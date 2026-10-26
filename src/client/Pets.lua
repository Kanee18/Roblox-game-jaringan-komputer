--[[
	Pets (client): menggambar pet yang mengikuti setiap pemain, menu koleksi pet,
	dan jendela "PET BARU TERBUKA!".
	Pet digambar di setiap layar secara lokal (ringan, tidak membebani server).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetCatalog = require(ReplicatedStorage:WaitForChild("QuizShared"):WaitForChild("PetCatalog"))

local Pets = {}

local localPlayer = Players.LocalPlayer
local active = {} -- [Player] = { model, petId, character, cframe }
local petFolder = Instance.new("Folder")
petFolder.Name = "PetLokal"
petFolder.Parent = workspace

---------------------------------------------------------------------
-- PET MENGIKUTI PEMAIN
---------------------------------------------------------------------
local function removePet(player)
	local entry = active[player]
	if entry then
		entry.model:Destroy()
		active[player] = nil
	end
end

local function refresh(player)
	local petId = player:GetAttribute("Pet")
	local character = player.Character
	local entry = active[player]
	if entry and (entry.petId ~= petId or entry.character ~= character) then
		removePet(player)
		entry = nil
	end
	if entry or not petId or petId == "" or not character or not PetCatalog.Get(petId) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local model = PetCatalog.Build(petId)
	local start = root and root.CFrame * CFrame.new(3, 0, 3) or CFrame.new()
	model:PivotTo(start)
	model.Parent = petFolder
	active[player] = { model = model, petId = petId, character = character, cframe = start, seed = math.random() * 10 }
end

local function watchPlayer(player)
	player:GetAttributeChangedSignal("Pet"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		refresh(player)
	end)
	player.CharacterRemoving:Connect(function()
		removePet(player)
	end)
	refresh(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(removePet)

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local cameraPos = camera and camera.CFrame.Position or Vector3.zero
	local t = os.clock()
	for player, entry in pairs(active) do
		local root = entry.character and entry.character:FindFirstChild("HumanoidRootPart")
		if not root or not entry.model.Parent then
			removePet(player)
		elseif (root.Position - cameraPos).Magnitude < 160 then
			local info = PetCatalog.Get(entry.petId)
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude < 0.1 then
				look = Vector3.new(0, 0, -1)
			end
			local base = CFrame.lookAt(root.Position, root.Position + look.Unit)
			local moving = root.AssemblyLinearVelocity.Magnitude > 2
			local bob
			if info.flying then
				bob = 1.6 + math.sin(t * 2.5 + entry.seed) * 0.5
			else
				bob = -1.95 + (moving and math.abs(math.sin(t * 9 + entry.seed)) * 0.6 or 0)
			end
			local target = base * CFrame.new(3, bob, 3)
			entry.cframe = entry.cframe:Lerp(target, math.clamp(dt * 7, 0, 1))
			entry.model:PivotTo(entry.cframe)
		end
	end
end)


---------------------------------------------------------------------
-- PRATINJAU PET (ViewportFrame)
---------------------------------------------------------------------
local function viewport(parent, petId, props)
	local frame = Instance.new("ViewportFrame")
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(200, 200, 210)
	frame.LightColor = Color3.new(1, 1, 1)
	frame.LightDirection = Vector3.new(-1, -1, 1)
	for key, value in pairs(props or {}) do
		frame[key] = value
	end
	local model = PetCatalog.Build(petId)
	model:PivotTo(CFrame.new())
	model.Parent = frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(3.2, 1.8, -6.5), Vector3.new(0, 0.3, 0))
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = parent
	return frame, camera
end

---------------------------------------------------------------------
-- MENU KOLEKSI & JENDELA PET BARU
---------------------------------------------------------------------
function Pets.Init(ctx)
	local Ui = ctx.Ui
	local T, F = Ui.Theme, Ui.Font
	local LOCKED_TINT = Color3.fromRGB(44, 48, 78)

	-- MENU KOLEKSI (920 x 580; area konten 516 tinggi)
	local menu, _, menuContent = ctx.makeModal("ModalPet", "Koleksi Pet", 920, 580)

	local strip = Ui.new("Frame", { Name = "Ringkasan", Position = UDim2.fromOffset(24, 16), Size = UDim2.new(1, -48, 0, 72),
		BackgroundColor3 = T.Paper2, BorderSizePixel = 0, ZIndex = 5, Parent = menuContent })
	Ui.corner(strip, 16)
	Ui.text({ Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(200, 16), Text = "POIN RANK KAMU", Font = F.Black, TextSize = 13,
		TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = strip })
	local xpLabel = Ui.text({ Position = UDim2.fromOffset(20, 28), Size = UDim2.fromOffset(200, 34), Text = "0", Font = F.Display, TextSize = 30,
		TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = strip })
	local nextLabel = Ui.text({ Position = UDim2.fromOffset(240, 14), Size = UDim2.new(1, -460, 0, 18), Text = "", Font = F.Bold, TextSize = 15,
		TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = strip })
	local nextBack, nextFill = Ui.bar({ Position = UDim2.fromOffset(240, 42), Size = UDim2.new(1, -460, 0, 10), ZIndex = 5 }, T.Pink, T.Line)
	nextBack.Parent = strip
	nextFill.ZIndex = 5
	local remainLabel = Ui.text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(190, 40),
		Text = "", Font = F.Black, TextSize = 16, TextColor3 = T.Pink, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5, Parent = strip })

	local grid = Ui.new("ScrollingFrame", { Position = UDim2.fromOffset(24, 104), Size = UDim2.new(1, -48, 1, -116), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = T.InkSoft, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = menuContent })
	Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(164, 192), CellPadding = UDim2.fromOffset(10, 12), SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid })

	local cards = {}
	for order, pet in ipairs(PetCatalog.List) do
		local rarityColor = PetCatalog.Rarities[pet.rarity]
		local card = Ui.new("Frame", { Name = pet.id, LayoutOrder = order, BackgroundColor3 = T.Paper, BorderSizePixel = 0, ZIndex = 5,
			Parent = grid })
		Ui.corner(card, 16)
		local stroke = Ui.stroke(card, T.Line, 1.5)
		local stage = Ui.new("Frame", { Name = "Panggung", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 96),
			BackgroundColor3 = rarityColor, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 5, Parent = card })
		Ui.corner(stage, 12)
		local view = viewport(stage, pet.id, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
		Ui.chip({ Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(0, 20), Text = string.upper(pet.rarity), TextSize = 11, ZIndex = 6,
			Parent = stage }, Ui.darker(rarityColor, 0.3))
		local name = Ui.text({ Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 22), Text = pet.name, Font = F.Display,
			TextSize = 17, Scaled = true, MaxTextSize = 17, TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
			Parent = card })
		local requirement = Ui.text({ Position = UDim2.fromOffset(10, 132), Size = UDim2.new(1, -20, 0, 16), Text = "", Font = F.Medium,
			TextSize = 13, TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = card })
		local button = Ui.button({ Position = UDim2.new(0, 8, 1, -38), Size = UDim2.new(1, -16, 0, 30), Text = "", TextSize = 14, Radius = 10,
			ZIndex = 6 }, function()
			local xp = localPlayer:GetAttribute("PoinRank") or 0
			if PetCatalog.IsUnlocked(pet.id, xp) then
				ctx.remotes.EquipPet:FireServer(pet.id)
				ctx.play("Hint")
			else
				ctx.showToast("Masih terkunci", "Kumpulkan " .. Ui.number(pet.xp - xp) .. " Poin Rank lagi untuk membuka pet ini.", T.Gold, 2.5)
			end
		end)
		button.Parent = card
		cards[pet.id] = { view = view, stage = stage, name = name, requirement = requirement, button = button, stroke = stroke, pet = pet,
			color = rarityColor }
	end

	local function refreshMenu()
		local xp = localPlayer:GetAttribute("PoinRank") or 0
		local equipped = localPlayer:GetAttribute("Pet")
		local nextPet = PetCatalog.Next(xp)
		xpLabel.Text = Ui.number(xp)
		if nextPet then
			local previous = 0
			for _, pet in ipairs(PetCatalog.List) do
				if pet.xp <= xp then
					previous = pet.xp
				end
			end
			nextLabel.Text = "Pet berikutnya: " .. nextPet.name
			nextFill.Size = UDim2.fromScale(math.clamp((xp - previous) / math.max(1, nextPet.xp - previous), 0, 1), 1)
			remainLabel.Text = Ui.number(nextPet.xp - xp) .. " poin lagi"
		else
			nextLabel.Text = "Semua pet sudah terbuka. Hebat!"
			nextFill.Size = UDim2.fromScale(1, 1)
			remainLabel.Text = "KOLEKSI LENGKAP"
		end
		for id, card in pairs(cards) do
			local unlocked = PetCatalog.IsUnlocked(id, xp)
			-- pet terkunci tampil sebagai siluet
			card.view.ImageColor3 = unlocked and Color3.new(1, 1, 1) or LOCKED_TINT
			card.view.ImageTransparency = unlocked and 0 or 0.15
			card.stage.BackgroundColor3 = unlocked and card.color or T.Line
			card.name.Text = unlocked and card.pet.name or "???"
			card.requirement.Text = card.pet.xp == 0 and "Pet awal" or (Ui.number(card.pet.xp) .. " Poin Rank")
			card.stroke.Color = id == equipped and T.Good or T.Line
			card.stroke.Thickness = id == equipped and 2.5 or 1.5
			if id == equipped then
				card.button.Text = "DIPAKAI"
				card.button.BackgroundColor3 = T.Good
				card.button.TextColor3 = T.White
			elseif unlocked then
				card.button.Text = "PAKAI"
				card.button.BackgroundColor3 = T.Primary
				card.button.TextColor3 = T.White
			else
				card.button.Text = "TERKUNCI"
				card.button.BackgroundColor3 = T.Paper2
				card.button.TextColor3 = T.InkSoft
			end
		end
	end
	localPlayer:GetAttributeChangedSignal("PoinRank"):Connect(refreshMenu)
	localPlayer:GetAttributeChangedSignal("Pet"):Connect(refreshMenu)
	refreshMenu()

	function Pets.OpenMenu()
		ctx.closeAllModals()
		refreshMenu()
		menu.Visible = true
		Ui.pop(menu, 0.9)
	end

	-- JENDELA PET BARU (520 x 540; area konten 476 tinggi)
	local popup, _, popupContent = ctx.makeModal("ModalPetBaru", "Pet Baru Terbuka!", 520, 540, T.Pink)
	popup.ZIndex = 7 -- tampil di atas jendela Hasil Akhir; menutupnya kembali ke hasil
	local popupStage = Ui.new("Frame", { Name = "Panggung", Position = UDim2.fromOffset(24, 20), Size = UDim2.new(1, -48, 0, 250),
		BackgroundColor3 = T.White, BorderSizePixel = 0, ZIndex = 5, Parent = popupContent })
	Ui.corner(popupStage, 18)
	local popupGradient = Ui.new("UIGradient", { Rotation = 90, Parent = popupStage })
	local popupView = Ui.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = popupStage })
	local popupChip = Ui.chip({ Position = UDim2.fromOffset(14, 14), Text = "", TextSize = 12, ZIndex = 6, Parent = popupStage }, T.Primary)
	local popupName = Ui.text({ Position = UDim2.fromOffset(24, 284), Size = UDim2.new(1, -48, 0, 40), Text = "", Font = F.Display, TextSize = 32,
		Scaled = true, MaxTextSize = 32, TextColor3 = T.Ink, ZIndex = 5, Parent = popupContent })
	local popupDesc = Ui.text({ Position = UDim2.fromOffset(40, 326), Size = UDim2.new(1, -80, 0, 44), Text = "", Font = F.Medium, TextSize = 17,
		TextColor3 = T.InkSoft, ZIndex = 5, Parent = popupContent })
	local equipNow
	local collection = Ui.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -24), Size = UDim2.new(0.5, -30, 0, 52),
		Text = "LIHAT KOLEKSI", TextSize = 17, ZIndex = 6 }, function()
		Pets.OpenMenu()
	end, "neutral")
	collection.Parent = popupContent
	equipNow = Ui.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.new(0.5, -30, 0, 52),
		Text = "PAKAI SEKARANG", TextSize = 17, ZIndex = 6 }, nil, "success")
	equipNow.Parent = popupContent

	local popupCamera, spinStart, popupPetId = nil, 0, nil
	equipNow.Activated:Connect(function()
		if popupPetId then
			ctx.remotes.EquipPet:FireServer(popupPetId)
			ctx.play("Hint")
		end
		popup.Visible = false
	end)
	RunService.RenderStepped:Connect(function()
		if popup.Visible and popupCamera then
			local angle = (os.clock() - spinStart) * 0.8
			popupCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * 7, 2, -math.cos(angle) * 7), Vector3.new(0, 0.3, 0))
		end
	end)

	local queue = {}
	local showing = false
	local function showNext()
		local pet = table.remove(queue, 1)
		if not pet then
			showing = false
			return
		end
		showing = true
		local catalogPet = PetCatalog.Get(pet.id)
		if not catalogPet then
			showNext()
			return
		end
		local rarityColor = PetCatalog.Rarities[catalogPet.rarity]
		Ui.clear(popupView)
		local _, camera = viewport(popupView, catalogPet.id, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
		popupCamera = camera
		spinStart = os.clock()
		popupPetId = catalogPet.id
		popupGradient.Color = ColorSequence.new(rarityColor:Lerp(T.White, 0.55), rarityColor:Lerp(T.White, 0.85))
		popupChip.Text = string.upper(catalogPet.rarity)
		popupChip.BackgroundColor3 = Ui.darker(rarityColor, 0.3)
		popupName.Text = catalogPet.name
		popupDesc.Text = catalogPet.desc
		popup.Visible = true
		Ui.pop(popup, 0.6)
		ctx.play("Fanfare")
		if #queue > 0 then
			task.delay(4, showNext)
		else
			showing = false
		end
	end

	function Pets.ShowUnlocked(list)
		for _, pet in ipairs(list) do
			table.insert(queue, pet)
		end
		if not showing then
			showNext()
		end
	end
end

return Pets
