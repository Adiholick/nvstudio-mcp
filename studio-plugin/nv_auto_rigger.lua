--!strict
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_auto_rigger
-- Deskripsi: Mesin Auto-Rigging Deterministik & Heuristik Geometris
-- Membangun struktur rig lengkap untuk Avatar R6, R15, Senjata/Prop,
-- dan Assembly Model secara instan dengan zero-dislocation math.
-- ══════════════════════════════════════════════════════════════════════

local jointMathMod = script.Parent:WaitForChild("nv_joint_math")
local JointMath = require(jointMathMod)

local AutoRigger = {}

-- ── Helper: Dapatkan atau buat Motor6D ─────────────────────────────────────────
local function createOrUpdateMotor(name: string, part0: BasePart, part1: BasePart, parent: Instance?): Motor6D
	part1.Anchored = false
	local existing = part0:FindFirstChild(name) or part1:FindFirstChild(name)
	local motor: Motor6D
	if existing and existing:IsA("Motor6D") then
		motor = existing
	else
		motor = Instance.new("Motor6D")
		motor.Name = name
	end

	motor.Part0 = part0
	motor.Part1 = part1
	local c0, c1 = JointMath.computeInitialOffsets(part0, part1)
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = parent or part0
	return motor
end

-- ── 1. Auto-Rig R6 Avatar ─────────────────────────────────────────────────────
function AutoRigger.rigR6(model: Model): { [string]: any }
	assert(model and model:IsA("Model"), "Target harus berupa Model")

	local parts: { [string]: BasePart } = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			parts[desc.Name] = desc
		end
	end

	local torso = parts["Torso"] or parts["UpperTorso"]
	if not torso then
		return { status = "error", error = "Model tidak memiliki part 'Torso' untuk R6 rig." }
	end

	local rootPart = parts["HumanoidRootPart"]
	if not rootPart then
		-- Buat HumanoidRootPart transparan jika belum ada
		rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = Vector3.new(2, 2, 1)
		rootPart.Transparency = 1
		rootPart.CanCollide = false
		rootPart.CFrame = torso.CFrame
		rootPart.Parent = model
		parts["HumanoidRootPart"] = rootPart
		model.PrimaryPart = rootPart
	end

	local created = {}

	-- 1. RootJoint: HumanoidRootPart -> Torso
	local rootJoint = createOrUpdateMotor("RootJoint", rootPart, torso, rootPart)
	table.insert(created, "RootJoint")

	-- 2. Neck: Torso -> Head
	if parts["Head"] then
		createOrUpdateMotor("Neck", torso, parts["Head"], torso)
		table.insert(created, "Neck")
	end

	-- 3. Shoulders: Torso -> Arms
	local lArm = parts["Left Arm"] or parts["LeftArm"]
	if lArm then
		createOrUpdateMotor("Left Shoulder", torso, lArm, torso)
		table.insert(created, "Left Shoulder")
	end

	local rArm = parts["Right Arm"] or parts["RightArm"]
	if rArm then
		createOrUpdateMotor("Right Shoulder", torso, rArm, torso)
		table.insert(created, "Right Shoulder")
	end

	-- 4. Hips: Torso -> Legs
	local lLeg = parts["Left Leg"] or parts["LeftLeg"]
	if lLeg then
		createOrUpdateMotor("Left Hip", torso, lLeg, torso)
		table.insert(created, "Left Hip")
	end

	local rLeg = parts["Right Leg"] or parts["RightLeg"]
	if rLeg then
		createOrUpdateMotor("Right Hip", torso, rLeg, torso)
		table.insert(created, "Right Hip")
	end

	-- Pastikan Humanoid bertipe R6
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RigType = Enum.HumanoidRigType.R6
	end

	return {
		status = "success",
		rigType = "R6",
		jointsCreated = #created,
		jointNames = created,
		rootPart = rootPart.Name
	}
end

