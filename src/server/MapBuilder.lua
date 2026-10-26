--[[
	MapBuilder: membangun Pulau NET QUEST secara otomatis.

	Peta (dilihat dari atas, utara = -Z):

	                 [1] ARENA LARI & PILIH (utara)
	                          |
	  [4] LAB PECAHKAN SANDI --+-- ALUN-ALUN --+-- [2] PANGGUNG KUIS KILAT (timur)
	      + Jalur Zona Materi   |  (spawn, air mancur, papan peringkat, podium)
	        TAMAN PET (barat daya)
	                 [3] MENARA LINTASAN FIREWALL (selatan, lintasan di langit)

	Dunia disimpan di Workspace > ArenaKuis (+ Terrain pulau). Jika folder itu sudah ada dan
	versinya sama, dunia lama dipakai apa adanya (boleh dihias sendiri di Studio).
	Membangun dunia di mode edit (Command Bar):
	    require(game.ServerScriptService.QuizServer.MapBuilder).Build()

	ASET TOOLBOX (opsional): taruh model di ServerStorage > AsetDunia dengan nama
	Pohon, PohonKelapa, Bangku, Lampu, Batu, Semak. Jika ada, model itu dipakai menggantikan
	hiasan bawaan (pohon/bangku/lampu dari Part).
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("QuizShared")
local Config = require(Shared:WaitForChild("Config"))
local Materi = require(Shared:WaitForChild("Materi"))
local PetCatalog = require(Shared:WaitForChild("PetCatalog"))

local MapBuilder = {}

local WORLD_NAME = "ArenaKuis"
local WORLD_VERSION = 3
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(24, 28, 48)
local STONE = Color3.fromRGB(228, 222, 208)
local STONE_DARK = Color3.fromRGB(196, 188, 170)
local WOOD = Color3.fromRGB(166, 120, 80)

-- warna khas tiap zona
local ZONE = {
	arena = Color3.fromRGB(64, 140, 240),
	stage = Color3.fromRGB(245, 180, 40),
	course = Color3.fromRGB(240, 100, 70),
	lab = Color3.fromRGB(60, 180, 130),
	pets = Color3.fromRGB(240, 110, 170),
}

-- ARENA 1 (Lari & Pilih)
local ARENA_Z = -150 -- garis tengah kotak jawaban
local PAD_X = { -33, -11, 11, 33 }
local PAD_SIZE = Vector3.new(22, 2, 22)
local IDLE_PAD_COLOR = Color3.fromRGB(150, 155, 175)

-- ARENA 3 (Lintasan Firewall di langit, mulai di atas menara selatan)
local COURSE = {
	startX = 12,
	y = 90,
	z = 150,
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

-- silinder tegak (sumbu Y) dengan tinggi & diameter
local function column(parent, name, position, height, diameter, color, material, extra)
	local props = { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material }
	for key, value in pairs(extra or {}) do
		props[key] = value
	end
	return part(props, parent)
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

local function corner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function billboard(parent, text, color, size, offset)
	local gui = make("BillboardGui", { Name = "Label", Size = size or UDim2.fromScale(12, 3), StudsOffset = offset or Vector3.new(0, 4, 0),
		LightInfluence = 0, MaxDistance = 120 }, parent)
	label(gui, { Name = "Teks", Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color or WHITE,
		Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.25, TextStrokeColor3 = INK })
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
-- ASET TOOLBOX (opsional) + hiasan bawaan
---------------------------------------------------------------------
local assetFolder = ServerStorage:FindFirstChild("AsetDunia")

local function placeAsset(slot, cframe, parent)
	local template = assetFolder and assetFolder:FindFirstChild(slot)
	if not template then
		return false
	end
	local copy = template:Clone()
	if copy:IsA("Model") or copy:IsA("BasePart") then
		copy:PivotTo(cframe)
	end
	copy.Parent = parent
	return true
end

local LEAF_COLORS = { Color3.fromRGB(96, 168, 82), Color3.fromRGB(80, 150, 72), Color3.fromRGB(120, 186, 92) }
local BLOSSOM = Color3.fromRGB(255, 182, 206)

local function tree(parent, position, scale, leafColor)
	scale = scale or 1
	if placeAsset("Pohon", CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0), parent) then
		return
	end
	local h = 8 * scale
	column(parent, "Batang", position + Vector3.new(0, h / 2, 0), h, 1.8 * scale, Color3.fromRGB(128, 92, 64), Enum.Material.Wood)
	local color = leafColor or LEAF_COLORS[math.random(1, #LEAF_COLORS)]
	local blobs = {
		{ Vector3.new(0, h / scale + 1.2, 0), 8 },
		{ Vector3.new(2.4, h / scale - 0.6, 1.2), 5.5 },
		{ Vector3.new(-2.2, h / scale - 0.2, -1.4), 5.5 },
		{ Vector3.new(0.6, h / scale + 3.6, -0.4), 5 },
	}
	for _, b in ipairs(blobs) do
		local size = b[2] * scale
		part({ Name = "Daun", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = position + b[1] * scale,
			Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false }, parent)
	end
end

local function palm(parent, position, angle)
	if placeAsset("PohonKelapa", CFrame.new(position) * CFrame.Angles(0, angle, 0), parent) then
		return
	end
	local lean = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	local top
	for i = 0, 4 do
		local cf = lean * CFrame.Angles(math.rad(-4 * i), 0, 0) * CFrame.new(0, 2.2 + i * 2.6, -i * 0.5)
		part({ Name = "BatangKelapa", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.8, 1.5 - i * 0.12, 1.5 - i * 0.12),
			CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(150, 116, 80), Material = Enum.Material.Wood }, parent)
		top = cf
	end
	for i = 1, 7 do
		local frondAngle = i / 7 * math.pi * 2
		part({ Name = "Pelepah", Size = Vector3.new(1.4, 0.2, 7), CFrame = top * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, frondAngle, 0)
			* CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -3.2), Color = Color3.fromRGB(80, 160, 70), CanCollide = false }, parent)
	end
end

local function bush(parent, position, scale)
	if placeAsset("Semak", CFrame.new(position), parent) then
		return
	end
	scale = scale or 1
	for i, offset in ipairs({ Vector3.new(0, 1, 0), Vector3.new(1.4, 0.8, 0.6), Vector3.new(-1.2, 0.8, -0.5) }) do
		local size = (i == 1 and 3.2 or 2.4) * scale
		part({ Name = "Semak", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = position + offset * scale,
			Color = LEAF_COLORS[2], CanCollide = false }, parent)
	end
end

local FLOWER_COLORS = { Color3.fromRGB(255, 110, 130), Color3.fromRGB(255, 214, 90), Color3.fromRGB(190, 140, 255), Color3.fromRGB(255, 255, 255) }

local function flowerBed(parent, cframe, length)
	part({ Name = "Bedengan", Size = Vector3.new(length, 0.8, 3), CFrame = cframe * CFrame.new(0, 0.4, 0),
		Color = Color3.fromRGB(120, 92, 70), Material = Enum.Material.Ground }, parent)
	part({ Name = "Hijau", Size = Vector3.new(length - 0.4, 0.5, 2.6), CFrame = cframe * CFrame.new(0, 1, 0),
		Color = LEAF_COLORS[1], CanCollide = false }, parent)
	for i = 1, math.floor(length / 1.6) do
		local x = -length / 2 + i * 1.6 - 0.6
		part({ Name = "Bunga", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = cframe * CFrame.new(x, 1.5, (i % 2 == 0) and 0.55 or -0.55),
			Color = FLOWER_COLORS[(i % #FLOWER_COLORS) + 1], CanCollide = false }, parent)
	end
end

local function bench(parent, cframe)
	if placeAsset("Bangku", cframe, parent) then
		return
	end
	part({ Name = "Dudukan", Size = Vector3.new(6, 0.4, 2), CFrame = cframe * CFrame.new(0, 1.6, 0), Color = WOOD, Material = Enum.Material.Wood }, parent)
	part({ Name = "Sandaran", Size = Vector3.new(6, 1.4, 0.3), CFrame = cframe * CFrame.new(0, 2.8, 0.9), Color = WOOD, Material = Enum.Material.Wood }, parent)
	for _, x in ipairs({ -2.6, 2.6 }) do
		part({ Name = "Kaki", Size = Vector3.new(0.4, 1.6, 1.8), CFrame = cframe * CFrame.new(x, 0.8, 0), Color = Color3.fromRGB(70, 72, 84),
			Material = Enum.Material.Metal }, parent)
	end
end

local function lampPost(parent, position)
	if placeAsset("Lampu", CFrame.new(position), parent) then
		return
	end
	column(parent, "TiangLampu", position + Vector3.new(0, 5, 0), 10, 0.6, Color3.fromRGB(60, 64, 78), Enum.Material.Metal)
	part({ Name = "Topi", Size = Vector3.new(1.8, 0.3, 1.8), Position = position + Vector3.new(0, 11.4, 0), Color = Color3.fromRGB(60, 64, 78),
		Material = Enum.Material.Metal }, parent)
	local bulb = part({ Name = "Bohlam", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Position = position + Vector3.new(0, 10.6, 0),
		Color = Color3.fromRGB(255, 240, 205), Material = Enum.Material.Neon, CanCollide = false }, parent)
	make("PointLight", { Range = 18, Brightness = 0.8, Color = Color3.fromRGB(255, 230, 190) }, bulb)
end

local function rock(parent, position, size)
	if placeAsset("Batu", CFrame.new(position), parent) then
		return
	end
	part({ Name = "Batu", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = position + Vector3.new(0, size * 0.2, 0),
		Color = Color3.fromRGB(150, 150, 158), Material = Enum.Material.Rock }, parent)
end

-- Gapura zona: dua tiang + papan nama bernomor (terbaca dari kedua sisi)
local function arch(parent, cframe, width, number, title, color)
	local folder = make("Folder", { Name = "Gapura" }, parent)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Tiang", Size = Vector3.new(2, 16, 2), CFrame = cframe * CFrame.new(side * width / 2, 8, 0), Color = WHITE }, folder)
		part({ Name = "Kepala", Size = Vector3.new(2.6, 1, 2.6), CFrame = cframe * CFrame.new(side * width / 2, 16.5, 0), Color = color }, folder)
	end
	local sign = part({ Name = "Papan", Size = Vector3.new(width + 2, 4.5, 1), CFrame = cframe * CFrame.new(0, 14.5, 0), Color = color }, folder)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = surfaceGui(sign, face, 25)
		local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, gui)
		if number then
			local badge = make("Frame", { Size = UDim2.new(0, 84, 0, 84), Position = UDim2.new(0, 14, 0.5, -42),
				BackgroundColor3 = WHITE, BorderSizePixel = 0 }, bg)
			corner(badge, 42)
			label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(number), Font = Enum.Font.FredokaOne, TextColor3 = color })
		end
		label(bg, { Size = UDim2.new(1, number and -130 or -24, 0.8, 0), Position = UDim2.new(0, number and 112 or 12, 0.1, 0),
			Text = title, Font = Enum.Font.FredokaOne, TextXAlignment = number and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center })
	end
	return folder
end

-- Layar soal (ada di beberapa zona; semua layar menampilkan isi yang sama)
local function questionScreen(parent, name, cframe, size, face, accent)
	local screen = part({ Name = name, Size = size, CFrame = cframe, Color = INK }, parent)
	screen:SetAttribute("LayarKuis", true)
	local gui = surfaceGui(screen, face, 20)
	local frame = make("Frame", { Name = "Isi", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 26, 52),
		BorderSizePixel = 0 }, gui)
	make("UIStroke", { Thickness = 12, Color = accent, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	local header = make("Frame", { Name = "Header", Size = UDim2.fromScale(1, 0.16), BackgroundColor3 = accent, BorderSizePixel = 0 }, frame)
	label(header, { Name = "Topik", Size = UDim2.fromScale(0.56, 0.72), Position = UDim2.fromScale(0.02, 0.14),
		TextXAlignment = Enum.TextXAlignment.Left, Text = Config.GameSubtitle })
	label(header, { Name = "Nomor", Size = UDim2.fromScale(0.24, 0.72), Position = UDim2.fromScale(0.59, 0.14), Text = "" })
	label(header, { Name = "Waktu", Size = UDim2.fromScale(0.13, 0.86), Position = UDim2.fromScale(0.85, 0.07), Text = "",
		Font = Enum.Font.FredokaOne })
	label(frame, { Name = "Pertanyaan", Size = UDim2.fromScale(0.94, 0.54), Position = UDim2.fromScale(0.03, 0.19),
		Text = Config.GameTitle, Font = Enum.Font.FredokaOne, MaxTextSize = 100 })
	label(frame, { Name = "Info", Size = UDim2.fromScale(0.94, 0.22), Position = UDim2.fromScale(0.03, 0.75),
		Text = "", Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(196, 214, 255), MaxTextSize = 44 })
	return screen
end

-- Panel jawaban berwarna (papan kotak jawaban & panggung)
local function answerPanel(target, face, pps, index)
	local gui = surfaceGui(target, face, pps)
	local bg = make("Frame", { Name = "Latar", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Config.PadColors[index], BorderSizePixel = 0 }, gui)
	make("UIStroke", { Thickness = 6, Color = WHITE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bg)
	label(bg, { Name = "Huruf", Size = UDim2.fromScale(0.2, 0.9), Position = UDim2.fromScale(0.02, 0.05), Text = Config.PadLetters[index],
		Font = Enum.Font.FredokaOne })
	label(bg, { Name = "Jawaban", Size = UDim2.fromScale(0.74, 0.7), Position = UDim2.fromScale(0.23, 0.08), Text = "", MaxTextSize = 64 })
	label(bg, { Name = "Jumlah", Size = UDim2.fromScale(0.74, 0.2), Position = UDim2.fromScale(0.23, 0.78), Text = "",
		TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamMedium })
	return bg
end

---------------------------------------------------------------------
-- TERRAIN PULAU & PENCAHAYAAN
---------------------------------------------------------------------
local function buildTerrain()
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -11, 0), Vector3.new(640, 18, 640), Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(0, -7, 0), 12, 236, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(0, -6, 0), 12, 220, Enum.Material.Grass)
	-- bukit kecil di sudut-sudut pulau (jauh dari zona permainan)
	for _, hill in ipairs({ { 120, -120, 22 }, { -125, -115, 20 }, { 125, 95, 16 }, { -40, 185, 14 }, { 192, -70, 14 } }) do
		terrain:FillBall(Vector3.new(hill[1], -8, hill[2]), hill[3], Enum.Material.Grass)
	end
	-- kolam di bawah kotak jawaban (Arena 1)
	terrain:FillBlock(CFrame.new(0, -10, ARENA_Z), Vector3.new(96, 20, 28), Enum.Material.Air)
	terrain.WaterColor = Color3.fromRGB(40, 150, 200)
	terrain.WaterTransparency = 0.5
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
	pcall(function()
		terrain.Decoration = true -- rumput bergoyang
	end)
	if not terrain:FindFirstChildOfClass("Clouds") then
		make("Clouds", { Cover = 0.5, Density = 0.55, Color = WHITE }, terrain)
	end
end

local function setupLighting()
	Lighting.ClockTime = Config.ClockTime
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(110, 112, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 152, 165)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.5
	local function ensure(className, name, props)
		if not Lighting:FindFirstChild(name) then
			local effect = make(className, props, Lighting)
			effect.Name = name
		end
	end
	ensure("BloomEffect", "BloomKuis", { Intensity = 0.3, Size = 24, Threshold = 1.7 })
	ensure("ColorCorrectionEffect", "WarnaKuis", { Saturation = 0.12, Contrast = 0.06, Brightness = 0.02 })
	ensure("SunRaysEffect", "SinarKuis", { Intensity = 0.03, Spread = 0.7 })
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		make("Atmosphere", { Density = 0.24, Offset = 0.15, Color = Color3.fromRGB(205, 222, 240),
			Decay = Color3.fromRGB(120, 140, 170), Glare = 0.25, Haze = 1 }, Lighting)
	end
end

---------------------------------------------------------------------
-- ALUN-ALUN (spawn, air mancur, papan peringkat, podium)
---------------------------------------------------------------------
local function buildPlaza(world)
	local plaza = make("Folder", { Name = "Alun" }, world)
	column(plaza, "Lantai", Vector3.new(0, -0.45, 0), 1, 88, STONE, Enum.Material.Pavement)
	column(plaza, "Cincin", Vector3.new(0, 0.07, 0), 0.1, 46, STONE_DARK, Enum.Material.Pavement, { CanCollide = false })
	column(plaza, "CincinDalam", Vector3.new(0, 0.09, 0), 0.1, 42, STONE, Enum.Material.Pavement, { CanCollide = false })

	make("SpawnLocation", { Name = "Spawn", Anchored = true, Size = Vector3.new(10, 0.4, 10), Position = Vector3.new(0, 0.25, 30),
		Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.SmoothPlastic, Neutral = true, Duration = 0,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, plaza)

	-- air mancur + globe internet
	column(plaza, "Kolam", Vector3.new(0, 1, 0), 2, 20, Color3.fromRGB(240, 236, 228), Enum.Material.Marble)
	column(plaza, "Air", Vector3.new(0, 2.05, 0), 0.3, 17.6, Color3.fromRGB(80, 180, 235), Enum.Material.Glass,
		{ Transparency = 0.25, CanCollide = false })
	column(plaza, "Tiang", Vector3.new(0, 3.5, 0), 5, 3, Color3.fromRGB(240, 236, 228), Enum.Material.Marble)
	column(plaza, "Mangkuk", Vector3.new(0, 6.2, 0), 0.8, 7, Color3.fromRGB(240, 236, 228), Enum.Material.Marble)
	local spray = part({ Name = "Semburan", Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, 7, 0), Transparency = 1,
		CanCollide = false }, plaza)
	make("ParticleEmitter", { Rate = 35, Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(10, 14),
		SpreadAngle = Vector2.new(20, 20), Acceleration = Vector3.new(0, -30, 0), Size = NumberSequence.new(0.45, 0.1),
		Color = ColorSequence.new(Color3.fromRGB(210, 240, 255)), Transparency = NumberSequence.new(0.2, 1),
		EmissionDirection = Enum.NormalId.Top }, spray)
	local globe = part({ Name = "GlobeInternet", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6),
		Position = Vector3.new(0, 13, 0), Color = Color3.fromRGB(70, 190, 255), Material = Enum.Material.ForceField,
		CanCollide = false }, plaza)
	make("PointLight", { Range = 18, Brightness = 1.5, Color = Color3.fromRGB(70, 190, 255) }, globe)

	-- bangku menghadap air mancur (di diagonal agar jalur utama tetap lega)
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local position = Vector3.new(math.sin(angle) * 15, 0, math.cos(angle) * 15)
		-- sisi depan bangku = -Z lokal, jadi -Z diarahkan ke air mancur
		bench(plaza, CFrame.lookAt(position, Vector3.new(0, 0, 0)))
	end
	for i = 0, 7 do
		local angle = math.rad(22.5 + i * 45)
		lampPost(plaza, Vector3.new(math.sin(angle) * 40, 0, math.cos(angle) * 40))
	end

	-- PAPAN PERINGKAT + PODIUM (timur laut, menghadap pusat)
	local base = CFrame.lookAt(Vector3.new(27, 0, -27), Vector3.new(0, 0, 0))
	local podium = make("Folder", { Name = "Podium" }, world)
	local board = part({ Name = "PapanPeringkat", Size = Vector3.new(24, 16, 1), CFrame = base * CFrame.new(0, 12, 0), Color = INK }, podium)
	for _, x in ipairs({ -12.6, 12.6 }) do
		part({ Name = "TiangPapan", Size = Vector3.new(1.4, 21, 1.4), CFrame = base * CFrame.new(x, 10.5, 0), Color = WHITE }, podium)
	end
	part({ Name = "AtapPapan", Size = Vector3.new(27, 1, 3), CFrame = base * CFrame.new(0, 21, 0), Color = Color3.fromRGB(255, 196, 60) }, podium)
	local gui = surfaceGui(board, Enum.NormalId.Front, 30)
	local bg = make("Frame", { Name = "Isi", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(26, 30, 60), BorderSizePixel = 0 }, gui)
	local head = make("Frame", { Size = UDim2.fromScale(1, 0.17), BackgroundColor3 = Color3.fromRGB(255, 196, 60), BorderSizePixel = 0 }, bg)
	label(head, { Name = "Judul", Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1), Text = "PAPAN PERINGKAT",
		Font = Enum.Font.FredokaOne, TextColor3 = INK })
	local list = make("Frame", { Name = "Daftar", Size = UDim2.fromScale(0.94, 0.78), Position = UDim2.fromScale(0.03, 0.2),
		BackgroundTransparency = 1 }, bg)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	for i = 1, 8 do
		local row = make("Frame", { Name = "Baris" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 0.115, -6),
			BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(36, 42, 80) or Color3.fromRGB(44, 52, 96), BorderSizePixel = 0 }, list)
		corner(row, 8)
		label(row, { Name = "Peringkat", Size = UDim2.fromScale(0.1, 0.8), Position = UDim2.fromScale(0.01, 0.1), Text = tostring(i),
			Font = Enum.Font.FredokaOne, TextColor3 = i <= 3 and Color3.fromRGB(255, 205, 70) or WHITE })
		label(row, { Name = "Nama", Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.13, 0.15), Text = i == 1 and "Belum ada data" or "",
			TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold })
		label(row, { Name = "Poin", Size = UDim2.fromScale(0.24, 0.7), Position = UDim2.fromScale(0.74, 0.15), Text = "",
			TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 205, 70) })
	end
	local podiumData = {
		{ x = 0, h = 4.5, color = Color3.fromRGB(255, 205, 60), text = "1" },
		{ x = -7.5, h = 3.2, color = Color3.fromRGB(205, 212, 228), text = "2" },
		{ x = 7.5, h = 2.2, color = Color3.fromRGB(220, 140, 80), text = "3" },
	}
	for rank, data in ipairs(podiumData) do
		local block = part({ Name = "Juara" .. rank, Size = Vector3.new(7, data.h, 7), CFrame = base * CFrame.new(data.x, data.h / 2, -8),
			Color = data.color }, podium)
		confettiEmitter(block)
		label(surfaceGui(block, Enum.NormalId.Front, 30), { Size = UDim2.fromScale(1, 1), Text = data.text,
			Font = Enum.Font.FredokaOne, TextColor3 = INK })
	end

	-- papan PETUALANGAN 4 GAME (barat laut, menghadap pusat)
	local infoBase = CFrame.lookAt(Vector3.new(-27, 0, -27), Vector3.new(0, 0, 0))
	local info = part({ Name = "PapanCaraMain", Size = Vector3.new(18, 12, 0.8), CFrame = infoBase * CFrame.new(0, 9, 0), Color = WHITE }, plaza)
	for _, x in ipairs({ -9.4, 9.4 }) do
		part({ Name = "TiangInfo", Size = Vector3.new(1, 15, 1), CFrame = infoBase * CFrame.new(x, 7.5, 0), Color = WOOD,
			Material = Enum.Material.Wood }, plaza)
	end
	local infoGui = surfaceGui(info, Enum.NormalId.Front, 40)
	local infoBg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 251, 240), BorderSizePixel = 0 }, infoGui)
	label(infoBg, { Size = UDim2.fromScale(0.92, 0.16), Position = UDim2.fromScale(0.04, 0.04), Text = "PETUALANGAN 4 GAME",
		Font = Enum.Font.FredokaOne, TextColor3 = INK })
	local steps = {
		{ "1", "Lari & Pilih", "Arena utara", ZONE.arena },
		{ "2", "Kuis Kilat", "Panggung timur", ZONE.stage },
		{ "3", "Lintasan Firewall", "Menara selatan", ZONE.course },
		{ "4", "Pecahkan Sandi", "Lab barat", ZONE.lab },
	}
	for i, step in ipairs(steps) do
		local row = make("Frame", { Size = UDim2.fromScale(0.92, 0.15), Position = UDim2.fromScale(0.04, 0.06 + i * 0.16),
			BackgroundColor3 = step[4], BorderSizePixel = 0 }, infoBg)
		corner(row, 10)
		label(row, { Size = UDim2.fromScale(0.12, 0.8), Position = UDim2.fromScale(0.02, 0.1), Text = step[1], Font = Enum.Font.FredokaOne })
		label(row, { Size = UDim2.fromScale(0.5, 0.7), Position = UDim2.fromScale(0.15, 0.15), Text = step[2],
			TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
		label(row, { Size = UDim2.fromScale(0.32, 0.6), Position = UDim2.fromScale(0.66, 0.2), Text = step[3],
			TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamMedium })
	end
	label(infoBg, { Size = UDim2.fromScale(0.92, 0.1), Position = UDim2.fromScale(0.04, 0.87),
		Text = "Poin dari keempat game dijumlahkan menjadi POIN TOTAL!", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(90, 96, 120) })

	-- taman bunga tenggara
	local garden = CFrame.lookAt(Vector3.new(26, 0, 26), Vector3.new(0, 0, 0))
	flowerBed(plaza, garden, 12)
	flowerBed(plaza, garden * CFrame.new(0, 0, 4), 9)
end

---------------------------------------------------------------------
-- JALAN SETAPAK
---------------------------------------------------------------------
local function buildPaths(world)
	local paths = make("Folder", { Name = "Jalan" }, world)
	local color = Color3.fromRGB(214, 204, 184)
	local function slab(name, cframe, size)
		part({ Name = name, Size = size, CFrame = cframe, Color = color, Material = Enum.Material.Pavement }, paths)
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Tepi", Size = Vector3.new(0.6, 0.7, size.Z), CFrame = cframe * CFrame.new(side * (size.X / 2 + 0.3), 0.05, 0),
				Color = STONE_DARK, Material = Enum.Material.Pavement }, paths)
		end
	end
	slab("JalanUtara", CFrame.new(0, -0.2, -79.5), Vector3.new(12, 0.6, 71))
	slab("JalanTimur", CFrame.new(70, -0.2, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(12, 0.6, 52))
	slab("JalanSelatan", CFrame.new(0, -0.2, 88), Vector3.new(12, 0.6, 88))
	slab("JalanBarat", CFrame.new(-82, -0.2, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(12, 0.6, 76))
	slab("JalanTamanPet", CFrame.new(-57, -0.2, 57) * CFrame.Angles(0, math.rad(-45), 0), Vector3.new(10, 0.6, 72))

	local deco = make("Folder", { Name = "HiasanJalan" }, world)
	for z = -58, -102, -22 do
		tree(deco, Vector3.new(-16, 0, z), 1)
		tree(deco, Vector3.new(16, 0, z - 11), 1)
	end
	for x = 56, 86, 30 do
		tree(deco, Vector3.new(x, 0, -16), 1)
		tree(deco, Vector3.new(x + 12, 0, 16), 1)
	end
	for z = 58, 114, 22 do
		tree(deco, Vector3.new(-16, 0, z), 0.95)
		tree(deco, Vector3.new(16, 0, z + 11), 0.95)
		lampPost(deco, Vector3.new(9, 0, z))
	end
end

---------------------------------------------------------------------
-- [1] ARENA LARI & PILIH (utara)
---------------------------------------------------------------------
local function buildArena(world)
	local arena = make("Folder", { Name = "ArenaLariPilih" }, world)
	local az = ARENA_Z
	part({ Name = "GarisStart", Size = Vector3.new(100, 2, 24), Position = Vector3.new(0, -1, az + 23),
		Color = Color3.fromRGB(150, 170, 220) }, arena)
	for i = 0, 4 do
		part({ Name = "Garis", Size = Vector3.new(100, 0.1, 0.4), Position = Vector3.new(0, 0.03, az + 14 + i * 5),
			Color = Color3.fromRGB(176, 192, 232), CanCollide = false }, arena)
	end
	part({ Name = "GarisNeon", Size = Vector3.new(88, 0.2, 0.6), Position = Vector3.new(0, 0.05, az + 11.3),
		Color = WHITE, Material = Enum.Material.Neon, CanCollide = false }, arena)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "SampingKotak", Size = Vector3.new(6, 2, 22), Position = Vector3.new(47 * side, -1, az),
			Color = Color3.fromRGB(120, 130, 170) }, arena)
	end

	-- KOTAK JAWABAN
	local pads = make("Folder", { Name = "KotakJawaban" }, world)
	for i = 1, 4 do
		local pad = part({ Name = "Pad" .. i, Size = PAD_SIZE, Position = Vector3.new(PAD_X[i], -1, az), Color = Config.PadColors[i] }, pads)
		confettiEmitter(pad)
		make("PointLight", { Name = "Cahaya", Range = 18, Brightness = 0, Color = WHITE }, pad)
		local letter = make("BillboardGui", { Name = "Huruf", Size = UDim2.fromScale(7, 7), StudsOffset = Vector3.new(0, 10, 0),
			LightInfluence = 0, MaxDistance = 250 }, pad)
		label(letter, { Name = "Teks", Size = UDim2.fromScale(1, 1), Text = Config.PadLetters[i], Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0, TextStrokeColor3 = INK })
		local sign = part({ Name = "Papan" .. i, Size = Vector3.new(21, 6.5, 0.6), Position = Vector3.new(PAD_X[i], 4.3, az - 11.6),
			Color = INK, CanCollide = false }, pads)
		answerPanel(sign, Enum.NormalId.Back, 40, i)
	end
	for i = 1, 3 do
		part({ Name = "Pembatas", Size = Vector3.new(0.5, 0.25, 22), Position = Vector3.new((PAD_X[i] + PAD_X[i + 1]) / 2, 0.1, az),
			Color = WHITE, Material = Enum.Material.Neon, CanCollide = false }, pads)
	end

	-- KOLAM di bawah kotak: kotak salah jatuh = tercebur lalu kembali ke garis start
	local pool = make("Folder", { Name = "Kolam" }, arena)
	part({ Name = "KolamData", Size = Vector3.new(96, 2, 28), Position = Vector3.new(0, -17, az),
		Color = Color3.fromRGB(40, 110, 170) }, world)
	part({ Name = "Air", Size = Vector3.new(96, 10, 28), Position = Vector3.new(0, -11, az), Color = Color3.fromRGB(60, 170, 230),
		Material = Enum.Material.Glass, Transparency = 0.35, CanCollide = false, CanQuery = false }, pool)
	for _, data in ipairs({
		{ Vector3.new(96, 15, 1), Vector3.new(0, -9.5, az - 14.5) },
		{ Vector3.new(1, 15, 28), Vector3.new(-48.5, -9.5, az) },
		{ Vector3.new(1, 15, 28), Vector3.new(48.5, -9.5, az) },
	}) do
		part({ Name = "DindingKolam", Size = data[1], Position = data[2], Color = Color3.fromRGB(210, 220, 230) }, pool)
	end

	-- LAYAR
	questionScreen(arena, "Layar", CFrame.new(0, 25, az - 22), Vector3.new(80, 30, 1), Enum.NormalId.Back, ZONE.arena)
	local title = part({ Name = "JudulGame", Size = Vector3.new(50, 6, 1), Position = Vector3.new(0, 44, az - 22), Color = ZONE.arena }, arena)
	label(surfaceGui(title, Enum.NormalId.Back, 20), { Size = UDim2.fromScale(1, 1), Text = Config.GameTitle, Font = Enum.Font.FredokaOne })
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "TiangLayar", Size = Vector3.new(3, 48, 3), Position = Vector3.new(41.5 * side, 24, az - 22), Color = WHITE }, arena)
		for tier = 1, 3 do
			part({ Name = "Tribun", Size = Vector3.new(4, tier * 1.6, 44), Position = Vector3.new(side * (56 + (tier - 1) * 4), tier * 0.8, az + 4),
				Color = tier % 2 == 0 and WHITE or Color3.fromRGB(200, 215, 245) }, arena)
		end
	end

	local walls = make("Folder", { Name = "Dinding" }, arena)
	local function invisibleWall(size, pos)
		part({ Name = "Batas", Size = size, Position = pos, Transparency = 1 }, walls)
	end
	invisibleWall(Vector3.new(100, 40, 1), Vector3.new(0, 20, az - 12.5))
	for _, side in ipairs({ -1, 1 }) do
		invisibleWall(Vector3.new(1, 40, 48), Vector3.new(50.5 * side, 20, az + 11))
		part({ Name = "Pagar", Size = Vector3.new(1.4, 3, 48), Position = Vector3.new(51.5 * side, 1.5, az + 11), Color = LEAF_COLORS[2] }, walls)
	end
	arch(arena, CFrame.new(0, 0, az + 38), 30, 1, "LARI & PILIH", ZONE.arena)
