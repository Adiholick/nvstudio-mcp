--!strict
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_anim_dispatcher
-- Deskripsi: Headless Modular Command Dispatcher untuk Pembuatan Animasi
-- Mengatur inisialisasi rig, analytical IK, generasi keyframe kurva halus,
-- dan ekspor resmi ke KeyframeSequence di Roblox Studio.
-- ══════════════════════════════════════════════════════════════════════

local kinematicsMod = script.Parent:WaitForChild("nv_kinematics")
local Kinematics = require(kinematicsMod)
local curvesMod = script.Parent:WaitForChild("nv_curves")
local Curves = require(curvesMod)
local motionMod = script.Parent:WaitForChild("nv_motion_generator")
local Motion = require(motionMod)

local Dispatcher = {}

-- ── 1. Helper: Temukan Rig dari Instance atau Path ────────────────────────────
function Dispatcher.getRigInfo(targetInstance: Instance?): Kinematics.RigInfo?
	if not targetInstance then return nil end
	local model = targetInstance:IsA("Model") and targetInstance or targetInstance:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	return Kinematics.inspectRig(model)
end

-- ── 2. Buat KeyframeSequence Resmi di Roblox ─────────────────────────────────
function Dispatcher.buildKeyframeSequence(
	rigInfo: Kinematics.RigInfo,
	clipName: string,
	keyframes: { Motion.KeyframeData },
	options: { loop: boolean?, priority: Enum.AnimationPriority? }?
): KeyframeSequence
	local opts = options or {}
	local isR15 = rigInfo.isR15

	local seq = Instance.new("KeyframeSequence")
	seq.Name = clipName
	seq.Loop = opts.loop ~= false
	seq.Priority = opts.priority or Enum.AnimationPriority.Action

	-- Urutkan keyframes berdasarkan waktu
	table.sort(keyframes, function(a, b) return a.time < b.time end)

	for _, kfData in ipairs(keyframes) do
		local kf = Instance.new("Keyframe")
		kf.Time = kfData.time
		kf.Name = string.format("Frame_%.2f", kfData.time)

		-- Root Pose (HumanoidRootPart)
		local rootPose = Instance.new("Pose")
		rootPose.Name = "HumanoidRootPart"
		rootPose.Weight = 1
		rootPose.EasingStyle = Enum.PoseEasingStyle.Cubic
		rootPose.EasingDirection = Enum.PoseEasingDirection.InOut

		local function createPose(name: string, cf: CFrame?, parent: Instance?): Pose
			local p = Instance.new("Pose")
			p.Name = name
			p.Weight = 1
			p.EasingStyle = Enum.PoseEasingStyle.Cubic
			p.EasingDirection = Enum.PoseEasingDirection.InOut
			if cf then p.CFrame = cf end
			if parent then p.Parent = parent end
			return p
		end

		if isR15 then
			-- LowerTorso pose
			local lowerTorsoPose = createPose("LowerTorso", kfData.poses["Root"], nil)

			-- UpperTorso pose
			local upperTorsoPose = createPose("UpperTorso", kfData.poses["Waist"], nil)

			-- Head
			if kfData.poses["Neck"] then
				createPose("Head", kfData.poses["Neck"], upperTorsoPose)
			end

			-- Arms
			for _, side in ipairs({ "Left", "Right" }) do
				local shoulderPose = createPose(side .. "UpperArm", kfData.poses[side .. "Shoulder"], nil)
				local elbowPose = shoulderPose
				if kfData.poses[side .. "Elbow"] then
					elbowPose = createPose(side .. "LowerArm", kfData.poses[side .. "Elbow"], shoulderPose)
				end
				if kfData.poses[side .. "Wrist"] then
					createPose(side .. "Hand", kfData.poses[side .. "Wrist"], elbowPose)
				end
				shoulderPose.Parent = upperTorsoPose
			end

			-- Legs
			for _, side in ipairs({ "Left", "Right" }) do
				local hipPose = createPose(side .. "UpperLeg", kfData.poses[side .. "Hip"], nil)
				local kneePose = hipPose
				if kfData.poses[side .. "Knee"] then
					kneePose = createPose(side .. "LowerLeg", kfData.poses[side .. "Knee"], hipPose)
				end
				if kfData.poses[side .. "Ankle"] then
					createPose(side .. "Foot", kfData.poses[side .. "Ankle"], kneePose)
				end
				hipPose.Parent = lowerTorsoPose
			end

			upperTorsoPose.Parent = lowerTorsoPose
			lowerTorsoPose.Parent = rootPose
		else
			-- R6 Pose Structure
			local torsoPose = createPose("Torso", kfData.poses["RootJoint"], nil)

			if kfData.poses["Neck"] then
				createPose("Head", kfData.poses["Neck"], torsoPose)
			end

			for _, limb in ipairs({ "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }) do
				if kfData.poses[limb] then
					local partName = limb == "Left Shoulder" and "Left Arm"
						or limb == "Right Shoulder" and "Right Arm"
						or limb == "Left Hip" and "Left Leg"
						or "Right Leg"
					createPose(partName, kfData.poses[limb], torsoPose)
				end
			end

			torsoPose.Parent = rootPose
		end

		-- Lampirkan VFX KeyframeMarkers jika ada event di frame ini
		if opts.vfx_events and type(opts.vfx_events) == "table" then
			for _, evt in ipairs(opts.vfx_events) do
				local evtTime = tonumber(evt.time) or 0
				if math.abs(evtTime - kfData.time) <= 0.08 then
					local marker = Instance.new("KeyframeMarker")
					marker.Name = evt.marker_name or "VFX"
					marker.Value = evt.value or evt.action or "Emit"
					marker.Parent = kf
				end
			end
		end

		rootPose.Parent = kf
		kf.Parent = seq
	end

	return seq
end

-- ── 3. Eksekusi Perintah Pembuatan Animasi ────────────────────────────────────
function Dispatcher.createAnimation(
	targetInstance: Instance,
	action: string,
	parameters: { [string]: any }?,
	keyPoses: { any }?
): { [string]: any }
	local rigInfo = Dispatcher.getRigInfo(targetInstance)
	if not rigInfo then
		return { status = "error", error = "Target bukan model karakter rig (R6/R15) yang valid: " .. targetInstance:GetFullName() }
	end

	local params = parameters or {}
	local clipName = params.clipName or (action .. "_" .. (rigInfo.isR15 and "R15" or "R6"))
	local keyframes: { Motion.KeyframeData }

	if action == "walk_cycle" or action == "walk" then
		keyframes = Motion.generateWalkCycle(rigInfo, params)
	elseif action == "melee_slash" or action == "slash" or action == "sword" then
		keyframes = Motion.generateMeleeSlash(rigInfo, params)
	elseif action == "punch" or action == "combat_punch" then
		keyframes = Motion.generatePunch(rigInfo, params)
	elseif action == "idle" or action == "idle_breath" then
		keyframes = Motion.generateIdle(rigInfo, params)
	elseif action == "custom" and keyPoses and #keyPoses > 0 then
		-- Parser custom keyposes dari input agent
		keyframes = {}
		for _, kp in ipairs(keyPoses) do
			local motorCfs: { [string]: CFrame } = {}
			if kp.poses then
				for mName, cVal in pairs(kp.poses) do
					if type(cVal) == "table" and cVal.t == "CFrame" then
						motorCfs[mName] = CFrame.new(table.unpack(cVal.v))
					elseif type(cVal) == "table" and cVal.angles then
						local a = cVal.angles
						motorCfs[mName] = CFrame.Angles(math.rad(a[1] or 0), math.rad(a[2] or 0), math.rad(a[3] or 0))
					end
				end
			end
			table.insert(keyframes, {
				time = tonumber(kp.time) or 0,
				poses = motorCfs
			})
		end
	else
		return {
			status = "error",
			error = "Action tidak dikenal: '" .. tostring(action) .. "'. Pilihan: walk_cycle, melee_slash, punch, idle_breath, custom."
		}
	end

	-- Simpan KeyframeSequence ke AnimSaves pada Rig
	local animSaves = rigInfo.model:FindFirstChild("AnimSaves")
	if not animSaves then
		animSaves = Instance.new("Model")
		animSaves.Name = "AnimSaves"
		animSaves.Parent = rigInfo.model
	end

	local kfSeq = Dispatcher.buildKeyframeSequence(rigInfo, clipName, keyframes, {
		loop = params.loop,
		priority = Enum.AnimationPriority.Action,
		vfx_events = params.vfx_events
	})
	kfSeq.Parent = animSaves

	-- Terapkan pose pertama ke karakter di Studio untuk live feedback
	if keyframes[1] and keyframes[1].poses then
		for mName, cf in pairs(keyframes[1].poses) do
			local m = rigInfo.motors[mName]
			if m then
				pcall(function() m.C0 = cf end)
			end
		end
	end

	return {
		status = "success",
		result = {
			clipName = clipName,
			action = action,
			rigType = rigInfo.isR15 and "R15" or "R6",
			keyframeCount = #keyframes,
			duration = keyframes[#keyframes].time,
			savedPath = kfSeq:GetFullName(),
			message = string.format("Animasi '%s' berhasil dibuat dan disimpan ke '%s'", clipName, kfSeq:GetFullName())
		}
	}
end

return Dispatcher

