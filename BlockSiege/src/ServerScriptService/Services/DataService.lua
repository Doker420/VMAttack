-- Профили, игровая валюта и инвентарь. В Studio по умолчанию используется память.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local DataService = {}
local cache = {}
local loadTokens = {}
local loadFailures = {}
local store
local remotes
local autosaveClock = 0
local closing = false

local function defaults()
	return {
		Coins = 0,
		CaseTokens = Config.StartingCaseTokens,
		Wins = 0,
		Matches = 0,
		Kills = 0,
		StructureDamage = 0,
		XP = 0,
		CasesOpened = 0,
		LegendaryPity = 0,
		OwnedWeapons = { Carbine = true },
		SelectedWeapon = "Carbine",
		Upgrades = { Speed = 0, Health = 0, Armor = 0, Engineering = 0 },
		OwnedDefenses = {},
		OwnedCosmetics = {},
		SelectedCosmetics = { WeaponSkin = "Default", Aura = "Default", Trail = "Default" },
		ClaimedLevelRewards = {},
		LastDailyClaim = 0,
	}
end

local function number(value, fallback, maximum)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(value, 0, maximum or 1000000000)
end

local function weaponDictionary(value)
	local result = {}
	if type(value) == "table" then
		for id, owned in pairs(value) do
			if owned == true and Catalog.GetWeapon(id) then
				result[id] = true
			end
		end
	end
	result.Carbine = true
	return result
end

local function upgradeDictionary(value)
	local result = {}
	for _, id in ipairs(Catalog.UpgradeOrder) do
		local definition = Catalog.Upgrades[id]
		local level = type(value) == "table" and value[id] or 0
		result[id] = math.floor(number(level, 0, definition.MaxLevel))
	end
	return result
end

local function cosmeticDictionary(value)
	local result = {}
	if type(value) == "table" then
		for id, owned in pairs(value) do
			if owned == true and Catalog.GetCosmetic(id) then
				result[id] = true
			end
		end
	end
	return result
end

local function defenseDictionary(value)
	local result = {}
	if type(value) == "table" then
		for id, owned in pairs(value) do
			if owned == true and Catalog.GetDefense(id) then
				result[id] = true
			end
		end
	end
	return result
end

local function grantTrackReward(data, level, includeBaseCoins)
	local key = tostring(level)
	local reward = Catalog.GetLevelReward(level)
	if not reward or data.ClaimedLevelRewards[key] then
		return 0, nil
	end
	data.ClaimedLevelRewards[key] = true
	local coins = includeBaseCoins and (15 + level * 5) or 0
	coins = coins + (tonumber(reward.Coins) or 0)
	data.CaseTokens = math.min(99, (data.CaseTokens or 0) + (tonumber(reward.CaseTokens) or 0))
	if reward.Weapon then
		if data.OwnedWeapons[reward.Weapon] then
			coins = coins + 60
		else
			data.OwnedWeapons[reward.Weapon] = true
		end
	end
	if reward.Defense and not data.OwnedDefenses[reward.Defense] then
		data.OwnedDefenses[reward.Defense] = true
	end
	data.Coins = data.Coins + coins
	return coins, reward.Description
end

local function sanitize(value)
	local result = defaults()
	if type(value) ~= "table" then
		return result
	end
	for _, key in ipairs({ "Coins", "CaseTokens", "Wins", "Matches", "Kills", "StructureDamage", "XP", "CasesOpened" }) do
		result[key] = math.floor(number(value[key], result[key]))
	end
	result.LegendaryPity = math.floor(number(value.LegendaryPity, 0, Catalog.Case.LegendaryPity))
	result.LastDailyClaim = math.floor(number(value.LastDailyClaim, 0, 2000000000))
	result.OwnedWeapons = weaponDictionary(value.OwnedWeapons)
	result.Upgrades = upgradeDictionary(value.Upgrades)
	result.OwnedDefenses = defenseDictionary(value.OwnedDefenses)
	result.OwnedCosmetics = cosmeticDictionary(value.OwnedCosmetics)
	result.SelectedCosmetics = { WeaponSkin = "Default", Aura = "Default", Trail = "Default" }
	if type(value.SelectedCosmetics) == "table" then
		for slot, selected in pairs(value.SelectedCosmetics) do
			if (slot == "WeaponSkin" or slot == "Aura" or slot == "Trail") and Catalog.GetCosmetic(selected) and Catalog.GetCosmetic(selected).Slot == slot and result.OwnedCosmetics[selected] then
				result.SelectedCosmetics[slot] = selected
			end
		end
	end
	if type(value.ClaimedLevelRewards) == "table" then
		for level, claimed in pairs(value.ClaimedLevelRewards) do
			if claimed == true and Catalog.GetLevelReward(tonumber(level)) then
				result.ClaimedLevelRewards[tostring(level)] = true
			end
		end
	end
	result.SelectedWeapon = Catalog.GetWeapon(value.SelectedWeapon) and value.SelectedWeapon or "Carbine"
	if not result.OwnedWeapons[result.SelectedWeapon] then
		result.SelectedWeapon = "Carbine"
	end
	return result
