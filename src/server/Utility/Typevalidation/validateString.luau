--[[
	validateString - Ensures that the passed argument is actually a string
--]]

local function validateString(string: string): boolean
	return typeof(string) == "string"
end

return validateString
