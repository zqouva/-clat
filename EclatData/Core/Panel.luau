--!strict
--!optimize 2

-- The studio panel: tabs, settings, footer, jobs.

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local TweenService = game:GetService("TweenService")

local Connection = require(script.Parent.Connection)
local Constants = require(script.Parent.Constants)
local Controls = require(script.Parent.Controls)
local Cookie = require(script.Parent.Cookie)
local Filter = require(script.Parent.Filter)
local History = require(script.Parent.History)
local Hover = require(script.Parent.Hover)
local Layout = require(script.Parent.Layout)
local Reupload = require(script.Parent.Reupload)
local SearchFilter = require(script.Parent.SearchFilter)
local Sections = require(script.Parent.Sections)
local Scrollbar = require(script.Parent.Scrollbar)
local Templates = require(script.Parent.Templates)
local Uplink = require(script.Parent.Uplink)

local Panel = {}

export type Handle = {
	Widget: DockWidgetPluginGui,
	Refresh: () -> (),
}

local TAB_NAMES = { "General", "Animation", "Mesh", "Sound" }
local PLUGIN_VERSION = "1.3.1"

--> [`theme studio`]
type CustomTheme = {
	Colors: { [string]: string },
	Fonts: { regular: string, emphasis: string },
}

local COLOR_KEYS = {
	"BlueNormal",
	"BlueHover",
	"BluePressed",
	"RowDefault",
	"RowHover",
	"MenuDefault",
	"MenuHover",
	"HeaderDefault",
	"HeaderHover",
	"RootBackground",
	"TextMain",
	"TextDim",
	"StrokeDefault",
	"StrokeHover",
	"StrokeFocus",
	"StrokeSelected",
	"StrokeInvalid",
	"ToggleOff",
	"ToggleOffHover",
	"ToggleOffPressed",
}

local function toHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function fromHex(text: string): Color3?
	if typeof(text) ~= "string" then
		return nil
	end
	local hex = if string.sub(text, 1, 1) == "#" then string.sub(text, 2) else text
	if #hex ~= 6 then
		return nil
	end
	local n = tonumber(hex, 16)
	if n == nil then
		return nil
	end
	return Color3.fromRGB(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256)
end

local function cleanName(text: any): string
	local out = string.gsub(string.gsub(text or "", "^%s*(.-)%s*$", "%1"), "[^%w ]", "")
	if #out > 24 then
		out = string.sub(out, 1, 24)
	end
	return out
end

local function applyCustom(custom: CustomTheme, name: string)
	local palette: { [string]: any } = {}
	for key, hex in custom.Colors do
		local color = fromHex(hex)
		if color ~= nil then
			palette[key] = color
		end
	end
	palette.FontRegular = Constants.fontFor(custom.Fonts.regular, false)
	palette.FontSemiBold = Constants.fontFor(custom.Fonts.emphasis, true)
	Constants.setCustom(palette)
	Constants.CurrentTheme = name
	Constants.CurrentFonts = { regular = custom.Fonts.regular, emphasis = custom.Fonts.emphasis }
end

local active: Handle? = nil
local busy = false
local sharedLink: Connection.Connection? = nil

--> [`settings`]
local function readSettings(plugin: Plugin): { [string]: any }
	local defaults: { [string]: any } = {}
	for _, tab in TAB_NAMES do
		for _, section in Layout[tab] do
			for _, set in section.Sets do
				local key = `Éclat_{set.Name}`
				local found, saved = pcall(function()
					return plugin:GetSetting(key)
				end)
				if found and saved ~= nil then
					defaults[set.Name] = saved
				else
					defaults[set.Name] = set.Default
				end
			end
		end
	end
	return defaults
end

