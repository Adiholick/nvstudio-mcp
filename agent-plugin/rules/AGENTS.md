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


