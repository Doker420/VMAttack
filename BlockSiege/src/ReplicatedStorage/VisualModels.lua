-- BLOCKSIEGE // AURORA SCULPTED VISUALS
-- Smooth, authored-looking prop assemblies built from Roblox primitives and
-- SpecialMesh spheres. These are visual models, not a second gameplay collision
-- layer. Creator Store meshes can replace/augment them at runtime.
local VisualModels = {}

local INK = Color3.fromRGB(19, 31, 43)
local STONE = Color3.fromRGB(107, 132, 147)
local STONE_DARK = Color3.fromRGB(46, 65, 79)
local STONE_LIGHT = Color3.fromRGB(172, 194, 201)
local SNOW = Color3.fromRGB(235, 247, 250)
local GOLD = Color3.fromRGB(238, 184, 75)
local WOOD = Color3.fromRGB(104, 68, 45)
local BARK = Color3.fromRGB(71, 53, 43)
local LEAF = Color3.fromRGB(30, 93, 76)
local LEAF_LIGHT = Color3.fromRGB(50, 133, 99)
local LEAF_DARK = Color3.fromRGB(22, 64, 58)
local FIRE = Color3.fromRGB(255, 132, 46)

local TEXTURES = {
	Stone = "rbxassetid://9438459300",
	Wood = "rbxassetid://9439658515",
	Snow = "rbxassetid://9439632387",
	Grass = "rbxassetid://9438956437",
}

local function addTexture(object, asset, tile)
	if not asset then
		return
	end
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Front }) do
		local texture = Instance.new("Texture")
		texture.Name = "SculptedSurface"
		texture.Texture = asset
		texture.Face = face
		texture.StudsPerTileU = tile or 4
		texture.StudsPerTileV = tile or 4
		texture.Transparency = 0.08
		texture.Parent = object
	end
	object:SetAttribute("SurfaceTextured", true)
end

