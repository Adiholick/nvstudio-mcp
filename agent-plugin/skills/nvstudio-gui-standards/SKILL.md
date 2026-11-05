---
name: nvstudio-gui-standards
description: Panduan standar arsitektur dan taste desain StarterGui Roblox (Struktur Instance, Smart Device Detection NVSelfTitle/NVDance, Layout Hierarchy, dan NV Dark Modern Aesthetics).
---

# NVStudio Roblox GUI Design Standards & Taste Guide

Gunakan skill ini sebagai acuan mutlak setiap kali membuat atau memodifikasi GUI di Roblox Studio (`StarterGui`). Semua GUI dirancang mengikuti filosofi arsitektur **NV-Series** (`NVMembership`, `NVMusic`, `NVSelfTitle`, `NVServer`, `NVDance`).

---

## 1. Aturan Fundamental Arsitektur GUI

1. **Roblox Instance Penuh (Bukan Pure Script):**
   - GUI dibuat sebagai hierarki **Instance nyata di Roblox Studio** (menggunakan MCP `create_instance` / `set_properties` atau builder helper Luau).
   - DILARANG membuat GUI murni on-the-fly dari script kosong dengan ratusan baris `Instance.new`.
   - Script Luau (`LocalScript` / `ModuleScript`) hanya bertindak sebagai **UI Controller** yang mengontrol state, event click/input, tweening, dan integrasi server.

2. **Hierarki ScreenGui & MainFrame:**
   - Setiap GUI berada di bawah `ScreenGui` dengan properti:
     - `ResetOnSpawn = false`
     - `ZIndexBehavior = Enum.ZIndexBehavior.Sibling`
     - `IgnoreGuiInset = false`
   - Child utama dari `ScreenGui` WAJIB berupa Frame bernama **`MainFrame`** (atau `ContainerFrame` yang membungkus `MainFrame`).
   - `MainFrame.AnchorPoint` default: `Vector2.new(0.5, 0.5)` dengan posisi tengah `UDim2.new(0.5, 0, 0.5, 0)`.

3. **Aturan Wajib Layout Frame:**
   - **Setiap Frame** WAJIB memiliki:
     - `UIListLayout` (atau `UIGridLayout` jika grid konten) dengan `SortOrder = Enum.SortOrder.LayoutOrder`.
     - `UIPadding` (memberikan padding konsisten agar elemen tidak menempel ke tepi).
   - **Setiap Item di dalam Frame** WAJIB memiliki properti `LayoutOrder` eksplisit (0, 1, 2, 3...) agar susunan elemen teratur secara deterministik.

4. **Aturan Wajib ScrollingFrame:**
   - Setiap `ScrollingFrame` WAJIB memiliki Frame transparan pembatas bernama **`Spacer`** atau **`SPACER`**:
     - `Name = "Spacer"`
     - `BackgroundTransparency = 1`
     - `BorderSizePixel = 0`
     - `LayoutOrder = 99999` (atau `999999999`)
     - Size: `UDim2.new(1, 0, 0.15, 0)` atau `UDim2.new(0, 0, 0, 20)` (menyesuaikan orientasi scroll vertical/horizontal).
   - Ini memastikan elemen paling bawah/ujung tidak terpotong saat pemain melakukan scroll.

5. **Pembangun Deklaratif Cepat (`batch_create_instances`):**
   - Sangat disarankan membangun seluruh pohon GUI menggunakan tool `batch_create_instances` dengan mode `tree` bersarang.
   - Contoh payload tree:
     ```json
     {
       "target": "StarterGui.MyScreen",
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
           { "className": "UICorner", "properties": { "CornerRadius": [0, 10] } },
           { "className": "UIStroke", "properties": { "Color": [63, 63, 63], "Thickness": 1 } },
           { "className": "UIListLayout", "properties": { "SortOrder": "LayoutOrder" } },
           { "className": "UIPadding", "properties": { "PaddingTop": [0, 10], "PaddingBottom": [0, 10] } }
         ]
       }
     }
     ```

---

## 2. Smart Device Detection & Responsive Scaling System

