-- Server-owned profiles, skin ownership, counters and receipt deduplication.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("SwapPlaces")
local Config = require(Shared:WaitForChild("Config"))
local SkinCatalog = require(Shared:WaitForChild("SkinCatalog"))

local DataService = {}
local remotes
local store = DataStoreService:GetDataStore(Config.DataStoreName)
local cache = {}
local dirty = {}
local saveClock = 0
local closing = false

local function persistent()
	return not RunService:IsStudio() or Config.PersistInStudio
end

local function defaultProfile(userId)
	local starter = SkinCatalog.StarterForUser(userId)
	return {
		Version = 1,
		OwnedSkins = { Default = true, [starter] = true },
		EquippedSkin = starter,
		Swaps = 0,
		Trades = 0,
		ProcessedReceipts = {},
	}
end

local function sanitize(raw, userId)
	local fallback = defaultProfile(userId)
	if type(raw) ~= "table" then return fallback end
	local result = {
		Version = 1,
		OwnedSkins = { Default = true },
		EquippedSkin = "Default",
		Swaps = math.max(0, math.floor(tonumber(raw.Swaps) or 0)),
		Trades = math.max(0, math.floor(tonumber(raw.Trades) or 0)),
		ProcessedReceipts = {},
	}
	local hasTradable = false
	for id in pairs(result.OwnedSkins) do hasTradable = hasTradable or SkinCatalog.IsTradable(id) end
	if type(raw.OwnedSkins) == "table" then
		for id, owned in pairs(raw.OwnedSkins) do
			if owned == true and SkinCatalog.Get(id) then
				result.OwnedSkins[id] = true
				hasTradable = hasTradable or SkinCatalog.IsTradable(id)
			end
		end
	end
	if not hasTradable then result.OwnedSkins[SkinCatalog.StarterForUser(userId)] = true end
	if type(raw.EquippedSkin) == "string" and result.OwnedSkins[raw.EquippedSkin] then result.EquippedSkin = raw.EquippedSkin end
	if type(raw.ProcessedReceipts) == "table" then
		local receipts = {}
		for id, timestamp in pairs(raw.ProcessedReceipts) do
			if type(id) == "string" and #id > 0 and #id <= 100 then
				receipts[id] = tonumber(timestamp) or 0
			end
		end
		local ordered = {}
		for id, timestamp in pairs(receipts) do table.insert(ordered, { Id = id, Time = timestamp }) end
		table.sort(ordered, function(a, b) return a.Time > b.Time end)
		for index = 1, math.min(Config.MaxProcessedReceipts, #ordered) do
			result.ProcessedReceipts[ordered[index].Id] = ordered[index].Time
		end
	end
	return result
end

local function publicProfile(data)
	local owned = {}
	for id in pairs(data.OwnedSkins) do owned[id] = true end
	return {
		OwnedSkins = owned,
		EquippedSkin = data.EquippedSkin,
		Swaps = data.Swaps,
		Trades = data.Trades,
	}
end

function DataService.Get(player)
	return player and cache[player.UserId] or nil
end

function DataService.Commit(player, saveNow)
	local data = DataService.Get(player)
	if not data then return end
	local count = 0
	for _ in pairs(data.OwnedSkins) do count = count + 1 end
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("EquippedSkin", data.EquippedSkin)
	player:SetAttribute("OwnedSkinCount", count)
	player:SetAttribute("AvatarSwaps", data.Swaps)
	player:SetAttribute("SkinTrades", data.Trades)
	if remotes and player.Parent then remotes.ProfileUpdate:FireClient(player, publicProfile(data)) end
	dirty[player.UserId] = true
	if saveNow then DataService.Save(player) end
end

function DataService.Load(player)
	if cache[player.UserId] then return cache[player.UserId] end
	local raw
	if persistent() then
		local ok, result = pcall(function() return store:GetAsync("player_" .. player.UserId) end)
		if ok then raw = result else warn("[SwapPlaces] DataStore load unavailable:", tostring(result)) end
	end
	local data = sanitize(raw, player.UserId)
	cache[player.UserId] = data
	DataService.Commit(player, false)
	dirty[player.UserId] = false
	return data
end

function DataService.Save(player)
	local data = DataService.Get(player)
	if not data then return false end
	if not persistent() then dirty[player.UserId] = false; return true end
	if not dirty[player.UserId] then return true end
	local snapshot = sanitize(data, player.UserId)
	local ok, err = pcall(function() store:SetAsync("player_" .. player.UserId, snapshot) end)
	if ok then dirty[player.UserId] = false else warn("[SwapPlaces] DataStore save unavailable:", tostring(err)) end
	return ok
end

function DataService.SaveAndClear(player)
	DataService.Save(player)
	cache[player.UserId] = nil
	dirty[player.UserId] = nil
end

function DataService.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do DataService.Save(player) end
end

function DataService.RecordSwap(player)
	local data = DataService.Get(player)
	if data then data.Swaps = data.Swaps + 1; DataService.Commit(player, false) end
end

function DataService.RecordTrade(player)
	local data = DataService.Get(player)
	if data then data.Trades = data.Trades + 1; DataService.Commit(player, false) end
end

function DataService.WasReceiptProcessed(player, receiptId)
	local data = DataService.Get(player)
	return not not (data and type(receiptId) == "string" and data.ProcessedReceipts[receiptId] ~= nil)
end

function DataService.MarkReceiptProcessed(player, receiptId)
	local data = DataService.Get(player)
	if not data or type(receiptId) ~= "string" or #receiptId == 0 or #receiptId > 100 then return false end
	data.ProcessedReceipts[receiptId] = os.time()
	local ordered = {}
	for id, timestamp in pairs(data.ProcessedReceipts) do table.insert(ordered, { Id = id, Time = timestamp }) end
	table.sort(ordered, function(a, b) return a.Time > b.Time end)
	for index = Config.MaxProcessedReceipts + 1, #ordered do data.ProcessedReceipts[ordered[index].Id] = nil end
	DataService.Commit(player, true)
	return true
end

function DataService.Step(deltaTime)
	saveClock = saveClock + deltaTime
	if saveClock < Config.AutosaveInterval then return end
	saveClock = 0
	for _, player in ipairs(Players:GetPlayers()) do DataService.Save(player) end
end

function DataService.Init(dependencies)
	remotes = dependencies.Remotes
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("ProfileLoaded", false)
	end
end

game:BindToClose(function()
	if closing then return end
	DataService.SaveAll()
	closing = true
end)

return DataService
