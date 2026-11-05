-- BLOCKSIEGE // CLASS HUD + ABILITY FX
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local AbilityCatalog = require(Shared:WaitForChild("AbilityCatalog"))
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = {
	Background = Color3.fromRGB(12, 20, 32),
	Panel = Color3.fromRGB(27, 42, 59),
	Text = Color3.fromRGB(239, 247, 255),
	Muted = Color3.fromRGB(157, 180, 198),
	Gold = Color3.fromRGB(255, 211, 107),
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
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, object)
end

local function label(parent, textValue, size, position, textSize, color)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		Font = Enum.Font.Gotham,
		Text = textValue,
		TextColor3 = color or C.Text,
		TextSize = textSize or 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local gui = new("ScreenGui", {
	Name = "BlockSiegeAbilities",
	ResetOnSpawn = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
local panel = new("Frame", {
	Name = "ClassPanel",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -18),
	Size = UDim2.fromOffset(310, 198),
	BackgroundColor3 = C.Background,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
corner(panel, 10)
new("UIStroke", { Color = Color3.fromRGB(78, 111, 137), Thickness = 1.2, Transparency = 0.1 }, panel)
new("UIGradient", { Rotation = 110, Color = ColorSequence.new(Color3.fromRGB(35, 57, 76), C.Background) }, panel)

local classLabel = label(panel, "CLASS // DRAFT", UDim2.new(1, -24, 0, 25), UDim2.new(0, 12, 0, 8), 18, C.Gold)
classLabel.Font = Enum.Font.GothamBlack
local roleLabel = label(panel, "", UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 33), 11, C.Muted)
roleLabel.Font = Enum.Font.GothamBold
local description = label(panel, "", UDim2.new(1, -24, 0, 29), UDim2.new(0, 12, 0, 51), 11, C.Muted)
local buttons = {}
for slot = 1, 2 do
	local button = new("TextButton", {
		Name = "Ability" .. slot,
		Position = UDim2.new(0, 12 + (slot - 1) * 147, 0, 86),
		Size = UDim2.fromOffset(137, 66),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = C.Text,
		TextSize = 13,
		TextWrapped = true,
		AutoButtonColor = true,
	}, panel)
	corner(button, 8)
	new("UIStroke", { Color = C.Gold, Thickness = 1, Transparency = 0.35 }, button)
	buttons[slot] = button
end
local hint = label(panel, "F / G · цель под прицелом · серверный cooldown", UDim2.new(1, -24, 0, 17), UDim2.new(0, 12, 1, -39), 10, C.Muted)
local reloadButton = new("TextButton", {
	Name = "ReloadButton",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -8),
	Size = UDim2.fromOffset(100, 24),
	BackgroundColor3 = C.Panel,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "R · RELOAD",
	TextColor3 = C.Gold,
	TextSize = 10,
}, panel)
corner(reloadButton, 5)

local function aimPosition()
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local camera = Workspace.CurrentCamera
		if camera then
			return camera.CFrame.Position + camera.CFrame.LookVector * 100
		end
	end
	local ok, position = pcall(function()
		return mouse.Hit.Position
	end)
	if ok and position then
		return position
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position + root.CFrame.LookVector * 50 or Vector3.zero
end

local function useAbility(slot)
	if state:GetAttribute("Phase") == "Battle" then
		remotes.AbilityRequest:FireServer(slot, aimPosition())
	end
end
for slot = 1, 2 do
	buttons[slot].Activated:Connect(function()
		useAbility(slot)
	end)
end
reloadButton.Activated:Connect(function()
	if state:GetAttribute("Phase") == "Battle" then
		remotes.ReloadRequest:FireServer()
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or state:GetAttribute("Phase") ~= "Battle" then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		useAbility(1)
	elseif input.KeyCode == Enum.KeyCode.G then
		useAbility(2)
	end
end)

local function layout(phase)
	local camera = Workspace.CurrentCamera
	local screen = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local sideWidth = math.clamp((screen.X - 200) / 2, 100, 340)
	local panelWidth = math.min(310, sideWidth)
	if phase == "Build" then
		panel.AnchorPoint = Vector2.new(0, 0)
		panel.Position = UDim2.new(0, 16, 0, 118)
		panel.Size = UDim2.fromOffset(panelWidth, 64)
		classLabel.Size = UDim2.new(1, -16, 0, 25)
		classLabel.Position = UDim2.new(0, 8, 0, 4)
		classLabel.TextSize = panelWidth < 240 and 11 or 15
		roleLabel.Size = UDim2.new(1, -16, 0, 18)
		roleLabel.Position = UDim2.new(0, 8, 0, 34)
		roleLabel.TextSize = panelWidth < 240 and 8 or 10
		description.Visible = false
		hint.Visible = false
		reloadButton.Visible = false
		for _, button in ipairs(buttons) do
			button.Visible = false
		end
		return
	end
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 16, 1, -18)
	panel.Size = UDim2.fromOffset(panelWidth, 198)
	classLabel.Size = UDim2.new(1, -24, 0, 25)
	classLabel.Position = UDim2.new(0, 12, 0, 8)
	classLabel.TextSize = panelWidth < 240 and 12 or 18
	roleLabel.Size = UDim2.new(1, -24, 0, 18)
	roleLabel.Position = UDim2.new(0, 12, 0, 33)
	roleLabel.TextSize = panelWidth < 240 and 9 or 11
	description.Visible = panelWidth >= 240
	description.Size = UDim2.new(1, -24, 0, 29)
	description.Position = UDim2.new(0, 12, 0, 51)
	description.TextSize = 11
	hint.Visible = true
	reloadButton.Visible = phase == "Battle"
	if panelWidth < 240 then
		for slot, button in ipairs(buttons) do
			button.Visible = true
			button.Size = UDim2.fromOffset(panelWidth - 24, 42)
			button.Position = UDim2.new(0, 12, 0, 56 + (slot - 1) * 46)
			button.TextSize = 10
		end
		hint.Size = UDim2.new(1, -24, 0, 14)
		hint.Position = UDim2.new(0, 12, 0, 146)
		hint.TextSize = 8
		reloadButton.Size = UDim2.fromOffset(math.max(60, panelWidth - 24), 24)
		reloadButton.TextSize = 8
	else
		local buttonWidth = (panelWidth - 36) / 2
		for slot, button in ipairs(buttons) do
			button.Visible = true
			button.Size = UDim2.fromOffset(buttonWidth, 66)
			button.Position = UDim2.new(0, 12 + (slot - 1) * (buttonWidth + 12), 0, 86)
			button.TextSize = panelWidth < 280 and 11 or 13
		end
		hint.Size = UDim2.new(1, -24, 0, 17)
		hint.Position = UDim2.new(0, 12, 1, -39)
		hint.TextSize = 10
		reloadButton.Size = UDim2.fromOffset(100, 24)
		reloadButton.TextSize = 10
	end
