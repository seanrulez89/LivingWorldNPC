# Managed IsoZombie Independence

Date: 2026-06-16

## Decision

LivingWorldNPC no longer requires or runs through Bandits2 for the default
companion path. The active companion carrier is now LWN's own managed
`IsoZombie` implementation in `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`.

Bandits-related documents remain historical reference only. They are not
permission to copy third-party code or assets, and they are not current runtime
requirements.

## Current Runtime Boundary

- Canonical state remains in the LWN NPC record.
- `LWN.Combat` decides whether a companion may engage a threat.
- `ActionRuntime` owns the intent queue.
- `CarrierAdapter` delegates execution to the active carrier.
- The `isozombie` carrier owns spawn, sync, follow, wait, move-to, melee attack,
  audio suppression, friendly-hit suppression, health sync, death cleanup, and
  shell debug state.
- Actor `ModData` is only a runtime bridge and identification surface.

## Removed Runtime Dependency

- `42/mod.info` no longer declares `require=\Bandits2`.
- The former Bandits carrier and integration files are removed from the load
  path.
- Dedicated `42/bandits` data files are removed.
- Default test/squad spawning now requests carrier kind `isozombie`.

## Item Rule

Normal gameplay paths must not create virtual weapons or clothing for NPCs.
Transfer and equip requests should move an existing player inventory item or
world item into the NPC actor inventory, then synchronize hand slots, worn item
visuals, and the canonical inventory summary.

Debug-only virtual grants must stay explicitly marked as test/debug behavior.

## Validation Focus

Next manual tests should verify:

1. The game loads with Bandits2 disabled.
2. Aggressive and passive companions can be spawned up to the three-person test
   squad limit.
3. Follow, wait, and right-click move still work through `isozombie`.
4. Aggressive companions can attack ordinary zombies without external task
   executors.
5. Passive companions ignore unrelated zombies but join team defense.
6. Player-friendly attacks are suppressed, while ordinary zombie damage still
   reduces health and can cause death.
7. Item transfer/equip uses real items and shows equipment visually.
8. Logs show `isozombie`, `CarrierIsoZombie`, `ShellProbe`, or `ShellVisual`
   names, not a Bandits runtime dependency.
