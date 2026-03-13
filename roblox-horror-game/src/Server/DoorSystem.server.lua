--[[
    DoorSystem (ServerScript)
    Location: ServerScriptService/DoorSystem

    Handles:
    - Interactive doors with proximity prompts
    - Doors that require keycards
    - Door open/close animations via TweenService
    - Creaking door sounds
    - Auto-close after delay
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
