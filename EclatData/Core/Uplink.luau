--!strict


local HttpService = game:GetService("HttpService")

local Connection = require(script.Parent.Connection)
local Hex = require(script.Parent.Hex)

local Uplink = {}

--> [`measures`]
Uplink.DEFAULT_PORT = 8080
Uplink.COMPAT_PORT = 38073
Uplink.PROTOCOL = "1.3.1"

export type ReuploadPetition = {
	placeId: number,
	creatorId: number,
	ids: { number },
	defaultPlaceIds: { number },
	pluginVersion: string,
	assetType: string,
	exportJson: boolean,
	isGroup: boolean,
}

export type StreamAnswer = {
	assetId: number,
	assetType: string,
	name: string,
}

--> [`connect`]
function Uplink.connect(port: number?): (any, string?, number?)
	local first = port or Uplink.DEFAULT_PORT
	local link, seed = Connection.new(first)
	if link then
		return link, seed, first
	end
	if port == nil then
		local fallback, fallbackSeed = Connection.new(Uplink.COMPAT_PORT)
		if fallback then
			return fallback, fallbackSeed, Uplink.COMPAT_PORT
		end
	end
	return nil, nil, nil
end

--> [`reupload`]
function Uplink.reupload(link, petition: ReuploadPetition): (boolean, string)
	return link:Send("/reupload", HttpService:JSONEncode(petition))
end

--> [`stream`]
function Uplink.uploadBinary(link, assetType: string, name: string, raw: string | buffer, description: string?, groupId: number?): (boolean, StreamAnswer?)
	local hexed: string
	if typeof(raw) == "buffer" then
		hexed = Hex.fromBuffer(raw :: buffer)
	else
		hexed = Hex.fromString(raw :: string)
	end
	local payload = HttpService:JSONEncode({
		assetType = assetType,
		name = name,
		description = description or "",
		groupId = groupId,
		hex = hexed,
		encoding = "hex",
	})
	hexed = ""

	local sent, response = link:Send("/upload", payload)
	if not sent then
		return false, nil
	end
	local decoded, answer = pcall(HttpService.JSONDecode, HttpService, response)
	if not decoded then
		return false, nil
	end
	return true, answer :: StreamAnswer
end

--> [`health`]
function Uplink.health(port: number): (boolean, any)
	local ok, response = pcall(HttpService.GetAsync, HttpService, `http://127.0.0.1:{port}/health`)
	if not ok then
		return false, nil
	end
	local decoded, answer = pcall(HttpService.JSONDecode, HttpService, response)
	if not decoded then
		return false, nil
	end
	return true, answer
end

--> [`status`]
function Uplink.status(port: number): (boolean, any)
	local ok, response = pcall(HttpService.GetAsync, HttpService, `http://127.0.0.1:{port}/status`)
	if not ok then
		return false, nil
	end
	local decoded, answer = pcall(HttpService.JSONDecode, HttpService, response)
	if not decoded then
		return false, nil
	end
	return true, answer
end

return table.freeze(Uplink)
