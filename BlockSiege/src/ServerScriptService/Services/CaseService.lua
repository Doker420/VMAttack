-- Игровые лутбоксы: серверный бросок, опубликованные шансы и pity без Robux.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))

local CaseService = {}
local dataService
local remotes
local equipHandler
local random = Random.new()

local function chooseRarity(data)
	if data.LegendaryPity >= Catalog.Case.LegendaryPity - 1 then
		return "Legendary"
	end
	local roll = random:NextNumber(0, 100)
	if roll < 5 then
		return "Legendary"
	elseif roll < 35 then
		return "Rare"
	end
	return "Common"
end

local function open(player, currency)
	local data = dataService.Get(player)
	if not data then
		return nil, "Профиль ещё загружается"
	end
	if currency == "Coins" and data.Coins < Catalog.Case.CoinPrice then
		return nil, "Нужно 25 монет"
	end
	if currency == "Tokens" and data.CaseTokens < Catalog.Case.TokenPrice then
		return nil, "Нужен 1 жетон"
	end

	local rarity = chooseRarity(data)
	local pool = Catalog.Case.Pool[rarity]
	local weaponId = pool[random:NextInteger(1, #pool)]
	local weapon = Catalog.GetWeapon(weaponId)
	if currency == "Coins" then
		data.Coins = data.Coins - Catalog.Case.CoinPrice
	else
		data.CaseTokens = data.CaseTokens - Catalog.Case.TokenPrice
	end
	data.CasesOpened = data.CasesOpened + 1
	data.LegendaryPity = rarity == "Legendary" and 0 or data.LegendaryPity + 1
	local duplicate = data.OwnedWeapons[weaponId] == true
	local compensation = 0
	if duplicate then
		compensation = Catalog.Case.DuplicateCoins[rarity]
		data.Coins = data.Coins + compensation
	else
		data.OwnedWeapons[weaponId] = true
	end
	dataService.Commit(player, true)
	local result = {
		WeaponId = weaponId,
		Name = weapon.Name,
		Rarity = rarity,
		Duplicate = duplicate,
		Compensation = compensation,
		Coins = data.Coins,
		Tokens = data.CaseTokens,
		Pity = data.LegendaryPity,
	}
	remotes.CaseOpened:FireClient(player, result)
	return result
end

function CaseService.Init(dependencies)
	dataService = dependencies.DataService
	remotes = dependencies.Remotes
end

function CaseService.SetEquipHandler(handler)
	equipHandler = handler
end

function CaseService.OpenCoin(player)
	return open(player, "Coins")
end

function CaseService.OpenToken(player)
	return open(player, "Tokens")
end

function CaseService.HandleAction(player, action, value)
	local result, reason
	if action == "OpenCoin" then
		result, reason = CaseService.OpenCoin(player)
	elseif action == "OpenToken" then
		result, reason = CaseService.OpenToken(player)
	elseif action == "Equip" then
		local data = dataService.Get(player)
		local weapon = Catalog.GetWeapon(value)
		if not data then
			reason = "Профиль ещё загружается"
		elseif not weapon or not data.OwnedWeapons[value] then
			reason = "Это оружие ещё не открыто"
		else
			data.SelectedWeapon = value
			dataService.Commit(player, true)
			if equipHandler then
				equipHandler(player)
			end
			result = { WeaponId = value }
		end
	else
		reason = "Неизвестное действие"
	end
	if not result and reason then
		remotes.Notify:FireClient(player, reason)
	end
	return result, reason
end

return CaseService
