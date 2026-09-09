--!strict

-->
-->	["uplinkvalidation"]
-->	the wire's small rites, examined without an engine.
-->	retry · waitgroup · cookie sanitize · status moods.

local ServerStorage = game:GetService("ServerStorage")

local Root = ServerStorage.Packages.Eclat
local Cookie = require(Root.Core.Cookie)
local Retry = require(Root.Core.Retry)
local StatusCodes = require(Root.Core.StatusCodes)
local WaitGroup = require(Root.Core.WaitGroup)

--> ["retry"]
local kneels = 0
local rose, fruit = Retry(3, function()
	kneels += 1
	if kneels < 3 then
		error("not yet")
	end
	return "risen"
end)
assert(rose and fruit == "risen" and kneels == 3, "[Éclat/Uplink] retry must rise on the third kneel")

local fell = Retry(2, function()
	error("always")
end)
assert(fell == false, "[Éclat/Uplink] retry must admit defeat")

--> ["waitgroup"]
local group = WaitGroup.new()
group:Add(2)
task.spawn(function()
	group:Done()
end)
task.spawn(function()
	group:Done()
end)
group:Wait()
group:Destroy()

--> ["cookie"]
assert(Cookie.sanitize('  "abc123"  ') == "abc123", "[Éclat/Uplink] quotes must fall")
assert(Cookie.sanitize(".ROBLOSECURITY=tok") == "tok", "[Éclat/Uplink] prefixes must fall")
assert(Cookie.sanitize("Cookie: tok") == "tok", "[Éclat/Uplink] headers must fall")
assert(Cookie.sanitize("  tok  ") == "tok", "[Éclat/Uplink] spaces must fall")
assert(Cookie.sanitize("") == "", "[Éclat/Uplink] emptiness must stay empty")

--> ["moods"]
assert(StatusCodes["HTTP 503 (Service Unavailable)"] ~= nil, "[Éclat/Uplink] 503 must have a mood")
assert(StatusCodes["HTTP 401 (Unauthorized)"] ~= nil, "[Éclat/Uplink] 401 must have a mood")

print("[Éclat/Uplink] all verses true.")
