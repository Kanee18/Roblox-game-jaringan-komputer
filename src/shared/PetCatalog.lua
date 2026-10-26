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
	{ id = "cat", name = "Kucing Kabel", xp = 300, rarity = "Biasa", flying = false,
		desc = "Ekornya kabel UTP yang menyala." },
	{ id = "dog", name = "Anjing Router", xp = 800, rarity = "Langka", flying = false,
		desc = "Selalu tahu rute tercepat menuju tuannya." },
	{ id = "bird", name = "Burung WiFi", xp = 1500, rarity = "Langka", flying = true,
		desc = "Terbang memancarkan sinyal ke mana-mana." },
	{ id = "robot", name = "Robot Server", xp = 2500, rarity = "Epik", flying = true,
		desc = "Melayani tuannya 24 jam tanpa lelah." },
	{ id = "dragon", name = "Naga Firewall", xp = 4000, rarity = "Epik", flying = true,
		desc = "Semburan apinya memblokir semua virus!" },
	{ id = "unicorn", name = "Unicorn Cloud", xp = 6000, rarity = "Legendaris", flying = true,
		desc = "Menyimpan semua datamu di atas awan." },
	{ id = "phoenix", name = "Phoenix Fiber Optik", xp = 9000, rarity = "Legendaris", flying = true,
		desc = "Secepat cahaya di dalam kabel serat optik." },
	{ id = "galaxy", name = "Galaksi Internet", xp = 13000, rarity = "Mitos", flying = true,
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
-- PEMBUAT MODEL PET (menghadap ke arah -Z)
---------------------------------------------------------------------
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local function newPart(model, size, cframe, color, material)
	local part = Instance.new("Part")
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
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- bola/elips (pakai SpecialMesh agar bisa lonjong)
local function blob(model, size, cframe, color, material)
	local part = newPart(model, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function block(model, size, cframe, color, material)
	return newPart(model, size, cframe, color, material)
end

local function cylinder(model, length, thickness, cframe, color, material)
	-- silinder Roblox memanjang di sumbu X; diputar agar tegak (sumbu Y)
	local part = newPart(model, Vector3.new(length, thickness, thickness), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function wedge(model, size, cframe, color, material)
	local part = Instance.new("WedgePart")
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

local function eyes(model, center, spacing, size)
	for _, side in ipairs({ -1, 1 }) do
		local eye = blob(model, Vector3.new(size, size, size * 0.6), center * CFrame.new(side * spacing, 0, 0), Color3.fromRGB(20, 20, 30))
		blob(model, Vector3.new(size * 0.35, size * 0.35, size * 0.2), eye.CFrame * CFrame.new(size * 0.15, size * 0.18, -size * 0.25),
			Color3.new(1, 1, 1), NEON)
	end
end

local function addEffect(body, kind, color)
	if kind == "sparkle" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = body
	elseif kind == "fire" then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Color = color
		fire.SecondaryColor = Color3.fromRGB(255, 230, 120)
		fire.Parent = body
	end
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Brightness = 1.2
	light.Color = color
	light.Parent = body
end

local builders = {}

function builders.slime(model)
	local body = blob(model, Vector3.new(2, 1.6, 2), CFrame.new(), Color3.fromRGB(110, 230, 120))
	body.Transparency = 0.15
	blob(model, Vector3.new(0.8, 0.5, 0.8), CFrame.new(0.3, 0.55, 0.2), Color3.fromRGB(180, 255, 180)).Transparency = 0.3
	eyes(model, CFrame.new(0, 0.15, -0.85), 0.35, 0.35)
	cylinder(model, 0.6, 0.12, CFrame.new(0, 1, 0), Color3.fromRGB(60, 160, 70))
	blob(model, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 1.35, 0), Color3.fromRGB(255, 255, 120), NEON)
	return body
end

function builders.cat(model)
	local fur = Color3.fromRGB(255, 160, 70)
	local body = blob(model, Vector3.new(1.4, 1.2, 1.9), CFrame.new(), fur)
	local head = blob(model, Vector3.new(1.3, 1.2, 1.2), CFrame.new(0, 0.6, -0.9), fur)
	for _, side in ipairs({ -1, 1 }) do
		wedge(model, Vector3.new(0.2, 0.5, 0.35), head.CFrame * CFrame.new(side * 0.38, 0.6, 0) * CFrame.Angles(0, math.rad(90), 0), fur)
		cylinder(model, 0.5, 0.25, CFrame.new(side * 0.4, -0.55, -0.5), fur)
		cylinder(model, 0.5, 0.25, CFrame.new(side * 0.4, -0.55, 0.5), fur)
	end
	eyes(model, head.CFrame * CFrame.new(0, 0.1, -0.5), 0.27, 0.28)
	blob(model, Vector3.new(0.18, 0.14, 0.12), head.CFrame * CFrame.new(0, -0.1, -0.6), Color3.fromRGB(255, 120, 160))
	-- ekor kabel menyala
	cylinder(model, 1.3, 0.2, CFrame.new(0, 0.5, 1.1) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(70, 160, 255), NEON)
	blob(model, Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 1.05, 1.5), Color3.fromRGB(150, 220, 255), NEON)
	return body
end

function builders.dog(model)
	local fur = Color3.fromRGB(170, 120, 80)
	local body = blob(model, Vector3.new(1.5, 1.3, 2), CFrame.new(), fur)
	local head = blob(model, Vector3.new(1.3, 1.2, 1.3), CFrame.new(0, 0.7, -1), fur)
	blob(model, Vector3.new(0.7, 0.5, 0.6), head.CFrame * CFrame.new(0, -0.2, -0.55), Color3.fromRGB(230, 200, 170))
	blob(model, Vector3.new(0.25, 0.2, 0.15), head.CFrame * CFrame.new(0, -0.05, -0.85), Color3.fromRGB(30, 30, 30))
	for _, side in ipairs({ -1, 1 }) do
		blob(model, Vector3.new(0.3, 0.8, 0.5), head.CFrame * CFrame.new(side * 0.65, -0.1, 0) * CFrame.Angles(0, 0, math.rad(side * 15)),
			Color3.fromRGB(120, 80, 50))
		cylinder(model, 0.55, 0.3, CFrame.new(side * 0.45, -0.6, -0.55), fur)
		cylinder(model, 0.55, 0.3, CFrame.new(side * 0.45, -0.6, 0.55), fur)
	end
	eyes(model, head.CFrame * CFrame.new(0, 0.2, -0.55), 0.28, 0.27)
	-- antena router
	cylinder(model, 0.9, 0.1, head.CFrame * CFrame.new(0.3, 0.9, 0.1), Color3.fromRGB(40, 40, 50))
	blob(model, Vector3.new(0.25, 0.25, 0.25), head.CFrame * CFrame.new(0.3, 1.4, 0.1), Color3.fromRGB(80, 255, 120), NEON)
	cylinder(model, 0.8, 0.2, CFrame.new(0, 0.4, 1.1) * CFrame.Angles(math.rad(-40), 0, 0), fur)
	return body
end

function builders.bird(model)
	local feather = Color3.fromRGB(60, 150, 255)
	local body = blob(model, Vector3.new(1.3, 1.3, 1.5), CFrame.new(), feather)
	blob(model, Vector3.new(0.9, 0.8, 0.6), CFrame.new(0, -0.2, -0.5), Color3.fromRGB(200, 230, 255))
	wedge(model, Vector3.new(0.3, 0.25, 0.4), CFrame.new(0, 0.05, -0.85) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(255, 170, 40))
	eyes(model, CFrame.new(0, 0.3, -0.6), 0.3, 0.25)
	for _, side in ipairs({ -1, 1 }) do
		blob(model, Vector3.new(0.25, 0.7, 1.2), CFrame.new(side * 0.75, 0.15, 0.1) * CFrame.Angles(0, 0, math.rad(side * -35)), feather)
	end
	blob(model, Vector3.new(0.5, 0.2, 0.8), CFrame.new(0, 0.1, 0.85), Color3.fromRGB(30, 100, 220))
	-- lengkung sinyal WiFi di atas kepala
	for i = 1, 3 do
		block(model, Vector3.new(0.3 + i * 0.3, 0.08, 0.08), CFrame.new(0, 0.75 + i * 0.2, -0.1), Color3.fromRGB(120, 255, 255), NEON)
	end
	return body
end

function builders.robot(model)
	local metal = Color3.fromRGB(160, 170, 190)
	local body = block(model, Vector3.new(1.4, 1.5, 1.1), CFrame.new(), metal, Enum.Material.Metal)
	for i = 1, 3 do
		block(model, Vector3.new(0.9, 0.1, 0.05), CFrame.new(0, 0.45 - i * 0.3, -0.56),
			i % 2 == 0 and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(70, 170, 255), NEON)
	end
	local head = block(model, Vector3.new(1.1, 0.85, 0.95), CFrame.new(0, 1.25, 0), Color3.fromRGB(120, 130, 150), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		block(model, Vector3.new(0.25, 0.18, 0.05), head.CFrame * CFrame.new(side * 0.25, 0.05, -0.49), Color3.fromRGB(0, 255, 255), NEON)
		cylinder(model, 0.8, 0.22, CFrame.new(side * 0.85, 0, 0) * CFrame.Angles(0, 0, math.rad(side * 15)), metal, Enum.Material.Metal)
	end
	block(model, Vector3.new(0.5, 0.08, 0.05), head.CFrame * CFrame.new(0, -0.22, -0.49), Color3.fromRGB(40, 40, 50))
	cylinder(model, 0.6, 0.08, head.CFrame * CFrame.new(0, 0.7, 0), Color3.fromRGB(60, 60, 70))
	blob(model, Vector3.new(0.25, 0.25, 0.25), head.CFrame * CFrame.new(0, 1.05, 0), Color3.fromRGB(255, 80, 80), NEON)
	addEffect(body, "none", Color3.fromRGB(80, 200, 255))
	return body
end

function builders.dragon(model)
	local scale = Color3.fromRGB(220, 50, 50)
	local body = blob(model, Vector3.new(1.4, 1.3, 2.1), CFrame.new(), scale)
	blob(model, Vector3.new(0.9, 0.8, 1.6), CFrame.new(0, -0.25, -0.1), Color3.fromRGB(255, 200, 100))
	local head = blob(model, Vector3.new(1.1, 1, 1.4), CFrame.new(0, 0.75, -1.1), scale)
	eyes(model, head.CFrame * CFrame.new(0, 0.2, -0.55), 0.3, 0.25)
	for _, side in ipairs({ -1, 1 }) do
		cylinder(model, 0.6, 0.14, head.CFrame * CFrame.new(side * 0.3, 0.6, 0.3) * CFrame.Angles(math.rad(-30), 0, 0),
			Color3.fromRGB(255, 220, 90))
		wedge(model, Vector3.new(0.1, 1.2, 1.8), CFrame.new(side * 1, 0.6, 0.2) * CFrame.Angles(0, 0, math.rad(side * -40)),
			Color3.fromRGB(150, 20, 30))
	end
	blob(model, Vector3.new(0.5, 0.5, 1.4), CFrame.new(0, 0.1, 1.4) * CFrame.Angles(math.rad(20), 0, 0), scale)
	addEffect(body, "fire", Color3.fromRGB(255, 120, 30))
	return body
end

function builders.unicorn(model)
	local white = Color3.fromRGB(250, 248, 255)
	local body = blob(model, Vector3.new(1.4, 1.3, 2), CFrame.new(), white)
	local head = blob(model, Vector3.new(1, 1.1, 1.3), CFrame.new(0, 0.85, -1), white)
	eyes(model, head.CFrame * CFrame.new(0, 0.2, -0.5), 0.27, 0.25)
	cylinder(model, 0.9, 0.16, head.CFrame * CFrame.new(0, 0.85, -0.25) * CFrame.Angles(math.rad(-25), 0, 0),
		Color3.fromRGB(255, 120, 220), NEON)
	local mane = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 200, 70), Color3.fromRGB(90, 220, 140), Color3.fromRGB(90, 160, 255) }
	for i, color in ipairs(mane) do
		blob(model, Vector3.new(0.35, 0.35, 0.35), head.CFrame * CFrame.new(0, 0.5 - i * 0.18, 0.4 + i * 0.12), color, NEON)
	end
	-- awan di bawah kaki
	for i = -1, 1 do
		blob(model, Vector3.new(1.2, 0.6, 1.2), CFrame.new(i * 0.7, -0.75, i * 0.3), Color3.fromRGB(235, 245, 255))
	end
	addEffect(body, "sparkle", Color3.fromRGB(255, 150, 255))
	return body
