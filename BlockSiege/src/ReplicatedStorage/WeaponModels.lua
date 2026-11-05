-- BLOCKSIEGE // SCULPTED V2 WEAPONS
-- New rounded/cylindrical/wedge silhouettes, not recolors of the old voxel set.
-- The same procedural assembly is used in a character's hand, lobby showcases
-- and the isolated ViewportFrame. Gameplay IDs/stats remain in Catalog.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))

local WeaponModels = {}
local DARK = Color3.fromRGB(32, 39, 48)
local GRAPHITE = Color3.fromRGB(20, 27, 38)
local METAL = Color3.fromRGB(111, 130, 143)
local SILVER = Color3.fromRGB(198, 220, 229)
local WOOD = Color3.fromRGB(133, 83, 49)
local LIGHT = Color3.fromRGB(232, 246, 249)
local GOLD = Color3.fromRGB(235, 177, 50)
local GOLD_LIGHT = Color3.fromRGB(255, 226, 137)

local TEXTURES = {
	[Enum.Material.WoodPlanks] = { Asset = "rbxassetid://9439658515", Tile = 1.2, Transparency = 0.06 },
	[Enum.Material.Metal] = { Asset = "rbxassetid://9920574687", Tile = 1.4, Transparency = 0.1 },
	[Enum.Material.DiamondPlate] = { Asset = "rbxassetid://10237720195", Tile = 1.3, Transparency = 0.08 },
}
local TEXTURED = { Handle = true, Stock = true, Body = true, HeavyBody = true, RailBody = true, PrismReceiver = true, TeslaBody = true, GauntletPalm = true, Armor = true }

local function texture(part, name, material)
	local style = TEXTURES[material]
	if not style or not TEXTURED[name] then
		return
	end
	local surface = Instance.new("Texture")
	surface.Name = "WeaponSurfaceTexture"
	surface.Texture = style.Asset
	surface.Face = Enum.NormalId.Front
	surface.StudsPerTileU = style.Tile
	surface.StudsPerTileV = style.Tile
	surface.Transparency = style.Transparency
	surface.Parent = part
	part:SetAttribute("SurfaceTextured", true)
end

local function part(model, name, size, cframe, color, material, shape)
	local object = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" then
		object.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		object.Shape = Enum.PartType.Cylinder
	end
	object.Reflectance = object.Material == Enum.Material.Metal and 0.1 or 0
	object.Anchored = true -- safe by default for lobby/viewport; Equip unwelds this into a hand assembly
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.Transparency = 0
	object.CastShadow = true
	object.Massless = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = model
	texture(object, name, object.Material)
	return object
end

-- Roblox cylinder primitives use the X axis. These helpers explicitly rotate
-- that axis instead of relying on a visually ambiguous cube approximation.
local function cylinderZ(model, name, length, diameter, cframe, color, material)
	return part(model, name, Vector3.new(length, diameter, diameter), cframe * CFrame.Angles(0, math.rad(90), 0), color, material, "Cylinder")
end

local function cylinderX(model, name, length, diameter, cframe, color, material)
	return part(model, name, Vector3.new(length, diameter, diameter), cframe, color, material, "Cylinder")
end

local function cylinderY(model, name, height, diameter, cframe, color, material)
	return part(model, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, "Cylinder")
end

local function ringZ(model, name, center, radius, depth, color, material)
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local segment = center * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle + math.pi / 2)
		part(model, name, Vector3.new(radius * 0.72, 0.2, depth), segment, color, material or Enum.Material.Metal)
	end
end

local function gripGrooves(model, handle, color)
	for index = 0, 3 do
		part(model, "GripGroove", Vector3.new(handle.Size.X * 1.05, 0.07, handle.Size.Z * 1.05), handle.CFrame * CFrame.new(0, -0.42 + index * 0.24, 0), color or GRAPHITE, Enum.Material.Metal)
	end
end

local function baseModel(weaponId)
	local weapon = Catalog.GetWeapon(weaponId) or Catalog.Weapons.Carbine
	local model = Instance.new("Model")
	model.Name = "Weapon_" .. weapon.Id
	model:SetAttribute("WeaponId", weapon.Id)
	model:SetAttribute("WeaponRarity", weapon.Rarity)
	model:SetAttribute("ModelGeneration", "SculptedV2")
	model:SetAttribute("VisualRevision", 2)
	local handle = part(model, "Handle", Vector3.new(0.68, 1.3, 0.72), CFrame.new(0, -0.25, 0.35), WOOD, Enum.Material.WoodPlanks)
	model.PrimaryPart = handle
	return model, weapon, handle