end

---------------------------------------------------------------------
-- [2] PANGGUNG KUIS KILAT (timur)
---------------------------------------------------------------------
local function buildStage(world)
	local stage = make("Folder", { Name = "PanggungKilat" }, world)
	part({ Name = "LantaiPenonton", Size = Vector3.new(42, 1, 60), Position = Vector3.new(117, -0.45, 0), Color = STONE,
		Material = Enum.Material.Pavement }, stage)
	for i = 0, 4 do
		part({ Name = "GarisPenonton", Size = Vector3.new(0.4, 0.1, 56), Position = Vector3.new(100 + i * 8, 0.08, 0), Color = STONE_DARK,
			CanCollide = false }, stage)
	end
	part({ Name = "Panggung", Size = Vector3.new(30, 3, 58), Position = Vector3.new(153, 1.5, 0), Color = Color3.fromRGB(70, 56, 96) }, stage)
	part({ Name = "LisPanggung", Size = Vector3.new(0.6, 0.6, 58), Position = Vector3.new(138.3, 2.8, 0), Color = ZONE.stage,
		Material = Enum.Material.Neon, CanCollide = false }, stage)
	part({ Name = "Tangga", Size = Vector3.new(4, 1.5, 22), Position = Vector3.new(136, 0.75, 0), Color = Color3.fromRGB(90, 76, 120) }, stage)
	part({ Name = "DindingBelakang", Size = Vector3.new(2, 44, 62), Position = Vector3.new(169, 22, 0), Color = Color3.fromRGB(44, 38, 66) }, stage)
	questionScreen(stage, "Layar", CFrame.new(167.6, 23, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(46, 22, 0.6),
		Enum.NormalId.Back, ZONE.stage)
	local title = part({ Name = "JudulPanggung", Size = Vector3.new(0.6, 5, 40), Position = Vector3.new(167.6, 38, 0), Color = ZONE.stage }, stage)
	label(surfaceGui(title, Enum.NormalId.Left, 20), { Size = UDim2.fromScale(1, 1), Text = "KUIS KILAT", Font = Enum.Font.FredokaOne, TextColor3 = INK })
	for i = 1, 4 do
		local panel = part({ Name = "PanelJawaban" .. i, Size = Vector3.new(0.6, 7, 10.4), Position = Vector3.new(167.6, 7.5, -16.5 + (i - 1) * 11),
			Color = INK }, stage)
		answerPanel(panel, Enum.NormalId.Left, 30, i)
	end
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "MenaraLampu", Size = Vector3.new(6, 22, 6), Position = Vector3.new(155, 11, side * 34), Color = Color3.fromRGB(56, 50, 80) }, stage)
		for k = 1, 3 do
			part({ Name = "LampuMenara", Size = Vector3.new(6.2, 0.6, 6.2), Position = Vector3.new(155, 5 + k * 5, side * 34),
				Color = k % 2 == 0 and ZONE.stage or WHITE, Material = Enum.Material.Neon, CanCollide = false }, stage)
		end
		local spot = part({ Name = "Sorot", Size = Vector3.new(2, 2, 2), Position = Vector3.new(150, 23, side * 30), Color = INK }, stage)
		make("SpotLight", { Face = Enum.NormalId.Bottom, Range = 40, Brightness = 2, Angle = 60, Color = Color3.fromRGB(255, 240, 210) }, spot)
	end
	arch(stage, CFrame.new(93, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), 30, 2, "KUIS KILAT", ZONE.stage)
