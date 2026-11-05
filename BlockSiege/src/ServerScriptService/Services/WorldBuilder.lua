-- Симметричная sculpted-арена и свободное лобби с витриной оружия и лутбоксом.
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
local VisualModels = require(Shared:WaitForChild("VisualModels"))

local WorldBuilder = {}
local buildSerial = 0
local C = {
	Grass = Color3.fromRGB(91, 158, 91),
	Dirt = Color3.fromRGB(116, 88, 65),
	Stone = Color3.fromRGB(151, 158, 159),
	StoneDark = Color3.fromRGB(66, 76, 84),
	Wood = Color3.fromRGB(137, 91, 56),
	Leaf = Color3.fromRGB(52, 126, 69),
	Sand = Color3.fromRGB(195, 172, 127),
	White = Color3.fromRGB(245, 244, 232),
	Gold = Color3.fromRGB(244, 188, 72),
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
	-- The old five-cube VoxelTree is intentionally gone. The trunk remains a
	-- small gameplay obstacle; the sculpted crown is non-interactive.
	return VisualModels.Tree(parent, position, scale, {
		Name = "FortressPine", Snow = true, Collide = true, Query = true,
	})
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
	Ivory = Color3.fromRGB(224, 215, 190),
	IvoryDark = Color3.fromRGB(151, 143, 123),
	Navy = Color3.fromRGB(51, 66, 79),
	Blue = Color3.fromRGB(69, 190, 239),
	Ice = Color3.fromRGB(104, 190, 211),
	Gold = Color3.fromRGB(235, 177, 62),
	Warm = Color3.fromRGB(239, 137, 71),
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

-- Curated free Creator Store models: Roblox-owned holiday decor plus credited
-- community mesh props. Only visual geometry is copied; source assets are never
-- parented into the game and every placement has a procedural fallback nearby.
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
	{
		Key = "RealisticPines", Id = 4783126123, Title = "[FREE] Realistic Pine Trees", Credit = "@QualityModeIs · Creator Store asset 4783126123", Shadows = true,
		Placements = {
			{ Parent = "Arena", Position = Vector3.new(-220, 0, -118), Size = 25, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(18), 0) },
			{ Parent = "Arena", Position = Vector3.new(220, 0, 118), Size = 25, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(-22), 0) },
			{ Parent = "Arena", Position = Vector3.new(-120, 0, 125), Size = 20, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(41), 0) },
			{ Parent = "Arena", Position = Vector3.new(120, 0, -125), Size = 20, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(-37), 0) },
			{ Parent = "Lobby", Position = Vector3.new(86, 44.5, 382), Size = 18, Fit = "Height" },
			{ Parent = "Lobby", Position = Vector3.new(-86, 44.5, 278), Size = 18, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(30), 0) },
		},
	},
	{
		Key = "MedievalTower", Id = 4989364844, Title = "Low Poly Medieval Tower", Credit = "@anomon · Creator Store asset 4989364844 · free with credit", Shadows = true,
		Placements = {
			{ Parent = "Arena", Position = Vector3.new(-190, 0, -125), Size = 25, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(20), 0) },
			{ Parent = "Arena", Position = Vector3.new(190, 0, 125), Size = 25, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(200), 0) },
			{ Parent = "Lobby", Position = Vector3.new(0, 44.5, 260), Size = 18, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(180), 0) },
		},
	},
	{
		Key = "MedievalHouse", Id = 4989402992, Title = "Low Poly Medieval House", Credit = "@anomon · Creator Store asset 4989402992 · free with credit", Shadows = true,
		Placements = {
			{ Parent = "Arena", Position = Vector3.new(-140, 0, 130), Size = 18, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(-25), 0) },
			{ Parent = "Arena", Position = Vector3.new(140, 0, -130), Size = 18, Fit = "Height", Rotation = CFrame.Angles(0, math.rad(155), 0) },
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
local CREATOR_STORE_MAX_TOTAL_PARTS = 900

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
	clean:SetAttribute("CreatorStoreCredit", definition.Credit or "Roblox Creator Store")
	clean:SetAttribute("StoreShadows", definition.Shadows == true)
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
				copy.CastShadow = definition.Shadows == true
				clearCreatorStoreGameplayAttributes(copy)
				copy:SetAttribute("HolidayDecor", true)
				copy:SetAttribute("StoreDecor", true)
				copy:SetAttribute("CreatorStoreAssetId", definition.Id)
				copy:SetAttribute("CreatorStoreCredit", definition.Credit or "Roblox Creator Store")
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
	return VisualModels.ChristmasTree(parent, position, scale)
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
	-- Seasonal props stay at the edges; combat lanes keep a clean silhouette.
	buildSnowEmitter(arena, Vector3.new(0, 28, 0), Vector3.new(390, 1, 170), 6)
end

local function buildSculptedTerrain()
	-- Terrain is deliberately outside the 640x360 combat rectangle. It gives
	-- the camera a natural horizon without introducing new navigation obstacles.
	local ok, terrain = pcall(function()
		return Workspace.Terrain
	end)
	if not ok or not terrain then
		return
	end
	pcall(function()
		for _, hill in ipairs({
			{ Position = Vector3.new(-352, -20, -142), Radius = 38 },
			{ Position = Vector3.new(352, -20, 142), Radius = 38 },
			{ Position = Vector3.new(-352, -18, 142), Radius = 34 },
			{ Position = Vector3.new(352, -18, -142), Radius = 34 },
			{ Position = Vector3.new(-160, -22, -202), Radius = 42 },
			{ Position = Vector3.new(160, -22, 202), Radius = 42 },
		}) do
			terrain:FillBall(hill.Position, hill.Radius, Enum.Material.Rock)
			terrain:FillBall(hill.Position + Vector3.new(0, hill.Radius * 0.28, 0), hill.Radius * 0.84, Enum.Material.Snow)
		end
		local clouds = terrain:FindFirstChild("BlockSiegeClouds")
		if not clouds then
			clouds = Instance.new("Clouds")
			clouds.Name = "BlockSiegeClouds"
			clouds.Parent = terrain
		end
		clouds.Cover = 0.38
		clouds.Density = 0.32
		clouds.Color = Color3.fromRGB(224, 238, 249)
	end)
end

local function buildGate(parent, prefix, baseCFrame, width, height, accent)
	return VisualModels.Gate(parent, prefix, baseCFrame, width, height, accent, { Holiday = true })
end

local function buildCitadelTower(parent, prefix, position, accent)
	return VisualModels.Tower(parent, prefix, position, 0.72, accent, { Holiday = true })
end

local function buildBaseArchitecture(arena, team, baseCFrame, accent)
	-- Keep all three original gate coordinates: BaseCFrame faces the enemy,
	-- so using a different world-space offset for Orange would move the gate.
	local facade = baseCFrame * CFrame.new(0, 0, 50)
	local gatePrefixes = { team .. "FrostGate", team .. "RearGate", team .. "InnerGate" }
	buildGate(arena, gatePrefixes[1], facade, 32, 15, accent)
	buildGate(arena, gatePrefixes[2], baseCFrame * CFrame.new(0, 0, -52), 64, 12, STYLE.Navy)
	buildGate(arena, gatePrefixes[3], baseCFrame * CFrame.new(0, 0, -28), 32, 11, accent)
	local function tagBase(root)
		root:SetAttribute("BaseGeometry", true)
		root:SetAttribute("Team", team)
		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant:SetAttribute("BaseGeometry", true)
				descendant:SetAttribute("Team", team)
			end
		end
	end
	for _, prefix in ipairs(gatePrefixes) do
		for _, descendant in ipairs(arena:GetDescendants()) do
			if descendant:IsA("BasePart") and string.sub(descendant.Name, 1, #prefix) == prefix then
				descendant:SetAttribute("BaseGeometry", true)
				descendant:SetAttribute("Team", team)
			end
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local towerPosition = (facade * CFrame.new(side * 22, 0, 0)).Position
		local tower = VisualModels.Tower(arena, "BasePillar" .. team .. tostring(side), towerPosition, 0.78, accent, { Holiday = true })
		tagBase(tower)
		local banner = decorPart(arena, "BaseBanner" .. team, Vector3.new(5.5, 2.8, 0.25), facade * CFrame.new(side * 10, 10, -2), accent, Enum.Material.Fabric)
		banner:SetAttribute("BaseGeometry", true)
		banner:SetAttribute("Team", team)
	end
	for _, side in ipairs({ -1, 1 }) do
		local column = VisualModels.Column(arena, (baseCFrame * CFrame.new(side * 30, 0, -15)).Position, 9, accent, { Holiday = true })
		column.Name = "BasePillar" .. team .. "Courtyard" .. tostring(side)
		tagBase(column)
	end
	local lane = decorPart(arena, team .. "GateLane", Vector3.new(8, 0.12, 68), baseCFrame * CFrame.new(0, 0.55, 3), STYLE.Navy, Enum.Material.Metal)
	lane:SetAttribute("BaseGeometry", true)
	lane:SetAttribute("Team", team)
	for _, side in ipairs({ -1, 1 }) do
		local edge = decorPart(arena, team .. "GateLaneEdge", Vector3.new(0.35, 0.14, 68), baseCFrame * CFrame.new(side * 4.2, 0.62, 3), accent, Enum.Material.Neon)
		edge:SetAttribute("BaseGeometry", true)
		edge:SetAttribute("Team", team)
	end
	local inlay = decorPart(arena, team .. "CourtyardInlay", Vector3.new(70, 0.12, 2), baseCFrame * CFrame.new(0, 0.48, 0), accent, Enum.Material.Metal)
	inlay:SetAttribute("BaseGeometry", true)
	inlay:SetAttribute("Team", team)
end

local function buildLobbyArchitecture(lobby)
	-- A vaulted winter hall: round columns, curved ribs and warm fireplaces,
	-- rather than a corridor made from rectangular roof blocks.
	buildGate(lobby, "LobbyEntry", CFrame.new(0, 44.5, 252), 46, 14, STYLE.Navy)
	for _, x in ipairs({ -82, 82 }) do
		for _, z in ipairs({ 270, 305, 350, 395 }) do
			VisualModels.Column(lobby, Vector3.new(x, 44.5, z), 17, STYLE.Gold, { Holiday = true })
		end
	end
	for _, z in ipairs({ 278, 318, 358, 398 }) do
		buildGate(lobby, "HallVault", CFrame.new(0, 44.5, z), 176, 19, STYLE.Gold)
	end
	VisualModels.Fireplace(lobby, Vector3.new(-65, 44.5, 330), 1.15, { Holiday = true })
	VisualModels.Fireplace(lobby, Vector3.new(65, 44.5, 330), 1.15, { Holiday = true })
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ 300, 340, 380 }) do
			decorPart(lobby, "WindowGlass", Vector3.new(0.5, 10, 18), CFrame.new(side * 101, 51, z), STYLE.Ice, Enum.Material.Glass).Transparency = 0.28
			decorPart(lobby, "WindowTop", Vector3.new(1, 0.7, 19), CFrame.new(side * 101, 56.2, z), STYLE.Navy, Enum.Material.Metal)
			decorPart(lobby, "WindowMullion", Vector3.new(1, 10, 0.6), CFrame.new(side * 101, 51, z), STYLE.Navy, Enum.Material.Metal)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		decorPart(lobby, "HallAxisGold", Vector3.new(0.35, 0.14, 145), CFrame.new(side * 2, 44.6, 330), STYLE.Gold, Enum.Material.Metal)
	end
	for _, entry in ipairs({
		{ Vector3.new(-48, 44.6, 344), STYLE.Blue }, { Vector3.new(48, 44.6, 344), STYLE.Gold },
		{ Vector3.new(-48, 44.6, 300), STYLE.Warm }, { Vector3.new(48, 44.6, 300), Color3.fromRGB(178, 125, 224) },
	}) do
		decorPart(lobby, "ShopRug", Vector3.new(20, 0.12, 16), CFrame.new(entry[1]), entry[2], Enum.Material.Fabric)
	end
	local galleryBackdrop = decorPart(lobby, "GalleryBackdrop", Vector3.new(150, 12, 1.2), CFrame.new(0, 51, 250), STYLE.Navy, Enum.Material.Slate)
	galleryBackdrop.Transparency = 0.12
	decorPart(lobby, "GalleryCrown", Vector3.new(172, 0.55, 1), CFrame.new(0, 56.2, 250), STYLE.Gold, Enum.Material.Metal)
	decorPart(lobby, "HallAxis", Vector3.new(2, 0.12, 145), CFrame.new(0, 44.58, 330), STYLE.Navy, Enum.Material.Metal)
	local signAnchor = decorPart(lobby, "BlockSiegeSign", Vector3.new(1, 1, 1), CFrame.new(0, 65, 330), C.White, Enum.Material.SmoothPlastic)
	signAnchor.Transparency = 1
	billboard(signAnchor, "BLOCKSIEGE  //  6×6", STYLE.Gold, Vector3.zero, UDim2.fromOffset(440, 70))
	for _, z in ipairs({ 280, 320, 360, 400 }) do
		local lamp = decorPart(lobby, "HallLight", Vector3.new(2, 2, 2), CFrame.new(0, 62, z), STYLE.Warm, Enum.Material.Neon)
		lamp.Shape = Enum.PartType.Ball
		holidayGlow(lamp, STYLE.Warm, 14, 0.8)
	end
