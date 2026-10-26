--[[
	NET QUEST - Client (tampilan di layar pemain)

	Tata letak (dirancang untuk 1280x720, otomatis mengecil di HP):
	  kiri tengah  : kartu poin + tombol Bantuan, Pet, Materi, Panduan, (Guru)
	  atas tengah  : kartu soal + pilihan jawaban (mode lari) / pengumuman lobi
	  bawah tengah : tombol jawaban besar (Kuis Kilat) / kotak ketik (Pecahkan Sandi) / penjelasan
	  tengah       : kartu pengenalan game, hasil tiap game, hasil akhir, jendela-jendela
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("QuizShared")
local Config = require(Shared:WaitForChild("Config"))
local Materi = require(Shared:WaitForChild("Materi"))
local PetCatalog = require(Shared:WaitForChild("PetCatalog"))
local Ui = require(script:WaitForChild("Ui"))
local Registration = require(script:WaitForChild("Registration"))
local Pets = require(script:WaitForChild("Pets"))
local T, F = Ui.Theme, Ui.Font

local remotesFolder = ReplicatedStorage:WaitForChild("QuizRemotes")
local remotes = {}
for _, name in ipairs({ "QuizEvent", "TeacherCommand", "ClientReady", "Answer", "EquipPet", "UseHint", "Register", "SubmitText", "GetRoster" }) do
	remotes[name] = remotesFolder:WaitForChild(name)
end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local state = {
	mode = "idle", -- idle / waiting / intermission / intro / question / explain / race / break / results
	gameMode = nil, -- id game yang sedang dimainkan (kotak/kilat/firewall/sandi)
	gameName = "",
	endsAt = 0,
	duration = 1,
	lastSecond = -1,
	options = {},
	kind = "PG",
	questionId = nil,
	clickable = false,
	locked = false,
	myPad = nil,
	hints = 0,
	hintUsed = false,
	score = 0,
	streak = 0,
	settings = nil,
	hiddenPads = {},
	savedPadColors = {},
	raceEndsAt = 0,
	raceDuration = 1,
	gate = nil,
	explainEndsAt = 0,
	explainDuration = 1,
	sandiDone = false,
	sandiBusy = false,
	adventure = nil, -- { index = n, games = { {name, color}, ... } }
	modeColor = T.Primary,
	nextName = "",
}

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Daftar pemain bawaan Roblox (pojok kanan atas) menutupi kartu soal, jadi disembunyikan selama game berlangsung.
local function showPlayerList(visible)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, visible)
	end)
end

---------------------------------------------------------------------
-- SUARA
---------------------------------------------------------------------
local sounds = {}
for name, id in pairs(Config.Sounds) do
	if id ~= "" then
		sounds[name] = Ui.new("Sound", { Name = "NetQuest_" .. name, SoundId = id, Volume = 0.5, Parent = SoundService })
	end
end
if Config.MusicId ~= "" then
	Ui.new("Sound", { Name = "NetQuest_Musik", SoundId = Config.MusicId, Volume = 0.2, Looped = true, Parent = SoundService }):Play()
end
local function play(name)
	local sound = sounds[name]
	if sound then
		sound:Play()
	end
end

---------------------------------------------------------------------
-- ROOT GUI + skala otomatis
---------------------------------------------------------------------
local gui = Ui.new("ScreenGui", {
	Name = "NetQuestGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local pixelScales = {}
local currentScale = 1
local function addPixelScale(frame)
	local scale = Ui.new("UIScale", { Name = "SkalaLayar", Scale = currentScale, Parent = frame })
	scale:SetAttribute("Dasar", currentScale)
	table.insert(pixelScales, scale)
	return scale
end
local function updatePixelScales()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	currentScale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.1)
	for _, scale in ipairs(pixelScales) do
		scale.Scale = currentScale
		scale:SetAttribute("Dasar", currentScale)
	end
end

local flash = Ui.new("Frame", { Name = "Kilat", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Good,
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })
local function flashScreen(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.7
	Ui.tween(flash, 0.7, { BackgroundTransparency = 1 })
end

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 60 then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end
	return tostring(seconds)
end

---------------------------------------------------------------------
-- MODAL (jendela di tengah layar)
---------------------------------------------------------------------
local openModals = {}
local function closeAllModals()
	for _, modal in pairs(openModals) do
		modal.Visible = false
	end
end

-- mengembalikan holder, body, area konten (di bawah judul), label judul
local function makeModal(name, titleText, width, height, accent)
	local holder, body = Ui.card({ Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height), Visible = false, ZIndex = 5, Parent = gui }, { radius = 22, clip = true })
	addPixelScale(holder)
	local header = Ui.band({ Name = "Kepala", Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = accent or T.Paper,
		BackgroundTransparency = accent and 0 or 1, ZIndex = 5, Parent = body }, 22)
	header.Penutup.BackgroundTransparency = header.BackgroundTransparency
	local title = Ui.text({ Name = "Judul", Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -90, 1, 0), Text = titleText,
		Font = F.Display, TextSize = 26, TextColor3 = accent and T.White or T.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
		Parent = header })
	if not accent then
		Ui.new("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Line, BorderSizePixel = 0,
			ZIndex = 5, Parent = header })
	end
	local close = Ui.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(40, 40),
		Text = "×", TextSize = 28, Font = F.Bold, Radius = 20, ZIndex = 6 }, function()
		holder.Visible = false
	end, "neutral")
	close.Parent = header
	local content = Ui.new("Frame", { Name = "Konten", Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 1, -64),
		BackgroundTransparency = 1, ZIndex = 5, Parent = body })
	openModals[name] = holder
	return holder, body, content, title
end

local function scrollList(parent, props)
	local frame = Ui.new("ScrollingFrame", {
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = T.InkSoft,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 5,
		Parent = parent,
	})
	Ui.list(frame, Enum.FillDirection.Vertical, props.gap or 8)
	Ui.padding(frame, 2, 10, 10, 2)
	return frame
end

---------------------------------------------------------------------
-- KIRI: KARTU POIN + TOMBOL
---------------------------------------------------------------------
local rail = Ui.new("Frame", { Name = "PanelKiri", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(204, 330), BackgroundTransparency = 1, Parent = gui })
addPixelScale(rail)
Ui.list(rail, Enum.FillDirection.Vertical, 10)

local scoreHolder, scoreCard = Ui.card({ Name = "KartuPoin", Size = UDim2.fromOffset(204, 150), Parent = rail }, { dark = true, radius = 18 })
scoreHolder.LayoutOrder = 1
Ui.padding(scoreCard, 14, 16, 14, 16)
Ui.text({ Size = UDim2.new(1, 0, 0, 16), Text = "POIN TOTAL", Font = F.Black, TextSize = 13, TextColor3 = Color3.fromRGB(160, 170, 210),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = scoreCard })
local scoreLabel = Ui.text({ Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40), Text = "0", Font = F.Display, TextSize = 36,
	TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = scoreCard })
local streakChip = Ui.chip({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -3), Size = UDim2.fromOffset(0, 20), Text = "STREAK 0",
	TextSize = 11, Visible = false, Parent = scoreCard }, T.Orange)
Ui.new("Frame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = scoreCard })
local rankLabel = Ui.text({ Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 18), Text = "Poin Rank 0", TextSize = 15,
	TextColor3 = T.White, TextXAlignment = Enum.TextXAlignment.Left, Parent = scoreCard })
local petBack, petFill = Ui.bar({ Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 8) }, T.Pink, Color3.fromRGB(56, 62, 100))
petBack.Parent = scoreCard
local petProgressText = Ui.text({ Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 0, 16), Text = "", Font = F.Medium, TextSize = 12,
	TextColor3 = Color3.fromRGB(176, 184, 220), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = scoreCard })

local function useHint() end -- diisi di bawah
local hintButton = Ui.button({ LayoutOrder = 2, Size = UDim2.fromOffset(204, 44), Text = "BANTUAN  ·  0", TextSize = 16 }, function()
	useHint()
end, "dark")
hintButton.Parent = rail

local grid = Ui.new("Frame", { LayoutOrder = 3, Size = UDim2.fromOffset(204, 100), BackgroundTransparency = 1, Parent = rail })
Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(97, 46), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = grid })
local function railButton(order, text, color)
	local button = Ui.button({ LayoutOrder = order, Text = text, TextSize = 15, BackgroundColor3 = color }, nil, "dark")
	button.Parent = grid
	return button
end
local petButton = railButton(1, "PET", Color3.fromRGB(214, 84, 150))
local materiButton = railButton(2, "MATERI", Color3.fromRGB(38, 160, 110))
local helpButton = railButton(3, "PANDUAN", Color3.fromRGB(70, 96, 200))
local teacherButton = railButton(4, "GURU", Color3.fromRGB(226, 128, 40))
teacherButton.Visible = false

local function updateRankHud()
	local xp = player:GetAttribute("PoinRank") or 0
	rankLabel.Text = "Poin Rank " .. Ui.number(xp)
	local nextPet = PetCatalog.Next(xp)
	if nextPet then
		local previous = 0
		for _, pet in ipairs(PetCatalog.List) do
			if pet.xp <= xp then
				previous = pet.xp
			end
		end
		petFill.Size = UDim2.fromScale(math.clamp((xp - previous) / math.max(1, nextPet.xp - previous), 0, 1), 1)
		petProgressText.Text = "Pet berikutnya: " .. nextPet.name
	else
		petFill.Size = UDim2.fromScale(1, 1)
		petProgressText.Text = "Semua pet sudah terbuka"
	end
end
player:GetAttributeChangedSignal("PoinRank"):Connect(updateRankHud)

