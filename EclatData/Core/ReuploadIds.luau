--!strict

-->
-->	["reuploadids"]
-->	the whole rite in one verse: gather → petition → replace → done.
-->	bring your own bells (any table with :Notify(title, message)).

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local Filter = require(script.Parent.Filter)
local Retry = require(script.Parent.Retry)
local StatusCodes = require(script.Parent.StatusCodes)
local Uplink = require(script.Parent.Uplink)

local ReuploadIds = {}

export type FilterAsk = {
	WhitelistedInstances: { string },
	Instances: { Instance },
}

local busy = false

local function scriptInjectionEnabled(): boolean
	local probe = Instance.new("Script")
	local ok = pcall(ScriptEditorService.UpdateSourceAsync, ScriptEditorService, probe, function()
		return ""
	end)
	probe:Destroy()
	return ok
end

local function getGameInfo(): (boolean, number, number)
	local creatorId, placeId = game.CreatorId, game.PlaceId
	if placeId == 0 then
		return false, creatorId, placeId
	end
	if creatorId ~= 0 then
		return game.CreatorType == Enum.CreatorType.Group, creatorId, placeId
	end
	local ok, result = Retry(3, MarketplaceService.GetProductInfo, MarketplaceService, placeId)
	if not ok then
		return false, creatorId, placeId
	end
	local creator = (result :: any).Creator
	return creator.CreatorType == "Group", creator.CreatorTargetId, placeId
end

function ReuploadIds.start(plugin: Plugin, ui: any, filterOptions: FilterAsk, assetType: string, placeArray: { number }?)
	if busy then
		ui:Notify("Notification", "Éclat is already carrying.")
		return
	end
	busy = true

	if not scriptInjectionEnabled() then
		ui:Notify("Notification", "Éclat needs script injection permission.")
		busy = false
		return
	end

	local isGroup, creatorId, placeId = getGameInfo()
	if placeId == 0 then
		ui:Notify("Notification", "Publish the place first, then restart it.")
		busy = false
		return
	elseif creatorId == 0 then
		ui:Notify("Notification", "Place info would not wake. Try again.")
		busy = false
		return
	end

	local found = Filter.getIds(filterOptions)
	if next(found) == nil then
		ui:Notify("Notification", "No ids found.")
		busy = false
		return
	end

	local portNumber = tonumber(plugin:GetSetting("Port")) or Uplink.DEFAULT_PORT
	local link, seed = Uplink.connect(portNumber)
	if not link then
		ui:Notify("Notification", "No engine on the wire. Did you start éclat?")
		busy = false
		return
	end

	local function onData(data: string)
		local ok, result = pcall(HttpService.JSONDecode, HttpService, data)
		if not ok then
			if data ~= "done" then
				return
			end
			ui:Notify("Notification", "All ids carried home.")
			busy = false
			link:Destroy()
			return
		end
		local pairs = result :: { { oldId: number, newId: number } }
		if #pairs == 0 then
			return
		end
		Filter.replaceIds(found, pairs)
		warn(`[Éclat] replaced {#pairs} ids`)
	end

	link.onData = onData
	link.onDisconnect = function()
		ui:Notify("Notification", "The engine let go. (Try reconnecting.)")
		busy = false
	end

	local ids = Filter.getIdArray(found)
	local petition = {
		placeId = placeId,
		creatorId = creatorId,
		ids = ids,
		defaultPlaceIds = placeArray or {},
		pluginVersion = Uplink.PROTOCOL,
		assetType = assetType,
		exportJson = plugin:GetSetting("ExportJSON") == true,
		isGroup = isGroup,
	}
	local sent, statusCode = link:Send("/reupload", HttpService:JSONEncode(petition))
	if not sent then
		local mood = StatusCodes[statusCode] or ("The engine would not take the petition.\n" .. statusCode)
		ui:Notify("Notification", mood)
		busy = false
		link:Destroy()
		return
	end

	ui:Notify("Notification", `Sent {#ids} ids to éclat.`)
	if seed then
		onData(seed)
	end
end

return table.freeze(ReuploadIds)
