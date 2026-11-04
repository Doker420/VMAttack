-- Server-authoritative hitscan, видимые модели оружия и нелетальный friendly-fire filter.
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
local phaseProvider = function()
	return "Lobby"
end
local teamProvider = function()
	return nil
end
local killHandler
local lastShot = {}
local damageCredits = {}
local watched = {}
local random = Random.new()

local function validPosition(position)
	return typeof(position) == vector3Type and position.X == position.X and position.Y == position.Y and position.Z == position.Z
		and math.abs(position.X) < 10000 and math.abs(position.Y) < 10000 and math.abs(position.Z) < 10000
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
	return WeaponService.EquipCharacter(character, weapon.Id, skin)
end

local function validTeam(team)
	return team == "Blue" or team == "Orange"
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
				if victim:GetAttribute("Team") ~= attackingTeam then
					local armor = tonumber(victim:GetAttribute("Armor")) or 0
					local appliedDamage = weapon.Damage * (1 - math.clamp(armor, 0, 0.65))
					victimHumanoid:TakeDamage(appliedDamage)
					damageCredits[victimHumanoid] = { Player = player, Clock = now }
				end
			else
				fortressService.DamagePart(hit.Instance, weapon.Damage * weapon.StructureMultiplier, attackingTeam, player)
			end
		end
		remotes.CombatFX:FireAllClients({
			Kind = "Shot",
			Origin = origin,
			Finish = finish,
			Color = weapon.Color,
			WeaponId = weapon.Id,
		})
	end
	return true
end

function WeaponService.FirePlayer(player, targetPosition)
	local character = player.Character
	local team = teamProvider(player)
	local weapon = WeaponService.GetPlayerWeapon(player)
	if not character or not team then
		return false
	end
	return fire(character, weapon, targetPosition, team, player, "Player_" .. player.UserId)
end

function WeaponService.FireBot(bot, weaponId, targetPosition)
	local weapon = Catalog.GetWeapon(weaponId) or Catalog.Weapons.Carbine
	local team = bot:GetAttribute("Team")
	local botId = bot:GetAttribute("BotId") or bot.Name
	return fire(bot, weapon, targetPosition, team, nil, "Bot_" .. tostring(botId))
end

return WeaponService
