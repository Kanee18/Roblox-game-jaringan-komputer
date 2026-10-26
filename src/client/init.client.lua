--[[
	NET QUEST - Client (tampilan di layar pemain)
	Menampilkan: pendaftaran, soal & timer, kartu/tombol jawaban, kotak ketik (Pecahkan Sandi),
	HUD poin/streak/Poin Rank, efek benar/salah, penjelasan materi, hasil ronde,
	Zona Materi, Cara Main, koleksi Pet, dan Panel Guru.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("QuizShared")
local Config = require(Shared:WaitForChild("Config"))
local Materi = require(Shared:WaitForChild("Materi"))
local PetCatalog = require(Shared:WaitForChild("PetCatalog"))
local Ui = require(script:WaitForChild("Ui"))
local Registration = require(script:WaitForChild("Registration"))
local Pets = require(script:WaitForChild("Pets"))
local T = Ui.Theme

local remotesFolder = ReplicatedStorage:WaitForChild("QuizRemotes")
local remotes = {}
for _, name in ipairs({ "QuizEvent", "TeacherCommand", "ClientReady", "Answer", "EquipPet", "UseHint", "Register", "SubmitText", "GetRoster" }) do
	remotes[name] = remotesFolder:WaitForChild(name)
end

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local state = {
	mode = "idle", -- idle / waiting / intermission / intro / question / explain / race / results
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
}

local function serverNow()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------
-- SUARA
---------------------------------------------------------------------
local sounds = {}
for name, id in pairs(Config.Sounds) do
	if id ~= "" then
		sounds[name] = Ui.new("Sound", { Name = "NetQuest_" .. name, SoundId = id, Volume = 0.6, Parent = SoundService })
	end
end
if Config.MusicId ~= "" then
	local music = Ui.new("Sound", { Name = "NetQuest_Musik", SoundId = Config.MusicId, Volume = 0.25, Looped = true,
		Parent = SoundService })
	music:Play()
end
local function play(name)
	local sound = sounds[name]
	if sound then
		sound:Play()
	end
end

---------------------------------------------------------------------
-- ROOT GUI
---------------------------------------------------------------------
local gui = Ui.new("ScreenGui", {
	Name = "NetQuestGui",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Panel berukuran piksel ikut mengecil di layar HP
local pixelScales = {}
local function addPixelScale(frame)
	local scale = Ui.new("UIScale", { Parent = frame })
	table.insert(pixelScales, scale)
	return scale
end
local function updatePixelScales()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local value = math.clamp(math.min(camera.ViewportSize.Y / 760, camera.ViewportSize.X / 1100), 0.55, 1)
	for _, scale in ipairs(pixelScales) do
		scale.Scale = value
	end
end

local flash = Ui.new("Frame", { Name = "Kilat", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Good,
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })
local function flashScreen(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.55
	Ui.tween(flash, 0.8, { BackgroundTransparency = 1 })
end

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 60 then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end
	return tostring(seconds)
end

---------------------------------------------------------------------
-- BANNER LOBI
---------------------------------------------------------------------
local banner = Ui.panel({ Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0.52, 0, 0.13, 0), Visible = false, Parent = gui })
Ui.sizeLimit(banner, Vector2.new(300, 70), Vector2.new(780, 120))
local bannerTitle = Ui.text({ Position = UDim2.new(0, 12, 0.06, 0), Size = UDim2.new(1, -24, 0.5, 0),
	Font = Enum.Font.FredokaOne, MaxTextSize = 34, Parent = banner })
local bannerSub = Ui.text({ Position = UDim2.new(0, 12, 0.56, 0), Size = UDim2.new(1, -24, 0.38, 0),
	TextColor3 = T.Sub, Font = Enum.Font.GothamMedium, MaxTextSize = 20, Parent = banner })

---------------------------------------------------------------------
-- PANEL SOAL (atas)
---------------------------------------------------------------------
local questionPanel = Ui.panel({ Name = "PanelSoal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0.62, 0, 0.23, 0), Visible = false, Parent = gui })
Ui.sizeLimit(questionPanel, Vector2.new(320, 120), Vector2.new(940, 220))
local questionStroke = questionPanel:FindFirstChildOfClass("UIStroke")
local topicChip = Ui.text({ Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(0.5, 0, 0.15, 0),
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Sub, MaxTextSize = 18, Parent = questionPanel })
local counterLabel = Ui.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -90, 0, 6), Size = UDim2.new(0.3, 0, 0.15, 0),
	TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.Sub, MaxTextSize = 18, Parent = questionPanel })
local bossBadge = Ui.text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0, 210, 0, 30),
	BackgroundTransparency = 0, BackgroundColor3 = T.Bad, Text = "⚠ SOAL BOS • POIN x2 ⚠", Font = Enum.Font.FredokaOne,
	Visible = false, Parent = questionPanel })
Ui.corner(bossBadge, 8)
local questionText = Ui.text({ Position = UDim2.new(0, 14, 0.2, 0), Size = UDim2.new(1, -110, 0.56, 0),
	MaxTextSize = 34, Parent = questionPanel })
local choiceHint = Ui.text({ Position = UDim2.new(0, 14, 0.76, 0), Size = UDim2.new(1, -110, 0.14, 0),
	TextColor3 = T.Gold, MaxTextSize = 20, Parent = questionPanel })
local timerBack = Ui.new("Frame", { Position = UDim2.new(0, 14, 1, -14), Size = UDim2.new(1, -28, 0, 7),
	BackgroundColor3 = Color3.fromRGB(40, 45, 80), BorderSizePixel = 0, Parent = questionPanel })
Ui.corner(timerBack, 4)
local timerFill = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Good, BorderSizePixel = 0,
	Parent = timerBack })
Ui.corner(timerFill, 4)
local timerCircle = Ui.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.48, 0),
	Size = UDim2.new(0, 72, 0, 72), BackgroundColor3 = T.Panel2, BorderSizePixel = 0, Parent = questionPanel })
Ui.corner(timerCircle, 36)
local timerStroke = Ui.stroke(timerCircle, T.Good, 4)
local timerNumber = Ui.text({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.FredokaOne, MaxTextSize = 34, Parent = timerCircle })

local feedLabel = Ui.text({ Name = "Kabar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.26, 0),
	Size = UDim2.new(0.5, 0, 0.04, 0), TextColor3 = T.Gold, TextStrokeTransparency = 0.3, MaxTextSize = 20, Text = "",
	Parent = gui })
local feedToken = 0
local function showFeed(text)
	feedToken += 1
	local token = feedToken
	feedLabel.Text = text
	feedLabel.TextTransparency = 0
	task.delay(4, function()
		if feedToken == token then
			Ui.tween(feedLabel, 0.5, { TextTransparency = 1 })
		end
	end)
end

---------------------------------------------------------------------
-- KARTU / TOMBOL JAWABAN (bawah)
---------------------------------------------------------------------
local optionsBar = Ui.new("Frame", { Name = "KartuJawaban", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.66, 0, 0.13, 0), BackgroundTransparency = 1, Visible = false, Parent = gui })
local optionsLimit = Ui.sizeLimit(optionsBar, Vector2.new(320, 64), Vector2.new(1000, 120))
Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = optionsBar })

