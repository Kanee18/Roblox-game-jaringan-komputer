--[[
	MapBuilder: membangun seluruh dunia NET QUEST secara otomatis.

	Dunia disimpan di Workspace > ArenaKuis (+ Terrain rumput & kolam). Jika folder itu sudah ada
	(misalnya Anda membangunnya di mode edit lalu menghias sendiri), dunia lama dipakai apa adanya.
	Untuk membangun dunia di mode edit agar bisa dihias, jalankan di Command Bar:
	    require(game.ServerScriptService.QuizServer.MapBuilder).Build()

	Tata letak (dilihat dari atas):
	    ARENA KUIS        x -50..50,  z -42..35   layar besar, 4 kotak jawaban, Lubang Data, Garis Start
	    TAMAN UTAMA       x -60..60,  z  35..122  spawn, air mancur + globe, Zona Materi, podium juara
	    TAMAN PET         x -145..-75, z  42..112  pameran semua pet hadiah
	    LINTASAN FIREWALL di langit (y = 80), mulai x = 120 ke arah timur
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("QuizShared")
local Config = require(Shared:WaitForChild("Config"))
local Materi = require(Shared:WaitForChild("Materi"))
local PetCatalog = require(Shared:WaitForChild("PetCatalog"))

local MapBuilder = {}

local ARENA_NAME = "ArenaKuis"
local PAD_X = { -33, -11, 11, 33 }
local PAD_SIZE = Vector3.new(22, 2, 22)
local IDLE_PAD_COLOR = Color3.fromRGB(150, 155, 175)
local DARK = Color3.fromRGB(18, 20, 34)
local WHITE = Color3.new(1, 1, 1)

-- Lintasan Firewall
local COURSE = {
	startX = 140, -- awal Gerbang 1 (platform start ada di x 120..140)
	y = 80, -- tinggi lantai lintasan
	z = 70, -- garis tengah lintasan
	width = 28,
	sectionLength = 56,
	gates = Config.FirewallGates,
}
COURSE.finishX = COURSE.startX + COURSE.gates * COURSE.sectionLength

local function laneZ(lane)
	return COURSE.z + (lane - 2.5) * 7
end

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

local function billboard(parent, text, color, size, offset)
	local gui = make("BillboardGui", { Name = "Label", Size = size or UDim2.fromScale(12, 3), StudsOffset = offset or Vector3.new(0, 4, 0),
		LightInfluence = 0, MaxDistance = 160 }, parent)
	label(gui, { Name = "Teks", Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color or WHITE,
		Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.2, TextStrokeColor3 = DARK })
	return gui
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
-- DEKORASI TAMAN
---------------------------------------------------------------------
local LEAF_COLORS = { Color3.fromRGB(90, 170, 80), Color3.fromRGB(70, 150, 70), Color3.fromRGB(120, 190, 90), Color3.fromRGB(255, 170, 200) }
local FLOWER_COLORS = { Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 210, 70), Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 60) }

local function tree(parent, position, scale, leafColor)
	scale = scale or 1
	local trunkHeight = 7 * scale
	part({ Name = "Batang", Shape = Enum.PartType.Cylinder, Size = Vector3.new(trunkHeight, 1.6 * scale, 1.6 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 85, 60), Material = Enum.Material.Wood }, parent)
	local color = leafColor or LEAF_COLORS[math.random(1, 3)]
	local leaves = {
		{ Vector3.new(0, trunkHeight + 1.5 * scale, 0), 7 },
		{ Vector3.new(2 * scale, trunkHeight, 1 * scale), 5 },
		{ Vector3.new(-2 * scale, trunkHeight + 0.5 * scale, -1 * scale), 5 },
		{ Vector3.new(0.5 * scale, trunkHeight + 3.5 * scale, 0), 4.5 },
	}
	for _, leaf in ipairs(leaves) do
		local size = leaf[2] * scale
		part({ Name = "Daun", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = position + leaf[1],
			Color = color, Material = Enum.Material.Grass, CanCollide = false }, parent)
	end
end

