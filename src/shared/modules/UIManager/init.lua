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
        local button = createStyledButton(tabContainer, {
            Name = tab.id .. "Tab",
            Text = tab.icon .. " " .. tab.text,
            Size = UDim2.new(tabWidth, -4, 1, -10),
            Position = UDim2.new((i-1) * tabWidth, 2, 0, 5),
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
    
    -- Add click handler for Lock Selected button
    lockSelectedButton.MouseButton1Click:Connect(function()
        local Selection = game:GetService("Selection")
        local selected = Selection:Get()
        
        if #selected == 0 then
            if NotificationManager then
                NotificationManager.sendMessage("No Selection", "Please select an asset to lock", "WARNING")
            end
            return
        end
        
        local lockedCount = 0
        for _, instance in ipairs(selected) do
            if AssetLockManager then
                local success, message = AssetLockManager.lockAsset(instance, "manual")
                if success then
                    lockedCount = lockedCount + 1
                end
            end
        end
        
        if NotificationManager then
            if lockedCount > 0 then
                NotificationManager.sendMessage("Assets Locked", "Successfully locked " .. lockedCount .. " asset(s)", "SUCCESS")
            else
                NotificationManager.sendMessage("Lock Failed", "Could not lock selected assets", "ERROR")
            end
        end
        
        -- Refresh assets panel
        if currentTab == "assets" then
            UIManager.refreshAssets()
        end
    end)
    
    local unlockAllButton = createStyledButton(actionsFrame, {
        Name = "UnlockAllButton", 
        Text = "🔓 Unlock My Assets",
        Size = UDim2.new(0, 140, 0, 30),
        Position = UDim2.new(0, 160, 0, 40),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
    })
    
    -- Add click handler for Unlock All button
    unlockAllButton.MouseButton1Click:Connect(function()
        if AssetLockManager then
            local unlockedCount = AssetLockManager.unlockAllUserAssets()
            
            if NotificationManager then
                if unlockedCount > 0 then
                    NotificationManager.sendMessage("Assets Unlocked", "Unlocked " .. unlockedCount .. " of your assets", "SUCCESS")
                else
                    NotificationManager.sendMessage("No Assets", "You have no locked assets to unlock", "INFO")
                end
            end
            
            -- Refresh assets panel
            if currentTab == "assets" then
                UIManager.refreshAssets()
            end
        end
    end)
    
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
    
    -- Title with session info
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(0.7, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🚦 Progress Tracker"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Session time display
    local sessionTimeLabel = Instance.new("TextLabel")
    sessionTimeLabel.Name = "SessionTimeLabel"
    sessionTimeLabel.Parent = panel
    sessionTimeLabel.Size = UDim2.new(0.2, 0, 0, 40)
    sessionTimeLabel.Position = UDim2.new(0.5, 0, 0, 10)
    sessionTimeLabel.BackgroundTransparency = 1
    sessionTimeLabel.Text = "Session: 0:00"
    sessionTimeLabel.TextColor3 = UI_CONSTANTS.COLORS.ACCENT_TEAL
    sessionTimeLabel.TextScaled = true
    sessionTimeLabel.Font = UI_CONSTANTS.FONTS.MAIN
    sessionTimeLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Reset button
    local resetButton = createStyledButton(panel, {
        Name = "ResetButton",
        Text = "🔄 Reset Session",
        Size = UDim2.new(0.3, -10, 0, 30),
        Position = UDim2.new(0.7, 0, 0, 15),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
    })
    
    -- Add click handler for reset button
    resetButton.MouseButton1Click:Connect(function()
        UIManager.resetProgressData()
        -- Refresh immediately to show reset data
        if currentTab == "progress" then
            UIManager.refreshProgress()
        end
    end)
    
    -- Live Edits Section
    local liveEditsFrame = createRoundedFrame(panel, {
        Name = "LiveEdits",
        Size = UDim2.new(1, -20, 0, 120),
        Position = UDim2.new(0, 10, 0, 60)
    })
    
    local liveEditsLabel = Instance.new("TextLabel")
    liveEditsLabel.Name = "LiveEditsLabel"
    liveEditsLabel.Parent = liveEditsFrame
    liveEditsLabel.Size = UDim2.new(1, -20, 0, 25)
    liveEditsLabel.Position = UDim2.new(0, 10, 0, 5)
    liveEditsLabel.BackgroundTransparency = 1
    liveEditsLabel.Text = "🎯 Live Editing Activity"
    liveEditsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    liveEditsLabel.TextScaled = true
    liveEditsLabel.Font = UI_CONSTANTS.FONTS.MAIN
    liveEditsLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Live edits stats
    local editsStatsFrame = Instance.new("Frame")
    editsStatsFrame.Name = "EditsStats"
    editsStatsFrame.Parent = liveEditsFrame
    editsStatsFrame.Size = UDim2.new(1, -20, 0, 30)
    editsStatsFrame.Position = UDim2.new(0, 10, 0, 30)
    editsStatsFrame.BackgroundTransparency = 1
    
    local function createStatLabel(parent, name, text, position, color)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Parent = parent
        label.Size = UDim2.new(0.33, -5, 1, 0)
        label.Position = position
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color
        label.TextScaled = true
        label.Font = UI_CONSTANTS.FONTS.MAIN
        label.TextXAlignment = Enum.TextXAlignment.Center
        return label
    end
    
    createStatLabel(editsStatsFrame, "ScriptEdits", "Scripts: 0", UDim2.new(0, 0, 0, 0), UI_CONSTANTS.COLORS.ACCENT_BLUE)
    createStatLabel(editsStatsFrame, "BuildEdits", "Builds: 0", UDim2.new(0.33, 0, 0, 0), UI_CONSTANTS.COLORS.ACCENT_PURPLE)
    createStatLabel(editsStatsFrame, "AssetEdits", "Assets: 0", UDim2.new(0.66, 0, 0, 0), UI_CONSTANTS.COLORS.ACCENT_MAGENTA)
    
    -- Current editor display
    local currentEditorLabel = Instance.new("TextLabel")
    currentEditorLabel.Name = "CurrentEditorLabel"
    currentEditorLabel.Parent = liveEditsFrame
    currentEditorLabel.Size = UDim2.new(1, -20, 0, 25)
    currentEditorLabel.Position = UDim2.new(0, 10, 0, 65)
    currentEditorLabel.BackgroundTransparency = 1
    currentEditorLabel.Text = "Currently editing: No selection"
    currentEditorLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    currentEditorLabel.TextScaled = true
    currentEditorLabel.Font = UI_CONSTANTS.FONTS.MAIN
    currentEditorLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- User Presence Section
    local presenceFrame = createRoundedFrame(panel, {
        Name = "UserPresence",
        Size = UDim2.new(1, -20, 0, 100),
        Position = UDim2.new(0, 10, 0, 190)
    })
    
    local presenceLabel = Instance.new("TextLabel")
    presenceLabel.Name = "PresenceLabel"
    presenceLabel.Parent = presenceFrame
    presenceLabel.Size = UDim2.new(1, -20, 0, 25)
    presenceLabel.Position = UDim2.new(0, 10, 0, 5)
    presenceLabel.BackgroundTransparency = 1
    presenceLabel.Text = "👥 Team Presence"
    presenceLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    presenceLabel.TextScaled = true
    presenceLabel.Font = UI_CONSTANTS.FONTS.MAIN
    presenceLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Activity Timeline Section
    local timelineFrame = createRoundedFrame(panel, {
        Name = "ActivityTimeline",
        Size = UDim2.new(1, -20, 1, -310),
        Position = UDim2.new(0, 10, 0, 300)
    })
    
    local timelineLabel = Instance.new("TextLabel")
    timelineLabel.Name = "TimelineLabel"
    timelineLabel.Parent = timelineFrame
    timelineLabel.Size = UDim2.new(1, -20, 0, 25)
    timelineLabel.Position = UDim2.new(0, 10, 0, 5)
    timelineLabel.BackgroundTransparency = 1
    timelineLabel.Text = "📈 Activity Timeline"
    timelineLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    timelineLabel.TextScaled = true
    timelineLabel.Font = UI_CONSTANTS.FONTS.MAIN
    timelineLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    return panel
end

local function createTasksPanel(parent)
    local panel = createRoundedFrame(parent, {
        Name = "TasksPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    
    -- Title with task stats
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = panel
    titleLabel.Size = UDim2.new(0.5, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "📋 Task Management"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Quick stats
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "StatsLabel"
    statsLabel.Parent = panel
    statsLabel.Size = UDim2.new(0.3, 0, 0, 40)
    statsLabel.Position = UDim2.new(0.5, 0, 0, 10)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "Total: 0 | Mine: 0"
    statsLabel.TextColor3 = UI_CONSTANTS.COLORS.ACCENT_TEAL
    statsLabel.TextScaled = true
    statsLabel.Font = UI_CONSTANTS.FONTS.MAIN
    statsLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- New Task Button
    local newTaskButton = createStyledButton(panel, {
        Name = "NewTaskButton",
        Text = "➕ New Task",
        Size = UDim2.new(0.2, -5, 0, 30),
        Position = UDim2.new(0.8, 0, 0, 15),
        BackgroundColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    })
    
    -- Add click handler for new task button
    newTaskButton.MouseButton1Click:Connect(function()
        UIManager.showNewTaskDialog()
    end)
    
    -- Task Filter Section
    local filterFrame = createRoundedFrame(panel, {
        Name = "TaskFilters",
        Size = UDim2.new(1, -20, 0, 80),
        Position = UDim2.new(0, 10, 0, 60)
    })
    
    local filterLabel = Instance.new("TextLabel")
    filterLabel.Name = "FilterLabel"
    filterLabel.Parent = filterFrame
    filterLabel.Size = UDim2.new(0.2, 0, 0, 25)
    filterLabel.Position = UDim2.new(0, 10, 0, 5)
    filterLabel.BackgroundTransparency = 1
    filterLabel.Text = "🔍 Filters:"
    filterLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    filterLabel.TextScaled = true
    filterLabel.Font = UI_CONSTANTS.FONTS.MAIN
    filterLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Filter buttons row
    local filterButtons = {}
    local filters = {
        {id = "all", text = "All", color = UI_CONSTANTS.COLORS.SECONDARY_BG},
        {id = "mine", text = "My Tasks", color = UI_CONSTANTS.COLORS.ACCENT_BLUE},
        {id = "todo", text = "To Do", color = UI_CONSTANTS.COLORS.ACCENT_PURPLE},
        {id = "inprogress", text = "In Progress", color = UI_CONSTANTS.COLORS.ACCENT_TEAL},
        {id = "overdue", text = "Overdue", color = UI_CONSTANTS.COLORS.ERROR_RED}
    }
    
    for i, filter in ipairs(filters) do
        local button = createStyledButton(filterFrame, {
            Name = filter.id .. "Filter",
            Text = filter.text,
            Size = UDim2.new(0.18, -2, 0, 25),
            Position = UDim2.new(0.2 + (i-1) * 0.16, 2, 0, 5),
            BackgroundColor3 = filter.color
        })
        filterButtons[filter.id] = button
    end
    
    -- Priority/Type filters row
    local priorityLabel = Instance.new("TextLabel")
    priorityLabel.Name = "PriorityLabel"
    priorityLabel.Parent = filterFrame
    priorityLabel.Size = UDim2.new(0.2, 0, 0, 25)
    priorityLabel.Position = UDim2.new(0, 10, 0, 35)
    priorityLabel.BackgroundTransparency = 1
    priorityLabel.Text = "Priority:"
    priorityLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    priorityLabel.TextScaled = true
    priorityLabel.Font = UI_CONSTANTS.FONTS.MAIN
    priorityLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local priorities = {"Critical", "High", "Medium", "Low"}
    for i, priority in ipairs(priorities) do
        local color = UI_CONSTANTS.COLORS.SECONDARY_BG
        if priority == "Critical" then color = UI_CONSTANTS.COLORS.ERROR_RED
        elseif priority == "High" then color = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
        elseif priority == "Medium" then color = UI_CONSTANTS.COLORS.ACCENT_BLUE
        end
        
        local button = createStyledButton(filterFrame, {
            Name = priority .. "Priority",
            Text = priority,
            Size = UDim2.new(0.18, -2, 0, 25),
            Position = UDim2.new(0.2 + (i-1) * 0.16, 2, 0, 35),
            BackgroundColor3 = color
        })
        filterButtons[priority:lower()] = button
    end
    
    -- Active Tasks List
    local tasksListFrame = createRoundedFrame(panel, {
        Name = "TasksList",
        Size = UDim2.new(1, -20, 1, -160),
        Position = UDim2.new(0, 10, 0, 150)
    })
    
    local tasksScrollFrame = Instance.new("ScrollingFrame")
    tasksScrollFrame.Name = "TasksScroll"
    tasksScrollFrame.Parent = tasksListFrame
    tasksScrollFrame.Size = UDim2.new(1, -10, 1, -35)
    tasksScrollFrame.Position = UDim2.new(0, 5, 0, 30)
    tasksScrollFrame.BackgroundTransparency = 1
    tasksScrollFrame.BorderSizePixel = 0
    tasksScrollFrame.ScrollBarThickness = 6
    tasksScrollFrame.ScrollBarImageColor3 = UI_CONSTANTS.COLORS.ACCENT_BLUE
    tasksScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    local tasksListLabel = Instance.new("TextLabel")
    tasksListLabel.Name = "TasksListLabel"
    tasksListLabel.Parent = tasksListFrame
    tasksListLabel.Size = UDim2.new(1, -20, 0, 25)
    tasksListLabel.Position = UDim2.new(0, 10, 0, 5)
    tasksListLabel.BackgroundTransparency = 1
    tasksListLabel.Text = "📝 Active Tasks (0)"
    tasksListLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    tasksListLabel.TextScaled = true
    tasksListLabel.Font = UI_CONSTANTS.FONTS.MAIN
    tasksListLabel.TextXAlignment = Enum.TextXAlignment.Left
    
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
    contentPanels.tasks = createTasksPanel(mainFrame)
    
    -- Hide all panels except overview
    for id, panel in pairs(contentPanels) do
        panel.Visible = (id == currentTab)
    end
    
    -- Initialize progress tracking
    progressData.sessionStartTime = os.time()
    
    -- Set up selection change monitoring for progress tracking
    local Selection = game:GetService("Selection")
    Selection.SelectionChanged:Connect(function()
        local selected = Selection:Get()
        if #selected > 0 then
            local selectedItem = selected[1]
            
            -- Track edit based on selection type
            if selectedItem:IsA("Script") or selectedItem:IsA("LocalScript") or selectedItem:IsA("ModuleScript") then
                UIManager.trackEdit("script")
            elseif selectedItem:IsA("Part") or selectedItem:IsA("Model") or selectedItem:IsA("MeshPart") then
                UIManager.trackEdit("build")
            else
                UIManager.trackEdit("asset")
            end
            
            -- Create notification for activity
            if NotificationManager then
                NotificationManager.sendMessage("Selection Changed", 
                    string.format("Now editing: %s", selectedItem.Name), "INFO")
            end
        end
    end)
    
    -- Start auto-refresh
    UIManager.startAutoRefresh()
    
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
    ConflictResolver = modules.ConflictResolver
    TaskManager = modules.TaskManager
    
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
        UIManager.refreshProgress()
    elseif currentTab == "tasks" then
        UIManager.refreshTasks()
    elseif currentTab == "permissions" then
        UIManager.refreshPermissions()
    elseif currentTab == "assets" then
        UIManager.refreshAssets()
    elseif currentTab == "notifications" then
        UIManager.refreshNotifications()
    end
    lastRefreshTime = os.time()
end

--[[
Starts auto-refresh of UI content every REFRESH_INTERVAL seconds.
]]
function UIManager.startAutoRefresh()
    if refreshConnection then
        return -- Already running
    end
    
    refreshConnection = RunService.Heartbeat:Connect(function()
        if os.time() - lastRefreshTime >= REFRESH_INTERVAL then
            UIManager.refresh()
        end
    end)
    
    print("[TCE] Auto-refresh started (", REFRESH_INTERVAL, "s interval)")
end

--[[
Stops auto-refresh of UI content.
]]
function UIManager.stopAutoRefresh()
    if refreshConnection then
        refreshConnection:Disconnect()
        refreshConnection = nil
        print("[TCE] Auto-refresh stopped")
    end
end

--[[
Refreshes the Overview panel with live connection and user data.
]]
function UIManager.refreshOverview()
    if not contentPanels.overview then return end
    
    -- Update Connection Status
    if ConnectionMonitor then
        local status = ConnectionMonitor.getConnectionStatus()
        local statusText, statusColor
        
        if not status.isConnected then
            statusText = "Disconnected"
            statusColor = UI_CONSTANTS.COLORS.ERROR_RED
        elseif status.quality == "Excellent" then
            statusText = "Connected"
            statusColor = UI_CONSTANTS.COLORS.SUCCESS_GREEN
        elseif status.quality == "Good" then
            statusText = "Available" -- Team Create available but not active
            statusColor = UI_CONSTANTS.COLORS.ACCENT_TEAL
        elseif status.quality == "Poor" then
            statusText = "Unstable"
            statusColor = UI_CONSTANTS.COLORS.ACCENT_BLUE
        else
            statusText = "Unknown"
            statusColor = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        end
        
        UIManager.updateConnectionStatus(statusText, statusColor)
        
        -- Update Active Users
        local activeUsers = ConnectionMonitor.getActiveUsers()
        UIManager.updateUserList(activeUsers)
        
        -- Update Session Stats
        UIManager.updateSessionStats(status)
    end
    
    -- Update Recent Activity
    if NotificationManager then
        UIManager.updateRecentActivity()
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
    if not contentPanels.assets then return end
    
    local lockedFrame = contentPanels.assets:FindFirstChild("LockedAssets")
    if not lockedFrame then return end
    
    -- Update header
    local lockedLabel = lockedFrame:FindFirstChild("LockedLabel")
    local lockedAssets = {}
    local assetCount = 0
    
    if AssetLockManager and AssetLockManager.getLockedAssets then
        lockedAssets = AssetLockManager.getLockedAssets()
        for _ in pairs(lockedAssets) do
            assetCount = assetCount + 1
        end
    end
    
    if lockedLabel then
        lockedLabel.Text = "Currently Locked Assets (" .. assetCount .. ")"
    end
    
    -- Clear existing asset entries
    for _, child in pairs(lockedFrame:GetChildren()) do
        if child.Name:match("^Asset_") then
            child:Destroy()
        end
    end
    
    -- Add locked asset entries
    local entryIndex = 0
    for path, lockInfo in pairs(lockedAssets) do
        if entryIndex < 6 then -- Show max 6 assets in panel
            entryIndex = entryIndex + 1
            
            local assetEntry = Instance.new("Frame")
            assetEntry.Name = "Asset_" .. entryIndex
            assetEntry.Parent = lockedFrame
            assetEntry.Size = UDim2.new(1, -20, 0, 25)
            assetEntry.Position = UDim2.new(0, 10, 0, 30 + (entryIndex-1) * 27)
            assetEntry.BackgroundTransparency = 1
            
            -- Lock icon
            local lockIcon = Instance.new("TextLabel")
            lockIcon.Name = "LockIcon"
            lockIcon.Parent = assetEntry
            lockIcon.Size = UDim2.new(0, 20, 0, 20)
            lockIcon.Position = UDim2.new(0, 0, 0, 2)
            lockIcon.BackgroundTransparency = 1
            lockIcon.Text = "🔒"
            lockIcon.TextColor3 = PermissionManager and PermissionManager.getRoleColor(lockInfo.role) or UI_CONSTANTS.COLORS.ACCENT_BLUE
            lockIcon.TextScaled = true
            lockIcon.Font = UI_CONSTANTS.FONTS.MAIN
            
            -- Asset name
            local assetName = path:match("([^/]+)$") or path -- Get last part of path
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Parent = assetEntry
            nameLabel.Size = UDim2.new(0.5, -25, 1, 0)
            nameLabel.Position = UDim2.new(0, 25, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = assetName
            nameLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
            nameLabel.TextScaled = true
            nameLabel.Font = UI_CONSTANTS.FONTS.MAIN
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- User name
            local userLabel = Instance.new("TextLabel")
            userLabel.Name = "UserLabel"
            userLabel.Parent = assetEntry
            userLabel.Size = UDim2.new(0.5, 0, 1, 0)
            userLabel.Position = UDim2.new(0.5, 0, 0, 0)
            userLabel.BackgroundTransparency = 1
            userLabel.Text = lockInfo.userName or ("User " .. lockInfo.userId)
            userLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
            userLabel.TextScaled = true
            userLabel.Font = UI_CONSTANTS.FONTS.MAIN
            userLabel.TextXAlignment = Enum.TextXAlignment.Right
            userLabel.TextTruncate = Enum.TextTruncate.AtEnd
        end
    end
    
    -- Show "No assets locked" if empty
    if assetCount == 0 then
        local noAssetsLabel = Instance.new("TextLabel")
        noAssetsLabel.Name = "Asset_None"
        noAssetsLabel.Parent = lockedFrame
        noAssetsLabel.Size = UDim2.new(1, -20, 0, 30)
        noAssetsLabel.Position = UDim2.new(0, 10, 0, 50)
        noAssetsLabel.BackgroundTransparency = 1
        noAssetsLabel.Text = "No assets are currently locked"
        noAssetsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        noAssetsLabel.TextScaled = true
        noAssetsLabel.Font = UI_CONSTANTS.FONTS.MAIN
        noAssetsLabel.TextXAlignment = Enum.TextXAlignment.Center
    end
    
    -- Update conflict status
    local conflictFrame = contentPanels.assets:FindFirstChild("ConflictStatus")
    if conflictFrame and ConflictResolver then
        local conflictLabel = conflictFrame:FindFirstChild("ConflictLabel")
        local activeConflicts = ConflictResolver.getActiveConflicts and ConflictResolver.getActiveConflicts() or {}
        local conflictCount = 0
        for _ in pairs(activeConflicts) do
            conflictCount = conflictCount + 1
        end
        
        if conflictLabel then
            conflictLabel.Text = "Edit Conflicts (" .. conflictCount .. " active)"
        end
    end
end

--[[
Refreshes the Tasks panel with current task information.
]]
function UIManager.refreshTasks()
    if not contentPanels.tasks or not TaskManager then return end
    
    -- Update stats display
    local statsLabel = contentPanels.tasks:FindFirstChild("StatsLabel")
    if statsLabel then
        local stats = TaskManager.getTaskStats()
        statsLabel.Text = string.format("Total: %d | Mine: %d", stats.total, stats.myTasks)
    end
    
    -- Update task list
    local tasksListFrame = contentPanels.tasks:FindFirstChild("TasksList")
    if not tasksListFrame then return end
    
    local tasksListLabel = tasksListFrame:FindFirstChild("TasksListLabel")
    local tasksScrollFrame = tasksListFrame:FindFirstChild("TasksScroll")
    
    if not tasksScrollFrame then return end
    
    -- Clear existing task entries
    for _, child in pairs(tasksScrollFrame:GetChildren()) do
        if child.Name:match("^Task_") then
            child:Destroy()
        end
    end
    
    -- Get tasks (showing all by default)
    local allTasks = TaskManager.getTasks()
    local displayTasks = {}
    
    -- Apply basic filtering - show pending/in-progress tasks first
    for _, task in ipairs(allTasks) do
        if task.status ~= "Completed" and task.status ~= "Cancelled" then
            table.insert(displayTasks, task)
        end
    end
    
    -- Update header
    if tasksListLabel then
        tasksListLabel.Text = string.format("📝 Active Tasks (%d)", #displayTasks)
    end
    
    -- Create task entries
    local yOffset = 0
    for i, task in ipairs(displayTasks) do
        if i <= 20 then -- Limit to 20 tasks for performance
            local taskEntry = createRoundedFrame(tasksScrollFrame, {
                Name = "Task_" .. task.id,
                Size = UDim2.new(1, -10, 0, 60),
                Position = UDim2.new(0, 5, 0, yOffset),
                BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
            })
            
            -- Make task entry clickable
            local clickDetector = Instance.new("TextButton")
            clickDetector.Name = "ClickDetector"
            clickDetector.Parent = taskEntry
            clickDetector.Size = UDim2.new(1, 0, 1, 0)
            clickDetector.Position = UDim2.new(0, 0, 0, 0)
            clickDetector.BackgroundTransparency = 1
            clickDetector.Text = ""
            clickDetector.ZIndex = 10
            
            -- Add hover effect
            clickDetector.MouseEnter:Connect(function()
                local hoverTween = TweenService:Create(taskEntry, TweenInfo.new(0.2), {BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_BLUE})
                hoverTween:Play()
            end)
            
            clickDetector.MouseLeave:Connect(function()
                local normalTween = TweenService:Create(taskEntry, TweenInfo.new(0.2), {BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG})
                normalTween:Play()
            end)
            
            -- Add click handler to open edit dialog
            clickDetector.MouseButton1Click:Connect(function()
                UIManager.showEditTaskDialog(task)
            end)
            
            -- Priority indicator
            local priorityColors = {
                Critical = UI_CONSTANTS.COLORS.ERROR_RED,
                High = UI_CONSTANTS.COLORS.ACCENT_MAGENTA,
                Medium = UI_CONSTANTS.COLORS.ACCENT_BLUE,
                Low = UI_CONSTANTS.COLORS.TEXT_SECONDARY
            }
            
            local priorityDot = createStatusIndicator(taskEntry, {
                Name = "PriorityDot",
                Position = UDim2.new(0, 8, 0, 8),
                Color = priorityColors[task.priority] or UI_CONSTANTS.COLORS.ACCENT_BLUE
            })
            
            -- Task title
            local titleLabel = Instance.new("TextLabel")
            titleLabel.Name = "TitleLabel"
            titleLabel.Parent = taskEntry
            titleLabel.Size = UDim2.new(0.6, -30, 0, 20)
            titleLabel.Position = UDim2.new(0, 25, 0, 5)
            titleLabel.BackgroundTransparency = 1
            titleLabel.Text = task.title
            titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
            titleLabel.TextScaled = true
            titleLabel.Font = UI_CONSTANTS.FONTS.MAIN
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Task status
            local statusColors = {
                Todo = UI_CONSTANTS.COLORS.TEXT_SECONDARY,
                InProgress = UI_CONSTANTS.COLORS.ACCENT_TEAL,
                Review = UI_CONSTANTS.COLORS.ACCENT_PURPLE,
                Completed = UI_CONSTANTS.COLORS.SUCCESS_GREEN,
                Cancelled = UI_CONSTANTS.COLORS.ERROR_RED
            }
            
            local statusLabel = Instance.new("TextLabel")
            statusLabel.Name = "StatusLabel"
            statusLabel.Parent = taskEntry
            statusLabel.Size = UDim2.new(0.3, 0, 0, 18)
            statusLabel.Position = UDim2.new(0.6, 5, 0, 6)
            statusLabel.BackgroundColor3 = statusColors[task.status] or UI_CONSTANTS.COLORS.TEXT_SECONDARY
            statusLabel.BorderSizePixel = 0
            statusLabel.Text = task.status
            statusLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
            statusLabel.TextScaled = true
            statusLabel.Font = UI_CONSTANTS.FONTS.MAIN
            statusLabel.TextXAlignment = Enum.TextXAlignment.Center
            
            -- Round status label
            local statusCorner = Instance.new("UICorner")
            statusCorner.CornerRadius = UDim.new(0, 6)
            statusCorner.Parent = statusLabel
            
            -- Assigned user and due date
            local assignedText = "👤 Unassigned"
            if task.assignedTo then
                local assigneeName = "Unknown User"
                local localPlayer = Players and Players.LocalPlayer
                if localPlayer and task.assignedTo == localPlayer.UserId then
                    assigneeName = "You"
                elseif ConnectionMonitor and ConnectionMonitor.getActiveUsers then
                    local activeUsers = ConnectionMonitor.getActiveUsers()
                    for _, user in ipairs(activeUsers) do
                        if user.userId == task.assignedTo then
                            assigneeName = user.name
                            break
                        end
                    end
                    if assigneeName == "Unknown User" then
                        assigneeName = "User " .. task.assignedTo
                    end
                else
                    assigneeName = "User " .. task.assignedTo
                end
                assignedText = "👤 " .. assigneeName
            end
            
            -- Add task type and description to the assigned text
            local descriptionText = ""
            if task.description and task.description ~= "" then
                descriptionText = " • " .. task.description
            end
            
            if task.taskType then
                assignedText = assignedText .. " • 📝 " .. task.taskType
            end
            
            assignedText = assignedText .. descriptionText
            
            local assignedLabel = Instance.new("TextLabel")
            assignedLabel.Name = "AssignedLabel"
            assignedLabel.Parent = taskEntry
            assignedLabel.Size = UDim2.new(0.6, -30, 0, 15)
            assignedLabel.Position = UDim2.new(0, 25, 0, 25)
            assignedLabel.BackgroundTransparency = 1
            assignedLabel.Text = assignedText
            assignedLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
            assignedLabel.TextScaled = true
            assignedLabel.Font = UI_CONSTANTS.FONTS.MAIN
            assignedLabel.TextXAlignment = Enum.TextXAlignment.Left
            assignedLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Due date if exists
            if task.dueDate then
                local currentTime = os.time()
                local timeUntilDue = task.dueDate - currentTime
                local daysUntilDue = math.floor(timeUntilDue / 86400)
                local hoursUntilDue = math.floor(timeUntilDue / 3600)
                
                local dueDateText = ""
                local dueDateColor = UI_CONSTANTS.COLORS.TEXT_SECONDARY
                
                if timeUntilDue < 0 then
                    -- Overdue
                    dueDateText = "🔴 OVERDUE"
                    dueDateColor = UI_CONSTANTS.COLORS.ERROR_RED
                elseif daysUntilDue == 0 and hoursUntilDue > 0 then
                    -- Due today
                    dueDateText = "🟡 Due in " .. hoursUntilDue .. "h"
                    dueDateColor = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
                elseif daysUntilDue == 0 then
                    -- Due very soon
                    dueDateText = "🔴 Due now!"
                    dueDateColor = UI_CONSTANTS.COLORS.ERROR_RED
                elseif daysUntilDue == 1 then
                    -- Due tomorrow
                    dueDateText = "🟠 Tomorrow"
                    dueDateColor = UI_CONSTANTS.COLORS.ACCENT_BLUE
                elseif daysUntilDue <= 3 then
                    -- Due soon
                    dueDateText = "🟡 " .. daysUntilDue .. " days"
                    dueDateColor = UI_CONSTANTS.COLORS.ACCENT_TEAL
                else
                    -- Due later
                    dueDateText = "📅 " .. os.date("%m/%d", task.dueDate)
                    dueDateColor = UI_CONSTANTS.COLORS.TEXT_SECONDARY
                end
                
                local dueDateLabel = Instance.new("TextLabel")
                dueDateLabel.Name = "DueDateLabel"
                dueDateLabel.Parent = taskEntry
                dueDateLabel.Size = UDim2.new(0.3, 0, 0, 15)
                dueDateLabel.Position = UDim2.new(0.6, 5, 0, 25)
                dueDateLabel.BackgroundTransparency = 1
                dueDateLabel.Text = dueDateText
                dueDateLabel.TextColor3 = dueDateColor
                dueDateLabel.TextScaled = true
                dueDateLabel.Font = UI_CONSTANTS.FONTS.MAIN
                dueDateLabel.TextXAlignment = Enum.TextXAlignment.Right
            end
            
            -- Comments indicator (if any)
            if task.comments and #task.comments > 0 then
                local commentsLabel = Instance.new("TextLabel")
                commentsLabel.Name = "CommentsLabel"
                commentsLabel.Parent = taskEntry
                commentsLabel.Size = UDim2.new(0, 30, 0, 15)
                commentsLabel.Position = UDim2.new(1, -35, 0, 40)
                commentsLabel.BackgroundTransparency = 1
                commentsLabel.Text = "💬 " .. #task.comments
                commentsLabel.TextColor3 = UI_CONSTANTS.COLORS.ACCENT_BLUE
                commentsLabel.TextScaled = true
                commentsLabel.Font = UI_CONSTANTS.FONTS.MAIN
                commentsLabel.TextXAlignment = Enum.TextXAlignment.Center
            end
            
            -- Progress bar (always show, even at 0%)
            local progressBg = Instance.new("Frame")
            progressBg.Name = "ProgressBg"
            progressBg.Parent = taskEntry
            progressBg.Size = UDim2.new(0.7, 0, 0, 6)
            progressBg.Position = UDim2.new(0, 8, 1, -12)
            progressBg.BackgroundColor3 = UI_CONSTANTS.COLORS.PRIMARY_BG
            progressBg.BorderSizePixel = 0
            
            local progressCorner = Instance.new("UICorner")
            progressCorner.CornerRadius = UDim.new(0, 3)
            progressCorner.Parent = progressBg
            
            -- Progress fill with color based on progress
            local progressColor = UI_CONSTANTS.COLORS.TEXT_SECONDARY
            if task.progress >= 100 then
                progressColor = UI_CONSTANTS.COLORS.SUCCESS_GREEN
            elseif task.progress >= 75 then
                progressColor = UI_CONSTANTS.COLORS.ACCENT_TEAL
            elseif task.progress >= 50 then
                progressColor = UI_CONSTANTS.COLORS.ACCENT_BLUE
            elseif task.progress >= 25 then
                progressColor = UI_CONSTANTS.COLORS.ACCENT_PURPLE
            elseif task.progress > 0 then
                progressColor = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
            end
            
            if task.progress > 0 then
                local progressFill = Instance.new("Frame")
                progressFill.Name = "ProgressFill"
                progressFill.Parent = progressBg
                progressFill.Size = UDim2.new(math.max(0.05, task.progress / 100), 0, 1, 0)
                progressFill.Position = UDim2.new(0, 0, 0, 0)
                progressFill.BackgroundColor3 = progressColor
                progressFill.BorderSizePixel = 0
                
                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(0, 3)
                fillCorner.Parent = progressFill
            end
            
            -- Progress percentage text
            local progressLabel = Instance.new("TextLabel")
            progressLabel.Name = "ProgressLabel"
            progressLabel.Parent = taskEntry
            progressLabel.Size = UDim2.new(0, 40, 0, 12)
            progressLabel.Position = UDim2.new(1, -45, 1, -14)
            progressLabel.BackgroundTransparency = 1
            progressLabel.Text = task.progress .. "%"
            progressLabel.TextColor3 = task.progress >= 100 and UI_CONSTANTS.COLORS.SUCCESS_GREEN or UI_CONSTANTS.COLORS.TEXT_SECONDARY
            progressLabel.TextScaled = true
            progressLabel.Font = UI_CONSTANTS.FONTS.MAIN
            progressLabel.TextXAlignment = Enum.TextXAlignment.Center
            
            yOffset = yOffset + 65
        end
    end
    
    -- Update canvas size for scrolling
    tasksScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(yOffset, tasksScrollFrame.AbsoluteSize.Y))
end

--[[
Shows a dialog for creating a new task.
]]
function UIManager.showNewTaskDialog()
    if not TaskManager then
        print("[TCE] TaskManager not available")
        return
    end
    
    -- Create modal overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "TaskDialogOverlay"
    overlay.Parent = dockWidget
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    
    -- Create dialog frame
    local dialog = createRoundedFrame(overlay, {
        Name = "NewTaskDialog",
        Size = UDim2.new(0, 400, 0, 580),
        Position = UDim2.new(0.5, -200, 0.5, -290),
        BackgroundColor3 = UI_CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true,
        GlowColor = UI_CONSTANTS.COLORS.ACCENT_PURPLE
    })
    dialog.ZIndex = 101
    
    -- Dialog title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = dialog
    titleLabel.Size = UDim2.new(1, -40, 0, 30)
    titleLabel.Position = UDim2.new(0, 20, 0, 15)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "➕ Create New Task"
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 102
    
    -- Close button
    local closeButton = createStyledButton(dialog, {
        Name = "CloseButton",
        Text = "✕",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(1, -35, 0, 10),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
    })
    closeButton.ZIndex = 102
    
    closeButton.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    -- Task title input
    local titleFrame = Instance.new("Frame")
    titleFrame.Name = "TitleFrame"
    titleFrame.Parent = dialog
    titleFrame.Size = UDim2.new(1, -40, 0, 60)
    titleFrame.Position = UDim2.new(0, 20, 0, 55)
    titleFrame.BackgroundTransparency = 1
    titleFrame.ZIndex = 102
    
    local titleInputLabel = Instance.new("TextLabel")
    titleInputLabel.Name = "TitleInputLabel"
    titleInputLabel.Parent = titleFrame
    titleInputLabel.Size = UDim2.new(1, 0, 0, 20)
    titleInputLabel.Position = UDim2.new(0, 0, 0, 0)
    titleInputLabel.BackgroundTransparency = 1
    titleInputLabel.Text = "Task Title:"
    titleInputLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleInputLabel.TextScaled = true
    titleInputLabel.Font = UI_CONSTANTS.FONTS.MAIN
    titleInputLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleInputLabel.ZIndex = 102
    
    local titleInput = Instance.new("TextBox")
    titleInput.Name = "TitleInput"
    titleInput.Parent = titleFrame
    titleInput.Size = UDim2.new(1, 0, 0, 30)
    titleInput.Position = UDim2.new(0, 0, 0, 25)
    titleInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    titleInput.BorderSizePixel = 0
    titleInput.Text = ""
    titleInput.PlaceholderText = "Enter task title..."
    titleInput.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleInput.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    titleInput.TextScaled = true
    titleInput.Font = UI_CONSTANTS.FONTS.MAIN
    titleInput.TextXAlignment = Enum.TextXAlignment.Left
    titleInput.ZIndex = 102
    
    local titleInputCorner = Instance.new("UICorner")
    titleInputCorner.CornerRadius = UDim.new(0, 4)
    titleInputCorner.Parent = titleInput
    
    -- Description input
    local descFrame = Instance.new("Frame")
    descFrame.Name = "DescFrame"
    descFrame.Parent = dialog
    descFrame.Size = UDim2.new(1, -40, 0, 80)
    descFrame.Position = UDim2.new(0, 20, 0, 125)
    descFrame.BackgroundTransparency = 1
    descFrame.ZIndex = 102
    
    local descInputLabel = Instance.new("TextLabel")
    descInputLabel.Name = "DescInputLabel"
    descInputLabel.Parent = descFrame
    descInputLabel.Size = UDim2.new(1, 0, 0, 20)
    descInputLabel.Position = UDim2.new(0, 0, 0, 0)
    descInputLabel.BackgroundTransparency = 1
    descInputLabel.Text = "Description:"
    descInputLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    descInputLabel.TextScaled = true
    descInputLabel.Font = UI_CONSTANTS.FONTS.MAIN
    descInputLabel.TextXAlignment = Enum.TextXAlignment.Left
    descInputLabel.ZIndex = 102
    
    local descInput = Instance.new("TextBox")
    descInput.Name = "DescInput"
    descInput.Parent = descFrame
    descInput.Size = UDim2.new(1, 0, 0, 50)
    descInput.Position = UDim2.new(0, 0, 0, 25)
    descInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    descInput.BorderSizePixel = 0
    descInput.Text = ""
    descInput.PlaceholderText = "Enter task description..."
    descInput.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    descInput.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    descInput.TextScaled = true
    descInput.Font = UI_CONSTANTS.FONTS.MAIN
    descInput.TextXAlignment = Enum.TextXAlignment.Left
    descInput.TextYAlignment = Enum.TextYAlignment.Top
    descInput.TextWrapped = true
    descInput.MultiLine = true
    descInput.ZIndex = 102
    
    local descInputCorner = Instance.new("UICorner")
    descInputCorner.CornerRadius = UDim.new(0, 4)
    descInputCorner.Parent = descInput
    
    -- Priority selection
    local priorityFrame = Instance.new("Frame")
    priorityFrame.Name = "PriorityFrame"
    priorityFrame.Parent = dialog
    priorityFrame.Size = UDim2.new(1, -40, 0, 60)
    priorityFrame.Position = UDim2.new(0, 20, 0, 215)
    priorityFrame.BackgroundTransparency = 1
    priorityFrame.ZIndex = 102
    
    local priorityLabel = Instance.new("TextLabel")
    priorityLabel.Name = "PriorityLabel"
    priorityLabel.Parent = priorityFrame
    priorityLabel.Size = UDim2.new(1, 0, 0, 20)
    priorityLabel.Position = UDim2.new(0, 0, 0, 0)
    priorityLabel.BackgroundTransparency = 1
    priorityLabel.Text = "Priority:"
    priorityLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    priorityLabel.TextScaled = true
    priorityLabel.Font = UI_CONSTANTS.FONTS.MAIN
    priorityLabel.TextXAlignment = Enum.TextXAlignment.Left
    priorityLabel.ZIndex = 102
    
    local selectedPriority = "Medium"
    local priorityButtons = {}
    local priorities = {"Critical", "High", "Medium", "Low"}
    local priorityColors = {
        Critical = UI_CONSTANTS.COLORS.ERROR_RED,
        High = UI_CONSTANTS.COLORS.ACCENT_MAGENTA,
        Medium = UI_CONSTANTS.COLORS.ACCENT_BLUE,
        Low = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    }
    
    for i, priority in ipairs(priorities) do
        local priorityButton = createStyledButton(priorityFrame, {
            Name = priority .. "Button",
            Text = priority,
            Size = UDim2.new(0.23, 0, 0, 30),
            Position = UDim2.new((i-1) * 0.25, 0, 0, 25),
            BackgroundColor3 = priority == selectedPriority and priorityColors[priority] or UI_CONSTANTS.COLORS.SECONDARY_BG
        })
        priorityButton.ZIndex = 102
        
        priorityButton.MouseButton1Click:Connect(function()
            selectedPriority = priority
            -- Update button colors
            for j, p in ipairs(priorities) do
                local button = priorityButtons[p]
                if button then
                    local targetColor = (p == selectedPriority) and priorityColors[p] or UI_CONSTANTS.COLORS.SECONDARY_BG
                    local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor})
                    tween:Play()
                end
            end
        end)
        
        priorityButtons[priority] = priorityButton
    end
    
    -- User Assignment section
    local assignFrame = Instance.new("Frame")
    assignFrame.Name = "AssignFrame"
    assignFrame.Parent = dialog
    assignFrame.Size = UDim2.new(1, -40, 0, 60)
    assignFrame.Position = UDim2.new(0, 20, 0, 285)
    assignFrame.BackgroundTransparency = 1
    assignFrame.ZIndex = 102
    
    local assignLabel = Instance.new("TextLabel")
    assignLabel.Name = "AssignLabel"
    assignLabel.Parent = assignFrame
    assignLabel.Size = UDim2.new(1, 0, 0, 20)
    assignLabel.Position = UDim2.new(0, 0, 0, 0)
    assignLabel.BackgroundTransparency = 1
    assignLabel.Text = "Assign to:"
    assignLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    assignLabel.TextScaled = true
    assignLabel.Font = UI_CONSTANTS.FONTS.MAIN
    assignLabel.TextXAlignment = Enum.TextXAlignment.Left
    assignLabel.ZIndex = 102
    
    -- Get available users
    local availableUsers = {{userId = 0, name = "Unassigned"}}
    if ConnectionMonitor and ConnectionMonitor.getActiveUsers then
        local activeUsers = ConnectionMonitor.getActiveUsers()
        for _, user in ipairs(activeUsers) do
            table.insert(availableUsers, {userId = user.userId, name = user.name})
        end
    end
    
    local selectedUserId = 0
    local assignButtons = {}
    
    for i, user in ipairs(availableUsers) do
        if i <= 4 then -- Show max 4 users in dialog
            local userButton = createStyledButton(assignFrame, {
                Name = user.name .. "Button",
                Text = user.name,
                Size = UDim2.new(0.23, 0, 0, 30),
                Position = UDim2.new((i-1) * 0.25, 0, 0, 25),
                BackgroundColor3 = selectedUserId == user.userId and UI_CONSTANTS.COLORS.ACCENT_TEAL or UI_CONSTANTS.COLORS.SECONDARY_BG
            })
            userButton.ZIndex = 102
            
            userButton.MouseButton1Click:Connect(function()
                selectedUserId = user.userId
                -- Update button colors
                for j, u in ipairs(availableUsers) do
                    local button = assignButtons[u.userId]
                    if button then
                        local targetColor = (u.userId == selectedUserId) and UI_CONSTANTS.COLORS.ACCENT_TEAL or UI_CONSTANTS.COLORS.SECONDARY_BG
                        local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor})
                        tween:Play()
                    end
                end
            end)
            
            assignButtons[user.userId] = userButton
        end
    end
    
    -- Due Date section
    local dueDateFrame = Instance.new("Frame")
    dueDateFrame.Name = "DueDateFrame"
    dueDateFrame.Parent = dialog
    dueDateFrame.Size = UDim2.new(1, -40, 0, 60)
    dueDateFrame.Position = UDim2.new(0, 20, 0, 355)
    dueDateFrame.BackgroundTransparency = 1
    dueDateFrame.ZIndex = 102
    
    local dueDateLabel = Instance.new("TextLabel")
    dueDateLabel.Name = "DueDateLabel"
    dueDateLabel.Parent = dueDateFrame
    dueDateLabel.Size = UDim2.new(0.5, 0, 0, 20)
    dueDateLabel.Position = UDim2.new(0, 0, 0, 0)
    dueDateLabel.BackgroundTransparency = 1
    dueDateLabel.Text = "Due Date (optional):"
    dueDateLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    dueDateLabel.TextScaled = true
    dueDateLabel.Font = UI_CONSTANTS.FONTS.MAIN
    dueDateLabel.TextXAlignment = Enum.TextXAlignment.Left
    dueDateLabel.ZIndex = 102
    
    local dueDateInput = Instance.new("TextBox")
    dueDateInput.Name = "DueDateInput"
    dueDateInput.Parent = dueDateFrame
    dueDateInput.Size = UDim2.new(0.5, -10, 0, 30)
    dueDateInput.Position = UDim2.new(0.5, 0, 0, 25)
    dueDateInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    dueDateInput.BorderSizePixel = 0
    dueDateInput.Text = ""
    dueDateInput.PlaceholderText = "MM/DD/YYYY or days from now..."
    dueDateInput.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    dueDateInput.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    dueDateInput.TextScaled = true
    dueDateInput.Font = UI_CONSTANTS.FONTS.MAIN
    dueDateInput.TextXAlignment = Enum.TextXAlignment.Center
    dueDateInput.ZIndex = 102
    
    local dueDateCorner = Instance.new("UICorner")
    dueDateCorner.CornerRadius = UDim.new(0, 4)
    dueDateCorner.Parent = dueDateInput
    
    -- Quick due date buttons
    local quickDates = {"1 Day", "3 Days", "1 Week"}
    for i, dateText in ipairs(quickDates) do
        local quickButton = createStyledButton(dueDateFrame, {
            Name = dateText .. "Button",
            Text = dateText,
            Size = UDim2.new(0.15, 0, 0, 25),
            Position = UDim2.new((i-1) * 0.16, 0, 0, 0),
            BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
        })
        quickButton.ZIndex = 102
        
        quickButton.MouseButton1Click:Connect(function()
            local days = 1
            if dateText == "3 Days" then days = 3
            elseif dateText == "1 Week" then days = 7 end
            
            local futureDate = os.time() + (days * 24 * 60 * 60)
            dueDateInput.Text = os.date("%m/%d/%Y", futureDate)
        end)
    end
    
    -- Type selection
    local typeFrame = Instance.new("Frame")
    typeFrame.Name = "TypeFrame"
    typeFrame.Parent = dialog
    typeFrame.Size = UDim2.new(1, -40, 0, 60)
    typeFrame.Position = UDim2.new(0, 20, 0, 425)
    typeFrame.BackgroundTransparency = 1
    typeFrame.ZIndex = 102
    
    local typeLabel = Instance.new("TextLabel")
    typeLabel.Name = "TypeLabel"
    typeLabel.Parent = typeFrame
    typeLabel.Size = UDim2.new(1, 0, 0, 20)
    typeLabel.Position = UDim2.new(0, 0, 0, 0)
    typeLabel.BackgroundTransparency = 1
    typeLabel.Text = "Type:"
    typeLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    typeLabel.TextScaled = true
    typeLabel.Font = UI_CONSTANTS.FONTS.MAIN
    typeLabel.TextXAlignment = Enum.TextXAlignment.Left
    typeLabel.ZIndex = 102
    
    local selectedType = "Feature"
    local typeButtons = {}
    local types = {"Script", "Build", "Design", "Feature"}
    
    for i, taskType in ipairs(types) do
        local typeButton = createStyledButton(typeFrame, {
            Name = taskType .. "Button",
            Text = taskType,
            Size = UDim2.new(0.23, 0, 0, 30),
            Position = UDim2.new((i-1) * 0.25, 0, 0, 25),
            BackgroundColor3 = taskType == selectedType and UI_CONSTANTS.COLORS.ACCENT_PURPLE or UI_CONSTANTS.COLORS.SECONDARY_BG
        })
        typeButton.ZIndex = 102
        
        typeButton.MouseButton1Click:Connect(function()
            selectedType = taskType
            -- Update button colors
            for j, t in ipairs(types) do
                local button = typeButtons[t]
                if button then
                    local targetColor = (t == selectedType) and UI_CONSTANTS.COLORS.ACCENT_PURPLE or UI_CONSTANTS.COLORS.SECONDARY_BG
                    local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor})
                    tween:Play()
                end
            end
        end)
        
        typeButtons[taskType] = typeButton
    end
    
    -- Action buttons
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Parent = dialog
    buttonFrame.Size = UDim2.new(1, -40, 0, 40)
    buttonFrame.Position = UDim2.new(0, 20, 0, 530)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.ZIndex = 102
    
    local cancelButton = createStyledButton(buttonFrame, {
        Name = "CancelButton",
        Text = "Cancel",
        Size = UDim2.new(0.45, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    })
    cancelButton.ZIndex = 102
    
    cancelButton.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    local createButton = createStyledButton(buttonFrame, {
        Name = "CreateButton",
        Text = "Create Task",
        Size = UDim2.new(0.45, 0, 1, 0),
        Position = UDim2.new(0.55, 0, 0, 0),
        BackgroundColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    })
    createButton.ZIndex = 102
    
    createButton.MouseButton1Click:Connect(function()
        local title = titleInput.Text:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
        if title == "" then
            -- Show error - title required
            titleInput.BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
            wait(0.5)
            titleInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
            return
        end
        
        -- Parse due date
        local dueDate = nil
        local dueDateText = dueDateInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if dueDateText ~= "" then
            -- Try parsing MM/DD/YYYY format
            local month, day, year = dueDateText:match("(%d+)/(%d+)/(%d+)")
            if month and day and year then
                dueDate = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 23, min = 59, sec = 59})
            else
                -- Try parsing as number of days from now
                local days = tonumber(dueDateText)
                if days then
                    dueDate = os.time() + (days * 24 * 60 * 60)
                end
            end
        end
        
        -- Create the task
        local taskData = {
            title = title,
            description = descInput.Text,
            assignedTo = selectedUserId > 0 and selectedUserId or nil,
            dueDate = dueDate,
            priority = selectedPriority,
            taskType = selectedType,
            tags = {}
        }
        
        local taskId, error = TaskManager.createTask(taskData)
        
        if taskId then
            print("[TCE] Created new task:", taskId, "-", title)
            overlay:Destroy()
            
            -- Refresh the tasks panel
            if currentTab == "tasks" then
                UIManager.refreshTasks()
            end
            
            -- Show success notification
            if NotificationManager then
                NotificationManager.sendMessage("Task Created", 
                    string.format("Successfully created task: %s", title), "SUCCESS")
            end
        else
            print("[TCE] Failed to create task:", error)
            -- Show error feedback
            createButton.BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
            createButton.Text = "Error: " .. (error or "Unknown")
            wait(2)
            createButton.BackgroundColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
            createButton.Text = "Create Task"
        end
    end)
    
    -- Focus on title input
    titleInput:CaptureFocus()
