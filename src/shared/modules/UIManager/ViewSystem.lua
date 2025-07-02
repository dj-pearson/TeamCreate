-- src/shared/modules/UIManager/ViewSystem.lua
-- Multi-view system for task management (ClickUp-inspired views)

local ViewSystem = {}

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Module references (will be injected)
local UIUtilities = nil
local TaskManager = nil

-- View state
local currentView = "list"
local viewContainer = nil
local viewData = {}
local filters = {
    status = nil,
    assignee = nil,
    priority = nil,
    search = ""
}

-- View types
local VIEW_TYPES = {
    LIST = "list",
    BOARD = "board", 
    CALENDAR = "calendar",
    TIMELINE = "timeline"
}

-- Initialize the view system
function ViewSystem.initialize(refs)
    UIUtilities = refs.UIUtilities
    TaskManager = refs.TaskManager
    print("[TCE] ViewSystem initialized")
end

-- Create the main view container
function ViewSystem.createViewContainer(parent)
    viewContainer = UIUtilities.createCard(parent, {
        Name = "ViewContainer",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.PRIMARY_BG,
        Shadow = false
    })
    
    -- Create view header with controls
    ViewSystem.createViewHeader(viewContainer)
    
    -- Create view content area
    local contentArea = UIUtilities.createCard(viewContainer, {
        Name = "ViewContent",
        Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_LG, 1, -100),
        Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_MD, 0, 80),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    -- Initialize with list view
    ViewSystem.switchView(VIEW_TYPES.LIST)
    
    return viewContainer
end

-- Create view header with view switcher and controls
function ViewSystem.createViewHeader(parent)
    local header = UIUtilities.createCard(parent, {
        Name = "ViewHeader",
        Size = UDim2.new(1, -UIUtilities.CONSTANTS.SIZES.PADDING_LG, 0, 64),
        Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_MD, 0, UIUtilities.CONSTANTS.SIZES.PADDING_MD),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    })
    
    -- View switcher buttons
    local viewButtons = {
        {id = VIEW_TYPES.LIST, text = "📋 List", icon = "📋"},
        {id = VIEW_TYPES.BOARD, text = "📌 Board", icon = "📌"},
        {id = VIEW_TYPES.CALENDAR, text = "📅 Calendar", icon = "📅"},
        {id = VIEW_TYPES.TIMELINE, text = "📊 Timeline", icon = "📊"}
    }
    
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "ViewButtons"
    buttonContainer.Parent = header
    buttonContainer.Size = UDim2.new(0, 400, 0, 36)
    buttonContainer.Position = UDim2.new(0, 0, 0.5, -18)
    buttonContainer.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(buttonContainer, {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_XS
    })
    
    for i, viewButton in ipairs(viewButtons) do
        local button = UIUtilities.createButton(buttonContainer, {
            Name = viewButton.id .. "ViewButton",
            Text = viewButton.text,
            Size = UDim2.new(0, 90, 0, 36),
            Variant = currentView == viewButton.id and "primary" or "outline",
            CornerRadius = UIUtilities.CONSTANTS.SIZES.RADIUS_MD
        })
        
        button.MouseButton1Click:Connect(function()
            ViewSystem.switchView(viewButton.id)
        end)
    end
    
    -- Search and filter controls
    local controlsContainer = Instance.new("Frame")
    controlsContainer.Name = "Controls"
    controlsContainer.Parent = header
    controlsContainer.Size = UDim2.new(0, 400, 0, 36)
    controlsContainer.Position = UDim2.new(1, -400, 0.5, -18)
    controlsContainer.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(controlsContainer, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_SM
    })
    
    -- Search input
    local searchContainer, searchInput = UIUtilities.createInput(controlsContainer, {
        Name = "SearchInput",
        Size = UDim2.new(0, 200, 0, 36),
        PlaceholderText = "🔍 Search tasks..."
    })
    
    searchInput.Changed:Connect(function(property)
        if property == "Text" then
            filters.search = searchInput.Text
            ViewSystem.refreshCurrentView()
        end
    end)
    
    -- Filter dropdown
    local filterDropdown = UIUtilities.createDropdown(controlsContainer, {
        Name = "FilterDropdown",
        Size = UDim2.new(0, 120, 0, 36),
        SelectedText = "🔽 Filters"
    })
    
    -- New task button
    local newTaskButton = UIUtilities.createButton(controlsContainer, {
        Name = "NewTaskButton",
        Text = "➕ New Task",
        Size = UDim2.new(0, 100, 0, 36),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SUCCESS
    })
    
    newTaskButton.MouseButton1Click:Connect(function()
        ViewSystem.showNewTaskDialog()
    end)
