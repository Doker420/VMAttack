-- BLOCKSIEGE // Level/score-gated PvE locations, separate from the 6v6 objective.
local ExpeditionCatalog = {}

ExpeditionCatalog.Order = { "VerdantBastion", "FrostFoundry", "EmberCitadel", "VoidObservatory" }
ExpeditionCatalog.MaxWaves = 3
ExpeditionCatalog.Items = {
	VerdantBastion = {
		Id = "VerdantBastion", Name = "VERDANT BASTION", Subtitle = "Тихий форпост · первая экспедиция",
		RequiredLevel = 1, RequiredWins = 0, Center = Vector3.new(-900, 0, 650),
		Color = Color3.fromRGB(91, 220, 164), Accent = Color3.fromRGB(255, 220, 113),
		EnemyName = "THORNLING", EnemyHealth = 90, EnemyDamage = 8, EnemySpeed = 10,
		BaseEnemies = 3, KillCoins = 3, KillXP = 8, RewardCoins = 60, RewardXP = 100,
	},
	FrostFoundry = {
		Id = "FrostFoundry", Name = "FROST FOUNDRY", Subtitle = "Ледяной завод · бронированные волны",
		RequiredLevel = 3, RequiredWins = 1, Center = Vector3.new(0, 0, 650),
		Color = Color3.fromRGB(111, 211, 255), Accent = Color3.fromRGB(195, 240, 255),
		EnemyName = "FROST DRONE", EnemyHealth = 150, EnemyDamage = 12, EnemySpeed = 11,
		BaseEnemies = 4, KillCoins = 4, KillXP = 11, RewardCoins = 100, RewardXP = 160,
	},
	EmberCitadel = {
		Id = "EmberCitadel", Name = "EMBER CITADEL", Subtitle = "Огненная цитадель · тяжёлые стражи",
		RequiredLevel = 5, RequiredWins = 2, Center = Vector3.new(900, 0, 650),
		Color = Color3.fromRGB(255, 133, 73), Accent = Color3.fromRGB(255, 216, 100),
		EnemyName = "EMBER GUARD", EnemyHealth = 230, EnemyDamage = 17, EnemySpeed = 12,
		BaseEnemies = 5, KillCoins = 5, KillXP = 15, RewardCoins = 150, RewardXP = 240,
	},
	VoidObservatory = {
		Id = "VoidObservatory", Name = "VOID OBSERVATORY", Subtitle = "Обсерватория · финальный PvE рейд",
		RequiredLevel = 8, RequiredWins = 4, Center = Vector3.new(0, 0, 1100),
		Color = Color3.fromRGB(190, 133, 255), Accent = Color3.fromRGB(102, 231, 255),
		EnemyName = "VOID WARDEN", EnemyHealth = 340, EnemyDamage = 23, EnemySpeed = 13,
		BaseEnemies = 6, KillCoins = 7, KillXP = 20, RewardCoins = 220, RewardXP = 360,
	},
}

function ExpeditionCatalog.Get(id)
	return type(id) == "string" and ExpeditionCatalog.Items[id] or nil
end

function ExpeditionCatalog.IsUnlocked(id, level, wins)
	local definition = ExpeditionCatalog.Get(id)
	return definition ~= nil and (tonumber(level) or 1) >= definition.RequiredLevel and (tonumber(wins) or 0) >= definition.RequiredWins
end

return ExpeditionCatalog
