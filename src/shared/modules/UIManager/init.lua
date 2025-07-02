-- src/shared/modules/UIManager/init.lua
-- Handles all UI creation and management for the Team Create Enhancement Plugin

--[[
UIManager
=========
Manages all UI components for Team Create Enhancer plugin.
Provides APIs for creating panels, managing tabs, and updating dynamic content.
Follows the PRD style guide with modern dark theme and responsive design.
Integrates with all backend modules for live data updates.
]]

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

-- Module references (will be injected)
local PermissionManager = nil
local AssetLockManager = nil
local ConnectionMonitor = nil
local NotificationManager = nil

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
        {id = "overview", text = "Overview", icon = "��"},
        {id = "progress", text = "Progress", icon = "🚦"},
        {id = "permissions", text = "Permissions", icon = "🔐"},
        {id = "assets", text = "Assets", icon = "🎯"},
        {id = "notifications", text = "Notifications", icon = "🔔"},
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
    
    local qualityLabel = Instance.new("TextLabel")
    qualityLabel.Name = "QualityLabel"
    qualityLabel.Parent = statusFrame
    qualityLabel.Size = UDim2.new(1, -50, 0, 20)
    qualityLabel.Position = UDim2.new(0, 40, 0, 40)
    qualityLabel.BackgroundTransparency = 1
    qualityLabel.Text = "Quality: Excellent"
    qualityLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    qualityLabel.TextScaled = true
    qualityLabel.Font = UI_CONSTANTS.FONTS.MAIN
    qualityLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Active Users
    local usersFrame = createRoundedFrame(panel, {
        Name = "ActiveUsers",
        Size = UDim2.new(0.48, 0, 0, 120),
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
    
    -- Current Statistics
    local statsFrame = createRoundedFrame(panel, {
        Name = "Statistics",
        Size = UDim2.new(0.48, 0, 0, 120),
        Position = UDim2.new(0.52, 0, 0, 100)
    })
    
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "StatsLabel"
    statsLabel.Parent = statsFrame
    statsLabel.Size = UDim2.new(1, -20, 0, 30)
    statsLabel.Position = UDim2.new(0, 10, 0, 10)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "Session Stats"
    statsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    statsLabel.TextScaled = true
    statsLabel.Font = UI_CONSTANTS.FONTS.HEADER
    statsLabel.TextXAlignment = Enum.TextXAlignment.Left
    
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

local function createPermissionsPanel(parent)
    local panel = createRoundedFrame(parent, {
        Name = "PermissionsPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🔐 Role-Based Permissions"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Current User Role
    local myRoleFrame = createRoundedFrame(panel, {
        Name = "MyRole",
        Size = UDim2.new(1, -20, 0, 60),
        Position = UDim2.new(0, 10, 0, 60),
        Glow = true,
        GlowColor = UI_CONSTANTS.COLORS.ACCENT_PURPLE
    })
    
    local myRoleLabel = Instance.new("TextLabel")
    myRoleLabel.Name = "MyRoleLabel"
    myRoleLabel.Parent = myRoleFrame
    myRoleLabel.Size = UDim2.new(1, -20, 0, 25)
    myRoleLabel.Position = UDim2.new(0, 10, 0, 5)
    myRoleLabel.BackgroundTransparency = 1
    myRoleLabel.Text = "Your Role: Developer"
    myRoleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    myRoleLabel.TextScaled = true
    myRoleLabel.Font = UI_CONSTANTS.FONTS.MAIN
    myRoleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local myPermissionsLabel = Instance.new("TextLabel")
    myPermissionsLabel.Name = "MyPermissionsLabel"
    myPermissionsLabel.Parent = myRoleFrame
    myPermissionsLabel.Size = UDim2.new(1, -20, 0, 25)
    myPermissionsLabel.Position = UDim2.new(0, 10, 0, 30)
    myPermissionsLabel.BackgroundTransparency = 1
    myPermissionsLabel.Text = "Permissions: Script Edit, Build Edit, Asset Lock"
    myPermissionsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    myPermissionsLabel.TextScaled = true
    myPermissionsLabel.Font = UI_CONSTANTS.FONTS.MAIN
    myPermissionsLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Role Management (for admins)
    local roleManagementFrame = createRoundedFrame(panel, {
        Name = "RoleManagement",
        Size = UDim2.new(1, -20, 1, -140),
        Position = UDim2.new(0, 10, 0, 130)
    })
    
    local roleManagementLabel = Instance.new("TextLabel")
    roleManagementLabel.Name = "RoleManagementLabel"
    roleManagementLabel.Parent = roleManagementFrame
    roleManagementLabel.Size = UDim2.new(1, -20, 0, 30)
    roleManagementLabel.Position = UDim2.new(0, 10, 0, 10)
    roleManagementLabel.BackgroundTransparency = 1
    roleManagementLabel.Text = "Team Role Management"
    roleManagementLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    roleManagementLabel.TextScaled = true
    roleManagementLabel.Font = UI_CONSTANTS.FONTS.HEADER
    roleManagementLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

local function createAssetsPanel(parent)
    local panel = createRoundedFrame(parent, {
        Name = "AssetsPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🎯 Asset Lock Management"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Currently Locked Assets
    local lockedFrame = createRoundedFrame(panel, {
        Name = "LockedAssets",
        Size = UDim2.new(1, -20, 0, 200),
        Position = UDim2.new(0, 10, 0, 60)
    })
    
    local lockedLabel = Instance.new("TextLabel")
    lockedLabel.Name = "LockedLabel"
    lockedLabel.Parent = lockedFrame
    lockedLabel.Size = UDim2.new(1, -20, 0, 30)
    lockedLabel.Position = UDim2.new(0, 10, 0, 10)
    lockedLabel.BackgroundTransparency = 1
    lockedLabel.Text = "Currently Locked Assets"
    lockedLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    lockedLabel.TextScaled = true
    lockedLabel.Font = UI_CONSTANTS.FONTS.MAIN
    lockedLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Asset Actions
    local actionsFrame = createRoundedFrame(panel, {
        Name = "AssetActions",
        Size = UDim2.new(1, -20, 0, 80),
        Position = UDim2.new(0, 10, 0, 270)
    })
    
    local actionsLabel = Instance.new("TextLabel")
    actionsLabel.Name = "ActionsLabel"
    actionsLabel.Parent = actionsFrame
    actionsLabel.Size = UDim2.new(1, -20, 0, 30)
    actionsLabel.Position = UDim2.new(0, 10, 0, 10)
    actionsLabel.BackgroundTransparency = 1
    actionsLabel.Text = "Asset Actions"
    actionsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    actionsLabel.TextScaled = true
    actionsLabel.Font = UI_CONSTANTS.FONTS.MAIN
    actionsLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local lockSelectedButton = createStyledButton(actionsFrame, {
        Name = "LockSelectedButton",
        Text = "🔒 Lock Selected",
        Size = UDim2.new(0, 140, 0, 30),
        Position = UDim2.new(0, 10, 0, 40),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_BLUE
    })
    
    local unlockAllButton = createStyledButton(actionsFrame, {
        Name = "UnlockAllButton", 
        Text = "🔓 Unlock My Assets",
        Size = UDim2.new(0, 140, 0, 30),
        Position = UDim2.new(0, 160, 0, 40),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
    })
    
    -- Conflict Status
    local conflictFrame = createRoundedFrame(panel, {
        Name = "ConflictStatus",
        Size = UDim2.new(1, -20, 1, -370),
        Position = UDim2.new(0, 10, 0, 360)
    })
    
    local conflictLabel = Instance.new("TextLabel")
    conflictLabel.Name = "ConflictLabel"
    conflictLabel.Parent = conflictFrame
    conflictLabel.Size = UDim2.new(1, -20, 0, 30)
    conflictLabel.Position = UDim2.new(0, 10, 0, 10)
    conflictLabel.BackgroundTransparency = 1
    conflictLabel.Text = "Edit Conflicts"
    conflictLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    conflictLabel.TextScaled = true
    conflictLabel.Font = UI_CONSTANTS.FONTS.MAIN
    conflictLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

local function createSettingsPanel(parent)
    local panel = createRoundedFrame(parent, {
        Name = "SettingsPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "⚙️ Plugin Settings"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Notification Settings
    local notificationFrame = createRoundedFrame(panel, {
        Name = "NotificationSettings",
        Size = UDim2.new(1, -20, 0, 100),
        Position = UDim2.new(0, 10, 0, 60)
    })
    
    local notificationLabel = Instance.new("TextLabel")
    notificationLabel.Name = "NotificationLabel"
    notificationLabel.Parent = notificationFrame
    notificationLabel.Size = UDim2.new(1, -20, 0, 30)
    notificationLabel.Position = UDim2.new(0, 10, 0, 10)
    notificationLabel.BackgroundTransparency = 1
    notificationLabel.Text = "Notification Settings"
    notificationLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    notificationLabel.TextScaled = true
    notificationLabel.Font = UI_CONSTANTS.FONTS.MAIN
    notificationLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local enableNotificationsButton = createStyledButton(notificationFrame, {
        Name = "EnableNotificationsButton",
        Text = "✅ Notifications Enabled",
        Size = UDim2.new(0, 180, 0, 30),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    })
    
    -- Connection Settings
    local connectionFrame = createRoundedFrame(panel, {
        Name = "ConnectionSettings",
        Size = UDim2.new(1, -20, 0, 100),
        Position = UDim2.new(0, 10, 0, 170)
    })
    
    local connectionLabel = Instance.new("TextLabel")
    connectionLabel.Name = "ConnectionLabel"
    connectionLabel.Parent = connectionFrame
    connectionLabel.Size = UDim2.new(1, -20, 0, 30)
    connectionLabel.Position = UDim2.new(0, 10, 0, 10)
    connectionLabel.BackgroundTransparency = 1
    connectionLabel.Text = "Connection Monitoring"
    connectionLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    connectionLabel.TextScaled = true
    connectionLabel.Font = UI_CONSTANTS.FONTS.MAIN
    connectionLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local monitoringButton = createStyledButton(connectionFrame, {
        Name = "MonitoringButton",
        Text = "✅ Monitoring Active",
        Size = UDim2.new(0, 160, 0, 30),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    })
    
    -- Plugin Info
    local infoFrame = createRoundedFrame(panel, {
        Name = "PluginInfo",
        Size = UDim2.new(1, -20, 1, -290),
        Position = UDim2.new(0, 10, 0, 280)
    })
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Parent = infoFrame
    infoLabel.Size = UDim2.new(1, -20, 0, 30)
    infoLabel.Position = UDim2.new(0, 10, 0, 10)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Plugin Information"
    infoLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    infoLabel.TextScaled = true
    infoLabel.Font = UI_CONSTANTS.FONTS.MAIN
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local versionLabel = Instance.new("TextLabel")
    versionLabel.Name = "VersionLabel"
    versionLabel.Parent = infoFrame
    versionLabel.Size = UDim2.new(1, -20, 0, 20)
    versionLabel.Position = UDim2.new(0, 10, 0, 50)
    versionLabel.BackgroundTransparency = 1
    versionLabel.Text = "Version: 1.0.0 (Compliance Mode)"
    versionLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    versionLabel.TextScaled = true
    versionLabel.Font = UI_CONSTANTS.FONTS.MAIN
    versionLabel.TextXAlignment = Enum.TextXAlignment.Left
    
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
    
    -- Recent Notifications
    local recentFrame = createRoundedFrame(panel, {
        Name = "RecentNotifications",
        Size = UDim2.new(1, -20, 1, -140),
        Position = UDim2.new(0, 10, 0, 130)
    })
    
    local recentLabel = Instance.new("TextLabel")
    recentLabel.Name = "RecentLabel"
    recentLabel.Parent = recentFrame
    recentLabel.Size = UDim2.new(1, -20, 0, 30)
    recentLabel.Position = UDim2.new(0, 10, 0, 10)
    recentLabel.BackgroundTransparency = 1
    recentLabel.Text = "Recent Activity"
    recentLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    recentLabel.TextScaled = true
    recentLabel.Font = UI_CONSTANTS.FONTS.MAIN
    recentLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

local function createProgressPanel(parent)
    local panel = createRoundedFrame(parent, {
        Name = "ProgressPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🚦 Progress Tracker"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    -- Live Edits Section
    local liveEditsFrame = createRoundedFrame(panel, {
        Name = "LiveEdits",
        Size = UDim2.new(1, -20, 0, 100),
        Position = UDim2.new(0, 10, 0, 60)
    })
    local liveEditsLabel = Instance.new("TextLabel")
    liveEditsLabel.Name = "LiveEditsLabel"
    liveEditsLabel.Parent = liveEditsFrame
    liveEditsLabel.Size = UDim2.new(1, -20, 0, 30)
    liveEditsLabel.Position = UDim2.new(0, 10, 0, 10)
    liveEditsLabel.BackgroundTransparency = 1
    liveEditsLabel.Text = "Live Edits (placeholder)"
    liveEditsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    liveEditsLabel.TextScaled = true
    liveEditsLabel.Font = UI_CONSTANTS.FONTS.MAIN
    liveEditsLabel.TextXAlignment = Enum.TextXAlignment.Left
    -- User Presence Section
    local presenceFrame = createRoundedFrame(panel, {
        Name = "UserPresence",
        Size = UDim2.new(1, -20, 0, 80),
        Position = UDim2.new(0, 10, 0, 170)
    })
    local presenceLabel = Instance.new("TextLabel")
    presenceLabel.Name = "PresenceLabel"
    presenceLabel.Parent = presenceFrame
    presenceLabel.Size = UDim2.new(1, -20, 0, 30)
    presenceLabel.Position = UDim2.new(0, 10, 0, 10)
    presenceLabel.BackgroundTransparency = 1
    presenceLabel.Text = "User Presence (placeholder)"
    presenceLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    presenceLabel.TextScaled = true
    presenceLabel.Font = UI_CONSTANTS.FONTS.MAIN
    presenceLabel.TextXAlignment = Enum.TextXAlignment.Left
    -- Activity Timeline Section
    local timelineFrame = createRoundedFrame(panel, {
        Name = "ActivityTimeline",
        Size = UDim2.new(1, -20, 1, -270),
        Position = UDim2.new(0, 10, 0, 260)
    })
    local timelineLabel = Instance.new("TextLabel")
    timelineLabel.Name = "TimelineLabel"
    timelineLabel.Parent = timelineFrame
    timelineLabel.Size = UDim2.new(1, -20, 0, 30)
    timelineLabel.Position = UDim2.new(0, 10, 0, 10)
    timelineLabel.BackgroundTransparency = 1
    timelineLabel.Text = "Activity Timeline (placeholder)"
    timelineLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    timelineLabel.TextScaled = true
    timelineLabel.Font = UI_CONSTANTS.FONTS.MAIN
    timelineLabel.TextXAlignment = Enum.TextXAlignment.Left
    return panel
end

-- Public API
--[[
Initializes the UIManager with dock widget and UI constants.
Creates all UI panels and sets up the tab system.
@param widget DockWidgetPluginGui: The plugin dock widget
@param constants table: UI constants (colors, fonts, sizes)
]]
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
    contentPanels.permissions = createPermissionsPanel(mainFrame)
    contentPanels.assets = createAssetsPanel(mainFrame)
    contentPanels.notifications = createNotificationsPanel(mainFrame)
    contentPanels.settings = createSettingsPanel(mainFrame)
    contentPanels.progress = createProgressPanel(mainFrame)
    
    -- Hide all panels except overview
    for id, panel in pairs(contentPanels) do
        panel.Visible = (id == currentTab)
    end
    
    print("[TCE] UI initialized with all panels - compliant design")
end

--[[
Sets module references for cross-integration with backend systems.
@param modules table: Table of module references
]]
function UIManager.setModuleReferences(modules)
    PermissionManager = modules.PermissionManager
    AssetLockManager = modules.AssetLockManager
    ConnectionMonitor = modules.ConnectionMonitor
    NotificationManager = modules.NotificationManager
    
    print("[TCE] UI module references set")
end

--[[
Switches to a specific tab and updates appearance.
@param tabId string: The tab identifier to switch to
]]
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

--[[
Refreshes UI content based on current tab and backend data.
]]
function UIManager.refresh()
    print("[TCE] Refreshing UI...")
    if currentTab == "overview" then
        UIManager.refreshOverview()
    elseif currentTab == "progress" then
        -- Placeholder for future live data refresh
    elseif currentTab == "permissions" then
        UIManager.refreshPermissions()
    elseif currentTab == "assets" then
        UIManager.refreshAssets()
    end
end

--[[
Refreshes the Overview panel with live connection and user data.
]]
function UIManager.refreshOverview()
    if ConnectionMonitor then
        local status = ConnectionMonitor.getConnectionStatus()
        UIManager.updateConnectionStatus(status.status, status.color)
    end
end

--[[
Refreshes the Permissions panel with current user role and team data.
]]
function UIManager.refreshPermissions()
    if PermissionManager and contentPanels.permissions then
        -- Update current user role display
        local myRoleFrame = contentPanels.permissions:FindFirstChild("MyRole")
        if myRoleFrame then
            local roleLabel = myRoleFrame:FindFirstChild("MyRoleLabel")
            local permissionsLabel = myRoleFrame:FindFirstChild("MyPermissionsLabel")
            
            if roleLabel and PermissionManager.getCurrentUserRole then
                local userRole = PermissionManager.getCurrentUserRole()
                roleLabel.Text = "Your Role: " .. (userRole or "Unknown")
            end
        end
    end
end

--[[
Refreshes the Assets panel with current lock information.
]]
function UIManager.refreshAssets()
    if AssetLockManager and contentPanels.assets then
        -- Update locked assets display
        local lockedFrame = contentPanels.assets:FindFirstChild("LockedAssets")
        if lockedFrame and AssetLockManager.getLockedAssets then
            local lockedAssets = AssetLockManager.getLockedAssets()
            local lockedLabel = lockedFrame:FindFirstChild("LockedLabel")
            if lockedLabel then
                lockedLabel.Text = "Currently Locked Assets (" .. #lockedAssets .. ")"
            end
        end
    end
end

--[[
Updates the connection status display in the Overview panel.
@param status string: Connection status
@param color Color3: Status indicator color
]]
function UIManager.updateConnectionStatus(status, color)
    if contentPanels.overview then
        local statusFrame = contentPanels.overview:FindFirstChild("ConnectionStatus")
        if statusFrame then
            local statusLabel = statusFrame:FindFirstChild("StatusLabel")
            local statusDot = statusFrame:FindFirstChild("StatusDot")
            local qualityLabel = statusFrame:FindFirstChild("QualityLabel")
            
            if statusLabel then
                statusLabel.Text = "Team Create: " .. status
            end
            
            if statusDot then
                statusDot.BackgroundColor3 = color
            end
            
            if qualityLabel then
                qualityLabel.Text = "Quality: " .. (status == "Connected" and "Excellent" or "Poor")
            end
        end
    end
end

--[[
Updates the active user list display in the Overview panel.
@param users table: List of active users
]]
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

--[[
Adds an activity log entry to the UI.
@param message string: Activity message
]]
function UIManager.addActivityLog(message)
    -- Add to internal activity feed
    print("[TCE] Activity:", message)
end

--[[
Shows a compliance mode notice to the user.
]]
function UIManager.showComplianceNotice()
    local notice = Instance.new("ScreenGui")
    notice.Name = "ComplianceNotice"
            if game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerGui then
            notice.Parent = game.Players.LocalPlayer.PlayerGui
        end
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

--[[
Cleans up the UIManager (destroys UI, clears references).
]]
function UIManager.cleanup()
    if mainFrame then
        mainFrame:Destroy()
        mainFrame = nil
    end
    contentPanels = {}
    tabButtons = {}
    print("[TCE] UI cleaned up")
end

return UIManager 