# Carrier Experiment Results - 2026-03-14

## Executive summary

As of 2026-03-14, the project has enough evidence to separate the recent carrier experiments into three categories:

- `IsoPlayer`
  - world-stable enough to spawn and delete
  - still fails the core alive-visibility requirement
- `IsoSurvivor`
  - constructor viability exists through at least one path
  - not runtime-ready as a world NPC carrier in the tested path
  - now fails safely instead of crashing the game
- `IsoZombie`
  - not yet implemented as a carrier
  - next practical embodied-carrier spike candidate

## Baseline result: `IsoPlayer`

### What succeeded

- debug spawn works
- delete behavior is now stable enough for testing
- non-combat delete succeeds immediately
- combat-time delete is blocked with a message instead of risking the previous crash

### What failed

- alive NPC still remains visually transparent

### Interpretation

`IsoPlayer` is usable as a simulation shell, but still does not satisfy the project's actual embodiment goal.
Its main failure mode is presentation/rendering, not basic runtime existence.

## Spike result: `IsoSurvivor`

### What was attempted

A proof-of-life `IsoSurvivor` carrier spike was added behind the carrier adapter.

Constructor candidates were tried in order, including:

1. `SurvivorFactory.InstansiateInCell(desc, cell, x, y, z)`
2. several `IsoSurvivor.new(...)` signatures

### What was confirmed in logs

The tested path that actually returned an object was:

- `SurvivorFactory.InstansiateInCell(desc,cell,x,y,z)`

However, the resulting object consistently showed:

- `bodyDamage=nil`
- `stats=true`
- `inventory=true`
- `inWorld=false`
- `squarePresent=true`
- `descriptor=true`

### What that means

This object appears to be **constructor-viable but runtime-incomplete** for LivingWorldNPC's needs.

In other words:

- it is not enough to obtain an `IsoSurvivor` instance
- the returned object is not a safe, fully initialized world-ready NPC carrier in the tested path

### Stability progression across the spike

#### Early spike

- `IsoSurvivor` spawn attempts could cause multiple errors and game termination
- the game could crash before there was time to judge visible embodiment

#### Safety-hardened spike

After the safety passes:

- unsafe `IsoSurvivor` objects are detected and rejected before embodiment proceeds
- the game no longer needs to crash for this experiment to fail
- failure is now surfaced as a blocked spawn / rejected runtime actor

#### Current state after final reject-path trim

- `IsoSurvivor` spawn is still rejected
- no game-ending crash was observed in the latest test
- the remaining reject-path noise has been reduced significantly
- the experiment currently ends in a clean "not viable" result rather than a catastrophic one

## Current verdict on `IsoSurvivor`

At the current level of evidence, `IsoSurvivor` should **not** be treated as the next primary carrier for LivingWorldNPC.

Reason:

- the observed constructor path does not yield a runtime-ready world actor
- the project had to harden around rejection rather than progress toward stable embodiment
- the experiment now serves mainly as evidence that constructor viability is not the same as carrier viability

This does not prove that every possible `IsoSurvivor` path is impossible.
It does mean the currently discovered/working path is not good enough to justify deeper commitment right now.

## Architecture takeaway

The experiments reinforce the same architecture lesson:

- keep the canonical NPC record/state system
- keep the carrier adapter
- treat carriers as replaceable bodies, not as the NPC itself

This remains the most valuable durable outcome of the recent work.

## Recommended next embodied-carrier experiment

The next embodied spike should be:

- `IsoZombie`

Reason:

- unlike `IsoPlayer`, it may offer stronger engine-native world visibility/update behavior
- unlike current `IsoSurvivor` results, it may provide a more runtime-complete live actor shell

## Recommended strategic fallback if embodied carriers keep failing

If `IsoZombie` is also unconvincing, the project should lean harder toward:

- logic-first / presentation-light fallback

Meaning:

- NPC identity/state/AI persists regardless of whether a full world actor exists
- embodiment becomes optional, temporary, and carrier-dependent

## Bottom line

Current standing after all tests so far:

- `IsoPlayer`: stable enough to test, but still invisible
- `IsoSurvivor`: safer to test now, but not currently viable as a runtime-ready carrier
- `IsoZombie`: next experiment worth running
