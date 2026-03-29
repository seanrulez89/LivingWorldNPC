# End-of-Day Wrap-Up — 2026-03-29 Late Session

Branch at end of session: `spike/bandits-visual-probe-v1`

This document is the authoritative late-session wrap-up for what was actually done after the earlier 2026-03-29 handoff/report set had already been written.

It exists because tonight's work materially changed the branch direction and test tooling:

- Bandits-style adoption moved from planning into real code,
- the debug menu was trimmed to the active test flow,
- log noise was reduced,
- and the newest test result sharpened the next exact question.

---

## 1. Session intent when this late block started

At the start of this late-session block, the important context was already settled:

- `IsoZombie` had already won as the practical shell.
- the final three **within-LWN** `IsoZombie` experiments were already completed and should not be casually re-run as if still undecided:
  - role/guard relax,
  - overwrite cadence tracking,
  - runtime-settle alive reset.
- the branch had already moved beyond “one more current-LWN tweak” and into **gradual Bandits-style adoption**.

So the work done here was not a restart of the old discussion.
It was the first concrete implementation pass on that Bandits adoption plan.

---

## 2. What was coded tonight

### 2.1 `c82f8c6` — Add Bandits probe checkpoints and settle reprobe

Purpose:
- keep the existing LWN build path,
- add a Bandits-style direct visual stamping probe,
- and instrument the result much more clearly.

What this patch added:
- `banditsVisualProbe.after_direct_copy`
- `banditsVisualProbe.ready`
- post-probe / post-basic-flags checkpoints
- post-runtime-settle re-probe path
- net-effect classification such as:
  - `no_effect`
  - `partial_visual_shift`
  - `direct_copy_survived`
  - `direct_copy_reverted_before_refresh_end`
- debug summary fields for:
  - `bProbe`
  - `bStage`
  - `bEffect`
  - `bPostRole`
  - `bPostFail`

Why it mattered:
- it answered whether the Bandits-style direct stamping pass was actually doing anything,
- instead of leaving that question buried in diffuse logs.

### 2.2 `14ab8b2` — Promote Bandits-first dummy build lane

Purpose:
- stop treating Bandits-style stamping as a tiny trailing helper,
- and instead promote it into the main dummy appearance build step.

What changed conceptually:
- old path: LWN humanization first, Bandits-style probe later,
- new test path: Bandits-style stamping becomes the main dummy appearance build step.

What changed in code:
- added `ISOZOMBIE_BANDITS_FIRST_BUILD_LANE = true`
- added a Bandits-first dummy carrier state
- in the minimal dummy path:
  - `ShellHumanizer.applyInitial` can still seed the descriptor,
  - but the old `maintain` / legacy rebuild path is not treated as the main visual authority in that lane,
  - Bandits-style direct stamping is elevated to the main build step,
  - post-build carrier setup is reduced toward a minimal shell lane rather than the heavier posture/illusion bundle.

Intent:
- test whether the old heavier post-build refresh stack itself was helping reassert the zombie-owned presentation basin.

### 2.3 `acda710` — Trim debug menu to active test flow

Purpose:
- clean the in-game debug menu before testing.

What changed:
- removed extra submenu nesting,
- removed items not relevant to the active branch question.

The menu was simplified to:
- `TEST RESET - Clear State`
- `TEST 01 - Spawn Baseline (IsoZombie)`
- `TEST 02 - Command Walk`
- `TEST 03 - Capture Move`
- `TEST STATUS - Dump Current`

What was intentionally hidden:
- `TEST 01P - IsoPlayer Viability Probe`
- `TEST 01B - Spawn Baseline (IsoSurvivor)`
- `TEST 04 - Return Check`

Reason:
- those options were no longer part of the active question and only increased test friction / confusion.

### 2.4 `98d952a` — Throttle noisy guard and dummy shell logs

Purpose:
- keep the logs useful for the active experiment,
- while reducing repeated low-information console spam.

What was throttled harder:
- `PresentationGuard` repeated alpha-repair noise,
- `restore_false_flags` repetition,
- repeated `dummy_contract_idle_applied` / `dummy_contract_move_applied` shell-contract traces.

