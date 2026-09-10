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
}

local Layout: { [string]: { Section } } = {
	General = {
		{
			Name = "Theme",
			Sets = {
				{
					Display = "Theme",
					Description = "Persona, Éclat, or Pixel. Applies instantly.",
					Name = "Theme",
					Type = { Persona = "Persona", Eclat = "Éclat", Pixel = "Pixel" },
					Default = "Eclat",
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
