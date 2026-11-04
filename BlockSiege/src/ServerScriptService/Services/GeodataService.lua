-- Lightweight server geodata: static collision geometry + live fortress/trap obstacles.
-- PathfindingService remains the final navmesh solver; this map gives bots tactical obstacle context.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BlockSiege"):WaitForChild("Config"))

local GeodataService = {}
local world
local fortressService
local state
local staticObstacles = {}
local obstacles = {}
local refreshClock = 0
local revision = 0

local ignoredNames = {
	ArenaDirt = true,
	ArenaGrass = true,
	CenterLane = true,
	SideLane = true,
	BlueBasePlatform = true,
	OrangeBasePlatform = true,
	BlueBaseGrass = true,
	OrangeBaseGrass = true,
	BlueSpawn = true,
	OrangeSpawn = true,
	ArenaBoundary = true,
}

local function addPart(list, part, source, team, kind)
	if not part or not part:IsA("BasePart") or part.CanCollide == false then
		return
	end
	table.insert(list, {
		Part = part,
		Position = part.Position,
		Size = part.Size,
		Source = source,
		Team = team,
		Kind = kind,
	})
end

local function collectStatic()
	staticObstacles = {}
	if not world or not world.Arena then
		return
	end
	for _, part in ipairs(world.Arena:GetDescendants()) do
		if part:IsA("BasePart") and not ignoredNames[part.Name] and not string.find(part.Name, "BasePlatform", 1, true) and not string.find(part.Name, "BaseGrass", 1, true) and not string.find(part.Name, "ExitStep", 1, true) then
			addPart(staticObstacles, part, "Static")
		end
	end
end

function GeodataService.Init(dependencies)
	world = dependencies.World
	fortressService = dependencies.FortressService
	state = dependencies.State
	collectStatic()
	GeodataService.Refresh()
end

function GeodataService.Refresh()
	obstacles = {}
	for _, obstacle in ipairs(staticObstacles) do
		table.insert(obstacles, obstacle)
	end
	if fortressService then
		for _, entry in ipairs(fortressService.GetEntries()) do
			for _, part in ipairs(entry.Parts) do
				addPart(obstacles, part, "Structure", entry.Team, entry.Kind)
			end
		end
	end
	revision = revision + 1
	if state then
		state:SetAttribute("GeodataObstacles", #obstacles)
		state:SetAttribute("GeodataRevision", revision)
	end
end

function GeodataService.Step(deltaTime)
	refreshClock = refreshClock + deltaTime
	if refreshClock >= 0.4 then
		refreshClock = 0
		GeodataService.Refresh()
	end
end

function GeodataService.GetObstacles()
	return obstacles
end

function GeodataService.GetObstacleCount()
	return #obstacles
end

function GeodataService.GetNearestObstacle(position, maximumDistance)
	local best
	local bestDistance = maximumDistance or math.huge
	for _, obstacle in ipairs(obstacles) do
		local radius = math.max(obstacle.Size.X, obstacle.Size.Z) * 0.5
		local distance = (obstacle.Position - position).Magnitude - radius
		if distance < bestDistance then
			best = obstacle
			bestDistance = distance
		end
	end
	return best, bestDistance
end

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Return a side waypoint when a registered obstacle intersects the direct route.
function GeodataService.GetAvoidancePoint(start, destination, side)
	local delta = horizontal(destination - start)
	local length = delta.Magnitude
	if length < 14 then
		return nil
	end
	local direction = delta.Unit
	local best
	local bestDistance = math.huge
	for _, obstacle in ipairs(obstacles) do
		local relative = horizontal(obstacle.Position - start)
		local projection = relative:Dot(direction)
		if projection > 4 and projection < length - 4 then
			local closest = start + direction * projection
			local lateral = horizontal(obstacle.Position - closest).Magnitude
			local radius = math.max(obstacle.Size.X, obstacle.Size.Z) * 0.5
			if lateral < radius + 4 and lateral < bestDistance and obstacle.Position.Y < start.Y + 14 then
				best = obstacle
				bestDistance = lateral
			end
		end
	end
	if not best then
		return nil
	end
	local radius = math.max(best.Size.X, best.Size.Z) * 0.5
	local sign = (side or 1) % 2 == 0 and 1 or -1
	local perpendicular = Vector3.new(-direction.Z, 0, direction.X) * sign
	local candidate = best.Position + perpendicular * (radius + 8)
	if math.abs(candidate.X) > Config.Arena.BotBoundsX or math.abs(candidate.Z) > Config.Arena.BotBoundsZ then
		candidate = best.Position - perpendicular * (radius + 8)
	end
	if math.abs(candidate.X) > Config.Arena.BotBoundsX or math.abs(candidate.Z) > Config.Arena.BotBoundsZ then
		return nil
	end
	return Vector3.new(candidate.X, destination.Y, candidate.Z)
end

return GeodataService
