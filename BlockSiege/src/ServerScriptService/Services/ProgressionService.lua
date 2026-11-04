-- Persistent character progression, lobby upgrades, daily rewards and cosmetic loadout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local ProgressionService = {}
local DataService
local weaponService
local remotes

local function notify(player, text, color)
	if remotes and player.Parent then
		remotes.Notify:FireClient(player, text, color)
	end
end

local function getLevel(data)
	return data and Catalog.LevelForXP(data.XP) or 1
end

function ProgressionService.Init(dependencies)
	DataService = dependencies.DataService
	weaponService = dependencies.WeaponService
	remotes = dependencies.Remotes
end

function ProgressionService.GetStats(player)
	local data = DataService and DataService.Get(player)
	local upgrades = data and data.Upgrades or {}
	local speed = upgrades.Speed or 0
	local health = upgrades.Health or 0
	local armor = upgrades.Armor or 0
	local engineering = upgrades.Engineering or 0
	return {
		Level = getLevel(data),
		Speed = 20 + speed,
		MaxHealth = 120 + health * 15,
		Armor = armor * 0.04,
		BuildCapacity = Config.Arena.MaxBuildPerPlayer + engineering * 2,
		SpeedLevel = speed,
		HealthLevel = health,
		ArmorLevel = armor,
		EngineeringLevel = engineering,
	}
end

local function removeNamed(parent, name)
	local child = parent and parent:FindFirstChild(name)
	if child then
		child:Destroy()
	end
end

function ProgressionService.ClearEffects(character)
	if not character then
		return
	end
	removeNamed(character, "BLOCKSIEGE_Aura")
	removeNamed(character, "BLOCKSIEGE_Trail")
	removeNamed(character, "BLOCKSIEGE_TrailAttachment0")
	removeNamed(character, "BLOCKSIEGE_TrailAttachment1")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		removeNamed(root, "BLOCKSIEGE_Aura")
		removeNamed(root, "BLOCKSIEGE_AuraLight")
		removeNamed(root, "BLOCKSIEGE_Trail")
		removeNamed(root, "BLOCKSIEGE_TrailAttachment0")
		removeNamed(root, "BLOCKSIEGE_TrailAttachment1")
	end
	local head = character:FindFirstChild("Head")
	if head then
		removeNamed(head, "BLOCKSIEGE_TrailAttachment0")
		removeNamed(head, "BLOCKSIEGE_TrailAttachment1")
	end
end

local function applyCosmetics(player, character)
	ProgressionService.ClearEffects(character)
	local data = DataService and DataService.Get(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	local selected = data.SelectedCosmetics or {}
	if selected.Aura and selected.Aura ~= "Default" and data.OwnedCosmetics[selected.Aura] then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "BLOCKSIEGE_Aura"
		aura.Rate = 12
		aura.Lifetime = NumberRange.new(0.45, 0.9)
		aura.Speed = NumberRange.new(0.4, 1.2)
		aura.Size = NumberSequence.new(0.22, 0)
		aura.Color = ColorSequence.new(Color3.fromRGB(102, 220, 255), Color3.fromRGB(177, 82, 255))
		aura.LightEmission = 0.8
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Parent = root
		local light = Instance.new("PointLight")
		light.Name = "BLOCKSIEGE_AuraLight"
		light.Color = Color3.fromRGB(133, 104, 255)
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = root
	end
	if selected.Trail and selected.Trail ~= "Default" and data.OwnedCosmetics[selected.Trail] then
		local head = character:FindFirstChild("Head") or root
		local attachment0 = Instance.new("Attachment")
		attachment0.Name = "BLOCKSIEGE_TrailAttachment0"
		attachment0.Parent = root
		local attachment1 = Instance.new("Attachment")
		attachment1.Name = "BLOCKSIEGE_TrailAttachment1"
		attachment1.Position = Vector3.new(0, 1.5, 0)
		attachment1.Parent = head
		local trail = Instance.new("Trail")
		trail.Name = "BLOCKSIEGE_Trail"
		trail.Attachment0 = attachment0
		trail.Attachment1 = attachment1
		trail.Lifetime = 0.35
		trail.WidthScale = NumberSequence.new(0.55, 0)
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 213, 82), Color3.fromRGB(255, 135, 45))
		trail.LightEmission = 0.65
		trail.Parent = root
	end
end

function ProgressionService.ApplyCharacter(player, character, preserveHealth)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local stats = ProgressionService.GetStats(player)
	local previousHealth = humanoid.Health
	humanoid.WalkSpeed = stats.Speed
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = preserveHealth and math.min(previousHealth, stats.MaxHealth) or stats.MaxHealth
	character:SetAttribute("Level", stats.Level)
	character:SetAttribute("MaxHP", stats.MaxHealth)
	character:SetAttribute("Armor", stats.Armor)
	character:SetAttribute("BuildCapacity", stats.BuildCapacity)
	player:SetAttribute("BuildCapacity", stats.BuildCapacity)
	player:SetAttribute("MaxHP", stats.MaxHealth)
	player:SetAttribute("Armor", stats.Armor)
	character:SetAttribute("SpeedBonus", stats.Speed - 20)
	applyCosmetics(player, character)
