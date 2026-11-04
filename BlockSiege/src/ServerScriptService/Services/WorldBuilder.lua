-- Симметричная voxel-арена и свободное лобби с витриной оружия и лутбоксом.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))

local WorldBuilder = {}
local C = {
	Grass = Color3.fromRGB(91, 145, 73),
	Dirt = Color3.fromRGB(114, 79, 48),
	Stone = Color3.fromRGB(107, 118, 112),
	StoneDark = Color3.fromRGB(63, 73, 70),
	Wood = Color3.fromRGB(159, 111, 57),
	Leaf = Color3.fromRGB(63, 119, 61),
	Sand = Color3.fromRGB(190, 170, 111),
	White = Color3.fromRGB(239, 240, 215),
	Gold = Color3.fromRGB(239, 179, 52),
}

local function makePart(parent, name, size, cframe, color, material, collide, className)
	local part = Instance.new(className or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collide ~= false
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function billboard(parent, text, color, offset, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Size = UDim2.fromOffset(260, 58)
	gui.StudsOffset = offset or Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = size or UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Parent = gui
	return gui
end

local function prompt(parent, action, object)
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = action
	proximity.ObjectText = object
	proximity.HoldDuration = 0.25
	proximity.MaxActivationDistance = 14
	proximity.RequiresLineOfSight = false
	proximity.Parent = parent
	return proximity
end

local function buildTree(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "VoxelTree"
	model.Parent = parent
	makePart(model, "Trunk", Vector3.new(2.4, 9, 2.4) * scale, CFrame.new(position + Vector3.new(0, 4.5 * scale, 0)), C.Wood, Enum.Material.WoodPlanks, true)
	for _, offset in ipairs({ Vector3.new(0, 10, 0), Vector3.new(2.5, 8.5, 0), Vector3.new(-2.5, 8.5, 0), Vector3.new(0, 8.5, 2.5), Vector3.new(0, 8.5, -2.5) }) do
		makePart(model, "Leaves", Vector3.new(5, 5, 5) * scale, CFrame.new(position + offset * scale), C.Leaf, Enum.Material.Grass, true)
	end
	return model
end

local function buildCloud(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "BlockCloud"
	model.Parent = parent
	for _, entry in ipairs({
		{ Vector3.new(0, 0, 0), Vector3.new(12, 4, 7) },
		{ Vector3.new(-7, -1, 1), Vector3.new(7, 3, 6) },
		{ Vector3.new(7, -0.5, -1), Vector3.new(8, 3.5, 6) },
		{ Vector3.new(1, 2, 0), Vector3.new(7, 3, 5) },
	}) do
		local cloud = makePart(model, "CloudBlock", entry[2] * scale, CFrame.new(position + entry[1] * scale), C.White, Enum.Material.SmoothPlastic, false)
		cloud.CanQuery = false
	end
	return model
end

local function buildBase(arena, structures, team)
	local color = Config.Teams[team].Color
	local base = Config.BasePosition(team)
	local baseCFrame = Config.BaseCFrame(team)
	local platform = makePart(arena, team .. "BasePlatform", Vector3.new(100, 4, 116), CFrame.new(base.X, 2, 0), C.Stone, Enum.Material.Cobblestone, true)
	platform:SetAttribute("Team", team)
	makePart(arena, team .. "BaseGrass", Vector3.new(94, 0.5, 110), CFrame.new(base.X, 4.15, 0), C.Grass, Enum.Material.Grass, true)
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -42, 42 }) do
			local towerCFrame = baseCFrame * CFrame.new(side * 44, 5, forward)
			makePart(arena, team .. "CornerTower", Vector3.new(8, 10, 8), towerCFrame, C.StoneDark, Enum.Material.Cobblestone, true)
			makePart(arena, team .. "CornerTrim", Vector3.new(8.6, 1, 8.6), towerCFrame * CFrame.new(0, -2.5, 0), C.Stone, Enum.Material.Cobblestone, true)
			makePart(arena, team .. "CornerBanner", Vector3.new(8.5, 1.2, 8.5), towerCFrame * CFrame.new(0, 5.5, 0), color, Enum.Material.Fabric, true)
			for _, x in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					makePart(arena, team .. "CornerBattlement", Vector3.new(2, 1.5, 2), towerCFrame * CFrame.new(x * 3.1, 6.8, z * 3.1), C.StoneDark, Enum.Material.Cobblestone, true)
				end
			end
			makePart(arena, team .. "FlagPole", Vector3.new(0.45, 10, 0.45), towerCFrame * CFrame.new(0, 12, 0), C.Wood, Enum.Material.WoodPlanks, false)
			local flag = makePart(arena, team .. "TeamFlag", Vector3.new(4.5, 3, 0.5), towerCFrame * CFrame.new(2.3, 15, 0), color, Enum.Material.Fabric, false)
			flag.CanQuery = false
		end
	end
	local marker = makePart(arena, team .. "BaseMarker", Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(0, 25, 0)), color, Enum.Material.SmoothPlastic, false)
	marker.Transparency = 1
	marker.CanQuery = false
	billboard(marker, Config.Teams[team].Name .. " // КРЕПОСТЬ", color, Vector3.zero, UDim2.fromScale(1, 1))
	local spawnCFrame = baseCFrame * CFrame.new(0, 4, 34)
	local spawn = makePart(arena, team .. "Spawn", Vector3.new(12, 1, 12), spawnCFrame, color, Enum.Material.Neon, false, "SpawnLocation")
	spawn.Neutral = true
	spawn.CanQuery = false
	-- Tags let the local visibility controller hide only the opposing base during Build.
	for _, part in ipairs(arena:GetChildren()) do
		if part:IsA("BasePart") and string.sub(part.Name, 1, #team) == team then
			part:SetAttribute("Team", team)
			part:SetAttribute("BaseGeometry", true)
		end
	end
	return spawnCFrame + Vector3.new(0, 3, 0)
end

local function buildNpc(parent, name, position, color, title, action, description)
	local model = Instance.new("Model")
	model.Name = "NPC_" .. name
	model.Parent = parent
	local root = makePart(model, "Root", Vector3.new(3.2, 4.5, 2.2), CFrame.new(position + Vector3.new(0, 2.5, 0)), color, Enum.Material.SmoothPlastic, true)
	model.PrimaryPart = root
	makePart(model, "Head", Vector3.new(2.5, 2.2, 2.5), CFrame.new(position + Vector3.new(0, 6, 0)), Color3.fromRGB(224, 190, 145), Enum.Material.SmoothPlastic, true)
	makePart(model, "Hat", Vector3.new(3, 0.65, 3), CFrame.new(position + Vector3.new(0, 7.35, 0)), C.StoneDark, Enum.Material.Fabric, true)
	for _, side in ipairs({ -1, 1 }) do
		makePart(model, "Arm", Vector3.new(0.85, 3.2, 1), CFrame.new(position + Vector3.new(side * 2.1, 2.6, 0)), color, Enum.Material.SmoothPlastic, true)
		makePart(model, "Leg", Vector3.new(1.1, 2.2, 1.2), CFrame.new(position + Vector3.new(side * 0.75, -0.9, 0)), C.StoneDark, Enum.Material.SmoothPlastic, true)
	end
	local ring = makePart(model, "NeonRing", Vector3.new(6, 0.25, 6), CFrame.new(position + Vector3.new(0, 0.15, 0)), color, Enum.Material.Neon, false)
	ring.CanQuery = false
	local light = Instance.new("PointLight")
	light.Name = "NPCGlow"
	light.Color = color
	light.Brightness = 1.6
	light.Range = 16
	light.Parent = root
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "NPCSparkles"
	sparkles.SparkleColor = color
	sparkles.Parent = root
	billboard(root, title .. "\n" .. description, color, Vector3.new(0, 5.5, 0), UDim2.fromScale(1, 1))
	return prompt(root, action, description)
end

local function buildLobby(lobby)
	makePart(lobby, "LobbyStone", Vector3.new(170, 8, 130), CFrame.new(0, 36, 330), C.StoneDark, Enum.Material.Cobblestone, true)
	makePart(lobby, "LobbyDirt", Vector3.new(166, 5, 126), CFrame.new(0, 41, 330), C.Dirt, Enum.Material.Ground, true)
	makePart(lobby, "LobbyGrass", Vector3.new(164, 1, 124), CFrame.new(0, 44, 330), C.Grass, Enum.Material.Grass, true)
	local spawnCFrame = CFrame.lookAt(Vector3.new(0, 48, 365), Vector3.new(0, 48, 330))
	local spawn = makePart(lobby, "LobbySpawn", Vector3.new(12, 1, 12), spawnCFrame, C.White, Enum.Material.Neon, false, "SpawnLocation")
	spawn.Neutral = true
	spawn.CanQuery = false

	-- Decorative rails plus continuous glass safety walls: the lobby cannot be fallen off.
	for _, side in ipairs({ -1, 1 }) do
		makePart(lobby, "LobbySafetyWall", Vector3.new(1.5, 18, 126), CFrame.new(side * 82, 53, 330), Color3.fromRGB(110, 170, 175), Enum.Material.Glass, true).Transparency = 0.72
		makePart(lobby, "LobbyFenceRail", Vector3.new(1.2, 1, 126), CFrame.new(side * 81.5, 48, 330), C.Gold, Enum.Material.Metal, true)
		for index = 0, 8 do
			makePart(lobby, "LobbyFencePost", Vector3.new(2, 7, 2), CFrame.new(side * 81.5, 47.5, 268 + index * 15.5), C.StoneDark, Enum.Material.Cobblestone, true)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		makePart(lobby, "LobbySafetyWall", Vector3.new(166, 18, 1.5), CFrame.new(0, 53, 330 + side * 62), Color3.fromRGB(110, 170, 175), Enum.Material.Glass, true).Transparency = 0.72
		makePart(lobby, "LobbyFenceRail", Vector3.new(166, 1, 1.2), CFrame.new(0, 48, 330 + side * 61.5), C.Gold, Enum.Material.Metal, true)
		for index = 0, 10 do
			makePart(lobby, "LobbyFencePost", Vector3.new(2, 7, 2), CFrame.new(-77 + index * 15.5, 47.5, 330 + side * 61.5), C.StoneDark, Enum.Material.Cobblestone, true)
		end
	end

	local crate = makePart(lobby, "LobbyLootbox", Vector3.new(9, 7, 9), CFrame.new(0, 48, 318), C.Gold, Enum.Material.Metal, true)
	local crateLight = Instance.new("PointLight")
	crateLight.Color = C.Gold
	crateLight.Brightness = 1.2
	crateLight.Range = 18
	crateLight.Parent = crate
	makePart(lobby, "LootboxBand", Vector3.new(9.5, 1.2, 9.5), CFrame.new(0, 49, 318), C.StoneDark, Enum.Material.Metal, true)
	billboard(crate, "GEAR // ЛУТБОКС", C.Gold)
	local lootPrompt = prompt(crate, "ОТКРЫТЬ", "Игровые кейсы · шансы 65 / 30 / 5")

	local board = makePart(lobby, "StartBoard", Vector3.new(18, 12, 1.5), CFrame.new(-30, 51, 318), C.StoneDark, Enum.Material.WoodPlanks, true)
	billboard(board, "BLOCK // БОЙ 6×6", C.White, Vector3.new(0, 0, 0))
	local startPrompt = prompt(board, "В БОЙ", "Быстрый старт · боты заполняют команды")

	local displayColumns = math.max(1, math.ceil(#Catalog.WeaponOrder / 2))
	for index, weaponId in ipairs(Catalog.WeaponOrder) do
		local row = math.floor((index - 1) / displayColumns)
		local column = (index - 1) % displayColumns
		local x = (column - (displayColumns - 1) / 2) * 24
		local z = 292 - row * 16
		makePart(lobby, "WeaponPedestal", Vector3.new(10, 3, 10), CFrame.new(x, 46, z), C.Stone, Enum.Material.Cobblestone, true)
		local weapon = WeaponModels.Build(weaponId)
		weapon.Name = "Display_" .. weaponId
		weapon.Parent = lobby
		weapon:PivotTo(CFrame.new(x, 50, z) * CFrame.Angles(0, math.rad(90), 0))
		for _, item in ipairs(weapon:GetDescendants()) do
			if item:IsA("BasePart") then
				item.Anchored = true
			end
		end
		local labelAnchor = makePart(lobby, "WeaponLabelAnchor", Vector3.new(1, 1, 1), CFrame.new(x, 52, z), C.White, Enum.Material.SmoothPlastic, false)
		labelAnchor.Transparency = 1
		labelAnchor.CanQuery = false
		local definition = Catalog.GetWeapon(weaponId)
		billboard(labelAnchor, definition.Name, Catalog.RarityColors[definition.Rarity], Vector3.zero)
	end

	local upgradePrompt = buildNpc(lobby, "UpgradeForge", Vector3.new(-48, 44.5, 344), Color3.fromRGB(88, 220, 255), "FORGE // УЛУЧШЕНИЯ", "УЛУЧШИТЬ", "HP · броня · скорость · постройки")
	local dailyPrompt = buildNpc(lobby, "DailyBonus", Vector3.new(48, 44.5, 344), Color3.fromRGB(255, 211, 78), "DAILY // БОНУС", "ПОЛУЧИТЬ", "Монеты · XP · жетон кейса")
	local shopPrompt = buildNpc(lobby, "CosmeticShop", Vector3.new(48, 44.5, 300), Color3.fromRGB(195, 117, 255), "ROBUX // КОСМЕТИКА", "МАГАЗИН", "Только внешний вид · без pay-to-win")
	local defensePrompt = buildNpc(lobby, "DefenseWorkshop", Vector3.new(-48, 44.5, 300), Color3.fromRGB(255, 133, 71), "DEFENSE // ЛОВУШКИ", "КУПИТЬ ЧЕРТЁЖ", "Шипы · мины · огнемёт за монеты")
	local upgradePad = makePart(lobby, "UpgradePad", Vector3.new(16, 0.35, 12), CFrame.new(-48, 44.8, 344), Color3.fromRGB(40, 120, 145), Enum.Material.Metal, false)
	upgradePad.CanQuery = false
	local dailyPad = makePart(lobby, "DailyPad", Vector3.new(16, 0.35, 12), CFrame.new(48, 44.8, 344), Color3.fromRGB(150, 110, 35), Enum.Material.Metal, false)
	dailyPad.CanQuery = false
	local shopPad = makePart(lobby, "ShopPad", Vector3.new(16, 0.35, 12), CFrame.new(48, 44.8, 300), Color3.fromRGB(105, 55, 145), Enum.Material.Metal, false)
	shopPad.CanQuery = false
	local defensePad = makePart(lobby, "DefensePad", Vector3.new(16, 0.35, 12), CFrame.new(-48, 44.8, 300), Color3.fromRGB(150, 65, 35), Enum.Material.Metal, false)
	defensePad.CanQuery = false

	for _, position in ipairs({ Vector3.new(-70, 44.5, 370), Vector3.new(70, 44.5, 370), Vector3.new(-70, 44.5, 280), Vector3.new(70, 44.5, 280) }) do
		buildTree(lobby, position, 0.8)
	end
	return spawnCFrame, lootPrompt, startPrompt, upgradePrompt, dailyPrompt, shopPrompt, defensePrompt
end

local function buildCapturePoint(parent)
	local model = Instance.new("Model")
	model.Name = "Capture67"
	model.Parent = parent
	local base = makePart(model, "CaptureBase", Vector3.new(28, 0.8, 28), CFrame.new(0, 0.4, 0), C.StoneDark, Enum.Material.Cobblestone, true)
	base:SetAttribute("CaptureGeometry", true)
	local crystal = makePart(model, "CaptureCrystal", Vector3.new(7, 10, 7), CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(237, 190, 64), Enum.Material.DiamondPlate, true)
	model.PrimaryPart = crystal
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -1, 1 }) do
			makePart(model, "CapturePylon", Vector3.new(2.2, 7, 2.2), CFrame.new(side * 11, 3.5, forward * 11), C.Stone, Enum.Material.Metal, true)
			makePart(model, "CaptureGlow", Vector3.new(2.5, 0.6, 2.5), CFrame.new(side * 11, 7.2, forward * 11), Color3.fromRGB(237, 190, 64), Enum.Material.Neon, false)
		end
	end
	for index = 1, 4 do
		local angle = math.rad(index * 90)
		makePart(model, "CaptureRing", Vector3.new(8, 0.3, 1), CFrame.new(math.cos(angle) * 9, 1.1, math.sin(angle) * 9) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(237, 190, 64), Enum.Material.Neon, false)
	end
	local light = Instance.new("PointLight")
	light.Name = "CaptureLight"
	light.Color = Color3.fromRGB(237, 190, 64)
	light.Brightness = 2.5
	light.Range = 30
	light.Parent = crystal
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "CaptureSparkles"
	sparkles.SparkleColor = Color3.fromRGB(237, 190, 64)
	sparkles.Parent = crystal
	local gui = billboard(crystal, "67", Color3.fromRGB(255, 222, 105), Vector3.new(0, 8, 0), UDim2.fromScale(1, 1))
	gui.Name = "Capture67Label"
	gui.Size = UDim2.fromOffset(250, 140)
	local label = gui:FindFirstChild("TextLabel")
	label.TextStrokeTransparency = 0.05
	local subtitleAnchor = makePart(model, "CaptureSubtitleAnchor", Vector3.new(1, 1, 1), CFrame.new(0, 2, 0), C.White, Enum.Material.SmoothPlastic, false)
	subtitleAnchor.Transparency = 1
	subtitleAnchor.CanQuery = false
	billboard(subtitleAnchor, "CAPTURE // КОНТРОЛЬ", C.White, Vector3.new(0, 4, 0), UDim2.fromScale(1, 1))
	model:SetAttribute("CaptureRadius", 22)
	return { Model = model, Root = crystal, Label = label, Light = light }
end

function WorldBuilder.Build()
	local old = Workspace:FindFirstChild("BlockSiegeWorld")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "BlockSiegeWorld"
	root.Parent = Workspace
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = root
	local structures = Instance.new("Folder")
	structures.Name = "Structures"
	structures.Parent = root
	local bots = Instance.new("Folder")
	bots.Name = "Bots"
	bots.Parent = root
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = root

	makePart(arena, "ArenaDirt", Vector3.new(420, 8, 190), CFrame.new(0, -6, 0), C.Dirt, Enum.Material.Ground, true)
	makePart(arena, "ArenaGrass", Vector3.new(420, 2, 190), CFrame.new(0, -1, 0), C.Grass, Enum.Material.Grass, true)
	makePart(arena, "CenterLane", Vector3.new(210, 0.35, 18), CFrame.new(0, 0.15, 0), C.Sand, Enum.Material.Ground, true)
	for _, z in ipairs({ -62, 62 }) do
		makePart(arena, "SideLane", Vector3.new(230, 0.3, 10), CFrame.new(0, 0.12, z), C.Sand, Enum.Material.Ground, true)
	end
	for index = 0, 20 do
		local x = -200 + index * 20
		local height = 8 + (index * 5 % 7)
		for _, side in ipairs({ -1, 1 }) do
			makePart(arena, "CliffDirt", Vector3.new(20, height, 6), CFrame.new(x, -10 - height / 2, side * 94), C.Dirt, Enum.Material.Ground, true)
			makePart(arena, "CliffStone", Vector3.new(18, 3, 6.5), CFrame.new(x, -12, side * 94), C.StoneDark, Enum.Material.Slate, true)
		end
	end
	for index = 1, 48 do
		local x = (index * 47 % 180) - 90
		local z = (index * 71 % 160) - 80
		if math.abs(z) > 12 then
			local tuft = makePart(arena, "GrassTuft", Vector3.new(0.45, 0.7 + (index % 3) * 0.2, 0.45), CFrame.new(x, 0.4, z), C.Leaf, Enum.Material.Grass, false)
			tuft.CanQuery = false
		end
	end
	for _, entry in ipairs({
		{ Vector3.new(-190, 62, -105), 1.1 }, { Vector3.new(-80, 76, -120), 0.85 },
		{ Vector3.new(45, 68, -112), 1.2 }, { Vector3.new(175, 72, -105), 0.9 },
		{ Vector3.new(-165, 70, 110), 0.9 }, { Vector3.new(-35, 60, 118), 1.1 },
		{ Vector3.new(95, 78, 112), 0.85 }, { Vector3.new(205, 64, 100), 1.15 },
	}) do
		buildCloud(arena, entry[1], entry[2])
	end

	local teamSpawns = {}
	for _, team in ipairs(Config.TeamOrder) do
		teamSpawns[team] = buildBase(arena, structures, team)
	end

	for _, position in ipairs({
		Vector3.new(-70, 0, -72), Vector3.new(-35, 0, 73), Vector3.new(35, 0, -73), Vector3.new(70, 0, 72),
		Vector3.new(-10, 0, -78), Vector3.new(10, 0, 78), Vector3.new(-90, 0, 62), Vector3.new(90, 0, -62),
	}) do
		buildTree(arena, position, 0.85)
	end
	for _, entry in ipairs({
		{ Vector3.new(-45, 3, -35), Vector3.new(12, 6, 8) },
		{ Vector3.new(45, 3, 35), Vector3.new(12, 6, 8) },
		{ Vector3.new(-45, 3, 35), Vector3.new(12, 6, 8) },
		{ Vector3.new(45, 3, -35), Vector3.new(12, 6, 8) },
	}) do
		makePart(arena, "StoneCover", entry[2], CFrame.new(entry[1]), C.Stone, Enum.Material.Cobblestone, true)
	end

	local capturePoint = buildCapturePoint(arena)
	local lobbySpawn, lootPrompt, startPrompt, upgradePrompt, dailyPrompt, shopPrompt, defensePrompt = buildLobby(lobby)
	Lighting.Brightness = 2
	Lighting.ClockTime = 14.5
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(137, 151, 146)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 244, 215)
	local function ensureEffect(className, name)
		local effect = Lighting:FindFirstChild(name)
		if not effect then
			effect = Instance.new(className)
			effect.Name = name
			effect.Parent = Lighting
		end
		return effect
	end
	local atmosphere = ensureEffect("Atmosphere", "BlockSiegeAtmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 0.7
	local colorCorrection = ensureEffect("ColorCorrectionEffect", "BlockSiegeColor")
	colorCorrection.Saturation = 0.07
	colorCorrection.Contrast = 0.04
	local bloom = ensureEffect("BloomEffect", "BlockSiegeBloom")
	bloom.Intensity = 0.16
	bloom.Size = 18
	bloom.Threshold = 1.15
	local rays = ensureEffect("SunRaysEffect", "BlockSiegeSun")
	rays.Intensity = 0.025

	return {
		Root = root,
		Arena = arena,
		Structures = structures,
		Bots = bots,
		Lobby = lobby,
		LobbySpawn = lobbySpawn,
		TeamSpawns = teamSpawns,
		LootPrompt = lootPrompt,
		StartPrompt = startPrompt,
		UpgradePrompt = upgradePrompt,
		DailyPrompt = dailyPrompt,
		ShopPrompt = shopPrompt,
		DefensePrompt = defensePrompt,
		CapturePoint = capturePoint,
	}
end

return WorldBuilder
