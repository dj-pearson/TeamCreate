-- src/init.lua
-- Team Create Enhancement Plugin - Main Entry Point
-- Rojo/Argon Compatible Structure

-- Type imports
local Types = require(script.shared.types)
type PluginState = Types.PluginState
type UIConstants = Types.UIConstants
type ModuleReferences = Types.ModuleReferences

local plugin = plugin or getfenv().PluginManager():CreatePlugin()

-- Core Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StudioService = game:GetService("StudioService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Plugin Info
local PLUGIN_NAME: string = "Team Create Enhancer"
local PLUGIN_VERSION: string = "1.0.0"

-- UI Constants based on PRD Style Guide
local UI_CONSTANTS: UIConstants = {
    COLORS = {
        PRIMARY_BG = Color3.fromHex("#0f111a"),
        SECONDARY_BG = Color3.fromHex("#1a1d29"),
        ACCENT_BLUE = Color3.fromHex("#00d4ff"),
        ACCENT_PURPLE = Color3.fromHex("#8b5cf6"),
        ACCENT_MAGENTA = Color3.fromHex("#f472b6"),
        ACCENT_TEAL = Color3.fromHex("#14b8a6"),
        TEXT_PRIMARY = Color3.fromHex("#ffffff"),
        TEXT_SECONDARY = Color3.fromHex("#a1a1aa"),
        SUCCESS_GREEN = Color3.fromHex("#10b981"),
        ERROR_RED = Color3.fromHex("#ef4444")
    },
    FONTS = {
        MAIN = Enum.Font.Gotham,
        HEADER = Enum.Font.GothamBold
    },
    SIZES = {
        HEADER = 18,
        SUBTEXT = 12,
        DATA = 16,
        CORNER_RADIUS = 8,
        GLOW_SIZE = 4
    }
}

-- Plugin State
local pluginState: PluginState = {
    isEnabled = false,
    currentUser = Players.LocalPlayer,
    teamCreateSession = nil,
    userRoles = {},
    assetLocks = {},
    connectionStatus = "Connected",
    complianceMode = true -- COMPLIANCE: Ensures no external HTTP requests
}

-- Core Modules (Rojo structure)
local UIManager = require(script.shared.modules.UIManager)
local PermissionManager = require(script.shared.modules.PermissionManager)
local ConnectionMonitor = require(script.shared.modules.ConnectionMonitor)
local AssetLockManager = require(script.shared.modules.AssetLockManager)
local NotificationManager = require(script.shared.modules.NotificationManager) -- Compliant notifications
local ConflictResolver = require(script.shared.modules.ConflictResolver)
local TaskManager = require(script.shared.modules.TaskManager)

-- Main Plugin GUI
local dockWidget: DockWidgetPluginGui = plugin:CreateDockWidgetPluginGui(
    "TeamCreateEnhancer",
    DockWidgetPluginGuiInfo.new(
        Enum.InitialDockState.Left,
        false, -- Initially disabled
        false, -- Don't override previous enabled state
        350, -- Default width
        500, -- Default height
        300, -- Min width
        400  -- Min height
    )
)

dockWidget.Title = PLUGIN_NAME
dockWidget.Name = "TeamCreateEnhancer"

-- Compliance Check
local function verifyCompliance(): boolean
    -- COMPLIANCE: Ensure no external HTTP requests are enabled
    local httpEnabled = game:GetService("HttpService").HttpEnabled
    
    if httpEnabled then
        warn("[TCE] COMPLIANCE WARNING: HTTP Service is enabled. External integrations disabled for compliance.")
        pluginState.complianceMode = true
    end
    
    -- COMPLIANCE: Check Studio API access
    local hasStudioAccess = pcall(function()
        return game:GetService("DataStoreService"):GetDataStore("TestStore")
    end)
    
    if not hasStudioAccess then
        print("[TCE] Studio API access not enabled - some features may be limited")
    end
    
    return true
end

-- Initialize Plugin
local function initializePlugin(): ()
    print("[TCE] Initializing Team Create Enhancement Plugin v" .. PLUGIN_VERSION)
    
    -- COMPLIANCE: Verify compliance before starting
    verifyCompliance()
    
    -- Setup UI
    UIManager.initialize(dockWidget, UI_CONSTANTS)
    
    -- Initialize core systems
    PermissionManager.initialize(pluginState)
    ConnectionMonitor.initialize(pluginState)
    AssetLockManager.initialize(pluginState)
    NotificationManager.initialize(pluginState) -- Compliant notifications only
    ConflictResolver.initialize(pluginState)
    TaskManager.initialize(pluginState)
    
    -- Set up module cross-references for UI integration
    local moduleRefs: ModuleReferences = {
        PermissionManager = PermissionManager,
        AssetLockManager = AssetLockManager,
        ConnectionMonitor = ConnectionMonitor,
        NotificationManager = NotificationManager,
        ConflictResolver = ConflictResolver,
        TaskManager = TaskManager
    }
    UIManager.setModuleReferences(moduleRefs)
    
    -- Set up module cross-references for backend integration
    AssetLockManager.setPermissionManager(PermissionManager)
    ConflictResolver.setAssetLockManager(AssetLockManager)
    ConflictResolver.setPermissionManager(PermissionManager)
    TaskManager.setModuleReferences(PermissionManager, NotificationManager)
    
    -- Setup plugin toolbar
    local toolbar = plugin:CreateToolbar("Team Create Enhancer")
    local toggleButton = toolbar:CreateButton(
        "TCE",
        "Toggle Team Create Enhancement Panel",
        "rbxassetid://75806853590546"
    )
    
    toggleButton.Click:Connect(function()
        dockWidget.Enabled = not dockWidget.Enabled
        pluginState.isEnabled = dockWidget.Enabled
        
        if pluginState.isEnabled then
            UIManager.refresh()
            ConnectionMonitor.startMonitoring()
        else
            ConnectionMonitor.stopMonitoring()
        end
    end)
    
    -- Auto-enable if in Team Create
    local teamCreateSettings = nil
    local success = pcall(function()
        teamCreateSettings = StudioService:GetCurrentTeamCreateSettings()
    end)
    
    if success and teamCreateSettings then
        dockWidget.Enabled = true
        pluginState.isEnabled = true
        ConnectionMonitor.startMonitoring()
        
        -- Show compliance notice
        if pluginState.complianceMode then
            NotificationManager.showComplianceNotice()
        end
        
        -- Initial UI refresh
        UIManager.refresh()
    end
    
    print("[TCE] Plugin initialized successfully!")
end

-- COMPLIANCE: Safe cleanup function
local function cleanup(): ()
    print("[TCE] Cleaning up plugin...")
    ConnectionMonitor.stopMonitoring()
    UIManager.cleanup()
    AssetLockManager.cleanup()
    TaskManager.cleanup()
    
    -- COMPLIANCE: Ensure no external connections remain
    NotificationManager.cleanup()
end

-- Plugin lifecycle
plugin.Unloading:Connect(cleanup)

-- COMPLIANCE: Error handling wrapper
local function safeInitialize(): ()
    local success, error = pcall(initializePlugin)
    if not success then
        warn("[TCE] Plugin initialization failed:", error)
        -- Show user-friendly error
        NotificationManager.showError("Plugin Initialization Failed", error)
    end
end

-- Initialize the plugin safely
safeInitialize()

-- COMPLIANCE: Export plugin info for debugging
return {
    name = PLUGIN_NAME,
    version = PLUGIN_VERSION,
    complianceMode = pluginState.complianceMode,
    modules = {
        "UIManager",
        "PermissionManager", 
        "ConnectionMonitor",
        "AssetLockManager",
        "NotificationManager",
        "ConflictResolver"
    }
} 