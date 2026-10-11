-- Lightning Auto-Hop (autoexec) - our hop + size + sweep
if not game:IsLoaded() then game.Loaded:Wait() end

local T = game:GetService("TeleportService")
local H = game:GetService("HttpService")
local P = game:GetService("Players")
local pl = P.LocalPlayer
local rq = (syn and syn.request) or (http and http.request) or http_request or request

-- نسخة واحدة بس تشتغل
local myToken = {}
_G.__LightningToken = myToken

-- ═══ الإعدادات ═══
local SMALL_MAX = 10   -- Small: لحد 10 قطع
local MEDIUM_MAX = 25  -- Medium: لحد 25 قطعة، وفوق كده Large
local SIZES = {"Small", "Medium", "Large", "All"}
local STATE_FILE = "LightningState.json"

local MIN_SCAN = 1.5   -- أقل وقت فحص
local MAX_SCAN = 4     -- أقصى وقت فحص
local SETTLE = 0.8     -- يوقف لما مفيش حاجة جديدة بتتحمل المدة دي

-- ═══ الحالة (بتتحفظ في ملف عشان تفضل بعد كل teleport) ═══
local state = {
    enabled = true, size = "All", sweep = false, visit = false,
    hops = 0, rounds = 0, visited = {}, cache = {}, found = {},
}

pcall(function()
    if isfile and readfile and isfile(STATE_FILE) then
        local d = H:JSONDecode(readfile(STATE_FILE))
        if type(d) == "table" then
            for k, v in pairs(d) do
                if state[k] ~= nil then state[k] = v end
            end
        end
    end
end)

do
    local okSize = false
    for _, n in ipairs(SIZES) do
        if state.size == n then okSize = true end
    end
    if not okSize then state.size = "All" end
    for _, k in ipairs({"visited", "cache", "found"}) do
        if type(state[k]) ~= "table" then state[k] = {} end
    end
end

local function saveState()
    pcall(function()
        if writefile then writefile(STATE_FILE, H:JSONEncode(state)) end
    end)
end

-- السيرفرات اللي زارها (آخر 300)
local visitedSet = {}
for _, id in ipairs(state.visited) do visitedSet[id] = true end

local function markVisited(id)
    if id and not visitedSet[id] then
        visitedSet[id] = true
        table.insert(state.visited, id)
        if #state.visited > 300 then
            local old = table.remove(state.visited, 1)
            visitedSet[old] = nil
        end
    end
end

local function resetVisited()
    state.visited = {}
    visitedSet = {}
    markVisited(game.JobId)
end
markVisited(game.JobId)

-- ═══ الواجهة ═══
local pg = pl:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("LightningTreeHop")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "LightningTreeHop"
gui.ResetOnSpawn = false
gui.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 236)
frame.Position = UDim2.new(0.05, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Lightning Auto-Hop"
title.TextColor3 = Color3.fromRGB(0, 255, 170)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 40)
statusLabel.Position = UDim2.new(0, 12, 0, 32)
statusLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
statusLabel.TextColor3 = Color3.fromRGB(210, 210, 225)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextWrapped = true
statusLabel.Text = "Ready"
statusLabel.Parent = frame
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 8)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -24, 0, 44)
toggleBtn.Position = UDim2.new(0, 12, 0, 78)
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 15
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = frame
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local sizeButtons = {}
for i, name in ipairs(SIZES) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 63, 0, 30)
    b.Position = UDim2.new(0, 12 + (i - 1) * 71, 0, 130)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.Text = name
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    sizeButtons[name] = b
end

local sweepBtn = Instance.new("TextButton")
sweepBtn.Size = UDim2.new(0, 276, 0, 28)
sweepBtn.Position = UDim2.new(0, 12, 0, 168)
sweepBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sweepBtn.TextSize = 11
sweepBtn.Font = Enum.Font.GothamBold
sweepBtn.Parent = frame
Instance.new("UICorner", sweepBtn).CornerRadius = UDim.new(0, 8)

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -24, 0, 24)
countLabel.Position = UDim2.new(0, 12, 0, 202)
countLabel.BackgroundTransparency = 1
countLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
countLabel.TextSize = 11
countLabel.Font = Enum.Font.Gotham
countLabel.Parent = frame

local function status(t)
    statusLabel.Text = t
end

local function updateCount()
    local text = "Servers: " .. state.hops .. "  |  Rounds: " .. state.rounds
    if state.sweep then
        text = text .. "  |  Found: " .. #state.found
    elseif state.visit then
        text = text .. "  |  Saved: " .. #state.found
    end
    countLabel.Text = text
end

local function refreshToggle()
    if state.enabled then
        toggleBtn.Text = "STOP"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
    else
        toggleBtn.Text = "START"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 190, 110)
    end
end

local function refreshSizes()
    for name, b in pairs(sizeButtons) do
        b.BackgroundColor3 = (name == state.size) and Color3.fromRGB(0, 150, 200) or Color3.fromRGB(40, 40, 58)
    end
