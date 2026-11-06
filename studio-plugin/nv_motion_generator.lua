--!strict
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_motion_generator
-- Deskripsi: Generator Gerakan Karakter Alami (Human-like Motion Synthesis)
-- Menghasilkan pose kunci realistis (Anticipation, Follow-through, Easing)
-- untuk berjalan, berlari, tebasan pedang, tinju, idle, dan lompat.
-- ══════════════════════════════════════════════════════════════════════

local curvesMod = script.Parent:WaitForChild("nv_curves")
local Curves = require(curvesMod)
local kinematicsMod = script.Parent:WaitForChild("nv_kinematics")
local Kinematics = require(kinematicsMod)

local MotionGenerator = {}

export type KeyframeData = {
	time: number, -- 0.0 to duration
	poses: { [string]: CFrame } -- motorName -> C0 CFrame
}

-- ── Helper Angles ─────────────────────────────────────────────────────────────
local function anglesDeg(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- ── 1. Generator: Walk Cycle ──────────────────────────────────────────────────
function MotionGenerator.generateWalkCycle(rigInfo: Kinematics.RigInfo, options: { [string]: any }?): { KeyframeData }
	local opts = options or {}
	local duration = tonumber(opts.duration) or 1.0
	local intensity = tonumber(opts.intensity) or 1.0
	local isR15 = rigInfo.isR15

	-- Base offsets per motor
	local m = rigInfo.motors
	local defaultC0 = {}
	for name, motor in pairs(m) do
		defaultC0[name] = motor.C0
	end

	local legAngle = 26 * intensity
	local armAngle = 22 * intensity
	local torsoBob = 0.12 * intensity
	local torsoTwist = 6 * intensity

	local kfTimes = { 0.0, 0.25, 0.50, 0.75, 1.0 }
	local keyframes: { KeyframeData } = {}

	for _, tFrac in ipairs(kfTimes) do
		local tSec = tFrac * duration
		local poses: { [string]: CFrame } = {}

		if isR15 then
			local legPhase = math.sin(tFrac * math.pi * 2)
			local armPhase = -legPhase

			-- Torso movement (vertical bounce on each step)
			local bobY = math.abs(math.cos(tFrac * math.pi * 2)) * torsoBob
			local rootC0 = defaultC0["Root"] or CFrame.identity
			poses["Root"] = rootC0 * CFrame.new(0, -bobY, 0) * anglesDeg(4, legPhase * torsoTwist, 0)

			-- Left Leg & Right Leg
			local lHip = defaultC0["LeftHip"] or CFrame.identity
			local rHip = defaultC0["RightHip"] or CFrame.identity
			local lKnee = defaultC0["LeftKnee"] or CFrame.identity
			local rKnee = defaultC0["RightKnee"] or CFrame.identity

			poses["LeftHip"] = lHip * anglesDeg(legPhase * legAngle, 0, 0)
			poses["RightHip"] = rHip * anglesDeg(-legPhase * legAngle, 0, 0)

			-- Knee bends when leg swings back
			local lKneeBend = math.clamp(-legPhase * legAngle * 1.5, 0, 45)
			local rKneeBend = math.clamp(legPhase * legAngle * 1.5, 0, 45)
			poses["LeftKnee"] = lKnee * anglesDeg(lKneeBend, 0, 0)
			poses["RightKnee"] = rKnee * anglesDeg(rKneeBend, 0, 0)

			-- Left Arm & Right Arm (opposite to legs)
			local lShoulder = defaultC0["LeftShoulder"] or CFrame.identity
			local rShoulder = defaultC0["RightShoulder"] or CFrame.identity
			poses["LeftShoulder"] = lShoulder * anglesDeg(armPhase * armAngle, 0, -4)
			poses["RightShoulder"] = rShoulder * anglesDeg(-armPhase * armAngle, 0, 4)
		else
			-- R6 Rig
			local legPhase = math.sin(tFrac * math.pi * 2)
			local armPhase = -legPhase

			local lShoulder = defaultC0["Left Shoulder"] or CFrame.identity
			local rShoulder = defaultC0["Right Shoulder"] or CFrame.identity
			local lHip = defaultC0["Left Hip"] or CFrame.identity
			local rHip = defaultC0["Right Hip"] or CFrame.identity

			poses["Left Shoulder"] = lShoulder * anglesDeg(armPhase * armAngle, 0, 0)
			poses["Right Shoulder"] = rShoulder * anglesDeg(-armPhase * armAngle, 0, 0)
			poses["Left Hip"] = lHip * anglesDeg(legPhase * legAngle, 0, 0)
			poses["Right Hip"] = rHip * anglesDeg(-legPhase * legAngle, 0, 0)
		end

		table.insert(keyframes, { time = tSec, poses = poses })
	end

	return keyframes
end

-- ── 2. Generator: Melee Slash (Combat Attack) ─────────────────────────────────
function MotionGenerator.generateMeleeSlash(rigInfo: Kinematics.RigInfo, options: { [string]: any }?): { KeyframeData }
	local opts = options or {}
	local duration = tonumber(opts.duration) or 0.8
	local isR15 = rigInfo.isR15

	local defaultC0 = {}
	for name, motor in pairs(rigInfo.motors) do
		defaultC0[name] = motor.C0
	end

	-- Keyframes: 0 (Ready), 0.25 (Wind-up Anticipation), 0.50 (Slash Snap), 0.75 (Follow-Through), 1.0 (Recover)
	local points = {
		{
			t = 0.0,
			armRot = anglesDeg(10, 0, 5),
			torsoRot = anglesDeg(0, 0, 0),
			lArmRot = anglesDeg(5, 0, -5)
		},
		{
			t = 0.25, -- Wind-up
			armRot = anglesDeg(-110, -35, 40),
			torsoRot = anglesDeg(-5, -25, 0),
			lArmRot = anglesDeg(20, 15, -15)
		},
		{
			t = 0.50, -- Slash Strike
			armRot = anglesDeg(65, 30, -25),
			torsoRot = anglesDeg(10, 35, 0),
			lArmRot = anglesDeg(-25, -10, -20)
		},
		{
			t = 0.75, -- Follow-through overshoot
			armRot = anglesDeg(75, 40, -30),
			torsoRot = anglesDeg(8, 40, 0),
			lArmRot = anglesDeg(-15, -5, -15)
		},
		{
			t = 1.0, -- Return
			armRot = anglesDeg(10, 0, 5),
			torsoRot = anglesDeg(0, 0, 0),
			lArmRot = anglesDeg(5, 0, -5)
		}
	}

	local keyframes: { KeyframeData } = {}
	for _, pt in ipairs(points) do
		local poses: { [string]: CFrame } = {}
		if isR15 then
			poses["RightShoulder"] = (defaultC0["RightShoulder"] or CFrame.identity) * pt.armRot
			poses["LeftShoulder"] = (defaultC0["LeftShoulder"] or CFrame.identity) * pt.lArmRot
			poses["Waist"] = (defaultC0["Waist"] or CFrame.identity) * pt.torsoRot
		else
			poses["Right Shoulder"] = (defaultC0["Right Shoulder"] or CFrame.identity) * pt.armRot
			poses["Left Shoulder"] = (defaultC0["Left Shoulder"] or CFrame.identity) * pt.lArmRot
			poses["RootJoint"] = (defaultC0["RootJoint"] or CFrame.identity) * pt.torsoRot
		end
		table.insert(keyframes, { time = pt.t * duration, poses = poses })
	end

	return keyframes
end

-- ── 3. Generator: Punch Combo ─────────────────────────────────────────────────
function MotionGenerator.generatePunch(rigInfo: Kinematics.RigInfo, options: { [string]: any }?): { KeyframeData }
	local opts = options or {}
	local duration = tonumber(opts.duration) or 0.6
	local isR15 = rigInfo.isR15

	local defaultC0 = {}
	for name, motor in pairs(rigInfo.motors) do
		defaultC0[name] = motor.C0
	end

	local points = {
		{ t = 0.0, rArm = anglesDeg(0, 0, 0), torso = anglesDeg(0, 0, 0) },
		{ t = 0.2, rArm = anglesDeg(-20, -10, 15), torso = anglesDeg(0, -15, 0) }, -- Coil back
		{ t = 0.45, rArm = anglesDeg(90, 10, -5), torso = anglesDeg(8, 25, 0) },   -- Thrust forward
		{ t = 0.7, rArm = anglesDeg(70, 5, -2), torso = anglesDeg(4, 15, 0) },     -- Recoil
		{ t = 1.0, rArm = anglesDeg(0, 0, 0), torso = anglesDeg(0, 0, 0) }
	}

	local keyframes: { KeyframeData } = {}
	for _, pt in ipairs(points) do
		local poses: { [string]: CFrame } = {}
		if isR15 then
			poses["RightShoulder"] = (defaultC0["RightShoulder"] or CFrame.identity) * pt.rArm
			poses["Waist"] = (defaultC0["Waist"] or CFrame.identity) * pt.torso
		else
			poses["Right Shoulder"] = (defaultC0["Right Shoulder"] or CFrame.identity) * pt.rArm
			poses["RootJoint"] = (defaultC0["RootJoint"] or CFrame.identity) * pt.torso
		end
		table.insert(keyframes, { time = pt.t * duration, poses = poses })
	end

	return keyframes
end

-- ── 4. Generator: Idle Breathing ──────────────────────────────────────────────
function MotionGenerator.generateIdle(rigInfo: Kinematics.RigInfo, options: { [string]: any }?): { KeyframeData }
	local opts = options or {}
	local duration = tonumber(opts.duration) or 2.5
	local isR15 = rigInfo.isR15

	local defaultC0 = {}
	for name, motor in pairs(rigInfo.motors) do
		defaultC0[name] = motor.C0
	end

	local keyframes: { KeyframeData } = {}
	local steps = 8
	for i = 0, steps do
		local frac = i / steps
		local timeSec = frac * duration
		local breathCycle = math.sin(frac * math.pi * 2)

		local poses: { [string]: CFrame } = {}
		if isR15 then
			poses["Root"] = (defaultC0["Root"] or CFrame.identity) * CFrame.new(0, breathCycle * 0.04, 0)
			poses["Waist"] = (defaultC0["Waist"] or CFrame.identity) * anglesDeg(breathCycle * 1.5, 0, 0)
			poses["Neck"] = (defaultC0["Neck"] or CFrame.identity) * anglesDeg(-breathCycle * 1.0, 0, 0)
		else
			poses["RootJoint"] = (defaultC0["RootJoint"] or CFrame.identity) * CFrame.new(0, 0, breathCycle * 0.04)
			poses["Neck"] = (defaultC0["Neck"] or CFrame.identity) * anglesDeg(-breathCycle * 1.2, 0, 0)
		end

		table.insert(keyframes, { time = timeSec, poses = poses })
	end

	return keyframes
end

-- ── 5. Dense Sampler: Interpolasi Keyframes Menggunakan SLERP & Easing ────────
function MotionGenerator.sampleSequence(
	keyframes: { KeyframeData },
	fps: number,
	easing: string?
): { [number]: { [string]: CFrame } }
	if #keyframes == 0 then return {} end
	table.sort(keyframes, function(a, b) return a.time < b.time end)

	local totalDuration = keyframes[#keyframes].time
	local totalFrames = math.max(1, math.floor(totalDuration * fps))
	local sampled: { [number]: { [string]: CFrame } } = {}

	for f = 0, totalFrames do
		local curTime = (f / totalFrames) * totalDuration

		-- Cari segment keyframe [prev, next]
		local kA = keyframes[1]
		local kB = keyframes[#keyframes]
		for i = 1, #keyframes - 1 do
			if curTime >= keyframes[i].time and curTime <= keyframes[i + 1].time then
				kA = keyframes[i]
				kB = keyframes[i + 1]
				break
			end
		end

		local segDuration = kB.time - kA.time
		local rawAlpha = segDuration > 1e-5 and ((curTime - kA.time) / segDuration) or 0
		local curvedAlpha = Curves.evaluate(easing or "QuadInOut", rawAlpha)

		local framePoses: { [string]: CFrame } = {}
		for motorName, cfA in pairs(kA.poses) do
			local cfB = kB.poses[motorName] or cfA
			framePoses[motorName] = Curves.slerp(cfA, cfB, curvedAlpha)
		end

		sampled[f] = framePoses
	end

	return sampled
end

return MotionGenerator

