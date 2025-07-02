-- src/shared/modules/UIManager/UIUtilities.lua
-- Modern UI creation utilities with ClickUp-inspired design system

local UIUtilities = {}

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Modern Design System Constants (ClickUp-inspired)
UIUtilities.CONSTANTS = {
    COLORS = {
        -- Background Colors
        PRIMARY_BG = Color3.fromHex("#1a1a1a"),     -- Dark main background
        SECONDARY_BG = Color3.fromHex("#262626"),   -- Card/panel background
        TERTIARY_BG = Color3.fromHex("#333333"),    -- Hover states
        SURFACE = Color3.fromHex("#404040"),        -- Input backgrounds
        
        -- Brand Colors
        BRAND_PRIMARY = Color3.fromHex("#7b68ee"),  -- Purple accent
        BRAND_SECONDARY = Color3.fromHex("#4f46e5"), -- Blue accent
        
        -- Status Colors
        SUCCESS = Color3.fromHex("#10b981"),        -- Green
        WARNING = Color3.fromHex("#f59e0b"),        -- Orange
        ERROR = Color3.fromHex("#ef4444"),          -- Red
        INFO = Color3.fromHex("#3b82f6"),           -- Blue
        
        -- Priority Colors
        PRIORITY_CRITICAL = Color3.fromHex("#dc2626"), -- Dark red
        PRIORITY_HIGH = Color3.fromHex("#ea580c"),      -- Orange-red
        PRIORITY_MEDIUM = Color3.fromHex("#d97706"),    -- Orange
        PRIORITY_LOW = Color3.fromHex("#059669"),       -- Green
        
        -- Task Status Colors
        STATUS_TODO = Color3.fromHex("#6b7280"),        -- Gray
        STATUS_PROGRESS = Color3.fromHex("#3b82f6"),    -- Blue
        STATUS_REVIEW = Color3.fromHex("#f59e0b"),       -- Orange
        STATUS_COMPLETED = Color3.fromHex("#10b981"),   -- Green
        STATUS_CANCELLED = Color3.fromHex("#ef4444"),   -- Red
        
        -- Text Colors
        TEXT_PRIMARY = Color3.fromHex("#ffffff"),       -- White
        TEXT_SECONDARY = Color3.fromHex("#d1d5db"),     -- Light gray
        TEXT_MUTED = Color3.fromHex("#9ca3af"),         -- Medium gray
        TEXT_DISABLED = Color3.fromHex("#6b7280"),      -- Dark gray
        
        -- Border Colors
        BORDER_LIGHT = Color3.fromHex("#374151"),       -- Light border
        BORDER_MEDIUM = Color3.fromHex("#4b5563"),      -- Medium border
        BORDER_FOCUS = Color3.fromHex("#7b68ee"),       -- Focus border
        
        -- Hover and Active States
        HOVER_OVERLAY = Color3.fromHex("#ffffff"),      -- White overlay for hover
        ACTIVE_OVERLAY = Color3.fromHex("#7b68ee"),     -- Brand overlay for active
    },
    
    FONTS = {
        HEADING = Enum.Font.GothamBold,
        SUBHEADING = Enum.Font.GothamMedium,
        BODY = Enum.Font.Gotham,
        CAPTION = Enum.Font.Gotham,
        MONO = Enum.Font.RobotoMono
    },
    
    SIZES = {
        -- Border Radius
        RADIUS_SM = 4,
        RADIUS_MD = 6,
        RADIUS_LG = 8,
        RADIUS_XL = 12,
        RADIUS_FULL = 50,
        
        -- Spacing
        PADDING_XS = 4,
        PADDING_SM = 8,
        PADDING_MD = 12,
        PADDING_LG = 16,
        PADDING_XL = 24,
        PADDING_2XL = 32,
        
        -- Component Heights
        BUTTON_SM = 28,
        BUTTON_MD = 36,
        BUTTON_LG = 44,
        INPUT_HEIGHT = 36,
        TAB_HEIGHT = 48,
        NAVBAR_HEIGHT = 64,
        SIDEBAR_WIDTH = 280,
        
        -- Typography
        TEXT_XS = 10,
        TEXT_SM = 12,
        TEXT_MD = 14,
        TEXT_LG = 16,
        TEXT_XL = 18,
        TEXT_2XL = 24,
        TEXT_3XL = 30,
        
        -- Shadows and Effects
        SHADOW_SM = 2,
        SHADOW_MD = 4,
        SHADOW_LG = 8,
        GLOW_SIZE = 3,
    },
    
    ANIMATIONS = {
        DURATION_FAST = 0.15,
        DURATION_NORMAL = 0.25,
        DURATION_SLOW = 0.35,
        EASING_STANDARD = Enum.EasingStyle.Quad,
        EASING_SMOOTH = Enum.EasingStyle.Sine,
        EASING_BOUNCE = Enum.EasingStyle.Back,
    }
}

