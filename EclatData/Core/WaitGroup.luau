--!strict


local WaitGroup = {}

export type WaitGroup = {
	_count: number,
	_event: BindableEvent,

	Add: (self: WaitGroup, count: number?) -> (),
	Done: (self: WaitGroup) -> (),
	Wait: (self: WaitGroup) -> (),
	Destroy: (self: WaitGroup) -> (),
}

local function Add(self: WaitGroup, count: number?)
	self._count += count or 1
end

local function Done(self: WaitGroup)
	self._count -= 1
	if self._count <= 0 then
		self._count = 0
		self._event:Fire()
	end
end

local function Wait(self: WaitGroup)
	if self._count > 0 then
		self._event.Event:Wait()
	end
end

local function Destroy(self: WaitGroup)
	self._event:Destroy()
	table.clear(self :: any)
end

function WaitGroup.new(): WaitGroup
	local self: WaitGroup = {
		_count = 0,
		_event = Instance.new("BindableEvent"),
		Add = Add,
		Done = Done,
		Wait = Wait,
		Destroy = Destroy,
	}
	return self
end

return table.freeze(WaitGroup)
