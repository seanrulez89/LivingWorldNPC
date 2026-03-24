# Test Identity Harness

Date: 2026-03-25
Branch: `spike/isozombie`
Status: implemented for debug/test lane

## Why this was added

Recent tests showed that a single managed `IsoZombie` shell could be misread as:

- a deleted NPC
- a despawned/rearmed NPC
- a duplicated NPC
- or just a normal zombie mixed back into world noise

The underlying issue was not only humanization quality. It was also **identity collapse during testing**.

The test lane therefore needed a dedicated harness that prioritizes:

1. continuity
2. observability
3. low-noise local world state
4. stable shell identity

---

## Implemented behavior

### Debug sterile spawn

The main debug IsoZombie spawn path now creates a **sterile test NPC** instead of a generic debug NPC.

The harness applies:

- `debugHarness.enabled = true`
- stable label: `TEST-<npcId>`
- high trust / low resentment / low fear
- forced-friendly test posture by default
- hold-position behavior by default
- identity lock by default
- sterile cleanup around the player before and after spawn

### World-noise cleanup

The debug lane now removes nearby ordinary zombies / dead bodies around the test area.

Purpose:

- reduce ambiguity when returning from a distance test
- keep the managed shell from visually blending back into a surrounding mob
- speed up short spawn → inspect → move away → return loops

### Hold-position policy override

For harness-enabled shells, the carrier policy layer now prefers a neutralized/friendly posture when `holdPosition=true`.

This suppresses:

- pathing churn
- target acquisition
- combat lunge behavior
- normal hostile shell drift into the nearby crowd

### Identity-lock-aware maintenance

For harness-enabled shells with `identityLock=true`:

- the initial appearance signature becomes the lock target
- maintenance no longer eagerly escalates into a full reapply when a different signature is observed
- instead it holds the shell in a lighter maintenance mode and records the mismatch

This is not a final visual fix.
It is a **test stability fix** designed to stop maintenance from acting like accidental re-randomization.

### Debug observability

Debug summaries now expose harness metadata directly:

- test label
- hold-position flag
- identity-lock flag
- sterile radius
- locked appearance signature

---

## New practical test loop

Use this loop for the next round:

1. `Spawn Sterile Test NPC Near Player (IsoZombie)`
2. `Dump Nearest NPC Summary + Hybrid`
3. walk away a meaningful distance
4. return
5. `Dump Nearest NPC Summary + Hybrid`
6. `Dump Nearest NPC Movement/Audio`

Expected signals:

- same `npcId`
- same harness label
- `hold=true`
- reduced movement/pathing noise
- nearby world less contaminated by ordinary zombies
- locked signature visible in humanization dump

---

## Known limits

This harness does **not** solve the fundamental Build 42 presentation ceiling.

The shell may still ultimately render as a zombie-coded entity.

What this pass does solve is the ability to answer questions like:

- is this still the same shell?
- did the test harness keep it local and stable?
- did maintenance drift from the initial signature?
- is ambiguity coming from world contamination rather than lifecycle duplication?

---

## Next likely follow-up

If ambiguity still remains after this harness:

1. add a true world-space visual marker or ring for test shells
2. add a dedicated dump command for the current harness NPC only
3. force a more obviously unique clothing preset at initial spawn
4. inspect whether non-managed zombies can still inherit or mimic the same visual signature by coincidence