local function flowerBed(parent, position, length)
	length = length or 8
	part({ Name = "Bedengan", Size = Vector3.new(length, 0.8, 3), Position = position + Vector3.new(0, 0.4, 0),
		Color = Color3.fromRGB(110, 80, 60), Material = Enum.Material.Ground }, parent)
	for i = 1, math.floor(length / 1.5) do
		local x = -length / 2 + i * 1.5 - 0.5
		part({ Name = "Bunga", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1),
			Position = position + Vector3.new(x, 1.3, (i % 2 == 0) and 0.6 or -0.6),
			Color = FLOWER_COLORS[(i % #FLOWER_COLORS) + 1], CanCollide = false }, parent)
	end
end

local function bench(parent, cframe)
	local wood = Color3.fromRGB(160, 110, 70)
	part({ Name = "Dudukan", Size = Vector3.new(6, 0.4, 2), CFrame = cframe * CFrame.new(0, 1.6, 0), Color = wood, Material = Enum.Material.Wood }, parent)
	part({ Name = "Sandaran", Size = Vector3.new(6, 1.6, 0.3), CFrame = cframe * CFrame.new(0, 2.8, 0.9), Color = wood, Material = Enum.Material.Wood }, parent)
	for _, x in ipairs({ -2.6, 2.6 }) do
		part({ Name = "Kaki", Size = Vector3.new(0.4, 1.6, 1.8), CFrame = cframe * CFrame.new(x, 0.8, 0), Color = Color3.fromRGB(60, 60, 70),
			Material = Enum.Material.Metal }, parent)
	end
end

local function lampPost(parent, position)
	part({ Name = "TiangLampu", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 0.6, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(50, 55, 70),
		Material = Enum.Material.Metal }, parent)
	local bulb = part({ Name = "Bohlam", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = position + Vector3.new(0, 10.5, 0),
		Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, CanCollide = false }, parent)
	make("PointLight", { Range = 22, Brightness = 1, Color = Color3.fromRGB(255, 230, 190) }, bulb)
end

local function rock(parent, position, size)
	part({ Name = "Batu", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = position + Vector3.new(0, size * 0.25, 0),
		Color = Color3.fromRGB(140, 140, 150), Material = Enum.Material.Rock }, parent)
end

---------------------------------------------------------------------
-- TERRAIN (rumput, kolam) & PENCAHAYAAN
---------------------------------------------------------------------
local function buildTerrain()
	local terrain = workspace.Terrain
	local function fill(x1, x2, z1, z2, material, y1, y2)
		y1, y2 = y1 or -12, y2 or 0
		terrain:FillBlock(CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), Vector3.new(x2 - x1, y2 - y1, z2 - z1), material)
	end
	-- rumput di semua tempat kecuali lubang di bawah arena kuis
	fill(-184, -52, -84, 204, Enum.Material.Grass)
	fill(52, 184, -84, 204, Enum.Material.Grass)
	fill(-52, 52, 36, 204, Enum.Material.Grass)
	fill(-52, 52, -84, -44, Enum.Material.Grass)
	-- jalan setapak menuju Taman Pet
	fill(-76, -60, 68, 76, Enum.Material.Cobblestone, -12, 0)
	-- kolam
	fill(76, 132, 124, 172, Enum.Material.Air, -10, 0)
	fill(76, 132, 124, 172, Enum.Material.Sand, -12, -9)
	fill(76, 132, 124, 172, Enum.Material.Water, -9, -1)
	fill(72, 136, 120, 124, Enum.Material.Sand, -12, -0.5)
	-- bukit kecil di pinggir dunia
	for _, hill in ipairs({ { -150, -40, 14 }, { 150, -40, 16 }, { -150, 170, 18 }, { 40, 185, 14 }, { 160, 100, 12 } }) do
		terrain:FillBall(Vector3.new(hill[1], -4, hill[2]), hill[3], Enum.Material.Grass)
	end
	terrain.WaterColor = Color3.fromRGB(60, 160, 220)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.1
	if not terrain:FindFirstChildOfClass("Clouds") then
		make("Clouds", { Cover = 0.55, Density = 0.6, Color = Color3.new(1, 1, 1) }, terrain)
	end
end

local function setupLighting()
	Lighting.ClockTime = Config.ClockTime
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 110, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	if not Lighting:FindFirstChild("BloomKuis") then
		make("BloomEffect", { Name = "BloomKuis", Intensity = 0.35, Size = 24, Threshold = 1.6 }, Lighting)
	end
	if not Lighting:FindFirstChild("WarnaKuis") then
		make("ColorCorrectionEffect", { Name = "WarnaKuis", Saturation = 0.15, Contrast = 0.05, Brightness = 0.02 }, Lighting)
	end
	if not Lighting:FindFirstChild("SinarKuis") then
		make("SunRaysEffect", { Name = "SinarKuis", Intensity = 0.04, Spread = 0.8 }, Lighting)
	end
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		make("Atmosphere", { Density = 0.28, Offset = 0.2, Color = Color3.fromRGB(200, 220, 240),
			Decay = Color3.fromRGB(110, 130, 160), Glare = 0.3, Haze = 1.2 }, Lighting)
	end
end

---------------------------------------------------------------------
-- ARENA KUIS (kotak jawaban + layar besar)
---------------------------------------------------------------------
local function buildArena(arena)
	local floors = make("Folder", { Name = "Lantai" }, arena)
	part({ Name = "GarisStart", Size = Vector3.new(100, 2, 24), Position = Vector3.new(0, -1, 23),
		Color = Color3.fromRGB(95, 110, 170), Material = Enum.Material.Slate }, floors)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "SampingKotak", Size = Vector3.new(6, 2, 23), Position = Vector3.new(47 * side, -1, -0.5),
			Color = Color3.fromRGB(70, 80, 120) }, floors)
	end
	part({ Name = "GarisNeon", Size = Vector3.new(88, 0.2, 0.6), Position = Vector3.new(0, 0.05, 11.3),
		Color = WHITE, Material = Enum.Material.Neon, CanCollide = false }, floors)
	local startLabel = part({ Name = "TulisanStart", Size = Vector3.new(40, 0.1, 5), Position = Vector3.new(0, 0.02, 15),
		Transparency = 1, CanCollide = false }, floors)
	label(surfaceGui(startLabel, Enum.NormalId.Top, 20), {
		Size = UDim2.fromScale(1, 1), Text = "▲ LARI KE KOTAK JAWABAN ▲", TextColor3 = WHITE, TextTransparency = 0.15,
	})

	-- KOTAK JAWABAN
	local pads = make("Folder", { Name = "KotakJawaban" }, arena)
	for i = 1, 4 do
		local pad = part({ Name = "Pad" .. i, Size = PAD_SIZE, Position = Vector3.new(PAD_X[i], -1, 0),
			Color = Config.PadColors[i] }, pads)
		confettiEmitter(pad)
		make("PointLight", { Name = "Cahaya", Range = 18, Brightness = 0, Color = WHITE }, pad)
		local letter = make("BillboardGui", { Name = "Huruf", Size = UDim2.fromScale(8, 8),
			StudsOffset = Vector3.new(0, 11, 0), LightInfluence = 0, MaxDistance = 250 }, pad)
		label(letter, { Name = "Teks", Size = UDim2.fromScale(1, 1), Text = Config.PadLetters[i],
			TextStrokeTransparency = 0, TextStrokeColor3 = DARK })

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
	for i = 1, 3 do
		part({ Name = "Pembatas", Size = Vector3.new(0.5, 0.25, 22), Position = Vector3.new((PAD_X[i] + PAD_X[i + 1]) / 2, 0.1, 0),
			Color = WHITE, Material = Enum.Material.Neon, CanCollide = false }, pads)
	end

	-- LUBANG DATA
	local pit = part({ Name = "LubangData", Size = Vector3.new(104, 2, 56), Position = Vector3.new(0, -46, -15),
		Color = Color3.fromRGB(0, 170, 255), Material = Enum.Material.Neon, Transparency = 0.25 }, arena)
	label(surfaceGui(pit, Enum.NormalId.Top, 6), { Size = UDim2.fromScale(1, 1),
		Text = "01001 UPS! KAMU JATUH KE LUBANG DATA 10110", TextTransparency = 0.3, TextColor3 = DARK })

	-- LAYAR BESAR
	local screen = part({ Name = "Layar", Size = Vector3.new(92, 34, 1), Position = Vector3.new(0, 29, -16),
		Color = Color3.fromRGB(10, 12, 24) }, arena)
	local sgui = surfaceGui(screen, Enum.NormalId.Back, 20)
	local frame = make("Frame", { Name = "Isi", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 22, 48),
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
		Text = "Selamat datang! Baca Zona Materi di taman sambil menunggu kuis dimulai.", Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(190, 220, 255), MaxTextSize = 48 })
	local titleBar = part({ Name = "JudulGame", Size = Vector3.new(60, 6, 1), Position = Vector3.new(0, 50, -16),
		Color = Color3.fromRGB(255, 120, 200), Material = Enum.Material.Neon }, arena)
	label(surfaceGui(titleBar, Enum.NormalId.Back, 20), { Size = UDim2.fromScale(1, 1),
		Text = "🌐 " .. Config.GameTitle .. " 🌐", Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.3 })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "TiangLayar", Size = Vector3.new(3, 100, 3), Position = Vector3.new(47.5 * side, 4, -16),
			Color = Color3.fromRGB(230, 235, 245), Material = Enum.Material.Metal }, arena)
		part({ Name = "LampuTiang", Size = Vector3.new(3.2, 60, 0.6), Position = Vector3.new(47.5 * side, 20, -14.4),
			Color = Color3.fromRGB(70, 160, 255), Material = Enum.Material.Neon, CanCollide = false }, arena)
	end

	-- DINDING: pagar tanaman (terlihat) + batas tak terlihat
	local walls = make("Folder", { Name = "Dinding" }, arena)
	local function invisibleWall(name, size, pos)
		part({ Name = name, Size = size, Position = pos, Transparency = 1 }, walls)
	end
	invisibleWall("BatasDepan", Vector3.new(100, 60, 1), Vector3.new(0, 20, -12.5))
	invisibleWall("BatasUtara", Vector3.new(104, 60, 1), Vector3.new(0, 20, -43.5))
	for _, side in ipairs({ -1, 1 }) do
		invisibleWall("BatasSamping", Vector3.new(1, 60, 79), Vector3.new(50.5 * side, 20, -4))
		part({ Name = "PagarTanaman", Size = Vector3.new(2, 4, 79), Position = Vector3.new(52 * side, 2, -4),
			Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass }, walls)
	end
	part({ Name = "PagarTanaman", Size = Vector3.new(106, 4, 2), Position = Vector3.new(0, 2, -44.5),
		Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass }, walls)
