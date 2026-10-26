--[[
	MODE "KUIS KILAT"
	Tombol jawaban muncul di layar setiap siswa. Jawab secepat mungkin!
	Jawaban tidak bisa diganti, jadi baca dengan teliti. Bonus kecepatan lebih besar.
]]

local Kilat = {}

function Kilat.StartCFrame(arena)
	return arena:GetStartCFrame()
end

local function ask(Core, q, index, total)
	local Config, arena = Core.Config, Core.arena
	local isBoss = index == total and total >= 5
	local prepared = Core.Questions.Prepare(q, Config)
	prepared.id = Core.nextQuestionId()
	local duration = (prepared.kind == "BS" and math.max(6, Config.KilatTime - 2) or Config.KilatTime) + (isBoss and 3 or 0)

	for _, player in ipairs(Core.participants()) do
		local st = Core.stats[player]
		st.choice, st.choiceTime = nil, nil
	end
	arena:SetQuestion(prepared)
	Core.current = prepared
	Core.phase = "Question"
	Core.flags.lock = false
	local startAt = Core.now()
	local endsAt = startAt + duration
	local valid = {}
	for _, option in ipairs(prepared.options) do
		valid[option.pad] = true
	end

	Core.hintProvider = function(_, st)
		if st.choice then
			return nil, "Kamu sudah menjawab soal ini."
		end
		return Core.fiftyFifty(prepared, st)
	end
	Core.answerHandler = function(player, questionId, pad)
		local st = Core.stats[player]
		if questionId ~= prepared.id or not st or st.choice or not valid[pad] or st.activeFrom > startAt then
			return
		end
		st.choice, st.choiceTime = pad, Core.now()
		Core.send(player, { type = "AnswerLocked", pad = pad })
	end

	Core.broadcast(Core.questionPayload(prepared, index, total, isBoss, endsAt, duration, { clickable = true }), true)
	Core.screenQuestion(prepared, index, total, isBoss, "⚡ KUIS KILAT: tekan tombol jawaban di layarmu secepat mungkin!")

	local function everyoneAnswered()
		local players = Core.participants(startAt)
		if #players == 0 then
			return false
		end
		for _, player in ipairs(players) do
			if not Core.stats[player].choice then
				return false
			end
		end
		return true
	end

	while Core.now() < endsAt and not Core.flags.lock and not Core.flags.stop and not everyoneAnswered() do
		arena:SetScreen({ timer = tostring(math.max(0, math.ceil(endsAt - Core.now()))) })
		task.wait(0.1)
	end
	Core.answerHandler = nil
	Core.hintProvider = nil
	Core.current = nil
	if Core.flags.stop then
		return false
	end

	Core.phase = "Reveal"
	local counts = { 0, 0, 0, 0 }
	local players = Core.participants(startAt)
	for _, player in ipairs(players) do
		local st = Core.stats[player]
		if st.choice then
			counts[st.choice] += 1
		end
	end
	for _, player in ipairs(players) do
		local st = Core.stats[player]
		Core.award(player, prepared.topic, st.choice == prepared.correctPad, {
			speed = 1 - ((st.choiceTime or endsAt) - startAt) / duration,
			speedMax = Config.KilatSpeedBonus,
			boss = isBoss,
			answered = st.choice ~= nil,
		})
	end
	Core.broadcast(Core.revealPayload(prepared, counts), true)
	arena:Reveal(prepared.correctPad, counts)
	Core.screenReveal(prepared)

	if not Core.waitFor(Config.RevealTime + Config.ExplanationTime - 2) then
		return false
	end
	arena:ResetPads(false)
	return true
end

function Kilat.Prepare(Core)
	return Core.Questions.Pick(Core.settings.topic, Core.settings.count)
end

function Kilat.Run(Core, list)
	for index, q in ipairs(list) do
		if not ask(Core, q, index, #list) then
			break
		end
	end
	return #list
end

return Kilat
