-- src/shared/modules/UIManager/TasksPanel.lua
-- Task management panel and dialogs

local TasksPanel = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Module references (will be injected)
local TaskManager = nil
local ConnectionMonitor = nil
local NotificationManager = nil
local UIUtilities = nil
local dockWidget = nil

-- Local variables
local tasksPanel = nil
local currentTaskFilter = "All"

function TasksPanel.initialize(refs)
    TaskManager = refs.TaskManager
    ConnectionMonitor = refs.ConnectionMonitor
    NotificationManager = refs.NotificationManager
    UIUtilities = refs.UIUtilities
    dockWidget = refs.dockWidget
end

function TasksPanel.createPanel(parent)
    tasksPanel = UIUtilities.createRoundedFrame(parent, {
        Name = "TasksPanel",
        Size = UDim2.new(1, -20, 1, -80),
        Position = UDim2.new(0, 10, 0, 70)
    })
    
    -- Header with title and new task button
    local header = UIUtilities.createRoundedFrame(tasksPanel, {
        Name = "TaskHeader",
        Size = UDim2.new(1, -20, 0, 60),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG
    })
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TaskTitle"
    titleLabel.Parent = header
    titleLabel.Size = UDim2.new(0.4, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "📋 Task Management"
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Task statistics
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "TaskStats"
    statsLabel.Parent = header
    statsLabel.Size = UDim2.new(0.35, 0, 1, 0)
    statsLabel.Position = UDim2.new(0.4, 0, 0, 0)
    statsLabel.BackgroundTransparency = 1
    statsLabel.Text = "Total: 0 | Mine: 0"
    statsLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    statsLabel.TextScaled = true
    statsLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    statsLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- New Task button
    local newTaskButton = UIUtilities.createStyledButton(header, {
        Name = "NewTaskButton",
        Text = "➕ New Task",
        Size = UDim2.new(0.2, 0, 0, 40),
        Position = UDim2.new(0.78, 0, 0, 10),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SUCCESS_GREEN
    })
    
    newTaskButton.MouseButton1Click:Connect(function()
        TasksPanel.showNewTaskDialog()
    end)
    
    -- Filter buttons
    local filterFrame = UIUtilities.createRoundedFrame(tasksPanel, {
        Name = "FilterFrame",
        Size = UDim2.new(1, -20, 0, 50),
        Position = UDim2.new(0, 10, 0, 80),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    local filterLabel = Instance.new("TextLabel")
    filterLabel.Name = "FilterLabel"
    filterLabel.Parent = filterFrame
    filterLabel.Size = UDim2.new(0, 60, 1, 0)
    filterLabel.Position = UDim2.new(0, 10, 0, 0)
    filterLabel.BackgroundTransparency = 1
    filterLabel.Text = "🔍 Filters:"
    filterLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    filterLabel.TextScaled = true
    filterLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    filterLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Filter buttons
    local filters = {"All", "My Tasks", "To Do", "In Progress", "Overdue"}
    for i, filter in ipairs(filters) do
        local filterButton = UIUtilities.createStyledButton(filterFrame, {
            Name = filter .. "Filter",
            Text = filter,
            Size = UDim2.new(0.15, 0, 0, 30),
            Position = UDim2.new(0.1 + (i-1) * 0.16, 0, 0, 10),
            BackgroundColor3 = currentTaskFilter == filter and UIUtilities.CONSTANTS.COLORS.ACCENT_TEAL or UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
        })
        
        filterButton.MouseButton1Click:Connect(function()
            TasksPanel.setFilter(filter)
        end)
    end
    
    -- Priority filter buttons
    local priorityLabel = Instance.new("TextLabel")
    priorityLabel.Name = "PriorityLabel"
    priorityLabel.Parent = filterFrame
    priorityLabel.Size = UDim2.new(0, 60, 0, 15)
    priorityLabel.Position = UDim2.new(0, 10, 0, 25)
    priorityLabel.BackgroundTransparency = 1
    priorityLabel.Text = "Priority:"
    priorityLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    priorityLabel.TextScaled = true
    priorityLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    priorityLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local priorities = {"Critical", "High", "Medium", "Low"}
    local priorityColors = {
        Critical = UIUtilities.CONSTANTS.COLORS.ERROR_RED,
        High = UIUtilities.CONSTANTS.COLORS.ACCENT_MAGENTA,
        Medium = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE,
        Low = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    }
    
    for i, priority in ipairs(priorities) do
        local priorityButton = UIUtilities.createStyledButton(filterFrame, {
            Name = priority .. "Priority",
            Text = priority,
            Size = UDim2.new(0.15, 0, 0, 15),
            Position = UDim2.new(0.1 + (i-1) * 0.16, 0, 0, 30),
            BackgroundColor3 = priorityColors[priority]
        })
        
        priorityButton.MouseButton1Click:Connect(function()
            TasksPanel.setFilter(priority)
        end)
    end
    
    -- Tasks scroll frame
    local tasksScrollFrame = UIUtilities.createScrollFrame(tasksPanel, {
        Name = "TasksScrollFrame",
        Size = UDim2.new(1, -20, 1, -150),
        Position = UDim2.new(0, 10, 0, 140)
    })
    
    return tasksPanel
end

function TasksPanel.setFilter(filter)
    currentTaskFilter = filter
    TasksPanel.refreshTasks()
    
    -- Update filter button colors
    local filterFrame = tasksPanel:FindFirstChild("FilterFrame")
    if filterFrame then
        for _, child in ipairs(filterFrame:GetChildren()) do
            if child:IsA("TextButton") and child.Name:find("Filter") then
                local isSelected = child.Text == filter
                child.BackgroundColor3 = isSelected and UIUtilities.CONSTANTS.COLORS.ACCENT_TEAL or UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
            end
        end
    end
end

function TasksPanel.refreshTasks()
    if not TaskManager or not tasksPanel then return end
    
    local tasksScrollFrame = tasksPanel:FindFirstChild("TasksScrollFrame")
    if not tasksScrollFrame then return end
    
    -- Clear existing task entries
    for _, child in ipairs(tasksScrollFrame:GetChildren()) do
        if child.Name:find("Task_") then
            child:Destroy()
        end
    end
    
    -- Get filtered tasks
    local allTasks = TaskManager.getTasks()
    local filteredTasks = {}
    
    for _, task in ipairs(allTasks) do
        local include = false
        
        if currentTaskFilter == "All" then
            include = true
        elseif currentTaskFilter == "My Tasks" then
            local localPlayer = Players and Players.LocalPlayer
            include = localPlayer and task.assignedTo == localPlayer.UserId
        elseif currentTaskFilter == "To Do" then
            include = task.status == "Todo"
        elseif currentTaskFilter == "In Progress" then
            include = task.status == "InProgress"
        elseif currentTaskFilter == "Overdue" then
            include = task.dueDate and os.time() > task.dueDate and task.status ~= "Completed"
        elseif currentTaskFilter == "Critical" or currentTaskFilter == "High" or currentTaskFilter == "Medium" or currentTaskFilter == "Low" then
            include = task.priority == currentTaskFilter
        end
        
        if include then
            table.insert(filteredTasks, task)
        end
    end
    
    -- Update statistics
    local statsLabel = tasksPanel:FindFirstChild("TaskHeader"):FindFirstChild("TaskStats")
    if statsLabel then
        local myTaskCount = 0
        local localPlayer = Players and Players.LocalPlayer
        if localPlayer then
            for _, task in ipairs(allTasks) do
                if task.assignedTo == localPlayer.UserId then
                    myTaskCount = myTaskCount + 1
                end
            end
        end
        statsLabel.Text = string.format("Total: %d | Mine: %d", #allTasks, myTaskCount)
    end
    
    -- Create task entries
    local yOffset = 10
    for _, task in ipairs(filteredTasks) do
        local taskEntry = TasksPanel.createTaskEntry(tasksScrollFrame, task, yOffset)
        yOffset = yOffset + 65
    end
    
    -- Update canvas size
    tasksScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(yOffset, tasksScrollFrame.AbsoluteSize.Y))
end

function TasksPanel.createTaskEntry(parent, task, yOffset)
    local taskEntry = UIUtilities.createRoundedFrame(parent, {
        Name = "Task_" .. task.id,
        Size = UDim2.new(1, -10, 0, 60),
        Position = UDim2.new(0, 5, 0, yOffset),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
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
        local hoverTween = TweenService:Create(taskEntry, TweenInfo.new(0.2), {BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE})
        hoverTween:Play()
    end)
    
    clickDetector.MouseLeave:Connect(function()
        local normalTween = TweenService:Create(taskEntry, TweenInfo.new(0.2), {BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG})
        normalTween:Play()
    end)
    
    -- Add click handler to open edit dialog
    clickDetector.MouseButton1Click:Connect(function()
        TasksPanel.showEditTaskDialog(task)
    end)
    
    -- Priority indicator
    local priorityColors = {
        Critical = UIUtilities.CONSTANTS.COLORS.ERROR_RED,
        High = UIUtilities.CONSTANTS.COLORS.ACCENT_MAGENTA,
        Medium = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE,
        Low = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    }
    
    local priorityDot = UIUtilities.createStatusIndicator(taskEntry, {
        Name = "PriorityDot",
        Position = UDim2.new(0, 8, 0, 8),
        Color = priorityColors[task.priority] or UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
    })
    
    -- Task title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Parent = taskEntry
    titleLabel.Size = UDim2.new(0.6, -30, 0, 20)
    titleLabel.Position = UDim2.new(0, 25, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = task.title
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Task status
    local statusColors = {
        Todo = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY,
        InProgress = UIUtilities.CONSTANTS.COLORS.ACCENT_TEAL,
        Review = UIUtilities.CONSTANTS.COLORS.ACCENT_PURPLE,
        Completed = UIUtilities.CONSTANTS.COLORS.SUCCESS_GREEN,
        Cancelled = UIUtilities.CONSTANTS.COLORS.ERROR_RED
    }
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Parent = taskEntry
    statusLabel.Size = UDim2.new(0.3, 0, 0, 18)
    statusLabel.Position = UDim2.new(0.6, 5, 0, 6)
    statusLabel.BackgroundColor3 = statusColors[task.status] or UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    statusLabel.BorderSizePixel = 0
    statusLabel.Text = task.status
    statusLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    statusLabel.TextScaled = true
    statusLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Round status label
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusLabel
    
    -- Assigned user info
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
    
    -- Add task type and description
    if task.taskType then
        assignedText = assignedText .. " • 📝 " .. task.taskType
    end
    
    if task.description and task.description ~= "" then
        assignedText = assignedText .. " • " .. task.description
    end
    
    local assignedLabel = Instance.new("TextLabel")
    assignedLabel.Name = "AssignedLabel"
    assignedLabel.Parent = taskEntry
    assignedLabel.Size = UDim2.new(0.6, -30, 0, 15)
    assignedLabel.Position = UDim2.new(0, 25, 0, 25)
    assignedLabel.BackgroundTransparency = 1
    assignedLabel.Text = assignedText
    assignedLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    assignedLabel.TextScaled = true
    assignedLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    assignedLabel.TextXAlignment = Enum.TextXAlignment.Left
    assignedLabel.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Due date indicator
    if task.dueDate then
        local currentTime = os.time()
        local timeUntilDue = task.dueDate - currentTime
        local daysUntilDue = math.floor(timeUntilDue / 86400)
        local hoursUntilDue = math.floor(timeUntilDue / 3600)
        
        local dueDateText = ""
        local dueDateColor = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
        
        if timeUntilDue < 0 then
            dueDateText = "🔴 OVERDUE"
            dueDateColor = UIUtilities.CONSTANTS.COLORS.ERROR_RED
        elseif daysUntilDue == 0 and hoursUntilDue > 0 then
            dueDateText = "🟡 Due in " .. hoursUntilDue .. "h"
            dueDateColor = UIUtilities.CONSTANTS.COLORS.ACCENT_MAGENTA
        elseif daysUntilDue == 0 then
            dueDateText = "🔴 Due now!"
            dueDateColor = UIUtilities.CONSTANTS.COLORS.ERROR_RED
        elseif daysUntilDue == 1 then
            dueDateText = "🟠 Tomorrow"
            dueDateColor = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
        elseif daysUntilDue <= 3 then
            dueDateText = "🟡 " .. daysUntilDue .. " days"
            dueDateColor = UIUtilities.CONSTANTS.COLORS.ACCENT_TEAL
        else
            dueDateText = "📅 " .. os.date("%m/%d", task.dueDate)
            dueDateColor = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
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
        dueDateLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
        dueDateLabel.TextXAlignment = Enum.TextXAlignment.Right
    end
    
    -- Comments indicator
    if task.comments and #task.comments > 0 then
        local commentsLabel = Instance.new("TextLabel")
        commentsLabel.Name = "CommentsLabel"
        commentsLabel.Parent = taskEntry
        commentsLabel.Size = UDim2.new(0, 30, 0, 15)
        commentsLabel.Position = UDim2.new(1, -35, 0, 40)
        commentsLabel.BackgroundTransparency = 1
        commentsLabel.Text = "💬 " .. #task.comments
        commentsLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
        commentsLabel.TextScaled = true
        commentsLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
        commentsLabel.TextXAlignment = Enum.TextXAlignment.Center
    end
    
    -- Progress bar
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBg"
    progressBg.Parent = taskEntry
    progressBg.Size = UDim2.new(0.7, 0, 0, 6)
    progressBg.Position = UDim2.new(0, 8, 1, -12)
    progressBg.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG
    progressBg.BorderSizePixel = 0
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 3)
    progressCorner.Parent = progressBg
    
    -- Progress fill with color based on progress
    local progressColor = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    if task.progress >= 100 then
        progressColor = UIUtilities.CONSTANTS.COLORS.SUCCESS_GREEN
    elseif task.progress >= 75 then
        progressColor = UIUtilities.CONSTANTS.COLORS.ACCENT_TEAL
    elseif task.progress >= 50 then
        progressColor = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
    elseif task.progress >= 25 then
        progressColor = UIUtilities.CONSTANTS.COLORS.ACCENT_PURPLE
    elseif task.progress > 0 then
        progressColor = UIUtilities.CONSTANTS.COLORS.ACCENT_MAGENTA
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
    progressLabel.TextColor3 = task.progress >= 100 and UIUtilities.CONSTANTS.COLORS.SUCCESS_GREEN or UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    progressLabel.TextScaled = true
    progressLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    progressLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    return taskEntry
end

-- This function will contain the large new task dialog code
function TasksPanel.showNewTaskDialog()
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
    
    -- Create compact dialog frame
    local dialog = UIUtilities.createRoundedFrame(overlay, {
        Name = "NewTaskDialog",
        Size = UDim2.new(0, 400, 0, 300),
        Position = UDim2.new(0.5, -200, 0.5, -150),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true,
        GlowColor = UIUtilities.CONSTANTS.COLORS.ACCENT_PURPLE
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
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 102
    
    -- Close button
    local closeButton = UIUtilities.createStyledButton(dialog, {
        Name = "CloseButton",
        Text = "✕",
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(1, -35, 0, 10),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.ERROR_RED
    })
    closeButton.ZIndex = 102
    
    closeButton.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    -- Task title input
    local titleInput = Instance.new("TextBox")
    titleInput.Name = "TitleInput"
    titleInput.Parent = dialog
    titleInput.Size = UDim2.new(1, -40, 0, 30)
    titleInput.Position = UDim2.new(0, 20, 0, 60)
    titleInput.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    titleInput.BorderSizePixel = 0
    titleInput.Text = ""
    titleInput.PlaceholderText = "Enter task title..."
    titleInput.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleInput.PlaceholderColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    titleInput.TextScaled = true
    titleInput.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    titleInput.TextXAlignment = Enum.TextXAlignment.Left
    titleInput.ZIndex = 102
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 4)
    titleCorner.Parent = titleInput
    
    -- Description input
    local descInput = Instance.new("TextBox")
    descInput.Name = "DescInput"
    descInput.Parent = dialog
    descInput.Size = UDim2.new(1, -40, 0, 50)
    descInput.Position = UDim2.new(0, 20, 0, 100)
    descInput.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    descInput.BorderSizePixel = 0
    descInput.Text = ""
    descInput.PlaceholderText = "Enter description..."
    descInput.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    descInput.PlaceholderColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    descInput.TextScaled = true
    descInput.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    descInput.TextXAlignment = Enum.TextXAlignment.Left
    descInput.TextYAlignment = Enum.TextYAlignment.Top
    descInput.TextWrapped = true
    descInput.MultiLine = true
    descInput.ZIndex = 102
    
    local descCorner = Instance.new("UICorner")
    descCorner.CornerRadius = UDim.new(0, 4)
    descCorner.Parent = descInput
    
    -- Priority selection
    local selectedPriority = "Medium"
    local priorities = {"Critical", "High", "Medium", "Low"}
    local priorityColors = {
        Critical = UIUtilities.CONSTANTS.COLORS.ERROR_RED,
        High = UIUtilities.CONSTANTS.COLORS.ACCENT_MAGENTA,
        Medium = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE,
        Low = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    }
    
    for i, priority in ipairs(priorities) do
        local priorityButton = UIUtilities.createStyledButton(dialog, {
            Name = priority .. "Button",
            Text = priority,
            Size = UDim2.new(0.23, 0, 0, 30),
            Position = UDim2.new((i-1) * 0.25, 20, 0, 160),
            BackgroundColor3 = priority == selectedPriority and priorityColors[priority] or UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
        })
        priorityButton.ZIndex = 102
        
        priorityButton.MouseButton1Click:Connect(function()
            selectedPriority = priority
        end)
    end
    
    -- Action buttons
    local cancelButton = UIUtilities.createStyledButton(dialog, {
        Name = "CancelButton",
        Text = "Cancel",
        Size = UDim2.new(0.4, 0, 0, 40),
        Position = UDim2.new(0, 20, 0, 240),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    })
    cancelButton.ZIndex = 102
    
    cancelButton.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    local createButton = UIUtilities.createStyledButton(dialog, {
        Name = "CreateButton",
        Text = "Create Task",
        Size = UDim2.new(0.55, 0, 0, 40),
        Position = UDim2.new(0.45, 0, 0, 240),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SUCCESS_GREEN
    })
    createButton.ZIndex = 102
    
    createButton.MouseButton1Click:Connect(function()
        local title = titleInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if title == "" then
            -- Show error
            titleInput.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.ERROR_RED
            wait(0.5)
            titleInput.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
            return
        end
        
        -- Create the task
        local taskData = {
            title = title,
            description = descInput.Text,
            priority = selectedPriority,
            taskType = "Feature",
            tags = {}
        }
        
        local taskId, error = TaskManager.createTask(taskData)
        
        if taskId then
            print("[TCE] Created task:", taskId, "-", title)
            overlay:Destroy()
            
            -- Refresh the tasks panel
            TasksPanel.refreshTasks()
            
            -- Show success notification
            if NotificationManager then
                NotificationManager.sendMessage("Task Created", 
                    string.format("Successfully created task: %s", title), "SUCCESS")
            end
        else
            print("[TCE] Failed to create task:", error)
        end
    end)
    
    -- Focus on title input
    titleInput:CaptureFocus()
end

-- Simplified edit dialog (the full version would be even larger)
function TasksPanel.showEditTaskDialog(task)
    if not TaskManager or not task then
        print("[TCE] TaskManager or task not available")
        return
    end
    
    -- Create a simplified edit dialog for now
    local overlay = Instance.new("Frame")
    overlay.Name = "EditTaskDialogOverlay"
    overlay.Parent = dockWidget
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 100
    
    local dialog = UIUtilities.createRoundedFrame(overlay, {
        Name = "EditTaskDialog",
        Size = UDim2.new(0, 400, 0, 200),
        Position = UDim2.new(0.5, -200, 0.5, -100),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Glow = true,
        GlowColor = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
    })
    dialog.ZIndex = 101
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = dialog
    titleLabel.Size = UDim2.new(1, -40, 0, 30)
    titleLabel.Position = UDim2.new(0, 20, 0, 15)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "✏️ Edit Task: " .. task.title
    titleLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    titleLabel.TextScaled = true
    titleLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADER
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 102
    
    local closeButton = UIUtilities.createStyledButton(dialog, {
        Name = "CloseButton",
        Text = "Close",
        Size = UDim2.new(0, 80, 0, 30),
        Position = UDim2.new(0.5, -40, 0, 150),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    })
    closeButton.ZIndex = 102
    
    closeButton.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Parent = dialog
    infoLabel.Size = UDim2.new(1, -40, 0, 80)
    infoLabel.Position = UDim2.new(0, 20, 0, 60)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = string.format("Status: %s\nProgress: %d%%\nPriority: %s", task.status, task.progress, task.priority)
    infoLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    infoLabel.TextScaled = true
    infoLabel.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    infoLabel.ZIndex = 102
end

return TasksPanel 