-- Оружие и честные игровые кейсы. Случайные награды нельзя купить за Robux.
local Catalog = {}

Catalog.WeaponOrder = { "Carbine", "SMG", "Scatter", "Marksman", "Demolisher", "Rail", "Vortex", "ThanosGauntlet", "TacticalKnife", "ShadowKnives", "PrismLance", "TeslaCarbine", "MeteorMaul", "VoidScythe" }
Catalog.Weapons = {
	Carbine = {
		Id = "Carbine", Name = "BLOCK CARBINE", Rarity = "Starter", Model = "Carbine",
		Damage = 16, Cooldown = 0.16, Range = 145, Spread = 0.012, Pellets = 1, StructureMultiplier = 1.1,
		Color = Color3.fromRGB(74, 169, 207),
	},
	SMG = {
		Id = "SMG", Name = "RAPID SMG", Rarity = "Common", Model = "SMG",
		Damage = 10, Cooldown = 0.09, Range = 112, Spread = 0.028, Pellets = 1, StructureMultiplier = 0.85,
		Color = Color3.fromRGB(102, 190, 130),
	},
	Scatter = {
		Id = "Scatter", Name = "SCATTERGUN", Rarity = "Common", Model = "Scatter",
		Damage = 8, Cooldown = 0.82, Range = 72, Spread = 0.075, Pellets = 7, StructureMultiplier = 0.8,
		Color = Color3.fromRGB(126, 194, 117),
	},
	Marksman = {
		Id = "Marksman", Name = "LONGSHOT", Rarity = "Rare", Model = "Marksman",
		Damage = 42, Cooldown = 0.65, Range = 225, Spread = 0.002, Pellets = 1, StructureMultiplier = 1.25,
		Color = Color3.fromRGB(75, 131, 220),
	},
	Demolisher = {
		Id = "Demolisher", Name = "DEMOLISHER", Rarity = "Rare", Model = "Demolisher",
		Damage = 28, Cooldown = 0.55, Range = 125, Spread = 0.018, Pellets = 1, StructureMultiplier = 2.25,
		Color = Color3.fromRGB(91, 121, 205),
	},
	Rail = {
		Id = "Rail", Name = "FORTRESS RAIL", Rarity = "Legendary", Model = "Rail",
		Damage = 85, Cooldown = 1.25, Range = 265, Spread = 0, Pellets = 1, StructureMultiplier = 1.8,
		Color = Color3.fromRGB(241, 178, 54),
	},
	Vortex = {
		Id = "Vortex", Name = "VORTEX REPEATER", Rarity = "Legendary", Model = "Vortex",
		Damage = 22, Cooldown = 0.22, Range = 165, Spread = 0.01, Pellets = 1, StructureMultiplier = 1.5,
		Color = Color3.fromRGB(235, 112, 51),
	},
	ThanosGauntlet = {
		Id = "ThanosGauntlet", Name = "THANOS GAUNTLET · SNIPER", Rarity = "Legendary", Model = "Gauntlet",
		Damage = 120, Cooldown = 1.6, Range = 320, Spread = 0, Pellets = 1, StructureMultiplier = 2,
		Color = Color3.fromRGB(232, 184, 55),
	},
	TacticalKnife = {
		Id = "TacticalKnife", Name = "TACTICAL KNIFE", Rarity = "Rare", Model = "Knife",
		Damage = 58, Cooldown = 0.42, Range = 14, Spread = 0, Pellets = 1, StructureMultiplier = 0.65, Melee = true,
		Color = Color3.fromRGB(107, 224, 220),
	},
	ShadowKnives = {
		Id = "ShadowKnives", Name = "SHADOW DUAL KNIVES", Rarity = "Legendary", Model = "DualKnives",
		Damage = 82, Cooldown = 0.65, Range = 16, Spread = 0, Pellets = 1, StructureMultiplier = 0.8, Melee = true,
		Color = Color3.fromRGB(186, 104, 255),
	},
	PrismLance = {
		Id = "PrismLance", Name = "PRISM LANCE", Rarity = "Legendary", Model = "PrismLance",
		Damage = 72, Cooldown = 0.85, Range = 245, Spread = 0.001, Pellets = 1, StructureMultiplier = 1.65,
		Color = Color3.fromRGB(113, 224, 255),
	},
	TeslaCarbine = {
		Id = "TeslaCarbine", Name = "TESLA CARBINE", Rarity = "Rare", Model = "TeslaCarbine",
		Damage = 18, Cooldown = 0.18, Range = 135, Spread = 0.014, Pellets = 1, StructureMultiplier = 1.05,
		Color = Color3.fromRGB(102, 239, 255),
	},
	MeteorMaul = {
		Id = "MeteorMaul", Name = "METEOR MAUL", Rarity = "Rare", Model = "MeteorMaul",
		Damage = 96, Cooldown = 1.05, Range = 18, Spread = 0, Pellets = 1, StructureMultiplier = 3, Melee = true,
		Color = Color3.fromRGB(255, 119, 54),
	},
	VoidScythe = {
		Id = "VoidScythe", Name = "VOID SCYTHE", Rarity = "Legendary", Model = "VoidScythe",
		Damage = 110, Cooldown = 0.9, Range = 19, Spread = 0, Pellets = 1, StructureMultiplier = 1.4, Melee = true,
		Color = Color3.fromRGB(184, 101, 255),
	},
}

