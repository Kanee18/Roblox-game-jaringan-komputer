--[[
	Core: state & fungsi bersama yang dipakai semua mode permainan
	(pengiriman pesan ke client, skor, teleport, daftar peserta, dll).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("QuizShared")

local Core = {}
Core.Config = require(Shared:WaitForChild("Config"))
Core.Questions = require(Shared:WaitForChild("Questions"))
Core.PetCatalog = require(Shared:WaitForChild("PetCatalog"))
Core.PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Config = Core.Config

Core.arena = nil
Core.remotes = {}
Core.settings = {
	topic = "campuran",
	count = Config.QuestionsPerRound,
	time = Config.QuestionTime,
	auto = Config.AutoStart,
	mode = Config.DefaultMode,
}
Core.phase = "Lobby" -- Lobby / Intro / Question / Reveal / Race / RoundEnd
Core.flags = { start = false, lock = false, stop = false }
Core.stats = {} -- [Player] = statistik ronde
Core.session = {} -- [Player] = statistik sepanjang sesi (untuk rekap guru)
Core.snapshot = nil -- pesan fase terakhir, dikirim ke pemain yang baru masuk
Core.current = nil -- soal yang sedang aktif
Core.hintProvider = nil -- fungsi bantuan untuk mode yang sedang berjalan
Core.answerHandler = nil -- penerima jawaban tombol (Kuis Kilat)
Core.textHandler = nil -- penerima jawaban ketikan (Pecahkan Sandi)
Core.currentMode = nil

local questionCounter = 0

function Core.now()
	return workspace:GetServerTimeNow()
end

function Core.SetupRemotes()
	local folder = Instance.new("Folder")
	folder.Name = "QuizRemotes"
	for _, name in ipairs({ "QuizEvent", "TeacherCommand", "ClientReady", "Answer", "EquipPet" }) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Core.remotes[name] = remote
	end
	for _, name in ipairs({ "UseHint", "Register", "SubmitText", "GetRoster" }) do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		Core.remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
end

function Core.broadcast(payload, keepAsSnapshot)
	if keepAsSnapshot then
		Core.snapshot = payload
	end
	Core.remotes.QuizEvent:FireAllClients(payload)
end

function Core.send(player, payload)
	Core.remotes.QuizEvent:FireClient(player, payload)
end

-- Tunggu beberapa detik. Berhenti lebih awal jika guru menekan "Hentikan" (hasil false)
-- atau jika fungsi done() bernilai true (hasil true).
function Core.waitFor(seconds, done)
	local endsAt = os.clock() + seconds
	while os.clock() < endsAt do
		if Core.flags.stop then
			return false
		end
		if done and done() then
			return true
		end
		task.wait(0.1)
	end
	return true
end

function Core.nextQuestionId()
	questionCounter += 1
	return questionCounter
end

---------------------------------------------------------------------
-- PESERTA
---------------------------------------------------------------------
function Core.isRegistered(player)
	return player:GetAttribute("Registered") == true
end

-- Siswa terdaftar yang ikut menjawab. Jika startAt diberikan, hanya yang sudah
-- terdaftar sebelum soal dimulai.
function Core.participants(startAt)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local st = Core.stats[player]
		if st and Core.isRegistered(player) and (not startAt or st.activeFrom <= startAt) then
			table.insert(list, player)
		end
	end
	return list
end

function Core.displayName(player)
	local name = player:GetAttribute("Nama")
	local absen = player:GetAttribute("Absen")
	if name and absen then
		return string.format("%02d. %s", absen, name)
	end
	return player.DisplayName
end

function Core.teleport(player, cframe)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(cframe)
	end
end

function Core.rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

---------------------------------------------------------------------
-- STATISTIK & SKOR
---------------------------------------------------------------------
function Core.newStats()
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
		hintKey = nil,
		activeFrom = Core.now(),
	}
end

function Core.getSession(player)
	local s = Core.session[player]
	if not s then
		s = { correct = 0, answered = 0, score = 0, rounds = 0 }
		Core.session[player] = s
	end
	return s
end

function Core.updateLeaderstats(player)
	local st = Core.stats[player]
	local folder = player:FindFirstChild("leaderstats")
	if not st or not folder then
		return
	end
	folder.Poin.Value = st.score
	folder.Benar.Value = st.correct
	folder.Absen.Value = player:GetAttribute("Absen") or 0
	folder["Poin Rank"].Value = Core.PlayerData.Get(player).xp
end

function Core.sendStats(player)
	local st = Core.stats[player]
	if st then
		Core.send(player, { type = "Stats", score = st.score, streak = st.streak, hints = st.hints })
	end
end

function Core.resetRoundStats()
	for _, player in ipairs(Players:GetPlayers()) do
		Core.stats[player] = Core.newStats()
		Core.stats[player].activeFrom = 0
		Core.updateLeaderstats(player)
		Core.sendStats(player)
	end
end

local function mergeInto(target, extra)
	if extra then
		for key, value in pairs(extra) do
			target[key] = value
		end
	end
	return target
end

--[[
	Mencatat satu jawaban siswa dan mengirim hasilnya ke siswa tersebut.
	opts:
	  speed     (0..1) seberapa cepat menjawab (1 = sangat cepat)
	  speedMax  bonus kecepatan maksimal (default Config.MaxSpeedBonus)
	  boss      true jika soal bos (poin dikali)
	  penalty   pengurang poin (misal salah ketik di Pecahkan Sandi)
	  answered  false jika siswa tidak menjawab sama sekali
	  silent    true = tidak mengirim pesan Result
	  extra     tabel tambahan yang ikut dikirim ke client
]]
function Core.award(player, topicId, isCorrect, opts)
	opts = opts or {}
	local st = Core.stats[player]
	if not st then
		return 0
	end
	local session = Core.getSession(player)
	st.answered += 1
	session.answered += 1
	local topicStat = st.topics[topicId]
	if not topicStat then
		topicStat = { correct = 0, total = 0 }
		st.topics[topicId] = topicStat
	end
	topicStat.total += 1

	local gained, earnedHint = 0, false
	if isCorrect then
		st.correct += 1
		session.correct += 1
		topicStat.correct += 1
		st.streak += 1
		st.bestStreak = math.max(st.bestStreak, st.streak)
		local speed = math.clamp(opts.speed or 0, 0, 1)
		gained = Config.BasePoints
			+ math.floor((opts.speedMax or Config.MaxSpeedBonus) * speed)
			+ math.min(Config.StreakBonus * (st.streak - 1), Config.MaxStreakBonus)
			- (opts.penalty or 0)
		gained = math.max(gained, 20)
		if opts.boss then
			gained *= Config.BossMultiplier
		end
		st.score += gained
		session.score += gained
		if st.streak % Config.HintEveryStreak == 0 and st.hints < Config.MaxHints then
			st.hints += 1
			earnedHint = true
		end
	else
		st.streak = 0
	end
	Core.updateLeaderstats(player)
	if not opts.silent then
		Core.send(player, mergeInto({
			type = "Result",
			correct = isCorrect,
			answered = opts.answered ~= false,
			gained = gained,
			score = st.score,
			streak = st.streak,
			hints = st.hints,
			earnedHint = earnedHint,
			isBoss = opts.boss == true,
		}, opts.extra))
	end
	return gained
end

function Core.addBonus(player, amount, reason)
	local st = Core.stats[player]
	if not st then
		return
	end
	st.score += amount
	Core.getSession(player).score += amount
	Core.updateLeaderstats(player)
	Core.send(player, { type = "Bonus", amount = amount, reason = reason, score = st.score })
end

---------------------------------------------------------------------
-- SOAL & TAMPILAN
---------------------------------------------------------------------
function Core.correctOption(prepared)
	for _, option in ipairs(prepared.options or {}) do
		if option.pad == prepared.correctPad then
			return option
		end
	end
	return nil
end

-- Bantuan 50:50 untuk soal pilihan ganda: menghapus 2 jawaban salah
function Core.fiftyFifty(prepared, st)
	if prepared.kind ~= "PG" then
		return nil, "Bantuan 50:50 hanya untuk soal pilihan ganda."
	end
	if st.hintKey == prepared.id then
		return nil, "Bantuan sudah dipakai di soal ini."
	end
	st.hintKey = prepared.id
	local wrong = {}
	for _, option in ipairs(prepared.options) do
		if option.pad ~= prepared.correctPad then
			table.insert(wrong, option.pad)
		end
	end
	table.remove(wrong, math.random(1, #wrong))
	return { type = "5050", pads = wrong }
end

function Core.questionPayload(prepared, index, total, isBoss, endsAt, duration, extra)
	local topic = Config.GetTopic(prepared.topic)
	return mergeInto({
		type = "Question",
		id = prepared.id,
		index = index,
		total = total,
		text = prepared.text,
		kind = prepared.kind,
		options = prepared.options or {},
		endsAt = endsAt,
		duration = duration,
		topicName = topic.icon .. " " .. topic.name,
		topicColor = topic.color,
		isBoss = isBoss,
		mode = Core.currentMode and Core.currentMode.id or "kotak",
	}, extra)
end

function Core.revealPayload(prepared, counts, extra)
	local option = Core.correctOption(prepared)
	return mergeInto({
		type = "Reveal",
		correctPad = prepared.correctPad,
		correctLetter = option and option.letter or "",
		correctText = option and option.text or prepared.display or "",
		explanation = prepared.explanation,
		counts = counts or {},
		explainEndsAt = Core.now() + Config.RevealTime + Config.ExplanationTime,
	}, extra)
end

function Core.screenQuestion(prepared, index, total, isBoss, info)
	local topic = Config.GetTopic(prepared.topic)
	Core.arena:SetScreen({
		topic = topic.icon .. " " .. topic.name,
		number = isBoss and ("⚠ SOAL BOS ⚠  " .. index .. "/" .. total) or ("SOAL " .. index .. "/" .. total),
		question = prepared.text,
		info = info,
		accent = isBoss and Color3.fromRGB(255, 70, 70) or topic.color,
	})
end

function Core.screenReveal(prepared)
	local option = Core.correctOption(prepared)
	local answer
	if option then
		answer = (prepared.kind == "PG" and (option.letter .. ". ") or "") .. option.text
	else
		answer = prepared.display or ""
	end
	Core.arena:SetScreen({ timer = "0", info = "✔ Jawaban: " .. answer .. "\n📘 " .. (prepared.explanation or "") })
end

function Core.idleScreen(info, timer)
	Core.arena:SetScreen({
		topic = Config.GameSubtitle,
		number = "",
		timer = timer or "",
		question = Config.GameTitle,
		info = info,
		accent = Color3.fromRGB(70, 160, 255),
	})
end

return Core
