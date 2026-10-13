-- Black Tree Finder | GUI (fixed)
-- Press START once: scans servers, joins them one by one, stops when it reaches a black tree.

print("[BlackTree] script started")
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local Busy = false
local CheckInterval = 1.0
local TeleportRetries = 3
local RegionWait = 8      -- seconds to wait for TreeRegion to load
local SearchWindow = 3    -- seconds to keep looking for the tree after it loads
local MaxPages = 10       -- server list pages to scan
local STATE_FILE = "BlackTreeFinder.json"

------------------------------------------------------------------
-- State (saved to file so it survives server hops)
------------------------------------------------------------------
local State = { running = false, size = "all", queue = {}, visited = {} }
local canFile = type(writefile) == "function"
    and type(readfile) == "function"
    and type(isfile) == "function"

local function saveState()
    if not canFile then return end
    pcall(function()
        writefile(STATE_FILE, HttpService:JSONEncode(State))
    end)
end

local function loadState()
    if not canFile then return end
    pcall(function()
        if isfile(STATE_FILE) then
            local d = HttpService:JSONDecode(readfile(STATE_FILE))
            if type(d) == "table" then
                State.running = d.running == true
                State.size = d.size or "all"
                State.queue = type(d.queue) == "table" and d.queue or {}
                State.visited = type(d.visited) == "table" and d.visited or {}
            end
        end
    end)
end

loadState()
State.visited[game.JobId] = true

------------------------------------------------------------------
-- Remove previous GUI
------------------------------------------------------------------
local playerGui = Player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("BlackTreeFinderUI")
if old then old:Destroy() end

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------
local function getRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isBlack(part)
    return part ~= nil
        and part:IsA("BasePart")
        and part.BrickColor.Name == "Really black"
end

local function matchesSize(model)
    if State.size == "all" then return true end

    local ok, size = pcall(function()
        return model:GetExtentsSize().Magnitude
    end)
    if not ok then return false end

    if State.size == "small" then return size <= 20 end
    if State.size == "medium" then return size > 20 and size <= 40 end
    if State.size == "large" then return size > 40 end

    return true
end

local function findBlackTree()
    local region = Workspace:FindFirstChild("TreeRegion")
    if not region then return nil end

    for _, model in ipairs(region:GetChildren()) do
        if model:IsA("Model") then
            local wood = model:FindFirstChild("WoodSection", true)
            if isBlack(wood) and matchesSize(model) then
                return model, wood
            end
        end
    end

    return nil
end

-- Waits for the map to load, then looks for the tree for a few seconds
local function searchTree()
    local region = Workspace:FindFirstChild("TreeRegion")
        or Workspace:WaitForChild("TreeRegion", RegionWait)
    if not region then return nil end

    local t0 = os.clock()
    repeat
        if not State.running then return nil end
        local model, wood = findBlackTree()
        if model then return model, wood end
        task.wait(0.5)
    until os.clock() - t0 >= SearchWindow

    return nil
end

local function teleportToTree(model, wood)
    for _ = 1, TeleportRetries do
        if not State.running then return false end

        local root = getRoot()
        if not root or not model.Parent or not wood.Parent then
            return false
        end

        local target = wood.Position + Vector3.new(0, 5, 0)

        local ok = pcall(function()
            root.CFrame = CFrame.new(target)
        end)

        task.wait(0.7)

        root = getRoot()
        if ok and root and (root.Position - target).Magnitude < 10 then
            return true
        end
    end

    return false
end

------------------------------------------------------------------
-- HTTP + server hopping
------------------------------------------------------------------
local function httpGet(url)
    local req = (syn and syn.request) or request or http_request
        or (http and http.request)

    if req then
        local ok, res = pcall(req, { Url = url, Method = "GET" })
        if ok and res then
            if res.StatusCode == 200 then return res.Body end
            return nil, res.StatusCode
        end
    end

    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok then return body end
    return nil, 0
end

local function scanServers(setStatus)
    local list = {}
    local cursor = nil
    local pages = 0
    local retries = 0
    local base = "https://games.roblox.com/v1/games/"
        .. game.PlaceId .. "/servers/Public"

    repeat
        if not State.running then return nil end

        local url = base .. "?sortOrder=Asc&excludeFullGames=true&limit=100"
        if cursor then url = url .. "&cursor=" .. cursor end

        setStatus("Scanning servers... (" .. #list .. " found)")
        local body, code = httpGet(url)

        if body then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(body)
            end)

            if ok and type(data) == "table" and data.data then
                for _, s in ipairs(data.data) do
                    if s.id ~= game.JobId
                        and not State.visited[s.id]
                        and s.playing and s.maxPlayers
                        and s.playing < s.maxPlayers - 1 then
                        table.insert(list, s.id)
                    end
                end
                cursor = data.nextPageCursor
            else
                cursor = nil
            end
            pages = pages + 1
        elseif code == 429 and retries < 6 then
            retries = retries + 1
            setStatus("Rate limited, waiting...")
            task.wait(5)
        else
            cursor = nil
        end

        task.wait(0.4)
    until not cursor or pages >= MaxPages

    return list
