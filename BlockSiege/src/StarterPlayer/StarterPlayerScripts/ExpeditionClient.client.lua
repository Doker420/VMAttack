-- BLOCKSIEGE // PvE expedition hub + server Level/Coins ratings.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local ExpeditionCatalog = require(Shared:WaitForChild("ExpeditionCatalog"))
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = { Background = Color3.fromRGB(12, 20, 34), Panel = Color3.fromRGB(29, 45, 66), Text = Color3.fromRGB(245, 250, 255), Muted = Color3.fromRGB(169, 192, 214), Green = Color3.fromRGB(103, 229, 183), Gold = Color3.fromRGB(255, 211, 107), Cyan = Color3.fromRGB(116, 222, 255), Purple = Color3.fromRGB(198, 160, 255), Red = Color3.fromRGB(255, 121, 116) }
local function new(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function corner(object, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
end
local function escape(value)
	local escaped = tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
	return escaped
end
local function label(parent, value, size, position, textSize, color)
	return new("TextLabel", { BackgroundTransparency = 1, RichText = true, Text = value, Size = size, Position = position or UDim2.new(), Font = Enum.Font.Gotham, TextWrapped = true, TextSize = textSize or 15, TextColor3 = color or C.Text }, parent)
end
local function button(parent, value, size, position, color)
	local object = new("TextButton", { BackgroundColor3 = color or C.Panel, Size = size, Position = position or UDim2.new(), Font = Enum.Font.GothamBold, RichText = true, Text = value, TextColor3 = C.Text, TextSize = 14, AutoButtonColor = true }, parent)
	corner(object, 7)
	new("UIStroke", { Color = C.Cyan, Thickness = 1, Transparency = 0.35 }, object)
	return object
end
local gui = new("ScreenGui", { Name = "BlockSiegeExpeditionUI", ResetOnSpawn = false, DisplayOrder = 9, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local hubButton = button(gui, "X · PVE / РЕЙТИНГ", UDim2.new(0, 300, 0, 34), UDim2.new(0.5, 0, 0, 118), Color3.fromRGB(40, 115, 105))
hubButton.AnchorPoint = Vector2.new(0.5, 0)
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.52, 0), Size = UDim2.new(0.92, 0, 0.8, 0), BackgroundColor3 = C.Background, Visible = false, Active = true }, gui)
new("UISizeConstraint", { MinSize = Vector2.new(320, 390), MaxSize = Vector2.new(640, 630) }, panel)
corner(panel, 12)
new("UIStroke", { Color = C.Green, Thickness = 1.6, Transparency = 0.1 }, panel)
local title = label(panel, '<font color="#67E5B7"><b>PVE // EXPEDITIONS</b></font>', UDim2.new(1, -130, 0, 36), UDim2.new(0, 16, 0, 9), 22, C.Text)
local closeButton = button(panel, "×", UDim2.new(0, 42, 0, 36), UDim2.new(1, -54, 0, 10), C.Panel)
local expeditionTab = button(panel, "ЭКСПЕДИЦИИ", UDim2.new(0, 148, 0, 30), UDim2.new(0, 16, 0, 51), C.Green)
local ratingTab = button(panel, "РЕЙТИНГИ", UDim2.new(0, 120, 0, 30), UDim2.new(0, 174, 0, 51), C.Panel)
local expeditionFrame = new("Frame", { Size = UDim2.new(1, -32, 1, -145), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1 }, panel)
local ratingFrame = new("Frame", { Size = UDim2.new(1, -32, 1, -145), Position = UDim2.new(0, 16, 0, 91), BackgroundTransparency = 1, Visible = false }, panel)
local locationList = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -105), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(0, 0, 0, #ExpeditionCatalog.Order * 101) }, expeditionFrame)
new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, locationList)
local rows = {}
for index, id in ipairs(ExpeditionCatalog.Order) do
	local definition = ExpeditionCatalog.Get(id)
	local row = new("Frame", { Size = UDim2.new(1, -8, 0, 94), BackgroundColor3 = C.Panel, LayoutOrder = index }, locationList)
	corner(row, 8)
	local name = label(row, escape(definition.Name), UDim2.new(0.58, 0, 0, 24), UDim2.new(0, 10, 0, 6), 17, definition.Color)
	name.Font = Enum.Font.GothamBold
	local description = label(row, escape(definition.Subtitle), UDim2.new(0.58, 0, 0, 30), UDim2.new(0, 10, 0, 31), 12, C.Muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local requirement = label(row, "", UDim2.new(0.58, 0, 0, 22), UDim2.new(0, 10, 0, 65), 11, C.Gold)
	local action = button(row, "", UDim2.new(0.32, 0, 0, 56), UDim2.new(0.65, 0, 0, 19), definition.Color)
	action.Activated:Connect(function()
		if state:GetAttribute("Phase") == "Battle" then
			remotes.ExpeditionAction:FireServer("Enter", id)
		else
			remotes.ExpeditionAction:FireServer("Select", id)
		end
	end)
	rows[id] = { Action = action, Requirement = requirement }
end
local trainButton = button(expeditionFrame, "ТРЕНИРОВКА ОТРЯДА", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 1, -96), C.Purple)
trainButton.Activated:Connect(function() remotes.ExpeditionAction:FireServer("Train") end)
local status = label(expeditionFrame, "", UDim2.new(0.68, 0, 0, 48), UDim2.new(0, 0, 1, -57), 13, C.Cyan)
status.TextXAlignment = Enum.TextXAlignment.Left
local exitButton = button(expeditionFrame, "ВЫЙТИ ИЗ РЕЙДА", UDim2.new(0.29, 0, 0, 38), UDim2.new(0.7, 0, 1, -52), C.Red)
exitButton.Visible = false
exitButton.Activated:Connect(function() remotes.ExpeditionAction:FireServer("Exit") end)

