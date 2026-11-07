# API Contract (nvstudio-mcp v2.4.3)

Dokumen ini adalah spesifikasi baku komunikasi antara Local Bridge Server (Node.js) dan Plugin Roblox Studio (Luau).

---

## 1. Arsitektur Jembatan (Bridge Server)
- **Port Baku:** `3055`
- **Dashboard Web:** `http://localhost:3055` (SSE real-time stream status & antrean tugas)
- **Polling Endpoint (GET):** `http://localhost:3055/api/tasks` (Dipanggil plugin Studio tiap tick / sub-detik)
- **Response Endpoint (POST):** `http://localhost:3055/api/response` (Mengirim hasil eksekusi kembali ke Node.js)

### Format Tugas (GET `/api/tasks`):
```json
{
  "id": "UUID-v4-string",
  "command": "nama_perintah",
  "target": "Path.Objek.Roblox (contoh: Workspace.Model.Part)",
  "data": "string (opsional atau stringified JSON)",
  "placeId": 12345678,
  "studioId": "UUID-studio-session"
}
```

### Format Respons (POST `/api/response`):
* **Sukses:**
  ```json
  {
    "id": "UUID-v4-string",
    "status": "success",
    "result": "data (objek JSON, array, string, atau boolean)"
  }
  ```
* **Gagal:**
  ```json
  {
    "id": "UUID-v4-string",
    "status": "error",
    "error": "Pesan error dari Luau runtime"
  }
  ```

---

## 2. Daftar Perintah (Commands) & Spesifikasi Payload

### A. Hirarki & Navigasi Objek
1. **`get_children`**
   - **Target:** Path objek (misal `Workspace.NPCs`).
   - **Data:** Kosong.
   - **Output:** Array objek `[{ name, className, isScript }]`.
2. **`get_full_tree`**
   - **Target:** Path root (misal `StarterGui` atau `ReplicatedStorage`).
   - **Data:** JSON `{ maxDepth?: number }` (default: 3).
   - **Output:** Struktur pohon rekursif instance Roblox.
3. **`search_instance`**
   - **Target:** Direktori pencarian (misal `game` atau `Workspace`).
   - **Data:** String nama instance yang dicari.
   - **Output:** Array path absolut instance yang cocok.

### B. Manipulasi Properti & Pembuatan Objek
4. **`get_properties`**
   - **Target:** Path objek spesifik.
   - **Data:** Kosong atau array nama properti yang diminta.
   - **Output:** Key-value map properti objek.
5. **`set_properties`**
   - **Target:** Path objek target.
   - **Data:** JSON map properti. Mendukung tipe data Roblox otomatis:
     - `UDim2`: `[scaleX, offsetX, scaleY, offsetY]`
     - `UDim`: `[scale, offset]`
     - `Vector3`: `[x, y, z]`
     - `Vector2`: `[x, y]`
     - `Color3`: `[r, g, b]` (0-255)
     - `CFrame`: `[x, y, z, ...]`
     - `NumberRange`: `[min, max]`
     - `Rect`: `[minX, minY, maxX, maxY]`
     - `BrickColor`: String nama warna (misal `"Bright red"`).
6. **`create_instance`**
   - **Target:** Path parent (misal `Workspace` atau `StarterGui.MyScreen`).
   - **Data:** JSON `{ "ClassName": "Part", "Properties": { ... } }`.
7. **`delete_instance`**
   - **Target:** Path objek yang akan dihapus.
   - **Data:** Kosong.

### C. Batch Instance Builder (v2.3+)
8. **`batch_create_instances`**
   - **Target:** Path parent root (misal `StarterGui.NVMenu`).
   - **Data:** JSON dengan dua mode:
     - **Mode Hierarchical Tree (Rekomendasi untuk UI):**
       ```json
       {
         "target": "StarterGui.NVMenu",
         "tree": {
           "className": "Frame",
           "name": "MainFrame",
           "properties": { "Size": [0.5, 0, 0.6, 0], "AnchorPoint": [0.5, 0.5] },
           "children": [
             { "className": "UICorner", "properties": { "CornerRadius": [0, 8] } },
             { "className": "UIListLayout", "properties": { "SortOrder": "LayoutOrder" } }
           ]
         }
       }
       ```
     - **Mode Flat Array:**
       ```json
       {
         "instances": [
           { "className": "Part", "name": "PartA", "parent": "Workspace", "properties": { ... } },
           { "className": "Part", "name": "PartB", "parent": "Workspace.Folder", "properties": { ... } }
         ]
       }
       ```