local function make(parent, name, size, cframe, color, material, options)
	options = options or {}
	local object = Instance.new(options.ClassName or "Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe or CFrame.new()
	object.Color = color or STONE
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = options.Collide == true
	object.CanTouch = false
	object.CanQuery = options.Query == true
	object.CastShadow = options.CastShadow ~= false and options.Holiday ~= true
	if options.Transparency ~= nil then
		object.Transparency = options.Transparency
	end
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if options.Shape then
		object.Shape = options.Shape
	end
	if options.Sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.Name = "SmoothSculpt"
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.one
		mesh.Parent = object
	end
	if options.Texture then
		addTexture(object, options.Texture, options.Tile)
	end
	if options.Holiday then
		object:SetAttribute("HolidayDecor", true)
	end
	object:SetAttribute("VisualModel", true)
	object.Parent = parent
	return object
end

local function sphere(parent, name, size, cframe, color, material, options)
	options = options or {}
	options.Sphere = true
	return make(parent, name, size, cframe, color, material, options)
end

-- Part cylinders are X-axis aligned. The supplied CFrame uses Y as the
-- authored axis, so rotate the primitive once instead of using square pillars.
local function cylinder(parent, name, radius, height, cframe, color, material, options)
	options = options or {}
	options.Shape = Enum.PartType.Cylinder
	return make(parent, name, Vector3.new(height, radius * 2, radius * 2), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material, options)
end

local function beam(parent, name, from, to, radius, color, material, options)
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return nil
	end
	options = options or {}
	options.Shape = Enum.PartType.Cylinder
	local cframe = CFrame.lookAt((from + to) * 0.5, to) * CFrame.Angles(0, math.rad(90), 0)
	return make(parent, name, Vector3.new(delta.Magnitude, radius * 2, radius * 2), cframe, color, material, options)
end

local function light(parent, name, color, range, brightness)
	local object = Instance.new("PointLight")
	object.Name = name
	object.Color = color
	object.Range = range or 12
	object.Brightness = brightness or 1
	object.Parent = parent
	return object
end

local function model(name, primary, parent, options)
	local object = Instance.new("Model")
	object.Name = name
	object.PrimaryPart = primary
	object:SetAttribute("VisualModel", true)
	if options and options.Holiday then
		object:SetAttribute("HolidayDecor", true)
	end
	object.Parent = parent
	return object
end

function VisualModels.Tree(parent, position, scale, options)
	options = options or {}
	scale = scale or 1
	local holiday = options.Holiday == true
	local trunk = cylinder(parent, "TreeTrunk", 0.82 * scale, 7.2 * scale, CFrame.new(position + Vector3.new(0, 3.6 * scale, 0)), BARK, Enum.Material.WoodPlanks, {
		Collide = options.Collide == true, Query = options.Query == true, Holiday = holiday, Texture = TEXTURES.Wood, Tile = 3,
	})
	local object = model(options.Name or "AuroraPine", trunk, parent, { Holiday = holiday })
	trunk.Parent = object
	-- Root flare and five visible branches give the silhouette a natural profile.
	for index = 1, 4 do
		local angle = math.rad(index * 90 + 20)
		local from = position + Vector3.new(0, 0.55 * scale, 0)
		local to = position + Vector3.new(math.cos(angle) * 1.8 * scale, 0.25 * scale, math.sin(angle) * 1.8 * scale)
		beam(object, "RootFlare", from, to, 0.34 * scale, BARK, Enum.Material.WoodPlanks, { Holiday = holiday })
	end
	for index, offset in ipairs({
		Vector3.new(-1.5, 4.4, 0.3), Vector3.new(1.6, 5.3, -0.4), Vector3.new(-1.3, 6.2, -0.5),
		Vector3.new(1.2, 6.9, 0.4), Vector3.new(0, 7.7, 0),
	}) do
		local from = position + Vector3.new(0, (3.5 + index * 0.55) * scale, 0)
		local to = position + offset * scale
		beam(object, "PineBranch", from, to, 0.22 * scale, BARK, Enum.Material.WoodPlanks, { Holiday = holiday })
	end
	local clusters = {
		{ Vector3.new(0, 7.8, 0), Vector3.new(4.4, 3.5, 4.2), LEAF_DARK },
		{ Vector3.new(-1.7, 7.1, 0.5), Vector3.new(3.9, 3.1, 3.8), LEAF },
		{ Vector3.new(1.7, 7.2, -0.4), Vector3.new(4.1, 3.3, 3.9), LEAF },
		{ Vector3.new(0, 9.5, 0), Vector3.new(3.5, 3.2, 3.4), LEAF_LIGHT },
		{ Vector3.new(-1.1, 10.2, 0.2), Vector3.new(2.6, 2.7, 2.6), LEAF },
		{ Vector3.new(0.9, 10.8, -0.2), Vector3.new(2.3, 2.5, 2.3), LEAF_LIGHT },
		{ Vector3.new(0, 12, 0), Vector3.new(1.35, 2.1, 1.35), LEAF_DARK },
	}
	for index, cluster in ipairs(clusters) do
		local center = position + cluster[1] * scale
		sphere(object, holiday and "PineTier" or "Foliage", cluster[2] * scale, CFrame.new(center) * CFrame.Angles(0, math.rad(index * 17), 0), cluster[3], Enum.Material.Grass, {
			Holiday = holiday, Texture = TEXTURES.Grass, Tile = 5,
		})
		if options.Snow and index % 2 == 1 then
			sphere(object, "SnowCap", Vector3.new(cluster[2].X * 0.86, 0.42, cluster[2].Z * 0.86) * scale, CFrame.new(center + Vector3.new(0, cluster[2].Y * 0.38 * scale, 0)), SNOW, Enum.Material.Snow, {
				Holiday = holiday, Texture = TEXTURES.Snow, Tile = 4,
			})
		end
	end
	return object
end

function VisualModels.ChristmasTree(parent, position, scale)
	local object = VisualModels.Tree(parent, position, scale, { Name = "HolidayTree", Holiday = true, Snow = true })
	for tier, y in ipairs({ 6.7, 8.6, 10.4, 12.1 }) do
		local radius = (4.2 - tier * 0.65) * scale
		for index = 1, 5 do
			local angle = math.rad(index * 72 + tier * 21)
			local ornamentPosition = position + Vector3.new(math.cos(angle) * radius, y * scale, math.sin(angle) * radius)
			local color = index % 2 == 0 and GOLD or Color3.fromRGB(212, 55, 76)
			sphere(object, "TreeOrnament", Vector3.one * 0.58 * scale, CFrame.new(ornamentPosition), color, Enum.Material.Neon, { Holiday = true })
			if index == 1 then
				light(object:FindFirstChild("TreeOrnament"), "OrnamentGlow", color, 5 * scale, 0.45)
			end
		end
	end
	local starPosition = position + Vector3.new(0, 14.4 * scale, 0)
	local star = sphere(object, "StarCore", Vector3.one * 0.9 * scale, CFrame.new(starPosition), GOLD, Enum.Material.Neon, { Holiday = true })
	for index = 0, 3 do
		local angle = math.rad(index * 90)
		local ray = cylinder(object, "StarRay", 0.14 * scale, 1.8 * scale, CFrame.new(starPosition) * CFrame.Angles(0, 0, angle), GOLD, Enum.Material.Neon, { Holiday = true })
		ray.CFrame = CFrame.new(starPosition) * CFrame.Angles(0, 0, angle + math.rad(45)) * CFrame.Angles(0, 0, math.rad(90))
	end
	light(star, "StarGlow", GOLD, 16 * scale, 1.8)
	return object
end

function VisualModels.Cloud(parent, position, scale)
	scale = scale or 1
	local first = sphere(parent, "CloudPuff", Vector3.new(14, 5, 8) * scale, CFrame.new(position), SNOW, Enum.Material.SmoothPlastic, { Transparency = 0.12, CastShadow = false })
	local object = model("AuroraCloud", first, parent)
	first.Parent = object
	for index, entry in ipairs({
		{ Vector3.new(-8, -0.8, 1), Vector3.new(9, 4, 7) },
		{ Vector3.new(8, -0.5, -1), Vector3.new(10, 4.5, 7) },
		{ Vector3.new(1, 2, 0), Vector3.new(8, 4, 6) },
		{ Vector3.new(-2, 1, -3), Vector3.new(7, 3.5, 5) },
	}) do
		sphere(object, "CloudPuff", entry[2] * scale, CFrame.new(position + entry[1] * scale), SNOW, Enum.Material.SmoothPlastic, { Transparency = 0.16, CastShadow = false })
	end
	return object
end

function VisualModels.Rock(parent, position, scale, options)
	options = options or {}
	scale = scale or 1
	local holiday = options.Holiday == true
	local first
	local object
	local pieces = {
		{ Vector3.new(0, 2.2, 0), Vector3.new(5.8, 4.4, 4.8), STONE_DARK, 12 },
		{ Vector3.new(-2.2, 1.4, 0.8), Vector3.new(3.8, 2.8, 3.4), STONE, -18 },
		{ Vector3.new(2.1, 1.1, -0.7), Vector3.new(3.5, 2.2, 3.1), STONE_LIGHT, 26 },
		{ Vector3.new(0.3, 3.5, -0.4), Vector3.new(3.4, 2.4, 2.8), STONE, 38 },
	}
	for index, piece in ipairs(pieces) do
		local part = sphere(parent, index == 1 and "RockMain" or "RockFragment", piece[2] * scale, CFrame.new(position + piece[1] * scale) * CFrame.Angles(0, math.rad(piece[4]), math.rad(index * 7)), piece[3], Enum.Material.Slate, {
			Query = options.Query == true, Holiday = holiday, Texture = TEXTURES.Stone, Tile = 4,
		})
		first = first or part
		if index == 1 then
			object = model(options.Name or "AuroraRock", first, parent, { Holiday = holiday })
			part.Parent = object
		else
			part.Parent = object
		end
	end
	if options.Snow then
		sphere(object, "RockSnow", Vector3.new(3.7, 0.5, 2.8) * scale, CFrame.new(position + Vector3.new(0, 4.5 * scale, 0)), SNOW, Enum.Material.Snow, { Holiday = holiday, Texture = TEXTURES.Snow })
	end
	return object
end

function VisualModels.Tower(parent, prefix, position, scale, accent, options)
	options = options or {}
	scale = scale or 1
	accent = accent or GOLD
	local body = cylinder(parent, prefix .. "Body", 5.2 * scale, 13 * scale, CFrame.new(position + Vector3.new(0, 6.5 * scale, 0)), STONE, Enum.Material.Cobblestone, {
		Holiday = options.Holiday, Texture = TEXTURES.Stone, Tile = 5,
	})
	local object = model(prefix, body, parent, options)
	body.Parent = object
	cylinder(object, "TowerBase", 6.1 * scale, 1.2 * scale, CFrame.new(position + Vector3.new(0, 0.6 * scale, 0)), STONE_DARK, Enum.Material.Slate, { Holiday = options.Holiday, Texture = TEXTURES.Stone })
	cylinder(object, "TowerFootRing", 5.7 * scale, 0.65 * scale, CFrame.new(position + Vector3.new(0, 1.45 * scale, 0)), STONE_LIGHT, Enum.Material.Cobblestone, { Holiday = options.Holiday })
	for _, y in ipairs({ 4.2, 11.8, 13.4 }) do
		cylinder(object, "TowerBand", 5.45 * scale, 0.55 * scale, CFrame.new(position + Vector3.new(0, y * scale, 0)), accent, Enum.Material.Metal, { Holiday = options.Holiday })
	end
	-- A rounded dome and snow cap replace the old cube roof.
	sphere(object, "TowerDome", Vector3.new(11.4, 5.2, 11.4) * scale, CFrame.new(position + Vector3.new(0, 15.3 * scale, 0)), INK, Enum.Material.Slate, { Holiday = options.Holiday, Texture = TEXTURES.Stone })
	sphere(object, "TowerRoofSnow", Vector3.new(9.7, 1.1, 9.7) * scale, CFrame.new(position + Vector3.new(0, 17.2 * scale, 0)), SNOW, Enum.Material.Snow, { Holiday = options.Holiday, Texture = TEXTURES.Snow })
	cylinder(object, "TowerSpire", 0.42 * scale, 4.8 * scale, CFrame.new(position + Vector3.new(0, 19.3 * scale, 0)), GOLD, Enum.Material.Metal, { Holiday = options.Holiday })
	sphere(object, "TowerSpireGem", Vector3.one * 1.05 * scale, CFrame.new(position + Vector3.new(0, 21.9 * scale, 0)), accent, Enum.Material.Neon, { Holiday = options.Holiday })
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		local merlonPosition = position + Vector3.new(math.cos(angle) * 4.55 * scale, 13.9 * scale, math.sin(angle) * 4.55 * scale)
		make(object, "TowerMerlon", Vector3.new(1.35, 1.8, 1.35) * scale, CFrame.new(merlonPosition) * CFrame.Angles(0, -angle, 0), STONE_LIGHT, Enum.Material.Cobblestone, { ClassName = "WedgePart", Holiday = options.Holiday })
	end
	for index = 0, 3 do
		local angle = math.rad(index * 90)
		local radial = Vector3.new(math.cos(angle) * 5.03 * scale, 0, math.sin(angle) * 5.03 * scale)
		local windowPosition = position + radial + Vector3.new(0, 8.1 * scale, 0)
		sphere(object, "TowerWindowFrame", Vector3.new(0.48, 3.1, 1.35) * scale, CFrame.new(windowPosition) * CFrame.Angles(0, -angle, 0), STONE_DARK, Enum.Material.Slate, { Holiday = options.Holiday })
		sphere(object, "TowerWindow", Vector3.new(0.52, 2.15, 0.78) * scale, CFrame.new(windowPosition + radial.Unit * 0.08 * scale) * CFrame.Angles(0, -angle, 0), accent, Enum.Material.Glass, { Holiday = options.Holiday })
	end
	local doorPosition = position + Vector3.new(0, 2.6 * scale, -5.05 * scale)
	sphere(object, "TowerDoorFrame", Vector3.new(3.5, 4.8, 0.65) * scale, CFrame.new(doorPosition), STONE_LIGHT, Enum.Material.Cobblestone, { Holiday = options.Holiday })
	sphere(object, "TowerDoor", Vector3.new(2.65, 4.05, 0.72) * scale, CFrame.new(doorPosition + Vector3.new(0, 0, -0.18 * scale)), INK, Enum.Material.WoodPlanks, { Holiday = options.Holiday, Texture = TEXTURES.Wood })
	cylinder(object, "TowerDoorHandle", 0.13 * scale, 0.35 * scale, CFrame.new(doorPosition + Vector3.new(0.65 * scale, 0, -0.6 * scale)), GOLD, Enum.Material.Metal, { Holiday = options.Holiday })
	local pole = cylinder(object, "TowerPole", 0.16 * scale, 6.5 * scale, CFrame.new(position + Vector3.new(0, 22 * scale, 0)), GOLD, Enum.Material.Metal, { Holiday = options.Holiday })
	make(object, "TowerFlag", Vector3.new(4.1, 2.2, 0.18) * scale, CFrame.new(position + Vector3.new(2 * scale, 23.2 * scale, 0)), accent, Enum.Material.Fabric, { ClassName = "WedgePart", Holiday = options.Holiday })
	local gem = sphere(object, "TowerLantern", Vector3.one * 0.8 * scale, CFrame.new(position + Vector3.new(0, 12.9 * scale, -5.1 * scale)), accent, Enum.Material.Neon, { Holiday = options.Holiday })
	light(gem, "TowerGlow", accent, 14 * scale, 1.1)
	return object
end

function VisualModels.Gate(parent, prefix, baseCFrame, width, height, accent, options)
	options = options or {}
	accent = accent or GOLD
	local radius = width * 0.5 - 1.8
	local first
	for _, side in ipairs({ -1, 1 }) do
		local pillarPosition = baseCFrame * CFrame.new(side * radius, height * 0.5, 0)
		local pillar = cylinder(parent, prefix .. "Pillar", 1.65, height, pillarPosition, STONE_LIGHT, Enum.Material.Cobblestone, { Holiday = options.Holiday, Texture = TEXTURES.Stone, Tile = 4 })
		first = first or pillar
		for _, y in ipairs({ 1.2, height * 0.55, height - 1.2 }) do
			cylinder(parent, prefix .. "PillarBand", 1.9, 0.5, baseCFrame * CFrame.new(side * radius, y, 0), accent, Enum.Material.Metal, { Holiday = options.Holiday })
		end
		sphere(parent, prefix .. "PillarCap", Vector3.new(4.1, 1.1, 4.1), baseCFrame * CFrame.new(side * radius, height + 0.3, 0), SNOW, Enum.Material.Snow, { Holiday = options.Holiday })
	end
	local archCenterY = height - 4.2
	local archRadius = math.max(3, radius - 0.4)
	for index = 0, 10 do
		local angle = math.pi - index * math.pi / 10
		local x = math.cos(angle) * archRadius
		local y = archCenterY + math.sin(angle) * 3.7
		local stone = make(parent, index == 5 and prefix .. "Lintel" or prefix .. "ArchStone", Vector3.new(2.9, 2.1, 3.8), baseCFrame * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, angle - math.pi / 2), index % 2 == 0 and STONE_LIGHT or STONE, Enum.Material.Cobblestone, { ClassName = "WedgePart", Holiday = options.Holiday, Texture = TEXTURES.Stone })
		if index == 5 then
			first = first or stone
		end
	end
	for index = 0, 8 do
		local angle = math.pi - index * math.pi / 8
		local x = math.cos(angle) * (archRadius - 0.25)
		local y = archCenterY + math.sin(angle) * 3.25
		make(parent, prefix .. "GoldInset", Vector3.new(1.2, 0.32, 4), baseCFrame * CFrame.new(x, y - 0.95, -0.1) * CFrame.Angles(0, 0, angle - math.pi / 2), accent, Enum.Material.Metal, { Holiday = options.Holiday })
	end
	-- Keep the old names for compatibility, but use sloped sculpted pieces.
	make(parent, prefix .. "Roof", Vector3.new(width + 3, 2.2, 5.5), baseCFrame * CFrame.new(0, height + 1.5, 0), INK, Enum.Material.Slate, { ClassName = "WedgePart", Holiday = options.Holiday })
	make(parent, prefix .. "RoofSnow", Vector3.new(width + 3.3, 0.45, 5.8), baseCFrame * CFrame.new(0, height + 2.8, 0), SNOW, Enum.Material.Snow, { ClassName = "WedgePart", Holiday = options.Holiday, Texture = TEXTURES.Snow })
	return first
