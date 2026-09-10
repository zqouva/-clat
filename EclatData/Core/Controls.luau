--!strict
--!optimize 2

-- Setting row controls: toggle, text box, and dropdown.

local UserInputService = game:GetService("UserInputService")

local Constants = require(script.Parent.Constants)
local Hover = require(script.Parent.Hover)
local Input = require(script.Parent.Input)
local Layout = require(script.Parent.Layout)
local Templates = require(script.Parent.Templates)

export type Context = {
	TweenService: TweenService,
	PluginGuiService: PluginGuiService?,
	FastInfo: TweenInfo,
	SlowInfo: TweenInfo,
	OnInfoButtonClicked: (title: string, lines: { string }, row: GuiObject) -> (),
	OnSetLoaded: (name: string, set: Layout.Set, control: Control) -> (),
	SetDropdownOpen: (open: boolean) -> (),
	OnValueChanged: ((name: string) -> ())?,
	OnButtonPressed: ((name: string) -> ())?,
	GetChoices: ((name: string) -> any)?,
}

export type Control = {
	Get: () -> any,
	Set: (next: any) -> (),
	Row: GuiObject,
}

type CustomEntry = {
	Key: string,
	Label: string,
	Item: TextButton,
	Binding: Hover.Binding,
}

local openCloser: ((animate: boolean?) -> ())? = nil
local openScope: GuiObject? = nil
local watcherConnected = false

local function setSearchText(row: GuiObject, text: string)
	row:SetAttribute("SearchText", string.lower(text))
end

local function connectWatcher()
	if watcherConnected then
		return
	end
	watcherConnected = true
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local closer = openCloser
		local scope = openScope
		if closer and scope and Input.IsSelectInput(input) then
			local point = Input.GetInputPoint(input)
			if not Input.IsPointInFrame(point, scope) then
				openCloser = nil
				openScope = nil
				closer()
			end
		end
	end)
end

--> [`toggle`]
local function buildBoolean(
	context: Context,
	set: Layout.Set,
	defaults: { [string]: any },
	values: { [string]: any },
	order: number
): GuiObject
	local row = Templates.boolean()
	row.Name = set.Name
	row.LayoutOrder = order
	local tap = row:WaitForChild("Tap") :: TextButton
	local mark = tap:WaitForChild("Mark") :: Frame
	local bubble = mark:WaitForChild("Bubble") :: Frame
	local title = row:WaitForChild("Title") :: TextButton
	local info = title:WaitForChild("Info") :: ImageButton
	title.Text = set.Display

	local value = defaults[set.Name]
	if typeof(value) ~= "boolean" then
		value = set.Default == true
	end
	values[set.Name] = value

	local normalStyle: Hover.Style = { Background = Constants.RowDefault, Stroke = nil }
	local hoverStyle: Hover.Style = { Background = Constants.RowHover, Stroke = nil }
	Hover.bind(tap, context.TweenService, context.FastInfo, normalStyle, hoverStyle, nil, nil)
	Hover.bind(title, context.TweenService, context.FastInfo, normalStyle, hoverStyle, nil, nil)

	local function setValue(next: boolean, silent: boolean?)
		if not silent and value == next then
			return
		end
		value = next
		values[set.Name] = value
		if not silent and context.OnValueChanged then
			context.OnValueChanged(set.Name)
		end
		local markGoal: Color3
		local bubbleGoal: UDim2
		if value then
			markGoal = Constants.BlueNormal
			bubbleGoal = Constants.BubbleOn
		else
			markGoal = Constants.ToggleOff
			bubbleGoal = Constants.BubbleOff
		end
		if silent then
			mark.BackgroundColor3 = markGoal
			bubble.Position = bubbleGoal
			return
		end
		context.TweenService:Create(mark, context.SlowInfo, { BackgroundColor3 = markGoal }):Play()
		context.TweenService:Create(bubble, context.SlowInfo, { Position = bubbleGoal }):Play()
	end
	setValue(value, true)

	local function getValue(): any
		return value
	end

	local function applyValue(next: any)
		if typeof(next) == "boolean" then
			setValue(next)
		end
	end

	info.MouseButton1Click:Connect(function()
		context.OnInfoButtonClicked(set.Display, { set.Description }, row)
	end)
	tap.MouseButton1Click:Connect(function()
		setValue(not value)
	end)
	context.OnSetLoaded(set.Name, set, {
		Get = getValue,
		Set = applyValue,
		Row = row,
	})
	setSearchText(row, `{set.Display} {set.Description}`)
	return row
end

