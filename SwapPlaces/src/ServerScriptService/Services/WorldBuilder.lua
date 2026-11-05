-- Original procedural social plaza for «Поменяйся местами».
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("SwapPlaces")
local Config = require(Shared:WaitForChild("Config"))
local SkinCatalog = require(Shared:WaitForChild("SkinCatalog"))

local WorldBuilder = {}
local INK = Color3.fromRGB(30, 36, 64)
local WHITE = Color3.fromRGB(244, 247, 255)
local PINK = Color3.fromRGB(245, 105, 173)
local CYAN = Color3.fromRGB(78, 211, 231)

local function part(parent, name, size, cframe, color, material, collide, className)
	local object = Instance.new(className or "Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.CanCollide = collide ~= false
	object.CanTouch = false
	object.CanQuery = collide == true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end

local function label(parent, text, color, offset, width)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.Size = UDim2.fromOffset(width or 340, 76)
	gui.StudsOffset = offset or Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 190
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Text = text
	textLabel.TextColor3 = color or WHITE
	textLabel.TextStrokeColor3 = INK
	textLabel.TextStrokeTransparency = 0.25
	textLabel.TextScaled = true
	textLabel.Parent = gui
	return gui
end

local function prompt(parent, action, objectText)
	local object = Instance.new("ProximityPrompt")
	object.ActionText = action
	object.ObjectText = objectText
	object.HoldDuration = 0.2
	object.MaxActivationDistance = 12
	object.RequiresLineOfSight = false
	object.Parent = parent
	return object
end

local function palm(parent, position, scale)
	local model = Instance.new("Model")
	model.Name = "PlazaPalm"
	model.Parent = parent
	for index = 0, 5 do
		part(model, "Trunk", Vector3.new(0.8 * scale, 2.4 * scale, 0.8 * scale), CFrame.new(position + Vector3.new(math.sin(index * 0.4) * scale, (index + 0.5) * 2.1 * scale, 0)), Color3.fromRGB(150, 102, 69), Enum.Material.Wood, index < 3)
	end
	local top = position + Vector3.new(0, 13.2 * scale, 0)
	part(model, "Crown", Vector3.one * 1.5 * scale, CFrame.new(top), Color3.fromRGB(69, 165, 91), Enum.Material.Grass, false).Shape = Enum.PartType.Ball
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local offset = Vector3.new(math.cos(angle) * 3.2 * scale, -0.3 * scale, math.sin(angle) * 3.2 * scale)
		part(model, "Leaf", Vector3.new(5.8 * scale, 0.28 * scale, 1.25 * scale), CFrame.new(top + offset) * CFrame.Angles(0, -angle, math.rad(index % 2 == 0 and 8 or -8)), index % 2 == 0 and Color3.fromRGB(79, 190, 105) or Color3.fromRGB(50, 148, 92), Enum.Material.Grass, false, "WedgePart")
	end
	return model
end

local function mannequin(parent, skin, position)
	local model = Instance.new("Model")
	model.Name = "Skin_" .. skin.Id
	model.Parent = parent
	local pedestal = part(model, "Pedestal", Vector3.new(8, 1, 8), CFrame.new(position + Vector3.new(0, 0.5, 0)), INK, Enum.Material.Metal, true)
	part(model, "PedestalGlow", Vector3.new(7.2, 0.18, 7.2), CFrame.new(position + Vector3.new(0, 1.08, 0)), skin.Accent, Enum.Material.Neon, false)
	local base = position + Vector3.new(0, 1.1, 0)
	part(model, "Torso", Vector3.new(2, 2, 1), CFrame.new(base + Vector3.new(0, 3.5, 0)), skin.Secondary, Enum.Material.Fabric, false)
	part(model, "Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(base + Vector3.new(0, 5.4, 0)), skin.Primary, Enum.Material.SmoothPlastic, false).Shape = Enum.PartType.Ball
	for side = -1, 1, 2 do
		part(model, "Arm", Vector3.new(0.65, 2.2, 0.65), CFrame.new(base + Vector3.new(side * 1.4, 3.5, 0)), skin.Primary, Enum.Material.Fabric, false)
		part(model, "Leg", Vector3.new(0.78, 2.1, 0.78), CFrame.new(base + Vector3.new(side * 0.55, 1.45, 0)), skin.Secondary, Enum.Material.Fabric, false)
	end
	if skin.Accessory == "Halo" or skin.Accessory == "Crown" then
		for index = 0, 5 do
			local angle = index * math.pi / 3
			part(model, "HeadAccessory", Vector3.one * 0.35, CFrame.new(base + Vector3.new(math.cos(angle), 6.45 + (skin.Accessory == "Crown" and math.sin(angle) * 0.4 or 0), math.sin(angle))), skin.Accent, Enum.Material.Neon, false).Shape = Enum.PartType.Ball
		end
	elseif skin.Accessory == "Wings" then
		for side = -1, 1, 2 do part(model, "Wing", Vector3.new(1.5, 2.5, 0.25), CFrame.new(base + Vector3.new(side * 1.6, 3.8, 0.75)) * CFrame.Angles(0, math.rad(side * 25), math.rad(side * -20)), skin.Accent, Enum.Material.Fabric, false, "WedgePart") end
	elseif skin.Accessory == "Pack" or skin.Accessory == "Cape" then
		part(model, "BackAccessory", Vector3.new(1.8, 2.4, 0.65), CFrame.new(base + Vector3.new(0, 3.3, 0.85)), skin.Accent, Enum.Material.Fabric, false)
	elseif skin.Accessory == "Visor" then
		part(model, "Visor", Vector3.new(1.2, 0.3, 0.18), CFrame.new(base + Vector3.new(0, 5.5, -0.72)), skin.Accent, Enum.Material.Neon, false)
	elseif skin.Accessory == "Orbit" then
		for index = 0, 5 do
			local angle = index * math.pi / 3
			part(model, "Orbit", Vector3.one * 0.35, CFrame.new(base + Vector3.new(math.cos(angle) * 1.8, 3.7 + math.sin(angle * 2) * 0.5, math.sin(angle) * 1.8)), skin.Accent, Enum.Material.Neon, false).Shape = Enum.PartType.Ball
		end
	end
	label(pedestal, skin.Name .. "\n" .. skin.Description, skin.Accent, Vector3.new(0, 8.5, 0), 260)
	return pedestal
end

function WorldBuilder.Build()
	local old = Workspace:FindFirstChild("SwapPlacesWorld")
	if old then old:Destroy() end
	local root = Instance.new("Folder")
	root.Name = "SwapPlacesWorld"
	root.Parent = Workspace
	part(root, "Ground", Vector3.new(Config.World.Width, 4, Config.World.Depth), CFrame.new(0, -2, 0), Color3.fromRGB(100, 176, 107), Enum.Material.Grass, true)
	part(root, "MainPath", Vector3.new(20, 0.35, 158), CFrame.new(0, 0.18, 0), Color3.fromRGB(233, 213, 174), Enum.Material.Sand, false)
	part(root, "CrossPath", Vector3.new(190, 0.34, 16), CFrame.new(0, 0.19, -18), Color3.fromRGB(233, 213, 174), Enum.Material.Sand, false)
	local plaza = part(root, "SwapPlaza", Vector3.new(1, 72, 72), CFrame.new(0, 0.35, -4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(238, 232, 222), Enum.Material.Cobblestone, true, "Part")
	plaza.Shape = Enum.PartType.Cylinder
	for side = -1, 1, 2 do
		local pad = part(root, side < 0 and "SwapPadA" or "SwapPadB", Vector3.new(0.35, 22, 22), CFrame.new(side * 15, 0.85, -4) * CFrame.Angles(0, 0, math.rad(90)), side < 0 and PINK or CYAN, Enum.Material.Neon, false)
		pad.Shape = Enum.PartType.Cylinder
		label(pad, side < 0 and "ТВОЁ ТЕЛО" or "ТЕЛО ПАРТНЁРА", WHITE, Vector3.new(0, 3, 0), 220)
	end
	local sign = part(root, "MainSign", Vector3.new(42, 12, 1.2), CFrame.new(0, 12, -39), INK, Enum.Material.Wood, true)
	label(sign, "ПОМЕНЯЙСЯ МЕСТАМИ\nТЕЛО ДРУГОГО · ОБМЕН СКИНАМИ", Color3.fromRGB(255, 220, 113), Vector3.new(0, 0, -0.8), 620)
	for side = -1, 1, 2 do
		part(root, "SignColumn", Vector3.new(2, 18, 2), CFrame.new(side * 19, 7, -38), Color3.fromRGB(95, 67, 77), Enum.Material.Wood, true)
		local booth = part(root, side < 0 and "TradeBooth" or "SwapBooth", Vector3.new(22, 8, 16), CFrame.new(side * 55, 4, -17), side < 0 and Color3.fromRGB(83, 71, 131) or Color3.fromRGB(46, 121, 139), Enum.Material.Fabric, true)
		part(booth, "Counter", Vector3.new(16, 2, 3), booth.CFrame * CFrame.new(0, -2, -8), WHITE, Enum.Material.Wood, true)
		label(booth, side < 0 and "ОБМЕН СКИНАМИ" or "ОБМЕН ТЕЛАМИ", WHITE, Vector3.new(0, 7, 0), 300)
	end
	local swapPrompt = prompt(root:FindFirstChild("SwapBooth"), "ОТКРЫТЬ", "ОБМЕН ТЕЛАМИ")
	local tradePrompt = prompt(root:FindFirstChild("TradeBooth"), "ОТКРЫТЬ", "ОБМЕН СКИНАМИ")
	local skinPrompts = {}
	for index, id in ipairs(SkinCatalog.Order) do
		local skin = SkinCatalog.Skins[id]
		local x = (index - 4.5) * 19
		local pedestal = mannequin(root, skin, Vector3.new(x, 0, -70))
		skinPrompts[id] = prompt(pedestal, "ГАРДЕРОБ", skin.Name)
	end
	for side = -1, 1, 2 do
		part(root, "SafetyWall", Vector3.new(2, 12, 180), CFrame.new(side * 109, 5, 0), Color3.fromRGB(150, 221, 221), Enum.Material.Glass, true).Transparency = 0.45
		part(root, "SafetyWall", Vector3.new(220, 12, 2), CFrame.new(0, 5, side * 89), Color3.fromRGB(150, 221, 221), Enum.Material.Glass, true).Transparency = 0.45
		for index = 0, 5 do palm(root, Vector3.new(side * (88 + (index % 2) * 8), 0, -65 + index * 25), 0.72 + (index % 3) * 0.08) end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(Config.Spawn)
	spawn.Color = Color3.fromRGB(255, 220, 113)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root
	label(spawn, "START · ВЫБЕРИ ИГРОКА", INK, Vector3.new(0, 5, 0), 280)
	Lighting.ClockTime = 14.4
	Lighting.Brightness = 2.3
	Lighting.OutdoorAmbient = Color3.fromRGB(117, 133, 139)
	Lighting.EnvironmentDiffuseScale = 0.42
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.ExposureCompensation = 0.08
	return { Root = root, Spawn = spawn, SwapPrompt = swapPrompt, TradePrompt = tradePrompt, SkinPrompts = skinPrompts }
end

return WorldBuilder
