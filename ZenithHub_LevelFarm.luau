--[[
    Zenith Hub - Level Farm UI
    Focused build based on the uploaded reference script.

    Features:
      • Advanced Fluent UI
      • Auto Farm Level
      • Automatic quest selection from the game's Quests module
      • Level-aware quest / NPC detection
      • Melee / Sword / Gun weapon selection
      • Fast Attack based on the uploaded script's RegisterAttack/RegisterHit flow
      • Optional Bring Mobs + Buso
      • Live farm status
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer

--// Services / game modules
local Workspace = workspace
local CommF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Net = Modules:WaitForChild("Net")
local Quests = require(ReplicatedStorage:WaitForChild("Quests"))
local GuideModule = require(ReplicatedStorage:WaitForChild("GuideModule"))

local Register_Attack = Net:WaitForChild("RE/RegisterAttack")
local Register_Hit = Net:WaitForChild("RE/RegisterHit")

--// Fluent
local Fluent = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/huyyeuemhihi/Fluent/refs/heads/main/Fluentvip.lua"
))()

local Window = Fluent:CreateWindow({
    Title = "Zenith Hub",
    SubTitle = "Level Farm",
    TabWidth = 150,
    Size = UDim2.fromOffset(590, 470),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Options = Fluent.Options

local function Notify(title, content, duration)
    Fluent:Notify({
        Title = title or "Zenith Hub",
        Content = content or "...",
        Duration = duration or 4
    })
end

--// Settings
local Settings = {
    AutoFarm = false,
    FastAttack = true,
    BringMobs = true,
    AutoBuso = true,
    WeaponType = "Melee",
    TweenSpeed = 325,
    AttackRange = 80
}

--// Helpers
local function Alive(char)
    return char
        and char:FindFirstChild("Humanoid")
        and char.Humanoid.Health > 0
        and char:FindFirstChild("HumanoidRootPart")
end

local function Character()
    return LocalPlayer.Character
end

local function Root()
    local c = Character()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function Distance(pos)
    local root = Root()
    if not root then return math.huge end
    return (root.Position - pos).Magnitude
end

local function FireRemote(...)
    return CommF_:InvokeServer(...)
end

local function EnableBuso()
    if not Settings.AutoBuso then return end
    local char = Character()
    if char and not char:GetAttribute("BusoEnabled") then
        pcall(function()
            FireRemote("Buso")
        end)
    end
end

local function GetCurrentWeapon()
    local weaponType = Settings.WeaponType
    local char = Character()

    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.ToolTip == weaponType then
                return tool
            end
        end
    end

    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.ToolTip == weaponType then
            return tool
        end
    end

    return nil
end

local function EquipWeapon()
    local tool = GetCurrentWeapon()
    local char = Character()
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if tool and hum then
        pcall(function()
            hum:EquipTool(tool)
        end)
        return tool
    end

    return nil
end

local function TweenTo(cf)
    local root = Root()
    if not root or not cf then return end

    local distance = (cf.Position - root.Position).Magnitude

    if distance <= 200 then
        root.CFrame = cf
        return
    end

    local duration = math.max(distance / Settings.TweenSpeed, 0.05)
    local tween = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = cf}
    )

    tween:Play()
end

--// Enemy lookup
local function GetEnemy(names, maxDistance)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local best, bestDistance = nil, maxDistance or math.huge

    for _, enemy in ipairs(enemies:GetChildren()) do
        local validName =
            (type(names) == "string" and enemy.Name == names)
            or (type(names) == "table" and table.find(names, enemy.Name) ~= nil)

        if validName and Alive(enemy) then
            local d = Distance(enemy.HumanoidRootPart.Position)
            if d < bestDistance then
                best = enemy
                bestDistance = d
            end
        end
    end

    return best
end

