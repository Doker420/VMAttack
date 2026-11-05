-- «Поменяйся местами»: общие server/client настройки.
local Config = {
	GameName = "ПОМЕНЯЙСЯ МЕСТАМИ",
	DataStoreName = "SwapPlaces_PlayerData_v1",
	PersistInStudio = false,
	AutosaveInterval = 60,

	-- Создайте Developer Product и вставьте настоящий ID перед live-тестом.
	-- Нулевой ID никогда не выдаёт бесплатный live-обмен.
	SwapProductId = 0,
	SwapRobuxPrice = 25,
	EnableStudioTestPurchases = true,

	SwapDuration = 180,
	OfferDuration = 45,
	TradeDuration = 120,
	MaxProcessedReceipts = 24,

	Spawn = Vector3.new(0, 7, 34),
	World = {
		Width = 220,
		Depth = 180,
		SwapPadRadius = 24,
	},
}

return Config
