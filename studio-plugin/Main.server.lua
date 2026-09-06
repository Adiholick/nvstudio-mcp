local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

local TASK_URL = "http://localhost:3055/api/tasks"
local RESPONSE_URL = "http://localhost:3055/api/response"

-- Generate Unique Studio ID (menghindari bentrok jika 2 Studio terbuka)
local STUDIO_ID = HttpService:GenerateGUID(false)

-- Import UI Manager (Procedural Dashboard)
local uiModule = script.Parent:FindFirstChild("ui_manager")
local ui = nil

-- Membangun Tombol Toolbar (Toggle)
local toolbar = plugin:CreateToolbar("NVStudio MCP")
local toggleBtn = toolbar:CreateButton("Dashboard", "Buka Dashboard NVStudio MCP", "rbxassetid://82696893597722")

-- Global State & Context AI
local ctx = {
    scriptHistory = {},
    recentLogs = {},
    HttpService = HttpService,
    studioId = STUDIO_ID
}
local MAX_LOGS = 50
local isConnected = false
local autoConnect = plugin:GetSetting("AutoConnect") or false
local isPolling = false
local isClickDebounce = false -- Mencegah rapid double-click

-- Deklarasi fungsi polling di awal agar bisa dipanggil oleh UI
local startPolling
local stopPolling

-- Inisialisasi UI jika modul ditemukan
if uiModule then
    local UIManager = require(uiModule)
    ui = UIManager.init(plugin, STUDIO_ID)
    
    -- Sync Initial State ke UI
    ui:setAutoConnectState(autoConnect)
    ui:setStatus("disconnected")
    
    -- Event Toggle GUI Panel
    toggleBtn.Click:Connect(function()
        ui:toggleVisibility()
    end)
    
    -- Event Tombol Connect (dengan debounce untuk mencegah double-click)
    ui.connectBtn.MouseButton1Click:Connect(function()
        if isClickDebounce then return end
        isClickDebounce = true
        
        if not isConnected then
            -- CONNECT (manual) — reset manual disconnect flag agar auto-detect bisa bekerja
            isManualDisconnect = false
            isConnected = true
            ui:setStatus("waiting")
            ui:addLog("[System] Koneksi manual dimulai. Mencari AI Server (Waiting)...", Color3.fromRGB(255, 220, 100))
            startPolling()
        else
            -- DISCONNECT — hentikan polling dan tandai manual disconnect
            stopPolling()
            ui:setStatus("disconnected")
            ui:addLog("[System] Koneksi dihentikan oleh pengguna.", Color3.fromRGB(255, 100, 100))
        end
        
        task.delay(0.3, function()
            isClickDebounce = false
        end)
    end)
    
    -- Event Custom Checkbox (Auto-Connect)
    ui.autoConnectBtn.MouseButton1Click:Connect(function()
        autoConnect = not autoConnect
        plugin:SetSetting("AutoConnect", autoConnect)
        ui:setAutoConnectState(autoConnect)
        ui:addLog("[System] Preferensi Auto-Connect disimpan: " .. tostring(autoConnect), Color3.fromRGB(200, 200, 255))
    end)
else
    -- Fallback aman jika pengguna lupa meng-copy ui_manager.lua
    toggleBtn.Click:Connect(function()
        print("[NVStudio MCP] ERROR: Modul 'ui_manager' tidak ditemukan di dalam Folder. GUI Gagal dimuat!")
    end)
end

-- Handler Output Studio (Untuk AI dan GUI)
local function addSystemLog(msg, msgType)
    local color = Color3.fromRGB(200, 200, 200)
    local prefix = "[INFO] "
    if msgType == Enum.MessageType.MessageError then
        prefix = "[ERROR] "
        color = Color3.fromRGB(255, 100, 100)
    elseif msgType == Enum.MessageType.MessageWarning then
        prefix = "[WARN] "
        color = Color3.fromRGB(255, 200, 100)
    end
    
    local fullMsg = prefix .. msg
    
    -- 1. Simpan di memori untuk disedot AI
    table.insert(ctx.recentLogs, fullMsg)
    if #ctx.recentLogs > MAX_LOGS then
        table.remove(ctx.recentLogs, 1)
    end
    
    -- 2. Cetak ke Terminal GUI Plugin
    if ui then
        ui:addLog(fullMsg, color)
    end
end

-- Ikat listener output
LogService.MessageOut:Connect(addSystemLog)

-- Memuat semua module skills secara dinamis
local skills = {}
for _, module in ipairs(script.Parent:GetChildren()) do
    if module:IsA("ModuleScript") and module.Name ~= "ui_manager" then
        skills[module.Name] = require(module)
    end
end

-- Fungsi Helper Pathing
local function getInstanceFromPath(pathString)
    local parts = string.split(pathString, ".")
    local current = game
    
    if parts[1] == "game" then table.remove(parts, 1) end
    
    -- Handle common Services directly to ensure reliability
    pcall(function()
        local svc = game:GetService(parts[1])
        if svc then
            current = svc
            table.remove(parts, 1)
        end
    end)
    
    for _, part in ipairs(parts) do
        local found = current:FindFirstChild(part)
        if not found then return nil end
        current = found
    end
    return current
