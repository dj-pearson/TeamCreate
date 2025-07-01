-- src/shared/modules/UIManager/init.lua
-- Handles all UI creation and management for the Team Create Enhancement Plugin

local UIManager = {}

-- Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Local variables
local dockWidget = nil
local UI_CONSTANTS = nil
local mainFrame = nil
local currentTab = "overview"
local tabButtons = {}
local contentPanels = {}

-- UI Creation Utilities
local function createRoundedFrame(parent, props)
    local frame = Instance.new("Frame")
    frame.Name = props.Name or "RoundedFrame"
    frame.Parent = parent
    frame.BackgroundColor3 = props.BackgroundColor3 or UI_CONSTANTS.COLORS.SECONDARY_BG
    frame.BorderSizePixel = 0
    frame.Size = props.Size or UDim2.new(1, 0, 1, 0)
    frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UI_CONSTANTS.SIZES.CORNER_RADIUS)
    corner.Parent = frame
    
    -- Add subtle glow effect
    if props.Glow then
        local stroke = Instance.new("UIStroke")
        stroke.Color = props.GlowColor or UI_CONSTANTS.COLORS.ACCENT_BLUE
        stroke.Thickness = 1
        stroke.Transparency = 0.7
        stroke.Parent = frame
    end
    
    return frame
end

local function createStyledButton(parent, props)
    local button = Instance.new("TextButton")
    button.Name = props.Name or "StyledButton"
    button.Parent = parent
    button.Size = props.Size or UDim2.new(0, 120, 0, 32)
    button.Position = props.Position or UDim2.new(0, 0, 0, 0)
    button.BackgroundColor3 = props.BackgroundColor3 or UI_CONSTANTS.COLORS.ACCENT_BLUE
    button.BorderSizePixel = 0
    button.Text = props.Text or "Button"
    button.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    button.TextScaled = true
    button.Font = UI_CONSTANTS.FONTS.MAIN
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    -- Hover effect
    local hoverTween = TweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {BackgroundColor3 = props.HoverColor or UI_CONSTANTS.COLORS.ACCENT_PURPLE}
    )
    
    local normalTween = TweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {BackgroundColor3 = props.BackgroundColor3 or UI_CONSTANTS.COLORS.ACCENT_BLUE}
    )
    
    button.MouseEnter:Connect(function()
        hoverTween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        normalTween:Play()
    end)
    
    return button
end

local function createStatusIndicator(parent, props)
    local frame = Instance.new("Frame")
    frame.Name = props.Name or "StatusIndicator"
    frame.Parent = parent
    frame.Size = UDim2.new(0, 12, 0, 12)
    frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = props.Color or UI_CONSTANTS.COLORS.SUCCESS_GREEN
    frame.BorderSizePixel = 0
    
    -- Make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = frame
    
    -- Pulsing animation for active status
    if props.Pulse then
        local pulseIn = TweenService:Create(
            frame,
            TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Transparency = 0.3}
        )
        pulseIn:Play()
    end
    
    return frame
end

-- Tab System
local function createTabSystem(parent)
    local tabContainer = createRoundedFrame(parent, {
        Name = "TabContainer",
        Size = UDim2.new(1, -20, 0, 50),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = UI_CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true
    })
    
    tabButtons = {}
    local tabs = {
        {id = "overview", text = "Overview", icon = "📊"},
        {id = "permissions", text = "Permissions", icon = "🔐"},
        {id = "assets", text = "Assets", icon = "🎯"},
        {id = "notifications", text = "Notifications", icon = "🔔"}, -- COMPLIANCE: Renamed from Discord
        {id = "settings", text = "Settings", icon = "⚙️"}
    }
    
    for i, tab in ipairs(tabs) do
        local button = createStyledButton(tabContainer, {
            Name = tab.id .. "Tab",
            Text = tab.icon .. " " .. tab.text,
            Size = UDim2.new(0.2, -4, 1, -10),
            Position = UDim2.new((i-1) * 0.2, 2, 0, 5),
            BackgroundColor3 = currentTab == tab.id and UI_CONSTANTS.COLORS.ACCENT_PURPLE or UI_CONSTANTS.COLORS.SECONDARY_BG
        })
        
        button.MouseButton1Click:Connect(function()
            UIManager.switchTab(tab.id)
        end)
        
        tabButtons[tab.id] = button
    end
    
    return tabContainer
