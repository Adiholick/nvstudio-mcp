--!strict
-- ══════════════════════════════════════════════════════════════════════
-- Skill Module: scan_vfx
-- Deskripsi: Memindai efek visual (ParticleEmitter, Beam, Trail, Light)
-- pada objek target di Roblox Studio dan mengubahnya menjadi tabel murni
-- ══════════════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local serializerMod = script.Parent:WaitForChild("nv_vfx_serializer")
local Serializer = require(serializerMod)

local function detectCategory(name: string, data: any): string
	local lower = string.lower(name)
	if lower:find("slash") or lower:find("blade") or lower:find("sword") or lower:find("cut") then
		return "Slash"
	elseif lower:find("explosion") or lower:find("burst") or lower:find("blast") or lower:find("boom") or lower:find("fire") then
		return "Explosion"
	elseif lower:find("aura") or lower:find("glow") or lower:find("shield") or lower:find("barrier") then
		return "Aura"
	elseif lower:find("laser") or lower:find("beam") or lower:find("ray") then
		return "Beam"
	elseif lower:find("magic") or lower:find("spell") or lower:find("rune") or lower:find("circle") or lower:find("portal") then
		return "Magic"
	elseif lower:find("hit") or lower:find("impact") or lower:find("spark") or lower:find("clash") then
		return "Impact"
	elseif lower:find("projectile") or lower:find("bullet") or lower:find("arrow") or lower:find("missile") then
		return "Projectile"
	end
	return "Ambient"
end

return function(targetInstance: Instance?, data: any, ctx: any, targetPath: string?)
	if not targetInstance then
		return { status = "error", error = "Target instance untuk scan_vfx tidak ditemukan: " .. tostring(targetPath) }
	end

	local parsedData = {}
	if data and data ~= "" then
		pcall(function()
			if type(data) == "table" then
				parsedData = data
			else
				parsedData = HttpService:JSONDecode(tostring(data))
			end
		end)
	end

	local vfxName = parsedData.name or targetInstance.Name or "Unnamed_VFX"
	local rawCat = parsedData.category or detectCategory(vfxName, parsedData)
	local category = "Ambient"
	if type(rawCat) == "string" and #rawCat > 0 then
		category = string.upper(string.sub(rawCat, 1, 1)) .. string.lower(string.sub(rawCat, 2))
	end
	local tags = parsedData.tags or { string.lower(category) }

	local ok, serialized = pcall(function()
		return Serializer.serialize(targetInstance)
	end)

	if not ok or not serialized then
		return { status = "error", error = "Gagal memindai VFX: " .. tostring(serialized) }
	end

	if serialized.nodeCount == 0 or (serialized.stats.emitters == 0 and serialized.stats.beams == 0 and serialized.stats.trails == 0 and serialized.stats.lights == 0) then
		return {
			status = "error",
			error = "Objek '" .. targetInstance.Name .. "' tidak memiliki komponen VFX (ParticleEmitter, Beam, Trail, atau Light)."
		}
	end

	return {
		status = "success",
		result = {
			name = vfxName,
			category = category,
			tags = tags,
			description = parsedData.description or ("Scanned VFX from " .. targetInstance:GetFullName()),
			stats = serialized.stats,
			nodeCount = serialized.nodeCount,
			rootClass = serialized.rootClass,
			data = serialized
		}
	}
end

