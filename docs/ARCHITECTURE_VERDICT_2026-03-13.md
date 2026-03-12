# LWN Architecture Verdict - 2026-03-13

## Scope

This document records the architecture judgment after the full-code re-review and refactor pass focused on:

- embodied `IsoPlayer` viability in Build 42
- canonical `ModData` ownership
- presentation staging
- death / corpse / reanimation overlap
- cleanup / remove ownership
- stale target removal
- rapid spawn stability

## Verdict

The current direction is still viable, but only under a narrower contract than earlier turns implied.

Keep:

- canonical NPC identity and long-lived state in `ModData`
- embodied world actor as a disposable cache
- `IsoPlayer` as the current Build 42 carrier for visible humans

Do not assume:

- Build 42 gives a stable first-party human NPC runtime
- `IsoPlayer` can be treated as canonical identity
- death can be modeled as only `health <= 0`
- cleanup can own corpse/reanimation presentation

## The Contract That Is Now Considered Safe Enough

### 1. Canonical state owns identity and lifecycle

- `record.status.life` is the authority for alive vs dead.
- `record.embodiment.state` remains the high-level world-presence bucket.
- `record.embodiment.stage`, `presentation`, `death`, `cleanup`, and `target` now make the sub-lifecycle explicit.

### 2. Embodiment is a staged pipeline

The code now treats embodiment as:

1. canonical record selected
2. actor spawn attempt
3. presentation pending
4. presentation refresh / settle
5. active embodied actor

This matches the strongest Build 42-safe lesson from official docs and the reference review: actor allocation is not the same as a usable visible actor.

### 3. Death is latched before cleanup

- death-like actors are now latched into canonical death state
- corpse observation is handled separately through `OnDeadBodySpawn` when available
- cleanup runs only after corpse observation or a short timeout

This is the main structural response to corpse flicker and death/cleanup overlap.

### 4. Cleanup ends LWN ownership, not world history

When a dead NPC leaves behind a corpse or reanimated zombie object, LWN now prefers:

- clear LWN markers
- unregister the actor from LWN ownership
- preserve the world object

That keeps cleanup from deleting evidence of death and reduces corpse/reanimation races.

### 5. Long-lived UI targeting is now canonical-id based

UI windows and radial menu no longer trust a cached actor ref as durable identity.
They keep `npcId` and resolve the current embodied actor on refresh.

This is the minimum practical version of the "canonical id over actor ref" lesson from PZNS and Bandits-style cleanup discipline.

## What This Pass Intentionally Did Not Claim

### Full corpse simulation ownership

This pass does not claim LWN owns corpse persistence as a first-class simulation system yet.
The current safer stance is:

- LWN owns canonical death state
- LWN observes corpse spawn
- LWN releases ownership cleanly

That is strong enough to judge whether the overall architecture is worth continuing, without pretending the Build 42 human-death pipeline is fully solved.

### A future-proof guarantee for `IsoPlayer`

`IsoPlayer` remains a gray-area carrier in Build 42.
The project can continue on this path only if it keeps the rest of the codebase insulated from actor-specific assumptions.

## Concrete Lessons Applied From Sources

### Official Build 42 docs

- favor documented lifecycle methods before square-pointer forcing
- favor `WornItems -> ItemVisuals` official bridge before manual rebuild
- treat corpse creation as a separate phase from death
- prefer `OnCreateLivingCharacter` over survivor-only assumptions for `IsoPlayer`

### Reference mods

- from PZNS: stable canonical record + runtime actor pointer as cache only
- from Bandits/BanditsWeekOne: separate death observation from dead-body follow-up
- from Build 41 human mods: explicit post-spawn visual rebuild is necessary

### Explicitly not imported

- Build 41 save/load ghost ownership
- invisibility/no-clip as ordinary lifecycle tools
- preview-actor rules from creator/editor mods

## Final Architectural Recommendation

Keep pushing in the same overall direction if and only if all future work respects this boundary:

`ModData` is the source of truth. `IsoPlayer` is a temporary embodiment adapter. Death, presentation, and cleanup must remain explicit canonical-state transitions instead of ad hoc actor-side side effects.

If tonight's in-game test still shows unrecoverable transparent actors even after the staged-presentation and death/cleanup separation changes in this pass, the next escalation should not be another hotfix on top of raw `IsoPlayer`; it should be a deliberate carrier reevaluation spike.
