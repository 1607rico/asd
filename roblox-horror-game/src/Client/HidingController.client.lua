--[[
    HidingController (LocalScript)
    Location: StarterPlayerScripts/HidingController

    Handles:
    - Detecting hiding spots (lockers, desks, closets)
    - Proximity prompt to hide
    - Camera view change when hiding
    - Exiting hiding spots
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
