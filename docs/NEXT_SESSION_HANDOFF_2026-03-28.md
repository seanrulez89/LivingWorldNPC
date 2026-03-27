# Next Session Handoff — 2026-03-28

Current work branch: `spike/minimal-neutral-dummy`
Baseline branches preserved:
- `spike/isozombie` — pre-surgery freeze point
- `spike/companion-shell-split` — surgery planning / reset branch

Status: meaningful progress achieved on minimal dummy branch; the project is no longer stuck at the old "no movement + zombie vocal + constant aggression" stage.

## Executive summary

The big-picture simplification worked.

The branch no longer treats the test subject like a full social NPC candidate.
Instead, it now behaves more like a deliberately constrained **minimal neutral dummy**.

That change finally produced real progress.

### What now works materially better

1. **Zombie vocal suppression works in practice**
   - the dummy no longer emits obvious zombie vocal audio while the rest of the game audio stays normal

2. **Real movement exists now**
   - deterministic movement produced real displacement
   - `squareChanged=yes`
   - `totalDelta` moved above zero in repeated runs

3. **Move position now commits more reliably**
   - after the recent move-authority + position-commit pass, the dummy did not immediately snap back to its original anchor in the latest automated move test
   - manual `Command Nearest Dummy To Test Destination` also no longer reproduced the old instant return-to-anchor regression in the latest run

### What still clearly fails

1. **Visual shell is still zombie-like**
   - current appearance signature still reads like `reanimated_zombie|F_ZedBody...`
   - the player still sees a zombie-looking shell

2. **Visual aggression residue remains after movement**
   - after arriving, the dummy can still show in-place stepping / attack-like posture
   - this presentation can pause when the player stands very close or collides with the dummy
   - the player still does not necessarily observe real damage/hit behavior at the same time

3. **Delete gating can still trip on attack-state presentation**
   - recent delete block reason shifted toward `actor_is_attacking`
   - this is different from earlier `actor_has_target` / obvious hostile pursuit failures
   - it suggests the top remaining issue is now presentation / attack-state residue rather than pure target-acquisition logic

## Why progress finally happened

This is the core lesson of the day.

Progress did not come from "better tuning" of the old system.
It came from changing the problem being solved.

### The old approach failed because too many layers were fighting each other

The earlier experiments tried to make one zombie-based actor simultaneously support:

- social relationship logic
- trust / resentment / betrayal drift
- goal / story / utility behavior
- non-hostile command behavior
- human-like presentation
- zombie carrier continuity

That created too many confounders.
When something failed, it was never obvious which layer was responsible.

### The new approach succeeded because it changed the architecture

The branch now made three decisive changes:

1. **Removed social/story/goal noise from the active test lane**
   - minimal dummy no longer runs like a socially interpreted NPC
   - relationship churn stopped being the main source of noise

2. **Applied a repeated hard dummy shell contract**
   - target clearing
   - attack-variable clearing
   - zombie vocal suppression
   - lane separation between idle and move
   - repeated reinforcement during runtime / tick flow

3. **Bypassed zombie-native locomotion with deterministic movement**
   - move intent now directly produces square-to-square displacement for the dummy
   - this was the first change that truly broke the old `moving=true / path2=true / totalDelta=0` failure pattern

A fourth important improvement landed later in the session:

4. **Committed moved positions back into anchor / embodiment / handle metadata**
   - this reduced the old tendency for some move flows to be silently dragged back toward stale anchor data

## Commits on the minimal dummy branch that matter most

In chronological order on `spike/minimal-neutral-dummy`:

- `194edd2` — `Bootstrap minimal neutral dummy test lane`
- `3a6ed34` — `Bypass social and goal logic for minimal dummy`
- `d852380` — `Narrow minimal dummy runtime to idle and move`
- `2e3a43c` — `Add hard shell contract for minimal dummy`
- `c24ed9a` — `Add deterministic move motor for minimal dummy`
- `22133e7` — `Document why minimal dummy branch made progress`
- `102c463` — `Replace dummy appearance path with stricter rebuild gating`
- `fc92e5b` — `Lock dummy move authority and commit moved positions`

## Current best interpretation of the system

The dummy is now much closer to this shape:

- **logic:** mostly non-hostile / controlled dummy
- **audio:** mostly corrected
- **movement:** first successful deterministic displacement achieved
- **visual body:** still zombie-coded
- **visual aggression / posture:** still partially zombie-coded after movement

In simple terms:

- the brain and movement control are starting to become a dummy,
- but the body and attack-presentation layer still read like a zombie.

## Immediate next patch priority

### 1. Visual aggression scrub (highest priority)

Goal:
- stop the post-move in-place stepping / attack-like body language
- reduce player-facing / alert-turn residue when no real hostile attack should exist

Main files expected:
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`
- possibly `42/media/lua/client/92_LWN_DebugTools.lua`

Expected focus:
- stronger clearing of attack / alert / turn presentation variables
- stronger idle-presentation reset after movement completes
- post-shove / post-stand / close-contact presentation scrub

### 2. Zombie body hard fail strengthening

Goal:
- treat zombie body skin / corpse-style presentation as an explicit hard failure, not just a weak signal

Main files expected:
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/37_LWN_ShellHumanizer.lua`
- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

Expected focus:
- fail appearance when `skin` still reads `ZedBody...`
- fail appearance when `presentationRole` remains `reanimated_zombie`
- expose clearer summary/debug values for visual truth vs visual failure

## What not to do first next time

- do **not** jump straight back into recovery / TEST 04 work first
- do **not** reintroduce relationship complexity
- do **not** spend time polishing natural-looking walking before the visual aggression residue is under control

The correct order is still:
1. visual aggression scrub
2. harder zombie-body fail gating / appearance truth
3. only then revisit deeper recovery/rebuild work

## Suggested next-session workflow

1. Start on `spike/minimal-neutral-dummy`
2. Implement visual aggression scrub patch
3. Run only `TEST 01~03`
4. If aggression-looking residue is materially lower, implement stronger zombie-body fail gating
5. Re-test `TEST 01~03`
6. Still postpone `TEST 04` unless the visual shell improves enough to make return-path work worth the noise

## Current testing takeaway

The branch is no longer in the old "everything fails at once" state.

It is now in a much better state:

- movement works enough to study
- audio suppression works enough to trust
- the remaining dominant issue is visual shell correctness and attack-like presentation residue

That narrowing is the main achievement of the day.
