-- AbilitySpam module for Dyxo Hub
-- Reads globals: Rayfield, CombatTab, Players, RunService, LP, ReplicatedStorage

local _Players = game:GetService("Players")
local _RS      = game:GetService("RunService")
local _LP      = _Players.LocalPlayer
local _RepStor = game:GetService("ReplicatedStorage")

local _CombatTab = CombatTab or getgenv().CombatTab
local _Rayfield  = Rayfield  or getgenv().Rayfield

local function _getCharValue()
    local d = _LP:FindFirstChild("Data")
    return d and d:FindFirstChild("Character") and d.Character.Value
end

local function _isKATarget(p)
    local PL = getgenv().PlayerLists
    if not PL then return true end
    if PL.whitelist[p.Name] then return false end
    if next(PL.blacklist) then return PL.blacklist[p.Name] == true end
    return true
end

local AbilitySpamInstantRespawn = {savedCFrame = nil, connections = {}}

local function ASK_KillPlayer(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) end
end

local function ASK_SetupRespawn(char)
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
            ASK_KillPlayer(char)
        end
    end)
    table.insert(AbilitySpamInstantRespawn.connections, conn)
end

local function ASK_StartRespawn()
    for _, c in ipairs(AbilitySpamInstantRespawn.connections) do if c then c:Disconnect() end end
    AbilitySpamInstantRespawn.connections = {}
    if _LP.Character then ASK_SetupRespawn(_LP.Character) end
    table.insert(AbilitySpamInstantRespawn.connections, _LP.CharacterAdded:Connect(ASK_SetupRespawn))
end

local function ASK_StopRespawn()
    for _, c in ipairs(AbilitySpamInstantRespawn.connections) do if c then c:Disconnect() end end
    AbilitySpamInstantRespawn.connections = {}
    AbilitySpamInstantRespawn.savedCFrame = nil
end

local AbilitySpamSystem = {
    enabled = false,
    connection = nil,
    selectedAbility = "4",
    spamSpeed = 0.5,
    abilityData = {
        ["1"] = { id = 328194,  actions = {59,  60,  61,  62,  63,  64,  65}  },
        ["2"] = { id = 671300,  actions = {303, 304, 305, 306, 307, 308, 309} },
        ["3"] = { id = 697911,  actions = {357, 358, 359, 360, 361, 362, 363} },
        ["4"] = { id = 9000000, actions = {377, 380, 383, 384, 385, 387, 389} },
    }
}

function AbilitySpamSystem:SwitchToMob()
    if _getCharValue() == "Mob" then return end
    local char = _LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then AbilitySpamInstantRespawn.savedCFrame = hrp.CFrame end
    ASK_StartRespawn()
    local rc = _RepStor:FindFirstChild("Remotes")
    local cc = rc and rc:FindFirstChild("Character") and rc.Character:FindFirstChild("ChangeCharacter")
    if cc then pcall(function() cc:FireServer("Mob") end) end
    task.wait(0.5)
end

function AbilitySpamSystem:FindNearest()
    local char = _LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, p in pairs(_Players:GetPlayers()) do
        if p ~= _LP and _isKATarget(p) and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChild("Humanoid")
            if tr and hum then
                local hp = hum:GetAttribute("Health")
                if hp and hp > 0 then
                    local d = (hrp.Position - tr.Position).Magnitude
                    if d < dist then dist = d; nearest = p end
                end
            end
        end
    end
    return nearest
end

