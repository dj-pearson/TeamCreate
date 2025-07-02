-- src/shared/modules/ConflictResolver/init.lua
-- Handles basic conflict resolution with warnings and temporary locks
-- COMPLIANCE: No external dependencies, Studio-only operations

-- Type imports
local Types = require(script.Parent.Parent.types)
type UserId = Types.UserId
type InstancePath = Types.InstancePath
type ConflictInfo = Types.ConflictInfo
type ConflictStats = Types.ConflictStats
type PluginState = Types.PluginState
type ConflictCallback = Types.ConflictCallback
type ConflictExportData = Types.ConflictExportData

--[[
ConflictResolver
================
Manages edit conflicts when multiple users edit the same assets simultaneously.
Provides APIs for conflict detection, warning UI, and resolution strategies.
Integrates with AssetLockManager for conflict prevention via locks.
All conflict data is stored using plugin settings for compliance.
]]

local ConflictResolver = {}

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Selection = game:GetService("Selection")

-- Constants
local CONFLICT_WARNING_DURATION: number = 5 -- seconds
local AUTO_RESOLVE_TIMEOUT: number = 30 -- seconds
local EDIT_DETECTION_DELAY: number = 1 -- second

-- Local state
local pluginState: PluginState? = nil
local activeConflicts: {[number]: ConflictInfo} = {}
local editTimestamps: {[InstancePath]: any} = {}
local conflictCallbacks: {[string]: ConflictCallback} = {}
local AssetLockManager: any = nil
local PermissionManager: any = nil

-- Utility functions
local function getInstancePath(instance)
    if not instance then return nil end
    
    local path = {}
    local current = instance
    
    while current and current.Parent do
        table.insert(path, 1, current.Name)
        current = current.Parent
        
        if current == workspace or current == game then
            break
        end
    end
    
    return table.concat(path, "/")
end

-- COMPLIANCE: Safe data storage
local function saveConflictData()
    local success, error = pcall(function()
        if plugin then
            -- Store only essential conflict metadata
            local conflictMeta = {}
            for id, conflict in pairs(activeConflicts) do
                if conflict.status == "active" then
                    conflictMeta[id] = {
                        instancePath = conflict.instancePath,
                        users = conflict.users,
                        timestamp = conflict.timestamp,
                        status = conflict.status
                    }
                end
            end
            plugin:SetSetting("TCE_ActiveConflicts", conflictMeta)
        end
    end)
    
    if not success then
        warn("[TCE] Failed to save conflict data:", error)
    end
end

local function loadConflictData()
    local success, savedConflicts = pcall(function()
        if plugin then
            return plugin:GetSetting("TCE_ActiveConflicts")
        end
        return {}
    end)
    
    if success and savedConflicts then
        activeConflicts = savedConflicts
        print("[TCE] Loaded conflict data")
    end
end

local function resolveConflict(conflictId, resolution)
    local conflict = activeConflicts[conflictId]
    if not conflict then return end
    
    conflict.status = "resolved"
    conflict.resolution = resolution
    conflict.resolvedAt = os.time()
    
    -- Clean up warning GUI
    if conflict.warningGui and conflict.warningGui.Parent then
        conflict.warningGui:Destroy()
    end
    
    print("[TCE] Conflict resolved:", conflictId, "via", resolution)
    
    -- COMPLIANCE: Save updated conflict data
    saveConflictData()
    
    -- Trigger callbacks
    for _, callback in pairs(conflictCallbacks) do
        callback("conflict_resolved", conflict)
    end
end

