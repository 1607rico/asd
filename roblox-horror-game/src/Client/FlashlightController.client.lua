--[[
    FlashlightController (LocalScript)
    Location: StarterPlayerScripts/FlashlightController

    Handles:
    - Flashlight toggle (F key or click)
    - Battery drain and recharge
    - Light beam visual
    - Flashlight flicker at low battery
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
