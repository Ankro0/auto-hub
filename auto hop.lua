--[[
	BLACK TREE FINDER
	Pro Max Ultra Edition
	Strongest Hop + Premium GUI
]]

print("[BlackTree] Pro Max Ultra loaded")
if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local Player = Players.LocalPlayer
local Busy   = false

-- ====================== ULTRA SETTINGS ======================
local CheckInterval     = 0.15
local TeleportRetries   = 3
local RegionWait        = 4.5
local SearchWindow      = 2.0
local MaxServerPlayers  = 6
local MaxPages          = 18
local HopDelay          = 0.14
local FailRetryDelay    = 2.8
local MaxFailsBeforeSkip = 3
local STATE_FILE        = "BlackTreeFinder_Pro.json"
local SERVERS_CACHE     = "BlackTree_Servers.json"
-- ============================================================

local State = {
	running    = false,
	size       = "all",
	treeClass  = "Spooky",
	queue      = {},
	visited    = {},
	failCount  = {}
}

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
				State.running   = d.running == true
				State.size      = d.size or "all"
				State.treeClass = (type(d.treeClass) == "string" and d.treeClass ~= "") and d.treeClass or "Spooky"
				State.queue     = type(d.queue) == "table" and d.queue or {}
				State.visited   = type(d.visited) == "table" and d.visited or {}
				State.failCount = type(d.failCount) == "table" and d.failCount or {}
			end
		end
	end)
end

loadState()
State.visited[game.JobId] = true

------------------------------------------------------------------
-- Clean old UI
------------------------------------------------------------------
local playerGui = Player:WaitForChild("PlayerGui")
pcall(function()
	local old = playerGui:FindFirstChild("BlackTreeFinderUI")
	if old then old:Destroy() end
end)

------------------------------------------------------------------
-- Core Helpers
------------------------------------------------------------------
local function getRoot()
	local char = Player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function classMatches(v)
	v = string.lower(tostring(v or ""))
	local t = string.lower(State.treeClass)
	if t == "both" then
		return v == "spooky" or v == "spookyneon"
	end
	return v == t
end

local lastWoodCount = 0
local lastClasses   = ""

local function isBlack(part)
	if not (part and part:IsA("BasePart")) then return false end
	if part.BrickColor.Name == "Really black" then return true end
	local c = part.Color
	return c.R < 0.12 and c.G < 0.12 and c.B < 0.12
end

local function matchesSize(model)
	if State.size == "all" then return true end
	local ok, size = pcall(function()
		return model:GetExtentsSize().Magnitude
	end)
	if not ok then return false end
	if State.size == "small"  then return size <= 20 end
	if State.size == "medium" then return size > 20 and size <= 40 end
	if State.size == "large"  then return size > 40 end
	return true
end

local function findBlackTree()
	local region = Workspace:FindFirstChild("TreeRegion")
	if not region then return nil end

	if State.treeClass ~= "" then
		local count, seen, seenList = 0, {}, {}
		local foundModel, foundWood

		for _, obj in ipairs(region:GetDescendants()) do
			if obj.Name == "TreeClass" and obj:IsA("ValueBase") then
				count += 1
				local v = tostring(obj.Value)
				if not seen[v] then
					seen[v] = true
					table.insert(seenList, v)
				end
				if not foundModel and classMatches(v) then
					local model = obj.Parent
					if model and matchesSize(model) then
						local part = model:FindFirstChild("WoodSection", true)
						if not (part and part:IsA("BasePart")) then
							part = model:FindFirstChildWhichIsA("BasePart", true)
						end
						if part then
							foundModel, foundWood = model, part
						end
					end
				end
			end
		end

		lastWoodCount = count
		lastClasses   = table.concat(seenList, ", ")
		return foundModel, foundWood
	end

	local woods = 0
	local foundModel, foundWood

	for _, obj in ipairs(region:GetDescendants()) do
		if obj.Name == "WoodSection" and obj:IsA("BasePart") then
			woods += 1
			if not foundModel and isBlack(obj) then
				local model = obj:FindFirstAncestorOfClass("Model") or obj.Parent
				if model and matchesSize(model) then
					foundModel, foundWood = model, obj
				end
			end
		end
	end

	lastWoodCount = woods
	return foundModel, foundWood
end

local function searchTree()
	local region = Workspace:FindFirstChild("TreeRegion")
		or Workspace:WaitForChild("TreeRegion", RegionWait)
	if not region then return nil end

	local t0 = os.clock()
	repeat
		if not State.running then return nil end
		local model, wood = findBlackTree()
		if model then return model, wood end
		task.wait(0.12)
	until (os.clock() - t0) >= SearchWindow

	return nil
