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
local lastTaskTime = 0 -- Untuk logic transisi UI "Waiting" vs "Connected"

-- Deklarasi fungsi polling di awal agar bisa dipanggil oleh UI
local startPolling

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
    
    -- Event Tombol Connect
    ui.connectBtn.MouseButton1Click:Connect(function()
        isConnected = not isConnected
        if isConnected then
            ui:setStatus("waiting")
            ui:addLog("[System] Koneksi manual dimulai. Mencari AI Server (Waiting)...", Color3.fromRGB(255, 220, 100))
            startPolling()
        else
            ui:setStatus("disconnected")
            ui:addLog("[System] Koneksi dihentikan oleh pengguna.", Color3.fromRGB(255, 100, 100))
        end
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

-- Background Polling Loop (Dapat dihentikan oleh user)
function startPolling()
    if isPolling then return end
    isPolling = true
    
    task.spawn(function()
        while isConnected do
            local success, response = pcall(function()
                return HttpService:GetAsync(TASK_URL)
            end)

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
            else
                -- Fetch gagal (Node.js server mati karena IDE/Antigravity/Cursor ditutup)
                if ui then ui:setStatus("waiting") end
            end
            
            task.wait(1)
        end
        isPolling = false
    end)
end

-- Eksekusi Awal (Start-up)
if autoConnect then
    isConnected = true
    if ui then
        ui:setStatus("waiting")
        ui:addLog("[System] Auto-Connect menyala. Mencari jembatan Node.js...", Color3.fromRGB(255, 220, 100))
    end
    startPolling()
else
    if ui then
        ui:addLog("[System] Plugin termuat sukses. Tekan 'Connect' di atas untuk menyambung.", Color3.fromRGB(200, 200, 200))
    end
end
