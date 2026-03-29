# Experiment Report — 2026-03-29 (IsoZombie vs IsoSurvivor A/B probe)

Branch: `spike/minimal-neutral-dummy`

Purpose of this document:
- preserve exactly what was tested today,
- preserve what was **not** tested,
- capture the causal lesson from each patch/test cycle,
- prevent repeating the same experiment without new information.

---

## Executive summary

Today’s work had two main phases:

1. **finish isolating the current `IsoZombie` failure mode**
2. **probe an alternative carrier (`IsoSurvivor`) just far enough to learn whether actor-class mismatch is real**

The day materially improved understanding even though it did not produce a working alive NPC.

### Durable conclusions from today

1. **`IsoZombie` is now stable enough to study, but still trapped in zombie presentation lifecycle.**
   - The shell spawns reliably.
   - It remains non-hostile, silent, and does not recognize the player.
   - Movement works in the sense of committed displacement.
   - But the shell still reads like a zombie visually.
   - Locomotion reads like segmented coordinate snapping rather than human walking.
   - Logs repeatedly converge on `presentationRole=reanimated_zombie` and related guard blocking.

2. **The current `IsoZombie` failure is no longer mainly a missing-descriptor / missing-clothes problem.**
   - Instrumentation now shows descriptor / skin / worn item truth can all be present.
   - The more persistent blocker is role / guard / alpha / culling behavior.

3. **`IsoSurvivor` did reveal a useful signal: it can appear as `alive_npc` in logs.**
   - This supports the actor-class mismatch hypothesis.
   - However, the current construction path is engine-unsafe.

4. **`IsoSurvivor` is not safe to keep testing in the current lane.**
   - It remains runtime-incomplete (`bodyDamage=nil`, `inWorld=false`).
   - It can trigger engine-level crashes in `IsoGameCharacter.updateInternal` because the update loop dereferences null `BodyDamage`.
   - Therefore the `IsoSurvivor` lane should be treated as quarantined, not as an active experiment lane.

---

## What was tested today

### A. IsoZombie appearance-failure forensics

#### Goal
Determine whether the zombie-looking alive NPC problem is caused mainly by:
- missing descriptor,
- missing human visual,
- missing skin,
- missing worn items / item visuals,
- timing/rebuild phase,
- guard blocking,
- role mismatch,
- or refresh overwrite.

#### Code changes made

1. `e430567` — `Add appearance failure taxonomy probes`
   - Added a structured appearance truth snapshot in `23_LWN_ActorFactory.lua`.
   - Added richer probe fields in `35_LWN_Carrier_IsoZombie.lua`.
   - Added expanded debug summaries in `92_LWN_DebugTools.lua`.

2. `3496670` — `Run one-shot rebuild after runtime settle`
   - Added a one-shot post-runtime-settle rebuild attempt for the `IsoZombie` lane.

3. `723aef3` — `Trace role and guard runtime blockers`
   - Added deeper role/guard snapshots for:
     - `bodyDamage`
     - `inWorld`
     - `currentSquare`
     - `square`
     - `presentationRole`
     - `alpha`
     - `targetAlpha`
     - `modelRegistered`
     - create-hook related fields

#### In-game results

Repeated full-restart tests showed a very stable pattern:
- alive NPC spawns as a zombie-looking shell,
- zombie audio is suppressed,
- NPC remains calm / non-hostile,
- NPC does not visibly recognize the player,
- command movement succeeds,
- destination position persists,
- but movement looks like repeated segmented teleporting rather than real walking animation,
- and the user sometimes felt there was a very brief moment of disappearance during movement.

Additional result:
- `clean` still does not remove the test NPC,
- `delete` still works.

#### What the logs proved

The important appearance-truth fields converged to a very specific pattern:
- `descOk=true`
- `visualOk=true`
- `skinOk=true`
- `wornOk=true`
- `itemVisualOk=true`
- `hybridApplied=true`
- but also:
  - `roleOk=false`
  - `guardBlocked=not_in_world`
  - `failCode=fail_presentation_role_zombie`

