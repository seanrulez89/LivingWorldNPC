# Carrier IsoZombie Spike Implementation - 2026-03-14

## Scope

First implementation pass for an `IsoZombie` proof-of-life carrier.

This pass aims only for:

- safe spawn through the carrier adapter
- visible world-actor proof-of-life
- minimal sync
- shallow safe retire
- debug-menu access for in-game testing

## Why this implementation chooses `addZombiesInOutfit(...)`

Instead of guessing at a low-level `IsoZombie.new(...)` constructor path, this spike uses the higher-level world spawn path already seen in reference mods:

- `addZombiesInOutfit(x, y, z, count, outfit, femaleChance, ...)`

Reason:

- it is clearly used in real mods
- it is more likely to produce a world-ready zombie actor than constructor guessing
- the first question is proof-of-life, not perfect semantic control

## New runtime file

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

## Debug entry added

New helper:

- `DebugTools.spawnOneNearPlayerIsoZombie(player)`

New menu item:

- `Debug: Spawn NPC Near Player (IsoZombie Spike)`

## Current behavior

### Spawn

- gets the target square near the player/record anchor
- spawns one zombie using `addZombiesInOutfit(...)`
- takes the first returned zombie from the result list
- tags it with LWN carrier metadata
- performs a runtime readiness check

### Runtime readiness check

Current required conditions:

- actor exists
- `getBodyDamage()` is available
- actor is in world
- square is present
- `isZombie() == true`

If those checks fail, the carrier rejects the actor and retires it shallowly.

### Basic neutralization attempt

The first pass lightly nudges the zombie toward a carrier-shell role by trying:

- `setUseless(true)`
- `setTargetSeenTime(0)`
- `setFakeDead(false)`
- `setCanWalk(false)`
- `setCrawler(false)`
- `setSitAgainstWall(false)`
- `setReanimate(false)`
- `setInvisible(false)`
- `setHealth(1)`

This is intentionally modest and may need revision after live testing.

### Sync

This spike does **not** reuse the full player-centric `ActorSync.pushRecordToActor(...)` pipeline.

It only applies minimal sync:

- runtime readiness re-check
- basic neutralization again
- position nudging toward anchor
- health sync

### Retire

Retire uses a shallow path:

- clear LWN npcId modData
- set invisible
- remove from square/world

This keeps the first spike simple and avoids dragging `IsoZombie` through player-centric cleanup assumptions.

## What to watch in the first in-game test

### Success signs

- no crash during spawn
- visible zombie appears
- logs show `CarrierIsoZombie spawn.ok`
- non-combat delete works safely

### Failure signs

- no actor appears
- runtime readiness rejects the actor
- zombie instantly behaves uncontrollably despite neutralization
- delete becomes unsafe

## Interpretation rules

### If visible + stable

Continue the spike.
Next step would be deeper control neutralization and better mapping between canonical NPC state and zombie shell behavior.

### If visible but behavior is wild

Still useful.
That means the carrier is viable as a world shell, but behavior control needs more work.

### If not visible or not stable

Then `IsoZombie` is much less promising than expected, and logic-first fallback becomes even more important.
