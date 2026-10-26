--[[
	Ui: design system kecil untuk seluruh antarmuka NET QUEST.
	- Kartu putih bersudut membulat dengan bayangan lembut
	- Font Builder Sans (font resmi Roblox) + Fredoka untuk angka/judul besar
	- Tombol dengan varian warna yang konsisten
]]

local TweenService = game:GetService("TweenService")

local Ui = {}

local function font(name, fallback)
	local ok, value = pcall(function()
		return Enum.Font[name]
	end)
	return ok and value or fallback
end

Ui.Font = {
	Display = Enum.Font.FredokaOne,
	Black = font("BuilderSansExtraBold", Enum.Font.GothamBlack),
	Bold = font("BuilderSansBold", Enum.Font.GothamBold),
	Medium = font("BuilderSansMedium", Enum.Font.GothamMedium),
	Mono = Enum.Font.RobotoMono,
}

Ui.Theme = {
	Ink = Color3.fromRGB(28, 32, 56), -- teks utama di atas kartu putih
	InkSoft = Color3.fromRGB(104, 112, 140), -- teks sekunder
	Paper = Color3.fromRGB(255, 255, 255),
	Paper2 = Color3.fromRGB(243, 245, 251), -- baris / latar sekunder
	Line = Color3.fromRGB(226, 230, 241),
	Night = Color3.fromRGB(24, 28, 52), -- kartu gelap (HUD)
	Night2 = Color3.fromRGB(40, 46, 80),
	Primary = Color3.fromRGB(92, 104, 245),
	Gold = Color3.fromRGB(255, 194, 48),
	Good = Color3.fromRGB(38, 186, 112),
	Bad = Color3.fromRGB(236, 78, 94),
	Orange = Color3.fromRGB(255, 140, 60),
	Pink = Color3.fromRGB(240, 100, 170),
	White = Color3.new(1, 1, 1),
}
local T = Ui.Theme

-- Membuat Instance dengan properti. props.Parent dipasang paling akhir.
function Ui.new(className, props)
	local inst = Instance.new(className)
	local parent = props.Parent
	for key, value in pairs(props) do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = parent
	return inst
end

function Ui.corner(parent, radius)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Ui.stroke(parent, color, thickness, transparency)
	return Ui.new("UIStroke", {
		Color = color or T.Line,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Ui.padding(parent, top, right, bottom, left)
	right = right or top
	bottom = bottom or top
	left = left or right
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
		Parent = parent,
	})
end

function Ui.list(parent, direction, gap, hAlign, vAlign)
	return Ui.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

function Ui.maxText(parent, max, min)
	return Ui.new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min or 10, Parent = parent })
end

function Ui.sizeLimit(parent, minSize, maxSize)
	return Ui.new("UISizeConstraint", { MinSize = minSize, MaxSize = maxSize, Parent = parent })
end

-- Teks. Default: ukuran tetap (TextSize) agar rapi; gunakan Scaled = true untuk teks panjang yang harus muat.
function Ui.text(props)
	local max, scaled = props.MaxTextSize, props.Scaled
	props.MaxTextSize, props.Scaled = nil, nil
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or Ui.Font.Bold
	props.TextColor3 = props.TextColor3 or T.Ink
	props.TextSize = props.TextSize or 18
	props.TextScaled = scaled == true
	if props.TextWrapped == nil then
		-- teks yang dipotong "..." cukup satu baris
		props.TextWrapped = props.TextTruncate == nil
	end
	props.Text = props.Text or ""
	props.BorderSizePixel = 0
	local label = Ui.new("TextLabel", props)
	if scaled then
		Ui.maxText(label, max or props.TextSize, 11)
	end
	return label
end