Diadopsi langsung dari **`NVSelfTitle`** dan **`NVDance`**. Sistem ini membedakan ukuran perangkat secara akurat dan memisahkan skala PC, Mobile, Tablet, dan Console secara independen.

### Modul Logika Deteksi Perangkat:
```lua
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- [KONFIGURASI SKALA INDEPENDEN PER PERANGKAT]
local PC_Scale               = 1.0   -- Skala normal PC / Laptop
local PC_Portrait_Scale      = 1.2   -- Jendela PC orientasi portrait
local Mobile_Landscape_Scale = 1.45  -- Smartphone landscape
local Mobile_Portrait_Scale  = 1.7   -- Smartphone portrait
local Tablet_Landscape_Scale = 1.25  -- Tablet / iPad landscape
local Tablet_Portrait_Scale  = 1.45  -- Tablet / iPad portrait
local Console_Scale          = 1.15  -- PlayStation / Xbox / TV
local GlobalScaleMultiplier  = 1.0

-- Fungsi Cerdas Deteksi Perangkat (NVSelfTitle / NVDance Standard)
local function GetDeviceType(vw: number, vh: number, mainFrame: GuiObject): string
    -- 1. Opsi override untuk testing di Studio lewat Attribute "ForceDevice" pada MainFrame:
    local forceDevice = mainFrame:GetAttribute("ForceDevice")
    if forceDevice and (forceDevice == "Phone" or forceDevice == "Tablet" or forceDevice == "PC" or forceDevice == "Console") then
        return forceDevice :: string
    end

    -- 2. Console (PlayStation / Xbox / Smart TV)
    if GuiService:IsTenFootInterface() then
        return "Console"
    end

    -- 3. Touch Device (Smartphone vs Tablet)
    -- Touchscreen aktif dan keyboard fisik tidak aktif
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        local smallerDimension = math.min(vw, vh)
        -- Dimensi logika layar smartphone di Roblox umumnya < 550 pixel, Tablet >= 550 pixel
        if smallerDimension > 0 and smallerDimension < 550 then
            return "Phone"
        else
            return "Tablet"
        end
    end

    -- 4. Default: Desktop / PC / Laptop
    return "PC"
end
```

### Handler Update Skala & Event Listener:
```lua
local function UpdateMainFrameScale(mainFrame: Frame, defaultSize: UDim2, isOpen: boolean)
    local camera = Workspace.CurrentCamera
    if not camera then return end

    local vw, vh = camera.ViewportSize.X, camera.ViewportSize.Y
    local isPortrait = vh > vw
    local deviceType = GetDeviceType(vw, vh, mainFrame)

    local baseScale = 1.0
    if deviceType == "Phone" then
        baseScale = isPortrait and Mobile_Portrait_Scale or Mobile_Landscape_Scale
    elseif deviceType == "Tablet" then
        baseScale = isPortrait and Tablet_Portrait_Scale or Tablet_Landscape_Scale
    elseif deviceType == "Console" then
        baseScale = Console_Scale
    else
        baseScale = isPortrait and PC_Portrait_Scale or PC_Scale
    end

    local totalScale = GlobalScaleMultiplier * baseScale

    mainFrame.Size = UDim2.new(
        defaultSize.X.Scale * totalScale,
        defaultSize.X.Offset * totalScale,
        defaultSize.Y.Scale * totalScale,
        defaultSize.Y.Offset * totalScale
    )

    if isOpen then
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
end
```

### Studio Attributes Testing Support:
Pasang Attribute pada `MainFrame`:
- `ForceDevice` (`String`: `"Phone"`, `"Tablet"`, `"PC"`, `"Console"`)
- `PCScale` (`Number`)
- `MobileScale` (`Number`)

---

## 3. NV Dark Modern Taste & Design Tokens

Semua GUI NV-Series menggunakan tema gelap elegan (*business-grade dark mode*) dengan kontras tinggi dan sentuhan rounded halus.

