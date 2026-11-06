--!strict
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_vfx_serializer
-- Deskripsi: Serializer & Deserializer 1:1 Efek Visual Roblox
-- Mengonversi seluruh properti ParticleEmitter, Beam, Trail, Light,
-- dan Attachment menjadi tabel data murni (JSON-safe) dan merekonstruksinya
-- dengan fidelitas 100% pada proyek Roblox mana saja.
-- ══════════════════════════════════════════════════════════════════════

local Serializer = {}

-- ── 1. Property Whitelist Per ClassName ───────────────────────────────────────
local PROPERTY_WHITELISTS: { [string]: { string } } = {
	ParticleEmitter = {
		"Name", "Enabled", "Texture", "Color", "Size", "Transparency",
		"Acceleration", "Drag", "EmissionDirection", "Lifetime",
		"LightEmission", "LightInfluence", "Orientation", "Rate",
		"RotSpeed", "Rotation", "Shape", "ShapeInOut", "ShapePartial",
		"ShapeStyle", "Speed", "SpreadAngle", "Squash",
		"FlipbookFramerate", "FlipbookLayout", "FlipbookMode", "FlipbookStartRandom",
		"ZOffset", "Brightness", "TimeScale", "VelocityInheritance", "WindAffects"
	},
	Beam = {
		"Name", "Enabled", "Attachment0", "Attachment1", "Color",
		"CurveSize0", "CurveSize1", "FaceCamera", "LightEmission",
		"LightInfluence", "Segments", "Texture", "TextureLength",
		"TextureMode", "TextureSpeed", "Transparency", "Width0",
		"Width1", "ZOffset", "Brightness"
	},
	Trail = {
		"Name", "Enabled", "Attachment0", "Attachment1", "Color",
		"FaceCamera", "LightEmission", "LightInfluence", "Lifetime",
		"MaxLength", "MinLength", "Texture", "TextureLength",
		"TextureMode", "Transparency", "WidthScale", "Brightness"
	},
	Attachment = {
		"Name", "Visible", "CFrame"
	},
	PointLight = {
		"Name", "Enabled", "Brightness", "Color", "Range", "Shadows"
	},
	SpotLight = {
		"Name", "Enabled", "Brightness", "Color", "Range", "Shadows", "Angle", "Face"
	},
	SurfaceLight = {
		"Name", "Enabled", "Brightness", "Color", "Range", "Shadows", "Face"
	},
	Highlight = {
		"Name", "Enabled", "FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency", "DepthMode"
	}
}

-- ── 2. Helper: Encode Roblox Values ke Pure Table ─────────────────────────────
local function encodeValue(val: any, nodeIndexMap: { [Instance]: number }): any
	local valType = typeof(val)

	if valType == "nil" or valType == "string" or valType == "number" or valType == "boolean" then
		return val
	elseif valType == "Vector3" then
		return { t = "Vector3", v = { val.X, val.Y, val.Z } }
	elseif valType == "Vector2" then
		return { t = "Vector2", v = { val.X, val.Y } }
	elseif valType == "CFrame" then
		return { t = "CFrame", v = { val:GetComponents() } }
	elseif valType == "Color3" then
		return { t = "Color3", v = { val.R, val.G, val.B } }
	elseif valType == "NumberRange" then
		return { t = "NumberRange", v = { val.Min, val.Max } }
	elseif valType == "NumberSequence" then
		local kps = {}
		for _, kp in ipairs(val.Keypoints) do
			table.insert(kps, { kp.Time, kp.Value, kp.Envelope })
		end
		return { t = "NumberSequence", v = kps }
	elseif valType == "ColorSequence" then
		local kps = {}
		for _, kp in ipairs(val.Keypoints) do
			table.insert(kps, {
				kp.Time,
				{ t = "Color3", v = { kp.Value.R, kp.Value.G, kp.Value.B } }
			})
		end
		return { t = "ColorSequence", v = kps }
	elseif valType == "EnumItem" then
		return { t = "EnumItem", e = tostring(val.EnumType), v = val.Name }
	elseif valType == "Instance" then
		local idx = nodeIndexMap[val]
		if idx then
			return { t = "Ref", v = idx }
		end
		return { t = "InstanceName", v = val.Name }
	end

	return tostring(val)
end

