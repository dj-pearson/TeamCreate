-- src/shared/modules/UIManager/ModernTaskCard.lua
-- Modern task card component with ClickUp-inspired design

local ModernTaskCard = {}

-- Services
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Module references (will be injected)
local UIUtilities = nil
local PermissionManager = nil

-- Card state management
local cardInstances = {}
local selectedCards = {}

-- Initialize the module
function ModernTaskCard.initialize(refs)
    UIUtilities = refs.UIUtilities
    PermissionManager = refs.PermissionManager
    print("[TCE] ModernTaskCard initialized")
end

-- Create a modern task card
function ModernTaskCard.createCard(parent, task, options)
    options = options or {}
    
    local cardId = "TaskCard_" .. task.id
    local cardHeight = options.height or (options.viewType == "board" and 140 or 100)
    local isCompact = options.viewType == "timeline"
    
    -- Main card container
    local card = UIUtilities.createCard(parent, {
        Name = cardId,
        Size = UDim2.new(1, 0, 0, cardHeight),
        BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SECONDARY_BG,
        Hoverable = true,
        HoverColor = UIUtilities.CONSTANTS.COLORS.TERTIARY_BG,
        CornerRadius = UIUtilities.CONSTANTS.SIZES.RADIUS_LG,
        PaddingTop = UIUtilities.CONSTANTS.SIZES.PADDING_MD,
        PaddingBottom = UIUtilities.CONSTANTS.SIZES.PADDING_MD,
        PaddingLeft = UIUtilities.CONSTANTS.SIZES.PADDING_MD,
        PaddingRight = UIUtilities.CONSTANTS.SIZES.PADDING_MD
    })
    
    -- Store card instance
    cardInstances[cardId] = {
        card = card,
        task = task,
        options = options
    }
    
    -- Priority indicator (left border)
    ModernTaskCard.createPriorityIndicator(card, task.priority)
    
    -- Main content layout
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "Content"
    contentFrame.Parent = card
    contentFrame.Size = UDim2.new(1, -8, 1, 0)
    contentFrame.Position = UDim2.new(0, 6, 0, 0)
    contentFrame.BackgroundTransparency = 1
    
    -- Header row (title, status, options menu)
    ModernTaskCard.createHeaderRow(contentFrame, task, options)
    
    -- Description row (if not compact)
    if not isCompact and task.description then
        ModernTaskCard.createDescriptionRow(contentFrame, task, options)
    end
    
    -- Metadata row (assignee, due date, tags)
    ModernTaskCard.createMetadataRow(contentFrame, task, options)
    
    -- Progress bar (if task has progress)
    if task.progress and task.progress > 0 then
        ModernTaskCard.createProgressBar(contentFrame, task, options)
    end
    
    -- Interactive elements
    ModernTaskCard.setupInteractivity(card, task, options)
    
    return card
end

-- Create priority indicator
function ModernTaskCard.createPriorityIndicator(parent, priority)
    local priorityColors = {
        Critical = UIUtilities.CONSTANTS.COLORS.PRIORITY_CRITICAL,
        High = UIUtilities.CONSTANTS.COLORS.PRIORITY_HIGH,
        Medium = UIUtilities.CONSTANTS.COLORS.PRIORITY_MEDIUM,
        Low = UIUtilities.CONSTANTS.COLORS.PRIORITY_LOW
    }
    
    local indicator = Instance.new("Frame")
    indicator.Name = "PriorityIndicator"
    indicator.Parent = parent
    indicator.Size = UDim2.new(0, 4, 1, 0)
    indicator.Position = UDim2.new(0, 0, 0, 0)
    indicator.BackgroundColor3 = priorityColors[priority] or priorityColors.Medium
    indicator.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 2)
    corner.Parent = indicator
    
    return indicator
end

