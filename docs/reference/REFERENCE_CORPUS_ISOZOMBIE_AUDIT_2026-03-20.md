# Reference corpus audit: IsoZombie-based NPC embodiment

Date: 2026-03-20
Repo: `LivingWorldNPC`
Scope: full `reference_mods/` corpus rescan from scratch, with emphasis on `IsoZombie`-carrier NPC embodiment, human presentation tricks, lifecycle/state handling, and Build 41 -> 42 portability clues.

## Executive verdict

The corpus does **not** show multiple mature `IsoZombie`-NPC implementations. It shows one clear, production-grade line of attack:

- **Bandits** (`reference_mods/3268487204/mods/Bandits/{42.12,42.13,42.15}`) is the only reference that explicitly and systematically uses **`IsoZombie` instances as human-ish bandits**.

Everything else splits into other categories:

- **True NPC / survivor lines built on `IsoPlayer` + `SurvivorDesc`**:
  - `Superb Survivors` and its forks
  - `PZNS_Framework` + add-ons
  - `Braven's NPC Framework`
- **Build 42 simulation / UI / authored-NPC ecosystem references**:
  - `KnoxEventExpanded` / `KnoxEventExpandedLegacy`
- **Support / content references, not embodiment carriers**:
  - `Braven's Outfit`, `My Little Braven`, `Npc Cabin Bases`, `BanditsWeekOne`, `BanditsCreator`

So the strongest reusable breakthrough path for LivingWorldNPC remains:

1. **spawn a real `IsoZombie` shell**,
2. **mark it as a managed NPC surrogate using variables/modData**,
3. **overwrite human-facing visuals/voice/loot/behavior every tick**,
4. **treat the zombie as a custom actor with a separate brain/state layer**, rather than trying to make the engine truly believe it is a base-game human.

That last point matters: the best reference does **not** fully convert the engine's classification from zombie to human. It instead **wins by persistent illusion plus custom control**.

---

## Corpus inventory

Inventory basis:
- `find reference_mods -name mod.info`
- Result: **25 `mod.info` files across 16 workshop-id directories**

### Workshop inventory scanned

1. `1905148104` — `Superb Survivors`
2. `2839582542` — `Superior Survivors Cabin Bases`
3. `2980672778` — `Superb Survivors continued`
4. `3001908830` — `PZNS_Framework`
5. `3001909546` — `PZNS_RosewoodPolice`
6. `3001910188` — `PZNS_AgentWong`
7. `3036260551` — `Superb Survivors continued Batmane`
8. `3049522108` — `Braven's Outfit`
9. `3076017350` — `My Little Braven`
10. `3088354589` — `Braven's NPC Framework`
11. `3231442597` — `Superb Survivors 3 Batmane`
12. `3243965932` — `PZNS_Npc Spawning System`
13. `3268487204` — `Bandits` (`42.12`, `42.13`, `42.15`)
14. `3397396843` — `Knox Event Expanded NPC` + `Knox Event Expanded NPC Legacy`
15. `3403180543` — `Bandits Week One`
16. `3469292499` — `Bandits Creator`

### Carrier classification summary

- **Explicit `IsoZombie` carrier / shell use**
  - `Bandits`
- **Explicit `IsoPlayer` NPC construction**
  - `Superb Survivors`
  - `Superb Survivors Continued`
  - `Superb Survivors Continued Batmane`
  - `Superb Survivors 3 Beta`
  - `PZNS_Framework`
  - `Braven's NPC Framework`
- **NPC-facing Build 42 systems but not evidence of `IsoZombie` shell NPCs in scanned files**
  - `KnoxEventExpanded`
  - `KnoxEventExpandedLegacy`
- **Scenario/content/support references**
  - `PZNS_RosewoodPolice`
  - `PZNS_AgentWong`
  - `PZNS_Npc Spawning System`
  - `BanditsWeekOne`
  - `BanditsCreator`
  - `Braven's Outfit`
  - `My Little Braven`
  - `Npc Cabin Bases`

---

## High-confidence findings by reference

## 1) Bandits — the key IsoZombie embodiment reference

### Why it matters