-- Modern Card Component
function UIUtilities.createCard(parent, props)
    props = props or {}
    
    local card = Instance.new("Frame")
    card.Name = props.Name or "Card"
    card.Parent = parent
    card.BackgroundColor3 = props.BackgroundColor3 or UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    card.BorderSizePixel = 0
    card.Size = props.Size or UDim2.new(1, 0, 0, 100)
    card.Position = props.Position or UDim2.new(0, 0, 0, 0)
    
    -- Modern rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, props.CornerRadius or UIUtilities.CONSTANTS.SIZES.RADIUS_MD)
    corner.Parent = card
    
    -- Subtle border
    local stroke = Instance.new("UIStroke")
    stroke.Color = props.BorderColor or UIUtilities.CONSTANTS.COLORS.BORDER_LIGHT
    stroke.Thickness = props.BorderThickness or 1
    stroke.Transparency = props.BorderTransparency or 0.3
    stroke.Parent = card
    
    -- Shadow effect
    if props.Shadow ~= false then
        local shadow = Instance.new("Frame")
        shadow.Name = "Shadow"
        shadow.Parent = card
        shadow.BackgroundColor3 = Color3.fromHex("#000000")
        shadow.BackgroundTransparency = 0.8
        shadow.BorderSizePixel = 0
        shadow.Size = UDim2.new(1, 4, 1, 4)
        shadow.Position = UDim2.new(0, 2, 0, 2)
        shadow.ZIndex = card.ZIndex - 1
        
        local shadowCorner = Instance.new("UICorner")
        shadowCorner.CornerRadius = corner.CornerRadius
        shadowCorner.Parent = shadow
    end
    
    -- Padding
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, props.PaddingTop or UIUtilities.CONSTANTS.SIZES.PADDING_MD)
    padding.PaddingBottom = UDim.new(0, props.PaddingBottom or UIUtilities.CONSTANTS.SIZES.PADDING_MD)
    padding.PaddingLeft = UDim.new(0, props.PaddingLeft or UIUtilities.CONSTANTS.SIZES.PADDING_MD)
    padding.PaddingRight = UDim.new(0, props.PaddingRight or UIUtilities.CONSTANTS.SIZES.PADDING_MD)
    padding.Parent = card
    
    -- Hover effect
    if props.Hoverable ~= false then
        local originalColor = card.BackgroundColor3
        local hoverColor = props.HoverColor or UIUtilities.CONSTANTS.COLORS.TERTIARY_BG
        
        local connection1, connection2
        connection1 = card.MouseEnter:Connect(function()
            if connection1 then
                TweenService:Create(card, TweenInfo.new(UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST), {
                    BackgroundColor3 = hoverColor
                }):Play()
            end
        end)
        
        connection2 = card.MouseLeave:Connect(function()
            if connection2 then
                TweenService:Create(card, TweenInfo.new(UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST), {
                    BackgroundColor3 = originalColor
                }):Play()
            end
        end)
    end
    
    return card
end

