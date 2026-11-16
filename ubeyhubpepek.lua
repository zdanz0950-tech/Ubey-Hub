-- ==============================================================================
-- UBEY HUB V4 | FISHING (game baru)
-- Key divalidasi di Supabase Edge Function (verify-key).
-- + Auto Summit (CP muncul berurutan saat dekat)
-- + Fix: GUI di gethui (tanpa suara klik game), tombol lebih mudah ditekan di HP
-- + Auto Diamond: sentuh dari jauh (tanpa TP), cadangan TP singkat lalu kembali
-- ==============================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ====== TAMPILAN ======
local HUB_TITLE = "UBEY HUB"
local HUB_DISCORD = "discord.gg/YXuYeEpnXE"
local DISCORD_LINK = "https://discord.gg/YXuYeEpnXE"
local LOGO_ASSET = "rbxassetid://90770802417381"

-- ====== SERVER VERIFIKASI ======
local FUNCTION_URL = "https://vwwxvemxeztfiyuurhro.supabase.co/functions/v1/verify-key"
local SUPABASE_ANON_KEY = "sb_publishable_rMWL7Qrjw9iG0c29vGZ0bw_O3swXT6n"
local HEARTBEAT_INTERVAL = 120

getgenv().TotalFishCaught = 0
getgenv().SessionStartTime = os.time()

------------------------------------------------------------------
-- SESSION
------------------------------------------------------------------
local Session = {token = nil, key = nil, expiresAt = 0}

local function IsVerified()
	return Session.token ~= nil and os.time() < Session.expiresAt
end

local function StopAll()
	getgenv().AutoFishRunning = false
	getgenv().AutoSellRunning = false
	getgenv().HideNameRunning = false
	getgenv().FishLoopId = (getgenv().FishLoopId or 0) + 1
	getgenv().SellLoopId = (getgenv().SellLoopId or 0) + 1
	getgenv().AutoDiamondRunning = false
	getgenv().DiamondLoopId = (getgenv().DiamondLoopId or 0) + 1
	getgenv().AutoSummitRunning = false
	getgenv().SummitLoopId = (getgenv().SummitLoopId or 0) + 1
end

local Lock

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------
local CONFIG_FILE = "UbeyHubV4_Config.json"
local KEY_FILE = "UbeyHubV3_SavedKey.txt"

local function DefaultConfig()
	return {
		AutoSellTimer = "5",
		SummitDelay = "2",
		AntiAdminEnabled = false, TargetGroupId = "0"
	}
end
getgenv().UbeyConfig = DefaultConfig()

local function SaveConfig()
	pcall(function()
		if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(getgenv().UbeyConfig)) end
	end)
end

local function LoadConfig()
	pcall(function()
		if readfile and isfile and isfile(CONFIG_FILE) then
			local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
			if ok and type(data) == "table" then
				for k, _ in pairs(DefaultConfig()) do
					if data[k] ~= nil then getgenv().UbeyConfig[k] = data[k] end
				end
			end
		end
	end)
end

local function ResetConfig()
	pcall(function()
		getgenv().UbeyConfig = DefaultConfig()
		if delfile and isfile then
			if isfile(CONFIG_FILE) then delfile(CONFIG_FILE) end
			if isfile(KEY_FILE) then delfile(KEY_FILE) end
		end
	end)
end

LoadConfig()

local function Num(key)
	return tonumber(getgenv().UbeyConfig[key]) or tonumber(DefaultConfig()[key]) or 0
end

------------------------------------------------------------------
-- HWID & REQUEST
------------------------------------------------------------------
local function GetDeviceHWID()
	local hwid = nil
	pcall(function()
		if gethwid then hwid = gethwid()
		elseif RbxAnalyticsService then hwid = RbxAnalyticsService:GetClientId() end
	end)
	return tostring(hwid or ("UNKNOWN_DEVICE_" .. tostring(LocalPlayer.UserId)))
end
local CurrentHWID = GetDeviceHWID()

local function GetRequestFunc()
	return (syn and syn.request) or (http and http.request) or request or (fluxus and fluxus.request)
end

local function CallServer(body)
	local req = GetRequestFunc()
	if not req then return nil, "Executor tidak mendukung request HTTP." end
	local ok, res = pcall(req, {
		Url = FUNCTION_URL, Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["apikey"] = SUPABASE_ANON_KEY,
			["Authorization"] = "Bearer " .. SUPABASE_ANON_KEY
		},
		Body = HttpService:JSONEncode(body)
	})
	if not ok or not res then return nil, "Gagal terhubung ke server verifikasi." end
	local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body or "") end)
	if not ok2 or type(data) ~= "table" then return nil, "Respon server tidak valid." end
	return data
end

------------------------------------------------------------------
-- AUTO RECONNECT
------------------------------------------------------------------
task.spawn(function()
	pcall(function()
		CoreGui.ChildAdded:Connect(function(child)
			if child.Name == "ErrorPrompt" or child.Name == "DisconnectPrompt" then
				task.wait(1)
				pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
			end
		end)
	end)
end)

------------------------------------------------------------------
-- FISHING CORE (Cast -> AuthorizeCatch -> FishGiver -> CleanupCast)
------------------------------------------------------------------
getgenv().AutoFishRunning = false
getgenv().AutoSellRunning = false
getgenv().HideNameRunning = false
getgenv().AntiAFKRunning = false
getgenv().FakeNameInput = "UBEY HUB"
getgenv().FishLoopId = 0
getgenv().SellLoopId = 0

local function R(n)
	for _, v in ipairs(game:GetDescendants()) do
		if v.Name == n and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then return v end
	end
end

local Cast, Auth, Giver, Cleanup, Equip, GetData, SellAll
local function LoadRemotes()
	Cast, Auth, Giver, Cleanup = R("CastReplication"), R("AuthorizeCatch"), R("FishGiver"), R("CleanupCast")
	Equip, GetData, SellAll = R("Inventory_EquipRod"), R("Inventory_GetData"), R("Inventory_SellAll")
	return Cast and Auth and Giver and Cleanup
end
LoadRemotes()

-- panggil remote dengan batas waktu 5 detik (anti macet)
local function SafeCall(r, ...)
	local args = table.pack(...)
	local done, ok, res = false, false, nil
	task.spawn(function()
		ok, res = pcall(function()
			if r:IsA("RemoteFunction") then return r:InvokeServer(table.unpack(args, 1, args.n)) end
			r:FireServer(table.unpack(args, 1, args.n))
			return true
		end)
		done = true
	end)
	local t = 0
	while not done and t < 5 do
		task.wait(0.1)
		t = t + 0.1
	end
	return done and ok, res
