--!strict
--!optimize 2

-- Builds every interface template in code.

local Constants = require(script.Parent.Constants)

local Templates = {}

--> [`row`]
function Templates.boolean(): Frame
	local Boolean = Instance.new("Frame")
	Boolean.Name = "Boolean"
	Boolean.AutoLocalize = false
	Boolean.BackgroundColor3 = Color3.new(0, 0, 0)
	Boolean.BackgroundTransparency = 1
	Boolean.BorderColor3 = Color3.new(0, 0, 0)
	Boolean.BorderSizePixel = 0
	Boolean.Size = UDim2.new(1, 0, 0, 26)

	local Tap = Instance.new("TextButton")
	Tap.Name = "Tap"
	Tap.AnchorPoint = Vector2.new(1, 0.5)
	Tap.AutoButtonColor = false
	Tap.AutoLocalize = false
	Tap.BackgroundColor3 = Color3.new(0.098, 0.102, 0.122)
	Tap.BorderColor3 = Color3.new(0, 0, 0)
	Tap.BorderSizePixel = 0
	Tap.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
	Tap.Position = UDim2.new(1, 0, 0.5, 0)
	Tap.Size = UDim2.new(0.5, -1, 0, 24)
	Tap.Text = ""
	Tap.TextColor3 = Color3.new(0.863, 0.863, 0.863)
	Tap.TextSize = 14
	Tap.TextXAlignment = Enum.TextXAlignment.Left
	Tap.Parent = Boolean

	local Mark = Instance.new("Frame")
	Mark.Name = "Mark"
	Mark.AnchorPoint = Vector2.new(0, 0.5)
	Mark.AutoLocalize = false
	Mark.BackgroundColor3 = Color3.new(0.278, 0.506, 1)
	Mark.BorderColor3 = Color3.new(0, 0, 0)
	Mark.BorderSizePixel = 0
	Mark.Interactable = false
	Mark.Position = UDim2.new(0, 12, 0.5, 0)
	Mark.Size = UDim2.new(0, 28, 0, 16)
	Mark.Parent = Tap

	local Corner = Instance.new("UICorner")
	Corner.Name = "Corner"
	Corner.CornerRadius = UDim.new(0, 9)
	Corner.Parent = Mark

	local Bubble = Instance.new("Frame")
	Bubble.Name = "Bubble"
	Bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	Bubble.AutoLocalize = false
	Bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	Bubble.BorderColor3 = Color3.new(0, 0, 0)
	Bubble.BorderSizePixel = 0
	Bubble.Interactable = false
	Bubble.Position = UDim2.new(1, -6, 0.5, 0)
	Bubble.Size = UDim2.new(1, 0, 1, 0)
	Bubble.SizeConstraint = Enum.SizeConstraint.RelativeYY
	Bubble.Parent = Mark

	local BubbleCorner = Instance.new("UICorner")
	BubbleCorner.Name = "Corner"
	BubbleCorner.CornerRadius = UDim.new(0.5, 0)
	BubbleCorner.Parent = Bubble

	local Pad = Instance.new("UIPadding")
	Pad.Name = "Pad"
	Pad.PaddingBottom = UDim.new(0, 2)
	Pad.PaddingLeft = UDim.new(0, 2)
	Pad.PaddingRight = UDim.new(0, 2)
	Pad.PaddingTop = UDim.new(0, 2)
	Pad.Parent = Mark

	local Branch = Instance.new("TextLabel")
	Branch.Name = "Branch"
	Branch.AutoLocalize = false
	Branch.BackgroundColor3 = Color3.new(0, 0, 0)
	Branch.BackgroundTransparency = 1
	Branch.BorderColor3 = Color3.new(0, 0, 0)
	Branch.BorderSizePixel = 0
	Branch.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	Branch.Position = UDim2.new(0, 12, 0, 0)
	Branch.Size = UDim2.new(0, 0, 0, 24)
	Branch.Text = "├"
	Branch.TextColor3 = Color3.new(0.871, 0.871, 0.871)
	Branch.TextSize = 14
	Branch.TextTruncate = Enum.TextTruncate.AtEnd
	Branch.TextXAlignment = Enum.TextXAlignment.Left
	Branch.Parent = Boolean

	local BranchPad = Instance.new("UIPadding")
	BranchPad.Name = "Pad"
	BranchPad.PaddingLeft = UDim.new(0, 12)
	BranchPad.Parent = Branch

	local Title = Instance.new("TextButton")
	Title.Name = "Title"
	Title.AnchorPoint = Vector2.new(0, 0.5)
	Title.AutoButtonColor = false
	Title.AutoLocalize = false
	Title.BackgroundColor3 = Color3.new(0.098, 0.102, 0.122)
	Title.BorderColor3 = Color3.new(0, 0, 0)
	Title.BorderSizePixel = 0
	Title.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	Title.Position = UDim2.new(0, 0, 0.5, 0)
	Title.Selectable = false
	Title.Size = UDim2.new(0.5, -1, 0, 24)
	Title.Text = "Boolean"
	Title.TextColor3 = Color3.new(0.871, 0.871, 0.871)
	Title.TextSize = 14
	Title.TextTruncate = Enum.TextTruncate.AtEnd
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Boolean

	local TitlePad = Instance.new("UIPadding")
	TitlePad.Name = "Pad"
	TitlePad.PaddingLeft = UDim.new(0, 30)
	TitlePad.Parent = Title

	local Info = Instance.new("ImageButton")
	Info.Name = "Info"
	Info.AnchorPoint = Vector2.new(1, 0.5)
	Info.AutoButtonColor = false
	Info.AutoLocalize = false
	Info.BackgroundColor3 = Color3.new(0, 0, 0)
	Info.BackgroundTransparency = 1
	Info.BorderColor3 = Color3.new(0, 0, 0)
	Info.BorderSizePixel = 0
	Info.Image = "rbxasset://studio_svg_textures/Lua/FileSync/Dark/Standard/Info.png"
	Info.Position = UDim2.new(1, -6, 0.5, 0)
	Info.Selectable = false
	Info.Size = UDim2.new(0, 12, 0, 12)
	Info.Parent = Title

	return Boolean