end

---------------------------------------------------------------------
-- [3] MENARA & LINTASAN FIREWALL (selatan, di langit)
---------------------------------------------------------------------
local function buildCourse(world)
	local course = make("Folder", { Name = "LintasanFirewall" }, world)
	local y, zc, width = COURSE.y, COURSE.z, COURSE.width
	local floorColor = Color3.fromRGB(96, 104, 150)
	local towerX = COURSE.startX - 10

	column(course, "LantaiMenara", Vector3.new(towerX, -0.42, zc), 1, 40, STONE, Enum.Material.Pavement)
	column(course, "Menara", Vector3.new(towerX, (y - 1) / 2, zc), y - 1, 18, Color3.fromRGB(236, 232, 224), Enum.Material.SmoothPlastic)
	for k = 1, 5 do
		column(course, "Cincin", Vector3.new(towerX, k * (y / 6), zc), 2.4, 18.6, ZONE.course, Enum.Material.SmoothPlastic)
	end
	local door = part({ Name = "PintuMenara", Size = Vector3.new(6, 9, 1), Position = Vector3.new(towerX, 4.5, zc - 9), Color = ZONE.course }, course)
	label(surfaceGui(door, Enum.NormalId.Front, 30), { Size = UDim2.fromScale(0.9, 0.5), Position = UDim2.fromScale(0.05, 0.25),
		Text = "Naik otomatis saat Game 3 dimulai", Font = Enum.Font.GothamBold })
	arch(course, CFrame.new(0, 0, 128) * CFrame.Angles(0, math.pi, 0), 30, 3, "LINTASAN FIREWALL", ZONE.course)

	local start = part({ Name = "Start", Size = Vector3.new(20, 1, width), Position = Vector3.new(COURSE.startX - 10, y - 0.5, zc),
		Color = Color3.fromRGB(80, 200, 130) }, course)
	billboard(start, "LINTASAN FIREWALL", ZONE.course, UDim2.fromScale(20, 3), Vector3.new(0, 11, 0))
	part({ Name = "Penghalang", Size = Vector3.new(1, 12, width), Position = Vector3.new(COURSE.startX - 0.5, y + 6, zc),
		Color = Color3.fromRGB(255, 80, 80), Material = Enum.Material.ForceField }, course)
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
				Color = ZONE.course, Material = Enum.Material.Neon, CanCollide = false }, folder)
		end
		local wallColor = Color3.fromRGB(210, 84, 70)
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
			label(gui, { Name = "Jawaban", Size = UDim2.fromScale(0.73, 0.9), Position = UDim2.fromScale(0.26, 0.05), Text = "", MaxTextSize = 40 })
			part({ Name = "Jalur" .. lane, Size = Vector3.new(14, 1, 7), Position = Vector3.new(x0 + 24, y - 0.5, lz), Color = floorColor }, folder)
		end
		for i = 0, 4 do
			part({ Name = "SekatJalur", Size = Vector3.new(14, 8, 0.4), Position = Vector3.new(x0 + 24, y + 4, zc - width / 2 + i * 7),
				Color = Color3.fromRGB(210, 235, 255), Material = Enum.Material.Glass, Transparency = 0.6 }, folder)
		end
		local board = part({ Name = "PapanSoal", Size = Vector3.new(0.4, 8, width), Position = Vector3.new(x0 + 15.8, y + 16.5, zc), Color = INK }, folder)
		local boardGui = surfaceGui(board, Enum.NormalId.Left, 25)
		label(boardGui, { Name = "Nomor", Size = UDim2.fromScale(1, 0.2), Text = "GERBANG " .. gate, Font = Enum.Font.FredokaOne,
			TextColor3 = Color3.fromRGB(255, 170, 90) })
		label(boardGui, { Name = "Soal", Size = UDim2.fromScale(0.96, 0.76), Position = UDim2.fromScale(0.02, 0.22), Text = "", MaxTextSize = 44 })
		part({ Name = "Gabung", Size = Vector3.new(5, 1, width), Position = Vector3.new(x0 + 33.5, y - 0.5, zc), Color = floorColor }, folder)
		local zig = (gate % 2 == 0) and 1 or -1
		part({ Name = "Lompat1", Size = Vector3.new(4, 1, 6), Position = Vector3.new(x0 + 42, y + 0.5, zc + zig * 5),
			Color = Color3.fromRGB(255, 200, 80) }, folder)
		part({ Name = "Lompat2", Size = Vector3.new(4, 1, 6), Position = Vector3.new(x0 + 50, y + 1.5, zc - zig * 5),
			Color = Color3.fromRGB(255, 160, 80) }, folder)
	end

	local finish = part({ Name = "Finish", Size = Vector3.new(24, 1, width), Position = Vector3.new(COURSE.finishX + 12, y - 0.5, zc),
		Color = Color3.fromRGB(255, 205, 60) }, course)
	confettiEmitter(finish)
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "TiangFinish", Size = Vector3.new(1.5, 16, 1.5), Position = Vector3.new(COURSE.finishX + 4, y + 8, zc + side * 12),
			Color = WHITE }, course)
		part({ Name = "PagarFinish", Size = Vector3.new(24, 4, 0.6), Position = Vector3.new(COURSE.finishX + 12, y + 2, zc + side * (width / 2)),
			Color = WHITE, Material = Enum.Material.Glass, Transparency = 0.6 }, course)
	end
	part({ Name = "PagarFinishUjung", Size = Vector3.new(0.6, 4, width), Position = Vector3.new(COURSE.finishX + 24, y + 2, zc),
		Color = WHITE, Material = Enum.Material.Glass, Transparency = 0.6 }, course)
	local banner = part({ Name = "SpandukFinish", Size = Vector3.new(1, 4, 25.5), Position = Vector3.new(COURSE.finishX + 4, y + 14, zc),
		Color = Color3.fromRGB(255, 90, 130) }, course)
	label(surfaceGui(banner, Enum.NormalId.Left, 30), { Size = UDim2.fromScale(1, 1), Text = "FINISH", Font = Enum.Font.FredokaOne })
