-- src/shared/types.lua
-- Luau type definitions for Team Create Enhancement Plugin

--[[
Types
=====
Shared type definitions for Team Create Enhancer plugin.
Provides type safety and better IDE support across all modules.
]]

-- Basic types
export type UserId = number
export type RoleName = "OWNER" | "ADMIN" | "DEVELOPER" | "SCRIPTER" | "BUILDER" | "VIEWER"
export type PermissionName = string
export type InstancePath = string

-- Role Definition
export type RoleDefinition = {
    name: string,
    permissions: {PermissionName},
    color: Color3,
    priority: number
}

export type RoleDefinitions = {
    [RoleName]: RoleDefinition
}

-- User Role Mapping
export type UserRoles = {
    [UserId]: RoleName
}

-- Plugin State
export type PluginState = {
    isEnabled: boolean,
    currentUser: Player?,
    teamCreateSession: any?,
    userRoles: UserRoles,
    assetLocks: {[InstancePath]: LockInfo},
    connectionStatus: string,
    complianceMode: boolean
}

-- Asset Lock Types
export type LockInfo = {
    userId: UserId,
    userName: string,
    timestamp: number,
    lockType: string,
    role: RoleName,
    instanceClass: string?
}

export type LockStats = {
    totalLocks: number,
    locksByUser: {[UserId]: number},
    locksByType: {[string]: number},
    expiredLocks: number
}

-- Connection Status Types
export type ConnectionStatus = {
    isConnected: boolean,
    quality: "Excellent" | "Good" | "Poor" | "Disconnected",
    ping: number,
    lastSeen: number,
    activeUsers: number,
    uptime: number,
    complianceMode: boolean
}

export type SnapshotInfo = {
    timestamp: number,
    version: number,
    data: {any},
    userActions: {any},
    metadata: {
        activeUsers: number,
        connectionQuality: string,
        pluginVersion: string,
        studioVersion: string,
        snapshotType: string?,
        complianceMode: boolean?
    }
}

-- Conflict Types
export type ConflictInfo = {
    id: number,
    instance: Instance?,
    instancePath: InstancePath,
    users: {UserId},
    timestamp: number,
    status: "active" | "resolved" | "timeout",
    warningShown: boolean?,
    warningGui: ScreenGui?,
    resolution: string?,
    resolvedAt: number?
}

export type ConflictStats = {
    active: number,
    resolved: number,
    total: number
}

-- Notification Types
export type NotificationType = "INFO" | "SUCCESS" | "WARNING" | "ERROR" | "USER"

export type NotificationInfo = {
    id: number,
    title: string,
    message: string,
    type: NotificationType,
    timestamp: number,
    duration: number,
    read: boolean
}

export type NotificationTypeInfo = {
    color: Color3,
    icon: string
}

-- UI Constants Types
export type UIColors = {
    PRIMARY_BG: Color3,
    SECONDARY_BG: Color3,
    ACCENT_BLUE: Color3,
    ACCENT_PURPLE: Color3,
    ACCENT_MAGENTA: Color3,
    ACCENT_TEAL: Color3,
    TEXT_PRIMARY: Color3,
    TEXT_SECONDARY: Color3,
    SUCCESS_GREEN: Color3,
    ERROR_RED: Color3
}

export type UIFonts = {
    MAIN: Enum.Font,
    HEADER: Enum.Font
}

export type UISizes = {
    HEADER: number,
    SUBTEXT: number,
    DATA: number,
    CORNER_RADIUS: number,
    GLOW_SIZE: number
}

export type UIConstants = {
    COLORS: UIColors,
    FONTS: UIFonts,
    SIZES: UISizes
}

-- Module References Type
export type ModuleReferences = {
    PermissionManager: any?,
    AssetLockManager: any?,
    ConnectionMonitor: any?,
    NotificationManager: any?,
    ConflictResolver: any?,
    UIManager: any?
}

-- Callback Function Types
export type PermissionCallback = (eventType: string, userId: UserId, roleName: RoleName?) -> ()
export type LockCallback = (eventType: string, data: {any}) -> ()
export type ConnectionCallback = (eventType: string, data: {any}) -> ()
export type ConflictCallback = (eventType: string, conflict: ConflictInfo) -> ()
export type NotificationCallback = (eventType: string, notification: NotificationInfo) -> ()

-- Export/Import Data Types
export type ExportData = {
    version: string,
    timestamp: number,
    compliance: string,
    [string]: any
}

export type RoleExportData = ExportData & {
    roles: UserRoles
}

export type LockExportData = ExportData & {
    locks: {[InstancePath]: LockInfo}
}

export type SnapshotExportData = ExportData & {
    snapshots: {SnapshotInfo}
}

export type ConflictExportData = ExportData & {
    conflicts: {[number]: ConflictInfo}
}

-- Statistics Types
export type RoleStats = {
    totalUsers: number,
    roleCount: {[RoleName]: number}
}

export type ConnectionStats = {
    totalSnapshots: number,
    connectionUptime: number,
    quality: string,
    reconnectAttempts: number,
    isMonitoring: boolean
}

return {} 