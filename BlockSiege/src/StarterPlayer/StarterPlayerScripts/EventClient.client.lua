-- BLOCKSIEGE // LIVE-OPS HUD, RICH-TEXT ANNOUNCEMENTS + ADMIN PANEL
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local EventCatalog = require(Shared:WaitForChild("EventCatalog"))
local SeasonCatalog = require(Shared:WaitForChild("SeasonCatalog"))
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = {
	Background = Color3.fromRGB(10, 14, 29),
	Panel = Color3.fromRGB(29, 38, 65),
	Text = Color3.fromRGB(246, 249, 255),
	Muted = Color3.fromRGB(161, 179, 214),
	Gold = Color3.fromRGB(255, 205, 87),
	Pink = Color3.fromRGB(255, 100, 190),
	Cyan = Color3.fromRGB(76, 216, 255),
	Purple = Color3.fromRGB(168, 108, 255),
}

local function new(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(object, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
end

local function gradient(object, first, second, rotation)
	return new("UIGradient", { Color = ColorSequence.new(first, second), Rotation = rotation or 100 }, object)
end

local function label(parent, value, size, position, textSize, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.Gotham,
		RichText = true,
		Text = value,
		TextColor3 = color or C.Text,
		TextSize = textSize or 15,
		TextWrapped = true,
	}, parent)
end

local function button(parent, value, size, position, color)
	local object = new("TextButton", {
		BackgroundColor3 = color or C.Panel,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.GothamBold,
		RichText = true,
		Text = value,
		TextColor3 = C.Text,
		TextSize = 14,
		AutoButtonColor = true,
	}, parent)
	corner(object, 7)
	new("UIStroke", { Color = C.Cyan, Thickness = 1, Transparency = 0.35 }, object)
	return object
end

local function escape(value)
	local escaped = tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
	return escaped
end

local function hex(color)
	color = color or C.Gold
	return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function colored(value, color)
	return string.format('<font color="#%s"><b>%s</b></font>', hex(color), escape(value))
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local gui = new("ScreenGui", {
	Name = "BlockSiegeLiveOps",
	ResetOnSpawn = false,
	DisplayOrder = 8,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local eventBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 186),
		Size = UDim2.new(0.9, 0, 0, 72),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.04,
}, gui)
corner(eventBar, 10)
gradient(eventBar, Color3.fromRGB(48, 33, 75), Color3.fromRGB(10, 23, 42), 105)
local eventStroke = new("UIStroke", { Color = C.Purple, Thickness = 1.4, Transparency = 0.08 }, eventBar)
local eventAccent = new("Frame", { Size = UDim2.new(0, 5, 1, -12), Position = UDim2.new(0, 5, 0, 6), BackgroundColor3 = C.Purple, BorderSizePixel = 0 }, eventBar)
corner(eventAccent, 3)
local eventKicker = label(eventBar, "LIVE EVENT", UDim2.new(1, -122, 0, 14), UDim2.new(0, 17, 0, 4), 10, C.Muted)
eventKicker.Font = Enum.Font.GothamBold
local eventTitle = label(eventBar, "", UDim2.new(1, -122, 0, 26), UDim2.new(0, 17, 0, 18), 19, C.Text)
eventTitle.Font = Enum.Font.GothamBold
local eventDescription = label(eventBar, "", UDim2.new(1, -32, 0, 23), UDim2.new(0, 17, 0, 45), 11, C.Muted)
local eventTime = label(eventBar, "00:00", UDim2.new(0, 92, 0, 34), UDim2.new(1, -103, 0, 8), 23, C.Gold)
eventTime.Font = Enum.Font.GothamBlack
eventTime.TextXAlignment = Enum.TextXAlignment.Right

local eventButton = button(gui, "V · ИВЕНТЫ И РАСПИСАНИЕ", UDim2.new(0, 330, 0, 34), UDim2.new(0, 16, 0, 426), Color3.fromRGB(67, 44, 105))
eventButton.Name = "LiveEventsButton"
gradient(eventButton, Color3.fromRGB(151, 69, 190), Color3.fromRGB(41, 105, 150), 0)

