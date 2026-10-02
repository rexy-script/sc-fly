--[[
    IRON ADMIN PANEL v2.0
    Target : Roblox (Client-side)
    Executor: Delta (mobile-compatible)
    Features:
        - Fly (with adjustable Fly Speed)
        - Noclip
        - Infinite Jump
        - Walk Speed (numeric input + presets)
        - Jump Power (numeric input + presets)
        - Godmode (local, visual)
        - Fullbright
        - ESP (player highlight)
        - Freeze Self
        - Teleport (X, Y, Z)
        - Reset Character
        - Rejoin Server
    Author : Axiom / Kyler
    Sim ID : IRON-GATE-RBX-ADMIN-006
]]

-- =====================================================================
-- SERVICES
-- =====================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local StarterGui        = game:GetService("StarterGui")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- =====================================================================
-- STATE
-- =====================================================================
local State = {
    Fly          = false,
    Noclip       = false,
    InfiniteJump = false,
    Godmode      = false,
    Fullbright   = false,
    ESP          = false,
    Frozen       = false,

    FlySpeed     = 60,
    WalkSpeed    = 16,
    JumpPower    = 50,
}

local Connections = {
    Fly          = nil,
    Noclip       = nil,
    InfiniteJump = nil,
    ESP          = nil,
}

local FlyBV, FlyBG = nil, nil
local ESPObjects   = {}
local GodmodeThread = nil

-- Original lighting snapshot
local OriginalLighting = {
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    FogEnd         = Lighting.FogEnd,
}

-- =====================================================================
-- UTILITY
-- =====================================================================
local function getUIParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 3,
        })
    end)
end

-- =====================================================================
-- FLY
-- =====================================================================
local function startFly()
    local hrp, hum = getHRP(), getHumanoid()
    if not hrp or not hum then return end

    for _, o in ipairs(hrp:GetChildren()) do
        if o:IsA("BodyVelocity") or o:IsA("BodyGyro") then o:Destroy() end
    end

    FlyBV = Instance.new("BodyVelocity")
    FlyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    FlyBV.Velocity = Vector3.zero
    FlyBV.Parent   = hrp

    FlyBG = Instance.new("BodyGyro")
    FlyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    FlyBG.P = 1e4
    FlyBG.Parent = hrp

    hum.PlatformStand = true
    hum:ChangeState(Enum.HumanoidStateType.Physics)

    Connections.Fly = RunService.RenderStepped:Connect(function()
        if not State.Fly then return end
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)        then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)  then dir -= Vector3.new(0, 1, 0) end

        local mv = hum.MoveDirection
        if mv.Magnitude > 0 then dir += mv end

        FlyBV.Velocity = (dir.Magnitude > 0) and (dir.Unit * State.FlySpeed) or Vector3.zero
        FlyBG.CFrame   = cam.CFrame
    end)
end

local function stopFly()
    if Connections.Fly then Connections.Fly:Disconnect() Connections.Fly = nil end
    if FlyBV then FlyBV:Destroy() FlyBV = nil end
    if FlyBG then FlyBG:Destroy() FlyBG = nil end
    local hum = getHumanoid()
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

