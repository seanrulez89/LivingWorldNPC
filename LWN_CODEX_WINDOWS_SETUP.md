# LivingWorldNPCSP + Codex app on Windows

This document is a practical setup checklist for using the Codex app as the coding agent for this repository on Windows.

## Recommended local checkout strategy
Keep the **Local** checkout in your actual Project Zomboid local mods folder so the game reads live edits immediately.

Example path:

```text
C:\Users\<you>\Zomboid\mods\LivingWorldNPCSP
```

Use Codex **Worktrees** for background tasks and hand them back to **Local** when you want to run the game against the changes.

## First-run checklist
1. Initialize Git in this folder.
2. Open this folder as a project in the Codex app.
3. Keep sandboxing on.
4. Use the Local checkout for foreground work.
5. Configure the local environment actions from `docs/CODEX_LOCAL_ENVIRONMENT_ACTIONS.md`.
6. Start Project Zomboid manually from Steam with your debug launch options.
7. Feed `console.txt`, screenshots, and behavior notes back into Codex for the next patch.
