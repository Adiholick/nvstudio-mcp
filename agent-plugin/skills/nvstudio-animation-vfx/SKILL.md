---
name: nvstudio-animation-vfx
description: Panduan AI Agent untuk membuat animasi karakter halus (Walk, Slash, Punch, Idle, Custom IK) menggunakan NV-Animation Engine dan mengelola efek visual lintas-proyek dengan NV-VFX Database di Roblox Studio.
---

# NVStudio Animation Engine & VFX Subsystem Guide

Panduan resmi untuk AI Agent dalam memanfaatkan kemampuan pembuatan animasi karakter manusiawi (*Human-like Motion Synthesis*) dan sistem efek visual portabel lintas-proyek.

---

## 1. Pembuatan Animasi Karakter (`animate_character`)

Gunakan tool `animate_character` untuk menghasilkan animasi yang halus (*smooth*) dengan kurva interpolasi Bezier, pelambatan *easing*, dan *LimbIK* analitis tanpa perlu menghitung sudut CFrame secara manual.

### Parameter Utama:
- `target`: Path ke Model karakter rig R6 atau R15 di Studio (contoh: `"Workspace.Dummy"`).
- `action`: Jenis gerakan yang ingin disintesis:
  - `"walk_cycle"`: Siklus berjalan seimbang dengan pergeseran berat badan dan ayunan tangan berlawanan.
  - `"melee_slash"`: Serangan tebasan pedang dengan ancang-ancang (*wind-up*), *acceleration snap*, dan *follow-through*.
  - `"punch"`: Pukulan terarah dengan pemanfaatan LimbIK ke sasaran dan putaran bahu.
  - `"idle_breath"`: Pernapasan lembut dengan ritme naik-turun dada dan sedikit kemiringan kepala.
  - `"custom"`: Pose kunci kustom yang disediakan di parameter `key_poses`.
- `parameters` (opsional):
  - `duration`: Durasi animasi dalam detik (contoh: `1.0`).
  - `intensity`: Skala intensitas gerakan (contoh: `1.2`).
  - `easing`: Jenis kurva interpolasi (`"QuadInOut"`, `"CubicInOut"`, `"BackOut"`, `"ElasticOut"`, dll).
  - `loop`: Boolean apakah animasi berulang (default: `true` untuk walk/idle, `false` untuk serangan).
  - `clipName`: Nama klip animasi di `AnimSaves`.

### Contoh Pemanggilan Tool:
```json
{
  "target": "Workspace.Dummy",
  "action": "melee_slash",
  "parameters": {
    "duration": 0.8,
    "intensity": 1.2,
    "easing": "CubicInOut",
    "loop": false,
    "clipName": "KatanaSlash"
  }
}
```

Hasilnya akan secara otomatis terkompilasi menjadi `KeyframeSequence` resmi di dalam folder `AnimSaves` karakter pada Studio.

---

## 2. Kalkulasi Kinematika Lengan / Kaki (`solve_limb_ik`)

Gunakan tool `solve_limb_ik` untuk mengarahkan telapak tangan atau kaki karakter ke target koordinat 3D secara instan menggunakan solver analitis sudut tertutup $O(1)$ (Hukum Cosinus).

### Parameter:
- `target`: Path ke karakter rig (contoh: `"Workspace.Dummy"`).
- `limb`: Anggota tubuh (`"LeftArm"`, `"RightArm"`, `"LeftLeg"`, atau `"RightLeg"`).
- `goal`: Array posisi 3D `[X, Y, Z]` di world space.
- `pole`: Array arah tekukan siku/lutut `[X, Y, Z]` (opsional).
- `apply_to_rig`: Boolean apakah langsung diterapkan ke sendi karakter di Studio (default: `true`).

---

## 3. Scrubbing Timeline & Preview VFX (`scrub_timeline`)

Gunakan tool `scrub_timeline` untuk menggeser playhead waktu animasi dan memicu semburan (burst) partikel VFX pada timestamp tertentu langsung di Viewport Studio tanpa perlu memutar animasi secara penuh:

### Parameter:
- `target`: Path model karakter rig atau folder VFX (contoh: `"Workspace.Dummy"`).
- `time`: Posisi timestamp waktu dalam detik (contoh: `0.35`).
- `action`: Aksi animasi yang di-scrub (`"melee_slash"`, `"walk_cycle"`, `"punch"`, `"idle_breath"`).
- `emit_vfx`: Boolean apakah memicu semburan partikel pada frame waktu ini (default: `true`).
- `emit_count`: Jumlah partikel yang disemburkan (default: `20`).

---

## 4. Modifikasi Properti Partikel & VFX (`set_properties` / `batch_set_properties`)

Gunakan `set_properties` untuk mengubah properti partikel VFX secara granular, termasuk `ColorSequence`, `NumberSequence`, `NumberRange`, dan `Rate`:
```json
{
  "target": "Workspace.FlameBurst.ParticleEmitter",
  "properties": {
    "Rate": 50,
    "Speed": [15, 30],
    "Size": [
      [0, 1.5, 0],
      [1, 0.2, 0]
    ],
    "Color": [
      [0, [1, 0.8, 0.2]],
      [1, [0.8, 0.1, 0]]
    ]
  }
}
```

---

