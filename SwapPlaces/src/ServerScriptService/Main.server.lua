-- «Поменяйся местами» server entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("SwapPlaces")
local services = script.Parent:WaitForChild("Services")
local WorldBuilder = require(services:WaitForChild("WorldBuilder"))
local DataService = require(services:WaitForChild("DataService"))
local AppearanceService = require(services:WaitForChild("AppearanceService"))
local TradeService = require(services:WaitForChild("TradeService"))
local SwapService = require(services:WaitForChild("SwapService"))

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({ "Notify", "ProfileUpdate", "SwapAction", "SwapFX", "TradeAction", "TradeFX", "InventoryAction", "UIFX" }) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = Shared

local world = WorldBuilder.Build()
DataService.Init({ Remotes = remotes })
AppearanceService.Init({ DataService = DataService })
TradeService.Init({ DataService = DataService, AppearanceService = AppearanceService, Remotes = remotes })
SwapService.Init({ DataService = DataService, Remotes = remotes })
TradeService.SetSwapAvailability(SwapService.IsAvailable)
SwapService.SetTradeAvailability(function(player) return not TradeService.IsBusy(player) end)

local function notify(player, text)
	if player and player.Parent then remotes.Notify:FireClient(player, text) end
end

local function onPlayerAdded(player)
	player:SetAttribute("ProfileLoaded", false)
	player:SetAttribute("SwapActive", false)
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if player.Parent and player.Character == character and player:GetAttribute("SwapActive") ~= true then
				AppearanceService.Apply(player, character)
			end
		end)
	end)
	task.spawn(function()
		DataService.Load(player)
		if player.Parent then AppearanceService.Apply(player, player.Character) end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	SwapService.OnPlayerRemoving(player)
	TradeService.OnPlayerRemoving(player)
	DataService.SaveAndClear(player)
end)

remotes.SwapAction.OnServerEvent:Connect(function(player, action, value)
	SwapService.HandleAction(player, action, value)
end)
remotes.TradeAction.OnServerEvent:Connect(function(player, action, value)
	TradeService.HandleAction(player, action, value)
end)
remotes.InventoryAction.OnServerEvent:Connect(function(player, action, value)
	if action == "Equip" then
		local ok, reason = AppearanceService.Equip(player, value)
		if not ok and reason then notify(player, reason) end
	else
		notify(player, "Неизвестное действие гардероба")
	end
end)

world.SwapPrompt.Triggered:Connect(function(player) remotes.UIFX:FireClient(player, { Kind = "OpenSwap" }) end)
world.TradePrompt.Triggered:Connect(function(player) remotes.UIFX:FireClient(player, { Kind = "OpenTrade" }) end)
for id, proximity in pairs(world.SkinPrompts) do
	proximity.Triggered:Connect(function(player) remotes.UIFX:FireClient(player, { Kind = "OpenInventory", SkinId = id }) end)
end

local accumulator = 0
RunService.Heartbeat:Connect(function(deltaTime)
	accumulator = accumulator + math.min(deltaTime, 0.15)
	while accumulator >= 1 / 20 do
		SwapService.Step(1 / 20)
		TradeService.Step(1 / 20)
		DataService.Step(1 / 20)
		accumulator = accumulator - 1 / 20
	end
end)

for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end
print("[SwapPlaces] ПОМЕНЯЙСЯ МЕСТАМИ · consensual avatar swaps + one-for-one skin trades")
