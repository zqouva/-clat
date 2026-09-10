--!strict
--!optimize 2

-- Synced custom scrollbar for a scrolling frame.

export type Controller = {
	SetTarget: (ScrollingFrame?) -> (),
	Update: () -> (),
}

export type Context = {
	Main: ScrollingFrame?,
	Sidebar: GuiObject,
	Scroller: GuiObject,
	TweenService: TweenService,
	Info: TweenInfo,
	FullSize: UDim2?,
	ScrollSize: UDim2?,
	BottomPadding: number?,
	OnScrolled: (() -> ())?,
	OnVisibleChanged: ((boolean) -> ())?,
}

local ScrollerHoverColor = Color3.fromRGB(122, 128, 148)
local ScrollerDefaultColor = Color3.fromRGB(106, 111, 129)
local MainFullSize = UDim2.new(1, 0, 1, 0)
local MainScrollSize = UDim2.new(1, -11, 1, 0)

local function getInputY(input: InputObject): number
	return input.Position.Y
end

local function isSelectInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
end

local function isDragInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement
end

local function getList(main: ScrollingFrame): (UIListLayout | UIGridLayout)?
	local list = main:FindFirstChild("List")
	if list and (list:IsA("UIListLayout") or list:IsA("UIGridLayout")) then
		return list
	end
	return nil
end

local function getCanvasY(main: ScrollingFrame, bottomPadding: number): number
	local list = getList(main)
	if list then
		return list.AbsoluteContentSize.Y + bottomPadding
	end
	return main.AbsoluteCanvasSize.Y
end

