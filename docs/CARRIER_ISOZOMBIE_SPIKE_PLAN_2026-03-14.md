# Carrier IsoZombie Spike Plan - 2026-03-14

## Why this spike is worth trying

Current findings:

- `IsoPlayer` can exist in-world and participate in simulation, but alive human presentation is still transparently broken.
- `IsoSurvivor` can be instantiated through at least one constructor path, but the resulting object appears to be runtime-incomplete (`bodyDamage=nil`, `inWorld=false`) and not suitable as a world-ready embodied NPC.

Because of that, the next practical carrier experiment should prioritize **engine-native world stability** over perfect human semantics.

`IsoZombie` is the strongest candidate for that kind of spike.

## Spike goal

Answer only these questions first:

1. Can LivingWorldNPC spawn an `IsoZombie` as a carrier through the adapter without crashing?
2. Does it render reliably as a visible world actor?
3. Can the project attach canonical npcId/state to it and clean it up safely?
4. Is the control/behavior surface good enough to justify deeper experimentation?

This spike is **not** meant to prove final design quality.
It is only meant to test practical viability as a visible embodied carrier.

## What the spike should NOT try to solve yet

Do **not** attempt all of this in the first pass:

- full bandit/human behavior fidelity
- perfect human visuals
- full equipment parity
- deep animation customization
- final interaction UX
- final death/corpse logic rewrite

Those can come later only if proof-of-life succeeds.

## Why IsoZombie is a plausible candidate

### Strengths

- clearly a world-native live actor in Build 42
- engine already expects to update, render, target, and retire it
- likely to avoid the invisible-human presentation failure seen with `IsoPlayer`
- likely to avoid the runtime-core incompleteness seen with current `IsoSurvivor` paths

### Risks

- zombie-native semantics may fight human NPC goals
- appearance may not convincingly match a living human without heavy tricks
- built-in zombie behavior may need strong neutralization or override
- combat/faction/AI logic may need adapter translation rather than direct reuse

## Recommended spike shape

### 1. New carrier implementation

Planned file:

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

Core API:

- `spawn(record, options)`
- `sync(record, handle, options)`
- `retire(record, handle, options)`
- `isUsable(handle)`
- `getActor(handle)`

### 2. Targeted debug spawn

Add a dedicated debug path similar to `IsoSurvivor`:

- `DebugTools.spawnOneNearPlayerIsoZombie(player)`

and expose a clearly labeled debug menu entry:

- `Debug: Spawn NPC Near Player (IsoZombie Spike)`

### 3. Minimal spawn contract

The first spike should aim for only:

- visible actor appears in world
- actor is tagged with canonical npcId
- actor can be found through the carrier handle
- actor can be removed safely in non-combat debug delete

## Technical plan

### Phase A — proof-of-life spawn

Questions to answer:

- what constructor/spawn path for `IsoZombie` is available from Lua in this runtime?
- can it be spawned at the requested square with no crash?
- does it appear immediately and remain in-world?

Required checks after spawn:

- `isExistInTheWorld()`
- `getCurrentSquare()`
- `getBodyDamage()`
- `getStats()`
- `getInventory()` if relevant
- visible actor on screen

### Phase B — neutralization / de-zombification controls

If spawn succeeds, test the minimum controls needed so it behaves like a carrier shell rather than an autonomous zombie:

Possible controls to investigate:

- disabling pathing/aggro where possible
- preventing autonomous chase/attack
- pinning movement or letting only project logic move it
- tagging it so project systems can recognize it as a surrogate NPC carrier

### Phase C — project sync integration

If the actor survives Phase A/B:

- map canonical position/health/basic flags into the zombie carrier
- decide which sync fields make sense and which do not
- avoid overusing the existing `ActorSync.pushRecordToActor(...)` if it assumes player/human semantics

## Expected outcomes and interpretation

### Best case

- `IsoZombie` spawns visibly and stably
- cleanup works
- project can attach canonical npcId and basic control

Interpretation:
- strong proof that a stable visible carrier exists even if human fidelity is not solved yet

### Medium case

- actor spawns and is visible, but behavior/control is awkward

Interpretation:
- still useful as a temporary shell or as a learning platform for adapter design

### Failure case

- constructor/spawn path is unavailable or unstable
- cleanup is unsafe
- control surface is too hostile

Interpretation:
- `IsoZombie` is not the right fallback carrier and the project should lean harder toward logic-first fallback

## Success criteria for the first test session

A first `IsoZombie` spike should be considered successful enough to continue if all of these are true:

- no crash during spawn
- visible actor appears
- actor remains in-world for a short observation window
- debug delete in non-combat succeeds safely
- logs are readable and specific

## Relationship to logic-first fallback

Even if `IsoZombie` works, the project should still keep the long-term option of logic-first fallback.

Reason:

- a stable visible shell is useful
- but it may still not be the final truth of the NPC system
- carrier swap freedom remains valuable

## Recommended next action after this plan

If the team wants one more embodied-carrier experiment before pivoting harder toward logic-first fallback, `IsoZombie` is the right next spike.
