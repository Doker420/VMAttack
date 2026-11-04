-- Local first-person weapon viewmodel. Server models remain equipped for other players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local state = Shared:WaitForChild("MatchState")

local viewModel
local viewKey

local function clearViewmodel()
	if viewModel then
		viewModel:Destroy()
	end
	viewModel = nil
	viewKey = nil
end

local function ensureViewmodel()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local weaponId = player:GetAttribute("SelectedWeapon") or "Carbine"
	local weapon = Catalog.GetWeapon(weaponId) or Catalog.Weapons.Carbine
	local skin = player:GetAttribute("Cosmetic_WeaponSkin") or "Default"
	local key = weapon.Id .. ":" .. skin
	if viewModel and viewKey == key then
		return
	end
	clearViewmodel()
	local model = WeaponModels.Build(weapon.Id)
	model.Name = "LocalWeaponViewModel"
	WeaponModels.ApplySkin(model, skin)
	if type(model.ScaleTo) == "function" then
		model:ScaleTo(0.55)
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Transparency = 0
			part.LocalTransparencyModifier = 0
		end
	end
	model:SetAttribute("Viewmodel", true)
	model.Parent = camera
	viewModel = model
	viewKey = key
end

RunService.RenderStepped:Connect(function()
	local phase = state:GetAttribute("Phase") or "Lobby"
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if phase ~= "Battle" or not character or not humanoid or humanoid.Health <= 0 then
		clearViewmodel()
		return
	end
	ensureViewmodel()
	local camera = Workspace.CurrentCamera
	if not viewModel or not camera then
		return
	end
	local weapon = Catalog.GetWeapon(player:GetAttribute("SelectedWeapon") or "Carbine") or Catalog.Weapons.Carbine
	local moving = humanoid.MoveDirection and humanoid.MoveDirection.Magnitude > 0.1
	local bob = moving and math.sin(os.clock() * 9) * 0.045 or 0
	local sway = moving and math.cos(os.clock() * 4.5) * 0.025 or 0
	local offset = weapon.Melee and CFrame.new(0.95, -0.85 + bob, -2.1) or CFrame.new(1.15, -0.95 + bob, -2.8)
	viewModel:PivotTo(camera.CFrame * offset * CFrame.Angles(math.rad(-5), sway, math.rad(5)))
end)

player:GetAttributeChangedSignal("SelectedWeapon"):Connect(clearViewmodel)
player:GetAttributeChangedSignal("Cosmetic_WeaponSkin"):Connect(clearViewmodel)
player.CharacterAdded:Connect(function()
	task.defer(clearViewmodel)
end)
