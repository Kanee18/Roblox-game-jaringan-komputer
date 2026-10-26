--[[
	NET QUEST - Client (tampilan di layar pemain)
	Menampilkan: soal & timer, kartu jawaban, poin/streak, efek benar/salah,
	penjelasan materi, hasil ronde, Zona Materi, Cara Main, dan Panel Guru.
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
local Ui = require(script:WaitForChild("Ui"))
local T = Ui.Theme

local remotes = ReplicatedStorage:WaitForChild("QuizRemotes")
local QuizEvent = remotes:WaitForChild("QuizEvent")
local TeacherEvent = remotes:WaitForChild("TeacherCommand")
local ReadyEvent = remotes:WaitForChild("ClientReady")
local HintFunction = remotes:WaitForChild("UseHint")

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local state = {
	mode = "idle", -- idle / waiting / intermission / countdown / question / explain / results
	endsAt = 0,
	duration = 1,
	lastSecond = -1,
	options = {},
	kind = "PG",
	myPad = nil,
	hints = 0,
	hintUsed = false,
	score = 0,
	streak = 0,
	settings = nil,
	hiddenPads = {},
	savedPadColors = {},
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

-- Kilatan layar (hijau = benar, merah = salah)
local flash = Ui.new("Frame", { Name = "Kilat", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Good,
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })
local function flashScreen(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.55
	Ui.tween(flash, 0.8, { BackgroundTransparency = 1 })
end

---------------------------------------------------------------------
-- BANNER LOBI
---------------------------------------------------------------------
local banner = Ui.panel({ Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.new(0.5, 0, 0.13, 0), Visible = false, Parent = gui })
Ui.sizeLimit(banner, Vector2.new(300, 70), Vector2.new(760, 120))
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
local timerNumber = Ui.text({ Size = UDim2.fromScale(1, 1), Font = Enum.Font.FredokaOne, MaxTextSize = 40, Parent = timerCircle })

---------------------------------------------------------------------
-- KARTU JAWABAN (bawah)
---------------------------------------------------------------------
local optionsBar = Ui.new("Frame", { Name = "KartuJawaban", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.66, 0, 0.13, 0), BackgroundTransparency = 1, Visible = false, Parent = gui })
Ui.sizeLimit(optionsBar, Vector2.new(320, 64), Vector2.new(1000, 120))
Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = optionsBar })

local cards = {}
for i = 1, 4 do
	local card = Ui.new("Frame", { Name = "Kartu" .. i, LayoutOrder = i, Size = UDim2.new(0.25, -6, 1, 0),
		BackgroundColor3 = Config.PadColors[i], BorderSizePixel = 0, Parent = optionsBar })
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
	cards[i] = { frame = card, stroke = stroke, letter = letter, text = text, count = count, you = youTag }
end

---------------------------------------------------------------------
-- HUD KANAN (poin, streak, tombol)
---------------------------------------------------------------------
local hud = Ui.panel({ Name = "HUD", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.48, 0),
	Size = UDim2.new(0, 170, 0, 236), Parent = gui })
addPixelScale(hud)
Ui.padding(hud, 8)
Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = hud })
local scoreLabel = Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), Text = "⭐ 0", Font = Enum.Font.FredokaOne,
	TextColor3 = T.Gold, MaxTextSize = 30, Parent = hud })
local streakLabel = Ui.text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 24), Text = "🔥 Streak 0", TextColor3 = Color3.fromRGB(255, 160, 80),
	MaxTextSize = 20, Parent = hud })
local hintButton, materiButton, helpButton
local function useHint() end -- diisi di bawah
hintButton = Ui.button({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 40), Text = "💡 50:50 (0)",
	BackgroundColor3 = Color3.fromRGB(150, 90, 255) }, function()
	useHint()
end)
hintButton.Parent = hud
materiButton = Ui.button({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 40), Text = "📚 Materi", BackgroundColor3 = Color3.fromRGB(40, 150, 110) })
materiButton.Parent = hud
helpButton = Ui.button({ LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 40), Text = "❓ Cara Main", BackgroundColor3 = Color3.fromRGB(60, 90, 170) })
helpButton.Parent = hud

---------------------------------------------------------------------
-- TOAST (teks besar di tengah) & HITUNG MUNDUR
---------------------------------------------------------------------
local toast = Ui.new("Frame", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.45, 0),
	Size = UDim2.new(0.7, 0, 0.2, 0), BackgroundTransparency = 1, Visible = false, Parent = gui })
