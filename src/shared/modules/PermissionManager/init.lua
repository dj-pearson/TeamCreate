-- src/shared/modules/PermissionManager/init.lua
-- Handles role-based permission control for Team Create Enhancement Plugin
-- COMPLIANCE: No external dependencies, self-contained module

-- Type imports
local Types = require(script.Parent.Parent.types)
type UserId = Types.UserId
type RoleName = Types.RoleName
type PermissionName = Types.PermissionName
type RoleDefinition = Types.RoleDefinition
type RoleDefinitions = Types.RoleDefinitions
type UserRoles = Types.UserRoles
type PluginState = Types.PluginState
type PermissionCallback = Types.PermissionCallback
type RoleStats = Types.RoleStats
type RoleExportData = Types.RoleExportData

--[[
PermissionManager
================
Manages user roles and permissions for the Team Create Enhancer plugin.
Provides APIs for assigning roles, checking permissions, and managing role configuration.
Roles include: OWNER, ADMIN, DEVELOPER, SCRIPTER, BUILDER, VIEWER.
All data is stored using plugin settings for compliance.
]]

local PermissionManager = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Permission Roles and Rules
local PERMISSION_ROLES: RoleDefinitions = {
    OWNER = {
        name = "Owner",
        permissions = {"*"}, -- All permissions
        color = Color3.fromHex("#f59e0b"), -- Amber
        priority = 100
    },
    ADMIN = {
        name = "Admin", 
        permissions = {
            "script.edit", "script.create", "script.delete",
            "build.edit", "build.create", "build.delete",
            "asset.lock", "asset.unlock", "asset.organize",
            "user.manage", "role.assign"
        },
        color = Color3.fromHex("#ef4444"), -- Red
        priority = 80
    },
    DEVELOPER = {
        name = "Developer",
        permissions = {
            "script.edit", "script.create",
            "build.edit", "build.create",
            "asset.lock", "asset.organize"
        },
        color = Color3.fromHex("#8b5cf6"), -- Purple
        priority = 60
    },
    SCRIPTER = {
        name = "Scripter",
        permissions = {
            "script.edit", "script.create",
            "asset.lock"
        },
        color = Color3.fromHex("#00d4ff"), -- Blue
        priority = 40
    },
    BUILDER = {
        name = "Builder", 
        permissions = {
            "build.edit", "build.create",
            "asset.lock"
        },
        color = Color3.fromHex("#14b8a6"), -- Teal
        priority = 40
    },
    VIEWER = {
        name = "Viewer",
        permissions = {
            "view.only"
        },
        color = Color3.fromHex("#6b7280"), -- Gray
        priority = 10
    }
}

-- Local state
local pluginState: PluginState? = nil
local userRoles: UserRoles = {}
local permissionCallbacks: {[string]: PermissionCallback} = {}

-- COMPLIANCE: No external service restrictions (removed for compliance)
-- Permission checking functions
local function hasPermission(userId, permission)
    local userRole = userRoles[userId]
    if not userRole then
        return false -- No role assigned, no permissions
    end
    
    local roleData = PERMISSION_ROLES[userRole]
    if not roleData then
        return false
    end
    
    -- Check for wildcard permission (Owner)
    for _, perm in ipairs(roleData.permissions) do
        if perm == "*" or perm == permission then
            return true
        end
    end
    
    return false
end

local function isHigherRole(userA, userB)
    local roleA = PERMISSION_ROLES[userRoles[userA] or "VIEWER"]
    local roleB = PERMISSION_ROLES[userRoles[userB] or "VIEWER"] 
    return roleA.priority > roleB.priority
end

-- Role management functions
local function assignRole(userId, roleName)
    if not PERMISSION_ROLES[roleName] then
        warn("[TCE] Invalid role:", roleName)
        return false
    end
    
    local currentUser = Players.LocalPlayer.UserId
    if not hasPermission(currentUser, "role.assign") then
        warn("[TCE] Permission denied: Cannot assign roles")
        return false
    end
    
    -- Can't assign role higher than or equal to your own
    local targetUser = Players:GetPlayerByUserId(userId)
    if targetUser and not isHigherRole(currentUser, userId) then
        warn("[TCE] Cannot assign role to user with equal or higher privileges")
        return false
    end
    
    userRoles[userId] = roleName
    print("[TCE] Assigned role", roleName, "to user", userId)
    
    -- Trigger callbacks
    for _, callback in pairs(permissionCallbacks) do
        callback("role_assigned", userId, roleName)
    end
    
    return true
