--[[
    EventsSetup (ModuleScript)
    Location: ReplicatedStorage/EventsSetup

    Run this once to create all the RemoteEvents needed by the game.
    Or create them manually in ReplicatedStorage/Events.

    Usage from command bar:
        require(game.ReplicatedStorage.EventsSetup)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
    eventsFolder = Instance.new("Folder")
    eventsFolder.Name = "Events"
    eventsFolder.Parent = ReplicatedStorage
end

local remoteEvents = {
    "Jumpscare",          -- Server -> Client: trigger jumpscare
    "UpdateObjective",    -- Server -> Client: update objective text
    "GameState",          -- Server -> Client: game state changes (Started, Won, Lost)
    "Heartbeat",          -- Server -> Client: monster proximity heartbeat
    "ScareEvent",         -- Server -> Client: random scare events
    "PlayerSprinting",    -- Client -> Server: sprint state toggle
    "PlayerHiding",       -- Client -> Server: hiding state toggle
}

for _, eventName in ipairs(remoteEvents) do
    if not eventsFolder:FindFirstChild(eventName) then
        local event = Instance.new("RemoteEvent")
        event.Name = eventName
        event.Parent = eventsFolder
    end
end

print("[EventsSetup] All remote events created successfully!")

return true
