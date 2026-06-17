# End-of-Day Lessons — Minimal Dummy Branch — 2026-03-28

## Why this document exists

This document is not just a handoff note.
It is meant to preserve the **actual lesson of the day**:

> exactly what was tried differently,
> why that difference produced real progress,
> and what still remains broken even after that progress.

That distinction matters because earlier parts of the project often produced many patches but very little real movement in the underlying failure shape.

Today was different.

The branch still has major problems, but it also achieved a genuine architectural narrowing.

---

## The old mistake

The older experimental direction kept trying to make one zombie-based shell do too many jobs at once.

That shell was expected to behave like all of these simultaneously:

- a world-resident zombie carrier
- a friendly or neutral or hostile social NPC
- a commandable companion
- a visually human-like survivor
- a recovery-stable identity across streaming and return
- a target / combat / sound-suppressed non-zombie entity

In practice that produced a pile of interacting failure layers.

### Typical old failure shape

- relationship logic kept changing meaning
- goal / utility / behavior logic kept generating noise
- zombie native locomotion pretended to move without real displacement
- zombie vocals and target reacquisition kept leaking back in
- return-path continuity collapsed into split-shell behavior
- humanization state often claimed success while the shell still read like a zombie

The result was not just failure.
It was **opaque failure**.

There were too many possible reasons for any single symptom.

---

## What was tried differently today

The single most important change was conceptual:

### We stopped asking the system to produce a full NPC.

Instead, we asked it to produce a **minimal neutral dummy**.

That sounds simple, but it changes almost everything.

### The new experimental definition

The new dummy only needs to do this:

- exist in the world
- stay quiet (no zombie vocal)
- not act aggressively in a real gameplay sense
- remain idle by default
- move when explicitly commanded
- eventually wear a human-looking shell

And it explicitly does **not** need to do this right now:

- relationship drift
- trust / resentment / betrayal
- companion-style autonomous behavior
- story goals
- follow / guard / retreat / search behavior
- rich combat logic
- dynamic social identity

That reduction in scope is the root cause of the day’s progress.

---

## The chain of changes that mattered

The breakthrough did not come from one patch.
It came from a sequence of changes that reinforced each other.

### 1. Minimal dummy test lane bootstrap

Relevant commit:
- `194edd2` — `Bootstrap minimal neutral dummy test lane`

What changed:
- UI/debug surface was simplified
- old relationship/legacy/debug noise was removed from the main entry path
- the test subject was explicitly marked as dummy-like rather than as a general NPC experiment

Why it mattered:
- the branch needed a different entrance before it could have a different runtime
- as long as the menus and debug path still revolved around relationship forcing and legacy experiments, every run started noisy

### 2. Social / goal / story bypass

Relevant commit:
- `3a6ed34` — `Bypass social and goal logic for minimal dummy`

What changed:
- the dummy stopped behaving like a social record in the active path
- trust / resentment / betrayal logic stopped mattering
- goal generation was reduced toward idle
- utility scoring stopped pushing richer NPC behaviors
- behavior tree stopped trying to run the dummy like a normal autonomous actor

Why it mattered:
- it removed the first major class of false explanations
- after this point, if the dummy still behaved strangely, the explanation was less likely to be social/story churn

### 3. Runtime narrowing to idle / move

Relevant commit:
- `d852380` — `Narrow minimal dummy runtime to idle and move`

What changed:
- the runtime stopped accepting a broad set of old intents for the dummy
- the queue became much closer to a single-purpose move pipeline
- unsupported intents were dropped more aggressively

Why it mattered:
- it simplified the active control path enough that later movement work had a stable place to attach

### 4. Hard dummy shell contract

Relevant commit:
- `2e3a43c` — `Add hard shell contract for minimal dummy`

What changed:
- target / attackedBy / lastTargettedBy clearing repeated more often
- zombie vocal suppression became a repeated shell-level concern
- idle and move shell modes became more explicit
- dummy rebuild fallback began trying to repair appearance more deliberately

Why it mattered:
- the project stopped trying to rely on one-time neutralization
- instead, it started repeatedly forcing the shell back into a constrained dummy state

This is one of the most important lessons of the day:

> the shell improved not because the zombie "learned" to behave,
> but because the branch stopped giving it long enough to fall back into its default instincts.

### 5. Deterministic move motor

Relevant commit:
- `c24ed9a` — `Add deterministic move motor for minimal dummy`

What changed:
- dummy `move_to` stopped depending on zombie-native locomotion as the primary movement mechanism
- the branch directly computed next-step squares and moved the actor there
- debug summaries started surfacing motor states explicitly

Why it mattered:
- this was the first time the project stopped hoping that zombie path state would eventually produce world displacement
- instead, move intent was translated directly into committed square-to-square change

This was the biggest technical breakthrough of the day.

Because before this change, the common pattern was:

- `moving=true`
- `path2=true`
- `totalDelta=0.00`

After the change, the branch finally produced:

- `motor=stepping`
- `squareChanged=yes`
- `totalDelta > 0`

That is the moment the project stopped being stuck at "fake movement".

### 6. Stricter progress documentation and analysis

Relevant commit:
- `22133e7` — `Document why minimal dummy branch made progress`

