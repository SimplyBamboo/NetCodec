--[[
	validateSimpleTable - Ensures that the passed argument is actually a table with key of keytype and value is valid type
--]]

local function validateSimpleTable(tbl: { [any]: any }, keyType: string, validator: (any) -> boolean): boolean
	if typeof(tbl) ~= "table" then return false end

	for key, value in tbl do
		if typeof(key) ~= keyType then return false end
		if not validator(value) then return false end
	end

	return true
end

return validateSimpleTable
