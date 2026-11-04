-- Очередь, команды 6x6, фазы Build/Battle/Results и возврат в лобби.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local MatchService = {}
local world
local dataService
local fortressService
local weaponService
local botService
local progressionService
local captureService
local abilityService
local neutralService
local remotes
local state
local phase = "Lobby"
local timer = 0
local intermission
local queued = {}
local participants = {}
local pendingSpawns = {}
local matchId = 0
local lastSecond = -1

local function notify(player, text)
	if player and player.Parent then
		remotes.Notify:FireClient(player, text)
	end
end

local function queueCount()
	local count = 0
	for userId in pairs(queued) do
		if Players:GetPlayerByUserId(userId) then
			count = count + 1
		else
			queued[userId] = nil
		end
	end
	return count
end

local function participantCount()
	local count = 0
	for userId in pairs(participants) do
		if Players:GetPlayerByUserId(userId) then
			count = count + 1
		end
	end
	return count
end

local function updateCounts()
	local humans = { Blue = 0, Orange = 0 }
	for _, player in ipairs(Players:GetPlayers()) do
		local team = participants[player.UserId]
		if team then
			humans[team] = humans[team] + 1
		end
	end
	for _, team in ipairs(Config.TeamOrder) do
		state:SetAttribute(team .. "Humans", humans[team])
		state:SetAttribute(team .. "Bots", botService and botService.Count(team) or 0)
	end
	state:SetAttribute("QueueCount", queueCount())
end

local function updateClock(force)
	local second = math.max(0, math.ceil(timer))
	if force or second ~= lastSecond then
		lastSecond = second
		state:SetAttribute("Time", second)
	end
end

local function setPhase(nextPhase, duration)
	phase = nextPhase
	timer = duration or 0
	state:SetAttribute("Phase", phase)
	updateClock(true)
	updateCounts()
end

local function spawnPlayer(player, cframe)
	if player and player.Parent then
		pendingSpawns[player.UserId] = cframe
		player:LoadCharacter()
	end
end

local function teamSpawn(team)
	return world.TeamSpawns[team]
end

local function playerLevel(player)
	local data = dataService and dataService.Get(player)
	return data and Catalog.LevelForXP(data.XP) or tonumber(player:GetAttribute("Level")) or 1
end

function MatchService.GetPhase()
	return phase
end

function MatchService.GetTeam(player)
	return participants[player.UserId]
end

function MatchService.IsParticipant(player)
	return participants[player.UserId] ~= nil
end

function MatchService.GetTargets(team)
	local enemy = Config.OtherTeam(team)
	local result = botService.GetModels(enemy)
	for _, player in ipairs(Players:GetPlayers()) do
		if participants[player.UserId] == enemy then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and humanoid and humanoid.Health > 0 and root then
				table.insert(result, character)
			end
		end
	end
	return result
end

function MatchService.OnStructureDamage(player, amount, kind)
	if phase == "Battle" and MatchService.IsParticipant(player) then
		dataService.AddStructureDamage(player, amount)
	end
end

function MatchService.OnKill(player, victim)
	if phase == "Battle" and MatchService.IsParticipant(player) then
		dataService.AddKill(player)
		notify(player, "Боец выведен из строя · +2 монеты")
	end
end

function MatchService.EndMatch(winner, reason)
	if phase ~= "Battle" then
		return
	end
	setPhase("Results", Config.ResultsDuration)
	-- Results should show the fortress, not live mines/projectiles or a frozen
	-- jungle encounter. The next match will draft fresh classes and camps.
	if abilityService then
		abilityService.Reset()
	end
	if neutralService then
		neutralService.Reset()
	end
	state:SetAttribute("Winner", winner or "")
	state:SetAttribute("Reason", reason or "Ядро уничтожено")
	for _, player in ipairs(Players:GetPlayers()) do
		local team = participants[player.UserId]
		if team then
			local draw = not winner or winner == ""
			local reward = dataService.RecordMatch(player, team == winner, draw)
			remotes.Results:FireClient(player, {
				Winner = winner or "",
				Team = team,
				Reason = reason or "",
				Reward = reward,
			})
		end
	end
	updateCounts()