9. **`batch_set_properties`**
   - **Target:** Kosong.
   - **Data:** JSON array pembaruan massal:
     ```json
     {
       "updates": [
         { "target": "Workspace.PartA", "properties": { "Transparency": 0.5 } },
         { "target": "Workspace.PartB", "properties": { "CanCollide": false } }
       ]
     }
     ```

### D. Manajemen & Sinkronisasi Skrip
10. **`get_script_source`**
    - **Target:** Path script (Script, LocalScript, ModuleScript).
    - **Output:** String teks murni dari kode Luau.
11. **`update_script_source`**
    - **Target:** Path script target.
    - **Data:** Teks kode Luau lengkap. Tervalidasi otomatis oleh Luau AST Validator di Node.js sebelum dikirim ke Studio.
12. **`patch_script_source`**
    - **Target:** Path script target.
    - **Data:** JSON `{ "search": "kode lama", "replacement": "kode baru" }`.
13. **`rollback_script`**
    - **Target:** Path script target.
    - **Data:** Kosong. Mengembalikan kode ke versi backup sebelumnya jika terjadi error halusinasi.
14. **`script_grep`**
    - **Target:** Path root direktori pencarian (misal `game.ServerScriptService`).
    - **Data:** JSON `{ "query": "pola regex/kata kunci" }`.
    - **Output:** Daftar baris kode skrip yang cocok.

### E. Eksekusi Luau & Konsol Studio
15. **`execute_luau`**
    - **Target:** Kosong.
    - **Data:** Kode Luau sembarang yang dieksekusi secara dinamis di Roblox Studio. Mendukung `return` data primitif, table, dan log output.
16. **`get_logs`**
    - **Target:** `"game"`.
    - **Data:** Kosong. Mengambil log riwayat output konsol Roblox Studio.

### F. Keamanan Aset & Creator Store (v2.3+)
17. **`preview_asset`**
    - **Target:** `"game"`.
    - **Data:** JSON `{ "asset_id": 12345678 }`.
    - **Fungsi:** Mengunduh aset ke memori terisolasi sementara, memindai 10 ancaman keamanan (backdoor `require`, obfuscation, loadstring, webhook logger), lalu menghapusnya tanpa memengaruhi tempat kerja.
18. **`insert_asset`**
    - **Target:** Path parent tujuan (default: `game.Workspace`).
    - **Data:** JSON `{ "asset_id": 12345678, "strip_scripts": true, "scan_security": true }`.
    - **Fungsi:** Memasukkan aset secara aman dengan auto-sanitasi skrip aktif secara default.
19. **`scan_security`**
    - **Target:** Path instance/folder yang ingin diaudit (misal `game.Workspace`).
    - **Data:** JSON `{ "clean_threats": false }`.
    - **Fungsi:** Memindai ancaman malware/backdoor pada instance yang sudah ada di dalam game.
20. **`search_asset`**
    - **Target:** `"game"`.
    - **Data:** JSON `{ "keyword": "lampu", "category": "Models" }`.

### G. Terrain Voxel
21. **`generate_terrain`**
    - **Target:** `"Workspace.Terrain"`.
    - **Data:** JSON `{ "Size": [100, 10, 100], "Position": [0, -5, 0], "Material": "Grass" }`.

### H. Dokumentasi Engine & Session (Node.js Level)
22. **`get_roblox_docs`**
    - **Fungsi:** Mengambil dokumentasi resmi Roblox Creator Docs untuk Class, Service, Datatype, Enum, atau Library dengan filter member dan disk cache (~2 ms).
23. **`list_connected_studios`**
    - **Fungsi:** Mengembalikan daftar session ID, Place ID, dan nama tempat Roblox Studio yang sedang aktif terhubung ke jembatan.

### I. NV-VFX Subsystem & Database (v2.4+)
24. **`scan_vfx`**
    - **Target:** Path objek VFX di Studio (misal `Workspace.CyberSlash`).
    - **Data:** JSON `{ name?: string, category?: string, tags?: string[], description?: string }`.
    - **Fungsi:** Mengonversi objek `ParticleEmitter`, `Beam`, `Trail`, `Light`, dan `Attachment` menjadi tabel data murni (JSON-safe) dan menyimpannya secara persisten ke database MCP.
