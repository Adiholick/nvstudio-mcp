local UIManager = {}
local widget = nil

function UIManager.init(pluginInstance, studioId)
    -- Membuat Widget Panel yang bisa di-dock (menempel)
    local widgetInfo = DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Right,
        false,  -- Initially hidden until toolbar button is clicked
        false,  -- Override enabled
        400,    -- Default width
        550,    -- Default height
        350,    -- Min width
        400     -- Min height
    )
    
    widget = pluginInstance:CreateDockWidgetPluginGui("NVStudioMCP_GUI_V2", widgetInfo)
    widget.Title = "NVStudio MCP Dashboard"
    
    -- Main Container dengan ScrollingFrame agar aman di layar kecil (Responsif)
    local mainFrame = Instance.new("ScrollingFrame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- Tema Gelap
    mainFrame.BorderSizePixel = 0
    mainFrame.ScrollBarThickness = 0
    mainFrame.CanvasSize = UDim2.new(0, 0, 1, 0)
    mainFrame.Parent = widget
    
    local mainLayout = Instance.new("UIListLayout")
    mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    mainLayout.Padding = UDim.new(0, 10)
    mainLayout.Parent = mainFrame
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 15)
    padding.PaddingRight = UDim.new(0, 15)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = mainFrame

    -- HEADER SECTION
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, 95)
    headerFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    local hCorner = Instance.new("UICorner")
    hCorner.CornerRadius = UDim.new(0, 8)
    hCorner.Parent = headerFrame
    headerFrame.LayoutOrder = 1
    headerFrame.Parent = mainFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Text = "NVStudio MCP"
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 22
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.Size = UDim2.new(1, -30, 0, 25)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = headerFrame
    
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Text = "Versi: v1.2.0 (Hybrid Agent)"
    versionLabel.Font = Enum.Font.Gotham
    versionLabel.TextSize = 12
    versionLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Position = UDim2.new(0, 15, 0, 35)
    versionLabel.Size = UDim2.new(1, -30, 0, 15)
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    versionLabel.Parent = headerFrame
    
    local placeLabel = Instance.new("TextLabel")
    placeLabel.Text = "Place: " .. (game.Name ~= "" and game.Name or "Untitled Baseplate")
    placeLabel.Font = Enum.Font.Gotham
    placeLabel.TextSize = 12
    placeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    placeLabel.BackgroundTransparency = 1
    placeLabel.Position = UDim2.new(0, 15, 0, 50)
    placeLabel.Size = UDim2.new(1, -30, 0, 15)
    placeLabel.TextXAlignment = Enum.TextXAlignment.Left
    placeLabel.Parent = headerFrame

    local idLabel = Instance.new("TextLabel")
    idLabel.Text = "Studio ID: " .. string.sub(tostring(studioId), 1, 13) .. "..."
    idLabel.Font = Enum.Font.Code
    idLabel.TextSize = 12
    idLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    idLabel.BackgroundTransparency = 1
    idLabel.Position = UDim2.new(0, 15, 0, 68)
    idLabel.Size = UDim2.new(1, -30, 0, 15)
    idLabel.TextXAlignment = Enum.TextXAlignment.Left
    idLabel.Parent = headerFrame

    -- CONNECTION INFO SECTION
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, 0, 0, 30)
    infoFrame.BackgroundTransparency = 1
    infoFrame.LayoutOrder = 2
    infoFrame.Parent = mainFrame
    
    local serverUrlLabel = Instance.new("TextLabel")
    serverUrlLabel.Text = "Server: http://localhost:3055"
    serverUrlLabel.Font = Enum.Font.Code
    serverUrlLabel.TextSize = 13
    serverUrlLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    serverUrlLabel.BackgroundTransparency = 1
    serverUrlLabel.Size = UDim2.new(1, -140, 1, 0)
    serverUrlLabel.TextXAlignment = Enum.TextXAlignment.Left
    serverUrlLabel.Parent = infoFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 140, 1, 0)
    statusLabel.Position = UDim2.new(1, -140, 0, 0)
    statusLabel.Text = "🔴 Disconnected"
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 13
    statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    statusLabel.Parent = infoFrame

    -- CONTROLS SECTION
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Size = UDim2.new(1, 0, 0, 40)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.LayoutOrder = 3
    controlsFrame.Parent = mainFrame

    -- Tombol Connect
    local connectBtn = Instance.new("TextButton")
    connectBtn.Size = UDim2.new(0.45, 0, 0, 35)
    connectBtn.Text = "Connect"
    connectBtn.Font = Enum.Font.GothamBold
    connectBtn.TextSize = 14
    connectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    connectBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 0) -- Hijau
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 6)
    cCorner.Parent = connectBtn
    connectBtn.Parent = controlsFrame
    
    -- Custom Checkbox (Auto Connect)
    local autoConnectContainer = Instance.new("Frame")
    autoConnectContainer.Size = UDim2.new(0.5, 0, 0, 35)
    autoConnectContainer.Position = UDim2.new(0.5, 0, 0, 0)
    autoConnectContainer.BackgroundTransparency = 1
    autoConnectContainer.Parent = controlsFrame

    local checkboxOuter = Instance.new("Frame")
    checkboxOuter.Size = UDim2.new(0, 20, 0, 20)
    checkboxOuter.Position = UDim2.new(0, 10, 0.5, -10)
    checkboxOuter.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    checkboxOuter.BorderSizePixel = 0
    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 4)
    cbCorner.Parent = checkboxOuter
    checkboxOuter.Parent = autoConnectContainer

    local checkboxInner = Instance.new("Frame")
    checkboxInner.Size = UDim2.new(0, 12, 0, 12)
    checkboxInner.Position = UDim2.new(0.5, -6, 0.5, -6)
    checkboxInner.BackgroundColor3 = Color3.fromRGB(0, 180, 255) -- Warna centang biru
    checkboxInner.Visible = false -- Default false
    local cbiCorner = Instance.new("UICorner")
    cbiCorner.CornerRadius = UDim.new(0, 2)
    cbiCorner.Parent = checkboxInner
    checkboxInner.Parent = checkboxOuter

    local autoConnectLabel = Instance.new("TextLabel")
    autoConnectLabel.Text = "Auto-Connect"
    autoConnectLabel.Font = Enum.Font.Gotham
    autoConnectLabel.TextSize = 13
    autoConnectLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    autoConnectLabel.BackgroundTransparency = 1
    autoConnectLabel.Position = UDim2.new(0, 40, 0, 0)
    autoConnectLabel.Size = UDim2.new(1, -40, 1, 0)
    autoConnectLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoConnectLabel.Parent = autoConnectContainer

    -- Invisible overlay button for checkbox
    local autoConnectBtn = Instance.new("TextButton")
    autoConnectBtn.Size = UDim2.new(1, 0, 1, 0)
    autoConnectBtn.BackgroundTransparency = 1
    autoConnectBtn.Text = ""
    autoConnectBtn.Parent = autoConnectContainer

    -- LOG TERMINAL SECTION
    local terminalContainer = Instance.new("Frame")
    terminalContainer.Size = UDim2.new(1, 0, 1, -210) -- Flexible
    terminalContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 15) -- Hitam pekat
    local termCorner = Instance.new("UICorner")
    termCorner.CornerRadius = UDim.new(0, 6)
    termCorner.Parent = terminalContainer
    terminalContainer.LayoutOrder = 4
    terminalContainer.Parent = mainFrame
    
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = UDim2.new(1, -10, 1, -10)
    scrollingFrame.Position = UDim2.new(0, 5, 0, 5)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.ScrollBarThickness = 6
    scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollingFrame.Parent = terminalContainer
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollingFrame

    -- Responsivity handler: Adjust terminal height dynamically
    widget:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        mainFrame.CanvasSize = UDim2.new(0, 0, 0, mainLayout.AbsoluteContentSize.Y + 30)
        -- Menjaga agar terminalContainer tidak menabrak elemen di atasnya
        terminalContainer.Size = UDim2.new(1, 0, 0, math.max(150, widget.AbsoluteSize.Y - 210))
    end)

    -- Menyimpan referensi
    UIManager.widget = widget
    UIManager.connectBtn = connectBtn
    UIManager.autoConnectBtn = autoConnectBtn
    UIManager.checkboxInner = checkboxInner
    UIManager.statusLabel = statusLabel
    UIManager.scrollingFrame = scrollingFrame
    UIManager.listLayout = listLayout
    UIManager.terminalContainer = terminalContainer
    UIManager.logsCount = 0
    
    return UIManager