Other recurring facts:
- `presentationRole=reanimated_zombie`
- `PresentationGuard ... reason=zombie_or_reanimated`
- alpha can recover briefly and later collapse again during movement / runtime progression
- `sceneCulled` can reappear after movement begins

#### Interpretation

The `IsoZombie` lane is **not primarily failing because appearance data is missing**.

Instead, the stronger interpretation is:
- human descriptor / visual data can be applied,
- but final presentation authority remains zombie-coded,
- so render/alpha/culling behavior reasserts zombie-role truth,
- and the visible result remains a zombie-like shell.

#### What this means practically

Do **not** repeat the following old question without a new hypothesis:
- “Maybe the NPC still looks like a zombie because descriptor/clothing/skin did not apply.”

Today’s answer is already stronger than that.

The next useful question is instead:
- “How do we escape or replace the zombie presentation lifecycle?”

---

### B. Post-runtime-settle rebuild timing test (`IsoZombie`)

#### Goal
Test whether a later rebuild timing window would solve the visual issue.

#### Code change made
- `3496670` — `Run one-shot rebuild after runtime settle`

#### Result
No visible change from the player’s perspective.

#### Why it did not help
Logs showed the rebuild hook’s intended transition was effectively not reached in a meaningful way because the shell remained stuck in runtime-readiness failure signals long enough that the timing experiment did not become the decisive factor.

#### Interpretation
This was useful because it narrowed the problem:
- **timing alone is not the main answer**.

Do **not** repeat “just rebuild later” as the main next experiment unless a new mechanism is being tested.

---

### C. IsoSurvivor A/B lane activation

#### Goal
Probe the actor-class mismatch hypothesis by comparing the existing `IsoZombie` lane to a non-zombie alternative.

#### Code changes made

1. `f45d513` — `Wire IsoSurvivor into debug A/B test lane`
   - Connected existing `34_LWN_Carrier_IsoSurvivor.lua` into debug tools and context menu.

2. `cfd19d0` — `Let IsoSurvivor settle before rejecting`
   - Allowed `IsoSurvivor` to remain `pending_settle` instead of being rejected immediately.

3. `cfe0829` — `Skip unsupported visual APIs for IsoSurvivor`
   - Prevented some `ActorFactory` trace paths from calling unsupported visual collection APIs on `IsoSurvivor`.

#### What was learned before crashes took over

Before the engine crash path took over, logs showed something important:
- `object=Survivor`
- `presentationRole=alive_npc`
- `alpha=1.00`
- `targetAlpha=1.00`
- `squarePresent=true`

This matters because it is qualitatively different from the `IsoZombie` lane.

#### Why this did **not** become a valid A/B win

`IsoSurvivor` also showed:
- `bodyDamage=nil`
- `inWorld=false`
- `humanVisual=false`
- runtime core incomplete

And then two kinds of failure appeared:

##### 1. Lua/debug-surface crashes
Some debug and trace paths still tried to use APIs that `IsoSurvivor` does not safely implement, especially around visual collection introspection.

##### 2. Engine update crash
Even after partial trace hardening, the real fatal failure became:
- `IsoGameCharacter.updateInternal`
- null `BodyDamage`
- engine dereference crash

Representative signal:
- `NullPointerException: Cannot invoke "zombie.characters.BodyDamage.BodyDamage.getNumPartsBleeding()" because the return value of "zombie.characters.IsoGameCharacter.getBodyDamage()" is null`

#### Interpretation

This is the most important `IsoSurvivor` lesson:

- The lane is **interesting as evidence**.
- The lane is **unsafe as a test rail**.

It supports the idea that actor class matters, because it can at least reach `alive_npc` role in logs.
But it fails the stronger requirement:
- must survive the engine update loop without crashing the game.

#### Practical rule from now on

Do **not** continue routine `IsoSurvivor` spawn tests on the current constructor path.
Treat the lane as **quarantined** until there is a specific plan to construct a fully runtime-valid survivor-like actor.

---

## What was NOT tested today

This section exists specifically to avoid false memory later.

### Not tested

1. **No Bandits adoption pass was done.**
   - We did not pivot the branch to Bandits-style direct human visual borrowing.
   - We only discussed it as a later fallback path.