local function build(context: Context): Controller
	local main = context.Main
	local dragging = false
	local dragOffset = 0
	local hovering = false
	local scrollVisible: boolean? = nil
	local scrollerColorTween: Tween? = nil
	local scrollerColorTarget = context.Scroller.BackgroundColor3
	local connections: { RBXScriptConnection } = {}

	context.Sidebar.Active = true
	context.Scroller.Active = true

	local fullSize = context.FullSize or MainFullSize
	local scrollSize = context.ScrollSize or MainScrollSize
	local bottomPadding = context.BottomPadding or 0

	local function tweenScrollerColor(color: Color3)
		if scrollerColorTarget == color then
			return
		end
		if scrollerColorTween then
			scrollerColorTween:Cancel()
		end
		scrollerColorTarget = color
		scrollerColorTween = context.TweenService:Create(context.Scroller, context.Info, { BackgroundColor3 = color })
		scrollerColorTween:Play()
	end

	local function refreshScrollerColor()
		tweenScrollerColor(if hovering or dragging then ScrollerHoverColor else ScrollerDefaultColor)
	end

	local function setScrollVisible(visible: boolean)
		context.Sidebar.Visible = visible
		context.Scroller.Visible = visible
		if main then
			main.Size = if visible then scrollSize else fullSize
		end
		if scrollVisible ~= visible then
			scrollVisible = visible
			local onVisibleChanged = context.OnVisibleChanged
			if onVisibleChanged then
				onVisibleChanged(visible)
			end
		end
	end

	local function getMaxCanvasY(): number
		if not main then
			return 0
		end
		local maxCanvasY = getCanvasY(main, bottomPadding) - main.AbsoluteWindowSize.Y
		return if maxCanvasY > 0 then maxCanvasY else 0
	end

	local function setCanvasY(canvasY: number)
		if not main then
			return
		end
		local maxCanvasY = getMaxCanvasY()
		local y = canvasY
		if y < 0 then
			y = 0
		elseif y > maxCanvasY then
			y = maxCanvasY
		end
		main.CanvasPosition = Vector2.new(main.CanvasPosition.X, y)
	end

	local function updateCanvasSize()
		if main then
			main.CanvasSize = UDim2.new(main.CanvasSize.X.Scale, main.CanvasSize.X.Offset, 0, getCanvasY(main, bottomPadding))
		end
	end

	local function update()
		if not main then
			setScrollVisible(false)
			dragging = false
			return
		end
		local sidebarHeight = context.Sidebar.AbsoluteSize.Y
		if sidebarHeight <= 0 then
			return
		end
		local maxCanvasY = getMaxCanvasY()
		if maxCanvasY <= 0 then
			setScrollVisible(false)
			dragging = false
			setCanvasY(0)
			return
		end
		setScrollVisible(true)
		local windowY = main.AbsoluteWindowSize.Y
		local canvasY = getCanvasY(main, bottomPadding)
		local scrollerHeight = sidebarHeight * windowY / canvasY
		if scrollerHeight < 20 then
			scrollerHeight = 20
		elseif scrollerHeight > sidebarHeight then
			scrollerHeight = sidebarHeight
		end
		local maxScrollerY = sidebarHeight - scrollerHeight
		local scrollerY = maxScrollerY * (main.CanvasPosition.Y / maxCanvasY)
		context.Scroller.Size = UDim2.new(context.Scroller.Size.X.Scale, context.Scroller.Size.X.Offset, 0, scrollerHeight)
		context.Scroller.Position = UDim2.new(context.Scroller.Position.X.Scale, context.Scroller.Position.X.Offset, 0, scrollerY)
	end

	local function onCanvasPositionChanged()
		update()
		refreshScrollerColor()
		local onScrolled = context.OnScrolled
		if onScrolled then
			onScrolled()
		end
	end

	local function setCanvasFromScroller(inputY: number)
		if not main then
			return
		end
		local maxCanvasY = getMaxCanvasY()
		local maxScrollerY = context.Sidebar.AbsoluteSize.Y - context.Scroller.AbsoluteSize.Y
		if maxCanvasY <= 0 or maxScrollerY <= 0 then
			setCanvasY(0)
			return
		end
		local scrollerY = inputY - context.Sidebar.AbsolutePosition.Y - dragOffset
		if scrollerY < 0 then
			scrollerY = 0
		elseif scrollerY > maxScrollerY then
			scrollerY = maxScrollerY
		end
		setCanvasY(maxCanvasY * (scrollerY / maxScrollerY))
	end

	local function disconnectTarget()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local function connectTarget()
		if not main then
			return
		end
		local target = main
		local list = getList(target)
		table.insert(connections, target:GetPropertyChangedSignal("CanvasPosition"):Connect(onCanvasPositionChanged))
		table.insert(connections, target:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
			setCanvasY(target.CanvasPosition.Y)
			update()
			refreshScrollerColor()
		end))
		if list then
			table.insert(connections, list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				updateCanvasSize()
				setCanvasY(target.CanvasPosition.Y)
				update()
				refreshScrollerColor()
			end))
		else
			table.insert(connections, target:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
				setCanvasY(target.CanvasPosition.Y)
				update()
				refreshScrollerColor()
			end))
		end
		updateCanvasSize()
	end

	local function setTarget(nextMain: ScrollingFrame?)
		disconnectTarget()
		main = nextMain
		dragging = false
		connectTarget()
		setCanvasY(0)
		update()
		refreshScrollerColor()
	end

	context.Sidebar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		update()
		refreshScrollerColor()
	end)

	context.Scroller.MouseEnter:Connect(function()
		hovering = true
		refreshScrollerColor()
	end)

	context.Scroller.MouseLeave:Connect(function()
		hovering = false
		refreshScrollerColor()
	end)

	local function beginDrag(inputY: number)
		dragging = true
		refreshScrollerColor()
		dragOffset = inputY - context.Scroller.AbsolutePosition.Y
		setCanvasFromScroller(inputY)
	end

	local function endDrag()
		dragging = false
		refreshScrollerColor()
	end

	context.Scroller.InputChanged:Connect(function(input: InputObject)
		if dragging and isDragInput(input) then
			setCanvasFromScroller(getInputY(input))
		end
	end)

	context.Sidebar.InputChanged:Connect(function(input: InputObject)
		if dragging and isDragInput(input) then
			setCanvasFromScroller(getInputY(input))
		end
	end)

	context.Scroller.InputBegan:Connect(function(input: InputObject)
		if isSelectInput(input) then
			beginDrag(getInputY(input))
		end
	end)

	context.Scroller.InputEnded:Connect(function(input: InputObject)
		if isSelectInput(input) then
			endDrag()
		end
	end)

	context.Sidebar.InputEnded:Connect(function(input: InputObject)
		if isSelectInput(input) then
			endDrag()
		end
	end)

	if context.Scroller:IsA("GuiButton") then
		local scrollerButton = context.Scroller
		scrollerButton.MouseButton1Down:Connect(function(_x: number, y: number)
			beginDrag(y)
		end)
		scrollerButton.MouseButton1Up:Connect(function()
			endDrag()
		end)
	end

	local dragDetector = Instance.new("UIDragDetector")
	dragDetector.Name = "ScrollbarDrag"
	dragDetector.DragStyle = Enum.UIDragDetectorDragStyle.TranslateLine
	dragDetector.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomOffset
	dragDetector.DragAxis = Vector2.yAxis
	dragDetector.ReferenceUIInstance = context.Sidebar
	dragDetector.Parent = context.Scroller

	dragDetector.DragStart:Connect(function(inputPosition: Vector2)
		beginDrag(inputPosition.Y)
	end)

	dragDetector.DragContinue:Connect(function(inputPosition: Vector2)
		if dragging then
			setCanvasFromScroller(inputPosition.Y)
		end
	end)

	dragDetector.DragEnd:Connect(function(_inputPosition: Vector2)
		endDrag()
	end)

	setTarget(main)

	return {
		SetTarget = setTarget,
		Update = update,
	}
end

return build