This is the one reference in the corpus that clearly says the quiet part out loud:

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditZombie.lua:4`
  - `-- consists of IsoZombie instances`

That is the closest thing in the corpus to a direct blueprint for an `IsoZombie`-backed NPC carrier.

### Spawn pipeline: create a zombie first, then "banditize" it

Bandits does **not** construct a human actor and then convert it. It spawns a zombie shell and layers identity/behavior on top.

Evidence:

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/server/BanditServerSpawner.lua:481`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/server/BanditServerSpawner.lua:530`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/server/BanditServerSpawner.lua:563`

Pattern:

```lua
local zombieList = BanditCompatibility.AddZombiesInOutfit(...)
local zombie = zombieList:get(0)
banditize(zombie, bandit, clan, args)
```

Compatibility wrapper:

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditCompatibility.lua:194`

```lua
BanditCompatibility.AddZombiesInOutfit = function(x, y, z, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, isInvulnerable, isSitting, health)
    if getGameVersion() >= 42 then
        zombieList = addZombiesInOutfit(x, y, z, 1, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, isInvulnerable, isSitting, health)
    else
        zombieList = addZombiesInOutfit(x, y, z, 1, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, health)
    end
end
```

### Identity marker: custom variables, not engine reclassification

Bandits distinguishes shell-bandits from normal zombies via custom variables and sidecar brain data.

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditUpdate.lua:164-201`

Key pattern:

```lua
zombie:setNoTeeth(true)
zombie:setVariable("Bandit", true)
zombie:setVariable("LimpSpeed", 0.80)
zombie:setVariable("RunSpeed", 0.65 + ZombRandFloat(0, 0.15))
zombie:setVariable("WalkSpeed", 1.04)
zombie:setVariable("BanditPrimary", "")
zombie:setVariable("BanditSecondary", "")
zombie:setWalkType("Walk")
zombie:setVariable("BanditWalkType", "Walk")
zombie:setVariable("ZombieHitReaction", "Chainsaw")
zombie:setVariable("NoLungeTarget", true)
zombie:getModData().brainId = brain.id
local desc = zombie:getDescriptor()
desc:setVoicePrefix("Bandit")
```

Important implications:

- `setVariable("Bandit", true)` is the core identity flag used throughout the mod.
- `modData.brainId` links the shell to a separate AI/brain object.
- `NoLungeTarget` and `setNoTeeth(true)` are anti-zombie-behavior suppression hacks.
- `ZombieHitReaction = "Chainsaw"` is explicitly documented as a crash workaround:
  - comment: `removes black screen crashes`
  - comment: engine otherwise reaches a moodle-based defense path that zombie objects lack.

That crash workaround is especially valuable because it confirms a deep truth of this approach: **you are living in zombie engine pathways, and must defensively patch around human-only assumptions.**

### Human presentation tricks

Bandits uses **continuous visual overwrite** to make the zombie shell look human-ish.

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/Bandit.lua:80+`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditUpdate.lua:1989-1994`

The update loop explicitly re-applies presentation:

```lua
bandit:setWalkType(bandit:getVariableString("BanditWalkType"))
Bandit.SurpressZombieSounds(bandit)
Bandit.ApplyVisuals(bandit, brain)
```

#### Visual rewrite details

`Bandit.ApplyVisuals` does several important things:

- clears existing item visuals
- clears worn items
- sets sex/body state via `setFemaleEtc`
- sets shell health
- writes skin texture directly
- writes hair / beard models and colors
- reconstructs clothing visuals in body-location order

Evidence:

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/Bandit.lua:80-140`

Key excerpts:

```lua
local banditVisuals = bandit:getHumanVisual()
local itemVisuals = bandit:getItemVisuals()
itemVisuals:clear()
bandit:getWornItems():clear()
bandit:setFemaleEtc(brain.female)
bandit:setHealth(brain.health)
banditVisuals:setSkinTextureName(Bandit.GetSkinTexture(brain.female, brain.skin))
banditVisuals:setHairModel(Bandit.GetHairStyle(brain.female, brain.hairType))
banditVisuals:setBeardModel(beardModel)
banditVisuals:setHairColor(icolor)
banditVisuals:setBeardColor(icolor)
```

Also critical: clothing is applied in a stable body-location order, with a dedicated compatibility table for B41 vs B42 body slots:

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditCompatibility.lua:243+`
- `...:303+`

This is useful because Build 42 body locations expanded substantially (`SCBA`, `Necklace_Long`, `Jersey`, `HandsRight`, `HandsLeft`, armor slots, etc.).

