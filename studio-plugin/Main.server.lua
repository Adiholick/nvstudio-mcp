-- ══════════════════════════════════════════════════════════════════════
-- NVStudio MCP Plugin v2.4.0
-- Arsitektur: Dual-Mode WebSocket Duplex (Port 3055/ws) + Fallback Long-Polling
-- Plugin auto-connect saat dimuat via WebSocket native, dengan fallback otomatis
-- ke HTTP stream jika WebSocket tidak tersedia di environment Roblox Studio ini.
-- ══════════════════════════════════════════════════════════════════════

local HttpService    = game:GetService("HttpService")
local LogService     = game:GetService("LogService")

-- URL Endpoints
local BASE_URL       = "http://localhost:3055"
local STREAM_URL     = BASE_URL .. "/api/stream"      -- SSE long-poll (blocking GET)
local RESPONSE_URL   = BASE_URL .. "/api/response"
local PING_URL       = BASE_URL .. "/api/ping"
local WS_URL         = "ws://localhost:3055/ws"
local WS_URL_IP      = "ws://127.0.0.1:3055/ws"

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
	getInstanceFromPath = nil -- akan di-bind di bawah
}
local MAX_LOGS           = 50
local isRunning          = false  -- apakah loop/koneksi aktif
local isManualDisconnect = false
local isClickDebounce    = false
local mcpAgentActive     = false  -- apakah Antigravity sedang konek ke MCP
local serverReachable    = false  -- apakah server Node.js reachable
local activeWsWrapper    = nil
local currentTransport   = "none" -- "websocket" | "longpoll" | "none"

-- Reconnect config untuk Long-Polling
local RECONNECT_DELAY_INITIAL = 1.5
local RECONNECT_DELAY_MAX     = 1.5
local reconnectDelay          = RECONNECT_DELAY_INITIAL
local currentLoopId           = nil

-- Task deduplication state (Bug G)
local runningTasks   = {} -- taskId -> true
local completedTasks = {} -- taskId -> os.clock()

local function shouldProcessTask(taskId)
	if not taskId or taskId == "" then return false end
	if runningTasks[taskId] then
		return false
	end
	local completedAt = completedTasks[taskId]
	if completedAt and (os.clock() - completedAt < 60) then
		return false
	end
	runningTasks[taskId] = true
	return true
end

local function markTaskDone(taskId)
	if not taskId then return end
	runningTasks[taskId] = nil
	completedTasks[taskId] = os.clock()

	-- Bersihkan entri kedaluwarsa (>60 detik)
	local now = os.clock()
	for id, t in pairs(completedTasks) do
		if now - t > 60 then
			completedTasks[id] = nil
		end
	end
end

-- Forward declaration
local startConnectionManager = nil
local startLongPollingLoop   = nil

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
			task.spawn(startConnectionManager)
		else
			isManualDisconnect = true
			isRunning = false
			serverReachable = false
			mcpAgentActive = false
			if activeWsWrapper then
				activeWsWrapper:Close()
				activeWsWrapper = nil
			end
			currentTransport = "none"
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
	if type(pathString) ~= "string" or pathString == "" then return nil end
	local parts   = string.split(pathString, ".")
	if #parts == 0 then return nil end
	local current = game
	if parts[1] == "game" then table.remove(parts, 1) end
	pcall(function()
		local svc = game:GetService(parts[1])
		if svc then current = svc; table.remove(parts, 1) end
	end)
	local i = 1
	while i <= #parts do
		local part = parts[i]
		local found = current:FindFirstChild(part)
		
		-- Jika tidak ketemu, coba gabungkan dengan part berikutnya (untuk nama yang mengandung titik)
		local combinedPart = part
		local lookAhead = i + 1
		while not found and lookAhead <= #parts do
			combinedPart = combinedPart .. "." .. parts[lookAhead]
			found = current:FindFirstChild(combinedPart)
			if found then
				i = lookAhead
			end
			lookAhead = lookAhead + 1
		end
		
		if not found then return nil end
		current = found
		i = i + 1
	end
	return current
