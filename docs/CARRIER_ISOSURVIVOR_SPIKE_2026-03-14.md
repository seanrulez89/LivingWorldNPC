# Carrier IsoSurvivor Spike - 2026-03-14

## Goal

Create a true proof-of-life carrier spike for `IsoSurvivor`.

This pass is not intended to prove final architecture readiness.
It is only meant to answer:

- can LivingWorldNPC instantiate an `IsoSurvivor` from Lua in this Build 42 runtime?
- if so, does it produce a visible alive world actor?
- can the existing adapter/sync/retire bridge drive it at all?

## Runtime changes

New file:

- `42/media/lua/client/34_LWN_Carrier_IsoSurvivor.lua`

This carrier:

- registers as `LWN.Carriers.isosurvivor`
- builds a descriptor from current record data
- tries multiple constructor/instantiation paths in order
- marks the resulting actor with LWN carrier metadata
- reuses current sync/cleanup infrastructure where possible

## Constructor strategy

Because practical Build 42 Lua examples for `IsoSurvivor` construction are scarce, the spike tries several candidate paths and records which one worked or failed.

Current candidate order:

1. `SurvivorFactory.InstansiateInCell(desc, cell, x, y, z)`
2. `IsoSurvivor.new(desc, cell, x, y, z)`
3. `IsoSurvivor.new(cell, desc, x, y, z)`
4. `IsoSurvivor.new(desc, square)`
5. `IsoSurvivor.new(square, desc)`

If all fail, the constructor errors are reported in the carrier detail/log output.

## Adapter integration

`CarrierAdapter.resolveKind()` now also respects:

- `record.embodiment.preferredCarrierKind`

This allows targeted debug spawn selection without changing the default carrier for all records.

## Debug spawn entry added

New helper:

- `DebugTools.spawnOneNearPlayerIsoSurvivor(player)`

This creates a normal debug NPC record, but sets:

- `record.embodiment.preferredCarrierKind = "isosurvivor"`
- `record.embodiment.carrierKind = "isosurvivor"`

Then it routes through the normal embodiment flow.

The original `DebugTools.spawnOneNearPlayer(player)` remains the `isoplayer` baseline.

## Expected test outcomes

### Success case

- actor is instantiated
- debug message says it spawned via `isosurvivor`
- NPC appears visibly alive in-world
- no immediate create/sync/delete crash

### Partial success

- actor instantiates but is not visibly correct
- adapter logs show which constructor path worked
- useful because it distinguishes constructor viability from rendering viability

### Failure case

- spawn fails and reports constructor failure details
- this still gives a clear answer that `IsoSurvivor` is not trivially usable through the attempted Lua/runtime paths

## Recommended in-game test

Do both:

1. baseline existing debug spawn (`isoplayer`)
2. new `IsoSurvivor` debug spawn

Compare:

- does it spawn?
- is it visible?
- does it remain stable?
- does delete work in non-combat?

## Important scope note

This spike does not yet add a dedicated `IsoSurvivor`-specific presentation pipeline.
It intentionally reuses the current sync/cleanup bridge first, because the first question is whether the carrier can even exist and render at all.
