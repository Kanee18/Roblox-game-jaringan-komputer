--[[
	MapBuilder: membangun arena kuis secara otomatis.

	Arena disimpan di Workspace > ArenaKuis. Jika folder itu sudah ada (misalnya
	Anda membangunnya di mode edit lalu menghias sendiri), arena lama dipakai apa adanya.
	Untuk membangun arena di mode edit agar bisa dihias, jalankan di Command Bar:
	    require(game.ServerScriptService.QuizServer.MapBuilder).Build()

	Tata letak (dilihat dari atas, sumbu Z):
	    z = -16      Layar besar (pertanyaan)
	    z = -11..11  4 kotak jawaban A B C D (di bawahnya "Lubang Data")
	    z =  11..35  Garis Start (tempat pemain menunggu soal)
	    z =  35..99  Lobi + Zona Materi + Podium Juara
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("QuizShared")
local Config = require(Shared:WaitForChild("Config"))
local Materi = require(Shared:WaitForChild("Materi"))

local MapBuilder = {}

local ARENA_NAME = "ArenaKuis"
local PAD_X = { -33, -11, 11, 33 }
local PAD_SIZE = Vector3.new(22, 2, 22)
local IDLE_PAD_COLOR = Color3.fromRGB(70, 75, 95)
local DARK = Color3.fromRGB(18, 20, 34)
local WHITE = Color3.new(1, 1, 1)

---------------------------------------------------------------------
-- Helper pembuat Instance
---------------------------------------------------------------------
local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function part(props, parent)
	props.Anchored = true
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.Material == nil then
		props.Material = Enum.Material.SmoothPlastic
	end
	return make("Part", props, parent)
end

local function surfaceGui(target, face, pixelsPerStud)
	return make("SurfaceGui", {
		Name = "Gui",
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = pixelsPerStud,
		LightInfluence = 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, target)
end

local function label(parent, props)
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local maxSize = defaults.MaxTextSize
	defaults.MaxTextSize = nil
	local inst = make("TextLabel", defaults, parent)
	if maxSize then
		make("UITextSizeConstraint", { MaxTextSize = maxSize }, inst)
	end
	return inst
end

local function confettiEmitter(parent)
	return make("ParticleEmitter", {
		Name = "Konfeti",
		Enabled = false,
		EmissionDirection = Enum.NormalId.Top,
		Rate = 0,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(30, 50),
		SpreadAngle = Vector2.new(45, 45),
		Acceleration = Vector3.new(0, -35, 0),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-300, 300),
		Size = NumberSequence.new(0.6),
		LightEmission = 0.3,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 90, 255)),
		}),
	}, parent)
end

