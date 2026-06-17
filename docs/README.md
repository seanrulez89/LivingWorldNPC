# Docs Index

This directory keeps LivingWorldNPC design notes, research, test evidence, and
historical experiment records. The docs are now grouped by purpose so current
runtime guidance is not mixed with older investigation notes.

## Layout

| Folder | Count | Purpose |
| --- | ---: | --- |
| `current/` | 6 | Active June 2026 decisions, contracts, logging rules, and independent managed `IsoZombie` carrier notes. |
| `reference/` | 20 | API audits, source maps, reference-mod reviews, and Build 42 research. |
| `experiments/` | 36 | Historical implementation experiments and result notes. |
| `handoffs/` | 10 | Restart context and next-session handoff files. |
| `testing/` | 5 | Test history, manual test workflow, and test harness notes. |
| `work-notes/` | 7 | Dated running notes and end-of-day summaries. |
| `workflow/` | 3 | Git, branch, and local environment workflow notes. |
| `plans/` | 7 | Historical plan documents and spike plans. |
| `retired-bandits/` | 7 | Retired Bandits-backed plans and investigations. Preserved only as external reference/history. |

Root-level docs outside this folder are limited to project-facing files such as
`README.md`, `AGENTS.md`, `LWN_SP_TDD.md`, and `LWN_SP_TESTING.md`.

## Start Here

Read these first for the current project state:

- `current/DOMAIN_WORKSTREAMS_AND_CONTRACTS_2026-06-16.md`
  - active domain ownership, shared runtime contracts, and sub-agent work rules
- `current/MANAGED_ISOZOMBIE_INDEPENDENCE_2026-06-16.md`
  - current decision that default companions run through LWN's own managed
    `IsoZombie` carrier
- `current/MANAGED_ISOZOMBIE_API_VERIFICATION_2026-06-17.md`
  - local JDK/`javap` verification and the confirmed vanilla/Bandits animation
    contract difference
- `current/WORK_SUMMARY_2026-06-17_INDEPENDENT_MANAGED_ISOZOMBIE.md`
  - detailed summary of the independent carrier repair milestone
- `current/LOGGING_AND_TEST_EVIDENCE_2026-06-16.md`
  - current structured logging and manual test evidence guide
- `current/LONG_TERM_NPC_VISION_2026-06-16.md`
  - long-term design direction for player-like NPCs, relationships, narrative,
    autonomy, gifts, betrayal, and vehicles

## Current Test Evidence

- `testing/TEST_LOG_HISTORY.md`
  - append-only historical in-game test chain
- `current/LOGGING_AND_TEST_EVIDENCE_2026-06-16.md`
  - how to collect and read current structured logs

## Current Reference Baseline

- `reference/REFERENCE_MODS_LOCAL_CODE_REVIEW_2026-06-13.md`
  - local review of Steam-downloaded reference mods
- `reference/LWN_ISOZOMBIE_MASTER_REFERENCE_2026-03-21.md`
  - older but still useful master synthesis of the `IsoZombie` shell problem
- `reference/LWN_BUILD42_DECISION_MATRIX_2026-03-12.md`
  - compact Build 42 decision matrix
- `reference/OFFICIAL_BUILD42_API_AUDIT_2026-03-12.md`
  - official API/lifecycle audit

## Historical Material

The March and April documents are preserved because they contain useful
debugging evidence and rationale. They are not current runtime instructions.

Important historical groups:

- `experiments/`
  - implementation experiments, many of which are superseded by the current
    independent managed carrier path
- `handoffs/`
  - session restart notes; useful for reconstructing timeline, not for current
    architecture decisions
- `retired-bandits/`
  - retired Bandits-backed implementation plans and investigations

## Bandits Boundary

Bandits-related documents are historical/reference material only.

Current rules:

- default runtime must not require Bandits2
- do not copy Bandits code or assets
- use reference-mod findings only as engineering evidence
- if an idea is adopted, reimplement it inside LWN with LWN-owned files,
  contracts, and validation

## Path Policy

When adding new documentation:

- current active decisions go in `current/`
- test procedures or evidence go in `testing/`
- reference/API/source research goes in `reference/`
- dated running notes go in `work-notes/`
- one-off experiments go in `experiments/`
- restart handoffs go in `handoffs/`
- branch/tooling process notes go in `workflow/`
- retired external-runtime or Bandits-specific notes go in `retired-bandits/`
- use `plans/` only for a plan that is not yet implemented or is preserved as a
  plan artifact

Do not add new dated Markdown files directly under `docs/` unless they are
indexes.
