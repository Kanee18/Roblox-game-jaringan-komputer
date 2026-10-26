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
				bob = -2.1 + (moving and math.abs(math.sin(t * 9 + entry.seed)) * 0.6 or 0)
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
	local Ui, T = ctx.Ui, ctx.Theme

	-- MENU KOLEKSI
	local menu = ctx.makeModal("ModalPet", "🐾 KOLEKSI PET", 0.84, 0.84)
	local info = Ui.text({ Position = UDim2.new(0, 16, 0.1, 0), Size = UDim2.new(1, -32, 0.06, 0), TextColor3 = T.Sub,
		Font = Enum.Font.GothamMedium, MaxTextSize = 18, ZIndex = 5, Parent = menu })
	local grid = Ui.new("ScrollingFrame", { Position = UDim2.new(0.02, 0, 0.17, 0), Size = UDim2.new(0.96, 0, 0.8, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = menu })
	Ui.new("UIGridLayout", { CellSize = UDim2.new(0.32, 0, 0, 210), CellPadding = UDim2.new(0.013, 0, 0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

	local cards = {}
	for order, pet in ipairs(PetCatalog.List) do
		local rarityColor = PetCatalog.Rarities[pet.rarity]
		local card = Ui.new("Frame", { LayoutOrder = order, BackgroundColor3 = T.Panel2, BorderSizePixel = 0, ZIndex = 5, Parent = grid })
		Ui.corner(card, 12)
		local stroke = Ui.stroke(card, rarityColor, 2)
		local view = viewport(card, pet.id, { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 0, 110), ZIndex = 5 })
		local name = Ui.text({ Position = UDim2.new(0, 6, 0, 114), Size = UDim2.new(1, -12, 0, 22), Text = pet.name,
			MaxTextSize = 18, Font = Enum.Font.FredokaOne, ZIndex = 5, Parent = card })
		Ui.text({ Position = UDim2.new(0, 6, 0, 136), Size = UDim2.new(1, -12, 0, 16), Text = pet.rarity .. " • " ..
			(pet.xp == 0 and "Gratis" or (pet.xp .. " Poin Rank")), TextColor3 = rarityColor, MaxTextSize = 14, ZIndex = 5, Parent = card })
		local button = Ui.button({ Position = UDim2.new(0.1, 0, 0, 160), Size = UDim2.new(0.8, 0, 0, 38), Text = "",
			MaxTextSize = 16, ZIndex = 6 }, function()
			local xp = localPlayer:GetAttribute("PoinRank") or 0
			if PetCatalog.IsUnlocked(pet.id, xp) then
				ctx.remotes.EquipPet:FireServer(pet.id)
				ctx.play("Hint")
			else
				ctx.showToast("🔒 Masih terkunci", "Kumpulkan " .. (pet.xp - xp) .. " Poin Rank lagi untuk membuka " .. pet.name .. "!", T.Gold, 2.5)
			end
		end)
		button.Parent = card
		cards[pet.id] = { view = view, name = name, button = button, stroke = stroke, pet = pet }
	end

	local function refreshMenu()
		local xp = localPlayer:GetAttribute("PoinRank") or 0
		local equipped = localPlayer:GetAttribute("Pet")
		local nextPet = PetCatalog.Next(xp)
		info.Text = "🏅 Poin Rank kamu: " .. xp .. (nextPet and ("   •   Pet berikutnya: " .. nextPet.name .. " (" .. (nextPet.xp - xp)
			.. " poin lagi)") or "   •   👑 Semua pet sudah terbuka!")
		for id, card in pairs(cards) do
			local unlocked = PetCatalog.IsUnlocked(id, xp)
			card.view.ImageColor3 = unlocked and Color3.new(1, 1, 1) or Color3.new(0, 0, 0) -- siluet jika terkunci
			card.name.Text = unlocked and card.pet.name or "???"
			if id == equipped then
				card.button.Text = "✔ Dipakai"
				card.button.BackgroundColor3 = T.Good
			elseif unlocked then
				card.button.Text = "Pakai"
				card.button.BackgroundColor3 = T.Accent
			else
				card.button.Text = "🔒 " .. card.pet.xp
				card.button.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
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
		Ui.pop(menu, 0.85)
	end

	-- JENDELA PET BARU
	local popup = ctx.makeModal("ModalPetBaru", "🎉 PET BARU TERBUKA! 🎉", 0.5, 0.7)
	local popupHolder = Ui.new("Frame", { Position = UDim2.new(0.1, 0, 0.12, 0), Size = UDim2.new(0.8, 0, 0.55, 0),
		BackgroundTransparency = 1, ZIndex = 5, Parent = popup })
	local popupName = Ui.text({ Position = UDim2.new(0, 10, 0.68, 0), Size = UDim2.new(1, -20, 0.1, 0), Font = Enum.Font.FredokaOne,
		MaxTextSize = 34, ZIndex = 5, Parent = popup })
	local popupDesc = Ui.text({ Position = UDim2.new(0, 10, 0.78, 0), Size = UDim2.new(1, -20, 0.07, 0), TextColor3 = T.Sub,
		Font = Enum.Font.GothamMedium, MaxTextSize = 18, ZIndex = 5, Parent = popup })
	local collection = Ui.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(0.6, 0, 0.09, 0),
		Text = "🐾 Lihat Koleksi Pet", BackgroundColor3 = T.Good, ZIndex = 6 }, function()
		Pets.OpenMenu()
	end)
	collection.Parent = popup
	local popupCamera, spinStart = nil, 0
	RunService.RenderStepped:Connect(function()
		if popup.Visible and popupCamera then
			local angle = (os.clock() - spinStart) * 0.8
			popupCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * 7, 2, -math.cos(angle) * 7), Vector3.new(0, 0.3, 0))
		end
	end)

	local queue = {}
	local function showNext()
		local pet = table.remove(queue, 1)
		if not pet then
			return
		end
		Ui.clear(popupHolder)
		local _, camera = viewport(popupHolder, pet.id, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })
		popupCamera = camera
		spinStart = os.clock()
		local catalogPet = PetCatalog.Get(pet.id)
		popupName.Text = catalogPet.name
		popupName.TextColor3 = PetCatalog.Rarities[catalogPet.rarity]
		popupDesc.Text = catalogPet.rarity .. " • " .. catalogPet.desc
		ctx.closeAllModals()
		popup.Visible = true
		Ui.pop(popup, 0.5)
		ctx.play("Fanfare")
		if #queue > 0 then
			task.delay(4, showNext)
		end
	end

	function Pets.ShowUnlocked(list)
		for _, pet in ipairs(list) do
			table.insert(queue, pet)
		end
		showNext()
	end
end

return Pets
