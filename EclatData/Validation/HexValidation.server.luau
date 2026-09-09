--!strict

-->
-->	["hexvalidation"]
-->	the hex translator, examined. run in studio; silence is success.

local ServerStorage = game:GetService("ServerStorage")

local Eclat = require(ServerStorage.Packages.Eclat)
local Hex = require(ServerStorage.Packages.Eclat.Core.Hex)

assert(Hex.fromString("") == "", "[Éclat/Hex] emptiness must stay empty")
assert(Hex.fromString("A") == "41", "[Éclat/Hex] A must speak 41")
assert(Hex.fromString("Éclat") == "c389636c6174", "[Éclat/Hex] the name must survive translation")
assert(Hex.measure(3) == 6, "[Éclat/Hex] measure must double")
assert(Hex.fromBuffer(buffer.fromstring("hi")) == "6869", "[Éclat/Hex] buffers must translate")

local long = string.rep("abcdef", 1000)
local hexed = Hex.fromString(long)
assert(#hexed == #long * 2, "[Éclat/Hex] long verses must double exactly")
assert(string.sub(hexed, 1, 12) == "616263646566", "[Éclat/Hex] long verses must open true")

assert(Eclat.spark("A") == "41", "[Éclat/Hex] the spark alias must sing")

print("[Éclat/Hex] all verses true.")