-- Modern Button Component
function UIUtilities.createButton(parent, props)
    props = props or {}
    
    local button = Instance.new("TextButton")
    button.Name = props.Name or "Button"
    button.Parent = parent
    button.Size = props.Size or UDim2.new(0, 120, 0, UIUtilities.CONSTANTS.SIZES.BUTTON_MD)
    button.Position = props.Position or UDim2.new(0, 0, 0, 0)
    button.BackgroundColor3 = props.BackgroundColor3 or UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
    button.BorderSizePixel = 0
    button.Text = props.Text or "Button"
    button.TextColor3 = props.TextColor3 or UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    button.TextSize = props.TextSize or UIUtilities.CONSTANTS.SIZES.TEXT_MD
    button.Font = props.Font or UIUtilities.CONSTANTS.FONTS.BODY
    button.AutoButtonColor = false
    
    -- Button variants
    local variant = props.Variant or "primary"
    if variant == "secondary" then
        button.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SURFACE
        button.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    elseif variant == "outline" then
        button.BackgroundTransparency = 1
        button.TextColor3 = UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
        stroke.Thickness = 1
        stroke.Parent = button
    elseif variant == "ghost" then
        button.BackgroundTransparency = 1
        button.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_SECONDARY
    end
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, props.CornerRadius or UIUtilities.CONSTANTS.SIZES.RADIUS_MD)
    corner.Parent = button
    
    -- Icon support
    if props.Icon then
        local icon = Instance.new("TextLabel")
        icon.Name = "Icon"
        icon.Parent = button
        icon.Size = UDim2.new(0, 16, 0, 16)
        icon.Position = UDim2.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_SM, 0.5, -8)
        icon.BackgroundTransparency = 1
        icon.Text = props.Icon
        icon.TextColor3 = button.TextColor3
        icon.TextSize = 16
        icon.Font = UIUtilities.CONSTANTS.FONTS.BODY
        
        -- Adjust button text position
        button.TextXAlignment = Enum.TextXAlignment.Left
        local textPadding = Instance.new("UIPadding")
        textPadding.PaddingLeft = UDim.new(0, 28)
        textPadding.Parent = button
    end
    
    -- Button states and animations
    local originalColor = button.BackgroundColor3
    local originalTextColor = button.TextColor3
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        local hoverColor = originalColor:lerp(UIUtilities.CONSTANTS.COLORS.HOVER_OVERLAY, 0.1)
        TweenService:Create(button, TweenInfo.new(UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST), {
            BackgroundColor3 = hoverColor
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST), {
            BackgroundColor3 = originalColor
        }):Play()
    end)
    
    -- Press effect
    button.MouseButton1Down:Connect(function()
        TweenService:Create(button, TweenInfo.new(UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST), {
            Size = button.Size - UDim2.new(0, 2, 0, 2)
        }):Play()
    end)
    
    button.MouseButton1Up:Connect(function()
        TweenService:Create(button, TweenInfo.new(UIUtilities.CONSTANTS.ANIMATIONS.DURATION_FAST), {
            Size = props.Size or UDim2.new(0, 120, 0, UIUtilities.CONSTANTS.SIZES.BUTTON_MD)
        }):Play()
    end)
    
    return button
end

