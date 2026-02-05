--[[
    DELTA-X PVP FRAMEWORK [ENTERPRISE EDITION]
    Version: 3.0.0 Stable
    Architecture: Monolithic / Component-Based
    Target: Mobile Executors (DeltaX, Hydrogen, Fluxus)
    
    [PART 1: CORE KERNEL]
]]

-- 1. SANITIZATION & SETUP
if getgenv().DeltaPvP_Running then
    if getgenv().DeltaPvP_Cleanup then getgenv().DeltaPvP_Cleanup() end
end
getgenv().DeltaPvP_Running = true

local Framework = {
    Services = {},
    State = {},
    Config = {},
    UI = {},
    Events = {}
}
getgenv().DeltaFramework = Framework

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- 2. BLACKBOARD (CONFIGURATION & STATE)
-- This is the central brain. The UI writes here, the Logic reads here.
Framework.Config = {
    -- Master Switch
    Enabled = true,
    
    -- Combat
    AutoAttack = false,
    AttackRange = 15,
    Aggression = 100, -- 0-100%
    TargetPriority = "Distance", -- "Distance", "Health"
    
    -- Movement
    AutoChase = false,
    DodgeMode = "None", -- "None", "Strafe", "Jump"
    OrbitRadius = 8,
    
    -- Visuals/Debug
    DrawESP = true,
    DebugInfo = true,
    
    -- System
    TickRate = 0.05
}

Framework.State = {
    Target = nil,
    TargetDistance = 9999,
    IsAttacking = false,
    IsMoving = false,
    FPS = 60,
    Ping = 0
}

-- 3. CORE UTILITIES
local Utils = {}
function Utils:GetRoot(char)
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

function Utils:GetHum(char)
    return char and char:FindFirstChild("Humanoid")
end

function Utils:IsAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = self:GetHum(plr.Character)
    return hum and hum.Health > 0
end

-- 4. PERCEPTION ENGINE (TARGETING)
local Perception = {}

function Perception:Scan()
    local Config = Framework.Config
    local bestTarget = nil
    local bestScore = 99999
    
    local myRoot = Utils:GetRoot(LocalPlayer.Character)
    if not myRoot then return end
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Utils:IsAlive(p) then
            -- Team Check
            if p.Team ~= nil and p.Team == LocalPlayer.Team then
                -- Skip teammates
            else
                local tRoot = Utils:GetRoot(p.Character)
                if tRoot then
                    local dist = (tRoot.Position - myRoot.Position).Magnitude
                    
                    -- Scoring Logic
                    local score = dist
                    if Config.TargetPriority == "Health" then
                        score = Utils:GetHum(p.Character).Health
                    end
                    
                    -- Max Scan Range (Hardcoded cap for performance)
                    if dist < 500 then
                        if score < bestScore then
                            bestScore = score
                            bestTarget = p
                        end
                    end
                end
            end
        end
    end
    
    Framework.State.Target = bestTarget
    if bestTarget and bestTarget.Character then
        local tRoot = Utils:GetRoot(bestTarget.Character)
        Framework.State.TargetDistance = (tRoot.Position - myRoot.Position).Magnitude
    else
        Framework.State.TargetDistance = 9999
    end
end

-- 5. SCHEDULER
-- Manages the heartbeat of the framework
local Scheduler = {}
local Connections = {}

function Scheduler:Start()
    -- Logic Loop (Heartbeat)
    Connections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
        Framework.State.FPS = 1/dt
        if Framework.Config.Enabled then
            Perception:Scan()
            if Framework.Combat then Framework.Combat:Update(dt) end
            if Framework.Movement then Framework.Movement:Update(dt) end
        end
    end)
    
    -- Visual Loop (RenderStepped)
    Connections.Render = RunService.RenderStepped:Connect(function()
        if Framework.UI and Framework.UI.UpdateLabels then
            Framework.UI:UpdateLabels()
        end
    end)
end

function Scheduler:Stop()
    for _, v in pairs(Connections) do v:Disconnect() end
end

-- Expose Cleanup for re-execution
getgenv().DeltaPvP_Cleanup = function()
    Scheduler:Stop()
    if LocalPlayer.PlayerGui:FindFirstChild("DeltaPvP_GUI") then
        LocalPlayer.PlayerGui.DeltaPvP_GUI:Destroy()
    end
    getgenv().DeltaPvP_Running = false
end

Framework.Services.Scheduler = Scheduler
Framework.Services.Perception = Perception
--[[
    [PART 2: COMBAT, PREDICTION & MOVEMENT]
]]

-- 6. PREDICTION ENGINE
local Prediction = {}

