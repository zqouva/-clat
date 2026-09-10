--!strict
--!optimize 2

-- Palettes for every theme. setTheme swaps the live values,
-- so this table is never frozen.

local TweenFast = TweenInfo.new(0.13, Enum.EasingStyle.Quart)
local TweenSlow = TweenInfo.new(0.30, Enum.EasingStyle.Quart)
local TweenSmooth = TweenInfo.new(0.20, Enum.EasingStyle.Quart)
local TweenBounce = TweenInfo.new(0.13, Enum.EasingStyle.Back)

local SourceRegular = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local SourceSemiBold = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
local MontserratSemiBold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
local GothamBold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local MontserratRegular = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local ArcadeFont = Font.fromEnum(Enum.Font.Arcade)

local Shared = {
	RowSize = UDim2.new(1, 0, 0, 26),
	ItemSize = UDim2.new(1, 0, 0, 18),

	BubbleOn = UDim2.new(1, -6, 0.5, 0),
	BubbleOff = UDim2.new(0, 6, 0.5, 0),

	FastInfo = TweenFast,
	SlowInfo = TweenSlow,
	SmoothInfo = TweenSmooth,
	BounceInfo = TweenBounce,
}

local Themes: { [string]: { [string]: any } } = {
	Persona = {
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

		FontRegular = SourceRegular,
		FontSemiBold = MontserratSemiBold,
	},
	Eclat = {
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

		FontRegular = SourceRegular,
		FontSemiBold = SourceSemiBold,
	},
	Pixel = {
		BlueNormal = Color3.fromRGB(57, 255, 113),
		BlueHover = Color3.fromRGB(110, 255, 150),
		BluePressed = Color3.fromRGB(30, 180, 70),

		RowDefault = Color3.fromRGB(14, 18, 14),
		RowHover = Color3.fromRGB(22, 30, 22),
		MenuDefault = Color3.fromRGB(16, 22, 16),
		MenuHover = Color3.fromRGB(26, 36, 26),
		HeaderDefault = Color3.fromRGB(12, 16, 12),
		HeaderHover = Color3.fromRGB(20, 28, 20),
		RootBackground = Color3.fromRGB(8, 11, 8),

		TextMain = Color3.fromRGB(232, 255, 232),
		TextDim = Color3.fromRGB(122, 150, 122),

		StrokeDefault = Color3.fromRGB(34, 54, 34),
		StrokeHover = Color3.fromRGB(60, 90, 60),
		StrokeFocus = Color3.fromRGB(57, 255, 113),
		StrokeSelected = Color3.fromRGB(57, 255, 113),
		StrokeInvalid = Color3.fromRGB(255, 80, 80),

		ToggleOff = Color3.fromRGB(30, 40, 30),
		ToggleOffHover = Color3.fromRGB(44, 58, 44),
		ToggleOffPressed = Color3.fromRGB(20, 28, 20),

		FontRegular = ArcadeFont,
		FontSemiBold = ArcadeFont,
	},
}

local Families: { [string]: { regular: string, emphasis: string } } = {
	Persona = { regular = "source", emphasis = "montserrat" },
	Eclat = { regular = "source", emphasis = "source" },
	Pixel = { regular = "arcade", emphasis = "arcade" },
}

local FontMakers: { [string]: { regular: Font, emphasis: Font } } = {
	source = { regular = SourceRegular, emphasis = SourceSemiBold },
	montserrat = { regular = MontserratRegular, emphasis = MontserratSemiBold },
	gotham = { regular = SourceRegular, emphasis = GothamBold },
	arcade = { regular = ArcadeFont, emphasis = ArcadeFont },
}

local Constants: { [string]: any } = {}
for key, value in Shared do
	Constants[key] = value
end
for key, value in Themes.Eclat do
	Constants[key] = value
end
Constants.ThemeNames = { "Persona", "Eclat", "Pixel" }
Constants.CurrentTheme = "Eclat"
Constants.CurrentFonts = { regular = "source", emphasis = "source" }

function Constants.setTheme(name: string)
	local palette = Themes[name]
	if palette == nil then
		return
	end
	for key, value in palette do
		Constants[key] = value
	end
	Constants.CurrentTheme = name
	local families = Families[name]
	if families ~= nil then
		Constants.CurrentFonts = { regular = families.regular, emphasis = families.emphasis }
	end
end

function Constants.setCustom(palette: { [string]: any })
	for key, value in palette do
		Constants[key] = value
	end
end

function Constants.fontFor(family: string, emphasis: boolean): Font
	local maker = FontMakers[family]
	if maker == nil then
		maker = FontMakers.source
	end
	if emphasis then
		return maker.emphasis
	end
	return maker.regular
end

function Constants.palette(name: string)
	return Themes[name]
end

function Constants.families(name: string)
	return Families[name]
end

return Constants