end

local function removeRole(userId)
    local currentUser = Players.LocalPlayer.UserId
    if not hasPermission(currentUser, "role.assign") then
        warn("[TCE] Permission denied: Cannot remove roles")
        return false
    end
    
    if not isHigherRole(currentUser, userId) then
        warn("[TCE] Cannot remove role from user with equal or higher privileges")
        return false
    end
    
    local oldRole = userRoles[userId]
    userRoles[userId] = "VIEWER" -- Default to viewer
    
    print("[TCE] Removed role", oldRole, "from user", userId)
    
    -- Trigger callbacks
    for _, callback in pairs(permissionCallbacks) do
        callback("role_removed", userId, oldRole)
    end
    
    return true
end

-- Permission checking for specific actions
local function canEditScripts(userId)
    return hasPermission(userId, "script.edit")
end

local function canEditBuilds(userId)
    return hasPermission(userId, "build.edit") 
end

local function canLockAssets(userId)
    return hasPermission(userId, "asset.lock")
end

local function canManageUsers(userId)
    return hasPermission(userId, "user.manage")
end

-- COMPLIANCE: Safe data storage using plugin settings only
local function saveRoleConfiguration()
    local success, error = pcall(function()
        if plugin then
            plugin:SetSetting("TCE_UserRoles", userRoles)
        end
    end)
    
    if not success then
        warn("[TCE] Failed to save role configuration:", error)
    end
end

local function loadRoleConfiguration()
    local success, savedRoles = pcall(function()
        if plugin then
            return plugin:GetSetting("TCE_UserRoles")
        end
        return {}
    end)
    
    if success and savedRoles then
        userRoles = savedRoles
        print("[TCE] Loaded role configuration")
    else
        userRoles = {}
        print("[TCE] No saved role configuration found")
    end
end

--[[
Initializes the PermissionManager with plugin state.
Loads saved role configuration and sets up the current user as OWNER if not present.
@param state table: Plugin state table
]]
function PermissionManager.initialize(state: PluginState): ()
    pluginState = state
    
    -- COMPLIANCE: Load saved configuration from plugin settings
    loadRoleConfiguration()
    
    -- Set up default roles for current session
    local localPlayer = Players.LocalPlayer
    if localPlayer and localPlayer.UserId then
        local currentUser = localPlayer.UserId
        if not userRoles[currentUser] then
            userRoles[currentUser] = "OWNER" -- Plugin installer is owner by default
            saveRoleConfiguration()
        end
        print("[TCE] Permission Manager initialized")
        print("[TCE] Current user role:", userRoles[currentUser])
    else
        print("[TCE] Permission Manager initialized (LocalPlayer not available)")
    end
end

--[[
Assigns a role to a user.
@param userId number: The userId to assign the role to
@param roleName string: The role name to assign
@return boolean: True if successful
]]
function PermissionManager.assignRole(userId: UserId, roleName: RoleName): boolean
    local success = assignRole(userId, roleName)
    if success then
        saveRoleConfiguration()
    end
    return success
end

--[[
Removes a role from a user (sets to VIEWER).
@param userId number: The userId to remove the role from
@return boolean: True if successful
]]
function PermissionManager.removeRole(userId: UserId): boolean
    local success = removeRole(userId)
    if success then
        saveRoleConfiguration()
    end
    return success
end

--[[
Gets the role of a user.
@param userId number: The userId to query
@return string: The user's role name
]]
function PermissionManager.getUserRole(userId: UserId): RoleName
    return userRoles[userId] or "VIEWER"
end

--[[
Gets the role of the current user (LocalPlayer).
@return string: The current user's role name
]]
function PermissionManager.getCurrentUserRole(): RoleName
    local localPlayer = Players.LocalPlayer
    if localPlayer and localPlayer.UserId then
        local currentUser = localPlayer.UserId
        return PermissionManager.getUserRole(currentUser)
    end
    return "VIEWER" -- Default role when LocalPlayer not available
end

--[[
Returns the table of all defined roles and their properties.
@return table: Role definitions
]]
function PermissionManager.getAllRoles(): RoleDefinitions
    return PERMISSION_ROLES
end

