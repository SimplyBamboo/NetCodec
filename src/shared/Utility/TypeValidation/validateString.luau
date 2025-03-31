--[[
	validateString - Ensures that the passed argument is actually a string
--]]

local function validateString(str: string): boolean
	return typeof(str) == "string"
end

return validateString
