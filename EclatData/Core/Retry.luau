--!strict

-->
-->	["retry"]
-->	kneel up to N times; rise with (true, firstfruit) or (false, nil).

return function(tries: number, fn: (...any) -> ...any, ...: any): (boolean, any)
	local args = table.pack(...)
	for _ = 1, tries do
		local results = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
		if results[1] == true then
			return true, results[2]
		end
	end
	return false, nil
end
