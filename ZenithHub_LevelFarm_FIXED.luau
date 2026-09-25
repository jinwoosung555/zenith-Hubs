--[[
    Zenith Hub - Level Farm FIXED
    Fixes:
      • Quest NPC detection uses GuideModule.Data.NPCList[*].Position
      • Level/quest selection follows the reference flow
      • Auto farm independently handles quest -> NPC -> target
      • Fast Attack runs independently instead of only once per farm tick
      • Weapon selection: Melee / Sword / Gun
      • Zenith branding (Z)
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = workspace

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CommF_ = Remotes:WaitForChild("CommF_")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = Modules:WaitForChild("Net")
local Quests = require(ReplicatedStorage:WaitForChild("Quests"))
local GuideModule = require(ReplicatedStorage:WaitForChild("GuideModule"))

local RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RegisterHit = Net:WaitForChild("RE/RegisterHit")

local Fluent = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/huyyeuemhihi/Fluent/refs/heads/main/Fluentvip.lua"
))()

local Window = Fluent:CreateWindow({
    Title = "Z • Zenith Hub",
    SubTitle = "Level Farm",
    TabWidth = 150,
    Size = UDim2.fromOffset(590, 470),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local function Notify(title, content, duration)
    Fluent:Notify({
        Title = title or "Zenith Hub",
        Content = content or "",
        Duration = duration or 4
    })
end

local Settings = {
    AutoFarm = false,
    FastAttack = true,
    BringMobs = true,
    AutoBuso = true,
    WeaponType = "Melee",
    TweenSpeed = 325,
    AttackRange = 80
}

local State = {
    Status = "Idle",
    Quest = "None",
    Mob = "None",
    Weapon = "None"
}

local function Character()
    return LocalPlayer.Character
end

local function Root()
    local c = Character()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function Alive(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0 and model:FindFirstChild("HumanoidRootPart")
end

local function Distance(pos)
    local r = Root()
    if not r then return math.huge end
    return (r.Position - pos).Magnitude
end

local function FireRemote(...)
    local ok, result = pcall(function()
        return CommF_:InvokeServer(...)
    end)
    return ok, result
end

local function GetLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    return level and level.Value or 1
end

local function GetCurrentWeapon()
    local char = Character()

    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.ToolTip == Settings.WeaponType then
                return tool
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.ToolTip == Settings.WeaponType then
                return tool
            end
        end
    end

    return nil
end

local function EquipWeapon()
    local tool = GetCurrentWeapon()
    local char = Character()
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if tool and hum and tool.Parent ~= char then
        pcall(function()
            hum:EquipTool(tool)
        end)
    end

    return GetCurrentWeapon()
end

local function EnableBuso()
    if not Settings.AutoBuso then return end

    local char = Character()
    if char and not char:GetAttribute("BusoEnabled") then
        FireRemote("Buso")
    end
end

local function TweenTo(cf)
    local root = Root()
    if not root or not cf then return end

    local distance = (root.Position - cf.Position).Magnitude

    if distance <= 35 then
        root.CFrame = cf
        return
    end

    local duration = math.max(distance / math.max(Settings.TweenSpeed, 50), 0.05)

    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = cf}
    )

    tween:Play()
end

--// Quest selection
local QuestBlacklist = {
    MarineQuest = true,
    BartiloQuest = true,
    CitizenQuest = true,
    Trainees = true,
    ["Swan's Raid"] = true,
    ["Town Raid"] = true
}

local function GetQuest()
    local level = GetLevel()

    if level < 10 then
        return {
            Mob = "Bandit",
            NameQuest = "BanditQuest1",
            ID = 1,
            LevelReq = 1
        }
    end

    local best
    local bestLevel = -1

    for questName, questList in pairs(Quests) do
        if not QuestBlacklist[questName] and type(questList) == "table" then
            for id, questData in pairs(questList) do
                if type(questData) == "table" then
                    local req = tonumber(questData.LevelReq)
                    local taskData = questData.Task

                    if req and req <= level and req >= bestLevel and type(taskData) == "table" then
                        for mobName, amount in pairs(taskData) do
                            if type(mobName) == "string" and tonumber(amount) and tonumber(amount) > 0 then
                                bestLevel = req
                                best = {
                                    Mob = mobName,
                                    NameQuest = questName,
                                    ID = id,
                                    LevelReq = req
                                }
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

--// FIX: GuideModule NPC entries use value.Position, not a CFrame key.
local function GetQuestPoint()
    local data = GuideModule and GuideModule.Data
    if not data or not data.NPCList then return nil end

    local closest = data.LastClosestNPC

    if closest then
        for _, npc in pairs(data.NPCList) do
            if type(npc) == "table" and npc.NPCName == closest then
                if typeof(npc.Position) == "CFrame" then
                    return npc.Position
                elseif typeof(npc.Position) == "Vector3" then
                    return CFrame.new(npc.Position)
                elseif typeof(npc.CFrame) == "CFrame" then
                    return npc.CFrame
                end
            end
        end
    end

    -- Fallback: choose the closest GuideModule NPC whose Levels contain the player level.
    local level = GetLevel()
    local bestPos
    local bestDistance = math.huge

    for _, npc in pairs(data.NPCList) do
        if type(npc) == "table" and typeof(npc.Position) == "CFrame" then
            local valid = false

            if type(npc.Levels) == "table" then
                for _, req in pairs(npc.Levels) do
                    if tonumber(req) and tonumber(req) <= level then
                        valid = true
                        break
                    end
                end
            end

            if valid then
                local d = Distance(npc.Position.Position)
                if d < bestDistance then
                    bestDistance = d
                    bestPos = npc.Position
                end
            end
        end
    end

    return bestPos
end

local function QuestVisible()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local quest = main and main:FindFirstChild("Quest")
    return quest and quest.Visible == true
end

local function StartQuest(q)
    if not q then return false end
    local ok = FireRemote("StartQuest", q.NameQuest, q.ID)
    return ok
end

local function GetEnemy(name, maxDistance)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local nearest
    local nearestDistance = maxDistance or math.huge

    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy.Name == name and Alive(enemy) then
            local d = Distance(enemy.HumanoidRootPart.Position)
            if d < nearestDistance then
                nearest = enemy
                nearestDistance = d
            end
        end
    end

    return nearest
end

local function BringEnemies(target)
    if not Settings.BringMobs or not target or not Alive(target) then return end

    local enemies = Workspace:FindFirstChild("Enemies")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not enemies or not targetRoot then return end

    pcall(function()
        sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
    end)

    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy.Name == target.Name and Alive(enemy) then
            local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")

            if enemyRoot and Distance(enemyRoot.Position) <= 500 then
                local owner = false

                pcall(function()
                    owner = isnetworkowner(enemyRoot)
                end)

                if owner then
                    for _, part in ipairs(enemy:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end

                    local lock = enemyRoot:FindFirstChild("ZenithLock")
                    if not lock then
                        lock = Instance.new("BodyVelocity")
                        lock.Name = "ZenithLock"
                        lock.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        lock.Velocity = Vector3.zero
                        lock.Parent = enemyRoot
                    end

                    local hum = enemy:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = 0 end

                    pcall(function()
                        enemy:PivotTo(targetRoot.CFrame)
                    end)
                end
            end
        end
    end
end

--// Fast Attack
local AttackParts = {
    "RightLowerArm",
    "RightUpperArm",
    "LeftLowerArm",
    "LeftUpperArm",
    "RightHand",
    "LeftHand",
    "Head",
    "HumanoidRootPart"
}

local function CollectHits()
    local root = Root()
    local enemies = Workspace:FindFirstChild("Enemies")
    if not root or not enemies then return {}, nil end

    local hits = {}
    local primary

    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy ~= Character() and Alive(enemy) then
            local body = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
            if body and (body.Position - root.Position).Magnitude <= Settings.AttackRange then
                local hitPart

                for _, name in ipairs(AttackParts) do
                    local p = enemy:FindFirstChild(name)
                    if p and p:IsA("BasePart") then
                        hitPart = p
                        break
                    end
                end

                hitPart = hitPart or body

                table.insert(hits, {enemy, hitPart})
                primary = primary or hitPart
            end
        end
    end

    return hits, primary
end

local function FastAttack()
    if not Settings.FastAttack then return end

    local char = Character()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = Root()
    local tool = GetCurrentWeapon()

    if not char or not hum or hum.Health <= 0 or not root or not tool then
        return
    end

    local hits, primary = CollectHits()
    if #hits == 0 or not primary then return end

    pcall(function()
        if tool:FindFirstChild("LeftClickRemote") then
            tool.LeftClickRemote:FireServer(
                (primary.Position - root.Position).Unit,
                1
            )
        end
    end)

    pcall(function()
        RegisterAttack:FireServer(0)
    end)

    pcall(function()
        RegisterHit:FireServer(primary, hits)
    end)
end

--// UI
local FarmTab = Window:AddTab({
    Title = "Level Farm",
    Icon = "rbxassetid://127561653320876"
})

FarmTab:AddSection("Z • Auto Farm")

local AutoFarmToggle = FarmTab:AddToggle("AutoFarm", {
    Title = "Auto Farm Level",
    Description = "Level-aware quest + NPC farming.",
    Default = false,
    Callback = function(v)
        Settings.AutoFarm = v
        State.Status = v and "Starting..." or "Stopped"
    end
})

FarmTab:AddDropdown("WeaponType", {
    Title = "Farm Weapon",
    Values = {"Melee", "Sword", "Gun"},
    Default = "Melee",
    Callback = function(v)
        Settings.WeaponType = v
    end
})

FarmTab:AddToggle("BringMobs", {
    Title = "Bring Mobs",
    Default = true,
    Callback = function(v)
        Settings.BringMobs = v
    end
})

FarmTab:AddToggle("AutoBuso", {
    Title = "Auto Buso",
    Default = true,
    Callback = function(v)
        Settings.AutoBuso = v
    end
})

FarmTab:AddSlider("TweenSpeed", {
    Title = "Tween Speed",
    Min = 100,
    Max = 500,
    Rounding = 5,
    Default = 325,
    Callback = function(v)
        Settings.TweenSpeed = v
    end
})

FarmTab:AddSection("Status")

local LevelStatus = FarmTab:AddParagraph({
    Title = "Z • Status",
    Content = "Loading..."
})

local QuestStatus = FarmTab:AddParagraph({
    Title = "Quest",
    Content = "None"
})

local TargetStatus = FarmTab:AddParagraph({
    Title = "Target",
    Content = "None"
})

local CombatTab = Window:AddTab({
    Title = "Combat",
    Icon = "rbxassetid://125736686613291"
})

CombatTab:AddSection("Z • Fast Attack")

CombatTab:AddToggle("FastAttack", {
    Title = "Fast Attack",
    Description = "Independent fast attack loop.",
    Default = true,
    Callback = function(v)
        Settings.FastAttack = v
    end
})

CombatTab:AddSlider("AttackRange", {
    Title = "Attack Range",
    Min = 20,
    Max = 80,
    Rounding = 1,
    Default = 80,
    Callback = function(v)
        Settings.AttackRange = v
    end
})

CombatTab:AddButton({
    Title = "Equip Selected Weapon",
    Callback = function()
        local tool = EquipWeapon()
        if tool then
            Notify("Z • Zenith Hub", "Equipped: " .. tool.Name, 3)
        else
            Notify("Z • Zenith Hub", "No " .. Settings.WeaponType .. " weapon found.", 3)
        end
    end
})

local SettingsTab = Window:AddTab({
    Title = "Settings",
    Icon = "rbxassetid://127147149367603"
})

SettingsTab:AddSection("Z • Zenith Hub")

SettingsTab:AddButton({
    Title = "Refresh Quest Detection",
    Callback = function()
        local q = GetQuest()
        if q then
            Notify("Quest Detection",
                q.NameQuest .. " | " .. q.Mob .. " | Lv. " .. tostring(q.LevelReq), 5)
        else
            Notify("Quest Detection", "No quest detected.", 4)
        end
    end
})

SettingsTab:AddButton({
    Title = "Stop Farming",
    Callback = function()
        Settings.AutoFarm = false
        pcall(function()
            AutoFarmToggle:SetValue(false)
        end)
        State.Status = "Stopped"
    end
})

--// Auto farm loop
task.spawn(function()
    while task.wait(0.08) do
        if Settings.AutoFarm then
            pcall(function()
                local q = GetQuest()

                if not q then
                    State.Status = "No quest found"
                    return
                end

                State.Quest = q.NameQuest
                State.Mob = q.Mob

                local weapon = EquipWeapon()
                State.Weapon = weapon and weapon.Name or "None"
                EnableBuso()

                if not QuestVisible() then
                    State.Status = "Going to quest"

                    local questPoint = GetQuestPoint()

                    if questPoint then
                        if Distance(questPoint.Position) <= 12 then
                            StartQuest(q)
                            task.wait(0.25)
                        else
                            TweenTo(questPoint)
                        end
                    else
                        -- If GuideModule has not selected an NPC yet, force its
                        -- closest-NPC update and retry on the next cycle.
                        pcall(function()
                            GuideModule:Update()
                        end)
                    end

                    return
                end

                local target = GetEnemy(q.Mob, 650)

                if target and Alive(target) then
                    State.Status = "Farming " .. target.Name

                    BringEnemies(target)

                    local targetRoot = target:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        TweenTo(targetRoot.CFrame * CFrame.new(0, 28, 0))
                    end
                else
                    State.Status = "Searching " .. q.Mob
                end
            end)
        end
    end
end)

--// Independent fast attack loop
task.spawn(function()
    while task.wait(0.035) do
        if Settings.FastAttack then
            pcall(FastAttack)
        end
    end
end)

--// UI status
task.spawn(function()
    while task.wait(0.35) do
        pcall(function()
            LevelStatus:SetContent(
                "Lv. " .. tostring(GetLevel()) ..
                " | " .. State.Status ..
                " | Weapon: " .. State.Weapon
            )

            QuestStatus:SetContent(
                State.Quest .. " | " .. State.Mob
            )

            TargetStatus:SetContent(State.Mob)
        end)
    end
end)

Notify(
    "Z • Zenith Hub",
    "Fixed build loaded. Enable Auto Farm Level.",
    5
)
