# BLUEPRINT: nvstudio-mcp (Fase 10 - Arsitektur Modular & Hybrid Installation Method)

**Tujuan:** Merombak arsitektur plugin Roblox Studio menjadi sistem modular berbasis folder `skills` yang bersih dan independen, serta menyediakan sistem instalasi **Hybrid Method**. Sistem instalasi hybrid ini dapat memasang **Roblox Studio Plugin** (`.rbxm`), mengatur **MCP Otomatis** (untuk Cursor/Windsurf), sekaligus menyediakan **AI Agent Plugin Bundle** (untuk Claude/Antigravity) tanpa kerancuan.

---

## 1. Klarifikasi Arsitektur Hybrid: Tiga Komponen Utama

Untuk mendukung metode instalasi Hybrid (layaknya Weppy), kita membagi proyek ke dalam tiga area tanggung jawab yang tegas:

```
nvstudio-mcp/
├── src/                          <-- [1. CORE BRIDGE SERVER]
│   ├── index.ts                  (Daftar MCP Tools)
│   └── roblox-bridge.ts          (Server HTTP & WebSocket di Port 3055)
│
├── studio-plugin/                <-- [2. PLUGIN ROBLOX STUDIO] (Jelas & Tidak Ambigu)
│   ├── init.server.lua           (Kernel router & background polling loop Luau)
│   ├── nvstudio_mcp.rbxm         (Hasil kemasan/build model untuk installer sistem)
│   └── skills/                   (Koleksi ModuleScript Luau independen)
│       ├── get_children.lua
│       ├── update_script_source.lua
│       └── ...
│
├── agent-plugin/                 <-- [3. AI AGENT PLUGIN BUNDLE]
│   ├── plugin.json               (Manifest ekosistem plugin Claude/Antigravity)
│   ├── mcp_config.json           (Pendaftaran MCP otomatis untuk plugin AI)
│   └── skills/                   (Dokumen Markdown panduan kerja AI / Cheatsheets)
│       ├── nvstudio-guide.md
│       └── anti-hallucination.md
│
└── docs/                         <-- Dokumentasi & API Contract
```

### Tabel Perbedaan Komponen

| Karakteristik | `src/` (Core Bridge Server) | `studio-plugin/` (Plugin Roblox Studio) | `agent-plugin/` (Plugin AI Agent) |
| :--- | :--- | :--- | :--- |
| **Fungsi Utama** | Server penghubung JSON-RPC (MCP) ke HTTP polling | Mengeksekusi aksi nyata di dalam Roblox Studio | Menyuntikkan instruksi, *rules*, dan *tools* secara terpusat ke AI |
| **Format Berkas** | TypeScript / Node.js | Luau / `.rbxm` | JSON & Markdown (`SKILL.md`) |
| **Distribusi (Installer)**| Dijalankan secara lokal (background) | Disalin ke `%LOCALAPPDATA%\Roblox\Plugins\` | Disalin ke direktori plugin AI (misal `~/.gemini/config/plugins/`) atau via perintah `/plugin install` |
| **Metode Instalasi AI** | **Auto-Configurator** (Menginjeksi file `mcpServers.json` secara langsung) | - | **Plugin Bundle** (Dikelola resmi oleh lingkungan AI tanpa merusak config JSON) |

---

## 2. Struktur Direktori `studio-plugin/`

Folder plugin Roblox Studio dinamai secara eksplisit **`studio-plugin/`**:

```text
nvstudio-mcp/
└── studio-plugin/
    ├── init.server.lua          # Router utama & polling worker
    ├── nvstudio_mcp.rbxm        # Kemasan binary tunggal untuk folder sistem Roblox
    └── skills/                  # Modul keterampilan terpisah (ModuleScript)
        ├── get_children.lua
        ├── get_script_source.lua
        ├── update_script_source.lua
        ├── rollback_script.lua
        ├── get_logs.lua
        ├── search_instance.lua
        ├── create_instance.lua
        ├── insert_asset.lua
        └── generate_terrain.lua
```

---

## 3. Core Plugin Roblox Studio (`studio-plugin/init.server.lua`)

Berkas `init.server.lua` bertindak sebagai kernel/router utama di dalam Roblox Studio:

```lua
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

local TASK_URL = "http://localhost:3055/api/tasks"
local RESPONSE_URL = "http://localhost:3055/api/response"

-- State Sesi Global
local scriptHistory = {}
local recentLogs = {}
local MAX_LOGS = 50

-- Listener Output Studio untuk Live Debugging (Fase 7)
LogService.MessageOut:Connect(function(message, messageType)
    local prefix = "[INFO] "
    if messageType == Enum.MessageType.MessageError then
        prefix = "[ERROR] "
    elseif messageType == Enum.MessageType.MessageWarning then
        prefix = "[WARNING] "
    end
    
    table.insert(recentLogs, prefix .. message)
    if #recentLogs > MAX_LOGS then
        table.remove(recentLogs, 1)
    end
end)

