# AGENTS.md

## Project identity
- This repository is a **Project Zomboid Build 42 single-player mod**.
- The mod root is the repository root used directly by local tooling and any coding agent.
- The game loads the mod from this folder directly during local testing.

## Hard constraints
- Follow **official Project Zomboid Build 42 modding APIs** when possible.
- Do not introduce multiplayer code paths unless explicitly requested.
- Keep the Build 42 versioned structure intact: `42/` for Build 42 runtime files and `common/` for shared assets.
- Do not move or rename `42/mod.info` without asking.
- Prefer small, reviewable edits.

## Runtime assumptions
- Offscreen NPCs are simulated as data.
- Onscreen NPCs are embodied only when needed.
- Canonical NPC state lives in ModData.
- Embodied actor state is a cache, not the source of truth.
- Current companions use LWN's own managed `IsoZombie` carrier. External NPC
  runtimes are reference material only, not required execution layers.
- Managed `IsoZombie` locomotion depends on LWN-owned AnimSet nodes under
  `42/media/AnimSets/zombie/pathfind` and `42/media/AnimSets/zombie/walktoward`.
  Do not reintroduce external walktype names such as `Walk`, `Run`, or
  `SneakWalk` unless matching LWN-owned AnimSets are provided.
- User commands and autonomous choices should flow through LWN intents before a
  carrier executes them.
- NPC visual defaults must not create real inventory items. Use visual
  projection for baseline presentation, and reserve actual inventory mutation
  for real player/world item transfer or explicit debug-only grants.

## Domain ownership
- Use `docs/DOMAIN_WORKSTREAMS_AND_CONTRACTS_2026-06-16.md` as the current
  workstream and shared-contract rulebook.
- Main integration authority stays in this thread/agent unless the user
  explicitly delegates a narrow subtask.
- Sub-agent style work should be scoped by domain owner, allowed files, public
  APIs being changed, and validation requirements.
- Schema, carrier, combat, action runtime, event adapter, and debug tools are
  shared-contract surfaces; avoid broad edits across several of them in one
  unplanned change.

## When editing code
- Preserve file-by-file module boundaries.
- Avoid speculative engine hooks. If an event or API is uncertain, add a TODO note and keep the hook isolated.
- When a Project Zomboid Java API or animation contract is uncertain, verify it
  against the local game install with `javap` or local media files before
  coding. Record important findings in `docs/`.
- Keep debug tooling available in development builds.
- After touching Lua runtime code, run the local validation scripts if available.
- Treat each meaningful coding turn as a snapshot boundary: after code changes, run validation, review `git status`, and prefer a small descriptive commit before moving to the next hypothesis.

## Preferred workflow
- Use the Local checkout for game-facing changes.
- Use Worktrees for larger refactors or parallel experiments.
- Before proposing a large rewrite, summarize the affected modules.

## Commands
- Bootstrap local Lua syntax checker on macOS: `bash scripts/bootstrap-lua-mac.sh`
- Validate current macOS working tree: `bash scripts/validate-mac.sh`
- Open latest Project Zomboid console log: `bash scripts/read-console-mac.sh`
- Read latest LWN-only test evidence: `bash scripts/read-lwn-log-mac.sh`
- Create a local zip artifact: `bash scripts/zip-local-release.sh`

## macOS validation preference
- This checkout is maintained for macOS local testing.
- Use `bash scripts/validate-mac.sh` as the default validation path.
- The validator expects `luac`; if it is missing, run `bash scripts/bootstrap-lua-mac.sh` to build a local Lua 5.1.5 checker under `.tools/`.
