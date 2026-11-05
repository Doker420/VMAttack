-- Applies owned in-game cosmetics to the player's own respawned avatar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("SwapPlaces")
local SkinCatalog = require(Shared:WaitForChild("SkinCatalog"))

local AppearanceService = {}
local dataService

local function addPart(model, anchor, name, size, offset, color, shape, material)
	local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" or shape == "Cylinder" then part.Shape = Enum.PartType[shape] end
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = anchor.CFrame * offset
	part.Parent = model
	local weld = Instance.new("Weld")
	weld.Name = "SkinWeld"
	weld.Part0 = anchor
	weld.Part1 = part
	weld.C0 = offset
	weld.C1 = CFrame.new()
	weld.Parent = part
	return part
end

local function buildAccessory(character, skin)
	local old = character:FindFirstChild("SwapPlacesSkin")
	if old then old:Destroy() end
	if skin.Accessory == "None" then return end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local head = character:FindFirstChild("Head")
	if not torso or not head then return end
	local model = Instance.new("Model")
	model.Name = "SwapPlacesSkin"
	model:SetAttribute("SkinId", skin.Id)
	model.Parent = character
	if skin.Accessory == "Pack" then
		addPart(model, torso, "PackBody", Vector3.new(1.65, 1.8, 0.75), CFrame.new(0, 0, 0.9), skin.Secondary)
		addPart(model, torso, "PackFlap", Vector3.new(1.45, 0.45, 0.82), CFrame.new(0, 0.65, 0.95), skin.Primary)
		for side = -1, 1, 2 do addPart(model, torso, "PackStrap", Vector3.new(0.18, 1.9, 0.18), CFrame.new(side * 0.62, 0, -0.48), skin.Accent) end
	elseif skin.Accessory == "Cape" then
		for index = -1, 1 do
			addPart(model, torso, "CapeStrip", Vector3.new(0.72, 2.8, 0.18), CFrame.new(index * 0.7, -0.75, 0.68) * CFrame.Angles(math.rad(-8), 0, 0), index == 0 and skin.Primary or skin.Secondary, "Wedge")
		end
	elseif skin.Accessory == "Wings" then
		for side = -1, 1, 2 do
			addPart(model, torso, "WingMain", Vector3.new(1.8, 2.5, 0.32), CFrame.new(side * 1.25, 0.35, 0.7) * CFrame.Angles(0, math.rad(side * 24), math.rad(side * -18)), skin.Primary, "Wedge")
			addPart(model, torso, "WingTip", Vector3.new(1.15, 1.55, 0.24), CFrame.new(side * 2.15, -0.2, 0.82) * CFrame.Angles(0, math.rad(side * 32), math.rad(side * -28)), skin.Accent, "Wedge")
		end
	elseif skin.Accessory == "Visor" then
		addPart(model, head, "Visor", Vector3.new(1.35, 0.36, 0.14), CFrame.new(0, 0.15, -0.63), skin.Accent, nil, Enum.Material.Neon)
		for side = -1, 1, 2 do addPart(model, head, "VisorArm", Vector3.new(0.16, 0.22, 0.8), CFrame.new(side * 0.68, 0.15, -0.25), skin.Secondary) end
	elseif skin.Accessory == "Orbit" then
		for index = 0, 5 do
			local angle = index * math.pi / 3
			addPart(model, torso, "OrbitSphere", Vector3.one * 0.42, CFrame.new(math.cos(angle) * 1.8, math.sin(angle * 2) * 0.5, math.sin(angle) * 1.8), skin.Accent, "Ball", Enum.Material.Neon)
		end
	elseif skin.Accessory == "Halo" then
		for index = 0, 9 do
			local angle = index * math.pi / 5
			addPart(model, head, "HaloSegment", Vector3.one * 0.34, CFrame.new(math.cos(angle) * 1.1, 1.35, math.sin(angle) * 1.1), skin.Accent, "Ball", Enum.Material.Neon)
		end
	elseif skin.Accessory == "Crown" then
		addPart(model, head, "CrownBand", Vector3.new(1.55, 0.28, 1.25), CFrame.new(0, 0.9, 0), skin.Secondary, nil, Enum.Material.Metal)
		for index = -2, 2 do
			addPart(model, head, "CrownPoint", Vector3.new(0.28, 0.85 + (2 - math.abs(index)) * 0.18, 0.3), CFrame.new(index * 0.32, 1.35, 0) * CFrame.Angles(0, 0, math.rad(index * -7)), skin.Accent, "Wedge", Enum.Material.Neon)
		end
	end
end

function AppearanceService.Apply(player, character)
	if not player or not character or player:GetAttribute("SwapActive") == true then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	local data = dataService.Get(player)
	local skin = data and SkinCatalog.Get(data.EquippedSkin) or SkinCatalog.Skins.Default
	local ok, description = pcall(function() return Players:GetHumanoidDescriptionFromUserId(player.UserId) end)
	if not ok or not description then
		local fallbackOk, fallback = pcall(function() return humanoid:GetAppliedDescription() end)
		description = fallbackOk and fallback or nil
	end
	if description then
		if skin.Id ~= "Default" then
			description.HeadColor = skin.Primary
			description.TorsoColor = skin.Secondary
			description.LeftArmColor = skin.Primary
			description.RightArmColor = skin.Primary
			description.LeftLegColor = skin.Secondary
			description.RightLegColor = skin.Secondary
		end
		pcall(function() humanoid:ApplyDescription(description) end)
	end
	character:SetAttribute("SkinId", skin.Id)
	buildAccessory(character, skin)
	return true
end

function AppearanceService.Equip(player, skinId)
	local data = dataService.Get(player)
	if not data or not SkinCatalog.Get(skinId) or not data.OwnedSkins[skinId] then return false, "Скин не найден в инвентаре" end
	if player:GetAttribute("SwapActive") then return false, "Сначала вернитесь в своё тело" end
	data.EquippedSkin = skinId
	dataService.Commit(player, false)
	AppearanceService.Apply(player, player.Character)
	return true
end

function AppearanceService.Init(dependencies)
	dataService = dependencies.DataService
end

return AppearanceService
