-- Разрушаемые крепости, строительная сетка и серверная проверка урона.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local CombatModels = require(Shared:WaitForChild("CombatModels"))
local VisualModels = require(Shared:WaitForChild("VisualModels"))

local vector3Type = typeof(Vector3.new())
local FortressService = {}
local world
local remotes
local state
local phaseProvider = function()
	return "Lobby"
end
local coreHandler
local damageHandler
local entries = {}
local partIndex = {}
local cores = {}
local buildCounts = {}
local nextId = 0
local buildCapacityProvider = function()
	return Config.Arena.MaxBuildPerPlayer
end
local buildAccessProvider = function()
	return true
end
local targetsProvider = function()
	return {}
end
local captureProvider = function()
	return nil
end
local circuitFolder
local circuits = {}
local circuitDirty = {}
local CIRCUIT_KINDS = { "Wall", "Barricade", "Tower" }
local isBreachActive

local function markCircuitDirty(team)
	if Config.Teams[team] then
		circuitDirty[team] = true
	end
end

local STRUCTURE_TEXTURES = {
	[Enum.Material.Cobblestone] = { Asset = "rbxassetid://9438459300", Tile = 5, Transparency = 0.1 },
	[Enum.Material.WoodPlanks] = { Asset = "rbxassetid://9439658515", Tile = 4, Transparency = 0.08 },
	[Enum.Material.Metal] = { Asset = "rbxassetid://9920574687", Tile = 3, Transparency = 0.16 },
}

local function addStructureTextures(part, name, material)
	if name ~= "Root" and name ~= "CorePedestal" and name ~= "CorePylon" then
		return
	end
	local style = STRUCTURE_TEXTURES[material]
	if not style then
		return
	end
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Front }) do
		local texture = Instance.new("Texture")
		texture.Name = "StructureSurfaceTexture"
		texture.Texture = style.Asset
		texture.Face = face
		texture.StudsPerTileU = style.Tile
		texture.StudsPerTileV = style.Tile
		texture.Transparency = style.Transparency
		texture.Parent = part
	end
	part:SetAttribute("SurfaceTextured", true)
end

local function makeBlock(model, name, size, cframe, color, material, collide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Cobblestone
	part.Anchored = true
	part.CanCollide = collide ~= false
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	addStructureTextures(part, name, part.Material)
	return part
end

local function updateState(team)
	local core = cores[team]
	if core and state then
		state:SetAttribute(team .. "Core", math.max(0, math.ceil(core.Health)))
		state:SetAttribute(team .. "CoreMax", core.MaxHealth)
	end
end

local function registerEntry(model, team, kind, health)
	nextId = nextId + 1
	local entry = {
		Id = nextId,
		Model = model,
		Team = team,
		Kind = kind,
		Health = health,
		MaxHealth = health,
		Active = true,
		Parts = {},
	}
	model.Name = string.format("%s_%s_%03d", team, kind, nextId)
	model:SetAttribute("Team", team)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("StructureId", nextId)
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetAttribute("StructureId", nextId)
			part:SetAttribute("Team", team)
			part:SetAttribute("Kind", kind)
			partIndex[part] = entry
			table.insert(entry.Parts, part)
		end
	end
	entries[nextId] = entry
	return entry
end

local function createCore(team)
	local model = Instance.new("Model")
	model.Parent = world.Structures
	local teamColor = Config.Teams[team].Color
	local baseCFrame = Config.BaseCFrame(team)
	local heart = makeBlock(model, "CoreHeart", Vector3.new(10, 12, 10), baseCFrame * CFrame.new(0, 7, 0), teamColor, Enum.Material.Neon, true)
	heart.Shape = Enum.PartType.Ball
	model.PrimaryPart = heart
	makeBlock(model, "CorePedestal", Vector3.new(18, 2, 18), baseCFrame * CFrame.new(0, 1, 0), Config.Teams[team].Dark, Enum.Material.Cobblestone, true)
	for _, height in ipairs({ 2, 12 }) do
		makeBlock(model, "CoreBand", Vector3.new(12, 1, 12), baseCFrame * CFrame.new(0, height, 0), Color3.fromRGB(238, 188, 68), Enum.Material.Metal, false)
	end
	for _, side in ipairs({ -1, 1 }) do
		makeBlock(model, "CorePylon", Vector3.new(2, 16, 2), baseCFrame * CFrame.new(side * 8, 8, 0), Config.Teams[team].Dark, Enum.Material.Cobblestone, true)
	end
	for index, offset in ipairs({ Vector3.new(-7, 6, -7), Vector3.new(-7, 8, 7), Vector3.new(7, 8, -7), Vector3.new(7, 6, 7) }) do
		local orbital = makeBlock(model, "CoreOrbital", Vector3.new(2.4, 2.4, 2.4), baseCFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad(index * 18), 0), teamColor, Enum.Material.Neon, false)
		orbital.Shape = Enum.PartType.Ball
		orbital.Transparency = 0.12
	end
	local coreLight = Instance.new("PointLight")
	coreLight.Name = "CoreGlow"
	coreLight.Color = teamColor
	coreLight.Brightness = 2.2
	coreLight.Range = 26
	coreLight.Shadows = true
	coreLight.Parent = heart
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "CoreSparkles"
	sparkles.SparkleColor = teamColor
	sparkles.Parent = heart
	heart.Transparency = 1
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and (item.Name == "CorePedestal" or item.Name == "CoreBand" or item.Name == "CorePylon" or item.Name == "CoreOrbital") then
			item.Transparency = 1
		end
	end
	VisualModels.Core(model, heart.CFrame, teamColor)
	local entry = registerEntry(model, team, "Core", Config.Arena.CoreHealth)
	cores[team] = entry
	updateState(team)
	return entry
