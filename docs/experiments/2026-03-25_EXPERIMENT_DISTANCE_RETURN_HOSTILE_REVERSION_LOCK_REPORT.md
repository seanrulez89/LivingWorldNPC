# Distance-Return Hostile Reversion Lock

Date: 2026-03-25
Branch: `spike/isozombie`
Status: implemented, needs in-game validation

## Why this consolidation pass was necessary

Latest test evidence converged on one critical failure:

- the originally spawned test shell can attack the player after distance-return
- this can happen before any new manual relationship toggle
- ordinary-zombie cleanup can remove the visible attacker
- but relationship controls can still target the same NPC record until explicit delete

That means the strongest current bug is not just appearance drift.
It is **live shell behavior authority + object/record separation after recovery/loss transitions**.

---

## Reference context used in this pass

- `docs/reference/2026-03-20_REFERENCE_BUILD42_ISOZOMBIE_NPC_WEB_MEMO.md`
  - zombie behavior control is distributed (no single-flag fix)
  - `setTargetSeenTime`, useful/useless, fake-dead/crawler posture controls are relevant
- `docs/reference/2026-03-20_REFERENCE_ISOZOMBIE_CORPUS_AUDIT.md`
  - Bandits-style shell suppression uses bundled controls (`NoLungeTarget`, `setNoTeeth`, walk-type, voice/audio handling)
- `docs/reference/2026-03-21_CARRIER_ISOZOMBIE_MASTER_REFERENCE.md`
  - this is an illusion-maintenance / continuity-control problem, not one-shot conversion

---

## Implementation goals

This pass focused on four practical goals:

1. prevent immediate post-recovery attack authority from reappearing
2. keep recovered shells under temporary attack quarantine
3. reduce actor_lost -> rogue shell drift by salvaging/removing likely attacker objects
4. stop debug cleanup from removing currently live bound shell objects

---

## Implemented code changes

### A) Recovery attack quarantine state added to schema/config

- `42/media/lua/shared/01_LWN_Schema.lua`
  - added `record.embodiment.attackQuarantineUntilHour`
  - added `record.embodiment.lastAttackQuarantineAt`
  - added `record.embodiment.lastAttackQuarantineReason`

- `42/media/lua/shared/00_LWN_Config.lua`
  - added `DebugRecoveryAttackQuarantineHours` (default `0.08`)
  - added `DebugPurgeRogueShellOnActorLost` (default `true`)

### B) EventAdapter recovery lock hardening

- `42/media/lua/client/90_LWN_EventAdapter.lua`

Added:

- `recoveryAttackQuarantineHours()`
- `applyRecoveryAttackQuarantine(record, reason)`
- `isRecoveryAttackQuarantineActive(record)`

Behavioral changes:

- `hardReNeutralize(...)` now also applies recovery attack quarantine state
- relation policy suppression in `tickEmbodiedRecord(...)` now also activates when recovery attack quarantine is active (not only harness quarantine)
- `restampManagedActor(...)` now stamps attack-lock metadata onto actor modData

Actor-lost salvage path:

- `hideEmbodiedRecord(..., reason="actor_lost")` now attempts salvage actor resolution from:
  1. carrier handle actor
  2. nearby relink search
  before cleanup continues (when `DebugPurgeRogueShellOnActorLost` is enabled)

### C) Carrier metadata continuity

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

Added modData stamps in `applyBasicZombieCarrierFlags(...)`:

- `LWN_AttackQuarantineUntil`
- `LWN_AttackQuarantineReason`

This improves live debugging and makes it easier to verify whether attack lock is active on the shell currently seen in-world.

### D) Debug cleanup safety + observability

- `42/media/lua/client/92_LWN_DebugTools.lua`

`clearNearbyWorldNoise(...)` now protects objects that are bound to live records even if markers are incomplete:

- checks not only LWN markers (`LWN_NpcId`, `LWN_LastNpcId`, labels, shell marker)
- also checks whether object is currently referenced by any live record actor/handle

Debug output expanded:

- actor summary / movement-audio lines now include `attackLock=<untilHour>`
- testHarness summary includes attack lock fields

---

## What this pass is expected to improve

- reduce immediate hostile attack reversion after distance-return/recovery
- reduce mismatch where visible attacker is removed but logical record remains entirely detached from live shell control
- make cleanup behavior safer for currently bound shell objects
- improve diagnosis when attack lock state is/was active

---

## Validation checklist (next run)

1. Spawn sterile IsoZombie test NPC.
2. Do not force hostile after spawn.
3. Travel far and return.
4. If shell attacks:
   - run nearest summary + movement/audio dump immediately
   - verify `attackLock` fields
5. Run nearby zombie cleanup and verify whether bound shell remains protected.
6. If actor_lost occurs, verify salvage/cleanup traces before final hidden state transition.

Success target:

- no immediate player attack after return while attack-lock window is active.
