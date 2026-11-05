-- Tactical bots: role-based construction, defense, assault, support and obstacle-aware pathing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local pathfindingOk, PathfindingService = pcall(function()
	return game:GetService("PathfindingService")
end)
if not pathfindingOk then
	PathfindingService = nil
end

local BotService = {}
local world
local fortressService
local weaponService
local geodataService
local abilityService
local squadLevelProvider = function()
	return 1
end
local phaseProvider = function()
	return "Lobby"
end
local targetsProvider = function()
	return {}
end
local bots = {}
local active = false
local matchId = 0
local nextBotId = 0

local botWeapons = { "Carbine", "SMG", "Scatter", "Marksman", "Demolisher", "Vortex", "ThanosGauntlet", "TacticalKnife", "ShadowKnives", "PrismLance", "TeslaCarbine", "MeteorMaul", "VoidScythe" }
local roles = { "Assault", "Assault", "Support", "Defender", "Assault", "Support" }
-- Bots cross the expanded 640-stud arena decisively, while defenders retain
-- a little more restraint. Lane offsets are shared with WorldBuilder/Fortress.
local BOT_SPEEDS = { Assault = 30, Support = 27, Defender = 24 }
local BOT_LANES = Config.Objectives.Lanes
local botSkins = {
	{ Id = "Scout", Name = "SCOUT", Primary = Color3.fromRGB(66, 168, 164), Secondary = Color3.fromRGB(35, 74, 83), Accent = Color3.fromRGB(156, 255, 224), Head = Color3.fromRGB(224, 190, 145) },
	{ Id = "Heavy", Name = "HEAVY", Primary = Color3.fromRGB(128,  90, 76), Secondary = Color3.fromRGB(62, 53, 55), Accent = Color3.fromRGB(255, 190,  70), Head = Color3.fromRGB(193, 153, 119) },
	{ Id = "Medic", Name = "MEDIC", Primary = Color3.fromRGB(213, 231, 218), Secondary = Color3.fromRGB( 70, 130, 111), Accent = Color3.fromRGB( 90, 255, 164), Head = Color3.fromRGB(235, 198, 160) },
	{ Id = "Ranger", Name = "RANGER", Primary = Color3.fromRGB(104, 128, 77), Secondary = Color3.fromRGB(49, 65, 45), Accent = Color3.fromRGB(215, 194, 104), Head = Color3.fromRGB(204, 165, 126) },
	{ Id = "Engineer", Name = "ENGINEER", Primary = Color3.fromRGB(211, 139, 49), Secondary = Color3.fromRGB(83,  60, 42), Accent = Color3.fromRGB(255, 222,  90), Head = Color3.fromRGB(224, 190, 145) },
	{ Id = "Shadow", Name = "SHADOW", Primary = Color3.fromRGB(77, 66, 112), Secondary = Color3.fromRGB(32,  30, 52), Accent = Color3.fromRGB(201, 127, 255), Head = Color3.fromRGB(177, 143, 126) },
}

local BOT_TEXTURES = {
	Torso = "rbxassetid://9920517696",
	Backpack = "rbxassetid://9920517696",
	ChestPlate = "rbxassetid://9920574687",
	Helmet = "rbxassetid://9920574687",
	LeftShoulder = "rbxassetid://9920574687",
	RightShoulder = "rbxassetid://9920574687",
	HardHat = "rbxassetid://9920574687",
}

local function addBotTexture(part, name)
	local asset = BOT_TEXTURES[name]
	if not asset then
		return
	end
	local texture = Instance.new("Texture")
	texture.Name = "BotSurfaceTexture"
	texture.Texture = asset
	texture.Face = Enum.NormalId.Front
	texture.StudsPerTileU = 2
	texture.StudsPerTileV = 2
	texture.Transparency = 0.12
	texture.Parent = part
	part:SetAttribute("SurfaceTextured", true)
end

