# LivingWorldNPC Cleanup Triage For `spike/isozombie`

Date: 2026-03-21
Scope: docs-only review of current cleanup candidates. Nothing was deleted in this pass.
Goal: identify stale or risky code that could be removed later to reduce accidental branch confusion, especially around old `IsoPlayer` assumptions, spike scaffolding, misleading stubs, and zombie-path hazards.

Method:

- reviewed active embodiment, carrier, event, UI, debug, and legacy modules
- preferred path/function-level references over broad claims
- conservative bias: suspicious does not automatically mean removable

Important framing:

- this branch still depends on some ugly-looking adapter and compatibility code
- some legacy code is genuinely dead
- some legacy-looking code is still carrying the current `IsoZombie` path safely across cleanup and UI boundaries

## A) High-confidence safe-to-remove soon

These are the cleanest candidates because they appear unconsumed or misleading right now.

### 1) `Legacy.applyPendingToPlayer(player)`

Path:

- `42/media/lua/client/30_LWN_Legacy.lua`

Why it is a cleanup candidate:

- repository search shows no callers
- the body only clears `root.legacy.pending`
- it does not currently drive any gameplay, spawn, transition, or UI behavior

Why removing it would help:

- it advertises a "pending legacy promotion" flow that does not exist in the current branch
- it makes the legacy feature look more complete than it actually is

Recommended note before deletion:

- if the project still wants inheritance/legacy transfer later, redesign it fresh instead of keeping this stub

### 2) Persisted `legacy.candidates` plumbing

Paths:

- `42/media/lua/client/10_LWN_PopulationStore.lua:Store.setLegacyCandidates(...)`
- write sites in `42/media/lua/client/30_LWN_Legacy.lua`
- write site in `42/media/lua/client/92_LWN_DebugTools.lua:forceLegacyCandidate(...)`

Why it is a cleanup candidate:

- repo search found writers but no readers of `root.legacy.candidates`
- the current modal flow in `Legacy.showDeathModal(...)` uses its own local `candidates` table and does not read the persisted copy back

Why removing it would help:

- it trims dead persistence state from ModData
- it reduces the false impression that an in-progress legacy selection UI is already wired

Recommended deletion shape later:

- remove the persistence helper and the writes together, not one at a time

### 3) `record.companion.canContinueAsLegacy` debug write

Path:

- `42/media/lua/client/92_LWN_DebugTools.lua:590-605`

Why it is a cleanup candidate:

- repo search found a write, but no read path
- current legacy candidate collection only checks:
  - alive state
  - `record.companion.recruited`
  - `record.relationshipToPlayer.trust >= LWN.Config.Legacy.MinTrust`

Why removing it would help:

- it is a misleading flag because it suggests gating logic that does not exist
- it creates future risk that someone assumes the field already matters

## B) Likely removable, but confirm first

These look like good deletion targets once the branch decides it is done with comparison spikes or legacy experiments. They still have real references today.

### 1) Entire `IsoPlayer` carrier spike path

Paths:

- `42/media/lua/client/33_LWN_Carrier_IsoPlayer.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua:spawnOneNearPlayer(...)`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua` debug menu entry for `IsoPlayer`

Why it is probably removable:

- March 20 synthesis strongly demotes `IsoPlayer` as the main carrier direction
- the current branch README already says the active carrier direction is `IsoZombie`
- keeping this route around makes it easier to accidentally interpret old `IsoPlayer` behavior as current architecture

Why confirm first:

- it is still the easiest baseline comparison path
- some cleanup and create-hook code in `ActorFactory` and `EventAdapter` still exists because this carrier can still be spawned in debug

### 2) Entire `IsoSurvivor` spike path

Paths:

- `42/media/lua/client/34_LWN_Carrier_IsoSurvivor.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua:spawnOneNearPlayerIsoSurvivor(...)`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua` debug menu entry for `IsoSurvivor Spike`
- `42/media/lua/client/90_LWN_EventAdapter.lua:onCreateSurvivor(...)`

Why it is probably removable:

- it is explicitly spike code
- constructor probing across multiple signatures is useful as a one-time exploration record, but risky as long-lived production surface
- it reinforces the idea that `IsoSurvivor` is still an active carrier candidate when the branch direction has moved on