end

function WeaponModels.Build(weaponId)
	local model, weapon, handle = baseModel(weaponId)
	local accent = weapon.Color

	if weapon.Model == "SMG" then
		part(model, "Body", Vector3.new(1.15, 0.82, 1.8), CFrame.new(0, 0.35, -0.65), accent, Enum.Material.Metal)
		cylinderZ(model, "Barrel", 2.2, 0.42, CFrame.new(0, 0.42, -2.45), SILVER, Enum.Material.Metal)
		cylinderZ(model, "MuzzleBrake", 0.55, 0.68, CFrame.new(0, 0.42, -3.75), GRAPHITE, Enum.Material.DiamondPlate)
		ringZ(model, "MuzzleGlow", CFrame.new(0, 0.42, -4.05), 0.42, 0.16, accent, Enum.Material.Neon)
		part(model, "Magazine", Vector3.new(0.62, 1.35, 0.72), CFrame.new(0, -0.48, -0.75) * CFrame.Angles(math.rad(-12), 0, 0), GRAPHITE, Enum.Material.Metal, "Wedge")
		for _, side in ipairs({ -1, 1 }) do
			part(model, "StockFork", Vector3.new(0.18, 0.25, 1.35), CFrame.new(side * 0.42, 0.38, 0.95), DARK, Enum.Material.Metal)
		end
		part(model, "Stock", Vector3.new(1.05, 0.65, 0.3), CFrame.new(0, 0.38, 1.65), DARK, Enum.Material.Metal)
		cylinderZ(model, "Sight", 0.75, 0.38, CFrame.new(0, 0.98, -0.65), LIGHT, Enum.Material.Metal)
	elseif weapon.Model == "Scatter" then
		part(model, "Body", Vector3.new(1.55, 0.92, 1.85), CFrame.new(0, 0.35, -0.7), accent, Enum.Material.Metal, "Ball")
		for _, side in ipairs({ -1, 1 }) do
			cylinderZ(model, "TwinBarrel", 3.15, 0.5, CFrame.new(side * 0.38, 0.52, -2.85), SILVER, Enum.Material.Metal)
			cylinderZ(model, "Muzzle", 0.42, 0.7, CFrame.new(side * 0.38, 0.52, -4.55), GRAPHITE, Enum.Material.DiamondPlate)
		end
		cylinderX(model, "DrumMagazine", 0.85, 1.35, CFrame.new(0, -0.42, -0.95), DARK, Enum.Material.DiamondPlate)
		part(model, "Pump", Vector3.new(1.35, 0.55, 1.05), CFrame.new(0, 0.05, -2.25), WOOD, Enum.Material.WoodPlanks, "Ball")
		part(model, "Stock", Vector3.new(1.1, 0.82, 1.5), CFrame.new(0, 0.18, 1.05) * CFrame.Angles(math.rad(8), 0, 0), WOOD, Enum.Material.WoodPlanks, "Wedge")
	elseif weapon.Model == "Marksman" then
		part(model, "Body", Vector3.new(1.05, 0.78, 2.75), CFrame.new(0, 0.35, -1.15), accent, Enum.Material.Metal)
		cylinderZ(model, "LongBarrel", 4.25, 0.32, CFrame.new(0, 0.46, -4.4), SILVER, Enum.Material.Metal)
		cylinderZ(model, "MuzzleBrake", 0.75, 0.58, CFrame.new(0, 0.46, -6.85), GRAPHITE, Enum.Material.DiamondPlate)
		cylinderZ(model, "Scope", 2.15, 0.62, CFrame.new(0, 1.12, -1.35), DARK, Enum.Material.Metal)
		cylinderZ(model, "ScopeGlass", 0.16, 0.72, CFrame.new(0, 1.12, -2.52), LIGHT, Enum.Material.Glass)
		for _, z in ipairs({ -0.65, -2.05 }) do
			ringZ(model, "ScopeRing", CFrame.new(0, 1.12, z), 0.43, 0.18, METAL, Enum.Material.Metal)
		end
		for _, side in ipairs({ -1, 1 }) do
			part(model, "Bipod", Vector3.new(0.18, 1.5, 0.22), CFrame.new(side * 0.55, -0.4, -3.6) * CFrame.Angles(0, 0, math.rad(side * 28)), DARK, Enum.Material.Metal)
		end
		part(model, "Stock", Vector3.new(1, 0.9, 1.55), CFrame.new(0, 0.12, 1.15), WOOD, Enum.Material.WoodPlanks, "Wedge")
	elseif weapon.Model == "Demolisher" then
		part(model, "HeavyBody", Vector3.new(2, 1.45, 2.35), CFrame.new(0, 0.45, -0.9), accent, Enum.Material.DiamondPlate, "Ball")
		for _, x in ipairs({ -0.55, 0.55 }) do
			for _, y in ipairs({ 0.1, 0.85 }) do
				cylinderZ(model, "QuadBarrel", 2.8, 0.58, CFrame.new(x, y, -3.25), GRAPHITE, Enum.Material.Metal)
				cylinderZ(model, "MuzzleGlow", 0.18, 0.42, CFrame.new(x, y, -4.75), accent, Enum.Material.Neon)
			end
		end
		part(model, "Armor", Vector3.new(2.25, 0.48, 1.9), CFrame.new(0, 1.4, -0.85) * CFrame.Angles(math.rad(-8), 0, 0), METAL, Enum.Material.DiamondPlate, "Wedge")
		part(model, "Counterweight", Vector3.new(1.55, 1.15, 1.2), CFrame.new(0, 0.3, 0.95), DARK, Enum.Material.Metal, "Ball")
	elseif weapon.Model == "Rail" then
		part(model, "RailBody", Vector3.new(1.25, 0.9, 3.1), CFrame.new(0, 0.4, -1.2), accent, Enum.Material.Metal, "Wedge")
		cylinderZ(model, "RailEnergy", 5.8, 0.26, CFrame.new(0, 0.48, -4.6), LIGHT, Enum.Material.Neon)
		for _, side in ipairs({ -1, 1 }) do
			part(model, "RailSide", Vector3.new(0.22, 0.35, 5.5), CFrame.new(side * 0.62, 0.48, -4.25), GRAPHITE, Enum.Material.Metal)
		end
		for index = 0, 4 do
			ringZ(model, "EnergyRing", CFrame.new(0, 0.48, -2.2 - index * 0.95), 0.74, 0.22, index % 2 == 0 and accent or SILVER, index % 2 == 0 and Enum.Material.Neon or Enum.Material.Metal)
		end
		cylinderZ(model, "RailSight", 1.25, 0.48, CFrame.new(0, 1.18, -1.2), LIGHT, Enum.Material.Metal)
		part(model, "Stock", Vector3.new(1.1, 0.9, 1.35), CFrame.new(0, 0.2, 1), GRAPHITE, Enum.Material.Metal, "Wedge")
	elseif weapon.Model == "Vortex" then
		part(model, "VortexBody", Vector3.new(1.5, 1.1, 2.25), CFrame.new(0, 0.4, -0.85), accent, Enum.Material.Metal, "Ball")
		cylinderZ(model, "VortexCore", 3.3, 0.58, CFrame.new(0, 0.45, -3.15), LIGHT, Enum.Material.Neon)
		for index = 0, 2 do
			ringZ(model, "EnergyRing", CFrame.new(0, 0.45, -2.15 - index * 0.9), 0.95 - index * 0.12, 0.25, accent, Enum.Material.Neon)
		end
		for _, side in ipairs({ -1, 1 }) do
			part(model, "VortexFin", Vector3.new(0.35, 1.35, 1.85), CFrame.new(side * 0.95, 0.55, -1.05) * CFrame.Angles(0, 0, math.rad(side * 24)), accent, Enum.Material.Metal, "Wedge")
		end
		part(model, "VortexStock", Vector3.new(1.15, 0.85, 1.25), CFrame.new(0, 0.2, 0.9), GRAPHITE, Enum.Material.Metal, "Wedge")
	elseif weapon.Model == "Gauntlet" then
		handle.Color = GOLD
		handle.Material = Enum.Material.Metal
		cylinderY(model, "GauntletCuff", 1.65, 2.45, CFrame.new(0, 0.05, 0.3), accent, Enum.Material.DiamondPlate)
		part(model, "GauntletPalm", Vector3.new(2.35, 1.85, 2.1), CFrame.new(0, 0.6, -1.15), accent, Enum.Material.Metal, "Ball")
		part(model, "PalmPlate", Vector3.new(1.75, 0.38, 1.55), CFrame.new(0, 1.55, -1.15), GOLD_LIGHT, Enum.Material.DiamondPlate, "Wedge")
		for index = 0, 3 do
			local x = -0.78 + index * 0.52
			cylinderZ(model, "GauntletFinger", 1.65, 0.46, CFrame.new(x, 0.82, -2.75), accent, Enum.Material.Metal)
			part(model, "GauntletKnuckle", Vector3.new(0.56, 0.68, 0.65), CFrame.new(x, 1.02, -3.65), GOLD_LIGHT, Enum.Material.Metal, "Ball")
		end
		cylinderZ(model, "GauntletThumb", 1.45, 0.68, CFrame.new(1.35, 0.3, -1.65) * CFrame.Angles(0, math.rad(-24), 0), accent, Enum.Material.Metal)
		local gemColors = { Color3.fromRGB(255,80,70), Color3.fromRGB(70,160,255), Color3.fromRGB(105,240,130), Color3.fromRGB(190,95,255), Color3.fromRGB(255,205,60), Color3.fromRGB(255,125,45) }
		for index, gemColor in ipairs(gemColors) do
			local x = -0.65 + ((index - 1) % 3) * 0.65
			local z = index <= 3 and -0.85 or -1.65
			part(model, "InfinityGem", Vector3.new(0.44, 0.3, 0.44), CFrame.new(x, 1.8, z), gemColor, Enum.Material.Neon, "Ball")
		end
		cylinderZ(model, "InfinityScope", 2.65, 0.52, CFrame.new(0, 2.08, -1.75), Color3.fromRGB(188,104,255), Enum.Material.Neon)
		ringZ(model, "InfinityEmitter", CFrame.new(0, 0.58, -4.35), 0.65, 0.3, Color3.fromRGB(222,173,255), Enum.Material.Neon)
	elseif weapon.Model == "PrismLance" then
		handle.Color = GRAPHITE
		handle.Material = Enum.Material.Metal
		part(model, "PrismReceiver", Vector3.new(1.45, 1, 2.9), CFrame.new(0, 0.35, -1.05), GRAPHITE, Enum.Material.Metal, "Wedge")
		cylinderZ(model, "PrismBarrel", 4.6, 0.38, CFrame.new(0, 0.52, -4.4), accent, Enum.Material.Neon)
		part(model, "PrismTip", Vector3.new(0.75, 0.75, 1.6), CFrame.new(0, 0.52, -7.15), LIGHT, Enum.Material.Glass, "Wedge")
		cylinderZ(model, "PrismScope", 2.1, 0.58, CFrame.new(0, 1.15, -1.35), METAL, Enum.Material.Metal)
		cylinderZ(model, "PrismLens", 0.18, 0.72, CFrame.new(0, 1.15, -2.52), LIGHT, Enum.Material.Glass)
		for index = 0, 4 do
			local shardColor = index % 2 == 0 and accent or Color3.fromRGB(206,119,255)
			part(model, "PrismShard", Vector3.new(0.68, 0.68, 1.25), CFrame.new(0, 0.58, -2.25 - index * 0.82) * CFrame.Angles(math.rad(45), math.rad(index * 23), math.rad(45)), shardColor, Enum.Material.Neon, "Wedge")
		end
		for _, side in ipairs({ -1, 1 }) do
			part(model, "PrismFin", Vector3.new(0.3, 1.2, 2.2), CFrame.new(side * 0.9, 0.45, -1.1) * CFrame.Angles(0, 0, math.rad(side * 25)), accent, Enum.Material.Metal, "Wedge")
		end
	elseif weapon.Model == "TeslaCarbine" then
		handle.Color = GRAPHITE
		part(model, "TeslaBody", Vector3.new(1.55, 1.1, 2.45), CFrame.new(0, 0.4, -0.9), accent, Enum.Material.DiamondPlate, "Ball")
		for _, side in ipairs({ -1, 1 }) do
			cylinderZ(model, "TeslaRail", 3.3, 0.28, CFrame.new(side * 0.48, 0.48, -3.45), SILVER, Enum.Material.Metal)
			cylinderZ(model, "TeslaElectrode", 1.65, 0.34, CFrame.new(side * 0.55, 0.75, -5.25) * CFrame.Angles(0, math.rad(side * 8), 0), LIGHT, Enum.Material.Metal)
			part(model, "TeslaArc", Vector3.new(0.18, 0.18, 2.1), CFrame.new(side * 0.42, 1.12, -3.85) * CFrame.Angles(0, math.rad(side * 30), 0), accent, Enum.Material.Neon, "Wedge")
		end
		for index = 0, 3 do
			ringZ(model, "TeslaGlow", CFrame.new(0, 0.5, -1.75 - index * 0.75), 0.85, 0.25, index % 2 == 0 and accent or SILVER, index % 2 == 0 and Enum.Material.Neon or Enum.Material.Metal)
		end
		part(model, "TeslaCapacitor", Vector3.new(1, 1.45, 1), CFrame.new(0, -0.42, -0.75), Color3.fromRGB(48,104,137), Enum.Material.DiamondPlate, "Ball")
		cylinderZ(model, "TeslaSight", 0.9, 0.45, CFrame.new(0, 1.2, -0.8), LIGHT, Enum.Material.Neon)
	elseif weapon.Model == "MeteorMaul" then
		handle.Size = Vector3.new(0.72, 3.5, 0.72)
		handle.CFrame = CFrame.new(0, 0.1, 0.55)
		handle.Color = GRAPHITE
		handle.Material = Enum.Material.WoodPlanks
		cylinderY(model, "MaulGrip", 1.2, 0.9, CFrame.new(0, -0.9, 0.55), accent, Enum.Material.Fabric)
		for _, chunk in ipairs({
			{ Vector3.new(0,1.65,-1.35), Vector3.new(3.3,2.2,2.3) },
			{ Vector3.new(-1.25,1.85,-1.2), Vector3.new(1.5,1.5,1.6) },
			{ Vector3.new(1.2,1.45,-1.5), Vector3.new(1.6,1.7,1.5) },
			{ Vector3.new(0.2,2.65,-1.25), Vector3.new(1.8,1.2,1.5) },
		}) do
			part(model, "MeteorHead", chunk[2], CFrame.new(chunk[1]) * CFrame.Angles(math.rad(12), math.rad(18), math.rad(8)), DARK, Enum.Material.Cobblestone, "Ball")
		end
		part(model, "MeteorCore", Vector3.new(1.65, 1.65, 0.55), CFrame.new(0, 1.65, -2.65), accent, Enum.Material.Neon, "Ball")
		cylinderX(model, "MeteorBand", 3.8, 0.48, CFrame.new(0, 1.65, -1.35), METAL, Enum.Material.DiamondPlate)
		for _, side in ipairs({ -1, 1 }) do
			part(model, "MeteorSpike", Vector3.new(0.85, 0.85, 1.85), CFrame.new(side * 2, 1.65, -1.35) * CFrame.Angles(0, math.rad(side * 90), 0), accent, Enum.Material.Metal, "Wedge")
			part(model, "MeteorFragment", Vector3.new(0.85, 0.85, 0.85), CFrame.new(side * 1.2, 3.15, -1.2) * CFrame.Angles(math.rad(25), math.rad(35), 0), accent, Enum.Material.Neon, "Ball")
		end
	elseif weapon.Model == "VoidScythe" then
		handle.Size = Vector3.new(0.6, 3.9, 0.6)
		handle.CFrame = CFrame.new(0, 0.05, 0.5)
		handle.Color = GRAPHITE
		handle.Material = Enum.Material.Metal
		cylinderY(model, "VoidGrip", 1.25, 0.78, CFrame.new(0, -1.15, 0.5), accent, Enum.Material.Fabric)
		part(model, "VoidOrb", Vector3.new(1.35, 1.35, 1.35), CFrame.new(0, 1.85, -0.35), accent, Enum.Material.Neon, "Ball")
		ringZ(model, "VoidHalo", CFrame.new(0, 1.85, -0.35), 1.05, 0.18, SILVER, Enum.Material.Metal)
		for index = 0, 6 do
			local angle = math.rad(18 + index * 17)
			local x = math.cos(angle) * (1.25 + index * 0.23)
			local y = 1.8 + math.sin(angle) * (1.1 + index * 0.13)
			local z = -1.05 - index * 0.22
			part(model, "VoidBlade", Vector3.new(1.5, 0.32, 0.72), CFrame.new(x, y, z) * CFrame.Angles(math.rad(-12), math.rad(-20 - index * 8), angle), GRAPHITE, Enum.Material.Metal, "Wedge")
			part(model, "VoidEdge", Vector3.new(1.55, 0.12, 0.2), CFrame.new(x, y + 0.24, z - 0.28) * CFrame.Angles(math.rad(-12), math.rad(-20 - index * 8), angle), accent, Enum.Material.Neon, "Wedge")
		end
		part(model, "VoidCounterweight", Vector3.new(1, 1, 1), CFrame.new(0, -2.05, 0.5), accent, Enum.Material.Neon, "Ball")
	elseif weapon.Model == "Knife" or weapon.Model == "DualKnives" then
		handle.Color = GRAPHITE
		handle.Material = Enum.Material.Fabric
		local sides = weapon.Model == "DualKnives" and { -1, 1 } or { 1 }
		for _, side in ipairs(sides) do
			local x = weapon.Model == "DualKnives" and side * 0.72 or 0
			local rotation = weapon.Model == "DualKnives" and CFrame.Angles(0, math.rad(side * 12), math.rad(side * 8)) or CFrame.new()
			cylinderX(model, "KnifeGuard", 1.45, 0.32, CFrame.new(x, 0.15, -0.72) * rotation, accent, Enum.Material.Metal)
			part(model, "KnifeBlade", Vector3.new(0.72, 0.24, 3.45), CFrame.new(x, 0.35, -2.55) * rotation, SILVER, Enum.Material.Metal, "Wedge")
			part(model, "KnifeTip", Vector3.new(0.42, 0.18, 1.25), CFrame.new(x, 0.35, -4.85) * rotation, LIGHT, Enum.Material.Metal, "Wedge")
			part(model, "BladeEdge", Vector3.new(0.12, 0.12, 3.85), CFrame.new(x + 0.34, 0.24, -2.85) * rotation, accent, Enum.Material.Neon, "Wedge")
			part(model, "BladeFuller", Vector3.new(0.16, 0.08, 2.65), CFrame.new(x, 0.5, -2.45) * rotation, GRAPHITE, Enum.Material.DiamondPlate)
			part(model, "GuardGem", Vector3.new(0.42, 0.42, 0.42), CFrame.new(x, 0.42, -0.72) * rotation, accent, Enum.Material.Neon, "Ball")
			part(model, "Pommel", Vector3.new(0.82, 0.82, 0.82), CFrame.new(x, -1.05, 0.35) * rotation, accent, Enum.Material.Metal, "Ball")
		end
	else
		part(model, "Body", Vector3.new(1.25, 0.88, 2.35), CFrame.new(0, 0.35, -0.9), accent, Enum.Material.Metal, "Ball")
		cylinderZ(model, "Barrel", 2.75, 0.44, CFrame.new(0, 0.46, -3.25), SILVER, Enum.Material.Metal)
		cylinderZ(model, "MuzzleBrake", 0.62, 0.68, CFrame.new(0, 0.46, -4.85), GRAPHITE, Enum.Material.DiamondPlate)
		ringZ(model, "MuzzleGlow", CFrame.new(0, 0.46, -5.2), 0.4, 0.14, accent, Enum.Material.Neon)
		part(model, "Magazine", Vector3.new(0.7, 1.3, 0.82), CFrame.new(0, -0.45, -1) * CFrame.Angles(math.rad(-10), 0, 0), GRAPHITE, Enum.Material.Metal, "Wedge")
		part(model, "Stock", Vector3.new(1.05, 0.78, 1.45), CFrame.new(0, 0.2, 1.05), WOOD, Enum.Material.WoodPlanks, "Wedge")
		cylinderZ(model, "Sight", 0.85, 0.42, CFrame.new(0, 1.05, -1.05), LIGHT, Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			part(model, "AccentArmor", Vector3.new(0.16, 0.5, 1.4), CFrame.new(side * 0.67, 0.38, -0.85), accent, Enum.Material.DiamondPlate, "Wedge")
		end
	end
	gripGrooves(model, handle, GRAPHITE)
	model:SetAttribute("SurfaceDetail", "RoundedCylindricalWedgeAssembly")
	return model
end

function WeaponModels.ApplySkin(model, skinId)
	if not model then
		return
	end
	local celestial = skinId == "CelestialArsenal"
	if skinId ~= "GoldenArsenal" and not celestial then
		model:SetAttribute("CosmeticSkin", skinId or "Default")
		return
	end
	local baseFinish = celestial and Color3.fromRGB(79,65,145) or GOLD
	local energyFinish = celestial and Color3.fromRGB(105,233,255) or GOLD_LIGHT
	local bladeFinish = celestial and Color3.fromRGB(206,239,255) or Color3.fromRGB(255,239,184)
	local glowColor = celestial and Color3.fromRGB(142,112,255) or Color3.fromRGB(255,196,65)
	local energyNames = { Sight=true, ScopeGlass=true, ScopeLens=true, EnergyRing=true, MuzzleGlow=true, RailEnergy=true, VortexCore=true, BladeEdge=true, PrismShard=true, PrismBarrel=true, PrismTip=true, TeslaGlow=true, TeslaArc=true, MeteorCore=true, MeteorFragment=true, VoidOrb=true, VoidEdge=true, VoidCounterweight=true, InfinityScope=true, InfinityEmitter=true }
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			local name = object.Name
			local lowerName = string.lower(name)
			local originalColor = object.Color
			local isEnergy = energyNames[name] == true or object.Material == Enum.Material.Neon
			local isGrip = name == "Handle" or name == "Stock" or name == "Magazine" or name == "Pump" or string.find(lowerName,"grip",1,true) ~= nil or string.find(lowerName,"stock",1,true) ~= nil or name == "Counterweight" or name == "TeslaCapacitor"
			if name == "InfinityGem" then
				object.Material = Enum.Material.Neon
				object.Color = originalColor
				object.Reflectance = 0
			elseif isEnergy then
				object.Material = Enum.Material.Neon
				object.Color = originalColor:Lerp(energyFinish, celestial and 0.42 or 0.22)
				object.Reflectance = 0
			elseif isGrip then
				object.Material = name == "Handle" and Enum.Material.Fabric or Enum.Material.Metal
				object.Color = GRAPHITE
				object.Reflectance = 0.04
			elseif name == "KnifeBlade" or name == "KnifeTip" then
				object.Material = Enum.Material.Metal
				object.Color = bladeFinish
				object.Reflectance = 0.16
			else
				object.Material = Enum.Material.Metal
				object.Color = baseFinish
				object.Reflectance = celestial and 0.2 or 0.12
			end
		end
	end
	if model.PrimaryPart then
		for _, name in ipairs({ "GoldenWeaponGlow", "CelestialWeaponGlow" }) do
			local oldLight = model.PrimaryPart:FindFirstChild(name)
			if oldLight then oldLight:Destroy() end
		end
		local light = Instance.new("PointLight")
		light.Name = celestial and "CelestialWeaponGlow" or "GoldenWeaponGlow"
		light.Color = glowColor
		light.Brightness = celestial and 1.5 or 1.1
		light.Range = celestial and 8 or 6
		light.Parent = model.PrimaryPart
	end
	model:SetAttribute("CosmeticSkin", skinId)
	model:SetAttribute("Finish", celestial and "CelestialMetalEnergy" or "GoldGraphiteAccent")
end

function WeaponModels.Equip(character, weaponId, skinId)
	local old = character:FindFirstChild("EquippedWeapon")
	if old then old:Destroy() end
	local anchor = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("HumanoidRootPart")
	if not anchor then return nil end
	local model = WeaponModels.Build(weaponId)
	model.Name = "EquippedWeapon"
	WeaponModels.ApplySkin(model, skinId)
	local offset = CFrame.new(0, -0.35, -0.75)
	for _, object in ipairs(model:GetChildren()) do
		if object:IsA("BasePart") then
			local localCFrame = object.CFrame
			object.Anchored = false
			object.Transparency = 0
			object.CFrame = anchor.CFrame * offset * localCFrame
			local weld = Instance.new("Weld")
			weld.Name = "WeaponWeld"
			weld.Part0 = anchor
			weld.Part1 = object
			weld.C0 = offset * localCFrame
			weld.C1 = CFrame.new()
			weld.Parent = object
		end
	end
	model.Parent = character
	local definition = Catalog.GetWeapon(weaponId)
	local outline = Instance.new("Highlight")
	outline.Name = "WeaponVisibilityOutline"
	outline.FillTransparency = 1
	outline.OutlineTransparency = 0.35
	outline.OutlineColor = definition and definition.Color or LIGHT
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	character:SetAttribute("WeaponId", weaponId)
	character:SetAttribute("WeaponSkin", skinId or "Default")
	character:SetAttribute("WeaponModelGeneration", "SculptedV2")
	character:SetAttribute("WeaponVisible", model.PrimaryPart ~= nil)
	return model
end

return WeaponModels
