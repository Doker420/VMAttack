-- Server-authoritative hitscan, magazines/reload, visible weapon models and
-- non-lethal friendly-fire filtering. Ability damage uses the same mitigation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))

local vector3Type = typeof(Vector3.new())
local WeaponService = {}
local dataService
local fortressService
local remotes
local phaseProvider = function() return "Lobby" end
local teamProvider = function() return nil end
local killHandler
local lastShot = {}
local damageCredits = {}
local watched = {}
local ammo = {}
local reloads = {}
local random = Random.new()

local function validPosition(position)
	return typeof(position) == vector3Type and position.X == position.X and position.Y == position.Y and position.Z == position.Z
		and math.abs(position.X) < 10000 and math.abs(position.Y) < 10000 and math.abs(position.Z) < 10000
end

local function validTeam(team)
	return team == "Blue" or team == "Orange"
end

local function magazineFor(weapon)
	if weapon.Melee then
		return 0
	end
	local magazines = { Carbine = 24, SMG = 30, Scatter = 6, Marksman = 8, Demolisher = 12, Rail = 5, Vortex = 18, ThanosGauntlet = 3, PrismLance = 10, TeslaCarbine = 24 }
	return magazines[weapon.Id] or 20
end

local function reloadDurationFor(weapon)
	if weapon.Id == "Rail" or weapon.Id == "ThanosGauntlet" then
		return 2.4
	end
	if weapon.Id == "Scatter" then
		return 2.1
	end
	return 1.65
end

local function watchHumanoid(character, humanoid)
	if watched[humanoid] then
		return
	end
	watched[humanoid] = true
	humanoid.Died:Connect(function()
		local credit = damageCredits[humanoid]
		damageCredits[humanoid] = nil
		watched[humanoid] = nil
		if credit and credit.Player and os.clock() - credit.Clock <= 10 and killHandler then
			killHandler(credit.Player, character)
		end
	end)
end

local function syncPlayerWeapon(player, weapon)
	local character = player and player.Character
	local clip = player and ammo[player.UserId]
	if not character or not clip or not weapon then
		return
	end
	character:SetAttribute("Ammo", clip.Rounds)
	character:SetAttribute("Magazine", magazineFor(weapon))
	character:SetAttribute("Reloading", reloads[player.UserId] ~= nil)
	local reload = reloads[player.UserId]
	character:SetAttribute("ReloadDuration", reload and reload.Duration or reloadDurationFor(weapon))
end

local function sendWeaponAction(player, action, weapon, duration)
	if remotes and remotes.WeaponAction and player and player.Parent then
		remotes.WeaponAction:FireClient(player, { Action = action, WeaponId = weapon and weapon.Id or "", Duration = duration or 0 })
	end
end

local function startReload(player, weapon)
	if not player or not weapon or weapon.Melee or phaseProvider() ~= "Battle" then
		return false
	end
	local userId = player.UserId
	local clip = ammo[userId]
	local magazine = magazineFor(weapon)
	if not clip or clip.WeaponId ~= weapon.Id then
		clip = { WeaponId = weapon.Id, Rounds = magazine }
		ammo[userId] = clip
	end
	if reloads[userId] or clip.Rounds >= magazine then
		return false
	end
	local duration = reloadDurationFor(weapon)
	reloads[userId] = { EndsAt = os.clock() + duration, Duration = duration, WeaponId = weapon.Id }
	syncPlayerWeapon(player, weapon)
	sendWeaponAction(player, "ReloadStart", weapon, duration)
	return true
end

function WeaponService.Init(dependencies)
	dataService = dependencies.DataService
	fortressService = dependencies.FortressService
	remotes = dependencies.Remotes
end

function WeaponService.SetProviders(phase, team, onKill)
	phaseProvider = phase
	teamProvider = team
	killHandler = onKill
end

function WeaponService.GetPlayerWeapon(player)
	local data = dataService.Get(player)
	local selected = data and data.SelectedWeapon or "Carbine"
	if data and not data.OwnedWeapons[selected] then
		selected = "Carbine"
	end
	return Catalog.GetWeapon(selected) or Catalog.Weapons.Carbine
end

function WeaponService.EquipCharacter(character, weaponId, skinId)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		watchHumanoid(character, humanoid)
	end
	return WeaponModels.Equip(character, weaponId, skinId)
end

function WeaponService.EquipPlayer(player)
	local character = player.Character
	if not character then
		return nil
	end
	local weapon = WeaponService.GetPlayerWeapon(player)
	local data = dataService.Get(player)
	local skin = data and data.SelectedCosmetics and data.SelectedCosmetics.WeaponSkin or "Default"
	local equipped = WeaponService.EquipCharacter(character, weapon.Id, skin)
	if equipped then
		ammo[player.UserId] = { WeaponId = weapon.Id, Rounds = magazineFor(weapon) }
		reloads[player.UserId] = nil
		syncPlayerWeapon(player, weapon)
		sendWeaponAction(player, "Equip", weapon, 0)
	end
	return equipped
end

