-- Cosmetic-only Robux shop. Game Pass IDs are deliberately zero until configured by the owner.
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local ShopService = {}
local DataService
local ProgressionService
local remotes
local promptConnected = false

local function notify(player, text, color)
	if remotes and player.Parent then
		remotes.Notify:FireClient(player, text, color)
	end
end

local function grant(player, id)
	local data = DataService and DataService.Get(player)
	local cosmetic = Catalog.GetCosmetic(id)
	if not data or not cosmetic then
		return false
	end
	if not data.OwnedCosmetics[id] then
		data.OwnedCosmetics[id] = true
		data.SelectedCosmetics[cosmetic.Slot] = id
		DataService.Commit(player, true)
		ProgressionService.Refresh(player)
	end
	notify(player, "Получено: " .. cosmetic.Name, Color3.fromRGB(255, 215, 110))
	return true
end

function ShopService.GrantForTesting(player, id)
	if not RunService:IsStudio() or not Config.EnableStudioTestPurchases then
		return false
	end
	return grant(player, id)
end

function ShopService.Init(dependencies)
	DataService = dependencies.DataService
	ProgressionService = dependencies.ProgressionService
	remotes = dependencies.Remotes
	if not promptConnected then
		promptConnected = true
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
			if not purchased then
				return
			end
			for _, id in ipairs(Catalog.CosmeticOrder) do
				local cosmetic = Catalog.Cosmetics[id]
				if cosmetic.GamePassId ~= 0 and cosmetic.GamePassId == gamePassId then
					grant(player, id)
					break
				end
			end
		end)
	end
end

function ShopService.Buy(player, id)
	local cosmetic = Catalog.GetCosmetic(id)
	local data = DataService and DataService.Get(player)
	if not cosmetic or not data then
		return false
	end
	if data.OwnedCosmetics[id] then
		return ProgressionService.EquipCosmetic(player, id)
	end
	if cosmetic.GamePassId == 0 then
		if RunService:IsStudio() and Config.EnableStudioTestPurchases then
			notify(player, "Studio TEST: выдача без Robux", Color3.fromRGB(255, 210, 100))
			return grant(player, id)
		end
		notify(player, "Game Pass ещё не настроен владельцем игры", Color3.fromRGB(255, 170, 100))
		return false
	end
	local owns = false
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, cosmetic.GamePassId)
	end)
	if ok then
		owns = result == true
	end
	if owns then
		return grant(player, id)
	end
	local prompted, promptError = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, cosmetic.GamePassId)
	end)
	if not prompted then
		notify(player, "Покупка недоступна: " .. tostring(promptError), Color3.fromRGB(255, 120, 110))
		return false
	end
	notify(player, "Открыто окно покупки " .. cosmetic.Name, Color3.fromRGB(255, 215, 110))
	return true
end

function ShopService.HandleAction(player, action, value)
	if action == "BuyCosmetic" then
		return ShopService.Buy(player, value)
	elseif action == "TestPurchase" then
		return ShopService.GrantForTesting(player, value)
	end
	return false
end

return ShopService
