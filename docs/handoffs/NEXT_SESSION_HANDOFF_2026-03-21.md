# Next Session Handoff - 2026-03-21

## Branch / current status

- active branch: `spike/isozombie`
- current HEAD at end of session: `9305213` (`Apply persistent illusion package to isozombie shells`)
- branch is ahead of origin and contains both research-only and gameplay-spike commits from this session

## Executive summary

Today was the day the project decisively stopped being an "engine conversion" attempt and became a managed-illusion project.

By the end of the session, all of the following were true at once:

- the `IsoZombie` shell remained visibly stable and controllable
- non-hostile (`friendly` / `neutral`) shells became much calmer and mostly stopped the old tiny-footstep treadmill churn
- zombie vocal sounds were successfully suppressed by the current experimental audio package
- the shell still rendered through zombie presentation (`reanimated_zombie`, zombie body skin)
- the first strong relationship/policy sync after spawn caused a real appearance refresh, including outfit / hair / beard / worn-item changes
- hostile still behaved and read like a zombie attack profile, not like a convincing human hostile NPC

This means the current spike has crossed from "can we keep the shell alive and under control?" into "which parts of human perception can we steadily layer onto a zombie carrier, and which parts appear hard-limited by the zombie presentation/runtime pipeline?"

## High-level verdict after today's work

### 1. `IsoZombie` remains the correct carrier direction

The repo, the day's experiments, and the full research pack all align on this:

- `IsoPlayer` as the main embodied carrier is no longer the favored route
- `IsoZombie` is the only path in this repo that consistently produces:
  - visible shell persistence
  - controllable hostile/non-hostile posture changes
  - manageable sync/debug loops
  - realistic room for a managed illusion stack

### 2. The problem is now explicitly a persistent illusion problem

The shell is not becoming a true native human runtime.
Instead, progress now comes from stacking and maintaining specific human-readable layers:

- clothing / outfit / worn-items
- hair / beard / descriptor-driven grooming
- human-leaning walk/read cues
- zombie-vocal suppression
- anti-zombie behavior suppressions
- social policy framing
- debug-visible continuity markers

### 3. Final zombie presentation still appears to be the active hard ceiling

Repeated logs and tests still show:

- `presentationRole=reanimated_zombie`
- zombie body skin such as `M_ZedBody...` / `F_ZedBody...`

This remained true even when:

- `descriptor=true`
- `humanVisual=true`
- `wornItems > 0`
- `itemVisuals > 0`
- appearance diffs clearly showed clothing / hair / beard / outfit-id changes

Interpretation:

- descriptor/human-visual shaping is real
- outfit/grooming refresh is real
- but zombie-class presentation is still winning the final render read

Treat this as the current default assumption until disproven.

## What changed today (chronological engineering summary)

### A. Research synthesis / roadmap / cleanup triage

Created and committed major docs-only synthesis work:

- `docs/reference/LWN_ISOZOMBIE_MASTER_REFERENCE_2026-03-21.md`
- `docs/reference/LWN_ISOZOMBIE_CLEANUP_TRIAGE_2026-03-21.md`
- plus the March 20 research docs from local corpus / web / B41 javadocs / PZwiki

These documents established the session's central conclusion:

- do not keep chasing a magical "turn zombie into human class" solution
- instead treat the shell as managed embodiment plus persistent illusion maintenance

### B. A-group cleanup removals

Commit: `9dad167` — `Remove dead legacy cleanup remnants`

Removed dead / unread legacy code such as:

- dead `Legacy.applyPendingToPlayer(player)` stub
- unread persisted `legacy.candidates` plumbing
- unused `record.companion.canContinueAsLegacy` writes/defaults

Goal:

- reduce stale branches that could confuse the current `IsoZombie` spike or create accidental future errors

### C. Stage-1 stabilization already in place going into today's tests

Relevant earlier commit still active today:

- `f99ff30` — `Stabilize IsoZombie presentation NPC stamping`

This mattered because it removed the unsafe `setNPC(true)` / `setIsNPC(true)` path on zombie carriers during appearance refresh, which had previously produced the Java-side `this.player is null` crash.

### D. Phase 0 immediate stability / observability pass

Commit: `5d9686b` — `Phase 0: tighten non-hostile shell suppression and debug observability`

Added:

- stronger non-hostile intent clearing
- shell/session/identity markers in modData
- richer actor summary with role/skin/item visuals/pathing state

### E. High-yield diagnostics pass

