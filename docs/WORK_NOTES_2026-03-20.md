# Work Notes - 2026-03-20

## IsoZombie relationship debug follow-up

- Added nearest-NPC debug controls for:
  - lowering trust
  - forcing canonical `friendly`, `neutral`, or `hostile` policy outcomes through `Social.forceRelationshipCombatPolicy(...)`
- Kept the forcing path inside real record fields (`relationshipToPlayer`, `companion`, `drama`) instead of adding a debug-only policy state.
- `DebugTools` now tries an immediate carrier sync after trust/policy changes so embodied `IsoZombie` shells update in-place during testing.

## IsoZombie shell observability / suppression

- `Carrier_IsoZombie` now writes concise policy metadata into shell `modData`:
  - `LWN_RelationshipPolicySummary`
  - `LWN_CarrierCombatMode`
  - `LWN_FriendlySuppression`
- Friendly / neutral shells now also call `StopAllActionQueue()` when clearing target state.
- `setGodMod(...)` remains the fallback safety layer for `allowPlayerAttack == false`; this pass does not claim complete player-side attack suppression is solved.

## Quick test path

1. Enable debug tools and spawn a nearby `IsoZombie` shell.
2. Use `Debug: Force Nearest Friendly Policy`, `Neutral`, and `Hostile` to confirm shell posture changes immediately.
3. Use `Debug: Boost Nearest NPC Trust` and `Debug: Lower Nearest NPC Trust` to verify trust-driven transitions still flow through the same policy model.
4. Use `Debug: Dump Nearest NPC Summary` and confirm the summary / actor line shows the current policy and suppression metadata.
5. For friendly shells, verify they stay inert and note whether player attackability still leaks through despite `godmod+clearqueue`.

## Validation in this pass

- `./scripts/validate-wsl.sh`
- `luac -p` on edited Lua files

## Late-night hybrid / policy test follow-up

### What changed before the test

- log spam was throttled so repeated `EmbodimentTrace`, `PresentationGuard`, `CleanupTrace`, and `CarrierIsoZombie` lines now sample instead of flooding the console
- hybrid metadata was exposed through debug dump helpers and stamped into shell `modData`
- safe `IsoPlayer`-era appearance shaping was reused conservatively on the `IsoZombie` path:
  - descriptor build / bind
  - baseline human-visual shaping
  - visible clothing / worn-item bridge
  - final model refresh
- appearance shaping now runs even while the `IsoZombie` carrier is still `pending_settle`

### In-game result

- dump helpers stopped crashing and became usable
- visible shell still looked like a normal zombie, not a human survivor
- `hostile` now produced a clear behavioral change: the shell attempted to come after the player
- `friendly` / `neutral` did not visibly attack the player
- however the shell still produced short repeated footstep sounds / movement attempts even when it was supposed to stay pinned in place

### Log-backed findings

- the old dump crash was fixed successfully
- the hybrid appearance experiment now really runs:
  - `exp=isozombie_shared_desc_visual_v1:applied@sync_pending_applied`
  - descriptor source moved to `npc_record_survivor_desc_*`
  - item-visual bridge reported `item_visuals_present`
- despite that, actor visuals still reported zombie presentation data:
  - `presentationRole=reanimated_zombie`
  - zombie body skin such as `M_ZedBody04_level1`
- therefore descriptor / human-visual reuse is now confirmed to be *executing* without producing a human-looking shell

### New error family discovered

- every relationship-state force / trust-adjust sync cycle could trigger the same Java-side exception during appearance refresh:
  - `NullPointerException: Cannot assign field \"isNpc\" because \"this.player\" is null`
- stack trace points to:
  - `IsoGameCharacter.setNPC(...)`
  - called from `23_LWN_ActorFactory.lua -> refreshActorPresentation()`
- this means `setNPC(true)` is unsafe on an `IsoZombie` shell and should be removed or gated away from the hybrid appearance path
- importantly, this exception does **not** stop the appearance experiment from stamping `applied`, but it pollutes every policy/trust sync and risks undefined side effects

### Movement / footstep conflict finding

- hostile summary showed the shell could carry a massive repeated action queue such as repeated `retreat`
- the game also emitted:
  - `IsoGameCharacter.doDeferredMovement > WalkTowardState but path2 != null`
- this matches the player's report of tiny repeating footstep sounds
- interpretation:
  - the shell is repeatedly receiving movement / pathing intent while the policy layer also keeps trying to neutralize or freeze it
  - current `friendly/neutral` suppression is not strong enough to fully stop queued/deferred movement churn

