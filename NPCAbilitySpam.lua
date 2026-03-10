-- ==========================================
-- NPCAbilitySpam.lua | Standalone Module
-- Загружается через loadstring в хаб
-- ТРЕБУЕТ: AbilitySpam.lua загружен первым
-- После загрузки: getgenv().NPCAbilitySpam
-- ==========================================
-- Два потока одновременно:
--   Thread 1 — WallCombo пулл NPC (сервер-сайд, как tearphy god mode)
--   Thread 2 — Ability 4 спам на NPC
-- ==========================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local LP                = Players.LocalPlayer

-- ---- Берём из env если AbilitySpam.lua уже загружен ----
local AbilitySpamSystem = getgenv().AbilitySpamSystem
if not AbilitySpamSystem then
    AbilitySpamSystem = { SwitchToMob = function() end }
    warn("[NPCAbilitySpam] AbilitySpam.lua не загружен — SwitchToMob недоступен!")
end

-- ---- Хелперы ----
local function findAllNPCs()
    local list  = {}
    local chars = workspace:FindFirstChild("Characters")
    local npcs  = chars and chars:FindFirstChild("NPCs")
    if not npcs then return list end
    for _, npc in pairs(npcs:GetChildren()) do
        if npc:IsA("Model") and npc:FindFirstChild("Head") then
            table.insert(list, npc)
        end
    end
    return list
end

local function IsAlive(char)
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return false end
    if hum.Health <= 0 then return false end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
    if char:GetAttribute("Dead") == true or char:GetAttribute("Dead") == "true" then return false end
    return true
end

local function genActionName()
    return "Action"..math.random(100, 9999)
end

-- ==========================================
-- NPCAbilitySpam
-- ==========================================
local NPCAbilitySpam = {
    enabled        = false,
    pullThread     = nil,
    attackThread   = nil,
    pullInterval   = 0.15,   -- скорость WallCombo
    attackInterval = 0.3,    -- скорость Ability 4
}

function NPCAbilitySpam:FindNearest()
    local char  = LP.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local npcs = findAllNPCs()
    if #npcs == 0 then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, npc in pairs(npcs) do
        if IsAlive(npc) then
            local nHRP = npc:FindFirstChild("HumanoidRootPart")
            if nHRP then
                local dist = (myHRP.Position - nHRP.Position).Magnitude
                if dist < nearestDist then nearestDist = dist; nearest = npc end
            end
        end
    end
    return nearest
end

function NPCAbilitySpam:WallCombo(npc)
    local char = LP.Character
    if not char or not IsAlive(npc) then return end
    local charData  = LP:FindFirstChild("Data")
    local charValue = charData and charData:FindFirstChild("Character") and charData.Character.Value
    if not charValue then return end
    local charsFolder = ReplicatedStorage:FindFirstChild("Characters")
    if not charsFolder or not charsFolder:FindFirstChild(charValue) then return end
    local wallComboAbility = charsFolder[charValue]:FindFirstChild("WallCombo")
    if not wallComboAbility then return end

    local actionNumber = genActionName()
    local randomId     = math.random(100000, 999999)

    pcall(function()
        ReplicatedStorage.Remotes.Abilities.Ability:FireServer(wallComboAbility, randomId)
    end)
    pcall(function()
        ReplicatedStorage.Remotes.Combat.Action:FireServer(
            wallComboAbility,
            "Characters:"..charValue..":WallCombo",
            1, randomId,
            {
                HitboxCFrames    = {nil},
                BestHitCharacter = npc,
                HitCharacters    = {npc},
                Ignore           = {[actionNumber] = {npc}},
                DeathInfo        = {},
                Actions          = {[actionNumber] = {}},
                HitInfo          = {Blocked=false, IsFacing=true, IsInFront=true},
                BlockedCharacters= {},
                ServerTime       = tick(),
                FromCFrame       = nil,
            }, actionNumber)
    end)
end

