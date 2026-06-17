# IsoPlayer Exit Plan - 2026-03-14

## Executive summary

`IsoPlayer` should no longer be treated as the long-term embodiment carrier for LivingWorldNPC alive human presentation.

The project should keep its canonical record/state architecture, but replace the current live-world carrier experiment with a different runtime strategy.

## Why the current `IsoPlayer` route should be retired

### In-project evidence

The current repo now has all of the following in place:

- descriptor creation via `SurvivorFactory` / `SurvivorDesc`
- outfit and clothing seeding
- item-visual bridging
- model-manager refresh
- alpha / ghost / invisible / cull repair
- post-create presentation hardening
- explicit alive-state animator/model rebuild attempts

Yet alive NPCs still remain transparent.

Observed signals across the recent passes:

- alive NPC remains visually transparent
- post-create hook evidence is weak or absent for this spawn path (`lastCreateHook=nil`)
- `modelRegistered` continues to look absent/nil
- death/downed/corpse-like presentation can appear, but stable alive human presentation does not

This is now stronger evidence for a carrier mismatch than for a mere missing refresh.

### Official modding docs signals

From the official Javadocs reviewed during this pass:

- `SurvivorFactory` is clearly centered on building `SurvivorDesc` / survivor descriptors, not giving a first-class documented Build 42 human NPC runtime by itself.
- `SurvivorDesc` clearly exposes human-visual, outfit, and metadata shaping functions, which is useful and should be retained.
- `IsoGameCharacter` exposes many model/animation methods (`resetModel`, `resetModelNextFrame`, `reloadOutfit`, `setAnimForecasted`, `releaseAnimationPlayer`, etc.), but the docs do **not** amount to a supported contract that `IsoPlayer.new(...)` behaves as a stable NPC embodiment path for live humans.
- `IsoPlayer` has a very large player-specific surface and assumptions.
- `IsoSurvivor` still exists in docs, but the docs alone do not demonstrate an actively supported modern Build 42 human NPC embodiment pipeline around it.

## What should be kept from the current codebase

These parts are still valuable and should survive an `IsoPlayer` exit.

### Keep: canonical record/state architecture

Keep all of this conceptually intact:

- canonical NPC identity in record/ModData
- actor ref as disposable runtime cache
- explicit stages for spawn/presentation/death/cleanup/targeting
- canonical-id-based UI lookup instead of trusting cached actor refs

This is one of the strongest parts of the current codebase.

### Keep: descriptor / appearance generation

Keep and reuse:

- `SurvivorFactory` descriptor generation
- `SurvivorDesc` naming / gender / outfit / human-visual setup
- item loadout shaping logic
- trait/stat application logic where actor-class-compatible

Even if the live actor carrier changes, the appearance and identity shaping work still matters.

### Keep: cleanup discipline and debug delete contract

Keep:

- canonical cleanup ownership
- explicit cleanup state machine
- combat-time delete guard
- UI/registry detachment before actor retirement

This work remains useful regardless of carrier choice.

### Keep: death/corpse separation

Keep:

- latched death state
- corpse observation as a separate phase
- world-object preservation discipline for death artifacts

This is still the right direction independently of `IsoPlayer`.

## What should be discarded or heavily downgraded

### Discard as primary strategy: `IsoPlayer`-specific alive presentation repair loops

These were worth trying, but should not be the new foundation:

- repeated alpha repair as if that solves embodiment
- player-focused post-create hook dependence for live NPC visibility
- `IsoPlayer`-specific animator/model reset escalation as the core plan
- cleanup complexity whose only purpose is compensating for a fragile `IsoPlayer` carrier

These can remain as legacy notes, but should not drive the next architecture.

### Discard as core assumption: "spawn success == viable visible human NPC"

That assumption is now disproven for this route.

## What the reference mods actually suggest

### Shared lesson from reference mods

Several reference projects still rely on the same broad pattern:

- build a `SurvivorDesc`
- create an `IsoPlayer`
- mark it NPC
- run a custom AI/framework around it

Examples reviewed:

- Superb Survivors / Superb Survivors Continued
- PZNS Framework
- Braven's NPC Framework

This is useful evidence for one thing only:

- `SurvivorFactory` / `SurvivorDesc` remain useful descriptor sources

It is **not** strong evidence that the current Build 42 visual embodiment problem in this repo is fixable just by continuing to pile more repairs on the same carrier path.

In fact, these references reinforce a different lesson:

- most successful NPC mods isolate game logic and persistence from the embodied object as much as possible

That is exactly the part LivingWorldNPC should keep.

## Recommended replacement directions