---------------------------------------------------------------------
-- MEMBANGUN ARENA BARU
---------------------------------------------------------------------
local function buildArena()
	local arena = make("Folder", { Name = ARENA_NAME }, nil)

	-- LANTAI ----------------------------------------------------------
	local floors = make("Folder", { Name = "Lantai" }, arena)
	part({ Name = "GarisStart", Size = Vector3.new(100, 2, 24), Position = Vector3.new(0, -1, 23),
		Color = Color3.fromRGB(34, 40, 72) }, floors)
	part({ Name = "Lobi", Size = Vector3.new(100, 2, 64), Position = Vector3.new(0, -1, 67),
		Color = Color3.fromRGB(26, 30, 52) }, floors)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "SampingKotak", Size = Vector3.new(6, 2, 23), Position = Vector3.new(47 * side, -1, -0.5),
			Color = DARK }, floors)
	end
	-- garis neon pembatas start
	part({ Name = "GarisNeon", Size = Vector3.new(88, 0.2, 0.6), Position = Vector3.new(0, 0.05, 11.3),
		Color = WHITE, Material = Enum.Material.Neon, CanCollide = false }, floors)
	local startLabel = part({ Name = "TulisanStart", Size = Vector3.new(40, 0.1, 5), Position = Vector3.new(0, 0.02, 15),
		Transparency = 1, CanCollide = false }, floors)
	label(surfaceGui(startLabel, Enum.NormalId.Top, 20), {
		Size = UDim2.fromScale(1, 1), Text = "▲ LARI KE KOTAK JAWABAN ▲",
		TextColor3 = Color3.fromRGB(150, 220, 255), TextTransparency = 0.2,
	})
	-- garis grid neon di lantai lobi
	for i = -2, 2 do
		part({ Name = "Grid", Size = Vector3.new(0.3, 0.1, 64), Position = Vector3.new(i * 20, 0.02, 67),
			Color = Color3.fromRGB(60, 120, 255), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.4 }, floors)
	end
	for i = 0, 3 do
		part({ Name = "Grid", Size = Vector3.new(100, 0.1, 0.3), Position = Vector3.new(0, 0.02, 40 + i * 18),
			Color = Color3.fromRGB(60, 120, 255), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.4 }, floors)
	end

	-- KOTAK JAWABAN ---------------------------------------------------
	local pads = make("Folder", { Name = "KotakJawaban" }, arena)
	for i = 1, 4 do
		local pad = part({ Name = "Pad" .. i, Size = PAD_SIZE, Position = Vector3.new(PAD_X[i], -1, 0),
			Color = Config.PadColors[i] }, pads)
		confettiEmitter(pad)
		make("PointLight", { Name = "Cahaya", Range = 18, Brightness = 0, Color = WHITE }, pad)

		-- huruf besar melayang di atas kotak
		local billboard = make("BillboardGui", { Name = "Huruf", Size = UDim2.fromScale(8, 8),
			StudsOffset = Vector3.new(0, 11, 0), LightInfluence = 0, MaxDistance = 250 }, pad)
		label(billboard, { Name = "Teks", Size = UDim2.fromScale(1, 1), Text = Config.PadLetters[i],
			TextStrokeTransparency = 0, TextStrokeColor3 = DARK })

		-- papan jawaban di ujung belakang kotak
		local sign = part({ Name = "Papan" .. i, Size = Vector3.new(21, 7, 0.6), Position = Vector3.new(PAD_X[i], 4.6, -11.6),
			Color = DARK, CanCollide = false }, pads)
		local gui = surfaceGui(sign, Enum.NormalId.Back, 40)
		local bg = make("Frame", { Name = "Latar", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Config.PadColors[i],
			BorderSizePixel = 0 }, gui)
		make("UIStroke", { Thickness = 8, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bg)
		label(bg, { Name = "Huruf", Size = UDim2.fromScale(0.2, 0.9), Position = UDim2.fromScale(0.02, 0.05),
			Text = Config.PadLetters[i], Font = Enum.Font.FredokaOne })
		label(bg, { Name = "Jawaban", Size = UDim2.fromScale(0.74, 0.7), Position = UDim2.fromScale(0.23, 0.08),
			Text = "", MaxTextSize = 70 })
		label(bg, { Name = "Jumlah", Size = UDim2.fromScale(0.74, 0.2), Position = UDim2.fromScale(0.23, 0.78),
			Text = "", TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.Gotham })
	end
	-- garis pembatas antar kotak (tidak bisa diinjak, hanya hiasan)
	for i = 1, 3 do
		part({ Name = "Pembatas", Size = Vector3.new(0.5, 0.25, 22), Position = Vector3.new((PAD_X[i] + PAD_X[i + 1]) / 2, 0.1, 0),
			Color = WHITE, Material = Enum.Material.Neon, CanCollide = false }, pads)
	end

	-- LUBANG DATA (tempat jatuh jika salah) ---------------------------
	local pit = part({ Name = "LubangData", Size = Vector3.new(130, 2, 60), Position = Vector3.new(0, -46, -6),
		Color = Color3.fromRGB(0, 170, 255), Material = Enum.Material.Neon, Transparency = 0.25 }, arena)
	label(surfaceGui(pit, Enum.NormalId.Top, 6), { Size = UDim2.fromScale(1, 1),
		Text = "01001 UPS! KAMU JATUH KE LUBANG DATA 10110", TextTransparency = 0.3, TextColor3 = DARK })

	-- LAYAR BESAR -----------------------------------------------------
	local screen = part({ Name = "Layar", Size = Vector3.new(92, 34, 1), Position = Vector3.new(0, 29, -16),
		Color = Color3.fromRGB(10, 12, 24) }, arena)
	local sgui = surfaceGui(screen, Enum.NormalId.Back, 20)
	local frame = make("Frame", { Name = "Isi", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 18, 38),
		BorderSizePixel = 0 }, sgui)
	make("UIStroke", { Thickness = 14, Color = Color3.fromRGB(70, 160, 255), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	local header = make("Frame", { Name = "Header", Size = UDim2.fromScale(1, 0.15), BackgroundColor3 = Color3.fromRGB(70, 160, 255),
		BorderSizePixel = 0 }, frame)
	label(header, { Name = "Topik", Size = UDim2.fromScale(0.55, 0.8), Position = UDim2.fromScale(0.02, 0.1),
		TextXAlignment = Enum.TextXAlignment.Left, Text = Config.GameSubtitle })
	label(header, { Name = "Nomor", Size = UDim2.fromScale(0.25, 0.8), Position = UDim2.fromScale(0.58, 0.1), Text = "" })
	label(header, { Name = "Waktu", Size = UDim2.fromScale(0.14, 0.9), Position = UDim2.fromScale(0.85, 0.05), Text = "",
		Font = Enum.Font.FredokaOne })
	label(frame, { Name = "Pertanyaan", Size = UDim2.fromScale(0.94, 0.55), Position = UDim2.fromScale(0.03, 0.18),
		Text = Config.GameTitle, Font = Enum.Font.FredokaOne, MaxTextSize = 110 })
	label(frame, { Name = "Info", Size = UDim2.fromScale(0.94, 0.22), Position = UDim2.fromScale(0.03, 0.75),
		Text = "Selamat datang! Baca Zona Materi di lobi sambil menunggu kuis dimulai.", Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(190, 220, 255), MaxTextSize = 48 })

	local titleBar = part({ Name = "JudulGame", Size = Vector3.new(60, 6, 1), Position = Vector3.new(0, 50, -16),
		Color = Color3.fromRGB(255, 80, 200), Material = Enum.Material.Neon }, arena)
	label(surfaceGui(titleBar, Enum.NormalId.Back, 20), { Size = UDim2.fromScale(1, 1),
		Text = "🌐 " .. Config.GameTitle .. " 🌐", Font = Enum.Font.FredokaOne, TextColor3 = WHITE,
		TextStrokeTransparency = 0.3 })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "TiangLayar", Size = Vector3.new(3, 100, 3), Position = Vector3.new(47.5 * side, 4, -16),
			Color = Color3.fromRGB(40, 45, 70), Material = Enum.Material.Metal }, arena)
		part({ Name = "LampuTiang", Size = Vector3.new(3.2, 60, 0.6), Position = Vector3.new(47.5 * side, 20, -14.4),
			Color = Color3.fromRGB(70, 160, 255), Material = Enum.Material.Neon, CanCollide = false }, arena)
	end

	-- DINDING ---------------------------------------------------------
	local walls = make("Folder", { Name = "Dinding" }, arena)
	local function invisibleWall(name, size, pos)
		part({ Name = name, Size = size, Position = pos, Transparency = 1 }, walls)
	end
	invisibleWall("BatasDepan", Vector3.new(100, 60, 1), Vector3.new(0, 20, -12.5))
	invisibleWall("BatasBelakang", Vector3.new(100, 60, 1), Vector3.new(0, 20, 99.5))
	invisibleWall("BatasKiri", Vector3.new(1, 60, 113), Vector3.new(-50.5, 20, 43.5))
	invisibleWall("BatasKanan", Vector3.new(1, 60, 113), Vector3.new(50.5, 20, 43.5))
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "DindingLobi", Size = Vector3.new(1, 18, 64), Position = Vector3.new(50.5 * side, 9, 67),
			Color = Color3.fromRGB(30, 36, 66) }, walls)
		part({ Name = "LisNeon", Size = Vector3.new(0.4, 0.4, 64), Position = Vector3.new(49.9 * side, 17.5, 67),
			Color = Color3.fromRGB(255, 80, 200), Material = Enum.Material.Neon, CanCollide = false }, walls)
	end
	part({ Name = "DindingBelakang", Size = Vector3.new(102, 18, 1), Position = Vector3.new(0, 9, 100.5),
		Color = Color3.fromRGB(30, 36, 66) }, walls)

	-- ZONA MATERI (papan materi di dinding kiri & kanan lobi) ---------
	local boards = make("Folder", { Name = "ZonaMateri" }, arena)
	local boardTopics = {}
	for _, topic in ipairs(Config.Topics) do
		if topic.id ~= "campuran" then
			table.insert(boardTopics, topic)
		end
	end
	for index, topic in ipairs(boardTopics) do
		local side = index <= 3 and -1 or 1
		local z = 46 + ((index - 1) % 3) * 20
		local board = part({ Name = "Materi_" .. topic.id, Size = Vector3.new(0.4, 12, 18),
			Position = Vector3.new(49.6 * side, 7.5, z), Color = DARK }, boards)
		board:SetAttribute("TopicId", topic.id)
		local face = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
		local gui = surfaceGui(board, face, 60)
		local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 20, 40),
			BorderSizePixel = 0 }, gui)
		make("UIStroke", { Thickness = 10, Color = topic.color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bg)
		local titleFrame = make("Frame", { Size = UDim2.fromScale(1, 0.15), BackgroundColor3 = topic.color,
			BorderSizePixel = 0 }, bg)
		label(titleFrame, { Size = UDim2.fromScale(0.96, 0.85), Position = UDim2.fromScale(0.02, 0.08),
			Text = topic.icon .. "  " .. string.upper(topic.name), Font = Enum.Font.FredokaOne, TextColor3 = DARK })
		local body = make("Frame", { Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.18),
			BackgroundTransparency = 1 }, bg)
		make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, body)
		for order, point in ipairs(Materi[topic.id] or {}) do
			label(body, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false,
				TextSize = 26, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = order, Text = "• " .. point, TextColor3 = Color3.fromRGB(225, 235, 255) })
		end
		make("ProximityPrompt", { Name = "BacaMateri", ActionText = "Baca Materi", ObjectText = topic.name,
			HoldDuration = 0, MaxActivationDistance = 14, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E }, board)
		-- lampu sorot papan
		part({ Name = "LampuPapan", Size = Vector3.new(1.2, 0.4, 18), Position = Vector3.new(49.2 * side, 14, z),
			Color = topic.color, Material = Enum.Material.Neon, CanCollide = false }, boards)
	end
	local zoneSign = part({ Name = "TulisanZonaMateri", Size = Vector3.new(30, 0.1, 6), Position = Vector3.new(0, 0.03, 42),
		Transparency = 1, CanCollide = false }, boards)
	label(surfaceGui(zoneSign, Enum.NormalId.Top, 20), { Size = UDim2.fromScale(1, 1), Rotation = 180,
		Text = "📚 ZONA MATERI: baca papan di dinding! 📚", TextColor3 = Color3.fromRGB(255, 220, 90), TextTransparency = 0.15 })

	-- PODIUM & PAPAN JUARA --------------------------------------------
	local podium = make("Folder", { Name = "Podium" }, arena)
	local podiumData = {
		{ x = 0, h = 5, color = Color3.fromRGB(255, 205, 50), text = "1" },
		{ x = -8, h = 3.5, color = Color3.fromRGB(200, 205, 220), text = "2" },
		{ x = 8, h = 2.5, color = Color3.fromRGB(215, 135, 70), text = "3" },
	}
	for rank, data in ipairs(podiumData) do
		local block = part({ Name = "Juara" .. rank, Size = Vector3.new(7, data.h, 7), Position = Vector3.new(data.x, data.h / 2, 90),
			Color = data.color, Material = Enum.Material.Metal }, podium)
		confettiEmitter(block)
		label(surfaceGui(block, Enum.NormalId.Front, 30), { Size = UDim2.fromScale(1, 1), Text = data.text,
			Font = Enum.Font.FredokaOne, TextColor3 = DARK })
	end
	local fame = part({ Name = "PapanJuara", Size = Vector3.new(34, 13, 0.4), Position = Vector3.new(0, 10, 99.6),
		Color = DARK }, podium)
	local fameGui = surfaceGui(fame, Enum.NormalId.Front, 30)
	local fameBg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 16, 40),
		BorderSizePixel = 0 }, fameGui)
	make("UIStroke", { Thickness = 8, Color = Color3.fromRGB(255, 205, 50), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, fameBg)
	label(fameBg, { Name = "Judul", Size = UDim2.fromScale(0.96, 0.18), Position = UDim2.fromScale(0.02, 0.03),
		Text = "🏆 JUARA RONDE TERAKHIR 🏆", Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 205, 50) })
	label(fameBg, { Name = "Daftar", Size = UDim2.fromScale(0.9, 0.74), Position = UDim2.fromScale(0.05, 0.23),
		Text = "Belum ada juara. Ayo jadi yang pertama!", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, MaxTextSize = 34 })

	-- SPAWN -----------------------------------------------------------
	make("SpawnLocation", { Name = "SpawnLobi", Anchored = true, Size = Vector3.new(12, 1, 12), Position = Vector3.new(0, 0.5, 60),
		Color = Color3.fromRGB(70, 160, 255), Material = Enum.Material.Neon, Transparency = 0.3, Neutral = true, Duration = 0,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, arena)

	-- DEKORASI: rak server, globe internet, kabel & paket data ---------
	local deco = make("Folder", { Name = "Dekorasi" }, arena)
	local rackSpots = { Vector3.new(-44, 0, 96), Vector3.new(44, 0, 96), Vector3.new(-44, 0, 38), Vector3.new(44, 0, 38) }
	for _, spot in ipairs(rackSpots) do
		part({ Name = "RakServer", Size = Vector3.new(5, 12, 4), Position = spot + Vector3.new(0, 6, 0),
			Color = Color3.fromRGB(22, 24, 30), Material = Enum.Material.Metal }, deco)
		for row = 1, 5 do
			part({ Name = "LampuRak", Size = Vector3.new(4, 0.3, 0.2),
				Position = spot + Vector3.new(0, row * 2, spot.Z > 60 and -2.05 or 2.05),
				Color = (row % 2 == 0) and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(70, 160, 255),
				Material = Enum.Material.Neon, CanCollide = false }, deco)
		end
	end
	local pedestal = part({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 10, 10),
		CFrame = CFrame.new(0, 1, 74) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 45, 70),
		Material = Enum.Material.Metal }, deco)
	pedestal:SetAttribute("Hiasan", true)
	local globe = part({ Name = "GlobeInternet", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8),
		Position = Vector3.new(0, 8, 74), Color = Color3.fromRGB(60, 200, 255), Material = Enum.Material.ForceField,
		CanCollide = false }, deco)
	make("PointLight", { Range = 24, Brightness = 2, Color = Color3.fromRGB(60, 200, 255) }, globe)
	local globeTag = make("BillboardGui", { Size = UDim2.fromScale(10, 2), StudsOffset = Vector3.new(0, 6, 0), LightInfluence = 0 }, globe)
	label(globeTag, { Size = UDim2.fromScale(1, 1), Text = "INTERNET", Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.fromRGB(150, 230, 255), TextStrokeTransparency = 0.2 })
	-- kabel neon dari rak server menuju globe
	for _, spot in ipairs(rackSpots) do
		local from = Vector3.new(spot.X, 0.1, spot.Z)
		local to = Vector3.new(0, 0.1, 74)
		local length = (to - from).Magnitude
		local cable = part({ Name = "Kabel", Size = Vector3.new(0.4, 0.15, length),
			CFrame = CFrame.lookAt((from + to) / 2, to), Color = Color3.fromRGB(255, 80, 200),
			Material = Enum.Material.Neon, CanCollide = false }, deco)
		cable:SetAttribute("Dari", from)
		cable:SetAttribute("Ke", to)
	end

	-- PENCAHAYAAN -----------------------------------------------------
	local lamps = make("Folder", { Name = "Lampu" }, arena)
	for _, pos in ipairs({ Vector3.new(-30, 16, 23), Vector3.new(30, 16, 23), Vector3.new(0, 16, 55), Vector3.new(0, 16, 85) }) do
		local lamp = part({ Name = "Lampu", Size = Vector3.new(1, 1, 1), Position = pos, Transparency = 1, CanCollide = false }, lamps)
		make("PointLight", { Range = 40, Brightness = 1.2, Color = Color3.fromRGB(200, 220, 255) }, lamp)
	end

	arena.Parent = workspace
	return arena
