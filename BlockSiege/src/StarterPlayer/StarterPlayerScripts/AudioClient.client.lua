-- Локальная музыка фаз, SFX и mute. Asset ID настраиваются в Config.Audio.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("BlockSiege")
local Config = require(Shared:WaitForChild("Config"))
local remotes = Shared:WaitForChild("Remotes")
local state = Shared:WaitForChild("MatchState")
local audioFolder = Instance.new("Folder")
audioFolder.Name = "BlockSiegeAudio"
audioFolder.Parent = player:WaitForChild("PlayerGui")

local enabled = Config.Audio.DefaultEnabled
local currentMusic
local currentTheme
local desiredTheme = "Lobby"

local gui = Instance.new("ScreenGui")
gui.Name = "BlockSiegeAudioUI"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui
local muteButton = Instance.new("TextButton")
muteButton.AnchorPoint = Vector2.new(1, 0)
muteButton.Position = UDim2.new(1, -18, 0, 122)
muteButton.Size = UDim2.new(0, 46, 0, 42)
muteButton.BackgroundColor3 = Color3.fromRGB(38, 49, 48)
muteButton.TextColor3 = Color3.fromRGB(240, 241, 217)
muteButton.Font = Enum.Font.Code
muteButton.TextSize = 24
muteButton.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent = muteButton

local function fadeAndDestroy(sound)
	if not sound then
		return
	end
	local fade = TweenService:Create(sound, TweenInfo.new(Config.Audio.FadeDuration), { Volume = 0 })
	fade:Play()
	task.delay(Config.Audio.FadeDuration + 0.05, function()
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end)
end

local function updateButton()
	muteButton.Text = enabled and "♪" or "×"
end

local function updateMusic()
	local phase = state:GetAttribute("Phase") or "Lobby"
	desiredTheme = phase == "Build" and "Build" or (phase == "Battle" and "Battle" or "Lobby")
	if desiredTheme == currentTheme then
		return
	end
	currentTheme = desiredTheme
	local previous = currentMusic
	currentMusic = nil
	fadeAndDestroy(previous)
	if not enabled then
		return
	end
	local assetId = Config.Audio[currentTheme .. "MusicId"] or 0
	if assetId <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = currentTheme .. "Music"
	sound.SoundId = string.format("rbxassetid://%.0f", assetId)
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = audioFolder
	currentMusic = sound
	SoundService:PlayLocalSound(sound)
	TweenService:Create(sound, TweenInfo.new(Config.Audio.FadeDuration), { Volume = Config.Audio.MusicVolume }):Play()
end

local function playSfx(name, volume, playbackSpeed)
	if not enabled then
		return
	end
	local assetId = Config.Audio[name .. "SfxId"] or 0
	if assetId <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = name .. "SFX"
	sound.SoundId = string.format("rbxassetid://%.0f", assetId)
	sound.Volume = (volume or 1) * Config.Audio.SFXVolume
	sound.PlaybackSpeed = playbackSpeed or 1
	sound.Parent = audioFolder
	SoundService:PlayLocalSound(sound)
	Debris:AddItem(sound, 4)
end

local function toggleAudio()
	enabled = not enabled
	updateButton()
	if not enabled then
		local previous = currentMusic
		currentMusic = nil
		currentTheme = nil
		fadeAndDestroy(previous)
	else
		currentTheme = nil
		updateMusic()
	end
end

muteButton.Activated:Connect(toggleAudio)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.N and not processed then
		toggleAudio()
	elseif processed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		playSfx("UIClick", 0.35, 1)
	end
end)

remotes.CombatFX.OnClientEvent:Connect(function(payload)
	if payload.Melee == true or payload.Kind == "Melee" then
		playSfx("Hit", 0.58, 1.18)
	elseif payload.Kind == "Shot" then
		local heavy = payload.WeaponId == "Rail" or payload.WeaponId == "Demolisher" or payload.WeaponId == "Marksman" or payload.WeaponId == "ThanosGauntlet" or payload.WeaponId == "PrismLance"
		local pitch = 1
		if payload.WeaponId == "SMG" or payload.WeaponId == "TeslaCarbine" then
			pitch = 1.16
		elseif payload.WeaponId == "Scatter" then
			pitch = 0.86
		elseif payload.WeaponId == "Rail" or payload.WeaponId == "ThanosGauntlet" or payload.WeaponId == "PrismLance" then
			pitch = 0.78
		end
		playSfx(heavy and "HeavyShot" or "Shot", heavy and 0.7 or 0.42, pitch)
	elseif payload.Kind == "StructureHit" then
		playSfx("Hit", 0.32, 0.95 + math.random() * 0.1)
	elseif payload.Kind == "StructureDestroyed" then
		playSfx("Destroy", 0.72, 0.94 + math.random() * 0.12)
	elseif payload.Kind == "CircuitBreach" then
		playSfx("HeavyShot", 0.72, 0.62)
		playSfx("CaseOpened", 0.5, 1.24)
	elseif payload.Kind == "CoreDestroyed" then
		playSfx("CoreDestroyed", 1, 1)
	elseif payload.Kind == "ExpeditionShot" then
		playSfx("Shot", 0.36, 0.82)
	elseif payload.Kind == "ExpeditionDefeated" then
		playSfx("Destroy", 0.58, 1.08)
	elseif payload.Kind == "ExpeditionBossWarning" then
		playSfx("HeavyShot", 0.62, 0.68)
	elseif payload.Kind == "ExpeditionBossSlam" then
		playSfx("CoreDestroyed", 0.82, 0.76)
	end
end)
remotes.BuildFX.OnClientEvent:Connect(function()
	playSfx("Build", 0.55, 0.96 + math.random() * 0.08)
end)
remotes.TrapFX.OnClientEvent:Connect(function(payload)
	playSfx(payload.Kind == "ShockMine" and "Destroy" or "Hit", 0.62, payload.Kind == "FlameTrap" and 0.82 or 1.08)
end)
remotes.CaptureFX.OnClientEvent:Connect(function()
	playSfx("CaseOpened", 0.72, 1.12)
end)
remotes.CaseOpened.OnClientEvent:Connect(function()
	playSfx("CaseOpened", 0.8, 1)
end)
remotes.SeasonFX.OnClientEvent:Connect(function()
	playSfx("CaseOpened", 0.5, 1.18)
end)
remotes.ExpeditionFX.OnClientEvent:Connect(function(payload)
	if payload.Type == "Completed" then
		playSfx("Victory", 0.8, 1.06)
	end
end)
remotes.DeathFX.OnClientEvent:Connect(function(payload)
	if payload.VictimUserId == player.UserId then
		playSfx(Config.Audio.DeathSfxId > 0 and "Death" or "Defeat", 0.85, 0.92)
	end
end)
remotes.Results.OnClientEvent:Connect(function(result)
	if result.Winner == "" then
		playSfx("CaseOpened", 0.55, 0.9)
	elseif result.Winner == result.Team then
		playSfx("Victory", 0.9, 1)
	else
		playSfx("Defeat", 0.8, 1)
	end
end)
state:GetAttributeChangedSignal("Phase"):Connect(updateMusic)
updateButton()
updateMusic()
