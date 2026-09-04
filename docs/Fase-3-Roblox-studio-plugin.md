# BLUEPRINT: nvstudio-mcp (Fase 3 - Plugin Roblox Studio)

**Tujuan:** Instruksi ini dirancang untuk dieksekusi oleh AI Agent. Eksekusi instruksi ini untuk membangun Plugin Luau lokal yang akan berkomunikasi dengan Local Bridge Server (Node.js).

### Langkah 1: Setup Direktori Plugin
1. Di dalam *root* direktori proyek `nvstudio-mcp`, buat sebuah folder baru bernama `plugin`.
2. Di dalam folder `plugin`, buat sebuah file berekstensi Lua bernama `nvstudio_mcp.server.lua`. (Akhiran `.server.lua` memastikan script ini berjalan sebagai *server script* di tingkat plugin Studio).

### Langkah 2: Tulis Kode Plugin Luau
Tuliskan (salin) seluruh *source code* Luau di bawah ini ke dalam file `nvstudio_mcp.server.lua`. Kode ini menggunakan `HttpService` untuk melakukan *polling* dan mengeksekusi struktur data yang disepakati pada `API_CONTRACT.md`.

```lua
local HttpService = game:GetService("HttpService")
local TASK_URL = "http://localhost:3000/api/tasks"
local RESPONSE_URL = "http://localhost:3000/api/response"

-- Fungsi untuk mengurai path string (contoh: "Workspace.Map.Part") menjadi Instance
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

-- Fungsi pemrosesan command sesuai API_CONTRACT.md
local function processTask(taskData)
    local command = taskData.command
    local target = taskData.target
    local data = taskData.data

    local targetInstance, err = getInstanceFromPath(target)
    if not targetInstance then
        return { status = "error", error = err }
    end

    if command == "get_children" then
        local children = {}
        for _, child in ipairs(targetInstance:GetChildren()) do
            table.insert(children, child.Name .. " (" .. child.ClassName .. ")")
        end
        return { status = "success", result = children }
        
    elseif command == "get_script_source" then
        if targetInstance:IsA("LuaSourceContainer") then
            return { status = "success", result = targetInstance.Source }
        else
            return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. "). Kamu WAJIB menggunakan get_children terlebih dahulu sebelum menarik source." }
        end
        
    elseif command == "update_script_source" then
        if targetInstance:IsA("LuaSourceContainer") then
            targetInstance.Source = data or ""
            return { status = "success", result = "Script '" .. targetInstance.Name .. "' berhasil diperbarui." }
        else
            return { status = "error", error = "Target BUKAN Script (ClassName: " .. targetInstance.ClassName .. ")." }
        end
        
    else
        return { status = "error", error = "Perintah tidak dikenali oleh Plugin: " .. tostring(command) }
    end
end

-- Polling Loop (Berjalan di background)
task.spawn(function()
    print("[nvstudio-mcp] Plugin aktif, memulai polling ke Local Bridge Server...")
    while true do
        task.wait(1) -- Polling setiap 1 detik
        
        -- Coba GET Request
        local getSuccess, getResponse = pcall(function()
            return HttpService:GetAsync(TASK_URL)
        end)
        
        if getSuccess and getResponse then
            local decodeSuccess, taskData = pcall(function()
                return HttpService:JSONDecode(getResponse)
            end)
            
            -- Jika ada task baru
            if decodeSuccess and type(taskData) == "table" and taskData.id ~= nil then
                local execResult = processTask(taskData)
                execResult.id = taskData.id
                
                -- Kirim POST Request balasan ke server
                pcall(function()
                    local payload = HttpService:JSONEncode(execResult)
                    HttpService:PostAsync(RESPONSE_URL, payload, Enum.HttpContentType.ApplicationJson)
                end)
            end
        end
    end
end)
```

### Langkah 3: Finalisasi & Instruksi Pengguna (User)
1. Simpan file `plugin/nvstudio_mcp.server.lua` tersebut.
2. Informasikan kepada *User* (pengguna manusia) bahwa untuk mengaktifkan ini, mereka harus:
   - Mengopi file `nvstudio_mcp.server.lua` ke dalam direktori `Plugins` lokal Roblox Studio mereka (biasanya di `%LOCALAPPDATA%\Roblox\Plugins` untuk Windows).
   - Membuka Roblox Studio, masuk ke menu **Game Settings > Security**, lalu mencentang opsi **"Allow HTTP Requests"** agar plugin diizinkan berkomunikasi dengan port 3000.
3. Eksekusi penulisan file ini sekarang.