-- Оружие и честные игровые кейсы. Случайные награды нельзя купить за Robux.
local Catalog = {}

Catalog.WeaponOrder = { "Carbine", "SMG", "Scatter", "Marksman", "Demolisher", "Rail", "Vortex" }
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
		Id = "Scatter", Name = "VOXEL SCATTER", Rarity = "Common", Model = "Scatter",
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
		Rare = { "Marksman", "Demolisher" },
		Legendary = { "Rail", "Vortex" },
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

-- Только косметика за Robux: никаких преимуществ в уроне, скорости или броне.
Catalog.CosmeticOrder = { "GoldenArsenal", "AuroraAura", "RoyalTrail" }
Catalog.Cosmetics = {
	GoldenArsenal = { Name = "GOLDEN ARSENAL", GamePassId = 0, RobuxPrice = 99, Slot = "WeaponSkin", Description = "Золотые детали и свечение всего оружия" },
	AuroraAura = { Name = "AURORA CORE", GamePassId = 0, RobuxPrice = 79, Slot = "Aura", Description = "Фиолетово-синяя аура и искры персонажа" },
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

return Catalog
