-- Симметричная voxel-арена и свободное лобби с витриной оружия и лутбоксом.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Roblox-owned Store models can be loaded without enabling arbitrary third-party
-- assets. The native/offline audit has no AssetService; procedural decor remains.
local assetServiceOk, AssetService = pcall(function()
	return game:GetService("AssetService")
end)
if not assetServiceOk then
	AssetService = nil
end

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))

local WorldBuilder = {}
local buildSerial = 0
local C = {
	Grass = Color3.fromRGB(83, 128, 112),
	Dirt = Color3.fromRGB(76, 72, 77),
	Stone = Color3.fromRGB(113, 138, 153),
	StoneDark = Color3.fromRGB(37, 55, 74),
	Wood = Color3.fromRGB(128, 91, 68),
	Leaf = Color3.fromRGB(42, 100, 88),
	Sand = Color3.fromRGB(155, 174, 184),
	White = Color3.fromRGB(235, 245, 255),
	Gold = Color3.fromRGB(255, 204, 102),
}

-- Public Roblox material color maps add real tiled surface detail without a custom
-- model upload. The underlying Material/Color remains as a loading-safe fallback.
local SURFACE_TEXTURES = {
	[Enum.Material.Cobblestone] = { Asset = "rbxassetid://9438459300", Tile = 6, Transparency = 0.1 },
	[Enum.Material.WoodPlanks] = { Asset = "rbxassetid://9439658515", Tile = 4, Transparency = 0.08 },
	[Enum.Material.Snow] = { Asset = "rbxassetid://9439632387", Tile = 5, Transparency = 0.04 },
	[Enum.Material.Grass] = { Asset = "rbxassetid://9438956437", Tile = 7, Transparency = 0.12 },
	[Enum.Material.Ground] = { Asset = "rbxassetid://9439044431", Tile = 7, Transparency = 0.12 },
	[Enum.Material.Slate] = { Asset = "rbxassetid://9483106252", Tile = 6, Transparency = 0.12 },
	[Enum.Material.Sand] = { Asset = "rbxassetid://9439585561", Tile = 6, Transparency = 0.1 },
	[Enum.Material.Fabric] = { Asset = "rbxassetid://9920517696", Tile = 3, Transparency = 0.1 },
}

local function addSurfaceTextures(part, material, name)
	local style = SURFACE_TEXTURES[material]
	if not style then
		return
	end
	local largest = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	if largest < 5 and name ~= "GiftBox" and name ~= "GiftLid" then
		return
	end
	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Front }) do
		local texture = Instance.new("Texture")
		texture.Name = "SurfaceTexture"
		texture.Texture = style.Asset
		texture.Face = face
		texture.StudsPerTileU = style.Tile
		texture.StudsPerTileV = style.Tile
		texture.Transparency = style.Transparency
		texture.Parent = part
	end
	part:SetAttribute("SurfaceTextured", true)
end

local function makePart(parent, name, size, cframe, color, material, collide, className)
	local part = Instance.new(className or "Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = collide ~= false
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	addSurfaceTextures(part, part.Material, name)
	return part
end

local function billboard(parent, text, color, offset, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Size = UDim2.fromOffset(260, 58)
	gui.StudsOffset = offset or Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = size or UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Parent = gui
	return gui
end

local function prompt(parent, action, object)
	local proximity = Instance.new("ProximityPrompt")
	proximity.ActionText = action
	proximity.ObjectText = object
	proximity.HoldDuration = 0.25
	proximity.MaxActivationDistance = 14
	proximity.RequiresLineOfSight = false
	proximity.Parent = parent
	return proximity
end

local function buildTree(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "VoxelTree"
	model.Parent = parent
	makePart(model, "Trunk", Vector3.new(2.4, 9, 2.4) * scale, CFrame.new(position + Vector3.new(0, 4.5 * scale, 0)), C.Wood, Enum.Material.WoodPlanks, true)
	for _, offset in ipairs({ Vector3.new(0, 10, 0), Vector3.new(2.5, 8.5, 0), Vector3.new(-2.5, 8.5, 0), Vector3.new(0, 8.5, 2.5), Vector3.new(0, 8.5, -2.5) }) do
		makePart(model, "Leaves", Vector3.new(5, 5, 5) * scale, CFrame.new(position + offset * scale), C.Leaf, Enum.Material.Grass, true)
	end
	return model
end

local HOLIDAY = {
	Red = Color3.fromRGB(202, 48, 64),
	Green = Color3.fromRGB(30, 137, 91),
	Pine = Color3.fromRGB(24, 87, 65),
	Snow = Color3.fromRGB(237, 248, 255),
	Ice = Color3.fromRGB(128, 222, 255),
	Gold = Color3.fromRGB(255, 205, 83),
	Warm = Color3.fromRGB(255, 164, 70),
	Ink = Color3.fromRGB(28, 42, 57),
}

local STYLE = {
	Ivory = Color3.fromRGB(205, 226, 237),
	IvoryDark = Color3.fromRGB(125, 161, 181),
	Navy = Color3.fromRGB(17, 35, 59),
	Blue = Color3.fromRGB(69, 190, 239),
	Ice = Color3.fromRGB(137, 231, 255),
	Gold = Color3.fromRGB(255, 204, 102),
	Warm = Color3.fromRGB(255, 151, 85),
}

local function decorPart(parent, name, size, cframe, color, material, className)
	local part = makePart(parent, name, size, cframe, color, material, false, className)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("HolidayDecor", true)
	return part
end

local function holidayGlow(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Name = "HolidayGlow"
	light.Color = color
	light.Range = range or 10
	light.Brightness = brightness or 1
	light.Parent = part
	return light
end

-- Curated free models published by Roblox in the Creator Store. Only their
-- visual geometry is copied; the original asset is never parented into the game.
local CREATOR_STORE_ASSETS = {
	{
		Key = "ChristmasTree", Id = 67187806, Title = "Christmas Tree",
		Placements = {
			{ Parent = "Lobby", Position = Vector3.new(24, 44.5, 350), Size = 16, Fit = "Height" },
			{ Parent = "Arena", Position = Vector3.new(188, 0, 72), Size = 11, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(25), 0) },
			{ Parent = "Arena", Position = Vector3.new(-188, 0, -72), Size = 11, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(-25), 0) },
		},
	},
	{
		Key = "Snowman", Id = 67187780, Title = "Snowman",
		Placements = {
			{ Parent = "Lobby", Position = Vector3.new(-68, 44.5, 320), Size = 8, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(20), 0) },
			{ Parent = "Lobby", Position = Vector3.new(68, 44.5, 320), Size = 8, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(-20), 0) },
		},
	},
	{
		Key = "Wreath", Id = 67187797, Title = "Wreath",
		Placements = {
			{ Parent = "Lobby", Position = Vector3.new(-27, 52, 383.2), Size = 5.5, Fit = "Max", Ground = false },
			{ Parent = "Lobby", Position = Vector3.new(27, 52, 383.2), Size = 5.5, Fit = "Max", Ground = false },
		},
	},
	{
		Key = "Present", Id = 67187816, Title = "Present",
		Placements = {
			{ Parent = "Lobby", Position = Vector3.new(-14, 44.5, 334), Size = 4.5, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(-15), 0) },
			{ Parent = "Lobby", Position = Vector3.new(14, 44.5, 334), Size = 4.5, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(15), 0) },
		},
	},
	{
		Key = "Ornaments", Id = 332741030, Title = "Christmas Ornaments",
		Placements = {
			{ Parent = "Lobby", Position = Vector3.new(24, 54, 350), Size = 4, Fit = "Max", Ground = false },
		},
	},
}

local CREATOR_STORE_VISUAL_CHILDREN = {
	SpecialMesh = true,
	BlockMesh = true,
	CylinderMesh = true,
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
}
local CREATOR_STORE_SKIP_PARTS = { SpawnLocation = true, Seat = true, VehicleSeat = true }
local CREATOR_STORE_GAMEPLAY_ATTRIBUTES = {
	"BaseGeometry", "CaptureGeometry", "Team", "StructureId", "Kind", "IsTrap", "DefenseId", "Rig", "CaptureRadius",
}
local CREATOR_STORE_MAX_SOURCE_PARTS = 120
local CREATOR_STORE_MAX_TOTAL_PARTS = 450

local function clearCreatorStoreGameplayAttributes(instance)
	local ok, attributes = pcall(function()
		return instance:GetAttributes()
	end)
	if ok and attributes then
		for attribute in pairs(attributes) do
			instance:SetAttribute(attribute, nil)
		end
		return
	end
	for _, attribute in ipairs(CREATOR_STORE_GAMEPLAY_ATTRIBUTES) do
		instance:SetAttribute(attribute, nil)
	end
end