-- ── 2. Auto-Rig R15 Avatar ────────────────────────────────────────────────────
function AutoRigger.rigR15(model: Model): { [string]: any }
	assert(model and model:IsA("Model"), "Target harus berupa Model")

	local parts: { [string]: BasePart } = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			parts[desc.Name] = desc
		end
	end

	local lowerTorso = parts["LowerTorso"]
	local upperTorso = parts["UpperTorso"]
	if not lowerTorso or not upperTorso then
		return { status = "error", error = "Model tidak memiliki 'LowerTorso' dan 'UpperTorso' untuk R15 rig." }
	end

	local rootPart = parts["HumanoidRootPart"]
	if not rootPart then
		rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = Vector3.new(2, 2, 1)
		rootPart.Transparency = 1
		rootPart.CanCollide = false
		rootPart.CFrame = lowerTorso.CFrame
		rootPart.Parent = model
		parts["HumanoidRootPart"] = rootPart
		model.PrimaryPart = rootPart
	end

	local r15Hierarchy = {
		{ name = "Root", p0 = "HumanoidRootPart", p1 = "LowerTorso" },
		{ name = "Waist", p0 = "LowerTorso", p1 = "UpperTorso" },
		{ name = "Neck", p0 = "UpperTorso", p1 = "Head" },

		-- Left Arm Chain
		{ name = "LeftShoulder", p0 = "UpperTorso", p1 = "LeftUpperArm" },
		{ name = "LeftElbow", p0 = "LeftUpperArm", p1 = "LeftLowerArm" },
		{ name = "LeftWrist", p0 = "LeftLowerArm", p1 = "LeftHand" },

		-- Right Arm Chain
		{ name = "RightShoulder", p0 = "UpperTorso", p1 = "RightUpperArm" },
		{ name = "RightElbow", p0 = "RightUpperArm", p1 = "RightLowerArm" },
		{ name = "RightWrist", p0 = "RightLowerArm", p1 = "RightHand" },

		-- Left Leg Chain
		{ name = "LeftHip", p0 = "LowerTorso", p1 = "LeftUpperLeg" },
		{ name = "LeftKnee", p0 = "LeftUpperLeg", p1 = "LeftLowerLeg" },
		{ name = "LeftAnkle", p0 = "LeftLowerLeg", p1 = "LeftFoot" },

		-- Right Leg Chain
		{ name = "RightHip", p0 = "LowerTorso", p1 = "RightUpperLeg" },
		{ name = "RightKnee", p0 = "RightUpperLeg", p1 = "RightLowerLeg" },
		{ name = "RightAnkle", p0 = "RightLowerLeg", p1 = "RightFoot" }
	}

	local created = {}
	for _, item in ipairs(r15Hierarchy) do
		local p0 = parts[item.p0]
		local p1 = parts[item.p1]
		if p0 and p1 then
			createOrUpdateMotor(item.name, p0, p1, p0)
			table.insert(created, item.name)
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.RigType = Enum.HumanoidRigType.R15
	end

	return {
		status = "success",
		rigType = "R15",
		jointsCreated = #created,
		jointNames = created,
		rootPart = rootPart.Name
	}
end

