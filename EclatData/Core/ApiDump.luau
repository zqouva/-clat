--!strict


local HttpService = game:GetService("HttpService")

local ApiDump = {}

ApiDump.DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"

local CURATED: { [string]: { string } } = {
	MeshPart = {
		"CFrame",
		"Size",
		"Color",
		"Material",
		"Transparency",
		"Anchored",
		"CanCollide",
		"CanQuery",
		"CanTouch",
		"CollisionFidelity",
		"RenderFidelity",
		"FluidFidelity",
		"CollisionGroup",
		"Massless",
		"RootPriority",
		"CustomPhysicalProperties",
		"MaterialVariant",
		"MeshSize",
		"Name",
		"Orientation",
		"Position",
		"Rotation",
		"Reflectance",
		"CastShadow",
		"DoubleSided",
		"AssemblyLinearVelocity",
		"AssemblyAngularVelocity",
	},
}

local cache: { [string]: { string } }? = nil

function ApiDump.isCached(): boolean
	return cache ~= nil
end

local function warm(): { [string]: { string } }
	local dump: { [string]: { string } } = {}
	local ok, body = pcall(HttpService.GetAsync, HttpService, ApiDump.DUMP_URL)
	if not ok then
		return dump
	end
	local decoded, parsed = pcall(HttpService.JSONDecode, HttpService, body)
	if not decoded then
		return dump
	end
	local classes = (parsed :: any).Classes
	if typeof(classes) ~= "table" then
		return dump
	end
	for _, class in classes do
		local members = (class :: any).Members
		if typeof(members) == "table" then
			local props: { string } = {}
			for _, member in members do
				local info = member :: any
				if info.MemberType == "Property" then
					table.insert(props, info.Name)
				end
			end
			dump[(class :: any).Name] = props
		end
	end
	return dump
end

function ApiDump.getProperties(className: string): { string }
	if cache == nil then
		cache = warm()
	end
	local known = (cache :: { [string]: { string } })[className]
	if known ~= nil and #known > 0 then
		return known
	end
	local curated = CURATED[className]
	if curated ~= nil then
		return curated
	end
	return {}
end

return table.freeze(ApiDump)
