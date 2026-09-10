--!strict


local ServerStorage = game:GetService("ServerStorage")

local Root = ServerStorage:WaitForChild("Packages"):WaitForChild("Eclat") :: ModuleScript
local Core = Root:WaitForChild("Core")
local Cookie = require(Core:WaitForChild("Cookie") :: ModuleScript)
local Retry = require(Core:WaitForChild("Retry") :: ModuleScript)
local StatusCodes = require(Core:WaitForChild("StatusCodes") :: ModuleScript)
local WaitGroup = require(Core:WaitForChild("WaitGroup") :: ModuleScript)

--> [`retry`]
local tries = 0
local rose, fruit = Retry(3, function()
	tries += 1
	if tries < 3 then
		error("not yet")
	end
	return "up"
end)
assert(rose and fruit == "up" and tries == 3, "[Éclat/Uplink] retry passes on try 3")

local fell = Retry(2, function()
	error("always")
end)
assert(fell == false, "[Éclat/Uplink] retry gives up")

--> [`waitgroup`]
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

--> [`cookie`]
assert(Cookie.sanitize('  "abc123"  ') == "abc123", "[Éclat/Uplink] quotes stripped")
assert(Cookie.sanitize(".ROBLOSECURITY=tok") == "tok", "[Éclat/Uplink] prefixes stripped")
assert(Cookie.sanitize("Cookie: tok") == "tok", "[Éclat/Uplink] headers stripped")
assert(Cookie.sanitize("  tok  ") == "tok", "[Éclat/Uplink] spaces trimmed")
assert(Cookie.sanitize("") == "", "[Éclat/Uplink] empty stays empty")

--> [`codes`]
assert(StatusCodes["HTTP 503 (Service Unavailable)"] ~= nil, "[Éclat/Uplink] 503 mapped")
assert(StatusCodes["HTTP 401 (Unauthorized)"] ~= nil, "[Éclat/Uplink] 401 mapped")

print("[Éclat/Uplink] all checks pass.")
