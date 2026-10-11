--[[
    Black Tree Auto Hop  (Auto-Exec ready)
    1) Scan  : بيلف على السيرفرات واحد واحد، يفحص الشجرة السودا، ويسجل السيرفرات اللي فيها
    2) Visit : كل ما تدوس Start يدخلك أول سيرفر من اللي لقاهم
    3) لما يخلصوا كلهم -> يرجع يعمل Scan جديد لوحده
    الحالة بتتحفظ في ملف عشان تكمل بعد كل Teleport (حطه في فولدر autoexec)
]]

-- الحارس بقى لكل سيرفر (JobId) عشان ما يمنعش التشغيل بعد الـ Teleport
if getgenv then
    if getgenv().BTH_JOB == game.JobId then return end
    getgenv().BTH_JOB = game.JobId
end
if not game:IsLoaded() then game.Loaded:Wait() end

-- احتياطي: لو الـ autoexec مش شغال، يعيد تشغيل نفسه بعد كل Teleport
-- (لازم تحط نفس الملف في فولدر workspace باسم auto hop.lua)
pcall(function()
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if q then
        q([[pcall(function() if isfile and isfile("auto hop.lua") then loadstring(readfile("auto hop.lua"))() end end)]])
    end
end)

pcall(function()
    local old = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("BTH_GUI")
    if old then old:Destroy() end
end)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end

local PLACE, JOB = game.PlaceId, game.JobId
local FILE = "BlackTreeHop_state.json"

---------------------------------------------------------------- CONFIG
local CONFIG = {
    TargetBrick     = "Really black", -- لون الخشب المطلوب
    TreeClass       = nil,            -- لو عايز نوع شجرة معين اكتب اسمه (مثلا "Oak") وإلا سيبه nil
    SizeLimits      = { small = 3, medium = 6 }, -- سمك الجذع: <=3 small | <=6 medium | اكتر من كده large
    LoadTimeout     = 10,             -- أقصى انتظار لتحميل الشجر في السيرفر (ثواني)
    SettleWait      = 0.8,            -- انتظار اضافي بعد ظهور الشجر (زوّده لو بيفوّت شجر)
    TeleportTimeout = 15,             -- لو الـ Teleport علّق نجرب سيرفر تاني
    HopDelay        = 0.3,            -- فاصل بين كل محاولة (زوّده لو جالك rate limit)
    MaxPages        = 20,             -- عدد صفحات السيرفرات (100 سيرفر للصفحة)
    AutoSkipGone    = true,           -- في وضع Visit لو الشجرة اختفت يروح اللي بعده لوحده
}

---------------------------------------------------------------- STATE
local State = {
    phase = "idle",  -- idle | scan | ready | visit
    size = "all",    -- small | medium | large | all
    found = {},      -- { {id=, small=, medium=, large=}, ... }
    done = {},       -- سيرفرات اتزارت
    visited = {},    -- سيرفرات اتفحصت
    pool = {},       -- سيرفرات لسه هنفحصها
    scanned = 0,
}

local function save()
    pcall(function() writefile(FILE, HttpService:JSONEncode(State)) end)
end

