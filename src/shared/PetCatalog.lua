--[[
	KATALOG PET - hadiah untuk siswa yang mengumpulkan Poin Rank.
	Poin Rank = total poin dari semua jawaban benar di semua ronde.
	Semakin banyak Poin Rank, semakin keren pet yang terbuka!

	Ubah angka "xp" untuk mengatur syarat membuka pet.
	Semua pet dibuat dari Part (tidak memerlukan aset dari Toolbox).
]]

local PetCatalog = {}

PetCatalog.Rarities = {
	Biasa = Color3.fromRGB(200, 205, 215),
	Langka = Color3.fromRGB(80, 170, 255),
	Epik = Color3.fromRGB(190, 100, 255),
	Legendaris = Color3.fromRGB(255, 200, 50),
	Mitos = Color3.fromRGB(255, 80, 160),
}

PetCatalog.List = {
	{ id = "slime", name = "Bit si Slime", xp = 0, rarity = "Biasa", flying = false,
		desc = "Pet pertamamu! Lahir dari 1 bit data." },
	{ id = "cat", name = "Kucing Kabel", xp = 600, rarity = "Biasa", flying = false,
		desc = "Ekornya kabel UTP yang menyala." },
	{ id = "dog", name = "Anjing Router", xp = 1500, rarity = "Langka", flying = false,
		desc = "Selalu tahu rute tercepat menuju tuannya." },
	{ id = "bird", name = "Burung WiFi", xp = 3000, rarity = "Langka", flying = true,
		desc = "Terbang memancarkan sinyal ke mana-mana." },
	{ id = "robot", name = "Robot Server", xp = 5000, rarity = "Epik", flying = true,
		desc = "Melayani tuannya 24 jam tanpa lelah." },
	{ id = "dragon", name = "Naga Firewall", xp = 8000, rarity = "Epik", flying = true,
		desc = "Semburan apinya memblokir semua virus!" },
	{ id = "unicorn", name = "Unicorn Cloud", xp = 12000, rarity = "Legendaris", flying = true,
		desc = "Menyimpan semua datamu di atas awan." },
	{ id = "phoenix", name = "Phoenix Fiber Optik", xp = 17000, rarity = "Legendaris", flying = true,
		desc = "Secepat cahaya di dalam kabel serat optik." },
	{ id = "galaxy", name = "Galaksi Internet", xp = 25000, rarity = "Mitos", flying = true,
		desc = "Pet terkuat! Menghubungkan seluruh jaringan di alam semesta." },
}

function PetCatalog.Get(id)
	for _, pet in ipairs(PetCatalog.List) do
		if pet.id == id then
			return pet
		end
	end
	return nil
end

function PetCatalog.IsUnlocked(id, xp)
	local pet = PetCatalog.Get(id)
	return pet ~= nil and (xp or 0) >= pet.xp
end

-- Pet terbaik yang sudah terbuka
function PetCatalog.Best(xp)
	local best = PetCatalog.List[1]
	for _, pet in ipairs(PetCatalog.List) do
		if (xp or 0) >= pet.xp then
			best = pet
		end
	end
	return best
end

-- Pet yang baru terbuka saat Poin Rank naik dari oldXp ke newXp
function PetCatalog.NewlyUnlocked(oldXp, newXp)
	local list = {}
	for _, pet in ipairs(PetCatalog.List) do
		if pet.xp > oldXp and pet.xp <= newXp then
			table.insert(list, pet)
		end
	end
	return list
end

-- Pet berikutnya yang belum terbuka
function PetCatalog.Next(xp)
	for _, pet in ipairs(PetCatalog.List) do
		if (xp or 0) < pet.xp then
			return pet
		end
	end
	return nil
end

---------------------------------------------------------------------
-- PEMBUAT MODEL PET
-- Semua pet memakai gaya "chibi" yang sama: badan bulat, mata besar mengilap,
-- pipi merona, kaki kecil, lalu ciri khas masing-masing. Model menghadap -Z.
--
-- ASET TOOLBOX (opsional): taruh model di ReplicatedStorage > AsetPet dengan nama
-- sesuai id pet (slime, cat, dog, ...). Model itu akan dipakai menggantikan pet bawaan.
---------------------------------------------------------------------
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(30, 30, 44)
local BLUSH = Color3.fromRGB(255, 140, 160)

