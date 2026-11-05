-- BLOCKSIEGE // SERVER-AUTHORITATIVE LIVE EVENTS + ADMIN ABUSE
-- Scheduled UTC event windows and allowlisted owner/admin-triggered chaos.
-- No arbitrary commands, client-selected rewards or client-granted permissions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local EventCatalog = require(Shared:WaitForChild("EventCatalog"))

local EventService = {}
local world
local remotes
local state
local bonusService
local fortressService
local botService
local objectFolder
local phaseProvider = function() return "Lobby" end
local teamProvider = function() return nil end
local participantProvider = function() return false end
local rewardHandler
local timeProvider = os.time
local clockProvider = os.clock
local active
local suppressScheduleSlot = -1
local publishClock = 0
local meteorSerial = 0
local meteors = {}
local adminRequests = {}

local METEOR_POINTS = {
	Vector3.new(0, 0, 0),
	Vector3.new(-45, 0, 112),
	Vector3.new(45, 0, -112),
	Vector3.new(-90, 0, 0),
	Vector3.new(90, 0, 0),
	Vector3.new(0, 0, 105),
	Vector3.new(0, 0, -105),
	Vector3.new(-55, 0, -42),
}

local function scheduleNow()
	local timestamp = timeProvider()
	local period = EventCatalog.Schedule.Period
	local slot = math.floor(timestamp / period)
	return slot, timestamp % period
end

local function notify(player, message)
	if remotes and remotes.Notify and player and player.Parent then
		remotes.Notify:FireClient(player, message)
	end
end

local function emit(payload)
	if remotes and remotes.EventFX then
		remotes.EventFX:FireAllClients(payload)
	end
end

local function rootAndHumanoid(model)
	if not model or not model.Parent then
		return nil, nil
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

local function forEachCombatant(callback)
	for _, player in ipairs(Players:GetPlayers()) do
		if participantProvider(player) then
			callback(player.Character, teamProvider(player), player)
		end
	end
	if botService then
		for _, team in ipairs(Config.TeamOrder) do
			for _, model in ipairs(botService.GetModels(team)) do
				callback(model, team, nil)
			end
		end
	end
end

local function clearMeteors()
	for _, record in ipairs(meteors) do
		if record.Model then
			record.Model:Destroy()
		end
	end
	meteors = {}
end

local function repairPulse()
	if not active or active.Id ~= "RepairPulse" then
		return
	end
	for _, team in ipairs(Config.TeamOrder) do
		local position = fortressService and fortressService.GetCorePosition(team) or Config.BasePosition(team)
		if fortressService then
			fortressService.RepairStructures(team, position, 120, 60)
		end
		emit({ Kind = "RepairPulse", Position = position, Team = team, Color = active.Definition.Color, Radius = 18 })
	end
	forEachCombatant(function(model)
		local _, humanoid = rootAndHumanoid(model)
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 15)
		end
	end)
end

local function spawnMeteor()
	if not active or active.Id ~= "MeteorMadness" or not objectFolder then
		return
	end
	meteorSerial = meteorSerial + 1
	local position = METEOR_POINTS[(meteorSerial - 1) % #METEOR_POINTS + 1]
	local model = Instance.new("Model")
	model.Name = "AdminMeteor"
	local rock = Instance.new("Part")
	rock.Name = "MeteorRock"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.one * 5
	rock.Color = Color3.fromRGB(255, 116, 55)
	rock.Material = Enum.Material.Slate
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanTouch = false
	rock.CanQuery = false
	rock.CastShadow = true
	rock.Parent = model
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 93, 48)
	fire.SecondaryColor = Color3.fromRGB(255, 207, 87)
	fire.Heat = 8
	fire.Size = 8
	fire.Parent = rock
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 112, 58)
	light.Brightness = 3
	light.Range = 22
	light.Parent = rock
	local warning = Instance.new("Part")
	warning.Name = "MeteorWarning"
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(0.22, 24, 24)
	warning.CFrame = CFrame.new(position + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90))
	warning.Color = Color3.fromRGB(255, 68, 115)
	warning.Material = Enum.Material.Neon
	warning.Transparency = 0.42
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanTouch = false
	warning.CanQuery = false
	warning.CastShadow = false
	warning.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Name = "MeteorCountdown"
	gui.Size = UDim2.fromOffset(250, 52)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 170
	gui.Parent = warning
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.RichText = true
	label.Text = "<font color=\"#FF75B5\"><b>МЕТЕОР · УЙДИ С КРУГА</b></font>"
	label.TextColor3 = Color3.fromRGB(255, 225, 236)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = gui
	model.PrimaryPart = rock
	model.Parent = objectFolder
	local now = clockProvider()
	local start = position + Vector3.new(-28, 68, -24)
	rock.CFrame = CFrame.new(start)
	table.insert(meteors, {
		Model = model,
		Rock = rock,
		Warning = warning,
		Label = label,
		Position = position,
		Start = start,
		Finish = position + Vector3.new(0, 3, 0),
		Born = now,
		ImpactAt = now + 2.4,
	})
	emit({ Kind = "MeteorWarning", Position = position, Color = active.Definition.Color, Radius = 12 })
