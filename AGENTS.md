# AGENTS.md

## Project identity
- This repository is a **Project Zomboid Build 42 single-player mod**.
- The mod root is the repository root used by Codex.
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

## When editing code
- Preserve file-by-file module boundaries.
- Avoid speculative engine hooks. If an event or API is uncertain, add a TODO note and keep the hook isolated.
- Keep debug tooling available in development builds.
- After touching Lua runtime code, run the local validation scripts if available.
- Treat each meaningful coding turn as a snapshot boundary: after code changes, run validation, review `git status`, and prefer a small descriptive commit before moving to the next hypothesis.

## Preferred workflow
- Use the Local checkout for game-facing changes.
- Use Worktrees for larger refactors or parallel experiments.
- Before proposing a large rewrite, summarize the affected modules.

## Commands
- Validate mod structure (Windows/PowerShell path): `pwsh -File ./scripts/validate-mod-structure.ps1`
- Validate current WSL working tree: `./scripts/validate-wsl.sh`
- Open latest Project Zomboid console log: `pwsh -File ./scripts/read-console.ps1`
- Wipe this mod's test data from the current cache dir: `pwsh -File ./scripts/wipe-lwn-data.ps1`
- Create a local zip artifact: `pwsh -File ./scripts/zip-local-release.ps1`

## WSL validation preference
- When working inside WSL, prefer `./scripts/validate-wsl.sh` before falling back to PowerShell tooling.
- Use PowerShell validation scripts as secondary helpers, not the default validation path.