local function setup(part, model, size, cframe, color, material)
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or SMOOTH
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Parent = model
	return part
end

local function newPart(model, size, cframe, color, material)
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return setup(part, model, size, cframe, color, material)
end

-- elips (bola yang bisa lonjong)
local function blob(model, size, cframe, color, material)
	local part = newPart(model, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- silinder tegak (sumbu Y)
local function rod(model, length, thickness, cframe, color, material)
	local part = newPart(model, Vector3.new(length, thickness, thickness), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- segitiga sama kaki di bidang X-Y (dibuat dari dua WedgePart), ujung lancip ke atas (+Y)
local function triangle(model, width, height, thickness, cframe, color, material)
	for _, side in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		setup(wedge, model, Vector3.new(thickness, height, width / 2),
			cframe * CFrame.new(side * width / 4, 0, 0) * CFrame.Angles(0, math.rad(-90 * side), 0), color, material)
	end
end

local BODY = Vector3.new(2.4, 2.2, 2.2) -- ukuran badan standar
local function frontZ(x, y)
	local a, b, c = BODY.X / 2, BODY.Y / 2, BODY.Z / 2
	local inside = 1 - (x / a) ^ 2 - (y / b) ^ 2
	return -c * math.sqrt(math.max(inside, 0))
end

-- badan + perut + mata + pipi + kaki; mengembalikan part badan
local function chibi(model, opts)
	local body = blob(model, BODY, CFrame.new(), opts.color, opts.material)
	if opts.transparency then
		body.Transparency = opts.transparency
	end
	if opts.belly then
		blob(model, Vector3.new(1.5, 1.25, 0.5), CFrame.new(0, -0.38, frontZ(0, -0.38) + 0.16), opts.belly)
	end
	local eyeY = opts.eyeY or 0.22
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 0.43
		local z = frontZ(x, eyeY)
		if opts.visor then
			newPart(model, Vector3.new(0.34, 0.2, 0.05), CFrame.new(x, eyeY, z - 0.02), opts.eyeColor or Color3.fromRGB(90, 240, 255), NEON)
		else
			blob(model, Vector3.new(0.5, 0.62, 0.22), CFrame.new(x, eyeY, z + 0.02), WHITE)
			blob(model, Vector3.new(0.36, 0.48, 0.16), CFrame.new(x, eyeY - 0.03, z - 0.05), opts.eyeColor or INK)
			blob(model, Vector3.new(0.13, 0.13, 0.06), CFrame.new(x + 0.07, eyeY + 0.1, z - 0.12), WHITE, NEON)
			local cheek = blob(model, Vector3.new(0.34, 0.18, 0.06), CFrame.new(side * 0.74, eyeY - 0.36, frontZ(side * 0.74, eyeY - 0.36) - 0.01), BLUSH)
			cheek.Transparency = 0.2
		end
	end
	if opts.mouth ~= false then
		blob(model, Vector3.new(0.16, 0.08, 0.05), CFrame.new(0, eyeY - 0.34, frontZ(0, eyeY - 0.34) - 0.01), INK)
	end
	if opts.feet ~= false then
		for _, side in ipairs({ -1, 1 }) do
			blob(model, Vector3.new(0.6, 0.36, 0.72), CFrame.new(side * 0.52, -1.02, -0.28), opts.feetColor or opts.color)
		end
	end
	return body
end

local function addEffect(attach, kind, color)
	if kind == "sparkle" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = attach
	elseif kind == "fire" then
		local fire = Instance.new("Fire")
		fire.Size = 1.2
		fire.Heat = 3
		fire.Color = color
		fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
		fire.Parent = attach
	end
	local light = Instance.new("PointLight")
	light.Range = 7
	light.Brightness = 0.8
	light.Color = color
	light.Parent = attach
end

local builders = {}

function builders.slime(model)
	local mint = Color3.fromRGB(120, 230, 160)
	local body = chibi(model, { color = mint, transparency = 0.1, feet = false })
	blob(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 1.15, 0.1), mint).Transparency = 0.1
	blob(model, Vector3.new(0.5, 0.3, 0.3), CFrame.new(-0.55, 0.7, -0.75), WHITE, NEON).Transparency = 0.4
	blob(model, Vector3.new(2.6, 0.5, 2.4), CFrame.new(0, -0.95, 0), mint).Transparency = 0.1
	return body
end

function builders.cat(model)
	local fur = Color3.fromRGB(255, 166, 82)
	local body = chibi(model, { color = fur, belly = Color3.fromRGB(255, 232, 200) })
	for _, side in ipairs({ -1, 1 }) do
		local ear = CFrame.new(side * 0.62, 1.12, 0.05) * CFrame.Angles(0, 0, math.rad(-side * 18))
		triangle(model, 0.75, 0.75, 0.24, ear, fur)
		triangle(model, 0.42, 0.45, 0.25, ear * CFrame.new(0, -0.08, -0.03), Color3.fromRGB(255, 170, 180))
	end
	-- ekor melengkung, ujungnya "kabel" menyala
	local tail = { { 0, -0.4, 1.2, 0.5 }, { 0.15, 0, 1.45, 0.45 }, { 0.3, 0.45, 1.55, 0.4 }, { 0.42, 0.9, 1.5, 0.38 } }
	for i, t in ipairs(tail) do
		blob(model, Vector3.new(t[4], t[4], t[4]), CFrame.new(t[1], t[2], t[3]), i == #tail and Color3.fromRGB(90, 190, 255) or fur,
			i == #tail and NEON or SMOOTH)
	end
	return body
end

function builders.dog(model)
	local fur = Color3.fromRGB(196, 146, 100)
	local body = chibi(model, { color = fur, belly = Color3.fromRGB(245, 226, 200), eyeY = 0.3 })
	blob(model, Vector3.new(0.8, 0.5, 0.45), CFrame.new(0, -0.06, frontZ(0, -0.06) + 0.08), Color3.fromRGB(245, 226, 200))
	blob(model, Vector3.new(0.26, 0.18, 0.14), CFrame.new(0, 0.06, frontZ(0, 0.06) - 0.1), INK)
	for _, side in ipairs({ -1, 1 }) do
		blob(model, Vector3.new(0.45, 1, 0.6), CFrame.new(side * 1.12, 0.35, 0.1) * CFrame.Angles(0, 0, math.rad(side * 20)),
			Color3.fromRGB(140, 96, 64))
	end
	-- antena router di kepala
	rod(model, 0.8, 0.12, CFrame.new(0.45, 1.35, 0.35), Color3.fromRGB(60, 60, 72))
	blob(model, Vector3.new(0.26, 0.26, 0.26), CFrame.new(0.45, 1.8, 0.35), Color3.fromRGB(90, 255, 140), NEON)
	blob(model, Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.1, 1.15), fur)
	return body
end

function builders.bird(model)
	local feather = Color3.fromRGB(96, 176, 255)
	local body = chibi(model, { color = feather, belly = Color3.fromRGB(225, 242, 255), feetColor = Color3.fromRGB(255, 176, 60), mouth = false })
	triangle(model, 0.42, 0.36, 0.3, CFrame.new(0, -0.05, frontZ(0, -0.05) - 0.08) * CFrame.Angles(math.rad(180), 0, 0),
		Color3.fromRGB(255, 176, 60))
	for _, side in ipairs({ -1, 1 }) do
		blob(model, Vector3.new(0.3, 1, 1.3), CFrame.new(side * 1.2, -0.05, 0.15) * CFrame.Angles(0, 0, math.rad(side * -25)),
			Color3.fromRGB(70, 140, 230))
	end
	for i, a in ipairs({ -20, 0, 20 }) do
		blob(model, Vector3.new(0.2, 0.6, 0.2), CFrame.new(0, 1.2, 0.1) * CFrame.Angles(0, 0, math.rad(a)) * CFrame.new(0, 0.2, 0),
			i == 2 and Color3.fromRGB(120, 255, 255) or feather, i == 2 and NEON or SMOOTH)
	end
	return body
end

function builders.robot(model)
	local metal = Color3.fromRGB(196, 204, 222)
	local body = newPart(model, Vector3.new(2.2, 2, 2), CFrame.new(), metal, Enum.Material.SmoothPlastic)
	newPart(model, Vector3.new(1.7, 0.85, 0.1), CFrame.new(0, 0.3, -1.02), Color3.fromRGB(28, 34, 52))
	for _, side in ipairs({ -1, 1 }) do
		newPart(model, Vector3.new(0.38, 0.22, 0.06), CFrame.new(side * 0.4, 0.32, -1.08), Color3.fromRGB(90, 240, 255), NEON)
		rod(model, 0.25, 0.6, CFrame.new(side * 1.15, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 130, 156))
	end
	for i = 1, 3 do
		newPart(model, Vector3.new(0.3, 0.1, 0.05), CFrame.new(-0.6 + i * 0.3, -0.45, -1.02), i == 2 and Color3.fromRGB(90, 255, 140)
			or Color3.fromRGB(255, 200, 70), NEON)
	end
	rod(model, 0.6, 0.1, CFrame.new(0, 1.3, 0), Color3.fromRGB(110, 118, 140))
	blob(model, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 1.65, 0), Color3.fromRGB(255, 90, 90), NEON)
	local jet = rod(model, 0.3, 1.1, CFrame.new(0, -1.15, 0), Color3.fromRGB(90, 200, 255), NEON)
	jet.Transparency = 0.3
	addEffect(jet, "none", Color3.fromRGB(90, 200, 255))
	return body