end

function VisualModels.Bridge(parent, position, width, depth, accent, options)
	options = options or {}
	accent = accent or GOLD
	width = width or 30
	depth = depth or 24
	local bridgeName = options.Name or "FrontierBridge"
	local object
	local first
	for index = -3, 3 do
		local alpha = index / 3
		local y = 0.45 + (1 - alpha * alpha) * 1.1
		local deck = make(parent, first and (bridgeName .. "Deck") or bridgeName, Vector3.new(width / 7 + 0.25, 0.7, depth), CFrame.new(position + Vector3.new(index * width / 7, y, 0)) * CFrame.Angles(0, 0, -alpha * 0.12), STONE_LIGHT, Enum.Material.Cobblestone, { Holiday = options.Holiday, Texture = TEXTURES.Stone })
		first = first or deck
		if not object then
			object = model(bridgeName .. "Model", deck, parent, options)
			deck.Parent = object
		else
			deck.Parent = object
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, index in ipairs({ -3, 0, 3 }) do
			local x = index * width / 7
			cylinder(object, "BridgePost", 0.24, 3.2, CFrame.new(position + Vector3.new(x, 2.1, side * (depth * 0.5 - 1))), accent, Enum.Material.Metal, { Holiday = options.Holiday })
			sphere(object, "BridgeLantern", Vector3.one * 0.65, CFrame.new(position + Vector3.new(x, 3.9, side * (depth * 0.5 - 1))), accent, Enum.Material.Neon, { Holiday = options.Holiday })
		end
		beam(object, "BridgeRail", position + Vector3.new(-width * 0.5, 3.1, side * (depth * 0.5 - 1)), position + Vector3.new(width * 0.5, 3.1, side * (depth * 0.5 - 1)), 0.18, accent, Enum.Material.Metal, { Holiday = options.Holiday })
	end
	return object
