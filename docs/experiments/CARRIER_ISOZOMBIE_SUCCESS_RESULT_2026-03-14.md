# Carrier IsoZombie Success Result - 2026-03-14

## Summary

The `IsoZombie` carrier experiment has now crossed the proof-of-life threshold.

Confirmed through live testing:

- visible actor appears in world
- actor no longer disappears immediately
- right-click menu can appear
- delete works safely
- no major runtime error spam remains in the latest stable test loop

This makes `IsoZombie` the strongest current carrier candidate among the tested options.

## Comparison against earlier carrier experiments

### `IsoPlayer`

- world/simulation shell was usable
- alive visual embodiment remained transparently broken

### `IsoSurvivor`

- some constructor viability existed
- runtime-ready world embodiment did not materialize
- safety hardening turned the result into a clean reject, not a usable carrier

### `IsoZombie`

- visible shell succeeded
- persistence succeeded
- interaction targeting succeeded
- delete safety succeeded
- remaining limitations are now semantic/policy issues rather than raw spawn viability

## Current limitations

`IsoZombie` is still visibly/semantically a zombie shell.

Observed behavior:

- player can still attack the carrier
- the carrier remains inert unless future hostility logic intentionally enables more aggressive behavior
- the actor is still classified through zombie/reanimated-zombie presentation paths internally

That means the current success is:

- a stable visible shell success

not yet:

- a finished human-like NPC embodiment success

## Why this result matters

This is the first carrier experiment that convincingly answered:

- yes, a visible and persistent embodied shell can be maintained through LivingWorldNPC's architecture

That is a major step forward for the project, even though the shell is still semantically zombie-based.

## Immediate strategic implication

The project should continue exploring the `IsoZombie` line before abandoning embodied carriers entirely.

At the same time:

- canonical state / carrier separation remains the right architecture
- trust/hostility policy should drive future behavior rather than hardcoding permanent friendliness or permanent hostility
