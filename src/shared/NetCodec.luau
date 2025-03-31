--!strict
-- NetCodec: High-performance, buffer-based networking library for Roblox Luau.
-- Simplifies networking by handling serialization, deserialization, and type validation.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Serializer = require(script.Parent.NetCodec_.Serializer)
local Deserializer = require(script.Parent.NetCodec_.Deserializer)
local Validator = require(script.Parent.NetCodec_.Validator)
local Types = require(script.Parent.NetCodec_.Types)
local Constants = require(script.Parent.NetCodec_.Internal.Constants)
--[[
	TODO: Define shared types in Types.luau
	type SerializableValue = Types.SerializableValue
	type RemoteCallback = (...any) -> (...any) -- For RemoteFunctions
	type EventCallback = (...any) -> () -- For RemoteEvents
]]

local NetCodec = {}
NetCodec.Remotes = {} 

local isServer = RunService:IsServer()
local remoteEventContainer: Folder
local remoteFunctionContainer: Folder

--[[!
	Initializes the NetCodec library. This function must be called once on the server
	and once on the client before any other NetCodec functions are used.

	On the server, it creates dedicated folders (`NetCodecEvents`, `NetCodecFunctions`)
	in `ReplicatedStorage` to hold the underlying `RemoteEvent` and `RemoteFunction` instances.

	On the client, it waits for these folders to be created by the server.

	@error Throws an error if called multiple times or if the client cannot find the server-created folders within the timeout period (60 seconds).
]]
function NetCodec.Start()
	if NetCodec._started then
		error("NetCodec.Start() should only be called once per environment (server/client).", 2)
	end

	if isServer then
		remoteEventContainer = Instance.new("Folder")
		remoteEventContainer.Name = "NetCodecEvents"
		remoteEventContainer.Parent = ReplicatedStorage

		remoteFunctionContainer = Instance.new("Folder")
		remoteFunctionContainer.Name = "NetCodecFunctions"
		remoteFunctionContainer.Parent = ReplicatedStorage
		print("NetCodec Server Started")
	else
		remoteEventContainer = ReplicatedStorage:WaitForChild("NetCodecEvents", 60) :: Folder
		remoteFunctionContainer = ReplicatedStorage:WaitForChild("NetCodecFunctions", 60) :: Folder
		if not remoteEventContainer or not remoteFunctionContainer then
			error("NetCodec Client: Failed to find remote containers created by server.", 0)
	end
	print("NetCodec Client Started")
	end
	NetCodec._started = true
end
NetCodec._started = false


local function getRemoteEvent(name: string): RemoteEvent
	local existing = remoteEventContainer:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	elseif isServer then
		local newEvent = Instance.new("RemoteEvent")
		newEvent.Name = name
		newEvent.Parent = remoteEventContainer
		return newEvent
	else
		local foundEvent = remoteEventContainer:WaitForChild(name, 10)
		if foundEvent and foundEvent:IsA("RemoteEvent") then
			return foundEvent
		else
			error(("NetCodec Client: Failed to find RemoteEvent '%s'"):format(name), 0)
		end
	end
end


local function getRemoteFunction(name: string): RemoteFunction
	local existing = remoteFunctionContainer:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	elseif isServer then
		local newFunc = Instance.new("RemoteFunction")
		newFunc.Name = name
		newFunc.Parent = remoteFunctionContainer
		return newFunc
	else
		local foundFunc = remoteFunctionContainer:WaitForChild(name, 10)
		if foundFunc and foundFunc:IsA("RemoteFunction") then
			return foundFunc
		else
			error(("NetCodec Client: Failed to find RemoteFunction '%s'"):format(name), 0)
		end
	end
end