local levelBoard = new("ScrollingFrame", { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(0.49, 0, 1, -65), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 370) }, ratingFrame)
local coinBoard = new("ScrollingFrame", { Position = UDim2.new(0.51, 0, 0, 30), Size = UDim2.new(0.49, 0, 1, -65), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(0, 0, 0, 370) }, ratingFrame)
label(ratingFrame, '<font color="#74DEFF"><b>TOP LEVEL</b></font>', UDim2.new(0.49, 0, 0, 24), UDim2.new(), 16, C.Cyan)
label(ratingFrame, '<font color="#FFD36F"><b>TOP COINS</b></font>', UDim2.new(0.49, 0, 0, 24), UDim2.new(0.51, 0, 0, 0), 16, C.Gold)
local boardRows = { Level = {}, Coins = {} }
for boardName, board in pairs({ Level = levelBoard, Coins = coinBoard }) do
	for index = 1, 10 do
		local row = label(board, "", UDim2.new(1, -5, 0, 34), UDim2.new(0, 0, 0, (index - 1) * 37), 12, C.Text)
		row.TextXAlignment = Enum.TextXAlignment.Left
		boardRows[boardName][index] = row
	end
end
label(ratingFrame, "Online server snapshot · не глобальный OrderedDataStore", UDim2.new(1, 0, 0, 25), UDim2.new(0, 0, 1, -28), 11, C.Muted)

local activeTab = "Expeditions"
local currentSnapshot
local leaderboard = { Level = {}, Coins = {} }
local selectedId = player:GetAttribute("SelectedExpedition") or "VerdantBastion"
local function showPanel(tab)
	local phase = state:GetAttribute("Phase")
	if phase ~= "Lobby" and phase ~= "Battle" then return end
	activeTab = tab or activeTab
	panel.Visible = true
	expeditionFrame.Visible = activeTab == "Expeditions"
	ratingFrame.Visible = activeTab == "Ratings"
	expeditionTab.BackgroundColor3 = activeTab == "Expeditions" and C.Green or C.Panel
	ratingTab.BackgroundColor3 = activeTab == "Ratings" and C.Green or C.Panel
	title.Text = activeTab == "Ratings" and '<font color="#FFD36F"><b>LOBBY // RATINGS</b></font>' or '<font color="#67E5B7"><b>PVE // EXPEDITIONS</b></font>'
end
local function renderRatings()
	for _, boardName in ipairs({ "Level", "Coins" }) do
		for index = 1, 10 do
			local entry = leaderboard[boardName] and leaderboard[boardName][index]
			boardRows[boardName][index].Text = entry and string.format('<font color="#FFD36F"><b>#%d</b></font> %s\n<font color="#74DEFF">%s</font>', index, escape(entry.DisplayName or entry.Name), tostring(entry.Value)) or string.format('<font color="#6E829E">#%d · —</font>', index)
		end
	end