-- =====================================================================
-- NOCLIP
-- =====================================================================
local function startNoclip()
    Connections.Noclip = RunService.Stepped:Connect(function()
        if not State.Noclip then return end
        local c = LocalPlayer.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

local function stopNoclip()
    if Connections.Noclip then Connections.Noclip:Disconnect() Connections.Noclip = nil end
    local c = LocalPlayer.Character
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

-- =====================================================================
-- INFINITE JUMP
-- =====================================================================
local function startInfiniteJump()
    Connections.InfiniteJump = UserInputService.JumpRequest:Connect(function()
        if not State.InfiniteJump then return end
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function stopInfiniteJump()
    if Connections.InfiniteJump then
        Connections.InfiniteJump:Disconnect()
        Connections.InfiniteJump = nil
    end
end

-- =====================================================================
-- GODMODE (LOCAL)
-- =====================================================================
local function startGodmode()
    local function apply()
        local hum = getHumanoid()
        if hum then
            hum.MaxHealth = math.huge
            hum.Health = math.huge
            hum.NameDisplayDistance = 0
        end
    end
    apply()
    GodmodeThread = task.spawn(function()
        while State.Godmode do
            apply()
            task.wait(0.5)
        end
    end)
end

local function stopGodmode()
    State.Godmode = false
    if GodmodeThread then task.cancel(GodmodeThread) GodmodeThread = nil end
    local hum = getHumanoid()
    if hum then
        hum.MaxHealth = 100
        hum.Health = 100
        hum.NameDisplayDistance = 100
    end
end

-- =====================================================================
-- FULLBRIGHT
-- =====================================================================
local function startFullbright()
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    Lighting.Brightness = 3
    Lighting.ClockTime = 12
    Lighting.FogEnd = 1e5
end

local function stopFullbright()
    Lighting.Ambient = OriginalLighting.Ambient
    Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.ClockTime = OriginalLighting.ClockTime
    Lighting.FogEnd = OriginalLighting.FogEnd
end

-- =====================================================================
-- ESP
-- =====================================================================
local function createESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    if ESPObjects[player] then ESPObjects[player]:Destroy() end

    local hl = Instance.new("Highlight")
    hl.Name = "IronESP"
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = char
    ESPObjects[player] = hl
end

local function stopESP()
    for _, hl in pairs(ESPObjects) do
        if hl then hl:Destroy() end
    end
    ESPObjects = {}
    if Connections.ESP then Connections.ESP:Disconnect() Connections.ESP = nil end
end

local function startESP()
    for _, p in ipairs(Players:GetPlayers()) do
        createESP(p)
        p.CharacterAdded:Connect(function()
            if State.ESP then
                task.wait(0.5)
                createESP(p)
            end
        end)
    end
    Connections.ESP = Players.PlayerAdded:Connect(function(p)
        if State.ESP then
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                if State.ESP then createESP(p) end
            end)
            createESP(p)
        end
    end)
end

-- =====================================================================
-- FREEZE / TELEPORT / SPEED / JUMP
-- =====================================================================
local function setFrozen(v)
    local hrp = getHRP()
    if hrp then hrp.Anchored = v end
    State.Frozen = v
end

local function teleportTo(x, y, z)
    local hrp = getHRP()
    if hrp then hrp.CFrame = CFrame.new(x, y, z) end
end

local function applyWalkSpeed(v)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = v end
    State.WalkSpeed = v
end

local function applyJumpPower(v)
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
    State.JumpPower = v
end

-- =====================================================================
-- UI
-- =====================================================================
local function createUI()
    local parent = getUIParent()
    if parent:FindFirstChild("IronAdminPanel") then
        parent.IronAdminPanel:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "IronAdminPanel"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent

    -- Floating toggle button
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 62, 0, 62)
    toggle.Position = UDim2.new(0, 15, 0.4, 0)
    toggle.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    toggle.Text = "ADMIN"
    toggle.TextColor3 = Color3.fromRGB(0, 220, 255)
    toggle.TextScaled = true
    toggle.Font = Enum.Font.GothamBold
    toggle.BorderSizePixel = 0
    toggle.Parent = gui
    do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 14) c.Parent = toggle end

    -- Main panel
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 320, 0, 460)
    panel.Position = UDim2.new(0.5, -160, 0.5, -230)
    panel.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    panel.Parent = gui
    do
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 14) c.Parent = panel
        local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(0, 220, 255) s.Thickness = 1.5 s.Transparency = 0.4 s.Parent = panel
    end

    -- Header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundTransparency = 1
    header.Text = "⚡ IRON ADMIN PANEL v2"
    header.TextColor3 = Color3.fromRGB(0, 220, 255)
    header.TextSize = 18
    header.Font = Enum.Font.GothamBold
    header.Parent = panel

    -- Close
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 30, 0, 30)
    close.Position = UDim2.new(1, -38, 0, 7)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 14
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    close.Parent = panel
    do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = close end

    -- Scrolling area
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -58)
    scroll.Position = UDim2.new(0, 10, 0, 52)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 220, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    -- Section header helper
    local function section(text)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 22)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(0, 220, 255)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = scroll
    end

    -- Toggle factory
    local function toggleBtn(text, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 42)
        b.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        b.Text = text .. ": OFF"
        b.TextColor3 = Color3.fromRGB(200, 200, 200)
        b.TextSize = 15
        b.Font = Enum.Font.GothamSemibold
        b.BorderSizePixel = 0
        b.Parent = scroll
        do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = b end

        local on = false
        b.MouseButton1Click:Connect(function()
            on = not on
            if on then
                b.Text = text .. ": ON"
                b.BackgroundColor3 = Color3.fromRGB(0, 130, 90)
                b.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                b.Text = text .. ": OFF"
                b.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
                b.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
            callback(on)
        end)
        return b
    end

    -- Numeric input with Apply button
    local function numRow(labelText, default, onApply)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -10, 0, 36)
        row.BackgroundTransparency = 1
        row.Parent = scroll
        do
            local l = Instance.new("UIListLayout")
            l.FillDirection = Enum.FillDirection.Horizontal
            l.Padding = UDim.new(0, 6)
            l.VerticalAlignment = Enum.VerticalAlignment.Center
            l.Parent = row
        end

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 110, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
        lbl.TextSize = 13
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0, 100, 1, 0)
        box.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
        box.Text = tostring(default)
        box.TextColor3 = Color3.fromRGB(0, 220, 255)
        box.TextSize = 14
        box.Font = Enum.Font.Gotham
        box.BorderSizePixel = 0
        box.ClearTextOnFocus = false
        box.Parent = row
        do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = box end

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
        btn.Text = "Apply"
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.BorderSizePixel = 0
        btn.Parent = row
        do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn end

        local function commit()
            local n = tonumber(box.Text)
            if n then
                onApply(n)
                notify("Iron Admin", labelText .. " set to " .. n, 2)
            else
                box.Text = tostring(default)
            end
        end

        btn.MouseButton1Click:Connect(commit)
        box.FocusLost:Connect(commit)
        return box
    end

    -- ============= FEATURE LIST =============

    section("MOVEMENT")

    toggleBtn("✈ FLY", function(on)
        State.Fly = on
        if on then startFly() else stopFly() end
    end)

    numRow("Fly Speed", State.FlySpeed, function(n)
        if n >= 10 and n <= 500 then State.FlySpeed = n end
    end)

    toggleBtn("👻 NOCLIP", function(on)
        State.Noclip = on
        if on then startNoclip() else stopNoclip() end
    end)

    toggleBtn("🦘 INFINITE JUMP", function(on)
        State.InfiniteJump = on
        if on then startInfiniteJump() else stopInfiniteJump() end
    end)

    section("SPEED & JUMP")

    numRow("Walk Speed", State.WalkSpeed, function(n)
        if n >= 0 and n <= 500 then applyWalkSpeed(n) end
    end)

    numRow("Jump Power", State.JumpPower, function(n)
        if n >= 0 and n <= 500 then applyJumpPower(n) end
    end)

    -- Quick presets for WalkSpeed
    do
        local presetFrame = Instance.new("Frame")
        presetFrame.Size = UDim2.new(1, -10, 0, 32)
        presetFrame.BackgroundTransparency = 1
        presetFrame.Parent = scroll
        local l = Instance.new("UIListLayout")
        l.FillDirection = Enum.FillDirection.Horizontal
        l.Padding = UDim.new(0, 6)
        l.Parent = presetFrame

        for _, speed in ipairs({16, 50, 100, 200}) do
            local pb = Instance.new("TextButton")
            pb.Size = UDim2.new(0, 62, 1, 0)
            pb.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            pb.Text = tostring(speed)
            pb.TextColor3 = Color3.fromRGB(0, 220, 255)
            pb.TextSize = 13
            pb.Font = Enum.Font.GothamBold
            pb.BorderSizePixel = 0
            pb.Parent = presetFrame
            do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = pb end
            pb.MouseButton1Click:Connect(function()
                applyWalkSpeed(speed)
                notify("Iron Admin", "WalkSpeed → " .. speed, 2)
            end)
        end
    end

    -- Quick presets for JumpPower
    do
        local presetFrame = Instance.new("Frame")
        presetFrame.Size = UDim2.new(1, -10, 0, 32)
        presetFrame.BackgroundTransparency = 1
        presetFrame.Parent = scroll
        local l = Instance.new("UIListLayout")
        l.FillDirection = Enum.FillDirection.Horizontal
        l.Padding = UDim.new(0, 6)
        l.Parent = presetFrame

        for _, jp in ipairs({50, 100, 200, 350}) do
            local pb = Instance.new("TextButton")
            pb.Size = UDim2.new(0, 62, 1, 0)
            pb.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            pb.Text = tostring(jp)
            pb.TextColor3 = Color3.fromRGB(0, 220, 255)
            pb.TextSize = 13
            pb.Font = Enum.Font.GothamBold
            pb.BorderSizePixel = 0
            pb.Parent = presetFrame
            do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = pb end
            pb.MouseButton1Click:Connect(function()
                applyJumpPower(jp)
        