#### Voice suppression / human-like audio

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditCompatibility.lua:218-226`

```lua
BanditCompatibility.SurpressZombieSounds = function(bandit)
    if getGameVersion() >= 42 then
        local desc = bandit:getDescriptor()
        desc:setVoicePrefix("NotAZombie")
    else
        bandit:getEmitter():stopSoundByName("MaleZombieCombined")
        bandit:getEmitter():stopSoundByName("FemaleZombieCombined")
    end
end
```

This is one of the strongest references in the whole corpus for “make the shell be perceived as human rather than zombie.” It doesn’t change actor class; it changes **what the player hears**.

### Lifecycle and caching patterns

Bandits tracks live shell instances aggressively.

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditZombie.lua`

Patterns worth stealing:

- global cache of raw shell instances keyed by zombie ID
- “light caches” for quick per-frame logic
- split caches for bandits vs ordinary zombies
- cleanup on `OnZombieUpdate`, `OnZombieDead`, and periodic `EveryOneMinute`

Examples:

```lua
BanditZombie.Cache
BanditZombie.CacheLight
BanditZombie.CacheLightZ
BanditZombie.CacheLightB
```

and:

```lua
local isBandit = zombie:getVariableBoolean("Bandit")
```

This is a good reference for **shell continuity resolution**, especially if LivingWorldNPC needs to reacquire carriers after streaming / chunk changes.

### AI / state machine strategy

Bandits does not rely on vanilla human AI. It treats the shell as a puppet body for a separate brain/program/task layer.

Evidence surfaces:

- `BanditBrain.Get(zombie)` / `BanditBrain.Update(zombie, brain)`
- `Bandit.SetProgramStage(...)`
- `GenerateTask(...)`
- `ProcessTask(...)`
- custom task locks / action states