end

function MatchService.OnCoreDestroyed(losingTeam, attackingTeam)
	if Config.Teams[losingTeam] and Config.Teams[attackingTeam] and losingTeam ~= attackingTeam then
		MatchService.EndMatch(attackingTeam, "Ядро крепости " .. Config.Teams[losingTeam].Name .. " уничтожено")
	end
end

function MatchService.StartMatch()
	if phase ~= "Lobby" then
		return false
	end
	local players = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if queued[player.UserId] then
			table.insert(players, player)
		end
	end
	if #players == 0 then
		return false
	end
	-- Snake/level-aware draft: high levels are distributed by total team power, not join order.
	table.sort(players, function(a, b)
		local levelA = playerLevel(a)
		local levelB = playerLevel(b)
		if levelA == levelB then
			return a.UserId < b.UserId
		end
		return levelA > levelB
	end)
	matchId = matchId + 1
	participants = {}
	local counts = { Blue = 0, Orange = 0 }
	local power = { Blue = 0, Orange = 0 }
	for _, player in ipairs(players) do
		local team
		if counts.Blue >= Config.TeamSize then
			team = "Orange"
		elseif counts.Orange >= Config.TeamSize then
			team = "Blue"
		elseif power.Blue == power.Orange then
			team = counts.Blue <= counts.Orange and "Blue" or "Orange"
		else
			team = power.Blue < power.Orange and "Blue" or "Orange"
		end
		local level = playerLevel(player)
		participants[player.UserId] = team
		counts[team] = counts[team] + 1
		power[team] = power[team] + level
		queued[player.UserId] = nil
		player:SetAttribute("Queued", false)
		player:SetAttribute("Team", team)
		player:SetAttribute("MatchLevel", level)
		player:SetAttribute("InMatch", true)
	end
	if abilityService then
		abilityService.StartMatch(matchId, participants)
	end
	for _, player in ipairs(players) do
		local stats = progressionService and progressionService.GetStats(player) or nil
		local capacity = (stats and stats.BuildCapacity or Config.Arena.MaxBuildPerPlayer) + (abilityService and abilityService.GetBuildBonus(player) or 0)
		player:SetAttribute("BuildRemaining", capacity)
	end
	state:SetAttribute("BluePower", power.Blue)
	state:SetAttribute("OrangePower", power.Orange)
	state:SetAttribute("MatchLevelDraft", true)
	intermission = nil
	if captureService then
		captureService.Reset()
	end
	fortressService.Reset()
	if neutralService then
		neutralService.StartMatch()
	end
	setPhase("Build", Config.BuildDuration)
	for _, player in ipairs(players) do
		spawnPlayer(player, teamSpawn(participants[player.UserId]))
		notify(player, "СТРОИТЕЛЬСТВО · укрепите свою крепость")
	end
	botService.Start(matchId, participants)
	updateCounts()
	return true
end

function MatchService.HandleLobbyAction(player, action)
	if phase ~= "Lobby" then
		notify(player, "Матч уже идёт · дождитесь возврата в лобби")
		return false
	end
	if not player:GetAttribute("ProfileLoaded") then
		notify(player, "Профиль загружается · секунду...")
		return false
	end
	if action == "QuickStart" then
		queued[player.UserId] = true
		player:SetAttribute("Queued", true)
		return MatchService.StartMatch()
	elseif action == "Queue" then
		if queued[player.UserId] then
			queued[player.UserId] = nil
			player:SetAttribute("Queued", false)
		else
			queued[player.UserId] = true
			player:SetAttribute("Queued", true)
			if not intermission then
				intermission = Config.IntermissionDuration
			end
		end
		if queueCount() == 0 then
			intermission = nil
			state:SetAttribute("Time", 0)
		else
			timer = intermission
			updateClock(true)
		end
		updateCounts()
		return true
	end
	return false
end

