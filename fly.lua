--[[
    IRON ADMIN PANEL v2.0
    Target: Roblox (Client-side)
    Executor: Delta (mobile-compatible)
    New: Live XYZ coords, sliders for speed/jump/fly, state readout
    Simulation: IRON-GATE-RBX-ADMIN-006
]]

-- =====================================================================
-- SERVICES
-- =====================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local StarterGui       = game:GetService("StarterGui")
local TeleportService  = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

local Connections = {
    Fly = nil, Noclip = nil, InfiniteJump = nil, ESP = nil,
    CoordUpdate = nil,
}

local FlyBV, FlyBG = nil, nil
local ESPObjects = {}
local UI = {}   -- store UI references for updating

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

local function getChar() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function getHRP() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end

local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = dur or 3,
        })
    end)
end

-- =====================================================================
-- FEATURE: FLY
-- =====================================================================
local function startFly()
    local hrp, hum = getHRP(), getHum()
    if not hrp or not hum then return end
    for _, o in ipairs(hrp:GetChildren()) do
        if o:IsA("BodyVelocity") or o:IsA("BodyGyro") then o:Destroy() end
    end
    FlyBV = Instance.new("BodyVelocity")
    FlyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
    FlyBV.Velocity = Vector3.zero
    FlyBV.Parent = hrp

    FlyBG = Instance.new("BodyGyro")
    FlyBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
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
    local hum = getHum()
    if hum then hum.PlatformStand = false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
end

