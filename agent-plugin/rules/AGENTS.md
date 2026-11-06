# NVStudio GUI Design Rules & Aesthetic Taste

Saat diminta membuat, memperbarui, atau merancang GUI di Roblox Studio (`StarterGui`), Anda WAJIB mematuhi aturan standar NV-Series (`NVMembership`, `NVMusic`, `NVSelfTitle`, `NVServer`, `NVDance`) di bawah ini:

## 1. Instance Structure Rule (Bukan Script Murni)
- **MUTLAK:** Semua GUI dibuat dalam bentuk **Roblox Instance konkret di dalam `StarterGui`**, BUKAN script Luau murni yang membangun ratusan baris `Instance.new` saat runtime.
- Bangun hierarki instance menggunakan tool MCP (`create_instance`, `set_properties`, atau generator Luau studio).
- Script Luau (`LocalScript`) HANYA bertindak sebagai Controller / Listener event, animasi `TweenService`, state, dan komunikasi jaringan.

## 2. Root & MainFrame Standard
- **ScreenGui Root:**
  - Wajib menyetel `ResetOnSpawn = false`.
  - Wajib menyetel `ZIndexBehavior = Enum.ZIndexBehavior.Sibling`.
- **MainFrame:**
  - Setiap `ScreenGui` WAJIB memiliki child utama bertipe `Frame` bernama **`MainFrame`** (atau `ContainerFrame` pembungkus `MainFrame`).
  - AnchorPoint standar: `Vector2.new(0.5, 0.5)` dengan Position di tengah layar `UDim2.new(0.5, 0, 0.5, 0)`.

## 3. Frame Layout & Deterministic Order Rules
- **Wajib UIListLayout & UIPadding:**
  - **Setiap `Frame`** (termasuk `MainFrame`, container, header, sub-frame, list container) WAJIB memiliki `UIListLayout` (dengan `SortOrder = Enum.SortOrder.LayoutOrder`) dan `UIPadding`.
- **Wajib LayoutOrder pada Setiap Item:**
  - Semua child `GuiObject` di dalam Frame yang menggunakan layout WAJIB disetel properti `LayoutOrder`-nya secara eksplisit (0, 1, 2, 3...) agar tidak ada tumpang tindih acak.

## 4. ScrollingFrame Spacer Rule
- **Wajib Frame Spacer:**
  - Setiap `ScrollingFrame` WAJIB memiliki child Frame pembatas transparan bernama **`Spacer`** atau **`SPACER`**.
  - Properti Spacer: `BackgroundTransparency = 1`, `BorderSizePixel = 0`, dan `LayoutOrder = 99999` (atau `999999999`).
  - Spacer berfungsi sebagai margin penutup agar elemen list paling bawah tidak terpotong tepi scrolling frame.

## 5. Smart Device Detection & Responsive Scaling
Setiap Controller GUI wajib menyertakan fungsi cerdas pendeteksi perangkat yang diadopsi dari `NVSelfTitle` dan `NVDance`:
```lua
local function GetDeviceType(vw: number, vh: number, mainFrame: GuiObject): string
    local forceDevice = mainFrame:GetAttribute("ForceDevice")
    if forceDevice and (forceDevice == "Phone" or forceDevice == "Tablet" or forceDevice == "PC" or forceDevice == "Console") then
        return forceDevice :: string
    end

    if game:GetService("GuiService"):IsTenFootInterface() then
        return "Console"
    end

    local uis = game:GetService("UserInputService")
    if uis.TouchEnabled and not uis.KeyboardEnabled then
        local smaller = math.min(vw, vh)
        if smaller > 0 and smaller < 550 then
            return "Phone"
        else
            return "Tablet"
        end
    end

    return "PC"
end
```
- Skala responsif PC, Mobile (Phone), Tablet, dan Console dihitung secara terpisah agar perubahan skala HP tidak merusak tampilan PC.
- Berikan listener pada `Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")`.