end

---------------------------------------------------------------------
-- Pengaturan dunia (langit, cahaya, hapus baseplate bawaan)
---------------------------------------------------------------------
local function setupWorld(arena)
	Lighting.ClockTime = Config.ClockTime
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 150)
	Lighting.Ambient = Color3.fromRGB(60, 60, 80)
	if not Lighting:FindFirstChild("BloomKuis") then
		make("BloomEffect", { Name = "BloomKuis", Intensity = 0.6, Size = 30, Threshold = 1.4 }, Lighting)
	end
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		make("Atmosphere", { Density = 0.25, Offset = 0.1, Color = Color3.fromRGB(200, 170, 255),
			Decay = Color3.fromRGB(90, 70, 140), Glare = 0.2, Haze = 1 }, Lighting)
	end
	-- Baseplate & SpawnLocation bawaan template Roblox menghalangi Lubang Data, jadi dihapus.
	for _, child in ipairs(workspace:GetChildren()) do
		if child ~= arena and (child.Name == "Baseplate" or child:IsA("SpawnLocation") or child.Name == "PetunjukAwal") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------
-- Objek Arena: dipakai server untuk mengontrol tampilan
---------------------------------------------------------------------
local Arena = {}
Arena.__index = Arena

local function requireChild(parent, path)
	local current = parent
	for _, name in ipairs(string.split(path, "/")) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local REQUIRED = {
	"KotakJawaban/Pad1", "KotakJawaban/Pad2", "KotakJawaban/Pad3", "KotakJawaban/Pad4",
	"KotakJawaban/Papan1", "KotakJawaban/Papan2", "KotakJawaban/Papan3", "KotakJawaban/Papan4",
	"LubangData", "Layar/Gui/Isi", "Podium/PapanJuara/Gui",
	"Podium/Juara1", "Podium/Juara2", "Podium/Juara3",
}

