# LivingWorldNPC Work Notes

Date: 2026-03-14

## Scope of this file
This file is for work performed on 2026-03-14 only.

## 2026-03-14 repo audit summary
- Performed a direct full-repo sweep without delegating to an external coding agent.
- Reviewed repository layout, tracked runtime Lua modules, top-level docs, workflow docs, scripts, and the local-only `reference_mods/` footprint.
- Confirmed the repo is still organized around the expected Build 42 mod structure:
  - `42/` runtime mod files
  - `docs/` research, verdicts, test logs, and work notes
  - `scripts/` local validation/helpers
  - `reference_mods/` ignored local research snapshots
- Confirmed the core runtime architecture remains split as intended:
  - canonical data/state in `PopulationStore` + schema-backed records
  - embodiment lifecycle centered on `ActorFactory`, `ActorSync`, and `EmbodimentManager`
  - post-create recovery/comparison logic in `EventAdapter`
  - UI targeting resolved via `npcId` rather than durable actor refs

## Current technical read after code/doc review
- `ActorFactory.createActor()` still allocates embodied NPCs through `IsoPlayer.new(...)` and marks `OnCreateLivingCharacter` as the expected post-create hook.
- `EventAdapter` still compares both `OnCreateLivingCharacter` and `OnCreateSurvivor`, which is useful for lifecycle evidence but also reinforces that the create-hook path is still part of the active investigation surface.
- The repo's current docs and logs still support the same top blocker:
  - alive embodied NPCs remain invisible despite apparently healthy runtime/debug state
- After reviewing the current docs and the code that implements the spawn/presentation path, the strongest unverified repo-level hypothesis remains:
  - alive presentation is failing at the `IsoPlayer` carrier / actor-class boundary rather than at simple visibility flags

## Documentation updates made today
- Updated `README.md` so the repo front page now exposes:
  - the current highest-priority blocker
  - the strongest current unverified hypothesis
  - the recommended next manual experiment order
  - `docs/TEST_LOG_HISTORY.md` as recommended reading
- Updated `docs/README.md` to surface the current blocker/next-spike guidance and include this new dated work-notes file.
- Updated `AGENTS.md` wording so the repo root guidance is tooling/agent-neutral instead of Codex-specific.
- Updated `docs/GIT_WORKFLOW_2026-03-11.md` wording so the workflow rule reads as a general project rule rather than a Codex-only one.

## 2026-03-14 IsoPlayer hardening pass
- Performed a direct code pass focused on whether the current `IsoPlayer` route deserves one more serious attempt before abandonment.
- Changes made:
  - deferred the heavy presentation build from `createActor()` to the post-create hook path
  - added `finalizePostCreatePresentation(...)` as the single heavy finalization stage
  - added an explicit alive-state animation/model rebuild pass using outfit reload, animation-player release, state reset attempt, and model-manager refresh
  - added an `ActorSync` fallback when post-create heavy finalization is still pending
- Validation performed:
  - `./scripts/validate-wsl.sh`
  - `luac -p` passed for all changed Lua files
- New document:
  - `docs/ISO_PLAYER_HARDENING_2026-03-14.md`

## 2026-03-14 cleanup NPE hardening pass
- Investigated the post-delete crash observed after debug-removing a live embodied NPC.
- Crash signature from `console.txt`:
  - `java.lang.NullPointerException`
  - `BodyDamage.UpdateBoredom(...)`
  - because `IsoGameCharacter.getCurrentSquare()` was `null`
- Conclusion from the log:
  - physical cleanup was still happening too early for a live `IsoPlayer`; delayed engine reaction/animation work could still touch the actor after removal.
- Changes made:
  - added a longer quarantine gate before deferred physical cleanup can finalize for live `IsoPlayer` actors
  - cached the actor's last known square/position at quarantine time
  - after world removal, attempted to restore square references on the detached actor if cleanup had nulled them out
- Validation performed:
  - `./scripts/validate-wsl.sh`
- New document:
  - `docs/CLEANUP_NPE_HARDENING_2026-03-14.md`

## 2026-03-14 debug delete combat guard pass
- Simplified the operator contract for debug deletion after combat-time delete continued crashing even with deferred cleanup hardening.
- New rule implemented:
  - if an embodied NPC is in combat / under attack, debug delete is refused
  - if the NPC is not in combat, debug delete proceeds immediately without deferred quarantine
- Combat detection currently checks:
  - actor has a target
  - actor is attacking
  - nearby zombies are targeting the actor or attacking in immediate proximity
- Code changes:
  - added `ActorFactory.isActorInCombatOrUnderAttack(actor)`
  - `debug_delete` now bypasses deferred cleanup in `ActorFactory.cleanupActor()`
  - `DebugTools.deleteNpcById()` now blocks combat-time delete and emits a user-facing reason
- New document:
  - `docs/DEBUG_DELETE_COMBAT_GUARD_2026-03-14.md`