end

function builders.dragon(model)
	local scale = Color3.fromRGB(235, 80, 70)
	local body = chibi(model, { color = scale, belly = Color3.fromRGB(255, 214, 120) })
	for _, side in ipairs({ -1, 1 }) do
		blob(model, Vector3.new(0.22, 0.75, 0.3), CFrame.new(side * 0.45, 1.25, 0.25) * CFrame.Angles(math.rad(-25), 0, math.rad(side * -15)),
			Color3.fromRGB(255, 228, 170))
		local wing = CFrame.new(side * 1.05, 0.55, 0.75) * CFrame.Angles(0, math.rad(side * 25), math.rad(side * -35))
		blob(model, Vector3.new(0.18, 1.2, 1.3), wing, Color3.fromRGB(190, 50, 60))
	end
	local tail = blob(model, Vector3.new(0.5, 0.5, 0.9), CFrame.new(0, -0.6, 1.3) * CFrame.Angles(math.rad(-20), 0, 0), scale)
	local tip = blob(model, Vector3.new(0.3, 0.3, 0.3), tail.CFrame * CFrame.new(0, 0.15, 0.5), Color3.fromRGB(255, 180, 60), NEON)
	addEffect(tip, "fire", Color3.fromRGB(255, 120, 40))
	return body
end