end

--> [`text`]
function Templates.text(): Frame
	local Text = Instance.new("Frame")
	Text.Name = "Text"
	Text.AutoLocalize = false
	Text.BackgroundTransparency = 1
	Text.BorderSizePixel = 0
	Text.Size = UDim2.new(1, 0, 0, 26)

	local Branch = Instance.new("TextLabel")
	Branch.Name = "Branch"
	Branch.AutoLocalize = false
	Branch.BackgroundTransparency = 1
	Branch.BorderSizePixel = 0
	Branch.FontFace = Constants.FontRegular
	Branch.Position = UDim2.new(0, 12, 0, 0)
	Branch.Size = UDim2.new(0, 0, 0, 24)
	Branch.Text = "├"
	Branch.TextColor3 = Constants.TextMain
	Branch.TextSize = 14
	Branch.TextXAlignment = Enum.TextXAlignment.Left
	Branch.Parent = Text

	local BranchPad = Instance.new("UIPadding")
	BranchPad.Name = "Pad"
	BranchPad.PaddingLeft = UDim.new(0, 12)
	BranchPad.Parent = Branch

	local Title = Instance.new("TextButton")
	Title.Name = "Title"
	Title.AnchorPoint = Vector2.new(0, 0.5)
	Title.AutoButtonColor = false
	Title.AutoLocalize = false
	Title.BackgroundColor3 = Constants.RowDefault
	Title.BorderSizePixel = 0
	Title.FontFace = Constants.FontRegular
	Title.Position = UDim2.new(0, 0, 0.5, 0)
	Title.Selectable = false
	Title.Size = UDim2.new(0.5, -1, 0, 24)
	Title.Text = "Text"
	Title.TextColor3 = Constants.TextMain
	Title.TextSize = 14
	Title.TextTruncate = Enum.TextTruncate.AtEnd
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Text

	local TitlePad = Instance.new("UIPadding")
	TitlePad.Name = "Pad"
	TitlePad.PaddingLeft = UDim.new(0, 30)
	TitlePad.Parent = Title

	local Info = Instance.new("ImageButton")
	Info.Name = "Info"
	Info.AnchorPoint = Vector2.new(1, 0.5)
	Info.AutoButtonColor = false
	Info.AutoLocalize = false
	Info.BackgroundTransparency = 1
	Info.BorderSizePixel = 0
	Info.Image = "rbxasset://studio_svg_textures/Lua/FileSync/Dark/Standard/Info.png"
	Info.Position = UDim2.new(1, -6, 0.5, 0)
	Info.Selectable = false
	Info.Size = UDim2.new(0, 12, 0, 12)
	Info.Parent = Title

	local Box = Instance.new("TextBox")
	Box.Name = "Box"
	Box.AnchorPoint = Vector2.new(1, 0.5)
	Box.AutoLocalize = false
	Box.BackgroundColor3 = Constants.RowDefault
	Box.BorderSizePixel = 0
	Box.ClearTextOnFocus = false
	Box.FontFace = Constants.FontRegular
	Box.PlaceholderColor3 = Constants.TextDim
	Box.Position = UDim2.new(1, 0, 0.5, 0)
	Box.Size = UDim2.new(0.5, -1, 0, 24)
	Box.Text = ""
	Box.TextColor3 = Constants.TextMain
	Box.TextSize = 14
	Box.TextXAlignment = Enum.TextXAlignment.Left
	Box.Parent = Text

	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "Stroke"
	Stroke.Color = Constants.StrokeDefault
	Stroke.Thickness = 1
	Stroke.Parent = Box

	local BoxPad = Instance.new("UIPadding")
	BoxPad.Name = "Pad"
	BoxPad.PaddingLeft = UDim.new(0, 8)
	BoxPad.Parent = Box

	return Text