end

-- Switch between different views
function ViewSystem.switchView(viewType)
    if currentView == viewType then return end
    
    currentView = viewType
    ViewSystem.updateViewButtons()
    ViewSystem.renderCurrentView()
    
    print("[TCE] Switched to view:", viewType)
end

-- Update view button states
function ViewSystem.updateViewButtons()
    if not viewContainer then return end
    
    local buttonContainer = viewContainer:FindFirstChild("ViewHeader"):FindFirstChild("ViewButtons")
    if not buttonContainer then return end
    
    for _, button in ipairs(buttonContainer:GetChildren()) do
        if button:IsA("TextButton") then
            local isActive = button.Name:find(currentView)
            button.BackgroundColor3 = isActive and UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY or UIUtilities.CONSTANTS.COLORS.SURFACE
            button.TextColor3 = isActive and UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY or UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
        end
    end
end

-- Render the current view
function ViewSystem.renderCurrentView()
    if not viewContainer then return end
    
    local contentArea = viewContainer:FindFirstChild("ViewContent")
    if not contentArea then return end
    
    -- Clear existing content
    for _, child in ipairs(contentArea:GetChildren()) do
        if not child:IsA("UICorner") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    
    -- Render based on current view
    if currentView == VIEW_TYPES.LIST then
        ViewSystem.renderListView(contentArea)
    elseif currentView == VIEW_TYPES.BOARD then
        ViewSystem.renderBoardView(contentArea)
    elseif currentView == VIEW_TYPES.CALENDAR then
        ViewSystem.renderCalendarView(contentArea)
    elseif currentView == VIEW_TYPES.TIMELINE then
        ViewSystem.renderTimelineView(contentArea)
    end
end

