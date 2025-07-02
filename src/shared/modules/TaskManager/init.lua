-- src/shared/modules/TaskManager/init.lua
-- Manages task creation, assignment, deadlines, and progress tracking for team collaboration

--[[
TaskManager - Enhanced Team Collaboration
=========================================
Comprehensive task management system with shared storage for real-time team collaboration.
Uses hybrid storage: workspace objects for team sharing + plugin settings for backup.
]]

local TaskManager = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types
type TaskPriority = "Low" | "Medium" | "High" | "Critical"
type TaskStatus = "Todo" | "InProgress" | "Review" | "Completed" | "Cancelled"
type TaskType = "Script" | "Build" | "Asset" | "Design" | "Test" | "Bug" | "Feature"

type Task = {
    id: string,
    title: string,
    description: string,
    assignedTo: number?, -- UserId
    assignedBy: number, -- UserId
    createdAt: number, -- timestamp
    updatedAt: number, -- timestamp
    dueDate: number?, -- timestamp
    priority: TaskPriority,
    status: TaskStatus,
    taskType: TaskType,
    estimatedHours: number?,
    actualHours: number?,
    tags: {string},
    comments: {TaskComment},
    attachments: {string}?, -- Asset references
    subtasks: {string}?, -- Subtask IDs
    parentTask: string?, -- Parent task ID
    progress: number -- 0-100
}

type TaskComment = {
    id: string,
    author: number, -- UserId
    content: string,
    timestamp: number,
    edited: boolean?
}

type TaskFilter = {
    status: TaskStatus?,
    assignedTo: number?,
    priority: TaskPriority?,
    taskType: TaskType?,
    dueDate: {before: number?, after: number?}?,
    tags: {string}?
}

-- Local variables
local tasks: {[string]: Task} = {}
local taskCallbacks: {[string]: (string, any) -> ()} = {}
local pluginState = nil
local PermissionManager = nil
local NotificationManager = nil

-- Constants
local TASK_STORAGE_KEY = "TCE_Tasks"
local SHARED_STORAGE_NAME = "TCE_SharedTasks"
local MAX_TASKS = 500
local DEADLINE_WARNING_HOURS = 24
local SYNC_INTERVAL = 5 -- seconds

-- Storage variables
local sharedTasksFolder = nil
local lastSyncTime = 0
local syncConnection = nil

-- Helper functions
local function generateTaskId(): string
    return tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
end

local function getOrCreateSharedStorage()
    if sharedTasksFolder and sharedTasksFolder.Parent then
        return sharedTasksFolder
    end
    
    -- Try ServerStorage first (more persistent)
    local success, result = pcall(function()
        local serverStorage = ServerStorage
        local existing = serverStorage:FindFirstChild(SHARED_STORAGE_NAME)
        if existing then
            return existing
        end
        
        local folder = Instance.new("Folder")
        folder.Name = SHARED_STORAGE_NAME
        folder.Parent = serverStorage
        return folder
    end)
    
    if success then
        sharedTasksFolder = result
        print("[TCE] Using ServerStorage for shared tasks")
        return result
    end
    
    -- Fallback to ReplicatedStorage
    local success2, result2 = pcall(function()
        local replicatedStorage = ReplicatedStorage
        local existing = replicatedStorage:FindFirstChild(SHARED_STORAGE_NAME)
        if existing then
            return existing
        end
        
        local folder = Instance.new("Folder")
        folder.Name = SHARED_STORAGE_NAME
        folder.Parent = replicatedStorage
        return folder
    end)
    
    if success2 then
        sharedTasksFolder = result2
        print("[TCE] Using ReplicatedStorage for shared tasks")
        return result2
    end
    
    warn("[TCE] Could not create shared storage, falling back to local only")
    return nil
end

