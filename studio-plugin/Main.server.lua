-- ══════════════════════════════════════════════════════════════════════
-- NVStudio MCP Plugin v2.1.0
-- Arsitektur: SSE via Long-Poll (Roblox tidak punya native SSE client)
-- Plugin auto-connect saat dimuat, polling /api/ping lalu /api/stream
-- untuk mendapatkan events (status, request) dari server Node.js.
-- ══════════════════════════════════════════════════════════════════════

local HttpService    = game:GetService("HttpService")
local LogService     = game:GetService("LogService")

-- URL Endpoints
local BASE_URL       = "http://localhost:3055"
local STREAM_URL     = BASE_URL .. "/api/stream"      -- SSE long-poll (blocking GET)
local RESPONSE_URL   = BASE_URL .. "/api/response"
local PING_URL       = BASE_URL .. "/api/ping"

-- ID unik per sesi Studio
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
local MAX_LOGS           = 50
local isRunning          = false  -- apakah loop aktif
local isManualDisconnect = false
local isClickDebounce    = false
local mcpAgentActive     = false  -- apakah Antigravity sedang konek ke MCP
local serverReachable    = false  -- apakah server Node.js reachable

-- Reconnect config
local RECONNECT_DELAY_INITIAL = 1
local RECONNECT_DELAY_MAX     = 15
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

		if not isRunning then
			isManualDisconnect = false
			reconnectDelay = RECONNECT_DELAY_INITIAL
			ui:setStatus("waiting")
			ui:addLog("[System] Menghubungkan ulang ke Server MCP...", Color3.fromRGB(255, 220, 100))
			task.spawn(startConnectionLoop)
		else
			isManualDisconnect = true
			isRunning = false
			serverReachable = false
			mcpAgentActive = false
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

-- ── Update UI berdasarkan state ───────────────────────────────────────────────
local function updateUIStatus()
	if not ui then return end
	if not serverReachable then
		ui:setStatus("waiting")
	elseif mcpAgentActive then
		ui:setStatus("connected")
	else
		-- Server reachable tapi tidak ada AI agent
		-- Tampilkan sebagai connected (karena server sse bridge aktif)
		ui:setStatus("server_connected")
	end
end

-- ── Proses satu event dari SSE stream ────────────────────────────────────────
local function handleSSELine(line)
	-- Format SSE: "data: {...json...}"
	local payload = line
	if line:sub(1, 5) == "data:" then
		payload = line:sub(6):gsub("^%s+", ""):gsub("%s+$", "")
	end
	if payload == "" then return end

	local ok, decoded = pcall(function() return HttpService:JSONDecode(payload) end)
	if not ok or type(decoded) ~= "table" then return end

	local kind = decoded.kind

	-- heartbeat: server masih hidup
	if kind == "heartbeat" then
		return
	end

	-- status: update mcpConnected
	if kind == "status" then
		local newActive = decoded.mcpConnected == true
		if newActive ~= mcpAgentActive then
			mcpAgentActive = newActive
			if ui then
				if mcpAgentActive then
					ui:setStatus("connected")
					ui:addLog("[System] ✅ IDE Agent (Antigravity) terhubung ke MCP.", Color3.fromRGB(100, 255, 100))
				else
					ui:setStatus("waiting")
					ui:addLog("[System] IDE Agent terputus dari MCP. Menunggu...", Color3.fromRGB(255, 200, 100))
				end
			end
		end
		return
	end

	-- request: ada task dari AI agent
	if kind == "request" then
		local taskId  = decoded.requestId
		local command = decoded.command
		local target  = decoded.target
		local data    = decoded.data

		if not taskId or not command then return end

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

