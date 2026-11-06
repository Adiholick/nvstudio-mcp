--!strict
-- ══════════════════════════════════════════════════════════════════════
-- Skill Module: animate_character
-- Deskripsi: Semantic Tool untuk AI Agent membuat animasi karakter halus
-- Menggunakan NV-Animation Engine (Walk, Slash, Punch, Idle, atau Custom)
-- ══════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local dispatcherMod = script.Parent:WaitForChild("nv_anim_dispatcher")
local Dispatcher = require(dispatcherMod)

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
	if not targetInstance then
		return { status = "error", error = "Target karakter rig untuk animate_character tidak ditemukan: " .. tostring(targetPath) }
	end

	local payload: { [string]: any } = {}
	local ok, err = pcall(function()
		if type(data) == "table" then
			payload = data
		else
			payload = HttpService:JSONDecode(tostring(data))
		end
	end)

	if not ok or type(payload) ~= "table" then
		return { status = "error", error = "Format payload animasi tidak valid: " .. tostring(err) }
	end

	local action = tostring(payload.action or "walk_cycle")
	local parameters = payload.parameters or {}
	local keyPoses = payload.key_poses

	return Dispatcher.createAnimation(targetInstance, action, parameters, keyPoses)
end

