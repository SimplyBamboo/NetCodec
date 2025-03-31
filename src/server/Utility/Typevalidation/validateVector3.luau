--[[
	validateVector3 - Ensures that the passed argument is actually a Vector3
--]]

local function validateVector3(vector3: Vector3): boolean
	if typeof(vector3) ~= "Vector3" then return false end
	if vector3 ~= vector3 then return false end
	return true
end

return validateVector3