---------------------------------------------------------------------
-- ATAS: PENGUMUMAN LOBI & KABAR
---------------------------------------------------------------------
local bannerHolder, banner = Ui.card({ Name = "Pengumuman", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(620, 72), Visible = false, Parent = gui }, { dark = true, radius = 36 })
addPixelScale(bannerHolder)
local bannerTitle = Ui.text({ Position = UDim2.fromOffset(28, 10), Size = UDim2.new(1, -56, 0, 28), Text = "", Font = F.Black, TextSize = 22,
	TextColor3 = T.White, Parent = banner })
local bannerSub = Ui.text({ Position = UDim2.fromOffset(28, 40), Size = UDim2.new(1, -56, 0, 20), Text = "", Font = F.Medium, TextSize = 15,
	TextColor3 = Color3.fromRGB(176, 186, 225), TextTruncate = Enum.TextTruncate.AtEnd, Parent = banner })

local feedHolder, feed = Ui.card({ Name = "Kabar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 290),
	Size = UDim2.fromOffset(460, 40), Visible = false, Parent = gui }, { dark = true, radius = 20, shadow = 3 })
addPixelScale(feedHolder)
local feedLabel = Ui.text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 16, TextColor3 = T.Gold, Parent = feed })
local feedToken = 0
local function showFeed(text)
	feedToken += 1
	local token = feedToken
	feedLabel.Text = text
	feedHolder.Visible = true
	task.delay(4, function()
		if feedToken == token then
			feedHolder.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- ATAS: KARTU SOAL
---------------------------------------------------------------------
local questionHolder, questionCard = Ui.card({ Name = "KartuSoal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(820, 176), Visible = false, Parent = gui }, { radius = 20, clip = true })
addPixelScale(questionHolder)
local headerRow = Ui.new("Frame", { Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -230, 0, 24), BackgroundTransparency = 1,
	Parent = questionCard })
Ui.list(headerRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
local modeChip = Ui.chip({ LayoutOrder = 1, Text = "", Parent = headerRow }, T.Primary)
local topicLabel = Ui.text({ LayoutOrder = 2, Size = UDim2.fromOffset(300, 24), Text = "", Font = F.Bold, TextSize = 14,
	TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = headerRow })
local counterLabel = Ui.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 16), Size = UDim2.fromOffset(160, 24), Text = "",
	TextSize = 14, TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Right, Parent = questionCard })
local bossChip = Ui.chip({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -96, 0, 16), Text = "SOAL BOS · POIN x2",
	Visible = false, Parent = questionCard }, T.Bad)
local questionText = Ui.text({ Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -116, 0, 86), Text = "", Font = F.Black,
	TextSize = 28, Scaled = true, MaxTextSize = 28, TextColor3 = T.Ink, RichText = true, Parent = questionCard })

local function richEscape(text)
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- Teks soal. Pada teka-teki sandi, kata rahasia (baris huruf kapital) ditonjolkan dengan huruf berjarak.
local function setQuestionText(text)
	local lines = string.split(text, "\n")
	for i, line in ipairs(lines) do
		if #lines > 1 and string.match(line, "^[A-Z]+$") then
			lines[i] = '<font color="#5C68F5" face="RobotoMono">' .. table.concat(string.split(line, ""), " ") .. "</font>"
		else
			lines[i] = richEscape(line)
		end
	end
	questionText.Text = table.concat(lines, "\n")
end
local choiceHint = Ui.text({ Position = UDim2.fromOffset(20, 134), Size = UDim2.new(1, -116, 0, 20), Text = "", Font = F.Bold, TextSize = 15,
	TextColor3 = T.InkSoft, Parent = questionCard })
local timerBack, timerFill = Ui.bar({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -14), Size = UDim2.new(1, -116, 0, 6) },
	T.Good, T.Paper2)
timerBack.Parent = questionCard
local timerCircle = Ui.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 4), Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = T.Paper2, BorderSizePixel = 0, Parent = questionCard })
Ui.corner(timerCircle, 32)
local timerStroke = Ui.stroke(timerCircle, T.Good, 4)
local timerNumber = Ui.text({ Size = UDim2.fromScale(1, 1), Text = "", Font = F.Display, TextSize = 26, TextColor3 = T.Ink, Parent = timerCircle })

---------------------------------------------------------------------
-- PILIHAN JAWABAN (atas untuk mode lari, bawah & bisa ditekan untuk Kuis Kilat)
---------------------------------------------------------------------
local optionsHolder = Ui.new("Frame", { Name = "PilihanJawaban", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 200),
	Size = UDim2.fromOffset(820, 66), BackgroundTransparency = 1, Visible = false, Parent = gui })
addPixelScale(optionsHolder)
Ui.list(optionsHolder, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

local cards = {}
local function onCardClicked(index) end -- diisi di bawah
for i = 1, 4 do
	local button = Ui.new("TextButton", { Name = "Pilihan" .. i, LayoutOrder = i, Size = UDim2.new(0.25, -8, 1, 0), Text = "",
		AutoButtonColor = false, BackgroundTransparency = 1, Parent = optionsHolder })
	local shade = Ui.new("Frame", { Name = "Bawah", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = Ui.darker(Config.PadColors[i]), BorderSizePixel = 0, Parent = button })
	Ui.corner(shade, 14)
	local face = Ui.new("Frame", { Name = "Muka", Size = UDim2.new(1, 0, 1, -5), BackgroundColor3 = Config.PadColors[i], BorderSizePixel = 0,
		Parent = button })
	Ui.corner(face, 14)
	local ring = Ui.stroke(face, T.White, 0)
	local badge = Ui.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = T.White, BorderSizePixel = 0, Parent = face })
	Ui.corner(badge, 17)
	local letter = Ui.text({ Size = UDim2.fromScale(1, 1), Text = Config.PadLetters[i], Font = F.Display, TextSize = 20,
		TextColor3 = Config.PadColors[i], Parent = badge })
	local text = Ui.text({ Position = UDim2.fromOffset(52, 4), Size = UDim2.new(1, -60, 1, -8), Text = "", Font = F.Black, TextSize = 16,
		Scaled = true, MaxTextSize = 16, TextColor3 = T.White, TextXAlignment = Enum.TextXAlignment.Left, Parent = face })
	local count = Ui.chip({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, -12), Text = "", Visible = false, TextSize = 12,
		Parent = button }, T.Ink)
	local you = Ui.chip({ Position = UDim2.fromOffset(6, -12), Text = "POSISIMU", Visible = false, TextSize = 12, Parent = button }, T.Ink)
	button.Activated:Connect(function()
		onCardClicked(i)
	end)
	cards[i] = { button = button, face = face, shade = shade, ring = ring, badge = badge, letter = letter, text = text, count = count, you = you }
end

local function placeOptions(bottom)
	-- tombol Kuis Kilat lebih besar, jadi teksnya boleh lebih besar; ukuran sama untuk keempat tombol
	for _, card in ipairs(cards) do
		card.text.UITextSizeConstraint.MaxTextSize = bottom and 22 or 16
	end
	if bottom then
		optionsHolder.AnchorPoint = Vector2.new(0.5, 1)
		optionsHolder.Position = UDim2.new(0.5, 0, 1, -18)
		optionsHolder.Size = UDim2.fromOffset(940, 118)
	else
		optionsHolder.AnchorPoint = Vector2.new(0.5, 0)
		optionsHolder.Position = UDim2.new(0.5, 0, 0, 12 + (176 + 14) * currentScale)
		optionsHolder.Size = UDim2.fromOffset(820, 66)
	end
end

---------------------------------------------------------------------
-- BAWAH: KOTAK KETIK (Pecahkan Sandi)
---------------------------------------------------------------------
local sandiHolder, sandiCard = Ui.card({ Name = "KotakSandi", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(660, 168), Visible = false, Parent = gui }, { radius = 20 })
addPixelScale(sandiHolder)
Ui.padding(sandiCard, 14, 18, 14, 18)
local alphabet = Ui.text({ Size = UDim2.new(1, 0, 0, 22), Text = "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z", Font = F.Mono,
	TextSize = 17, TextColor3 = T.Primary, Parent = sandiCard })
local sandiBox = Ui.new("TextBox", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -150, 0, 52), BackgroundColor3 = T.Paper2,
	TextColor3 = T.Ink, PlaceholderText = "Ketik jawabanmu di sini...", PlaceholderColor3 = T.InkSoft, Font = F.Black, TextSize = 24,
	Text = "", ClearTextOnFocus = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, Parent = sandiCard })
Ui.corner(sandiBox, 12)
Ui.stroke(sandiBox, T.Line, 2)
Ui.padding(sandiBox, 0, 14, 0, 14)
local sandiSend
local sandiInfo = Ui.text({ Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 20), Text = "", Font = F.Bold, TextSize = 15,
	TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, Parent = sandiCard })
local sandiHint = Ui.text({ Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 22), Text = "", Font = F.Mono, TextSize = 18,
	TextColor3 = Color3.fromRGB(150, 100, 240), TextXAlignment = Enum.TextXAlignment.Left, Parent = sandiCard })

local function setSandiEnabled(enabled)
	sandiBox.TextEditable = enabled
	sandiSend.BackgroundColor3 = enabled and T.Good or T.Line
end