-- Memuat semua module skills yang ada di dalam folder skills secara dinamis
local skills = {}
local skillsFolder = script:FindFirstChild("skills")

if skillsFolder then
    for _, child in ipairs(skillsFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local success, skillModule = pcall(require, child)
            if success and type(skillModule) == "function" then
                skills[child.Name] = skillModule
                print("[nvstudio-mcp] Skill dimuat: " .. child.Name)
            else
                warn("[nvstudio-mcp] Gagal memuat skill module: " .. child.Name .. " -> " .. tostring(skillModule))
            end
        end
    end
else
    warn("[nvstudio-mcp] Folder 'skills' tidak ditemukan di dalam direktori plugin!")
end

-- Helper universal untuk mengurai path string (contoh: "Workspace.Map.Part") menjadi Instance
local function getInstanceFromPath(path)
    local parts = string.split(path, ".")
    local current = game
    
    for i, part in ipairs(parts) do
        if part == "game" and i == 1 then
            continue
        end
        local success, nextInstance = pcall(function()
            return current[part]
        end)
        
        if not success or not nextInstance then
            return nil, "Gagal menemukan instance '" .. part .. "' pada path: " .. path
        end
        current = nextInstance
    end
    
    return current, nil
end

-- Context object yang dibagikan ke setiap skill
local context = {
    getPath = getInstanceFromPath,
    scriptHistory = scriptHistory,
    recentLogs = recentLogs,
    HttpService = HttpService
}

local function processTask(taskData)
    local command = taskData.command
    local target = taskData.target
    local data = taskData.data

    -- Validasi keberadaan modul skill
    if skills[command] then
        local success, result = pcall(function()
            return skills[command](target, data, context)
        end)
        
        if success then
            return result 
        else
            return { status = "error", error = "Crash pada eksekusi skill '" .. command .. "': " .. tostring(result) }
        end
    else
        return { status = "error", error = "Skill/Command tidak ditemukan: " .. tostring(command) }
    end
end

-- Polling Loop Utama (Background Worker)
task.spawn(function()
    print("[nvstudio-mcp] Modular Plugin aktif, memulai polling ke port 3055...")
    while true do
        task.wait(1)
        local getSuccess, getResponse = pcall(function()
            return HttpService:GetAsync(TASK_URL)
        end)
        
        if getSuccess and getResponse then
            local decodeSuccess, taskData = pcall(function()
                return HttpService:JSONDecode(getResponse)
            end)
            
            if decodeSuccess and type(taskData) == "table" and taskData.id ~= nil then
                local execResult = processTask(taskData)
                execResult.id = taskData.id
                
                pcall(function()
                    local payload = HttpService:JSONEncode(execResult)
                    HttpService:PostAsync(RESPONSE_URL, payload, Enum.HttpContentType.ApplicationJson)
                end)
            end
        end
    end
end)
```

---

## 4. Modul Keterampilan di `studio-plugin/skills/`

Masing-masing berkas di bawah ini disimpan sebagai `ModuleScript` Luau independen dengan signature `function(target, data, ctx)`.

### 1. `studio-plugin/skills/get_children.lua`
```lua
return function(target, data, ctx)
    local targetInst, err = ctx.getPath(target)
    if not targetInst then return { status = "error", error = err } end
    
    local children = {}
    for _, child in ipairs(targetInst:GetChildren()) do
        table.insert(children, child.Name .. " (" .. child.ClassName .. ")")
    end
    return { status = "success", result = children }
end
```

### 2. `studio-plugin/skills/get_script_source.lua`
```lua
return function(target, data, ctx)
    local targetInst, err = ctx.getPath(target)
    if not targetInst then return { status = "error", error = err } end
    
    if targetInst:IsA("LuaSourceContainer") then
        return { status = "success", result = targetInst.Source }
    else
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInst.ClassName .. "). Gunakan get_children terlebih dahulu." }
    end
end
```

### 3. `studio-plugin/skills/update_script_source.lua`
```lua
return function(target, data, ctx)
    local targetInst, err = ctx.getPath(target)
    if not targetInst then return { status = "error", error = err } end
    
    if targetInst:IsA("LuaSourceContainer") then
        local newCode = data or ""
        
        -- Luau AST Validator (Mengecek syntax tanpa mengeksekusi)
        local syntaxSuccess, syntaxError = loadstring(newCode)
        if not syntaxSuccess then
            return { 
                status = "error", 
                error = "SYNTAX ERROR (AST Validation Gagal): " .. tostring(syntaxError) .. ". Script dibatalkan." 
            }
        end
        
        -- Simpan backup untuk fitur rollback
        ctx.scriptHistory[target] = targetInst.Source
        targetInst.Source = newCode
        return { status = "success", result = "Script '" .. targetInst.Name .. "' divalidasi dan berhasil diperbarui." }
    else
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInst.ClassName .. ")." }
    end
