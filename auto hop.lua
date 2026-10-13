
-- ==========================================
-- Tree Auto Hop + Auto Restart
-- ==========================================

local SCRIPT_URL = "https://raw.githubusercontent.com/Ankro0/auto-hub/refs/heads/main/auto%20hop.lua"

local queue = queue_on_teleport
    or (syn and syn.queue_on_teleport)

if queue then
    queue('loadstring(game:HttpGet("' .. SCRIPT_URL .. '", true))()')
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Config = {
    Running = true,
    SizeOption = "all",
    CheckInterval = 1,
    HopCooldown = 5
}

local function GetTree()
    local tree = Workspace:FindFirstChild("TreeRegion")
    if not tree then return nil end

    local leaves = tree:FindFirstChild("Leaves")
    local wood = tree:FindFirstChild("WoodSection")
    if not leaves or not wood then return nil end

    local isBlack = false

    if wood:IsA("BasePart") and
        (wood.BrickColor.Name == "Really black"
        or wood.Color == Color3.fromRGB(0, 0, 0)) then
        isBlack = true
    elseif leaves:IsA("BasePart") and
        (leaves.BrickColor.Name == "Really black"
        or leaves.Color == Color3.fromRGB(0, 0, 0)) then
        isBlack = true
    end

    if not isBlack then return nil end

    local magnitude = tree:GetExtentsSize().Magnitude
    local treeSize = "small"

    if magnitude > 40 then
        treeSize = "large"
    elseif magnitude > 20 then
        treeSize = "medium"
    end

    if Config.SizeOption == "all"
        or Config.SizeOption == treeSize then
        return tree
    end

    return nil
end

local function TeleportToTree(tree)
    local char = LocalPlayer.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = CFrame.new(
        tree:GetPivot().Position + Vector3.new(0, 5, 0)
    )
end

local function HopServer()
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        game.PlaceId
    )

    local success, response = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if not success or not response or not response.data then
        warn("Failed to retrieve servers.")
        return
    end

    for _, server in ipairs(response.data) do
        if server.playing < server.maxPlayers
            and server.id ~= game.JobId then

            TeleportService:TeleportToPlaceInstance(
                game.PlaceId,
                server.id,
                LocalPlayer
            )
            return
        end
    end

    warn("No available servers found.")
end

local function CreateUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "TreeAutoHopUI"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 220)
    frame.Position = UDim2.new(0.5, -125, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    title.Text = "Auto Hop Tree Finder"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Parent = frame

    local sizeFrame = Instance.new("Frame")
    sizeFrame.Size = UDim2.new(1, -20, 0, 40)
    sizeFrame.Position = UDim2.new(0, 10, 0, 40)
    sizeFrame.BackgroundTransparency = 1
    sizeFrame.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 5)
    layout.Parent = sizeFrame

    local sizes = {"small", "medium", "large", "all"}
    local buttons = {}

    for _, size in ipairs(sizes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 50, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn.Text = size
        btn.Parent = sizeFrame

        btn.MouseButton1Click:Connect(function()
            Config.SizeOption = size
            for _, b in ipairs(buttons) do
                b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
            btn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
        end)

        table.insert(buttons, btn)
    end

    buttons[4].BackgroundColor3 = Color3.fromRGB(0, 120, 200)

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(1, -20, 0, 40)
    toggle.Position = UDim2.new(0, 10, 0, 100)
    toggle.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    toggle.Text = "Stop"
    toggle.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 40)
    status.Position = UDim2.new(0, 10, 0, 150)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.Text = "Status: Scanning..."
    status.Parent = frame

    toggle.MouseButton1Click:Connect(function()
        Config.Running = not Config.Running
        toggle.Text = Config.Running and "Stop" or "Start"
        toggle.BackgroundColor3 = Config.Running
            and Color3.fromRGB(200, 0, 0)
            or Color3.fromRGB(0, 170, 0)
        status.Text = Config.Running
            and "Status: Scanning..."
            or "Status: Stopped"
    end)

    return status
end

local function Main()
    local status = CreateUI()

    task.spawn(function()
        while true do
            if Config.Running then
                local tree = GetTree()

                if tree then
                    status.Text = "Status: Tree found!"
                    TeleportToTree(tree)

                    while GetTree() and Config.Running do
                        task.wait(1)
                    end

                    if Config.Running then
                        status.Text = "Status: Hopping..."
                        task.wait(2)
                        HopServer()
                    end
                else
                    status.Text = "Status: No tree. Hopping..."
                    task.wait(Config.HopCooldown)
                    HopServer()
                end
            end

            task.wait(Config.CheckInterval)
        end
    end)
end

Main()

