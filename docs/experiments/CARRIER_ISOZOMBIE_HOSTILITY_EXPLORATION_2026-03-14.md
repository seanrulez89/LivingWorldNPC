# Carrier IsoZombie Hostility Exploration - 2026-03-14

## Why this pass exists

After `IsoZombie` became visible, persistent, interactive, and stable, the next issue was no longer embodiment viability.

It was relationship-driven combat policy.

The project requirement is:

- do not hardcode permanent pacifism
- trusted companions should eventually behave as allies
- betrayal / hostility should still be possible later

## What this pass changes

This pass adds a careful first control layer without overcommitting to fragile engine hooks.

### 1. Relationship policy is now applied directly to the zombie shell

`Carrier_IsoZombie` now uses `Social.relationshipCombatPolicy(record)` not just to tag modData, but to drive the shell's immediate combat posture.

### 2. Friendly / neutral shell posture

For policy states that still want the shell neutralized:

- `setUseless(true)`
- `setTargetSeenTime(0)`
- `setCanWalk(false)`
- `setNoTeeth(true)`
- `setTarget(nil)`
- `setAttackedBy(nil)`

This is meant to suppress zombie-initiated aggression conservatively.

### 3. Hostile shell posture

For hostile policy:

- `setUseless(false)`
- `setCanWalk(true)`
- `setNoTeeth(false)`
- if a player reference exists, attempt:
  - `setTarget(player)`
  - `faceThisObject(player)`
  - `pathToCharacter(player)`

This is still exploratory, but it gives the shell a controlled path out of the current inert mode.

## Important limitation

This pass does **not** claim to fully solve player attack suppression.

Specifically:

- engine-level player attack targeting may still require a more specific interception point than carrier policy alone
- this pass focuses first on shell posture and hostility intent rather than hard promises about player-input suppression

That is intentional.
The code remains easier to reason about and safer to roll back.

## Why this is the right level of caution

At this stage, `IsoZombie` is the first carrier to produce a stable visible shell.

Overly invasive combat hacks would risk destabilizing the first working embodied candidate.
So the correct next move is:

- policy first
- targeted engine-control hooks later, once the minimal shell remains stable

## Recommended next step

If the current shell stays stable, the next work item should be a narrowly scoped search for the best engine hook or target-selection gate to suppress player attacks only when:

- `relationshipCombatPolicy(record).allowPlayerAttack == false`

and to allow active hostility when:

- `allowCarrierAttackPlayer == true`

That future work should remain policy-driven rather than hardcoded to the carrier type.
