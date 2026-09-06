-- ══════════════════════════════════════════════════════════════════════
-- NVStudio MCP Plugin v2.1.0
-- Arsitektur: SSE (Server-Sent Events) via WebStreamClient
-- Plugin membuka koneksi stream persisten ke server Node.js.
-- Server PUSH task langsung — tidak ada polling loop.
-- ══════════════════════════════════════════════════════════════════════

local HttpService    = game:GetService("HttpService")
local LogService     = game:GetService("LogService")

-- URL Endpoints
local BASE_URL       = "http://localhost:3055"
local STREAM_URL     = BASE_URL .. "/api/stream"
local RESPONSE_URL   = BASE_URL .. "/api/response"  -- /api/response/:taskId via POST
local PING_URL       = BASE_URL .. "/api/ping"

-- ID unik per sesi Studio (jika dua Studio terbuka, keduanya didaftarkan terpisah)
local STUDIO_ID      = HttpService:GenerateGUID(false)

-- ── UI Module ──────────────────────────────────────────────────────────────────
local uiModule = script.Parent:FindFirstChild("ui_manager")
local ui = nil

-- ── Toolbar ───────────────────────────────────────────────────────────────────
local toolbar   = plugin:CreateToolbar("NVStudio MCP")
local toggleBtn = toolbar:CreateButton("Dashboard", "Buka Dashboard NVStudio MCP", "rbxassetid://82696893597722", "NVStudio")

-- ── State ─────────────────────────────────────────────────────────────────────
local ctx = {
    scriptHistory = {},
    recentLogs    = {},
    HttpService   = HttpService,
    studioId      = STUDIO_ID,
}
local MAX_LOGS          = 50
local isConnected       = false   -- apakah SSE stream aktif
local mcpAgentActive    = false   -- apakah Antigravity/Cursor sedang konek ke MCP
local isManualDisconnect = false
local isClickDebounce   = false
local currentStream     = nil     -- WebStreamClient aktif
local streamConnections = {}      -- RBXScriptConnection SSE

-- Reconnect config (exponential backoff)
local RECONNECT_DELAY_INITIAL = 0.5
local RECONNECT_DELAY_MAX     = 10
local reconnectDelay          = RECONNECT_DELAY_INITIAL

-- ── Skills (ModuleScript) ─────────────────────────────────────────────────────
local skills = {}
for _, module in ipairs(script.Parent:GetChildren()) do
    if module:IsA("ModuleScript") and module.Name ~= "ui_manager" then
        local ok, result = pcall(require, module)
        if ok then
            skills[module.Name] = result
        else
            warn("[NVStudio] Gagal load module '" .. module.Name .. "': " .. tostring(result))
        end
    end
end

-- ── Inisialisasi UI ──────────────────────────────────────────────────────────
if uiModule then
    local UIManager = require(uiModule)
    ui = UIManager.init(plugin, STUDIO_ID)

    ui:setAutoConnectState(true)
    ui:setStatus("waiting")

    if ui.widget then
        toggleBtn:SetActive(ui.widget.Enabled)
        ui.widget:GetPropertyChangedSignal("Enabled"):Connect(function()
            toggleBtn:SetActive(ui.widget.Enabled)
        end)
    end

    toggleBtn.Click:Connect(function()
        ui:toggleVisibility()
    end)

    -- Tombol Connect / Disconnect
    ui.connectBtn.MouseButton1Click:Connect(function()
        if isClickDebounce then return end
        isClickDebounce = true

        if not isConnected then
            isManualDisconnect = false
            reconnectDelay = RECONNECT_DELAY_INITIAL
            ui:setStatus("waiting")
            ui:addLog("[System] Menghubungkan ulang ke Server MCP...", Color3.fromRGB(255, 220, 100))
            task.spawn(connectSSE)
        else
            isManualDisconnect = true
            disconnectSSE()
            ui:setStatus("disconnected")
            ui:addLog("[System] Koneksi dihentikan oleh pengguna.", Color3.fromRGB(255, 100, 100))
        end

        task.delay(0.3, function() isClickDebounce = false end)
    end)
else
    toggleBtn.Click:Connect(function()
        print("[NVStudio MCP] ERROR: Modul 'ui_manager' tidak ditemukan. GUI gagal dimuat!")
    end)
end

-- ── Log Capture ──────────────────────────────────────────────────────────────
local function addSystemLog(msg, msgType)
    local color  = Color3.fromRGB(200, 200, 200)
    local prefix = "[INFO] "
    if msgType == Enum.MessageType.MessageError then
        prefix = "[ERROR] "; color = Color3.fromRGB(255, 100, 100)
    elseif msgType == Enum.MessageType.MessageWarning then
        prefix = "[WARN] ";  color = Color3.fromRGB(255, 200, 100)
    end
    local fullMsg = prefix .. msg
    table.insert(ctx.recentLogs, fullMsg)
    if #ctx.recentLogs > MAX_LOGS then table.remove(ctx.recentLogs, 1) end
    if ui then ui:addLog(fullMsg, color) end
