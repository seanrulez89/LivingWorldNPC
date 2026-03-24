# Docs Index

This directory contains research notes, audits, workflow references, and experiment summaries for LivingWorldNPC.

## Fresh synthesis / triage

- `INITIAL_HUMANIZATION_SPLIT_IMPLEMENTATION_2026-03-24.md`
  - implementation note for the first major structural split between spawn-time initial humanization and sync-time maintenance, including the new `ShellHumanizer` module and an in-game validation order
- `LWN_ISOZOMBIE_MASTER_REFERENCE_2026-03-21.md`
  - new master synthesis of the March 20 IsoZombie research set, including:
    - executive verdict
    - supported vs speculative boundaries
    - Build 41 lessons vs Build 42 distrust points
    - what the best reference mods actually prove
    - why the problem is really human perception / illusion maintenance
    - the current strongest architecture for `spike/isozombie`
    - a phased, practical next-session experiment roadmap
- `LWN_ISOZOMBIE_CLEANUP_TRIAGE_2026-03-21.md`
  - conservative cleanup candidate review of the current codebase, grouped into:
    - high-confidence safe-to-remove soon
    - likely removable but confirm first
    - suspicious but should not be removed yet
- `LWN_BANDITS_1TO1_MINIMAL_COMPONENT_MAP_2026-03-21.md`
  - detailed 1:1 structure map from Bandits into LWN, identifying the minimum missing orchestration components for a true `IsoZombie`-shell persistent-illusion architecture

## Current blocker / next spike

- for the most current branch-level judgment, read `LWN_ISOZOMBIE_MASTER_REFERENCE_2026-03-21.md` first
- the notes below are the 2026-03-20 session snapshot and are useful as historical context, not as the latest final verdict
- current active carrier direction is `IsoZombie`, not `IsoPlayer`
- the hybrid appearance experiment now really runs on the live `IsoZombie` shell, but the shell still renders through zombie presentation (`reanimated_zombie`, zombie body skin)
- relationship policy has started affecting live behavior: `hostile` can now provoke pursuit/attack intent, while `friendly` / `neutral` still suffer from movement-churn / partial-neutralization issues
- the March 20 snapshot's most immediate technical blocker was a repeatable Java-side exception during relationship/trust sync:
  - `NullPointerException: Cannot assign field "isNpc" because "this.player" is null`
  - current code has since added zombie-carrier guards around those human-only setters; the master reference covers the newer architecture verdict
- recommended next manual experiments / fixes:
  1. strengthen non-hostile movement suppression and trace the repeated `retreat` / deferred movement churn
  2. probe the zombie presentation pipeline itself rather than only descriptor/human-visual shaping
  3. keep validating shell identity continuity and UI framing rather than treating the problem as purely visual

## Start here

- `ISO_PLAYER_HARDENING_2026-03-14.md`
  - concrete code-level hardening pass for the current `IsoPlayer` route and what result should trigger abandonment
- `CLEANUP_NPE_HARDENING_2026-03-14.md`
  - safety hardening for live `IsoPlayer` debug cleanup after a `getCurrentSquare()==nil` crash during deletion
- `DEBUG_DELETE_COMBAT_GUARD_2026-03-14.md`
  - simplified delete contract: block debug delete during combat, allow immediate delete only outside combat
- `LOG_QUALITY_TUNING_2026-03-14.md`
  - small trace-noise cleanup for death waiting and trivial detached-self leftover snapshots
- `ISOPLAYER_EXIT_PLAN_2026-03-14.md`
  - what to keep, what to discard, and which carrier experiments to run after retiring `IsoPlayer`
- `CARRIER_ADAPTER_DRAFT_2026-03-14.md`
  - first adapter boundary draft plus the initial runtime-handle bridge for future carrier migration
- `CARRIER_ADAPTER_MIGRATION_PASS_2026-03-14.md`
  - first real spawn/sync/retire routing pass from legacy actor calls into the adapter
- `CARRIER_ISOSURVIVOR_SPIKE_2026-03-14.md`
  - proof-of-life `IsoSurvivor` carrier experiment, including constructor fallback strategy and test path
- `CARRIER_ISOZOMBIE_SPIKE_PLAN_2026-03-14.md`
  - planning document for the next embodied carrier experiment using `IsoZombie`
- `CARRIER_EXPERIMENT_RESULTS_2026-03-14.md`
  - consolidated result summary for the `IsoPlayer` and `IsoSurvivor` experiments, plus the current next-step verdict
