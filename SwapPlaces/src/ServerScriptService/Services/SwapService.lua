-- Consensual Robux avatar/body swaps. ProcessReceipt is the only live grant path.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("SwapPlaces")
local Config = require(Shared:WaitForChild("Config"))

local SwapService = {}
local dataService, remotes
local tradeAvailable = function() return true end
local offers, active, byUser = {}, {}, {}
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

local function aliveCharacter(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and root and humanoid.Health > 0 then return character, humanoid, root end
	return nil
end

local function participantReady(player)
	return player and player.Parent and player:GetAttribute("ProfileLoaded") == true
		and player:GetAttribute("SwapActive") ~= true and tradeAvailable(player)
end

local function publicSession(session)
	local names = {}
	for key, userId in pairs(session.Users) do
		local player = Players:GetPlayerByUserId(userId)
		names[key] = player and player.DisplayName or "Игрок"
	end
	return {
		Id = session.Id, Users = session.Users, Names = names, State = session.State,
		PayerUserId = session.Payer, Price = Config.SwapRobuxPrice,
		StudioTest = RunService:IsStudio() and Config.EnableStudioTestPurchases,
		ExpiresIn = session.State == "Active" and math.max(0, (session.EndsAt or os.clock()) - os.clock()) or math.max(0, (session.ExpiresAt or os.clock()) - os.clock()),
	}
end

local function broadcast(session, kind)
	local payload = publicSession(session)
	payload.Kind = kind or "Update"
	for _, userId in pairs(session.Users) do
		local player = Players:GetPlayerByUserId(userId)
		if player then remotes.SwapFX:FireClient(player, payload) end
	end
end

local function unmap(session)
	offers[session.Id] = nil
	active[session.Id] = nil
	for _, userId in pairs(session.Users) do
		if byUser[userId] == session then byUser[userId] = nil end
	end
end

local function disconnect(session)
	for _, connection in ipairs(session.Connections or {}) do connection:Disconnect() end
	session.Connections = {}
end

local function endActive(session, reason, skipUserId)
	if not session or active[session.Id] ~= session then return false end
	disconnect(session)
	unmap(session)
	for _, userId in pairs(session.Users) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("SwapActive", false)
			player:SetAttribute("SwapPartnerUserId", nil)
			player:SetAttribute("SwapSessionId", nil)
		end
	end
	broadcast(session, "Ended")
	for _, userId in pairs(session.Users) do
		local player = Players:GetPlayerByUserId(userId)
		if player and userId ~= skipUserId then notify(player, reason or "Вы вернулись в своё тело") end
	end
	-- LoadCharacter may yield: session state and notifications are already final.
	for _, userId in pairs(session.Users) do
		local player = Players:GetPlayerByUserId(userId)
		if player and player.Parent and userId ~= skipUserId then
			local ok, err = pcall(function() player:LoadCharacter() end)
			if not ok then warn("[SwapPlaces] Character restore failed:", tostring(err)) end
		end
	end
	return true
end

local function cancel(session, kind)
	if not session or offers[session.Id] ~= session or session.State == "PaymentPending" then return false end
	unmap(session)
	broadcast(session, kind or "Cancelled")
	return true
end

local function setController(player, character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and not root.Anchored then pcall(function() root:SetNetworkOwner(player) end) end
	character:SetAttribute("SwapControllerUserId", player.UserId)
end

local function execute(session, payer, receiptId)
	if not session or offers[session.Id] ~= session then return false end
	if session.State ~= "Accepted" and session.State ~= "PaymentPending" then return false end
	local a = Players:GetPlayerByUserId(session.Users.A)
	local b = Players:GetPlayerByUserId(session.Users.B)
	if not a or not b or not participantReady(a) or not participantReady(b) then return false end
	local charA, humanoidA, rootA = aliveCharacter(a)
	local charB, humanoidB, rootB = aliveCharacter(b)
	if not charA or not charB or charA == charB or rootA.Anchored or rootB.Anchored or charA:GetAttribute("SwapSessionId") or charB:GetAttribute("SwapSessionId") then return false end
	session.State = "Active"
	session.Payer = payer.UserId
	session.ReceiptId = receiptId
	session.EndsAt = os.clock() + Config.SwapDuration
	session.Characters = { [a.UserId] = charB, [b.UserId] = charA }
	for _, player in ipairs({ a, b }) do
		local partner = player == a and b or a
		player:SetAttribute("SwapActive", true)
		player:SetAttribute("SwapPartnerUserId", partner.UserId)
		player:SetAttribute("SwapSessionId", session.Id)
	end
	local ok = pcall(function()
		a.Character = charB
		b.Character = charA
	end)
	if not ok then
		pcall(function() a.Character = charA; b.Character = charB end)
		for _, player in ipairs({ a, b }) do
			player:SetAttribute("SwapActive", false)
			player:SetAttribute("SwapPartnerUserId", nil)
			player:SetAttribute("SwapSessionId", nil)
		end
		session.State = "Accepted"
		return false
	end
	charA:SetAttribute("SwapSessionId", session.Id)
	charB:SetAttribute("SwapSessionId", session.Id)
	setController(a, charB)
	setController(b, charA)
	session.Connections = {
		humanoidA.Died:Connect(function() endActive(session, "Тело погибло · оба игрока возвращаются к своим аватарам") end),
		humanoidB.Died:Connect(function() endActive(session, "Тело погибло · оба игрока возвращаются к своим аватарам") end),
	}
	offers[session.Id] = nil
	active[session.Id] = session
	dataService.RecordSwap(a)
	dataService.RecordSwap(b)
	broadcast(session, "Active")
	notify(a, "Вы управляете телом " .. b.DisplayName .. " · " .. Config.SwapDuration .. " с")
	notify(b, "Вы управляете телом " .. a.DisplayName .. " · " .. Config.SwapDuration .. " с")
	return true
end

function SwapService.Create(player, targetUserId)
	local target = getTarget(player, targetUserId)
	if not target then return false, "Игрок недоступен" end
	if not participantReady(player) or not participantReady(target) then return false, "Оба игрока должны быть готовы" end
	if byUser[player.UserId] or byUser[target.UserId] then return false, "Один из игроков уже участвует в предложении" end
	if not aliveCharacter(player) or not aliveCharacter(target) then return false, "Дождитесь появления обоих персонажей" end
	nextId = nextId + 1
	local session = {
		Id = nextId, Users = { A = player.UserId, B = target.UserId }, State = "Pending",
		ExpiresAt = os.clock() + Config.OfferDuration, Connections = {},
	}
	offers[session.Id] = session
	byUser[player.UserId], byUser[target.UserId] = session, session
	broadcast(session, "Offer")
	return true
end

function SwapService.Accept(player)
	local session = byUser[player.UserId]
	if not session or offers[session.Id] ~= session or session.State ~= "Pending" then return false, "Предложение не найдено" end
	if session.Users.B ~= player.UserId then return false, "Это предложение адресовано другому игроку" end
	if not participantReady(player) or not aliveCharacter(player) then return false, "Сейчас нельзя принять обмен" end
	session.State = "Accepted"
	broadcast(session, "Accepted")
	return true
end

function SwapService.Pay(player)
	local session = byUser[player.UserId]
	if not session or offers[session.Id] ~= session or session.State ~= "Accepted" then return false, "Сначала получите согласие второго игрока" end
	if session.Users.A ~= player.UserId and session.Users.B ~= player.UserId then return false end
	local other = Players:GetPlayerByUserId(session.Users.A == player.UserId and session.Users.B or session.Users.A)
	if not participantReady(player) or not other or not participantReady(other) or not aliveCharacter(player) or not aliveCharacter(other) then return false, "Персонажи больше недоступны" end
	if RunService:IsStudio() and Config.EnableStudioTestPurchases then
		if execute(session, player, nil) then return true end
		return false, "Не удалось выполнить TEST-обмен"
	end
	if Config.SwapProductId <= 0 then return false, "Developer Product ещё не настроен владельцем" end
	session.State = "PaymentPending"
	session.Payer = player.UserId
	session.ProductId = Config.SwapProductId
	broadcast(session, "PaymentPending")
	local ok, err = pcall(function() MarketplaceService:PromptProductPurchase(player, Config.SwapProductId) end)
	if not ok then
		session.State = "Accepted"
		session.Payer = nil
		broadcast(session, "Accepted")
		return false, "Не удалось открыть покупку: " .. tostring(err)
	end
	return true
end

function SwapService.ProcessReceipt(receipt)
	if type(receipt) ~= "table" or Config.SwapProductId <= 0 or receipt.ProductId ~= Config.SwapProductId then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if dataService.WasReceiptProcessed(player, receipt.PurchaseId) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local session = byUser[player.UserId]
	if session and active[session.Id] == session and session.ReceiptId == receipt.PurchaseId then
		return dataService.MarkReceiptProcessed(player, receipt.PurchaseId) and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not session or offers[session.Id] ~= session or session.State ~= "PaymentPending" or session.Payer ~= player.UserId or session.ProductId ~= receipt.ProductId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not execute(session, player, receipt.PurchaseId) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if not dataService.MarkReceiptProcessed(player, receipt.PurchaseId) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function SwapService.OnPromptFinished(player, productId, purchased)
	local session = byUser[player.UserId]
	if not session or offers[session.Id] ~= session or session.State ~= "PaymentPending" or session.Payer ~= player.UserId or session.ProductId ~= productId then return end
	if not purchased then
		session.State = "Accepted"
		session.Payer = nil
		broadcast(session, "Accepted")
	end
end

function SwapService.Revert(player)
	local session = byUser[player.UserId]
	if not session or active[session.Id] ~= session then return false, "Активный обмен не найден" end
	return endActive(session, "Обмен завершён · вы вернулись в своё тело")
end

function SwapService.HandleAction(player, action, value)
	local now = os.clock()
	if now - (lastAction[player.UserId] or 0) < 0.2 then return false, "Подождите мгновение" end
	lastAction[player.UserId] = now
	local result, reason
	if action == "Create" then result, reason = SwapService.Create(player, value)
	elseif action == "Accept" then result, reason = SwapService.Accept(player)
	elseif action == "Pay" then result, reason = SwapService.Pay(player)
	elseif action == "Decline" or action == "Cancel" then
		local session = byUser[player.UserId]
		result = session and cancel(session, action == "Decline" and "Declined" or "Cancelled") or false
		if not result then reason = "Предложение нельзя отменить сейчас" end
	elseif action == "Revert" then result, reason = SwapService.Revert(player)
	else reason = "Неизвестное действие" end
	if not result and reason then notify(player, reason) end
	return result, reason
end

function SwapService.IsAvailable(player)
	return player and byUser[player.UserId] == nil and player:GetAttribute("SwapActive") ~= true
end

function SwapService.GetSession(player)
	return byUser[player.UserId]
end

function SwapService.SetTradeAvailability(provider)
	tradeAvailable = provider or function() return true end
end

function SwapService.OnPlayerRemoving(player)
	lastAction[player.UserId] = nil
	local session = byUser[player.UserId]
	if session and active[session.Id] == session then endActive(session, "Партнёр вышел · вы вернулись в своё тело", player.UserId)
	elseif session and offers[session.Id] == session then
		unmap(session)
		broadcast(session, "Cancelled")
	end
end

function SwapService.Step()
	local now = os.clock()
	for _, session in pairs(offers) do
		if session.State ~= "PaymentPending" and now >= session.ExpiresAt then cancel(session, "Expired") end
	end
	for _, session in pairs(active) do
		local a = Players:GetPlayerByUserId(session.Users.A)
		local b = Players:GetPlayerByUserId(session.Users.B)
		if now >= session.EndsAt then endActive(session, "Время обмена истекло · вы вернулись в своё тело")
		elseif not a or not b then endActive(session, "Партнёр отключился · обмен завершён", not a and session.Users.A or session.Users.B) end
	end
end

function SwapService.Init(dependencies)
	dataService = dependencies.DataService
	remotes = dependencies.Remotes
	MarketplaceService.ProcessReceipt = function(receipt) return SwapService.ProcessReceipt(receipt) end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, purchased)
		SwapService.OnPromptFinished(player, productId, purchased)
	end)
end

return SwapService
