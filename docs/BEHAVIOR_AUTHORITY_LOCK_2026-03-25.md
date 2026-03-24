# Behavior Authority Lock

Date: 2026-03-25
Branch: `spike/isozombie`
Status: implemented, needs in-game validation

## Why this pass was necessary

Previous hardening improved:

- spawn-time audio leakage
- test-shell identity stability
- some continuity / recovery behavior

But a major failure remained:

- after travelling away and returning, the shell could still behave like an ordinary hostile zombie
- it would actively path toward and attack the player
- meanwhile appearance was much more stable than before

That meant the dominant remaining problem was no longer appearance churn.
It was **behavior authority**.

The shell was still able to fall back to zombie-native combat/movement authority after recovery or drift.

---

## Design intent alignment

This pass is not just a test tweak.
It supports the actual mod goal.

The intended design is not:

- "a zombie that sometimes looks more human"

The intended design is closer to:

- "a managed NPC shell whose movement/combat authority remains subordinate to NPC control"

To move toward that, quarantine shells need a stronger authority lock.

---

## Implemented changes

### 1. Hard re-neutralize helper in EventAdapter

Added a stronger recovery helper that:

- re-stamps managed shell identity
- re-applies carrier quarantine
- clears ActionRuntime queue
- clears direct target/path/movement state
- reasserts useless/cannot-walk/no-teeth flags

This helper is now used during the most important recovery and quarantine paths.

### 2. Recovery-time authority reset

When an actor is recovered or relinked, the runtime now performs a harder re-neutralization step instead of only lightly re-stamping metadata.

Applied during:

- cached resolve path for quarantined shells
- relink-near-anchor path
- actor-missing recovery-from-handle path

### 3. Quarantine shells skip normal goal/action progression

For quarantined debug shells:

- `GoalSystem.update(...)` is skipped
- combat/utility-driven action selection is effectively bypassed by stronger neutralized handling
- `ActionRuntime.tick(...)` is skipped
- post-quarantine hard re-neutralize is applied again instead

This reduces the chance that zombie-native or queued hostile behavior reasserts itself between recovery steps.

### 4. Hostile force blocked under quarantine by default

The debug policy-forcing tool now refuses hostile forcing when:

- harness is enabled
- quarantine is enabled
- `allowForcedHostile` is not explicitly enabled

This prevents test-shell authority from being accidentally undermined by the debug menu itself.

---

## Strategic meaning

This pass shifts the project from:

- identity stability only

toward:

- identity stability **plus** behavior authority control

That matters because appearance stability without behavior control still reads like a zombie shell with cosmetic improvements.

The intended design needs both.

---

## Next validation focus

1. spawn a sterile debug IsoZombie
2. confirm spawn is still quiet
3. walk far away and return
4. verify the shell does **not** resume obvious hostile pursuit/attack
5. verify appearance still remains stable after the first forced policy refresh

If hostile pursuit still returns after this pass, the next likely step will be pushing authority lock even lower into carrier/runtime state transitions or introducing a dedicated anti-hostility watchdog for quarantined shells.
