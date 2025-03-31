--[[
	validateSimpleTable - Ensures that the passed argument is actually a table vith key of keytype and value is valid type and
--]]

local function validateSimpleTable(table: { [any]: any }, keyType: string, validator: (any) -> boolean): boolean
	if typeof(table) ~= "table" then return false end

	for key, value in table do
		if typeof(key) ~= keyType then return false end
		if not validator(value) then return false end
	end

	return true
end

return validateSimpleTable