-- Kartu: mengembalikan (holder, body). Atur posisi/ukuran/visibilitas pada holder, isi konten di body.
function Ui.card(props, style)
	style = style or {}
	local radius = style.radius or 18
	local holder = Ui.new("Frame", {
		Name = props.Name or "Kartu",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(200, 100),
		BackgroundTransparency = 1,
		Visible = props.Visible ~= false,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local shadow = Ui.new("Frame", {
		Name = "Bayangan",
		Position = UDim2.fromOffset(0, style.shadow or 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = style.dark and 0.55 or 0.8,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 1,
		Parent = holder,
	})
	Ui.corner(shadow, radius)
	local body = Ui.new("Frame", {
		Name = "Isi",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = style.color or (style.dark and T.Night or T.Paper),
		BackgroundTransparency = style.transparency or (style.dark and 0.06 or 0),
		BorderSizePixel = 0,
		ClipsDescendants = style.clip == true,
		ZIndex = props.ZIndex or 1,
		Parent = holder,
	})
	Ui.corner(body, radius)
	if not style.dark then
		Ui.stroke(body, T.Line, 1, 0.2)
	else
		Ui.stroke(body, Color3.new(1, 1, 1), 1, 0.88)
	end
	return holder, body
end

-- Pita warna di tepi atas kartu. ClipsDescendants di Roblox tidak mengikuti UICorner, jadi pita diberi
-- sudut sendiri (sama dengan kartu) + penutup di bagian bawahnya agar sisi bawahnya tetap lurus.
function Ui.band(props, radius)
	props.BorderSizePixel = 0
	local band = Ui.new("Frame", props)
	Ui.corner(band, radius)
	local filler = Ui.new("Frame", { Name = "Penutup", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, radius), BackgroundColor3 = band.BackgroundColor3, BorderSizePixel = 0, ZIndex = 0, Parent = band })
	band:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		filler.BackgroundColor3 = band.BackgroundColor3
	end)
	return band
end

local VARIANTS = {
	primary = { bg = T.Primary, fg = T.White },
	success = { bg = T.Good, fg = T.White },
	danger = { bg = T.Bad, fg = T.White },
	gold = { bg = T.Gold, fg = T.Ink },
	neutral = { bg = T.Paper2, fg = T.Ink },
	dark = { bg = T.Night2, fg = T.White },
	ghost = { bg = T.Paper, fg = T.Primary },
}

-- Tombol dengan sudut membulat, efek hover & tekan
function Ui.button(props, onClick, variant)
	local v = VARIANTS[variant or "primary"] or VARIANTS.primary
	props.BackgroundColor3 = props.BackgroundColor3 or v.bg
	props.TextColor3 = props.TextColor3 or v.fg
	props.Font = props.Font or Ui.Font.Black
	props.TextSize = props.TextSize or 17
	props.TextWrapped = true
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.Text = props.Text or ""
	local radius = props.Radius or 12
	props.Radius = nil
	local button = Ui.new("TextButton", props)
	Ui.corner(button, radius)
	local scale = Ui.new("UIScale", { Name = "Skala", Parent = button })
	-- warna "diam" mengikuti perubahan BackgroundColor3 dari luar, jadi hover tidak mengembalikan warna lama
	local resting, hovered, applied = props.BackgroundColor3, false, props.BackgroundColor3
	local function apply()
		applied = hovered and resting:Lerp(Color3.new(1, 1, 1), 0.12) or resting
		button.BackgroundColor3 = applied
	end
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		if button.BackgroundColor3 ~= applied then
			resting = button.BackgroundColor3
			if hovered then
				apply()
			end
		end
	end)
	button.MouseEnter:Connect(function()
		hovered = true
		Ui.tween(scale, 0.12, { Scale = 1.03 })
		apply()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		Ui.tween(scale, 0.12, { Scale = 1 })
		apply()
	end)
	button.MouseButton1Down:Connect(function()
		Ui.tween(scale, 0.06, { Scale = 0.97 })
	end)
	button.MouseButton1Up:Connect(function()
		Ui.tween(scale, 0.1, { Scale = 1 })
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Label kecil berbentuk pil
function Ui.chip(props, color, textColor)
	props.BackgroundColor3 = color
	props.BackgroundTransparency = 0
	props.TextColor3 = textColor or T.White
	props.Font = props.Font or Ui.Font.Black
	props.TextSize = props.TextSize or 13
	props.Size = props.Size or UDim2.fromOffset(0, 24)
	props.AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.X
	props.TextWrapped = false
	local chip = Ui.text(props)
	Ui.corner(chip, 12)
	Ui.padding(chip, 0, 10, 0, 10)
	return chip
end

-- Bilah progres: mengembalikan (latar, isi)
function Ui.bar(props, color, track)
	props.BackgroundColor3 = track or T.Line
	props.BorderSizePixel = 0
	local back = Ui.new("Frame", props)
	Ui.corner(back, 6)
	local fill = Ui.new("Frame", { Name = "Isi", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or T.Primary, BorderSizePixel = 0,
		Parent = back })
	Ui.corner(fill, 6)
	return back, fill
end

function Ui.tween(inst, time, goal, style, direction)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- Animasi "muncul" (membesar sedikit lalu normal).
-- Satu GuiObject hanya memakai satu UIScale, jadi UIScale yang sudah ada (skala layar / hover) dipakai ulang;
-- atribut "Dasar" menyimpan skala normalnya.
function Ui.pop(inst, from)
	local scale = inst:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Name = "PopScale", Parent = inst })
	local base = scale:GetAttribute("Dasar") or 1
	scale.Scale = base * (from or 0.7)
	Ui.tween(scale, 0.35, { Scale = base }, Enum.EasingStyle.Back)
end

function Ui.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- 12345 -> "12.345"
function Ui.number(n)
	local s = tostring(math.floor(n or 0))
	local negative = string.sub(s, 1, 1) == "-"
	if negative then
		s = string.sub(s, 2)
	end
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1.")))
	if string.sub(out, 1, 1) == "." then
		out = string.sub(out, 2)
	end
	return (negative and "-" or "") .. out
end

-- warna lebih gelap untuk sisi bawah tombol 3D
function Ui.darker(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.25)
end

return Ui
