-- BLOCKSIEGE // VISIBLE COMBAT EQUIPMENT
-- Anchored, non-colliding utility models are moved only by the server. Named
-- subassemblies are intentionally animated by AbilityService/FortressService.
local CombatModels = {}

local INK = Color3.fromRGB(24, 34, 47)
local METAL = Color3.fromRGB(83, 103, 119)
local LIGHT = Color3.fromRGB(222, 238, 244)
local GOLD = Color3.fromRGB(255, 204, 93)
local HOT = Color3.fromRGB(255, 110, 64)

local function part(parent, name, size, cframe, color, material, shape)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe or CFrame.new()
	object.Color = color or LIGHT
	object.Material = material or Enum.Material.Metal
	object.Anchored = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		object.Shape = shape
	end
	object.Parent = parent
	return object
end

local function light(parent, name, color, range, brightness)
	local object = Instance.new("PointLight")
	object.Name = name
	object.Color = color
	object.Range = range or 10
	object.Brightness = brightness or 1
	object.Parent = parent
	return object
end

local function model(name, primary)
	local object = Instance.new("Model")
	object.Name = name
	object.PrimaryPart = primary
	object:SetAttribute("CombatUtility", true)
	object:SetAttribute("AnimatedModel", true)
	return object
end

local function finish(object, utilityId, teamColor)
	object:SetAttribute("UtilityId", utilityId)
	object:SetAttribute("TeamColor", teamColor)
	for _, item in ipairs(object:GetDescendants()) do
		if item:IsA("BasePart") then
			item:SetAttribute("CombatUtilityPart", true)
		end
	end
	return object
end

function CombatModels.BuildMine(teamColor)
	local accent = teamColor or GOLD
	local root = part(nil, "MineBase", Vector3.new(4.8, 0.8, 4.8), CFrame.new(), INK, Enum.Material.DiamondPlate)
	local object = model("AbilityMine", root)
	root.Parent = object
	part(object, "MinePlate", Vector3.new(3.7, 0.35, 3.7), CFrame.new(0, 0.55, 0), METAL, Enum.Material.Metal)
	local core = part(object, "MineCore", Vector3.new(1.7, 1.2, 1.7), CFrame.new(0, 1.15, 0), accent, Enum.Material.Neon, Enum.PartType.Ball)
	light(core, "MineGlow", accent, 9, 1.5)
	for index = 1, 4 do
		local angle = math.rad(index * 90)
		local offset = Vector3.new(math.cos(angle) * 2.25, 0.1, math.sin(angle) * 2.25)
		part(object, "MineLeg", Vector3.new(0.55, 0.55, 1.8), CFrame.new(offset) * CFrame.Angles(0, -angle, 0), METAL, Enum.Material.Metal)
	end
	for index = 1, 2 do
		local ring = part(object, "MineRing", Vector3.new(5.6, 0.22, 0.45), CFrame.new(0, 0.78, 0) * CFrame.Angles(0, index * math.pi / 2, 0), accent, Enum.Material.Neon)
		ring:SetAttribute("Spin", index == 1 and 1 or -1)
	end
	local fuse = part(object, "MineFuse", Vector3.new(0.35, 0.7, 0.35), CFrame.new(0, 1.9, 0), HOT, Enum.Material.Neon)
	light(fuse, "FuseLight", HOT, 5, 0.8)
	return finish(object, "Minefield", accent)
end

