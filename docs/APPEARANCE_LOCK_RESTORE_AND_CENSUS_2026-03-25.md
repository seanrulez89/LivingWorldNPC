# Appearance Lock Restore (Pending) + Nearby Zombie Census

Date: 2026-03-25
Branch: `spike/isozombie`
Status: implemented, needs in-game validation

## Why this pass happened

Recent testing suggested two linked issues:

1. policy changes could still trigger major shell appearance changes more than once
2. after distance-return, the player could perceive two distinct zombie-like/NPC-like bodies on screen at the same time

This meant the next step needed to address both:

- appearance stability under forced policy transitions
- observability of nearby zombie-like world objects that might explain split-body or contamination reads

---

## Implemented changes

### 1. Identity-lock maintenance no longer refreshes blindly on mismatch

For harness-enabled shells with identity lock enabled:

- if the current appearance signature no longer matches the locked signature,
- maintenance now avoids the normal presentation refresh path,
- and instead records a `maintenance_identity_lock_restore_pending` mode.

This is intentionally conservative.

The goal is to stop policy/sync churn from inventing yet another look before we have a more explicit restore pipeline.

### 2. Locked mismatch no longer overwrites the remembered last-known signature

When maintenance enters the `restore_pending` mode, the locked/last-known state is preserved more carefully.

This makes the lock state more meaningful for later restore work instead of simply accepting every new drifted state as the new normal.

### 3. Nearby zombie-like census debug tool

Added a new debug helper that scans the nearby area and prints every zombie-like or dead-body object with:

- object kind
- object ref
- managed status
- `LWN_NpcId`
- `LWN_LastNpcId`
- test harness label
- world position
- whether current cleanup logic would treat it as a cleanup candidate

This is meant specifically for moments where the player sees:

- “the original NPC-like body”
- and “another NPC-like body”

on the screen at the same time.

### 4. Ordinary-zombie cleanup now protects any object with LWN markers

Nearby cleanup no longer removes zombie-like objects that still carry any LWN identity marker such as:

- `LWN_NpcId`
- `LWN_LastNpcId`
- `LWN_TestHarnessLabel`
- `LWN_ShellMarker`

This reduces the chance that a partially managed / partially split shell-like object gets deleted as if it were just ordinary ambient noise.

---

## Why this still supports the real mod goal

The real goal is not merely to make the test lane cleaner.
The real goal is to make the NPC shell stable, readable, and continuous.

That requires:

- stable shell identity under policy transitions
- the ability to distinguish the intended shell from ambient or orphaned zombie-like objects
- a more trustworthy understanding of when a shell truly splits versus when world contamination simply makes it look that way

This pass is therefore another step toward the intended NPC embodiment design, not away from it.

---

## Next validation focus

1. spawn a sterile test NPC
2. force the same policy sequence that previously produced two appearance shifts
3. verify whether appearance now stops drifting sooner
4. when two bodies seem visible at once, run `Dump Nearby Zombie-like Objects`
5. compare which object carries LWN markers and which one is considered an ordinary cleanup candidate

If the same shell still visibly splits, the next step will likely be a more explicit orphan-body detection and cleanup path around recovered/relinked shells.
