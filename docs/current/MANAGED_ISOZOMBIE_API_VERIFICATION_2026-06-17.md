# Managed IsoZombie API Verification - 2026-06-17

## Purpose

This note records the local API and reference-mod evidence used for the
post-Bandits independent carrier repair pass.

The immediate issue was that the independent `isozombie` carrier regressed to
zombie presentation and poor/no movement after the Bandits2 runtime dependency
was removed.

## Local Tooling

- Installed JDK: Azul Zulu 25.0.3, user-local.
- JDK home:
  `/Users/sean/Library/Java/JavaVirtualMachines/zulu25.34.17-ca-jdk25.0.3-macosx_aarch64/Contents/Home`
- Game jar inspected:
  `/Users/sean/Library/Application Support/Steam/steamapps/common/ProjectZomboid/Project Zomboid.app/Contents/Java/projectzomboid.jar`
- Verification command family:
  `javap -classpath "$PZJAR" -public <class>`

## Confirmed Public API

`zombie.characters.IsoZombie` exposes:

- `pathToLocationF(float, float, float)`
- `setWalkType(String)`
- `setTarget(IsoMovingObject)`
- `setTargetSeenTime(float)`
- `setUseless(boolean)`
- `setCanWalk(boolean)`
- `setNoTeeth(boolean)`
- `clearAggroList()`
- `getHumanVisual()`
- `getItemVisuals()`
- `dressInRandomOutfit()`
- `dressInNamedOutfit(String)`

`zombie.characters.IsoGameCharacter` exposes:

- `getEmitter()`
- `resetModel()`
- `resetModelNextFrame()`
- `setHealth(float)`
- `setPrimaryHandItem(InventoryItem)`
- `setSecondaryHandItem(InventoryItem)`
- `setWornItem(...)`
- `onWornItemsChanged()`
- `setAttachedItem(String, InventoryItem)`
- `clearAttachedItems()`
- `StopAllActionQueue()`
- `setMoving(boolean)`
- `setPath2(Path)`
- `getPathFindBehavior2()`
- `setAvoidDamage(boolean)`
- `setVariable(String, String|boolean|float)`
- `clearVariable(String)`
- `resetEquippedHandsModels()`

`zombie.pathfind.PathFindBehavior2` exposes:

- `pathToLocation(int, int, int)`
- `pathToLocationF(float, float, float)`
- `cancel()`
- `reset()`
- `update()`
- `isMovingUsingPathFind()`

`HumanVisual` / `ItemVisual` expose the visual APIs needed for direct human
projection:

- `HumanVisual:setSkinTextureName(String)`
- `HumanVisual:setHairModel(String)`
- `HumanVisual:setBeardModel(String)`
- `HumanVisual:removeBlood()`
- `HumanVisual:removeDirt()`
- `ItemVisual.new()`
- `ItemVisual:setItemType(String)`
- `ItemVisual:setClothingItemName(String)`
- `ItemVisuals:add(ItemVisual)`
- `ItemVisuals:clear()`

## Key Difference Confirmed

Vanilla zombie pathfind AnimSets only define zombie walk/sprint names such as
`1`, `2`, `sprint1`, etc.

Bandits succeeds with `setWalkType("Walk")`, `setWalkType("Run")`, and
`setWalkType("SneakWalk")` because it ships its own matching zombie pathfind
AnimSet nodes. Those string values are not vanilla carrier values.

Therefore the independent LWN carrier must not use `Walk`, `Run`, or
`SneakWalk` unless LWN itself provides matching AnimSets.

## Implementation Decision

- Added LWN-owned `pathfind` and `walktoward` AnimSet nodes:
  - `LWNWalk`
  - `LWNRun`
  - `LWNSprint`
  - `LWNCrouchWalk`
  - `LWNCrouchRun`
- Updated carrier movement profiles to use those LWN names.
- Added a vanilla walktype fallback after no-progress stalls.
- Changed path starts to prefer `PathFindBehavior2:pathToLocationF(...)` and
  immediately call `update()` once.
- Reworked fallback clothing presentation to use `ItemVisuals` directly instead
  of creating inventory items.
- Forced human skin names to `MaleBody01` / `FemaleBody01` when the shell still
  reports a zombie/non-human skin.
- Tightened follow formation distances so companions trail closer.

## Important Constraint

This repair borrows the implementation idea of explicit visual and locomotion
projection, but it does not copy Bandits source files or assets and does not
restore a Bandits runtime dependency.
