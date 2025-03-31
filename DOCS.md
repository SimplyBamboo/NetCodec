# NetCodec API Documentation

## Overview

NetCodec provides a safer, more efficient way to handle Roblox networking by:
- Serializing data to binary buffers for smaller payloads
- Validating data types automatically before transmission
- Managing RemoteEvent/RemoteFunction instances

## Core Functions

### `NetCodec.Start()`
Initializes the networking system. Must be called once on both client and server before any other NetCodec functions.

**Usage:**
```lua
-- Server:
NetCodec.Start() -- Creates containers in ReplicatedStorage

-- Client:
NetCodec.Start() -- Finds server-created containers
```

### `NetCodec.DefineRemoteEvent(eventName: string)`
Creates a managed RemoteEvent wrapper.

**Parameters:**
- `eventName` (string): Unique identifier shared between server/client scripts

**Returns:** RemoteEvent wrapper with methods below.

**Example:**
```lua
local myEvent = NetCodec.DefineRemoteEvent("PlayerJoined")
```

### `NetCodec.DefineRemoteFunction(funcName: string)`  
Creates a managed RemoteFunction wrapper.

**Parameters & Returns:** Same as DefineRemoteEvent but for functions.

## RemoteEvent Methods

### Event Firing
| Method | Description | Example |
|--------|-------------|---------|
| `:FireServer(...)` | Client → Server | `myEvent:FireServer(playerData)` |
| `:FireClient(player, ...)` | Server → Specific client | `myEvent:FireClient(player, message)` |
| `:FireAllClients(...)` | Server → All clients | `myEvent:FireAllClients(gameUpdate)` |
| `:FireAllClientsExcept(excludedPlayers, ...)` | Server → Filtered clients | `myEvent:FireAllClientsExcept({cheater}, antiCheatUpdate)` |

### Event Listening
| Method | Parameters | Example |
|--------|------------|---------|
| `:ConnectServer(callback)` | `function(player, ...)` | `myEvent:ConnectServer(onPlayerEvent)` |
| `:ConnectClient(callback)` | `function(...)` | `myEvent:ConnectClient(onServerMessage)` |

## RemoteFunction Methods

| Method | Description | Example |
|--------|-------------|---------|
| `:InvokeServer(...)` | Client → Server request | `local response = myFunc:InvokeServer(request)` |
| `:SetCallback(callback)` | Server handler `function(player, ...)` | `myFunc:SetCallback(handleRequest)` |

## Supported Data Types

| Type | Limits | Example |
|------|--------|---------|
| Boolean | - | `true` | 
| Number | Finite, 64-bit | `42`, `3.14` |
| String | ≤65535 chars UTF-8 | `"Hello"` |
| Vector3 | - | `Vector3.new(1,2,3)` |
| CFrame | - | `CFrame.new(pos)` |
| Table | Arrays or maps | `{1,2,3}` or `{key="value"}` |

## Validation Rules

1. **Numbers**: Must be finite (no NaN/infinity)
2. **Strings**: Max 65535 UTF-8 encoded chars
3. **Tables**:
   - Arrays: Sequential integer keys from 1
   - Maps: String keys only
   - Max 32 nesting levels
4. **Custom Types**: Use validator modules

## Error Handling

NetCodec will:
- Validate data before sending
- Validate received data
- Log warnings for invalid data
- Use `task.spawn` to isolate callbacks
