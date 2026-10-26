--[[
	Roster: pendaftaran siswa (nama lengkap, nomor absen, kelas).
	- Siswa yang belum mendaftar tidak bisa bergerak dan tidak ikut kuis.
	- Nama & kelas disaring dengan filter teks Roblox sebelum ditampilkan ke pemain lain.
	- Data disimpan agar saat masuk lagi formulir sudah terisi otomatis.
	- Rekap nilai lengkap (nama asli) dicetak di Output/Developer Console untuk guru.
]]

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local StarterPlayer = game:GetService("StarterPlayer")

local Roster = {}
local Core
local rawClass = {} -- [Player] = kelas asli (hanya di server, untuk cek absen ganda & urutan)

local function trim(text)
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function filterForEveryone(text, player)
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		return result
	end
	warn("[NetQuest] Filter teks gagal: " .. tostring(result))
	return nil
end

---------------------------------------------------------------------
-- BEKUKAN / LEPAS KARAKTER
---------------------------------------------------------------------
local function canMove(player)
	return Core.isRegistered(player) or player:GetAttribute("SkipDaftar") == true
end

function Roster.ApplyMovement(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if canMove(player) then
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
	else
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end
end

---------------------------------------------------------------------
-- PAPAN NAMA DI ATAS KEPALA
---------------------------------------------------------------------
function Roster.ApplyTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local old = head:FindFirstChild("GelarTag")
	if old then
		old:Destroy()
	end
	local rank = Core.PlayerData.GetRank(Core.PlayerData.Get(player).xp)
	local tag = Instance.new("BillboardGui")
	tag.Name = "GelarTag"
	tag.Size = UDim2.fromScale(8, 2)
	tag.StudsOffset = Vector3.new(0, 3.2, 0)
	tag.MaxDistance = 90
	tag.LightInfluence = 0

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.3
	local titleLabel = nameLabel:Clone()
	titleLabel.Position = UDim2.fromScale(0, 0.55)
	titleLabel.Size = UDim2.fromScale(1, 0.45)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextColor3 = rank.color

	if Core.isRegistered(player) then
		local kelas = player:GetAttribute("Kelas")
		nameLabel.Text = Core.displayName(player) .. ((kelas and kelas ~= "") and (" (" .. kelas .. ")") or "")
		titleLabel.Text = rank.name
	elseif player:GetAttribute("IsTeacher") then
		nameLabel.Text = player.DisplayName
		titleLabel.Text = "Guru"
		titleLabel.TextColor3 = Color3.fromRGB(255, 200, 90)
	else
		nameLabel.Text = player.DisplayName
		titleLabel.Text = "Belum mendaftar"
		titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
	nameLabel.Parent = tag
	titleLabel.Parent = tag
	tag.Parent = head
end

---------------------------------------------------------------------
-- PENDAFTARAN
---------------------------------------------------------------------
local function normalizeClass(kelas)
	return string.upper((string.gsub(kelas, "%s+", "")))
end

local function register(player, name, absen, kelas)
	if type(name) ~= "string" or type(absen) ~= "string" and type(absen) ~= "number" then
		return false, "Data tidak valid."
	end
	local Config = Core.Config
	name = trim(string.sub(name, 1, 60))
	name = string.gsub(name, "%s+", " ")
	if #name < Config.MinNameLength then
		return false, "Nama terlalu pendek. Tulis nama lengkapmu ya!"
	end
	if #name > Config.MaxNameLength then
		return false, "Nama terlalu panjang (maksimal " .. Config.MaxNameLength .. " huruf)."
	end
	if not string.match(name, "%a") then
		return false, "Nama harus berisi huruf."
	end
	local number = tonumber(absen)
	if not number or number ~= math.floor(number) or number < 1 or number > Config.MaxAbsen then
		return false, "Nomor absen harus angka 1 sampai " .. Config.MaxAbsen .. "."
	end
	if Config.AskClass then
		if type(kelas) ~= "string" then
			return false, "Isi kelasmu dulu (contoh: 7A)."
		end
		kelas = normalizeClass(string.sub(kelas, 1, 12))
		if #kelas < 1 or #kelas > 6 then
			return false, "Tulis kelas dengan singkat, contoh: 7A"
		end
	else
		kelas = ""
	end

	-- nomor absen tidak boleh sama dengan siswa lain di kelas yang sama
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and Core.isRegistered(other) and other:GetAttribute("Absen") == number
			and (rawClass[other] or "") == kelas then
			return false, "Absen " .. number .. (kelas ~= "" and (" kelas " .. kelas) or "")
				.. " sudah dipakai siswa lain. Periksa lagi nomor absenmu!"
		end
	end

	local shownName = filterForEveryone(name, player)
	local shownClass = kelas ~= "" and filterForEveryone(kelas, player) or ""
	if not shownName or not shownClass then
		return false, "Server sedang memeriksa nama. Coba tekan tombol lagi ya."
	end

	player:SetAttribute("Nama", shownName)
	player:SetAttribute("Absen", number)
	player:SetAttribute("Kelas", shownClass)
	rawClass[player] = kelas
	player:SetAttribute("Registered", true)
	Core.PlayerData.SetProfile(player, { nama = name, absen = number, kelas = kelas })

	local st = Core.stats[player]
	if st then
		st.activeFrom = Core.now()
	end
	Roster.ApplyMovement(player)
	Roster.ApplyTag(player)
	Core.updateLeaderstats(player)
	print(string.format("[NetQuest] Siswa terdaftar: %s | Absen %02d | Kelas %s", name, number, kelas))
	return true, "Selamat datang, " .. shownName .. "!"
end

function Roster.SendProfile(player)
	local data = Core.PlayerData.Get(player)
	local profile = data.profile
	Core.send(player, {
		type = "Profile",
		registered = Core.isRegistered(player),
		nama = profile and profile.nama or "",
		absen = profile and profile.absen or "",
		kelas = profile and profile.kelas or "",
		askClass = Core.Config.AskClass,
		maxAbsen = Core.Config.MaxAbsen,
	})
end

-- Daftar siswa untuk Panel Guru (nama yang sudah disaring)
local function rosterList()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if Core.isRegistered(player) then
			local st = Core.stats[player]
			local session = Core.getSession(player)
			local data = Core.PlayerData.Get(player)
			table.insert(list, {
				absen = player:GetAttribute("Absen"),
				nama = player:GetAttribute("Nama"),
				kelas = player:GetAttribute("Kelas") or "",
				kelasSort = rawClass[player] or "",
				roundScore = st and st.score or 0,
				correct = session.correct,
				answered = session.answered,
				sessionScore = session.score,
				xp = data.xp,
				title = Core.PlayerData.GetRank(data.xp).name,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.kelasSort ~= b.kelasSort then
			return a.kelasSort < b.kelasSort
		end
		return a.absen < b.absen
	end)
	return list
end

-- Mencetak rekap nilai ke Output / Developer Console (F9 > Server) untuk guru
function Roster.PrintRecap(title)
	print("==================== [NetQuest] REKAP NILAI: " .. title .. " ====================")
	print("Kelas | Absen | Nama | Benar/Soal (sesi ini) | Nilai | Poin Sesi | Poin Rank")
	for _, player in ipairs(Players:GetPlayers()) do
		if Core.isRegistered(player) then
			local profile = Core.PlayerData.Get(player).profile or {}
			local session = Core.getSession(player)
			local nilai = session.answered > 0 and math.floor(session.correct / session.answered * 100 + 0.5) or 0
			print(string.format("%s | %02d | %s | %d/%d | %d | %d | %d", profile.kelas or "-", profile.absen or 0,
				profile.nama or player.Name, session.correct, session.answered, nilai, session.score, Core.PlayerData.Get(player).xp))
		end
	end
	print("=================================================================================")
end

function Roster.Init(core)
	Core = core
	Players.PlayerRemoving:Connect(function(player)
		rawClass[player] = nil
	end)
	Core.remotes.Register.OnServerInvoke = function(player, name, absen, kelas, skipAsTeacher)
		if skipAsTeacher == true then
			if player:GetAttribute("IsTeacher") then
				player:SetAttribute("SkipDaftar", true)
				Roster.ApplyMovement(player)
				Roster.ApplyTag(player)
				return true, "Masuk sebagai guru."
			end
			return false, "Hanya guru yang boleh melewati pendaftaran."
		end
		return register(player, name, absen, kelas)
	end
	Core.remotes.GetRoster.OnServerInvoke = function(player)
		if not player:GetAttribute("IsTeacher") then
			return nil
		end
		return rosterList()
	end
end

return Roster
