--!strict

-->
-->	["boot"]
-->	a headless pilgrimage: carry every Animation id sleeping in the place.
-->	1. start the engine (it prints its magenta psalm).
-->	2. drop Eclat under ServerStorage.Packages.Eclat.
-->	3. run this script. watch the terminal glow.

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Eclat = require(ServerStorage.Packages.Eclat)
local FilterLib = require(ServerStorage.Packages.Eclat.Core.Filter)

assert(game.PlaceId ~= 0, "[Éclat/Boot] publish the place first, then restart it.")

local found = Eclat.filter({
	WhitelistedInstances = { "Animation" },
	Instances = game:GetDescendants(),
})
local ids = FilterLib.getIdArray(found)
assert(#ids > 0, "[Éclat/Boot] no animation ids found.")

local link, seed = Eclat.connect()
assert(link, "[Éclat/Boot] no engine on the wire. did you start éclat?")

local finished = Instance.new("BindableEvent")
link.onData = function(data: string)
	if data == "done" then
		finished:Fire()
		return
	end
	local ok, pairs = pcall(HttpService.JSONDecode, HttpService, data)
	if ok and typeof(pairs) == "table" and #pairs > 0 then
		Eclat.replace(found, pairs)
		warn(`[Éclat/Boot] replaced {#pairs} ids`)
	end
end
link.onDisconnect = function()
	warn("[Éclat/Boot] the engine let go.")
	finished:Fire()
end

local petition = {
	placeId = game.PlaceId,
	creatorId = game.CreatorId,
	ids = ids,
	defaultPlaceIds = {},
	pluginVersion = Eclat.PROTOCOL,
	assetType = "Animation",
	exportJson = true,
	isGroup = game.CreatorType == Enum.CreatorType.Group,
}
local sent, status = link:Send("/reupload", HttpService:JSONEncode(petition))
assert(sent, `[Éclat/Boot] the engine refused the petition: {status}`)
print(`[Éclat/Boot] sent {#ids} ids to éclat.`)

if seed then
	link.onData(seed)
end
finished.Event:Wait()
link:Destroy()
print("[Éclat/Boot] all ids carried home.")
