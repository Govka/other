-- ==========================================
-- AbilitySpam.lua | Standalone Module
-- Load via loadstring from your hub
-- After load: getgenv().AbilitySpamSystem
-- ==========================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local LP                = Players.LocalPlayer

-- ---- Helpers ----
local function getCharValue()
    local d = LP:FindFirstChild("Data")
    return d and d:FindFirstChild("Character") and d.Character.Value
end

local function getChangeCharRemote()
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    local ch  = rem and rem:FindFirstChild("Character")
    return ch and ch:FindFirstChild("ChangeCharacter")
end

local function isKATarget(player)
    local wl = getgenv()._DyxoWhitelist
    local bl = getgenv()._DyxoBlacklist
    if wl and wl[player.Name] then return false end
    if bl and next(bl) then return bl[player.Name] == true end
    return true
end

-- ==========================================
-- Instant Respawn
-- ==========================================
local InstantRespawn = { savedCFrame = nil, connections = {} }

local function killChar(char)
    local ok = pcall(function()
        if type(replicatesignal) == "function" and LP.Kill then
            replicatesignal(LP.Kill)
        else
            error("no replicatesignal")
        end
    end)
    if not ok then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Dead)
        else
            char:BreakJoints()
        end
    end
end

local function setupRespawn(char)
    if not char then return end
    if InstantRespawn.savedCFrame then
        task.spawn(function()
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            if not hrp then return end
            task.wait(0.1)
            for i = 1, 10 do
                hrp.CFrame = InstantRespawn.savedCFrame
                task.wait(0.05)
            end
            InstantRespawn.savedCFrame = nil
        end)
    end
    -- Use Heartbeat instead of GetAttributeChangedSignal for compatibility
    local lastHP = 100
    local conn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local hp = hum:GetAttribute("Health") or hum.Health or 0
        if hp <= 0 and lastHP > 0 then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then InstantRespawn.savedCFrame = hrp.CFrame end
            killChar(char)
        end
        lastHP = hp
    end)
    table.insert(InstantRespawn.connections, conn)
end

local function startRespawnListener()
    for _, c in ipairs(InstantRespawn.connections) do
        if c then pcall(function() c:Disconnect() end) end
    end
    InstantRespawn.connections = {}
    if LP.Character then setupRespawn(LP.Character) end
    table.insert(InstantRespawn.connections,
        LP.CharacterAdded:Connect(setupRespawn))
end

local function stopRespawnListener()
    for _, c in ipairs(InstantRespawn.connections) do
        if c then pcall(function() c:Disconnect() end) end
    end
    InstantRespawn.connections = {}
    InstantRespawn.savedCFrame = nil
end

-- ==========================================
-- AbilitySpamSystem
-- ==========================================
local AbilitySpamSystem = {
    enabled         = false,
    connection      = nil,
    selectedAbility = "4",
    spamSpeed       = 0.5,
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
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then InstantRespawn.savedCFrame = hrp.CFrame end
    startRespawnListener()
    local remote = getChangeCharRemote()
    if remote then pcall(function() remote:FireServer("Mob") end) end
    task.wait(0.5)
end

function AbilitySpamSystem:FindNearestPlayer()
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, best = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and isKATarget(p) and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local hm = p.Character:FindFirstChild("Humanoid")
            if tr and hm then
                local hp = hm:GetAttribute("Health") or hm.Health or 0
                if hp > 0 then
                    local d = (hrp.Position - tr.Position).Magnitude
                    if d < best then best = d; nearest = p end
                end
            end
        end
    end
    return nearest
end

function AbilitySpamSystem:GetNearestCFrame()
    local p = self:FindNearestPlayer()
    if p and p.Character then
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.CFrame end
    end
    return CFrame.new()
end

function AbilitySpamSystem:UseAbility(abilityNum)
    pcall(function()
        local chars = ReplicatedStorage:FindFirstChild("Characters")
        local mob   = chars and chars:FindFirstChild("Mob")
        local abs   = mob and mob:FindFirstChild("Abilities")
        local obj   = abs and abs:FindFirstChild(tostring(abilityNum))
        if not obj then return end

        local target = self:FindNearestPlayer()
        if not target then return end

        local targetChar = target.Character
        local targetCF   = self:GetNearestCFrame()
        local data       = self.abilityData[tostring(abilityNum)]
        if not data then return end

        ReplicatedStorage.Remotes.Abilities.Ability:FireServer(obj, data.id)

        for i = 1, 7 do
            local args = {
                obj,
                "Mob:Abilities:"..tostring(abilityNum),
                i,
                data.id,
                {
                    HitboxCFrames    = {targetCF, targetCF},
                    BestHitCharacter = targetChar,
                    HitCharacters    = {targetChar},
                    Ignore           = i > 2 and {ActionNumber1 = {targetChar}} or {},
                    DeathInfo        = {},
                    BlockedCharacters= {},
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
                            StartCFrameStr     = tostring(targetCF.X)..","..tostring(targetCF.Y)..","..tostring(targetCF.Z)..",0,0,0,0,0,0,0,0,0",
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
        local chars = ReplicatedStorage:FindFirstChild("Characters")
        local mob   = chars and chars:FindFirstChild("Mob")
        local abs   = mob and mob:FindFirstChild("Abilities")
        local obj   = abs and abs:FindFirstChild(tostring(abilityNum))
        if obj then
            ReplicatedStorage.Remotes.Abilities.AbilityCanceled:FireServer(obj)
        end
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
    stopRespawnListener()
end

-- ---- Export to global env ----
getgenv().AbilitySpamSystem                = AbilitySpamSystem
getgenv().AbilitySpam_InstantRespawn       = InstantRespawn
getgenv().AbilitySpam_StartRespawnListener = startRespawnListener
getgenv().AbilitySpam_StopRespawnListener  = stopRespawnListener

print("[AbilitySpam] Loaded OK")