local function isValid(arena)
	for _, path in ipairs(REQUIRED) do
		if not requireChild(arena, path) then
			warn("[NetQuest] ArenaKuis tidak lengkap (" .. path .. " hilang), arena dibangun ulang.")
			return false
		end
	end
	return true
end

function Arena.new(folder)
	local self = setmetatable({}, Arena)
	self.Folder = folder
	self.Pads, self.Signs = {}, {}
	for i = 1, 4 do
		self.Pads[i] = requireChild(folder, "KotakJawaban/Pad" .. i)
		self.Signs[i] = requireChild(folder, "KotakJawaban/Papan" .. i .. "/Gui/Latar")
	end
	self.Pit = folder.LubangData
	local screen = requireChild(folder, "Layar/Gui/Isi")
	self.Screen = {
		Frame = screen,
		Topic = requireChild(screen, "Header/Topik"),
		Number = requireChild(screen, "Header/Nomor"),
		Timer = requireChild(screen, "Header/Waktu"),
		Header = screen:FindFirstChild("Header"),
		Question = screen:FindFirstChild("Pertanyaan"),
		Info = screen:FindFirstChild("Info"),
	}
	self.FameList = requireChild(folder, "Podium/PapanJuara/Gui")
	self.FameList = self.FameList and self.FameList:FindFirstChild("Daftar", true)
	self.Podiums = {}
	for i = 1, 3 do
		self.Podiums[i] = requireChild(folder, "Podium/Juara" .. i)
	end
	self.ActivePads = {}
	self.PadColors = {}
	return self
