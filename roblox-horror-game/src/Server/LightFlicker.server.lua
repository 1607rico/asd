--[[
    LightFlicker (ServerScript)
    Location: ServerScriptService/LightFlicker

    Makes lights in the facility flicker randomly for horror atmosphere.
    - Tags lights with "FlickerLight" attribute
    - Random flicker patterns
    - Some lights permanently die over time
    - Lights near the monster flicker more intensely
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