end

ctx.getInstanceFromPath = getInstanceFromPath

-- ── Proses Task dari Server ───────────────────────────────────────────────────
local function processTask(taskData)
	if not taskData or not taskData.id or not taskData.command then return nil end

	if ui then
		ui:addLog("[AI Command] " .. taskData.command, Color3.fromRGB(150, 200, 255))
	end

	local targetInstance = getInstanceFromPath(taskData.target)
	if not targetInstance then
		if taskData.target == "" or taskData.target == "nil" then
			targetInstance = game
		else
			return { id = taskData.id, status = "error", error = "Target path tidak ditemukan: " .. tostring(taskData.target) }
		end
	end

	local skillFunc = skills[taskData.command]
	if not skillFunc then
		return { id = taskData.id, status = "error", error = "Command tidak dikenali: " .. taskData.command }
	end

	local ok, result = pcall(function()
		return skillFunc(targetInstance, taskData.data, ctx, taskData.target)
	end)
	
	if not ok then
		result = { status = "error", error = "Internal Plugin Error: " .. tostring(result) }
	end
	
	result = result or { status = "success", result = "Eksekusi selesai (Tidak ada return value)" }
	result.id = taskData.id

	if ui then
		local color = result.status == "success" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
		ui:addLog("[AI Result] " .. tostring(result.result or result.error), color)
	end

	return result
end

-- ── Helper: Sanitize result sebelum JSONEncode (Bug H) ─────────────────────────
local function sanitizeForJson(val, depth)
	depth = depth or 0
	if depth > 5 then return tostring(val) end
	local t = typeof(val)
	if t == "string" or t == "number" or t == "boolean" then
		return val
	elseif t == "Instance" then
		return val:GetFullName()
	elseif t == "Vector3" then
		return { X = val.X, Y = val.Y, Z = val.Z }
	elseif t == "CFrame" then
		return { Position = { X = val.Position.X, Y = val.Position.Y, Z = val.Position.Z } }
	elseif t == "Color3" then
		return { R = val.R, G = val.G, B = val.B }
	elseif t == "table" then
		local sanitized = {}
		for k, v in pairs(val) do
			sanitized[tostring(k)] = sanitizeForJson(v, depth + 1)
		end
		return sanitized
	else
		return tostring(val)
	end
end

-- ── Kirim Respons ke Server (HTTP Fallback) (Bug H) ───────────────────────────
local function sendResponse(taskId, resultData, attempt)
	task.spawn(function()
		local payload = {
			id      = taskId,
			taskId  = taskId,
			attempt = attempt,
			status  = resultData.status or "success",
			result  = sanitizeForJson(resultData.result),
			error   = resultData.error and tostring(resultData.error) or nil,
		}

		local encOk, json = pcall(function()
			return HttpService:JSONEncode(payload)
		end)

		if not encOk then
			payload.result = tostring(payload.result)
			pcall(function() json = HttpService:JSONEncode(payload) end)
		end

		if not json then
			json = string.format('{"id":"%s","taskId":"%s","status":"error","error":"Gagal encode payload JSON"}', taskId, taskId)
		end

		local postOk = pcall(function()
			HttpService:PostAsync(
				RESPONSE_URL .. "/" .. taskId,
				json,
				Enum.HttpContentType.ApplicationJson
			)
		end)

		if not postOk then
			-- Backoff sejenak sebelum fallback ke endpoint legacy (Bug H)
			task.wait(0.2)
			local fallbackOk = pcall(function()
				HttpService:PostAsync(RESPONSE_URL, json, Enum.HttpContentType.ApplicationJson)
			end)
			if not fallbackOk and ui then
				ui:addLog("[System] Gagal kirim response HTTP ke server: " .. tostring(taskId), Color3.fromRGB(255, 100, 100))
			end
		end
	end)