end

---------------------------------------------------------------------
-- [4] LAB PECAHKAN SANDI + JALUR ZONA MATERI (barat)
---------------------------------------------------------------------
local function buildLab(world)
	local lab = make("Folder", { Name = "LabSandi" }, world)
	part({ Name = "Lantai", Size = Vector3.new(64, 1, 60), Position = Vector3.new(-152, 0.5, 0), Color = Color3.fromRGB(236, 226, 206),
		Material = Enum.Material.WoodPlanks }, lab)
	part({ Name = "Undakan", Size = Vector3.new(3, 0.5, 18), Position = Vector3.new(-118.5, 0.25, 0), Color = STONE_DARK }, lab)
	for _, x in ipairs({ -182, -152, -122 }) do
		for _, z in ipairs({ -28, 28 }) do
			part({ Name = "Pilar", Size = Vector3.new(2, 16, 2), Position = Vector3.new(x, 9, z), Color = WHITE }, lab)
		end
	end
	part({ Name = "Atap", Size = Vector3.new(68, 1.2, 64), Position = Vector3.new(-152, 17.6, 0), Color = ZONE.lab }, lab)
	part({ Name = "LisAtap", Size = Vector3.new(68.4, 0.6, 64.4), Position = Vector3.new(-152, 16.8, 0), Color = WHITE }, lab)
	part({ Name = "DindingPapan", Size = Vector3.new(1, 16, 58), Position = Vector3.new(-184, 9, 0), Color = Color3.fromRGB(246, 240, 226) }, lab)
	questionScreen(lab, "Layar", CFrame.new(-183.2, 10, 0) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(40, 13, 0.6),
		Enum.NormalId.Back, ZONE.lab)
	-- meja komputer (siswa menghadap papan di barat)
	for _, x in ipairs({ -172, -163 }) do
		for _, z in ipairs({ -19.5, -6.5, 6.5, 19.5 }) do
			part({ Name = "Meja", Size = Vector3.new(3, 0.4, 9), Position = Vector3.new(x, 3.6, z), Color = WOOD, Material = Enum.Material.Wood }, lab)
			for _, dz in ipairs({ -4, 4 }) do
				part({ Name = "KakiMeja", Size = Vector3.new(2.6, 2.4, 0.3), Position = Vector3.new(x, 2.2, z + dz), Color = Color3.fromRGB(80, 84, 96) }, lab)
			end
			for _, dz in ipairs({ -2.2, 2.2 }) do
				part({ Name = "Monitor", Size = Vector3.new(0.3, 1.7, 2.6), Position = Vector3.new(x - 0.8, 4.75, z + dz), Color = INK }, lab)
				part({ Name = "LayarMonitor", Size = Vector3.new(0.05, 1.4, 2.3), Position = Vector3.new(x - 0.62, 4.75, z + dz),
					Color = Color3.fromRGB(110, 230, 170), Material = Enum.Material.Neon, CanCollide = false }, lab)
			end
		end
	end
	arch(lab, CFrame.new(-116, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 30, 4, "PECAHKAN SANDI", ZONE.lab)

	-- JALUR ZONA MATERI: papan materi di kiri-kanan jalan menuju lab
	local boards = make("Folder", { Name = "ZonaMateri" }, world)
	local topics = {}
	for _, topic in ipairs(Config.Topics) do
		if topic.id ~= "campuran" then
			table.insert(topics, topic)
		end
	end
	for index, topic in ipairs(topics) do
		local x = -60 - ((index - 1) % 3) * 20
		local side = index <= 3 and 1 or -1
		local z = side * 15
		local base = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0))
		local board = part({ Name = "Materi_" .. topic.id, Size = Vector3.new(16, 10, 0.5), CFrame = base * CFrame.new(0, 7, 0),
			Color = Color3.fromRGB(255, 252, 244) }, boards)
		board:SetAttribute("TopicId", topic.id)
		local gui = surfaceGui(board, Enum.NormalId.Front, 60)
		local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 252, 244), BorderSizePixel = 0 }, gui)
		local titleFrame = make("Frame", { Size = UDim2.fromScale(1, 0.15), BackgroundColor3 = topic.color, BorderSizePixel = 0 }, bg)
		label(titleFrame, { Size = UDim2.fromScale(0.96, 0.8), Position = UDim2.fromScale(0.02, 0.1), Text = string.upper(topic.name),
			Font = Enum.Font.FredokaOne, TextColor3 = INK })
		local body = make("Frame", { Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.18), BackgroundTransparency = 1 }, bg)
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
		for order, point in ipairs(Materi[topic.id] or {}) do
			label(body, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false, TextSize = 24,
				Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Text = "• " .. point,
				TextColor3 = Color3.fromRGB(40, 45, 70) })
		end
		make("ProximityPrompt", { Name = "BacaMateri", ActionText = "Baca Materi", ObjectText = topic.name, HoldDuration = 0,
			MaxActivationDistance = 14, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E }, board)
		for _, dx in ipairs({ -8.4, 8.4 }) do
			part({ Name = "TiangPapan", Size = Vector3.new(0.8, 13, 0.8), CFrame = base * CFrame.new(dx, 6.5, 0.2), Color = WOOD,
				Material = Enum.Material.Wood }, boards)
		end
		part({ Name = "AtapPapan", Size = Vector3.new(18, 0.6, 3), CFrame = base * CFrame.new(0, 13, -0.6), Color = topic.color }, boards)
		bush(boards, (base * CFrame.new(0, 0, 3)).Position, 0.9)
	end
	arch(boards, CFrame.new(-50, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 26, nil, "ZONA MATERI", Color3.fromRGB(90, 120, 200))
end

---------------------------------------------------------------------
-- TAMAN PET (barat daya)
---------------------------------------------------------------------
local PET_CENTER = Vector3.new(-110, 0, 110)

local function buildPetGarden(world)
	local garden = make("Folder", { Name = "TamanPet" }, world)
	column(garden, "Lantai", PET_CENTER + Vector3.new(0, -0.42, 0), 1, 76, Color3.fromRGB(196, 228, 170), Enum.Material.SmoothPlastic)
	column(garden, "Jalur", PET_CENTER + Vector3.new(0, 0.1, 0), 0.1, 30, Color3.fromRGB(230, 220, 200), Enum.Material.Pavement,
		{ CanCollide = false })
	-- arah pintu masuk: menghadap alun-alun (timur laut)
	local entrance = math.atan2(-PET_CENTER.X, -PET_CENTER.Z)
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local diff = math.abs((angle - entrance + math.pi) % (math.pi * 2) - math.pi)
		if diff > math.rad(20) then
			local position = PET_CENTER + Vector3.new(math.sin(angle) * 37, 1.5, math.cos(angle) * 37)
			part({ Name = "Pagar", Size = Vector3.new(9.4, 3, 1.6), CFrame = CFrame.lookAt(position, PET_CENTER + Vector3.new(0, 1.5, 0)),
				Color = LEAF_COLORS[2] }, garden)
		end
	end
	local gateCf = CFrame.new(PET_CENTER + Vector3.new(math.sin(entrance) * 37, 0, math.cos(entrance) * 37))
		* CFrame.Angles(0, entrance, 0)
	arch(garden, gateCf, 18, nil, "TAMAN PET", ZONE.pets)
	tree(garden, PET_CENTER, 1.5, BLOSSOM)
	local info = part({ Name = "PapanInfoPet", Size = Vector3.new(12, 6, 0.5),
		CFrame = CFrame.lookAt(PET_CENTER + Vector3.new(math.sin(entrance) * 9, 4, math.cos(entrance) * 9),
			PET_CENTER + Vector3.new(math.sin(entrance) * 20, 4, math.cos(entrance) * 20)), Color = WHITE }, garden)
	local infoGui = surfaceGui(info, Enum.NormalId.Front, 40)
	local infoBg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 246, 250), BorderSizePixel = 0 }, infoGui)
	label(infoBg, { Size = UDim2.fromScale(0.92, 0.3), Position = UDim2.fromScale(0.04, 0.06), Text = "KOLEKSI PET",
		Font = Enum.Font.FredokaOne, TextColor3 = ZONE.pets })
	label(infoBg, { Size = UDim2.fromScale(0.92, 0.56), Position = UDim2.fromScale(0.04, 0.4),
		Text = "Kumpulkan POIN RANK dari jawaban benar untuk membuka pet. Pakai pet lewat tombol PET di layar.",
		Font = Enum.Font.GothamMedium, TextColor3 = INK })

	local count = #PetCatalog.List
	for index, pet in ipairs(PetCatalog.List) do
		local angle = entrance + math.rad(40) + (index - 1) / (count - 1) * math.rad(280)
		local position = PET_CENTER + Vector3.new(math.sin(angle) * 26, 0, math.cos(angle) * 26)
		local face = CFrame.lookAt(position, PET_CENTER)
		local rarityColor = PetCatalog.Rarities[pet.rarity] or WHITE
		column(garden, "Alas_" .. pet.id, position + Vector3.new(0, 1, 0), 2, 7, WHITE, Enum.Material.Marble)
		column(garden, "CincinAlas", position + Vector3.new(0, 2.05, 0), 0.25, 7.6, rarityColor, Enum.Material.Neon, { CanCollide = false })
		local model = PetCatalog.Build(pet.id)
		model:PivotTo(face * CFrame.new(0, (pet.flying and 4.6 or 3.05), 0))
		model.Parent = garden
		local anchor = part({ Name = "Label_" .. pet.id, Size = Vector3.new(1, 1, 1), Position = position + Vector3.new(0, 8.5, 0),
			Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }, garden)
		billboard(anchor, pet.name .. "\n" .. pet.rarity .. " • " .. (pet.xp == 0 and "Gratis" or (pet.xp .. " Poin Rank")), rarityColor,
			UDim2.fromScale(9, 2.6), Vector3.new(0, 0, 0))
	end
