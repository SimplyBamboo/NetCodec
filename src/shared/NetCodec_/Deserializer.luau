--!strict
-- Handles deserialization of buffers back into Luau data types for NetCodec.

local Constants = require(script.Parent.Internal.Constants)
local Types = require(script.Parent.Types) --defined here later

assert(buffer, "Buffer library not available")

local Deserializer = {}

type ReadBuffer = { buffer: buffer, offset: number, size: number }
type SerializableValue = nil | boolean | number | string | Vector3 | CFrame | { [string]: SerializableValue } | { [number]: SerializableValue }

local deserializeValue

local function readTypeId(readBuffer: ReadBuffer): number
	local typeId = buffer.readu8(readBuffer.buffer, readBuffer.offset)
	readBuffer.offset += 1
	return typeId
end

--[[
	Deserializes a single value from the buffer based on its type ID.
	Handles recursion for tables.
]]
function deserializeValue(readBuffer: ReadBuffer): SerializableValue
	if readBuffer.offset >= readBuffer.size then
		error("NetCodec Deserializer: Read past end of buffer", 2)
	end

	local typeId = readTypeId(readBuffer)

	if typeId == Constants.TypeIds.NIL then
		return nil
	elseif typeId == Constants.TypeIds.BOOLEAN_FALSE then
		return false
	elseif typeId == Constants.TypeIds.BOOLEAN_TRUE then
		return true
	elseif typeId == Constants.TypeIds.NUMBER then
		local value = buffer.readf64(readBuffer.buffer, readBuffer.offset)
		readBuffer.offset += 8
		return value
	elseif typeId == Constants.TypeIds.STRING then
		local len = buffer.readu32(readBuffer.buffer, readBuffer.offset)
		readBuffer.offset += 4
		local value = buffer.readbytes(readBuffer.buffer, readBuffer.offset, len)
		readBuffer.offset += len
		return value
	elseif typeId == Constants.TypeIds.VECTOR3 then
		local x = buffer.readf32(readBuffer.buffer, readBuffer.offset)
		local y = buffer.readf32(readBuffer.buffer, readBuffer.offset + 4)
		local z = buffer.readf32(readBuffer.buffer, readBuffer.offset + 8)
		readBuffer.offset += 12
		return Vector3.new(x, y, z)
	elseif typeId == Constants.TypeIds.CFRAME then
		local components = table.create(12)
		for i = 1, 12 do
			components[i] = buffer.readf32(readBuffer.buffer, readBuffer.offset + (i - 1) * 4)
		end
		readBuffer.offset += 48
		return CFrame.new(unpack(components))
	elseif typeId == Constants.TypeIds.TABLE_ARRAY then
		local count = buffer.readu32(readBuffer.buffer, readBuffer.offset)
		readBuffer.offset += 4
		local array = table.create(count)
		for i = 1, count do
			array[i] = deserializeValue(readBuffer)
		end
		return array
	elseif typeId == Constants.TypeIds.TABLE_MAP then
		local mapSize = buffer.readu32(readBuffer.buffer, readBuffer.offset)
		readBuffer.offset += 4
		local map = {}
		for _ = 1, mapSize do
			local key = deserializeValue(readBuffer)
			local value = deserializeValue(readBuffer)
			if typeof(key) == "string" then
				map[key] = value
			else
				warn("NetCodec Deserializer: Skipping non-string key found in map data:", key)
			end
		end
		return map
	else
		error(("NetCodec Deserializer: Encountered unknown type ID '%d'"):format(typeId), 2)
	end
end

--[[
	Main entry point for deserialization.
	Takes a buffer and returns the deserialized Luau value.
]]
function Deserializer.Deserialize(buf: buffer): SerializableValue
	local readBuffer: ReadBuffer = { buffer = buf, offset = 0, size = buffer.len(buf) }

	local value = deserializeValue(readBuffer)

	-- Optional: Check if the entire buffer was consumed
	if readBuffer.offset ~= readBuffer.size then
		warn("NetCodec Deserializer: Did not consume entire buffer. Bytes remaining:", readBuffer.size - readBuffer.offset)
	end

	return value
end

return Deserializer
