# Experiment Report — 2026-03-29 Full Day Final

Branch: `spike/minimal-neutral-dummy`

Purpose of this document:
- preserve the full sequence of experiments performed on 2026-03-29,
- clearly separate what was tested from what was only discussed,
- record which hypotheses strengthened or weakened,
- prevent the next session from casually repeating already-settled experiments.

---

## 1. Executive summary

Today’s work moved through three distinct investigation tracks:

1. **IsoZombie appearance / presentation failure forensics**
2. **IsoSurvivor alternative-carrier spike**
3. **IsoPlayer alternative-carrier viability + visibility/materialization spike**

No playable alive-NPC embodiment was achieved today.
However, the problem statement is now much sharper than at session start.

### 1.1 Final branch-state understanding at the end of the day

- **IsoZombie**
  - stable enough to study,
  - non-hostile / quiet / movement-capable in the current minimal test lane,
  - but still trapped in zombie-owned presentation lifecycle.

- **IsoSurvivor**
  - showed alive-role evidence in logs,
  - but is unsafe on the current constructor/runtime path,
  - and can hard-crash the game engine.

- **IsoPlayer**
  - survived the engine update loop,
  - reached `alive_npc`,
  - had valid runtime-core signals (`world`, `square`, `BodyDamage`, `HumanVisual`),
  - but still failed to become visible,
  - and repeatedly hit model/materialization blockage around `ModelManager.Add` / `legsSprite.modelSlot`.

### 1.2 Final durable conclusion

The next session should **not** restart by re-running the same in-game spawn tests blindly.
The day already established enough to say:

- `IsoZombie` is not mainly a clothing/descriptor-missing problem.
- `IsoSurvivor` is quarantined.
- `IsoPlayer` is the least hopeless alternative tested today, but its current construction path still does not produce a renderable visible NPC.
- The final three pre-Bandits `IsoZombie`-within-LWN experiments were also attempted later the same day, and none of them meaningfully changed the branch outcome:
  - narrow guard/role relax was not sufficient,
  - overwrite/reassert did not appear to be the main issue,
  - runtime-settle-triggered alive reset did not meaningfully fire.

---

## 2. What was tested today, in order

### 2.1 IsoZombie appearance failure taxonomy

#### Goal
Determine whether the zombie-looking shell is failing because of missing visual data, or because a deeper presentation/runtime layer is overriding the humanized state.

#### Code changes made
- `e430567` — `Add appearance failure taxonomy probes`
- `3496670` — `Run one-shot rebuild after runtime settle`
- `723aef3` — `Trace role and guard runtime blockers`

#### What was instrumented
The new probes split appearance truth into fields like:
- descriptor truth
- human visual truth
- skin truth
- worn-items truth
- item-visual truth
- hybrid-applied truth
- presentation-role truth
- guard-block reason
- overwrite-after-refresh signal

#### In-game result
Repeated full restarts showed the same high-level behavior:
- spawn works,
- NPC still looks zombie-like,
- zombie vocal leakage is suppressed,
- NPC remains calm / non-hostile,
- NPC does not visibly recognize the player,
- TEST 02 movement succeeds and final position persists,
- movement reads like segmented coordinate snapping rather than human walk animation,
- user also sometimes felt a split-second disappearance during movement,
- `clean` still does not remove the shell,
- `delete` still works.

#### What logs proved
The important repeated pattern was:
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

Related recurring signals:
- `presentationRole=reanimated_zombie`
- `PresentationGuard ... reason=zombie_or_reanimated`
- alpha/culling could briefly recover and later collapse again during movement/runtime progression

#### Interpretation
This materially weakened the old theory that the shell still looked like a zombie because human appearance data never really applied.
The stronger interpretation became:
- appearance data can be injected,
- but final presentation ownership remains zombie-coded,
- so final visible truth still returns to zombie-role behavior.

#### Repeat-prevention rule
Do **not** repeat simple “maybe descriptor/clothes/skin didn’t apply” reasoning on this branch without a genuinely new signal.
That question was answered much more sharply today.

---

### 2.2 IsoZombie post-runtime-settle rebuild timing test

#### Goal
Test whether a later rebuild timing window would solve the visible zombie-shell problem.

#### Code change made
- `3496670` — `Run one-shot rebuild after runtime settle`