end

---------------------------------------------------------------------
-- TAMAN UTAMA (spawn, air mancur, Zona Materi, podium)
---------------------------------------------------------------------
local function buildPlaza(arena)
	local plaza = make("Folder", { Name = "Taman" }, arena)
	part({ Name = "Pelataran", Size = Vector3.new(120, 1, 87), Position = Vector3.new(0, -0.45, 78.5),
		Color = Color3.fromRGB(225, 215, 195), Material = Enum.Material.Pavement }, plaza)
	-- pola ubin berwarna
	for i = 0, 3 do
		part({ Name = "Ubin", Size = Vector3.new(120, 0.1, 1.2), Position = Vector3.new(0, 0.08, 44 + i * 22),
			Color = Color3.fromRGB(190, 175, 150), Material = Enum.Material.Pavement, CanCollide = false }, plaza)
	end
	part({ Name = "JalurTengah", Size = Vector3.new(10, 0.1, 87), Position = Vector3.new(0, 0.07, 78.5),
		Color = Color3.fromRGB(200, 185, 160), Material = Enum.Material.Pavement, CanCollide = false }, plaza)

	-- SPAWN
	make("SpawnLocation", { Name = "SpawnTaman", Anchored = true, Size = Vector3.new(12, 1, 12), Position = Vector3.new(0, 0.1, 48),
		Color = Color3.fromRGB(110, 200, 255), Material = Enum.Material.SmoothPlastic, Neutral = true, Duration = 0,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, plaza)

	-- AIR MANCUR + GLOBE INTERNET
	part({ Name = "KolamAirMancur", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 20, 20),
		CFrame = CFrame.new(0, 1, 74) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 230, 220),
		Material = Enum.Material.Marble }, plaza)
	part({ Name = "AirMancur", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 17, 17),
		CFrame = CFrame.new(0, 2.1, 74) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 180, 240),
		Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false }, plaza)
	part({ Name = "TiangAirMancur", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 2.5, 2.5),
		CFrame = CFrame.new(0, 3, 74) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 230, 220),
		Material = Enum.Material.Marble }, plaza)
	local spray = part({ Name = "Semburan", Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, 5, 74), Transparency = 1,
		CanCollide = false }, plaza)
	make("ParticleEmitter", { Rate = 40, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(12, 16),
		SpreadAngle = Vector2.new(18, 18), Acceleration = Vector3.new(0, -30, 0), Size = NumberSequence.new(0.5, 0.1),
		Color = ColorSequence.new(Color3.fromRGB(200, 235, 255)), Transparency = NumberSequence.new(0.3, 1),
		EmissionDirection = Enum.NormalId.Top }, spray)
	local globe = part({ Name = "GlobeInternet", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7),
		Position = Vector3.new(0, 13, 74), Color = Color3.fromRGB(60, 200, 255), Material = Enum.Material.ForceField,
		CanCollide = false }, plaza)
	make("PointLight", { Range = 20, Brightness = 2, Color = Color3.fromRGB(60, 200, 255) }, globe)
	billboard(globe, "🌐 INTERNET", Color3.fromRGB(150, 230, 255), UDim2.fromScale(12, 2.5), Vector3.new(0, 6, 0))
	for _, x in ipairs({ -10, 10 }) do
		-- bangku menghadap air mancur (sisi depan bangku = -Z lokal)
		bench(plaza, CFrame.new(x * 1.6, 0, 74) * CFrame.Angles(0, math.rad(x > 0 and 90 or -90), 0))
	end

	-- ZONA MATERI (6 kios papan materi)
	local boards = make("Folder", { Name = "ZonaMateri" }, arena)
	local boardTopics = {}
	for _, topic in ipairs(Config.Topics) do
		if topic.id ~= "campuran" then
			table.insert(boardTopics, topic)
		end
	end
	for index, topic in ipairs(boardTopics) do
		local side = index <= 3 and -1 or 1
		local z = 52 + ((index - 1) % 3) * 22
		local x = 46 * side
		local board = part({ Name = "Materi_" .. topic.id, Size = Vector3.new(0.6, 12, 18), Position = Vector3.new(x, 7.5, z),
			Color = Color3.fromRGB(245, 240, 230), Material = Enum.Material.Wood }, boards)
		board:SetAttribute("TopicId", topic.id)
		local face = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
		local gui = surfaceGui(board, face, 60)
		local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 252, 245),
			BorderSizePixel = 0 }, gui)
		make("UIStroke", { Thickness = 12, Color = topic.color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bg)
		local titleFrame = make("Frame", { Size = UDim2.fromScale(1, 0.15), BackgroundColor3 = topic.color, BorderSizePixel = 0 }, bg)
		label(titleFrame, { Size = UDim2.fromScale(0.96, 0.85), Position = UDim2.fromScale(0.02, 0.08),
			Text = topic.icon .. "  " .. string.upper(topic.name), Font = Enum.Font.FredokaOne, TextColor3 = DARK })
		local body = make("Frame", { Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.18),
			BackgroundTransparency = 1 }, bg)
		make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, body)
		for order, point in ipairs(Materi[topic.id] or {}) do
			label(body, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false,
				TextSize = 26, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = order, Text = "• " .. point, TextColor3 = Color3.fromRGB(40, 45, 70) })
		end
		make("ProximityPrompt", { Name = "BacaMateri", ActionText = "Baca Materi", ObjectText = topic.name,
			HoldDuration = 0, MaxActivationDistance = 14, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E }, board)
		-- rangka kios: tiang, atap, lampu
		for _, dz in ipairs({ -9.5, 9.5 }) do
			part({ Name = "TiangKios", Size = Vector3.new(1, 15, 1), Position = Vector3.new(x + side * 0.6, 7.5, z + dz),
				Color = Color3.fromRGB(150, 105, 70), Material = Enum.Material.Wood }, boards)
		end
		part({ Name = "AtapKios", Size = Vector3.new(5, 0.8, 21), Position = Vector3.new(x - side * 1.4, 15.2, z),
			Color = topic.color, Material = Enum.Material.SmoothPlastic }, boards)
		local lamp = part({ Name = "LampuKios", Size = Vector3.new(0.6, 0.4, 16), Position = Vector3.new(x - side * 2.5, 14.6, z),
			Color = Color3.fromRGB(255, 245, 220), Material = Enum.Material.Neon, CanCollide = false }, boards)
		make("SpotLight", { Face = Enum.NormalId.Bottom, Range = 16, Brightness = 1.5, Angle = 90 }, lamp)
	end
	local zoneSign = part({ Name = "TulisanZonaMateri", Size = Vector3.new(34, 6, 0.5), Position = Vector3.new(0, 20, 52),
		Transparency = 1, CanCollide = false }, boards)
	label(surfaceGui(zoneSign, Enum.NormalId.Front, 20), { Size = UDim2.fromScale(1, 1),
		Text = "📚 ZONA MATERI: baca papan di kiri & kanan!", Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 230, 120),
		TextStrokeTransparency = 0.2 })

	-- PODIUM & PAPAN JUARA
	local podium = make("Folder", { Name = "Podium" }, arena)
	local podiumData = {
		{ x = 0, h = 5, color = Color3.fromRGB(255, 205, 50), text = "1" },
		{ x = -8, h = 3.5, color = Color3.fromRGB(200, 205, 220), text = "2" },
		{ x = 8, h = 2.5, color = Color3.fromRGB(215, 135, 70), text = "3" },
	}
	for rank, data in ipairs(podiumData) do
		local block = part({ Name = "Juara" .. rank, Size = Vector3.new(7, data.h, 7), Position = Vector3.new(data.x, data.h / 2, 108),
			Color = data.color, Material = Enum.Material.Metal }, podium)
		confettiEmitter(block)
		label(surfaceGui(block, Enum.NormalId.Front, 30), { Size = UDim2.fromScale(1, 1), Text = data.text,
			Font = Enum.Font.FredokaOne, TextColor3 = DARK })
	end
	local fame = part({ Name = "PapanJuara", Size = Vector3.new(34, 13, 0.6), Position = Vector3.new(0, 12, 118),
		Color = DARK }, podium)
	for _, x in ipairs({ -16, 16 }) do
		part({ Name = "TiangPapan", Size = Vector3.new(1.2, 19, 1.2), Position = Vector3.new(x, 9.5, 118.5),
			Color = Color3.fromRGB(230, 235, 245), Material = Enum.Material.Metal }, podium)
	end
	local fameGui = surfaceGui(fame, Enum.NormalId.Front, 30)
	local fameBg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 26, 60),
		BorderSizePixel = 0 }, fameGui)
	make("UIStroke", { Thickness = 8, Color = Color3.fromRGB(255, 205, 50), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, fameBg)
	label(fameBg, { Name = "Judul", Size = UDim2.fromScale(0.96, 0.18), Position = UDim2.fromScale(0.02, 0.03),
		Text = "🏆 JUARA RONDE TERAKHIR 🏆", Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 205, 50) })
	label(fameBg, { Name = "Daftar", Size = UDim2.fromScale(0.9, 0.74), Position = UDim2.fromScale(0.05, 0.23),
		Text = "Belum ada juara. Ayo jadi yang pertama!", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, MaxTextSize = 34 })

	-- HIASAN TAMAN
	local deco = make("Folder", { Name = "Dekorasi" }, arena)
	for _, pos in ipairs({ Vector3.new(-56, 0, 40), Vector3.new(56, 0, 40), Vector3.new(-56, 0, 118), Vector3.new(56, 0, 118),
		Vector3.new(-25, 0, 40), Vector3.new(25, 0, 40), Vector3.new(-25, 0, 118), Vector3.new(25, 0, 118) }) do
		lampPost(deco, pos)
	end
	for _, pos in ipairs({ Vector3.new(-22, 0, 96), Vector3.new(22, 0, 96), Vector3.new(-22, 0, 58), Vector3.new(22, 0, 58) }) do
		flowerBed(deco, pos, 9)
	end
	bench(deco, CFrame.new(-26, 0, 108) * CFrame.Angles(0, math.rad(-90), 0))
	bench(deco, CFrame.new(26, 0, 108) * CFrame.Angles(0, math.rad(90), 0))
	-- pohon mengelilingi taman & dunia
	local treeSpots = {
		{ -66, 40 }, { -66, 58 }, { -66, 92 }, { -66, 112 }, { 66, 40 }, { 66, 58 }, { 66, 92 }, { 66, 112 },
		{ -40, 130 }, { -15, 132 }, { 15, 132 }, { 40, 130 }, { 0, 140 }, { -60, 135 }, { 60, 135 },
		{ -64, 20 }, { -64, 0 }, { -64, -20 }, { -64, -40 }, { 64, 20 }, { 64, 0 }, { 64, -20 }, { 64, -40 },
		{ -30, -58 }, { 0, -62 }, { 30, -58 }, { -90, -10 }, { 90, -10 }, { -100, 140 }, { -130, 130 },
		{ 100, 30 }, { 140, 40 }, { 150, 150 }, { -150, 20 }, { -160, 90 }, { 160, -10 }, { 120, 100 },
	}
	for i, spot in ipairs(treeSpots) do
		local color = (i % 7 == 0) and LEAF_COLORS[4] or nil -- sesekali pohon sakura
		tree(deco, Vector3.new(spot[1], 0, spot[2]), 0.9 + (i % 4) * 0.15, color)
	end
	for _, spot in ipairs({ { -80, 130, 3 }, { 75, 20, 4 }, { 140, 120, 5 }, { -120, 0, 4 }, { 20, 160, 3 } }) do
		rock(deco, Vector3.new(spot[1], 0, spot[2]), spot[3])
	end
	-- rak server kecil di samping arena (tetap ada nuansa jaringan)
	for _, x in ipairs({ -58, 58 }) do
		part({ Name = "RakServer", Size = Vector3.new(4, 10, 3), Position = Vector3.new(x, 5, 28),
			Color = Color3.fromRGB(40, 44, 56), Material = Enum.Material.Metal }, deco)
		for row = 1, 4 do
			part({ Name = "LampuRak", Size = Vector3.new(3.2, 0.3, 0.2), Position = Vector3.new(x, row * 2, 29.6),
				Color = row % 2 == 0 and Color3.fromRGB(80, 255, 140) or Color3.fromRGB(70, 160, 255),
				Material = Enum.Material.Neon, CanCollide = false }, deco)
		end
	end

	-- batas dunia (tak terlihat). Tingginya hanya sampai y = 40 agar tidak menghalangi
	-- Lintasan Firewall yang melayang di y = 80.
	local bounds = make("Folder", { Name = "BatasDunia" }, arena)
	for _, data in ipairs({
		{ Vector3.new(1, 50, 300), Vector3.new(-172, 15, 60) },
		{ Vector3.new(1, 50, 300), Vector3.new(172, 15, 60) },
		{ Vector3.new(344, 50, 1), Vector3.new(0, 15, -86) },
		{ Vector3.new(344, 50, 1), Vector3.new(0, 15, 206) },
	}) do
		part({ Name = "Batas", Size = data[1], Position = data[2], Transparency = 1 }, bounds)
	end
	return globe
