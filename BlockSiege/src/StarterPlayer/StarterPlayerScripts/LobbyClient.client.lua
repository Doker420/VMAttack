-- Lobby progression HUD and NPC panels: upgrades, daily rewards, coin defenses and cosmetic-only Robux shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = {
	Background = Color3.fromRGB(20, 28, 48),
	Panel = Color3.fromRGB(36, 49, 76),
	Text = Color3.fromRGB(248, 250, 255),
	Muted = Color3.fromRGB(177, 192, 216),
	Gold = Color3.fromRGB(255, 197, 68),
	Green = Color3.fromRGB(75, 211, 137),
	Cyan = Color3.fromRGB(80, 202, 255),
	Purple = Color3.fromRGB(195, 117, 255),
	Red = Color3.fromRGB(255, 110, 100),
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
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, object)
end

local function escapeRich(value)
	local escaped = tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
	return escaped
end

local function hexColor(color)
	color = color or C.Text
	return string.format("%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function rich(value, color)
	return string.format('<font color="#%s"><b>%s</b></font>', hexColor(color), escapeRich(value))
end

local function highlight(value)
	local formatted = escapeRich(value)
	formatted = formatted:gsub("6×6", '<font color="#62DFFF"><b>6×6</b></font>')
	formatted = formatted:gsub("75", '<font color="#FFD166"><b>75</b></font>')
	formatted = formatted:gsub("(%+%d+)", '<font color="#72E6B1"><b>%1</b></font>')
	formatted = formatted:gsub("БЫСТРЫЙ СТАРТ", '<font color="#72E6B1"><b>БЫСТРЫЙ СТАРТ</b></font>')
	return formatted
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
		TextSize = textSize or 17,
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
		TextSize = 16,
		AutoButtonColor = true,
	}, parent)
	corner(object)
	new("UIStroke", { Color = Color3.fromRGB(91, 108, 101), Thickness = 1 }, object)
	return object
end

local gui = new("ScreenGui", {
	Name = "BlockSiegeLobbyUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local statsPanel = new("Frame", {
	Position = UDim2.new(0, 16, 0, 112),
	Size = UDim2.new(0, 330, 0, 148),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.04,
}, gui)
corner(statsPanel, 10)
new("UIStroke", { Color = Color3.fromRGB(79, 104, 148), Thickness = 1 }, statsPanel)
local levelLabel = label(statsPanel, "УРОВЕНЬ 1", UDim2.new(0.48, 0, 0, 29), UDim2.new(0, 12, 0, 7), 21, C.Gold)
levelLabel.Font = Enum.Font.GothamBold
local xpLabel = label(statsPanel, "0 / 80 XP", UDim2.new(0.48, -12, 0, 25), UDim2.new(0.5, 0, 0, 10), 14, C.Muted)
xpLabel.TextXAlignment = Enum.TextXAlignment.Right
local xpTrack = new("Frame", { Position = UDim2.new(0, 12, 0, 40), Size = UDim2.new(1, -24, 0, 10), BackgroundColor3 = C.Panel }, statsPanel)
corner(xpTrack, 5)
local xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold }, xpTrack)
corner(xpFill, 5)
local statsLabel = label(statsPanel, "HP 120/120 · ARMOR 0%", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 59), 15, C.Text)
local speedLabel = label(statsPanel, "SPEED 20 · BUILDS 14", UDim2.new(1, -24, 0, 23), UDim2.new(0, 12, 0, 85), 14, C.Cyan)
local coinsLabel = label(statsPanel, "МОНЕТЫ 0 · ЖЕТОНЫ 0", UDim2.new(1, -24, 0, 25), UDim2.new(0, 12, 0, 113), 14, C.Gold)

