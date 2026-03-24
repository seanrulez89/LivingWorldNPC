# Manual-Assisted Automated Test Runner

Date: 2026-03-25
Branch: `spike/isozombie`
Status: implemented, needs in-game validation

## Why this was needed

The previous debug workflow required too many manual menu clicks in rapid succession:

- spawn NPC
- dump summary
- change policy
- dump again
- move away / return
- dump at the critical moment

That made it too easy to miss the exact window where important runtime transitions occurred.

At the same time, some test dimensions should remain manual:

- sound
- visual impression
- posture / animation read
- whether the shell *feels* human or zombie-like

So the right design is not full automation.
It is **manual-assisted automation**.

---

## What is automated now

New debug-menu automation path under:

- `LWN Settings`
  - `IsoZombie Test`
    - `Automation`

### Actions

- `Start Automated Test`
- `Continue Automated Test`
- `Dump Automated Test Status`
- `Reset Automated Test`

---

## Standard automated scenario

### Phase 1 — Spawn baseline

`Start Automated Test`

Automates:

- spawn sterile debug IsoZombie shell
- capture baseline summary dump
- capture baseline movement/audio dump

Then prompts the human to manually observe:

- current sound
- current appearance
- current posture / animation

### Phase 2 — Policy cycle

`Continue Automated Test`

Automates:

- force hostile policy (with automation-only temporary override when needed)
- dump summary
- dump movement/audio
- force friendly policy
- dump summary
- dump movement/audio

Then prompts the human to:

- briefly inspect current visual/audio state
- move far away and come back

### Phase 3 — Return capture

`Continue Automated Test` again after returning

Automates:

- summary dump for the same tracked NPC id
- movement/audio dump
- nearby zombie-like census
- last actor failure dump

Then prompts the human to manually evaluate:

- sound
- appearance
- posture
- animation
- attack behavior

---

## Why this is the right level of automation

It preserves the parts the human is best at:

- noticing subtle posture reads
- hearing zombie-vs-human audio
- judging whether something *looks* like the same NPC

While automating the parts the machine is best at:

- consistent policy sequence
- consistent dump timing
- consistent log emission
- consistent target NPC tracking by id rather than nearest-only clicking

---

## Implementation notes

Implemented in:

- `42/media/lua/client/92_LWN_DebugTools.lua`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua`

Key design points:

- automation state is stored in debug state
- the scenario tracks a concrete `npcId`
- follow-up phases act on that same record instead of relying only on ad-hoc nearest selection
- prompts are emitted via in-game debug speech/log messages so the human knows what to do next

---

## Intended future use

After each meaningful runtime patch, the default practice should be:

1. run `Start Automated Test`
2. visually/audibly inspect the spawn baseline
3. run `Continue Automated Test`
4. move away and return
5. run `Continue Automated Test` again
6. report the human-observed sound/visual/posture results alongside the dumped logs

That gives a much more reproducible loop for future regressions and fixes.
