-- Lightning Hop (autoexec version) + Size system
if not game:IsLoaded() then game.Loaded:Wait() end

local T = game:GetService("TeleportService")
local H = game:GetService("HttpService")
local P = game:GetService("Players")
local pl = P.LocalPlayer
local rq = (syn and syn.request) or (http and http.request) or http_request or request

-- ═══ نظام الحجم (Small / Medium / Large / All) ═══
-- الحجم = عدد قطع WoodSection في الشجرة. الأرقام تخمين، عدّلها لو لزم.
local SMALL_MAX = 10
local MEDIUM_MAX = 25
local SIZE_FILE = "LightningSize.txt"
local SIZES = {"Small", "Medium", "Large", "All"}

local SIZE = "All"
pcall(function()
    if isfile and readfile and isfile(SIZE_FILE) then
        local saved = readfile(SIZE_FILE)
        for _, n in ipairs(SIZES) do
            if saved == n then SIZE = n end
        end
    end
end)

local function sizeMatches(o)
    if SIZE == "All" then return true end
    local n = 0
    for _, c in ipairs(o.Parent:GetChildren()) do
        if c.Name == "WoodSection" then n = n + 1 end
    end
    if SIZE == "Small" then
        return n <= SMALL_MAX
    elseif SIZE == "Medium" then
        return n > SMALL_MAX and n <= MEDIUM_MAX
    else
        return n > MEDIUM_MAX
    end
end

-- أزرار اختيار الحجم
pcall(function()
    local pg = pl:WaitForChild("PlayerGui", 10)
    if not pg then return end
    local old = pg:FindFirstChild("LightningSize")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LightningSize"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 64)
    frame.Position = UDim2.new(0.05, 0, 0.2, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 22)
    title.BackgroundTransparency = 1
    title.Text = "Tree size"
    title.TextColor3 = Color3.fromRGB(0, 255, 170)
    title.TextSize = 12
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local buttons = {}
    local function refresh()
        for name, b in pairs(buttons) do
            b.BackgroundColor3 = (name == SIZE) and Color3.fromRGB(0, 150, 200) or Color3.fromRGB(40, 40, 58)
        end
    end

    for i, name in ipairs(SIZES) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 62, 0, 28)
        b.Position = UDim2.new(0, 8 + (i - 1) * 68, 0, 28)
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 11
        b.Font = Enum.Font.GothamBold
        b.Text = name
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        buttons[name] = b
        b.MouseButton1Click:Connect(function()
            SIZE = name
            refresh()
            -- احفظ الاختيار عشان يفضل بعد النقل بين السيرفرات
            pcall(function()
                if writefile then writefile(SIZE_FILE, SIZE) end
            end)
        end)
    end
    refresh()
end)

-- ═══ ابحث عن الشجرة ═══
local function scan()
    local c = pl.Character
    if not c then return false end
    local rp = c:FindFirstChild("HumanoidRootPart")
    if not rp then return false end
    local box = workspace:FindFirstChild("TreeRegion") or workspace
    for _, o in ipairs(box:GetDescendants()) do
        if o.Name == "WoodSection" and o:IsA("BasePart") then
            local bc = o.BrickColor
            local col = o.Color
            if (bc and bc.Name == "Really black") or (col and col.R < 0.05 and col.G < 0.05 and col.B < 0.05) then
                if sizeMatches(o) then
                    rp.CFrame = o.CFrame + Vector3.new(0, 3, 0)
                    return true
                end
            end
        end
    end
    return false
end

-- ═══ انتظر ثم افحص ثم انقل ═══
task.wait(5) -- انتظر اللعبة تحمل

-- تأكد إن الشخصية موجودة قبل الفحص (كان بيعمل hop من غير ما يفحص لو لسه محملتش)
if not pl.Character then pl.CharacterAdded:Wait() end
pl.Character:WaitForChild("HumanoidRootPart", 10)

if not scan() then
    -- مافيش شجرة، انقل سيرفر
    if rq then
        local ok, sv = pcall(function()
            local u = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            local r = rq({Url = u, Method = "GET"})
            return H:JSONDecode(r.Body).data
        end)
        if ok and sv then
            for _, s in ipairs(sv) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    pcall(function()
                        T:TeleportToPlaceInstance(game.PlaceId, s.id, pl)
                    end)
                    break
                end
            end
        end
    end
end
