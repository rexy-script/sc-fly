--[[
    IRON ADMIN PANEL v1.0
    Target: Roblox (Client-side)
    Executor: Delta (mobile-compatible)
    Features: Fly, Noclip, Speed, JumpPower, Infinite Jump, Teleport,
              Godmode (local), Fullbright, ESP, Freeze, Rejoin, Reset
    Author: Axiom / Kyler
    Simulation: IRON-GATE-RBX-ADMIN-005
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
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

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
    WalkSpeed    = 16,
    JumpPower    = 50,
    FlySpeed     = 60,
}

-- Connections
local Connections = {
    Fly = nil,
    Noclip = nil,
    InfiniteJump = nil,
    ESP = nil,
}

-- Fly objects
local FlyBV, FlyBG = nil, nil

-- ESP objects
local ESPObjects = {}

-- Original lighting state
local OriginalLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
}

-- =====================================================================
-- UTILITY: UI PARENT
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
    local char = getChar()
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getChar()
    return char:FindFirstChildOfClass("Humanoid")
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3,
        })
    end)
end

-- =====================================================================
-- FEATURE: FLY
-- =====================================================================
local function startFly()
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return end

    for _, o in ipairs(hrp:GetChildren()) do
        if o:IsA("BodyVelocity") or o:IsA("BodyGyro") then o:Destroy() end
    end

    FlyBV = Instance.new("BodyVelocity")
    FlyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    FlyBV.Velocity = Vector3.zero
    FlyBV.Parent = hrp

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

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end

        local mv = hum.MoveDirection
        if mv.Magnitude > 0 then dir = dir + mv end

        FlyBV.Velocity = dir.Magnitude > 0 and (dir.Unit * State.FlySpeed) or Vector3.zero
        FlyBG.CFrame = cam.CFrame
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
-- FEATURE: NOCLIP
-- =====================================================================
local function startNoclip()
    Connections.Noclip = RunService.Stepped:Connect(function()
        if not State.Noclip then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

local function stopNoclip()
    if Connections.Noclip then Connections.Noclip:Disconnect() Connections.Noclip = nil end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- =====================================================================
-- FEATURE: INFINITE JUMP
-- =====================================================================
local function startInfiniteJump()
    Connections.InfiniteJump = UserInputService.JumpRequest:Connect(function()
        if not State.InfiniteJump then return end
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

local function stopInfiniteJump()
    if Connections.InfiniteJump then
        Connections.InfiniteJump:Disconnect()
        Connections.InfiniteJump = nil
    end
end

-- =====================================================================
-- FEATURE: GODMODE (LOCAL VISUAL)
-- =====================================================================
local function startGodmode()
    local hum = getHumanoid()
    if hum then
        hum.MaxHealth = math.huge
        hum.Health = math.huge
        hum.NameDisplayDistance = 0
    end
    -- Re-apply on respawn via loop
    if not State._GodmodeLoop then
        State._GodmodeLoop = task.spawn(function()
            while State.Godmode do
                local h = getHumanoid()
                if h then
                    h.MaxHealth = math.huge
                    h.Health = math.huge
                end
                task.wait(0.5)
            end
        end)
    end
end

local function stopGodmode()
    State._GodmodeLoop = nil
    local hum = getHumanoid()
    if hum then
        hum.MaxHealth = 100
        hum.Health = 100
        hum.NameDisplayDistance = 100
    end
end

-- =====================================================================
-- FEATURE: FULLBRIGHT
-- =====================================================================
local function startFullbright()
    Lighting.Ambient = Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
    Lighting.Brightness = 3
    Lighting.ClockTime = 12
    Lighting.FogEnd = 100000
end

local function stopFullbright()
    Lighting.Ambient = OriginalLighting.Ambient
    Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    Lighting.Brightness = OriginalLighting.Brightness
    Lighting.ClockTime = OriginalLighting.ClockTime
    Lighting.FogEnd = OriginalLighting.FogEnd
end

-- =====================================================================
-- FEATURE: ESP (PLAYER HIGHLIGHT)
-- =====================================================================
local function createESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "IronESP"
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
    highlight.Parent = char
    ESPObjects[player] = highlight
end

local function removeESP(player)
    if ESPObjects[player] then
        ESPObjects[player]:Destroy()
        ESPObjects[player] = nil
    end
end

local function startESP()
    for _, p in ipairs(Players:GetPlayers()) do
        createESP(p)
        p.CharacterAdded:Connect(function(c)
            if State.ESP then
                task.wait(0.5)
                createESP(p)
            end
        end)
    end
    Connections.ESP = Players.PlayerAdded:Connect(function(p)
        if State.ESP then createESP(p) end
    end)
end

local function stopESP()
    for p, h in pairs(ESPObjects) do
        if h then h:Destroy() end
    end
    ESPObjects = {}
    if Connections.ESP then Connections.ESP:Disconnect() Connections.ESP = nil end
end

-- =====================================================================
-- FEATURE: FREEZE (LOCAL ANCHOR)
-- =====================================================================
local function setFrozen(freeze)
    local hrp = getHRP()
    if hrp then
        hrp.Anchored = freeze
    end
    State.Frozen = freeze
end

-- =====================================================================
-- FEATURE: TELEPORT TO COORDINATES
-- =====================================================================
local function teleportTo(x, y, z)
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(x, y, z)
    end
end

-- =====================================================================
-- FEATURE: SPEED / JUMP
-- =====================================================================
local function applySpeed(val)
    local hum = getHumanoid()
    if hum then hum.WalkSpeed = val end
    State.WalkSpeed = val
end

local function applyJump(val)
    local hum = getHumanoid()
    if hum then hum.JumpPower = val; hum.UseJumpPower = true end
    State.JumpPower = val
end

-- =====================================================================
-- UI BUILDER
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

    -- Toggle button
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 60, 0, 60)
    toggle.Position = UDim2.new(0, 15, 0.4, 0)
    toggle.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    toggle.Text = "ADMIN"
    toggle.TextColor3 = Color3.fromRGB(0, 220, 255)
    toggle.TextScaled = true
    toggle.Font = Enum.Font.GothamBold
    toggle.BorderSizePixel = 0
    toggle.Parent = gui
    local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0,12) tc.Parent = toggle

    -- Main panel
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 300, 0, 420)
    panel.Position = UDim2.new(0.5, -150, 0.5, -210)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    panel.Parent = gui
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0,12) pc.Parent = panel
    local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(0,220,255) ps.Thickness = 1.5 ps.Transparency = 0.4 ps.Parent = panel

    -- Header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 42)
    header.BackgroundTransparency = 1
    header.Text = "⚡ IRON ADMIN PANEL"
    header.TextColor3 = Color3.fromRGB(0, 220, 255)
    header.TextSize = 18
    header.Font = Enum.Font.GothamBold
    header.Parent = panel

    -- Close button
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 30, 0, 30)
    close.Position = UDim2.new(1, -36, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255,255,255)
    close.TextSize = 14
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    close.Parent = panel
    local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,8) cc.Parent = close

    -- Scrolling container
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -55)
    scroll.Position = UDim2.new(0, 10, 0, 48)
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

    -- Button factory
    local function makeToggle(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 42)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        btn.Text = text .. ": OFF"
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.TextSize = 15
        btn.Font = Enum.Font.GothamSemibold
        btn.BorderSizePixel = 0
        btn.Parent = scroll
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,8) c.Parent = btn

        local enabled = false
        btn.MouseButton1Click:Connect(function()
            enabled = not enabled
            if enabled then
                btn.Text = text .. ": ON"
                btn.BackgroundColor3 = Color3.fromRGB(0, 130, 90)
                btn.TextColor3 = Color3.fromRGB(255,255,255)
            else
                btn.Text = text .. ": OFF"
                btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
                btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
            callback(enabled)
        end)
        return btn
    end

    local function makeInput(labelText, placeholder, default, onConfirm)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(160, 160, 180)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = scroll

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, -10, 0, 34)
        box.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
        box.Text = tostring(default)
        box.PlaceholderText = placeholder
        box.TextColor3 = Color3.fromRGB(0, 220, 255)
        box.TextSize = 14
        box.Font = Enum.Font.Gotham
        box.BorderSizePixel = 0
        box.Parent = scroll
        local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = box

        box.FocusLost:Connect(function()
            onConfirm(box.Text)
        end)
        return box
    end

    -- ============ FEATURES ============
    makeToggle("✈ FLY", function(on)
        State.Fly = on
        if on then startFly() else stopFly() end
    end)

    makeToggle("👻 NOCLIP", function(on)
        State.Noclip = on
        if on then startNoclip() else stopNoclip() end
    end)

    makeToggle("🦘 INFINITE JUMP", function(on)
        State.InfiniteJump = on
        if on then startInfiniteJump() else stopInfiniteJump() end
    end)

    makeToggle("🛡 GODMODE (LOCAL)", function(on)
        State.Godmode = on
        if on then startGodmode() else stopGodmode() end
    end)

    makeToggle("☀ FULLBRIGHT", function(on)
        State.Fullbright = on
        if on then startFullbright() else stopFullbright() end
    end)

    makeToggle("👁 ESP (PLAYERS)", function(on)
        State.ESP = on
        if on then startESP() else stopESP() end
    end)

    makeToggle("❄ FREEZE SELF", function(on)
        setFrozen(on)
    end)

    makeInput("WALK SPEED", "16", State.WalkSpeed, function(txt)
        local n = tonumber(txt)
        if n and n >= 0 and n <= 500 then applySpeed(n) end
    end)

    makeInput("JUMP POWER", "50", State.JumpPower, function(txt)
        local n = tonumber(txt)
        if n and n >= 0 and n <= 500 then applyJump(n) end
    end)

    makeInput("FLY SPEED", "60", State.FlySpeed, function(txt)
        local n = tonumber(txt)
        if n and n >= 10 and n <= 500 then State.FlySpeed = n end
    end)

    -- Teleport section
    local tpLabel = Instance.new("TextLabel")
    tpLabel.Size = UDim2.new(1, -10, 0, 20)
    tpLabel.BackgroundTransparency = 1
    tpLabel.Text = "TELEPORT (X, Y, Z)"
    tpLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
    tpLabel.TextSize = 13
    tpLabel.Font = Enum.Font.GothamBold
    tpLabel.TextXAlignment = Enum.TextXAlignment.Left
    tpLabel.Parent = scroll

    local tpBox = Instance.new("TextBox")
    tpBox.Size = UDim2.new(1, -10, 0, 34)
    tpBox.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
    tpBox.Text = "0, 50, 0"
    tpBox.PlaceholderText = "X, Y, Z"
    tpBox.TextColor3 = Color3.fromRGB(0, 220, 255)
    tpBox.TextSize = 14
    tpBox.Font = Enum.Font.Gotham
    tpBox.BorderSizePixel = 0
    tpBox.Parent = scroll
    local tpc = Instance.new("UICorner") tpc.CornerRadius = UDim.new(0,6) tpc.Parent = tpBox

    local tpGo = Instance.new("TextButton")
    tpGo.Size = UDim2.new(1, -10, 0, 36)
    tpGo.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
    tpGo.Text = "TELEPORT"
    tpGo.TextColor3 = Color3.fromRGB(255,255,255)
    tpGo.TextSize = 14
    tpGo.Font = Enum.Font.GothamBold
    tpGo.BorderSizePixel = 0
    tpGo.Parent = scroll
    local tpcc = Instance.new("UICorner") tpcc.CornerRadius = UDim.new(0,6) tpcc.Parent = tpGo

    tpGo.MouseButton1Click:Connect(function()
        local parts = {}
        for s in string.gmatch(tpBox.Text, "([^,]+)") do
            table.insert(parts, tonumber(s))
        end
        if #parts == 3 and parts[1] and parts[2] and parts[3] then
            teleportTo(parts[1], parts[2], parts[3])
            notify("Iron Admin", "Teleported!", 2)
        else
            notify("Iron Admin", "Invalid coordinates", 2)
        end
    end)

    -- Utility buttons
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -10, 0, 38)
    resetBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
    resetBtn.Text = "🔄 RESET CHARACTER"
    resetBtn.TextColor3 = Color3.fromRGB(255,255,255)
    resetBtn.TextSize = 14
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.BorderSizePixel = 0
    resetBtn.Parent = scroll
    local rbc = Instance.new("UICorner") rbc.CornerRadius = UDim.new(0,6) rbc.Parent = resetBtn

    resetBtn.MouseButton1Click:Connect(function()
        local hum = getHumanoid()
        if hum then hum.Health = 0 end
    end)

    local rejoinBtn = Instance.new("TextButton")
    rejoinBtn.Size = UDim2.new(1, -10, 0, 38)
    rejoinBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
    rejoinBtn.Text = "🚪 REJOIN SERVER"
    rejoinBtn.TextColor3 = Color3.fromRGB(255,255,255)
    rejoinBtn.TextSize = 14
    rejoinBtn.Font = Enum.Font.GothamBold
    rejoinBtn.BorderSizePixel = 0
    rejoinBtn.Parent = scroll
    local rjc = Instance.new("UICorner") rjc.CornerRadius = UDim.new(0,6) rjc.Parent = rejoinBtn

    rejoinBtn.MouseButton1Click:Connect(function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)

    -- Footer credit
    local credit = Instance.new("TextLabel")
    credit.Size = UDim2.new(1, -10, 0, 20)
    credit.BackgroundTransparency = 1
    credit.Text = "Iron Gate Hub v1.0 | Client-side"
    credit.TextColor3 = Color3.fromRGB(100, 100, 120)
    credit.TextSize = 11
    credit.Font = Enum.Font.Gotham
    credit.Parent = scroll

    -- Toggle handlers
    toggle.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
    end)
    close.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)
end

-- =====================================================================
-- RESPAWN HANDLER
-- =====================================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.Fly then stopFly() startFly() end
    if State.Noclip then stopNoclip() startNoclip() end
    if State.Godmode then startGodmode() end
    if State.WalkSpeed ~= 16 then applySpeed(State.WalkSpeed) end
    if State.JumpPower ~= 50 then applyJump(State.JumpPower) end
    if State.ESP then
        for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    end
end)

-- =====================================================================
-- INIT
-- =====================================================================
local ok, err = pcall(createUI)
if not ok then
    warn("[IronAdmin] UI failed: " .. tostring(err))
else
    notify("Iron Admin Panel", "Loaded! Tap 'ADMIN' to open.", 5)
end

print("[IronAdmin] Panel loaded successfully.")
