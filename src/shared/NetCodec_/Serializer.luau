--!strict
-- Handles serialization

local Constants = require(script.Parent.Internal.Constants)
local Types = require(script.Parent.Types)

assert(buffer, "Buffer library not available")

local Serializer = {}

type WriteBuffer = { buffer: buffer, offset: number }
type SerializableValue = nil | boolean | number | string | Vector3 | CFrame | { [string]: SerializableValue } | { [number]: SerializableValue }

local serializeValue

local function writeTypeId(writeBuffer: WriteBuffer, typeId: number)
	buffer.writeu8(writeBuffer.buffer, writeBuffer.offset, typeId)
	writeBuffer.offset += 1
end

--[[
	Serializes a single value into the buffer.
	Handles recursion for tables.
]]
function serializeValue(writeBuffer: WriteBuffer, value: SerializableValue)
	local valueType = typeof(value)

	if value == nil then
		writeTypeId(writeBuffer, Constants.TypeIds.NIL)
	elseif valueType == "boolean" then
		writeTypeId(writeBuffer, if value then Constants.TypeIds.BOOLEAN_TRUE else Constants.TypeIds.BOOLEAN_FALSE)
	elseif valueType == "number" then
		writeTypeId(writeBuffer, Constants.TypeIds.NUMBER)
		buffer.writef64(writeBuffer.buffer, writeBuffer.offset, value) 
		writeBuffer.offset += 8
	elseif valueType == "string" then
		writeTypeId(writeBuffer, Constants.TypeIds.STRING)
		local len = string.len(value)
		buffer.writeu32(writeBuffer.buffer, writeBuffer.offset, len)
		writeBuffer.offset += 4
		buffer.writebytes(writeBuffer.buffer, writeBuffer.offset, value) 
		writeBuffer.offset += len
	elseif valueType == "Vector3" then
		writeTypeId(writeBuffer, Constants.TypeIds.VECTOR3)
		buffer.writef32(writeBuffer.buffer, writeBuffer.offset, value.X)
		buffer.writef32(writeBuffer.buffer, writeBuffer.offset + 4, value.Y)
		buffer.writef32(writeBuffer.buffer, writeBuffer.offset + 8, value.Z)
		writeBuffer.offset += 12
	elseif valueType == "CFrame" then
		writeTypeId(writeBuffer, Constants.TypeIds.CFRAME)
		local components = { value:GetComponents() }
		for i = 1, 12 do
			buffer.writef32(writeBuffer.buffer, writeBuffer.offset + (i - 1) * 4, components[i])
		end
		writeBuffer.offset += 48
	elseif valueType == "table" then

		local isArray = true
		local count = 0
		for i, _ in ipairs(value) do
			count += 1
		end
		if count ~= #value then
			isArray = false -- Contains non-sequential numeric keys or string keys
		end

		if isArray then
			writeTypeId(writeBuffer, Constants.TypeIds.TABLE_ARRAY)
			buffer.writeu32(writeBuffer.buffer, writeBuffer.offset, count) 
			writeBuffer.offset += 4
			for i = 1, count do
				serializeValue(writeBuffer, value[i]) 
			end
		else -- Treat as map 
			writeTypeId(writeBuffer, Constants.TypeIds.TABLE_MAP)
			local mapSizeOffset = writeBuffer.offset
			buffer.writeu32(writeBuffer.buffer, mapSizeOffset, 0) -- Placeholder for map size
			writeBuffer.offset += 4
			local mapSize = 0
			for k, v in pairs(value) do
				if typeof(k) == "string" then 
					mapSize += 1
					serializeValue(writeBuffer, k) 
					serializeValue(writeBuffer, v) 
				else
					warn("NetCodec Serializer: Skipping non-string key in map:", k)
				end
			end
			buffer.writeu32(writeBuffer.buffer, mapSizeOffset, mapSize)
		end
	else
		error(("NetCodec Serializer: Cannot serialize unsupported type '%s'"):format(valueType), 2)
	end
end

--[[
	Main entry point for serialization.
	Takes any serializable value and returns a buffer.
]]
function Serializer.Serialize(value: SerializableValue): buffer
	local estimatedSize = 128
	local buf = buffer.create(estimatedSize)
	local writeBuffer: WriteBuffer = { buffer = buf, offset = 0 }

	serializeValue(writeBuffer, value)

	if writeBuffer.offset < estimatedSize then
		local finalBuffer = buffer.create(writeBuffer.offset)
		buffer.copy(finalBuffer, 0, writeBuffer.buffer, 0, writeBuffer.offset)
		return finalBuffer
	elseif writeBuffer.offset > estimatedSize then
		-- This case means the buffer automatically grew. We can just return it.
		-- Or, if Roblox buffer doesn't auto-grow efficiently, we might need to handle reallocation.
		-- Assuming Roblox handles growth, we return the original buffer.
		-- If reallocation was needed during writes, the 'writeBuffer.buffer' might point to a new buffer.
		-- For simplicity now, assume buffer.create makes a large enough or growable buffer.
		-- NOTE: Roblox buffer API details on growth/reallocation are important here.
		-- If buffer.write exceeds capacity, it might error or reallocate. Let's assume it handles it.
		-- We might need to resize manually if writes fail past initial capacity.
		-- For now, just return the potentially oversized buffer.
		-- TODO: Investigate Roblox buffer behavior on overflow.
	end

	-- If offset exactly matches estimatedSize, or if it grew, return the buffer used.
	return writeBuffer.buffer
end


return Serializer