local function submitSandi()
	if state.mode ~= "question" or state.kind ~= "ISIAN" or state.sandiDone or state.sandiBusy then
		return
	end
	local text = sandiBox.Text
	if string.gsub(text, "%s", "") == "" then
		sandiInfo.Text = "Ketik jawabanmu dulu ya."
		return
	end
	state.sandiBusy = true
	local ok, result = pcall(function()
		return remotes.SubmitText:InvokeServer(state.questionId, text)
	end)
	state.sandiBusy = false
	if not ok or type(result) ~= "table" then
		sandiInfo.Text = "Koneksi bermasalah, coba lagi."
		return
	end
	if not result.ok then
		sandiInfo.Text = result.message or ""
		return
	end
	if result.correct then
		state.sandiDone = true
		setSandiEnabled(false)
		sandiInfo.TextColor3 = T.Good
		sandiInfo.Text = "Benar! Tunggu teman-temanmu selesai."
	elseif (result.attemptsLeft or 0) <= 0 then
		state.sandiDone = true
		setSandiEnabled(false)
		sandiInfo.TextColor3 = T.Bad
		sandiInfo.Text = "Kesempatan habis. Jawabannya akan ditampilkan sebentar lagi."
		play("Wrong")
	else
		sandiInfo.TextColor3 = T.Bad
		sandiInfo.Text = "Belum tepat. Sisa " .. result.attemptsLeft .. " kesempatan."
		play("Wrong")
		Ui.pop(sandiHolder, 1.04)
		sandiBox.Text = ""
		sandiBox:CaptureFocus()
	end
end
sandiSend = Ui.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 30), Size = UDim2.fromOffset(138, 52), Text = "KIRIM",
	TextSize = 20 }, submitSandi, "success")
sandiSend.Parent = sandiCard
sandiBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submitSandi()
	end
end)

---------------------------------------------------------------------
-- BAWAH: PENJELASAN
---------------------------------------------------------------------
local explainHolder, explainCard = Ui.card({ Name = "Penjelasan", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(780, 150), Visible = false, Parent = gui }, { radius = 20, clip = true })
addPixelScale(explainHolder)
local explainBand = Ui.band({ Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.Good, Parent = explainCard }, 20)
local explainTitle = Ui.text({ Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 1, 0), Text = "", Font = F.Black, TextSize = 19,
	Scaled = true, MaxTextSize = 19, TextColor3 = T.White, TextXAlignment = Enum.TextXAlignment.Left, Parent = explainBand })
local explainText = Ui.text({ Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 1, -68), Text = "", Font = F.Medium, TextSize = 19,
	Scaled = true, MaxTextSize = 19, TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Parent = explainCard })
local explainBack, explainFill = Ui.bar({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -12), Size = UDim2.new(1, -40, 0, 5) },
	T.Primary, T.Paper2)
explainBack.Parent = explainCard

local function showExplain(title, good, text, endsAt, bottomOffset)
	explainBand.BackgroundColor3 = good and T.Good or T.Bad
	explainTitle.Text = title
	explainText.Text = text or ""
	explainHolder.Position = UDim2.new(0.5, 0, 1, -(bottomOffset or 18) * currentScale)
	state.explainEndsAt = endsAt
	state.explainDuration = math.max(1, endsAt - serverNow())
	explainHolder.Visible = true
	Ui.pop(explainHolder, 0.9)
end

---------------------------------------------------------------------
-- TENGAH: TOAST
---------------------------------------------------------------------
local toast = Ui.new("Frame", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.52, 0),
	Size = UDim2.fromOffset(700, 130), BackgroundTransparency = 1, Visible = false, ZIndex = 8, Parent = gui })
addPixelScale(toast)
local toastTitle = Ui.text({ Size = UDim2.new(1, 0, 0, 74), Text = "", Font = F.Display, TextSize = 64, TextColor3 = T.White,
	TextStrokeTransparency = 0, TextStrokeColor3 = T.Ink, ZIndex = 8, Parent = toast })
local toastSubHolder, toastSubCard = Ui.card({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(520, 40),
	ZIndex = 8, Parent = toast }, { dark = true, radius = 20, shadow = 3 })
local toastSub = Ui.text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 17, TextColor3 = T.White, ZIndex = 8, Parent = toastSubCard })
local toastToken = 0
local function showToast(title, sub, color, duration)
	toastToken += 1
	local token = toastToken
	toastTitle.Text = title
	toastTitle.TextColor3 = color or T.White
	toastSub.Text = sub or ""
	toastSubHolder.Visible = sub ~= nil and sub ~= ""
	toast.Visible = true
	Ui.pop(toast, 0.5)
	task.delay(duration or 2.4, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end
local function hideToast()
	toastToken += 1
	toast.Visible = false
end

---------------------------------------------------------------------
-- TENGAH: KARTU PENGENALAN GAME
---------------------------------------------------------------------
local introHolder, introCard = Ui.card({ Name = "KartuGame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(660, 320), Visible = false, Parent = gui }, { radius = 24, clip = true })
addPixelScale(introHolder)
local introBand = Ui.band({ Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = T.Primary, Parent = introCard }, 24)
local introStep = Ui.text({ Position = UDim2.fromOffset(28, 18), Size = UDim2.new(1, -150, 0, 20), Text = "", Font = F.Black, TextSize = 15,
	TextColor3 = T.White, TextTransparency = 0.15, TextXAlignment = Enum.TextXAlignment.Left, Parent = introBand })
local introName = Ui.text({ Position = UDim2.fromOffset(28, 40), Size = UDim2.new(1, -150, 0, 60), Text = "", Font = F.Display, TextSize = 46,
	Scaled = true, MaxTextSize = 46, TextColor3 = T.White, TextXAlignment = Enum.TextXAlignment.Left, Parent = introBand })
local countCircle = Ui.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.5, 0), Size = UDim2.fromOffset(84, 84),
	BackgroundColor3 = T.White, BorderSizePixel = 0, Parent = introBand })
Ui.corner(countCircle, 42)
local countdownLabel = Ui.text({ Size = UDim2.fromScale(1, 1), Text = "", Font = F.Display, TextSize = 44, TextColor3 = T.Ink, Parent = countCircle })
local introDesc = Ui.text({ Position = UDim2.fromOffset(28, 136), Size = UDim2.new(1, -56, 0, 66), Text = "", Font = F.Bold, TextSize = 21,
	Scaled = true, MaxTextSize = 21, TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Parent = introCard })
local introInfo = Ui.text({ Position = UDim2.fromOffset(28, 208), Size = UDim2.new(1, -56, 0, 20), Text = "", Font = F.Bold, TextSize = 15,
	TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, Parent = introCard })
local stepRow = Ui.new("Frame", { Position = UDim2.fromOffset(28, 246), Size = UDim2.new(1, -56, 0, 48), BackgroundTransparency = 1,
	Parent = introCard })
Ui.list(stepRow, Enum.FillDirection.Horizontal, 8)

local function fillSteps(container, games, current, widthEach)
	Ui.clear(container)
	for i, entry in ipairs(games) do
		local done = i < current
		local active = i == current
		local pill = Ui.new("Frame", { LayoutOrder = i, Size = UDim2.new(0, widthEach, 1, 0), BorderSizePixel = 0,
			BackgroundColor3 = active and entry.color or T.Paper2, Parent = container })
		Ui.corner(pill, 12)
		if not active then
			Ui.stroke(pill, T.Line, 1)
		end
		local dot = Ui.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = active and T.White or (done and T.Good or entry.color), BorderSizePixel = 0, Parent = pill })
		Ui.corner(dot, 14)
		Ui.text({ Size = UDim2.fromScale(1, 1), Text = done and "✓" or tostring(i), Font = F.Display, TextSize = 15,
			TextColor3 = active and entry.color or T.White, Parent = dot })
		Ui.text({ Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -48, 1, 0), Text = entry.name, Font = F.Black, TextSize = 13,
			Scaled = true, MaxTextSize = 13, TextColor3 = active and T.White or T.Ink, TextXAlignment = Enum.TextXAlignment.Left, Parent = pill })
	end
end

---------------------------------------------------------------------
-- TENGAH: HASIL SATU GAME (jeda Petualangan)
---------------------------------------------------------------------
local breakHolder, breakCard = Ui.card({ Name = "HasilGame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(800, 470), Visible = false, Parent = gui }, { radius = 24, clip = true })
addPixelScale(breakHolder)
local breakBand = Ui.band({ Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = T.Primary, Parent = breakCard }, 24)
local breakStep = Ui.text({ Position = UDim2.fromOffset(28, 14), Size = UDim2.new(1, -56, 0, 18), Text = "", Font = F.Black, TextSize = 14,
	TextColor3 = T.White, TextTransparency = 0.15, TextXAlignment = Enum.TextXAlignment.Left, Parent = breakBand })
local breakTitle = Ui.text({ Position = UDim2.fromOffset(28, 34), Size = UDim2.new(1, -56, 0, 38), Text = "", Font = F.Display, TextSize = 32,
	TextColor3 = T.White, TextXAlignment = Enum.TextXAlignment.Left, Parent = breakBand })
local function columnTitle(x, text)
	Ui.text({ Position = UDim2.new(x, 28, 0, 100), Size = UDim2.new(0.5, -42, 0, 20), Text = text, Font = F.Black, TextSize = 14,
		TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, Parent = breakCard })
end
columnTitle(0, "POIN DI GAME INI")
columnTitle(0.5, "POIN TOTAL SEMENTARA")
local breakLeft = Ui.new("Frame", { Position = UDim2.new(0, 28, 0, 126), Size = UDim2.new(0.5, -42, 0, 230), BackgroundTransparency = 1,
	Parent = breakCard })
Ui.list(breakLeft, Enum.FillDirection.Vertical, 6)
local breakRight = Ui.new("Frame", { Position = UDim2.new(0.5, 14, 0, 126), Size = UDim2.new(0.5, -42, 0, 230), BackgroundTransparency = 1,
	Parent = breakCard })
Ui.list(breakRight, Enum.FillDirection.Vertical, 6)
local breakMine = Ui.text({ Position = UDim2.new(0, 28, 1, -92), Size = UDim2.new(1, -56, 0, 24), Text = "", Font = F.Black, TextSize = 18,
	TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, Parent = breakCard })
local breakNext = Ui.text({ Position = UDim2.new(0, 28, 1, -60), Size = UDim2.new(1, -56, 0, 36), Text = "", Font = F.Bold, TextSize = 16,
	TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, Parent = breakCard })

local medalColors = { Color3.fromRGB(255, 194, 48), Color3.fromRGB(176, 186, 206), Color3.fromRGB(214, 140, 80) }
local function rankRow(parent, order, row, highlight, height)
	local frame = Ui.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height or 38), BorderSizePixel = 0,
		BackgroundColor3 = highlight and Color3.fromRGB(232, 236, 255) or T.Paper2, ZIndex = 5, Parent = parent })
	Ui.corner(frame, 10)
	if highlight then
		Ui.stroke(frame, T.Primary, 2)
	end
	local badge = Ui.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = medalColors[order] or T.Line, BorderSizePixel = 0, ZIndex = 5, Parent = frame })
	Ui.corner(badge, 13)
	Ui.text({ Size = UDim2.fromScale(1, 1), Text = tostring(order), Font = F.Display, TextSize = 14, TextColor3 = order <= 3 and T.White or T.Ink,
		ZIndex = 5, Parent = badge })
	-- nama dari server berformat "01. Nama"; nomor absen dipisah agar tidak tertukar dengan nomor peringkat
	local absen, plainName = string.match(row.name, "^(%d+)%.%s+(.+)$")
	local nameLabel = Ui.text({ Position = UDim2.fromOffset(44, 0), Size = UDim2.new(0.68, -44, 1, 0), Text = plainName or row.name, Font = F.Bold,
		TextSize = 16, TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
		Parent = frame })
	if absen then
		nameLabel.Size = UDim2.new(0.68, -116, 1, 0)
		Ui.text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.68, 0, 0.5, 0), Size = UDim2.fromOffset(68, 18), Text = "absen " .. absen,
			Font = F.Medium, TextSize = 12, TextWrapped = false, TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5,
			Parent = frame })
	end
	Ui.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.32, 0, 1, 0), Text = Ui.number(row.score),
		Font = F.Display, TextSize = 17, TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Parent = frame })
	return frame