end

---------------------------------------------------------------------
-- PEMANDANGAN & BATAS
---------------------------------------------------------------------
local function buildScenery(world)
	local deco = make("Folder", { Name = "Pemandangan" }, world)
	local clusters = {
		{ 75, -75 }, { 95, -55 }, { 60, -105 }, { 100, -95 },
		{ -75, -75 }, { -95, -50 }, { -60, -110 }, { -105, -95 },
		{ 70, 75 }, { 95, 60 }, { 60, 105 }, { 110, 120 },
		{ -165, 60 }, { -60, 160 }, { -170, -60 }, { 175, 40 }, { 40, 185 }, { -20, -195 }, { 160, -110 }, { -150, 140 },
	}
	for i, spot in ipairs(clusters) do
		tree(deco, Vector3.new(spot[1], 0, spot[2]), 0.9 + (i % 4) * 0.15, (i % 6 == 0) and BLOSSOM or nil)
		if i % 2 == 0 then
			bush(deco, Vector3.new(spot[1] + 6, 0, spot[2] - 4), 1)
		end
	end
	for i = 0, 27 do
		local angle = i / 28 * math.pi * 2 + 0.05
		local radius = 214 + (i % 3) * 4
		local x, z = math.sin(angle) * radius, math.cos(angle) * radius
		palm(deco, Vector3.new(x, -1, z), angle + math.pi)
	end
	for i, spot in ipairs({ { 140, -150, 4 }, { -150, -150, 5 }, { 190, 80, 3 }, { -190, 20, 4 }, { 30, -200, 3 }, { -90, 190, 4 } }) do
		rock(deco, Vector3.new(spot[1], -0.5, spot[2]), spot[3] + (i % 2))
	end
	-- batas dunia (tak terlihat). Hanya sampai y = 50 agar tidak menghalangi lintasan langit (y = 90).
	local bounds = make("Folder", { Name = "BatasDunia" }, world)
	for _, data in ipairs({
		{ Vector3.new(1, 60, 560), Vector3.new(-262, 20, 0) },
		{ Vector3.new(1, 60, 560), Vector3.new(262, 20, 0) },
		{ Vector3.new(560, 60, 1), Vector3.new(0, 20, -262) },
		{ Vector3.new(560, 60, 1), Vector3.new(0, 20, 262) },
	}) do
		part({ Name = "Batas", Size = data[1], Position = data[2], Transparency = 1 }, bounds)
	end
