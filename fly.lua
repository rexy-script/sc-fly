--[[
    IRON GATE HUB v1.0
    Target: Roblox (Client-side)
    Executor: Delta (mobile-compatible)
    Features: Fly, Translucent (Local Invisibility)
    Author: Axiom / Kyler
    Simulation: IRON-GATE-RBX-LUA-004
]]

-- =====================================================================
-- SERVICES
-- =====================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- =====================================================================
-- STATE
-- =====================================================================
local State = {
    Fly         = false,
    Translucent = false,
    FlySpeed    = 50,
    Transparency = 0.5,
}

-- Store original transparency for restore
local OriginalTransparency = {}

-- Fly connection handle
local FlyConnection = nil
local FlyBodyVelocity = nil
local FlyBodyGyro = nil

-- =====================================================================
-- UTILITY: SAFE UI PARENTING
-- =====================================================================
local function getUIParent()
    -- Try gethui (Delta supports it), fallback to CoreGui, then PlayerGui
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return CoreGui end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- =====================================================================
-- FEATURE 1: FLY
-- =====================================================================
local function startFly()
    local character = LocalPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not rootPart then return end

    -- Remove existing velocity objects if any
    for _, obj in ipairs(rootPart:GetChildren()) do
        if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") then
            obj:Destroy()
        end
    end

    -- Create BodyVelocity for movement
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = rootPart

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 1e4
    bg.Parent = rootPart

    FlyBodyVelocity = bv
    FlyBodyGyro = bg

    -- Adjust humanoid state to allow flight
    humanoid.PlatformStand = true
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    -- Connection: update velocity every frame
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not State.Fly then return end
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero

        -- Keyboard input (PC)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - cam.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + cam.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end

        -- Mobile: use camera direction + on-screen joystick
        local moveVector = humanoid.MoveDirection
        if moveVector.Magnitude > 0 then
            moveDir = moveDir + moveVector
        end

        if moveDir.Magnitude > 0 then
            bv.Velocity = moveDir.Unit * State.FlySpeed
        else
            bv.Velocity = Vector3.zero
        end

        bg.CFrame = cam.CFrame
    end)
end

local function stopFly()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    if FlyBodyVelocity then
        FlyBodyVelocity:Destroy()
        FlyBodyVelocity = nil
    end
    if FlyBodyGyro then
        FlyBodyGyro:Destroy()
        FlyBodyGyro = nil
    end
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end

-- =====================================================================
-- FEATURE 2: TRANSLUCENT (LOCAL INVISIBILITY)
-- =====================================================================
local function applyTransparency(instance, value)
    if not instance then return end
    for _, part in ipairs(instance:GetDescendants()) do
        if part:IsA("BasePart") then
            if OriginalTransparency[part] == nil then
                OriginalTransparency[part] = part.Transparency
            end
            part.Transparency = value
        elseif part:IsA("Decal") then
            if OriginalTransparency[part] == nil then
                OriginalTransparency[part] = part.Transparency
            end
            part.Transparency = value
        end
    end
    if instance:IsA("BasePart") then
        if OriginalTransparency[instance] == nil then
            OriginalTransparency[instance] = instance.Transparency
        end
        instance.Transparency = value
    end
end

local function startTranslucent()
    local character = LocalPlayer.Character
    if not character then return end

    applyTransparency(character, State.Transparency)

    -- Watch for respawns/character changes
    if not State._CharConnection then
        State._CharConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(0.5)
            if State.Translucent then
                applyTransparency(newChar, State.Transparency)
            end
        end)
    end
end

local function stopTranslucent()
    local character = LocalPlayer.Character
    if character then
        applyTransparency(character, 0)  -- Restore to opaque
    end
    -- Restore original values
    for part, orig in pairs(OriginalTransparency) do
        if part and part.Parent then
            pcall(function() part.Transparency = orig end)
        end
    end
    OriginalTransparency = {}
end