local eventPanel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.new(0.92, 0, 0.8, 0),
	BackgroundColor3 = C.Background,
	Visible = false,
}, gui)
new("UISizeConstraint", { MinSize = Vector2.new(320, 400), MaxSize = Vector2.new(590, 590) }, eventPanel)
corner(eventPanel, 12)
gradient(eventPanel, Color3.fromRGB(39, 30, 67), Color3.fromRGB(9, 19, 35), 110)
new("UIStroke", { Color = C.Pink, Thickness = 1.6, Transparency = 0.12 }, eventPanel)
local panelTitle = label(eventPanel, '<font color="#FF66BE"><b>LIVEOPS</b></font> <font color="#66DFFF"><b>· ИВЕНТЫ</b></font>', UDim2.new(1, -72, 0, 36), UDim2.new(0, 16, 0, 9), 23, C.Text)
local panelSubtitle = label(eventPanel, "45 секунд события · новое UTC-окно каждые 4 минуты", UDim2.new(1, -210, 0, 24), UDim2.new(0, 16, 0, 45), 12, C.Muted)
local seasonTab = button(eventPanel, "ПРАЗДНИКИ", UDim2.new(0, 124, 0, 28), UDim2.new(1, -184, 0, 43), C.Purple)
local closeButton = button(eventPanel, "×", UDim2.new(0, 42, 0, 36), UDim2.new(1, -54, 0, 10), C.Panel)
local eventList = new("ScrollingFrame", {
	Position = UDim2.new(0, 16, 0, 73), Size = UDim2.new(1, -32, 1, -137),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, #EventCatalog.Order * 91), ScrollBarImageColor3 = C.Pink,
}, eventPanel)
local seasonList = new("ScrollingFrame", {
	Position = UDim2.new(0, 16, 0, 73), Size = UDim2.new(1, -32, 1, -137),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, #SeasonCatalog.Order * 77), ScrollBarImageColor3 = C.Purple, Visible = false,
}, eventPanel)
local seasonButtons = {}
for index, id in ipairs(SeasonCatalog.Order) do
	local definition = SeasonCatalog.Get(id)
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 70), Position = UDim2.new(0, 0, 0, (index - 1) * 77), BackgroundColor3 = C.Panel }, seasonList)
	corner(row, 8)
	local name = label(row, colored(definition.Name, definition.Color), UDim2.new(0.58, 0, 0, 23), UDim2.new(0, 12, 0, 5), 16, C.Text)
	name.Font = Enum.Font.GothamBold
	local description = label(row, escape(definition.Subtitle), UDim2.new(0.58, 0, 0, 35), UDim2.new(0, 12, 0, 30), 11, C.Muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local apply = button(row, "ПРИМЕНИТЬ", UDim2.new(0.34, 0, 0, 36), UDim2.new(0.63, 0, 0, 17), definition.Color)
	apply.Activated:Connect(function()
		remotes.AdminSeasonRequest:FireServer(id)
	end)
	seasonButtons[id] = apply
end
local adminRows = {}
for index, id in ipairs(EventCatalog.Order) do
	local definition = EventCatalog.Get(id)
	local row = new("Frame", {
		Position = UDim2.new(0, 0, 0, (index - 1) * 91),
		Size = UDim2.new(1, -8, 0, 84),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, eventList)
	corner(row, 9)
	local accent = new("Frame", { Size = UDim2.new(0, 4, 1, -12), Position = UDim2.new(0, 5, 0, 6), BackgroundColor3 = definition.Color, BorderSizePixel = 0 }, row)
	corner(accent, 2)
	local title = label(row, colored(definition.Name, definition.Color), UDim2.new(1, -26, 0, 23), UDim2.new(0, 15, 0, 5), 16, C.Text)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local description = label(row, escape(definition.Description), UDim2.new(1, -150, 0, 47), UDim2.new(0, 15, 0, 30), 12, C.Muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	local start = button(row, "ЗАПУСТИТЬ", UDim2.new(0, 116, 0, 34), UDim2.new(1, -128, 0, 39), definition.Color)
	start.TextColor3 = Color3.fromRGB(20, 24, 35)
	start.Visible = false
	start.Activated:Connect(function()
		remotes.AdminEventRequest:FireServer("Start", id)
		eventPanel.Visible = false
	end)
	adminRows[id] = start
end
local stopButton = button(eventPanel, "ОСТАНОВИТЬ ИВЕНТ", UDim2.new(0, 190, 0, 36), UDim2.new(0, 16, 1, -49), Color3.fromRGB(150, 54, 85))
stopButton.Visible = false
stopButton.Activated:Connect(function()
	remotes.AdminEventRequest:FireServer("Stop")
end)
local panelStatus = label(eventPanel, "", UDim2.new(1, -230, 0, 39), UDim2.new(0, 218, 1, -51), 11, C.Muted)
panelStatus.TextXAlignment = Enum.TextXAlignment.Right

local announcement = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.37, 0),
	Size = UDim2.new(0.92, 0, 0, 116),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.12,
	GroupTransparency = 1,
	Visible = false,
	ZIndex = 30,
}, gui)
corner(announcement, 13)
local announcementStroke = new("UIStroke", { Color = C.Pink, Thickness = 2.2, Transparency = 0.05 }, announcement)
local announcementTitle = label(announcement, "", UDim2.new(1, -24, 0, 35), UDim2.new(0, 12, 0, 8), 27, C.Gold)
announcementTitle.Font = Enum.Font.GothamBlack
announcementTitle.ZIndex = 31
local announcementText = label(announcement, "", UDim2.new(1, -28, 0, 63), UDim2.new(0, 14, 0, 45), 18, C.Text)
announcementText.Font = Enum.Font.GothamBold
announcementText.ZIndex = 31
local announcementVersion = 0