function CombatModels.BuildBomb(teamColor)
	local accent = teamColor or HOT
	local root = part(nil, "BombBody", Vector3.new(3.2, 3.2, 3.2), CFrame.new(), INK, Enum.Material.DiamondPlate, Enum.PartType.Ball)
	local object = model("AbilityBomb", root)
	root.Parent = object
	part(object, "BombBand", Vector3.new(3.35, 0.42, 3.35), CFrame.new(), accent, Enum.Material.Metal)
	part(object, "BombBand", Vector3.new(0.42, 3.35, 3.35), CFrame.new(), accent, Enum.Material.Metal)
	for side = -1, 1, 2 do
		part(object, "BombFin", Vector3.new(0.35, 1.4, 2.2), CFrame.new(side * 1.8, 0, 0) * CFrame.Angles(0, 0, math.rad(side * 20)), METAL, Enum.Material.Metal)
	end
	local fuse = part(object, "BombFuse", Vector3.new(0.45, 1.25, 0.45), CFrame.new(0, 2, 0), GOLD, Enum.Material.WoodPlanks)
	local spark = part(object, "BombSpark", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 2.75, 0), HOT, Enum.Material.Neon, Enum.PartType.Ball)
	light(spark, "BombSparkLight", HOT, 8, 2)
	light(fuse, "BombFuseLight", GOLD, 5, 0.7)
	return finish(object, "ClusterBomb", accent)
end

function CombatModels.BuildTurret(teamColor)
	local accent = teamColor or GOLD
	local root = part(nil, "TurretBase", Vector3.new(6, 1.2, 6), CFrame.new(), INK, Enum.Material.DiamondPlate)
	local object = model("AbilityTurret", root)
	root.Parent = object
	part(object, "TurretPedestal", Vector3.new(3.6, 3.2, 3.6), CFrame.new(0, 2, 0), METAL, Enum.Material.Metal)
	part(object, "TurretTeamRing", Vector3.new(4, 0.35, 4), CFrame.new(0, 3.55, 0), accent, Enum.Material.Neon)
	local headRoot = part(nil, "TurretHeadRoot", Vector3.new(3.8, 2.1, 3.8), CFrame.new(0, 5, 0), INK, Enum.Material.Metal)
	local head = Instance.new("Model")
	head.Name = "TurretHead"
	head.PrimaryPart = headRoot
	headRoot.Parent = head
	head.Parent = object
	part(head, "TurretArmor", Vector3.new(4.2, 1.2, 2.8), CFrame.new(0, 5.2, 0), METAL, Enum.Material.DiamondPlate)
	for side = -1, 1, 2 do
		part(head, "TurretBarrel", Vector3.new(0.65, 0.65, 5.2), CFrame.new(side * 1.05, 5, -3.2), LIGHT, Enum.Material.Metal)
		part(head, "TurretMuzzle", Vector3.new(0.9, 0.9, 0.65), CFrame.new(side * 1.05, 5, -5.8), accent, Enum.Material.Neon)
	end
	local eye = part(head, "TurretEye", Vector3.new(1.2, 0.45, 0.3), CFrame.new(0, 5.5, -1.95), accent, Enum.Material.Neon)
	light(eye, "TurretEyeLight", accent, 10, 1.4)
	return finish(object, "SentryTurret", accent)
end

function CombatModels.BuildDrone(teamColor)
	local accent = teamColor or Color3.fromRGB(93, 239, 174)
	local root = part(nil, "DroneCore", Vector3.new(2.8, 1.8, 2.8), CFrame.new(), LIGHT, Enum.Material.DiamondPlate, Enum.PartType.Ball)
	local object = model("GuardianDrone", root)
	root.Parent = object
	part(object, "DroneBand", Vector3.new(3, 0.35, 3), CFrame.new(), accent, Enum.Material.Neon)
	for index = 1, 4 do
		local angle = math.rad(index * 90)
		local offset = Vector3.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5)
		part(object, "DroneArm", Vector3.new(0.45, 0.45, 2.8), CFrame.new(offset * 0.5) * CFrame.Angles(0, -angle, 0), METAL, Enum.Material.Metal)
		local rotor = part(object, "DroneRotor", Vector3.new(3, 0.15, 0.35), CFrame.new(offset + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, angle, 0), accent, Enum.Material.Neon)
		rotor:SetAttribute("Spin", index % 2 == 0 and 1 or -1)
	end
	part(object, "MedicCross", Vector3.new(0.35, 1.25, 0.25), CFrame.new(0, 0, -1.45), accent, Enum.Material.Neon)
	part(object, "MedicCross", Vector3.new(1.25, 0.35, 0.25), CFrame.new(0, 0, -1.45), accent, Enum.Material.Neon)
	light(root, "DroneGlow", accent, 13, 1.8)
	return finish(object, "GuardianDrone", accent)
