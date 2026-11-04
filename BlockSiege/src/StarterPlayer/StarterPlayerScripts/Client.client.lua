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
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = {
	Background = Color3.fromRGB(30, 39, 39),
	Panel = Color3.fromRGB(45, 57, 55),
	Text = Color3.fromRGB(240, 241, 217),
	Muted = Color3.fromRGB(174, 187, 178),
	Blue = Color3.fromRGB(45, 157, 203),
	Orange = Color3.fromRGB(235, 139, 44),
	Gold = Color3.fromRGB(239, 179, 52),
	Green = Color3.fromRGB(102, 190, 130),
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
	new("UIStroke", { Color = Color3.fromRGB(91, 108, 101), Thickness = 1 }, object)
end

local function text(parent, value, size, position, textSize, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.Code,
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
		Font = Enum.Font.Code,
		Text = value,
		TextColor3 = C.Text,
		TextSize = 17,
		AutoButtonColor = true,
	}, parent)
	corner(object)
	new("UIStroke", { Color = Color3.fromRGB(91, 108, 101), Thickness = 1 }, object)
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
gradient(top, Color3.fromRGB(43, 57, 54), Color3.fromRGB(25, 34, 34))
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
		BackgroundColor3 = Color3.fromRGB(20, 27, 27),
	}, coreFrame)
	corner(back, 3)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C[team] }, back)
	corner(fill, 3)
	coreFills[team] = fill
end

local lobbyDock = new("Frame", { Position = UDim2.new(0, 16, 1, -166), Size = UDim2.new(0, 260, 0, 150), BackgroundTransparency = 1 }, gui)
local queueButton = button(lobbyDock, "В ОЧЕРЕДЬ 6×6", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 0), C.Blue)
local quickButton = button(lobbyDock, "БЫСТРЫЙ СТАРТ + БОТЫ", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 49), C.Orange)
local caseButton = button(lobbyDock, "ЛУТБОКС / ОРУЖИЕ  [L]", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 0, 98), C.Panel)
local lobbyHint = text(gui, "6×6 · драфт команд по уровню · боты заполняют пустые слоты", UDim2.new(0, 480, 0, 52), UDim2.new(0, 290, 1, -112), 17, C.Muted)

local buildDock = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0, 530, 0, 122), BackgroundColor3 = C.Background,
}, gui)
corner(buildDock, 7)
local buildTitle = text(buildDock, "СТРОИТЕЛЬСТВО · зелёный = можно · красный = нельзя", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 5), 16, C.Gold)
local buildButtons = {}
for index, entry in ipairs({ { "Wall", "1 СТЕНА" }, { "Barricade", "2 БАРРИКАДА" }, { "Tower", "3 БАШНЯ" } }) do
	local buildButton = button(buildDock, entry[2], UDim2.new(0.31, 0, 0, 38), UDim2.new((index - 1) * 0.345 + 0.015, 0, 0, 38), C.Panel)
	buildButtons[entry[1]] = buildButton
end
local buildRemaining = text(buildDock, "", UDim2.new(0.45, 0, 0, 30), UDim2.new(0.02, 0, 0, 84), 16, C.Muted)
local rotateButton = button(buildDock, "R ⟳ 0°", UDim2.new(0.15, 0, 0, 34), UDim2.new(0.49, 0, 0, 82), C.Panel)
local placeButton = button(buildDock, "ПОСТАВИТЬ", UDim2.new(0.32, 0, 0, 34), UDim2.new(0.66, 0, 0, 82), C.Green)
local trapDock = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -144), Size = UDim2.new(0, 530, 0, 44), BackgroundTransparency = 1,
}, gui)
for index, id in ipairs(Catalog.DefenseOrder) do
	local definition = Catalog.Defenses[id]
	local trapButton = button(trapDock, tostring(index + 3) .. " " .. definition.Name, UDim2.new(0.31, 0, 0, 40), UDim2.new((index - 1) * 0.345 + 0.015, 0, 0, 0), Color3.fromRGB(126, 70, 48))
	buildButtons[id] = trapButton