| Komponen | Token Warna / Properti | Nilai RGB / Hex | Kegunaan |
| :--- | :--- | :--- | :--- |
| **MainFrame Background** | `BackgroundColor3` | `Color3.fromRGB(28, 28, 30)` (`#1C1C1E`) | Latar belakang frame utama jendela |
| **Card / Item Background** | `BackgroundColor3` | `Color3.fromRGB(25, 25, 25)` (`#191919`) | Latar belakang list item, segment container |
| **Sub-Frame / Input** | `BackgroundColor3` | `Color3.fromRGB(13, 13, 13)` (`#0D0D0D`) | Textbox search, area preview, inner box |
| **Border / UIStroke** | `Color`, `Thickness = 1` | `Color3.fromRGB(63, 63, 63)` (`#3F3F3F`) | Garis tepi halus (`ApplyStrokeMode.Border`) |
| **Active Accent (Cyan)** | `Color3` | `Color3.fromRGB(0, 170, 255)` / `fromRGB(0, 255, 255)` | Tab aktif, border seleksi (`SelectStroke`) |
| **Text Primary** | `TextColor3` | `Color3.fromRGB(255, 255, 255)` (`#FFFFFF`) | Judul, label penting, nama item |
| **Text Secondary** | `TextColor3` | `Color3.fromRGB(163, 162, 165)` (`#A3A2A5`) | Deskripsi, subtitle, teks tidak aktif |

### Corner Radius (`UICorner`):
- `MainFrame`: `UDim.new(0, 10)` atau `UDim.new(0.03, 0)`
- `Card / Container Frame`: `UDim.new(0, 8)` atau `UDim.new(0, 10)`
- `Buttons / Pills / Tags`: `UDim.new(0.2, 0)` atau `UDim.new(0.5, 0)`

### Tipografi (`Font`):
- **Judul & Header:** `Enum.Font.GothamBold`
- **Teks Tubuh & List:** `Enum.Font.Gotham` atau `Enum.Font.GothamMedium`
- **Aksen / Badge:** `Enum.Font.FredokaOne` atau `Enum.Font.SourceSansBold`

---

## 4. UI Controller Script Template (LocalScript)

Setiap ScreenGui memiliki Controller (`LocalScript`) dengan struktur standar berikut:

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Maid = require(Modules:WaitForChild("Maid"))
local Icon = require(ReplicatedStorage:WaitForChild("Icon")) -- TopbarPlus

local GUI = script.Parent
local MainFrame = GUI:WaitForChild("MainFrame") :: Frame
local ScrollingFrame = MainFrame:FindFirstChildWhichIsA("ScrollingFrame", true)

local Controller = {
    _maid = Maid.new(),
    IsOpen = false,
    DefaultSize = MainFrame.Size,
}

-- [1] ANIMASI TOGGLE WINDOW (Pop-In & Slide)
function Controller:Toggle(state: boolean)
    self.IsOpen = state
    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local targetPos = state and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0.5, 0, -0.6, 0)

    if state then
        MainFrame.Visible = true
        UpdateMainFrameScale(MainFrame, self.DefaultSize, true)
    end

    local tween = TweenService:Create(MainFrame, tweenInfo, { Position = targetPos })
    tween:Play()

    if not state then
        tween.Completed:Connect(function()
            if not self.IsOpen then
                MainFrame.Visible = false
            end
        end)
    end
end

-- [2] SELEKSI TOMBOL INTERAKTIF (Pola SelectStroke)
function Controller:HighlightButton(parentContainer: Instance, activeBtn: Instance?)
    for _, child in ipairs(parentContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            local stroke = child:FindFirstChild("SelectStroke") :: UIStroke?
            if not stroke then
                stroke = Instance.new("UIStroke")
                stroke.Name = "SelectStroke"
                stroke.Thickness = 1
                stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                stroke.Parent = child
            end
            if child == activeBtn then
                stroke.Color = Color3.fromRGB(0, 255, 255)
            else
                stroke.Color = Color3.fromRGB(60, 60, 65)
            end
        end
    end
end

-- [3] SETUP TOPBARPLUS ICON
local topbarIcon = Icon.new()
topbarIcon:setLabel(GUI.Name)
topbarIcon.toggled:Connect(function(isSelected: boolean)
    Controller:Toggle(isSelected)
end)

-- [4] HOOK CAMERA & ATTRIBUTES
local function hookCamera()
    local cam = Workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            UpdateMainFrameScale(MainFrame, Controller.DefaultSize, Controller.IsOpen)
        end)
        UpdateMainFrameScale(MainFrame, Controller.DefaultSize, Controller.IsOpen)
    end
