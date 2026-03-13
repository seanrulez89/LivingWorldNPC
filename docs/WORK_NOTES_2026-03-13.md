# LivingWorldNPC Work Notes

Date: 2026-03-13

## Scope of this file
This file is for work performed on 2026-03-13 only.

## Operating rule
- Date-stamped `WORK_NOTES_YYYY-MM-DD.md` files must only contain work from their matching date.
- Cross-test narratives and rolling lessons belong in `docs/TEST_LOG_HISTORY.md`.
- If later work references earlier notes, link or summarize them instead of appending new-day work into an older date file.

## 2026-03-13 summary
- Added and maintained `docs/TEST_LOG_HISTORY.md` as the append-only chain for in-game test results, log signals, lessons, follow-up changes, and next checks.
- Performed additional reference rescans and architecture review work, producing:
  - `docs/REFERENCE_STUDY_2026-03-13_FULL_RESCAN.md`
  - `docs/REFERENCE_STUDY_2026-03-13_LWN_IMPLICATIONS.md`
  - `docs/ARCHITECTURE_VERDICT_2026-03-13.md`
  - `docs/INGAME_TEST_CHECKLIST_2026-03-13.md`
- Large architecture pass concluded that the current direction can continue, but only as a defensive/experimental embodiment model:
  - `ModData` remains canonical state
  - `IsoPlayer` is treated as an embodied carrier, not as proof of official Build 42 human-NPC support
- Latest successful test analysis on 2026-03-13 indicated:
  - no crash
  - stale target behavior improved
  - cleanup contract behaves better
  - alive actor is still invisible despite apparently normal runtime state
  - highest remaining suspicion is alive render/model registration path rather than simple alpha/ghost/invisible flags
- Follow-up guidance for 2026-03-13 work:
  - keep new dated work notes in same-day files only
  - keep rolling test evidence in `TEST_LOG_HISTORY.md`
  - prefer commit snapshots after meaningful coding turns