end

-- Posisi acak di Garis Start (menghadap layar)
function Arena:GetStartCFrame()
	return CFrame.new(math.random(-40, 40), 3.5, math.random(15, 31))
end

function Arena:GetLobbyCFrame()
	return CFrame.new(math.random(-12, 12), 3.5, math.random(52, 66))
end

function Arena:GetPodiumCFrame(rank)
	local block = self.Podiums[rank]
	-- CFrame.new tanpa rotasi = menghadap -Z (ke arah lobi & layar)
	return CFrame.new(block.Position + Vector3.new(0, block.Size.Y / 2 + 3, 0))
end

-- Mengembalikan nomor kotak (1-4) tempat posisi berada, atau nil
function Arena:GetPadAt(position)
	for i, pad in ipairs(self.Pads) do
		if self.ActivePads[i] then
			local rel = pad.CFrame:PointToObjectSpace(position)
			local half = pad.Size / 2
			if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y > -half.Y and rel.Y < 10 then
				return i
			end
		end
	end
	return nil
end

function Arena:SetScreen(data)
	local s = self.Screen
	if data.topic then s.Topic.Text = data.topic end
	if data.number then s.Number.Text = data.number end
	if data.timer then s.Timer.Text = data.timer end
	if data.question then s.Question.Text = data.question end
	if data.info then s.Info.Text = data.info end
	if data.accent and s.Header then
		s.Header.BackgroundColor3 = data.accent
	end
