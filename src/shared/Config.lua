--[[
	KONFIGURASI GAME "NET QUEST: Kuis Jaringan Komputer & Internet"
	Ubah angka/teks di file ini untuk menyesuaikan game dengan kelas Anda.
	Tidak perlu menyentuh script lain.
]]

local Config = {}

---------------------------------------------------------------------
-- PENDAFTARAN SISWA (muncul saat siswa pertama kali masuk)
---------------------------------------------------------------------
Config.AskClass = true -- true = siswa juga mengisi kelas (contoh: 7A). false = hanya nama & absen
Config.MaxAbsen = 50 -- nomor absen maksimal
Config.MinNameLength = 3
Config.MaxNameLength = 30

---------------------------------------------------------------------
-- MODE PERMAINAN
-- "petualangan" = keempat game dimainkan berurutan dan poinnya DIJUMLAHKAN (poin total).
-- Guru juga bisa memilih satu game saja di Panel Guru.
---------------------------------------------------------------------
Config.Modes = {
	{ id = "petualangan", name = "Petualangan 4 Game", icon = "", color = Color3.fromRGB(150, 110, 255),
		desc = "Mainkan keempat game berurutan. Poin semua game dijumlahkan menjadi POIN TOTAL." },
	{ id = "kotak", name = "Lari & Pilih", icon = "", color = Color3.fromRGB(64, 140, 240),
		desc = "Lari dan berdiri di kotak jawaban yang benar. Kotak yang salah akan jatuh ke kolam!" },
	{ id = "kilat", name = "Kuis Kilat", icon = "", color = Color3.fromRGB(245, 180, 40),
		desc = "Tekan tombol jawaban secepat mungkin. Jawaban tidak bisa diganti, makin cepat makin besar poinnya." },
	{ id = "firewall", name = "Lintasan Firewall", icon = "", color = Color3.fromRGB(240, 100, 70),
		desc = "Balapan di lintasan langit. Masuk ke pintu jawaban yang benar, pintu yang salah membuatmu jatuh!" },
	{ id = "sandi", name = "Pecahkan Sandi", icon = "", color = Color3.fromRGB(60, 180, 130),
		desc = "Ketik jawaban yang benar dan pecahkan kode rahasia Caesar Cipher." },
}
Config.DefaultMode = "petualangan"
Config.AdventureOrder = { "kotak", "kilat", "firewall", "sandi" } -- urutan game di Petualangan
Config.CompletionBonus = 200 -- bonus untuk siswa yang ikut menjawab di keempat game
Config.GameBreakTime = 10 -- detik menampilkan hasil tiap game sebelum lanjut ke game berikutnya

function Config.GetMode(id)
	for _, mode in ipairs(Config.Modes) do
		if mode.id == id then
			return mode
		end
	end
	return Config.Modes[1]
end

---------------------------------------------------------------------
-- PENGATURAN KUIS
---------------------------------------------------------------------
Config.QuestionsPerRound = 5 -- jumlah soal PER GAME (Lintasan Firewall selalu FirewallGates soal)
Config.QuestionTime = 20 -- detik soal pilihan ganda (mode Lari & Pilih)
Config.TrueFalseTime = 12 -- detik soal Benar/Salah (mode Lari & Pilih)
Config.KilatTime = 10 -- detik per soal mode Kuis Kilat
Config.SandiTime = 35 -- detik per soal mode Pecahkan Sandi
Config.SandiAttempts = 3 -- kesempatan mengetik per soal
Config.FirewallGates = 6 -- jumlah gerbang (soal) di Lintasan Firewall
Config.FirewallTime = 240 -- batas waktu Lintasan Firewall (detik)
Config.RevealTime = 3 -- detik animasi jawaban benar
Config.ExplanationTime = 7 -- detik menampilkan penjelasan materi
Config.IntermissionTime = 30 -- detik jeda sebelum ronde dimulai
Config.ModeIntroTime = 6 -- detik penjelasan cara main mode sebelum ronde
Config.RoundEndTime = 15 -- detik menampilkan hasil akhir ronde
Config.MinPlayers = 1 -- minimal siswa terdaftar agar ronde otomatis dimulai
Config.AutoStart = true -- true = ronde mulai otomatis; false = tunggu guru menekan "Mulai"

---------------------------------------------------------------------
-- GURU (bisa membuka Panel Guru)
-- Pemilik game otomatis menjadi guru. Tambahkan akun guru lain di sini.
---------------------------------------------------------------------
Config.TeacherUserIds = {
	-- 12345678,
}
Config.TeacherNames = {
	-- "NamaAkunGuru",
}
Config.GroupTeacherMinRank = 254 -- jika game milik Grup: rank minimal untuk jadi guru
Config.StudioEveryoneTeacher = true -- saat dites di Roblox Studio, semua pemain jadi guru

