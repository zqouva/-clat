--!strict
--!optimize 2

-- Live search filter for a pane.

local Constants = require(script.Parent.Constants)

local SearchFilter = {}

export type Context = {
	Pane: ScrollingFrame,
	TweenService: TweenService,
	FastInfo: TweenInfo,
	Empty: TextLabel?,
	ShowEmptyWhenNoQuery: boolean?,
	OnFiltered: (visibleCount: number) -> (),
}

export type Handle = {
	Refresh: () -> (),
	TextBox: TextBox,
	Root: Frame,
	Empty: TextLabel,
}

function SearchFilter.attach(filterRoot: Frame, context: Context): Handle
	local search = filterRoot:WaitForChild("Search") :: TextBox
	local stroke = search:WaitForChild("Stroke") :: UIStroke
	local placeholder = filterRoot:WaitForChild("Placeholder") :: TextLabel
	local icon = filterRoot:WaitForChild("Icon") :: ImageButton

	local empty = Instance.new("TextLabel")
	empty.AutoLocalize = false
	empty.BackgroundTransparency = 1
	empty.BorderSizePixel = 0
	empty.FontFace = Constants.FontRegular
	empty.Size = UDim2.new(1, 0, 0, 24)
	empty.Text = "Nothing found"
	empty.TextColor3 = Constants.TextDim
	empty.TextSize = 13
	empty.Visible = false
	empty.Parent = context.Pane
	if context.Empty then
		context.Empty.Visible = false
	end

	local emptyToken = 0
	local function setEmptyVisible(visible: boolean, queryEmpty: boolean)
		empty.Visible = visible
		if visible then
			if context.Empty then
				context.Empty.Visible = queryEmpty
			end
			emptyToken += 1
			local token = emptyToken
			task.delay(10, function()
				if emptyToken == token and empty.Visible then
					empty.Visible = false
					if context.Empty then
						context.Empty.Visible = true
					end
				end
			end)
		end
	end

	local function refresh()
		local query = string.lower(search.Text)
		local matches = 0
		for _, section in context.Pane:GetChildren() do
			if section:IsA("GuiObject") then
				local header = section:FindFirstChild("Header")
				if header then
					local titleText = ""
					local titleLabel = header:FindFirstChild("Title")
					if titleLabel and titleLabel:IsA("TextLabel") then
						titleText = string.lower(titleLabel.Text)
					end
					local sectionMatch = query == "" or string.find(titleText, query, 1, true) ~= nil
					local anyRow = false
					for _, row in section:GetChildren() do
						if row:IsA("GuiObject") and row ~= header then
							local searchText: string? = row:GetAttribute("SearchText")
							local rowMatch = query == ""
								or (searchText ~= nil and string.find(searchText, query, 1, true) ~= nil)
							row.Visible = rowMatch
							if rowMatch then
								anyRow = true
								matches += 1
							end
						end
					end
					section.Visible = sectionMatch or anyRow
				end
			end
		end
		local showStaticEmpty = context.ShowEmptyWhenNoQuery == true
		setEmptyVisible(matches == 0 and (query ~= "" or showStaticEmpty), query == "")
		context.OnFiltered(matches)
	end

	local function setStroke(color: Color3)
		context.TweenService:Create(stroke, context.FastInfo, { Color = color }):Play()
	end

	search.Focused:Connect(function()
		setStroke(Constants.StrokeFocus)
	end)
	search.FocusLost:Connect(function()
		setStroke(Constants.StrokeDefault)
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		placeholder.Visible = search.Text == ""
		refresh()
	end)
	icon.MouseButton1Click:Connect(function()
		search:CaptureFocus()
	end)
	refresh()

	return {
		Refresh = refresh,
		TextBox = search,
		Root = filterRoot,
		Empty = empty,
	}
end

return table.freeze(SearchFilter)