local function saveTaskToShared(task: Task)
    local success, error = pcall(function()
        local sharedFolder = getOrCreateSharedStorage()
        if not sharedFolder then return end
        
        -- Create or update task object in shared storage
        local existing = sharedFolder:FindFirstChild("Task_" .. task.id)
        local taskObj = existing or Instance.new("StringValue")
        
        if not existing then
            taskObj.Name = "Task_" .. task.id
            taskObj.Parent = sharedFolder
        end
        
        -- Store serialized task data
        local taskData = {
            id = task.id,
            title = task.title,
            description = task.description,
            assignedTo = task.assignedTo,
            assignedBy = task.assignedBy,
            createdAt = task.createdAt,
            updatedAt = task.updatedAt,
            dueDate = task.dueDate,
            priority = task.priority,
            status = task.status,
            taskType = task.taskType,
            estimatedHours = task.estimatedHours,
            actualHours = task.actualHours,
            tags = task.tags,
            comments = task.comments,
            attachments = task.attachments,
            subtasks = task.subtasks,
            parentTask = task.parentTask,
            progress = task.progress
        }
        
        -- Serialize to JSON-like string
        taskObj.Value = game:GetService("HttpService"):JSONEncode(taskData)
        
        -- Add metadata attributes
        taskObj:SetAttribute("LastModified", os.time())
        local localPlayer = Players and Players.LocalPlayer
        taskObj:SetAttribute("ModifiedBy", localPlayer and localPlayer.UserId or 0)
    end)
    
    if not success then
        warn("[TCE] Failed to save task to shared storage:", error)
    end
end

local function deleteTaskFromShared(taskId: string)
    local success, error = pcall(function()
        local sharedFolder = getOrCreateSharedStorage()
        if not sharedFolder then return end
        
        local taskObj = sharedFolder:FindFirstChild("Task_" .. taskId)
        if taskObj then
            taskObj:Destroy()
        end
    end)
    
    if not success then
        warn("[TCE] Failed to delete task from shared storage:", error)
    end
end

local function loadTasksFromShared(): {[string]: Task}
    local sharedTasks = {}
    
    local success, error = pcall(function()
        local sharedFolder = getOrCreateSharedStorage()
        if not sharedFolder then return end
        
        for _, taskObj in ipairs(sharedFolder:GetChildren()) do
            if taskObj:IsA("StringValue") and taskObj.Name:match("^Task_") then
                local success2, taskData = pcall(function()
                    return game:GetService("HttpService"):JSONDecode(taskObj.Value)
                end)
                
                if success2 and taskData then
                    -- Ensure all required fields exist with defaults
                    local task: Task = {
                        id = taskData.id or taskObj.Name:gsub("Task_", ""),
                        title = taskData.title or "Untitled Task",
                        description = taskData.description or "",
                        assignedTo = taskData.assignedTo,
                        assignedBy = taskData.assignedBy or 0,
                        createdAt = taskData.createdAt or os.time(),
                        updatedAt = taskData.updatedAt or os.time(),
                        dueDate = taskData.dueDate,
                        priority = taskData.priority or "Medium",
                        status = taskData.status or "Todo",
                        taskType = taskData.taskType or "Feature",
                        estimatedHours = taskData.estimatedHours,
                        actualHours = taskData.actualHours or 0,
                        tags = taskData.tags or {},
                        comments = taskData.comments or {},
                        attachments = taskData.attachments or {},
                        subtasks = taskData.subtasks or {},
                        parentTask = taskData.parentTask,
                        progress = taskData.progress or 0
                    }
                    
                    sharedTasks[task.id] = task
                end
            end
        end
    end)
    
    if not success then
        warn("[TCE] Failed to load tasks from shared storage:", error)
    end
    
    return sharedTasks
end

local function saveTaskData()
    local success, error = pcall(function()
        if plugin then
            -- Save to plugin settings as backup
            local taskData = {
                version = "1.1",
                timestamp = os.time(),
                tasks = tasks
            }
            plugin:SetSetting(TASK_STORAGE_KEY, taskData)
        end
    end)
    
    if not success then
        warn("[TCE] Failed to save task data to plugin settings:", error)
    end
end

