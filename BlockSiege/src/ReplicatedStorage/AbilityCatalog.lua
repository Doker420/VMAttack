-- BLOCKSIEGE // CLASS DRAFT
-- Server and client share this read-only content catalog. All numbers are
-- validated and executed by AbilityService; the client never applies effects.
local AbilityCatalog = {}

AbilityCatalog.ClassOrder = { "Medic", "Tank", "Striker", "Buffer", "Engineer" }

AbilityCatalog.Classes = {
	Medic = {
		Id = "Medic", Name = "ЛЕКАРЬ", Role = "HEALER",
		Color = Color3.fromRGB(93, 239, 174),
		Description = "Лечит отряд и вызывает дрона-санитара.",
		MaxHealthBonus = 10, ArmorBonus = 0, SpeedBonus = 0, DamageMultiplier = 1, BuildBonus = 0,
		Abilities = { "HealingPulse", "GuardianDrone" },
	},
	Tank = {
		Id = "Tank", Name = "ТАНК", Role = "DEFENDER",
		Color = Color3.fromRGB(103, 178, 255),
		Description = "Поглощает урон и разбивает строй противника.",
		MaxHealthBonus = 70, ArmorBonus = 0.12, SpeedBonus = 0, DamageMultiplier = 1, BuildBonus = 0,
		Abilities = { "AegisShield", "SeismicSlam" },
	},
	Striker = {
		Id = "Striker", Name = "ДАМАГЕР", Role = "ASSAULT",
		Color = Color3.fromRGB(255, 125, 104),
		Description = "Усиливает оружие и бросает кассетную бомбу.",
		MaxHealthBonus = 0, ArmorBonus = 0, SpeedBonus = 0, DamageMultiplier = 1.12, BuildBonus = 0,
		Abilities = { "Overdrive", "ClusterBomb" },
	},
	Buffer = {
		Id = "Buffer", Name = "БАФФЕР", Role = "SUPPORT",
		Color = Color3.fromRGB(206, 150, 255),
		Description = "Ускоряет союзников и чинит крепость.",
		MaxHealthBonus = 0, ArmorBonus = 0, SpeedBonus = 2, DamageMultiplier = 1, BuildBonus = 0,
		Abilities = { "RallyBanner", "RepairPulse" },
	},
	Engineer = {
		Id = "Engineer", Name = "ИНЖЕНЕР", Role = "ENGINEER",
		Color = Color3.fromRGB(255, 209, 99),
		Description = "Строит минные поля и автоматические турели.",
		MaxHealthBonus = 0, ArmorBonus = 0, SpeedBonus = 0, DamageMultiplier = 1, BuildBonus = 3,
		Abilities = { "Minefield", "SentryTurret" },
	},
}