-- Status Badge Component
function UIUtilities.createStatusBadge(parent, props)
    props = props or {}
    
    local badge = Instance.new("Frame")
    badge.Name = props.Name or "StatusBadge"
    badge.Parent = parent
    badge.Size = props.Size or UDim2.new(0, 80, 0, 24)
    badge.Position = props.Position or UDim2.new(0, 0, 0, 0)
    badge.BorderSizePixel = 0
    
    -- Status-based colors
    local status = props.Status or "default"
    local statusColors = {
        todo = UIUtilities.CONSTANTS.COLORS.STATUS_TODO,
        progress = UIUtilities.CONSTANTS.COLORS.STATUS_PROGRESS,
        review = UIUtilities.CONSTANTS.COLORS.STATUS_REVIEW,
        completed = UIUtilities.CONSTANTS.COLORS.STATUS_COMPLETED,
        cancelled = UIUtilities.CONSTANTS.COLORS.STATUS_CANCELLED,
        critical = UIUtilities.CONSTANTS.COLORS.PRIORITY_CRITICAL,
        high = UIUtilities.CONSTANTS.COLORS.PRIORITY_HIGH,
        medium = UIUtilities.CONSTANTS.COLORS.PRIORITY_MEDIUM,
        low = UIUtilities.CONSTANTS.COLORS.PRIORITY_LOW,
        default = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    }
    
    badge.BackgroundColor3 = statusColors[status:lower()] or statusColors.default
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UIUtilities.CONSTANTS.SIZES.RADIUS_FULL)
    corner.Parent = badge
    
    -- Status text
    local text = Instance.new("TextLabel")
    text.Name = "StatusText"
    text.Parent = badge
    text.Size = UDim2.new(1, 0, 1, 0)
    text.Position = UDim2.new(0, 0, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = props.Text or status:upper()
    text.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    text.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_XS
    text.Font = UIUtilities.CONSTANTS.FONTS.CAPTION
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.TextYAlignment = Enum.TextYAlignment.Center
    
    return badge
end

-- Priority Indicator Component
function UIUtilities.createPriorityIndicator(parent, props)
    props = props or {}
    
    local indicator = Instance.new("Frame")
    indicator.Name = props.Name or "PriorityIndicator"
    indicator.Parent = parent
    indicator.Size = props.Size or UDim2.new(0, 4, 1, 0)
    indicator.Position = props.Position or UDim2.new(0, 0, 0, 0)
    indicator.BorderSizePixel = 0
    
    -- Priority-based colors
    local priority = props.Priority or "medium"
    local priorityColors = {
        critical = UIUtilities.CONSTANTS.COLORS.PRIORITY_CRITICAL,
        high = UIUtilities.CONSTANTS.COLORS.PRIORITY_HIGH,
        medium = UIUtilities.CONSTANTS.COLORS.PRIORITY_MEDIUM,
        low = UIUtilities.CONSTANTS.COLORS.PRIORITY_LOW
    }
    
    indicator.BackgroundColor3 = priorityColors[priority:lower()] or priorityColors.medium
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UIUtilities.CONSTANTS.SIZES.RADIUS_SM)
    corner.Parent = indicator
    
    return indicator
end

-- Avatar Component
function UIUtilities.createAvatar(parent, props)
    props = props or {}
    
    local avatar = Instance.new("Frame")
    avatar.Name = props.Name or "Avatar"
    avatar.Parent = parent
    avatar.Size = props.Size or UDim2.new(0, 32, 0, 32)
    avatar.Position = props.Position or UDim2.new(0, 0, 0, 0)
    avatar.BackgroundColor3 = props.BackgroundColor3 or UIUtilities.CONSTANTS.COLORS.BRAND_PRIMARY
    avatar.BorderSizePixel = 0
    
    -- Circular shape
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = avatar
    
    -- Avatar content
    if props.UserId then
        -- Try to load user avatar
        local success, avatarUrl = pcall(function()
            return game.Players:GetUserThumbnailAsync(props.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size100x100)
        end)
        
        if success then
            local imageLabel = Instance.new("ImageLabel")
            imageLabel.Name = "AvatarImage"
            imageLabel.Parent = avatar
            imageLabel.Size = UDim2.new(1, 0, 1, 0)
            imageLabel.Position = UDim2.new(0, 0, 0, 0)
            imageLabel.BackgroundTransparency = 1
            imageLabel.Image = avatarUrl
            
            local imageCorner = Instance.new("UICorner")
            imageCorner.CornerRadius = UDim.new(0.5, 0)
            imageCorner.Parent = imageLabel
        end
    elseif props.Initials then
        -- Show initials
        local initialsLabel = Instance.new("TextLabel")
        initialsLabel.Name = "Initials"
        initialsLabel.Parent = avatar
        initialsLabel.Size = UDim2.new(1, 0, 1, 0)
        initialsLabel.Position = UDim2.new(0, 0, 0, 0)
        initialsLabel.BackgroundTransparency = 1
        initialsLabel.Text = props.Initials
        initialsLabel.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
        initialsLabel.TextSize = props.TextSize or 12
        initialsLabel.Font = UIUtilities.CONSTANTS.FONTS.BODY
        initialsLabel.TextXAlignment = Enum.TextXAlignment.Center
        initialsLabel.TextYAlignment = Enum.TextYAlignment.Center
    end
    
    return avatar
