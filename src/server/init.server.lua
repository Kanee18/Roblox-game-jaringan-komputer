--[[
	NET QUEST - Server utama
	Alur: Siswa daftar (nama + absen) -> Lobi/Taman -> Pengenalan mode -> Ronde kuis -> Juara & hadiah -> ...

	Mode permainan (lihat folder Modes):
	  🏃 Lari & Pilih      berdiri di kotak jawaban, kotak salah jatuh
	  ⚡ Kuis Kilat        tekan tombol jawaban secepat mungkin
	  🧱 Lintasan Firewall balapan obby di langit, pilih pintu jawaban
	  🔐 Pecahkan Sandi    ketik jawaban & pecahkan Caesar Cipher

	Hadiah: poin dari jawaban benar menjadi POIN RANK (tersimpan). Poin Rank membuka gelar & PET.
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
arena:ResetPads(true)
Roster.Init(Core)

local remotes = Core.remotes
local settings, flags = Core.settings, Core.flags

local function settingsPayload()
	local topic = Config.GetTopic(settings.topic)
	local mode = Config.GetMode(settings.mode)
	return {
		type = "Settings",
		topic = settings.topic,
		topicName = topic.icon .. " " .. topic.name,
		mode = settings.mode,
		modeName = mode.icon .. " " .. mode.name,
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
	if not PetCatalog.IsUnlocked(petId, data.xp) then
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
			if root and root.Position.Y < -60 then
				local inArenaRound = Core.currentMode and Core.currentMode.id ~= "firewall"
				Core.teleport(player, inArenaRound and arena:GetStartCFrame() or arena:GetLobbyCFrame())
			end
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
		return nil, "Bantuan habis! Jawab benar " .. Config.HintEveryStreak .. "x berturut-turut untuk dapat lagi."
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
-- ALUR PERMAINAN
---------------------------------------------------------------------
local function registeredCount()
	return #Core.participants()
end

local function waitInLobby()
	Core.phase = "Lobby"
	Core.current = nil
	Core.currentMode = nil
	flags.stop, flags.lock = false, false
	arena:ResetPads(true)
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
				local nextMode = settings.mode == "giliran" and "Bergiliran" or Config.GetMode(settings.mode).name
				Core.idleScreen("Kuis berikutnya: " .. Config.GetTopic(settings.topic).name .. " • Mode: " .. nextMode
					.. ". Sambil menunggu, baca ZONA MATERI & lihat TAMAN PET!", tostring(math.ceil(endsAt - Core.now())))
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

local rotationIndex = 0
local function chooseMode()
	if settings.mode ~= "giliran" then
		return Config.GetMode(settings.mode)
	end
	rotationIndex = rotationIndex % #Config.RotationOrder + 1
	return Config.GetMode(Config.RotationOrder[rotationIndex])
end

local function topicLabel(topicId)
	local topic = Config.GetTopic(topicId)
	return topic.icon .. " " .. topic.name
end

local function finishRound(mode, totalQuestions)
	Core.phase = "RoundEnd"
	local ranking = {}
	for _, player in ipairs(Core.participants()) do
		local st = Core.stats[player]
		if st.answered > 0 then
			table.insert(ranking, { player = player, st = st })
		end
	end
	table.sort(ranking, function(a, b)
		if a.st.score ~= b.st.score then
			return a.st.score > b.st.score
		end
		return a.st.correct > b.st.correct
	end)

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
	Core.broadcast({ type = "RoundEnd", ranking = publicRanking, totalQuestions = totalQuestions,
		modeName = mode.icon .. " " .. mode.name }, true)
	arena:SetHallOfFame(publicRanking)

	-- ringkasan pribadi + rekomendasi belajar + hadiah
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
		Core.getSession(player).rounds += 1
		local oldXp = PlayerData.Get(player).xp
		local data, rankUp = PlayerData.AddRoundResult(player, st.score, st.correct, st.answered, position == 1)
		local rank, nextRank = PlayerData.GetRank(data.xp)
		local newPets = {}
		for _, pet in ipairs(PetCatalog.NewlyUnlocked(oldXp, data.xp)) do
			table.insert(newPets, { id = pet.id, name = pet.name, rarity = pet.rarity })
		end
		if #newPets > 0 then
			-- langsung pakai pet terbaru yang terbuka
			PlayerData.SetPet(player, newPets[#newPets].id)
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
	Roster.PrintRecap(mode.name .. " • " .. Config.GetTopic(settings.topic).name)

	-- semua ke taman, 3 besar naik podium
	for _, player in ipairs(Players:GetPlayers()) do
		Core.teleport(player, arena:GetLobbyCFrame())
	end
	for rank = 1, math.min(3, #ranking) do
		Core.teleport(ranking[rank].player, arena:GetPodiumCFrame(rank))
	end
	arena:CelebratePodium()
	Core.idleScreen(#ranking > 0 and ("🏆 Juara ronde ini: " .. Core.displayName(ranking[1].player) .. " dengan "
		.. ranking[1].st.score .. " poin! 🏆") or "Ronde selesai!")

	Core.waitFor(Config.RoundEndTime)
end

local function runRound()
	local mode = chooseMode()
	local module = ModeModules[mode.id]
	Core.currentMode = mode
	Core.resetRoundStats()
	broadcastSettings()

	-- PENGENALAN MODE (cara main) + hitung mundur
	Core.phase = "Intro"
	if mode.id == "firewall" then
		arena:SetCourseBarrier(true)
	end
	for _, player in ipairs(Core.participants()) do
		Core.teleport(player, module.StartCFrame(arena))
	end
	local list = module.Prepare(Core)
	local total = #list
	Core.broadcast({
		type = "ModeIntro",
		modeId = mode.id,
		modeName = mode.icon .. " " .. mode.name,
		desc = mode.desc,
		color = mode.color,
		topicName = topicLabel(settings.topic),
		total = total,
		endsAt = Core.now() + Config.ModeIntroTime,
	}, true)
	Core.idleScreen("MODE: " .. mode.icon .. " " .. string.upper(mode.name) .. " — " .. mode.desc, "")

	local played = 0
	if Core.waitFor(Config.ModeIntroTime) then
		played = module.Run(Core, list)
	end
	Core.answerHandler, Core.textHandler, Core.hintProvider, Core.current = nil, nil, nil, nil

	if flags.stop then
		Core.broadcast({ type = "Stopped" })
		arena:ResetCourse()
		for _, player in ipairs(Players:GetPlayers()) do
			Core.teleport(player, arena:GetLobbyCFrame())
		end
		return
	end
	finishRound(mode, played)
end

-- LOOP UTAMA
task.wait(2)
while true do
	waitInLobby()
	runRound()
	arena:ResetPads(true)
	Core.currentMode = nil
end
