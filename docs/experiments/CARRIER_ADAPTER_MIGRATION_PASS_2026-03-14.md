# Carrier Adapter Migration Pass - 2026-03-14

## Scope

First real routing pass from legacy direct actor calls into the new carrier adapter boundary.

This pass does **not** complete the migration.
It moves the main runtime entry points so the project begins talking to the adapter instead of directly to `ActorFactory` / `ActorSync` in several core places.

## What changed

### 1. Embodiment spawn now prefers `CarrierAdapter.spawn()`

`EmbodimentManager.tryEmbody()` no longer assumes direct actor creation first.

It now:

- asks `CarrierAdapter.spawn(record, options)` for the carrier
- receives a runtime handle
- uses the returned actor/handle for the rest of the initial embodiment flow

A legacy fallback still exists if the adapter is unavailable.

### 2. Initial sync now prefers `CarrierAdapter.sync()`

The first post-spawn sync in `tryEmbody()` now routes through:

- `CarrierAdapter.sync(record, handle, { mode = "full" })`

This keeps the upper layer from directly depending on `ActorSync.pushRecordToActor(...)`.

### 3. Cleanup/retire now prefers `CarrierAdapter.retire()`

`EmbodimentManager.canonicalCleanup()` now prefers retiring actors through the adapter.

This means the higher-level cleanup path is beginning to depend on the carrier boundary rather than on a specific actor implementation.

### 4. Deferred cleanup finalization can now retire through the adapter

When deferred cleanup reaches the finalization stage, the manager can now retire through the adapter when appropriate.

### 5. EventAdapter post-create sync now prefers the adapter

The post-create hook path in `90_LWN_EventAdapter.lua` now attempts adapter-based sync first.

If no registered carrier handle exists yet, it creates an ephemeral handle so the sync still goes through the adapter path.

### 6. Debug wipe fallback now prefers adapter retire

The debug wipe path in `92_LWN_DebugTools.lua` now prefers carrier retirement through the adapter as well.

## What did NOT change yet

This is still a bridge pass.

Not fully migrated yet:

- all direct `registerActor()` / legacy registry assumptions still exist
- legacy `ActorFactory` remains the real implementation behind the current `isoplayer` carrier
- direct actor-centric logic still exists in some lifecycle paths
- no `IsoSurvivor` or `IsoZombie` carrier exists yet

## Why this pass matters

Before this pass, the adapter existed but was mostly structural.
After this pass, core runtime control points now actually route through it.

That makes the next step much safer:

- migrating more logic out of `ActorFactory`
- introducing new carriers without rewriting every upper layer again

## Validated files

- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

## Validation performed

```bash
./scripts/validate-wsl.sh
luac -p 42/media/lua/client/90_LWN_EventAdapter.lua
luac -p 42/media/lua/client/92_LWN_DebugTools.lua
```

## Recommended next step

The next clean migration step should be:

1. reduce direct `registerActor()` assumptions further
2. move more actor-specific behavior behind carrier implementations
3. add the first real alternative carrier spike (`IsoSurvivor` first)