local function loadTaskData()
    -- First, load from shared storage (team tasks)
    local sharedTasks = loadTasksFromShared()
    
    -- Then load from plugin settings (personal backup)
    local localTasks = {}
    local success, savedData = pcall(function()
        if plugin then
            return plugin:GetSetting(TASK_STORAGE_KEY)
        end
        return nil
    end)
    
    if success and savedData and (savedData.version == "1.0" or savedData.version == "1.1") then
        localTasks = savedData.tasks or {}
    end
    
    -- Merge shared and local tasks (shared takes priority)
    tasks = sharedTasks
    
    -- Add any local tasks that aren't in shared storage
    for taskId, localTask in pairs(localTasks) do
        if not tasks[taskId] then
            tasks[taskId] = localTask
            -- Save to shared storage
            saveTaskToShared(localTask)
        end
    end
    
    print("[TCE] Loaded", countTasks(tasks), "tasks (" .. countTasks(sharedTasks) .. " shared, " .. countTasks(localTasks) .. " local)")
    lastSyncTime = os.time()
end

local function syncWithSharedStorage()
    if os.time() - lastSyncTime < SYNC_INTERVAL then
        return
    end
    
    local sharedTasks = loadTasksFromShared()
    local hasChanges = false
    
    -- Check for new or updated tasks in shared storage
    for taskId, sharedTask in pairs(sharedTasks) do
        local localTask = tasks[taskId]
        if not localTask or (sharedTask.updatedAt > localTask.updatedAt) then
            tasks[taskId] = sharedTask
            hasChanges = true
            
            -- Trigger callbacks for updated tasks
            for _, callback in pairs(taskCallbacks) do
                callback(localTask and "task_updated" or "task_created", sharedTask)
            end
        end
    end
    
    -- Check for deleted tasks (exist locally but not in shared)
    for taskId, localTask in pairs(tasks) do
        if not sharedTasks[taskId] then
            tasks[taskId] = nil
            hasChanges = true
            
            -- Trigger callbacks for deleted tasks
            for _, callback in pairs(taskCallbacks) do
                callback("task_deleted", {id = taskId, title = localTask.title})
            end
        end
    end
    
    if hasChanges then
        print("[TCE] Synced tasks from shared storage")
        
        -- Refresh UI if needed
        if UIManager and UIManager.refreshTasks then
            UIManager.refreshTasks()
        end
    end
    
    lastSyncTime = os.time()
end

local function isTaskOverdue(task: Task): boolean
    if not task.dueDate then return false end
    return os.time() > task.dueDate and task.status ~= "Completed" and task.status ~= "Cancelled"
end

local function isTaskDueSoon(task: Task): boolean
    if not task.dueDate then return false end
    local hoursUntilDue = (task.dueDate - os.time()) / 3600
    return hoursUntilDue <= DEADLINE_WARNING_HOURS and hoursUntilDue > 0 and task.status ~= "Completed"
end

local function getUserName(userId: number): string
    local localPlayer = Players and Players.LocalPlayer
    if localPlayer and userId == localPlayer.UserId then
        return localPlayer.Name or "You"
    end
    
    -- Try to get from active users if available
    if ConnectionMonitor and ConnectionMonitor.getActiveUsers then
        local activeUsers = ConnectionMonitor.getActiveUsers()
        for _, user in ipairs(activeUsers) do
            if user.userId == userId then
                return user.name
            end
        end
    end
    
    return "User " .. userId
end

local function validateTask(task: Task): boolean
    if not task.title or task.title == "" then return false end
    if not task.assignedBy or task.assignedBy <= 0 then return false end
    if not task.priority or not task.status or not task.taskType then return false end
    if task.progress < 0 or task.progress > 100 then return false end
    return true
end

local function canManageTask(userId: number, task: Task): boolean
    -- Check if user can manage this task based on permissions
    if not PermissionManager then return true end
    
    -- Task creator can always manage
    if task.assignedBy == userId then return true end
    
    -- Assigned user can update status and progress
    if task.assignedTo == userId then return true end
    
    -- Admins can manage all tasks
    if PermissionManager.hasPermission(userId, "task.manage") then return true end
    
    return false
end

-- Public API