end

function builders.phoenix(model)
	local gold = Color3.fromRGB(255, 170, 40)
	local body = blob(model, Vector3.new(1.3, 1.3, 1.8), CFrame.new(), gold, NEON)
	local head = blob(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.7, -0.9), Color3.fromRGB(255, 120, 40))
	eyes(model, head.CFrame * CFrame.new(0, 0.1, -0.4), 0.22, 0.2)
	wedge(model, Vector3.new(0.25, 0.2, 0.4), head.CFrame * CFrame.new(0, -0.1, -0.55) * CFrame.Angles(0, math.rad(180), 0),
		Color3.fromRGB(255, 240, 150))
	for _, side in ipairs({ -1, 1 }) do
		wedge(model, Vector3.new(0.1, 1.4, 2), CFrame.new(side * 1.1, 0.5, 0.3) * CFrame.Angles(0, 0, math.rad(side * -55)),
			Color3.fromRGB(255, 90, 30), NEON)
	end
	for i = -1, 1 do
		cylinder(model, 1.6, 0.12, CFrame.new(i * 0.25, -0.1, 1.5) * CFrame.Angles(math.rad(70), math.rad(i * 15), 0),
			Color3.fromRGB(255, 230, 120), NEON)
	end
	addEffect(body, "fire", Color3.fromRGB(255, 160, 40))
	return body
