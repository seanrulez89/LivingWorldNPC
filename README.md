# LivingWorldNPC

LivingWorldNPC is an experimental **single-player Project Zomboid Build 42** mod focused on data-driven NPC simulation and on-screen embodiment.

## Current status

This project is currently in active R&D.

- Canonical NPC state lives in `ModData`
- On-screen NPCs are embodied dynamically when needed
- The current active companion carrier is LWN's own managed `IsoZombie` shell;
  no external NPC runtime is required for the default test path
- The initial milestone of a human-looking, non-zombie-sounding, commandable NPC
  has been reached
- Current work is moving into three-person companion squad behavior: follow,
  wait, directed movement, combat stance, damage/death, status, inventory, and
  autonomous-feeling decisions
- Legacy `IsoZombie`, `IsoSurvivor`, and `IsoPlayer` carriers remain in the
  repository as research paths, not as the current default test path
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
- LWN-managed `IsoZombie` shells as the practical world carrier for test
  companions
- LWN-owned intents, command state, movement, combat execution, damage handling,
  and cleanup
- squad threat evaluation and combat permission through `LWN.Combat`
- runtime tracing for presentation, cleanup, death/corpse/reanimation, and UI targeting
- Build 42-specific validation and debugging workflow on macOS

## Repository layout

- `42/` — Build 42 runtime mod files
- `common/` — shared assets/resources
- `docs/` — research notes, audits, decision docs, and workflow references
- `scripts/` — local validation helpers

## Development workflow

This repository now uses a macOS-first local workflow. The game-facing checkout is intended to live under the local Project Zomboid Workshop development folder.

Primary validation command:

```bash
bash scripts/validate-mac.sh
```

That script currently checks:

- required Build 42 mod structure
- `git diff --check`
- `git diff --stat`
- `git diff --name-only`
- Lua syntax for all tracked runtime `.lua` files via `luac -p`

If `luac` is not available on the Mac yet, run:

```bash
bash scripts/bootstrap-lua-mac.sh
```

## Important notes

- `reference_mods/` is kept locally for research but is **not tracked** in the main git repository
- Build 41 reference mods are used as learning material, not as direct drop-in solutions for Build 42
- Bandits-related documents are historical/reference material only; the default
  runtime must not require Bandits2 or copy third-party code/assets
- Some documents in `docs/` are exploratory and may represent intermediate findings rather than final decisions

## Recommended reading

Start here if you want context:

- `docs/README.md`
- `docs/current/DOMAIN_WORKSTREAMS_AND_CONTRACTS_2026-06-16.md`
- `docs/current/MANAGED_ISOZOMBIE_INDEPENDENCE_2026-06-16.md`
- `docs/current/MANAGED_ISOZOMBIE_API_VERIFICATION_2026-06-17.md`
- `docs/current/WORK_SUMMARY_2026-06-17_INDEPENDENT_MANAGED_ISOZOMBIE.md`
- `docs/current/LOGGING_AND_TEST_EVIDENCE_2026-06-16.md`
- `docs/retired-bandits/COMPANION_SQUAD_COMBAT_FOUNDATION_PLAN_2026-06-14.md` historical only
- `docs/retired-bandits/BANDITS_CONTROLLED_NPC_IMPLEMENTATION_2026-06-13.md` historical only
- `docs/testing/TEST_LOG_HISTORY.md`
- `docs/reference/REFERENCE_MODS_LOCAL_CODE_REVIEW_2026-06-13.md`

## License / publishing note

This repository currently serves as a public development and research workspace. If you plan to reuse ideas, please inspect the source references in `docs/` and confirm the origin and compatibility of any borrowed patterns.