end

-- Menambahkan baris log baru ke terminal GUI
function UIManager:addLog(text, color)
    local logLabel = Instance.new("TextLabel")
    logLabel.Text = text
    logLabel.Font = Enum.Font.Code
    logLabel.TextSize = 12
    logLabel.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    logLabel.BackgroundTransparency = 1
    logLabel.TextWrapped = true
    logLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local bounds = game:GetService("TextService"):GetTextSize(text, 12, Enum.Font.Code, Vector2.new(self.scrollingFrame.AbsoluteSize.X - 10, 10000))
    logLabel.Size = UDim2.new(1, -10, 0, math.max(18, bounds.Y))
    
    logLabel.LayoutOrder = self.logsCount
    logLabel.Parent = self.scrollingFrame
    self.logsCount = self.logsCount + 1
    
    if self.logsCount > 100 then
        local first = self.scrollingFrame:FindFirstChildWhichIsA("TextLabel")
        if first then first:Destroy() end
    end
    
    self.scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, self.listLayout.AbsoluteContentSize.Y)
    self.scrollingFrame.CanvasPosition = Vector2.new(0, self.scrollingFrame.CanvasSize.Y.Offset)
end

-- 3 State Setter (Disconnected, Waiting, Connected)
function UIManager:setStatus(stateStr)
    if stateStr == "disconnected" then
        self.connectBtn.Text = "Connect"
        self.connectBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 0) -- Hijau
        self.statusLabel.Text = "🔴 Disconnected"
        self.statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        self.terminalContainer.BorderColor3 = Color3.fromRGB(40, 40, 40)
        self.terminalContainer.BorderSizePixel = 1
    elseif stateStr == "waiting" then
        self.connectBtn.Text = "Disconnect"
        self.connectBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40) -- Merah
        self.statusLabel.Text = "🟡 Waiting for AI..."
        self.statusLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        self.terminalContainer.BorderColor3 = Color3.fromRGB(255, 220, 100)
        self.terminalContainer.BorderSizePixel = 1
    elseif stateStr == "connected" then
        self.connectBtn.Text = "Disconnect"
        self.connectBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40) -- Merah
        self.statusLabel.Text = "🟢 Connected"
        self.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        self.terminalContainer.BorderColor3 = Color3.fromRGB(100, 255, 100)
        self.terminalContainer.BorderSizePixel = 1
    end
end

-- Mengubah visual custom checkbox
function UIManager:setAutoConnectState(isAuto)
    self.checkboxInner.Visible = isAuto
end

-- Sakelar visibilitas panel GUI
function UIManager:toggleVisibility()
    if self.widget then
        self.widget.Enabled = not self.widget.Enabled
    end
end

return UIManager
