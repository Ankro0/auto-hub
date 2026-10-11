-- Lightning Auto-Hop v10 (fixed)
local SCRIPT_URL = "https://raw.githubusercontent.com/Ankro0/auto-hub/refs/heads/main/auto%20hop.lua"

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
local queueTeleport = (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queue_on_teleport

-- Auto-Start flag
local AUTO_START = _G.__LightningAutoStart == true
_G.__LightningAutoStart = nil

-- Make sure only one copy of the script runs at a time
local myToken = {}
_G.__LightningToken = myToken

-- Selected tree size (kept across teleports)
local selectedSize = _G.__LightningSize
_G.__LightningSize = nil
if selectedSize ~= "Small" and selectedSize ~= "Medium" and selectedSize ~= "Large" then
    selectedSize = "Small"
end

-- Server IDs carried over from the previous server (saves a web request per hop)
local serverCache = {}
if type(_G.__LightningServers) == "table" then
    for _, id in ipairs(_G.__LightningServers) do
        if type(id) == "string" then table.insert(serverCache, id) end
    end
end
_G.__LightningServers = nil

-- Clean old GUI
local old = playerGui:FindFirstChild("LightningTreeHop")
if old then old:Destroy() end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightningTreeHop"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 250)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(45, 45, 65)
Stroke.Thickness = 1.5

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundTransparency = 1
Title.Text = "Lightning Auto-Hop v10"
Title.TextColor3 = Color3.fromRGB(0, 255, 170)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 40)
StatusLabel.Position = UDim2.new(0, 12, 0, 38)
StatusLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
StatusLabel.TextColor3 = Color3.fromRGB(210, 210, 225)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.Text = "Ready - Press START once"
StatusLabel.TextWrapped = true
StatusLabel.Parent = MainFrame
Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 8)

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(1, -24, 0, 50)
ToggleButton.Position = UDim2.new(0, 12, 0, 88)
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 190, 110)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 15
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "START"
ToggleButton.Parent = MainFrame
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 8)

local SizeButtons = {}
for i, name in ipairs({"Small", "Medium", "Large"}) do
    local b = Instance.new("TextButton")
    b.Name = "Size_" .. name
    b.Size = UDim2.new(0, 88, 0, 30)
    b.Position = UDim2.new(0, 12 + (i - 1) * 94, 0, 146)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.Text = name
    b.Parent = MainFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    SizeButtons[name] = b
end

local CountLabel = Instance.new("TextLabel")
CountLabel.Size = UDim2.new(1, -24, 0, 25)
CountLabel.Position = UDim2.new(0, 12, 0, 184)
CountLabel.BackgroundTransparency = 1
CountLabel.Text = "Servers: 0"
CountLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
CountLabel.TextSize = 11
CountLabel.Font = Enum.Font.Gotham
CountLabel.Parent = MainFrame

local Credit = Instance.new("TextLabel")
Credit.Size = UDim2.new(1, 0, 0, 20)
Credit.Position = UDim2.new(0, 0, 1, -22)
Credit.BackgroundTransparency = 1
Credit.Text = "No-File Auto-Execute"
Credit.TextColor3 = Color3.fromRGB(100, 100, 120)
Credit.TextSize = 10
Credit.Font = Enum.Font.Gotham
Credit.Parent = MainFrame

-- Variables
local running = false
local hopCount = 0
local teleportFailed = false
local visited = {}
visited[game.JobId] = true

-- Tree size thresholds (number of WoodSection parts in the tree)
-- Small: up to SMALL_MAX | Medium: up to MEDIUM_MAX | Large: more than MEDIUM_MAX
local SMALL_MAX = 10
local MEDIUM_MAX = 25

local function sectionCount(model)
    local n = 0
    for _, c in ipairs(model:GetChildren()) do
        if c.Name == "WoodSection" then n = n + 1 end
    end
    return n
end

local function sizeMatches(obj)
    local n = sectionCount(obj.Parent)
    if selectedSize == "Small" then
        return n <= SMALL_MAX
    elseif selectedSize == "Medium" then
        return n > SMALL_MAX and n <= MEDIUM_MAX
    else
        return n > MEDIUM_MAX
    end
end

local function refreshSizeButtons()
    for name, b in pairs(SizeButtons) do
        if name == selectedSize then
            b.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
        else
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
        end
    end
end

for name, b in pairs(SizeButtons) do
    b.MouseButton1Click:Connect(function()
        if running then
            StatusLabel.Text = "Press STOP first to change the size"
            return
        end
        selectedSize = name
        refreshSizeButtons()
        StatusLabel.Text = "Tree size: " .. name
    end)
end
refreshSizeButtons()

