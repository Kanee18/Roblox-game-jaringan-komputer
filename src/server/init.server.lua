--[[
	NET QUEST - Server utama
	Mengatur alur permainan: Lobi -> Hitung mundur -> Soal -> Ungkap jawaban -> Penjelasan -> ... -> Juara

	Cara main:
	- Soal muncul di layar besar. Pemain berlari dan BERDIRI di kotak jawaban (A/B/C/D atau BENAR/SALAH).
	- Saat waktu habis, kotak yang salah jatuh ke "Lubang Data". Pemain yang jatuh kembali ke Garis Start
	  (tidak ada yang tereliminasi, semua tetap ikut belajar sampai akhir).
	- Poin = jawaban benar + bonus kecepatan + bonus streak. Soal terakhir adalah SOAL BOS (poin x2).
	- Setelah setiap soal ditampilkan PENJELASAN materi agar siswa tetap belajar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("QuizShared")
local Config = require(Shared:WaitForChild("Config"))
local Questions = require(Shared:WaitForChild("Questions"))
local MapBuilder = require(script:WaitForChild("MapBuilder"))
local PlayerData = require(script:WaitForChild("PlayerData"))

local arena = MapBuilder.Build()
arena:ConnectPit()
arena:StartDecorations()
arena:ResetPads(true)

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "QuizRemotes"
local QuizEvent = Instance.new("RemoteEvent")
QuizEvent.Name = "QuizEvent"
QuizEvent.Parent = remotes
local TeacherEvent = Instance.new("RemoteEvent")
TeacherEvent.Name = "TeacherCommand"
TeacherEvent.Parent = remotes
local ReadyEvent = Instance.new("RemoteEvent")
ReadyEvent.Name = "ClientReady"
ReadyEvent.Parent = remotes
local HintFunction = Instance.new("RemoteFunction")
HintFunction.Name = "UseHint"
HintFunction.Parent = remotes
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local settings = {
	topic = "campuran",
	count = Config.QuestionsPerRound,
	time = Config.QuestionTime,
	auto = Config.AutoStart,
}
local phase = "Lobby" -- Lobby / Countdown / Question / Reveal / RoundEnd
local flags = { start = false, lock = false, stop = false }
local current = nil -- soal yang sedang aktif (hasil Questions.Prepare)
local snapshot = nil -- pesan fase terakhir, dikirim ke pemain yang baru masuk
local stats = {} -- [Player] = statistik ronde

local function now()
	return workspace:GetServerTimeNow()
end

local function broadcast(payload, keepAsSnapshot)
	if keepAsSnapshot then
		snapshot = payload
	end
	QuizEvent:FireAllClients(payload)
end

local function settingsPayload()
	local topic = Config.GetTopic(settings.topic)
	return {
		type = "Settings",
		topic = settings.topic,
		topicName = topic.icon .. " " .. topic.name,
		count = settings.count,
		time = settings.time,
		auto = settings.auto,
	}
end

local function broadcastSettings()
	broadcast(settingsPayload())
end

-- Tunggu beberapa detik, berhenti lebih awal jika guru menekan "Hentikan"
local function waitFor(seconds)
	local endsAt = os.clock() + seconds
	while os.clock() < endsAt do
		if flags.stop then
			return false
		end
		task.wait(0.1)
	end
	return true
end

---------------------------------------------------------------------
-- PEMAIN
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

local function newStats()
	return {
		score = 0,
		streak = 0,
		bestStreak = 0,
		correct = 0,
		answered = 0,
		hints = Config.StartingHints,
		topics = {},
		choice = nil,
		choiceTime = nil,
		hintUsed = false,
		activeFrom = now(),
	}
end

local function updateLeaderstats(player)
	local st = stats[player]
	local folder = player:FindFirstChild("leaderstats")
	if not st or not folder then
		return
	end
	folder.Poin.Value = st.score
	folder.Benar.Value = st.correct
	folder.Streak.Value = st.streak
end

local function sendPersonalStats(player)
	local st = stats[player]
	if st then
		QuizEvent:FireClient(player, { type = "Stats", score = st.score, streak = st.streak, hints = st.hints })
	end
end

local function attachTitle(player, character)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local old = head:FindFirstChild("GelarTag")
	if old then
		old:Destroy()
	end
	local rank = PlayerData.GetRank(PlayerData.Get(player).xp)
	local tag = Instance.new("BillboardGui")
	tag.Name = "GelarTag"
	tag.Size = UDim2.fromScale(7, 1.1)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.MaxDistance = 90
	tag.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextStrokeTransparency = 0.2
	text.TextColor3 = rank.color
	text.Text = (player:GetAttribute("IsTeacher") and "🎓 Guru • " or "⭐ ") .. rank.name
	text.Parent = tag
	tag.Parent = head
end

local function teleport(player, cframe)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cframe)
	end
end

local function onPlayerAdded(player)
	player:SetAttribute("IsTeacher", isTeacher(player))
	stats[player] = newStats()

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in ipairs({ "Poin", "Benar", "Streak" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	PlayerData.Load(player)
	player.CharacterAdded:Connect(function(character)
		attachTitle(player, character)
	end)
	if player.Character then
		task.spawn(attachTitle, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	stats[player] = nil
	PlayerData.Release(player)
end)

game:BindToClose(function()
	PlayerData.SaveAll()
end)

ReadyEvent.OnServerEvent:Connect(function(player)
	QuizEvent:FireClient(player, settingsPayload())
	if snapshot then
		QuizEvent:FireClient(player, snapshot)
	end
	sendPersonalStats(player)
end)

-- Jaring pengaman: pemain yang terjatuh terlalu jauh dikembalikan
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and root.Position.Y < -60 then
				teleport(player, arena:GetStartCFrame())
			end
		end
	end
end)

---------------------------------------------------------------------
-- PERINTAH GURU
---------------------------------------------------------------------
TeacherEvent.OnServerEvent:Connect(function(player, command, value)
	if not player:GetAttribute("IsTeacher") then
		return
	end
	if command == "start" then
		if phase == "Lobby" then
			flags.start = true
		end
	elseif command == "lock" then
		if phase == "Question" then
			flags.lock = true
		end
	elseif command == "stop" then
		if phase ~= "Lobby" then
			flags.stop = true
		end
	elseif command == "topic" then
		if type(value) == "string" and Config.GetTopic(value).id == value then
			settings.topic = value
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
	end
	broadcastSettings()
end)

---------------------------------------------------------------------
-- BANTUAN 50:50
---------------------------------------------------------------------
HintFunction.OnServerInvoke = function(player)
	local st = stats[player]
	if not st or phase ~= "Question" or not current then
		return nil, "Bantuan hanya bisa dipakai saat soal berlangsung."
	end
	if current.kind ~= "PG" then
		return nil, "Bantuan 50:50 hanya untuk soal pilihan ganda."
	end
	if st.hintUsed then
		return nil, "Bantuan sudah dipakai di soal ini."
	end
	if st.hints <= 0 then
		return nil, "Bantuan habis! Jawab benar 3x berturut-turut untuk dapat lagi."
	end
	st.hints -= 1
	st.hintUsed = true
	local wrong = {}
	for _, option in ipairs(current.options) do
		if option.pad ~= current.correctPad then
			table.insert(wrong, option.pad)
		end
	end
	table.remove(wrong, math.random(1, #wrong)) -- sisakan satu jawaban salah
	return wrong, st.hints
end

---------------------------------------------------------------------
-- ALUR PERMAINAN
---------------------------------------------------------------------
local function idleScreen(info, timer)
	arena:SetScreen({
		topic = Config.GameSubtitle,
		number = "",
		timer = timer or "",
		question = Config.GameTitle,
		info = info,
		accent = Color3.fromRGB(70, 160, 255),
	})
end

local function waitInLobby()
	phase = "Lobby"
	current = nil
	flags.stop, flags.lock = false, false
	arena:ResetPads(true)
	while true do
		if flags.start then
			break
		end
		local enoughPlayers = #Players:GetPlayers() >= Config.MinPlayers
		if settings.auto and enoughPlayers then
			local endsAt = now() + Config.IntermissionTime
			broadcast({ type = "Intermission", endsAt = endsAt }, true)
			local topicName = Config.GetTopic(settings.topic).name
			local cancelled = false
			while now() < endsAt and not flags.start do
				if not settings.auto or #Players:GetPlayers() < Config.MinPlayers then
					cancelled = true
					break
				end
				idleScreen("Kuis berikutnya: " .. topicName .. " (" .. settings.count .. " soal). "
					.. "Sambil menunggu, baca papan di ZONA MATERI!", tostring(math.ceil(endsAt - now())))
				task.wait(0.25)
			end
			if not cancelled then
				break
			end
		else
			broadcast({ type = "Waiting", reason = enoughPlayers and "teacher" or "players" }, true)
			idleScreen(enoughPlayers and "Menunggu guru menekan tombol MULAI..." or "Menunggu pemain lain bergabung...")
			repeat
				task.wait(0.25)
			until flags.start or (settings.auto and #Players:GetPlayers() >= Config.MinPlayers)
		end
	end
	flags.start = false
end

local function scoreQuestion(prepared, startAt, duration, isBoss)
	local counts = { 0, 0, 0, 0 }
	for _, player in ipairs(Players:GetPlayers()) do
		local st = stats[player]
		if st and st.choice then
			counts[st.choice] += 1
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local st = stats[player]
		if st and st.activeFrom <= startAt then
			st.answered += 1
			local topicStat = st.topics[prepared.topic]
			if not topicStat then
				topicStat = { correct = 0, total = 0 }
				st.topics[prepared.topic] = topicStat
			end
			topicStat.total += 1

			local isCorrect = st.choice == prepared.correctPad
			local gained, earnedHint = 0, false
			if isCorrect then
				st.correct += 1
				topicStat.correct += 1
				st.streak += 1
				st.bestStreak = math.max(st.bestStreak, st.streak)
				local speed = math.clamp(1 - ((st.choiceTime or now()) - startAt) / duration, 0, 1)
				gained = Config.BasePoints
					+ math.floor(Config.MaxSpeedBonus * speed)
					+ math.min(Config.StreakBonus * (st.streak - 1), Config.MaxStreakBonus)
				if isBoss then
					gained *= Config.BossMultiplier
				end
				st.score += gained
				if st.streak % Config.HintEveryStreak == 0 and st.hints < Config.MaxHints then
					st.hints += 1
					earnedHint = true
				end
			else
				st.streak = 0
			end
			updateLeaderstats(player)
			QuizEvent:FireClient(player, {
				type = "Result",
				correct = isCorrect,
				answered = st.choice ~= nil,
				gained = gained,
				score = st.score,
				streak = st.streak,
				hints = st.hints,
				earnedHint = earnedHint,
				isBoss = isBoss,
			})
		end
	end
	return counts
end

local function askQuestion(q, index, total)
	local isBoss = index == total and total >= 5
	local prepared = Questions.Prepare(q, Config)
	local topic = Config.GetTopic(prepared.topic)
	local duration = prepared.kind == "BS" and Config.TrueFalseTime or settings.time
	if isBoss then
		duration += 5
	end

	-- semua pemain kembali ke Garis Start agar adil
	for _, player in ipairs(Players:GetPlayers()) do
		teleport(player, arena:GetStartCFrame())
		local st = stats[player]
		if st then
			st.choice, st.choiceTime, st.hintUsed = nil, nil, false
		end
	end

	arena:SetQuestion(prepared)
	current = prepared
	phase = "Question"
	flags.lock = false
	local startAt = now()
	local endsAt = startAt + duration

	broadcast({
		type = "Question",
		index = index,
		total = total,
		text = prepared.text,
		kind = prepared.kind,
		options = prepared.options,
		endsAt = endsAt,
		duration = duration,
		topicName = topic.icon .. " " .. topic.name,
		topicColor = topic.color,
		isBoss = isBoss,
	}, true)

	arena:SetScreen({
		topic = topic.icon .. " " .. topic.name,
		number = isBoss and ("⚠ SOAL BOS ⚠  " .. index .. "/" .. total) or ("SOAL " .. index .. "/" .. total),
		question = prepared.text,
		info = prepared.kind == "BS" and "Pernyataan ini BENAR atau SALAH? Berdiri di kotak jawabanmu!"
			or "Lari dan BERDIRI di kotak jawaban yang benar sebelum waktu habis!",
		accent = isBoss and Color3.fromRGB(255, 70, 70) or topic.color,
	})

	-- pantau posisi pemain sampai waktu habis
	while now() < endsAt and not flags.lock and not flags.stop do
		local t = now()
		for _, player in ipairs(Players:GetPlayers()) do
			local st = stats[player]
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local pad = nil
			if root and humanoid and humanoid.Health > 0 then
				pad = arena:GetPadAt(root.Position)
			end
			if st and pad ~= st.choice then
				st.choice, st.choiceTime = pad, t
			end
		end
		arena:SetScreen({ timer = tostring(math.max(0, math.ceil(endsAt - t))) })
		task.wait(0.1)
	end
	if flags.stop then
		return false
	end

	-- UNGKAP JAWABAN
	phase = "Reveal"
	arena:SetScreen({ timer = "0" })
	local counts = scoreQuestion(prepared, startAt, duration, isBoss)
	local correctOption
	for _, option in ipairs(prepared.options) do
		if option.pad == prepared.correctPad then
			correctOption = option
		end
	end
	broadcast({
		type = "Reveal",
		correctPad = prepared.correctPad,
		correctLetter = correctOption.letter,
		correctText = correctOption.text,
		explanation = prepared.explanation,
		counts = counts,
		explainEndsAt = now() + Config.RevealTime + Config.ExplanationTime,
	}, true)
	arena:Reveal(prepared.correctPad, counts)
	arena:SetScreen({
		info = "✔ Jawaban: " .. (prepared.kind == "PG" and (correctOption.letter .. ". ") or "") .. correctOption.text
			.. "\n📘 " .. prepared.explanation,
	})
	current = nil

	if not waitFor(Config.RevealTime + Config.ExplanationTime) then
		return false
	end
	arena:ResetPads(false)
	return true
end

local function topicLabel(topicId)
	local topic = Config.GetTopic(topicId)
	return topic.icon .. " " .. topic.name
end

local function finishRound(totalQuestions)
	phase = "RoundEnd"
	local ranking = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local st = stats[player]
		if st and st.answered > 0 then
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
			name = entry.player.DisplayName,
			userId = entry.player.UserId,
			score = entry.st.score,
			correct = entry.st.correct,
			total = entry.st.answered,
		})
		if i >= 10 then
			break
		end
	end
	broadcast({ type = "RoundEnd", ranking = publicRanking, totalQuestions = totalQuestions }, true)
	arena:SetHallOfFame(publicRanking)

	-- ringkasan pribadi + rekomendasi belajar
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
		local data, rankUp = PlayerData.AddRoundResult(player, st.score, st.correct, st.answered, position == 1)
		local rank, nextRank = PlayerData.GetRank(data.xp)
		QuizEvent:FireClient(player, {
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
		})
		if player.Character then
			task.spawn(attachTitle, player, player.Character)
		end
	end

	-- semua ke lobi, 3 besar naik podium
	for _, player in ipairs(Players:GetPlayers()) do
		teleport(player, arena:GetLobbyCFrame() * CFrame.Angles(0, math.pi, 0))
	end
	for rank = 1, math.min(3, #ranking) do
		teleport(ranking[rank].player, arena:GetPodiumCFrame(rank))
	end
	arena:CelebratePodium()
	idleScreen(#ranking > 0 and ("🏆 Juara ronde ini: " .. ranking[1].player.DisplayName .. " dengan " .. ranking[1].st.score .. " poin! 🏆")
		or "Ronde selesai!")

	waitFor(Config.RoundEndTime)
end

local function runRound()
	local list = Questions.Pick(settings.topic, settings.count)
	if #list == 0 then
		warn("[NetQuest] Tidak ada soal untuk topik " .. settings.topic)
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		stats[player] = newStats()
		stats[player].activeFrom = 0
		updateLeaderstats(player)
		sendPersonalStats(player)
	end

	-- hitung mundur 3..2..1
	phase = "Countdown"
	local topic = Config.GetTopic(settings.topic)
	for _, player in ipairs(Players:GetPlayers()) do
		teleport(player, arena:GetStartCFrame())
	end
	broadcast({ type = "Countdown", endsAt = now() + 4, topicName = topic.icon .. " " .. topic.name, total = #list }, true)
	idleScreen("Bersiap! Topik: " .. topic.name .. " • " .. #list .. " soal", "")
	if waitFor(4) then
		for index, q in ipairs(list) do
			if not askQuestion(q, index, #list) then
				break
			end
		end
	end

	if flags.stop then
		broadcast({ type = "Stopped" })
		for _, player in ipairs(Players:GetPlayers()) do
			teleport(player, arena:GetLobbyCFrame())
		end
		return
	end
	finishRound(#list)
end

-- LOOP UTAMA
task.wait(2)
while true do
	waitInLobby()
	broadcastSettings()
	runRound()
	arena:ResetPads(true)
end
