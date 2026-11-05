-- BLOCKSIEGE // LIVE-OPS EVENT DEFINITIONS
-- Shared presentation data only. The server decides activation, rewards and damage.
local EventCatalog = {
	Schedule = {
		Period = 240,
		ActiveWindow = 45,
		CompletionCoins = 5,
		CompletionXP = 10,
		MinimumPresence = 10,
	},
	Order = { "SupplyStorm", "GoldRush", "RepairPulse", "MeteorMadness" },
}

EventCatalog.Events = {
	SupplyStorm = {
		Id = "SupplyStorm",
		Name = "ШТОРМ ПРИПАСОВ",
		ShortName = "SUPPLY STORM",
		Color = Color3.fromRGB(255, 199, 65),
		Duration = 45,
		Description = "Золотые ящики появляются в 3 раза чаще. Первая пара — сразу.",
		Announcement = "Снабжение уже падает на арену · ищи золотые лучи",
	},
	GoldRush = {
		Id = "GoldRush",
		Name = "ЗОЛОТАЯ ЛИХОРАДКА",
		ShortName = "GOLD RUSH ×2",
		Color = Color3.fromRGB(255, 102, 190),
		Duration = 45,
		Description = "×2 монеты и XP за бой, разрушения, 67 и бонусы. Итог матча не удваивается.",
		Announcement = "Сражайся, разрушай защиту, захватывай 67 и выполняй задания с ×2",
	},
	RepairPulse = {
		Id = "RepairPulse",
		Name = "ИМПУЛЬС ВОЗРОЖДЕНИЯ",
		ShortName = "REPAIR PULSE",
		Color = Color3.fromRGB(78, 239, 190),
		Duration = 45,
		Description = "Каждые 10 секунд обе команды получают лечение и ремонт построек.",
		Announcement = "Симметричный ремонт для Blue и Orange · уничтоженное не воскрешается",
	},
	MeteorMadness = {
		Id = "MeteorMadness",
		Name = "МЕТЕОРНЫЙ ХАОС",
		ShortName = "METEOR MADNESS",
		Color = Color3.fromRGB(163, 105, 255),
		Duration = 45,
		Description = "Телеграфируемые метеориты: уходи из круга. До 18 урона, минимум 1 HP.",
		Announcement = "Смотри на предупреждающие круги · ядра и постройки не повреждаются",
	},
}

function EventCatalog.Get(id)
	return type(id) == "string" and EventCatalog.Events[id] or nil
end

function EventCatalog.GetForSlot(slot)
	local index = math.floor(tonumber(slot) or 0) % #EventCatalog.Order + 1
	return EventCatalog.Events[EventCatalog.Order[index]]
end

return EventCatalog
