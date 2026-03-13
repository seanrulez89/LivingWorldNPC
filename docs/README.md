# Docs Index

This directory contains research notes, audits, workflow references, and experiment summaries for LivingWorldNPC.

## Start here

- `ARCHITECTURE_VERDICT_2026-03-13.md`
  - final judgment on whether the current architecture is still worth pushing
- `INGAME_TEST_CHECKLIST_2026-03-13.md`
  - must-run scenarios for the next in-game verdict pass
- `LWN_BUILD42_DECISION_MATRIX_2026-03-12.md`
  - condensed decision aid for what to trust, question, or test next
- `STRUCTURE_REVIEW_EXPERIMENTS_2026-03-12.md`
  - grouped experiment results for structure-level questions
- `OFFICIAL_BUILD42_API_AUDIT_2026-03-12.md`
  - comparison between current LWN patterns and official Build 42 API/lifecycle expectations

## Build 42 knowledge / source mapping

- `BUILD42_MODDING_KNOWLEDGE_MAP_2026-03-12.md`
  - broad topic map of official Build 42 modding knowledge
- `BUILD42_MODDING_SOURCE_REGISTER_2026-03-12.md`
  - source register with official vs supporting references

## Reference-study documents

- `REFERENCE_STUDY_2026-03-11.md`
- `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS.md`
- `LUA_FLOW_AUDIT_2026-03-11.md`
- `REFERENCE_MODS_DEEP_ANALYSIS.txt` (repo root)

These documents summarize what was learned from reference mods and how those lessons may or may not apply to Build 42.

## Workflow / process docs

- `GIT_WORKFLOW_2026-03-11.md`
  - git hygiene, validation workflow, snapshot-commit rule
- `WORK_NOTES_2026-03-11.md`, `WORK_NOTES_2026-03-13.md`, ...
  - date-matched work notes; each file should only contain work from its own date
- `TEST_LOG_HISTORY.md`
  - append-only in-game test history linking observation -> logs -> lesson -> fix -> next check
- `CODEX_LOCAL_ENVIRONMENT_ACTIONS.md`
  - local environment setup/actions used during development

## Reading guidance

- If you want the quickest overview, start with the decision matrix.
- If you want the current go/no-go judgment after the large refactor pass, read the architecture verdict and in-game checklist next.
- If you want the detailed reasoning behind it, read the structure review and official API audit next.
- If you want raw ongoing findings, read the work notes.