local function showConflictWarningUI(conflict)
    -- COMPLIANCE: Create safe warning GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TCE_ConflictWarning"
    if game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerGui then
        screenGui.Parent = game.Players.LocalPlayer.PlayerGui
    end
    screenGui.ResetOnSpawn = false
    
    -- Main frame with modern dark styling
    local frame = Instance.new("Frame")
    frame.Name = "WarningFrame"
    frame.Size = UDim2.new(0, 400, 0, 200)
    frame.Position = UDim2.new(0.5, -200, 0.2, 0)
    frame.BackgroundColor3 = Color3.fromHex("#1a1d29")
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Border glow
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("#f59e0b") -- Warning amber
    stroke.Thickness = 2
    stroke.Parent = frame
    
    -- Warning icon
    local icon = Instance.new("TextLabel")
    icon.Name = "WarningIcon"
    icon.Size = UDim2.new(0, 40, 0, 40)
    icon.Position = UDim2.new(0, 20, 0, 20)
    icon.BackgroundTransparency = 1
    icon.Text = "⚠️"
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.Parent = frame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -80, 0, 30)
    title.Position = UDim2.new(0, 70, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "EDIT CONFLICT DETECTED"
    title.TextColor3 = Color3.fromHex("#ffffff")
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    -- Description
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, -40, 0, 60)
    description.Position = UDim2.new(0, 20, 0, 50)
    description.BackgroundTransparency = 1
    description.Text = "Another user is currently editing this asset. Simultaneous editing may cause conflicts."
    description.TextColor3 = Color3.fromHex("#a1a1aa")
    description.TextScaled = true
    description.Font = Enum.Font.Gotham
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.Parent = frame
    
    -- Asset info
    local assetInfo = Instance.new("TextLabel")
    assetInfo.Name = "AssetInfo"
    assetInfo.Size = UDim2.new(1, -40, 0, 25)
    assetInfo.Position = UDim2.new(0, 20, 0, 115)
    assetInfo.BackgroundTransparency = 1
    assetInfo.Text = "Asset: " .. (conflict.instance.Name or "Unknown")
    assetInfo.TextColor3 = Color3.fromHex("#14b8a6")
    assetInfo.TextScaled = true
    assetInfo.Font = Enum.Font.GothamMedium
    assetInfo.TextXAlignment = Enum.TextXAlignment.Left
    assetInfo.Parent = frame
    
    -- Action buttons
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Size = UDim2.new(1, -40, 0, 40)
    buttonFrame.Position = UDim2.new(0, 20, 0, 145)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = frame
    
    -- Lock button
    local lockButton = Instance.new("TextButton")
    lockButton.Name = "LockButton"
    lockButton.Size = UDim2.new(0.48, 0, 1, 0)
    lockButton.Position = UDim2.new(0, 0, 0, 0)
    lockButton.BackgroundColor3 = Color3.fromHex("#f59e0b")
    lockButton.BorderSizePixel = 0
    lockButton.Text = "🔒 Lock Asset"
    lockButton.TextColor3 = Color3.fromHex("#ffffff")
    lockButton.TextScaled = true
    lockButton.Font = Enum.Font.GothamMedium
    lockButton.Parent = buttonFrame
    
    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 4)
    lockCorner.Parent = lockButton
    
    -- Cancel button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Name = "CancelButton"
    cancelButton.Size = UDim2.new(0.48, 0, 1, 0)
    cancelButton.Position = UDim2.new(0.52, 0, 0, 0)
    cancelButton.BackgroundColor3 = Color3.fromHex("#6b7280")
    cancelButton.BorderSizePixel = 0
    cancelButton.Text = "❌ Cancel Edit"
    cancelButton.TextColor3 = Color3.fromHex("#ffffff")
    cancelButton.TextScaled = true
    cancelButton.Font = Enum.Font.GothamMedium
    cancelButton.Parent = buttonFrame
    
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 4)
    cancelCorner.Parent = cancelButton
    
    -- Button handlers
    lockButton.MouseButton1Click:Connect(function()
        if AssetLockManager then
            local success, message = AssetLockManager.lockAsset(conflict.instance, "conflict")
            if success then
                resolveConflict(conflict.id, "locked")
            else
                warn("[TCE] Failed to lock asset:", message)
            end
        end
        screenGui:Destroy()
    end)
    
    cancelButton.MouseButton1Click:Connect(function()
        resolveConflict(conflict.id, "cancelled")
        screenGui:Destroy()
    end)
    
    -- Auto-close after duration
    spawn(function()
        wait(CONFLICT_WARNING_DURATION)
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
    
    conflict.warningShown = true
    conflict.warningGui = screenGui
end

-- Conflict detection and resolution
local function detectEditConflict(instance, userId)
    local instancePath = getInstancePath(instance)
    if not instancePath then return false end
    
    local currentTime = os.time()
    local existingEdit = editTimestamps[instancePath]
    
    -- Check if someone else is already editing
    if existingEdit and existingEdit.userId ~= userId then
        local timeDiff = currentTime - existingEdit.timestamp
        
        -- If edit is recent (within detection delay), it's a conflict
        if timeDiff < EDIT_DETECTION_DELAY * 2 then
            return true, existingEdit.userId
        end
    end
    
    -- Record this edit
    editTimestamps[instancePath] = {
        userId = userId,
        timestamp = currentTime,
        userName = Players:GetPlayerByUserId(userId) and Players:GetPlayerByUserId(userId).Name or "Unknown"
    }
    
    return false, nil
end

local function createConflictWarning(instance, conflictingUserId)
    local conflictId = #activeConflicts + 1
    local currentUser = Players and Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    
    local conflict = {
        id = conflictId,
        instance = instance,
        instancePath = getInstancePath(instance),
        users = {currentUser, conflictingUserId},
        timestamp = os.time(),
        status = "active", -- active, resolved, timeout
        warningShown = false
    }
    
    activeConflicts[conflictId] = conflict
    
    -- COMPLIANCE: Save conflict data
    saveConflictData()
    
    -- Show warning UI
    showConflictWarningUI(conflict)
    
    -- Auto-resolve after timeout
    spawn(function()
        wait(AUTO_RESOLVE_TIMEOUT)
        if activeConflicts[conflictId] and activeConflicts[conflictId].status == "active" then
            resolveConflict(conflictId, "timeout")
        end
    end)
    
    print("[TCE] Conflict detected:", conflict.instancePath)
    
    -- Trigger callbacks
    for _, callback in pairs(conflictCallbacks) do
        callback("conflict_detected", conflict)
    end
    
    return conflictId
end

--[[
Initializes the ConflictResolver with plugin state.
Sets up selection change monitoring for conflict detection.
@param state table: Plugin state table
]]
local function showConflictWarning(conflict)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TCE_ConflictWarning"
    if game.Players.LocalPlayer and game.Players.LocalPlayer.PlayerGui then
        screenGui.Parent = game.Players.LocalPlayer.PlayerGui
    end
    screenGui.ResetOnSpawn = false
    
    -- Main frame with modern dark styling
    local frame = Instance.new("Frame")
    frame.Name = "WarningFrame"
    frame.Size = UDim2.new(0, 400, 0, 200)
    frame.Position = UDim2.new(0.5, -200, 0.2, 0)
    frame.BackgroundColor3 = Color3.fromHex("#1a1d29")
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Border glow
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromHex("#f59e0b") -- Warning amber
    stroke.Thickness = 2
    stroke.Parent = frame
    
    -- Warning icon
    local icon = Instance.new("TextLabel")
    icon.Name = "WarningIcon"
    icon.Size = UDim2.new(0, 40, 0, 40)
    icon.Position = UDim2.new(0, 20, 0, 20)
    icon.BackgroundTransparency = 1
    icon.Text = "⚠️"
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.Parent = frame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -80, 0, 30)
    title.Position = UDim2.new(0, 70, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "EDIT CONFLICT DETECTED"
    title.TextColor3 = Color3.fromHex("#ffffff")
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame
    
    -- Description
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, -40, 0, 60)
    description.Position = UDim2.new(0, 20, 0, 50)
    description.BackgroundTransparency = 1
    description.Text = "Another user is currently editing this asset. Simultaneous editing may cause conflicts."
    description.TextColor3 = Color3.fromHex("#a1a1aa")
    description.TextScaled = true
    description.Font = Enum.Font.Gotham
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.Parent = frame
    
    -- Asset info
    local assetInfo = Instance.new("TextLabel")
    assetInfo.Name = "AssetInfo"
    assetInfo.Size = UDim2.new(1, -40, 0, 25)
    assetInfo.Position = UDim2.new(0, 20, 0, 115)
    assetInfo.BackgroundTransparency = 1
    assetInfo.Text = "Asset: " .. (conflict.instance and conflict.instance.Name or "Unknown")
    assetInfo.TextColor3 = Color3.fromHex("#14b8a6")
    assetInfo.TextScaled = true
    assetInfo.Font = Enum.Font.GothamMedium
    assetInfo.TextXAlignment = Enum.TextXAlignment.Left
    assetInfo.Parent = frame
    
    -- Action buttons
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ButtonFrame"
    buttonFrame.Size = UDim2.new(1, -40, 0, 40)
    buttonFrame.Position = UDim2.new(0, 20, 0, 145)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = frame
    
    -- Lock button
    local lockButton = Instance.new("TextButton")
    lockButton.Name = "LockButton"
    lockButton.Size = UDim2.new(0.48, 0, 1, 0)
    lockButton.Position = UDim2.new(0, 0, 0, 0)
    lockButton.BackgroundColor3 = Color3.fromHex("#f59e0b")
    lockButton.BorderSizePixel = 0
    lockButton.Text = "🔒 Lock Asset"
    lockButton.TextColor3 = Color3.fromHex("#ffffff")
    lockButton.TextScaled = true
    lockButton.Font = Enum.Font.GothamMedium
    lockButton.Parent = buttonFrame
    
    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 4)
    lockCorner.Parent = lockButton
    
    -- Cancel button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Name = "CancelButton"
    cancelButton.Size = UDim2.new(0.48, 0, 1, 0)
    cancelButton.Position = UDim2.new(0.52, 0, 0, 0)
    cancelButton.BackgroundColor3 = Color3.fromHex("#6b7280")
    cancelButton.BorderSizePixel = 0
    cancelButton.Text = "❌ Cancel Edit"
    cancelButton.TextColor3 = Color3.fromHex("#ffffff")
    cancelButton.TextScaled = true
    cancelButton.Font = Enum.Font.GothamMedium
    cancelButton.Parent = buttonFrame
    
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 4)
    cancelCorner.Parent = cancelButton
    
    -- Button handlers
    lockButton.MouseButton1Click:Connect(function()
        if AssetLockManager and conflict.instance then
            local success, message = AssetLockManager.lockAsset(conflict.instance, "conflict")
            if success then
                resolveConflict(conflict.id, "locked")
            else
                warn("[TCE] Failed to lock asset:", message)
            end
        end
        screenGui:Destroy()
    end)
    
    cancelButton.MouseButton1Click:Connect(function()
        if conflict.id then
            resolveConflict(conflict.id, "cancelled")
        end
        screenGui:Destroy()
    end)
    
    -- Auto-close after duration
    spawn(function()
        wait(CONFLICT_WARNING_DURATION)
        if screenGui and screenGui.Parent then
            screenGui:Destroy()
        end
    end)
    
    if conflict then
        conflict.warningShown = true
        conflict.warningGui = screenGui
    end