local guidePanel = new("Frame", {
	Position = UDim2.new(0, 16, 0, 270),
	Size = UDim2.new(0, 330, 0, 148),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.04,
}, gui)
corner(guidePanel, 10)
new("UIStroke", { Color = C.Green, Thickness = 1 }, guidePanel)
local guideTitle = label(guidePanel, "ТВОЙ СЛЕДУЮЩИЙ ШАГ", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 0, 8), 15, C.Green)
guideTitle.Font = Enum.Font.GothamBold
local guideText = label(guidePanel, "Нажми БЫСТРЫЙ СТАРТ — пустые места займут боты.", UDim2.new(1, -24, 0, 55), UDim2.new(0, 12, 0, 38), 15, C.Text)
guideText.TextXAlignment = Enum.TextXAlignment.Left
local nextRewardLabel = label(guidePanel, "LV 2 · RAPID SMG + 50 монет + жетон", UDim2.new(1, -24, 0, 42), UDim2.new(0, 12, 0, 99), 14, C.Gold)
nextRewardLabel.TextXAlignment = Enum.TextXAlignment.Left

local lobbyDock = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 122),
	Size = UDim2.new(0, 300, 0, 249),
	BackgroundTransparency = 1,
}, gui)
local rewardsButton = button(lobbyDock, "★  НАГРАДЫ УРОВНЕЙ  [J]", UDim2.new(1, 0, 0, 42), UDim2.new(), C.Green)
rewardsButton.TextColor3 = Color3.fromRGB(16, 40, 31)
local upgradeButton = button(lobbyDock, "КУЗНИЦА · УЛУЧШЕНИЯ  [U]", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 49), C.Cyan)
upgradeButton.TextColor3 = Color3.fromRGB(22, 37, 40)
local dailyButton = button(lobbyDock, "ПОДАРОК · ЕЖЕДНЕВНЫЙ БОНУС", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 98), C.Gold)
dailyButton.TextColor3 = Color3.fromRGB(35, 32, 22)
local shopButton = button(lobbyDock, "КОСМЕТИКА · МАГАЗИН  [K]", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 147), C.Purple)
local defenseButton = button(lobbyDock, "ОБОРОНА · ЛОВУШКИ / МИНЫ", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 196), Color3.fromRGB(232, 126, 64))

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.53),
	Size = UDim2.new(0.92, 0, 0.82, 0),
	BackgroundColor3 = C.Background,
	Visible = false,
}, gui)
corner(panel, 8)
new("UIStroke", { Color = Color3.fromRGB(107, 130, 121), Thickness = 2 }, panel)
new("UISizeConstraint", { MinSize = Vector2.new(310, 350), MaxSize = Vector2.new(650, 660) }, panel)
local panelTitle = label(panel, "FORGE", UDim2.new(1, -70, 0, 42), UDim2.new(0, 16, 0, 8), 24, C.Gold)
local closeButton = button(panel, "×", UDim2.new(0, 42, 0, 38), UDim2.new(1, -52, 0, 8), C.Panel)
local panelHint = label(panel, "", UDim2.new(1, -32, 0, 35), UDim2.new(0, 16, 0, 51), 15, C.Muted)

local upgradeFrame = new("Frame", { Size = UDim2.new(1, -32, 1, -100), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1, Visible = false }, panel)
local dailyFrame = new("Frame", { Size = UDim2.new(1, -32, 1, -100), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1, Visible = false }, panel)
local shopFrame = new("ScrollingFrame", { Size = UDim2.new(1, -32, 1, -100), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1, Visible = false, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(0, 0, 0, #Catalog.CosmeticOrder * 106) }, panel)
local defenseFrame = new("Frame", { Size = UDim2.new(1, -32, 1, -100), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1, Visible = false }, panel)
local rewardsFrame = new("Frame", { Size = UDim2.new(1, -32, 1, -100), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1, Visible = false }, panel)

local rewardRows = {}
local rewardList = new("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, #Catalog.LevelRewardOrder * 68),
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = C.Cyan,
}, rewardsFrame)
new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, rewardList)
for index, rewardLevel in ipairs(Catalog.LevelRewardOrder) do
	local reward = Catalog.LevelRewards[rewardLevel]
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 60), BackgroundColor3 = C.Panel, LayoutOrder = index }, rewardList)
	corner(row, 8)
	local badge = label(row, "LV " .. rewardLevel, UDim2.new(0, 66, 1, 0), UDim2.new(0, 8, 0, 0), 18, C.Gold)
	badge.Font = Enum.Font.GothamBold
	local description = label(row, escapeRich(reward.Description), UDim2.new(1, -176, 1, -8), UDim2.new(0, 79, 0, 4), 14, C.Text)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local status = label(row, "ЗАКРЫТО", UDim2.new(0, 92, 1, 0), UDim2.new(1, -98, 0, 0), 12, C.Muted)
	status.Font = Enum.Font.GothamBold
	rewardRows[rewardLevel] = { Row = row, Status = status }
