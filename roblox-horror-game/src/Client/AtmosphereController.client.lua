--[[
    AtmosphereController (LocalScript)
    Location: StarterPlayerScripts/AtmosphereController

    Handles:
    - Ambient horror sounds (background drones, drips, creaks)
    - Dynamic fog
    - Camera effects (slight sway, chromatic aberration feel)
    - Footstep sounds based on material
    - Breathing sounds when stamina is low
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