end

-- Rod otomatis: ambil rod terakhir dari server, cadangan dari tool
local currentRod = "Basic Rod"
local function DetectRod()
	if GetData and GetData:IsA("RemoteFunction") then
		local ok, data = SafeCall(GetData)
		if ok and type(data) == "table" and type(data.LastRod) == "string" and data.LastRod ~= "" then
			return data.LastRod
		end
	end
	for _, h in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack")}) do
		if h then
			for _, t in ipairs(h:GetChildren()) do
				if t:IsA("Tool") and string.find(string.lower(t.Name), "rod") then return t.Name end
			end
		end
	end
end

local function RefreshRod()
	local r = DetectRod()
	if r then currentRod = r end
	return currentRod
end

local SetFishStatus = function() end
local TgFish
local SellBusy = false
local CollectBusy = false
local CycleBusy = false
local BITE_WAIT = 1   -- jeda setelah lempar
local REEL_WAIT = 2.5 -- jeda sebelum ikan diambil

local function FishOnce(id, cycle)
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then SetFishStatus("Karakter tidak ada") task.wait(1) return end
	if cycle % 10 == 1 then RefreshRod() end

	local look = hrp.CFrame.LookVector
	local origin = hrp.Position
	local dir = Vector3.new(look.X * 25, 5, look.Z * 25)
	local land = origin + Vector3.new(look.X * 9.2, -10.2, look.Z * 9.2)

	SetFishStatus("Rod: " .. currentRod .. " | Melempar...")
	Cast:FireServer(origin, dir, currentRod, math.random(95, 100))

	task.wait(BITE_WAIT)
	if not getgenv().AutoFishRunning or getgenv().FishLoopId ~= id then return end

	local ok, res = pcall(function() return Auth:InvokeServer(land) end)
	if not ok or type(res) ~= "table" or not res.token then
		SetFishStatus("AuthorizeCatch gagal, ulang...")
		pcall(function() Cleanup:FireServer() end)
		RefreshRod()
		task.wait(2)
		return
	end

	local name = res.fish and res.fish.name or "?"
	local rarity = res.fish and res.fish.rarity or "?"
	task.wait(REEL_WAIT)
	if not getgenv().AutoFishRunning or getgenv().FishLoopId ~= id then return end

	Giver:FireServer({token = res.token})
	Cleanup:FireServer()
	getgenv().TotalFishCaught = getgenv().TotalFishCaught + 1
	SetFishStatus(string.format("%s (%s)\nRod: %s", name, rarity, currentRod))
	task.wait(0.3)
end

local function StartFishingLoop()
	getgenv().FishLoopId = getgenv().FishLoopId + 1
	local myId = getgenv().FishLoopId
	task.spawn(function()
		if not (Cast and Auth and Giver and Cleanup) and not LoadRemotes() then
			SetFishStatus("Remote fishing tidak ketemu")
			getgenv().AutoFishRunning = false
			if TgFish then TgFish.Set(false) end
			return
		end
		RefreshRod()
		pcall(function() if Equip then Equip:FireServer(currentRod) end end)
		task.wait(0.5)
		local cycle = 0
		while getgenv().AutoFishRunning and getgenv().FishLoopId == myId do
			if not IsVerified() then getgenv().AutoFishRunning = false break end
			cycle = cycle + 1
			while (SellBusy or CollectBusy) and getgenv().AutoFishRunning and getgenv().FishLoopId == myId do
				task.wait(0.2)
			end
			if not getgenv().AutoFishRunning or getgenv().FishLoopId ~= myId then break end
			CycleBusy = true
			local ok, err = pcall(FishOnce, myId, cycle)
			CycleBusy = false
			if not ok then SetFishStatus("Error: " .. tostring(err)) task.wait(2) end
		end
	end)
end

------------------------------------------------------------------
-- AUTO SELL (Inventory_SellAll, tanpa teleport)
------------------------------------------------------------------
local function DoSell()
	if SellBusy then return false, "Sedang jual" end
	if not SellAll then SellAll = R("Inventory_SellAll") end
	if not SellAll then return false, "Remote tidak ada" end
	SellBusy = true
	task.wait(0.5)
	local ok = SafeCall(SellAll)
	task.wait(0.5)
	SellBusy = false
	if ok then return true, "Terjual ✓" end
	return false, "Gagal jual"
end

-- ==============================================================================
-- GUI SETUP
-- ==============================================================================
-- GUI dipasang di gethui() supaya script UI game (suara klik, dll) tidak
-- ikut menempel ke tombol kita. Kalau executor tidak punya gethui, pakai PlayerGui.
local function GetGuiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	return PlayerGui
end
local GuiParent = GetGuiParent()

pcall(function()
	for _, p in ipairs({GuiParent, PlayerGui}) do
		local old = p:FindFirstChild("UbeyHub")
		if old then old:Destroy() end
	end
end)

local Gui = Instance.new("ScreenGui")
Gui.Name = "UbeyHub"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 999
Gui.Parent = GuiParent

local C = {
	bg = Color3.fromRGB(9, 12, 26), side = Color3.fromRGB(13, 17, 36),
	card = Color3.fromRGB(15, 21, 44), line = Color3.fromRGB(30, 42, 90),
	accent = Color3.fromRGB(45, 95, 255), off = Color3.fromRGB(32, 44, 105),
	text = Color3.fromRGB(240, 243, 255), sub = Color3.fromRGB(150, 160, 195),
	good = Color3.fromRGB(0, 230, 150), bad = Color3.fromRGB(255, 80, 80),
	warn = Color3.fromRGB(255, 200, 0)
}