-- ── 3. Helper: Decode Pure Table ke Roblox Values ──────────────────────────────
local function decodeValue(val: any, createdNodes: { [number]: Instance }, scale: number?): any
	if type(val) ~= "table" or not val.t then
		return val
	end

	local t = val.t
	local v = val.v
	local s = scale or 1

	if t == "Vector3" then
		return Vector3.new(v[1] * s, v[2] * s, v[3] * s)
	elseif t == "Vector2" then
		return Vector2.new(v[1], v[2])
	elseif t == "CFrame" then
		local c = v
		if s ~= 1 then
			return CFrame.new(c[1] * s, c[2] * s, c[3] * s, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		end
		return CFrame.new(table.unpack(c))
	elseif t == "Color3" then
		return Color3.new(v[1], v[2], v[3])
	elseif t == "NumberRange" then
		local minV = tonumber(v[1]) or 0
		local maxV = tonumber(v[2]) or minV
		return NumberRange.new(math.min(minV, maxV), math.max(minV, maxV))
	elseif t == "NumberSequence" then
		local kps = {}
		for _, kp in ipairs(v) do
			if type(kp) == "table" then
				local timeVal = math.clamp(tonumber(kp[1]) or 0, 0, 1)
				local numVal = (tonumber(kp[2]) or 0) * s
				local envVal = (tonumber(kp[3]) or 0) * s
				table.insert(kps, NumberSequenceKeypoint.new(timeVal, numVal, envVal))
			end
		end
		if #kps >= 2 then
			table.sort(kps, function(a, b) return a.Time < b.Time end)
			if kps[1].Time ~= 0 then
				kps[1] = NumberSequenceKeypoint.new(0, kps[1].Value, kps[1].Envelope)
			end
			if kps[#kps].Time ~= 1 then
				kps[#kps] = NumberSequenceKeypoint.new(1, kps[#kps].Value, kps[#kps].Envelope)
			end
			for i = 2, #kps do
				if kps[i].Time <= kps[i - 1].Time then
					local newT = math.min(1.0, kps[i - 1].Time + 0.001)
					kps[i] = NumberSequenceKeypoint.new(newT, kps[i].Value, kps[i].Envelope)
				end
			end
			return NumberSequence.new(kps)
		elseif #kps == 1 then
			return NumberSequence.new(kps[1].Value)
		end
		return NumberSequence.new(0)
	elseif t == "ColorSequence" then
		local kps = {}
		for _, kp in ipairs(v) do
			if type(kp) == "table" and kp[2] then
				local timeVal = math.clamp(tonumber(kp[1]) or 0, 0, 1)
				local col = kp[2].v or { 1, 1, 1 }
				table.insert(kps, ColorSequenceKeypoint.new(timeVal, Color3.new(col[1] or 1, col[2] or 1, col[3] or 1)))
			end
		end
		if #kps >= 2 then
			table.sort(kps, function(a, b) return a.Time < b.Time end)
			if kps[1].Time ~= 0 then
				kps[1] = ColorSequenceKeypoint.new(0, kps[1].Value)
			end
			if kps[#kps].Time ~= 1 then
				kps[#kps] = ColorSequenceKeypoint.new(1, kps[#kps].Value)
			end
			for i = 2, #kps do
				if kps[i].Time <= kps[i - 1].Time then
					local newT = math.min(1.0, kps[i - 1].Time + 0.001)
					kps[i] = ColorSequenceKeypoint.new(newT, kps[i].Value)
				end
			end
			return ColorSequence.new(kps)
		elseif #kps == 1 then
			return ColorSequence.new(kps[1].Value)
		end
		return ColorSequence.new(Color3.new(1, 1, 1))
	elseif t == "EnumItem" then
		local enumGroup = Enum[val.e]
		if enumGroup and enumGroup[v] then
			return enumGroup[v]
		end
		return nil
	elseif t == "Ref" then
		return createdNodes[v]
	end

	return val
end

-- ── 4. Serializer: Mengonversi Instance Hierarchy Menjadi Pure Table ─────────
function Serializer.serialize(rootInstance: Instance): { [string]: any }
	assert(typeof(rootInstance) == "Instance", "Root instance harus berupa Roblox Instance")

	-- Kumpulkan seluruh node VFX yang didukung
	local rawNodes: { Instance } = {}
	local nodeIndexMap: { [Instance]: number } = {}

	local function collect(inst: Instance)
		if PROPERTY_WHITELISTS[inst.ClassName] or inst:IsA("Folder") or inst:IsA("Model") or inst:IsA("Configuration") or inst == rootInstance then
			table.insert(rawNodes, inst)
			nodeIndexMap[inst] = #rawNodes
		end
		for _, child in ipairs(inst:GetChildren()) do
			collect(child)
		end
	end

	collect(rootInstance)

	local nodes = {}
	local stats = { emitters = 0, beams = 0, trails = 0, lights = 0 }

	for i, inst in ipairs(rawNodes) do
		local className = inst.ClassName
		local parentIndex = nil
		if inst ~= rootInstance and inst.Parent then
			parentIndex = nodeIndexMap[inst.Parent]
		end

		local props = {}
		local whitelist = PROPERTY_WHITELISTS[className]
		if whitelist then
			for _, propName in ipairs(whitelist) do
				local ok, propVal = pcall(function() return (inst :: any)[propName] end)
				if ok and propVal ~= nil then
					props[propName] = encodeValue(propVal, nodeIndexMap)
				end
			end
		else
			props["Name"] = inst.Name
		end

		-- Perbarui statistik
		if className == "ParticleEmitter" then
			stats.emitters += 1
		elseif className == "Beam" then
			stats.beams += 1
		elseif className == "Trail" then
			stats.trails += 1
		elseif className:find("Light") then
			stats.lights += 1
		end

		nodes[i] = {
			class = className,
			name = inst.Name,
			parent = parentIndex,
			properties = props
		}
	end

	return {
		version = 1,
		rootName = rootInstance.Name,
		rootClass = rootInstance.ClassName,
		nodeCount = #nodes,
		stats = stats,
		nodes = nodes
	}
end

-- ── 5. Deserializer: Merekonstruksi Roblox Instances dari Pure Table ───────────
function Serializer.deserialize(treeData: { [string]: any }, targetParent: Instance, options: { scale: number?, enabled: boolean? }?): { [string]: any }
	assert(type(treeData) == "table" and treeData.nodes, "Format data treeData tidak valid")
	assert(typeof(targetParent) == "Instance", "TargetParent harus berupa Instance")

	local opts = options or {}
	local scale = tonumber(opts.scale) or 1
	local createdNodes: { [number]: Instance } = {}
	local refDeferred: { { inst: Instance, propName: string, refIdx: number } } = {}
	local errors: { string } = {}
	local createdCount = 0

	-- Pass 1: Buat semua instance dan tetapkan parent dasar
	for i, node in ipairs(treeData.nodes) do
		local ok, inst = pcall(function()
			-- Jika node pertama adalah root dan bertipe Part/Model pembungkus, kita bisa menaruh isinya langsung
			if i == 1 and (node.class == "Folder" or node.class == "Model" or node.class == "Configuration") and targetParent:IsA("BasePart") then
				-- Buat container pembungkus di targetParent
				local container = Instance.new(node.class)
				container.Name = node.name or "NV_VFX"
				container.Parent = targetParent
				return container
			elseif i == 1 and (node.class == "ParticleEmitter" or node.class == "Beam" or node.class == "Trail" or node.class == "Attachment") then
				local newInst = Instance.new(node.class)
				newInst.Name = node.name or "NV_VFX"
				newInst.Parent = targetParent
				return newInst
			else
				local newInst = Instance.new(node.class)
				newInst.Name = node.name or ("Node_" .. tostring(i))
				return newInst
			end
		end)

		if ok and inst then
			createdNodes[i] = inst
			createdCount += 1
		else
			table.insert(errors, "Gagal membuat instance untuk node " .. tostring(i) .. ": " .. tostring(inst))
		end
	end

	-- Pass 2: Hubungkan hierarki Parent
	for i, node in ipairs(treeData.nodes) do
		local inst = createdNodes[i]
		if inst and i > 1 then
			local parentIdx = node.parent
			if parentIdx and createdNodes[parentIdx] then
				inst.Parent = createdNodes[parentIdx]
			else
				inst.Parent = createdNodes[1] or targetParent
			end
		end
	end

	-- Pass 3: Terapkan Properti (dengan scaling & deferred Attachment ref)
	for i, node in ipairs(treeData.nodes) do
		local inst = createdNodes[i]
		if inst and node.properties then
			for propName, propData in pairs(node.properties) do
				if type(propData) == "table" and propData.t == "Ref" then
					table.insert(refDeferred, { inst = inst, propName = propName, refIdx = propData.v })
				else
					local pScale = (propName == "Size" or propName == "Width0" or propName == "Width1" or propName == "Speed" or propName == "Acceleration") and scale or 1
					local decoded = decodeValue(propData, createdNodes, pScale)
					if decoded ~= nil then
						pcall(function()
							if propName == "Enabled" and opts.enabled ~= nil then
								(inst :: any)[propName] = opts.enabled
							else
								(inst :: any)[propName] = decoded
							end
						end)
					end
				end
			end
		end
	end

	-- Pass 4: Hubungkan Deferred Attachment References (Beam / Trail)
	for _, ref in ipairs(refDeferred) do
		local targetNode = createdNodes[ref.refIdx]
		if targetNode and targetNode:IsA("Attachment") then
			pcall(function()
				(ref.inst :: any)[ref.propName] = targetNode
			end)
		end
	end

	return {
		status = #errors == 0 and "success" or "partial",
		createdCount = createdCount,
		root = createdNodes[1] or targetParent,
		errors = errors
	}
end

return Serializer