## 6. NV Dark Modern Taste & Design Tokens
- **Background Utama (MainFrame):** `Color3.fromRGB(28, 28, 30)` (`#1C1C1E`).
- **Background Card / Item / Container:** `Color3.fromRGB(25, 25, 25)` (`#191919`).
- **Background Sub-box / Search / Input:** `Color3.fromRGB(13, 13, 13)` (`#0D0D0D`).
- **Border / Outline:** Gunakan `UIStroke` dengan `Color = Color3.fromRGB(63, 63, 63)` (`#3F3F3F`), `Thickness = 1`, `ApplyStrokeMode = Enum.ApplyStrokeMode.Border`.
- **Aksen Aktif & Seleksi:** Cyan `Color3.fromRGB(0, 170, 255)` atau `Color3.fromRGB(0, 255, 255)`.
- **Corner Radius:** Selalu gunakan `UICorner` (`UDim.new(0, 8)` s/d `UDim.new(0, 10)` untuk Frame/Card, dan `UDim.new(0.2, 0)` atau `UDim.new(0.5, 0)` untuk tombol/chip).
- **Tipografi:** Wajib menggunakan `Enum.Font.GothamBold` untuk judul/header, `Enum.Font.Gotham` / `GothamMedium` untuk teks isi.

## 7. Interactive Component Rules (Slider, Switch, Segment & Buttons)
Saat merancang komponen interaktif khusus, patuhi pola NV-Series:
- **Vertical Slider:**
  - Bangun `SliderFrame` (track vertikal), `Button` (knob draggable), dan `ValueTextTarget`.
  - Hitung ratio dari bawah ke atas: `ratio = 1 - (relativeY / frameH)`.
- **Horizontal Slider:**
  - Bangun `SliderFrame` (track horizontal), `Fill` (bar progress), `Knob`/`Button`, dan `Trigger` (TextButton transparan full-size).
  - Hitung ratio dari kiri ke kanan: `ratio = relativeX / frameW`.
- **Switch Button (Toggle):**
  - Gunakan `SwitchContainer` (pill frame capsule), `SwitchFrame` (knob bulat), dan `SwitchButton` transparan overlay.
  - State ON: Container warna Cyan `Color3.fromRGB(0, 170, 255)`, indikator bergeser ke kanan dengan warna putih.
  - State OFF: Container warna gelap `Color3.fromRGB(20, 20, 20)`, indikator bergeser ke kiri dengan warna abu-abu.
- **Segment Frame (Tab Bar):**
  - Bungkus tab di dalam `SegmentFrame` (background `Color3.fromRGB(25, 25, 25)`, `UICorner` kapsul, `UIListLayout` horizontal).
- **Active & Inactive Button Styling:**
  - **Tab Segment:** Active = `Color3.fromRGB(55, 55, 60)`, Inactive = `Color3.fromRGB(25, 25, 25)`.
  - **Item Seleksi:** Gunakan `UIStroke` bernama `SelectStroke`: Active = `Color3.fromRGB(0, 255, 255)` (Cyan), Inactive = `Color3.fromRGB(60, 60, 65)`.
  - **Tombol Non-Aktif / Limit:** Set `AutoButtonColor = false` dan teks status (contoh: `"WAIT (Xs)"`, `"OUT OF QUOTA"`).

## 8. NV-Animation Engine & Kinematics (Anti-Hallucination Ground Truth)
Saat diminta menganimasikan karakter di Roblox Studio, Anda WAJIB mematuhi ground truth berikut:
- **DILARANG MENGGUNAKAN LOOP RUNTIME**: Animasi karakter tidak boleh dibuat menggunakan script loop `while true do task.wait() ...`. Animasi wajib dibuat sebagai instance resmi `KeyframeSequence` di dalam `AnimSaves` rig (gunakan tool semantic `animate_character` atau `solve_limb_ik`).
- **SENSITIVITAS SPASI NAMA MOTOR6D**:
  - Karakter R15: Menggunakan CamelCase TANPA SPASI (`LeftShoulder`, `LeftElbow`, `LeftWrist`, `LeftHip`, `LeftKnee`, `LeftAnkle`, `Waist`, `Neck`, `Root`).
  - Karakter R6: WAJIB MENGGUNAKAN SPASI (`Left Shoulder`, `Right Shoulder`, `Left Hip`, `Right Hip`, `Neck`, `RootJoint`).