local function New(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function Round(o, r) return New("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function Label(parent, text, size, color, font, pos, sz, align)
	return New("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = font, Position = pos or UDim2.new(), Size = sz or UDim2.new(1, 0, 1, 0),
		TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
	}, parent)
end

local DRAG_THRESHOLD = 15 -- piksel; lebih besar supaya tap di HP tidak dianggap geser

local function MakeDraggable(obj, handle)
	handle = handle or obj
	local dragging, dragInput, dragStart, startPos, moved
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			dragStart, startPos = input.Position, obj.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local d = input.Position - dragStart
			if d.Magnitude > DRAG_THRESHOLD then moved = true end
			if moved then
				obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	return function() return moved end
end

------------------------------------------------------------------
-- KEY FRAME
------------------------------------------------------------------
local KeyFrame = New("Frame", {
	Size = UDim2.new(0, 400, 0, 262), Position = UDim2.new(0.5, -200, 0.5, -131),
	BackgroundColor3 = C.bg, Visible = false, Active = true
}, Gui)
Round(KeyFrame, 14)
New("UIStroke", {Color = C.line, Thickness = 1.5}, KeyFrame)
MakeDraggable(KeyFrame)

Label(KeyFrame, HUB_TITLE .. " • Key System", 16, C.text, Enum.Font.GothamBold, UDim2.new(0, 20, 0, 14), UDim2.new(1, -40, 0, 22))
Label(KeyFrame, HUB_DISCORD, 11, C.sub, Enum.Font.Gotham, UDim2.new(0, 20, 0, 36), UDim2.new(1, -40, 0, 16))
Label(KeyFrame, "Masukkan key dari bot Discord untuk melanjutkan.", 12, C.sub, Enum.Font.Gotham, UDim2.new(0, 20, 0, 62), UDim2.new(1, -40, 0, 18))

local KeyBox = New("TextBox", {
	Size = UDim2.new(1, -40, 0, 40), Position = UDim2.new(0, 20, 0, 88),
	BackgroundColor3 = C.card, PlaceholderText = "Paste key di sini...", PlaceholderColor3 = C.sub,
	Text = "", TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false
}, KeyFrame)
Round(KeyBox, 10)
New("UIStroke", {Color = C.line}, KeyBox)

local SubmitKeyBtn = New("TextButton", {
	Size = UDim2.new(0.5, -26, 0, 38), Position = UDim2.new(0, 20, 0, 140),
	BackgroundColor3 = C.accent, Text = "Verifikasi Key", TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 13
}, KeyFrame)
Round(SubmitKeyBtn, 10)

local GetKeyDiscordBtn = New("TextButton", {
	Size = UDim2.new(0.5, -26, 0, 38), Position = UDim2.new(0.5, 6, 0, 140),
	BackgroundColor3 = Color3.fromRGB(88, 101, 242), Text = "Get Key (Discord)", TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 13
}, KeyFrame)
Round(GetKeyDiscordBtn, 10)

local StatusKey = Label(KeyFrame, "", 12, C.bad, Enum.Font.Gotham, UDim2.new(0, 20, 0, 188), UDim2.new(1, -40, 0, 22), Enum.TextXAlignment.Center)

local Disclosure = Label(KeyFrame, "Saat verifikasi, username Roblox & ID perangkat (HWID) dikirim ke server untuk mengikat key ke akunmu.",
	10, C.sub, Enum.Font.Gotham, UDim2.new(0, 20, 0, 214), UDim2.new(1, -40, 0, 36), Enum.TextXAlignment.Center)
Disclosure.TextWrapped = true
Disclosure.TextTruncate = Enum.TextTruncate.None

------------------------------------------------------------------
-- MAIN WINDOW
------------------------------------------------------------------
local WIN_W, WIN_H = 580, 370
local Main = New("Frame", {
	Size = UDim2.new(0, WIN_W, 0, WIN_H), Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
	BackgroundColor3 = C.bg, Visible = false, ClipsDescendants = true, Active = true
}, Gui)
Round(Main, 14)
New("UIStroke", {Color = C.line, Thickness = 1.5}, Main)

local Header = New("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1}, Main)
MakeDraggable(Main, Header)
Label(Header, HUB_TITLE, 15, C.text, Enum.Font.GothamBold, UDim2.new(0, 16, 0, 5), UDim2.new(0, 110, 0, 20))
Label(Header, "PREMIUM", 10, C.warn, Enum.Font.GothamBold, UDim2.new(0, 16, 0, 23), UDim2.new(0, 110, 0, 14))
Label(Header, HUB_DISCORD, 10, C.sub, Enum.Font.Gotham, UDim2.new(0, 112, 0, 0), UDim2.new(0, 130, 1, 0))
local StatLabel = Label(Header, "📡 -- ms", 11, C.accent, Enum.Font.GothamBold, UDim2.new(0, 245, 0, 0), UDim2.new(1, -330, 1, 0), Enum.TextXAlignment.Right)

local MinimizeBtn = New("TextButton", {
	Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -80, 0, 4), BackgroundTransparency = 1,
	Text = "—", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 16
}, Header)
local CloseBtn = New("TextButton", {
	Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -44, 0, 4), BackgroundTransparency = 1,
	Text = "✕", TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 16
}, Header)

local Body = New("Frame", {Size = UDim2.new(1, 0, 1, -42), Position = UDim2.new(0, 0, 0, 42), BackgroundTransparency = 1}, Main)

-- Sidebar: scroll dimatikan karena 9 tab sudah muat (supaya tap tidak dibaca sebagai scroll)
local Sidebar = New("ScrollingFrame", {
	Size = UDim2.new(0, 150, 1, -10), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1,
	ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
	ScrollingEnabled = false
}, Body)
New("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, Sidebar)

New("Frame", {Size = UDim2.new(0, 2, 1, -24), Position = UDim2.new(0, 166, 0, 4), BackgroundColor3 = C.accent, BorderSizePixel = 0}, Body)

local Content = New("Frame", {Size = UDim2.new(1, -186, 1, 0), Position = UDim2.new(0, 178, 0, 0), BackgroundTransparency = 1}, Body)
local PageTitle = Label(Content, "", 19, C.text, Enum.Font.GothamBold, UDim2.new(0, 2, 0, 0), UDim2.new(1, 0, 0, 30))
local PagesHolder = New("Frame", {Size = UDim2.new(1, 0, 1, -44), Position = UDim2.new(0, 0, 0, 38), BackgroundTransparency = 1}, Content)

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	Body.Visible = not isMinimized
	TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
		Size = UDim2.new(0, WIN_W, 0, isMinimized and 42 or WIN_H)
	}):Play()
end)
CloseBtn.MouseButton1Click:Connect(function() Main.Visible = false end)