function AbilitySpamSystem:UseAbility(abilityNum)
    pcall(function()
        local abilityObj = _RepStor.Characters.Mob.Abilities:FindFirstChild(tostring(abilityNum))
        if not abilityObj then return end
        local target = self:FindNearest()
        if not target then return end
        local targetChar = target.Character
        local targetCF = targetChar.HumanoidRootPart.CFrame
        local data = self.abilityData[tostring(abilityNum)]
        if not data then return end
        _RepStor.Remotes.Abilities.Ability:FireServer(abilityObj, data.id)
        for i = 1, 7 do
            local args = {
                abilityObj, "Mob:Abilities:"..tostring(abilityNum), i, data.id,
                {
                    HitboxCFrames={targetCF, targetCF}, BestHitCharacter=targetChar,
                    HitCharacters={targetChar},
                    Ignore=i>2 and {ActionNumber1={targetChar}} or {},
                    DeathInfo={}, BlockedCharacters={},
                    HitInfo={IsFacing=not(i==1 or i==2), IsInFront=i<=2, Blocked=i>2 and false or nil},
                    ServerTime=tick(), Actions=i>2 and {ActionNumber1={}} or {}, FromCFrame=targetCF,
                },
                "Action"..data.actions[i], i==2 and 0.1 or nil,
            }
            if i == 7 then
                args[5].RockCFrame = targetCF
                args[5].Actions = {ActionNumber1={[target.Name]={
                    StartCFrameStr=tostring(targetCF.X)..","..tostring(targetCF.Y)..","..tostring(targetCF.Z)..",0,0,0,0,0,0,0,0,0",
                    ImpulseVelocity=Vector3.new(1901,-25000,291), AbilityName=tostring(abilityNum),
                    RotVelocityStr="0,0,0", VelocityStr="1.900635,0.010867,0.291061", Duration=2,
                    RotImpulseVelocity=Vector3.new(5868,-6649,-7414), Seed=math.random(1,1e6),
                    LookVectorStr="0.988493,0,0.151268",
                }}}
            end
            _RepStor.Remotes.Combat.Action:FireServer(unpack(args))
        end
    end)
end

function AbilitySpamSystem:CancelAbility(abilityNum)
    pcall(function()
        local obj = _RepStor.Characters.Mob.Abilities:FindFirstChild(tostring(abilityNum))
        if obj then _RepStor.Remotes.Abilities.AbilityCanceled:FireServer(obj) end
    end)
end

function AbilitySpamSystem:SpamCycle()
    if self.selectedAbility == "All" then
        for _, num in ipairs({"1","2","3","4"}) do
            if not self.enabled then return end
            local n = tonumber(num)
            self:UseAbility(n)
            task.wait(self.spamSpeed * 0.25)
            self:CancelAbility(n)
        end
    else
        local num = tonumber(self.selectedAbility)
        if num then
            self:UseAbility(num)
            task.wait(self.spamSpeed)
            self:CancelAbility(num)
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
        while self.enabled do self:SpamCycle() end
    end)
end

function AbilitySpamSystem:Stop()
    if self.connection then pcall(task.cancel, self.connection); self.connection = nil end
    self.enabled = false
    ASK_StopRespawn()
end

-- Export to global so hub can call it
getgenv().AbilitySpamSystem = AbilitySpamSystem

-- Build UI
_CombatTab:CreateSection("Ability Spam (Mob)")
_CombatTab:CreateParagraph({Title="Ability Spam", Content="Spams selected Mob ability on nearest player. Auto-switches to Mob character."})
_CombatTab:CreateDropdown({
    Name="Ability", Options={"1","2","3","4","All"},
    CurrentOption={"4"}, MultipleOptions=false, Flag="AbilitySpamSelect",
    Callback=function(v)
        AbilitySpamSystem.selectedAbility = (type(v)=="table" and v[1] or v) or "4"
    end,
})
_CombatTab:CreateSlider({
    Name="Spam Speed", Range={0.05,2.0}, Increment=0.05,
    Suffix="s", CurrentValue=0.5, Flag="AbilitySpamSpeed",
    Callback=function(v) AbilitySpamSystem.spamSpeed = v end,
})
_CombatTab:CreateToggle({
    Name="⚡ Ability Spam",
    CurrentValue=false, Flag="AbilitySpamToggle",
    Callback=function(v)
        if v then AbilitySpamSystem:Start() else AbilitySpamSystem:Stop() end
    end,
})