-- LIST VIEW - Traditional task list with modern styling
function ViewSystem.renderListView(parent)
    local scrollFrame = UIUtilities.createScrollFrame(parent, {
        Name = "TaskListScroll",
        Size = UDim2.new(1, 0, 1, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y
    })
    
    local listContainer = Instance.new("Frame")
    listContainer.Name = "TaskList"
    listContainer.Parent = scrollFrame
    listContainer.Size = UDim2.new(1, 0, 1, 0)
    listContainer.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(listContainer, {
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_SM
    })
    
    -- Get and filter tasks
    local tasks = ViewSystem.getFilteredTasks()
    
    -- Create task cards
    for i, task in ipairs(tasks) do
        ViewSystem.createTaskCard(listContainer, task, "list")
    end
end

-- BOARD VIEW - Kanban-style columns
function ViewSystem.renderBoardView(parent)
    local boardContainer = Instance.new("Frame")
    boardContainer.Name = "BoardContainer"
    boardContainer.Parent = parent
    boardContainer.Size = UDim2.new(1, 0, 1, 0)
    boardContainer.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(boardContainer, {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_MD
    })
    
    -- Status columns
    local statusColumns = {
        {id = "Todo", title = "📝 To Do", color = UIUtilities.CONSTANTS.COLORS.STATUS_TODO},
        {id = "InProgress", title = "🔄 In Progress", color = UIUtilities.CONSTANTS.COLORS.STATUS_PROGRESS},
        {id = "Review", title = "👀 Review", color = UIUtilities.CONSTANTS.COLORS.STATUS_REVIEW},
        {id = "Completed", title = "✅ Completed", color = UIUtilities.CONSTANTS.COLORS.STATUS_COMPLETED}
    }
    
    local tasks = ViewSystem.getFilteredTasks()
    
    for _, column in ipairs(statusColumns) do
        ViewSystem.createBoardColumn(boardContainer, column, tasks)
    end
end

-- CALENDAR VIEW - Month/week calendar with task indicators
function ViewSystem.renderCalendarView(parent)
    local calendarContainer = Instance.new("Frame")
    calendarContainer.Name = "CalendarContainer"
    calendarContainer.Parent = parent
    calendarContainer.Size = UDim2.new(1, 0, 1, 0)
    calendarContainer.BackgroundTransparency = 1
    
    -- Calendar header
    local header = UIUtilities.createCard(calendarContainer, {
        Name = "CalendarHeader",
        Size = UDim2.new(1, 0, 0, 60),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.TERTIARY_BG
    })
    
    local monthLabel = Instance.new("TextLabel")
    monthLabel.Name = "MonthLabel"
    monthLabel.Parent = header
    monthLabel.Size = UDim2.new(1, 0, 1, 0)
    monthLabel.BackgroundTransparency = 1
    monthLabel.Text = os.date("%B %Y")
    monthLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    monthLabel.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XL
    monthLabel.Font = UIUtilities.CONSTANTS.FONTS.HEADING
    monthLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Calendar grid
    local calendarGrid = Instance.new("Frame")
    calendarGrid.Name = "CalendarGrid"
    calendarGrid.Parent = calendarContainer
    calendarGrid.Size = UDim2.new(1, 0, 1, -80)
    calendarGrid.Position = UDim2.new(0, 0, 0, 70)
    calendarGrid.BackgroundTransparency = 1
    
    UIUtilities.applyGridLayout(calendarGrid, {
        CellSize = UDim2.new(0.14, -2, 0.16, -2),
        CellPadding = UDim2.new(0, 2, 0, 2)
    })
    
    -- Day headers
    local dayNames = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
    for _, dayName in ipairs(dayNames) do
        local dayHeader = UIUtilities.createCard(calendarGrid, {
            Name = "DayHeader_" .. dayName,
            BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.TERTIARY_BG
        })
        
        local dayLabel = Instance.new("TextLabel")
        dayLabel.Parent = dayHeader
        dayLabel.Size = UDim2.new(1, 0, 1, 0)
        dayLabel.BackgroundTransparency = 1
        dayLabel.Text = dayName
        dayLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
        dayLabel.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
        dayLabel.Font = UIUtilities.CONSTANTS.FONTS.BODY
        dayLabel.TextXAlignment = Enum.TextXAlignment.Center
    end
    
    -- Calendar days (simplified - shows current month)
    local currentDate = os.date("*t")
    local daysInMonth = 30 -- Simplified
    
    for day = 1, daysInMonth do
        local dayCard = ViewSystem.createCalendarDay(calendarGrid, day, currentDate)
    end
end

-- TIMELINE VIEW - Gantt chart style
function ViewSystem.renderTimelineView(parent)
    local timelineContainer = Instance.new("Frame")
    timelineContainer.Name = "TimelineContainer"
    timelineContainer.Parent = parent
    timelineContainer.Size = UDim2.new(1, 0, 1, 0)
    timelineContainer.BackgroundTransparency = 1
    
    -- Timeline header with date range
    local header = UIUtilities.createCard(timelineContainer, {
        Name = "TimelineHeader",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.TERTIARY_BG
    })
    
    -- Date markers
    local dateContainer = Instance.new("Frame")
    dateContainer.Name = "DateContainer"
    dateContainer.Parent = header
    dateContainer.Size = UDim2.new(1, -200, 1, 0)
    dateContainer.Position = UDim2.new(0, 200, 0, 0)
    dateContainer.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(dateContainer, {
        FillDirection = Enum.FillDirection.Horizontal
    })
    
    -- Create date markers for next 7 days
    for i = 0, 6 do
        local date = os.date("*t", os.time() + (i * 24 * 60 * 60))
        local dateMarker = Instance.new("TextLabel")
        dateMarker.Name = "DateMarker_" .. i
        dateMarker.Parent = dateContainer
        dateMarker.Size = UDim2.new(0.14, 0, 1, 0)
        dateMarker.BackgroundTransparency = 1
        dateMarker.Text = os.date("%m/%d", os.time() + (i * 24 * 60 * 60))
        dateMarker.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
        dateMarker.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
        dateMarker.Font = UIUtilities.CONSTANTS.FONTS.BODY
        dateMarker.TextXAlignment = Enum.TextXAlignment.Center
    end
    
    -- Timeline content
    local scrollFrame = UIUtilities.createScrollFrame(timelineContainer, {
        Name = "TimelineScroll",
        Size = UDim2.new(1, 0, 1, -60),
        Position = UDim2.new(0, 0, 0, 60),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    
    local timelineContent = Instance.new("Frame")
    timelineContent.Name = "TimelineContent"
    timelineContent.Parent = scrollFrame
    timelineContent.Size = UDim2.new(1, 0, 1, 0)
    timelineContent.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(timelineContent, {
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_SM
    })
    
    -- Get tasks and create timeline rows
    local tasks = ViewSystem.getFilteredTasks()
    for _, task in ipairs(tasks) do
        ViewSystem.createTimelineRow(timelineContent, task)
    end
end

-- Create a task card for list view
function ViewSystem.createTaskCard(parent, task, viewType)
    local cardHeight = viewType == "list" and 80 or 120
    
    local card = UIUtilities.createCard(parent, {
        Name = "TaskCard_" .. task.id,
        Size = UDim2.new(1, 0, 0, cardHeight),
        Hoverable = true,
        HoverColor = UIUtilities.CONSTANTS.COLORS.TERTIARY_BG
    })
    
    -- Priority indicator
    UIUtilities.createPriorityIndicator(card, {
        Priority = task.priority:lower()
    })
    
    -- Main content area
    local contentArea = Instance.new("Frame")
    contentArea.Name = "Content"
    contentArea.Parent = card
    contentArea.Size = UDim2.new(1, -20, 1, 0)
    contentArea.Position = UDim2.new(0, 16, 0, 0)
    contentArea.BackgroundTransparency = 1
    
    -- Task title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Parent = contentArea
    title.Size = UDim2.new(1, -100, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = task.title
    title.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    title.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_LG
    title.Font = UIUtilities.CONSTANTS.FONTS.SUBHEADING
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Status badge
    UIUtilities.createStatusBadge(contentArea, {
        Name = "StatusBadge",
        Size = UDim2.new(0, 80, 0, 20),
        Position = UDim2.new(1, -80, 0, 8),
        Status = task.status:lower(),
        Text = task.status
    })
    
    -- Task description (if list view)
    if viewType == "list" then
        local description = Instance.new("TextLabel")
        description.Name = "Description"
        description.Parent = contentArea
        description.Size = UDim2.new(1, -100, 0, 16)
        description.Position = UDim2.new(0, 0, 0, 32)
        description.BackgroundTransparency = 1
        description.Text = task.description or ""
        description.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
        description.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
        description.Font = UIUtilities.CONSTANTS.FONTS.BODY
        description.TextXAlignment = Enum.TextXAlignment.Left
        description.TextTruncate = Enum.TextTruncate.AtEnd
    end
    
    -- Bottom row with assignee and due date
    local bottomRow = Instance.new("Frame")
    bottomRow.Name = "BottomRow"
    bottomRow.Parent = contentArea
    bottomRow.Size = UDim2.new(1, 0, 0, 24)
    bottomRow.Position = UDim2.new(0, 0, 1, -32)
    bottomRow.BackgroundTransparency = 1
    
    -- Assignee avatar
    if task.assignedTo then
        UIUtilities.createAvatar(bottomRow, {
            Name = "AssigneeAvatar",
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(0, 0, 0, 0),
            UserId = task.assignedTo
        })
    end
    
    -- Due date
    if task.dueDate then
        local dueDateLabel = Instance.new("TextLabel")
        dueDateLabel.Name = "DueDate"
        dueDateLabel.Parent = bottomRow
        dueDateLabel.Size = UDim2.new(0, 100, 0, 24)
        dueDateLabel.Position = UDim2.new(1, -100, 0, 0)
        dueDateLabel.BackgroundTransparency = 1
        dueDateLabel.Text = "📅 " .. os.date("%m/%d", task.dueDate)
        dueDateLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
        dueDateLabel.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
        dueDateLabel.Font = UIUtilities.CONSTANTS.FONTS.BODY
        dueDateLabel.TextXAlignment = Enum.TextXAlignment.Right
    end
    
    return card
end

-- Create board column
function ViewSystem.createBoardColumn(parent, column, tasks)
    local columnCard = UIUtilities.createCard(parent, {
        Name = "Column_" .. column.id,
        Size = UDim2.new(0.24, 0, 1, 0),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.TERTIARY_BG
    })
    
    -- Column header
    local header = UIUtilities.createCard(columnCard, {
        Name = "ColumnHeader",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = column.color,
        Shadow = false
    })
    
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Parent = header
    headerLabel.Size = UDim2.new(1, 0, 1, 0)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Text = column.title
    headerLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    headerLabel.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_MD
    headerLabel.Font = UIUtilities.CONSTANTS.FONTS.SUBHEADING
    headerLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Column content
    local scrollFrame = UIUtilities.createScrollFrame(columnCard, {
        Name = "ColumnScroll",
        Size = UDim2.new(1, 0, 1, -50),
        Position = UDim2.new(0, 0, 0, 50),
        AutomaticCanvasSize = Enum.AutomaticSize.Y
    })
    
    local taskContainer = Instance.new("Frame")
    taskContainer.Name = "TaskContainer"
    taskContainer.Parent = scrollFrame
    taskContainer.Size = UDim2.new(1, 0, 1, 0)
    taskContainer.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(taskContainer, {
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_SM
    })
    
    -- Add tasks to column
    for _, task in ipairs(tasks) do
        if task.status == column.id then
            ViewSystem.createTaskCard(taskContainer, task, "board")
        end
    end
end

-- Create calendar day
function ViewSystem.createCalendarDay(parent, day, currentDate)
    local dayCard = UIUtilities.createCard(parent, {
        Name = "CalendarDay_" .. day,
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SURFACE,
        Hoverable = true
    })
    
    local dayLabel = Instance.new("TextLabel")
    dayLabel.Parent = dayCard
    dayLabel.Size = UDim2.new(1, 0, 0, 20)
    dayLabel.Position = UDim2.new(0, 0, 0, 4)
    dayLabel.BackgroundTransparency = 1
    dayLabel.Text = tostring(day)
    dayLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    dayLabel.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
    dayLabel.Font = UIUtilities.CONSTANTS.FONTS.BODY
    dayLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Add task indicators (simplified)
    local taskIndicator = Instance.new("Frame")
    taskIndicator.Name = "TaskIndicator"
    taskIndicator.Parent = dayCard
    taskIndicator.Size = UDim2.new(0, 4, 0, 4)
    taskIndicator.Position = UDim2.new(0.5, -2, 1, -8)
    taskIndicator.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
    taskIndicator.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = taskIndicator
    
    return dayCard
end

-- Create timeline row
function ViewSystem.createTimelineRow(parent, task)
    local row = UIUtilities.createCard(parent, {
        Name = "TimelineRow_" .. task.id,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SURFACE
    })
    
    -- Task info section
    local taskInfo = Instance.new("Frame")
    taskInfo.Name = "TaskInfo"
    taskInfo.Parent = row
    taskInfo.Size = UDim2.new(0, 180, 1, 0)
    taskInfo.Position = UDim2.new(0, 0, 0, 0)
    taskInfo.BackgroundTransparency = 1
    
    local taskTitle = Instance.new("TextLabel")
    taskTitle.Parent = taskInfo
    taskTitle.Size = UDim2.new(1, -8, 0, 20)
    taskTitle.Position = UDim2.new(0, 8, 0, 8)
    taskTitle.BackgroundTransparency = 1
    taskTitle.Text = task.title
    taskTitle.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    taskTitle.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_MD
    taskTitle.Font = UIUtilities.CONSTANTS.FONTS.BODY
    taskTitle.TextXAlignment = Enum.TextXAlignment.Left
    taskTitle.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Timeline bar section
    local timelineBar = Instance.new("Frame")
    timelineBar.Name = "TimelineBar"
    timelineBar.Parent = row
    timelineBar.Size = UDim2.new(1, -200, 0, 20)
    timelineBar.Position = UDim2.new(0, 200, 0.5, -10)
    timelineBar.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
    timelineBar.BorderSizePixel = 0
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 10)
    barCorner.Parent = timelineBar
    
    return row
end

-- Get filtered tasks based on current filters
function ViewSystem.getFilteredTasks()
    if not TaskManager then return {} end
    
    local allTasks = TaskManager.getTasks and TaskManager.getTasks() or {}
    local filteredTasks = {}
    
    for _, task in ipairs(allTasks) do
        local include = true
        
        -- Search filter
        if filters.search and filters.search ~= "" then
            local searchLower = filters.search:lower()
            if not (task.title:lower():find(searchLower) or 
                   (task.description and task.description:lower():find(searchLower))) then
                include = false
            end
        end
        
        -- Status filter
        if filters.status and task.status ~= filters.status then
            include = false
        end
        
        -- Priority filter
        if filters.priority and task.priority ~= filters.priority then
            include = false
        end
        
        -- Assignee filter
        if filters.assignee and task.assignedTo ~= filters.assignee then
            include = false
        end
        
        if include then
            table.insert(filteredTasks, task)
        end
    end
    
    return filteredTasks
end

-- Refresh current view
function ViewSystem.refreshCurrentView()
    ViewSystem.renderCurrentView()
end

-- Show new task dialog (placeholder)
function ViewSystem.showNewTaskDialog()
    print("[TCE] New task dialog (to be implemented)")
    -- This will be implemented with the task details panel
end

-- Set filter
function ViewSystem.setFilter(filterType, value)
    filters[filterType] = value
    ViewSystem.refreshCurrentView()
end

-- Get current view
function ViewSystem.getCurrentView()
    return currentView
end

return ViewSystem 