# CODE AUDIT — 2026-04-04

## Scope

This audit was performed after repeated live tests on branch `spike/bandits-visual-probe-v1`, with the explicit goal of:

1. adding more reliable runtime evidence for the real execution path,
2. checking whether recent instrumentation was actually attached to the hot path,
3. reviewing the project codebase for obvious syntax, entrypoint, and flow mismatches,
4. documenting both fixed issues and still-open risks before the next test cycle.

Repository path:
- `/mnt/c/Users/seanr/Zomboid/mods/LivingWorldNPC`

Date:
- 2026-04-04 (KST)

---

## What was changed in this pass

### 1. Boot markers added

Unconditional one-line boot markers were added so the next test can confirm which files are actually being loaded by the game runtime:

- `42/media/lua/client/23_LWN_ActorFactory.lua`
  - `[LWN][Boot] file=23_LWN_ActorFactory`
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
  - `[LWN][Boot] file=35_LWN_Carrier_IsoZombie`
- `42/media/lua/client/92_LWN_DebugTools.lua`
  - `[LWN][Boot] file=92_LWN_DebugTools`

These markers are intentionally unconditional because the previous problem was not lack of detail but uncertainty about whether the expected file was even participating in the live code path.

### 2. ActorFactory-side Bandits markers added

Because `[LWN][Checkpoint]` lines from `ActorFactory` already appeared reliably in `console.txt`, Bandits probe instrumentation was moved deeper into the path that clearly executes.

New unconditional markers were added around `Factory.applyBanditsStyleVisualProbe(...)`:

- `applyBanditsStyleVisualProbe.enter`
- `applyBanditsStyleVisualProbe.after_direct_copy`
- `applyBanditsStyleVisualProbe.after_bridge`
- `applyBanditsStyleVisualProbe.after_refresh`
- `applyBanditsStyleVisualProbe.ready`
- `applyBanditsStyleVisualProbe.actor_nil`

Marker prefix:
- `[LWN][BanditsFactory]`

The intent is to stop guessing whether Carrier-side Bandits checkpoints are on the hot path and instead observe the direct visual probe at the point where it actually runs.

### 3. TestAction markers added

The test harness now emits explicit action-entry markers to `console.txt` for the following actions:

- `TEST_RESET`
- `TEST_01_BEGIN`
- `TEST_01_READY`
- `TEST_02_BEGIN`
- `TEST_02_READY`
- `TEST_03_BEGIN`
- `TEST_03_READY`
- `TEST_04_BEGIN`
- `TEST_04_COMPLETE`
- `TEST_STATUS`
- `ISOPLAYER_PROBE_BEGIN`
- `ISOPLAYER_PROBE_READY`

Marker prefix:
- `[LWN][TestAction]`

These markers live in `42/media/lua/client/92_LWN_DebugTools.lua` and are intended to answer a simple but critical question: did the expected debug/test action actually execute?

### 4. TEST 04 menu mismatch fixed

Static review found a real flow mismatch:

- the automation checklist after TEST 03 explicitly told the user to click TEST 04,
- but the current debug context menu did **not** expose a TEST 04 item.

This has now been fixed in:
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua`

Added menu item:
- `TEST 04 - Return/Recovery Check`

This was a genuine UI/flow inconsistency, not just a cosmetic preference.

---

## Static verification performed

### 1. Full Lua syntax / load check

A repository-wide syntax/load verification was run across all Lua files under `42/media/lua`.

Result:
- **34 / 34 Lua files passed** `loadfile(...)`
- no syntax-level failures were found in this audit pass

This does **not** prove runtime correctness against the Project Zomboid engine, but it does remove the simpler class of broken-file / parse-failure regressions.

### 2. Test menu hook verification

The project was checked for the current debug test hook path.

Verified hook chain:
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua`
  -> `LWN.DebugTools.resetAutomatedIsoZombieTest`
  -> `LWN.DebugTools.runAutomatedIsoZombieTest01`
  -> `LWN.DebugTools.runAutomatedIsoZombieTest02`
  -> `LWN.DebugTools.runAutomatedIsoZombieTest03`
  -> `LWN.DebugTools.runAutomatedIsoZombieTest04` (fixed in this pass)
  -> `LWN.DebugTools.dumpAutomatedIsoZombieTestStatus`

Conclusion:
- after the TEST 04 menu fix, the visible UI flow and the checklist text are now aligned again.

### 3. Bandits instrumentation reference verification

A grep-based cross-check confirmed that the new marker families exist in the expected files:

- `[LWN][BanditsFactory]` in `23_LWN_ActorFactory.lua`
- `[LWN][BanditsPath]` and `[LWN][BanditsCheckpoint]` in `35_LWN_Carrier_IsoZombie.lua`
- `[LWN][TestAction]` in `92_LWN_DebugTools.lua`
- Boot markers in all three target files

This means the new instrumentation is present in source and syntactically valid.
The next live test must determine which of these families actually appear in `console.txt`.

### 4. Duplicate-file / wrong-copy suspicion check

A search under the user Zomboid tree was performed for core files such as:

- `35_LWN_Carrier_IsoZombie.lua`
- `23_LWN_ActorFactory.lua`
- `92_LWN_DebugTools.lua`

No duplicate project copies were found under the expected `Zomboid/mods/LivingWorldNPC` tree that would obviously explain the hot-path mismatch by simple file duplication.

Conclusion:
- the earlier mismatch is less likely to be caused by accidentally editing the wrong duplicate mod copy.

---

## Findings from code review

### Fixed finding A — test flow mismatch

**Issue**
- TEST 03 instructed the user to proceed to TEST 04, but no TEST 04 menu option existed.

