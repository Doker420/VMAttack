-- Собственные внутриигровые скины. Это не передаваемые Roblox avatar items.
local SkinCatalog = {}

SkinCatalog.Order = { "Default", "Citrus", "Ocean", "Berry", "Lime", "Midnight", "Sunset", "Crystal" }
SkinCatalog.StarterPool = { "Citrus", "Ocean", "Berry", "Lime", "Midnight", "Sunset", "Crystal" }

SkinCatalog.Skins = {
	Default = {
		Id = "Default", Name = "СВОЙ СТИЛЬ", Description = "Исходные цвета аватара без дополнительной сборки.",
		Primary = Color3.fromRGB(210, 215, 220), Secondary = Color3.fromRGB(130, 140, 150), Accent = Color3.fromRGB(255, 255, 255),
		Accessory = "None", Tradable = false,
	},
	Citrus = {
		Id = "Citrus", Name = "ЦИТРУС", Description = "Тёплая палитра и объёмный рюкзак.",
		Primary = Color3.fromRGB(255, 190, 62), Secondary = Color3.fromRGB(245, 116, 65), Accent = Color3.fromRGB(255, 236, 145),
		Accessory = "Pack", Tradable = true,
	},
	Ocean = {
		Id = "Ocean", Name = "ОКЕАН", Description = "Синие тона и сегментированная накидка.",
		Primary = Color3.fromRGB(70, 165, 232), Secondary = Color3.fromRGB(42, 91, 160), Accent = Color3.fromRGB(117, 239, 244),
		Accessory = "Cape", Tradable = true,
	},
	Berry = {
		Id = "Berry", Name = "ЯГОДА", Description = "Яркая палитра и парные крылья.",
		Primary = Color3.fromRGB(221, 84, 161), Secondary = Color3.fromRGB(116, 65, 157), Accent = Color3.fromRGB(255, 167, 219),
		Accessory = "Wings", Tradable = true,
	},
	Lime = {
		Id = "Lime", Name = "ЛАЙМ", Description = "Свежие цвета и светящийся визор.",
		Primary = Color3.fromRGB(137, 218, 82), Secondary = Color3.fromRGB(43, 133, 96), Accent = Color3.fromRGB(213, 255, 130),
		Accessory = "Visor", Tradable = true,
	},
	Midnight = {
		Id = "Midnight", Name = "ПОЛНОЧЬ", Description = "Графит, индиго и orbital-сферы.",
		Primary = Color3.fromRGB(54, 60, 91), Secondary = Color3.fromRGB(29, 34, 55), Accent = Color3.fromRGB(139, 117, 255),
		Accessory = "Orbit", Tradable = true,
	},
	Sunset = {
		Id = "Sunset", Name = "ЗАКАТ", Description = "Коралловые тона и сегментированное halo.",
		Primary = Color3.fromRGB(246, 123, 99), Secondary = Color3.fromRGB(156, 66, 104), Accent = Color3.fromRGB(255, 208, 112),
		Accessory = "Halo", Tradable = true,
	},
	Crystal = {
		Id = "Crystal", Name = "КРИСТАЛЛ", Description = "Холодная палитра и собственная crown-сборка.",
		Primary = Color3.fromRGB(159, 226, 237), Secondary = Color3.fromRGB(92, 125, 176), Accent = Color3.fromRGB(224, 252, 255),
		Accessory = "Crown", Tradable = true,
	},
}

function SkinCatalog.Get(id)
	return type(id) == "string" and SkinCatalog.Skins[id] or nil
end

function SkinCatalog.IsTradable(id)
	local skin = SkinCatalog.Get(id)
	return skin ~= nil and skin.Tradable == true
end

function SkinCatalog.StarterForUser(userId)
	local index = (math.abs(tonumber(userId) or 0) % #SkinCatalog.StarterPool) + 1
	return SkinCatalog.StarterPool[index]
end

return SkinCatalog