-- Ping | total ikan | waktu main
task.spawn(function()
	while true do
		pcall(function()
			local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
			local elapsed = os.time() - getgenv().SessionStartTime
			local h, m, s = math.floor(elapsed / 3600), math.floor((elapsed % 3600) / 60), elapsed % 60
			local t = h > 0 and string.format("%dh %02dm", h, m) or string.format("%02dm %02ds", m, s)
			StatLabel.Text = string.format("📡 %d ms  |  🐟 %d  |  ⏱ %s", ping, getgenv().TotalFishCaught, t)
		end)
		task.wait(1)
	end
end)

Lock = function(msg)
	Session.token, Session.key, Session.expiresAt = nil, nil, 0
	StopAll()
	pcall(function()
		Main.Visible = false
		KeyFrame.Visible = true
		StatusKey.TextColor3 = C.bad
		StatusKey.Text = msg or ""
	end)
end

-- Anti-tamper
task.spawn(function()
	while true do
		task.wait(2)
		if not KeyFrame or not KeyFrame.Parent then
			Session.token, Session.key, Session.expiresAt = nil, nil, 0
			StopAll()
			if Main and Main.Parent then Main:Destroy() end
			break
		end
	end
end)

-- Heartbeat
task.spawn(function()
	while true do
		task.wait(HEARTBEAT_INTERVAL)
		if Session.token then
			local data = CallServer({
				action = "heartbeat", key = Session.key, token = Session.token,
				hwid = CurrentHWID, username = LocalPlayer.Name
			})
			if data and data.ok then
				Session.token = data.token or Session.token
				Session.expiresAt = os.time() + (tonumber(data.ttl) or 300) + 60
			elseif data and data.ok == false then
				Lock(data.reason or "Sesi key dicabut oleh server.")
			end
			if Session.token and os.time() >= Session.expiresAt then
				Lock("Sesi kedaluwarsa, verifikasi ulang.")
			end
		end
	end
end)

------------------------------------------------------------------
-- UI LIBRARY
------------------------------------------------------------------
local UI = {}
local Tabs = {}

function UI.Tab(name, icon)
	local btn = New("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.card, BackgroundTransparency = 1,
		AutoButtonColor = false, Text = "", LayoutOrder = #Tabs + 1
	}, Sidebar)
	Round(btn, 10)
	local bar = New("Frame", {Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = C.accent, Visible = false, BorderSizePixel = 0}, btn)
	Round(bar, 2)
	Label(btn, icon, 14, C.text, Enum.Font.Gotham, UDim2.new(0, 12, 0, 0), UDim2.new(0, 24, 1, 0), Enum.TextXAlignment.Center)
	local lbl = Label(btn, name, 12, C.sub, Enum.Font.GothamMedium, UDim2.new(0, 42, 0, 0), UDim2.new(1, -46, 1, 0))

	local page = New("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y
	}, PagesHolder)
	New("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, page)
	New("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8)}, page)

	local tab = {Button = btn, Bar = bar, Label = lbl, Page = page, Name = name}
	table.insert(Tabs, tab)

	btn.MouseButton1Click:Connect(function()
		for _, t in ipairs(Tabs) do
			local on = (t == tab)
			t.Page.Visible = on
			t.Bar.Visible = on
			t.Button.BackgroundTransparency = on and 0 or 1
			t.Label.TextColor3 = on and C.text or C.sub
		end
		PageTitle.Text = name
	end)
	if #Tabs == 1 then
		page.Visible, bar.Visible = true, true
		btn.BackgroundTransparency = 0
		lbl.TextColor3 = C.text
		PageTitle.Text = name
	end
	return page
end

local function Card(page, h)
	local f = New("Frame", {Size = UDim2.new(1, -4, 0, h or 54), BackgroundColor3 = C.card}, page)
	Round(f, 10)
	New("UIStroke", {Color = C.line, Thickness = 1}, f)
	return f
end

local function CardText(card, title, desc, rightPad)
	if desc and desc ~= "" then
		Label(card, title, 13, C.text, Enum.Font.GothamMedium, UDim2.new(0, 12, 0, 8), UDim2.new(1, -rightPad, 0, 18))
		Label(card, desc, 11, C.sub, Enum.Font.Gotham, UDim2.new(0, 12, 0, 27), UDim2.new(1, -rightPad, 0, 18))
	else
		Label(card, title, 13, C.text, Enum.Font.GothamMedium, UDim2.new(0, 12, 0, 0), UDim2.new(1, -rightPad, 1, 0))
	end
end

function UI.Section(page, text, color)
	return Label(page, text, 12, color or C.accent, Enum.Font.GothamBold, nil, UDim2.new(1, -4, 0, 22))
end

function UI.Toggle(page, title, desc, default, cb)
	local card = Card(page)
	CardText(card, title, desc, 90)
	local sw = New("TextButton", {
		Text = "", AutoButtonColor = false, Size = UDim2.new(0, 52, 0, 26),
		Position = UDim2.new(1, -64, 0.5, -13), BackgroundColor3 = C.off
	}, card)
	Round(sw, 13)
	local knob = New("Frame", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 3, 0.5, -10), BackgroundColor3 = C.accent}, sw)
	Round(knob, 10)
	local state = default and true or false
	local function render()
		local ti = TweenInfo.new(0.15)
		TweenService:Create(knob, ti, {
			Position = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or C.accent
		}):Play()
		TweenService:Create(sw, ti, {BackgroundColor3 = state and C.accent or C.off}):Play()
	end
	render()
	sw.MouseButton1Click:Connect(function()
		if not IsVerified() then
			state = false
			render()
			return
		end
		state = not state
		render()
		task.spawn(cb, state)
	end)
	return {Set = function(v) state = v and true or false; render() end}
end

function UI.Button(page, title, desc, btnText, cb, color)
	local card = Card(page)
	CardText(card, title, desc, 130)
	local b = New("TextButton", {
		Size = UDim2.new(0, 104, 0, 34), Position = UDim2.new(1, -116, 0.5, -17),
		BackgroundColor3 = color or C.accent, Text = btnText, TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd
	}, card)
	Round(b, 8)
	b.MouseButton1Click:Connect(function()
		if not IsVerified() then return end
		task.spawn(cb, b)
	end)
	return b, card
end

function UI.Input(page, title, desc, default, placeholder, cb)
	local card = Card(page)
	CardText(card, title, desc, 140)
	local box = New("TextBox", {
		Size = UDim2.new(0, 112, 0, 34), Position = UDim2.new(1, -124, 0.5, -17),
		BackgroundColor3 = C.bg, Text = tostring(default or ""), PlaceholderText = placeholder or "",
		PlaceholderColor3 = C.sub, TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false
	}, card)
	Round(box, 8)
	New("UIStroke", {Color = C.line}, box)
	box.FocusLost:Connect(function() cb(box.Text) end)
	return box
