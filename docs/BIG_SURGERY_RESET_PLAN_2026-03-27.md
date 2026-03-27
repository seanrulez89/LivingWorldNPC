# Big Surgery Reset Plan — 2026-03-27

## Core decision

The next phase should stop optimizing the current experiment around three simultaneous relationship modes.

For now, remove unnecessary noise from the main loop.

The simplified baseline should be:

- one test NPC
- one active companion-style relationship lock
- one main question at a time

That means the first surgery loop should focus on **locked-friendly companion behavior**, not on repeatedly cycling:

- friendly
- neutral
- hostile

## Why the reset is needed

Recent tests keep repeating the same structural shape:

1. spawn still reads as zombie
2. movement still does not produce real displacement
3. return still splits continuity between old shell and replacement shell
4. later friendly reapply can sometimes alter appearance, which proves the system is not totally dead, but it does not fix the underlying architecture

The relationship matrix now adds churn and false leads.

## Scope reduction for the first surgery loop

### Keep

- debug harness
- observability / summaries / cleanup tools
- managed-shell tracing
- test automation flow

### Temporarily de-emphasize

- hostile validation
- neutral validation
- trust drift / betrayal / pending_betrayal transitions
- posture polish
- subtle human-like animation tuning

### New immediate success criteria

1. locked-friendly shell spawns consistently
2. the shell no longer reverts to obvious zombie authority during the same test loop
3. the shell moves at least one real tile when commanded
4. return-path continuity preserves one active logical shell identity

## Proposed architecture reset

### 1. Relationship authority lock

Introduce a top-priority manual relationship override that cannot be silently replaced by:

- story logic
- betrayal logic
- ambient hostility drift
- non-test policy maintenance

### 2. Role split

Stop assuming the same actor configuration can cleanly serve all roles.

Longer-term target:

- hostile shell path
- companion shell path

These should become separable enough that friendly command movement and zombie hostility do not keep fighting inside one actor lifecycle.

### 3. Failed-shell rebuild policy

If spawn-time humanization still fails practical probes, treat that as a failed shell candidate.

Do not endlessly keep repairing the same failing shell.

### 4. Generation-based identity

Identity needs more than `npcId`.

Track at least:

- `npcId`
- `generationId`
- `carrierKind`
- last known active actor ref

This should make it easier to prevent old/orphaned shells from competing with replacement shells.

### 5. Deterministic companion movement

If the current zombie-native locomotion path keeps yielding:

- `moving=true`
- `path2=true`
- `totalDelta=0.00`

then the companion shell may need a more explicit movement layer for the first real success target.

The first goal is not elegance.
The first goal is verified real displacement.

## Suggested implementation order

### Phase A — Simplify the experiment

1. lock the main test harness to friendly/trusted-companion mode
2. block neutral/hostile drift from overriding the lock
3. keep TEST 01-04 but interpret them through the locked-friendly baseline only

### Phase B — Identity and lifecycle reset

1. add generation tracking
2. mark failed shells and orphaned shells explicitly
3. prevent replacement spawn while an equivalent active generation is still unresolved

### Phase C — Companion shell path

1. isolate companion shell assumptions from hostile shell assumptions
2. rebuild the friendly shell path around stable appearance + movement + continuity
3. only after that, reintroduce other relationship modes one by one

## What not to do next

- do not immediately add more relationship toggles
- do not spend the next pass on posture polish alone
- do not keep assuming that more suppression flags on the same `IsoZombie` actor will magically cross the final gap
- do not bury this reset point under a large mixed patch without preserving a clean baseline

## One-line goal for the next branch

**Prove one locked-friendly companion shell can spawn, stay visually stable enough, move for real, and survive return-path continuity without splitting.**
