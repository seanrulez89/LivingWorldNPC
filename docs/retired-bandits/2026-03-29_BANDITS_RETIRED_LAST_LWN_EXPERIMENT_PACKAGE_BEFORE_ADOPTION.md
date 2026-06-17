# Last LWN Experiment Package Before Bandits — 2026-03-29

Branch: `spike/minimal-neutral-dummy`

Purpose of this document:
- record the final three in-framework `IsoZombie` experiments that were explicitly meant to exhaust the remaining pre-Bandits experiment space,
- capture their exact outcomes,
- make it clear which hypotheses are now weakened enough that they should not be casually repeated.

---

## Executive summary

Three final `IsoZombie`-within-LWN experiments were attempted after the `IsoSurvivor` and `IsoPlayer` alt-carrier spikes had already shown major limitations.

The three experiments were:
1. **Guard/Role Minimal Override Lane**
2. **Overwrite Tracker / Reassert Cadence**
3. **Alive-State Animator Reset A/B (runtime-settle version only)**

Final verdict:
- Experiment 1 reached the target codepath but did **not** produce the hoped-for visible/presentation change.
- Experiment 2 produced a strong negative result: the branch is **not** merely achieving a better state and later overwriting it.
- Experiment 3, in its runtime-settle form, did **not actually fire** because the current lane never meaningfully reached the needed runtime-settle state transition.

Taken together, these three results strongly suggest that the currently identified pre-Bandits `IsoZombie` experiment space has been substantially exhausted.

---

## Experiment 1 — Guard/Role Minimal Override Lane

### Goal
Test whether a very narrow ownership/guard relaxation inside the existing `IsoZombie` minimal-dummy lane could meaningfully alter the final presentation read.

The experiment intentionally did **not** do a full guard bypass.
It only relaxed the zombie/reanimated block for these two actions:
- `restore_false_flags`
- `repair_alpha`

### Code change
- `aed2e69` — `Add minimal dummy role-guard relax lane`

### What was changed
- A minimal-dummy-only opt-in flag was stamped in modData.
- `presentationRestoreBlockedReason(...)` gained action-sensitive relaxation for the two actions above.
- Debug summary gained an `rgRelax` field.

### In-game result
- No meaningful visible improvement was observed by the user.
- The shell still looked zombie-like.
- Movement still did not become convincingly human-read.

### Log result
The patch definitely activated:
- `rgRelax=yes`
- role/guard relaxation metadata was present
- some alpha-repair behavior was indeed permitted more aggressively after world-state improved

But final failure still converged on the same signature:
- `roleOk=no`
- `guardBlocked=not_in_world`
- `failCode=fail_presentation_role_zombie`
- `rgRole=reanimated_zombie`

### Interpretation
This matters because it shows that lightly relaxing those two guard actions is **not enough** to break the final zombie-owned presentation read.
In other words:
- ownership/guard is still relevant,
- but the two chosen relax points are not sufficient to produce the desired visible human-like result.

### Repeat-prevention rule
Do **not** repeat this exact narrow relax lane unless the next patch changes the scope of what is being relaxed.
The result of this exact version is already known.

---

## Experiment 2 — Overwrite Tracker / Reassert Cadence

### Goal
Determine whether the current branch briefly reaches a better appearance state and then loses it, or whether it simply enters the same bad state from the beginning and stays there.

### Code change
- `14d0cb6` — `Track appearance overwrite cadence for dummy lane`

### What was added
- cadence scoring of current appearance truth
- best-so-far score and stage
- last-seen score and stage
- overwrite detection based on score drop and/or signature drift after a better state
- summary fields:
  - `owBest`
  - `owNow`
  - `owStage`
  - `owSeen`
  - `owReason`

### In-game result
- No new visible phase was perceived.
- The shell still looked like the same zombie-like managed shell throughout the test.

### Log result
This experiment produced the most useful negative result of the package.
Repeatedly:
- `owBest=5`
- `owNow=5`
- `owSeen=nil`
- `owReason=none`
- overwrite tracker lines showed `overwrite=false`

The dominant state remained anchored at the same stage:
- `owStage=CarrierIsoZombie.sync.rebuild.probe`

### Interpretation
This strongly weakens the theory that the branch is achieving a better human-like state and then later losing it to overwrite/reassert behavior.
The evidence now points more strongly to this:
- the shell enters the same failure basin very early,
- and then simply stays in it.

### Repeat-prevention rule
Do **not** casually return to the “maybe it briefly worked and got overwritten” explanation on this branch without a genuinely new signal.
This experiment materially weakened that hypothesis.

---

## Experiment 3 — Alive-State Animator Reset A/B

### Goal
Test whether a one-time alive-state animator/state reset at the runtime-settle boundary could improve zombie-like posture/read or hopping-like locomotion read.

### Code change
- `7e65017` — `Add runtime-settle alive reset experiment`

### What was attempted
- a minimal-dummy-only one-shot alive-state rebuild was added
- trigger point chosen for the first pass:
  - **runtime-settle completion**
- summary fields added:
  - `arReset`
  - `arTouched`

### Expected meaning
If this fired and improved visual read, it would suggest that the shell was entering the wrong animation/state bucket and could be nudged into a more alive-like read without abandoning the current carrier.

### Actual result
The experiment did **not** produce a meaningful test of that hypothesis because the reset path did not actually execute in the tested runs.
The summary stayed:
- `arReset=nil`
- `arTouched=nil`

And the broader failure signature remained unchanged:
- `failCode=fail_presentation_role_zombie`
- `guardBlocked=not_in_world`
- `rgRole=reanimated_zombie`
- cadence values unchanged from Experiment 2

### Interpretation
This does **not** prove that all alive-state reset ideas are impossible.
What it proves is narrower:
- the **runtime-settle-triggered** version of the reset experiment does not currently become a meaningful active test, because the current branch never cleanly reaches the needed runtime-settle boundary in a way that fires the experiment.

### Repeat-prevention rule
Do **not** re-run this exact runtime-settle reset version expecting new information.
If alive-state reset is revisited later, it must use a different trigger point (for example a deliberately different post-arrival or forced-stage trigger), or it will simply reproduce the same non-firing result.

---

## Combined interpretation of the 3-experiment package

### What is now strongly weakened

1. **Narrow guard relax is enough**
   - weakened by Experiment 1

2. **A better state exists but gets overwritten later**
   - strongly weakened by Experiment 2

3. **A runtime-settle-triggered alive reset is the missing switch**
   - weakened in its current trigger form by Experiment 3

### What this means strategically

The originally documented pre-Bandits experiment order said:
- exhaust the remaining experiment space inside the current LWN approach first,
- then only consider narrow Bandits borrowing.

After today’s package, the remaining high-value pre-Bandits LWN space looks much smaller.
It is now hard to justify many more same-lane `IsoZombie` micro-variants unless they are genuinely new in mechanism and not just small variations of the same three ideas.

---

## Final practical takeaway

At the end of this package, the branch is best described as:
- **stable managed `IsoZombie` shell**
- **still zombie-presentation-owned**
- **not mainly failing because of overwrite/reassert**
- **not meaningfully rescued by the tested narrow guard relax**
- **not meaningfully tested by the runtime-settle reset trigger because the trigger did not really fire**

This does not mathematically prove there is zero possible future LWN-only idea.
But it does mean that the specifically identified “last useful LWN experiments before Bandits” have now largely been spent.

That is enough to justify a careful strategic pivot discussion.
