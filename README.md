# LivingWorldNPC

LivingWorldNPC is an experimental **single-player Project Zomboid Build 42** mod focused on data-driven NPC simulation and on-screen embodiment.

## Current status

This project is currently in active R&D.

- Canonical NPC state lives in `ModData`
- On-screen NPCs are embodied dynamically when needed
- The current embodiment path is still under active investigation
- The repository contains both runtime code and research/debug documentation

In short: this is a working development repository, **not a finished stable release**.

## Goals

- Simulate off-screen NPCs as lightweight records
- Embody nearby NPCs as world actors only when needed
- Keep a canonical data model separate from runtime actor caches
- Build a robust single-player NPC workflow for Build 42

## Current technical direction

The project currently experiments with:

- `ModData` as canonical NPC state
- dynamic embodiment near the player
- runtime tracing for presentation, cleanup, death/corpse/reanimation, and UI targeting
- Build 42-specific validation and debugging workflow inside WSL

## Repository layout

- `42/` — Build 42 runtime mod files
- `common/` — shared assets/resources
- `docs/` — research notes, audits, decision docs, and workflow references
- `scripts/` — local validation helpers

## Development workflow

This repository uses a WSL-first local workflow.

Primary validation command:

```bash
./scripts/validate-wsl.sh
```

That script currently checks:

- `git diff --check`
- `git diff --stat`
- `git diff --name-only`
- Lua syntax for changed `.lua` files via `luac -p` when available

## Important notes

- `reference_mods/` is kept locally for research but is **not tracked** in the main git repository
- Build 41 reference mods are used as learning material, not as direct drop-in solutions for Build 42
- Some documents in `docs/` are exploratory and may represent intermediate findings rather than final decisions

## Recommended reading

Start here if you want context:

- `docs/README.md`
- `docs/LWN_BUILD42_DECISION_MATRIX_2026-03-12.md`
- `docs/STRUCTURE_REVIEW_EXPERIMENTS_2026-03-12.md`
- `docs/OFFICIAL_BUILD42_API_AUDIT_2026-03-12.md`

## License / publishing note

This repository currently serves as a public development and research workspace. If you plan to reuse ideas, please inspect the source references in `docs/` and confirm the origin and compatibility of any borrowed patterns.
