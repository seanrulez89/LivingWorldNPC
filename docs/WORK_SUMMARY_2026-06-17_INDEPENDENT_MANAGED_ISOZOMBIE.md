# Work Summary - Independent Managed IsoZombie Repair

Date: 2026-06-17

Branch created for this line of work:

```text
feature/independent-managed-isozombie-carrier
```

## Context

The project had just removed the Bandits2 runtime dependency and moved the
default companion path back to LWN's own managed `IsoZombie` carrier.

The first post-removal manual test exposed severe regressions:

- companions visually reverted to ordinary zombies
- movement could freeze or fail
- hostile-looking zombie shell behavior returned
- item transfer partially worked, but NPC inventory inspection and presentation
  still needed stronger evidence

The main engineering question was why Bandits could make an `IsoZombie` shell
look and move like a human while the independent LWN carrier could not.

## Verification Work

Installed a local JDK so the game jar could be inspected directly instead of
guessing at API names.

JDK installed:

```text
/Users/sean/Library/Java/JavaVirtualMachines/zulu25.34.17-ca-jdk25.0.3-macosx_aarch64/Contents/Home
```

Game jar inspected:

```text
/Users/sean/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/projectzomboid.jar
```

Confirmed public APIs with `javap`:

- `IsoZombie:setWalkType(String)`
- `IsoZombie:pathToLocationF(float, float, float)`
- `IsoZombie:clearAggroList()`
- `IsoZombie:setUseless(boolean)`
- `IsoZombie:setCanWalk(boolean)`
- `IsoGameCharacter:getPathFindBehavior2()`
- `PathFindBehavior2:pathToLocationF(float, float, float)`
- `PathFindBehavior2:update()`
- `HumanVisual:setSkinTextureName(String)`
- `ItemVisual.new()`
- `ItemVisual:setItemType(String)`
- `ItemVisual:setClothingItemName(String)`
- `ItemVisuals:add(ItemVisual)`

Also compared local vanilla animation files and the installed Bandits mod files.
The important finding:

- Vanilla zombie AnimSets do not define Bandits-style `Walk`, `Run`, or
  `SneakWalk` as valid `zombieWalkType` values.
- Bandits succeeds with those names because it ships matching AnimSet nodes.
- Therefore LWN must provide its own matching AnimSet nodes or use vanilla
  values only.

Detailed API evidence is recorded in:

```text
docs/MANAGED_ISOZOMBIE_API_VERIFICATION_2026-06-17.md
```

## Implementation Summary

### 1. LWN-owned locomotion AnimSets

Added LWN-owned zombie AnimSet nodes for both pathfinding and walk-toward states:

```text
42/media/AnimSets/zombie/pathfind/LWNWalk.xml
42/media/AnimSets/zombie/pathfind/LWNRun.xml
42/media/AnimSets/zombie/pathfind/LWNSprint.xml
42/media/AnimSets/zombie/pathfind/LWNCrouchWalk.xml
42/media/AnimSets/zombie/pathfind/LWNCrouchRun.xml
42/media/AnimSets/zombie/walktoward/LWNWalk.xml
42/media/AnimSets/zombie/walktoward/LWNRun.xml
42/media/AnimSets/zombie/walktoward/LWNSprint.xml
42/media/AnimSets/zombie/walktoward/LWNCrouchWalk.xml
42/media/AnimSets/zombie/walktoward/LWNCrouchRun.xml
```

These are original LWN nodes that reference vanilla Bob animations. They do not
copy Bandits XML files or restore a Bandits dependency.

### 2. Carrier movement repair

Updated:

```text
42/media/lua/client/35_LWN_Carrier_IsoZombie.lua
```

Key changes:

- replaced `Walk`, `Run`, and `SneakWalk` with LWN-specific walktype names
- tightened follow formation distances so companions stay closer
- made path starts prefer `PathFindBehavior2:pathToLocationF(...)`
- call `PathFindBehavior2:update()` immediately after starting a path
- added a vanilla walktype fallback after no-progress stalls
- kept command state and canonical records as the authority