end

---------------------------------------------------------------------
-- TAMAN PET
---------------------------------------------------------------------
local function buildPetGarden(arena)
	local garden = make("Folder", { Name = "TamanPet" }, arena)
	part({ Name = "LantaiTaman", Size = Vector3.new(70, 1, 70), Position = Vector3.new(-110, -0.45, 77),
		Color = Color3.fromRGB(170, 215, 140), Material = Enum.Material.Grass }, garden)
	-- pagar
	for _, data in ipairs({
		{ Vector3.new(70, 3, 0.6), Vector3.new(-110, 1.5, 42) },
		{ Vector3.new(70, 3, 0.6), Vector3.new(-110, 1.5, 112) },
		{ Vector3.new(0.6, 3, 70), Vector3.new(-145, 1.5, 77) },
		{ Vector3.new(0.6, 3, 28), Vector3.new(-75, 1.5, 56) },
		{ Vector3.new(0.6, 3, 28), Vector3.new(-75, 1.5, 98) },
	}) do
		part({ Name = "Pagar", Size = data[1], Position = data[2], Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.Wood }, garden)
	end
	-- gerbang & papan nama
	for _, z in ipairs({ 69, 85 }) do
		part({ Name = "TiangGerbang", Size = Vector3.new(1.5, 14, 1.5), Position = Vector3.new(-75, 7, z),
			Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Wood }, garden)
	end
	local gateSign = part({ Name = "PapanTamanPet", Size = Vector3.new(0.8, 4, 18), Position = Vector3.new(-75, 15, 77),
		Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Wood }, garden)
	label(surfaceGui(gateSign, Enum.NormalId.Right, 30), { Size = UDim2.fromScale(1, 1), Text = "🐾 TAMAN PET 🐾",
		Font = Enum.Font.FredokaOne, TextColor3 = WHITE, TextStrokeTransparency = 0.2 })
	local info = part({ Name = "PapanInfoPet", Size = Vector3.new(0.6, 7, 14), Position = Vector3.new(-80, 4.5, 60),
		Color = Color3.fromRGB(255, 250, 235), Material = Enum.Material.Wood }, garden)
	label(surfaceGui(info, Enum.NormalId.Right, 40), { Size = UDim2.fromScale(0.92, 0.9), Position = UDim2.fromScale(0.04, 0.05),
		Text = "Jawab soal dengan BENAR untuk mengumpulkan POIN RANK.\nSemakin banyak Poin Rank, semakin keren pet yang terbuka!\nPakai pet lewat tombol 🐾 Pet di layar.",
		Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(60, 50, 40) })

	-- alas pet: 3 baris x 3 kolom
	for index, pet in ipairs(PetCatalog.List) do
		local col = (index - 1) % 3
		local row = math.floor((index - 1) / 3)
		local position = Vector3.new(-90 - row * 20, 0, 55 + col * 22)
		local rarityColor = PetCatalog.Rarities[pet.rarity] or WHITE
		local pedestal = part({ Name = "Alas_" .. pet.id, Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 7, 7),
			CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(245, 245, 250), Material = Enum.Material.Marble }, garden)
		part({ Name = "CincinAlas", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7.6, 7.6),
			CFrame = CFrame.new(position + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rarityColor, Material = Enum.Material.Neon, CanCollide = false }, garden)
		local model = PetCatalog.Build(pet.id)
		model:PivotTo(CFrame.new(position + Vector3.new(0, pet.flying and 5 or 3.6, 0)) * CFrame.Angles(0, -math.pi / 2, 0))
		model.Parent = garden
		billboard(pedestal, pet.name .. "\n" .. pet.rarity .. " • " .. (pet.xp == 0 and "GRATIS" or (pet.xp .. " Poin Rank")),
			rarityColor, UDim2.fromScale(10, 3), Vector3.new(0, 7.5, 0))
	end
	for _, spot in ipairs({ { -140, 47 }, { -140, 107 }, { -80, 107 }, { -80, 47 } }) do
		tree(garden, Vector3.new(spot[1], 0, spot[2]), 0.8, LEAF_COLORS[4])
	end