end

---------------------------------------------------------------------
-- JENDELA: ZONA MATERI
---------------------------------------------------------------------
local materiHolder, _, materiContent = makeModal("ModalMateri", "Zona Materi", 900, 560)
local tabList = scrollList(materiContent, { Position = UDim2.fromOffset(20, 16), Size = UDim2.new(0, 250, 1, -32), gap = 8 })
local materiBody = scrollList(materiContent, { Position = UDim2.fromOffset(290, 16), Size = UDim2.new(1, -310, 1, -32), gap = 12 })

local function showMateri(topicId)
	Ui.clear(materiBody)
	local topic = Config.GetTopic(topicId)
	Ui.chip({ LayoutOrder = 0, Text = string.upper(topic.name), TextSize = 14, ZIndex = 5, Parent = materiBody }, topic.color, T.Ink)
	for i, point in ipairs(Materi[topicId] or {}) do
		local row = Ui.new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = T.Paper2, BorderSizePixel = 0, ZIndex = 5, Parent = materiBody })
		Ui.corner(row, 12)
		Ui.padding(row, 12, 14, 12, 14)
		Ui.text({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = point, Font = F.Medium, TextSize = 18,
			TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = row })
	end
	materiBody.CanvasPosition = Vector2.zero
end

local function focusMode()
	return state.mode == "question" or state.mode == "race"
end

local function openMateri(topicId)
	if focusMode() then
		showToast("Fokus ke soal", "Materi bisa dibaca lagi setelah soal selesai.", T.Gold, 2)
		return
	end
	closeAllModals()
	materiHolder.Visible = true
	Ui.pop(materiHolder, 0.9)
	showMateri(topicId or "konsep")
end

for order, topic in ipairs(Config.Topics) do
	if topic.id ~= "campuran" then
		local tab = Ui.button({ LayoutOrder = order, Size = UDim2.new(1, -4, 0, 50), Text = topic.name, TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = topic.color, TextColor3 = T.Ink, ZIndex = 5 }, function()
			showMateri(topic.id)
		end)
		Ui.padding(tab, 0, 12, 0, 14)
		tab.Parent = tabList
	end
end
materiButton.Activated:Connect(function()
	openMateri("konsep")
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "BacaMateri" and prompt.Parent then
		openMateri(prompt.Parent:GetAttribute("TopicId"))
	end
end)

---------------------------------------------------------------------
-- JENDELA: PANDUAN
---------------------------------------------------------------------
local helpHolder, _, helpContent, helpTitle = makeModal("ModalPanduan", "Cara Main NET QUEST", 860, 560)
local helpList = scrollList(helpContent, { Position = UDim2.fromOffset(24, 16), Size = UDim2.new(1, -48, 1, -96), gap = 10 })
local helpSteps = {
	{ "1", "Lari & Pilih", "Lari dan berdiri di kotak jawaban. Kotak yang salah jatuh ke kolam!", Config.GetMode("kotak").color },
	{ "2", "Kuis Kilat", "Tekan tombol jawaban di layar secepat mungkin. Jawaban tidak bisa diganti.", Config.GetMode("kilat").color },
	{ "3", "Lintasan Firewall", "Balapan di langit. Masuk ke pintu jawaban yang benar, pintu salah membuatmu jatuh.",
		Config.GetMode("firewall").color },
	{ "4", "Pecahkan Sandi", "Ketik jawabanmu dan pecahkan kode rahasia Caesar Cipher.", Config.GetMode("sandi").color },
}
for i, step in ipairs(helpSteps) do
	local row = Ui.new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -6, 0, 64), BackgroundColor3 = T.Paper2, BorderSizePixel = 0, ZIndex = 5,
		Parent = helpList })
	Ui.corner(row, 14)
	local dot = Ui.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = step[4], BorderSizePixel = 0, ZIndex = 5, Parent = row })
	Ui.corner(dot, 20)
	Ui.text({ Size = UDim2.fromScale(1, 1), Text = step[1], Font = F.Display, TextSize = 20, TextColor3 = T.White, ZIndex = 5, Parent = dot })
	Ui.text({ Position = UDim2.fromOffset(68, 10), Size = UDim2.new(1, -80, 0, 22), Text = step[2], Font = F.Black, TextSize = 18, TextColor3 = T.Ink,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = row })
	Ui.text({ Position = UDim2.fromOffset(68, 32), Size = UDim2.new(1, -80, 0, 22), Text = step[3], Font = F.Medium, TextSize = 15,
		TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, Scaled = true, MaxTextSize = 15, ZIndex = 5, Parent = row })
end
local tips = {
	"Keempat game dimainkan berurutan dan poinnya dijumlahkan menjadi POIN TOTAL. Ikut semua game untuk bonus tamat.",
	"Jawab lebih cepat untuk bonus poin. Benar berturut-turut menambah bonus streak.",
	"Benar 3x berturut-turut memberi BANTUAN: 50:50 atau petunjuk huruf.",
	"Baca penjelasan setelah setiap soal dan papan Zona Materi di jalan menuju Lab Sandi.",
	"Semua poin menjadi POIN RANK untuk naik gelar dan membuka pet di Taman Pet.",
}
for i, tip in ipairs(tips) do
	Ui.text({ LayoutOrder = 10 + i, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "•  " .. tip, Font = F.Medium,
		TextSize = 16, TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = helpList })
end
local readyButton = Ui.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(280, 52),
	Text = "SIAP BELAJAR", TextSize = 20, ZIndex = 6 }, function()
	helpHolder.Visible = false
end, "success")
readyButton.Parent = helpContent
local function openHelp(greeting)
	helpTitle.Text = greeting or "Cara Main NET QUEST"
	closeAllModals()
	helpHolder.Visible = true
	Ui.pop(helpHolder, 0.9)
end
helpButton.Activated:Connect(function()
	openHelp()
end)

---------------------------------------------------------------------
-- MODUL PET & PENDAFTARAN
---------------------------------------------------------------------
local ctx = {
	gui = gui,
	Ui = Ui,
	remotes = remotes,
	makeModal = makeModal,
	closeAllModals = closeAllModals,
	showToast = showToast,
	play = play,
	addPixelScale = addPixelScale,
}
Pets.Init(ctx)
petButton.Activated:Connect(function()
	if focusMode() then
		showToast("Fokus ke soal", "Koleksi pet bisa dilihat setelah soal selesai.", T.Gold, 2)
		return
	end
	Pets.OpenMenu()
end)
ctx.onRegistered = function(message, asTeacher)
	play("Correct")
	if asTeacher then
		showToast("Halo, Guru!", message, T.White, 3)
	else
		openHelp(message)
	end
end
Registration.Init(ctx)

---------------------------------------------------------------------
-- JENDELA: HASIL AKHIR
---------------------------------------------------------------------
local resultsHolder, _, resultsContent, resultsTitle = makeModal("ModalHasil", "Hasil Akhir", 920, 580, Color3.fromRGB(255, 166, 40))
Ui.text({ Position = UDim2.fromOffset(24, 14), Size = UDim2.new(0.44, -24, 0, 20), Text = "PERINGKAT", Font = F.Black, TextSize = 14,
	TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = resultsContent })
local rankingList = scrollList(resultsContent, { Position = UDim2.fromOffset(24, 40), Size = UDim2.new(0.44, -24, 1, -56), gap = 6 })
Ui.text({ Position = UDim2.new(0.44, 20, 0, 14), Size = UDim2.new(0.56, -44, 0, 20), Text = "RAPOR KAMU", Font = F.Black, TextSize = 14,
	TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = resultsContent })
