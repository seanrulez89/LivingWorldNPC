# End-of-Day Strategy and Experiment Order — 2026-03-28

Branch: `spike/minimal-neutral-dummy`

## Why this document exists

This document closes the day by capturing the most important late-session strategic conclusions after the branch achieved material progress on:
- stable single spawn,
- zombie vocal suppression,
- deterministic movement with committed displacement,
- calmer non-hostile shell behavior,
- and a substantially improved move→idle handoff.

The project is no longer dominated by general instability. It is now dominated by a much narrower question:

> why does the shell still remain zombie-looking, and how should the team design the next experiments so that the resulting evidence has clear causal meaning?

This document also records a crucial late-session rule:

> Before gradually adopting Bandits-style visual borrowing, the project should first exhaust the remaining meaningful experiment space inside the current LWN approach.

And a second crucial rule:

> Avoid experiments that bundle too many variables together. Every experiment should have a narrow goal, explicit measurements, and a result that supports a clear causal interpretation.

---

## Current project state at end of day

### What now works materially better
- exactly one dummy can spawn in the latest main validation lane
- zombie vocal leakage is suppressed in the tested cases
- movement can now produce real world displacement and committed destination arrival
- post-arrival aggression-looking residue was materially reduced / absent in the latest retest
- delete works in the tested scenario

### What still clearly fails
- the shell still looks zombie-like to the player
- summaries still report `probeOk=no` / `appFail=yes`
- `PresentationGuard` still reports `reason=zombie_or_reanimated`
- movement still does **not** read as convincingly human walking; it feels more like repeated coordinate hops than a natural walking animation

---

## Strategic decision: our approach first, Bandits later and only surgically

The late-session conclusion is now explicit.

### Do not do this next
- do **not** replace the current LWN descriptor/hybrid pipeline wholesale
- do **not** jump straight to a large Bandits-style visual rewrite
- do **not** run broad multi-variable “kitchen sink” experiments that mix timing, direct visual mutation, guard overrides, and locomotion cues all at once

### Do this next
- preserve the current `IsoZombie` shell + canonical record architecture
- use the newly improved branch stability to extract the maximum possible learning from the current LWN appearance pipeline first
- only after the current approach reaches a clearer ceiling, introduce Bandits-style ideas narrowly at the exact missing layer

### Why
Because the branch has finally become stable enough that appearance can be investigated as its own problem, and that means Bandits borrowing can be made much smarter later if the team first identifies:
- which layer actually fails,
- when it fails,
- and whether failure is caused by missing truth or later overwrite.

---

## Late-session locomotion insight

Another important conclusion from the final discussion is that “movement success” and “convincing human walking” are not the same thing.

Current observed state:
- movement logic now succeeds enough to change squares and arrive
- however, player perception still reads the movement as coordinate hopping rather than natural human walking

### Working hypothesis
The most plausible current interpretation is:
- locomotion authority / position commit is now good enough to move the shell,
- but the shell may still be zombie-coded at the presentation / animation bucket level,
- so the branch may currently be able to move logically without yet being able to look like a naturally walking human.

This does **not** yet prove that human-like walking is impossible on the current shell.
But it does strongly suggest the following experimental rule:

> Do not treat locomotion “readability” as an isolated animation-polish problem before appearance truth / presentation truth improves.

In practical terms:
- the next phase should test whether improved appearance truth changes locomotion readability,
- and only after that should the project decide whether it must add stronger movement-animation contracts.

---

## Master experimental principle for next session

### Principle 1 — one causal question per experiment
Every experiment should answer one main question.

Bad example:
- add new probes,
- change rebuild timing,
- add guard exceptions,
- add direct visual stamping,
- and add locomotion animation cues,
all in one patch.

This produces unusable evidence because success or failure cannot be attributed cleanly.

Good example:
- only refine failure taxonomy,
- then check whether the branch now reveals descriptor success but presentation overwrite failure.

### Principle 2 — measurement must be defined before implementation
Each experiment must specify:
- what it is trying to change,
- what success looks like,
- what failure looks like,
- what exact logs or in-game observations will be used to judge the result.

### Principle 3 — preserve the current low-noise lane
Use `TEST 01~03` only while appearance remains wrong.
Do not broaden scenario complexity until the shell stops reading as zombie-coded.

### Principle 4 — do not move on from a layer until the current evidence is interpretable
If a patch produces ambiguous evidence, refine the instrumentation before moving to the next patch family.

---

## Ordered experiment plan for the next session

The following order is now recommended.

---

# Phase 1 — Appearance forensics before any new behavior ambition

## Goal
Determine exactly which layer of the current LWN appearance pipeline fails.

## Main question
Is the current branch failing because:
- descriptor shaping never really lands,
- human visual truth never really appears,
- clothing/item visuals never really materialize,
- or correct visual truth gets overwritten later by zombie-coded presentation / guard behavior?

## Files
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

## Required outputs
At minimum, separate and log:
- descriptor truth
- human visual truth
- skin truth
- worn items truth
- item visuals truth
- hybrid applied truth
- presentation role truth
- guard blocked truth
- overwritten-after-refresh truth

## Measurement
Success means the branch can now classify appearance failure more precisely than `probeOk=no`.

