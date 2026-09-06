local UIManager = {}
local widget = nil

function UIManager.init(pluginInstance, studioId)
    -- Membuat Widget Panel yang bisa di-dock (menempel)
    local widgetInfo = DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Right,
        true,   -- Initially visible on first install so user immediately sees the dashboard
        false,  -- Don't override user's saved state on subsequent launches
        380,    -- Default width
        520,    -- Default height
        280,    -- Min width
        320     -- Min height
    )
    
    widget = pluginInstance:CreateDockWidgetPluginGui("NVStudioMCP_GUI_V3", widgetInfo)
    widget.Title = "NVStudio MCP Dashboard"
    
    -- ═══════════════════════════════════════════
    -- ROOT FRAME (Non-scrolling, fills entire widget)
    -- ═══════════════════════════════════════════
    local rootFrame = Instance.new("Frame")
    rootFrame.Size = UDim2.new(1, 0, 1, 0)
    rootFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    rootFrame.BorderSizePixel = 0
    rootFrame.Parent = widget

    local rootPadding = Instance.new("UIPadding")
    rootPadding.PaddingTop = UDim.new(0, 8)
    rootPadding.PaddingLeft = UDim.new(0, 10)
    rootPadding.PaddingRight = UDim.new(0, 10)
    rootPadding.PaddingBottom = UDim.new(0, 8)
    rootPadding.Parent = rootFrame

    local rootLayout = Instance.new("UIListLayout")
    rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rootLayout.Padding = UDim.new(0, 6)
    rootLayout.Parent = rootFrame

    -- ═══════════════════════════════════════════
    -- SECTION 1: HEADER CARD
    -- ═══════════════════════════════════════════
    local headerFrame = Instance.new("Frame")
    headerFrame.AutomaticSize = Enum.AutomaticSize.Y
    headerFrame.Size = UDim2.new(1, 0, 0, 0)
    headerFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    headerFrame.BorderSizePixel = 0
    headerFrame.LayoutOrder = 1
    headerFrame.Parent = rootFrame

    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 6)
    hCorner.Parent = headerFrame

    local hPadding = Instance.new("UIPadding")
    hPadding.PaddingTop = UDim.new(0, 10)
    hPadding.PaddingLeft = UDim.new(0, 12)
    hPadding.PaddingRight = UDim.new(0, 12)
    hPadding.PaddingBottom = UDim.new(0, 10)
    hPadding.Parent = headerFrame

    local hLayout = Instance.new("UIListLayout")
    hLayout.SortOrder = Enum.SortOrder.LayoutOrder
    hLayout.Padding = UDim.new(0, 2)
    hLayout.Parent = headerFrame

    -- Title Row (Name + Status side by side)
    local titleRow = Instance.new("Frame")
    titleRow.AutomaticSize = Enum.AutomaticSize.Y
    titleRow.Size = UDim2.new(1, 0, 0, 0)
    titleRow.BackgroundTransparency = 1
    titleRow.LayoutOrder = 1
    titleRow.Parent = headerFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "NVStudio MCP"
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 18
    titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(0.6, 0, 0, 22)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleRow

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "● Disconnected"
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(0.4, 0, 0, 22)
    statusLabel.Position = UDim2.new(0.6, 0, 0, 0)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    statusLabel.Parent = titleRow

    -- Version
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Text = "v2.1.3"
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.TextSize = 11
    versionLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Size = UDim2.new(1, 0, 0, 14)
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    versionLabel.LayoutOrder = 2
    versionLabel.Parent = headerFrame

    -- Thin separator
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, 0, 0, 1)
    sep1.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
    sep1.BorderSizePixel = 0
    sep1.LayoutOrder = 3
    sep1.Parent = headerFrame

    -- Place info
    local placeLabel = Instance.new("TextLabel")
    placeLabel.Text = "📁  " .. (game.Name ~= "" and game.Name or "Untitled Baseplate")
    placeLabel.Font = Enum.Font.Gotham
    placeLabel.TextSize = 11
    placeLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    placeLabel.BackgroundTransparency = 1
    placeLabel.Size = UDim2.new(1, 0, 0, 16)
    placeLabel.TextXAlignment = Enum.TextXAlignment.Left
    placeLabel.LayoutOrder = 4
    placeLabel.Parent = headerFrame

    -- Studio ID
    local idLabel = Instance.new("TextLabel")
    idLabel.Text = "🔗  " .. string.sub(tostring(studioId), 1, 18) .. "..."
    idLabel.Font = Enum.Font.Code
    idLabel.TextSize = 10
    idLabel.TextColor3 = Color3.fromRGB(90, 180, 230)
    idLabel.BackgroundTransparency = 1
    idLabel.Size = UDim2.new(1, 0, 0, 14)
    idLabel.TextXAlignment = Enum.TextXAlignment.Left
    idLabel.LayoutOrder = 5
    idLabel.Parent = headerFrame

    -- Server URL
    local serverLabel = Instance.new("TextLabel")
    serverLabel.Text = "🌐  localhost:3055"
    serverLabel.Font = Enum.Font.Code
    serverLabel.TextSize = 10
    serverLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
    serverLabel.BackgroundTransparency = 1
    serverLabel.Size = UDim2.new(1, 0, 0, 14)
    serverLabel.TextXAlignment = Enum.TextXAlignment.Left
    serverLabel.LayoutOrder = 6
    serverLabel.Parent = headerFrame

    -- ═══════════════════════════════════════════
    -- SECTION 2: CONTROLS ROW
    -- ═══════════════════════════════════════════
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Size = UDim2.new(1, 0, 0, 32)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.LayoutOrder = 2
    controlsFrame.Parent = rootFrame

    -- Connect / Disconnect Button
    local connectBtn = Instance.new("TextButton")
    connectBtn.Size = UDim2.new(0.52, -4, 1, 0)
    connectBtn.Position = UDim2.new(0, 0, 0, 0)
    connectBtn.Text = "  Connect"
    connectBtn.Font = Enum.Font.GothamBold
    connectBtn.TextSize = 13
    connectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    connectBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    connectBtn.BorderSizePixel = 0
    connectBtn.AutoButtonColor = false
    connectBtn.ZIndex = 2
    connectBtn.Parent = controlsFrame

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 5)
    cCorner.Parent = connectBtn

    -- Hover Effects for Connect Button (menggunakan stored base color, bukan text check)
    local _btnBaseColor = Color3.fromRGB(40, 160, 80)
    local _isHovering = false
    
    connectBtn.MouseEnter:Connect(function()
        _isHovering = true
        connectBtn.BackgroundColor3 = Color3.fromRGB(
            math.min(255, math.floor(_btnBaseColor.R * 255 + 25)),
            math.min(255, math.floor(_btnBaseColor.G * 255 + 25)),
            math.min(255, math.floor(_btnBaseColor.B * 255 + 25))
        )
    end)
    connectBtn.MouseLeave:Connect(function()
        _isHovering = false
        connectBtn.BackgroundColor3 = _btnBaseColor
    end)

    -- Auto-Connect Checkbox Container
    local autoConnectContainer = Instance.new("Frame")
    autoConnectContainer.Size = UDim2.new(0.48, -4, 1, 0)
    autoConnectContainer.Position = UDim2.new(0.52, 4, 0, 0)
    autoConnectContainer.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    autoConnectContainer.BorderSizePixel = 0
    autoConnectContainer.Parent = controlsFrame

    local acCorner = Instance.new("UICorner")
    acCorner.CornerRadius = UDim.new(0, 5)
    acCorner.Parent = autoConnectContainer

    -- Checkbox visual (outer box)
    local checkboxOuter = Instance.new("Frame")
    checkboxOuter.Size = UDim2.new(0, 16, 0, 16)
    checkboxOuter.Position = UDim2.new(0, 10, 0.5, -8)
    checkboxOuter.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    checkboxOuter.BorderSizePixel = 0
    checkboxOuter.Parent = autoConnectContainer

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 3)
    cbCorner.Parent = checkboxOuter

    local cbStroke = Instance.new("UIStroke")
    cbStroke.Color = Color3.fromRGB(80, 80, 95)
    cbStroke.Thickness = 1
    cbStroke.Parent = checkboxOuter

    -- Checkbox inner (check mark)
    local checkboxInner = Instance.new("Frame")
    checkboxInner.Size = UDim2.new(0, 10, 0, 10)
    checkboxInner.Position = UDim2.new(0.5, -5, 0.5, -5)
    checkboxInner.BackgroundColor3 = Color3.fromRGB(80, 170, 255)
    checkboxInner.Visible = false
    checkboxInner.Parent = checkboxOuter

    local cbiCorner = Instance.new("UICorner")
    cbiCorner.CornerRadius = UDim.new(0, 2)
    cbiCorner.Parent = checkboxInner

    -- Label
    local autoConnectLabel = Instance.new("TextLabel")
    autoConnectLabel.Text = "Auto-Connect"
    autoConnectLabel.Font = Enum.Font.Gotham
    autoConnectLabel.TextSize = 11
    autoConnectLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
    autoConnectLabel.BackgroundTransparency = 1
    autoConnectLabel.Position = UDim2.new(0, 32, 0, 0)
    autoConnectLabel.Size = UDim2.new(1, -36, 1, 0)
    autoConnectLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoConnectLabel.Parent = autoConnectContainer

    -- Invisible overlay button for checkbox hit area
    local autoConnectBtn = Instance.new("TextButton")
    autoConnectBtn.Size = UDim2.new(1, 0, 1, 0)
    autoConnectBtn.BackgroundTransparency = 1
    autoConnectBtn.Text = ""
    autoConnectBtn.ZIndex = 3 -- Di atas elemen visual agar klik selalu terdeteksi
    autoConnectBtn.Parent = autoConnectContainer

    -- Hover effect for checkbox container
    autoConnectBtn.MouseEnter:Connect(function()
        autoConnectContainer.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
    end)
    autoConnectBtn.MouseLeave:Connect(function()
        autoConnectContainer.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    end)

    -- ═══════════════════════════════════════════
    -- SECTION 3: TERMINAL LOG (fills remaining space)
    -- ═══════════════════════════════════════════
    -- Terminal Label
    local termLabel = Instance.new("TextLabel")
    termLabel.Text = "TERMINAL"
    termLabel.Font = Enum.Font.GothamBold
    termLabel.TextSize = 10
    termLabel.TextColor3 = Color3.fromRGB(90, 90, 100)
    termLabel.BackgroundTransparency = 1
    termLabel.Size = UDim2.new(1, 0, 0, 14)
    termLabel.TextXAlignment = Enum.TextXAlignment.Left
    termLabel.LayoutOrder = 3
    termLabel.Parent = rootFrame

    -- Terminal container: Fills ALL remaining vertical space
    local terminalContainer = Instance.new("Frame")
    terminalContainer.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    terminalContainer.BorderSizePixel = 0
    terminalContainer.LayoutOrder = 4
    terminalContainer.ClipsDescendants = true
    terminalContainer.Parent = rootFrame

    local termCorner = Instance.new("UICorner")
    termCorner.CornerRadius = UDim.new(0, 5)
    termCorner.Parent = terminalContainer

    local termStroke = Instance.new("UIStroke")
    termStroke.Color = Color3.fromRGB(40, 40, 48)
    termStroke.Thickness = 1
    termStroke.Parent = terminalContainer

    -- Scrolling log area inside terminal
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = UDim2.new(1, -8, 1, -4)
    scrollingFrame.Position = UDim2.new(0, 4, 0, 2)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.ScrollBarThickness = 4
    scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 85)
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollingFrame.Parent = terminalContainer

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 1)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollingFrame

    -- ═══════════════════════════════════════════
    -- RESPONSIVITY: Dynamically size terminal to fill remaining space
    -- ═══════════════════════════════════════════
    local function updateLayout()
        -- Calculate how much space header + controls + termLabel use
        local usedHeight = rootLayout.AbsoluteContentSize.Y - terminalContainer.AbsoluteSize.Y
        local availableHeight = rootFrame.AbsoluteSize.Y - 16 -- rootPadding top+bottom
        local termHeight = math.max(100, availableHeight - usedHeight)
        terminalContainer.Size = UDim2.new(1, 0, 0, termHeight)
    end

    -- Fire on widget resize
    widget:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
    -- Also fire once after initial render
    task.defer(updateLayout)

    -- ═══════════════════════════════════════════
    -- Store references for external access
    -- ═══════════════════════════════════════════
    UIManager.widget = widget
    UIManager.connectBtn = connectBtn
    UIManager.autoConnectBtn = autoConnectBtn
    UIManager.checkboxInner = checkboxInner
    UIManager.checkboxStroke = cbStroke
    UIManager.statusLabel = statusLabel
    UIManager.scrollingFrame = scrollingFrame
    UIManager.listLayout = listLayout
    UIManager.terminalContainer = terminalContainer
    UIManager.termStroke = termStroke
    UIManager.logsCount = 0
    
    -- Simpan referensi hover state agar setStatus bisa update base color
    UIManager._btnBaseColor = _btnBaseColor
    UIManager._isHovering = _isHovering
    UIManager._updateBtnBaseColor = function(newColor)
        _btnBaseColor = newColor
        if not _isHovering then
            connectBtn.BackgroundColor3 = newColor
        end
    end
    
    return UIManager
