# Test Log History

This file is the running narrative for in-game test results.

## Purpose

Track each meaningful test cycle in a way that preserves causality:

1. what was tested
2. what happened in-game
3. what the logs showed
4. what hypothesis or lesson was derived
5. what code/doc changes followed
6. what the next expected check should be

## Entry format

For every new test cycle, append a new section using this structure:

```md
## YYYY-MM-DD HH:MM KST — Short title

### In-game result
- ...

### Log signals
- ...

### Interpretation / lesson
- ...

### Code or document changes that followed
- ...

### Next thing to verify
- ...
```

## Notes

- Keep entries append-only.
- Prefer concrete observations over vague summaries.
- If an observation later turns out to be wrong, do not erase it; append a correction in a later entry.
- This file is intended to help large refactors keep contact with actual test evidence.