end
local function refresh()
	local phase = state:GetAttribute("Phase") or "Lobby"
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 1280
	local side = math.clamp((width - 200) / 2, 100, 340)
	local gap = math.max(40, width - 32 - side * 2)
	hubButton.Size = UDim2.new(0, math.clamp(gap - 24, 40, 330), 0, 34)
	hubButton.Text = gap < 180 and "X · PVE" or "X · PVE / РЕЙТИНГ"
	hubButton.TextSize = gap < 180 and 10 or 14
	hubButton.Visible = phase == "Lobby"
	trainButton.Visible = phase == "Lobby" and not (currentSnapshot and currentSnapshot.InExpedition)
	local squadLevel = player:GetAttribute("SquadLevel") or 1
	trainButton.Text = squadLevel >= 10 and "ОТРЯД · MAX LEVEL" or string.format("ТРЕНИРОВКА +100 XP · %d МОНЕТ", 100 + squadLevel * 50)
	trainButton.Active = squadLevel < 10
	if phase ~= "Lobby" and phase ~= "Battle" then panel.Visible = false end
	local level = player:GetAttribute("Level") or 1
	local wins = player:GetAttribute("Wins") or 0
	for id, row in pairs(rows) do
		local definition = ExpeditionCatalog.Get(id)
		local unlocked = ExpeditionCatalog.IsUnlocked(id, level, wins)
		row.Requirement.Text = unlocked and string.format('<font color="#72E6B1">LV %d · WINS %d · 3 WAVES + BOSS</font>', definition.RequiredLevel, definition.RequiredWins) or string.format('<font color="#FF8C83">LOCKED · LV %d · WINS %d</font>', definition.RequiredLevel, definition.RequiredWins)
		row.Action.Active = unlocked
		row.Action.AutoButtonColor = unlocked
		row.Action.BackgroundColor3 = unlocked and definition.Color or C.Panel
		row.Action.Text = not unlocked and "LOCKED" or (phase == "Battle" and "ВОЙТИ" or (selectedId == id and "ВЫБРАНО" or "ВЫБРАТЬ"))
	end
	if currentSnapshot and currentSnapshot.InExpedition then
		status.Text = string.format('<font color="#74DEFF"><b>%s</b></font> · WAVE %d/%d · ENEMIES %d · PLAYERS %d', escape(currentSnapshot.LocationId), currentSnapshot.Wave or 0, currentSnapshot.MaxWaves or 3, currentSnapshot.Enemies or 0, currentSnapshot.Players or 0)
		exitButton.Visible = true
	else
		status.Text = string.format('<font color="#A9C0D6">Выбрано: %s · Squad LV %d · Best wave %d</font>', escape(selectedId), player:GetAttribute("SquadLevel") or 1, player:GetAttribute("ExpeditionBestWave") or 0)
		exitButton.Visible = false
	end
end

hubButton.Activated:Connect(function() showPanel("Expeditions") end)
closeButton.Activated:Connect(function() panel.Visible = false end)
expeditionTab.Activated:Connect(function() showPanel("Expeditions") end)
ratingTab.Activated:Connect(function() showPanel("Ratings") end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.X then
		if panel.Visible then panel.Visible = false else showPanel("Expeditions") end
	elseif input.KeyCode == Enum.KeyCode.Y then
		showPanel("Ratings")
	end
end)
remotes.OpenPanel.OnClientEvent:Connect(function(name)
	if name == "Expeditions" then showPanel("Expeditions") elseif name == "Ratings" then showPanel("Ratings") end
end)
remotes.ExpeditionFX.OnClientEvent:Connect(function(payload)
	if payload.Type == "Snapshot" then
		local wasIn = currentSnapshot and currentSnapshot.InExpedition
		currentSnapshot = payload.InExpedition and payload or nil
		if payload.LocationId then selectedId = payload.LocationId end
		if payload.InExpedition and not wasIn then showPanel("Expeditions") end
		refresh()
	end
end)
remotes.LeaderboardUpdate.OnClientEvent:Connect(function(payload)
	leaderboard = payload
	renderRatings()
end)
state:GetAttributeChangedSignal("Phase"):Connect(refresh)
local refreshClock = 0
RunService.RenderStepped:Connect(function(deltaTime)
	refreshClock = refreshClock + deltaTime
	if refreshClock >= 0.2 then
		refreshClock = 0
		refresh()
	end
end)
renderRatings()
refresh()
