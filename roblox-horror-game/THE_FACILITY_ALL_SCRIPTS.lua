--[[
================================================================================
    THE FACILITY - Complete Roblox Horror Game
    All scripts in one file for easy copy-paste
================================================================================

    HOW TO USE:
    1. Each section below is a SEPARATE script
    2. Copy each section into Roblox Studio as the type shown in the header
    3. Place it in the location shown in the header
    4. DO NOT paste this entire file as one script - each section is independent

    SCRIPT LIST:
    1. EventsSetup         → ModuleScript   → ReplicatedStorage
    2. GameManager          → Script         → ServerScriptService
    3. PlayerSetup          → Script         → ServerScriptService
    4. DoorSystem           → Script         → ServerScriptService
    5. LightFlicker         → Script         → ServerScriptService
    6. FlashlightController → LocalScript    → StarterPlayer > StarterPlayerScripts
    7. SprintController     → LocalScript    → StarterPlayer > StarterPlayerScripts
    8. HorrorUI             → LocalScript    → StarterPlayer > StarterPlayerScripts
    9. AtmosphereController → LocalScript    → StarterPlayer > StarterPlayerScripts
   10. HidingController     → LocalScript    → StarterPlayer > StarterPlayerScripts

    WORKSPACE SETUP (create these in Workspace):
    - PlayerSpawn        (SpawnLocation) - where players spawn
    - ExitDoor           (Model) - with a child Part named "ExitZone"
    - Keycards           (Folder) - with Parts named Keycard1, Keycard2, Keycard3
    - MonsterWaypoints   (Folder) - with Parts marking patrol route
    - Doors              (Folder) - with door Models (each has "Hinge" + "Door" parts)
    - HidingSpots        (Folder) - with Parts/Models (lockers, desks, etc.)

    SERVER STORAGE SETUP:
    - Subject7            (Model) - the monster, must have Humanoid + HumanoidRootPart
    - Flashlight          (Tool) - given to players on spawn

    CONTROLS:
    - WASD       = Move
    - Left Shift = Sprint
    - F          = Toggle flashlight
    - E          = Interact (doors, hiding spots)
================================================================================
]]