end

function VisualModels.Column(parent, position, height, accent, options)
	options = options or {}
	local body = cylinder(parent, "HallColumn", 1.35, height, CFrame.new(position + Vector3.new(0, height * 0.5, 0)), STONE_LIGHT, Enum.Material.Marble, { Holiday = options.Holiday, Texture = TEXTURES.Stone })
	local object = model("AuroraColumn", body, parent, options)
	body.Parent = object
	for _, y in ipairs({ 0.6, height - 0.6 }) do
		cylinder(object, "ColumnCapital", 1.85, 0.7, CFrame.new(position + Vector3.new(0, y, 0)), accent or GOLD, Enum.Material.Metal, { Holiday = options.Holiday })
	end
	for index = 0, 3 do
		local angle = math.rad(index * 90)
		cylinder(object, "ColumnFlute", 0.12, height - 1.5, CFrame.new(position + Vector3.new(math.cos(angle) * 1.25, height * 0.5, math.sin(angle) * 1.25)), STONE, Enum.Material.Marble, { Holiday = options.Holiday })
	end
	return object
end

function VisualModels.Fireplace(parent, position, scale, options)
	options = options or {}
	scale = scale or 1
	local base = cylinder(parent, "FireplaceBase", 3.8 * scale, 0.8 * scale, CFrame.new(position + Vector3.new(0, 0.4 * scale, 0)), STONE_DARK, Enum.Material.Slate, { Holiday = options.Holiday })
	local object = model("FrostfireFireplace", base, parent, options)
	base.Parent = object
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		sphere(object, "HearthStone", Vector3.new(1.7, 1.25, 1.4) * scale, CFrame.new(position + Vector3.new(math.cos(angle) * 3 * scale, 0.9 * scale, math.sin(angle) * 3 * scale)), STONE, Enum.Material.Cobblestone, { Holiday = options.Holiday, Texture = TEXTURES.Stone })
	end
	beam(object, "FireLog", position + Vector3.new(-2 * scale, 1.25 * scale, -0.7 * scale), position + Vector3.new(2 * scale, 1.25 * scale, 0.7 * scale), 0.42 * scale, WOOD, Enum.Material.WoodPlanks, { Holiday = options.Holiday, Texture = TEXTURES.Wood })
	beam(object, "FireLog", position + Vector3.new(-2 * scale, 1.45 * scale, 0.7 * scale), position + Vector3.new(2 * scale, 1.45 * scale, -0.7 * scale), 0.38 * scale, WOOD, Enum.Material.WoodPlanks, { Holiday = options.Holiday, Texture = TEXTURES.Wood })
	for index, offset in ipairs({ Vector3.new(-0.8, 2.2, 0), Vector3.new(0.7, 2.6, 0.2), Vector3.new(0, 3.2, -0.2) }) do
		local flame = sphere(object, "FireFlame", Vector3.new(1.2, 2.1, 1.2) * scale, CFrame.new(position + offset * scale), index == 2 and GOLD or FIRE, Enum.Material.Neon, { Holiday = options.Holiday })
		if index == 2 then
			light(flame, "FireGlow", FIRE, 18 * scale, 2)
		end
	end
	return object
