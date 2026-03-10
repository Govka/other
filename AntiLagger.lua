-- AntiLagger module for Dyxo Hub
-- Load via: loadstring(game:HttpGet("YOUR_URL"))()
-- Requires: Rayfield, TestTab, Players, RunService, LP to be in scope (set as globals below)

local _Rayfield  = Rayfield  or getgenv().Rayfield
local _TestTab   = TestTab   or getgenv().TestTab
local _Players   = game:GetService("Players")
local _RS        = game:GetService("RunService")
local _LP        = _Players.LocalPlayer

local AntiLagger = {
    enabled      = false,
    conn         = nil,
    lastPos      = {},
    jumpCount    = {},
    frozen       = {},
    lastUnfreeze = {},
    JUMP_DIST    = 800,
    JUMP_TRIGGER = 3,
    FREEZE_TIME  = 5,
}

local function freeze(p)
    if AntiLagger.frozen[p] then return end
    AntiLagger.frozen[p] = true
    AntiLagger.lastUnfreeze[p] = tick() + AntiLagger.FREEZE_TIME
    local char = p.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function() hrp.Anchored = true end) end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.LocalTransparencyModifier = 1 end)
        end
    end
    if _Rayfield then
        _Rayfield:Notify({Title="Anti-Lagger", Content="Froze: "..p.Name, Duration=3})
    end
end

local function unfreeze(p)
    if not AntiLagger.frozen[p] then return end
    AntiLagger.frozen[p] = nil
    AntiLagger.jumpCount[p] = 0
    local char = p.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function() hrp.Anchored = false end) end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function() part.LocalTransparencyModifier = 0 end)
        end
    end
end

local function startAntiLagger()
    if AntiLagger.enabled then return end
    AntiLagger.enabled = true
    AntiLagger.lastPos = {}
    AntiLagger.jumpCount = {}
    AntiLagger.frozen = {}
    AntiLagger.lastUnfreeze = {}

    AntiLagger.conn = _RS.Heartbeat:Connect(function()
        if not AntiLagger.enabled then return end
        local now = tick()
        for _, p in pairs(_Players:GetPlayers()) do
            if p ~= _LP then
                local char = p.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if AntiLagger.frozen[p] then
                    if now >= (AntiLagger.lastUnfreeze[p] or 0) then
                        unfreeze(p)
                    end
                elseif hrp then
                    local curPos = hrp.Position
                    local lastP  = AntiLagger.lastPos[p]
                    if lastP then
                        local dist = (curPos - lastP).Magnitude
                        if dist > AntiLagger.JUMP_DIST then
                            AntiLagger.jumpCount[p] = (AntiLagger.jumpCount[p] or 0) + 1
                            if AntiLagger.jumpCount[p] >= AntiLagger.JUMP_TRIGGER then
                                freeze(p)
                            end
                        else
                            if (AntiLagger.jumpCount[p] or 0) > 0 then
                                AntiLagger.jumpCount[p] = AntiLagger.jumpCount[p] - 0.05
                            end
                        end
                    end
                    AntiLagger.lastPos[p] = curPos
                end
            end
        end
        for p in pairs(AntiLagger.frozen) do
            if not p.Parent then
                AntiLagger.frozen[p] = nil
                AntiLagger.lastPos[p] = nil
                AntiLagger.jumpCount[p] = nil
            end
        end
    end)
end

local function stopAntiLagger()
    AntiLagger.enabled = false
    if AntiLagger.conn then AntiLagger.conn:Disconnect(); AntiLagger.conn = nil end
    for p in pairs(AntiLagger.frozen) do pcall(unfreeze, p) end
    AntiLagger.lastPos = {}
    AntiLagger.jumpCount = {}
    AntiLagger.frozen = {}
end

-- Build UI
_TestTab:CreateSection("🛡 Anti Server Lagger")
_TestTab:CreateParagraph({
    Title="Anti-Lagger",
    Content="Detects players spamming teleports. Locally anchors + hides their character. Auto-unfreezes after N seconds."
})
_TestTab:CreateSlider({
    Name="Jump Detect Distance", Range={200,2000}, Increment=50,
    Suffix=" studs", CurrentValue=800, Flag="AntiLagJumpDist",
    Callback=function(v) AntiLagger.JUMP_DIST = v end,
})
_TestTab:CreateSlider({
    Name="Freeze After N Jumps", Range={1,10}, Increment=1,
    Suffix="", CurrentValue=3, Flag="AntiLagJumpTrigger",
    Callback=function(v) AntiLagger.JUMP_TRIGGER = v end,
})
_TestTab:CreateSlider({
    Name="Unfreeze After", Range={2,30}, Increment=1,
    Suffix="s", CurrentValue=5, Flag="AntiLagFreezeTime",
    Callback=function(v) AntiLagger.FREEZE_TIME = v end,
})
_TestTab:CreateToggle({
    Name="🛡 Anti Server Lagger",
    CurrentValue=false, Flag="AntiLaggerToggle",
    Callback=function(v)
        if v then startAntiLagger() else stopAntiLagger() end
    end,
})
