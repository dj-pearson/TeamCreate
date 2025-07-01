-- src/shared/modules/PermissionManager/init.lua
-- Handles role-based permission control for Team Create Enhancement Plugin
-- COMPLIANCE: No external dependencies, self-contained module

local PermissionManager = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Permission Roles and Rules
local PERMISSION_ROLES = {
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
local pluginState = nil
local userRoles = {}
local permissionCallbacks = {}

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

-- Public API
function PermissionManager.initialize(state)
    pluginState = state
    
    -- COMPLIANCE: Load saved configuration from plugin settings
    loadRoleConfiguration()
    
    -- Set up default roles for current session
    local currentUser = Players.LocalPlayer.UserId
    if not userRoles[currentUser] then
        userRoles[currentUser] = "OWNER" -- Plugin installer is owner by default
        saveRoleConfiguration()
    end
    
    print("[TCE] Permission Manager initialized")
    print("[TCE] Current user role:", userRoles[currentUser])
end

function PermissionManager.assignRole(userId, roleName)
    local success = assignRole(userId, roleName)
    if success then
        saveRoleConfiguration()
    end
    return success
end

function PermissionManager.removeRole(userId)
    local success = removeRole(userId)
    if success then
        saveRoleConfiguration()
    end
    return success
end

function PermissionManager.getUserRole(userId)
    return userRoles[userId] or "VIEWER"
end

function PermissionManager.getAllRoles()
    return PERMISSION_ROLES
end

function PermissionManager.hasPermission(userId, permission)
    return hasPermission(userId, permission)
end

function PermissionManager.canEditScripts(userId)
    return canEditScripts(userId)
end

function PermissionManager.canEditBuilds(userId)
    return canEditBuilds(userId)
end

function PermissionManager.canLockAssets(userId)
    return canLockAssets(userId)
end

function PermissionManager.canManageUsers(userId)
    return canManageUsers(userId)
end

function PermissionManager.getUsersByRole(roleName)
    local users = {}
    for userId, role in pairs(userRoles) do
        if role == roleName then
            table.insert(users, userId)
        end
    end
    return users
end

function PermissionManager.registerCallback(id, callback)
    permissionCallbacks[id] = callback
end

function PermissionManager.unregisterCallback(id)
    permissionCallbacks[id] = nil
end

function PermissionManager.getRoleColor(roleName)
    local role = PERMISSION_ROLES[roleName]
    return role and role.color or Color3.fromHex("#6b7280")
end

function PermissionManager.getRolePriority(roleName)
    local role = PERMISSION_ROLES[roleName]
    return role and role.priority or 0
end

function PermissionManager.validateRoleHierarchy(assignerRole, targetRole)
    local assignerPriority = PermissionManager.getRolePriority(assignerRole)
    local targetPriority = PermissionManager.getRolePriority(targetRole)
    return assignerPriority > targetPriority
end

-- COMPLIANCE: Export/import using safe plugin settings only
function PermissionManager.exportRoleConfig()
    return {
        version = "1.0",
        timestamp = os.time(),
        roles = userRoles,
        compliance = "plugin_settings_only"
    }
end

function PermissionManager.importRoleConfig(config)
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

function PermissionManager.resetRoles()
    local currentUser = Players.LocalPlayer.UserId
    userRoles = {[currentUser] = "OWNER"}
    saveRoleConfiguration()
    print("[TCE] Role configuration reset")
end

function PermissionManager.getRoleStats()
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

-- COMPLIANCE: Clean up function
function PermissionManager.cleanup()
    -- Save current state
    saveRoleConfiguration()
    
    -- Clear callbacks
    permissionCallbacks = {}
    
    print("[TCE] Permission Manager cleaned up")
end

return PermissionManager 