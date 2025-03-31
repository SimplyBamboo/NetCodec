# NetCodec

**⚠️ WARNING: This is a WORK IN PROGRESS and not stable for production use yet! ⚠️**  
*(Only use if you're willing to deal with potential breaking changes and bugs)*

NetCodec is a high-performance, buffer-based networking library for Roblox Luau. It simplifies client-server communication by automatically handling data serialization into efficient buffer formats, deserialization, and type validation.

Created by [SimplyBamboo](https://www.youtube.com/@Simply.Bamboo) ([Roblox Profile](https://www.roblox.com/users/1466889132/profile), Discord: simply.bamboo)

## Features

- **Performance:** Leverages Luau's `buffer` library for efficient data transmission
- **Type Safety:** Built-in validation for common Roblox data types
- **Simple API:** Minimalistic API for remote events and functions

## Installation

1. Download this repository
2. Drag the `src/shared` and its contents into Roblox Studio's ReplicatedStorage


## Quick Start

```lua
-- Server
local NetCodec = require(game:GetService("ReplicatedStorage").NetCodec)
NetCodec.Start()

local playerJoined = NetCodec.DefineRemoteEvent("PlayerJoined")

game.Players.PlayerAdded:Connect(function(player)
    playerJoined:FireAllClients(player.Name.." joined the game!")
end)
```

```lua
-- Client
local NetCodec = require(game:GetService("ReplicatedStorage").NetCodec)
NetCodec.Start()

local playerJoined = NetCodec.DefineRemoteEvent("PlayerJoined")
playerJoined:ConnectClient(function(message)
    print(message) -- "PlayerName joined the game!"
end)
```

## Advanced Examples

### Custom Data Types
```lua
-- Shared
local NetCodec = require(game:GetService("ReplicatedStorage").NetCodec)

local playerUpdate = NetCodec.DefineRemoteEvent("PlayerUpdate")

-- Server
playerUpdate:ConnectServer(function(player, data)
    -- data is automatically validated
    print(player.Name, "position:", data.position)
end)

-- Client
local data = {
    position = Vector3.new(10, 5, 20),
    health = 100,
    items = {"sword", "shield"}
}
playerUpdate:FireServer(data)
```

## Documentation

Full API documentation is available in [DOCS.md](DOCS.md)

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

GNU General Public License v3.0 - See [LICENSE](LICENSE) for details.