end

local function meteorImpact(record)
	forEachCombatant(function(model)
		local root, humanoid = rootAndHumanoid(model)
		if root and humanoid and humanoid.Health > 1 and (root.Position - record.Position).Magnitude <= 12 then
			-- Neutral, telegraphed and nonlethal: admin chaos cannot award a kill,
			-- delete a core or decide the match by itself.
			humanoid:TakeDamage(math.min(18, humanoid.Health - 1))
		end
	end)
	emit({ Kind = "MeteorImpact", Position = record.Position, Color = active and active.Definition.Color or Color3.fromRGB(163, 105, 255), Radius = 12 })
end

local function stepMeteors(deltaTime)
	if not active or active.Id ~= "MeteorMadness" then
		return
	end
	active.MeteorClock = active.MeteorClock + deltaTime
	if active.MeteorClock >= 5.5 then
		active.MeteorClock = 0
		spawnMeteor()
	end
	local now = clockProvider()
	for index = #meteors, 1, -1 do
		local record = meteors[index]
		if not record.Model or not record.Model.Parent then
			table.remove(meteors, index)
		elseif now >= record.ImpactAt then
			meteorImpact(record)
			record.Model:Destroy()
			table.remove(meteors, index)
		else
			local alpha = math.clamp((now - record.Born) / (record.ImpactAt - record.Born), 0, 1)
			record.Rock.CFrame = CFrame.new(record.Start:Lerp(record.Finish, alpha)) * CFrame.Angles(now * 2, now * 1.4, 0)
			record.Warning.Transparency = 0.3 + math.sin(now * 10) * 0.15
			record.Label.Text = string.format("<font color=\"#FF75B5\"><b>МЕТЕОР · %d · УЙДИ С КРУГА</b></font>", math.max(1, math.ceil(record.ImpactAt - now)))
		end
	end
end

local function awardCompletion(record)
	if not rewardHandler then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local presence = participantProvider(player) and record.Presence[player.UserId] or 0
		if presence >= EventCatalog.Schedule.MinimumPresence then
			rewardHandler(player, EventCatalog.Schedule.CompletionCoins, EventCatalog.Schedule.CompletionXP, "ИВЕНТ ЗАВЕРШЁН · " .. record.Definition.Name)
		end
	end
end

