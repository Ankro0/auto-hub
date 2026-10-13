-- Black Tree Finder + Server Hop
-- Config
local Config = {
    Running = true,
    SizeOption = "all",
    CheckInterval = 1,
    HopCooldown = 5,
    TeleportRetries = 3
}

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

local function GetRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function IsBlack(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    local color = part.Color
    return (
        part.BrickColor.Name == "Really black"
        or (color.R < 0.05 and color.G < 0.05 and color.B < 0.05)
    )
end

local function MatchesSize(tree)
    if Config.SizeOption == "all" then
        return true
    end

    local ok, size = pcall(function()
        return tree:GetExtentsSize().Magnitude
    end)

    if not ok then
        return false
    end

    if Config.SizeOption == "large" then
        return size > 40
    elseif Config.SizeOption == "medium" then
        return size > 20 and size <= 40
    elseif Config.SizeOption == "small" then
        return size <= 20
    end

    return true
end

local function FindBlackTree()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and MatchesSize(obj) then
            local name = obj.Name:lower()
            local isTree = name:find("tree") ~= nil
            local wood = obj:FindFirstChild("WoodSection", true)

            if wood and IsBlack(wood) then
                return obj
            end

            if isTree then
                for _, part in ipairs(obj:GetDescendants()) do
                    if part:IsA("BasePart") and IsBlack(part) then
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

local function TeleportToTree(tree)
    local root = GetRoot()
    if not root or not tree or not tree.Parent then
        return false
    end

    local ok, pivot = pcall(function()
        return tree:GetPivot()
    end)

    if not ok then
        return false
    end

    local target = pivot.Position + Vector3.new(0, 5, 0)

    for attempt = 1, Config.TeleportRetries do
        root = GetRoot()
        if not root then
            return false
        end

        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = CFrame.new(target)
        end)

        task.wait(0.6)

        root = GetRoot()
        if root and (root.Position - target).Magnitude < 10 then
            print("Teleport confirmed.")
            return true
        end
    end

    warn("Teleport failed after retries.")
    return false
end

local function HopServer()
    task.wait(Config.HopCooldown)

    local ok, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/"
            .. game.PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100"

        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if not ok or not result or not result.data then
        warn("Could not retrieve servers.")
        return false
    end

    for _, server in ipairs(result.data) do
        if server.id ~= game.JobId
            and server.playing < server.maxPlayers then

            local success = pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    server.id,
                    Player
                )
            end)

            if success then
                return true
            end
        end
    end

    return false
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "BlackTreeFinder"
gui.ResetOnSpawn = false

pcall(function()
    gui.Parent = game:GetService("CoreGui")
end)

if not gui.Parent then
    gui.Parent = Player:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 230)
frame.Position = UDim2.new(0.05, 0, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundTransparency = 1
title.Text = "Black Tree Finder"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.new(0, 5, 0, 40)
status.Size = UDim2.new(1, -10, 0, 30)
status.BackgroundTransparency = 1
status.Text = "Status: Ready"
status.TextColor3 = Color3.new(1, 1, 1)
status.TextScaled = true
status.Parent = frame

local function MakeButton(text, x, y, callback)
    local button = Instance.new("TextButton")
    button.Position = UDim2.new(0, x, 0, y)
    button.Size = UDim2.new(0, 70, 0, 30)
    button.Text = text
    button.TextScaled = true
    button.Parent = frame
    button.MouseButton1Click:Connect(callback)
    return button
end

MakeButton("Small", 5, 80, function()
    Config.SizeOption = "small"
    status.Text = "Size: Small"
end)

MakeButton("Medium", 85, 80, function()
    Config.SizeOption = "medium"
    status.Text = "Size: Medium"
end)

MakeButton("Large", 165, 80, function()
    Config.SizeOption = "large"
    status.Text = "Size: Large"
end)

MakeButton("All", 5, 120, function()
    Config.SizeOption = "all"
    status.Text = "Size: All"
end)

MakeButton("Start", 85, 120, function()
    Config.Running = true
    status.Text = "Status: Running"
end)

MakeButton("Stop", 165, 120, function()
    Config.Running = false
    status.Text = "Status: Stopped"
end)

-- Main loop
task.spawn(function()
    while task.wait(Config.CheckInterval) do
        if not Config.Running then
            continue
        end

        local tree = FindBlackTree()

        if tree then
            status.Text = "Teleporting..."
            local arrived = TeleportToTree(tree)

            if arrived then
                status.Text = "Reached tree"
                task.wait(2)
            else
                status.Text = "Retrying..."
            end
        else
            status.Text = "No tree - hopping"
            HopServer()
        end
    end
end)
