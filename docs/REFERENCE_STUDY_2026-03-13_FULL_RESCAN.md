# Reference Mods Full Rescan - 2026-03-13

## Scope

This pass re-scans the full `reference_mods/` set from scratch, including newly added materials that were not covered in earlier notes.

Included source folders:

- `reference_mods/1905148104/mods/Superb-Survivors`
- `reference_mods/2980672778/mods/SuperbSurvivorsContinued`
- `reference_mods/3001908830/mods/PZNS_Framework`
- `reference_mods/3049522108/mods/BravensOutfit`
- `reference_mods/3076017350/mods/MyLittleBraven`
- `reference_mods/3088354589/mods/BravensNPCFramework`
- `reference_mods/3243965932/mods/PZNS_NeighbourhoodNpcs`
- `reference_mods/3268487204/mods/Bandits`
- `reference_mods/3397396843/mods/KnoxEventExpanded`
- `reference_mods/3397396843/mods/KnoxEventExpandedLegacy`
- `reference_mods/3403180543/mods/BanditsWeekOne`
- `reference_mods/3469292499/mods/BanditsCreator`

Focus areas for each reference:

- structure and module boundaries
- key entrypoints
- actor or NPC creation path
- visual or presentation pipeline
- death, corpse, and reanimation handling
- cleanup or remove handling
- context menu and targeting
- canonical state management
- direct Build 42 value versus portability risk

## Comparison Matrix

| Source folder | Era | Primary world carrier | Canonical state tendency | Strongest reusable lesson | Highest portability risk |
| --- | --- | --- | --- | --- | --- |
| `1905148104/mods/Superb-Survivors` | Build 41 | `IsoPlayer` | Split across manager tables, save files, and actor `modData` | Human embodiment needs explicit post-spawn or post-load visual rebuild | Tick-heavy lifecycle and hard actor deletion |
| `2980672778/mods/SuperbSurvivorsContinued` | Build 41 | `IsoPlayer` | Same split model with clearer folders | Better separation of spawn, data, and UI modules | Same Build 41 workaround debt as original |
| `3001908830/mods/PZNS_Framework` | Build 41 | `IsoPlayer` plus wrapper record | Strong explicit NPC record in `ModData` | Canonical NPC record can outlive embodied actor | Save-file coupling and ghost unload tricks |
| `3049522108/mods/BravensOutfit` | Build 41-era support pack | none | n/a | Keep appearance assets separate from NPC runtime | No lifecycle guidance |
| `3076017350/mods/MyLittleBraven` | Build 41 | `IsoPlayer` via Braven framework | Thin companion data table | Stale-target fallback is explicit and practical | Invisibility, no-clip, and instant respawn hacks |
| `3088354589/mods/BravensNPCFramework` | Build 41 | `IsoPlayer` | Runtime-object centric | Small modular companion framework layout | Core runtime state lives too close to actor hacks |
| `3243965932/mods/PZNS_NeighbourhoodNpcs` | Build 41 | PZNS `IsoPlayer` wrapper | Persistent spawn registry plus PZNS save path | Spawn policy can live above framework core | More periodic spawn logic and save assumptions |
| `3268487204/mods/Bandits` | Build 42 | `IsoZombie` with human visuals | Brain data in clustered global `ModData` | Carrier and canonical brain should be separate | Human `IsoPlayer` bugs do not map 1:1 |
| `3397396843/mods/KnoxEventExpanded` | Build 42 | `IsoNpcPlayer` and `metaNpc` via external classes | Class-backed meta model | Rich job, zone, and faction UX on top of engine-level NPC API | Depends on replaced class files not present in repo |
| `3397396843/mods/KnoxEventExpandedLegacy` | Build 42 legacy | `IsoNpcPlayer` and `metaNpc` via external classes | Same as above | Same zone and schedule ideas, older compatibility target | Same external class dependency plus legacy divergence |
| `3403180543/mods/BanditsWeekOne` | Build 42 | Bandits zombie carrier plus scenario systems | Scenario `ModData` over carrier state | Keep scenario or population layer above core carrier runtime | Cleanup is aggressive and event-driven |
| `3469292499/mods/BanditsCreator` | Build 42 | `IsoPlayer` preview models only | Editor config data | Preview actors must stay isolated from gameplay actors | Invisible ghost previews are not safe world-runtime patterns |

