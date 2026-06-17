# Our Approach First — Appearance Investigation Plan Before Gradual Bandits Adoption — 2026-03-28

Branch context: `spike/minimal-neutral-dummy`

## Why this document exists

Late-session discussion narrowed the project state considerably.

The current minimal dummy branch is no longer mainly failing at:
- multi-spawn instability,
- zombie vocal leakage,
- fake / non-committing movement,
- or post-arrival attack-like residue.

Those areas improved materially through the late-session fixes:
- `91561dd` — `Fix dummy spawn scrub grace helpers`
- `70bebb0` — `Fix dummy move idle handoff`

What remains most visibly wrong is now much narrower:
- the embodied shell still looks zombie-like,
- summaries still report `probeOk=no` / `appFail=yes`,
- `PresentationGuard` still reports `reason=zombie_or_reanimated`.

At the same time, fresh re-analysis of the Bandits reference confirmed that Bandits is strongest not merely because it uses zombie shells, but because it:
- treats the shell as a first-class managed contract,
- applies direct visual mutations to `HumanVisual` / `ItemVisuals`,
- reasserts locomotion / animation presentation continuously,
- favors practical in-world persistence over elegant descriptor theory.

However, the right next move is **not** to abandon the current LWN hybrid approach immediately.

## Core decision

Before gradually adopting Bandits-style direct visual stamping, the project should first exhaust the meaningful remaining experiment space inside the current LWN approach.

This is the right order because:

1. **The current architecture has already produced real wins**
   - stable single spawn
   - real movement with committed world position
   - calmer non-hostile shell behavior
   - stable move→idle handoff

2. **The remaining failure may still be inside timing / layering / overwrite behavior, not only inside the shaping method itself**
   - earlier logs showed that the first strong state transition after spawn could trigger a real appearance refresh
   - earlier regressions repeatedly showed that correct ideas could fail because they were applied too early or too aggressively

3. **Bandits-style borrowing will be more effective if we first know exactly which layer of the LWN pipeline is failing**
   - descriptor layer?
   - human visual layer?
   - clothing / item visuals layer?
   - presentation overwrite layer?
   - guard / role bucket layer?

The working rule from this point forward should be:

> Keep the current LWN architecture.
> First push it to its maximum informative limit.
> Only then add Bandits-style direct visual stamping as a surgical reinforcement, not as a blind replacement.

---

## High-level comparison that drives this plan

## What the current LWN approach is doing well

- canonical identity remains cleanly record-driven
- spawn / sync / handoff logic is increasingly testable
- the branch now has strong observability and strict appearance probes
- minimal dummy mode offers a low-noise validation lane
- the system still preserves future room for commandable movement and broader non-hostile behavior

## What Bandits is strongest at

- direct mutation of `HumanVisual`
- direct `ItemVisual` population
- aggressive cleanup of visual residue
- repeated walk / contract / animation reassertion
- practical persistence of the illusion over time

## What this implies

Bandits should remain an active practical reference, but only after LWN first answers:

- where exactly does the current descriptor/hybrid pipeline fail?
- is the failure caused by missing visual truth, or by later zombie-coded overwrite?
- is the current method fundamentally weak, or just badly timed?
- can appearance truth be improved without discarding the current architecture?

---

## Strategic principle for the next round

### Principle A — Preserve the current shell architecture
Keep:
- `IsoZombie` shell carrier
- canonical NPC identity in record / ModData
- relationship policy / dummy lane logic
- strict appearance probes / debug summaries
- TEST `01~03` as the main validation lane

### Principle B — Delay Bandits-style direct stamping until the current approach is better understood
Do **not** yet:
- replace the current descriptor/hybrid path outright
- remove strict probes in favor of visual optimism
- import Bandits runtime structure wholesale
- let the project lose the diagnostic clarity gained in the latest retests

### Principle C — Treat the next phase as a structured appearance-forensics pass
The next phase should answer:
- what actually applies,
- what actually survives,
- what gets overwritten,
- and when.

