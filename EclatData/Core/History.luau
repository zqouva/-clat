--!strict
--!optimize 2

-- A short log of past runs, kept in plugin settings.

local History = {}

export type Run = {
	At: string,
	AssetType: string,
	Swapped: number,
	Total: number,
}

local KEY = "Éclat_History"
local CAP = 8

--> [`read`]
local function read(plugin: Plugin): { Run }
	local found, saved = pcall(function()
		return plugin:GetSetting(KEY)
	end)
	if not found or typeof(saved) ~= "table" then
		return {}
	end
	return saved :: { Run }
end

--> [`record`]
function History.record(plugin: Plugin, assetType: string, swapped: number, total: number)
	local log = read(plugin)
	table.insert(log, 1, {
		At = os.date("%H:%M"),
		AssetType = assetType,
		Swapped = swapped,
		Total = total,
	})
	while #log > CAP do
		table.remove(log)
	end
	pcall(function()
		plugin:SetSetting(KEY, log)
	end)
end

--> [`last`]
function History.last(plugin: Plugin): Run?
	local log = read(plugin)
	return log[1]
end

return table.freeze(History)