function builders.unicorn(model)
	local body = chibi(model, { color = Color3.fromRGB(252, 250, 255), belly = Color3.fromRGB(255, 236, 246), eyeColor = Color3.fromRGB(90, 60, 140),
		feet = false })
	-- tanduk bertingkat warna emas
	for i = 0, 2 do
		rod(model, 0.32, 0.36 - i * 0.1, CFrame.new(0, 1.2 + i * 0.28, -0.25) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(255, 214, 90),
			i == 2 and NEON or SMOOTH)
	end
	local mane = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 200, 90), Color3.fromRGB(120, 220, 160), Color3.fromRGB(120, 170, 255) }
	for i, color in ipairs(mane) do
		blob(model, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.25, 1.05 - i * 0.22, 0.45 + i * 0.18), color)
	end
	for _, side in ipairs({ -1, 1 }) do
		triangle(model, 0.4, 0.5, 0.2, CFrame.new(side * 0.6, 1.1, 0.1), Color3.fromRGB(252, 250, 255))
	end
	-- awan tempat berpijak
	for i, p in ipairs({ { -0.8, 0.1 }, { 0, -0.2 }, { 0.8, 0.1 }, { 0.2, 0.6 } }) do
		blob(model, Vector3.new(1.2, 0.8, 1.1), CFrame.new(p[1], -1.15, p[2]), Color3.fromRGB(235, 244, 255))
	end
	addEffect(body, "sparkle", Color3.fromRGB(255, 170, 255))
	return body