function Prediction:GetPredictedPosition(target)
    if not target or not target.Character then return Vector3.zero end
    
    local root = Utils:GetRoot(target.Character)
    if not root then return Vector3.zero end
    
    -- Ping Compensation Formula
    local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
    local pingValue = tonumber(ping:match("%d+")) or 50
    local lagFactor = pingValue / 1000
    
    -- Extrapolate: CurrentPos + (Velocity * Latency)
    return root.Position + (root.Velocity * lagFactor)
end

Framework.Services.Prediction = Prediction

-- 7. COMBAT SYSTEM
local Combat = {}

function Combat:Update(dt)
    local Config = Framework.Config
    local State = Framework.State
    local Target = State.Target
    
    if not Target or not Config.Enabled then 
        State.IsAttacking = false
        return 
    end
    
    local myRoot = Utils:GetRoot(LocalPlayer.Character)
    local tRoot = Utils:GetRoot(Target.Character)
    
    if myRoot and tRoot then
        local dist = State.TargetDistance
        
        -- A. Aiming (Lock-on)
        if dist <= Config.AttackRange * 1.5 then
            local predPos = Prediction:GetPredictedPosition(Target)
            local lookCFrame = CFrame.new(myRoot.Position, Vector3.new(predPos.X, myRoot.Position.Y, predPos.Z))
            myRoot.CFrame = myRoot.CFrame:Lerp(lookCFrame, 0.5) -- Smooth lock
        end
        
        -- B. Attacking
        if Config.AutoAttack and dist <= Config.AttackRange then
            -- Legit-style click simulation
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(0,0))
            State.IsAttacking = true
        else
            State.IsAttacking = false
        end
    end
end

Framework.Services.Combat = Combat

-- 8. MOVEMENT SYSTEM
local Movement = {}

function Movement:Update(dt)
    local Config = Framework.Config
    local State = Framework.State
    local Target = State.Target
    
    if not Config.Enabled or not Config.AutoChase or not Target then 
        State.IsMoving = false
        return 
    end
    
    local myChar = LocalPlayer.Character
    local myHum = Utils:GetHum(myChar)
    local myRoot = Utils:GetRoot(myChar)
    local tRoot = Utils:GetRoot(Target.Character)
    
    if myHum and myRoot and tRoot then
        local dist = State.TargetDistance
        
        -- Movement Logic State Machine
        if dist > Config.AttackRange - 2 then
            -- Case 1: Chase
            myHum:MoveTo(tRoot.Position)
            State.IsMoving = true
            
            -- Anti-Stuck (Jump if not moving)
            if myRoot.Velocity.Magnitude < 2 then
                myHum.Jump = true
            end
            
        elseif dist < 5 then
            -- Case 2: Too Close (Backstep/Orbit)
            if Config.DodgeMode == "Strafe" then
                -- Calculate strafe vector
                local right = myRoot.CFrame.RightVector
                myHum:MoveTo(myRoot.Position + (right * 10))
            else
                -- Just stop
                myHum:MoveTo(myRoot.Position)
            end
        end
    end
end

Framework.Services.Movement = Movement

-- 9. SQUAD SYSTEM (Basic Implementation)
local Squad = {}
Squad.Members = {}

function Squad:AddMember(name)
    table.insert(self.Members, name)
end

function Squad:IsMember(player)
    for _, name in ipairs(self.Members) do
        if player.Name == name then return true end
    end
    return false
end

Framework.Services.Squad = Squad

-- Linking references for scheduler access
Framework.Combat = Combat
Framework.Movement = Movement
--[[
    [PART 3: NATIVE UI & BOOTSTRAP]
]]

-- 10. UI ENGINE (CUSTOM NATIVE LIBRARY)
local UI = {}
local Theme = {
    Bg = Color3.fromRGB(25, 25, 30),
    Sidebar = Color3.fromRGB(35, 35, 40),
    Element = Color3.fromRGB(45, 45, 50),
    Accent = Color3.fromRGB(0, 120, 215),
    Text = Color3.fromRGB(240, 240, 240),
    Green = Color3.fromRGB(46, 204, 113),
    Red = Color3.fromRGB(231, 76, 60)
}

