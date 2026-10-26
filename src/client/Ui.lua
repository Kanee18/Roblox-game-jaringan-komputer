-- Ui: fungsi bantu kecil untuk membuat antarmuka dengan kode.

local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.Theme = {
	Panel = Color3.fromRGB(18, 22, 46),
	Panel2 = Color3.fromRGB(30, 36, 72),
	Stroke = Color3.fromRGB(90, 120, 220),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(170, 190, 235),
	Accent = Color3.fromRGB(70, 160, 255),
	Good = Color3.fromRGB(60, 220, 120),
	Bad = Color3.fromRGB(255, 80, 95),
	Gold = Color3.fromRGB(255, 205, 60),
	Pink = Color3.fromRGB(255, 80, 200),
}

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
		Color = color or Ui.Theme.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Ui.maxText(parent, max, min)
	return Ui.new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min or 8, Parent = parent })
end

function Ui.sizeLimit(parent, minSize, maxSize)
	return Ui.new("UISizeConstraint", { MinSize = minSize, MaxSize = maxSize, Parent = parent })
end

function Ui.padding(parent, px)
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function Ui.panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Ui.Theme.Panel
	props.BorderSizePixel = 0
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 0.08
	end
	local frame = Ui.new("Frame", props)
	Ui.corner(frame, 14)
	Ui.stroke(frame, Ui.Theme.Stroke, 2, 0.3)
	return frame
end

function Ui.text(props)
	local max = props.MaxTextSize
	props.MaxTextSize = nil
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Ui.Theme.Text
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	if props.TextWrapped == nil then
		props.TextWrapped = true
	end
	props.Text = props.Text or ""
	local label = Ui.new("TextLabel", props)
	if max then
		Ui.maxText(label, max)
	end
	return label
end

function Ui.button(props, onClick)
	local max = props.MaxTextSize or 22
	props.MaxTextSize = nil
	props.BackgroundColor3 = props.BackgroundColor3 or Ui.Theme.Accent
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Ui.Theme.Text
	props.TextScaled = true
	props.TextWrapped = true
	props.AutoButtonColor = true
	local button = Ui.new("TextButton", props)
	Ui.corner(button, 10)
	Ui.maxText(button, max)
	Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = button })
	local scale = Ui.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(scale, 0.12, { Scale = 1 })
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Ui.tween(inst, time, goal, style, direction)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out), goal)
	tween:Play()
	return tween
end

-- Animasi "muncul" (membesar sedikit lalu normal)
function Ui.pop(inst, from)
	local scale = inst:FindFirstChild("PopScale") or Ui.new("UIScale", { Name = "PopScale", Parent = inst })
	scale.Scale = from or 0.6
	Ui.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Ui.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Ui
