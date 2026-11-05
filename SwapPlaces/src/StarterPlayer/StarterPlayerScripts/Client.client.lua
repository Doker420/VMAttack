-- Responsive social UI and camera binding for avatar/body swaps.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("SwapPlaces")
local Config = require(Shared:WaitForChild("Config"))
local SkinCatalog = require(Shared:WaitForChild("SkinCatalog"))
local remotes = Shared:WaitForChild("Remotes")
local INK = Color3.fromRGB(25, 30, 54)
local PANEL = Color3.fromRGB(43, 51, 82)
local TEXT = Color3.fromRGB(246, 248, 255)
local MUTED = Color3.fromRGB(178, 190, 216)
local PINK = Color3.fromRGB(241, 105, 174)
local CYAN = Color3.fromRGB(83, 211, 230)
local GOLD = Color3.fromRGB(255, 211, 105)
local GREEN = Color3.fromRGB(94, 218, 151)

local function new(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties or {}) do object[key] = value end
	object.Parent = parent
	return object
end
local function corner(object, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 9) }, object)
end
local function label(parent, text, size, position, textSize, color)
	return new("TextLabel", {
		BackgroundTransparency = 1, Size = size, Position = position or UDim2.new(),
		Font = Enum.Font.Gotham, Text = text, TextColor3 = color or TEXT,
		TextSize = textSize or 16, TextWrapped = true,
	}, parent)
end
local function button(parent, text, size, position, color)
	local object = new("TextButton", {
		BackgroundColor3 = color or PANEL, Size = size, Position = position or UDim2.new(),
		Font = Enum.Font.GothamBold, Text = text, TextColor3 = TEXT, TextSize = 15,
		TextWrapped = true, AutoButtonColor = true, BorderSizePixel = 0,
	}, parent)
	corner(object)
	new("UIStroke", { Color = Color3.fromRGB(93, 111, 151), Thickness = 1, Transparency = 0.2 }, object)
	return object
end

local gui = new("ScreenGui", { Name = "SwapPlacesUI", ResetOnSpawn = false, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))
local top = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 82), BackgroundColor3 = INK, BackgroundTransparency = 0.08 }, gui)
corner(top, 12)
local title = label(top, "ПОМЕНЯЙСЯ МЕСТАМИ", UDim2.new(0.58, -16, 0, 36), UDim2.fromOffset(16, 7), 25, GOLD)
title.Font = Enum.Font.GothamBlack
title.TextXAlignment = Enum.TextXAlignment.Left
local status = label(top, "Загрузка профиля…", UDim2.new(0.58, -16, 0, 26), UDim2.fromOffset(16, 46), 15, MUTED)
status.TextXAlignment = Enum.TextXAlignment.Left
local pairStatus = label(top, "СВОЙ АВАТАР", UDim2.new(0.4, -18, 0, 60), UDim2.new(0.6, 0, 0, 11), 18, CYAN)
pairStatus.TextXAlignment = Enum.TextXAlignment.Right

local playersFrame = new("Frame", { Position = UDim2.fromOffset(12, 108), Size = UDim2.fromOffset(320, 342), BackgroundColor3 = INK, BackgroundTransparency = 0.08 }, gui)
corner(playersFrame, 12)
label(playersFrame, "ИГРОКИ · ВЫБЕРИ ДЕЙСТВИЕ", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 7), 16, GOLD)
local playerList = new("ScrollingFrame", { Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 1, -56), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new() }, playersFrame)
new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, playerList)

local dock = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 108), Size = UDim2.fromOffset(240, 148), BackgroundColor3 = INK, BackgroundTransparency = 0.08 }, gui)
corner(dock, 12)
local swapButton = button(dock, "ПОМЕНЯТЬСЯ ТЕЛАМИ [B]", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 10), PINK)
local tradeButton = button(dock, "ОБМЕН СКИНАМИ [T]", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 54), CYAN)
local inventoryButton = button(dock, "ГАРДЕРОБ [I]", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 98), PANEL)

local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.9, 0, 0.72, 0), BackgroundColor3 = INK, Visible = false }, gui)
corner(panel, 14)
new("UISizeConstraint", { MinSize = Vector2.new(320, 470), MaxSize = Vector2.new(700, 570) }, panel)
new("UIStroke", { Color = CYAN, Thickness = 1.5, Transparency = 0.15 }, panel)
local modalTitle = label(panel, "", UDim2.new(1, -90, 0, 44), UDim2.fromOffset(18, 8), 24, GOLD)
modalTitle.Font = Enum.Font.GothamBlack
local closeButton = button(panel, "×", UDim2.fromOffset(44, 38), UDim2.new(1, -58, 0, 10), PANEL)
closeButton.Activated:Connect(function() panel.Visible = false end)
local pages = new("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 1, -76), BackgroundTransparency = 1 }, panel)
local swapPage = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, pages)
local tradePage = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, pages)
local inventoryPage = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, pages)