end

local function createStructure(team, kind, cframe, circuitEligible)
	local definition = Config.BuildKinds[kind]
	if not definition then
		return nil
	end
	local model = Instance.new("Model")
	model.Parent = world.Structures
	local color = Config.Teams[team].Color
	local dark = Config.Teams[team].Dark
	local root = makeBlock(model, "Root", definition.Size, cframe, dark, definition.Trap and Enum.Material.Metal or (kind == "Barricade" and Enum.Material.WoodPlanks or Enum.Material.Cobblestone), true)
	model.PrimaryPart = root
	if kind == "LaneTower" then
		model:SetAttribute("Objective", "LaneTower")
		-- Keep the original collision/damage parts as invisible proxies. The
		-- visible tower is a sculpted mesh-style assembly, not a stack of cubes.
		root.Transparency = 1
		local oldBase = makeBlock(model, "TowerBase", Vector3.new(11, 1.2, 11), cframe * CFrame.new(0, -6.4, 0), dark, Enum.Material.Cobblestone, true)
		oldBase.Transparency = 1
		local oldBand = makeBlock(model, "TowerBand", Vector3.new(8.5, 0.7, 8.5), cframe * CFrame.new(0, 3.8, 0), color, Enum.Material.Metal, false)
		oldBand.Transparency = 1
		local oldHead = makeBlock(model, "TowerHead", Vector3.new(7, 3, 7), cframe * CFrame.new(0, 5.5, 0), color, Enum.Material.DiamondPlate, true)
		oldHead.Transparency = 1
		local barrel = makeBlock(model, "TowerBarrel", Vector3.new(8, 1.4, 1.4), cframe * CFrame.new(0, 5.5, -5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(222, 238, 244), Enum.Material.Metal, false)
		barrel.Shape = Enum.PartType.Cylinder
		local eye = makeBlock(model, "TowerEye", Vector3.new(2.2, 0.65, 0.4), cframe * CFrame.new(0, 6, -3.6), Color3.fromRGB(255, 211, 99), Enum.Material.Neon, false)
		eye.Transparency = 1
		local glow = Instance.new("PointLight")
		glow.Name = "TowerGlow"
		glow.Color = color
		glow.Brightness = 1.4
		glow.Range = 16
		glow.Parent = eye
		local ground = cframe.Position - Vector3.new(0, 7, 0)
		VisualModels.Tower(model, "LaneTowerVisual", ground, 0.62, color)
	elseif definition.Trap then
		model:SetAttribute("IsTrap", true)
		model:SetAttribute("DefenseId", kind)
		if kind == "SpikeTrap" then
			for index = 1, 5 do
				local angle = math.rad(index * 72)
				local offset = Vector3.new(math.cos(angle) * 2.4, 1.8, math.sin(angle) * 2.4)
				makeBlock(model, "Spike", Vector3.new(1.1, 3.8, 1.1), cframe * CFrame.new(offset) * CFrame.Angles(0, angle, math.rad(18)), Color3.fromRGB(193, 205, 198), Enum.Material.Metal, true)
				makeBlock(model, "SpikeTip", Vector3.new(1.2, 0.45, 1.2), cframe * CFrame.new(offset + Vector3.new(0, 1.9, 0)), color, Enum.Material.Neon, false)
			end
		elseif kind == "ShockMine" then
			local core = makeBlock(model, "MineCore", Vector3.new(3.2, 2.2, 3.2), cframe * CFrame.new(0, 1.1, 0), Color3.fromRGB(75, 198, 255), Enum.Material.Neon, false)
			core.Shape = Enum.PartType.Ball
			makeBlock(model, "MineRing", Vector3.new(5.5, 0.35, 1), cframe * CFrame.new(0, 0.8, 0), color, Enum.Material.Metal, false)
			makeBlock(model, "MineRing", Vector3.new(1, 0.35, 5.5), cframe * CFrame.new(0, 0.8, 0), color, Enum.Material.Metal, false)
			local light = Instance.new("PointLight")
			light.Name = "MineGlow"
			light.Color = Color3.fromRGB(75, 198, 255)
			light.Brightness = 1.5
			light.Range = 10
			light.Parent = core
		elseif kind == "FlameTrap" then
			makeBlock(model, "FlameNozzle", Vector3.new(2, 2.4, 2), cframe * CFrame.new(0, 1.5, 0), Color3.fromRGB(238, 113, 48), Enum.Material.Metal, true)
			makeBlock(model, "FlameCore", Vector3.new(1.2, 2.8, 1.2), cframe * CFrame.new(0, 3.5, 0), Color3.fromRGB(255, 207, 70), Enum.Material.Neon, false)
		end
	else
		if kind == "Barricade" then
			root.Transparency = 1
			local oldBrace = makeBlock(model, "WoodBrace", Vector3.new(1, definition.Size.Y + 1, definition.Size.Z + 0.4), cframe * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(28)), Color3.fromRGB(164, 111, 55), Enum.Material.WoodPlanks, true)
			oldBrace.Transparency = 1
			VisualModels.Barricade(model, cframe, color)
		else
			root.Transparency = 1
			local oldBand = makeBlock(model, "TeamBand", Vector3.new(definition.Size.X + 0.25, 0.8, definition.Size.Z + 0.25), cframe * CFrame.new(0, definition.Size.Y * 0.25, 0), color, Enum.Material.Metal, false)
			oldBand.Transparency = 1
			for _, side in ipairs({ -1, 0, 1 }) do
				local oldBattlement = makeBlock(model, "Battlement", Vector3.new(math.max(1.5, definition.Size.X / 4), 2, definition.Size.Z), cframe * CFrame.new(side * definition.Size.X * 0.32, definition.Size.Y / 2 + 1, 0), dark, Enum.Material.Cobblestone, true)
				oldBattlement.Transparency = 1
			end
			if kind == "Tower" then
				local towerVisual = VisualModels.Tower(model, "BuildTowerVisual", cframe.Position - Vector3.new(0, definition.Size.Y / 2, 0), 0.78, color)
				-- Body is an X-axis cylinder: retain its intrinsic Z=90 rotation.
				towerVisual:PivotTo(cframe * CFrame.new(0, -3.93, 0) * CFrame.Angles(0, 0, math.rad(90)))
			else
				VisualModels.Wall(model, cframe, color)
			end
		end
	end
	local entry = registerEntry(model, team, kind, definition.Health)
	entry.PlacementCFrame = cframe
	entry.PlacementLocked = kind == "Barricade"
	model:SetAttribute("PlacementLocked", entry.PlacementLocked)
	root:SetAttribute("PlacementLocked", entry.PlacementLocked)
	entry.IsTrap = definition.Trap == true
	entry.IsLaneTower = kind == "LaneTower"
	entry.ArmedAt = os.clock() + 1
	entry.NextTrigger = 0
	entry.NextAttack = os.clock() + 0.8
	CombatModels.RegisterStructureAnimation(entry)
	entry.CircuitEligible = circuitEligible == true and (kind == "Wall" or kind == "Barricade" or kind == "Tower")
	model:SetAttribute("CircuitNode", entry.CircuitEligible)
	if entry.CircuitEligible then
		-- Visuals are added after registerEntry: they are deliberately not damage
		-- proxies, navigation obstacles or extra structure hit points.
		local node = Instance.new("Part")
		node.Name = "CircuitNodeVisual"
		node.Shape = Enum.PartType.Ball
		node.Size = Vector3.new(1.8, 1.8, 1.8)
		node.CFrame = root.CFrame * CFrame.new(0, root.Size.Y / 2 + 2.2, 0)
		node.Color = Color3.fromRGB(86, 99, 112)
		node.Material = Enum.Material.Neon
		node.Anchored = true
		node.CanCollide = false
		node.CanTouch = false
		node.CanQuery = false
		node.CastShadow = false
		node:SetAttribute("Team", team)
		node:SetAttribute("BaseGeometry", true)
		node.Parent = model
		local light = Instance.new("PointLight")
		light.Name = "CircuitNodeLight"
		light.Color = color
		light.Brightness = 0
		light.Range = 12
		-- Keep Enabled stable for BaseVisibilityClient's original-state cache;
		-- server updates Brightness while the client alone controls fog hiding.
		light.Enabled = true
		light.Parent = node
		entry.CircuitVisual = node
		model:SetAttribute("CircuitLinked", false)
		markCircuitDirty(team)
	end
	return entry