end

---------------------------------------------------------------------
-- MEMBANGUN DUNIA
---------------------------------------------------------------------
local function buildWorld()
	local world = make("Folder", { Name = WORLD_NAME }, nil)
	world:SetAttribute("Versi", WORLD_VERSION)
	world:SetAttribute("Gerbang", COURSE.gates)
	buildTerrain()
	buildPlaza(world)
	buildPaths(world)
	buildArena(world)
	buildStage(world)
	buildCourse(world)
	buildLab(world)
	buildPetGarden(world)
	buildScenery(world)
	world.Parent = workspace
	return world
end

local function removeDefaults(world)
	-- Baseplate & SpawnLocation bawaan template Roblox dihapus agar tidak bertabrakan dengan pulau.
	for _, child in ipairs(workspace:GetChildren()) do
		if child ~= world and (child.Name == "Baseplate" or child:IsA("SpawnLocation") or child.Name == "PetunjukAwal") then
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
	"KolamData", "Podium/PapanPeringkat", "Podium/Juara1", "Podium/Juara2", "Podium/Juara3",
	"PanggungKilat/PanelJawaban1", "LintasanFirewall/Penghalang", "LintasanFirewall/Finish",
}

local function isValid(world)
	if world:GetAttribute("Versi") ~= WORLD_VERSION or world:GetAttribute("Gerbang") ~= COURSE.gates then
		warn("[NetQuest] Versi dunia berbeda, dunia dibangun ulang.")
		return false
	end
	for _, path in ipairs(REQUIRED) do
		if not findPath(world, path) then
			warn("[NetQuest] ArenaKuis tidak lengkap (" .. path .. " hilang), dunia dibangun ulang.")
			return false
		end
	end
	return true