local toastTitle = Ui.text({ Size = UDim2.fromScale(1, 0.62), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0,
	TextStrokeColor3 = T.Panel, MaxTextSize = 80, Parent = toast })
local toastSub = Ui.text({ Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.36), TextStrokeTransparency = 0.2,
	TextStrokeColor3 = T.Panel, MaxTextSize = 28, Parent = toast })
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

local countdownLabel = Ui.text({ Name = "HitungMundur", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromScale(0.5, 0.3), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0, TextStrokeColor3 = T.Panel,
	TextColor3 = T.Gold, Visible = false, MaxTextSize = 150, Parent = gui })

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
	if state.mode == "question" then
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
local helpModal = makeModal("ModalCaraMain", "❓ CARA MAIN NET QUEST", 0.7, 0.78)
local helpBody = Ui.new("ScrollingFrame", { Position = UDim2.new(0.04, 0, 0.13, 0), Size = UDim2.new(0.92, 0, 0.7, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = helpModal })
Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = helpBody })
local helpLines = {
	"1️⃣  Baca soal di LAYAR BESAR atau di bagian atas layarmu.",
	"2️⃣  LARI dan BERDIRI di kotak jawaban (A / B / C / D atau BENAR / SALAH) sebelum waktu habis.",
	"3️⃣  Saat waktu habis, kotak yang salah akan JATUH! Tenang, kamu kembali ke Garis Start dan tetap ikut kuis.",
	"4️⃣  Jawab lebih CEPAT = bonus poin. Benar berturut-turut = bonus STREAK 🔥",
	"5️⃣  Benar 3x berturut-turut = dapat bantuan 💡 50:50 yang menghapus 2 jawaban salah.",
	"6️⃣  Soal terakhir adalah ⚠ SOAL BOS ⚠ dengan poin x2!",
	"7️⃣  Baca PENJELASAN setelah setiap soal dan papan ZONA MATERI di lobi (tekan E / ketuk papan).",
	"8️⃣  Kumpulkan XP untuk naik gelar: Kabel Pemula → Hub Junior → Switch Cekatan → Router Hebat → Server Master → Legenda Internet!",
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
helpButton.Activated:Connect(function()
	closeAllModals()
	helpModal.Visible = true
	Ui.pop(helpModal, 0.85)
end)

---------------------------------------------------------------------
-- HASIL RONDE
---------------------------------------------------------------------
local resultsModal = makeModal("ModalHasil", "🏆 HASIL RONDE 🏆", 0.8, 0.8)
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
		Ui.text({ Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(0.68, -8, 1, -8), TextXAlignment = Enum.TextXAlignment.Left,
			Text = (medals[i] or (i .. ".")) .. "  " .. row.name, MaxTextSize = 20, ZIndex = 5, Parent = frame })
		Ui.text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.new(0.32, 0, 1, -8),
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
	personalLine(3, "✔ Benar: " .. s.correct .. " dari " .. s.answered .. " soal (" .. accuracy .. "%)")
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
	personalLine(9, "🎖 Gelar: " .. s.title .. "   •   XP: " .. s.xp, s.titleColor, 20)
	if s.nextTitle then
		personalLine(10, "➡ " .. (s.nextXp - s.xp) .. " XP lagi menuju gelar " .. s.nextTitle, T.Sub, 17)
	else
		personalLine(10, "👑 Kamu sudah mencapai gelar tertinggi!", T.Gold, 17)
	end
	if s.rankUp then
		personalLine(11, "🎉 NAIK GELAR! Selamat, kamu sekarang " .. s.title .. "!", T.Gold, 22)
		task.delay(1, function()
			showToast("🎉 NAIK GELAR! 🎉", "Gelar baru: " .. s.title, s.titleColor, 3.5)
			play("Fanfare")
		end)
	end
end

---------------------------------------------------------------------
-- PANEL GURU
---------------------------------------------------------------------
local teacherToggle, teacherPanel, teacherRefresh
local function buildTeacherPanel()
	if teacherPanel then
		return
	end
	teacherToggle = Ui.button({ Name = "TombolGuru", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.3, 0),
		Size = UDim2.new(0, 150, 0, 40), Text = "🎓 Panel Guru", BackgroundColor3 = Color3.fromRGB(230, 130, 40) })
	teacherToggle.Parent = gui

	teacherPanel = Ui.panel({ Name = "PanelGuru", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 10, 0.3, 26),
		Size = UDim2.new(0, 270, 0, 372), Visible = false, Parent = gui })
	addPixelScale(teacherPanel)
	Ui.padding(teacherPanel, 10)
	Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = teacherPanel })
	Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), Text = "🎓 PANEL GURU", Font = Enum.Font.FredokaOne,
		TextColor3 = T.Gold, MaxTextSize = 24, Parent = teacherPanel })

	local function row(order, labelText)
		local frame = Ui.new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
			Parent = teacherPanel })
		Ui.text({ Size = UDim2.new(0.38, 0, 1, 0), Text = labelText, TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.Sub, MaxTextSize = 16, Parent = frame })
		return frame
	end
	local function stepper(frame, onMinus, onPlus)
		local minus = Ui.button({ Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.16, 0, 1, 0), Text = "−",
			BackgroundColor3 = T.Panel2 }, onMinus)
		minus.Parent = frame
		local value = Ui.text({ Position = UDim2.new(0.58, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0), MaxTextSize = 20, Parent = frame })
		local plus = Ui.button({ Position = UDim2.new(0.84, 0, 0, 0), Size = UDim2.new(0.16, 0, 1, 0), Text = "+",
			BackgroundColor3 = T.Panel2 }, onPlus)
		plus.Parent = frame
		return value
	end

	local topicRow = row(2, "Topik")
	local topicButton = Ui.button({ Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = "",
		BackgroundColor3 = T.Panel2, MaxTextSize = 15 }, function()
		local settings = state.settings
		if not settings then
			return
		end
		local index = 1
		for i, topic in ipairs(Config.Topics) do
			if topic.id == settings.topic then
				index = i
			end
		end
		local nextTopic = Config.Topics[index % #Config.Topics + 1]
		TeacherEvent:FireServer("topic", nextTopic.id)
	end)
	topicButton.Parent = topicRow

	local function currentSetting(key, default)
		return state.settings and state.settings[key] or default
	end
	local countValue = stepper(row(3, "Jumlah soal"), function()
		TeacherEvent:FireServer("count", math.max(5, currentSetting("count", 10) - 5))
	end, function()
		TeacherEvent:FireServer("count", math.min(30, currentSetting("count", 10) + 5))
	end)
	local timeValue = stepper(row(4, "Waktu/soal"), function()
		TeacherEvent:FireServer("time", math.max(5, currentSetting("time", 20) - 5))
	end, function()
		TeacherEvent:FireServer("time", math.min(60, currentSetting("time", 20) + 5))
	end)

	local autoButton = Ui.button({ LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 34), Text = "", BackgroundColor3 = T.Panel2 }, function()
		TeacherEvent:FireServer("auto", not (state.settings and state.settings.auto))
	end)
	autoButton.Parent = teacherPanel

	local startButton = Ui.button({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 40), Text = "▶  MULAI KUIS SEKARANG",
		BackgroundColor3 = T.Good }, function()
		TeacherEvent:FireServer("start")
	end)
	startButton.Parent = teacherPanel
	local lockButton = Ui.button({ LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 40), Text = "⏩  KUNCI JAWABAN SEKARANG",
		BackgroundColor3 = Color3.fromRGB(230, 170, 40) }, function()
		TeacherEvent:FireServer("lock")
	end)
	lockButton.Parent = teacherPanel
	local stopButton = Ui.button({ LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 40), Text = "⏹  HENTIKAN RONDE",
		BackgroundColor3 = T.Bad }, function()
		TeacherEvent:FireServer("stop")
	end)
	stopButton.Parent = teacherPanel
	Ui.text({ LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 40), Text = "Pengaturan baru berlaku di ronde berikutnya.",
		TextColor3 = T.Sub, Font = Enum.Font.Gotham, MaxTextSize = 14, Parent = teacherPanel })

	teacherToggle.Activated:Connect(function()
		teacherPanel.Visible = not teacherPanel.Visible
	end)

	teacherRefresh = function()
		local settings = state.settings
		if not settings then
			return
		end
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
-- KOTAK JAWABAN 3D (deteksi posisi & efek 50:50 lokal)
---------------------------------------------------------------------
local function getPad(index)
	local arena = workspace:FindFirstChild("ArenaKuis")
	local folder = arena and arena:FindFirstChild("KotakJawaban")
	return folder and folder:FindFirstChild("Pad" .. index)