end

local function ensureLeaderstats(player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	for _, name in ipairs({ "Wins", "Kills", "Coins" }) do
		if not stats:FindFirstChild(name) then
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = stats
		end
	end
	if not stats:FindFirstChild("Level") then
		local value = Instance.new("IntValue")
		value.Name = "Level"
		value.Parent = stats
	end
	stats.Level.Value = Catalog.LevelForXP(profile.XP)
	return stats
end

local function apply(player)
	local data = cache[player.UserId]
	if not data then
		return
	end
	local stats = ensureLeaderstats(player, data)
	for _, name in ipairs({ "Wins", "Kills", "Coins" }) do
		stats[name].Value = data[name]
	end
	for _, key in ipairs({ "Coins", "CaseTokens", "Wins", "Matches", "Kills", "StructureDamage", "XP", "CasesOpened", "LegendaryPity", "SelectedWeapon" }) do
		player:SetAttribute(key, data[key])
	end
	player:SetAttribute("Level", Catalog.LevelForXP(data.XP))
	stats.Level.Value = Catalog.LevelForXP(data.XP)
	for id, level in pairs(data.Upgrades) do
		player:SetAttribute("Upgrade_" .. id, level)
	end
	for _, id in ipairs(Catalog.DefenseOrder) do
		player:SetAttribute("Defense_" .. id, data.OwnedDefenses[id] == true)
	end
	for _, slot in ipairs({ "WeaponSkin", "Aura", "Trail" }) do
		player:SetAttribute("Cosmetic_" .. slot, data.SelectedCosmetics[slot])
	end
	player:SetAttribute("LastDailyClaim", data.LastDailyClaim)
	player:SetAttribute("ProfileLoaded", true)
	if remotes and player.Parent then
		remotes.ProfileUpdate:FireClient(player, sanitize(data))
	end
end

function DataService.Init(dependencies)
	remotes = dependencies.Remotes
	local enabled = not RunService:IsStudio() or Config.PersistInStudio
	if enabled then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.DataStoreName)
		end)
		if ok then
			store = result
		end
	end
end

function DataService.Load(player)
	local userId = player.UserId
	if cache[userId] then
		apply(player)
		return cache[userId]
	end
	local token = {}
	loadTokens[userId] = token
	local stored
	if store then
		local ok, result = pcall(function()
			return store:GetAsync("Player_" .. userId)
		end)
		if ok then
			stored = result
			loadFailures[userId] = nil
		else
			loadFailures[userId] = true
			player:SetAttribute("DataStatus", "Память: ошибка загрузки")
		end
	end
	if loadTokens[userId] ~= token or not player.Parent then
		return nil
	end
	local profile = sanitize(stored)
	local currentLevel = Catalog.LevelForXP(profile.XP)
	for _, rewardLevel in ipairs(Catalog.LevelRewardOrder) do
		if rewardLevel <= currentLevel then
			grantTrackReward(profile, rewardLevel, false)
		end
	end
	cache[userId] = profile
	apply(player)
	return cache[userId]
end

function DataService.Get(player)
	return cache[player.UserId]
end

function DataService.GetSnapshot(player)
	local data = cache[player.UserId]
	return data and sanitize(data) or nil
end

function DataService.Commit(player, immediate)
	if not cache[player.UserId] then
		return
	end
	apply(player)
	if immediate then
		task.spawn(function()
			DataService.Save(player)
		end)
	end
end

function DataService.Save(player)
	local data = cache[player.UserId]
	if not data or not store then
		return true
	end
	if loadFailures[player.UserId] then
		return false
	end
	local snapshot = sanitize(data)
	return pcall(function()
		store:SetAsync("Player_" .. player.UserId, snapshot)
	end)
