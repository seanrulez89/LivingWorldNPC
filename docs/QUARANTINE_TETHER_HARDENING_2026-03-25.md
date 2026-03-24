# Quarantine + Tether Hardening

Date: 2026-03-25
Branch: `spike/isozombie`
Status: implemented, needs in-game validation

## Why this pass happened

Recent testing showed a sharper failure mode than simple visual ambiguity:

- spawn-time zombie audio leak before policy suppression fully landed
- managed debug shell could later behave like an ordinary attacking zombie
- continuity eventually failed with `actor_lost`
- once the registry lost the shell, the player's read was effectively "the NPC reverted into a normal zombie"

This meant the test harness was still too soft.

The project goal is still the intended mod design: a convincing managed NPC shell, not merely a debug toy.
But to reach that goal, the managed shell first needs stronger lifecycle control.

This pass therefore hardens three things:

1. **spawn quarantine**
2. **actor tether / recovery**
3. **hidden-state continuity preservation**

---

## Implemented changes

### 1. Spawn quarantine for debug harness shells

Debug-harness IsoZombie shells now enter a stronger quarantine path immediately at spawn/sync time.

Effects:

- emergency zombie audio suppression happens before full humanization succeeds
- shell is forced toward neutralized non-lunge, non-targeting posture
- managed shell markers are re-stamped aggressively

This is meant to close the early "spawn as noisy zombie, only later become quiet" gap.

### 2. EventAdapter-side quarantine enforcement

The world tick loop now respects debug harness quarantine more directly.

Effects:

- quarantined harness shells are re-neutralized during embodied ticks
- action/combat generation is suppressed even if the generic social path would otherwise drift
- managed markers are re-stamped before further embodied processing

This is intentionally stronger than the previous hold-position-only logic.

### 3. Actor tether / recovery hardening

`resolveEmbodiedActor(...)` and nearby recovery now accept more recovery signals than only a perfect `LWN_NpcId` marker.

Recovery signals now include:

- known NPC id (`LWN_LastNpcId` path)
- matching test harness label
- same carrier-handle actor reference

If such a match is found, the actor is re-stamped and reused instead of being too quickly treated as lost.

### 4. Wider harness search radius

For harness-enabled shells, nearby recovery searches now scan a wider area around the preserved position.

This increases the chance of relinking to the managed shell after distance movement / partial drift.

### 5. Preserve last known position for hidden alive records

Embodiment cleanup previously cleared embodied meta too aggressively.

Now:

- register/update paths store `record.embodiment.lastKnownX/Y/Z`
- hidden alive records keep hidden-state embodied meta at the last known position instead of immediately dropping to nil

This improves future rearm/recovery and prevents the system from falling back to stale anchor-only assumptions too early.

### 6. Longer actor-lost grace for debug harness shells

Harness-enabled debug shells now tolerate a larger missing-actor threshold before being declared lost.

This is not meant as a final gameplay rule.
It is a stability bridge so the system gets more chances to recover a shell before hard cleanup.

---

## Strategic meaning

This hardening is not a detour away from the real mod goal.
It supports that goal.

The intended mod fantasy requires:

- persistent shell identity
- stable social posture
- suppression of obvious zombie leakage when the design does not want it
- continuity across travel and lifecycle transitions

If the shell cannot stay under control, later polish on profiles/audio/humanization remains unreliable.

So this pass should be understood as **runtime control hardening in service of the real NPC illusion**, not just test convenience.

---

## Next validation focus

1. spawn a sterile debug IsoZombie
2. immediately verify it is quiet faster than before
3. move far away and return
4. confirm the same shell is more likely to remain tracked or recoverable
5. confirm it does not easily revert into obvious hostile zombie behavior unless intentionally released from quarantine

If this still fails, the next likely step is an even stronger rebind path or a dedicated shell-specific world marker.