## Per Reference Notes

### `reference_mods/1905148104/mods/Superb-Survivors`

- Structure:
  - Core runtime is concentrated in `media/lua/client/3_Other/SuperSurvivor.lua`, `SuperSurvivorManager.lua`, `SuperSurvivorsMod.lua`, and `SuperSurvivorUpdate.lua`.
  - UI and targeting live in `media/lua/client/5_UI/SuperSurvivorsContextMenu.lua`.
- Key entrypoints:
  - `Events.OnGameStart.Add(SuperSurvivorsInit)`
  - `Events.LoadGridsquare.Add(SuperSurvivorsLoadGridsquare)`
  - `Events.OnCreatePlayer.Add(SSCreatePlayerHandle)`
  - `Events.OnCharacterDeath.Add(SuperSurvivorOnDeath)`
  - `Events.OnFillWorldObjectContextMenu.Add(SurvivorsFillWorldObjectContextMenu)`
- Actor or NPC creation:
  - `SuperSurvivor:spawnPlayer()` creates a `SurvivorFactory.CreateSurvivor(...)` descriptor and then `IsoPlayer.new(...)`.
  - The actor is marked with `setNPC(true)`, `setBlockMovement(true)`, and `setSceneCulled(false)`.
- Visual or presentation:
  - Spawn itself is not enough. Clothing and visuals are rebuilt later through `WearThis()`, `setWornItem(...)`, `initSpritePartsEmpty()`, `triggerEvent("OnClothingUpdated", self.player)`, and preset visual calls such as `getHumanVisual():setHairModel(...)`.
  - Name display is handled with `TextDrawObject`.
- Death, corpse, reanimation:
  - `OnCharacterDeath` is mostly bookkeeping-oriented. It removes survivor references from manager structures.
  - There is no clean corpse-state contract. Death and embodied cleanup are loosely coupled.
- Cleanup or remove:
  - Hard teardown is common. `self.player:removeFromWorld()` and `self.player:removeFromSquare()` are called directly.
  - Save files also participate in lifecycle, which increases coupling between actor presence and persistent state.
- Context menu or targeting:
  - Context menu actions are actor-centric and use the live object at click time.
  - Combat and follow logic repeatedly reach through `getModData().ID`, but many short-lived decisions still rely on direct actor refs.
- Canonical state:
  - State is fragmented across manager tables, save files, and `IsoPlayer:getModData()`.
  - The embodied actor is not treated as a mere cache.
- Build 42 note:
  - Worth learning: explicit post-spawn visual reconstruction for human actors.
  - Risky to copy: hard delete patterns, save-file ownership, and tick-heavy lifecycle spread.

### `reference_mods/2980672778/mods/SuperbSurvivorsContinued`

- Structure:
  - Clearer folders than original Superb Survivors: `03_Core`, `04_DataManagement`, `07_Spawning`, `08_UI`.
- Key entrypoints:
  - `Events.LoadGridsquare.Add(SuperSurvivorsLoadGridsquare)`
  - `Events.OnCreatePlayer.Add(SSCreatePlayerHandle)`
  - `Events.OnGameStart.Add(SuperSurvivorsInit)`
  - `Events.OnCharacterDeath.Add(SuperSurvivorOnDeath)`
  - `Events.OnFillWorldObjectContextMenu.Add(SurvivorsFillWorldObjectContextMenu)`
- Actor or NPC creation:
  - `SuperSurvivor:spawnPlayer()` still uses `SurvivorFactory.CreateSurvivor(...)` and `IsoPlayer.new(...)`.
  - `newSurvivor()` wraps the actor with a Lua-side survivor object and a `TextDrawObject`.
- Visual or presentation:
  - Same overall pattern as original: spawn first, then equip, then force clothing or sprite refresh.
  - The modular split makes visual and spawn code easier to isolate during analysis.
- Death, corpse, reanimation:
  - Death remains mostly a manager cleanup event.
  - Corpse behavior is still not first-class architecture.
- Cleanup or remove:
  - Uses direct `removeFromWorld()` and `removeFromSquare()` in the core survivor object.
  - The underlying teardown model remains aggressive.