end
LogService.MessageOut:Connect(addSystemLog)

-- ── Helper: Resolve path ke Instance ─────────────────────────────────────────
local function getInstanceFromPath(pathString)
    local parts   = string.split(pathString, ".")
    local current = game
    if parts[1] == "game" then table.remove(parts, 1) end
    pcall(function()
        local svc = game:GetService(parts[1])
        if svc then current = svc; table.remove(parts, 1) end
    end)
    for _, part in ipairs(parts) do
        local found = current:FindFirstChild(part)
        if not found then return nil end
        current = found
    end
    return current
end

-- ── Proses Task dari Server ───────────────────────────────────────────────────
local function processTask(taskData)
    if not taskData or not taskData.id or not taskData.command then return nil end

    if ui then
        ui:addLog("[AI Command] " .. taskData.command, Color3.fromRGB(150, 200, 255))
    end

    local targetInstance = getInstanceFromPath(taskData.target)
    if not targetInstance then
        return { id = taskData.id, status = "error", error = "Target path tidak ditemukan: " .. tostring(taskData.target) }
    end

    local skillFunc = skills[taskData.command]
    if not skillFunc then
        return { id = taskData.id, status = "error", error = "Command tidak dikenali: " .. taskData.command }
    end

    local result = skillFunc(targetInstance, taskData.data, ctx, taskData.target)
    result.id    = taskData.id

    if ui then
        local color = result.status == "success" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        ui:addLog("[AI Result] " .. tostring(result.result or result.error), color)
    end

    return result
end

-- ── Kirim Respons ke Server ───────────────────────────────────────────────────
local function sendResponse(taskId, resultData)
    task.spawn(function()
        local ok, err = pcall(function()
            local json = HttpService:JSONEncode(resultData)
            -- Coba endpoint baru dulu (/api/response/:taskId), fallback ke lama
            local success = pcall(function()
                HttpService:PostAsync(
                    RESPONSE_URL .. "/" .. taskId,
                    json,
                    Enum.HttpContentType.ApplicationJson
                )
            end)
            if not success then
                HttpService:PostAsync(RESPONSE_URL, json, Enum.HttpContentType.ApplicationJson)
            end
        end)
        if not ok and ui then
            ui:addLog("[System] Gagal kirim response: " .. tostring(err), Color3.fromRGB(255, 100, 100))
        end
    end)
end

-- ── Proses satu baris data SSE ────────────────────────────────────────────────
local function handleSSEMessage(rawMessage)
    -- Strip prefix "data: " jika ada (beberapa Studio version memberikannya)
    local payload = rawMessage
    local normalized = rawMessage:gsub("\r\n", "\n"):gsub("\r", "\n")
    if normalized:sub(1, 5) == "data:" then
        payload = normalized:sub(6):gsub("^%s+", ""):gsub("%s+$", "")
    end
    if payload == "" then return end

    local ok, decoded = pcall(function() return HttpService:JSONDecode(payload) end)
    if not ok or type(decoded) ~= "table" then return end

    local kind = decoded.kind

    -- ── heartbeat ────────────────────────────────────────────────────
    if kind == "heartbeat" then
        -- Server masih hidup, tidak perlu tindakan khusus
        return
    end

    -- ── status ───────────────────────────────────────────────────────
    if kind == "status" then
        local newMcpActive = decoded.mcpConnected == true
        if newMcpActive ~= mcpAgentActive then
            mcpAgentActive = newMcpActive
            if ui then
                if mcpAgentActive then
                    ui:setStatus("connected")
                    ui:addLog("[System] IDE Agent (Antigravity/Cursor) terhubung ke MCP.", Color3.fromRGB(100, 255, 100))
                else
                    ui:setStatus("waiting")
                    ui:addLog("[System] IDE Agent terputus dari MCP.", Color3.fromRGB(255, 200, 100))
                end
            end
        end
        return
    end

    -- ── request (task dari AI agent) ─────────────────────────────────
    if kind == "request" then
        local taskId  = decoded.requestId
        local command = decoded.command
        local target  = decoded.target
        local data    = decoded.data

        if not taskId or not command then return end

        -- Proses task di coroutine terpisah agar tidak memblokir stream
        task.spawn(function()
            local resultData = processTask({
                id      = taskId,
                command = command,
                target  = target or "",
                data    = data,
            })
            if resultData then
                sendResponse(taskId, resultData)
            end
        end)
        return
    end
end