end

local function teleportToTree(model, wood)
	for _ = 1, TeleportRetries do
		if not State.running then return false end
		local root = getRoot()
		if not root or not model.Parent or not wood.Parent then return false end

		local target = wood.Position + Vector3.new(0, 5, 0)
		local ok = pcall(function()
			root.CFrame = CFrame.new(target)
		end)

		task.wait(0.4)
		root = getRoot()
		if ok and root and (root.Position - target).Magnitude < 14 then
			return true
		end
	end
	return false
end

------------------------------------------------------------------
-- ULTRA HOP SYSTEM
------------------------------------------------------------------
local function httpGet(url)
	local req = (syn and syn.request) or request or http_request or (http and http.request)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and res and (res.StatusCode == 200 or res.StatusCode == 0) then
			return res.Body or res.Body
		end
		return nil
	end
	local ok, body = pcall(game.HttpGet, game, url)
	return ok and body or nil
end

local function scanServers(setStatus)
	local list = {}
	local cursor = nil
	local pages = 0
	local fails = 0
	local base = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public"

	-- try load cache first
	if canFile and isfile(SERVERS_CACHE) then
		pcall(function()
			local cached = HttpService:JSONDecode(readfile(SERVERS_CACHE))
			if type(cached) == "table" and type(cached.list) == "table" and cached.placeId == game.PlaceId then
				for _, id in ipairs(cached.list) do
					if not State.visited[id] then
						table.insert(list, id)
					end
				end
			end
		end)
	end

	if #list < 8 then
		list = {}
		repeat
			if not State.running then return nil end

			local url = base .. "?sortOrder=Asc&excludeFullGames=true&limit=100"
			if cursor then url = url .. "&cursor=" .. cursor end

			setStatus("Scanning... " .. #list .. " servers")
			local body = httpGet(url)

			if body then
				local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
				if ok and type(data) == "table" and data.data then
					for _, s in ipairs(data.data) do
						if s.playing and s.maxPlayers
							and s.playing <= MaxServerPlayers
							and s.playing < s.maxPlayers
							and s.id ~= game.JobId
							and not State.visited[s.id]
							and (State.failCount[s.id] or 0) < MaxFailsBeforeSkip then
							table.insert(list, s.id)
						end
					end
					cursor = data.nextPageCursor
				else
					cursor = nil
				end
				pages += 1
				fails = 0
			else
				fails += 1
				if fails >= 5 then
					cursor = nil
				else
					setStatus("Rate limit, waiting...")
					task.wait(FailRetryDelay)
				end
			end
			task.wait(0.08)
		until not cursor or pages >= MaxPages

		-- save cache
		if canFile and #list > 0 then
			pcall(function()
				writefile(SERVERS_CACHE, HttpService:JSONEncode({
					placeId = game.PlaceId,
					list = list,
					time = os.time()
				}))
			end)
		end
	end

	-- Shuffle
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end

	return list
end

local function hopNext(setStatus)
	while State.running do
		if #State.queue == 0 then
			local list = scanServers(setStatus)
			if not list then return end

			if #list == 0 then
				State.visited = { [game.JobId] = true }
				State.failCount = {}
				saveState()
				setStatus("No servers found, retry...")
				task.wait(3.2)
			else
				State.queue = list
				saveState()
			end
		end

		if State.running and #State.queue > 0 then
			local id = table.remove(State.queue, 1)
			State.visited[id] = true
			saveState()

			setStatus("Hopping  •  " .. #State.queue .. " left")

			local failed = false
			local conn = TeleportService.TeleportInitFailed:Connect(function()
				failed = true
			end)

			local ok = pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, id, Player)
			end)
			if not ok then failed = true end

			local waited = 0
			while not failed and waited < 7.5 and State.running do
				task.wait(0.18)
				waited += 0.18
			end
			conn:Disconnect()

			if failed then
				State.failCount[id] = (State.failCount[id] or 0) + 1
				saveState()
			end

			task.wait(HopDelay)
		end
	end
end

------------------------------------------------------------------
-- PREMIUM GUI (Pro Max)
------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "BlackTreeFinderUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Main Container
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(360, 420)
main.Position = UDim2.new(0.5, -180, 0.5, -210)
main.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 100, 210)
stroke.Thickness = 1.5
stroke.Transparency = 0.35
stroke.Parent = main

