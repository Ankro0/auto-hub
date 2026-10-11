local S=[==[
local SRC = ...

-- حارس لكل سيرفر (JobId): يمنع التشغيل المزدوج ولا يمنع التشغيل بعد الـ Teleport
if not game:IsLoaded() then game.Loaded:Wait() end
if getgenv then
    if getgenv().BTH_JOB == game.JobId then return end
    getgenv().BTH_JOB = game.JobId
end

-- يعيد تشغيل نفسه بعد كل Teleport (من غير ما يعتمد على autoexec ولا ملفات)
pcall(function()
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if q and SRC then
        q("local S=[==[" .. SRC .. "]=" .. "=] loadstring(S)(S)")
    end
end)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end

pcall(function()
    local old = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("BTH_GUI")
    if old then old:Destroy() end
end)

local PLACE, JOB = game.PlaceId, game.JobId
local FILE = "auto_hop_state.json"

---------------------------------------------------------------- CONFIG
local CONFIG = {
    TargetBrick     = "Really black", -- لون الخشب المطلوب
    TreeClass       = nil,            -- نوع شجرة معين (مثلا "Oak") وإلا سيبه nil
    SizeLimits      = { small = 3, medium = 6 }, -- سمك الجذع: <=3 small | <=6 medium | اكتر large
    LoadTimeout     = 10,             -- أقصى انتظار لتحميل الشجر (ثواني)
    SettleWait      = 0.8,            -- زوّده لو بيفوّت شجر
    TeleportTimeout = 15,             -- لو الـ Teleport علّق يجرب سيرفر تاني
    HopDelay        = 0.3,            -- زوّده لو جالك rate limit
    MaxPages        = 20,             -- صفحات السيرفرات (100 سيرفر للصفحة)
}

---------------------------------------------------------------- STATE
local State = {
    phase = "idle",  -- idle | scan | found
    size = "all",    -- small | medium | large | all
    visited = {},
    pool = {},
    scanned = 0,
    hits = 0,
}

local function save()
    pcall(function() writefile(FILE, HttpService:JSONEncode(State)) end)
end

pcall(function()
    if isfile and isfile(FILE) then
        local data = HttpService:JSONDecode(readfile(FILE))
        if type(data) == "table" then
            for k, v in pairs(data) do State[k] = v end
        end
    end
end)
if State.phase ~= "scan" and State.phase ~= "found" then State.phase = "idle" end

---------------------------------------------------------------- TREE CHECK
local TARGET = BrickColor.new(CONFIG.TargetBrick)

local function median(a, b, c)
    local t = { a, b, c }
    table.sort(t)
    return t[2]
end

local function classify(th)
    if th <= CONFIG.SizeLimits.small then return "small" end
    if th <= CONFIG.SizeLimits.medium then return "medium" end
    return "large"
end

-- بترجع سمك الجذع لو الشجرة سودا + طبيعية (مش مزروعة من لاعب)
local function analyzeTree(model)
    local owner = model:FindFirstChild("Owner")
    if owner and owner:IsA("ValueBase") then
        local v = owner.Value
        if v ~= nil and v ~= 0 and v ~= "" then return nil end
    end
    if CONFIG.TreeClass then
        local tc = model:FindFirstChild("TreeClass")
        if not (tc and tc:IsA("ValueBase") and tostring(tc.Value) == CONFIG.TreeClass) then return nil end
    end
    local n, nb, th = 0, 0, 0
    for _, c in ipairs(model:GetChildren()) do
        if c.Name == "WoodSection" and c:IsA("BasePart") then
            n += 1
            if c.BrickColor == TARGET then nb += 1 end
            local s = c.Size
            th = math.max(th, median(s.X, s.Y, s.Z))
        end
    end
    if n == 0 or nb * 2 < n then return nil end
    return th
end

local function isTree(m)
    return m:IsA("Model") and m:FindFirstChild("TreeClass") and m:FindFirstChild("WoodSection")
end

local function scanCurrent()
    local res = { small = 0, medium = 0, large = 0, maxThick = 0, trees = {} }
    local deadline = os.clock() + CONFIG.LoadTimeout
    local seen = false
    repeat
        for _, m in ipairs(workspace:GetDescendants()) do
            if isTree(m) then seen = true break end
        end
        if seen then break end
        task.wait(0.25)
    until os.clock() > deadline
    if not seen then return res end
    task.wait(CONFIG.SettleWait)

    for _, m in ipairs(workspace:GetDescendants()) do
        if isTree(m) then
            local th = analyzeTree(m)
            if th then
                local sz = classify(th)
                res[sz] += 1
                res.maxThick = math.max(res.maxThick, th)
                table.insert(res.trees, { model = m, size = sz, thick = th })
            end
        end
    end
    return res
end

local function matchCount(r)
    if State.size == "all" then return r.small + r.medium + r.large end
    return r[State.size] or 0
end

-- تيليبورت للكاركتر عند أقرب شجرة مطابقة للحجم المختار
local function teleportToTree(r)
    local char = LP.Character
    local t0 = os.clock()
    while (not char or not char:FindFirstChild("HumanoidRootPart")) and os.clock() - t0 < 15 do
        task.wait(0.5)
        char = LP.Character
    end
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    local best, bestDist, bestBase
    for _, t in ipairs(r.trees) do
        if (State.size == "all" or t.size == State.size) and t.model.Parent then
            local base
            for _, c in ipairs(t.model:GetChildren()) do
                if c.Name == "WoodSection" and c:IsA("BasePart") then
                    if not base or c.Position.Y < base.Position.Y then base = c end
                end
            end
            if base then
                local d = (base.Position - root.Position).Magnitude
                if not bestDist or d < bestDist then
                    best, bestDist, bestBase = t, d, base
                end
            end
        end
    end
    if not best then return false end

    local pos = bestBase.Position + Vector3.new(best.thick / 2 + 4, 3, 0)
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = CFrame.new(pos, bestBase.Position)
    return true
end

---------------------------------------------------------------- SERVERS
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and res then return res end
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local ok2, r = pcall(req, { Url = url, Method = "GET" })
        if ok2 and r and r.StatusCode == 200 then return r.Body end
    end
end

local function fetchServers()
    local list, cursor = {}, nil
    for _ = 1, CONFIG.MaxPages do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PLACE)
        if cursor then url = url .. "&cursor=" .. cursor end
        local body
        for _ = 1, 4 do
            body = httpGet(url)
            if body then break end
            task.wait(3)
        end
        if not body then return #list > 0 and list or nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not ok or type(data) ~= "table" or not data.data then return #list > 0 and list or nil end
        for _, s in ipairs(data.data) do
            table.insert(list, { id = s.id, playing = s.playing or 0, max = s.maxPlayers or 0 })
        end
        cursor = data.nextPageCursor
        if not cursor then break end
        task.wait(0.2)
    end
    return list
end

---------------------------------------------------------------- GUI
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local gui = mk("ScreenGui", { Name = "BTH_GUI", ResetOnSpawn = false }, nil)
pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end

local main = mk("Frame", {
    Size = UDim2.fromOffset(230, 232), Position = UDim2.fromOffset(20, 60),
    BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0,
    Active = true, Draggable = true,
}, gui)
mk("UICorner", { CornerRadius = UDim.new(0, 8) }, main)

mk("TextLabel", {
    Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "auto hop",
    TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 15,
}, main)

local status = mk("TextLabel", {
    Position = UDim2.fromOffset(8, 28), Size = UDim2.new(1, -16, 0, 84),
    BackgroundColor3 = Color3.fromRGB(32, 32, 40), BorderSizePixel = 0,
    TextColor3 = Color3.fromRGB(220, 220, 220), Font = Enum.Font.Gotham, TextSize = 12,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, Text = "",
}, main)
mk("UICorner", { CornerRadius = UDim.new(0, 6) }, status)
mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }, status)

