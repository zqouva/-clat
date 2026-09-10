--!strict
--!optimize 2

-- Pointer hit-testing and activation checks.

local Input = {}

function Input.IsPointInFrame(point: Vector2, frame: GuiObject): boolean
	local pos = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	return point.X >= pos.X
		and point.X <= pos.X + size.X
		and point.Y >= pos.Y
		and point.Y <= pos.Y + size.Y
end

function Input.IsSelectInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
end

function Input.GetInputPoint(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

return table.freeze(Input)
