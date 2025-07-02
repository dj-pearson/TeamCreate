-- src/shared/modules/UIManager/init.lua
-- Modern UI coordinator with ClickUp-inspired design system

local UIManager = {}

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Import UI modules
local UIUtilities = require(script.UIUtilities)
local TasksPanel = require(script.TasksPanel)
local ViewSystem = require(script.ViewSystem)

-- Local variables
local dockWidget = nil
local mainFrame = nil
local currentTab = "tasks"
local tabButtons = {}
local contentPanels = {}

-- Module references (will be injected)
local PermissionManager = nil
local AssetLockManager = nil
local ConnectionMonitor = nil
local NotificationManager = nil
local ConflictResolver = nil
local TaskManager = nil

-- Auto-refresh system
local refreshConnection = nil
local REFRESH_INTERVAL = 5 -- seconds
local lastRefreshTime = 0

-- Main navigation tabs
local MAIN_TABS = {
    {id = "dashboard", text = "📊 Dashboard", icon = "📊"},
    {id = "tasks", text = "📋 Tasks", icon = "📋"},
    {id = "assets", text = "🎯 Assets", icon = "🎯"},
    {id = "team", text = "👥 Team", icon = "👥"},
    {id = "settings", text = "⚙️ Settings", icon = "⚙️"}
}

function UIManager.initialize(widget, modules)
    print("[TCE] UIManager initializing with modern design...")
    
    dockWidget = widget
    PermissionManager = modules.PermissionManager
    AssetLockManager = modules.AssetLockManager
    ConnectionMonitor = modules.ConnectionMonitor
    NotificationManager = modules.NotificationManager
    ConflictResolver = modules.ConflictResolver
    TaskManager = modules.TaskManager
    
    -- Initialize sub-modules
    ViewSystem.initialize({
        UIUtilities = UIUtilities,
        TaskManager = TaskManager
    })
    
    TasksPanel.initialize({
        TaskManager = TaskManager,
        ConnectionMonitor = ConnectionMonitor,
        NotificationManager = NotificationManager,
        UIUtilities = UIUtilities,
        dockWidget = dockWidget
    })
    
    UIManager.createModernUI()
    UIManager.startAutoRefresh()
    
    print("[TCE] Modern UIManager initialized successfully")
    return true
end

function UIManager.createModernUI()
    -- Create main container with modern styling
    mainFrame = UIUtilities.createCard(dockWidget, {
        Name = "TCE_MainFrame",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Shadow = false,
        CornerRadius = 0
    })
    
    -- Create modern navigation header
    UIManager.createNavigationHeader(mainFrame)
    
    -- Create content area
    local contentArea = UIUtilities.createCard(mainFrame, {
        Name = "ContentArea",
        Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_LG, 1, -UIUtilities.CONSTANTS.SIZES.NAVBAR_HEIGHT - UIUtilities.CONSTANTS.SIZES.PADDING_LG),
        Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_MD, 0, UIUtilities.CONSTANTS.SIZES.NAVBAR_HEIGHT + UIUtilities.CONSTANTS.SIZES.PADDING_MD),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG,
        Shadow = false
    })
    
    -- Create all panels
    contentPanels = {
        dashboard = UIManager.createDashboardPanel(contentArea),
        tasks = ViewSystem.createViewContainer(contentArea),
        assets = UIManager.createAssetsPanel(contentArea),
        team = UIManager.createTeamPanel(contentArea),
        settings = UIManager.createSettingsPanel(contentArea)
    }
    
    -- Show initial tab
    UIManager.switchTab("tasks") -- Start with tasks view
end

