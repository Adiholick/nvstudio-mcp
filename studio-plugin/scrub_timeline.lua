--!strict
-- ══════════════════════════════════════════════════════════════════════
-- Skill Module: scrub_timeline
-- Deskripsi: Headless Timeline Scrubbing & VFX Playhead Controller
-- Mengevaluasi pose rig dan memicu burst/scrub VFX pada timestamp spesifik (t)
-- secara deterministik langsung di Viewport Roblox Studio.
-- ══════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local kinematicsMod = script.Parent:WaitForChild("nv_kinematics")
local Kinematics = require(kinematicsMod)
local curvesMod = script.Parent:WaitForChild("nv_curves")
local Curves = require(curvesMod)
local motionMod = script.Parent:WaitForChild("nv_motion_generator")
local Motion = require(motionMod)

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
	if not targetInstance then
		return { status = "error", error = "Target instance untuk scrub_timeline tidak ditemukan: " .. tostring(targetPath) }
	end

	local payload: { [string]: any } = {}
	pcall(function()
		if type(data) == "table" then payload = data
		else payload = HttpService:JSONDecode(tostring(data)) end
	end)

	local timePos = tonumber(payload.time) or 0.0
	local action = payload.action or "melee_slash"
	local emitVfx = payload.emit_vfx == true or payload.emit == true
	local emitCount = tonumber(payload.emit_count) or 20

	local rigInfo = Kinematics.inspectRig(targetInstance:IsA("Model") and targetInstance or targetInstance:FindFirstAncestorOfClass("Model") :: any)
	local appliedMotors: { string } = {}

	-- 1. Scrub Rig Joint Poses jika target adalah Rig
	if rigInfo then
		local keyframes: { Motion.KeyframeData }
		if action == "walk_cycle" then
			keyframes = Motion.generateWalkCycle(rigInfo, payload.parameters)
		elseif action == "punch" then
			keyframes = Motion.generatePunch(rigInfo, payload.parameters)
		elseif action == "idle" or action == "idle_breath" then
			keyframes = Motion.generateIdle(rigInfo, payload.parameters)
		else
			keyframes = Motion.generateMeleeSlash(rigInfo, payload.parameters)
		end

		if #keyframes > 0 then
			table.sort(keyframes, function(a, b) return a.time < b.time end)
			local totalDur = keyframes[#keyframes].time
			local clampedTime = math.clamp(timePos, 0, totalDur)

			-- Cari segmen [kA, kB]
			local kA = keyframes[1]
			local kB = keyframes[#keyframes]
			for i = 1, #keyframes - 1 do
				if clampedTime >= keyframes[i].time and clampedTime <= keyframes[i + 1].time then
					kA = keyframes[i]
					kB = keyframes[i + 1]
					break
				end
			end

			local segDur = kB.time - kA.time
			local alpha = segDur > 1e-5 and ((clampedTime - kA.time) / segDur) or 0
			local curvedAlpha = Curves.evaluate(payload.easing or "QuadInOut", alpha)

			for motorName, cfA in pairs(kA.poses) do
				local cfB = kB.poses[motorName] or cfA
				local interpCF = Curves.slerp(cfA, cfB, curvedAlpha)
				local m = rigInfo.motors[motorName]
				if m then
					pcall(function()
						m.C0 = interpCF
						table.insert(appliedMotors, motorName)
					end)
				end
			end
		end
	end

	-- 2. Scrub & Trigger VFX Emitters
	local emittersTriggered = 0
	local beamsToggled = 0

	local function checkVfx(inst: Instance)
		if inst:IsA("ParticleEmitter") then
			if emitVfx then
				pcall(function()
					inst:Emit(emitCount)
					emittersTriggered += 1
				end)
			end
		elseif inst:IsA("Beam") or inst:IsA("Trail") then
			if payload.enabled ~= nil then
				pcall(function()
					inst.Enabled = payload.enabled
					beamsToggled += 1
				end)
			end
		end
	end

	checkVfx(targetInstance)
	for _, desc in ipairs(targetInstance:GetDescendants()) do
		checkVfx(desc)
	end

	return {
		status = "success",
		result = {
			time = timePos,
			action = action,
			motorsPosed = #appliedMotors,
			emittersTriggered = emittersTriggered,
			beamsToggled = beamsToggled,
			message = string.format("Timeline di-scrub ke t=%.2fs (Pose: %d joint, VFX: %d emitter burst)", timePos, #appliedMotors, emittersTriggered)
		}
	}
end

