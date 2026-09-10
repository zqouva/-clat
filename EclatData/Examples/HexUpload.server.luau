--!strict


local ServerStorage = game:GetService("ServerStorage")

local Root = ServerStorage:WaitForChild("Packages"):WaitForChild("Eclat") :: ModuleScript
local Core = Root:WaitForChild("Core")
local Uplink = require(Core:WaitForChild("Uplink") :: ModuleScript)

--> [`sample`]
local SAMPLE_BYTES = buffer.fromstring("eclat-sample-payload")

local link = Uplink.connect()
assert(link, "[Éclat/HexUpload] no engine found. start eclat first.")

local ok, answer = Uplink.uploadBinary(link, "Mesh", "eclat-direct-mesh", SAMPLE_BYTES, "streamed by eclat")
assert(ok, "[Éclat/HexUpload] engine refused the bytes.")

print(`[Éclat/HexUpload] uploaded as asset {answer.assetId} ({answer.name})`)
link:Destroy()
