--[[
	validateNumber - Ensures that the passed argument is actually a number
--]]


local function validateNumber(number: number): boolean
	if typeof(number) ~= "number" then return false end
	if number ~= number then return false end -- NaN check
	return true
end

return validateNumber