AbilityCatalog.Abilities = {
	HealingPulse = {
		Id = "HealingPulse", Name = "ИСЦЕЛЯЮЩИЙ ПУЛЬС", ShortName = "ПУЛЬС",
		Description = "Восстанавливает 50 HP союзникам в радиусе 26.",
		Kind = "Heal", Cooldown = 12, Range = 48, Radius = 26, Amount = 50,
		Color = Color3.fromRGB(93, 239, 174), Hotkey = "F",
	},
	GuardianDrone = {
		Id = "GuardianDrone", Name = "ДРОН-САНИТАР", ShortName = "ДРОН",
		Description = "12 секунд сопровождает вас и лечит союзников рядом.",
		Kind = "Drone", Cooldown = 28, Duration = 12, Radius = 20, HealPerSecond = 8,
		Color = Color3.fromRGB(93, 239, 174), Hotkey = "G",
	},
	AegisShield = {
		Id = "AegisShield", Name = "ЭГИДА", ShortName = "ЩИТ",
		Description = "6 секунд уменьшает входящий урон до 42%.",
		Kind = "Shield", Cooldown = 18, Duration = 6, DamageTakenMultiplier = 0.42,
		Color = Color3.fromRGB(103, 178, 255), Hotkey = "F",
	},
	SeismicSlam = {
		Id = "SeismicSlam", Name = "СЕЙСМИЧЕСКИЙ УДАР", ShortName = "УДАР",
		Description = "Наносит 65 урона врагам в радиусе 18.",
		Kind = "Slam", Cooldown = 14, Range = 28, Radius = 18, Amount = 65,
		Color = Color3.fromRGB(103, 178, 255), Hotkey = "G",
	},
	Overdrive = {
		Id = "Overdrive", Name = "ОВЕРДРАЙВ", ShortName = "РАЗГОН",
		Description = "8 секунд увеличивает урон оружия и способностей на 45%.",
		Kind = "Overdrive", Cooldown = 22, Duration = 8, DamageMultiplier = 1.45,
		Color = Color3.fromRGB(255, 125, 104), Hotkey = "F",
	},
	ClusterBomb = {
		Id = "ClusterBomb", Name = "КАССЕТНАЯ БОМБА", ShortName = "БОМБА",
		Description = "Бросок по дуге: 100 урона в радиусе 16.",
		Kind = "Bomb", Cooldown = 18, Range = 95, Radius = 16, Amount = 100, FlightTime = 0.85,
		Color = Color3.fromRGB(255, 125, 104), Hotkey = "G",
	},
	RallyBanner = {
		Id = "RallyBanner", Name = "ЗНАМЯ РАЛЛИ", ShortName = "ЗНАМЯ",
		Description = "10 секунд: союзники рядом получают +20% урона и +5 скорости.",
		Kind = "Rally", Cooldown = 24, Range = 36, Radius = 32, Duration = 10,
		DamageMultiplier = 1.2, SpeedBonus = 5,
		Color = Color3.fromRGB(206, 150, 255), Hotkey = "F",
	},
	RepairPulse = {
		Id = "RepairPulse", Name = "РЕМОНТНЫЙ ПУЛЬС", ShortName = "РЕМОНТ",
		Description = "Лечит союзников и восстанавливает 240 HP постройкам.",
		Kind = "Repair", Cooldown = 16, Range = 55, Radius = 28, Amount = 35, StructureAmount = 240,
		Color = Color3.fromRGB(206, 150, 255), Hotkey = "G",
	},
	Minefield = {
		Id = "Minefield", Name = "МИННОЕ ПОЛЕ", ShortName = "МИНЫ",
		Description = "Устанавливает 3 мины: 85 урона, радиус взрыва 13.",
		Kind = "Minefield", Cooldown = 22, Range = 65, Radius = 13, TriggerRadius = 6,
		Amount = 85, Count = 3, Duration = 50,
		Color = Color3.fromRGB(255, 209, 99), Hotkey = "F",
	},
	SentryTurret = {
		Id = "SentryTurret", Name = "СТРАЖЕВАЯ ТУРЕЛЬ", ShortName = "ТУРЕЛЬ",
		Description = "35 секунд автоматически поражает врагов в радиусе 80.",
		Kind = "Turret", Cooldown = 34, Range = 70, Duration = 35, AttackRange = 80,
		Amount = 16, ShotCooldown = 1.1,
		Color = Color3.fromRGB(255, 209, 99), Hotkey = "G",
	},
}

function AbilityCatalog.GetClass(classId)
	return type(classId) == "string" and AbilityCatalog.Classes[classId] or nil
end

function AbilityCatalog.GetAbility(abilityId)
	return type(abilityId) == "string" and AbilityCatalog.Abilities[abilityId] or nil
end

function AbilityCatalog.GetAbilityForSlot(classId, slot)
	local definition = AbilityCatalog.GetClass(classId)
	local abilityId = definition and definition.Abilities[slot]
	return abilityId and AbilityCatalog.GetAbility(abilityId) or nil
end

function AbilityCatalog.GetClassForAbility(abilityId)
	for classId, definition in pairs(AbilityCatalog.Classes) do
		for _, id in ipairs(definition.Abilities) do
			if id == abilityId then
				return classId
			end
		end
	end
	return nil
end

return AbilityCatalog