---------------------------------------------------------------------
-- SKOR
---------------------------------------------------------------------
Config.BasePoints = 100 -- poin jawaban benar
Config.MaxSpeedBonus = 50 -- bonus maksimal jika menjawab cepat
Config.KilatSpeedBonus = 100 -- bonus kecepatan maksimal di Kuis Kilat
Config.StreakBonus = 10 -- bonus per jawaban benar berturut-turut
Config.MaxStreakBonus = 50 -- batas bonus streak
Config.BossMultiplier = 2 -- soal terakhir (SOAL BOS) poinnya dikali angka ini
Config.SandiRetryPenalty = 30 -- poin berkurang tiap salah ketik sebelum benar
Config.FinishBonus = { 300, 200, 100 } -- bonus juara 1/2/3 yang mencapai finish Lintasan Firewall
Config.FinishAllBonus = 50 -- bonus untuk semua yang berhasil mencapai finish
Config.HintEveryStreak = 3 -- tiap benar 3x berturut-turut dapat 1 bantuan
Config.MaxHints = 2 -- maksimal bantuan yang bisa disimpan
Config.StartingHints = 1 -- bantuan yang dimiliki saat ronde dimulai

---------------------------------------------------------------------
-- PENYIMPANAN (DataStore) untuk data siswa, Poin Rank & Pet
-- Agar berfungsi: Game Settings > Security > Enable Studio Access to API Services
-- dan game sudah dipublikasikan. Jika gagal, game tetap berjalan tanpa simpan.
---------------------------------------------------------------------
Config.UseDataStore = true
Config.DataStoreName = "NetQuest_KuisJaringan_v1"

-- Gelar berdasarkan total POIN RANK (Poin Rank = total poin dari semua ronde)
Config.Ranks = {
	{ xp = 0, name = "Kabel Pemula", color = Color3.fromRGB(200, 200, 200) },
	{ xp = 1000, name = "Hub Junior", color = Color3.fromRGB(120, 220, 255) },
	{ xp = 3000, name = "Switch Cekatan", color = Color3.fromRGB(110, 255, 150) },
	{ xp = 6000, name = "Router Hebat", color = Color3.fromRGB(255, 220, 90) },
	{ xp = 10000, name = "Server Master", color = Color3.fromRGB(255, 140, 70) },
	{ xp = 16000, name = "Legenda Internet", color = Color3.fromRGB(255, 90, 220) },
}
-- Daftar pet & syarat Poin Rank-nya ada di QuizShared > PetCatalog

---------------------------------------------------------------------
-- TOPIK MATERI (Informatika Kelas 7 - Jaringan Komputer & Internet)
---------------------------------------------------------------------
Config.Topics = {
	{ id = "campuran", name = "Campuran (Semua Materi)", color = Color3.fromRGB(180, 120, 255) },
	{ id = "konsep", name = "Konsep Jaringan Komputer", color = Color3.fromRGB(80, 170, 255) },
	{ id = "topologi", name = "Topologi Jaringan", color = Color3.fromRGB(255, 160, 60) },
	{ id = "perangkat", name = "Perangkat Jaringan", color = Color3.fromRGB(90, 220, 140) },
	{ id = "internet", name = "Internet & Cara Kerjanya", color = Color3.fromRGB(60, 210, 230) },
	{ id = "koneksi", name = "Koneksi Kabel & Nirkabel", color = Color3.fromRGB(255, 210, 70) },
	{ id = "keamanan", name = "Keamanan & Proteksi Data", color = Color3.fromRGB(255, 90, 110) },
}

function Config.GetTopic(id)
	for _, topic in ipairs(Config.Topics) do
		if topic.id == id then
			return topic
		end
	end
	return Config.Topics[1]
end

---------------------------------------------------------------------
-- WARNA KOTAK / PINTU JAWABAN (A, B, C, D)
---------------------------------------------------------------------
Config.PadColors = {
	Color3.fromRGB(235, 64, 82), -- A merah
	Color3.fromRGB(45, 125, 245), -- B biru
	Color3.fromRGB(245, 185, 30), -- C kuning
	Color3.fromRGB(40, 190, 95), -- D hijau
}
Config.PadLetters = { "A", "B", "C", "D" }
Config.TrueColor = Color3.fromRGB(40, 190, 95)
Config.FalseColor = Color3.fromRGB(235, 64, 82)

---------------------------------------------------------------------
-- SUARA (boleh diganti dengan ID audio dari Toolbox, contoh "rbxassetid://123")
-- Kosongkan ("") untuk mematikan suara tertentu.
---------------------------------------------------------------------
Config.Sounds = {
	Tick = "rbxasset://sounds/clickfast.wav",
	Correct = "rbxasset://sounds/electronicpingshort.wav",
	Wrong = "rbxasset://sounds/uuhhh.mp3",
	Question = "rbxasset://sounds/button.wav",
	Fanfare = "rbxasset://sounds/electronicpingshort.wav",
	Hint = "rbxasset://sounds/snap.wav",
}
Config.MusicId = "" -- isi dengan ID musik latar dari Toolbox jika ingin ada musik

---------------------------------------------------------------------
-- TAMPILAN DUNIA
---------------------------------------------------------------------
Config.ClockTime = 14.5 -- waktu langit (0-24). 14 = siang cerah, 17.5 = senja
Config.GameTitle = "NET QUEST"
Config.GameSubtitle = "Kuis Jaringan Komputer & Internet • Informatika Kelas 7"

return Config