end

---------------------------------------------------------------------
-- LINTASAN FIREWALL (obby di langit)
---------------------------------------------------------------------
local function buildCourse(arena)
	local course = make("Folder", { Name = "LintasanFirewall" }, arena)
	local y, zc, width = COURSE.y, COURSE.z, COURSE.width
	local floorColor = Color3.fromRGB(70, 80, 125)

	local start = part({ Name = "Start", Size = Vector3.new(20, 1, width), Position = Vector3.new(COURSE.startX - 10, y - 0.5, zc),
		Color = Color3.fromRGB(60, 200, 120) }, course)
	billboard(start, "🧱 LINTASAN FIREWALL 🧱\nPilih pintu jawaban yang BENAR!", Color3.fromRGB(255, 200, 120),
		UDim2.fromScale(26, 5), Vector3.new(0, 12, 0))
	part({ Name = "Penghalang", Size = Vector3.new(1, 12, width), Position = Vector3.new(COURSE.startX - 0.5, y + 6, zc),
		Color = Color3.fromRGB(255, 70, 70), Material = Enum.Material.ForceField }, course)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "PagarStart", Size = Vector3.new(20, 4, 0.6), Position = Vector3.new(COURSE.startX - 10, y + 2, zc + side * (width / 2)),
			Color = WHITE, Material = Enum.Material.Glass, Transparency = 0.6 }, course)
	end
	part({ Name = "PagarStartBelakang", Size = Vector3.new(0.6, 4, width), Position = Vector3.new(COURSE.startX - 20, y + 2, zc),
		Color = WHITE, Material = Enum.Material.Glass, Transparency = 0.6 }, course)

	for gate = 1, COURSE.gates do
		local x0 = COURSE.startX + (gate - 1) * COURSE.sectionLength
		local folder = make("Folder", { Name = "Gerbang" .. gate }, course)
		part({ Name = "Area", Size = Vector3.new(16, 1, width), Position = Vector3.new(x0 + 8, y - 0.5, zc), Color = floorColor }, folder)
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "TepiNeon", Size = Vector3.new(16, 0.3, 0.6), Position = Vector3.new(x0 + 8, y + 0.1, zc + side * (width / 2 - 0.3)),
				Color = Color3.fromRGB(255, 120, 60), Material = Enum.Material.Neon, CanCollide = false }, folder)
		end
		-- dinding firewall dengan 4 pintu
		local wallColor = Color3.fromRGB(200, 70, 60)
		part({ Name = "Atas", Size = Vector3.new(1, 4, width), Position = Vector3.new(x0 + 16.5, y + 10, zc), Color = wallColor,
			Material = Enum.Material.Brick }, folder)
		for lane = 1, 4 do
			local lz = laneZ(lane)
			for _, dz in ipairs({ -3, 3 }) do
				part({ Name = "Tiang", Size = Vector3.new(1, 8, 1), Position = Vector3.new(x0 + 16.5, y + 4, lz + dz), Color = wallColor,
					Material = Enum.Material.Brick }, folder)
			end
			part({ Name = "Blok" .. lane, Size = Vector3.new(0.6, 8, 5), Position = Vector3.new(x0 + 16.5, y + 4, lz),
				Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.ForceField, CanCollide = false, Transparency = 1 }, folder)
			local sign = part({ Name = "Tanda" .. lane, Size = Vector3.new(0.3, 3.6, 6.6), Position = Vector3.new(x0 + 15.8, y + 10, lz),
				Color = Config.PadColors[lane] }, folder)
			local gui = surfaceGui(sign, Enum.NormalId.Left, 40)
			label(gui, { Name = "Huruf", Size = UDim2.fromScale(0.25, 1), Text = Config.PadLetters[lane], Font = Enum.Font.FredokaOne })
			label(gui, { Name = "Jawaban", Size = UDim2.fromScale(0.73, 0.9), Position = UDim2.fromScale(0.26, 0.05), Text = "",
				MaxTextSize = 40 })
			-- lantai jalur di balik pintu (jalur salah tidak bisa diinjak!)
			part({ Name = "Jalur" .. lane, Size = Vector3.new(14, 1, 7), Position = Vector3.new(x0 + 24, y - 0.5, lz), Color = floorColor }, folder)
		end
		for i = 0, 4 do
			part({ Name = "SekatJalur", Size = Vector3.new(14, 8, 0.4), Position = Vector3.new(x0 + 24, y + 4, zc - width / 2 + i * 7),
				Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.6 }, folder)
		end
		local board = part({ Name = "PapanSoal", Size = Vector3.new(0.4, 8, width), Position = Vector3.new(x0 + 15.8, y + 16.5, zc),
			Color = DARK }, folder)
		local boardGui = surfaceGui(board, Enum.NormalId.Left, 25)
		label(boardGui, { Name = "Nomor", Size = UDim2.fromScale(1, 0.2), Text = "GERBANG " .. gate, Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.fromRGB(255, 160, 80) })
		label(boardGui, { Name = "Soal", Size = UDim2.fromScale(0.96, 0.76), Position = UDim2.fromScale(0.02, 0.22), Text = "",
			MaxTextSize = 44 })
		-- platform setelah pintu + lompatan
		part({ Name = "Gabung", Size = Vector3.new(5, 1, width), Position = Vector3.new(x0 + 33.5, y - 0.5, zc), Color = floorColor }, folder)
		local zig = (gate % 2 == 0) and 1 or -1
		part({ Name = "Lompat1", Size = Vector3.new(4, 1, 6), Position = Vector3.new(x0 + 42, y + 0.5, zc + zig * 5),
			Color = Color3.fromRGB(255, 200, 80) }, folder)
		part({ Name = "Lompat2", Size = Vector3.new(4, 1, 6), Position = Vector3.new(x0 + 50, y + 1.5, zc - zig * 5),
			Color = Color3.fromRGB(255, 160, 80) }, folder)
	end

	local finish = part({ Name = "Finish", Size = Vector3.new(24, 1, width), Position = Vector3.new(COURSE.finishX + 12, y - 0.5, zc),
		Color = Color3.fromRGB(255, 205, 50) }, course)
	confettiEmitter(finish)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "TiangFinish", Size = Vector3.new(1.5, 16, 1.5), Position = Vector3.new(COURSE.finishX + 4, y + 8, zc + side * 12),
			Color = WHITE, Material = Enum.Material.Metal }, course)
		part({ Name = "PagarFinish", Size = Vector3.new(24, 4, 0.6), Position = Vector3.new(COURSE.finishX + 12, y + 2, zc + side * (width / 2)),
			Color = WHITE, Material = Enum.Material.Glass, Transparency = 0.6 }, course)
	end
	part({ Name = "PagarFinishUjung", Size = Vector3.new(0.6, 4, width), Position = Vector3.new(COURSE.finishX + 24, y + 2, zc),
		Color = WHITE, Material = Enum.Material.Glass, Transparency = 0.6 }, course)
	local banner = part({ Name = "SpandukFinish", Size = Vector3.new(1, 4, 25.5), Position = Vector3.new(COURSE.finishX + 4, y + 14, zc),
		Color = Color3.fromRGB(255, 80, 120) }, course)
	label(surfaceGui(banner, Enum.NormalId.Left, 30), { Size = UDim2.fromScale(1, 1), Text = "🏁 FINISH 🏁", Font = Enum.Font.FredokaOne })

	-- menara penanda di taman (lintasan ada di langit di atasnya)
	local tower = part({ Name = "MenaraFirewall", Size = Vector3.new(6, 40, 6), Position = Vector3.new(100, 20, 70),
		Color = Color3.fromRGB(200, 70, 60), Material = Enum.Material.Brick }, course)
	billboard(tower, "🧱 Lintasan Firewall ada di langit!\nDibuka saat mode Lintasan Firewall", Color3.fromRGB(255, 200, 120),
		UDim2.fromScale(24, 5), Vector3.new(0, 26, 0))
