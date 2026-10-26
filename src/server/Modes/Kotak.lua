--[[
	MODE "LARI & PILIH"
	Soal muncul di layar besar. Siswa lari dan BERDIRI di kotak jawaban.
	Saat waktu habis, kotak yang salah jatuh ke Lubang Data.
]]

local Kotak = {}

function Kotak.StartCFrame(arena)
	return arena:GetStartCFrame()
end

local function ask(Core, q, index, total)
	local Config, arena, settings = Core.Config, Core.arena, Core.settings
	local isBoss = index == total and total >= 5
	local prepared = Core.Questions.Prepare(q, Config)
	prepared.id = Core.nextQuestionId()
	local duration = (prepared.kind == "BS" and Config.TrueFalseTime or settings.time) + (isBoss and 5 or 0)

	-- semua siswa kembali ke Garis Start agar adil
	for _, player in ipairs(Core.participants()) do
		Core.teleport(player, arena:GetStartCFrame())
		local st = Core.stats[player]
		st.choice, st.choiceTime = nil, nil
	end

	arena:SetQuestion(prepared)
	Core.current = prepared
	Core.phase = "Question"
	Core.flags.lock = false
	Core.hintProvider = function(_, st)
		return Core.fiftyFifty(prepared, st)
	end
	local startAt = Core.now()
	local endsAt = startAt + duration

	Core.broadcast(Core.questionPayload(prepared, index, total, isBoss, endsAt, duration), true)
	Core.screenQuestion(prepared, index, total, isBoss, prepared.kind == "BS"
		and "Pernyataan ini BENAR atau SALAH? Berdiri di kotak jawabanmu!"
		or "Lari dan BERDIRI di kotak jawaban yang benar sebelum waktu habis!")

	-- pantau posisi siswa sampai waktu habis
	while Core.now() < endsAt and not Core.flags.lock and not Core.flags.stop do
		local t = Core.now()
		for _, player in ipairs(Core.participants(startAt)) do
			local st = Core.stats[player]
			local root = Core.rootOf(player)
			local pad = root and arena:GetPadAt(root.Position) or nil
			if pad ~= st.choice then
				st.choice, st.choiceTime = pad, t
			end
		end
		arena:SetScreen({ timer = tostring(math.max(0, math.ceil(endsAt - t))) })
		task.wait(0.1)
	end
	Core.hintProvider = nil
	Core.current = nil
	if Core.flags.stop then
		return false
	end

	-- UNGKAP JAWABAN
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
			boss = isBoss,
			answered = st.choice ~= nil,
		})
	end
	Core.broadcast(Core.revealPayload(prepared, counts), true)
	arena:Reveal(prepared.correctPad, counts)
	Core.screenReveal(prepared)

	if not Core.waitFor(Config.RevealTime + Config.ExplanationTime) then
		return false
	end
	arena:ResetPads(false)
	return true
end

function Kotak.Prepare(Core)
	return Core.Questions.Pick(Core.settings.topic, Core.settings.count)
end

function Kotak.Run(Core, list)
	for index, q in ipairs(list) do
		if not ask(Core, q, index, #list) then
			break
		end
	end
	return #list
end

return Kotak