local cards = {}
local function onCardClicked(index) end -- diisi di bawah
for i = 1, 4 do
	local card = Ui.new("TextButton", { Name = "Kartu" .. i, LayoutOrder = i, Size = UDim2.new(0.25, -6, 1, 0), Text = "",
		AutoButtonColor = false, BackgroundColor3 = Config.PadColors[i], BorderSizePixel = 0, Parent = optionsBar })
	Ui.corner(card, 12)
	local stroke = Ui.stroke(card, Color3.new(1, 1, 1), 0)
	local letter = Ui.text({ Position = UDim2.new(0, 4, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), Font = Enum.Font.FredokaOne,
		MaxTextSize = 40, TextStrokeTransparency = 0.6, Parent = card })
	local text = Ui.text({ Position = UDim2.new(0.21, 0, 0, 6), Size = UDim2.new(0.77, 0, 1, -12),
		TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 22, TextStrokeTransparency = 0.7, Parent = card })
	local count = Ui.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 2), Size = UDim2.new(0.5, 0, 0.26, 0),
		TextXAlignment = Enum.TextXAlignment.Right, MaxTextSize = 16, Text = "", Parent = card })
	local youTag = Ui.text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.new(0, 110, 0, 24),
		BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), TextColor3 = T.Panel, Text = "📍 POSISIMU",
		MaxTextSize = 16, Visible = false, Parent = card })
	Ui.corner(youTag, 8)
	card.Activated:Connect(function()
		onCardClicked(i)
	end)
	cards[i] = { frame = card, stroke = stroke, letter = letter, text = text, count = count, you = youTag }
end

---------------------------------------------------------------------
-- KOTAK KETIK (mode Pecahkan Sandi)
---------------------------------------------------------------------
local sandiPanel = Ui.panel({ Name = "KotakSandi", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0, 560, 0, 150), Visible = false, Parent = gui })
addPixelScale(sandiPanel)
local alphabet = Ui.text({ Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 22), TextColor3 = Color3.fromRGB(150, 230, 255),
	Font = Enum.Font.Code, Text = "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z", MaxTextSize = 20, Parent = sandiPanel })
local sandiBox = Ui.new("TextBox", { Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -150, 0, 50),
	BackgroundColor3 = Color3.fromRGB(245, 247, 255), TextColor3 = Color3.fromRGB(20, 25, 50), PlaceholderText = "Ketik jawabanmu di sini...",
	PlaceholderColor3 = Color3.fromRGB(140, 145, 165), Font = Enum.Font.GothamBold, TextSize = 24, Text = "", ClearTextOnFocus = false,
	BorderSizePixel = 0, Parent = sandiPanel })
Ui.corner(sandiBox, 10)
Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = sandiBox })
local sandiSend
local sandiInfo = Ui.text({ Position = UDim2.new(0, 12, 0, 88), Size = UDim2.new(1, -24, 0, 24), TextColor3 = T.Sub,
	MaxTextSize = 18, Parent = sandiPanel })
local sandiHint = Ui.text({ Position = UDim2.new(0, 12, 0, 114), Size = UDim2.new(1, -24, 0, 28), TextColor3 = Color3.fromRGB(200, 160, 255),
	Font = Enum.Font.Code, MaxTextSize = 22, Parent = sandiPanel })

local function setSandiEnabled(enabled)
	sandiBox.TextEditable = enabled
	sandiSend.AutoButtonColor = enabled
	sandiSend.BackgroundColor3 = enabled and T.Good or Color3.fromRGB(80, 80, 100)
end

local function submitSandi()
	if state.mode ~= "question" or state.kind ~= "ISIAN" or state.sandiDone or state.sandiBusy then
		return
	end
	local text = sandiBox.Text
	if string.gsub(text, "%s", "") == "" then
		sandiInfo.Text = "✏ Ketik jawabanmu dulu ya!"
		return
	end
	state.sandiBusy = true
	local ok, result = pcall(function()
		return remotes.SubmitText:InvokeServer(state.questionId, text)
	end)
	state.sandiBusy = false
	if not ok or type(result) ~= "table" then
		sandiInfo.Text = "⚠ Koneksi bermasalah, coba lagi."
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
		sandiInfo.Text = "✔ BENAR! Tunggu teman-temanmu selesai..."
	elseif (result.attemptsLeft or 0) <= 0 then
		state.sandiDone = true
		setSandiEnabled(false)
		sandiInfo.TextColor3 = T.Bad
		sandiInfo.Text = "✖ Kesempatan habis. Lihat jawabannya sebentar lagi."
		play("Wrong")
	else
		sandiInfo.TextColor3 = T.Bad
		sandiInfo.Text = "✖ Belum tepat! Sisa " .. result.attemptsLeft .. " kesempatan."
		play("Wrong")
		Ui.pop(sandiPanel, 1.06)
		sandiBox.Text = ""
		sandiBox:CaptureFocus()
	end
end
sandiSend = Ui.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 32), Size = UDim2.new(0, 120, 0, 50),
	Text = "Kirim ➤", BackgroundColor3 = T.Good, MaxTextSize = 24 }, submitSandi)
sandiSend.Parent = sandiPanel
sandiBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		submitSandi()
	end
end)

---------------------------------------------------------------------
-- HUD KANAN (poin, streak, Poin Rank, tombol)
---------------------------------------------------------------------
local hud = Ui.panel({ Name = "HUD", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.new(0, 176, 0, 330), Parent = gui })
addPixelScale(hud)
Ui.padding(hud, 8)
Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = hud })
local scoreLabel = Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), Text = "⭐ 0", Font = Enum.Font.FredokaOne,
	TextColor3 = T.Gold, MaxTextSize = 30, Parent = hud })
local streakLabel = Ui.text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 22), Text = "🔥 Streak 0", TextColor3 = Color3.fromRGB(255, 160, 80),
	MaxTextSize = 20, Parent = hud })
local rankLabel = Ui.text({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), Text = "🏅 Poin Rank 0", TextColor3 = Color3.fromRGB(150, 230, 255),
	MaxTextSize = 17, Parent = hud })
local petProgressBack = Ui.new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(40, 45, 80),
	BorderSizePixel = 0, Parent = hud })
Ui.corner(petProgressBack, 4)
local petProgressFill = Ui.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Pink, BorderSizePixel = 0, Parent = petProgressBack })
Ui.corner(petProgressFill, 4)
local petProgressText = Ui.text({ LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 16), Text = "", TextColor3 = T.Sub, Font = Enum.Font.GothamMedium,
	MaxTextSize = 13, Parent = hud })
local function useHint() end -- diisi di bawah
local hintButton = Ui.button({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 38), Text = "💡 Bantuan (0)",
	BackgroundColor3 = Color3.fromRGB(150, 90, 255) }, function()
	useHint()