local function showAnnouncement(payload)
	announcementVersion = announcementVersion + 1
	local version = announcementVersion
	local color = payload.Color or C.Pink
	announcementStroke.Color = color
	announcementTitle.Text = colored(payload.Title or "LIVE EVENT", color)
	local subtitle = tostring(payload.Subtitle or "")
	local first, rest = subtitle:match("^([^\n]+)\n?(.*)$")
	announcementText.Text = colored(first or subtitle, color) .. (rest and rest ~= "" and ("\n<font color=\"#F4F7FF\">" .. escape(rest) .. "</font>") or "")
	if state:GetAttribute("Phase") == "Results" then
		return
	end
	announcement.Visible = true
	eventButton.Visible = false
	announcement.GroupTransparency = 0.15
	announcement.Position = UDim2.new(0.5, 0, 0, 233 + announcement.Size.Y.Offset / 2)
	TweenService:Create(announcement, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
	task.delay(tonumber(payload.Duration) or 3.5, function()
		if version ~= announcementVersion then
			return
		end
		local tween = TweenService:Create(announcement, TweenInfo.new(0.35), { GroupTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if version == announcementVersion then
			announcement.Visible = false
		end
	end)
end

local function effect(position, color, size, duration)
	if typeof(position) ~= typeof(Vector3.new()) then
		return
	end
	local part = new("Part", {
		Position = position + Vector3.new(0, 2, 0), Size = Vector3.one * size, Shape = Enum.PartType.Ball,
		Color = color, Material = Enum.Material.Neon, Anchored = true, CanCollide = false,
		CanTouch = false, CanQuery = false, CastShadow = false, Transparency = 0.15,
	}, Workspace)
	TweenService:Create(part, TweenInfo.new(duration), { Size = Vector3.one * size * 1.8, Transparency = 1 }):Play()
	Debris:AddItem(part, duration + 0.05)
end

local function burst(position, color, count)
	if typeof(position) ~= typeof(Vector3.new()) then
		return
	end
	for _ = 1, count do
		local lifetime = 0.4 + math.random() * 0.35
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.25, math.random() - 0.5).Unit
		local part = new("Part", {
			Position = position + Vector3.new(0, 2, 0), Size = Vector3.one * (0.35 + math.random() * 0.55),
			Color = color, Material = Enum.Material.Neon, Anchored = true, CanCollide = false,
			CanTouch = false, CanQuery = false, CastShadow = false,
		}, Workspace)
		TweenService:Create(part, TweenInfo.new(lifetime), { Position = part.Position + direction * 15, Transparency = 1, Size = Vector3.one * 0.05 }):Play()
		Debris:AddItem(part, lifetime + 0.05)
	end
end

remotes.EventFX.OnClientEvent:Connect(function(payload)
	if payload.Kind == "Announcement" then
		showAnnouncement(payload)
	elseif payload.Kind == "MeteorImpact" then
		effect(payload.Position, payload.Color or C.Purple, 11, 0.55)
		burst(payload.Position, payload.Color or C.Purple, 20)
	elseif payload.Kind == "RepairPulse" then
		effect(payload.Position, payload.Color or Color3.fromRGB(78, 239, 190), 8, 0.5)
		burst(payload.Position, payload.Color or Color3.fromRGB(78, 239, 190), 10)
	end
end)

local seasonMode = false
remotes.SeasonFX.OnClientEvent:Connect(function(payload)
	if seasonMode then
		panelSubtitle.Text = "Тема: " .. tostring(payload.Name or "СЕЗОН")
	end
	showAnnouncement({ Title = "СЕЗОН · " .. tostring(payload.Name or "ОБНОВЛЕНИЕ"), Subtitle = payload.Subtitle or "", Color = payload.Color or C.Cyan, Duration = 3.2 })
end)

local function setPanelMode(showSeasons)
	local isAdmin = player:GetAttribute("EventAdmin") == true
	seasonMode = showSeasons
	eventList.Visible = not showSeasons
	seasonList.Visible = showSeasons
	seasonTab.Text = showSeasons and "ИВЕНТЫ" or "ПРАЗДНИКИ"
	if showSeasons then
		stopButton.Visible = false
		panelSubtitle.Text = isAdmin and "Visual theme · admin" or ("Тема: " .. tostring(state:GetAttribute("SeasonName") or "НОВЫЙ ГОД"))
	else
		panelSubtitle.Text = isAdmin and "45 сек · server admin" or "45 сек · окно 4 мин"
	end
end
seasonTab.Activated:Connect(function()
	setPanelMode(not seasonMode)
end)

local function togglePanel()
	eventPanel.Visible = not eventPanel.Visible
	if eventPanel.Visible then
		announcement.Visible = false
	end
end
eventButton.Activated:Connect(togglePanel)
closeButton.Activated:Connect(function()
	eventPanel.Visible = false
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.V then
		togglePanel()
	end
end)

local function layoutEvents(phase)
	local camera = Workspace.CurrentCamera
	local screenWidth = camera and camera.ViewportSize.X or 1280
	local screenHeight = camera and camera.ViewportSize.Y or 720
	local sideWidth = math.clamp((screenWidth - 200) / 2, 100, 340)
	local centralGap = math.max(40, screenWidth - 32 - sideWidth * 2)
	local narrow = screenWidth < 700 or screenHeight < 680
	eventBar.Size = UDim2.new(0, sideWidth, 0, 72)
	if phase == "Lobby" then
		-- The lobby dock occupies the upper-right; its lower-right bay is free.
		eventBar.AnchorPoint = Vector2.new(1, 0)
		eventBar.Position = UDim2.new(1, -16, 0, 374)
	else
		-- Below the 190..326 coach, never through the 67 capture banner.
		eventBar.AnchorPoint = Vector2.new(0, 0)
		eventBar.Position = UDim2.new(0, 16, 0, 340)
	end
	if narrow and phase == "Lobby" then
		eventButton.AnchorPoint = Vector2.new(0.5, 0)
		eventButton.Position = UDim2.new(0.5, 0, 0, 426)
		eventButton.Size = UDim2.new(0, math.clamp(centralGap - 24, 40, 330), 0, 34)
	elseif narrow and (phase == "Build" or phase == "Battle") then
		eventButton.AnchorPoint = Vector2.new(0.5, 0)
		eventButton.Position = UDim2.new(0.5, 0, 0, phase == "Battle" and 240 or 268)
		eventButton.Size = UDim2.new(0, math.clamp(centralGap - 24, 40, 330), 0, 34)
	else
		eventButton.AnchorPoint = Vector2.new(0, 0)
		eventButton.Position = UDim2.new(0, 16, 0, 426)
		eventButton.Size = UDim2.new(0, math.min(330, sideWidth), 0, 34)
	end
	eventButton.TextSize = sideWidth < 240 and 11 or 14
	local compact = sideWidth < 240
	local timerWidth = compact and 58 or 92
	eventKicker.Size = UDim2.new(1, -(timerWidth + 30), 0, 14)
	eventTitle.Size = UDim2.new(1, -(timerWidth + 30), 0, 26)
	eventDescription.Size = UDim2.new(1, -32, 0, 23)
	eventTime.Size = UDim2.new(0, timerWidth, 0, 34)
	eventTime.Position = UDim2.new(1, -(timerWidth + 11), 0, 8)
	eventKicker.TextSize = compact and 8 or 10
	eventTitle.TextSize = compact and 14 or 19
	eventDescription.TextSize = compact and 9 or 11
	eventTime.TextSize = compact and 18 or 23
	local announcementWidth = math.clamp(centralGap - 24, 40, 650)
	local announcementHeight = narrow and 58 or 90
	announcement.Size = UDim2.new(0, announcementWidth, 0, announcementHeight)
	announcement.Position = UDim2.new(0.5, 0, 0, 233 + announcementHeight / 2)
	announcementTitle.Size = UDim2.new(1, -24, 0, narrow and 20 or 30)
	announcementTitle.Position = UDim2.new(0, 12, 0, narrow and 3 or 4)
	announcementText.Size = UDim2.new(1, -28, 0, narrow and 28 or 48)
	announcementText.Position = UDim2.new(0, 14, 0, narrow and 25 or 36)
	announcementTitle.TextSize = narrow and 14 or (announcementWidth < 240 and 18 or 27)
	announcementText.TextSize = narrow and 10 or (announcementWidth < 240 and 12 or 18)
	return centralGap
end

local function refresh()
	local phase = state:GetAttribute("Phase") or "Lobby"
	local centralGap = layoutEvents(phase)
	local isAdmin = player:GetAttribute("EventAdmin") == true
	local active = state:GetAttribute("EventActive") == true
	local id = active and (state:GetAttribute("EventId") or "") or (state:GetAttribute("EventNextId") or "")
	local definition = EventCatalog.Get(id) or EventCatalog.GetForSlot(0)
	eventBar.Visible = phase ~= "Results"
	eventButton.Visible = phase ~= "Results" and not announcement.Visible
	if phase == "Results" then
		eventPanel.Visible = false
		announcement.Visible = false
	end
	local color = active and (state:GetAttribute("EventColor") or definition.Color) or definition.Color
	eventAccent.BackgroundColor3 = color
	eventStroke.Color = color
	eventTime.TextColor3 = color
	if active then
		eventKicker.Text = state:GetAttribute("EventManual") == true and '<font color="#FF72C3"><b>⚡ ADMIN ABUSE · LIVE</b></font>' or '<font color="#77E4FF"><b>LIVE · СЕРВЕРНЫЙ ИВЕНТ</b></font>'
		eventTitle.Text = colored(state:GetAttribute("EventName") or definition.Name, color)
		eventDescription.Text = escape(state:GetAttribute("EventDescription") or definition.Description)
		eventTime.Text = tostring(state:GetAttribute("EventTime") or 0) .. "с"
	else
		eventKicker.Text = '<font color="#B7A4FF"><b>СЛЕДУЮЩИЙ ИВЕНТ · UTC РАСПИСАНИЕ</b></font>'
		eventTitle.Text = colored(definition.Name, color)
		eventDescription.Text = escape(definition.Description)
		eventTime.Text = state:GetAttribute("EventScheduleWaiting") == true and "В БОЮ" or formatTime(state:GetAttribute("EventTime") or 0)
	end
	if centralGap < 180 then
		eventButton.Text = isAdmin and '<font color="#FF83CA"><b>V · ADMIN</b></font>' or '<font color="#8BE9FF"><b>V · LIVE</b></font>'
	else
		eventButton.Text = isAdmin and '<font color="#FF83CA"><b>V · ADMIN ABUSE / ИВЕНТЫ</b></font>' or '<font color="#8BE9FF"><b>V · ИВЕНТЫ И РАСПИСАНИЕ</b></font>'
	end
	for eventId, start in pairs(adminRows) do
		start.Visible = isAdmin
	end
	stopButton.Visible = isAdmin and active and not seasonMode
	for _, apply in pairs(seasonButtons) do
		apply.Visible = true
		apply.Active = isAdmin
		apply.AutoButtonColor = isAdmin
		apply.Text = isAdmin and "ПРИМЕНИТЬ" or "ADMIN ONLY"
	end
	if seasonMode then
		panelSubtitle.Text = isAdmin and "Visual theme · admin" or ("Тема: " .. tostring(state:GetAttribute("SeasonName") or "НОВЫЙ ГОД"))
		panelStatus.Text = isAdmin and "Только visual · server admin" or "Праздничные темы"
	else
		panelStatus.Text = isAdmin and "Battle · server admin" or "Общее расписание · награды"
	end
end

task.spawn(function()
	while gui.Parent do
		refresh()
		task.wait(0.1)
	end
end)
refresh()
