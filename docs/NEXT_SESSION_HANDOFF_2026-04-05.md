# Next Session Handoff — 2026-04-05

Current work branch: `spike/bandits-visual-probe-v1`

## Executive summary

This handoff is a **hard scope reset**.

The current immediate goal is now exactly this:

> **Spawn an NPC that looks human, even for just 1 second.**

Everything else is lower priority until that exists.

That means the following are **not** the current problem to solve first:

- walking quality
- movement authority
- distance despawn
- return / recovery
- replacement spawning
- hostile reversion after travel
- long-lived stability beyond the initial visible spawn moment

Those topics may matter later, but they are now explicitly **out of the main line**.

## The one success criterion that matters right now

A run is a meaningful success candidate only if:

- the NPC is spawned,
- the user can see it,
- and it reads as a **human NPC rather than a zombie**,
- even if that human-looking result lasts only briefly.

If that does not happen, then movement / return / recovery discussion is noise for the current phase.

## Strategic direction that is still valid

The chosen strategy is still:

- keep `IsoZombie` as the practical shell lane,
- and **gradually introduce Bandits-style visual/build behavior**,
- instead of restarting a different carrier argument.

The important part is the word **gradually**:

- do **not** import Bandits AI / pathing / combat / persistence wholesale,
- do **not** switch the project goal back to movement or return-path correctness,
- do **not** broaden the experiment surface again.

The current mission is narrower:

> borrow only enough of the Bandits-style build / visual-stamping / ordering behavior to get a first human-looking spawn.

## What was useful from the recent work, and what was not

### Useful / still relevant

1. The branch already moved into the Bandits-adoption phase.
   - This was not just planning; real Bandits-style probing and Bandits-first build-lane work landed.

2. The Bandits-style pass was proven to be **not a no-op**.
   - Earlier logs showed real partial visual shifts.
   - That means this strategy still has live value.

3. The 2026-04-04 audit work is still useful.
   - Boot markers
   - `BanditsFactory` markers
   - `TestAction` markers
   - These help confirm the real hot path during spawn-time investigation.

### Useful only as background, not as next focus

The latest return/recovery instrumentation and tests clarified some identity-loss behavior, but that is **not the next question** anymore.

Specifically, the following are now background context only:

- `TEST 04`
- distance travel / return checks
- hidden-handle preservation
- recoverable-candidate rejection
- replacement spawn debugging

Do not start the next session there.

## Current best reading of project history

### What the pre-Bandits work already established

The project already spent enough time proving that:

- the shell can exist,
- various descriptor / clothing / alpha / world-state values can look superficially good,
- yet the final visible read still collapses into zombie-owned presentation.

That is why continuing the old “one more LWN-only tweak” loop is not the best use of time.

### What the Bandits-stage work established

The Bandits-stage work established two important things together:

1. **Bandits-style visual/build borrowing changes something real**
   - not just summary text,
   - but actual appearance-related state.

2. **The current branch still does not produce a human-looking first spawn**
   - which means the next task is to make the Bandits-influenced spawn lane more direct, simpler, and more causally readable.

## Exact focus rule for the next session

When deciding whether a code change is in-scope, ask only this:

> “Does this increase the chance that the freshly spawned NPC will visibly read as human for at least 1 second?”

If the answer is no, postpone it.

That means these are **out of scope unless they directly affect first-second appearance**:

- return-path recovery
- replacement logic
- long-distance despawn behavior
- walking path correctness
- movement smoothing
- combat cleanup
- later lifecycle polish

## What to read first next session

Read these in this order:

1. `docs/NEXT_SESSION_HANDOFF_2026-04-05.md`
2. `docs/BANDITS_FIRST_BUILD_LANE_2026-03-29.md`
3. `docs/CODE_AUDIT_2026-04-04.md`
4. `docs/TEST_LOG_HISTORY.md` — but only the entries relevant to **spawn-time appearance**, not the return/recovery detour

## Where to start in code next session

Start with these files, in this order:

1. `42/media/lua/client/23_LWN_ActorFactory.lua`
   - this is the highest-value starting point
   - inspect the actual Bandits-style visual probe / Bandits-first build path
   - the next question is whether the spawn-time build order can be made more directly Bandits-led and less polluted by later zombie-owned refresh behavior

2. `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
   - only for the **minimum** shell/carrier state needed to let the first spawned result stay visible long enough to evaluate
   - do not drift into return/recovery cleanup unless it directly affects the first human-looking second

3. `42/media/lua/client/92_LWN_DebugTools.lua`
   - trim or bias the testing surface toward spawn-only evaluation
   - the debug flow should make it easy to answer one question: “human-looking on spawn, yes or no?”

4. `42/media/lua/client/25_LWN_EmbodimentManager.lua`
   - touch only if it is clearly interfering with initial materialization / first-second appearance
   - do **not** begin from its return/recovery machinery

## What the next in-game test should look like

The next useful in-game check should be spawn-only and visually simple.

Preferred shape:

- `TEST RESET`
- `TEST 01`
- observe immediately
- `TEST STATUS`

What matters in that run:

- does a visible NPC appear?
- does it read as human or zombie?
- if it fails, where is the first visible handoff back to zombie-owned presentation?

What does **not** matter yet:

- whether it walks correctly
- whether it survives distance travel
- whether it recovers after despawn
- whether a replacement appears later

## Logging rule from now on

Until first human-looking spawn exists, logs and summaries should focus on **spawn-time appearance truth**.

That means future logging should prioritize:

- which Bandits-first path actually executed
- whether the Bandits-first visual/build step ran
- what the first post-build appearance verdict was
- where the first zombie-owned transition appears
- what the user visually saw on spawn

And future logs should de-prioritize:

- return/recovery churn
- hidden handle details
- replacement / reclaim details
- movement summaries that say nothing about first-second appearance

## Recent commits: what matters vs what is sidelined

### Still relevant to the main line

- `c82f8c6` — `Add Bandits probe checkpoints and settle reprobe`
- `14ab8b2` — `Promote Bandits-first dummy build lane`
- `74c803b` — `Fix Bandits-first post-build checkpoint summary`
- `ecc92af` — `Add structured presentation checkpoints for pre-test diagnosis`
- `48b39c3` — `Track presentation role and failure transitions`
- `75ac613` — `Summarize likely causes for presentation transitions`
- `9e30170` — `Audit runtime entrypoints and add load/action markers`
- `f993942` — `Promote Bandits checkpoint state into move summary`

### Background only for now

These happened, but should not drive the next session start:

- `9294a2e` — `Make TEST 04 use clean return recovery mode`
- `9106200` — `Fix TEST 04/status crash from forward local reference`
- `b596678` — `Trace TEST 04 recovery rejection path`

They clarified a later-lifecycle problem, but that later-lifecycle problem is not the current top priority.

## Exact starting mindset for next time

Start the next session with this sentence in mind:

> **Do not solve the whole NPC. First make it spawn as a human-looking NPC for even one second.**

If a proposed action is about anything else, it is probably not the right next action.
