---
name: nvstudio-mcp-guide
description: Panduan umum untuk berinteraksi dengan Roblox Studio menggunakan MCP nvstudio-mcp.
---
# nvstudio-mcp-guide

Gunakan skill ini sebagai referensi umum saat bekerja dengan Roblox Studio via `nvstudio-mcp`.

## Dasar Pemanggilan
1. Jika target path tidak diketahui, gunakan perintah eksplorasi seperti `get_children` atau `search_instance` (khusus pencarian berdasarkan nama) terlebih dahulu.
2. Tentukan target path string yang valid (misalnya `game.Workspace.Model.Part`). LLM/Agent tidak bisa berinteraksi menggunakan reference Luau langsung.
3. Gunakan native semantic tools yang tersedia (`execute_luau`, `batch_create_instances`, `get_roblox_docs`, dll.) atau gunakan legacy dispatcher `call_mcp_tool` untuk kompatibilitas.

## Batch Instance Builder (`batch_create_instances` & `batch_set_properties`)
Saat membuat banyak instance (terutama struktur GUI seperti `MainFrame`, `UICorner`, `UIStroke`, `UIListLayout`, `UIPadding`, `ScrollingFrame`, `Spacer`), **JANGAN** membuat instance satu per satu dengan `create_instance`. Gunakan `batch_create_instances`:
- **Mode `tree` (Rekomendasi Utama UI):**
  Membangun seluruh hierarki bersarang dalam 1 roundtrip:
  ```json
  {
    "target": "StarterGui.NVMenu",
    "tree": {
      "className": "Frame",
      "name": "MainFrame",
      "properties": {
        "Size": [0.5, 0, 0.6, 0],
        "Position": [0.5, 0, 0.5, 0],
        "AnchorPoint": [0.5, 0.5],
        "BackgroundColor3": [28, 28, 30]
      },
      "children": [
        { "className": "UICorner", "name": "UICorner", "properties": { "CornerRadius": [0, 10] } },
        { "className": "UIStroke", "name": "UIStroke", "properties": { "Color": [63, 63, 63], "Thickness": 1 } },
        { "className": "UIListLayout", "name": "UIListLayout", "properties": { "SortOrder": "LayoutOrder" } },
        { "className": "UIPadding", "name": "UIPadding", "properties": { "PaddingTop": [0, 10] } }
      ]
    }
  }
  ```
- **Mode `instances` (Flat Array):**
  Membuat banyak objek di berbagai parent berbeda sekaligus:
  ```json
  {
    "instances": [
      { "className": "Part", "name": "LightA", "parent": "Workspace.Lights", "properties": { "Anchored": true } },
      { "className": "Part", "name": "LightB", "parent": "Workspace.Lights", "properties": { "Anchored": true } }
    ]
  }
  ```
- **Pembaruan Massal (`batch_set_properties`):**
  Untuk mengubah properti banyak instance secara atomik dalam 1 pemanggilan:
  ```json
  {
    "updates": [
      { "target": "Workspace.PartA", "properties": { "Transparency": 0.5, "CanCollide": false } },
      { "target": "Workspace.PartB", "properties": { "Color": [255, 0, 0] } }
    ]
  }
  ```

## Verifikasi Dokumentasi Engine Resmi (`get_roblox_docs`)
Sebelum menulis skrip Luau atau menggunakan API/Service yang belum pasti nama properti atau method-nya, **selalu panggil `get_roblox_docs`**:
- **Format Panggilan:**
  - `query`: Nama class, service, datatype, enum, atau library (contoh: `"TweenService"`, `"CanvasGroup"`, `"UDim2"`, `"EasingStyle"`, `"task"`).
  - `member` *(opsional)*: Untuk menghemat token, tentukan nama method atau properti spesifik (contoh: `query: "CanvasGroup", member: "GroupTransparency"`).
- **Keunggulan:** Tool ini membaca data resmi terverifikasi dari Creator Docs dengan caching lokal berkecepatan tinggi (~2 ms) untuk mencegah halusinasi kode Luau.

## Modifikasi Skrip Cerdas (`patch_script_source`)
- Jika hanya ingin mengubah sebagian baris kode tanpa menimpa seluruh file skrip, gunakan `patch_script_source` dengan parameter `search` dan `replacement`.
- Untuk penggantian skrip utuh, gunakan `update_script_source` (otomatis dicek oleh AST Validator di Node.js untuk mencegah syntax error fatal).

## Rigging, Animasi Karakter & Efek Visual (v2.4+)
nvstudio-mcp dilengkapi dengan rangkaian modular tripartit:
1. **NV-Rig Engine** (lihat skill `nvstudio-rig-engine`):
   - Gunakan `inspect_rig` untuk diagnosa kesehatan sendi & anchor status.
   - Gunakan `auto_rig` untuk membuat rig R6, R15, atau menautkan senjata (`Weapon`).
   - Gunakan `edit_rig_joint` untuk memindahkan pivot tanpa dislokasi part anak.
   - Gunakan `weld_assembly` untuk menyatukan armor/prop/kendaraan.
2. **NV-Animation Engine** (lihat skill `nvstudio-animation-vfx`):
   - Gunakan `animate_character` untuk membuat animasi resmi `KeyframeSequence` di `AnimSaves` (Walk, Slash, Punch, Idle).
   - Gunakan `solve_limb_ik` untuk analytical 2-link LimbIK ke koordinat 3D.
   - Gunakan `scrub_timeline` untuk scrubbing playhead waktu deterministik.
3. **NV-VFX Subsystem** (lihat skill `nvstudio-animation-vfx`):
   - Gunakan `scan_vfx` untuk memindai efek visual dan `apply_vfx` untuk merekonstruksinya dari database persisten.
