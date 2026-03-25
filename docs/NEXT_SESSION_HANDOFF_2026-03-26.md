# Next Session Handoff — 2026-03-26

Branch: `spike/isozombie`
Status: movement-capable non-hostile shell pass completed

## What landed

- non-hostile `IsoZombie` shells can now keep walking without regaining hostile attack behavior
- designated-location walking is implemented through the existing intent/runtime queue
- command state now lives on the record side under `record.companion.command`
- test automation is renamed into numbered `TEST 01` to `TEST 04` menu steps
- all human-check prompts are ASCII speech bubbles with explicit observation goals

## Most important runtime change

The branch no longer treats:

- `friendly` / `neutral`

as equivalent to:

- `fully immobilized`

Instead the carrier/runtime stack now supports:

- command-only non-hostile shells for the debug harness
- autonomous non-hostile mobile shells for normal friendly / neutral policy
- quarantine as a separate hard-stop mode

## What to verify next in-game

1. Confirm commanded walking actually reaches the designated destination in repeated runs.
2. Confirm appearance does not drift during the walk itself, not just while idle.
3. Confirm the walk animation reads less zombie-like than the old frozen shell.
4. Re-run the distance-return step and watch for any hostile reversion under the new mobile non-hostile mode.

## Main files touched this pass

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`
- `42/media/lua/client/20_LWN_ActionRuntime.lua`
- `42/media/lua/client/27_LWN_UI_RadialMenu.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

## Validation run

- `./scripts/validate-wsl.sh`
- `luac -p` on all changed Lua files
