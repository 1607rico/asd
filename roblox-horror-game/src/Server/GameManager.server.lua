--[[
    GameManager (ServerScript)
    Location: ServerScriptService/GameManager

    Core server-side game loop:
    - Manages game state (Waiting, Playing, Ended)
    - Spawns and manages the monster
    - Tracks keycards collected
    - Handles win/lose conditions
    - Scales difficulty over time
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