- Context menu or targeting:
  - Cleaner than the original mod, but still assumes a live `IsoPlayer` actor is the primary target surface.
- Canonical state:
  - Improved module boundaries do not change the underlying state split. Manager, actor `modData`, and save state still overlap.
- Build 42 note:
  - Worth learning: more maintainable module layout around spawn, update, and UI.
  - Risky to copy: same Build 41 embodiment and deletion assumptions as original Superb Survivors.

### `reference_mods/3001908830/mods/PZNS_Framework`

- Structure:
  - Framework-style layout with explicit manager, utils, orders, AI, context menu, and event modules.
  - Key folders are `02_mod_utils`, `04_data_management`, `08_mod_contextmenu`, and `11_events_spawning`.
- Key entrypoints:
  - `Events.OnInitGlobalModData.Add(PZNS_GetSandboxOptions)`
  - `Events.OnGameStart.Add(PZNS_UtilsDataNPCs.PZNS_InitLoadNPCsData)`
  - `Events.OnFillWorldObjectContextMenu.Add(PZNS_ContextMenu.PZNS_OnFillWorldObjectContextMenu)`
  - `Events.EveryOneMinute.Add(PZNS_WorldUtils.PZNS_SpawnNPCIfSquareIsLoaded)`
- Actor or NPC creation:
  - `PZNS_NPCsManager.createNPCSurvivor()` creates a wrapper record and optionally an `IsoPlayer`.
  - `createIsoPlayer()` sets `survivorID` into actor `modData`, applies optional outfit, marks NPC, and returns the actor plus square Z.
- Visual or presentation:
  - Clothing and weapons are applied with explicit utility functions such as `PZNS_AddEquipClothingNPCSurvivor()` and `PZNS_AddEquipWeaponNPCSurvivor()`.
  - Hair, beard, skin color, and skin texture are set through `getHumanVisual()`.
  - `TextDrawObject` is attached to the wrapper record, not used as standalone canonical state.
- Death, corpse, reanimation:
  - Corpse-related jobs exist, but there is no especially strong human death pipeline in the reference.
  - The strongest lesson is not corpse behavior itself, but state survival outside the actor.
- Cleanup or remove:
  - `deleteActiveNPCBySurvivorID()` can still hard-remove actors and save files.
  - More interesting is `PZNS_WorldUtils.PZNS_SpawnNPCIfSquareIsLoaded()`: when offscreen, the framework saves state, marks ghost-like behavior, swaps to a nil job, and drops the runtime actor pointer from the canonical record.
- Context menu or targeting:
  - `PZNS_ContextMenu.PZNS_OnFillWorldObjectContextMenu()` builds a framework root menu and delegates to invite, order, job, inventory, and info modules.
  - This is one of the cleaner examples of keeping interaction features modular.
- Canonical state:
  - Best Build 41 example in the reference set.
  - `ModData.getOrCreate("PZNS_ActiveNPCs")` is the primary registry.
  - `npcSurvivor.npcIsoPlayerObject` is explicitly a runtime field, not the only state owner.
- Build 42 note:
  - Worth learning: stable wrapper record, `survivorID`, and actor pointer as cache only.
  - Risky to copy: save-file dependence and ghost or nil-job unload workaround.

### `reference_mods/3243965932/mods/PZNS_NeighbourhoodNpcs`

- Structure:
  - This is a spawn system layered on top of `PZNS_Framework`, not a standalone embodiment framework.
  - Main files are `PZNS_NeighbourhoodNPCs.lua` and `PZNS_WanderingNPCs.lua`.
- Key entrypoints:
  - `Events.OnGameStart.Add(checkIsFrameWorkIsInstalled)`
  - `Events.OnGameStart.Add(initalizeNeighbourhoodNPCsSpawn)`
  - `Events.EveryOneMinute.Add(spawnNeighbourhoodNpcs)`
  - `Events.EveryHours.Add(CleanUpVars)`
  - Wandering NPCs also use hourly periodic spawn logic.
- Actor or NPC creation:
  - Uses `PZNS_NPCsManager.createNPCSurvivor(...)` with generated `survivorID` strings.
  - Spawn policy is cell-based and building-based, using `ModData.getOrCreate("PZNS_NeighbourhoodNPCs1")` to track used cells and spawn locations.
