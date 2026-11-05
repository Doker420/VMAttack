-- BLOCKSIEGE // JUNGLE NEUTRAL CAMPS
-- Small server-side PvE encounters between the three lanes. Neutrals never
-- replace the 6v6 team fill and cannot destroy a fortress core by themselves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))

local NeutralService = {}
local world
local remotes
local dataService
local rewardHandler
local botService
local state
local phaseProvider = function() return "Lobby" end
local camps = {}
local defeated = 0
local animationClock = 0

local colors = {
	Color3.fromRGB(143, 190, 157),
	Color3.fromRGB(177, 153, 205),
	Color3.fromRGB(205, 175, 112),
}

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

local function living(model)
	local root = rootOf(model)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and humanoid or nil
end

local function makePart(parent, name, size, cframe, color, material, collide)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = cframe
	object.Color = color
	object.Material = material or Enum.Material.Slate
	object.Anchored = true
	object.CanCollide = collide == true
	object.CanTouch = false
	object.CanQuery = true
	object.Parent = parent
	return object
end

local function addTag(head, campId, humanoid)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NeutralTag"
	gui.Size = UDim2.fromOffset(210, 48)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 100
	gui.Parent = head
	local text = Instance.new("TextLabel")
	text.Name = "Health"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(221, 242, 213)
	text.TextStrokeTransparency = 0.25
	text.Text = "NEUTRAL // " .. string.upper(campId) .. " · " .. math.ceil(humanoid.Health)
	text.Parent = gui
	return text
end

local function combatants()
	local result = {}
	if botService then
		for _, team in ipairs(Config.TeamOrder) do
			for _, model in ipairs(botService.GetModels(team)) do
				if living(model) then
					table.insert(result, model)
				end
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("InMatch") == true and living(player.Character) then
			table.insert(result, player.Character)
		end
	end
	return result
end

local function neutralDeath(record, model)
	local attackerId = model:GetAttribute("LastAttackerUserId")
	local player = attackerId and Players:GetPlayerByUserId(attackerId) or nil
	if player then
		if rewardHandler then
			rewardHandler(player, 8, 18, "Нейтральный лагерь очищен")
		elseif dataService then
			dataService.Award(player, 8, 18, "Нейтральный лагерь очищен")
		end
	end
	defeated = defeated + 1
	record.RespawnAt = os.clock() + (Config.Objectives.NeutralRespawn or 45)
	record.Humanoid = nil
	if state then
		state:SetAttribute("NeutralDefeated", defeated)
	end
	if remotes and remotes.CombatFX then
		remotes.CombatFX:FireAllClients({ Kind = "NeutralDefeated", Position = record.Position + Vector3.new(0, 3, 0), Team = "Neutral", Color = Color3.fromRGB(170, 220, 160) })
	end
	task.delay(1, function()
		if record.Model == model then
			model:Destroy()
		end
	end)
end

