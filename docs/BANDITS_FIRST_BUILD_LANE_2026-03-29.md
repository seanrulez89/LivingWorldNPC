# Bandits-First Build Lane — 2026-03-29 Late Session

Branch at time of writing: `spike/bandits-visual-probe-v1`

## 1. Why this document exists

This document records the late-session pivot after the final pre-Bandits `IsoZombie` experiments were already exhausted and after the first Bandits-style direct visual probe pass was tested in-game.

The goal is to prevent the next session from collapsing these distinct phases into one blurry memory:

1. the final three **within-LWN** `IsoZombie` experiments,
2. the first **Bandits-style direct visual probe v1**,
3. the follow-up **probe checkpoint / settle re-probe** instrumentation,
4. and the new **Bandits-first build lane** patch.

---

## 2. What was already settled before this late-session work

By the time this late session began, all of the following were already considered settled enough not to casually re-prove:

- `IsoZombie` had already won the practical shell decision.
- the final three pre-Bandits experiments inside the existing LWN lane had already been completed:
  - narrow guard / role relax,
  - overwrite cadence tracking,
  - runtime-settle alive-reset attempt.
- none of those three changed the branch conclusion enough to keep spending the main line there.
- the plan had already shifted to **gradual Bandits-style adoption**, not to “one more LWN-only visual tweak.”

That context matters, because the work below is not a restart of the old argument; it is the first concrete follow-through on the Bandits adoption decision.

---

## 3. First late-session patch: Bandits visual probe checkpoints + settle re-probe

Late-session code patch and commit:

- `c82f8c6` — `Add Bandits probe checkpoints and settle reprobe`

### 3.1 Patch intent

This patch did **not** try to fully replace the LWN humanization lane.
It intentionally stayed conservative and asked a narrower question:

> If we keep the current LWN build path but add a Bandits-style direct visual stamping pass plus better checkpoints, do we get a decisive visible change?

### 3.2 What the patch added

- direct-copy probe checkpoint after the Bandits-style visual copy step
- post-basic-flags checkpoint
- post-runtime-settle re-probe checkpoint
- net-effect classification such as:
  - `no_effect`
  - `partial_visual_shift`
  - `direct_copy_survived`
  - `direct_copy_reverted_before_refresh_end`
- debug summary fields for:
  - Bandits probe stage,
  - net effect,
  - post-flags role,
  - post-flags failure code.

### 3.3 In-game result

User-tested result:

- the NPC still looked like a zombie.

### 3.4 What `console.txt` proved

The important late-session lines from `/mnt/c/Users/seanr/Zomboid/console.txt` were:

- `bProbe=yes`
- `bEffect=partial_visual_shift`
- `bPostRole=reanimated_zombie`
- `bPostFail=fail_presentation_role_zombie`

Representative appearance diff also changed for real:

- `skin:F_ZedBody02_level1->F_ZedBody04_level1`
- `itemVisuals:4->8`
- `persistentOutfitId:-2143157835->-2143158208`

### 3.5 Interpretation

This was an important result because it ruled out one specific weak interpretation.

It showed that the Bandits-style direct stamping pass was **not** a total no-op.
Visual-related state did shift.
However, the final actor still ended at:

- `presentationRole=reanimated_zombie`
- `failCode=fail_presentation_role_zombie`

So the late-session lesson was:

- a Bandits-style visual probe can modify visible-state inputs,
- but **as a trailing helper bolted onto the existing LWN build path**, it still loses the final ownership battle.

In other words:

> The issue is no longer “did the Bandits-style probe run?”
> It did.
> The issue is “who owns final presentation truth after it runs?”

---

## 4. Why the next patch had to become a Bandits-first build lane

After the checkpoint patch, continuing to add more tiny probe instrumentation on the same trailing-helper model no longer looked efficient.

The stronger late-session conclusion became:

- Bandits-style stamping should no longer sit only as a **post-humanizer probe**.
- it needs a test lane where it is promoted to the **main build step** for the dummy appearance path.