Why confirm first:

- if the team still wants one final comparison run, deleting it now would remove that option

### 3) Legacy death-modal feature chain

Paths:

- `42/media/lua/client/30_LWN_Legacy.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua:onPlayerDeath(...)`
- `42/media/lua/client/92_LWN_DebugTools.lua:forceLegacyCandidate(...)`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua` debug entry `Force Legacy Candidate`

Why it is probably removable:

- the current file set reads like an abandoned feature stub, not a living branch direction
- `showDeathModal(...)` can still set `legacy.pending`, but no active gameplay flow promotes that pending snapshot anywhere
- the debug affordance and persistence helpers make the feature look more real than it is

Why confirm first:

- if "legacy succession" is still a planned pillar, it should be redesigned deliberately instead of deleted casually

### 4) Adapter-era `isoplayer` default fallbacks

Paths:

- `42/media/lua/client/25_LWN_EmbodimentManager.lua:668-678`
- `42/media/lua/client/25_LWN_EmbodimentManager.lua:895-904`
- `42/media/lua/client/25_LWN_EmbodimentManager.lua:1267-1273`
- `42/media/lua/client/90_LWN_EventAdapter.lua:1161-1171`
- `42/media/lua/client/92_LWN_DebugTools.lua:410-411`

Why it is probably removable or should at least be tightened:

- several fallback handles or defaults still collapse to `"isoplayer"` when carrier information is missing
- on an `IsoZombie`-first branch, that is a risky default because it can silently misdescribe shell kind during sync/cleanup/debug
- even when harmless, it keeps old mental models alive

Why confirm first:

- some of these are defensive fallbacks for adapter failure or ephemeral event-handle creation
- deleting them without replacing them with safer `"none"`/`"unknown"` behavior could make diagnosis worse

Suggested future cleanup:

- replace `"isoplayer"` fallback defaults with explicit `"unknown"` or `record.embodiment.carrierKind`-only resolution, then remove any dead branches revealed by that change

### 5) Debug menu clutter that keeps obsolete routes alive

Paths:

- `42/media/lua/client/26_LWN_UI_ContextMenu.lua:342-358`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua:427-430`
- `42/media/lua/client/92_LWN_DebugTools.lua:435-444`
- `42/media/lua/client/92_LWN_DebugTools.lua:723-745`

Why it is probably removable:

- the current debug surface still advertises:
  - `IsoPlayer`
  - `IsoSurvivor Spike`
  - `Force Legacy Candidate`
- that makes the branch look strategically undecided even though the docs and current code direction now center on `IsoZombie`

Why confirm first:

- these shortcuts are still convenient when reproducing old behavior for comparison
- if kept temporarily, they should at least be relabeled as deprecated comparison tools

## C) Do not remove yet, despite looking suspicious

These pieces look legacy-heavy or experimental, but deleting them now would likely damage the active `IsoZombie` work.

### 1) `CarrierAdapter` indirection

Path:

- `42/media/lua/client/31_LWN_CarrierAdapter.lua`

Why it looks removable:

- it adds abstraction overhead in a single-player spike branch

Why it should stay for now:

- it is the current routing layer that lets `EmbodimentManager` stay carrier-agnostic while `IsoZombie` remains the active path
- removing it now would mix current branch cleanup with architecture collapse

### 2) Handle registration and recovery paths in `EmbodimentManager`

Paths:

- `42/media/lua/client/25_LWN_EmbodimentManager.lua:registerCarrierHandle(...)`
- `42/media/lua/client/25_LWN_EmbodimentManager.lua:getCarrierHandle(...)`
- `42/media/lua/client/25_LWN_EmbodimentManager.lua:unregisterCarrierHandle(...)`
- `42/media/lua/client/90_LWN_EventAdapter.lua:onTick(...)` handle recovery path

Why they look suspicious:

- they feel like extra bookkeeping on top of `_actors`

Why they should stay for now:

- the current `IsoZombie` path depends on carrier handles for sync/retire and recovery from missing registry actors
- this is one of the branch's defenses against shell loss and continuity faults