end

local function createLaneTower(team, lane, distance)
	local side = team == "Blue" and -1 or 1
	local zOffset = lane == 0 and 18 or (lane > 0 and -16 or 16)
	local position = Vector3.new(side * distance, 7, lane + zOffset)
	local facing = team == "Blue" and 1 or -1
	local towerCFrame = CFrame.lookAt(position, position + Vector3.new(facing, 0, 0))
	local entry = createStructure(team, "LaneTower", towerCFrame)
	if entry then
		entry.Lane = lane
		entry.Model:SetAttribute("Lane", lane)
		entry.Model:SetAttribute("AttackRange", Config.BuildKinds.LaneTower.AttackRange)
	end
	return entry
end

local function removeEntry(entry)
	if not entry.Active then
		return
	end
	entry.Active = false
	if entry.CircuitEligible then
		markCircuitDirty(entry.Team)
	end
	for _, part in ipairs(entry.Parts) do
		partIndex[part] = nil
	end
	entries[entry.Id] = nil
	if entry.Model then
		entry.Model:Destroy()
	end
end

function FortressService.Init(dependencies)
	world = dependencies.World
	remotes = dependencies.Remotes
	state = dependencies.State
	circuitFolder = Instance.new("Folder")
	circuitFolder.Name = "CircuitVisuals"
	circuitFolder.Parent = world.Root
