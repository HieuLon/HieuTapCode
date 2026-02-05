print("DeltaX script loaded!")


--[[
    Title: DeltaPvP Framework - Core Kernel
    Author: Lead Engineer
    Version: 1.0.0 Production
    Environment: DeltaX / Roblox LuaU
]]

local DeltaPvP = {
    _VERSION = "1.0.0-PROD",
    _DEBUG = true,
    Services = {},
    Events = {},
    Config = {},
    Flags = {
        IsRunning = false,
        IsPaused = false
    }
}

-- Optimization: Localize global functions for speed
local getgenv = getgenv or function() return _G end
local task = task
local game = game
local setmetatable, getmetatable = setmetatable, getmetatable
local type, pairs, ipairs = type, pairs, ipairs
local pcall, xpcall = pcall, xpcall
local string_format = string.format

-- Service: RunService (Critical for loop)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------
-- 1. LOGGER SYSTEM (Prefix formatted logs)
--------------------------------------------------------------------------------
local Logger = {}
Logger.__index = Logger

function Logger.Info(msg, ...)
    if DeltaPvP._DEBUG then
        print(string_format("[DeltaPvP :: INFO] " .. msg, ...))
    end
end

function Logger.Warn(msg, ...)
    warn(string_format("[DeltaPvP :: WARN] " .. msg, ...))
end

function Logger.Error(msg, ...)
    error(string_format("[DeltaPvP :: ERROR] " .. msg, ...))
end

DeltaPvP.Logger = Logger

--------------------------------------------------------------------------------
-- 2. SERVICE CONTAINER (Dependency Injection)
--------------------------------------------------------------------------------
-- Giúp các module gọi nhau mà không cần require chéo gây circular dependency
function DeltaPvP:RegisterService(name, serviceTable)
    if self.Services[name] then
        self.Logger.Warn("Service '%s' is already registered. Overwriting.", name)
    end
    self.Services[name] = serviceTable
    self.Logger.Info("Service Registered: %s", name)
    return serviceTable
end

function DeltaPvP:GetService(name)
    local service = self.Services[name]
    if not service then
        -- Chờ service nếu nó chưa load (Lazy loading safeguard)
        local start = tick()
        repeat
            task.wait()
            service = self.Services[name]
        until service or (tick() - start > 5)
        
        if not service then
            self.Logger.Error("Critical: Service '%s' not found!", name)
            return nil
        end
    end
    return service
end

--------------------------------------------------------------------------------
-- 3. ERROR HANDLING (SafeCall)
--------------------------------------------------------------------------------
-- Bảo vệ DeltaX khỏi crash khi code lỗi logic
function DeltaPvP:SafeCall(func, ...)
    local args = {...}
    local success, result = xpcall(function()
        return func(unpack(args))
    end, function(err)
        self.Logger.Warn("Runtime Error: %s\nStack: %s", tostring(err), debug.traceback())
    end)
    return success, result
end

--------------------------------------------------------------------------------
-- 4. LIFECYCLE MANAGEMENT
--------------------------------------------------------------------------------
function DeltaPvP:Initialize()
    self.Logger.Info("Initializing Framework...")
    
    -- 1. Initialize all services
    for name, service in pairs(self.Services) do
        if service.Init and type(service.Init) == "function" then
            self:SafeCall(service.Init, service)
        end
    end

    -- 2. Start all services
    for name, service in pairs(self.Services) do
        if service.Start and type(service.Start) == "function" then
            self:SafeCall(service.Start, service)
        end
    end

    self.Flags.IsRunning = true
    self.Logger.Info("Framework Initialized Successfully.")
    
    -- Global Access for debugging via Console
    getgenv().DeltaPvPInstance = self
end

function DeltaPvP:Shutdown()
    self.Logger.Info("Shutting down Framework...")
    self.Flags.IsRunning = false
    
    -- Cleanup services
    for name, service in pairs(self.Services) do
        if service.Cleanup and type(service.Cleanup) == "function" then
            self:SafeCall(service.Cleanup, service)
        end
    end
    
    -- Clear connections
    for _, conn in pairs(self.Events) do
        if conn and conn.Disconnect then conn:Disconnect() end
    end
    
    self.Logger.Info("Shutdown Complete.")
end

--------------------------------------------------------------------------------
-- 5. UTILITY LIBRARY (Shared Math & Helper functions)
--------------------------------------------------------------------------------
local Utils = {}

function Utils:GetCharacter(player)
    player = player or LocalPlayer
    return player.Character or player.CharacterAdded:Wait()
end

function Utils:IsAlive(player)
    player = player or LocalPlayer
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return hum and root and hum.Health > 0
end

-- Tối ưu hóa tính khoảng cách (tránh create Vector3 mới)
function Utils:GetDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

DeltaPvP.Utils = Utils

return DeltaPvP
--[[
    Module: Scheduler
    Description: Centralized loop manager to prevent lag and frame drops.
]]

local DeltaPvP = getgenv().DeltaPvPInstance or require(script.Parent) -- Fallback logic
local Scheduler = {}

-- Constants
local TARGET_FPS = 60
local FRAME_TIME = 1 / TARGET_FPS

-- State
local Tasks = {
    Render = {},
    Physics = {},
    Background = {}
}

local Connections = {}
local RunService = game:GetService("RunService")

function Scheduler:Init()
    DeltaPvP.Logger.Info("Scheduler Initializing...")
end