end

-- ── WebSocket API Abstraction ────────────────────────────────────────────────
local function detectWebSocketCapability()
	-- 1. Check HttpService:CreateWebStreamClient (Roblox Studio native API)
	local hasWebStream = false
	pcall(function()
		hasWebStream = (typeof(HttpService.CreateWebStreamClient) == "function")
			and (Enum.WebStreamClientType and Enum.WebStreamClientType.WebSocket ~= nil)
	end)
	if hasWebStream then
		return "WebStreamClient"
	end

	-- 2. Check global WebSocket API jika tersedia
	local wsGlobal = rawget(_G, "WebSocket") or rawget(_G, "websocket")
	if not wsGlobal then
		pcall(function() wsGlobal = WebSocket end)
	end
	if wsGlobal and typeof(wsGlobal.connect) == "function" then
		return "WebSocketGlobal"
	end

	return nil
end

local function createWsClient(url)
	local cap = detectWebSocketCapability()
	if not cap then
		return nil, "WebSocket API not available"
	end

	if cap == "WebStreamClient" then
		local ok, client = pcall(function()
			return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, {
				Url = url
			})
		end)
		if not ok or not client then
			return nil, tostring(client or "CreateWebStreamClient failed")
		end

		local wrapper = {
			raw = client,
			cap = "WebStreamClient",
			closed = false,
			connections = {},
		}

		function wrapper:Send(data)
			if self.closed then return false, "Closed" end
			return pcall(function()
				self.raw:Send(data)
			end)
		end

		function wrapper:Close()
			if self.closed then return end
			self.closed = true
			pcall(function() self.raw:Close() end)
			for _, conn in ipairs(self.connections) do
				pcall(function() conn:Disconnect() end)
			end
			table.clear(self.connections)
		end

		function wrapper:BindEvents(onMessage, onClose)
			if self.raw.MessageReceived and typeof(self.raw.MessageReceived.Connect) == "function" then
				local ok, conn = pcall(function()
					return self.raw.MessageReceived:Connect(onMessage)
				end)
				if ok and conn then table.insert(self.connections, conn) end
			end

			if self.raw.Closed and typeof(self.raw.Closed.Connect) == "function" then
				local ok, conn = pcall(function()
					return self.raw.Closed:Connect(onClose)
				end)
				if ok and conn then table.insert(self.connections, conn) end
			end
		end

		return wrapper, nil

	elseif cap == "WebSocketGlobal" then
		local wsGlobal = rawget(_G, "WebSocket") or rawget(_G, "websocket") or WebSocket
		local ok, client = pcall(function()
			return wsGlobal.connect(url)
		end)
		if not ok or not client then
			return nil, tostring(client or "WebSocket.connect failed")
		end

		local wrapper = {
			raw = client,
			cap = "WebSocketGlobal",
			closed = false,
			connections = {},
		}

		function wrapper:Send(data)
			if self.closed then return false, "Closed" end
			return pcall(function()
				if typeof(self.raw.Send) == "function" then
					self.raw:Send(data)
				elseif typeof(self.raw.send) == "function" then
					self.raw:send(data)
				end
			end)
		end

		function wrapper:Close()
			if self.closed then return end
			self.closed = true
			pcall(function()
				if typeof(self.raw.Close) == "function" then
					self.raw:Close()
				elseif typeof(self.raw.close) == "function" then
					self.raw:close()
				end
			end)
			for _, conn in ipairs(self.connections) do
				pcall(function() conn:Disconnect() end)
			end
			table.clear(self.connections)
		end

		function wrapper:BindEvents(onMessage, onClose)
			if self.raw.MessageReceived and typeof(self.raw.MessageReceived.Connect) == "function" then
				local ok, conn = pcall(function() return self.raw.MessageReceived:Connect(onMessage) end)
				if ok and conn then table.insert(self.connections, conn) end
			elseif self.raw.OnMessage then
				if typeof(self.raw.OnMessage) == "RBXScriptSignal" or (typeof(self.raw.OnMessage) == "userdata" and self.raw.OnMessage.Connect) then
					local ok, conn = pcall(function() return self.raw.OnMessage:Connect(onMessage) end)
					if ok and conn then table.insert(self.connections, conn) end
				else
					pcall(function() self.raw.OnMessage = onMessage end)
				end
			end

			if self.raw.Closed and typeof(self.raw.Closed.Connect) == "function" then
				local ok, conn = pcall(function() return self.raw.Closed:Connect(onClose) end)
				if ok and conn then table.insert(self.connections, conn) end
			elseif self.raw.OnClose then
				if typeof(self.raw.OnClose) == "RBXScriptSignal" or (typeof(self.raw.OnClose) == "userdata" and self.raw.OnClose.Connect) then
					local ok, conn = pcall(function() return self.raw.OnClose:Connect(onClose) end)
					if ok and conn then table.insert(self.connections, conn) end
				else
					pcall(function() self.raw.OnClose = onClose end)
				end
			end
		end

		return wrapper, nil
	end

	return nil, "Unsupported"