end

-- ═══════════════════════════════════════════
-- Menambahkan baris log baru ke terminal GUI
-- ═══════════════════════════════════════════
function UIManager:addLog(text, color)
    local timestamp = os.date("%H:%M:%S")
    local displayText = "[" .. timestamp .. "] " .. text

    local logLabel = Instance.new("TextLabel")
    logLabel.Text = displayText
    logLabel.Font = Enum.Font.Code
    logLabel.TextSize = 11
    logLabel.TextColor3 = color or Color3.fromRGB(180, 180, 190)
    logLabel.BackgroundTransparency = 1
    logLabel.TextWrapped = true
    logLabel.TextXAlignment = Enum.TextXAlignment.Left
    logLabel.RichText = false
    logLabel.AutomaticSize = Enum.AutomaticSize.Y
    logLabel.Size = UDim2.new(1, -6, 0, 0) -- Width fill, height auto

    local logPadding = Instance.new("UIPadding")
    logPadding.PaddingLeft = UDim.new(0, 4)
    logPadding.PaddingTop = UDim.new(0, 1)
    logPadding.PaddingBottom = UDim.new(0, 1)
    logPadding.Parent = logLabel
    
    logLabel.LayoutOrder = self.logsCount
    logLabel.Parent = self.scrollingFrame
    self.logsCount = self.logsCount + 1
    
    -- Limit max logs to prevent memory bloat
    if self.logsCount > 150 then
        local first = self.scrollingFrame:FindFirstChildWhichIsA("TextLabel")
        if first then first:Destroy() end
    end
    
    -- Update canvas size after a frame so AutomaticSize has resolved
    task.defer(function()
        self.scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, self.listLayout.AbsoluteContentSize.Y + 4)
        self.scrollingFrame.CanvasPosition = Vector2.new(0, math.max(0, self.listLayout.AbsoluteContentSize.Y - self.scrollingFrame.AbsoluteSize.Y))
    end)
