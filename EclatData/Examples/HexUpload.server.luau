--!strict

-->
-->	["hexupload"]
-->	the direct verse: stream one raw payload to the engine as hex,
-->	without the gather → petition → replace dance.
-->	swap SAMPLE_BYTES for true mesh / animation / audio bytes
-->	(read from your own assets, your own files, your own soul).

local ServerStorage = game:GetService("ServerStorage")

local Eclat = require(ServerStorage.Packages.Eclat)

--> ["offering"]
--> placeholder bytes. the engine will carry them; roblox will judge them.
--> bring true binary for a true asset.
local SAMPLE_BYTES = buffer.fromstring("eclat-sample-payload")

local link = Eclat.connect()
assert(link, "[Éclat/HexUpload] no engine on the wire. did you start éclat?")

local carried, answer = Eclat.stream(link, "Mesh", "eclat-direct-mesh", SAMPLE_BYTES, "streamed by éclat")
assert(carried, "[Éclat/HexUpload] the engine would not take the offering.")

print(`[Éclat/HexUpload] carried home as asset {answer.assetId} ({answer.name})`)
link:Destroy()