end

local function resolveConflict(conflictId, resolution)
    local conflict = activeConflicts[conflictId]
    if not conflict then return end
    
    conflict.status = "resolved"
    conflict.resolution = resolution
    conflict.resolvedAt = os.time()
    
    -- Clean up warning GUI
    if conflict.warningGui and conflict.warningGui.Parent then
        conflict.warningGui:Destroy()
    end
    
    print("[TCE] Conflict resolved:", conflictId, "via", resolution)
    
    -- COMPLIANCE: Save updated conflict data
    saveConflictData()
    
    -- Trigger callbacks
    for _, callback in pairs(conflictCallbacks) do
        callback("conflict_resolved", conflict)
    end
    
    -- Remove from active conflicts after delay
    spawn(function()
        wait(60)
        activeConflicts[conflictId] = nil
        saveConflictData()
    end)
end

--[[
Initializes the ConflictResolver with plugin state.
Sets up selection change monitoring for conflict detection.
@param state table: Plugin state table
]]
function ConflictResolver.initialize(state: PluginState): ()
    pluginState = state
    
    -- COMPLIANCE: Load saved conflict data
    loadConflictData()
    
    -- Get references to other managers
    local success1 = pcall(function()
        AssetLockManager = require(script.Parent.AssetLockManager)
    end)
    
    local success2 = pcall(function()
        PermissionManager = require(script.Parent.PermissionManager)
    end)
    
    if not success1 then
        warn("[TCE] Failed to load AssetLockManager")
    end
    
    if not success2 then
        warn("[TCE] Failed to load PermissionManager")
    end
    
    -- Monitor selection changes for conflict detection
    Selection.SelectionChanged:Connect(function()
        local currentUser = Players.LocalPlayer.UserId
        local selected = Selection:Get()
        
        for _, instance in ipairs(selected) do
            -- Check for existing locks
            if AssetLockManager then
                local isLocked, lockInfo = AssetLockManager.isAssetLocked(instance)
                if isLocked and lockInfo.userId ~= currentUser then
                    -- Asset is locked by someone else - potential conflict
                    createConflictWarning(instance, lockInfo.userId)
                end
            end
            
            -- Detect edit conflicts
            local hasConflict, conflictingUserId = detectEditConflict(instance, currentUser)
            if hasConflict then
                createConflictWarning(instance, conflictingUserId)
            end
        end
    end)
    
    print("[TCE] Conflict Resolver initialized")
