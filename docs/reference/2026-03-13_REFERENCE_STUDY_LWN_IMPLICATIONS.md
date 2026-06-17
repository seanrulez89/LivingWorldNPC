# LWN Implications From Reference Mods Rescan - 2026-03-13

## Scope

This document turns the full `reference_mods/` rescan into direct implications for Living World NPC.

Primary trouble spots:

- transparent actor
- corpse flicker
- cleanup or death overlap
- stale target
- gray areas caused by implicit `IsoPlayer` assumptions

Primary source folders behind these conclusions:

- `reference_mods/3001908830/mods/PZNS_Framework`
- `reference_mods/3243965932/mods/PZNS_NeighbourhoodNpcs`
- `reference_mods/3268487204/mods/Bandits`
- `reference_mods/3403180543/mods/BanditsWeekOne`
- `reference_mods/3076017350/mods/MyLittleBraven`
- `reference_mods/3088354589/mods/BravensNPCFramework`
- `reference_mods/1905148104/mods/Superb-Survivors`
- `reference_mods/2980672778/mods/SuperbSurvivorsContinued`
- `reference_mods/3397396843/mods/KnoxEventExpanded`

## Top 5 Implications For LWN

### 1. Embodiment must become an explicit staged pipeline

Why this is first:

- `Bandits` proves that Build 42 presentation is a separate phase. `Bandit.ApplyVisuals()` clears and rebuilds visuals after the carrier exists.
- `Superb-Survivors`, `SuperbSurvivorsContinued`, and PZNS-era human mods repeatedly force clothing and sprite refresh after spawn or load.

LWN implication:

- "Create actor" cannot mean "ready for gameplay."
- LWN needs an embodiment sequence such as:
  - reserve or load canonical NPC record
  - create carrier
  - attach appearance and equipment
  - force visual rebuild
  - validate presentation state
  - only then expose targeting, cleanup, and combat

Why this matters for current bugs:

- Transparent actor is much more likely to be a missing or incomplete stage boundary than a single bad flag.

### 2. Death, corpse, and cleanup need separate owners

Why this is second:

- `Bandits` cleanly splits `OnZombieDead` and `OnDeadBodySpawn`.
- `BanditsWeekOne` keeps corpse simulation in scenario data instead of mixing it with one big destroy path.
- Braven references show the opposite pattern: hide or remove the actor immediately and let that stand in for all lifecycle concerns.

LWN implication:

- A death latch should fire once.
- Corpse creation or corpse follow-up should happen after death latch, not inside the same ad hoc cleanup branch.
- Cleanup should not be allowed to race or reinterpret death.

Why this matters for current bugs:

- Corpse flicker and cleanup or death overlap both point to multiple subsystems believing they own the same transition.

### 3. Durable targeting should move from actor refs to canonical ids

Why this is third:

- `PZNS_Framework` keeps stable IDs in its canonical record and treats actor pointers as runtime fields.
- `MyLittleBraven` explicitly resets stale targets when the old one is dead or invalid.
- `Bandits` clears invalid targets during update rather than trusting a stale live ref forever.

LWN implication:

- Long-lived target ownership should be by canonical NPC id or explicit target contract.
- Live actor refs can stay as short-lived caches.
- Despawn, death, and invalidation should clear runtime target refs immediately.

Why this matters for current bugs:

- Stale target is a direct symptom of object identity being treated as more durable than embodiment.

### 4. `IsoPlayer` must be wrapped behind an embodiment adapter

Why this is fourth:

- Build 41 references show `IsoPlayer` can work, but also show how quickly the whole codebase becomes coupled to player-specific assumptions.
- `Bandits` is instructive precisely because the carrier is just a carrier. Canonical state is elsewhere.
- `KnoxEventExpanded` also suggests a meta-layer above the visible world actor, even though the low-level implementation is hidden in class files.

LWN implication:

- If LWN still uses `IsoPlayer`, other systems should not talk to it as if it were canonical identity.
- Cleanup, death, context menu lookup, target ownership, and visual readiness should go through a narrower embodiment API.

Why this matters for current bugs:

- The current gray zone around "real actor, preview actor, unloading actor, dead actor, invisible actor" will keep leaking until the carrier is demoted to an implementation detail.

### 5. Preview and companion hacks must stay out of core runtime

Why this is fifth:

- `BanditsCreator` intentionally uses invisible, ghosted preview `IsoPlayer` models for editor UI.
- `BravensNPCFramework` and `MyLittleBraven` intentionally use invisibility, no-clip, and emergency respawn to preserve a companion fantasy.

LWN implication:

- Those patterns can be valid inside editor or highly scoped companion code.
- They are poor defaults for population runtime or authoritative state transitions.

Why this matters for current bugs:

- If LWN uses hidden or half-removed actors to dodge lifecycle problems, it will keep reproducing transparent actor and corpse or cleanup edge cases.

## Directly Applicable In Build 42

- `Bandits`:
  - canonical state outside the carrier
  - explicit visual assembly stage
  - separate death event and dead-body event thinking
  - target invalidation discipline
- `PZNS_Framework`:
  - wrapper record owns identity
  - runtime actor pointer is cache only
- `PZNS_NeighbourhoodNpcs`:
  - spawn policy should sit above core runtime state
- `KnoxEventExpanded`:
  - context menu, group UX, and corpse-zone UX ideas

## High-Risk To Import Directly

- `Superb-Survivors` and `SuperbSurvivorsContinued`:
  - direct actor deletion
  - save-file ownership
  - broad tick and square-load lifecycle spread
- `PZNS_Framework`:
  - ghost-mode unload and nil-job workaround
- `BravensNPCFramework` and `MyLittleBraven`:
  - invisibility and no-clip as state transitions
  - death as immediate remove or respawn
- `BanditsCreator`:
  - preview model rules
- `KnoxEventExpanded`:
  - any runtime assumption that depends on replaced class files

## Issue Mapping

### Transparent actor

- Most likely source class:
  - missing embodiment stage or incomplete visual rebuild
- Strongest references:
  - `Bandits`
  - `Superb-Survivors`
  - `SuperbSurvivorsContinued`
  - `PZNS_Framework`

### Corpse flicker

- Most likely source class:
  - death, corpse, and cleanup are overlapping on the same actor window
- Strongest references:
  - `Bandits`
  - `BanditsWeekOne`

### Cleanup or death overlap

- Most likely source class:
  - no single owner for transition into dead or unloading state
- Strongest references:
  - `Bandits`
  - `PZNS_Framework`
  - negative warning from `BravensNPCFramework`

### Stale target

- Most likely source class:
  - target state stored as actor ref instead of stable id plus cache
- Strongest references:
  - `PZNS_Framework`
  - `MyLittleBraven`
  - `Bandits`

### `IsoPlayer` gray area

- Most likely source class:
  - carrier assumptions leaked into state, cleanup, context menu, and targeting code
- Strongest references:
  - `PZNS_Framework`
  - `Bandits`
  - `KnoxEventExpanded`

## Recommended LWN Design Direction

1. Define canonical NPC state as the only authority for identity, target ownership, and death ownership.
2. Introduce an embodiment state machine with explicit stages for spawn, visual-ready, active, death-latched, corpse-owned, unload-pending, and removed.
3. Convert long-lived target references to canonical ids and make actor refs disposable caches.
4. Let exactly one subsystem own first entry into death-latched state.
5. Keep preview, editor, and companion-only hacks out of the ordinary world runtime.