local function applyDamage(victim, amount, attackingTeam, player)
	local humanoid = victim and victim:FindFirstChildOfClass("Humanoid")
	if not victim or not humanoid or humanoid.Health <= 0 or not validTeam(attackingTeam) or victim:GetAttribute("Team") == attackingTeam then
		return 0
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	local armor = tonumber(victim:GetAttribute("Armor")) or 0
	local shield = tonumber(victim:GetAttribute("DamageTakenMultiplier")) or 1
	local appliedDamage = amount * math.clamp(shield, 0.05, 1) * (1 - math.clamp(armor, 0, 0.65))
	humanoid:TakeDamage(appliedDamage)
	damageCredits[humanoid] = { Player = player, Clock = os.clock() }
	if player then
		victim:SetAttribute("LastAttackerUserId", player.UserId)
	end
	return appliedDamage
end

-- Used by mines, bombs, slams and turrets. The server supplies the attacking
-- team; a client can never call this function directly.
function WeaponService.ApplyAbilityDamage(victim, amount, attackingTeam, player)
	if phaseProvider() ~= "Battle" then
		return 0
	end
	return applyDamage(victim, amount, attackingTeam, player)
end

local function fire(character, weapon, targetPosition, attackingTeam, player, key)
	if phaseProvider() ~= "Battle" or not character.Parent or not validTeam(attackingTeam) then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not head or not validPosition(targetPosition) then
		return false
	end
	local now = os.clock()
	if lastShot[key] and now - lastShot[key] < weapon.Cooldown then
		return false
	end
	local origin = head.Position
	local delta = targetPosition - origin
	if delta.Magnitude < 0.1 or delta.Magnitude > 1500 then
		return false
	end
	lastShot[key] = now
	local direction = delta.Unit
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	raycastParams.FilterDescendantsInstances = { character }
	local outgoing = tonumber(character:GetAttribute("DamageMultiplier")) or 1

	for _ = 1, weapon.Pellets do
		local jitter = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), random:NextNumber(-1, 1)) * weapon.Spread
		local shotDirection = (direction + jitter).Unit
		local hit = Workspace:Raycast(origin, shotDirection * weapon.Range, raycastParams)
		local finish = origin + shotDirection * weapon.Range
		if hit then
			finish = hit.Position
			local victim = hit.Instance:FindFirstAncestorOfClass("Model")
			local victimHumanoid = victim and victim:FindFirstChildOfClass("Humanoid")
			if victimHumanoid and victimHumanoid.Health > 0 and victim ~= character then
				applyDamage(victim, weapon.Damage * outgoing, attackingTeam, player)
			else
				fortressService.DamagePart(hit.Instance, weapon.Damage * outgoing * weapon.StructureMultiplier, attackingTeam, player)
			end
		end
		remotes.CombatFX:FireAllClients({
			Kind = "Shot",
			Origin = origin,
			Finish = finish,
			Color = weapon.Color,
			WeaponId = weapon.Id,
			Melee = weapon.Melee == true,
			AttackerUserId = player and player.UserId or nil,
		})
	end
	return true
end

function WeaponService.FirePlayer(player, targetPosition)
	local character = player.Character
	local team = teamProvider(player)
	local weapon = WeaponService.GetPlayerWeapon(player)
	if not character or not team or reloads[player.UserId] then
		return false
	end
	local clip = ammo[player.UserId]
	local magazine = magazineFor(weapon)
	if not weapon.Melee then
		if not clip or clip.WeaponId ~= weapon.Id then
			clip = { WeaponId = weapon.Id, Rounds = magazine }
			ammo[player.UserId] = clip
		end
		if clip.Rounds <= 0 then
			startReload(player, weapon)
			return false
		end
	end
	local success = fire(character, weapon, targetPosition, team, player, "Player_" .. player.UserId)
	if success and not weapon.Melee then
		clip.Rounds = math.max(0, clip.Rounds - 1)
		syncPlayerWeapon(player, weapon)
		if clip.Rounds <= 0 then
			startReload(player, weapon)
		end
	end
	return success
end

function WeaponService.RequestReload(player)
	local character = player.Character
	local team = teamProvider(player)
	if not character or not team then
		return false
	end
	return startReload(player, WeaponService.GetPlayerWeapon(player))
end

function WeaponService.FireBot(bot, weaponId, targetPosition)
	local weapon = Catalog.GetWeapon(weaponId) or Catalog.Weapons.Carbine
	local team = bot:GetAttribute("Team")
	local botId = bot:GetAttribute("BotId") or bot.Name
	return fire(bot, weapon, targetPosition, team, nil, "Bot_" .. tostring(botId))
end

function WeaponService.Step()
	local now = os.clock()
	for userId, reload in pairs(reloads) do
		local player = Players:GetPlayerByUserId(userId)
		if not player or phaseProvider() ~= "Battle" then
			reloads[userId] = nil
			if player then
				syncPlayerWeapon(player, WeaponService.GetPlayerWeapon(player))
			end
		elseif now >= reload.EndsAt then
			local weapon = WeaponService.GetPlayerWeapon(player)
			local clip = ammo[userId]
			if clip and clip.WeaponId == weapon.Id then
				clip.Rounds = magazineFor(weapon)
			end
			reloads[userId] = nil
			syncPlayerWeapon(player, weapon)
			sendWeaponAction(player, "ReloadEnd", weapon, 0)
		end
	end
end

function WeaponService.OnPlayerRemoving(player)
	ammo[player.UserId] = nil
	reloads[player.UserId] = nil
	lastShot["Player_" .. player.UserId] = nil
end

return WeaponService