end

local function Flash(btn, text, ok)
	local old = btn.Text
	local oldColor = btn.BackgroundColor3
	btn.Text = text
	btn.BackgroundColor3 = ok and C.good or C.bad
	task.wait(1.8)
	btn.Text = old
	btn.BackgroundColor3 = oldColor
end

------------------------------------------------------------------
-- TABS
------------------------------------------------------------------
local FishingPage = UI.Tab("Fishing", "🎣")
local SellPage = UI.Tab("Sell", "💰")
local DiamondPage = UI.Tab("Diamond", "🔷")
local SummitPage = UI.Tab("Summit", "⛰️")
local PlayerPage = UI.Tab("Player", "⚡")
local PlayerTpPage = UI.Tab("TP Player", "👥")
local PrivacyPage = UI.Tab("Privacy", "🛡️")
local SettingsPage = UI.Tab("Settings", "⚙️")
local CreditsPage = UI.Tab("Credits", "💎")

------------------------------------------------------------------
-- KEY VALIDATION
------------------------------------------------------------------
GetKeyDiscordBtn.MouseButton1Click:Connect(function()
	local ok = pcall(function() setclipboard(DISCORD_LINK) end)
	StatusKey.TextColor3 = ok and C.accent or C.bad
	StatusKey.Text = ok and "Link Discord disalin!" or ("Buka manual: " .. DISCORD_LINK)
end)

local validating = false
local function ValidateKey(enteredKey, isAutoLogin)
	enteredKey = tostring(enteredKey or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if validating then return end
	if enteredKey == "" then
		if not isAutoLogin then
			StatusKey.TextColor3 = C.bad
			StatusKey.Text = "Masukkan Key terlebih dahulu!"
		end
		KeyFrame.Visible = true
		return
	end
	validating = true
	if not isAutoLogin then
		StatusKey.TextColor3 = C.warn
		StatusKey.Text = "Memeriksa validasi akun & key..."
	end

	task.spawn(function()
		local data, err = CallServer({
			action = "verify", key = enteredKey, hwid = CurrentHWID,
			username = LocalPlayer.Name, userId = LocalPlayer.UserId, placeId = game.PlaceId
		})
		validating = false

		if not data then
			if not isAutoLogin then StatusKey.TextColor3 = C.bad; StatusKey.Text = err or "Gagal verifikasi." end
			KeyFrame.Visible = true
			return
		end
		if not data.ok or type(data.token) ~= "string" then
			if not isAutoLogin then StatusKey.TextColor3 = C.bad; StatusKey.Text = tostring(data.reason or "Key tidak valid!") end
			KeyFrame.Visible = true
			return
		end

		Session.token = data.token
		Session.key = enteredKey
		Session.expiresAt = os.time() + (tonumber(data.ttl) or 300) + 60

		pcall(function() if writefile then writefile(KEY_FILE, enteredKey) end end)
		StatusKey.Text = ""
		KeyFrame.Visible = false
		Main.Visible = true
	end)
end

SubmitKeyBtn.MouseButton1Click:Connect(function() ValidateKey(KeyBox.Text, false) end)

task.spawn(function()
	if readfile and isfile and isfile(KEY_FILE) then
		local savedKey = readfile(KEY_FILE)
		if savedKey and savedKey ~= "" then
			KeyBox.Text = savedKey
			ValidateKey(savedKey, true)
			return
		end
	end
	KeyFrame.Visible = true
end)

------------------------------------------------------------------
-- 1. FISHING PAGE
------------------------------------------------------------------
UI.Section(FishingPage, "AUTO FISHING")

TgFish = UI.Toggle(FishingPage, "Auto Fishing", "Rod terdeteksi otomatis.", false, function(v)
	if v and not IsVerified() then return end
	getgenv().AutoFishRunning = v
	if v then
		StartFishingLoop()
	else
		getgenv().FishLoopId = getgenv().FishLoopId + 1
		SetFishStatus("Berhenti.")
	end
end)

do
	local card = Card(FishingPage, 60)
	local lbl = Label(card, "Siap.", 11, C.text, Enum.Font.Gotham, UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 1, -16))
	lbl.TextWrapped = true
	lbl.TextTruncate = Enum.TextTruncate.None
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	SetFishStatus = function(t) lbl.Text = t end
end

------------------------------------------------------------------
-- 2. SELL PAGE
------------------------------------------------------------------
UI.Section(SellPage, "AUTO SELL IKAN")

UI.Toggle(SellPage, "Auto Sell", "Jual semua ikan lewat Sell All berkala.", false, function(v)
	if v and not IsVerified() then return end
	getgenv().AutoSellRunning = v
	getgenv().SellLoopId = getgenv().SellLoopId + 1
	if v then
		local myId = getgenv().SellLoopId
		task.spawn(function()
			local last = tick()
			while getgenv().AutoSellRunning and getgenv().SellLoopId == myId do
				if not IsVerified() then getgenv().AutoSellRunning = false break end
				task.wait(1)
				if (tick() - last) / 60 >= math.max(0.1, Num("AutoSellTimer")) then
					local ok, msg = DoSell()
					SetFishStatus(msg)
					last = tick()
				end
			end
		end)
	end
end)

local SellTimerBox
SellTimerBox = UI.Input(SellPage, "Jeda Jual", "Menit antar penjualan", getgenv().UbeyConfig.AutoSellTimer, "5", function(t)
	local n = math.clamp(tonumber(t) or 5, 0.1, 120)
	getgenv().UbeyConfig.AutoSellTimer = tostring(n)
	SellTimerBox.Text = tostring(n)
	SaveConfig()
end)

UI.Button(SellPage, "Jual Sekarang", "Jual semua ikan satu kali.", "Jual", function(btn)
	local ok, msg = DoSell()
	Flash(btn, msg, ok)
end, C.good)

------------------------------------------------------------------
-- DIAMOND (Workspace.DiamondSpawn -> DiamondPickup)
------------------------------------------------------------------
getgenv().AutoDiamondRunning = false
getgenv().DiamondLoopId = getgenv().DiamondLoopId or 0
local diamondCount = 0
local SetDiamondStatus = function() end