#### In-game result
No meaningful visible change.

#### Log result
The intended later rebuild window was not the decisive missing ingredient.
The shell still remained tied to runtime/presentation states that blocked a clean visible-human result.

#### Interpretation
Timing-only rebuild is not the main answer.

#### Repeat-prevention rule
Do **not** repeat “just rebuild later” as the primary experiment unless paired with a new concrete mechanism.

---

### 2.3 IsoSurvivor activation as an A/B alt carrier

#### Goal
Test whether moving away from zombie actor class immediately improves alive-role presentation.

#### Code changes made
- `f45d513` — `Wire IsoSurvivor into debug A/B test lane`
- `cfd19d0` — `Let IsoSurvivor settle before rejecting`
- `cfe0829` — `Skip unsupported visual APIs for IsoSurvivor`
- `0eb2a42` — `Quarantine IsoSurvivor test rail and document 2026-03-29 findings`

#### What was learned before the lane was shut down
Useful signal observed in logs:
- `object=Survivor`
- `presentationRole=alive_npc`
- `alpha=1.00`
- `targetAlpha=1.00`
- `squarePresent=true`

This mattered because it showed a non-zombie role truth distinct from the `IsoZombie` lane.

#### Failure mode
However the same lane also showed:
- `bodyDamage=nil`
- `inWorld=false`
- runtime-core incompleteness

And two classes of failure occurred:

##### A. Lua/debug-surface crashes
Unsupported APIs such as `getItemVisuals()` could explode on `IsoSurvivor` in some tracing codepaths.

##### B. Engine update crash
Even after partial trace hardening, the real fatal blocker remained engine-side:
- `IsoGameCharacter.updateInternal`
- null-body-damage dereference
- game crash

Representative failure:
- `NullPointerException: Cannot invoke "zombie.characters.BodyDamage.BodyDamage.getNumPartsBleeding()" because the return value of "zombie.characters.IsoGameCharacter.getBodyDamage()" is null`

#### Interpretation
`IsoSurvivor` is meaningful evidence, but not a safe active lane.
It showed that actor class matters, but the current constructor/runtime path is unsafe enough to crash the engine.

#### Repeat-prevention rule
Do **not** re-run current-path `IsoSurvivor` TEST 01B.
The lane is quarantined.

---

### 2.4 IsoPlayer viability probe introduction

#### Goal
After `IsoSurvivor` proved too dangerous, test whether `IsoPlayer` can serve as a safer alive-class alternative.

#### Code changes made before testing
- `f31ac6c` — `Add IsoPlayer viability probe test rail`
- `8fe0d91` — `Add phase-1 IsoPlayer visibility stabilization`
- `702228f` — `Block zero-target alpha loop for IsoPlayer`
- `79124a9` — `Guard IsoPlayer model registration until slot ready`
- `6c20bc7` — `Add IsoPlayer create-hook fallback completion`
- `acfe3f0` — `Trace IsoPlayer sprite slots before model add`
- `ce88dbe` — `Use minimal IsoPlayer materialization call set`

#### Important menu/tooling changes bundled into the day
- non-test debug clutter was removed from the UI
- test/debug menu default state was made effectively ON
- test UI was simplified to a focused `LWN Tests` flow

#### First major finding
Unlike `IsoSurvivor`, `IsoPlayer` could at least survive the engine update loop and remain runtime-valid long enough to study.
Repeated logs showed:
- `handleStatus=active`
- actor created and registered in the embodiment layer
- `body=true`
- `stats=true`
- `inventory=true`
- `world=true`
- `squarePresent=true`
- `presentationRole=alive_npc`
- `descriptor=true`
- `humanVisual=true`
- `itemVisuals` present
- `wornItems` present

This made `IsoPlayer` the most viable alternative carrier tested today in runtime-safety terms.

#### User-visible result across repeated probes
Despite the healthy-looking runtime summary, the user never saw a visible NPC on screen.
No reliable visible materialization occurred.

---

## 3. IsoPlayer experiment sequence in detail

### 3.1 IsoPlayer phase-1 visibility stabilization

#### Goal
If `IsoPlayer` already survives and remains `alive_npc`, try to stabilize visibility/materialization with alpha repair and post-create finalization assistance.

