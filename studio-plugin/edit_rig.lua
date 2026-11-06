--!strict
-- ══════════════════════════════════════════════════════════════════════
-- Skill Module: edit_rig
-- Deskripsi: Semantic Tool untuk AI Agent mengelola rig, Motor6D, Weld,
-- C0/C1 pivot compensation, auto-rigging, dan pengelasan model.
-- ══════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local dispatcherMod = script.Parent:WaitForChild("nv_rig_dispatcher")
local Dispatcher = require(dispatcherMod)

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
	if not targetInstance then
		return { status = "error", error = "Target instance untuk edit_rig tidak ditemukan: " .. tostring(targetPath) }
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
		return { status = "error", error = "Format payload edit_rig tidak valid: " .. tostring(err) }
	end

	local action = tostring(payload.action or "inspect")
	local parameters = payload.parameters or payload

	return Dispatcher.dispatch(targetInstance, action, parameters)
end