end

function builders.phoenix(model)
	local gold = Color3.fromRGB(255, 176, 60)
	local body = chibi(model, { color = gold, belly = Color3.fromRGB(255, 236, 160), feet = false, mouth = false })
	triangle(model, 0.4, 0.34, 0.3, CFrame.new(0, -0.05, frontZ(0, -0.05) - 0.08) * CFrame.Angles(math.rad(180), 0, 0),
		Color3.fromRGB(255, 240, 200))
	for i, a in ipairs({ -28, 0, 28 }) do
		blob(model, Vector3.new(0.24, 0.8, 0.24), CFrame.new(0, 1.15, 0.15) * CFrame.Angles(0, 0, math.rad(a)) * CFrame.new(0, 0.3, 0),
			i == 2 and Color3.fromRGB(255, 90, 60) or Color3.fromRGB(255, 140, 60), NEON)
	end
	for _, side in ipairs({ -1, 1 }) do
		blob(model, Vector3.new(0.22, 1.1, 1.6), CFrame.new(side * 1.15, 0.25, 0.3) * CFrame.Angles(0, math.rad(side * 15), math.rad(side * -40)),
			Color3.fromRGB(255, 110, 50))
	end
	local tail
	for i, a in ipairs({ -18, 0, 18 }) do
		tail = blob(model, Vector3.new(0.3, 0.3, 1.5), CFrame.new(0, -0.4, 1.4) * CFrame.Angles(math.rad(25), math.rad(a), 0) * CFrame.new(0, 0, 0.4),
			i == 2 and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(255, 120, 60), NEON)
	end
	addEffect(tail, "fire", Color3.fromRGB(255, 150, 40))
	return body
end

function builders.galaxy(model)
	local body = chibi(model, { color = Color3.fromRGB(70, 50, 150), eyeColor = Color3.fromRGB(20, 10, 60), feet = false })
	local stars = { { -0.6, 0.8, -0.3 }, { 0.7, 0.75, 0.1 }, { 0.2, 1.0, 0.5 }, { -0.9, -0.2, 0.5 }, { 0.95, -0.3, 0.4 }, { -0.3, 0.5, 0.9 } }
	for _, s in ipairs(stars) do
		blob(model, Vector3.new(0.14, 0.14, 0.14), CFrame.new(s[1], s[2], s[3]), Color3.fromRGB(255, 255, 210), NEON)
	end
	local ring = newPart(model, Vector3.new(0.08, 3.6, 3.6), CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(14), 0, math.rad(90)),
		Color3.fromRGB(90, 230, 255), NEON)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.45
	blob(model, Vector3.new(0.5, 0.5, 0.5), CFrame.new(1.7, 0.6, 0.4), Color3.fromRGB(255, 170, 230), NEON)
	addEffect(body, "sparkle", Color3.fromRGB(170, 140, 255))
	return body
end

local function customAsset(id)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("AsetPet")
	local template = folder and folder:FindFirstChild(id)
	if template and template:IsA("Model") then
		local model = template:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		model.PrimaryPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		return model
	end
	return nil
end

-- Membuat model pet. Model menghadap -Z dengan titik pusat di badan pet.
function PetCatalog.Build(id)
	local pet = PetCatalog.Get(id) or PetCatalog.List[1]
	local custom = customAsset(pet.id)
	if custom then
		custom.Name = "Pet_" .. pet.id
		return custom
	end
	local model = Instance.new("Model")
	model.Name = "Pet_" .. pet.id
	local body = builders[pet.id](model)
	body.Name = "Badan"
	model.PrimaryPart = body
	model:ScaleTo(0.85)
	return model
end

return PetCatalog