### 3) Zombie-specific targetability rules in context UI

Paths:

- `42/media/lua/client/26_LWN_UI_ContextMenu.lua:isManagedZombieCarrier(...)`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua:isTargetableNpcActor(...)`

Why they look suspicious:

- they special-case zombies inside a "Living NPC" UI path

Why they should stay for now:

- they are exactly what makes managed zombie carriers reachable as NPCs instead of being filtered out as ordinary undead
- deleting them would regress the active branch's interaction story

### 4) Hybrid debug metadata and appearance probes

Paths:

- `42/media/lua/client/23_LWN_ActorFactory.lua:stampHybridDebugMetadata(...)`
- `42/media/lua/client/23_LWN_ActorFactory.lua:applySafeAppearanceShaping(...)`
- `42/media/lua/client/92_LWN_DebugTools.lua:dumpNearestNpcSummary(...)`

Why they look suspicious:

- some names still say `hybrid`
- they read like temporary experiment instrumentation

Why they should stay for now:

- the branch still does not fully understand where zombie presentation is overriding human-facing inputs
- these probes are the best current observability surface for that question

### 5) Old `IsoPlayer` cleanup quarantine code in `ActorFactory`

Paths:

- `42/media/lua/client/23_LWN_ActorFactory.lua:shouldDeferPhysicalCleanup(...)`
- `42/media/lua/client/23_LWN_ActorFactory.lua:stageDeferredCleanupActor(...)`
- `42/media/lua/client/23_LWN_ActorFactory.lua:safeCleanupActor(...)`

Why it looks removable:

- the comments and contracts are clearly `IsoPlayer`-era
- the current branch focus is `IsoZombie`

Why it should stay for now:

- as long as the debug surface can still spawn `IsoPlayer`, this code remains the branch's protection against known deletion/combat crashes
- removing it before deleting the human-carrier comparison path would make debugging riskier, not cleaner

## Special caution: risky assumptions that should be deleted or rewritten before broadening the branch

These are not "safe to remove now," but they deserve special attention because they can quietly mislead the `IsoZombie` branch.

### 1) `"isoplayer"` as the fallback carrier identity

Why this is dangerous:

- it is a human-first assumption living inside a zombie-first branch
- when a handle is missing or synthetic, the code can still describe the path as `isoplayer` even when the real branch intent is `isozombie`

Best future cleanup:

- make unknown carrier state explicit
- stop defaulting to a human carrier name when information is missing

### 2) Debug routes that imply strategic parity between carriers

Why this is dangerous:

- the menu still presents `IsoPlayer`, `IsoSurvivor`, and `IsoZombie` as sibling debug options
- that UI signal clashes with the actual documentation verdict and invites accidental regression work

Best future cleanup:

- either remove old routes or label them as retired comparison spikes

### 3) Legacy naming that makes abandoned features look half-supported

Why this is dangerous:

- `legacy.pending`, `legacy.candidates`, `canContinueAsLegacy`, and `showDeathModal(...)` together imply a broader system than the branch actually has

Best future cleanup:

- either cut the feature cleanly or replace it with a clearly named future-design stub outside the active runtime path

## Recommended cleanup order after this docs pass

1. Remove truly dead legacy fields/helpers first:
   - `Legacy.applyPendingToPlayer(...)`
   - `legacy.candidates` persistence plumbing
   - `canContinueAsLegacy` write
2. Decide whether legacy succession is still in scope at all.
3. If not, remove the legacy modal/debug chain together.
4. Decide whether `IsoPlayer` and `IsoSurvivor` comparison spikes are finished.
5. If yes, remove their carriers plus related debug/menu entries in the same snapshot.
6. Only after that, simplify adapter-era fallback defaults that still pretend missing carrier info means `isoplayer`.

## Bottom line

The branch's most dangerous clutter is not just "old code." It is old code that keeps teaching the wrong architecture:

- that `IsoPlayer` is still the likely destination,
- that legacy succession is already partly real,
- or that missing carrier identity should fall back to a human path.

The safest immediate cleanup targets are the genuinely dead legacy helpers and fields. The larger removals should happen as deliberate snapshot commits once the team confirms it no longer needs human-carrier comparison spikes.