- **BATAS SUDUT ANATOMIS AMAN**:
  - Siku (`LeftElbow`, `RightElbow`) dan Lutut (`LeftKnee`, `RightKnee`) adalah sendi engsel (hinge joint). Dilarang memutar sumbu Roll/Yaw. Sudut tekukan Pitch hanya $0^\circ \dots 145^\circ$ untuk siku dan $0^\circ \dots 135^\circ$ untuk lutut. Dilarang menekuk siku atau lutut ke arah berlawanan (dislokasi).
  - Torso/Waist pitch dibatasi $-25^\circ \dots 35^\circ$, twist yaw $\pm 45^\circ$.
- **PRINSIP GERAKAN HALUS (Disney 12 Principles)**:
  - Setiap gerakan wajib memiliki fase ancang-ancang (*Anticipation*), interpolasi pelambatan (*QuadInOut* atau *CubicInOut*), dan peredaman akhir (*Follow-Through*).

## 9. NV-VFX Serializer & Cross-Project Database Protocols
Saat memindai, merekonstruksi, atau menerapkan efek visual antar-proyek:
- **ATTACHMENT HARUS VALID**: Properti `Attachment0` dan `Attachment1` pada `Beam` atau `Trail` HANYA BOLEH menunjuk ke instance bertipe `Attachment`. Dilarang keras menunjuk ke Part atau Model.
- **ATURAN URUTAN KEYPOINT**: Setiap `ColorSequence` dan `NumberSequence` WAJIB memiliki keypoint awal pada $t = 0.0$ dan keypoint akhir pada $t = 1.0$.
- **ALUR KERJA LINTAS-PROYEK**:
  - Gunakan tool `scan_vfx` pada Project A untuk mengonversi partikel, beam, trail, dan light menjadi tabel data murni yang disimpan secara persisten di database MCP.
  - Gunakan tool `apply_vfx` pada Project B untuk menginstansiasi efek dari database ke target objek dengan parameter `scale` opsional.
  - Dokumentasi referensi lengkap: lihat `docs/NV_ANIMATION_AND_VFX_GUIDE.md`.

## 10. NV-Rig Engine & Joint Kinematics Protocols (Anti-Hallucination Ground Truth)
Saat memeriksa, membuat, atau memodifikasi sendi karakter (`Motor6D` / `Weld`):
- **PERSAMAAN KESEIMBANGAN SAMBUNGAN**: Hubungan spasial sendi diatur oleh `Part0.CFrame * C0 = Part1.CFrame * C1`.
- **HUKUM NON-DISLOKASI PIVOT**: Saat menggeser atau memutar poros sendi, DILARANG hanya mengubah `C0` sepihak karena akan mendislokasi posisi fisik `Part1`. Nilai `C1` WAJIB dikompensasi secara simultan: `diff = C0_old:ToObjectSpace(C0_new); C1_new = C1_old * diff` (gunakan tool `edit_rig_joint`).
- **ATURAN WAJIB UNANCHOR**: Seluruh part anak (`Part1`) yang dihubungkan dengan `Motor6D` atau `Weld` WAJIB disetel `Anchored = false`. Part yang berstatus anchored tidak akan dapat bergerak dalam simulasi fisika atau animasi.
- **URUTAN KERJA RIGGING SEBELUM ANIMASI**: Dilarang memanggil `animate_character` pada model yang belum memiliki hierarki sendi valid. Selalu jalankan `inspect_rig` untuk diagnosa atau `auto_rig` untuk membuat kerangka standar.
- **PENGELASAN ASSEMBLY SENJATA/PROP**: Gunakan `weld_assembly` untuk menyatukan seluruh komponen prop/senjata secara kaku ke part pegangan sebelum ditautkan ke karakter.
- **DOKUMENTASI REFERENSI LENGKAP**: lihat `docs/NV_RIG_ENGINE_GUIDE.md`.

