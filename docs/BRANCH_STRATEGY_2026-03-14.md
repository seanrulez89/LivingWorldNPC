# Branch Strategy - 2026-03-14

## Why this exists

This repo now has two different kinds of work happening:

- stability / bugfix work that should usually be safe to keep on `master`
- carrier / architecture experiments that may fail and should be isolated

Because of that, the repo needs a simple branching rule.

## The simple rule

### 1. `master` is for stable progress only
Put these on `master`:

- crash fixes
- cleanup safety fixes
- debug tool safety fixes
- logging quality improvements
- documentation of confirmed findings
- small refactors that do not commit the project to a speculative architecture path

### 2. Experimental carrier work always gets its own branch
Do **not** push these first to `master`:

- new carrier spikes (`IsoSurvivor`, `IsoZombie`, etc.)
- architecture experiments
- major embodiment rewrites
- speculative rendering/model fixes tied to one carrier approach
- large migration passes that may need to be abandoned or rewritten

### 3. Merge back only after a clear verdict
An experiment branch returns to `master` only when at least one of these is true:

- it clearly works in-game
- it provides infrastructure the project will keep regardless of the winning carrier
- the failed experiment still produced docs or tooling worth keeping, and those pieces are cherry-picked cleanly

## Naming rules

Use these branch prefixes:

- `stable/...`
  - known-good milestone or safe checkpoint
- `fix/...`
  - targeted bugfix or stability work
- `feature/...`
  - implementation work likely to survive and merge
- `spike/...`
  - short-lived experiment / proof-of-life work

## Recommended branch names for this project

Examples:

- `fix/debug-delete-safety`
- `fix/cleanup-npe`
- `feature/carrier-adapter`
- `spike/isosurvivor`
- `spike/isozombie`
- `stable/debug-delete-safe`

## What to do before starting work

### If the task is a bugfix or safety fix
Stay on `master` **only if** it is clearly a fix and not an architecture gamble.

### If the task is experimental
Create a branch first.

Examples:

```bash
git switch -c spike/isosurvivor
git switch -c spike/isozombie
git switch -c feature/carrier-adapter-phase2
```

## What to do after testing

### If the branch worked
- keep the branch
- merge or cherry-pick the useful commits to `master`

### If the branch failed
- keep the branch for history/reference if useful
- document the conclusion
- do not merge the speculative code into `master`

## Practical rule for this repo going forward

### Safe on `master`
- cleanup stability
- delete safety
- trace quality
- docs
- generic infrastructure with clear long-term value

### Not safe on `master`
- carrier experiments
- rendering spikes
- constructor guesswork
- actor-class replacement attempts

## Important note

Rewriting already-pushed `master` history is usually not worth the risk here.
If an experimental change accidentally lands on `master`, prefer this response:

1. create the correct branch from the relevant commit(s)
2. keep `master` unchanged unless there is a strong reason to rewrite history
3. follow the branch rule correctly from the next experiment onward

That is the safest policy for this project.
