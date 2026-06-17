# Carrier Adapter Draft - 2026-03-14

## Purpose

LivingWorldNPC should preserve canonical NPC identity/state while making the embodied world carrier replaceable.

This draft introduces that direction explicitly:

- record/state remains canonical
- carrier remains disposable runtime embodiment
- upper layers should eventually stop depending directly on `IsoPlayer`

## Core rule

**The record is the NPC. The carrier is only the current body.**

## Layers

### 1. Canonical layer
Owns:

- identity
- stats
- loadout intent
- AI state
- target state
- death / cleanup lifecycle

### 2. Carrier adapter layer
Owns:

- choosing carrier kind
- spawning a carrier
- syncing canonical state into a carrier
- retiring a carrier safely
- exposing the current actor/proxy through a common interface

### 3. Carrier implementation layer
Current skeleton carriers:

- `none`
- `isoplayer`

Planned research carriers:

- `isosurvivor`
- `isozombie`

## New files added

- `42/media/lua/client/31_LWN_CarrierAdapter.lua`
- `42/media/lua/client/32_LWN_Carrier_None.lua`
- `42/media/lua/client/33_LWN_Carrier_IsoPlayer.lua`

## Adapter API draft

The adapter currently exposes these core entry points:

- `CarrierAdapter.resolveKind(record, options)`
- `CarrierAdapter.spawn(record, options)`
- `CarrierAdapter.sync(record, handle, options)`
- `CarrierAdapter.retire(record, handle, options)`
- `CarrierAdapter.isUsable(handle)`
- `CarrierAdapter.getActor(handle)`
- `CarrierAdapter.getDebugState(record, handle)`

## Runtime handle shape

A runtime carrier handle is a small, disposable object:

```lua
{
  npcId = "LWN-000001",
  kind = "isoplayer",
  actor = <runtime actor or nil>,
  status = "active",
  spawnedAt = ...,
  lastSyncAt = ...,
  lastRetireAt = ...,
  detail = "...",
  runtime = { ... }
}
```

This must remain runtime-only and easy to discard.

## EmbodimentManager integration added in this pass

`EmbodimentManager` now owns:

- `_carrierHandles`
- `registerCarrierHandle(record, handle)`
- `getCarrierHandle(record)`
- `unregisterCarrierHandle(record, reason)`

For compatibility with the current codebase:

- `registerActor()` now also registers a legacy carrier handle
- `getActor()` first resolves through the carrier adapter if a handle exists
- `unregisterActor()` also clears the carrier handle

This is a bridge step, not the final migration.

## Current carrier skeletons

### `none`
Purpose:

- logic-only safe mode
- no world actor
- allows future simulation-first fallback

### `isoplayer`
Purpose:

- legacy wrapper around the existing `ActorFactory` / `ActorSync` / cleanup path
- isolates the current implementation behind the new adapter boundary

Important:

- this does **not** mean `IsoPlayer` is re-endorsed architecturally
- it is simply wrapped as the legacy carrier so the rest of the repo can stop depending on it directly over time

## What this pass intentionally does NOT do yet

This pass does not fully migrate embodiment orchestration to the adapter.

It does **not yet**:

- replace all direct `ActorFactory.createActor()` call sites with `CarrierAdapter.spawn()`
- replace all direct cleanup paths with `CarrierAdapter.retire()`
- add `IsoSurvivor` or `IsoZombie` carrier implementations

Those belong to the next controlled refactor pass.

## Recommended next refactor step

### 1. Route spawn through the adapter
Move embodiment spawn entry from direct actor creation to:

- `CarrierAdapter.spawn()`

### 2. Route sync through the adapter
Move actor refresh/update entry to:

- `CarrierAdapter.sync()`

### 3. Route cleanup through the adapter
Move debug delete / despawn / cleanup ownership to:

- `CarrierAdapter.retire()`

### 4. Add proof-of-life carriers
After the adapter path is stable:

- add `IsoSurvivor` spike carrier
- add `IsoZombie` spike carrier if needed

## Bottom line

This pass does not solve embodiment.
It creates the boundary needed so embodiment can be changed without rewriting the whole project again.
