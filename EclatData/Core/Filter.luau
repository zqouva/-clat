--!strict


local ApiDump = require(script.Parent.ApiDump)
local Retry = require(script.Parent.Retry)
local WaitGroup = require(script.Parent.WaitGroup)

local AssetService = game:GetService("AssetService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local Filter = {}

export type FilterOptions = {
	WhitelistedInstances: { string },
	Instances: { Instance },
}

export type IdPair = {
	oldId: number,
	newId: number,
}

local NUMBER_ONLY = "%d+"

--> [`gather`]
local function isValidId(id: number): boolean
	if id == 0 or id % 1 ~= 0 then
		return false
	end
	local width = math.floor(math.log10(math.abs(id))) + 1
	return width >= 7 and width <= 15
end

local function singleId(host: Instance, possible: any): { [number]: { Instance } }
	local id = tonumber(possible)
	if not id or not isValidId(id) then
		return {}
	end
	return { [id] = { host } }
end

local function stringIds(host: Instance, text: string): { [number]: { Instance } }
	local map: { [number]: { Instance } } = {}
	for found in string.gmatch(text, "%d+") do
		local id = tonumber(found)
		if id ~= nil and not map[id] and isValidId(id) then
			map[id] = { host }
		end
	end
	return map
end

local function getAnimationId(host: Animation): { [number]: { Instance } }
	return singleId(host, string.match(tostring(host.AnimationId), NUMBER_ONLY))
end

local function getSoundId(host: Sound): { [number]: { Instance } }
	return singleId(host, string.match(tostring(host.SoundId), NUMBER_ONLY))
end

local function getScriptIds(host: LuaSourceContainer): { [number]: { Instance } }
	return stringIds(host, host.Source)
end

local function getStringValueIds(host: StringValue): { [number]: { Instance } }
	return stringIds(host, host.Value)
end

local function getNumberValueId(host: NumberValue | IntValue): { [number]: { Instance } }
	return singleId(host, host.Value)
end

local function getCharacterMesh(host: CharacterMesh): { [number]: { Instance } }
	return singleId(host, string.match(tostring(host.MeshId), NUMBER_ONLY))
end

local function getMeshPartId(host: MeshPart): { [number]: { Instance } }
	return singleId(host, string.match(tostring(host.MeshId), NUMBER_ONLY))
end

local function getSpecialMeshId(host: SpecialMesh): { [number]: { Instance } }
	return singleId(host, string.match(tostring(host.MeshId), NUMBER_ONLY))
end

local getters: { [string]: (host: any) -> { [number]: { Instance } } } = {
	Animation = getAnimationId,
	Sound = getSoundId,
	NumberValue = getNumberValueId,
	IntValue = getNumberValueId,
	StringValue = getStringValueIds,
	CharacterMesh = getCharacterMesh,
	MeshPart = getMeshPartId,
	SpecialMesh = getSpecialMeshId,
}

local function merge(into: { [number]: { Instance } }, other: { [number]: { Instance } })
	for id, hosts in other do
		local bucket = into[id]
		if not bucket then
			into[id] = hosts
			continue
		end
		for _, host in hosts do
			if not table.find(bucket, host) then
				table.insert(bucket, host)
			end
		end
	end
end

function Filter.getIds(options: FilterOptions): { [number]: { Instance } }
	local map: { [number]: { Instance } } = {}
	local picks: { [string]: (host: any) -> { [number]: { Instance } } } = {}
	for _, className in options.WhitelistedInstances do
		if className == "LuaSourceContainer" then
			picks["LocalScript"] = getScriptIds
			picks["ModuleScript"] = getScriptIds
			picks["Script"] = getScriptIds
		else
			local getter = getters[className]
			if getter == nil then
				error(`[Éclat/Filter] {className} is not a supported instance`)
			end
			picks[className] = getter
		end
	end
	for _, host in options.Instances do
		local parse = picks[host.ClassName]
		if parse == nil then
			continue
		end
		merge(map, parse(host))
	end
	return map
end

function Filter.getIdArray(map: { [number]: { Instance } }): { number }
	local array: { number } = {}
	for id in map do
		array[#array + 1] = id
	end
	return array
end

--> [`rewrite`]
local function setScriptIds(host: LuaSourceContainer, pairs: { IdPair })
	local source = host.Source
	for _, pair in pairs do
		source = string.gsub(source, `%f[%d]{pair.oldId}%f[%D]`, tostring(pair.newId))
	end
	if #source > 200_000 then
		ScriptEditorService:UpdateSourceAsync(host, function()
			return source
		end)
	else
		host.Source = source
	end
end

local function setAnimationId(host: Animation, oldId: number, newId: number)
	host.AnimationId = string.gsub(host.AnimationId, tostring(oldId), tostring(newId))
end

local function setSoundId(host: Sound, oldId: number, newId: number)
	host.SoundId = string.gsub(host.SoundId, tostring(oldId), tostring(newId))
end

local function setNumberValueId(host: NumberValue | IntValue, _: number, newId: number)
	host.Value = newId
end

local function setStringValueIds(host: StringValue, oldId: number, newId: number)
	host.Value = string.gsub(host.Value, tostring(oldId), tostring(newId))
end

local function setCharacterMesh(host: CharacterMesh, _: number, newId: number)
	(host :: any).MeshId = `rbxassetid://{newId}`
end

local function setSpecialMeshId(host: SpecialMesh, oldId: number, newId: number)
	(host :: any).MeshId = string.gsub(tostring(host.MeshId), tostring(oldId), tostring(newId))
end

local setters: { [string]: (host: any, oldId: number, newId: number) -> () } = {
	Animation = setAnimationId,
	Sound = setSoundId,
	NumberValue = setNumberValueId,
	IntValue = setNumberValueId,
	StringValue = setStringValueIds,
	CharacterMesh = setCharacterMesh,
	SpecialMesh = setSpecialMeshId,
}

--> [`rebirth`]
local propertyCache: { [string]: { string } } = {}

local function transferProperties(oldHost: Instance, newHost: Instance)
	local className = oldHost.ClassName
	assert(className == newHost.ClassName, "[Éclat/Filter] kin must share a class")
	local cached = propertyCache[className]
	if cached == nil then
		cached = ApiDump.getProperties(className)
		propertyCache[className] = cached
	end
	for _, property in cached do
		if property == "Parent" or property == "Sandboxed" or property == "brickColor" then
			continue
		end
		pcall(function()
			(newHost :: any)[property] = (oldHost :: any)[property]
		end)
	end
end

local function transferAttributes(oldHost: Instance, newHost: Instance)
	for name, value in oldHost:GetAttributes() do
		newHost:SetAttribute(name, value)
	end
end

local function transferTags(oldHost: Instance, newHost: Instance)
	for _, tag in oldHost:GetTags() do
		newHost:AddTag(tag)
	end
end

local function transferChildren(oldHost: Instance, newHost: Instance)
	for _, child in oldHost:GetChildren() do
		if child:IsA("TouchTransmitter") then
			continue
		end
		child.Parent = newHost
	end
end

local function indexJoints(root: DataModel): { [Instance]: { JointInstance } }
	local index: { [Instance]: { JointInstance } } = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("JointInstance") then
			if descendant.Part0 ~= nil then
				local bucket = index[descendant.Part0]
				if bucket == nil then
					bucket = {}
					index[descendant.Part0] = bucket
				end
				table.insert(bucket, descendant)
			end
			if descendant.Part1 ~= nil then
				local bucket = index[descendant.Part1]
				if bucket == nil then
					bucket = {}
					index[descendant.Part1] = bucket
				end
				table.insert(bucket, descendant)
			end
		end
	end
	return index
end

local function rehomeJoints(oldHost: MeshPart, newHost: MeshPart, joints: { [Instance]: { JointInstance } })
	local bucket = joints[oldHost]
	if bucket == nil then
		return
	end
	for _, joint in bucket do
		if joint.Part0 == oldHost then
			joint.Part0 = newHost
		end
		if joint.Part1 == oldHost then
			joint.Part1 = newHost
		end
	end
end

local function setMeshPart(host: MeshPart, oldId: number, newId: number, joints: { [Instance]: { JointInstance } })
	local retrieved, content = Retry(3, Content.fromAssetId, newId)
	if not retrieved then
		warn(`[Éclat/Filter] content {newId} failed to load, meshpart {oldId} skipped`)
		return
	end
	local bornOk, born = pcall(function()
		return AssetService:CreateMeshPartAsync(content, {
			CollisionFidelity = host.CollisionFidelity,
			RenderFidelity = host.RenderFidelity,
			FluidFidelity = host.FluidFidelity,
		} :: any)
	end)
	if not bornOk then
		warn(`[Éclat/Filter] meshpart {oldId} failed: {born}`)
		return
	end
	local newHost = born :: MeshPart

	local moved, problem = pcall(function()
		transferProperties(host, newHost)
		transferAttributes(host, newHost)
		transferTags(host, newHost)
		transferChildren(host, newHost)
		rehomeJoints(host, newHost, joints)
	end)
	if not moved then
		newHost:Destroy()
		warn(`[Éclat/Filter] meshpart {oldId} copy failed: {problem}`)
		return
	end

	newHost.Parent = host.Parent
	host:Destroy()
end

function Filter.replaceIds(map: { [number]: { Instance } }, pairs: { IdPair })
	local scripts: { [LuaSourceContainer]: { IdPair } } = {}
	local meshparts: { { host: MeshPart, oldId: number, newId: number } } = {}

	for _, pair in pairs do
		local hosts = map[pair.oldId]
		if hosts == nil then
			continue
		end
		for _, host in hosts do
			if host:IsA("LuaSourceContainer") then
				local bucket = scripts[host]
				if bucket == nil then
					bucket = {}
					scripts[host] = bucket
				end
				table.insert(bucket, pair)
				continue
			end
			if host:IsA("MeshPart") then
				table.insert(meshparts, { host = host, oldId = pair.oldId, newId = pair.newId })
				continue
			end
			local set = setters[host.ClassName]
			if set == nil then
				warn(`[Éclat/Filter] {host.ClassName} has no setter, skipped`)
				continue
			end
			local applied = pcall(set, host, pair.oldId, pair.newId)
			if not applied then
				warn(`[Éclat/Filter] {host.ClassName} {pair.oldId} would not paste`)
			end
		end
	end

	for host, list in scripts do
		local pasted = pcall(setScriptIds, host, list)
		if not pasted then
			warn(`[Éclat/Filter] script {host:GetFullName()} would not paste`)
		end
	end

	if #meshparts > 0 then
		local joints = indexJoints(game)
		local group = WaitGroup.new()
		for _, task_ in meshparts do
			group:Add()
			task.spawn(function()
				setMeshPart(task_.host, task_.oldId, task_.newId, joints)
				group:Done()
			end)
		end
		group:Wait()
		group:Destroy()
	end
end

return table.freeze(Filter)
