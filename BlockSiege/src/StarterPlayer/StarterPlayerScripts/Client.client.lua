-- BLOCKSIEGE: HUD, строительство, огонь, инвентарь и игровые кейсы.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local VisualModels = require(Shared:WaitForChild("VisualModels"))
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = {
	Background = Color3.fromRGB(12, 20, 34),
	Panel = Color3.fromRGB(25, 39, 58),
	Text = Color3.fromRGB(236, 245, 255),
	Muted = Color3.fromRGB(147, 170, 196),
	Blue = Color3.fromRGB(58, 184, 255),
	Orange = Color3.fromRGB(255, 133, 74),
	Gold = Color3.fromRGB(255, 204, 102),
	Green = Color3.fromRGB(73, 221, 174),
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
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 5) }, object)
end

local function gradient(object, topColor, bottomColor)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(topColor, bottomColor) }, object)
	new("UIStroke", { Color = Color3.fromRGB(68, 100, 135), Thickness = 1, Transparency = 0.12 }, object)
end

local function text(parent, value, size, position, textSize, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.Gotham,
		Text = value,
		TextColor3 = color or C.Text,
		TextSize = textSize or 18,
		TextWrapped = true,
	}, parent)
end

local function button(parent, value, size, position, color)
	local object = new("TextButton", {
		BackgroundColor3 = color or C.Panel,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.GothamBold,
		Text = value,
		TextColor3 = C.Text,
		TextSize = 16,
		TextStrokeTransparency = 1,
		AutoButtonColor = true,
	}, parent)
	corner(object, 8)
	new("UIStroke", { Color = Color3.fromRGB(68, 100, 135), Thickness = 1, Transparency = 0.12 }, object)
	return object
end

local gui = new("ScreenGui", {
	Name = "BlockSiegeUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0.96, 0, 0, 102),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.08,
}, gui)
corner(top, 7)
gradient(top, Color3.fromRGB(28, 48, 72), Color3.fromRGB(10, 18, 31))
local phaseLabel = text(top, "ЛОББИ", UDim2.new(0.42, 0, 0, 30), UDim2.new(0.02, 0, 0, 7), 23)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
local timeLabel = text(top, "", UDim2.new(0.25, 0, 0, 32), UDim2.new(0.38, 0, 0, 5), 25, C.Gold)
local teamLabel = text(top, "", UDim2.new(0.3, 0, 0, 32), UDim2.new(0.68, 0, 0, 7), 18)
teamLabel.TextXAlignment = Enum.TextXAlignment.Right

local coreFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, top)
local coreLabels = {}
local coreFills = {}
for index, team in ipairs({ "Blue", "Orange" }) do
	local left = index == 1
	local label = text(coreFrame, team == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ", UDim2.new(0.44, 0, 0, 22), UDim2.new(left and 0.02 or 0.54, 0, 0, 43), 16, C[team])
	label.TextXAlignment = left and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
	coreLabels[team] = label
	local back = new("Frame", {
		Position = UDim2.new(left and 0.02 or 0.54, 0, 0, 71),
		Size = UDim2.new(0.44, 0, 0, 17),
		BackgroundColor3 = Color3.fromRGB(8, 15, 27),
	}, coreFrame)
	corner(back, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C[team] }, back)
	corner(fill, 3)
	coreFills[team] = fill
end

local seasonLabel = text(top, "BLOCKSIEGE // NEW YEAR 2026", UDim2.new(1, -24, 0, 12), UDim2.new(0, 12, 0, 88), 11, Color3.fromRGB(255, 215, 116))
seasonLabel.Font = Enum.Font.GothamBold
seasonLabel.TextXAlignment = Enum.TextXAlignment.Center
seasonLabel.TextStrokeTransparency = 0.5
local seasonRule = new("Frame", {
	Position = UDim2.new(0, 10, 1, -3),
	Size = UDim2.new(1, -20, 0, 2),
	BackgroundColor3 = Color3.fromRGB(202, 48, 64),
	BorderSizePixel = 0,
}, top)
new("UIGradient", {
	Rotation = 0,
	Color = ColorSequence.new(Color3.fromRGB(202, 48, 64), Color3.fromRGB(30, 137, 91)),
}, seasonRule)

local lobbyDock = new("Frame", {
	Position = UDim2.new(0, 16, 1, -190), Size = UDim2.new(0, 280, 0, 174),
	BackgroundColor3 = C.Background, BackgroundTransparency = 0.04, BorderSizePixel = 0,
}, gui)
corner(lobbyDock, 10)
gradient(lobbyDock, Color3.fromRGB(28, 48, 72), Color3.fromRGB(10, 18, 31))
text(lobbyDock, "BLOCKSIEGE  /  6V6", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 7), 14, C.Gold)
local queueButton = button(lobbyDock, "В ОЧЕРЕДЬ 6×6", UDim2.new(1, -24, 0, 38), UDim2.new(0, 12, 0, 36), C.Blue)
local quickButton = button(lobbyDock, "БЫСТРЫЙ СТАРТ + БОТЫ", UDim2.new(1, -24, 0, 38), UDim2.new(0, 12, 0, 80), C.Green)
quickButton.TextColor3 = Color3.fromRGB(15, 42, 34)
local caseButton = button(lobbyDock, "ЛУТБОКС / ОРУЖИЕ  [L]", UDim2.new(1, -24, 0, 38), UDim2.new(0, 12, 0, 124), C.Panel)
local lobbyHint = text(gui, "1 · построй защиту   2 · уничтожь ядро   3 · получи награду и уровень", UDim2.new(0, 560, 0, 52), UDim2.new(0, 310, 1, -112), 17, C.Muted)

local buildDock = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0.9, 0, 0, 132), BackgroundColor3 = C.Background,
}, gui)
new("UISizeConstraint", { MinSize = Vector2.new(360, 132), MaxSize = Vector2.new(600, 132) }, buildDock)
corner(buildDock, 10)
gradient(buildDock, Color3.fromRGB(25, 46, 67), Color3.fromRGB(10, 18, 31))
local buildTitle = text(buildDock, "СТРОИТЕЛЬСТВО  ·  ТОЧНЫЙ ПРЕДПРОСМОТР", UDim2.new(1, -16, 0, 26), UDim2.new(0, 12, 0, 5), 16, C.Gold)
local buildButtons = {}
for index, entry in ipairs({ { "Wall", "1 СТЕНА" }, { "Barricade", "2 БАРРИКАДА" }, { "Tower", "3 БАШНЯ" } }) do
	local buildButton = button(buildDock, entry[2], UDim2.new(0.31, 0, 0, 38), UDim2.new((index - 1) * 0.345 + 0.015, 0, 0, 38), C.Panel)
	buildButtons[entry[1]] = buildButton
end
local buildRemaining = text(buildDock, "", UDim2.new(0.30, 0, 0, 38), UDim2.new(0.02, 0, 0, 84), 14, C.Muted)
local rotateLeftButton = button(buildDock, "↶ 90°", UDim2.new(0.13, 0, 0, 40), UDim2.new(0.34, 0, 0, 82), C.Panel)
rotateLeftButton.Name = "RotateLeftButton"
rotateLeftButton.TextSize = 15
local rotationReadout = text(buildDock, "R  ·  0°", UDim2.new(0.12, 0, 0, 40), UDim2.new(0.48, 0, 0, 82), 18, C.Gold)
rotationReadout.Name = "RotationReadout"
rotationReadout.TextXAlignment = Enum.TextXAlignment.Center
local rotateRightButton = button(buildDock, "90° ↷", UDim2.new(0.13, 0, 0, 40), UDim2.new(0.61, 0, 0, 82), C.Panel)
rotateRightButton.Name = "RotateRightButton"
rotateRightButton.TextSize = 15
local placeButton = button(buildDock, "ПОСТАВИТЬ", UDim2.new(0.23, 0, 0, 40), UDim2.new(0.75, 0, 0, 82), C.Green)
placeButton.Name = "PlaceBuildButton"
local trapDock = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -154), Size = UDim2.new(0.9, 0, 0, 44), BackgroundTransparency = 1,
}, gui)
new("UISizeConstraint", { MinSize = Vector2.new(360, 44), MaxSize = Vector2.new(600, 44) }, trapDock)
for index, id in ipairs(Catalog.DefenseOrder) do
	local definition = Catalog.Defenses[id]
	local trapButton = button(trapDock, tostring(index + 3) .. " " .. definition.Name, UDim2.new(0.31, 0, 0, 40), UDim2.new((index - 1) * 0.345 + 0.015, 0, 0, 0), Color3.fromRGB(116, 61, 51))
	buildButtons[id] = trapButton
