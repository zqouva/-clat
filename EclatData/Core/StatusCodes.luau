--!strict


local StatusCodes: { [string]: string } = {
	["HTTP 400 (Bad Request)"] = "Bad request.",
	["HTTP 401 (Unauthorized)"] = "The cookie was refused. Import a fresh one.",
	["HTTP 404 (Not Found)"] = "Unknown assetType.",
	["HTTP 409 (Conflict)"] = "Incompatible versions. Update your plugin or engine.",
	["HTTP 413 (Content Too Large)"] = "Payload over 64 MiB.",
	["HTTP 422 (Unprocessable Entity)"] = "Payload unreadable.",
	["HTTP 429 (Too Many Requests)"] = "Rate limited. Eclat is backing off.",
	["HTTP 500 (Internal Server Error)"] = "Engine error.",
	["HTTP 502 (Bad Gateway)"] = "Roblox refused the upload (see the engine terminal).",
	["HTTP 503 (Service Unavailable)"] = "The engine is busy with another reupload.",
}

return table.freeze(StatusCodes)
