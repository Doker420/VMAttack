-- Процедурные voxel-модели оружия. Одна и та же модель используется в руках и на витрине.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))

local WeaponModels = {}
local DARK = Color3.fromRGB(43, 51, 52)
local METAL = Color3.fromRGB(103, 116, 115)
local WOOD = Color3.fromRGB(155, 105, 54)
local LIGHT = Color3.fromRGB(238, 241, 218)

local function block(model, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0
	part.CastShadow = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

function WeaponModels.Build(weaponId)
	local weapon = Catalog.GetWeapon(weaponId) or Catalog.Weapons.Carbine
	local model = Instance.new("Model")
	model.Name = "Weapon_" .. weapon.Id
	model:SetAttribute("WeaponId", weapon.Id)
	local accent = weapon.Color
	local handle = block(model, "Handle", Vector3.new(0.72, 1.15, 0.82), CFrame.new(0, -0.2, 0.25), WOOD, Enum.Material.WoodPlanks)
	model.PrimaryPart = handle

	if weapon.Model == "SMG" then
		block(model, "Body", Vector3.new(1.05, 0.75, 2.15), CFrame.new(0, 0.35, -0.75), accent)
		block(model, "Barrel", Vector3.new(0.38, 0.38, 1.65), CFrame.new(0, 0.42, -2.5), METAL, Enum.Material.Metal)
		block(model, "Magazine", Vector3.new(0.62, 1.35, 0.72), CFrame.new(0, -0.45, -0.85), DARK)
		block(model, "Stock", Vector3.new(0.82, 0.65, 1.1), CFrame.new(0, 0.3, 0.95), DARK)
		block(model, "Sight", Vector3.new(0.35, 0.35, 0.65), CFrame.new(0, 0.92, -0.85), LIGHT)
	elseif weapon.Model == "Scatter" then
		block(model, "Body", Vector3.new(1.4, 0.9, 2.1), CFrame.new(0, 0.35, -0.75), accent)
		for _, side in ipairs({ -1, 1 }) do
			block(model, "TwinBarrel", Vector3.new(0.48, 0.48, 2.7), CFrame.new(side * 0.34, 0.48, -2.55), METAL, Enum.Material.Metal)
			block(model, "Muzzle", Vector3.new(0.58, 0.58, 0.35), CFrame.new(side * 0.34, 0.48, -4), DARK)
		end
		block(model, "Pump", Vector3.new(1.25, 0.58, 0.9), CFrame.new(0, -0.05, -2), WOOD, Enum.Material.WoodPlanks)
		block(model, "Stock", Vector3.new(1.05, 0.8, 1.35), CFrame.new(0, 0.15, 1), WOOD, Enum.Material.WoodPlanks)
	elseif weapon.Model == "Marksman" then
		block(model, "Body", Vector3.new(0.95, 0.72, 3), CFrame.new(0, 0.35, -1.2), accent)
		block(model, "LongBarrel", Vector3.new(0.3, 0.3, 3.6), CFrame.new(0, 0.43, -4.35), METAL, Enum.Material.Metal)
		block(model, "Scope", Vector3.new(0.52, 0.52, 1.8), CFrame.new(0, 1.05, -1.35), DARK)
		block(model, "ScopeGlass", Vector3.new(0.58, 0.58, 0.18), CFrame.new(0, 1.05, -2.28), LIGHT, Enum.Material.Glass)
		block(model, "Bipod", Vector3.new(1.8, 0.18, 0.25), CFrame.new(0, -0.2, -3.25), DARK)
		block(model, "Stock", Vector3.new(0.85, 0.85, 1.3), CFrame.new(0, 0.18, 1), WOOD, Enum.Material.WoodPlanks)
	elseif weapon.Model == "Demolisher" then
		block(model, "HeavyBody", Vector3.new(1.75, 1.3, 2.7), CFrame.new(0, 0.45, -1), accent, Enum.Material.Metal)
		for _, x in ipairs({ -0.48, 0.48 }) do
			for _, y in ipairs({ 0.12, 0.82 }) do
				block(model, "QuadBarrel", Vector3.new(0.52, 0.52, 2.2), CFrame.new(x, y, -3.35), DARK, Enum.Material.Metal)
			end
		end
		block(model, "Armor", Vector3.new(2.05, 0.35, 1.8), CFrame.new(0, 1.25, -0.9), METAL, Enum.Material.DiamondPlate)
		block(model, "Counterweight", Vector3.new(1.5, 1.1, 1.1), CFrame.new(0, 0.25, 0.95), DARK)
	elseif weapon.Model == "Rail" then
		block(model, "RailBody", Vector3.new(1.15, 0.82, 3.4), CFrame.new(0, 0.4, -1.4), accent, Enum.Material.Metal)
		block(model, "RailBarrel", Vector3.new(0.32, 0.32, 5.2), CFrame.new(0, 0.45, -5.6), LIGHT, Enum.Material.Neon)
		for index = 0, 4 do
			block(model, "Coil", Vector3.new(1.35, 1.35, 0.28), CFrame.new(0, 0.45, -3.25 - index * 0.85), DARK, Enum.Material.Metal)
		end
		block(model, "RailSight", Vector3.new(0.45, 0.65, 1.2), CFrame.new(0, 1.12, -1.3), LIGHT)
		block(model, "Stock", Vector3.new(1, 0.9, 1.25), CFrame.new(0, 0.2, 1), DARK)
	elseif weapon.Model == "Vortex" then
		block(model, "VortexBody", Vector3.new(1.35, 1.05, 2.5), CFrame.new(0, 0.4, -1), accent, Enum.Material.Metal)
		block(model, "VortexBarrel", Vector3.new(0.72, 0.72, 2.5), CFrame.new(0, 0.45, -3.4), DARK, Enum.Material.Metal)
		for index = 0, 2 do
			block(model, "EnergyRing", Vector3.new(1.4 - index * 0.15, 1.4 - index * 0.15, 0.25), CFrame.new(0, 0.45, -2.45 - index * 0.75), LIGHT, Enum.Material.Neon)
		end
		for _, side in ipairs({ -1, 1 }) do
			block(model, "VortexFin", Vector3.new(0.3, 1.2, 1.7), CFrame.new(side * 0.9, 0.55, -1.15) * CFrame.Angles(0, 0, math.rad(side * 18)), accent)
		end
		block(model, "VortexStock", Vector3.new(1.1, 0.8, 1.2), CFrame.new(0, 0.25, 0.85), DARK)
	elseif weapon.Model == "Gauntlet" then
		handle.Color = Color3.fromRGB(164, 112, 38)
		handle.Material = Enum.Material.Metal
		block(model, "GauntletCuff", Vector3.new(2.5, 1.55, 1.4), CFrame.new(0, 0.05, 0.25), accent, Enum.Material.Metal)
		block(model, "GauntletPalm", Vector3.new(2.25, 1.8, 2), CFrame.new(0, 0.55, -1.15), accent, Enum.Material.Metal)
		block(model, "PalmPlate", Vector3.new(1.65, 0.35, 1.5), CFrame.new(0, 1.55, -1.2), Color3.fromRGB(255, 220, 104), Enum.Material.DiamondPlate)
		for index = 0, 3 do
			local x = -0.78 + index * 0.52
			block(model, "GauntletFinger", Vector3.new(0.44, 0.62, 1.65), CFrame.new(x, 0.85, -2.75), accent, Enum.Material.Metal)
			block(model, "GauntletKnuckle", Vector3.new(0.5, 0.7, 0.65), CFrame.new(x, 1.05, -3.65), Color3.fromRGB(255, 214, 91), Enum.Material.Metal)
		end
		block(model, "GauntletThumb", Vector3.new(0.7, 0.75, 1.5), CFrame.new(1.35, 0.3, -1.65) * CFrame.Angles(0, math.rad(-24), 0), accent, Enum.Material.Metal)
		local gemColors = {
			Color3.fromRGB(255, 80, 70), Color3.fromRGB(70, 160, 255), Color3.fromRGB(105, 240, 130),
			Color3.fromRGB(190, 95, 255), Color3.fromRGB(255, 205, 60), Color3.fromRGB(255, 125, 45),
		}
		for index, gemColor in ipairs(gemColors) do
			local x = -0.65 + ((index - 1) % 3) * 0.65
			local z = index <= 3 and -0.85 or -1.65
			local gem = block(model, "InfinityGem", Vector3.new(0.42, 0.28, 0.42), CFrame.new(x, 1.78, z), gemColor, Enum.Material.Neon)
			if index == 1 then
				local glow = Instance.new("PointLight")
				glow.Name = "InfinityGlow"
				glow.Color = Color3.fromRGB(203, 126, 255)
				glow.Brightness = 1.4
				glow.Range = 8
				glow.Parent = gem
			end
		end
		block(model, "InfinityScope", Vector3.new(0.5, 0.5, 2.6), CFrame.new(0, 2.05, -1.75), Color3.fromRGB(188, 104, 255), Enum.Material.Neon)
		block(model, "InfinityEmitter", Vector3.new(0.8, 0.8, 1.4), CFrame.new(0, 0.55, -4.45), Color3.fromRGB(222, 173, 255), Enum.Material.Neon)
	elseif weapon.Model == "PrismLance" then
		handle.Color = DARK
		handle.Material = Enum.Material.Metal
		block(model, "PrismReceiver", Vector3.new(1.35, 0.95, 3.2), CFrame.new(0, 0.35, -1.15), DARK, Enum.Material.Metal)
		block(model, "PrismBarrel", Vector3.new(0.48, 0.48, 4.6), CFrame.new(0, 0.5, -4.5), accent, Enum.Material.Neon)
		block(model, "PrismScope", Vector3.new(0.62, 0.62, 2.2), CFrame.new(0, 1.12, -1.45), METAL, Enum.Material.Metal)
		block(model, "PrismLens", Vector3.new(0.7, 0.7, 0.22), CFrame.new(0, 1.12, -2.58), Color3.fromRGB(221, 252, 255), Enum.Material.Glass)
		for index = 0, 4 do
			local shardColor = index % 2 == 0 and accent or Color3.fromRGB(206, 119, 255)
			block(model, "PrismShard", Vector3.new(0.72, 0.72, 1.1), CFrame.new(0, 0.55, -2.25 - index * 0.78) * CFrame.Angles(0, math.rad(index * 19), math.rad(45)), shardColor, Enum.Material.Neon)
		end
		for _, side in ipairs({ -1, 1 }) do
			block(model, "PrismFin", Vector3.new(0.25, 1.1, 2.2), CFrame.new(side * 0.88, 0.45, -1.2) * CFrame.Angles(0, 0, math.rad(side * 22)), accent, Enum.Material.Metal)
		end
		block(model, "PrismStock", Vector3.new(1.05, 0.8, 1.3), CFrame.new(0, 0.2, 0.95), DARK, Enum.Material.Metal)
	elseif weapon.Model == "TeslaCarbine" then
		handle.Color = DARK
		block(model, "TeslaBody", Vector3.new(1.45, 1.05, 2.7), CFrame.new(0, 0.4, -1), accent, Enum.Material.Metal)
		block(model, "TeslaBarrel", Vector3.new(0.5, 0.5, 2.8), CFrame.new(0, 0.45, -3.55), DARK, Enum.Material.Metal)
		for index = 0, 3 do
			block(model, "TeslaCoil", Vector3.new(1.55, 1.55, 0.28), CFrame.new(0, 0.5, -1.65 - index * 0.63), METAL, Enum.Material.Metal)
			block(model, "TeslaGlow", Vector3.new(0.72, 0.72, 0.34), CFrame.new(0, 0.5, -1.65 - index * 0.63), accent, Enum.Material.Neon)
		end
		for _, side in ipairs({ -1, 1 }) do
			block(model, "TeslaElectrode", Vector3.new(0.3, 0.3, 2.4), CFrame.new(side * 0.55, 0.7, -4.15) * CFrame.Angles(0, math.rad(side * 8), 0), LIGHT, Enum.Material.Metal)
			block(model, "TeslaArc", Vector3.new(0.18, 0.18, 1.8), CFrame.new(side * 0.45, 1.1, -3.2) * CFrame.Angles(0, 0, math.rad(side * 28)), accent, Enum.Material.Neon)
		end
		block(model, "TeslaCapacitor", Vector3.new(0.9, 1.4, 0.9), CFrame.new(0, -0.4, -0.75), Color3.fromRGB(48, 104, 137), Enum.Material.DiamondPlate)
		block(model, "TeslaSight", Vector3.new(0.42, 0.55, 0.9), CFrame.new(0, 1.15, -0.8), LIGHT, Enum.Material.Neon)
	elseif weapon.Model == "MeteorMaul" then
		handle.Size = Vector3.new(0.68, 3.4, 0.68)
		handle.CFrame = CFrame.new(0, 0.15, 0.55)
		handle.Color = DARK
		handle.Material = Enum.Material.WoodPlanks
		block(model, "MaulGrip", Vector3.new(0.86, 1.1, 0.86), CFrame.new(0, -0.85, 0.55), accent, Enum.Material.Fabric)
		block(model, "MeteorHead", Vector3.new(3.5, 2.35, 2.35), CFrame.new(0, 1.65, -1.45), DARK, Enum.Material.Cobblestone)
		block(model, "MeteorCore", Vector3.new(1.55, 1.55, 0.5), CFrame.new(0, 1.65, -2.7), accent, Enum.Material.Neon)
		block(model, "MeteorBand", Vector3.new(3.7, 0.42, 2.5), CFrame.new(0, 1.65, -1.45), METAL, Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			block(model, "MeteorSpike", Vector3.new(0.7, 0.7, 1.7), CFrame.new(side * 2, 1.65, -1.45) * CFrame.Angles(0, math.rad(side * 90), 0), accent, Enum.Material.Metal)
			block(model, "MeteorFragment", Vector3.new(0.75, 0.75, 0.75), CFrame.new(side * 1.15, 3.05, -1.25) * CFrame.Angles(0, math.rad(25), math.rad(35)), accent, Enum.Material.Neon)
		end
	elseif weapon.Model == "VoidScythe" then
		handle.Size = Vector3.new(0.55, 3.8, 0.55)
		handle.CFrame = CFrame.new(0, 0.1, 0.5)
		handle.Color = DARK
		handle.Material = Enum.Material.Metal
		block(model, "VoidGrip", Vector3.new(0.72, 1.1, 0.72), CFrame.new(0, -1.15, 0.5), accent, Enum.Material.Fabric)
		local orb = block(model, "VoidOrb", Vector3.new(1.25, 1.25, 1.25), CFrame.new(0, 1.75, -0.35), accent, Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		for index = 0, 4 do
			local x = 0.55 + index * 0.58
			local y = 1.85 + math.sin(index * 0.65) * 0.45
			local z = -1.1 - index * 0.25
			block(model, "VoidBlade", Vector3.new(1.35, 0.3, 0.62), CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(-18 - index * 9), math.rad(index * 7)), DARK, Enum.Material.Metal)
			block(model, "VoidEdge", Vector3.new(1.4, 0.12, 0.18), CFrame.new(x, y + 0.22, z - 0.25) * CFrame.Angles(0, math.rad(-18 - index * 9), math.rad(index * 7)), accent, Enum.Material.Neon)
		end
		block(model, "VoidCounterweight", Vector3.new(0.95, 0.95, 0.95), CFrame.new(0, -1.95, 0.5), accent, Enum.Material.Neon)
	elseif weapon.Model == "Knife" or weapon.Model == "DualKnives" then
		handle.Color = DARK
		handle.Material = Enum.Material.Fabric
		local sides = weapon.Model == "DualKnives" and { -1, 1 } or { 1 }
		for _, side in ipairs(sides) do
			local x = weapon.Model == "DualKnives" and side * 0.7 or 0
			local rotation = weapon.Model == "DualKnives" and CFrame.Angles(0, math.rad(side * 12), math.rad(side * 8)) or CFrame.new()
			block(model, "KnifeGuard", Vector3.new(1.35, 0.28, 0.45), CFrame.new(x, 0.15, -0.75) * rotation, accent, Enum.Material.Metal)
			block(model, "KnifeBlade", Vector3.new(0.62, 0.22, 3.3), CFrame.new(x, 0.35, -2.55) * rotation, Color3.fromRGB(190, 211, 218), Enum.Material.Metal)
			block(model, "KnifeTip", Vector3.new(0.32, 0.16, 1.1), CFrame.new(x, 0.35, -4.65) * rotation, LIGHT, Enum.Material.Metal)
			block(model, "BladeEdge", Vector3.new(0.12, 0.28, 3.8), CFrame.new(x + 0.31, 0.35, -2.8) * rotation, accent, Enum.Material.Neon)
		end
	else
		block(model, "Body", Vector3.new(1.15, 0.82, 2.6), CFrame.new(0, 0.35, -1), accent)
		block(model, "Barrel", Vector3.new(0.42, 0.42, 2.25), CFrame.new(0, 0.43, -3.35), METAL, Enum.Material.Metal)
		block(model, "Muzzle", Vector3.new(0.62, 0.62, 0.45), CFrame.new(0, 0.43, -4.55), DARK)
		block(model, "Magazine", Vector3.new(0.68, 1.25, 0.8), CFrame.new(0, -0.4, -1.05), DARK)
		block(model, "Stock", Vector3.new(0.95, 0.72, 1.25), CFrame.new(0, 0.25, 0.95), WOOD, Enum.Material.WoodPlanks)
		block(model, "Sight", Vector3.new(0.4, 0.4, 0.7), CFrame.new(0, 0.95, -1.15), LIGHT)
	end
	return model
end

function WeaponModels.ApplySkin(model, skinId)
	if not model or skinId ~= "GoldenArsenal" then
		return
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = Color3.fromRGB(244, 190, 55)
			part.Material = Enum.Material.Metal
			if part.Name == "Sight" or part.Name == "ScopeGlass" or part.Name == "EnergyRing" or part.Name == "InfinityGem" or part.Name == "BladeEdge" or part.Name == "PrismShard" or part.Name == "PrismBarrel" or part.Name == "TeslaGlow" or part.Name == "TeslaArc" or part.Name == "MeteorCore" or part.Name == "MeteorFragment" or part.Name == "VoidOrb" or part.Name == "VoidEdge" then
				part.Material = Enum.Material.Neon
				part.Color = Color3.fromRGB(255, 232, 128)
			end
		end
	end
	local light = Instance.new("PointLight")
	light.Name = "GoldenWeaponGlow"
	light.Color = Color3.fromRGB(255, 196, 65)
	light.Brightness = 0.8
	light.Range = 5
	light.Parent = model.PrimaryPart
	model:SetAttribute("CosmeticSkin", skinId)
end

function WeaponModels.Equip(character, weaponId, skinId)
	local old = character:FindFirstChild("EquippedWeapon")
	if old then
		old:Destroy()
	end
	local anchor = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("HumanoidRootPart")
	if not anchor then
		return nil
	end
	local model = WeaponModels.Build(weaponId)
	model.Name = "EquippedWeapon"
	WeaponModels.ApplySkin(model, skinId)
	local offset = CFrame.new(0, -0.25, -0.55)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			local localCFrame = part.CFrame
			part.CFrame = anchor.CFrame * offset * localCFrame
			local weld = Instance.new("WeldConstraint")
			weld.Name = "WeaponWeld"
			weld.Part0 = anchor
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.Parent = character
	local definition = Catalog.GetWeapon(weaponId)
	local outline = Instance.new("Highlight")
	outline.Name = "WeaponVisibilityOutline"
	outline.FillTransparency = 1
	outline.OutlineTransparency = 0.55
	outline.OutlineColor = definition and definition.Color or LIGHT
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	character:SetAttribute("WeaponId", weaponId)
	character:SetAttribute("WeaponSkin", skinId or "Default")
	character:SetAttribute("WeaponVisible", model.PrimaryPart ~= nil)
	return model
end

return WeaponModels