end

--[[
Shows a dialog for editing an existing task.
@param task table: The task to edit
]]
function UIManager.showEditTaskDialog(task)
    if not TaskManager or not task then
        print("[TCE] TaskManager or task not available")
        return
    end
    
    -- Create modal overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "EditTaskDialogOverlay"
    overlay.Parent = dockWidget
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    
    -- Create dialog frame (larger for edit dialog)
    local dialog = createRoundedFrame(overlay, {
        Name = "EditTaskDialog",
        Size = UDim2.new(0, 450, 0, 700),
        Position = UDim2.new(0.5, -225, 0.5, -350),
        BackgroundColor3 = UI_CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true,
        GlowColor = UI_CONSTANTS.COLORS.ACCENT_BLUE
    })
    dialog.ZIndex = 101
    
    -- Dialog title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = dialog
    titleLabel.Size = UDim2.new(1, -70, 0, 30)
    titleLabel.Position = UDim2.new(0, 20, 0, 15)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "✏️ Edit Task: " .. task.title
    titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UI_CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 102
    
    -- Close button
    local closeButton = createStyledButton(dialog, {
        Name = "CloseButton",
        Text = "✕",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(1, -35, 0, 10),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
    })
    closeButton.ZIndex = 102
    
    closeButton.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    -- Delete button
    local deleteButton = createStyledButton(dialog, {
        Name = "DeleteButton",
        Text = "🗑️",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(1, -65, 0, 10),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
    })
    deleteButton.ZIndex = 102
    
    deleteButton.MouseButton1Click:Connect(function()
        -- Confirmation dialog
        local confirmOverlay = Instance.new("Frame")
        confirmOverlay.Name = "ConfirmOverlay"
        confirmOverlay.Parent = dockWidget
        confirmOverlay.Size = UDim2.new(1, 0, 1, 0)
        confirmOverlay.Position = UDim2.new(0, 0, 0, 0)
        confirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
        confirmOverlay.BackgroundTransparency = 0.7
        confirmOverlay.BorderSizePixel = 0
        confirmOverlay.ZIndex = 200
        
        local confirmDialog = createRoundedFrame(confirmOverlay, {
            Name = "ConfirmDialog",
            Size = UDim2.new(0, 300, 0, 150),
            Position = UDim2.new(0.5, -150, 0.5, -75),
            BackgroundColor3 = UI_CONSTANTS.COLORS.PRIMARY_BG,
            Glow = true,
            GlowColor = UI_CONSTANTS.COLORS.ERROR_RED
        })
        confirmDialog.ZIndex = 201
        
        local confirmLabel = Instance.new("TextLabel")
        confirmLabel.Name = "ConfirmLabel"
        confirmLabel.Parent = confirmDialog
        confirmLabel.Size = UDim2.new(1, -20, 0, 60)
        confirmLabel.Position = UDim2.new(0, 10, 0, 20)
        confirmLabel.BackgroundTransparency = 1
        confirmLabel.Text = "Are you sure you want to delete this task?\n\n\"" .. task.title .. "\""
        confirmLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
        confirmLabel.TextScaled = true
        confirmLabel.Font = UI_CONSTANTS.FONTS.MAIN
        confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
        confirmLabel.TextWrapped = true
        confirmLabel.ZIndex = 202
        
        local confirmCancelButton = createStyledButton(confirmDialog, {
            Name = "ConfirmCancelButton",
            Text = "Cancel",
            Size = UDim2.new(0.4, 0, 0, 35),
            Position = UDim2.new(0.05, 0, 0, 100),
            BackgroundColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        })
        confirmCancelButton.ZIndex = 202
        
        local confirmDeleteButton = createStyledButton(confirmDialog, {
            Name = "ConfirmDeleteButton",
            Text = "Delete",
            Size = UDim2.new(0.4, 0, 0, 35),
            Position = UDim2.new(0.55, 0, 0, 100),
            BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
        })
        confirmDeleteButton.ZIndex = 202
        
        confirmCancelButton.MouseButton1Click:Connect(function()
            confirmOverlay:Destroy()
        end)
        
        confirmDeleteButton.MouseButton1Click:Connect(function()
            local success, error = TaskManager.deleteTask(task.id)
            if success then
                confirmOverlay:Destroy()
                overlay:Destroy()
                if currentTab == "tasks" then
                    UIManager.refreshTasks()
                end
                if NotificationManager then
                    NotificationManager.sendMessage("Task Deleted", 
                        string.format("Deleted task: %s", task.title), "WARNING")
                end
            else
                print("[TCE] Failed to delete task:", error)
            end
        end)
    end)
    
    -- Task status and progress section
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusFrame"
    statusFrame.Parent = dialog
    statusFrame.Size = UDim2.new(1, -40, 0, 80)
    statusFrame.Position = UDim2.new(0, 20, 0, 55)
    statusFrame.BackgroundTransparency = 1
    statusFrame.ZIndex = 102
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Parent = statusFrame
    statusLabel.Size = UDim2.new(0.5, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 0, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status:"
    statusLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    statusLabel.TextScaled = true
    statusLabel.Font = UI_CONSTANTS.FONTS.MAIN
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 102
    
    local progressLabel = Instance.new("TextLabel")
    progressLabel.Name = "ProgressLabel"
    progressLabel.Parent = statusFrame
    progressLabel.Size = UDim2.new(0.5, 0, 0, 20)
    progressLabel.Position = UDim2.new(0.5, 0, 0, 0)
    progressLabel.BackgroundTransparency = 1
    progressLabel.Text = "Progress:"
    progressLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    progressLabel.TextScaled = true
    progressLabel.Font = UI_CONSTANTS.FONTS.MAIN
    progressLabel.TextXAlignment = Enum.TextXAlignment.Left
    progressLabel.ZIndex = 102
    
    -- Status buttons
    local selectedStatus = task.status
    local statusButtons = {}
    local statuses = {"Todo", "InProgress", "Review", "Completed"}
    local statusColors = {
        Todo = UI_CONSTANTS.COLORS.TEXT_SECONDARY,
        InProgress = UI_CONSTANTS.COLORS.ACCENT_TEAL,
        Review = UI_CONSTANTS.COLORS.ACCENT_PURPLE,
        Completed = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    }
    
    for i, status in ipairs(statuses) do
        local statusButton = createStyledButton(statusFrame, {
            Name = status .. "Button",
            Text = status,
            Size = UDim2.new(0.23, 0, 0, 25),
            Position = UDim2.new((i-1) * 0.25, 0, 0, 25),
            BackgroundColor3 = status == selectedStatus and statusColors[status] or UI_CONSTANTS.COLORS.SECONDARY_BG
        })
        statusButton.ZIndex = 102
        
        statusButton.MouseButton1Click:Connect(function()
            selectedStatus = status
            -- Update button colors
            for j, s in ipairs(statuses) do
                local button = statusButtons[s]
                if button then
                    local targetColor = (s == selectedStatus) and statusColors[s] or UI_CONSTANTS.COLORS.SECONDARY_BG
                    local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor})
                    tween:Play()
                end
            end
            
            -- Auto-update progress based on status
            if selectedStatus == "Completed" then
                progressSlider.Text = "100"
            elseif selectedStatus == "InProgress" and tonumber(progressSlider.Text) == 0 then
                progressSlider.Text = "25"
            elseif selectedStatus == "Review" and tonumber(progressSlider.Text) < 75 then
                progressSlider.Text = "75"
            end
        end)
        
        statusButtons[status] = statusButton
    end
    
    -- Progress slider
    local progressSlider = Instance.new("TextBox")
    progressSlider.Name = "ProgressSlider"
    progressSlider.Parent = statusFrame
    progressSlider.Size = UDim2.new(0.5, -10, 0, 25)
    progressSlider.Position = UDim2.new(0.5, 0, 0, 25)
    progressSlider.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    progressSlider.BorderSizePixel = 0
    progressSlider.Text = tostring(task.progress)
    progressSlider.PlaceholderText = "0-100"
    progressSlider.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    progressSlider.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    progressSlider.TextScaled = true
    progressSlider.Font = UI_CONSTANTS.FONTS.MAIN
    progressSlider.TextXAlignment = Enum.TextXAlignment.Center
    progressSlider.ZIndex = 102
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 4)
    progressCorner.Parent = progressSlider
    
    -- Progress buttons (quick set)
    local progressButtons = {"0%", "25%", "50%", "75%", "100%"}
    for i, prog in ipairs(progressButtons) do
        local progButton = createStyledButton(statusFrame, {
            Name = prog .. "Button",
            Text = prog,
            Size = UDim2.new(0.08, 0, 0, 20),
            Position = UDim2.new(0.5 + (i-1) * 0.09, 0, 0, 50),
            BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
        })
        progButton.ZIndex = 102
        
        progButton.MouseButton1Click:Connect(function()
            progressSlider.Text = prog:sub(1, -2) -- Remove %
        end)
    end
    
    -- Task title input (editable)
    local titleFrame = Instance.new("Frame")
    titleFrame.Name = "TitleFrame"
    titleFrame.Parent = dialog
    titleFrame.Size = UDim2.new(1, -40, 0, 60)
    titleFrame.Position = UDim2.new(0, 20, 0, 145)
    titleFrame.BackgroundTransparency = 1
    titleFrame.ZIndex = 102
    
    local titleInputLabel = Instance.new("TextLabel")
    titleInputLabel.Name = "TitleInputLabel"
    titleInputLabel.Parent = titleFrame
    titleInputLabel.Size = UDim2.new(1, 0, 0, 20)
    titleInputLabel.Position = UDim2.new(0, 0, 0, 0)
    titleInputLabel.BackgroundTransparency = 1
    titleInputLabel.Text = "Task Title:"
    titleInputLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleInputLabel.TextScaled = true
    titleInputLabel.Font = UI_CONSTANTS.FONTS.MAIN
    titleInputLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleInputLabel.ZIndex = 102
    
    local titleInput = Instance.new("TextBox")
    titleInput.Name = "TitleInput"
    titleInput.Parent = titleFrame
    titleInput.Size = UDim2.new(1, 0, 0, 30)
    titleInput.Position = UDim2.new(0, 0, 0, 25)
    titleInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    titleInput.BorderSizePixel = 0
    titleInput.Text = task.title
    titleInput.PlaceholderText = "Enter task title..."
    titleInput.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    titleInput.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    titleInput.TextScaled = true
    titleInput.Font = UI_CONSTANTS.FONTS.MAIN
    titleInput.TextXAlignment = Enum.TextXAlignment.Left
    titleInput.ZIndex = 102
    
    local titleInputCorner = Instance.new("UICorner")
    titleInputCorner.CornerRadius = UDim.new(0, 4)
    titleInputCorner.Parent = titleInput
    
    -- Description input (editable)
    local descFrame = Instance.new("Frame")
    descFrame.Name = "DescFrame"
    descFrame.Parent = dialog
    descFrame.Size = UDim2.new(1, -40, 0, 80)
    descFrame.Position = UDim2.new(0, 20, 0, 215)
    descFrame.BackgroundTransparency = 1
    descFrame.ZIndex = 102
    
    local descInputLabel = Instance.new("TextLabel")
    descInputLabel.Name = "DescInputLabel"
    descInputLabel.Parent = descFrame
    descInputLabel.Size = UDim2.new(1, 0, 0, 20)
    descInputLabel.Position = UDim2.new(0, 0, 0, 0)
    descInputLabel.BackgroundTransparency = 1
    descInputLabel.Text = "Description:"
    descInputLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    descInputLabel.TextScaled = true
    descInputLabel.Font = UI_CONSTANTS.FONTS.MAIN
    descInputLabel.TextXAlignment = Enum.TextXAlignment.Left
    descInputLabel.ZIndex = 102
    
    local descInput = Instance.new("TextBox")
    descInput.Name = "DescInput"
    descInput.Parent = descFrame
    descInput.Size = UDim2.new(1, 0, 0, 50)
    descInput.Position = UDim2.new(0, 0, 0, 25)
    descInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    descInput.BorderSizePixel = 0
    descInput.Text = task.description or ""
    descInput.PlaceholderText = "Enter task description..."
    descInput.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    descInput.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    descInput.TextScaled = true
    descInput.Font = UI_CONSTANTS.FONTS.MAIN
    descInput.TextXAlignment = Enum.TextXAlignment.Left
    descInput.TextYAlignment = Enum.TextYAlignment.Top
    descInput.TextWrapped = true
    descInput.MultiLine = true
    descInput.ZIndex = 102
    
    local descInputCorner = Instance.new("UICorner")
    descInputCorner.CornerRadius = UDim.new(0, 4)
    descInputCorner.Parent = descInput
    
    -- Priority selection (editable)
    local priorityFrame = Instance.new("Frame")
    priorityFrame.Name = "PriorityFrame"
    priorityFrame.Parent = dialog
    priorityFrame.Size = UDim2.new(1, -40, 0, 60)
    priorityFrame.Position = UDim2.new(0, 20, 0, 305)
    priorityFrame.BackgroundTransparency = 1
    priorityFrame.ZIndex = 102
    
    local priorityLabel = Instance.new("TextLabel")
    priorityLabel.Name = "PriorityLabel"
    priorityLabel.Parent = priorityFrame
    priorityLabel.Size = UDim2.new(1, 0, 0, 20)
    priorityLabel.Position = UDim2.new(0, 0, 0, 0)
    priorityLabel.BackgroundTransparency = 1
    priorityLabel.Text = "Priority:"
    priorityLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    priorityLabel.TextScaled = true
    priorityLabel.Font = UI_CONSTANTS.FONTS.MAIN
    priorityLabel.TextXAlignment = Enum.TextXAlignment.Left
    priorityLabel.ZIndex = 102
    
    local selectedPriority = task.priority
    local priorityButtons = {}
    local priorities = {"Critical", "High", "Medium", "Low"}
    local priorityColors = {
        Critical = UI_CONSTANTS.COLORS.ERROR_RED,
        High = UI_CONSTANTS.COLORS.ACCENT_MAGENTA,
        Medium = UI_CONSTANTS.COLORS.ACCENT_BLUE,
        Low = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    }
    
    for i, priority in ipairs(priorities) do
        local priorityButton = createStyledButton(priorityFrame, {
            Name = priority .. "Button",
            Text = priority,
            Size = UDim2.new(0.23, 0, 0, 30),
            Position = UDim2.new((i-1) * 0.25, 0, 0, 25),
            BackgroundColor3 = priority == selectedPriority and priorityColors[priority] or UI_CONSTANTS.COLORS.SECONDARY_BG
        })
        priorityButton.ZIndex = 102
        
        priorityButton.MouseButton1Click:Connect(function()
            selectedPriority = priority
            -- Update button colors
            for j, p in ipairs(priorities) do
                local button = priorityButtons[p]
                if button then
                    local targetColor = (p == selectedPriority) and priorityColors[p] or UI_CONSTANTS.COLORS.SECONDARY_BG
                    local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor})
                    tween:Play()
                end
            end
        end)
        
        priorityButtons[priority] = priorityButton
    end
    
    -- User Assignment section (editable)
    local assignFrame = Instance.new("Frame")
    assignFrame.Name = "AssignFrame"
    assignFrame.Parent = dialog
    assignFrame.Size = UDim2.new(1, -40, 0, 60)
    assignFrame.Position = UDim2.new(0, 20, 0, 375)
    assignFrame.BackgroundTransparency = 1
    assignFrame.ZIndex = 102
    
    local assignLabel = Instance.new("TextLabel")
    assignLabel.Name = "AssignLabel"
    assignLabel.Parent = assignFrame
    assignLabel.Size = UDim2.new(1, 0, 0, 20)
    assignLabel.Position = UDim2.new(0, 0, 0, 0)
    assignLabel.BackgroundTransparency = 1
    assignLabel.Text = "Assign to:"
    assignLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    assignLabel.TextScaled = true
    assignLabel.Font = UI_CONSTANTS.FONTS.MAIN
    assignLabel.TextXAlignment = Enum.TextXAlignment.Left
    assignLabel.ZIndex = 102
    
    -- Get available users
    local availableUsers = {{userId = 0, name = "Unassigned"}}
    if ConnectionMonitor and ConnectionMonitor.getActiveUsers then
        local activeUsers = ConnectionMonitor.getActiveUsers()
        for _, user in ipairs(activeUsers) do
            table.insert(availableUsers, {userId = user.userId, name = user.name})
        end
    end
    
    local selectedUserId = task.assignedTo or 0
    local assignButtons = {}
    
    for i, user in ipairs(availableUsers) do
        if i <= 4 then -- Show max 4 users in dialog
            local userButton = createStyledButton(assignFrame, {
                Name = user.name .. "Button",
                Text = user.name,
                Size = UDim2.new(0.23, 0, 0, 30),
                Position = UDim2.new((i-1) * 0.25, 0, 0, 25),
                BackgroundColor3 = selectedUserId == user.userId and UI_CONSTANTS.COLORS.ACCENT_TEAL or UI_CONSTANTS.COLORS.SECONDARY_BG
            })
            userButton.ZIndex = 102
            
            userButton.MouseButton1Click:Connect(function()
                selectedUserId = user.userId
                -- Update button colors
                for j, u in ipairs(availableUsers) do
                    local button = assignButtons[u.userId]
                    if button then
                        local targetColor = (u.userId == selectedUserId) and UI_CONSTANTS.COLORS.ACCENT_TEAL or UI_CONSTANTS.COLORS.SECONDARY_BG
                        local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = targetColor})
                        tween:Play()
                    end
                end
            end)
            
            assignButtons[user.userId] = userButton
        end
    end
    
    -- Due Date section (editable)
    local dueDateFrame = Instance.new("Frame")
    dueDateFrame.Name = "DueDateFrame"
    dueDateFrame.Parent = dialog
    dueDateFrame.Size = UDim2.new(1, -40, 0, 60)
    dueDateFrame.Position = UDim2.new(0, 20, 0, 445)
    dueDateFrame.BackgroundTransparency = 1
    dueDateFrame.ZIndex = 102
    
    local dueDateLabel = Instance.new("TextLabel")
    dueDateLabel.Name = "DueDateLabel"
    dueDateLabel.Parent = dueDateFrame
    dueDateLabel.Size = UDim2.new(0.5, 0, 0, 20)
    dueDateLabel.Position = UDim2.new(0, 0, 0, 0)
    dueDateLabel.BackgroundTransparency = 1
    dueDateLabel.Text = "Due Date (optional):"
    dueDateLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    dueDateLabel.TextScaled = true
    dueDateLabel.Font = UI_CONSTANTS.FONTS.MAIN
    dueDateLabel.TextXAlignment = Enum.TextXAlignment.Left
    dueDateLabel.ZIndex = 102
    
    local dueDateInput = Instance.new("TextBox")
    dueDateInput.Name = "DueDateInput"
    dueDateInput.Parent = dueDateFrame
    dueDateInput.Size = UDim2.new(0.5, -10, 0, 30)
    dueDateInput.Position = UDim2.new(0.5, 0, 0, 25)
    dueDateInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    dueDateInput.BorderSizePixel = 0
    dueDateInput.Text = task.dueDate and os.date("%m/%d/%Y", task.dueDate) or ""
    dueDateInput.PlaceholderText = "MM/DD/YYYY or days from now..."
    dueDateInput.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    dueDateInput.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    dueDateInput.TextScaled = true
    dueDateInput.Font = UI_CONSTANTS.FONTS.MAIN
    dueDateInput.TextXAlignment = Enum.TextXAlignment.Center
    dueDateInput.ZIndex = 102
    
    local dueDateCorner = Instance.new("UICorner")
    dueDateCorner.CornerRadius = UDim.new(0, 4)
    dueDateCorner.Parent = dueDateInput
    
    -- Quick due date buttons
    local quickDates = {"1 Day", "3 Days", "1 Week"}
    for i, dateText in ipairs(quickDates) do
        local quickButton = createStyledButton(dueDateFrame, {
            Name = dateText .. "Button",
            Text = dateText,
            Size = UDim2.new(0.15, 0, 0, 25),
            Position = UDim2.new((i-1) * 0.16, 0, 0, 0),
            BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_MAGENTA
        })
        quickButton.ZIndex = 102
        
        quickButton.MouseButton1Click:Connect(function()
            local days = 1
            if dateText == "3 Days" then days = 3
            elseif dateText == "1 Week" then days = 7 end
            
            local futureDate = os.time() + (days * 24 * 60 * 60)
            dueDateInput.Text = os.date("%m/%d/%Y", futureDate)
        end)
    end
    
    -- Comments section
    local commentsFrame = createRoundedFrame(dialog, {
        Name = "CommentsFrame",
        Size = UDim2.new(1, -40, 0, 120),
        Position = UDim2.new(0, 20, 0, 515),
        BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
    })
    commentsFrame.ZIndex = 102
    
    local commentsLabel = Instance.new("TextLabel")
    commentsLabel.Name = "CommentsLabel"
    commentsLabel.Parent = commentsFrame
    commentsLabel.Size = UDim2.new(1, -20, 0, 20)
    commentsLabel.Position = UDim2.new(0, 10, 0, 5)
    commentsLabel.BackgroundTransparency = 1
    commentsLabel.Text = "💬 Comments (" .. #task.comments .. ")"
    commentsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    commentsLabel.TextScaled = true
    commentsLabel.Font = UI_CONSTANTS.FONTS.MAIN
    commentsLabel.TextXAlignment = Enum.TextXAlignment.Left
    commentsLabel.ZIndex = 103
    
    -- Add comment input
    local commentInput = Instance.new("TextBox")
    commentInput.Name = "CommentInput"
    commentInput.Parent = commentsFrame
    commentInput.Size = UDim2.new(0.7, 0, 0, 25)
    commentInput.Position = UDim2.new(0, 10, 0, 30)
    commentInput.BackgroundColor3 = UI_CONSTANTS.COLORS.PRIMARY_BG
    commentInput.BorderSizePixel = 0
    commentInput.Text = ""
    commentInput.PlaceholderText = "Add a comment..."
    commentInput.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
    commentInput.PlaceholderColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    commentInput.TextScaled = true
    commentInput.Font = UI_CONSTANTS.FONTS.MAIN
    commentInput.TextXAlignment = Enum.TextXAlignment.Left
    commentInput.ZIndex = 103
    
    local commentInputCorner = Instance.new("UICorner")
    commentInputCorner.CornerRadius = UDim.new(0, 4)
    commentInputCorner.Parent = commentInput
    
    local addCommentButton = createStyledButton(commentsFrame, {
        Name = "AddCommentButton",
        Text = "💬 Add",
        Size = UDim2.new(0.25, 0, 0, 25),
        Position = UDim2.new(0.75, 0, 0, 30),
        BackgroundColor3 = UI_CONSTANTS.COLORS.ACCENT_BLUE
    })
    addCommentButton.ZIndex = 103
    
    addCommentButton.MouseButton1Click:Connect(function()
        local commentText = commentInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if commentText ~= "" then
            local success, error = TaskManager.addComment(task.id, commentText)
            if success then
                commentInput.Text = ""
                commentsLabel.Text = "💬 Comments (" .. (#task.comments + 1) .. ")"
                -- Refresh task data
                task = TaskManager.getTask(task.id)
            else
                print("[TCE] Failed to add comment:", error)
            end
        end
    end)
    
    -- Recent comments display
    local commentsScroll = Instance.new("ScrollingFrame")
    commentsScroll.Name = "CommentsScroll"
    commentsScroll.Parent = commentsFrame
    commentsScroll.Size = UDim2.new(1, -20, 0, 60)
    commentsScroll.Position = UDim2.new(0, 10, 0, 60)
    commentsScroll.BackgroundTransparency = 1
    commentsScroll.BorderSizePixel = 0
    commentsScroll.ScrollBarThickness = 4
    commentsScroll.ScrollBarImageColor3 = UI_CONSTANTS.COLORS.ACCENT_BLUE
    commentsScroll.CanvasSize = UDim2.new(0, 0, 0, #task.comments * 15)
    commentsScroll.ZIndex = 103
    
    -- Show recent comments
    for i = math.max(1, #task.comments - 2), #task.comments do
        local comment = task.comments[i]
        if comment then
            local commentLabel = Instance.new("TextLabel")
            commentLabel.Name = "Comment_" .. i
            commentLabel.Parent = commentsScroll
            commentLabel.Size = UDim2.new(1, -10, 0, 12)
            commentLabel.Position = UDim2.new(0, 5, 0, (i - math.max(1, #task.comments - 2)) * 15)
            commentLabel.BackgroundTransparency = 1
            commentLabel.Text = string.format("%s: %s", comment.author, comment.content)
            commentLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
            commentLabel.TextScaled = true
            commentLabel.Font = UI_CONSTANTS.FONTS.MAIN
            commentLabel.TextXAlignment = Enum.TextXAlignment.Left
            commentLabel.TextTruncate = Enum.TextTruncate.AtEnd
            commentLabel.ZIndex = 104
        end
    end
    
    -- Action buttons
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Parent = dialog
    buttonFrame.Size = UDim2.new(1, -40, 0, 40)
    buttonFrame.Position = UDim2.new(0, 20, 0, 650)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.ZIndex = 102
    
    local cancelButton = createStyledButton(buttonFrame, {
        Name = "CancelButton",
        Text = "Cancel",
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
    })
    cancelButton.ZIndex = 102
    
    cancelButton.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    local saveButton = createStyledButton(buttonFrame, {
        Name = "SaveButton",
        Text = "Save Changes",
        Size = UDim2.new(0.65, 0, 1, 0),
        Position = UDim2.new(0.35, 0, 0, 0),
        BackgroundColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
    })
    saveButton.ZIndex = 102
    
    saveButton.MouseButton1Click:Connect(function()
        local title = titleInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if title == "" then
            -- Show error - title required
            titleInput.BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
            wait(0.5)
            titleInput.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
            return
        end
        
        -- Parse progress
        local progress = tonumber(progressSlider.Text) or task.progress
        if progress < 0 then progress = 0 end
        if progress > 100 then progress = 100 end
        
        -- Parse due date
        local dueDate = nil
        local dueDateText = dueDateInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if dueDateText ~= "" then
            -- Try parsing MM/DD/YYYY format
            local month, day, year = dueDateText:match("(%d+)/(%d+)/(%d+)")
            if month and day and year then
                dueDate = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 23, min = 59, sec = 59})
            else
                -- Try parsing as number of days from now
                local days = tonumber(dueDateText)
                if days then
                    dueDate = os.time() + (days * 24 * 60 * 60)
                end
            end
        end
        
        -- Update the task
        local updates = {
            title = title,
            description = descInput.Text,
            assignedTo = selectedUserId > 0 and selectedUserId or nil,
            dueDate = dueDate,
            priority = selectedPriority,
            status = selectedStatus,
            progress = progress
        }
        
        local success, error = TaskManager.updateTask(task.id, updates)
        
        if success then
            print("[TCE] Updated task:", task.id, "-", title)
            overlay:Destroy()
            
            -- Refresh the tasks panel
            if currentTab == "tasks" then
                UIManager.refreshTasks()
            end
            
            -- Show success notification
            if NotificationManager then
                NotificationManager.sendMessage("Task Updated", 
                    string.format("Successfully updated task: %s", title), "SUCCESS")
            end
        else
            print("[TCE] Failed to update task:", error)
            -- Show error feedback
            saveButton.BackgroundColor3 = UI_CONSTANTS.COLORS.ERROR_RED
            saveButton.Text = "Error: " .. (error or "Unknown")
            wait(2)
            saveButton.BackgroundColor3 = UI_CONSTANTS.COLORS.SUCCESS_GREEN
            saveButton.Text = "Save Changes"
        end
    end)
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
    if not contentPanels.overview then return end
    
    local usersFrame = contentPanels.overview:FindFirstChild("ActiveUsers")
    if not usersFrame then return end
    
    -- Update header
    local usersLabel = usersFrame:FindFirstChild("UsersLabel")
    if usersLabel then
        usersLabel.Text = "Active Users (" .. #users .. ")"
    end
    
    -- Clear existing user entries
    for _, child in pairs(usersFrame:GetChildren()) do
        if child.Name:match("^User_") then
            child:Destroy()
        end
    end
    
    -- Add user entries
    for i, user in ipairs(users) do
        if i <= 3 then -- Show max 3 users in overview
            local userEntry = Instance.new("Frame")
            userEntry.Name = "User_" .. user.userId
            userEntry.Parent = usersFrame
            userEntry.Size = UDim2.new(1, -20, 0, 20)
            userEntry.Position = UDim2.new(0, 10, 0, 30 + (i-1) * 22)
            userEntry.BackgroundTransparency = 1
            
            -- Status dot
            local statusDot = Instance.new("Frame")
            statusDot.Name = "StatusDot"
            statusDot.Parent = userEntry
            statusDot.Size = UDim2.new(0, 8, 0, 8)
            statusDot.Position = UDim2.new(0, 0, 0.5, -4)
            statusDot.BorderSizePixel = 0
            statusDot.BackgroundColor3 = user.status == "Active" and UI_CONSTANTS.COLORS.SUCCESS_GREEN or UI_CONSTANTS.COLORS.TEXT_SECONDARY
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = statusDot
            
            -- User name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Parent = userEntry
            nameLabel.Size = UDim2.new(1, -15, 1, 0)
            nameLabel.Position = UDim2.new(0, 15, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = user.name or ("User " .. user.userId)
            nameLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
            nameLabel.TextScaled = true
            nameLabel.Font = UI_CONSTANTS.FONTS.MAIN
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        end
    end
end

--[[
Updates the session statistics display in the Overview panel.
@param status table: Connection status from ConnectionMonitor
]]
function UIManager.updateSessionStats(status)
    if not contentPanels.overview then return end
    
    local statsFrame = contentPanels.overview:FindFirstChild("Statistics")
    if not statsFrame then return end
    
    -- Clear existing stats
    for _, child in pairs(statsFrame:GetChildren()) do
        if child.Name:match("^Stat_") then
            child:Destroy()
        end
    end
    
    local stats = {
        {label = "Uptime", value = math.floor(status.uptime or 0) .. "s", color = UI_CONSTANTS.COLORS.ACCENT_TEAL},
        {label = "Quality", value = status.quality, color = status.quality == "Excellent" and UI_CONSTANTS.COLORS.SUCCESS_GREEN or UI_CONSTANTS.COLORS.ACCENT_BLUE},
        {label = "Active Users", value = tostring(status.activeUsers or 0), color = UI_CONSTANTS.COLORS.ACCENT_PURPLE}
    }
    
    for i, stat in ipairs(stats) do
        local statEntry = Instance.new("Frame")
        statEntry.Name = "Stat_" .. i
        statEntry.Parent = statsFrame
        statEntry.Size = UDim2.new(1, -20, 0, 20)
        statEntry.Position = UDim2.new(0, 10, 0, 30 + (i-1) * 22)
        statEntry.BackgroundTransparency = 1
        
        local labelText = Instance.new("TextLabel")
        labelText.Name = "Label"
        labelText.Parent = statEntry
        labelText.Size = UDim2.new(0.6, 0, 1, 0)
        labelText.Position = UDim2.new(0, 0, 0, 0)
        labelText.BackgroundTransparency = 1
        labelText.Text = stat.label .. ":"
        labelText.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        labelText.TextScaled = true
        labelText.Font = UI_CONSTANTS.FONTS.MAIN
        labelText.TextXAlignment = Enum.TextXAlignment.Left
        
        local valueText = Instance.new("TextLabel")
        valueText.Name = "Value"
        valueText.Parent = statEntry
        valueText.Size = UDim2.new(0.4, 0, 1, 0)
        valueText.Position = UDim2.new(0.6, 0, 0, 0)
        valueText.BackgroundTransparency = 1
        valueText.Text = stat.value
        valueText.TextColor3 = stat.color
        valueText.TextScaled = true
        valueText.Font = UI_CONSTANTS.FONTS.MAIN
        valueText.TextXAlignment = Enum.TextXAlignment.Right
    end
end

--[[
Updates the recent activity display in the Overview panel.
]]
function UIManager.updateRecentActivity()
    if not contentPanels.overview then return end
    
    local activityFrame = contentPanels.overview:FindFirstChild("RecentActivity")
    if not activityFrame then return end
    
    -- Clear existing activities
    for _, child in pairs(activityFrame:GetChildren()) do
        if child.Name:match("^Activity_") then
            child:Destroy()
        end
    end
    
    -- Get recent notifications/activities
    local activities = {}
    if NotificationManager and NotificationManager.getRecentNotifications then
        local notifications = NotificationManager.getRecentNotifications()
        for i, notification in ipairs(notifications) do
            if i <= 5 then -- Show last 5 activities
                table.insert(activities, {
                    text = notification.title .. ": " .. notification.message,
                    time = os.date("%H:%M:%S", notification.timestamp),
                    type = notification.type
                })
            end
        end
    end
    
    -- Add default activities if none exist
    if #activities == 0 then
        activities = {
            {text = "Plugin initialized successfully", time = os.date("%H:%M:%S"), type = "SUCCESS"},
            {text = "Connection monitoring started", time = os.date("%H:%M:%S"), type = "INFO"},
            {text = "All systems operational", time = os.date("%H:%M:%S"), type = "SUCCESS"}
        }
    end
    
    for i, activity in ipairs(activities) do
        local activityEntry = Instance.new("Frame")
        activityEntry.Name = "Activity_" .. i
        activityEntry.Parent = activityFrame
        activityEntry.Size = UDim2.new(1, -20, 0, 25)
        activityEntry.Position = UDim2.new(0, 10, 0, 30 + (i-1) * 27)
        activityEntry.BackgroundTransparency = 1
        
        -- Activity text
        local activityText = Instance.new("TextLabel")
        activityText.Name = "Text"
        activityText.Parent = activityEntry
        activityText.Size = UDim2.new(0.75, 0, 1, 0)
        activityText.Position = UDim2.new(0, 0, 0, 0)
        activityText.BackgroundTransparency = 1
        activityText.Text = activity.text
        activityText.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
        activityText.TextScaled = true
        activityText.Font = UI_CONSTANTS.FONTS.MAIN
        activityText.TextXAlignment = Enum.TextXAlignment.Left
        activityText.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Time stamp
        local timeText = Instance.new("TextLabel")
        timeText.Name = "Time"
        timeText.Parent = activityEntry
        timeText.Size = UDim2.new(0.25, 0, 1, 0)
        timeText.Position = UDim2.new(0.75, 0, 0, 0)
        timeText.BackgroundTransparency = 1
        timeText.Text = activity.time
        timeText.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        timeText.TextScaled = true
        timeText.Font = UI_CONSTANTS.FONTS.MAIN
        timeText.TextXAlignment = Enum.TextXAlignment.Right
    end
end

--[[
Refreshes the Progress panel with live editing and activity data.
]]
function UIManager.refreshProgress()
    if not contentPanels.progress then return end
    
    -- Update session time
    local sessionTimeLabel = contentPanels.progress:FindFirstChild("SessionTimeLabel")
    if sessionTimeLabel then
        local sessionDuration = os.time() - progressData.sessionStartTime
        local minutes = math.floor(sessionDuration / 60)
        local seconds = sessionDuration % 60
        sessionTimeLabel.Text = string.format("Session: %d:%02d", minutes, seconds)
    end
    
    -- Update edit counts
    local liveEditsFrame = contentPanels.progress:FindFirstChild("LiveEdits")
    if liveEditsFrame then
        local editsStats = liveEditsFrame:FindFirstChild("EditsStats")
        if editsStats then
            local scriptEdits = editsStats:FindFirstChild("ScriptEdits")
            local buildEdits = editsStats:FindFirstChild("BuildEdits")
            local assetEdits = editsStats:FindFirstChild("AssetEdits")
            
            if scriptEdits then scriptEdits.Text = "Scripts: " .. progressData.editCounts.scripts end
            if buildEdits then buildEdits.Text = "Builds: " .. progressData.editCounts.builds end
            if assetEdits then assetEdits.Text = "Assets: " .. progressData.editCounts.assets end
        end
        
        -- Update current selection display
        local currentEditorLabel = liveEditsFrame:FindFirstChild("CurrentEditorLabel")
        if currentEditorLabel then
            local Selection = game:GetService("Selection")
            local selected = Selection:Get()
            
            if #selected > 0 then
                local selectedItem = selected[1]
                local itemType = "Unknown"
                
                if selectedItem:IsA("Script") or selectedItem:IsA("LocalScript") or selectedItem:IsA("ModuleScript") then
                    itemType = "Script"
                elseif selectedItem:IsA("Part") or selectedItem:IsA("Model") or selectedItem:IsA("MeshPart") then
                    itemType = "Build"
                else
                    itemType = "Asset"
                end
                
                currentEditorLabel.Text = string.format("Currently editing: %s (%s)", selectedItem.Name, itemType)
                currentEditorLabel.TextColor3 = UI_CONSTANTS.COLORS.ACCENT_TEAL
                progressData.currentSelection = selectedItem
            else
                currentEditorLabel.Text = "Currently editing: No selection"
                currentEditorLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
                progressData.currentSelection = nil
            end
        end
    end
    
    -- Update user presence
    local presenceFrame = contentPanels.progress:FindFirstChild("UserPresence")
    if presenceFrame then
        UIManager.updateUserPresence(presenceFrame)
    end
    
    -- Update activity timeline
    local timelineFrame = contentPanels.progress:FindFirstChild("ActivityTimeline")
    if timelineFrame then
        UIManager.updateActivityTimeline(timelineFrame)
    end
end

--[[
Updates the user presence display in the Progress panel.
@param presenceFrame Frame: The presence frame to update
]]
function UIManager.updateUserPresence(presenceFrame)
    -- Clear existing presence entries
    for _, child in pairs(presenceFrame:GetChildren()) do
        if child.Name:match("^User_") then
            child:Destroy()
        end
    end
    
    local activeUsers = {}
    if ConnectionMonitor and ConnectionMonitor.getActiveUsers then
        activeUsers = ConnectionMonitor.getActiveUsers()
    end
    
    for i, user in ipairs(activeUsers) do
        if i <= 3 then -- Show max 3 users
            local userEntry = Instance.new("Frame")
            userEntry.Name = "User_" .. i
            userEntry.Parent = presenceFrame
            userEntry.Size = UDim2.new(1, -20, 0, 20)
            userEntry.Position = UDim2.new(0, 10, 0, 25 + (i-1) * 22)
            userEntry.BackgroundTransparency = 1
            
            -- Status indicator
            local statusDot = createStatusIndicator(userEntry, {
                Name = "StatusDot",
                Position = UDim2.new(0, 0, 0.5, -6),
                Color = user.status == "Active" and UI_CONSTANTS.COLORS.SUCCESS_GREEN or UI_CONSTANTS.COLORS.TEXT_SECONDARY,
                Pulse = user.status == "Active"
            })
            
            -- User name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Parent = userEntry
            nameLabel.Size = UDim2.new(0.6, -20, 1, 0)
            nameLabel.Position = UDim2.new(0, 20, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = user.name or ("User " .. user.userId)
            nameLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
            nameLabel.TextScaled = true
            nameLabel.Font = UI_CONSTANTS.FONTS.MAIN
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            -- Activity status
            local activityLabel = Instance.new("TextLabel")
            activityLabel.Name = "ActivityLabel"
            activityLabel.Parent = userEntry
            activityLabel.Size = UDim2.new(0.4, 0, 1, 0)
            activityLabel.Position = UDim2.new(0.6, 0, 0, 0)
            activityLabel.BackgroundTransparency = 1
            activityLabel.Text = user.status == "Active" and "Editing" or "Idle"
            activityLabel.TextColor3 = user.status == "Active" and UI_CONSTANTS.COLORS.ACCENT_TEAL or UI_CONSTANTS.COLORS.TEXT_SECONDARY
            activityLabel.TextScaled = true
            activityLabel.Font = UI_CONSTANTS.FONTS.MAIN
            activityLabel.TextXAlignment = Enum.TextXAlignment.Right
        end
    end
end

--[[
Updates the activity timeline display in the Progress panel.
@param timelineFrame Frame: The timeline frame to update
]]
function UIManager.updateActivityTimeline(timelineFrame)
    -- Clear existing timeline entries
    for _, child in pairs(timelineFrame:GetChildren()) do
        if child.Name:match("^Activity_") then
            child:Destroy()
        end
    end
    
    -- Get recent activities
    local activities = {}
    if NotificationManager and NotificationManager.getRecentNotifications then
        local notifications = NotificationManager.getRecentNotifications()
        for i, notification in ipairs(notifications) do
            if i <= 6 then -- Show last 6 activities
                table.insert(activities, {
                    text = notification.title,
                    detail = notification.message,
                    time = os.date("%H:%M", notification.timestamp),
                    type = notification.type
                })
            end
        end
    end
    
    -- Add default activities if none exist
    if #activities == 0 then
        activities = {
            {text = "Plugin Started", detail = "Team Create Enhancement Plugin loaded", time = os.date("%H:%M"), type = "SUCCESS"},
            {text = "Monitoring Active", detail = "Connection monitoring started", time = os.date("%H:%M"), type = "INFO"}
        }
    end
    
    for i, activity in ipairs(activities) do
        local activityEntry = Instance.new("Frame")
        activityEntry.Name = "Activity_" .. i
        activityEntry.Parent = timelineFrame
        activityEntry.Size = UDim2.new(1, -20, 0, 30)
        activityEntry.Position = UDim2.new(0, 10, 0, 25 + (i-1) * 32)
        activityEntry.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
        activityEntry.BorderSizePixel = 0
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = activityEntry
        
        -- Timeline dot
        local timelineDot = Instance.new("Frame")
        timelineDot.Name = "TimelineDot"
        timelineDot.Parent = activityEntry
        timelineDot.Size = UDim2.new(0, 8, 0, 8)
        timelineDot.Position = UDim2.new(0, -4, 0.5, -4)
        timelineDot.BackgroundColor3 = activity.type == "SUCCESS" and UI_CONSTANTS.COLORS.SUCCESS_GREEN or UI_CONSTANTS.COLORS.ACCENT_BLUE
        timelineDot.BorderSizePixel = 0
        
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = timelineDot
        
        -- Activity text
        local activityText = Instance.new("TextLabel")
        activityText.Name = "ActivityText"
        activityText.Parent = activityEntry
        activityText.Size = UDim2.new(0.7, -10, 0.5, 0)
        activityText.Position = UDim2.new(0, 8, 0, 2)
        activityText.BackgroundTransparency = 1
        activityText.Text = activity.text
        activityText.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
        activityText.TextScaled = true
        activityText.Font = UI_CONSTANTS.FONTS.MAIN
        activityText.TextXAlignment = Enum.TextXAlignment.Left
        activityText.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Activity detail
        local activityDetail = Instance.new("TextLabel")
        activityDetail.Name = "ActivityDetail"
        activityDetail.Parent = activityEntry
        activityDetail.Size = UDim2.new(0.7, -10, 0.5, 0)
        activityDetail.Position = UDim2.new(0, 8, 0.5, 0)
        activityDetail.BackgroundTransparency = 1
        activityDetail.Text = activity.detail
        activityDetail.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        activityDetail.TextScaled = true
        activityDetail.Font = UI_CONSTANTS.FONTS.MAIN
        activityDetail.TextXAlignment = Enum.TextXAlignment.Left
        activityDetail.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Time stamp
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Name = "TimeLabel"
        timeLabel.Parent = activityEntry
        timeLabel.Size = UDim2.new(0.3, 0, 1, 0)
        timeLabel.Position = UDim2.new(0.7, 0, 0, 0)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = activity.time
        timeLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        timeLabel.TextScaled = true
        timeLabel.Font = UI_CONSTANTS.FONTS.MAIN
        timeLabel.TextXAlignment = Enum.TextXAlignment.Right
    end
end

--[[
Tracks an edit action for progress monitoring.
@param editType string: Type of edit (script/build/asset)
]]
function UIManager.trackEdit(editType)
    if editType == "script" then
        progressData.editCounts.scripts = progressData.editCounts.scripts + 1
    elseif editType == "build" then
        progressData.editCounts.builds = progressData.editCounts.builds + 1
    elseif editType == "asset" then
        progressData.editCounts.assets = progressData.editCounts.assets + 1
    end
    
    -- Add to recent activity
    table.insert(progressData.recentActivity, {
        type = editType,
        timestamp = os.time(),
        item = progressData.currentSelection and progressData.currentSelection.Name or "Unknown"
    })
    
    -- Keep only last 10 activities
    if #progressData.recentActivity > 10 then
        table.remove(progressData.recentActivity, 1)
    end
end

--[[
Resets progress tracking data for a new session.
]]
function UIManager.resetProgressData()
    progressData.sessionStartTime = os.time()
    progressData.editCounts.scripts = 0
    progressData.editCounts.builds = 0
    progressData.editCounts.assets = 0
    progressData.currentSelection = nil
    progressData.recentActivity = {}
    progressData.userActivity = {}
    
    if NotificationManager then
        NotificationManager.sendMessage("Progress Reset", "Progress tracking data has been reset", "INFO")
    end
    
    print("[TCE] Progress data reset for new session")
end

--[[
Gets the current progress statistics.
@return table: Progress stats
]]
function UIManager.getProgressStats()
    local totalEdits = progressData.editCounts.scripts + progressData.editCounts.builds + progressData.editCounts.assets
    local sessionDuration = os.time() - progressData.sessionStartTime
    
    return {
        sessionDuration = sessionDuration,
        totalEdits = totalEdits,
        editCounts = progressData.editCounts,
        editsPerMinute = sessionDuration > 0 and (totalEdits / (sessionDuration / 60)) or 0,
        currentSelection = progressData.currentSelection,
        recentActivity = progressData.recentActivity
    }
end

--[[
Refreshes the Notifications panel with recent notification data.
]]
function UIManager.refreshNotifications()
    if not contentPanels.notifications then return end
    
    local recentFrame = contentPanels.notifications:FindFirstChild("RecentNotifications")
    if not recentFrame then return end
    
    -- Update header
    local recentLabel = recentFrame:FindFirstChild("RecentLabel")
    local notifications = {}
    local notificationCount = 0
    
    if NotificationManager and NotificationManager.getRecentNotifications then
        notifications = NotificationManager.getRecentNotifications()
        notificationCount = NotificationManager.getNotificationCount and NotificationManager.getNotificationCount() or #notifications
    end
    
    if recentLabel then
        recentLabel.Text = "Recent Notifications (" .. notificationCount .. " total)"
    end
    
    -- Clear existing notification entries
    for _, child in pairs(recentFrame:GetChildren()) do
        if child.Name:match("^Notif_") then
            child:Destroy()
        end
    end
    
    -- Add notification entries
    for i, notification in ipairs(notifications) do
        if i <= 8 then -- Show max 8 notifications in panel
            local notifEntry = Instance.new("Frame")
            notifEntry.Name = "Notif_" .. i
            notifEntry.Parent = recentFrame
            notifEntry.Size = UDim2.new(1, -20, 0, 40)
            notifEntry.Position = UDim2.new(0, 10, 0, 30 + (i-1) * 42)
            notifEntry.BackgroundColor3 = UI_CONSTANTS.COLORS.SECONDARY_BG
            notifEntry.BorderSizePixel = 0
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = notifEntry
            
            -- Type icon
            local typeIcons = {
                INFO = "ℹ️",
                SUCCESS = "✅",
                WARNING = "⚠️",
                ERROR = "❌",
                USER = "👤"
            }
            
            local iconLabel = Instance.new("TextLabel")
            iconLabel.Name = "IconLabel"
            iconLabel.Parent = notifEntry
            iconLabel.Size = UDim2.new(0, 30, 0, 20)
            iconLabel.Position = UDim2.new(0, 5, 0, 2)
            iconLabel.BackgroundTransparency = 1
            iconLabel.Text = typeIcons[notification.type] or "📝"
            iconLabel.TextScaled = true
            iconLabel.Font = UI_CONSTANTS.FONTS.MAIN
            
            -- Title
            local titleLabel = Instance.new("TextLabel")
            titleLabel.Name = "TitleLabel"
            titleLabel.Parent = notifEntry
            titleLabel.Size = UDim2.new(1, -80, 0, 18)
            titleLabel.Position = UDim2.new(0, 35, 0, 2)
            titleLabel.BackgroundTransparency = 1
            titleLabel.Text = notification.title
            titleLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_PRIMARY
            titleLabel.TextScaled = true
            titleLabel.Font = UI_CONSTANTS.FONTS.MAIN
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Message
            local messageLabel = Instance.new("TextLabel")
            messageLabel.Name = "MessageLabel"
            messageLabel.Parent = notifEntry
            messageLabel.Size = UDim2.new(1, -80, 0, 16)
            messageLabel.Position = UDim2.new(0, 35, 0, 20)
            messageLabel.BackgroundTransparency = 1
            messageLabel.Text = notification.message
            messageLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
            messageLabel.TextScaled = true
            messageLabel.Font = UI_CONSTANTS.FONTS.MAIN
            messageLabel.TextXAlignment = Enum.TextXAlignment.Left
            messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
            
            -- Time
            local timeLabel = Instance.new("TextLabel")
            timeLabel.Name = "TimeLabel"
            timeLabel.Parent = notifEntry
            timeLabel.Size = UDim2.new(0, 40, 1, 0)
            timeLabel.Position = UDim2.new(1, -45, 0, 0)
            timeLabel.BackgroundTransparency = 1
            timeLabel.Text = os.date("%H:%M", notification.timestamp)
            timeLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
            timeLabel.TextScaled = true
            timeLabel.Font = UI_CONSTANTS.FONTS.MAIN
            timeLabel.TextXAlignment = Enum.TextXAlignment.Right
        end
    end
    
    -- Show "No notifications" if empty
    if #notifications == 0 then
        local noNotifsLabel = Instance.new("TextLabel")
        noNotifsLabel.Name = "Notif_None"
        noNotifsLabel.Parent = recentFrame
        noNotifsLabel.Size = UDim2.new(1, -20, 0, 40)
        noNotifsLabel.Position = UDim2.new(0, 10, 0, 60)
        noNotifsLabel.BackgroundTransparency = 1
        noNotifsLabel.Text = "No notifications yet"
        noNotifsLabel.TextColor3 = UI_CONSTANTS.COLORS.TEXT_SECONDARY
        noNotifsLabel.TextScaled = true
        noNotifsLabel.Font = UI_CONSTANTS.FONTS.MAIN
        noNotifsLabel.TextXAlignment = Enum.TextXAlignment.Center
    end
end

--[[
Adds an activity log entry to the UI.
@param message string: Activity message
]]
function UIManager.addActivityLog(message)
    -- Add to internal activity feed and refresh if overview is active
    print("[TCE] Activity:", message)
    if currentTab == "overview" then
        UIManager.updateRecentActivity()
    elseif currentTab == "notifications" then
        UIManager.refreshNotifications()
    end
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
    -- Stop auto-refresh
    UIManager.stopAutoRefresh()
    
    if mainFrame then
        mainFrame:Destroy()
        mainFrame = nil
    end
    contentPanels = {}
    tabButtons = {}
    print("[TCE] UI cleaned up")
end

return UIManager 