--> [`open`]
function Panel.open(plugin: Plugin): Handle
	if active then
		active.Widget.Enabled = true
		return active
	end

	local defaults = readSettings(plugin)
	local customs: { [string]: CustomTheme } = {}
	local customIndex: { string } = {}
	do
		local found, saved = pcall(function()
			return plugin:GetSetting("Éclat_CustomIndex")
		end)
		if found and typeof(saved) == "table" then
			for _, name in (saved :: { string }) do
				local ok, palette = pcall(function()
					return plugin:GetSetting("Éclat_Custom_" .. name)
				end)
				if ok and typeof(palette) == "table" then
					customs[name] = palette :: CustomTheme
					table.insert(customIndex, name)
				end
			end
		end
	end
	local savedTheme = if typeof(defaults.Theme) == "string" then defaults.Theme else "Eclat"
	local savedCustom: CustomTheme? = customs[savedTheme]
	if savedCustom ~= nil then
		applyCustom(savedCustom, savedTheme)
	else
		Constants.setTheme(savedTheme)
	end
	for _, key in COLOR_KEYS do
		if defaults["T_" .. key] == nil then
			defaults["T_" .. key] = toHex(Constants[key])
		end
	end
	if defaults.FontBody == nil then
		defaults.FontBody = Constants.CurrentFonts.regular
	end
	if defaults.FontEmphasis == nil then
		defaults.FontEmphasis = Constants.CurrentFonts.emphasis
	end
	local values: { [string]: any } = {}
	for name, value in defaults do
		values[name] = value
	end
	local registered: { [string]: Controls.Control } = {}
	local dropdownOpen = false
	local pendingRetry: { number }? = nil
	local retryTab: string? = nil
	local countCache: { [string]: number } = {}
	local countsStale = true
	local current = "General"

	--> [`widget`]
	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, true, false, 360, 520, 300, 200)
	local widget = plugin:CreateDockWidgetPluginGui("EclatPanel", info)
	widget.Name = "Éclat"
	widget.Title = "Éclat"
	widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AutoLocalize = false
	root.BackgroundColor3 = Constants.RootBackground
	root.BorderSizePixel = 0
	root.Size = UDim2.new(1, 0, 1, 0)
	root.Parent = widget

	local rootPad = Instance.new("UIPadding")
	rootPad.Name = "Pad"
	rootPad.PaddingBottom = UDim.new(0, 8)
	rootPad.PaddingLeft = UDim.new(0, 8)
	rootPad.PaddingRight = UDim.new(0, 8)
	rootPad.PaddingTop = UDim.new(0, 8)
	rootPad.Parent = root

	local rootList = Instance.new("UIListLayout")
	rootList.Name = "List"
	rootList.Padding = UDim.new(0, 6)
	rootList.SortOrder = Enum.SortOrder.LayoutOrder
	rootList.Parent = root

	--> [`topbar`]
	local topbar = Templates.topbar()
	topbar.LayoutOrder = 1
	topbar.Parent = root
	local topTitle = topbar:WaitForChild("Title") :: TextLabel
	local topCount = topbar:WaitForChild("Count") :: TextLabel
	local topClose = topbar:WaitForChild("Close") :: TextButton
	topTitle.Text = "Éclat"
	topClose.MouseButton1Click:Connect(function()
		widget.Enabled = false
	end)

	--> [`tabs`]
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.AutoLocalize = false
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.LayoutOrder = 2
	tabs.Size = UDim2.new(1, 0, 0, 32)
	tabs.Parent = root

	local tabsList = Instance.new("UIListLayout")
	tabsList.Name = "List"
	tabsList.FillDirection = Enum.FillDirection.Horizontal
	tabsList.Padding = UDim.new(0, 6)
	tabsList.SortOrder = Enum.SortOrder.LayoutOrder
	tabsList.Parent = tabs

	--> [`content`]
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AutoLocalize = false
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.LayoutOrder = 3
	content.Size = UDim2.new(1, 0, 1, -148)
	content.Parent = root

	--> [`footer`]
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AutoLocalize = false
	footer.BackgroundTransparency = 1
	footer.BorderSizePixel = 0
	footer.LayoutOrder = 4
	footer.Size = UDim2.new(1, 0, 0, 66)
	footer.Parent = root

	local footerList = Instance.new("UIListLayout")
	footerList.Name = "List"
	footerList.Padding = UDim.new(0, 6)
	footerList.SortOrder = Enum.SortOrder.LayoutOrder
	footerList.Parent = footer

	local statusLabel = Templates.status()
	statusLabel.LayoutOrder = 1
	statusLabel.Text = "Start the engine, then pick a tab."
	statusLabel.Parent = footer

	local progress = Templates.progress()
	progress.LayoutOrder = 2
	progress.Parent = footer
	local progressFill = progress:WaitForChild("Fill") :: Frame

	local function setProgress(swapped: number, total: number)
		local ratio = 0
		if total > 0 then
			ratio = math.clamp(swapped / total, 0, 1)
		end
		progressFill.Size = UDim2.new(ratio, 0, 1, 0)
	end

	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.AutoLocalize = false
	buttonRow.BackgroundTransparency = 1
	buttonRow.BorderSizePixel = 0
	buttonRow.LayoutOrder = 3
	buttonRow.Size = UDim2.new(1, 0, 0, 30)
	buttonRow.Parent = footer

	local buttonList = Instance.new("UIListLayout")
	buttonList.Name = "List"
	buttonList.FillDirection = Enum.FillDirection.Horizontal
	buttonList.Padding = UDim.new(0, 6)
	buttonList.SortOrder = Enum.SortOrder.LayoutOrder
	buttonList.Parent = buttonRow

	local reuploadButton = Templates.button()
	reuploadButton.LayoutOrder = 1
	reuploadButton.Size = UDim2.new(1, -106, 1, 0)
	reuploadButton.Parent = buttonRow
	local reuploadTitle = reuploadButton:WaitForChild("Title") :: TextLabel
	reuploadTitle.Text = "Reupload"
	Hover.bind(reuploadButton, TweenService, Constants.FastInfo, {
		Background = Constants.BlueNormal,
		Stroke = nil,
	}, {
		Background = Constants.BlueHover,
		Stroke = nil,
	}, nil, nil, {
		Background = Constants.BluePressed,
		Stroke = nil,
	})

	local cookieButton = Templates.button()
	cookieButton.LayoutOrder = 2
	cookieButton.Size = UDim2.new(0, 100, 1, 0)
	cookieButton.BackgroundColor3 = Constants.MenuDefault
	cookieButton.Parent = buttonRow
	local cookieTitle = cookieButton:WaitForChild("Title") :: TextLabel
	cookieTitle.Text = "Cookie"
	local cookieStroke = Instance.new("UIStroke")
	cookieStroke.Name = "Stroke"
	cookieStroke.Color = Constants.StrokeDefault
	cookieStroke.Thickness = 1
	cookieStroke.Parent = cookieButton
	Hover.bind(cookieButton, TweenService, Constants.FastInfo, {
		Background = Constants.MenuDefault,
		Stroke = Constants.StrokeDefault,
	}, {
		Background = Constants.MenuHover,
		Stroke = Constants.StrokeHover,
	}, nil, nil, {
		Background = Constants.ToggleOffPressed,
		Stroke = Constants.StrokeDefault,
	})

	--> [`cookie card`]
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.AutoButtonColor = false
	dim.AutoLocalize = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.BorderSizePixel = 0
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.Text = ""
	dim.Visible = false
	dim.Parent = root

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.AutoLocalize = false
	card.BackgroundColor3 = Constants.MenuDefault
	card.BorderSizePixel = 0
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0, 320, 0, 150)
	card.Parent = dim

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "Stroke"
	cardStroke.Color = Constants.StrokeDefault
	cardStroke.Thickness = 1
	cardStroke.Parent = card

	local cardPad = Instance.new("UIPadding")
	cardPad.Name = "Pad"
	cardPad.PaddingBottom = UDim.new(0, 10)
	cardPad.PaddingLeft = UDim.new(0, 10)
	cardPad.PaddingRight = UDim.new(0, 10)
	cardPad.PaddingTop = UDim.new(0, 10)
	cardPad.Parent = card

	local cardList = Instance.new("UIListLayout")
	cardList.Name = "List"
	cardList.Padding = UDim.new(0, 8)
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Name = "Title"
	cardTitle.AutoLocalize = false
	cardTitle.BackgroundTransparency = 1
	cardTitle.BorderSizePixel = 0
	cardTitle.FontFace = Constants.FontSemiBold
	cardTitle.LayoutOrder = 1
	cardTitle.Size = UDim2.new(1, 0, 0, 22)
	cardTitle.Text = "Import .ROBLOSECURITY"
	cardTitle.TextColor3 = Constants.TextMain
	cardTitle.TextSize = 14
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardTitle.Parent = card

	local cookieBox = Instance.new("TextBox")
	cookieBox.Name = "Box"
	cookieBox.AutoLocalize = false
	cookieBox.BackgroundColor3 = Constants.RowDefault
	cookieBox.BorderSizePixel = 0
	cookieBox.ClearTextOnFocus = false
	cookieBox.FontFace = Constants.FontRegular
	cookieBox.LayoutOrder = 2
	cookieBox.PlaceholderColor3 = Constants.TextDim
	cookieBox.PlaceholderText = "Paste cookie here..."
	cookieBox.Size = UDim2.new(1, 0, 0, 28)
	cookieBox.Text = ""
	cookieBox.TextColor3 = Constants.TextMain
	cookieBox.TextSize = 13
	cookieBox.TextXAlignment = Enum.TextXAlignment.Left
	cookieBox.Parent = card

	local cookieBoxStroke = Instance.new("UIStroke")
	cookieBoxStroke.Name = "Stroke"
	cookieBoxStroke.Color = Constants.StrokeDefault
	cookieBoxStroke.Thickness = 1
	cookieBoxStroke.Parent = cookieBox

	local cookieBoxPad = Instance.new("UIPadding")
	cookieBoxPad.Name = "Pad"
	cookieBoxPad.PaddingLeft = UDim.new(0, 8)
	cookieBoxPad.Parent = cookieBox

	local cardRow = Instance.new("Frame")
	cardRow.Name = "Row"
	cardRow.AutoLocalize = false
	cardRow.BackgroundTransparency = 1
	cardRow.BorderSizePixel = 0
	cardRow.LayoutOrder = 3
	cardRow.Size = UDim2.new(1, 0, 0, 28)
	cardRow.Parent = card

	local cardRowList = Instance.new("UIListLayout")
	cardRowList.Name = "List"
	cardRowList.FillDirection = Enum.FillDirection.Horizontal
	cardRowList.Padding = UDim.new(0, 6)
	cardRowList.SortOrder = Enum.SortOrder.LayoutOrder
	cardRowList.Parent = cardRow

	local saveButton = Templates.button()
	saveButton.LayoutOrder = 1
	saveButton.Size = UDim2.new(0.5, -3, 1, 0)
	saveButton.Parent = cardRow
	local saveTitle = saveButton:WaitForChild("Title") :: TextLabel
	saveTitle.Text = "Save"
	saveTitle.TextSize = 13
	Hover.bind(saveButton, TweenService, Constants.FastInfo, {
		Background = Constants.BlueNormal,
		Stroke = nil,
	}, {
		Background = Constants.BlueHover,
		Stroke = nil,
	}, nil, nil, {
		Background = Constants.BluePressed,
		Stroke = nil,
	})

	local cancelButton = Templates.button()
	cancelButton.LayoutOrder = 2
	cancelButton.Size = UDim2.new(0.5, -3, 1, 0)
	cancelButton.BackgroundColor3 = Constants.MenuDefault
	cancelButton.Parent = cardRow
	local cancelTitle = cancelButton:WaitForChild("Title") :: TextLabel
	cancelTitle.Text = "Cancel"
	cancelTitle.TextSize = 13
	local cancelStroke = Instance.new("UIStroke")
	cancelStroke.Name = "Stroke"
	cancelStroke.Color = Constants.StrokeDefault
	cancelStroke.Thickness = 1
	cancelStroke.Parent = cancelButton
	Hover.bind(cancelButton, TweenService, Constants.FastInfo, {
		Background = Constants.MenuDefault,
		Stroke = Constants.StrokeDefault,
	}, {
		Background = Constants.MenuHover,
		Stroke = Constants.StrokeHover,
	}, nil, nil, {
		Background = Constants.ToggleOffPressed,
		Stroke = Constants.StrokeDefault,
	})

	--> [`helpers`]
	local tabButtons: { [string]: TextButton } = {}
	local tabBindings: { [string]: Hover.Binding } = {}
	local tabContents: { [string]: Frame } = {}
	local tabScrollbars: { [string]: Scrollbar.Controller } = {}
	local tabSearches: { [string]: SearchFilter.Handle } = {}
	local tabSections: { [string]: Sections.Handle } = {}
	local tabSidebars: { [string]: Frame } = {}

	local function status(text: string)
		statusLabel.Text = text
	end

	local function portNumber(): number
		local port = tonumber(values.Port or "") or Uplink.DEFAULT_PORT
		if port < 1 or port > 65535 then
			port = Uplink.DEFAULT_PORT
		end
		return port
	end

	local function parsePlaces(): { number }
		local out: { number } = {}
		local text = values.DefaultPlaceIds
		if typeof(text) ~= "string" or text == "" then
			return out
		end
		for part in string.gmatch(text, "([^,]+)") do
			local id = tonumber(string.match(part, "^%s*(.-)%s*$") or "")
			if id ~= nil then
				table.insert(out, id)
			end
		end
		return out
	end

	local function whitelistFor(assetType: string): { string }
		local out: { string } = {}
		local function add(flag: string, class: string)
			if values[flag] == true then
				table.insert(out, class)
			end
		end
		if assetType == "Animation" then
			add("A_Animation", "Animation")
			add("A_Lua", "LuaSourceContainer")
			add("A_String", "StringValue")
			add("A_Number", "NumberValue")
			add("A_Int", "IntValue")
		elseif assetType == "Mesh" then
			add("M_MeshPart", "MeshPart")
			add("M_SpecialMesh", "SpecialMesh")
			add("M_CharacterMesh", "CharacterMesh")
			add("M_Lua", "LuaSourceContainer")
			add("M_String", "StringValue")
			add("M_Number", "NumberValue")
			add("M_Int", "IntValue")
		elseif assetType == "Sound" then
			add("S_Sound", "Sound")
			add("S_Lua", "LuaSourceContainer")
			add("S_String", "StringValue")
			add("S_Number", "NumberValue")
			add("S_Int", "IntValue")
		end
		return out
	end

	local function scopeInstances(): { Instance }
		local out: { Instance } = {}
		if values.SelectionOnly == true then
			for _, selected in Selection:Get() do
				table.insert(out, selected)
				for _, descendant in selected:GetDescendants() do
					table.insert(out, descendant)
				end
			end
		else
			for _, descendant in game:GetDescendants() do
				table.insert(out, descendant)
			end
		end
		return out
	end

	local function gatherMap(assetType: string): { [number]: { Instance } }
		local whitelist = whitelistFor(assetType)
		if #whitelist == 0 then
			return {}
		end
		return Filter.getIds({
			WhitelistedInstances = whitelist,
			Instances = scopeInstances(),
		})
	end

	local function saveSettings()
		for name, value in values do
			pcall(function()
				plugin:SetSetting(`Éclat_{name}`, value)
			end)
		end
	end

	local rebuilding = false
	local function rebuildWidget()
		if rebuilding or busy then
			return
		end
		rebuilding = true
		saveSettings()
		widget:Destroy()
		active = nil
		Panel.open(plugin)
	end

	local function refreshCount()
		if current == "General" then
			topCount.Text = ""
			reuploadTitle.Text = "Reupload"
			return
		end
		if countsStale or countCache[current] == nil then
			local map = gatherMap(current)
			local count = 0
			for _ in map do
				count += 1
			end
			countCache[current] = count
			countsStale = false
		end
		local count = countCache[current] or 0
		topCount.Text = `{count} ids`
		if retryTab == current and pendingRetry ~= nil and #pendingRetry > 0 then
			reuploadTitle.Text = `Retry {#pendingRetry} failed`
		else
			reuploadTitle.Text = `Reupload {current}`
		end
	end

	local function switchTo(name: string)
		current = name
		for _, tab in TAB_NAMES do
			tabContents[tab].Visible = tab == name
			tabBindings[tab].SetSelected(tab == name)
		end
		tabScrollbars[name].Update()
		refreshCount()
	end

	local function ensureLink(): Connection.Connection?
		if sharedLink and sharedLink.Send ~= nil then
			return sharedLink
		end
		if sharedLink then
			pcall(function()
				(sharedLink :: Connection.Connection):Destroy()
			end)
			sharedLink = nil
		end
		local port = portNumber()
		status(`Connecting to :{port}...`)
		local fresh: Connection.Connection? = Uplink.connect(port)
		if fresh then
			sharedLink = fresh
			status(`Engine on :{port}.`)
			return sharedLink
		end
		return nil
	end

	local function runJob(assetType: string, only: { number }?)
		local whitelist = whitelistFor(assetType)
		if #whitelist == 0 then
			status("All find toggles are off.")
			return
		end
		status("Gathering ids...")
		local map = Filter.getIds({
			WhitelistedInstances = whitelist,
			Instances = scopeInstances(),
		})
		local ids = Filter.getIdArray(map)
		if only ~= nil then
			local keep: { [number]: boolean } = {}
			for _, id in only do
				keep[id] = true
			end
			local narrowed: { number } = {}
			for _, id in ids do
				if keep[id] then
					table.insert(narrowed, id)
				end
			end
			ids = narrowed
		end
		if #ids == 0 then
			status("No ids found.")
			return
		end
		local live = ensureLink()
		if not live then
			status("Engine is offline. Start it first.")
			return
		end
		local job: Reupload.Job = {
			AssetType = assetType,
			PlaceId = game.PlaceId,
			CreatorId = game.CreatorId,
			Ids = ids,
			DefaultPlaceIds = parsePlaces(),
			Version = PLUGIN_VERSION,
			IsGroup = game.CreatorType == Enum.CreatorType.Group,
			ExportJson = values.ExportJSON == true,
			During = values.ReplaceMode ~= "Once",
		}
		if typeof(values.CacheMode) == "string" then
			Uplink.setCache(values.CacheMode)
		end
		setProgress(0, #ids)
		local outcome = Reupload.run(live, map, job, {
			Status = status,
			Progress = setProgress,
		})
		setProgress(outcome.Swapped, outcome.Total)
		countsStale = true
		History.record(plugin, assetType, outcome.Swapped, outcome.Total)
		if #outcome.Missing > 0 then
			pendingRetry = outcome.Missing
			retryTab = assetType
			status(`{outcome.Swapped} of {outcome.Total} — {#outcome.Missing} missing, press Reupload to retry.`)
		elseif outcome.Ok then
			pendingRetry = nil
			retryTab = nil
			status(`Done: {outcome.Swapped} swapped of {outcome.Total}.`)
		else
			pendingRetry = nil
			retryTab = nil
			status(`Failed: {outcome.Error or "unknown"}.`)
		end
		saveSettings()
		refreshCount()
		if values.Theme ~= Constants.CurrentTheme then
			task.defer(rebuildWidget)
		end
	end

	local function startJob()
		if busy then
			status("Already running...")
			return
		end
		if current == "General" then
			status("Pick Animation, Mesh, or Sound first.")
			return
		end
		busy = true
		local retry: { number }? = nil
		if retryTab == current then
			retry = pendingRetry
		end
		pendingRetry = nil
		retryTab = nil
		task.spawn(function()
			local ok, err = pcall(runJob, current, retry)
			if not ok then
				status(`Failed: {tostring(err)}.`)
			end
			busy = false
		end)
	end

	local function importCookie()
		local text = cookieBox.Text
		cookieBox.Text = ""
		dim.Visible = false
		if text == "" then
			status("Cookie is empty.")
			return
		end
		status("Importing cookie...")
		task.spawn(function()
			local ok, user = Cookie.importCookie(portNumber(), text)
			if ok and user then
				status(`Cookie live as {user.displayName}.`)
			else
				status("Cookie rejected.")
			end
		end)
	end

	local openThemeCard: (mode: string, text: string) -> () = function(_mode: string, _text: string) end

	local function saveCustom(name: string, custom: CustomTheme)
		pcall(function()
			plugin:SetSetting("Éclat_Custom_" .. name, custom)
		end)
		if customs[name] == nil then
			table.insert(customIndex, name)
		end
		customs[name] = custom
		pcall(function()
			plugin:SetSetting("Éclat_CustomIndex", customIndex)
		end)
	end

	local function loadThemeIntoEditor(name: string)
		local custom: CustomTheme? = customs[name]
		if custom ~= nil then
			for _, key in COLOR_KEYS do
				local hex = custom.Colors[key]
				if typeof(hex) == "string" then
					values["T_" .. key] = hex
				end
			end
			values.FontBody = custom.Fonts.regular
			values.FontEmphasis = custom.Fonts.emphasis
			return
		end
		local palette = Constants.palette(name)
		if palette == nil then
			return
		end
		for _, key in COLOR_KEYS do
			local color: Color3 = palette[key]
			values["T_" .. key] = toHex(color)
		end
		local families = Constants.families(name)
		if families ~= nil then
			values.FontBody = families.regular
			values.FontEmphasis = families.emphasis
		end
	end

	local function editorPalette(): (CustomTheme, number)
		local colors: { [string]: string } = {}
		local bad = 0
		for _, key in COLOR_KEYS do
			local text = values["T_" .. key]
			if typeof(text) == "string" and fromHex(text) ~= nil then
				colors[key] = text
			else
				bad += 1
				colors[key] = toHex(Constants[key])
			end
		end
		local body = values.FontBody
		local emphasis = values.FontEmphasis
		if body ~= "source" and body ~= "montserrat" and body ~= "arcade" then
			body = "source"
		end
		if emphasis ~= "source" and emphasis ~= "montserrat" and emphasis ~= "gotham" and emphasis ~= "arcade" then
			emphasis = "source"
		end
		return { Colors = colors, Fonts = { regular = body, emphasis = emphasis } }, bad
	end

	local function doImportTheme(text: string)
		if text == "" then
			status("Paste a theme first.")
			return
		end
		local parsed, data = pcall(function()
			return HttpService:JSONDecode(text)
		end)
		if not parsed or typeof(data) ~= "table" then
			status("That is not a theme.")
			return
		end
		local colors = data.colors
		local fonts = data.fonts
		if typeof(colors) ~= "table" or typeof(fonts) ~= "table" then
			status("Theme needs colors plus fonts.")
			return
		end
		local custom: CustomTheme = { Colors = {}, Fonts = { regular = "source", emphasis = "source" } }
		local good = 0
		for _, key in COLOR_KEYS do
			local hex = colors[key]
			if typeof(hex) == "string" and fromHex(hex) ~= nil then
				custom.Colors[key] = hex
				good += 1
			else
				custom.Colors[key] = toHex(Constants[key])
			end
		end
		local body = fonts.regular
		local emphasis = fonts.emphasis
		if body == "source" or body == "montserrat" or body == "arcade" then
			custom.Fonts.regular = body
		end
		if emphasis == "source" or emphasis == "montserrat" or emphasis == "gotham" or emphasis == "arcade" then
			custom.Fonts.emphasis = emphasis
		end
		local name = cleanName(if typeof(data.name) == "string" then data.name else "")
		if name == "" or name == "Persona" or name == "Eclat" or name == "Pixel" then
			name = "Imported"
			local n = 2
			local taken: CustomTheme? = customs[name]
			while taken ~= nil do
				name = `Imported {n}`
				n += 1
				taken = customs[name]
			end
		end
		saveCustom(name, custom)
		values.Theme = name
		loadThemeIntoEditor(name)
		saveSettings()
		if good < #COLOR_KEYS then
			status(`Imported {name} with {#COLOR_KEYS - good} fields repaired.`)
		else
			status(`Imported {name}.`)
		end
		rebuildWidget()
	end

	local function pushCacheMode()
		local mode = values.CacheMode
		if typeof(mode) ~= "string" then
			return
		end
		if not Uplink.setCache(mode) then
			status("Engine is offline — start it first.")
			return
		end
		if mode == "Fresh" then
			status("Engine will read fresh every run.")
		elseif mode == "Hour" then
			status("Engine will update every hour.")
		elseif mode == "Day" then
			status("Engine will update every day.")
		else
			status("Engine will keep its list until you clear it.")
		end
	end

	local function onButtonPressed(name: string)
		if name == "SaveTheme" then
			local themeName = cleanName(values.CustomName)
			if themeName == "" then
				status("Name your theme first.")
				return
			end
			if themeName == "Persona" or themeName == "Eclat" or themeName == "Pixel" then
				status("Built-ins keep their names. Pick another.")
				return
			end
			local custom, bad = editorPalette()
			saveCustom(themeName, custom)
			values.Theme = themeName
			loadThemeIntoEditor(themeName)
			saveSettings()
			if bad > 0 then
				status(`Saved {themeName} with {bad} fields repaired.`)
			else
				status(`Saved {themeName}.`)
			end
			rebuildWidget()
			return
		end
		if name == "DeleteTheme" then
			local selected = values.Theme
			local gone: CustomTheme? = customs[selected]
			if selected == nil or gone == nil then
				status("Only customs can go.")
				return
			end
			customs[selected] = nil
			for i, entry in customIndex do
				if entry == selected then
					table.remove(customIndex, i)
					break
				end
			end
			pcall(function()
				plugin:SetSetting("Éclat_Custom_" .. selected, nil)
			end)
			pcall(function()
				plugin:SetSetting("Éclat_CustomIndex", customIndex)
			end)
			values.Theme = "Eclat"
			loadThemeIntoEditor("Eclat")
			saveSettings()
			status(`Deleted {selected}.`)
			rebuildWidget()
			return
		end
		if name == "ExportTheme" then
			local custom, _bad = editorPalette()
			local payload = {
				app = "eclat",
				kind = "theme",
				version = 1,
				name = values.Theme,
				colors = custom.Colors,
				fonts = custom.Fonts,
			}
			local encoded, json = pcall(function()
				return HttpService:JSONEncode(payload)
			end)
			if encoded then
				print(`[Éclat] theme export: {json}`)
				openThemeCard("export", json)
			else
				status("Export failed.")
			end
			return
		end
		if name == "ImportTheme" then
			openThemeCard("import", "")
			return
		end
		if name == "RefreshData" then
			if Uplink.refreshList() then
				status("Saved list cleared — next run reads fresh.")
			else
				status("Engine is offline — start it first.")
			end
			return
		end
	end

	--> [`theme card`]
	local dimT = Instance.new("TextButton")
	dimT.Name = "DimT"
	dimT.AutoButtonColor = false
	dimT.AutoLocalize = false
	dimT.BackgroundColor3 = Color3.new(0, 0, 0)
	dimT.BackgroundTransparency = 0.4
	dimT.BorderSizePixel = 0
	dimT.Size = UDim2.new(1, 0, 1, 0)
	dimT.Text = ""
	dimT.Visible = false
	dimT.Parent = root

	local cardT = Instance.new("Frame")
	cardT.Name = "CardT"
	cardT.AnchorPoint = Vector2.new(0.5, 0.5)
	cardT.AutoLocalize = false
	cardT.BackgroundColor3 = Constants.MenuDefault
	cardT.BorderSizePixel = 0
	cardT.Position = UDim2.new(0.5, 0, 0.5, 0)
	cardT.Size = UDim2.new(0, 340, 0, 270)
	cardT.Parent = dimT

	local cardTStroke = Instance.new("UIStroke")
	cardTStroke.Name = "Stroke"
	cardTStroke.Color = Constants.StrokeDefault
	cardTStroke.Thickness = 1
	cardTStroke.Parent = cardT

	local cardTPad = Instance.new("UIPadding")
	cardTPad.Name = "Pad"
	cardTPad.PaddingBottom = UDim.new(0, 10)
	cardTPad.PaddingLeft = UDim.new(0, 10)
	cardTPad.PaddingRight = UDim.new(0, 10)
	cardTPad.PaddingTop = UDim.new(0, 10)
	cardTPad.Parent = cardT

	local cardTList = Instance.new("UIListLayout")
	cardTList.Name = "List"
	cardTList.Padding = UDim.new(0, 8)
	cardTList.SortOrder = Enum.SortOrder.LayoutOrder
	cardTList.Parent = cardT

	local cardTTitle = Instance.new("TextLabel")
	cardTTitle.Name = "Title"
	cardTTitle.AutoLocalize = false
	cardTTitle.BackgroundTransparency = 1
	cardTTitle.BorderSizePixel = 0
	cardTTitle.FontFace = Constants.FontSemiBold
	cardTTitle.LayoutOrder = 1
	cardTTitle.Size = UDim2.new(1, 0, 0, 22)
	cardTTitle.Text = "Theme"
	cardTTitle.TextColor3 = Constants.TextMain
	cardTTitle.TextSize = 14
	cardTTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardTTitle.Parent = cardT

	local themeBox = Instance.new("TextBox")
	themeBox.Name = "Box"
	themeBox.AutoLocalize = false
	themeBox.BackgroundColor3 = Constants.RowDefault
	themeBox.BorderSizePixel = 0
	themeBox.ClearTextOnFocus = false
	themeBox.FontFace = Constants.FontRegular
	themeBox.LayoutOrder = 2
	themeBox.MultiLine = true
	themeBox.Size = UDim2.new(1, 0, 0, 172)
	themeBox.Text = ""
	themeBox.TextColor3 = Constants.TextMain
	themeBox.TextSize = 12
	themeBox.TextWrapped = true
	themeBox.TextXAlignment = Enum.TextXAlignment.Left
	themeBox.TextYAlignment = Enum.TextYAlignment.Top
	themeBox.Parent = cardT

	local themeBoxStroke = Instance.new("UIStroke")
	themeBoxStroke.Name = "Stroke"
	themeBoxStroke.Color = Constants.StrokeDefault
	themeBoxStroke.Thickness = 1
	themeBoxStroke.Parent = themeBox

	local themeBoxPad = Instance.new("UIPadding")
	themeBoxPad.Name = "Pad"
	themeBoxPad.PaddingLeft = UDim.new(0, 8)
	themeBoxPad.PaddingRight = UDim.new(0, 8)
	themeBoxPad.PaddingTop = UDim.new(0, 6)
	themeBoxPad.Parent = themeBox

	local themeRow = Instance.new("Frame")
	themeRow.Name = "Row"
	themeRow.AutoLocalize = false
	themeRow.BackgroundTransparency = 1
	themeRow.BorderSizePixel = 0
	themeRow.LayoutOrder = 3
	themeRow.Size = UDim2.new(1, 0, 0, 28)
	themeRow.Parent = cardT

	local themeRowList = Instance.new("UIListLayout")
	themeRowList.Name = "List"
	themeRowList.FillDirection = Enum.FillDirection.Horizontal
	themeRowList.Padding = UDim.new(0, 6)
	themeRowList.SortOrder = Enum.SortOrder.LayoutOrder
	themeRowList.Parent = themeRow

	local themeGo = Templates.button()
	themeGo.LayoutOrder = 1
	themeGo.Size = UDim2.new(0.5, -3, 1, 0)
	themeGo.Parent = themeRow
	local themeGoTitle = themeGo:WaitForChild("Title") :: TextLabel
	themeGoTitle.Text = "Import"
	themeGoTitle.TextSize = 13
	Hover.bind(themeGo, TweenService, Constants.FastInfo, {
		Background = Constants.BlueNormal,
		Stroke = nil,
	}, {
		Background = Constants.BlueHover,
		Stroke = nil,
	}, nil, nil, {
		Background = Constants.BluePressed,
		Stroke = nil,
	})

	local themeShut = Templates.button()
	themeShut.LayoutOrder = 2
	themeShut.Size = UDim2.new(0.5, -3, 1, 0)
	themeShut.BackgroundColor3 = Constants.MenuDefault
	themeShut.Parent = themeRow
	local themeShutTitle = themeShut:WaitForChild("Title") :: TextLabel
	themeShutTitle.Text = "Close"
	themeShutTitle.TextSize = 13
	local themeShutStroke = Instance.new("UIStroke")
	themeShutStroke.Name = "Stroke"
	themeShutStroke.Color = Constants.StrokeDefault
	themeShutStroke.Thickness = 1
	themeShutStroke.Parent = themeShut
	Hover.bind(themeShut, TweenService, Constants.FastInfo, {
		Background = Constants.MenuDefault,
		Stroke = Constants.StrokeDefault,
	}, {
		Background = Constants.MenuHover,
		Stroke = Constants.StrokeHover,
	}, nil, nil, {
		Background = Constants.ToggleOffPressed,
		Stroke = Constants.StrokeDefault,
	})

	openThemeCard = function(mode: string, text: string)
		cardTTitle.Text = if mode == "export" then "Export theme — copy this" else "Import theme — paste, then Import"
		themeBox.Text = text
		themeGo.Visible = mode == "import"
		themeShut.Size = if mode == "export" then UDim2.new(1, 0, 1, 0) else UDim2.new(0.5, -3, 1, 0)
		dimT.Visible = true
		if mode == "import" then
			themeBox:CaptureFocus()
		end
	end
	themeGo.MouseButton1Click:Connect(function()
		local text = themeBox.Text
		themeBox.Text = ""
		dimT.Visible = false
		doImportTheme(text)
	end)
	themeShut.MouseButton1Click:Connect(function()
		themeBox.Text = ""
		dimT.Visible = false
	end)

	--> [`build tabs`]
	for index, name in TAB_NAMES do
		local tabName = name
		local button = Templates.tab()
		button.Name = tabName
		button.LayoutOrder = index
		button.Size = UDim2.new(0.25, -5, 1, 0)
		button.Parent = tabs
		local buttonTitle = button:WaitForChild("Title") :: TextLabel
		buttonTitle.Text = tabName
		tabButtons[tabName] = button
		tabBindings[tabName] = Hover.bind(button, TweenService, Constants.FastInfo, {
			Background = Constants.MenuDefault,
			Stroke = Constants.StrokeDefault,
		}, {
			Background = Constants.MenuHover,
			Stroke = Constants.StrokeHover,
		}, {
			Background = Constants.HeaderDefault,
			Stroke = Constants.StrokeSelected,
		}, {
			Background = Constants.MenuHover,
			Stroke = Constants.StrokeSelected,
		}, {
			Background = Constants.HeaderHover,
			Stroke = Constants.StrokeSelected,
		})
		button.MouseButton1Click:Connect(function()
			switchTo(tabName)
		end)

		local tabContent = Instance.new("Frame")
		tabContent.Name = tabName
		tabContent.AutoLocalize = false
		tabContent.BackgroundTransparency = 1
		tabContent.BorderSizePixel = 0
		tabContent.Size = UDim2.new(1, 0, 1, 0)
		tabContent.Visible = false
		tabContent.Parent = content
		tabContents[tabName] = tabContent

		local filterRoot = Templates.filter()
		filterRoot.Name = "Filter"
		filterRoot.Parent = tabContent

		local body = Instance.new("Frame")
		body.Name = "Body"
		body.AutoLocalize = false
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Position = UDim2.new(0, 0, 0, 30)
		body.Size = UDim2.new(1, 0, 1, -30)
		body.Parent = tabContent

		local pane = Templates.pane()
		pane.Name = "Pane"
		pane.Parent = body

		local sidebar = Templates.sidebar()
		sidebar.Name = "Sidebar"
		sidebar.Position = UDim2.new(1, -8, 0, 0)
		sidebar.Parent = body
		tabSidebars[tabName] = sidebar
		local scroller = sidebar:WaitForChild("Scroller") :: TextButton

		tabSections[tabName] = Sections.build(pane, tabContent, tabName, {
			TweenService = TweenService,
			PluginGuiService = nil,
			FastInfo = Constants.FastInfo,
			SlowInfo = Constants.SlowInfo,
			SetDropdownOpen = function(open: boolean)
				dropdownOpen = open
				if open then
					sidebar.Visible = false
				end
			end,
			OnSectionToggled = function()
				tabScrollbars[tabName].Update()
			end,
			OnValueChanged = function(name: string)
				countsStale = true
				if name == "Theme" then
					loadThemeIntoEditor(if typeof(values.Theme) == "string" then values.Theme else "Eclat")
					task.defer(rebuildWidget)
				end
				if name == "CacheMode" then
					pushCacheMode()
				end
			end,
			OnButtonPressed = onButtonPressed,
			GetChoices = function(setName: string)
				if setName ~= "Theme" then
					return nil
				end
				local choices: { [string]: string } = { Persona = "Persona", Eclat = "Éclat", Pixel = "Pixel" }
				for _, entry in customIndex do
					choices[entry] = entry
				end
				return choices
			end,
		}, defaults, values, registered)

		tabScrollbars[tabName] = Scrollbar({
			Main = pane,
			Sidebar = sidebar,
			Scroller = scroller,
			TweenService = TweenService,
			Info = Constants.FastInfo,
			BottomPadding = 8,
			OnScrolled = function()
				tabSections[tabName].HideInfo()
			end,
			OnVisibleChanged = function(_visible: boolean)
				if dropdownOpen then
					sidebar.Visible = false
				end
			end,
		})

		tabSearches[tabName] = SearchFilter.attach(filterRoot, {
			Pane = pane,
			TweenService = TweenService,
			FastInfo = Constants.FastInfo,
			Empty = nil,
			ShowEmptyWhenNoQuery = false,
			OnFiltered = function(_matches: number)
				tabScrollbars[tabName].Update()
			end,
		})
	end

	--> [`wire`]
	reuploadButton.MouseButton1Click:Connect(function()
		startJob()
	end)
	cookieButton.MouseButton1Click:Connect(function()
		dim.Visible = true
		cookieBox.Text = ""
		cookieBox:CaptureFocus()
	end)
	saveButton.MouseButton1Click:Connect(function()
		importCookie()
	end)
	cancelButton.MouseButton1Click:Connect(function()
		cookieBox.Text = ""
		dim.Visible = false
	end)
	cookieBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed and dim.Visible then
			importCookie()
		end
	end)
	widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not widget.Enabled then
			saveSettings()
		end
	end)

	switchTo("General")

	local last = History.last(plugin)
	if last ~= nil then
		status(`Last run: {last.AssetType} {last.Swapped}/{last.Total} at {last.At}.`)
	end

	local handle: Handle = {
		Widget = widget,
		Refresh = refreshCount,
	}
	active = handle
	return handle
end

return table.freeze(Panel)
