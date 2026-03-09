# Codex app local environment actions (Windows)

Enter these in **Codex app > Project settings > Local environments**.

## Setup script (Windows)
```powershell
pwsh -File ./scripts/validate-mod-structure.ps1
```

## Suggested project actions

### Validate structure
```powershell
pwsh -File ./scripts/validate-mod-structure.ps1
```

### Read latest PZ console log
```powershell
pwsh -File ./scripts/read-console.ps1
```

### Zip local release
```powershell
pwsh -File ./scripts/zip-local-release.ps1
```

## Optional manual action
Launching the game manually from Steam is safer than granting Codex wider filesystem access just to start the game executable.