end

local function padUnderMe()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	for _, option in ipairs(state.options) do
		local pad = getPad(option.pad)
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
		local pad = getPad(index)
		if pad then
			pad.Color = color
		end
	end
	state.savedPadColors = {}
end

---------------------------------------------------------------------
-- TAMPILAN PER FASE
---------------------------------------------------------------------
local function updateHud()
	scoreLabel.Text = "⭐ " .. state.score
	streakLabel.Text = "🔥 Streak " .. state.streak
	hintButton.Text = "💡 50:50 (" .. state.hints .. ")"
	local usable = state.mode == "question" and state.kind == "PG" and state.hints > 0 and not state.hintUsed
	hintButton.BackgroundColor3 = usable and Color3.fromRGB(150, 90, 255) or Color3.fromRGB(70, 65, 100)
end

local function hideRoundUi()
	questionPanel.Visible = false
	optionsBar.Visible = false
	explain.Visible = false
	countdownLabel.Visible = false
end

local function cardForPad(pad)
	for i, option in ipairs(state.options) do
		if option.pad == pad then
			return cards[i]
		end
	end
	return nil
end

local function setupCards(options)
	for i, card in ipairs(cards) do
		local option = options[i]
		card.frame.Visible = option ~= nil
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
		return "Baca ZONA MATERI di lobi sambil menunggu!"
	end
	return "Topik: " .. s.topicName .. "  •  " .. s.count .. " soal  •  Baca ZONA MATERI sambil menunggu!"
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

