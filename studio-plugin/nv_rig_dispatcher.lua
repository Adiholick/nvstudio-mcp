--!strict
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_rig_dispatcher
-- Deskripsi: Headless Modular Command Dispatcher untuk NV-Rig Engine
-- Mengelola routing perintah rigging dari AI Agent LLM, eksekusi
-- deterministik, inspeksi topologi rig, dan diagnostik otomatis.
-- ══════════════════════════════════════════════════════════════════════

local jointMathMod = script.Parent:WaitForChild("nv_joint_math")
local JointMath = require(jointMathMod)
local autoRiggerMod = script.Parent:WaitForChild("nv_auto_rigger")
local AutoRigger = require(autoRiggerMod)

local Dispatcher = {}

-- ── 1. Inspeksi & Diagnostik Rig Mendalam (Deep Topological Inspection) ────────
function Dispatcher.inspectRig(targetInstance: Instance): { [string]: any }
	if not targetInstance then
		return { status = "error", error = "Target instance tidak ditemukan." }
	end

	local model = targetInstance:IsA("Model") and targetInstance or targetInstance:FindFirstAncestorOfClass("Model")
	if not model then
		model = targetInstance:IsA("Folder") and targetInstance or targetInstance:IsA("BasePart") and targetInstance.Parent :: any
	end
	if not model then
		return { status = "error", error = "Target harus berada di dalam Model atau Folder." }
	end

	local parts: { [string]: { anchored: boolean, size: { number }, mass: number, className: string } } = {}
	local joints: { any } = {}
	local parentToChildren: { [string]: { string } } = {}
	local childToParent: { [string]: string } = {}
	local rootCandidates: { string } = {}
	local anchoredCount = 0
	local totalParts = 0

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			totalParts += 1
			if desc.Anchored then anchoredCount += 1 end
			parts[desc.Name] = {
				anchored = desc.Anchored,
				size = { desc.Size.X, desc.Size.Y, desc.Size.Z },
				mass = desc:GetMass(),
				className = desc.ClassName
			}
		elseif desc:IsA("Motor6D") or desc:IsA("Weld") then
			local p0Name = desc.Part0 and desc.Part0.Name or "nil"
			local p1Name = desc.Part1 and desc.Part1.Name or "nil"
			local pivotWorld = JointMath.getJointWorldPosition(desc)

			table.insert(joints, {
				name = desc.Name,
				type = desc.ClassName,
				part0 = p0Name,
				part1 = p1Name,
				parent = desc.Parent and desc.Parent.Name or "nil",
				pivotWorld = pivotWorld and { pivotWorld.X, pivotWorld.Y, pivotWorld.Z } or nil,
				c0 = { desc.C0:GetComponents() },
				c1 = { desc.C1:GetComponents() }
			})

			if p0Name ~= "nil" and p1Name ~= "nil" then
				if not parentToChildren[p0Name] then parentToChildren[p0Name] = {} end
				table.insert(parentToChildren[p0Name], p1Name)
				childToParent[p1Name] = p0Name
			end
		end
	end

	-- Deteksi Root Part (Part yang tidak memiliki Part0 di atasnya)
	for partName, _ in pairs(parts) do
		if not childToParent[partName] then
			table.insert(rootCandidates, partName)
		end
	end

	-- Deteksi Loop / Circular Dependency dalam hierarki
	local hasCycle = false
	local cyclePath = ""
	local visited: { [string]: boolean } = {}
	local recStack: { [string]: boolean } = {}

	local function checkCycle(node: string, path: string): boolean
		visited[node] = true
		recStack[node] = true
		local children = parentToChildren[node] or {}
		for _, child in ipairs(children) do
			if not visited[child] then
				if checkCycle(child, path .. " -> " .. child) then return true end
			elseif recStack[child] then
				cyclePath = path .. " -> " .. child
				return true
			end
		end
		recStack[node] = false
		return false
	end

	for _, root in ipairs(rootCandidates) do
		if checkCycle(root, root) then
			hasCycle = true
			break
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rigType = humanoid and (humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6") or "Custom"

	local warnings: { string } = {}
	if hasCycle then
		table.insert(warnings, "Ditemukan siklus tertutup (Circular Dependency): " .. cyclePath)
	end
	if anchoredCount > 1 then
		table.insert(warnings, string.format("Ada %d part yang masih 'Anchored = true'. Karakter mungkin tidak dapat bergerak/beranimasi.", anchoredCount))
	end
	if #rootCandidates > 1 then
		table.insert(warnings, "Ditemukan lebih dari 1 calon root part: " .. table.concat(rootCandidates, ", "))
	end

	return {
		status = "success",
		modelName = model.Name,
		rigType = rigType,
		totalParts = totalParts,
		totalJoints = #joints,
		rootParts = rootCandidates,
		hasCycle = hasCycle,
		warnings = warnings,
		joints = joints,
		parts = parts
	}
end

-- ── 2. Buat Sambungan Sendi Baru (Create Joint / Weld) ─────────────────────────
function Dispatcher.createJoint(targetModel: Instance, params: { [string]: any }): { [string]: any }
	local part0Name = params.part0
	local part1Name = params.part1
	local jointType = params.joint_type or "Motor6D"
	local jointName = params.name

	if not part0Name or not part1Name then
		return { status = "error", error = "Parameter 'part0' dan 'part1' wajib disertakan." }
	end

	local part0 = targetModel:FindFirstChild(part0Name, true) :: BasePart?
	local part1 = targetModel:FindFirstChild(part1Name, true) :: BasePart?

	if not part0 or not part0:IsA("BasePart") then
		return { status = "error", error = "Part0 '" .. tostring(part0Name) .. "' tidak ditemukan." }
	end
	if not part1 or not part1:IsA("BasePart") then
		return { status = "error", error = "Part1 '" .. tostring(part1Name) .. "' tidak ditemukan." }
	end

	part1.Anchored = false
	local joint: JointInstance
	if jointType == "Weld" then
		joint = Instance.new("Weld")
	else
		joint = Instance.new("Motor6D")
	end

	joint.Name = jointName or (jointType == "Motor6D" and part1.Name or (part0.Name .. "_" .. part1.Name))
	joint.Part0 = part0
	joint.Part1 = part1
	local c0, c1 = JointMath.computeInitialOffsets(part0, part1)
	joint.C0 = c0
	joint.C1 = c1
	joint.Parent = part0

	return {
		status = "success",
		jointName = joint.Name,
		jointType = joint.ClassName,
		part0 = part0.Name,
		part1 = part1.Name,
		message = string.format("Berhasil membuat %s '%s' antara '%s' dan '%s'", joint.ClassName, joint.Name, part0.Name, part1.Name)
	}
end

-- ── 3. Edit Poros Sendi (Offset World / Target Position) ───────────────────────
function Dispatcher.editPivot(targetModel: Instance, params: { [string]: any }): { [string]: any }
	local jointName = params.joint_name or params.name
	if not jointName then
		return { status = "error", error = "Parameter 'joint_name' wajib diisi." }
	end

	local joint: JointInstance? = nil
	for _, desc in ipairs(targetModel:GetDescendants()) do
		if (desc:IsA("Motor6D") or desc:IsA("Weld")) and desc.Name == jointName then
			joint = desc
			break
		end
	end

	if not joint then
		return { status = "error", error = "Joint '" .. tostring(jointName) .. "' tidak ditemukan pada model." }
	end

	local success = false
	if params.delta_world and type(params.delta_world) == "table" and #params.delta_world >= 3 then
		local d = params.delta_world
		success = JointMath.offsetPivot(joint, Vector3.new(d[1], d[2], d[3]))
	elseif params.target_world and type(params.target_world) == "table" and #params.target_world >= 3 then
		local p = params.target_world
		success = JointMath.setPivotWorld(joint, Vector3.new(p[1], p[2], p[3]))
	elseif params.rotate_euler_deg and type(params.rotate_euler_deg) == "table" and #params.rotate_euler_deg >= 3 then
		local r = params.rotate_euler_deg
		local rad = Vector3.new(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
		success = JointMath.rotatePivot(joint, rad)
	elseif params.reset == true then
		success = JointMath.resetPivot(joint)
	elseif params.align_to == "Part0" or params.align_to == "Part1" then
		success = JointMath.alignJoint(joint, params.align_to)
	else
		return { status = "error", error = "Tindakan edit pivot tidak spesifik. Berikan delta_world, target_world, rotate_euler_deg, reset, atau align_to." }
	end

	if not success then
		return { status = "error", error = "Gagal memodifikasi poros sendi '" .. jointName .. "'." }
	end

	local newPivot = JointMath.getJointWorldPosition(joint)
	return {
		status = "success",
		jointName = joint.Name,
		newPivotWorld = newPivot and { newPivot.X, newPivot.Y, newPivot.Z } or nil,
		newC0 = { joint.C0:GetComponents() },
		newC1 = { joint.C1:GetComponents() },
		message = "Poros sendi '" .. joint.Name .. "' berhasil diperbarui tanpa dislokasi part."
	}
end

-- ── 4. Cerminkan Sendi Simetri Bilateral (Mirror Joints) ──────────────────────
function Dispatcher.mirrorJoints(targetModel: Instance, params: { [string]: any }): { [string]: any }
	local sourceSide = params.source_side or "Left"
	local targetSide = sourceSide == "Left" and "Right" or "Left"

	local mirroredCount = 0
	local pairsProcessed: { string } = {}

	for _, desc in ipairs(targetModel:GetDescendants()) do
		if desc:IsA("Motor6D") or desc:IsA("Weld") then
			if string.find(desc.Name, sourceSide) then
				local targetName = string.gsub(desc.Name, sourceSide, targetSide)
				local targetJoint: JointInstance? = nil
				for _, d2 in ipairs(targetModel:GetDescendants()) do
					if (d2:IsA("Motor6D") or d2:IsA("Weld")) and d2.Name == targetName then
						targetJoint = d2
						break
					end
				end

				if targetJoint then
					JointMath.mirrorJoint(desc, targetJoint)
					mirroredCount += 1
					table.insert(pairsProcessed, desc.Name .. " -> " .. targetName)
				end
			end
		end
	end

	return {
		status = "success",
		sourceSide = sourceSide,
		targetSide = targetSide,
		mirroredCount = mirroredCount,
		pairs = pairsProcessed,
		message = string.format("Berhasil mencerminkan %d sendi dari %s ke %s", mirroredCount, sourceSide, targetSide)
	}
end

-- ── 5. Router Eksekusi Utama (Modular Dispatcher) ─────────────────────────────
function Dispatcher.dispatch(targetInstance: Instance, action: string, data: { [string]: any }): { [string]: any }
	if action == "inspect" then
		return Dispatcher.inspectRig(targetInstance)
	elseif action == "create_joint" or action == "create" then
		return Dispatcher.createJoint(targetInstance, data)
	elseif action == "create_weld" then
		data.joint_type = "Weld"
		return Dispatcher.createJoint(targetInstance, data)
	elseif action == "edit_pivot" or action == "edit" or action == "move_pivot" or action == "rotate_pivot" or action == "reset_pivot" or action == "align_joint" then
		return Dispatcher.editPivot(targetInstance, data)
	elseif action == "mirror" or action == "mirror_joints" then
		return Dispatcher.mirrorJoints(targetInstance, data)
	elseif action == "auto_rig_r6" or action == "rig_r6" then
		return AutoRigger.rigR6(targetInstance:IsA("Model") and targetInstance or targetInstance:FindFirstAncestorOfClass("Model") :: any)
	elseif action == "auto_rig_r15" or action == "rig_r15" then
		return AutoRigger.rigR15(targetInstance:IsA("Model") and targetInstance or targetInstance:FindFirstAncestorOfClass("Model") :: any)
	elseif action == "rig_weapon" or action == "attach_weapon" then
		local weapon = data.weapon_path and game:GetService("HttpService") -- akan di-resolve oleh caller jika ada path
		return AutoRigger.rigWeapon(targetInstance:IsA("Model") and targetInstance or targetInstance:FindFirstAncestorOfClass("Model") :: any, targetInstance, data.target_limb)
	elseif action == "weld_assembly" or action == "weld_all" then
		return AutoRigger.weldAssembly(targetInstance, nil)
	elseif action == "remove_joint" or action == "delete_joint" then
		local jointName = data.joint_name or data.name
		local removed = 0
		for _, desc in ipairs(targetInstance:GetDescendants()) do
			if (desc:IsA("Motor6D") or desc:IsA("Weld")) and (not jointName or desc.Name == jointName) then
				if data.reanchor == true and desc.Part1 then
					desc.Part1.Anchored = true
				end
				desc:Destroy()
				removed += 1
			end
		end
		return { status = "success", removedCount = removed, message = string.format("Berhasil menghapus %d joint", removed) }
	else
		return {
			status = "error",
			error = "Action tidak dikenal: '" .. tostring(action) .. "'. Pilihan: inspect, create_joint, create_weld, edit_pivot, auto_rig_r6, auto_rig_r15, weld_assembly, mirror_joints, remove_joint."
		}
	end
end

return Dispatcher