- Visual or presentation:
  - Defers appearance and gear to preset helpers such as `PZNS_NeighbourhoodNPCsPresetsOutfits.useOutfitRandom(...)`.
  - Hostile spawns recolor name text via `textObject:setDefaultColors(...)`.
- Death, corpse, reanimation:
  - Not a strong source for corpse handling.
  - It inherits whatever the underlying PZNS runtime can do.
- Cleanup or remove:
  - Cleanup is mostly spawn-policy cleanup, not actor teardown. Used spawn locations are reset hourly.
  - Because it saves through PZNS, spawned NPCs are intended to persist.
- Context menu or targeting:
  - No new major context-menu model beyond the base PZNS framework.
- Canonical state:
  - Important as a layering lesson.
  - Spawn policy data belongs in its own `ModData` area and sits above the framework's canonical NPC registry.
- Build 42 note:
  - Worth learning: keep population or spawn policy above core runtime state.
  - Risky to copy: periodic spawn loops and Build 41 persistence assumptions still inherit PZNS constraints.

### `reference_mods/3049522108/mods/BravensOutfit`

- Structure:
  - Asset pack only. Files are clothing XML, script definitions, and textures.
- Key entrypoints:
  - None in the NPC runtime sense.
- Actor or NPC creation:
  - None.
- Visual or presentation:
  - Strong example of keeping outfit content outside runtime logic.
- Death, corpse, reanimation:
  - None.
- Cleanup or remove:
  - None.
- Context menu or targeting:
  - None.
- Canonical state:
  - Not applicable.
- Build 42 note:
  - Worth learning: keep appearance assets modular.
  - Risky to copy: nothing runtime-related here, so it is not a lifecycle reference.

### `reference_mods/3088354589/mods/BravensNPCFramework`

- Structure:
  - Companion-oriented modules split by behavior: movement, health, attack, orders, speech, and name display.
- Key entrypoints:
  - Tick-driven modules register directly with `Events.OnTick`.
  - Core lifecycle is distributed across module-level managers rather than a central state machine.
- Actor or NPC creation:
  - Respawn path uses `IsoPlayer.new(getWorld():getCell(), cachedAesthetics, ...)` in `BB_MyLittleMovement.lua`.
  - The framework caches descriptor and inventory from the current NPC and reconstructs a fresh actor near the player.
- Visual or presentation:
  - Name tags use `TextDrawObject`.
  - Visual continuity relies on cached descriptor reuse rather than an explicit canonical appearance record.
- Death, corpse, reanimation:
  - `BB_MyLittleHealth.lua` handles "essential" state by hiding and disabling the actor before real death.
  - This avoids ordinary corpse behavior instead of defining it.
- Cleanup or remove:
  - `onCharacterDeath` in health module saves data and immediately calls `removeFromWorld()` and `removeFromSquare()`.
  - Movement module also toggles invisibility during vehicle state and teleport-style corrections.
- Context menu or targeting:
  - Interaction is companion-focused and actor-centric.
  - Runtime target correction exists, but the framework remains built around a live actor.
- Canonical state:
  - Better than pure actor-only logic, but still heavily actor-driven.
  - The data table is not a clean offscreen simulation authority in the PZNS sense.
- Build 42 note:
  - Worth learning: modular behavior slices and explicit stale-target fallback.
  - Risky to copy: invisibility, no-clip, and removal hacks as normal lifecycle tools.

### `reference_mods/3076017350/mods/MyLittleBraven`

- Structure:
  - Thin content mod on top of `BravensNPCFramework`.
  - Main logic sits in `BB_MyLittleBraven_Main.lua`.
- Key entrypoints:
  - `Events.OnInitGlobalModData.Add(initModData)`
  - `Events.OnGameStart.Add(onGameStart)`
  - `Events.OnCharacterDeath.Add(onCharacterDeath)`
- Actor or NPC creation:
  - `spawnBraven()` builds a parameter table and calls `BB_NPCFramework.CreateNPC(...)`.
  - Companion-specific modules are subscribed afterward.
- Visual or presentation:
  - Outfit items are added and marked `equippedByBravenNPC = true`.
  - Appearance is content-pack driven through `BravensOutfit`.
