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
	Grass = Color3.fromRGB(91, 145, 73),
	Dirt = Color3.fromRGB(114, 79, 48),
	Stone = Color3.fromRGB(107, 118, 112),
	StoneDark = Color3.fromRGB(63, 73, 70),
	Wood = Color3.fromRGB(159, 111, 57),
	Leaf = Color3.fromRGB(63, 119, 61),
	Sand = Color3.fromRGB(190, 170, 111),
	White = Color3.fromRGB(239, 240, 215),
	Gold = Color3.fromRGB(239, 179, 52),
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
	label.Font = Enum.Font.Code
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

local function decorPart(parent, name, size, cframe, color, material)
	local part = makePart(parent, name, size, cframe, color, material, false)
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
	{
		Key = "LoungeFurniture", Id = 10847897579, Title = "House Furniture Pack - Duvall Drive", MaxParts = 90,
		Selection = { "sofa", "couch", "chair", "table", "lamp", "rug" },
		Placements = {
			{ Parent = "Lobby", Position = Vector3.new(-94, 44.5, 340), Size = 18, Fit = "Max" },
			{ Parent = "Lobby", Position = Vector3.new(94, 44.5, 340), Size = 18, Fit = "Max", Rotation = CFrame.Angles(0, math.rad(180), 0) },
		},
	},
	{
		Key = "LoungeProps", Id = 10840642581, Title = "House Props Pack - Duvall Drive", MaxParts = 90,
		Selection = { "statue", "globe", "candelabra", "radio", "book", "frame", "vase" },
		Placements = {
			{ Parent = "Lobby", Position = Vector3.new(-94, 44.5, 390), Size = 16, Fit = "Max" },
			{ Parent = "Lobby", Position = Vector3.new(94, 44.5, 390), Size = 16, Fit = "Max", Rotation = CFrame.Angles(0, math.rad(180), 0) },
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
local CREATOR_STORE_MAX_TOTAL_PARTS = 700

local function clearCreatorStoreGameplayAttributes(instance)
	-- Roblox attributes are arbitrary gameplay input too. Clear the complete
	-- dictionary when available; the small native mock falls back to known keys.
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
	local maxSourceParts = definition.MaxParts or CREATOR_STORE_MAX_SOURCE_PARTS
	-- Large official packs are never copied wholesale. Pick one named, bounded
	-- furniture/prop submodel so a pack cannot bring hundreds of meshes or scripts.
	if definition.Selection then
		local bestModel
		local bestScore = 0
		for _, candidate in ipairs(source:GetDescendants()) do
			if candidate:IsA("Model") then
				local candidateParts = 0
				for _, item in ipairs(candidate:GetDescendants()) do
					if item:IsA("BasePart") and not CREATOR_STORE_SKIP_PARTS[item.ClassName] then
						candidateParts = candidateParts + 1
					end
				end
				if candidateParts > 0 and candidateParts <= maxSourceParts then
					local lowerName = string.lower(candidate.Name)
					for rank, keyword in ipairs(definition.Selection) do
						if string.find(lowerName, keyword, 1, true) then
							local score = (#definition.Selection - rank + 1) * 1000 + candidateParts
							if score > bestScore then
								bestModel = candidate
								bestScore = score
							end
							break
						end
					end
				end
			end
		end
		if not bestModel then
			return nil, "no curated submodel within the geometry budget"
		end
		source = bestModel
	end
	local sourcePartCount = 0
	for _, descendant in ipairs(source:GetDescendants()) do
		if descendant:IsA("BasePart") and not CREATOR_STORE_SKIP_PARTS[descendant.ClassName] then
			sourcePartCount = sourcePartCount + 1
		end
	end
	if sourcePartCount == 0 or sourcePartCount > maxSourceParts then
		return nil, "empty or over the geometry budget"
	end

	local clean = Instance.new("Model")
	clean.Name = "Store_" .. definition.Key
	clearCreatorStoreGameplayAttributes(clean)
	clean:SetAttribute("HolidayDecor", true)
	clean:SetAttribute("StoreDecor", true)
	clean:SetAttribute("CreatorStoreAssetId", definition.Id)
	clean:SetAttribute("StoreSelection", source.Name)
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

local function buildBaseCrown(arena, team, baseCFrame, color, dark)
	local function crownPart(name, size, cframe, partColor, material)
		return decorPart(arena, team .. name, size, cframe, partColor, material)
	end
	-- Wide silhouettes make each fortress read as a citadel from the lobby and
	-- the outer ring. They are visual only; the original combat cover remains.
	crownPart("CitadelBackWall", Vector3.new(112, 14, 2), baseCFrame * CFrame.new(0, 7, -58), dark, Enum.Material.Cobblestone)
	crownPart("CitadelBackSnow", Vector3.new(114, 0.55, 2.8), baseCFrame * CFrame.new(0, 14.25, -58), HOLIDAY.Snow, Enum.Material.Snow)
	crownPart("CitadelBackTrim", Vector3.new(108, 0.55, 2.5), baseCFrame * CFrame.new(0, 3.2, -56.8), HOLIDAY.Gold, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		crownPart("CitadelSideWall", Vector3.new(2, 12, 104), baseCFrame * CFrame.new(side * 56, 6, -4), dark, Enum.Material.Cobblestone)
		crownPart("CitadelSideSnow", Vector3.new(2.6, 0.5, 104), baseCFrame * CFrame.new(side * 56, 12.25, -4), HOLIDAY.Snow, Enum.Material.Snow)
		crownPart("CitadelTower", Vector3.new(12, 22, 12), baseCFrame * CFrame.new(side * 56, 11, -58), dark, Enum.Material.Cobblestone)
		crownPart("CitadelTowerSnow", Vector3.new(13, 0.65, 13), baseCFrame * CFrame.new(side * 56, 22.35, -58), HOLIDAY.Snow, Enum.Material.Snow)
		crownPart("CitadelTowerBand", Vector3.new(12.7, 1, 12.7), baseCFrame * CFrame.new(side * 56, 16, -58), color, Enum.Material.Fabric)
		for index = 0, 3 do
			local angle = math.rad(index * 90)
			crownPart("CitadelBattlement", Vector3.new(3, 2.2, 3), baseCFrame * CFrame.new(side * 56 + math.cos(angle) * 4.2, 23.5, -58 + math.sin(angle) * 4.2), dark, Enum.Material.Cobblestone)
		end
		crownPart("CitadelBanner", Vector3.new(11, 7, 0.35), baseCFrame * CFrame.new(side * 27, 10, -56.7), color, Enum.Material.Fabric)
		crownPart("CitadelBannerStripe", Vector3.new(1.1, 7.2, 0.42), baseCFrame * CFrame.new(side * 27, 10, -56.45), HOLIDAY.Gold, Enum.Material.Metal)
		local lamp = crownPart("CitadelLamp", Vector3.new(1.4, 2.4, 1.4), baseCFrame * CFrame.new(side * 45, 5, 34), HOLIDAY.Warm, Enum.Material.Neon)
		holidayGlow(lamp, HOLIDAY.Warm, 12, 1.1)
	end
end

local function buildBase(arena, structures, team)
	local color = Config.Teams[team].Color
	local base = Config.BasePosition(team)
	local baseCFrame = Config.BaseCFrame(team)
	local presentation = Config.Presentation
	local platform = makePart(arena, team .. "BasePlatform", Vector3.new(presentation.BaseWidth, 4, presentation.BaseDepth), CFrame.new(base.X, 2, 0), C.Stone, Enum.Material.Cobblestone, true)
	platform:SetAttribute("Team", team)
	makePart(arena, team .. "BaseGrass", Vector3.new(presentation.BaseWidth - 6, 0.5, presentation.BaseDepth - 6), CFrame.new(base.X, 4.15, 0), C.Grass, Enum.Material.Grass, true)
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
	buildBaseCrown(arena, team, baseCFrame, color, C.StoneDark)
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

local function buildLantern(parent, position, scale, color)
	local model = Instance.new("Model")
	model.Name = "CitadelLantern"
	model.Parent = parent
	decorPart(model, "LanternFoot", Vector3.new(2.2 * scale, 0.5 * scale, 2.2 * scale), CFrame.new(position + Vector3.new(0, 0.25 * scale, 0)), C.StoneDark, Enum.Material.Cobblestone)
	decorPart(model, "LanternPole", Vector3.new(0.45 * scale, 5.5 * scale, 0.45 * scale), CFrame.new(position + Vector3.new(0, 3 * scale, 0)), C.Wood, Enum.Material.WoodPlanks)
	decorPart(model, "LanternCap", Vector3.new(2.2 * scale, 0.45 * scale, 2.2 * scale), CFrame.new(position + Vector3.new(0, 6.1 * scale, 0)), C.StoneDark, Enum.Material.Metal)
	local glow = decorPart(model, "LanternGlow", Vector3.new(1.25 * scale, 1.6 * scale, 1.25 * scale), CFrame.new(position + Vector3.new(0, 5.1 * scale, 0)), color or HOLIDAY.Warm, Enum.Material.Neon)
	if scale >= 1 then holidayGlow(glow, color or HOLIDAY.Warm, 11 * scale, 0.85) end
	return model
end

local function buildIceCluster(parent, position, scale, color)
	local model = Instance.new("Model")
	model.Name = "FrostGarden"
	model.Parent = parent
	decorPart(model, "IceSnowBed", Vector3.new(12 * scale, 0.35 * scale, 10 * scale), CFrame.new(position + Vector3.new(0, 0.2 * scale, 0)), HOLIDAY.Snow, Enum.Material.Snow)
	for index = 1, 5 do
		local angle = math.rad(index * 72)
		local height = (4.5 + (index % 3) * 1.8) * scale
		local offset = 3.2 * scale
		local shard = decorPart(model, "IceShard", Vector3.new(1.8 * scale, height, 1.8 * scale), CFrame.new(position + Vector3.new(math.cos(angle) * offset, height / 2, math.sin(angle) * offset)) * CFrame.Angles(0, angle, math.rad((index % 2 == 0 and 1 or -1) * 8)), color or Color3.fromRGB(122, 220, 255), Enum.Material.Ice)
		shard.Transparency = 0.12
	end
	return model
end

local function buildWatchtower(parent, position, scale, color)
	local model = Instance.new("Model")
	model.Name = "CitadelWatchtower"
	model.Parent = parent
	decorPart(model, "WatchtowerBody", Vector3.new(10 * scale, 18 * scale, 10 * scale), CFrame.new(position + Vector3.new(0, 9 * scale, 0)), C.StoneDark, Enum.Material.Cobblestone)
	decorPart(model, "WatchtowerBand", Vector3.new(10.5 * scale, 1.1 * scale, 10.5 * scale), CFrame.new(position + Vector3.new(0, 13 * scale, 0)), color, Enum.Material.Fabric)
	decorPart(model, "WatchtowerSnow", Vector3.new(11.5 * scale, 0.65 * scale, 11.5 * scale), CFrame.new(position + Vector3.new(0, 18.35 * scale, 0)), HOLIDAY.Snow, Enum.Material.Snow)
	for index = 0, 3 do
		local angle = math.rad(index * 90)
		decorPart(model, "WatchtowerBattlement", Vector3.new(2.4 * scale, 2 * scale, 2.4 * scale), CFrame.new(position + Vector3.new(math.cos(angle) * 3.8 * scale, 19.5 * scale, math.sin(angle) * 3.8 * scale)), C.StoneDark, Enum.Material.Cobblestone)
	end
	decorPart(model, "WatchtowerPole", Vector3.new(0.35 * scale, 8 * scale, 0.35 * scale), CFrame.new(position + Vector3.new(0, 23 * scale, 0)), C.Wood, Enum.Material.WoodPlanks)
	decorPart(model, "WatchtowerFlag", Vector3.new(4.5 * scale, 2.8 * scale, 0.3 * scale), CFrame.new(position + Vector3.new(2.2 * scale, 25 * scale, 0)), color, Enum.Material.Fabric)
	local lamp = decorPart(model, "WatchtowerLamp", Vector3.new(1.2 * scale, 1.5 * scale, 1.2 * scale), CFrame.new(position + Vector3.new(0, 15 * scale, 5.2 * scale)), HOLIDAY.Warm, Enum.Material.Neon)
	holidayGlow(lamp, HOLIDAY.Warm, 10 * scale, 0.7)
	return model
end

local function buildMarketStall(parent, position, scale, color)
	local model = Instance.new("Model")
	model.Name = "WinterMarketStall"
	model.Parent = parent
	decorPart(model, "MarketCounter", Vector3.new(14 * scale, 2.2 * scale, 5 * scale), CFrame.new(position + Vector3.new(0, 1.4 * scale, 0)), C.Wood, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		decorPart(model, "MarketPost", Vector3.new(0.8 * scale, 8 * scale, 0.8 * scale), CFrame.new(position + Vector3.new(side * 5.7 * scale, 4 * scale, 0)), C.Wood, Enum.Material.WoodPlanks)
	end
	decorPart(model, "MarketRoof", Vector3.new(15 * scale, 0.7 * scale, 7 * scale), CFrame.new(position + Vector3.new(0, 8 * scale, 0)), color, Enum.Material.Fabric)
	for index = 0, 4 do
		decorPart(model, "MarketAwning", Vector3.new(2.8 * scale, 0.35 * scale, 7.2 * scale), CFrame.new(position + Vector3.new((index - 2) * 2.8 * scale, 7.55 * scale, 0)), index % 2 == 0 and HOLIDAY.Snow or color, Enum.Material.Fabric)
	end
	for _, side in ipairs({ -1, 1 }) do
		decorPart(model, "MarketCrate", Vector3.new(2.4 * scale, 2.4 * scale, 2.4 * scale), CFrame.new(position + Vector3.new(side * 4 * scale, 3.5 * scale, -0.3 * scale)), C.Gold, Enum.Material.WoodPlanks)
	end
	local sign = decorPart(model, "MarketSign", Vector3.new(7 * scale, 2 * scale, 0.35 * scale), CFrame.new(position + Vector3.new(0, 6.2 * scale, 3.6 * scale)), C.StoneDark, Enum.Material.WoodPlanks)
	billboard(sign, "WINTER MARKET", HOLIDAY.Gold, Vector3.new(0, 0, 0), UDim2.fromScale(1, 1))
	return model
end

local function buildFireBowl(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "LobbyFireBowl"
	model.Parent = parent
	decorPart(model, "FireBowlBase", Vector3.new(5 * scale, 1.2 * scale, 5 * scale), CFrame.new(position + Vector3.new(0, 0.6 * scale, 0)), C.StoneDark, Enum.Material.Cobblestone)
	decorPart(model, "FireBowlRim", Vector3.new(5.5 * scale, 0.45 * scale, 5.5 * scale), CFrame.new(position + Vector3.new(0, 1.25 * scale, 0)), HOLIDAY.Gold, Enum.Material.Metal)
	local flame = decorPart(model, "FireBowlFlame", Vector3.new(2.2 * scale, 3.2 * scale, 2.2 * scale), CFrame.new(position + Vector3.new(0, 3 * scale, 0)), Color3.fromRGB(255, 133, 71), Enum.Material.Neon)
	holidayGlow(flame, Color3.fromRGB(255, 133, 71), 15 * scale, 1.2)
	return model
end

local function buildLobbyExpansion(lobby)
	local signAnchor = decorPart(lobby, "GrandLobbySignAnchor", Vector3.new(1, 1, 1), CFrame.new(0, 69, 330), C.White, Enum.Material.SmoothPlastic)
	signAnchor.Transparency = 1
	billboard(signAnchor, "WINTER CITADEL  //  BLOCK SIEGE", HOLIDAY.Gold, Vector3.zero, UDim2.fromOffset(620, 90))
	decorPart(lobby, "GrandLobbySignFrame", Vector3.new(58, 8, 1), CFrame.new(0, 68, 329), C.StoneDark, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ 258, 302, 346, 390, 410 }) do
			decorPart(lobby, "GrandPergolaColumn", Vector3.new(2.4, 22, 2.4), CFrame.new(side * 103, 55, z), C.StoneDark, Enum.Material.Cobblestone)
			decorPart(lobby, "GrandPergolaSnow", Vector3.new(3.2, 0.5, 3.2), CFrame.new(side * 103, 66.2, z), HOLIDAY.Snow, Enum.Material.Snow)
		end
		decorPart(lobby, "GrandPergolaBeam", Vector3.new(2.8, 2, 156), CFrame.new(side * 103, 67, 334), C.Wood, Enum.Material.WoodPlanks)
		decorPart(lobby, "GrandLoungeRug", Vector3.new(28, 0.16, 24), CFrame.new(side * 94, 44.65, 360), Color3.fromRGB(48, 74, 105), Enum.Material.Fabric)
		buildMarketStall(lobby, Vector3.new(side * 91, 44.5, 282), 0.85, side < 0 and HOLIDAY.Blue or HOLIDAY.Red)
		buildFireBowl(lobby, Vector3.new(side * 82, 44.5, 410), 0.9)
		buildIceCluster(lobby, Vector3.new(side * 101, 44.5, 250), 0.7, HOLIDAY.Blue)
		for _, z in ipairs({ 306, 336, 366, 396 }) do
			buildLantern(lobby, Vector3.new(side * 101, 44.5, z), 1, HOLIDAY.Warm)
		end
	end
	buildGarland(lobby, Vector3.new(-101, 66, 258), Vector3.new(101, 66, 258), 1.5, 14)
	buildGarland(lobby, Vector3.new(-101, 66, 410), Vector3.new(101, 66, 410), 1.5, 14)
end

local function buildLobby(lobby)
	local presentation = Config.Presentation
	local lobbyWidth = presentation.LobbyWidth
	local lobbyDepth = presentation.LobbyDepth
	makePart(lobby, "LobbyStone", Vector3.new(lobbyWidth, 8, lobbyDepth), CFrame.new(0, 36, 330), C.StoneDark, Enum.Material.Cobblestone, true)
	makePart(lobby, "LobbyDirt", Vector3.new(lobbyWidth - 4, 5, lobbyDepth - 4), CFrame.new(0, 41, 330), C.Dirt, Enum.Material.Ground, true)
	makePart(lobby, "LobbyGrass", Vector3.new(lobbyWidth - 6, 1, lobbyDepth - 6), CFrame.new(0, 44, 330), C.Grass, Enum.Material.Grass, true)
	local spawnCFrame = CFrame.lookAt(Vector3.new(0, 48, 365), Vector3.new(0, 48, 330))
	local spawn = makePart(lobby, "LobbySpawn", Vector3.new(12, 1, 12), spawnCFrame, C.White, Enum.Material.Neon, false, "SpawnLocation")
	spawn.Neutral = true
	spawn.CanQuery = false

	-- Continuous glass safety walls scale with the larger lobby: no new fall gaps.
	local halfWidth = lobbyWidth / 2
	local halfDepth = lobbyDepth / 2
	for _, side in ipairs({ -1, 1 }) do
		makePart(lobby, "LobbySafetyWall", Vector3.new(1.5, 18, lobbyDepth - 4), CFrame.new(side * (halfWidth - 3), 53, 330), Color3.fromRGB(110, 170, 175), Enum.Material.Glass, true).Transparency = 0.72
		makePart(lobby, "LobbyFenceRail", Vector3.new(1.2, 1, lobbyDepth - 4), CFrame.new(side * (halfWidth - 3.5), 48, 330), C.Gold, Enum.Material.Metal, true)
		local sidePostCount = math.floor((lobbyDepth - 8) / 15.5)
		for index = 0, sidePostCount do
			local z = 330 - (lobbyDepth - 8) / 2 + index * 15.5
			makePart(lobby, "LobbyFencePost", Vector3.new(2, 7, 2), CFrame.new(side * (halfWidth - 3.5), 47.5, z), C.StoneDark, Enum.Material.Cobblestone, true)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		makePart(lobby, "LobbySafetyWall", Vector3.new(lobbyWidth - 4, 18, 1.5), CFrame.new(0, 53, 330 + side * (halfDepth - 2)), Color3.fromRGB(110, 170, 175), Enum.Material.Glass, true).Transparency = 0.72
		makePart(lobby, "LobbyFenceRail", Vector3.new(lobbyWidth - 4, 1, 1.2), CFrame.new(0, 48, 330 + side * (halfDepth - 2.5)), C.Gold, Enum.Material.Metal, true)
		local frontPostCount = math.floor((lobbyWidth - 8) / 15.5)
		for index = 0, frontPostCount do
			local x = -(lobbyWidth - 8) / 2 + index * 15.5
			makePart(lobby, "LobbyFencePost", Vector3.new(2, 7, 2), CFrame.new(x, 47.5, 330 + side * (halfDepth - 2.5)), C.StoneDark, Enum.Material.Cobblestone, true)
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
		local frameColor = Catalog.RarityColors[definition.Rarity]
		decorPart(lobby, "WeaponGalleryFrame", Vector3.new(11, 9, 0.6), CFrame.new(x, 50, z - 4.8), C.StoneDark, Enum.Material.Fabric)
		decorPart(lobby, "WeaponGalleryTrim", Vector3.new(11.4, 0.45, 0.75), CFrame.new(x, 54.5, z - 4.7), frameColor, Enum.Material.Neon)
		decorPart(lobby, "WeaponGalleryFoot", Vector3.new(10.5, 0.3, 0.8), CFrame.new(x, 45.2, z - 4.7), frameColor, Enum.Material.Neon)
		billboard(labelAnchor, definition.Name, frameColor, Vector3.zero)
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
	buildLobbyExpansion(lobby)
	return spawnCFrame, lootPrompt, startPrompt, upgradePrompt, dailyPrompt, shopPrompt, defensePrompt
end

local function buildArenaExpansion(arena)
	local presentation = Config.Presentation
	-- A broad, readable outer ring gives the place a much larger silhouette while
	-- leaving the original lanes, spawn positions and capture radius untouched.
	for _, side in ipairs({ -1, 1 }) do
		decorPart(arena, "OuterSnowLane", Vector3.new(presentation.ArenaWidth - 42, 0.18, 8), CFrame.new(0, 0.22, side * 105), HOLIDAY.Snow, Enum.Material.Snow)
		decorPart(arena, "OuterLaneInlay", Vector3.new(presentation.ArenaWidth - 56, 0.12, 1.2), CFrame.new(0, 0.34, side * 105), HOLIDAY.Gold, Enum.Material.Metal)
		buildGarland(arena, Vector3.new(-250, 14, side * 114), Vector3.new(250, 14, side * 114), 2.5, 12)
		-- Small ruined gateways are landmarks, not new collision obstacles.
		for _, x in ipairs({ -18, 18 }) do
			decorPart(arena, "FrostGatePillar", Vector3.new(4, 14, 4), CFrame.new(x, 7, side * 112), C.StoneDark, Enum.Material.Cobblestone)
			decorPart(arena, "FrostGateSnow", Vector3.new(4.8, 0.5, 4.8), CFrame.new(x, 14.25, side * 112), HOLIDAY.Snow, Enum.Material.Snow)
		end
		decorPart(arena, "FrostGateBeam", Vector3.new(40, 3, 4), CFrame.new(0, 14, side * 112), C.StoneDark, Enum.Material.Cobblestone)
		decorPart(arena, "FrostGateBeamSnow", Vector3.new(41, 0.5, 4.8), CFrame.new(0, 15.75, side * 112), HOLIDAY.Snow, Enum.Material.Snow)
	end
	for _, side in ipairs({ -1, 1 }) do
		decorPart(arena, "OuterSnowLane", Vector3.new(8, 0.18, 196), CFrame.new(side * 240, 0.22, 0), HOLIDAY.Snow, Enum.Material.Snow)
		for _, z in ipairs({ -94, 0, 94 }) do
			buildWatchtower(arena, Vector3.new(side * 246, 0, z), z == 0 and 1.25 or 1.05, side < 0 and HOLIDAY.Blue or HOLIDAY.Red)
		end
		for _, z in ipairs({ -42, 42 }) do
			buildChristmasTree(arena, Vector3.new(side * 218, 0, z), 0.8)
		end
		for _, z in ipairs({ -72, 72 }) do
			buildIceCluster(arena, Vector3.new(side * 204, 0, z), 1.1, side < 0 and HOLIDAY.Blue or HOLIDAY.Red)
		end
		for _, z in ipairs({ -72, -24, 24, 72 }) do
			buildLantern(arena, Vector3.new(side * 228, 0, z), 0.85, HOLIDAY.Warm)
		end
	end
	for _, z in ipairs({ -108, 108 }) do
		buildIceCluster(arena, Vector3.new(0, 0, z), 0.85, HOLIDAY.Blue)
	end
	for _, z in ipairs({ -105, 105 }) do
		for _, x in ipairs({ -180, -60, 60, 180 }) do
			buildLantern(arena, Vector3.new(x, 0, z), 0.85, HOLIDAY.Warm)
		end
	end
	for index = 1, 36 do
		local x = -250 + ((index * 67) % 500)
		local z = (index % 2 == 0 and -1 or 1) * (96 + ((index * 13) % 17))
		decorPart(arena, "OuterWinterGrass", Vector3.new(0.35, 1.1 + (index % 3) * 0.25, 0.35), CFrame.new(x, 0.6, z) * CFrame.Angles(0, math.rad(index * 31), 0), index % 3 == 0 and HOLIDAY.Blue or C.Grass, Enum.Material.Grass)
	end
	for _, position in ipairs({
		Vector3.new(-182, 0.1, -104), Vector3.new(182, 0.1, -104),
		Vector3.new(-182, 0.1, 104), Vector3.new(182, 0.1, 104),
		Vector3.new(-238, 0.1, -28), Vector3.new(238, 0.1, 28),
	}) do
		decorPart(arena, "OuterSnowPatch", Vector3.new(26, 0.25, 15), CFrame.new(position), HOLIDAY.Snow, Enum.Material.Snow)
	end
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
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		decorPart(model, "CaptureRune", Vector3.new(2.2, 0.16, 2.2), CFrame.new(math.cos(angle) * 17, 0.95, math.sin(angle) * 17) * CFrame.Angles(0, angle, 0), HOLIDAY.Gold, Enum.Material.Neon)
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, forward in ipairs({ -1, 1 }) do
			local shard = decorPart(model, "CaptureOuterCrystal", Vector3.new(1.8, 4.5, 1.8), CFrame.new(side * 17, 2.25, forward * 17) * CFrame.Angles(0, math.rad(45), math.rad(side * 8)), Color3.fromRGB(255, 211, 78), Enum.Material.Ice)
			shard.Transparency = 0.15
		end
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
	gui.Size = UDim2.fromOffset(300, 160)
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
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = root

	local presentation = Config.Presentation
	makePart(arena, "ArenaDirt", Vector3.new(presentation.ArenaWidth, 8, presentation.ArenaDepth), CFrame.new(0, -6, 0), C.Dirt, Enum.Material.Ground, true)
	makePart(arena, "ArenaGrass", Vector3.new(presentation.ArenaWidth, 2, presentation.ArenaDepth), CFrame.new(0, -1, 0), C.Grass, Enum.Material.Grass, true)
	makePart(arena, "CenterLane", Vector3.new(210, 0.35, 18), CFrame.new(0, 0.15, 0), C.Sand, Enum.Material.Ground, true)
	for _, z in ipairs({ -62, 62 }) do
		makePart(arena, "SideLane", Vector3.new(230, 0.3, 10), CFrame.new(0, 0.12, z), C.Sand, Enum.Material.Ground, true)
	end
	for index = 0, 27 do
		local x = -270 + index * 20
		local height = 8 + (index * 5 % 7)
		for _, side in ipairs({ -1, 1 }) do
			makePart(arena, "CliffDirt", Vector3.new(20, height, 6), CFrame.new(x, -10 - height / 2, side * (presentation.ArenaEdgeZ)), C.Dirt, Enum.Material.Ground, true)
			makePart(arena, "CliffStone", Vector3.new(18, 3, 6.5), CFrame.new(x, -12, side * (presentation.ArenaEdgeZ)), C.StoneDark, Enum.Material.Slate, true)
		end
	end
	-- Visible perimeter walls keep the enlarged place enclosed without becoming
	-- bot navigation targets or changing the tactical geodata footprint.
	for _, side in ipairs({ -1, 1 }) do
		local zWall = makePart(arena, "ArenaBoundary", Vector3.new(presentation.ArenaWidth, 24, 2), CFrame.new(0, 10, side * (presentation.ArenaEdgeZ)), C.StoneDark, Enum.Material.Slate, true)
		zWall.CanQuery = false
		decorPart(arena, "ArenaBoundarySnow", Vector3.new(presentation.ArenaWidth, 0.5, 2.5), CFrame.new(0, 22.25, side * (presentation.ArenaEdgeZ)), HOLIDAY.Snow, Enum.Material.Snow)
		local xWall = makePart(arena, "ArenaBoundary", Vector3.new(2, 24, presentation.ArenaDepth), CFrame.new(side * (presentation.ArenaEdgeX), 10, 0), C.StoneDark, Enum.Material.Slate, true)
		xWall.CanQuery = false
		decorPart(arena, "ArenaBoundarySnow", Vector3.new(2.5, 0.5, presentation.ArenaDepth), CFrame.new(side * (presentation.ArenaEdgeX), 22.25, 0), HOLIDAY.Snow, Enum.Material.Snow)
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
	buildArenaExpansion(arena)

	local capturePoint = buildCapturePoint(arena)
	local lobbySpawn, lootPrompt, startPrompt, upgradePrompt, dailyPrompt, shopPrompt, defensePrompt = buildLobby(lobby)
	Lighting.Brightness = 2
	Lighting.ClockTime = 14.5
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(137, 151, 146)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 244, 215)
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
	atmosphere.Density = 0.28
	atmosphere.Haze = 0.7
	local colorCorrection = ensureEffect("ColorCorrectionEffect", "BlockSiegeColor")
	colorCorrection.Saturation = 0.12
	colorCorrection.Contrast = 0.04
	local bloom = ensureEffect("BloomEffect", "BlockSiegeBloom")
	bloom.Intensity = 0.22
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