local personal = scrollList(resultsContent, { Position = UDim2.new(0.44, 20, 0, 40), Size = UDim2.new(0.56, -44, 1, -56), gap = 10 })

local function personalLine(order, text, color, size, font)
	return Ui.text({ LayoutOrder = order, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, Font = font or F.Bold,
		TextSize = size or 16, TextColor3 = color or T.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = personal })
end

local function showRanking(ranking)
	Ui.clear(rankingList)
	for i, row in ipairs(ranking) do
		rankRow(rankingList, i, row, row.userId == player.UserId, 42)
	end
	if #ranking == 0 then
		Ui.text({ Size = UDim2.new(1, 0, 0, 40), Text = "Belum ada peserta.", TextColor3 = T.InkSoft, ZIndex = 5, Parent = rankingList })
	end
end

local function statTile(parent, order, labelText, value, color)
	local tile = Ui.new("Frame", { LayoutOrder = order, Size = UDim2.new(0.333, -7, 1, 0), BackgroundColor3 = T.Paper2, BorderSizePixel = 0,
		ZIndex = 5, Parent = parent })
	Ui.corner(tile, 12)
	Ui.text({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 16), Text = labelText, Font = F.Black, TextSize = 12,
		TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = tile })
	Ui.text({ Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 30), Text = value, Font = F.Display, TextSize = 26,
		TextColor3 = color or T.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = tile })
end

local function showSummary(s)
	Ui.clear(personal)
	local accuracy = s.answered > 0 and math.floor(s.correct / s.answered * 100 + 0.5) or 0
	local tiles = Ui.new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -6, 0, 66), BackgroundTransparency = 1, ZIndex = 5, Parent = personal })
	Ui.list(tiles, Enum.FillDirection.Horizontal, 10)
	statTile(tiles, 1, "PERINGKAT", "#" .. s.position .. "/" .. s.players, T.Primary)
	statTile(tiles, 2, "POIN TOTAL", Ui.number(s.score), Color3.fromRGB(220, 150, 20))
	statTile(tiles, 3, "NILAI", tostring(accuracy), accuracy >= 70 and T.Good or (accuracy >= 50 and T.Orange or T.Bad))

	if s.games and #s.games > 1 then
		personalLine(2, "POIN TIAP GAME", T.InkSoft, 13, F.Black)
		local best = 1
		for _, g in ipairs(s.games) do
			best = math.max(best, g.score)
		end
		for i, g in ipairs(s.games) do
			local row = Ui.new("Frame", { LayoutOrder = 2 + i, Size = UDim2.new(1, -6, 0, 30), BackgroundTransparency = 1, ZIndex = 5,
				Parent = personal })
			Ui.text({ Size = UDim2.new(0.36, 0, 1, 0), Text = g.name, Font = F.Bold, TextSize = 15, TextColor3 = T.Ink,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = row })
			local back, fill = Ui.bar({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.37, 0, 0.5, 0), Size = UDim2.new(0.38, 0, 0, 12),
				ZIndex = 5 }, g.color, T.Paper2)
			back.Parent = row
			fill.Size = UDim2.fromScale(math.clamp(g.score / best, 0.02, 1), 1)
			Ui.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0),
				Text = Ui.number(g.score) .. "  (" .. g.correct .. "/" .. g.answered .. ")", Font = F.Bold, TextSize = 13, TextColor3 = T.InkSoft,
				TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Parent = row })
		end
	end
	if s.completedAll then
		personalLine(10, "+" .. Ui.number(s.completionBonus) .. " bonus tamat karena kamu menyelesaikan keempat game", T.Good, 14)
	end

	-- kartu umpan balik belajar
	local feedback = Ui.new("Frame", { LayoutOrder = 11, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Paper2, BorderSizePixel = 0, ZIndex = 5, Parent = personal })
	Ui.corner(feedback, 14)
	Ui.padding(feedback, 12, 14, 12, 14)
	Ui.list(feedback, Enum.FillDirection.Vertical, 6)
	local message
	if accuracy >= 90 then
		message = "Luar biasa! Kamu sudah menguasai materi ini."
	elseif accuracy >= 70 then
		message = "Bagus sekali! Sedikit lagi jadi master."
	elseif accuracy >= 50 then
		message = "Lumayan! Baca lagi materinya, pasti bisa lebih baik."
	else
		message = "Jangan menyerah! Baca Zona Materi lalu coba lagi."
	end
	local function feedbackLine(order, text, color, size, fontFace)
		Ui.text({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, Font = fontFace or F.Bold,
			TextSize = size or 14, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = feedback })
	end
	feedbackLine(1, message, T.Ink, 16, F.Black)
	if s.strongTopic then
		feedbackLine(2, "Paling kuat: " .. s.strongTopic .. " (" .. s.strongText .. ")", Color3.fromRGB(24, 140, 84))
	end
	if s.weakTopic then
		feedbackLine(3, "Perlu dipelajari lagi: " .. s.weakTopic .. " (" .. s.weakText .. ")", Color3.fromRGB(200, 56, 72))
		local study = Ui.button({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 40), Text = "PELAJARI MATERI INI", TextSize = 15, ZIndex = 6 },
			function()
				openMateri(s.weakId)
			end, "primary")
		study.Parent = feedback
	end

	-- kartu kemajuan: gelar & pet
	local progress = Ui.new("Frame", { LayoutOrder = 12, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Paper2, BorderSizePixel = 0, ZIndex = 5, Parent = personal })
	Ui.corner(progress, 14)
	Ui.padding(progress, 12, 14, 12, 14)
	Ui.list(progress, Enum.FillDirection.Vertical, 6)
	local titleRow = Ui.new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, ZIndex = 5, Parent = progress })
	Ui.list(titleRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	Ui.text({ LayoutOrder = 1, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Text = "Gelar", Font = F.Black, TextSize = 15,
		TextColor3 = T.InkSoft, TextWrapped = false, ZIndex = 5, Parent = titleRow })
	Ui.chip({ LayoutOrder = 2, Text = s.title, TextSize = 13, ZIndex = 5, Parent = titleRow }, s.titleColor:Lerp(T.Ink, 0.25))
	if s.rankUp then
		Ui.chip({ LayoutOrder = 3, Text = "NAIK GELAR", TextSize = 12, ZIndex = 5, Parent = titleRow }, T.Gold, T.Ink)
	end
	local nextParts = { "Poin Rank " .. Ui.number(s.xp) }
	if s.nextTitle then
		table.insert(nextParts, Ui.number(s.nextXp - s.xp) .. " lagi menuju " .. s.nextTitle)
	end
	Ui.text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = table.concat(nextParts, "  ·  "),
		Font = F.Medium, TextSize = 14, TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = progress })
	local petText
	if s.newPets and #s.newPets > 0 then
		local names = {}
		for _, pet in ipairs(s.newPets) do
			table.insert(names, pet.name)
		end
		petText = "Pet baru terbuka: " .. table.concat(names, ", ")
	elseif s.nextPetName then
		petText = "Pet berikutnya: " .. s.nextPetName .. " (" .. Ui.number(s.nextPetXp - s.xp) .. " Poin Rank lagi)"
	end
	if petText then
		Ui.text({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = petText, Font = F.Bold, TextSize = 14,
			TextColor3 = Color3.fromRGB(200, 60, 130), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = progress })
	end
	if s.rankUp then
		task.delay(1, function()
			play("Fanfare")
		end)
	end
	if s.newPets and #s.newPets > 0 then
		task.delay(3, function()
			Pets.ShowUnlocked(s.newPets)
		end)
	end
end

---------------------------------------------------------------------
-- PANEL GURU
---------------------------------------------------------------------
local rosterHolder, _, rosterContent = makeModal("ModalSiswa", "Daftar Siswa & Nilai", 940, 580)
local rosterColumns = { { "KELAS", 0.09 }, { "ABSEN", 0.08 }, { "NAMA", 0.35 }, { "BENAR/SOAL", 0.15 }, { "NILAI", 0.1 }, { "POIN RANK", 0.23 } }
local function rosterRow(parent, order, values, header)
	local row = Ui.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -6, 0, 36), BackgroundColor3 = header and T.Ink or (order % 2 == 0
		and T.Paper2 or T.Paper), BorderSizePixel = 0, ZIndex = 5, Parent = parent })
	Ui.corner(row, 8)
	local x = 0
	for i, column in ipairs(rosterColumns) do
		Ui.text({ Position = UDim2.new(x, 10, 0, 0), Size = UDim2.new(column[2], -12, 1, 0), Text = tostring(values[i]),
			Font = header and F.Black or F.Bold, TextSize = header and 12 or 15, TextColor3 = header and T.White or T.Ink,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = row })
		x += column[2]
	end
	return row
end
local rosterHeaderHolder = Ui.new("Frame", { Position = UDim2.fromOffset(24, 14), Size = UDim2.new(1, -48, 0, 36), BackgroundTransparency = 1,
	ZIndex = 5, Parent = rosterContent })
local headerValues = {}
for i, column in ipairs(rosterColumns) do
	headerValues[i] = column[1]
end
rosterRow(rosterHeaderHolder, 0, headerValues, true).Size = UDim2.fromScale(1, 1)
local rosterList = scrollList(rosterContent, { Position = UDim2.fromOffset(24, 56), Size = UDim2.new(1, -48, 1, -72), gap = 4 })