- Death, corpse, reanimation:
  - Death is turned into delayed respawn. The mod schedules a new spawn after death rather than treating corpse state as meaningful gameplay state.
- Cleanup or remove:
  - Cleanup is effectively delegated to the underlying Braven framework.
  - The mod itself treats death as a signal to recreate the companion.
- Context menu or targeting:
  - Companion-style rather than population-style.
- Canonical state:
  - ModData is used mostly to remember this one companion and whether first start has occurred.
  - It is not an example of broad canonical NPC simulation.
- Build 42 note:
  - Worth learning: narrow wrapper modules can sit cleanly on top of a framework.
  - Risky to copy: companion-preservation assumptions do not scale to LWN population runtime.

### `reference_mods/3268487204/mods/Bandits`

- Structure:
  - Build 42 runtime split across server spawn, shared brain data, client update, and compatibility layers.
  - Most important files for lifecycle are `BanditServerSpawner.lua`, `Bandit.lua`, `BanditBrain.lua`, `BanditGMD.lua`, `BanditUpdate.lua`, and `BanditZombie.lua`.
- Key entrypoints:
  - `Events.OnInitGlobalModData.Add(initBanditModData)`
  - `Events.OnZombieUpdate.Add(onZombieUpdate)`
  - `Events.OnZombieDead.Add(OnZombieDead)`
  - `Events.OnDeadBodySpawn.Add(OnDeadBodySpawn)`
- Actor or NPC creation:
  - Spawner creates zombie carriers via `BanditCompatibility.AddZombiesInOutfit(...)`.
  - `banditize(...)` turns that carrier into a human-like bandit by attaching brain data and setting bandit variables.
- Visual or presentation:
  - `Bandit.ApplyVisuals()` is a fully explicit visual assembly stage.
  - It clears worn items and item visuals, applies human skin and hair, rebuilds clothing with ordered `ItemVisual` creation, cleans blood and dirt, and resets attached items.
  - This is the clearest Build 42 proof that visual presentation is its own lifecycle phase.
- Death, corpse, reanimation:
  - `OnZombieDead` handles bandit-specific death bookkeeping and deprovisioning.
  - `OnDeadBodySpawn` handles the later corpse moment and notifies the server with corpse coordinates.
  - The two-step event model is the cleanest death versus corpse separation in the reference set.
  - Bandits also explicitly disable reanimation behavior for dead bandits with `setReanim(false)`.
- Cleanup or remove:
  - Runtime caches are aggressively cleared in `BanditZombie` when actors die or become invalid.
  - Bandit death removes the canonical brain from cluster `ModData`, while corpse follow-up happens separately.
- Context menu or targeting:
  - `BanditMenu.lua` is lighter than the Build 41 companion mods, but the runtime targeting model is strong.
  - The update loop explicitly clears invalid targets and handles special cases when current target is no longer alive or visible.
- Canonical state:
  - Best Build 42 state architecture in the set.
  - Canonical brain data lives in clustered global `ModData` via `BanditGMD.lua`.
  - Actor `modData` holds lightweight pointers like `brainId`, while the true logic record lives outside the actor.
- Build 42 note:
  - Worth learning: canonical brain separate from world carrier, staged visuals, and death-body split.
  - Risky to copy: direct implementation details depend on `IsoZombie`, not `IsoPlayer`.

### `reference_mods/3403180543/mods/BanditsWeekOne`

- Structure:
  - Scenario layer built on top of Bandits-style carriers plus its own world scheduler and event systems.
  - Key modules are `BWOGMD.lua`, `BWOScheduler.lua`, `BWOSquareLoader.lua`, `BWOPopControl.lua`, and `BWOEvents.lua`.
- Key entrypoints:
  - `Events.OnInitGlobalModData.Add(InitBWOModData)`
  - Population and scenario systems also run on tick and square-loader hooks.
  - World context debug or spawn options are added with `Events.OnPreFillWorldObjectContextMenu.Add(BWOMenu.WorldContextMenuPre)`.
- Actor or NPC creation:
  - Mostly piggybacks on Bandits carriers and event placement helpers.
  - Also uses hidden `IsoPlayer` preview or driver actors in isolated special cases such as `BWOVehicles.lua`.
