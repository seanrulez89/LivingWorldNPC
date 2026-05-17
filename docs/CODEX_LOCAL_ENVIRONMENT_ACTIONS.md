# Codex app local environment actions (macOS)

Enter these in **Codex app > Project settings > Local environments**.

## Setup script
```bash
bash scripts/bootstrap-lua-mac.sh
```

## Suggested project actions

### Validate repo and Lua syntax
```bash
bash scripts/validate-mac.sh
```

### Read latest PZ console log
```bash
bash scripts/read-console-mac.sh
```

### Zip local release
```bash
bash scripts/zip-local-release.sh
```

## Optional manual action
Launching the game manually from Steam is safer than granting Codex wider filesystem access just to start the game executable.
