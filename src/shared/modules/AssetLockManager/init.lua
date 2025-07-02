-- src/shared/modules/AssetLockManager/init.lua
-- Handles asset locking system with visual indicators for conflict prevention
-- COMPLIANCE: No external dependencies, Studio-only operations

-- Type imports
local Types = require(script.Parent.Parent.types)
type UserId = Types.UserId
type RoleName = Types.RoleName
type InstancePath = Types.InstancePath
type LockInfo = Types.LockInfo
type LockStats = Types.LockStats
type PluginState = Types.PluginState
type LockCallback = Types.LockCallback
type LockExportData = Types.LockExportData

--[[
AssetLockManager
================
Manages asset locking for Team Create Enhancer plugin.
Provides APIs for locking/unlocking assets, visual lock indicators, and lock metadata.
Integrates with PermissionManager for role-based lock permissions.
All lock data is stored using plugin settings for compliance.
]]

local AssetLockManager = {}

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Selection = game:GetService("Selection")
local TweenService = game:GetService("TweenService")

-- Constants
local LOCK_TIMEOUT: number = 300 -- 5 minutes before auto-unlock
local VISUAL_UPDATE_INTERVAL: number = 1 -- Update visuals every second

-- Lock colors based on user roles
local LOCK_COLORS: {[RoleName]: Color3} = {
    OWNER = Color3.fromHex("#f59e0b"), -- Amber
    ADMIN = Color3.fromHex("#ef4444"), -- Red  
    DEVELOPER = Color3.fromHex("#8b5cf6"), -- Purple
    SCRIPTER = Color3.fromHex("#00d4ff"), -- Blue
    BUILDER = Color3.fromHex("#14b8a6"), -- Teal
    VIEWER = Color3.fromHex("#6b7280"), -- Gray
    DEFAULT = Color3.fromHex("#ffffff") -- White
}

-- Local state
local pluginState: PluginState? = nil
local assetLocks: {[InstancePath]: LockInfo} = {} -- {instancePath: {userId, timestamp, lockType, metadata}}
local visualIndicators: {[Instance]: any} = {} -- {instance: visualObject}
local lockCallbacks: {[string]: LockCallback} = {}
local selectionConnection: RBXScriptConnection? = nil
local visualUpdateConnection: RBXScriptConnection? = nil
local PermissionManager: any = nil

-- Asset identification functions
local function getInstancePath(instance)
    if not instance then return nil end
    
    local path = {}
    local current = instance
    
    while current and current.Parent do
        table.insert(path, 1, current.Name)
        current = current.Parent
        
        -- Stop at workspace level
        if current == workspace or current == game then
            break
        end
    end
    
    return table.concat(path, "/")
end

local function getInstanceFromPath(path)
    if not path then return nil end
    
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        table.insert(parts, part)
    end
    
    local current = workspace
    for _, part in ipairs(parts) do
        current = current:FindFirstChild(part)
        if not current then
            return nil
        end
    end
    
    return current
end

-- COMPLIANCE: Safe data storage
local function saveLockData()
    local success, error = pcall(function()
        if plugin then
            -- Store only essential lock metadata
            local lockMeta = {}
            for path, lockInfo in pairs(assetLocks) do
                lockMeta[path] = {
                    userId = lockInfo.userId,
                    userName = lockInfo.userName,
                    timestamp = lockInfo.timestamp,
                    lockType = lockInfo.lockType,
                    role = lockInfo.role
                }
            end
            plugin:SetSetting("TCE_AssetLocks", lockMeta)
        end
    end)
    
    if not success then
        warn("[TCE] Failed to save lock data:", error)
    end
end

local function loadLockData()
    local success, savedLocks = pcall(function()
        if plugin then
            return plugin:GetSetting("TCE_AssetLocks")
        end
        return {}
    end)
    
    if success and savedLocks then
        assetLocks = savedLocks
        print("[TCE] Loaded asset lock data")
    end
end

-- Visual indicator management
local function removeLockIndicator(instance)
    local visual = visualIndicators[instance]
    if visual then
        if visual.selectionBox then
            visual.selectionBox:Destroy()
        end
        if visual.billboard then
            visual.billboard:Destroy()
        end
        if visual.pulseAnimation then
            visual.pulseAnimation:Cancel()
        end
        visualIndicators[instance] = nil
    end
end

-- Lock management functions
local function isLockExpired(lockInfo)
    return (os.time() - lockInfo.timestamp) > LOCK_TIMEOUT
