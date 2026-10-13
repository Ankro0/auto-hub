
-- ==========================================
-- Black Tree Finder | Auto Hop
-- ==========================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Player = Players.LocalPlayer

local URL = "https://raw.githubusercontent.com/Ankro0/auto-hub/refs/heads/main/auto%20hop.lua"

local Config = {
    Running = true,
    SizeOption = "all",
    CheckInterval = 1,
    HopCooldown = 5,
    TargetColor = Color3.fromRGB(0, 0, 0),
}

-- إعادة التشغيل بعد الانتقال
local queue = queue_on_teleport
    or (syn and syn.queue_on_teleport)

if queue then
    pcall(function()
        queue('loadstring(game:HttpGet("' .. URL .. '", true))()')
    end)
end

-- إزالة الواجهة القديمة
pcall(function()
    local gui = Player.PlayerGui:FindFirstChild("TreeAutoHopUI")
    if gui then gui:Destroy() end
end)

-- ==========================================
-- فحص لون الجذع
-- ==========================================

local function IsBlack(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    return part.BrickColor.Name == "Really black"
        or (
            part.Color.R == 0
            and part.Color.G == 0
            and part.Color.B == 0
        )
end

local function GetTreeSize(model)
    local ok, extents = pcall(function()
        return model:GetExtentsSize()
    end)

    if not ok then return "small" end

    local magnitude = extents.Magnitude

    if magnitude > 40 then
        return "large"
    elseif magnitude > 20 then
        return "medium"
    end

    return "small"
end

local function FindBlackTree()
    for _, model in ipairs(Workspace:GetDescendants()) do
        if not Config.Running then
            return nil
        end

        if model:IsA("Model") then
            local name = model.Name:lower()

            local looksLikeTree =
                name:find("tree")
                or model:FindFirstChild("TreeClass", true) ~= nil
                or model:FindFirstChild("WoodSection", true) ~= nil

            if looksLikeTree then
                local blackWood = false

                for _, part in ipairs(model:GetDescendants()) do
                    if part.Name == "WoodSection"
                        and IsBlack(part) then
                        blackWood = true
                        break
                    end
                end

                if blackWood then
                    local size = GetTreeSize(model)

                    if Config.SizeOption == "all"
                        or Config.SizeOption == size then
                        return model
                    end
                end
            end
        end
    end

    return nil
end

-- ==========================================
-- الانتقال للشجرة
-- ==========================================

local function TeleportToTree(tree)
    local character = Player.Character
    local root = character
        and character:FindFirstChild("HumanoidRootPart")

    if not root or not tree.Parent then
        return false
    end

    local ok, pivot = pcall(function()
        return tree:GetPivot()
    end)

    if not ok then return false end

    root.CFrame = CFrame.new(
        pivot.Position + Vector3.new(0, 5, 0)
    )

    return true
end

-- ==========================================
-- الانتقال لسيرفر آخر
-- ==========================================

local function HopServer()
    local endpoint = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        game.PlaceId
    )

    local ok, body = pcall(function()
        return game:HttpGet(endpoint)
    end)

    if not ok then
        warn("تعذر جلب قائمة السيرفرات")
        return false
    end

    local decodedOK, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not decodedOK or not data.data then
        warn("استجابة السيرفرات غير صالحة")
        return false
    end

    local candidates = {}

    for _, server in ipairs(data.data) do
        if server.id ~= game.JobId
            and server.playing < server.maxPlayers then
            table.insert(candidates, server.id)
        end
    end

    if #candidates == 0 then
        warn("مفيش سيرفر متاح في الصفحة دي")
        return false
    end

    local target = candidates[math.random(#candidates)]

    local tpOK, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(
            game.PlaceId,
            target,
            Player
        )
    end)

    if not tpOK then
        warn("فشل الانتقال: " .. tostring(err))
    end

    return tpOK
end

-- ==========================================
-- الواجهة
-- ==========================================

local gui = Instance.new("ScreenGui")
gui.Name = "TreeAutoHopUI"
gui.ResetOnSpawn = false
gui.Parent = Player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 220)
frame.Position = UDim2.new(0.5, -130, 0.5, -110)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
title.Text = "Black Tree Auto Hop"
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = frame

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(10, 38)
status.Size = UDim2.new(1, -20, 0, 45)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.Text = "جاري البحث..."
status.Parent = frame

local sizes = {"small", "medium", "large", "all"}
local buttons = {}

for i, size in ipairs(sizes) do
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(56, 30)
    button.Position = UDim2.fromOffset(8 + (i - 1) * 62, 92)
    button.Text = size
    button.Parent = frame

    button.MouseButton1Click:Connect(function()
        Config.SizeOption = size

        for _, b in pairs(buttons) do
            b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end

        button.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    end)

    buttons[i] = button
end

buttons[4].BackgroundColor3 = Color3.fromRGB(0, 120, 200)

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -20, 0, 38)
toggle.Position = UDim2.fromOffset(10, 140)
toggle.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Text = "Stop"
toggle.Parent = frame

toggle.MouseButton1Click:Connect(function()
    Config.Running = not Config.Running
    toggle.Text = Config.Running and "Stop" or "Start"
    status.Text = Config.Running and "جاري البحث..." or "تم الإيقاف"
end)

-- ==========================================
-- التشغيل التلقائي
-- ==========================================

task.spawn(function()
    while gui.Parent do
        if Config.Running then
            status.Text = "بيفحص الشجر الأسود..."

            local ok, tree = pcall(FindBlackTree)

            if not Config.Running then
                task.wait(0.2)

            elseif ok and tree then
                status.Text = "لقينا شجرة سودا!"

                if TeleportToTree(tree) then
                    status.Text = "وصلت للشجرة"
                else
                    status.Text = "الشجرة اختفت، هكمل بحث"
                end

                task.wait(2)

            else
                status.Text = "مفيش شجرة مطابقة، بغيّر السيرفر..."
                task.wait(Config.HopCooldown)

                if Config.Running then
                    HopServer()
                    task.wait(3)
                end
            end
        else
            task.wait(0.5)
        end

        task.wait(Config.CheckInterval)
    end
end)