end

--[[
Registers a callback for conflict events.
@param id string: Unique callback id
@param callback function
]]
function ConflictResolver.registerCallback(id: string, callback: ConflictCallback): ()
    conflictCallbacks[id] = callback
end

--[[
Unregisters a conflict event callback by id.
@param id string
]]
function ConflictResolver.unregisterCallback(id: string): ()
    conflictCallbacks[id] = nil
end

--[[
Returns all currently active conflicts.
@return table: {id = conflictInfo}
]]
function ConflictResolver.getActiveConflicts(): {[number]: ConflictInfo}
    local active = {}
    for id, conflict in pairs(activeConflicts) do
        if conflict.status == "active" then
            active[id] = conflict
        end
    end
    return active
end

--[[
Resolves a conflict by id with a specific resolution method.
@param conflictId number
@param resolution string: Resolution method
@return boolean: True if successful
]]
function ConflictResolver.resolveConflict(conflictId: number, resolution: string): boolean
    return resolveConflict(conflictId, resolution)
end

--[[
Forces resolution of all active conflicts.
@return number: Number of conflicts resolved
]]
function ConflictResolver.forceResolveAllConflicts(): number
    local resolved = 0
    for id, conflict in pairs(activeConflicts) do
        if conflict.status == "active" then
            resolveConflict(id, "force_resolved")
            resolved = resolved + 1
        end
    end
    return resolved
