-- src/shared/modules/UIManager/UIUtilities.lua
-- Common UI creation utilities and constants

local UIUtilities = {}

-- Services
local TweenService = game:GetService("TweenService")

-- UI Constants
UIUtilities.CONSTANTS = {
    COLORS = {
        PRIMARY_BG = Color3.fromHex("#0f111a"),
        SECONDARY_BG = Color3.fromHex("#1a1d29"),
        ACCENT_BLUE = Color3.fromHex("#3b82f6"),
        ACCENT_PURPLE = Color3.fromHex("#8b5cf6"),
        ACCENT_TEAL = Color3.fromHex("#14b8a6"),
        ACCENT_MAGENTA = Color3.fromHex("#ec4899"),
        SUCCESS_GREEN = Color3.fromHex("#10b981"),
        ERROR_RED = Color3.fromHex("#ef4444"),
        TEXT_PRIMARY = Color3.fromHex("#ffffff"),
        TEXT_SECONDARY = Color3.fromHex("#9ca3af")
    },
    FONTS = {
        MAIN = Enum.Font.Gotham,
        HEADER = Enum.Font.GothamBold
    },
    SIZES = {
        CORNER_RADIUS = 6,
        PADDING = 10,
        BUTTON_HEIGHT = 32,
        TAB_HEIGHT = 50
    }
}

function UIUtilities.createRoundedFrame(parent, props)
    local frame = Instance.new("Frame")
    frame.Name = props.Name or "RoundedFrame"
    frame.Parent = parent
    frame.BackgroundColor3 = props.BackgroundColor3 or UIUtilities.CONSTANTS.COLORS.SECONDARY_BG
    frame.BorderSizePixel = 0
    frame.Size = props.Size or UDim2.new(1, 0, 1, 0)
    frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, UIUtilities.CONSTANTS.SIZES.CORNER_RADIUS)
    corner.Parent = frame
    
    -- Add subtle glow effect
    if props.Glow then
        local stroke = Instance.new("UIStroke")
        stroke.Color = props.GlowColor or UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
        stroke.Thickness = 1
        stroke.Transparency = 0.7
        stroke.Parent = frame
    end
    
    return frame
end

function UIUtilities.createStyledButton(parent, props)
    local button = Instance.new("TextButton")
    button.Name = props.Name or "StyledButton"
    button.Parent = parent
    button.Size = props.Size or UDim2.new(0, 120, 0, 32)
    button.Position = props.Position or UDim2.new(0, 0, 0, 0)
    button.BackgroundColor3 = props.BackgroundColor3 or UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
    button.BorderSizePixel = 0
    button.Text = props.Text or "Button"
    button.TextColor3 = UIUtilities.CONSTANTS.COLORS.TEXT_PRIMARY
    button.TextScaled = true
    button.Font = UIUtilities.CONSTANTS.FONTS.MAIN
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button
    
    -- Hover effect
    local hoverTween = TweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {BackgroundColor3 = props.HoverColor or UIUtilities.CONSTANTS.COLORS.ACCENT_PURPLE}
    )
    
    local normalTween = TweenService:Create(
        button,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad),
        {BackgroundColor3 = props.BackgroundColor3 or UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE}
    )
    
    button.MouseEnter:Connect(function()
        hoverTween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        normalTween:Play()
    end)
    
    return button
end

function UIUtilities.createStatusIndicator(parent, props)
    local frame = Instance.new("Frame")
    frame.Name = props.Name or "StatusIndicator"
    frame.Parent = parent
    frame.Size = UDim2.new(0, 12, 0, 12)
    frame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = props.Color or UIUtilities.CONSTANTS.COLORS.SUCCESS_GREEN
    frame.BorderSizePixel = 0
    
    -- Make it circular
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = frame
    
    -- Pulsing animation for active status
    if props.Pulse then
        local pulseIn = TweenService:Create(
            frame,
            TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Transparency = 0.3}
        )
        pulseIn:Play()
    end
    
    return frame
end

function UIUtilities.createScrollFrame(parent, props)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = props.Name or "ScrollFrame"
    scrollFrame.Parent = parent
    scrollFrame.Size = props.Size or UDim2.new(1, 0, 1, 0)
    scrollFrame.Position = props.Position or UDim2.new(0, 0, 0, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = UIUtilities.CONSTANTS.COLORS.ACCENT_BLUE
    scrollFrame.CanvasSize = props.CanvasSize or UDim2.new(0, 0, 2, 0)
    
    return scrollFrame
end

return UIUtilities 