## 5. Pindai Efek Visual Lintas-Proyek (`scan_vfx`)

Gunakan tool `scan_vfx` pada Project A untuk mengekstrak seluruh hierarki partikel, beam, trail, dan light menjadi tabel data murni yang disimpan secara persisten di database MCP.

### Parameter:
- `target`: Path objek di Studio (contoh: `"Workspace.FireSpell"`).
- `name`: Nama efek visual di database (contoh: `"FlameBurst_Ultimate"`).
- `category`: Kategori efek (`"Slash"`, `"Explosion"`, `"Aura"`, `"Projectile"`, `"Magic"`, `"Impact"`, `"Beam"`, atau `"Ambient"`).
- `tags`: Array kata kunci (contoh: `["fire", "orange", "anime"]`).

---

## 6. Terapkan Efek Visual di Proyek Lain (`apply_vfx`)

Buka proyek baru (Project B), lalu panggil `apply_vfx` untuk menginstansiasi efek visual yang tersimpan dengan fidelitas 100%.

### Parameter:
- `vfx_id`: ID efek visual dari database (contoh: `"preset-cyan-slash"`).
- `target`: Path objek tujuan di Studio (contoh: `"Workspace.Boss.RightHand"`).
- `scale`: Skala ukuran efek (contoh: `1.5` untuk memperbesar 50%, `0.8` untuk mengecilkan 20%).
- `enabled`: Boolean opsional untuk menyalakan/mematikan seluruh emitter saat pertama dibuat.

---

## 7. Dekomposisi Partikel Prosedural & Pembedahan Aset Creator Store (Asset Surgery)

DILARANG mengambil free model mentah dari Creator Store untuk efek skill/kemampuan game. Seluruh efek wajib dirakit secara prosedural atau dibedah secara higienis melalui alur berikut:

### A. Blueprint 5-Layer Prosedural Wajib:
1. **Core Anchor**: Objek bola neon (`Ball`, `Neon`, transparansi $0.2-0.4$) atau `Attachment` pusat gravitasi.
2. **Rotational Emitters**: `ParticleEmitter` berkecepatan putar tinggi (`RotSpeed = [400, 700]`) dengan akselerasi inward (menyedot ke pusat).
3. **Ribbons & Blades**: 4 `Beam` atau `ParticleEmitter` silang (*X-Shape*) untuk membentuk bilah energi berputar.
4. **Atmosphere & Shockwave**: `PointLight` dinamis (Range: 12, Brightness: 3, Color Cyan/Orange) + partikel cincin gelombang kejut (*Ring Wave*).
5. **Acoustic SFX**: Objek `Sound` (Charge whine frekuensi tinggi + Burst explosion impact).

### B. Pengambilan Aset Creator Store yang Sah & Higienis:
- **`Images` (Decals/Textures)**: Cari aset visual 2D (seperti *wind swirl*, *energy blade*, *magic ring*, *lightning sprite*). Salin `Texture` ID dan gunakan langsung di properti `Texture` dari `ParticleEmitter` atau `Beam`.
- **`Visual Effects` (Sub-kategori `Particle Effects`)**: Jika mengimpor preset partikel kompleks:
  1. Jalankan `scan_security` untuk memastikan 100% bebas script backdoor dan `require(id)`.
  2. Ekstrak hanya instance visual (`ParticleEmitter`, `Beam`, sequences).
  3. Hapus model pembungkus asli dan seluruh script bawaan.
  4. Rakit ulang ke rig karakter via `batch_create_instances`.
  5. Simpan ke NV-VFX Database via `scan_vfx`.

### C. Contoh Blueprint Perakitan Prosedural (`batch_create_instances`):
```json
{
  "instances": [
    {
      "className": "Attachment",
      "parent": "Workspace.Dummy.RightHand",
      "name": "RasenAnchor",
      "properties": {
        "Position": [0, -1.2, 0]
      },
      "children": [
        {
          "className": "Part",
          "name": "CoreOrb",
          "properties": {
            "Shape": "Ball",
            "Size": [1.2, 1.2, 1.2],
            "Material": "Neon",
            "Color": [0, 0.85, 1],
            "Transparency": 0.25,
            "CanCollide": false,
            "Anchored": false
          }
        },
        {
          "className": "ParticleEmitter",
          "name": "InwardSwirl",
          "properties": {
            "Rate": 60,
            "Lifetime": [0.3, 0.5],
            "Speed": [1, 3],
            "RotSpeed": [400, 800],
            "Acceleration": [0, 0, 0],
            "Color": [
              [0, [0.4, 0.9, 1]],
              [1, [0.9, 1, 1]]
            ],
            "Size": [
              [0, 1.8, 0],
              [1, 0.2, 0]
            ],
            "Transparency": [
              [0, 0.8, 0],
              [0.5, 0.1, 0],
              [1, 1, 0]
            ]
          }
        },
        {
          "className": "PointLight",
          "name": "AmbientGlow",
          "properties": {
            "Color": [0, 0.8, 1],
            "Range": 14,
            "Brightness": 3.5,
            "Shadows": true
          }
        },
        {
          "className": "Sound",
          "name": "ChargeSFX",
          "properties": {
            "Volume": 0.85,
            "Looped": true,
            "PlaybackSpeed": 1.15
          }
        }
      ]
    }
  ]
}
```