local function publishState()
	local slot, within = scheduleNow()
	local inWindow = within < EventCatalog.Schedule.ActiveWindow
	local currentDefinition = EventCatalog.GetForSlot(slot)
	local nextDefinition = EventCatalog.GetForSlot(slot + 1)
	if state then
		if active then
			state:SetAttribute("EventActive", true)
			state:SetAttribute("EventId", active.Id)
			state:SetAttribute("EventName", active.Definition.Name)
			state:SetAttribute("EventDescription", active.Definition.Description)
			state:SetAttribute("EventColor", active.Definition.Color)
			state:SetAttribute("EventManual", active.Manual)
			state:SetAttribute("EventTime", math.max(0, math.ceil(active.Remaining)))
			state:SetAttribute("EventNextId", nextDefinition.Id)
			state:SetAttribute("EventNextName", nextDefinition.Name)
			state:SetAttribute("EventScheduledActive", inWindow)
			state:SetAttribute("EventScheduleWaiting", false)
		else
			local currentAvailable = inWindow and suppressScheduleSlot ~= slot
			local shown = currentAvailable and currentDefinition or nextDefinition
			state:SetAttribute("EventActive", false)
			state:SetAttribute("EventId", "")
			state:SetAttribute("EventName", "")
			state:SetAttribute("EventDescription", "")
			state:SetAttribute("EventManual", false)
			state:SetAttribute("EventColor", shown.Color)
			state:SetAttribute("EventNextId", shown.Id)
			state:SetAttribute("EventNextName", shown.Name)
			state:SetAttribute("EventScheduledActive", currentAvailable)
			state:SetAttribute("EventScheduleWaiting", currentAvailable and phaseProvider() ~= "Battle")
			state:SetAttribute("EventTime", currentAvailable and math.max(0, math.ceil(EventCatalog.Schedule.ActiveWindow - within)) or math.max(0, math.ceil(EventCatalog.Schedule.Period - within)))
		end
		state:SetAttribute("EventRewardMultiplier", EventService.GetRewardMultiplier())
	end
end

local stopActive

local function startEvent(id, manual, remaining, scheduleSlot)
	local definition = EventCatalog.Get(id)
	if not definition or phaseProvider() ~= "Battle" then
		return false
	end
	if active then
		stopActive("replace", false)
	end
	local slot = scheduleNow()
	active = {
		Id = id,
		Definition = definition,
		Manual = manual == true,
		Remaining = math.max(0.1, tonumber(remaining) or definition.Duration),
		Elapsed = 0,
		Presence = {},
		PulseClock = 0,
		MeteorClock = 0,
		ScheduleSlot = scheduleSlot,
	}
	if active.Manual then
		suppressScheduleSlot = slot
	end
	if state then
		state:SetAttribute("EventSequence", (state:GetAttribute("EventSequence") or 0) + 1)
	end
	emit({
		Kind = "Announcement",
		Title = active.Manual and "⚡ ADMIN ABUSE ⚡" or "LIVE EVENT",
		Subtitle = definition.Name .. "\n" .. definition.Announcement,
		Color = definition.Color,
		Duration = 4,
	})
	if id == "SupplyStorm" then
		if bonusService then
			bonusService.SetEventBoost(3)
			bonusService.TriggerSupplyWave(1)
		end
	elseif id == "RepairPulse" then
		repairPulse()
	elseif id == "MeteorMadness" then
		spawnMeteor()
	end
	publishState()
	return true
end

stopActive = function(reason, completed)
	local record = active
	if not record then
		return
	end
	-- Completion is a fixed participation grant, not a Gold Rush action reward.
	-- Clear active first so MatchService cannot multiply the 5/10 completion grant.
	active = nil
	if completed then
		awardCompletion(record)
		suppressScheduleSlot = record.ScheduleSlot or scheduleNow()
	end
	if bonusService then
		bonusService.SetEventBoost(1)
	end
	clearMeteors()
	if completed then
		emit({
			Kind = "Announcement",
			Title = "ИВЕНТ ЗАВЕРШЁН",
			Subtitle = record.Definition.Name .. "\nНаграда активным участникам · следующий ивент уже в расписании",
			Color = record.Definition.Color,
			Duration = 3,
		})
	end
	publishState()
end

function EventService.IsAdmin(player)
	if not player or not player.Parent then
		return false
	end
	local admin = Config.Admin or {}
	if admin.UserIds and admin.UserIds[player.UserId] == true then
		return true
	end
	if admin.StudioAdmin and RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		return ok and rank >= (admin.GroupMinimumRank or 200)
	end
	return false
end

function EventService.OnPlayerAdded(player)
	player:SetAttribute("EventAdmin", EventService.IsAdmin(player))
end

function EventService.OnPlayerRemoving(player)
	if player then
		adminRequests[player.UserId] = nil
	end
end

