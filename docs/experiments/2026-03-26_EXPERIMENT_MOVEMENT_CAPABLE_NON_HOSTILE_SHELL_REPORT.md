# Movement-Capable Non-Hostile Shell — 2026-03-26

Branch: `spike/isozombie`
Status: implemented

## What changed

Today's pass split **non-hostile** from **immobile** for `IsoZombie` carriers.

Before this pass:

- friendly / neutral shell policy effectively meant full neutralization
- neutralization cleared runtime movement along with combat
- debug harness hold/quarantine settings made movement testing misleading

After this pass:

- friendly / neutral policy can use a **movement-capable non-hostile shell mode**
- attack behavior stays suppressed
- humanization / no-lunge / no-teeth / audio suppression stay active
- commanded walking can run through the existing `ActionIntents` + `ActionRuntime` path

## Carrier/runtime model

### Shell modes

The relationship policy layer now distinguishes:

- `hostile`
- `non_hostile_mobile`
- `non_hostile_commandable`
- `non_hostile_hold`
- `debug_quarantine`
- `recovery_non_hostile_mobile`

The important new idea is:

- `shouldNeutralizeCarrier=true` no longer automatically means `setCanWalk(false)`

Instead the policy also carries:

- `allowMovement`
- `allowAutonomousMovement`
- `shellMode`

That lets the carrier and embodied tick loop preserve anti-hostility while still allowing walking.

### Debug harness behavior

For today's milestone, debug-spawned `IsoZombie` shells now default to:

- hold position by default
- allow commanded movement
- quarantine off by default

This keeps baseline observation stable without permanently freezing the shell.

## Commanded destination walking

Implemented through the existing stack:

- `ActionIntents.moveTo(...)`
- `ActionRuntime.replaceWithIntent(...)`
- record-side command state under `record.companion.command`

The new command state tracks:

- command kind
- source
- status
- destination xyz + label
- issued / started / completed times
- last outcome / reason
- remaining distance snapshot

## In-game testable command surfaces

### Quick command radial

New slice:

- `Move`

It queues a designated test destination near the player:

- `TEST EAST 6`
- `TEST WEST 6`
- `TEST SOUTH 6`
- `TEST NORTH 6`

The farthest valid candidate from the shell is chosen so movement is visually obvious.

### Debug menu

New direct helper:

- `Command Nearest NPC To Test Destination`

## TEST 01-04 flow

The old start/continue automation has been replaced in the menu with numbered steps:

- `TEST 01 - Spawn Baseline`
- `TEST 02 - Command Walk`
- `TEST 03 - Capture Walk`
- `TEST 04 - Return Capture`
- `TEST STATUS - Dump Current`
- `TEST RESET - Clear State`

All human checkpoints now use short ASCII speech-bubble prompts so they remain readable in-game.

The prompts explicitly ask the tester to check:

- appearance stability
- posture / human-vs-zombie movement read
- audio impression
- destination walk success / failure
- return-path hostile reversion

## Observability added

Debug/status output now exposes:

- shell mode
- movement permissions
- command kind / status
- destination coordinates + label
- command timing / result fields

Main updated surfaces:

- command panel
- movement/audio dump
- record summary dump
- actor debug line