Catalog.RarityNames = { Starter = "СТАРТОВОЕ", Common = "ОБЫЧНОЕ", Rare = "РЕДКОЕ", Legendary = "ЛЕГЕНДАРНОЕ" }
Catalog.RarityColors = {
	Starter = Color3.fromRGB(180, 190, 188),
	Common = Color3.fromRGB(102, 190, 130),
	Rare = Color3.fromRGB(75, 131, 220),
	Legendary = Color3.fromRGB(241, 178, 54),
}

Catalog.Case = {
	CoinPrice = 25,
	TokenPrice = 1,
	LegendaryPity = 20,
	Pool = {
		Common = { "SMG", "Scatter" },
		Rare = { "Marksman", "Demolisher", "TacticalKnife", "TeslaCarbine", "MeteorMaul" },
		Legendary = { "Rail", "Vortex", "ThanosGauntlet", "ShadowKnives", "PrismLance", "VoidScythe" },
	},
	DuplicateCoins = { Common = 8, Rare = 18, Legendary = 40 },
}

Catalog.UpgradeOrder = { "Speed", "Health", "Armor", "Engineering" }
Catalog.Upgrades = {
	Speed = { Name = "СКОРОСТЬ", MaxLevel = 5, Costs = { 30, 60, 100, 150, 220 }, RequiredLevels = { 1, 2, 3, 4, 5 }, Description = "+1 к скорости передвижения за уровень" },
	Health = { Name = "ЗДОРОВЬЕ", MaxLevel = 5, Costs = { 35, 70, 115, 170, 240 }, RequiredLevels = { 1, 2, 3, 4, 5 }, Description = "+15 к максимальному HP за уровень" },
	Armor = { Name = "БРОНЯ", MaxLevel = 5, Costs = { 45, 85, 135, 200, 280 }, RequiredLevels = { 2, 3, 4, 5, 6 }, Description = "4% сопротивления урону за уровень" },
	Engineering = { Name = "ИНЖЕНЕРИЯ", MaxLevel = 3, Costs = { 40, 90, 160 }, RequiredLevels = { 1, 3, 5 }, Description = "+2 дополнительные постройки за уровень" },
}

-- Оборонительные чертежи покупаются только за заработанные монеты, не за Robux.
Catalog.DefenseOrder = { "SpikeTrap", "ShockMine", "FlameTrap" }
Catalog.Defenses = {
	SpikeTrap = { Name = "SPIKE TRAP", Price = 60, RequiredLevel = 1, Description = "35 урона и повторное срабатывание каждые 2 секунды" },
	ShockMine = { Name = "SHOCK MINE", Price = 90, RequiredLevel = 2, Description = "70 урона по области, одноразовая мина" },
	FlameTrap = { Name = "FLAME TRAP", Price = 120, RequiredLevel = 3, Description = "24 урона огнём каждые 1,5 секунды" },
}

-- Visible account-level track. Case drops can unlock items earlier; duplicate
-- track rewards are converted into coins by DataService instead of wasted.
Catalog.LevelRewardOrder = { 2, 3, 4, 5, 6, 7, 8, 9, 10 }
Catalog.LevelRewards = {
	[2] = { Weapon = "SMG", Coins = 50, CaseTokens = 1, Description = "RAPID SMG · 50 монет · жетон" },
	[3] = { Defense = "SpikeTrap", Coins = 75, Description = "SPIKE TRAP · 75 монет" },
	[4] = { Weapon = "TacticalKnife", Coins = 100, Description = "TACTICAL KNIFE · 100 монет" },
	[5] = { Weapon = "Scatter", CaseTokens = 1, Description = "SCATTERGUN · жетон кейса" },
	[6] = { Weapon = "TeslaCarbine", Coins = 150, Description = "TESLA CARBINE · 150 монет" },
	[7] = { Weapon = "Marksman", CaseTokens = 1, Description = "LONGSHOT · жетон кейса" },
	[8] = { Weapon = "ShadowKnives", Coins = 200, Description = "SHADOW DUAL KNIVES · 200 монет" },
	[9] = { Weapon = "PrismLance", CaseTokens = 2, Description = "PRISM LANCE · 2 жетона" },
	[10] = { Weapon = "ThanosGauntlet", Coins = 500, Description = "THANOS GAUNTLET · SNIPER · 500 монет" },
}

