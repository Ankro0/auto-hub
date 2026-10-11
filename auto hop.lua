-- ═══════════════════════════════════════════════════════
-- ⚡ Lightning Fast Black Tree Hop v5 (GitHub Auto-Execute)
-- ═══════════════════════════════════════════════════════

-- 🔴🔴🔴 ضع رابط GitHub Raw هنا 🔴🔴🔴
local SCRIPT_URL = "https://raw.githubusercontent.com/USERNAME/roblox-scripts/main/LightningTreeHop.lua"
-- ═══════════════════════════════════════════════════════

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══ كشف دوال الاكسبلوتر ═══
local requestFunc = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request

local queueTeleport = (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or queue_on_teleport

-- ═══ تفعيل الأوتو إكسكيوت عبر GitHub ═══
local function setupAutoExecute()
    if not queueTeleport then
        warn("[Lightning] ❌ الاكسبلوتر مايدعم queue_on_teleport — الأوتو إكسكيوت ماراح يشتغل")
        return false
    end

    if SCRIPT_URL:find("USERNAME") then
        warn("[Lightning] ⚠️ ما غيرتش SCRIPT_URL! حط رابط GitHub Raw بتاعك")
        return false
    end

    local ok = pcall(function()
        queueTeleport(([[
            task.wait(1)
            local ok, err = pcall(function()
                loadstring(game:HttpGet("%s"))()
            end)
            if not ok then warn("[Lightning AutoExec] " .. tostring(err)) end
        ]]):format(SCRIPT_URL))
    end)

    if ok then
        print("[Lightning] ✅ الأوتو إكسكيوت مفعّل عبر GitHub")
        return true
    end

    warn("[Lightning] ❌ فشل تفعيل الأوتو إكسكيوت")
    return false
end

setupAutoExecute()

-- ═══ حذف الواجهة القديمة ═══
if playerGui:FindFirstChild("LightningTreeHop") then
    playerGui.LightningTreeHop:Destroy()
end

-- ═══════════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════════

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LightningTreeHop"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 210)
MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(45, 45, 65)
Stroke.Thickness = 1.5
Stroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundTransparency = 1
Title.Text = "⚡ Lightning Fast Black Tree Hop"
Title.TextColor3 = Color3.fromRGB(0, 255, 170)
Title.TextSize = 12
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 35)
StatusLabel.Position = UDim2.new(0, 12, 0, 38)
StatusLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
StatusLabel.TextColor3 = Color3.fromRGB(210, 210, 225)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.Text = "الحالة: جاهز للسرعة القصوى"
StatusLabel.Parent = MainFrame

Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 8)

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(1, -24, 0, 45)
ToggleButton.Position = UDim2.new(0, 12, 0, 88)
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 190, 110)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 15
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "تشغيل (START)"
ToggleButton.Parent = MainFrame

Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 8)

local Credit = Instance.new("TextLabel")
Credit.Size = UDim2.new(1, 0, 0, 20)
Credit.Position = UDim2.new(0, 0, 1, -22)
Credit.BackgroundTransparency = 1
Credit.Text = "Lightning Engine v5"
Credit.TextColor3 = Color3.fromRGB(100, 100, 120)
Credit.TextSize = 10
Credit.Font = Enum.Font.Gotham
Credit.Parent = MainFrame

-- ═══════════════════════════════════════════════════════
-- المتغيرات
-- ═══════════════════════════════════════════════════════

local running = false
local hopping = false

-- ═══════════════════════════════════════════════════════
-- دالة الهوب
-- ═══════════════════════════════════════════════════════

local function serverHop()
    if hopping then return end
    hopping = true

    StatusLabel.Text = "الحالة: 🚀 انتقال فوري لسيرفر جديد..."

    if not requestFunc then
        StatusLabel.Text = "الحالة: ❌ الاكسبلوتر مايدعم request"
        hopping = false
        return
    end

    local success, servers = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = requestFunc({ Url = url, Method = "GET" })
        local data = HttpService:JSONDecode(res.Body)
        return data.data
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

-- ═══════════════════════════════════════════════════════
-- البحث عن الشجرة السوداء
-- ═══════════════════════════════════════════════════════

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

            if isReallyBlack then
                StatusLabel.Text = "الحالة: 🎯 تم صيد الشجرة السوداء!"
                rootPart.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                return true
            end
        end
    end

    return false
end

-- ═══════════════════════════════════════════════════════
-- الزر
-- ═══════════════════════════════════════════════════════

ToggleButton.MouseButton1Click:Connect(function()
    running = not running

    if running then
        ToggleButton.Text = "إيقاف (STOP)"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(230, 60, 60)

        task.spawn(function()
            while running do
                StatusLabel.Text = "الحالة: ⚡ فحص خاطف للشجرة السوداء..."

                if fastScan() then
                    running = false
                    ToggleButton.Text = "تشغيل (START)"
                    ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 190, 110)
                    StatusLabel.Text = "الحالة: ✅ تم الاستقرار بنجاح!"
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
    else
        ToggleButton.Text = "تشغيل (START)"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 190, 110)
        StatusLabel.Text = "الحالة: متوقف"
    end
end)
