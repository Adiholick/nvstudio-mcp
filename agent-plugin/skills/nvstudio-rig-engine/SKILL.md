---
name: nvstudio-rig-engine
description: Panduan AI Agent untuk memeriksa, membuat, mengedit poros (C0/C1 tanpa dislokasi), auto-rigging R6/R15/senjata, dan mengelas assembly model di Roblox Studio menggunakan NV-Rig Engine.
---

# NV-Rig Engine: Headless Modular Rigging Suite Guide

Panduan resmi untuk AI Agent dalam mengoperasikan sistem rigging Roblox secara headless menggunakan **NV-Rig Engine**. Modul ini melengkapi **NV-Animation Engine** dan **NV-VFX Subsystem** untuk menghasilkan alur kerja karakter yang lengkap dan anti-halusinasi.

---

## 1. Kapan Harus Menggunakan NV-Rig Engine

Gunakan tool-tool NV-Rig Engine saat:
- Karakter atau model impor belum memiliki `Motor6D` / sendi gerak.
- Titik tumpu (*pivot*) bahu, siku, lutut, atau sayap berada di posisi yang salah dan perlu digeser tanpa merusak susunan visual part.
- Bagian tubuh masih ter-anchor (`Anchored = true`) sehingga animasi tidak dapat menggerakkannya.
- Ingin menautkan senjata, perisai, atau pedang ke tangan karakter (`Weapon Grip`).
- Ingin mengelas (*weld*) seluruh komponen helm, armor, atau kendaraan menjadi satu kesatuan kaku.
- Ingin menyalin konfigurasi sendi sisi kiri ke sisi kanan secara simetris cermin (*X-axis mirror*).

---

## 2. Inspeksi Rig Mendalam (`inspect_rig`)

Selalu awali dengan memanggil `inspect_rig` sebelum melakukan rigging atau animasi untuk mendeteksi potensi masalah secara dini:

```json
{
  "target": "Workspace.CharacterModel"
}
```

### Yang Didiagnosis oleh `inspect_rig`:
1. **Daftar Joint**: Semua `Motor6D` dan `Weld`, lengkap dengan nama `Part0`, `Part1`, $C_0$, $C_1$, dan koordinat poros dunia 3D.
2. **Anchor Warning**: Mendeteksi part yang masih `Anchored = true`. Part anak yang ter-anchor tidak akan bergerak saat dianimasikan!
3. **Circular Dependency**: Mendeteksi jika ada siklus sambungan tertutup yang dapat membekukan simulasi fisika Roblox.
4. **Root Part**: Menemukan calon part induk utama (misal `HumanoidRootPart` atau `Torso`).

---

## 3. Auto-Rigging Cerdas 1-Klik (`auto_rig`)

Alih-alih membuat belasan sendi satu per satu, gunakan `auto_rig` untuk membangun pohon hierarki standar dalam sekejap:

### A. Auto-Rig Avatar R15
Membangun 15 sambungan Motor6D lengkap (`Root`, `Waist`, `Neck`, bahu, siku, pergelangan tangan, panggul, lutut, pergelangan kaki):
```json
{
  "target": "Workspace.CustomR15Avatar",
  "rig_type": "R15"
}
```

### B. Auto-Rig Avatar R6
Membangun 6 sambungan Motor6D klasik (`RootJoint`, `Neck`, `Left Shoulder`, `Right Shoulder`, `Left Hip`, `Right Hip`):
```json
{
  "target": "Workspace.CustomR6Avatar",
  "rig_type": "R6"
}
```

### C. Auto-Rig Senjata / Tool
Menghubungkan senjata ke tangan karakter dengan `Motor6D` dinamai `WeaponGrip` dan mengelas seluruh bagian senjata lainnya ke `Handle`:
```json
{
  "target": "Workspace.Knight",
  "rig_type": "Weapon",
  "weapon_target": "Workspace.GreatSword",
  "target_limb": "RightHand"
}
```

---

## 4. Manipulasi Poros Sendi Presisi (`edit_rig_joint`)

Gunakan `edit_rig_joint` untuk menggeser, memutar, mereset, menyelaraskan, atau membuat sendi baru.

### A. Geser Poros Sendi (Non-Dislocation Law)
Menggeser titik engsel sendi di dunia nyata tanpa membuat part anak terlempar:
```json
{
  "target": "Workspace.CharacterModel",
  "action": "edit_pivot",
  "joint_name": "RightShoulder",
  "delta_world": [0, 0.5, 0]
}
```

### B. Pindahkan Poros ke Koordinat Dunia Tertentu
Menempatkan titik engsel tepat pada koordinat target 3D:
```json
{
  "target": "Workspace.CharacterModel",
  "action": "edit_pivot",
  "joint_name": "RightElbow",
  "target_world": [10.5, 5.0, -12.3]
}
```

### C. Putar Orientasi Poros
Memutar orientasi sumbu lokal sendi sebesar sudut Euler derajat:
```json
{
  "target": "Workspace.CharacterModel",
  "action": "rotate_pivot",
  "joint_name": "Neck",
  "rotate_euler_deg": [0, 90, 0]
}
```

### D. Reset Poros ke Pusat Part Anak
Mengembalikan $C_0$ langsung ke origin Part1 dan mengosongkan $C_1$:
```json
{
  "target": "Workspace.CharacterModel",
  "action": "reset_pivot",
  "joint_name": "LeftShoulder"
}
```

### E. Buat Sendi Baru Secara Spesifik
```json
{
  "target": "Workspace.CharacterModel",
  "action": "create_joint",
  "joint_name": "TailJoint1",
  "part0": "LowerTorso",
  "part1": "TailBase"
}
```

---

## 5. Pengelasan Assembly Model (`weld_assembly`)

Gunakan `weld_assembly` untuk menyatukan seluruh komponen pada sebuah model (aksesori, sayap dekoratif, helm, armor, kendaraan) ke part jangkar utama:
```json
{
  "target": "Workspace.ArmorSet",
  "primary_part": "Chestplate"
}
```
*Catatan: Semua part anak otomatis di-unanchor dan dilas ke `Chestplate` menggunakan transformasi $C_0$ yang presisi.*

---

## 6. Pencerminan Simetri Bilateral (`mirror_rig`)

Jika Anda telah mengonfigurasi poros sendi sisi kiri (`LeftShoulder`, `LeftElbow`, dll.), gunakan `mirror_rig` untuk mencerminkan nilai $C_0$ dan $C_1$ ke sisi kanan secara simetris sepanjang sumbu $X$:
```json
{
  "target": "Workspace.CharacterModel",
  "source_side": "Left"
}
```

---

## 7. Alur Kerja Komprehensif: Rigging $\rightarrow$ Animasi $\rightarrow$ VFX

Ketika pengguna meminta animasi pertarungan lengkap:
1. **Langkah 1**: Panggil `inspect_rig` pada karakter. Jika belum ada joint, jalankan `auto_rig` (mode `"R15"`).
2. **Langkah 2**: Jika ada senjata, panggil `weld_assembly` pada senjata, lalu panggil `auto_rig` mode `"Weapon"`.
3. **Langkah 3**: Buat animasi halus menggunakan `animate_character` (misal aksi `"melee_slash"` dengan `vfx_events`).
4. **Langkah 4**: Pasang efek visual menggunakan `apply_vfx` dari database persisten.
5. **Langkah 5**: Scrub timeline menggunakan `scrub_timeline` ke timestamp tebasan untuk memverifikasi pose dan partikel.