function EventService.HandleAdminRequest(player, action, eventId)
	if not EventService.IsAdmin(player) then
		notify(player, "ADMIN · недостаточно прав")
		return false, "not_admin"
	end
	local now = clockProvider()
	local previous = adminRequests[player.UserId] or -1000
	if now - previous < (Config.Admin.RequestCooldown or 0.75) then
		notify(player, "ADMIN · подожди перед следующей командой")
		return false, "cooldown"
	end
	adminRequests[player.UserId] = now
	if action == "Stop" then
		if not active then
			return false, "no_active_event"
		end
		suppressScheduleSlot = scheduleNow()
		stopActive("admin", false)
		notify(player, "ADMIN · ивент остановлен без награды за завершение")
		return true
	end
	if action ~= "Start" or not EventCatalog.Get(eventId) then
		return false, "invalid_request"
	end
	if phaseProvider() ~= "Battle" then
		notify(player, "ADMIN · запуск ивентов доступен во время Battle")
		return false, "wrong_phase"
	end
	return startEvent(eventId, true, EventCatalog.Get(eventId).Duration, nil)
end

function EventService.GetRewardMultiplier()
	return active and active.Id == "GoldRush" and phaseProvider() == "Battle" and 2 or 1
end

function EventService.GetActiveId()
	return active and active.Id or ""
end

function EventService.GetMeteorCount()
	return #meteors
end

function EventService.SetProviders(phase, team, participant, reward)
	phaseProvider = phase or phaseProvider
	teamProvider = team or teamProvider
	participantProvider = participant or participantProvider
	rewardHandler = reward or rewardHandler
end

function EventService.Step(deltaTime)
	local dt = math.clamp(tonumber(deltaTime) or 0, 0, 0.25)
	if active then
		if phaseProvider() ~= "Battle" then
			stopActive("phase", false)
		else
			active.Elapsed = active.Elapsed + dt
			active.Remaining = active.Remaining - dt
			for _, player in ipairs(Players:GetPlayers()) do
				if participantProvider(player) then
					active.Presence[player.UserId] = (active.Presence[player.UserId] or 0) + dt
				end
			end
			if active.Id == "RepairPulse" then
				active.PulseClock = active.PulseClock + dt
				if active.PulseClock >= 10 then
					active.PulseClock = 0
					repairPulse()
				end
			elseif active.Id == "MeteorMadness" then
				stepMeteors(dt)
			end
			if active and active.Remaining <= 0 then
				stopActive("complete", true)
			end
		end
	end
	local slot, within = scheduleNow()
	if active and not active.Manual and (slot ~= active.ScheduleSlot or within >= EventCatalog.Schedule.ActiveWindow) then
		stopActive("schedule", within >= EventCatalog.Schedule.ActiveWindow and phaseProvider() == "Battle")
	end
	if not active and phaseProvider() == "Battle" and within < EventCatalog.Schedule.ActiveWindow and suppressScheduleSlot ~= slot then
		startEvent(EventCatalog.GetForSlot(slot).Id, false, EventCatalog.Schedule.ActiveWindow - within, slot)
	end
	publishClock = publishClock + dt
	if publishClock >= 0.2 then
		publishClock = 0
		publishState()
	end
end

function EventService.Init(dependencies)
	world = dependencies.World
	remotes = dependencies.Remotes
	state = dependencies.State
	bonusService = dependencies.BonusService
	fortressService = dependencies.FortressService
	botService = dependencies.BotService
	timeProvider = dependencies.TimeProvider or os.time
	clockProvider = dependencies.ClockProvider or os.clock
	objectFolder = world.Root:FindFirstChild("EventObjects")
	if not objectFolder then
		objectFolder = Instance.new("Folder")
		objectFolder.Name = "EventObjects"
		objectFolder.Parent = world.Root
	end
	if state then
		state:SetAttribute("EventActive", false)
		state:SetAttribute("EventSequence", 0)
		state:SetAttribute("EventRewardMultiplier", 1)
	end
	publishState()
end

function EventService.Reset()
	stopActive("reset", false)
	suppressScheduleSlot = -1
	meteorSerial = 0
	publishState()
end

return EventService
