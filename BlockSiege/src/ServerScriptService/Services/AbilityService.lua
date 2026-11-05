-- BLOCKSIEGE // SERVER-AUTHORITATIVE CLASS ABILITIES
-- Random class draft, cooldowns, deployables, healing, buffs and ability damage.
-- Clients only request F/G and render replicated models/FX.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local AbilityCatalog = require(Shared:WaitForChild("AbilityCatalog"))
local CombatModels = require(Shared:WaitForChild("CombatModels"))

local vector3Type = typeof(Vector3.new())
local AbilityService = {}
local world
local remotes
local state
local fortressService
local botService
local weaponService
local objectFolder
local phaseProvider = function() return "Lobby" end
local teamProvider = function() return nil end
local targetsProvider = function() return {} end
local random = Random.new()
local playerClasses = {}
local modelClasses = {}
local teamDecks = {}
local teamDeckCursor = { Blue = 0, Orange = 0 }
local cooldowns = {}
local effects = {}
local projectiles = {}
local mines = {}
local turrets = {}
local drones = {}
local banners = {}
local cooldownClock = 0
local stateClock = 0
local classCleanupClock = 0
local rewardHandler

local function validPosition(position)
	return typeof(position) == vector3Type and position.X == position.X and position.Y == position.Y and position.Z == position.Z
		and math.abs(position.X) < 10000 and math.abs(position.Y) < 10000 and math.abs(position.Z) < 10000
end

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

local function living(model)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = rootOf(model)
	return model and model.Parent and humanoid and humanoid.Health > 0 and root and humanoid or nil
end

local function notify(player, text)
	if remotes and remotes.Notify and player and player.Parent then
		remotes.Notify:FireClient(player, text)
	end
end

local function emit(payload)
	if remotes and remotes.AbilityFX then
		remotes.AbilityFX:FireAllClients(payload)
	end
end

local function getClassForModel(model)
	return modelClasses[model] or (model and model:GetAttribute("ClassId")) or nil
end

local function getClassForPlayer(player)
	return playerClasses[player.UserId] or player:GetAttribute("ClassId") or nil
end

local function updateCooldownAttributes(owner)
	local clock = os.clock()
	local ownerCooldowns = cooldowns[owner]
	for slot = 1, 2 do
		local remaining = ownerCooldowns and math.max(0, (ownerCooldowns[slot] or 0) - clock) or 0
		remaining = math.ceil(remaining * 10) / 10
		if owner:GetAttribute("Ability" .. slot .. "Remaining") ~= remaining then
			owner:SetAttribute("Ability" .. slot .. "Remaining", remaining)
		end
	end
end

local function publishPlayerClass(player, classId)
	local definition = AbilityCatalog.GetClass(classId)
	if not definition then
		return
	end
	playerClasses[player.UserId] = classId
	player:SetAttribute("ClassId", classId)
	player:SetAttribute("ClassName", definition.Name)
	player:SetAttribute("ClassRole", definition.Role)
	player:SetAttribute("ClassDescription", definition.Description)
	player:SetAttribute("ClassColor", definition.Color)
	player:SetAttribute("ClassBuildBonus", definition.BuildBonus or 0)
	for slot = 1, 2 do
		local ability = AbilityCatalog.GetAbilityForSlot(classId, slot)
		player:SetAttribute("Ability" .. slot .. "Id", ability.Id)
		player:SetAttribute("Ability" .. slot .. "Name", ability.Name)
		player:SetAttribute("Ability" .. slot .. "ShortName", ability.ShortName)
		player:SetAttribute("Ability" .. slot .. "Description", ability.Description)
		player:SetAttribute("Ability" .. slot .. "Cooldown", ability.Cooldown)
		player:SetAttribute("Ability" .. slot .. "Hotkey", ability.Hotkey)
	end
	cooldowns[player] = { 0, 0 }
	updateCooldownAttributes(player)
end

