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

5. NV-ANIMATION ENGINE & KINEMATICS (HUMAN-LIKE MOTION & ANTI-DISLOCATION RULES):
- DILARANG KERAS membuat script loop runtime (`while true do task.wait() ...`) untuk menganimasikan karakter. Animasi WAJIB dibuat sebagai instance resmi `KeyframeSequence` (gunakan semantic tool `animate_character` atau `solve_limb_ik`).
- PERHATIKAN SPASI NAMA MOTOR6D:
  - Karakter R15: Wajib CamelCase tanpa spasi (`LeftShoulder`, `LeftElbow`, `LeftWrist`, `LeftHip`, `LeftKnee`, `LeftAnkle`, `Waist`, `Neck`, `Root`).
  - Karakter R6: Wajib memiliki SPASI (`Left Shoulder`, `Right Shoulder`, `Left Hip`, `Right Hip`, `Neck`, `RootJoint`).
- BATAS SUDUT ANATOMIS & ANTI-PATAH TULANG (Anti-Dislocation):
  - Siku (`LeftElbow`, `RightElbow`): Sendi engsel (hinge joint 1-DOF). Hanya boleh menekuk pada Pitch ke depan/dalam ($0^\circ \dots 145^\circ$). MUTLAK DILARANG sudut negatif ($< 0^\circ$) yang membuat siku patah ke belakang, dan DILARANG rotasi Roll/Yaw.
  - Lutut (`LeftKnee`, `RightKnee`): Sendi engsel (hinge joint 1-DOF). Hanya boleh menekuk pada Pitch ke belakang ($0^\circ \dots 135^\circ$). MUTLAK DILARANG sudut negatif ($< 0^\circ$) yang membuat lutut patah ke depan, dan DILARANG rotasi Roll/Yaw.
  - Bahu (`Shoulder`) & Paha (`Hip`): Rotasi dalam batas wajar gerak manusia. DILARANG memutar lengan/kaki $> 180^\circ$ mendadak yang memelintir sendi atau menembus torso (*mesh clipping*).
  - Leher (`Neck`): Pitch $-35^\circ \dots 45^\circ$, twist yaw $\le \pm 65^\circ$. DILARANG memutar kepala $> 70^\circ$ yaw (seperti burung hantu/kesurupan).
  - Pinggang (`Waist`): Pitch $-25^\circ \dots 35^\circ$, twist yaw $\pm 35^\circ$, roll $\pm 15^\circ$.
- ISOLASI SENDI & EFISIENSI GERAK (HANYA GERAKKAN SENDI YANG RELEVAN):
  - Prinsip Intentional Movement: HANYA gerakkan sendi-sendi yang relevan secara biomekanik dengan aksi utama. DILARANG menggerakkan atau memutar sendi tubuh tanpa tujuan kinematis (anti-spastic flailing).
  - Contoh Pukulan: Gerakkan lengan pemukul dan sedikit rotasi torso ($10^\circ \dots 15^\circ$) untuk momentum; lengan satunya tetap pada posisi bersiap/guard dan kedua kaki menapak stabil.
  - Foot-Planting & Grounding: Kaki penopang lantai tidak boleh meluncur/sliding, melayang, atau amblas ke tanah. Root bobbing dijaga wajar ($\pm 0.1 \dots 0.2$ stud).
- PRINSIP DISNEY 12 PRINCIPLES: Selalu sertakan fase ancang-ancang (Anticipation), kurva pelambatan (QuadInOut/CubicInOut), dan peredaman (Follow-Through).

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

8. VFX INSTANCE STRUCTURE RULE & PROTOKOL CREATOR STORE HIGIENIS (BUKAN SCRIPT HARDCODED):
- MUTLAK: SEMUA VFX WAJIB BERUPA ROBLOX INSTANCE KONKRET:
  - DILARANG KERAS membuat VFX menggunakan script Luau murni yang memuat puluhan/ratusan baris hardcoded `Instance.new("ParticleEmitter")`, `Instance.new("Attachment")`, atau tabel properti raksasa di dalam script runtime gameplay.
  - Seluruh efek visual (ParticleEmitter, Beam, Trail, Attachment, PointLight, Sound) WAJIB dibangun langsung sebagai Roblox Instance konkret di hierarchy DataModel (`ReplicatedStorage.VFX.<Kategori>.<NamaEfek>`, `Workspace`, atau Attachment rig karakter) menggunakan MCP tools (`batch_create_instances`, `create_instance`, `set_properties`, atau `apply_vfx`).
- PERAN SCRIPT LUAU HANYA SEBAGAI RUNTIME CONTROLLER / TRIGGER:
  - Script Luau (Server/Client) HANYA bertindak sebagai pengendali: meng-clone template dari `ReplicatedStorage.VFX`, menempatkan ke target, memanggil `:Emit(n)` atau mengaktifkan `Enabled = true/false`, dan membersihkan via `Debris:AddItem`.
  - Script DILARANG merakit struktur partikel dari nol atau meng-hardcode ColorSequence/NumberSequence di runtime code.
- HAKEKAT DASAR VFX: Gabungan gambar/decal 2D (RotSpeed), skala (SizeSequence), warna (ColorSequence), emisi (ParticleEmitter/Beam/Trail), pencahayaan (PointLight), dan audio (Sound).
- LARANGAN KERAS FREE MODEL MENTAH: Dilarang menyuntikkan free model Creator Store mentah untuk efek skill game.
- KATEGORI CREATOR STORE RESMI:
  - `Images` (Decals/Textures): Mengambil aset visual 2D murni (wind swirl, energy blade, magic rune, lightning sprite).
  - `Visual Effects` (Sub-kategori `Particle Effects`): Mengambil preset partikel kompleks.
  - `Audio`: Mengambil sound effect resmi (charge whine, blast, boom).
- PROTOKOL PEMBEDAHAN ASET:
  1. Audit keamanan via `scan_security`.
  2. Dekomposisi visual (ekstrak ParticleEmitter, Beam, Attachment, TextureId murni).
  3. Hapus model pembungkus dan script bawaan.
  4. Pasang partikel bersih ke rig via `batch_create_instances`.
  5. Simpan ke NV-VFX Database via `scan_vfx`.
- BLUEPRINT 5-LAYER PROSEDURAL:
  1. Core Anchor (Part Neon transparan / Attachment pusat).
  2. Dynamic Emitters (ParticleEmitter inward swirl berkecepatan tinggi).
  3. Ribbons & Blades (Beam/Trail silang membentuk bilah energi tajam).
  4. Atmosphere & Glow (PointLight dinamis + cincin shockwave tanah).
  5. Acoustic Feedback (Sound charge whine + burst explosion).
