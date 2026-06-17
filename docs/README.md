# Docs Index

This directory keeps LivingWorldNPC design notes, research, test evidence, and
historical experiment records. Documents are grouped by purpose, and dated
documents use a filename that exposes the date, domain, topic, and document role.

## Layout

| Folder | Count | Purpose |
| --- | ---: | --- |
| `current/` | 6 | Active June 2026 decisions, contracts, logging rules, and independent managed `IsoZombie` carrier notes. |
| `reference/` | 21 | API audits, source maps, reference-mod reviews, Build 42 research, and technical design references. |
| `experiments/` | 36 | Historical implementation experiments and result notes. |
| `handoffs/` | 10 | Restart context and next-session handoff files. |
| `testing/` | 6 | Test history, manual test workflow, local debug guide, and test harness notes. |
| `work-notes/` | 7 | Dated running notes and end-of-day summaries. |
| `workflow/` | 4 | Git, branch, local environment, and documentation workflow notes. |
| `plans/` | 7 | Historical plan documents and spike plans. |
| `retired-bandits/` | 7 | Retired Bandits-backed plans and investigations. Preserved only as external reference/history. |

Root-level Markdown files outside this folder are limited to project-facing
convention files: `README.md` and `AGENTS.md`.

## Naming Policy

For non-index documentation, use:

```text
YYYY-MM-DD_DOMAIN_TOPIC_DOCROLE.md
```

Examples:

- `current/2026-06-17_CARRIER_MANAGED_ISOZOMBIE_API_VERIFICATION.md`
- `current/2026-06-16_LOGGING_TEST_EVIDENCE_GUIDE.md`
- `experiments/2026-03-29_EXPERIMENT_ISOZOMBIE_ISOSURVIVOR_REPORT.md`

See `workflow/2026-06-17_DOCS_NAMING_AND_REFERENCE_POLICY.md` for the full
rules, allowed exceptions, and reference-update policy.

## Start Here

Read these first for the current project state:

- `current/2026-06-16_ARCHITECTURE_DOMAIN_WORKSTREAMS_AND_CONTRACTS_POLICY.md`
  - active domain ownership, shared runtime contracts, and sub-agent work rules
- `current/2026-06-16_CARRIER_MANAGED_ISOZOMBIE_INDEPENDENCE_DECISION.md`
  - current decision that default companions run through LWN's own managed
    `IsoZombie` carrier
- `current/2026-06-17_CARRIER_MANAGED_ISOZOMBIE_API_VERIFICATION.md`
  - local JDK/`javap` verification and the confirmed vanilla/Bandits animation
    contract difference
- `current/2026-06-17_CARRIER_INDEPENDENT_MANAGED_ISOZOMBIE_WORK_SUMMARY.md`
  - detailed summary of the independent carrier repair milestone
- `current/2026-06-16_LOGGING_TEST_EVIDENCE_GUIDE.md`
  - current structured logging and manual test evidence guide
- `current/2026-06-16_VISION_LONG_TERM_NPC_DESIGN.md`
  - long-term design direction for player-like NPCs, relationships, narrative,
    autonomy, gifts, betrayal, and vehicles
- `workflow/2026-06-17_DOCS_NAMING_AND_REFERENCE_POLICY.md`
  - documentation naming and reference maintenance rules

## Current Test Evidence

- `testing/2026-03-13_TESTING_LOG_HISTORY.md`
  - append-only historical in-game test chain
- `current/2026-06-16_LOGGING_TEST_EVIDENCE_GUIDE.md`
  - how to collect and read current structured logs
- `testing/2026-03-10_TESTING_LOCAL_DEBUG_GUIDE.md`
  - local Build 42 test and debug guide

## Current Reference Baseline

- `reference/2026-06-13_REFERENCE_MODS_LOCAL_CODE_REVIEW.md`
  - local review of Steam-downloaded reference mods
- `reference/2026-03-21_CARRIER_ISOZOMBIE_MASTER_REFERENCE.md`
  - older but still useful master synthesis of the `IsoZombie` shell problem
- `reference/2026-03-12_ARCHITECTURE_BUILD42_DECISION_MATRIX.md`
  - compact Build 42 decision matrix
- `reference/2026-03-12_API_OFFICIAL_BUILD42_AUDIT.md`
  - official API/lifecycle audit
- `reference/2026-03-10_ARCHITECTURE_SINGLE_PLAYER_TECHNICAL_DESIGN.md`
  - original single-player technical design document

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
- branch/tooling/documentation process notes go in `workflow/`
- retired external-runtime or Bandits-specific notes go in `retired-bandits/`
- use `plans/` only for a plan that is not yet implemented or is preserved as a
  plan artifact

Do not add new dated Markdown files directly under `docs/` unless they are
indexes.
