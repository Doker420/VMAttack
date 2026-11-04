-- Разрушаемые крепости, строительная сетка и серверная проверка урона.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))

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
	local entry = registerEntry(model, team, "Core", Config.Arena.CoreHealth)
	cores[team] = entry
	updateState(team)
	return entry
end

local function createStructure(team, kind, cframe)
	local definition = Config.BuildKinds[kind]
	if not definition then
		return nil
	end
	local model = Instance.new("Model")
	model.Parent = world.Structures
	local color = Config.Teams[team].Color
	local dark = Config.Teams[team].Dark
	local root = makeBlock(model, "Root", definition.Size, cframe, dark, kind == "Barricade" and Enum.Material.WoodPlanks or Enum.Material.Cobblestone, true)
	model.PrimaryPart = root
	makeBlock(model, "TeamBand", Vector3.new(definition.Size.X + 0.25, 0.8, definition.Size.Z + 0.25), cframe * CFrame.new(0, definition.Size.Y * 0.25, 0), color, Enum.Material.Metal, false)
	if kind == "Wall" or kind == "Tower" then
		for _, side in ipairs({ -1, 0, 1 }) do
			makeBlock(model, "Battlement", Vector3.new(math.max(1.5, definition.Size.X / 4), 2, definition.Size.Z), cframe * CFrame.new(side * definition.Size.X * 0.32, definition.Size.Y / 2 + 1, 0), dark, Enum.Material.Cobblestone, true)
		end
	elseif kind == "Barricade" then
		makeBlock(model, "WoodBrace", Vector3.new(1, definition.Size.Y + 1, definition.Size.Z + 0.4), cframe * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(28)), Color3.fromRGB(164, 111, 55), Enum.Material.WoodPlanks, true)
	end
	return registerEntry(model, team, kind, definition.Health)
end

local function removeEntry(entry)
	if not entry.Active then
		return
	end
	entry.Active = false
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
end

function FortressService.Reset()
	FortressService.Clear()
	for _, team in ipairs(Config.TeamOrder) do
		createCore(team)
		local baseCFrame = Config.BaseCFrame(team)
		for index = 1, 4 do
			createStructure(team, "Wall", baseCFrame * CFrame.new((index - 2.5) * 14, 6, -28))
		end
		for _, side in ipairs({ -1, 1 }) do
			createStructure(team, "Barricade", baseCFrame * CFrame.new(side * 42, 2.5, 4) * CFrame.Angles(0, math.rad(90), 0))
		end
	end
end

local function validPosition(position)
	return typeof(position) == vector3Type and position.X == position.X and position.Y == position.Y and position.Z == position.Z
		and math.abs(position.X) < 10000 and math.abs(position.Y) < 10000 and math.abs(position.Z) < 10000
end

local function placement(team, kind, position)
	local definition = Config.BuildKinds[kind]
	if not definition or not validPosition(position) then
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
	return baseCFrame * CFrame.new(x, definition.Size.Y / 2, z)
end

function FortressService.GetPlayerPlacement(player, team, kind, position)
	if phaseProvider() ~= "Build" then
		return nil, "Строительство уже закончено"
	end
	if not validPosition(position) then
		return nil, "Неверная позиция"
	end
	if not Config.Teams[team] then
		return nil, "Вы не участвуете в матче"
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
	return placement(team, kind, position)
end

function FortressService.BuildPlayer(player, team, kind, position)
	local cframe, reason = FortressService.GetPlayerPlacement(player, team, kind, position)
	if not cframe then
		return false, reason
	end
	local entry = createStructure(team, kind, cframe)
	local count = (buildCounts[player.UserId] or 0) + 1
	buildCounts[player.UserId] = count
	local capacity = buildCapacityProvider(player)
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
			createStructure(team, kind, cframe)
			return true
		end
	end
	return false
end

function FortressService.DamagePart(part, amount, attackingTeam, player)
	if phaseProvider() ~= "Battle" or not part or not Config.Teams[attackingTeam] then
		return 0
	end
	local entry = partIndex[part]
	if not entry or not entry.Active or entry.Team == attackingTeam then
		return 0
	end
	local applied = math.min(entry.Health, math.max(0, amount))
	if applied <= 0 then
		return 0
	end
	entry.Health = entry.Health - applied
	entry.Model:SetAttribute("Health", entry.Health)
	if player and damageHandler then
		damageHandler(player, applied, entry.Kind)
	end
	remotes.CombatFX:FireAllClients({ Kind = "StructureHit", Position = part.Position, Team = entry.Team })
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

return FortressService