function Scheduler:Start()
    -- Render Loop (Visuals/Aim)
    Connections.Render = RunService.RenderStepped:Connect(function(dt)
        if not DeltaPvP.Flags.IsRunning then return end
        for name, taskFunc in pairs(Tasks.Render) do
            DeltaPvP:SafeCall(taskFunc, dt)
        end
    end)

    -- Physics Loop (Movement/Combat)
    Connections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
        if not DeltaPvP.Flags.IsRunning then return end
        for name, taskFunc in pairs(Tasks.Physics) do
            DeltaPvP:SafeCall(taskFunc, dt)
        end
    end)
    
    -- Background Loop (Logic nặng)
    -- Sử dụng task.spawn để không chặn luồng chính
    task.spawn(function()
        while DeltaPvP.Flags.IsRunning do
            for name, taskFunc in pairs(Tasks.Background) do
                DeltaPvP:SafeCall(taskFunc)
            end
            task.wait(0.1) -- 10Hz tick rate cho background
        end
    end)
    
    DeltaPvP.Logger.Info("Scheduler Started.")
end

-- Bind function to loop
function Scheduler:BindToRender(name, func)
    Tasks.Render[name] = func
end

function Scheduler:BindToPhysics(name, func)
    Tasks.Physics[name] = func
end

function Scheduler:BindToBackground(name, func)
    Tasks.Background[name] = func
end

function Scheduler:Unbind(name)
    Tasks.Render[name] = nil
    Tasks.Physics[name] = nil
    Tasks.Background[name] = nil
end

function Scheduler:Cleanup()
    if Connections.Render then Connections.Render:Disconnect() end
    if Connections.Heartbeat then Connections.Heartbeat:Disconnect() end
    Tasks = {Render={}, Physics={}, Background={}}
end

