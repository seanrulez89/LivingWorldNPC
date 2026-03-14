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

## Recommended next direct coding focus
1. Re-test debug delete on a live embodied NPC and confirm the `getCurrentSquare()==nil` crash is gone.
2. If cleanup becomes stable, keep the safer delayed-retirement contract even if the actor carrier changes later.
3. Treat the alive-render transparency problem as a separate architecture decision from cleanup safety.

## Git note
- At the start of this audit, `git status --short --branch` reported a clean working tree on `master` tracking `origin/master`.
- After the documentation refresh above, re-run validation and `git status` before the next commit.
