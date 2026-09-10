--!strict
--!optimize 2

-- Builds collapsible setting sections into a pane.

local Constants = require(script.Parent.Constants)
local Controls = require(script.Parent.Controls)
local Hover = require(script.Parent.Hover)
local Layout = require(script.Parent.Layout)
local Templates = require(script.Parent.Templates)

local Sections = {}

export type Context = {
	TweenService: TweenService,
	PluginGuiService: PluginGuiService?,
	FastInfo: TweenInfo,
	SlowInfo: TweenInfo,
	SetDropdownOpen: (open: boolean) -> (),
	OnSectionToggled: () -> (),
	OnValueChanged: ((name: string) -> ())?,
	OnButtonPressed: ((name: string) -> ())?,
	GetChoices: ((name: string) -> any)?,
}

export type Handle = {
	HideInfo: () -> (),
}

function Sections.build(
	pane: ScrollingFrame,
	overlay: GuiObject,
	tabName: string,
	context: Context,
	defaults: { [string]: any },
	values: { [string]: any },
	registered: { [string]: Controls.Control }
): Handle
	local info = Templates.info()
	info.Parent = overlay
	local infoClose = info:WaitForChild("Close") :: TextButton
	local infoLabel = info:WaitForChild("Label") :: TextLabel
	infoClose.MouseButton1Click:Connect(function()
		info.Visible = false
	end)

	local function showInfo(title: string, lines: { string }, row: GuiObject)
		infoLabel.Text = `<b>{title}</b>\n{table.concat(lines, "\n")}`
		local overPos = overlay.AbsolutePosition
		local overSize = overlay.AbsoluteSize
		local y = row.AbsolutePosition.Y - overPos.Y + row.AbsoluteSize.Y + 4
		local maxY = overSize.Y - 136
		if y > maxY then
			y = row.AbsolutePosition.Y - overPos.Y - 136 - 4
		end
		if y < 0 then
			y = 0
		end
		info.Position = UDim2.new(0, row.AbsolutePosition.X - overPos.X, 0, y)
		info.Size = UDim2.new(0, overSize.X, 0, 136)
		info.Visible = true
	end

	local controlsContext: Controls.Context = {
		TweenService = context.TweenService,
		PluginGuiService = context.PluginGuiService,
		FastInfo = context.FastInfo,
		SlowInfo = context.SlowInfo,
		OnInfoButtonClicked = showInfo,
		OnSetLoaded = function(name: string, _set: Layout.Set, control: Controls.Control)
			registered[name] = control
		end,
		SetDropdownOpen = context.SetDropdownOpen,
		OnValueChanged = context.OnValueChanged,
		OnButtonPressed = context.OnButtonPressed,
		GetChoices = context.GetChoices,
	}

	local sectionDefs = Layout[tabName] or {}
	local order = 1
	for _, sectionDef in sectionDefs do
		local section = Templates.section()
		section.LayoutOrder = order
		order += 1
		local header = section:WaitForChild("Header") :: TextButton
		local headerTitle = header:WaitForChild("Title") :: TextLabel
		local arrow = header:WaitForChild("Arrow") :: TextButton
		headerTitle.Text = sectionDef.Name

		local rows: { GuiObject } = {}
		local collapsed = sectionDef.Collapsed == true
		header.MouseButton1Click:Connect(function()
			collapsed = not collapsed
			section:SetAttribute("Collapsed", collapsed)
			for _, row in rows do
				row.Visible = not collapsed
			end
			arrow.Text = if collapsed then "▸" else "▾"
			context.OnSectionToggled()
		end)
		Hover.bind(header, context.TweenService, context.FastInfo, {
			Background = Constants.HeaderDefault,
			Stroke = nil,
		}, {
			Background = Constants.HeaderHover,
			Stroke = nil,
		}, nil, nil)

		local rowOrder = 1
		for _, set in sectionDef.Sets do
			local row = Controls(controlsContext, set, defaults, values, rowOrder)
			rowOrder += 1
			table.insert(rows, row)
			row.Parent = section
		end
		if collapsed then
			for _, row in rows do
				row.Visible = false
			end
			arrow.Text = "▸"
		end
		section:SetAttribute("Collapsed", collapsed)
		section.Parent = pane
	end

	local function hideInfo()
		info.Visible = false
	end

	return {
		HideInfo = hideInfo,
	}
end

return table.freeze(Sections)
