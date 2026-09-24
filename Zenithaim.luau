repeat task.wait() until game:IsLoaded()
local plr = game:GetService("Players").LocalPlayer
local WS, RunService, ReplicatedStorage, Players, UserInputService = workspace, game:GetService("RunService"), game:GetService("ReplicatedStorage"), game:GetService("Players"), game:GetService("UserInputService")

local Net = ReplicatedStorage:WaitForChild("Modules", 9) and ReplicatedStorage.Modules:WaitForChild("Net", 9)
local Register_Attack = Net and Net:FindFirstChild("RE/RegisterAttack")
local Register_Hit = Net and Net:FindFirstChild("RE/RegisterHit")

-- Fast Attack Implementation matching structural file specs
local FastAttack = {}
local FastAttack_enemies = workspace:FindFirstChild("Enemies")
local FastAttack_characters = workspace:FindFirstChild("Characters")
local FastAttack_arms = { "RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm", "RightHand", "LeftHand" }
local FastAttack_sendHits
local FastAttack_combatThread

pcall(function()
    FastAttack_combatThread = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Flags")).COMBAT_REMOTE_THREAD or false
end)

local function FastAttack_GetSendHits()
    if not getsenv then return nil end
    local playerScripts = plr:FindFirstChild("PlayerScripts")
    if not playerScripts then return nil end
    for _, s in ipairs(playerScripts:GetChildren()) do
        if s:IsA("LocalScript") then
            local ok, env = pcall(getsenv, s)
            if ok and env and env._G and env._G.SendHitsToServer then
                return env._G.SendHitsToServer
            end
        end
    end
    return nil
end

local function FastAttack_EnsureSendHits()
    if getsenv and FastAttack_sendHits == nil then
        FastAttack_sendHits = FastAttack_GetSendHits()
    end
end

function FastAttack:SuperFastAttack()
    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local tool
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then
            tool = c
            break
        end
    end
    if not tool then return end
    local hitData = {}
    local primaryPart
    for _, list in ipairs({ FastAttack_enemies, FastAttack_characters }) do
        if list then
            for _, e in list:GetChildren() do
                if e ~= char and not e:GetAttribute("IsBoat") then
                    local ehum = e:FindFirstChild("Humanoid")
                    local ebody = e:FindFirstChild("Head") or e.PrimaryPart
                    if ehum and ehum.Health > 0 and ebody and (ebody.Position - root.Position).Magnitude <= 80 then
                        local part = e:FindFirstChild(FastAttack_arms[math.random(#FastAttack_arms)]) or e.PrimaryPart
                        if part then
                            table.insert(hitData, { e, part })
                            primaryPart = part
                        end
                    end
                end
            end
        end
    end
    if #hitData == 0 or not primaryPart then return end
    local lcr = tool:FindFirstChild("LeftClickRemote")
    if lcr then
        pcall(function()
            lcr:FireServer((primaryPart.Position - root.Position).Unit, 1)
        end)
    end
    if Register_Attack then Register_Attack:FireServer(0) end
    if FastAttack_combatThread then
        FastAttack_EnsureSendHits()
        if FastAttack_sendHits then
            FastAttack_sendHits(primaryPart, hitData)
        elseif Register_Hit then
            Register_Hit:FireServer(primaryPart, hitData)
        end
    elseif Register_Hit then
        Register_Hit:FireServer(primaryPart, hitData)
    end
end

-- Load Fluent UI Library configured with Glass / Acrylic Setup
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/huyyeuemhihi/Fluent/refs/heads/main/Fluentvip.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Zenith Hub || Aimbot",
    SubTitle = "Glass Edition • v1.0",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, -- Glass Background Effect
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Multi-Tabs Setup
local CombatTab = Window:AddTab({ Title = "Combat / Aimbot", Icon = "rbxassetid://125736686613291" })
local FarmTab = Window:AddTab({ Title = "Farming Tab", Icon = "rbxassetid://127561653320876" })
local SettingsTab = Window:AddTab({ Title = "UI Settings", Icon = "rbxassetid://10723424179" })

-- Player Targeting List
local PlayerList = {}
for _, v in next, Players:GetPlayers() do
    if v.Name ~= plr.Name then
        table.insert(PlayerList, v.Name)
    end
end

CombatTab:AddSection("Aimbot & Silent Aim Controls")

local TargetSelect = CombatTab:AddDropdown("SelectTargetDropdown", {
    Title = "Select Target",
    Values = PlayerList,
    Default = "",
    Callback = function(v)
        getgenv().ZenithTarget = v
    end
})

CombatTab:AddButton({
    Title = "Refresh Player List",
    Callback = function()
        local newList = {}
        for _, v in next, Players:GetPlayers() do
            if v.Name ~= plr.Name then
                table.insert(newList, v.Name)
            end
        end
        TargetSelect:SetValues(newList)
    end
})

CombatTab:AddToggle("AimbotToggle", {
    Title = "Camera Aimbot",
    Description = "Locks camera directly onto selected target",
    Default = false,
    Callback = function(v)
        getgenv().ZenithAimbot = v
    end
})

CombatTab:AddToggle("SilentAimToggle", {
    Title = "Silent Aim Hook",
    Description = "Redirects hits/attacks toward target direction silently",
    Default = false,
    Callback = function(v)
        getgenv().ZenithSilentAim = v
    end
})

-- Fast Attack Integration
FarmTab:AddSection("Fast Attack Engine")
FarmTab:AddToggle("FastAttackToggle", {
    Title = "Super Fast Attack",
    Description = "Executes rapid-fire combat handlers safely",
    Default = false,
    Callback = function(v)
        getgenv().ZenithFastAttack = v
    end
})

-- UI Settings / Minimize Helper section
SettingsTab:AddSection("Interface Configurations")
SettingsTab:AddButton({
    Title = "Minimize / Toggle UI",
    Description = "Use LeftControl or click to hide/show UI",
    Callback = function()
        Window:Minimize()
    end
})

-- Main Render Loop Handling Aimbot, Silent Aim, and Fast Attack
RunService.RenderStepped:Connect(function()
    -- Fast Attack Loop
    if getgenv().ZenithFastAttack then
        pcall(function()
            FastAttack:SuperFastAttack()
        end)
    end

    -- Aimbot Loop
    if getgenv().ZenithAimbot and getgenv().ZenithTarget then
        pcall(function()
            local targetPlayer = Players:FindFirstChild(getgenv().ZenithTarget)
            if targetPlayer and targetPlayer.Character then
                local hrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.Position, hrp.Position)
                end
            end
        end)
    end
end)

-- Silent Aim Metatable Hook 
local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldNamecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if getgenv().ZenithSilentAim and getgenv().ZenithTarget and (method == "FireServer" or method == "InvokeServer") then
        pcall(function()
            local targetPlayer = Players:FindFirstChild(getgenv().ZenithTarget)
            if targetPlayer and targetPlayer.Character then
                local hrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    for i, arg in ipairs(args) do
                        if typeof(arg) == "Vector3" then
                            args[i] = hrp.Position
                        elseif typeof(arg) == "CFrame" then
                            args[i] = CFrame.new(hrp.Position)
                        end
                    end
                end
            end
        end)
    end
    return oldNamecall(self, unpack(args))
end)
setreadonly(mt, true)

Fluent:Notify({
    Title = "Zenith Hub || Aimbot",
    Content = "Successfully loaded with Glass UI & Silent Aim!",
    Duration = 5
})
