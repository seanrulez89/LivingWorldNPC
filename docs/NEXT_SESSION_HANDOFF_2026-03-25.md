# Next Session Handoff — 2026-03-25

Branch: `spike/isozombie`
Status: end-of-day handoff after multiple runtime hardening passes and a final automated/manual-assisted test cycle

## 1. Where the branch stands now

Today introduced a concentrated stack of `IsoZombie` shell runtime work:

### Core commits from this session

- `bde0a9a` — `Split initial humanization from maintenance`
- `439e47d` — `Harden debug embodiment continuity and trim test menus`
- `413f318` — `Add sterile test identity harness for isozombie`
- `b358c47` — `Harden isozombie quarantine and actor recovery`
- `f12775a` — `Lock quarantined shell behavior authority`
- `54115ac` — `Add appearance lock safeguards and zombie census`
- `cc5652f` — `Add posture idle reset experiment for isozombie`
- `e4208fb` — `Lock return-path hostile reversion and shell cleanup`
- `018db42` — `Add manual-assisted automated isozombie test runner`

The branch is no longer in the “ad hoc menu clicks and loose observations” stage.
It now has:

- explicit initial-vs-maintenance humanization structure
- test harness and sterile lane
- quarantine / attack-lock logic
- recovery/actor-lost hardening
- nearby zombie census tools
- manual-assisted automation menu flow

## 2. What is currently improved

### Confirmed improvements

- spawn-time zombie audio leak appears significantly improved
- policy/automation sequence now produces more consistent dump timing
- split-body/two-bodies-at-once symptom is not happening on every run anymore
- automation is viable in principle for repeated test structure

### Partially improved

- appearance drift is reduced but not fully solved
- policy transitions may still trigger one or more outfit/appearance changes
- cleanup protection is better, but visible shell vs logical record separation is not fully ruled out yet

## 3. What is still clearly broken

### A. Return-path hostile reversion is still the sharpest runtime bug

Most important end-of-day finding:

- after travelling away and returning,
- before any new relationship toggle,
- the originally spawned shell can immediately behave like a hostile zombie,
- including real hit/attack confirmation.

This means the main unresolved problem remains:

**distance-return / recovery-time loss of behavior authority over the original shell**.

### B. Posture experiment did not achieve the intended perceptual result

Even after the anti-hunch posture pass:

- user still perceived the shell as hunched and zombie-like

Interpretation:

- current accessible idle/anim reset controls are not enough to defeat the zombie read in practice
- posture is still important, but currently looks secondary to the behavior-authority failure

### C. Automation prompt text is currently degraded by encoding in speech bubbles

Manual-assisted automation menu is useful, but:

- Korean speech-bubble text appears garbled / unreadable

Likely implication:

- `player:Say(...)` prompt path is not safe for the current Korean strings / rendering path
- prompts should likely be converted to ASCII/English or moved to a different player-visible notification path while retaining usability

## 4. Most reliable current interpretation of shell/runtime state

The best current model is:

- the canonical NPC record often remains alive and controllable
- the live world shell can still recover or drift into hostile zombie-native behavior after distance-return
- nearby-zombie cleanup can sometimes remove the visible shell object from view
- but the logical record may still remain until explicit delete

So the branch is still fighting **live shell authority continuity**, not just appearance illusion.

## 5. Highest-priority next steps (recommended order)

### Priority 1 — Fix automation prompt channel

Do this before relying on the automated runner heavily again.

Target:

- replace Korean speech-bubble prompts with an encoding-safe prompt strategy
- likely easiest first step: ASCII/English prompt text while keeping the same phased automation flow

Rationale:

- the automation itself is useful, but unreadable prompts lower its value right away
- this is low-risk compared to changing shell runtime again

### Priority 2 — Re-verify attack-lock on return-path hostility using automation

After prompt fix:

- run the automated scenario again
- at return-path threat moment, verify whether `attackLock` is present on the attacker-looking shell

This is the key discriminator for the next runtime decision:

- either attack lock is not being applied when expected
- or it is applied but the live attacking shell is no longer the shell we think it is

### Priority 3 — Re-check cleanup semantics after visible hostile shell removal

Need an explicit retest of this exact question:

- after nearby-zombie cleanup removes the visible attacker,
- do relationship controls and automated status/dumps still target the same logical NPC record?

This was not re-confirmed cleanly in the final run and remains important.

### Priority 4 — Treat posture as secondary until behavior authority is under control

The anti-hunch posture pass was worth trying, but user perception still said:

- “it still looks hunched like a zombie.”

Recommendation:

- do not let posture work outrun behavior-authority work right now
- keep posture on the board, but subordinate it to shell-control continuity

## 6. Final test result that should anchor the next session

End-of-day final test summary:

- spawn quiet: **yes / improved**
- distance-return hostile reversion: **yes / still broken**
- split-body symptom: **not observed in final run**
- posture improvement: **no meaningful perceived success**
- automation workflow: **conceptually useful but prompt encoding broken**

## 7. Practical note for next session

Before resuming deep runtime changes:

1. fix automation prompt readability first
2. rerun the automated scenario once with minimal extra manual clicks
3. only then decide whether the next code patch should target:
   - attack-lock timing
   - shell identity mismatch at return time
   - or actor_lost / cleanup semantics again

If the next run still shows immediate return-path attack before any user input, then the branch should continue prioritizing:

- recovery-time hostile reversion prevention
- live shell / logical record binding integrity

not posture polish.