end

--> [`custom`]
function Templates.custom(): Frame
	local Custom = Instance.new("Frame")
	Custom.Name = "Custom"
	Custom.AutoLocalize = false
	Custom.BackgroundTransparency = 1
	Custom.BorderSizePixel = 0
	Custom.Size = UDim2.new(1, 0, 0, 26)

	local Branch = Instance.new("TextLabel")
	Branch.Name = "Branch"
	Branch.AutoLocalize = false
	Branch.BackgroundTransparency = 1
	Branch.BorderSizePixel = 0
	Branch.FontFace = Constants.FontRegular
	Branch.Position = UDim2.new(0, 12, 0, 0)
	Branch.Size = UDim2.new(0, 0, 0, 24)
	Branch.Text = "├"
	Branch.TextColor3 = Constants.TextMain
	Branch.TextSize = 14
	Branch.TextXAlignment = Enum.TextXAlignment.Left
	Branch.Parent = Custom

	local BranchPad = Instance.new("UIPadding")
	BranchPad.Name = "Pad"
	BranchPad.PaddingLeft = UDim.new(0, 12)
	BranchPad.Parent = Branch

	local Title = Instance.new("TextButton")
	Title.Name = "Title"
	Title.AnchorPoint = Vector2.new(0, 0.5)
	Title.AutoButtonColor = false
	Title.AutoLocalize = false
	Title.BackgroundColor3 = Constants.RowDefault
	Title.BorderSizePixel = 0
	Title.FontFace = Constants.FontRegular
	Title.Position = UDim2.new(0, 0, 0.5, 0)
	Title.Selectable = false
	Title.Size = UDim2.new(0.5, -1, 0, 24)
	Title.Text = "Custom"
	Title.TextColor3 = Constants.TextMain
	Title.TextSize = 14
	Title.TextTruncate = Enum.TextTruncate.AtEnd
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Custom

	local TitlePad = Instance.new("UIPadding")
	TitlePad.Name = "Pad"
	TitlePad.PaddingLeft = UDim.new(0, 30)
	TitlePad.Parent = Title

	local Info = Instance.new("ImageButton")
	Info.Name = "Info"
	Info.AnchorPoint = Vector2.new(1, 0.5)
	Info.AutoButtonColor = false
	Info.AutoLocalize = false
	Info.BackgroundTransparency = 1
	Info.BorderSizePixel = 0
	Info.Image = "rbxasset://studio_svg_textures/Lua/FileSync/Dark/Standard/Info.png"
	Info.Position = UDim2.new(1, -6, 0.5, 0)
	Info.Selectable = false
	Info.Size = UDim2.new(0, 12, 0, 12)
	Info.Parent = Title

	local Tap = Instance.new("TextButton")
	Tap.Name = "Tap"
	Tap.AnchorPoint = Vector2.new(1, 0.5)
	Tap.AutoButtonColor = false
	Tap.AutoLocalize = false
	Tap.BackgroundColor3 = Constants.RowDefault
	Tap.BorderSizePixel = 0
	Tap.FontFace = Constants.FontSemiBold
	Tap.Position = UDim2.new(1, 0, 0.5, 0)
	Tap.Size = UDim2.new(0.5, -1, 0, 24)
	Tap.Text = ""
	Tap.TextColor3 = Constants.TextMain
	Tap.TextSize = 14
	Tap.TextXAlignment = Enum.TextXAlignment.Left
	Tap.Parent = Custom

	local TapPad = Instance.new("UIPadding")
	TapPad.Name = "Pad"
	TapPad.PaddingLeft = UDim.new(0, 8)
	TapPad.Parent = Tap

	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "Stroke"
	Stroke.Color = Constants.StrokeDefault
	Stroke.Thickness = 1
	Stroke.Enabled = false
	Stroke.Parent = Tap

	local Down = Instance.new("TextButton")
	Down.Name = "Down"
	Down.AnchorPoint = Vector2.new(1, 0.5)
	Down.AutoButtonColor = false
	Down.AutoLocalize = false
	Down.BackgroundTransparency = 1
	Down.BorderSizePixel = 0
	Down.FontFace = Constants.FontRegular
	Down.Position = UDim2.new(1, -4, 0.5, 0)
	Down.Size = UDim2.new(0, 16, 0, 16)
	Down.Text = "▾"
	Down.TextColor3 = Constants.TextDim
	Down.TextSize = 12
	Down.Parent = Tap

	local Items = Instance.new("Frame")
	Items.Name = "Items"
	Items.AutoLocalize = false
	Items.BackgroundColor3 = Constants.RowDefault
	Items.BorderSizePixel = 0
	Items.ClipsDescendants = true
	Items.Position = UDim2.new(0.5, 1, 0, 26)
	Items.Size = UDim2.new(0.5, -1, 0, 0)
	Items.Visible = false
	Items.ZIndex = 5
	Items.Parent = Custom

	local List = Instance.new("UIListLayout")
	List.Name = "List"
	List.Parent = Items

	local ItemsStroke = Instance.new("UIStroke")
	ItemsStroke.Name = "Stroke"
	ItemsStroke.Color = Constants.StrokeDefault
	ItemsStroke.Thickness = 1
	ItemsStroke.Parent = Items

	return Custom