end

local function refreshSweep()
    if state.sweep then
        sweepBtn.Text = "Sweep: ON (check all, then go to the best)"
        sweepBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
    else
        sweepBtn.Text = "Sweep: OFF"
        sweepBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
    end
end

refreshToggle()
refreshSizes()
refreshSweep()
updateCount()

local function alive()
    return state.enabled and _G.__LightningToken == myToken
end

-- ═══ الحجم ═══
local function sectionCount(model)
    local n = 0
    for _, c in ipairs(model:GetChildren()) do
        if c.Name == "WoodSection" then n = n + 1 end
    end
    return n
end

local function sizeMatches(obj)
    if state.size == "All" then return true end
    local n = sectionCount(obj.Parent)
    if state.size == "Small" then
        return n <= SMALL_MAX
    elseif state.size == "Medium" then
        return n > SMALL_MAX and n <= MEDIUM_MAX
    else
        return n > MEDIUM_MAX
    end
end

-- ═══ ابحث عن الشجرة ═══
local skippedLogged = setmetatable({}, {__mode = "k"})
local lastFoundSections = 0

local function scan()
    local c = pl.Character
    if not c then return false end
    local rp = c:FindFirstChild("HumanoidRootPart")
    if not rp then return false end
    local box = workspace:FindFirstChild("TreeRegion") or workspace
    local descendants = box:GetDescendants()
    local woodCount = 0
    for _, o in ipairs(descendants) do
        if o.Name == "WoodSection" and o:IsA("BasePart") then
            woodCount = woodCount + 1
            local bc = o.BrickColor
            local col = o.Color
            local isBlack = (bc and bc.Name == "Really black")
                or (col and col.R < 0.05 and col.G < 0.05 and col.B < 0.05)
            if isBlack then
                if sizeMatches(o) then
                    lastFoundSections = sectionCount(o.Parent)
                    print("[Lightning] found black tree, sections =", lastFoundSections)
                    if not state.sweep then
                        rp.CFrame = o.CFrame + Vector3.new(0, 3, 0)
                    end
                    return true
                elseif not skippedLogged[o.Parent] then
                    skippedLogged[o.Parent] = true
                    local n = sectionCount(o.Parent)
                    print("[Lightning] black tree skipped (wrong size), sections =", n)
                    status("Skipped a black tree (" .. n .. " sections) - size filter")
                end
            end
        end
    end
    return false, #descendants, woodCount
end

local function waitForWorld()
    local c = pl.Character or pl.CharacterAdded:Wait()
    local root = c:WaitForChild("HumanoidRootPart", 15)
    if not root then return false end
    workspace:WaitForChild("TreeRegion", 2)
    return true
end

-- يفحص لحد ما العالم يخلص تحميل (مفيش حاجة جديدة بتتحمل) وبعدين يكمل
local function scanWindow()
    local t0 = os.clock()
    local lastCount, changedAt = -1, os.clock()
    local woods = 0
    while alive() do
        local found, count, w = scan()
        if found then return true end
        count = count or 0
        woods = w or 0
        if count ~= lastCount then
            lastCount = count
            changedAt = os.clock()
        end
        status("Scanning #" .. state.hops .. " - trees seen: " .. woods)
        local elapsed = os.clock() - t0
        if (elapsed >= MIN_SCAN and os.clock() - changedAt >= SETTLE) or elapsed >= MAX_SCAN then
            break
        end
        task.wait(0.3)
    end
    print("[Lightning] no black tree here, wood sections seen =", woods)
    return false
end

-- ═══ نظام النقل (hop) ═══
local teleportFailed = false
T.TeleportInitFailed:Connect(function(plr)
    if plr == pl then teleportFailed = true end
end)

local function fetchPage(cursor)
    local ok, a, b, c = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url = url .. "&cursor=" .. H:UrlEncode(cursor) end
        local res = rq({Url = url, Method = "GET"})
        if not res then return nil, "no response" end
        if res.StatusCode and res.StatusCode ~= 200 then
            return nil, "HTTP " .. tostring(res.StatusCode)
        end
        local d = H:JSONDecode(res.Body)
        return d.data, nil, d.nextPageCursor
    end)
    if not ok then return nil, tostring(a) end
    return a, b, c
end