-- Queue the script to run again after teleport, passing along the remaining servers
local queued = false
local function queueNow(remaining)
    if not queueTeleport then return end
    if queued then
        if clear_teleport_queue then
            pcall(clear_teleport_queue)
        else
            return
        end
    end
    queued = true

    local parts = {}
    for i = 1, math.min(#remaining, 60) do
        local clean = tostring(remaining[i]):gsub("[^%w%-]", "")
        parts[#parts + 1] = "'" .. clean .. "'"
    end
    local list = "{" .. table.concat(parts, ",") .. "}"

    local code = "task.wait(0.5) _G.__LightningAutoStart = true _G.__LightningSize = '" .. selectedSize
        .. "' _G.__LightningServers = " .. list
        .. " pcall(function() loadstring(game:HttpGet('" .. SCRIPT_URL .. "', true))() end)"
    pcall(function() queueTeleport(code) end)
end

-- Cancel any pending auto-execute (used when the tree is found or you press STOP)
local function clearQueue()
    _G.__LightningAutoStart = nil
    if clear_teleport_queue then
        pcall(clear_teleport_queue)
        queued = false
    end
end

local function alive()
    return running and _G.__LightningToken == myToken
end

local function updateButton(isRunning)
    if isRunning then
        ToggleButton.Text = "STOP"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
    else
        ToggleButton.Text = "START"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 190, 110)
    end
end

-- Detect failed teleports so the script never gets stuck
TeleportService.TeleportInitFailed:Connect(function(plr)
    if plr == player then
        teleportFailed = true
    end
end)

-- Fetch a list of public servers (returns nil on failure)
local function fetchServers()
    if not requestFunc then return nil, "no request function" end

    local ok, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = requestFunc({Url = url, Method = "GET"})
        if not res then return nil, "no response" end
        if res.StatusCode and res.StatusCode ~= 200 then
            return nil, "HTTP " .. tostring(res.StatusCode)
        end
        local decoded = HttpService:JSONDecode(res.Body)
        return decoded and decoded.data, nil
    end)

    if not ok then return nil, tostring(result) end
    return result, nil
end

-- Shuffle so we don't try the same servers every time
local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Tries to teleport to another server. Returns true once a teleport was started.
local function serverHop()
    hopCount = hopCount + 1
    CountLabel.Text = "Servers: " .. hopCount
    StatusLabel.Text = "Hopping to server #" .. hopCount

    while alive() do
        -- Only fetch a new list when the cached one is empty
        if #serverCache == 0 then
            if not requestFunc then
                StatusLabel.Text = "Error: no request function in your executor"
                running = false
                updateButton(false)
                return false
            end

            StatusLabel.Text = "Fetching server list..."
            local servers, err = fetchServers()
            if not servers then
                StatusLabel.Text = "Fetch failed (" .. tostring(err) .. ") - retrying"
                task.wait((err == "HTTP 429") and 6 or 1)
                return false
            end

            shuffle(servers)
            for _, s in ipairs(servers) do
                if s.id and s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                    table.insert(serverCache, s.id)
                end
            end

            if #serverCache == 0 then
                task.wait(1.5)
                return false
            end
        end

        local id = table.remove(serverCache)
        if id ~= game.JobId then
            teleportFailed = false
            queueNow(serverCache)

            local ok = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, id, player)
            end)

            if ok then
                -- Wait up to 10s for the teleport to either happen or fail
                local t = 0
                while t < 10 and not teleportFailed and alive() do
                    task.wait(0.1)
                    t = t + 0.1
                end
                if not teleportFailed then
                    return true
                end
                StatusLabel.Text = "Teleport failed - next server"
            end
        end
    end

    return false
end

-- Wait until the character and the world are ready before scanning
local function waitForWorld()
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:WaitForChild("HumanoidRootPart", 15)
    if not root then return false end
    workspace:WaitForChild("TreeRegion", 10)
    task.wait(0.3) -- tiny delay so the trees can load
    return true
end

local function fastScan()
    local character = player.Character
    if not character then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    local container = workspace:FindFirstChild("TreeRegion") or workspace

    for _, obj in ipairs(container:GetDescendants()) do
        if obj.Name == "WoodSection" and obj:IsA("BasePart") then
            local bc = obj.BrickColor
            local c3 = obj.Color
            local isReallyBlack = (bc and bc.Name == "Really black")
                or (c3 and c3.R < 0.05 and c3.G < 0.05 and c3.B < 0.05)
            if isReallyBlack and sizeMatches(obj) then
                StatusLabel.Text = "Found the tree! (" .. selectedSize .. ")"
                rootPart.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                return true
            end
        end
    end
    return false
end

local function startLoop()
    if running then return end
    running = true
    updateButton(true)

    task.spawn(function()
        while alive() do
            StatusLabel.Text = "Loading world..."
            if not waitForWorld() then
                task.wait(2)
            else
                if not alive() then break end
                StatusLabel.Text = "Scanning #" .. hopCount

                if fastScan() then
                    running = false
                    updateButton(false)
                    StatusLabel.Text = "Done! Found the tree - press START to hop again"
                    clearQueue()
                    break
                end

                if not alive() then break end
                serverHop()
            end
            task.wait()
        end
    end)
end

ToggleButton.MouseButton1Click:Connect(function()
    if running then
        running = false
        updateButton(false)
        StatusLabel.Text = "Stopped"
        clearQueue()
    else
        startLoop()
    end
end)

if AUTO_START then
    print("[Lightning] Returned from teleport - auto starting")
    StatusLabel.Text = "Returned - auto starting..."
    startLoop()
else
    print("[Lightning] Ready - press START once")
end