end

local captureFrame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.new(0, 350, 0, 62), BackgroundColor3 = C.Background,
}, gui)
corner(captureFrame)
local captureTitle = text(captureFrame, "67 // ЗАХВАТ", UDim2.new(1, -16, 0, 27), UDim2.new(0, 8, 0, 4), 17, C.Gold)
local captureTrack = new("Frame", { Position = UDim2.new(0, 10, 0, 36), Size = UDim2.new(1, -20, 0, 14), BackgroundColor3 = Color3.fromRGB(47, 57, 57), BorderSizePixel = 0 }, captureFrame)
corner(captureTrack, 4)
local captureFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, BorderSizePixel = 0 }, captureTrack)
corner(captureFill, 4)

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
gradient(casePanel, Color3.fromRGB(48, 62, 58), Color3.fromRGB(25, 34, 34))
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
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 520, 0, 220),
	BackgroundColor3 = C.Background, Visible = false,
}, gui)
corner(resultsPanel, 8)
gradient(resultsPanel, Color3.fromRGB(54, 65, 56), Color3.fromRGB(28, 35, 35))
local resultTitle = text(resultsPanel, "МАТЧ ЗАВЕРШЁН", UDim2.new(1, -20, 0, 48), UDim2.new(0, 10, 0, 18), 28, C.Gold)
local resultReason = text(resultsPanel, "", UDim2.new(1, -30, 0, 60), UDim2.new(0, 15, 0, 76), 20)
local resultReward = text(resultsPanel, "", UDim2.new(1, -30, 0, 46), UDim2.new(0, 15, 0, 143), 18, C.Green)

local profile
local selectedBuild = "Wall"
local buildRotation = 0
local buildGhost
local buildGhostOutline
local ghostKind
local ghostHasServerPreview = false
local nextPreviewRequest = 0
local lastResult
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

local function clearBuildGhost()
	if buildGhost then
		buildGhost:Destroy()
	end
	buildGhost = nil
	buildGhostOutline = nil
	ghostKind = nil
	ghostHasServerPreview = false
	placeButton.BackgroundColor3 = C.Green
	buildTitle.Text = "СТРОИТЕЛЬСТВО · зелёный = можно · красный = нельзя"
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
end