end

--> [`item`]
function Templates.item(): TextButton
	local Item = Instance.new("TextButton")
	Item.Name = "Item"
	Item.AutoButtonColor = false
	Item.AutoLocalize = false
	Item.BackgroundColor3 = Constants.RowDefault
	Item.BorderSizePixel = 0
	Item.FontFace = Constants.FontRegular
	Item.Size = UDim2.new(1, 0, 0, 18)
	Item.Text = ""
	Item.TextColor3 = Constants.TextMain
	Item.TextSize = 13
	Item.TextXAlignment = Enum.TextXAlignment.Left

	local Pad = Instance.new("UIPadding")
	Pad.Name = "Pad"
	Pad.PaddingLeft = UDim.new(0, 8)
	Pad.Parent = Item

	return Item
end

--> [`section`]
function Templates.section(): Frame
	local Section = Instance.new("Frame")
	Section.Name = "Section"
	Section.AutoLocalize = false
	Section.AutomaticSize = Enum.AutomaticSize.Y
	Section.BackgroundTransparency = 1
	Section.BorderSizePixel = 0
	Section.Size = UDim2.new(1, 0, 0, 0)

	local List = Instance.new("UIListLayout")
	List.Name = "List"
	List.Parent = Section

	local Header = Instance.new("TextButton")
	Header.Name = "Header"
	Header.AutoButtonColor = false
	Header.AutoLocalize = false
	Header.BackgroundColor3 = Constants.HeaderDefault
	Header.BorderSizePixel = 0
	Header.LayoutOrder = 0
	Header.Size = UDim2.new(1, 0, 0, 24)
	Header.Text = ""
	Header.Parent = Section

	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.AutoLocalize = false
	Title.BackgroundTransparency = 1
	Title.BorderSizePixel = 0
	Title.FontFace = Constants.FontSemiBold
	Title.Position = UDim2.new(0, 12, 0, 0)
	Title.Size = UDim2.new(1, -36, 0, 24)
	Title.Text = ""
	Title.TextColor3 = Constants.TextMain
	Title.TextSize = 14
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Header

	local Arrow = Instance.new("TextButton")
	Arrow.Name = "Arrow"
	Arrow.AnchorPoint = Vector2.new(1, 0.5)
	Arrow.AutoButtonColor = false
	Arrow.AutoLocalize = false
	Arrow.BackgroundTransparency = 1
	Arrow.BorderSizePixel = 0
	Arrow.FontFace = Constants.FontRegular
	Arrow.Position = UDim2.new(1, -6, 0.5, 0)
	Arrow.Size = UDim2.new(0, 20, 0, 20)
	Arrow.Text = "▾"
	Arrow.TextColor3 = Constants.TextDim
	Arrow.TextSize = 12
	Arrow.Parent = Header

	return Section