2. **No broad social / relationship logic work was resumed.**
   - Today was not a social-systems session.
   - We stayed focused on embodiment / appearance / runtime investigation.

3. **No locomotion polish solution was landed.**
   - Movement commitment exists.
   - But there is still no convincing human walk presentation result.

4. **No `clean` semantic redesign was done.**
   - We confirmed `clean` still is not a shell delete path.
   - We did not redesign it.

5. **No stable alt carrier beyond `IsoSurvivor` was implemented.**
   - `IsoPlayer` was discussed conceptually as a future candidate.
   - It was not reintroduced as a real A/B lane today.

6. **No successful `IsoSurvivor` move test happened.**
   - We did not reach a valid TEST 02 / TEST 03 comparison on `IsoSurvivor`.
   - The lane failed before it became safe for normal in-game comparison.

---

## Today’s strongest lessons

### Lesson 1 — `IsoZombie` failure is more structural than cosmetic
The evidence is now strong enough that future work should stop framing the problem as a simple “appearance data didn’t apply” issue.

### Lesson 2 — timing experiments are useful only after runtime truth is valid
A late rebuild window does not help much if the actor remains in the wrong presentation/runtime category.

### Lesson 3 — actor-class mismatch is now a serious, evidence-backed hypothesis
`IsoSurvivor` did not solve the problem, but it showed a different role truth (`alive_npc`) before failing. That is still valuable evidence.

### Lesson 4 — not every alt lane is worth keeping live
A lane that can hard-crash the game should be quarantined quickly, documented clearly, and removed from normal test flow.

### Lesson 5 — crashy experiments must leave explicit paper trails
Because actor-class experiments can be dangerous, they must be documented at a level that prevents the next session from casually re-running the same crash path.

---

## Recommended next direction

### Immediate operational action
- keep `IsoSurvivor` disabled in debug UI / automation lane,
- keep the warning visible so future sessions do not casually re-enable it.

### Most sensible next alt-candidate direction
If another actor-class experiment is attempted, the next one should be **planned before coded**, not improvised inside the current live harness.

Recommended candidate direction order:

1. **`IsoPlayer`-adjacent re-review, but only with a fresh contract review**
   - Reason: earlier project history already pointed toward actor-class mismatch around the `IsoPlayer` workaround.
   - But do **not** simply re-run old `IsoPlayer` ideas blindly.
   - First review what exact runtime/render problems caused the original retreat from that lane.

2. **Constructor / lifecycle review before any new alt carrier spawn**
   - A future alt carrier must satisfy at minimum:
     - world registration,
     - bodyDamage initialization,
     - safe engine update loop participation,
     - non-crashing debug inspection surface.

3. **If no safe alive-class constructor exists, return to `IsoZombie` with a narrower goal**
   - not “make it human in every way,”
   - but “break the zombie presentation ownership problem” with a more explicit proof-oriented patch.

### Concrete next-step research question
Before another alt carrier implementation pass, answer this more exact question:

> Which Build 42 actor classes can be constructed from Lua such that they survive `IsoGameCharacter.updateInternal` without null runtime members like `BodyDamage`?

That is a better question than simply “what else besides `IsoZombie` can we spawn?”

---

## Re-test prohibition list

Do **not** repeat these without a new patch or a new hypothesis:

1. **Plain IsoZombie TEST 01~03 just to re-confirm zombie-looking visuals**
   - already confirmed multiple times today
   - only re-run if a new patch changes appearance/runtime logic

2. **Post-runtime-settle rebuild timing test as a standalone idea**
   - already shown to be non-decisive

3. **Current-path IsoSurvivor TEST 01B**
   - prohibited for now
   - current constructor path is crash-prone

4. **“Maybe clothing/skin didn’t apply” theory without new evidence**
   - today’s logs already strongly weakened that explanation

---

## One-line durable takeaway

Today did not produce a working alive NPC, but it successfully transformed the problem statement from a vague “humanization failed” into a much sharper split:

- `IsoZombie` = stable but zombie-role trapped
- `IsoSurvivor` = alive-role hint but engine-unsafe

That is enough progress to prevent a lot of blind repeated experiments next session.