### Option A — Logic-first / presentation-light interim mode (lowest risk)

Use no fully embodied live human actor for ordinary NPC simulation.

Instead:

- keep canonical NPC records active
- simulate movement/intent/interaction logically
- represent world presence with lightweight markers, dialogue ranges, debug overlays, or controlled proxy objects
- only instantiate heavier world objects for narrow situations where absolutely needed

Pros:

- least exposure to unstable live human embodiment
- fastest path to a stable system
- preserves most current architecture

Cons:

- not the final visual fantasy
- weaker immersive embodiment

This is the safest immediate fallback.

### Option B — `IsoZombie`-based carrier experiment for world embodiment (highest practical chance of stable visible world actor)

If the next goal is a visible in-world actor that the engine is already comfortable rendering and updating, `IsoZombie` is the strongest candidate to spike.

Why:

- official docs show an actively supported Build 42 runtime surface for `IsoZombie`
- it is a first-class visible world actor with robust scene/model handling
- many systems (targeting, updates, corpse transition, deletion discipline) are already built around it

But this option is only realistic if the design accepts that the NPC is not literally a normal live human actor underneath.

Use cases where it may still work:

- disguised/stand-in embodiment experiments
- hostile bandit-like entities where custom behavior matters more than true human internals
- staged proof-of-concept to validate world simulation before revisiting true human visuals

Risks:

- human visual fidelity may still be limited or awkward
- semantics will fight the zombie-native behavior model

Recommendation:

- worth a spike/prototype
- not guaranteed to be the final architecture

### Option C — `IsoSurvivor` re-evaluation spike (narrow, research-first)

Because `IsoSurvivor` still appears in the official docs, it is worth a contained experiment.

However, this should be treated as a **research spike**, not a commitment.

Test only:

- can it be instantiated in Build 42 mod runtime from Lua in a supported-enough way?
- does it produce stable visible alive human presentation?
- does it integrate with cleanup/death/targeting better than `IsoPlayer`?

Why only a spike:

- docs presence is not the same as proven practical support
- the modern ecosystem appears to lean more on `IsoPlayer`-based workarounds and custom frameworks

Recommendation:

- do a tiny proof-of-life experiment
- abandon quickly if instantiation/support is awkward

### Option D — hybrid architecture: logical NPC + temporary embodied shell on demand (best long-term shape)

This is the option I would recommend as the strategic direction.

Core idea:

- NPCs are canonical logical entities first
- world embodiment is temporary and situation-specific
- the embodiment shell can change over time without rewriting identity, memory, scheduling, UI, quests, or cleanup ownership

That lets you:

- spike `IsoSurvivor`
- spike `IsoZombie`
- even spike future Build 42/43-supported carriers

without burning the whole project down each time.

## My recommendation order

### 1. Keep the current canonical architecture
Do not throw away the record/state/cleanup/UI work.

### 2. Retire `IsoPlayer` as the default live human embodiment path
Treat it as a failed experiment for this repo's current goals.

### 3. Run two small spikes instead of one giant rewrite

Recommended spike order:

1. `IsoSurvivor` proof-of-life spike
2. if weak/unavailable, `IsoZombie` embodiment spike

Each spike should answer only:

- visible alive world presence?
- stable spawn/update/delete?
- acceptable interaction semantics?

### 4. If neither spike is convincing, ship a logic-first presentation-light interim architecture
That still preserves the project and avoids getting trapped in another low-level carrier fight.

## Practical migration advice for this repo

### Reuse directly

- store / canonical record structures
- embodiment state machine concepts
- UI target resolution by npcId
- cleanup state + combat delete guard
- death lifecycle separation
- descriptor / naming / outfit generation helpers
- loadout / stat / trait shaping code where not actor-specific

### Rewrite or isolate

- `IsoPlayer`-specific presentation repair code
- create-hook assumptions tied to `IsoPlayer`
- model-manager heuristics whose only purpose is reviving invisible players
- actor cleanup branches designed around live `IsoPlayer` quirks

### New abstraction to add next

Introduce an explicit `carrier adapter` boundary, for example:

- `carrierKind = "none" | "isoplayer" | "isosurvivor" | "isozombie"`
- `spawnCarrier(record)`
- `applyPresentation(record, actor)`
- `retireCarrier(record, actor)`
- `supportsHumanVisual(carrierKind)`

That turns the next architecture step from a rewrite into a controlled substitution.

## Bottom line

The project is not a failure.
The `IsoPlayer` carrier experiment likely is.

Keep the architecture.
Retire the carrier.
Prototype the next one behind a proper adapter boundary.