local function PickupPart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function FindPickups()
	local list, seen = {}, {}
	local function consider(v)
		if v.Name == "DiamondPickup" and not seen[v] and PickupPart(v) then
			seen[v] = true
			table.insert(list, v)
		end
	end
	local folder = workspace:FindFirstChild("DiamondSpawn")
	if folder then
		for _, v in ipairs(folder:GetDescendants()) do consider(v) end
	end
	for _, v in ipairs(workspace:GetChildren()) do consider(v) end
	return list
end

-- true kalau diamond hilang (berhasil diambil)
local function CollectOne(p)
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local part = PickupPart(p)
	if not (hrp and part and p.Parent) then return false end

	-- 1) sentuh dari jauh, tanpa pindah posisi
	pcall(function()
		if firetouchinterest then
			firetouchinterest(hrp, part, 0)
			task.wait()
			firetouchinterest(hrp, part, 1)
		end
	end)
	pcall(function()
		local pp = p:FindFirstChildWhichIsA("ProximityPrompt", true)
		if pp and fireproximityprompt then fireproximityprompt(pp) end
	end)
	task.wait(0.4)
	if not p.Parent then return true end

	-- 2) cadangan: pindah ke diamond, lalu kembali ke posisi semula
	local back = hrp.CFrame
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = part.CFrame
	task.wait(0.5)
	hrp.CFrame = back
	task.wait(0.2)
	return not p.Parent
end

local function StartDiamondLoop()
	getgenv().DiamondLoopId = getgenv().DiamondLoopId + 1
	local myId = getgenv().DiamondLoopId
	task.spawn(function()
		local fails = setmetatable({}, {__mode = "k"})
		while getgenv().AutoDiamondRunning and getgenv().DiamondLoopId == myId do
			if not IsVerified() then getgenv().AutoDiamondRunning = false break end

			local todo = {}
			for _, p in ipairs(FindPickups()) do
				if (fails[p] or 0) < 3 then table.insert(todo, p) end
			end

			if #todo > 0 then
				CollectBusy = true -- jeda mancing
				local w = 0
				while CycleBusy and w < 20 do task.wait(0.1) w = w + 0.1 end
				for _, p in ipairs(todo) do
					if not getgenv().AutoDiamondRunning or getgenv().DiamondLoopId ~= myId then break end
					local ok, got = pcall(CollectOne, p)
					if ok and got then
						diamondCount = diamondCount + 1
					else
						fails[p] = (fails[p] or 0) + 1
					end
					SetDiamondStatus("Mengambil diamond... Terkumpul: " .. diamondCount)
				end
				CollectBusy = false
			else
				SetDiamondStatus("Menunggu diamond muncul...\nTerkumpul: " .. diamondCount)
			end
			task.wait(1.5)
		end
		CollectBusy = false
	end)
end

UI.Section(DiamondPage, "AUTO DIAMOND")

UI.Toggle(DiamondPage, "Auto Collect Diamond", "Ambil diamond yang muncul di checkpoint.", false, function(v)
	if v and not IsVerified() then return end
	getgenv().AutoDiamondRunning = v
	if v then
		StartDiamondLoop()
	else
		getgenv().DiamondLoopId = getgenv().DiamondLoopId + 1
		CollectBusy = false
		SetDiamondStatus("Berhenti. Terkumpul: " .. diamondCount)
	end
end)

do
	local card = Card(DiamondPage, 60)
	local lbl = Label(card, "Siap.", 11, C.text, Enum.Font.Gotham, UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 1, -16))
	lbl.TextWrapped = true
	lbl.TextTruncate = Enum.TextTruncate.None
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	SetDiamondStatus = function(t) lbl.Text = t end
end

------------------------------------------------------------------
-- SUMMIT (Workspace.Checkpoints -> CP0, CP1, CP2, ...)
-- CP muncul berurutan saat karakter dekat (StreamingEnabled):
-- teleport ke CP sekarang, tunggu CP berikutnya muncul, ulangi.
------------------------------------------------------------------
getgenv().AutoSummitRunning = false
getgenv().SummitLoopId = getgenv().SummitLoopId or 0
local SetSummitStatus = function() end
local lastCp = -1

local function CpIndex(name)
	local n = string.match(name, "^[Cc][Pp](%d+)$")
	return n and tonumber(n)
end

local function InstPos(inst)
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, cf = pcall(function() return inst:GetPivot() end)
		if ok and cf then return cf.Position end
	end
	local p = inst:FindFirstChildWhichIsA("BasePart", true)
	return p and p.Position
end

-- peta index -> instance untuk semua CP yang sedang termuat
local function ScanCheckpoints()
	local map = {}
	local function add(inst)
		local i = CpIndex(inst.Name)
		if i and not map[i] and InstPos(inst) then map[i] = inst end
	end
	local folder = workspace:FindFirstChild("Checkpoints")
	if folder then
		for _, v in ipairs(folder:GetChildren()) do add(v) end
	end
	for _, v in ipairs(workspace:GetChildren()) do
		if v ~= folder then add(v) end
	end
	return map
end

local function GetCurrentIndex(map, hrp)
	local best, bd
	for i, inst in pairs(map) do
		local pos = InstPos(inst)
		if pos then
			local d = (pos - hrp.Position).Magnitude
			if not bd or d < bd then best, bd = i, d end
		end
	end
	if best and bd <= 80 then return best end
	if lastCp >= 0 then return lastCp end
	return best
end

local function TeleportToCp(inst)
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local pos = InstPos(inst)
	if not (hrp and pos) then return false end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) * (hrp.CFrame - hrp.CFrame.Position)
	return true
end

local function SummitStepOnce()
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "Karakter tidak ada" end
	local map = ScanCheckpoints()
	local cur = GetCurrentIndex(map, hrp)
	if not cur then return false, "Tidak ada CP terdeteksi di sekitar" end
	local nxt = map[cur + 1]
	if not nxt then return false, "Di CP" .. cur .. ". CP" .. (cur + 1) .. " belum muncul" end
	TeleportToCp(nxt)
	lastCp = cur + 1
	return true, "Teleport ke CP" .. (cur + 1)
end

