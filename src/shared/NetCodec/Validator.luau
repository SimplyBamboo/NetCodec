--!strict
-- Handles data validation for NetCodec before serialization and after deserialization.

local Utility = script.Parent.Parent:WaitForChild("Utility")
local TypeValidation = Utility:WaitForChild("TypeValidation")

local validateCFrame = require(TypeValidation:WaitForChild("validateCFrame"))
-- local validateInstance = require(TypeValidation:WaitForChild("validateInstance")) -- Not needed for initial types
local validateNumber = require(TypeValidation:WaitForChild("validateNumber"))
local validateSimpleTable = require(TypeValidation:WaitForChild("validateSimpleTable"))
local validateString = require(TypeValidation:WaitForChild("validateString"))
local validateVector3 = require(TypeValidation:WaitForChild("validateVector3"))

local Validator = {}

-- Forward declare for recursion
local validateInternal

-- Main validation function exposed
function Validator.Validate(data: any): boolean
	-- We use a separate internal function to handle recursion depth if needed later
	return validateInternal(data)
end

-- Internal recursive validation function
function validateInternal(data: any): boolean
	local dataType = typeof(data)

	if dataType == "nil" then
		return true
	elseif dataType == "boolean" then
		return true
	elseif dataType == "number" then
		return validateNumber(data)
	elseif dataType == "string" then
		return validateString(data)
	elseif dataType == "Vector3" then
		return validateVector3(data)
	elseif dataType == "CFrame" then
		return validateCFrame(data)
	elseif dataType == "table" then
		-- Check if it's potentially an array (sequential integer keys starting from 1)
		local isArrayCandidate = true
		local count = 0
		for k, _ in pairs(data) do
			if typeof(k) ~= "number" or k < 1 or math.floor(k) ~= k then
				isArrayCandidate = false
				break -- Found a non-positive-integer key, cannot be a simple array
			end
			count += 1
		end

		-- If it looks like an array, verify sequential keys up to #data
		if isArrayCandidate and count == #data then
			-- Validate as array
			for i = 1, count do
				if not validateInternal(data[i]) then
					-- warn("NetCodec Validation: Invalid value found in array at index", i)
					return false
				end
			end
			return true
		else
			-- Validate as map (must have only string keys)
			for key, value in pairs(data) do
				if typeof(key) ~= "string" then
					warn("NetCodec Validation: Map keys must be strings. Found:", typeof(key))
					return false
				end
				-- Key is valid (string), now validate the value recursively
				if not validateInternal(value) then
					-- warn("NetCodec Validation: Invalid value found in map for key", key)
					return false
				end
			end
			return true
		end
	else
		-- Unsupported type for NetCodec serialization
		warn("NetCodec Validation: Unsupported data type:", dataType)
		return false
	end
end


return Validator
