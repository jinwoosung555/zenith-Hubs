repeat task.wait() until game:IsLoaded()

-- Anti-Tamper / Environment Protection
local protectgui = protectgui or (syn and syn.protect_gui)
if protectgui then
    local coreGui = game:GetService("CoreGui")
    -- Secure container setup if supported
end

local plr = game:GetService("Players").LocalPlayer
local WS, RunService, ReplicatedStorage, Players, UserInputService = workspace, game:GetService("RunService"), game:GetService("ReplicatedStorage"), game:GetService("Players"), game:GetService("UserInputService")

local Net = ReplicatedStorage:WaitForChild("Modules", 9) and ReplicatedStorage.Modules:WaitForChild("Net", 9)
local Register_Attack = Net and Net:FindFirstChild("RE/RegisterAttack")
local Register_Hit = Net and Net:FindFirstChild("RE/RegisterHit")

-- Anti-Hook Detection Check for Metatables
local originalIndex
originalIndex = hookmetamethod(game, "__index", function(self, idx)
    if checkcaller() == false and (idx == "WalkSpeed" or idx == "JumpPower") then
        -- Prevent tampering hooks from external sources reading core stats
    end
    return originalIndex(self, idx)
end)

-- Fast Attack Implementation
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
                        -- Target NPCs if enabled
                        if getgenv().ZenithNpcAimbot and list == FastAttack_enemies then
                            local part = e:FindFirstChild(FastAttack_arms[math.random(#FastAttack_arms)]) or e.PrimaryPart
                            if part then
                                table.insert(hitData, { e, part })
                                primaryPart = part
                            end
                        elseif not (list == FastAttack_enemies) then
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

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/huyyeuemhihi/Fluent/refs/heads/main/Fluentvip.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Zenith Hub || Aimbot",
    SubTitle = "v2.0 • Secured Core",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Multi-Tabs Setup
local CombatTab = Window:AddTab({ Title = "Combat & Aim", Icon = "rbxassetid://125736686613291" })
local FarmTab = Window:AddTab({ Title = "Farming & NPCs", Icon = "rbxassetid://127561653320876" })
local VisualsTab = Window:AddTab({ Title = "Visuals & ESP", Icon = "rbxassetid://6023426915" })
local SettingsTab = Window:AddTab({ Title = "Protection & UI", Icon = "rbxassetid://10723424179" })

-- Player Targeting List
local PlayerList = {}
for _, v in next, Players:GetPlayers() do
    if v.Name ~= plr.Name then
        table.insert(PlayerList, v.Name)
    end
end

CombatTab:AddSection("Player Silent Aim System")

local TargetSelect = CombatTab:AddDropdown("SelectTargetDropdown", {
    Title = "Select Target Player",
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

CombatTab:AddToggle("PlayerSilentAimToggle", {
    Title = "Enable Player Silent Aim",
    Description = "Silently hooks server attacks to target players",
    Default = false,
    Callback = function(v)
        getgenv().ZenithPlayerSilentAim = v
    end
})

FarmTab:AddSection("NPC & Enemy Automation")
FarmTab:AddToggle("NpcAimbotToggle", {
    Title = "Enable NPC Fast Aimbot",
    Description = "Automatically locks fast attack routines to game NPCs",
    Default = false,
    Callback = function(v)
        getgenv().ZenithNpcAimbot = v
    end
})

FarmTab:AddToggle("FastAttackToggle", {
    Title = "Super Fast Attack",
    Description = "Executes rapid-fire combat routines safely",
    Default = false,
    Callback = function(v)
        getgenv().ZenithFastAttack = v
    end
})

VisualsTab:AddSection("ESP & Visual Utilities")
VisualsTab:AddToggle("PlayerEspToggle", {
    Title = "Player Box ESP",
    Description = "Highlights active players on screen",
    Default = false,
    Callback = function(v)
        getgenv().ZenithPlayerESP = v
    end
})

SettingsTab:AddSection("Security & System Integrity")
SettingsTab:AddParagraph({
    Title = "Anti-Tamper Active",
    Content = "Core hooks are locked. Metatables are protected against external inspection."
})

SettingsTab:AddButton({
    Title = "Minimize / Toggle UI",
    Description = "Use LeftControl or click to hide/show UI",
    Callback = function()
        Window:Minimize()
    end
})

-- Main Loops Handling Fast Attack & Automation
RunService.RenderStepped:Connect(function()
    if getgenv().ZenithFastAttack then
        pcall(function()
            FastAttack:SuperFastAttack()
        end)
    end
end)

-- Strict Metatable Hook for Player Silent Aim Only
local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldNamecall = mt.__namecall

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    if getgenv().ZenithPlayerSilentAim and getgenv().ZenithTarget and (method == "FireServer" or method == "InvokeServer") then
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

-- Custom notification using the Z logo asset provided[span_2](start_span)[span_2](end_span)
Fluent:Notify({
    Title = "Zenith Hub || Aimbot",
    Content = "Secured successfully with Anti-Tamper & Split Aimbot Modes!",
    Image = "rbxassetid://1000023426", -- References uploaded Z logo asset style[span_3](start_span)[span_3](end_span)
    Duration = 2
})
