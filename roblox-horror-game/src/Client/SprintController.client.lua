--[[
    SprintController (LocalScript)
    Location: StarterPlayerScripts/SprintController

    Handles:
    - Sprint toggle (Left Shift)
    - Stamina bar UI updates
    - Camera FOV shift when sprinting
    - Sends sprint state to server (for monster detection)
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