end

function Arena.new(folder)
	local self = setmetatable({}, Arena)
	self.Folder = folder
	self.Pads, self.Signs, self.StagePanels = {}, {}, {}
	for i = 1, 4 do
		self.Pads[i] = findPath(folder, "KotakJawaban/Pad" .. i)
		self.Signs[i] = findPath(folder, "KotakJawaban/Papan" .. i .. "/Gui/Latar")
		self.StagePanels[i] = findPath(folder, "PanggungKilat/PanelJawaban" .. i .. "/Gui/Latar")
	end
	self.Pit = folder.KolamData
	self.Screens = {}
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("LayarKuis") then
			local isi = findPath(d, "Gui/Isi")
			if isi then
				table.insert(self.Screens, {
					Topic = findPath(isi, "Header/Topik"),
					Number = findPath(isi, "Header/Nomor"),
					Timer = findPath(isi, "Header/Waktu"),
					Header = isi:FindFirstChild("Header"),
					Question = isi:FindFirstChild("Pertanyaan"),
					Info = isi:FindFirstChild("Info"),
				})
			end
		end
	end
	local board = findPath(folder, "Podium/PapanPeringkat/Gui/Isi")
	self.BoardTitle = board and board:FindFirstChild("Judul", true)
	self.BoardList = board and board:FindFirstChild("Daftar", true)
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

