--[[
	MODE "LINTASAN FIREWALL"
	Balapan di lintasan langit. Setiap gerbang punya soal dan 4 pintu jawaban.
	- Pintu BENAR: jalurnya kokoh, lanjut ke lompatan & gerbang berikutnya.
	- Pintu SALAH: lantainya tembus, siswa jatuh dan kembali ke depan gerbang (poin gerbang itu hangus).
	Poin hanya didapat jika memilih pintu yang benar pada percobaan PERTAMA.
	Bonus untuk siswa yang paling cepat mencapai FINISH.
]]

local Firewall = {}

function Firewall.StartCFrame(arena)
	return arena:GetCourseStartCFrame()
end

local GATE_SPEED_WINDOW = 20 -- detik: makin cepat melewati gerbang, makin besar bonus

local function gatePayload(Core, prepared, gate, total)
	return Core.questionPayload(prepared, gate, total, false, 0, 0, { type = "Gate" })
end

function Firewall.Prepare(Core)
	local Questions = Core.Questions
	local gates = Core.arena.CourseInfo.gates
	local list = Questions.Pick(Core.settings.topic, gates)
	if #list < gates then
		-- topik terlalu sedikit soalnya: lengkapi dengan soal campuran
		local seen = {}
		for _, q in ipairs(list) do
			seen[q] = true
		end
		for _, q in ipairs(Questions.Pick("campuran", gates * 2)) do
			if #list >= gates then
				break
			end
			if not seen[q] then
				table.insert(list, q)
				seen[q] = true
			end
		end
	end
	return list
end

function Firewall.Run(Core, list)
	local Config, Questions, arena = Core.Config, Core.Questions, Core.arena
	local info = arena.CourseInfo
	local gates = info.gates

	local prepared = {}
	for gate = 1, gates do
		local p = Questions.Prepare(list[gate], Config)
		p.id = Core.nextQuestionId()
		prepared[gate] = p
		arena:SetupGate(gate, p)
	end

	local startAt = Core.now()
	local endsAt = startAt + Config.FirewallTime
	local racers = {}
	for _, player in ipairs(Core.participants()) do
		racers[player] = { gate = 1, failed = {}, arriveAt = startAt, lastZone = "start", lastGate = 0, finished = false }
		Core.teleport(player, arena:GetCourseStartCFrame())
	end

	Core.phase = "Race"
	Core.flags.lock = false
	arena:SetCourseBarrier(false)
	Core.broadcast({ type = "Race", endsAt = endsAt, gates = gates }, true)
	Core.idleScreen("LINTASAN FIREWALL sedang berlangsung di langit! Pilih pintu jawaban yang benar!")
	for player, racer in pairs(racers) do
		Core.send(player, gatePayload(Core, prepared[racer.gate], racer.gate, gates))
	end

	Core.hintProvider = function(player, st)
		local racer = racers[player]
		if not racer or racer.finished or racer.gate > gates then
			return nil, "Bantuan tidak bisa dipakai sekarang."
		end
		local result, err = Core.fiftyFifty(prepared[racer.gate], st)
		if result then
			result.gate = racer.gate
		end
		return result, err
	end

	local finishOrder = {}
	local function allFinished()
		for player, racer in pairs(racers) do
			if player.Parent and not racer.finished then
				return false
			end
		end
		return true
	end

	local function passGate(player, racer, gate)
		local p = prepared[gate]
		local option = Core.correctOption(p)
		local extra = {
			gate = gate,
			correctLetter = option.letter,
			correctText = option.text,
			explanation = p.explanation,
		}
		if not racer.failed[gate] then
			Core.award(player, p.topic, true, {
				speed = 1 - (Core.now() - racer.arriveAt) / GATE_SPEED_WINDOW,
				extra = extra,
			})
		end
		racer.gate = gate + 1
		racer.arriveAt = Core.now()
		if racer.gate <= gates then
			Core.send(player, gatePayload(Core, prepared[racer.gate], racer.gate, gates))
		else
			Core.send(player, { type = "GateDone" })
		end
	end

	while Core.now() < endsAt and not Core.flags.stop and not Core.flags.lock and not allFinished() do
		for player, racer in pairs(racers) do
			local root = player.Parent and Core.rootOf(player)
			if root and not racer.finished then
				local position = root.Position
				if position.Y < info.y - 8 then
					-- JATUH dari lintasan
					if racer.lastZone == "jalur" and racer.lastGate == racer.gate and not racer.failed[racer.gate] then
						racer.failed[racer.gate] = true
						local p = prepared[racer.gate]
						local option = Core.correctOption(p)
						Core.award(player, p.topic, false, { extra = {
							gate = racer.gate,
							correctLetter = option.letter,
							correctText = option.text,
							explanation = p.explanation,
						} })
					end
					if racer.lastZone == "gabung" or racer.lastZone == "lompat" then
						Core.teleport(player, arena:GetMergeCFrame(racer.lastGate))
					elseif racer.gate == 1 and racer.lastZone == "start" then
						Core.teleport(player, arena:GetCourseStartCFrame())
					else
						Core.teleport(player, arena:GetGateCFrame(math.min(racer.gate, gates)))
					end
				else
					local gate, zone = arena:CourseZone(position)
					if zone then
						racer.lastZone, racer.lastGate = zone, gate
						if (zone == "gabung" or zone == "lompat") and gate == racer.gate then
							passGate(player, racer, gate)
						elseif zone == "finish" and racer.gate > gates then
							racer.finished = true
							table.insert(finishOrder, player)
							local place = #finishOrder
							local bonus = (Config.FinishBonus[place] or 0) + Config.FinishAllBonus
							Core.addBonus(player, bonus, "Finish urutan ke-" .. place .. "!")
							arena:CelebrateFinish()
							Core.broadcast({ type = "Finished", name = Core.displayName(player), place = place })
						end
					end
				end
			end
		end
		arena:SetScreen({ timer = tostring(math.max(0, math.ceil(endsAt - Core.now()))) })
		task.wait(0.1)
	end
	Core.hintProvider = nil
	arena:SetCourseBarrier(true)

	if not Core.flags.stop then
		-- gerbang yang belum dilewati dihitung salah (tanpa pesan)
		for player, racer in pairs(racers) do
			if player.Parent then
				for gate = racer.gate, gates do
					Core.award(player, prepared[gate].topic, false, { answered = false, silent = true })
				end
			end
		end
		local names = {}
		for place, player in ipairs(finishOrder) do
			table.insert(names, place .. ". " .. Core.displayName(player))
		end
		Core.broadcast({ type = "RaceEnd", finishers = names })
		Core.waitFor(3)
	end
	arena:ResetCourse()
	return gates
end

return Firewall
