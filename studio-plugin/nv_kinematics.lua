--!strict
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_kinematics
-- Deskripsi: Mesin Kinematika Analitis 2-Link LimbIK & Abstraksi R6/R15
-- Menyelesaikan posisi siku/lutut menggunakan Hukum Cosinus O(1) tertutup,
-- ekstensi SoftIK anti-hentakan kaku, dan stabilisasi rotasi leher/kaki.
-- ══════════════════════════════════════════════════════════════════════

local Kinematics = {}
local EPSILON = 1e-6

-- ── 1. SoftIK Algorithm ───────────────────────────────────────────────────────
local function softDistance(dist: number, reach: number, softPercent: number?): number
	if dist <= 0 or reach <= 0 then return 0 end
	local pct = math.clamp(softPercent or 90, 0, 100) / 100
	local onset = reach * pct
	if dist <= onset then
		return dist
	end
	local zone = reach - onset
	if zone <= 0 then
		return math.min(dist, reach)
	end
	local x = (dist - onset) / zone
	local eased = x < 1e-4 and (x * (1 - x * 0.5)) or (1 - math.exp(-x))
	return math.min(dist, reach, onset + zone * eased)
end

-- ── 2. Rotation Between Two Vectors ───────────────────────────────────────────
function Kinematics.rotationBetween(from: Vector3, to: Vector3): CFrame
	if from.Magnitude < EPSILON or to.Magnitude < EPSILON then
		return CFrame.identity
	end
	from = from.Unit
	to = to.Unit
	local dot = math.clamp(from:Dot(to), -1, 1)
	local cross = from:Cross(to)
	if cross.Magnitude < EPSILON then
		if dot > 0 then
			return CFrame.identity
		end
		local basis = math.abs(from.X) < 0.8 and Vector3.xAxis or Vector3.yAxis
		return CFrame.fromAxisAngle(from:Cross(basis).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(cross.Unit, math.atan2(cross.Magnitude, dot))
end

-- ── 3. Analytical 2-Bone Limb Solver (Law of Cosines) ─────────────────────────
function Kinematics.solveTwoLink(
	root: Vector3,
	middle: Vector3,
	tip: Vector3,
	goal: Vector3,
	pole: Vector3?,
	softPercent: number?
): (Vector3, Vector3)
	local upperLen = (middle - root).Magnitude
	local lowerLen = (tip - middle).Magnitude
	if upperLen < EPSILON or lowerLen < EPSILON then
		return middle, tip
	end

	local delta = goal - root
	local rawDist = delta.Magnitude
	local dir = rawDist > EPSILON and delta.Unit or (tip - root).Unit
	local reach = upperLen + lowerLen

	-- Soften distance
	local softened = softDistance(rawDist, reach, softPercent or 90)
	local dist = math.clamp(softened, math.max(math.abs(upperLen - lowerLen), EPSILON), reach - 1e-4)

	-- Bend direction towards pole
	local polePos = pole or (middle + Vector3.new(0, 0, -1))
	local bend = polePos - root
	bend = bend - dir * bend:Dot(dir)
	if bend.Magnitude < EPSILON then
		local basis = math.abs(dir.X) < 0.8 and Vector3.xAxis or Vector3.yAxis
		bend = basis - dir * basis:Dot(dir)
	end
	bend = bend.Unit

	-- Law of Cosines: Upper arm projection along direction vector
	local along = (upperLen * upperLen - lowerLen * lowerLen + dist * dist) / (2 * dist)
	local heightSq = upperLen * upperLen - along * along
	local height = math.sqrt(math.max(0, heightSq))

	local solvedMiddle = root + dir * along + bend * height
	local solvedTip = root + dir * dist
	return solvedMiddle, solvedTip
end

-- ── 4. Rig Discovery & Abstraction (R6 & R15) ──────────────────────────────────
export type RigInfo = {
	model: Model,
	isR15: boolean,
	rootPart: BasePart,
	motors: { [string]: Motor6D },
	parts: { [string]: BasePart }
}

function Kinematics.inspectRig(model: Model): RigInfo?
	if not model or not model:IsA("Model") then return nil end
	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		rootPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	end
	if not rootPart then return nil end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local isR15 = humanoid and (humanoid.RigType == Enum.HumanoidRigType.R15) or false
	if not humanoid then
		isR15 = model:FindFirstChild("UpperTorso") ~= nil
	end

	local motors: { [string]: Motor6D } = {}
	local parts: { [string]: BasePart } = {}

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Motor6D") then
			motors[desc.Name] = desc
		elseif desc:IsA("BasePart") then
			parts[desc.Name] = desc
		end
	end

	return {
		model = model,
		isR15 = isR15,
		rootPart = rootPart,
		motors = motors,
		parts = parts
	}
end

-- ── 5. Solve Limb IK on R15 / R6 Rig ──────────────────────────────────────────
function Kinematics.solveLimb(
	rigInfo: RigInfo,
	limbName: string, -- "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg"
	targetWorldPos: Vector3,
	poleWorldPos: Vector3?,
	applyToRig: boolean?
): { [string]: CFrame }?
	local m = rigInfo.motors
	local p = rigInfo.parts

	if rigInfo.isR15 then
		local upperMotorName, lowerMotorName, endMotorName
		local upperPartName, lowerPartName, endPartName
		local defaultPoleOffset = Vector3.new(0, 0, -2)

		if limbName == "LeftArm" then
			upperMotorName, lowerMotorName, endMotorName = "LeftShoulder", "LeftElbow", "LeftWrist"
			upperPartName, lowerPartName, endPartName = "LeftUpperArm", "LeftLowerArm", "LeftHand"
			defaultPoleOffset = Vector3.new(-1, 0, -2)
		elseif limbName == "RightArm" then
			upperMotorName, lowerMotorName, endMotorName = "RightShoulder", "RightElbow", "RightWrist"
			upperPartName, lowerPartName, endPartName = "RightUpperArm", "RightLowerArm", "RightHand"
			defaultPoleOffset = Vector3.new(1, 0, -2)
		elseif limbName == "LeftLeg" then
			upperMotorName, lowerMotorName, endMotorName = "LeftHip", "LeftKnee", "LeftAnkle"
			upperPartName, lowerPartName, endPartName = "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"
			defaultPoleOffset = Vector3.new(0, 0, 2)
		elseif limbName == "RightLeg" then
			upperMotorName, lowerMotorName, endMotorName = "RightHip", "RightKnee", "RightAnkle"
			upperPartName, lowerPartName, endPartName = "RightUpperLeg", "RightLowerLeg", "RightFoot"
			defaultPoleOffset = Vector3.new(0, 0, 2)
		else
			return nil
		end

		local upperMotor = m[upperMotorName]
		local lowerMotor = m[lowerMotorName]
		local upperPart = p[upperPartName]
		local lowerPart = p[lowerPartName]
		local endPart = p[endPartName]

		if not upperMotor or not lowerMotor or not upperPart or not lowerPart or not endPart then
			return nil
		end

		local rootPos = upperPart.Position
		local midPos = lowerPart.Position
		local tipPos = endPart.Position
		local pole = poleWorldPos or (midPos + defaultPoleOffset)

		local solvedMid, solvedTip = Kinematics.solveTwoLink(rootPos, midPos, tipPos, targetWorldPos, pole, 90)

		-- Hitung C0 baru untuk upper dan lower
		local upperParentCF = upperMotor.Part0.CFrame
		local upperGoalWorldCF = CFrame.lookAt(rootPos, solvedMid, pole - rootPos)
		local upperC0 = upperParentCF:Inverse() * upperGoalWorldCF * upperMotor.C1

		local lowerParentCF = solvedMid ~= rootPos and CFrame.lookAt(rootPos, solvedMid) or upperPart.CFrame
		local lowerGoalWorldCF = CFrame.lookAt(solvedMid, solvedTip, pole - solvedMid)
		local lowerC0 = lowerParentCF:Inverse() * lowerGoalWorldCF * lowerMotor.C1

		if applyToRig then
			upperMotor.C0 = upperC0
			lowerMotor.C0 = lowerC0
		end

		return {
			[upperMotorName] = upperC0,
			[lowerMotorName] = lowerC0
		}
	else
		-- Mode R6: 1 bone per limb, arahkan ke targetWorldPos
		local motorName, partName
		if limbName == "LeftArm" then motorName, partName = "Left Shoulder", "Left Arm"
		elseif limbName == "RightArm" then motorName, partName = "Right Shoulder", "Right Arm"
		elseif limbName == "LeftLeg" then motorName, partName = "Left Hip", "Left Leg"
		elseif limbName == "RightLeg" then motorName, partName = "Right Hip", "Right Leg"
		else return nil end

		local motor = m[motorName]
		local part = p[partName]
		if not motor or not part or not motor.Part0 then return nil end

		local rootPos = part.Position
		local goalCF = CFrame.lookAt(rootPos, targetWorldPos)
		local c0 = motor.Part0.CFrame:Inverse() * goalCF * motor.C1

		if applyToRig then
			motor.C0 = c0
		end
		return { [motorName] = c0 }
	end
end

-- ── 6. Head Look-At Stabilizer ────────────────────────────────────────────────
function Kinematics.solveLookAt(rigInfo: RigInfo, targetWorldPos: Vector3, applyToRig: boolean?): CFrame?
	local neckMotor = rigInfo.motors["Neck"]
	local headPart = rigInfo.parts["Head"]
	if not neckMotor or not headPart or not neckMotor.Part0 then return nil end

	local headPos = headPart.Position
	local lookDir = (targetWorldPos - headPos).Unit
	local targetWorldCF = CFrame.lookAt(headPos, headPos + lookDir)
	local neckC0 = neckMotor.Part0.CFrame:Inverse() * targetWorldCF * neckMotor.C1

	if applyToRig then
		neckMotor.C0 = neckC0
	end
	return neckC0
end

return Kinematics