--[[
Creates a new task and adds it to the system.
@param taskData table: Task creation data
@return string?, string: Task ID if successful, error message if failed
]]
function TaskManager.createTask(taskData: {
    title: string,
    description: string?,
    assignedTo: number?,
    dueDate: number?,
    priority: TaskPriority?,
    taskType: TaskType?,
    estimatedHours: number?,
    tags: {string}?
}): (string?, string?)
    local currentUser = Players and Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    
    if not taskData.title or taskData.title == "" then
        return nil, "Task title is required"
    end
    
    if countTasks(tasks) >= MAX_TASKS then
        return nil, "Maximum number of tasks reached"
    end
    
    local taskId = generateTaskId()
    local now = os.time()
    
    local newTask: Task = {
        id = taskId,
        title = taskData.title,
        description = taskData.description or "",
        assignedTo = taskData.assignedTo,
        assignedBy = currentUser,
        createdAt = now,
        updatedAt = now,
        dueDate = taskData.dueDate,
        priority = taskData.priority or "Medium",
        status = "Todo",
        taskType = taskData.taskType or "Feature",
        estimatedHours = taskData.estimatedHours,
        actualHours = 0,
        tags = taskData.tags or {},
        comments = {},
        attachments = {},
        subtasks = {},
        parentTask = nil,
        progress = 0
    }
    
    if not validateTask(newTask) then
        return nil, "Invalid task data"
    end
    
    tasks[taskId] = newTask
    
    -- Save to both local and shared storage
    saveTaskData()
    saveTaskToShared(newTask)
    
    -- Send notifications
    if NotificationManager then
        NotificationManager.sendMessage("Task Created", 
            string.format("Created task: %s", newTask.title), "SUCCESS")
        
        if newTask.assignedTo and newTask.assignedTo ~= currentUser then
            NotificationManager.sendMessage("Task Assigned", 
                string.format("You've been assigned: %s", newTask.title), "INFO")
        end
    end
    
    -- Trigger callbacks
    for _, callback in pairs(taskCallbacks) do
        callback("task_created", newTask)
    end
    
    print("[TCE] Created task:", taskId, "-", newTask.title)
    return taskId, nil
end

--[[
Updates an existing task.
@param taskId string: Task ID to update
@param updates table: Fields to update
@return boolean, string: Success status and error message if failed
]]
function TaskManager.updateTask(taskId: string, updates: any): (boolean, string?)
    local task = tasks[taskId]
    if not task then
        return false, "Task not found"
    end
    
    local currentUser = Players and Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    if not canManageTask(currentUser, task) then
        return false, "Permission denied"
    end
    
    local oldStatus = task.status
    local now = os.time()
    
    -- Apply updates
    for field, value in pairs(updates) do
        if field == "title" or field == "description" or field == "priority" or 
           field == "taskType" or field == "dueDate" or field == "estimatedHours" or
           field == "assignedTo" or field == "status" or field == "progress" then
            task[field] = value
        elseif field == "tags" and type(value) == "table" then
            task.tags = value
        end
    end
    
    task.updatedAt = now
    
    if not validateTask(task) then
        return false, "Invalid task data after update"
    end
    
    -- Auto-complete task if progress reaches 100%
    if task.progress >= 100 and task.status ~= "Completed" then
        task.status = "Completed"
        task.actualHours = task.actualHours or task.estimatedHours or 0
    end
    
    -- Save to both local and shared storage
    saveTaskData()
    saveTaskToShared(task)
    
    -- Send notifications for status changes
    if NotificationManager and oldStatus ~= task.status then
        local statusMessages = {
            InProgress = "started working on",
            Review = "submitted for review",
            Completed = "completed",
            Cancelled = "cancelled"
        }
        
        local message = statusMessages[task.status]
        if message then
            NotificationManager.sendMessage("Task Status Updated", 
                string.format("%s %s: %s", getUserName(currentUser), message, task.title), "INFO")
        end
    end
    
    -- Trigger callbacks
    for _, callback in pairs(taskCallbacks) do
        callback("task_updated", task)
    end
    
    print("[TCE] Updated task:", taskId)
    return true, nil
end

--[[
Deletes a task from the system.
@param taskId string: Task ID to delete
@return boolean, string: Success status and error message if failed
]]
function TaskManager.deleteTask(taskId: string): (boolean, string?)
    local task = tasks[taskId]
    if not task then
        return false, "Task not found"
    end
    
    local currentUser = Players and Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    if not canManageTask(currentUser, task) then
        return false, "Permission denied"
    end
    
    -- Remove from both local and shared storage
    tasks[taskId] = nil
    saveTaskData()
    deleteTaskFromShared(taskId)
    
    if NotificationManager then
        NotificationManager.sendMessage("Task Deleted", 
            string.format("Deleted task: %s", task.title), "WARNING")
    end
    
    -- Trigger callbacks
    for _, callback in pairs(taskCallbacks) do
        callback("task_deleted", {id = taskId, title = task.title})
    end
    
    print("[TCE] Deleted task:", taskId)
    return true, nil
