--!strict

-->
-->	["statuscodes"]
-->	the engine's moods, translated for mortals.

local StatusCodes: { [string]: string } = {
	["HTTP 400 (Bad Request)"] = "The petition was malformed.",
	["HTTP 401 (Unauthorized)"] = "The cookie was refused. Import a fresh one.",
	["HTTP 404 (Not Found)"] = "Unknown assetType.",
	["HTTP 409 (Conflict)"] = "Incompatible versions. Update your plugin or engine.",
	["HTTP 413 (Content Too Large)"] = "The offering exceeded 64 MiB.",
	["HTTP 422 (Unprocessable Entity)"] = "The payload verse was unreadable.",
	["HTTP 429 (Too Many Requests)"] = "Roblox asked for quiet; eclat is already slowing.",
	["HTTP 500 (Internal Server Error)"] = "Engine error.",
	["HTTP 502 (Bad Gateway)"] = "Roblox refused the offering (see the engine terminal).",
	["HTTP 503 (Service Unavailable)"] = "The engine is carrying another pilgrimage.",
}

return table.freeze(StatusCodes)