--[[!
	Defines and retrieves a wrapper for a `RemoteEvent` used for one-way communication
	between the server and client(s).

	If an event with the same name has already been defined, the existing definition is returned.
	This ensures that both server and client scripts can define the same event without conflicts.

	The underlying `RemoteEvent` instance is automatically created in the appropriate
	`ReplicatedStorage` folder if it doesn't exist (server-side) or waited for (client-side).

	@param name string The unique identifier for this remote event. Must be consistent across server and client.
	@returns table A table containing methods specific to this event:
		- `:FireServer(...args: SerializableValue)` (Client only) Sends data to the server.
		- `:FireClient(player: Player, ...args: SerializableValue)` (Server only) Sends data to a specific client.
		- `:FireAllClients(...args: SerializableValue)` (Server only) Sends data to all connected clients.
		- `:FireAllClientsExcept(exclude: Player | {Player}, ...args: SerializableValue)` (Server only) Sends data to all clients except the specified one(s).
		- `:ConnectServer(callback: (player: Player, ...args: SerializableValue) -> ())` (Server only) Registers a function to handle data received from clients.
		- `:ConnectClient(callback: (...args: SerializableValue) -> ())` (Client only) Registers a function to handle data received from the server.
	@error Throws an error if `NetCodec.Start()` has not been called first, or if underlying remotes cannot be found/created.
]]
function NetCodec.DefineRemoteEvent(name: string)
	if not NetCodec._started then error("NetCodec.Start() must be called before defining remotes.", 2) end
	if typeof(name) ~= "string" or string.len(name) == 0 then error("Remote event name must be a non-empty string.", 2) end

	if NetCodec.Remotes[name] then
		if not NetCodec.Remotes[name]._isEvent then
			error(("NetCodec: Remote '%s' was previously defined as a RemoteFunction, not a RemoteEvent."):format(name), 2)
		end
		return NetCodec.Remotes[name]
	end

	local remote = getRemoteEvent(name)
	local definition = { _isEvent = true }

	--[[! (Client-only) Fires the event, sending data to the server.
		@param ...args SerializableValue The data arguments to send. Must be serializable by NetCodec.
		@error Throws if called from the server or if data validation fails. ]]
	function definition:FireServer(...)
		if isServer then error("FireServer can only be called from the client", 2) end
		local args = { ... }
		if not Validator.Validate(args) then
			error("NetCodec: Invalid data provided to FireServer for event '" .. name .. "'", 2)
		end
		local bufferData = Serializer.Serialize(args)
		remote:FireServer(bufferData)
	end

	--[[! (Server-only) Fires the event, sending data to a specific client.
		@param player Player The client to send the data to.
		@param ...args SerializableValue The data arguments to send. Must be serializable by NetCodec.
		@error Throws if called from the client or if data validation fails. ]]
	function definition:FireClient(player: Player, ...)
		if not isServer then error("FireClient can only be called from the server", 2) end
		local args = { ... }
		if not Validator.Validate(args) then
			error("NetCodec: Invalid data provided to FireClient for event '" .. name .. "'", 2)
		end
		local bufferData = Serializer.Serialize(args)
		remote:FireClient(player, bufferData)
	end

	--[[! (Server-only) Fires the event, sending data to all connected clients.
		@param ...args SerializableValue The data arguments to send. Must be serializable by NetCodec.
		@error Throws if called from the client or if data validation fails. ]]
	function definition:FireAllClients(...)
		if not isServer then error("FireAllClients can only be called from the server", 2) end
		local args = { ... }
		if not Validator.Validate(args) then
			error("NetCodec: Invalid data provided to FireAllClients for event '" .. name .. "'", 2)
		end
		local bufferData = Serializer.Serialize(args)
		remote:FireAllClients(bufferData)
	end

	--[[! (Server-only) Fires the event, sending data to all connected clients except those specified.
		@param playersToExclude Player | {Player} A single Player instance or an array of Player instances to exclude.
		@param ...args SerializableValue The data arguments to send. Must be serializable by NetCodec.
		@error Throws if called from the client or if data validation fails. ]]
	function definition:FireAllClientsExcept(playersToExclude: Player | {Player}, ...)
		if not isServer then error("FireAllClientsExcept can only be called from the server", 2) end
		local args = { ... }
		if not Validator.Validate(args) then
			error("NetCodec: Invalid data provided to FireAllClientsExcept for event '" .. name .. "'", 2)
		end
		local bufferData = Serializer.Serialize(args)
		remote:FireAllClientsExcept(playersToExclude, bufferData)
	end

	--[[! (Server-only) Connects a listener function that will be called when a client fires this event using `:FireServer()`.
		The callback function receives the Player instance who fired the event, followed by the deserialized data arguments.
		The callback is executed in a separate thread using `task.spawn` for safety.
		@param callback function The function to call upon receiving the event. Signature: `(player: Player, ...args: SerializableValue) -> ()`
		@error Throws if called from the client. ]]
	function definition:ConnectServer(callback: (player: Player, ...any) -> ())
		if not isServer then error("ConnectServer can only be called from the server", 2) end
		if typeof(callback) ~= "function" then error("ConnectServer requires a function callback.", 2) end
		remote.OnServerEvent:Connect(function(player, bufferData)
			local success, args = pcall(Deserializer.Deserialize, bufferData)
			if success then
				if Validator.Validate(args) then
					task.spawn(callback, player, unpack(args))
				else
					warn("NetCodec Server: Invalid data received for event '" .. name .. "'. Validation failed.")
				end
			else
				warn("NetCodec Server: Failed to deserialize data for event '" .. name .. "':", args) 
			end
		end)
	end

	--[[! (Client-only) Connects a listener function that will be called when the server fires this event using `:FireClient()`, `:FireAllClients()`, or `:FireAllClientsExcept()`.
		The callback function receives the deserialized data arguments sent by the server.
		The callback is executed in a separate thread using `task.spawn` for safety.
		@param callback function The function to call upon receiving the event. Signature: `(...args: SerializableValue) -> ()`
		@error Throws if called from the server. ]]
	function definition:ConnectClient(callback: (...any) -> ())
		if isServer then error("ConnectClient can only be called from the client", 2) end
		if typeof(callback) ~= "function" then error("ConnectClient requires a function callback.", 2) end
		remote.OnClientEvent:Connect(function(bufferData)
			local success, args = pcall(Deserializer.Deserialize, bufferData)
			if success then
				if Validator.Validate(args) then
					task.spawn(callback, unpack(args))
				else
					warn("NetCodec Client: Invalid data received for event '" .. name .. "'. Validation failed.")
				end
			else
				warn("NetCodec Client: Failed to deserialize data for event '" .. name .. "':", args) 
			end
		end)
	end

	NetCodec.Remotes[name] = definition
	return definition
