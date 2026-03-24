# Initial Humanization Split Implementation

Date: 2026-03-24
Branch: `spike/isozombie`
Status: implemented, needs in-game validation

## What changed

This pass introduces the first real structural split between:

1. **initial humanization**
2. **maintenance / reassertion**

The goal is to stop treating spawn-time and sync-time appearance work as the same operation.

---

## New runtime component

### `42/media/lua/client/37_LWN_ShellHumanizer.lua`

New module responsibilities:

- owns `record.embodiment.illusion`
- exposes:
  - `applyInitial(record, actor, options)`
  - `maintain(record, actor, options)`
  - `hasInitialApplied(record, actor)`
  - `getIllusionState(record)`
- stamps shell-side telemetry for:
  - initial application status/time/profile/signature
  - last maintenance status/time/profile/mode
  - drift count / last drift reason

Important behavior:

- **spawn path** now prefers a one-time heavy appearance shaping pass
- **sync path** now prefers a lighter maintenance path
- maintenance can still escalate into a full reapply when the appearance signature is missing or the shell appears uninitialized

---

## Carrier changes

### `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

Main change:

- old `runAppearancePass(...)` orchestration is replaced by `runHumanizationPass(...)`

New flow:

### Spawn

- spawn shell
- assess runtime readiness
- run `ShellHumanizer.applyInitial(...)`
- stamp relation / illusion / shell flags

### Sync

- assess runtime readiness
- run `ShellHumanizer.maintain(...)`
- stamp relation / illusion / shell flags
- update runtime metadata with maintenance mode/profile

Additional metadata now surfaces on the actor modData:

- `LWN_HumanizationProfile`
- `LWN_HumanizationInitialApplied`
- `LWN_HumanizationInitialAt`
- `LWN_HumanizationInitialSignature`
- `LWN_HumanizationMaintenanceAt`
- `LWN_HumanizationMaintenanceMode`
- `LWN_HumanizationDriftCount`

---

## Schema changes

### `42/media/lua/shared/01_LWN_Schema.lua`

Added default record shape for:

- `record.embodiment.illusion`

Tracked fields:

- `initialApplied`
- `initialAppliedAt`
- `initialSource`
- `initialProfile`
- `initialAppearanceSignature`
- `lastMaintenanceAt`
- `lastMaintenanceSource`
- `lastMaintenanceProfile`
- `lastKnownAppearanceSignature`
- `lastMaintenanceMode`
- `driftCount`
- `lastDriftAt`
- `lastDriftReason`

---

## ActorFactory change

### `42/media/lua/client/23_LWN_ActorFactory.lua`

Exported:

- `Factory.refreshActorPresentation`

Reason:

- `ShellHumanizer.maintain(...)` needs a safe, lower-level presentation refresh without always going through a full shape-and-bridge pass

---

## Debug/testing changes

### `42/media/lua/client/92_LWN_DebugTools.lua`

Expanded debug output now shows:

- whether initial humanization applied
- active humanization profile
- maintenance mode
- drift count
- record-side illusion snapshot

This should make testing much faster because we can now answer:

- did the shell get initial humanization at spawn time?
- is sync doing light maintenance or full reapply?
- is the shell drifting away from its initial signature?

---

## Recommended in-game validation order

### 1. Fresh spawn validation

- spawn exactly one debug `IsoZombie` NPC
- immediately dump nearest NPC summary
- verify:
  - `initialApplied=true`
  - `initialProfile` matches relationship policy
  - `initialAppearanceSignature` is populated
  - `maintenanceMode` is still nil or empty before the first maintenance pass

### 2. First-sync validation

- wait for first normal sync/tick maintenance
- dump nearest NPC summary again
- verify:
  - `initialApplied` remains true
  - `maintenanceAt` is now populated
  - `maintenanceMode` is usually `maintenance_light`
  - drift count does not immediately explode

### 3. Profile transition validation

- force `friendly`
- force `neutral`
- force `hostile`
- after each state change, sync and dump summary
- verify:
  - `humanizationProfile` changes with relation state
  - initial state remains preserved
  - maintenance keeps updating without wiping initial metadata

### 4. Drift validation

- move away / return / let the shell repath
- dump summary repeatedly
- verify whether:
  - `lastKnownAppearanceSignature` remains stable
  - drift only increments when the signature actually changes

### 5. Presentation ceiling validation

Even if initial humanization succeeds, still check whether:

- presentation role remains `reanimated_zombie`
- body skin remains zombie-coded
- hostile still reads like managed zombie rather than human attacker

That is expected to remain partially unresolved after this pass.
This implementation is about **timing and structure**, not final illusion completion.

---

## What this implementation does NOT solve yet

This is intentionally the first structural step, not the full Bandits-style stack.

Still missing / next likely work:

1. `ShellProfiles` as a first-class module
2. selective audio suppression / replacement
3. hostile-specific shell action choreography
4. shell equipment / hand / attachment orchestration

---

## Strategic verdict

This was the correct first large change.

It aligns the runtime with the strongest evidence from the March 21 docs:

- heavy humanization should happen once, intentionally, at shell birth
- maintenance should preserve and repair the illusion rather than recreate it every time