### Updated interpretation

1. `IsoZombie` relationship policy is now partially real.
   - `hostile` is no longer just metadata; it can provoke actual pursuit intent.
2. `friendly/neutral` still need stronger movement neutralization.
   - current `setUseless + setCanWalk(false) + clear queue/target` is not enough to eliminate all movement churn.
3. Hybrid appearance reuse has crossed an important threshold.
   - it is no longer just theoretical; it executes successfully.
   - but `IsoZombie` still renders as a zombie because zombie presentation/body pipeline is overriding human-facing descriptor work.
4. The next blocker is no longer “is the hybrid experiment running?”
   - it is now:
     - remove the unsafe `setNPC(true)` call from zombie refresh
     - stop movement churn for non-hostile shells
     - probe the zombie presentation pipeline itself rather than descriptor plumbing alone

### Recommended next code actions

1. Remove or hard-gate `setNPC(true)` inside `refreshActorPresentation()` for `IsoZombie` carriers.
   - keep `setIsNPC(true)` only if it remains safe
   - do not call the Java path that assumes a backing `player`
2. Split non-hostile suppression into a stronger inert package.
   - explicitly clear path/deferred movement state in addition to target/action queue
   - avoid re-issuing movement intent every sync when policy is `friendly` or `neutral`
3. Inspect who is enqueuing `retreat` during hostile/non-hostile transitions.
   - the repeated action queue suggests another layer is still writing movement intent after carrier policy applies
4. Start a focused presentation-pipeline probe.
   - because `descriptor=true` + `humanVisual=true` + `applied` still ends with `presentationRole=reanimated_zombie` and zombie skin
   - next appearance experiments should target zombie base skin / role override boundaries, not just more descriptor work

## Stage-1 stabilization patch

- `23_LWN_ActorFactory.lua` now treats `refreshActorPresentation()` as carrier-aware for the live `IsoZombie` shell.
- The shared refresh helper still runs for:
  - `refreshEmbodiedPresentation()`
  - `applyLoadout()`
  - `finalizePostCreatePresentation()`
  - `applySafeAppearanceShaping()`
- For `IsoZombie` carriers / zombie actors, it now skips `setNPC(true)` and `setIsNPC(true)` instead of calling the player-backed Java path during trust / relationship sync.
- The rest of the refresh path stays intact so the current hybrid appearance experiment and hostile posture work can continue unchanged for this pass.
- Next in-game verification:
  - force trust / relationship changes on a live `IsoZombie` shell and confirm the Java `this.player is null` exception no longer appears
  - confirm hostile shells still enter pursuit / attack posture
  - leave friendly / neutral movement churn for the later pass

## A-group cleanup + Phase-0 immediate pass (2026-03-21)

### Cleanup removals applied

- removed dead `Legacy.applyPendingToPlayer(player)` stub from `30_LWN_Legacy.lua`
- removed unread persisted `legacy.candidates` plumbing (`10_LWN_PopulationStore.lua` and write site in `30_LWN_Legacy.lua`)
- removed unused debug write `record.companion.canContinueAsLegacy` and related forced-candidate write path in `92_LWN_DebugTools.lua`
- removed now-unused schema defaults:
  - `root.legacy.candidates`
  - `record.companion.canContinueAsLegacy`

### Phase-0 immediate changes applied

- strengthened non-hostile suppression in `35_LWN_Carrier_IsoZombie.lua`:
  - `clearCombatIntent(...)` now also calls `setPath2(nil)` and `setMoving(false)`
  - non-hostile policy branches now also clear `LWN.ActionRuntime` queue via `ActionRuntime.clear(record, actor)`
- expanded shell observability metadata in `35_LWN_Carrier_IsoZombie.lua`:
  - `LWN_ActorKind`
  - `LWN_SessionId`
  - `LWN_ShellMarker`
  - `LWN_MovementSuppression`
  - `LWN_AudioLeakHint`
- expanded debug dump in `92_LWN_DebugTools.lua`:
  - actor line now includes carrier/shell/session/presentation-role/skin/itemVisuals/wornItems/path2/moving/audio hint
  - identity line now includes canonical npc id, carrier kind, shell marker, session id, and embodied meta coordinates/state

### Intended immediate test effect

- reduce repeated footstep/path churn in `friendly`/`neutral`
- make "still zombie-looking" ceiling easier to see in one dump
- make shell replacement/continuity issues easier to spot from logs