local swapTitle = label(swapPage, "ОБМЕН ПЕРСОНАЖАМИ", UDim2.new(1, 0, 0, 44), UDim2.new(), 23, PINK)
local swapDescription = label(swapPage, "Выберите ТЕЛО у игрока. Он должен согласиться; затем любой из вас может оплатить обмен.", UDim2.new(1, 0, 0, 110), UDim2.fromOffset(0, 54), 18, TEXT)
local swapTimer = label(swapPage, "", UDim2.new(1, 0, 0, 38), UDim2.fromOffset(0, 172), 18, GOLD)
local acceptSwap = button(swapPage, "СОГЛАСИТЬСЯ", UDim2.new(0.47, 0, 0, 48), UDim2.new(0, 0, 1, -158), GREEN)
local declineSwap = button(swapPage, "ОТКЛОНИТЬ", UDim2.new(0.47, 0, 0, 48), UDim2.new(0.53, 0, 1, -158), Color3.fromRGB(175, 74, 91))
local paySwap = button(swapPage, "ОПЛАТИТЬ", UDim2.new(1, 0, 0, 52), UDim2.new(0, 0, 1, -100), GOLD)
local cancelSwap = button(swapPage, "ОТМЕНИТЬ ПРЕДЛОЖЕНИЕ", UDim2.new(1, 0, 0, 42), UDim2.new(0, 0, 1, -48), PANEL)
local revertSwap = button(swapPage, "ВЕРНУТЬСЯ В СВОЁ ТЕЛО", UDim2.new(1, 0, 0, 52), UDim2.new(0, 0, 1, -58), PINK)
acceptSwap.Activated:Connect(function() remotes.SwapAction:FireServer("Accept") end)
declineSwap.Activated:Connect(function() remotes.SwapAction:FireServer("Decline") end)
paySwap.Activated:Connect(function() remotes.SwapAction:FireServer("Pay") end)
cancelSwap.Activated:Connect(function() remotes.SwapAction:FireServer("Cancel") end)
revertSwap.Activated:Connect(function() remotes.SwapAction:FireServer("Revert") end)

local tradeSummary = label(tradePage, "Выберите игрока кнопкой СКИН. Каждый предлагает один собственный скин.", UDim2.new(1, 0, 0, 98), UDim2.new(), 17, TEXT)
local ownSkins = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 1, -218), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new() }, tradePage)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, ownSkins)
local confirmTrade = button(tradePage, "ПОДТВЕРДИТЬ ОБМЕН", UDim2.new(0.58, 0, 0, 46), UDim2.new(0, 0, 1, -52), GREEN)
local cancelTrade = button(tradePage, "ОТМЕНА", UDim2.new(0.38, 0, 0, 46), UDim2.new(0.62, 0, 1, -52), PANEL)
confirmTrade.Activated:Connect(function() remotes.TradeAction:FireServer("Confirm") end)
cancelTrade.Activated:Connect(function() remotes.TradeAction:FireServer("Cancel") end)

