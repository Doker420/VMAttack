-- BLOCKSIEGE: общие правила матча 6 на 6.
local Config = {
	GameName = "BLOCKSIEGE",
	TeamSize = 6,
	MaxPlayers = 12,
	IntermissionDuration = 15,
	BuildDuration = 75,
	BattleDuration = 360,
	ResultsDuration = 15,
	RespawnDuration = 4,

	Arena = {
		BaseX = 150,
		BaseY = 4,
		CoreHealth = 3000,
		BuildGrid = 4,
		BuildZoneForward = 50,
		BuildZoneSide = 52,
		MaxBuildDistance = 48,
		MaxBuildPerPlayer = 14,
		BotBuildsPerBot = 3,
		HideEnemyBaseDuringBuild = true,
	},

	DataStoreName = "BlockSiege_PlayerData_v1",
	PersistInStudio = false,
	AutosaveInterval = 90,
	StartingCaseTokens = 3,
	DailyCooldown = 20 * 60 * 60, -- серверный cooldown Daily в секундах
	EnableStudioTestPurchases = true, -- только Studio: косметика без Robux для теста

	-- Оригинальные WAV лежат в assets/audio; ниже IDs загруженных владельцем Audio assets. 0 = отключить звук.
	Audio = {
		LobbyMusicId = 107302597029227,
		BuildMusicId = 80895801914266,
		BattleMusicId = 93303701052020,
		ShotSfxId = 125805003489875,
		HeavyShotSfxId = 977022236373846,
		HitSfxId = 109159125731146,
		BuildSfxId = 86217235156683,
		DestroySfxId = 104163068739526,
		CoreDestroyedSfxId = 131007272682990,
		CaseOpenedSfxId = 76485285757394,
		UIClickSfxId = 91669565215428,
		VictorySfxId = 133823162922154,
		DefeatSfxId = 126799440489634,
		MusicVolume = 0.24,
		SFXVolume = 0.42,
		FadeDuration = 1.1,
		DefaultEnabled = true,
	},

	TeamOrder = { "Blue", "Orange" },
	Teams = {
		Blue = {
			Name = "СИНИЕ",
			Color = Color3.fromRGB(45, 157, 203),
			Dark = Color3.fromRGB(28, 77, 110),
		},
		Orange = {
			Name = "ОРАНЖЕВЫЕ",
			Color = Color3.fromRGB(235, 139, 44),
			Dark = Color3.fromRGB(128, 65, 29),
		},
	},

	BuildKinds = {
		Wall = {
			Name = "СТЕНА",
			Size = Vector3.new(12, 12, 2),
			Health = 420,
		},
		Barricade = {
			Name = "БАРРИКАДА",
			Size = Vector3.new(12, 5, 2),
			Health = 240,
		},
		Tower = {
			Name = "БАШНЯ",
			Size = Vector3.new(8, 18, 8),
			Health = 560,
		},
		SpikeTrap = {
			Name = "ШИПЫ",
			Size = Vector3.new(8, 0.8, 8),
			Health = 150,
			Trap = true,
			TriggerRadius = 7,
			Damage = 35,
			Cooldown = 2,
		},
		ShockMine = {
			Name = "МИНА",
			Size = Vector3.new(5, 1, 5),
			Health = 100,
			Trap = true,
			TriggerRadius = 8,
			BlastRadius = 13,
			Damage = 70,
			Cooldown = 99,
			OneShot = true,
		},
		FlameTrap = {
			Name = "ОГНЕМЁТ",
			Size = Vector3.new(7, 1.2, 7),
			Health = 180,
			Trap = true,
			TriggerRadius = 9,
			Damage = 24,
			Cooldown = 1.5,
		},
	},
}

function Config.OtherTeam(team)
	return team == "Blue" and "Orange" or "Blue"
end

function Config.BasePosition(team)
	return Vector3.new(team == "Blue" and -Config.Arena.BaseX or Config.Arena.BaseX, Config.Arena.BaseY, 0)
end

function Config.BaseCFrame(team)
	local position = Config.BasePosition(team)
	return CFrame.lookAt(position, Config.BasePosition(Config.OtherTeam(team)))
end

return Config