end

--> [`menu`]
function Templates.menuRow(): TextButton
	local Row = Instance.new("TextButton")
	Row.AutoButtonColor = false
	Row.AutoLocalize = false
	Row.BackgroundColor3 = Constants.MenuDefault
	Row.BorderSizePixel = 0
	Row.Size = UDim2.new(1, 0, 0, 26)
	Row.Text = ""

	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "Stroke"
	Stroke.Color = Constants.StrokeDefault
	Stroke.Thickness = 1
	Stroke.Parent = Row

	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.AutoLocalize = false
	Title.BackgroundTransparency = 1
	Title.BorderSizePixel = 0
	Title.FontFace = Constants.FontSemiBold
	Title.Position = UDim2.new(0, 12, 0, 0)
	Title.Size = UDim2.new(1, -24, 0, 26)
	Title.Text = ""
	Title.TextColor3 = Constants.TextMain
	Title.TextSize = 14
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Row

	return Row
end

--> [`tab`]
function Templates.tab(): TextButton
	local Tab = Instance.new("TextButton")
	Tab.AutoButtonColor = false
	Tab.AutoLocalize = false
	Tab.BackgroundColor3 = Constants.MenuDefault
	Tab.BorderSizePixel = 0
	Tab.Size = UDim2.new(0, 120, 0, 28)
	Tab.Text = ""

	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "Stroke"
	Stroke.Color = Constants.StrokeDefault
	Stroke.Thickness = 1
	Stroke.Parent = Tab

	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.AutoLocalize = false
	Title.BackgroundTransparency = 1
	Title.BorderSizePixel = 0
	Title.FontFace = Constants.FontSemiBold
	Title.Size = UDim2.new(1, 0, 1, 0)
	Title.Text = ""
	Title.TextColor3 = Constants.TextMain
	Title.TextSize = 14
	Title.Parent = Tab

	return Tab
end

--> [`button`]
function Templates.button(): TextButton
	local Button = Instance.new("TextButton")
	Button.AutoButtonColor = false
	Button.AutoLocalize = false
	Button.BackgroundColor3 = Constants.BlueNormal
	Button.BorderSizePixel = 0
	Button.Size = UDim2.new(1, 0, 0, 30)
	Button.Text = ""

	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.AutoLocalize = false
	Title.BackgroundTransparency = 1
	Title.BorderSizePixel = 0
	Title.FontFace = Constants.FontSemiBold
	Title.Size = UDim2.new(1, 0, 1, 0)
	Title.Text = ""
	Title.TextColor3 = Color3.new(1, 1, 1)
	Title.TextSize = 14
	Title.Parent = Button

	return Button
end

--> [`status`]
function Templates.status(): TextLabel
	local Status = Instance.new("TextLabel")
	Status.AutoLocalize = false
	Status.BackgroundTransparency = 1
	Status.BorderSizePixel = 0
	Status.FontFace = Constants.FontRegular
	Status.Size = UDim2.new(1, 0, 0, 18)
	Status.Text = ""
	Status.TextColor3 = Constants.TextDim
	Status.TextSize = 12
	Status.TextTruncate = Enum.TextTruncate.AtEnd
	Status.TextXAlignment = Enum.TextXAlignment.Left
	return Status
end