function handlers.Waiting(msg)
	state.mode = "waiting"
	hideRoundUi()
	showBanner(msg.reason == "teacher" and "✋ Menunggu guru memulai kuis..." or "👋 Menunggu pemain lain...", lobbySubtitle())
end

function handlers.Intermission(msg)
	state.mode = "intermission"
	state.endsAt = msg.endsAt
	hideRoundUi()
	showBanner("⏳ Kuis dimulai sebentar lagi", lobbySubtitle())
end

function handlers.Countdown(msg)
	state.mode = "countdown"
	state.endsAt = msg.endsAt
	state.lastSecond = -1
	closeAllModals()
	hideRoundUi()
	showBanner("🚀 BERSIAP!", msg.topicName .. "  •  " .. msg.total .. " soal  •  Lihat layar besar!")
	countdownLabel.Visible = true
end

function handlers.Question(msg)
	state.mode = "question"
	state.endsAt = msg.endsAt
	state.duration = msg.duration
	state.lastSecond = -1
	state.options = msg.options
	state.kind = msg.kind
	state.myPad = nil
	state.hintUsed = false
	state.hiddenPads = {}
	restoreLocalPads()
	closeAllModals()
	banner.Visible = false
	explain.Visible = false
	countdownLabel.Visible = false

	questionPanel.Visible = true
	topicChip.Text = msg.topicName
	topicChip.TextColor3 = msg.topicColor
	counterLabel.Text = "Soal " .. msg.index .. " / " .. msg.total
	questionText.Text = msg.text
	bossBadge.Visible = msg.isBoss
	questionStroke.Color = msg.isBoss and T.Bad or msg.topicColor
	questionStroke.Transparency = 0
	choiceHint.Text = ""
	Ui.pop(questionPanel, 0.85)

	setupCards(msg.options)
	optionsBar.Visible = true
	updateHud()
	play("Question")
	if msg.isBoss then
		showToast("⚠ SOAL BOS ⚠", "Poin dikali " .. Config.BossMultiplier .. "! Fokus!", T.Bad, 2)
	end
end

function handlers.Stats(msg)
	state.score, state.streak, state.hints = msg.score, msg.streak, msg.hints
	updateHud()
end