Expected effect:

- less freezing when moving
- better follow behavior
- clearer logs if the custom AnimSet path still fails

### 3. Visual projection repair

Updated:

```text
42/media/lua/client/23_LWN_ActorFactory.lua
```

Key changes:

- force baseline human skin to `MaleBody01` or `FemaleBody01` when the shell is
  still carrying zombie/non-human skin data
- remove blood and dirt from the baseline human visual
- project fallback shirt, pants, and shoes via `ItemVisuals`
- do not create real inventory clothing items for baseline presentation
- reapply fallback visuals after descriptor materialization so the descriptor
  pass cannot immediately erase the visual layer

Expected effect:

- stronger chance that managed `IsoZombie` shells display as human-like actors
- no fake clothing items appear in NPC inventory merely because baseline visuals
  were applied

### 4. Appearance repair loop

Updated the carrier sync path so an appearance failure no longer passes just
because a previous "applied" flag existed.

The sync path can now attempt a limited appearance repair when the truth probe
still reports an incomplete human visual state.

Relevant log markers:

```text
sync.appearance_repair_retry
runtime_settle_rebuild.ok
runtime_settle_rebuild.failed
```

### 5. Item, inventory, overlay, and logging work already in this snapshot

The current snapshot also includes the companion inventory and evidence logging
work that was developed before the locomotion/appearance repair:

- real item transfer/equip flow from player/world inventory into NPC inventory
- NPC inventory UI file
- overhead name/health overlay file
- inventory-to-record reconciliation
- clearer structured logging for inventory, movement, carrier, and event
  adapter evidence

Those files are part of the same stabilization milestone because manual testing
depends on seeing whether items really moved and whether health/presentation
state can be inspected after the session.

## Important Non-Goals

This work does not attempt to:

- make `IsoZombie` a true `IsoPlayer`
- reintroduce Bandits2 as a dependency
- copy Bandits source or assets
- solve full combat quality, long-term AI, vehicles, dialogue, wounds, or
  persistent autonomous schedules

The purpose is narrower: restore the independent carrier to a usable baseline
for continued manual testing.

## Validation Performed

Passed:

```bash
bash scripts/validate-mac.sh
git diff --check
xmllint --noout 42/media/AnimSets/zombie/pathfind/*.xml 42/media/AnimSets/zombie/walktoward/*.xml
```

`validate-mac.sh` includes Lua syntax checks for all runtime Lua files.

## Branch Decision

The previous active branch was:

```text
spike/bandits-visual-probe-v1
```

That name no longer describes the work. It also risks confusing future agents
because the current direction is explicitly independent from Bandits runtime
execution.

Created the new branch:

```text
feature/independent-managed-isozombie-carrier
```

The old branch is preserved. The new branch starts from the same history and is
the correct branch for the independent carrier stabilization line.

## Next Manual Test Focus

Run with Bandits2 disabled if possible.

Recommended test order:

1. Spawn one aggressive and one passive companion.
2. Confirm visual state: human-like body, clothing, name, health bar position.
3. Issue follow, wait, and right-click move commands.
4. Watch for freezing, zombie shamble presentation, or attacking-player intent.
5. Transfer a real item from player inventory and confirm it appears in NPC
   inventory.
6. Let ordinary zombies attack the NPC and confirm health bar/log health changes.
7. End the game and inspect logs.

Important log markers to check:

```text
carrier=isozombie
LWNWalk
LWNRun
LWNSprint
LWNCrouchWalk
LWNCrouchRun
animset_fallback
sync.appearance_repair_retry
fail_worn_and_item_visuals_empty
fail_overwritten_after_refresh
```

If `animset_fallback` appears, the LWN custom AnimSet path still did not move
the actor reliably and the fallback took over.

If `sync.appearance_repair_retry` repeats and the actor remains zombie-looking,
the next investigation should focus on what overwrites `HumanVisual` /
`ItemVisuals` after carrier sync.