end

local function refresh()
	local phase = state:GetAttribute("Phase") or "Lobby"
	layout(phase)
	local classId = player:GetAttribute("ClassId") or ""
	local definition = AbilityCatalog.GetClass(classId)
	panel.Visible = (phase == "Build" or phase == "Battle") and definition ~= nil
	if not definition then
		return
	end
	classLabel.Text = "CLASS // " .. (player:GetAttribute("ClassName") or definition.Name)
	classLabel.TextColor3 = definition.Color
	roleLabel.Text = definition.Role .. " · " .. (phase == "Build" and "СЛУЧАЙНЫЙ КЛАСС НА МАТЧ" or "F / G · СПОСОБНОСТИ")
	description.Text = player:GetAttribute("ClassDescription") or definition.Description
	for slot = 1, 2 do
		local ability = AbilityCatalog.GetAbilityForSlot(classId, slot)
		local remaining = tonumber(player:GetAttribute("Ability" .. slot .. "Remaining")) or 0
		local shortName = player:GetAttribute("Ability" .. slot .. "ShortName") or (ability and ability.ShortName) or "ABILITY"
		local status = phase == "Build" and "BATTLE ONLY" or (remaining > 0 and string.format("%.1f s", remaining) or "READY")
		buttons[slot].Text = string.format("[%s] %s\n%s", ability and ability.Hotkey or (slot == 1 and "F" or "G"), shortName, status)
		buttons[slot].BackgroundColor3 = remaining > 0 and C.Panel or definition.Color
		buttons[slot].TextColor3 = remaining > 0 and C.Muted or Color3.fromRGB(12, 25, 35)
		buttons[slot].Active = phase == "Battle" and remaining <= 0
	end
	local character = player.Character
	local reloading = character and character:GetAttribute("Reloading") == true
	reloadButton.Text = reloading and "RELOADING..." or "R · RELOAD"
	reloadButton.Visible = phase == "Battle"
	hint.Text = phase == "Build" and "Класс закреплён до конца матча · способности откроются в бою" or "F / G · цель под прицелом · серверный cooldown"
