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
		OwnedCosmetics = {},
		SelectedCosmetics = { WeaponSkin = "Default", Aura = "Default", Trail = "Default" },
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
	result.OwnedCosmetics = cosmeticDictionary(value.OwnedCosmetics)
	result.SelectedCosmetics = { WeaponSkin = "Default", Aura = "Default", Trail = "Default" }
	if type(value.SelectedCosmetics) == "table" then
		for slot, selected in pairs(value.SelectedCosmetics) do
			if (slot == "WeaponSkin" or slot == "Aura" or slot == "Trail") and Catalog.GetCosmetic(selected) and Catalog.GetCosmetic(selected).Slot == slot and result.OwnedCosmetics[selected] then
				result.SelectedCosmetics[slot] = selected
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
	cache[userId] = sanitize(stored)
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

function DataService.AddKill(player)
	local data = cache[player.UserId]
	if data then
		data.Kills = data.Kills + 1
		data.Coins = data.Coins + 2
		data.XP = data.XP + 8
		apply(player)
	end
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
	local oldLevel = Catalog.LevelForXP(data.XP)
	local newLevel = Catalog.LevelForXP(data.XP + xp)
	local levelCoins = 0
	for level = oldLevel + 1, newLevel do
		levelCoins = levelCoins + 15 + level * 5
	end
	data.Coins = data.Coins + coins + levelCoins
	data.XP = data.XP + xp
	local token = false
	if won then
		data.Wins = data.Wins + 1
		if data.Wins % 2 == 0 then
			data.CaseTokens = data.CaseTokens + 1
			token = true
		end
	end
	DataService.Commit(player, true)
	return { Coins = coins, XP = xp, Token = token, LevelCoins = levelCoins, Level = newLevel, LeveledUp = newLevel > oldLevel }
end

game:BindToClose(function()
	if closing then
		return
	end
	closing = true
	DataService.SaveAll()
end)

return DataService
