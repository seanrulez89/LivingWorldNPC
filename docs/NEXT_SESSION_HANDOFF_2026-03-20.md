# Next Session Handoff - 2026-03-20

## Current branch

- active experimental branch: `spike/isozombie`

## Tonight's important result

This was the first test where all of the following became true at once:

- debug dump no longer crashed
- the hybrid appearance experiment actually executed on the live `IsoZombie` shell
- `hostile` produced real pursuit/attack intent toward the player
- `friendly` / `neutral` looked calmer than `hostile`
- but the visible shell still rendered as a zombie
- and relationship/trust sync still threw repeatable errors

## What is now confirmed

### 1. The hybrid appearance experiment is genuinely running

Logs now show:

- `exp=isozombie_shared_desc_visual_v1:applied@sync_pending_applied`
- descriptor source moving to `npc_record_survivor_desc_*`
- item-visual bridge reporting `item_visuals_present`

This means the safe-reuse path from the old `IsoPlayer` work is no longer hypothetical.
It runs on the shell.

### 2. The live shell still renders through zombie presentation

Even after `applied`, logs still show zombie-facing render state such as:

- `presentationRole=reanimated_zombie`
- zombie body skins like `M_ZedBody04_level1`

Practical meaning:

- descriptor / human-visual work is being applied
- but it does not overcome the `IsoZombie` presentation pipeline

### 3. Hostility policy now affects live behavior

The latest hostile test did not remain a no-op.
User observed the shell coming after the player.
Logs support this with lines such as:

- `stance=hostile_player`
- `safety=attackable`

This is the first strong sign that relationship policy is now changing real runtime behavior, not just metadata.

### 4. Non-hostile suppression is still incomplete

User heard short repeated footstep sounds in states that should have stayed pinned/inert.
Logs support a movement conflict with signals like:

- repeated `retreat` entries in the action queue
- `IsoGameCharacter.doDeferredMovement > WalkTowardState but path2 != null`

Interpretation:

- the shell still has deferred movement/path state surviving or getting re-enqueued
- current neutralization is not strong enough for `friendly` / `neutral`

### 5. Current relationship/trust sync still throws a repeatable Java-side exception

Every force-policy or trust-adjust sync can trigger:

- `NullPointerException: Cannot assign field "isNpc" because "this.player" is null`

Stack trace shows:

- Java side: `IsoGameCharacter.setNPC(...)`
- Lua side: `23_LWN_ActorFactory.lua -> refreshActorPresentation()`

Interpretation:

- `setNPC(true)` is unsafe on the live `IsoZombie` carrier
- this is now the first fix to make before more relationship-state testing

## Most likely next code actions

### A. Remove or hard-gate `setNPC(true)` for zombie carriers

Do this first.

Reason:

- the stack trace points directly at it
- it pollutes every relationship/trust sync test
- it is probably calling a player-backed Java path that `IsoZombie` does not satisfy

Keep `setIsNPC(true)` only if it remains safe after verification.

### B. Strengthen non-hostile movement suppression

Current package is not enough:

- `setUseless(true)`
- `setCanWalk(false)`
- `setNoTeeth(true)`
- `StopAllActionQueue()`
- target clear

Next pass should also inspect and clear path/deferred movement state where possible, and avoid re-enqueuing movement on every sync.

### C. Trace the source of repeated `retreat`

The action queue suggests another layer is writing movement intent after carrier policy applies.
Find who is writing `retreat` and whether it should be disabled for non-hostile shells.

### D. Shift the appearance investigation up one layer

Do **not** spend the next pass only adding more descriptor/human-visual tweaks.
That layer now runs and still loses.

The next appearance question is:

- can `IsoZombie` ever stop rendering through `reanimated_zombie` / zombie body skin
- or is that presentation pipeline the hard limit

## Recommended reading order next time

1. `docs/WORK_NOTES_2026-03-20.md`
2. `docs/TEST_LOG_HISTORY.md`
3. `docs/HYBRID_ISOZOMBIE_SHELL_PLAN_2026-03-20.md`
4. `logs/2026-03-20_02-42_DebugLog.txt`

## Bottom line

Resume from:

- branch `spike/isozombie`
- current goal = stabilize the `IsoZombie` shell by:
  - removing the unsafe `setNPC(true)` zombie refresh path
  - stopping non-hostile movement churn
  - then probing whether zombie presentation itself is the real appearance ceiling