local function clearPlayerClass(player)
	playerClasses[player.UserId] = nil
	cooldowns[player] = nil
	for _, attribute in ipairs({ "ClassId", "ClassName", "ClassRole", "ClassDescription", "Ability1Id", "Ability1Name", "Ability1ShortName", "Ability1Description", "Ability2Id", "Ability2Name", "Ability2ShortName", "Ability2Description", "Ability1Hotkey", "Ability2Hotkey" }) do
		player:SetAttribute(attribute, "")
	end
	player:SetAttribute("ClassColor", nil)
	player:SetAttribute("ClassBuildBonus", 0)
	player:SetAttribute("Ability1Cooldown", 0)
	player:SetAttribute("Ability2Cooldown", 0)
	player:SetAttribute("Ability1Remaining", 0)
	player:SetAttribute("Ability2Remaining", 0)
end

local function refreshEffects(model)
	if not model then
		return
	end
	local clock = os.clock()
	local effect = effects[model]
	local damage = tonumber(model:GetAttribute("ClassDamageMultiplier")) or 1
	local taken = 1
	local speed = tonumber(model:GetAttribute("ClassSpeedBonus")) or 0
	if effect then
		if effect.ShieldUntil and clock < effect.ShieldUntil then
			taken = math.min(taken, effect.ShieldMultiplier or 1)
		end
		if effect.OverdriveUntil and clock < effect.OverdriveUntil then
			damage = damage * (effect.OverdriveMultiplier or 1)
		end
		if effect.RallyUntil and clock < effect.RallyUntil then
			damage = damage * (effect.RallyDamage or 1)
			speed = speed + (effect.RallySpeed or 0)
		end
	end
	model:SetAttribute("DamageMultiplier", damage)
	model:SetAttribute("DamageTakenMultiplier", taken)
	model:SetAttribute("AbilitySpeedBonus", speed)
	model:SetAttribute("Shielded", taken < 0.999)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local baseSpeed = tonumber(model:GetAttribute("BaseWalkSpeed")) or humanoid.WalkSpeed
		local desiredSpeed = baseSpeed + speed
		if math.abs(humanoid.WalkSpeed - desiredSpeed) > 0.01 then
			humanoid.WalkSpeed = desiredSpeed
		end
	end
end

local function applyClassToModel(model, classId)
	local definition = AbilityCatalog.GetClass(classId)
	if not model or not definition then
		return nil
	end
	modelClasses[model] = classId
	model:SetAttribute("ClassId", classId)
	model:SetAttribute("ClassName", definition.Name)
	model:SetAttribute("ClassRole", definition.Role)
	model:SetAttribute("ClassColor", definition.Color)
	model:SetAttribute("ClassDamageMultiplier", definition.DamageMultiplier or 1)
	model:SetAttribute("ClassSpeedBonus", definition.SpeedBonus or 0)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and model:GetAttribute("ClassPassiveApplied") ~= true then
		humanoid.MaxHealth = humanoid.MaxHealth + (definition.MaxHealthBonus or 0)
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (definition.MaxHealthBonus or 0))
		local armor = tonumber(model:GetAttribute("Armor")) or 0
		model:SetAttribute("Armor", armor + (definition.ArmorBonus or 0))
		model:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
		model:SetAttribute("ClassPassiveApplied", true)
	end
	cooldowns[model] = cooldowns[model] or { 0, 0 }
	refreshEffects(model)
	updateCooldownAttributes(model)
	return classId
end