-- Soft Shadow
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.fromScale(0.5, 0.5)
shadow.Size = UDim2.new(1, 60, 1, 60)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.4
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49, 49, 450, 450)
shadow.ZIndex = 0
shadow.Parent = main

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 48)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 21, 32)
titleBar.BorderSizePixel = 0
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 16)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 18)
titleFix.Position = UDim2.new(0, 0, 1, -18)
titleFix.BackgroundColor3 = Color3.fromRGB(18, 21, 32)
titleFix.BorderSizePixel = 0
titleFix.Parent = titleBar

local accent = Instance.new("Frame")
accent.Size = UDim2.new(0, 4, 0, 22)
accent.Position = UDim2.fromOffset(14, 13)
accent.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
accent.BorderSizePixel = 0
accent.Parent = titleBar
Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -110, 1, 0)
title.Position = UDim2.fromOffset(28, 0)
title.BackgroundTransparency = 1
title.Text = "BLACK TREE FINDER"
title.TextColor3 = Color3.fromRGB(160, 195, 255)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local proBadge = Instance.new("TextLabel")
proBadge.Size = UDim2.fromOffset(52, 18)
proBadge.Position = UDim2.new(1, -140, 0.5, -9)
proBadge.BackgroundColor3 = Color3.fromRGB(50, 90, 200)
proBadge.Text = "PRO"
proBadge.TextColor3 = Color3.new(1, 1, 1)
proBadge.TextSize = 10
proBadge.Font = Enum.Font.GothamBold
proBadge.Parent = titleBar
Instance.new("UICorner", proBadge).CornerRadius = UDim.new(0, 6)

-- Buttons
local function iconBtn(parent, text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(30, 30)
	b.Position = UDim2.new(1, x, 0.5, -15)
	b.BackgroundColor3 = Color3.fromRGB(32, 36, 52)
	b.Text = text
	b.TextColor3 = Color3.fromRGB(190, 195, 215)
	b.TextSize = 13
	b.Font = Enum.Font.GothamBold
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	return b
end

local closeBtn = iconBtn(titleBar, "✕", -40)
local minBtn   = iconBtn(titleBar, "—", -76)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	local target = minimized and UDim2.fromOffset(360, 48) or UDim2.fromOffset(360, 420)
	TweenService:Create(main, TweenInfo.new(0.28, Enum.EasingStyle.Quint), {Size = target}):Play()
end)

-- Drag
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)
titleBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Status Card
local statusCard = Instance.new("Frame")
statusCard.Size = UDim2.new(1, -28, 0, 52)
statusCard.Position = UDim2.fromOffset(14, 60)
statusCard.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
statusCard.BorderSizePixel = 0
statusCard.Parent = main
Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 12)

local statusStroke = Instance.new("UIStroke")
statusStroke.Color = Color3.fromRGB(40, 50, 75)
statusStroke.Thickness = 1
statusStroke.Parent = statusCard

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.fromOffset(11, 11)
statusDot.Position = UDim2.fromOffset(16, 20)
statusDot.BackgroundColor3 = Color3.fromRGB(255, 175, 55)
statusDot.BorderSizePixel = 0
statusDot.Parent = statusCard
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -45, 1, 0)
statusLabel.Position = UDim2.fromOffset(36, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "STOPPED"
statusLabel.TextColor3 = Color3.fromRGB(230, 235, 250)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusCard

local function setStatus(text, color)
	if statusLabel and statusLabel.Parent then
		statusLabel.Text = text
	end
	if statusDot and statusDot.Parent and color then
		TweenService:Create(statusDot, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play()
	end
end

-- Section helper
local function sectionTitle(text, y)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -28, 0, 16)
	t.Position = UDim2.fromOffset(16, y)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = Color3.fromRGB(120, 135, 165)
	t.TextSize = 11
	t.Font = Enum.Font.GothamBold
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = main
	return t
end

sectionTitle("TREE SIZE", 126)

local function makeBtn(text, x, y, w, h, callback)
	local b = Instance.new("TextButton")
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(w, h)
	b.BackgroundColor3 = Color3.fromRGB(28, 32, 48)
	b.Text = text
	b.TextColor3 = Color3.fromRGB(225, 230, 245)
	b.TextSize = 12
	b.Font = Enum.Font.GothamBold
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Parent = main
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
	b.MouseButton1Click:Connect(callback)
	return b
end

local activeCol   = Color3.fromRGB(55, 110, 235)
local inactiveCol = Color3.fromRGB(28, 32, 48)

local sizeButtons = {}
local sizeOpts = {"small", "medium", "large", "all"}

local function refreshSizes()
	for name, btn in pairs(sizeButtons) do
		btn.BackgroundColor3 = (name == State.size) and activeCol or inactiveCol
	end
end

for i, name in ipairs(sizeOpts) do
	sizeButtons[name] = makeBtn(string.upper(name), 16 + (i-1)*84, 146, 78, 34, function()
		State.size = name
		saveState()
		refreshSizes()
	end)
end
refreshSizes()

sectionTitle("TREE CLASS", 192)

local classButtons = {}
local classOpts = {
	{"SPOOKY", "Spooky"},
	{"NEON", "SpookyNeon"},
	{"BOTH", "Both"},
}

local function refreshClasses()
	for value, btn in pairs(classButtons) do
		btn.BackgroundColor3 = (string.lower(value) == string.lower(State.treeClass)) and activeCol or inactiveCol
	end
end

for i, opt in ipairs(classOpts) do
	classButtons[opt[2]] = makeBtn(opt[1], 16 + (i-1)*110, 212, 104, 36, function()
		State.treeClass = opt[2]
		saveState()
		refreshClasses()
	end)
end
refreshClasses()

-- Start / Stop
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.fromOffset(158, 48)
startBtn.Position = UDim2.fromOffset(16, 268)
startBtn.BackgroundColor3 = Color3.fromRGB(28, 160, 95)
startBtn.Text = "START"
startBtn.TextColor3 = Color3.new(1, 1, 1)
startBtn.TextSize = 16
startBtn.Font = Enum.Font.GothamBold
startBtn.BorderSizePixel = 0
startBtn.Parent = main
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 11)

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.fromOffset(158, 48)
stopBtn.Position = UDim2.fromOffset(186, 268)
stopBtn.BackgroundColor3 = Color3.fromRGB(185, 48, 58)
stopBtn.Text = "STOP"
stopBtn.TextColor3 = Color3.new(1, 1, 1)
stopBtn.TextSize = 16
stopBtn.Font = Enum.Font.GothamBold
stopBtn.BorderSizePixel = 0
stopBtn.Parent = main
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 11)