function Catalog.GetLevelReward(level)
	return Catalog.LevelRewards[tonumber(level) or -1]
end

function Catalog.GetNextLevelReward(level)
	for _, rewardLevel in ipairs(Catalog.LevelRewardOrder) do
		if rewardLevel > level then
			return rewardLevel, Catalog.LevelRewards[rewardLevel]
		end
	end
	return nil
end

-- Three different bonus missions are drafted for every participant each match.
-- Server progress is mirrored to attributes; the client never grants these rewards.
Catalog.BonusMissionOrder = { "Fortifier", "Siege", "Captain", "ClassAct", "Hunter", "Eliminator" }
Catalog.BonusMissions = {
	Fortifier = { Id = "Fortifier", Name = "УКРЕПИТЕЛЬ", Action = "Build", Target = 3, Coins = 15, XP = 30, Hint = "Поставь 3 укрепления" },
	Siege = { Id = "Siege", Name = "РАЗРУШИТЕЛЬ", Action = "Structure", Target = 2, Coins = 20, XP = 40, Hint = "Разруши 2 вражеских сооружения" },
	Captain = { Id = "Captain", Name = "ЗАХВАТЧИК", Action = "Capture", Target = 1, Coins = 15, XP = 30, Hint = "Захвати точку 67" },
	ClassAct = { Id = "ClassAct", Name = "СПЕЦИАЛИСТ", Action = "Ability", Target = 3, Coins = 15, XP = 35, Hint = "Примени F/G трижды" },
	Hunter = { Id = "Hunter", Name = "ЕГЕРЬ", Action = "Camp", Target = 2, Coins = 20, XP = 40, Hint = "Очисти 2 лагеря в джунглях" },
	Eliminator = { Id = "Eliminator", Name = "ДУЭЛЯНТ", Action = "Kill", Target = 3, Coins = 20, XP = 40, Hint = "Выведи 3 бойцов из боя" },
}

function Catalog.GetBonusMission(id)
	return type(id) == "string" and Catalog.BonusMissions[id] or nil
end

function Catalog.GetDefense(id)
	return type(id) == "string" and Catalog.Defenses[id] or nil
end

-- Только косметика за Robux: никаких преимуществ в уроне, скорости или броне.
Catalog.CosmeticOrder = { "GoldenArsenal", "CelestialArsenal", "AuroraAura", "PhoenixAura", "RoyalTrail" }
Catalog.Cosmetics = {
	GoldenArsenal = { Name = "GOLDEN ARSENAL", GamePassId = 0, RobuxPrice = 99, Slot = "WeaponSkin", Description = "Золотые детали и свечение всего оружия" },
	CelestialArsenal = { Name = "LEGENDARY // CELESTIAL ARSENAL", GamePassId = 0, RobuxPrice = 199, Slot = "WeaponSkin", Description = "Легендарный celestial-metal и cyan glow · только внешний вид" },
	AuroraAura = { Name = "AURORA CORE", GamePassId = 0, RobuxPrice = 79, Slot = "Aura", Description = "Фиолетово-синяя аура и искры персонажа" },
	PhoenixAura = { Name = "LEGENDARY // PHOENIX AURA", GamePassId = 0, RobuxPrice = 149, Slot = "Aura", Description = "Оранжево-розовое legendary свечение · без боевых бонусов" },
	RoyalTrail = { Name = "ROYAL TRAIL", GamePassId = 0, RobuxPrice = 49, Slot = "Trail", Description = "Золотой след при движении" },
}

function Catalog.GetUpgrade(id)
	return type(id) == "string" and Catalog.Upgrades[id] or nil
end

function Catalog.GetCosmetic(id)
	return type(id) == "string" and Catalog.Cosmetics[id] or nil
end

function Catalog.GetWeapon(id)
	if type(id) ~= "string" then
		return nil
	end
	return Catalog.Weapons[id]
end

function Catalog.LevelForXP(xp)
	return math.max(1, math.floor(math.sqrt(math.max(0, xp) / 80)) + 1)
end

function Catalog.LevelProgress(xp)
	local totalXP = math.max(0, math.floor(tonumber(xp) or 0))
	local level = Catalog.LevelForXP(totalXP)
	local levelStart = 80 * (level - 1) ^ 2
	local nextLevelXP = 80 * level ^ 2
	return level, totalXP - levelStart, nextLevelXP - levelStart, nextLevelXP
end

return Catalog