end

function VisualModels.Wall(parent, cframe, accent, options)
	options = options or {}
	accent = accent or GOLD
	local anchor = make(parent, "VisualAnchor", Vector3.new(12, 12, 2), cframe, INK, Enum.Material.SmoothPlastic, {
		Transparency = 1, Collide = false, Query = false, CastShadow = false,
	})
	local object = model("WallVisual", anchor, parent, options)
	anchor.Parent = object
	local function frame(x, y, z, rotation)
		return cframe * CFrame.new(x, y, z) * (rotation or CFrame.new())
	end
	sphere(object, "WallRoundedPanel", Vector3.new(10.8, 10.6, 1.85), frame(0, 0, 0), STONE, Enum.Material.Cobblestone, {
		Texture = TEXTURES.Stone, Tile = 5, Holiday = options.Holiday,
	})
	for _, x in ipairs({ -5.1, 5.1 }) do
		cylinder(object, "WallButtress", 0.88, 11.7, frame(x, 0, 0), STONE_DARK, Enum.Material.Cobblestone, {
			Texture = TEXTURES.Stone, Holiday = options.Holiday,
		})
		for _, y in ipairs({ -4.3, 0, 4.3 }) do
			cylinder(object, "WallIronBand", 1.02, 0.32, frame(x, y, 0), accent, Enum.Material.Metal, { Holiday = options.Holiday })
		end
	end
	for _, y in ipairs({ -3.8, 3.8 }) do
		cylinder(object, "WallCoping", 0.38, 10.8, frame(0, y, 0, CFrame.Angles(0, 0, math.rad(90))), STONE_LIGHT, Enum.Material.Cobblestone, { Holiday = options.Holiday })
	end
	for index = 0, 5 do
		local x = -4.5 + index * 1.8
		make(object, "WallMerlon", Vector3.new(1.25, 1.45, 1.9), frame(x, 6.15, 0), STONE_LIGHT, Enum.Material.Cobblestone, {
			ClassName = "WedgePart", Holiday = options.Holiday,
		})
	end
	beam(object, "WallSnowCap", (cframe * CFrame.new(-5.2, 5.75, 0)).Position, (cframe * CFrame.new(5.2, 5.75, 0)).Position, 0.2, SNOW, Enum.Material.Snow, {
		Texture = TEXTURES.Snow, Holiday = options.Holiday,
	})
	return object
