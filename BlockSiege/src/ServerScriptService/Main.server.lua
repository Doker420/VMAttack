-- BLOCKSIEGE server entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local services = script.Parent:WaitForChild("Services")
local WorldBuilder = require(services:WaitForChild("WorldBuilder"))
local DataService = require(services:WaitForChild("DataService"))
local FortressService = require(services:WaitForChild("FortressService"))
local GeodataService = require(services:WaitForChild("GeodataService"))
local CaptureService = require(services:WaitForChild("CaptureService"))
local NeutralService = require(services:WaitForChild("NeutralService"))
local WeaponService = require(services:WaitForChild("WeaponService"))
local BotService = require(services:WaitForChild("BotService"))
local AbilityService = require(services:WaitForChild("AbilityService"))
local CaseService = require(services:WaitForChild("CaseService"))
local ProgressionService = require(services:WaitForChild("ProgressionService"))
local ShopService = require(services:WaitForChild("ShopService"))
local MatchService = require(services:WaitForChild("MatchService"))

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in ipairs({
	"Notify", "ProfileUpdate", "CaseOpened", "Results", "CombatFX", "BuildFX", "TrapFX", "CaptureFX",
	"LobbyAction", "CaseAction", "FireRequest", "BuildRequest", "BuildPreviewRequest", "BuildPreview", "OpenPanel",
	"ProgressionAction", "ShopAction", "AbilityRequest", "AbilityFX", "AbilityState", "WeaponAction", "ReloadRequest",
}) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = Shared

local state = Instance.new("Folder")
state.Name = "MatchState"
state.Parent = Shared

local world = WorldBuilder.Build()
DataService.Init({ Remotes = remotes })
ProgressionService.Init({ DataService = DataService, WeaponService = WeaponService, Remotes = remotes })
FortressService.Init({ World = world, Remotes = remotes, State = state })
GeodataService.Init({ World = world, FortressService = FortressService, State = state })
WeaponService.Init({ DataService = DataService, FortressService = FortressService, Remotes = remotes })
BotService.Init({ World = world, FortressService = FortressService, WeaponService = WeaponService, GeodataService = GeodataService, CaptureService = CaptureService, AbilityService = AbilityService })
AbilityService.Init({ World = world, Remotes = remotes, State = state, FortressService = FortressService, BotService = BotService, WeaponService = WeaponService })
CaseService.Init({ DataService = DataService, Remotes = remotes })
ShopService.Init({ DataService = DataService, ProgressionService = ProgressionService, Remotes = remotes })
CaptureService.Init({ World = world, State = state, BotService = BotService, Remotes = remotes })
NeutralService.Init({ World = world, State = state, BotService = BotService, DataService = DataService, Remotes = remotes })
MatchService.Init({
	World = world,
	DataService = DataService,
	FortressService = FortressService,
	WeaponService = WeaponService,
	BotService = BotService,
	ProgressionService = ProgressionService,
	CaptureService = CaptureService,
	NeutralService = NeutralService,
	AbilityService = AbilityService,
	Remotes = remotes,
	State = state,
})
CaseService.SetEquipHandler(WeaponService.EquipPlayer)

local function onPlayerAdded(player)
	MatchService.OnPlayerAdded(player)
	task.spawn(function()
		DataService.Load(player)
		if player.Parent then
			MatchService.OnProfileLoaded(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	MatchService.OnPlayerRemoving(player)
	DataService.SaveAndClear(player)
end)

remotes.LobbyAction.OnServerEvent:Connect(function(player, action)
	MatchService.HandleLobbyAction(player, action)
end)
remotes.CaseAction.OnServerEvent:Connect(function(player, action, value)
	CaseService.HandleAction(player, action, value)
end)
remotes.FireRequest.OnServerEvent:Connect(function(player, targetPosition)
	WeaponService.FirePlayer(player, targetPosition)
end)
remotes.ReloadRequest.OnServerEvent:Connect(function(player)
	WeaponService.RequestReload(player)
end)
remotes.AbilityRequest.OnServerEvent:Connect(function(player, slot, targetPosition)
	AbilityService.UsePlayerAbility(player, slot, targetPosition)
end)
remotes.BuildRequest.OnServerEvent:Connect(function(player, kind, position, rotation)
	MatchService.HandleBuild(player, kind, position, rotation)
end)
remotes.BuildPreviewRequest.OnServerEvent:Connect(function(player, kind, position, rotation, requestId)
	MatchService.HandleBuildPreview(player, kind, position, rotation, requestId)
end)
remotes.ProgressionAction.OnServerEvent:Connect(function(player, action, value)
	ProgressionService.HandleAction(player, action, value)
end)
remotes.ShopAction.OnServerEvent:Connect(function(player, action, value)
	ShopService.HandleAction(player, action, value)
end)
world.LootPrompt.Triggered:Connect(function(player)
	remotes.OpenPanel:FireClient(player, "Cases")
end)
world.StartPrompt.Triggered:Connect(function(player)
	MatchService.HandleLobbyAction(player, "QuickStart")
end)
world.UpgradePrompt.Triggered:Connect(function(player)
	remotes.OpenPanel:FireClient(player, "Upgrades")
end)
world.DailyPrompt.Triggered:Connect(function(player)
	remotes.OpenPanel:FireClient(player, "Daily")
end)
world.ShopPrompt.Triggered:Connect(function(player)
	remotes.OpenPanel:FireClient(player, "Shop")
end)
world.DefensePrompt.Triggered:Connect(function(player)
	remotes.OpenPanel:FireClient(player, "Defense")
end)

local accumulator = 0
RunService.Heartbeat:Connect(function(deltaTime)
	accumulator = accumulator + math.min(deltaTime, 0.15)
	while accumulator >= 1 / 20 do
		MatchService.Step(1 / 20)
		GeodataService.Step(1 / 20)
		FortressService.Step(1 / 20)
		BotService.Step(1 / 20)
		AbilityService.Step(1 / 20)
		NeutralService.Step(1 / 20)
		WeaponService.Step(1 / 20)
		CaptureService.Step(1 / 20)
		DataService.Step(1 / 20)
		accumulator = accumulator - 1 / 20
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

print("[BLOCKSIEGE] 6x6 готов · классы, jungle, башни, мины, бомбы и разрушаемые крепости")