local inventoryList = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(0, 0, 0, #SkinCatalog.Order * 72) }, inventoryPage)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, inventoryList)

local toast = label(gui, "", UDim2.new(0.8, 0, 0, 58), UDim2.new(0.1, 0, 0, 102), 18, GOLD)
toast.TextStrokeTransparency = 0.35
local toastVersion = 0
local function notify(text)
	toastVersion = toastVersion + 1
	local version = toastVersion
	toast.Text = tostring(text)
	task.delay(4, function() if version == toastVersion then toast.Text = "" end end)
end

local profile = { OwnedSkins = { Default = true }, EquippedSkin = "Default", Swaps = 0, Trades = 0 }
local swapSession, tradeSession
local swapReceived = os.clock()
local activePage = "Swap"

local function showPage(name)
	activePage = name
	swapPage.Visible = name == "Swap"
	tradePage.Visible = name == "Trade"
	inventoryPage.Visible = name == "Inventory"
	modalTitle.Text = name == "Swap" and "ОБМЕН ТЕЛАМИ" or (name == "Trade" and "ВЗАИМНЫЙ ОБМЕН СКИНАМИ" or "МОЙ ГАРДЕРОБ")
	panel.Visible = true
end
swapButton.Activated:Connect(function() showPage("Swap") end)
tradeButton.Activated:Connect(function() showPage("Trade") end)
inventoryButton.Activated:Connect(function() showPage("Inventory") end)

local function refreshPlayers()
	for _, child in ipairs(playerList:GetChildren()) do if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end end
	local index = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			index = index + 1
			local row = new("Frame", { Size = UDim2.new(1, -4, 0, 52), BackgroundColor3 = PANEL, LayoutOrder = index }, playerList)
			corner(row)
			label(row, other.DisplayName, UDim2.new(0.45, 0, 1, 0), UDim2.fromOffset(8, 0), 14, TEXT).TextXAlignment = Enum.TextXAlignment.Left
			local body = button(row, "ТЕЛО", UDim2.new(0.25, 0, 0, 36), UDim2.new(0.47, 0, 0, 8), PINK)
			local skin = button(row, "СКИН", UDim2.new(0.25, 0, 0, 36), UDim2.new(0.74, 0, 0, 8), CYAN)
			body.Activated:Connect(function() remotes.SwapAction:FireServer("Create", other.UserId) end)
			skin.Activated:Connect(function() remotes.TradeAction:FireServer("Create", other.UserId) end)
		end
	end
	if index == 0 then label(playerList, "Пока нет второго игрока. Для обмена нужен другой человек.", UDim2.new(1, 0, 0, 80), UDim2.new(), 16, MUTED) end
	playerList.CanvasSize = UDim2.fromOffset(0, math.max(80, index * 59))
end

local function refreshTradeInventory()
	for _, child in ipairs(ownSkins:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	local index = 0
	for _, id in ipairs(SkinCatalog.Order) do
		local skin = SkinCatalog.Skins[id]
		if profile.OwnedSkins[id] and skin.Tradable then
			index = index + 1
			local key = tradeSession and (tradeSession.Users.A == player.UserId and "A" or "B")
			local selected = tradeSession and tradeSession.Selected and tradeSession.Selected[key] == id
			local choice = button(ownSkins, (selected and "✓ " or "") .. skin.Name, UDim2.new(1, -8, 0, 40), UDim2.new(), selected and GOLD or PANEL)
			choice.LayoutOrder = index
			choice.Activated:Connect(function() remotes.TradeAction:FireServer("Select", id) end)
		end
	end
	ownSkins.CanvasSize = UDim2.fromOffset(0, math.max(44, index * 46))
end

local function refreshInventory()
	for _, child in ipairs(inventoryList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	for index, id in ipairs(SkinCatalog.Order) do
		local skin = SkinCatalog.Skins[id]
		local owned = profile.OwnedSkins[id] == true
		local row = new("Frame", { Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = owned and PANEL or INK, LayoutOrder = index }, inventoryList)
		corner(row)
		label(row, skin.Name .. "\n" .. skin.Description, UDim2.new(0.68, 0, 1, 0), UDim2.fromOffset(10, 3), 14, owned and skin.Accent or MUTED).TextXAlignment = Enum.TextXAlignment.Left
		local equip = button(row, not owned and "НЕ ОТКРЫТ" or (profile.EquippedSkin == id and "ВЫБРАН" or "НАДЕТЬ"), UDim2.new(0.27, 0, 0, 42), UDim2.new(0.71, 0, 0, 10), owned and skin.Secondary or INK)
		equip.Active = owned and profile.EquippedSkin ~= id and not player:GetAttribute("SwapActive")
		equip.AutoButtonColor = equip.Active
		equip.Activated:Connect(function() if equip.Active then remotes.InventoryAction:FireServer("Equip", id) end end)
	end
end

local function roleKey(session)
	if not session then return nil end
	if session.Users.A == player.UserId then return "A" elseif session.Users.B == player.UserId then return "B" end
	return nil
end

local function updateSwap()
	local key = roleKey(swapSession)
	acceptSwap.Visible, declineSwap.Visible, paySwap.Visible, cancelSwap.Visible, revertSwap.Visible = false, false, false, false, false
	if not swapSession or not key then
		swapTitle.Text = "ОБМЕН ПЕРСОНАЖАМИ"
		swapDescription.Text = "Нажмите ТЕЛО у игрока. После его согласия любой из вас сможет оплатить обмен. Вы получите управление телом другого на " .. Config.SwapDuration .. " секунд."
		swapTimer.Text = ""
		return
	end
	local otherKey = key == "A" and "B" or "A"
	local otherName = swapSession.Names[otherKey] or "партнёр"
	swapTitle.Text = "ВЫ ↔ " .. string.upper(otherName)
	swapDescription.Text = swapSession.State == "Pending" and (key == "B" and (otherName .. " предлагает обмен телами. Нужно ваше согласие.") or "Предложение отправлено. Ждём согласия " .. otherName .. ".")
		or swapSession.State == "Accepted" and "Согласие получено. Теперь любой из вас может нажать оплату. Платит только нажавший игрок."
		or swapSession.State == "PaymentPending" and "Ожидаем подтверждение покупки Roblox. Не создавайте вторую покупку."
		or "Обмен активен: вы управляете телом партнёра. Смерть, выход, возврат или таймер восстановят ваши аватары."
	local remaining = math.max(0, math.ceil((swapSession.ExpiresIn or 0) - (os.clock() - swapReceived)))
	swapTimer.Text = (swapSession.State == "Active" and "ДО ВОЗВРАТА: " or "ПРЕДЛОЖЕНИЕ: ") .. remaining .. " С"
	acceptSwap.Visible = swapSession.State == "Pending" and key == "B"
	declineSwap.Visible = acceptSwap.Visible
	paySwap.Visible = swapSession.State == "Accepted"
	cancelSwap.Visible = swapSession.State == "Pending" or swapSession.State == "Accepted"
	revertSwap.Visible = swapSession.State == "Active"
	paySwap.Text = swapSession.StudioTest and "TEST-ОБМЕН · БЕЗ ROBUX" or ("ОПЛАТИТЬ " .. Config.SwapRobuxPrice .. " R$ И ПОМЕНЯТЬСЯ")
	paySwap.Active = swapSession.StudioTest or Config.SwapProductId > 0
	paySwap.AutoButtonColor = paySwap.Active
	if not paySwap.Active then paySwap.Text = "DEVELOPER PRODUCT НЕ НАСТРОЕН" end
end

local function updateTrade()
	if not tradeSession or not roleKey(tradeSession) then
		tradeSummary.Text = "Нажмите СКИН у игрока. Каждый выбирает один собственный скин; повторное подтверждение обеих сторон выполняет одновременный обмен без копий."
		confirmTrade.Active = false
		confirmTrade.AutoButtonColor = false
		return
	end
	local key = roleKey(tradeSession)
	local otherKey = key == "A" and "B" or "A"
	local own = tradeSession.Selected[key] or "—"
	local other = tradeSession.Selected[otherKey] or "—"
	local ownName = own ~= "—" and SkinCatalog.Get(own).Name or "—"
	local otherName = other ~= "—" and SkinCatalog.Get(other).Name or "—"
	tradeSummary.Text = "ВЫ: " .. ownName .. (tradeSession.Confirmed[key] and " · ПОДТВЕРЖДЕНО" or "")
		.. "\n" .. (tradeSession.Names[otherKey] or "ПАРТНЁР") .. ": " .. otherName .. (tradeSession.Confirmed[otherKey] and " · ПОДТВЕРЖДЕНО" or "")
		.. "\nИзменение выбора сбрасывает оба подтверждения."
	confirmTrade.Active = own ~= "—" and other ~= "—" and not tradeSession.Confirmed[key]
	confirmTrade.AutoButtonColor = confirmTrade.Active
	confirmTrade.Text = tradeSession.Confirmed[key] and "ЖДЁМ ПАРТНЁРА" or "ПОДТВЕРДИТЬ ОБМЕН"
end

remotes.ProfileUpdate.OnClientEvent:Connect(function(data)
	profile = data
	refreshInventory()
	refreshTradeInventory()
end)
remotes.Notify.OnClientEvent:Connect(notify)
remotes.SwapFX.OnClientEvent:Connect(function(data)
	if data.Kind == "Ended" or data.Kind == "Cancelled" or data.Kind == "Declined" or data.Kind == "Expired" then
		swapSession = nil
	else
		swapSession = data
		swapReceived = os.clock()
		if data.Kind == "Offer" then showPage("Swap") end
	end
	updateSwap()
end)
remotes.TradeFX.OnClientEvent:Connect(function(data)
	if data.Kind == "Completed" then
		tradeSession = nil
		notify("Обмен завершён: " .. SkinCatalog.Get(data.Received).Name)
	elseif data.Kind == "Cancelled" or data.Kind == "Expired" then
		tradeSession = nil
	else
		tradeSession = data
		if data.Kind == "Started" then showPage("Trade") end
	end
	refreshTradeInventory()
	updateTrade()
end)
remotes.UIFX.OnClientEvent:Connect(function(data)
	if data.Kind == "OpenSwap" then showPage("Swap")
	elseif data.Kind == "OpenTrade" then showPage("Trade")
	elseif data.Kind == "OpenInventory" then showPage("Inventory") end
end)

local function bindCamera(character)
	if not character then return end
	task.defer(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local camera = Workspace.CurrentCamera
		if humanoid and camera and player.Character == character then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end)
end
player:GetPropertyChangedSignal("Character"):Connect(function() bindCamera(player.Character) end)
player.CharacterAdded:Connect(bindCamera)
if player.Character then bindCamera(player.Character) end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then showPage("Swap")
	elseif input.KeyCode == Enum.KeyCode.T then showPage("Trade")
	elseif input.KeyCode == Enum.KeyCode.I then showPage("Inventory") end
end)

local layoutClock, playerClock = 0, 0
RunService.RenderStepped:Connect(function(deltaTime)
	layoutClock = layoutClock + deltaTime
	playerClock = playerClock + deltaTime
	if playerClock >= 2 then playerClock = 0; refreshPlayers() end
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local compact = viewport.X < 700 or viewport.Y < 600
	if compact then
		playersFrame.Position = UDim2.fromOffset(12, 108)
		playersFrame.Size = UDim2.new(1, -24, 0, 220)
		dock.AnchorPoint = Vector2.new(0.5, 1)
		dock.Position = UDim2.new(0.5, 0, 1, -12)
		dock.Size = UDim2.new(1, -24, 0, 64)
		for index, object in ipairs({ swapButton, tradeButton, inventoryButton }) do
			object.Size = UDim2.new(1 / 3, -10, 0, 44)
			object.Position = UDim2.new((index - 1) / 3, 7, 0, 10)
		end
		swapButton.Text, tradeButton.Text, inventoryButton.Text = "ТЕЛА [B]", "СКИНЫ [T]", "ГАРДЕРОБ [I]"
	else
		playersFrame.Position = UDim2.fromOffset(12, 108)
		playersFrame.Size = UDim2.fromOffset(320, 342)
		dock.AnchorPoint = Vector2.new(1, 0)
		dock.Position = UDim2.new(1, -12, 0, 108)
		dock.Size = UDim2.fromOffset(240, 148)
		for index, object in ipairs({ swapButton, tradeButton, inventoryButton }) do
			object.Size = UDim2.new(1, -20, 0, 36)
			object.Position = UDim2.fromOffset(10, 10 + (index - 1) * 44)
		end
		swapButton.Text, tradeButton.Text, inventoryButton.Text = "ПОМЕНЯТЬСЯ ТЕЛАМИ [B]", "ОБМЕН СКИНАМИ [T]", "ГАРДЕРОБ [I]"
	end
	title.TextSize = compact and 18 or 25
	status.TextSize = compact and 12 or 15
	pairStatus.TextSize = compact and 14 or 18
	if compact then
		title.Size = UDim2.new(0.66, -16, 0, 36)
		status.Size = UDim2.new(0.66, -16, 0, 26)
		pairStatus.Size = UDim2.new(0.32, -18, 0, 60)
		pairStatus.Position = UDim2.new(0.68, 0, 0, 11)
	else
		title.Size = UDim2.new(0.58, -16, 0, 36)
		status.Size = UDim2.new(0.58, -16, 0, 26)
		pairStatus.Size = UDim2.new(0.4, -18, 0, 60)
		pairStatus.Position = UDim2.new(0.6, 0, 0, 11)
	end
	pairStatus.Text = player:GetAttribute("SwapActive") and (compact and "ЧУЖОЕ ТЕЛО\nB: ВОЗВРАТ" or "В ТЕЛЕ ПАРТНЁРА · B — ВОЗВРАТ") or "СВОЙ АВАТАР"
	status.Text = compact and ("Скинов " .. tostring(player:GetAttribute("OwnedSkinCount") or 1) .. " · Тела " .. tostring(player:GetAttribute("AvatarSwaps") or 0) .. " · Скины " .. tostring(player:GetAttribute("SkinTrades") or 0))
		or ("Скинов: " .. tostring(player:GetAttribute("OwnedSkinCount") or 1) .. " · Обменов телами: " .. tostring(player:GetAttribute("AvatarSwaps") or 0) .. " · Скинами: " .. tostring(player:GetAttribute("SkinTrades") or 0))
	toast.Position = compact and UDim2.new(0.1, 0, 1, -154) or UDim2.new(0.1, 0, 1, -74)
	if layoutClock >= 0.25 then layoutClock = 0; updateSwap(); updateTrade() end
end)

player:GetAttributeChangedSignal("SwapActive"):Connect(refreshInventory)
refreshPlayers()
refreshInventory()
refreshTradeInventory()
updateSwap()
updateTrade()
