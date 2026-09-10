--!strict
--!optimize 2

--> [`eclat`]
local Panel = require(script.Core.Panel)

local Eclat = {}

export type Handle = Panel.Handle

Eclat.VERSION = "1.3.1"

function Eclat.open(plugin: Plugin): Panel.Handle
	return Panel.open(plugin)
end

return table.freeze(Eclat)