end
hookCamera()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
```

---

## 5. Komponen Interaktif Standar NV-Series

### A. Vertical Slider (`VerticalSlider`)
Diadopsi dari `NVMusic` (Volume Fader Master, Deck A/B Volume, Speed Control):
- **Struktur Instance:**
  - `SliderFrame` (Frame Track Vertikal: Width `0.12` - `0.2`, Height `0.85`, background `#101010`, `UICorner`, `UIStroke`, `UIPadding`).
  - `Button` (Draggable Knob: AnchorPoint `0.5, 0.5`, `UICorner`).
  - `ValueTextTarget` (TextLabel indikator nilai).
- **Logika Luau:**
  ```lua
  local function ProcessVerticalInput(inputY, sliderFrame, minVal, maxVal, step)
      local frameY = sliderFrame.AbsolutePosition.Y
      local frameH = sliderFrame.AbsoluteSize.Y
      if frameH <= 0 then return minVal end

      local relativeY = math.clamp(inputY - frameY, 0, frameH)
      local ratio = 1 - (relativeY / frameH) -- Dari bawah ke atas
      local rawVal = minVal + ratio * (maxVal - minVal)
      local steps = math.floor(rawVal / step + 0.5)
      return math.clamp(steps * step, minVal, maxVal), ratio
  end

  local function UpdateVerticalVisual(button, ratio, textLabel, val)
      button.Position = UDim2.new(
          button.Position.X.Scale,
          button.Position.X.Offset,
          (1 - ratio),
          -button.Size.Y.Offset / 2
      )
      if textLabel then
          textLabel.Text = tostring(math.floor(val * 100) / 100)
      end
  end
  ```

---

### B. Horizontal Slider (`HorizontalSlider`)
Diadopsi dari `NVMusic` (Volume Horizontal, Master Crossfade) dan `NVDance` (Emote Speed Slider):
- **Struktur Instance:**
  - `SliderFrame` (Track Horizontal: Height `0.2` - `0.25`, Width `1.0`, background `#101010`, `UICorner`, `UIStroke`).
  - `Fill` (Frame Bar kemajuan aksen Cyan/Putih, Size `UDim2.new(ratio, 0, 1, 0)`).
  - `Button` / `Knob` (Frame/Button bulat, Position `UDim2.new(ratio, 0, 0.5, 0)`).
  - `Trigger` (TextButton transparan pembungkus input sentuh `Size = UDim2.new(1, 0, 1, 0)`).
- **Logika Luau:**
  ```lua
  local function ProcessHorizontalInput(inputX, barFrame, minVal, maxVal, step)
      local frameX = barFrame.AbsolutePosition.X
      local frameW = barFrame.AbsoluteSize.X
      if frameW <= 0 then return minVal end

      local relX = math.clamp((inputX - frameX) / frameW, 0, 1)
      local rawVal = minVal + relX * (maxVal - minVal)
      local steps = math.floor(rawVal / step + 0.5)
      return math.clamp(steps * step, minVal, maxVal), relX
  end

  local function UpdateHorizontalVisual(fillFrame, knobFrame, ratio, valueLabel, val)
      if fillFrame then fillFrame.Size = UDim2.new(ratio, 0, 1, 0) end
      if knobFrame then knobFrame.Position = UDim2.new(ratio, -knobFrame.Size.X.Offset / 2, 0.5, 0) end
      if valueLabel then valueLabel.Text = string.format("%.2f", val) end
  end
  ```

---