end

function ProgressionService.Refresh(player)
	if player.Character then
		ProgressionService.ApplyCharacter(player, player.Character, true)
	end
	if weaponService and player.Character then
		weaponService.EquipPlayer(player)
	end
	if DataService then
		DataService.Commit(player)
	end
end

function ProgressionService.Upgrade(player, id)
	local data = DataService and DataService.Get(player)
	local definition = Catalog.GetUpgrade(id)
	if not data or not definition then
		return false
	end
	if player:GetAttribute("InMatch") == true then
		notify(player, "Улучшения доступны в лобби", Color3.fromRGB(255, 180, 90))
		return false
	end
	local current = data.Upgrades[id] or 0
	if current >= definition.MaxLevel then
		notify(player, "Этот навык уже на максимуме", Color3.fromRGB(130, 220, 255))
		return false
	end
	local nextLevel = current + 1
	local requiredLevel = definition.RequiredLevels[nextLevel] or 1
	if getLevel(data) < requiredLevel then
		notify(player, "Нужен уровень " .. requiredLevel, Color3.fromRGB(255, 180, 90))
		return false
	end
	local cost = definition.Costs[nextLevel]
	if data.Coins < cost then
		notify(player, "Недостаточно монет: нужно " .. cost, Color3.fromRGB(255, 110, 100))
		return false
	end
	data.Coins = data.Coins - cost
	data.Upgrades[id] = nextLevel
	DataService.Commit(player, true)
	ProgressionService.Refresh(player)
	notify(player, definition.Name .. " · уровень " .. nextLevel, Color3.fromRGB(120, 255, 180))
	return true
end

function ProgressionService.ClaimDaily(player)
	local data = DataService and DataService.Get(player)
	if not data then
		return false
	end
	local now = os.time()
	local elapsed = now - (data.LastDailyClaim or 0)
	if elapsed < Config.DailyCooldown then
		local minutes = math.ceil((Config.DailyCooldown - elapsed) / 60)
		notify(player, "Ежедневный бонус через " .. minutes .. " мин", Color3.fromRGB(255, 190, 100))
		return false
	end
	local level = getLevel(data)
	local coins = 50 + level * 5
	data.Coins = data.Coins + coins
	data.XP = data.XP + 20
	data.CaseTokens = data.CaseTokens + 1
	data.LastDailyClaim = now
	DataService.Commit(player, true)
	notify(player, "Ежедневный бонус: +" .. coins .. " монет, +20 XP и жетон кейса", Color3.fromRGB(120, 255, 190))
	return true, { Coins = coins, XP = 20, CaseTokens = 1 }
end

function ProgressionService.CanBuildDefense(player, kind)
	local definition = Catalog.GetDefense(kind)
	if not definition then
		return true
	end
	local data = DataService and DataService.Get(player)
	return data ~= nil and data.OwnedDefenses[kind] == true
end

function ProgressionService.BuyDefense(player, id)
	local data = DataService and DataService.Get(player)
	local definition = Catalog.GetDefense(id)
	if not data or not definition then
		return false
	end
	if player:GetAttribute("InMatch") == true then
		notify(player, "Чертежи покупаются в лобби", Color3.fromRGB(255, 180, 90))
		return false
	end
	if data.OwnedDefenses[id] then
		notify(player, "Чертёж уже куплен", Color3.fromRGB(130, 220, 255))
		return false
	end
	if getLevel(data) < definition.RequiredLevel then
		notify(player, "Нужен уровень " .. definition.RequiredLevel, Color3.fromRGB(255, 180, 90))
		return false
	end
	if data.Coins < definition.Price then
		notify(player, "Недостаточно монет: нужно " .. definition.Price, Color3.fromRGB(255, 110, 100))
		return false
	end
	data.Coins = data.Coins - definition.Price
	data.OwnedDefenses[id] = true
	DataService.Commit(player, true)
	notify(player, "Чертёж куплен: " .. definition.Name, Color3.fromRGB(120, 255, 180))
	return true
end

function ProgressionService.EquipCosmetic(player, id)
	local data = DataService and DataService.Get(player)
	local cosmetic = Catalog.GetCosmetic(id)
	if not data or not cosmetic or not data.OwnedCosmetics[id] then
		return false
	end
	data.SelectedCosmetics[cosmetic.Slot] = id
	DataService.Commit(player, true)
	ProgressionService.Refresh(player)
	notify(player, "Экипировано: " .. cosmetic.Name, Color3.fromRGB(190, 150, 255))
	return true
end

function ProgressionService.HandleAction(player, action, value)
	if action == "Upgrade" then
		return ProgressionService.Upgrade(player, value)
	elseif action == "Daily" then
		return ProgressionService.ClaimDaily(player)
	elseif action == "BuyDefense" then
		return ProgressionService.BuyDefense(player, value)
	elseif action == "EquipCosmetic" then
		return ProgressionService.EquipCosmetic(player, value)
	elseif action == "Refresh" then
		ProgressionService.Refresh(player)
		return true
	end
	return false
end

return ProgressionService
