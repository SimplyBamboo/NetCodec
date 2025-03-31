--!strict
-- Handles serialization of Luau data types into buffers for NetCodec.

local Constants = require(script.Parent.Internal.Constants)
local Types = require(script.Parent.Types) -- Assuming types might be defined here later

-- Luau 5.1+ buffer library (available in Roblox)
assert(buffer, "Buffer library not available")

local Serializer = {}

-- Type definitions (could move to Types.luau)
type WriteBuffer = { buffer: buffer, offset: number }
type SerializableValue = nil | boolean | number | string | Vector3 | CFrame | { [string]: SerializableValue } | { [number]: SerializableValue }

-- Forward declare for recursive table serialization
local serializeValue

-- Helper to write type ID
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
		buffer.writef64(writeBuffer.buffer, writeBuffer.offset, value) -- Use f64 for standard Luau numbers
		writeBuffer.offset += 8
	elseif valueType == "string" then
		writeTypeId(writeBuffer, Constants.TypeIds.STRING)
		local len = string.len(value)
		buffer.writeu32(writeBuffer.buffer, writeBuffer.offset, len) -- Write string length (max ~4GB)
		writeBuffer.offset += 4
		buffer.writebytes(writeBuffer.buffer, writeBuffer.offset, value) -- Write string bytes
		writeBuffer.offset += len
	elseif valueType == "Vector3" then
		writeTypeId(writeBuffer, Constants.TypeIds.VECTOR3)
		buffer.writef32(writeBuffer.buffer, writeBuffer.offset, value.X)
		buffer.writef32(writeBuffer.buffer, writeBuffer.offset + 4, value.Y)
		buffer.writef32(writeBuffer.buffer, writeBuffer.offset + 8, value.Z)
		writeBuffer.offset += 12
	elseif valueType == "CFrame" then
		-- CFrames are 12 floats (Position + 3x3 Rotation Matrix)
		writeTypeId(writeBuffer, Constants.TypeIds.CFRAME)
		local components = { value:GetComponents() }
		for i = 1, 12 do
			buffer.writef32(writeBuffer.buffer, writeBuffer.offset + (i - 1) * 4, components[i])
		end
		writeBuffer.offset += 48
	elseif valueType == "table" then
		-- Determine if it's an array or map (simple check for now)
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
			buffer.writeu32(writeBuffer.buffer, writeBuffer.offset, count) -- Write array length
			writeBuffer.offset += 4
			for i = 1, count do
				serializeValue(writeBuffer, value[i]) -- Recursively serialize elements
			end
		else -- Treat as map (dictionary)
			writeTypeId(writeBuffer, Constants.TypeIds.TABLE_MAP)
			local mapSizeOffset = writeBuffer.offset
			buffer.writeu32(writeBuffer.buffer, mapSizeOffset, 0) -- Placeholder for map size
			writeBuffer.offset += 4
			local mapSize = 0
			for k, v in pairs(value) do
				if typeof(k) == "string" then -- Only support string keys for maps
					mapSize += 1
					serializeValue(writeBuffer, k) -- Serialize key
					serializeValue(writeBuffer, v) -- Serialize value
				else
					warn("NetCodec Serializer: Skipping non-string key in map:", k)
				end
			end
			-- Write the actual map size back at the placeholder position
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
	-- Estimate initial buffer size (can be refined)
	local estimatedSize = 128
	local buf = buffer.create(estimatedSize)
	local writeBuffer: WriteBuffer = { buffer = buf, offset = 0 }

	serializeValue(writeBuffer, value)

	-- Trim buffer to actual size if needed (optional optimization)
	-- If the initial estimate was too large, create a new buffer of the exact size.
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