local function updateResults()
	local winner = state:GetAttribute("Winner") or ""
	resultTitle.Text = winner == "" and "НИЧЬЯ" or ((C[winner] and (winner == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ") or winner) .. " ПОБЕДИЛИ")
	resultTitle.TextColor3 = C[winner] or C.Gold
	resultReason.Text = state:GetAttribute("Reason") or ""
	if lastResult and lastResult.Reward then
		local reward = lastResult.Reward
		local levelBonus = reward.LeveledUp and string.format(" · LEVEL %d! +%d монет", reward.Level, reward.LevelCoins or 0) or ""
		resultReward.Text = string.format("Награда: +%d монет · +%d XP%s%s", reward.Coins, reward.XP, reward.Token and " · +1 жетон" or "", levelBonus)
	else
		resultReward.Text = "Наблюдение за матчем"
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
	coreFrame.Visible = phase ~= "Lobby"
	queueButton.Text = player:GetAttribute("Queued") and "ВЫЙТИ ИЗ ОЧЕРЕДИ" or "В ОЧЕРЕДЬ 6×6"
	local team = player:GetAttribute("Team") or ""
	teamLabel.Text = team ~= "" and ((team == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ") .. " · Lv " .. tostring(player:GetAttribute("MatchLevel") or 1)) or "НАБЛЮДЕНИЕ"
	teamLabel.TextColor3 = C[team] or C.Muted
	buildRemaining.Text = "Осталось построек: " .. tostring(player:GetAttribute("BuildRemaining") or 0)
	local equippedWeapon = Catalog.GetWeapon(player:GetAttribute("SelectedWeapon") or "Carbine") or Catalog.Weapons.Carbine
	local weaponSkin = player:GetAttribute("Cosmetic_WeaponSkin")
	weaponLabel.Text = "ОРУЖИЕ: " .. equippedWeapon.Name .. (weaponSkin and weaponSkin ~= "Default" and " · GOLD" or "")
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
	captureTitle.Text = phase == "Build" and "67 // ЗАХВАТ ОТКРОЕТСЯ В БОЮ" or ("67 // " .. ownerText .. (captureContested and " · ОСПАРИВАЕТСЯ" or ""))
	captureTitle.TextColor3 = captureContested and C.Orange or (C[captureOwner] or C.Gold)
	captureFill.BackgroundColor3 = C[captureOwner] or C.Gold
	captureFill.Size = UDim2.fromScale(math.clamp(captureProgress / 100, 0, 1), 1)
	if phase == "Results" then
		updateResults()
	end
end

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
	if not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		return mouse.Hit.Position
	end
	local camera = Workspace.CurrentCamera
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 48, params)
	return hit and hit.Position or camera.CFrame.Position + camera.CFrame.LookVector * 32
end

local function rotateBuild()
	buildRotation = (buildRotation + 90) % 360
	rotateButton.Text = "R ⟳ " .. tostring(buildRotation) .. "°"
	ghostHasServerPreview = false
end
rotateButton.Activated:Connect(rotateBuild)

local function requestBuild()
	if state:GetAttribute("Phase") == "Build" then
		remotes.BuildRequest:FireServer(selectedBuild, buildPosition(), buildRotation)
	end
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
		rotateBuild()
	elseif input.KeyCode == Enum.KeyCode.B then
		requestBuild()
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
				if not ghostHasServerPreview then
					buildGhost.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(buildRotation), 0)
				end
				local now = os.clock()
				if now >= nextPreviewRequest then
					nextPreviewRequest = now + 0.14
					ghostHasServerPreview = false
					remotes.BuildPreviewRequest:FireServer(selectedBuild, position, buildRotation)
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
	elseif payload.Kind == "Shot" then
		local distance = (payload.Finish - payload.Origin).Magnitude
		if distance > 0.1 then
			local width = payload.WeaponId == "Rail" and 0.3 or 0.12
			local beam = new("Part", {
				Size = Vector3.new(width, width, distance), CFrame = CFrame.lookAt(payload.Origin:Lerp(payload.Finish, 0.5), payload.Finish),
				Color = payload.Color, Material = Enum.Material.Neon, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 0.08,
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
		notify("67 ЗАХВАЧЕНА · " .. (payload.Team == "Blue" and "СИНИЕ" or "ОРАНЖЕВЫЕ"))
	end
end)
remotes.BuildPreview.OnClientEvent:Connect(function(payload)
	if payload.Kind ~= selectedBuild or (payload.Rotation or 0) ~= buildRotation or state:GetAttribute("Phase") ~= "Build" then
		return
	end
	ensureBuildGhost(payload.Kind)
	if not buildGhost then
		return
	end
	ghostHasServerPreview = true
	local color = payload.Valid and Color3.fromRGB(65, 255, 130) or Color3.fromRGB(255, 65, 65)
	buildGhost.Color = color
	buildGhost.Transparency = payload.Valid and 0.42 or 0.28
	buildGhost:SetAttribute("ServerValid", payload.Valid == true)
	if buildGhostOutline then
		buildGhostOutline.Color3 = color
	end
	if payload.CFrame then
		buildGhost.CFrame = payload.CFrame
	elseif payload.Position then
		buildGhost.CFrame = CFrame.new(payload.Position) * CFrame.Angles(0, math.rad(payload.Rotation or buildRotation), 0)
	end
	placeButton.BackgroundColor3 = payload.Valid and C.Green or Color3.fromRGB(170, 65, 65)
	buildTitle.Text = payload.Valid and "РАЗРЕШЕНО СЕРВЕРОМ · клик, чтобы поставить" or ("НЕЛЬЗЯ: " .. tostring(payload.Reason))
	buildTitle.TextColor3 = color
end)
remotes.Notify.OnClientEvent:Connect(notify)
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
