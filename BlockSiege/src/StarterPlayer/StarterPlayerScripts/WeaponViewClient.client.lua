-- BLOCKSIEGE: one equipped weapon in the world, one clean arsenal preview in UI.
-- The ViewportFrame owns its camera and WorldModel; it never adds a second weapon
-- to Workspace or draws a camera-following duplicate over the character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Catalog = require(Shared:WaitForChild("Catalog"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local state = Shared:WaitForChild("MatchState")
local remotes = Shared:FindFirstChild("Remotes")
local animatedWeapon
local animatedWelds = {}
local equipStarted = 0
local recoilUntil = 0
local reloadStarted = 0
local wasReloading = false

local C = {
	Background = Color3.fromRGB(17, 24, 32),
	Panel = Color3.fromRGB(28, 39, 49),
	Text = Color3.fromRGB(244, 246, 239),
	Muted = Color3.fromRGB(164, 184, 193),
	Gold = Color3.fromRGB(255, 199, 76),
	Cyan = Color3.fromRGB(100, 224, 255),
	Build = Color3.fromRGB(112, 219, 176),
	Battle = Color3.fromRGB(255, 142, 87),
}

local function new(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(object, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 7) }, object)
end

local function label(parent, name, value, size, position, textSize, color)
	return new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.GothamBold,
		Text = value,
		TextColor3 = color or C.Text,
		TextSize = textSize or 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local gui = new("ScreenGui", {
	Name = "BlockSiegeWeaponPreview",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 3,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local panel = new("Frame", {
	Name = "WeaponPreviewPanel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 118),
	Size = UDim2.new(0.27, 0, 0, 196),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.03,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
}, gui)
corner(panel, 9)
local panelStroke = new("UIStroke", {
	Name = "RarityBorder",
	Color = C.Cyan,
	Thickness = 1.5,
	Transparency = 0.12,
}, panel)
new("UIGradient", {
	Rotation = 115,
	Color = ColorSequence.new(Color3.fromRGB(42, 61, 72), C.Background),
}, panel)
new("UISizeConstraint", {
	MinSize = Vector2.new(40, 40),
	MaxSize = Vector2.new(350, 270),
}, panel)

local previewHeader = label(panel, "PreviewHeader", "ARSENAL // 3D LOADOUT", UDim2.new(1, -104, 0, 22), UDim2.new(0, 13, 0, 8), 12, C.Muted)
local phaseLabel = label(panel, "PreviewPhase", "BUILD", UDim2.new(0, 78, 0, 22), UDim2.new(1, -91, 0, 8), 11, C.Build)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Right
local accentBar = new("Frame", {
	Name = "AccentBar",
	Position = UDim2.new(0, 12, 0, 33),
	Size = UDim2.new(1, -24, 0, 2),
	BackgroundColor3 = C.Cyan,
	BorderSizePixel = 0,
}, panel)

local viewport = new("ViewportFrame", {
	Name = "WeaponViewport",
	Position = UDim2.new(0, 10, 0, 42),
	Size = UDim2.new(1, -20, 1, -104),
	BackgroundColor3 = Color3.fromRGB(12, 20, 29),
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Ambient = Color3.fromRGB(105, 119, 133),
	LightColor = Color3.fromRGB(255, 242, 218),
	LightDirection = Vector3.new(-0.65, -1, -0.8),
	ImageTransparency = 0,
}, panel)
corner(viewport, 6)
new("UIStroke", { Color = Color3.fromRGB(65, 91, 105), Thickness = 1, Transparency = 0.15 }, viewport)

local worldModel = new("WorldModel", { Name = "WeaponWorld" }, viewport)
local previewCamera = new("Camera", {
	Name = "WeaponPreviewCamera",
	CameraType = Enum.CameraType.Scriptable,
	FieldOfView = 38,
}, viewport)
viewport.CurrentCamera = previewCamera

local weaponName = label(panel, "WeaponName", "", UDim2.new(1, -28, 0, 27), UDim2.new(0, 14, 1, -62), 17, C.Text)
weaponName.Font = Enum.Font.GothamBlack
local rarityLabel = label(panel, "WeaponRarity", "", UDim2.new(0.56, -14, 0, 22), UDim2.new(0, 14, 1, -34), 11, C.Cyan)
local skinLabel = label(panel, "WeaponSkin", "", UDim2.new(0.44, -14, 0, 22), UDim2.new(0.56, 0, 1, -34), 10, C.Gold)
skinLabel.TextXAlignment = Enum.TextXAlignment.Right

local viewModel
local viewKey
local modelCenter = Vector3.zero
local modelDistance = 16
local modelReady = false
local lastPhase
local lastViewportX = 0
local lastViewportY = 0

local function clearViewmodel()
	if viewModel then
		viewModel:Destroy()
	end
	viewModel = nil
	viewKey = nil
	modelReady = false
	modelCenter = Vector3.zero
end

local function prepareParts(model)
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
end

local function frameModel(model)
	-- Normalize only the local preview; server-side weapon scale and hit detection are untouched.
	model:PivotTo(CFrame.new())
	local _, initialSize = model:GetBoundingBox()
	local initialLargest = math.max(initialSize.X, initialSize.Y, initialSize.Z)
	if initialLargest > 0.01 and type(model.ScaleTo) == "function" then
		model:ScaleTo(8 / initialLargest)
	end
	model:PivotTo(CFrame.new())
	local bounds, size = model:GetBoundingBox()
	modelCenter = bounds.Position
	local largest = math.max(size.X, size.Y, size.Z, 1)
	local halfFov = math.rad(previewCamera.FieldOfView * 0.5)
	modelDistance = math.max(9, largest * 0.78 / math.tan(halfFov))
	previewCamera.Focus = CFrame.new()
	previewCamera.CFrame = CFrame.lookAt(Vector3.new(0, 1.7, modelDistance), Vector3.zero)
	modelReady = true
end

local function ensureViewmodel()
	local weaponId = player:GetAttribute("SelectedWeapon") or "Carbine"
	local weapon = Catalog.GetWeapon(weaponId) or Catalog.Weapons.Carbine
	local skin = player:GetAttribute("Cosmetic_WeaponSkin") or "Default"
	local key = weapon.Id .. ":" .. tostring(skin)
	if viewModel and viewKey == key and modelReady then
		return
	end
	clearViewmodel()

	local model = WeaponModels.Build(weapon.Id)
	model.Name = "LocalWeaponViewModel"
	model:SetAttribute("Viewmodel", true)
	model:SetAttribute("PreviewWeaponId", weapon.Id)
	WeaponModels.ApplySkin(model, skin)
	prepareParts(model)
	model.Parent = worldModel
	viewModel = model
	viewKey = key
	frameModel(model)
end

local function refreshLabels(phase)
	local weapon = Catalog.GetWeapon(player:GetAttribute("SelectedWeapon") or "Carbine") or Catalog.Weapons.Carbine
	local skin = player:GetAttribute("Cosmetic_WeaponSkin") or "Default"
	local rarityColor = Catalog.RarityColors[weapon.Rarity] or C.Cyan
	weaponName.Text = weapon.Name
	rarityLabel.Text = Catalog.RarityNames[weapon.Rarity] or string.upper(weapon.Rarity)
	rarityLabel.TextColor3 = rarityColor
	skinLabel.Text = skin == "GoldenArsenal" and "GOLDEN ARSENAL" or (skin == "CelestialArsenal" and "CELESTIAL LEGENDARY" or "STANDARD ISSUE")
	skinLabel.TextColor3 = skin == "GoldenArsenal" and C.Gold or (skin == "CelestialArsenal" and C.Cyan or C.Muted)
	phaseLabel.Text = phase == "Build" and "BUILD" or "BATTLE"
	phaseLabel.TextColor3 = phase == "Build" and C.Build or C.Battle
	panelStroke.Color = rarityColor
	accentBar.BackgroundColor3 = rarityColor
end

local function updateLayout(phase)
	local camera = Workspace.CurrentCamera
	local screen = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local compact = screen.X < 700 or screen.Y < 680
	local sideWidth = math.clamp((screen.X - 200) / 2, 100, 340)
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 118)
	if compact then
		panel.Size = UDim2.fromOffset(sideWidth, phase == "Build" and 62 or 120)
		previewHeader.Visible = phase ~= "Build"
		previewHeader.Size = UDim2.new(1, -12, 0, 18)
		previewHeader.Position = UDim2.new(0, 6, 0, 4)
		previewHeader.TextSize = sideWidth < 240 and 8 or 10
		phaseLabel.Visible = false
		accentBar.Visible = false
		rarityLabel.Visible = false
		skinLabel.Visible = false
		weaponName.Visible = phase ~= "Build"
		if phase == "Build" then
			viewport.Position = UDim2.new(0, 4, 0, 4)
			viewport.Size = UDim2.new(1, -8, 1, -8)
		else
			viewport.Position = UDim2.new(0, 6, 0, 26)
			viewport.Size = UDim2.new(1, -12, 0, 58)
			weaponName.Size = UDim2.new(1, -12, 0, 20)
			weaponName.Position = UDim2.new(0, 6, 0, 94)
			weaponName.TextSize = sideWidth < 240 and 9 or 11
		end
	else
		panel.Size = UDim2.new(0.27, 0, 0, 196)
		previewHeader.Visible = true
		previewHeader.Size = UDim2.new(1, -104, 0, 22)
		previewHeader.Position = UDim2.new(0, 13, 0, 8)
		previewHeader.TextSize = 12
		phaseLabel.Visible = true
		accentBar.Visible = true
		rarityLabel.Visible = true
		skinLabel.Visible = true
		weaponName.Visible = true
		viewport.Position = UDim2.new(0, 10, 0, 42)
		viewport.Size = UDim2.new(1, -20, 1, -104)
		weaponName.Size = UDim2.new(1, -28, 0, 27)
		weaponName.Position = UDim2.new(0, 14, 1, -62)
		weaponName.TextSize = 17
	end
	lastViewportX = screen.X
	lastViewportY = screen.Y
end

local function cacheWorldWeapon()
	local character = player.Character
	local equipped = character and character:FindFirstChild("EquippedWeapon") or nil
	if equipped == animatedWeapon then
		return character, equipped
	end
	animatedWeapon = equipped
	animatedWelds = {}
	equipStarted = os.clock()
	wasReloading = false
	if equipped then
		for _, item in ipairs(equipped:GetDescendants()) do
			if item.Name == "WeaponWeld" and item.ClassName == "Weld" then
				table.insert(animatedWelds, { Weld = item, C0 = item.C0 })
			end
		end
	end
	return character, equipped
end

local function animateWorldWeapon(clock, phase)
	local character, equipped = cacheWorldWeapon()
	local active = equipped ~= nil and (phase == "Build" or phase == "Battle")
	local action = CFrame.new()
	if active then
		-- Small hand-held bob; this changes only the existing Weld.C0 values.
		action = CFrame.new(math.sin(clock * 1.7) * 0.025, math.sin(clock * 2.3) * 0.035, 0)
		local equipAlpha = math.clamp((clock - equipStarted) / 0.28, 0, 1)
		if equipAlpha < 1 then
			action = action * CFrame.new(0, -(1 - equipAlpha) * 0.8, 0) * CFrame.Angles(0, 0, math.rad(-35 * (1 - equipAlpha)))
		end
		if clock < recoilUntil then
			local kick = math.clamp((recoilUntil - clock) / 0.12, 0, 1)
			action = action * CFrame.new(0, 0, kick * 0.22) * CFrame.Angles(math.rad(-10 * kick), 0, 0)
		end
		local reloading = character:GetAttribute("Reloading") == true
		if reloading and not wasReloading then
			reloadStarted = clock
		end
		wasReloading = reloading
		if reloading then
			local duration = math.max(0.2, tonumber(character:GetAttribute("ReloadDuration")) or 1.65)
			local progress = math.clamp((clock - reloadStarted) / duration, 0, 1)
			local arc = math.sin(progress * math.pi)
			action = action * CFrame.new(0, -arc * 0.45, arc * 0.15) * CFrame.Angles(math.rad(arc * 55), 0, math.rad(-30 * arc))
		end
	else
		wasReloading = false
	end
	for _, record in ipairs(animatedWelds) do
		if record.Weld.Parent then
			record.Weld.C0 = active and action * record.C0 or record.C0
		end
	end
end

if remotes then
	local combat = remotes:FindFirstChild("CombatFX")
	if combat then
		combat.OnClientEvent:Connect(function(payload)
			if payload.AttackerUserId == player.UserId and payload.Kind == "Shot" then
				recoilUntil = os.clock() + 0.12
			end
		end)
	end
	local weaponAction = remotes:FindFirstChild("WeaponAction")
	if weaponAction then
		weaponAction.OnClientEvent:Connect(function(payload)
			if payload.Action == "ReloadStart" then
				reloadStarted = os.clock()
			elseif payload.Action == "Equip" then
				equipStarted = os.clock()
			end
		end)
	end
end

RunService.RenderStepped:Connect(function()
	local clock = os.clock()
	local phase = state:GetAttribute("Phase") or "Lobby"
	animateWorldWeapon(clock, phase)
	local visible = phase == "Build" or phase == "Battle"
	panel.Visible = visible
	if not visible then
		if viewModel then
			clearViewmodel()
		end
		lastPhase = phase
		return
	end

	-- Do not gate this UI on a character or Workspace.CurrentCamera. During respawn the
	-- loadout must remain visible, and the viewport has its own scriptable camera.
	ensureViewmodel()
	refreshLabels(phase)
	local camera = Workspace.CurrentCamera
	local viewportSize = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if phase ~= lastPhase or viewportSize.X ~= lastViewportX or viewportSize.Y ~= lastViewportY then
		updateLayout(phase)
		lastPhase = phase
	end
	if viewModel and modelReady then
		local yaw = 78 + math.sin(clock * 0.65) * 9
		local pitch = -7 + math.sin(clock * 0.9) * 2
		local roll = -3 + math.cos(clock * 0.55) * 1.5
		local rotation = CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
		viewModel:PivotTo(rotation * CFrame.new(-modelCenter))
		previewCamera.CFrame = CFrame.lookAt(Vector3.new(0, 1.7 + math.sin(clock * 0.8) * 0.12, modelDistance), Vector3.zero)
	end

end)

player:GetAttributeChangedSignal("SelectedWeapon"):Connect(clearViewmodel)
player:GetAttributeChangedSignal("Cosmetic_WeaponSkin"):Connect(clearViewmodel)
updateLayout()
