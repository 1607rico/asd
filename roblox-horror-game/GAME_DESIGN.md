# The Facility - Horror Game Design Document

## Overview
**Title:** The Facility
**Genre:** Survival Horror / Escape
**Players:** 1-4 (multiplayer supported)
**Playtime:** 10-20 minutes per round

## Story
You wake up in an abandoned underground research facility. The lights flicker. Something went wrong here — experiment logs are scattered, blood stains the walls, and the emergency exit is sealed behind a series of locked doors. Worst of all, you're not alone. **Subject-7**, a failed experiment, stalks the corridors hunting anything that moves. Find the keycards, unlock the exits, and escape before it finds you.

## Map Layout

```
┌─────────────────────────────────────────────────────┐
│                    FACILITY MAP                      │
│                                                      │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐        │
│  │  SPAWN   │───│ HALLWAY  │───│  LAB A   │        │
│  │  ROOM    │   │    1     │   │(Keycard1)│        │
│  └────┬─────┘   └────┬─────┘   └──────────┘        │
│       │              │                               │
│  ┌────┴─────┐   ┌────┴─────┐   ┌──────────┐        │
│  │ STORAGE  │   │ HALLWAY  │───│  LAB B   │        │
│  │  ROOM    │   │    2     │   │(Keycard2)│        │
│  └──────────┘   └────┬─────┘   └──────────┘        │
│                      │                               │
│  ┌──────────┐   ┌────┴─────┐   ┌──────────┐        │
│  │ MONSTER  │───│ CENTRAL  │───│ GENERATOR│        │
│  │  LAIR    │   │   HUB    │   │   ROOM   │        │
│  └──────────┘   └────┬─────┘   └──────────┘        │
│                      │                               │
│  ┌──────────┐   ┌────┴─────┐                        │
│  │ OFFICE   │───│  EXIT    │                        │
│  │(Keycard3)│   │  DOOR    │                        │
│  └──────────┘   └──────────┘                        │
└─────────────────────────────────────────────────────┘
```

## Core Mechanics

### 1. Flashlight System
- Players start with a flashlight (limited battery)
- Battery drains over time, recharges slowly when off
- Essential for navigating dark corridors
- The monster is slightly repelled by light

### 2. Sprint & Stamina
- Players can sprint (Shift key) to run from the monster
- Stamina bar depletes while sprinting, regenerates when walking
- Running makes noise — the monster hears you

### 3. Monster AI (Subject-7)
- **Patrol Mode:** Wanders between waypoints through corridors
- **Alert Mode:** Hears player sprinting/doors opening, investigates
- **Chase Mode:** Spots player, chases at high speed
- **Cooldown:** Loses interest after a while if player hides
- Gets faster as time progresses

### 4. Keycard System
- 3 keycards hidden in Labs A, B, and the Office
- All 3 required to unlock the Exit Door
- Keycards glow faintly to help players find them
- Picking up a keycard triggers a scare event

### 5. Hiding Spots
- Lockers and desks players can hide inside
- Monster cannot detect hidden players (unless it saw them hide)
- Limited hiding time to prevent camping

### 6. Scare Events
- Flickering/dying lights at random intervals
- Distant monster sounds (growling, footsteps, screams)
- Jump scares when picking up keycards or entering certain rooms
- Doors slamming shut behind players
- Objects falling off shelves
- Whispers when near the monster's lair

### 7. Environmental Hazards
- Broken glass on floor (makes noise when walked on)
- Steam vents that obscure vision
- Locked doors that require keycards

## Win / Lose Conditions
- **Win:** Collect all 3 keycards and reach the exit door
- **Lose:** The monster catches you (death screen + jumpscare)
- **Multiplayer:** At least 1 player must escape; dead players spectate

## UI Elements
- Stamina bar (bottom center)
- Battery indicator (bottom right)
- Keycard counter (top right) — shows 0/3, 1/3, etc.
- Objective text (top center)
- Jumpscare overlay (fullscreen, brief flash)
- Death screen with restart option

## Sound Design
- Ambient drone (low frequency, unsettling)
- Heartbeat when monster is nearby
- Footsteps (player + monster, different sounds)
- Metal creaking, water dripping
- Distant screams
- Jump scare stinger (loud, sharp)
- Generator humming in generator room

## Difficulty Scaling
- Monster speed increases every 2 minutes
- Lights flicker more frequently over time
- Flashlight battery drains faster as game progresses