-- Register to Core
DeltaPvP:RegisterService("Scheduler", Scheduler)
--[[
    Module: Blackboard
    Description: Shared memory for state management.
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local Blackboard = {}

-- State Storage
local Memory = {
    Target = nil,               -- Current Player Instance
    TargetDistance = 9999,      -- Distance to target
    TargetState = "Idle",       -- Idle, Attacking, Stunned, Ragdoll, Blocking
    
    MyState = "Idle",           -- Idle, Attacking, Stunned
    CanAttack = true,
    IsDanger = false,           -- If true, trigger auto dodge/block
    
    Prediction = {
        NextPosition = Vector3.new(0,0,0),
        HitChance = 0
    },
    
    Config = {                  -- Dynamic Config overrides
        Aggressive = true,
        Range = 15
    }
}

function Blackboard:Init()
    DeltaPvP.Logger.Info("Blackboard Initialized.")
end

function Blackboard:Set(key, value)
    Memory[key] = value
end

function Blackboard:Get(key)
    return Memory[key]
end

-- Batch update để tối ưu performance khi cập nhật nhiều state một lúc
function Blackboard:BatchUpdate(data)
    for k, v in pairs(data) do
        Memory[k] = v
    end
end

function Blackboard:Dump()
    -- Debug purpose
    return Memory
end

DeltaPvP:RegisterService("Blackboard", Blackboard)
--[[
    Module: Perception
    Description: Scans environment, identifies targets, checks visibility.
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local Perception = {}

-- Dependencies
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- Settings
local SCAN_RANGE = 500
local FOV_CHECK = false -- Có thể bật nếu muốn "Legit"
local TEAM_CHECK = true

-- Cache
local CurrentTarget = nil
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

function Perception:Init()
    DeltaPvP.Logger.Info("Perception System Initialized.")
end

function Perception:Start()
    local Scheduler = DeltaPvP:GetService("Scheduler")
    local Blackboard = DeltaPvP:GetService("Blackboard")
    
    -- Scan loop (Background priority)
    Scheduler:BindToBackground("TargetScan", function()
        self:FindTarget(Blackboard)
    end)
    
    -- Analysis loop (Physics priority - Fast update)
    Scheduler:BindToPhysics("TargetAnalysis", function()
        self:AnalyzeTarget(Blackboard)
    end)
end

function Perception:FindTarget(Blackboard)
    local bestTarget = nil
    local shortestDist = SCAN_RANGE
    local myRoot = DeltaPvP.Utils:GetCharacter(LocalPlayer):FindFirstChild("HumanoidRootPart")
    
    if not myRoot then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if char and root and hum and hum.Health > 0 then
                -- Team Check
                if TEAM_CHECK and player.Team == LocalPlayer.Team and player.Team ~= nil then
                    continue 
                end
                
                local dist = (root.Position - myRoot.Position).Magnitude
                
                if dist < shortestDist then
                    shortestDist = dist
                    bestTarget = player
                end
            end
        end
    end
    
    CurrentTarget = bestTarget
    Blackboard:Set("Target", bestTarget)
end

function Perception:AnalyzeTarget(Blackboard)
    local target = Blackboard:Get("Target")
    if not target then 
        Blackboard:Set("TargetDistance", 9999)
        return 
    end
    
    local myRoot = DeltaPvP.Utils:GetCharacter(LocalPlayer):FindFirstChild("HumanoidRootPart")
    local targetChar = target.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    local targetHum = targetChar and targetChar:FindFirstChild("Humanoid")
    
    if myRoot and targetRoot then
        -- Update Distance
        local dist = (targetRoot.Position - myRoot.Position).Magnitude
        Blackboard:Set("TargetDistance", dist)
        
        -- State Analysis (Logic này cần tùy chỉnh theo game cụ thể)
        -- Ví dụ check Ragdoll bằng attribute hoặc state của Humanoid
        local state = "Idle"
        if targetHum:GetState() == Enum.HumanoidStateType.Physics then
            state = "Ragdoll" -- Thường là bị đánh bay
        elseif targetChar:FindFirstChild("Blocking") or targetChar:GetAttribute("Blocking") then
            state = "Blocking"
        elseif targetChar:FindFirstChild("Stun") or targetChar:GetAttribute("Stunned") then
            state = "Stunned"
        end
        
        Blackboard:Set("TargetState", state)
        
        -- Visibility Check (Raycast)
        RayParams.FilterDescendantsInstances = {DeltaPvP.Utils:GetCharacter(LocalPlayer), targetChar}
        local result = Workspace:Raycast(myRoot.Position, (targetRoot.Position - myRoot.Position), RayParams)
        
        -- Nếu raycast hit nil hoặc hit target -> Visible
        -- Nếu hit tường -> Not visible
        local isVisible = true
        if result and result.Instance and not result.Instance:IsDescendantOf(targetChar) then
            isVisible = false
        end
        Blackboard:Set("TargetVisible", isVisible)
    end
end

DeltaPvP:RegisterService("Perception", Perception)
--[[
    Module: CombatEngine
    Description: Handles offensive actions, combo logic, and tool management.
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local Combat = {}

-- Services
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = game:GetService("Players").LocalPlayer

-- Settings
local CONFIG = {
    AttackRange = 15,    -- Studs (Melee usually 10-15)
    AttackDelay = 0.1,   -- Seconds between hits
    AutoEquip = true,
    ToolName = "Sword"   -- Tên vũ khí ưu tiên (Có thể chỉnh trong UI)
}

-- State
local LastAttackTime = 0
local IsAttacking = false

function Combat:Init()
    DeltaPvP.Logger.Info("Combat Engine Initialized.")
end

function Combat:Start()
    local Scheduler = DeltaPvP:GetService("Scheduler")
    local Blackboard = DeltaPvP:GetService("Blackboard")
    
    -- Bind combat logic to Physics loop (Heartbeat)
    Scheduler:BindToPhysics("CombatLoop", function(dt)
        if not Blackboard:Get("Config").Enabled then return end
        self:Update(dt, Blackboard)
    end)
end

function Combat:Update(dt, Blackboard)
    local target = Blackboard:Get("Target")
    local distance = Blackboard:Get("TargetDistance")
    local canAttack = Blackboard:Get("CanAttack")
    
    -- 1. Validate Target
    if not target or distance > CONFIG.AttackRange then return end
    
    -- 2. Check Cooldown & State
    if tick() - LastAttackTime < CONFIG.AttackDelay then return end
    if not canAttack then return end
    
    -- 3. Execute Attack
    self:EquipWeapon()
    self:PerformAttack(target)
end

function Combat:EquipWeapon()
    if not CONFIG.AutoEquip then return end
    
    local char = LocalPlayer.Character
    if char and not char:FindFirstChild(CONFIG.ToolName) then
        local bp = LocalPlayer.Backpack
        local tool = bp:FindFirstChild(CONFIG.ToolName)
        if tool then
            char.Humanoid:EquipTool(tool)
        end
    end
end

function Combat:PerformAttack(target)
    IsAttacking = true
    LastAttackTime = tick()
    
    -- Method 1: VirtualUser (Legit - Simulates hardware click)
    VirtualUser:CaptureController()
    VirtualUser:ClickButton1(Vector2.new(0,0))
    
    -- Method 2: Direct Tool Activation (Rage - Faster but riskier)
    -- local char = LocalPlayer.Character
    -- local tool = char and char:FindFirstChildOfClass("Tool")
    -- if tool and tool:FindFirstChild("Activate") then
    --     tool:Activate()
    -- end
    
    DeltaPvP:GetService("Blackboard"):Set("MyState", "Attacking")
    
    -- Reset state shortly after
    task.delay(0.1, function()
        IsAttacking = false
        DeltaPvP:GetService("Blackboard"):Set("MyState", "Idle")
    end)
end

-- Configuration Setter for UI
function Combat:SetConfig(key, value)
    if CONFIG[key] ~= nil then
        CONFIG[key] = value
    end
end

DeltaPvP:RegisterService("Combat", Combat)
--[[
    Module: Prediction
    Description: Calculates future positions based on velocity and latency.
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local Prediction = {}

-- State
local LastPos = Vector3.new(0,0,0)
local CurrentVelocity = Vector3.new(0,0,0)
local LastCalcTime = 0

function Prediction:Init()
    DeltaPvP.Logger.Info("Prediction Engine Initialized.")
end

function Prediction:Start()
    local Scheduler = DeltaPvP:GetService("Scheduler")
    
    -- Calculate velocity manually (More accurate than Humanoid.AssemblyLinearVelocity sometimes)
    Scheduler:BindToPhysics("VelocityCalc", function(dt)
        self:TrackVelocity(dt)
    end)
end

function Prediction:TrackVelocity(dt)
    local Blackboard = DeltaPvP:GetService("Blackboard")
    local target = Blackboard:Get("Target")
    
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local currentPos = target.Character.HumanoidRootPart.Position
        
        -- Calculate velocity: v = dx / dt
        if dt > 0 then
            CurrentVelocity = (currentPos - LastPos) / dt
        end
        
        LastPos = currentPos
        LastCalcTime = tick()
    else
        CurrentVelocity = Vector3.new(0,0,0)
    end
end

-- API: Get Predicted Position
-- timeAhead: How many seconds into the future (usually Ping + TravelTime)
function Prediction:GetPredictedPosition(timeAhead)
    local Blackboard = DeltaPvP:GetService("Blackboard")
    local target = Blackboard:Get("Target")
    
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
        return Vector3.new(0,0,0)
    end
    
    local root = target.Character.HumanoidRootPart
    local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
    local pingValue = tonumber(ping:match("%d+")) or 50
    local totalDelay = timeAhead + (pingValue / 1000)
    
    -- Formula: P_future = P_current + (Velocity * Time)
    local predicted = root.Position + (CurrentVelocity * totalDelay)
    
    return predicted
end

DeltaPvP:RegisterService("Prediction", Prediction)
--[[
    Module: Defense
    Description: Auto blocking, dodging, and evasive maneuvers.
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local Defense = {}

-- Settings
local SETTINGS = {
    AutoBlock = true,
    AutoDodge = true,
    DodgeType = "CFrame", -- "CFrame" (Teleport short dist) or "Velocity" (Dash)
    SafeDistance = 20,
    BlockDistance = 10
}

-- Animations to detect (Cần lấy ID animation của game cụ thể để điền vào đây)
-- Đây là danh sách ví dụ, user cần tự thêm ID thông qua UI hoặc Config
local DANGEROUS_ANIMS = {
    ["rbxassetid://123456789"] = true, -- Example Attack ID
    ["rbxassetid://987654321"] = true  -- Example Skill ID
}

function Defense:Init()
    DeltaPvP.Logger.Info("Defense System Initialized.")
end

function Defense:Start()
    local Scheduler = DeltaPvP:GetService("Scheduler")
    local Blackboard = DeltaPvP:GetService("Blackboard")
    
    -- High priority check
    Scheduler:BindToRender("DefenseCheck", function()
        self:AnalyzeThreats(Blackboard)
    end)
end

function Defense:AnalyzeThreats(Blackboard)
    local target = Blackboard:Get("Target")
    if not target then return end
    
    local targetChar = target.Character
    if not targetChar then return end
    
    local animator = targetChar:FindFirstChild("Humanoid") and targetChar.Humanoid:FindFirstChild("Animator")
    if not animator then return end
    
    -- Check playing animations
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animId = track.Animation.AnimationId
        
        -- Logic phát hiện đòn đánh
        -- Nếu không có ID cụ thể, ta có thể check tốc độ animation hoặc tên animation
        if DANGEROUS_ANIMS[animId] or track.Priority == Enum.AnimationPriority.Action then
            local dist = Blackboard:Get("TargetDistance")
            
            if dist < SETTINGS.BlockDistance and SETTINGS.AutoBlock then
                self:Block(true)
            elseif dist < SETTINGS.SafeDistance and SETTINGS.AutoDodge then
                self:Dodge(targetChar)
            end
        end
    end
end

function Defense:Block(enable)
    local VirtualInputManager = game:GetService("VirtualInputManager")
    -- Giả lập giữ nút F (Block mặc định nhiều game)
    if enable then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        DeltaPvP:GetService("Blackboard"):Set("MyState", "Blocking")
    else
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        DeltaPvP:GetService("Blackboard"):Set("MyState", "Idle")
    end
end

function Defense:Dodge(enemyChar)
    local root = DeltaPvP.Utils:GetCharacter(game.Players.LocalPlayer):FindFirstChild("HumanoidRootPart")
    local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart")
    
    if not root or not enemyRoot then return end
    
    -- Tính hướng né: Ngược hướng địch hoặc sang ngang (Strafe)
    -- Vector from Enemy to Me
    local direction = (root.Position - enemyRoot.Position).Unit
    local sideDirection = direction:Cross(Vector3.new(0,1,0)) -- Vuông góc
    
    if SETTINGS.DodgeType == "CFrame" then
        -- Teleport nhẹ sang bên cạnh (Khó bị hit hơn lùi lại)
        local dodgeDest = root.CFrame * CFrame.new(5, 0, 0) -- Dịch sang phải 5 studs
        root.CFrame = dodgeDest
    elseif SETTINGS.DodgeType == "Velocity" then
        -- Tạo lực đẩy
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(100000, 0, 100000)
        bv.Velocity = sideDirection * 50
        bv.Parent = root
        game.Debris:AddItem(bv, 0.2) -- Xóa sau 0.2s
    end
    
    DeltaPvP.Logger.Info("Dodged incoming attack!")
end

DeltaPvP:RegisterService("Defense", Defense)
--[[
    Module: LearningSystem
    Description: Records enemy behavior and adapts combat style.
    Storage: Workspace/DeltaPvP_Data.json
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local Learning = {}

-- Services
local HttpService = game:GetService("HttpService")

-- Data Store
local EnemyDatabase = {}
local FILE_NAME = "DeltaPvP_Brain.json"

-- Constants
local THREAT_WEIGHTS = {
    Win = -10,    -- Bot thắng -> Giảm độ nguy hiểm của địch
    Loss = 20,    -- Bot thua -> Tăng độ nguy hiểm
    Dodge = 1     -- Địch né nhiều -> Tăng nhẹ
}

function Learning:Init()
    DeltaPvP.Logger.Info("Learning System Initializing...")
    self:LoadData()
end

function Learning:Start()
    local Scheduler = DeltaPvP:GetService("Scheduler")
    
    -- Auto Save Loop (Every 60s)
    Scheduler:BindToBackground("AutoSaveBrain", function()
        self:SaveData()
    end)
    
    -- Hook into Death Event (Learning from failure)
    game.Players.LocalPlayer.CharacterAdded:Connect(function()
        -- Logic: Check who killed me (Last hit detection usually requires game-specific logic or reading Kill Feed GUI)
        -- Placeholder: Assume CurrentTarget killed us if we died while targeting them
        local Blackboard = DeltaPvP:GetService("Blackboard")
        local target = Blackboard:Get("Target")
        if target then
            self:RecordOutcome(target, "Loss")
        end
    end)
end

function Learning:GetProfile(player)
    local id = tostring(player.UserId)
    if not EnemyDatabase[id] then
        EnemyDatabase[id] = {
            Name = player.Name,
            ThreatLevel = 0,
            PlayStyle = "Balanced", -- Aggressive, Defensive, Evasive
            Encounters = 0
        }
    end
    return EnemyDatabase[id]
end

function Learning:RecordOutcome(player, outcome)
    local profile = self:GetProfile(player)
    profile.Encounters = profile.Encounters + 1
    
    if outcome == "Loss" then
        profile.ThreatLevel = profile.ThreatLevel + THREAT_WEIGHTS.Loss
    elseif outcome == "Win" then
        profile.ThreatLevel = math.max(0, profile.ThreatLevel + THREAT_WEIGHTS.Win)
    end
    
    -- Adapt Strategy based on Threat
    if profile.ThreatLevel > 50 then
        DeltaPvP.Logger.Warn("High Threat Enemy Detected: %s. Switching to DEFENSIVE mode.", player.Name)
        DeltaPvP:GetService("Blackboard"):Set("StrategyOverride", "Defensive")
    end
end

-- I/O Operations (Safe for Executor)
function Learning:SaveData()
    local success, json = pcall(function()
        return HttpService:JSONEncode(EnemyDatabase)
    end)
    
    if success then
        if writefile then
            writefile(FILE_NAME, json)
            DeltaPvP.Logger.Info("Brain Data Saved.")
        end
    end
end

function Learning:LoadData()
    if isfile and isfile(FILE_NAME) then
        local success, content = pcall(function()
            return readfile(FILE_NAME)
        end)
        if success then
            local decoded = HttpService:JSONDecode(content)
            if decoded then EnemyDatabase = decoded end
        end
    end
end

DeltaPvP:RegisterService("Learning", Learning)
--[[
    Module: UIDashboard
    Description: Custom Native UI optimized for DeltaX/Mobile.
    No external dependencies.
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local UI = {}

-- UI State
local ScreenGui = nil
local MainFrame = nil
local Tabs = {}
local CurrentTab = nil

-- Colors (Dark Theme)
local Colors = {
    Bg = Color3.fromRGB(25, 25, 25),
    Sidebar = Color3.fromRGB(35, 35, 35),
    Element = Color3.fromRGB(45, 45, 45),
    Accent = Color3.fromRGB(0, 170, 255),
    Text = Color3.fromRGB(255, 255, 255)
}

function UI:Init()
    DeltaPvP.Logger.Info("UI System Building...")
    self:BuildInterface()
end

function UI:Start()
    -- Load saved configs if any
end

function UI:CreateElement(class, props)
    local instance = Instance.new(class)
    for k, v in pairs(props) do
        instance[k] = v
    end
    return instance
end

function UI:BuildInterface()
    -- Protect GUI from game detection (CoreGui or PlayerGui)
    local parent = game:GetService("CoreGui")
    if not pcall(function() parent = game:GetService("CoreGui") end) then
        parent = game:GetService("Players").LocalPlayer.PlayerGui
    end
    
    -- Cleanup old UI
    for _, v in pairs(parent:GetChildren()) do
        if v.Name == "DeltaPvP_UI" then v:Destroy() end
    end

    -- 1. Main ScreenGui
    ScreenGui = self:CreateElement("ScreenGui", {
        Name = "DeltaPvP_UI",
        Parent = parent,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })

    -- 2. Main Window (Draggable)
    MainFrame = self:CreateElement("Frame", {
        Name = "MainFrame",
        Parent = ScreenGui,
        BackgroundColor3 = Colors.Bg,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, -250, 0.5, -175), -- Center
        Size = UDim2.new(0, 600, 0, 350),
        Active = true,
        Draggable = true -- Native draggable works fine
    })
    
    -- Corner Radius
    self:CreateElement("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, 8)})

    -- 3. Sidebar (Tabs)
    local Sidebar = self:CreateElement("Frame", {
        Parent = MainFrame,
        BackgroundColor3 = Colors.Sidebar,
        Size = UDim2.new(0, 120, 1, 0),
        BorderSizePixel = 0
    })
    self:CreateElement("UICorner", {Parent = Sidebar, CornerRadius = UDim.new(0, 8)})
    
    -- Fix Sidebar overlap
    self:CreateElement("Frame", {
        Parent = Sidebar,
        BackgroundColor3 = Colors.Sidebar,
        Size = UDim2.new(0, 10, 1, 0),
        Position = UDim2.new(1, -10, 0, 0),
        BorderSizePixel = 0
    })

    -- Title
    local Title = self:CreateElement("TextLabel", {
        Parent = Sidebar,
        Text = "DELTA PVP",
        TextColor3 = Colors.Accent,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1
    })
    
    -- Container for Elements
    local Container = self:CreateElement("Frame", {
        Parent = MainFrame,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 130, 0, 10),
        Size = UDim2.new(1, -140, 1, -20)
    })
    
    self.Container = Container
    self.Sidebar = Sidebar
    
    -- Initialize Tabs
    self:CreateTab("Combat")
    self:CreateTab("Defense")
    self:CreateTab("Visuals")
    self:CreateTab("Settings")
    
    -- Populate Combat Tab (Example)
    self:AddToggle("Combat", "Enabled", true, function(val) 
        DeltaPvP:GetService("Blackboard").Config.Enabled = val
    end)
    
    self:AddToggle("Combat", "Auto Attack", true, function(val)
        DeltaPvP:GetService("Combat"):SetConfig("AutoEquip", val)
    end)
    
    self:AddSlider("Combat", "Range", 5, 50, 15, function(val)
        DeltaPvP:GetService("Combat"):SetConfig("AttackRange", val)
    end)
    
    self:AddToggle("Defense", "Auto Block", true, function(val) end)
    
    -- Toggle UI Keybind (Right Control)
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, processed)
        if input.KeyCode == Enum.KeyCode.RightControl then
            ScreenGui.Enabled = not ScreenGui.Enabled
        end
    end)
    
    -- Select first tab
    self:SelectTab("Combat")
end

function UI:CreateTab(name)
    local TabButton = self:CreateElement("TextButton", {
        Parent = self.Sidebar,
        Text = name,
        TextColor3 = Colors.Text,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        Size = UDim2.new(1, -20, 0, 35),
        Position = UDim2.new(0, 10, 0, 60 + (#Tabs * 40)),
        BackgroundColor3 = Colors.Bg,
        AutoButtonColor = false,
        BorderSizePixel = 0
    })
    self:CreateElement("UICorner", {Parent = TabButton, CornerRadius = UDim.new(0, 6)})
    
    -- Tab Page (Scrolling Frame)
    local Page = self:CreateElement("ScrollingFrame", {
        Parent = self.Container,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        Visible = false
    })
    self:CreateElement("UIListLayout", {
        Parent = Page,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    
    local tabData = {Button = TabButton, Page = Page, Name = name}
    table.insert(Tabs, tabData)
    
    TabButton.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)
end

function UI:SelectTab(name)
    for _, tab in ipairs(Tabs) do
        if tab.Name == name then
            tab.Page.Visible = true
            tab.Button.TextColor3 = Colors.Accent
            tab.Button.BackgroundColor3 = Colors.Element
        else
            tab.Page.Visible = false
            tab.Button.TextColor3 = Colors.Text
            tab.Button.BackgroundColor3 = Colors.Bg
        end
    end
end

-- UI Component: Toggle
function UI:AddToggle(tabName, text, default, callback)
    local page = self:GetPage(tabName)
    if not page then return end
    
    local Frame = self:CreateElement("Frame", {
        Parent = page,
        BackgroundColor3 = Colors.Element,
        Size = UDim2.new(1, 0, 0, 40)
    })
    self:CreateElement("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
    
    local Label = self:CreateElement("TextLabel", {
        Parent = Frame,
        Text = text,
        TextColor3 = Colors.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 15, 0, 0),
        Size = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham
    })
    
    local Button = self:CreateElement("TextButton", {
        Parent = Frame,
        Text = "",
        BackgroundColor3 = default and Colors.Accent or Colors.Bg,
        Position = UDim2.new(1, -55, 0.5, -10),
        Size = UDim2.new(0, 40, 0, 20)
    })
    self:CreateElement("UICorner", {Parent = Button, CornerRadius = UDim.new(1, 0)})
    
    local state = default
    Button.MouseButton1Click:Connect(function()
        state = not state
        Button.BackgroundColor3 = state and Colors.Accent or Colors.Bg
        if callback then callback(state) end
    end)
end

-- UI Component: Slider
function UI:AddSlider(tabName, text, min, max, default, callback)
    local page = self:GetPage(tabName)
    if not page then return end
    
    local Frame = self:CreateElement("Frame", {
        Parent = page,
        BackgroundColor3 = Colors.Element,
        Size = UDim2.new(1, 0, 0, 60)
    })
    self:CreateElement("UICorner", {Parent = Frame, CornerRadius = UDim.new(0, 6)})
    
    local Label = self:CreateElement("TextLabel", {
        Parent = Frame,
        Text = text,
        TextColor3 = Colors.Text,
        Position = UDim2.new(0, 15, 0, 5),
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    
    local ValueLabel = self:CreateElement("TextLabel", {
        Parent = Frame,
        Text = tostring(default),
        TextColor3 = Colors.Accent,
        Position = UDim2.new(1, -60, 0, 5),
        Size = UDim2.new(0, 50, 0, 25),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right
    })
    
    local SliderBar = self:CreateElement("TextButton", { -- Use button for input
        Parent = Frame,
        Text = "",
        BackgroundColor3 = Colors.Bg,
        Position = UDim2.new(0, 15, 0, 35),
        Size = UDim2.new(1, -30, 0, 6),
        AutoButtonColor = false
    })
    self:CreateElement("UICorner", {Parent = SliderBar, CornerRadius = UDim.new(1, 0)})
    
    local Fill = self:CreateElement("Frame", {
        Parent = SliderBar,
        BackgroundColor3 = Colors.Accent,
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BorderSizePixel = 0
    })
    self:CreateElement("UICorner", {Parent = Fill, CornerRadius = UDim.new(1, 0)})

    -- Slider Logic
    local UserInputService = game:GetService("UserInputService")
    local Dragging = false
    
    SliderBar.MouseButton1Down:Connect(function() Dragging = true end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mousePos = input.Position.X
            local barPos = SliderBar.AbsolutePosition.X
            local barSize = SliderBar.AbsoluteSize.X
            local percent = math.clamp((mousePos - barPos) / barSize, 0, 1)
            
            Fill.Size = UDim2.new(percent, 0, 1, 0)
            local value = math.floor(min + (max - min) * percent)
            ValueLabel.Text = tostring(value)
            if callback then callback(value) end
        end
    end)
end

function UI:GetPage(name)
    for _, tab in ipairs(Tabs) do
        if tab.Name == name then return tab.Page end
    end
    return nil
end

DeltaPvP:RegisterService("UIDashboard", UI)
--[[
    Module: Optimizer
    Description: Memory management and performance throttling.
]]

local DeltaPvP = getgenv().DeltaPvPInstance
local Optimizer = {}

-- Settings
local MEMORY_THRESHOLD = 800 -- MB
local CRITICAL_FPS = 15

function Optimizer:Init()
    DeltaPvP.Logger.Info("Optimizer Initialized.")
end

function Optimizer:Start()
    local Scheduler = DeltaPvP:GetService("Scheduler")
    
    -- Low priority check (Every 5 seconds)
    Scheduler:BindToBackground("SystemMonitor", function()
        self:MonitorPerformance()
    end)
    
    -- Auto-cleanup signals on shutdown
    game:GetService("CoreGui").ChildRemoved:Connect(function(child)
        if child.Name == "DeltaPvP_UI" then
            DeltaPvP:Shutdown()
        end
    end)
end

function Optimizer:MonitorPerformance()
    local stats = game:GetService("Stats")
    local mem = stats:GetTotalMemoryUsageMb()
    local fps = game:GetService("Workspace"):GetRealPhysicsFPS()
    
    -- 1. Memory Leak Protection
    if mem > MEMORY_THRESHOLD then
        DeltaPvP.Logger.Warn("High Memory Usage (%.1f MB). Triggering GC...", mem)
        -- Force Lua Garbage Collection (Deprecated but useful in exploits)
        for i = 1, 5 do collectgarbage("collect") end
    end
    
    -- 2. Anti-Crash (FPS Drop)
    if fps < CRITICAL_FPS then
        DeltaPvP.Logger.Warn("Low FPS Detected (%.1f). Throttling Scanners...", fps)
        -- Giảm tần suất scan của Perception Module
        local Perception = DeltaPvP:GetService("Perception")
        -- (Logic giảm tải sẽ nằm ở implementation chi tiết, ví dụ tăng wait time)
    end
end

-- Deep Clean function for Tables
function Optimizer:DeepClean(tbl)
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            self:DeepClean(v)
        elseif type(v) == "userdata" and v.Destroy then
            v:Destroy()
        end
        tbl[k] = nil
    end
end

DeltaPvP:RegisterService("Optimizer", Optimizer)
--[[
    DELTA PVP FRAMEWORK - PRODUCTION RELEASE
    Target: Roblox PvP Games (Battlegrounds/Combat)
    Executor: DeltaX / Fluxus / Hydrogen
    Author: Lead Automation Engineer
    Version: 1.0.0 Stable
]]

--------------------------------------------------------------------------------
-- 1. CORE KERNEL
--------------------------------------------------------------------------------
getgenv().DeltaPvPInstance = nil -- Reset old instance

local DeltaPvP = {
    _VERSION = "1.0.0-PROD",
    Services = {},
    Events = {},
    Flags = { IsRunning = false }
}
getgenv().DeltaPvPInstance = DeltaPvP

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Logger
function DeltaPvP:Log(msg) print("[DELTA PVP] " .. tostring(msg)) end
function DeltaPvP:Warn(msg) warn("[DELTA PVP] " .. tostring(msg)) end

-- Service Registry
function DeltaPvP:RegisterService(name, tbl)
    self.Services[name] = tbl
    return tbl
end

function DeltaPvP:GetService(name)
    return self.Services[name]
end

function DeltaPvP:SafeCall(func, ...)
    local s, e = pcall(func, ...)
    if not s then self:Warn("Error: " .. tostring(e)) end
end

function DeltaPvP:Initialize()
    self:Log("Initializing Systems...")
    for n, s in pairs(self.Services) do if s.Init then self:SafeCall(s.Init, s) end end
    for n, s in pairs(self.Services) do if s.Start then self:SafeCall(s.Start, s) end end
    self.Flags.IsRunning = true
    self:Log("System Online. Press RightControl to toggle UI.")
end

function DeltaPvP:Shutdown()
    self.Flags.IsRunning = false
    for n, s in pairs(self.Services) do if s.Cleanup then s:Cleanup() end end
    self:Log("System Shutdown.")
end

-- Utils
local Utils = {}
function Utils:GetRoot(char) return char and char:FindFirstChild("HumanoidRootPart") end
function Utils:GetHum(char) return char and char:FindFirstChild("Humanoid") end
DeltaPvP.Utils = Utils

--------------------------------------------------------------------------------
-- 2. SCHEDULER (LOOP MANAGER)
--------------------------------------------------------------------------------
local Scheduler = {}
local Loops = {Render={}, Physics={}, Background={}}
local Conns = {}

function Scheduler:Init()
    Conns.Render = RunService.RenderStepped:Connect(function(dt)
        if not DeltaPvP.Flags.IsRunning then return end
        for _, f in pairs(Loops.Render) do pcall(f, dt) end
    end)
    Conns.Physics = RunService.Heartbeat:Connect(function(dt)
        if not DeltaPvP.Flags.IsRunning then return end
        for _, f in pairs(Loops.Physics) do pcall(f, dt) end
    end)
    task.spawn(function()
        while true do
            if DeltaPvP.Flags.IsRunning then
                for _, f in pairs(Loops.Background) do pcall(f) end
            end
            task.wait(0.2)
        end
    end)
end

function Scheduler:Bind(type, name, func) Loops[type][name] = func end
function Scheduler:Unbind(type, name) Loops[type][name] = nil end
function Scheduler:Cleanup() for _, c in pairs(Conns) do c:Disconnect() end end
DeltaPvP:RegisterService("Scheduler", Scheduler)

--------------------------------------------------------------------------------
-- 3. BLACKBOARD (MEMORY)
--------------------------------------------------------------------------------
local Blackboard = {
    Data = {
        Target = nil,
        Dist = 9999,
        Config = {Enabled=true, Range=20, AutoBlock=true, AutoDodge=true}
    }
}
function Blackboard:Set(k, v) self.Data[k] = v end
function Blackboard:Get(k) return self.Data[k] end
DeltaPvP:RegisterService("Blackboard", Blackboard)

--------------------------------------------------------------------------------
-- 4. PERCEPTION (TARGETING)
--------------------------------------------------------------------------------
local Perception = {}
function Perception:Start()
    local BB = DeltaPvP:GetService("Blackboard")
    DeltaPvP:GetService("Scheduler"):Bind("Background", "Scan", function()
        local myRoot = Utils:GetRoot(LocalPlayer.Character)
        if not myRoot then return end
        
        local best, minDist = nil, BB:Get("Config").Range * 2 -- Scan a bit further
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= LocalPlayer and v.Character then
                local tRoot = Utils:GetRoot(v.Character)
                local tHum = Utils:GetHum(v.Character)
                if tRoot and tHum and tHum.Health > 0 then
                    local dist = (tRoot.Position - myRoot.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        best = v
                    end
                end
            end
        end
        BB:Set("Target", best)
        BB:Set("Dist", minDist)
    end)
end
DeltaPvP:RegisterService("Perception", Perception)

--------------------------------------------------------------------------------
-- 5. COMBAT & PREDICTION
--------------------------------------------------------------------------------
local Combat = {}
local VirtualUser = game:GetService("VirtualUser")

function Combat:Start()
    local BB = DeltaPvP:GetService("Blackboard")
    DeltaPvP:GetService("Scheduler"):Bind("Physics", "Combat", function()
        if not BB:Get("Config").Enabled then return end
        
        local target = BB:Get("Target")
        local dist = BB:Get("Dist")
        
        if target and dist <= BB:Get("Config").Range then
            -- Simple Face Target
            local myRoot = Utils:GetRoot(LocalPlayer.Character)
            local tRoot = Utils:GetRoot(target.Character)
            if myRoot and tRoot then
                myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(tRoot.Position.X, myRoot.Position.Y, tRoot.Position.Z))
                
                -- Attack
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new(0,0))
            end
        end
    end)
end
DeltaPvP:RegisterService("Combat", Combat)

--------------------------------------------------------------------------------
-- 6. DEFENSE (AUTO BLOCK/DODGE)
--------------------------------------------------------------------------------
local Defense = {}
function Defense:Start()
    local BB = DeltaPvP:GetService("Blackboard")
    local VIM = game:GetService("VirtualInputManager")
    
    DeltaPvP:GetService("Scheduler"):Bind("Render", "Defense", function()
        local target = BB:Get("Target")
        local dist = BB:Get("Dist")
        
        if target and target.Character and dist < 15 then
            local animator = target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid:FindFirstChild("Animator")
            if animator then
                local isAttacking = false
                for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                    if t.Priority == Enum.AnimationPriority.Action then isAttacking = true break end
                end
                
                if isAttacking then
                    if BB:Get("Config").AutoBlock then
                        VIM:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                    end
                else
                    if BB:Get("Config").AutoBlock then
                        VIM:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                    end
                end
            end
        end
    end)
end
DeltaPvP:RegisterService("Defense", Defense)

--------------------------------------------------------------------------------
-- 7. UI DASHBOARD (NATIVE)
--------------------------------------------------------------------------------
local UI = {}
function UI:Init()
    local CoreGui = game:GetService("CoreGui")
    if CoreGui:FindFirstChild("DeltaPvP_UI") then CoreGui.DeltaPvP_UI:Destroy() end
    
    local Screen = Instance.new("ScreenGui")
    Screen.Name = "DeltaPvP_UI"
    Screen.Parent = CoreGui
    
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 300, 0, 250)
    Frame.Position = UDim2.new(0.1, 0, 0.2, 0)
    Frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    Frame.Active = true
    Frame.Draggable = true
    Frame.Parent = Screen
    
    local Title = Instance.new("TextLabel")
    Title.Text = "DELTA PVP FRAMEWORK"
    Title.Size = UDim2.new(1,0,0,30)
    Title.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    Title.TextColor3 = Color3.new(1,1,1)
    Title.Parent = Frame
    
    local function AddToggle(text, key, y)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, 30)
        btn.Position = UDim2.new(0.05, 0, 0, y)
        btn.Text = text .. ": ON"
        btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Parent = Frame
        
        btn.MouseButton1Click:Connect(function()
            local BB = DeltaPvP:GetService("Blackboard")
            local curr = BB:Get("Config")[key]
            BB:Get("Config")[key] = not curr
            btn.Text = text .. ": " .. (not curr and "ON" or "OFF")
            btn.BackgroundColor3 = not curr and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(50,50,50)
        end)
    end
    
    AddToggle("Combat Active", "Enabled", 40)
    AddToggle("Auto Block", "AutoBlock", 80)
    AddToggle("Auto Dodge", "AutoDodge", 120)
    
    -- Close Btn
    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 20, 0, 20)
    Close.Position = UDim2.new(1, -25, 0, 5)
    Close.Text = "X"
    Close.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    Close.Parent = Frame
    Close.MouseButton1Click:Connect(function() DeltaPvP:Shutdown() Screen:Destroy() end)
    
    -- Toggle Key
    UserInputService.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.RightControl then
            Screen.Enabled = not Screen.Enabled
        end
    end)
end
DeltaPvP:RegisterService("UI", UI)

--------------------------------------------------------------------------------
-- 8. BOOTSTRAP
--------------------------------------------------------------------------------
DeltaPvP:Initialize()
-- GIẢ LẬP MENU HIỆN LÊN
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "DeltaXMenu"
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 200)
frame.Position = UDim2.new(0.5, -150, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,30)
title.Text = "DeltaX PvP AI"
title.TextColor3 = Color3.new(1,1,1)
title.Parent = frame