local function shuffledDeck()
	local deck = {}
	for _, classId in ipairs(AbilityCatalog.ClassOrder) do
		table.insert(deck, classId)
	end
	-- The sixth slot is random, while the first five guarantee role variety.
	table.insert(deck, AbilityCatalog.ClassOrder[random:NextInteger(1, #AbilityCatalog.ClassOrder)])
	for index = #deck, 2, -1 do
		local other = random:NextInteger(1, index)
		deck[index], deck[other] = deck[other], deck[index]
	end
	return deck
end

local function nextClass(team)
	if not teamDecks[team] then
		teamDecks[team] = shuffledDeck()
		teamDeckCursor[team] = 0
	end
	local cursor = (teamDeckCursor[team] or 0) + 1
	teamDeckCursor[team] = cursor
	return teamDecks[team][cursor] or AbilityCatalog.ClassOrder[random:NextInteger(1, #AbilityCatalog.ClassOrder)]
end

local function ensureObjectFolder()
	if objectFolder and objectFolder.Parent then
		return objectFolder
	end
	objectFolder = Instance.new("Folder")
	objectFolder.Name = "AbilityObjects"
	objectFolder.Parent = world and world.Root or Workspace
	return objectFolder
end

local function parentUtility(object, team, abilityId, owner)
	object.Parent = ensureObjectFolder()
	object:SetAttribute("Team", team)
	object:SetAttribute("AbilityId", abilityId)
	if owner then
		object:SetAttribute("OwnerUserId", owner.UserId)
	end
	return object
end

local function groundTarget(character, position, range)
	local root = rootOf(character)
	if not root then
		return nil
	end
	local origin = root.Position
	local target = validPosition(position) and position or origin
	local delta = target - origin
	if range and delta.Magnitude > range then
		target = origin + delta.Unit * range
	end
	local edgeX = (Config.Presentation and Config.Presentation.ArenaEdgeX or 300) - 8
	local edgeZ = (Config.Presentation and Config.Presentation.ArenaEdgeZ or 160) - 8
	return Vector3.new(math.clamp(target.X, -edgeX, edgeX), 0.8, math.clamp(target.Z, -edgeZ, edgeZ))
end

local function allies(team)
	local result = {}
	if botService then
		for _, model in ipairs(botService.GetModels(team)) do
			if living(model) then
				table.insert(result, model)
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local playerTeam = teamProvider(player) or player:GetAttribute("Team")
		if playerTeam == team and player:GetAttribute("InMatch") ~= false and living(player.Character) then
			table.insert(result, player.Character)
		end
	end
	return result
end

local function enemies(team)
	local result = {}
	for _, model in ipairs(targetsProvider(team)) do
		if living(model) then
			table.insert(result, model)
		end
	end
	return result
end

local function healAround(team, center, radius, amount)
	local healed = 0
	for _, model in ipairs(allies(team)) do
		local root = rootOf(model)
		local humanoid = living(model)
		if root and humanoid and (root.Position - center).Magnitude <= radius then
			local before = humanoid.Health
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
			if humanoid.Health > before then
				healed = healed + 1
			end
		end
	end
	return healed
end

local function damageAround(team, center, radius, amount, sourcePlayer, sourceModel)
	local damageMultiplier = sourceModel and tonumber(sourceModel:GetAttribute("DamageMultiplier")) or 1
	local hits = 0
	for _, model in ipairs(enemies(team)) do
		local root = rootOf(model)
		if root and (root.Position - center).Magnitude <= radius then
			if weaponService and weaponService.ApplyAbilityDamage then
				weaponService.ApplyAbilityDamage(model, amount * damageMultiplier, team, sourcePlayer)
			else
				local humanoid = living(model)
				if humanoid then
					local armor = tonumber(model:GetAttribute("Armor")) or 0
					local shield = tonumber(model:GetAttribute("DamageTakenMultiplier")) or 1
					humanoid:TakeDamage(amount * damageMultiplier * shield * (1 - math.clamp(armor, 0, 0.65)))
				end
			end
			hits = hits + 1
		end
	end
	return hits
end

local function nearestEnemy(team, position, range)
	local best
	local bestDistance = range or math.huge
	for _, model in ipairs(enemies(team)) do
		local root = rootOf(model)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance <= bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best, bestDistance
end

local function effectFor(model)
	local effect = effects[model]
	if not effect then
		effect = {}
		effects[model] = effect
	end
	return effect
end

local function applyRally(buffModel, untilTime, ability)
	local effect = effectFor(buffModel)
	effect.RallyUntil = math.max(effect.RallyUntil or 0, untilTime)
	effect.RallyDamage = ability.DamageMultiplier or 1.2
	effect.RallySpeed = ability.SpeedBonus or 5
	refreshEffects(buffModel)
end

local function rallyAllies(team, center, radius, untilTime, ability)
	for _, model in ipairs(allies(team)) do
		local root = rootOf(model)
		if root and (root.Position - center).Magnitude <= radius then
			applyRally(model, untilTime, ability)
		end
	end
end

local function execute(character, team, ability, target, player)
	local root = rootOf(character)
	if not root or not living(character) then
		return false
	end
	local now = os.clock()
	local center = target or root.Position
	if ability.Kind == "Heal" then
		healAround(team, center, ability.Radius, ability.Amount)
		emit({ Kind = "Heal", AbilityId = ability.Id, Position = center, Radius = ability.Radius, Team = team, Color = ability.Color })
	elseif ability.Kind == "Drone" then
		if #drones >= 12 then
			return false
		end
		local object = parentUtility(CombatModels.BuildDrone(Config.Teams[team].Color), team, ability.Id, player)
		object:PivotTo(CFrame.new(root.Position + Vector3.new(0, 5, 0)))
		table.insert(drones, { Model = object, Owner = character, Team = team, Until = now + ability.Duration, Radius = ability.Radius, Heal = ability.HealPerSecond, NextHeal = now })
		emit({ Kind = "DroneLaunch", AbilityId = ability.Id, Position = root.Position, Team = team, Color = ability.Color, Duration = ability.Duration })
	elseif ability.Kind == "Shield" then
		local effect = effectFor(character)
		effect.ShieldUntil = math.max(effect.ShieldUntil or 0, now + ability.Duration)
		effect.ShieldMultiplier = ability.DamageTakenMultiplier or 0.42
		refreshEffects(character)
		emit({ Kind = "Shield", AbilityId = ability.Id, Position = root.Position, Origin = root.Position, Team = team, Color = ability.Color, Duration = ability.Duration, Radius = 6 })
	elseif ability.Kind == "Slam" then
		damageAround(team, center, ability.Radius, ability.Amount, player, character)
		emit({ Kind = "Slam", AbilityId = ability.Id, Position = center, Radius = ability.Radius, Team = team, Color = ability.Color })
	elseif ability.Kind == "Overdrive" then
		local effect = effectFor(character)
		effect.OverdriveUntil = math.max(effect.OverdriveUntil or 0, now + ability.Duration)
		effect.OverdriveMultiplier = ability.DamageMultiplier or 1.45
		refreshEffects(character)
		emit({ Kind = "Overdrive", AbilityId = ability.Id, Position = root.Position, Origin = root.Position, Team = team, Color = ability.Color, Duration = ability.Duration, Radius = 5 })
	elseif ability.Kind == "Bomb" then
		if #projectiles >= 24 then
			return false
		end
		local object = parentUtility(CombatModels.BuildBomb(Config.Teams[team].Color), team, ability.Id, player)
		local start = root.Position + Vector3.new(0, 2, 0)
		object:PivotTo(CFrame.new(start))
		table.insert(projectiles, { Model = object, Team = team, Source = character, Player = player, Start = start, Target = center, Born = now, Duration = ability.FlightTime or 0.85, Radius = ability.Radius, Amount = ability.Amount, AbilityId = ability.Id })
		emit({ Kind = "BombLaunch", AbilityId = ability.Id, Position = start, Origin = start, Finish = center, Team = team, Color = ability.Color })
	elseif ability.Kind == "Rally" then
		if #banners >= 24 then
			return false
		end
		local object = parentUtility(CombatModels.BuildBanner(Config.Teams[team].Color), team, ability.Id, player)
		object:PivotTo(CFrame.new(center))
		local banner = { Model = object, Team = team, Position = center, Radius = ability.Radius, Until = now + ability.Duration, Ability = ability, NextBuff = now }
		table.insert(banners, banner)
		rallyAllies(team, center, ability.Radius, now + ability.Duration, ability)
		emit({ Kind = "Rally", AbilityId = ability.Id, Position = center, Radius = ability.Radius, Team = team, Color = ability.Color, Duration = ability.Duration })
	elseif ability.Kind == "Repair" then
		healAround(team, center, ability.Radius, ability.Amount)
		if fortressService and fortressService.RepairStructures then
			fortressService.RepairStructures(team, center, ability.Radius, ability.StructureAmount)
		end
		emit({ Kind = "Repair", AbilityId = ability.Id, Position = center, Radius = ability.Radius, Team = team, Color = ability.Color })
	elseif ability.Kind == "Minefield" then
		if #mines + ability.Count > 72 then
			return false
		end
		local offsets = { Vector3.new(-4, 0, 0), Vector3.new(4, 0, 0), Vector3.new(0, 0, 4) }
		for index = 1, ability.Count do
			local object = parentUtility(CombatModels.BuildMine(Config.Teams[team].Color), team, ability.Id, player)
			local position = center + offsets[((index - 1) % #offsets) + 1]
			object:PivotTo(CFrame.new(position))
			object:SetAttribute("Armed", false)
			table.insert(mines, { Model = object, Team = team, Source = character, Player = player, Position = position, ArmAt = now + 1, Until = now + ability.Duration, Radius = ability.Radius, TriggerRadius = ability.TriggerRadius, Amount = ability.Amount, NextCheck = now, AbilityId = ability.Id })
		end
		emit({ Kind = "Minefield", AbilityId = ability.Id, Position = center, Radius = 8, Team = team, Color = ability.Color })
	elseif ability.Kind == "Turret" then
		if #turrets >= 24 then
			return false
		end
		local object = parentUtility(CombatModels.BuildTurret(Config.Teams[team].Color), team, ability.Id, player)
		object:PivotTo(CFrame.new(center))
		table.insert(turrets, { Model = object, Team = team, Source = character, Player = player, Position = center, Until = now + ability.Duration, NextShot = now + 0.6, Range = ability.AttackRange, Amount = ability.Amount, ShotCooldown = ability.ShotCooldown, AbilityId = ability.Id })
		emit({ Kind = "TurretDeploy", AbilityId = ability.Id, Position = center, Team = team, Color = ability.Color, Duration = ability.Duration })
	else
		return false
	end
	return true
end

local function useAbility(owner, character, team, slot, targetPosition, player)
	if phaseProvider() ~= "Battle" then
		return false, "Способности доступны в фазе ШТУРМ"
	end
	local humanoid = living(character)
	if not humanoid then
		return false, "Персонаж не готов"
	end
	local classId = getClassForModel(character) or (player and getClassForPlayer(player))
	local ability = AbilityCatalog.GetAbilityForSlot(classId, slot)
	if not ability then
		return false, "Класс ещё не назначен"
	end
	local ownerCooldowns = cooldowns[owner]
	local now = os.clock()
	if ownerCooldowns and (ownerCooldowns[slot] or 0) > now then
		return false, "Способность перезаряжается"
	end
	local target = groundTarget(character, targetPosition, ability.Range)
	if not target then
		return false, "Нет цели"
	end
	if not execute(character, team, ability, target, player) then
		return false, "Достигнут лимит активных объектов"
	end
	cooldowns[owner] = cooldowns[owner] or { 0, 0 }
	cooldowns[owner][slot] = now + ability.Cooldown
	updateCooldownAttributes(owner)
	if player and remotes and remotes.AbilityState then
		remotes.AbilityState:FireClient(player, { Slot = slot, Cooldown = ability.Cooldown, AbilityId = ability.Id })
	end
	emit({ Kind = "Cooldown", AbilityId = ability.Id, Position = rootOf(character).Position, Team = team, Color = ability.Color })
	return true
end

function AbilityService.Init(dependencies)
	world = dependencies.World
	remotes = dependencies.Remotes
	state = dependencies.State
	fortressService = dependencies.FortressService
	botService = dependencies.BotService
	weaponService = dependencies.WeaponService
	ensureObjectFolder()
end

function AbilityService.SetProviders(phase, team, targets)
	phaseProvider = phase or phaseProvider
	teamProvider = team or teamProvider
	targetsProvider = targets or targetsProvider
end

function AbilityService.SetRewardHandler(handler)
	rewardHandler = handler
end

function AbilityService.StartMatch(matchId, participants)
	AbilityService.Reset()
	teamDecks = { Blue = shuffledDeck(), Orange = shuffledDeck() }
	teamDeckCursor = { Blue = 0, Orange = 0 }
	for _, player in ipairs(Players:GetPlayers()) do
		local team = participants[player.UserId]
		if team then
			publishPlayerClass(player, nextClass(team))
		end
	end
	if state then
		state:SetAttribute("ClassDraftMatch", matchId)
		state:SetAttribute("ClassDraftEnabled", true)
	end
end

function AbilityService.RegisterBot(model, team)
	return applyClassToModel(model, nextClass(team))
end

function AbilityService.ApplyCharacter(player, character)
	local classId = getClassForPlayer(player)
	if classId then
		playerClasses[player.UserId] = classId
		applyClassToModel(character, classId)
		-- A respawn starts with fresh ability cooldowns only at match start;
		-- cooldowns remain bound to the player, not to the new character.
		cooldowns[player] = cooldowns[player] or { 0, 0 }
		updateCooldownAttributes(player)
	end
end

function AbilityService.UsePlayerAbility(player, slot, targetPosition)
	if slot ~= 1 and slot ~= 2 then
		return false
	end
	local team = teamProvider(player) or player:GetAttribute("Team")
	if not Config.Teams[team] then
		return false, "Вы не участвуете в матче"
	end
	local classId = getClassForPlayer(player)
	if not classId then
		notify(player, "Класс будет назначен при старте матча")
		return false
	end
	local character = player.Character
	if character and not modelClasses[character] then
		applyClassToModel(character, classId)
	end
	local success, reason = useAbility(player, character, team, slot, targetPosition, player)
	if success and rewardHandler then
		local ability = AbilityCatalog.GetAbilityForSlot(classId, slot)
		rewardHandler(player, 1, 4, "Способность · " .. tostring(ability and ability.ShortName or "F/G"))
	end
	if not success and reason and reason ~= "Способность перезаряжается" then
		notify(player, reason)
	end
	return success, reason
end

function AbilityService.UseBotAbility(model, targetPosition)
	if not living(model) then
		return false
	end
	local classId = getClassForModel(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	-- Attribute stores the NEXT slot directly. The old encoded cursor made
	-- every other think retry the same cooldown before trying its partner.
	local cursor = tonumber(model:GetAttribute("AbilityCursor")) or 1
	if cursor ~= 1 and cursor ~= 2 then
		cursor = 1
	end
	if classId == "Medic" and humanoid.Health / math.max(1, humanoid.MaxHealth) < 0.8 then
		cursor = 1
	elseif classId == "Tank" and humanoid.Health / math.max(1, humanoid.MaxHealth) < 0.65 then
		cursor = 1
	end
	local function targetForSlot(slot)
		if classId == "Medic" and slot == 1 then
			return rootOf(model).Position
		elseif classId == "Buffer" then
			return slot == 2 and fortressService.GetCorePosition(model:GetAttribute("Team")) or rootOf(model).Position
		elseif classId == "Engineer" and slot == 2 then
			return rootOf(model).Position
		end
		return targetPosition
	end
	local success = useAbility(model, model, model:GetAttribute("Team"), cursor, targetForSlot(cursor), nil)
	if not success then
		cursor = cursor % 2 + 1
		success = useAbility(model, model, model:GetAttribute("Team"), cursor, targetForSlot(cursor), nil)
	end
	if success then
		model:SetAttribute("AbilityCursor", cursor % 2 + 1)
	end
	return success
end

function AbilityService.GetPlayerClass(player)
	return getClassForPlayer(player)
end

function AbilityService.GetBuildBonus(player)
	local classId = getClassForPlayer(player)
	local definition = AbilityCatalog.GetClass(classId)
	return definition and definition.BuildBonus or 0
end

function AbilityService.GetObjectCounts()
	return { Projectiles = #projectiles, Mines = #mines, Turrets = #turrets, Drones = #drones, Banners = #banners }
end

local function destroyRecord(record)
	if record and record.Model then
		record.Model:Destroy()
	end
end

local function explodeProjectile(projectile)
	damageAround(projectile.Team, projectile.Target, projectile.Radius, projectile.Amount, projectile.Player, projectile.Source)
	emit({ Kind = "BombImpact", AbilityId = projectile.AbilityId, Position = projectile.Target, Radius = projectile.Radius, Team = projectile.Team, Color = AbilityCatalog.GetAbility(projectile.AbilityId).Color })
end

local function explodeMine(mine)
	damageAround(mine.Team, mine.Position, mine.Radius, mine.Amount, mine.Player, mine.Source)
	emit({ Kind = "MineExplode", AbilityId = mine.AbilityId, Position = mine.Position, Radius = mine.Radius, Team = mine.Team, Color = AbilityCatalog.GetAbility(mine.AbilityId).Color })
end

function AbilityService.Step(deltaTime)
	local now = os.clock()
	for model, effect in pairs(effects) do
		if not model.Parent then
			effects[model] = nil
			modelClasses[model] = nil
			cooldowns[model] = nil
		else
			local expired = (not effect.ShieldUntil or effect.ShieldUntil <= now)
				and (not effect.OverdriveUntil or effect.OverdriveUntil <= now)
				and (not effect.RallyUntil or effect.RallyUntil <= now)
			refreshEffects(model)
			if expired then
				effects[model] = nil
			end
		end
	end

	if phaseProvider() == "Battle" then
		for index = #projectiles, 1, -1 do
			local projectile = projectiles[index]
			local alpha = (now - projectile.Born) / projectile.Duration
			if alpha >= 1 or not projectile.Model.Parent then
				if projectile.Model.Parent then
					explodeProjectile(projectile)
				end
				destroyRecord(projectile)
				table.remove(projectiles, index)
			else
				local position = projectile.Start:Lerp(projectile.Target, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * 18, 0)
				projectile.Model:PivotTo(CFrame.new(position) * CFrame.Angles(now * 3, now * 4, 0))
				CombatModels.AnimateUtility(projectile.Model, now, true)
			end
		end
		for index = #mines, 1, -1 do
			local mine = mines[index]
			if now >= mine.Until or not mine.Model.Parent then
				destroyRecord(mine)
				table.remove(mines, index)
			else
				local armed = now >= mine.ArmAt
				mine.Model:SetAttribute("Armed", armed)
				CombatModels.AnimateUtility(mine.Model, now, armed)
				if armed and now >= mine.NextCheck then
					mine.NextCheck = now + 0.12
					local target = nearestEnemy(mine.Team, mine.Position, mine.TriggerRadius)
					if target then
						explodeMine(mine)
						destroyRecord(mine)
						table.remove(mines, index)
					end
				end
			end
		end
		for index = #turrets, 1, -1 do
			local turret = turrets[index]
			if now >= turret.Until or not turret.Model.Parent then
				destroyRecord(turret)
				table.remove(turrets, index)
			else
				local target = nearestEnemy(turret.Team, turret.Position, turret.Range)
				if target then
					local targetRoot = rootOf(target)
					local head = turret.Model:FindFirstChild("TurretHead")
					local headRoot = head and head.PrimaryPart
					if head and headRoot and targetRoot then
						head:PivotTo(CFrame.lookAt(headRoot.Position, targetRoot.Position))
					end
					if now >= turret.NextShot then
						turret.NextShot = now + turret.ShotCooldown
						if weaponService and weaponService.ApplyAbilityDamage then
							weaponService.ApplyAbilityDamage(target, turret.Amount, turret.Team, turret.Player)
						end
						local origin = headRoot and headRoot.Position or turret.Position
						emit({ Kind = "TurretShot", AbilityId = turret.AbilityId, Origin = origin, Finish = targetRoot.Position, Position = targetRoot.Position, Team = turret.Team, Color = Color3.fromRGB(255, 209, 99) })
					end
				end
			end
		end
		for index = #drones, 1, -1 do
			local drone = drones[index]
			local ownerRoot = rootOf(drone.Owner)
			if now >= drone.Until or not living(drone.Owner) or not drone.Model.Parent then
				destroyRecord(drone)
				table.remove(drones, index)
			else
				local position = ownerRoot.Position + Vector3.new(math.sin(now * 2) * 2, 5 + math.sin(now * 4) * 0.5, math.cos(now * 2) * 2)
				drone.Model:PivotTo(CFrame.new(position) * CFrame.Angles(0, now * 2, 0))
				CombatModels.AnimateUtility(drone.Model, now, true)
				if now >= drone.NextHeal then
					drone.NextHeal = now + 1
					healAround(drone.Team, position, drone.Radius, drone.Heal)
					emit({ Kind = "DroneHeal", AbilityId = "GuardianDrone", Position = position, Radius = drone.Radius, Team = drone.Team, Color = Color3.fromRGB(93, 239, 174) })
				end
			end
		end
		for index = #banners, 1, -1 do
			local banner = banners[index]
			if now >= banner.Until or not banner.Model.Parent then
				destroyRecord(banner)
				table.remove(banners, index)
			else
				CombatModels.AnimateBanner(banner.Model, now)
				if now >= banner.NextBuff then
					banner.NextBuff = now + 0.3
					rallyAllies(banner.Team, banner.Position, banner.Radius, now + 0.45, banner.Ability)
				end
			end
		end
	end

	classCleanupClock = classCleanupClock + deltaTime
	if classCleanupClock >= 1 then
		classCleanupClock = 0
		for model in pairs(modelClasses) do
			if not model.Parent then
				modelClasses[model] = nil
				cooldowns[model] = nil
				effects[model] = nil
			end
		end
	end

	cooldownClock = cooldownClock + deltaTime
	if cooldownClock >= 0.1 then
		cooldownClock = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if playerClasses[player.UserId] then
				updateCooldownAttributes(player)
			end
		end
		if botService then
			for _, team in ipairs(Config.TeamOrder) do
				for _, model in ipairs(botService.GetModels(team)) do
					updateCooldownAttributes(model)
				end
			end
		end
	end
	stateClock = stateClock + deltaTime
	if stateClock >= 0.25 and state then
		stateClock = 0
		state:SetAttribute("ActiveAbilityMines", #mines)
		state:SetAttribute("ActiveAbilityTurrets", #turrets)
		state:SetAttribute("ActiveAbilityProjectiles", #projectiles)
		state:SetAttribute("ActiveAbilityDrones", #drones)
	end
end

function AbilityService.Reset()
	for _, list in ipairs({ projectiles, mines, turrets, drones, banners }) do
		for _, record in ipairs(list) do
			destroyRecord(record)
		end
		for index = #list, 1, -1 do
			table.remove(list, index)
		end
	end
	playerClasses = {}
	modelClasses = {}
	cooldowns = {}
	effects = {}
	teamDecks = {}
	teamDeckCursor = { Blue = 0, Orange = 0 }
	classCleanupClock = 0
	cooldownClock = 0
	stateClock = 0
	for _, player in ipairs(Players:GetPlayers()) do
		clearPlayerClass(player)
	end
	if state then
		state:SetAttribute("ClassDraftEnabled", false)
		state:SetAttribute("ActiveAbilityMines", 0)
		state:SetAttribute("ActiveAbilityTurrets", 0)
		state:SetAttribute("ActiveAbilityProjectiles", 0)
		state:SetAttribute("ActiveAbilityDrones", 0)
	end
end

function AbilityService.OnPlayerRemoving(player)
	playerClasses[player.UserId] = nil
	cooldowns[player] = nil
end

return AbilityService