end

local function crystalAssembly(parent, name, cframe, accent, options)
	options = options or {}
	accent = accent or GOLD
	local anchor = make(parent, "VisualAnchor", options.AnchorSize or Vector3.new(10, 12, 10), cframe, INK, Enum.Material.SmoothPlastic, {
		Transparency = 1, Collide = false, Query = false, CastShadow = false,
	})
	local object = model(name, anchor, parent, options)
	anchor.Parent = object
	local function point(x, y, z)
		return (cframe * CFrame.new(x, y, z)).Position
	end
	local function frame(x, y, z, rotation)
		return cframe * CFrame.new(x, y, z) * (rotation or CFrame.new())
	end
	cylinder(object, name .. "Base", options.BaseRadius or 9, 1.2, frame(0, options.BaseY or -6, 0), STONE_DARK, Enum.Material.Cobblestone, {
		Texture = TEXTURES.Stone, Tile = 5, Holiday = options.Holiday,
	})
	for _, y in ipairs({ (options.BaseY or -6) + 0.72, (options.BaseY or -6) + 1.15 }) do
		cylinder(object, name .. "BaseTrim", (options.BaseRadius or 9) + 0.25, 0.22, frame(0, y, 0), accent, Enum.Material.Metal, { Holiday = options.Holiday })
	end
	local crystalSize = options.CrystalSize or Vector3.new(7, 11, 7)
	sphere(object, name .. "CrystalShell", crystalSize, frame(0, 0, 0, CFrame.Angles(0, math.rad(45), 0)), accent, Enum.Material.Glass, {
		Transparency = 0.2, Holiday = options.Holiday,
	})
	sphere(object, options.CrystalHeartName or (name .. "CrystalHeart"), crystalSize * 0.55, frame(0, 0, 0), accent, Enum.Material.Neon, {
		Transparency = 0.04, Holiday = options.Holiday,
	})
	-- Faceted shards break up the smooth shell and create a premium silhouette.
	for index = 0, 5 do
		local angle = math.rad(index * 60 + 30)
		local radius = options.ShardRadius or 5.2
		local shardPosition = frame(math.cos(angle) * radius, math.sin(index * 1.7) * 1.2, math.sin(angle) * radius, CFrame.Angles(math.rad(12 * (index % 3)), angle, math.rad(18)))
		make(object, options.ShardName or "CoreOrbital", Vector3.new(1.1, 2.6, 1.1), shardPosition, accent, Enum.Material.Neon, {
			ClassName = "WedgePart", Transparency = 0.08, Holiday = options.Holiday,
		})
	end
	-- Two segmented energy rings, rather than flat square bands.
	for ringIndex = 1, 2 do
		local radius = (options.RingRadius or 5.8) + (ringIndex - 1) * 1.25
		local segments = 16
		for index = 0, segments - 1 do
			local a0 = index * math.pi * 2 / segments
			local a1 = (index + 1) * math.pi * 2 / segments
			local y0 = ringIndex == 1 and 0 or math.sin(a0 * 2) * 1.4
			local y1 = ringIndex == 1 and 0 or math.sin(a1 * 2) * 1.4
			beam(object, options.RingName or "CoreRing", point(math.cos(a0) * radius, y0, math.sin(a0) * radius), point(math.cos(a1) * radius, y1, math.sin(a1) * radius), 0.13, accent, Enum.Material.Neon, { Holiday = options.Holiday })
		end
	end
	for index = 0, 3 do
		local angle = math.rad(index * 90 + 45)
		local x = math.cos(angle) * (options.PylonRadius or 8)
		local z = math.sin(angle) * (options.PylonRadius or 8)
		local pylonHeight = options.PylonHeight or 10
		local pylonY = options.PylonY or -1
		cylinder(object, name .. "Pylon", 0.68, pylonHeight, frame(x, pylonY, z), STONE, Enum.Material.Cobblestone, {
			Texture = TEXTURES.Stone, Holiday = options.Holiday,
		})
		for _, bandY in ipairs({ pylonY - pylonHeight * 0.35, pylonY + pylonHeight * 0.35 }) do
			cylinder(object, name .. "PylonBand", 0.82, 0.3, frame(x, bandY, z), accent, Enum.Material.Metal, { Holiday = options.Holiday })
		end
		sphere(object, options.ShardName or "CoreOrbital", Vector3.one * 1.15, frame(x, pylonY + pylonHeight * 0.55, z), accent, Enum.Material.Neon, { Holiday = options.Holiday })
	end
	local glow = sphere(object, name .. "LightAnchor", Vector3.one * 0.5, frame(0, 0, 0), accent, Enum.Material.Neon, { Holiday = options.Holiday })
	light(glow, name .. "Glow", accent, options.LightRange or 26, 2.4)
	return object