end

local function setPadSolid(pad, color)
	pad.CanCollide = true
	pad.Transparency = 0
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = color
	local light = pad:FindFirstChild("Cahaya")
	if light then
		light.Brightness = 0
	end
end

-- Menampilkan soal di kotak jawaban & papan
function Arena:SetQuestion(prepared)
	for i = 1, 4 do
		self.ActivePads[i] = false
		self.PadColors[i] = IDLE_PAD_COLOR
	end
	for _, option in ipairs(prepared.options) do
		self.ActivePads[option.pad] = true
		self.PadColors[option.pad] = option.color
	end
	for i, pad in ipairs(self.Pads) do
		setPadSolid(pad, self.PadColors[i])
		local sign = self.Signs[i]
		local billboard = pad:FindFirstChild("Huruf")
		local option
		for _, o in ipairs(prepared.options) do
			if o.pad == i then
				option = o
			end
		end
		sign.BackgroundColor3 = self.PadColors[i]
		sign.Jumlah.Text = ""
		if option then
			sign.Huruf.Text = option.letter
			sign.Jawaban.Text = option.text
			if billboard then
				billboard.Enabled = true
				billboard.Teks.Text = option.letter
				billboard.Teks.TextColor3 = option.color:Lerp(WHITE, 0.35)
			end
		else
			sign.Huruf.Text = ""
			sign.Jawaban.Text = "—"
			if billboard then
				billboard.Enabled = false
			end
		end
	end