25. **`apply_vfx`**
    - **Target:** Path instance target di Studio (misal `Workspace.Character.RightHand`).
    - **Data:** JSON `{ vfx_id: string, scale?: number, enabled?: boolean }`.
    - **Fungsi:** Merekonstruksi efek visual dari database persisten MCP ke Studio aktif dengan fidelitas 100% dan penskalaan ukuran.
26. **`list_vfx_database`**
    - **Target:** Kosong.
    - **Data:** JSON `{ category?: string, query?: string }`.
    - **Fungsi:** Melihat katalog efek visual yang tersimpan di database persisten MCP dengan filter kategori dan pencarian kata kunci.
27. **`delete_vfx`**
    - **Target:** Kosong.
    - **Data:** JSON `{ id: string }`.
    - **Fungsi:** Menghapus efek visual dari database persisten MCP.

### J. NV-Animation Engine & Kinematika (v2.4+)
28. **`animate_character`**
    - **Target:** Path model karakter rig (R6/R15) di Studio (misal `Workspace.Dummy`).
    - **Data:** JSON `{ action: "walk_cycle" | "melee_slash" | "punch" | "idle_breath" | "custom", parameters?: { duration?: number, intensity?: number, easing?: string, loop?: boolean, vfx_events?: array }, key_poses?: array }`.
    - **Fungsi:** Menghasilkan animasi karakter halus (Disney 12 Principles & Cubic Bezier) dan mengekspornya langsung ke `KeyframeSequence` resmi di `AnimSaves` rig.
29. **`solve_limb_ik`**
    - **Target:** Path model karakter rig (R6/R15).
    - **Data:** JSON `{ limb: "LeftArm" | "RightArm" | "LeftLeg" | "RightLeg", goal: [x, y, z], pole?: [x, y, z], apply_to_rig?: boolean }`.
    - **Fungsi:** Menyelesaikan inverse kinematics analitis (2-link LimbIK O(1)) dengan SoftIK anti-snapping.
30. **`scrub_timeline`**
    - **Target:** Path model karakter atau container VFX.
    - **Data:** JSON `{ time: number, action?: string, emit_vfx?: boolean, emit_count?: number, enabled?: boolean }`.
    - **Fungsi:** Melakukan scrubbing playhead timeline deterministik pada waktu $t$ di Viewport Studio (menerapkan pose SLERP dan memicu burst partikel).

### K. NV-Rig Engine & Joint Kinematics (v2.4+)
31. **`inspect_rig`**
    - **Target:** Path model karakter atau objek di Studio (misal `Workspace.Dummy`).
    - **Data:** Kosong.
    - **Fungsi:** Mendiagnosis topologi rig: pohon sambungan Motor6D & Weld, deteksi cycle/circular dependency, status anchor part, dan posisi poros dunia 3D.
32. **`edit_rig_joint`**
    - **Target:** Path model karakter di Studio.
    - **Data:** JSON `{ action: "create_joint" | "create_weld" | "edit_pivot" | "rotate_pivot" | "reset_pivot" | "align_joint" | "remove_joint", joint_name?: string, part0?: string, part1?: string, delta_world?: [x, y, z], target_world?: [x, y, z], rotate_euler_deg?: [x, y, z], align_to?: "Part0" | "Part1", reanchor?: boolean }`.
    - **Fungsi:** Manipulasi sendi presisi tinggi menggunakan hukum non-dislokasi poros ($C_1 = C_{1\text{old}} \times \text{diff}$).
33. **`auto_rig`**
    - **Target:** Path model di Studio.
    - **Data:** JSON `{ rig_type: "R6" | "R15" | "Weapon", weapon_target?: string, target_limb?: string }`.
    - **Fungsi:** Auto-rigging cerdas 1-klik untuk Avatar R6, Avatar R15, atau Penautan Senjata (Weapon Grip) dengan unanchor otomatis.
34. **`weld_assembly`**
    - **Target:** Path model, armor, aksesori, prop, atau kendaraan.
    - **Data:** JSON `{ primary_part?: string }`.
    - **Fungsi:** Mengelas seluruh komponen BasePart pada sebuah model ke part jangkar utama secara atomik.
35. **`mirror_rig`**
    - **Target:** Path model karakter di Studio.
    - **Data:** JSON `{ source_side: "Left" | "Right" }`.
    - **Fungsi:** Mencerminkan seluruh konfigurasi sendi bilateral sepanjang sumbu simetri $X$ secara matematis.