end

function DataService.SaveAndClear(player)
	local userId = player.UserId
	loadTokens[userId] = nil
	DataService.Save(player)
	cache[userId] = nil
	loadFailures[userId] = nil
end

function DataService.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		DataService.Save(player)
	end
end

function DataService.Step(deltaTime)
	autosaveClock = autosaveClock + deltaTime
	if autosaveClock < Config.AutosaveInterval then
		return
	end
	autosaveClock = 0
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			DataService.Save(player)
		end)
	end
end

function DataService.AddCoins(player, amount)
	local data = cache[player.UserId]
	if data then
		data.Coins = math.max(0, data.Coins + math.floor(amount))
		apply(player)
	end
end

function DataService.AddXP(player, amount)
	local data = cache[player.UserId]
	local gained = math.max(0, math.floor(tonumber(amount) or 0))
	if not data then
		return { XP = gained, PreviousLevel = 1, Level = 1, LeveledUp = false, Unlocks = {}, LevelCoins = 0 }
	end
	local previousLevel = Catalog.LevelForXP(data.XP)
	data.XP = data.XP + gained
	local level = Catalog.LevelForXP(data.XP)
	local levelCoins = 0
	local unlocks = {}
	for reachedLevel = previousLevel + 1, level do
		local baseCoins = 15 + reachedLevel * 5
		data.Coins = data.Coins + baseCoins
		levelCoins = levelCoins + baseCoins
		local trackCoins, description = grantTrackReward(data, reachedLevel, false)
		levelCoins = levelCoins + trackCoins
		table.insert(unlocks, {
			Level = reachedLevel,
			Text = description or string.format("+%d монет", baseCoins),
		})
	end
	apply(player)
	local result = {
		XP = gained,
		PreviousLevel = previousLevel,
		Level = level,
		LeveledUp = level > previousLevel,
		Unlocks = unlocks,
		LevelCoins = levelCoins,
	}
	if result.LeveledUp and remotes and remotes.ProgressionFX then
		remotes.ProgressionFX:FireClient(player, {
			Type = "LevelUp",
			Level = level,
			LevelCoins = levelCoins,
			Unlocks = unlocks,
		})
	end
	return result
end

function DataService.Award(player, coins, xp, reason)
	local data = cache[player.UserId]
	local coinReward = math.max(0, math.floor(tonumber(coins) or 0))
	local xpReward = math.max(0, math.floor(tonumber(xp) or 0))
	if data then
		data.Coins = data.Coins + coinReward
	end
	local progress = DataService.AddXP(player, xpReward)
	if data and remotes and remotes.ProgressionFX then
		remotes.ProgressionFX:FireClient(player, {
			Type = "Action",
			Coins = coinReward,
			XP = xpReward,
			Reason = tostring(reason or "Полезное действие"),
			Level = progress.Level,
		})
	end
	return progress
end

function DataService.AddKill(player)
	local data = cache[player.UserId]
	if data then
		data.Kills = data.Kills + 1
		return DataService.Award(player, 2, 8, "Противник выведен из боя")
	end
	return nil
end

function DataService.AddStructureDamage(player, amount)
	local data = cache[player.UserId]
	if data then
		data.StructureDamage = data.StructureDamage + math.max(0, math.floor(amount))
	end
end

function DataService.RecordMatch(player, won, draw)
	local data = cache[player.UserId]
	if not data then
		return nil
	end
	data.Matches = data.Matches + 1
	local coins = draw and 25 or (won and 40 or 15)
	local xp = draw and 75 or (won and 120 or 50)
	data.Coins = data.Coins + coins
	local token = false
	if won then
		data.Wins = data.Wins + 1
		if data.Wins % 2 == 0 then
			data.CaseTokens = data.CaseTokens + 1
			token = true
		end
	end
	local progress = DataService.AddXP(player, xp)
	DataService.Commit(player, true)
	return {
		Coins = coins,
		XP = xp,
		Token = token,
		LevelCoins = progress.LevelCoins,
		Level = progress.Level,
		LeveledUp = progress.LeveledUp,
		Unlocks = progress.Unlocks,
	}
end

game:BindToClose(function()
	if closing then
		return
	end
	closing = true
	DataService.SaveAll()
end)

return DataService