Example acceptable outcomes:
- descriptor succeeds, but presentation role remains zombie-coded
- item visuals exist, but skin is nil
- refresh improves appearance signature briefly, then overwrite happens next tick

## Why this phase comes first
Because all later strategy depends on knowing whether the current approach still has internal headroom.

---

# Phase 2 — Timing and phase-aware rebuild experiments

## Goal
Test whether the current method works better when applied at different stable phases.

## Main question
Is the current appearance method fundamentally weak, or merely mistimed?

## Files
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/37_LWN_ShellHumanizer.lua`
- `42/media/lua/client/23_LWN_ActorFactory.lua`

## Experiments to run
### Experiment 2A — post-runtime-settle heavy rebuild
- change only rebuild timing
- trigger one heavy rebuild after runtime is stable
- do not also change guard behavior

### Experiment 2B — post-arrival heavy rebuild
- change only rebuild timing
- trigger one heavy rebuild after move arrival + idle settle
- do not also change visual mutation method

### Experiment 2C — refresh granularity A/B
- compare minimal refresh vs current heavy refresh
- do not also add direct Bandits-style visual stamping here

## Measurement
Success means one of the timing lanes clearly produces better appearance truth than spawn-only shaping.

Useful outcomes:
- post-runtime-settle wins
- post-arrival wins
- refresh-heavy causes overwrite but refresh-minimal does not
- no timing lane improves truth, suggesting the weakness is elsewhere

## Why this phase is separate
Because it answers a timing question, not a direct-visual-stamping question.

---

# Phase 3 — Guard / role / overwrite investigation

## Goal
Determine whether the final current-approach blocker is now mainly guard behavior, role truth, or overwrite.

## Main question
After instrumentation and timing have been improved, is `PresentationGuard` still the main thing blocking visible human truth?

## Files
- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

## Experiments to run
### Experiment 3A — guard classification only
- no behavior changes
- only make the guard’s blocking reasons more precise

### Experiment 3B — narrow minimal-dummy-only guarded repair lane
- opt-in only
- minimal scope
- do not combine with direct visual stamping

### Experiment 3C — overwrite tracker
- explicitly record when a better appearance signature is later lost

## Measurement
Success means the branch can state clearly whether:
- guard blocks the needed repair,
- role truth stays zombie-coded even without guard interference,
- or appearance improves briefly and then gets overwritten.

## Why this phase is delayed
Because touching guard logic too early risks destabilizing a branch that has only recently become interpretable again.

---

# Phase 4 — Only after that: locomotion readability experiments

## Goal
Determine whether improved appearance truth changes the player’s perception of movement readability.

## Main question
Once appearance truth improves, does the same movement logic begin to read as actual walking rather than coordinate hopping?

## Important rule
Do **not** treat locomotion readability as the top optimization target before appearance truth improves.

## Why
Because the current shell may be moving logically while still remaining zombie-coded in presentation / animation bucket terms.
If that is true, locomotion polish done too early will produce muddy evidence.

## Files likely involved later
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/20_LWN_ActionRuntime.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`
- debug summary / test helpers as needed

## First locomotion readability tests to run after appearance improves
### Experiment 4A — same movement command, better appearance truth
Compare movement readability before and after appearance truth improvement with the same move logic.

### Experiment 4B — movement-state / animation-state snapshot
Record together:
- `moving`
- `path2`
- `motorState`
- `walkType`
- `bumpType`
- action state name
- appearance truth summary

### Experiment 4C — move-start / move-mid / post-arrival split
Judge movement readability in three segments rather than as one vague impression.

## Measurement
Use a simple human-readable rubric:
- appearance: zombie-like / partial human / convincing human
- movement success: yes / no
- walking readability: none / weak / partial / convincing
- turning readability: none / weak / clear
- movement feel: statue / coordinate-hop / glide / walk-like
- post-arrival settle: abrupt / acceptable / natural

---

## What should not be mixed together in one patch

Avoid the following combinations in a single experiment patch:
- new failure taxonomy + new timing + guard exception
- guard exception + direct visual stamping + locomotion cue changes
- heavy rebuild timing changes + move animation cue changes
- Bandits-style direct `ItemVisual` population + strict probe rewrite + new refresh path

If more than one layer changes at once, the result becomes hard to interpret.

---

## When Bandits borrowing becomes appropriate

Only after the branch can say with confidence:
- which current layer fails,
- whether timing alone helps,
- whether guard / role / overwrite is the last blocker,
- and whether improved appearance truth changes movement readability.

Then, and only then, Bandits-style borrowing should begin — and only surgically.

Likely first borrowing candidates later:
- direct `HumanVisual` skin/hair/beard restamp
- direct `ItemVisual` fallback population
- body-visual residue cleanup
- tighter walktype / animation reassertion

But those should come **after** the current approach proves exactly what it cannot do.

---

## Final end-of-day message

The project’s direction is now clearer than it was earlier in the day.

The next session should **not** ask:
- “How can we make the branch more like Bandits as quickly as possible?”

It should ask:
- “How can we use the branch’s new stability to extract the maximum possible causal learning from the current LWN approach before borrowing only what is truly missing?”

That is now the preferred strategy.
