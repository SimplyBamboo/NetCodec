--!strict

local Utility = script.Parent.Parent:WaitForChild("Utility")
local TypeValidation = Utility:WaitForChild("TypeValidation")

local validateCFrame = require(TypeValidation:WaitForChild("validateCFrame"))
-- local validateInstance = require(TypeValidation:WaitForChild("validateInstance"))
local validateNumber = require(TypeValidation:WaitForChild("validateNumber"))
local validateSimpleTable = require(TypeValidation:WaitForChild("validateSimpleTable"))
local validateString = require(TypeValidation:WaitForChild("validateString"))
local validateVector3 = require(TypeValidation:WaitForChild("validateVector3"))

local Validator = {}

local validateInternal

function Validator.Validate(data: any): boolean

	return validateInternal(data)
end


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
		local isArrayCandidate = true
		local count = 0
		for k, _ in pairs(data) do
			if typeof(k) ~= "number" or k < 1 or math.floor(k) ~= k then
				isArrayCandidate = false
				break -- Found a non-positive-integer key, cannot be a simple array
			end
			count += 1
		end
		if isArrayCandidate and count == #data then
			for i = 1, count do
				if not validateInternal(data[i]) then
					return false
				end
			end
			return true
		else
			-- (must have only string keys)
			for key, value in pairs(data) do
				if typeof(key) ~= "string" then
					warn("NetCodec Validation: Map keys must be strings. Found:", typeof(key))
					return false
				end
				-- Key is valid (string), now validate the value recursively
				if not validateInternal(value) then
					return false
				end
			end
			return true
		end
	else
		warn("NetCodec Validation: Unsupported data type:", dataType)
		return false
	end
end


return Validator