end

local upgradeRows = {}
for index, id in ipairs(Catalog.UpgradeOrder) do
	local definition = Catalog.Upgrades[id]
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 76), Position = UDim2.new(0, 0, 0, (index - 1) * 83), BackgroundColor3 = C.Panel }, upgradeFrame)
	corner(row)
	label(row, rich(definition.Name, C.Cyan), UDim2.new(0.55, 0, 0, 24), UDim2.new(0, 10, 0, 6), 18, C.Cyan)
	local description = label(row, definition.Description, UDim2.new(0.58, 0, 0, 38), UDim2.new(0, 10, 0, 30), 13, C.Muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local action = button(row, "", UDim2.new(0.36, 0, 0, 56), UDim2.new(0.62, 0, 0, 10), C.Green)
	action.Activated:Connect(function()
		remotes.ProgressionAction:FireServer("Upgrade", id)
	end)
	upgradeRows[id] = { Action = action }
end

label(dailyFrame, "ПОДАРОК ЗА ВХОД", UDim2.new(1, 0, 0, 44), UDim2.new(), 28, C.Gold)
label(dailyFrame, "Монеты, XP и жетон кейса. Чем выше уровень, тем больше монет.\nКейсы по-прежнему открываются только за игровую валюту.", UDim2.new(1, 0, 0, 92), UDim2.new(0, 0, 0, 58), 18, C.Text)
local dailyStatus = label(dailyFrame, "", UDim2.new(1, 0, 0, 48), UDim2.new(0, 0, 0, 166), 19, C.Cyan)
local dailyClaim = button(dailyFrame, "ПОЛУЧИТЬ БОНУС", UDim2.new(1, 0, 0, 58), UDim2.new(0, 0, 0, 235), C.Green)
dailyClaim.Activated:Connect(function()
	remotes.ProgressionAction:FireServer("Daily")
end)
label(dailyFrame, "Сервер проверяет cooldown и сохраняет награду в профиле.", UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 315), 15, C.Muted)