--> [`text`]
local function buildText(
	context: Context,
	set: Layout.Set,
	defaults: { [string]: any },
	values: { [string]: any },
	order: number
): GuiObject
	local row = Templates.text()
	row.Name = set.Name
	row.LayoutOrder = order
	local title = row:WaitForChild("Title") :: TextButton
	local info = title:WaitForChild("Info") :: ImageButton
	local box = row:WaitForChild("Box") :: TextBox
	local stroke = box:WaitForChild("Stroke") :: UIStroke
	title.Text = set.Display

	local saved = defaults[set.Name]
	local value: string
	if typeof(saved) == "string" then
		value = saved
	elseif typeof(set.Default) == "string" then
		value = set.Default
	else
		value = ""
	end
	values[set.Name] = value
	box.Text = value
	local focused = false

	local normalStyle: Hover.Style = { Background = Constants.RowDefault, Stroke = nil }
	local hoverStyle: Hover.Style = { Background = Constants.RowHover, Stroke = nil }
	Hover.bind(title, context.TweenService, context.FastInfo, normalStyle, hoverStyle, nil, nil)

	local function refreshSearch()
		setSearchText(row, `{set.Display} {set.Description} {value}`)
	end

	local function setStroke(color: Color3)
		context.TweenService:Create(stroke, context.FastInfo, { Color = color }):Play()
	end

	local function getValue(): any
		return value
	end

	local function applyValue(next: any)
		if typeof(next) == "string" then
			value = next
			values[set.Name] = value
			if context.OnValueChanged then
				context.OnValueChanged(set.Name)
			end
			if box.Text ~= value then
				box.Text = value
			end
			refreshSearch()
		end
	end

	box.Focused:Connect(function()
		focused = true
		setStroke(Constants.StrokeFocus)
	end)
	box.FocusLost:Connect(function()
		focused = false
		setStroke(Constants.StrokeDefault)
		if box.Text ~= value then
			value = box.Text
			values[set.Name] = value
			if context.OnValueChanged then
				context.OnValueChanged(set.Name)
			end
			refreshSearch()
		end
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if focused and box.Text ~= value then
			value = box.Text
			values[set.Name] = value
			if context.OnValueChanged then
				context.OnValueChanged(set.Name)
			end
			refreshSearch()
		end
	end)
	info.MouseButton1Click:Connect(function()
		context.OnInfoButtonClicked(set.Display, { set.Description }, row)
	end)
	context.OnSetLoaded(set.Name, set, {
		Get = getValue,
		Set = applyValue,
		Row = row,
	})
	refreshSearch()
	return row
end

