-- src/shared/modules/UIManager/init.lua
-- Lightweight UI coordinator that manages panel modules

local UIManager = {}

-- Services
local RunService = game:GetService("RunService")

-- Import UI modules
local UIUtilities = require(script.UIUtilities)
local TasksPanel = require(script.TasksPanel)

-- Local variables
local dockWidget = nil
local mainFrame = nil
local currentTab = "overview"
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

-- Progress tracking
local progressData = {
    sessionStartTime = 0,
    editCounts = {
        scripts = 0,
        builds = 0,
        assets = 0
    },
    currentSelection = nil,
    recentActivity = {},
    userActivity = {}
}

function UIManager.initialize(widget, modules)
    print("[TCE] UIManager initializing...")
    
    dockWidget = widget
    PermissionManager = modules.PermissionManager
    AssetLockManager = modules.AssetLockManager
    ConnectionMonitor = modules.ConnectionMonitor
    NotificationManager = modules.NotificationManager
    ConflictResolver = modules.ConflictResolver
    TaskManager = modules.TaskManager
    
    -- Initialize panel modules
    TasksPanel.initialize({
        TaskManager = TaskManager,
        ConnectionMonitor = ConnectionMonitor,
        NotificationManager = NotificationManager,
        UIUtilities = UIUtilities,
        dockWidget = dockWidget
    })
    
    UIManager.createUI()
    UIManager.startAutoRefresh()
    
    -- Initialize progress tracking
    progressData.sessionStartTime = os.time()
    
    print("[TCE] UIManager initialized successfully")
    return true
end