-- ── 3. Rig Weapon / Tool ke Karakter ──────────────────────────────────────────
function AutoRigger.rigWeapon(characterModel: Model, weaponInstance: Instance, targetLimbName: string?): { [string]: any }
	assert(characterModel and characterModel:IsA("Model"), "Character target harus berupa Model")
	assert(weaponInstance and weaponInstance:IsA("Instance"), "Weapon target tidak valid")

	local parts: { [string]: BasePart } = {}
	for _, desc in ipairs(characterModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			parts[desc.Name] = desc
		end
	end

	local limb = targetLimbName and parts[targetLimbName]
	if not limb then
		limb = parts["RightHand"] or parts["Right Arm"] or parts["RightArm"] or parts["HumanoidRootPart"]
	end
	if not limb then
		return { status = "error", error = "Tidak dapat menemukan anggota tubuh target (RightHand / Right Arm) pada karakter." }
	end

	-- Cari handle pada senjata
	local weaponHandle: BasePart? = nil
	if weaponInstance:IsA("BasePart") then
		weaponHandle = weaponInstance
	elseif weaponInstance:IsA("Model") or weaponInstance:IsA("Tool") then
		weaponHandle = (weaponInstance :: any).PrimaryPart
			or weaponInstance:FindFirstChild("Handle") :: BasePart?
			or weaponInstance:FindFirstChildWhichIsA("BasePart")
	end

	if not weaponHandle then
		return { status = "error", error = "Senjata tidak memiliki BasePart atau Handle." }
	end

	-- 1. Buat Motor6D penaut karakter ke Handle
	local weaponMotor = createOrUpdateMotor("WeaponGrip", limb, weaponHandle, limb)

	-- 2. Las seluruh bagian senjata lain ke Handle
	local weldedCount = 0
	if weaponInstance ~= weaponHandle then
		for _, desc in ipairs(weaponInstance:GetDescendants()) do
			if desc:IsA("BasePart") and desc ~= weaponHandle then
				desc.Anchored = false
				local weld = desc:FindFirstChild("WeldToHandle") or Instance.new("Weld")
				weld.Name = "WeldToHandle"
				weld.Part0 = weaponHandle
				weld.Part1 = desc
				weld.C0 = weaponHandle.CFrame:ToObjectSpace(desc.CFrame)
				weld.C1 = CFrame.identity
				weld.Parent = weaponHandle
				weldedCount += 1
			end
		end
	end

	return {
		status = "success",
		attachedTo = limb.Name,
		handleName = weaponHandle.Name,
		weldedComponents = weldedCount,
		message = string.format("Senjata '%s' berhasil dirig ke '%s' (%d part dilas)", weaponInstance.Name, limb.Name, weldedCount)
	}
end

-- ── 4. Weld Assembly (Props, Armor, Kendaraan) ────────────────────────────────
function AutoRigger.weldAssembly(container: Instance, primaryPart: BasePart?): { [string]: any }
	assert(container and container:IsA("Instance"), "Container tidak valid")

	local rootPart: BasePart? = primaryPart
	if not rootPart and container:IsA("Model") then
		rootPart = container.PrimaryPart
	end

	local allParts: { BasePart } = {}
	for _, desc in ipairs(container:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(allParts, desc)
		end
	end
	if container:IsA("BasePart") then
		table.insert(allParts, container)
	end

	if #allParts == 0 then
		return { status = "error", error = "Tidak ada BasePart di dalam kontainer untuk dilas." }
	end

	-- Jika belum ada rootPart, tentukan berdasarkan volume terbesar
	if not rootPart then
		local maxVol = -1
		for _, p in ipairs(allParts) do
			local vol = p.Size.X * p.Size.Y * p.Size.Z
			if vol > maxVol then
				maxVol = vol
				rootPart = p
			end
		end
	end

	if not rootPart then
		return { status = "error", error = "Gagal menentukan Root Part untuk pengelasan." }
	end

	local weldsCreated = 0
	for _, p in ipairs(allParts) do
		if p ~= rootPart then
			p.Anchored = false
			local w = p:FindFirstChild("AssemblyWeld") or Instance.new("Weld")
			w.Name = "AssemblyWeld"
			w.Part0 = rootPart
			w.Part1 = p
			w.C0 = rootPart.CFrame:ToObjectSpace(p.CFrame)
			w.C1 = CFrame.identity
			w.Parent = rootPart
			weldsCreated += 1
		end
	end

	return {
		status = "success",
		rootPart = rootPart.Name,
		weldsCreated = weldsCreated,
		message = string.format("Berhasil mengelas %d part ke Root '%s'", weldsCreated, rootPart.Name)
	}
end

-- ── 5. Spatial Geometric Limb Analyzer (Heuristik Bounding Box) ───────────────
-- Menganalisis model dengan nama part acak/impor dan mengklasifikasikan anggota tubuh
function AutoRigger.discoverLimbsBySpatialGeometry(model: Model): { [string]: BasePart }
	local parts: { BasePart } = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end

	if #parts == 0 then return {} end

	-- 1. Hitung bounding box pusat model
	local cframe, size = model:GetBoundingBox()
	local center = cframe.Position

	-- 2. Temukan torso (part dengan volume besar di sekitar pusat vertikal)
	local bestTorso: BasePart = parts[1]
	local bestScore = -1e9

	for _, p in ipairs(parts) do
		local vol = p.Size.X * p.Size.Y * p.Size.Z
		local distToCenter = (p.Position - center).Magnitude
		local score = vol / (distToCenter + 1)
		if score > bestScore then
			bestScore = score
			bestTorso = p
		end
	end

	local identified: { [string]: BasePart } = {
		Torso = bestTorso
	}

	local torsoPos = bestTorso.Position

	-- 3. Klasifikasi part lainnya relatif terhadap Torso
	for _, p in ipairs(parts) do
		if p ~= bestTorso then
			local relPos = bestTorso.CFrame:PointToObjectSpace(p.Position)

			if relPos.Y > bestTorso.Size.Y * 0.5 then
				-- Bagian atas -> Head
				if not identified["Head"] or p.Position.Y > identified["Head"].Position.Y then
					identified["Head"] = p
				end
			elseif relPos.Y < -bestTorso.Size.Y * 0.3 then
				-- Bagian bawah -> Legs
				if relPos.X < 0 then
					identified["Left Leg"] = p
				else
					identified["Right Leg"] = p
				end
			else
				-- Bagian samping -> Arms
				if relPos.X < 0 then
					identified["Left Arm"] = p
				else
					identified["Right Arm"] = p
				end
			end
		end
	end

	return identified
end

return AutoRigger

