--!strict
-- Server initialization for NetCodec example
local NetCodec = require(game.ReplicatedStorage.Shared.NetCodec)

-- Initialize NetCodec (must be called once)
NetCodec.Start()

-- Define a remote event for player greetingss
local GreetEvent = NetCodec.DefineRemoteEvent("PlayerGreeting")

-- Connect handler for when clients send greetings
GreetEvent:ConnectServer(function(player: Player, message: string)
    print(`Server received greeting from {player.Name}: {message}`)
    
    -- Broadcast to all players except the sender
    GreetEvent:FireAllClientsExcept(player, 
        `{player.Name} says: {message}`)
end)

print("NetCodec server setup complete")
