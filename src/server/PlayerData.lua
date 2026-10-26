--[[
	PlayerData: menyimpan XP, jumlah ronde, dan statistik jawaban siswa (DataStore).
	Jika DataStore tidak tersedia (misal API Services belum diaktifkan), data hanya
	disimpan selama sesi berjalan dan game tetap bisa dimainkan.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("QuizShared"):WaitForChild("Config"))

local PlayerData = {}

local cache = {}
local store = nil
local storeAvailable = false

if Config.UseDataStore then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		storeAvailable = true
	else
		warn("[NetQuest] DataStore tidak tersedia, XP tidak akan tersimpan permanen: " .. tostring(result))
	end
end

local function defaultData()
	return { xp = 0, rounds = 0, correct = 0, answered = 0, wins = 0 }
end

local function keyFor(player)
	return "siswa_" .. player.UserId
end

function PlayerData.Load(player)
	local data = defaultData()
	if storeAvailable then
		local ok, saved = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok and type(saved) == "table" then
			for key, value in pairs(saved) do
				data[key] = value
			end
		elseif not ok then
			warn("[NetQuest] Gagal memuat data " .. player.Name .. ": " .. tostring(saved))
			storeAvailable = false -- hindari spam error (misal di Studio tanpa akses API)
		end
	end
	cache[player] = data
	return data
end

function PlayerData.Get(player)
	return cache[player] or defaultData()
end

function PlayerData.Save(player)
	local data = cache[player]
	if not data or not storeAvailable then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), data)
	end)
	if not ok then
		warn("[NetQuest] Gagal menyimpan data " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerData.Release(player)
	PlayerData.Save(player)
	cache[player] = nil
end

function PlayerData.SaveAll()
	for player in pairs(cache) do
		PlayerData.Save(player)
	end
end

-- Mengembalikan gelar sekarang, gelar berikutnya (atau nil), dan indeks gelar
function PlayerData.GetRank(xp)
	local current, index = Config.Ranks[1], 1
	for i, rank in ipairs(Config.Ranks) do
		if xp >= rank.xp then
			current, index = rank, i
		end
	end
	return current, Config.Ranks[index + 1], index
end

-- Menambahkan hasil ronde. Mengembalikan data terbaru & apakah naik gelar.
function PlayerData.AddRoundResult(player, score, correct, answered, isWinner)
	local data = cache[player]
	if not data then
		return defaultData(), false
	end
	local _, _, before = PlayerData.GetRank(data.xp)
	data.xp += score
	data.rounds += 1
	data.correct += correct
	data.answered += answered
	if isWinner then
		data.wins += 1
	end
	local _, _, after = PlayerData.GetRank(data.xp)
	task.spawn(PlayerData.Save, player)
	return data, after > before
end

return PlayerData