end
```

### 4. `studio-plugin/skills/rollback_script.lua`
```lua
return function(target, data, ctx)
    local targetInst, err = ctx.getPath(target)
    if not targetInst then return { status = "error", error = err } end
    
    if targetInst:IsA("LuaSourceContainer") then
        local prevSource = ctx.scriptHistory[target]
        if prevSource then
            targetInst.Source = prevSource
            return { status = "success", result = "Script '" .. targetInst.Name .. "' berhasil di-rollback ke versi sebelumnya." }
        else
            return { status = "error", error = "Tidak ada riwayat backup sebelumnya di sesi Studio ini untuk: " .. target }
        end
    else
        return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInst.ClassName .. ")." }
    end
end
```

### 5. `studio-plugin/skills/get_logs.lua`
```lua
return function(target, data, ctx)
    if not ctx.recentLogs or #ctx.recentLogs == 0 then
        return { status = "success", result = { "Console kosong. Tidak ada error atau log terbaru." } }
    else
        return { status = "success", result = ctx.recentLogs }
    end
end
```

### 6. `studio-plugin/skills/search_instance.lua`
```lua
return function(target, data, ctx)
    local searchName = tostring(data)
    local results = {}
    
    local searchableServices = {
        game:GetService("Workspace"), 
        game:GetService("ReplicatedStorage"), 
        game:GetService("ServerScriptService"), 
        game:GetService("StarterGui")
    }
    
    for _, service in ipairs(searchableServices) do
        for _, desc in ipairs(service:GetDescendants()) do
            if desc.Name == searchName then
                table.insert(results, desc:GetFullName())
            end
        end
    end
    
    if #results > 0 then
        return { status = "success", result = results }
    else
        return { status = "success", result = "Tidak ditemukan instance dengan nama: " .. searchName }
    end
end
```

### 7. `studio-plugin/skills/create_instance.lua`
```lua
return function(target, data, ctx)
    local targetInst, err = ctx.getPath(target)
    if not targetInst then return { status = "error", error = err } end
    
    local success, config = pcall(function() return ctx.HttpService:JSONDecode(data) end)
    if not success or not config.ClassName then
        return { status = "error", error = "Format data JSON tidak valid atau ClassName hilang." }
    end
    
    local newSuccess, newInst = pcall(function()
        local inst = Instance.new(config.ClassName)
        inst.Parent = targetInst
        
        if config.Properties then
            for prop, val in pairs(config.Properties) do
                pcall(function() inst[prop] = val end)
            end
        end
        return inst
    end)
    
    if newSuccess then
        return { status = "success", result = "Instance '" .. config.ClassName .. "' berhasil dibuat di " .. target }
    else
        return { status = "error", error = "Gagal membuat Instance. Pastikan ClassName valid." }
    end
end
```

### 8. `studio-plugin/skills/insert_asset.lua`
```lua
return function(target, data, ctx)
    local InsertService = game:GetService("InsertService")
    local assetId = tonumber(data)
    if not assetId then
        return { status = "error", error = "Asset ID harus berupa angka yang valid." }
    end
    
    local success, model = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    
    if success and model then
        model.Parent = game.Workspace
        return { status = "success", result = "Aset berhasil dimasukkan ke Workspace." }
    else
        return { status = "error", error = "Gagal memuat aset. Pastikan Asset ID benar dan memiliki izin kepemilikan/publikasi." }
    end
end
```

### 9. `studio-plugin/skills/generate_terrain.lua`
```lua
return function(target, data, ctx)
    local success, config = pcall(function() return ctx.HttpService:JSONDecode(data) end)
    if not success or not config.Size or not config.Position or not config.Material then
        return { status = "error", error = "Format JSON tidak valid. Membutuhkan Size, Position, dan Material." }
    end
    
    local terrain = game.Workspace.Terrain
    local materialEnum = Enum.Material[config.Material] or Enum.Material.Grass
    
    local size = Vector3.new(config.Size[1], config.Size[2], config.Size[3])
    local position = Vector3.new(config.Position[1], config.Position[2], config.Position[3])
    
    local region = Region3.new(position - (size / 2), position + (size / 2))
    
    local fillSuccess, err = pcall(function()
        terrain:FillRegion(region:ExpandToGrid(4), 4, materialEnum)
    end)
    
    if fillSuccess then
        return { status = "success", result = "Terrain (" .. config.Material .. ") berhasil di-generate." }
    else
        return { status = "error", error = "Gagal men-generate Terrain: " .. tostring(err) }
    end