end

local captureFrame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.new(0, 350, 0, 62), BackgroundColor3 = C.Background,
}, gui)
corner(captureFrame, 9)
gradient(captureFrame, Color3.fromRGB(28, 48, 72), Color3.fromRGB(10, 18, 31))
local captureTitle = text(captureFrame, "67 // ЗАХВАТ", UDim2.new(1, -16, 0, 27), UDim2.new(0, 8, 0, 4), 17, C.Gold)
local captureTrack = new("Frame", { Position = UDim2.new(0, 10, 0, 36), Size = UDim2.new(1, -20, 0, 14), BackgroundColor3 = Color3.fromRGB(8, 15, 27), BorderSizePixel = 0 }, captureFrame)
corner(captureTrack, 4)
local captureFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0 }, captureTrack)
corner(captureFill, 4)

local guideVisible = true
local coachFrame = new("Frame", {
	Position = UDim2.new(0, 16, 0, 190),
	Size = UDim2.new(0, 340, 0, 136),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.04,
}, gui)
corner(coachFrame, 10)
gradient(coachFrame, Color3.fromRGB(29, 48, 66), Color3.fromRGB(10, 18, 31))
local coachTitle = text(coachFrame, "ПОДСКАЗКА", UDim2.new(1, -24, 0, 23), UDim2.new(0, 12, 0, 7), 15, C.Gold)
coachTitle.Font = Enum.Font.GothamBold
coachTitle.TextXAlignment = Enum.TextXAlignment.Left
local coachText = text(coachFrame, "", UDim2.new(1, -24, 0, 66), UDim2.new(0, 12, 0, 32), 14, C.Text)
coachText.TextXAlignment = Enum.TextXAlignment.Left
coachText.TextYAlignment = Enum.TextYAlignment.Top
local coachFooter = text(coachFrame, "", UDim2.new(1, -100, 0, 24), UDim2.new(0, 12, 0, 105), 11, C.Muted)
coachFooter.TextXAlignment = Enum.TextXAlignment.Left
local coachNext = button(coachFrame, "ЕЩЁ ›", UDim2.new(0, 72, 0, 26), UDim2.new(1, -84, 0, 102), C.Panel)
coachNext.TextSize = 12

local bonusFrame = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 190),
	Size = UDim2.new(0, 330, 0, 258),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.04,
	Visible = false,
}, gui)
corner(bonusFrame, 10)
gradient(bonusFrame, Color3.fromRGB(45, 43, 52), Color3.fromRGB(12, 20, 32))
new("UIStroke", { Color = C.Gold, Thickness = 1.2, Transparency = 0.08 }, bonusFrame)
local bonusTitle = text(bonusFrame, "БОНУСЫ МАТЧА", UDim2.new(1, -24, 0, 25), UDim2.new(0, 12, 0, 6), 17, C.Gold)
bonusTitle.Font = Enum.Font.GothamBold
bonusTitle.TextXAlignment = Enum.TextXAlignment.Left
local bonusSummary = text(bonusFrame, "3 задания · награда сразу", UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 30), 12, C.Muted)
bonusSummary.TextXAlignment = Enum.TextXAlignment.Left
local missionRows = {}
for index = 1, 3 do
	local row = new("Frame", {
		Position = UDim2.new(0, 12, 0, 51 + (index - 1) * 50),
		Size = UDim2.new(1, -24, 0, 46),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, bonusFrame)
	corner(row, 7)
	local name = text(row, "", UDim2.new(1, -88, 0, 20), UDim2.new(0, 9, 0, 3), 14, C.Text)
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	local hint = text(row, "", UDim2.new(1, -88, 0, 20), UDim2.new(0, 9, 0, 23), 11, C.Muted)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	local progress = text(row, "", UDim2.new(0, 76, 0, 40), UDim2.new(1, -80, 0, 3), 12, C.Gold)
	progress.TextXAlignment = Enum.TextXAlignment.Right
	missionRows[index] = { Frame = row, Name = name, Hint = hint, Progress = progress }
end
local supplyLabel = text(bonusFrame, "", UDim2.new(1, -24, 0, 43), UDim2.new(0, 12, 0, 207), 12, C.Gold)
supplyLabel.TextXAlignment = Enum.TextXAlignment.Left
local guideToggle = button(gui, "H · СКРЫТЬ ПОДСКАЗКИ", UDim2.new(0, 220, 0, 30), UDim2.new(1, -346, 0, 151), C.Panel)
guideToggle.TextSize = 12

local waypointPart = new("Part", {
	Name = "LocalEnemyCoreWaypoint",
	Size = Vector3.one,
	Transparency = 1,
	Anchored = true,
	CanCollide = false,
	CanTouch = false,
	CanQuery = false,
	CastShadow = false,
}, Workspace)
local waypointGui = new("BillboardGui", {
	Name = "EnemyCoreDirection",
	Size = UDim2.fromOffset(250, 66),
	StudsOffset = Vector3.new(0, 18, 0),
	AlwaysOnTop = true,
	MaxDistance = 0,
	LightInfluence = 0,
	Enabled = false,
}, waypointPart)
local waypointBack = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Background, BackgroundTransparency = 0.2 }, waypointGui)
corner(waypointBack, 8)
new("UIStroke", { Color = C.Orange, Thickness = 2 }, waypointBack)
local waypointLabel = text(waypointBack, "", UDim2.new(1, -12, 1, -8), UDim2.new(0, 6, 0, 4), 16, C.Text)
waypointLabel.Font = Enum.Font.GothamBold
waypointLabel.TextStrokeTransparency = 0.35

