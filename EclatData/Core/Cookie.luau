--!strict


local HttpService = game:GetService("HttpService")

local Cookie = {}

export type CookieUser = {
	id: number,
	name: string,
	displayName: string,
}

local PREFIXES = {
	".ROBLOSECURITY=",
	".ROBLOSECURITY:",
	".ROBLOSECURITY ",
	"ROBLOSECURITY=",
	"Cookie:",
	"cookie:",
	"Cookie=",
	"cookie=",
}

local function trimmed(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or ""
end

function Cookie.sanitize(raw: string): string
	local out = trimmed(raw)

	--> [`unquote`]
	if #out >= 2 then
		local first = string.sub(out, 1, 1)
		local last = string.sub(out, -1)
		if (first == '"' and last == '"') or (first == "'" and last == "'") then
			out = trimmed(string.sub(out, 2, -2))
		end
	end

	--> [`unprefix`]
	while true do
		local cut = false
		for _, prefix in PREFIXES do
			if string.sub(out, 1, #prefix) == prefix then
				out = trimmed(string.sub(out, #prefix + 1))
				cut = true
				break
			end
		end
		if not cut then
			break
		end
	end

	--> [`unwrap pairs`]
	local equals = string.find(out, "=", 1, true)
	if equals ~= nil then
		local lowered = string.lower(trimmed(string.sub(out, 1, equals - 1)))
		if lowered == ".robloxsecurity" or lowered == "cookie" then
			out = trimmed(string.sub(out, equals + 1))
		end
	end

	return out
end

--> [`import`]
function Cookie.importCookie(port: number, rawCookie: string): (boolean, CookieUser?)
	local clean = Cookie.sanitize(rawCookie)
	if #clean == 0 then
		return false, nil
	end
	local payload = HttpService:JSONEncode({ cookie = clean })
	clean = ""

	local sent, response = pcall(function()
		return HttpService:PostAsync(`http://127.0.0.1:{port}/cookie`, payload, Enum.HttpContentType.ApplicationJson)
	end)
	if not sent then
		return false, nil
	end
	local decoded, user = pcall(HttpService.JSONDecode, HttpService, response)
	if not decoded then
		return false, nil
	end
	return true, user :: CookieUser
end

return table.freeze(Cookie)