end

---------------------------------------------------------------------
-- MEMBANGUN DUNIA BARU
---------------------------------------------------------------------
local function buildWorld()
	local arena = make("Folder", { Name = ARENA_NAME }, nil)
	buildTerrain()
	buildArena(arena)
	buildPlaza(arena)
	buildPetGarden(arena)
	buildCourse(arena)
	arena:SetAttribute("Gerbang", COURSE.gates)
	arena.Parent = workspace
	return arena
end

local function removeDefaults(arena)
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

local function findPath(parent, path)
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
	"LintasanFirewall/Penghalang", "LintasanFirewall/Finish",
}

local function isValid(arena)
	if arena:GetAttribute("Gerbang") ~= COURSE.gates then
		warn("[NetQuest] Jumlah gerbang Lintasan Firewall berubah, dunia dibangun ulang.")
		return false
	end
	for _, path in ipairs(REQUIRED) do
		if not findPath(arena, path) then
			warn("[NetQuest] ArenaKuis tidak lengkap (" .. path .. " hilang), dunia dibangun ulang.")
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
		self.Pads[i] = findPath(folder, "KotakJawaban/Pad" .. i)
		self.Signs[i] = findPath(folder, "KotakJawaban/Papan" .. i .. "/Gui/Latar")
	end
	self.Pit = folder.LubangData
	local screen = findPath(folder, "Layar/Gui/Isi")
	self.Screen = {
		Topic = findPath(screen, "Header/Topik"),
		Number = findPath(screen, "Header/Nomor"),
		Timer = findPath(screen, "Header/Waktu"),
		Header = screen:FindFirstChild("Header"),
		Question = screen:FindFirstChild("Pertanyaan"),
		Info = screen:FindFirstChild("Info"),
	}
	local fame = findPath(folder, "Podium/PapanJuara/Gui")
	self.FameList = fame and fame:FindFirstChild("Daftar", true)
	self.Podiums = {}
	for i = 1, 3 do
		self.Podiums[i] = findPath(folder, "Podium/Juara" .. i)
	end
	self.Course = findPath(folder, "LintasanFirewall")
	self.CourseInfo = COURSE
	self.ActivePads = {}
	self.PadColors = {}
	return self
