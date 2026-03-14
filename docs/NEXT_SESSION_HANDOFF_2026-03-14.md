# Next Session Handoff - 2026-03-14

## Current branch

- active experimental branch: `spike/isozombie`

## Current headline status

### Stable findings

- `IsoPlayer`
  - still spawns and deletes stably enough for testing
  - still transparent while alive
  - no longer the preferred embodiment direction

- `IsoSurvivor`
  - constructor viability was observed through `SurvivorFactory.InstansiateInCell(...)`
  - runtime-ready embodiment failed (`bodyDamage=nil`, `inWorld=false`)
  - now safely rejects without crashing the game
  - not currently a promising next carrier

- `IsoZombie`
  - now visibly spawns
  - remains in-world instead of disappearing immediately
  - right-click context menu works
  - delete works safely
  - no major runtime error spam in the latest stable tests
  - currently the strongest carrier candidate

## What `IsoZombie` currently is

It is best understood as:

- a visible persistent managed zombie shell
- not yet a finished human-like NPC embodiment

Observed latest behavior:

- visible and persistent
- inert / does not attack or move in friendly/neutral state
- player can still attack it
- ordinary zombies still appear to treat it as zombie-side rather than a player ally target

## Relationship/hostility policy state

A first policy layer now exists:

- `Social.relationshipCombatPolicy(record)`

Policy states:

- `friendly`
- `neutral`
- `hostile`

Current shell behavior:

- friendly/neutral
  - shell is neutralized/inert
  - `setGodMod(true)` is applied only when `allowPlayerAttack == false`
- hostile
  - shell is allowed out of inert posture
  - minimal target/face/path attempts toward player are made if a player reference exists

Important limitation:

- this does not yet prove complete player-attack suppression for friendly shells
- this does not yet prove fully working hostile activation/combat behavior

## Important confirmed test result from latest run

Latest live test reported:

- no visible runtime errors
- `IsoZombie` stayed visible and persisted
- right-click menu appeared
- delete worked
- player could still attack even at max trust
- the managed shell did not attack the player
- ordinary zombies still preferred attacking the player rather than the managed shell

## Main unresolved problems

### 1. Friendly shell player attack suppression is not solved

Current `setGodMod(true)` probe is not sufficient to prove that trusted companion shells are practically protected from player attacks.

### 2. Hostile activation is only a first posture change, not a full behavior layer

The shell can be de-neutralized by policy, but hostile pathing/attack behavior is not yet proven.

### 3. Debug trust UI is incomplete

Current debug menu status:

- trust increase UI exists (`Debug: Boost Nearest NPC Trust`)
- trust decrease UI does **not** exist yet
- backend support does already exist via:
  - `DebugTools.adjustNearestRelationship(player, field, delta)`

This means adding a `Debug: Lower Nearest NPC Trust` menu item should be a low-risk next step.

## Best next actions

### A. Add trust decrease debug UI

Low risk, high testing value.

Recommended:

- `Debug: Lower Nearest NPC Trust`
- possibly also presets like:
  - `Debug: Set Nearest NPC Friendly`
  - `Debug: Set Nearest NPC Hostile`

### B. Find the real player-attack suppression control point

The next technical goal is not broad combat hacking.
It is to find the narrowest reliable control point for:

- suppressing player damage/targeting against `friendly` shells
- while still allowing `neutral/hostile` shells to remain attackable

### C. Explore real hostile activation only after A/B are clearer

Current hostile posture work is still exploratory.
Do not overcomplicate it until player-side attack policy is clearer.

## Documents worth reading first next time

- `docs/CARRIER_EXPERIMENT_RESULTS_2026-03-14.md`
- `docs/CARRIER_ISOZOMBIE_SUCCESS_RESULT_2026-03-14.md`
- `docs/CARRIER_ISOZOMBIE_TRUST_HOSTILITY_2026-03-14.md`
- `docs/CARRIER_ISOZOMBIE_HOSTILITY_EXPLORATION_2026-03-14.md`
- `docs/CARRIER_ISOZOMBIE_FRIENDLY_ATTACK_SUPPRESSION_2026-03-14.md`

## Bottom line

If work resumes next week, do **not** restart from `IsoPlayer` or `IsoSurvivor`.

Resume from:

- branch `spike/isozombie`
- current goal = relationship-aware control of the already-working `IsoZombie` shell
