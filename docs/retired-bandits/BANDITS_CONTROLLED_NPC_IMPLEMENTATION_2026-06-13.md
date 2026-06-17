# Bandits Controlled NPC Implementation

Date: 2026-06-13
Target: Project Zomboid Build 42.18 single player

## Scope

This iteration makes the Bandits-backed actor the default LWN test carrier and adds the first player-controlled command loop:

- one non-hostile, human-presenting NPC with no weapons or speech
- a unique first and last name stored in the canonical LWN record
- right-click movement to a player-selected world square
- persistent follow mode with a trailing offset
- follow locomotion that switches between walk, run, crouched walk, and crouched run
- a wait command that cancels the active Bandits task and pathfinder
- mitigation for the vanilla player panic and surprise sound emitted when the actor first becomes visible

The LWN record and action intent remain canonical. The Bandit brain, tasks, and `IsoZombie` actor are disposable presentation and locomotion state.

## Player Commands

Right-click an empty world location and open:

`Living NPC Commands -> <NPC name>`

Available commands:

- `Move to this location`: replaces the current intent and walks to the clicked square.
- `Follow me`: continually targets a point 2.25 tiles behind the player.
- `Wait here`: clears the intent queue, Bandits tasks, and pathfinder, then forces the actor stationary.

The NPC interaction menu and radial menu also expose follow and wait commands. Multiple embodied NPCs are listed by their unique names.

## Follow Behavior

Follow mode remains active until replaced or cancelled. It does not complete when the NPC catches up.

- Player walking: NPC uses `Walk`.
- Player running or sprinting: NPC uses `Run`.
- Player sneaking: NPC uses `SneakWalk`.
- Player running or sprinting while sneaking: NPC uses `SneakRun`.
- Separation over 10 tiles: NPC uses `Run` to recover.
- Target point movement of 1.25 tiles or a locomotion style change rebuilds the move task.
- No movement progress for 5 seconds clears the current task and requests a new path.

The target is recomputed from the player's current position and facing direction, so the actor normally remains behind the player instead of occupying the same tile.

## Interaction Foundation

Right-click interaction actions are registered through `LWN.NPCInteraction` instead of being hard-wired directly into the context menu. The initial registry exposes status, talk, and quick-command actions. Future inventory, health, skills, equipment, and relationship views can register additional actions without changing actor detection or the root menu.

`LWN.NPCStatus.snapshot` builds a versioned, structured view of canonical NPC identity, condition, relationship, inventory summary, activity, and embodiment state. The current read-only status window renders that snapshot. A later player-style tabbed character window can therefore replace the renderer without changing the record contract or interaction entry point.

## Spawn Surprise Mitigation

Bandits presents a human model through an `IsoZombie` engine actor. Vanilla `IsoPlayer` visibility code still counts that actor as a zombie before LWN hostility or presentation flags are considered. There is no clean Lua-level flag that makes this carrier stop contributing to the vanilla visible-zombie path.

The mitigation therefore applies a short spawn-only calm window:

- capture the player's panic and surprise timer before the spawn request
- suppress `ZombieSurprisedPlayer`
- prevent spawn-induced panic from rising above the captured value
- synchronize the previous visible-zombie count with the current count
- restore the original surprise timer after one second

This is deliberately narrow. It avoids permanently suppressing legitimate reactions to real zombies, but the Bandits actor can still affect other vanilla systems that only inspect the actor's `IsoZombie` type or visible-zombie counts.

## Identity

New records receive a randomized Project Zomboid survivor name. The allocator checks all existing LWN records and retries to avoid duplicate full names. The fixed Bandits profile is male, so the initial Bandits dummy receives a male name. The full name is copied to:

- `record.identity`
- `brain.fullname`
- actor descriptor fields when available
- actor ModData as `LWN_DisplayName`

## Diagnostics

Console logging includes:

- LWN NPC ID, Bandits correlation key, and Bandit ID
- spawn request, asynchronous binding, and removal
- move attempts, task cycles, destination, and final result
- follow walk-style changes and stalled-path rebuilds
- non-combat state, current task, combat task detection, and active audio
- spawn calm completion with baseline panic and visible-zombie count

## In-Game Verification

1. Run `TEST RESET` and then `TEST 01`.
2. Confirm one named human-presenting NPC appears and does not attack or vocalize.
3. Confirm the initial surprise sound and panic moodle spike are absent or substantially reduced.
4. Right-click a clear square and choose `Living NPC Commands -> <name> -> Move to this location`.
5. Confirm the NPC walks to the selected square and stops.
6. Choose `Follow me`, then walk, sprint, and sneak in turn.
7. Confirm the NPC follows from behind with matching locomotion.
8. Choose `Wait here` and confirm movement stops immediately.
9. Run `TEST RESET` and confirm the actor and Bandits brain/cache entry are removed.

## Validation Performed

- Lua 5.1 syntax validation for all Lua files through `scripts/validate-mac.sh`
- `git diff --check`
- static comparison against Bandits 42.18 `GetMoveTask`, `ZAMove`, `BanditUpdate`, and `ZPCompanion` behavior

Runtime behavior still requires the in-game verification sequence above because Project Zomboid and Bandits engine objects are not available in the standalone Lua validator.
