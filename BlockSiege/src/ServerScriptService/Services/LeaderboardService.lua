-- BLOCKSIEGE // Server-generated online Level/Coins ratings.
-- OrderedDataStore/global history is intentionally not faked: this board ranks
-- loaded online profiles and can be backed by a persistent service later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))

local LeaderboardService = {}
local DataService
local remotes
local state
local clock = 0
local signature = ""
local revision = 0

local function entryFor(player, data)
	return {
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Level = Catalog.LevelForXP(data.XP or 0),
		XP = data.XP or 0,
		Coins = data.Coins or 0,
		Wins = data.Wins or 0,
	}
end

local function copyTop(entries, valueKey)
	local result = {}
	for index = 1, math.min(10, #entries) do
		local source = entries[index]
		result[index] = {
			Rank = index,
			UserId = source.UserId,
			Name = source.Name,
			DisplayName = source.DisplayName,
			Value = source[valueKey],
			Level = source.Level,
			Coins = source.Coins,
			Wins = source.Wins,
		}
	end
	return result
end

function LeaderboardService.GetSnapshot()
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService and DataService.Get(player) or nil
		if data then
			table.insert(entries, entryFor(player, data))
		end
	end
	local levels = { table.unpack(entries) }
	local coins = { table.unpack(entries) }
	table.sort(levels, function(a, b)
		if a.Level ~= b.Level then return a.Level > b.Level end
		if a.XP ~= b.XP then return a.XP > b.XP end
		if a.Coins ~= b.Coins then return a.Coins > b.Coins end
		return a.UserId < b.UserId
	end)
	table.sort(coins, function(a, b)
		if a.Coins ~= b.Coins then return a.Coins > b.Coins end
		if a.Level ~= b.Level then return a.Level > b.Level end
		if a.Wins ~= b.Wins then return a.Wins > b.Wins end
		return a.UserId < b.UserId
	end)
	return { Revision = revision, Level = copyTop(levels, "Level"), Coins = copyTop(coins, "Coins") }
end

local function snapshotSignature(snapshot)
	local pieces = {}
	for _, board in ipairs({ snapshot.Level, snapshot.Coins }) do
		for _, entry in ipairs(board) do
			table.insert(pieces, table.concat({ entry.UserId, entry.Value, entry.Level, entry.Coins, entry.Wins }, ":"))
		end
		table.insert(pieces, "|")
	end
	return table.concat(pieces, ";")
end

function LeaderboardService.Broadcast(force)
	if not remotes then
		return
	end
	local snapshot = LeaderboardService.GetSnapshot()
	local nextSignature = snapshotSignature(snapshot)
	if force or nextSignature ~= signature then
		signature = nextSignature
		revision = revision + 1
		snapshot.Revision = revision
		remotes.LeaderboardUpdate:FireAllClients(snapshot)
		if state then
			local levelTop = snapshot.Level[1]
			local coinTop = snapshot.Coins[1]
			state:SetAttribute("LevelLeader", levelTop and levelTop.DisplayName or "—")
			state:SetAttribute("CoinLeader", coinTop and coinTop.DisplayName or "—")
		end
	end
end

function LeaderboardService.Init(dependencies)
	DataService = dependencies.DataService
	remotes = dependencies.Remotes
	state = dependencies.State
	clock = 0
end

function LeaderboardService.Step(deltaTime)
	clock = clock + deltaTime
	if clock >= 2 then
		clock = 0
		LeaderboardService.Broadcast(false)
	end
end

return LeaderboardService