end

--[[
Gets a specific task by ID.
@param taskId string: Task ID
@return Task?: Task data if found
]]
function TaskManager.getTask(taskId: string): Task?
    return tasks[taskId]
end

--[[
Gets all tasks with optional filtering.
@param filter TaskFilter?: Optional filter criteria
@return {Task}: Array of filtered tasks
]]
function TaskManager.getTasks(filter: TaskFilter?): {Task}
    local result = {}
    
    for _, task in pairs(tasks) do
        local include = true
        
        if filter then
            if filter.status and task.status ~= filter.status then include = false end
            if filter.assignedTo and task.assignedTo ~= filter.assignedTo then include = false end
            if filter.priority and task.priority ~= filter.priority then include = false end
            if filter.taskType and task.taskType ~= filter.taskType then include = false end
            
            if filter.dueDate then
                if filter.dueDate.before and task.dueDate and task.dueDate > filter.dueDate.before then include = false end
                if filter.dueDate.after and task.dueDate and task.dueDate < filter.dueDate.after then include = false end
            end
            
            if filter.tags and #filter.tags > 0 then
                local hasTag = false
                for _, filterTag in ipairs(filter.tags) do
                    for _, taskTag in ipairs(task.tags) do
                        if taskTag == filterTag then
                            hasTag = true
                            break
                        end
                    end
                    if hasTag then break end
                end
                if not hasTag then include = false end
            end
        end
        
        if include then
            table.insert(result, task)
        end
    end
    
    -- Sort by priority and due date
    table.sort(result, function(a, b)
        local priorityOrder = {Critical = 4, High = 3, Medium = 2, Low = 1}
        local aPriority = priorityOrder[a.priority] or 2
        local bPriority = priorityOrder[b.priority] or 2
        
        if aPriority ~= bPriority then
            return aPriority > bPriority
        end
        
        if a.dueDate and b.dueDate then
            return a.dueDate < b.dueDate
        elseif a.dueDate then
            return true
        elseif b.dueDate then
            return false
        end
        
        return a.createdAt < b.createdAt
    end)
    
    return result
end

--[[
Gets tasks assigned to current user.
@return {Task}: Array of assigned tasks
]]
function TaskManager.getMyTasks(): {Task}
    local currentUser = Players and Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    return TaskManager.getTasks({assignedTo = currentUser})
end

--[[
Gets overdue tasks.
@return {Task}: Array of overdue tasks
]]
function TaskManager.getOverdueTasks(): {Task}
    local result = {}
    
    for _, task in pairs(tasks) do
        if isTaskOverdue(task) then
            table.insert(result, task)
        end
    end
    
    return result
end

--[[
Gets tasks due soon (within deadline warning period).
@return {Task}: Array of tasks due soon
]]
function TaskManager.getTasksDueSoon(): {Task}
    local result = {}
    
    for _, task in pairs(tasks) do
        if isTaskDueSoon(task) then
            table.insert(result, task)
        end
    end
    
    return result
end

--[[
Adds a comment to a task.
@param taskId string: Task ID
@param content string: Comment content
@return boolean, string: Success status and error message if failed
]]
function TaskManager.addComment(taskId: string, content: string): (boolean, string?)
    local task = tasks[taskId]
    if not task then
        return false, "Task not found"
    end
    
    if not content or content == "" then
        return false, "Comment content is required"
    end
    
    local currentUser = Players and Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    
    local comment: TaskComment = {
        id = generateTaskId(),
        author = currentUser,
        content = content,
        timestamp = os.time(),
        edited = false
    }
    
    table.insert(task.comments, comment)
    task.updatedAt = os.time()
    
    -- Save to both local and shared storage
    saveTaskData()
    saveTaskToShared(task)
    
    if NotificationManager then
        NotificationManager.sendMessage("Comment Added", 
            string.format("Comment added to: %s", task.title), "INFO")
    end
    
    -- Trigger callbacks
    for _, callback in pairs(taskCallbacks) do
        callback("comment_added", {task = task, comment = comment})
    end
    
    return true, nil