local rewardToast = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 190),
	Size = UDim2.new(0.9, 0, 0, 78),
	BackgroundColor3 = Color3.fromRGB(20, 40, 43),
	Visible = false,
	ZIndex = 12,
}, gui)
new("UISizeConstraint", { MinSize = Vector2.new(280, 78), MaxSize = Vector2.new(420, 78) }, rewardToast)
corner(rewardToast, 10)
local rewardStroke = new("UIStroke", { Color = C.Green, Thickness = 2 }, rewardToast)
local rewardTitle = text(rewardToast, "", UDim2.new(1, -24, 0, 29), UDim2.new(0, 12, 0, 8), 18, C.Green)
rewardTitle.Font = Enum.Font.GothamBold
rewardTitle.ZIndex = 13
local rewardDetail = text(rewardToast, "", UDim2.new(1, -24, 0, 33), UDim2.new(0, 12, 0, 39), 15, C.Text)
rewardDetail.ZIndex = 13
local rewardQueue = {}
local rewardShowing = false
local function showNextReward()
	if rewardShowing or #rewardQueue == 0 then
		return
	end
	rewardShowing = true
	local payload = table.remove(rewardQueue, 1)
	local isLevel = payload.Type == "LevelUp"
	rewardToast.BackgroundColor3 = isLevel and Color3.fromRGB(54, 43, 25) or Color3.fromRGB(20, 40, 43)
	rewardStroke.Color = isLevel and C.Gold or C.Green
	rewardTitle.TextColor3 = isLevel and C.Gold or C.Green
	if isLevel then
		rewardTitle.Text = "★ УРОВЕНЬ " .. tostring(payload.Level) .. "!"
		local unlockText = {}
		for _, unlock in ipairs(payload.Unlocks or {}) do
			table.insert(unlockText, tostring(unlock.Text))
		end
		rewardDetail.Text = (#unlockText > 0 and table.concat(unlockText, " · ") or "Новый уровень") .. string.format(" · +%d монет", payload.LevelCoins or 0)
	else
		rewardTitle.Text = tostring(payload.Reason or "Награда")
		rewardDetail.Text = string.format("+%d монет  ·  +%d XP", payload.Coins or 0, payload.XP or 0)
	end
	rewardToast.Visible = true
	task.delay(isLevel and 4.5 or 2.6, function()
		rewardToast.Visible = false
		rewardShowing = false
		showNextReward()
	end)
end
local function queueReward(payload)
	if type(payload) ~= "table" then
		return
	end
	if #rewardQueue >= 6 then
		for index, queued in ipairs(rewardQueue) do
			if queued.Type ~= "LevelUp" then
				table.remove(rewardQueue, index)
				break
			end
		end
	end
	table.insert(rewardQueue, payload)
	showNextReward()
end

local crosshair = text(gui, "+", UDim2.new(0, 46, 0, 46), UDim2.new(0.5, -23, 0.5, -23), 34, C.Text)
crosshair.TextStrokeTransparency = 0.2
local weaponLabel = text(gui, "", UDim2.new(0, 350, 0, 38), UDim2.new(0, 18, 1, -58), 20, C.Text)
local fireButton = button(gui, "ОГОНЬ", UDim2.new(0, 126, 0, 70), UDim2.new(1, -146, 1, -104), C.Orange)
fireButton.Visible = false

local notifyLabel = text(gui, "", UDim2.new(0.8, 0, 0, 48), UDim2.new(0.1, 0, 0.72, 0), 20, C.Gold)
notifyLabel.TextStrokeTransparency = 0.25
local notifyVersion = 0
local function notify(message)
	notifyVersion = notifyVersion + 1
	local version = notifyVersion
	notifyLabel.Text = tostring(message)
	task.delay(3.5, function()
		if version == notifyVersion then
			notifyLabel.Text = ""
		end
	end)
end

local casePanel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.92, 0, 0.82, 0),
	BackgroundColor3 = C.Background, Visible = false,
}, gui)
corner(casePanel, 8)
gradient(casePanel, Color3.fromRGB(28, 48, 72), Color3.fromRGB(10, 18, 31))
new("UISizeConstraint", { MinSize = Vector2.new(300, 330), MaxSize = Vector2.new(590, 650) }, casePanel)
text(casePanel, "GEAR // ЛУТБОКС И ОРУЖИЕ", UDim2.new(1, -60, 0, 40), UDim2.new(0, 16, 0, 8), 23, C.Gold)
local closeCase = button(casePanel, "×", UDim2.new(0, 42, 0, 38), UDim2.new(1, -52, 0, 8), C.Panel)
local balanceLabel = text(casePanel, "", UDim2.new(1, -30, 0, 30), UDim2.new(0, 15, 0, 54), 19)
text(casePanel, "Обычное 65% · Редкое 30% · Легендарное 5% · гарант на 20-м", UDim2.new(1, -30, 0, 38), UDim2.new(0, 15, 0, 86), 16, C.Muted)
local openCoin = button(casePanel, "ОТКРЫТЬ ЗА 25 МОНЕТ", UDim2.new(0.47, 0, 0, 42), UDim2.new(0.02, 0, 0, 132), C.Green)
local openToken = button(casePanel, "ОТКРЫТЬ ЗА 1 ЖЕТОН", UDim2.new(0.47, 0, 0, 42), UDim2.new(0.51, 0, 0, 132), C.Blue)
local caseResult = text(casePanel, "Награды выдаёт сервер. Robux-кейсов нет.", UDim2.new(1, -30, 0, 52), UDim2.new(0, 15, 0, 181), 18, C.Gold)
text(casePanel, "ИНВЕНТАРЬ · нажмите, чтобы экипировать", UDim2.new(1, -30, 0, 28), UDim2.new(0, 15, 0, 238), 17, C.Muted)
local inventory = new("ScrollingFrame", {
	Position = UDim2.new(0.02, 0, 0, 272), Size = UDim2.new(0.96, 0, 1, -282), CanvasSize = UDim2.new(),
	BackgroundColor3 = C.Panel, BorderSizePixel = 0, ScrollBarThickness = 5,
}, casePanel)
corner(inventory)
local inventoryLayout = new("UIListLayout", { Padding = UDim.new(0, 5) }, inventory)
inventoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	inventory.CanvasSize = UDim2.new(0, 0, 0, inventoryLayout.AbsoluteContentSize.Y + 10)
end)

local resultsPanel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0, 326),
	BackgroundColor3 = C.Background, Visible = false,
}, gui)
new("UISizeConstraint", { MinSize = Vector2.new(300, 326), MaxSize = Vector2.new(580, 326) }, resultsPanel)
corner(resultsPanel, 12)
gradient(resultsPanel, Color3.fromRGB(35, 53, 76), Color3.fromRGB(12, 20, 34))
local resultTitle = text(resultsPanel, "МАТЧ ЗАВЕРШЁН", UDim2.new(1, -20, 0, 42), UDim2.new(0, 10, 0, 12), 28, C.Gold)
local resultReason = text(resultsPanel, "", UDim2.new(1, -30, 0, 44), UDim2.new(0, 15, 0, 56), 18)
local resultReward = text(resultsPanel, "", UDim2.new(1, -30, 0, 52), UDim2.new(0, 15, 0, 103), 18, C.Green)
local resultStats = text(resultsPanel, "", UDim2.new(1, -30, 0, 52), UDim2.new(0, 15, 0, 157), 16, C.Text)
local resultUnlock = text(resultsPanel, "", UDim2.new(1, -30, 0, 50), UDim2.new(0, 15, 0, 211), 17, C.Gold)
local resultNext = text(resultsPanel, "", UDim2.new(1, -30, 0, 36), UDim2.new(0, 15, 0, 275), 15, C.Muted)

local profile
local selectedBuild = "Wall"
local buildRotation = 0
local buildGhost
local buildGhostModel
local buildGhostModelPivotOffset = Vector3.zero
local buildGhostOutline
local ghostKind
local ghostHasServerPreview = false
local nextPreviewRequest = 0
local previewRequestId = 0
local activePreviewRequest = 0
local previewAimPosition
local previewSentPosition
local previewCFrame
local previewPosition
local previewRotation
local previewValid = false
local previewDirty = true
local lastResult
local coachPage = 0
local coachManualUntil = 0

local function setGuideVisible(visible)
	guideVisible = visible
	guideToggle.Text = visible and "H · СКРЫТЬ ПОДСКАЗКИ" or "H · ПОКАЗАТЬ ПОМОЩЬ"
	coachFrame.Visible = visible
	bonusFrame.Visible = visible
	waypointGui.Enabled = visible
end