Visible in:

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditUpdate.lua`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditPrograms.lua`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/ZombieActions/*`

This supports a strong design conclusion: for `IsoZombie` NPCs, **brain/state probably belongs outside the carrier**.

### Targeting / social perception limits

Bandits never truly makes the shell a vanilla human. It continuously checks things like:

- `instanceof(target, "IsoZombie")`
- `zombie:getVariableBoolean("Bandit")`
- `instanceof(character, "IsoZombie") or instanceof(character, "IsoPlayer")`

Examples:

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditPrograms.lua:111`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditUtils.lua:549-551`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditUpdate.lua:1444-1450`

So the shell remains a zombie in engine taxonomy. Bandits succeeds by teaching its own systems and many interactions to interpret `Bandit=true` as “special zombie acting like a person.”

### Build 41 -> 42 breakage and compatibility clues

Bandits is loaded with concrete portability clues.

#### Signature changes

- `addZombiesInOutfit` got extra B42 parameters:
  - B42: `isInvulnerable`, `isSitting` included
  - wrapped in `BanditCompatibility.AddZombiesInOutfit`

#### Audio / emitter path changes

- B42 uses descriptor voice prefix instead of only stopping zombie sounds by emitter.

#### Muzzle flash breakage

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditCompatibility.lua:157-166`

Comment:

```lua
-- shooter:startMuzzleFlash() -- it does not work in b42 apparently, so here is how to do this now:
```

Fallback is spawning an `IsoLightSource`.

#### New B42 zombie states

- `isReanimatedForGrappleOnly()`
- `isRagdoll()`

Wrapped by compatibility helpers and used in shell cache filtering.

#### Body-location expansion

- large B42/B41 divergence in clothing slot maps.

#### Item API drift

- `instanceItem()` vs `InventoryItemFactory.CreateItem(...)`
- legacy item remapping table in `BanditCompatibility.LegacyItemMap`

### Bottom-line lessons from Bandits

#### Strongest reusable ideas

1. **Spawn naked zombie shells, then fully repaint them**.
2. **Use a durable identity variable** like `Bandit=true` plus `modData.brainId`.
3. **Continuously reassert human presentation** rather than assuming one-time setup sticks.
4. **Suppress zombie behaviors surgically** (`setNoTeeth`, `NoLungeTarget`, voice prefix hacks, walk type override).
5. **Keep AI external to the shell**.
6. **Expect Build 42-specific wrappers everywhere**.

#### Strongest warnings / dead ends

1. This does **not** make the engine truly believe the actor is human.
2. It requires a lot of compatibility glue and repeated visual/state enforcement.
3. It is vulnerable to weird zombie-side engine codepaths and crashy assumptions.
4. It probably works best when your systems explicitly know they are dealing with a “managed zombie shell,” not a real human actor.

---

## 2) Superb Survivors line — important contrast, but not IsoZombie embodiment

References:
- `reference_mods/1905148104/mods/Superb-Survivors/...`
- `reference_mods/2980672778/mods/SuperbSurvivorsContinued/...`
- `reference_mods/3036260551/mods/SuperbSurvivorsContinuedBatmane/...`
- `reference_mods/3231442597/mods/SuperbSurvivors3Beta/...`

### Core construction model

These mods are still very clearly **`IsoPlayer`-based NPCs**.

Representative evidence:

- `reference_mods/1905148104/mods/Superb-Survivors/media/lua/client/3_Other/SuperSurvivor.lua:494-508`
- `reference_mods/2980672778/mods/SuperbSurvivorsContinued/media/lua/client/03_Core/SuperSurvivor.lua:91-112`
- `reference_mods/3231442597/mods/SuperbSurvivors3Beta/media/lua/client/03_Core/SuperSurvivor.lua:97-118`

Pattern:

```lua
local BuddyDesc = SurvivorFactory.CreateSurvivor(nil, isFemale)
local Buddy = IsoPlayer.new(getWorld():getCell(), BuddyDesc, square:getX(), square:getY(), Z)
Buddy:setNPC(true)
```

### Why these still matter

They are useful for:

- `SurvivorFactory.CreateSurvivor(...)`
- `getHumanVisual()` tweaks for skin/hair/beard
- inventory/equipment/task patterns
- companion/follower/group/job logic
- examples of how long-running `IsoPlayer` NPC projects structure AI/tasks

Examples of visual shaping:

- `reference_mods/1905148104/mods/Superb-Survivors/media/lua/client/3_Other/SuperSurvivorPresetSpawns.lua:585-608`
  - `getHumanVisual():setSkinTextureIndex(...)`
  - `setHairModel(...)`
  - `setBeardModel(...)`
  - `setHairColor(...)`

### Why these are weaker for the current spike

They do **not** show a route for making an `IsoZombie` be treated as human.
They show the older, more straightforward “just use a human carrier” strategy.

### Useful contrast clue

`SuperSurvivorSpawnCore.lua` contains a revealing workaround after spawning an NPC:

- `reference_mods/2980672778/mods/SuperbSurvivorsContinued/media/lua/client/07_Spawning/SuperSurvivorSpawnCore.lua:150+`

It removes nearby zombies after spawning a survivor, with the author commenting uncertainty:

```lua
-- Cows: What exactly is happening here?... I don't think I ever seen the zombies get removed on an npc spawn...
```

That is not an `IsoZombie` solution, but it is a nice reminder that **human-carrier NPCs often require special coexistence handling with nearby zombies.**

### Portability verdict

Good for:
- human visual shaping APIs
- task and AI concepts
- `IsoPlayer` lifecycle pain

Not good for:
- `IsoZombie` shell embodiment
- zombie-to-human perception tricks

---

## 3) PZNS_Framework (+ spawning add-ons) — clean IsoPlayer lifecycle reference

References:
- `reference_mods/3001908830/mods/PZNS_Framework/...`
- `reference_mods/3243965932/mods/PZNS_NeighbourhoodNpcs/...`
- plus scenario packs `3001909546`, `3001910188`

### Core model

Again, this line is **IsoPlayer-backed**, but it is valuable because the code is unusually explicit about persistence and respawn.

Evidence:

- `reference_mods/3001908830/mods/PZNS_Framework/media/lua/client/02_mod_utils/PZNS_UtilsDataNPCs.lua:56+`
- `...:126-146`
- `reference_mods/3001908830/mods/PZNS_Framework/media/lua/client/04_data_management/PZNS_NPCsManager.lua:52-77`

Key patterns:

```lua
local survivorDescObject = SurvivorFactory.CreateSurvivor(nil, isFemale)
local npcIsoPlayerObject = IsoPlayer.new(getWorld():getCell(), npcSurvivorDesc, x, y, z)
npcIsoPlayerObject:setNPC(true)
npcIsoPlayerObject:setSceneCulled(false)
npcIsoPlayerObject:load(npcFileName)
npcIsoPlayerObject:save(fileName)
```

### Valuable lifecycle ideas

PZNS is useful for:

- save/load split between modData and actor save files
- placeholder data when actor object is not loaded
- actor validity checks
- culling / spawn / despawn logic
- ghosting when outside loaded area

Examples:

- `PZNS_CreateNPCSurvivorDescObject(...)`
- `PZNS_SpawnNPCFromModData(...)`
- `PZNS_SaveNPCData(...)`
- `PZNS_WorldUtils.spawnNPCIsoPlayer(...)`

This is a strong reference for **continuity architecture**, even if not for zombie-shell embodiment.

### Human visual usage

PZNS manipulates `getHumanVisual()` heavily:

- hair color
- hair model
- skin color
- skin texture index

Examples:

- `reference_mods/3001908830/mods/PZNS_Framework/media/lua/client/02_mod_utils/PZNS_UtilsNPCs.lua:216-253`

### Limitation for the current goal

No evidence in scanned PZNS files that it uses `IsoZombie` as a person shell. It remains squarely in the “construct a real human actor” camp.

---

## 4) Braven's NPC Framework — simple human NPC constructor, useful for presentation API reminders

Reference:
- `reference_mods/3088354589/mods/BravensNPCFramework/media/lua/client/BB_NPCFramework.lua`

### Core model

This is a compact and readable `IsoPlayer` creation example.

Evidence:

```lua
local npcAesthetics = SurvivorFactory.CreateSurvivor(SurvivorType.Neutral, properties.isFemale or false)
npcAesthetics:setForename(...)
npcAesthetics:setSurname(...)
npcAesthetics:dressInNamedOutfit(...)
local npcVisuals = npcAesthetics:getHumanVisual()
npcVisuals:setHairModel(...)
npcVisuals:setHairColor(...)
npcVisuals:setSkinTextureIndex(...)
local npc = IsoPlayer.new(getWorld():getCell(), npcAesthetics, x, y, z)
npc:setSceneCulled(false)
npc:setNPC(true)
```

### Why it matters

Good reminder that some human-facing presentation work can happen **on the descriptor/survivor object before actor construction**.

Potentially reusable idea for zombie shells:
- build a consistent descriptor / visual source-of-truth object first,
- then mirror that onto the live shell.

### Limitation

No `IsoZombie` embodiment. This is purely a human-carrier reference.

---

## 5) KnoxEventExpanded / Legacy — Build 42 NPC ecosystem reference, not evidence of zombie-shell humans

References:
- `reference_mods/3397396843/mods/KnoxEventExpanded/...`
- `reference_mods/3397396843/mods/KnoxEventExpandedLegacy/...`

### What the scan found

The strongest hits were:

- Build 42 UI / character creation code using `desc:getHumanVisual()` extensively
- survival-guide text describing NPC world simulation
- story-layer abstractions like `Zombie:new(...)`, `ZombieTeamEntity:new(...)`

Examples:

- `.../client/OptionScreens/NpcCreationMain.lua`
- `.../shared/Translate/EN/SurvivalGuide_EN.txt`
- `.../shared/02_LuaStories/ZombieStories/...`

The survival guide explicitly describes a broad NPC simulation world:

- `reference_mods/3397396843/mods/KnoxEventExpanded/42/media/lua/shared/Translate/EN/SurvivalGuide_EN.txt`
  - NPCs are distributed across the map
  - follow schedules
  - use relationship / memory systems
  - hostile NPCs exist

### Why it matters

This mod may still be useful as a conceptual reference for:

- Build 42-era NPC simulation UX
- authored NPC creation UIs
- social/memory abstractions

### Limitation

In the scanned evidence, I did **not** find a direct, concrete `IsoZombie`-as-human-shell implementation comparable to Bandits.
The story-layer `Zombie:new(...)` entities look more like simulation/story abstractions than proof of an engine-level human-illusion shell.

---

## 6) BanditsWeekOne / BanditsCreator — supporting Bandits ecosystem, not primary shell-tech sources

References:
- `reference_mods/3403180543/mods/BanditsWeekOne/...`
- `reference_mods/3469292499/mods/BanditsCreator/...`

These belong in the same ecosystem and may be useful later for content/schema examples, but the core embodiment tricks clearly live in main `Bandits`.

---

## 7) Support/content-only references

### Npc Cabin Bases
- `reference_mods/2839582542/mods/Npc Cabin Bases`
- scenario/content support, not shell embodiment tech.

### Braven's Outfit / My Little Braven
- `reference_mods/3049522108`
- `reference_mods/3076017350`
- mostly outfit/content support; `MyLittleBraven` functions as ecosystem support to Braven NPC work, but the shell-construction evidence is in `BravensNPCFramework`.

---

## Cross-reference synthesis

## Which references actually use IsoZombie or related shell ideas?

### Strong yes: explicit IsoZombie shell embodiment

- **Bandits**
  - `BanditZombie.lua` literally documents that its actor collection “consists of `IsoZombie` instances”.
  - spawn path is `addZombiesInOutfit(...)` -> decorate zombie -> manage by custom brain/state.

### Weak / incidental only

- `Superb Survivors` line
  - interacts with zombies as enemies, removes nearby zombies on spawn, checks `instanceof(..., "IsoZombie")`, but does not use zombies as NPC carriers.
- `PZNS`
  - references `IsoZombie` mostly for combat/scan utilities, not embodiment.
- `Braven's NPC Framework`
  - references `IsoZombie` in combat helpers, not as carrier.
- `KnoxEventExpanded`
  - has story/simulation “Zombie” abstractions, but scanned evidence did not prove `IsoZombie` human shells.

## How do refs make entities feel human rather than zombie?

Bandits provides the clearest answer:

1. **Visual surface rewrite**
   - `getHumanVisual()` skin/hair/beard/clothes are overwritten.
2. **Animation/walk override**
   - `setWalkType("Walk")`
   - persistent `BanditWalkType`
3. **Audio suppression / replacement**
   - `desc:setVoicePrefix("Bandit")`
   - later `desc:setVoicePrefix("NotAZombie")` for B42 suppression path
4. **Behavior suppression**
   - `setNoTeeth(true)`
   - `NoLungeTarget = true`
5. **Custom identity and logic**
   - `Bandit=true`
   - `brainId`
   - external task/program state
6. **Loot / social cues**
   - `AddId(...)` adds ID cards / key rings so dead shells read as humans narratively

This is the strongest corpus-supported pattern for “human perception without true human class identity.”

## Strongest candidate breakthrough ideas for LivingWorldNPC

### 1. Managed zombie shell + external brain is the proven path

Bandits strongly supports a carrier split:

- carrier = `IsoZombie`
- identity = custom variable + modData key
- mind = separate brain/program/task tables
- presentation = re-applied every update

That maps well onto a carrier-adapter architecture.

### 2. Human illusion is a maintenance loop, not a one-time conversion

The decisive lesson is not “set the right properties once.”
It is “**reassert the illusion every frame / update slice**.”

Bandits repeatedly does:
- walk type reset
- sound suppression
- visual application
- task/state management

### 3. Descriptor voice prefix is a real B42 lever

`desc:setVoicePrefix("NotAZombie")` / `("Bandit")` is one of the most concrete B42-era tricks in the corpus for reducing zombie feel without changing carrier type.

### 4. Clothing/body slot ordering matters a lot in B42

Bandits’ B42 body-location tables are a high-value reference for any humanized shell outfitting system.

### 5. Use one explicit carrier flag everywhere

`zombie:getVariableBoolean("Bandit")` shows how useful a single engine-visible boolean marker is. LivingWorldNPC should likely keep one canonical managed-shell flag and branch on it everywhere.

## Strongest dead ends / weak bets

### 1. Expecting the engine to truly perceive an IsoZombie as a normal human

Nothing in the corpus shows a robust way to fully reclassify a zombie into a first-class human/NPC actor. Bandits succeeds without doing that.

### 2. Leaning on old Build 41 IsoPlayer NPC frameworks for shell problems

Superb Survivors / PZNS / Braven are good general NPC references, but they are the wrong primary source for the exact `IsoZombie` embodiment question.

### 3. Over-trusting one-time visual setup

Bandits suggests visuals drift / are overwritten / need reapplication. One-shot descriptor dressing is probably insufficient.

### 4. Mixing human-only APIs into zombie carriers casually

The Bandits crash workaround around `ZombieHitReaction` is a warning sign. If a call path assumes player moodles/human state, zombie carriers can blow up in surprising ways.

---

## Build 42 portability assessment

## Overall assessment

**Favorable for an `IsoZombie` shell approach, but only if you stay honest about what the shell is.**

The corpus suggests:

- **Build 42 can support a polished `IsoZombie` surrogate actor**.
- But it requires **compatibility wrappers, defensive coding, and constant presentation control**.
- Build 42 does **not** magically erase the distinction between zombie and human carriers.

## Best B42-positive signals

From Bandits 42.12 / 42.13 / 42.15:

- continued explicit use of zombie shells across multiple B42 point versions
- version-aware wrapper for `addZombiesInOutfit`
- B42-specific handling of voice suppression
- B42 handling of `isReanimatedForGrappleOnly()` and ragdoll states
- B42 clothing/body-location support expanded rather than abandoned

This is good evidence that a serious author found the approach worth maintaining in B42.

## B42 risk signals

- API signatures drifted (`addZombiesInOutfit`, body slots, item instancing, firearm/flash behavior)
- engine-side presentation/FX calls changed (`startMuzzleFlash()` comment says it does not work in B42)
- zombie-side engine states expanded (`ragdoll`, grapple-only reanimation), meaning more shell edge cases
- any human-only API assumption remains a hazard

## Practical portability verdict for LivingWorldNPC

### If goal is:
- **visible embodied agents in world**
- **persistent shell continuity**
- **human-ish appearance**
- **custom social/AI logic**

Then **`IsoZombie` remains a viable B42 carrier**.

### If goal is:
- engine-native human/NPC treatment in every vanilla subsystem
- zero special casing
- clean reuse of all human-only APIs

Then the corpus does **not** support `IsoZombie` as a full replacement for a real human actor.

---

## Concrete takeaways for next LivingWorldNPC experiments

1. **Keep shell identity explicit**
   - mirror Bandits’ `Bandit=true` idea with one LWN-managed-shell variable.
2. **Keep the brain outside the shell**
   - shell only stores stable ID / lookup key.
3. **Reapply presentation repeatedly**
   - visuals, walk type, voice, anti-zombie suppressions.
4. **Prefer compatibility wrappers**
   - especially for spawn signatures, clothing/body slots, B42-only APIs.
5. **Assume zombie internals can hit hostile engine codepaths**
   - gate human-only calls aggressively.
6. **Treat “human-perceived” and “human-classified” as separate goals**
   - the corpus only strongly supports the former.

---

## Quick reference table

### Highest-value references for IsoZombie shell work

- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditZombie.lua`
  - zombie-shell cache architecture
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditUpdate.lua`
  - banditization, shell update loop, anti-zombie suppressions
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/Bandit.lua`
  - human visual rewrite and clothing application
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditCompatibility.lua`
  - B41/B42 wrappers, voice suppression, body-slot maps
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/server/BanditServerSpawner.lua`
  - shell spawn / restore / individual spawn flows

### Useful secondary references

- `reference_mods/3001908830/mods/PZNS_Framework/media/lua/client/02_mod_utils/PZNS_UtilsDataNPCs.lua`
  - persistence / load / save lifecycle architecture
- `reference_mods/3088354589/mods/BravensNPCFramework/media/lua/client/BB_NPCFramework.lua`
  - compact human visual construction flow
- `reference_mods/2980672778/mods/SuperbSurvivorsContinued/media/lua/client/07_Spawning/SuperSurvivorSpawnCore.lua`
  - world coexistence / spawn-area cleanup clue
- `reference_mods/3397396843/mods/KnoxEventExpanded/42/media/lua/shared/Translate/EN/SurvivalGuide_EN.txt`
  - B42 NPC-world simulation framing

---

## Final conclusion

After rescanning the corpus from scratch, the result is pretty crisp:

- **Bandits is the decisive reference** for `IsoZombie`-backed NPC embodiment.
- The other major NPC frameworks in the repo are still primarily **`IsoPlayer` survivor systems**.
- The best corpus-supported strategy is **not** “turn a zombie into a real human,” but rather:
  - **use a zombie shell**,
  - **tag it**,
  - **drive it with external AI**,
  - **continuously repaint and suppress zombie cues**,
  - **special-case systems that must recognize managed shells**.

That is the strongest evidence-backed route toward a robust Build 42 `IsoZombie` embodiment line for LivingWorldNPC.
