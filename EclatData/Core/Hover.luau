--!strict
--!optimize 2

-- Tweened hover and selection colors.

local Hover = {}

export type Style = {
	Background: Color3,
	Stroke: Color3?,
}

export type Binding = {
	SetSelected: (boolean) -> (),
}

type State = {
	Selected: boolean,
	Hovering: boolean,
	BackgroundTarget: Color3?,
	StrokeTarget: Color3?,
	BackgroundTween: Tween?,
	StrokeTween: Tween?,
}

local function tweenBackground(tweenService: TweenService, info: TweenInfo, obj: GuiObject, state: State, color: Color3)
	if state.BackgroundTarget == color then
		return
	end
	local current = state.BackgroundTween
	if current then
		current:Cancel()
	end
	state.BackgroundTarget = color
	local tween = tweenService:Create(obj, info, { BackgroundColor3 = color })
	state.BackgroundTween = tween
	tween:Play()
end

local function tweenStroke(tweenService: TweenService, info: TweenInfo, stroke: UIStroke?, state: State, color: Color3?)
	if stroke == nil or color == nil or state.StrokeTarget == color then
		return
	end
	local current = state.StrokeTween
	if current then
		current:Cancel()
	end
	state.StrokeTarget = color
	local tween = tweenService:Create(stroke, info, { Color = color })
	state.StrokeTween = tween
	tween:Play()
end

function Hover.bind(
	obj: GuiObject,
	tweenService: TweenService,
	info: TweenInfo,
	defaultStyle: Style,
	hoverStyle: Style,
	selectedStyle: Style?,
	selectedHoverStyle: Style?
): Binding
	local found = obj:FindFirstChild("Stroke")
	local stroke: UIStroke? = nil
	if found and found:IsA("UIStroke") then
		stroke = found
	end
	local state: State = {
		Selected = false,
		Hovering = false,
		BackgroundTarget = nil,
		StrokeTarget = nil,
		BackgroundTween = nil,
		StrokeTween = nil,
	}
	local function refresh()
		local style: Style
		if state.Selected and state.Hovering then
			style = selectedHoverStyle or hoverStyle
		elseif state.Selected then
			style = selectedStyle or defaultStyle
		elseif state.Hovering then
			style = hoverStyle
		else
			style = defaultStyle
		end
		tweenBackground(tweenService, info, obj, state, style.Background)
		tweenStroke(tweenService, info, stroke, state, style.Stroke)
	end
	obj.MouseEnter:Connect(function()
		state.Hovering = true
		refresh()
	end)
	obj.MouseLeave:Connect(function()
		state.Hovering = false
		refresh()
	end)
	refresh()
	local function setSelected(selected: boolean)
		state.Selected = selected
		refresh()
	end
	return {
		SetSelected = setSelected,
	}
end

return table.freeze(Hover)