-- Create header row with title and status
function ModernTaskCard.createHeaderRow(parent, task, options)
    local headerRow = Instance.new("Frame")
    headerRow.Name = "HeaderRow"
    headerRow.Parent = parent
    headerRow.Size = UDim2.new(1, 0, 0, 24)
    headerRow.Position = UDim2.new(0, 0, 0, 0)
    headerRow.BackgroundTransparency = 1
    
    -- Task title
    local title = Instance.new("TextLabel")
    title.Name = "TaskTitle"
    title.Parent = headerRow
    title.Size = UDim2.new(1, -90, 1, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = task.title
    title.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    title.TextSize = options.viewType == "board" and UIUtilities.CONSTANTS.SIZES.TEXT_LG or UIUtilities.CONSTANTS.SIZES.TEXT_MD
    title.Font = UIUtilities.CONSTANTS.FONTS.SUBHEADING
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Status badge
    local statusBadge = ModernTaskCard.createStatusBadge(headerRow, task.status, {
        Size = UDim2.new(0, 80, 0, 20),
        Position = UDim2.new(1, -80, 0, 2)
    })
    
    -- Task ID (small, subtle)
    local taskId = Instance.new("TextLabel")
    taskId.Name = "TaskId"
    taskId.Parent = headerRow
    taskId.Size = UDim2.new(0, 40, 0, 12)
    taskId.Position = UDim2.new(1, -40, 1, -12)
    taskId.BackgroundTransparency = 1
    taskId.Text = "#" .. tostring(task.id):sub(-4) -- Last 4 characters
    taskId.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_DISABLED
    taskId.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XS
    taskId.Font = UIUtilities.CONSTANTS.FONTS.MONO
    taskId.TextXAlignment = Enum.TextXAlignment.Right
    
    return headerRow
end

-- Create description row
function ModernTaskCard.createDescriptionRow(parent, task, options)
    local descRow = Instance.new("Frame")
    descRow.Name = "DescriptionRow"
    descRow.Parent = parent
    descRow.Size = UDim2.new(1, 0, 0, 32)
    descRow.Position = UDim2.new(0, 0, 0, 28)
    descRow.BackgroundTransparency = 1
    
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Parent = descRow
    description.Size = UDim2.new(1, 0, 1, 0)
    description.Position = UDim2.new(0, 0, 0, 0)
    description.BackgroundTransparency = 1
    description.Text = task.description or ""
    description.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    description.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_SM
    description.Font = UIUtilities.CONSTANTS.FONTS.BODY
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.TextWrapped = true
    description.TextTruncate = Enum.TextTruncate.AtEnd
    
    return descRow
end

-- Create metadata row with assignee, due date, tags
function ModernTaskCard.createMetadataRow(parent, task, options)
    local metaRow = Instance.new("Frame")
    metaRow.Name = "MetadataRow"
    metaRow.Parent = parent
    metaRow.Size = UDim2.new(1, 0, 0, 28)
    metaRow.Position = UDim2.new(0, 0, 1, -32)
    metaRow.BackgroundTransparency = 1
    
    local leftSection = Instance.new("Frame")
    leftSection.Name = "LeftSection"
    leftSection.Parent = metaRow
    leftSection.Size = UDim2.new(0.6, 0, 1, 0)
    leftSection.Position = UDim2.new(0, 0, 0, 0)
    leftSection.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(leftSection, {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_XS
    })
    
    -- Assignee avatar
    if task.assignedTo then
        local avatar = UIUtilities.createAvatar(leftSection, {
            Name = "AssigneeAvatar",
            Size = UDim2.new(0, 24, 0, 24),
            UserId = task.assignedTo
        })
    end
    
    -- Task type icon
    local typeIcon = Instance.new("TextLabel")
    typeIcon.Name = "TypeIcon"
    typeIcon.Parent = leftSection
    typeIcon.Size = UDim2.new(0, 20, 0, 20)
    typeIcon.BackgroundTransparency = 1
    typeIcon.Text = ModernTaskCard.getTaskTypeIcon(task.taskType)
    typeIcon.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    typeIcon.TextSize = 14
    typeIcon.Font = UIUtilities.CONSTANTS.FONTS.BODY
    typeIcon.TextXAlignment = Enum.TextXAlignment.Center
    typeIcon.TextYAlignment = Enum.TextYAlignment.Center
    
    -- Tags (if any)
    if task.tags and #task.tags > 0 then
        for i, tag in ipairs(task.tags) do
            if i <= 2 then -- Limit to 2 tags for space
                local tagChip = ModernTaskCard.createTagChip(leftSection, tag)
            end
        end
    end
    
    -- Right section (due date, comments, attachments)
    local rightSection = Instance.new("Frame")
    rightSection.Name = "RightSection"
    rightSection.Parent = metaRow
    rightSection.Size = UDim2.new(0.4, 0, 1, 0)
    rightSection.Position = UDim2.new(0.6, 0, 0, 0)
    rightSection.BackgroundTransparency = 1
    
    UIUtilities.applyListLayout(rightSection, {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UIUtilities.CONSTANTS.SIZES.PADDING_XS
    })
    
    -- Comment count
    if task.comments and #task.comments > 0 then
        local commentCount = ModernTaskCard.createMetaIcon(rightSection, "💬", tostring(#task.comments))
    end
    
    -- Attachment count
    if task.attachments and #task.attachments > 0 then
        local attachmentCount = ModernTaskCard.createMetaIcon(rightSection, "📎", tostring(#task.attachments))
    end
    
    -- Due date
    if task.dueDate then
        local isOverdue = task.dueDate < os.time()
        local dueDateIcon = ModernTaskCard.createDueDateIndicator(rightSection, task.dueDate, isOverdue)
    end
    
    return metaRow
end

-- Create status badge
function ModernTaskCard.createStatusBadge(parent, status, props)
    props = props or {}
    
    local statusColors = {
        Todo = UIUtilities.CONSTANTS.COLORS.STATUS_TODO,
        InProgress = UIUtilities.CONSTANTS.COLORS.STATUS_PROGRESS,
        Review = UIUtilities.CONSTANTS.COLORS.STATUS_REVIEW,
        Completed = UIUtilities.CONSTANTS.COLORS.STATUS_COMPLETED,
        Cancelled = UIUtilities.CONSTANTS.COLORS.STATUS_CANCELLED
    }
    
    local badge = Instance.new("Frame")
    badge.Name = "StatusBadge"
    badge.Parent = parent
    badge.Size = props.Size or UDim2.new(0, 70, 0, 18)
    badge.Position = props.Position or UDim2.new(0, 0, 0, 0)
    badge.BackgroundColor3 = statusColors[status] or statusColors.Todo
    badge.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = badge
    
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Parent = badge
    statusText.Size = UDim2.new(1, 0, 1, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = status:upper()
    statusText.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    statusText.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XS
    statusText.Font = UIUtilities.CONSTANTS.FONTS.CAPTION
    statusText.TextXAlignment = Enum.TextXAlignment.Center
    statusText.TextYAlignment = Enum.TextYAlignment.Center
    
    return badge
end

-- Create tag chip
function ModernTaskCard.createTagChip(parent, tagText)
    local chip = Instance.new("Frame")
    chip.Name = "TagChip_" .. tagText
    chip.Parent = parent
    chip.Size = UDim2.new(0, math.min(60, #tagText * 8 + 16), 0, 16)
    chip.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SURFACE
    chip.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = chip
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = UIUtilities.CONSTANTS.COLORS.BORDER_LIGHT
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = chip
    
    local text = Instance.new("TextLabel")
    text.Name = "TagText"
    text.Parent = chip
    text.Size = UDim2.new(1, -8, 1, 0)
    text.Position = UDim2.new(0, 4, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = tagText
    text.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    text.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XS
    text.Font = UIUtilities.CONSTANTS.FONTS.CAPTION
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.TextYAlignment = Enum.TextYAlignment.Center
    text.TextTruncate = Enum.TextTruncate.AtEnd
    
    return chip
end

-- Create metadata icon with count
function ModernTaskCard.createMetaIcon(parent, icon, count)
    local container = Instance.new("Frame")
    container.Name = "MetaIcon_" .. icon
    container.Parent = parent
    container.Size = UDim2.new(0, 24, 0, 16)
    container.BackgroundTransparency = 1
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Parent = container
    iconLabel.Size = UDim2.new(0, 12, 1, 0)
    iconLabel.Position = UDim2.new(0, 0, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 10
    iconLabel.Font = UIUtilities.CONSTANTS.FONTS.BODY
    
    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "Count"
    countLabel.Parent = container
    countLabel.Size = UDim2.new(0, 12, 1, 0)
    countLabel.Position = UDim2.new(0, 12, 0, 0)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = count
    countLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    countLabel.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XS
    countLabel.Font = UIUtilities.CONSTANTS.FONTS.CAPTION
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    return container
end

-- Create due date indicator
function ModernTaskCard.createDueDateIndicator(parent, dueDate, isOverdue)
    local indicator = Instance.new("Frame")
    indicator.Name = "DueDateIndicator"
    indicator.Parent = parent
    indicator.Size = UDim2.new(0, 60, 0, 16)
    indicator.BackgroundTransparency = 1
    
    local dateText = Instance.new("TextLabel")
    dateText.Name = "DateText"
    dateText.Parent = indicator
    dateText.Size = UDim2.new(1, 0, 1, 0)
    dateText.BackgroundTransparency = 1
    dateText.Text = "📅 " .. os.date("%m/%d", dueDate)
    dateText.TextColor3 = isOverdue and UIUtilities.CONSTANTS.COLORS.ERROR or UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    dateText.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XS
    dateText.Font = UIUtilities.CONSTANTS.FONTS.CAPTION
    dateText.TextXAlignment = Enum.TextXAlignment.Right
    
    -- Add overdue highlighting
    if isOverdue then
        indicator.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.ERROR
        indicator.BackgroundTransparency = 0.9
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = indicator
    end
    
    return indicator
end

-- Create progress bar
function ModernTaskCard.createProgressBar(parent, task, options)
    local progressContainer = Instance.new("Frame")
    progressContainer.Name = "ProgressContainer"
    progressContainer.Parent = parent
    progressContainer.Size = UDim2.new(1, 0, 0, 8)
    progressContainer.Position = UDim2.new(0, 0, 1, -8)
    progressContainer.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SURFACE
    progressContainer.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = progressContainer
    
    local progressBar = Instance.new("Frame")
    progressBar.Name = "ProgressBar"
    progressBar.Parent = progressContainer
    progressBar.Size = UDim2.new(task.progress / 100, 0, 1, 0)
    progressBar.Position = UDim2.new(0, 0, 0, 0)
    progressBar.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SUCCESS
    progressBar.BorderSizePixel = 0
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 4)
    progressCorner.Parent = progressBar
    
    return progressContainer
end

-- Get task type icon
function ModernTaskCard.getTaskTypeIcon(taskType)
    local icons = {
        Script = "💻",
        Build = "🏗️",
        Asset = "🎨",
        Design = "🎨",
        Test = "🧪",
        Bug = "🐛",
        Feature = "✨"
    }
    return icons[taskType] or "📝"
end

-- Setup card interactivity
function ModernTaskCard.setupInteractivity(card, task, options)
    local cardInstance = cardInstances["TaskCard_" .. task.id]
    if not cardInstance then return end
    
    -- Click to select/open
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            ModernTaskCard.selectCard(card, task)
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            ModernTaskCard.showContextMenu(card, task)
        end
    end)
    
    -- Double-click to open details
    local lastClickTime = 0
    card.MouseButton1Click:Connect(function()
        local currentTime = tick()
        if currentTime - lastClickTime < 0.5 then
            ModernTaskCard.openTaskDetails(task)
        end
        lastClickTime = currentTime
    end)
    
    -- Drag and drop (for board view)
    if options.viewType == "board" then
        ModernTaskCard.setupDragAndDrop(card, task)
    end
end

-- Select card
function ModernTaskCard.selectCard(card, task)
    local cardId = "TaskCard_" .. task.id
    
    -- Deselect other cards
    for id, instance in pairs(cardInstances) do
        if id ~= cardId then
            ModernTaskCard.deselectCard(instance.card)
        end
    end
    
    -- Select this card
    selectedCards[cardId] = true
    
    -- Visual feedback
    local stroke = card:FindFirstChild("UIStroke")
    if not stroke then
        stroke = Instance.new("UIStroke")
        stroke.Parent = card
    end
    
    stroke.Color = UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
    stroke.Thickness = 2
    stroke.Transparency = 0
    
    print("[TCE] Selected task:", task.title)
end

-- Deselect card
function ModernTaskCard.deselectCard(card)
    selectedCards["TaskCard_" .. (card.Name:match("TaskCard_(.+)") or "")] = nil
    
    local stroke = card:FindFirstChild("UIStroke")
    if stroke and stroke.Color == UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY then
        stroke.Transparency = 0.3
        stroke.Color = UIUtilities.CONSTANTS.COLORS.BORDER_LIGHT
    end
end

-- Open task details (placeholder)
function ModernTaskCard.openTaskDetails(task)
    print("[TCE] Opening task details for:", task.title)
    -- This will be implemented with the task details panel
end

-- Show context menu (placeholder)
function ModernTaskCard.showContextMenu(card, task)
    print("[TCE] Context menu for task:", task.title)
    -- Context menu with edit, delete, assign, etc.
end

-- Setup drag and drop for board view
function ModernTaskCard.setupDragAndDrop(card, task)
    -- Simplified drag and drop - will be enhanced later
    local isDragging = false
    local dragStart = nil
    
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isDragging = true
            dragStart = input.Position
            
            -- Create drag preview
            local preview = card:Clone()
            preview.Parent = card.Parent.Parent -- Move to higher level
            preview.ZIndex = 10
            preview.Transparency = 0.5
            
            -- Follow mouse
            local connection
            connection = game:GetService("UserInputService").InputChanged:Connect(function(input2)
                if input2.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
                    local delta = input2.Position - dragStart
                    preview.Position = card.Position + UDim2.new(0, delta.X, 0, delta.Y)
                end
            end)
            
            -- End drag
            local endConnection
            endConnection = game:GetService("UserInputService").InputEnded:Connect(function(input2)
                if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                    isDragging = false
                    connection:Disconnect()
                    endConnection:Disconnect()
                    preview:Destroy()
                end
            end)
        end
    end)
end

-- Update card data
function ModernTaskCard.updateCard(taskId, newData)
    local cardInstance = cardInstances["TaskCard_" .. taskId]
    if not cardInstance then return end
    
    -- Update task data
    for key, value in pairs(newData) do
        cardInstance.task[key] = value
    end
    
    -- Refresh card display
    ModernTaskCard.refreshCard(cardInstance.card, cardInstance.task, cardInstance.options)
end

-- Refresh card display
function ModernTaskCard.refreshCard(card, task, options)
    -- This is a simplified refresh - in a real implementation,
    -- we would update specific elements rather than recreating
    print("[TCE] Refreshing card for task:", task.title)
end

-- Get selected cards
function ModernTaskCard.getSelectedCards()
    local selected = {}
    for cardId, _ in pairs(selectedCards) do
        local taskId = cardId:match("TaskCard_(.+)")
        if taskId and cardInstances[cardId] then
            table.insert(selected, cardInstances[cardId].task)
        end
    end
    return selected
end

-- Cleanup
function ModernTaskCard.cleanup()
    cardInstances = {}
    selectedCards = {}
    print("[TCE] ModernTaskCard cleaned up")
end

return ModernTaskCard 