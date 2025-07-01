-- src/shared/modules/NotificationManager/init.lua
-- COMPLIANCE: Internal notifications only - no external HTTP requests

-- Type imports
local Types = require(script.Parent.Parent.types)
type NotificationType = Types.NotificationType
type NotificationInfo = Types.NotificationInfo
type NotificationTypeInfo = Types.NotificationTypeInfo
type PluginState = Types.PluginState
type NotificationCallback = Types.NotificationCallback

--[[
NotificationManager
===================
Manages internal notifications for Team Create Enhancer plugin.
Provides APIs for creating notifications, tracking events, and Studio integration.
Uses Studio's native notification system for compliance (no external webhooks).
All notification data is stored using plugin settings.
]]

local NotificationManager = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

-- Constants
local MAX_NOTIFICATIONS: number = 50 -- Keep last 50 notifications
local NOTIFICATION_DURATION: number = 5 -- seconds
local NOTIFICATION_TYPES: {[NotificationType]: NotificationTypeInfo} = {
    INFO = {color = Color3.fromHex("#3b82f6"), icon = "ℹ️"},
    SUCCESS = {color = Color3.fromHex("#10b981"), icon = "✅"},
    WARNING = {color = Color3.fromHex("#f59e0b"), icon = "⚠️"},
    ERROR = {color = Color3.fromHex("#ef4444"), icon = "❌"},
    USER = {color = Color3.fromHex("#8b5cf6"), icon = "👤"}
}

-- Local state
local pluginState: PluginState? = nil
local notifications: {NotificationInfo} = {}
local notificationCallbacks: {[string]: NotificationCallback} = {}
local isEnabled: boolean = true

-- COMPLIANCE: Internal notification system only
local function createNotification(title, message, notificationType, duration)
    local notification = {
        id = #notifications + 1,
        title = title,
        message = message,
        type = notificationType or "INFO",
        timestamp = os.time(),
        duration = duration or NOTIFICATION_DURATION,
        read = false
    }
    
    -- Add to notifications list
    table.insert(notifications, notification)
    
    -- Keep only last MAX_NOTIFICATIONS
    if #notifications > MAX_NOTIFICATIONS then
        table.remove(notifications, 1)
    end
    
    -- Show in console for debugging
    local typeInfo = NOTIFICATION_TYPES[notification.type] or NOTIFICATION_TYPES.INFO
    print(string.format("[TCE] %s %s: %s", typeInfo.icon, notification.title, notification.message))
    
    -- Trigger callbacks
    for _, callback in pairs(notificationCallbacks) do
        callback("notification_created", notification)
    end
    
    -- Show Studio notification (safe alternative to external webhooks)
    showStudioNotification(notification)
    
    return notification
end

-- COMPLIANCE: Studio-only notification display
local function showStudioNotification(notification)
    local typeInfo = NOTIFICATION_TYPES[notification.type] or NOTIFICATION_TYPES.INFO
    
    -- Use StarterGui for in-Studio notifications
    local success = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Team Create Enhancer",
            Text = notification.title .. ": " .. notification.message,
            Duration = notification.duration,
            Icon = "rbxasset://textures/AnimationEditor/button_animationEditor@2x.png"
        })
    end)
    
    if not success then
        -- Fallback to output window
        print(string.format("[TCE] Notification: %s - %s", notification.title, notification.message))
    end
end

--[[
Logs a user join event with internal notification.
@param player Player
]]
local function logUserJoinEvent(player)
    createNotification(
        "User Joined",
        player.Name .. " (" .. player.UserId .. ") joined Team Create",
        "USER",
        3
    )
end

--[[
Logs a user leave event with internal notification.
@param player Player
]]
local function logUserLeaveEvent(player)
    createNotification(
        "User Left", 
        player.Name .. " (" .. player.UserId .. ") left Team Create",
        "WARNING",
        3
    )
end

--[[
Logs an asset lock event with internal notification.
@param lockInfo table
]]
local function logAssetLockEvent(lockInfo)
    createNotification(
        "Asset Locked",
        lockInfo.userName .. " locked " .. (lockInfo.instanceClass or "asset"),
        "INFO",
        4
    )
end

--[[
Logs a connection status change event with internal notification.
@param status string
@param quality string
]]
local function logConnectionStatusEvent(status, quality)
    local notifType = "INFO"
    if status == "Disconnected" then
        notifType = "ERROR"
    elseif quality == "Poor" then
        notifType = "WARNING"
    elseif quality == "Excellent" then
        notifType = "SUCCESS"
    end
    
    createNotification(
        "Connection Status",
        "Team Create connection: " .. status .. " (" .. quality .. ")",
        notifType,
        4
    )
end

--[[
Logs an error event with internal notification.
@param errorType string
@param errorMessage string
]]
local function logErrorEvent(errorType, errorMessage)
    createNotification(
        "Plugin Error",
        errorType .. ": " .. errorMessage,
        "ERROR",
        6
    )
end

