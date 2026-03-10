-- ==========================================
-- AbilitySpam.lua | Standalone Module
-- Загружается через loadstring в хаб
-- После загрузки: getgenv().AbilitySpamSystem
-- ==========================================

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace       = game:GetService("Workspace")
local LP              = Players.LocalPlayer

-- Remotes (берём из getgenv хаба, или сами находим)
local Remotes = getgenv().Remotes or {}
if not Remotes.ChangeCharacter then
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    if rem then
        Remotes.ChangeCharacter = rem:FindFirstChild("Character") and rem.Character:FindFirstChild("ChangeCharacter")
    end
end

-- ---- Хелперы ----
local function getCharValue()
    local d = LP:FindFirstChild("Data")
    return d and d:FindFirstChild("Character") and d.Character.Value
end

local function isKATarget(player)
    local wl = getgenv()._DyxoWhitelist
    local bl = getgenv()._DyxoBlacklist
    if wl and wl[player.Name] then return false end
    if bl and next(bl) then return bl[player.Name] == true end
    return true
end

-- ---- Instant Respawn ----
local AbilitySpamInstantRespawn = { savedCFrame = nil, connections = {} }

local function AbilitySpam_KillPlayer(char)
    local ok = pcall(function()
        if type(replicatesignal) == "function" and LP.Kill then
            replicatesignal(LP.Kill)
        else error() end
    end)
    if not ok then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) else char:BreakJoints() end
    end
end

local function AbilitySpam_SetupRespawn(char)
    if not char then return end
    if AbilitySpamInstantRespawn.savedCFrame then
        task.spawn(function()
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            if not hrp then return end
            task.wait(0.1)
            for i = 1, 10 do
                if hrp then hrp.CFrame = AbilitySpamInstantRespawn.savedCFrame end
                task.wait(0.05)
            end
            AbilitySpamInstantRespawn.savedCFrame = nil
        end)
    end
    local hum = char:WaitForChild("Humanoid", 3)
    if not hum then return end
    local conn
    conn = hum:GetAttributeChangedSignal("Health"):Connect(function()
        local h = hum:GetAttribute("Health") or hum.Health
        if h <= 0 then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then AbilitySpamInstantRespawn.savedCFrame = hrp.CFrame end
            AbilitySpam_KillPlayer(char)
        end
    end)
    table.insert(AbilitySpamInstantRespawn.connections, conn)
end

local function AbilitySpam_StartRespawnListener()
    for _, c in ipairs(AbilitySpamInstantRespawn.connections) do if c then c:Disconnect() end end
    AbilitySpamInstantRespawn.connections = {}
    if LP.Character then AbilitySpam_SetupRespawn(LP.Character) end
    table.insert(AbilitySpamInstantRespawn.connections, LP.CharacterAdded:Connect(AbilitySpam_SetupRespawn))
end

local function AbilitySpam_StopRespawnListener()
    for _, c in ipairs(AbilitySpamInstantRespawn.connections) do if c then c:Disconnect() end end
    AbilitySpamInstantRespawn.connections = {}
    AbilitySpamInstantRespawn.savedCFrame = nil
end

-- ---- AbilitySpamSystem ----
local AbilitySpamSystem = {
    enabled          = false,
    connection       = nil,
    selectedAbility  = "4",
    spamSpeed        = 0.5,
    abilityData = {
        ["1"] = { id = 328194,  actions = {59,  60,  61,  62,  63,  64,  65}  },
        ["2"] = { id = 671300,  actions = {303, 304, 305, 306, 307, 308, 309} },
        ["3"] = { id = 697911,  actions = {357, 358, 359, 360, 361, 362, 363} },
        ["4"] = { id = 9000000, actions = {377, 380, 383, 384, 385, 387, 389} },
    }
}

function AbilitySpamSystem:SwitchToMob()
    if getCharValue() == "Mob" then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then AbilitySpamInstantRespawn.savedCFrame = hrp.CFrame end
    AbilitySpam_StartRespawnListener()
    if Remotes.ChangeCharacter then
        pcall(function() Remotes.ChangeCharacter:FireServer("Mob") end)
    else
        local rem = ReplicatedStorage:FindFirstChild("Remotes")
        local ch = rem and rem:FindFirstChild("Character")
        local r = ch and ch:FindFirstChild("ChangeCharacter")
        if r then pcall(function() r:FireServer("Mob") end) end
    end
    task.wait(0.5)
end

function AbilitySpamSystem:FindNearestPlayer()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and isKATarget(p) and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local th = p.Character:FindFirstChild("Humanoid")
            if tr and th then
                local hp = th:GetAttribute("Health")
                if hp and hp > 0 then
                    local d = (hrp.Position - tr.Position).Magnitude
                    if d < dist then dist = d; nearest = p end
                end
            end
        end
    end
    return nearest