local function bodyPart(model, root, name, size, offset, color, jointParent, jointName, jointC0)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.Color = color
	part.Material = (name == "Torso" or name == "Backpack") and Enum.Material.Fabric or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = name == "Torso" or name == "Left Leg" or name == "Right Leg"
	part.CanTouch = false
	part.CanQuery = true
	part.Massless = name ~= "Torso"
	part.Parent = model
	addBotTexture(part, name)

	-- Humanoid navigation expects a real character assembly, not a collection of
	-- welded props. C0 preserves the authored pose while Motor6D supplies the rig.
	local joint = Instance.new("Motor6D")
	joint.Name = jointName or (name .. "Joint")
	joint.Part0 = jointParent or root
	joint.Part1 = part
	joint.C0 = jointC0 or CFrame.new(offset)
	joint.C1 = CFrame.new()
	joint.Parent = part
	return part
end

local function addNameTag(head, entry)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BotTag"
	gui.Size = UDim2.fromOffset(210, 54)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.65)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s BOT %02d", string.upper(entry.Team), entry.Slot)
	label.TextColor3 = Config.Teams[entry.Team].Color
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Parent = gui
	local role = Instance.new("TextLabel")
	role.Name = "Role"
	role.Position = UDim2.fromScale(0, 0.65)
	role.Size = UDim2.fromScale(1, 0.35)
	role.BackgroundTransparency = 1
	role.Font = Enum.Font.Gotham
	role.Text = (entry.Role == "Defender" and "DEFENSE" or (entry.Role == "Support" and "SUPPORT" or "ASSAULT")) .. " · " .. entry.Skin.Name
	role.TextColor3 = Color3.fromRGB(235, 240, 235)
	role.TextStrokeTransparency = 0.4
	role.TextScaled = true
	role.Parent = gui
end

local function resetPath(entry)
	entry.Path = nil
	entry.PathIndex = 1
	entry.PathGoal = nil
	entry.NavigationGoal = nil
	entry.NextPath = 0
end