local function StartSummitLoop()
	getgenv().SummitLoopId = getgenv().SummitLoopId + 1
	local myId = getgenv().SummitLoopId
	task.spawn(function()
		local waited = 0
		while getgenv().AutoSummitRunning and getgenv().SummitLoopId == myId do
			if not IsVerified() then getgenv().AutoSummitRunning = false break end
			local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				SetSummitStatus("Karakter tidak ada...")
				task.wait(1)
				continue
			end

			local map = ScanCheckpoints()
			local cur = GetCurrentIndex(map, hrp)
			if not cur then
				SetSummitStatus("Tidak ada CP terdeteksi.\nDekati salah satu CP dulu.")
				task.wait(1)
				continue
			end

			local tIdx = cur + 1
			local target = map[tIdx]
			-- kalau CP berikutnya tak kunjung muncul, boleh lompat sedikit
			if not target and waited >= 10 then
				for i = cur + 2, cur + 3 do
					if map[i] then target, tIdx = map[i], i break end
				end
			end

			if target then
				SetSummitStatus("Di CP" .. cur .. " → pindah ke CP" .. tIdx)
				TeleportToCp(target)
				lastCp = tIdx
				waited = 0
				task.wait(math.max(0.5, Num("SummitDelay")))
			else
				waited = waited + 0.5
				SetSummitStatus(string.format("Di CP%d. Menunggu CP%d muncul... (%.0fs)\nKalau macet lama, mungkin sudah puncak.", cur, cur + 1, waited))
				task.wait(0.5)
			end
		end
	end)
end

UI.Section(SummitPage, "AUTO SUMMIT")

UI.Toggle(SummitPage, "Auto Summit", "Teleport ke CP berikutnya yang muncul.", false, function(v)
	if v and not IsVerified() then return end
	getgenv().AutoSummitRunning = v
	if v then
		StartSummitLoop()
	else
		getgenv().SummitLoopId = getgenv().SummitLoopId + 1
		SetSummitStatus("Berhenti.")
	end
end)

local SummitDelayBox
SummitDelayBox = UI.Input(SummitPage, "Jeda Antar CP", "Detik setelah teleport ke satu CP", getgenv().UbeyConfig.SummitDelay, "2", function(t)
	local n = math.clamp(tonumber(t) or 2, 0.5, 30)
	getgenv().UbeyConfig.SummitDelay = tostring(n)
	SummitDelayBox.Text = tostring(n)
	SaveConfig()
end)

UI.Button(SummitPage, "CP Berikutnya", "Teleport satu kali ke CP berikutnya.", "Teleport", function(btn)
	local ok, msg = SummitStepOnce()
	SetSummitStatus(msg)
	Flash(btn, ok and "Berhasil ✓" or "Belum ada", ok)
end, C.good)

UI.Button(SummitPage, "Scan CP", "Tampilkan CP yang sedang termuat.", "Scan", function(btn)
	local map = ScanCheckpoints()
	local list = {}
	for i in pairs(map) do table.insert(list, i) end
	table.sort(list)
	local names = {}
	for _, i in ipairs(list) do table.insert(names, "CP" .. i) end
	SetSummitStatus(#names > 0 and ("Termuat: " .. table.concat(names, ", ")) or "Tidak ada CP termuat.")
	Flash(btn, #names .. " CP", #names > 0)
end)

do
	local card = Card(SummitPage, 60)
	local lbl = Label(card, "Siap.", 11, C.text, Enum.Font.Gotham, UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 1, -16))
	lbl.TextWrapped = true
	lbl.TextTruncate = Enum.TextTruncate.None
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	SetSummitStatus = function(t) lbl.Text = t end
end

------------------------------------------------------------------
-- 3. PLAYER PAGE
------------------------------------------------------------------
UI.Section(PlayerPage, "PLAYER SETTINGS")
UI.Input(PlayerPage, "WalkSpeed", "Kecepatan jalan karakter", "", "50", function(t)
	local num = tonumber(t)
	if num and IsVerified() then
		pcall(function()
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = num end
		end)
	end
end)

UI.Toggle(PlayerPage, "Anti-AFK", "Cegah kick karena idle.", false, function(v) getgenv().AntiAFKRunning = v end)
LocalPlayer.Idled:Connect(function()
	if getgenv().AntiAFKRunning then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new(0, 0))
	end
end)

------------------------------------------------------------------
-- 4. TP PLAYER PAGE
------------------------------------------------------------------
local RefreshPlayerBtn = New("TextButton", {
	Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(0, 100, 180),
	Text = "🔄 Refresh / Scan Pemain", TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold, TextSize = 12
}, PlayerTpPage)
Round(RefreshPlayerBtn, 8)

local PlayerListContainer = New("ScrollingFrame", {
	Size = UDim2.new(1, 0, 0, 210), BackgroundTransparency = 1,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3
}, PlayerTpPage)
New("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, PlayerListContainer)

local function ScanAndDisplayPlayers()
	for _, child in ipairs(PlayerListContainer:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local pBtn = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(35, 35, 45),
				Text = "👤 " .. plr.Name .. " (" .. plr.DisplayName .. ")",
				TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, TextSize = 11
			}, PlayerListContainer)
			Round(pBtn, 8)
			pBtn.MouseButton1Click:Connect(function()
				if not IsVerified() then return end
				pcall(function()
					local hrpTarget = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
					if hrpTarget and myHrp then myHrp.CFrame = hrpTarget.CFrame + Vector3.new(0, 5, 0) end
				end)
			end)
		end
	end
end

RefreshPlayerBtn.MouseButton1Click:Connect(function()
	if not IsVerified() then return end
	ScanAndDisplayPlayers()
end)
task.spawn(function() task.wait(2); ScanAndDisplayPlayers() end)

------------------------------------------------------------------
-- 5. PRIVACY & ANTI-ADMIN
------------------------------------------------------------------
local function EscPat(s) return (tostring(s):gsub("%p", "%%%0")) end
local function EscRep(s) return (tostring(s):gsub("%%", "%%%%")) end

local extraBillboards = {}
local function ScanBillboards()
	extraBillboards = {}
	local char = LocalPlayer.Character
	if not char then return end
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("BillboardGui") then
			local ad = v.Adornee
			if ad and ad:IsDescendantOf(char) then table.insert(extraBillboards, v) end
		end
	end
end

