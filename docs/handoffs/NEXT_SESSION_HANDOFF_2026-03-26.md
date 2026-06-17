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


## Follow-up debug pass after first live validation

After the first live TEST 01-04 run, the user confirmed the stronger failure mode:

- two different NPCs overlapped at spawn
- commanded walking never actually started
- the original shells later returned as hostile attackers with the same clothes/hair
- fresh stationary replacements then appeared with different random appearance

A follow-up direct patch addressed that by:

- forcing clean-slate automation startup and reset
- switching debug quarantine default back off for movement testing
- making move commands explicitly drop quarantine
- widening debug shell recovery to reclaim matching shells near the player/anchor
- blocking hidden debug records from auto-respawning replacement shells after actor loss

See also:

- `docs/experiments/DEBUG_SINGLE_SHELL_RECOVERY_2026-03-26.md`


## Follow-up locomotion patch after direct retest

The next live retest after `98d1352` narrowed the state further:

- one visible test NPC only
- no visible walking at all during TEST 02/03 (completely statue-like)
- command state reached `queued -> pathing` but body/world position never changed
- `90_LWN_EventAdapter.lua` had a real nil-call regression in `findRecoveryCandidateNearSquare`

A direct follow-up patch then:

- fixed the recovery helper nil-call
- removed designated-move prep full-sync side effects
- made carrier anchor snapping opt-in instead of always-on
- switched movement start to try actor-level path calls first

The immediate next question for live validation is now simple:

- do TEST 02/03 finally show first visible walking?

## Latest live validation after `ba1e972`

The next live validation answered that question in a worse way than hoped:

- the test still started with one visible NPC only
- the shell immediately read as hostile / attack-seeking while remaining stuck in place
- zombie audio leakage was back
- `TEST 02` / `TEST 03` still showed only in-place walking with no real displacement or turning
- local active-test appearance stayed mostly stable, but posture still read as hunched / zombie-like
- after leaving and returning, the user clearly saw both of these **simultaneously** on screen:
  - the original roaming hostile zombie shell
  - a different-looking NPC anchored back at the original test spot
- forcing the anchored replacement friendly changed its appearance again
- deleting the anchored NPC failed because the actor was still considered in combat
- the previous explicit EventAdapter runtime error did not obviously recur

## Current best diagnosis

The branch now appears to have two linked failures active at once:

1. **Combat-state leak into non-hostile shells**
   - the managed `non_hostile_commandable` shell is still targetable / combat-active in practice
   - this matches the user seeing attack intent, zombie audio, and delete-blocking due to `actor_has_target`

2. **Duplicate embodiment via rogue original + anchored replacement**
   - the user explicitly saw the roaming hostile original and anchored replacement together on the same screen
   - this is stronger than an observability ambiguity; it is active dual-shell coexistence

A third issue remains open beneath those two:

3. **Pathing without locomotion**
   - command state can reach `pathing` with `moving=true` and `path2=true`
   - but the actor still does not visibly leave the anchor square

## Immediate next priorities

1. Hard-clear combat target / attack state every tick for commandable non-hostile shells.
2. Add explicit combat-target observability to debug output.
3. Explain anchored in-place walking before doing more posture polish.
4. Keep duplicate-shell debugging centered on `rogue hostile original` versus `managed anchored replacement`.
