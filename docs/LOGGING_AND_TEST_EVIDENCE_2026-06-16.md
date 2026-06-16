# Logging and Test Evidence

Date: 2026-06-16

## Purpose

Manual in-game testing is now the primary validation path. Player observation is
still essential, but it can miss fast combat, movement, inventory, and lifecycle
events. LWN therefore keeps two complementary traces:

- existing human-readable `[LWN][...]` lines for quick scanning
- structured `[LWN][Log]` lines for event ordering and field comparison

The structured log is intentionally focused on evidence, not noise. It records
commands, carrier lifecycle, movement mode changes, combat engagement, damage
handling, inventory transfer/equipment, relationship/team changes, and debug
test actions.

## Quick Commands

Read the latest LWN-only console lines:

```bash
bash scripts/read-lwn-log-mac.sh
```

Read more or less history:

```bash
bash scripts/read-lwn-log-mac.sh 1200
```

Filter only structured lines:

```bash
bash scripts/read-lwn-log-mac.sh 1200 "\\[LWN\\]\\[Log\\]"
```

Filter one domain:

```bash
bash scripts/read-lwn-log-mac.sh 1200 "domain=Combat|\\[LWN\\]\\[Combat\\]"
```

The raw file is still:

```text
~/Zomboid/console.txt
```

## Structured Line Shape

Structured lines look like this:

```text
[LWN][Log] | seq=12 | level=info | domain=Command | event=follow_player | hour=4.1200 | npcId=NPC-1 | ...
```

Important fields:

- `seq`: per-session LWN event order
- `domain`: broad subsystem, such as `Command`, `Movement`, `Combat`, `Carrier`,
  `Inventory`, `Social`, `Embodiment`, `Cleanup`, or `Test`
- `event`: specific event name
- `npcId`, `name`, `teamId`, `slot`: identity and squad context
- `command`, `intent`, `status`, `policy`, `reason`: command/runtime decision
- `stance`, `state`, `target`, `health`: combat and survival evidence
- `item`, `slotName`, `source`, `ok`, `detail`: inventory/equipment evidence
- `x`, `y`, `z`, `distance`, `targetDistance`: movement and position evidence

## In-Game Test Notes

When reporting a test, prefer this shape:

```text
1. Spawned aggressive/passive companion at roughly <place>.
2. Issued follow / wait / move / give item / stance change.
3. Observed <visual/audio/behavior>.
4. Zombies/player/NPC attacked or did not attack.
5. Ended test and closed game.
```

The exact timing does not need to be perfect. The structured log provides event
order through `seq`, while the old lines provide detailed legacy context.

## Current Evidence Coverage

Covered now:

- test menu actions and squad spawn readiness/failure
- embodiment stage changes, cleanup state, death latch changes
- Bandits spawn request, async bind, timeout, retire, actor removal, death detect
- command issue, queue replacement, command state changes, and cancellation
- right-click move/follow/wait, stance changes, behavior guideline changes
- item-context transfer/equip requests from inventory or world items, existing
  item equip, declared equipment sync, and missing-real-item cleanup
- combat engagement changes, team defense signals, friendly hit suppression,
  zombie damage acceptance, friendly-hit repair, health sync, unexpected
  auto-heal blocking, and Bandits auto-medical task blocking
- follow locomotion/mode changes, combat pause/resume, stale Bandits task
  cleanup, move task creation, retries, arrival, and failure
- relationship stage and team pressure changes

Not covered yet:

- body-part wounds, infection, and treatment state
- detailed animation graph state beyond Bandits walk type and movement mode
- long-term autonomous behavior choice scoring
- full persisted export of the ring buffer outside ModData/console

## Ring Buffer

`LWN.Log` also stores recent structured entries in `ModData[LWN.Config.ModDataTag].debug.logBuffer`.
This is a bounded in-save buffer controlled by:

```lua
LWN.Config.Logging.MaxBufferEntries
```

The default is 500 entries. Console output remains the primary source after a
game session because it survives game exit in `~/Zomboid/console.txt`.