- Visual or presentation:
  - Scenario presentation is broader than NPC visuals alone: fake vehicles, effects, ambience, and world objects.
  - Human-like carriers still rely on Bandits-compatible visual assembly and event dressing.
- Death, corpse, reanimation:
  - Uses scenario-side dead-body simulation and corpse cleanup.
  - `BWOPopControl.lua` records `md.reanimateAge`, and square-loader logic tracks or removes corpses using `gmd.DeadBodies`.
  - The mod explicitly warns through data and scheduling that corpse handling is a separate simulation layer.
- Cleanup or remove:
  - Cleanup is aggressive and scenario-driven. Multiple systems directly call `removeFromSquare()` and `removeFromWorld()` for carriers and temporary actors.
  - Population control despawns whole bands of inhabitants or survivors to maintain scenario density.
- Context menu or targeting:
  - More scenario and debug oriented than companion oriented.
  - Targeting often works through Bandits utility functions that resolve locations or actor ids from cached data.
- Canonical state:
  - Global scenario state lives in `ModData.getOrCreate("BanditWeekOne")`.
  - This sits above the carrier runtime and keeps world-story data, dead bodies, objects, and scheduled events separate from any one actor.
- Build 42 note:
  - Worth learning: separate scenario or population control from core actor runtime.
  - Risky to copy: event-driven cleanup is too aggressive for a precise human-NPC lifecycle model.

### `reference_mods/3469292499/mods/BanditsCreator`

- Structure:
  - Tooling or editor mod for Bandits, not a gameplay runtime.
  - Main files are `BanditCreationMain.lua`, `BanditClanMain.lua`, and `BanditMainScreen.lua`.
- Key entrypoints:
  - `Events.OnPreFillWorldObjectContextMenu.Add(BCMenu.WorldContextMenuPre)` opens creator UI.
- Actor or NPC creation:
  - Creates preview `IsoPlayer` models with `IsoPlayer.new(...)`.
  - These preview models are marked `setNPC(true)`, `setGodMod(true)`, `setInvisible(true)`, and `setGhostMode(true)`.
- Visual or presentation:
  - Uses preview actors to drive avatar panels and editor UI.
  - Appearance is manipulated directly through `getHumanVisual()` and worn-item application.
- Death, corpse, reanimation:
  - Not applicable as gameplay lifecycle reference.
- Cleanup or remove:
  - Preview cleanup is explicit and isolated. Models are detached from panels and removed from square and world on screen cleanup.
- Context menu or targeting:
  - Context menu is only a UI launch surface.
- Canonical state:
  - Canonical data is editor configuration for bandit definitions and clan spawn rules, not live actor state.
- Build 42 note:
  - Worth learning: preview or editor actors must stay isolated from world actors.
  - Risky to copy: ghosted invisible preview models must never leak into ordinary gameplay embodiment.

### `reference_mods/3397396843/mods/KnoxEventExpanded`

- Structure:
  - Build 42 NPC stack with large UI, faction, story, schedule, and procgen surface.
  - Important folders are `client/00_UI`, `client/01_Core`, shared preset and faction folders, and story or memory data.
- Key entrypoints:
  - `NpcContextMenu.lua` registers `Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectNpcContextMenu)`.
  - Debug and faction helpers call `KnoxEventNpcAPI.instance:spawnNpc(...)`.
- Actor or NPC creation:
  - Lua does not create the actor directly. It calls external class-backed API such as `KnoxEventNpcAPI.instance:spawnNpc("SurvivorNpc", x, y)`.
  - The runtime works with `IsoNpcPlayer` and `metaNpc`, not plain Lua-wrapped `IsoPlayer`.
- Visual or presentation:
  - `NpcCreationMain.lua` is a full NPC creation UI adapted from character creation.
  - Presentation is rich, but much of the actual embodiment implementation is hidden in external class code.
- Death, corpse, reanimation:
  - Corpse handling appears mostly through job zones and UI language such as corpse clear and corpse dump areas.
  - The Lua part does not expose a full low-level death pipeline in the repo.
- Cleanup or remove:
  - Not enough low-level source is present in Lua alone to treat it as a cleanup implementation reference.