local function sanitizeCreatorStoreModel(source, definition)
	local sourcePartCount = 0
	for _, descendant in ipairs(source:GetDescendants()) do
		if descendant:IsA("BasePart") and not CREATOR_STORE_SKIP_PARTS[descendant.ClassName] then
			sourcePartCount = sourcePartCount + 1
		end
	end
	if sourcePartCount == 0 or sourcePartCount > CREATOR_STORE_MAX_SOURCE_PARTS then
		return nil, "empty or over the geometry budget"
	end

	local clean = Instance.new("Model")
	clean.Name = "Store_" .. definition.Key
	clearCreatorStoreGameplayAttributes(clean)
	clean:SetAttribute("HolidayDecor", true)
	clean:SetAttribute("StoreDecor", true)
	clean:SetAttribute("CreatorStoreAssetId", definition.Id)
	local createdCount = 0
	for _, descendant in ipairs(source:GetDescendants()) do
		if descendant:IsA("BasePart") and not CREATOR_STORE_SKIP_PARTS[descendant.ClassName] then
			local cloneOk, copy = pcall(function()
				return descendant:Clone()
			end)
			if cloneOk and copy then
				-- Keep only visual children. Scripts, Humanoids, GUI, sounds,
				-- prompts, constraints and particles never enter the clean model.
				for _, child in ipairs(copy:GetChildren()) do
					if not CREATOR_STORE_VISUAL_CHILDREN[child.ClassName] then
						child:Destroy()
					else
						clearCreatorStoreGameplayAttributes(child)
					end
				end
				copy.Name = "Store_" .. descendant.Name
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanTouch = false
				copy.CanQuery = false
				copy.CastShadow = false
				clearCreatorStoreGameplayAttributes(copy)
				copy:SetAttribute("HolidayDecor", true)
				copy:SetAttribute("StoreDecor", true)
				copy:SetAttribute("CreatorStoreAssetId", definition.Id)
				copy:SetAttribute("SourcePartName", descendant.Name)
				copy.Parent = clean
				createdCount = createdCount + 1
			end
		end
	end
	if createdCount == 0 then
		clean:Destroy()
		return nil, "no cloneable visual parts"
	end
	clean:SetAttribute("StorePartCount", createdCount)
	return clean
end

local function placeCreatorStoreModel(template, definition, placement, parent)
	local model = template:Clone()
	if not model then
		return false, "model clone failed"
	end
	local ok, err = pcall(function()
		local _, size = model:GetBoundingBox()
		local basis = placement.Fit == "Height" and size.Y or math.max(size.X, size.Y, size.Z)
		if basis <= 0.01 then
			error("invalid model bounds")
		end
		model:ScaleTo(placement.Size / basis)
		model:PivotTo(CFrame.new(placement.Position) * (placement.Rotation or CFrame.new()))
		local bounds, scaledSize = model:GetBoundingBox()
		local target = placement.Position
		if placement.Ground ~= false then
			target = target + Vector3.new(0, scaledSize.Y * 0.5, 0)
		end
		model:PivotTo(model:GetPivot() + (target - bounds.Position))
		model.Parent = parent
	end)
	if not ok then
		model:Destroy()
		return false, err
	end
	return true
end

local function loadCreatorStoreDecorations(root, lobby, arena, serial)
	if not AssetService then
		return
	end
	local parents = { Lobby = lobby, Arena = arena }
	local totalParts = 0
	local loadedModels = 0
	local function isCurrent()
		return serial == buildSerial and root.Parent == Workspace
	end
	for _, definition in ipairs(CREATOR_STORE_ASSETS) do
		if not isCurrent() then
			return
		end
		local loadOk, source = pcall(function()
			return AssetService:LoadAssetAsync(definition.Id)
		end)
		if loadOk and source then
			local sanitizeOk, template, sanitizeErr = pcall(sanitizeCreatorStoreModel, source, definition)
			source:Destroy()
			if sanitizeOk and template then
				for _, placement in ipairs(definition.Placements) do
					if not isCurrent() then
						template:Destroy()
						return
					end
					local partCount = template:GetAttribute("StorePartCount") or 0
					if totalParts + partCount <= CREATOR_STORE_MAX_TOTAL_PARTS then
						local placeOk, placed, placeErr = pcall(placeCreatorStoreModel, template, definition, placement, parents[placement.Parent])
						if placeOk and placed then
							totalParts = totalParts + partCount
							loadedModels = loadedModels + 1
						else
							warn("[BLOCKSIEGE] Store decor placement skipped:", definition.Title, tostring(placeErr or placed))
						end
					end
				end
				template:Destroy()
			else
				warn("[BLOCKSIEGE] Store decor rejected:", definition.Title, tostring(sanitizeErr or template))
			end
		else
			warn("[BLOCKSIEGE] Store decor unavailable; procedural fallback kept:", definition.Title, tostring(source))
		end
	end
	if loadedModels > 0 then
		print(string.format("[BLOCKSIEGE] Creator Store decor: %d models, %d static parts", loadedModels, totalParts))
	end
end