-- =====================================================================
-- FEATURE: NOCLIP
-- =====================================================================
local function startNoclip()
    Connections.Noclip = RunService.Stepped:Connect(function()
        if not State.Noclip then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end

local function stopNoclip()
    if Connections.Noclip then Connections.Noclip:Disconnect() Connections.Noclip = nil end
    local char = LocalPlayer.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

-- =====================================================================
-- FEATURE: INFINITE JUMP
-- =====================================================================
local function startInfiniteJump()
    Connections.InfiniteJump = UserInputService.JumpRequest:Connect(function()
        if not State.InfiniteJump then return end
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

local function stopInfiniteJump()
    if Connections.InfiniteJump then
        Connections.InfiniteJump:Disconnect()
        Connections.InfiniteJump = nil
    end
end

-- =====================================================================
-- FEATURE: GODMODE (LOCAL)
-- =====================================================================
local function startGodmode()
    local function apply()
        local h = getHum()
        if h then h.MaxHealth = math.huge; h.Health = math.huge end
    end
    apply()
    State._GodmodeLoop = task.spawn(function()
        while State.Godmode do apply(); task.wait(0.5) end
    end)
end

local function stopGodmode()
    State._GodmodeLoop = nil
    local h = getHum()
    if h then h.MaxHealth = 100; h.Health = 100 end
end

-- =====================================================================
-- FEATURE: FULLBRIGHT
-- =====================================================================
local OrigLight = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
}

local function startFullbright()
    Lighting.Ambient = Color3.fromRGB(255,255,255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
    Lighting.Brightness = 3
    Lighting.ClockTime = 12
    Lighting.FogEnd = 100000
end

local function stopFullbright()
    Lighting.Ambient = OrigLight.Ambient
    Lighting.OutdoorAmbient = OrigLight.OutdoorAmbient
    Lighting.Brightness = OrigLight.Brightness
    Lighting.ClockTime = OrigLight.ClockTime
    Lighting.FogEnd = OrigLight.FogEnd
end

-- =====================================================================
-- FEATURE: ESP
-- =====================================================================
local function createESP(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    if ESPObjects[plr] then ESPObjects[plr]:Destroy() end
    local hl = Instance.new("Highlight")
    hl.Name = "IronESP"
    hl.FillColor = Color3.fromRGB(255,0,0)
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.5
    hl.Adornee = char
    hl.Parent = char
    ESPObjects[plr] = hl
end

local function removeESP(plr)
    if ESPObjects[plr] then ESPObjects[plr]:Destroy() ESPObjects[plr] = nil end
end

local function startESP()
    for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
    Connections.ESP = Players.PlayerAdded:Connect(function(p)
        if State.ESP then createESP(p) end
    end)
end

local function stopESP()
    for p, h in pairs(ESPObjects) do if h then h:Destroy() end end
    ESPObjects = {}
    if Connections.ESP then Connections.ESP:Disconnect() Connections.ESP = nil end
end

-- =====================================================================
-- FEATURE: FREEZE
-- =====================================================================
local function setFrozen(freeze)
    local hrp = getHRP()
    if hrp then hrp.Anchored = freeze end
    State.Frozen = freeze
end

-- =====================================================================
-- FEATURE: SPEED / JUMP / TELEPORT
-- =====================================================================
local function applySpeed(v)
    local h = getHum()
    if h then h.WalkSpeed = v end
    State.WalkSpeed = v
end

local function applyJump(v)
    local h = getHum()
    if h then h.UseJumpPower = true; h.JumpPower = v end
    State.JumpPower = v
end

local function teleportTo(x, y, z)
    local hrp = getHRP()
    if hrp then hrp.CFrame = CFrame.new(x, y, z) end
end

-- =====================================================================
-- UI BUILDER
-- =====================================================================
local function createUI()
    local parent = getUIParent()
    if parent:FindFirstChild("IronAdminPanelV2") then parent.IronAdminPanelV2:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "IronAdminPanelV2"
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
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 12)

    -- Main panel
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 320, 0, 480)
    panel.Position = UDim2.new(0.5, -160, 0.5, -240)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    panel.Parent = gui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local ps = Instance.new("UIStroke", panel)
    ps.Color = Color3.fromRGB(0,220,255); ps.Thickness = 1.5; ps.Transparency = 0.4

    -- Header (title + coord readout)
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 30)
    header.Position = UDim2.new(0, 0, 0, 5)
    header.BackgroundTransparency = 1
    header.Text = "⚡ IRON ADMIN v2"
    header.TextColor3 = Color3.fromRGB(0, 220, 255)
    header.TextSize = 17
    header.Font = Enum.Font.GothamBold
    header.Parent = panel

    -- Coordinate label (live-updating)
    local coordLabel = Instance.new("TextLabel")
    coordLabel.Name = "CoordLabel"
    coordLabel.Size = UDim2.new(1, -10, 0, 24)
    coordLabel.Position = UDim2.new(0, 5, 0, 32)
    coordLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    coordLabel.Text = "X: --  Y: --  Z: --"
    coordLabel.TextColor3 = Color3.fromRGB(80, 255, 150)
    coordLabel.TextSize = 13
    coordLabel.Font = Enum.Font.Code
    coordLabel.BorderSizePixel = 0
    coordLabel.Parent = panel
    Instance.new("UICorner", coordLabel).CornerRadius = UDim.new(0, 6)
    UI.CoordLabel = coordLabel

    -- Close button
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 28, 0, 28)
    close.Position = UDim2.new(1, -34, 0, 5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255,255,255)
    close.TextSize = 13
    close.Font = Enum.Font.GothamBold
    close.BorderSizePixel = 0
    close.Parent = panel
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)

    -- Scrolling container
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -70)
    scroll.Position = UDim2.new(0, 8, 0, 62)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 220, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = panel

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    -- ========== UI HELPERS ==========
    local function makeSection(text)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -8, 0, 22)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(0, 220, 255)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = scroll
        return lbl
    end

    local function makeToggle(text, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 38)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        btn.Text = text .. ": OFF"
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamSemibold
        btn.BorderSizePixel = 0
        btn.Parent = scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
        local on = false
        btn.MouseButton1Click:Connect(function()
            on = not on
            btn.Text = text .. (on and ": ON" or ": OFF")
            btn.BackgroundColor3 = on and Color3.fromRGB(0,130,90) or Color3.fromRGB(35,35,50)
            btn.TextColor3 = on and Color3.fromRGB(255,255,255) or Color3.fromRGB(200,200,200)
            cb(on)
        end)
        return btn
    end

    -- SLIDER (draggable) — mobile-friendly
    local function makeSlider(label, minVal, maxVal, default, format, cb)
        -- label
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -8, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Text = label .. ": " .. format(default)
        lbl.TextColor3 = Color3.fromRGB(160, 160, 180)
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = scroll

        -- track
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -8, 0, 10)
        track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        track.BorderSizePixel = 0
        track.Parent = scroll
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        -- fill
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - minVal) / (maxVal - minVal), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        fill.BorderSizePixel = 0
        fill.Parent = track
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        -- knob
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.Position = UDim2.new((default - minVal) / (maxVal - minVal), -10, 0.5, -10)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.ZIndex = 2
        knob.Parent = track
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local function updateFromX(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = math.floor(minVal + rel * (maxVal - minVal) + 0.5)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -10, 0.5, -10)
            lbl.Text = label .. ": " .. format(val)
            cb(val)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateFromX(input.Position.X)
            end
        end)
        track.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
               or input.UserInputType == Enum.UserInputType.Touch) then
                updateFromX(input.Position.X)
            end
        end)
        track.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        return {track = track, fill = fill, knob = knob, label = lbl, setVal = updateFromX}
    end

    -- ========== CONTENT ==========
    makeSection("— MOVEMENT —")

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

    makeToggle("❄ FREEZE SELF", function(on) setFrozen(on) end)

    makeSection("— STATS —")

    makeSlider("Walk Speed", 16, 300, State.WalkSpeed, function(v) return tostring(v) end, function(v)
        applySpeed(v)
    end)

    makeSlider("Jump Power", 50, 500, State.JumpPower, function(v) return tostring(v) end, function(v)
        applyJump(v)
    end)

    makeSlider("Fly Speed", 10, 500, State.FlySpeed, function(v) return tostring(v) end, function(v)
        State.FlySpeed = v
    end)

    makeSection("— VISUAL —")

    makeToggle("☀ FULLBRIGHT", function(on)
        State.Fullbright = on
        if on then startFullbright() else stopFullbright() end
    end)

    makeToggle("👁 ESP PLAYERS", function(on)
        State.ESP = on
        if on then startESP() else stopESP() end
    end)

    makeToggle("🛡 GODMODE (LOCAL)", function(on)
        State.Godmode = on
        if on then startGodmode() else stopGodmode() end
    end)

    makeSection("— COORDINATES —")

    -- Copy coords button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(1, -8, 0, 34)
    copyBtn.BackgroundColor3 = Color3.fromRGB(0, 110, 160)
    copyBtn.Text = "📋 COPY CURRENT XYZ"
    copyBtn.TextColor3 = Color3.fromRGB(255,255,255)
    copyBtn.TextSize = 13
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.BorderSizePixel = 0
    copyBtn.Parent = scroll
    Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)
    copyBtn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            local str = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
            if setclipboard then setclipboard(str) end
            notify("Copied", str, 2)
        end
    end)

    -- Teleport to coords
    local tpBox = Instance.new("TextBox")
    tpBox.Size = UDim2.new(1, -8, 0, 32)
    tpBox.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
    tpBox.Text = "0, 50, 0"
    tpBox.PlaceholderText = "X, Y, Z"
    tpBox.TextColor3 = Color3.fromRGB(0, 220, 255)
    tpBox.TextSize = 13
    tpBox.Font = Enum.Font.Code
    tpBox.BorderSizePixel = 0
    tpBox.Parent = scroll
    Instance.new("UICorner", tpBox).CornerRadius = UDim.new(0, 6)

    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(1, -8, 0, 34)
    tpBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
    tpBtn.Text = "🚀 TELEPORT TO XYZ"
    tpBtn.TextColor3 = Color3.fromRGB(255,255,255)
    tpBtn.TextSize = 13
    tpBtn.Font = Enum.Font.GothamBold
    tpBtn.BorderSizePixel = 0
    tpBtn.Parent = scroll
    Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)
    tpBtn.MouseButton1Click:Connect(function()
        local t = {}
        for s in string.gmatch(tpBox.Text, "([^,]+)") do t[#t+1] = tonumber(s) end
        if #t == 3 and t[1] and t[2] and t[3] then
            teleportTo(t[1], t[2], t[3])
            notify("Iron Admin", "Teleported!", 2)
        else
            notify("Iron Admin", "Invalid XYZ", 2)
        end
    end)

    makeSection("— UTILITY —")

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -8, 0, 36)
    resetBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
    resetBtn.Text = "🔄 RESET CHARACTER"
    resetBtn.TextColor3 = Color3.fromRGB(255,255,255)
    resetBtn.TextSize = 13
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.BorderSizePixel = 0
    resetBtn.Parent = scroll
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)
    resetBtn.MouseButton1Click:Connect(function()
        local h = getHum(); if h then h.Health = 0 end
    end)

    local rejoinBtn = Instance.new("TextButton")
    rejoinBtn.Size = UDim2.new(1, -8, 0, 36)
    rejoinBtn.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
    rejoinBtn.Text = "🚪 REJOIN SERVER"
    rejoinBtn.TextColor3 = Color3.fromRGB(255,255,255)
    rejoinBtn.TextSize = 13
    rejoinBtn.Font = Enum.Font.GothamBold
    rejoinBtn.BorderSizePixel = 0
    rejoinBtn.Parent = scroll
    Instance.new("UICorner", rejoinBtn).CornerRadius = UDim.new(0, 6)
    rejoinBtn.MouseButton1Click:Connect(function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)

    local credit = Instance.new("TextLabel")
    credit.Size = UDim2.new(1, -8, 0, 18)
    credit.BackgroundTransparency = 1
    credit.Text = "Iron Gate Hub v2.0 | Client-side only"
    credit.TextColor3 = Color3.fromRGB(100,100,120)
    credit.TextSize = 10
    credit.Font = Enum.Font.Gotham
    credit.Parent = scroll

    -- Toggle handlers
    toggle.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)
    close.MouseButton1Click:Connect(function() panel.Visible = false end)

    -- ================================================================
    -- LIVE COORDINATE UPDATER
    -- ================================================================
    Connections.CoordUpdate = RunService.RenderStepped:Connect(function()
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            UI.CoordLabel.Text = string.format("X: %.1f   Y: %.1f   Z: %.1f", p.X, p.Y, p.Z)
        else
            UI.CoordLabel.Text = "X: --  Y: --  Z: --"
        end
    end)
end

-- =====================================================================
-- RESPAWN HANDLER
-- =====================================================================
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.Fly then stopFly(); startFly() end
    if State.Noclip then stopNoclip(); startNoclip() end
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
    warn("[IronAdmin v2] UI failed: " .. tostring(err))
else
    notify("Iron Admin v2", "Loaded! Tap 'ADMIN' to open.", 5)
end

print("[IronAdmin v2] Panel loaded. Live coords active.")