Commit: `66b63d9` — `Phase 0 follow-up: add high-yield shell diagnostics`

Added:

- `npc decision` dump line
- `Dump Nearest NPC Movement/Audio`
- debug state stamping for:
  - decision source
  - utility choice
  - behavior choice
  - chosen action
  - neutralization state
  - queue-before state

This was the key pass that isolated movement churn as a specific decision-source issue instead of just a vague shell instability.

### F. Neutralized combat-churn block + appearance diff logger

Commit: `d90b005` — `Block neutralized combat churn and log appearance diffs`

Two crucial fixes landed here:

1. **Neutralized shells now suppress combat intent generation entirely**
   - not just UtilityAI/BehaviorTree
   - stale queues are cleared when neutralized
2. **Appearance diff logging became real**
   - before/after appearance snapshot compare
   - diffs logged for role / skin / hair / beard / itemVisuals / wornItems / persistentOutfitId / descriptor / humanVisual

This is the patch that made it possible to confirm the first visible outfit/hair/grooming change was real.

### G. Persistent illusion package

Commit: `9305213` — `Apply persistent illusion package to isozombie shells`

This is the most conceptually important code change of the day.

It intentionally moved the spike into an explicit illusion-maintenance architecture.

The package currently reasserts, per sync:

- descriptor voice prefix `NotAZombie`
- `NoLungeTarget = true`
- `ZombieHitReaction = "Chainsaw"`
- `Walk` walk type
- `BanditWalkType = "Walk"`
- emitter-level audio suppression (`stopAll`, stop zombie combined sounds)

This was consciously inspired by the Bandits-style evidence from the reference audit.

## Most important in-game observations from today's tests

### 1. Non-hostile shells are now much calmer

User-observed behavior after the neutralized combat block:

- friendly / neutral no longer obviously attack
- the previous tiny repeated footstep churn mostly stopped
- changing from hostile back to neutral/friendly now stops the shell immediately
- treadmill-walk after de-escalation was no longer the dominant failure mode

Interpretation:

- the key culprit really was combat-side retreat injection fighting policy suppression
- blocking neutralized combat generation was the right move

### 2. Hostile still works, but still reads as zombie hostility

User observed:

- hostile shell still comes after the player
- but does so in a zombie-like way
- after the persistent illusion pass, the shell could still attack like a zombie but now without the earlier obvious zombie vocalization

Interpretation:

- hostile control survives the new suppression package
- however hostile still lacks a dedicated human-hostile embodiment profile
- current result is closer to "managed zombie aggression" than "human hostile NPC"

### 3. The first big humanization sync after spawn is real

This was a key breakthrough.

User repeatedly observed that the first forced state change after spawn caused a visible outfit change.
Logs confirmed that this was not imagination.

Example logged appearance diff:

- `skin:M_ZedBody02_level1->M_ZedBody04_level1`
- `hair:Mullet->Fabian`
- `beard:Chin->PointyChin`
- `itemVisuals:7->6`
- `wornItems:0->3`
- `persistentOutfitId:4325872->4325390`

Interpretation:

- the shell is not fully humanized at raw spawn time
- the first significant sync/humanization pass is still doing meaningful work
- later maintenance syncs appear to be less dramatic, which suggests the architecture should probably split:
  - initial humanization apply
  - later maintenance reassertion

### 4. Audio humanization works, but currently too bluntly

User observed:

- zombie sounds stopped
- but when the shell treadmill-walked, normal footstep presence also felt absent

Interpretation:

- `stopAll()`-style emitter suppression is proving the concept
- but likely over-suppresses valid audio presence too
- the next version should be more selective

## Research conclusions that must not be forgotten next session

The day's large research set repeatedly supported these points:

### A. Best-supported architecture

The strongest evidence-backed architecture remains:

- managed zombie shell
- external brain / policy / identity
- persistent illusion maintenance

### B. Best reference-backed pattern source

From the scanned corpus, the strongest explicit `IsoZombie` carrier reference is still the Bandits family.
Key lessons imported from there:

- spawn shell, then decorate it
- keep AI/brain external to the shell
- mark shell identity explicitly
- continuously reassert anti-zombie / humanizing state instead of relying on one-shot setup
- use voice prefix / walk type / anti-lunge / reaction guards as illusion-layer tools

### C. Build 41 material remains a concept map, not implementation truth

Build 41 javadocs are still useful for conceptual separation of:

- identity
- visual shaping
- shell/runtime semantics