end

-- Posisi acak di Garis Start (menghadap layar)
function Arena:GetStartCFrame()
	return CFrame.new(math.random(-40, 40), 3.5, math.random(15, 31))
end

-- Posisi acak di taman, menghadap podium
function Arena:GetLobbyCFrame()
	return CFrame.new(math.random(-14, 14), 3.5, math.random(84, 96)) * CFrame.Angles(0, math.pi, 0)
end

function Arena:GetPodiumCFrame(rank)
	local block = self.Podiums[rank]
	-- CFrame.new tanpa rotasi = menghadap -Z (ke arah taman)
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

local function optionForPad(prepared, pad)
	for _, option in ipairs(prepared.options) do
		if option.pad == pad then
			return option
		end
	end
	return nil
end

-- Menampilkan soal di kotak jawaban & papan
function Arena:SetQuestion(prepared)
	for i = 1, 4 do
		local option = optionForPad(prepared, i)
		self.ActivePads[i] = option ~= nil
		self.PadColors[i] = option and option.color or IDLE_PAD_COLOR
	end
	for i, pad in ipairs(self.Pads) do
		setPadSolid(pad, self.PadColors[i])
		local sign = self.Signs[i]
		local letter = pad:FindFirstChild("Huruf")
		local option = optionForPad(prepared, i)
		sign.BackgroundColor3 = self.PadColors[i]
		sign.Jumlah.Text = ""
		if option then
			sign.Huruf.Text = option.letter
			sign.Jawaban.Text = option.text
			if letter then
				letter.Enabled = true
				letter.Teks.Text = option.letter
				letter.Teks.TextColor3 = option.color:Lerp(WHITE, 0.35)
			end
		else
			sign.Huruf.Text = ""
			sign.Jawaban.Text = "—"
			if letter then
				letter.Enabled = false
			end
		end
	end