local function loadRoster()
	Ui.clear(rosterList)
	local ok, list = pcall(function()
		return remotes.GetRoster:InvokeServer()
	end)
	if not ok or type(list) ~= "table" then
		Ui.text({ Size = UDim2.new(1, 0, 0, 30), Text = "Gagal memuat daftar siswa.", TextColor3 = T.Bad, ZIndex = 5, Parent = rosterList })
		return
	end
	for i, s in ipairs(list) do
		local nilai = s.answered > 0 and math.floor(s.correct / s.answered * 100 + 0.5) or 0
		rosterRow(rosterList, i, { s.kelas, string.format("%02d", s.absen), s.nama, s.correct .. "/" .. s.answered, nilai,
			Ui.number(s.xp) .. " · " .. s.title })
	end
	if #list == 0 then
		Ui.text({ Size = UDim2.new(1, 0, 0, 30), Text = "Belum ada siswa yang mendaftar.", TextColor3 = T.InkSoft, ZIndex = 5, Parent = rosterList })
	end
end
local refreshRoster = Ui.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -70, 0, -32), Size = UDim2.fromOffset(140, 40),
	Text = "MUAT ULANG", TextSize = 14, ZIndex = 6 }, loadRoster, "primary")
refreshRoster.Parent = rosterContent

local function TeacherCommand(command, value)
	remotes.TeacherCommand:FireServer(command, value)
end