end)
hintButton.Parent = hud
local petButton = Ui.button({ LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 38), Text = "🐾 Pet", BackgroundColor3 = T.Pink })
petButton.Parent = hud
local materiButton = Ui.button({ LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 38), Text = "📚 Materi", BackgroundColor3 = Color3.fromRGB(40, 150, 110) })
materiButton.Parent = hud
local helpButton = Ui.button({ LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 38), Text = "❓ Cara Main", BackgroundColor3 = Color3.fromRGB(60, 90, 170) })
helpButton.Parent = hud

local function updateRankHud()
	local xp = player:GetAttribute("PoinRank") or 0
	rankLabel.Text = "🏅 Poin Rank " .. xp
	local nextPet = PetCatalog.Next(xp)
	if nextPet then
		local previous = 0
		for _, pet in ipairs(PetCatalog.List) do
			if pet.xp <= xp then
				previous = pet.xp
			end
		end
		petProgressFill.Size = UDim2.fromScale(math.clamp((xp - previous) / math.max(1, nextPet.xp - previous), 0, 1), 1)
		petProgressText.Text = "Pet berikut: " .. nextPet.name .. " (" .. nextPet.xp .. ")"
	else
		petProgressFill.Size = UDim2.fromScale(1, 1)
		petProgressText.Text = "👑 Semua pet terbuka!"
	end
end
player:GetAttributeChangedSignal("PoinRank"):Connect(updateRankHud)

---------------------------------------------------------------------
-- TOAST (teks besar di tengah) & HITUNG MUNDUR
---------------------------------------------------------------------
local toast = Ui.new("Frame", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0),
	Size = UDim2.new(0.7, 0, 0.2, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 8, Parent = gui })
local toastTitle = Ui.text({ Size = UDim2.fromScale(1, 0.62), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0,
	TextStrokeColor3 = T.Panel, MaxTextSize = 80, ZIndex = 8, Parent = toast })
local toastSub = Ui.text({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.36), TextStrokeTransparency = 0.2,
	TextStrokeColor3 = T.Panel, MaxTextSize = 28, ZIndex = 8, Parent = toast })
local toastToken = 0
local function showToast(title, sub, color, duration)
	toastToken += 1
	local token = toastToken
	toastTitle.Text = title
	toastTitle.TextColor3 = color or T.Text
	toastSub.Text = sub or ""
	toast.Visible = true
	Ui.pop(toast, 0.4)
	task.delay(duration or 2.5, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local countdownLabel = Ui.text({ Name = "HitungMundur", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72),
	Size = UDim2.fromScale(0.3, 0.16), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = T.Panel,
	TextColor3 = T.Gold, Visible = false, MaxTextSize = 120, Parent = gui })

---------------------------------------------------------------------
-- KARTU PENGENALAN MODE
---------------------------------------------------------------------
local introCard = Ui.panel({ Name = "KartuMode", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(0, 620, 0, 250), Visible = false, Parent = gui })
addPixelScale(introCard)
local introStroke = introCard:FindFirstChildOfClass("UIStroke")
introStroke.Thickness = 4
Ui.text({ Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -32, 0, 24), Text = "MODE PERMAINAN", TextColor3 = T.Sub,
	MaxTextSize = 20, Parent = introCard })
local introName = Ui.text({ Position = UDim2.new(0, 16, 0, 36), Size = UDim2.new(1, -32, 0, 64), Font = Enum.Font.FredokaOne,
	MaxTextSize = 56, Parent = introCard })
local introDesc = Ui.text({ Position = UDim2.new(0, 24, 0, 106), Size = UDim2.new(1, -48, 0, 80), Font = Enum.Font.GothamBold,
	MaxTextSize = 24, Parent = introCard })
local introInfo = Ui.text({ Position = UDim2.new(0, 16, 0, 196), Size = UDim2.new(1, -32, 0, 36), TextColor3 = T.Gold,
	MaxTextSize = 22, Parent = introCard })

---------------------------------------------------------------------
-- PANEL PENJELASAN
---------------------------------------------------------------------
local explain = Ui.panel({ Name = "Penjelasan", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.86, -16),
	Size = UDim2.new(0.62, 0, 0.22, 0), Visible = false, Parent = gui })
Ui.sizeLimit(explain, Vector2.new(320, 110), Vector2.new(920, 210))
local explainTitle = Ui.text({ Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -28, 0.3, 0), TextColor3 = T.Good,
	Font = Enum.Font.FredokaOne, MaxTextSize = 28, Parent = explain })
local explainText = Ui.text({ Position = UDim2.new(0, 14, 0.36, 0), Size = UDim2.new(1, -28, 0.54, 0),
	Font = Enum.Font.GothamMedium, MaxTextSize = 22, Parent = explain })
local explainBack = Ui.new("Frame", { Position = UDim2.new(0, 14, 1, -12), Size = UDim2.new(1, -28, 0, 5),
	BackgroundColor3 = Color3.fromRGB(40, 45, 80), BorderSizePixel = 0, Parent = explain })
local explainFill = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
	Parent = explainBack })

local function showExplain(title, color, text, endsAt)
	explainTitle.Text = title
	explainTitle.TextColor3 = color
	explainText.Text = "📘 " .. (text or "")
	state.explainEndsAt = endsAt
	state.explainDuration = math.max(1, endsAt - serverNow())
	explain.Visible = true
	Ui.pop(explain, 0.9)
end

---------------------------------------------------------------------
-- MODAL (jendela tengah) helper
---------------------------------------------------------------------
local openModals = {}
local function makeModal(name, titleText, widthScale, heightScale)
	local modal = Ui.panel({ Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(widthScale, heightScale), Visible = false, ZIndex = 5, Parent = gui })
	Ui.sizeLimit(modal, Vector2.new(320, 260), Vector2.new(1000, 640))
	Ui.text({ Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(1, -80, 0.09, 0), Text = titleText,
		Font = Enum.Font.FredokaOne, TextColor3 = T.Gold, MaxTextSize = 34, ZIndex = 5, Parent = modal })
	local close = Ui.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.new(0, 40, 0, 40),
		Text = "✖", BackgroundColor3 = T.Bad, ZIndex = 6 }, function()
		modal.Visible = false
	end)
	close.Parent = modal
	openModals[name] = modal
	return modal
end
local function closeAllModals()
	for _, modal in pairs(openModals) do
		modal.Visible = false
	end
end

local function focusMode()
	return state.mode == "question" or state.mode == "race"
end

---------------------------------------------------------------------
-- ZONA MATERI (pembaca materi)
---------------------------------------------------------------------
local materiModal = makeModal("ModalMateri", "📚 ZONA MATERI", 0.8, 0.8)
local tabList = Ui.new("ScrollingFrame", { Position = UDim2.new(0.02, 0, 0.13, 0), Size = UDim2.new(0.28, 0, 0.84, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = materiModal })
Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })
local materiContent = Ui.new("ScrollingFrame", { Position = UDim2.new(0.32, 0, 0.13, 0), Size = UDim2.new(0.66, 0, 0.84, 0),
	BackgroundColor3 = T.Panel2, BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 6,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = materiModal })
Ui.corner(materiContent, 10)
Ui.padding(materiContent, 12)
Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = materiContent })