end

local function hopNext(setStatus)
    while State.running do
        if #State.queue == 0 then
            local list = scanServers(setStatus)
            if not list then return end

            if #list == 0 then
                State.visited = { [game.JobId] = true }
                saveState()
                setStatus("No new servers, retrying...")
                task.wait(5)
            else
                State.queue = list
                saveState()
            end
        end

        if State.running and #State.queue > 0 then
            local id = table.remove(State.queue, 1)
            State.visited[id] = true
            saveState()

            setStatus("Joining server (" .. #State.queue .. " left)")

            local failed = false
            local conn = TeleportService.TeleportInitFailed:Connect(function()
                failed = true
            end)

            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId, id, Player
                )
            end)
            if not ok then failed = true end

            local waited = 0
            while not failed and waited < 15 and State.running do
                task.wait(0.25)
                waited = waited + 0.25
            end
            conn:Disconnect()

            task.wait(1)
        end
    end
end

------------------------------------------------------------------
-- GUI
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BlackTreeFinderUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
print("[BlackTree] GUI created")

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(320, 300)
main.Position = UDim2.new(0.5, -160, 0.35, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 23, 32)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 110, 220)
stroke.Thickness = 1.5
stroke.Parent = main

local function label(parent, text, pos, size, color, textSize)
    local obj = Instance.new("TextLabel")
    obj.Position = pos
    obj.Size = size
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = color or Color3.new(1, 1, 1)
    obj.TextSize = textSize or 14
    obj.Font = Enum.Font.GothamMedium
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.Parent = parent
    return obj
end

label(main, "BLACK TREE FINDER", UDim2.fromOffset(16, 10),
    UDim2.new(1, -32, 0, 30), Color3.fromRGB(130, 170, 255), 18)

label(main, "AUTO TELEPORT  •  SERVER HOP", UDim2.fromOffset(16, 40),
    UDim2.new(1, -32, 0, 20), Color3.fromRGB(160, 165, 180), 10)

local statusLabel = label(main, "● STOPPED", UDim2.fromOffset(16, 68),
    UDim2.new(1, -32, 0, 28), Color3.fromRGB(255, 190, 90), 14)

local function setStatus(text)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = "● " .. text
    end
end

label(main, "TREE SIZE", UDim2.fromOffset(16, 105),
    UDim2.new(1, -32, 0, 20), Color3.fromRGB(200, 205, 220), 12)

local function makeButton(text, x, y, w, h, color, callback)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, h)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = main

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = b

    b.MouseButton1Click:Connect(callback)
    return b
end

local sizeButtons = {}
local options = { "small", "medium", "large", "all" }

local function refreshSizes()
    for name, button in pairs(sizeButtons) do
        button.BackgroundColor3 = (name == State.size)
            and Color3.fromRGB(65, 105, 210)
            or Color3.fromRGB(43, 47, 60)
    end
end

for i, name in ipairs(options) do
    sizeButtons[name] = makeButton(
        string.upper(name),
        16 + (i - 1) * 74, 130, 68, 30,
        Color3.fromRGB(43, 47, 60),
        function()
            State.size = name
            saveState()
            refreshSizes()
        end
    )
end
refreshSizes()

makeButton("START", 16, 185, 140, 42, Color3.fromRGB(35, 160, 100), function()
    if State.running then return end
    State.running = true
    State.queue = {}
    State.visited = { [game.JobId] = true }
    saveState()
    setStatus("RUNNING")
end)

makeButton("STOP", 164, 185, 140, 42, Color3.fromRGB(190, 60, 70), function()
    State.running = false
    State.queue = {}
    saveState()
    setStatus("STOPPED")
end)

label(main, "Scans servers, joins one by one, stops at the tree",
    UDim2.fromOffset(12, 244), UDim2.new(1, -24, 0, 30),
    Color3.fromRGB(145, 150, 165), 10)

if State.running then
    setStatus("RESUMING...")
end

------------------------------------------------------------------
-- Main loop: nothing happens until START (or resume after a hop)
------------------------------------------------------------------
local function step()
    setStatus("Searching for tree...")
    local model, wood = searchTree()

    if not State.running then return end

    if model and wood then
        setStatus("TREE FOUND - TELEPORTING")
        if teleportToTree(model, wood) then
            State.running = false
            State.queue = {}
            saveState()
            setStatus("TREE REACHED")
            return
        end
        setStatus("TELEPORT FAILED - HOPPING")
    else
        setStatus("NO TREE - HOPPING")
    end

    hopNext(setStatus)
end

task.spawn(function()
    while gui.Parent do
        if State.running and not Busy then
            Busy = true

            local ok, err = pcall(step)
            if not ok then
                warn("Black Tree Finder error:", err)
                setStatus("ERROR - CHECK CONSOLE")
                task.wait(2)
            end

            Busy = false
        end

        task.wait(CheckInterval)
    end
end)
