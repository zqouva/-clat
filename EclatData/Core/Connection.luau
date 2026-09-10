--!strict


local HttpService = game:GetService("HttpService")

local Connection = {}

export type Connection = {
	_port: number,
	_thread: thread?,

	onData: ((data: string) -> ())?,
	onDisconnect: (() -> ())?,

	Send: (self: Connection, path: string, body: string) -> (boolean, string),
	Destroy: (self: Connection) -> (),
}

local function get(port: number): string
	return HttpService:GetAsync(`http://127.0.0.1:{port}/`)
end

local function post(port: number, path: string, data: string): string
	return HttpService:PostAsync(`http://127.0.0.1:{port}{path}`, data, Enum.HttpContentType.ApplicationJson)
end

local function checkConnectionStatus(self: Connection)
	local connected, data = pcall(get, self._port)
	if not connected then
		if self.onDisconnect then
			self.onDisconnect()
		end
		self:Destroy()
		return
	end

	if self.onData then
		self.onData(data :: string)
	end
	self._thread = task.delay(0.25, checkConnectionStatus, self)
end

local function Send(self: Connection, path: string, body: string): (boolean, string)
	local success, response = pcall(post, self._port, path, body)
	return success :: boolean, response :: string
end

local function Destroy(self: Connection)
	if self._thread ~= nil then
		task.cancel(self._thread)
		self._thread = nil
	end
	table.clear(self :: any)
end

function Connection.new(port: number): (Connection?, string?)
	local connected, data = pcall(get, port)
	if not connected then
		return nil, nil
	end

	local self: Connection = {
		_port = port,
		_thread = nil,
		onData = nil,
		onDisconnect = nil,
		Send = Send,
		Destroy = Destroy,
	}
	self._thread = task.delay(0.25, checkConnectionStatus, self)

	local text = data :: string
	if text == "" or text == "null\n" then
		return self, nil
	end
	return self, text
end

return table.freeze(Connection)