end

-- ── WebSocket Message Dispatcher ─────────────────────────────────────────────
local function handleWsMessage(wrapper, rawMessage)
	if type(rawMessage) ~= "string" or rawMessage == "" then return end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(rawMessage) end)
	if not ok or type(decoded) ~= "table" then return end

	local kind = decoded.kind

	-- Heartbeat ping -> balas pong
	if kind == "ping" then
		pcall(function()
			wrapper:Send(HttpService:JSONEncode({ kind = "pong", ts = os.time() }))
		end)
		return
	end

	if kind == "pong" then
		return
	end

	-- Update status koneksi MCP / Studio
	if kind == "status" then
		local newActive = decoded.mcpConnected == true
		local changed = (mcpAgentActive ~= newActive)
		mcpAgentActive = newActive
		if ui then
			if mcpAgentActive then
				ui:setStatus("connected")
			else
				ui:setStatus("server_connected")
			end
			if newActive and changed then
				ui:addLog("[System] ✅ IDE Agent (Antigravity) aktif ⚡", Color3.fromRGB(100, 255, 100))
			elseif not newActive and changed then
				ui:addLog("[System] ⚠️ IDE Agent terputus.", Color3.fromRGB(255, 150, 50))
			end
		end
		return
	end

	-- Eksekusi perintah AI
	if kind == "request" then
		local taskId  = decoded.taskId or decoded.requestId
		local attempt = decoded.attempt
		local command = decoded.command
		local target  = decoded.target
		local data    = decoded.data

		if not taskId or not command then return end
		if not shouldProcessTask(taskId) then return end -- Bug G: Dedup!

		task.spawn(function()
			local resultData = processTask({
				id      = taskId,
				command = command,
				target  = target or "",
				data    = data,
			})
			markTaskDone(taskId) -- Bug G: Tandai selesai
			if resultData then
				-- Push respons instan kembali via WebSocket (Zero-Delay)
				local responseEnvelope = {
					kind    = "response",
					taskId  = taskId,
					id      = taskId,
					attempt = attempt,
					status  = resultData.status,
					result  = sanitizeForJson(resultData.result),
					error   = resultData.error and tostring(resultData.error) or nil,
				}
				local encOk, encoded = pcall(function()
					return HttpService:JSONEncode(responseEnvelope)
				end)
				local sent = false
				if encOk then
					local sendOk, _ = wrapper:Send(encoded)
					sent = (sendOk == true)
				end
				if not sent then
					-- Jika serialisasi atau pengiriman via WS gagal, fallback ke HTTP POST
					sendResponse(taskId, resultData, attempt)
				end
			end
		end)
		return
	end
end