end

local function buildArenaArchitecture(arena)
	for _, side in ipairs({ -1, 1 }) do
		local canal = decorPart(arena, "FrozenCanal", Vector3.new(420, 0.12, 7), CFrame.new(0, 0.08, side * 84), STYLE.Ice, Enum.Material.Ice)
		canal.Transparency = 0.18
		for _, x in ipairs({ -100, 0, 100 }) do
			VisualModels.Bridge(arena, Vector3.new(x, 0.05, side * 84), 20, 13, STYLE.Gold, { Name = "CanalBridge", Holiday = true })
		end
		for _, x in ipairs({ -72, 72 }) do
			buildGate(arena, "LaneGate", CFrame.new(x, 0, side * 62) * CFrame.Angles(0, math.rad(90), 0), 18, 9, STYLE.Navy)
		end
	end
	for _, z in ipairs({ -11, 11, -69, -55, 55, 69 }) do
		decorPart(arena, "LaneBorder", Vector3.new(300, 0.12, 0.8), CFrame.new(0, 0.38, z), STYLE.Gold, Enum.Material.Metal)
	end
	-- A round inlaid plaza keeps the 67 objective readable from every lane.
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		local tile = decorPart(arena, "CapturePlazaTile", Vector3.new(0.28, 5.5, 2.8), CFrame.new(math.cos(angle) * 19, 0.25, math.sin(angle) * 19) * CFrame.Angles(0, -angle, math.rad(90)), index % 2 == 0 and STYLE.Ivory or STYLE.Navy, Enum.Material.Cobblestone)
		tile.Shape = Enum.PartType.Cylinder
	end
	for _, position in ipairs({
		Vector3.new(-45, 0, -35), Vector3.new(45, 0, 35), Vector3.new(-45, 0, 35), Vector3.new(45, 0, -35),
	}) do
		VisualModels.Rock(arena, position, 1.15, { Snow = true })
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -1, 1 }) do
			buildCitadelTower(arena, "PerimeterTower", Vector3.new(side * 244, 0, forward * 94), STYLE.Navy)
		end
	end
	-- Sculpted outcrops close the horizon without adding invisible maze walls.
	for _, position in ipairs({
		Vector3.new(-285, 0, -128), Vector3.new(285, 0, 128), Vector3.new(-285, 0, 128), Vector3.new(285, 0, -128),
	}) do
		VisualModels.Rock(arena, position, 2.2, { Snow = true })
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
			local groundPosition = (towerCFrame * CFrame.new(0, -5, 0)).Position
			local tower = VisualModels.Tower(arena, team .. "CornerTower", groundPosition, 0.55, color, { Holiday = true })
			tower:SetAttribute("BaseGeometry", true)
			tower:SetAttribute("Team", team)
			for _, descendant in ipairs(tower:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant:SetAttribute("BaseGeometry", true)
					descendant:SetAttribute("Team", team)
				end
			end
			-- Preserve the old navigation/weapon obstacle without rendering a cube.
			local proxy = makePart(arena, team .. "CornerTowerCollision", Vector3.new(8, 10, 8), towerCFrame, C.StoneDark, Enum.Material.Cobblestone, true)
			proxy.Transparency = 1
			proxy.CanQuery = true
			proxy:SetAttribute("BaseGeometry", true)
			proxy:SetAttribute("Team", team)
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
		VisualModels.Bridge(arena, Vector3.new(0, 0.05, lane), 30, 24, STYLE.Gold, { Holiday = true })
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
		local campRock = makePart(campModel, "CampRock", Vector3.new(5, 4, 5), CFrame.new(camp.Position + Vector3.new(10, 2, -7)), C.Stone, Enum.Material.Slate, true)
		campRock.Transparency = 1
		campRock.CanQuery = true
		VisualModels.Rock(campModel, camp.Position + Vector3.new(10, 0, -7), 0.82, { Snow = true })
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
	-- Preserve the gameplay anchors, but render a detailed crystal assembly.
	base.Transparency = 1
	crystal.Transparency = 1
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and (item.Name == "CapturePylon" or item.Name == "CaptureGlow" or item.Name == "CaptureRing") then
			item.Transparency = 1
		end
	end
	VisualModels.Capture(model, crystal.CFrame, Color3.fromRGB(237, 190, 64))
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
	-- The terrain/cloud system and tiled ground materials carry the horizon and
	-- surface detail. Avoid scatter made from tiny cubes across the combat view.
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
		local cover = makePart(arena, "StoneCover", entry[2], CFrame.new(entry[1]), C.Stone, Enum.Material.Cobblestone, true)
		cover.Transparency = 1
		cover.CanQuery = true
	end
	decorateArena(arena)
	buildArenaArchitecture(arena)
	local neutralCamps = buildDotaFrontier(arena)

	local capturePoint = buildCapturePoint(arena)
	local lobbySpawn, lootPrompt, startPrompt, upgradePrompt, dailyPrompt, shopPrompt, defensePrompt = buildLobby(lobby)
	buildSculptedTerrain()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.Brightness = 2.5
	Lighting.ClockTime = 15.4
	Lighting.EnvironmentDiffuseScale = 0.58
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(184, 191, 177)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 238, 211)
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
	atmosphere.Density = 0.09
	atmosphere.Haze = 0.08
	atmosphere.Color = Color3.fromRGB(218, 226, 213)
	atmosphere.Decay = Color3.fromRGB(145, 151, 135)
	atmosphere.Glare = 0.04
	local colorCorrection = ensureEffect("ColorCorrectionEffect", "BlockSiegeColor")
	colorCorrection.Saturation = 0.16
	colorCorrection.Contrast = 0.07
	local bloom = ensureEffect("BloomEffect", "BlockSiegeBloom")
	bloom.Intensity = 0.24
	bloom.Size = 22
	bloom.Threshold = 1
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
