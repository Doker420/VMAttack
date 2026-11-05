-- Secondary capture objective: the fortress/core victory rule remains unchanged.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))

local CaptureService = {}
local world
local state
local botService
local remotes
local phaseProvider = function()
	return "Lobby"
end
local owner = ""
local progress = 0
local progressTeam = ""
local contested = false
local published
local captureHandler

local function point()
	return world and world.CapturePoint
end

local function colorFor(team)
	return Config.Teams[team] and Config.Teams[team].Color or Color3.fromRGB(237, 190, 64)
end

local function publish()
	local signature = table.concat({ owner, progressTeam, tostring(math.floor(progress * 10)), tostring(contested) }, ":")
	if published == signature then
		return
	end
	published = signature
	if state then
		state:SetAttribute("Capture67Owner", owner)
		state:SetAttribute("Capture67Team", progressTeam)
		state:SetAttribute("Capture67Progress", math.floor(progress + 0.5))
		state:SetAttribute("Capture67Contested", contested)
		state:SetAttribute("Capture67Radius", 22)
	end
	local capture = point()
	if capture then
		local color = colorFor(owner ~= "" and owner or progressTeam)
		capture.Model:SetAttribute("Owner", owner)
		capture.Model:SetAttribute("Progress", math.floor(progress + 0.5))
		capture.Model:SetAttribute("Contested", contested)
		capture.Light.Color = color
		for _, item in ipairs(capture.Model:GetDescendants()) do
			if item:IsA("BasePart") and (item.Name == "CaptureCrystal" or item.Name == "CaptureGlow" or item.Name == "CaptureRing") then
				item.Color = color
			end
		end
	end
end

function CaptureService.Init(dependencies)
	world = dependencies.World
	state = dependencies.State
	botService = dependencies.BotService
	remotes = dependencies.Remotes
	CaptureService.Reset()
end

function CaptureService.SetPhaseProvider(provider)
	phaseProvider = provider
end

function CaptureService.SetCaptureHandler(handler)
	captureHandler = handler
end

function CaptureService.Reset()
	owner = ""
	progress = 0
	progressTeam = ""
	contested = false
	published = nil
	publish()
end

function CaptureService.GetPosition()
	local capture = point()
	return capture and capture.Root.Position or Vector3.zero
end

function CaptureService.GetOwner()
	return owner ~= "" and owner or nil
end

function CaptureService.GetProgress()
	return progress, progressTeam, contested
end

local function presence(team)
	local count = 0
	local position = CaptureService.GetPosition()
	if botService then
		for _, model in ipairs(botService.GetModels(team)) do
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and (root.Position - position).Magnitude <= 22 then
				count = count + 1
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Team") == team and player:GetAttribute("InMatch") == true then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and (root.Position - position).Magnitude <= 22 then
				count = count + 1
			end
		end
	end
	return count
end

function CaptureService.Step(deltaTime)
	if phaseProvider() ~= "Battle" then
		return
	end
	local blue = presence("Blue")
	local orange = presence("Orange")
	contested = blue > 0 and orange > 0
	local presentTeam = blue > 0 and "Blue" or (orange > 0 and "Orange" or nil)
	local rate = 25 * deltaTime
	if not contested and presentTeam then
		if owner == presentTeam then
			progressTeam = presentTeam
			progress = 100
		else
			if progressTeam ~= presentTeam then
				if owner ~= "" or progress > 0 then
					progress = progress - rate
					if progress <= 0 then
						owner = ""
						progressTeam = presentTeam
						progress = 0
					end
				else
					progressTeam = presentTeam
					progress = 0
				end
			end
			if progressTeam == presentTeam then
				progress = math.min(100, progress + rate)
				if progress >= 100 and owner ~= presentTeam then
					owner = presentTeam
					progressTeam = presentTeam
					if remotes then
						remotes.CaptureFX:FireAllClients({ Kind = "Captured", Position = CaptureService.GetPosition(), Team = presentTeam })
					end
					if captureHandler then
						captureHandler(presentTeam)
					end
				end
			end
		end
	elseif not presentTeam and owner == "" then
		progress = math.max(0, progress - rate * 0.35)
	end
	publish()
end

return CaptureService