-- ── Proses satu event dari SSE stream (Long-Polling fallback) ────────────────
local function handleSSELine(line)
	local payload = line
	if line:sub(1, 6) == "event:" then return end
	if line:sub(1, 5) == "data:" then
		payload = line:sub(6):gsub("^%s+", ""):gsub("%s+$", "")
	end
	if payload == "" then return end

	local ok, decoded = pcall(function() return HttpService:JSONDecode(payload) end)
	if not ok or type(decoded) ~= "table" then return end

	local kind = decoded.kind

	if kind == "heartbeat" then
		return
	end

	if kind == "status" then
		local newActive = decoded.mcpConnected == true
		local changed = (mcpAgentActive ~= newActive)
		mcpAgentActive = newActive
		if ui then
			if mcpAgentActive then
				ui:setStatus("connected")
			else
				ui:setStatus("server_connected")
			end
			
			if newActive and changed then
				ui:addLog("[System] ✅ IDE Agent (Antigravity) aktif.", Color3.fromRGB(100, 255, 100))
			elseif not newActive and changed then
				ui:addLog("[System] ⚠️ IDE Agent terputus.", Color3.fromRGB(255, 150, 50))
			end
		end
		return
	end

	if kind == "request" then
		local taskId  = decoded.requestId or decoded.taskId
		local attempt = decoded.attempt
		local command = decoded.command
		local target  = decoded.target
		local data    = decoded.data

		if not taskId or not command then return end
		if not shouldProcessTask(taskId) then return end -- Bug G: Dedup!

		task.spawn(function()
			local resultData = processTask({
				id      = taskId,
				command = command,
				target  = target or "",
				data    = data,
			})
			markTaskDone(taskId) -- Bug G: Tandai selesai
			if resultData then
				sendResponse(taskId, resultData, attempt)
			end
		end)
		return
	end
end

-- ── Fallback Loop: Long-Polling (/api/stream) ─────────────────────────────────
function startLongPollingLoop()
	if not isRunning or isManualDisconnect then return end
	currentTransport = "longpoll"
	reconnectDelay = RECONNECT_DELAY_INITIAL

	local loopId = HttpService:GenerateGUID(false)
	currentLoopId = loopId

	if ui then
		ui:addLog("[System] Mode Long-Polling aktif (Port 3055)...", Color3.fromRGB(200, 200, 200))
	end

	local consecutiveErrors = 0

	while isRunning and not isManualDisconnect and currentLoopId == loopId and currentTransport == "longpoll" do
		local streamOk, streamRaw = pcall(function()
			return HttpService:GetAsync(
				STREAM_URL .. "?studioId=" .. HttpService:UrlEncode(STUDIO_ID) .. "&placeId=" .. tostring(game.PlaceId),
				false
			)
		end)

		if streamOk and streamRaw and streamRaw ~= "" then
			consecutiveErrors = 0
			reconnectDelay = RECONNECT_DELAY_INITIAL

			if not serverReachable then
				serverReachable = true
				if ui then
					ui:setStatus(mcpAgentActive and "connected" or "server_connected")
					ui:addLog("[System] ✅ Server MCP terhubung via Long-Polling.", Color3.fromRGB(100, 255, 150))
				end
			end

			for line in (streamRaw .. "\n"):gmatch("([^\n]*)\n") do
				line = line:gsub("\r", "")
				if line ~= "" then
					handleSSELine(line)
				end
			end
			task.wait()
		else
			consecutiveErrors = consecutiveErrors + 1
			if consecutiveErrors >= 2 then
				if serverReachable then
					serverReachable = false
					mcpAgentActive = false
					if ui then
						ui:setStatus("waiting")
						ui:addLog("[System] ⚠️ Server MCP tidak dapat dijangkau. Menghubungkan ulang...", Color3.fromRGB(255, 150, 50))
					end
				end
			end

			task.wait(reconnectDelay)
			reconnectDelay = RECONNECT_DELAY_MAX
		end
	end

	if currentTransport == "longpoll" and (not isRunning or isManualDisconnect) then
		isRunning = false
		serverReachable = false
		mcpAgentActive  = false
		if ui then ui:setStatus("disconnected") end
	end