--// Bring mobs - based on the uploaded reference
local function BringEnemies(target)
    if not Settings.BringMobs or not target or not Alive(target) then return end

    pcall(function()
        sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
    end)

    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local targetCF = targetRoot.CFrame
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return end

    for _, enemy in ipairs(enemies:GetChildren()) do
        if enemy.Name == target.Name and Alive(enemy) then
            local enemyRoot = enemy.HumanoidRootPart

            local canControl = false
            pcall(function()
                canControl = isnetworkowner(enemyRoot)
            end)

            if canControl and Distance(enemyRoot.Position) <= 500 then
                for _, part in ipairs(enemy:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end

                if not enemyRoot:FindFirstChild("ZenithLock") then
                    local lock = Instance.new("BodyVelocity")
                    lock.Name = "ZenithLock"
                    lock.Velocity = Vector3.zero
                    lock.MaxForce = Vector3.new(10000, 10000, 10000)
                    lock.Parent = enemyRoot
                end

                enemy.Humanoid.WalkSpeed = 0
                enemy:SetPrimaryPartCFrame(targetCF)
            end
        end
    end
end

--// Quest selection - follows the uploaded reference's level-aware approach
local QuestBlacklist = {
    MarineQuest = true,
    BartiloQuest = true,
    CitizenQuest = true,
    Trainees = true
}

local function GetLevel()
    local data = LocalPlayer:FindFirstChild("Data")
    local level = data and data:FindFirstChild("Level")
    return level and level.Value or 1
end

local function GetQuest()
    local level = GetLevel()

    -- Special cases from the reference
    if level >= 1 and level < 10 then
        return {
            Mob = "Bandit",
            NameQuest = "BanditQuest1",
            ID = 1,
            LevelReq = 1
        }
    end

    local best = nil
    local bestLevel = 0

    for questName, questList in pairs(Quests) do
        if not QuestBlacklist[questName] then
            for id, questData in pairs(questList) do
                local req = questData.LevelReq
                if req and req <= level and req >= bestLevel and questData.Task then
                    for mobName, amount in pairs(questData.Task) do
                        if amount and amount > 1 then
                            bestLevel = req
                            best = {
                                Mob = mobName,
                                NameQuest = questName,
                                ID = id,
                                LevelReq = req
                            }
                        end
                    end
                end
            end
        end
    end

    return best
end

local function QuestVisible()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local main = gui and gui:FindFirstChild("Main")
    local quest = main and main:FindFirstChild("Quest")
    return quest and quest.Visible == true
end

local function GetQuestPoint()
    -- Same GuideModule idea used by the reference:
    -- locate the closest quest NPC and use its CFrame.
    local data = GuideModule.Data
    if not data then return nil end

    local closest = data.LastClosestNPC
    local npcList = data.NPCList

    if closest and npcList then
        for key, value in pairs(npcList) do
            if type(value) == "table" and value.NPCName == closest then
                if typeof(key) == "CFrame" then
                    return key
                end
                if value.CFrame and typeof(value.CFrame) == "CFrame" then
                    return value.CFrame
                end
            end
        end
    end

    return nil
end

local function StartQuest(quest)
    if not quest then return false end

    local ok = pcall(function()
        FireRemote("StartQuest", quest.NameQuest, quest.ID)
    end)

    return ok
end

--// FAST ATTACK
--// This is the focused RegisterAttack/RegisterHit implementation
--// from the uploaded reference, adapted to the smaller Zenith UI.

local FastAttack = {}
local FastAttack_enemies = Workspace:WaitForChild("Enemies")
local FastAttack_characters = Workspace:WaitForChild("Characters")
local FastAttack_arms = {
    "RightLowerArm",
    "RightUpperArm",
    "LeftLowerArm",
    "LeftUpperArm",
    "RightHand",
    "LeftHand"
}

local FastAttack_sendHits
local FastAttack_combatThread

pcall(function()
    FastAttack_combatThread =
        require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Flags")).COMBAT_REMOTE_THREAD
        or false
end)

local function FastAttack_GetSendHits()
    if not getsenv then return nil end

    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if not scripts then return nil end

    for _, scriptObj in ipairs(scripts:GetChildren()) do
        if scriptObj:IsA("LocalScript") then
            local ok, env = pcall(getsenv, scriptObj)

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
    if not Settings.FastAttack then return end

    local char = Character()
    if not char then return end

    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    if not hum or hum.Health <= 0 or not root then
        return
    end

    local tool = GetCurrentWeapon()
    if not tool then return end

    local hitData = {}
    local primaryPart

    for _, list in ipairs({FastAttack_enemies, FastAttack_characters}) do
        if list then
            for _, enemy in ipairs(list:GetChildren()) do
                if enemy ~= char and not enemy:GetAttribute("IsBoat") then
                    local enemyHum = enemy:FindFirstChild("Humanoid")
                    local enemyBody = enemy:FindFirstChild("Head") or enemy.PrimaryPart

                    if enemyHum
                        and enemyHum.Health > 0
                        and enemyBody
                        and (enemyBody.Position - root.Position).Magnitude <= Settings.AttackRange
                    then
                        local partName = FastAttack_arms[math.random(1, #FastAttack_arms)]
                        local part = enemy:FindFirstChild(partName) or enemy.PrimaryPart

                        if part then
                            table.insert(hitData, {enemy, part})
                            primaryPart = part
                        end
                    end
                end
            end
        end
    end

    if #hitData == 0 or not primaryPart then return end

    local leftClickRemote = tool:FindFirstChild("LeftClickRemote")

    if leftClickRemote then
        pcall(function()
            leftClickRemote:FireServer(
                (primaryPart.Position - root.Position).Unit,
                1
            )
        end)
    end

    pcall(function()
        Register_Attack:FireServer(0)
    end)

    if FastAttack_combatThread then
        FastAttack_EnsureSendHits()

        if FastAttack_sendHits then
            pcall(function()
                FastAttack_sendHits(primaryPart, hitData)
            end)
        else
            pcall(function()
                Register_Hit:FireServer(primaryPart, hitData)
            end)
        end
    else
        pcall(function()
            Register_Hit:FireServer(primaryPart, hitData)
        end)
    end
end

--// Status
local CurrentStatus = "Idle"
local CurrentQuest = "None"
local CurrentMob = "None"
local CurrentWeapon = "None"

--// UI tabs
local FarmTab = Window:AddTab({
    Title = "Level Farm",
    Icon = "rbxassetid://127561653320876"
})

FarmTab:AddSection("Level Farming")

local AutoFarmToggle = FarmTab:AddToggle("AutoFarm", {
    Title = "Auto Farm Level",
    Description = "Automatically detects your level, selects a suitable quest and farms its NPC.",
    Default = false,
    Callback = function(v)
        Settings.AutoFarm = v
        if v then
            Notify("Zenith Hub", "Auto Farm Level enabled.", 3)
        else
            CurrentStatus = "Stopped"
        end
    end
})

FarmTab:AddDropdown("WeaponType", {
    Title = "Farm Weapon",
    Description = "Weapon category used while farming.",
    Values = {"Melee", "Sword", "Gun"},
    Default = "Melee",
    Callback = function(v)
        Settings.WeaponType = v
    end
})

FarmTab:AddToggle("BringMobs", {
    Title = "Bring Mobs",
    Description = "Groups matching NPCs around the current target.",
    Default = true,
    Callback = function(v)
        Settings.BringMobs = v
    end
})

FarmTab:AddToggle("AutoBuso", {
    Title = "Auto Buso",
    Description = "Automatically enables Buso while farming.",
    Default = true,
    Callback = function(v)
        Settings.AutoBuso = v
    end
})

FarmTab:AddSlider("TweenSpeed", {
    Title = "Tween Speed",
    Description = "Movement speed used when travelling to quest/NPC locations.",
    Min = 100,
    Max = 500,
    Rounding = 5,
    Default = 325,
    Callback = function(v)
        Settings.TweenSpeed = v
    end
})

FarmTab:AddSection("Farm Status")

local LevelStatus = FarmTab:AddParagraph({
    Title = "Level",
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

CombatTab:AddSection("Fast Attack")

CombatTab:AddToggle("FastAttack", {
    Title = "Fast Attack",
    Description = "Uses the RegisterAttack/RegisterHit system from the uploaded reference.",
    Default = true,
    Callback = function(v)
        Settings.FastAttack = v
    end
})

CombatTab:AddSlider("AttackRange", {
    Title = "Attack Range",
    Description = "Maximum distance for Fast Attack target collection.",
    Min = 20,
    Max = 80,
    Rounding = 1,
    Default = 80,
    Callback = function(v)
        Settings.AttackRange = v
    end
})

CombatTab:AddSection("Weapon")

CombatTab:AddParagraph({
    Title = "Selected Weapon",
    Content = "Uses the currently available tool whose ToolTip matches Melee / Sword / Gun."
})

CombatTab:AddButton({
    Title = "Equip Selected Weapon",
    Callback = function()
        local tool = EquipWeapon()
        if tool then
            Notify("Zenith Hub", "Equipped: " .. tool.Name, 3)
        else
            Notify("Zenith Hub", "No " .. Settings.WeaponType .. " weapon found.", 3)
        end
    end
})

local SettingsTab = Window:AddTab({
    Title = "Settings",
    Icon = "rbxassetid://127147149367603"
})

SettingsTab:AddSection("Information")

SettingsTab:AddParagraph({
    Title = "Zenith Hub",
    Content = "Focused level-farming build. Main farming controls are in the Level Farm tab."
})

SettingsTab:AddButton({
    Title = "Refresh Quest Detection",
    Callback = function()
        local q = GetQuest()
        if q then
            Notify(
                "Quest Detection",
                q.NameQuest .. " | " .. q.Mob .. " | Lv. " .. tostring(q.LevelReq),
                5
            )
        else
            Notify("Quest Detection", "No suitable quest was found.", 4)
        end
    end
})

SettingsTab:AddButton({
    Title = "Stop Farming",
    Callback = function()
        Settings.AutoFarm = false
        AutoFarmToggle:SetValue(false)
        CurrentStatus = "Stopped"
        Notify("Zenith Hub", "Farming stopped.", 3)
    end
})

--// Main farming loop
task.spawn(function()
    while task.wait(0.12) do
        if Settings.AutoFarm then
            pcall(function()
                local level = GetLevel()
                LevelStatus:SetContent(tostring(level))

                local quest = GetQuest()

                if not quest then
                    CurrentStatus = "No quest found"
                    CurrentQuest = "None"
                    CurrentMob = "None"
                    return
                end

                CurrentQuest = quest.NameQuest
                CurrentMob = quest.Mob

                QuestStatus:SetContent(
                    quest.NameQuest .. " | " .. quest.Mob ..
                    " | Req Lv. " .. tostring(quest.LevelReq)
                )

                local weapon = EquipWeapon()
                CurrentWeapon = weapon and weapon.Name or "None"

                EnableBuso()

                if not QuestVisible() then
                    CurrentStatus = "Travelling to quest"

                    local questPoint = GetQuestPoint()

                    if questPoint then
                        if Distance(questPoint.Position) > 10 then
                            TweenTo(questPoint)
                        else
                            StartQuest(quest)
                            task.wait(0.35)
                        end
                    else
                        -- GuideModule may not have populated LastClosestNPC yet.
                        -- Retry instead of inventing a quest location.
                        CurrentStatus = "Waiting for quest NPC detection"
                    end
                else
                    CurrentStatus = "Farming NPC"

                    local target = GetEnemy(quest.Mob, 500)

                    if target and Alive(target) then
                        TargetStatus:SetContent(target.Name)
                        CurrentMob = target.Name

                        if Settings.BringMobs then
                            BringEnemies(target)
                        end

                        local targetRoot = target:FindFirstChild("HumanoidRootPart")

                        if targetRoot then
                            TweenTo(
                                targetRoot.CFrame *
                                CFrame.new(0, 30, 0)
                            )
                        end

                        if Settings.FastAttack then
                            FastAttack:SuperFastAttack()
                        end
                    else
                        TargetStatus:SetContent("Searching...")
                        CurrentStatus = "Searching for " .. quest.Mob

                        -- Search the game's EnemySpawns folder without hardcoding
                        -- a full level table.
                        local worldOrigin = Workspace:FindFirstChild("_WorldOrigin")
                        local spawns = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")

                        if spawns then
                            for _, spawnPart in ipairs(spawns:GetChildren()) do
                                local spawnName = tostring(spawnPart.Name)
                                    :gsub(" %pLv. %d+%p", "")
                                    :gsub(" %pBoss%p", "")
                                    :gsub(" %pRaid Boss%p", "")

                                if spawnName == quest.Mob then
                                    TweenTo(spawnPart.CFrame)
                                    break
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

--// Live status updater
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            LevelStatus:SetContent(
                tostring(GetLevel()) ..
                " | Weapon: " .. CurrentWeapon ..
                " | Status: " .. CurrentStatus
            )

            TargetStatus:SetContent(CurrentMob)
        end)
    end
end)

Notify(
    "Zenith Hub",
    "Loaded. Open Level Farm and enable Auto Farm Level.",
    5
)