--> [`pane`]
function Templates.pane(): ScrollingFrame
	local Pane = Instance.new("ScrollingFrame")
	Pane.AutoLocalize = false
	Pane.BackgroundTransparency = 1
	Pane.BorderSizePixel = 0
	Pane.CanvasSize = UDim2.new(0, 0, 0, 0)
	Pane.ScrollBarThickness = 0
	Pane.ScrollingDirection = Enum.ScrollingDirection.Y
	Pane.ScrollingEnabled = true
	Pane.Size = UDim2.new(1, 0, 1, 0)

	local List = Instance.new("UIListLayout")
	List.Name = "List"
	List.Padding = UDim.new(0, 4)
	List.Parent = Pane

	local Pad = Instance.new("UIPadding")
	Pad.Name = "Pad"
	Pad.PaddingBottom = UDim.new(0, 8)
	Pad.PaddingRight = UDim.new(0, 4)
	Pad.Parent = Pane

	return Pane
end

--> [`sidebar`]
function Templates.sidebar(): Frame
	local Sidebar = Instance.new("Frame")
	Sidebar.AutoLocalize = false
	Sidebar.Active = true
	Sidebar.BackgroundTransparency = 1
	Sidebar.BorderSizePixel = 0
	Sidebar.Size = UDim2.new(0, 8, 1, 0)

	local Scroller = Instance.new("TextButton")
	Scroller.Name = "Scroller"
	Scroller.AutoButtonColor = false
	Scroller.AutoLocalize = false
	Scroller.Active = true
	Scroller.BackgroundColor3 = Color3.fromRGB(106, 111, 129)
	Scroller.BorderSizePixel = 0
	Scroller.Size = UDim2.new(1, 0, 0, 20)
	Scroller.Text = ""
	Scroller.Parent = Sidebar

	local Corner = Instance.new("UICorner")
	Corner.Name = "Corner"
	Corner.CornerRadius = UDim.new(0, 3)
	Corner.Parent = Scroller

	return Sidebar
end

--> [`filter`]
function Templates.filter(): Frame
	local Filter = Instance.new("Frame")
	Filter.AutoLocalize = false
	Filter.BackgroundTransparency = 1
	Filter.BorderSizePixel = 0
	Filter.Size = UDim2.new(1, 0, 0, 26)

	local Search = Instance.new("TextBox")
	Search.Name = "Search"
	Search.AutoLocalize = false
	Search.BackgroundColor3 = Constants.RowDefault
	Search.BorderSizePixel = 0
	Search.ClearTextOnFocus = false
	Search.FontFace = Constants.FontRegular
	Search.PlaceholderColor3 = Constants.TextDim
	Search.PlaceholderText = "Search..."
	Search.Size = UDim2.new(1, 0, 1, 0)
	Search.Text = ""
	Search.TextColor3 = Constants.TextMain
	Search.TextSize = 14
	Search.TextXAlignment = Enum.TextXAlignment.Left
	Search.Parent = Filter

	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "Stroke"
	Stroke.Color = Constants.StrokeDefault
	Stroke.Thickness = 1
	Stroke.Parent = Search

	local Pad = Instance.new("UIPadding")
	Pad.Name = "Pad"
	Pad.PaddingLeft = UDim.new(0, 27)
	Pad.Parent = Search

	local Placeholder = Instance.new("TextLabel")
	Placeholder.Name = "Placeholder"
	Placeholder.AnchorPoint = Vector2.new(0, 0.5)
	Placeholder.AutoLocalize = false
	Placeholder.BackgroundTransparency = 1
	Placeholder.BorderSizePixel = 0
	Placeholder.FontFace = Constants.FontRegular
	Placeholder.Position = UDim2.new(0, 32, 0.5, 0)
	Placeholder.Size = UDim2.new(1, -70, 0, 18)
	Placeholder.Text = "Search..."
	Placeholder.TextColor3 = Constants.TextDim
	Placeholder.TextSize = 14
	Placeholder.TextXAlignment = Enum.TextXAlignment.Left
	Placeholder.Parent = Filter

	local Icon = Instance.new("ImageButton")
	Icon.Name = "Icon"
	Icon.AnchorPoint = Vector2.new(0, 0.5)
	Icon.AutoButtonColor = false
	Icon.AutoLocalize = false
	Icon.BackgroundTransparency = 1
	Icon.BorderSizePixel = 0
	Icon.Image = "rbxasset://textures/ui/SearchIcon.png"
	Icon.Position = UDim2.new(0, 6, 0.5, 0)
	Icon.Size = UDim2.new(0, 16, 0, 16)
	Icon.Parent = Filter

	return Filter