function UIManager.createNavigationHeader(parent)
    local header = UIUtilities.createCard(parent, {
        Name = "NavigationHeader",
        Size = UDim2.new(1, 0, 0, UIUtilities.CONSTANTS.SIZES.NAVBAR_HEIGHT),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG,
        CornerRadius = 0,
        Shadow = true,
        BorderColor = UIUtilities.CONSTANTS.COLORS.BORDER_LIGHT,
        BorderThickness = 1,
        BorderTransparency = 0.5
    })
    
    -- Logo and title section
    local titleSection = Instance.new("Frame")
    titleSection.Name = "TitleSection"
    titleSection.Parent = header
    titleSection.Size = UDim2.new(0, 200, 1, 0)
    titleSection.Position = UDim2.new(0, 0, 0, 0)
    titleSection.BackgroundTransparency = 1
    
    local logoIcon = Instance.new("TextLabel")
    logoIcon.Name = "LogoIcon"
    logoIcon.Parent = titleSection
    logoIcon.Size = UDim2.new(0, 32, 0, 32)
    logoIcon.Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0.5, -16)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Text = "🚀"
    logoIcon.TextSize = 24
    logoIcon.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = titleSection
    titleLabel.Size = UDim2.new(0, 140, 0, 24)
    titleLabel.Position = UDim2.new(0, 56, 0.5, -12)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Team Create Pro"
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_LG
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Navigation tabs
    local navContainer = Instance.new("Frame")
    navContainer.Name = "NavigationTabs"
    navContainer.Parent = header
    navContainer.Size = UDim2.new(0, 400, 0, 40)
    navContainer.Position = UDim2.new(0.5, -200, 0.5, -20)
    navContainer.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(navContainer, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_SM
    })
    
    tabButtons = {}
    for i, tab in ipairs(MAIN_TABS) do
        local button = UIUtilities.createButton(navContainer, {
            Name = tab.id .. "Tab",
            Text = tab.text,
            Size = UDim2.new(0, 85, 0, 36),
            Variant = currentTab == tab.id and "primary" or "ghost",
            CornerRadius = UIUtilities.CONSTANTS.SIZES.RADIUS_MD
        })
        
        button.MouseButton1Click:Connect(function()
            UIManager.switchTab(tab.id)
        end)
        
        tabButtons[tab.id] = button
    end
    
    -- User section
    local userSection = Instance.new("Frame")
    userSection.Name = "UserSection"
    userSection.Parent = header
    userSection.Size = UDim2.new(0, 180, 1, 0)
    userSection.Position = UDim2.new(1, -180, 0, 0)
    userSection.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(userSection, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_SM
    })
    
    -- Connection status indicator
    local connectionStatus = Instance.new("Frame")
    connectionStatus.Name = "ConnectionStatus"
    connectionStatus.Parent = userSection
    connectionStatus.Size = UDim2.new(0, 12, 0, 12)
    connectionStatus.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SUCCESS
    connectionStatus.BorderSizePixel = 0
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0.5, 0)
    statusCorner.Parent = connectionStatus
    
    -- User avatar and name
    local localPlayer = Players.LocalPlayer
    if localPlayer then
        local userAvatar = UIUtilities.createAvatar(userSection, {
            Name = "UserAvatar",
            Size = UDim2.new(0, 32, 0, 32),
            UserId = localPlayer.UserId
        })
        
        local userName = Instance.new("TextLabel")
        userName.Name = "UserName"
        userName.Parent = userSection
        userName.Size = UDim2.new(0, 100, 0, 32)
        userName.BackgroundTransparency = 1
        userName.Text = localPlayer.DisplayName or localPlayer.Name
        userName.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
        userName.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
        userName.Font = UIUtilities.CONSTANTS.FONTS.BODY
        userName.TextXAlignment = Enum.TextXAlignment.Left
        userName.TextTruncate = Enum.TextTruncate.AtEnd
    end
    
    return header
end

function UIManager.switchTab(tabId)
    if currentTab == tabId then return end
    
    currentTab = tabId
    
    -- Update tab button appearance
    for id, button in pairs(tabButtons) do
        if id == tabId then
            button.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
            button.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
        else
            button.BackgroundColor3 = Color3.new(0, 0, 0)
            button.BackgroundTransparency = 1
            button.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
        end
    end
    
    -- Show/hide panels with smooth transitions
    for id, panel in pairs(contentPanels) do
        if id == tabId then
            panel.Visible = true
            UIUtilities.fadeIn(panel, UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST)
        else
            UIUtilities.fadeOut(panel, UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST, function()
                panel.Visible = false
            end)
        end
    end
    
    -- Refresh current panel
    UIManager.refreshCurrentTab()
    
    print("[TCE] Switched to tab:", tabId)
end