local shopRows = {}
for index, id in ipairs(Catalog.CosmeticOrder) do
	local definition = Catalog.Cosmetics[id]
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 98), Position = UDim2.new(0, 0, 0, (index - 1) * 106), BackgroundColor3 = C.Panel }, shopFrame)
	corner(row)
	label(row, rich(definition.Name, C.Purple), UDim2.new(0.58, 0, 0, 26), UDim2.new(0, 10, 0, 6), 18, C.Purple)
	local description = label(row, definition.Description, UDim2.new(0.58, 0, 0, 54), UDim2.new(0, 10, 0, 34), 13, C.Muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local action = button(row, "", UDim2.new(0.36, 0, 0, 70), UDim2.new(0.62, 0, 0, 14), C.Purple)
	action.Activated:Connect(function()
		remotes.ShopAction:FireServer("BuyCosmetic", id)
	end)
	shopRows[id] = { Action = action }
end

local defenseRows = {}
for index, id in ipairs(Catalog.DefenseOrder) do
	local definition = Catalog.Defenses[id]
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 98), Position = UDim2.new(0, 0, 0, (index - 1) * 106), BackgroundColor3 = C.Panel }, defenseFrame)
	corner(row)
	label(row, rich(definition.Name, Color3.fromRGB(255, 151, 82)), UDim2.new(0.58, 0, 0, 26), UDim2.new(0, 10, 0, 6), 18, Color3.fromRGB(255, 151, 82))
	local description = label(row, definition.Description, UDim2.new(0.58, 0, 0, 54), UDim2.new(0, 10, 0, 34), 13, C.Muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local action = button(row, "", UDim2.new(0.36, 0, 0, 70), UDim2.new(0.62, 0, 0, 14), Color3.fromRGB(211, 111, 57))
	action.Activated:Connect(function()
		remotes.ProgressionAction:FireServer("BuyDefense", id)
	end)
	defenseRows[id] = { Action = action }
end

local profile
local activePanel
local function refreshPanels()
	if profile then
		for id, row in pairs(upgradeRows) do
			local definition = Catalog.Upgrades[id]
			local level = profile.Upgrades and profile.Upgrades[id] or 0
			if level >= definition.MaxLevel then
				row.Action.Text = "MAX · " .. level .. "/" .. definition.MaxLevel
				row.Action.BackgroundColor3 = C.Panel
			else
				local cost = definition.Costs[level + 1]
				local required = definition.RequiredLevels[level + 1] or 1
				row.Action.Text = string.format("%d/%d · %d монет\nLv %d+", level, definition.MaxLevel, cost, required)
				row.Action.BackgroundColor3 = C.Green
			end
		end
		for id, row in pairs(shopRows) do
			local definition = Catalog.Cosmetics[id]
			local owned = profile.OwnedCosmetics and profile.OwnedCosmetics[id]
			local equipped = profile.SelectedCosmetics and profile.SelectedCosmetics[definition.Slot] == id
			if equipped then
				row.Action.Text = "ЭКИПИРОВАНО"
				row.Action.BackgroundColor3 = C.Green
			elseif owned then
				row.Action.Text = "ЭКИПИРОВАТЬ"
				row.Action.BackgroundColor3 = C.Cyan
			else
				local testPrefix = RunService:IsStudio() and Config.EnableStudioTestPurchases and "TEST · " or ""
				row.Action.Text = string.format("%s%d R$\nКУПИТЬ", testPrefix, definition.RobuxPrice)
				row.Action.BackgroundColor3 = C.Purple
			end
		end
		for id, row in pairs(defenseRows) do
			local definition = Catalog.Defenses[id]
			local owned = profile.OwnedDefenses and profile.OwnedDefenses[id]
			if owned then
				row.Action.Text = "ЧЕРТЁЖ КУПЛЕН"
				row.Action.BackgroundColor3 = C.Green
			else
				row.Action.Text = string.format("%d монет\nLv %d+", definition.Price, definition.RequiredLevel)
				row.Action.BackgroundColor3 = Color3.fromRGB(211, 111, 57)
			end
		end
		local currentLevel = Catalog.LevelForXP(profile.XP or 0)
		local nextLevel = Catalog.GetNextLevelReward(currentLevel)
		for rewardLevel, row in pairs(rewardRows) do
			local claimed = profile.ClaimedLevelRewards and (profile.ClaimedLevelRewards[tostring(rewardLevel)] or profile.ClaimedLevelRewards[rewardLevel])
			if claimed then
				row.Status.Text = "ПОЛУЧЕНО"
				row.Status.TextColor3 = C.Green
				row.Row.BackgroundColor3 = C.Panel
			elseif rewardLevel == nextLevel then
				row.Status.Text = "СЛЕДУЮЩАЯ"
				row.Status.TextColor3 = C.Gold
				row.Row.BackgroundColor3 = Color3.fromRGB(57, 66, 79)
			elseif rewardLevel <= currentLevel then
				row.Status.Text = "ОТКРЫТО"
				row.Status.TextColor3 = C.Green
			else
				row.Status.Text = "ЗАКРЫТО"
				row.Status.TextColor3 = C.Muted
				row.Row.BackgroundColor3 = C.Panel
			end
		end
		local elapsed = os.time() - (profile.LastDailyClaim or 0)
		if elapsed >= Config.DailyCooldown then
			dailyStatus.Text = highlight("БОНУС ГОТОВ · +" .. tostring(50 + (profile.XP and Catalog.LevelForXP(profile.XP) or 1) * 5) .. " монет")
			dailyClaim.Text = "ПОЛУЧИТЬ БОНУС"
			dailyClaim.BackgroundColor3 = C.Green
		else
			local seconds = Config.DailyCooldown - elapsed
			dailyStatus.Text = rich(string.format("Следующий бонус через %02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60), C.Cyan)
			dailyClaim.Text = "БОНУС УЖЕ ПОЛУЧЕН"
			dailyClaim.BackgroundColor3 = C.Panel
		end
	end
end

local function showPanel(name)
	activePanel = name
	panel.Visible = name ~= nil
	upgradeFrame.Visible = name == "Upgrades"
	dailyFrame.Visible = name == "Daily"
	shopFrame.Visible = name == "Shop"
	defenseFrame.Visible = name == "Defense"
	rewardsFrame.Visible = name == "Rewards"
	if name == "Rewards" then
		panelTitle.Text = rich("ПУТЬ НАГРАД // УРОВНИ 2–10", C.Gold)
		panelHint.Text = highlight("За каждый уровень — монеты. Золотая строка — ближайшая разблокировка.")
	elseif name == "Upgrades" then
		panelTitle.Text = rich("FORGE // УЛУЧШЕНИЯ ПЕРСОНАЖА", C.Cyan)
		panelHint.Text = highlight("Монеты и уровни открывают реальные бонусы. Улучшения доступны в лобби.")
	elseif name == "Daily" then
		panelTitle.Text = rich("DAILY // ЕЖЕДНЕВНАЯ НАГРАДА", C.Gold)
		panelHint.Text = highlight("Забирайте подарок у светящегося NPC или здесь.")
	elseif name == "Shop" then
		panelTitle.Text = rich("ROBUX // КОСМЕТИЧЕСКИЙ МАГАЗИН", C.Purple)
		panelHint.Text = highlight("Только внешний вид: никаких преимуществ в уроне, HP, скорости или matchmaking.")
	elseif name == "Defense" then
		panelTitle.Text = rich("DEFENSE // ЛОВУШКИ И МИНЫ", Color3.fromRGB(255, 151, 82))
		panelHint.Text = highlight("Чертежи покупаются за монеты. В бою выбирайте ловушку клавишами 4 / 5 / 6.")
	end
	refreshPanels()
	if name then
		remotes.ProgressionAction:FireServer("Refresh")
	end
end

rewardsButton.Activated:Connect(function() showPanel("Rewards") end)
upgradeButton.Activated:Connect(function() showPanel("Upgrades") end)
dailyButton.Activated:Connect(function() showPanel("Daily") end)
shopButton.Activated:Connect(function() showPanel("Shop") end)
defenseButton.Activated:Connect(function() showPanel("Defense") end)
closeButton.Activated:Connect(function() showPanel(nil) end)
remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Rewards" or name == "Upgrades" or name == "Daily" or name == "Shop" or name == "Defense" then
		showPanel(name)
	end
end)
remotes.ProfileUpdate.OnClientEvent:Connect(function(data)
	profile = data
	refreshPanels()
end)

local function refreshStats()
	local xp = player:GetAttribute("XP") or (profile and profile.XP) or 0
	local level, currentXP, requiredXP = Catalog.LevelProgress(xp)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.ceil(humanoid.Health) or 0
	local maximum = humanoid and math.ceil(humanoid.MaxHealth) or 120
	local armor = (character and character:GetAttribute("Armor")) or (player:GetAttribute("Upgrade_Armor") or 0) * 0.04
	local speed = humanoid and humanoid.WalkSpeed or (20 + (player:GetAttribute("Upgrade_Speed") or 0))
	local phase = state:GetAttribute("Phase") or "Lobby"
	local builds = phase == "Lobby" and (player:GetAttribute("BuildCapacity") or Config.Arena.MaxBuildPerPlayer) or (player:GetAttribute("BuildRemaining") or 0)
	local camera = Workspace.CurrentCamera
	local screenWidth = camera and camera.ViewportSize.X or 1280
	local sideWidth = math.clamp((screenWidth - 200) / 2, 100, 340)
	statsPanel.Size = UDim2.new(0, math.min(330, sideWidth), 0, 148)
	guidePanel.Size = UDim2.new(0, math.min(330, sideWidth), 0, 148)
	lobbyDock.Size = UDim2.new(0, math.min(300, sideWidth), 0, 249)
	levelLabel.Text = rich("УРОВЕНЬ " .. tostring(level), C.Gold)
	xpLabel.Text = string.format('<font color="#74DEFF"><b>%d / %d XP</b></font>', currentXP, requiredXP)
	xpFill.Size = UDim2.fromScale(math.clamp(currentXP / math.max(1, requiredXP), 0, 1), 1)
	statsLabel.Text = string.format('<font color="#FF8E83"><b>HP %d/%d</b></font> · <font color="#C6A0FF">БРОНЯ %d%%</font>', health, maximum, math.floor(armor * 100 + 0.5))
	speedLabel.Text = string.format('<font color="#74DEFF">СКОРОСТЬ <b>%d</b></font> · <font color="#FFD166">ПОСТРОЙКИ <b>%d</b></font>', math.floor(speed + 0.5), builds)
	coinsLabel.Text = string.format('<font color="#FFD166"><b>МОНЕТЫ %d</b></font> · <font color="#74DEFF"><b>ЖЕТОНЫ %d</b></font>', player:GetAttribute("Coins") or 0, player:GetAttribute("CaseTokens") or 0)
	local nextLevel, nextReward = Catalog.GetNextLevelReward(level)
	if nextReward then
		nextRewardLabel.Text = string.format('<font color="#C6A0FF"><b>СЛЕДУЮЩАЯ · LV %d</b></font><font color="#FFD166">: %s</font>', nextLevel, escapeRich(nextReward.Description))
	else
		nextRewardLabel.Text = highlight("Особые награды открыты · дальше монеты за каждый уровень")
	end
	if player:GetAttribute("Queued") then
		guideTitle.Text = "МЕСТО ЗАБРОНИРОВАНО"
		guideText.Text = "Команда собирается. Далее: 75 секунд на 3 укрепления, затем штурм вражеского ядра."
	elseif (player:GetAttribute("Matches") or 0) > 0 and (player:GetAttribute("CaseTokens") or 0) > 0 then
		guideTitle.Text = "НАГРАДА ЖДЁТ · ОТКРОЙ КЕЙС [L]"
		guideText.Text = "Потрать жетон в лутбоксе, экипируй предмет в инвентаре — и возвращайся в бой за следующим уровнем."
	else
		guideTitle.Text = "ТВОЙ СЛЕДУЮЩИЙ ШАГ"
		guideText.Text = "Нажми БЫСТРЫЙ СТАРТ — пустые места в двух командах 6×6 займут боты."
	end
	guideTitle.Text = rich(guideTitle.Text, C.Green)
	guideText.Text = highlight(guideText.Text)
	statsPanel.Visible = phase == "Lobby"
	guidePanel.Visible = phase == "Lobby"
	lobbyDock.Visible = phase == "Lobby"
	if phase ~= "Lobby" and panel.Visible then
		showPanel(nil)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.J then
		if activePanel == "Rewards" then showPanel(nil) else showPanel("Rewards") end
	elseif input.KeyCode == Enum.KeyCode.U then
		if activePanel == "Upgrades" then showPanel(nil) else showPanel("Upgrades") end
	elseif input.KeyCode == Enum.KeyCode.K then
		if activePanel == "Shop" then showPanel(nil) else showPanel("Shop") end
	end
end)

RunService.RenderStepped:Connect(function()
	refreshStats()
end)
refreshStats()