local cheers = { "BENAR! 🎉", "MANTAP! 🔥", "HEBAT! ⭐", "KEREN! 😎", "JENIUS! 🧠" }
function handlers.Result(msg)
	state.score, state.streak, state.hints = msg.score, msg.streak, msg.hints
	state.mode = "explain"
	updateHud()
	if msg.correct then
		local sub = "+" .. msg.gained .. " poin"
		if msg.streak >= 2 then
			sub ..= "  •  🔥 Streak x" .. msg.streak
		end
		if msg.earnedHint then
			sub ..= "  •  💡 Dapat bantuan 50:50!"
			task.delay(0.4, function()
				play("Hint")
			end)
		end
		showToast(cheers[math.random(1, #cheers)], sub, T.Good, 2.6)
		flashScreen(T.Good)
		play("Correct")
	elseif msg.answered then
		showToast("SALAH 😅", "Tidak apa-apa! Baca penjelasannya ya.", T.Bad, 2.6)
		flashScreen(T.Bad)
		play("Wrong")
	else
		showToast("WAKTU HABIS ⏰", "Kamu belum berdiri di kotak jawaban mana pun.", T.Gold, 2.6)
		flashScreen(T.Gold)
		play("Wrong")
	end
	scoreLabel.TextColor3 = msg.correct and T.Good or T.Gold
	Ui.pop(scoreLabel, 1.4)
	task.delay(0.6, function()
		scoreLabel.TextColor3 = T.Gold
	end)
end

function handlers.Reveal(msg)
	state.mode = "explain"
	state.endsAt = msg.explainEndsAt
	state.duration = math.max(1, msg.explainEndsAt - serverNow())
	restoreLocalPads()
	choiceHint.Text = ""
	timerNumber.Text = "✔"
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
	explainTitle.Text = "✔ Jawaban benar: " .. prefix .. msg.correctText
	explainText.Text = "📘 " .. msg.explanation
	explain.Visible = true
	Ui.pop(explain, 0.9)
	updateHud()
end

function handlers.RoundEnd(msg)
	state.mode = "results"
	state.options = {}
	hideRoundUi()
	banner.Visible = false
	closeAllModals()
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
	restoreLocalPads()
	hideRoundUi()
	showToast("⏹ Kuis dihentikan", "Guru menghentikan ronde ini.", T.Gold, 3)
end

QuizEvent.OnClientEvent:Connect(function(msg)
	local handler = type(msg) == "table" and handlers[msg.type]
	if handler then
		handler(msg)
	end
end)

---------------------------------------------------------------------
-- BANTUAN 50:50
---------------------------------------------------------------------
useHint = function()
	if state.mode ~= "question" then
		showToast("💡 Belum bisa", "Bantuan dipakai saat soal sedang berlangsung.", T.Gold, 2)
		return
	end
	local ok, wrongPads, info = pcall(function()
		return HintFunction:InvokeServer()
	end)
	if not ok or not wrongPads then
		showToast("💡 Bantuan", (ok and info) or "Coba lagi.", T.Gold, 2.2)
		return
	end
	state.hints = info
	state.hintUsed = true
	play("Hint")
	for _, padIndex in ipairs(wrongPads) do
		state.hiddenPads[padIndex] = true
		local card = cardForPad(padIndex)
		if card then
			card.frame.BackgroundTransparency = 0.75
			card.text.TextTransparency = 0.6
			card.letter.Text = "✖"
		end
		local pad = getPad(padIndex)
		if pad then
			state.savedPadColors[padIndex] = state.savedPadColors[padIndex] or pad.Color
			pad.Color = Color3.fromRGB(55, 55, 60)
		end
	end
	showToast("💡 50:50!", "2 jawaban salah sudah dihapus. Pilih dengan teliti!", Color3.fromRGB(190, 150, 255), 2)
	updateHud()
end

---------------------------------------------------------------------
-- LOOP PER FRAME: timer, hitung mundur, posisi pemain
---------------------------------------------------------------------
local lastPositionCheck = 0
RunService.RenderStepped:Connect(function()
	local t = serverNow()
	local left = math.max(0, state.endsAt - t)

	if state.mode == "question" then
		local ratio = math.clamp(left / state.duration, 0, 1)
		timerFill.Size = UDim2.fromScale(ratio, 1)
		local color = T.Bad:Lerp(T.Good, ratio)
		timerFill.BackgroundColor3 = color
		timerStroke.Color = color
		local seconds = math.ceil(left)
		if seconds ~= state.lastSecond then
			state.lastSecond = seconds
			timerNumber.Text = tostring(seconds)
			if seconds <= 5 and seconds > 0 then
				play("Tick")
				Ui.pop(timerCircle, 1.25)
			end
		end

		if os.clock() - lastPositionCheck > 0.1 then
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
	elseif state.mode == "explain" then
		explainFill.Size = UDim2.fromScale(math.clamp(left / state.duration, 0, 1), 1)
	elseif state.mode == "intermission" then
		bannerTitle.Text = "⏳ Kuis dimulai dalam " .. math.ceil(left) .. " detik"
	elseif state.mode == "countdown" then
		local seconds = math.ceil(left - 1)
		if seconds ~= state.lastSecond then
			state.lastSecond = seconds
			countdownLabel.Text = seconds > 0 and tostring(seconds) or "MULAI! 🚀"
			Ui.pop(countdownLabel, 1.6)
			play(seconds > 0 and "Tick" or "Correct")
		end
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updatePixelScales)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePixelScales)
end
updatePixelScales()

-- tampilkan Cara Main saat pertama kali masuk
helpModal.Visible = true
updateHud()
ReadyEvent:FireServer()
