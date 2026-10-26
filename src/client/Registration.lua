--[[
	Registration (client): formulir pendaftaran siswa (nama lengkap, nomor absen, kelas).
	Muncul saat siswa masuk. Siswa belum bisa bergerak sebelum menekan "MULAI BELAJAR".
]]

local Players = game:GetService("Players")

local Registration = {}

local player = Players.LocalPlayer

function Registration.Init(ctx)
	local Ui, T = ctx.Ui, ctx.Theme

	local overlay = Ui.new("Frame", { Name = "Pendaftaran", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 14, 30),
		BackgroundTransparency = 0.35, BorderSizePixel = 0, Active = true, ZIndex = 20, Visible = false, Parent = ctx.gui })
	local form = Ui.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 460, 0, 590),
		ZIndex = 21, Parent = overlay })
	ctx.addPixelScale(form)
	Ui.padding(form, 18)
	Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = form })

	Ui.text({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), Text = "🌐 NET QUEST", Font = Enum.Font.FredokaOne,
		TextColor3 = T.Pink, MaxTextSize = 38, ZIndex = 21, Parent = form })
	Ui.text({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30), Text = "📝 Isi data dirimu dulu ya!", Font = Enum.Font.FredokaOne,
		TextColor3 = T.Gold, MaxTextSize = 26, ZIndex = 21, Parent = form })
	Ui.text({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 34), Text = "Data ini dipakai guru untuk melihat nilaimu. Tulis dengan benar ya!",
		TextColor3 = T.Sub, Font = Enum.Font.GothamMedium, MaxTextSize = 16, ZIndex = 21, Parent = form })

	local function field(order, labelText, placeholder)
		Ui.text({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 20), Text = labelText, TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 17, ZIndex = 21, Parent = form })
		local box = Ui.new("TextBox", { LayoutOrder = order + 1, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(245, 247, 255),
			TextColor3 = Color3.fromRGB(20, 25, 50), PlaceholderText = placeholder, PlaceholderColor3 = Color3.fromRGB(140, 145, 165),
			Font = Enum.Font.GothamBold, TextSize = 20, Text = "", ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 21, Parent = form })
		Ui.corner(box, 10)
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = box })
		return box
	end
	local nameBox = field(10, "👤 Nama Lengkap", "contoh: Budi Santoso")
	local absenBox = field(20, "🔢 Nomor Absen", "contoh: 5")
	local classLabelOrder = 30
	local classBox = field(classLabelOrder, "🏫 Kelas", "contoh: 7A")

	local message = Ui.text({ LayoutOrder = 40, Size = UDim2.new(1, 0, 0, 36), Text = "", TextColor3 = T.Bad, MaxTextSize = 16,
		ZIndex = 21, Parent = form })
	local submit
	local busy = false
	local function send(skipAsTeacher)
		if busy then
			return
		end
		busy = true
		message.TextColor3 = T.Sub
		message.Text = "⏳ Memeriksa data..."
		local ok, success, info = pcall(function()
			return ctx.remotes.Register:InvokeServer(nameBox.Text, absenBox.Text, classBox.Text, skipAsTeacher)
		end)
		busy = false
		if ok and success then
			overlay.Visible = false
			ctx.onRegistered(info, skipAsTeacher)
		else
			message.TextColor3 = T.Bad
			message.Text = "⚠ " .. tostring(ok and info or "Koneksi bermasalah, coba lagi.")
		end
	end
	submit = Ui.button({ LayoutOrder = 50, Size = UDim2.new(1, 0, 0, 50), Text = "🚀 MULAI BELAJAR", BackgroundColor3 = T.Good,
		MaxTextSize = 26, ZIndex = 22 }, function()
		send(false)
	end)
	submit.Parent = form
	local teacherSkip = Ui.button({ LayoutOrder = 60, Size = UDim2.new(1, 0, 0, 36), Text = "🎓 Saya guru (lewati pendaftaran)",
		BackgroundColor3 = Color3.fromRGB(230, 130, 40), MaxTextSize = 16, ZIndex = 22, Visible = false }, function()
		send(true)
	end)
	teacherSkip.Parent = form

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

	local function updateTeacherButton()
		teacherSkip.Visible = player:GetAttribute("IsTeacher") == true
	end
	player:GetAttributeChangedSignal("IsTeacher"):Connect(updateTeacherButton)
	updateTeacherButton()

	-- Pesan "Profile" dari server: isi otomatis dari data tersimpan
	function Registration.OnProfile(msg)
		classBox.Visible = msg.askClass
		for _, child in ipairs(form:GetChildren()) do
			if child:IsA("TextLabel") and child.LayoutOrder == classLabelOrder then
				child.Visible = msg.askClass
			end
		end
		if nameBox.Text == "" then
			nameBox.Text = msg.nama or ""
		end
		if absenBox.Text == "" and msg.absen and msg.absen ~= "" then
			absenBox.Text = tostring(msg.absen)
		end
		if classBox.Text == "" then
			classBox.Text = msg.kelas or ""
		end
		absenBox.PlaceholderText = "1 - " .. tostring(msg.maxAbsen or 50)
		if msg.nama ~= "" and not msg.registered then
			message.TextColor3 = T.Good
			message.Text = "👋 Selamat datang kembali! Periksa datamu lalu tekan MULAI."
		end
		overlay.Visible = not msg.registered and player:GetAttribute("SkipDaftar") ~= true
	end

	function Registration.IsOpen()
		return overlay.Visible
	end
end

return Registration
