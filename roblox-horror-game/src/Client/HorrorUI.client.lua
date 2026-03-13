--[[
    HorrorUI (LocalScript)
    Location: StarterPlayerScripts/HorrorUI

    Creates and manages all horror game UI:
    - Stamina bar
    - Battery indicator
    - Keycard counter
    - Objective text
    - Jumpscare overlay
    - Death screen
    - Heartbeat vignette effect
    - Screen shake
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