end

-- Memproses Task Eksekusi dari AI
local function processTask(taskData)
    if not taskData or not taskData.id or not taskData.command then return nil end
    
    if ui then 
        ui:addLog("[AI Command] Menerima instruksi: " .. taskData.command, Color3.fromRGB(150, 200, 255)) 
    end
    
    local targetInstance = getInstanceFromPath(taskData.target)
    if not targetInstance then
        return {
            id = taskData.id,
            status = "error",
            error = "Target path tidak ditemukan: " .. taskData.target
        }
    end

    local skillFunc = skills[taskData.command]
    if not skillFunc then
        return {
            id = taskData.id,
            status = "error",
            error = "Command tidak dikenali oleh Studio: " .. taskData.command
        }
    end

    -- Eksekusi skill AI
    local result = skillFunc(targetInstance, taskData.data, ctx, taskData.target)
    result.id = taskData.id
    
    -- Cetak hasil eksekusi ke Terminal GUI
    if ui then
        local color = result.status == "success" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        ui:addLog("[AI Result] " .. tostring(result.result or result.error), color)
    end
    
    return result
end

-- Menghentikan polling dengan bersih (dipanggil oleh tombol Disconnect)
local isManualDisconnect = false -- Mencegah auto-reconnect saat user sengaja disconnect

function stopPolling()
    isConnected = false
    isManualDisconnect = true
    -- isPolling akan menjadi false secara otomatis saat loop keluar
end

-- Background Polling Loop (Dapat dihentikan oleh user)
function startPolling()
    if isPolling then return end
    isPolling = true
    
    task.spawn(function()
        while isConnected do
            local success, response = pcall(function()
                -- Tambahkan cache-buster agar Studio tidak me-cache response HTTP
                local cacheBuster = "?t=" .. tostring(os.clock())
                return HttpService:GetAsync(TASK_URL .. cacheBuster)
            end)

            -- PENTING: Cek ulang isConnected SETELAH HTTP request selesai.
            if not isConnected then
                break
            end

            if success and response then
                -- JIKA PING SUKSES, Node.js menyala (IDE / Agen Sedang Terbuka!)
                if ui then ui:setStatus("connected") end

                local decodeSuccess, taskData = pcall(function()
                    return HttpService:JSONDecode(response)
                end)
                
                if decodeSuccess and taskData and taskData.id then
                    local resultData = processTask(taskData)
                    if resultData then
                        pcall(function()
                            local jsonResult = HttpService:JSONEncode(resultData)
                            HttpService:PostAsync(RESPONSE_URL, jsonResult, Enum.HttpContentType.ApplicationJson)
                        end)
                    end
                end
                
                -- Fast-polling (long-polling yield di server Node.js)
                -- 50ms untuk safety mencegah Studio Engine freeze jika Node.js membalas instant
                task.wait(0.05)
            else
                -- Fetch gagal (Node.js server mati karena IDE/Antigravity/Cursor ditutup)
                if ui then ui:setStatus("waiting") end
                task.wait(1)
            end
            
            -- Cek lagi sebelum sleep (agar disconnect lebih responsif)
            if not isConnected then
                break
            end
        end
        isPolling = false
    end)
end

-- ══════════════════════════════════════════════════════════════════════
-- AUTO-DETECT: Background heartbeat yang SELALU berjalan.
-- Mendeteksi apakah server MCP aktif setiap 2 detik.
-- Jika terdeteksi aktif → otomatis connect (tanpa perlu tekan tombol).
-- Jika terdeteksi mati → otomatis update status.
-- ══════════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(1) -- Tunggu sebentar agar UI siap
    
    if ui then
        ui:addLog("[System] Plugin termuat. Auto-detect server MCP aktif...", Color3.fromRGB(200, 200, 200))
    end
    
    while true do
        -- Skip heartbeat jika polling loop sudah aktif (ia sudah menangani semuanya)
        if not isPolling then
            local success, errorMsg = pcall(function()
                local cacheBuster = "?t=" .. tostring(os.clock())
                return HttpService:GetAsync(TASK_URL .. cacheBuster)
            end)
            
            if success then
                -- Server terdeteksi aktif!
                if not isConnected and not isManualDisconnect then
                    isConnected = true
                    if ui then
                        ui:setStatus("connected")
                        ui:addLog("[System] Server MCP terdeteksi! Auto-connected.", Color3.fromRGB(100, 255, 100))
                    end
                    startPolling()
                end
            else
                -- Server tidak aktif
                if isConnected then
                    -- Server baru saja mati (sebelumnya connected) — polling loop juga akan exit
                    isConnected = false
                    if ui then
                        ui:setStatus("waiting")
                        ui:addLog("[System] Server MCP terputus. Menunggu reconnect...", Color3.fromRGB(255, 200, 100))
                    end
                elseif not isManualDisconnect then
                    if ui then 
                        ui:setStatus("waiting") 
                        -- HANYA print error jika belum terkoneksi, untuk debugging
                        ui:addLog("[Debug] Deteksi gagal: " .. tostring(errorMsg), Color3.fromRGB(150, 150, 150))
                    end
                end
            end
        end
        
        task.wait(2)
    end
end)