end

local function createLockIndicator(instance, lockInfo)
    if not instance or not instance:IsA("BasePart") then
        return nil
    end
    
    -- Remove existing indicator
    removeLockIndicator(instance)
    
    -- Create visual indicator
    local indicator = Instance.new("SelectionBox")
    indicator.Name = "TCE_LockIndicator"
    indicator.Adornee = instance
    indicator.Color3 = LOCK_COLORS[lockInfo.role] or LOCK_COLORS.DEFAULT
    indicator.Transparency = 0.3
    indicator.LineThickness = 0.2
    indicator.Parent = workspace
    
    -- Add pulsing animation
    local pulseIn = TweenService:Create(
        indicator,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.1}
    )
    pulseIn:Play()
    
    -- Add lock icon billboard
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "TCE_LockIcon"
    billboardGui.Adornee = instance
    billboardGui.Size = UDim2.new(0, 50, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, instance.Size.Y/2 + 1, 0)
    billboardGui.Parent = workspace
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromHex("#000000")
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = billboardGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.3, 0)
    corner.Parent = frame
    
    local lockIcon = Instance.new("TextLabel")
    lockIcon.Size = UDim2.new(1, 0, 1, 0)
    lockIcon.BackgroundTransparency = 1
    lockIcon.Text = "🔒"
    lockIcon.TextScaled = true
    lockIcon.TextColor3 = LOCK_COLORS[lockInfo.role] or LOCK_COLORS.DEFAULT
    lockIcon.Font = Enum.Font.GothamBold
    lockIcon.Parent = frame
    
    -- Add user name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
    nameLabel.Position = UDim2.new(0, 0, 1, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = lockInfo.userName or "Unknown"
    nameLabel.TextScaled = true
    nameLabel.TextColor3 = Color3.fromHex("#ffffff")
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Parent = billboardGui
    
    visualIndicators[instance] = {
        selectionBox = indicator,
        billboard = billboardGui,
        pulseAnimation = pulseIn
    }
    
    return indicator
end

local function updateAllVisuals()
    -- Clean up outdated visuals
    for instance, visual in pairs(visualIndicators) do
        local path = getInstancePath(instance)
        if not assetLocks[path] or isLockExpired(assetLocks[path]) then
            removeLockIndicator(instance)
        end
    end
    
    -- Create visuals for new locks
    for path, lockInfo in pairs(assetLocks) do
        if not isLockExpired(lockInfo) then
            local instance = getInstanceFromPath(path)
            if instance and not visualIndicators[instance] then
                createLockIndicator(instance, lockInfo)
            end
        end
    end
end

local function cleanupExpiredLocks()
    local expiredPaths = {}
    for path, lockInfo in pairs(assetLocks) do
        if isLockExpired(lockInfo) then
            table.insert(expiredPaths, path)
        end
    end
    
    for _, path in ipairs(expiredPaths) do
        AssetLockManager.unlockAsset(path, assetLocks[path].userId, true)
    end
    
    if #expiredPaths > 0 then
        saveLockData()
    end
end

local function canLockAsset(userId, instancePath)
    -- Check if user has permission to lock assets
    if PermissionManager and not PermissionManager.canLockAssets(userId) then
        return false, "Permission denied: Cannot lock assets"
    end
    
    -- Check if already locked
    local existingLock = assetLocks[instancePath]
    if existingLock and not isLockExpired(existingLock) then
        if existingLock.userId == userId then
            return false, "Asset already locked by you"
        else
            return false, "Asset locked by " .. (existingLock.userName or "another user")
        end
    end
    
    return true
end

-- Public API
--[[
Initializes the AssetLockManager with plugin state.
@param state table: Plugin state table
]]
function AssetLockManager.initialize(state: PluginState): ()
    pluginState = state
    
    -- COMPLIANCE: Load saved lock data
    loadLockData()
    
    -- Get reference to PermissionManager
    local success = pcall(function()
        PermissionManager = require(script.Parent.PermissionManager)
    end)
    
    if not success then
        warn("[TCE] Failed to load PermissionManager")
    end
    
    -- Setup selection monitoring
    selectionConnection = Selection.SelectionChanged:Connect(function()
        local selected = Selection:Get()
        
        for _, instance in ipairs(selected) do
            local path = getInstancePath(instance)
            local lockInfo = assetLocks[path]
            
            if lockInfo and not isLockExpired(lockInfo) then
                local currentUser = Players.LocalPlayer.UserId
                if lockInfo.userId ~= currentUser then
                    -- Warn about locked asset
                    warn("[TCE] Asset is locked by " .. (lockInfo.userName or "another user"))
                    
                    -- Trigger callback
                    for _, callback in pairs(lockCallbacks) do
                        callback("lock_warning", {
                            instance = instance,
                            lockInfo = lockInfo
                        })
                    end
                end
            end
        end
    end)
    
    -- Setup visual update loop
    visualUpdateConnection = RunService.Heartbeat:Connect(function()
        -- Update every VISUAL_UPDATE_INTERVAL seconds
        local currentTime = os.time()
        if currentTime % VISUAL_UPDATE_INTERVAL == 0 then
            cleanupExpiredLocks()
            updateAllVisuals()
        end
    end)
    
    print("[TCE] Asset Lock Manager initialized")
end

--[[
Locks an asset for the current user.
@param instance Instance: The asset to lock
@param lockType string: The type of lock (optional)
@return boolean, string: Success and message
]]
function AssetLockManager.lockAsset(instance: Instance, lockType: string?): (boolean, string)
    if not instance then
        return false, "Invalid instance"
    end
    
    local currentUser = Players.LocalPlayer.UserId
    local currentUserName = Players.LocalPlayer.Name
    local instancePath = getInstancePath(instance)
    
    local canLock, reason = canLockAsset(currentUser, instancePath)
    if not canLock then
        return false, reason
    end
    
    -- Get user role for color coding
    local userRole = "DEFAULT"
    if PermissionManager then
        userRole = PermissionManager.getUserRole(currentUser)
    end
    
    -- Create lock
    local lockInfo = {
        userId = currentUser,
        userName = currentUserName,
        timestamp = os.time(),
        lockType = lockType or "edit",
        role = userRole,
        instanceClass = instance.ClassName
    }
    
    assetLocks[instancePath] = lockInfo
    
    -- COMPLIANCE: Save lock data
    saveLockData()
    
    -- Create visual indicator
    createLockIndicator(instance, lockInfo)
    
    print("[TCE] Locked asset:", instancePath, "by", currentUserName)
    
    -- Trigger callbacks
    for _, callback in pairs(lockCallbacks) do
        callback("asset_locked", {
            instance = instance,
            lockInfo = lockInfo
        })
    end
    
    return true, "Asset locked successfully"
end

--[[
Unlocks an asset by path for a user.
@param instancePath string: The asset path
@param userId number: The user unlocking
@param isAutoUnlock boolean: If true, unlock is automatic (timeout)
@return boolean, string: Success and message
]]
function AssetLockManager.unlockAsset(instancePath: InstancePath, userId: UserId, isAutoUnlock: boolean?): (boolean, string)
    local lockInfo = assetLocks[instancePath]
    
    if not lockInfo then
        return false, "Asset not locked"
    end
    
    local currentUser = Players.LocalPlayer.UserId
    
    -- Check permission to unlock
    if lockInfo.userId ~= currentUser and not isAutoUnlock then
        -- Only admins can unlock others' assets
        if PermissionManager and not PermissionManager.hasPermission(currentUser, "asset.unlock") then
            return false, "Permission denied: Cannot unlock assets locked by others"
        end
    end
    
    -- Remove lock
    assetLocks[instancePath] = nil
    
    -- COMPLIANCE: Save lock data
    saveLockData()
    
    -- Remove visual indicator
    local instance = getInstanceFromPath(instancePath)
    if instance then
        removeLockIndicator(instance)
    end
    
    print("[TCE] Unlocked asset:", instancePath, isAutoUnlock and "(auto)" or "(manual)")
    
    -- Trigger callbacks
    for _, callback in pairs(lockCallbacks) do
        callback("asset_unlocked", {
            instancePath = instancePath,
            lockInfo = lockInfo,
            isAutoUnlock = isAutoUnlock
        })
    end
    
    return true, "Asset unlocked successfully"
end

--[[
Checks if an asset is locked.
@param instance Instance
@return boolean, table: True and lockInfo if locked, else false
]]
function AssetLockManager.isAssetLocked(instance: Instance): (boolean, LockInfo?)
    local instancePath = getInstancePath(instance)
    local lockInfo = assetLocks[instancePath]
    
    if lockInfo and not isLockExpired(lockInfo) then
        return true, lockInfo
    end
    
    return false, nil
end

--[[
Returns a table of all currently locked assets (not expired).
@return table: {path = lockInfo}
]]
function AssetLockManager.getLockedAssets(): {[InstancePath]: LockInfo}
    local locks = {}
    for path, lockInfo in pairs(assetLocks) do
        if not isLockExpired(lockInfo) then
            locks[path] = lockInfo
        end
    end
    return locks
end

--[[
Returns all locks held by a specific user.
@param userId number
@return table: {path = lockInfo}
]]
function AssetLockManager.getUserLocks(userId: UserId): {[InstancePath]: LockInfo}
    local userLocks = {}
    for path, lockInfo in pairs(assetLocks) do
        if lockInfo.userId == userId and not isLockExpired(lockInfo) then
            userLocks[path] = lockInfo
        end
    end
    return userLocks
end

--[[
Registers a callback for lock events.
@param id string: Unique callback id
@param callback function
]]
function AssetLockManager.registerCallback(id: string, callback: LockCallback): ()
    lockCallbacks[id] = callback
end

--[[
Unregisters a lock event callback by id.
@param id string
]]
function AssetLockManager.unregisterCallback(id: string): ()
    lockCallbacks[id] = nil
end

--[[
Returns statistics about current locks.
@return table: Stats table
]]
function AssetLockManager.getLockStats(): LockStats
    local stats = {
        totalLocks = 0,
        locksByUser = {},
        locksByType = {},
        expiredLocks = 0
    }
    
    for path, lockInfo in pairs(assetLocks) do
        stats.totalLocks = stats.totalLocks + 1
        
        -- Count by user
        stats.locksByUser[lockInfo.userId] = (stats.locksByUser[lockInfo.userId] or 0) + 1
        
        -- Count by type
        stats.locksByType[lockInfo.lockType] = (stats.locksByType[lockInfo.lockType] or 0) + 1
        
        -- Count expired
        if isLockExpired(lockInfo) then
            stats.expiredLocks = stats.expiredLocks + 1
        end
    end
    
    return stats
end

--[[
Exports all lock data for backup or migration.
@return table
]]
function AssetLockManager.exportLocks(): LockExportData
    return {
        version = "1.0",
        timestamp = os.time(),
        locks = assetLocks,
        compliance = "plugin_settings_only"
    }
end

--[[
Imports lock data (merges with current locks).
@param data table
@return boolean: True if import was successful
]]
function AssetLockManager.importLocks(data: LockExportData): boolean
    if data.version == "1.0" and data.locks then
        -- Merge imported locks
        for path, lockInfo in pairs(data.locks) do
            if not isLockExpired(lockInfo) then
                assetLocks[path] = lockInfo
            end
        end
        
        saveLockData()
        updateAllVisuals()
        print("[TCE] Imported lock data")
        return true
    end
    return false
end

--[[
Unlocks all assets locked by the current user.
@return number: Number of assets unlocked
]]
function AssetLockManager.unlockAllUserAssets(): number
    local currentUser = Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    local unlockedCount = 0
    
    local pathsToUnlock = {}
    for path, lockInfo in pairs(assetLocks) do
        if lockInfo.userId == currentUser then
            table.insert(pathsToUnlock, path)
        end
    end
    
    for _, path in ipairs(pathsToUnlock) do
        local success = AssetLockManager.unlockAsset(path, currentUser, false)
        if success then
            unlockedCount = unlockedCount + 1
        end
    end
    
    return unlockedCount
end

--[[
Cleans up the AssetLockManager (disconnects, clears visuals, saves state).
]]
function AssetLockManager.cleanup(): ()
    -- Disconnect connections
    if selectionConnection then
        selectionConnection:Disconnect()
        selectionConnection = nil
    end
    
    if visualUpdateConnection then
        visualUpdateConnection:Disconnect()
        visualUpdateConnection = nil
    end
    
    -- Clean up visuals
    for instance, visual in pairs(visualIndicators) do
        removeLockIndicator(instance)
    end
    
    -- COMPLIANCE: Save final state
    saveLockData()
    
    -- Clear locks
    assetLocks = {}
    
    print("[TCE] Asset Lock Manager cleaned up")
end

--[[
Sets the PermissionManager reference for cross-module integration.
@param permissionManagerRef table
]]
function AssetLockManager.setPermissionManager(permissionManagerRef: any): ()
    PermissionManager = permissionManagerRef
    print("[TCE] AssetLockManager: PermissionManager reference set")
end

return AssetLockManager 