local function coreDirection(team)
	if team == "" then
		return "↑", 0, nil
	end
	local enemy = Config.OtherTeam(team)
	local target = Config.BaseCFrame(enemy).Position + Vector3.new(0, 12, 0)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") or nil
	local origin = root and root.Position or (camera and camera.CFrame.Position) or target
	local distance = (target - origin).Magnitude
	local arrow = "↑"
	if camera and (target - camera.CFrame.Position).Magnitude > 0.1 then
		local direction = camera.CFrame:VectorToObjectSpace((target - camera.CFrame.Position).Unit)
		local angle = math.atan2(direction.X, -direction.Z)
		local arrows = { "↑", "↗", "→", "↘", "↓", "↙", "←", "↖" }
		local index = math.floor((angle + math.pi / 8) / (math.pi / 4)) % 8 + 1
		arrow = arrows[index]
	end
	return arrow, math.floor(distance + 0.5), target
end

local function updateWaypoint(phase, team)
	local visible = guideVisible and phase == "Battle" and team ~= ""
	waypointGui.Enabled = visible
	if not visible then
		return
	end
	local arrow, distance, target = coreDirection(team)
	if target then
		waypointPart.Position = target
		waypointLabel.Text = string.format("%s  ВРАЖЕСКОЕ ЯДРО\n%d м · уничтожь для победы", arrow, distance)
		waypointLabel.TextColor3 = C[Config.OtherTeam(team)] or C.Orange
	end
end

local function updateBonusMissions(phase, team)
	bonusFrame.Visible = guideVisible and (phase == "Build" or phase == "Battle") and team ~= ""
	local completedCount = player:GetAttribute("BonusCompleted") or 0
	local collected = player:GetAttribute("BonusSupplyCollected") or 0
	bonusSummary.Text = string.format("Выполнено %d/3 · ящики: %d · награда сразу", completedCount, collected)
	for index, row in ipairs(missionRows) do
		local definition = Catalog.GetBonusMission(player:GetAttribute("BonusMission" .. index .. "Id") or "")
		row.Frame.Visible = definition ~= nil
		if definition then
			local progress = math.min(definition.Target, player:GetAttribute("BonusMission" .. index .. "Progress") or 0)
			local completed = player:GetAttribute("BonusMission" .. index .. "Completed") == true
			row.Name.Text = (completed and "✓ " or "") .. definition.Name
			row.Name.TextColor3 = completed and C.Green or C.Text
			row.Hint.Text = definition.Hint
			row.Progress.Text = completed and string.format("ГОТОВО\n+%d · %dXP", definition.Coins, definition.XP) or string.format("%d/%d\n+%d · %dXP", progress, definition.Target, definition.Coins, definition.XP)
			row.Progress.TextColor3 = completed and C.Green or C.Gold
			row.Frame.BackgroundColor3 = completed and Color3.fromRGB(25, 65, 55) or C.Panel
		end
	end
	local active = state:GetAttribute("SupplyActive") or 0
	local nextSupply = state:GetAttribute("SupplyNext") or 0
	if phase == "Build" then
		supplyLabel.Text = "СНАБЖЕНИЕ · золотые ящики появятся в бою\n+15 монет · +30 XP · +25 HP"
	elseif active > 0 then
		supplyLabel.Text = string.format("ЯЩИКИ НА КАРТЕ: %d · иди к золотому лучу\n+15 монет · +30 XP · +25 HP", active)
	else
		supplyLabel.Text = string.format("ДО СНАБЖЕНИЯ: %d с\n+15 монет · +30 XP · +25 HP", nextSupply)
	end
end