---

## What the current evidence already suggests

## Evidence 1 — correct ideas have repeatedly failed because of timing / force, not because the idea itself was wrong
Recent spawn-regression analysis already showed this pattern clearly:
- visual aggression scrub itself was not necessarily the wrong idea,
- but applying it too early / too aggressively destabilized the shell and caused loops.

Implication:
- appearance work must continue to be **phase-aware** and **spawn-safe**.

## Evidence 2 — appearance sometimes really does change after a strong state transition
Earlier appearance-diff logging showed that the first major forced state transition after spawn could cause real changes in:
- skin
- hair
- beard
- item visuals
- worn items
- persistent outfit id

Implication:
- a fully timed post-settle or post-arrival rebuild may still unlock more of the current pipeline without any Bandits borrowing yet.

## Evidence 3 — the branch is now finally quiet enough to isolate appearance as its own problem
Current retests show:
- spawn stable,
- movement real,
- move→idle handoff materially fixed,
- delete working,
- residual aggression mostly gone in the main test lane.

Implication:
- appearance can now be investigated as a primary variable rather than one symptom inside a giant multi-failure pile.

---

## Patch plan overview

This document proposes a three-wave plan.

- **Patch Plan 1** — instrumentation / forensics
- **Patch Plan 2** — timing / layering / rebuild experiments inside the current LWN approach
- **Patch Plan 3** — guard / presentation / truth hardening still inside the current LWN approach

Only **after** these three waves should the project consider introducing Bandits-style direct visual stamping.

---

# Patch Plan 1 — Appearance Forensics and Failure Taxonomy

## Goal

Turn the current appearance result from a vague failure (`probeOk=no`, `appFail=yes`) into a precise diagnosis of which layer fails and when.

## Why this is first

Without this, any Bandits-inspired adoption would be partially blind.
We would know that something is broken, but not whether we were fixing:
- missing descriptor bind,
- missing human visual materialization,
- missing clothing truth,
- zombie-role overwrite,
- or guard blockage.

## Target files

### 1. `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

Add finer-grained probe outputs to `probeHumanizationState(...)` and surrounding logging.

#### Add distinct truth flags
Current probe should be expanded into separate booleans such as:
- `descriptorOk`
- `humanVisualOk`
- `skinOk`
- `wornItemsOk`
- `itemVisualsOk`
- `hybridAppliedOk`
- `presentationRoleOk`
- `strictVisualOk`
- `appearanceLockedOk`

#### Add structured failure reasons
Prefer writing one or more of:
- `fail_descriptor_missing`
- `fail_human_visual_missing`
- `fail_skin_nil`
- `fail_worn_and_item_visuals_empty`
- `fail_hybrid_not_applied`
- `fail_presentation_role_zombie`
- `fail_guard_blocked`
- `fail_overwritten_after_refresh`

#### Add phase-tagged snapshots
At minimum, capture snapshots at:
- spawn initial dummy build end
- sync rebuild entry / exit
- first runtime settle
- move arrival
- post-arrival idle settle

### 2. `42/media/lua/client/23_LWN_ActorFactory.lua`

Instrument the hybrid shaping pipeline stage-by-stage.

#### Stage snapshots to add
Inside / around:
- `buildDescriptor(...)`
- `materializeDescriptorVisual(... pre_clothing ...)`
- `setBaselineHumanVisual(...)`
- `ensureVisibleClothing(...)`
- `materializeDescriptorVisual(... post_clothing ...)`
- `bridgeWornItemsToItemVisuals(...)`
- `refreshActorPresentation(...)`

Record at each stage:
- descriptor present?
- human visual present?
- skin texture?
- worn item count?
- item visual count?
- presentation role?
- appearance signature?

### 3. `42/media/lua/client/92_LWN_DebugTools.lua`

Expand debug summary output so live tests can tell not just “failed,” but **how** it failed.