end

function builders.galaxy(model)
	local body = blob(model, Vector3.new(1.8, 1.8, 1.8), CFrame.new(), Color3.fromRGB(140, 80, 255), Enum.Material.ForceField)
	blob(model, Vector3.new(1.1, 1.1, 1.1), CFrame.new(), Color3.fromRGB(80, 40, 200), NEON)
	eyes(model, CFrame.new(0, 0.15, -0.6), 0.25, 0.25)
	local ring1 = newPart(model, Vector3.new(0.08, 3.2, 3.2), CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0),
		Color3.fromRGB(0, 230, 255), NEON)
	ring1.Shape = Enum.PartType.Cylinder
	ring1.Transparency = 0.5
	local ring2 = newPart(model, Vector3.new(0.08, 2.6, 2.6), CFrame.Angles(math.rad(70), 0, math.rad(90)),
		Color3.fromRGB(255, 80, 200), NEON)
	ring2.Shape = Enum.PartType.Cylinder
	ring2.Transparency = 0.5
	for i = 1, 4 do
		local angle = i * math.pi / 2
		blob(model, Vector3.new(0.3, 0.3, 0.3), CFrame.new(math.cos(angle) * 1.6, math.sin(angle) * 0.4, math.sin(angle) * 1.6),
			Color3.fromRGB(255, 255, 200), NEON)
	end
	addEffect(body, "sparkle", Color3.fromRGB(160, 120, 255))
	return body
end

-- Membuat model pet. Model menghadap -Z dengan titik pusat di badan pet.
function PetCatalog.Build(id)
	local pet = PetCatalog.Get(id) or PetCatalog.List[1]
	local model = Instance.new("Model")
	model.Name = "Pet_" .. pet.id
	local body = builders[pet.id](model)
	body.Name = "Badan"
	model.PrimaryPart = body
	return model
end

return PetCatalog