end

function AbilitySpamSystem:GetNearestPlayerCFrame()
    local p = self:FindNearestPlayer()
    return p and p.Character and p.Character.HumanoidRootPart
        and p.Character.HumanoidRootPart.CFrame or CFrame.new()
end

function AbilitySpamSystem:UseAbility(abilityNum)
    pcall(function()
        local abilityObj = ReplicatedStorage.Characters.Mob.Abilities:FindFirstChild(tostring(abilityNum))
        if not abilityObj then return end
        local target = self:FindNearestPlayer()
        if not target then return end
        local targetChar = target.Character
        local targetCF   = self:GetNearestPlayerCFrame()
        local data = self.abilityData[tostring(abilityNum)]
        if not data then return end

        ReplicatedStorage.Remotes.Abilities.Ability:FireServer(abilityObj, data.id)

        for i = 1, 7 do
            local args = {
                abilityObj,
                "Mob:Abilities:"..tostring(abilityNum),
                i, data.id,
                {
                    HitboxCFrames  = {targetCF, targetCF},
                    BestHitCharacter = targetChar,
                    HitCharacters  = {targetChar},
                    Ignore         = i > 2 and {ActionNumber1 = {targetChar}} or {},
                    DeathInfo      = {},
                    BlockedCharacters = {},
                    HitInfo = {
                        IsFacing  = not (i == 1 or i == 2),
                        IsInFront = i <= 2,
                        Blocked   = i > 2 and false or nil
                    },
                    ServerTime = tick(),
                    Actions    = i > 2 and {ActionNumber1 = {}} or {},
                    FromCFrame = targetCF
                },
                "Action"..data.actions[i],
                i == 2 and 0.1 or nil
            }
            if i == 7 then
                args[5].RockCFrame = targetCF
                args[5].Actions = {
                    ActionNumber1 = {
                        [target.Name] = {
                            StartCFrameStr = tostring(targetCF.X)..","..tostring(targetCF.Y)..","..tostring(targetCF.Z)..",0,0,0,0,0,0,0,0,0",
                            ImpulseVelocity    = Vector3.new(1901, -25000, 291),
                            AbilityName        = tostring(abilityNum),
                            RotVelocityStr     = "0,0,0",
                            VelocityStr        = "1.900635,0.010867,0.291061",
                            Duration           = 2,
                            RotImpulseVelocity = Vector3.new(5868, -6649, -7414),
                            Seed               = math.random(1, 1e6),
                            LookVectorStr      = "0.988493,0,0.151268"
                        }
                    }
                }
            end
            ReplicatedStorage.Remotes.Combat.Action:FireServer(unpack(args))
        end
    end)
end

function AbilitySpamSystem:CancelAbility(abilityNum)
    pcall(function()
        local obj = ReplicatedStorage.Characters.Mob.Abilities:FindFirstChild(tostring(abilityNum))
        if obj then ReplicatedStorage.Remotes.Abilities.AbilityCanceled:FireServer(obj) end
    end)
end

function AbilitySpamSystem:SpamCycle()
    if self.selectedAbility == "All" then
        for _, num in ipairs({"1","2","3","4"}) do
            if not self.enabled then return end
            local n = tonumber(num)
            self:UseAbility(n)
            task.wait(0.05)
            self:CancelAbility(n)
            task.wait(self.spamSpeed * 0.25)
        end
    else
        local num = tonumber(self.selectedAbility)
        if num then
            self:UseAbility(num)
            task.wait(0.05)
            self:CancelAbility(num)
            task.wait(self.spamSpeed)
        else
            task.wait(0.1)
        end
    end
end

function AbilitySpamSystem:Start()
    if self.connection then return end
    self.enabled = true
    self:SwitchToMob()
    self.connection = task.spawn(function()
        while self.enabled do
            self:SpamCycle()
        end
    end)
end

function AbilitySpamSystem:Stop()
    if self.connection then
        pcall(task.cancel, self.connection)
        self.connection = nil
    end
    self.enabled = false
    AbilitySpam_StopRespawnListener()
end

-- ---- Экспорт в глобальный env ----
getgenv().AbilitySpamSystem          = AbilitySpamSystem
getgenv().AbilitySpamInstantRespawn  = AbilitySpamInstantRespawn
getgenv().AbilitySpam_StartRespawnListener = AbilitySpam_StartRespawnListener
getgenv().AbilitySpam_StopRespawnListener  = AbilitySpam_StopRespawnListener

print("[AbilitySpam] Loaded OK — getgenv().AbilitySpamSystem ready")