function UI:Init()
    -- Cleanup
    if LocalPlayer.PlayerGui:FindFirstChild("DeltaPvP_GUI") then
        LocalPlayer.PlayerGui.DeltaPvP_GUI:Destroy()
    end

    -- ScreenGui
    local Screen = Instance.new("ScreenGui")
    Screen.Name = "DeltaPvP_GUI"
    Screen.Parent = LocalPlayer.PlayerGui
    Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Screen.ResetOnSpawn = false

    -- Main Window
    local Window = Instance.new("Frame")
    Window.Name = "MainWindow"
    Window.Parent = Screen
    Window.BackgroundColor3 = Theme.Bg
    Window.Position = UDim2.new(0.5, -200, 0.5, -150)
    Window.Size = UDim2.new(0, 450, 0, 320)
    Window.BorderSizePixel = 0
    Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 8)

    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Parent = Window
    TitleBar.BackgroundColor3 = Theme.Sidebar
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Parent = TitleBar
    TitleText.Text = "DELTA-PVP [FRAMEWORK]"
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 16
    TitleText.TextColor3 = Theme.Accent
    TitleText.Size = UDim2.new(1, -50, 1, 0)
    TitleText.BackgroundTransparency = 1
    
    -- Mobile Drag Logic
    local Dragging, DragStart, StartPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true
            DragStart = input.Position
            StartPos = Window.Position
        end
    end)
    
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if Dragging then
                local delta = input.Position - DragStart
                Window.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = false
        end
    end)

    -- Tab Container
    local TabHolder = Instance.new("Frame")
    TabHolder.Parent = Window
    TabHolder.BackgroundColor3 = Theme.Sidebar
    TabHolder.Position = UDim2.new(0, 10, 0, 50)
    TabHolder.Size = UDim2.new(0, 100, 1, -60)
    Instance.new("UICorner", TabHolder).CornerRadius = UDim.new(0, 6)
    
    local TabList = Instance.new("UIListLayout")
    TabList.Parent = TabHolder
    TabList.Padding = UDim.new(0, 5)
    TabList.SortOrder = Enum.SortOrder.LayoutOrder

    -- Page Container
    local PageHolder = Instance.new("Frame")
    PageHolder.Parent = Window
    PageHolder.BackgroundTransparency = 1
    PageHolder.Position = UDim2.new(0, 120, 0, 50)
    PageHolder.Size = UDim2.new(1, -130, 1, -60)

    -- Elements Storage
    self.Tabs = {}
    self.Pages = {}
    self.DebugLabels = {}

    -- UI Generators
    function self:CreateTab(name)
        -- Button
        local Btn = Instance.new("TextButton")
        Btn.Parent = TabHolder
        Btn.Text = name
        Btn.Size = UDim2.new(1, 0, 0, 35)
        Btn.BackgroundColor3 = Theme.Bg
        Btn.TextColor3 = Theme.Text
        Btn.Font = Enum.Font.GothamSemibold
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4)
        
        -- Page
        local Page = Instance.new("ScrollingFrame")
        Page.Parent = PageHolder
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.Visible = false
        Page.ScrollBarThickness = 4
        
        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = Page
        PageLayout.Padding = UDim.new(0, 8)
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        
        -- Logic
        Btn.MouseButton1Click:Connect(function()
            for _, p in pairs(self.Pages) do p.Visible = false end
            for _, b in pairs(self.Tabs) do b.TextColor3 = Theme.Text b.BackgroundColor3 = Theme.Bg end
            Page.Visible = true
            Btn.TextColor3 = Theme.Accent
            Btn.BackgroundColor3 = Theme.Element
        end)
        
        table.insert(self.Tabs, Btn)
        table.insert(self.Pages, Page)
        
        -- Select first tab automatically
        if #self.Tabs == 1 then
            Page.Visible = true
            Btn.TextColor3 = Theme.Accent
        end
        
        return Page
    end

    function self:CreateToggle(parent, text, configKey)
        local Frame = Instance.new("Frame")
        Frame.Parent = parent
        Frame.BackgroundColor3 = Theme.Element
        Frame.Size = UDim2.new(1, -5, 0, 40)
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)
        
        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = text
        Label.TextColor3 = Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.Position = UDim2.new(0, 10, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local Btn = Instance.new("TextButton")
        Btn.Parent = Frame
        Btn.Text = ""
        Btn.Size = UDim2.new(0, 40, 0, 20)
        Btn.Position = UDim2.new(1, -50, 0.5, -10)
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(1, 0)
        
        local function Update()
            local state = Framework.Config[configKey]
            Btn.BackgroundColor3 = state and Theme.Green or Theme.Red
        end
        Update()
        
        Btn.MouseButton1Click:Connect(function()
            Framework.Config[configKey] = not Framework.Config[configKey]
            Update()
        end)
    end
    
    function self:CreateSlider(parent, text, configKey, min, max)
        local Frame = Instance.new("Frame")
        Frame.Parent = parent
        Frame.BackgroundColor3 = Theme.Element
        Frame.Size = UDim2.new(1, -5, 0, 55)
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)
        
        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = text
        Label.TextColor3 = Theme.Text
        Label.Position = UDim2.new(0, 10, 0, 5)
        Label.BackgroundTransparency = 1
        Label.TextXAlignment = Enum.TextXAlignment.Left
        
        local ValLabel = Instance.new("TextLabel")
        ValLabel.Parent = Frame
        ValLabel.Text = tostring(Framework.Config[configKey])
        ValLabel.TextColor3 = Theme.Accent
        ValLabel.Position = UDim2.new(1, -40, 0, 5)
        ValLabel.BackgroundTransparency = 1
        
        local SlideBg = Instance.new("TextButton")
        SlideBg.Parent = Frame
        SlideBg.Text = ""
        SlideBg.BackgroundColor3 = Theme.Bg
        SlideBg.Size = UDim2.new(1, -20, 0, 6)
        SlideBg.Position = UDim2.new(0, 10, 0, 35)
        SlideBg.AutoButtonColor = false
        
        local Fill = Instance.new("Frame")
        Fill.Parent = SlideBg
        Fill.BackgroundColor3 = Theme.Accent
        Fill.Size = UDim2.new((Framework.Config[configKey] - min)/(max-min), 0, 1, 0)
        Fill.BorderSizePixel = 0
        
        local Dragging = false
        SlideBg.MouseButton1Down:Connect(function() Dragging = true end)
        UserInputService.InputEnded:Connect(function(input) 
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then 
                Dragging = false 
            end 
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local percent = math.clamp((input.Position.X - SlideBg.AbsolutePosition.X) / SlideBg.AbsoluteSize.X, 0, 1)
                local val = math.floor(min + (max - min) * percent)
                Framework.Config[configKey] = val
                ValLabel.Text = tostring(val)
                Fill.Size = UDim2.new(percent, 0, 1, 0)
            end
        end)
    end
    
    function self:CreateLabel(parent, text)
        local Label = Instance.new("TextLabel")
        Label.Parent = parent
        Label.Text = text
        Label.Size = UDim2.new(1, 0, 0, 25)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Theme.Text
        Label.Font = Enum.Font.Code
        Label.TextXAlignment = Enum.TextXAlignment.Left
        table.insert(self.DebugLabels, Label)
        return Label
    end

    -- POPULATE UI
    local CombatTab = self:CreateTab("Combat")
    self:CreateToggle(CombatTab, "Master Switch", "Enabled")
    self:CreateToggle(CombatTab, "Auto Attack", "AutoAttack")
    self:CreateSlider(CombatTab, "Range (Studs)", "AttackRange", 5, 50)
    self:CreateSlider(CombatTab, "Aggression %", "Aggression", 0, 100)
    
    local MoveTab = self:CreateTab("Move")
    self:CreateToggle(MoveTab, "Auto Chase", "AutoChase")
    self:CreateSlider(MoveTab, "Orbit Radius", "OrbitRadius", 5, 20)
    
    local DebugTab = self:CreateTab("Debug")
    self.StatusLabel = self:CreateLabel(DebugTab, "Status: Init")
    self.TargetLabel = self:CreateLabel(DebugTab, "Target: None")
    self.DistLabel = self:CreateLabel(DebugTab, "Dist: 0")
    self.FpsLabel = self:CreateLabel(DebugTab, "FPS: 0")
    
    Framework.UI = self
end

function UI:UpdateLabels()
    if not self.StatusLabel then return end
    
    local State = Framework.State
    local Config = Framework.Config
    
    self.StatusLabel.Text = "Active: " .. tostring(Config.Enabled)
    self.FpsLabel.Text = string.format("FPS: %d | Ping: %dms", State.FPS, State.Ping)
    
    if State.Target then
        self.TargetLabel.Text = "Target: " .. State.Target.Name
        self.DistLabel.Text = string.format("Distance: %.1f", State.TargetDistance)
        self.TargetLabel.TextColor3 = Theme.Green
    else
        self.TargetLabel.Text = "Target: None"
        self.DistLabel.Text = "Distance: N/A"
        self.TargetLabel.TextColor3 = Theme.Red
    end
end

-- 11. BOOTSTRAPPER
local function Boot()
    -- Initialize UI
    UI:Init()
    
    -- Start Scheduler
    Framework.Services.Scheduler:Start()
    
    -- Notification
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Delta-PvP Loaded";
        Text = "Framework Online. v3.0.0";
        Duration = 3;
    })
end

-- Run
Boot()
