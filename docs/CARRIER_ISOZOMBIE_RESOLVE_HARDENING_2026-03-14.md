# Carrier IsoZombie Resolve Hardening - 2026-03-14

## Why this pass exists

The first `IsoZombie` spike finally produced a visible in-world actor, but it only stayed visible for a very short time before LivingWorldNPC marked the embodied record as lost and hid/retired it.

This indicated a new problem:

- the spawn path was no longer the primary blocker
- actor continuity / resolve / lost-detection had become the real bottleneck

## What the prior logs showed

The important pattern was:

- `spawn.pending_settle`
- later `resolveEmbodiedActor.repaired_cached` with `hadWorld=false hasWorld=true`
- brief visual presence in-world
- then `onTick.actor_missing`
- then `actor_lost` / hidden cleanup

This strongly suggested that the zombie carrier could become world-valid, but the project's existing actor continuity assumptions were still too human-centric and too aggressive.

## What changed

### 1. Carrier-aware usable actor check in EventAdapter

`resolveEmbodiedActor()` now uses a carrier-aware usability check.

For carrier-managed actors, the system now prefers:

- `CarrierAdapter.isUsable(handle)`

before falling back to older actor-factory runtime-core assumptions.

This matters because `IsoZombie` should not be judged by the same `hasRuntimeCore()` expectations used for human-like actor paths.

### 2. Longer actor-lost grace for `IsoZombie`

The on-tick missing threshold is now carrier-aware.

Current thresholds:

- default carriers: `10` missing ticks
- `IsoZombie`: `40` missing ticks

This gives the zombie carrier more time to settle and remain resolvable without being hidden immediately.

### 3. Recovery from carrier handle when actor resolve temporarily fails

If regular embodied-actor resolution fails, the tick loop now checks the carrier handle directly.

If the carrier handle still has an actor that:

- belongs to the npcId
- still exists in world

then the manager re-registers that actor and restores grace instead of immediately continuing toward actor-lost cleanup.

### 4. Carrier-aware usability in EmbodimentManager helper paths

`Embody.getUsableActorByNpcId()` now also prefers `CarrierAdapter.isUsable(handle)` before relying only on older managed-actor assumptions.

## Intended effect

This pass is trying to preserve an `IsoZombie` carrier long enough to answer the real experimental question:

- can it remain visible and stable as a carrier shell?

Without this pass, the system was likely destroying the experiment too quickly to tell.

## Validation performed

```bash
./scripts/validate-wsl.sh
luac -p 42/media/lua/client/90_LWN_EventAdapter.lua
luac -p 42/media/lua/client/25_LWN_EmbodimentManager.lua
```

## What to watch in the next test

Look for:

- visible zombie remains longer than before
- `onTick.actor_missing_recovered_from_handle`
- fewer immediate `actor_lost` transitions
- whether the actor can stay embodied long enough for more meaningful observation