--[[
Checks if a user has a specific permission.
@param userId number: The userId to check
@param permission string: The permission string
@return boolean: True if the user has the permission
]]
function PermissionManager.hasPermission(userId: UserId, permission: PermissionName): boolean
    return hasPermission(userId, permission)
end

--[[
Checks if a user can edit scripts.
@param userId number
@return boolean
]]
function PermissionManager.canEditScripts(userId: UserId): boolean
    return canEditScripts(userId)
end

--[[
Checks if a user can edit builds.
@param userId number
@return boolean
]]
function PermissionManager.canEditBuilds(userId: UserId): boolean
    return canEditBuilds(userId)
end

--[[
Checks if a user can lock assets.
@param userId number
@return boolean
]]
function PermissionManager.canLockAssets(userId: UserId): boolean
    return canLockAssets(userId)
end

--[[
Checks if a user can manage other users.
@param userId number
@return boolean
]]
function PermissionManager.canManageUsers(userId: UserId): boolean
    return canManageUsers(userId)
end

--[[
Returns a list of userIds for a given role.
@param roleName string
@return table: List of userIds
]]
function PermissionManager.getUsersByRole(roleName: RoleName): {UserId}
    local users = {}
    for userId, role in pairs(userRoles) do
        if role == roleName then
            table.insert(users, userId)
        end
    end
    return users
end

--[[
Registers a callback for permission events.
@param id string: Unique callback id
@param callback function: The callback function
]]
function PermissionManager.registerCallback(id: string, callback: PermissionCallback): ()
    permissionCallbacks[id] = callback
end

--[[
Unregisters a callback by id.
@param id string
]]
function PermissionManager.unregisterCallback(id: string): ()
    permissionCallbacks[id] = nil
end

--[[
Gets the color associated with a role.
@param roleName string
@return Color3
]]
function PermissionManager.getRoleColor(roleName: RoleName): Color3
    local role = PERMISSION_ROLES[roleName]
    return role and role.color or Color3.fromHex("#6b7280")
end

--[[
Gets the priority value for a role.
@param roleName string
@return number
]]
function PermissionManager.getRolePriority(roleName: RoleName): number
    local role = PERMISSION_ROLES[roleName]
    return role and role.priority or 0
end

--[[
Validates if an assigner role can assign a target role (priority check).
@param assignerRole string
@param targetRole string
@return boolean
]]
function PermissionManager.validateRoleHierarchy(assignerRole: RoleName, targetRole: RoleName): boolean
    local assignerPriority = PermissionManager.getRolePriority(assignerRole)
    local targetPriority = PermissionManager.getRolePriority(targetRole)
    return assignerPriority > targetPriority
end

--[[
Exports the current role configuration for backup or migration.
@return table
]]
function PermissionManager.exportRoleConfig(): RoleExportData
    return {
        version = "1.0",
        timestamp = os.time(),
        roles = userRoles,
        compliance = "plugin_settings_only"
    }
end

--[[
Imports a role configuration.
@param config table
@return boolean: True if import was successful
]]
function PermissionManager.importRoleConfig(config: RoleExportData): boolean
    if config.version == "1.0" and config.roles then
        for userId, role in pairs(config.roles) do
            if PERMISSION_ROLES[role] then
                userRoles[userId] = role
            end
        end
        saveRoleConfiguration()
        print("[TCE] Imported role configuration")
        return true
    end
    return false
end

--[[
Resets all roles to default (current user as OWNER).
]]
function PermissionManager.resetRoles(): ()
    local currentUser = Players.LocalPlayer.UserId
    userRoles = {[currentUser] = "OWNER"}
    saveRoleConfiguration()
    print("[TCE] Role configuration reset")
end

--[[
Returns statistics about roles and users.
@return table: Stats table
]]
function PermissionManager.getRoleStats(): RoleStats
    local stats = {
        totalUsers = 0,
        roleCount = {}
    }
    
    for userId, role in pairs(userRoles) do
        stats.totalUsers = stats.totalUsers + 1
        stats.roleCount[role] = (stats.roleCount[role] or 0) + 1
    end
    
    return stats
end

--[[
Cleans up the PermissionManager (saves state, clears callbacks).
]]
function PermissionManager.cleanup(): ()
    -- Save current state
    saveRoleConfiguration()
    
    -- Clear callbacks
    permissionCallbacks = {}
    
    print("[TCE] Permission Manager cleaned up")
end

return PermissionManager 