local function buildGift(parent, position, scale, color)
	local model = Instance.new("Model")
	model.Name = "HolidayGift"
	model:SetAttribute("HolidayDecor", true)
	model.Parent = parent
	local box = decorPart(model, "GiftBox", Vector3.new(3.4, 2.7, 3.4) * scale, CFrame.new(position + Vector3.new(0, 1.35 * scale, 0)), color or HOLIDAY.Red, Enum.Material.Fabric)
	model.PrimaryPart = box
	decorPart(model, "GiftLid", Vector3.new(3.65, 0.42, 3.65) * scale, CFrame.new(position + Vector3.new(0, 2.82 * scale, 0)), color or HOLIDAY.Red, Enum.Material.Fabric)
	decorPart(model, "GiftRibbon", Vector3.new(0.46, 2.95, 3.55) * scale, CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)), HOLIDAY.Gold, Enum.Material.Metal)
	decorPart(model, "GiftRibbon", Vector3.new(3.55, 2.95, 0.46) * scale, CFrame.new(position + Vector3.new(0, 1.5 * scale, 0)), HOLIDAY.Gold, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		decorPart(model, "GiftBow", Vector3.new(1.5, 0.38, 0.58) * scale, CFrame.new(position + Vector3.new(side * 0.62 * scale, 3.35 * scale, 0)) * CFrame.Angles(0, 0, side * math.rad(28)), HOLIDAY.Gold, Enum.Material.Metal)
	end
	return model
end

local function buildChristmasTree(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "HolidayTree"
	model:SetAttribute("HolidayDecor", true)
	model.Parent = parent
	local trunk = decorPart(model, "TreeTrunk", Vector3.new(2.1, 4, 2.1) * scale, CFrame.new(position + Vector3.new(0, 2 * scale, 0)), C.Wood, Enum.Material.WoodPlanks)
	model.PrimaryPart = trunk
	local tiers = {
		{ Width = 11, Height = 3.4, Y = 5.5 },
		{ Width = 8.8, Height = 3.1, Y = 8.2 },
		{ Width = 6.5, Height = 2.8, Y = 10.7 },
		{ Width = 4.2, Height = 2.4, Y = 13 },
	}
	for tierIndex, tier in ipairs(tiers) do
		local width = tier.Width * scale
		local height = tier.Height * scale
		local center = position + Vector3.new(0, tier.Y * scale, 0)
		local rotation = CFrame.Angles(0, math.rad(tierIndex % 2 == 0 and 45 or 0), 0)
		decorPart(model, "PineTier", Vector3.new(width, height, width), CFrame.new(center) * rotation, HOLIDAY.Pine, Enum.Material.Grass)
		decorPart(model, "SnowCap", Vector3.new(width * 0.82, 0.34 * scale, width * 0.82), CFrame.new(center + Vector3.new(0, height * 0.5 + 0.16 * scale, 0)) * rotation, HOLIDAY.Snow, Enum.Material.Snow)
		for sideIndex, side in ipairs({ -1, 1 }) do
			local ornamentColor = sideIndex == 1 and HOLIDAY.Red or HOLIDAY.Gold
			for _, forward in ipairs({ -1, 1 }) do
				local ornament = decorPart(model, "TreeOrnament", Vector3.new(0.62, 0.62, 0.62) * scale, CFrame.new(center + Vector3.new(side * width * 0.43, 0, forward * width * 0.43)), ornamentColor, Enum.Material.Neon)
				ornament.Shape = Enum.PartType.Ball
			end
		end
		for _, forward in ipairs({ -1, 1 }) do
			decorPart(model, "TreeGarland", Vector3.new(width * 0.68, 0.14 * scale, 0.14 * scale), CFrame.new(center + Vector3.new(0, 0.35 * scale, forward * width * 0.51)) * rotation, HOLIDAY.Gold, Enum.Material.Neon)
			decorPart(model, "TreeGarland", Vector3.new(0.14 * scale, 0.14 * scale, width * 0.68), CFrame.new(center + Vector3.new(forward * width * 0.51, 0.35 * scale, 0)) * rotation, HOLIDAY.Gold, Enum.Material.Neon)
		end
	end
	local starPosition = position + Vector3.new(0, 15.5 * scale, 0)
	decorPart(model, "StarVertical", Vector3.new(0.35, 2.2, 0.35) * scale, CFrame.new(starPosition), HOLIDAY.Gold, Enum.Material.Neon)
	decorPart(model, "StarHorizontal", Vector3.new(2.2, 0.35, 0.35) * scale, CFrame.new(starPosition), HOLIDAY.Gold, Enum.Material.Neon)
	for _, angle in ipairs({ -45, 45 }) do
		decorPart(model, "StarRay", Vector3.new(0.28, 2.25, 0.28) * scale, CFrame.new(starPosition) * CFrame.Angles(0, 0, math.rad(angle)), HOLIDAY.Gold, Enum.Material.Neon)
	end
	local star = decorPart(model, "StarCore", Vector3.new(0.72, 0.72, 0.72) * scale, CFrame.new(starPosition), HOLIDAY.Gold, Enum.Material.Neon)
	star.Shape = Enum.PartType.Ball
	holidayGlow(star, HOLIDAY.Gold, 16 * scale, 2)
	return model
end

local function buildSnowman(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "HolidaySnowman"
	model:SetAttribute("HolidayDecor", true)
	model.Parent = parent
	local function snowball(name, diameter, y)
		local part = decorPart(model, name, Vector3.new(diameter, diameter, diameter) * scale, CFrame.new(position + Vector3.new(0, y * scale, 0)), HOLIDAY.Snow, Enum.Material.Snow)
		part.Shape = Enum.PartType.Ball
		return part
	end
	snowball("SnowmanBody", 3.5, 1.75)
	snowball("SnowmanMiddle", 2.65, 4.05)
	snowball("SnowmanHead", 1.95, 6.15)
	for _, y in ipairs({ 3.55, 4.25 }) do
		local button = decorPart(model, "CoalButton", Vector3.new(0.25, 0.25, 0.25) * scale, CFrame.new(position + Vector3.new(0, y * scale, -1.27 * scale)), HOLIDAY.Ink, Enum.Material.SmoothPlastic)
		button.Shape = Enum.PartType.Ball
	end
	for _, side in ipairs({ -1, 1 }) do
		local eye = decorPart(model, "CoalEye", Vector3.new(0.22, 0.22, 0.22) * scale, CFrame.new(position + Vector3.new(side * 0.36 * scale, 6.42 * scale, -0.86 * scale)), HOLIDAY.Ink, Enum.Material.SmoothPlastic)
		eye.Shape = Enum.PartType.Ball
		decorPart(model, "SnowmanArm", Vector3.new(2.2, 0.22, 0.22) * scale, CFrame.new(position + Vector3.new(side * 2.1 * scale, 4.1 * scale, 0)) * CFrame.Angles(0, 0, side * math.rad(22)), C.Wood, Enum.Material.WoodPlanks)
	end
	decorPart(model, "CarrotNose", Vector3.new(0.28, 0.28, 0.85) * scale, CFrame.new(position + Vector3.new(0, 6.1 * scale, -1.12 * scale)), Color3.fromRGB(255, 133, 48), Enum.Material.SmoothPlastic)
	decorPart(model, "Scarf", Vector3.new(2.25, 0.42, 2.25) * scale, CFrame.new(position + Vector3.new(0, 5.12 * scale, 0)), HOLIDAY.Red, Enum.Material.Fabric)
	decorPart(model, "ScarfTail", Vector3.new(0.48, 1.55, 0.25) * scale, CFrame.new(position + Vector3.new(0.72 * scale, 4.35 * scale, -1.05 * scale)), HOLIDAY.Red, Enum.Material.Fabric)
	decorPart(model, "HatBrim", Vector3.new(2.5, 0.3, 2.5) * scale, CFrame.new(position + Vector3.new(0, 7.2 * scale, 0)), HOLIDAY.Ink, Enum.Material.Fabric)
	decorPart(model, "Hat", Vector3.new(1.55, 1.35, 1.55) * scale, CFrame.new(position + Vector3.new(0, 7.85 * scale, 0)), HOLIDAY.Ink, Enum.Material.Fabric)
	decorPart(model, "HatBand", Vector3.new(1.62, 0.25, 1.62) * scale, CFrame.new(position + Vector3.new(0, 7.55 * scale, 0)), HOLIDAY.Red, Enum.Material.Fabric)
	return model
end

local function buildSnowflake(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "HolidaySnowflake"
	model:SetAttribute("HolidayDecor", true)
	model.Parent = parent
	for index = 0, 2 do
		decorPart(model, "SnowflakeRay", Vector3.new(0.22, 4, 0.22) * scale, CFrame.new(position) * CFrame.Angles(0, 0, math.rad(index * 60)), HOLIDAY.Ice, Enum.Material.Neon)
	end
	local center = decorPart(model, "SnowflakeCenter", Vector3.new(0.5, 0.5, 0.5) * scale, CFrame.new(position), HOLIDAY.Snow, Enum.Material.Neon)
	center.Shape = Enum.PartType.Ball
	return model
end

local function buildGarland(parent, startPoint, endPoint, sag, segments)
	local previous = startPoint
	for index = 0, segments do
		local alpha = index / segments
		local point = startPoint:Lerp(endPoint, alpha) - Vector3.new(0, math.sin(alpha * math.pi) * (sag or 2), 0)
		if index > 0 then
			local delta = point - previous
			if delta.Magnitude > 0.05 then
				decorPart(parent, "GarlandCable", Vector3.new(0.14, 0.14, delta.Magnitude), CFrame.lookAt((previous + point) * 0.5, point), HOLIDAY.Pine, Enum.Material.Metal)
			end
		end
		local colors = { HOLIDAY.Red, HOLIDAY.Gold, HOLIDAY.Ice, HOLIDAY.Green }
		local bulb = decorPart(parent, "GarlandBulb", Vector3.new(0.58, 0.58, 0.58), CFrame.new(point - Vector3.new(0, 0.25, 0)), colors[(index % #colors) + 1], Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		if index % 4 == 0 then
			holidayGlow(bulb, bulb.Color, 7, 0.7)
		end
		previous = point
	end
end

local function buildSnowEmitter(parent, position, size, rate)
	local anchor = decorPart(parent, "SnowfallEmitter", size, CFrame.new(position), HOLIDAY.Snow, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "HolidaySnowfall"
	snow.Rate = rate or 12
	snow.Lifetime = NumberRange.new(4, 7)
	snow.Speed = NumberRange.new(1, 2)
	snow.Acceleration = Vector3.new(0, -1.5, 0)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(35, 35)
	snow.RotSpeed = NumberRange.new(-35, 35)
	snow.Size = NumberSequence.new(0.18)
	snow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.75) })
	snow.Color = ColorSequence.new(HOLIDAY.Snow)
	snow.LightEmission = 0.15
	snow.Parent = anchor
	return snow
end

local function buildFestiveArch(parent, position)
	local model = Instance.new("Model")
	model.Name = "HolidayArch"
	model:SetAttribute("HolidayDecor", true)
	model.Parent = parent
	for _, side in ipairs({ -1, 1 }) do
		decorPart(model, "ArchPillar", Vector3.new(2.2, 13, 2.2), CFrame.new(position + Vector3.new(side * 27, 6.5, 0)), HOLIDAY.Red, Enum.Material.Fabric)
		for _, y in ipairs({ 2, 10.5 }) do
			decorPart(model, "ArchBand", Vector3.new(2.5, 0.45, 2.5), CFrame.new(position + Vector3.new(side * 27, y, 0)), HOLIDAY.Gold, Enum.Material.Metal)
		end
	end
	decorPart(model, "ArchBeam", Vector3.new(58, 2.2, 2.2), CFrame.new(position + Vector3.new(0, 13, 0)), HOLIDAY.Green, Enum.Material.Fabric)
	decorPart(model, "ArchSnow", Vector3.new(58.5, 0.4, 2.5), CFrame.new(position + Vector3.new(0, 14.25, 0)), HOLIDAY.Snow, Enum.Material.Snow)
	local sign = decorPart(model, "ArchSign", Vector3.new(1, 1, 1), CFrame.new(position + Vector3.new(0, 11.5, -1.3)), HOLIDAY.Snow, Enum.Material.SmoothPlastic)
	sign.Transparency = 1
	billboard(sign, "С НОВЫМ ГОДОМ // 2026", HOLIDAY.Gold, Vector3.zero, UDim2.fromScale(1, 1))
	return model
end

local function decorateLobby(lobby)
	buildFestiveArch(lobby, Vector3.new(0, 44.5, 385))
	for _, entry in ipairs({
		{ Vector3.new(-58, 44.58, 372), Vector3.new(18, 0.16, 9) }, { Vector3.new(58, 44.58, 372), Vector3.new(18, 0.16, 9) },
		{ Vector3.new(-62, 44.58, 286), Vector3.new(14, 0.16, 8) }, { Vector3.new(62, 44.58, 286), Vector3.new(14, 0.16, 8) },
	}) do
		decorPart(lobby, "LobbySnowPatch", entry[2], CFrame.new(entry[1]), HOLIDAY.Snow, Enum.Material.Snow)
	end
	decorPart(lobby, "LootboxSnowCap", Vector3.new(9.2, 0.34, 9.2), CFrame.new(0, 51.65, 318), HOLIDAY.Snow, Enum.Material.Snow)
	buildChristmasTree(lobby, Vector3.new(-24, 44.5, 350), 0.72)
	for _, entry in ipairs({
		{ Vector3.new(-8, 44.5, 347), 0.8, HOLIDAY.Red }, { Vector3.new(8, 44.5, 347), 0.75, HOLIDAY.Green },
		{ Vector3.new(-8, 44.5, 318), 0.65, HOLIDAY.Green }, { Vector3.new(8, 44.5, 318), 0.7, HOLIDAY.Red },
	}) do
		buildGift(lobby, entry[1], entry[2], entry[3])
	end
	buildSnowman(lobby, Vector3.new(-68, 44.5, 350), 0.9)
	buildSnowman(lobby, Vector3.new(68, 44.5, 350), 0.9)
	buildGarland(lobby, Vector3.new(-78, 60, 268), Vector3.new(78, 60, 268), 3, 16)
	buildGarland(lobby, Vector3.new(-78, 60, 392), Vector3.new(78, 60, 392), 3, 16)
	buildGarland(lobby, Vector3.new(-81, 60, 275), Vector3.new(-81, 60, 385), 2, 12)
	buildGarland(lobby, Vector3.new(81, 60, 275), Vector3.new(81, 60, 385), 2, 12)
	for _, position in ipairs({
		Vector3.new(-81, 55, 300), Vector3.new(-81, 55, 360), Vector3.new(81, 55, 300), Vector3.new(81, 55, 360),
		Vector3.new(-48, 57, 391), Vector3.new(48, 57, 391),
	}) do
		buildSnowflake(lobby, position, 1.1)
	end
	buildSnowEmitter(lobby, Vector3.new(0, 76, 330), Vector3.new(150, 1, 110), 18)
end

local function decorateArena(arena)
	for _, entry in ipairs({
		{ Vector3.new(-120, 0.08, -62), Vector3.new(19, 0.16, 9) }, { Vector3.new(120, 0.08, 62), Vector3.new(19, 0.16, 9) },
		{ Vector3.new(-76, 0.08, 42), Vector3.new(13, 0.16, 8) }, { Vector3.new(76, 0.08, -42), Vector3.new(13, 0.16, 8) },
		{ Vector3.new(0, 0.08, -72), Vector3.new(22, 0.16, 7) }, { Vector3.new(0, 0.08, 72), Vector3.new(22, 0.16, 7) },
	}) do
		decorPart(arena, "SnowPatch", entry[2], CFrame.new(entry[1]), HOLIDAY.Snow, Enum.Material.Snow)
	end
	buildChristmasTree(arena, Vector3.new(-116, 0, 80), 0.55)
	buildChristmasTree(arena, Vector3.new(116, 0, -80), 0.55)
	buildSnowman(arena, Vector3.new(-125, 0, -74), 0.85)
	buildSnowman(arena, Vector3.new(125, 0, 74), 0.85)
	buildGift(arena, Vector3.new(-28, 0, -76), 0.8, HOLIDAY.Red)
	buildGift(arena, Vector3.new(28, 0, 76), 0.8, HOLIDAY.Green)
	buildGift(arena, Vector3.new(-100, 0, 70), 0.65, HOLIDAY.Green)
	buildGift(arena, Vector3.new(100, 0, -70), 0.65, HOLIDAY.Red)
	buildGarland(arena, Vector3.new(-190, 10, -88), Vector3.new(190, 10, -88), 4, 24)
	buildGarland(arena, Vector3.new(-190, 10, 88), Vector3.new(190, 10, 88), 4, 24)
	buildSnowflake(arena, Vector3.new(-18, 9, -88), 1.3)
	buildSnowflake(arena, Vector3.new(18, 9, 88), 1.3)
	buildSnowEmitter(arena, Vector3.new(0, 28, 0), Vector3.new(390, 1, 170), 10)
end

local function buildCloud(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "BlockCloud"
	model.Parent = parent
	for _, entry in ipairs({
		{ Vector3.new(0, 0, 0), Vector3.new(12, 4, 7) },
		{ Vector3.new(-7, -1, 1), Vector3.new(7, 3, 6) },
		{ Vector3.new(7, -0.5, -1), Vector3.new(8, 3.5, 6) },
		{ Vector3.new(1, 2, 0), Vector3.new(7, 3, 5) },
	}) do
		local cloud = makePart(model, "CloudBlock", entry[2] * scale, CFrame.new(position + entry[1] * scale), C.White, Enum.Material.SmoothPlastic, false)
		cloud.CanQuery = false
	end
	return model
end

local function buildGate(parent, prefix, baseCFrame, width, height, accent)
	local function gatePart(suffix, size, offset, color, material, className)
		return decorPart(parent, prefix .. suffix, size, baseCFrame * offset, color, material, className)
	end
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (width / 2 - 1.5)
		gatePart("Pillar", Vector3.new(3, height, 4), CFrame.new(x, height / 2, 0), STYLE.Ivory, Enum.Material.Cobblestone)
		gatePart("PillarBand", Vector3.new(3.5, 0.65, 4.5), CFrame.new(x, height * 0.7, 0), accent, Enum.Material.Metal)
		local lamp = gatePart("Lamp", Vector3.new(1.1, 1.7, 1.1), CFrame.new(x, height * 0.52, 2.5), STYLE.Warm, Enum.Material.Neon)
		holidayGlow(lamp, STYLE.Warm, 10, 0.75)
	end
	gatePart("Lintel", Vector3.new(width, 3, 4), CFrame.new(0, height - 1.5, 0), STYLE.Ivory, Enum.Material.Cobblestone)
	gatePart("GoldInset", Vector3.new(width - 3, 0.55, 4.4), CFrame.new(0, height - 3, 2.1), STYLE.Gold, Enum.Material.Metal)
	gatePart("Roof", Vector3.new(width + 3, 3, 6), CFrame.new(0, height + 1, 0), STYLE.Navy, Enum.Material.Slate, "WedgePart")
	gatePart("RoofSnow", Vector3.new(width + 3.4, 0.45, 6.4), CFrame.new(0, height + 2.65, 0), HOLIDAY.Snow, Enum.Material.Snow)
end

local function buildCitadelTower(parent, prefix, position, accent)
	local function towerPart(suffix, size, offset, color, material, className)
		return decorPart(parent, prefix .. suffix, size, CFrame.new(position + offset), color, material, className)
	end
	towerPart("Body", Vector3.new(10, 16, 10), Vector3.new(0, 8, 0), STYLE.Ivory, Enum.Material.Cobblestone)
	towerPart("Band", Vector3.new(10.5, 1, 10.5), Vector3.new(0, 12, 0), accent, Enum.Material.Fabric)
	towerPart("Roof", Vector3.new(12, 4, 12), Vector3.new(0, 18, 0), STYLE.Navy, Enum.Material.Slate, "WedgePart")
	towerPart("Snow", Vector3.new(12.5, 0.5, 12.5), Vector3.new(0, 20.2, 0), HOLIDAY.Snow, Enum.Material.Snow)
	towerPart("Pole", Vector3.new(0.35, 7, 0.35), Vector3.new(0, 23, 0), C.Wood, Enum.Material.WoodPlanks)
	towerPart("Flag", Vector3.new(4.5, 2.8, 0.3), Vector3.new(2.2, 25, 0), accent, Enum.Material.Fabric)
	local lamp = towerPart("Lamp", Vector3.new(1.2, 1.6, 1.2), Vector3.new(0, 10, 5.3), STYLE.Warm, Enum.Material.Neon)
	holidayGlow(lamp, STYLE.Warm, 10, 0.7)
end

local function buildBaseArchitecture(arena, team, baseCFrame, accent)
	buildGate(arena, team .. "FrostGate", baseCFrame * CFrame.new(0, 0, 50), 30, 13, accent)
	buildGate(arena, team .. "RearGate", baseCFrame * CFrame.new(0, 0, -52), 64, 12, STYLE.Navy)
	-- A readable, non-colliding gate frame sits exactly over the playable
	-- opening between the two initial wall pairs.
	buildGate(arena, team .. "InnerGate", baseCFrame * CFrame.new(0, 0, -28), 32, 11, accent)
	decorPart(arena, team .. "GateLane", Vector3.new(8, 0.12, 68), baseCFrame * CFrame.new(0, 0.55, 3), STYLE.Navy, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		decorPart(arena, team .. "GateLaneEdge", Vector3.new(0.35, 0.14, 68), baseCFrame * CFrame.new(side * 4.2, 0.62, 3), accent, Enum.Material.Neon)
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -42, 42 }) do
			local towerCFrame = baseCFrame * CFrame.new(side * 44, 0, forward)
			decorPart(arena, team .. "TowerRoof", Vector3.new(10, 4, 10), towerCFrame * CFrame.new(0, 12, 0), STYLE.Navy, Enum.Material.Slate, "WedgePart")
			decorPart(arena, team .. "TowerRoofSnow", Vector3.new(10.5, 0.45, 10.5), towerCFrame * CFrame.new(0, 14.2, 0), HOLIDAY.Snow, Enum.Material.Snow)
		end
	end
	decorPart(arena, team .. "CourtyardInlay", Vector3.new(70, 0.12, 2), baseCFrame * CFrame.new(0, 0.48, 0), accent, Enum.Material.Metal)
end

local function buildFireplace(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "FrostfireFireplace"
	model.Parent = parent
	local function piece(name, size, offset, color, material)
		return decorPart(model, name, size * scale, CFrame.new(position + offset * scale), color, material)
	end
	piece("Hearth", Vector3.new(12, 1, 6), Vector3.new(0, 0.5, 0), STYLE.IvoryDark, Enum.Material.Cobblestone)
	for _, side in ipairs({ -1, 1 }) do
		piece("FireplacePillar", Vector3.new(2, 8, 4), Vector3.new(side * 4.5, 4.5, 0), STYLE.Ivory, Enum.Material.Cobblestone)
	end
	piece("FireplaceLintel", Vector3.new(11, 2, 4), Vector3.new(0, 8, 0), STYLE.Ivory, Enum.Material.Cobblestone)
	piece("FireplaceOpening", Vector3.new(7, 5.5, 0.6), Vector3.new(0, 3.8, 2.1), STYLE.Navy, Enum.Material.Slate)
	piece("FireplaceMantel", Vector3.new(13, 0.7, 5), Vector3.new(0, 9.2, 0), STYLE.Gold, Enum.Material.WoodPlanks)
	local flame = piece("FireplaceFlame", Vector3.new(3, 3.5, 1), Vector3.new(0, 3, 2.6), STYLE.Warm, Enum.Material.Neon)
	holidayGlow(flame, STYLE.Warm, 16, 1.1)
	return model
end

local function buildLobbyArchitecture(lobby)
	buildGate(lobby, "LobbyEntry", CFrame.new(0, 44.5, 252), 46, 14, STYLE.Navy)
	for _, z in ipairs({ 270, 330, 390 }) do
		for _, side in ipairs({ -1, 1 }) do
			decorPart(lobby, "HallColumn", Vector3.new(3, 20, 3), CFrame.new(side * 94, 54.5, z), STYLE.Ivory, Enum.Material.Cobblestone)
			decorPart(lobby, "HallColumnTrim", Vector3.new(3.6, 0.7, 3.6), CFrame.new(side * 94, 63.5, z), STYLE.Gold, Enum.Material.Metal)
		end
		decorPart(lobby, "HallRib", Vector3.new(190, 2, 2), CFrame.new(0, 65, z), STYLE.Navy, Enum.Material.Slate)
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ 300, 340, 380 }) do
			decorPart(lobby, "WindowGlass", Vector3.new(0.5, 10, 18), CFrame.new(side * 101, 51, z), STYLE.Ice, Enum.Material.Glass).Transparency = 0.28
			decorPart(lobby, "WindowTop", Vector3.new(1, 0.7, 19), CFrame.new(side * 101, 56.2, z), STYLE.Navy, Enum.Material.Metal)
			decorPart(lobby, "WindowMullion", Vector3.new(1, 10, 0.6), CFrame.new(side * 101, 51, z), STYLE.Navy, Enum.Material.Metal)
		end
		buildFireplace(lobby, Vector3.new(side * 85, 44.5, 335), 0.9)
	end
	decorPart(lobby, "GalleryBackdrop", Vector3.new(170, 11, 0.8), CFrame.new(0, 50.5, 265), STYLE.Navy, Enum.Material.Fabric)
	decorPart(lobby, "GalleryCrown", Vector3.new(172, 0.55, 1), CFrame.new(0, 56.2, 265), STYLE.Gold, Enum.Material.Metal)
	decorPart(lobby, "HallAxis", Vector3.new(2, 0.12, 145), CFrame.new(0, 44.58, 330), STYLE.Navy, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		decorPart(lobby, "HallAxisGold", Vector3.new(0.35, 0.14, 145), CFrame.new(side * 2, 44.6, 330), STYLE.Gold, Enum.Material.Metal)
	end
	for _, entry in ipairs({
		{ Vector3.new(-48, 44.6, 344), STYLE.Blue }, { Vector3.new(48, 44.6, 344), STYLE.Gold },
		{ Vector3.new(-48, 44.6, 300), STYLE.Warm }, { Vector3.new(48, 44.6, 300), Color3.fromRGB(178, 125, 224) },
	}) do
		decorPart(lobby, "ShopRug", Vector3.new(20, 0.12, 16), CFrame.new(entry[1]), entry[2], Enum.Material.Fabric)
	end
	local signAnchor = decorPart(lobby, "FrostfireSign", Vector3.new(1, 1, 1), CFrame.new(0, 62, 330), C.White, Enum.Material.SmoothPlastic)
	signAnchor.Transparency = 1
	billboard(signAnchor, "AURORA  //  BASTION", STYLE.Gold, Vector3.zero, UDim2.fromOffset(440, 70))
	for _, z in ipairs({ 280, 320, 360, 400 }) do
		local lamp = decorPart(lobby, "HallLight", Vector3.new(2, 0.5, 2), CFrame.new(0, 62, z), STYLE.Warm, Enum.Material.Neon)
		holidayGlow(lamp, STYLE.Warm, 14, 0.8)
	end
end

local function buildArenaArchitecture(arena)
	for _, side in ipairs({ -1, 1 }) do
		local canal = decorPart(arena, "FrozenCanal", Vector3.new(420, 0.12, 7), CFrame.new(0, 0.08, side * 84), STYLE.Ice, Enum.Material.Ice)
		canal.Transparency = 0.18
		for _, x in ipairs({ -100, 0, 100 }) do
			decorPart(arena, "CanalBridge", Vector3.new(20, 0.35, 13), CFrame.new(x, 0.25, side * 84), STYLE.Ivory, Enum.Material.Cobblestone)
			decorPart(arena, "BridgeInlay", Vector3.new(14, 0.1, 1), CFrame.new(x, 0.48, side * 84), STYLE.Gold, Enum.Material.Metal)
		end
		for _, x in ipairs({ -72, 72 }) do
			buildGate(arena, "LaneGate", CFrame.new(x, 0, side * 62) * CFrame.Angles(0, math.rad(90), 0), 18, 9, STYLE.Navy)
		end
	end
	for _, z in ipairs({ -11, 11, -69, -55, 55, 69 }) do
		decorPart(arena, "LaneBorder", Vector3.new(300, 0.12, 0.8), CFrame.new(0, 0.38, z), STYLE.Gold, Enum.Material.Metal)
	end
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		decorPart(arena, "CapturePlazaTile", Vector3.new(8, 0.25, 3), CFrame.new(math.cos(angle) * 19, 0.25, math.sin(angle) * 19) * CFrame.Angles(0, -angle, 0), index % 2 == 0 and STYLE.Ivory or STYLE.Navy, Enum.Material.Cobblestone)
	end
	for _, position in ipairs({
		Vector3.new(-45, 3, -35), Vector3.new(45, 3, 35), Vector3.new(-45, 3, 35), Vector3.new(45, 3, -35),
	}) do
		decorPart(arena, "CoverCap", Vector3.new(12.5, 0.5, 8.5), CFrame.new(position + Vector3.new(0, 3.3, 0)), STYLE.Ivory, Enum.Material.Cobblestone)
		decorPart(arena, "CoverInlay", Vector3.new(1, 0.55, 8.7), CFrame.new(position + Vector3.new(0, 3.35, 0)), STYLE.Navy, Enum.Material.Metal)
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -1, 1 }) do
			buildCitadelTower(arena, "PerimeterTower", Vector3.new(side * 244, 0, forward * 94), STYLE.Navy)
		end
	end
end

local function buildBase(arena, structures, team)
	local color = Config.Teams[team].Color
	local base = Config.BasePosition(team)
	local baseCFrame = Config.BaseCFrame(team)
	local presentation = Config.Presentation
	local platform = makePart(arena, team .. "BasePlatform", Vector3.new(presentation.BaseWidth, 4, presentation.BaseDepth), CFrame.new(base.X, 2, 0), STYLE.IvoryDark, Enum.Material.Cobblestone, true)
	platform:SetAttribute("Team", team)
	makePart(arena, team .. "BaseGrass", Vector3.new(presentation.BaseWidth - 6, 0.5, presentation.BaseDepth - 6), CFrame.new(base.X, 4.15, 0), C.Grass, Enum.Material.Grass, true)
	-- The courtyard is raised above the field. Broad, shallow steps give
	-- Humanoid navigation a real walkable descent instead of a 4.4-stud cliff.
	for _, laneX in ipairs(Config.Objectives.Lanes) do
		for step = 1, 5 do
			local top = 4.4 * (1 - step / 5)
			local height = 0.88
			local centerY = top - height / 2
			local stepPart = makePart(arena, team .. "ExitStep", Vector3.new(10, height, 4), baseCFrame * CFrame.new(laneX, centerY - base.Y, -62 - step * 4), STYLE.IvoryDark, Enum.Material.Cobblestone, true)
			stepPart:SetAttribute("BotWalkway", true)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -42, 42 }) do
			local towerCFrame = baseCFrame * CFrame.new(side * 44, 5, forward)
			makePart(arena, team .. "CornerTower", Vector3.new(8, 10, 8), towerCFrame, C.StoneDark, Enum.Material.Cobblestone, true)
			makePart(arena, team .. "CornerTrim", Vector3.new(8.6, 1, 8.6), towerCFrame * CFrame.new(0, -2.5, 0), C.Stone, Enum.Material.Cobblestone, true)
			makePart(arena, team .. "CornerBanner", Vector3.new(8.5, 1.2, 8.5), towerCFrame * CFrame.new(0, 5.5, 0), color, Enum.Material.Fabric, true)
			for _, x in ipairs({ -1, 1 }) do
				for _, z in ipairs({ -1, 1 }) do
					makePart(arena, team .. "CornerBattlement", Vector3.new(2, 1.5, 2), towerCFrame * CFrame.new(x * 3.1, 6.8, z * 3.1), C.StoneDark, Enum.Material.Cobblestone, true)
				end
			end
			makePart(arena, team .. "FlagPole", Vector3.new(0.45, 10, 0.45), towerCFrame * CFrame.new(0, 12, 0), C.Wood, Enum.Material.WoodPlanks, false)
			local flag = makePart(arena, team .. "TeamFlag", Vector3.new(4.5, 3, 0.5), towerCFrame * CFrame.new(2.3, 15, 0), color, Enum.Material.Fabric, false)
			flag.CanQuery = false
		end
	end
	buildBaseArchitecture(arena, team, baseCFrame, color)
	local marker = makePart(arena, team .. "BaseMarker", Vector3.new(1, 1, 1), CFrame.new(base + Vector3.new(0, 25, 0)), color, Enum.Material.SmoothPlastic, false)
	marker.Transparency = 1
	marker.CanQuery = false
	billboard(marker, Config.Teams[team].Name .. " // КРЕПОСТЬ", color, Vector3.zero, UDim2.fromScale(1, 1))
	local spawnCFrame = baseCFrame * CFrame.new(0, 4, 34)
	local spawn = makePart(arena, team .. "Spawn", Vector3.new(12, 1, 12), spawnCFrame, color, Enum.Material.Neon, false, "SpawnLocation")
	spawn.Neutral = true
	spawn.CanQuery = false
	-- Tags let the local visibility controller hide only the opposing base during Build.
	for _, part in ipairs(arena:GetChildren()) do
		if part:IsA("BasePart") and string.sub(part.Name, 1, #team) == team then
			part:SetAttribute("Team", team)
			part:SetAttribute("BaseGeometry", true)
		end
	end
	return spawnCFrame + Vector3.new(0, 3, 0)
end

local function buildNpc(parent, name, position, color, title, action, description)
	local model = Instance.new("Model")
	model.Name = "NPC_" .. name
	model.Parent = parent
	local root = makePart(model, "Root", Vector3.new(3.2, 4.5, 2.2), CFrame.new(position + Vector3.new(0, 2.5, 0)), color, Enum.Material.SmoothPlastic, true)
	model.PrimaryPart = root
	makePart(model, "Head", Vector3.new(2.5, 2.2, 2.5), CFrame.new(position + Vector3.new(0, 6, 0)), Color3.fromRGB(224, 190, 145), Enum.Material.SmoothPlastic, true)
	makePart(model, "Hat", Vector3.new(3, 0.65, 3), CFrame.new(position + Vector3.new(0, 7.35, 0)), C.StoneDark, Enum.Material.Fabric, true)
	for _, side in ipairs({ -1, 1 }) do
		makePart(model, "Arm", Vector3.new(0.85, 3.2, 1), CFrame.new(position + Vector3.new(side * 2.1, 2.6, 0)), color, Enum.Material.SmoothPlastic, true)
		makePart(model, "Leg", Vector3.new(1.1, 2.2, 1.2), CFrame.new(position + Vector3.new(side * 0.75, -0.9, 0)), C.StoneDark, Enum.Material.SmoothPlastic, true)
	end
	local ring = makePart(model, "NeonRing", Vector3.new(6, 0.25, 6), CFrame.new(position + Vector3.new(0, 0.15, 0)), color, Enum.Material.Neon, false)
	ring.CanQuery = false
	local light = Instance.new("PointLight")
	light.Name = "NPCGlow"
	light.Color = color
	light.Brightness = 1.6
	light.Range = 16
	light.Parent = root
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "NPCSparkles"
	sparkles.SparkleColor = color
	sparkles.Parent = root
	billboard(root, title .. "\n" .. description, color, Vector3.new(0, 5.5, 0), UDim2.fromScale(1, 1))
	return prompt(root, action, description)
end

local function buildLobby(lobby)
	local presentation = Config.Presentation
	local lobbyWidth = presentation.LobbyWidth
	local lobbyDepth = presentation.LobbyDepth
	makePart(lobby, "LobbyStone", Vector3.new(lobbyWidth, 8, lobbyDepth), CFrame.new(0, 36, 330), STYLE.Navy, Enum.Material.Cobblestone, true)
	makePart(lobby, "LobbyDirt", Vector3.new(lobbyWidth - 4, 5, lobbyDepth - 4), CFrame.new(0, 41, 330), C.Dirt, Enum.Material.Ground, true)
	makePart(lobby, "LobbyGrass", Vector3.new(lobbyWidth - 6, 1, lobbyDepth - 6), CFrame.new(0, 44, 330), C.Grass, Enum.Material.Grass, true)
	local spawnCFrame = CFrame.lookAt(Vector3.new(0, 48, 365), Vector3.new(0, 48, 330))
	local spawn = makePart(lobby, "LobbySpawn", Vector3.new(12, 1, 12), spawnCFrame, C.White, Enum.Material.Neon, false, "SpawnLocation")
	spawn.Neutral = true
	spawn.CanQuery = false

	-- Continuous safety walls follow the new hall footprint, including its corners.
	local halfWidth = lobbyWidth / 2
	local halfDepth = lobbyDepth / 2
	for _, side in ipairs({ -1, 1 }) do
		makePart(lobby, "LobbySafetyWall", Vector3.new(1.5, 18, lobbyDepth - 4), CFrame.new(side * (halfWidth - 3), 53, 330), Color3.fromRGB(135, 190, 210), Enum.Material.Glass, true).Transparency = 0.72
		makePart(lobby, "LobbyFenceRail", Vector3.new(1.2, 1, lobbyDepth - 4), CFrame.new(side * (halfWidth - 3.5), 48, 330), STYLE.Gold, Enum.Material.Metal, true)
		local sidePostCount = math.floor((lobbyDepth - 8) / 15.5)
		for index = 0, sidePostCount do
			local z = 330 - (lobbyDepth - 8) / 2 + index * 15.5
			makePart(lobby, "LobbyFencePost", Vector3.new(2, 7, 2), CFrame.new(side * (halfWidth - 3.5), 47.5, z), STYLE.Navy, Enum.Material.Cobblestone, true)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		makePart(lobby, "LobbySafetyWall", Vector3.new(lobbyWidth - 4, 18, 1.5), CFrame.new(0, 53, 330 + side * (halfDepth - 2)), Color3.fromRGB(135, 190, 210), Enum.Material.Glass, true).Transparency = 0.72
		makePart(lobby, "LobbyFenceRail", Vector3.new(lobbyWidth - 4, 1, 1.2), CFrame.new(0, 48, 330 + side * (halfDepth - 2.5)), STYLE.Gold, Enum.Material.Metal, true)
		local frontPostCount = math.floor((lobbyWidth - 8) / 15.5)
		for index = 0, frontPostCount do
			local x = -(lobbyWidth - 8) / 2 + index * 15.5
			makePart(lobby, "LobbyFencePost", Vector3.new(2, 7, 2), CFrame.new(x, 47.5, 330 + side * (halfDepth - 2.5)), STYLE.Navy, Enum.Material.Cobblestone, true)
		end
	end

	local crate = makePart(lobby, "LobbyLootbox", Vector3.new(9, 7, 9), CFrame.new(0, 48, 318), C.Gold, Enum.Material.Metal, true)
	local crateLight = Instance.new("PointLight")
	crateLight.Color = C.Gold
	crateLight.Brightness = 1.2
	crateLight.Range = 18
	crateLight.Parent = crate
	makePart(lobby, "LootboxBand", Vector3.new(9.5, 1.2, 9.5), CFrame.new(0, 49, 318), C.StoneDark, Enum.Material.Metal, true)
	billboard(crate, "GEAR // ЛУТБОКС", C.Gold)
	local lootPrompt = prompt(crate, "ОТКРЫТЬ", "Игровые кейсы · шансы 65 / 30 / 5")

	local board = makePart(lobby, "StartBoard", Vector3.new(18, 12, 1.5), CFrame.new(-30, 51, 318), C.StoneDark, Enum.Material.WoodPlanks, true)
	billboard(board, "BLOCK // БОЙ 6×6", C.White, Vector3.new(0, 0, 0))
	local startPrompt = prompt(board, "В БОЙ", "Быстрый старт · боты заполняют команды")

	local displayColumns = math.max(1, math.ceil(#Catalog.WeaponOrder / 2))
	for index, weaponId in ipairs(Catalog.WeaponOrder) do
		local row = math.floor((index - 1) / displayColumns)
		local column = (index - 1) % displayColumns
		local x = (column - (displayColumns - 1) / 2) * 24
		local z = 292 - row * 16
		makePart(lobby, "WeaponPedestal", Vector3.new(10, 3, 10), CFrame.new(x, 46, z), C.Stone, Enum.Material.Cobblestone, true)
		local weapon = WeaponModels.Build(weaponId)
		weapon.Name = "Display_" .. weaponId
		weapon.Parent = lobby
		weapon:PivotTo(CFrame.new(x, 50, z) * CFrame.Angles(0, math.rad(90), 0))
		for _, item in ipairs(weapon:GetDescendants()) do
			if item:IsA("BasePart") then
				item.Anchored = true
			end
		end
		local labelAnchor = makePart(lobby, "WeaponLabelAnchor", Vector3.new(1, 1, 1), CFrame.new(x, 52, z), C.White, Enum.Material.SmoothPlastic, false)
		labelAnchor.Transparency = 1
		labelAnchor.CanQuery = false
		local definition = Catalog.GetWeapon(weaponId)
		billboard(labelAnchor, definition.Name, Catalog.RarityColors[definition.Rarity], Vector3.zero)
	end

	local upgradePrompt = buildNpc(lobby, "UpgradeForge", Vector3.new(-48, 44.5, 344), Color3.fromRGB(88, 220, 255), "FORGE // УЛУЧШЕНИЯ", "УЛУЧШИТЬ", "HP · броня · скорость · постройки")
	local dailyPrompt = buildNpc(lobby, "DailyBonus", Vector3.new(48, 44.5, 344), Color3.fromRGB(255, 211, 78), "DAILY // БОНУС", "ПОЛУЧИТЬ", "Монеты · XP · жетон кейса")
	local shopPrompt = buildNpc(lobby, "CosmeticShop", Vector3.new(48, 44.5, 300), Color3.fromRGB(195, 117, 255), "ROBUX // КОСМЕТИКА", "МАГАЗИН", "Только внешний вид · без pay-to-win")
	local defensePrompt = buildNpc(lobby, "DefenseWorkshop", Vector3.new(-48, 44.5, 300), Color3.fromRGB(255, 133, 71), "DEFENSE // ЛОВУШКИ", "КУПИТЬ ЧЕРТЁЖ", "Шипы · мины · огнемёт за монеты")
	local upgradePad = makePart(lobby, "UpgradePad", Vector3.new(16, 0.35, 12), CFrame.new(-48, 44.8, 344), Color3.fromRGB(40, 120, 145), Enum.Material.Metal, false)
	upgradePad.CanQuery = false
	local dailyPad = makePart(lobby, "DailyPad", Vector3.new(16, 0.35, 12), CFrame.new(48, 44.8, 344), Color3.fromRGB(150, 110, 35), Enum.Material.Metal, false)
	dailyPad.CanQuery = false
	local shopPad = makePart(lobby, "ShopPad", Vector3.new(16, 0.35, 12), CFrame.new(48, 44.8, 300), Color3.fromRGB(105, 55, 145), Enum.Material.Metal, false)
	shopPad.CanQuery = false
	local defensePad = makePart(lobby, "DefensePad", Vector3.new(16, 0.35, 12), CFrame.new(-48, 44.8, 300), Color3.fromRGB(150, 65, 35), Enum.Material.Metal, false)
	defensePad.CanQuery = false

	for _, position in ipairs({ Vector3.new(-70, 44.5, 370), Vector3.new(70, 44.5, 370), Vector3.new(-70, 44.5, 280), Vector3.new(70, 44.5, 280) }) do
		buildChristmasTree(lobby, position, 0.55)
	end
	decorateLobby(lobby)
	buildLobbyArchitecture(lobby)
	return spawnCFrame, lootPrompt, startPrompt, upgradePrompt, dailyPrompt, shopPrompt, defensePrompt
end

local function buildDotaFrontier(arena)
	local campSpots = {}
	for _, lane in ipairs(Config.Objectives.Lanes) do
		local laneName = lane < 0 and "TOP LANE" or (lane > 0 and "BOTTOM LANE" or "MID LANE // 67")
		for _, edge in ipairs({ -1, 1 }) do
			decorPart(arena, "FrontierLaneBorder", Vector3.new(510, 0.12, 0.8), CFrame.new(0, 0.42, lane + edge * 10), STYLE.Gold, Enum.Material.Metal)
		end
		local marker = makePart(arena, "LaneLabelAnchor", Vector3.new(1, 1, 1), CFrame.new(0, 8, lane), C.White, Enum.Material.SmoothPlastic, false)
		marker.Transparency = 1
		marker.CanQuery = false
		billboard(marker, laneName, STYLE.Gold, Vector3.zero, UDim2.fromOffset(250, 42))
	end
	local river = decorPart(arena, "FrozenRiver", Vector3.new(18, 0.16, 340), CFrame.new(0, 0.06, 0), STYLE.Ice, Enum.Material.Ice)
	river.Transparency = 0.25
	for _, lane in ipairs(Config.Objectives.Lanes) do
		decorPart(arena, "FrontierBridge", Vector3.new(30, 0.45, 24), CFrame.new(0, 0.28, lane), STYLE.IvoryDark, Enum.Material.Cobblestone)
		decorPart(arena, "FrontierBridgeInlay", Vector3.new(22, 0.1, 1), CFrame.new(0, 0.56, lane), STYLE.Gold, Enum.Material.Metal)
	end
	for _, x in ipairs({ -170, -85, 85, 170 }) do
		for _, side in ipairs({ -1, 1 }) do
			local path = makePart(arena, "JunglePath", Vector3.new(10, 0.25, 86), CFrame.new(x, 0.16, side * 56), C.Dirt, Enum.Material.Ground, false)
			path.CanQuery = false
			for _, offset in ipairs({ Vector3.new(-9, 0, -28), Vector3.new(9, 0, 28) }) do
				buildTree(arena, Vector3.new(x, 0, side * 56) + offset, 0.62)
			end
		end
	end
	for _, team in ipairs(Config.TeamOrder) do
		local side = team == "Blue" and -1 or 1
		for _, lane in ipairs(Config.Objectives.Lanes) do
			for _, distance in ipairs(Config.Objectives.TowerDistances) do
				local zOffset = lane == 0 and 18 or (lane > 0 and -16 or 16)
				local pad = makePart(arena, "LaneTowerPad", Vector3.new(13, 0.25, 13), CFrame.new(side * distance, 0.18, lane + zOffset), Config.Teams[team].Dark, Enum.Material.Cobblestone, false)
				pad:SetAttribute("Team", team)
				pad:SetAttribute("BaseGeometry", true)
				pad.CanQuery = false
			end
		end
	end
	for _, camp in ipairs(Config.Objectives.NeutralCamps) do
		local campModel = Instance.new("Model")
		campModel.Name = "NeutralCamp_" .. camp.Id
		campModel.Parent = arena
		local pad = makePart(campModel, "NeutralCampPad", Vector3.new(28, 0.3, 24), CFrame.new(camp.Position + Vector3.new(0, 0.15, 0)), C.StoneDark, Enum.Material.Cobblestone, false)
		pad.CanQuery = false
		for _, offset in ipairs({ Vector3.new(-17, 0, -11), Vector3.new(17, 0, 11), Vector3.new(-17, 0, 11) }) do
			buildTree(campModel, camp.Position + offset, 0.62)
		end
		makePart(campModel, "CampRock", Vector3.new(5, 4, 5), CFrame.new(camp.Position + Vector3.new(10, 2, -7)), C.Stone, Enum.Material.Slate, true)
		local marker = makePart(campModel, "CampLabelAnchor", Vector3.new(1, 1, 1), CFrame.new(camp.Position + Vector3.new(0, 9, 0)), C.White, Enum.Material.SmoothPlastic, false)
		marker.Transparency = 1
		marker.CanQuery = false
		billboard(marker, "NEUTRAL CAMP // " .. string.upper(camp.Id), Color3.fromRGB(194, 223, 191), Vector3.zero, UDim2.fromOffset(230, 36))
		table.insert(campSpots, { Id = camp.Id, Position = camp.Position, Model = campModel })
	end
	return campSpots
end

local function buildCapturePoint(parent)
	local model = Instance.new("Model")
	model.Name = "Capture67"
	model.Parent = parent
	local base = makePart(model, "CaptureBase", Vector3.new(28, 0.8, 28), CFrame.new(0, 0.4, 0), C.StoneDark, Enum.Material.Cobblestone, true)
	base:SetAttribute("CaptureGeometry", true)
	local crystal = makePart(model, "CaptureCrystal", Vector3.new(7, 10, 7), CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(237, 190, 64), Enum.Material.DiamondPlate, true)
	model.PrimaryPart = crystal
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -1, 1 }) do
			makePart(model, "CapturePylon", Vector3.new(2.2, 7, 2.2), CFrame.new(side * 11, 3.5, forward * 11), C.Stone, Enum.Material.Metal, true)
			makePart(model, "CaptureGlow", Vector3.new(2.5, 0.6, 2.5), CFrame.new(side * 11, 7.2, forward * 11), Color3.fromRGB(237, 190, 64), Enum.Material.Neon, false)
		end
	end
	for index = 1, 4 do
		local angle = math.rad(index * 90)
		makePart(model, "CaptureRing", Vector3.new(8, 0.3, 1), CFrame.new(math.cos(angle) * 9, 1.1, math.sin(angle) * 9) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(237, 190, 64), Enum.Material.Neon, false)
	end
	local light = Instance.new("PointLight")
	light.Name = "CaptureLight"
	light.Color = Color3.fromRGB(237, 190, 64)
	light.Brightness = 2.5
	light.Range = 30
	light.Parent = crystal
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = "CaptureSparkles"
	sparkles.SparkleColor = Color3.fromRGB(237, 190, 64)
	sparkles.Parent = crystal
	local gui = billboard(crystal, "67", Color3.fromRGB(255, 222, 105), Vector3.new(0, 8, 0), UDim2.fromScale(1, 1))
	gui.Name = "Capture67Label"
	gui.Size = UDim2.fromOffset(250, 140)
	local label = gui:FindFirstChild("TextLabel")
	label.TextStrokeTransparency = 0.05
	local subtitleAnchor = makePart(model, "CaptureSubtitleAnchor", Vector3.new(1, 1, 1), CFrame.new(0, 2, 0), C.White, Enum.Material.SmoothPlastic, false)
	subtitleAnchor.Transparency = 1
	subtitleAnchor.CanQuery = false
	billboard(subtitleAnchor, "CAPTURE // КОНТРОЛЬ", C.White, Vector3.new(0, 4, 0), UDim2.fromScale(1, 1))
	model:SetAttribute("CaptureRadius", 22)
	return { Model = model, Root = crystal, Label = label, Light = light }
end

function WorldBuilder.Build()
	buildSerial = buildSerial + 1
	local serial = buildSerial
	local old = Workspace:FindFirstChild("BlockSiegeWorld")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "BlockSiegeWorld"
	root.Parent = Workspace
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = root
	local structures = Instance.new("Folder")
	structures.Name = "Structures"
	structures.Parent = root
	local bots = Instance.new("Folder")
	bots.Name = "Bots"
	bots.Parent = root
	local neutrals = Instance.new("Folder")
	neutrals.Name = "Neutrals"
	neutrals.Parent = root
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = root

	local presentation = Config.Presentation
	makePart(arena, "ArenaDirt", Vector3.new(presentation.ArenaWidth, 8, presentation.ArenaDepth), CFrame.new(0, -6, 0), C.Dirt, Enum.Material.Ground, true)
	makePart(arena, "ArenaGrass", Vector3.new(presentation.ArenaWidth, 2, presentation.ArenaDepth), CFrame.new(0, -1, 0), C.Grass, Enum.Material.Grass, true)
	makePart(arena, "CenterLane", Vector3.new(510, 0.35, 22), CFrame.new(0, 0.15, 0), C.Sand, Enum.Material.Ground, true)
	for _, z in ipairs(Config.Objectives.Lanes) do
		if z ~= 0 then
			makePart(arena, "SideLane", Vector3.new(540, 0.3, 16), CFrame.new(0, 0.12, z), C.Sand, Enum.Material.Ground, true)
		end
	end
	for index = 0, 31 do
		local x = -310 + index * 20
		local height = 8 + (index * 5 % 7)
		for _, side in ipairs({ -1, 1 }) do
			makePart(arena, "CliffDirt", Vector3.new(20, height, 6), CFrame.new(x, -10 - height / 2, side * presentation.ArenaEdgeZ), C.Dirt, Enum.Material.Ground, true)
			makePart(arena, "CliffStone", Vector3.new(18, 3, 6.5), CFrame.new(x, -12, side * presentation.ArenaEdgeZ), STYLE.Navy, Enum.Material.Slate, true)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local zWall = makePart(arena, "ArenaBoundary", Vector3.new(presentation.ArenaWidth, 20, 2), CFrame.new(0, 8, side * presentation.ArenaEdgeZ), STYLE.Navy, Enum.Material.Slate, true)
		zWall.CanQuery = false
		decorPart(arena, "ArenaBoundarySnow", Vector3.new(presentation.ArenaWidth, 0.5, 2.5), CFrame.new(0, 18.25, side * presentation.ArenaEdgeZ), HOLIDAY.Snow, Enum.Material.Snow)
		local xWall = makePart(arena, "ArenaBoundary", Vector3.new(2, 20, presentation.ArenaDepth), CFrame.new(side * presentation.ArenaEdgeX, 8, 0), STYLE.Navy, Enum.Material.Slate, true)
		xWall.CanQuery = false
		decorPart(arena, "ArenaBoundarySnow", Vector3.new(2.5, 0.5, presentation.ArenaDepth), CFrame.new(side * presentation.ArenaEdgeX, 18.25, 0), HOLIDAY.Snow, Enum.Material.Snow)
	end
	for index = 1, 48 do
		local x = (index * 47 % 180) - 90
		local z = (index * 71 % 160) - 80
		if math.abs(z) > 12 then
			local tuft = makePart(arena, "GrassTuft", Vector3.new(0.45, 0.7 + (index % 3) * 0.2, 0.45), CFrame.new(x, 0.4, z), C.Leaf, Enum.Material.Grass, false)
			tuft.CanQuery = false
		end
	end
	for _, entry in ipairs({
		{ Vector3.new(-190, 62, -105), 1.1 }, { Vector3.new(-80, 76, -120), 0.85 },
		{ Vector3.new(45, 68, -112), 1.2 }, { Vector3.new(175, 72, -105), 0.9 },
		{ Vector3.new(-165, 70, 110), 0.9 }, { Vector3.new(-35, 60, 118), 1.1 },
		{ Vector3.new(95, 78, 112), 0.85 }, { Vector3.new(205, 64, 100), 1.15 },
	}) do
		buildCloud(arena, entry[1], entry[2])
	end

	local teamSpawns = {}
	for _, team in ipairs(Config.TeamOrder) do
		teamSpawns[team] = buildBase(arena, structures, team)
	end

	for _, position in ipairs({
		Vector3.new(-70, 0, -72), Vector3.new(-35, 0, 73), Vector3.new(35, 0, -73), Vector3.new(70, 0, 72),
		Vector3.new(-10, 0, -78), Vector3.new(10, 0, 78), Vector3.new(-90, 0, 62), Vector3.new(90, 0, -62),
	}) do
		buildTree(arena, position, 0.85)
	end
	for _, entry in ipairs({
		{ Vector3.new(-45, 3, -35), Vector3.new(12, 6, 8) },
		{ Vector3.new(45, 3, 35), Vector3.new(12, 6, 8) },
		{ Vector3.new(-45, 3, 35), Vector3.new(12, 6, 8) },
		{ Vector3.new(45, 3, -35), Vector3.new(12, 6, 8) },
	}) do
		makePart(arena, "StoneCover", entry[2], CFrame.new(entry[1]), C.Stone, Enum.Material.Cobblestone, true)
	end
	decorateArena(arena)
	buildArenaArchitecture(arena)
	local neutralCamps = buildDotaFrontier(arena)

	local capturePoint = buildCapturePoint(arena)
	local lobbySpawn, lootPrompt, startPrompt, upgradePrompt, dailyPrompt, shopPrompt, defensePrompt = buildLobby(lobby)
	Lighting.Brightness = 2.6
	Lighting.ClockTime = 15.5
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(155, 181, 211)
	Lighting.ColorShift_Top = Color3.fromRGB(214, 235, 255)
	local function ensureEffect(className, name)
		local effect = Lighting:FindFirstChild(name)
		if not effect then
			effect = Instance.new(className)
			effect.Name = name
			effect.Parent = Lighting
		end
		return effect
	end
	local atmosphere = ensureEffect("Atmosphere", "BlockSiegeAtmosphere")
	atmosphere.Density = 0.18
	atmosphere.Haze = 0.35
	local colorCorrection = ensureEffect("ColorCorrectionEffect", "BlockSiegeColor")
	colorCorrection.Saturation = 0.02
	colorCorrection.Contrast = 0.1
	local bloom = ensureEffect("BloomEffect", "BlockSiegeBloom")
	bloom.Intensity = 0.25
	bloom.Size = 18
	bloom.Threshold = 1.05
	local rays = ensureEffect("SunRaysEffect", "BlockSiegeSun")
	rays.Intensity = 0.025

	if AssetService and task and task.spawn then
		task.spawn(function()
			loadCreatorStoreDecorations(root, lobby, arena, serial)
		end)
	end

	return {
		Root = root,
		Arena = arena,
		Structures = structures,
		Bots = bots,
		Neutrals = neutrals,
		NeutralCamps = neutralCamps,
		Lobby = lobby,
		LobbySpawn = lobbySpawn,
		TeamSpawns = teamSpawns,
		LootPrompt = lootPrompt,
		StartPrompt = startPrompt,
		UpgradePrompt = upgradePrompt,
		DailyPrompt = dailyPrompt,
		ShopPrompt = shopPrompt,
		DefensePrompt = defensePrompt,
		CapturePoint = capturePoint,
	}
end

return WorldBuilder