#### What was attempted
- additional visibility stabilization helper
- enforced embodied flags
- repeated alpha repairs
- heavier post-create finalization fallback

#### What logs showed
The actor remained logically healthy, but a crucial repeated signal stayed stuck:
- `modelRegistered=nil`

Other useful signals:
- alpha often recovered to `1.00`
- target alpha sometimes oscillated
- actor still did not become visible

#### Interpretation
The main blocker was no longer “is the actor alive and valid?”
It had become:
- why does the actor stay non-materialized / non-registered visually?

---

### 3.2 IsoPlayer zero-target alpha loop mitigation

#### Goal
Stop our own code from reintroducing `targetAlpha=0` on the `IsoPlayer` lane.

#### Code change made
- `702228f` — `Block zero-target alpha loop for IsoPlayer`

#### What changed
The code explicitly blocked the `setAlphaToTarget(0)` path for `IsoPlayer` and started logging `zero_target_blocked` instead.

#### Result
This was a valid narrowing step, but it did **not** solve visibility.
The branch learned that alpha-loop issues were not the deepest blocker anymore.

#### Interpretation
Alpha was part of the symptom stack, but not the final root cause.

---

### 3.3 IsoPlayer create-hook fallback completion

#### Goal
Stop waiting forever for `OnCreateLivingCharacter` and force completion if the actor was already valid enough.

#### Code change made
- `6c20bc7` — `Add IsoPlayer create-hook fallback completion`

#### What logs later showed
This fallback **did actually fire**.
Representative stable signal:
- `lastCreateHook=fallback_isoplayer_materialize`
- `createHookPending=false`
- `completeIsoPlayerCreateHookFallback.ready`

#### Why this matters
It means the create-hook-wait problem was partially solved/overridden.
The lane still did not become visible.

#### Interpretation
By the end of this step, the main blocker had moved even further down:
- create-hook fallback was no longer the decisive missing piece,
- model/materialization registration still failed.

---

### 3.4 IsoPlayer model-registration safety and sprite-slot tracing

#### Goal
Determine whether `ModelManager.Add` was failing because sprite/model slots were still not ready.

#### Code changes made
- `79124a9` — `Guard IsoPlayer model registration until slot ready`
- `acfe3f0` — `Trace IsoPlayer sprite slots before model add`

#### What was attempted
- avoid unguarded `ModelManager.Add`
- inspect readiness of sprite/model-slot state
- add slot-specific skip reasons
- inspect legs/torso/head slot readiness separately

#### Console signal that remained important
Even with new protections, the key console-side failure remained:
- `NullPointerException: Cannot assign field "remove" because "chr.legsSprite.modelSlot" is null at ModelManager.Add(ModelManager.java:638)`

#### Interpretation
This strongly suggests that either:
- model registration is still being triggered from a path outside the guarded wrapper,
- or the guarded wrapper is not the only code path causing engine-side model registration.

---

### 3.5 IsoPlayer minimal materialization call-set experiment

#### Goal
Reduce the set of high-risk calls that might be provoking internal engine-side `ModelManager.Add` too early.

#### Code change made
- `ce88dbe` — `Use minimal IsoPlayer materialization call set`

#### What changed
The lane stopped repeatedly invoking the heavier cluster of calls such as:
- `resetModel`
- `resetModelNextFrame`
- `reloadOutfit`
- `checkUpdateModelTextures`

and instead used a smaller set centered around:
- `InitSpriteParts`
- `onWornItemsChanged`
- visibility flags

#### Result
The user still saw nothing.
The engine/model-registration errors did not disappear and, by user perception, seemed to worsen or at least not improve.

#### Interpretation
The problem is unlikely to be solved just by trimming heavy refresh calls.
The deeper issue is still engine/materialization contract mismatch.

---

## 4. Console and error summary

### 4.1 Errors confirmed during the day

#### A. `DebugFileWatcher.add(...)` watcher null
- `java.lang.NullPointerException: Cannot invoke "zombie.PredicatedFileWatcher.getPath()" because "watcher" is null at DebugFileWatcher.add(...)`
- Important enough to note, but treated as secondary to the NPC embodiment problem.

#### B. `attempted index: getForname of non-table: null`
- Seen in console/system output search results.
- Relevant as a null-name/descriptor safety smell.
- Not currently judged to be the primary reason `IsoPlayer` stays invisible.