end

local fxFolder = Workspace:FindFirstChild("BlockSiegeAbilityFX")
if not fxFolder then
	fxFolder = new("Folder", { Name = "BlockSiegeAbilityFX" }, Workspace)
end

local function effect(position, color, size, duration, ball)
	if not position then
		return
	end
	local object = new("Part", {
		Position = position,
		Size = Vector3.one * (size or 4),
		Color = color or C.Gold,
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Transparency = 0.2,
	}, fxFolder)
	if ball then
		object.Shape = Enum.PartType.Ball
	end
	local light = new("PointLight", { Color = object.Color, Brightness = 2, Range = math.max(8, (size or 4) * 2) }, object)
	TweenService:Create(light, TweenInfo.new(duration or 0.35), { Brightness = 0 }):Play()
	TweenService:Create(object, TweenInfo.new(duration or 0.35), { Size = Vector3.one * (size or 4) * 1.35, Transparency = 1 }):Play()
	Debris:AddItem(object, (duration or 0.35) + 0.05)
end

local function burst(position, color, count, power)
	if not position then
		return
	end
	for _ = 1, count or 8 do
		local lifetime = 0.3 + math.random() * 0.35
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		local object = new("Part", {
			Position = position,
			Size = Vector3.one * (0.35 + math.random() * 0.5),
			Color = color or C.Gold,
			Material = Enum.Material.Neon,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		}, fxFolder)
		TweenService:Create(object, TweenInfo.new(lifetime), { Position = position + direction * (power or 8), Transparency = 1, Size = Vector3.one * 0.05 }):Play()
		Debris:AddItem(object, lifetime + 0.05)
	end
end

remotes.AbilityFX.OnClientEvent:Connect(function(payload)
	if payload.Kind == "Cooldown" then
		return
	end
	local color = payload.Color or C.Gold
	if payload.Kind == "TurretShot" and payload.Origin and payload.Finish then
		local distance = (payload.Finish - payload.Origin).Magnitude
		if distance > 0.1 then
			local beam = new("Part", {
				Size = Vector3.new(0.18, 0.18, distance),
				CFrame = CFrame.lookAt(payload.Origin:Lerp(payload.Finish, 0.5), payload.Finish),
				Color = color,
				Material = Enum.Material.Neon,
				Anchored = true,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				Transparency = 0.05,
			}, fxFolder)
			TweenService:Create(beam, TweenInfo.new(0.1), { Transparency = 1 }):Play()
			Debris:AddItem(beam, 0.12)
		end
		return
	end
	local large = payload.Kind == "BombImpact" or payload.Kind == "MineExplode" or payload.Kind == "Slam"
	local size = payload.Radius and math.min(payload.Radius, 18) or (large and 9 or 4)
	effect(payload.Position or payload.Origin, color, size, large and 0.55 or 0.35, payload.Kind == "Shield" or payload.Kind == "Overdrive" or large)
	if large or payload.Kind == "Heal" or payload.Kind == "Repair" then
		burst(payload.Position or payload.Origin, color, large and 18 or 10, large and 16 or 8)
	end
end)

state:GetAttributeChangedSignal("Phase"):Connect(refresh)
player:GetAttributeChangedSignal("ClassId"):Connect(refresh)
local refreshClock = 0
RunService.RenderStepped:Connect(function(deltaTime)
	refreshClock = refreshClock + deltaTime
	if refreshClock >= 0.08 then
		refreshClock = 0
		refresh()
	end
end)
refresh()