end


--[[!
	Defines and retrieves a wrapper for a `RemoteFunction` used for two-way request/response
	communication between a client and the server.

	If a function with the same name has already been defined, the existing definition is returned.
	This ensures that both server and client scripts can define the same function without conflicts.

	The underlying `RemoteFunction` instance is automatically created in the appropriate
	`ReplicatedStorage` folder if it doesn't exist (server-side) or waited for (client-side).

	@param name string The unique identifier for this remote function. Must be consistent across server and client.
	@returns table A table containing methods specific to this function:
		- `:InvokeServer(...args: SerializableValue) -> ...SerializableValue` (Client only) Sends a request to the server and waits for a response.
		- `:SetCallback(callback: (player: Player, ...args: SerializableValue) -> ...SerializableValue)` (Server only) Sets the function that handles client requests and returns a response.
	@error Throws an error if `NetCodec.Start()` has not been called first, or if underlying remotes cannot be found/created.
]]
function NetCodec.DefineRemoteFunction(name: string)
	if not NetCodec._started then error("NetCodec.Start() must be called before defining remotes.", 2) end
	if typeof(name) ~= "string" or string.len(name) == 0 then error("Remote function name must be a non-empty string.", 2) end

	if NetCodec.Remotes[name] then
		if NetCodec.Remotes[name]._isEvent then
			error(("NetCodec: Remote '%s' was previously defined as a RemoteEvent, not a RemoteFunction."):format(name), 2)
		end
		return NetCodec.Remotes[name]
	end

	local remote = getRemoteFunction(name)
	local definition = { _isEvent = false }

	--[[! (Client-only) Invokes the remote function on the server, sending request data and waiting synchronously for a response.
		@param ...args SerializableValue The request data arguments to send. Must be serializable by NetCodec.
		@returns ...SerializableValue The deserialized response data arguments returned by the server's callback. Returns `nil` if deserialization or validation of the response fails.
		@error Throws if called from the server or if request data validation fails. May also yield and error if the server takes too long to respond or errors internally. ]]
	function definition:InvokeServer(...)
		if isServer then error("InvokeServer can only be called from the client", 2) end
		local args = { ... }
		if not Validator.Validate(args) then
			error("NetCodec: Invalid data provided to InvokeServer for function '" .. name .. "'", 2)
		end
		local bufferData = Serializer.Serialize(args)
		local responseBuffer = remote:InvokeServer(bufferData)
		local success, responseArgs = pcall(Deserializer.Deserialize, responseBuffer)
		if success then
			if Validator.Validate(responseArgs) then
				return unpack(responseArgs)
			else
				warn("NetCodec Client: Invalid response data received for function '" .. name .. "'. Validation failed.")
				return nil
			end
		else
			warn("NetCodec Client: Failed to deserialize response for function '" .. name .. "':", responseArgs)
			return nil
		end
	end

	--[[! (Server-only) Sets the callback function that will be executed when a client invokes this function using `:InvokeServer()`.
		The callback receives the Player instance who made the request, followed by the deserialized request arguments.
		It **must** return one or more values that are serializable by NetCodec. These values will be sent back to the invoking client as the response.
		If the received data or the data returned by the callback fails validation, a default empty table `{}` is serialized and returned to the client to indicate an issue.
		@param callback function The function to handle the invocation. Signature: `(player: Player, ...requestArgs: SerializableValue) -> ...responseArgs: SerializableValue`
		@error Throws if called from the client. ]]
	function definition:SetCallback(callback: (player: Player, ...any) -> ...any)
		if not isServer then error("SetCallback can only be called from the server", 2) end
		if typeof(callback) ~= "function" then error("SetCallback requires a function callback.", 2) end
		remote.OnServerInvoke = function(player, bufferData)
			local success, args = pcall(Deserializer.Deserialize, bufferData)
			if success then
				if Validator.Validate(args) then
					local responseArgs = { callback(player, unpack(args)) }
					if Validator.Validate(responseArgs) then
						return Serializer.Serialize(responseArgs)
					else
						warn("NetCodec Server: Invalid response data generated by callback for function '" .. name .. "'. Validation failed.")
						return Serializer.Serialize({})
					end
				else
					warn("NetCodec Server: Invalid data received for function '" .. name .. "'. Validation failed.")
					return Serializer.Serialize({})
				end
			else
				warn("NetCodec Server: Failed to deserialize data for function '" .. name .. "':", args) 
				return Serializer.Serialize({})
			end
		end
	end

	NetCodec.Remotes[name] = definition
	return definition
end


return NetCodec
