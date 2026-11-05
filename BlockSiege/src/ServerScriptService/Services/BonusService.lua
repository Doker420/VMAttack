-- BLOCKSIEGE // MATCH BONUSES AND SUPPLY DROPS
-- Server-drafted missions, one-time rewards and tangible world pickups.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))

local BonusService = {}
local world
local remotes
local state
local supplyFolder
local phaseProvider = function() return "Lobby" end
local teamProvider = function() return nil end
local participantProvider = function() return false end
local rewardHandler
local missions = {}
local supplies = {}
local battleClock = 0
local publishClock = 0
local nextSupplyAt = 8
local supplySerial = 0

local GOLD = Color3.fromRGB(255, 196, 64)
local DARK = Color3.fromRGB(55, 46, 40)
local DROP_PAIRS = {
	{ Vector3.new(-105, 0, 48), Vector3.new(105, 0, -48) },
	{ Vector3.new(-55, 0, -42), Vector3.new(55, 0, 42) },
	{ Vector3.new(0, 0, 62), Vector3.new(0, 0, -62) },
}

local function activeSupplyCount()
	local count = 0
	for _, record in ipairs(supplies) do
		if not record.Collected and record.Model and record.Model.Parent then
			count = count + 1
		end
	end
	return count
end

local function publishSupplyState()
	if state then
		state:SetAttribute("SupplyActive", activeSupplyCount())
		state:SetAttribute("SupplyNext", math.max(0, math.ceil(nextSupplyAt - battleClock)))
	end
end

local function clearSupplies()
	for _, record in ipairs(supplies) do
		if record.Model then
			record.Model:Destroy()
		end
	end
	supplies = {}
	publishSupplyState()
end

local function clearPlayer(player)
	if not player then
		return
	end
	missions[player.UserId] = nil
	player:SetAttribute("BonusMissionCount", 0)
	player:SetAttribute("BonusCompleted", 0)
	player:SetAttribute("BonusSupplyCollected", 0)
	for index = 1, 3 do
		player:SetAttribute("BonusMission" .. index .. "Id", "")
		player:SetAttribute("BonusMission" .. index .. "Progress", 0)
		player:SetAttribute("BonusMission" .. index .. "Completed", false)
	end
end

local function shuffledMissionIds(userId, matchId)
	local ids = table.clone(Catalog.BonusMissionOrder)
	local random = Random.new((userId * 104729 + matchId * 7919) % 2000000000 + 1)
	for index = #ids, 2, -1 do
		local other = random:NextInteger(1, index)
		ids[index], ids[other] = ids[other], ids[index]
	end
	return { ids[1], ids[2], ids[3] }
end

local function assignMissions(player, matchId)
	local records = {}
	for index, id in ipairs(shuffledMissionIds(player.UserId, matchId)) do
		records[index] = { Id = id, Progress = 0, Completed = false }
		player:SetAttribute("BonusMission" .. index .. "Id", id)
		player:SetAttribute("BonusMission" .. index .. "Progress", 0)
		player:SetAttribute("BonusMission" .. index .. "Completed", false)
	end
	missions[player.UserId] = records
	player:SetAttribute("BonusMissionCount", #records)
	player:SetAttribute("BonusCompleted", 0)
	player:SetAttribute("BonusSupplyCollected", 0)
end

local function emitBonus(position, team, kind)
	if remotes and remotes.BonusFX and typeof(position) == typeof(Vector3.new()) then
		remotes.BonusFX:FireAllClients({ Kind = kind or "BonusMission", Position = position, Team = team, Color = GOLD })
	end
end

local function playerPosition(player)
	local character = player and player.Character or nil
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart) or nil
	return root and root.Position or nil
end

