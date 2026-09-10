--!strict


local ServerStorage = game:GetService("ServerStorage")

local Root = ServerStorage:WaitForChild("Packages"):WaitForChild("Eclat") :: ModuleScript
local Core = Root:WaitForChild("Core")
local Hex = require(Core:WaitForChild("Hex") :: ModuleScript)

assert(Hex.fromString("") == "", "[Éclat/Hex] empty stays empty")
assert(Hex.fromString("A") == "41", "[Éclat/Hex] A gives 41")
assert(Hex.fromString("Éclat") == "c389636c6174", "[Éclat/Hex] name survives")
assert(Hex.measure(3) == 6, "[Éclat/Hex] measure doubles")
assert(Hex.fromBuffer(buffer.fromstring("hi")) == "6869", "[Éclat/Hex] buffers work")

local long = string.rep("abcdef", 1000)
local hexed = Hex.fromString(long)
assert(#hexed == #long * 2, "[Éclat/Hex] long strings double exactly")
assert(string.sub(hexed, 1, 12) == "616263646566", "[Éclat/Hex] long strings start right")

print("[Éclat/Hex] all checks pass.")
