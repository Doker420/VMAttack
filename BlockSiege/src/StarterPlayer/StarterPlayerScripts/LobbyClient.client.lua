-- Lobby progression HUD and NPC panels: upgrades, daily rewards and cosmetic-only Robux shop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = {
	Background = Color3.fromRGB(27, 35, 39),
	Panel = Color3.fromRGB(46, 59, 61),
	Text = Color3.fromRGB(240, 241, 217),
	Muted = Color3.fromRGB(174, 187, 178),
	Gold = Color3.fromRGB(239, 179, 52),
	Green = Color3.fromRGB(102, 190, 130),
	Cyan = Color3.fromRGB(88, 220, 255),
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

local function label(parent, value, size, position, textSize, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.Code,
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
		Font = Enum.Font.Code,
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
	Position = UDim2.new(0, 16, 0, 122),
	Size = UDim2.new(0, 318, 0, 112),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.08,
}, gui)
corner(statsPanel)
new("UIStroke", { Color = Color3.fromRGB(91, 108, 101), Thickness = 1 }, statsPanel)
local levelLabel = label(statsPanel, "LEVEL 1", UDim2.new(0.46, 0, 0, 29), UDim2.new(0, 12, 0, 7), 22, C.Gold)
local xpLabel = label(statsPanel, "XP 0", UDim2.new(0.5, 0, 0, 24), UDim2.new(0.48, 0, 0, 10), 15, C.Muted)
local statsLabel = label(statsPanel, "HP 120/120 · ARMOR 0%", UDim2.new(1, -24, 0, 25), UDim2.new(0, 12, 0, 42), 16, C.Text)
local speedLabel = label(statsPanel, "SPEED 20 · BUILDS 14", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 68), 15, C.Cyan)
local coinsLabel = label(statsPanel, "COINS 0 · CASE TOKENS 0", UDim2.new(1, -24, 0, 22), UDim2.new(0, 12, 0, 91), 14, C.Gold)

local lobbyDock = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 122),
	Size = UDim2.new(0, 286, 0, 150),
	BackgroundTransparency = 1,
}, gui)
local upgradeButton = button(lobbyDock, "FORGE · УЛУЧШЕНИЯ  [U]", UDim2.new(1, 0, 0, 42), UDim2.new(), C.Cyan)
upgradeButton.TextColor3 = Color3.fromRGB(22, 37, 40)
local dailyButton = button(lobbyDock, "DAILY · ЕЖЕДНЕВНЫЙ БОНУС", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 49), C.Gold)
dailyButton.TextColor3 = Color3.fromRGB(35, 32, 22)
local shopButton = button(lobbyDock, "ROBUX · КОСМЕТИКА  [K]", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 98), C.Purple)

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
local shopFrame = new("Frame", { Size = UDim2.new(1, -32, 1, -100), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1, Visible = false }, panel)

