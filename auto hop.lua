-- Lightning Auto-Hop v9 (English Only - No Files)
local SCRIPT_URL = "https://raw.githubusercontent.com/Ankro0/auto-hub/refs/heads/main/auto%20hop.lua"

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
local queueTeleport = (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queue_on_teleport

-- Auto-Start flag
local AUTO_START = _G.__LightningAutoStart == true
_G.__LightningAutoStart = nil

-- Setup auto-execute
if queueTeleport then
    local code = "task.wait(1) _G.__LightningAutoStart = true pcall(function() loadstring(game:HttpGet('" .. SCRIPT_URL .. "', true))() end)"
    pcall(function() queueTeleport(code) end)
end

-- Clean old GUI
if playerGui:FindFirstChild("LightningTreeHop") then
    playerGui.LightningTreeHop:Destroy()
end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightningTreeHop"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 220)
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
Title.Text = "Lightning Auto-Hop v9"
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

local CountLabel = Instance.new("TextLabel")
CountLabel.Size = UDim2.new(1, -24, 0, 25)
CountLabel.Position = UDim2.new(0, 12, 0, 145)
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
local hopping = false
local hopCount = 0

local function updateButton(isRunning)
    if isRunning then
        ToggleButton.Text = "STOP"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
    else
        ToggleButton.Text = "START"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 190, 110)
    end
end

local function serverHop()
    if hopping then return end
    hopping = true
    
    hopCount = hopCount + 1
    CountLabel.Text = "Servers: " .. hopCount
    StatusLabel.Text = "Hopping to server #" .. hopCount

    if not requestFunc then
        StatusLabel.Text = "Error: no request function"
        hopping = false
        return
    end

    local success, servers = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = requestFunc({Url = url, Method = "GET"})
        return HttpService:JSONDecode(res.Body).data
    end)

    if success and servers then
        for _, s in ipairs(servers) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                local ok = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
                end)
                if ok then return end
            end
        end
    end

    task.wait(1.5)
    hopping = false
    if running then serverHop() end
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
            local isReallyBlack = (bc and bc.Name == "Really black") or (c3 and c3.R < 0.05 and c3.G < 0.05 and c3.B < 0.05)
            if isReallyBlack then
                StatusLabel.Text = "Found the tree!"
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
        task.wait(2)
        while running do
            StatusLabel.Text = "Scanning #" .. hopCount
            
            if fastScan() then
                running = false
                updateButton(false)
                StatusLabel.Text = "Done! Found the tree"
                break
            else
                if running then
                    serverHop()
                    break
                end
            end
            
            RunService.RenderStepped:Wait()
        end
    end)
end

ToggleButton.MouseButton1Click:Connect(function()
    if running then
        running = false
        updateButton(false)
        StatusLabel.Text = "Stopped"
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