**Impact**
- made the intended diagnostic flow incomplete from the UI,
- increased ambiguity during live testing,
- created a false impression that TEST 04 might be obsolete when the harness still expected it.

**Resolution**
- added `TEST 04 - Return/Recovery Check` to the debug context menu.

### Fixed finding B — runtime path visibility was too weak

**Issue**
- previous debugging relied too heavily on late-stage summaries and some Carrier-side markers that did not show up reliably in `console.txt`.

**Impact**
- made it hard to distinguish:
  - file not loaded,
  - function not called,
  - function called but marker path not reached,
  - stale modData reappearing from an older pass.

**Resolution**
- added unconditional boot markers,
- added explicit test-action entry markers,
- moved critical Bandits probe instrumentation into `ActorFactory` where checkpoint evidence was already known to appear reliably.

### Fixed finding C — review checklist and UI were no longer synchronized

This is closely related to Finding A, but worth stating separately:
- the live debug/testing workflow had already drifted enough that documentation/checklist expectations and concrete UI affordances were out of sync.
- this class of mismatch is dangerous because it can look like a runtime bug when it is actually a test harness ergonomics bug.

---

## Important observations that remain open

### Open risk 1 — Carrier-side markers still may not be on the real hot path

Before this audit pass, repeated live tests showed:
- `ActorFactory` checkpoints appeared reliably in `console.txt`,
- `Carrier`-side Bandits path/checkpoint markers did **not**.

This can mean one of the following:

1. the real test path does not execute the exact Carrier-side block that was instrumented,
2. a different rebuild path is populating the same modData summary fields,
3. the direct probe runs but the relevant helper wrapper is bypassed.

The new Boot / TestAction / BanditsFactory markers are meant to answer this in the next test.

### Open risk 2 — late summaries can still lag the real seed point

Current evidence still supports the view that:
- `world=true` and `alpha=1.00` are often restored later,
- while `presentationRole=reanimated_zombie` and `fail_presentation_role_zombie` remain.

This continues to suggest that the decisive zombie-owned seed happens **before** the later world-registration / alpha-repair / refresh checkpoints.

However, until the new early markers are observed live, the exact upstream seed point is still not proven.

### Open risk 3 — debug output is now intentionally heavier

This pass added several unconditional console markers.
That is appropriate for the current investigation, but it should be treated as temporary diagnostic instrumentation.
Once the hot path is proven and the real fault is isolated, these markers should probably be reduced or consolidated.

---

## Best-effort full-project review notes

This was a static and flow-oriented audit, not a formal semantic proof.
Still, several useful conclusions can be stated with confidence.

### 1. No syntax-level regressions were found
- all Lua files parsed successfully.

### 2. No obvious duplicate-mod explanation was found
- the expected project tree appears singular in the user Zomboid directory.

### 3. The live debug/test UI had at least one real flow bug
- missing TEST 04 menu option.
- now fixed.

### 4. The current project contains substantial debug/instrumentation layering
This is not inherently wrong, but it increases the chance of:
- stale modData confusion,
- old summary fields surviving longer than intended,
- parallel diagnostic systems telling slightly different stories.

The previous addition of state resets (`clearBanditsObservationState`) was therefore directionally correct and should remain in place unless the next runtime evidence disproves its necessity.

### 5. One pre-existing TODO remains outside the current bug lane
Static grep found a pre-existing TODO in:
- `42/media/lua/client/30_LWN_Legacy.lua`

This was not directly related to the current alive-presentation / Bandits-first investigation and was not modified in this pass.

---

## Recommended next live verification

After restarting the game completely, the next test should first search `console.txt` for these markers in this order:

1. `[LWN][Boot]`
   - confirm the three target files actually loaded:
     - `23_LWN_ActorFactory`
     - `35_LWN_Carrier_IsoZombie`
     - `92_LWN_DebugTools`

2. `[LWN][TestAction]`
   - confirm each requested test action actually executed:
     - reset
     - test 01
     - test 02
     - test 03
     - test status
     - test 04 if used

3. `[LWN][BanditsFactory]`
   - confirm `applyBanditsStyleVisualProbe(...)` entered and how far it progressed.

4. `[LWN][BanditsPath]` / `[LWN][BanditsCheckpoint]`
   - compare whether Carrier-side path markers appear at all.

5. existing `[LWN][Checkpoint]` lines
   - correlate the new upstream markers with the previously reliable world/alpha/refresh checkpoints.

The first useful branching question for the next test is:

- Do Boot markers appear for all three files?

If **no**:
- the live runtime is not loading what the repo currently contains.

If **yes**, but `[LWN][TestAction]` does not appear:
- the UI/test route is not calling the expected `DebugTools` entrypoints.

If `[LWN][TestAction]` appears but `[LWN][BanditsFactory]` does not:
- the test ran, but the Bandits direct probe was not actually entered.

If `[LWN][BanditsFactory]` appears and `[LWN][BanditsPath]` still does not:
- the real hot path likely lives closer to `ActorFactory` than to the currently instrumented Carrier-side early checkpoints.

---

## Files touched in this audit pass

- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua`
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

---

## Audit conclusion

At the end of this pass:

- the project is syntax-clean,
- the debug test UI flow is more internally consistent than before,
- the next runtime test should be able to answer file-load vs test-action vs Bandits-hot-path questions much more decisively,
- and the codebase now has a documented audit trail for what was checked, what was fixed, and what is still open.

The most important unresolved question is no longer “does the NPC still look zombie-like?”
The next high-value question is:

**Which instrumentation family actually appears first in the live run, and therefore which file/function is truly on the hot path when the zombie-owned presentation state is being seeded?**
