--[[
	Registration (client): formulir pendaftaran siswa (nama lengkap, nomor absen, kelas).
	Muncul saat siswa masuk. Siswa belum bisa bergerak sebelum menekan "MULAI BELAJAR".
]]

local Players = game:GetService("Players")

local Registration = {}

local player = Players.LocalPlayer

local WIDTH = 460
local HEADER = 140

function Registration.Init(ctx)
	local Ui = ctx.Ui
	local T, F = Ui.Theme, Ui.Font

	local overlay = Ui.new("Frame", { Name = "Pendaftaran", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 18, 40),
		BackgroundTransparency = 0.25, BorderSizePixel = 0, Active = true, ZIndex = 20, Visible = false, Parent = ctx.gui })
	local formHolder, form = Ui.card({ Name = "Formulir", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 560), ZIndex = 21, Parent = overlay }, { radius = 24, clip = true, shadow = 8 })
	ctx.addPixelScale(formHolder)

	-- kepala berwarna
	local header = Ui.band({ Name = "Kepala", Size = UDim2.new(1, 0, 0, HEADER), BackgroundColor3 = T.Primary, ZIndex = 21, Parent = form }, 24)
	Ui.chip({ Position = UDim2.fromOffset(28, 24), Text = "INFORMATIKA · KELAS 7", TextSize = 12, ZIndex = 21, Parent = header },
		Color3.fromRGB(255, 255, 255), T.Primary)
	Ui.text({ Position = UDim2.fromOffset(28, 54), Size = UDim2.new(1, -56, 0, 48), Text = "NET QUEST", Font = F.Display, TextSize = 46,
		TextColor3 = T.White, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = header })
	Ui.text({ Position = UDim2.fromOffset(28, 102), Size = UDim2.new(1, -56, 0, 20), Text = "Kuis Jaringan Komputer dan Internet",
		Font = F.Bold, TextSize = 16, TextColor3 = T.White, TextTransparency = 0.12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21,
		Parent = header })

	local bodyArea = Ui.new("Frame", { Name = "Isian", Position = UDim2.fromOffset(0, HEADER), Size = UDim2.new(1, 0, 1, -HEADER),
		BackgroundTransparency = 1, ZIndex = 21, Parent = form })
	Ui.padding(bodyArea, 22, 28, 22, 28)
	Ui.list(bodyArea, Enum.FillDirection.Vertical, 14)

	Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), Text = "Isi data dirimu dulu, ya. Guru memakai data ini untuk melihat nilaimu.",
		Font = F.Medium, TextSize = 16, TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 21, Parent = bodyArea })

	local function field(parent, props, labelText, placeholder)
		local group = Ui.new("Frame", { LayoutOrder = props.LayoutOrder, Position = props.Position, Size = props.Size, BackgroundTransparency = 1,
			ZIndex = 21, Parent = parent })
		Ui.text({ Size = UDim2.new(1, 0, 0, 18), Text = labelText, Font = F.Black, TextSize = 13, TextColor3 = T.InkSoft,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = group })
		local box = Ui.new("TextBox", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = T.Paper2,
			TextColor3 = T.Ink, PlaceholderText = placeholder, PlaceholderColor3 = Color3.fromRGB(160, 166, 190), Font = F.Bold, TextSize = 20,
			Text = "", TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 21, Parent = group })
		Ui.corner(box, 12)
		Ui.padding(box, 0, 14, 0, 14)
		local stroke = Ui.stroke(box, T.Line, 1.5)
		box.Focused:Connect(function()
			stroke.Color, stroke.Thickness = T.Primary, 2
			box.BackgroundColor3 = T.Paper
		end)
		box.FocusLost:Connect(function()
			stroke.Color, stroke.Thickness = T.Line, 1.5
			box.BackgroundColor3 = T.Paper2
		end)
		return box, group
	end

	local nameBox = field(bodyArea, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 72) }, "NAMA LENGKAP", "contoh: Budi Santoso")

	-- absen & kelas berdampingan; jika kelas tidak ditanyakan, absen memakai lebar penuh
	local row = Ui.new("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1, ZIndex = 21, Parent = bodyArea })
	local absenBox, absenGroup = field(row, { Size = UDim2.new(0.5, -8, 1, 0) }, "NOMOR ABSEN", "contoh: 5")
	local classBox, classGroup = field(row, { Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0) }, "KELAS", "contoh: 7A")

	local message = Ui.text({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 20), Text = "", Font = F.Bold, TextSize = 15, TextColor3 = T.Bad,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21, Parent = bodyArea })

	local busy = false
	local submit
	local function send(skipAsTeacher)
		if busy then
			return
		end
		busy = true
		submit.Text = "MEMERIKSA..."
		message.TextColor3 = T.InkSoft
		message.Text = "Sebentar, datamu sedang diperiksa."
		local ok, success, info = pcall(function()
			return ctx.remotes.Register:InvokeServer(nameBox.Text, absenBox.Text, classBox.Text, skipAsTeacher)
		end)
		busy = false
		submit.Text = "MULAI BELAJAR"
		if ok and success then
			overlay.Visible = false
			ctx.onRegistered(info, skipAsTeacher)
		else
			message.TextColor3 = T.Bad
			message.Text = tostring(ok and info or "Koneksi bermasalah, coba lagi.")
			Ui.pop(formHolder, 1.02)
		end
	end
	submit = Ui.button({ LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 54), Text = "MULAI BELAJAR", TextSize = 20, Radius = 14, ZIndex = 22 },
		function()
			send(false)
		end, "success")
	submit.Parent = bodyArea
	local teacherSkip = Ui.button({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 36), Text = "Saya guru, lewati pendaftaran", TextSize = 15,
		Font = F.Bold, ZIndex = 22, Visible = false }, function()
		send(true)
	end, "ghost")
	teacherSkip.Parent = bodyArea

	local askClass = true
	local function layout()
		classGroup.Visible = askClass
		absenGroup.Size = askClass and UDim2.new(0.5, -8, 1, 0) or UDim2.new(1, 0, 1, 0)
		-- tinggi: kepala + padding + teks + 2 baris isian + pesan + tombol (+ tombol guru) + jarak antarbaris
		local height = HEADER + 22 + 40 + 72 + 72 + 20 + 54 + 22 + 14 * 4
		if teacherSkip.Visible then
			height += 36 + 14
		end
		formHolder.Size = UDim2.fromOffset(WIDTH, height)
	end

	local function onlyDigits()
		local digits = string.gsub(absenBox.Text, "%D", "")
		if digits ~= absenBox.Text then
			absenBox.Text = digits
		end
	end
	absenBox:GetPropertyChangedSignal("Text"):Connect(onlyDigits)
	nameBox.FocusLost:Connect(function(enter)
		if enter then
			absenBox:CaptureFocus()
		end
	end)
	absenBox.FocusLost:Connect(function(enter)
		if enter then
			if askClass then
				classBox:CaptureFocus()
			else
				send(false)
			end
		end
	end)
	classBox.FocusLost:Connect(function(enter)
		if enter then
			send(false)
		end
	end)

	local function updateTeacherButton()
		teacherSkip.Visible = player:GetAttribute("IsTeacher") == true
		layout()
	end
	player:GetAttributeChangedSignal("IsTeacher"):Connect(updateTeacherButton)
	updateTeacherButton()

	-- Pesan "Profile" dari server: isi otomatis dari data tersimpan
	function Registration.OnProfile(msg)
		askClass = msg.askClass ~= false
		layout()
		if nameBox.Text == "" then
			nameBox.Text = msg.nama or ""
		end
		if absenBox.Text == "" and msg.absen and msg.absen ~= "" then
			absenBox.Text = tostring(msg.absen)
		end
		if classBox.Text == "" then
			classBox.Text = msg.kelas or ""
		end
		absenBox.PlaceholderText = "1 sampai " .. tostring(msg.maxAbsen or 50)
		if msg.nama and msg.nama ~= "" and not msg.registered then
			message.TextColor3 = T.Good
			message.Text = "Selamat datang kembali! Periksa datamu lalu tekan MULAI."
		end
		local wasOpen = overlay.Visible
		overlay.Visible = not msg.registered and player:GetAttribute("SkipDaftar") ~= true
		if overlay.Visible and not wasOpen then
			Ui.pop(formHolder, 0.9)
		end
	end

	function Registration.IsOpen()
		return overlay.Visible
	end
end

return Registration