end

-- ═══════════════════════════════════════════
-- 4 State Setter (Disconnected, Waiting, Server Connected, Connected)
-- ═══════════════════════════════════════════
function UIManager:setStatus(stateStr)
    if stateStr == "disconnected" then
        self.connectBtn.Text = "  Connect"
        self._updateBtnBaseColor(Color3.fromRGB(40, 160, 80))
        self.statusLabel.Text = "● Disconnected"
        self.statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        self.termStroke.Color = Color3.fromRGB(40, 40, 48)

    elseif stateStr == "waiting" then
        -- Server tidak dapat dijangkau (bridge belum jalan)
        self.connectBtn.Text = "  Disconnect"
        self._updateBtnBaseColor(Color3.fromRGB(180, 50, 50))
        self.statusLabel.Text = "● Waiting for Server..."
        self.statusLabel.TextColor3 = Color3.fromRGB(255, 140, 60)
        self.termStroke.Color = Color3.fromRGB(100, 70, 30)

    elseif stateStr == "server_connected" then
        -- Server reachable, tampilkan Connected meskipun agent (IDE) belum konek via stdio
        self.connectBtn.Text = "  Disconnect"
        self._updateBtnBaseColor(Color3.fromRGB(180, 50, 50))
        self.statusLabel.Text = "● Connected"
        self.statusLabel.TextColor3 = Color3.fromRGB(100, 230, 120)
        self.termStroke.Color = Color3.fromRGB(50, 120, 60)

    elseif stateStr == "connected" then
        self.connectBtn.Text = "  Disconnect"
        self._updateBtnBaseColor(Color3.fromRGB(180, 50, 50))
        self.statusLabel.Text = "● Connected"
        self.statusLabel.TextColor3 = Color3.fromRGB(100, 230, 120)
        self.termStroke.Color = Color3.fromRGB(50, 120, 60)
    end
end

-- Mengubah visual custom checkbox
function UIManager:setAutoConnectState(isAuto)
    self.checkboxInner.Visible = isAuto
    if isAuto then
        self.checkboxStroke.Color = Color3.fromRGB(80, 170, 255)
    else
        self.checkboxStroke.Color = Color3.fromRGB(80, 80, 95)
    end
end

-- Sakelar visibilitas panel GUI
function UIManager:toggleVisibility()
    if self.widget then
        self.widget.Enabled = not self.widget.Enabled
    end
end

return UIManager
