--!strict
--!optimize 2

-- Setting sections per pane.

export type Set = {
	Display: string,
	Description: string,
	Name: string,
	Type: any,
	Default: any,
}

export type Section = {
	Name: string,
	Sets: { Set },
	Collapsed: boolean?,
}

local Layout: { [string]: { Section } } = {
	General = {
		{
			Name = "Theme",
			Sets = {
				{
					Display = "Theme",
					Description = "Built-ins plus your customs. Picking one loads it into the editor below.",
					Name = "Theme",
					Type = { Persona = "Persona", Eclat = "Éclat", Pixel = "Pixel" },
					Default = "Eclat",
				},
				{
					Display = "Custom name",
					Description = "Name for the theme you are making below.",
					Name = "CustomName",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Save theme",
					Description = "Saves the editor below under the custom name and applies it.",
					Name = "SaveTheme",
					Type = "Button",
					Default = nil,
				},
				{
					Display = "Delete theme",
					Description = "Deletes the selected custom theme. Built-ins stay.",
					Name = "DeleteTheme",
					Type = "Button",
					Default = nil,
				},
				{
					Display = "Export theme",
					Description = "Shows the editor as JSON. Copy it to share with others.",
					Name = "ExportTheme",
					Type = "Button",
					Default = nil,
				},
				{
					Display = "Import theme",
					Description = "Pastes someone else's theme JSON and applies it.",
					Name = "ImportTheme",
					Type = "Button",
					Default = nil,
				},
			},
		},
		{
			Name = "Theme colors",
			Collapsed = true,
			Sets = {
				{
					Display = "Blue normal",
					Description = "Hex color, like #2B66FF.",
					Name = "T_BlueNormal",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Blue hover",
					Description = "Hex color, like #2B66FF.",
					Name = "T_BlueHover",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Blue pressed",
					Description = "Hex color, like #2B66FF.",
					Name = "T_BluePressed",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Row",
					Description = "Hex color, like #2B66FF.",
					Name = "T_RowDefault",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Row hover",
					Description = "Hex color, like #2B66FF.",
					Name = "T_RowHover",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Menu",
					Description = "Hex color, like #2B66FF.",
					Name = "T_MenuDefault",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Menu hover",
					Description = "Hex color, like #2B66FF.",
					Name = "T_MenuHover",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Header",
					Description = "Hex color, like #2B66FF.",
					Name = "T_HeaderDefault",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Header hover",
					Description = "Hex color, like #2B66FF.",
					Name = "T_HeaderHover",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Background",
					Description = "Hex color, like #2B66FF.",
					Name = "T_RootBackground",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Text",
					Description = "Hex color, like #2B66FF.",
					Name = "T_TextMain",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Text dim",
					Description = "Hex color, like #2B66FF.",
					Name = "T_TextDim",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Stroke",
					Description = "Hex color, like #2B66FF.",
					Name = "T_StrokeDefault",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Stroke hover",
					Description = "Hex color, like #2B66FF.",
					Name = "T_StrokeHover",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Stroke focus",
					Description = "Hex color, like #2B66FF.",
					Name = "T_StrokeFocus",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Stroke selected",
					Description = "Hex color, like #2B66FF.",
					Name = "T_StrokeSelected",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Stroke invalid",
					Description = "Hex color, like #2B66FF.",
					Name = "T_StrokeInvalid",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Toggle off",
					Description = "Hex color, like #2B66FF.",
					Name = "T_ToggleOff",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Toggle off hover",
					Description = "Hex color, like #2B66FF.",
					Name = "T_ToggleOffHover",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Toggle off pressed",
					Description = "Hex color, like #2B66FF.",
					Name = "T_ToggleOffPressed",
					Type = "Text",
					Default = nil,
				},
			},
		},
		{
			Name = "Theme fonts",
			Collapsed = true,
			Sets = {
				{
					Display = "Body font",
					Description = "Font for plain text.",
					Name = "FontBody",
					Type = { source = "Source", montserrat = "Montserrat", arcade = "Arcade" },
					Default = nil,
				},
				{
					Display = "Emphasis font",
					Description = "Font for headers and buttons.",
					Name = "FontEmphasis",
					Type = { source = "Source", montserrat = "Montserrat", gotham = "Gotham", arcade = "Arcade" },
					Default = nil,
				},
			},
		},
		{
			Name = "Replace",
			Sets = {
				{
					Display = "Replace mode",
					Description = "During upload swaps ids as answers arrive. All at once waits for done, then swaps everything.",
					Name = "ReplaceMode",
					Type = { During = "During upload", Once = "All at once" },
					Default = "During",
				},
			},
		},
		{
			Name = "Engine",
			Sets = {
				{
					Display = "Port",
					Description = "Port the engine listens on.",
					Name = "Port",
					Type = "Text",
					Default = "8080",
				},
				{
					Display = "Export JSON",
					Description = "Write Output_<type>_<time>.json with old and new ids.",
					Name = "ExportJSON",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "Default place ids",
					Description = "Extra place ids, comma separated. Used when a creator has no open places.",
					Name = "DefaultPlaceIds",
					Type = "Text",
					Default = nil,
				},
				{
					Display = "Selection only",
					Description = "Only gather ids under the selected instances.",
					Name = "SelectionOnly",
					Type = "Boolean",
					Default = false,
				},
			},
		},
	},
	Animation = {
		{
			Name = "Find",
			Sets = {
				{
					Display = "Animation",
					Description = "Gather Animation.AnimationId.",
					Name = "A_Animation",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "Scripts",
					Description = "Gather numeric ids inside script sources.",
					Name = "A_Lua",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "StringValue",
					Description = "Gather numeric ids inside StringValue.",
					Name = "A_String",
					Type = "Boolean",
					Default = false,
				},
				{
					Display = "NumberValue",
					Description = "Gather NumberValue.Value.",
					Name = "A_Number",
					Type = "Boolean",
					Default = false,
				},
				{
					Display = "IntValue",
					Description = "Gather IntValue.Value.",
					Name = "A_Int",
					Type = "Boolean",
					Default = false,
				},
			},
		},
	},
	Mesh = {
		{
			Name = "Find",
			Sets = {
				{
					Display = "MeshPart",
					Description = "Gather MeshPart.MeshId. Matched parts are rebuilt on replace.",
					Name = "M_MeshPart",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "SpecialMesh",
					Description = "Gather SpecialMesh.MeshId.",
					Name = "M_SpecialMesh",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "CharacterMesh",
					Description = "Gather CharacterMesh.MeshId.",
					Name = "M_CharacterMesh",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "Scripts",
					Description = "Gather numeric ids inside script sources.",
					Name = "M_Lua",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "StringValue",
					Description = "Gather numeric ids inside StringValue.",
					Name = "M_String",
					Type = "Boolean",
					Default = false,
				},
				{
					Display = "NumberValue",
					Description = "Gather NumberValue.Value.",
					Name = "M_Number",
					Type = "Boolean",
					Default = false,
				},
				{
					Display = "IntValue",
					Description = "Gather IntValue.Value.",
					Name = "M_Int",
					Type = "Boolean",
					Default = false,
				},
			},
		},
	},
	Sound = {
		{
			Name = "Find",
			Sets = {
				{
					Display = "Sound",
					Description = "Gather Sound.SoundId.",
					Name = "S_Sound",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "Scripts",
					Description = "Gather numeric ids inside script sources.",
					Name = "S_Lua",
					Type = "Boolean",
					Default = true,
				},
				{
					Display = "StringValue",
					Description = "Gather numeric ids inside StringValue.",
					Name = "S_String",
					Type = "Boolean",
					Default = false,
				},
				{
					Display = "NumberValue",
					Description = "Gather NumberValue.Value.",
					Name = "S_Number",
					Type = "Boolean",
					Default = false,
				},
				{
					Display = "IntValue",
					Description = "Gather IntValue.Value.",
					Name = "S_Int",
					Type = "Boolean",
					Default = false,
				},
			},
		},
	},
}

return table.freeze(Layout)