local teacherHolder, teacherRefresh
local function buildTeacherPanel()
	if teacherHolder then
		return
	end
	teacherButton.Visible = true
	local body
	teacherHolder, body = Ui.card({ Name = "PanelGuru", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 236, 0.5, 0),
		Size = UDim2.fromOffset(320, 604), Visible = false, Parent = gui }, { radius = 20 })
	addPixelScale(teacherHolder)
	Ui.padding(body, 16, 18, 16, 18)
	Ui.list(body, Enum.FillDirection.Vertical, 8)
	Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), Text = "Panel Guru", Font = F.Display, TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = body })

	local function currentSetting(key, default)
		return state.settings and state.settings[key] or default
	end
	local function row(order, labelText)
		local frame = Ui.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = body })
		Ui.text({ Size = UDim2.new(0.34, 0, 1, 0), Text = labelText, Font = F.Bold, TextSize = 14, TextColor3 = T.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
		return frame
	end
	local function cycleButton(frame, list, key, command)
		local button = Ui.button({ Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.64, 0, 1, 0), Text = "", TextSize = 13,
			Font = F.Bold }, function()
			local currentId = currentSetting(key, list[1].id)
			local index = 1
			for i, item in ipairs(list) do
				if item.id == currentId then
					index = i
				end
			end
			TeacherCommand(command, list[index % #list + 1].id)
		end, "neutral")
		button.Parent = frame
		return button
	end
	local function stepper(frame, onMinus, onPlus)
		local minus = Ui.button({ Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), Text = "–", TextSize = 22 }, onMinus, "neutral")
		minus.Parent = frame
		local value = Ui.text({ Position = UDim2.new(0.56, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), Text = "", Font = F.Display, TextSize = 20,
			Parent = frame })
		local plus = Ui.button({ Position = UDim2.new(0.82, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), Text = "+", TextSize = 22 }, onPlus, "neutral")
		plus.Parent = frame
		return value
	end

	local modeButton = cycleButton(row(2, "Mode"), Config.Modes, "mode", "mode")
	local topicButton = cycleButton(row(3, "Topik"), Config.Topics, "topic", "topic")
	local countValue = stepper(row(4, "Soal/game"), function()
		TeacherCommand("count", math.max(3, currentSetting("count", 5) - 1))
	end, function()
		TeacherCommand("count", math.min(30, currentSetting("count", 5) + 1))
	end)
	local timeValue = stepper(row(5, "Waktu/soal"), function()
		TeacherCommand("time", math.max(5, currentSetting("time", 20) - 5))
	end, function()
		TeacherCommand("time", math.min(60, currentSetting("time", 20) + 5))
	end)
	local autoButton = Ui.button({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 40), Text = "", TextSize = 14 }, function()
		TeacherCommand("auto", not currentSetting("auto", true))
	end, "neutral")
	autoButton.Parent = body
	local buttons = {
		{ 7, "MULAI SEKARANG", "success", function() TeacherCommand("start") end },
		{ 8, "KUNCI JAWABAN / AKHIRI BALAPAN", "gold", function() TeacherCommand("lock") end },
		{ 9, "HENTIKAN SESI", "danger", function() TeacherCommand("stop") end },
		{ 10, "DAFTAR SISWA & NILAI", "primary", function()
			closeAllModals()
			rosterHolder.Visible = true
			loadRoster()
		end },
		{ 11, "CETAK REKAP KE OUTPUT", "dark", function()
			TeacherCommand("recap")
			showToast("Rekap dicetak", "Buka Developer Console (F9) > Server untuk menyalin rekap nilai.", T.White, 3.5)
		end },
	}
	for _, info in ipairs(buttons) do
		local button = Ui.button({ LayoutOrder = info[1], Size = UDim2.new(1, 0, 0, 44), Text = info[2], TextSize = 14 }, info[4], info[3])
		button.Parent = body
	end
	Ui.text({ LayoutOrder = 12, Size = UDim2.new(1, 0, 0, 30), Text = "Pengaturan baru berlaku di sesi berikutnya.", Font = F.Medium,
		TextSize = 13, TextColor3 = T.InkSoft, Parent = body })

	teacherButton.Activated:Connect(function()
		teacherHolder.Visible = not teacherHolder.Visible
	end)
	teacherRefresh = function()
		local settings = state.settings
		if not settings then
			return
		end
		modeButton.Text = settings.modeName
		topicButton.Text = settings.topicName
		countValue.Text = tostring(settings.count)
		timeValue.Text = settings.time .. "s"
		autoButton.Text = settings.auto and "Mulai otomatis: ON" or "Mulai otomatis: OFF (manual)"
		autoButton.BackgroundColor3 = settings.auto and Color3.fromRGB(214, 244, 226) or T.Paper2
	end
	teacherRefresh()
	updatePixelScales()
end

local function checkTeacher()
	if player:GetAttribute("IsTeacher") then
		buildTeacherPanel()
	end
end
player:GetAttributeChangedSignal("IsTeacher"):Connect(checkTeacher)
checkTeacher()

---------------------------------------------------------------------
-- BENDA 3D (deteksi posisi & efek bantuan lokal)
---------------------------------------------------------------------
local function arenaChild(path)
	local current = workspace:FindFirstChild("ArenaKuis")
	for _, name in ipairs(string.split(path, "/")) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function padUnderMe()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	for _, option in ipairs(state.options) do
		local pad = arenaChild("KotakJawaban/Pad" .. option.pad)
		if pad then
			local rel = pad.CFrame:PointToObjectSpace(root.Position)
			local half = pad.Size / 2
			if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y > -half.Y and rel.Y < 10 then
				return option.pad
			end
		end
	end
	return nil
end

local function restoreLocalPads()
	for index, color in pairs(state.savedPadColors) do
		local pad = arenaChild("KotakJawaban/Pad" .. index)
		if pad then
			pad.Color = color
		end
	end
	state.savedPadColors = {}
end

---------------------------------------------------------------------
-- PEMBARUAN TAMPILAN
---------------------------------------------------------------------
local function hintUsable()
	if state.hintUsed or state.hints <= 0 then
		return false
	end
	if state.mode == "question" then
		return (state.kind == "PG" and not state.locked) or (state.kind == "ISIAN" and not state.sandiDone)
	end
	return state.mode == "race" and state.kind == "PG" and state.gate ~= nil
end

local function updateHud()
	scoreLabel.Text = Ui.number(state.score)
	streakChip.Text = "STREAK " .. state.streak
	streakChip.Visible = state.streak >= 2
	local usable = hintUsable()
	hintButton.Text = (state.kind == "ISIAN" and "PETUNJUK HURUF" or "BANTUAN 50:50") .. "  ·  " .. state.hints
	hintButton.BackgroundColor3 = usable and Color3.fromRGB(140, 92, 246) or T.Night2
	hintButton.TextTransparency = (usable or state.hints > 0) and 0 or 0.45
	updateRankHud()
end

local function hideRoundUi()
	questionHolder.Visible = false
	optionsHolder.Visible = false
	sandiHolder.Visible = false
	explainHolder.Visible = false
	introHolder.Visible = false
	breakHolder.Visible = false
end

local function cardForPad(pad)
	for i, option in ipairs(state.options) do
		if option.pad == pad then
			return cards[i]
		end
	end
	return nil
end

local function setupCards(options, clickable)
	placeOptions(clickable)
	for i, card in ipairs(cards) do
		local option = options[i]
		card.button.Visible = option ~= nil
		card.button.Active = clickable
		card.button.Size = (#options == 2) and UDim2.new(0.4, -6, 1, 0) or UDim2.new(0.25, -8, 1, 0)
		card.you.Visible = false
		card.count.Visible = false
		card.ring.Thickness = 0
		card.face.BackgroundTransparency = 0
		card.shade.BackgroundTransparency = 0
		card.text.TextTransparency = 0
		card.face.Position = UDim2.new()
		if option then
			card.face.BackgroundColor3 = option.color
			card.shade.BackgroundColor3 = Ui.darker(option.color)
			card.letter.Text = option.letter
			card.letter.TextColor3 = option.color
			card.text.Text = option.text
		end
	end
end

local function dimCard(card)
	card.face.BackgroundTransparency = 0.55
	card.shade.BackgroundTransparency = 0.7
	card.text.TextTransparency = 0.35
end

local function showBanner(title, sub)
	bannerHolder.Visible = true
	bannerTitle.Text = title
	bannerSub.Text = sub or ""
end

local function lobbySubtitle()
	local s = state.settings
	if not s then
		return "Baca Zona Materi dan kunjungi Taman Pet sambil menunggu."
	end
	return s.modeName .. "  ·  " .. s.topicName .. "  ·  Baca Zona Materi sambil menunggu"
end

local function showQuestionCard(msg, counterText)
	questionHolder.Visible = true
	local adv = state.adventure
	local step = (adv and #adv.games > 1) and ("GAME " .. adv.index .. "/" .. #adv.games .. "  ·  ") or ""
	modeChip.Text = step .. string.upper(state.gameName or "")
	modeChip.BackgroundColor3 = state.modeColor
	topicLabel.Text = msg.topicName or ""
	counterLabel.Text = counterText
	counterLabel.Visible = not msg.isBoss
	bossChip.Visible = msg.isBoss == true
	setQuestionText(msg.text)
	choiceHint.Text = ""
	timerFill.BackgroundColor3 = state.modeColor
	Ui.pop(questionHolder, 0.92)
end

local handlers = {}

function handlers.Settings(msg)
	state.settings = msg
	if teacherRefresh then
		teacherRefresh()
	end
	if state.mode == "intermission" or state.mode == "waiting" then
		bannerSub.Text = lobbySubtitle()
	end
end

function handlers.Profile(msg)
	Registration.OnProfile(msg)
end

function handlers.Adventure(msg)
	state.adventure = { index = msg.index, games = msg.games }
end

function handlers.AdventureEnd()
	state.adventure = nil
end

function handlers.Waiting(msg)
	state.mode = "waiting"
	showPlayerList(true)
	hideRoundUi()
	showBanner(msg.reason == "teacher" and "Menunggu guru memulai" or "Menunggu siswa mendaftar", lobbySubtitle())
end

function handlers.Intermission(msg)
	state.mode = "intermission"
	showPlayerList(true)
	state.endsAt = msg.endsAt
	hideRoundUi()
	showBanner("Petualangan segera dimulai", lobbySubtitle())
end

function handlers.ModeIntro(msg)
	state.mode = "intro"
	state.gameMode = msg.modeId
	state.gameName = msg.modeName
	state.modeColor = msg.color
	state.endsAt = msg.endsAt
	state.lastSecond = -1
	state.options = {}
	showPlayerList(false)
	closeAllModals()
	hideRoundUi()
	bannerHolder.Visible = false
	introBand.BackgroundColor3 = msg.color
	countdownLabel.TextColor3 = msg.color
	introStep.Text = (msg.gameTotal and msg.gameTotal > 1) and ("GAME " .. msg.gameIndex .. " DARI " .. msg.gameTotal) or "GAME"
	introName.Text = msg.modeName
	introDesc.Text = msg.desc
	introInfo.Text = "Topik: " .. msg.topicName .. "   ·   " .. msg.total .. " soal"
	if state.adventure and #state.adventure.games > 1 then
		stepRow.Visible = true
		fillSteps(stepRow, state.adventure.games, msg.gameIndex, 145)
		introHolder.Size = UDim2.fromOffset(660, 320)
	else
		stepRow.Visible = false
		introHolder.Size = UDim2.fromOffset(660, 250)
	end
	introHolder.Visible = true
	Ui.pop(introHolder, 0.7)
	play("Question")
end

local function beginQuestion(msg)
	state.questionId = msg.id
	state.options = msg.options or {}
	state.kind = msg.kind
	state.myPad = nil
	state.locked = false
	state.hintUsed = false
	state.hiddenPads = {}
	restoreLocalPads()
	closeAllModals()
	bannerHolder.Visible = false
	explainHolder.Visible = false
	introHolder.Visible = false
	breakHolder.Visible = false
end

function handlers.Question(msg)
	beginQuestion(msg)
	state.mode = "question"
	state.endsAt = msg.endsAt
	state.duration = msg.duration
	state.lastSecond = -1
	state.clickable = msg.clickable == true
	state.sandiDone = false
	showQuestionCard(msg, "Soal " .. msg.index .. " dari " .. msg.total)

	if msg.kind == "ISIAN" then
		optionsHolder.Visible = false
		sandiHolder.Visible = true
		alphabet.Visible = msg.isCipher == true
		sandiBox.Text = ""
		sandiHint.Text = ""
		sandiInfo.TextColor3 = T.InkSoft
		sandiInfo.Text = "Kamu punya " .. (msg.attempts or 3) .. " kesempatan. Tekan Enter atau KIRIM."
		setSandiEnabled(true)
		choiceHint.Text = msg.isCipher and "Geser setiap huruf MUNDUR untuk membaca kata aslinya." or "Ketik jawaban singkat di kotak bawah."
		choiceHint.TextColor3 = T.InkSoft
	else
		sandiHolder.Visible = false
		setupCards(state.options, state.clickable)
		optionsHolder.Visible = true
		Ui.pop(optionsHolder, 0.9)
		if state.clickable then
			choiceHint.Text = "Tekan jawaban di bawah secepat mungkin!"
			choiceHint.TextColor3 = T.Primary
		end
	end
	updateHud()
	play("Question")
	if msg.isBoss then
		showToast("SOAL BOS", "Poin dikali " .. Config.BossMultiplier .. ". Fokus!", T.Gold, 2)
	end
end

function handlers.Race(msg)
	state.mode = "race"
	state.raceEndsAt = msg.endsAt
	state.raceDuration = math.max(1, msg.endsAt - serverNow())
	state.lastSecond = -1
	closeAllModals()
	hideRoundUi()
	bannerHolder.Visible = false
	showToast("BALAPAN DIMULAI!", "Masuk ke pintu jawaban yang benar.", T.Gold, 2.5)
	play("Correct")
end

function handlers.Gate(msg)
	beginQuestion(msg)
	state.mode = "race"
	state.gate = msg.index
	state.clickable = false
	showQuestionCard(msg, "Gerbang " .. msg.index .. " dari " .. msg.total)
	choiceHint.Text = "Masuk ke PINTU jawaban yang benar. Pintu salah membuatmu jatuh!"
	choiceHint.TextColor3 = T.InkSoft
	sandiHolder.Visible = false
	setupCards(state.options, false)
	optionsHolder.Visible = true
	updateHud()
end

function handlers.GateDone()
	state.gate = nil
	state.options = {}
	questionText.Text = "Semua gerbang sudah kamu lewati. Lompat terus ke FINISH!"
	counterLabel.Text = "Menuju finish"
	choiceHint.Text = ""
	optionsHolder.Visible = false
	updateHud()
end

function handlers.Finished(msg)
	showFeed(msg.name .. " mencapai finish urutan ke-" .. msg.place)
end

function handlers.RaceEnd(msg)
	state.mode = "explain"
	state.gate = nil
	hideRoundUi()
	local top = {}
	for i = 1, math.min(3, #msg.finishers) do
		table.insert(top, msg.finishers[i])
	end
	showToast("BALAPAN SELESAI", #top > 0 and table.concat(top, "   ") or "Belum ada yang mencapai finish.", T.Gold, 3)
end

function handlers.AnswerLocked(msg)
	state.locked = true
	for i, option in ipairs(state.options) do
		local card = cards[i]
		if option.pad == msg.pad then
			card.ring.Thickness = 4
			card.you.Text = "PILIHANMU"
			card.you.Visible = true
			card.face.Position = UDim2.fromOffset(0, 3)
			choiceHint.Text = "Jawabanmu terkunci: " .. option.letter .. ". " .. option.text
			choiceHint.TextColor3 = T.Good
		else
			dimCard(card)
		end
	end
	updateHud()
end

function handlers.Stats(msg)
	state.score, state.streak, state.hints = msg.score, msg.streak, msg.hints
	updateHud()
end

local cheers = { "BENAR!", "MANTAP!", "HEBAT!", "KEREN!", "JENIUS!" }
function handlers.Result(msg)
	state.score, state.streak, state.hints = msg.score, msg.streak, msg.hints
	if state.mode == "question" and state.kind ~= "ISIAN" then
		state.mode = "explain"
	end
	if msg.correct then
		local sub = "+" .. msg.gained .. " poin"
		if msg.streak >= 2 then
			sub ..= "   ·   streak " .. msg.streak
		end
		if msg.earnedHint then
			sub ..= "   ·   dapat bantuan"
			task.delay(0.4, function()
				play("Hint")
			end)
		end
		showToast(cheers[math.random(1, #cheers)], sub, Color3.fromRGB(110, 240, 160), 2.2)
		flashScreen(T.Good)
		play("Correct")
	elseif msg.answered then
		showToast("BELUM TEPAT", msg.gate and "Kamu jatuh. Coba pintu lain!" or "Tidak apa-apa, baca penjelasannya ya.",
			Color3.fromRGB(255, 130, 140), 2.2)
		flashScreen(T.Bad)
		play("Wrong")
	else
		showToast("WAKTU HABIS", "Kamu belum menjawab soal ini.", T.Gold, 2.2)
		play("Wrong")
	end
	if msg.gate and msg.explanation then
		local answer = msg.correctLetter .. ". " .. msg.correctText
		showExplain(msg.correct and ("Gerbang " .. msg.gate .. " benar: " .. answer) or ("Jawaban gerbang " .. msg.gate .. ": " .. answer),
			msg.correct, msg.explanation, serverNow() + (msg.correct and 4 or 6), 18)
	end
	Ui.pop(scoreHolder, 1.08)
	updateHud()
end

function handlers.Bonus(msg)
	state.score = msg.score
	showToast("+" .. msg.amount .. " BONUS", msg.reason, T.Gold, 3)
	play("Fanfare")
	updateHud()
end

function handlers.Reveal(msg)
	state.mode = "explain"
	restoreLocalPads()
	choiceHint.Text = ""
	timerNumber.Text = "–"
	if state.kind == "ISIAN" then
		-- kotak ketik tidak diperlukan lagi; penjelasan menempati posisinya
		setSandiEnabled(false)
		sandiHolder.Visible = false
		showExplain("Jawaban: " .. msg.correctText .. "   ·   " .. (msg.solved or 0) .. " siswa berhasil", true, msg.explanation, msg.explainEndsAt)
	else
		for i, option in ipairs(state.options) do
			local card = cards[i]
			card.count.Text = (msg.counts[option.pad] or 0) .. " pemain"
			card.count.Visible = true
			if option.pad == msg.correctPad then
				card.ring.Thickness = 4
				card.face.BackgroundTransparency = 0
				Ui.pop(card.button, 1.08)
			else
				dimCard(card)
			end
		end
		local prefix = state.kind == "PG" and (msg.correctLetter .. ". ") or ""
		showExplain("Jawaban benar: " .. prefix .. msg.correctText, true, msg.explanation, msg.explainEndsAt,
			state.clickable and (18 + 118 + 12) or 18)
	end
	updateHud()
end

function handlers.GameEnd(msg)
	state.mode = "break"
	state.endsAt = msg.endsAt
	state.lastSecond = -1
	state.nextName = msg.nextName
	hideRoundUi()
	closeAllModals()
	breakBand.BackgroundColor3 = msg.color
	breakStep.Text = "HASIL GAME " .. msg.gameIndex .. " DARI " .. msg.gameTotal
	breakTitle.Text = msg.modeName
	Ui.clear(breakLeft)
	Ui.clear(breakRight)
	for i = 1, math.min(5, #msg.gameRanking) do
		local row = msg.gameRanking[i]
		rankRow(breakLeft, i, row, row.userId == player.UserId, 38)
	end
	for i = 1, math.min(5, #msg.totalRanking) do
		local row = msg.totalRanking[i]
		rankRow(breakRight, i, row, row.userId == player.UserId, 38)
	end
	breakMine.Text = ""
	breakNext.Text = "Berikutnya: " .. msg.nextName
	breakHolder.Visible = true
	Ui.pop(breakHolder, 0.8)
	play("Fanfare")
end

function handlers.GameScore(msg)
	breakMine.Text = "Kamu: +" .. Ui.number(msg.gameScore) .. " poin di game ini (" .. msg.correct .. "/" .. msg.answered .. " benar)   ·   Total "
		.. Ui.number(msg.totalScore)
end

function handlers.RoundEnd(msg)
	state.mode = "results"
	state.options = {}
	state.gate = nil
	hideRoundUi()
	bannerHolder.Visible = false
	closeAllModals()
	hideToast() -- bonus tamat sudah tercantum di rapor
	resultsTitle.Text = "Hasil Akhir  ·  " .. (msg.modeName or "")
	showRanking(msg.ranking)
	Ui.clear(personal)
	personalLine(1, "Kamu belum ikut menjawab di sesi ini. Ikut sesi berikutnya ya!", T.InkSoft)
	resultsHolder.Visible = true
	Ui.pop(resultsHolder, 0.85)
	play("Fanfare")
end

function handlers.Summary(msg)
	showSummary(msg)
end

function handlers.Stopped()
	state.mode = "idle"
	state.options = {}
	state.gate = nil
	state.adventure = nil
	restoreLocalPads()
	hideRoundUi()
	showPlayerList(true)
	showToast("SESI DIHENTIKAN", "Guru menghentikan sesi ini.", T.Gold, 3)
end

remotes.QuizEvent.OnClientEvent:Connect(function(msg)
	local handler = type(msg) == "table" and handlers[msg.type]
	if handler then
		handler(msg)
	end
end)

---------------------------------------------------------------------
-- TOMBOL JAWABAN (Kuis Kilat)
---------------------------------------------------------------------
onCardClicked = function(index)
	if state.mode ~= "question" or not state.clickable or state.locked then
		return
	end
	local option = state.options[index]
	if not option or state.hiddenPads[option.pad] then
		return
	end
	state.locked = true
	play("Hint")
	remotes.Answer:FireServer(state.questionId, option.pad)
end

---------------------------------------------------------------------
-- BANTUAN (50:50 / petunjuk huruf)
---------------------------------------------------------------------
useHint = function()
	if not hintUsable() then
		if state.hints <= 0 then
			showToast("Bantuan habis", "Jawab benar " .. Config.HintEveryStreak .. "x berturut-turut untuk mendapatkannya.", T.White, 2)
		else
			showToast("Belum bisa", "Bantuan dipakai saat soal sedang berlangsung.", T.White, 2)
		end
		return
	end
	local ok, result, info = pcall(function()
		return remotes.UseHint:InvokeServer()
	end)
	if not ok or type(result) ~= "table" then
		showToast("Bantuan", (ok and info) or "Coba lagi.", T.White, 2.2)
		return
	end
	state.hints = info
	state.hintUsed = true
	play("Hint")
	if result.type == "huruf" then
		sandiHint.Text = "Petunjuk:  " .. result.text
		showToast("PETUNJUK", result.text, Color3.fromRGB(200, 170, 255), 2)
	else
		for _, padIndex in ipairs(result.pads) do
			state.hiddenPads[padIndex] = true
			local card = cardForPad(padIndex)
			if card then
				dimCard(card)
				card.letter.Text = "×"
			end
			if result.gate then
				local sign = arenaChild("LintasanFirewall/Gerbang" .. result.gate .. "/Tanda" .. padIndex)
				if sign then
					sign.Color = Color3.fromRGB(55, 55, 60)
					local answer = sign:FindFirstChild("Gui") and sign.Gui:FindFirstChild("Jawaban")
					if answer then
						answer.Text = "SALAH"
					end
				end
			else
				local pad = arenaChild("KotakJawaban/Pad" .. padIndex)
				if pad then
					state.savedPadColors[padIndex] = state.savedPadColors[padIndex] or pad.Color
					pad.Color = Color3.fromRGB(55, 55, 60)
				end
			end
		end
		showToast("50:50", "Dua jawaban salah sudah dihapus.", Color3.fromRGB(200, 170, 255), 2)
	end
	updateHud()
end

---------------------------------------------------------------------
-- LOOP PER FRAME: timer, hitung mundur, posisi pemain
---------------------------------------------------------------------
local lastPositionCheck = 0
local function setTimer(left, total)
	local ratio = math.clamp(left / math.max(total, 0.01), 0, 1)
	timerFill.Size = UDim2.fromScale(ratio, 1)
	local color = ratio < 0.3 and T.Bad or state.modeColor
	timerFill.BackgroundColor3 = color
	timerStroke.Color = color
	local seconds = math.ceil(left)
	if seconds ~= state.lastSecond then
		state.lastSecond = seconds
		timerNumber.Text = formatTime(left)
		return seconds
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local t = serverNow()
	local left = math.max(0, state.endsAt - t)

	if state.mode == "question" then
		local changed = setTimer(left, state.duration)
		if changed and changed <= 5 and changed > 0 then
			play("Tick")
			Ui.pop(timerCircle, 1.2)
		end
		if not state.clickable and state.kind ~= "ISIAN" and os.clock() - lastPositionCheck > 0.1 then
			lastPositionCheck = os.clock()
			local pad = padUnderMe()
			if pad ~= state.myPad then
				state.myPad = pad
				for _, card in ipairs(cards) do
					card.you.Visible = false
					card.ring.Thickness = 0
				end
				local card = pad and cardForPad(pad)
				if card then
					card.you.Text = "POSISIMU"
					card.you.Visible = true
					card.ring.Thickness = 4
					Ui.pop(card.button, 1.06)
				end
			end
			if pad then
				local option
				for _, o in ipairs(state.options) do
					if o.pad == pad then
						option = o
					end
				end
				local letter = state.kind == "PG" and (option.letter .. ". ") or ""
				choiceHint.Text = "Jawabanmu: " .. letter .. option.text
				choiceHint.TextColor3 = state.hiddenPads[pad] and T.Bad or T.Primary
			elseif left <= 5 then
				choiceHint.Text = (math.floor(t * 3) % 2 == 0) and "CEPAT! Berdiri di kotak jawaban!" or ""
				choiceHint.TextColor3 = T.Bad
			else
				choiceHint.Text = "Lari ke kotak jawaban pilihanmu."
				choiceHint.TextColor3 = T.InkSoft
			end
		end
	elseif state.mode == "race" then
		local changed = setTimer(math.max(0, state.raceEndsAt - t), state.raceDuration)
		if changed and changed <= 10 and changed > 0 then
			play("Tick")
		end
	elseif state.mode == "intermission" then
		bannerTitle.Text = "Petualangan dimulai dalam " .. math.ceil(left) .. " detik"
	elseif state.mode == "intro" then
		local seconds = math.ceil(left)
		if seconds ~= state.lastSecond then
			state.lastSecond = seconds
			countdownLabel.Text = seconds > 0 and tostring(seconds) or "GO"
			Ui.pop(countCircle, 1.25)
			if seconds <= 3 then
				play(seconds > 0 and "Tick" or "Correct")
			end
		end
	elseif state.mode == "break" then
		local seconds = math.ceil(left)
		if seconds ~= state.lastSecond then
			state.lastSecond = seconds
			breakNext.Text = "Berikutnya: " .. state.nextName .. "   ·   mulai dalam " .. seconds .. " detik"
		end
	end

	if explainHolder.Visible then
		local explainLeft = state.explainEndsAt - t
		explainFill.Size = UDim2.fromScale(math.clamp(explainLeft / state.explainDuration, 0, 1), 1)
		if explainLeft <= -0.5 and state.mode ~= "explain" then
			explainHolder.Visible = false
		end
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updatePixelScales)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePixelScales)
end
updatePixelScales()
updateHud()
remotes.ClientReady:FireServer()
