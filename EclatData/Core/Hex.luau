--!strict

-->
-->	["hex"]
-->	the studio uplink speaks in hex verses; this is the translator.
-->	string → hex · buffer → hex · measured, chunked, frozen.

local Hex = {}

local CHUNK = 0x1000

function Hex.fromString(value: string): string
	if #value == 0 then
		return ""
	end
	local parts = table.create(math.ceil(#value / CHUNK))
	for offset = 1, #value, CHUNK do
		local stop = math.min(offset + CHUNK - 1, #value)
		local piece = string.sub(value, offset, stop)
		parts[#parts + 1] = (string.gsub(piece, ".", function(char)
			return string.format("%02x", string.byte(char))
		end))
	end
	return table.concat(parts)
end

function Hex.fromBuffer(source: buffer): string
	return Hex.fromString(buffer.tostring(source))
end

function Hex.measure(rawBytes: number): number
	return rawBytes * 2
end

return table.freeze(Hex)
