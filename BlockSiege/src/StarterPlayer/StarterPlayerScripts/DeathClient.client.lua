-- BLOCKSIEGE // Server-sourced death card and compact kill feed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")

local C = { Background = Color3.fromRGB(16, 20, 35), Red = Color3.fromRGB(255, 111, 116), Gold = Color3.fromRGB(255, 213, 111), Text = Color3.fromRGB(246, 249, 255), Muted = Color3.fromRGB(174, 191, 216) }
local function new(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function escape(value)
	local escaped = tostring(value or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
	return escaped
end
local function label(parent, textValue, size, position, textSize, color)
	return new("TextLabel", { BackgroundTransparency = 1, RichText = true, Text = textValue, Size = size, Position = position or UDim2.new(), Font = Enum.Font.GothamBold, TextWrapped = true, TextSize = textSize or 16, TextColor3 = color or C.Text }, parent)
end
local gui = new("ScreenGui", { Name = "BlockSiegeDeathUI", ResetOnSpawn = false, DisplayOrder = 14, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.43, 0), Size = UDim2.new(0, 380, 0, 132), BackgroundColor3 = C.Background, BackgroundTransparency = 0.04, Visible = false, ZIndex = 20 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
new("UIStroke", { Color = C.Red, Thickness = 2, Transparency = 0.08 }, card)
local title = label(card, '<font color="#FF6F74"><b>ВЫ ВЫБЫЛИ ИЗ БОЯ</b></font>', UDim2.new(1, -28, 0, 32), UDim2.new(0, 14, 0, 10), 22, C.Red)
title.ZIndex = 21
local detail = label(card, "", UDim2.new(1, -28, 0, 43), UDim2.new(0, 14, 0, 47), 15, C.Text)
detail.ZIndex = 21
local timer = label(card, "", UDim2.new(1, -28, 0, 25), UDim2.new(0, 14, 0, 98), 14, C.Gold)
timer.ZIndex = 21
local feed = label(gui, "", UDim2.new(0, 330, 0, 52), UDim2.new(0, 16, 0, 112), 12, C.Muted)
feed.TextXAlignment = Enum.TextXAlignment.Left
feed.Visible = false
local version = 0
local deathEnds = 0
local feedVersion = 0

local function sourceText(payload)
	if payload.Source == "Expedition" then
		return "PVЕ СТРАЖ · " .. (payload.KillerName ~= "" and payload.KillerName or "экспедиция")
	end
	if payload.KillerName and payload.KillerName ~= "" then
		return "Источник: " .. payload.KillerName
	end
	return "Источник не указан · сервер не присваивает случайный kill"
end

remotes.DeathFX.OnClientEvent:Connect(function(payload)
	if payload.VictimUserId == player.UserId then
		version = version + 1
		local current = version
		deathEnds = os.clock() + math.max(2, tonumber(payload.RespawnDuration) or 4)
		title.Text = payload.InExpedition and '<font color="#C6A0FF"><b>PVЕ · ВЫ ПАЛИ В РЕЙДЕ</b></font>' or '<font color="#FF6F74"><b>ВЫ ВЫБЫЛИ ИЗ БОЯ</b></font>'
		detail.Text = escape(sourceText(payload))
		card.Visible = true
		task.delay(math.max(2, tonumber(payload.RespawnDuration) or 4) + 0.25, function()
			if current == version then card.Visible = false end
		end)
	elseif state:GetAttribute("Phase") == "Battle" then
		feedVersion = feedVersion + 1
		local current = feedVersion
		local killerName = payload.KillerName
		local killer = (type(killerName) == "string" and killerName ~= "") and killerName or (payload.Source == "Expedition" and "PVЕ" or "UNKNOWN")
		feed.Text = string.format('<font color="#FFD36F"><b>%s</b></font>  →  <font color="#AEBFD8">%s</font>', escape(killer), escape(payload.VictimName))
		feed.Visible = true
		task.delay(3.5, function()
			if current == feedVersion then feed.Visible = false end
		end)
	end
end)

state:GetAttributeChangedSignal("Phase"):Connect(function()
	local phase = state:GetAttribute("Phase")
	if phase == "Lobby" or phase == "Results" then
		version = version + 1
		feedVersion = feedVersion + 1
		card.Visible = false
		feed.Visible = false
	end
end)
RunService.RenderStepped:Connect(function()
	if card.Visible then
		timer.Text = "ВОЗВРАЩЕНИЕ ЧЕРЕЗ  " .. string.format("%.1f", math.max(0, deathEnds - os.clock())) .. " s"
	end
	local camera = Workspace.CurrentCamera
	if camera then
		card.Size = UDim2.new(0, math.min(380, math.max(280, camera.ViewportSize.X - 32)), 0, 132)
		feed.Size = UDim2.new(0, math.min(330, math.max(220, camera.ViewportSize.X - 32)), 0, 52)
	end
end)
