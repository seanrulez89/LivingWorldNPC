# Working Context - 2026-06-13

## Project location

The active game-facing repository is:

```text
/Users/sean/Zomboid/Workshop/LivingWorldNPC/Contents/mods/LivingWorldNPC
```

`/Users/sean/Documents/Project_Zomboid` is only an empty, unborn Git repository. Do not use it for LivingWorldNPC changes.

## Repository state

- Project: Project Zomboid Build 42 single-player mod
- Mod id: `LivingWorldNPCSP`
- Branch: `spike/bandits-visual-probe-v1`
- Local HEAD: `74e7c4b Switch local workflow to macOS validation`
- Remote branch HEAD: `e9a8bfd Reset handoff to spawn-first Bandits focus`
- Local branch is one commit ahead of origin; `74e7c4b` has not been pushed.
- The remote was fetched and checked on 2026-06-13.
- Before this context document was added, the working tree was clean.

## Immediate goal

The current goal is deliberately narrow:

> Spawn an NPC that visibly reads as human for at least one second.

Do not prioritize movement, distance despawn, return/recovery, replacement, combat, or long-lived stability until this first visible result exists.

## Established technical conclusions

- Canonical NPC state lives in `ModData`; embodied actors are runtime caches.
- `IsoZombie` is the only currently practical and stable world shell.
- The shell can spawn, remain calm, suppress zombie audio, and move, but its final presentation still resolves as `reanimated_zombie` with `fail_presentation_role_zombie`.
- Descriptor, skin, clothing, worn-item, and item-visual values can all appear valid while the final rendered ownership remains zombie-side.
- `IsoSurvivor` is quarantined because its incomplete runtime contract can crash in engine update code due to missing `BodyDamage`.
- `IsoPlayer` can satisfy many alive/runtime checks but has not visibly materialized; the strongest clue was missing model registration and a null `legsSprite.modelSlot` path.
- Bandits-style visual/build borrowing is not a no-op: it changes real appearance state. It has not yet produced a human-looking first spawn.
- The next investigation should find the earliest spawn-time checkpoint where zombie-owned presentation is established or re-established.

## Primary code path

Read and edit in this order:

1. `42/media/lua/client/23_LWN_ActorFactory.lua`
   - Bandits-style visual probe and Bandits-first build lane
   - presentation checkpoints and transition-cause tracking
   - highest-value place for the next narrow experiment
2. `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
   - minimum shell state required to keep the first spawn visible
3. `42/media/lua/client/92_LWN_DebugTools.lua`
   - `TEST 01`, `TEST STATUS`, and one-line checkpoint summaries
4. `42/media/lua/client/25_LWN_EmbodimentManager.lua`
   - touch only if initial materialization clearly interferes with first-second appearance

## Runtime status

- Last confirmed game run: 2026-05-17.
- The mod loaded and emitted boot markers for `23_LWN_ActorFactory`, `35_LWN_Carrier_IsoZombie`, and `92_LWN_DebugTools`.
- The latest console log contains no `TEST 01`, `TEST STATUS`, `BanditsFactory`, or spawn checkpoint run from the current macOS workflow.
- Therefore the first real in-game validation of the current local branch is still pending.
- `/Users/sean/Zomboid/options.ini` currently has `fullScreen=false` and `lockCursorToWindow=false` to make automated screen interaction more reliable.

## Next test

Run exactly this small loop before changing runtime code:

1. Start Project Zomboid and enter a test world with `LivingWorldNPCSP` enabled.
2. Use `LWN Tests -> TEST RESET - Clear State`.
3. Use `LWN Tests -> TEST 01 - Spawn Baseline (IsoZombie)`.
4. Observe and capture the actor immediately.
5. Use `LWN Tests -> TEST STATUS - Dump Current`.
6. Read `console.txt` for `Boot`, `TestAction`, `BanditsFactory`, `BanditsCheckpoint`, `Checkpoint`, and `Transition`.

Success is visual: the fresh actor must look human, even briefly. A mechanically healthy but zombie-looking actor is still a failure.

## Development environment

- Default validation: `bash scripts/validate-mac.sh`
- Lua checker: local Lua 5.1.5 `luac` under `.tools/lua-5.1.5/src/luac`
- Console helper: `bash scripts/read-console-mac.sh`
- Local artifact helper: `bash scripts/zip-local-release.sh`
- Validation on 2026-06-13 passed for all 34 runtime Lua files.

## Session guardrails

- Keep changes small and hypothesis-driven.
- Preserve Build 42 layout under `42/` and `common/`.
- Do not revive the `IsoSurvivor` test lane without a new engine-contract argument.
- Do not repeat generic descriptor/clothing rebuild experiments already shown to leave presentation zombie-owned.
- Treat TEST 04 return/recovery work as background until first-spawn appearance succeeds.
- Validate and review Git status after Lua changes; prefer a small commit at each meaningful snapshot.

## Best source documents

1. `docs/NEXT_SESSION_HANDOFF_2026-04-05.md`
2. `docs/BANDITS_FIRST_BUILD_LANE_2026-03-29.md`
3. `docs/CODE_AUDIT_2026-04-04.md`
4. `docs/TEST_LOG_HISTORY.md`
5. `LWN_SP_TESTING.md`