local note = ""
local function refresh()
    status.Text = ("phase: %s | size: %s\nscanned: %d | trees found: %d\n%s")
        :format(State.phase, State.size, State.scanned, State.hits, note)
end
local function setNote(t) note = t refresh() end

local sizeBtns = {}
local function paintSizes()
    for name, b in pairs(sizeBtns) do
        b.BackgroundColor3 = (State.size == name) and Color3.fromRGB(70, 110, 220) or Color3.fromRGB(45, 45, 55)
    end
end

local function button(text, x, y, w, h, color, cb)
    local b = mk("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Text = text,
        BackgroundColor3 = color, TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0, AutoButtonColor = true,
    }, main)
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    b.MouseButton1Click:Connect(cb)
    return b
end

for i, name in ipairs({ "small", "medium", "large", "all" }) do
    sizeBtns[name] = button(name, 8 + (i - 1) * 54, 118, 51, 28, Color3.fromRGB(45, 45, 55), function()
        State.size = name
        save() paintSizes() refresh()
    end)
end

---------------------------------------------------------------- LOGIC
local tpFailed = false
TeleportService.TeleportInitFailed:Connect(function() tpFailed = true end)

local function tp(id)
    tpFailed = false
    State.visited[id] = true
    save()
    pcall(function() TeleportService:TeleportToPlaceInstance(PLACE, id, LP) end)