What was intentionally kept:
- `TEST STATUS`
- `MOVE SUMMARY`
- `npc appearance ::`
- `bandits_probe_*`
- `banditsVisualProbe.after_direct_copy`
- `banditsVisualProbe.ready`

Reason:
- those are the lines that directly answer the branch's active question.

---

## 3. What was tested tonight

The user ran in-game tests after the late-session patches.

The most important run was the Bandits-first build lane validation run using the trimmed active menu flow.

### 3.1 Practical in-game result
- the shell still looked zombie-like.
- movement still worked in the minimal dummy lane.
- the branch did not gain a visual human breakthrough.

### 3.2 Console-level result
The new logs answered several questions much more clearly.

#### 3.2.1 Bandits-first build lane really did run
The test summary showed:
- `bFirst=yes`
- `bFirstMode=idle`

So there is no ambiguity anymore about whether the new lane was active.

#### 3.2.2 Direct visual effects were still only partial
The summary and appearance lines showed:
- `bEffect=partial_visual_shift`
- visible-state inputs changed, including skin / hair / item-visual counts / outfit values.

Example of real diff from console:
- `skin:F_ZedBody01_level1->F_ZedBody02_level1`
- `hair:RachelCurly->OverEyeCurly`
- `itemVisuals:7->8`
- `persistentOutfitId:-2143158176->-2143289026`

This confirms again that Bandits-style stamping is **not** a total no-op.

#### 3.2.3 Final ownership still stayed zombie-side
Despite the Bandits-first lane being active, the branch still ended with:
- `presentationRole=reanimated_zombie`
- `failCode=fail_presentation_role_zombie`
- `roleOk=false`

So the late-session result strengthened this interpretation:

> promoting Bandits-style stamping from trailing helper to main dummy build step is still not enough to break the final zombie-owned presentation trap.

#### 3.2.4 A stronger early blocker became more visible
The logs also showed that the actor is already in a weak state very early:
- `world=false` / `world=nil` at the initial Bandits-first build moment,
- `alpha=0.00`
- `targetAlpha=0.00`
- early guard failures around `not_in_world`.

That matters because it suggests the unresolved problem is not only “what visual values were copied,” but also:
- when world registration becomes authoritative,
- when alpha is allowed to normalize,
- and whether zombie presentation ownership is already asserted before the human-like pass can truly stick.

---

## 4. Important lessons from tonight

### 4.1 What is now settled enough to remember
- The branch is **past** the old “should we keep trying tiny LWN-only appearance tweaks?” stage.
- The final three pre-Bandits current-LWN experiments are already done and should not be restarted casually.
- Bandits-style direct stamping definitely changes some appearance-related state.
- Even Bandits-first elevation still does **not** yet break the final zombie-owned presentation role.

### 4.2 What this does *not* mean
It does **not** mean the entire current direction is abandoned.

The current branch direction remains:
- keep the practical `IsoZombie` shell lane,
- keep the minimal dummy test harness and movement validation flow,
- but continue reducing the old LWN appearance authority,
- while borrowing more of the right **Bandits-style presentation/orchestration** logic.

What is being reduced is not the whole project direction.
What is being reduced is the assumption that the old LWN appearance build path should remain the final authority for the shell's visible state.

### 4.3 What tonight most strongly suggests
Tonight's strongest technical lesson is:

> the remaining wall looks less like “copy better appearance data” and more like “identify the exact runtime/presentation ownership stage where the shell becomes or remains zombie-owned.”

That means the next session should spend less time on generic restamping and more time on sharper causal checkpoints around:
- world registration,
- alpha restoration,
- and the first point at which final zombie role truth reappears or persists.

---

## 5. Known issues left open at end of session

### 5.1 `bPostRole` / `bPostFail` summary fields are currently misleading in the Bandits-first lane
The console checkpoint lines already show the real state after the minimal post-build flags stage, but the one-line debug summary can still show:
- `bPostRole=none`
- `bPostFail=none`

This is not a true “no data” situation.
It is a late-session instrumentation mismatch.

