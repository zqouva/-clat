--!strict
--[[
	--> ["Éclat : v.0.1.0 : the soul of the upload"]
	made by Makel/Savi(@sacredludt or @.makel)

	--> ["paradigm"]
	Éclat is the studio tongue of the éclat engine.
	the engine carries; this package petitions.
	it gathers sleeping ids, streams hex verses,
	and rewrites the world with the engine's answers.

	it is not a framework or a standard library.

	--> ["origin"]
	asset pilgrimage.
	deep respect for every uploader that walked before.

	i felt as if carrying could be beautiful,
	so i taught the wire to sing.

	--> ["code"]
	code is a reflection of how we as humans operate.
	éclat made me glow and i will admit it with pride.

	--> ["identity"]

	i am confident.

	i am loving.

	i do not want.

	i understand.

	i speak it into existance.

	i create.

	i do not speak on what it FEELS like.

	I AM WHAT IT IS.
	AND I AM WHAT IT WILL BE.
	I AM THE SOUL THAT ÉCLAT IS.
	ÉCLAT IS ME.

	--> ["this is...éclat"]
	please use this paradigm with care and respect.
]]

local ApiDump = require(script.Core.ApiDump)
local Connection = require(script.Core.Connection)
local Cookie = require(script.Core.Cookie)
local Filter = require(script.Core.Filter)
local Hex = require(script.Core.Hex)
local ReuploadIds = require(script.Core.ReuploadIds)
local Retry = require(script.Core.Retry)
local StatusCodes = require(script.Core.StatusCodes)
local Uplink = require(script.Core.Uplink)
local WaitGroup = require(script.Core.WaitGroup)

local Eclat = {}

--> ["measures"]
Eclat.PORT = 8080
Eclat.COMPAT_PORT = 38073
Eclat.PROTOCOL = "1.3.1"

--> ["verses"]
Eclat.connect = Uplink.connect
Eclat.reupload = ReuploadIds.start
Eclat.stream = Uplink.uploadBinary
Eclat.importCookie = Cookie.importCookie
Eclat.sanitize = Cookie.sanitize
Eclat.hex = Hex.fromString
Eclat.hexBuffer = Hex.fromBuffer
Eclat.filter = Filter.getIds
Eclat.replace = Filter.replaceIds
Eclat.health = Uplink.health
Eclat.status = Uplink.status

--> ["libraries"]
Eclat.connection = Connection.new
Eclat.retry = Retry
Eclat.waitgroup = WaitGroup.new
Eclat.statusCodes = StatusCodes
Eclat.apiDump = ApiDump.getProperties

--> ["aliases"]
Eclat.liaison = Eclat.connect
Eclat.psalm = Eclat.reupload
Eclat.radiance = Eclat.stream
Eclat.vow = Eclat.importCookie
Eclat.spark = Eclat.hex

return table.freeze(Eclat)