-- ── Tutup SSE stream yang aktif ───────────────────────────────────────────────
function disconnectSSE()
    isConnected = false
    for _, conn in ipairs(streamConnections) do
        pcall(function() conn:Disconnect() end)
    end
    streamConnections = {}
    if currentStream then
        pcall(function() currentStream:Close() end)
        currentStream = nil
    end
end

-- ── Buka SSE stream baru ──────────────────────────────────────────────────────
function connectSSE()
    if isConnected then return end
    disconnectSSE() -- Bersihkan sisa koneksi lama

    local url = STREAM_URL .. "?studioId=" .. HttpService:UrlEncode(STUDIO_ID)

    local ok, streamOrErr = pcall(function()
        return HttpService:GetAsync(url, false) -- Gunakan non-cached request
    end)

    -- WebStreamClient hanya tersedia di Studio; GetAsync biasa tidak akan
    -- mempertahankan koneksi. Kita butuh WebStreamClient khusus.
    -- Coba via WebStreamClient API:
    local streamOk, stream = pcall(function()
        -- @ts-ignore – WebStreamClient mungkin belum ada di semua versi Studio
        return (HttpService :: any):WebStream(url)
    end)

    if not streamOk or not stream then
        -- Fallback: Studio tidak mendukung WebStreamClient → gunakan polling biasa
        if ui then
            ui:addLog("[System] WebStreamClient tidak tersedia. Menggunakan polling fallback.", Color3.fromRGB(255, 200, 100))
        end
        task.spawn(fallbackPolling)
        return
    end

    currentStream = stream
    isConnected   = true
    reconnectDelay = RECONNECT_DELAY_INITIAL

    if ui then
        ui:setStatus("waiting") -- Menunggu status mcpConnected dari server
        ui:addLog("[System] SSE stream terbuka. Menunggu IDE Agent...", Color3.fromRGB(100, 200, 255))
    end

    -- Event: pesan masuk dari SSE stream
    local onMessage = stream.OnMessage:Connect(function(message)
        handleSSEMessage(message)
    end)
    table.insert(streamConnections, onMessage)

    -- Event: stream ditutup (server restart / network drop)
    local onClose = stream.OnClose:Connect(function()
        isConnected    = false
        mcpAgentActive = false
        currentStream  = nil
        streamConnections = {}
        if ui then
            ui:setStatus("waiting")
            ui:addLog("[System] SSE stream terputus. Reconnect dalam " .. reconnectDelay .. "s...", Color3.fromRGB(255, 200, 100))
        end
        if not isManualDisconnect then
            task.delay(reconnectDelay, connectSSE)
            reconnectDelay = math.min(reconnectDelay * 2, RECONNECT_DELAY_MAX)
        end
    end)
    table.insert(streamConnections, onClose)
end

-- ── Fallback: HTTP Polling (jika WebStreamClient tidak tersedia) ──────────────
-- Digunakan pada versi Studio lama yang belum mendukung WebStreamClient.
local isPollingActive = false
function fallbackPolling()
    if isPollingActive then return end
    isPollingActive = true
    isConnected     = true

    if ui then
        ui:setStatus("waiting")
        ui:addLog("[System] Mode Polling aktif (WebStreamClient tidak didukung).", Color3.fromRGB(200, 200, 100))
    end

    while isConnected and not isManualDisconnect do
        -- Ping
        local pingOk, _ = pcall(function()
            return HttpService:GetAsync(PING_URL .. "?studioId=" .. STUDIO_ID .. "&t=" .. tostring(os.clock()))
        end)

        if pingOk then
            if ui then ui:setStatus("connected") end

            -- Long-poll tasks
            local taskOk, taskResponse = pcall(function()
                return HttpService:GetAsync(BASE_URL .. "/api/tasks?t=" .. tostring(os.clock()))
            end)

            if taskOk and taskResponse then
                local decodeOk, taskData = pcall(function() return HttpService:JSONDecode(taskResponse) end)
                if decodeOk and taskData and taskData.id then
                    local resultData = processTask(taskData)
                    if resultData then
                        sendResponse(taskData.id, resultData)
                    end
                end
            end
            task.wait(0.1)
        else
            if ui then ui:setStatus("waiting") end
            task.wait(1.5)
        end
    end

    isPollingActive = false
end

-- ── Plugin Unloading ──────────────────────────────────────────────────────────
plugin.Unloading:Connect(function()
    isManualDisconnect = true
    disconnectSSE()
end)

-- ══════════════════════════════════════════════════════════════════════
-- STARTUP: Langsung buka SSE stream
-- ══════════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(0.5) -- Tunggu UI siap

    if ui then
        ui:addLog("[System] NVStudio MCP v2.1.0 termuat. Membuka SSE stream...", Color3.fromRGB(200, 200, 200))
    end

    connectSSE()
end)
