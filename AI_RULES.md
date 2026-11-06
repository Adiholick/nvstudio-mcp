# ROBLOX STUDIO MCP RULES - MUTLAK DAN TIDAK BISA DIGANGGU GUGAT

1. INTERAKSI MCP RESMI:
Anda HANYA DIIZINKAN berinteraksi dengan Roblox menggunakan native MCP tools `nvstudio-mcp` (seperti `execute_luau`, `batch_create_instances`, `batch_set_properties`, `preview_asset`, `scan_security`, `get_roblox_docs`, `get_script_source`, `patch_script_source`, dll.) atau melalui dispatcher `call_mcp_tool`.

2. STRICT BYPASS BAN:
DILARANG KERAS merancang, menulis, atau mengeksekusi script eksternal seperti `fetch_mcp_source.js`, `PowerShell`, atau `Node.js runner` ad-hoc lainnya untuk berinteraksi dengan Roblox. Jalur komunikasi sudah diatur sepenuhnya melalui MCP lokal.

3. MANDATORY HIERARCHY CHECK:
DILARANG memanggil `get_script_source` secara menebak-nebak (buta). Anda WAJIB memanggil `get_children` pada direktori parent terlebih dahulu. Jika Anda mendapat pesan error bahwa "teks kosong", itu karena Anda mencoba membaca Folder, bukan Script. Selalu verifikasi ClassName dari hasil `get_children` sebelum mengekstrak kode.

4. STARTERGUI & NV-SERIES DESIGN TASTE:
Setiap pembuatan atau modifikasi GUI di `StarterGui` WAJIB mematuhi standar NV-Series:
- GUI dibuat sebagai Instance Roblox nyata (gunakan `batch_create_instances` dengan mode `tree`, BUKAN pure script runtime generator).
- ScreenGui selalu memiliki `ResetOnSpawn = false`, `ZIndexBehavior = Sibling`, dan berpusat pada `MainFrame`.
- Setiap Frame WAJIB memiliki `UIListLayout` dan `UIPadding`. Semua child item diatur `LayoutOrder`-nya secara eksplisit.
- Setiap `ScrollingFrame` WAJIB memiliki Frame transparan `Spacer` dengan `LayoutOrder = 99999`.
- Wajib menggunakan Smart Device Detection `GetDeviceType` milik `NVSelfTitle` / `NVDance`.
- Estetika tema gelap: Background `#1C1C1E`, card `#191919`, accent Cyan `#00AAFF`, stroke border `#3F3F3F`, UICorner (`0, 8` - `0, 10`), font GothamBold/Gotham.

5. NV-ANIMATION ENGINE & KINEMATICS (ANTI-HALLUCINATION RULES):
- DILARANG KERAS membuat script loop runtime (`while true do task.wait() ...`) untuk menganimasikan karakter. Animasi WAJIB dibuat sebagai instance resmi `KeyframeSequence` (gunakan semantic tool `animate_character` atau `solve_limb_ik`).
- PERHATIKAN SPASI NAMA MOTOR6D:
  - Karakter R15: Wajib CamelCase tanpa spasi (`LeftShoulder`, `LeftElbow`, `LeftWrist`, `LeftHip`, `LeftKnee`, `LeftAnkle`, `Waist`, `Neck`, `Root`).
  - Karakter R6: Wajib memiliki SPASI (`Left Shoulder`, `Right Shoulder`, `Left Hip`, `Right Hip`, `Neck`, `RootJoint`).
- BATAS SUDUT ANATOMIS:
  - Siku (`LeftElbow`, `RightElbow`) dan Lutut (`LeftKnee`, `RightKnee`) adalah sendi engsel (hinge joint). Dilarang memutar sumbu Roll/Yaw. Sudut tekukan Pitch hanya $0^\circ \dots 145^\circ$ untuk siku dan $0^\circ \dots 135^\circ$ untuk lutut.
  - Siku dan lutut tidak boleh ditekuk ke arah berlawanan (dislokasi).

6. NV-VFX SERIALIZER & CROSS-PROJECT DATABASE PROTOCOLS:
- DILARANG KERAS membuat instance `Beam` atau `Trail` tanpa menghubungkan `Attachment0` dan `Attachment1` ke instance `Attachment` yang valid. Menunjuk ke Part atau Model akan merusak DataModel.
- ATURAN KEYPOINT URUTAN: Setiap `ColorSequence` dan `NumberSequence` WAJIB memiliki keypoint pada $t=0.0$ dan $t=1.0$.
- ALUR KERJA VFX LINTAS-PROYEK:
  - Gunakan `scan_vfx` untuk memindai efek visual pada Project A ke database persisten MCP.
  - Gunakan `apply_vfx` untuk menerapkan efek visual dari database ke Project B dengan parameter `scale` opsional.
  - Dokumentasi referensi lengkap: lihat `docs/NV_ANIMATION_AND_VFX_GUIDE.md`.

7. NV-RIG ENGINE & JOINT KINEMATICS PROTOCOLS:
- PERSAMAAN MUTLAK SAMBUNGAN: Hubungan spasial sendi diatur oleh `Part0.CFrame * C0 = Part1.CFrame * C1`.
- HUKUM NON-DISLOKASI PIVOT: Saat menggeser poros sendi, DILARANG hanya mengubah `C0` sepihak (ini akan mendislokasi part anak). Nilai `C1` WAJIB dikompensasi secara simultan: `diff = C0_old:ToObjectSpace(C0_new); C1_new = C1_old * diff` (gunakan tool `edit_rig_joint`).
- ATURAN UNANCHOR: Seluruh part anak (`Part1`) yang digerakkan oleh `Motor6D` atau `Weld` WAJIB disetel `Anchored = false`. Part yang ter-anchor tidak akan bergerak saat dianimasikan.
- URUTAN RIGGING SEBELUM ANIMASI: Selalu jalankan `inspect_rig` atau `auto_rig` sebelum memanggil `animate_character` pada model yang belum memiliki sendi gerak.
- PANDUAN LENGKAP: lihat `docs/NV_RIG_ENGINE_GUIDE.md`.
