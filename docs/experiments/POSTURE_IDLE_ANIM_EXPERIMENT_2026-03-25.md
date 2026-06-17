# Posture / Idle / Animator Experiment

Date: 2026-03-25
Branch: `spike/isozombie`
Status: implemented, needs in-game validation

## Why this pass happened

A major player-perception issue remained even when:

- spawn audio was quieter
- shell identity was more stable
- behavior quarantine was stronger

The shell could still read immediately as a zombie because of **idle posture**.

The most obvious tell is the hunched zombie stand pose.
Even with better clothes and quieter audio, that posture heavily collapses the human read.

---

## Reference-backed control points reviewed

This pass was informed by:

- `docs/reference/PZWIKI_BUILD42_ISOZOMBIE_SHELL_REVIEW_2026-03-20.md`
  - explicitly calls out idle hunch / tension posture as a high-signal zombie tell
- `docs/retired-bandits/LWN_BANDITS_1TO1_MINIMAL_COMPONENT_MAP_2026-03-21.md`
  - identifies idle posture / turn behavior as a first-class profile dimension
- `docs/reference/REFERENCE_CORPUS_ISOZOMBIE_AUDIT_2026-03-20.md`
  - confirms Bandits uses zombie-shell suppression variables like `NoLungeTarget`, `Walk`, and `ZombieHitReaction`
- `reference_mods/1905148104/mods/Superb-Survivors/.../SuperSurvivor.lua`
  - shows a human-NPC-side `setIdleAnimatorState()` plus animation variable clearing pattern for unsticking/returning to a cleaner idle state

---

## Implemented experiment

Added a dedicated posture helper in `35_LWN_Carrier_IsoZombie.lua`:

- `applyPostureHumanization(record, actor, source, options)`

### What it does

It attempts to reduce zombie-looking idle posture by combining:

- `setIdleAnimatorState()`
- `setWalkType("Walk")`
- `setVariable("BanditWalkType", "Walk")`
- `setVariable("NoLungeTarget", true)`
- `setVariable("ZombieHitReaction", "Chainsaw")`
- clearing animation/action variables such as:
  - `TimedActionType`
  - `BumpFallType`
  - `WeaponReloadType`
  - `bdoshove`
  - `bDoShove`
  - `isattacking`
  - `AttackAnim`
  - `bShoveAiming`
  - `BumpFall`
  - `bPathfind`
  - `bKnockedDown`
  - `FallOnFront`
  - `ZombieTurnAlerted`
  - `ZombieTurnRight`
  - `ZombieTurnLeft`
  - `onknees`
  - `frombehind`
  - `ragdollbump`
- forcing `setOnFloor(false)` and `setFallOnFront(false)`
- when neutralized, also re-clearing path/target/movement and re-facing a calm direction
- refreshing presentation afterward

### Where it is applied

The new posture helper is now used in:

- emergency quarantine
- persistent illusion package
- neutralized relationship state
- active relationship state

This makes posture correction part of both initial suppression and ongoing shell maintenance.

---

## Debug visibility

Debug output now includes:

- `posture=<...>`

This allows quick verification of whether the posture experiment path actually ran on the live shell.

---

## What this experiment is trying to learn

Not:

- whether one magic flag can make an `IsoZombie` truly stand like a player

But:

- whether the shell can be pushed away from the most obviously hunched zombie idle read
- whether animator reset + variable clearing lowers the perceived zombie posture enough to matter
- whether this works stably under quarantine / policy transitions / distance-return

---

## Expected validation questions

1. does the shell stand less hunched immediately after spawn?
2. does it still revert to a zombie-like hunch after policy changes?
3. does distance-return preserve the improved posture or lose it?
4. does the debug dump show `posture=...anti_hunch...` consistently when expected?

If posture still remains strongly zombie-coded after this pass, that would be evidence that the final idle stance is more deeply tied to zombie presentation-role ownership than to the currently accessible animator variables.