local function load()
    local ok, data = pcall(function()
        if isfile and isfile(FILE) then
            return HttpService:JSONDecode(readfile(FILE))
        end
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do State[k] = v end
    end
end

load()

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

-- بترجع نتيجة الشجرة لو سودا + طبيعية (مش مزروعة من لاعب)
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
    local deadline = os.clock() + CONFIG.LoadTimeout
    local seen = false
    repeat
        for _, m in ipairs(workspace:GetDescendants()) do
            if isTree(m) then seen = true break end
        end
        if seen then break end
        task.wait(0.25)
    until os.clock() > deadline
    if not seen then
        return { small = 0, medium = 0, large = 0, maxThick = 0, trees = {} }
    end
    task.wait(CONFIG.SettleWait)

    local res = { small = 0, medium = 0, large = 0, maxThick = 0, trees = {} }
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

---------------------------------------------------------------- HELPERS
local function countFor(e)
    if State.size == "all" then
        return (e.small or 0) + (e.medium or 0) + (e.large or 0)
    end
    return e[State.size] or 0
end

local function queue()
    local q = {}
    for _, e in ipairs(State.found) do
        if countFor(e) > 0 and not State.done[e.id] then table.insert(q, e) end
    end
    return q
end

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
    Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "Black Tree Hop",
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
    local q = queue()
    local withTree = 0
    for _, e in ipairs(State.found) do if countFor(e) > 0 then withTree += 1 end end
    status.Text = ("Phase: %s | Size: %s\nScanned: %d\nServers with tree: %d (left: %d)\n%s")
        :format(State.phase, State.size, State.scanned, withTree, #q, note)
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
TeleportService.TeleportInitFailed:Connect(function()
    tpFailed = true
end)

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

local function pickScanTarget()
    local id = nextFromPool()
    if id then return id end
    setNote("Refreshing server list...")
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

local function finishScan()
    State.phase = (#queue() > 0) and "ready" or "idle"
    save()
    setNote(("Scan done. %d server(s) have the tree. Press Start."):format(#queue()))
end

local function scanHere()
    State.visited[JOB] = true
    setNote("Checking this server...")
    local r = scanCurrent()
    if (r.small + r.medium + r.large) > 0 then
        local exists = false
        for _, e in ipairs(State.found) do if e.id == JOB then exists = true end end
        if not exists then
            table.insert(State.found, { id = JOB, small = r.small, medium = r.medium, large = r.large })
        end
    end
    State.scanned += 1
    save()
    refresh()
    return r
end

local function hopLoop()
    local httpFails = 0
    while State.phase == "scan" do
        local id, err = pickScanTarget()
        if not id then
            if err == "http" and httpFails < 5 then
                httpFails += 1
                setNote("Server list failed, retrying...")
                task.wait(5)
            else
                finishScan()
                return
            end
        else
            httpFails = 0
            setNote("Hopping... (" .. State.scanned .. " scanned)")
            task.wait(CONFIG.HopDelay)
            tp(id)
            local t = os.clock()
            while os.clock() - t < CONFIG.TeleportTimeout and State.phase == "scan" and not tpFailed do
                task.wait(0.5)
            end
        end
    end
end

local function runScan()
    scanHere()
    if State.phase == "scan" then hopLoop() end
end

local function beginScan()
    State.found, State.done, State.visited, State.pool, State.scanned = {}, {}, {}, {}, 0
    State.phase = "scan"
    save()
    task.spawn(runScan)
end

-- بيعمل تيليبورت للشجرة (أقرب شجرة مطابقة للحجم المختار)
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
            -- قاعدة الجذع = أوطى WoodSection
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

local goVisit
local function verifyHere()
    setNote("Verifying tree here...")
    local r = scanCurrent()
    local n = r.small + r.medium + r.large
    if n > 0 then
        local ok = teleportToTree(r)
        setNote(("Tree HERE%s small:%d medium:%d large:%d (max thick %.1f)")
            :format(ok and " - teleported!" or "!", r.small, r.medium, r.large, r.maxThick))
    else
        setNote("Tree is gone here.")
        if CONFIG.AutoSkipGone then
            task.wait(1.5)
            local q = queue()
            if #q > 0 then goVisit(q[1]) else beginScan() end
        end
    end
end

goVisit = function(e)
    State.phase = "visit"
    State.done[e.id] = true
    save()
    if e.id == JOB then
        task.spawn(verifyHere)
    else
        setNote("Joining next server...")
        tp(e.id)
        task.spawn(function()
            local t = os.clock()
            while os.clock() - t < CONFIG.TeleportTimeout and not tpFailed do task.wait(0.5) end
            if tpFailed or os.clock() - t >= CONFIG.TeleportTimeout then
                setNote("Join failed (server full/closed). Press Start for next.")
            end
        end)
    end
end

---------------------------------------------------------------- BUTTONS
button("START", 8, 152, 214, 34, Color3.fromRGB(40, 160, 80), function()
    if State.phase == "scan" then return end
    local q = queue()
    if #q > 0 then goVisit(q[1]) else beginScan() end
end)

button("STOP", 8, 192, 105, 30, Color3.fromRGB(190, 120, 30), function()
    if State.phase == "scan" then
        State.phase = (#queue() > 0) and "ready" or "idle"
        save()
        setNote("Stopped.")
    end
end)

button("RESET", 117, 192, 105, 30, Color3.fromRGB(180, 50, 50), function()
    State.phase, State.found, State.done, State.visited, State.pool, State.scanned = "idle", {}, {}, {}, {}, 0
    save()
    setNote("Reset.")
end)

---------------------------------------------------------------- BOOT
paintSizes()
refresh()

if State.phase == "scan" then
    task.spawn(runScan)
elseif State.phase == "visit" then
    task.spawn(verifyHere)
end