---------------------------------------------------------------------
-- POSISI
---------------------------------------------------------------------
-- Garis Start Arena 1 (menghadap layar di utara)
function Arena:GetStartCFrame()
	return CFrame.new(math.random(-40, 40), 3.5, ARENA_Z + math.random(15, 31))
end

-- Area penonton Panggung Kuis Kilat (menghadap timur)
function Arena:GetStageCFrame()
	local position = Vector3.new(math.random(102, 128), 3.5, math.random(-22, 22))
	return CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
end

-- Lab Pecahkan Sandi (menghadap papan di barat)
function Arena:GetLabCFrame()
	local position = Vector3.new(math.random(-152, -128), 4.5, math.random(-24, 24))
	return CFrame.lookAt(position, position + Vector3.new(-1, 0, 0))
end

-- Alun-alun, menghadap papan peringkat
function Arena:GetLobbyCFrame()
	local position = Vector3.new(math.random(-10, 14), 3.5, math.random(-6, 18))
	return CFrame.lookAt(position, Vector3.new(27, 3.5, -27))
end

function Arena:GetPodiumCFrame(rank)
	local block = self.Podiums[rank]
	return block.CFrame * CFrame.new(0, block.Size.Y / 2 + 3, 0)
end

---------------------------------------------------------------------
-- LAYAR
---------------------------------------------------------------------
function Arena:SetScreen(data)
	for _, s in ipairs(self.Screens) do
		if data.topic and s.Topic then s.Topic.Text = data.topic end
		if data.number and s.Number then s.Number.Text = data.number end
		if data.timer and s.Timer then s.Timer.Text = data.timer end
		if data.question and s.Question then s.Question.Text = data.question end
		if data.info and s.Info then s.Info.Text = data.info end
		if data.accent and s.Header then
			s.Header.BackgroundColor3 = data.accent
		end
	end
end

---------------------------------------------------------------------
-- KOTAK JAWABAN (Arena 1)
---------------------------------------------------------------------
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
	for _, option in ipairs(prepared.options or {}) do
		if option.pad == pad then
			return option
		end
	end
	return nil
end

local function fillPanel(panel, option, idleColor)
	if not panel then
		return
	end
	panel.BackgroundColor3 = option and option.color or idleColor
	panel.Huruf.Text = option and option.letter or ""
	panel.Jawaban.Text = option and option.text or "—"
	panel.Jumlah.Text = ""
end

function Arena:SetQuestion(prepared)
	for i = 1, 4 do
		local option = optionForPad(prepared, i)
		self.ActivePads[i] = option ~= nil
		self.PadColors[i] = option and option.color or IDLE_PAD_COLOR
	end
	for i, pad in ipairs(self.Pads) do
		setPadSolid(pad, self.PadColors[i])
		local option = optionForPad(prepared, i)
		fillPanel(self.Signs[i], option, IDLE_PAD_COLOR)
		local letter = pad:FindFirstChild("Huruf")
		if letter then
			letter.Enabled = option ~= nil
			if option then
				letter.Teks.Text = option.letter
				letter.Teks.TextColor3 = option.color:Lerp(WHITE, 0.35)
			end
		end
	end
end

function Arena:Reveal(correctPad, counts)
	for i, pad in ipairs(self.Pads) do
		local sign = self.Signs[i]
		if self.ActivePads[i] and counts then
			sign.Jumlah.Text = tostring(counts[i] or 0) .. " pemain"
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
			pad.Color = Color3.fromRGB(40, 44, 60)
			sign.BackgroundColor3 = Color3.fromRGB(70, 72, 84)
		end
	end
end

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

---------------------------------------------------------------------
-- PANEL PANGGUNG (Arena 2)
---------------------------------------------------------------------
function Arena:SetStageQuestion(prepared)
	for i, panel in ipairs(self.StagePanels) do
		if panel then
			if prepared then
				fillPanel(panel, optionForPad(prepared, i), Color3.fromRGB(70, 72, 84))
			else
				panel.BackgroundColor3 = Config.PadColors[i]
				panel.Huruf.Text = Config.PadLetters[i]
				panel.Jawaban.Text = ""
				panel.Jumlah.Text = ""
			end
		end
	end
end

function Arena:RevealStage(correctPad, counts)
	for i, panel in ipairs(self.StagePanels) do
		if panel then
			if counts then
				panel.Jumlah.Text = tostring(counts[i] or 0) .. " pemain"
			end
			if i == correctPad then
				panel.Jawaban.Text = "✔ " .. panel.Jawaban.Text
			else
				panel.BackgroundColor3 = Color3.fromRGB(70, 72, 84)
			end
		end
	end
end

---------------------------------------------------------------------
-- PAPAN PERINGKAT & PODIUM
---------------------------------------------------------------------
-- rows = { { name = "...", score = 123 }, ... }
function Arena:SetLeaderboard(title, rows)
	if self.BoardTitle then
		self.BoardTitle.Text = title
	end
	if not self.BoardList then
		return
	end
	for i = 1, 8 do
		local row = self.BoardList:FindFirstChild("Baris" .. i)
		local data = rows[i]
		if row then
			row.Nama.Text = data and data.name or ((i == 1 and #rows == 0) and "Belum ada data" or "")
			row.Poin.Text = data and tostring(data.score) or ""
		end
	end
end

function Arena:SetHallOfFame(ranking, title)
	local rows = {}
	for i = 1, math.min(8, #ranking) do
		rows[i] = { name = ranking[i].name, score = ranking[i].score }
	end
	self:SetLeaderboard(title or "JUARA TERAKHIR", rows)
end

function Arena:CelebratePodium()
	for _, block in ipairs(self.Podiums) do
		local emitter = block:FindFirstChild("Konfeti")
		if emitter then
			emitter:Emit(100)
		end
	end
end

-- Pemain yang tercebur ke kolam dikembalikan ke Garis Start
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

function Arena:StartDecorations()
	local globe = findPath(self.Folder, "Alun/GlobeInternet")
	if globe then
		local base = globe.CFrame
		local angle = 0
		RunService.Heartbeat:Connect(function(dt)
			angle += dt * 0.6
			globe.CFrame = base * CFrame.new(0, math.sin(angle * 1.5) * 0.6, 0) * CFrame.Angles(0, angle, 0)
		end)
	end
	local barrier = self.Course and self.Course:FindFirstChild("Penghalang")
	if barrier then
		TweenService:Create(barrier, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Color = Color3.fromRGB(255, 160, 60) }):Play()
	end
end

---------------------------------------------------------------------
-- LINTASAN FIREWALL (Arena 3)
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
				gui.Jawaban.Text = option and option.text or (prepared and "DIBLOKIR" or "")
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

-- zona: "start", "area", "pintu", "jalur", "gabung", "lompat", "finish", atau nil
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
	local folder = workspace:FindFirstChild(WORLD_NAME)
	if folder and not isValid(folder) then
		folder:Destroy()
		folder = nil
		workspace.Terrain:Clear()
	end
	if not folder then
		folder = buildWorld()
	end
	removeDefaults(folder)
	setupLighting()
	local arena = Arena.new(folder)
	arena:ResetCourse()
	arena:ResetPads(true)
	arena:SetStageQuestion(nil)
	return arena
end

MapBuilder.Course = COURSE

return MapBuilder
