# Minimal Dummy Move-Idle Handoff Retest — 2026-03-28

## Scope

This document captures the late-session state after the two most recent stabilization passes on `spike/minimal-neutral-dummy`:

- `91561dd` — `Fix dummy spawn scrub grace helpers`
- `70bebb0` — `Fix dummy move idle handoff`

Primary log analyzed:
- `/mnt/c/Users/seanr/Zomboid/Logs/2026-03-28_15-54_DebugLog.txt`

Goal of this retest:
- verify that the spawn-safe scrub hotfix still prevents old spawn regression,
- verify that the new move→idle handoff patch actually removes the post-arrival attack-like / in-place-stepping residue,
- document what still remains broken.

---

## Player-observed result

### TEST 01
- exactly one NPC spawned
- the shell still looked like a zombie
- no zombie vocal audio
- no aggression
- no player recognition
- the dummy stayed still

### TEST 02
- the actor did not play a convincing walking animation,
  but it **did** move across multiple intermediate positions and successfully reached the destination
- after arrival, the dummy kept the same visual shell but:
  - did **not** show attack-like posture
  - did **not** show in-place stepping
  - did **not** recognize or target the player
  - did **not** become aggressive when approached or shoved

### TEST 03
- no major new visible change
- the dummy remained quiet, still, and non-aggressive

### Cleanup / delete behavior
- `clean` still did not remove the NPC
- `delete` successfully removed the NPC

---

## Key log evidence

## 1. Spawn regression stayed fixed

Relevant lines:
- spawn grace / initial idle contract: `907`, `927-930`, `1026-1307`
- early TEST 01 summaries: `968-975`

What the log shows:
- `dummy_contract_idle_applied` appears immediately at spawn with:
  - `lane=dummy_idle`
  - `target=false`
  - `moving=false`
  - `path2=false`
- `dummy_scrub_skipped_spawn_grace` repeats many times during the grace window
- the TEST 01 summary reports:
  - `lane=dummy_idle`
  - `cmd=none/idle`
  - `attacking=no`
  - `target=no`
  - `path2=nil`
  - `appFail=yes`

Interpretation:
- the spawn-safe hotfix remained active and did not regress
- the branch stayed in the expected safe idle lane during initial embodiment
- the remaining failure at spawn is appearance, not aggression or command-state instability

---

## 2. Movement succeeded and committed correctly

Relevant lines:
- move queued summary: `2209-2216`
- move-lane contract during active move startup: `2259`, `2260`, `2273`, `2336`
- arrived summary: `5281-5288`, `5592-5593`

What the log shows:
- during actual move startup, `dummy_contract_move_applied` appeared only **4** times total
- the arrival summary later reported:
  - `lane=dummy_idle`
  - `cmd=designated_location/arrived`
  - `motor=arrived`
  - `commit=3753,10997,0`
  - `moving=no`
  - `attacking=no`
  - `target=no`
  - `path2=no`
  - `totalDelta=7.00`
  - `squareChanged=yes`
- command details also recorded:
  - `outcome=arrived`
  - `reason=dummy_move_arrived`
  - `distance=0.7071067811865476`

Interpretation:
- deterministic movement is now materially working
- committed position and visible position stayed aligned
- the old “move briefly, then snap back to anchor” regression did not reproduce here

---

## 3. The move→idle handoff patch appears to have worked

This is the most important result of the retest.

### Strong evidence that stale move authority no longer wins after arrival

Quick grep counts from the analyzed log:
- `dummy_contract_move_applied` = `4`
- `dummy_contract_idle_applied` = `195`
- `attacking=yes` = `0`
- `target=yes` = `0`
- `Deleted NPC LWN-000027` = `1`

Post-arrival stabilization evidence:
- after arrival, the log repeatedly shows `dummy_contract_idle_applied` with:
  - `target=false`
  - `moving=false`
  - `path2=false`
- representative lines after arrival / during idle maintenance:
  - `5495`, `5498`, `5499`, `5515`, `5516`, `5535`, `5536`, `5557`, `5558`, `5575`, `5578`, `5595`, `5611`, `5612`, `5616`, `5632-5656`
- there are **no** post-arrival `attacking=yes` or `target=yes` signals
- there are **no** LWN runtime exceptions in the analyzed run