local function showMateri(topicId)
	Ui.clear(materiContent)
	local topic = Config.GetTopic(topicId)
	Ui.text({ LayoutOrder = 0, Size = UDim2.new(1, -8, 0, 34), Text = topic.icon .. " " .. topic.name, TextColor3 = topic.color,
		Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 28, ZIndex = 5, Parent = materiContent })
	for i, point in ipairs(Materi[topicId] or {}) do
		Ui.text({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false,
			TextSize = 19, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Text = "• " .. point,
			ZIndex = 5, Parent = materiContent })
	end
	materiContent.CanvasPosition = Vector2.zero
end

local function openMateri(topicId)
	if focusMode() then
		showToast("Fokus ke soal! 🧠", "Materi bisa dibaca lagi setelah soal selesai.", T.Gold, 2)
		return
	end
	closeAllModals()
	materiModal.Visible = true
	Ui.pop(materiModal, 0.85)
	showMateri(topicId or "konsep")
end

for order, topic in ipairs(Config.Topics) do
	if topic.id ~= "campuran" then
		local tab = Ui.button({ LayoutOrder = order, Size = UDim2.new(1, -6, 0, 44), Text = topic.icon .. " " .. topic.name,
			BackgroundColor3 = topic.color, TextColor3 = T.Panel, MaxTextSize = 18, ZIndex = 5 }, function()
			showMateri(topic.id)
		end)
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
-- CARA MAIN
---------------------------------------------------------------------
local helpModal = makeModal("ModalCaraMain", "❓ CARA MAIN NET QUEST", 0.72, 0.8)
local helpBody = Ui.new("ScrollingFrame", { Position = UDim2.new(0.04, 0, 0.13, 0), Size = UDim2.new(0.92, 0, 0.7, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = helpModal })
Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = helpBody })
local helpLines = {
	"🎮 Ada 4 MODE permainan yang bergantian:",
	"   🏃 LARI & PILIH: lari dan BERDIRI di kotak jawaban. Kotak yang salah akan JATUH!",
	"   ⚡ KUIS KILAT: tekan tombol jawaban di layar secepat mungkin. Jawaban tidak bisa diganti!",
	"   🧱 LINTASAN FIREWALL: balapan di langit! Masuk PINTU jawaban yang benar. Pintu salah = jatuh.",
	"   🔐 PECAHKAN SANDI: KETIK jawabanmu dan pecahkan kode rahasia Caesar Cipher.",
	"⭐ Jawab cepat = bonus poin. Benar berturut-turut = bonus STREAK 🔥",
	"💡 Benar 3x berturut-turut = dapat BANTUAN (50:50 atau petunjuk huruf).",
	"⚠ Soal terakhir adalah SOAL BOS dengan poin x2!",
	"📘 Baca PENJELASAN setelah setiap soal dan papan ZONA MATERI di taman (tekan E / ketuk papan).",
	"🏅 Semua poinmu menjadi POIN RANK. Kumpulkan untuk naik gelar dan membuka PET keren di TAMAN PET! 🐾",
}
for i, line in ipairs(helpLines) do
	Ui.text({ LayoutOrder = i, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false, TextSize = 19,
		Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Text = line, ZIndex = 5, Parent = helpBody })
end
local readyButton = Ui.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0.4, 0, 0.1, 0),
	Text = "Siap Belajar! 👍", BackgroundColor3 = T.Good, MaxTextSize = 26, ZIndex = 6 }, function()
	helpModal.Visible = false
end)
readyButton.Parent = helpModal
local function openHelp()
	closeAllModals()
	helpModal.Visible = true
	Ui.pop(helpModal, 0.85)
end
helpButton.Activated:Connect(openHelp)

---------------------------------------------------------------------
-- MODUL PET & PENDAFTARAN
---------------------------------------------------------------------
local ctx = {
	gui = gui,
	Ui = Ui,
	Theme = T,
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
		showToast("Fokus ke soal! 🧠", "Koleksi pet bisa dilihat setelah soal selesai.", T.Gold, 2)
		return
	end
	Pets.OpenMenu()
end)

ctx.onRegistered = function(message, asTeacher)
	showToast(asTeacher and "🎓 Halo, Guru!" or "👋 Selamat datang!", message, T.Good, 3)
	play("Correct")
	if not asTeacher then
		openHelp()
	end
end
Registration.Init(ctx)

---------------------------------------------------------------------
-- HASIL RONDE
---------------------------------------------------------------------
local resultsModal = makeModal("ModalHasil", "🏆 HASIL RONDE 🏆", 0.8, 0.8)
local resultsTitle = resultsModal:FindFirstChildOfClass("TextLabel")
local rankingList = Ui.new("ScrollingFrame", { Position = UDim2.new(0.03, 0, 0.13, 0), Size = UDim2.new(0.45, 0, 0.84, 0),
	BackgroundColor3 = T.Panel2, BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 5,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = resultsModal })
Ui.corner(rankingList, 10)
Ui.padding(rankingList, 8)
Ui.new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rankingList })
local personal = Ui.new("ScrollingFrame", { Position = UDim2.new(0.51, 0, 0.13, 0), Size = UDim2.new(0.46, 0, 0.84, 0),
	BackgroundColor3 = T.Panel2, BackgroundTransparency = 0.3, BorderSizePixel = 0, ScrollBarThickness = 5,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = resultsModal })
Ui.corner(personal, 10)
Ui.padding(personal, 10)
Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = personal })

local function personalLine(order, text, color, size)
	return Ui.text({ LayoutOrder = order, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextScaled = false,
		TextSize = size or 19, TextXAlignment = Enum.TextXAlignment.Left, Text = text, TextColor3 = color or T.Text,
		Font = Enum.Font.GothamBold, ZIndex = 5, Parent = personal })
end

local function showRanking(ranking)
	Ui.clear(rankingList)
	local medals = { "🥇", "🥈", "🥉" }
	for i, row in ipairs(ranking) do
		local isMe = row.userId == player.UserId
		local frame = Ui.new("Frame", { LayoutOrder = i, Size = UDim2.new(1, -4, 0, 38),
			BackgroundColor3 = isMe and Color3.fromRGB(70, 110, 220) or T.Panel, BorderSizePixel = 0, ZIndex = 5, Parent = rankingList })
		Ui.corner(frame, 8)
		Ui.text({ Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(0.66, -8, 1, -8), TextXAlignment = Enum.TextXAlignment.Left,
			Text = (medals[i] or (i .. ".")) .. "  " .. row.name, MaxTextSize = 19, ZIndex = 5, Parent = frame })
		Ui.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.new(0.34, 0, 1, -8),
			TextXAlignment = Enum.TextXAlignment.Right, Text = row.score .. " • " .. row.correct .. "/" .. row.total .. "✔",
			TextColor3 = T.Gold, MaxTextSize = 18, ZIndex = 5, Parent = frame })
	end
	if #ranking == 0 then
		Ui.text({ Size = UDim2.new(1, 0, 0, 40), Text = "Belum ada peserta.", ZIndex = 5, Parent = rankingList })
	end
end

