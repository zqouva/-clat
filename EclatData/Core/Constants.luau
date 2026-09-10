--!strict
--!optimize 2

-- Shared colors, sizes, fonts, and tween infos.

local Constants = {
	BlueNormal = Color3.fromRGB(43, 102, 255),
	BlueHover = Color3.fromRGB(64, 124, 255),
	BluePressed = Color3.fromRGB(30, 80, 210),

	RowDefault = Color3.fromRGB(17, 23, 48),
	RowHover = Color3.fromRGB(24, 32, 64),
	MenuDefault = Color3.fromRGB(20, 28, 58),
	MenuHover = Color3.fromRGB(28, 38, 76),
	HeaderDefault = Color3.fromRGB(16, 22, 46),
	HeaderHover = Color3.fromRGB(24, 30, 58),
	RootBackground = Color3.fromRGB(11, 15, 34),

	TextMain = Color3.fromRGB(238, 242, 255),
	TextDim = Color3.fromRGB(140, 155, 200),

	StrokeDefault = Color3.fromRGB(36, 52, 100),
	StrokeHover = Color3.fromRGB(52, 76, 140),
	StrokeFocus = Color3.fromRGB(41, 180, 255),
	StrokeSelected = Color3.fromRGB(90, 150, 255),
	StrokeInvalid = Color3.fromRGB(255, 86, 86),

	ToggleOff = Color3.fromRGB(30, 38, 70),
	ToggleOffHover = Color3.fromRGB(40, 50, 88),
	ToggleOffPressed = Color3.fromRGB(22, 28, 54),

	FontRegular = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	FontSemiBold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),

	RowSize = UDim2.new(1, 0, 0, 26),
	ItemSize = UDim2.new(1, 0, 0, 18),

	BubbleOn = UDim2.new(1, -6, 0.5, 0),
	BubbleOff = UDim.new(0, 6, 0.5, 0),

	FastInfo = TweenInfo.new(0.13, Enum.EasingStyle.Quart),
	SlowInfo = TweenInfo.new(0.30, Enum.EasingStyle.Quart),
	SmoothInfo = TweenInfo.new(0.20, Enum.EasingStyle.Quart),
	BounceInfo = TweenInfo.new(0.13, Enum.EasingStyle.Back),
}

return table.freeze(Constants)
