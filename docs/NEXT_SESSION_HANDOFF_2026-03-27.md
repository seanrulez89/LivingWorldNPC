# Next Session Handoff — 2026-03-27

Branch at freeze point: `spike/isozombie`
Next work branch: `spike/companion-shell-split`
Status: pre-surgery baseline frozen after repeated same-shape failures

## Why this handoff exists

The project has reached a point where incremental hardening is no longer changing the core failure shape enough.

Recent fixes did improve:

- debug observability
- test automation clarity
- cleanup protection for known managed shells
- global game-audio regression caused by broad emitter shutdown
- crash safety around watchdog telemetry

But the same main failures still repeat.

## Current repeated failure shape

### 1. Spawn still defaults to zombie presentation

The active test shell still repeatedly shows:

- `presentationRole=reanimated_zombie`
- `humanInit=false`
- zombie body skin / zombie read at spawn

This means default spawn-time humanization is still not crossing the practical success line.

### 2. Movement command pathing still does not become real locomotion

The recent hold-release pass did matter, because test logs now show `hold=false` during command movement.

However, the deeper failure remains:

- `moving=true`
- `path2=true`
- `totalDelta=0.00`
- no actual square change

So the strongest remaining movement diagnosis is no longer simple hold-position blockage.
It is now closer to:

- same-shell locomotion authority mismatch
- or zombie-native state machine conflict on the friendly command path

### 3. Return-path continuity still collapses into split behavior

After leaving and returning, the user still repeatedly sees some version of:

- the original shell reading like an ordinary hostile zombie
- a different-looking replacement or anchored shell near the original spot

Recent reclaim and cleanup hardening helped observability, but logs still show the same continuity failure family:

- `cached_miss`
- `handle_reclaim_failed`
- `handle_rejected`
- `candidate_missing`

### 4. Friendly reapply contains the strongest new clue

The user observed that forcing the replacement into a friendly state changed the shell’s appearance and that changed appearance then stayed stable.

This matters a lot.

It suggests:

- appearance work is not universally impossible on this branch
- later maintenance/reapply paths can visibly land
- the default spawn path and/or same-actor authority model are likely the real bottleneck

### 5. The relationship matrix is now hurting test clarity

At this stage, keeping:

- friendly
- neutral
- hostile

all active in the same experiment loop is making diagnosis noisier.

The user’s current judgment is correct:

- relationship-mode variety is adding ambiguity instead of learning value

## Decision for the next phase

For the next big-surgery phase, simplify the test lane.

### Freeze the main experiment baseline to one relationship mode first

Use:

- locked friendly / trusted companion
- commandable or companion-mobile only

Temporarily stop treating friendly/neutral/hostile as equally important in the same immediate loop.

### Preserve `spike/isozombie` as the readable pre-surgery baseline

Do not bury the current evidence under another long chain of mixed patches.

Instead:

- keep the current branch as the freeze point
- move the next architectural work into a dedicated surgery branch

## Big-surgery direction

The strongest current architectural conclusion is:

**Stop trying to make one `IsoZombie` actor cleanly support all of these at once:**

- hostile zombie behavior
- friendly companion behavior
- human survivor presentation
- commandable movement
- recovery continuity
- appearance stability

That approach has produced repeated same-shape failures even after multiple hardening passes.

### New direction to test aggressively

1. **Simplify authority first**
   - locked-friendly override for the main experiment lane
   - no neutral/hostile churn in the first surgery loop

2. **Split roles instead of forcing one actor to do everything**
   - hostile shell logic and companion shell logic should stop sharing the same assumptions

3. **Treat failed spawn humanization as a rebuild trigger, not just a repair target**
   - if spawn stays zombie-role / humanInit-false, consider that shell a failed candidate

4. **Use generation-based identity, not just npcId**
   - stop allowing old/orphaned shells and replacement shells to compete for the same logical identity

5. **Prioritize actual displacement over natural-looking locomotion**
   - first prove one-tile real movement
   - polish later

## Immediate practical next tasks

1. Disable or bypass neutral/hostile churn in the main debug harness.
2. Introduce a top-priority manual relationship lock that other logic cannot override.
3. Add a generation concept for shell identity.
4. Design or prototype a companion-specific shell path separate from the hostile zombie path.
5. Consider deterministic movement for the friendly companion shell instead of relying on the current zombie-native locomotion path.

## Main files likely to matter in the surgery phase

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/20_LWN_ActionRuntime.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`
- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

## Validation state at freeze point

- `./scripts/validate-wsl.sh`
- `luac -p` on recent changed files

The branch is being frozen here specifically because the runtime is once again testable, documented, and consistent enough to justify a true architecture reset instead of more small patches.