end

-- Content Panels
local function createOverviewPanel(parent)
    local panel = createRoundedFrame(parent, {
        Name = "OverviewPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    
    -- Connection Status
    local statusFrame = createRoundedFrame(panel, {
        Name = "ConnectionStatus",
        Size = UDim2.new(1, -20, 0, 80),
        Position = UDim2.new(0, 10, 0, 10),
        Glow = true,
        GlowColor = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    })
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Parent = statusFrame
    statusLabel.Size = UDim2.new(1, -50, 0, 30)
    statusLabel.Position = UDim2.new(0, 40, 0, 10)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Team Create: Connected"
    statusLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    statusLabel.TextScaled = true
    statusLabel.Font = UI_CONSTANTS.FONTS.HEADER
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local statusIndicator = createStatusIndicator(statusFrame, {
        Name = "StatusDot",
        Position = UDim2.new(0, 15, 0, 15),
        Color = UI_CONSTANTS.COLORS.SUCCESS_GREEN,
        Pulse = true
    })
    
    -- Active Users
    local usersFrame = createRoundedFrame(panel, {
        Name = "ActiveUsers",
        Size = UDim2.new(1, -20, 0, 120),
        Position = UDim2.new(0, 10, 0, 100)
    })
    
    local usersLabel = Instance.new("TextLabel")
    usersLabel.Name = "UsersLabel"
    usersLabel.Parent = usersFrame
    usersLabel.Size = UDim2.new(1, -20, 0, 30)
    usersLabel.Position = UDim2.new(0, 10, 0, 10)
    usersLabel.BackgroundTransparency = 1
    usersLabel.Text = "Active Users (3)"
    usersLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    usersLabel.TextScaled = true
    usersLabel.Font = UI_CONSTANTS.FONTS.HEADER
    usersLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Recent Activity
    local activityFrame = createRoundedFrame(panel, {
        Name = "RecentActivity",
        Size = UDim2.new(1, -20, 1, -240),
        Position = UDim2.new(0, 10, 0, 230)
    })
    
    local activityLabel = Instance.new("TextLabel")
    activityLabel.Name = "ActivityLabel"
    activityLabel.Parent = activityFrame
    activityLabel.Size = UDim2.new(1, -20, 0, 30)
    activityLabel.Position = UDim2.new(0, 10, 0, 10)
    activityLabel.BackgroundTransparency = 1
    activityLabel.Text = "Recent Activity"
    activityLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    activityLabel.TextScaled = true
    activityLabel.Font = UI_CONSTANTS.FONTS.HEADER
    activityLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

local function createNotificationsPanel(parent)
    -- COMPLIANCE: Internal notifications only, no external HTTP
    local panel = createRoundedFrame(parent, {
        Name = "NotificationsPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🔔 Internal Notifications"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local complianceNote = Instance.new("TextLabel")
    complianceNote.Name = "ComplianceNote"
    complianceNote.Parent = panel
    complianceNote.Size = UDim2.new(1, -20, 0, 60)
    complianceNote.Position = UDim2.new(0, 10, 0, 60)
    complianceNote.BackgroundTransparency = 1
    complianceNote.Text = "⚠️ COMPLIANCE: External webhooks disabled to meet Roblox plugin policies. All notifications are internal only."
    complianceNote.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    complianceNote.TextScaled = true
    complianceNote.Font = UI_CONSTANTS.FONTS.MAIN
    complianceNote.TextWrapped = true
    complianceNote.TextXAlignment = Enum.TextXAlignment.Left
    complianceNote.TextYAlignment = Enum.TextYAlignment.Top
    
    return panel
end

-- Public API
function UIManager.initialize(widget, constants)
    dockWidget = widget
    UI_CONSTANTS = constants
    
    -- Create main UI
    mainFrame = Instance.new("ScrollingFrame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = dockWidget
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = UI_CONSTANTS.COLORS.PRIMARY_BG
    mainFrame.BorderSizePixel = 0
    mainFrame.ScrollBarThickness = 8
    mainFrame.ScrollBarImageColor3 = UI_CONSTANTS.COLORS.ACCENT_BLUE
    
    -- Create tab system
    createTabSystem(mainFrame)
    
    -- Create content panels
    contentPanels.overview = createOverviewPanel(mainFrame)
    contentPanels.notifications = createNotificationsPanel(mainFrame)
    
    -- Hide all panels except overview
    for id, panel in pairs(contentPanels) do
        panel.Visible = (id == currentTab)
    end
    
    print("[TCE] UI initialized with compliant design")
end

function UIManager.switchTab(tabId)
    -- Update tab appearance
    for id, button in pairs(tabButtons) do
        local targetColor = (id == tabId) and UI_CONSTANTS.COLORS.ACCENT_PURPLE or UI_CONSTANTS.COLORS.SECONDARY_BG
        local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor})
        tween:Play()
    end
    
    -- Show/hide panels
    for id, panel in pairs(contentPanels) do
        panel.Visible = (id == tabId)
    end
    
    currentTab = tabId
    print("[TCE] Switched to tab:", tabId)
end

function UIManager.refresh()
    print("[TCE] Refreshing UI...")
    -- Update dynamic content
end

function UIManager.cleanup()
    if mainFrame then
        mainFrame:Destroy()
        mainFrame = nil
    end
    contentPanels = {}
    tabButtons = {}
    print("[TCE] UI cleaned up")
end

function UIManager.updateConnectionStatus(status, color)
    if contentPanels.overview then
        local statusFrame = contentPanels.overview:FindFirstChild("ConnectionStatus")
        if statusFrame then
            local statusLabel = statusFrame:FindFirstChild("StatusLabel")
            local statusDot = statusFrame:FindFirstChild("StatusDot")
            
            if statusLabel then
                statusLabel.Text = "Team Create: " .. status
            end
            
            if statusDot then
                statusDot.BackgroundColor3 = color
            end
        end
    end
end

function UIManager.updateUserList(users)
    if contentPanels.overview then
        local usersFrame = contentPanels.overview:FindFirstChild("ActiveUsers")
        if usersFrame then
            local usersLabel = usersFrame:FindFirstChild("UsersLabel")
            if usersLabel then
                usersLabel.Text = "Active Users (" .. #users .. ")"
            end
        end
    end
end

function UIManager.addActivityLog(message)
    -- Add to internal activity feed
    print("[TCE] Activity:", message)
end

-- COMPLIANCE: Show compliance notice
function UIManager.showComplianceNotice()
    local notice = Instance.new("ScreenGui")
    notice.Name = "ComplianceNotice"
    notice.Parent = game.Players.LocalPlayer.PlayerGui
    notice.ResetOnSpawn = false
    
    local frame = createRoundedFrame(notice, {
        Name = "NoticeFrame",
        Size = UDim2.new(0, 400, 0, 150),
        Position = UDim2.new(0.5, -200, 0.1, 0),
        BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG,
        Glow = true,
        GlowColor = UI_CONSTANTS.COLORS.ACCENT_TEAL
    })
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = frame
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "✅ COMPLIANCE MODE ACTIVE"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Parent = frame
    messageLabel.Size = UDim2.new(1, -20, 0, 80)
    messageLabel.Position = UDim2.new(0, 10, 0, 55)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = "Plugin running in compliance mode. External integrations disabled to meet Roblox policies."
    messageLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    messageLabel.TextScaled = true
    messageLabel.Font = UI_CONSTANTS.FONTS.MAIN
    messageLabel.TextWrapped = true
    
    -- Auto-close after 5 seconds
    game:GetService("Debris"):AddItem(notice, 5)
end

return UIManager 