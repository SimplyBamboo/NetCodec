--!strict
-- Client initialization for NetCodec example
local Players = game:GetService("Players")
local NetCodec = require(game.ReplicatedStorage.Shared.NetCodec)

-- Initialize NetCodec (must be called once)
NetCodec.Start()

-- Get the local player
local player = Players.LocalPlayer

-- Define the same remote event
local GreetEvent = NetCodec.DefineRemoteEvent("PlayerGreeting")

-- Connect handler for server broadcasts
GreetEvent:ConnectClient(function(message: string)
    print("Client received:", message)
end)

-- Send initial greeting after character loads
player.CharacterAdded:Connect(function()
    task.wait(1) -- Brief delay
    GreetEvent:FireServer(`Hello from {player.Name}!`)
end)

print("NetCodec client setup complete")
