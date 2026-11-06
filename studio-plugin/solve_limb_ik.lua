--!strict
-- ══════════════════════════════════════════════════════════════════════
-- Skill Module: solve_limb_ik
-- Deskripsi: Semantic Tool untuk AI Agent menghitung orientasi sendi
-- lengan / kaki menuju koordinat sasaran 3D secara analitis O(1).
-- ══════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local kinematicsMod = script.Parent:WaitForChild("nv_kinematics")
local Kinematics = require(kinematicsMod)

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
	if not targetInstance then
		return { status = "error", error = "Target karakter rig untuk solve_limb_ik tidak ditemukan: " .. tostring(targetPath) }
	end

	local rigInfo = Kinematics.inspectRig(targetInstance:IsA("Model") and targetInstance or targetInstance:FindFirstAncestorOfClass("Model") :: any)
	if not rigInfo then
		return { status = "error", error = "Target bukan model karakter rig (R6/R15) yang valid: " .. targetInstance:GetFullName() }
	end

	local payload: { [string]: any } = {}
	pcall(function()
		if type(data) == "table" then payload = data
		else payload = HttpService:JSONDecode(tostring(data)) end
	end)

	local limb = tostring(payload.limb or "RightArm")
	local goalArr = payload.goal
	if not goalArr or type(goalArr) ~= "table" or #goalArr < 3 then
		return { status = "error", error = "Parameter 'goal' [X, Y, Z] wajib diisi." }
	end

	local goalPos = Vector3.new(goalArr[1], goalArr[2], goalArr[3])
	local polePos: Vector3? = nil
	if payload.pole and type(payload.pole) == "table" and #payload.pole >= 3 then
		polePos = Vector3.new(payload.pole[1], payload.pole[2], payload.pole[3])
	end

	local apply = payload.apply_to_rig ~= false
	local solved = Kinematics.solveLimb(rigInfo, limb, goalPos, polePos, apply)

	if not solved then
		return { status = "error", error = "Gagal menyelesaikan IK untuk anggota tubuh: " .. limb }
	end

	local resultC0: { [string]: any } = {}
	for mName, cf in pairs(solved) do
		resultC0[mName] = { t = "CFrame", v = { cf:GetComponents() } }
	end

	return {
		status = "success",
		result = {
			limb = limb,
			rigType = rigInfo.isR15 and "R15" or "R6",
			applied = apply,
			targetGoal = { goalPos.X, goalPos.Y, goalPos.Z },
			solvedMotors = resultC0
		}
	}
end

