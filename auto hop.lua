
-- Black Tree Finder | GUI
-- Starts OFF. Only START begins the loop.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local Running = false
local Busy = false
local SizeOption = "all"
local CheckInterval = 1.0
local HopCooldown = 4
local TeleportRetries = 3

-- Remove previous GUI
local playerGui = Player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("BlackTreeFinderUI")
if old then old:Destroy() end

local function getRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isBlack(part)
    return part
        and part:IsA("BasePart")
        and part.BrickColor.Name == "Really black"
end

local function matchesSize(model)
    if SizeOption == "all" then return true end

    local ok, size = pcall(function()
        return model:GetExtentsSize().Magnitude
    end)
    if not ok then return false end

    if SizeOption == "small" then return size <= 20 end
    if SizeOption == "medium" then
        return size > 20 and size <= 40
    end
    if SizeOption == "large" then return size > 40 end

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

local function teleportToTree(model, wood)
    for attempt = 1, TeleportRetries do
        if not Running then return false end

        local root = getRoot()
        if not root or not model.Parent or not wood.Parent then
            return false
        end

        -- Move beside the wood section, above the ground
        local target = wood.Position + Vector3.new(0, 5, 0)

        local ok = pcall(function()
            root.CFrame = CFrame.new(target)
        end)

        task.wait(0.7)

        root = getRoot()
        if ok and root
            and (root.Position - target).Magnitude < 10 then
            return true
        end
    end

    return false
end

local function hopServer(setStatus)
    if not Running then return false end
    setStatus("Searching for another server...")

    task.wait(HopCooldown)
    if not Running then return false end

    local url = "https://games.roblox.com/v1/games/"
        .. game.PlaceId
        .. "/servers/Public?sortOrder=Asc&limit=100"

    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if not ok or not data or not data.data then
        setStatus("Hop failed: HTTP request error")
        return false
    end

    for _, server in ipairs(data.data) do
        if not Running then return false end

        if server.id ~= game.JobId
            and server.playing < server.maxPlayers then

            setStatus("Teleporting to new server...")
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(
                    game.PlaceId,
                    server.id,
                    Player
                )
            end)

            if success then
                return true
            else
                warn("Server hop error:", err)
            end
        end
    end

    setStatus("No available server found")
    return false
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "BlackTreeFinderUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

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
    obj.Parent = parent
    return obj
end

label(main, "BLACK TREE FINDER", UDim2.fromOffset(16, 10),
    UDim2.new(1, -32, 0, 30),
    Color3.fromRGB(130, 170, 255), 18).TextXAlignment =
    Enum.TextXAlignment.Left

label(main, "AUTO TELEPORT  •  SERVER HOP",
    UDim2.fromOffset(16, 40), UDim2.new(1, -32, 0, 20),
    Color3.fromRGB(160, 165, 180), 10).TextXAlignment =
    Enum.TextXAlignment.Left

local statusLabel = label(main, "● STOPPED",
    UDim2.fromOffset(16, 68), UDim2.new(1, -32, 0, 28),
    Color3.fromRGB(255, 190, 90), 14)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(text)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = "● " .. text
    end
end

label(main, "TREE SIZE", UDim2.fromOffset(16, 105),
    UDim2.new(1, -32, 0, 20),
    Color3.fromRGB(200, 205, 220), 12).TextXAlignment =
    Enum.TextXAlignment.Left

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
local options = {"small", "medium", "large", "all"}

local function refreshSizes()
    for name, button in pairs(sizeButtons) do
        button.BackgroundColor3 = name == SizeOption
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
            SizeOption = name
            refreshSizes()
        end
    )
end
refreshSizes()

local startButton = makeButton(
    "START", 16, 185, 140, 42,
    Color3.fromRGB(35, 160, 100),
    function()
        if Running then return end
        Running = true
        setStatus("RUNNING")
    end
)

local stopButton = makeButton(
    "STOP", 164, 185, 140, 42,
    Color3.fromRGB(190, 60, 70),
    function()
        Running = false
        setStatus("STOPPED")
    end
)

label(main, "Starts stopped • Hop only when no tree is found",
    UDim2.fromOffset(12, 244), UDim2.new(1, -24, 0, 30),
    Color3.fromRGB(145, 150, 165), 10)

-- Main loop: no teleport or hop before START
task.spawn(function()
    while gui.Parent do
        task.wait(CheckInterval)

        if not Running or Busy then
            continue
        end

        Busy = true

        local ok, err = pcall(function()
            local model, wood = findBlackTree()

            if model and wood then
                setStatus("TREE FOUND - TELEPORTING")
                local arrived = teleportToTree(model, wood)

                if arrived then
                    setStatus("TREE REACHED")
                    task.wait(2)
                else
                    setStatus("TELEPORT RETRY FAILED")
                    task.wait(1)
                end
            else
                setStatus("NO TREE - HOPPING")
                hopServer(setStatus)
            end
        end)

        if not ok then
            warn("Black Tree Finder error:", err)
            setStatus("ERROR - CHECK CONSOLE")
            task.wait(2)
        end

        Busy = false
    end
end)
```
