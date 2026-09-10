--!strict
--!optimize 2

-- Shared colors, sizes, fonts, and tween infos.

local Constants = {
	BlueNormal = Color3.fromRGB(71, 129, 255),
	BlueHover = Color3.fromRGB(86, 143, 255),
	BluePressed = Color3.fromRGB(58, 109, 218),

	RowDefault = Color3.fromRGB(25, 26, 31),
	RowHover = Color3.fromRGB(32, 34, 40),
	MenuDefault = Color3.fromRGB(39, 41, 48),
	MenuHover = Color3.fromRGB(45, 48, 56),
	HeaderDefault = Color3.fromRGB(32, 34, 39),
	HeaderHover = Color3.fromRGB(35, 38, 43),
	RootBackground = Color3.fromRGB(22, 23, 28),

	TextMain = Color3.fromRGB(222, 222, 222),
	TextDim = Color3.fromRGB(150, 152, 162),

	StrokeDefault = Color3.fromRGB(54, 56, 66),
	StrokeHover = Color3.fromRGB(77, 80, 94),
	StrokeFocus = Color3.fromRGB(41, 180, 255),
	StrokeSelected = Color3.fromRGB(88, 146, 255),
	StrokeInvalid = Color3.fromRGB(255, 86, 86),

	ToggleOff = Color3.fromRGB(40, 41, 49),
	ToggleOffHover = Color3.fromRGB(55, 57, 66),
	ToggleOffPressed = Color3.fromRGB(31, 32, 39),

	FontRegular = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	FontSemiBold = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),

	RowSize = UDim2.new(1, 0, 0, 26),
	ItemSize = UDim2.new(1, 0, 0, 18),

	BubbleOn = UDim2.new(1, -6, 0.5, 0),
	BubbleOff = UDim2.new(0, 6, 0.5, 0),

	FastInfo = TweenInfo.new(0.13, Enum.EasingStyle.Quart),
	SlowInfo = TweenInfo.new(0.30, Enum.EasingStyle.Quart),
	SmoothInfo = TweenInfo.new(0.20, Enum.EasingStyle.Quart),
	BounceInfo = TweenInfo.new(0.13, Enum.EasingStyle.Back),
}

return table.freeze(Constants)
