local P=game:GetService("Players")local T=game:GetService("TeleportService")local H=game:GetService("HttpService")local R=game:GetService("RunService")local pl=P.LocalPlayer local pg=pl:WaitForChild("PlayerGui")local URL="https://raw.githubusercontent.com/Ankro0/auto-hub/refs/heads/main/auto%20hop.lua"local rq=(syn and syn.request)or(http and http.request)or http_request or request local qt=(syn and syn.queue_on_teleport)or(fluxus and fluxus.queue_on_teleport)or queue_on_teleport
if qt then pcall(function() qt(([[task.wait(1)pcall(function()loadstring(game:HttpGet("%s"))()end)]]):format(URL)) print("[Lightning] Auto-exec OK") end) else warn("[Lightning] No queue_on_teleport") end
if pg:FindFirstChild("LightningTreeHop") then pg.LightningTreeHop:Destroy() end
local sg=Instance.new("ScreenGui")sg.Name="LightningTreeHop"sg.ResetOnSpawn=false sg.Parent=pg
local mf=Instance.new("Frame")mf.Size=UDim2.new(0,280,0,210)mf.Position=UDim2.new(0.05,0,0.2,0)mf.BackgroundColor3=Color3.fromRGB(18,18,26)mf.BorderSizePixel=0 mf.Active=true mf.Draggable=true mf.Parent=sg
Instance.new("UICorner",mf).CornerRadius=UDim.new(0,14)
local st=Instance.new("UIStroke",mf)st.Color=Color3.fromRGB(45,45,65)st.Thickness=1.5
local ti=Instance.new("TextLabel")ti.Size=UDim2.new(1,0,0,35)ti.BackgroundTransparency=1 ti.Text="⚡ Lightning Fast Black Tree Hop"ti.TextColor3=Color3.fromRGB(0,255,170)ti.TextSize=12 ti.Font=Enum.Font.GothamBold ti.Parent=mf
local sl=Instance.new("TextLabel")sl.Size=UDim2.new(1,-24,0,35)sl.Position=UDim2.new(0,12,0,38)sl.BackgroundColor3=Color3.fromRGB(28,28,40)sl.TextColor3=Color3.fromRGB(210,210,225)sl.TextSize=11 sl.Font=Enum.Font.GothamMedium sl.Text="Status: Ready"sl.Parent=mf
Instance.new("UICorner",sl).CornerRadius=UDim.new(0,8)
local bt=Instance.new("TextButton")bt.Size=UDim2.new(1,-24,0,45)bt.Position=UDim2.new(0,12,0,88)bt.BackgroundColor3=Color3.fromRGB(0,190,110)bt.TextColor3=Color3.fromRGB(255,255,255)bt.TextSize=15 bt.Font=Enum.Font.GothamBold bt.Text="START"bt.Parent=mf
Instance.new("UICorner",bt).CornerRadius=UDim.new(0,8)
local cr=Instance.new("TextLabel")cr.Size=UDim2.new(1,0,0,20)cr.Position=UDim2.new(0,0,1,-22)cr.BackgroundTransparency=1 cr.Text="Lightning v6"cr.TextColor3=Color3.fromRGB(100,100,120)cr.TextSize=10 cr.Parent=mf
local run=false local hop=false
local function sh()
 if hop then return end hop=true sl.Text="🚀 Hopping..."
 if not rq then sl.Text="❌ No request"hop=false return end
 local ok,sv=pcall(function()
  local u="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
  local r=rq({Url=u,Method="GET"})return H:JSONDecode(r.Body).data
 end)
 if ok and sv then for _,s in ipairs(sv) do if s.playing<s.maxPlayers and s.id~=game.JobId then pcall(function() T:TeleportToPlaceInstance(game.PlaceId,s.id,pl) end)return end end end
 task.wait(1.5)hop=false if run then sh() end
end
local function fs()
 local c=pl.Character if not c then return false end
 local rp=c:FindFirstChild("HumanoidRootPart")if not rp then return false end
 local cn=workspace:FindFirstChild("TreeRegion")or workspace
 for _,o in ipairs(cn:GetDescendants())do
  if o.Name=="WoodSection"and o:IsA("BasePart")then
   local bc=o.BrickColor local c3=o.Color
   if(bc and bc.Name=="Really black")or(c3 and c3.R<0.05 and c3.G<0.05 and c3.B<0.05)then
    sl.Text="🎯 Found!"rp.CFrame=o.CFrame+Vector3.new(0,3,0)return true
   end
  end
 end
 return false
end
bt.MouseButton1Click:Connect(function()
 run=not run
 if run then
  bt.Text="STOP"bt.BackgroundColor3=Color3.fromRGB(230,60,60)
  task.spawn(function()
   while run do
    sl.Text="⚡ Scanning..."
    if fs()then run=false bt.Text="START"bt.BackgroundColor3=Color3.fromRGB(0,190,110)sl.Text="✅ Done!"break
    else if run then sh()break end end
    R.RenderStepped:Wait()
   end
  end)
 else
  bt.Text="START"bt.BackgroundColor3=Color3.fromRGB(0,190,110)sl.Text="Stopped"
 end
end)