### C. Switch Button / Toggle (`ToggleSwitch`)
Diadopsi dari `NVMusic.GuiController.ToggleSwitch` (DJ Switch Controller):
- **Struktur Instance:**
  - `SwitchContainer` (Frame Pill / Kapsul: `UICorner` CornerRadius `UDim.new(1, 0)`, background `#141414`).
  - `SwitchFrame` (Indicator bulat / knob kecil di dalam container, `UICorner` `UDim.new(1, 0)`).
  - `SwitchButton` (TextButton transparan `Size = UDim2.new(1, 0, 1, 0)`, `BackgroundTransparency = 1`).
- **Logika & Animasi Tween Luau:**
  ```lua
  local ThemeColors = {
      ActiveItem = Color3.fromRGB(0, 170, 255), -- Cyan saat ON
      Background = Color3.fromRGB(20, 20, 20),   -- Gelap saat OFF
      White = Color3.fromRGB(255, 255, 255),
      SubText = Color3.fromRGB(150, 150, 150)
  }

  local function SetToggleState(isOn: boolean, container: Frame, indicator: Frame, animate: boolean)
      local bgColor = isOn and ThemeColors.ActiveItem or ThemeColors.Background
      local offset = indicator and indicator.Size.X.Offset or 14
      local indicatorPos = isOn and UDim2.new(1, -(offset + 2), 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
      local indicatorColor = isOn and ThemeColors.White or ThemeColors.SubText

      if animate then
          TweenService:Create(container, TweenInfo.new(0.2), { BackgroundColor3 = bgColor }):Play()
          TweenService:Create(indicator, TweenInfo.new(0.2), { Position = indicatorPos, BackgroundColor3 = indicatorColor }):Play()
      else
          container.BackgroundColor3 = bgColor
          indicator.Position = indicatorPos
          indicator.BackgroundColor3 = indicatorColor
      end
  end
  ```

---

### D. Segment Frame (Tab Bar Segment)
Diadopsi dari `NVMembership`, `NVServer`, `NVMusic`, dan `NVDance`:
- **Struktur Instance:**
  - `SegmentFrame` (Container Tab Horizontal: `BackgroundColor3 = Color3.fromRGB(25, 25, 25)`, `UICorner` kapsul `UDim.new(1, 0)` atau `0.5`, `UIPadding`, `UIStroke`).
  - `UIListLayout` (FillDirection `Horizontal`, HorizontalAlignment `Center`, SortOrder `LayoutOrder`).
  - Tab Buttons (`ServerListButton`, `PlayerListButton`, `ManageButton`, dll) dengan `UICorner` rounded.
- **Logika Luau:**
  ```lua
  local function SetActiveTab(tabButtons: { [string]: TextButton }, activeTabName: string, contentFrames: { [string]: GuiObject })
      for name, btn in pairs(tabButtons) do
          if name == activeTabName then
              btn.BackgroundColor3 = Color3.fromRGB(55, 55, 60) -- Active Tab
          else
              btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25) -- Inactive Tab
          end
      end

      for name, frame in pairs(contentFrames) do
          frame.Visible = (name == activeTabName)
      end
  end
  ```

---

### E. Standar Tombol Aktif & Inaktif (Button State Styling)
1. **Gaya Tab / Segment (`ThemeColors`):**
   - **Active:** `Color3.fromRGB(55, 55, 60)` (abu-abu terang kontras).
   - **Inactive:** `Color3.fromRGB(25, 25, 25)` (abu-abu gelap menyatu dengan background).
2. **Gaya Seleksi Item (`SelectStroke`):**
   - Menggunakan child `UIStroke` bernama `SelectStroke` pada tombol:
     - **Active (Selected):** `Color3.fromRGB(0, 255, 255)` (Cyan menyala).
     - **Inactive:** `Color3.fromRGB(60, 60, 65)` (Outline abu-abu gelap).
3. **Gaya Disable / Cooldown (`AutoButtonColor`):**
   - Saat dalam cooldown / limit habis: `AutoButtonColor = false`, teks diubah menjadi `"WAIT (Xs)"` atau `"OUT OF QUOTA"`, dan warna teks/latar diredupkan.