end

-- Modern Scrolling Frame
function UIUtilities.createScrollFrame(parent, props)
    props = props or {}
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = props.Name or "ScrollFrame"
    scrollFrame.Parent = parent
    scrollFrame.Size = props.Size or UDim2.new(1, 0, 1, 0)
    scrollFrame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = UIUtilities.CONSTANTS.COLORS.BORDER_MEDIUM
    scrollFrame.CanvasSize = props.CanvasSize or UDim2.new(0, 0, 2, 0)
    scrollFrame.ScrollingDirection = props.ScrollingDirection or Enum.ScrollingDirection.XY
    scrollFrame.ElasticBehavior = Enum.ElasticBehavior.Never
    
    -- Auto-sizing for content
    if props.AutomaticCanvasSize then
        scrollFrame.AutomaticCanvasSize = props.AutomaticCanvasSize
    end
    
    return scrollFrame
end

-- Input Field Component
function UIUtilities.createInput(parent, props)
    props = props or {}
    
    local container = Instance.new("Frame")
    container.Name = props.Name or "InputContainer"
    container.Parent = parent
    container.Size = props.Size or UDim2.new(1, 0, 0, UIUtilities.CONSTANTS.SIZES.INPUT_HEIGHT)
    container.Position = props.Position or UDim2.new(0, 0, 0, 0)
    container.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SURFACE
    container.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UIUtilities.CONSTANTS.SIZES.RADIUS_MD)
    corner.Parent = container
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = UIUtilities.CONSTANTS.COLORS.BORDER_LIGHT
    stroke.Thickness = 1
    stroke.Parent = container
    
    local textBox = Instance.new("TextBox")
    textBox.Name = "TextInput"
    textBox.Parent = container
    textBox.Size = UDim2.new(1, -16, 1, 0)
    textBox.Position = UDim2.new(0, 8, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text = props.PlaceholderText or ""
    textBox.PlaceholderText = props.PlaceholderText or "Enter text..."
    textBox.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    textBox.PlaceholderColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    textBox.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_MD
    textBox.Font = UIUtilities.CONSTANTS.FONTS.BODY
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.ClearTextOnFocus = false
    
    -- Focus effects
    textBox.Focused:Connect(function()
        stroke.Color = UIUtilities.CONSTANTS.COLORS.BORDER_FOCUS
    end)
    
    textBox.FocusLost:Connect(function()
        stroke.Color = UIUtilities.CONSTANTS.COLORS.BORDER_LIGHT
    end)
    
    return container, textBox
end

-- Dropdown Component
function UIUtilities.createDropdown(parent, props)
    props = props or {}
    
    local dropdown = Instance.new("Frame")
    dropdown.Name = props.Name or "Dropdown"
    dropdown.Parent = parent
    dropdown.Size = props.Size or UDim2.new(0, 200, 0, UIUtilities.CONSTANTS.SIZES.INPUT_HEIGHT)
    dropdown.Position = props.Position or UDim2.new(0, 0, 0, 0)
    dropdown.BackgroundColor3 = UIUtilities.CONSTANTS.COLORS.SURFACE
    dropdown.BorderSizePixel = 0
    dropdown.ClipsDescendants = true
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UIUtilities.CONSTANTS.SIZES.RADIUS_MD)
    corner.Parent = dropdown
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = UIUtilities.CONSTANTS.COLORS.BORDER_LIGHT
    stroke.Thickness = 1
    stroke.Parent = dropdown
    
    -- Selected value display
    local selectedButton = Instance.new("TextButton")
    selectedButton.Name = "SelectedButton"
    selectedButton.Parent = dropdown
    selectedButton.Size = UDim2.new(1, 0, 0, UIUtilities.CONSTANTS.SIZES.INPUT_HEIGHT)
    selectedButton.Position = UDim2.new(0, 0, 0, 0)
    selectedButton.BackgroundTransparency = 1
    selectedButton.Text = props.SelectedText or "Select option..."
    selectedButton.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    selectedButton.TextSize = UIUtilities.CONSTANTS.SIZES.TEXT_MD
    selectedButton.Font = UIUtilities.CONSTANTS.FONTS.BODY
    selectedButton.TextXAlignment = Enum.TextXAlignment.Left
    
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_MD)
    padding.PaddingRight = UDim.new(0, UIUtilities.CONSTANTS.SIZES.PADDING_MD)
    padding.Parent = selectedButton
    
    -- Dropdown arrow
    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.Parent = selectedButton
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.Position = UDim2.new(1, -24, 0.5, -8)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_MUTED
    arrow.TextSize = 12
    arrow.Font = UIUtilities.CONSTANTS.FONTS.BODY
    
    return dropdown
