# Next Session Handoff — 2026-03-29

Current work branch: `spike/minimal-neutral-dummy`

## Executive summary

Today’s session sharply narrowed the current branch state:

- `IsoZombie` remains the only stable active lane.
- `IsoZombie` is **not** primarily failing because descriptor/clothing/skin are missing.
- The stronger current blocker is zombie-owned presentation/runtime truth.
- `IsoSurvivor` provided useful actor-class evidence but is **not safe to keep live** because the current constructor path can hard-crash the engine.

## What is settled enough that it should not be re-proved casually

### 1. Current `IsoZombie` minimal dummy behavior
Repeated full-restart tests already established all of the following together:
- spawn succeeds reliably,
- shell remains non-hostile,
- zombie vocal leakage is suppressed,
- player-recognition/aggression did not visibly appear,
- TEST 02 movement produces real displacement and committed final position,
- movement still looks segmented / snap-like rather than like natural human walking,
- shell still looks zombie-like.

### 2. Current `IsoZombie` visual failure is not just “appearance data missing”
New instrumentation repeatedly showed strong data truth such as:
- `descOk=true`
- `visualOk=true`
- `skinOk=true`
- `wornOk=true`
- `itemVisualOk=true`

But final failure still converged on:
- `presentationRole=reanimated_zombie`
- `roleOk=false`
- `guardBlocked=not_in_world`
- `failCode=fail_presentation_role_zombie`

### 3. Timing-only rebuild is not the main answer
The post-runtime-settle rebuild experiment did not materially change in-game behavior.
Do not repeat that as a main experiment unless paired with a new mechanism.

### 4. `IsoSurvivor` is quarantined
`IsoSurvivor` did reveal a meaningful signal:
- logs could show `object=Survivor`
- `presentationRole=alive_npc`

But the current constructor/runtime path also showed:
- `bodyDamage=nil`
- `inWorld=false`
- engine crash in `IsoGameCharacter.updateInternal`
- null-body-damage dereference during update

Therefore the lane is not just “buggy”; it is currently crash-prone.

## Commits added during this session

### IsoZombie instrumentation / investigation
- `e430567` — `Add appearance failure taxonomy probes`
- `3496670` — `Run one-shot rebuild after runtime settle`
- `723aef3` — `Trace role and guard runtime blockers`

### IsoSurvivor A/B activation and quarantine-era attempts
- `f45d513` — `Wire IsoSurvivor into debug A/B test lane`
- `cfd19d0` — `Let IsoSurvivor settle before rejecting`
- `cfe0829` — `Skip unsupported visual APIs for IsoSurvivor`

### Safety follow-up after crash evidence
- pending in this same session after the handoff doc: disable/quarantine the IsoSurvivor UI/debug rail so it cannot be casually retriggered

## Most important detailed report

Read this first next time:
- `docs/EXPERIMENT_REPORT_2026-03-29_ISOZOMBIE_ISOSURVIVOR.md`

Also updated:
- `docs/TEST_LOG_HISTORY.md`

## Recommended next step

### Immediate
- keep `IsoSurvivor` disabled in the debug/test rail
- do not re-run TEST 01B on the current constructor path

### Strategic
If another alt carrier experiment is attempted, do not start from the in-game harness first.
Start from a constructor/runtime contract review and answer:

> Which Build 42 actor classes can be constructed from Lua such that they survive `IsoGameCharacter.updateInternal` without null runtime members like `BodyDamage`?

### If continuing on `IsoZombie`
The next useful experiments should focus on **zombie presentation ownership**, not general appearance reapplication.
That means:
- role/presentation authority,
- alpha/culling ownership,
- model registration / render-path implications,
- or a more deliberate actor-class escape plan.

## Explicit do-not-repeat list

Do not casually repeat these without a new patch/hypothesis:
- plain `IsoZombie` TEST 01~03 just to re-confirm zombie-looking visuals
- post-runtime-settle rebuild as a standalone idea
- current-path `IsoSurvivor` TEST 01B spawn attempt
- generic “maybe skin/clothes didn’t apply” reasoning

## One-line handoff summary

The branch is now understood as:
- **`IsoZombie` = stable enough to study, but zombie-role trapped**
- **`IsoSurvivor` = alive-role hint, but engine-unsafe**