end

function FortressService.SetPhaseProvider(provider)
	phaseProvider = provider
end

function FortressService.SetCoreHandler(handler)
	coreHandler = handler
end

function FortressService.SetDamageHandler(handler)
	damageHandler = handler
end

function FortressService.SetBuildCapacityProvider(provider)
	buildCapacityProvider = provider or function()
		return Config.Arena.MaxBuildPerPlayer
	end
end

function FortressService.SetBuildAccessProvider(provider)
	buildAccessProvider = provider or function()
		return true
	end
end

function FortressService.SetTargetsProvider(provider)
	targetsProvider = provider or function()
		return {}
	end
end

function FortressService.SetCaptureProvider(provider)
	captureProvider = provider or function()
		return nil
	end
end

function FortressService.Clear()
	for _, entry in pairs(entries) do
		entry.Active = false
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	entries = {}
	partIndex = {}
	cores = {}
	buildCounts = {}
	circuits = {}
	circuitDirty = {}
	if circuitFolder then
		circuitFolder:ClearAllChildren()
	end
	if state then
		for _, team in ipairs(Config.TeamOrder) do
			state:SetAttribute(team .. "CircuitOnline", false)
			state:SetAttribute(team .. "CircuitTypeCount", 0)
			state:SetAttribute(team .. "CircuitCharge", 0)
			state:SetAttribute(team .. "CircuitBreach", 0)
			state:SetAttribute(team .. "CircuitCooldown", 0)
		end
	end
end