local upgradeRows = {}
for index, id in ipairs(Catalog.UpgradeOrder) do
	local definition = Catalog.Upgrades[id]
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 76), Position = UDim2.new(0, 0, 0, (index - 1) * 83), BackgroundColor3 = C.Panel }, upgradeFrame)
	corner(row)
	label(row, definition.Name, UDim2.new(0.55, 0, 0, 24), UDim2.new(0, 10, 0, 6), 18, C.Cyan)
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
	label(row, definition.Name, UDim2.new(0.58, 0, 0, 26), UDim2.new(0, 10, 0, 6), 18, C.Purple)
	local description = label(row, definition.Description, UDim2.new(0.58, 0, 0, 54), UDim2.new(0, 10, 0, 34), 13, C.Muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local action = button(row, "", UDim2.new(0.36, 0, 0, 70), UDim2.new(0.62, 0, 0, 14), C.Purple)
	action.Activated:Connect(function()
		remotes.ShopAction:FireServer("BuyCosmetic", id)
	end)
	shopRows[id] = { Action = action }
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
		local elapsed = os.time() - (profile.LastDailyClaim or 0)
		if elapsed >= Config.DailyCooldown then
			dailyStatus.Text = "БОНУС ГОТОВ · +" .. tostring(50 + (profile.XP and Catalog.LevelForXP(profile.XP) or 1) * 5) .. " монет"
			dailyClaim.Text = "ПОЛУЧИТЬ БОНУС"
			dailyClaim.BackgroundColor3 = C.Green
		else
			local seconds = Config.DailyCooldown - elapsed
			dailyStatus.Text = string.format("Следующий бонус через %02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60)
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
	if name == "Upgrades" then
		panelTitle.Text = "FORGE // УЛУЧШЕНИЯ ПЕРСОНАЖА"
		panelHint.Text = "Монеты и уровни открывают реальные бонусы. Улучшения доступны в лобби."
	elseif name == "Daily" then
		panelTitle.Text = "DAILY // ЕЖЕДНЕВНАЯ НАГРАДА"
		panelHint.Text = "Забирайте подарок у светящегося NPC или здесь."
	elseif name == "Shop" then
		panelTitle.Text = "ROBUX // КОСМЕТИЧЕСКИЙ МАГАЗИН"
		panelHint.Text = "Только внешний вид: никаких преимуществ в уроне, HP, скорости или matchmaking."
	end
	refreshPanels()
	if name then
		remotes.ProgressionAction:FireServer("Refresh")
	end
end

upgradeButton.Activated:Connect(function() showPanel("Upgrades") end)
dailyButton.Activated:Connect(function() showPanel("Daily") end)
shopButton.Activated:Connect(function() showPanel("Shop") end)
closeButton.Activated:Connect(function() showPanel(nil) end)
remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Upgrades" or name == "Daily" or name == "Shop" then
		showPanel(name)
	end
end)
remotes.ProfileUpdate.OnClientEvent:Connect(function(data)
	profile = data
	refreshPanels()
end)

local function refreshStats()
	local level = player:GetAttribute("Level") or (profile and Catalog.LevelForXP(profile.XP)) or 1
	local xp = player:GetAttribute("XP") or (profile and profile.XP) or 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.ceil(humanoid.Health) or 0
	local maximum = humanoid and math.ceil(humanoid.MaxHealth) or 120
	local armor = (character and character:GetAttribute("Armor")) or (player:GetAttribute("Upgrade_Armor") or 0) * 0.04
	local speed = humanoid and humanoid.WalkSpeed or (20 + (player:GetAttribute("Upgrade_Speed") or 0))
	local phase = state:GetAttribute("Phase") or "Lobby"
	local builds = phase == "Lobby" and (player:GetAttribute("BuildCapacity") or Config.Arena.MaxBuildPerPlayer) or (player:GetAttribute("BuildRemaining") or 0)
	levelLabel.Text = "LEVEL " .. tostring(level)
	xpLabel.Text = "XP " .. tostring(xp)
	statsLabel.Text = string.format("HP %d/%d · ARMOR %d%%", health, maximum, math.floor(armor * 100 + 0.5))
	speedLabel.Text = string.format("SPEED %d · BUILDS %d", math.floor(speed + 0.5), builds)
	coinsLabel.Text = string.format("COINS %d · CASE TOKENS %d", player:GetAttribute("Coins") or 0, player:GetAttribute("CaseTokens") or 0)
	lobbyDock.Visible = phase == "Lobby"
	if phase ~= "Lobby" and panel.Visible then
		showPanel(nil)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.U then
		if activePanel == "Upgrades" then showPanel(nil) else showPanel("Upgrades") end
	elseif input.KeyCode == Enum.KeyCode.K then
		if activePanel == "Shop" then showPanel(nil) else showPanel("Shop") end
	end
end)

RunService.RenderStepped:Connect(function()
	refreshStats()
end)
refreshStats()