end

--[[
Returns statistics about conflicts (active, resolved, total).
@return table: Stats table
]]
function ConflictResolver.getConflictStats(): ConflictStats
    local stats = {
        active = 0,
        resolved = 0,
        total = 0
    }
    
    for _, conflict in pairs(activeConflicts) do
        stats.total = stats.total + 1
        if conflict.status == "active" then
            stats.active = stats.active + 1
        else
            stats.resolved = stats.resolved + 1
        end
    end
    
    return stats
end

--[[
Exports all conflict data for backup or migration.
@return table
]]
function ConflictResolver.exportConflictData(): ConflictExportData
    return {
        version = "1.0",
        timestamp = os.time(),
        conflicts = activeConflicts,
        compliance = "plugin_settings_only"
    }
end

--[[
Imports conflict data (merges with current conflicts).
@param data table
@return boolean: True if import was successful
]]
function ConflictResolver.importConflictData(data: ConflictExportData): boolean
    if data.version == "1.0" and data.conflicts then
        activeConflicts = data.conflicts
        saveConflictData()
        print("[TCE] Imported conflict data")
        return true
    end
    return false
end

--[[
Cleans up the ConflictResolver (resolves all conflicts, saves state, clears callbacks).
]]
function ConflictResolver.cleanup(): ()
    -- Force resolve all active conflicts
    ConflictResolver.forceResolveAllConflicts()
    
    -- COMPLIANCE: Save final state
    saveConflictData()
    
    -- Clear callbacks
    conflictCallbacks = {}
    
    print("[TCE] Conflict Resolver cleaned up")
end

--[[
Sets the AssetLockManager reference for cross-module integration.
@param assetLockManagerRef table
]]
function ConflictResolver.setAssetLockManager(assetLockManagerRef: any): ()
    AssetLockManager = assetLockManagerRef
    print("[TCE] ConflictResolver: AssetLockManager reference set")
end

--[[
Sets the PermissionManager reference for cross-module integration.
@param permissionManagerRef table
]]
function ConflictResolver.setPermissionManager(permissionManagerRef: any): ()
    PermissionManager = permissionManagerRef
    print("[TCE] ConflictResolver: PermissionManager reference set")
end

return ConflictResolver 