local function spawnCamp(definition)
	local model = Instance.new("Model")
	model.Name = "NeutralGuardian_" .. definition.Id
	model:SetAttribute("Team", "Neutral")
	model:SetAttribute("IsNeutral", true)
	model:SetAttribute("NeutralCamp", definition.Id)
	model:SetAttribute("Armor", 0.05)
	model.Parent = world.Neutrals
	local color = colors[(#camps % #colors) + 1]
	local root = makePart(model, "HumanoidRootPart", Vector3.new(3, 3, 3), CFrame.new(definition.Position + Vector3.new(0, 3, 0)), color, Enum.Material.Slate, false)
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root
	-- Guardians are combat targets, not invisible navmesh walls. Keeping their
	-- bodies non-colliding prevents a jungle camp from trapping a lane bot; the
	-- parts remain queryable so hitscan and LastAttackerUserId still work.
	local body = makePart(model, "Body", Vector3.new(4.2, 4.5, 3.8), root.CFrame * CFrame.new(0, 0.5, 0), color, Enum.Material.DiamondPlate, false)
	local head = makePart(model, "Head", Vector3.new(2.7, 2.2, 2.7), root.CFrame * CFrame.new(0, 3.4, 0), Color3.fromRGB(45, 65, 65), Enum.Material.Slate, false)
	makePart(model, "NeutralEye", Vector3.new(1.4, 0.35, 0.25), root.CFrame * CFrame.new(0, 3.5, -1.4), Color3.fromRGB(221, 255, 159), Enum.Material.Neon, false)
	for _, side in ipairs({ -1, 1 }) do
		makePart(model, "Horn", Vector3.new(0.55, 2.2, 0.55), root.CFrame * CFrame.new(side * 1.1, 5, 0) * CFrame.Angles(0, 0, math.rad(side * 20)), Color3.fromRGB(222, 213, 173), Enum.Material.Cobblestone, false)
	end
	local crystal = makePart(model, "NeutralCrystal", Vector3.new(1.1, 2.4, 1.1), root.CFrame * CFrame.new(0, 1, 2.2), color, Enum.Material.Neon, false)
	local glow = Instance.new("PointLight")
	glow.Name = "NeutralGlow"
	glow.Color = color
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Parent = crystal
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 220
	humanoid.Health = 220
	humanoid.WalkSpeed = 0
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	local record = { Id = definition.Id, Position = definition.Position, Model = model, Humanoid = humanoid, Root = root, Body = body, Crystal = crystal, CrystalCFrame = crystal.CFrame, NextAttack = os.clock() + 1, RespawnAt = 0 }
	record.Tag = addTag(head, definition.Id, humanoid)
	humanoid.Died:Connect(function()
		neutralDeath(record, model)
	end)
	return record
end

function NeutralService.Init(dependencies)
	world = dependencies.World
	remotes = dependencies.Remotes
	dataService = dependencies.DataService
	botService = dependencies.BotService
	state = dependencies.State
	if not world.Neutrals then
		local folder = Instance.new("Folder")
		folder.Name = "Neutrals"
		folder.Parent = world.Root
		world.Neutrals = folder
	end
end

function NeutralService.SetPhaseProvider(provider)
	phaseProvider = provider or phaseProvider
end

function NeutralService.SetRewardHandler(handler)
	rewardHandler = handler
end

function NeutralService.StartMatch()
	NeutralService.Reset()
	for _, definition in ipairs(Config.Objectives.NeutralCamps) do
		table.insert(camps, spawnCamp(definition))
	end
	if state then
		state:SetAttribute("NeutralCampCount", #camps)
		state:SetAttribute("NeutralDefeated", 0)
	end
end

function NeutralService.Reset()
	for _, record in ipairs(camps) do
		if record.Model then
			record.Model:Destroy()
		end
	end
	camps = {}
	defeated = 0
	if state then
		state:SetAttribute("NeutralCampCount", 0)
		state:SetAttribute("NeutralGuardiansAlive", 0)
		state:SetAttribute("NeutralDefeated", 0)
	end
end

function NeutralService.Step(deltaTime)
	if phaseProvider() ~= "Battle" then
		return
	end
	local now = os.clock()
	local alive = 0
	animationClock = animationClock + deltaTime
	for index, record in ipairs(camps) do
		local humanoid = record.Humanoid
		if humanoid and humanoid.Health > 0 and record.Model.Parent then
			alive = alive + 1
			record.Crystal.CFrame = record.CrystalCFrame * CFrame.Angles(0, now * 1.5, 0)
			local glow = record.Crystal:FindFirstChild("NeutralGlow")
			if glow then
				glow.Brightness = 1.1 + math.sin(now * 4) * 0.35
			end
			if record.Tag then
				record.Tag.Text = "NEUTRAL // " .. string.upper(record.Id) .. " · " .. math.ceil(humanoid.Health)
			end
			if now >= record.NextAttack then
				local nearest
				local nearestRoot
				local nearestDistance = 22
				for _, target in ipairs(combatants()) do
					local targetRoot = rootOf(target)
					if targetRoot then
						local distance = (targetRoot.Position - record.Root.Position).Magnitude
						if distance <= nearestDistance then
							nearest = target
							nearestRoot = targetRoot
							nearestDistance = distance
						end
					end
				end
				if nearest then
					record.NextAttack = now + 1.6
					record.Model:PivotTo(CFrame.lookAt(record.Root.Position, Vector3.new(nearestRoot.Position.X, record.Root.Position.Y, nearestRoot.Position.Z)))
					local targetHumanoid = living(nearest)
					local armor = tonumber(nearest:GetAttribute("Armor")) or 0
					local shield = tonumber(nearest:GetAttribute("DamageTakenMultiplier")) or 1
					targetHumanoid:TakeDamage(10 * math.clamp(shield, 0.05, 1) * (1 - math.clamp(armor, 0, 0.65)))
					if remotes and remotes.CombatFX then
						remotes.CombatFX:FireAllClients({ Kind = "NeutralShot", Origin = record.Body.Position, Finish = nearestRoot.Position, Position = nearestRoot.Position, Team = "Neutral", Color = Color3.fromRGB(170, 220, 160) })
					end
				else
					record.NextAttack = now + 0.4
				end
			end
		elseif record.RespawnAt > 0 and now >= record.RespawnAt then
			if record.Model then
				record.Model:Destroy()
			end
			camps[index] = spawnCamp({ Id = record.Id, Position = record.Position })
		end
	end
	if state then
		state:SetAttribute("NeutralGuardiansAlive", alive)
	end
end

function NeutralService.GetCampCount()
	return #camps
end

return NeutralService