function BonusService.Init(dependencies)
	world = dependencies.World
	remotes = dependencies.Remotes
	state = dependencies.State
	supplyFolder = world.Root:FindFirstChild("BonusDrops")
	if not supplyFolder then
		supplyFolder = Instance.new("Folder")
		supplyFolder.Name = "BonusDrops"
		supplyFolder.Parent = world.Root
	end
	if state then
		state:SetAttribute("BonusActive", false)
		state:SetAttribute("BonusMatchId", 0)
	end
	publishSupplyState()
end

function BonusService.SetProviders(phase, team, participant, reward)
	phaseProvider = phase or phaseProvider
	teamProvider = team or teamProvider
	participantProvider = participant or participantProvider
	rewardHandler = reward or rewardHandler
end

function BonusService.StartMatch(matchId, participants)
	clearSupplies()
	missions = {}
	battleClock = 0
	publishClock = 0
	nextSupplyAt = 8
	supplySerial = 0
	for userId in pairs(participants) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			assignMissions(player, matchId)
		end
	end
	if state then
		state:SetAttribute("BonusActive", true)
		state:SetAttribute("BonusMatchId", matchId)
	end
	publishSupplyState()
end

function BonusService.OnAction(player, action, amount)
	if not player or not participantProvider(player) then
		return
	end
	local phase = phaseProvider()
	if phase ~= "Build" and phase ~= "Battle" then
		return
	end
	local records = missions[player.UserId]
	if not records then
		return
	end
	local increment = math.max(0, tonumber(amount) or 1)
	if increment <= 0 then
		return
	end
	for index, record in ipairs(records) do
		local definition = Catalog.GetBonusMission(record.Id)
		if definition and definition.Action == action and not record.Completed then
			record.Progress = math.min(definition.Target, record.Progress + increment)
			player:SetAttribute("BonusMission" .. index .. "Progress", record.Progress)
			if record.Progress >= definition.Target then
				record.Completed = true
				player:SetAttribute("BonusMission" .. index .. "Completed", true)
				player:SetAttribute("BonusCompleted", (player:GetAttribute("BonusCompleted") or 0) + 1)
				if rewardHandler then
					rewardHandler(player, definition.Coins, definition.XP, "БОНУС · " .. definition.Name)
				end
				emitBonus(playerPosition(player), teamProvider(player), "BonusMission")
			end
		end
	end
end

local collectSupply

local function createSupply(position)
	local model = Instance.new("Model")
	model.Name = "SupplyDrop"
	local function part(name, size, cframe, color, material)
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.CFrame = cframe
		object.Color = color
		object.Material = material
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.CastShadow = true
		object.Parent = model
		return object
	end
	local root = part("SupplyRoot", Vector3.new(4.2, 2.8, 4.2), CFrame.new(position + Vector3.new(0, 3, 0)), GOLD, Enum.Material.Metal)
	root.CanTouch = true
	part("SupplyLid", Vector3.new(4.6, 0.65, 4.6), CFrame.new(position + Vector3.new(0, 4.65, 0)), DARK, Enum.Material.Metal)
	part("SupplyBandX", Vector3.new(0.48, 3.25, 4.5), CFrame.new(position + Vector3.new(0, 3.1, 0)), DARK, Enum.Material.Metal)
	part("SupplyBandZ", Vector3.new(4.5, 3.25, 0.48), CFrame.new(position + Vector3.new(0, 3.1, 0)), DARK, Enum.Material.Metal)
	local beacon = part("SupplyBeacon", Vector3.new(0.35, 18, 0.35), CFrame.new(position + Vector3.new(0, 12, 0)), GOLD, Enum.Material.Neon)
	beacon.Transparency = 0.72
	beacon.CastShadow = false
	local orb = part("SupplyOrb", Vector3.one * 1.25, CFrame.new(position + Vector3.new(0, 6.3, 0)), GOLD, Enum.Material.Neon)
	orb.Shape = Enum.PartType.Ball
	orb.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 20
	light.Brightness = 2.2
	light.Parent = orb
	local gui = Instance.new("BillboardGui")
	gui.Name = "SupplyLabel"
	gui.Size = UDim2.fromOffset(230, 68)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "БОНУС\n+15 монет · +30 XP · +25 HP"
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.Parent = gui
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "ПОДОБРАТЬ"
	prompt.ObjectText = "СНАБЖЕНИЕ"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	model.PrimaryPart = root
	local now = os.clock()
	local record = {
		Model = model,
		Root = root,
		Pivot = root.CFrame,
		Position = position,
		Born = now,
		Until = now + 30,
		Collected = false,
		Phase = math.random() * math.pi * 2,
	}
	root.Touched:Connect(function(hit)
		local character = hit and hit:FindFirstAncestorOfClass("Model") or nil
		local player = character and Players:GetPlayerFromCharacter(character) or nil
		if player and collectSupply then
			collectSupply(record, player)
		end
	end)
	prompt.Triggered:Connect(function(player)
		if collectSupply then
			collectSupply(record, player)
		end
	end)
	model.Parent = supplyFolder
	table.insert(supplies, record)
	return record
