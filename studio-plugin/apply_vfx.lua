--!strict
-- ══════════════════════════════════════════════════════════════════════
-- Skill Module: apply_vfx
-- Deskripsi: Menerapkan tabel data VFX murni ke instance target di Studio
-- ══════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local serializerMod = script.Parent:WaitForChild("nv_vfx_serializer")
local Serializer = require(serializerMod)

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
	if not targetInstance then
		return { status = "error", error = "Target instance untuk apply_vfx tidak ditemukan: " .. tostring(targetPath) }
	end

	local payload = {}
	local ok, err = pcall(function()
		if type(data) == "table" then
			payload = data
		else
			payload = HttpService:JSONDecode(tostring(data))
		end
	end)

	if not ok or type(payload) ~= "table" then
		return { status = "error", error = "Format payload VFX tidak valid: " .. tostring(err) }
	end

	-- Extract treeData (bisa di payload.data atau langsung di payload)
	local treeData = payload.data or payload
	if not treeData.nodes then
		return { status = "error", error = "Payload tidak memiliki struktur 'nodes' yang valid untuk deserialisasi." }
	end

	local scale = tonumber(payload.scale) or 1
	local enabled = payload.enabled

	local desResult = Serializer.deserialize(treeData, targetInstance, {
		scale = scale,
		enabled = enabled
	})

	if desResult.status == "error" then
		return {
			status = "error",
			error = "Gagal merekonstruksi VFX: " .. table.concat(desResult.errors or {}, "; ")
		}
	end

	return {
		status = "success",
		result = {
			message = string.format("Berhasil menerapkan VFX '%s' (%d node) ke '%s'", tostring(treeData.rootName or "VFX"), desResult.createdCount, targetInstance:GetFullName()),
			createdCount = desResult.createdCount,
			errors = desResult.errors
		}
	}
end