- Context menu or targeting:
  - Strongest area of this mod for LWN learning.
  - Context menu discovers nearby `IsoNpcPlayer`, resolves `metaNpc`, and exposes medical check, talk, inventory, group, debug, and building actions.
- Canonical state:
  - The visible Lua API suggests canonical state lives in `metaNpc`, group, faction, and behavior-tree objects rather than only in the world actor.
  - However, the true implementation is hidden behind replaced class files.
- Build 42 note:
  - Worth learning: rich UX around group orders, schedule panels, corpse zones, and meta-level interaction.
  - Risky to copy: the runtime depends on external class replacement not present in `reference_mods`.

### `reference_mods/3397396843/mods/KnoxEventExpandedLegacy`

- Structure:
  - Legacy branch of the same system, targeting older Build 42 compatibility.
  - Folder layout mirrors the main mod with `00_UI_SP` and older screen paths.
- Key entrypoints:
  - Same overall entrypoint style as non-legacy version, including world context hooks and debug spawn helpers.
- Actor or NPC creation:
  - Same external API pattern: `KnoxEventNpcAPI.instance:spawnNpc(...)`.
- Visual or presentation:
  - Same family of UI, faction, and schedule tooling, but with legacy naming and slightly older screen implementations.
- Death, corpse, reanimation:
  - Same main lesson as the newer branch: corpse-clear and corpse-dump are exposed at the group UX layer.
- Cleanup or remove:
  - Lua-visible cleanup details remain limited because class-backed runtime is not in the repo.
- Context menu or targeting:
  - Same `IsoNpcPlayer` and meta-level interaction pattern as the newer branch.
- Canonical state:
  - Same inference: canonical gameplay state likely lives above the world actor in class-backed meta objects.
- Build 42 note:
  - Worth learning: same schedule and zone UX ideas.
  - Risky to copy: same external dependency, plus additional drift from current Build 42 versions.

## Build 41: Worth Learning vs Dangerous To Port Directly

### Still worth learning from Build 41 references

- `Superb-Survivors` and `SuperbSurvivorsContinued`:
  - Human `IsoPlayer` embodiment usually needs explicit post-spawn visual repair and clothing refresh.
- `PZNS_Framework`:
  - Canonical NPC record in `ModData` should outlive the runtime actor.
- `PZNS_NeighbourhoodNpcs`:
  - Population spawning rules can live in a separate layer above the core NPC runtime.
- `BravensNPCFramework` and `MyLittleBraven`:
  - Small modules can own narrow behavior slices.
  - Runtime targeting needs fallback when target actor is dead or invalid.
- `BravensOutfit`:
  - Asset packs should remain separate from logic and lifecycle code.

### Dangerous to port directly into Build 42

- `Superb-Survivors` and `SuperbSurvivorsContinued`:
  - Save-file ownership, direct world removal, and broad tick-driven lifecycle hooks.
- `PZNS_Framework`:
  - Ghost-mode unload plus dropped actor ref as crash workaround.
  - Save-folder coupling through `IsoPlayer:save()` and `IsoPlayer:load()`.
- `PZNS_NeighbourhoodNpcs`:
  - Periodic cell or building spawners that assume Build 41 persistence behavior.
- `BravensNPCFramework`:
  - Invisibility, no-clip, essential knockdown, and actor recreation as ordinary state transitions.
- `MyLittleBraven`:
  - Death as "delay, then respawn companion" does not generalize to offscreen world populations.

## Cross-Reference Takeaways For LWN

- The cleanest Build 42 state pattern is `Bandits`: canonical data in `ModData`, carrier in world, explicit death-body split.
- The cleanest Build 41 architectural pattern is `PZNS_Framework`: wrapper record owns state, actor is cache.
- The strongest warning pattern is `BravensNPCFramework` plus `MyLittleBraven`: invisibility and emergency deletion solve symptoms while hiding lifecycle faults.
- The strongest UI and targeting inspiration is `KnoxEventExpanded`: meta-level interaction, group tooling, and corpse-zone UX, but only as conceptual reference because implementation lives in missing class files.
- The strongest Build 42 scenario-layer lesson is `BanditsWeekOne`: keep story or population control above core actor runtime and keep that layer from owning embodiment details.