local function spawnModel(entry)
	local spawn = world.TeamSpawns[entry.Team] * CFrame.new((entry.Slot - 3.5) * 3, 0, 0)
	-- TeamSpawns includes clearance for a player character. This custom R6 rig's
	-- feet sit 2.8 studs below its root, so start close to the spawn pad instead
	-- of dropping the assembly from the player spawn height.
	spawn = spawn * CFrame.new(0, -3.25, 0)
	local model = Instance.new("Model")
	model.Name = "Bot_" .. entry.Id
	model:SetAttribute("Team", entry.Team)
	model:SetAttribute("BotId", entry.Id)
	model:SetAttribute("IsBot", true)
	model:SetAttribute("Role", entry.Role)
	model:SetAttribute("SkinId", entry.Skin.Id)
	model:SetAttribute("Level", 1)
	model:SetAttribute("Armor", 0)
	model.Parent = world.Bots
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 4.5, 3)
	root.CFrame = spawn
	root.Transparency = 1
	root.Anchored = false
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root
	local teamColor = Config.Teams[entry.Team].Color
	local skin = entry.Skin
	local torso = bodyPart(model, root, "Torso", Vector3.new(3, 2.2, 1.8), Vector3.new(0, 0.3, 0), skin.Primary, root, "RootJoint", CFrame.new(0, 0.3, 0))
	bodyPart(model, root, "ChestPlate", Vector3.new(2.2, 1.1, 0.35), Vector3.new(0, 0.55, -1.05), skin.Accent)
	bodyPart(model, root, "TeamBand", Vector3.new(3.1, 0.35, 1.9), Vector3.new(0, 1.15, 0), teamColor)
	local head = bodyPart(model, root, "Head", Vector3.new(2.1, 1.8, 2.1), Vector3.new(0, 2.5, 0), skin.Head, torso, "Neck", CFrame.new(0, 2.2, 0))
	bodyPart(model, root, "Helmet", Vector3.new(2.35, 0.65, 2.35), Vector3.new(0, 3.45, 0), skin.Secondary)
	bodyPart(model, root, "Visor", Vector3.new(1.7, 0.35, 0.25), Vector3.new(0, 2.65, -1.1), skin.Accent)
	bodyPart(model, root, "Backpack", Vector3.new(1.8, 2, 0.7), Vector3.new(0, 0.45, 1.15), skin.Secondary)
	bodyPart(model, root, "Left Arm", Vector3.new(1, 2.4, 1.4), Vector3.new(-2, 0.3, 0), skin.Primary, torso, "Left Shoulder", CFrame.new(-2, 0, 0))
	bodyPart(model, root, "Right Arm", Vector3.new(1, 2.4, 1.4), Vector3.new(2, 0.3, 0), skin.Primary, torso, "Right Shoulder", CFrame.new(2, 0, 0))
	bodyPart(model, root, "Left Leg", Vector3.new(1.2, 2, 1.5), Vector3.new(-0.8, -1.8, 0), skin.Secondary, torso, "Left Hip", CFrame.new(-0.8, -2.1, 0))
	bodyPart(model, root, "Right Leg", Vector3.new(1.2, 2, 1.5), Vector3.new(0.8, -1.8, 0), skin.Secondary, torso, "Right Hip", CFrame.new(0.8, -2.1, 0))
	if skin.Id == "Heavy" then
		bodyPart(model, root, "LeftShoulder", Vector3.new(1.4, 0.7, 1.7), Vector3.new(-2, 1.35, 0), skin.Accent)
		bodyPart(model, root, "RightShoulder", Vector3.new(1.4, 0.7, 1.7), Vector3.new(2, 1.35, 0), skin.Accent)
	elseif skin.Id == "Medic" then
		bodyPart(model, root, "MedicCross", Vector3.new(0.35, 1.1, 0.15), Vector3.new(0, 0.55, -1.25), Color3.fromRGB(255, 90, 95))
		bodyPart(model, root, "MedicCross", Vector3.new(1.1, 0.35, 0.15), Vector3.new(0, 0.55, -1.25), Color3.fromRGB(255, 90, 95))
	elseif skin.Id == "Engineer" then
		bodyPart(model, root, "HardHat", Vector3.new(2.6, 0.35, 2.6), Vector3.new(0, 3.85, 0), Color3.fromRGB(255, 211, 65))
	end
	addNameTag(head, entry)
	local tacticalLight = Instance.new("SpotLight")
	tacticalLight.Name = "BlockSiegeTacticalLight"
	tacticalLight.Color = Color3.fromRGB(185, 220, 255)
	tacticalLight.Face = Enum.NormalId.Front
	tacticalLight.Angle = 64
	tacticalLight.Range = 26
	tacticalLight.Brightness = 0.8
	tacticalLight.Shadows = false
	tacticalLight.Enabled = phaseProvider() ~= "Build"
	tacticalLight.Parent = root

	-- Parent Humanoid only after the complete rig exists; otherwise it can die while
	-- the model is still being assembled and never receive MoveTo commands.
	local squadLevel = math.clamp(tonumber(entry.SquadLevel) or 1, 1, 10)
	local squadHealth = 120 + (squadLevel - 1) * 4
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = squadHealth
	humanoid.Health = squadHealth
	humanoid.WalkSpeed = (BOT_SPEEDS[entry.Role] or 24) + math.min(2, (squadLevel - 1) * 0.25)
	humanoid.JumpPower = 50
	humanoid.HipHeight = 0
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.AutoRotate = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.Parent = model
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	-- RootPart is read-only in current Roblox runtime. The correctly named
	-- HumanoidRootPart and Motor6D RootJoint let Humanoid resolve it automatically.
	model:SetAttribute("Rig", "Motor6D")
	model:SetAttribute("SquadLevel", squadLevel)
	-- Set ownership after every joint/part exists so the complete assembly stays
	-- server-simulated even when a player is standing next to the bot.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	entry.Model = model
	entry.Humanoid = humanoid
	entry.LastPosition = root.Position
	entry.StuckTime = 0
	entry.LaneOffset = 0
	entry.NextJump = 0
	entry.Target = nil
	entry.LastHeal = 0
	entry.Retreating = false
	entry.NextRecover = 0
	entry.BattleStarted = nil
	entry.NextAbility = os.clock() + 2 + entry.Slot * 0.2
	resetPath(entry)
	if abilityService then
		entry.ClassId = abilityService.RegisterBot(model, entry.Team)
		local tag = head:FindFirstChild("BotTag")
		local roleLabel = tag and tag:FindFirstChild("Role")
		if roleLabel and entry.ClassId then
			roleLabel.Text = (entry.Role == "Defender" and "DEFENSE" or (entry.Role == "Support" and "SUPPORT" or "ASSAULT")) .. " · " .. string.upper(entry.ClassId)
		end
	end
	weaponService.EquipCharacter(model, entry.WeaponId)
	entry.Animations = {}
	for _, joint in ipairs(model:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part1 then
			table.insert(entry.Animations, { Joint = joint, Name = joint.Part1.Name, C0 = joint.C0 })
		end
	end
	local spawnMatch = entry.MatchId
	humanoid.Died:Connect(function()
		resetPath(entry)
		task.delay(2, function()
			if entry.Model == model then
				model:Destroy()
			end
		end)
		task.delay(Config.RespawnDuration, function()
			if active and entry.MatchId == spawnMatch and matchId == spawnMatch and (phaseProvider() == "Battle" or phaseProvider() == "Build") then
				spawnModel(entry)
			end
		end)
	end)
	return model
end

local function addBot(team, slot)
	nextBotId = nextBotId + 1
	local entry = {
		Id = nextBotId,
		Team = team,
		Slot = slot,
		Role = roles[((slot - 1) % #roles) + 1],
		Skin = botSkins[((nextBotId - 1) % #botSkins) + 1],
		WeaponId = botWeapons[((nextBotId - 1) % #botWeapons) + 1],
		MatchId = matchId,
		SquadLevel = math.clamp(tonumber(squadLevelProvider(team)) or 1, 1, 10),
		Builds = 0,
		NextBuild = os.clock() + 1 + slot * 0.15,
		NextThink = 0,
	}
	bots[entry.Id] = entry
	spawnModel(entry)
	return entry
end

function BotService.Init(dependencies)
	world = dependencies.World
	fortressService = dependencies.FortressService
	weaponService = dependencies.WeaponService
	geodataService = dependencies.GeodataService
	abilityService = dependencies.AbilityService
	squadLevelProvider = dependencies.SquadLevelProvider or squadLevelProvider
end

function BotService.SetProviders(phase, targets)
	phaseProvider = phase
	targetsProvider = targets
end

function BotService.Start(newMatchId, participants)
	BotService.Stop()
	matchId = newMatchId
	active = true
	local humanCounts = { Blue = 0, Orange = 0 }
	for _, team in pairs(participants) do
		if humanCounts[team] then
			humanCounts[team] = humanCounts[team] + 1
		end
	end
	for _, team in ipairs(Config.TeamOrder) do
		local needed = Config.TeamSize - humanCounts[team]
		for index = 1, needed do
			addBot(team, humanCounts[team] + index)
		end
	end
end

function BotService.AddBot(team)
	if not active then
		return nil
	end
	local used = {}
	for _, entry in pairs(bots) do
		if entry.Team == team then
			used[entry.Slot] = true
		end
	end
	for slot = 1, Config.TeamSize do
		if not used[slot] then
			return addBot(team, slot)
		end
	end
	return nil
end

function BotService.Stop()
	active = false
	for _, entry in pairs(bots) do
		if entry.Model then
			entry.Model:Destroy()
		end
	end
	bots = {}
end

function BotService.Count(team)
	local count = 0
	for _, entry in pairs(bots) do
		if entry.Team == team and entry.Model and entry.Model.Parent then
			count = count + 1
		end
	end
	return count
end

function BotService.GetModels(team)
	local result = {}
	for _, entry in pairs(bots) do
		local humanoid = entry.Model and entry.Model:FindFirstChildOfClass("Humanoid")
		if entry.Team == team and entry.Model and entry.Model.Parent and humanoid and humanoid.Health > 0 then
			table.insert(result, entry.Model)
		end
	end
	return result
end

local function modelPosition(model)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function nearestEnemy(entry, position)
	local best
	local bestDistance = math.huge
	local bestScore = math.huge
	for _, model in ipairs(targetsProvider(entry.Team)) do
		local root = model and model:FindFirstChild("HumanoidRootPart")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			-- Prefer a nearby threat, but switch to a wounded target when it is a better tactical choice.
			local healthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth)
			local score = distance + healthRatio * 18
			if model == entry.Target then
				score = score - 8
			end
			if score < bestScore then
				best = model
				bestDistance = distance
				bestScore = score
			end
		end
	end
	return best, bestDistance
end

local function basePoint(team, localX, localZ)
	return (Config.BaseCFrame(team) * CFrame.new(localX or 0, 0, localZ or 16)).Position
end

local function laneForSlot(slot)
	return BOT_LANES[((slot - 1) % #BOT_LANES) + 1]
end

local function laneForEntry(entry)
	local index = (entry.Slot - 1 + (entry.LaneOffset or 0)) % #BOT_LANES
	return BOT_LANES[index + 1]
end

local function exitPoint(team, slot, lane)
	-- BaseCFrame looks at the enemy with -Z. The initial wall line is at -28;
	-- this point is beyond it, on a side lane with enough room for an R6 agent.
	return basePoint(team, lane or laneForSlot(slot), -54)
end

local function enemyAttackPoint(team)
	-- CorePedestal reaches local Z=-9; with an R6 agent radius the safe
	-- approach must be farther out than the heart itself. -17 leaves room for
	-- the whole rig while remaining close enough for a melee ray.
	return basePoint(Config.OtherTeam(team), 0, -17)
end

local function enemyAimPoint(team)
	-- Aim at the lower front of CoreHeart (front=-5), above the pedestal's
	-- top edge. The ray remains inside Tactical Knife's 14-stud range and still
	-- hits the heart after the pedestal has been destroyed.
	return basePoint(Config.OtherTeam(team), 0, -5) + Vector3.new(0, 2, 0)
end

local function insideOwnBase(entry, position)
	local localPosition = Config.BaseCFrame(entry.Team):PointToObjectSpace(position)
	return math.abs(localPosition.X) < 62 and localPosition.Z > -48 and localPosition.Z < 70
end

local function routeToDestination(entry, destination)
	-- Only use the exit leg when the tactical target is actually outside. A
	-- defender chasing an intruder inside its own base must not turn around.
	return insideOwnBase(entry, destination) and "Direct" or "Field"
end

local function computePath(entry, destination, now)
	if not PathfindingService or not entry.Model or not entry.Model.PrimaryPart then
		return nil
	end
	local ok, path = pcall(function()
		return PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 6,
			AgentCanJump = true,
			WaypointSpacing = 8,
			Costs = { Water = 20 },
		})
	end)
	if not ok or not path then
		return nil
	end
	local computed = pcall(function()
		path:ComputeAsync(entry.Model.PrimaryPart.Position, destination)
	end)
	if not computed then
		return nil
	end
	local gotWaypoints, waypoints = pcall(function()
		return path:GetWaypoints()
	end)
	if gotWaypoints and waypoints and #waypoints > 0 then
		return waypoints
	end
	return nil
end

local function jumpForObstacle(entry, root, humanoid, now)
	if type(Workspace.Raycast) ~= "function" then
		return
	end
	if now < (entry.NextJump or 0) then
		return
	end
	local origin = root.Position + Vector3.new(0, 0.5, 0)
	local direction = root.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entry.Model }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(origin, direction * 6, params)
	if hit and hit.Instance and hit.Instance.CanCollide ~= false then
		-- A jump is allowed only after a real collision/path obstacle, never merely because a bot is stuck.
		humanoid.Jump = true
		entry.NextJump = now + 1.5
	end
end

local function followDestination(entry, destination, now, route)
	local root = entry.Model and entry.Model:FindFirstChild("HumanoidRootPart")
	local humanoid = entry.Humanoid
	if not root or not humanoid then
		return
	end
	route = route or "Direct"
	local goalChanged = not entry.PathGoal or (entry.PathGoal - destination).Magnitude > 10
	local routeDestination = destination

	-- A direct MoveTo(CoreHeart.Position) is a reliable way to make a bot push
	-- against a wall forever: the requested endpoint is inside solid geometry.
	-- Use explicit tactical legs instead. The first leg always gets the bot out
	-- through a side lane; assaults then stage outside the enemy wall before
	-- approaching the attack point. No teleporting and no jump spam is involved.
	if route == "Assault" then
		if insideOwnBase(entry, root.Position) then
			routeDestination = exitPoint(entry.Team, entry.Slot, laneForEntry(entry))
		else
			local enemyTeam = Config.OtherTeam(entry.Team)
			local approach = basePoint(enemyTeam, laneForEntry(entry), -54)
			local enemyLocal = Config.BaseCFrame(enemyTeam):PointToObjectSpace(root.Position)
			if (root.Position - approach).Magnitude > 12 and enemyLocal.Z < -44 then
				routeDestination = approach
			end
		end
	elseif route == "Return" and not insideOwnBase(entry, root.Position) then
		local approach = exitPoint(entry.Team, entry.Slot, laneForEntry(entry))
		if (root.Position - approach).Magnitude > 12 then
			routeDestination = approach
		end
	elseif route == "Field" and insideOwnBase(entry, root.Position) then
		routeDestination = exitPoint(entry.Team, entry.Slot, laneForEntry(entry))
	end

	local navigationChanged = not entry.NavigationGoal or (entry.NavigationGoal - routeDestination).Magnitude > 6
	if goalChanged or navigationChanged or now >= (entry.NextPath or 0) then
		local pathDestination = routeDestination
		if geodataService then
			local avoidance = geodataService.GetAvoidancePoint(root.Position, routeDestination, entry.Slot)
			if avoidance and (avoidance - root.Position).Magnitude > 5 and (avoidance - routeDestination).Magnitude > 5 then
				pathDestination = avoidance
			end
		end
		entry.Path = computePath(entry, pathDestination, now)
		entry.PathIndex = 1
		entry.PathGoal = destination
		entry.NavigationGoal = routeDestination
		entry.NextPath = now + 1.8
	end
	local waypoints = entry.Path
	if waypoints and #waypoints > 0 then
		local waypoint = waypoints[entry.PathIndex]
		while waypoint and (waypoint.Position - root.Position).Magnitude < 4 do
			entry.PathIndex = entry.PathIndex + 1
			waypoint = waypoints[entry.PathIndex]
		end
		if waypoint then
			humanoid:MoveTo(waypoint.Position)
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				if now >= (entry.NextJump or 0) then
					humanoid.Jump = true
					entry.NextJump = now + 1.5
				end
			else
				jumpForObstacle(entry, root, humanoid, now)
			end
			return
		end
	end
	humanoid:MoveTo(routeDestination)
	jumpForObstacle(entry, root, humanoid, now)
end

local function supportHeal(entry, now)
	if entry.Role ~= "Support" or now - (entry.LastHeal or 0) < 2 then
		return
	end
	local root = entry.Model and entry.Model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, ally in ipairs(BotService.GetModels(entry.Team)) do
		if ally ~= entry.Model then
			local allyRoot = ally:FindFirstChild("HumanoidRootPart")
			local humanoid = ally:FindFirstChildOfClass("Humanoid")
			if allyRoot and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth and (allyRoot.Position - root.Position).Magnitude < 24 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 8 + ((entry.SquadLevel or 1) - 1) * 0.5)
				entry.LastHeal = now
				return
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Team") == entry.Team then
			local ally = player.Character
			local allyRoot = ally and ally:FindFirstChild("HumanoidRootPart")
			local humanoid = ally and ally:FindFirstChildOfClass("Humanoid")
			if allyRoot and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth and (allyRoot.Position - root.Position).Magnitude < 24 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 8 + ((entry.SquadLevel or 1) - 1) * 0.5)
				entry.LastHeal = now
				return
			end
		end
	end
end

local function battleThink(entry, now)
	local model = entry.Model
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local humanoid = entry.Humanoid
	local weapon = Catalog.GetWeapon(entry.WeaponId)
	if not root or not humanoid or not weapon then
		return
	end
	local position = root.Position
	local ownCore = fortressService.GetCorePosition(entry.Team)
	local enemyCore = fortressService.GetCorePosition(Config.OtherTeam(entry.Team))
	local enemy, enemyDistance = nearestEnemy(entry, position)
	entry.Target = enemy
	entry.BattleStarted = entry.BattleStarted or now

	local healthRatio = humanoid.Health / math.max(1, humanoid.MaxHealth)
	if entry.Retreating then
		if healthRatio >= 0.68 then
			entry.Retreating = false
			resetPath(entry)
		end
	elseif healthRatio <= 0.28 then
		entry.Retreating = true
		resetPath(entry)
	end
	local retreating = entry.Retreating == true
	local destination = enemyAttackPoint(entry.Team)
	local route = "Assault"
	local targetPosition = enemyAimPoint(entry.Team)
	local shouldFire = true
	local action = "ATTACK CORE"

	if retreating then
		action = "RECOVER"
		destination = basePoint(entry.Team, laneForSlot(entry.Slot), 18)
		route = "Return"
		targetPosition = enemy and modelPosition(enemy) or enemyAimPoint(entry.Team)
		shouldFire = enemy ~= nil and enemyDistance < weapon.Range * 0.8
	elseif entry.Role == "Defender" then
		local threatDistance = enemy and (modelPosition(enemy) - ownCore).Magnitude or math.huge
		local joinedAssault = now - (entry.BattleStarted or now) >= 35
		if enemy and (threatDistance < 115 or enemyDistance < 60) then
			action = "ENGAGE"
			targetPosition = modelPosition(enemy) + Vector3.new(0, 1.5, 0)
			destination = targetPosition
			route = routeToDestination(entry, destination)
		elseif joinedAssault then
			-- Defense has a timed purpose; it is not permission to remain on the
			-- spawn pad for the entire round. A safe core releases the defender.
			action = "ATTACK CORE"
		else
			action = "FORWARD DEFENSE"
			destination = basePoint(entry.Team, laneForSlot(entry.Slot), -34)
			route = "Direct"
			targetPosition = enemyAimPoint(entry.Team)
			shouldFire = (enemyCore - position).Magnitude < weapon.Range * 0.8
		end
	elseif entry.Role == "Support" then
		if enemy and enemyDistance < 100 then
			action = "ENGAGE + SUPPORT"
			targetPosition = modelPosition(enemy) + Vector3.new(0, 1.5, 0)
			destination = targetPosition
			route = routeToDestination(entry, destination)
		else
			-- Support advances with the attack and heals on the way. Capture 67
			-- remains incidental; it must not cancel the team's core assault.
			action = "ATTACK + SUPPORT"
		end
	else
		if enemy and enemyDistance < 72 then
			action = "ENGAGE"
			targetPosition = modelPosition(enemy) + Vector3.new(0, 1.5, 0)
			destination = targetPosition
			route = routeToDestination(entry, destination)
		end
	end

	local distance = (targetPosition - position).Magnitude
	local destinationDistance = (destination - position).Magnitude
	local moving = distance > weapon.Range * 0.55
	if retreating or not shouldFire then
		moving = destinationDistance > 6
	end
	-- Range is never an excuse to keep firing from inside the spawn/base.
	if route == "Assault" and insideOwnBase(entry, position) and destinationDistance > 8 then
		moving = true
	end
	if moving then
		followDestination(entry, destination, now, route)
	else
		humanoid:MoveTo(position)
	end
	if shouldFire and distance <= weapon.Range * 0.95 then
		weaponService.FireBot(model, entry.WeaponId, targetPosition)
	end
	if abilityService and now >= (entry.NextAbility or 0) then
		entry.NextAbility = now + 2.8 + (entry.Slot % 3) * 0.3
		abilityService.UseBotAbility(model, targetPosition)
	end
	supportHeal(entry, now)

	-- A custom bot Humanoid has no default player CharacterHealth script. Limited
	-- recovery at its own base closes the old permanent-retreat state and sends
	-- the bot back once the 68% hysteresis threshold is reached.
	if retreating and insideOwnBase(entry, position) and now >= (entry.NextRecover or 0) then
		entry.NextRecover = now + 0.75
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 5)
	end

	model:SetAttribute("AIState", action)
	model:SetAttribute("AITarget", enemy and enemy.Name or "CORE")
	model:SetAttribute("AIDestination", destination)
	model:SetAttribute("AIShouldFire", shouldFire)
	if moving and entry.LastPosition and (position - entry.LastPosition).Magnitude < 0.35 and destinationDistance > 20 then
		entry.StuckTime = entry.StuckTime + 0.25
		if entry.StuckTime > 1.2 then
			entry.LaneOffset = (entry.LaneOffset or 0) + 1
			resetPath(entry)
			entry.StuckTime = 0
		end
	else
		entry.StuckTime = 0
	end
	model:SetAttribute("AIStuckTime", entry.StuckTime)
	entry.LastPosition = position
end

local function animateBot(entry, now)
	local root = entry.Model and entry.Model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local velocity = root.AssemblyLinearVelocity or Vector3.zero
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local stride = math.clamp(speed / 24, 0, 1)
	local cycle = now * (5 + stride * 4) + entry.Slot * 0.7
	for _, animation in ipairs(entry.Animations or {}) do
		if animation.Joint.Parent then
			local swing = 0
			if animation.Name == "Left Leg" or animation.Name == "Right Arm" then
				swing = math.sin(cycle) * 0.52 * stride
			elseif animation.Name == "Right Leg" or animation.Name == "Left Arm" then
				swing = -math.sin(cycle) * 0.52 * stride
			end
			if animation.Name == "Head" then
				animation.Joint.C0 = animation.C0 * CFrame.Angles(0, math.sin(now * 0.8 + entry.Slot) * 0.08, 0)
			else
				animation.Joint.C0 = animation.C0 * CFrame.Angles(swing, 0, 0)
			end
		end
	end
end

function BotService.Step(deltaTime)
	if not active then
		return
	end
	local phase = phaseProvider()
	local now = os.clock()
	for _, entry in pairs(bots) do
		local model = entry.Model
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if model and model.Parent and humanoid and humanoid.Health > 0 and root then
			animateBot(entry, now)
			entry.Humanoid = humanoid
			-- Humanoid initialization and external slows must not silently restore
			-- the old 16–20 speeds; fast crossing is part of the bot role behavior.
			humanoid.WalkSpeed = (BOT_SPEEDS[entry.Role] or 24) + math.min(2, ((entry.SquadLevel or 1) - 1) * 0.25) + (tonumber(model:GetAttribute("AbilitySpeedBonus")) or 0)
			if phase == "Build" then
				if entry.Builds < Config.Arena.BotBuildsPerBot and now >= entry.NextBuild then
					local built = fortressService.BuildBot(entry.Team, entry.Slot, entry.Builds + 1)
					if built then
						entry.Builds = entry.Builds + 1
					end
					entry.NextBuild = now + 2.2
				end
				if entry.Builds < Config.Arena.BotBuildsPerBot then
					local pad = basePoint(entry.Team, (entry.Slot - 3.5) * 7, 20)
					followDestination(entry, pad, now, "Direct")
				elseif entry.Role == "Defender" then
					followDestination(entry, basePoint(entry.Team, laneForSlot(entry.Slot), 20), now, "Direct")
				else
					-- Construction is still protected, but finished attackers gather
					-- near the front instead of standing frozen on the spawn pad.
					followDestination(entry, basePoint(entry.Team, laneForSlot(entry.Slot), -18), now, "Direct")
				end
			elseif phase == "Battle" and now >= entry.NextThink then
				entry.NextThink = now + 0.25
				battleThink(entry, now)
			else
				humanoid:MoveTo(root.Position)
			end
		end
	end
end

return BotService
