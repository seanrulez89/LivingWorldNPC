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


## Follow-up locomotion patch after the first single-shell retest

A second live retest showed:

- clean-slate startup was improved enough to show only one test NPC
- the command escaped quarantine and entered `queued -> pathing`
- but the NPC still looked completely statue-like and never visibly walked
- a runtime error remained in `findRecoveryCandidateNearSquare`

That pointed to two direct issues:

1. the recovery helper had a real nil-call regression
2. movement was entering command/path state without reliably reaching actor-level locomotion

The follow-up patch therefore:

- removed the forward-local dependency in `findRecoveryCandidateNearSquare`
- stopped forcing a full carrier sync immediately before designated move command issue
- changed `Carrier.sync` so anchor snapping only happens when explicitly requested
- kept initial embodiment snapping by passing `snapToAnchor=true` only during initial sync
- updated movement start to try actor-level `pathToLocation` / `pathToCharacter` before falling back to `PathFindBehavior2`

This should make the next retest answer a narrower question:

- does the commandable non-hostile shell now produce first visible walking?

## Latest live validation after `ba1e972`

The next live validation established a stronger failure shape than the previous retest:

- `TEST 01` still showed only one visible test NPC at spawn
- from spawn, the shell already behaved as if it wanted to attack the player
- zombie audio leakage was present again
- `TEST 02` / `TEST 03` still produced only in-place walking with no real displacement and no visible turning
- the active shell kept its external appearance during the local test loop, but posture still read as hunched / zombie-like
- there was no obvious repeat of the earlier explicit runtime error
- after leaving and returning, the user clearly saw **both** of these on screen at the same time:
  - a roaming hostile zombie that matched the original NPC
  - a different-looking anchored NPC sitting back at the original test spot
- forcibly setting the anchored replacement friendly changed its appearance again
- deleting the active anchored NPC failed because it was already considered in combat

## Updated interpretation after that validation

The strongest current interpretation is now:

- the explicit `findRecoveryCandidateNearSquare` nil-call regression was fixed
- but the managed non-hostile commandable shell is still not actually winning against zombie combat / target-acquisition state
- movement command state can still reach `pathing`, `moving=true`, and `path2=true` while the actor never leaves the anchor square
- duplication is no longer just inferred: the user explicitly saw a roaming hostile original shell and a separate anchored replacement shell on the same screen at the same time
- the anchored managed shell also appears vulnerable to repeated appearance drift / reapplication when state is forced back toward friendly

## Immediate next engineering priorities

1. Hard-stop target acquisition and combat intent for commandable non-hostile test shells every tick.
2. Log explicit current-target / attack-state data so `non-hostile policy` can be compared against actual actor combat state.
3. Explain why `moving=true` + `path2=true` still never changes `currentSquare`.
4. Keep the duplicate-shell investigation focused on `rogue hostile original` + `managed anchored replacement`, not just generic relink failure.
5. Treat posture polish as secondary until the shell can both stay non-hostile and visibly walk.