end

--> [`empty`]
function Templates.empty(): TextLabel
	local Empty = Instance.new("TextLabel")
	Empty.AutoLocalize = false
	Empty.BackgroundTransparency = 1
	Empty.BorderSizePixel = 0
	Empty.FontFace = Constants.FontRegular
	Empty.Size = UDim2.new(1, 0, 0, 24)
	Empty.Text = "Nothing found"
	Empty.TextColor3 = Constants.TextDim
	Empty.TextSize = 13
	Empty.Visible = false
	return Empty
end

--> [`topbar`]
function Templates.topbar(): Frame
	local Topbar = Instance.new("Frame")
	Topbar.AutoLocalize = false
	Topbar.BackgroundTransparency = 1
	Topbar.BorderSizePixel = 0
	Topbar.Size = UDim2.new(1, 0, 0, 32)

	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.AutoLocalize = false
	Title.BackgroundTransparency = 1
	Title.BorderSizePixel = 0
	Title.FontFace = Constants.FontSemiBold
	Title.Size = UDim2.new(1, -120, 1, 0)
	Title.Text = ""
	Title.TextColor3 = Constants.TextMain
	Title.TextSize = 15
	Title.TextTruncate = Enum.TextTruncate.AtEnd
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = Topbar

	local Count = Instance.new("TextLabel")
	Count.Name = "Count"
	Count.AnchorPoint = Vector2.new(1, 0.5)
	Count.AutoLocalize = false
	Count.BackgroundTransparency = 1
	Count.BorderSizePixel = 0
	Count.FontFace = Constants.FontRegular
	Count.Position = UDim2.new(1, -28, 0.5, 0)
	Count.Size = UDim2.new(0, 80, 0, 18)
	Count.Text = ""
	Count.TextColor3 = Constants.TextDim
	Count.TextSize = 12
	Count.TextXAlignment = Enum.TextXAlignment.Right
	Count.Parent = Topbar

	local Close = Instance.new("TextButton")
	Close.Name = "Close"
	Close.AnchorPoint = Vector2.new(1, 0.5)
	Close.AutoButtonColor = false
	Close.AutoLocalize = false
	Close.BackgroundTransparency = 1
	Close.BorderSizePixel = 0
	Close.FontFace = Constants.FontRegular
	Close.Position = UDim2.new(1, -4, 0.5, 0)
	Close.Size = UDim2.new(0, 20, 0, 20)
	Close.Text = "✕"
	Close.TextColor3 = Constants.TextDim
	Close.TextSize = 12
	Close.Parent = Topbar

	return Topbar
end

--> [`info`]
function Templates.info(): Frame
	local Info = Instance.new("Frame")
	Info.AutoLocalize = false
	Info.BackgroundColor3 = Constants.RowDefault
	Info.BorderSizePixel = 0
	Info.Size = UDim2.new(1, 0, 0, 136)
	Info.Visible = false

	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "Stroke"
	Stroke.Color = Constants.StrokeDefault
	Stroke.Thickness = 1
	Stroke.Parent = Info

	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.AutoLocalize = false
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.FontFace = Constants.FontRegular
	Label.Position = UDim2.new(0, 10, 0, 8)
	Label.RichText = true
	Label.Size = UDim2.new(1, -20, 1, -16)
	Label.Text = ""
	Label.TextColor3 = Constants.TextMain
	Label.TextSize = 13
	Label.TextWrapped = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Top
	Label.Parent = Info

	local Close = Instance.new("TextButton")
	Close.Name = "Close"
	Close.AnchorPoint = Vector2.new(1, 0)
	Close.AutoButtonColor = false
	Close.AutoLocalize = false
	Close.BackgroundTransparency = 1
	Close.BorderSizePixel = 0
	Close.FontFace = Constants.FontRegular
	Close.Position = UDim2.new(1, -6, 0, 6)
	Close.Size = UDim2.new(0, 16, 0, 16)
	Close.Text = "✕"
	Close.TextColor3 = Constants.TextDim
	Close.TextSize = 11
	Close.Parent = Info

	return Info
end

return table.freeze(Templates)
