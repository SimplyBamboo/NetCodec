# NetCodec API Documentation

## Core Functions

### `NetCodec.Start()`
Initializes the networking system. Must be called on both client and server.

### `NetCodec.DefineRemoteEvent(eventName: string): RemoteEvent`
Creates a new remote event that can be fired between client and server.

### `NetCodec.DefineRemoteFunction(funcName: string): RemoteFunction`  
Creates a new remote function for request/response communication.

## RemoteEvent Methods

### `RemoteEvent:FireServer(...)`
Client-to-server event firing. Arguments are automatically serialized.

### `RemoteEvent:FireClient(player: Player, ...)`  
Server-to-client event firing for a specific player.

### `RemoteEvent:FireAllClients(...)`  
Server-to-all-clients event firing.

### `RemoteEvent:ConnectServer(callback: (player: Player, ...) -> ())`  
Server-side event listener.

### `RemoteEvent:ConnectClient(callback: (...)->())`  
Client-side event listener.

## RemoteFunction Methods

### `RemoteFunction:InvokeServer(...): ...`  
Client-to-server function invocation.

### `RemoteFunction:SetCallback(callback: (player: Player, ...)->...)`  
Server-side function handler.

## Supported Types

| Type       | Notes                          |
|------------|--------------------------------|
| nil        |                                |
| boolean    |                                |
| number     | 64-bit float                  |
| string     | UTF-8 encoded                 |
| Vector3    |                                |
| CFrame     |                                |
| table      | Arrays or string-keyed maps   |

## Validation Rules

Data is automatically validated against these rules:
- Numbers must be finite (no NaN/infinity)
- Strings have maximum length of 65535 characters
- Tables must be either:
  - Arrays (sequential integer keys starting at 1)
  - Maps (string keys only)
- Nested tables up to 32 levels deep
