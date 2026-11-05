-- BLOCKSIEGE // Server-authoritative seasonal presentation layer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local SeasonCatalog = require(Shared:WaitForChild("SeasonCatalog"))
local VisualModels = require(Shared:WaitForChild("VisualModels"))

local SeasonService = {}
local world
local remotes
local state
local adminService
local folder
local currentId = SeasonCatalog.Default
local revision = 0
local requestClocks = {}
local animated = {}
local clock = 0

local function part(parent, name, size, cframe, color, material, shape)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Shape = shape or Enum.PartType.Block
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = true
	object:SetAttribute("SeasonalDecor", true)
	object.Parent = parent
	return object
end

local function light(parent, color)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Brightness = 1.1
	glow.Range = 8
	glow.Parent = parent
end

local function floatPart(object, amount, speed)
	table.insert(animated, { Part = object, Base = object.CFrame, Amount = amount or 0.25, Speed = speed or 1, Phase = #animated * 0.7 })
	return object
end

local function pumpkin(parent, position, definition, scale)
	local body = part(parent, "HalloweenPumpkin", Vector3.new(3.4, 2.8, 3.1) * scale, CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)), definition.Color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(parent, "PumpkinStem", Vector3.new(0.45, 1.1, 0.45) * scale, CFrame.new(position + Vector3.new(0, 3.3 * scale, 0)), Color3.fromRGB(77, 142, 72), Enum.Material.Grass)
	for _, side in ipairs({ -1, 1 }) do
		part(parent, "PumpkinEye", Vector3.new(0.45, 0.35, 0.12) * scale, CFrame.new(position + Vector3.new(side * 0.65 * scale, 1.8 * scale, -1.45 * scale)), definition.Accent, Enum.Material.Neon)
	end
	light(body, definition.Accent)
	floatPart(body, 0.08, 1.4)
end

local function egg(parent, position, definition, scale)
	local body = part(parent, "EasterEgg", Vector3.new(2.3, 3.1, 2.3) * scale, CFrame.new(position + Vector3.new(0, 1.6 * scale, 0)), definition.Color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(parent, "EggRibbon", Vector3.new(2.1, 0.35, 2.1) * scale, CFrame.new(position + Vector3.new(0, 1.6 * scale, 0)), definition.Accent, Enum.Material.Neon, Enum.PartType.Ball)
	light(body, definition.Accent)
	floatPart(body, 0.16, 1.2)
end

local function flower(parent, position, definition, scale)
	part(parent, "SpringStem", Vector3.new(0.22, 2.4, 0.22) * scale, CFrame.new(position + Vector3.new(0, 1.2 * scale, 0)), Color3.fromRGB(83, 181, 104), Enum.Material.Grass)
	for index = 1, 5 do
		local angle = (index - 1) * math.pi * 2 / 5
		local offset = Vector3.new(math.cos(angle) * 0.7, 2.5, math.sin(angle) * 0.7) * scale
		part(parent, "SpringPetal", Vector3.new(0.85, 0.45, 0.85) * scale, CFrame.new(position + offset), definition.Color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	local center = part(parent, "SpringCenter", Vector3.one * 0.65 * scale, CFrame.new(position + Vector3.new(0, 2.5 * scale, 0)), definition.Accent, Enum.Material.Neon, Enum.PartType.Ball)
	light(center, definition.Accent)
end

local function flag(parent, position, definition, scale)
	part(parent, "DefenderPole", Vector3.new(0.22, 7, 0.22) * scale, CFrame.new(position + Vector3.new(0, 3.5 * scale, 0)), definition.Accent, Enum.Material.Metal)
	local banner = part(parent, "DefenderBanner", Vector3.new(3.4, 2.1, 0.18) * scale, CFrame.new(position + Vector3.new(1.45 * scale, 5.6 * scale, 0)), definition.Color, Enum.Material.Fabric)
	part(parent, "DefenderStar", Vector3.one * 0.8 * scale, CFrame.new(position + Vector3.new(1.45 * scale, 5.6 * scale, -0.18)), definition.Accent, Enum.Material.Neon, Enum.PartType.Ball)
	floatPart(banner, 0.12, 1.6)
end

local function buildTheme(definition)
	animated = {}
	local model = Instance.new("Model")
	model.Name = "Season_" .. definition.Id
	model:SetAttribute("SeasonId", definition.Id)
	model.Parent = folder
	local positions = {
		Vector3.new(-76, 44.5, 280), Vector3.new(76, 44.5, 380),
		Vector3.new(-150, 0, -128), Vector3.new(150, 0, 128),
		Vector3.new(-105, 0, 118), Vector3.new(105, 0, -118),
	}
	for index, position in ipairs(positions) do
		local scale = index <= 2 and 1.1 or 0.85
		if definition.Id == "NewYear" and not (world and world.WinterDecor) then
			local tree = VisualModels.ChristmasTree(model, position, scale * 0.55)
			tree:SetAttribute("SeasonalDecor", true)
		elseif definition.Id == "Halloween" then
			pumpkin(model, position, definition, scale)
		elseif definition.Id == "Defenders" then
			flag(model, position, definition, scale)
		elseif definition.Id == "WomensDay" then
			flower(model, position, definition, scale)
		elseif definition.Id == "Easter" then
			egg(model, position, definition, scale)
		end
	end
	return model
end

function SeasonService.GetSnapshot()
	local definition = SeasonCatalog.Get(currentId)
	return { Id = currentId, Name = definition.Name, Subtitle = definition.Subtitle, Color = definition.Color, Revision = revision }
end

function SeasonService.Apply(id, force)
	local definition = SeasonCatalog.Get(id)
	if not definition then
		return false
	end
	if world and world.WinterDecor then
		world.WinterDecor.Parent = id == "NewYear" and world.Root or nil
	end
	if id == currentId and not force and folder and folder:FindFirstChild("Season_" .. id) then
		return false
	end
	if folder then
		folder:ClearAllChildren()
	end
	currentId = id
	revision = revision + 1
	buildTheme(definition)
	if state then
		state:SetAttribute("SeasonId", definition.Id)
		state:SetAttribute("SeasonName", definition.Name)
		state:SetAttribute("SeasonSubtitle", definition.Subtitle)
		state:SetAttribute("SeasonColor", definition.Color)
		state:SetAttribute("SeasonRevision", revision)
	end
	if remotes then
		remotes.SeasonFX:FireAllClients(SeasonService.GetSnapshot())
	end
	return true
end

function SeasonService.HandleAdminRequest(player, id)
	if not adminService or not adminService.IsAdmin(player) then
		return false
	end
	local now = os.clock()
	if now - (requestClocks[player.UserId] or -math.huge) < 0.75 then
		return false
	end
	requestClocks[player.UserId] = now
	return SeasonService.Apply(id, false)
end

function SeasonService.OnPlayerAdded(player)
	requestClocks[player.UserId] = nil
	if remotes and player.Parent then
		remotes.SeasonFX:FireClient(player, SeasonService.GetSnapshot())
	end
end

function SeasonService.OnPlayerRemoving(player)
	requestClocks[player.UserId] = nil
end

function SeasonService.Init(dependencies)
	world = dependencies.World
	remotes = dependencies.Remotes
	state = dependencies.State
	adminService = dependencies.AdminService
	folder = Instance.new("Folder")
	folder.Name = "SeasonalDecor"
	folder.Parent = world.Root
	world.Seasonal = folder
	SeasonService.Apply(SeasonCatalog.Default, true)
end

function SeasonService.Step(deltaTime)
	clock = clock + deltaTime
	for _, item in ipairs(animated) do
		if item.Part.Parent then
			item.Part.CFrame = item.Base * CFrame.new(0, math.sin(clock * item.Speed + item.Phase) * item.Amount, 0) * CFrame.Angles(0, math.sin(clock * 0.7 + item.Phase) * 0.08, 0)
		end
	end
end

return SeasonService