function FortressService.Reset()
	FortressService.Clear()
	for _, team in ipairs(Config.TeamOrder) do
		createCore(team)
		local baseCFrame = Config.BaseCFrame(team)
		-- Two wall pairs leave a real central gate. The old -21/-7/7/21
		-- layout had only 2-stud slits, too narrow for the R6 pathfinding agent.
		for _, x in ipairs({ -35, -21, 21, 35 }) do
			createStructure(team, "Wall", baseCFrame * CFrame.new(x, 6, -28))
		end
		for _, side in ipairs({ -1, 1 }) do
			createStructure(team, "Barricade", baseCFrame * CFrame.new(side * 42, 2.5, 4) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
	if Config.Objectives and Config.Objectives.LaneTowers then
		for _, team in ipairs(Config.TeamOrder) do
			for _, lane in ipairs(Config.Objectives.Lanes) do
				for _, distance in ipairs(Config.Objectives.TowerDistances) do
					createLaneTower(team, lane, distance)
				end
			end
		end
	end
	if state then
		state:SetAttribute("LaneTowerCount", Config.Objectives and (#Config.Objectives.Lanes * #Config.Objectives.TowerDistances * 2) or 0)
	end
end

local function validPosition(position)
	return typeof(position) == vector3Type and position.X == position.X and position.Y == position.Y and position.Z == position.Z
		and math.abs(position.X) < 10000 and math.abs(position.Y) < 10000 and math.abs(position.Z) < 10000
end

local function normalizeRotation(rotation)
	if type(rotation) ~= "number" or rotation ~= rotation or rotation == math.huge or rotation == -math.huge then
		return 0
	end
	local degrees = rotation % 360
	return math.floor(degrees / 90 + 0.5) % 4
end

function FortressService.GetRotationDegrees(rotation)
	return normalizeRotation(rotation) * 90
end

local function placement(team, kind, position, rotation)
	local definition = Config.BuildKinds[kind]
	if not definition or kind == "LaneTower" or not validPosition(position) then
		return nil, "Неверная позиция"
	end
	local baseCFrame = Config.BaseCFrame(team)
	local localPosition = baseCFrame:PointToObjectSpace(position)
	if math.abs(localPosition.X) > Config.Arena.BuildZoneSide or math.abs(localPosition.Z) > Config.Arena.BuildZoneForward then
		return nil, "Строить можно только на своей базе"
	end
	local grid = Config.Arena.BuildGrid
	local x = math.floor(localPosition.X / grid + 0.5) * grid
	local z = math.floor(localPosition.Z / grid + 0.5) * grid
	if Vector3.new(x, 0, z).Magnitude < 17 then
		return nil, "Оставьте место вокруг ядра"
	end
	if z > 25 and math.abs(x) < 18 then
		return nil, "Не блокируйте возрождение команды"
	end
	for _, entry in pairs(entries) do
		if entry.Active and entry.Team == team then
			local other = baseCFrame:PointToObjectSpace(entry.Model.PrimaryPart.Position)
			if math.abs(other.X - x) < 10 and math.abs(other.Z - z) < 10 then
				return nil, "Здесь уже есть постройка"
			end
		end
	end
	return baseCFrame * CFrame.new(x, definition.Size.Y / 2, z) * CFrame.Angles(0, math.rad(normalizeRotation(rotation) * 90), 0)
end

function FortressService.GetPlayerPlacement(player, team, kind, position, rotation)
	if phaseProvider() ~= "Build" then
		return nil, "Строительство уже закончено"
	end
	if not validPosition(position) then
		return nil, "Неверная позиция"
	end
	if not Config.Teams[team] then
		return nil, "Вы не участвуете в матче"
	end
	if not buildAccessProvider(player, kind) then
		return nil, "Сначала купите этот чертёж в магазине"
	end
	local count = buildCounts[player.UserId] or 0
	local capacity = buildCapacityProvider(player)
	if count >= capacity then
		return nil, "Лимит построек исчерпан"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - position).Magnitude > Config.Arena.MaxBuildDistance then
		return nil, "Подойдите ближе к месту постройки"
	end
	return placement(team, kind, position, rotation)
end

function FortressService.BuildPlayer(player, team, kind, position, rotation)
	local cframe, reason = FortressService.GetPlayerPlacement(player, team, kind, position, rotation)
	if not cframe then
		return false, reason
	end
	local entry = createStructure(team, kind, cframe, true)
	local count = (buildCounts[player.UserId] or 0) + 1
	buildCounts[player.UserId] = count
	local capacity = buildCapacityProvider(player)
	player:SetAttribute("BuildLimit", capacity)
	player:SetAttribute("BuildUsed", count)
	player:SetAttribute("BuildRemaining", math.max(0, capacity - count))
	remotes.BuildFX:FireAllClients({ Kind = "Build", Position = cframe.Position, Team = team })
	return true, entry
end

local botPads = {
	{ { -46, -44 }, { -46, -16 }, { -46, 20 } },
	{ { -30, -44 }, { -30, -16 }, { -30, 20 } },
	{ { 30, -44 }, { 30, -16 }, { 30, 20 } },
	{ { 46, -44 }, { 46, -16 }, { 46, 20 } },
	{ { -14, -44 }, { -30, 40 }, { -46, 40 } },
	{ { 14, -44 }, { 30, 40 }, { 46, 40 } },
}

function FortressService.BuildBot(team, slot, buildIndex)
	if phaseProvider() ~= "Build" then
		return false
	end
	local botSlot = botPads[((slot - 1) % #botPads) + 1]
	local pad = botSlot[buildIndex]
	if not pad then
		return false
	end
	local kind = buildIndex == 2 and "Barricade" or (buildIndex == 3 and "Tower" or "Wall")
	-- Try nearby tactical pads if a human or another bot already occupied the preferred one.
	local offsets = { { 0, 0 }, { 14, 0 }, { -14, 0 }, { 0, 14 }, { 0, -14 }, { 18, 12 }, { -18, 12 } }
	for _, offset in ipairs(offsets) do
		local position = (Config.BaseCFrame(team) * CFrame.new(pad[1] + offset[1], 0, pad[2] + offset[2])).Position
		local cframe = placement(team, kind, position)
		if cframe then
			createStructure(team, kind, cframe, true)
			return true
		end
	end
	return false
end

function FortressService.RepairStructures(team, position, radius, amount)
	if not Config.Teams[team] or not validPosition(position) then
		return 0
	end
	local repaired = 0
	local repairAmount = math.max(0, tonumber(amount) or 0)
	for _, entry in pairs(entries) do
		local root = entry.Active and entry.Team == team and entry.Model and entry.Model.PrimaryPart or nil
		if root and (root.Position - position).Magnitude <= radius then
			local before = tonumber(entry.Health) or 0
			local maximum = tonumber(entry.MaxHealth) or before
			entry.Health = math.min(maximum, before + repairAmount)
			entry.Model:SetAttribute("Health", entry.Health)
			repaired = repaired + entry.Health - before
			if entry.Kind == "Core" then
				updateState(team)
			end
		end
	end
	return repaired
end

function FortressService.DamagePart(part, amount, attackingTeam, player)
	if phaseProvider() ~= "Battle" or not part or not Config.Teams[attackingTeam] then
		return 0
	end
	local entry = partIndex[part]
	if not entry or not entry.Active or entry.Team == attackingTeam then
		return 0
	end
	local breach = entry.Kind == "Core" and isBreachActive(attackingTeam, os.clock())
	local multiplier = breach and Config.Arena.CircuitCoreMultiplier or 1
	local applied = math.min(entry.Health, math.max(0, tonumber(amount) or 0) * multiplier)
	if applied <= 0 then
		return 0
	end
	entry.Health = entry.Health - applied
	entry.Model:SetAttribute("Health", entry.Health)
	if player and damageHandler then
		damageHandler(player, applied, entry.Kind, entry.Health <= 0)
	end
	remotes.CombatFX:FireAllClients({ Kind = "StructureHit", Position = part.Position, Team = entry.Team, CircuitBreach = breach })
	if entry.Kind == "Core" then
		updateState(entry.Team)
	end
	local healthRatio = entry.Health / entry.MaxHealth
	if entry.Kind ~= "Core" and healthRatio < 0.66 then
		for _, structurePart in ipairs(entry.Parts) do
			if structurePart.Name == "Root" then
				structurePart.Color = healthRatio < 0.33 and Color3.fromRGB(63, 51, 46) or Color3.fromRGB(88, 82, 69)
			end
		end
	end
	if healthRatio < 0.35 and not entry.Model:FindFirstChild("DamageSmoke") then
		local smoke = Instance.new("Smoke")
		smoke.Name = "DamageSmoke"
		smoke.Color = Color3.fromRGB(74, 70, 64)
		smoke.Opacity = 0.22
		smoke.RiseVelocity = 2
		smoke.Size = 7
		smoke.Parent = entry.Model.PrimaryPart
	end
	if entry.Health <= 0 then
		local losingTeam = entry.Team
		local kind = entry.Kind
		local position = entry.Model.PrimaryPart and entry.Model.PrimaryPart.Position or part.Position
		removeEntry(entry)
		if kind == "Core" then
			cores[losingTeam] = nil
			if state then
				state:SetAttribute(losingTeam .. "Core", 0)
			end
			remotes.CombatFX:FireAllClients({ Kind = "CoreDestroyed", Position = position, Team = losingTeam })
			if coreHandler then
				coreHandler(losingTeam, attackingTeam)
			end
		else
			remotes.CombatFX:FireAllClients({ Kind = "StructureDestroyed", Position = position, Team = losingTeam })
		end
	end
	return applied
end

function FortressService.GetCorePosition(team)
	local core = cores[team]
	if core and core.Active and core.Model.PrimaryPart then
		return core.Model.PrimaryPart.Position
	end
	return Config.BasePosition(team) + Vector3.new(0, 7, 0)
end

function FortressService.GetCoreHealth(team)
	local core = cores[team]
	return core and core.Active and core.Health or 0
end

function FortressService.GetStructureCount(team)
	local count = 0
	for _, entry in pairs(entries) do
		if entry.Active and (not team or entry.Team == team) then
			count = count + 1
		end
	end
	return count
end

function FortressService.GetEntry(part)
	return partIndex[part]
end

function FortressService.GetEntries()
	local result = {}
	for _, entry in pairs(entries) do
		if entry.Active then
			table.insert(result, entry)
		end
	end
	return result
end

local function ensureCircuit(team)
	local circuit = circuits[team]
	if circuit then
		return circuit
	end
	local folder = Instance.new("Folder")
	folder.Name = team .. "Circuit"
	folder.Parent = circuitFolder
	circuit = { Charge = 0, BreachUntil = 0, NextBreach = 0, Online = false, TypeCount = 0, Nodes = {}, Beams = {}, Folder = folder }
	circuits[team] = circuit
	return circuit
end

isBreachActive = function(team, now)
	local circuit = circuits[team]
	return circuit ~= nil and now < (circuit.BreachUntil or 0)
end

local function circuitNodePosition(entry)
	local root = entry.Model and entry.Model.PrimaryPart
	return root.Position + Vector3.new(0, root.Size.Y / 2 + 2.2, 0)
end

local function createCircuitBeam(folder, team, from, to)
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return nil
	end
	local beam = Instance.new("Part")
	beam.Name = "CircuitLink"
	beam.Size = Vector3.new(0.34, 0.34, distance)
	beam.CFrame = CFrame.lookAt((from + to) * 0.5, to)
	beam.Color = Config.Teams[team].Color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.35
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam:SetAttribute("Team", team)
	beam:SetAttribute("BaseGeometry", true)
	beam.Parent = folder
	return beam
end

local function refreshCircuit(team)
	local circuit = ensureCircuit(team)
	circuit.Folder:ClearAllChildren()
	local byKind = { Wall = {}, Barricade = {}, Tower = {} }
	local all = {}
	local positions = {}
	for id = 1, nextId do
		local entry = entries[id]
		if entry and entry.Active and entry.Team == team and entry.CircuitEligible and entry.Model and entry.Model.PrimaryPart then
			table.insert(byKind[entry.Kind], entry)
			table.insert(all, entry)
			positions[entry] = circuitNodePosition(entry)
		end
	end
	local typeCount = 0
	for _, kind in ipairs(CIRCUIT_KINDS) do
		if #byKind[kind] > 0 then
			typeCount = typeCount + 1
		end
	end
	local best
	local bestScore = math.huge
	for _, wall in ipairs(byKind.Wall) do
		for _, barricade in ipairs(byKind.Barricade) do
			for _, tower in ipairs(byKind.Tower) do
				local ab = (positions[wall] - positions[barricade]).Magnitude
				local bc = (positions[barricade] - positions[tower]).Magnitude
				local ca = (positions[tower] - positions[wall]).Magnitude
				if math.max(ab, bc, ca) <= Config.Arena.CircuitMaxLink then
					local score = ab + bc + ca
					if score < bestScore then
						bestScore = score
						best = { wall, barricade, tower }
					end
				end
			end
		end
	end
	for _, entry in ipairs(all) do
		entry.Model:SetAttribute("CircuitLinked", false)
		if entry.CircuitVisual then
			entry.CircuitVisual.Color = Color3.fromRGB(86, 99, 112)
		end
	end
	circuit.Nodes = best or {}
	circuit.Online = best ~= nil
	circuit.TypeCount = typeCount
	circuit.Beams = {}
	if best then
		for _, entry in ipairs(best) do
			entry.Model:SetAttribute("CircuitLinked", true)
			if entry.CircuitVisual then
				entry.CircuitVisual.Color = Config.Teams[team].Color
			end
		end
		for index = 1, 3 do
			local beam = createCircuitBeam(circuit.Folder, team, positions[best[index]], positions[best[index % 3 + 1]])
			if beam then
				table.insert(circuit.Beams, beam)
			end
		end
	end
	circuitDirty[team] = false
	if state then
		state:SetAttribute(team .. "CircuitOnline", circuit.Online)
		state:SetAttribute(team .. "CircuitTypeCount", typeCount)
	end
end

local function publishCircuit(team, now)
	local circuit = ensureCircuit(team)
	local breach = math.max(0, (circuit.BreachUntil or 0) - now)
	local cooldown = math.max(0, (circuit.NextBreach or 0) - now)
	if state then
		state:SetAttribute(team .. "CircuitCharge", math.floor((circuit.Charge or 0) + 0.5))
		state:SetAttribute(team .. "CircuitBreach", breach)
		state:SetAttribute(team .. "CircuitCooldown", cooldown)
	end
	local phase = phaseProvider()
	local visible = phase == "Build" or phase == "Battle"
	local activeBreach = breach > 0
	local color = activeBreach and Color3.fromRGB(255, 220, 110) or Config.Teams[team].Color
	for _, beam in ipairs(circuit.Beams) do
		if beam.Parent then
			beam.Color = color
			beam.Transparency = visible and (activeBreach and 0.02 or 0.35) or 1
		end
	end
	for id = 1, nextId do
		local entry = entries[id]
		if entry and entry.Active and entry.Team == team and entry.CircuitEligible and entry.CircuitVisual then
			local linked = entry.Model:GetAttribute("CircuitLinked") == true
			entry.CircuitVisual.Transparency = visible and (linked and 0.05 or 0.65) or 1
			if linked then
				entry.CircuitVisual.Color = color
			end
			local light = entry.CircuitVisual:FindFirstChild("CircuitNodeLight")
			if light then
				light.Brightness = visible and linked and (activeBreach and 2.4 or 1.5) or 0
				light.Color = color
			end
		end
	end
	local core = cores[team]
	local enemyCircuit = circuits[Config.OtherTeam(team)]
	if core and core.Active then
		core.Model:SetAttribute("BreachVulnerable", enemyCircuit ~= nil and now < (enemyCircuit.BreachUntil or 0))
	end
end

local function updateCircuit(team, deltaTime, now)
	if circuitDirty[team] or not circuits[team] then
		refreshCircuit(team)
	end
	local circuit = ensureCircuit(team)
	if phaseProvider() ~= "Battle" then
		circuit.Charge = 0
		circuit.BreachUntil = 0
		circuit.NextBreach = 0
	else
		local activeBreach = isBreachActive(team, now)
		if not activeBreach then
			circuit.BreachUntil = 0
			if now >= (circuit.NextBreach or 0) then
				if circuit.Online and captureProvider() == team then
					circuit.Charge = math.min(100, (circuit.Charge or 0) + Config.Arena.CircuitChargePerSecond * deltaTime)
					if circuit.Charge >= 100 then
						circuit.Charge = 0
						circuit.BreachUntil = now + Config.Arena.CircuitBreachDuration
						circuit.NextBreach = now + Config.Arena.CircuitBreachCooldown
						if remotes and remotes.CombatFX then
							remotes.CombatFX:FireAllClients({
								Kind = "CircuitBreach", Team = team, Position = FortressService.GetCorePosition(Config.OtherTeam(team)),
								Duration = Config.Arena.CircuitBreachDuration, Multiplier = Config.Arena.CircuitCoreMultiplier,
							})
						end
					end
				else
					local decay = circuit.Online and 2 or 25
					circuit.Charge = math.max(0, (circuit.Charge or 0) - decay * deltaTime)
				end
			end
		end
	end
	publishCircuit(team, now)
end

function FortressService.GetCircuitState(team)
	local circuit = circuits[team]
	if not circuit then
		return { Online = false, TypeCount = 0, Charge = 0, Breach = 0, Cooldown = 0, NodeIds = {} }
	end
	local nodeIds = {}
	for _, entry in ipairs(circuit.Nodes) do
		table.insert(nodeIds, entry.Id)
	end
	return {
		Online = circuit.Online, TypeCount = circuit.TypeCount, Charge = circuit.Charge,
		Breach = math.max(0, circuit.BreachUntil - os.clock()), Cooldown = math.max(0, circuit.NextBreach - os.clock()), NodeIds = nodeIds,
	}
end

local function applyTrapDamage(model, amount)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local armor = tonumber(model:GetAttribute("Armor")) or 0
	local shield = tonumber(model:GetAttribute("DamageTakenMultiplier")) or 1
	humanoid:TakeDamage(amount * math.clamp(shield, 0.05, 1) * (1 - math.clamp(armor, 0, 0.65)))
	return true
end

local function towerAttack(entry, definition, root, now)
	if now < (entry.NextAttack or 0) then
		return
	end
	local best
	local bestRoot
	local bestDistance = definition.AttackRange
	for _, model in ipairs(targetsProvider(entry.Team)) do
		local targetRoot = model and model:FindFirstChild("HumanoidRootPart")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if targetRoot and humanoid and humanoid.Health > 0 then
			local distance = (targetRoot.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best = model
				bestRoot = targetRoot
				bestDistance = distance
			end
		end
	end
	if not best then
		entry.NextAttack = now + 0.25
		return
	end
	entry.NextAttack = now + definition.AttackCooldown
	local aimPosition = Vector3.new(bestRoot.Position.X, root.Position.Y, bestRoot.Position.Z)
	if (aimPosition - root.Position).Magnitude > 0.1 then
		entry.Model:PivotTo(CFrame.lookAt(root.Position, aimPosition))
	end
	applyTrapDamage(best, definition.AttackDamage)
	entry.Model:SetAttribute("TargetName", best.Name)
	local barrel = entry.Model:FindFirstChild("TowerBarrel")
	remotes.CombatFX:FireAllClients({
		Kind = "TowerShot",
		Origin = barrel and barrel.Position or root.Position + Vector3.new(0, 6, 0),
		Finish = bestRoot.Position,
		Position = bestRoot.Position,
		Team = entry.Team,
		Color = Config.Teams[entry.Team].Color,
	})
end

function FortressService.Step(deltaTime)
	local now = os.clock()
	local step = math.clamp(tonumber(deltaTime) or 0.05, 0, 0.25)
	for _, team in ipairs(Config.TeamOrder) do
		updateCircuit(team, step, now)
	end
	-- Traps remain visually alive during Build; only damage is Battle-gated.
	for _, entry in pairs(entries) do
		if entry.Active and entry.PlacementLocked and entry.Model and entry.Model.PrimaryPart and entry.PlacementCFrame then
			local root = entry.Model.PrimaryPart
			if root.CFrame ~= entry.PlacementCFrame then
				entry.Model:PivotTo(entry.PlacementCFrame)
			end
		end
		if entry.Active and entry.IsTrap then
			entry.Model:SetAttribute("Triggered", (entry.TriggeredUntil or 0) > now)
			CombatModels.AnimateStructure(entry, now)
		end
	end
	if phaseProvider() ~= "Battle" then
		return
	end
	local destroyAfter = {}
	for _, entry in pairs(entries) do
		local definition = Config.BuildKinds[entry.Kind]
		local root = entry.Model and entry.Model.PrimaryPart
		if entry.Active and entry.IsLaneTower and definition and root then
			towerAttack(entry, definition, root, now)
		elseif entry.Active and entry.IsTrap and definition and root and now >= (entry.ArmedAt or 0) and now >= (entry.NextTrigger or 0) then
			local targets = targetsProvider(entry.Team)
			for _, model in ipairs(targets) do
				local targetRoot = model and model:FindFirstChild("HumanoidRootPart")
				local humanoid = model and model:FindFirstChildOfClass("Humanoid")
				if targetRoot and humanoid and humanoid.Health > 0 and (targetRoot.Position - root.Position).Magnitude <= definition.TriggerRadius then
					if definition.OneShot then
						for _, blastTarget in ipairs(targets) do
							local blastRoot = blastTarget and blastTarget:FindFirstChild("HumanoidRootPart")
							if blastRoot and (blastRoot.Position - root.Position).Magnitude <= (definition.BlastRadius or definition.TriggerRadius) then
								applyTrapDamage(blastTarget, definition.Damage)
							end
						end
						destroyAfter[entry] = true
					else
						applyTrapDamage(model, definition.Damage)
						entry.NextTrigger = now + definition.Cooldown
					end
					entry.TriggeredUntil = now + 0.35
					entry.Model:SetAttribute("Triggered", true)
					remotes.TrapFX:FireAllClients({ Kind = entry.Kind, Position = root.Position, Team = entry.Team })
					break
				end
			end
		end
	end
	for entry in pairs(destroyAfter) do
		removeEntry(entry)
	end
end

return FortressService
