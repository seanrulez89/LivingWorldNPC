# Debug Single-Shell Recovery and Clean-Slate Pass — 2026-03-26

Branch: `spike/isozombie`
Status: implemented

## Why this pass happened

The first `TEST 01` to `TEST 04` movement pass revealed a more basic failure than pathfinding:

- two debug NPCs could overlap at the same origin
- automation still ran under quarantine in practice
- after leaving and returning, the original shells could survive as hostile zombies
- the system could then respawn fresh stationary replacements with different random appearance

That means the branch had a **single identity -> multiple shell** failure mode.

## What changed

### 1. Clean-slate automation startup

`TEST 01` now clears prior debug harness records and nearby rogue test shells before spawning the next test NPC.

This is meant to guarantee:

- one active debug test subject
- no stale overlapping shells from older runs
- no accidental reuse of old quarantined test actors

`TEST RESET` now performs the same cleanup.

### 2. Debug movement no longer defaults to quarantine

The debug config default for `DebugTestQuarantine` is now `false`.

Automation `TEST 01` also explicitly forces:

- `forceFriendly = true`
- `holdPosition = true`
- `quarantine = false`
- `allowCommandMovement = true`

So the movement path can actually be exercised.

### 3. Move commands explicitly break out of quarantine

Issuing the designated move command now forces:

- `allowCommandMovement = true`
- `quarantine = false`

before syncing the shell and queuing movement.

### 4. Actor-lost handling now prefers recovery over replacement

For debug harness records, the event adapter now:

- searches more aggressively near the anchor
- searches near the player for a matching rogue shell
- accepts recovery candidates using `activeNpcId`, `lastNpcId`, harness label, or shell marker
- uses a full sync for recovered non-quarantine shells

### 5. Hidden debug records no longer auto-respawn fresh replacements after actor loss

If a debug shell is truly lost, the record is moved to hidden with `noAutoRearm=true`.

That blocks the old failure mode where:

- original shell survives in-world as hostile
- record goes hidden
- a fresh replacement shell respawns later

Hidden debug records will now only recover by reclaiming a matching live shell, or by explicit clean-slate reset/test restart.

## What to verify next

1. `TEST 01` should show exactly one test NPC.
2. `TEST 02` should finally produce real commanded walking.
3. `TEST 04` should not produce hostile originals plus fresh replacement duplicates.
4. If recovery fails, the expected failure should now be **missing test NPC without replacement spawn**, not shell duplication.
