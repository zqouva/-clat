--!strict
--!optimize 2

-- Runs one reupload job over a live link.

local HttpService = game:GetService("HttpService")

local Connection = require(script.Parent.Connection)
local Filter = require(script.Parent.Filter)
local Uplink = require(script.Parent.Uplink)

local Reupload = {}

export type Job = {
	AssetType: string,
	PlaceId: number,
	CreatorId: number,
	Ids: { number },
	DefaultPlaceIds: { number },
	Version: string,
	IsGroup: boolean,
	ExportJson: boolean,
	During: boolean,
}

export type Events = {
	Status: (text: string) -> (),
	Progress: (swapped: number, total: number) -> (),
	ShouldCancel: (() -> boolean)?,
}

export type Outcome = {
	Ok: boolean,
	Swapped: number,
	Total: number,
	Error: string?,
	Missing: { number },
}

--> [`run`]
function Reupload.run(
	link: Connection.Connection,
	map: { [number]: { Instance } },
	job: Job,
	events: Events
): Outcome
	local total = #job.Ids
	if total == 0 then
		return { Ok = false, Swapped = 0, Total = 0, Error = "no ids found", Missing = {} }
	end

	local pairs: { Filter.IdPair } = {}
	local answered: { [number]: boolean } = {}
	local wanted: { [number]: boolean } = {}
	for _, id in job.Ids do
		wanted[id] = true
	end
	local swapped = 0
	local finished = false
	local lost = false
	local lastBeat = os.clock()
	local idleData = link.onData
	local idleGone = link.onDisconnect

	local function restore()
		if link.Send ~= nil then
			link.onData = idleData
			link.onDisconnect = idleGone
		end
	end

	local function missingIds(): { number }
		local out: { number } = {}
		for _, id in job.Ids do
			if not answered[id] then
				table.insert(out, id)
			end
		end
		return out
	end

	link.onData = function(data: string)
		lastBeat = os.clock()
		if finished then
			return
		end
		local text = string.gsub(data, "%s+$", "")
		if text == "" then
			return
		end
		if text == "done" then
			finished = true
			return
		end
		local parsed, chunk = pcall(HttpService.JSONDecode, HttpService, text)
		if not parsed or typeof(chunk) ~= "table" then
			return
		end
		for _, answer in chunk do
			if typeof(answer) == "table" then
				local oldId = tonumber(answer.oldId)
				local newId = tonumber(answer.newId)
				if oldId ~= nil and newId ~= nil and wanted[oldId] and not answered[oldId] then
					if job.During then
						Filter.replaceIds(map, { { oldId = oldId, newId = newId } })
					else
						table.insert(pairs, { oldId = oldId, newId = newId })
					end
					swapped += 1
					answered[oldId] = true
					events.Status(`{swapped} of {total}...`)
					events.Progress(swapped, total)
				end
			end
		end
	end
	link.onDisconnect = function()
		lost = true
		finished = true
	end

	events.Status(`Sending {total} ids...`)
	local petition: Uplink.ReuploadPetition = {
		placeId = job.PlaceId,
		creatorId = job.CreatorId,
		ids = job.Ids,
		defaultPlaceIds = job.DefaultPlaceIds,
		pluginVersion = job.Version,
		assetType = job.AssetType,
		exportJson = job.ExportJson,
		isGroup = job.IsGroup,
	}
	local called, sent, response = pcall(function(): (boolean, string)
		return link:Send("/reupload", HttpService:JSONEncode(petition))
	end)
	if not called then
		restore()
		return { Ok = false, Swapped = 0, Total = total, Error = "engine went away", Missing = table.clone(job.Ids) }
	end
	if not sent then
		restore()
		if string.find(tostring(response), "503", 1, true) ~= nil then
			return { Ok = false, Swapped = 0, Total = total, Error = "engine is busy — wait a moment, then retry", Missing = {} }
		end
		return { Ok = false, Swapped = 0, Total = total, Error = tostring(response), Missing = table.clone(job.Ids) }
	end

	events.Status("Waiting on the engine...")
	while not finished do
		task.wait(0.1)
		if os.clock() - lastBeat > 20 then
			restore()
			return { Ok = false, Swapped = swapped, Total = total, Error = "link went quiet — press Reupload to retry", Missing = missingIds() }
		end
		if events.ShouldCancel ~= nil and events.ShouldCancel() then
			restore()
			return { Ok = true, Swapped = swapped, Total = total, Error = nil, Missing = missingIds() }
		end
	end
	restore()
	if lost then
		return { Ok = false, Swapped = swapped, Total = total, Error = "engine went away", Missing = missingIds() }
	end
	if not job.During and #pairs > 0 then
		events.Status("Pasting all ids...")
		Filter.replaceIds(map, pairs)
	end
	return { Ok = true, Swapped = swapped, Total = total, Error = nil, Missing = missingIds() }
end

return table.freeze(Reupload)
