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
- `docs/experiments/2026-03-29_EXPERIMENT_FULL_DAY_FINAL_REPORT.md`

Also useful:
- `docs/experiments/2026-03-29_EXPERIMENT_ISOZOMBIE_ISOSURVIVOR_REPORT.md`
- `docs/testing/2026-03-13_TESTING_LOG_HISTORY.md`

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
- do not casually repeat the final three pre-Bandits LWN experiments either; those are now documented in `docs/retired-bandits/2026-03-29_BANDITS_RETIRED_LAST_LWN_EXPERIMENT_PACKAGE_BEFORE_ADOPTION.md`

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

## Late-session addendum — Bandits adoption actually started

After this handoff was first written, late-session follow-up work continued on the new branch direction and should be treated as the newest context:

1. `c82f8c6` — `Add Bandits probe checkpoints and settle reprobe`
   - user-tested result still looked zombie-like,
   - but `console.txt` proved the Bandits probe was **not** a no-op,
   - key signals included:
     - `bProbe=yes`
     - `bEffect=partial_visual_shift`
     - `bPostRole=reanimated_zombie`
     - `bPostFail=fail_presentation_role_zombie`

2. `14ab8b2` — `Promote Bandits-first dummy build lane`
   - the minimal dummy lane now has a test path where Bandits-style direct stamping is promoted from trailing helper to main build step,
   - the old heavier dummy post-build carrier stack is reduced toward a minimal shell-lane state in that test path.

3. `acda710` — `Trim debug menu to active test flow`
   - the active test menu was reduced to the current branch question only:
     - `TEST RESET`
     - `TEST 01`
     - `TEST 02`
     - `TEST 03`
     - `TEST STATUS`

4. `98d952a` — `Throttle noisy guard and dummy shell logs`
   - repeated low-value guard / dummy-contract spam was reduced,
   - while preserving the lines that directly answer the current experiment.

5. Latest late-session in-game result after the Bandits-first build lane patch:
   - `bFirst=yes`
   - `bFirstMode=idle`
   - `bEffect=partial_visual_shift`
   - visible-state diffs still change,
   - but final failure still remains zombie-owned:
     - `presentationRole=reanimated_zombie`
     - `failCode=fail_presentation_role_zombie`

6. One important instrumentation caveat now exists:
   - `MOVE SUMMARY` may still show `bPostRole=none` / `bPostFail=none` in the Bandits-first lane,
   - but that is currently a summary-field mismatch, not proof that no post-flags state existed.
   - The underlying checkpoint lines already show the post-min-flags state still landing at zombie-owned failure.

Read these documents before resuming that line:
- `docs/work-notes/2026-03-29_WORK_NOTES_LATE_END_OF_DAY_WRAPUP.md`
- `docs/retired-bandits/2026-03-29_BANDITS_RETIRED_FIRST_BUILD_LANE.md`

## Exact next-session start order

1. Read `docs/work-notes/2026-03-29_WORK_NOTES_LATE_END_OF_DAY_WRAPUP.md`
2. Read the 2026-04-04 instrumentation note appended to `docs/testing/2026-03-13_TESTING_LOG_HISTORY.md`
3. Do **not** spend the first test proving the same old visual outcome again; use the new checkpoint/transition fields to locate the first zombie-owned transition point
4. Then run:
   - `TEST RESET`
   - `TEST 01`
   - `TEST STATUS`
   - `TEST 02`
   - `TEST STATUS`
   - `TEST 03`
   - `TEST STATUS`
5. Read the new summary fields in this exact order:
   - `wr*` (world-registration checkpoint)
   - `ar*` (alpha-repair checkpoint)
   - `bPost*` (Bandits-first post-build checkpoint)
   - `trRole*` / `trFail*` (transition point and likely cause)
   - `firstZombie*` / `firstFail*` (first observed irreversible-looking failure point)
6. Main branch question for that run:
   - does `presentationRole=reanimated_zombie` first appear during world registration,
   - after alpha repair,
   - during refresh/model pass,
   - or only at the Bandits-first post-build checkpoint?

## Addendum — instrumentation work completed on 2026-04-04 before the next home test

The late-session to-do items listed above have now been completed on branch `spike/bandits-visual-probe-v1`.

The following commits were added specifically to make the next in-game run more causal and less ambiguous:

- `74c803b` — `Fix Bandits-first post-build checkpoint summary`
- `ecc92af` — `Add structured presentation checkpoints for pre-test diagnosis`
- `48b39c3` — `Track presentation role and failure transitions`
- `75ac613` — `Summarize likely causes for presentation transitions`

### What these new fields mean at a glance

- `bPost*`
  - Bandits-first post-build snapshot after post-min-flags recognition was fixed.
- `wr*`
  - the most recent world-registration checkpoint snapshot.
- `ar*`
  - the most recent alpha-repair checkpoint snapshot.
- `cp*`
  - the most recent generic presentation checkpoint snapshot.
- `trRole*`
  - the most recent role transition, if one occurred.
- `trFail*`
  - the most recent failure-code transition, if one occurred.
- `firstZombie*`
  - the first checkpoint where zombie-owned role was observed after tracked observation began.
- `firstFail*`
  - the first checkpoint where a concrete failure code was observed after tracked observation began.

### How to interpret the new cause strings

Treat the `*Cause` fields as **likely-cause shorthand**, not absolute proof.
They are meant to reduce ambiguity fast during live testing.

Examples:
- `zombie_role_after_world_registration:model_unregistered`
  - the first observed zombie-role transition happened at a world-registration checkpoint and model registration was still not healthy.
- `fail_role_zombie_after_alpha_repair:alpha_zeroish`
  - the first observed fail-code transition to zombie-role failure aligned with alpha-repair timing and zero-ish alpha state still mattered.
- `refresh_model_checkpoint`
  - the checkpoint itself likely belongs to the refresh/model layer, even if no hard transition happened at that exact line.
- `bandits_probe_checkpoint`
  - the observed state belongs to the Bandits-first probe path and should be compared against `wr*` / `ar*` rather than treated in isolation.

### What should count as progress in the next test

Progress is **not** “the NPC still looked zombie-like, same as before.”
Progress is any test that cleanly answers one of these:

- zombie-role trap is already present by world registration,
- zombie-role trap appears only after alpha repair,
- zombie-role trap appears only after refresh/model pass,
- Bandits-first post-build state is still the first clear zombie-owned checkpoint,
- or role stays stable while only fail-code transitions later.

## One-line handoff summary

The branch is now best understood as:
- **`IsoZombie` = stable enough to study, but zombie-role trapped**
- **late-session Bandits probe = real partial visual shift, but still loses final role ownership**
- **Bandits-first build lane = implemented and confirmed active, but still blocked by zombie-owned presentation/runtime truth**
- **next session = fix summary mismatch, then instrument the exact post-world-registration / post-alpha checkpoint where zombie-owned presentation still survives**
- **`IsoSurvivor` = alive-role hint, but engine-unsafe**
- **`IsoPlayer` = runtime-valid, but still non-materialized / non-registered visually**