## 2026-03-14 log quality tuning pass
- Applied a small log-only cleanup pass after delete behavior stabilized.
- Changes made:
  - throttled repeated `death.awaiting_corpse` cleanup traces
  - suppressed `leftover.snapshot` when the only leftover is the same detached actor already out of world
- Intent:
  - reduce noise
  - preserve the more meaningful cleanup traces
- New document:
  - `docs/LOG_QUALITY_TUNING_2026-03-14.md`

## 2026-03-14 IsoPlayer exit planning pass
- Wrote a migration-oriented architecture note for the post-`IsoPlayer` phase.
- Summary judgment:
  - keep the canonical record/state/cleanup architecture
  - retire `IsoPlayer` as the default live human embodiment carrier
  - evaluate `IsoSurvivor` as a narrow proof-of-life spike
  - evaluate `IsoZombie` as a more engine-native visible-world carrier spike if human-carrier support remains weak
  - prefer a long-term carrier-adapter boundary so embodiment can change without rewriting simulation state
- New document:
  - `docs/ISOPLAYER_EXIT_PLAN_2026-03-14.md`

## 2026-03-14 carrier adapter draft pass
- Added the first adapter boundary intended to separate canonical NPC state from embodied world-carrier choice.
- New runtime code:
  - `31_LWN_CarrierAdapter.lua`
  - `32_LWN_Carrier_None.lua`
  - `33_LWN_Carrier_IsoPlayer.lua`
- `EmbodimentManager` now also tracks runtime carrier handles and bridges legacy actor registration into that handle system.
- Important scope note:
  - this is a structural bridge, not a full migration yet
  - current embodiment logic still largely runs through legacy paths, but the repo now has a concrete place to move spawn/sync/retire behavior into
- New document:
  - `docs/CARRIER_ADAPTER_DRAFT_2026-03-14.md`

## 2026-03-14 carrier adapter migration pass
- Performed the first real routing pass from direct legacy actor calls into the carrier adapter.
- Main changes:
  - `tryEmbody()` now prefers `CarrierAdapter.spawn()`
  - initial embodiment sync now prefers `CarrierAdapter.sync()`
  - canonical cleanup now prefers `CarrierAdapter.retire()`
  - deferred cleanup finalization can retire through the adapter
  - event-hook sync path now prefers adapter sync
  - debug wipe fallback now prefers adapter retire
- New document:
  - `docs/CARRIER_ADAPTER_MIGRATION_PASS_2026-03-14.md`
- Important scope note:
  - this is still not the full migration
  - legacy `ActorFactory` / `ActorSync` still sit behind the current `isoplayer` carrier implementation

## 2026-03-14 IsoSurvivor carrier spike pass
- Added a proof-of-life `IsoSurvivor` carrier implementation behind the adapter.
- New runtime code:
  - `34_LWN_Carrier_IsoSurvivor.lua`
- Added targeted carrier selection support through:
  - `record.embodiment.preferredCarrierKind`
- Added a dedicated debug spawn entry:
  - `DebugTools.spawnOneNearPlayerIsoSurvivor(player)`
- Constructor strategy is intentionally multi-path because practical Lua examples were scarce:
  - try `SurvivorFactory.InstansiateInCell(...)`
  - then several `IsoSurvivor.new(...)` signatures
- New document:
  - `docs/CARRIER_ISOSURVIVOR_SPIKE_2026-03-14.md`

## 2026-03-14 IsoSurvivor reject cleanup follow-up
- Applied a tiny follow-up patch after reviewing the remaining `IsoSurvivor` reject-path error.
- Change made:
  - removed `setSceneCulled(false)` from `IsoSurvivor` mark/management setup because it triggered `IsoGameCharacter.getVisual()` / `subclasses must implement this` exceptions on the rejected survivor object.
- Expected result:
  - same runtime rejection behavior
  - fewer remaining errors during the reject path

## 2026-03-14 IsoZombie spike planning
- Wrote the next carrier experiment plan targeting `IsoZombie` as a more engine-native visible-world carrier candidate.
- New document:
  - `docs/CARRIER_ISOZOMBIE_SPIKE_PLAN_2026-03-14.md`

## 2026-03-14 carrier experiment result consolidation
- Confirmed current standing after live testing:
  - `IsoPlayer` still spawns and deletes stably enough to test, but remains transparent while alive
  - `IsoSurvivor` no longer crashes the game after reject-path hardening, but still fails as a runtime-ready carrier and is blocked before embodiment proceeds
- Wrote a consolidated result summary and verdict document:
  - `docs/CARRIER_EXPERIMENT_RESULTS_2026-03-14.md`
- Current practical direction:
  - keep the adapter/canonical architecture
  - stop treating `IsoSurvivor` as the likely next carrier
  - treat `IsoZombie` as the next embodied-carrier spike candidate

## 2026-03-14 IsoZombie spike implementation pass
- Started the first actual `IsoZombie` proof-of-life carrier implementation on branch `spike/isozombie`.
- New runtime code:
  - `35_LWN_Carrier_IsoZombie.lua`