But must not be trusted as proof that Build 42 supports true human reclassification of `IsoZombie`.

### D. PZwiki / web / official docs all pointed toward the same framing

The problem is not simply "spawn a smarter AI".
It is fundamentally:

- a human-perception problem
- an animation/read problem
- an audio/read problem
- a UI/social framing problem
- a lifecycle/continuity problem

## Current unresolved blockers at end of session

### 1. Zombie presentation ceiling still wins

Still unresolved:

- final zombie presentation role
- final zombie body skin

This remains the top appearance ceiling.

### 2. Hostile profile is still not humanized

Hostile shells still read like zombies with some suppressions layered on top.
They do not yet read like armed/angry human NPCs.

### 3. Audio suppression is too coarse

Zombie vocal suppression is now working, but valid movement/presence sounds may also be getting wiped.

### 4. Humanization timing is awkward

The first big appearance jump still happens on first forced state/sync rather than feeling like part of spawn completion.

## Recommended next-session code priorities

### Priority 1 — Split initial humanization from maintenance

This should likely be the very next experiment.

Goal:

- make the first major clothing/hair/outfit/grooming application happen as an explicit initial stage
- later syncs should do light maintenance only

Reason:

- currently the first forced relationship/policy change visibly transforms the shell
- this is both immersion-breaking and diagnostically valuable
- separating first-apply from maintenance should make the illusion cleaner and easier to reason about

### Priority 2 — Replace blunt audio stop with selective zombie-vocal suppression

Goal:

- keep zombie vocals gone
- restore non-zombie presence cues where appropriate
- avoid muting everything via `stopAll()` as the steady-state solution

Reason:

- current pass proved audio humanization matters
- but the current tactic is too heavy-handed

### Priority 3 — Create a hostile-specific illusion profile

Goal:

- keep hostile pursuit/attack active
- but maintain anti-zombie read as much as possible
- reduce the sense that hostile == plain zombie attack mode

Potential ingredients:

- keep human walk/read cues where possible
- keep zombie vocals suppressed
- preserve anti-lunge / reaction guards
- consider whether combat intent/read should be steered away from purely zombie-like fallback behavior

### Priority 4 — Continue appearance diff instrumentation, but stop treating clothing change as victory

Goal:

- keep tracking what actually changes
- but recognize that clothing/hair/outfit shifts still terminate in zombie final presentation

Reason:

- surface-layer progress is useful
- but it is not the same as solving the final embodiment problem

### Priority 5 — Keep known-constant trace noise compressed

Do not regress here.
The project is now at the stage where repeated constant spam can easily hide the few truly meaningful lines.

## Best test plan next time

A strong next-session manual test would be:

1. spawn shell
2. dump summary + hybrid + movement/audio immediately
3. force one first state change and immediately dump again
4. verify whether the initial humanization apply still causes the major appearance jump
5. test friendly / neutral quietness
6. test hostile audio / locomotion read
7. compare whether new audio strategy restores presence without reintroducing zombie vocals

## Files most worth reading before touching code next time

1. `docs/reference/LWN_ISOZOMBIE_MASTER_REFERENCE_2026-03-21.md`
2. `docs/reference/LWN_ISOZOMBIE_CLEANUP_TRIAGE_2026-03-21.md`
3. `docs/work-notes/WORK_NOTES_2026-03-20.md`
4. `docs/testing/TEST_LOG_HISTORY.md`
5. `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
6. `42/media/lua/client/90_LWN_EventAdapter.lua`
7. `42/media/lua/client/23_LWN_ActorFactory.lua`
8. `42/media/lua/client/92_LWN_DebugTools.lua`

## Commit sequence from today's meaningful spike work

- `9dad167` — Remove dead legacy cleanup remnants
- `5d9686b` — Phase 0: tighten non-hostile shell suppression and debug observability
- `66b63d9` — Phase 0 follow-up: add high-yield shell diagnostics
- `d90b005` — Block neutralized combat churn and log appearance diffs
- `9305213` — Apply persistent illusion package to isozombie shells

## Bottom line

End-of-day status:

- `IsoZombie` spike is still the right lane
- non-hostile shells are now much more stable
- humanizing layers are now visibly doing real work
- audio suppression proves the illusion stack can affect player perception
- the project now needs cleaner initial-humanization timing, more selective audio handling, and a hostile-specific illusion profile
- do **not** fall back into thinking the next win comes from a hidden engine switch that reclassifies the shell into a native human actor