Suggested additions:
- `descOk`
- `visualOk`
- `skinOk`
- `wornOk`
- `itemVisualOk`
- `roleOk`
- `guardBlocked`
- `lastProbeFailureCode`

## Expected outcome

At the end of Patch Plan 1, the project should be able to say something like:

> descriptor and clothing bind do work, but presentation role remains zombie-coded and wipes the visible result after refresh

or

> skin never materializes at all, so the problem is earlier than guard overwrite

That level of specificity is mandatory before adopting Bandits-style direct stamping.

---

# Patch Plan 2 — Timing, Phase-Aware Rebuild, and Layered Reapplication

## Goal

Push the current LWN descriptor/hybrid path to its maximum practical potential by changing **when** heavy appearance work happens, not yet **how** it fundamentally works.

## Why this is second

Recent history strongly suggests that timing matters as much as method.
The current branch may still have useful unused headroom if the same appearance work is applied later, once runtime and movement state are stable.

## Target files

### 1. `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

#### Introduce phase-aware rebuild states for minimal dummy appearance
Instead of one generic rebuild bucket, distinguish:
- `spawn_initial`
- `runtime_settle_rebuild`
- `post_move_arrival_rebuild`
- `post_idle_settle_rebuild`

#### Add narrow rebuild opportunities
Potential triggers:
- first time `runtimeOk == true`
- first successful move arrival
- first post-arrival idle settle after movement

Each should:
- fire once,
- be logged clearly,
- avoid aggressive scrub overlap during spawn grace,
- avoid repeated heavy rebuild loops.

### 2. `42/media/lua/client/37_LWN_ShellHumanizer.lua`

#### Separate maintenance modes more explicitly
Current modes should be strengthened into clear buckets such as:
- `initial`
- `maintenance_light`
- `maintenance_full_reapply`
- `post_settle_full_reapply`
- `post_arrival_full_reapply`

#### Allow one-shot heavy reapply after stable state transitions
The current system already supports `forceFull`; the next step is to make the triggers intentional instead of generic.

### 3. `42/media/lua/client/23_LWN_ActorFactory.lua`

#### A/B test refresh granularity
The current heavy path bundles many things together. Break them into experimental lanes:
- descriptor bind only
- descriptor + clothing
- descriptor + clothing + bridge
- descriptor + clothing + bridge + refresh
- descriptor + clothing + bridge + refresh + alive-state reset

#### Add appearance snapshot diff at each lane boundary
The purpose is not permanent code churn, but proving which layer causes the first visible gain or first visible overwrite.

## Concrete experiment lanes inside Patch Plan 2

### Lane 2A — Post-runtime-settle heavy rebuild
Apply one heavy rebuild only after:
- actor is in world,
- bodyDamage exists,
- square exists,
- runtime core is stable.

### Lane 2B — Post-arrival heavy rebuild
Apply one heavy rebuild only after:
- command inactive or arrived,
- motor arrived,
- actor no longer moving,
- path2 cleared,
- dummy settled to idle.

### Lane 2C — Refresh-minimal vs refresh-heavy comparison
Compare:
- only `resetModel/resetModelNextFrame`
vs
- full current `refreshActorPresentation()`

This will help determine whether the current refresh path is helping, or partly reintroducing zombie-coded presentation.

## Expected outcome

At the end of Patch Plan 2, the project should know whether the current approach fails because it is too weak, or merely because it is applied at the wrong phase.

---

# Patch Plan 3 — Presentation Guard, Role Bucket Truth, and Hard-Fail Cleanup

## Goal

Still staying inside the current LWN approach, determine whether the final blocker is now mostly:
- presentation-role truth,
- guard overprotection,
- or post-refresh overwrite.

## Why this is third

Only after instrumentation and timing experiments should the project touch guard / role-layer behavior. Earlier interference at this layer would risk turning the branch noisy again.

## Target files

### 1. `42/media/lua/client/23_LWN_ActorFactory.lua`

