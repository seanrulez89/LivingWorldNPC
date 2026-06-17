# IsoPlayer Hardening Pass - 2026-03-14

## Why this pass exists

This pass was done to answer one question more honestly:

- is the current `IsoPlayer` embodiment path still worth pushing?

To make that decision, the repo needed one more direct coding pass that tightened the current path rather than arguing abstractly about it.

## What was audited

The full repo was rechecked with attention to all project surfaces that currently matter for `IsoPlayer` embodiment:

- actor allocation in `23_LWN_ActorFactory.lua`
- post-create hook handling in `90_LWN_EventAdapter.lua`
- engine-facing state enforcement in `24_LWN_ActorSync.lua`
- repo docs and prior test notes describing the invisible-alive-NPC failure

## Core findings before changes

Before this pass, the codebase already had:

- descriptor creation
- clothing seeding
- item-visual bridging
- model-manager refresh
- alpha/ghost/invisible/scene-cull repair
- dual hook observation for `OnCreateLivingCharacter` and `OnCreateSurvivor`

However, one architectural weakness remained:

- the heavy presentation build still happened during `createActor()` itself, even though the repo's own evidence increasingly pointed to the post-create lifecycle edge as the most suspicious boundary

That meant the project was still vulnerable to:

- same-frame or early-frame presentation invalidation
- duplicated heavy refresh work before the engine's own create hook stabilized the actor
- difficulty separating "spawn succeeded" from "alive presentation actually finalized"

## What changed in code

### 1. Heavy presentation was deferred to the post-create stage

`ActorFactory.createActor()` no longer performs the full final presentation build immediately.

It now:

- allocates the `IsoPlayer`
- binds canonical markers/modData
- registers the actor in world
- applies traits
- seeds visible clothing / loadout items
- marks the actor as `LWN_PostCreateHeavyPending = true`
- records that heavy presentation is intentionally waiting for the post-create phase

This is the biggest structural change in the pass.

### 2. A dedicated post-create finalization path was introduced

New function:

- `Factory.finalizePostCreatePresentation(record, actor, descriptor, source)`

This function centralizes the heavy "make the actor actually presentation-ready" work:

- `refreshEmbodiedPresentation(...)`
- `applyLoadout(...)`
- explicit alive-state animation/model rebuild
- health restore
- final presentation refresh
- stage transitions to `active` / `ready`

This reduces ambiguity about where the current path is supposed to become truly visible.

### 3. An explicit alive-state animation/model rebuild pass was added

New helper:

- `rebuildAliveAnimationState(actor, reason)`

This pass attempts to recover the alive presentation layer more aggressively by using safe, documented or already-observed methods around the model/animation surface:

- release animation player if present
- clear forced animation override
- set animation forecast to immediate
- check/update model textures
- reload outfit
- attempt `changeState(getDefaultState())` when possible
- reset model now and next frame
- refresh through `ModelManager`

The purpose is not cosmetic cleanup. It is to test whether the invisible-NPC failure is really stuck at the alive-state animation/model boundary.

### 4. ActorSync now provides a fallback if the create hook is late or missing

`24_LWN_ActorSync.lua` now checks `LWN_PostCreateHeavyPending`.

If the post-create hook did not finalize the actor in time, `ActorSync` can trigger the same heavy finalization path as a fallback.

This matters because a pure hook-only approach is useful for diagnosis, but brittle if a hook is delayed or skipped in some runtime path.

### 5. EventAdapter now uses the new finalization path directly

`90_LWN_EventAdapter.lua` now prefers:

- `finalizePostCreatePresentation(...)`

instead of only calling the older presentation refresh path.

So the create hook becomes the intended point where the actor crosses from:

- allocated / world-registered

into:

- presentation-finalized / ready-for-judgment

## Validation performed

WSL validation command run:

```bash
./scripts/validate-wsl.sh
```

Validation covered:

- `git diff --check`
- `git diff --stat`
- `git diff --name-only`
- `luac -p` syntax checks for changed Lua files

Result:

- passed

Files validated:

- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/24_LWN_ActorSync.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`

## What this pass gives the project

If a new in-game test still produces transparent alive NPCs after this pass, the evidence against the current `IsoPlayer` route becomes much stronger.

Because after this hardening pass, the current route will already have:

- explicit post-create anchoring
- explicit staged presentation finalization
- explicit clothing/material/model rebuild
- explicit alive-state animation reset attempt
- fallback finalization if hook timing is bad

At that point, a continued invisible result is harder to explain as a simple missing refresh or ordering bug.
It would more strongly support:

- a deeper Build 42 alive-presentation incompatibility for this `IsoPlayer` carrier path
- or an actor-class boundary problem that incremental repair is no longer likely to solve cleanly

## Updated go / no-go interpretation

### Keep pushing `IsoPlayer` if

- alive NPCs finally render after this pass
- or render becomes conditionally stable and logs clearly show the post-create finalization fixed the worst failure mode

### Prepare to abandon `IsoPlayer` if

- alive NPCs are still transparent in the same dominant way
- logs show post-create finalization and alive-state rebuild both ran, but visibility still failed
- the only visible world form remains death/downed/corpse-like output rather than stable alive human presentation

## Next in-game evidence to collect

Watch especially for these traces:

- `createActor.await_post_create`
- `onCreateLivingCharacter.presentation_refreshed`
- `finalizePostCreatePresentation.ready`
- `presentation_heavy_fallback`
- `action=alive_state_rebuild`

If those all appear and the NPC is still invisible, that is a much cleaner decision point than before this pass.