local function showSummary(s)
	Ui.clear(personal)
	local accuracy = s.answered > 0 and math.floor(s.correct / s.answered * 100 + 0.5) or 0
	local medal = ({ "🥇", "🥈", "🥉" })[s.position] or "🎖"
	personalLine(1, medal .. " Peringkatmu: #" .. s.position .. " dari " .. s.players, T.Gold, 24)
	personalLine(2, "⭐ Skor: " .. s.score .. " poin")
	personalLine(3, "✔ Benar: " .. s.correct .. " dari " .. s.answered .. " soal (Nilai " .. accuracy .. ")")
	personalLine(4, "🔥 Streak terbaik: " .. s.bestStreak)
	local message
	if accuracy >= 90 then
		message = "Luar biasa! Kamu sudah menguasai materi ini! 🌟"
	elseif accuracy >= 70 then
		message = "Bagus sekali! Sedikit lagi jadi master! 💪"
	elseif accuracy >= 50 then
		message = "Lumayan! Baca lagi materinya, pasti bisa lebih baik! 📖"
	else
		message = "Jangan menyerah! Baca Zona Materi lalu coba lagi ya! 🚀"
	end
	personalLine(5, message, T.Good)
	if s.strongTopic then
		personalLine(6, "💪 Paling kuat: " .. s.strongTopic .. " (" .. s.strongText .. ")", Color3.fromRGB(150, 230, 255))
	end
	if s.weakTopic then
		personalLine(7, "📚 Perlu dipelajari lagi: " .. s.weakTopic .. " (" .. s.weakText .. ")", Color3.fromRGB(255, 170, 120))
		local study = Ui.button({ LayoutOrder = 8, Size = UDim2.new(1, -6, 0, 40), Text = "📖 Pelajari materi ini sekarang",
			BackgroundColor3 = Color3.fromRGB(40, 150, 110), ZIndex = 6 }, function()
			openMateri(s.weakId)
		end)
		study.Parent = personal
	end
	personalLine(9, "🏅 Poin Rank: " .. s.xp .. "   •   Gelar: " .. s.title, s.titleColor, 20)
	if s.nextTitle then
		personalLine(10, "➡ " .. (s.nextXp - s.xp) .. " Poin Rank lagi menuju gelar " .. s.nextTitle, T.Sub, 17)
	else
		personalLine(10, "👑 Kamu sudah mencapai gelar tertinggi!", T.Gold, 17)
	end
	if s.nextPetName then
		personalLine(11, "🐾 " .. (s.nextPetXp - s.xp) .. " Poin Rank lagi untuk membuka pet " .. s.nextPetName .. "!", T.Pink, 17)
	end
	if s.rankUp then
		personalLine(12, "🎉 NAIK GELAR! Selamat, kamu sekarang " .. s.title .. "!", T.Gold, 22)
		task.delay(1, function()
			showToast("🎉 NAIK GELAR! 🎉", "Gelar baru: " .. s.title, s.titleColor, 3.5)
			play("Fanfare")
		end)
	end
	if s.newPets and #s.newPets > 0 then
		local names = {}
		for _, pet in ipairs(s.newPets) do
			table.insert(names, pet.name)
		end
		personalLine(13, "🐾 PET BARU: " .. table.concat(names, ", ") .. "!", T.Pink, 22)
		task.delay(3, function()
			Pets.ShowUnlocked(s.newPets)
		end)
	end
end

---------------------------------------------------------------------
-- PANEL GURU
---------------------------------------------------------------------
local teacherToggle, teacherPanel, teacherRefresh
local rosterModal = makeModal("ModalSiswa", "📋 DAFTAR SISWA", 0.84, 0.84)
local rosterList = Ui.new("ScrollingFrame", { Position = UDim2.new(0.02, 0, 0.2, 0), Size = UDim2.new(0.96, 0, 0.77, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = rosterModal })
Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rosterList })
local rosterColumns = { { "Kelas", 0.09 }, { "Absen", 0.08 }, { "Nama", 0.33 }, { "Benar/Soal", 0.15 }, { "Nilai", 0.1 }, { "Poin Rank", 0.25 } }
local function rosterRow(parent, order, values, color, bold)
	local row = Ui.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 30), BackgroundColor3 = color or T.Panel2,
		BorderSizePixel = 0, ZIndex = 5, Parent = parent })
	Ui.corner(row, 6)
	local x = 0
	for i, column in ipairs(rosterColumns) do
		Ui.text({ Position = UDim2.new(x, 6, 0, 3), Size = UDim2.new(column[2], -8, 1, -6), Text = tostring(values[i]),
			TextXAlignment = Enum.TextXAlignment.Left, Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamMedium,
			MaxTextSize = 16, ZIndex = 5, Parent = row })
		x += column[2]
	end
	return row
end
local headerValues = {}
for i, column in ipairs(rosterColumns) do
	headerValues[i] = column[1]
end
local rosterHeader = rosterRow(rosterModal, 0, headerValues, Color3.fromRGB(70, 110, 220), true)
rosterHeader.Position = UDim2.new(0.02, 0, 0.12, 0)
rosterHeader.Size = UDim2.new(0.96, -8, 0, 30)

local function loadRoster()
	Ui.clear(rosterList)
	local ok, list = pcall(function()
		return remotes.GetRoster:InvokeServer()
	end)
	if not ok or type(list) ~= "table" then
		Ui.text({ Size = UDim2.new(1, 0, 0, 30), Text = "Gagal memuat daftar siswa.", ZIndex = 5, Parent = rosterList })
		return
	end
	for i, s in ipairs(list) do
		local nilai = s.answered > 0 and math.floor(s.correct / s.answered * 100 + 0.5) or 0
		rosterRow(rosterList, i, { s.kelas, string.format("%02d", s.absen), s.nama, s.correct .. "/" .. s.answered, nilai,
			s.xp .. " (" .. s.title .. ")" }, i % 2 == 0 and T.Panel or T.Panel2)
	end
	if #list == 0 then
		Ui.text({ Size = UDim2.new(1, 0, 0, 30), Text = "Belum ada siswa yang mendaftar.", ZIndex = 5, Parent = rosterList })
	end
end
local refreshRoster = Ui.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 10), Size = UDim2.new(0, 130, 0, 40),
	Text = "🔄 Muat ulang", BackgroundColor3 = T.Accent, ZIndex = 6, MaxTextSize = 16 }, loadRoster)
refreshRoster.Parent = rosterModal

local function TeacherCommand(command, value)
	remotes.TeacherCommand:FireServer(command, value)
end