end

--[[
Gets task statistics.
@return table: Task statistics
]]
function TaskManager.getTaskStats(): any
    local stats = {
        total = 0,
        byStatus = {},
        byPriority = {},
        byType = {},
        overdue = 0,
        dueSoon = 0,
        myTasks = 0,
        completionRate = 0
    }
    
    local currentUser = Players and Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    local completedTasks = 0
    
    for _, task in pairs(tasks) do
        stats.total = stats.total + 1
        
        stats.byStatus[task.status] = (stats.byStatus[task.status] or 0) + 1
        stats.byPriority[task.priority] = (stats.byPriority[task.priority] or 0) + 1
        stats.byType[task.taskType] = (stats.byType[task.taskType] or 0) + 1
        
        if task.assignedTo == currentUser then
            stats.myTasks = stats.myTasks + 1
        end
        
        if task.status == "Completed" then
            completedTasks = completedTasks + 1
        end
        
        if isTaskOverdue(task) then
            stats.overdue = stats.overdue + 1
        end
        
        if isTaskDueSoon(task) then
            stats.dueSoon = stats.dueSoon + 1
        end
    end
    
    if stats.total > 0 then
        stats.completionRate = (completedTasks / stats.total) * 100
    end
    
    return stats
end

--[[
Registers a callback for task events.
@param id string: Unique callback id
@param callback function: Callback function
]]
function TaskManager.registerCallback(id: string, callback: (string, any) -> ()): ()
    taskCallbacks[id] = callback
end

--[[
Unregisters a task event callback by id.
@param id string: Callback id
]]
function TaskManager.unregisterCallback(id: string): ()
    taskCallbacks[id] = nil
end

--[[
Checks for deadline warnings and sends notifications.
]]
function TaskManager.checkDeadlineWarnings(): ()
    local overdueTasks = TaskManager.getOverdueTasks()
    local dueSoonTasks = TaskManager.getTasksDueSoon()
    
    if #overdueTasks > 0 and NotificationManager then
        NotificationManager.sendMessage("Overdue Tasks", 
            string.format("You have %d overdue task(s)", #overdueTasks), "ERROR")
    end
    
    if #dueSoonTasks > 0 and NotificationManager then
        NotificationManager.sendMessage("Upcoming Deadlines", 
            string.format("%d task(s) due within 24 hours", #dueSoonTasks), "WARNING")
    end
end

--[[
Initializes the TaskManager with plugin state.
@param state table: Plugin state
]]
function TaskManager.initialize(state: any): ()
    pluginState = state
    
    -- Initialize shared storage
    getOrCreateSharedStorage()
    
    -- Load saved task data (shared + local)
    loadTaskData()
    
    -- Start sync timer
    if syncConnection then
        syncConnection:Disconnect()
    end
    
    syncConnection = RunService.Heartbeat:Connect(function()
        syncWithSharedStorage()
    end)
    
    print("[TCE] Task Manager initialized with", countTasks(tasks), "tasks (shared storage enabled)")
end

--[[
Sets module references for cross-module integration.
@param permissionManagerRef table: PermissionManager reference
@param notificationManagerRef table: NotificationManager reference
]]
function TaskManager.setModuleReferences(permissionManagerRef: any, notificationManagerRef: any): ()
    PermissionManager = permissionManagerRef
    NotificationManager = notificationManagerRef
    print("[TCE] TaskManager: Module references set")
end

--[[
Cleans up the TaskManager (saves state, clears callbacks).
]]
function TaskManager.cleanup(): ()
    -- Stop sync timer
    if syncConnection then
        syncConnection:Disconnect()
        syncConnection = nil
    end
    
    -- Save final state
    saveTaskData()
    
    -- Clear callbacks
    taskCallbacks = {}
    
    print("[TCE] Task Manager cleaned up")
end

-- Helper function to count table elements
local function countTasks(taskTable)
    local count = 0
    for _ in pairs(taskTable) do 
        count = count + 1 
    end
    return count
end

return TaskManager 