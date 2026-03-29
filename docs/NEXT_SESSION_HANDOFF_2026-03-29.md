# Next Session Handoff — 2026-03-29

Current work branch: `spike/minimal-neutral-dummy`

## Executive summary

Today’s session established a much sharper embodiment map than at session start:

- `IsoZombie` remains the only stable active gameplay test lane.
- `IsoZombie` is **not** primarily failing because of missing descriptor/clothing/skin truth.
- The strongest current `IsoZombie` blocker remains zombie-owned presentation/runtime truth.
- `IsoSurvivor` provided useful actor-class evidence but is quarantined because the current constructor/runtime path can hard-crash the engine.
- `IsoPlayer` became the most interesting alternative lane of the day because it survives as an alive-class actor, but it still does not visibly materialize.

## Most important document to read first next time

Read this before touching code:
- `docs/EXPERIMENT_REPORT_2026-03-29_FULL_DAY_FINAL.md`

Also useful:
- `docs/EXPERIMENT_REPORT_2026-03-29_ISOZOMBIE_ISOSURVIVOR.md`
- `docs/TEST_LOG_HISTORY.md`

## What is settled enough that it should not be re-proved casually

### 1. Current `IsoZombie` minimal dummy behavior
Repeated full-restart tests already established all of the following together:
- spawn succeeds reliably,
- shell remains non-hostile,
- zombie vocal leakage is suppressed,
- player-recognition/aggression did not visibly appear,
- TEST 02 movement produces real displacement and committed final position,
- movement still looks segmented / snap-like rather than natural human walking,
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

Therefore the lane is not just buggy; it is currently crash-prone.
Do not re-run it casually.

### 5. `IsoPlayer` survives but still does not visibly materialize
This is the most important end-of-day update.
Repeated logs showed that `IsoPlayer` can reach:
- `alive_npc`
- `world=true`
- `squarePresent=true`
- `body=true`
- `humanVisual=true`
- `descriptor=true`
- `inventory=true`
- stable embodied actor state

But even after alpha-loop mitigation and create-hook fallback completion, the lane still ended with:
- `modelRegistered=nil`
- no visible NPC on screen
- recurring console-side evidence around `ModelManager.Add(...)` and `legsSprite.modelSlot` being null

## Commits added during this session

### IsoZombie instrumentation / investigation
- `e430567` — `Add appearance failure taxonomy probes`
- `3496670` — `Run one-shot rebuild after runtime settle`
- `723aef3` — `Trace role and guard runtime blockers`

### IsoSurvivor A/B activation and quarantine-era attempts
- `f45d513` — `Wire IsoSurvivor into debug A/B test lane`
- `cfd19d0` — `Let IsoSurvivor settle before rejecting`
- `cfe0829` — `Skip unsupported visual APIs for IsoSurvivor`
- `0eb2a42` — `Quarantine IsoSurvivor test rail and document 2026-03-29 findings`

### IsoPlayer viability / visibility / materialization investigation
- `f31ac6c` — `Add IsoPlayer viability probe test rail`
- `8fe0d91` — `Add phase-1 IsoPlayer visibility stabilization`
- `702228f` — `Block zero-target alpha loop for IsoPlayer`
- `79124a9` — `Guard IsoPlayer model registration until slot ready`
- `6c20bc7` — `Add IsoPlayer create-hook fallback completion`
- `acfe3f0` — `Trace IsoPlayer sprite slots before model add`
- `ce88dbe` — `Use minimal IsoPlayer materialization call set`

## Recommended next-session stance

### Immediate operational stance
- keep `IsoSurvivor` disabled in the debug/test rail
- do not re-run current-path `IsoSurvivor` TEST 01B
- do not blindly re-run the same `IsoPlayer` probe unless there is a **new model/materialization hypothesis**

### Best current exact question
If continuing the alt-carrier path, the next question should be:

> Which exact engine or Lua call path is still provoking `ModelManager.Add` while `chr.legsSprite.modelSlot` is null on the `IsoPlayer` lane?

### What NOT to do next session
Do not restart with:
- plain `IsoZombie` TEST 01~03 just to prove the same zombie-looking result again,
- post-runtime-settle rebuild as a standalone idea,
- current-path `IsoSurvivor` spawn retry,
- another `IsoPlayer` probe that simply repeats the same code path without a new materialization hypothesis,
- generic “maybe clothes/descriptor didn’t apply” reasoning.

## One-line handoff summary

The branch is now best understood as:
- **`IsoZombie` = stable enough to study, but zombie-role trapped**
- **`IsoSurvivor` = alive-role hint, but engine-unsafe**
- **`IsoPlayer` = runtime-valid, but still non-materialized / non-registered visually**
