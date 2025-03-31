--!strict
-- Internal constants used by NetCodec

local Constants = {}

Constants.TypeIds = {
	NIL = 0,
	BOOLEAN_FALSE = 1,
	BOOLEAN_TRUE = 2,
	NUMBER = 3,
	STRING = 4,
	VECTOR3 = 5,
	CFRAME = 6,
	TABLE_ARRAY = 7,
	TABLE_MAP = 8,
}

return Constants