end
```

---

## 5. Panduan Pembuatan File `.rbxm` (Roblox Binary Model)

Agar installer dapat memasang plugin sebagai satu berkas tunggal yang utuh ke folder Plugins Roblox Studio:

### Metode: Manual Export dari Roblox Studio (Direkomendasikan Tanpa Toolchain Eksternal)

1. Buka **Roblox Studio** dan buat place baru (kosong).
2. Di panel **Explorer**:
   - Klik kanan pada `ServerScriptService` -> Pilih `Insert Object` -> **`Script`**.
   - Beri nama script tersebut: **`nvstudio_mcp`**.
   - Buka script tersebut dan tempel seluruh isi dari `studio-plugin/init.server.lua`.
3. Di dalam instance `nvstudio_mcp`:
   - Klik ikon `+` pada script `nvstudio_mcp` -> Buat sebuah **`Folder`**.
   - Beri nama folder tersebut: **`skills`**.
4. Di dalam folder `skills`:
   - Buat 9 buah **`ModuleScript`** dengan nama masing-masing:
     1. `get_children`
     2. `get_script_source`
     3. `update_script_source`
     4. `rollback_script`
     5. `get_logs`
     6. `search_instance`
     7. `create_instance`
     8. `insert_asset`
     9. `generate_terrain`
   - Buka masing-masing ModuleScript dan tempel kode dari file `.lua` yang sesuai.
5. **Simpan ke File Model (`.rbxm`)**:
   - Klik kanan pada script induk **`nvstudio_mcp`** di jendela Explorer.
   - Pilih menu **"Save to File..."**.
   - Beri nama file: **`nvstudio_mcp.rbxm`** (pilih tipe file *Roblox Model File (*.rbxm)*).
   - Simpan berkas tersebut ke dalam folder direktori proyek: `studio-plugin/nvstudio_mcp.rbxm`.

---

## 6. Mekanisme Instalasi ke Sistem Roblox Studio

Setelah file `studio-plugin/nvstudio_mcp.rbxm` tersedia, script installer `install.sh` atau auto-installer Node.js akan menyalinnya langsung ke folder plugins sistem:

- **Windows**: `%LOCALAPPDATA%\Roblox\Plugins\nvstudio_mcp.rbxm`
- **macOS**: `~/Documents/Roblox/Plugins/nvstudio_mcp.rbxm`

### Penyesuaian pada `install.sh` (Untuk Sisi Roblox):
```bash
PLUGIN_DIR=""
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    PLUGIN_DIR="$LOCALAPPDATA/Roblox/Plugins"
elif grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
    PLUGIN_DIR="/mnt/c/Users/$WIN_USER/AppData/Local/Roblox/Plugins"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLUGIN_DIR="$HOME/Documents/ROBLOX/Plugins"
fi

if [ -n "$PLUGIN_DIR" ]; then
    mkdir -p "$PLUGIN_DIR"
    cp studio-plugin/nvstudio_mcp.rbxm "$PLUGIN_DIR/"
    echo "✅ Plugin nvstudio_mcp.rbxm berhasil dipasang ke: $PLUGIN_DIR"
fi
```

---

## 7. Mekanisme Instalasi ke Sistem AI Agent (Metode Hybrid)

Selain memasang `.rbxm` ke Roblox, installer `install.sh` juga akan mendeteksi lingkungan kerja pengembang (AI IDE mana yang digunakan) dan memasang konfigurasi MCP menggunakan **Metode Hybrid**:

### A. Metode Auto-Configurator (Untuk AI Berbasis JSON)
Ditujukan untuk Editor yang membaca file konfigurasi `mcp.json` secara statis, seperti **Cursor** atau **Windsurf**. Installer akan menginjeksi entri ke file JSON pengguna secara terprogram menggunakan Node.js inline.

**Logika Injeksi (Pseudocode di install.sh):**
```javascript
const config = JSON.parse(fs.readFileSync('.cursor/mcp.json'));
config.mcpServers["nvstudio-mcp"] = {
    command: "npx",
    args: ["-y", "nvstudio-mcp@latest"]
};
fs.writeFileSync('.cursor/mcp.json', JSON.stringify(config));
```

### B. Metode Plugin Bundle (Untuk Ekosistem AI Lanjutan)
Ditujukan untuk **Antigravity IDE** atau **Claude Code** yang mendukung sistem *Plugin Extension* penuh. Installer akan menyalin folder `agent-plugin/` (yang berisi `plugin.json` dan folder `skills/`) ke direktori plugin milik AI agent.

- Folder target Antigravity: `~/.gemini/config/plugins/nvstudio-mcp/`
- Command alternatif Antigravity: `agy plugin install path/to/agent-plugin`

Metode Bundle ini mengizinkan AI Agent untuk membaca file panduan anti-halusinasi (*Cheatsheets*) dari folder `skills/` tanpa harus menghafalnya, mengurangi risiko kesalahan pemanggilan API saat memodifikasi skrip Roblox.