-- ── Loop Utama: Ping → Stream → Parse SSE lines ───────────────────────────────
-- Roblox HttpService:GetAsync() tidak mendukung streaming, jadi kita
-- menggunakan strategi: GET /api/stream dengan waktu hold singkat (5 detik).
-- Server mengirim semua events yang tertunda lalu tutup koneksi.
-- Plugin reconnect langsung untuk sesi berikutnya.
function startConnectionLoop()
	if isRunning then return end
	isRunning = true
	reconnectDelay = RECONNECT_DELAY_INITIAL

	if ui then
		ui:addLog("[System] NVStudio MCP v2.1.0 — Menghubungkan ke server...", Color3.fromRGB(200, 200, 200))
	end

	while isRunning and not isManualDisconnect do
		-- Langkah 1: Ping untuk cek apakah server hidup
		local pingOk, pingRaw = pcall(function()
			return HttpService:GetAsync(
				PING_URL .. "?studioId=" .. HttpService:UrlEncode(STUDIO_ID) .. "&t=" .. tostring(os.clock()),
				false
			)
		end)

		if not pingOk then
			-- Server tidak reachable
			if serverReachable then
				serverReachable = false
				mcpAgentActive  = false
				if ui then
					ui:setStatus("waiting")
					ui:addLog("[System] ⚠️ Server MCP tidak dapat dijangkau. Retry dalam " .. reconnectDelay .. "s...", Color3.fromRGB(255, 150, 50))
				end
			end
			task.wait(reconnectDelay)
			reconnectDelay = math.min(reconnectDelay * 2, RECONNECT_DELAY_MAX)
		else
			-- Server reachable → parse ping response
			reconnectDelay = RECONNECT_DELAY_INITIAL

			local pingData = nil
			pcall(function()
				pingData = HttpService:JSONDecode(pingRaw)
			end)

			local wasReachable = serverReachable
			serverReachable = true

			if not wasReachable and ui then
				ui:addLog("[System] ✅ Server MCP terhubung. Membuka event stream...", Color3.fromRGB(100, 255, 150))
			end

			-- Update mcpConnected dari ping response
			if pingData then
				local newActive = pingData.mcpConnected == true
				if newActive ~= mcpAgentActive then
					mcpAgentActive = newActive
					if ui then
						if mcpAgentActive then
							ui:setStatus("connected")
							ui:addLog("[System] ✅ IDE Agent (Antigravity) terhubung ke MCP.", Color3.fromRGB(100, 255, 100))
						else
							ui:setStatus("server_connected")
							-- No need to explicitly add log for IDE Agent wait every time it connects, 
							-- bridge connected log is enough.
						end
					end
				elseif serverReachable and not mcpAgentActive then
					-- Tidak ada perubahan tapi pastikan status benar
					if ui then ui:setStatus("server_connected") end
				end
			end

			-- Langkah 2: Buka SSE stream (blocking hingga server menutup koneksi / ~10 detik)
			-- Server akan mengirim events yang tertunda, heartbeat, lalu tutup.
			if isRunning and not isManualDisconnect then
				local streamOk, streamRaw = pcall(function()
					return HttpService:GetAsync(
						STREAM_URL .. "?studioId=" .. HttpService:UrlEncode(STUDIO_ID),
						false
					)
				end)

				if streamOk and streamRaw and streamRaw ~= "" then
					-- Parse baris-baris SSE dari response
					for line in (streamRaw .. "\n"):gmatch("([^\n]*)\n") do
						line = line:gsub("\r", "")
						if line ~= "" then
							handleSSELine(line)
						end
					end
				end
			end

			-- Jeda singkat sebelum cycle berikutnya
			task.wait(0.5)
		end
	end

	isRunning = false
	serverReachable = false
	mcpAgentActive  = false
	if ui then ui:setStatus("disconnected") end
end

-- ── Plugin Unloading ──────────────────────────────────────────────────────────
plugin.Unloading:Connect(function()
	isManualDisconnect = true
	isRunning = false
end)

-- ══════════════════════════════════════════════════════════════════════
-- STARTUP: Langsung mulai connection loop
-- ══════════════════════════════════════════════════════════════════════
task.spawn(function()
	task.wait(0.5) -- Tunggu UI siap
	startConnectionLoop()
end)