end

function VisualModels.Core(parent, cframe, accent, options)
	options = options or {}
	options.BaseRadius = 9
	options.BaseY = -6
	options.PylonRadius = 8
	options.PylonHeight = 10
	options.PylonY = -1
	options.CrystalSize = Vector3.new(7, 11, 7)
	options.RingRadius = 5.8
	options.ShardRadius = 5.2
	options.ShardName = "CoreOrbital"
	options.RingName = "CoreRing"
	return crystalAssembly(parent, "CoreVisual", cframe, accent, options)
end

function VisualModels.Capture(parent, cframe, accent, options)
	options = options or {}
	options.AnchorSize = Vector3.new(7, 10, 7)
	options.BaseRadius = 14
	options.BaseY = -5.6
	options.PylonRadius = 11
	options.PylonHeight = 7
	options.PylonY = -2.5
	options.CrystalSize = Vector3.new(6, 9, 6)
	options.RingRadius = 6.4
	options.ShardRadius = 5.4
	options.ShardName = "CaptureGlow"
	options.CrystalHeartName = "CaptureGlow"
	options.RingName = "CaptureRing"
	return crystalAssembly(parent, "CaptureVisual", cframe, accent, options)
end

function VisualModels.Barricade(parent, cframe, accent, options)
	options = options or {}
	accent = accent or GOLD
	local anchor = make(parent, "VisualAnchor", Vector3.new(12, 5, 2), cframe, INK, Enum.Material.SmoothPlastic, {
		Transparency = 1, Collide = false, Query = false, CastShadow = false,
	})
	local object = model("BarricadeVisual", anchor, parent, options)
	anchor.Parent = object
	anchor:SetAttribute("PlacementLocked", true)
	local function point(x, y, z)
		return (cframe * CFrame.new(x, y, z)).Position
	end
	local function frame(x, y, z, rotation)
		return cframe * CFrame.new(x, y, z) * (rotation or CFrame.new())
	end
	-- Three rounded timbers establish a readable silhouette without a box root.
	for _, y in ipairs({ -1.25, 0, 1.25 }) do
		beam(object, "BarricadeLog", point(-5.55, y, 0), point(5.55, y, 0), 0.47, WOOD, Enum.Material.WoodPlanks, {
			Texture = TEXTURES.Wood, Tile = 3, Holiday = options.Holiday,
		})
	end
	for _, x in ipairs({ -4.8, 4.8 }) do
		cylinder(object, "BarricadePost", 0.46, 5.5, frame(x, 0, 0), BARK, Enum.Material.WoodPlanks, {
			Texture = TEXTURES.Wood, Tile = 3, Holiday = options.Holiday,
		})
		for _, y in ipairs({ -1.45, 1.45 }) do
			cylinder(object, "BarricadeIronBand", 0.57, 0.28, frame(x, y, 0), INK, Enum.Material.Metal, { Holiday = options.Holiday })
			sphere(object, "BarricadeBolt", Vector3.one * 0.28, frame(x, y, -0.57), GOLD, Enum.Material.Metal, { Holiday = options.Holiday })
		end
		sphere(object, "BarricadeFoot", Vector3.new(1.65, 0.72, 1.65), frame(x, -2.55, 0), STONE_DARK, Enum.Material.Slate, {
			Texture = TEXTURES.Stone, Holiday = options.Holiday,
		})
	end
	-- Crossed front and rear braces make the side/rotation legible at a glance.
	for _, z in ipairs({ -0.72, 0.72 }) do
		beam(object, "BarricadeCrossBrace", point(-4.9, -1.85, z), point(4.9, 1.85, z), 0.25, WOOD, Enum.Material.WoodPlanks, {
			Texture = TEXTURES.Wood, Tile = 3, Holiday = options.Holiday,
		})
		beam(object, "BarricadeCrossBrace", point(-4.9, 1.85, z), point(4.9, -1.85, z), 0.21, BARK, Enum.Material.WoodPlanks, {
			Texture = TEXTURES.Wood, Tile = 3, Holiday = options.Holiday,
		})
	end
	beam(object, "BarricadeRope", point(-5.1, 0.25, -1.02), point(5.1, 0.25, -1.02), 0.11, Color3.fromRGB(185, 145, 89), Enum.Material.Fabric, { Holiday = options.Holiday })
	beam(object, "BarricadeSnow", point(-5.35, 1.68, 0), point(5.35, 1.68, 0), 0.16, SNOW, Enum.Material.Snow, {
		Texture = TEXTURES.Snow, Holiday = options.Holiday,
	})
	for index = 0, 6 do
		local x = -4.5 + index * 1.5
		make(object, "BarricadeSpike", Vector3.new(0.62, 1.55, 0.62), frame(x, 3.05, 0, CFrame.Angles(0, 0, math.rad(index % 2 == 0 and -8 or 8))), STONE_LIGHT, Enum.Material.Metal, {
			ClassName = "WedgePart", Holiday = options.Holiday,
		})
	end
	sphere(object, "BarricadeTeamMarker", Vector3.new(1.1, 0.7, 0.18), frame(0, 1.65, -1.08), accent, Enum.Material.Neon, { Holiday = options.Holiday })
	object:SetAttribute("PlacementLocked", true)
	return object
end

return VisualModels