end

-- Mengungkap jawaban: kotak salah jatuh, kotak benar bersinar + konfeti
function Arena:Reveal(correctPad, counts)
	for i, pad in ipairs(self.Pads) do
		local sign = self.Signs[i]
		if self.ActivePads[i] then
			sign.Jumlah.Text = "👥 " .. tostring(counts[i] or 0) .. " pemain"
		end
		if i == correctPad then
			pad.Material = Enum.Material.Neon
			local light = pad:FindFirstChild("Cahaya")
			if light then
				light.Brightness = 3
			end
			local confetti = pad:FindFirstChild("Konfeti")
			if confetti then
				confetti:Emit(120)
			end
			sign.Jawaban.Text = "✔ " .. sign.Jawaban.Text
		else
			pad.CanCollide = false
			pad.Transparency = 0.8
			pad.Color = DARK
			sign.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		end
	end
end

-- Mengembalikan semua kotak menjadi padat (setelah penjelasan / saat lobi)
function Arena:ResetPads(idle)
	for i, pad in ipairs(self.Pads) do
		local color = self.PadColors[i] or IDLE_PAD_COLOR
		if idle then
			color = Config.PadColors[i]
			self.ActivePads[i] = false
			local sign = self.Signs[i]
			sign.BackgroundColor3 = color
			sign.Huruf.Text = Config.PadLetters[i]
			sign.Jawaban.Text = "Menunggu soal..."
			sign.Jumlah.Text = ""
			local billboard = pad:FindFirstChild("Huruf")
			if billboard then
				billboard.Enabled = true
				billboard.Teks.Text = Config.PadLetters[i]
				billboard.Teks.TextColor3 = WHITE
			end
		end
		setPadSolid(pad, color)
	end