#### Investigate `restoreEmbodiedPresentationFlags(...)` and `repairVisibleAlpha(...)`
Specifically determine:
- whether they help visibility truth,
- whether they preserve zombie-coded presentation role,
- whether they need a minimal-dummy-specific limited bypass lane.

#### Add optional narrow experimental path
For minimal dummy only, and only under explicit debug flag:
- allow a tightly bounded presentation repair path even if normal zombie-coded guard logic would skip it.

This must be:
- opt-in,
- easy to disable,
- clearly logged,
- never blended with broad unrelated runtime logic.

### 2. `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

#### Track overwrite-after-refresh behavior
If appearance improves for one stage and then degrades on the next tick, write this explicitly into record/modData state.

Suggested tracking:
- `appearanceChangedAt`
- `appearanceChangedSignature`
- `appearanceOverwrittenAt`
- `appearanceOverwriteSource`

#### Add minimal-dummy-specific hard-fail staging
If a shell still presents as zombie-coded after all current-approach rebuild lanes, mark that clearly as:
- `appearanceHardFail = true`
- `appearanceHardFailReason = <specific failure taxonomy>`

This creates a clean handoff point into future Bandits borrowing.

### 3. `42/media/lua/client/92_LWN_DebugTools.lua`

#### Show hard-fail state directly in the test summaries
The user should be able to tell whether a run ended in:
- not yet tried,
- partial visual truth,
- overwritten-after-refresh,
- or hard fail under current approach.

## Expected outcome

At the end of Patch Plan 3, the team should be able to say one of two things with confidence:

### Outcome A — the LWN approach still has usable headroom
If so, continue improving it without introducing Bandits-style direct stamping yet.

### Outcome B — the LWN approach now shows a repeatable hard ceiling
If so, the project will have earned the right to introduce Bandits borrowing very precisely, because it will know exactly what current LWN shaping cannot achieve alone.

---

## What should *not* be done during these three patch waves

Do **not**:
- replace the current descriptor / hybrid pipeline wholesale
- import Bandits brain/runtime structure wholesale
- reopen large-scale social / relationship feature work
- broaden test scope beyond `TEST 01~03`
- let recovery / TEST 04 complexity re-enter before appearance truth improves
- revisit aggressive scrub timing that already destabilized spawn once

---

## What this plan is trying to learn before Bandits borrowing begins

The project must first answer these questions using the current approach alone:

1. Does descriptor materialization actually succeed?
2. Does `HumanVisual` actually contain usable human truth?
3. Does clothing truth survive into `ItemVisuals`?
4. Does a later state transition improve visual truth more than spawn-time shaping?
5. Does refresh help, or does refresh trigger overwrite?
6. Is `PresentationGuard` merely reporting the truth, or actively preventing the last needed repair?
7. Is the current method weak in principle, or just mis-timed?

Only once those questions are answered should Bandits-style direct visual stamping be introduced.

---

## Future rule for gradual Bandits adoption

When Bandits borrowing eventually begins, it should follow this rule:

> borrow only the missing layer,
> not the whole architecture.

That means future Bandits-inspired work should probably start with only:
- direct skin/hair/beard visual stamping,
- direct `ItemVisual` fallback population,
- body visual residue cleanup,
- or narrowly scoped model-reset reinforcement,

**after** the current LWN approach proves which one is truly missing.

---

## Final recommendation

### Recommended next work order

1. Patch Plan 1 — appearance forensics / failure taxonomy
2. Patch Plan 2 — phase-aware rebuild / timing experiments
3. Patch Plan 3 — guard / role / overwrite hardening
4. Only then evaluate narrowly targeted Bandits-style visual borrowing

### Final strategic message

The project should not jump to “be more like Bandits” yet.

The correct immediate move is:

- protect the diagnostic clarity gained from the latest minimal dummy stabilizations,
- use that clarity to extract the maximum possible lessons from the current LWN approach,
- and only after that, adopt Bandits ideas surgically where the current approach proves it has reached a real ceiling.

That sequence maximizes both learning value and implementation quality.
