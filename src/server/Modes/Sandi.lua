--[[
	MODE "PECAHKAN SANDI"
	Siswa MENGETIK jawaban: soal isian singkat dan teka-teki Caesar Cipher.
	Ada beberapa kesempatan; setiap salah ketik mengurangi poin.
]]

local Sandi = {}

function Sandi.StartCFrame(arena)
	return arena:GetStartCFrame()
end

-- Petunjuk huruf: memperlihatkan sepertiga huruf pertama jawaban, contoh "R O _ _ _ _"
local function letterHint(display)
	local letters = {}
	for ch in string.gmatch(string.upper(display), "%w") do
		table.insert(letters, ch)
	end
	local reveal = math.max(1, math.ceil(#letters / 3))
	local parts = {}
	for i, ch in ipairs(letters) do
		table.insert(parts, i <= reveal and ch or "_")
	end
	return table.concat(parts, " ")
end

local function ask(Core, prepared, index, total)
	local Config, Questions, arena = Core.Config, Core.Questions, Core.arena
	local isBoss = index == total and total >= 5
	prepared.id = Core.nextQuestionId()
	local duration = Config.SandiTime + (isBoss and 10 or 0)

	for _, player in ipairs(Core.participants()) do
		Core.stats[player].sandi = { attempts = 0, done = false }
	end
	arena:ResetPads(true, "⌨ Ketik jawabanmu!")
	Core.current = prepared
	Core.phase = "Question"
	Core.flags.lock = false
	local startAt = Core.now()
	local endsAt = startAt + duration

	Core.hintProvider = function(_, st)
		if st.hintKey == prepared.id then
			return nil, "Petunjuk sudah dipakai di soal ini."
		end
		if st.sandi and st.sandi.done then
			return nil, "Kamu sudah selesai menjawab soal ini."
		end
		st.hintKey = prepared.id
		return { type = "huruf", text = letterHint(prepared.display) }
	end

	Core.textHandler = function(player, questionId, text)
		local st = Core.stats[player]
		if questionId ~= prepared.id or not st or not st.sandi or st.activeFrom > startAt then
			return { ok = false, message = "Soal ini sudah berakhir." }
		end
		local state = st.sandi
		if state.done then
			return { ok = false, message = "Kamu sudah selesai menjawab soal ini." }
		end
		text = string.sub(tostring(text or ""), 1, 40)
		if Questions.Normalize(text) == "" then
			return { ok = false, message = "Ketik jawabanmu dulu ya!" }
		end
		state.attempts += 1
		if Questions.CheckIsian(prepared, text) then
			state.done = true
			state.solved = true
			local gained = Core.award(player, prepared.topic, true, {
				speed = 1 - (Core.now() - startAt) / duration,
				boss = isBoss,
				penalty = (state.attempts - 1) * Config.SandiRetryPenalty,
			})
			return { ok = true, correct = true, gained = gained }
		end
		local left = Config.SandiAttempts - state.attempts
		if left <= 0 then
			state.done = true
			Core.award(player, prepared.topic, false, {})
			return { ok = true, correct = false, attemptsLeft = 0 }
		end
		return { ok = true, correct = false, attemptsLeft = left }
	end

	Core.broadcast(Core.questionPayload(prepared, index, total, isBoss, endsAt, duration, {
		attempts = Config.SandiAttempts,
		isCipher = prepared.isCipher == true,
		cipherText = prepared.cipherText,
	}), true)
	Core.screenQuestion(prepared, index, total, isBoss, "🔐 PECAHKAN SANDI: ketik jawabanmu di kotak yang muncul di layarmu!")

	local function everyoneDone()
		local players = Core.participants(startAt)
		if #players == 0 then
			return false
		end
		for _, player in ipairs(players) do
			if not Core.stats[player].sandi.done then
				return false
			end
		end
		return true
	end

	while Core.now() < endsAt and not Core.flags.lock and not Core.flags.stop and not everyoneDone() do
		arena:SetScreen({ timer = tostring(math.max(0, math.ceil(endsAt - Core.now()))) })
		task.wait(0.1)
	end
	Core.textHandler = nil
	Core.hintProvider = nil
	Core.current = nil
	if Core.flags.stop then
		return false
	end

	Core.phase = "Reveal"
	local solved = 0
	for _, player in ipairs(Core.participants(startAt)) do
		local state = Core.stats[player].sandi
		if state.solved then
			solved += 1
		elseif not state.done then
			-- belum selesai saat waktu habis = salah
			Core.award(player, prepared.topic, false, { answered = state.attempts > 0 })
			state.done = true
		end
	end
	Core.broadcast(Core.revealPayload(prepared, nil, { solved = solved, kind = "ISIAN" }), true)
	Core.screenReveal(prepared)

	return Core.waitFor(Config.RevealTime + Config.ExplanationTime)
end

function Sandi.Prepare(Core)
	return Core.Questions.PickIsian(Core.settings.topic, Core.settings.count)
end

function Sandi.Run(Core, list)
	for index, prepared in ipairs(list) do
		if not ask(Core, prepared, index, #list) then
			break
		end
	end
	Core.arena:ResetPads(true)
	return #list
end

return Sandi