end

function CombatModels.BuildBanner(teamColor)
	local accent = teamColor or Color3.fromRGB(206, 150, 255)
	local root = part(nil, "BannerBase", Vector3.new(5.5, 0.8, 5.5), CFrame.new(), INK, Enum.Material.Cobblestone)
	local object = model("RallyBanner", root)
	root.Parent = object
	part(object, "BannerPole", Vector3.new(0.45, 12, 0.45), CFrame.new(0, 6, 0), GOLD, Enum.Material.Metal)
	part(object, "BannerCrown", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 12.5, 0), accent, Enum.Material.Neon, Enum.PartType.Ball)
	part(object, "BannerFlag", Vector3.new(5.8, 3.8, 0.25), CFrame.new(3, 9.5, 0), accent, Enum.Material.Fabric)
	part(object, "BannerStripe", Vector3.new(0.45, 3.9, 0.3), CFrame.new(1.1, 9.5, 0), LIGHT, Enum.Material.Fabric)
	light(root, "BannerGlow", accent, 18, 1.5)
	return finish(object, "RallyBanner", accent)
end

-- Fortress traps use authored base CFrames so rotation never accumulates drift.
function CombatModels.RegisterStructureAnimation(entry)
	entry.AnimationParts = {}
	for _, item in ipairs(entry.Model:GetDescendants()) do
		if item:IsA("BasePart") and (item.Name == "MineRing" or item.Name == "MineCore" or item.Name == "Spike" or item.Name == "SpikeTip" or item.Name == "FlameCore") then
			table.insert(entry.AnimationParts, { Part = item, CFrame = item.CFrame, Size = item.Size, Name = item.Name })
		end
	end
end

function CombatModels.AnimateStructure(entry, clock)
	for _, visual in ipairs(entry.AnimationParts or {}) do
		local item = visual.Part
		if item.Parent then
			if visual.Name == "MineRing" then
				item.CFrame = visual.CFrame * CFrame.Angles(0, clock * 1.8, 0)
			elseif visual.Name == "MineCore" then
				local pulse = 1 + math.sin(clock * 6) * 0.12
				item.Size = visual.Size * pulse
				local glow = item:FindFirstChild("MineGlow")
				if glow then
					glow.Brightness = 1.2 + math.sin(clock * 6) * 0.6
				end
			elseif visual.Name == "Spike" or visual.Name == "SpikeTip" then
				local lift = entry.Model:GetAttribute("Triggered") == true and 0.8 or (0.15 + math.sin(clock * 2.5) * 0.15)
				item.CFrame = visual.CFrame * CFrame.new(0, lift, 0)
			elseif visual.Name == "FlameCore" then
				item.Size = Vector3.new(visual.Size.X, visual.Size.Y * (0.85 + math.sin(clock * 12) * 0.2), visual.Size.Z)
				item.Transparency = 0.08 + math.sin(clock * 9) * 0.05
			end
		end
	end
end

function CombatModels.AnimateUtility(object, clock, active)
	for _, item in ipairs(object:GetDescendants()) do
		if item:IsA("BasePart") then
			if item.Name == "MineRing" or item.Name == "DroneRotor" then
				local spin = tonumber(item:GetAttribute("Spin")) or 1
				item.CFrame = item.CFrame * CFrame.Angles(0, spin * 0.12, 0)
			elseif item.Name == "MineFuse" or item.Name == "BombSpark" then
				item.Transparency = active == false and 0.65 or (math.sin(clock * 14) > 0 and 0 or 0.35)
			end
		end
	end
end

function CombatModels.AnimateBanner(object, clock)
	local flag = object:FindFirstChild("BannerFlag")
	if flag then
		flag.Size = Vector3.new(5.8 + math.sin(clock * 4) * 0.25, 3.8, 0.25)
	end
end

return CombatModels