-- =====================================================================
-- UI BUILDER (Mobile-friendly, lightweight)
-- =====================================================================
local function createUI()
    local parent = getUIParent()

    -- Destroy old UI if exists
    if parent:FindFirstChild("IronGateHub") then
        parent.IronGateHub:Destroy()
    end

    -- Main ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "IronGateHub"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent

    -- Draggable toggle button (minimized state)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(0, 60, 0, 60)
    toggleBtn.Position = UDim2.new(0, 20, 0.5, -30)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    toggleBtn.BackgroundTransparency = 0.1
    toggleBtn.Text = "IG"
    toggleBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
    toggleBtn.TextScaled = true
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = gui

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 12)
    toggleCorner.Parent = toggleBtn

    -- Main frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 280, 0, 320)
    frame.Position = UDim2.new(0.5, -140, 0.5, -160)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = frame

    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(0, 200, 255)
    frameStroke.Thickness = 1.5
    frameStroke.Transparency = 0.5
    frameStroke.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ IRON GATE HUB"
    title.TextColor3 = Color3.fromRGB(0, 200, 255)
    title.TextScaled = false
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = frame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    -- Section: Fly
    local flyBtn = Instance.new("TextButton")
    flyBtn.Size = UDim2.new(0.9, 0, 0, 45)
    flyBtn.Position = UDim2.new(0.05, 0, 0, 60)
    flyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    flyBtn.Text = "✈ FLY: OFF"
    flyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    flyBtn.TextSize = 16
    flyBtn.Font = Enum.Font.GothamSemibold
    flyBtn.BorderSizePixel = 0
    flyBtn.Parent = frame

    local flyCorner = Instance.new("UICorner")
    flyCorner.CornerRadius = UDim.new(0, 8)
    flyCorner.Parent = flyBtn

    -- Fly speed slider label
    local speedLabel = Instance.new("TextLabel")
    speedLabel.Size = UDim2.new(0.9, 0, 0, 20)
    speedLabel.Position = UDim2.new(0.05, 0, 0, 115)
    speedLabel.BackgroundTransparency = 1
    speedLabel.Text = "Fly Speed: " .. State.FlySpeed
    speedLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    speedLabel.TextSize = 12
    speedLabel.Font = Enum.Font.Gotham
    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
    speedLabel.Parent = frame

    -- Speed slider (using TextBox for mobile simplicity)
    local speedBox = Instance.new("TextBox")
    speedBox.Size = UDim2.new(0.9, 0, 0, 30)
    speedBox.Position = UDim2.new(0.05, 0, 0, 140)
    speedBox.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    speedBox.Text = tostring(State.FlySpeed)
    speedBox.TextColor3 = Color3.fromRGB(0, 200, 255)
    speedBox.TextSize = 14
    speedBox.Font = Enum.Font.Gotham
    speedBox.BorderSizePixel = 0
    speedBox.PlaceholderText = "Speed (10-500)"
    speedBox.Parent = frame

    local speedCorner = Instance.new("UICorner")
    speedCorner.CornerRadius = UDim.new(0, 6)
    speedCorner.Parent = speedBox

    -- Section: Translucent
    local transBtn = Instance.new("TextButton")
    transBtn.Size = UDim2.new(0.9, 0, 0, 45)
    transBtn.Position = UDim2.new(0.05, 0, 0, 185)
    transBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    transBtn.Text = "👻 TRANSLUCENT: OFF"
    transBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    transBtn.TextSize = 16
    transBtn.Font = Enum.Font.GothamSemibold
    transBtn.BorderSizePixel = 0
    transBtn.Parent = frame

    local transCorner = Instance.new("UICorner")
    transCorner.CornerRadius = UDim.new(0, 8)
    transCorner.Parent = transBtn

    -- Transparency slider label
    local alphaLabel = Instance.new("TextLabel")
    alphaLabel.Size = UDim2.new(0.9, 0, 0, 20)
    alphaLabel.Position = UDim2.new(0.05, 0, 0, 240)
    alphaLabel.BackgroundTransparency = 1
    alphaLabel.Text = "Alpha: " .. State.Transparency
    alphaLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    alphaLabel.TextSize = 12
    alphaLabel.Font = Enum.Font.Gotham
    alphaLabel.TextXAlignment = Enum.TextXAlignment.Left
    alphaLabel.Parent = frame

    -- Alpha textbox
    local alphaBox = Instance.new("TextBox")
    alphaBox.Size = UDim2.new(0.9, 0, 0, 30)
    alphaBox.Position = UDim2.new(0.05, 0, 0, 265)
    alphaBox.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    alphaBox.Text = tostring(State.Transparency)
    alphaBox.TextColor3 = Color3.fromRGB(0, 200, 255)
    alphaBox.TextSize = 14
    alphaBox.Font = Enum.Font.Gotham
    alphaBox.BorderSizePixel = 0
    alphaBox.PlaceholderText = "0.0 - 1.0"
    alphaBox.Parent = frame

    local alphaCorner = Instance.new("UICorner")
    alphaCorner.CornerRadius = UDim.new(0, 6)
    alphaCorner.Parent = alphaBox

    -- =====================================================================
    -- UI EVENT HANDLERS
    -- =====================================================================
    toggleBtn.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
    end)

    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)

    -- Fly toggle
    flyBtn.MouseButton1Click:Connect(function()
        State.Fly = not State.Fly
        if State.Fly then
            flyBtn.Text = "✈ FLY: ON"
            flyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            flyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            startFly()
        else
            flyBtn.Text = "✈ FLY: OFF"
            flyBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            flyBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            stopFly()
        end
    end)

    -- Speed input
    speedBox.FocusLost:Connect(function()
        local num = tonumber(speedBox.Text)
        if num and num >= 10 and num <= 500 then
            State.FlySpeed = num
            speedLabel.Text = "Fly Speed: " .. num
        else
            speedBox.Text = tostring(State.FlySpeed)
        end
    end)

    -- Translucent toggle
    transBtn.MouseButton1Click:Connect(function()
        State.Translucent = not State.Translucent
        if State.Translucent then
            transBtn.Text = "👻 TRANSLUCENT: ON"
            transBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
            transBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            startTranslucent()
        else
            transBtn.Text = "👻 TRANSLUCENT: OFF"
            transBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            transBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            stopTranslucent()
        end
    end)

    -- Alpha input
    alphaBox.FocusLost:Connect(function()
        local num = tonumber(alphaBox.Text)
        if num and num >= 0 and num <= 1 then
            State.Transparency = num
            alphaLabel.Text = "Alpha: " .. num
            if State.Translucent then
                applyTransparency(LocalPlayer.Character, num)
            end
        else
            alphaBox.Text = tostring(State.Transparency)
        end
    end)

    return gui
end

-- =====================================================================
-- CHARACTER RESPAWN HANDLING
-- =====================================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if State.Translucent then
        startTranslucent()
    end
    if State.Fly then
        stopFly()
        State.Fly = false
        startFly()
    end
end)

-- =====================================================================
-- INIT
-- =====================================================================
local ok, err = pcall(function()
    createUI()
end)

if not ok then
    warn("[IronGate] UI creation failed: " .. tostring(err))
else
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Iron Gate Hub",
            Text = "Loaded successfully. Tap 'IG' to open.",
            Duration = 5,
        })
    end)
end

print("[IronGate] Hub loaded. Fly + Translucent ready.")