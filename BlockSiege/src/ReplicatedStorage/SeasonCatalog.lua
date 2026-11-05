-- BLOCKSIEGE // Fixed seasonal themes. Only these IDs can cross the admin remote.
local SeasonCatalog = {}

SeasonCatalog.Default = "NewYear"
SeasonCatalog.Order = { "NewYear", "Halloween", "Defenders", "WomensDay", "Easter" }
SeasonCatalog.Items = {
	NewYear = {
		Id = "NewYear", Name = "НОВЫЙ ГОД", Subtitle = "Снежные огни · подарки · общий штурм",
		Color = Color3.fromRGB(107, 220, 255), Accent = Color3.fromRGB(255, 211, 93), Material = Enum.Material.Snow,
	},
	Halloween = {
		Id = "Halloween", Name = "ХЭЛЛУИН", Subtitle = "Тыквенные огни · неоновые тени · охота за ядром",
		Color = Color3.fromRGB(255, 137, 57), Accent = Color3.fromRGB(184, 106, 255), Material = Enum.Material.Slate,
	},
	Defenders = {
		Id = "Defenders", Name = "23 ФЕВРАЛЯ", Subtitle = "Знамёна защитников · командная дисциплина",
		Color = Color3.fromRGB(255, 92, 83), Accent = Color3.fromRGB(255, 211, 93), Material = Enum.Material.Metal,
	},
	WomensDay = {
		Id = "WomensDay", Name = "8 МАРТА", Subtitle = "Весенние цветы · тёплые огни · новый сезон",
		Color = Color3.fromRGB(255, 126, 193), Accent = Color3.fromRGB(255, 225, 119), Material = Enum.Material.Grass,
	},
	Easter = {
		Id = "Easter", Name = "ПАСХА", Subtitle = "Пастельные яйца · весенние огни · общий праздник",
		Color = Color3.fromRGB(175, 239, 157), Accent = Color3.fromRGB(196, 164, 255), Material = Enum.Material.SmoothPlastic,
	},
}

function SeasonCatalog.Get(id)
	return type(id) == "string" and SeasonCatalog.Items[id] or nil
end

return SeasonCatalog
