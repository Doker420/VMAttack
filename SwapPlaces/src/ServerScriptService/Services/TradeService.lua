-- Consensual one-for-one trades of owned in-game skins. No copies or client rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("SwapPlaces")
local Config = require(Shared:WaitForChild("Config"))
local SkinCatalog = require(Shared:WaitForChild("SkinCatalog"))

local TradeService = {}
local dataService, appearanceService, remotes
local swapAvailable = function() return true end
local sessions = {}
local byUser = {}
local nextId = 0
local lastAction = {}

local function getTarget(player, targetUserId)
	if type(targetUserId) ~= "number" or targetUserId < 1 or targetUserId > 9007199254740991 or targetUserId % 1 ~= 0 then return nil end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then return nil end
	return target
end

local function notify(player, text)
	if player and player.Parent then remotes.Notify:FireClient(player, text) end
end

local function baseAvailable(player)
	return player and player.Parent and player:GetAttribute("ProfileLoaded") == true
		and player:GetAttribute("SwapActive") ~= true and swapAvailable(player)
end

local function publicSession(session)
	local selected, confirmed, names = {}, {}, {}
	for key, userId in pairs(session.Users) do
		local player = Players:GetPlayerByUserId(userId)
		names[key] = player and player.DisplayName or "Игрок"
		if session.Selected[userId] then selected[key] = session.Selected[userId] end
		if session.Confirmed[userId] then confirmed[key] = true end
	end
	return { Id = session.Id, Users = session.Users, Names = names, Selected = selected, Confirmed = confirmed, ExpiresIn = math.max(0, session.ExpiresAt - os.clock()) }
end

local function broadcast(session, kind)
	local payload = publicSession(session)
	payload.Kind = kind or "Update"
	for _, userId in pairs(session.Users) do
		local player = Players:GetPlayerByUserId(userId)
		if player then remotes.TradeFX:FireClient(player, payload) end
	end
end

local function remove(session, kind)
	if not session or sessions[session.Id] ~= session then return end
	sessions[session.Id] = nil
	for _, userId in pairs(session.Users) do byUser[userId] = nil end
	if kind then broadcast(session, kind) end
end

local function execute(session)
	if not session or sessions[session.Id] ~= session then return false end
	local a = Players:GetPlayerByUserId(session.Users.A)
	local b = Players:GetPlayerByUserId(session.Users.B)
	local skinA, skinB = session.Selected[session.Users.A], session.Selected[session.Users.B]
	if not a or not b or not baseAvailable(a) or not baseAvailable(b) or not skinA or not skinB or skinA == skinB then return false end
	local dataA, dataB = dataService.Get(a), dataService.Get(b)
	if not dataA or not dataB or not dataA.OwnedSkins[skinA] or not dataB.OwnedSkins[skinB] or not SkinCatalog.IsTradable(skinA) or not SkinCatalog.IsTradable(skinB) then return false end
	-- Commit both ownership changes as one in-memory transaction after every check.
	dataA.OwnedSkins[skinA] = nil
	dataB.OwnedSkins[skinB] = nil
	dataA.OwnedSkins[skinB] = true
	dataB.OwnedSkins[skinA] = true
	if dataA.EquippedSkin == skinA then dataA.EquippedSkin = "Default" end
	if dataB.EquippedSkin == skinB then dataB.EquippedSkin = "Default" end
	remove(session, nil)
	dataService.RecordTrade(a)
	dataService.RecordTrade(b)
	for _, player in ipairs({ a, b }) do
		if player.Parent then
			remotes.TradeFX:FireClient(player, { Kind = "Completed", SessionId = session.Id, Given = player == a and skinA or skinB, Received = player == a and skinB or skinA })
		end
	end
	-- Cosmetic/DataStore operations come after the atomic ownership commit and notifications.
	if a.Parent then appearanceService.Apply(a, a.Character) end
	if b.Parent then appearanceService.Apply(b, b.Character) end
	return true
end

function TradeService.Create(player, targetUserId)
	local target = getTarget(player, targetUserId)
	if not target then return false, "Игрок недоступен" end
	if not baseAvailable(player) or not baseAvailable(target) then return false, "Оба игрока должны быть свободны" end
	if byUser[player.UserId] or byUser[target.UserId] then return false, "Один из игроков уже обменивается" end
	nextId = nextId + 1
	local session = {
		Id = nextId,
		Users = { A = player.UserId, B = target.UserId },
		Selected = {}, Confirmed = {},
		ExpiresAt = os.clock() + Config.TradeDuration,
	}
	sessions[session.Id] = session
	byUser[player.UserId], byUser[target.UserId] = session, session
	broadcast(session, "Started")
	return true
end

function TradeService.Select(player, skinId)
	local session = byUser[player.UserId]
	local data = dataService.Get(player)
	if not session or not data then return false, "Обмен не найден" end
	if not SkinCatalog.IsTradable(skinId) or not data.OwnedSkins[skinId] then return false, "Этот скин нельзя предложить" end
	if not baseAvailable(player) then return false, "Сейчас нельзя менять предложение" end
	session.Selected[player.UserId] = skinId
	session.Confirmed = {}
	broadcast(session, "Update")
	return true
end

function TradeService.Confirm(player)
	local session = byUser[player.UserId]
	if not session then return false, "Обмен не найден" end
	if not baseAvailable(player) then return false, "Сейчас нельзя подтвердить" end
	local selectedA = session.Selected[session.Users.A]
	local selectedB = session.Selected[session.Users.B]
	if not selectedA or not selectedB then return false, "Оба игрока должны выбрать скин" end
	if selectedA == selectedB then return false, "Выберите разные скины" end
	session.Confirmed[player.UserId] = true
	if not (session.Confirmed[session.Users.A] and session.Confirmed[session.Users.B]) then
		broadcast(session, "Update")
		return true
	end
	if not execute(session) then
		session.Confirmed = {}
		broadcast(session, "Update")
		return false, "Предложение устарело · выберите скины заново"
	end
	return true
end

function TradeService.Cancel(player)
	local session = byUser[player.UserId]
	if not session then return false, "Обмен не найден" end
	remove(session, "Cancelled")
	return true
end

function TradeService.HandleAction(player, action, value)
	local now = os.clock()
	if now - (lastAction[player.UserId] or 0) < 0.15 then return false, "Подождите мгновение" end
	lastAction[player.UserId] = now
	local result, reason
	if action == "Create" then result, reason = TradeService.Create(player, value)
	elseif action == "Select" then result, reason = TradeService.Select(player, value)
	elseif action == "Confirm" then result, reason = TradeService.Confirm(player)
	elseif action == "Cancel" then result, reason = TradeService.Cancel(player)
	else reason = "Неизвестное действие" end
	if not result and reason then notify(player, reason) end
	return result, reason
end

function TradeService.IsBusy(player)
	return byUser[player.UserId] ~= nil
end

function TradeService.GetSession(player)
	return byUser[player.UserId]
end

function TradeService.SetSwapAvailability(provider)
	swapAvailable = provider or function() return true end
end

function TradeService.OnPlayerRemoving(player)
	lastAction[player.UserId] = nil
	local session = byUser[player.UserId]
	if session then remove(session, "Cancelled") end
end

function TradeService.Step()
	local now = os.clock()
	for _, session in pairs(sessions) do
		if now >= session.ExpiresAt then remove(session, "Expired") end
	end
end

function TradeService.Init(dependencies)
	dataService = dependencies.DataService
	appearanceService = dependencies.AppearanceService
	remotes = dependencies.Remotes
end

return TradeService