startBtn.MouseButton1Click:Connect(function()
	if State.running then return end
	State.running = true
	State.queue = {}
	State.visited = {[game.JobId] = true}
	saveState()
	setStatus("RUNNING", Color3.fromRGB(50, 220, 120))
end)

stopBtn.MouseButton1Click:Connect(function()
	State.running = false
	State.queue = {}
	saveState()
	setStatus("STOPPED", Color3.fromRGB(255, 175, 55))
end)

-- Footer
local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -28, 0, 18)
footer.Position = UDim2.fromOffset(14, 335)
footer.BackgroundTransparency = 1
footer.Text = "Pro Max Ultra  •  Strongest Hop Engine"
footer.TextColor3 = Color3.fromRGB(90, 105, 140)
footer.TextSize = 11
footer.Font = Enum.Font.Gotham
footer.Parent = main

local ver = Instance.new("TextLabel")
ver.Size = UDim2.new(1, -28, 0, 16)
ver.Position = UDim2.fromOffset(14, 358)
ver.BackgroundTransparency = 1
ver.Text = "v3.0 Ultra"
ver.TextColor3 = Color3.fromRGB(60, 75, 110)
ver.TextSize = 10
ver.Font = Enum.Font.Gotham
ver.Parent = main

if State.running then
	setStatus("RESUMING...", Color3.fromRGB(70, 170, 255))
end

------------------------------------------------------------------
-- Main Loop
------------------------------------------------------------------
local function step()
	setStatus("Searching tree...", Color3.fromRGB(80, 160, 255))
	local model, wood = searchTree()

	if not State.running then return end

	if model and wood then
		setStatus("TREE FOUND!", Color3.fromRGB(50, 230, 130))
		if teleportToTree(model, wood) then
			State.running = false
			State.queue = {}
			saveState()
			setStatus("TREE REACHED ✓", Color3.fromRGB(40, 220, 120))
			return
		end
		setStatus("TP failed → Hop", Color3.fromRGB(255, 160, 60))
	else
		setStatus("No tree (" .. lastWoodCount .. ") → Hop", Color3.fromRGB(255, 170, 70))
		print("[BlackTree] no tree | woods:", lastWoodCount, "| classes:", lastClasses)
	end

	hopNext(setStatus)
end

task.spawn(function()
	while gui.Parent do
		if State.running and not Busy then
			Busy = true
			local ok, err = pcall(step)
			if not ok then
				warn("[BlackTree] error:", err)
				setStatus("ERROR", Color3.fromRGB(255, 70, 70))
				task.wait(1.4)
			end
			Busy = false
		end
		task.wait(CheckInterval)
	end
end)