end

-- ── Connection Manager: WebSocket Utama + Fallback Long-Polling ──────────────
function startConnectionManager()
	if isRunning then return end
	isRunning = true
	isManualDisconnect = false

	local cap = detectWebSocketCapability()
	if cap then
		task.spawn(function()
			local wsFailures = 0
			local backoff = 0.5

			while isRunning and not isManualDisconnect and wsFailures < 3 do
				currentTransport = "websocket"
				if ui then
					ui:setStatus("waiting")
					ui:addLog("[System] Menghubungkan via WebSocket (Port 3055)...", Color3.fromRGB(200, 200, 255))
				end

				local wrapper, err = createWsClient(WS_URL)
				if not wrapper then
					-- Coba fallback ke IP 127.0.0.1
					wrapper, err = createWsClient(WS_URL_IP)
				end

				if wrapper then
					activeWsWrapper = wrapper
					serverReachable = true
					if ui then
						ui:setStatus(mcpAgentActive and "connected" or "server_connected")
						ui:addLog("[System] ⚡ WebSocket Terhubung! (Ultra Low-Latency <1ms)", Color3.fromRGB(100, 255, 150))
					end

					-- Kirim pesan registrasi awal
					local regOk = wrapper:Send(HttpService:JSONEncode({
						kind = "register",
						studioId = STUDIO_ID,
						placeId = game.PlaceId,
						pluginsVersion = 2,
					}))

					if regOk then
						wsFailures = 0
						backoff = 0.5

						local closedSignal = Instance.new("BindableEvent")
						wrapper:BindEvents(
							function(msg)
								handleWsMessage(wrapper, msg)
							end,
							function()
								closedSignal:Fire()
							end
						)

						closedSignal.Event:Wait()
						closedSignal:Destroy()
					end

					if activeWsWrapper == wrapper then
						activeWsWrapper = nil
					end
					wrapper:Close()
				end

				if isManualDisconnect or not isRunning then break end

				wsFailures = wsFailures + 1
				if wsFailures < 3 then
					if ui then
						ui:setStatus("waiting")
						ui:addLog("[System] ⚠️ WebSocket terputus. Reconnect dalam " .. string.format("%.1f", backoff) .. "s...", Color3.fromRGB(255, 180, 50))
					end
					task.wait(backoff)
					backoff = math.min(backoff * 2, 5.0)
				end
			end

			-- Jika WS gagal 3x berturut-turut dan plugin masih aktif -> Beralih ke Long-Polling!
			if isRunning and not isManualDisconnect then
				if ui then
					ui:addLog("[System] ℹ️ Mengalihkan ke Mode Fallback Long-Polling...", Color3.fromRGB(255, 200, 100))
				end
				startLongPollingLoop()
			end
		end)
	else
		-- WebSocket tidak didukung di environment Studio ini -> langsung Long-Polling
		if ui then
			ui:addLog("[System] ℹ️ WebSocket tidak terdeteksi. Menggunakan Long-Polling.", Color3.fromRGB(200, 200, 200))
		end
		startLongPollingLoop()
	end
end

-- ── Plugin Unloading ──────────────────────────────────────────────────────────
plugin.Unloading:Connect(function()
	isManualDisconnect = true
	isRunning = false
	if activeWsWrapper then
		activeWsWrapper:Close()
		activeWsWrapper = nil
	end
end)

-- ══════════════════════════════════════════════════════════════════════
-- STARTUP: Langsung mulai connection manager
-- ══════════════════════════════════════════════════════════════════════
task.spawn(function()
	task.wait(0.5) -- Tunggu UI siap
	startConnectionManager()
end)