end

collectSupply = function(record, player)
	if not record or record.Collected or phaseProvider() ~= "Battle" or not participantProvider(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid") or nil
	local root = character and character:FindFirstChild("HumanoidRootPart") or nil
	if not humanoid or humanoid.Health <= 0 or not root or not record.Root or not record.Root.Parent then
		return false
	end
	if (root.Position - record.Root.Position).Magnitude > 14 then
		return false
	end
	record.Collected = true
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 25)
	player:SetAttribute("BonusSupplyCollected", (player:GetAttribute("BonusSupplyCollected") or 0) + 1)
	if rewardHandler then
		rewardHandler(player, 15, 30, "СНАБЖЕНИЕ · +25 HP")
	end
	local position = record.Root.Position
	local team = teamProvider(player)
	record.Model:Destroy()
	emitBonus(position, team, "Supply")
	publishSupplyState()
	return true
end

local function spawnPair()
	supplySerial = supplySerial + 1
	local pair = DROP_PAIRS[(supplySerial - 1) % #DROP_PAIRS + 1]
	for _, position in ipairs(pair) do
		createSupply(position)
	end
	publishSupplyState()
end

function BonusService.Step(deltaTime)
	if phaseProvider() ~= "Battle" then
		return
	end
	battleClock = battleClock + deltaTime
	publishClock = publishClock + deltaTime
	if battleClock >= nextSupplyAt then
		if activeSupplyCount() <= 4 then
			spawnPair()
		end
		nextSupplyAt = battleClock + 35
	end
	local now = os.clock()
	for index = #supplies, 1, -1 do
		local record = supplies[index]
		if record.Collected or not record.Model or not record.Model.Parent or now >= record.Until then
			if record.Model then
				record.Model:Destroy()
			end
			table.remove(supplies, index)
		else
			local bob = math.sin(now * 2.2 + record.Phase) * 0.45
			record.Model:PivotTo(record.Pivot * CFrame.new(0, bob, 0) * CFrame.Angles(0, now * 0.65, 0))
		end
	end
	if publishClock >= 0.2 then
		publishClock = 0
		publishSupplyState()
	end
end

function BonusService.EndMatch()
	clearSupplies()
	if state then
		state:SetAttribute("BonusActive", false)
	end
	battleClock = 0
	publishClock = 0
	nextSupplyAt = 8
	publishSupplyState()
end

function BonusService.Reset()
	BonusService.EndMatch()
	missions = {}
	for _, player in ipairs(Players:GetPlayers()) do
		clearPlayer(player)
	end
end

function BonusService.OnPlayerRemoving(player)
	if player then
		clearPlayer(player)
	end
end

function BonusService.GetMissions(player)
	return player and missions[player.UserId] or nil
end

function BonusService.GetSupplyCount()
	return activeSupplyCount()
end

return BonusService