local function fetchServers()
    if not rq then return nil, "no request function" end
    local all, cursor = {}, nil
    for page = 1, 2 do
        local data, err, nextCursor = fetchPage(cursor)
        if not data then
            if page == 1 then return nil, err end
            break
        end
        for _, s in ipairs(data) do all[#all + 1] = s end
        cursor = nextCursor
        if not cursor then break end
    end
    return all, nil
end

-- يحاول ينقل لسيرفر معين. بيرجع true لو النقل بدأ ومفشلش
local function attemptTeleport(id)
    teleportFailed = false
    saveState() -- احفظ الحالة قبل ما نمشي
    local ok = pcall(function()
        T:TeleportToPlaceInstance(game.PlaceId, id, pl)
    end)
    if not ok then return false end
    local t = 0
    while t < 10 and not teleportFailed and alive() do
        task.wait(0.1)
        t = t + 0.1
    end
    return not teleportFailed
end

-- بعد ما يلف الكل: يروح للسيرفرات اللي لقى فيها شجرة، الأكبر الأول
local function finishSweep()
    table.sort(state.found, function(a, b) return a.n > b.n end)
    state.sweep = false
    state.visit = true
    refreshSweep()

    while #state.found > 0 do
        if not alive() then return false end
        local best = table.remove(state.found, 1)
        updateCount()

        if best.id == game.JobId then
            status("Sweep done - the tree is on this server")
            saveState()
            return "here"
        end

        status("Going to a saved server (" .. best.n .. " sections) - " .. #state.found .. " left")
        if attemptTeleport(best.id) then return true end
    end

    state.visit = false
    updateCount()
    saveState()
    return false
end

local function serverHop()
    local counted = false
    status("Finding a server...")

    if state.visit then
        if #state.found > 0 then
            local r = finishSweep()
            if r then return r end
        end
        state.visit = false
        updateCount()
    end

    while alive() do
        if #state.cache == 0 then
            if not rq then
                status("Error: no request function in your executor")
                state.enabled = false
                saveState()
                refreshToggle()
                return false
            end

            status("Fetching server list...")
            local servers, err = fetchServers()
            if not servers then
                status("Fetch failed (" .. tostring(err) .. ") - retrying")
                task.wait((err == "HTTP 429") and 6 or 1)
                return false
            end

            -- ترتيب عشوائي، من غير اللي زاره ولا اللي على وشك يتملي
            local pool = {}
            for _, s in ipairs(servers) do
                if s.id and not visitedSet[s.id] and s.playing and s.maxPlayers and s.playing < s.maxPlayers - 1 then
                    pool[#pool + 1] = {id = s.id, score = math.random()}
                end
            end
            table.sort(pool, function(a, b) return a.score > b.score end)
            for _, e in ipairs(pool) do
                state.cache[#state.cache + 1] = e.id
            end

            if #state.cache == 0 then
                if state.sweep and #state.found > 0 then
                    return finishSweep()
                end
                local checked = #state.visited
                state.rounds = state.rounds + 1
                updateCount()
                status("Not found after " .. checked .. " servers - starting over")
                print("[Lightning] tree not found after", checked, "servers - starting a new round")
                resetVisited()
                saveState()
                task.wait(2)
                return false
            end
        end

        local id = table.remove(state.cache)
        if id ~= game.JobId then
            if not counted then
                counted = true
                state.hops = state.hops + 1
                updateCount()
            end
            status("Hopping to server #" .. state.hops)
            markVisited(id)
            if attemptTeleport(id) then return true end
            status("Teleport failed - next server")
        end
    end

    return false
end

-- ═══ الحلقة الرئيسية ═══
local running = false

local function main()
    if running then return end
    running = true

    while alive() do
        status("Loading world...")
        if not waitForWorld() then
            task.wait(2)
        else
            if not alive() then break end

            if scanWindow() then
                if state.sweep then
                    local already = false
                    for _, f in ipairs(state.found) do
                        if f.id == game.JobId then already = true end
                    end
                    if not already then
                        table.insert(state.found, {id = game.JobId, n = lastFoundSections})
                    end
                    updateCount()
                    saveState()
                    status("Sweep: found " .. #state.found .. " so far - continuing")
                else
                    -- لقى الشجرة: وقف، ومش هيشتغل تاني غير لما تدوس START
                    state.enabled = false
                    state.visit = false
                    state.found = {}
                    saveState()
                    refreshToggle()
                    updateCount()
                    status("Done! Found the tree - press START to hop again")
                    break
                end
            end

            if not alive() then break end
            serverHop()
        end
        task.wait()
    end

    running = false
end

-- ═══ الأزرار ═══
toggleBtn.MouseButton1Click:Connect(function()
    state.enabled = not state.enabled
    saveState()
    refreshToggle()
    if state.enabled then
        task.spawn(function()
            while running do task.wait(0.1) end
            main()
        end)
    else
        status("Stopped")
    end
end)

for name, b in pairs(sizeButtons) do
    b.MouseButton1Click:Connect(function()
        state.size = name
        saveState()
        refreshSizes()
        status("Tree size: " .. name)
    end)
end

sweepBtn.MouseButton1Click:Connect(function()
    if state.enabled then
        status("Press STOP first to change Sweep")
        return
    end
    state.sweep = not state.sweep
    state.visit = false
    state.found = {}
    saveState()
    refreshSweep()
    updateCount()
    status(state.sweep and "Sweep ON" or "Sweep OFF")
end)

-- ═══ ابدأ تلقائي (autoexec) ═══
if state.enabled then
    task.spawn(main)
else
    status("OFF - press START")
end