--> [`custom`]
local function buildCustom(
	context: Context,
	set: Layout.Set,
	defaults: { [string]: any },
	values: { [string]: any },
	order: number
): GuiObject
	local options = set.Type
	if context.GetChoices then
		local override = context.GetChoices(set.Name)
		if typeof(override) == "table" then
			options = override
		end
	end
	assert(typeof(options) == "table", `[Éclat/Controls] custom set {set.Name} needs a table of options`)
	local row = Templates.custom()
	row.Name = set.Name
	row.LayoutOrder = order
	local title = row:WaitForChild("Title") :: TextButton
	local info = title:WaitForChild("Info") :: ImageButton
	local tap = row:WaitForChild("Tap") :: TextButton
	local tapStroke = tap:WaitForChild("Stroke") :: UIStroke
	local down = tap:WaitForChild("Down") :: TextButton
	local items = row:WaitForChild("Items") :: Frame
	title.Text = set.Display

	local entries: { CustomEntry } = {}
	local seenLabels: { [string]: number } = {}
	for key, label in options do
		local labelText = tostring(label)
		local seen = seenLabels[labelText] or 0
		seenLabels[labelText] = seen + 1
		if seen > 0 then
			labelText = `{labelText} ({seen + 1})`
		end
		local item = Templates.item()
		item.LayoutOrder = #entries + 1
		local labelHolder = item:WaitForChild("Pad")
		labelHolder:Destroy()
		item.Text = labelText
		table.insert(entries, {
			Key = tostring(key),
			Label = labelText,
			Item = item,
			Binding = Hover.bind(item, context.TweenService, context.FastInfo, {
				Background = Constants.RowDefault,
				Stroke = nil,
			}, {
				Background = Constants.RowHover,
				Stroke = nil,
			}, nil, nil),
		})
	end
	table.sort(entries, function(a: CustomEntry, b: CustomEntry): boolean
		return a.Label < b.Label
	end)
	local list = items:WaitForChild("List") :: UIListLayout
	list.SortOrder = Enum.SortOrder.LayoutOrder
	for index, entry in entries do
		entry.Item.LayoutOrder = index
		entry.Item.Parent = items
	end

	local saved = defaults[set.Name]
	local value: string
	if typeof(saved) == "string" then
		value = saved
	else
		value = tostring(set.Default)
	end
	if options[value] == nil and #entries > 0 then
		value = entries[1].Key
	end
	values[set.Name] = value
	tap.Text = tostring(options[value])

	local normalStyle: Hover.Style = { Background = Constants.RowDefault, Stroke = nil }
	local hoverStyle: Hover.Style = { Background = Constants.RowHover, Stroke = nil }
	Hover.bind(title, context.TweenService, context.FastInfo, normalStyle, hoverStyle, nil, nil)
	Hover.bind(tap, context.TweenService, context.FastInfo, normalStyle, hoverStyle, nil, nil)

	local isOpen = false
	local closedRowSize = UDim2.new(1, 0, 0, 26)
	local openRowSize = UDim2.new(1, 0, 0, 26 + 18 * #entries)
	local openItemsSize = UDim2.new(0.5, -1, 0, 18 * #entries)
	local closedItemsSize = UDim2.new(0.5, -1, 0, 0)

	local function closeDropdown(animate: boolean?)
		if not isOpen then
			return
		end
		isOpen = false
		tapStroke.Enabled = false
		context.SetDropdownOpen(false)
		context.TweenService:Create(down, context.FastInfo, { Rotation = 0 }):Play()
		if animate == false then
			row.Size = closedRowSize
			items.Size = closedItemsSize
			items.Visible = false
			return
		end
		context.TweenService:Create(row, context.SlowInfo, { Size = closedRowSize }):Play()
		local tween = context.TweenService:Create(items, context.SlowInfo, { Size = closedItemsSize })
		tween.Completed:Connect(function()
			if not isOpen then
				items.Visible = false
			end
		end)
		tween:Play()
	end

	local function openDropdown()
		if isOpen then
			return
		end
		connectWatcher()
		local previous = openCloser
		openCloser = nil
		openScope = nil
		if previous then
			previous(false)
		end
		isOpen = true
		tapStroke.Enabled = true
		context.SetDropdownOpen(true)
		context.TweenService:Create(down, context.SlowInfo, { Rotation = -90 }):Play()
		items.Visible = true
		context.TweenService:Create(row, context.SlowInfo, { Size = openRowSize }):Play()
		context.TweenService:Create(items, context.SlowInfo, { Size = openItemsSize }):Play()
		openCloser = closeDropdown
		openScope = row
	end

	local function refreshSearch()
		setSearchText(row, `{set.Display} {set.Description} {tap.Text}`)
	end

	local function choose(entry: CustomEntry)
		value = entry.Key
		values[set.Name] = value
		if context.OnValueChanged then
			context.OnValueChanged(set.Name)
		end
		tap.Text = entry.Label
		refreshSearch()
		closeDropdown()
	end

	for _, entry in entries do
		local target = entry
		target.Item.MouseButton1Click:Connect(function()
			choose(target)
		end)
	end

	local function getValue(): any
		return value
	end

	local function applyValue(next: any)
		local key = tostring(next)
		if options[key] ~= nil then
			value = key
			values[set.Name] = value
			if context.OnValueChanged then
				context.OnValueChanged(set.Name)
			end
			tap.Text = tostring(options[key])
			refreshSearch()
		end
	end

	tap.MouseButton1Click:Connect(function()
		if isOpen then
			closeDropdown()
		else
			openDropdown()
		end
	end)
	info.MouseButton1Click:Connect(function()
		context.OnInfoButtonClicked(set.Display, { set.Description }, row)
	end)
	context.OnSetLoaded(set.Name, set, {
		Get = getValue,
		Set = applyValue,
		Row = row,
	})
	refreshSearch()
	return row
end

--> [`button`]
local function buildButton(
	context: Context,
	set: Layout.Set,
	order: number
): GuiObject
	local row = Templates.button()
	row.Name = set.Name
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 26)
	local title = row:WaitForChild("Title") :: TextLabel
	title.Text = set.Display
	title.TextSize = 13
	Hover.bind(row, context.TweenService, context.FastInfo, {
		Background = Constants.BlueNormal,
		Stroke = nil,
	}, {
		Background = Constants.BlueHover,
		Stroke = nil,
	}, nil, nil, {
		Background = Constants.BluePressed,
		Stroke = nil,
	})
	row.MouseButton1Click:Connect(function()
		if context.OnButtonPressed then
			context.OnButtonPressed(set.Name)
		end
	end)
	context.OnSetLoaded(set.Name, set, {
		Get = function()
			return true
		end,
		Set = function(_next: any)
			if context.OnButtonPressed then
				context.OnButtonPressed(set.Name)
			end
		end,
		Row = row,
	})
	setSearchText(row, `{set.Display} {set.Description}`)
	return row
end

--> [`build`]
local function build(
	context: Context,
	set: Layout.Set,
	defaults: { [string]: any },
	values: { [string]: any },
	order: number
): GuiObject
	assert(typeof(set.Name) == "string", "[Éclat/Controls] set needs a name")
	assert(set.Type ~= nil, `[Éclat/Controls] set {set.Name} needs a type`)
	if set.Type == "Boolean" then
		return buildBoolean(context, set, defaults, values, order)
	elseif set.Type == "Text" then
		return buildText(context, set, defaults, values, order)
	elseif set.Type == "Button" then
		return buildButton(context, set, order)
	elseif typeof(set.Type) == "table" then
		return buildCustom(context, set, defaults, values, order)
	end
	error(`[Éclat/Controls] unknown type for set {set.Name}`)
end

return build