Why:
- the checkpoint writer stores `LWN_BanditsVisualProbePostFlags*` only for the legacy `after_basic_flags` stage name,
- but the Bandits-first lane now uses stage names like:
  - `bandits_first_after_min_flags`
  - `bandits_first_post_runtime_settle_after_min_flags`

So the one-line summary needs to be updated to treat those stages as the same family of post-flags checkpoints.

### 5.2 The strongest unresolved technical question at end of session
The best current exact question is now:

> After Bandits-first stamping, once world registration and alpha restoration have both had their chance, what exact stage still keeps or reasserts `presentationRole=reanimated_zombie` on the `IsoZombie` shell?

This is a better question than “did the Bandits stamping run?” because tonight already answered that with “yes, partially.”

### 5.3 Logging is improved but not perfect yet
The log-throttling patch helped.
The console is meaningfully more readable than before.

However, one family is still louder than ideal:
- repeated `repair_alpha` loops.

This is not the first thing to fix next session unless the console becomes unreadable again, but it is still a known cleanup candidate.

---

## 6. Exact recommended start for the next session

### 6.1 Read these first
In this order:
1. `docs/END_OF_DAY_WRAPUP_2026-03-29_LATE.md` (this document)
2. `docs/BANDITS_FIRST_BUILD_LANE_2026-03-29.md`
3. `docs/TEST_LOG_HISTORY.md`
4. `docs/NEXT_SESSION_HANDOFF_2026-03-29.md`

### 6.2 Confirm repo state
- branch should still be `spike/bandits-visual-probe-v1`
- latest relevant late-session commits should include:
  - `c82f8c6`
  - `14ab8b2`
  - `acda710`
  - `98d952a`

### 6.3 First code task next session
Before another in-game run, fix the summary instrumentation mismatch:
- make `bandits_first_after_min_flags`
- and `bandits_first_post_runtime_settle_after_min_flags`
feed the same `LWN_BanditsVisualProbePostFlagsRole/Fail/...` fields used by `MOVE SUMMARY`.

Reason:
- this is a small, high-value correction,
- and it removes a fake ambiguity (`bPostRole=none`) before the next test.

### 6.4 Second code task next session
Add one sharper checkpoint immediately after the shell has:
- entered the world successfully, and
- completed the first meaningful alpha recovery / registration pass.

What that checkpoint should answer:
- is the shell still already `reanimated_zombie` there?
- did role/fail change at all after world-registration + alpha recovery?
- is the zombie role already stable before later idle/move maintenance kicks in?

This should be a focused checkpoint, not a broad new logging explosion.

### 6.5 Then test in this order
- `TEST RESET`
- `TEST 01`
- `TEST STATUS`
- `TEST 02`
- `TEST STATUS`
- `TEST 03`
- `TEST STATUS`

Primary fields to inspect:
- `bFirst`
- `bFirstMode`
- `bEffect`
- `bPostRole`
- `bPostFail`
- `failCode`
- `guardBlocked`
- plus the `npc appearance ::` diff line

---

## 7. What not to do next session

Do **not** restart with these dead ends:
- do not go back to casually repeating the old three pre-Bandits current-LWN experiments,
- do not bring `IsoSurvivor` back into the menu or casual testing,
- do not re-open `IsoPlayer` as the main lane unless there is a fresh and very specific materialization hypothesis,
- do not interpret tonight's result as “Bandits is useless,”
- do not assume more generic visual stamping alone will solve the remaining wall.

---

## 8. One-paragraph handoff summary

Tonight's work turned the Bandits adoption plan into real branch state. First, a checkpoint-heavy direct visual probe proved that Bandits-style stamping is not a no-op: it causes real but partial visual shifts. Next, that stamping was promoted into a Bandits-first dummy build lane, replacing the old assumption that LWN humanization should remain the main appearance authority in the dummy path. The result still did not break the zombie-owned presentation trap: `presentationRole=reanimated_zombie` and `fail_presentation_role_zombie` survived. The next session should therefore start by fixing the new post-flags summary instrumentation mismatch and then add a sharper checkpoint immediately after world-registration/alpha recovery to identify where final zombie-owned presentation truth is still being held.