function UIManager.refreshCurrentTab()
    if currentTab == "dashboard" then
        UIManager.refreshDashboard()
    elseif currentTab == "tasks" then
        ViewSystem.refreshCurrentView()
    elseif currentTab == "assets" then
        UIManager.refreshAssets()
    elseif currentTab == "team" then
        UIManager.refreshTeam()
    elseif currentTab == "settings" then
        UIManager.refreshSettings()
    end
end

-- Dashboard Panel
function UIManager.createDashboardPanel(parent)
    local panel = UIUtilities.createCard(parent, {
        Name = "DashboardPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Shadow = false
    })
    
    -- Dashboard title
    local title = Instance.new("TextLabel")
    title.Name = "DashboardTitle"
    title.Parent = panel
    title.Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_2XL, 0, 40)
    title.Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0, UIUtilities.CONSTANTS.SIZES.PADDING_LG)
    title.BackgroundTransparency = 1
    title.Text = "📊 Project Dashboard"
    title.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    title.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_2XL
    title.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Stats grid
    local statsGrid = Instance.new("Frame")
    statsGrid.Name = "StatsGrid"
    statsGrid.Parent = panel
    statsGrid.Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_2XL, 0, 120)
    statsGrid.Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0, 70)
    statsGrid.BackgroundTransparency = 1
    
    UIUtilities.applyGridLayout(statsGrid, {
        CellSize = UDim2.new(0.24, -6, 1, 0),
        CellPadding = UDim2.new(0, 8, 0, 8)
    })
    
    -- Create stat cards
    local stats = {
        {title = "Total Tasks", value = "24", icon = "📋", color = UIUtilities.CONSTANTS.COLORS.INFO},
        {title = "In Progress", value = "8", icon = "🔄", color = UIUtilities.CONSTANTS.COLORS.STATUS_PROGRESS},
        {title = "Completed", value = "12", icon = "✅", color = UIUtilities.CONSTANTS.COLORS.SUCCESS},
        {title = "Team Members", value = "5", icon = "👥", color = UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY}
    }
    
    for _, stat in ipairs(stats) do
        UIManager.createStatCard(statsGrid, stat)
    end
    
    -- Recent activity section
    local activitySection = UIUtilities.createCard(panel, {
        Name = "ActivitySection",
        Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_2XL, 1, -220),
        Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0, 210),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    local activityTitle = Instance.new("TextLabel")
    activityTitle.Name = "ActivityTitle"
    activityTitle.Parent = activitySection
    activityTitle.Size = UDim2.new(1, 0, 0, 30)
    activityTitle.Position = UDim2.new(0, 0, 0, 0)
    activityTitle.BackgroundTransparency = 1
    activityTitle.Text = "📈 Recent Activity"
    activityTitle.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    activityTitle.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_LG
    activityTitle.Font = UIUtilities.CONSTANTS.FONTS.SUBHEADING
    activityTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

function UIManager.createStatCard(parent, stat)
    local card = UIUtilities.createCard(parent, {
        Name = "StatCard_" .. stat.title:gsub("%s", ""),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG,
        Hoverable = true
    })
    
    -- Icon
    local icon = Instance.new("TextLabel")
    icon.Name = "StatIcon"
    icon.Parent = card
    icon.Size = UDim2.new(0, 32, 0, 32)
    icon.Position = UDim2.new(0, 0, 0, 8)
    icon.BackgroundTransparency = 1
    icon.Text = stat.icon
    icon.TextSize = 24
    icon.Font = UIUtilities.CONSTANTS.FONTS.BODY
    
    -- Value
    local value = Instance.new("TextLabel")
    value.Name = "StatValue"
    value.Parent = card
    value.Size = UDim2.new(1, -40, 0, 32)
    value.Position = UDim2.new(0, 40, 0, 8)
    value.BackgroundTransparency = 1
    value.Text = stat.value
    value.TextColor3 = stat.color
    value.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_2XL
    value.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    value.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "StatTitle"
    title.Parent = card
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 1, -28)
    title.BackgroundTransparency = 1
    title.Text = stat.title
    title.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    title.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
    title.Font = UIUtilities.CONSTANTS.FONTS.BODY
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    return card
end