end

local function nextFromPool()
    while #State.pool > 0 do
        local id = table.remove(State.pool, math.random(#State.pool))
        if not State.visited[id] and id ~= JOB then return id end
    end
end

local function pickTarget()
    local id = nextFromPool()
    if id then return id end
    setNote("refreshing server list...")
    local list = fetchServers()
    if not list then return nil, "http" end
    for _, s in ipairs(list) do
        if not State.visited[s.id] and s.id ~= JOB and s.playing < s.max then
            table.insert(State.pool, s.id)
        end
    end
    save()
    return nextFromPool()
end

local function hopLoop()
    local httpFails = 0
    while State.phase == "scan" do
        local id, err = pickTarget()
        if not id then
            if err == "http" then
                httpFails += 1
                if httpFails >= 5 then
                    State.phase = "idle" save()
                    setNote("server list failed, press START to retry")
                    return
                end
                setNote("server list failed, retrying...")
                task.wait(5)
            else
                -- خلصنا كل السيرفرات: ابدأ لفة جديدة
                State.visited, State.pool = {}, {}
                save()
                setNote("cycle done, starting a new one...")
                task.wait(2)
            end
        else
            httpFails = 0
            setNote("hopping... (" .. State.scanned .. " scanned)")
            task.wait(CONFIG.HopDelay)
            tp(id)
            local t = os.clock()
            while os.clock() - t < CONFIG.TeleportTimeout and State.phase == "scan" and not tpFailed do
                task.wait(0.5)
            end
        end
    end
end

-- يفحص السيرفر الحالي: لو لقى الشجرة يقف ويروحلها، وإلا يكمل hop
local function runScan()
    State.visited[JOB] = true
    setNote("checking this server...")
    local r = scanCurrent()
    if State.phase ~= "scan" then return end
    State.scanned += 1
    if matchCount(r) > 0 then
        State.phase = "found"
        State.hits += 1
        save()
        local ok = teleportToTree(r)
        setNote(("TREE FOUND%s\nsmall:%d medium:%d large:%d (max thick %.1f)\npress START to keep hopping")
            :format(ok and " - teleported!" or "!", r.small, r.medium, r.large, r.maxThick))
        return
    end
    save()
    refresh()
    hopLoop()
end

---------------------------------------------------------------- BUTTONS
button("START", 8, 152, 214, 34, Color3.fromRGB(40, 160, 80), function()
    if State.phase == "scan" then return end
    local wasFound = State.phase == "found"
    State.phase = "scan"
    save()
    if wasFound then
        task.spawn(hopLoop)   -- السيرفر ده اتفحص خلاص، كمّل hop
    else
        task.spawn(runScan)
    end
end)

button("STOP", 8, 192, 105, 30, Color3.fromRGB(190, 120, 30), function()
    State.phase = "idle"
    save()
    setNote("stopped.")
end)

button("RESET", 117, 192, 105, 30, Color3.fromRGB(180, 50, 50), function()
    State.phase, State.visited, State.pool, State.scanned, State.hits = "idle", {}, {}, 0, 0
    save()
    setNote("reset.")
end)

---------------------------------------------------------------- BOOT
paintSizes()
refresh()

if State.phase == "scan" then
    task.spawn(runScan)
elseif State.phase == "found" then
    setNote("tree was found earlier. press START to keep hopping")
end

]==]
local f,e=loadstring(S)
if f then f(S) else warn(e) end