function MatchService.HandleBuild(player, kind, position, rotation)
	local team = participants[player.UserId]
	if phase ~= "Build" or not team then
		notify(player, "Строить можно только во время подготовки")
		return false
	end
	local success, reason = fortressService.BuildPlayer(player, team, kind, position, rotation)
	if not success then
		notify(player, reason)
	end
	return success, reason
end

function MatchService.HandleBuildPreview(player, kind, position, rotation, requestId)
	local team = participants[player.UserId]
	local cframe, reason = fortressService.GetPlayerPlacement(player, team, kind, position, rotation)
	local valid = cframe ~= nil
	remotes.BuildPreview:FireClient(player, {
		Kind = kind,
		RequestId = type(requestId) == "number" and requestId or nil,
		Rotation = fortressService.GetRotationDegrees(rotation),
		Valid = valid,
		Reason = reason or "Можно строить",
		Position = cframe and cframe.Position or position,
		CFrame = cframe,
		Team = team,
	})
	return valid, reason
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.JumpPower = 50
	if progressionService then
		progressionService.ApplyCharacter(player, character)
	else
		humanoid.WalkSpeed = 20
		humanoid.MaxHealth = 120
		humanoid.Health = 120
	end
	local team = participants[player.UserId]
	character:SetAttribute("Team", team or "")
	if abilityService then
		abilityService.ApplyCharacter(player, character)
	end
	weaponService.EquipPlayer(player)
	local spawn = pendingSpawns[player.UserId] or world.LobbySpawn
	task.defer(function()
		if character.Parent then
			character:PivotTo(spawn)
			-- Re-equip after the avatar finishes loading so R15 hands and the server
			-- weapon weld cannot be lost during character assembly or respawn.
			if player.Character == character then
				weaponService.EquipPlayer(player)
			end
		end
	end)
	local deathMatch = matchId
	humanoid.Died:Connect(function()
		if participants[player.UserId] and (phase == "Build" or phase == "Battle") then
			task.delay(Config.RespawnDuration, function()
				local currentTeam = participants[player.UserId]
				if currentTeam and matchId == deathMatch and (phase == "Build" or phase == "Battle") and player.Parent then
					spawnPlayer(player, teamSpawn(currentTeam))
				end
			end)
		end
	end)
end

function MatchService.OnPlayerAdded(player)
	player:SetAttribute("Queued", false)
	player:SetAttribute("Team", "")
	player:SetAttribute("InMatch", false)
	player:SetAttribute("ProfileLoaded", false)
	player:SetAttribute("BuildRemaining", 0)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	spawnPlayer(player, world.LobbySpawn)
end

function MatchService.OnProfileLoaded(player)
	if player.Character then
		if progressionService then
			progressionService.ApplyCharacter(player, player.Character, player:GetAttribute("InMatch") == true)
		end
		if abilityService then
			abilityService.ApplyCharacter(player, player.Character)
		end
		weaponService.EquipPlayer(player)
	end
end

local function resetToLobby()
	botService.Stop()
	if abilityService then
		abilityService.Reset()
	end
	if neutralService then
		neutralService.Reset()
	end
	fortressService.Clear()
	if captureService then
		captureService.Reset()
	end
	participants = {}
	queued = {}
	intermission = nil
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("Team", "")
		player:SetAttribute("Queued", false)
		player:SetAttribute("InMatch", false)
		player:SetAttribute("BuildRemaining", 0)
		spawnPlayer(player, world.LobbySpawn)
	end
	state:SetAttribute("Winner", "")
	state:SetAttribute("Reason", "")
	state:SetAttribute("BluePower", 0)
	state:SetAttribute("OrangePower", 0)
	state:SetAttribute("MatchLevelDraft", false)
	setPhase("Lobby", 0)
end

