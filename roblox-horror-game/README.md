# The Facility - Roblox Horror Game

A complete, scary survival horror game for Roblox with monster AI, flashlight mechanics, jump scares, an economy of keycards, hiding spots, and atmospheric horror effects.

## Game Overview

You wake up in an abandoned underground research facility. **Subject-7**, a failed experiment, stalks the corridors. Find 3 keycards, unlock the exit, and escape before it finds you.

### Features
- **Monster AI** with patrol, alert, chase, and cooldown states
- **Flashlight system** with battery drain/recharge and flicker effects
- **Sprint & Stamina** system with breathing sounds
- **Hiding spots** (lockers, desks) with camera transitions
- **Keycard puzzle** — find 3 keycards to unlock the exit
- **Interactive doors** with creak sounds and auto-close
- **Jump scares** — screen flashes, loud sounds, screen shake
- **Atmospheric horror** — flickering lights, fog, ambient drones, whispers
- **Dynamic difficulty** — monster gets faster, scares get more frequent
- **Full HUD** — stamina bar, battery indicator, keycard counter, objective text
- **Multiplayer support** (1-4 players)

## Setup in Roblox Studio

### Step 1: Create Remote Events

1. Open Roblox Studio
2. In **ReplicatedStorage**, create a Folder called `Events`
3. Inside `Events`, create these **RemoteEvent** objects:
   - `Jumpscare`
   - `UpdateObjective`
   - `GameState`
   - `Heartbeat`
   - `ScareEvent`
   - `PlayerSprinting`
   - `PlayerHiding`

> **Shortcut:** Copy `src/Shared/EventsSetup.lua` as a ModuleScript in ReplicatedStorage and run `require(game.ReplicatedStorage.EventsSetup)` in the command bar.

### Step 2: Place Server Scripts

Copy these into **ServerScriptService**:
| File | Script Type |
|------|------------|
| `src/Server/GameManager.server.lua` | Script |
| `src/Server/PlayerSetup.server.lua` | Script |
| `src/Server/DoorSystem.server.lua` | Script |
| `src/Server/LightFlicker.server.lua` | Script |

### Step 3: Place Client Scripts

Copy these into **StarterPlayer > StarterPlayerScripts**:
| File | Script Type |
|------|------------|
| `src/Client/FlashlightController.client.lua` | LocalScript |
| `src/Client/SprintController.client.lua` | LocalScript |
| `src/Client/HorrorUI.client.lua` | LocalScript |
| `src/Client/AtmosphereController.client.lua` | LocalScript |
| `src/Client/HidingController.client.lua` | LocalScript |

### Step 4: Build the Map

Create these objects in **Workspace**:

#### Required Objects
| Name | Type | Description |
|------|------|-------------|
| `PlayerSpawn` | SpawnLocation | Where players spawn |
| `ExitDoor` | Model | The exit with a child Part named `ExitZone` |
| `Keycards` | Folder | Contains 3 Parts named `Keycard1`, `Keycard2`, `Keycard3` |
| `MonsterWaypoints` | Folder | Contains Parts marking the monster's patrol route |
| `Doors` | Folder | Contains door Models (each with `Hinge` and `Door` Parts) |
| `HidingSpots` | Folder | Contains Parts/Models (lockers, desks) with optional `CameraPosition` Part inside |

#### Monster Model
1. Create a scary humanoid model (or use a free one from the Toolbox)
2. Name it `Subject7`
3. Ensure it has a `Humanoid` and `HumanoidRootPart`
4. Place it in **ServerStorage** (the GameManager will clone it into the game)

#### Flashlight Tool
1. Create a Tool named `Flashlight`
2. Place it in **ServerStorage** (PlayerSetup will give it to players on spawn)

#### Door Setup
Each door in the `Doors` folder should be a Model containing:
- `Hinge` — A Part that acts as the pivot point
- `Door` — The visible door Part (welded to Hinge)
- Optional: Set attribute `RequiredKeycard` = `"Keycard1"` (etc.) to make it locked

#### Hiding Spot Setup
Each hiding spot in `HidingSpots` should have:
- A visible model (locker, desk, etc.)
- Optional: A Part named `CameraPosition` inside to define the camera view when hiding

### Step 5: Lighting Setup

The AtmosphereController will automatically configure:
- Color Correction (desaturated, dark tint)
- Bloom effect
- Atmosphere fog
- Depth of Field

You can also manually set:
- `Lighting.Brightness` = 0.3
- `Lighting.ClockTime` = 0 (midnight)
- `Lighting.FogEnd` = 150

### Step 6: Add Lights to the Map

Place `PointLight` objects in your facility corridors. The `LightFlicker` script will automatically find all lights in the workspace and make them flicker randomly. Some lights will permanently die over time for extra horror.

## Controls

| Key | Action |
|-----|--------|
| **WASD** | Move |
| **Left Shift** | Sprint (drains stamina) |
| **F** | Toggle flashlight |
| **E** | Interact (doors, hiding spots) |
| **Mouse** | Look around |

## Script Architecture

```
src/
├── Server/
│   ├── GameManager.server.lua    -- Core game loop, monster AI, keycard & exit logic
│   ├── PlayerSetup.server.lua    -- Player attributes, stamina, flashlight tool
│   ├── DoorSystem.server.lua     -- Interactive doors, locked doors, auto-close
│   └── LightFlicker.server.lua   -- Random light flicker & death effects
├── Client/
│   ├── FlashlightController.client.lua  -- Flashlight toggle, battery, beam
│   ├── SprintController.client.lua      -- Sprint, stamina, FOV shift
│   ├── HorrorUI.client.lua             -- All UI (stamina, battery, scares, death)
│   ├── AtmosphereController.client.lua  -- Ambient sounds, fog, camera sway
│   └── HidingController.client.lua      -- Hide in lockers/desks
└── Shared/
    └── EventsSetup.lua           -- Creates all RemoteEvents
```

## Tips for Maximum Scariness

1. **Make corridors narrow and winding** — claustrophobia adds tension
2. **Use dim red/green emergency lights** — avoid bright white
3. **Add blood decals and broken furniture** — environmental storytelling
4. **Place monster waypoints through tight spaces** — forces close encounters
5. **Add vent sounds and distant screams** as ambient Sound objects in the map
6. **Test with friends in the dark** with headphones for best experience

## Sound Asset IDs

Replace the placeholder sound IDs in the scripts with your own or use free ones from the Roblox library. Search for:
- "horror ambient" — background drones
- "heartbeat" — monster proximity
- "jumpscare" — loud stinger sounds
- "door creak" — door interactions
- "footsteps" — walking sounds
- "heavy breathing" — low stamina

## License

MIT — Use freely in your Roblox games!
