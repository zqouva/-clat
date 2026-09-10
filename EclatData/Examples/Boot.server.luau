--!strict


local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Root = ServerStorage:WaitForChild("Packages"):WaitForChild("Eclat") :: ModuleScript
local Core = Root:WaitForChild("Core")
local FilterLib = require(Core:WaitForChild("Filter") :: ModuleScript)
local Uplink = require(Core:WaitForChild("Uplink") :: ModuleScript)

assert(game.PlaceId ~= 0, "[Éclat/Boot] publish the place first, then restart it.")

--> [`gather`]
local found = FilterLib.getIds({
	WhitelistedInstances = { "Animation" },
	Instances = game:GetDescendants(),
})
local ids = FilterLib.getIdArray(found)
assert(#ids > 0, "[Éclat/Boot] no animation ids found.")

--> [`send`]
local link, seed = Uplink.connect()
assert(link, "[Éclat/Boot] no engine found. start eclat first.")

local finished = Instance.new("BindableEvent")
link.onData = function(data: string)
	local text = string.gsub(data, "%s+$", "")
	if text == "done" then
		finished:Fire()
		return
	end
	if text == "" then
		return
	end
	local ok, pairs = pcall(HttpService.JSONDecode, HttpService, text)
	if ok and typeof(pairs) == "table" and #pairs > 0 then
		FilterLib.replaceIds(found, pairs)
		warn(`[Éclat/Boot] replaced {#pairs} ids`)
	end
end
link.onDisconnect = function()
	warn("[Éclat/Boot] engine disconnected.")
	finished:Fire()
end

local petition = {
	placeId = game.PlaceId,
	creatorId = game.CreatorId,
	ids = ids,
	defaultPlaceIds = {},
	pluginVersion = Uplink.PROTOCOL,
	assetType = "Animation",
	exportJson = true,
	isGroup = game.CreatorType == Enum.CreatorType.Group,
}
local sent, status = link:Send("/reupload", HttpService:JSONEncode(petition))
assert(sent, `[Éclat/Boot] engine refused: {status}`)
print(`[Éclat/Boot] sent {#ids} ids.`)

if seed then
	link.onData(seed)
end
finished.Event:Wait()
link:Destroy()
print("[Éclat/Boot] done.")
