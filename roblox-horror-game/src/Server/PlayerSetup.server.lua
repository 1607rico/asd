--[[
    PlayerSetup (ServerScript)
    Location: ServerScriptService/PlayerSetup

    Handles:
    - Giving players a flashlight tool on spawn
    - Setting up player attributes (stamina, keycards)
    - Sprint noise detection for monster
    - Hiding mechanic
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
