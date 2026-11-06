--!strict
-- ══════════════════════════════════════════════════════════════════════
-- NVStudio Subsystem: nv_joint_math
-- Deskripsi: Modul Matematika Kinematika Sambungan (Joints) & Transformasi
-- Menyediakan kalkulasi C0/C1 presisi, pemindahan poros tanpa dislokasi,
-- rotasi poros, penyelarasan koordinat, dan pencerminan simetri bilateral.
-- ══════════════════════════════════════════════════════════════════════

local JointMath = {}

local EPSILON = 1e-6

-- ── 1. Hitung Offset Awal C0 & C1 ─────────────────────────────────────────────
-- Menghubungkan Part0 dan Part1 tanpa mengubah posisi relatif fisik saat ini
function JointMath.computeInitialOffsets(part0: BasePart, part1: BasePart): (CFrame, CFrame)
	local c0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	local c1 = CFrame.identity
	return c0, c1
end

-- ── 2. Geser Poros Sendi di Koordinat Dunia (World Delta) ─────────────────────
-- Menggeser titik pivot tanpa mendislokasi posisi part anak di dunia 3D
function JointMath.offsetPivot(joint: JointInstance, deltaWorld: Vector3): boolean
	local part0 = joint.Part0
	local part1 = joint.Part1
	if not part0 or not part1 then return false end

	local origJointWorld = part0.CFrame * joint.C0
	local desiredWorld = origJointWorld + deltaWorld

	local newC0 = part0.CFrame:ToObjectSpace(desiredWorld)
	local diff = joint.C0:ToObjectSpace(newC0)
	local newC1 = joint.C1 * diff

	joint.C0 = newC0
	joint.C1 = newC1
	return true
end

-- ── 3. Tetapkan Posisi Poros ke Titik Dunia Absolut (Set World Position) ──────
-- Memindahkan titik tumpu sendi tepat ke koordinat 3D yang diinginkan
function JointMath.setPivotWorld(joint: JointInstance, targetWorldPos: Vector3): boolean
	local part0 = joint.Part0
	local part1 = joint.Part1
	if not part0 or not part1 then return false end

	local origJointWorld = part0.CFrame * joint.C0
	local targetWorldCF = CFrame.new(targetWorldPos) * origJointWorld.Rotation

	local newC0 = part0.CFrame:ToObjectSpace(targetWorldCF)
	local diff = joint.C0:ToObjectSpace(newC0)
	local newC1 = joint.C1 * diff

	joint.C0 = newC0
	joint.C1 = newC1
	return true
end

-- ── 4. Rotasi Poros Sendi Tanpa Merusak Rig ───────────────────────────────────
-- Memutar orientasi poros sendi sebesar sudut Euler radian
function JointMath.rotatePivot(joint: JointInstance, rotEulerRad: Vector3): boolean
	local part0 = joint.Part0
	local part1 = joint.Part1
	if not part0 or not part1 then return false end

	local rotCF = CFrame.Angles(rotEulerRad.X, rotEulerRad.Y, rotEulerRad.Z)
	joint.C0 = joint.C0 * rotCF
	joint.C1 = joint.C1 * rotCF
	return true
end

-- ── 5. Reset Poros Sendi ke Pusat Part Anak ───────────────────────────────────
-- Mengembalikan poros sendi ke origin geometris Part1
function JointMath.resetPivot(joint: JointInstance): boolean
	local part0 = joint.Part0
	local part1 = joint.Part1
	if not part0 or not part1 then return false end

	joint.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	joint.C1 = CFrame.identity
	return true
end

-- ── 6. Selaraskan Orientasi Poros ke Part0 atau Part1 ─────────────────────────
-- Menjaga posisi poros di dunia tetap sama, tetapi rotasinya mengikuti part referensi
function JointMath.alignJoint(joint: JointInstance, alignTo: "Part0" | "Part1"): boolean
	local part0 = joint.Part0
	local part1 = joint.Part1
	if not part0 or not part1 then return false end

	local pivotWorldPos = (part0.CFrame * joint.C0).Position
	local refCF = alignTo == "Part0" and part0.CFrame or part1.CFrame
	local targetWorldCF = CFrame.new(pivotWorldPos) * refCF.Rotation

	local newC0 = part0.CFrame:ToObjectSpace(targetWorldCF)
	local diff = joint.C0:ToObjectSpace(newC0)
	local newC1 = joint.C1 * diff

	joint.C0 = newC0
	joint.C1 = newC1
	return true
end

-- ── 7. Refleksi CFrame Sumbu X Simetris (Bilateral Mirroring) ──────────────────
-- Mencerminkan CFrame melewati bidang sagittal (sumbu X)
function JointMath.mirrorCFrame(cf: CFrame): CFrame
	local x, y, z,
		r00, r01, r02,
		r10, r11, r12,
		r20, r21, r22 = cf:GetComponents()

	-- Refleksi koordinat posisi dan rotasi M_x * R * M_x
	return CFrame.new(
		-x, y, z,
		r00, -r01, -r02,
		-r10, r11, r12,
		-r20, r21, r22
	)
end

-- ── 8. Cerminkan Sendi Bilateral Kiri <-> Kanan ────────────────────────────────
-- Menerapkan C0 dan C1 yang telah dicerminkan dari sumber ke sendi target
function JointMath.mirrorJoint(sourceJoint: JointInstance, targetJoint: JointInstance): boolean
	if not sourceJoint or not targetJoint then return false end
	targetJoint.C0 = JointMath.mirrorCFrame(sourceJoint.C0)
	targetJoint.C1 = JointMath.mirrorCFrame(sourceJoint.C1)
	return true
end

-- ── 9. Dapatkan Posisi Poros di Dunia ─────────────────────────────────────────
function JointMath.getJointWorldPosition(joint: JointInstance): Vector3?
	local part0 = joint.Part0
	if not part0 then return nil end
	return (part0.CFrame * joint.C0).Position
end

return JointMath

