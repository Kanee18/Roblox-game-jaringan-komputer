--[[
	NET QUEST - Server utama
	Alur: Siswa daftar (nama + absen) -> Alun-alun -> PETUALANGAN 4 GAME -> Juara & hadiah -> ...

	Petualangan = keempat game dimainkan berurutan, poinnya DIJUMLAHKAN menjadi POIN TOTAL:
	  1. Lari & Pilih       (Arena utara)      berdiri di kotak jawaban, kotak salah jatuh ke kolam
	  2. Kuis Kilat         (Panggung timur)   tekan tombol jawaban secepat mungkin
	  3. Lintasan Firewall  (Menara selatan)   balapan obby di langit, pilih pintu jawaban
	  4. Pecahkan Sandi     (Lab barat)        ketik jawaban & pecahkan Caesar Cipher
	Siswa yang ikut keempat game mendapat BONUS TAMAT.

	Hadiah: poin total menjadi POIN RANK (tersimpan). Poin Rank membuka gelar & PET.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Core = require(script:WaitForChild("Core"))
local MapBuilder = require(script:WaitForChild("MapBuilder"))
local Roster = require(script:WaitForChild("Roster"))
local ModesFolder = script:WaitForChild("Modes")

local Config, PlayerData, PetCatalog = Core.Config, Core.PlayerData, Core.PetCatalog
local ModeModules = {
	kotak = require(ModesFolder:WaitForChild("Kotak")),
	kilat = require(ModesFolder:WaitForChild("Kilat")),
	firewall = require(ModesFolder:WaitForChild("Firewall")),
	sandi = require(ModesFolder:WaitForChild("Sandi")),
}

Core.SetupRemotes()
local arena = MapBuilder.Build()
Core.arena = arena
arena:ConnectPit()
arena:StartDecorations()
Roster.Init(Core)

local remotes = Core.remotes
local settings, flags = Core.settings, Core.flags

local function settingsPayload()
	return {
		type = "Settings",
		topic = settings.topic,
		topicName = Config.GetTopic(settings.topic).name,
		mode = settings.mode,
		modeName = Config.GetMode(settings.mode).name,
		count = settings.count,
		time = settings.time,
		auto = settings.auto,
	}
end

local function broadcastSettings()
	Core.broadcast(settingsPayload())
end

---------------------------------------------------------------------
-- GURU
---------------------------------------------------------------------
local function isTeacher(player)
	if RunService:IsStudio() and Config.StudioEveryoneTeacher then
		return true
	end
	if table.find(Config.TeacherUserIds, player.UserId) then
		return true
	end
	for _, name in ipairs(Config.TeacherNames) do
		if string.lower(name) == string.lower(player.Name) then
			return true
		end
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if ok and rank >= Config.GroupTeacherMinRank then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
-- PET
---------------------------------------------------------------------
local function applyPet(player)
	local data = PlayerData.Get(player)
	local petId = data.pet
	if petId ~= "" and not PetCatalog.IsUnlocked(petId, data.xp) then
		petId = PetCatalog.Best(data.xp).id
		PlayerData.SetPet(player, petId)
	end
	player:SetAttribute("PoinRank", data.xp)
	player:SetAttribute("Pet", petId)
end

remotes.EquipPet.OnServerEvent:Connect(function(player, petId)
	local data = PlayerData.Get(player)
	if type(petId) == "string" and PetCatalog.IsUnlocked(petId, data.xp) then
		PlayerData.SetPet(player, petId)
		player:SetAttribute("Pet", petId)
	elseif petId == "" then
		PlayerData.SetPet(player, "")
		player:SetAttribute("Pet", "") -- sembunyikan pet
	end
end)

---------------------------------------------------------------------
-- PEMAIN MASUK / KELUAR
---------------------------------------------------------------------
local function onCharacter(player, character)
	character:WaitForChild("Humanoid", 10)
	character:WaitForChild("Head", 10)
	Roster.ApplyMovement(player)
	Roster.ApplyTag(player)
end

local function onPlayerAdded(player)
	player:SetAttribute("IsTeacher", isTeacher(player))
	Core.stats[player] = Core.newStats()

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in ipairs({ "Absen", "Poin", "Benar", "Poin Rank" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end

	PlayerData.Load(player)
	applyPet(player)
	Core.updateLeaderstats(player)
	Roster.SendProfile(player)
	if player.Character then
		Roster.ApplyTag(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Core.stats[player] = nil
	Core.session[player] = nil
	PlayerData.Release(player)
end)

game:BindToClose(function()
	PlayerData.SaveAll()
end)

remotes.ClientReady.OnServerEvent:Connect(function(player)
	Core.send(player, settingsPayload())
	Roster.SendProfile(player)
	if Core.adventure then
		Core.send(player, Core.adventurePayload())
	end
	if Core.snapshot then
		Core.send(player, Core.snapshot)
	end
	Core.sendStats(player)
end)

-- Jaring pengaman: pemain yang terjatuh terlalu jauh dikembalikan
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = Core.rootOf(player)
			if root and root.Position.Y < -40 then
				local module = Core.currentMode and ModeModules[Core.currentMode.id]
				local inZone = module and Core.currentMode.id ~= "firewall"
				Core.teleport(player, inZone and module.StartCFrame(arena) or arena:GetLobbyCFrame())
			end
		end
	end
end)

-- Papan peringkat di alun-alun selalu menampilkan POIN TOTAL terbaru selama petualangan
task.spawn(function()
	while true do
		task.wait(2)
		if Core.adventure and Core.phase ~= "RoundEnd" then
			local rows = {}
			for _, player in ipairs(Core.participants()) do
				table.insert(rows, { name = Core.displayName(player), score = Core.stats[player].score })
			end
			table.sort(rows, function(a, b)
				return a.score > b.score
			end)
			arena:SetLeaderboard("POIN TOTAL • GAME " .. Core.adventure.index .. "/" .. #Core.adventure.modes, rows)
		end
	end
end)

---------------------------------------------------------------------
-- PERINTAH GURU
---------------------------------------------------------------------
remotes.TeacherCommand.OnServerEvent:Connect(function(player, command, value)
	if not player:GetAttribute("IsTeacher") then
		return
	end
	if command == "start" then
		if Core.phase == "Lobby" then
			flags.start = true
		end
	elseif command == "lock" then
		if Core.phase == "Question" or Core.phase == "Race" then
			flags.lock = true
		end
	elseif command == "stop" then
		if Core.phase ~= "Lobby" then
			flags.stop = true
		end
	elseif command == "topic" then
		if type(value) == "string" and Config.GetTopic(value).id == value then
			settings.topic = value
		end
	elseif command == "mode" then
		if type(value) == "string" and Config.GetMode(value).id == value then
			settings.mode = value
		end
	elseif command == "count" then
		if type(value) == "number" and value >= 3 and value <= 30 then
			settings.count = math.floor(value)
		end
	elseif command == "time" then
		if type(value) == "number" and value >= 5 and value <= 60 then
			settings.time = math.floor(value)
		end
	elseif command == "auto" then
		settings.auto = value == true
	elseif command == "recap" then
		Roster.PrintRecap("diminta guru")
	end
	broadcastSettings()
end)

---------------------------------------------------------------------
-- BANTUAN (50:50 / petunjuk huruf) & JAWABAN
---------------------------------------------------------------------
remotes.UseHint.OnServerInvoke = function(player)
	local st = Core.stats[player]
	if not st or not Core.isRegistered(player) then
		return nil, "Daftar dulu ya!"
	end
	if not Core.hintProvider then
		return nil, "Bantuan hanya bisa dipakai saat soal berlangsung."
	end
	if st.hints <= 0 then
		return nil, "Bantuan habis. Jawab benar " .. Config.HintEveryStreak .. "x berturut-turut untuk dapat lagi."
	end
	local result, err = Core.hintProvider(player, st)
	if not result then
		return nil, err
	end
	st.hints -= 1
	return result, st.hints
end

remotes.Answer.OnServerEvent:Connect(function(player, questionId, pad)
	if Core.answerHandler and type(questionId) == "number" and type(pad) == "number" then
		Core.answerHandler(player, questionId, pad)
	end
end)

remotes.SubmitText.OnServerInvoke = function(player, questionId, text)
	if not Core.textHandler or type(questionId) ~= "number" or type(text) ~= "string" then
		return { ok = false, message = "Belum ada soal isian sekarang." }
	end
	return Core.textHandler(player, questionId, text)
end

---------------------------------------------------------------------
-- LOBI
---------------------------------------------------------------------
local function registeredCount()
	return #Core.participants()
end

local function waitInLobby()
	Core.phase = "Lobby"
	Core.current = nil
	Core.currentMode = nil
	Core.adventure = nil
	flags.stop, flags.lock = false, false
	arena:ResetPads(true)
	arena:SetStageQuestion(nil)
	while true do
		if flags.start then
			break
		end
		local enough = registeredCount() >= Config.MinPlayers
		if settings.auto and enough then
			local endsAt = Core.now() + Config.IntermissionTime
			Core.broadcast({ type = "Intermission", endsAt = endsAt }, true)
			local cancelled = false
			while Core.now() < endsAt and not flags.start do
				if not settings.auto or registeredCount() < Config.MinPlayers then
					cancelled = true
					break
				end
				Core.idleScreen("Berikutnya: " .. Config.GetMode(settings.mode).name .. " • Topik: " .. Config.GetTopic(settings.topic).name
					.. ". Sambil menunggu, baca Zona Materi dan lihat Taman Pet!", tostring(math.ceil(endsAt - Core.now())))
				task.wait(0.25)
			end
			if not cancelled then
				break
			end
		else
			Core.broadcast({ type = "Waiting", reason = enough and "teacher" or "players" }, true)
			Core.idleScreen(enough and "Menunggu guru menekan tombol MULAI..." or "Menunggu siswa mendaftar...")
			repeat
				task.wait(0.25)
			until flags.start or (settings.auto and registeredCount() >= Config.MinPlayers)
		end
	end
	flags.start = false
end

---------------------------------------------------------------------
-- SATU GAME
---------------------------------------------------------------------
local function ranked(list)
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return (a.correct or 0) > (b.correct or 0)
	end)
	return list
end

-- Memainkan satu game. Mengembalikan jumlah soal yang dimainkan, atau nil jika dihentikan guru.
local function playGame(mode, index, total)
	local module = ModeModules[mode.id]
	Core.currentMode = mode
	if Core.adventure then
		Core.adventure.index = index
		Core.broadcast(Core.adventurePayload())
	end

	Core.phase = "Intro"
	if mode.id == "firewall" then
		arena:SetCourseBarrier(true)
	end
	for _, player in ipairs(Core.participants()) do
		Core.teleport(player, module.StartCFrame(arena))
	end
	local list = module.Prepare(Core)
	local before = {}
	for player, st in pairs(Core.stats) do
		before[player] = { score = st.score, correct = st.correct, answered = st.answered, attempted = st.attempted }
	end

	Core.broadcast({
		type = "ModeIntro",
		modeId = mode.id,
		modeName = mode.name,
		desc = mode.desc,
		color = mode.color,
		topicName = Config.GetTopic(settings.topic).name,
		total = #list,
		gameIndex = index,
		gameTotal = total,
		endsAt = Core.now() + Config.ModeIntroTime,
	}, true)
	Core.idleScreen((total > 1 and ("GAME " .. index .. " DARI " .. total .. ": ") or "") .. string.upper(mode.name) .. ". " .. mode.desc, "")

	local played = 0
	if Core.waitFor(Config.ModeIntroTime) then
		played = module.Run(Core, list)
	end
	Core.answerHandler, Core.textHandler, Core.hintProvider, Core.current = nil, nil, nil, nil
	if flags.stop then
		return nil
	end

	-- catat poin game ini untuk setiap siswa
	local rows = {}
	for _, player in ipairs(Core.participants()) do
		local st = Core.stats[player]
		local b = before[player] or { score = 0, correct = 0, answered = 0, attempted = 0 }
		local g = { score = st.score - b.score, correct = st.correct - b.correct, answered = st.answered - b.answered,
			attempted = st.attempted - b.attempted }
		st.games = st.games or {}
		st.games[mode.id] = g
		if g.answered > 0 then
			table.insert(rows, { player = player, name = Core.displayName(player), userId = player.UserId, score = g.score, correct = g.correct,
				total = g.answered })
		end
	end
	return played, ranked(rows)
end

-- Jeda singkat setelah satu game di Petualangan: hasil game ini + poin total sementara
local function showGameBreak(mode, index, total, gameRows)
	local totals = {}
	for _, player in ipairs(Core.participants()) do
		local st = Core.stats[player]
		if st.answered > 0 then
			table.insert(totals, { name = Core.displayName(player), userId = player.UserId, score = st.score, correct = st.correct, total = st.answered })
		end
	end
	ranked(totals)
	local nextMode = Config.GetMode(Config.AdventureOrder[index + 1])
	local publicGame, publicTotal = {}, {}
	for i = 1, math.min(8, #gameRows) do
		local r = gameRows[i]
		publicGame[i] = { name = r.name, userId = r.userId, score = r.score, correct = r.correct, total = r.total }
	end
	for i = 1, math.min(8, #totals) do
		publicTotal[i] = totals[i]
	end
	Core.phase = "Break"
	Core.broadcast({
		type = "GameEnd",
		gameIndex = index,
		gameTotal = total,
		modeName = mode.name,
		color = mode.color,
		gameRanking = publicGame,
		totalRanking = publicTotal,
		nextName = nextMode.name,
		endsAt = Core.now() + Config.GameBreakTime,
	}, true)
	for _, player in ipairs(Core.participants()) do
		local st = Core.stats[player]
		local g = st.games and st.games[mode.id]
		if g then
			Core.send(player, { type = "GameScore", gameScore = g.score, correct = g.correct, answered = g.answered, totalScore = st.score })
		end
	end
	Core.idleScreen("Hasil Game " .. index .. " • Berikutnya: " .. nextMode.name, "")
	arena:SetHallOfFame(publicTotal, "POIN TOTAL • GAME " .. index .. "/" .. total)
	return Core.waitFor(Config.GameBreakTime)
end

---------------------------------------------------------------------
-- AKHIR SESI: juara, rapor, hadiah pet, rekap
---------------------------------------------------------------------
local function topicLabel(topicId)
	return Config.GetTopic(topicId).name
end

local function finishSession(modes, totalQuestions)
	Core.phase = "RoundEnd"

	-- bonus tamat untuk yang ikut menjawab di semua game
	if #modes > 1 then
		for _, player in ipairs(Core.participants()) do
			local st = Core.stats[player]
			local all = true
			for _, mode in ipairs(modes) do
				local g = st.games and st.games[mode.id]
				if not g or g.attempted == 0 then
					all = false
				end
			end
			if all then
				st.completedAll = true
				Core.addBonus(player, Config.CompletionBonus, "Bonus tamat: kamu menyelesaikan keempat game!")
			end
		end
	end

	local ranking = {}
	for _, player in ipairs(Core.participants()) do
		local st = Core.stats[player]
		if st.answered > 0 then
			table.insert(ranking, { player = player, st = st, score = st.score, correct = st.correct })
		end
	end
	ranked(ranking)

	local publicRanking = {}
	for i, entry in ipairs(ranking) do
		table.insert(publicRanking, {
			name = Core.displayName(entry.player),
			userId = entry.player.UserId,
			score = entry.st.score,
			correct = entry.st.correct,
			total = entry.st.answered,
		})
		if i >= 10 then
			break
		end
	end
	local title = #modes > 1 and "Petualangan 4 Game" or modes[1].name
	Core.broadcast({ type = "RoundEnd", ranking = publicRanking, totalQuestions = totalQuestions, modeName = title }, true)
	arena:SetHallOfFame(publicRanking, "JUARA • " .. string.upper(title))

	for position, entry in ipairs(ranking) do
		local player, st = entry.player, entry.st
		local weak, strong
		for topicId, topicStat in pairs(st.topics) do
			local ratio = topicStat.correct / topicStat.total
			if not weak or ratio < weak.ratio then
				weak = { id = topicId, ratio = ratio, correct = topicStat.correct, total = topicStat.total }
			end
			if not strong or ratio > strong.ratio then
				strong = { id = topicId, ratio = ratio, correct = topicStat.correct, total = topicStat.total }
			end
		end
		local games = {}
		for _, mode in ipairs(modes) do
			local g = st.games and st.games[mode.id]
			table.insert(games, { name = mode.name, color = mode.color, score = g and g.score or 0, correct = g and g.correct or 0,
				answered = g and g.answered or 0 })
		end
		Core.getSession(player).rounds += 1
		local oldXp = PlayerData.Get(player).xp
		local data, rankUp = PlayerData.AddRoundResult(player, st.score, st.correct, st.answered, position == 1)
		local rank, nextRank = PlayerData.GetRank(data.xp)
		local newPets = {}
		for _, pet in ipairs(PetCatalog.NewlyUnlocked(oldXp, data.xp)) do
			table.insert(newPets, { id = pet.id, name = pet.name, rarity = pet.rarity })
		end
		if #newPets > 0 then
			PlayerData.SetPet(player, newPets[#newPets].id) -- langsung pakai pet terbaru
		end
		applyPet(player)
		local nextPet = PetCatalog.Next(data.xp)
		Core.send(player, {
			type = "Summary",
			position = position,
			players = #ranking,
			score = st.score,
			correct = st.correct,
			answered = st.answered,
			bestStreak = st.bestStreak,
			games = games,
			completedAll = st.completedAll == true,
			completionBonus = Config.CompletionBonus,
			weakTopic = weak and weak.ratio < 1 and topicLabel(weak.id) or nil,
			weakId = weak and weak.ratio < 1 and weak.id or nil,
			weakText = weak and (weak.correct .. "/" .. weak.total) or nil,
			strongTopic = strong and strong.ratio > 0 and topicLabel(strong.id) or nil,
			strongText = strong and (strong.correct .. "/" .. strong.total) or nil,
			xp = data.xp,
			title = rank.name,
			titleColor = rank.color,
			nextTitle = nextRank and nextRank.name or nil,
			nextXp = nextRank and nextRank.xp or nil,
			rankUp = rankUp,
			newPets = newPets,
			nextPetName = nextPet and nextPet.name or nil,
			nextPetXp = nextPet and nextPet.xp or nil,
		})
		Core.updateLeaderstats(player)
		Roster.ApplyTag(player)
	end
	Roster.PrintRecap(title .. " • " .. Config.GetTopic(settings.topic).name)

	-- semua kembali ke alun-alun, 3 besar naik podium
	for _, player in ipairs(Players:GetPlayers()) do
		Core.teleport(player, arena:GetLobbyCFrame())
	end
	for rank = 1, math.min(3, #ranking) do
		Core.teleport(ranking[rank].player, arena:GetPodiumCFrame(rank))
	end
	arena:CelebratePodium()
	Core.idleScreen(#ranking > 0 and ("Juara " .. title .. ": " .. Core.displayName(ranking[1].player) .. " dengan "
		.. ranking[1].st.score .. " poin!") or "Selesai!")
	Core.waitFor(Config.RoundEndTime)
end

---------------------------------------------------------------------
-- SESI (Petualangan 4 game atau satu game saja)
---------------------------------------------------------------------
local function chooseModes()
	if settings.mode == "petualangan" then
		local list = {}
		for _, id in ipairs(Config.AdventureOrder) do
			table.insert(list, Config.GetMode(id))
		end
		return list
	end
	return { Config.GetMode(settings.mode) }
end

function Core.adventurePayload()
	local adv = Core.adventure
	local names = {}
	for i, mode in ipairs(adv.modes) do
		names[i] = { name = mode.name, color = mode.color }
	end
	return { type = "Adventure", index = adv.index, games = names }
end

local function runSession()
	local modes = chooseModes()
	Core.resetRoundStats()
	Core.adventure = { modes = modes, index = 1 }
	broadcastSettings()

	local totalQuestions = 0
	for index, mode in ipairs(modes) do
		local played, rows = playGame(mode, index, #modes)
		if not played then
			break
		end
		totalQuestions += played
		if index < #modes and not showGameBreak(mode, index, #modes, rows) then
			break
		end
	end

	if flags.stop then
		Core.broadcast({ type = "Stopped" })
		arena:ResetCourse()
		for _, player in ipairs(Players:GetPlayers()) do
			Core.teleport(player, arena:GetLobbyCFrame())
		end
		return
	end
	finishSession(modes, totalQuestions)
end

-- LOOP UTAMA
task.wait(2)
while true do
	waitInLobby()
	runSession()
	arena:ResetPads(true)
	arena:SetStageQuestion(nil)
	Core.currentMode = nil
	Core.adventure = nil
	Core.broadcast({ type = "AdventureEnd" })
end