end

function Arena:SetHallOfFame(ranking)
	if not self.FameList then
		return
	end
	local medals = { "🥇", "🥈", "🥉", "4.", "5." }
	local lines = {}
	for i = 1, math.min(5, #ranking) do
		local r = ranking[i]
		table.insert(lines, string.format("%s  %s  —  %d poin (%d/%d benar)", medals[i], r.name, r.score, r.correct, r.total))
	end
	self.FameList.Text = #lines > 0 and table.concat(lines, "\n") or "Belum ada juara."
end

function Arena:CelebratePodium()
	for _, block in ipairs(self.Podiums) do
		local emitter = block:FindFirstChild("Konfeti")
		if emitter then
			emitter:Emit(100)
		end
	end
end

-- Pemain yang jatuh ke Lubang Data dikembalikan ke Garis Start
function Arena:ConnectPit()
	local cooldown = {}
	self.Pit.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or cooldown[player] then
			return
		end
		cooldown[player] = true
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(self:GetStartCFrame())
		end
		task.delay(1, function()
			cooldown[player] = nil
		end)
	end)
end

-- Animasi hiasan (globe berputar, paket data berjalan di kabel)
function Arena:StartDecorations()
	local deco = self.Folder:FindFirstChild("Dekorasi")
	if not deco then
		return
	end
	local globe = deco:FindFirstChild("GlobeInternet")
	if globe then
		local base = globe.CFrame
		local angle = 0
		RunService.Heartbeat:Connect(function(dt)
			angle += dt * 0.6
			globe.CFrame = base * CFrame.new(0, math.sin(angle * 1.5) * 0.8, 0) * CFrame.Angles(0, angle, 0)
		end)
	end
	for _, cable in ipairs(deco:GetChildren()) do
		local from, to = cable:GetAttribute("Dari"), cable:GetAttribute("Ke")
		if cable.Name == "Kabel" and from and to then
			for n = 0, 1 do
				local packet = part({ Name = "PaketData", Size = Vector3.new(0.9, 0.9, 0.9), Position = from + Vector3.new(0, 0.6, 0),
					Color = Color3.fromRGB(255, 255, 140), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false,
					CanTouch = false }, deco)
				local info = TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
				local tween = TweenService:Create(packet, info, { Position = to + Vector3.new(0, 0.6, 0) })
				task.delay(n * 2 + math.random(), function()
					tween:Play()
				end)
			end
		end
	end
end

---------------------------------------------------------------------
-- FUNGSI UTAMA
---------------------------------------------------------------------
function MapBuilder.Build()
	local folder = workspace:FindFirstChild(ARENA_NAME)
	if folder and not isValid(folder) then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = buildArena()
	end
	setupWorld(folder)
	return Arena.new(folder)
end

return MapBuilder