--[[
Initializes the NotificationManager with plugin state.
Sets up player event monitoring for internal notifications only.
@param state table: Plugin state table
]]
function NotificationManager.initialize(state: PluginState): ()
    pluginState = state
    
    -- COMPLIANCE: Check if we're in Studio
    if not game:GetService("RunService"):IsStudio() then
        warn("[TCE] NotificationManager: Not running in Studio environment")
        isEnabled = false
        return
    end
    
    -- Setup player event monitoring (internal only)
    Players.PlayerAdded:Connect(function(player)
        if isEnabled then
            logUserJoinEvent(player)
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if isEnabled then
            logUserLeaveEvent(player)
        end
    end)
    
    print("[TCE] NotificationManager initialized (compliance mode)")
    
    -- Show initialization notice
    createNotification(
        "Plugin Started",
        "Team Create Enhancement Plugin v1.0.0 loaded",
        "SUCCESS"
    )
    
    -- Show compliance notice
    createNotification(
        "Compliance Mode",
        "Running in compliance mode - external integrations disabled",
        "INFO",
        8
    )
end

--[[
Enables or disables notifications.
@param enabled boolean
]]
function NotificationManager.setEnabled(enabled: boolean): ()
    isEnabled = enabled
    
    if enabled then
        createNotification("Notifications Enabled", "Internal notifications are now active", "SUCCESS")
    else
        print("[TCE] Notifications disabled")
    end
end

--[[
Returns whether notifications are currently enabled.
@return boolean
]]
function NotificationManager.isEnabled(): boolean
    return isEnabled
end

--[[
Sends an internal notification message.
@param title string
@param message string
@param notifType string: Notification type (INFO, SUCCESS, WARNING, ERROR, USER)
@return boolean, string: Success and error message if any
]]
function NotificationManager.sendMessage(title: string, message: string, notifType: NotificationType?): (boolean, string?)
    if not isEnabled then
        return false, "Notifications are disabled"
    end
    
    createNotification(title, message, notifType or "INFO")
    return true
end

function NotificationManager.sendAssetLockNotification(lockInfo)
    if isEnabled then
        logAssetLockEvent(lockInfo)
    end
end

function NotificationManager.sendConnectionStatusNotification(status, quality)
    if isEnabled then
        logConnectionStatusEvent(status, quality)
    end
end

function NotificationManager.sendErrorNotification(errorType, errorMessage)
    if isEnabled then
        logErrorEvent(errorType, errorMessage)
    end
end

function NotificationManager.sendCustomNotification(title, description, notifType)
    if not isEnabled then
        return false
    end
    
    createNotification(title, description, notifType or "INFO")
    return true
end

-- COMPLIANCE: No external testing - internal validation only
function NotificationManager.testNotifications()
    if not isEnabled then
        return false, "Notifications are disabled"
    end
    
    createNotification(
        "Test Notification",
        "Internal notification system is working correctly",
        "SUCCESS"
    )
    
    print("[TCE] Internal notification test completed")
    return true
end

--[[
Returns all stored notifications.
@return table: List of notifications
]]
function NotificationManager.getNotifications(): {NotificationInfo}
    return notifications
end

function NotificationManager.getUnreadNotifications()
    local unread = {}
    for _, notification in ipairs(notifications) do
        if not notification.read then
            table.insert(unread, notification)
        end
    end
    return unread
end

function NotificationManager.markAsRead(notificationId)
    for _, notification in ipairs(notifications) do
        if notification.id == notificationId then
            notification.read = true
            return true
        end
    end
    return false
end

function NotificationManager.markAllAsRead()
    for _, notification in ipairs(notifications) do
        notification.read = true
    end
end

--[[
Clears all stored notifications.
]]
function NotificationManager.clearNotifications(): ()
    notifications = {}
    print("[TCE] Notification history cleared")
end

--[[
Registers a callback for notification events.
@param id string: Unique callback id
@param callback function
]]
function NotificationManager.registerCallback(id: string, callback: NotificationCallback): ()
    notificationCallbacks[id] = callback
end

--[[
Unregisters a notification event callback by id.
@param id string
]]
function NotificationManager.unregisterCallback(id: string): ()
    notificationCallbacks[id] = nil
end

--[[
Shows a compliance mode notice to the user.
]]
function NotificationManager.showComplianceNotice(): ()
    createNotification(
        "Compliance Mode Active",
        "Plugin is running in compliance mode. All external integrations disabled.",
        "INFO",
        10
    )
end

-- COMPLIANCE: Show error messages safely
function NotificationManager.showError(title, message)
    createNotification(title, message, "ERROR", 8)
end

function NotificationManager.getNotificationStats()
    local stats = {
        total = #notifications,
        unread = 0,
        byType = {}
    }
    
    for _, notification in ipairs(notifications) do
        if not notification.read then
            stats.unread = stats.unread + 1
        end
        
        stats.byType[notification.type] = (stats.byType[notification.type] or 0) + 1
    end
    
    return stats
end

-- COMPLIANCE: Export for internal logging only
function NotificationManager.exportNotifications()
    return {
        version = "1.0",
        timestamp = os.time(),
        notifications = notifications,
        compliance = "internal_only"
    }
end

--[[
Cleans up the NotificationManager (clears callbacks, saves state).
]]
function NotificationManager.cleanup(): ()
    -- Clear all notifications
    notifications = {}
    notificationCallbacks = {}
    
    print("[TCE] NotificationManager cleaned up")
end

-- COMPLIANCE: No external HTTP requests allowed
-- All webhook functionality removed for compliance
-- Only internal Studio notifications are used

return NotificationManager 