function NPCAbilitySpam:FireAbility4(targetCF, targetModel)
    pcall(function()
        local abilityObj = ReplicatedStorage.Characters.Mob.Abilities:FindFirstChild("4")
        if not abilityObj then return end

        local abilityID = 9000000 + math.random(0, 999)
        local actions   = {377, 380, 383, 384, 385, 387, 389}

        ReplicatedStorage.Remotes.Abilities.Ability:FireServer(abilityObj, abilityID)

        for i = 1, 7 do
            local hitChars = targetModel and {targetModel} or {}
            local args = {
                abilityObj, "Mob:Abilities:4", i, abilityID,
                {
                    HitboxCFrames    = {targetCF, targetCF},
                    BestHitCharacter = targetModel or nil,
                    HitCharacters    = hitChars,
                    Ignore           = i > 2 and (targetModel and {ActionNumber1={targetModel}} or {}) or {},
                    DeathInfo        = {},
                    BlockedCharacters= {},
                    HitInfo = {
                        IsFacing  = not (i == 1 or i == 2),
                        IsInFront = i <= 2,
                        Blocked   = i > 2 and false or nil
                    },
                    ServerTime = tick(),
                    Actions    = i > 2 and {ActionNumber1={}} or {},
                    FromCFrame = targetCF,
                },
                "Action"..actions[i],
                i == 2 and 0.05 or nil,
            }
            if i == 7 then
                local key = targetModel and tostring(targetModel) or "empty"
                args[5].RockCFrame = targetCF
                args[5].Actions = {ActionNumber1={[key]={
                    StartCFrameStr     = tostring(targetCF.X)..","..tostring(targetCF.Y)..","..tostring(targetCF.Z)..",0,0,0,0,0,0,0,0,0",
                    ImpulseVelocity    = Vector3.new(1901, -25000, 291),
                    AbilityName        = "4",
                    RotVelocityStr     = "0,0,0",
                    VelocityStr        = "1.900635,0.010867,0.291061",
                    Duration           = 2,
                    RotImpulseVelocity = Vector3.new(5868, -6649, -7414),
                    Seed               = math.random(1, 1e6),
                    LookVectorStr      = "0.988493,0,0.151268",
                }}}
            end
            ReplicatedStorage.Remotes.Combat.Action:FireServer(unpack(args))
        end

        task.delay(0.05, function()
            pcall(function() ReplicatedStorage.Remotes.Abilities.AbilityCanceled:FireServer(abilityObj) end)
        end)
    end)
end

function NPCAbilitySpam:Start()
    if self.enabled then return end
    self.enabled = true
    AbilitySpamSystem:SwitchToMob()

    -- Thread 1: WallCombo пулл
    self.pullThread = task.spawn(function()
        while self.enabled do
            local npc = NPCAbilitySpam:FindNearest()
            if npc then
                pcall(function() NPCAbilitySpam:WallCombo(npc) end)
            end
            task.wait(self.pullInterval)
        end
    end)

    -- Thread 2: Ability 4 спам
    self.attackThread = task.spawn(function()
        while self.enabled do
            local npc   = NPCAbilitySpam:FindNearest()
            local char  = LP.Character
            local myHRP = char and char:FindFirstChild("HumanoidRootPart")

            if npc then
                local nHRP = npc:FindFirstChild("HumanoidRootPart")
                if nHRP then
                    pcall(function() NPCAbilitySpam:FireAbility4(nHRP.CFrame, npc) end)
                end
            elseif myHRP then
                -- Нет NPC — стреляем в пустоту перед собой
                local emptyCF = myHRP.CFrame * CFrame.new(0, 0, -5)
                pcall(function() NPCAbilitySpam:FireAbility4(emptyCF, nil) end)
            end

            task.wait(self.attackInterval)
        end
    end)
end

function NPCAbilitySpam:Stop()
    self.enabled = false
    if self.pullThread   then pcall(task.cancel, self.pullThread);   self.pullThread   = nil end
    if self.attackThread then pcall(task.cancel, self.attackThread); self.attackThread = nil end
    pcall(function()
        local obj = ReplicatedStorage.Characters.Mob.Abilities:FindFirstChild("4")
        if obj then ReplicatedStorage.Remotes.Abilities.AbilityCanceled:FireServer(obj) end
    end)
end

-- ---- Экспорт ----
getgenv().NPCAbilitySpam = NPCAbilitySpam
print("[NPCAbilitySpam] Loaded OK — getgenv().NPCAbilitySpam ready")