That does **not** mean “rewrite the whole mod as Bandits.”
It means a narrower structural test:

- use `ShellHumanizer.applyInitial` only as a descriptor seed when needed,
- skip the old full `maintain` / legacy appearance rebuild as the main visual truth in the dummy lane,
- run Bandits-style direct stamping as the primary build step,
- then apply only the minimum shell/carrier flags needed to keep the shell usable,
- and observe whether the zombie-role trap changes at all.

---

## 5. Second late-session patch: Bandits-first build lane

This late-session patch was applied directly after the console review.

### 5.1 High-level design

New lane behavior for the minimal dummy path when the feature flag is on:

- `ShellHumanizer.applyInitial` remains allowed as an early seed step
- the old `ShellHumanizer.maintain` / legacy rebuild path is **not** used as the main appearance authority for the dummy build lane
- Bandits-style direct visual stamping becomes the primary appearance build step
- after that, carrier setup applies a **minimal shell lane** instead of the heavier posture/illusion refresh bundle

### 5.2 Key implementation idea

The patch introduces the concept of a **Bandits-first dummy carrier state**:

- use shell-lane contract and audio suppression
- aggressively clear zombie aggro / combat residue
- keep the shell managed and quiet
- avoid the heavier refresh-heavy posture / persistent-illusion path in this lane

This is explicitly trying to test whether some of the old post-build maintenance stack was itself helping reassert the zombie-owned presentation basin.

### 5.3 What changed conceptually

Before this patch, the order was effectively:

1. LWN initial / maintain build
2. Bandits-style visual probe
3. normal zombie carrier flag / posture / illusion path
4. final probe

After this patch, the dummy lane aims closer to:

1. seed descriptor if needed
2. Bandits-style direct stamping as the main build step
3. minimal shell lane + quiet/non-hostile enforcement
4. final probe

### 5.4 What this patch is trying to answer

The new question is no longer:

> “Does direct visual stamping do anything?”

That was already answered with “yes, partially.”

The new question is:

> “If direct Bandits-style stamping becomes the main appearance build step and the heavier old post-build carrier stack is reduced, does the final zombie-role trap change?”

---

## 6. What to look for in the next in-game test

The next test should focus on the following debug signals:

- `bProbe=yes`
- `bEffect=...`
- `bPostRole=...`
- `bPostFail=...`
- `bFirst=yes`
- `bFirstMode=idle|move`

The most important distinctions are:

### 6.1 Best-case improvement
- `bFirst=yes`
- `bEffect=direct_copy_survived` or stronger
- `bPostRole` changes away from `reanimated_zombie`
- failure code changes materially

### 6.2 Mixed result
- `bFirst=yes`
- visual diff grows or stabilizes
- but `bPostRole=reanimated_zombie` remains

This would mean Bandits-first build helps more than trailing-probe mode, but final presentation ownership is still above this layer.

### 6.3 No strategic improvement
- `bFirst=yes`
- still `bEffect=partial_visual_shift`
- still `bPostRole=reanimated_zombie`
- still `fail_presentation_role_zombie`

If that happens, the next step should likely stop spending time on “copying more appearance” and instead focus on whichever specific post-build engine/runtime ownership layer keeps reasserting the zombie role.

---

## 7. Practical caution

This patch is intentionally more opinionated than the prior checkpoint-only patch.
It touches not just instrumentation, but the actual dummy build path.

So the next session should verify both:

- visual outcome,
- and whether minimal dummy behavior remains acceptably stable enough for the same test flow.

In other words, the patch should be judged not only on “did it stop looking zombie-like?” but also on whether it preserved the current test harness usefulness.

---

## 8. One-line takeaway

The late-session console review proved that Bandits-style direct stamping already causes a **real but partial** visual shift.
The new patch exists because that was no longer enough: the next meaningful experiment is to make Bandits-style stamping the **main dummy build lane**, not just a trailing probe.