- New debug entry:
  - `DebugTools.spawnOneNearPlayerIsoZombie(player)`
- New menu entry:
  - `Debug: Spawn NPC Near Player (IsoZombie Spike)`
- Important implementation choice:
  - used `addZombiesInOutfit(...)` rather than guessing a low-level `IsoZombie.new(...)` path, because the goal is a world-ready visible actor proof-of-life
- New document:
  - `docs/CARRIER_ISOZOMBIE_SPIKE_IMPL_2026-03-14.md`

## 2026-03-14 IsoZombie resolve hardening pass
- After the first visible `IsoZombie` proof-of-life result, the next blocker turned out to be actor continuity rather than spawn viability.
- Main changes:
  - `resolveEmbodiedActor()` now uses a carrier-aware usability check
  - `IsoZombie` gets a longer `actor_lost` grace window than human-oriented carriers
  - on-tick logic can recover from the carrier handle if normal actor resolution briefly fails
  - `Embody.getUsableActorByNpcId()` now respects carrier usability before older managed-actor assumptions
- New document:
  - `docs/CARRIER_ISOZOMBIE_RESOLVE_HARDENING_2026-03-14.md`

## 2026-03-14 IsoZombie sync/UI branching pass
- After `IsoZombie` finally stayed visible in-world, the main blockers shifted to sync and interaction layers.
- Main fixes:
  - `ActorSync.enforceEmbodiedFlags()` now branches for `carrierKind == isozombie` and skips human/player-specific setters like `setNPC()` that were causing repeated NPEs
  - context-menu targeting now distinguishes ordinary zombies from `LWN`-managed zombie carriers and can allow the managed carrier through the targetable-NPC path
- New document:
  - `docs/CARRIER_ISOZOMBIE_SYNC_UI_BRANCHING_2026-03-14.md`

## 2026-03-14 IsoZombie managed-target finalization
- After `IsoZombie` became visible, persistent, and error-light, the remaining blocker for interaction was the final managed-actor check.
- Main fixes:
  - `ActorFactory.isManagedActor()` is now carrier-aware for `isozombie`
  - managed zombie carriers are no longer required to satisfy human body/inventory assumptions just to be considered valid managed actors
  - context-target rejection reason for managed zombies is now more specific when they still fail finalization
- New document:
  - `docs/CARRIER_ISOZOMBIE_MANAGED_TARGET_FINALIZATION_2026-03-14.md`

## 2026-03-14 IsoZombie success consolidation
- Confirmed the first genuinely successful `IsoZombie` shell result:
  - visible
  - persistent
  - right-click menu available
  - delete safe
  - no major runtime errors in the latest stable test
- New document:
  - `docs/CARRIER_ISOZOMBIE_SUCCESS_RESULT_2026-03-14.md`

## 2026-03-14 trust-gated hostility groundwork
- Added the first relationship-driven combat policy helper instead of hardcoding permanent friendliness or permanent hostility.
- New helper:
  - `Social.relationshipCombatPolicy(record)`
- `IsoZombie` now stores policy state into modData and branches between inert vs non-neutralized shell behavior using relationship policy.
- Important limitation:
  - this is policy groundwork only
  - it does not yet fully control every engine-level player attack or hostile-targeting decision
- New document:
  - `docs/CARRIER_ISOZOMBIE_TRUST_HOSTILITY_2026-03-14.md`

## 2026-03-14 IsoZombie hostility exploration pass
- Extended the trust-gated hostility groundwork into the carrier shell itself.
- Main change:
  - `IsoZombie` now applies relationship policy directly to combat posture rather than only storing policy into modData
- Friendly/neutral shell posture now attempts to suppress zombie-initiated aggression conservatively with:
  - `setUseless(true)`
  - `setTargetSeenTime(0)`
  - `setCanWalk(false)`
  - `setNoTeeth(true)`
  - `setTarget(nil)`
  - `setAttackedBy(nil)`
- Hostile shell posture now attempts a cautious first activation path with:
  - `setUseless(false)`
  - `setCanWalk(true)`
  - `setNoTeeth(false)`
  - optional target/face/path-to-player calls when a player reference exists
- Important limitation:
  - this still does not guarantee final engine-level suppression of player direct attacks against friendly shells
  - that requires a narrower control point later
- New document:
  - `docs/CARRIER_ISOZOMBIE_HOSTILITY_EXPLORATION_2026-03-14.md`

## Recommended next direct coding focus
1. Re-test both cases explicitly:
   - non-combat delete should be immediate
   - combat delete should refuse with a message and no crash
2. If combat guard proves reliable, keep this simpler debug-delete contract even if actor internals change later.
3. Treat the alive-render transparency problem as a separate architecture decision from debug-delete safety.

## Git note
- At the start of this audit, `git status --short --branch` reported a clean working tree on `master` tracking `origin/master`.
- After the documentation refresh above, re-run validation and `git status` before the next commit.