end

-- Layout Utilities
function UIUtilities.applyListLayout(parent, props)
    props = props or {}
    
    local layout = Instance.new("UIListLayout")
    layout.Parent = parent
    layout.FillDirection = props.FillDirection or Enum.FillDirection.Vertical
    layout.HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = props.VerticalAlignment or Enum.VerticalAlignment.Top
    layout.Padding = UDim.new(0, props.Padding or UIUtilities.CONSTANTS.SIZES.PADDING_SM)
    layout.SortOrder = props.SortOrder or Enum.SortOrder.LayoutOrder
    
    return layout
end

function UIUtilities.applyGridLayout(parent, props)
    props = props or {}
    
    local layout = Instance.new("UIGridLayout")
    layout.Parent = parent
    layout.CellSize = props.CellSize or UDim2.new(0, 200, 0, 100)
    layout.CellPadding = props.CellPadding or UDim2.new(0, 8, 0, 8)
    layout.FillDirection = props.FillDirection or Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = props.VerticalAlignment or Enum.VerticalAlignment.Top
    layout.SortOrder = props.SortOrder or Enum.SortOrder.LayoutOrder
    
    return layout
end

-- Animation Helpers
function UIUtilities.fadeIn(gui, duration)
    duration = duration or UIUtilities.CONSTANTS.ANIMATIONS.DURATION_NORMAL
    gui.Transparency = 1
    gui.Visible = true
    
    TweenService:Create(gui, TweenInfo.new(duration, UIUtilities.CONSTANTS.ANIMATIONS.EASING_STANDARD), {
        Transparency = 0
    }):Play()
end

function UIUtilities.fadeOut(gui, duration, callback)
    duration = duration or UIUtilities.CONSTANTS.ANIMATIONS.DURATION_NORMAL
    
    local tween = TweenService:Create(gui, TweenInfo.new(duration, UIUtilities.CONSTANTS.ANIMATIONS.EASING_STANDARD), {
        Transparency = 1
    })
    
    tween.Completed:Connect(function()
        gui.Visible = false
        if callback then callback() end
    end)
    
    tween:Play()
end

function UIUtilities.slideIn(gui, direction, duration)
    direction = direction or "left"
    duration = duration or UIUtilities.CONSTANTS.ANIMATIONS.DURATION_NORMAL
    
    local startPosition = gui.Position
    local offscreenPosition
    
    if direction == "left" then
        offscreenPosition = startPosition - UDim2.new(1, 0, 0, 0)
    elseif direction == "right" then
        offscreenPosition = startPosition + UDim2.new(1, 0, 0, 0)
    elseif direction == "up" then
        offscreenPosition = startPosition - UDim2.new(0, 0, 1, 0)
    elseif direction == "down" then
        offscreenPosition = startPosition + UDim2.new(0, 0, 1, 0)
    end
    
    gui.Position = offscreenPosition
    gui.Visible = true
    
    TweenService:Create(gui, TweenInfo.new(duration, UIUtilities.CONSTANTS.ANIMATIONS.EASING_STANDARD), {
        Position = startPosition
    }):Play()
end

return UIUtilities 