Why it mattered:
- this wasn’t just paperwork
- it forced the branch to state clearly *why* progress happened:
  - less social noise
  - more repeated shell enforcement
  - direct movement control

That lesson is worth preserving because it should guide the next stage too.

### 7. Step B-full: stricter rebuild gating for appearance truth

Relevant commit:
- `102c463` — `Replace dummy appearance path with stricter rebuild gating`

What changed:
- appearance success became harder to fake
- dummy rebuild path leaned more heavily on rebuild/reapply rather than optimistic early success
- `appLock` / `appFail` became more meaningful

Why it mattered:
- this change did not solve the visual problem
- but it did make the branch more honest about it

That honesty matters.
A system that lies about success wastes more time than a system that fails clearly.

### 8. Move authority lock + position commit

Relevant commit:
- `fc92e5b` — `Lock dummy move authority and commit moved positions`

What changed:
- dummy move state stopped dropping into idle so easily while movement authority was still active
- successful move steps began updating anchor / embodiment / handle metadata more aggressively
- committed square became visible in summary output

Why it mattered:
- it narrowed the old "move, then snap back" problem
- it also improved manual command behavior enough that the branch started behaving more consistently across both automated and manual move triggers

This is the second biggest lesson of the day:

> moving an actor is not enough.
> the rest of the system must also accept that movement as the new truth.

Without position commit, successful movement could still be undone by stale anchor assumptions.

---

## What actually improved in gameplay terms

By the end of the session, the branch produced a materially different gameplay experience than earlier attempts.

### Improvement 1 — zombie vocal suppression became trustworthy

The player heard:
- normal world audio
- but no zombie vocal from the dummy

That is a meaningful win.
Earlier sessions sometimes made it unclear whether audio suppression was real or whether the whole game’s sound had been damaged.

Today the branch behaved more cleanly:
- game audio was still broadly normal
- dummy zombie vocal was suppressed

This tells us the audio suppression work moved closer to the correct granularity.

### Improvement 2 — the dummy stopped behaving like an obviously live hostile threat at spawn

At spawn in the later runs:
- no immediate aggression
- no zombie vocal
- no uncontrolled roaming

That means the hard dummy shell contract is doing real work.

### Improvement 3 — movement happened for real

This is the most important improvement.
Not pretty movement.
Not natural movement.
But **real displacement**.

The dummy could now:
- receive move commands
- change square
- commit a new location
- remain away from the original anchor in the main automated path

That is a deep structural win.

### Improvement 4 — position authority improved enough to matter

The later runs showed that:
- automated move no longer immediately snapped back to the original spot
- manual command no longer immediately reproduced the old regression either

That means move authority and position authority are starting to align.

---

## What still failed even after progress

This is just as important as the successes.

### 1. Visual shell still reads as a zombie

The player still saw a zombie-looking body.
And the visual signature still strongly suggested zombie body skin / zombie-coded presentation.

So the branch has **not** solved the visual shell problem yet.

### 2. Attack-like presentation residue remains

The later runs showed a new, more refined failure:
- the dummy often did not land real attacks
- but it could still look like it was attacking
- after movement it could enter in-place stepping / attack-like posture
- contact/proximity sometimes changed or paused that motion

This means the remaining problem is not simply "hostile AI".
It looks more like:
- attack animation residue
- alert-turn residue
- zombie presentation residue

That is much narrower than before, but still real.

### 3. Delete blocking reason evolved, but did not disappear

The delete path shifted from earlier target-centric failure modes toward `actor_is_attacking` style failure.
That is meaningful.

It suggests:
- the shell may no longer be fully interpreted as actively targeting in the old way,
- but the game can still believe the actor is in an attack state or attack presentation state.

Again, narrower—but not solved.

---

## The most important lesson of the day

If only one lesson survives this document, it should be this:

> Progress started when the project stopped trying to solve "all of NPC-ness" at once,
> and instead solved one narrow physical reality at a time.

Those realities were:

1. can the dummy stay quiet?
2. can the dummy avoid behaving like a real attacker?
3. can the dummy physically move for real?
4. can the system accept the moved position as true?

That approach worked.

The earlier approach—solving movement, appearance, social identity, behavior, combat, and continuity all at once—did not.

---

## Why this matters for next time

The branch is no longer in the old state of "everything fails everywhere".

It is now in a state where the remaining issues are much more concrete:

- visual aggression residue
- player-facing / turn residue
- zombie body skin and zombie presentation lock

That means the next session should not go backward.
It should continue this same philosophy:

- simplify the active problem
- hit the remaining layer directly
- do not reintroduce complexity prematurely

### In practical terms, that means:

Do next:
1. visual aggression scrub
2. stronger zombie-body visual hard fail

Do not do first:
- relationship complexity
- full recovery deep dive
- TEST 04 noise-heavy return-path work

---

## Final end-of-day statement

Today did not produce a human-looking NPC.
But that is not the whole truth.

Today produced something arguably more important:

- a quieter problem,
- a narrower problem,
- and a branch where movement and non-aggression can now be studied separately from the old social/goal mess.

That is a real win.

The project is not at the finish line.
But it is no longer trapped in the same shapeless failure it had before.

That is the durable lesson to carry into the next session.