end

-- Mengungkap jawaban: kotak salah jatuh, kotak benar bersinar + konfeti
function Arena:Reveal(correctPad, counts)
	for i, pad in ipairs(self.Pads) do
		local sign = self.Signs[i]
		if self.ActivePads[i] and counts then
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
function Arena:ResetPads(idle, idleText)
	for i, pad in ipairs(self.Pads) do
		local color = self.PadColors[i] or IDLE_PAD_COLOR
		if idle then
			color = Config.PadColors[i]
			self.ActivePads[i] = false
			local sign = self.Signs[i]
			sign.BackgroundColor3 = color
			sign.Huruf.Text = Config.PadLetters[i]
			sign.Jawaban.Text = idleText or "Menunggu soal..."
			sign.Jumlah.Text = ""
			local letter = pad:FindFirstChild("Huruf")
			if letter then
				letter.Enabled = true
				letter.Teks.Text = Config.PadLetters[i]
				letter.Teks.TextColor3 = WHITE
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

-- Globe berputar & naik turun di atas air mancur
function Arena:StartDecorations()
	local globe = findPath(self.Folder, "Taman/GlobeInternet")
	if globe then
		local base = globe.CFrame
		local angle = 0
		RunService.Heartbeat:Connect(function(dt)
			angle += dt * 0.6
			globe.CFrame = base * CFrame.new(0, math.sin(angle * 1.5) * 0.8, 0) * CFrame.Angles(0, angle, 0)
		end)
	end
	local course = self.Course
	if course then
		-- penghalang berkedip pelan agar terlihat "aktif"
		local barrier = course:FindFirstChild("Penghalang")
		if barrier then
			TweenService:Create(barrier, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Color = Color3.fromRGB(255, 160, 60) }):Play()
		end
	end
end

---------------------------------------------------------------------
-- LINTASAN FIREWALL: API
---------------------------------------------------------------------
function Arena:GetCourseStartCFrame()
	local position = Vector3.new(COURSE.startX - math.random(4, 16), COURSE.y + 3.5, COURSE.z + math.random(-11, 11))
	return CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
end

function Arena:GetGateCFrame(gate)
	local x0 = COURSE.startX + (gate - 1) * COURSE.sectionLength
	local position = Vector3.new(x0 + 4, COURSE.y + 3.5, COURSE.z + math.random(-8, 8))
	return CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
end

function Arena:GetMergeCFrame(gate)
	local x0 = COURSE.startX + (gate - 1) * COURSE.sectionLength
	local position = Vector3.new(x0 + 33.5, COURSE.y + 3.5, COURSE.z)
	return CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
end

function Arena:SetCourseBarrier(closed)
	local barrier = self.Course and self.Course:FindFirstChild("Penghalang")
	if barrier then
		barrier.CanCollide = closed
		barrier.Transparency = closed and 0 or 1
	end
end

-- Mengisi gerbang dengan soal: label pintu, papan soal, dan jalur yang bisa diinjak
function Arena:SetupGate(gate, prepared)
	local folder = self.Course and self.Course:FindFirstChild("Gerbang" .. gate)
	if not folder then
		return
	end
	local board = findPath(folder, "PapanSoal/Gui/Soal")
	if board then
		board.Text = prepared and prepared.text or ""
	end
	for lane = 1, 4 do
		local option = prepared and optionForPad(prepared, lane)
		local sign = folder:FindFirstChild("Tanda" .. lane)
		local blocker = folder:FindFirstChild("Blok" .. lane)
		local floor = folder:FindFirstChild("Jalur" .. lane)
		if sign then
			sign.Color = option and option.color or IDLE_PAD_COLOR
			local gui = sign:FindFirstChild("Gui")
			if gui then
				gui.Huruf.Text = option and option.letter or ""
				gui.Jawaban.Text = option and option.text or (prepared and "⛔ DIBLOKIR" or "")
			end
		end
		if blocker then
			local blocked = prepared ~= nil and option == nil
			blocker.CanCollide = blocked
			blocker.Transparency = blocked and 0.2 or 1
		end
		if floor then
			-- hanya jalur jawaban benar yang padat; jalur lain tampak sama tetapi tembus
			floor.CanCollide = (prepared == nil) or (prepared.correctPad == lane)
		end
	end
end

function Arena:ResetCourse()
	for gate = 1, COURSE.gates do
		self:SetupGate(gate, nil)
	end
	self:SetCourseBarrier(true)
end

-- Menentukan posisi pemain di lintasan: gate (nomor gerbang) dan zona
-- zona: "start", "area", "pintu", "jalur", "gabung", "lompat", "finish", atau nil (di luar lintasan)
function Arena:CourseZone(position)
	if position.Y < COURSE.y - 8 or position.Y > COURSE.y + 30 then
		return nil
	end
	if math.abs(position.Z - COURSE.z) > COURSE.width / 2 + 2 then
		return nil
	end
	local dx = position.X - COURSE.startX
	if dx < 0 then
		return 0, "start"
	end
	if position.X >= COURSE.finishX then
		return COURSE.gates + 1, "finish"
	end
	local gate = math.floor(dx / COURSE.sectionLength) + 1
	local offset = dx - (gate - 1) * COURSE.sectionLength
	local zone
	if offset < 16 then
		zone = "area"
	elseif offset < 17 then
		zone = "pintu"
	elseif offset < 31 then
		zone = "jalur"
	elseif offset < 36 then
		zone = "gabung"
	else
		zone = "lompat"
	end
	return gate, zone
end

function Arena:CelebrateFinish()
	local finish = self.Course and self.Course:FindFirstChild("Finish")
	local emitter = finish and finish:FindFirstChild("Konfeti")
	if emitter then
		emitter:Emit(60)
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
		folder = buildWorld()
	end
	removeDefaults(folder)
	setupLighting()
	local arena = Arena.new(folder)
	arena:ResetCourse()
	return arena
end

MapBuilder.Course = COURSE

return MapBuilder