local function updateCoach(phase, team, remaining, captureOwner)
	coachFrame.Visible = guideVisible and phase ~= "Results"
	guideToggle.Visible = phase ~= "Results"
	guideToggle.Text = guideVisible and "H · СКРЫТЬ ПОДСКАЗКИ" or "H · ПОКАЗАТЬ ПОМОЩЬ"
	if not coachFrame.Visible then
		return
	end
	local arrow, distance = coreDirection(team)
	local builds = player:GetAttribute("MatchBuilds") or 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
	local root = character and character:FindFirstChild("HumanoidRootPart") or nil
	local ammo = character and character:GetAttribute("Ammo") or 0
	local magazine = character and character:GetAttribute("Magazine") or 0
	local reloading = character and character:GetAttribute("Reloading") == true
	local manual = os.clock() < coachManualUntil
	local hints = {}
	local title = "ПОДСКАЗКА"
	if phase == "Lobby" then
		title = "НАЧНИ ЗДЕСЬ · ЛОББИ"
		hints = {
			"Нажми БЫСТРЫЙ СТАРТ: пустые места заполнят боты, строго 6×6. Обе команды строят, победа — уничтожение вражеского ядра.",
			"Нажми L или подойди к GEAR: открой кейс за игровые монеты/жетон, затем нажми на оружие в инвентаре, чтобы экипировать его.",
			"DAILY даёт ежедневную награду. DEFENSE продаёт шипы, мины и огненную ловушку. FORGE улучшает HP, броню, скорость и лимит построек.",
			"Перед боем осмотри витрину: есть огнестрельное оружие, ножи и легендарная перчатка. В матче класс и способности F/G выдаются случайно.",
		}
		coachFooter.Text = "L — снаряжение · H — скрыть/показать помощь"
	elseif (phase == "Build" or phase == "Battle") and team == "" then
		title = "НАБЛЮДЕНИЕ · СЛЕДУЮЩИЙ МАТЧ"
		coachText.Text = "Ты не занимаешь слот в этом матче. Дождись результатов и возврата в лобби, затем нажми БЫСТРЫЙ СТАРТ или встань в очередь 6×6."
		coachFooter.Text = "H — скрыть/показать помощь"
	elseif phase == "Build" then
		title = builds < 3 and "ШАГ 1 · ЗАЩИТИ СВОЮ КРЕПОСТЬ" or "ЗАЩИТА ГОТОВА · ДО ШТУРМА " .. tostring(remaining) .. " С"
		hints = {
			"Выбери 1 СТЕНА, 2 БАРРИКАДА или 3 БАШНЯ. Наведи прицел внутрь своей базы: зелёная модель — точное место установки, красная — запрет.",
			"Q/R и видимые кнопки ↶ ↷ поворачивают на 90°. Нажми ПОСТАВИТЬ, B или ЛКМ только после зелёного серверного предпросмотра.",
			"Стены закрывают подходы, башни атакуют врагов. Купленные в DEFENSE ловушки выбираются клавишами 4–6. Каждая постройка даёт монеты и XP.",
			"Справа — 3 бонусных задания. Укрепитель засчитывает постройки уже сейчас. В бою появятся золотые ящики с монетами, XP и лечением.",
		}
		if not manual and ghostHasServerPreview and not previewValid then
			title = "КРАСНЫЙ КОНТУР · ИЗМЕНИ ПОЗИЦИЮ"
			coachText.Text = "Объект не установлен. Наведи прицел на свободную площадку внутри своей базы, отойди от других моделей и дождись зелёного контура."
		elseif not manual and builds == 0 then
			coachText.Text = hints[1]
		elseif not manual and builds < 3 then
			coachText.Text = string.format("Построено %d/3. Добавь стены у прохода и башню рядом с ядром. Точная позиция и угол видны до подтверждения — преждевременной установки нет.", builds)
		else
			coachText.Text = hints[(coachPage % #hints) + 1]
		end
		coachFooter.Text = "Q/R — поворот · B — поставить · H — помощь"
	elseif phase == "Battle" then
		title = "ШАГ 2 · УНИЧТОЖЬ ВРАЖЕСКОЕ ЯДРО"
		local abilityF = player:GetAttribute("Ability1Name") or "способность F"
		local abilityG = player:GetAttribute("Ability2Name") or "способность G"
		local supplies = state:GetAttribute("SupplyActive") or 0
		hints = {
			string.format("Следуй за стрелкой %s: до вражеского ядра %d м. ЛКМ — огонь, R — перезарядка. Сносить башни и стены тоже выгодно: за них есть награды.", arrow, distance),
			"Захвати 67: встань в центральный круг и удерживай его. Команда получает монеты, XP и +1 HP/s. Если точку оспаривают — сначала выбей противника.",
			string.format("Твой случайный класс: %s. F — %s; G — %s. Применяй способности по откату: задание Специалист награждает три использования.", player:GetAttribute("ClassName") or "класс назначается", abilityF, abilityG),
			"Золотой вертикальный луч отмечает снабжение. Подойди к ящику или нажми ProximityPrompt: +15 монет, +30 XP и +25 HP. Ящик исчезает через 30 секунд.",
			"Выполняй 3 задания справа: разрушения, 67, F/G, лагеря, убийства или постройки. Награда начисляется сразу и каждое задание выполняется один раз за матч.",
		}
		local ownCore = state:GetAttribute(team .. "Core") or 0
		local ownMaximum = math.max(1, state:GetAttribute(team .. "CoreMax") or 1)
		local near67 = root and (root.Position - Vector3.new(0, root.Position.Y, 0)).Magnitude < 32
		if not manual and (reloading or (magazine > 0 and humanoid and humanoid.Health > 0 and ammo == 0)) then
			title = "ПЕРЕЗАРЯДКА · НЕ СТОЙ ОТКРЫТО"
			coachText.Text = reloading and "Оружие перезаряжается. Укройся за стеной или используй F/G; после перезарядки продолжай штурм по стрелке." or "Магазин пуст — нажми R. Во время перезарядки используй укрытие и способности F/G."
		elseif not manual and ownCore / ownMaximum < 0.3 then
			title = "ТВОЯ КРЕПОСТЬ В ОПАСНОСТИ"
			coachText.Text = "У своего ядра осталось меньше 30% HP. Вернись по командной метке, устрани штурмующих и используй защитные способности — затем продолжи атаку."
		elseif not manual and near67 and captureOwner ~= team then
			title = "67 РЯДОМ · УДЕРЖИВАЙ КРУГ"
			coachText.Text = "Оставайся внутри центральной зоны. Захват даёт всей команде награду и +1 HP/s; враг в круге оспаривает прогресс."
		elseif not manual and supplies > 0 and (player:GetAttribute("BonusSupplyCollected") or 0) == 0 then
			title = "БОНУС НА КАРТЕ · ЗОЛОТОЙ ЛУЧ"
			coachText.Text = "Снабжение уже лежит на арене. Найди золотой ящик у светового столба и подойди вплотную: +15 монет, +30 XP, +25 HP."
		else
			coachText.Text = hints[(coachPage % #hints) + 1]
		end
		coachFooter.Text = string.format("%s ядро: %d м · F/G — класс · H — помощь", arrow, distance)
	end
	coachTitle.Text = title
	if phase == "Lobby" then
		coachText.Text = hints[(coachPage % #hints) + 1]
	end
end

local function refreshInventory()
	for _, child in ipairs(inventory:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not profile then
		return
	end
	for _, weaponId in ipairs(Catalog.WeaponOrder) do
		if profile.OwnedWeapons[weaponId] then
			local weapon = Catalog.GetWeapon(weaponId)
			local selected = profile.SelectedWeapon == weaponId
			local row = button(inventory, (selected and "✓ " or "") .. weapon.Name .. " · " .. Catalog.RarityNames[weapon.Rarity], UDim2.new(1, -12, 0, 42), UDim2.new(), Catalog.RarityColors[weapon.Rarity])
			row.TextColor3 = Color3.fromRGB(24, 32, 32)
			row.Activated:Connect(function()
				remotes.CaseAction:FireServer("Equip", weaponId)
			end)
		end
	end
end

local function setBuildKind(kind)
	selectedBuild = kind
	activePreviewRequest = 0
	ghostHasServerPreview = false
	previewValid = false
	previewDirty = true
	previewCFrame = nil
	previewPosition = nil
	previewRotation = nil
	previewSentPosition = nil
	for id, object in pairs(buildButtons) do
		object.BackgroundColor3 = id == kind and C.Green or C.Panel
		object.TextColor3 = id == kind and Color3.fromRGB(24, 32, 32) or C.Text
	end
end
local function selectBuildKind(kind)
	local defense = Catalog.GetDefense(kind)
	if defense and player:GetAttribute("Defense_" .. kind) ~= true then
		notify(defense.Name .. ": купите чертёж у DEFENSE в лобби")
		return
	end
	setBuildKind(kind)
end
for id, object in pairs(buildButtons) do
	object.Activated:Connect(function()
		selectBuildKind(id)
	end)
end
setBuildKind("Wall")

local function syncGhostModel(cframe)
	if buildGhostModel and cframe then
		buildGhostModel:PivotTo(cframe * CFrame.new(buildGhostModelPivotOffset) * (ghostKind == "Tower" and CFrame.Angles(0, 0, math.rad(90)) or CFrame.new()))
	end
end

local function setGhostModelTransparency(transparency)
	if not buildGhostModel then
		return
	end
	for _, item in ipairs(buildGhostModel:GetDescendants()) do
		if item:IsA("BasePart") and item.Name ~= "VisualAnchor" then
			item.Transparency = transparency
		end
	end
end

local function clearBuildGhost()
	if buildGhost then
		buildGhost:Destroy()
	end
	if buildGhostModel then
		buildGhostModel:Destroy()
	end
	buildGhost = nil
	buildGhostModel = nil
	buildGhostModelPivotOffset = Vector3.zero
	buildGhostOutline = nil
	ghostKind = nil
	ghostHasServerPreview = false
	activePreviewRequest = 0
	previewAimPosition = nil
	previewSentPosition = nil
	previewCFrame = nil
	previewPosition = nil
	previewRotation = nil
	previewValid = false
	previewDirty = true
	placeButton.BackgroundColor3 = C.Green
	buildTitle.Text = "СТРОИТЕЛЬСТВО  ·  ТОЧНЫЙ ПРЕДПРОСМОТР"
	buildTitle.TextColor3 = C.Gold
end

local function ensureBuildGhost(kind)
	if buildGhost and ghostKind == kind then
		return
	end
	clearBuildGhost()
	local definition = Config.BuildKinds[kind]
	if not definition then
		return
	end
	ghostKind = kind
	buildGhost = new("Part", {
		Name = "ServerValidatedBuildGhost",
		Size = definition.Size,
		Color = Color3.fromRGB(255, 65, 65),
		Material = Enum.Material.Neon,
		Transparency = 0.38,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	}, Workspace)
	buildGhostOutline = new("SelectionBox", {
		Name = "GhostOutline",
		Adornee = buildGhost,
		Color3 = Color3.fromRGB(255, 65, 65),
		LineThickness = 0.06,
		SurfaceTransparency = 0.7,
	}, buildGhost)
	local teamColor = C[player:GetAttribute("Team") or ""] or C.Gold
	if kind == "Barricade" then
		buildGhostModel = VisualModels.Barricade(Workspace, buildGhost.CFrame, teamColor)
	elseif kind == "Wall" then
		buildGhostModel = VisualModels.Wall(Workspace, buildGhost.CFrame, teamColor)
	elseif kind == "Tower" then
		buildGhostModelPivotOffset = Vector3.new(0, -3.93, 0)
		buildGhostModel = VisualModels.Tower(Workspace, "BuildGhostTower", (buildGhost.CFrame * CFrame.new(0, -9, 0)).Position, 0.78, teamColor)
	end
	if buildGhostModel then
		syncGhostModel(buildGhost.CFrame)
		setGhostModelTransparency(0.35)
		buildGhost.Transparency = 0.92
	end
end

local function updateResults()
	local winner = state:GetAttribute("Winner") or ""
	resultTitle.Text = winner == "" and "НИЧЬЯ" or ((C[winner] and (winner == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ") or winner) .. " ПОБЕДИЛИ")
	resultTitle.TextColor3 = C[winner] or C.Gold
	resultReason.Text = state:GetAttribute("Reason") or ""
	if lastResult and lastResult.Reward then
		local reward = lastResult.Reward
		local stats = lastResult.Stats or {}
		local totalLevelCoins = (reward.LevelCoins or 0) + (stats.LevelCoins or 0)
		local levelBonus = totalLevelCoins > 0 and string.format(" · УРОВЕНЬ %d! +%d монет", reward.Level, totalLevelCoins) or ""
		resultReward.Text = string.format("За матч: +%d монет · +%d XP%s%s", reward.Coins, reward.XP, reward.Token and " · +1 жетон" or "", levelBonus)
		resultStats.Text = string.format("За действия: +%d монет · +%d XP\nПостройки %d · Бойцы %d · Сооружения %d · 67: %d", stats.Coins or 0, stats.XP or 0, stats.Builds or 0, stats.Kills or 0, stats.Structures or 0, stats.Captures or 0)
		local unlocks = {}
		for _, unlock in ipairs(stats.Unlocks or {}) do
			table.insert(unlocks, "LV " .. tostring(unlock.Level) .. ": " .. tostring(unlock.Text))
		end
		for _, unlock in ipairs(reward.Unlocks or {}) do
			table.insert(unlocks, "LV " .. tostring(unlock.Level) .. ": " .. tostring(unlock.Text))
		end
		resultUnlock.Text = #unlocks > 0 and ("ОТКРЫТО · " .. table.concat(unlocks, " · ")) or "Награды за действия начислены ещё до этого экрана."
		local nextLevel, nextReward = Catalog.GetNextLevelReward(reward.Level or 1)
		resultNext.Text = nextReward and string.format("ДАЛЬШЕ · LV %d: %s", nextLevel, nextReward.Description) or "Вся особая шкала открыта. Каждый следующий уровень даёт монеты."
	else
		resultReward.Text = "Наблюдение за матчем"
		resultStats.Text = ""
		resultUnlock.Text = ""
		resultNext.Text = ""
	end
end

local function refresh()
	local phase = state:GetAttribute("Phase") or "Lobby"
	local remaining = state:GetAttribute("Time") or 0
	local names = { Lobby = "ЛОББИ", Build = "СТРОИТЕЛЬСТВО", Battle = "ШТУРМ", Results = "РЕЗУЛЬТАТЫ" }
	phaseLabel.Text = names[phase] or phase
	timeLabel.Text = remaining > 0 and string.format("%02d:%02d", math.floor(remaining / 60), remaining % 60) or ""
	lobbyDock.Visible = phase == "Lobby"
	lobbyHint.Visible = phase == "Lobby"
	buildDock.Visible = phase == "Build"
	trapDock.Visible = phase == "Build"
	captureFrame.Visible = phase == "Build" or phase == "Battle"
	if phase ~= "Build" and buildGhost then
		clearBuildGhost()
	end
	crosshair.Visible = phase == "Battle"
	weaponLabel.Visible = phase == "Battle"
	fireButton.Visible = phase == "Battle" and UserInputService.TouchEnabled
	resultsPanel.Visible = phase == "Results"
	rewardToast.Position = UDim2.new(0.5, 0, 0, phase == "Results" and 118 or 190)
	coreFrame.Visible = phase ~= "Lobby"
	queueButton.Text = player:GetAttribute("Queued") and "ВЫЙТИ ИЗ ОЧЕРЕДИ" or "В ОЧЕРЕДЬ 6×6"
	local team = player:GetAttribute("Team") or ""
	teamLabel.Text = team ~= "" and ((team == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ") .. " · Lv " .. tostring(player:GetAttribute("MatchLevel") or 1)) or "НАБЛЮДЕНИЕ"
	teamLabel.TextColor3 = C[team] or C.Muted
	buildRemaining.Text = "Осталось построек: " .. tostring(player:GetAttribute("BuildRemaining") or 0)
	local equippedWeapon = Catalog.GetWeapon(player:GetAttribute("SelectedWeapon") or "Carbine") or Catalog.Weapons.Carbine
	local weaponSkin = player:GetAttribute("Cosmetic_WeaponSkin")
	local character = player.Character
	local ammo = character and character:GetAttribute("Ammo")
	local magazine = character and character:GetAttribute("Magazine")
	local reloading = character and character:GetAttribute("Reloading") == true
	local ammoText = ""
	if phase == "Battle" and ammo ~= nil and magazine ~= nil and magazine > 0 then
		ammoText = reloading and " · ПЕРЕЗАРЯДКА" or (" · " .. tostring(ammo) .. "/" .. tostring(magazine) .. " · R")
	end
	weaponLabel.Text = "ОРУЖИЕ: " .. equippedWeapon.Name .. (weaponSkin and weaponSkin ~= "Default" and " · GOLD" or "") .. ammoText
	balanceLabel.Text = string.format("Монеты: %d · Жетоны: %d · Pity: %d/20", player:GetAttribute("Coins") or 0, player:GetAttribute("CaseTokens") or 0, player:GetAttribute("LegendaryPity") or 0)
	for _, teamName in ipairs({ "Blue", "Orange" }) do
		local health = state:GetAttribute(teamName .. "Core") or 0
		local maximum = math.max(1, state:GetAttribute(teamName .. "CoreMax") or 1)
		coreFills[teamName].Size = UDim2.fromScale(math.clamp(health / maximum, 0, 1), 1)
		coreLabels[teamName].Text = (teamName == "Blue" and "СИНИЕ · " or "ОРАНЖЕВЫЕ · ") .. tostring(health)
	end
	local captureOwner = state:GetAttribute("Capture67Owner") or ""
	local captureProgress = state:GetAttribute("Capture67Progress") or 0
	local captureContested = state:GetAttribute("Capture67Contested") == true
	local ownerText = captureOwner == "" and "НЕЙТРАЛЬНАЯ" or (captureOwner == team and "ВАША" or (captureOwner == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ"))
	captureTitle.Text = phase == "Build" and "67 // В БОЮ: НАГРАДА + РЕГЕНЕРАЦИЯ" or ("67 // " .. ownerText .. (captureContested and " · ОСПАРИВАЕТСЯ" or (captureOwner ~= "" and " · +1 HP/s" or "")))
	captureTitle.TextColor3 = captureContested and C.Orange or (C[captureOwner] or C.Gold)
	captureFill.BackgroundColor3 = C[captureOwner] or C.Gold
	captureFill.Size = UDim2.fromScale(math.clamp(captureProgress / 100, 0, 1), 1)
	updateBonusMissions(phase, team)
	updateCoach(phase, team, remaining, captureOwner)
	updateWaypoint(phase, team)
	if phase == "Results" then
		updateResults()
	end
end

guideToggle.Activated:Connect(function()
	setGuideVisible(not guideVisible)
	refresh()
end)
coachNext.Activated:Connect(function()
	coachPage = coachPage + 1
	coachManualUntil = os.clock() + 8
	refresh()
end)

queueButton.Activated:Connect(function()
	remotes.LobbyAction:FireServer("Queue")
end)
quickButton.Activated:Connect(function()
	remotes.LobbyAction:FireServer("QuickStart")
end)
caseButton.Activated:Connect(function()
	casePanel.Visible = not casePanel.Visible
end)
closeCase.Activated:Connect(function()
	casePanel.Visible = false
end)
openCoin.Activated:Connect(function()
	remotes.CaseAction:FireServer("OpenCoin")
end)
openToken.Activated:Connect(function()
	remotes.CaseAction:FireServer("OpenToken")
end)

local function aimPosition()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local camera = Workspace.CurrentCamera
		return camera.CFrame.Position + camera.CFrame.LookVector * 180
	end
	return mouse.Hit.Position
end

local function buildPosition()
	-- Mouse.Hit can select an existing barricade or the preview itself. Use a
	-- filtered ray instead, so the destination does not jump between structures.
	local camera = Workspace.CurrentCamera
	local ok, result = pcall(function()
		local origin, direction
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			origin = camera.CFrame.Position
			direction = camera.CFrame.LookVector * 48
		else
			local mouseLocation = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
			origin = ray.Origin
			direction = ray.Direction * 512
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignored = { player.Character }
		if buildGhost then
			table.insert(ignored, buildGhost)
		end
		local world = Workspace:FindFirstChild("BlockSiegeWorld")
		local structures = world and world:FindFirstChild("Structures")
		if structures then
			table.insert(ignored, structures)
		end
		local bots = world and world:FindFirstChild("Bots")
		if bots then
			table.insert(ignored, bots)
		end
		params.FilterDescendantsInstances = ignored
		local hit = Workspace:Raycast(origin, direction, params)
		return hit and hit.Position or nil
	end)
	if ok and result then
		return result
	end
	-- Compatibility fallback for touch/Studio mocks and a camera over empty sky.
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return camera.CFrame.Position + camera.CFrame.LookVector * 32
	end
	return mouse.Hit.Position
end

local function rotateBuild(direction)
	local previousRotation = buildRotation
	buildRotation = (buildRotation + (direction or 1) * 90) % 360
	rotationReadout.Text = "СТОРОНА  ·  " .. tostring(buildRotation) .. "°"
	-- Rotation is an edit to the preview only. It never calls BuildRequest.
	-- Invalidate old responses while retaining the last visible destination.
	activePreviewRequest = 0
	ghostHasServerPreview = false
	previewValid = false
	previewRotation = nil
	previewDirty = true
	if buildGhost and previewCFrame then
		local delta = (buildRotation - previousRotation) % 360
		previewCFrame = previewCFrame * CFrame.Angles(0, math.rad(delta), 0)
		buildGhost.CFrame = previewCFrame
		syncGhostModel(previewCFrame)
		setGhostModelTransparency(0.58)
		buildGhost.Color = C.Gold
		buildGhost.Transparency = 0.58
	end
	buildTitle.Text = "СТОРОНА " .. tostring(buildRotation) .. "° · дождитесь зелёного preview"
	buildTitle.TextColor3 = C.Gold
end

rotateLeftButton.Activated:Connect(function()
	rotateBuild(-1)
end)
rotateRightButton.Activated:Connect(function()
	rotateBuild(1)
end)

local function requestBuild()
	if state:GetAttribute("Phase") ~= "Build" then
		return
	end
	-- Confirm exactly what the player sees. Never use a fresh mouse.Hit after
	-- the green preview has been shown, and never place while it is stale/red.
	if not buildGhost or not ghostHasServerPreview or not previewValid or not previewPosition then
		notify("Сначала выберите позицию и сторону · дождитесь зелёного preview")
		return
	end
	local kind = selectedBuild
	local position = previewPosition
	local rotation = previewRotation or buildRotation
	ghostHasServerPreview = false
	previewValid = false
	previewRotation = nil
	previewDirty = true
	activePreviewRequest = 0
	remotes.BuildRequest:FireServer(kind, position, rotation)
	buildTitle.Text = "ПОДТВЕРЖДЕНО · выберите следующую позицию"
	buildTitle.TextColor3 = C.Green
end

placeButton.Activated:Connect(requestBuild)

local firing = false
local nextFire = 0
local function fire()
	if os.clock() < nextFire then
		return
	end
	nextFire = os.clock() + 0.065
	remotes.FireRequest:FireServer(aimPosition())
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if state:GetAttribute("Phase") == "Build" then
			requestBuild()
		elseif state:GetAttribute("Phase") == "Battle" then
			firing = true
			fire()
		end
	elseif input.KeyCode == Enum.KeyCode.One then
		selectBuildKind("Wall")
	elseif input.KeyCode == Enum.KeyCode.Two then
		selectBuildKind("Barricade")
	elseif input.KeyCode == Enum.KeyCode.Three then
		selectBuildKind("Tower")
	elseif input.KeyCode == Enum.KeyCode.Four or input.KeyCode == Enum.KeyCode.Five or input.KeyCode == Enum.KeyCode.Six then
		local index = input.KeyCode == Enum.KeyCode.Four and 1 or (input.KeyCode == Enum.KeyCode.Five and 2 or 3)
		selectBuildKind(Catalog.DefenseOrder[index])
	elseif input.KeyCode == Enum.KeyCode.R then
		if state:GetAttribute("Phase") == "Battle" then
			remotes.ReloadRequest:FireServer()
		else
			rotateBuild(1)
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		rotateBuild(-1)
	elseif input.KeyCode == Enum.KeyCode.B then
		requestBuild()
	elseif input.KeyCode == Enum.KeyCode.H then
		setGuideVisible(not guideVisible)
		refresh()
	elseif input.KeyCode == Enum.KeyCode.L then
		casePanel.Visible = not casePanel.Visible
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	end
end)
fireButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		firing = true
		fire()
	end
end)
fireButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		firing = false
	end
end)

RunService.RenderStepped:Connect(function()
	if firing and state:GetAttribute("Phase") == "Battle" then
		fire()
	end
	if state:GetAttribute("Phase") == "Build" then
		ensureBuildGhost(selectedBuild)
		if buildGhost then
			local ok, position = pcall(buildPosition)
			if ok and position then
				previewAimPosition = position
				if not previewSentPosition or (position - previewSentPosition).Magnitude > 0.75 then
					previewDirty = true
				end
				-- Only the very first preview uses a raw local CFrame. Afterwards
				-- the last server destination stays still until its replacement is valid.
				if not previewCFrame then
					previewCFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(buildRotation), 0)
					buildGhost.CFrame = previewCFrame
					syncGhostModel(previewCFrame)
				end
				local now = os.clock()
				if now >= nextPreviewRequest and previewDirty then
					nextPreviewRequest = now + 0.18
					previewRequestId = previewRequestId + 1
					activePreviewRequest = previewRequestId
					previewSentPosition = position
					previewDirty = false
					ghostHasServerPreview = false
					previewValid = false
					buildTitle.Text = "ОПРЕДЕЛЯЕМ ПОЗИЦИЮ · сторона " .. tostring(buildRotation) .. "°"
					buildTitle.TextColor3 = C.Gold
					remotes.BuildPreviewRequest:FireServer(selectedBuild, position, buildRotation, activePreviewRequest)
				end
			end
		end
	end
end)

local function effect(position, color, size, lifetime)
	local part = new("Part", {
		Position = position, Size = Vector3.one * size, Color = color, Material = Enum.Material.Neon,
		Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 0.15,
	}, Workspace)
	if size >= 3 then
		local light = new("PointLight", { Color = color, Brightness = math.min(5, size / 3), Range = size * 2 }, part)
		TweenService:Create(light, TweenInfo.new(lifetime), { Brightness = 0 }):Play()
	end
	TweenService:Create(part, TweenInfo.new(lifetime), { Size = Vector3.one * size * 1.65, Transparency = 1 }):Play()
	Debris:AddItem(part, lifetime + 0.05)
end

local function burst(position, color, count, power)
	for _ = 1, count do
		local lifetime = 0.35 + math.random() * 0.35
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		local part = new("Part", {
			Position = position, Size = Vector3.one * (0.4 + math.random() * 0.7), Color = color,
			Material = Enum.Material.Neon, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 0.05,
		}, Workspace)
		TweenService:Create(part, TweenInfo.new(lifetime), {
			Position = position + direction * power * (0.6 + math.random() * 0.7), Size = Vector3.one * 0.05, Transparency = 1,
		}):Play()
		Debris:AddItem(part, lifetime + 0.05)
	end
end

remotes.CombatFX.OnClientEvent:Connect(function(payload)
	if payload.Melee == true or payload.Kind == "Melee" then
		local color = payload.Color or C.Gold
		effect(payload.Finish or payload.Position, color, 1.8, 0.12)
		burst(payload.Finish or payload.Position, color, 5, 3)
	elseif payload.Kind == "Shot" or payload.Kind == "TowerShot" or payload.Kind == "NeutralShot" then
		local distance = (payload.Finish - payload.Origin).Magnitude
		if distance > 0.1 then
			local width = payload.WeaponId == "Rail" and 0.3 or (payload.Kind == "Shot" and 0.12 or 0.18)
			local beam = new("Part", {
				Size = Vector3.new(width, width, distance), CFrame = CFrame.lookAt(payload.Origin:Lerp(payload.Finish, 0.5), payload.Finish),
				Color = payload.Color or C[payload.Team] or C.Gold, Material = Enum.Material.Neon, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 0.08,
			}, Workspace)
			TweenService:Create(beam, TweenInfo.new(0.07), { Transparency = 1 }):Play()
			Debris:AddItem(beam, 0.08)
		end
	elseif payload.Kind == "CoreDestroyed" then
		local color = C[payload.Team] or C.Gold
		effect(payload.Position, color, 18, 0.8)
		burst(payload.Position, color, 28, 32)
	elseif payload.Kind == "StructureDestroyed" then
		local color = C[payload.Team] or C.Gold
		effect(payload.Position, color, 5, 0.35)
		burst(payload.Position, color, 10, 12)
	elseif payload.Kind == "NeutralDefeated" then
		local color = payload.Color or C.Green
		effect(payload.Position, color, 7, 0.45)
		burst(payload.Position, color, 16, 12)
	else
		effect(payload.Position, C[payload.Team] or C.Gold, 2.2, 0.14)
		burst(payload.Position, C[payload.Team] or C.Gold, 3, 4)
	end
end)
remotes.BuildFX.OnClientEvent:Connect(function(payload)
	local color = C[payload.Team] or C.Green
	effect(payload.Position, color, 3, 0.2)
	burst(payload.Position, color, 6, 5)
end)
remotes.TrapFX.OnClientEvent:Connect(function(payload)
	local color = payload.Kind == "FlameTrap" and Color3.fromRGB(255, 105, 35) or (payload.Kind == "ShockMine" and Color3.fromRGB(93, 190, 255) or Color3.fromRGB(255, 213, 92))
	local position = payload.Position
	if position then
		effect(position, color, payload.Kind == "ShockMine" and 5 or 3, 0.35)
		burst(position, color, 12, 8)
	end
end)
remotes.CaptureFX.OnClientEvent:Connect(function(payload)
	if payload.Position then
		local color = C[payload.Team] or C.Gold
		effect(payload.Position, color, 8, 0.5)
		burst(payload.Position, color, 18, 14)
	end
	if payload.Team then
		notify("67 ЗАХВАЧЕНА · +1 HP/s · " .. (payload.Team == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ"))
	end
end)
remotes.BonusFX.OnClientEvent:Connect(function(payload)
	if not payload.Position then
		return
	end
	local color = payload.Color or C.Gold
	effect(payload.Position, color, payload.Kind == "Supply" and 7 or 5, 0.5)
	burst(payload.Position, color, 18, 13)
	local anchor = new("Part", {
		Position = payload.Position + Vector3.new(0, 3, 0), Size = Vector3.one, Transparency = 1,
		Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
	}, Workspace)
	local tag = new("BillboardGui", { Size = UDim2.fromOffset(250, 48), AlwaysOnTop = true, MaxDistance = 140 }, anchor)
	local label = text(tag, payload.Kind == "Supply" and "СНАБЖЕНИЕ СОБРАНО!" or "БОНУС ВЫПОЛНЕН!", UDim2.fromScale(1, 1), UDim2.new(), 20, color)
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.2
	TweenService:Create(anchor, TweenInfo.new(1.2), { Position = anchor.Position + Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.25)
end)
remotes.BuildPreview.OnClientEvent:Connect(function(payload)
	if payload.Kind ~= selectedBuild or (payload.Rotation or 0) ~= buildRotation or state:GetAttribute("Phase") ~= "Build" then
		return
	end
	-- A response from an older aim/rotation/kind must never move the ghost.
	if payload.RequestId ~= nil and payload.RequestId ~= activePreviewRequest then
		return
	end
	if payload.RequestId == nil and previewRequestId > 0 and activePreviewRequest == 0 then
		return
	end
	if previewAimPosition and previewSentPosition and (previewAimPosition - previewSentPosition).Magnitude > 1.25 then
		previewDirty = true
		return
	end
	ensureBuildGhost(payload.Kind)
	if not buildGhost then
		return
	end
	local nextCFrame = payload.CFrame
	if not nextCFrame and payload.Position then
		nextCFrame = CFrame.new(payload.Position) * CFrame.Angles(0, math.rad(payload.Rotation or buildRotation), 0)
	end
	if not nextCFrame then
		return
	end
	previewCFrame = nextCFrame
	previewPosition = nextCFrame.Position
	previewRotation = tonumber(payload.Rotation) or buildRotation
	previewValid = payload.Valid == true
	ghostHasServerPreview = true
	buildGhost.CFrame = nextCFrame
	syncGhostModel(nextCFrame)
	local color = previewValid and Color3.fromRGB(65, 255, 130) or Color3.fromRGB(255, 65, 65)
	buildGhost.Color = color
	buildGhost.Transparency = buildGhostModel and 0.92 or (previewValid and 0.42 or 0.28)
	buildGhost:SetAttribute("ServerValid", previewValid)
	buildGhost:SetAttribute("PreviewRequestId", activePreviewRequest)
	setGhostModelTransparency(previewValid and 0.35 or 0.52)
	if buildGhostOutline then
		buildGhostOutline.Color3 = color
	end
	placeButton.BackgroundColor3 = previewValid and C.Green or Color3.fromRGB(170, 65, 65)
	buildTitle.Text = previewValid and "ГОТОВО · сторона " .. tostring(buildRotation) .. "° · ПОСТАВИТЬ" or ("НЕЛЬЗЯ: " .. tostring(payload.Reason))
	buildTitle.TextColor3 = color
end)

remotes.Notify.OnClientEvent:Connect(notify)
remotes.ProgressionFX.OnClientEvent:Connect(queueReward)
remotes.CaseOpened.OnClientEvent:Connect(function(result)
	casePanel.Visible = true
	caseResult.Text = (result.Duplicate and "ДУБЛИКАТ · " or "ПОЛУЧЕНО · ") .. result.Name .. " · " .. Catalog.RarityNames[result.Rarity] .. (result.Duplicate and " · +" .. result.Compensation .. " монет" or "")
	caseResult.TextColor3 = Catalog.RarityColors[result.Rarity]
end)
remotes.ProfileUpdate.OnClientEvent:Connect(function(data)
	profile = data
	refreshInventory()
end)
remotes.Results.OnClientEvent:Connect(function(result)
	lastResult = result
	updateResults()
end)
remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == nil or name == "Cases" then
		casePanel.Visible = true
	end
end)
player.CharacterAdded:Connect(function(character)
	mouse.TargetFilter = character
end)
if player.Character then
	mouse.TargetFilter = player.Character
end
state:GetAttributeChangedSignal("Phase"):Connect(refresh)
task.spawn(function()
	while gui.Parent do
		refresh()
		task.wait(0.1)
	end
end)
refresh()