--[[
================================================================================
SCRIPT 1 OF 10: EventsSetup
TYPE: ModuleScript
LOCATION: ReplicatedStorage/EventsSetup
PURPOSE: Creates all RemoteEvents. Run once from command bar:
         require(game.ReplicatedStorage.EventsSetup)
         OR just manually create the Events folder (see below).
================================================================================
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


--[[
================================================================================
SCRIPT 2 OF 10: GameManager
TYPE: Script (ServerScript)
LOCATION: ServerScriptService/GameManager
PURPOSE: Core game loop - monster AI, keycards, win/lose, difficulty scaling
================================================================================
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Remote Events (create these in ReplicatedStorage/Events)
local Events = ReplicatedStorage:WaitForChild("Events")
local JumpscareEvent = Events:WaitForChild("Jumpscare")
local ObjectiveEvent = Events:WaitForChild("UpdateObjective")
local GameStateEvent = Events:WaitForChild("GameState")
local HeartbeatEvent = Events:WaitForChild("Heartbeat")
local ScareEvent = Events:WaitForChild("ScareEvent")

-- Game Configuration
local CONFIG = {
    MIN_PLAYERS = 1,
    MAX_KEYCARDS = 3,
    GAME_START_DELAY = 5,
    MONSTER_BASE_SPEED = 18,
    MONSTER_CHASE_SPEED = 28,
    MONSTER_SPEED_INCREMENT = 1.5,
    DIFFICULTY_INTERVAL = 120, -- seconds between difficulty increases
    MONSTER_DETECTION_RANGE = 60,
    MONSTER_CHASE_RANGE = 35,
    MONSTER_LOSE_INTEREST_TIME = 10,
    MONSTER_KILL_RANGE = 5,
    SCARE_EVENT_MIN_INTERVAL = 30,
    SCARE_EVENT_MAX_INTERVAL = 90,
}

-- Game State
local gameState = "Waiting" -- Waiting, Playing, Ended
local keycardsCollected = {}
local totalKeycards = 0
local gameStartTime = 0
local difficultyLevel = 0
local alivePlayers = {}

-- Monster State
local monster = nil
local monsterState = "Patrol" -- Patrol, Alert, Chase, Cooldown
local monsterTarget = nil
local monsterCooldownTimer = 0
local currentWaypointIndex = 1
local waypoints = {}

----------------------------------------------------------------------
-- UTILITY
----------------------------------------------------------------------

local function getAlivePlayers()
    local alive = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if alivePlayers[player.UserId] and player.Character and player.Character:FindFirstChild("Humanoid") then
            if player.Character.Humanoid.Health > 0 then
                table.insert(alive, player)
            end
        end
    end
    return alive
end

local function distanceBetween(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

local function broadcastObjective(text)
    ObjectiveEvent:FireAllClients(text)
end

----------------------------------------------------------------------
-- SCARE EVENTS
----------------------------------------------------------------------

local function triggerRandomScare()
    if gameState ~= "Playing" then return end

    local scareTypes = {"flicker", "sound", "door_slam", "whisper", "object_fall"}
    local scareType = scareTypes[math.random(1, #scareTypes)]

    ScareEvent:FireAllClients(scareType)

    -- Flicker lights server-side too
    if scareType == "flicker" then
        local originalBrightness = Lighting.Brightness
        for _ = 1, math.random(3, 8) do
            Lighting.Brightness = 0
            task.wait(math.random() * 0.15)
            Lighting.Brightness = originalBrightness
            task.wait(math.random() * 0.1)
        end
    end
end

local function scareEventLoop()
    while gameState == "Playing" do
        local interval = math.random(CONFIG.SCARE_EVENT_MIN_INTERVAL, CONFIG.SCARE_EVENT_MAX_INTERVAL)
        -- Reduce interval as difficulty increases
        interval = math.max(10, interval - (difficultyLevel * 5))
        task.wait(interval)
        if gameState == "Playing" then
            triggerRandomScare()
        end
    end
end

----------------------------------------------------------------------
-- MONSTER AI
----------------------------------------------------------------------

local function setupMonster()
    local monsterModel = ServerStorage:FindFirstChild("Subject7")
    if not monsterModel then
        warn("[GameManager] Subject7 model not found in ServerStorage!")
        return
    end

    monster = monsterModel:Clone()
    monster.Parent = workspace

    -- Collect waypoints
    local waypointFolder = workspace:FindFirstChild("MonsterWaypoints")
    if waypointFolder then
        for _, wp in ipairs(waypointFolder:GetChildren()) do
            table.insert(waypoints, wp.Position)
        end
    end

    if #waypoints == 0 then
        warn("[GameManager] No MonsterWaypoints found! Monster will stay in place.")
    end
end

local function moveMonsterTo(targetPosition, speed)
    if not monster or not monster:FindFirstChild("Humanoid") then return end
    monster.Humanoid.WalkSpeed = speed
    monster.Humanoid:MoveTo(targetPosition)
end

local function findNearestPlayer()
    local nearest = nil
    local nearestDist = math.huge

    for _, player in ipairs(getAlivePlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local dist = distanceBetween(
                monster.HumanoidRootPart.Position,
                player.Character.HumanoidRootPart.Position
            )
            if dist < nearestDist then
                nearestDist = dist
                nearest = player
            end
        end
    end

    return nearest, nearestDist
end

local function killPlayer(player)
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end

    alivePlayers[player.UserId] = nil

    -- Trigger jumpscare on the killed player
    JumpscareEvent:FireClient(player, "death")

    -- Kill after brief delay for jumpscare
    task.wait(0.5)
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.Health = 0
    end

    -- Check if all players are dead
    if #getAlivePlayers() == 0 then
        gameState = "Ended"
        GameStateEvent:FireAllClients("Lost")
        broadcastObjective("GAME OVER - Subject-7 got everyone...")
    end
end

local function updateMonster()
    if not monster or not monster:FindFirstChild("HumanoidRootPart") then return end
    if gameState ~= "Playing" then return end

    local nearest, nearestDist = findNearestPlayer()
    local currentSpeed = CONFIG.MONSTER_BASE_SPEED + (difficultyLevel * CONFIG.MONSTER_SPEED_INCREMENT)

    -- State machine
    if monsterState == "Patrol" then
        if nearest and nearestDist < CONFIG.MONSTER_CHASE_RANGE then
            monsterState = "Chase"
            monsterTarget = nearest
        elseif nearest and nearestDist < CONFIG.MONSTER_DETECTION_RANGE then
            monsterState = "Alert"
            monsterTarget = nearest
        else
            -- Patrol between waypoints
            if #waypoints > 0 then
                local targetWP = waypoints[currentWaypointIndex]
                moveMonsterTo(targetWP, currentSpeed * 0.5)

                local monsterPos = monster.HumanoidRootPart.Position
                if distanceBetween(Vector3.new(monsterPos.X, 0, monsterPos.Z), Vector3.new(targetWP.X, 0, targetWP.Z)) < 5 then
                    currentWaypointIndex = currentWaypointIndex % #waypoints + 1
                end
            end
        end

    elseif monsterState == "Alert" then
        if nearest and nearestDist < CONFIG.MONSTER_CHASE_RANGE then
            monsterState = "Chase"
            monsterTarget = nearest
        elseif nearest and nearestDist < CONFIG.MONSTER_DETECTION_RANGE then
            -- Move toward player slowly
            if nearest.Character and nearest.Character:FindFirstChild("HumanoidRootPart") then
                moveMonsterTo(nearest.Character.HumanoidRootPart.Position, currentSpeed * 0.7)
            end
            -- Send heartbeat to nearby players
            HeartbeatEvent:FireClient(nearest, true)
        else
            monsterState = "Patrol"
            if nearest then
                HeartbeatEvent:FireClient(nearest, false)
            end
        end

    elseif monsterState == "Chase" then
        if monsterTarget and monsterTarget.Character and monsterTarget.Character:FindFirstChild("HumanoidRootPart") then
            local targetDist = distanceBetween(
                monster.HumanoidRootPart.Position,
                monsterTarget.Character.HumanoidRootPart.Position
            )

            if targetDist < CONFIG.MONSTER_KILL_RANGE then
                killPlayer(monsterTarget)
                monsterState = "Cooldown"
                monsterCooldownTimer = 5
            elseif targetDist > CONFIG.MONSTER_DETECTION_RANGE * 1.5 then
                monsterState = "Cooldown"
                monsterCooldownTimer = CONFIG.MONSTER_LOSE_INTEREST_TIME
                HeartbeatEvent:FireClient(monsterTarget, false)
            else
                local chaseSpeed = CONFIG.MONSTER_CHASE_SPEED + (difficultyLevel * CONFIG.MONSTER_SPEED_INCREMENT)
                moveMonsterTo(monsterTarget.Character.HumanoidRootPart.Position, chaseSpeed)
                HeartbeatEvent:FireClient(monsterTarget, true)
            end
        else
            monsterState = "Cooldown"
            monsterCooldownTimer = CONFIG.MONSTER_LOSE_INTEREST_TIME
        end

    elseif monsterState == "Cooldown" then
        monsterCooldownTimer = monsterCooldownTimer - 0.1
        if monsterCooldownTimer <= 0 then
            monsterState = "Patrol"
            monsterTarget = nil
        end
    end
end

----------------------------------------------------------------------
-- KEYCARD SYSTEM
----------------------------------------------------------------------

local function setupKeycards()
    local keycardFolder = workspace:FindFirstChild("Keycards")
    if not keycardFolder then
        warn("[GameManager] No Keycards folder found in Workspace!")
        return
    end

    for _, keycard in ipairs(keycardFolder:GetChildren()) do
        totalKeycards = totalKeycards + 1

        -- Add glow effect
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(0, 255, 100)
        light.Brightness = 0.5
        light.Range = 8
        light.Parent = keycard

        -- Touch detection
        keycard.Touched:Connect(function(hit)
            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player and not keycardsCollected[keycard.Name] then
                keycardsCollected[keycard.Name] = true
                keycard:Destroy()

                local count = 0
                for _ in pairs(keycardsCollected) do count = count + 1 end

                broadcastObjective("Keycards: " .. count .. "/" .. CONFIG.MAX_KEYCARDS)

                -- Trigger scare when picking up keycard
                JumpscareEvent:FireClient(player, "keycard")
                ScareEvent:FireAllClients("flicker")

                -- Check if all keycards collected
                if count >= CONFIG.MAX_KEYCARDS then
                    broadcastObjective("All keycards found! Get to the EXIT!")
                    -- Unlock exit door
                    local exitDoor = workspace:FindFirstChild("ExitDoor")
                    if exitDoor then
                        exitDoor:SetAttribute("Unlocked", true)
                        -- Visual feedback
                        if exitDoor:FindFirstChild("Light") then
                            exitDoor.Light.Color = Color3.fromRGB(0, 255, 0)
                        end
                    end
                end
            end
        end)
    end
end

----------------------------------------------------------------------
-- EXIT DOOR
----------------------------------------------------------------------

local function setupExitDoor()
    local exitDoor = workspace:FindFirstChild("ExitDoor")
    if not exitDoor then
        warn("[GameManager] No ExitDoor found in Workspace!")
        return
    end

    exitDoor:SetAttribute("Unlocked", false)

    local exitZone = exitDoor:FindFirstChild("ExitZone")
    if exitZone then
        exitZone.Touched:Connect(function(hit)
            if gameState ~= "Playing" then return end
            if not exitDoor:GetAttribute("Unlocked") then return end

            local player = Players:GetPlayerFromCharacter(hit.Parent)
            if player and alivePlayers[player.UserId] then
                -- Player escaped!
                alivePlayers[player.UserId] = nil
                gameState = "Ended"
                GameStateEvent:FireAllClients("Won")
                broadcastObjective("ESCAPED! You survived The Facility!")
            end
        end)
    end
end

----------------------------------------------------------------------
-- DIFFICULTY SCALING
----------------------------------------------------------------------

local function difficultyLoop()
    while gameState == "Playing" do
        task.wait(CONFIG.DIFFICULTY_INTERVAL)
        if gameState == "Playing" then
            difficultyLevel = difficultyLevel + 1
            -- Reduce scare intervals handled in scareEventLoop
            -- Monster gets faster via updateMonster reading difficultyLevel
        end
    end
end

----------------------------------------------------------------------
-- GAME FLOW
----------------------------------------------------------------------

local function startGame()
    gameState = "Playing"
    gameStartTime = tick()
    difficultyLevel = 0
    keycardsCollected = {}
    totalKeycards = 0

    -- Mark all current players as alive
    for _, player in ipairs(Players:GetPlayers()) do
        alivePlayers[player.UserId] = true
    end

    -- Setup game elements
    setupKeycards()
    setupExitDoor()
    setupMonster()

    -- Broadcast
    GameStateEvent:FireAllClients("Started")
    broadcastObjective("Find 3 keycards and escape the facility!")

    -- Set dark atmosphere
    Lighting.Brightness = 0.3
    Lighting.ClockTime = 0
    Lighting.FogEnd = 150
    Lighting.FogColor = Color3.fromRGB(10, 10, 15)
    Lighting.Ambient = Color3.fromRGB(15, 15, 20)

    -- Start background loops
    task.spawn(scareEventLoop)
    task.spawn(difficultyLoop)

    -- Main monster update loop
    while gameState == "Playing" do
        updateMonster()
        task.wait(0.1)
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        -- Spawn player at spawn location
        local spawn = workspace:FindFirstChild("PlayerSpawn")
        if spawn and character:FindFirstChild("HumanoidRootPart") then
            character.HumanoidRootPart.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
        end

        if gameState == "Playing" then
            alivePlayers[player.UserId] = true
        end
    end)
end

local function onPlayerRemoving(player)
    alivePlayers[player.UserId] = nil
end

----------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Wait for minimum players then start
while true do
    if #Players:GetPlayers() >= CONFIG.MIN_PLAYERS and gameState == "Waiting" then
        broadcastObjective("Game starting in " .. CONFIG.GAME_START_DELAY .. " seconds...")
        task.wait(CONFIG.GAME_START_DELAY)

        if #Players:GetPlayers() >= CONFIG.MIN_PLAYERS then
            startGame()
        end
    end
    task.wait(1)
end


--[[
================================================================================
SCRIPT 3 OF 10: PlayerSetup
TYPE: Script (ServerScript)
LOCATION: ServerScriptService/PlayerSetup
PURPOSE: Player attributes, stamina, flashlight tool, sprint/hide handlers
================================================================================
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local SprintEvent = Events:WaitForChild("PlayerSprinting")
local HideEvent = Events:WaitForChild("PlayerHiding")

----------------------------------------------------------------------
-- PLAYER SETUP
----------------------------------------------------------------------

local function onCharacterAdded(player, character)
    local humanoid = character:WaitForChild("Humanoid")

    -- Set attributes
    player:SetAttribute("Stamina", 100)
    player:SetAttribute("MaxStamina", 100)
    player:SetAttribute("IsSprinting", false)
    player:SetAttribute("IsHiding", false)
    player:SetAttribute("FlashlightBattery", 100)
    player:SetAttribute("KeycardsHeld", 0)

    -- Set default walk speed
    humanoid.WalkSpeed = 14

    -- Give flashlight tool
    local flashlightTool = ServerStorage:FindFirstChild("Flashlight")
    if flashlightTool then
        local flashlight = flashlightTool:Clone()
        flashlight.Parent = player.Backpack
    end

    -- Stamina regeneration loop
    task.spawn(function()
        while character and humanoid and humanoid.Health > 0 do
            local stamina = player:GetAttribute("Stamina")
            local isSprinting = player:GetAttribute("IsSprinting")

            if isSprinting and stamina > 0 then
                -- Drain stamina while sprinting
                player:SetAttribute("Stamina", math.max(0, stamina - 1.5))
                humanoid.WalkSpeed = 24

                if stamina <= 0 then
                    player:SetAttribute("IsSprinting", false)
                    humanoid.WalkSpeed = 14
                end
            elseif not isSprinting and stamina < 100 then
                -- Regenerate stamina
                player:SetAttribute("Stamina", math.min(100, stamina + 0.8))
                humanoid.WalkSpeed = 14
            end

            task.wait(0.1)
        end
    end)
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)

    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

----------------------------------------------------------------------
-- REMOTE EVENT HANDLERS
----------------------------------------------------------------------

-- Sprint toggle from client
SprintEvent.OnServerEvent:Connect(function(player, isSprinting)
    player:SetAttribute("IsSprinting", isSprinting)
end)

-- Hide toggle from client
HideEvent.OnServerEvent:Connect(function(player, isHiding)
    player:SetAttribute("IsHiding", isHiding)

    if player.Character then
        -- Make player invisible when hiding
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = isHiding and 1 or 0
            end
        end

        -- Disable collision when hiding
        if player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CanCollide = not isHiding
        end

        -- Can't move while hiding
        if player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.WalkSpeed = isHiding and 0 or 14
        end
    end
end)

----------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------

Players.PlayerAdded:Connect(onPlayerAdded)

-- Setup existing players (in case script loads late)
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end


--[[
================================================================================
SCRIPT 4 OF 10: DoorSystem
TYPE: Script (ServerScript)
LOCATION: ServerScriptService/DoorSystem
PURPOSE: Interactive doors, keycard locks, auto-close, creak sounds
================================================================================
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")
local ScareEvent = Events:WaitForChild("ScareEvent")

-- Config
local DOOR_OPEN_TIME = 1
local DOOR_AUTO_CLOSE_DELAY = 5
local DOOR_OPEN_ANGLE = 90

----------------------------------------------------------------------
-- DOOR SETUP
----------------------------------------------------------------------

local function setupDoor(door)
    local hinge = door:FindFirstChild("Hinge")
    local doorPart = door:FindFirstChild("Door")
    if not hinge or not doorPart then return end

    local isOpen = false
    local isTweening = false
    local closedCFrame = hinge.CFrame
    local openCFrame = hinge.CFrame * CFrame.Angles(0, math.rad(DOOR_OPEN_ANGLE), 0)

    -- Determine if door requires a keycard
    local requiredKeycard = door:GetAttribute("RequiredKeycard") -- e.g., "Keycard1"
    local isLocked = requiredKeycard ~= nil

    -- Create proximity prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = isLocked and "Locked" or "Open Door"
    prompt.ObjectText = door.Name
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration = 0.2
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.Parent = doorPart

    prompt.Triggered:Connect(function(playerWhoTriggered)
        if isTweening then return end

        -- Check if locked
        if isLocked then
            -- Check if player has the required keycard (via game state)
            local keycardFolder = workspace:FindFirstChild("Keycards")
            local hasKey = true
            if keycardFolder then
                local keycard = keycardFolder:FindFirstChild(requiredKeycard)
                if keycard then
                    hasKey = false -- Keycard still exists, hasn't been collected
                end
            end

            if not hasKey then
                prompt.ActionText = "Need " .. requiredKeycard
                task.wait(1)
                prompt.ActionText = "Locked"
                return
            else
                isLocked = false
                prompt.ActionText = "Open Door"
            end
        end

        isTweening = true

        if isOpen then
            -- Close door
            local tweenInfo = TweenInfo.new(DOOR_OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = TweenService:Create(hinge, tweenInfo, {CFrame = closedCFrame})

            -- Play door sound
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://1838456612" -- Door close
            sound.Volume = 0.8
            sound.Parent = doorPart
            sound:Play()
            sound.Ended:Connect(function() sound:Destroy() end)

            tween:Play()
            tween.Completed:Wait()

            isOpen = false
            prompt.ActionText = "Open Door"
        else
            -- Open door
            local tweenInfo = TweenInfo.new(DOOR_OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local tween = TweenService:Create(hinge, tweenInfo, {CFrame = openCFrame})

            -- Play door creak sound
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://1843463175" -- Door creak
            sound.Volume = 1
            sound.Parent = doorPart
            sound:Play()
            sound.Ended:Connect(function() sound:Destroy() end)

            tween:Play()
            tween.Completed:Wait()

            isOpen = true
            prompt.ActionText = "Close Door"

            -- Auto close after delay
            task.delay(DOOR_AUTO_CLOSE_DELAY, function()
                if isOpen and not isTweening then
                    isTweening = true
                    local closeTween = TweenService:Create(hinge, TweenInfo.new(DOOR_OPEN_TIME), {CFrame = closedCFrame})

                    local closeSound = Instance.new("Sound")
                    closeSound.SoundId = "rbxassetid://1838456612"
                    closeSound.Volume = 0.6
                    closeSound.Parent = doorPart
                    closeSound:Play()
                    closeSound.Ended:Connect(function() closeSound:Destroy() end)

                    closeTween:Play()
                    closeTween.Completed:Wait()
                    isOpen = false
                    prompt.ActionText = "Open Door"
                    isTweening = false
                end
            end)
        end

        isTweening = false
    end)
end

----------------------------------------------------------------------
-- INITIALIZE ALL DOORS
----------------------------------------------------------------------

local doorsFolder = workspace:FindFirstChild("Doors")
if doorsFolder then
    for _, door in ipairs(doorsFolder:GetChildren()) do
        setupDoor(door)
    end
else
    warn("[DoorSystem] No 'Doors' folder found in Workspace!")
end

----------------------------------------------------------------------
-- RANDOM DOOR SLAM SCARE
----------------------------------------------------------------------

task.spawn(function()
    while true do
        task.wait(math.random(60, 180))
        if doorsFolder then
            local doors = doorsFolder:GetChildren()
            if #doors > 0 then
                local randomDoor = doors[math.random(1, #doors)]
                local hinge = randomDoor:FindFirstChild("Hinge")
                local doorPart = randomDoor:FindFirstChild("Door")
                if hinge and doorPart then
                    -- Slam sound
                    local sound = Instance.new("Sound")
                    sound.SoundId = "rbxassetid://1838456612"
                    sound.Volume = 2
                    sound.Parent = doorPart
                    sound:Play()
                    sound.Ended:Connect(function() sound:Destroy() end)

                    ScareEvent:FireAllClients("door_slam")
                end
            end
        end
    end
end)


--[[
================================================================================
SCRIPT 5 OF 10: LightFlicker
TYPE: Script (ServerScript)
LOCATION: ServerScriptService/LightFlicker
PURPOSE: Random light flickering and permanent light death for horror atmosphere
================================================================================
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------

local FLICKER_CHECK_INTERVAL = 0.5
local FLICKER_CHANCE = 0.03           -- chance per check per light
local INTENSE_FLICKER_CHANCE = 0.01   -- chance of intense flicker (longer)
local LIGHT_DEATH_CHANCE = 0.001      -- chance a light permanently dies
local FLICKER_DURATION_MIN = 0.05
local FLICKER_DURATION_MAX = 0.3

----------------------------------------------------------------------
-- COLLECT LIGHTS
----------------------------------------------------------------------

local flickerLights = {}

local function collectLights()
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
            -- Skip player flashlights
            if descendant.Name ~= "FlashlightBeam" and descendant.Name ~= "FlashlightGlow" then
                table.insert(flickerLights, {
                    light = descendant,
                    originalBrightness = descendant.Brightness,
                    originalEnabled = descendant.Enabled,
                    isDead = false,
                })
            end
        end
    end
end

----------------------------------------------------------------------
-- FLICKER LOGIC
----------------------------------------------------------------------

local function flickerLight(lightData)
    if lightData.isDead then return end

    local light = lightData.light
    if not light or not light.Parent then return end

    local originalBrightness = lightData.originalBrightness

    -- Quick flicker pattern
    task.spawn(function()
        local flickerCount = math.random(2, 6)
        for _ = 1, flickerCount do
            light.Brightness = 0
            task.wait(math.random() * FLICKER_DURATION_MAX + FLICKER_DURATION_MIN)
            light.Brightness = originalBrightness * (0.3 + math.random() * 0.7)
            task.wait(math.random() * FLICKER_DURATION_MAX + FLICKER_DURATION_MIN)
        end
        light.Brightness = originalBrightness
    end)
end

local function intenseFlicker(lightData)
    if lightData.isDead then return end

    local light = lightData.light
    if not light or not light.Parent then return end

    local originalBrightness = lightData.originalBrightness

    -- Long intense flicker
    task.spawn(function()
        for _ = 1, math.random(8, 15) do
            light.Brightness = 0
            light.Enabled = false
            task.wait(math.random() * 0.2)
            light.Enabled = true
            light.Brightness = originalBrightness * math.random()
            task.wait(math.random() * 0.1)
        end

        -- Buzz effect
        for _ = 1, 20 do
            light.Brightness = originalBrightness * (0.5 + math.random() * 0.5)
            task.wait(0.02)
        end

        light.Brightness = originalBrightness
    end)
end

local function killLight(lightData)
    lightData.isDead = true
    local light = lightData.light
    if light and light.Parent then
        -- Dramatic death flicker then off
        task.spawn(function()
            for _ = 1, 5 do
                light.Brightness = lightData.originalBrightness * 0.5
                task.wait(0.1)
                light.Brightness = 0
                task.wait(0.15)
            end
            light.Enabled = false
        end)
    end
end

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------

collectLights()

while true do
    task.wait(FLICKER_CHECK_INTERVAL)

    for _, lightData in ipairs(flickerLights) do
        if lightData.isDead then continue end
        if not lightData.light or not lightData.light.Parent then continue end

        local roll = math.random()

        if roll < LIGHT_DEATH_CHANCE then
            killLight(lightData)
        elseif roll < INTENSE_FLICKER_CHANCE then
            intenseFlicker(lightData)
        elseif roll < FLICKER_CHANCE then
            flickerLight(lightData)
        end
    end
end


--[[
================================================================================
SCRIPT 6 OF 10: FlashlightController
TYPE: LocalScript
LOCATION: StarterPlayer > StarterPlayerScripts/FlashlightController
PURPOSE: Flashlight toggle (F key), battery drain/recharge, flicker at low battery
================================================================================
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Config
local BATTERY_DRAIN_RATE = 0.15    -- per frame (~9/sec)
local BATTERY_RECHARGE_RATE = 0.08 -- per frame when off
local FLICKER_THRESHOLD = 20       -- battery % to start flickering
local LIGHT_RANGE = 50
local LIGHT_BRIGHTNESS = 1.5

-- State
local flashlightOn = false
local battery = 100
local spotLight = nil
local flashlightModel = nil

----------------------------------------------------------------------
-- FLASHLIGHT SETUP
----------------------------------------------------------------------

local function createFlashlight()
    local character = player.Character
    if not character then return end

    local head = character:FindFirstChild("Head")
    if not head then return end

    -- Create spotlight attached to head
    spotLight = Instance.new("SpotLight")
    spotLight.Name = "FlashlightBeam"
    spotLight.Angle = 45
    spotLight.Brightness = 0
    spotLight.Color = Color3.fromRGB(255, 255, 230)
    spotLight.Enabled = true
    spotLight.Face = Enum.NormalId.Front
    spotLight.Range = LIGHT_RANGE
    spotLight.Shadows = true
    spotLight.Parent = head

    -- Add a subtle point light for ambient glow
    local pointLight = Instance.new("PointLight")
    pointLight.Name = "FlashlightGlow"
    pointLight.Brightness = 0
    pointLight.Color = Color3.fromRGB(255, 255, 230)
    pointLight.Range = 10
    pointLight.Parent = head

    return spotLight, pointLight
end

local function destroyFlashlight()
    if spotLight then
        spotLight:Destroy()
        spotLight = nil
    end

    local character = player.Character
    if character then
        local head = character:FindFirstChild("Head")
        if head then
            local glow = head:FindFirstChild("FlashlightGlow")
            if glow then glow:Destroy() end
        end
    end
end

----------------------------------------------------------------------
-- TOGGLE & UPDATE
----------------------------------------------------------------------

local function toggleFlashlight()
    if battery <= 0 then
        flashlightOn = false
        return
    end
    flashlightOn = not flashlightOn
end

local function updateFlashlight()
    local character = player.Character
    if not character then return end

    local head = character:FindFirstChild("Head")
    if not head then return end

    if not spotLight or not spotLight.Parent then
        createFlashlight()
    end

    if not spotLight then return end

    local glow = head:FindFirstChild("FlashlightGlow")

    if flashlightOn then
        -- Drain battery
        battery = math.max(0, battery - BATTERY_DRAIN_RATE)
        player:SetAttribute("FlashlightBattery", battery)

        if battery <= 0 then
            flashlightOn = false
        end

        -- Flicker effect at low battery
        local brightness = LIGHT_BRIGHTNESS
        if battery < FLICKER_THRESHOLD then
            if math.random() < 0.1 then
                brightness = 0
            elseif math.random() < 0.2 then
                brightness = LIGHT_BRIGHTNESS * 0.3
            end
        end

        spotLight.Brightness = brightness
        spotLight.Range = LIGHT_RANGE * (battery / 100)
        if glow then
            glow.Brightness = brightness * 0.3
        end
    else
        -- Recharge battery when off
        battery = math.min(100, battery + BATTERY_RECHARGE_RATE)
        player:SetAttribute("FlashlightBattery", battery)

        spotLight.Brightness = 0
        if glow then
            glow.Brightness = 0
        end
    end
end

----------------------------------------------------------------------
-- INPUT
----------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F then
        toggleFlashlight()
    end
end)

----------------------------------------------------------------------
-- CHARACTER SETUP
----------------------------------------------------------------------

player.CharacterAdded:Connect(function(character)
    character:WaitForChild("Head")
    battery = 100
    flashlightOn = false
    task.wait(0.5)
    createFlashlight()
end)

if player.Character then
    task.wait(0.5)
    createFlashlight()
end

----------------------------------------------------------------------
-- UPDATE LOOP
----------------------------------------------------------------------

RunService.RenderStepped:Connect(updateFlashlight)


--[[
================================================================================
SCRIPT 7 OF 10: SprintController
TYPE: LocalScript
LOCATION: StarterPlayer > StarterPlayerScripts/SprintController
PURPOSE: Sprint toggle (Left Shift), stamina, FOV shift, server communication
================================================================================
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Events = ReplicatedStorage:WaitForChild("Events")
local SprintEvent = Events:WaitForChild("PlayerSprinting")

-- Config
local NORMAL_FOV = 70
local SPRINT_FOV = 85
local FOV_TWEEN_TIME = 0.3

-- State
local isSprinting = false
local shiftHeld = false

----------------------------------------------------------------------
-- FOV TWEEN
----------------------------------------------------------------------

local function tweenFOV(targetFOV)
    local tweenInfo = TweenInfo.new(FOV_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(camera, tweenInfo, {FieldOfView = targetFOV})
    tween:Play()
end

----------------------------------------------------------------------
-- SPRINT LOGIC
----------------------------------------------------------------------

local function startSprint()
    local stamina = player:GetAttribute("Stamina") or 0
    if stamina <= 5 then return end

    isSprinting = true
    player:SetAttribute("IsSprinting", true)
    SprintEvent:FireServer(true)
    tweenFOV(SPRINT_FOV)
end

local function stopSprint()
    isSprinting = false
    player:SetAttribute("IsSprinting", false)
    SprintEvent:FireServer(false)
    tweenFOV(NORMAL_FOV)
end

----------------------------------------------------------------------
-- INPUT
----------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.LeftShift then
        shiftHeld = true
        startSprint()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        shiftHeld = false
        stopSprint()
    end
end)

----------------------------------------------------------------------
-- UPDATE LOOP (auto-stop sprint when stamina runs out)
----------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
    if isSprinting then
        local stamina = player:GetAttribute("Stamina") or 0
        if stamina <= 0 then
            stopSprint()
        end
    end

    -- Resume sprinting if shift is still held and stamina recovered
    if shiftHeld and not isSprinting then
        local stamina = player:GetAttribute("Stamina") or 0
        if stamina > 20 then
            startSprint()
        end
    end
end)


--[[
================================================================================
SCRIPT 8 OF 10: HorrorUI
TYPE: LocalScript
LOCATION: StarterPlayer > StarterPlayerScripts/HorrorUI
PURPOSE: Complete UI - stamina bar, battery, keycards, objectives, jumpscares,
         death screen, heartbeat vignette, screen shake
================================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events = ReplicatedStorage:WaitForChild("Events")
local JumpscareEvent = Events:WaitForChild("Jumpscare")
local ObjectiveEvent = Events:WaitForChild("UpdateObjective")
local GameStateEvent = Events:WaitForChild("GameState")
local HeartbeatEvent = Events:WaitForChild("Heartbeat")
local ScareEvent = Events:WaitForChild("ScareEvent")

----------------------------------------------------------------------
-- CREATE UI
----------------------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HorrorUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Dark vignette overlay (always present for atmosphere)
local vignette = Instance.new("ImageLabel")
vignette.Name = "Vignette"
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.Position = UDim2.new(0, 0, 0, 0)
vignette.BackgroundColor3 = Color3.new(0, 0, 0)
vignette.BackgroundTransparency = 1
vignette.Image = "" -- You can add a vignette texture here
vignette.ImageTransparency = 0.3
vignette.ZIndex = 1
vignette.Parent = screenGui

-- Heartbeat vignette (red pulse when monster is near)
local heartbeatOverlay = Instance.new("Frame")
heartbeatOverlay.Name = "HeartbeatOverlay"
heartbeatOverlay.Size = UDim2.new(1, 0, 1, 0)
heartbeatOverlay.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
heartbeatOverlay.BackgroundTransparency = 1
heartbeatOverlay.ZIndex = 2
heartbeatOverlay.Parent = screenGui

-- Jumpscare overlay (fullscreen flash)
local jumpscareFrame = Instance.new("ImageLabel")
jumpscareFrame.Name = "JumpscareOverlay"
jumpscareFrame.Size = UDim2.new(1, 0, 1, 0)
jumpscareFrame.BackgroundColor3 = Color3.new(0, 0, 0)
jumpscareFrame.BackgroundTransparency = 1
jumpscareFrame.ImageTransparency = 1
jumpscareFrame.ZIndex = 100
jumpscareFrame.Parent = screenGui

-- Stamina bar container
local staminaContainer = Instance.new("Frame")
staminaContainer.Name = "StaminaContainer"
staminaContainer.Size = UDim2.new(0.2, 0, 0.015, 0)
staminaContainer.Position = UDim2.new(0.4, 0, 0.93, 0)
staminaContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
staminaContainer.BorderSizePixel = 0
staminaContainer.ZIndex = 10
staminaContainer.Parent = screenGui

local staminaCorner = Instance.new("UICorner")
staminaCorner.CornerRadius = UDim.new(1, 0)
staminaCorner.Parent = staminaContainer

local staminaBar = Instance.new("Frame")
staminaBar.Name = "StaminaFill"
staminaBar.Size = UDim2.new(1, 0, 1, 0)
staminaBar.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
staminaBar.BorderSizePixel = 0
staminaBar.ZIndex = 11
staminaBar.Parent = staminaContainer

local staminaFillCorner = Instance.new("UICorner")
staminaFillCorner.CornerRadius = UDim.new(1, 0)
staminaFillCorner.Parent = staminaBar

local staminaLabel = Instance.new("TextLabel")
staminaLabel.Name = "StaminaLabel"
staminaLabel.Size = UDim2.new(1, 0, 0, 20)
staminaLabel.Position = UDim2.new(0, 0, -1.5, 0)
staminaLabel.BackgroundTransparency = 1
staminaLabel.Text = "STAMINA"
staminaLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
staminaLabel.TextSize = 12
staminaLabel.Font = Enum.Font.GothamBold
staminaLabel.ZIndex = 10
staminaLabel.Parent = staminaContainer

-- Battery indicator
local batteryFrame = Instance.new("Frame")
batteryFrame.Name = "BatteryFrame"
batteryFrame.Size = UDim2.new(0.08, 0, 0.03, 0)
batteryFrame.Position = UDim2.new(0.88, 0, 0.92, 0)
batteryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
batteryFrame.BorderSizePixel = 0
batteryFrame.ZIndex = 10
batteryFrame.Parent = screenGui

local batteryCorner = Instance.new("UICorner")
batteryCorner.CornerRadius = UDim.new(0.3, 0)
batteryCorner.Parent = batteryFrame

local batteryFill = Instance.new("Frame")
batteryFill.Name = "BatteryFill"
batteryFill.Size = UDim2.new(1, 0, 1, 0)
batteryFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
batteryFill.BorderSizePixel = 0
batteryFill.ZIndex = 11
batteryFill.Parent = batteryFrame

local batteryFillCorner = Instance.new("UICorner")
batteryFillCorner.CornerRadius = UDim.new(0.3, 0)
batteryFillCorner.Parent = batteryFill

local batteryLabel = Instance.new("TextLabel")
batteryLabel.Name = "BatteryLabel"
batteryLabel.Size = UDim2.new(1, 0, 1, 0)
batteryLabel.BackgroundTransparency = 1
batteryLabel.Text = "BATTERY"
batteryLabel.TextColor3 = Color3.new(1, 1, 1)
batteryLabel.TextSize = 11
batteryLabel.Font = Enum.Font.GothamBold
batteryLabel.ZIndex = 12
batteryLabel.Parent = batteryFrame

-- Keycard counter
local keycardLabel = Instance.new("TextLabel")
keycardLabel.Name = "KeycardCounter"
keycardLabel.Size = UDim2.new(0.15, 0, 0.04, 0)
keycardLabel.Position = UDim2.new(0.84, 0, 0.03, 0)
keycardLabel.BackgroundTransparency = 1
keycardLabel.Text = "KEYCARDS: 0/3"
keycardLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
keycardLabel.TextSize = 18
keycardLabel.Font = Enum.Font.GothamBold
keycardLabel.TextXAlignment = Enum.TextXAlignment.Right
keycardLabel.ZIndex = 10
keycardLabel.Parent = screenGui

-- Objective text
local objectiveLabel = Instance.new("TextLabel")
objectiveLabel.Name = "ObjectiveText"
objectiveLabel.Size = UDim2.new(0.6, 0, 0.05, 0)
objectiveLabel.Position = UDim2.new(0.2, 0, 0.05, 0)
objectiveLabel.BackgroundTransparency = 1
objectiveLabel.Text = ""
objectiveLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
objectiveLabel.TextSize = 20
objectiveLabel.Font = Enum.Font.GothamBold
objectiveLabel.TextTransparency = 0
objectiveLabel.ZIndex = 10
objectiveLabel.Parent = screenGui

-- Death screen
local deathScreen = Instance.new("Frame")
deathScreen.Name = "DeathScreen"
deathScreen.Size = UDim2.new(1, 0, 1, 0)
deathScreen.BackgroundColor3 = Color3.new(0, 0, 0)
deathScreen.BackgroundTransparency = 1
deathScreen.ZIndex = 200
deathScreen.Visible = false
deathScreen.Parent = screenGui

local deathText = Instance.new("TextLabel")
deathText.Size = UDim2.new(1, 0, 0.3, 0)
deathText.Position = UDim2.new(0, 0, 0.3, 0)
deathText.BackgroundTransparency = 1
deathText.Text = "YOU DIED"
deathText.TextColor3 = Color3.fromRGB(200, 0, 0)
deathText.TextSize = 72
deathText.Font = Enum.Font.GothamBlack
deathText.ZIndex = 201
deathText.Parent = deathScreen

local restartButton = Instance.new("TextButton")
restartButton.Size = UDim2.new(0.2, 0, 0.06, 0)
restartButton.Position = UDim2.new(0.4, 0, 0.65, 0)
restartButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
restartButton.Text = "RESPAWN"
restartButton.TextColor3 = Color3.new(1, 1, 1)
restartButton.TextSize = 24
restartButton.Font = Enum.Font.GothamBold
restartButton.ZIndex = 201
restartButton.Parent = deathScreen

local restartCorner = Instance.new("UICorner")
restartCorner.CornerRadius = UDim.new(0, 8)
restartCorner.Parent = restartButton

restartButton.MouseButton1Click:Connect(function()
    deathScreen.Visible = false
    player:LoadCharacter()
end)

----------------------------------------------------------------------
-- UI UPDATE LOOP
----------------------------------------------------------------------

RunService.RenderStepped:Connect(function()
    -- Update stamina bar
    local stamina = player:GetAttribute("Stamina") or 100
    local maxStamina = player:GetAttribute("MaxStamina") or 100
    local ratio = stamina / maxStamina

    staminaBar.Size = UDim2.new(ratio, 0, 1, 0)

    if ratio < 0.3 then
        staminaBar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    elseif ratio < 0.6 then
        staminaBar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    else
        staminaBar.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
    end

    -- Update battery
    local battery = player:GetAttribute("FlashlightBattery") or 100
    local batteryRatio = battery / 100
    batteryFill.Size = UDim2.new(batteryRatio, 0, 1, 0)

    if batteryRatio < 0.2 then
        batteryFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    elseif batteryRatio < 0.5 then
        batteryFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    else
        batteryFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    end
end)

----------------------------------------------------------------------
-- REMOTE EVENT HANDLERS
----------------------------------------------------------------------

-- Objective updates
ObjectiveEvent.OnClientEvent:Connect(function(text)
    objectiveLabel.Text = text
    objectiveLabel.TextTransparency = 0

    -- Update keycard counter if applicable
    local keycardMatch = string.match(text, "Keycards: (%d+/%d+)")
    if keycardMatch then
        keycardLabel.Text = "KEYCARDS: " .. keycardMatch
    end

    -- Fade out objective after 5 seconds
    task.delay(5, function()
        local tween = TweenService:Create(objectiveLabel, TweenInfo.new(2), {TextTransparency = 0.5})
        tween:Play()
    end)
end)

-- Jumpscare
JumpscareEvent.OnClientEvent:Connect(function(scareType)
    if scareType == "death" then
        -- Full death jumpscare
        jumpscareFrame.BackgroundTransparency = 0
        jumpscareFrame.ImageTransparency = 0

        -- Play jumpscare sound
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://9114219308" -- Loud scare stinger
        sound.Volume = 2
        sound.Parent = playerGui
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)

        -- Screen shake
        task.spawn(function()
            local cam = workspace.CurrentCamera
            for _ = 1, 20 do
                local offset = CFrame.Angles(
                    math.rad(math.random(-5, 5)),
                    math.rad(math.random(-5, 5)),
                    math.rad(math.random(-2, 2))
                )
                cam.CFrame = cam.CFrame * offset
                task.wait(0.03)
            end
        end)

        task.wait(1.5)
        jumpscareFrame.BackgroundTransparency = 1
        jumpscareFrame.ImageTransparency = 1

        -- Show death screen
        deathScreen.Visible = true
        deathScreen.BackgroundTransparency = 0.3

    elseif scareType == "keycard" then
        -- Brief scare flash when picking up keycard
        jumpscareFrame.BackgroundTransparency = 0
        jumpscareFrame.BackgroundColor3 = Color3.new(1, 1, 1)

        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://9114219308"
        sound.Volume = 1
        sound.Parent = playerGui
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)

        task.wait(0.1)
        local tween = TweenService:Create(jumpscareFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
        tween:Play()
        jumpscareFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    end
end)

-- Heartbeat effect (monster nearby)
local heartbeatActive = false
local heartbeatSound = Instance.new("Sound")
heartbeatSound.SoundId = "rbxassetid://9120250792" -- Heartbeat sound
heartbeatSound.Volume = 0.8
heartbeatSound.Looped = true
heartbeatSound.Parent = playerGui

HeartbeatEvent.OnClientEvent:Connect(function(active)
    heartbeatActive = active

    if active then
        if not heartbeatSound.Playing then
            heartbeatSound:Play()
        end

        -- Pulse red vignette
        task.spawn(function()
            while heartbeatActive do
                local fadeIn = TweenService:Create(heartbeatOverlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.7})
                fadeIn:Play()
                fadeIn.Completed:Wait()
                local fadeOut = TweenService:Create(heartbeatOverlay, TweenInfo.new(0.4), {BackgroundTransparency = 1})
                fadeOut:Play()
                fadeOut.Completed:Wait()
            end
        end)
    else
        heartbeatSound:Stop()
        heartbeatOverlay.BackgroundTransparency = 1
    end
end)

-- Scare events
ScareEvent.OnClientEvent:Connect(function(scareType)
    if scareType == "flicker" then
        -- Screen flicker effect
        task.spawn(function()
            for _ = 1, math.random(3, 6) do
                jumpscareFrame.BackgroundTransparency = 0.5
                task.wait(math.random() * 0.1)
                jumpscareFrame.BackgroundTransparency = 1
                task.wait(math.random() * 0.15)
            end
        end)

    elseif scareType == "sound" then
        local creepySounds = {
            "rbxassetid://9114219308",
            "rbxassetid://1838456612",
            "rbxassetid://1843463175",
        }
        local sound = Instance.new("Sound")
        sound.SoundId = creepySounds[math.random(1, #creepySounds)]
        sound.Volume = math.random() * 0.5 + 0.3
        sound.Parent = playerGui
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)

    elseif scareType == "door_slam" then
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://1838456612"
        sound.Volume = 1.5
        sound.Parent = playerGui
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)

        -- Brief screen shake
        task.spawn(function()
            local cam = workspace.CurrentCamera
            for _ = 1, 5 do
                cam.CFrame = cam.CFrame * CFrame.Angles(
                    math.rad(math.random(-2, 2)),
                    math.rad(math.random(-2, 2)),
                    0
                )
                task.wait(0.05)
            end
        end)

    elseif scareType == "whisper" then
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://1843463175"
        sound.Volume = 0.4
        sound.Parent = playerGui
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
    end
end)

-- Game state changes
GameStateEvent.OnClientEvent:Connect(function(state)
    if state == "Won" then
        objectiveLabel.Text = "YOU ESCAPED!"
        objectiveLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
        objectiveLabel.TextSize = 48
        objectiveLabel.TextTransparency = 0
    elseif state == "Lost" then
        objectiveLabel.Text = "GAME OVER"
        objectiveLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        objectiveLabel.TextSize = 48
        objectiveLabel.TextTransparency = 0
    end
end)


--[[
================================================================================
SCRIPT 9 OF 10: AtmosphereController
TYPE: LocalScript
LOCATION: StarterPlayer > StarterPlayerScripts/AtmosphereController
PURPOSE: Horror atmosphere - ambient sounds, fog, camera sway, footsteps, breathing
================================================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

----------------------------------------------------------------------
-- AMBIENT SOUND SETUP
----------------------------------------------------------------------

-- Main ambient drone
local ambientDrone = Instance.new("Sound")
ambientDrone.Name = "AmbientDrone"
ambientDrone.SoundId = "rbxassetid://1837072870" -- Dark ambient drone
ambientDrone.Volume = 0.4
ambientDrone.Looped = true
ambientDrone.Parent = SoundService
ambientDrone:Play()

-- Water dripping
local dripSound = Instance.new("Sound")
dripSound.Name = "WaterDrip"
dripSound.SoundId = "rbxassetid://1838456612" -- Drip/ambient sound
dripSound.Volume = 0.2
dripSound.Looped = true
dripSound.Parent = SoundService
dripSound:Play()

-- Heavy breathing (plays when stamina is low)
local breathingSound = Instance.new("Sound")
breathingSound.Name = "HeavyBreathing"
breathingSound.SoundId = "rbxassetid://9120250792" -- Breathing
breathingSound.Volume = 0
breathingSound.Looped = true
breathingSound.Parent = SoundService
breathingSound:Play()

----------------------------------------------------------------------
-- LIGHTING & ATMOSPHERE
----------------------------------------------------------------------

local function setupAtmosphere()
    -- Color correction for horror feel
    local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not colorCorrection then
        colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Parent = Lighting
    end
    colorCorrection.Brightness = -0.05
    colorCorrection.Contrast = 0.15
    colorCorrection.Saturation = -0.4
    colorCorrection.TintColor = Color3.fromRGB(200, 200, 220)

    -- Bloom for eerie glow
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Parent = Lighting
    end
    bloom.Intensity = 0.3
    bloom.Size = 24
    bloom.Threshold = 0.9

    -- Atmosphere fog
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = 0.35
    atmosphere.Offset = 0
    atmosphere.Color = Color3.fromRGB(20, 20, 30)
    atmosphere.Decay = Color3.fromRGB(30, 25, 40)
    atmosphere.Glare = 0
    atmosphere.Haze = 5

    -- Depth of field for focus effect
    local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
    if not dof then
        dof = Instance.new("DepthOfFieldEffect")
        dof.Parent = Lighting
    end
    dof.FarIntensity = 0.15
    dof.FocusDistance = 30
    dof.InFocusRadius = 20
    dof.NearIntensity = 0
end

----------------------------------------------------------------------
-- CAMERA SWAY (subtle unease)
----------------------------------------------------------------------

local swayTime = 0
local SWAY_SPEED = 0.5
local SWAY_AMOUNT = 0.1 -- degrees

local function updateCameraSway(dt)
    swayTime = swayTime + dt

    local swayX = math.sin(swayTime * SWAY_SPEED) * SWAY_AMOUNT
    local swayY = math.cos(swayTime * SWAY_SPEED * 0.7) * SWAY_AMOUNT * 0.5

    camera.CFrame = camera.CFrame * CFrame.Angles(
        math.rad(swayX),
        math.rad(swayY),
        0
    )
end

----------------------------------------------------------------------
-- BREATHING SOUND (stamina-based)
----------------------------------------------------------------------

local function updateBreathing()
    local stamina = player:GetAttribute("Stamina") or 100
    local maxStamina = player:GetAttribute("MaxStamina") or 100
    local ratio = stamina / maxStamina

    if ratio < 0.4 then
        local volume = (1 - ratio / 0.4) * 0.6
        breathingSound.Volume = volume
    else
        breathingSound.Volume = 0
    end
end

----------------------------------------------------------------------
-- FOOTSTEP SOUNDS
----------------------------------------------------------------------

local lastFootstepTime = 0
local FOOTSTEP_INTERVAL = 0.45
local SPRINT_FOOTSTEP_INTERVAL = 0.3

local function playFootstep()
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.MoveDirection.Magnitude < 0.1 then return end

    local now = tick()
    local interval = player:GetAttribute("IsSprinting") and SPRINT_FOOTSTEP_INTERVAL or FOOTSTEP_INTERVAL

    if now - lastFootstepTime < interval then return end
    lastFootstepTime = now

    -- Play footstep
    local footstep = Instance.new("Sound")
    footstep.SoundId = "rbxassetid://9114219308" -- Generic footstep
    footstep.Volume = player:GetAttribute("IsSprinting") and 0.5 or 0.25
    footstep.PlaybackSpeed = 0.8 + math.random() * 0.4
    footstep.Parent = character:FindFirstChild("HumanoidRootPart")
    footstep:Play()
    footstep.Ended:Connect(function()
        footstep:Destroy()
    end)
end

----------------------------------------------------------------------
-- RANDOM AMBIENT EVENTS
----------------------------------------------------------------------

local function ambientEventLoop()
    while true do
        task.wait(math.random(15, 45))

        -- Random distant sound
        local sounds = {
            "rbxassetid://1838456612",  -- Metal creak
            "rbxassetid://1843463175",  -- Distant noise
            "rbxassetid://1837072870",  -- Low rumble
        }

        local sound = Instance.new("Sound")
        sound.SoundId = sounds[math.random(1, #sounds)]
        sound.Volume = math.random() * 0.3 + 0.1
        sound.PlaybackSpeed = 0.7 + math.random() * 0.6
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function() sound:Destroy() end)
    end
end

----------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------

setupAtmosphere()
task.spawn(ambientEventLoop)

RunService.RenderStepped:Connect(function(dt)
    updateCameraSway(dt)
    updateBreathing()
    playFootstep()
end)


--[[
================================================================================
SCRIPT 10 OF 10: HidingController
TYPE: LocalScript
LOCATION: StarterPlayer > StarterPlayerScripts/HidingController
PURPOSE: Hiding in lockers/desks, camera transitions, exit mechanics
================================================================================
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Events = ReplicatedStorage:WaitForChild("Events")
local HideEvent = Events:WaitForChild("PlayerHiding")

-- State
local isHiding = false
local currentHidingSpot = nil

----------------------------------------------------------------------
-- HIDING SPOT SETUP
----------------------------------------------------------------------

local function setupHidingSpots()
    local hidingFolder = workspace:FindFirstChild("HidingSpots")
    if not hidingFolder then return end

    for _, spot in ipairs(hidingFolder:GetChildren()) do
        -- Create proximity prompt for each hiding spot
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Hide"
        prompt.ObjectText = spot.Name
        prompt.MaxActivationDistance = 8
        prompt.HoldDuration = 0.3
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.Parent = spot

        prompt.Triggered:Connect(function(playerWhoTriggered)
            if playerWhoTriggered ~= player then return end

            if isHiding then
                -- Exit hiding spot
                exitHidingSpot()
            else
                -- Enter hiding spot
                enterHidingSpot(spot)
            end
        end)
    end
end

----------------------------------------------------------------------
-- ENTER / EXIT HIDING
----------------------------------------------------------------------

local function enterHidingSpot(spot)
    if isHiding then return end

    isHiding = true
    currentHidingSpot = spot
    player:SetAttribute("IsHiding", true)
    HideEvent:FireServer(true)

    -- Move camera inside the hiding spot
    local hideCam = spot:FindFirstChild("CameraPosition")
    if hideCam then
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        camera.CameraType = Enum.CameraType.Scriptable

        local tween = TweenService:Create(camera, tweenInfo, {
            CFrame = hideCam.CFrame
        })
        tween:Play()
    end

    -- Update prompt text
    local prompt = spot:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt.ActionText = "Exit"
    end

    -- Add dark overlay to simulate being inside
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.Anchored = true
    end
end

local function exitHidingSpot()
    if not isHiding then return end

    isHiding = false
    player:SetAttribute("IsHiding", false)
    HideEvent:FireServer(false)

    -- Reset camera
    camera.CameraType = Enum.CameraType.Custom

    -- Update prompt text
    if currentHidingSpot then
        local prompt = currentHidingSpot:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            prompt.ActionText = "Hide"
        end
    end

    -- Unanchor character
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.Anchored = false
    end

    currentHidingSpot = nil
end

----------------------------------------------------------------------
-- KEYBIND TO EXIT (also E key)
----------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.E and isHiding then
        exitHidingSpot()
    end
end)

----------------------------------------------------------------------
-- SETUP ON CHARACTER LOAD
----------------------------------------------------------------------

player.CharacterAdded:Connect(function()
    isHiding = false
    currentHidingSpot = nil
    task.wait(1)
    setupHidingSpots()
end)

if player.Character then
    task.wait(1)
    setupHidingSpots()
end


--[[
================================================================================
    END OF ALL SCRIPTS
    
    Remember: Each section above is a SEPARATE script!
    Copy them individually into Roblox Studio at the locations shown.
    
    Have fun scaring your friends!
================================================================================
]]