- `CARRIER_ISOZOMBIE_SPIKE_IMPL_2026-03-14.md`
  - first implementation pass for the `IsoZombie` proof-of-life carrier experiment
- `CARRIER_ISOZOMBIE_RESOLVE_HARDENING_2026-03-14.md`
  - hardening pass for `IsoZombie` continuity: longer grace, carrier-aware resolve, and recovery from the carrier handle
- `CARRIER_ISOZOMBIE_SYNC_UI_BRANCHING_2026-03-14.md`
  - carrier-aware sync and UI targeting changes for `IsoZombie`, removing human-only setter assumptions and allowing managed zombie carriers through context targeting
- `CARRIER_ISOZOMBIE_MANAGED_TARGET_FINALIZATION_2026-03-14.md`
  - final managed-actor/targetability adjustment so `IsoZombie` carriers are no longer judged by human runtime-core rules
- `CARRIER_ISOZOMBIE_SUCCESS_RESULT_2026-03-14.md`
  - confirms the first successful visible, persistent, interactive `IsoZombie` shell result
- `CARRIER_ISOZOMBIE_TRUST_HOSTILITY_2026-03-14.md`
  - relationship-driven hostility policy groundwork for `IsoZombie`, preserving future betrayal design instead of hardcoding permanent safety
- `CARRIER_ISOZOMBIE_HOSTILITY_EXPLORATION_2026-03-14.md`
  - careful first pass applying relationship policy directly to zombie shell posture and hostile activation attempts
- `CARRIER_ISOZOMBIE_FRIENDLY_ATTACK_SUPPRESSION_2026-03-14.md`
  - minimal friendly-shell suppression test using `setGodMod(true)` only when policy disallows player attack
- `WORK_NOTES_2026-03-20.md`
  - running technical narrative for the March 20-21 `IsoZombie` spike, including debug forcing, hybrid appearance work, churn suppression, appearance diff logging, and the first persistent illusion package
- `NEXT_SESSION_HANDOFF_2026-03-21.md`
  - the detailed end-of-day restart guide after the March 21 spike, including commit sequence, what actually improved, what still reads zombie, and the recommended next code priorities
- `NEXT_SESSION_HANDOFF_2026-03-14.md`
  - earlier practical restart guide from the first visible `IsoZombie` success stage; useful historical context but superseded by the March 21 handoff
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

- `LWN_ISOZOMBIE_MASTER_REFERENCE_2026-03-21.md`
  - consolidated strategic reference that supersedes the need to read the four March 20 IsoZombie research docs separately before the next session
- `LWN_ISOZOMBIE_CLEANUP_TRIAGE_2026-03-21.md`
  - current cleanup/removal triage for stale carrier paths, legacy stubs, and risky human-first assumptions
- `REFERENCE_CORPUS_ISOZOMBIE_AUDIT_2026-03-20.md`
  - full-corpus rescan focused on `IsoZombie` NPC-shell embodiment, human-presentation tricks, lifecycle patterns, and Build 41 -> 42 portability clues
- `BUILD42_ISOZOMBIE_NPC_WEB_MEMO_2026-03-20.md`
  - official Build 42 docs + web-context memo focused on supported `IsoZombie` shell boundaries and Build 42 pooling risk
- `BUILD41_78_JAVADOC_SKEPTICAL_AUDIT_FOR_BUILD42_ISOZOMBIE_SHELL_2026-03-20.md`
  - skeptical read of Build 41.78 javadocs as a concept map, not as Build 42 implementation truth
- `PZWIKI_BUILD42_ISOZOMBIE_SHELL_REVIEW_2026-03-20.md`
  - wiki-driven review of the broader Build 42 modding lanes, especially UI/animation/audio/perception implications for a zombie-shell NPC
- `REFERENCE_STUDY_2026-03-11.md`
- `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS.md`
- `LUA_FLOW_AUDIT_2026-03-11.md`
- `REFERENCE_MODS_DEEP_ANALYSIS.txt` (repo root)

These documents summarize what was learned from reference mods and how those lessons may or may not apply to Build 42.

## Workflow / process docs

- `GIT_WORKFLOW_2026-03-11.md`
  - git hygiene, validation workflow, snapshot-commit rule
- `WORK_NOTES_2026-03-11.md`, `WORK_NOTES_2026-03-13.md`, `WORK_NOTES_2026-03-14.md`, `WORK_NOTES_2026-03-20.md`, ...
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