local function HideNameStep()
	local fake = tostring(getgenv().FakeNameInput or "UBEY HUB")
	local names = {LocalPlayer.DisplayName, LocalPlayer.Name}

	local function fix(lbl)
		local txt = lbl.Text
		if txt == "" or string.find(txt, fake, 1, true) then return end
		local new = txt
		for _, n in ipairs(names) do
			if n ~= "" and string.find(new, n, 1, true) then
				new = string.gsub(new, EscPat(n), EscRep(fake))
			end
		end
		if new ~= txt then lbl.Text = new end
	end

	local function scan(root)
		for _, o in ipairs(root:GetDescendants()) do
			if o:IsA("TextLabel") or o:IsA("TextButton") then fix(o) end
		end
	end

	local char = LocalPlayer.Character
	if char then
		scan(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	end
	for _, bb in ipairs(extraBillboards) do
		if bb.Parent then scan(bb) end
	end
	for _, o in ipairs(PlayerGui:GetDescendants()) do
		if (o:IsA("TextLabel") or o:IsA("TextButton")) and not o:IsDescendantOf(Gui) then fix(o) end
	end
end

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(2)
	if getgenv().HideNameRunning then pcall(ScanBillboards) end
end)

UI.Section(PrivacyPage, "PRIVACY & ANTI-ADMIN")
UI.Input(PrivacyPage, "Nama Samaran", "Dipakai saat Privacy Mode aktif", "UBEY HUB", "UBEY HUB", function(t)
	getgenv().FakeNameInput = t
end)

UI.Toggle(PrivacyPage, "Privacy Mode (Hide Name)", "Samarkan nama di atas kepala, HUD, dan karakter.", false, function(v)
	if v and not IsVerified() then return end
	getgenv().HideNameRunning = v
	if v then
		task.spawn(function()
			pcall(ScanBillboards)
			while getgenv().HideNameRunning do
				if not IsVerified() then getgenv().HideNameRunning = false break end
				pcall(HideNameStep)
				task.wait(0.7)
			end
		end)
	end
end)

local GroupBox
GroupBox = UI.Input(PrivacyPage, "Group ID Admin", "ID grup game ini (0 = nonaktif)", getgenv().UbeyConfig.TargetGroupId, "0", function(t)
	local n = math.max(0, math.floor(tonumber(t) or 0))
	getgenv().UbeyConfig.TargetGroupId = tostring(n)
	GroupBox.Text = tostring(n)
	SaveConfig()
end)

UI.Toggle(PrivacyPage, "Anti-Admin Protect", "Pindah server otomatis jika admin grup masuk.", getgenv().UbeyConfig.AntiAdminEnabled, function(v)
	getgenv().UbeyConfig.AntiAdminEnabled = v
	SaveConfig()
end)

local function CheckPlayerIsAdmin(player)
	local gid = tonumber(getgenv().UbeyConfig.TargetGroupId) or 0
	if gid <= 0 then return false end
	local ok, rank = pcall(function() return player:GetRankInGroup(gid) end)
	return ok and rank and rank > 1
end

Players.PlayerAdded:Connect(function(player)
	if player ~= LocalPlayer then
		task.spawn(function()
			task.wait(1.5)
			if IsVerified() and getgenv().UbeyConfig.AntiAdminEnabled and CheckPlayerIsAdmin(player) then
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end
		end)
	end
end)

------------------------------------------------------------------
-- 6. SETTINGS
------------------------------------------------------------------
UI.Section(SettingsPage, "SETTINGS & PERFORMANCE")

UI.Button(SettingsPage, "Anti-Lag", "Matikan bayangan & partikel untuk naikkan FPS.", "Aktifkan", function(btn)
	pcall(function()
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 999999
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled = false end
		end
		btn.Text = "Aktif ✓"
	end)
end)

local BlackScreenGui = nil
local bsToggle
bsToggle = UI.Toggle(SettingsPage, "Black Screen (Battery Saver)", "Layar hitam hemat baterai. Sentuh layar untuk kembali.", false, function(v)
	if v then
		if not BlackScreenGui then
			BlackScreenGui = New("ScreenGui", {Name = "UbeyBlackScreen", DisplayOrder = 999999, IgnoreGuiInset = true, ResetOnSpawn = false}, GuiParent)
			local frame = New("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(2, 2, 5)}, BlackScreenGui)
			Label(frame, "🌙 " .. HUB_TITLE .. " - BATTERY SAVER AKTIF\n(Sentuh layar untuk kembali)", 13, C.accent, Enum.Font.GothamBold,
				UDim2.new(0, 0, 0.45, 0), UDim2.new(1, 0, 0, 60), Enum.TextXAlignment.Center).TextWrapped = true
			frame.InputBegan:Connect(function()
				BlackScreenGui.Enabled = false
				bsToggle.Set(false)
			end)
		else
			BlackScreenGui.Enabled = true
		end
	elseif BlackScreenGui then
		BlackScreenGui.Enabled = false
	end
end)

UI.Section(SettingsPage, "KONFIGURASI", C.warn)
UI.Button(SettingsPage, "Simpan Konfigurasi", "Simpan semua pengaturan ke file.", "Simpan", function(btn)
	SaveConfig()
	Flash(btn, "Tersimpan ✓", true)
end, C.good)

UI.Button(SettingsPage, "Reset Konfigurasi & Clear Key", "Hapus config dan key tersimpan.", "Reset", function(btn)
	ResetConfig()
	KeyBox.Text = ""
	Flash(btn, "Direset ✓", true)
	task.wait(0.5)
	Lock("Key dihapus. Masukkan key lagi.")
end, Color3.fromRGB(180, 50, 50))

------------------------------------------------------------------
-- 7. CREDITS
------------------------------------------------------------------
UI.Section(CreditsPage, "CREDITS")
UI.Button(CreditsPage, "Created By UBEY", "Terima kasih sudah memakai " .. HUB_TITLE .. ".", "Discord", function(btn)
	pcall(function() if setclipboard then setclipboard(DISCORD_LINK) end end)
	Flash(btn, "Link disalin ✓", true)
end, Color3.fromRGB(88, 101, 242))

------------------------------------------------------------------
-- FLOATING LOGO
------------------------------------------------------------------
local Float = New("ImageButton", {
	Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 20, 0, 120),
	Image = LOGO_ASSET, BackgroundColor3 = C.bg, AutoButtonColor = false, ZIndex = 50
}, Gui)
Round(Float, 30)
New("UIStroke", {Color = C.accent, Thickness = 2}, Float)
local floatMoved = MakeDraggable(Float)

Float.MouseButton1Click:Connect(function()
	if floatMoved() then return end
	if not IsVerified() then
		KeyFrame.Visible = not KeyFrame.Visible
		Main.Visible = false
	else
		Main.Visible = not Main.Visible
		KeyFrame.Visible = false
	end
end)
