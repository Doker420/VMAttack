-- Client-side fog of war: the opposing fortress is hidden only during the Build phase.
-- This is presentation-only; server geometry, navigation and victory rules stay authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local state = Shared:WaitForChild("MatchState")
local world = Workspace:WaitForChild("BlockSiegeWorld")
local structures = world:WaitForChild("Structures")

local originals = {}
local nextRefresh = 0
local effectClasses = {
	BillboardGui = true,
	SurfaceGui = true,
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Sparkles = true,
	ParticleEmitter = true,
	Smoke = true,
	Fire = true,
	Trail = true,
	Beam = true,
	Highlight = true,
}
local textureClasses = { Texture = true, Decal = true }

local function remember(part)
	local record = originals[part]
	if not record then
		record = { Transparency = part.LocalTransparencyModifier, CastShadow = part.CastShadow, Effects = {} }
		originals[part] = record
	end
	for _, item in ipairs(part:GetDescendants()) do
		if textureClasses[item.ClassName] and not record.Effects[item] then
			record.Effects[item] = { Transparency = item.Transparency }
		elseif effectClasses[item.ClassName] and not record.Effects[item] then
			record.Effects[item] = { Enabled = item.Enabled }
		end
	end
	return record
end

local function hidePart(part)
	local record = remember(part)
	part.LocalTransparencyModifier = 1
	part.CastShadow = false
	for item, effect in pairs(record.Effects) do
		if item.Parent then
			if effect.Transparency ~= nil then
				item.Transparency = 1
			elseif effect.Enabled ~= nil then
				item.Enabled = false
			end
		end
	end
end

local function showPart(part)
	local record = originals[part]
	if not record then
		return
	end
	part.LocalTransparencyModifier = record.Transparency
	part.CastShadow = record.CastShadow
	for item, effect in pairs(record.Effects) do
		if item.Parent then
			if effect.Transparency ~= nil then
				item.Transparency = effect.Transparency
			elseif effect.Enabled ~= nil then
				item.Enabled = effect.Enabled
			end
		end
	end
	originals[part] = nil
end

local function isVisibilityControlled(part)
	if part:GetAttribute("BaseGeometry") == true then
		return true
	end
	local current = part.Parent
	while current and current ~= world do
		if current == structures then
			return true
		end
		current = current.Parent
	end
	return false
end

local function refresh()
	local phase = state:GetAttribute("Phase") or "Lobby"
	local team = player:GetAttribute("Team") or ""
	local enemy = team == "Blue" and "Orange" or (team == "Orange" and "Blue" or nil)
	local hideEnemy = Config.Arena.HideEnemyBaseDuringBuild and phase == "Build" and enemy ~= nil
	for _, part in ipairs(world:GetDescendants()) do
		if part:IsA("BasePart") and isVisibilityControlled(part) then
			if hideEnemy and part:GetAttribute("Team") == enemy then
				hidePart(part)
			else
				showPart(part)
			end
		end
	end
	for part in pairs(originals) do
		if not part.Parent then
			originals[part] = nil
		end
	end
end

state:GetAttributeChangedSignal("Phase"):Connect(refresh)
player:GetAttributeChangedSignal("Team"):Connect(refresh)
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now >= nextRefresh then
		nextRefresh = now + 0.3
		refresh()
	end
end)
refresh()