local function buildTeacherPanel()
	if teacherPanel then
		return
	end
	teacherToggle = Ui.button({ Name = "TombolGuru", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.24, 0),
		Size = UDim2.new(0, 150, 0, 40), Text = "🎓 Panel Guru", BackgroundColor3 = Color3.fromRGB(230, 130, 40) })
	teacherToggle.Parent = gui

	teacherPanel = Ui.panel({ Name = "PanelGuru", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 10, 0.24, 26),
		Size = UDim2.new(0, 280, 0, 498), Visible = false, Parent = gui })
	addPixelScale(teacherPanel)
	Ui.padding(teacherPanel, 10)
	Ui.new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = teacherPanel })
	Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), Text = "🎓 PANEL GURU", Font = Enum.Font.FredokaOne,
		TextColor3 = T.Gold, MaxTextSize = 24, Parent = teacherPanel })

	local function row(order, labelText)
		local frame = Ui.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
			Parent = teacherPanel })
		Ui.text({ Size = UDim2.new(0.34, 0, 1, 0), Text = labelText, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.Sub, MaxTextSize = 15, Parent = frame })
		return frame
	end
	local function currentSetting(key, default)
		return state.settings and state.settings[key] or default
	end
	local function cycleButton(frame, list, key, command)
		local button = Ui.button({ Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.64, 0, 1, 0), Text = "",
			BackgroundColor3 = T.Panel2, MaxTextSize = 14 }, function()
			local currentId = currentSetting(key, list[1].id)
			local index = 1
			for i, item in ipairs(list) do
				if item.id == currentId then
					index = i
				end
			end
			TeacherCommand(command, list[index % #list + 1].id)
		end)
		button.Parent = frame
		return button
	end
	local function stepper(frame, onMinus, onPlus)
		local minus = Ui.button({ Position = UDim2.new(0.36, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), Text = "−",
			BackgroundColor3 = T.Panel2 }, onMinus)
		minus.Parent = frame
		local value = Ui.text({ Position = UDim2.new(0.56, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), MaxTextSize = 20, Parent = frame })
		local plus = Ui.button({ Position = UDim2.new(0.82, 0, 0, 0), Size = UDim2.new(0.18, 0, 1, 0), Text = "+",
			BackgroundColor3 = T.Panel2 }, onPlus)
		plus.Parent = frame
		return value
	end

	local modeButton = cycleButton(row(2, "Mode"), Config.Modes, "mode", "mode")
	local topicButton = cycleButton(row(3, "Topik"), Config.Topics, "topic", "topic")
	local countValue = stepper(row(4, "Jumlah soal"), function()
		TeacherCommand("count", math.max(5, currentSetting("count", 10) - 5))
	end, function()
		TeacherCommand("count", math.min(30, currentSetting("count", 10) + 5))
	end)
	local timeValue = stepper(row(5, "Waktu/soal"), function()
		TeacherCommand("time", math.max(5, currentSetting("time", 20) - 5))
	end, function()
		TeacherCommand("time", math.min(60, currentSetting("time", 20) + 5))
	end)
	local autoButton = Ui.button({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 32), Text = "", BackgroundColor3 = T.Panel2 }, function()
		TeacherCommand("auto", not currentSetting("auto", true))
	end)
	autoButton.Parent = teacherPanel

	local buttons = {
		{ 7, "▶  MULAI KUIS SEKARANG", T.Good, function() TeacherCommand("start") end },
		{ 8, "⏩  KUNCI JAWABAN / AKHIRI BALAPAN", Color3.fromRGB(230, 170, 40), function() TeacherCommand("lock") end },
		{ 9, "⏹  HENTIKAN RONDE", T.Bad, function() TeacherCommand("stop") end },
		{ 10, "📋  DAFTAR SISWA & NILAI", T.Accent, function()
			closeAllModals()
			rosterModal.Visible = true
			loadRoster()
		end },
		{ 11, "🖨  CETAK REKAP KE OUTPUT (F9)", Color3.fromRGB(90, 100, 140), function()
			TeacherCommand("recap")
			showToast("🖨 Rekap dicetak", "Buka Developer Console (F9) > Server untuk menyalin rekap nilai.", T.Gold, 3.5)
		end },
	}
	for _, info in ipairs(buttons) do
		local button = Ui.button({ LayoutOrder = info[1], Size = UDim2.new(1, 0, 0, 38), Text = info[2], BackgroundColor3 = info[3],
			MaxTextSize = 15 }, info[4])
		button.Parent = teacherPanel
	end
	Ui.text({ LayoutOrder = 12, Size = UDim2.new(1, 0, 0, 30), Text = "Pengaturan baru berlaku di ronde berikutnya.",
		TextColor3 = T.Sub, Font = Enum.Font.Gotham, MaxTextSize = 13, Parent = teacherPanel })

	teacherToggle.Activated:Connect(function()
		teacherPanel.Visible = not teacherPanel.Visible
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
		autoButton.Text = settings.auto and "🔁 Mulai otomatis: ON" or "✋ Mulai otomatis: OFF (manual)"
		autoButton.BackgroundColor3 = settings.auto and Color3.fromRGB(40, 140, 100) or T.Panel2
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
-- TAMPILAN PER FASE
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
	scoreLabel.Text = "⭐ " .. state.score
	streakLabel.Text = "🔥 Streak " .. state.streak
	hintButton.Text = (state.kind == "ISIAN" and "💡 Petunjuk (" or "💡 50:50 (") .. state.hints .. ")"
	hintButton.BackgroundColor3 = hintUsable() and Color3.fromRGB(150, 90, 255) or Color3.fromRGB(70, 65, 100)
	updateRankHud()
end

local function hideRoundUi()
	questionPanel.Visible = false
	optionsBar.Visible = false
	sandiPanel.Visible = false
	explain.Visible = false
	countdownLabel.Visible = false
	introCard.Visible = false
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
	optionsLimit.MaxSize = clickable and Vector2.new(1000, 170) or Vector2.new(1000, 120)
	optionsBar.Size = clickable and UDim2.new(0.7, 0, 0.18, 0) or UDim2.new(0.66, 0, 0.13, 0)
	for i, card in ipairs(cards) do
		local option = options[i]
		card.frame.Visible = option ~= nil
		card.frame.AutoButtonColor = clickable
		card.frame.Active = clickable
		card.you.Visible = false
		card.stroke.Thickness = 0
		card.count.Text = ""
		card.frame.BackgroundTransparency = 0
		card.text.TextTransparency = 0
		card.letter.TextTransparency = 0
		if option then
			card.frame.BackgroundColor3 = option.color
			card.letter.Text = option.letter
			card.text.Text = option.text
			card.frame.Size = #options == 2 and UDim2.new(0.4, -4, 1, 0) or UDim2.new(0.25, -6, 1, 0)
		end
	end
end

local function showBanner(title, sub)
	banner.Visible = true
	bannerTitle.Text = title
	bannerSub.Text = sub or ""
end

local function lobbySubtitle()
	local s = state.settings
	if not s then
		return "Baca ZONA MATERI & kunjungi TAMAN PET sambil menunggu!"
	end
	return s.modeName .. "  •  " .. s.topicName .. "  •  Baca ZONA MATERI & lihat TAMAN PET!"
end

local function showQuestionPanel(msg, counterText)
	questionPanel.Visible = true
	topicChip.Text = msg.topicName
	topicChip.TextColor3 = msg.topicColor
	counterLabel.Text = counterText
	questionText.Text = msg.text
	bossBadge.Visible = msg.isBoss == true
	questionStroke.Color = msg.isBoss and T.Bad or msg.topicColor
	questionStroke.Transparency = 0
	choiceHint.Text = ""
	Ui.pop(questionPanel, 0.85)
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

function handlers.Waiting(msg)
	state.mode = "waiting"
	hideRoundUi()
	showBanner(msg.reason == "teacher" and "✋ Menunggu guru memulai kuis..." or "📝 Menunggu siswa mendaftar...", lobbySubtitle())
end

function handlers.Intermission(msg)
	state.mode = "intermission"
	state.endsAt = msg.endsAt
	hideRoundUi()
	showBanner("⏳ Kuis dimulai sebentar lagi", lobbySubtitle())
end

function handlers.ModeIntro(msg)
	state.mode = "intro"
	state.endsAt = msg.endsAt
	state.lastSecond = -1
	state.options = {}
	closeAllModals()
	hideRoundUi()
	banner.Visible = false
	introName.Text = msg.modeName
	introName.TextColor3 = msg.color
	introStroke.Color = msg.color
	introDesc.Text = msg.desc
	introInfo.Text = msg.topicName .. "  •  " .. msg.total .. " soal"
	introCard.Visible = true
	Ui.pop(introCard, 0.6)
	countdownLabel.Visible = true
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
	banner.Visible = false
	explain.Visible = false
	introCard.Visible = false
	countdownLabel.Visible = false
end

function handlers.Question(msg)
	beginQuestion(msg)
	state.mode = "question"
	state.endsAt = msg.endsAt
	state.duration = msg.duration
	state.lastSecond = -1
	state.clickable = msg.clickable == true
	state.sandiDone = false
	showQuestionPanel(msg, "Soal " .. msg.index .. " / " .. msg.total)

	if msg.kind == "ISIAN" then
		optionsBar.Visible = false
		sandiPanel.Visible = true
		alphabet.Visible = msg.isCipher == true
		sandiBox.Text = ""
		sandiHint.Text = ""
		sandiInfo.TextColor3 = T.Sub
		sandiInfo.Text = "Kamu punya " .. (msg.attempts or 3) .. " kesempatan. Tekan Enter atau Kirim."
		setSandiEnabled(true)
		choiceHint.Text = msg.isCipher and "🔐 Geser setiap huruf MUNDUR untuk membaca kata aslinya!" or "⌨ Ketik jawaban singkat di kotak bawah!"
		choiceHint.TextColor3 = T.Sub
	else
		sandiPanel.Visible = false
		setupCards(state.options, state.clickable)
		optionsBar.Visible = true
		if state.clickable then
			choiceHint.Text = "👆 Tekan jawaban di bawah secepat mungkin!"
			choiceHint.TextColor3 = T.Gold
		end
	end
	updateHud()
	play("Question")
	if msg.isBoss then
		showToast("⚠ SOAL BOS ⚠", "Poin dikali " .. Config.BossMultiplier .. "! Fokus!", T.Bad, 2)
	end
end

function handlers.Race(msg)
	state.mode = "race"
	state.raceEndsAt = msg.endsAt
	state.raceDuration = math.max(1, msg.endsAt - serverNow())
	state.lastSecond = -1
	closeAllModals()
	hideRoundUi()
	banner.Visible = false
	showToast("🧱 BALAPAN DIMULAI! 🧱", "Masuk ke PINTU jawaban yang benar!", T.Gold, 2.5)
	play("Correct")
end

function handlers.Gate(msg)
	beginQuestion(msg)
	state.mode = "race"
	state.gate = msg.index
	state.clickable = false
	showQuestionPanel(msg, "🚪 Gerbang " .. msg.index .. " / " .. msg.total)
	choiceHint.Text = "🚪 Masuk ke PINTU jawaban yang benar! Pintu salah = jatuh!"
	choiceHint.TextColor3 = T.Gold
	sandiPanel.Visible = false
	setupCards(state.options, false)
	optionsBar.Visible = true
	updateHud()
end

function handlers.GateDone()
	state.gate = nil
	state.options = {}
	questionText.Text = "🏁 Semua gerbang sudah kamu lewati! Lompat terus ke FINISH!"
	counterLabel.Text = "Menuju FINISH"
	choiceHint.Text = ""
	optionsBar.Visible = false
	updateHud()
end

function handlers.Finished(msg)
	showFeed("🏁 " .. msg.name .. " mencapai FINISH urutan ke-" .. msg.place .. "!")
end

function handlers.RaceEnd(msg)
	state.mode = "explain"
	state.gate = nil
	hideRoundUi()
	local top = {}
	for i = 1, math.min(3, #msg.finishers) do
		table.insert(top, msg.finishers[i])
	end
	showToast("⏱ BALAPAN SELESAI!", #top > 0 and table.concat(top, "   ") or "Belum ada yang mencapai finish.", T.Gold, 3)
end

function handlers.AnswerLocked(msg)
	state.locked = true
	for i, option in ipairs(state.options) do
		local card = cards[i]
		if option.pad == msg.pad then
			card.stroke.Thickness = 5
			card.you.Text = "✔ PILIHANMU"
			card.you.Visible = true
			Ui.pop(card.frame, 1.1)
			choiceHint.Text = "✔ Jawabanmu terkunci: " .. option.letter .. ". " .. option.text
			choiceHint.TextColor3 = T.Good
		else
			card.frame.BackgroundTransparency = 0.6
		end
	end
	updateHud()
end

function handlers.Stats(msg)
	state.score, state.streak, state.hints = msg.score, msg.streak, msg.hints
	updateHud()
end

local cheers = { "BENAR! 🎉", "MANTAP! 🔥", "HEBAT! ⭐", "KEREN! 😎", "JENIUS! 🧠" }
function handlers.Result(msg)
	state.score, state.streak, state.hints = msg.score, msg.streak, msg.hints
	if state.mode == "question" and state.kind ~= "ISIAN" then
		state.mode = "explain"
	end
	if msg.correct then
		local sub = "+" .. msg.gained .. " poin"
		if msg.streak >= 2 then
			sub ..= "  •  🔥 Streak x" .. msg.streak
		end
		if msg.earnedHint then
			sub ..= "  •  💡 Dapat bantuan!"
			task.delay(0.4, function()
				play("Hint")
			end)
		end
		showToast(cheers[math.random(1, #cheers)], sub, T.Good, 2.4)
		flashScreen(T.Good)
		play("Correct")
	elseif msg.answered then
		showToast("SALAH 😅", msg.gate and "Kamu jatuh! Coba pintu lain." or "Tidak apa-apa! Baca penjelasannya ya.", T.Bad, 2.4)
		flashScreen(T.Bad)
		play("Wrong")
	else
		showToast("WAKTU HABIS ⏰", "Kamu belum menjawab soal ini.", T.Gold, 2.4)
		flashScreen(T.Gold)
		play("Wrong")
	end
	if msg.gate and msg.explanation then
		-- Lintasan Firewall: penjelasan pribadi untuk gerbang ini
		explain.Position = UDim2.new(0.5, 0, 0.86, -16)
		local answer = msg.correctLetter .. ". " .. msg.correctText
		showExplain(msg.correct and ("✔ Gerbang " .. msg.gate .. " benar: " .. answer) or ("✖ Jawaban benar gerbang " .. msg.gate
			.. ": " .. answer), msg.correct and T.Good or T.Bad, msg.explanation, serverNow() + (msg.correct and 4 or 6))
	end
	scoreLabel.TextColor3 = msg.correct and T.Good or T.Gold
	Ui.pop(scoreLabel, 1.4)
	task.delay(0.6, function()
		scoreLabel.TextColor3 = T.Gold
	end)
	updateHud()
end

function handlers.Bonus(msg)
	state.score = msg.score
	showToast("+" .. msg.amount .. " BONUS! 🎁", msg.reason, T.Gold, 3)
	play("Fanfare")
	updateHud()
end

function handlers.Reveal(msg)
	state.mode = "explain"
	restoreLocalPads()
	choiceHint.Text = ""
	timerNumber.Text = "✔"
	if state.kind == "ISIAN" then
		setSandiEnabled(false)
		sandiInfo.TextColor3 = T.Good
		sandiInfo.Text = "✔ Jawaban: " .. msg.correctText .. "   •   " .. (msg.solved or 0) .. " siswa berhasil"
		showExplain("✔ Jawaban: " .. msg.correctText, T.Good, msg.explanation, msg.explainEndsAt)
		explain.Position = UDim2.new(0.5, 0, 1, -180)
	else
		explain.Position = UDim2.new(0.5, 0, 0.86, -16)
		for i, option in ipairs(state.options) do
			local card = cards[i]
			card.count.Text = "👥 " .. (msg.counts[option.pad] or 0)
			if option.pad == msg.correctPad then
				card.stroke.Thickness = 4
				card.frame.BackgroundTransparency = 0
				Ui.pop(card.frame, 1.15)
			else
				card.stroke.Thickness = 0
				card.frame.BackgroundTransparency = 0.65
				card.text.TextTransparency = 0.5
			end
		end
		local prefix = state.kind == "PG" and (msg.correctLetter .. ". ") or ""
		showExplain("✔ Jawaban benar: " .. prefix .. msg.correctText, T.Good, msg.explanation, msg.explainEndsAt)
	end
	updateHud()
end

function handlers.RoundEnd(msg)
	state.mode = "results"
	state.options = {}
	state.gate = nil
	hideRoundUi()
	banner.Visible = false
	closeAllModals()
	if resultsTitle then
		resultsTitle.Text = "🏆 HASIL RONDE • " .. (msg.modeName or "") .. " 🏆"
	end
	showRanking(msg.ranking)
	Ui.clear(personal)
	personalLine(1, "Kamu belum ikut menjawab di ronde ini. Ikut ronde berikutnya ya! 😊", T.Sub)
	resultsModal.Visible = true
	Ui.pop(resultsModal, 0.8)
	play("Fanfare")
	if msg.ranking[1] then
		showToast("🏆 " .. msg.ranking[1].name .. " 🏆", "Juara ronde ini dengan " .. msg.ranking[1].score .. " poin!", T.Gold, 4)
	end
end

function handlers.Summary(msg)
	showSummary(msg)
end

function handlers.Stopped()
	state.mode = "idle"
	state.options = {}
	state.gate = nil
	restoreLocalPads()
	hideRoundUi()
	showToast("⏹ Kuis dihentikan", "Guru menghentikan ronde ini.", T.Gold, 3)
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
			showToast("💡 Bantuan habis", "Jawab benar " .. Config.HintEveryStreak .. "x berturut-turut untuk dapat lagi.", T.Gold, 2)
		else
			showToast("💡 Belum bisa", "Bantuan dipakai saat soal sedang berlangsung.", T.Gold, 2)
		end
		return
	end
	local ok, result, info = pcall(function()
		return remotes.UseHint:InvokeServer()
	end)
	if not ok or type(result) ~= "table" then
		showToast("💡 Bantuan", (ok and info) or "Coba lagi.", T.Gold, 2.2)
		return
	end
	state.hints = info
	state.hintUsed = true
	play("Hint")
	if result.type == "huruf" then
		sandiHint.Text = "💡 Petunjuk: " .. result.text
		showToast("💡 Petunjuk!", result.text, Color3.fromRGB(190, 150, 255), 2)
	else
		for _, padIndex in ipairs(result.pads) do
			state.hiddenPads[padIndex] = true
			local card = cardForPad(padIndex)
			if card then
				card.frame.BackgroundTransparency = 0.75
				card.text.TextTransparency = 0.6
				card.letter.Text = "✖"
			end
			if result.gate then
				local sign = arenaChild("LintasanFirewall/Gerbang" .. result.gate .. "/Tanda" .. padIndex)
				if sign then
					sign.Color = Color3.fromRGB(55, 55, 60)
					local answer = sign:FindFirstChild("Gui") and sign.Gui:FindFirstChild("Jawaban")
					if answer then
						answer.Text = "✖ SALAH"
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
		showToast("💡 50:50!", "2 jawaban salah sudah dihapus. Pilih dengan teliti!", Color3.fromRGB(190, 150, 255), 2)
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
	local color = T.Bad:Lerp(T.Good, ratio)
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
			Ui.pop(timerCircle, 1.25)
		end
		if not state.clickable and state.kind ~= "ISIAN" and os.clock() - lastPositionCheck > 0.1 then
			lastPositionCheck = os.clock()
			local pad = padUnderMe()
			if pad ~= state.myPad then
				state.myPad = pad
				for _, card in ipairs(cards) do
					card.you.Visible = false
					card.stroke.Thickness = 0
				end
				local card = pad and cardForPad(pad)
				if card then
					card.you.Text = "📍 POSISIMU"
					card.you.Visible = true
					card.stroke.Thickness = 4
					Ui.pop(card.frame, 1.1)
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
				choiceHint.Text = "📍 Jawabanmu: " .. letter .. option.text
				choiceHint.TextColor3 = state.hiddenPads[pad] and T.Bad or T.Gold
			elseif left <= 5 then
				choiceHint.Text = (math.floor(t * 3) % 2 == 0) and "⚠ CEPAT! Berdiri di kotak jawaban!" or ""
				choiceHint.TextColor3 = T.Bad
			else
				choiceHint.Text = "🏃 Lari ke kotak jawaban pilihanmu!"
				choiceHint.TextColor3 = T.Sub
			end
		end
	elseif state.mode == "race" then
		local raceLeft = math.max(0, state.raceEndsAt - t)
		local changed = setTimer(raceLeft, state.raceDuration)
		if changed and changed <= 10 and changed > 0 then
			play("Tick")
		end
	elseif state.mode == "intermission" then
		bannerTitle.Text = "⏳ Kuis dimulai dalam " .. math.ceil(left) .. " detik"
	elseif state.mode == "intro" then
		local seconds = math.ceil(left)
		if seconds ~= state.lastSecond then
			state.lastSecond = seconds
			countdownLabel.Text = seconds > 0 and tostring(seconds) or "MULAI! 🚀"
			Ui.pop(countdownLabel, 1.6)
			if seconds <= 3 then
				play(seconds > 0 and "Tick" or "Correct")
			end
		end
	end

	if explain.Visible then
		local explainLeft = state.explainEndsAt - t
		explainFill.Size = UDim2.fromScale(math.clamp(explainLeft / state.explainDuration, 0, 1), 1)
		if explainLeft <= -0.5 and state.mode ~= "explain" then
			explain.Visible = false
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