-- Assets Panel
function UIManager.createAssetsPanel(parent)
    local panel = UIUtilities.createCard(parent, {
        Name = "AssetsPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Shadow = false
    })
    
    -- Assets title and controls
    local header = UIUtilities.createCard(panel, {
        Name = "AssetsHeader",
        Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_2XL, 0, 64),
        Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0, UIUtilities.CONSTANTS.SIZES.PADDING_LG),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    local assetsTitle = Instance.new("TextLabel")
    assetsTitle.Name = "AssetsTitle"
    assetsTitle.Parent = header
    assetsTitle.Size = UDim2.new(0.5, 0, 1, 0)
    assetsTitle.Position = UDim2.new(0, 0, 0, 0)
    assetsTitle.BackgroundTransparency = 1
    assetsTitle.Text = "🎯 Asset Management"
    assetsTitle.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    assetsTitle.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XL
    assetsTitle.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    assetsTitle.TextXAlignment = Enum.TextXAlignment.Left
    assetsTitle.TextYAlignment = Enum.TextYAlignment.Center
    
    return panel
end

-- Team Panel
function UIManager.createTeamPanel(parent)
    local panel = UIUtilities.createCard(parent, {
        Name = "TeamPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Shadow = false
    })
    
    -- Team title
    local title = Instance.new("TextLabel")
    title.Name = "TeamTitle"
    title.Parent = panel
    title.Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_2XL, 0, 40)
    title.Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0, UIUtilities.CONSTANTS.SIZES.PADDING_LG)
    title.BackgroundTransparency = 1
    title.Text = "👥 Team Management"
    title.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    title.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_2XL
    title.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

-- Settings Panel
function UIManager.createSettingsPanel(parent)
    local panel = UIUtilities.createCard(parent, {
        Name = "SettingsPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Shadow = false
    })
    
    -- Settings title
    local title = Instance.new("TextLabel")
    title.Name = "SettingsTitle"
    title.Parent = panel
    title.Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_2XL, 0, 40)
    title.Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0, UIUtilities.CONSTANTS.SIZES.PADDING_LG)
    title.BackgroundTransparency = 1
    title.Text = "⚙️ Settings & Configuration"
    title.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    title.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_2XL
    title.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

-- Refresh functions
function UIManager.refreshDashboard()
    -- Update dashboard stats
    if not TaskManager then return end
    
    -- This would update the dashboard with real data
    print("[TCE] Dashboard refreshed")
end

function UIManager.refreshAssets()
    -- Update assets display
    print("[TCE] Assets refreshed")
end

function UIManager.refreshTeam()
    -- Update team display
    print("[TCE] Team refreshed")
end

function UIManager.refreshSettings()
    -- Update settings display
    print("[TCE] Settings refreshed")
end

function UIManager.startAutoRefresh()
    if refreshConnection then
        refreshConnection:Disconnect()
    end
    
    refreshConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        if currentTime - lastRefreshTime >= REFRESH_INTERVAL then
            UIManager.refreshCurrentTab()
            lastRefreshTime = currentTime
        end
    end)
end

function UIManager.cleanup()
    if refreshConnection then
        refreshConnection:Disconnect()
        refreshConnection = nil
    end
    
    -- Cleanup sub-modules
    if ViewSystem.cleanup then ViewSystem.cleanup() end
    if TasksPanel.cleanup then TasksPanel.cleanup() end
    
    print("[TCE] Modern UIManager cleaned up")
end

-- Public API
function UIManager.getCurrentTab()
    return currentTab
end

function UIManager.showNotification(title, message, type)
    -- Modern notification system
    print("[TCE] Notification:", title, "-", message)
end

function UIManager.updateConnectionStatus(status)
    -- Update connection indicator
    local header = mainFrame and mainFrame:FindFirstChild("NavigationHeader")
    if header then
        local userSection = header:FindFirstChild("UserSection")
        local connectionStatus = userSection and userSection:FindFirstChild("ConnectionStatus")
        if connectionStatus then
            connectionStatus.BackgroundColor3 = status.isConnected and UIUtilities.CONSTANTS.COLORS.SUCCESS or UIUtilities.CONSTANTS.COLORS.ERROR
        end
    end
end

return UIManager 