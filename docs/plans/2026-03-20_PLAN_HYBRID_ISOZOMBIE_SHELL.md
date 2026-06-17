# Hybrid IsoZombie Shell Plan - 2026-03-20

## Goal

Keep the live in-world carrier as `IsoZombie`, but reuse safe human-facing data shaping from the older `IsoPlayer` path where that shaping is still useful.

## Safe borrowing path

The practical split is:

- shell / world presence:
  - keep `IsoZombie` as the visible runtime shell
  - keep carrier lifecycle, recovery, and retirement on the zombie path
- canonical identity and safe state:
  - continue sourcing identity, outfit choice, traits, stats, and inventory intent from the NPC record in `ModData`
  - treat `SurvivorDesc` creation and outfit seeding as reusable preparation logic, not as proof that the live shell should become an `IsoPlayer`
- appearance shaping:
  - reuse descriptor-building rules from `ActorFactory.buildDescriptor(...)`
  - reuse human-visual and outfit selection knowledge from the old `IsoPlayer` presentation path as a source of "what the NPC should look like"
  - stamp that source metadata onto the shell so tests can confirm which source won

## Good candidates to borrow

- `SurvivorDesc` naming, gender, profession, and outfit seeding
- any stable record-to-descriptor mapping that does not require player-only runtime state
- selected canonical stats that already exist in record data:
  - health
  - high-level inventory/loadout intent
  - relationship policy summary
- debug metadata that explains:
  - shell visual source
  - descriptor source
  - safe state source
  - current relation policy

## Probably unsafe to borrow directly

- true player combat semantics
- player-only state machine assumptions
- input-driven action queues
- hotbar, UI, and local-player ownership assumptions
- save/load behavior that expects a real `IsoPlayer`
- any logic whose correctness depends on "this actor is the player" rather than "this actor is a managed NPC"

## Conservative experiment sequence

1. Keep `IsoZombie` spawn/sync/retire unchanged as the carrier.
2. Build or reuse `SurvivorDesc` only as a shaping artifact from the NPC record.
3. Copy only safe appearance decisions into shell-facing metadata first.
4. If a later engine-safe hook is found, apply individual appearance fragments in isolation:
   - descriptor-backed identity
   - outfit choice
   - human visual fragments
5. Reject any step that starts depending on player-only combat or control state.

## Current groundwork in this pass

- shared hybrid-source metadata is now stamped on both carrier paths
- the `IsoZombie` shell exposes a terse hybrid summary line when that source mix changes
- this keeps the current carrier experiment honest: the shell is still `IsoZombie`, while the borrowed data remains clearly labeled as record/descriptor input