Interpretation:
- before `70bebb0`, arrival could still devolve into apparent attack posture / in-place stepping because stale move authority kept letting the move shell reassert itself
- after `70bebb0`, the lane seen in summaries after arrival is now `dummy_idle`, not persistent `dummy_move`
- repeated idle shell reapplication after arrival strongly suggests that patch A+B fixed the previously dominant handoff bug at the right layer

Important nuance:
- some debug surfaces still show `cmdMove=true` in actor summaries after arrival
- in this run that no longer appears to be authoritative for shell enforcement
- the real runtime evidence is more important:
  - arrival summary is settled
  - lane stays `dummy_idle`
  - repeated idle shell enforcement wins
  - no aggression/target residue appears in behavior

---

## 4. Appearance / humanization is still the main blocker

Relevant lines:
- `930`
- `968-975`
- `5496-5497`
- `5517-5518`
- `5538-5539`
- `5576-5577`
- `5613-5614`
- `5635-5643`

What the log shows:
- spawn still logged `spawn.humanization_failed`
- summaries still report:
  - `probeOk=no`
  - `appLock=no`
  - `appFail=yes`
- visual signature still reads as reanimated zombie presentation
- `PresentationGuard` repeatedly blocks restoration / alpha repair with:
  - `reason=zombie_or_reanimated`

Interpretation:
- the branch is no longer primarily failing at spawn stability or post-move aggression presentation
- the clearest remaining blocker is still visual shell correctness / alive-state humanization truth
- current evidence still fits the broader hypothesis that the alive-looking human presentation path is being blocked upstream by role/class/presentation constraints

---

## 5. Clean vs delete now has a clearer explanation

Relevant lines:
- clean protection: `5405-5408`
- delete request + success: `5775-5796`

What the log shows:
- `clean` encountered:
  - `debug_cleanup.protected_managed_shell`
  - `Sterile cleanup removed 3 nearby world objects`
- `delete` later succeeded through:
  - `deleteNpcById:immediate_noncombat`
  - `Deleted NPC LWN-000027`

Interpretation:
- `clean` is still behaving like a nearby sterile cleanup pass, not a force-delete of the protected managed shell itself
- `delete` is the correct debug removal path for the embodied dummy
- this is no longer being blocked by false combat-state residue in the tested scenario

---

## What changed in code that likely mattered most

### Patch stack that now appears validated

1. `91561dd` — spawn-safe scrub completion
   - ensured grace helpers actually existed and worked
   - prevented over-eager scrub at spawn

2. `70bebb0` — move→idle handoff fix
   - `dummy.command` no longer counts as authoritative move-active state by itself
   - arrival / failed / cleared / idle transitions now settle the dummy back into idle more explicitly
   - EventAdapter now gives the runtime a narrow post-stop idle settle opportunity before deciding shell mode

### Why the result matters

This latest run suggests that the branch has now crossed another important threshold:

- spawn is stable enough to study,
- movement is real and committed,
- post-arrival aggression-looking residue is no longer the dominant problem,
- visual shell correctness is now the clearest remaining blocker.

That is a major narrowing.

---

## Current best diagnosis

The system now behaves like this:

- **logic / command control:** materially improved
- **spawn stability:** materially improved
- **movement authority:** materially improved
- **move→idle handoff:** materially improved
- **audio suppression:** materially improved
- **visual shell / human appearance truth:** still failing

In plain language:

> the branch is getting good enough at being a quiet, commandable dummy,
> but it is still bad at looking like a living human instead of a zombie shell.

---

## Recommended next priority

### Highest priority now
1. investigate / strengthen alive-state appearance truth and hard-fail conditions
2. keep testing on `TEST 01~03` until appearance changes are meaningful
3. continue to defer deeper recovery / TEST 04 work until the shell stops reading as a zombie

### What should *not* be the immediate next priority
- do **not** return first to big social / relationship logic work
- do **not** spend the next session polishing locomotion animation before visual shell truth improves
- do **not** re-open the old post-arrival aggression hypothesis unless a future run reintroduces it

### Practical next question
If the next session focuses on one thing only, it should be:

> why does the dummy remain `reanimated_zombie|M_ZedBody...` even after the control layer is now substantially cleaner?