## 11. Standar Dekomposisi VFX Prosedural & Protokol Creator Store Higienis (Anti-Shortcut Ground Truth)
Saat diminta merancang efek visual, sihir, aura, proyektil, atau skill anime/game (seperti Rasengan, Fireball, Katana Slash, Aura Super, dll):
- **HAKEKAT DASAR VFX**: Sejatinya sebuah efek visual di Roblox adalah gabungan dari gambar/decal/tekstur 2D yang diputar (`RotSpeed`), diskalakan (`SizeSequence`), diinterpolasi warnanya (`ColorSequence`), dipancarkan via `ParticleEmitter` / `Beam` / `Trail`, diperkaya pencahayaan dinamis (`PointLight`), dan disinkronkan dengan efek suara (`Sound`).
- **LARANGAN KERAS PENGGUNAAN MENTAH (ANTI-RAW MODEL SHORTCUT)**:
  - Dilarang keras mengandalkan free model Creator Store yang disuntikkan secara mentah ke karakter atau workspace dengan script bawaannya yang rentan backdoor, malware, laggy loop, dan ukuran tidak proporsional.
- **KATEGORI CREATOR STORE RESMI YANG DIIZINKAN**:
  - `Images` (Decals/Textures): Mengambil aset visual 2D murni (misal: *wind swirl*, *energy blade*, *magic ring*, *lightning sprite*, *flipbook sheet*) tanpa risiko kode eksekusi.
  - `Visual Effects` (Sub-kategori `Particle Effects`): Mengambil preset partikel kompleks.
  - `Audio`: Mengambil efek suara resmi (*charge whine*, *whoosh*, *blast*, *boom*).
- **PROTOKOL PEMBEDAHAN ASET (ASSET SURGERY PROTOCOL)**:
  Jika mengimpor aset dari kategori `Visual Effects` atau Model:
  1. **Audit Keamanan Mutlak**: Wajib panggil `scan_security` untuk memusnahkan seluruh script, backdoor, dan `require(id)`.
  2. **Dekomposisi Visual**: Ekstrak HANYA objek visual murni (`ParticleEmitter`, `Beam`, `Attachment`, `TextureId`, sequences).
  3. **Pemusnahan Container**: Hapus model pembungkus asli beserta script-scriptnya.
  4. **Rekonstruksi Higienis**: Pasang partikel bersih ke anchor/rig karakter menggunakan `batch_create_instances` / `set_properties`.
  5. **Simpan ke Database**: Simpan konfigurasi ke NV-VFX Database via `scan_vfx` agar menjadi aset mandiri portabel proyek.
- **BLUEPRINT 5-LAYER PROSEDURAL WAJIB**:
  Setiap efek skill berkekuatan tinggi wajib dibangun dengan dekomposisi 5 layer:
  1. *Core Anchor*: Part/Mesh Ball Neon transparan + Attachment pusat rotasi.
  2. *Dynamic Emitters*: `ParticleEmitter` akselerasi inward (hisapan angin/energi) dengan `RotSpeed` tinggi.
  3. *Ribbons & Blades*: `Beam` atau `Trail` silang (*X-Shape*) membentuk bilah tajam memotong.
  4. *Atmosphere & Glow*: `PointLight` dinamis (pantulan ke tubuh karakter) + cincin shockwave tanah.
  5. *Acoustic Feedback*: Objek `Sound` (Charge high-pitch whine + Burst impact).




