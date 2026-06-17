# Documentation Naming And Reference Policy

This policy keeps LivingWorldNPC documentation searchable by filename and safe
to rename without losing cross-document references.

## Standard Filename

Use this format for non-index documentation:

```text
YYYY-MM-DD_DOMAIN_TOPIC_DOCROLE.md
```

Rules:

- Use ASCII uppercase words separated by underscores.
- Put the date first for chronological sorting.
- Keep the date tied to the document's event, creation date, or primary evidence
  date; do not use the cleanup date unless the cleanup itself is the content.
- Keep the filename descriptive enough to identify the document without opening
  it.
- Avoid vague tokens such as `FINAL`, `LATEST`, `NEW`, or `MISC` unless they are
  part of historical source material.

## Date Rules

Choose the date in this order:

1. The explicit date already present in the old filename.
2. The date of the event or test evidence described by the document.
3. The first tracked git date for undated legacy documents.
4. Today's date only for new documents written today.

## Domain Tokens

Use one or two stable domain tokens near the start of the descriptive part.

Preferred tokens:

- `ARCHITECTURE`
- `API`
- `BANDITS_RETIRED`
- `CARRIER`
- `CODE`
- `COMBAT`
- `DOCS`
- `EXPERIMENT`
- `HANDOFF`
- `LOGGING`
- `PLAN`
- `REFERENCE`
- `TESTING`
- `VISION`
- `WORKFLOW`
- `WORK_NOTES`

Add a new token only when none of these accurately describes the document.

## Document Role Tokens

End filenames with a role token when it helps clarify intent.

Preferred role tokens:

- `AUDIT`
- `CHECKLIST`
- `DECISION`
- `GUIDE`
- `HANDOFF`
- `HISTORY`
- `PLAN`
- `POLICY`
- `REFERENCE`
- `REPORT`
- `SUMMARY`

## Allowed Exceptions

These files keep conventional names:

- `README.md`
- `AGENTS.md`
- `docs/README.md`

Do not rename these unless the project explicitly changes its tooling and
conventions.

## Folder Placement

- `docs/current/`: active decisions, contracts, and current implementation notes
- `docs/reference/`: API/source research and durable technical references
- `docs/experiments/`: historical trials, results, and discarded attempts
- `docs/handoffs/`: restart context for future sessions
- `docs/testing/`: test plans, logs, harnesses, and local debug guides
- `docs/work-notes/`: dated running notes and end-of-day summaries
- `docs/workflow/`: process, branch, git, environment, and docs policies
- `docs/plans/`: proposed or preserved implementation plans
- `docs/retired-bandits/`: Bandits-backed historical references only

## Reference Updates

When renaming documentation:

- use `git mv` so history remains followable
- build an explicit `old_path -> new_path` map
- update full path references such as `docs/reference/OLD.md`
- update docs-root relative references such as `reference/OLD.md`
- update bare filename references when they point to a renamed document
- verify that every `.md` reference in `README.md`, `AGENTS.md`, and `docs/**/*.md`
  resolves to an existing file
- run `git diff --check` and the project validation script before committing