function UIManager.createUI()
    -- Create main container
    mainFrame = UIUtilities.createRoundedFrame(dockWidget, {
        Name = "TCE_MainFrame",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG
    })
    
    -- Create tab system
    local tabContainer = UIManager.createTabSystem(mainFrame)
    
    -- Create content area
    local contentArea = UIUtilities.createRoundedFrame(mainFrame, {
        Name = "ContentArea",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    -- Create all panels (initially hidden)
    contentPanels = {
        overview = UIManager.createOverviewPanel(contentArea),
        progress = UIManager.createProgressPanel(contentArea),
        tasks = TasksPanel.createPanel(contentArea),
        permissions = UIManager.createPermissionsPanel(contentArea),
        assets = UIManager.createAssetsPanel(contentArea),
        notifications = UIManager.createNotificationsPanel(contentArea),
        settings = UIManager.createSettingsPanel(contentArea)
    }
    
    -- Show initial tab
    UIManager.switchTab("overview")
end

function UIManager.createTabSystem(parent)
    local tabContainer = UIUtilities.createRoundedFrame(parent, {
        Name = "TabContainer",
        Size = UDim2.new(1, -20, 0, 50),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true
    })
    
    tabButtons = {}
    local tabs = {
        {id = "overview", text = "Overview", icon = "🏠"},
        {id = "progress", text = "Progress", icon = "🚦"},
        {id = "tasks", text = "Tasks", icon = "📋"},
        {id = "permissions", text = "Permissions", icon = "🔐"},
        {id = "assets", text = "Assets", icon = "🎯"},
        {id = "notifications", text = "Notifications", icon = "🔔"},
        {id = "settings", text = "Settings", icon = "⚙️"}
    }
    
    for i, tab in ipairs(tabs) do
        local tabWidth = 1 / #tabs
        local button = UIUtilities.createStyledButton(tabContainer, {
            Name = tab.id .. "Tab",
            Text = tab.icon .. " " .. tab.text,
            Size = UDim2.new(tabWidth, -4, 1, -10),
            Position = UDim2.new((i-1) * tabWidth, 2, 0, 5),
            BackgroundColor3 = currentTab == tab.id and UIUtilities.CONSTANTS.COLORS.ACCENT_PURPLE or UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
        })
        
        button.MouseButton1Click:Connect(function()
            UIManager.switchTab(tab.id)
        end)
        
        tabButtons[tab.id] = button
    end
    
    return tabContainer
end

function UIManager.switchTab(tabId)
    currentTab = tabId
    
    -- Update tab button appearance
    for id, button in pairs(tabButtons) do
        button.BackgroundColor3 = id == tabId and UIUtilities.CONSTANTS.COLORS.ACCENT_PURPLE or UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    end
    
    -- Show/hide panels
    for id, panel in pairs(contentPanels) do
        panel.Visible = id == tabId
    end
    
    -- Refresh current panel
    UIManager.refreshCurrentTab()
end

function UIManager.refreshCurrentTab()
    if currentTab == "overview" then
        UIManager.refreshOverview()
    elseif currentTab == "progress" then
        UIManager.refreshProgress()
    elseif currentTab == "tasks" then
        TasksPanel.refreshTasks()
    elseif currentTab == "assets" then
        UIManager.refreshAssets()
    elseif currentTab == "notifications" then
        UIManager.refreshNotifications()
    end
end

function UIManager.createOverviewPanel(parent)
    local panel = UIUtilities.createRoundedFrame(parent, {
        Name = "OverviewPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    -- Connection Status Card
    local statusCard = UIUtilities.createRoundedFrame(panel, {
        Name = "StatusCard",
        Size = UDim2.new(1, -20, 0, 80),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true
    })
    
    local statusTitle = Instance.new("TextLabel")
    statusTitle.Name = "StatusTitle"
    statusTitle.Parent = statusCard
    statusTitle.Size = UDim2.new(1, -20, 0, 25)
    statusTitle.Position = UDim2.new(0, 10, 0, 5)
    statusTitle.BackgroundTransparency = 1
    statusTitle.Text = "🔗 Team Create Status"
    statusTitle.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    statusTitle.TextScaled = true
    statusTitle.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local statusInfo = Instance.new("TextLabel")
    statusInfo.Name = "StatusInfo"
    statusInfo.Parent = statusCard
    statusInfo.Size = UDim2.new(1, -20, 0, 45)
    statusInfo.Position = UDim2.new(0, 10, 0, 30)
    statusInfo.BackgroundTransparency = 1
    statusInfo.Text = "Status: Connected\nQuality: Good\nUsers: 1"
    statusInfo.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    statusInfo.TextScaled = true
    statusInfo.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    statusInfo.TextXAlignment = Enum.TextXAlignment.Left
    statusInfo.TextYAlignment = Enum.TextYAlignment.Top
    
    -- Recent Activity Card
    local activityCard = UIUtilities.createRoundedFrame(panel, {
        Name = "ActivityCard",
        Size = UDim2.new(1, -20, 1, -110),
        Position = UDim2.new(0, 10, 0, 100),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true
    })
    
    local activityTitle = Instance.new("TextLabel")
    activityTitle.Name = "ActivityTitle"
    activityTitle.Parent = activityCard
    activityTitle.Size = UDim2.new(1, -20, 0, 30)
    activityTitle.Position = UDim2.new(0, 10, 0, 5)
    activityTitle.BackgroundTransparency = 1
    activityTitle.Text = "📊 Recent Activity"
    activityTitle.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    activityTitle.TextScaled = true
    activityTitle.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    activityTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local activityList = UIUtilities.createScrollFrame(activityCard, {
        Name = "ActivityList",
        Size = UDim2.new(1, -20, 1, -45),
        Position = UDim2.new(0, 10, 0, 35)
    })
    
    return panel
end

function UIManager.createProgressPanel(parent)
    local panel = UIUtilities.createRoundedFrame(parent, {
        Name = "ProgressPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    -- Session Timer
    local timerCard = UIUtilities.createRoundedFrame(panel, {
        Name = "TimerCard",
        Size = UDim2.new(0.48, 0, 0, 100),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true
    })
    
    local timerTitle = Instance.new("TextLabel")
    timerTitle.Parent = timerCard
    timerTitle.Size = UDim2.new(1, -20, 0, 30)
    timerTitle.Position = UDim2.new(0, 10, 0, 5)
    timerTitle.BackgroundTransparency = 1
    timerTitle.Text = "⏱️ Session Timer"
    timerTitle.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    timerTitle.TextScaled = true
    timerTitle.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    timerTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local timerDisplay = Instance.new("TextLabel")
    timerDisplay.Name = "TimerDisplay"
    timerDisplay.Parent = timerCard
    timerDisplay.Size = UDim2.new(1, -20, 0, 40)
    timerDisplay.Position = UDim2.new(0, 10, 0, 35)
    timerDisplay.BackgroundTransparency = 1
    timerDisplay.Text = "00:00:00"
    timerDisplay.TextColor3 = UIUtilities.CONSTANTS.COLORS.ACCENT_TEAL
    timerDisplay.TextScaled = true
    timerDisplay.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    timerDisplay.TextXAlignment = Enum.TextXAlignment.Center
    
    local resetButton = UIUtilities.createStyledButton(timerCard, {
        Name = "ResetButton",
        Text = "🔄 Reset",
        Size = UDim2.new(0, 60, 0, 20),
        Position = UDim2.new(1, -70, 0, 75),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
    })
    
    resetButton.MouseButton1Click:Connect(function()
        progressData.sessionStartTime = os.time()
        progressData.editCounts = {scripts = 0, builds = 0, assets = 0}
    end)
    
    return panel
end

function UIManager.createPermissionsPanel(parent)
    local panel = UIUtilities.createRoundedFrame(parent, {
        Name = "PermissionsPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, 0, 0, 50)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🔐 Permissions Management"
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    return panel
end

function UIManager.createAssetsPanel(parent)
    local panel = UIUtilities.createRoundedFrame(parent, {
        Name = "AssetsPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, 0, 0, 50)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🎯 Asset Management"
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    return panel
end

function UIManager.createNotificationsPanel(parent)
    local panel = UIUtilities.createRoundedFrame(parent, {
        Name = "NotificationsPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, 0, 0, 50)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🔔 Notifications"
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    return panel
end

function UIManager.createSettingsPanel(parent)
    local panel = UIUtilities.createRoundedFrame(parent, {
        Name = "SettingsPanel",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, 0, 0, 50)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "⚙️ Settings"
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    return panel
end

function UIManager.refreshOverview()
    if not contentPanels.overview then return end
    
    local statusCard = contentPanels.overview:FindFirstChild("StatusCard")
    if statusCard then
        local statusInfo = statusCard:FindFirstChild("StatusInfo")
        if statusInfo and ConnectionMonitor then
            local status = ConnectionMonitor.getStatus()
            local activeUsers = ConnectionMonitor.getActiveUsers()
            statusInfo.Text = string.format("Status: %s\nQuality: %s\nUsers: %d", 
                status.connected and "Connected" or "Disconnected",
                status.quality or "Unknown",
                #activeUsers)
        end
    end
end

function UIManager.refreshProgress()
    if not contentPanels.progress then return end
    
    local timerCard = contentPanels.progress:FindFirstChild("TimerCard")
    if timerCard then
        local timerDisplay = timerCard:FindFirstChild("TimerDisplay")
        if timerDisplay then
            local currentTime = os.time()
            local sessionDuration = currentTime - progressData.sessionStartTime
            local hours = math.floor(sessionDuration / 3600)
            local minutes = math.floor((sessionDuration % 3600) / 60)
            local seconds = sessionDuration % 60
            timerDisplay.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        end
    end
end

function UIManager.refreshAssets()
    -- Asset refresh logic here
end

function UIManager.refreshNotifications()
    -- Notification refresh logic here
end

function UIManager.startAutoRefresh()
    if refreshConnection then
        refreshConnection:Disconnect()
    end
    
    refreshConnection = RunService.Heartbeat:Connect(function()
        local currentTime = os.time()
        if currentTime - lastRefreshTime >= REFRESH_INTERVAL then
            lastRefreshTime = currentTime
            UIManager.refreshCurrentTab()
        end
    end)
end

function UIManager.cleanup()
    if refreshConnection then
        refreshConnection:Disconnect()
        refreshConnection = nil
    end
    
    if mainFrame then
        mainFrame:Destroy()
        mainFrame = nil
    end
end

return UIManager 