#### C. `ModelManager.Add(...)` with `legsSprite.modelSlot` null
- This is the most important console-side error of the day for the `IsoPlayer` lane.
- It matches the repeated log symptom:
  - `modelRegistered=nil`
- It is currently the strongest direct error-level clue for why `IsoPlayer` remains non-visible.

### 4.2 Priority ranking of the errors

1. **Highest priority** — `ModelManager.Add(...)` / `legsSprite.modelSlot` null
2. **Medium priority** — `getForname of non-table: null`
3. **Lower priority for this embodiment problem** — `DebugFileWatcher.add(...)` watcher null

---

## 5. What was NOT tested today

This section exists to stop future false memory and repeated experiments.

### 5.1 Not tested

1. **No Bandits adoption pass was implemented.**
   - Bandits was discussed only as a possible future reference direction.

2. **No successful visible `IsoPlayer` move test happened.**
   - The `IsoPlayer` lane remained spawn/visibility investigation only.
   - It never reached a justified TEST 02/03 gameplay comparison phase.

3. **No successful `IsoSurvivor` movement/idle comparison happened.**
   - The lane was shut down before safe comparison was possible.

4. **No redesign of the `clean` semantic happened.**
   - Only reconfirmed that `clean` still does not remove the managed shell.

5. **No final actor-class solution was found.**
   - Today sharpened the failure map; it did not solve embodiment.

---

## 6. Strongest lessons of the day

### 6.1 `IsoZombie` is stable but presentation-trapped
This lane is still the safest for repeatable behavioral testing, but its visible-human problem now looks structural rather than superficial.

### 6.2 `IsoSurvivor` is evidence, not a usable lane
Its alive-role signal matters, but the runtime path is too unsafe to leave active.

### 6.3 `IsoPlayer` is runtime-viable but render/materialization-blocked
This is the most important new understanding from the second half of the day.

### 6.4 alpha/create-hook fixes were narrowing steps, not end solutions
They were worth doing because they removed ambiguity, but by day end they were no longer the main unknown.

### 6.5 the current deepest blocker is `IsoPlayer` model/materialization registration
The strongest concrete clue is still:
- `ModelManager.Add(...)`
- `chr.legsSprite.modelSlot is null`
- `modelRegistered=nil`

---

## 7. Repeat-prohibition list

Do **not** re-run these without a new patch or a new hypothesis:

1. **Plain `IsoZombie` TEST 01~03 just to re-confirm zombie-looking visuals**
   - already proven repeatedly today

2. **Post-runtime-settle rebuild as a standalone idea**
   - already shown to be non-decisive

3. **Current-path `IsoSurvivor` TEST 01B**
   - prohibited; crash-prone

4. **Any `IsoPlayer` probe that only re-runs the same visibility flow without a new model/materialization idea**
   - by the end of today, merely re-running the same probe is not information-efficient

5. **Generic “maybe clothes/skin/descriptor didn’t apply” reasoning**
   - today’s probes already weakened that heavily for the active lanes

---

## 8. Practical next-step framing for the next session

The next session should not start from “let’s just click the probe again.”
It should start from a narrowed question.

### 8.1 Best current next question
> Which exact engine or Lua call path is still invoking `ModelManager.Add` for the `IsoPlayer` lane while `legsSprite.modelSlot` is null?

### 8.2 If continuing `IsoPlayer`
Future work should be framed as:
- engine/materialization contract investigation,
- not generic visibility poking,
- not alpha-only patching,
- and not another broad alt-carrier search on the same day.

### 8.3 If stepping back strategically
It is now reasonable to consider whether the project should:
- keep `IsoZombie` as the only stable shell for gameplay iteration,
- and treat alive-class actor experimentation as a slower side track rather than the main execution path.

---

## 9. One-line final takeaway

By the end of 2026-03-29, the problem was no longer “how do we humanize something?” in the abstract.
It became a much sharper three-way map:

- **`IsoZombie` = stable but zombie-role trapped**
- **`IsoSurvivor` = alive-role hint but engine-unsafe**
- **`IsoPlayer` = runtime-valid but still non-materialized / non-registered visually**

That is enough progress that tomorrow’s session should not need to repeat most of today’s experiments.
