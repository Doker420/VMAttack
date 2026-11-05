-- BLOCKSIEGE // Shared level-gated PvE expeditions inside the fortress world.
-- The 6v6 match remains authoritative; an expedition is an optional side run
-- during Battle with its own enemies, waves, rewards and complete cleanup.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local ExpeditionCatalog = require(Shared:WaitForChild("ExpeditionCatalog"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local ExpeditionService = {}
local world
local remotes
local state
local dataService
local phaseProvider = function() return "Lobby" end
local teamProvider = function() return nil end
local participantProvider = function() return false end
local rewardHandler
local folder
local runs = {}
local playerRuns = {}
local requestClocks = {}
local nextRunId = 0

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

local function living(model)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = rootOf(model)
	return humanoid and humanoid.Health > 0 and root and humanoid or nil
end

local function notify(player, text)
	if remotes and player and player.Parent then
		remotes.Notify:FireClient(player, text)
	end
end

local function visualPart(parent, name, size, cframe, color, material, collide, query)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = collide == true
	object.CanTouch = false
	object.CanQuery = query == true
	object.CastShadow = true
	object.Parent = parent
	return object
end

local function tag(parent, title, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ExpeditionTag"
	gui.Size = UDim2.fromOffset(230, 52)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = parent
	local text = Instance.new("TextLabel")
	text.Name = "Health"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = color
	text.TextStrokeTransparency = 0.25
	text.Text = title
	text.Parent = gui
	return text
end

local function returnCFrame(player)
	local team = teamProvider(player)
	return team and world.TeamSpawns[team] or world.LobbySpawn
end

local function aliveEnemies(run)
	local count = 0
	for _, enemy in ipairs(run.Enemies) do
		if not enemy.Dead and living(enemy.Model) then
			count = count + 1
		end
	end
	return count
end

local function playerCount(run)
	local count = 0
	for _ in pairs(run.Players) do
		count = count + 1
	end
	return count
end

local function snapshot(run, player)
	local data = dataService and dataService.Get(player) or nil
	return {
		Type = "Snapshot",
		InExpedition = run ~= nil,
		LocationId = run and run.Definition.Id or (data and data.SelectedExpedition or player:GetAttribute("SelectedExpedition") or "VerdantBastion"),
		Wave = run and run.Wave or 0,
		MaxWaves = ExpeditionCatalog.MaxWaves,
		Enemies = run and aliveEnemies(run) or 0,
		Players = run and playerCount(run) or 0,
		Completed = run and run.Completed == true or false,
		BestWave = data and data.ExpeditionBestWave or player:GetAttribute("ExpeditionBestWave") or 0,
		SquadLevel = player:GetAttribute("SquadLevel") or 1,
	}
end

local function sendSnapshot(player, run)
	if remotes and player and player.Parent then
		remotes.ExpeditionFX:FireClient(player, snapshot(run, player))
	end
end

local function broadcast(run)
	for _, entry in pairs(run.Players) do
		sendSnapshot(entry.Player, run)
	end
end

local function buildStage(run)
	local definition = run.Definition
	local center = definition.Center
	run.Model = Instance.new("Folder")
	run.Model.Name = "Expedition_" .. definition.Id .. "_" .. run.Id
	run.Model:SetAttribute("ExpeditionId", definition.Id)
	run.Model.Parent = folder
	visualPart(run.Model, "ExpeditionPlatform", Vector3.new(150, 2, 110), CFrame.new(center + Vector3.new(0, -1, 0)), Color3.fromRGB(28, 43, 58), Enum.Material.Slate, true, false)
	visualPart(run.Model, "ExpeditionArena", Vector3.new(138, 0.35, 98), CFrame.new(center + Vector3.new(0, 0.2, 0)), definition.Color, Enum.Material.Ground, true, false)
	for _, side in ipairs({ -1, 1 }) do
		visualPart(run.Model, "ExpeditionBoundary", Vector3.new(2, 12, 110), CFrame.new(center + Vector3.new(side * 75, 6, 0)), definition.Accent, Enum.Material.Metal, true, false)
		visualPart(run.Model, "ExpeditionBoundary", Vector3.new(150, 12, 2), CFrame.new(center + Vector3.new(0, 6, side * 55)), definition.Accent, Enum.Material.Metal, true, false)
	end
	run.SpawnCFrame = CFrame.lookAt(center + Vector3.new(0, 4, 34), center + Vector3.new(0, 4, 0))
	visualPart(run.Model, "ExpeditionSpawnPad", Vector3.new(18, 0.4, 14), CFrame.new(center + Vector3.new(0, 0.5, 34)), definition.Accent, Enum.Material.Neon, false, false)
	for index = 1, 6 do
		local angle = (index - 1) * math.pi / 3
		local position = center + Vector3.new(math.cos(angle) * 57, 3, math.sin(angle) * 39)
		local crystal = visualPart(run.Model, "ExpeditionCrystal", Vector3.new(2.4, 6, 2.4), CFrame.new(position), definition.Accent, Enum.Material.Neon, false, false)
		local glow = Instance.new("PointLight")
		glow.Color = definition.Accent
		glow.Range = 12
		glow.Brightness = 1.5
		glow.Parent = crystal
		table.insert(run.Animated, { Part = crystal, Base = crystal.CFrame, Phase = index * 0.8 })
	end
	local sign = visualPart(run.Model, "ExpeditionSign", Vector3.one, CFrame.new(center + Vector3.new(0, 9, -48)), definition.Accent, Enum.Material.Neon, false, false)
	sign.Transparency = 1
	tag(sign, definition.Name .. " · PVE", definition.Accent)
end

local function createRun(definition)
	nextRunId = nextRunId + 1
	local run = {
		Id = nextRunId,
		Definition = definition,
		Players = {},
		Connections = {},
		Enemies = {},
		Animated = {},
		Wave = 0,
		Completed = false,
		Active = true,
		NextWaveAt = os.clock() + 1.5,
		NextSnapshot = 0,
		DestroyAt = 0,
	}
	buildStage(run)
	runs[definition.Id] = run
	return run
end

local function enemyDeath(enemy)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	local run = enemy.Run
	if not run.Active then
		return
	end
	local model = enemy.Model
	local lastDamage = tonumber(model:GetAttribute("LastDamageClock")) or -math.huge
	local attackerId = os.clock() - lastDamage <= 10 and model:GetAttribute("LastAttackerUserId") or nil
	local attacker = attackerId and Players:GetPlayerByUserId(attackerId) or nil
	if attacker and run.Players[attacker.UserId] and rewardHandler then
		rewardHandler(attacker, run.Definition.KillCoins, run.Definition.KillXP, "PvE · " .. run.Definition.EnemyName)
	end
	if remotes then
		remotes.CombatFX:FireAllClients({ Kind = "ExpeditionDefeated", Position = enemy.Root.Position, Color = run.Definition.Accent })
	end
	task.delay(1, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	broadcast(run)
end

local function spawnEnemy(run, index, boss)
	local definition = run.Definition
	local center = definition.Center
	local row = math.floor((index - 1) / 3)
	local column = (index - 1) % 3 - 1
	local position = center + Vector3.new(column * 18, boss and 5 or 3.5, -20 - row * 15)
	if boss then
		position = center + Vector3.new(0, 6, -30)
	end
	local model = Instance.new("Model")
	model.Name = boss and "ExpeditionBoss" or "ExpeditionEnemy"
	model:SetAttribute("Team", "Neutral")
	model:SetAttribute("IsExpeditionEnemy", true)
	model:SetAttribute("ExpeditionId", definition.Id)
	model:SetAttribute("ExpeditionRun", run.Id)
	model:SetAttribute("Armor", boss and 0.18 or 0.05)
	model.Parent = run.Model
	local root = visualPart(model, "HumanoidRootPart", Vector3.new(3, 3, 3), CFrame.new(position), definition.Color, Enum.Material.Slate, false, false)
	root.Transparency = 1
	model.PrimaryPart = root
	local scale = boss and 1.65 or 1
	local body = visualPart(model, "Body", Vector3.new(4.4, 4.8, 4) * scale, CFrame.new(position), definition.Color, Enum.Material.DiamondPlate, false, true)
	local head = visualPart(model, "Head", Vector3.new(2.8, 2.4, 2.8) * scale, CFrame.new(position + Vector3.new(0, 3.5 * scale, 0)), Color3.fromRGB(30, 42, 61), Enum.Material.Slate, false, true)
	visualPart(model, "EnemyEye", Vector3.new(1.5, 0.4, 0.25) * scale, CFrame.new(position + Vector3.new(0, 3.6 * scale, -1.45 * scale)), definition.Accent, Enum.Material.Neon, false, false)
	for _, side in ipairs({ -1, 1 }) do
		visualPart(model, "EnemyHorn", Vector3.new(0.55, 2.3, 0.55) * scale, CFrame.new(position + Vector3.new(side * 1.2 * scale, 5.1 * scale, 0)) * CFrame.Angles(0, 0, math.rad(side * 18)), definition.Accent, Enum.Material.Metal, false, false)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = definition.EnemyHealth * (1 + (run.Wave - 1) * 0.22) * (boss and 3 or 1)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = 0
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	local enemy = {
		Run = run, Model = model, Root = root, Body = body, Humanoid = humanoid,
		Boss = boss == true, Dead = false, Speed = definition.EnemySpeed * (boss and 0.72 or 1),
		Damage = definition.EnemyDamage * (boss and 1.45 or 1), NextAttack = os.clock() + 1,
		NextSpecial = os.clock() + 5, Tag = tag(head, (boss and "BOSS · " or "") .. definition.EnemyName, definition.Accent),
	}
	humanoid.Died:Connect(function()
		enemyDeath(enemy)
	end)
	table.insert(run.Enemies, enemy)
	return enemy
end

local function spawnWave(run)
	if not run.Active or run.Completed then
		return
	end
	run.Wave = run.Wave + 1
	run.Enemies = {}
	local count = run.Definition.BaseEnemies + (run.Wave - 1) * 2
	for index = 1, count do
		spawnEnemy(run, index, false)
	end
	if run.Wave == ExpeditionCatalog.MaxWaves then
		spawnEnemy(run, count + 1, true)
	end
	run.NextWaveAt = 0
	broadcast(run)
end

local function completeRun(run)
	if run.Completed or not run.Active then
		return
	end
	run.Completed = true
	run.DestroyAt = os.clock() + 45
	for _, entry in pairs(run.Players) do
		local player = entry.Player
		if dataService then
			dataService.AwardExpedition(player, run.Definition.Id, run.Wave, run.Definition.RewardCoins, run.Definition.RewardXP)
		end
		notify(player, "Экспедиция завершена · +" .. run.Definition.RewardCoins .. " монет · +" .. run.Definition.RewardXP .. " XP")
		if remotes then
			remotes.ExpeditionFX:FireClient(player, { Type = "Completed", LocationId = run.Definition.Id, Wave = run.Wave, Coins = run.Definition.RewardCoins, XP = run.Definition.RewardXP })
		end
	end
	broadcast(run)
end

local function bossSlam(run, enemy)
	if not run.Active or enemy.Dead then
		return
	end
	local position = enemy.Root.Position
	local groundPosition = Vector3.new(position.X, run.Definition.Center.Y + 0.45, position.Z)
	local ring = visualPart(run.Model, "BossSlamTelegraph", Vector3.new(18, 0.25, 18), CFrame.new(groundPosition), Color3.fromRGB(255, 86, 102), Enum.Material.Neon, false, false)
	ring.Transparency = 0.25
	if remotes then
		remotes.CombatFX:FireAllClients({ Kind = "ExpeditionBossWarning", Position = position, Color = Color3.fromRGB(255, 86, 102) })
	end
	task.delay(1.15, function()
		if ring.Parent then
			ring:Destroy()
		end
		if not run.Active or enemy.Dead or not enemy.Model.Parent then
			return
		end
		for _, entry in pairs(run.Players) do
			local character = entry.Player.Character
			local humanoid = living(character)
			local root = rootOf(character)
			if humanoid and root and (root.Position - position).Magnitude <= 19 then
				local armor = tonumber(character:GetAttribute("Armor")) or 0
				local shield = tonumber(character:GetAttribute("DamageTakenMultiplier")) or 1
				character:SetAttribute("LastDamageSource", "Expedition")
				character:SetAttribute("LastDamageClock", os.clock())
				character:SetAttribute("LastAttackerName", run.Definition.EnemyName)
				character:SetAttribute("LastAttackerUserId", nil)
				humanoid:TakeDamage(35 * math.clamp(shield, 0.05, 1) * (1 - math.clamp(armor, 0, 0.65)))
			end
		end
		if remotes then
			remotes.CombatFX:FireAllClients({ Kind = "ExpeditionBossSlam", Position = position, Color = Color3.fromRGB(255, 113, 91) })
		end
	end)
end

local function nearestPlayer(run, position)
	local best
	local bestRoot
	local bestDistance = math.huge
	for _, entry in pairs(run.Players) do
		local character = entry.Player.Character
		local root = rootOf(character)
		if living(character) and root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best = character
				bestRoot = root
				bestDistance = distance
			end
		end
	end
	return best, bestRoot, bestDistance
end

local function stepEnemies(run, now, deltaTime)
	for _, enemy in ipairs(run.Enemies) do
		if not enemy.Dead and living(enemy.Model) and enemy.Model.Parent then
			local target, targetRoot, distance = nearestPlayer(run, enemy.Root.Position)
			if target and targetRoot then
				local position = enemy.Root.Position
				local targetPosition = Vector3.new(targetRoot.Position.X, position.Y, targetRoot.Position.Z)
				if distance > (enemy.Boss and 17 or 14) then
					local direction = targetPosition - position
					if direction.Magnitude > 0.1 then
						local nextPosition = position + direction.Unit * math.min(direction.Magnitude, enemy.Speed * deltaTime)
						enemy.Model:PivotTo(CFrame.lookAt(nextPosition, targetPosition))
					end
				else
					enemy.Model:PivotTo(CFrame.lookAt(position, targetPosition))
					if now >= enemy.NextAttack then
						enemy.NextAttack = now + (enemy.Boss and 1.8 or 1.45)
						local humanoid = living(target)
						local armor = tonumber(target:GetAttribute("Armor")) or 0
						local shield = tonumber(target:GetAttribute("DamageTakenMultiplier")) or 1
					target:SetAttribute("LastDamageSource", "Expedition")
					target:SetAttribute("LastDamageClock", os.clock())
					target:SetAttribute("LastAttackerName", run.Definition.EnemyName)
						target:SetAttribute("LastAttackerUserId", nil)
						humanoid:TakeDamage(enemy.Damage * math.clamp(shield, 0.05, 1) * (1 - math.clamp(armor, 0, 0.65)))
						if remotes then
							remotes.CombatFX:FireAllClients({ Kind = "ExpeditionShot", Origin = enemy.Body.Position, Finish = targetRoot.Position, Color = run.Definition.Color })
						end
					end
				end
				if enemy.Boss and now >= enemy.NextSpecial then
					enemy.NextSpecial = now + 7
					bossSlam(run, enemy)
				end
			end
			if enemy.Tag then
				enemy.Tag.Text = (enemy.Boss and "BOSS · " or "") .. run.Definition.EnemyName .. " · " .. math.ceil(enemy.Humanoid.Health)
			end
		end
	end
end

local function destroyRun(run)
	run.Active = false
	if run.Model then
		run.Model:Destroy()
	end
	if runs[run.Definition.Id] == run then
		runs[run.Definition.Id] = nil
	end
end

local function leave(player, teleport)
	local run = playerRuns[player.UserId]
	if not run then
		return false
	end
	playerRuns[player.UserId] = nil
	local entry = run.Players[player.UserId]
	run.Players[player.UserId] = nil
	if run.Connections[player.UserId] then
		run.Connections[player.UserId]:Disconnect()
		run.Connections[player.UserId] = nil
	end
	player:SetAttribute("InExpedition", false)
	player:SetAttribute("ExpeditionId", "")
	player:SetAttribute("ExpeditionWave", 0)
	if teleport and player.Parent and player.Character and player.Character.Parent then
		player.Character:PivotTo(entry and entry.ReturnCFrame or returnCFrame(player))
	end
	if playerCount(run) == 0 then
		destroyRun(run)
	else
		broadcast(run)
	end
	sendSnapshot(player, nil)
	return true
end

function ExpeditionService.Enter(player, id)
	if phaseProvider() ~= "Battle" or not participantProvider(player) then
		notify(player, "Экспедиция доступна участнику во время Battle")
		return false
	end
	if playerRuns[player.UserId] then
		return false
	end
	local data = dataService and dataService.Get(player) or nil
	local selected = id or (data and data.SelectedExpedition) or player:GetAttribute("SelectedExpedition")
	local definition = ExpeditionCatalog.Get(selected)
	local level = data and Catalog.LevelForXP(data.XP) or player:GetAttribute("Level") or 1
	local wins = data and data.Wins or player:GetAttribute("Wins") or 0
	if not definition or not ExpeditionCatalog.IsUnlocked(selected, level, wins) then
		notify(player, "Локация закрыта · нужен уровень и победы")
		return false
	end
	local run = runs[selected]
	if run and (not run.Active or run.Completed or playerCount(run) >= 8) then
		notify(player, "Этот рейд завершён или заполнен · попробуй позже")
		return false
	end
	run = run or createRun(definition)
	run.Players[player.UserId] = { Player = player, ReturnCFrame = returnCFrame(player) }
	playerRuns[player.UserId] = run
	run.Connections[player.UserId] = player.CharacterAdded:Connect(function(character)
		task.defer(function()
			local current = playerRuns[player.UserId]
			if current and current.Active and player.Character == character and character.Parent then
				character:PivotTo(current.SpawnCFrame)
			end
		end)
	end)
	player:SetAttribute("InExpedition", true)
	player:SetAttribute("ExpeditionId", selected)
	player:SetAttribute("ExpeditionWave", run.Wave)
	if player.Character and player.Character.Parent then
		player.Character:PivotTo(run.SpawnCFrame)
	end
	notify(player, "PvE · " .. definition.Name .. " · волна начинается")
	broadcast(run)
	return true
end

function ExpeditionService.Train(player)
	if phaseProvider() ~= "Lobby" or player:GetAttribute("InMatch") == true or playerRuns[player.UserId] then
		notify(player, "Тренировка отряда доступна в Lobby")
		return false
	end
	local data = dataService and dataService.Get(player) or nil
	if not data then
		return false
	end
	local oldLevel = dataService.GetSquadLevel(player)
	if oldLevel >= 10 then
		notify(player, "Отряд уже достиг уровня 10")
		return false
	end
	local cost = 100 + oldLevel * 50
	if data.Coins < cost then
		notify(player, "Для тренировки нужно " .. cost .. " монет")
		return false
	end
	data.Coins = data.Coins - cost
	data.SquadXP = (data.SquadXP or 0) + 100
	dataService.Commit(player, true)
	local newLevel = dataService.GetSquadLevel(player)
	notify(player, newLevel > oldLevel and ("ОТРЯД · LEVEL " .. newLevel .. " · боты усилены в следующем матче") or ("Тренировка +100 Squad XP · следующий уровень " .. (newLevel + 1)))
	sendSnapshot(player, nil)
	return true
end

function ExpeditionService.HandleAction(player, action, value)
	local now = os.clock()
	if now - (requestClocks[player.UserId] or -math.huge) < 0.25 then
		return false
	end
	requestClocks[player.UserId] = now
	if action == "Select" then
		local definition = ExpeditionCatalog.Get(value)
		local data = dataService and dataService.Get(player) or nil
		local level = data and Catalog.LevelForXP(data.XP) or player:GetAttribute("Level") or 1
		local wins = data and data.Wins or player:GetAttribute("Wins") or 0
		if not definition or not ExpeditionCatalog.IsUnlocked(value, level, wins) then
			notify(player, "Сначала открой локацию уровнем и победами")
			return false
		end
		if dataService then
			dataService.SetExpedition(player, value)
		else
			player:SetAttribute("SelectedExpedition", value)
		end
		sendSnapshot(player, playerRuns[player.UserId])
		return true
	elseif action == "Train" then
		return ExpeditionService.Train(player)
	elseif action == "Enter" then
		return ExpeditionService.Enter(player, value)
	elseif action == "Exit" then
		return leave(player, true)
	elseif action == "Refresh" then
		sendSnapshot(player, playerRuns[player.UserId])
		return true
	end
	return false
end

function ExpeditionService.OnPlayerRemoving(player)
	leave(player, false)
	requestClocks[player.UserId] = nil
end

function ExpeditionService.Reset()
	local players = {}
	for userId, run in pairs(playerRuns) do
		local entry = run.Players[userId]
		if entry then
			table.insert(players, entry.Player)
		end
	end
	for _, player in ipairs(players) do
		leave(player, true)
	end
	for _, run in pairs(runs) do
		destroyRun(run)
	end
	playerRuns = {}
end

function ExpeditionService.SetProviders(phase, team, participant, onReward)
	phaseProvider = phase or phaseProvider
	teamProvider = team or teamProvider
	participantProvider = participant or participantProvider
	rewardHandler = onReward
end

function ExpeditionService.Init(dependencies)
	world = dependencies.World
	remotes = dependencies.Remotes
	state = dependencies.State
	dataService = dependencies.DataService
	folder = Instance.new("Folder")
	folder.Name = "Expeditions"
	folder.Parent = world.Root
	world.Expeditions = folder
end

function ExpeditionService.Step(deltaTime)
	if phaseProvider() ~= "Battle" then
		return
	end
	local now = os.clock()
	for _, run in pairs(runs) do
		if run.Active then
			if run.Completed and now >= run.DestroyAt then
				local members = {}
				for _, entry in pairs(run.Players) do
					table.insert(members, entry.Player)
				end
				for _, player in ipairs(members) do
					leave(player, true)
				end
			elseif not run.Completed then
				local alive = aliveEnemies(run)
				if alive == 0 then
					if run.Wave >= ExpeditionCatalog.MaxWaves then
						completeRun(run)
					elseif run.NextWaveAt == 0 then
						run.NextWaveAt = now + 2
					elseif now >= run.NextWaveAt then
						spawnWave(run)
					end
				end
				stepEnemies(run, now, deltaTime)
			end
			for _, crystal in ipairs(run.Animated) do
				if crystal.Part.Parent then
					crystal.Part.CFrame = crystal.Base * CFrame.Angles(0, now * 0.8 + crystal.Phase, 0)
				end
			end
			for userId in pairs(run.Players) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					player:SetAttribute("ExpeditionWave", run.Wave)
				end
			end
			if now >= run.NextSnapshot then
				run.NextSnapshot = now + 0.5
				broadcast(run)
			end
		end
	end
	if state then
		local count = 0
		for _ in pairs(runs) do count = count + 1 end
		state:SetAttribute("ActiveExpeditions", count)
	end
end

return ExpeditionService