function MatchService.OnPlayerRemoving(player)
	local userId = player.UserId
	if weaponService and weaponService.OnPlayerRemoving then
		weaponService.OnPlayerRemoving(player)
	end
	queued[userId] = nil
	pendingSpawns[userId] = nil
	local team = participants[userId]
	if abilityService then
		abilityService.OnPlayerRemoving(player)
	end
	if team then
		participants[userId] = nil
		if participantCount() == 0 then
			matchId = matchId + 1
			resetToLobby()
			return
		elseif phase == "Build" or phase == "Battle" then
			botService.AddBot(team)
		end
	end
	updateCounts()
end

function MatchService.Init(dependencies)
	world = dependencies.World
	dataService = dependencies.DataService
	fortressService = dependencies.FortressService
	weaponService = dependencies.WeaponService
	botService = dependencies.BotService
	progressionService = dependencies.ProgressionService
	captureService = dependencies.CaptureService
	abilityService = dependencies.AbilityService
	neutralService = dependencies.NeutralService
	remotes = dependencies.Remotes
	state = dependencies.State
	fortressService.SetPhaseProvider(MatchService.GetPhase)
	fortressService.SetCoreHandler(MatchService.OnCoreDestroyed)
	fortressService.SetDamageHandler(MatchService.OnStructureDamage)
	fortressService.SetBuildCapacityProvider(function(player)
		local stats = progressionService and progressionService.GetStats(player)
		local baseCapacity = stats and stats.BuildCapacity or Config.Arena.MaxBuildPerPlayer
		return baseCapacity + (abilityService and abilityService.GetBuildBonus(player) or 0)
	end)
	fortressService.SetBuildAccessProvider(function(player, kind)
		return not progressionService or progressionService.CanBuildDefense(player, kind)
	end)
	fortressService.SetTargetsProvider(MatchService.GetTargets)
	weaponService.SetProviders(MatchService.GetPhase, MatchService.GetTeam, MatchService.OnKill)
	botService.SetProviders(MatchService.GetPhase, MatchService.GetTargets)
	if abilityService then
		abilityService.SetProviders(MatchService.GetPhase, MatchService.GetTeam, MatchService.GetTargets)
	end
	if neutralService then
		neutralService.SetPhaseProvider(MatchService.GetPhase)
	end
	if captureService then
		captureService.SetPhaseProvider(MatchService.GetPhase)
	end
	state:SetAttribute("Phase", "Lobby")
	state:SetAttribute("Time", 0)
	state:SetAttribute("Winner", "")
	state:SetAttribute("Reason", "")
	state:SetAttribute("BluePower", 0)
	state:SetAttribute("OrangePower", 0)
	state:SetAttribute("MatchLevelDraft", false)
	for _, team in ipairs(Config.TeamOrder) do
		state:SetAttribute(team .. "Core", 0)
		state:SetAttribute(team .. "CoreMax", Config.Arena.CoreHealth)
	end
	updateCounts()
end

function MatchService.Step(deltaTime)
	if phase == "Lobby" then
		if intermission then
			if queueCount() == 0 then
				intermission = nil
				setPhase("Lobby", 0)
				return
			end
			intermission = math.max(0, intermission - deltaTime)
			timer = intermission
			updateClock()
			if intermission <= 0 then
				MatchService.StartMatch()
			end
		end
		return
	end
	timer = math.max(0, timer - deltaTime)
	updateClock()
	if timer > 0 then
		return
	end
	if phase == "Build" then
		setPhase("Battle", Config.BattleDuration)
		for _, player in ipairs(Players:GetPlayers()) do
			if participants[player.UserId] then
				-- Reassert the selected weapon and skin at the combat boundary.
				weaponService.EquipPlayer(player)
				notify(player, "ШТУРМ · уничтожьте вражеское ядро")
			end
		end
	elseif phase == "Battle" then
		local blue = fortressService.GetCoreHealth("Blue")
		local orange = fortressService.GetCoreHealth("Orange")
		if blue == orange then
			MatchService.EndMatch("", "Время вышло · ничья")
		else
			local winner = blue > orange and "Blue" or "Orange"
			MatchService.EndMatch(winner, "Время вышло · сохранено больше здоровья ядра")
		end
	elseif phase == "Results" then
		resetToLobby()
	end
end

return MatchService
