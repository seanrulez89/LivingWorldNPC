# LivingWorldNPC SP — Technical Design Document

## 1. Scope and implementation target

This architecture targets **Project Zomboid Build 42 single-player only**. It deliberately excludes multiplayer. The design is built around API surfaces that are directly visible in the current Java modding docs or in shipped/community-documented Lua event layers.

Build 42 note: the official first-party NPC initiative is aimed at later builds, so this mod implements visible humans by combining the exposed `SurvivorDesc` and `IsoPlayer` APIs with a strict data-first embodiment layer. Public Build 42 community work such as PZNS follows the same `IsoPlayer.new(...)` + `setNPC(true)` pattern, which makes it a useful reference for what is practical without engine patching.

### Hard guarantees

1. NPCs do **not** exist as always-active world actors.
2. NPCs are seeded as persistent data records at world creation time.
3. NPC embodiment happens **only** when the player approaches an eligible encounter and the NPC enters the configured activation envelope.
4. The authoritative source of truth is `ModData`, never an embodied actor.
5. Any feature that would require engine patching or modified class files is out of scope.
6. Legacy continuation is implemented as **companion snapshot promotion**, not live body-possession.

### Why this shape

This is the narrowest architecture that still supports the original design goals:

- personality
- motives and goal hierarchies
- memory and causal reactions
- player commands and negotiation
- NPC suggestions
- betrayal and social drama
- backstory and world-story arcs
- language-ready dialogue generation
- continuation after player death

while staying inside a realistic Build 42 SP-only mod envelope.

---

## 2. API surface policy

The implementation is split by evidence level.

### Tier A — official Java docs / stable public surface

Used directly in the runtime design:

- `SurvivorFactory.CreateSurvivor`
- `SurvivorDesc`
- `IsoPlayer(IsoCell, SurvivorDesc, int, int, int)`
- `IsoGameCharacter.setNPC`, `setSceneCulled`
- `ILuaGameCharacter.getMoodles`, `getStats`, `getTraits`, `getInventory`, `getPerkLevel`, `getPathFindBehavior2`, `StartAction`, `StopAllActionQueue`, `Say`, `setDescriptor`
- `PathFindBehavior2.pathToLocation`, `pathToCharacter`, `update`, `cancel`
- `BaseAction`, `LuaTimedAction`
- `ModData.getOrCreate`, `get`, `transmit`, `remove`
- `Translator.getText`, `getTextOrNull`
- UI primitives `UIManager`, `UIElement`, `NewWindow`, `UITextBox2`, `RadialMenu`, `ModalDialog`
- `HaloTextHelper`
- `WorldMarkers` and `WorldMapMarkersV1`
- registries/factories `ProfessionFactory`, `TraitFactory`, `PerkFactory.Perks`, `SurvivorDesc`

### Tier B — shipped/community-documented Lua layer

Used only behind adapter layers:

- `Events.OnNewGame`
- `Events.OnCreateUI`
- `Events.OnCreateSurvivor` (defensive compatibility hook, not the primary embodiment path)
- `Events.OnPlayerDeath`
- `Events.OnFillWorldObjectContextMenu`
- `Events.OnCustomUIKeyPressed`
- `Events.EveryOneMinute`
- `Events.EveryTenMinutes`

Because these hooks are not enumerated in one official Javadoc page, all event names are isolated in `90_LWN_EventAdapter.lua`.

### Tier C — convenience patterns from community code

Used only as implementation hints, never as unguarded hard dependencies:

- `LuaTimedAction.new(...)` constructor style from the classic timed action helper pattern.

If a future Build 42 point release changes constructor exposure, only `20_LWN_ActionRuntime.lua` must be adjusted.

---

## 3. Folder and module layout

```text
42/
  mod.info
  media/
    lua/
      shared/
        00_LWN_Config.lua
        01_LWN_Schema.lua
        02_LWN_Localization.lua
        Translate/
          EN/LWN_EN.txt
          KO/LWN_KO.txt
      client/
        10_LWN_PopulationStore.lua
        11_LWN_PopulationSeeder.lua
        12_LWN_Memory.lua
        13_LWN_Social.lua
        14_LWN_DialogueRealizer.lua
        15_LWN_WorldStory.lua
        16_LWN_GoalSystem.lua
        17_LWN_UtilityAI.lua
        18_LWN_BehaviorTree.lua
        19_LWN_ActionIntents.lua
        20_LWN_ActionRuntime.lua
        21_LWN_Combat.lua
        22_LWN_EncounterDirector.lua
        23_LWN_ActorFactory.lua
        24_LWN_ActorSync.lua
        25_LWN_EmbodimentManager.lua
        26_LWN_UI_ContextMenu.lua
        27_LWN_UI_RadialMenu.lua
        28_LWN_UI_CommandPanel.lua
        29_LWN_UI_DialogueWindow.lua
        30_LWN_Legacy.lua
        90_LWN_EventAdapter.lua
        99_LWN_Bootstrap.lua
common/
```

The numbered filenames are intentional. They reduce ambiguity in Lua load order and make debugging easier.

---

## 4. Canonical data model

The canonical save root lives at:

```lua
ModData.getOrCreate("LWN_SP")
```

### Root layout

```lua
root = {
  version = 1,
  seeded = false,
  nextNpcId = 1,
  npcs = {},             -- [npcId] = NPCRecord
  embodied = {},         -- [npcId] = actor metadata mirror only
  encounters = {},       -- staged encounter state
  worldStory = {},       -- world-story seeds and flags
  legacy = {},           -- continuation candidates and last chosen snapshot
  debug = {},
}
```

### NPCRecord

```lua
NPCRecord = {
  id = "LWN-000001",
  seed = 123456789,
  identity = {
    firstName = "",
    lastName = "",
    female = false,
    ageBucket = "adult",
    profession = "unemployed",
    traitIds = {},
  },
  appearance = {
    outfit = nil,
    persistentOutfit = nil,
  },
  anchor = {
    x = 0, y = 0, z = 0,
    zoneId = nil,
    buildingId = nil,
    roomType = nil,
  },
  embodiment = {
    state = "hidden",   -- hidden|eligible|staged|embodied|cooldown
    actorId = nil,
    lastSeenHour = 0,
    graceUntilHour = 0,
  },
  stats = {
    hunger = 0.0,
    thirst = 0.0,
    fatigue = 0.0,
    boredom = 0.0,
    panic = 0.0,
    fear = 0.0,
    stress = 0.0,
    pain = 0.0,
    drunkenness = 0.0,
    endurance = 1.0,
    morale = 0.5,
    health = 100.0,
  },
  moodles = {},
  perks = {},
  inventory = {
    foodDays = 0.0,
    waterUnits = 0.0,
    meds = 0,
    ammo = 0,
    valuables = 0,
    equipment = {},
  },
  personality = {
    bravery = 0.5,
    empathy = 0.5,
    greed = 0.5,
    discipline = 0.5,
    curiosity = 0.5,
    impulsiveness = 0.5,
    loyalty = 0.5,
    paranoia = 0.5,
    sociability = 0.5,
  },
  motivations = {
    survival = 1.0,
    safety = 0.7,
    belonging = 0.4,
    power = 0.2,
    curiosity = 0.3,
    pleasure = 0.2,
    ideology = 0.1,
  },
  vice = {
    smoker = false,
    drinker = false,
    reader = false,
  },
  relationshipToPlayer = {
    trust = 0.0,
    respect = 0.0,
    fear = 0.0,
    resentment = 0.0,
    attachment = 0.0,
    debt = 0.0,
    loyaltyShift = 0.0,
  },
  memories = {},
  backstory = {
    formerProfession = nil,
    trauma = nil,
    hobby = nil,
    belief = nil,
    secret = nil,
    familyStatus = nil,
  },
  storyArc = {
    type = nil,
    phase = 0,
    clueCount = 0,
    revealFlags = {},
  },
  schedule = {
    activity = "idle_abstract",
    nextHour = 0,
  },
  goals = {
    longTerm = nil,
    shortTerm = nil,
    currentPlan = {},
    currentIntent = nil,
  },
  drama = {
    rivalry = false,
    jealousy = false,
    promiseBroken = false,
    suspectsTheft = false,
    pendingBetrayal = false,
  },
  companion = {
    recruited = false,
    squadRole = nil,
    canContinueAsLegacy = false,
  },
}
```

### Invariants

- Only pure data goes into `NPCRecord`.
- No functions, userdata, or actor references are stored in `ModData`.
- Actor runtime state is rebuilt from `NPCRecord` after load.

---

## 5. Runtime loops

### 5.1 New game bootstrap

1. `OnNewGame` fires.
2. `PopulationSeeder.seedNewWorld(player, square)` creates the hidden population.
3. No NPC is embodied yet.
4. `WorldStory.seed()` creates initial background arcs.
5. The first encounter gates remain closed for a short intro period.

### 5.2 Minute-scale off-screen simulation

Runs from `EveryOneMinute` and `EveryTenMinutes`.

For each non-embodied NPC:

1. drift needs and vice pressure
2. resolve abstract activity (`rest`, `scavenge`, `hide`, `travel_abstract`, `drink`, `read`)
3. advance story arcs
4. evaluate encounter eligibility
5. update drama flags and relationship decay/repair
6. migrate anchor when needed

### 5.3 On-screen update

Runs from `OnTick`, but only for embodied NPCs.

Per embodied NPC:

1. pull actor state into snapshot cache
2. rebuild short-term context
3. update goals
4. score intents with Utility AI
5. tick Behavior Tree
6. submit intents to ActionRuntime
7. resolve combat if threat exists
8. refresh UI if the NPC is selected

### 5.4 Embody/de-embody cycle

1. `EncounterDirector` marks a hidden NPC as `eligible`.
2. `EmbodimentManager` checks distance and activation budget.
3. `ActorFactory` builds `SurvivorDesc`, chooses a safe visible square, then creates an NPC-flagged `IsoPlayer`.
4. `ActorSync` pushes canonical record data into the actor.
5. NPC becomes `embodied`.
6. When the player leaves the despawn envelope and no sticky state is active, `ActorSync` pulls final state, then the runtime actor is cleaned up with `Despawn()` and world-removal guards.

Sticky states include:

- active conversation
- recruited companion status
- active combat
- just-finished interaction cooldown

---

## 6. Encounter architecture

The player starts alone. Hidden NPCs only become encounter candidates after one or more gates are satisfied.

### Global gates

- at least `introLockHours` in-game hours passed
- player travelled beyond `introTravelThreshold`
- or player slept once
- or player visited a strategic building class
- or world-story forced event budget opened

### Candidate scoring

`EncounterDirector` scores hidden NPCs by:

- distance to player anchor
- current story relevance
- biome/zone compatibility
- player state (hungry, injured, exhausted, noisy, trespassing, sleeping rough)
- NPC backstory (nurse, loner, paranoid, looter, resident)
- cooldown from previous encounter

### Encounter archetypes

- cautious scavenger
- barricaded resident
- injured wanderer
- grief survivor
- future companion
- opportunistic robber
- backstory clue carrier
- later-act betrayer / reunion

This keeps the first meeting curated and allows later recurrences.

---

## 7. Embodiment and despawn design

### Activation envelope

The mod intentionally uses a **tile-radius approximation** instead of pixel-accurate screen visibility. That is simpler, deterministic, and cheaper.

Suggested defaults:

- embody radius: 32 tiles
- despawn radius: 44 tiles
- companion despawn radius: 58 tiles
- interaction grace: 0.05 in-game hours

### Actor creation pipeline

1. Create `SurvivorDesc`.
2. Apply name, sex, profession, XP boosts, descriptor personality hints.
3. Pick a solid, free square near the canonical anchor with player-overlap avoidance.
4. Instantiate actor with `IsoPlayer.new(...)`.
5. Mark the actor as NPC, sync clothing/equipment/health, and attach `npcId` in actor modData mirror.
6. Register in `embodied` mirror table.

### Actor destruction pipeline

1. Stop all active actions.
2. Pull inventory/perks/stats summary into canonical record.
3. Clear UI selections if needed.
4. Call cleanup guards (`Despawn`, `removeFromSquare`, `removeFromWorld`) as needed.
5. Return state to `hidden` or short auto-rearm cooldown for companions/debug-spawned records.

---

## 8. AI stack

### 8.1 Motivation layer

Continuous values:

- survival
- safety
- belonging
- power
- curiosity
- pleasure
- ideology

They are not actions by themselves. They bias which goals become active.

### 8.2 Goal layer

Long-term goals:

- stay_alive
- secure_food
- secure_water
- reduce_panic
- gain_trust
- protect_player
- keep_distance
- seek_story_clue
- satisfy_vice
- betray_when_ready

Short-term goals are concrete world-facing subgoals.

### 8.3 Utility layer

Scores candidate intents using:

- stats and moodles
- current long-term goal
- relationship to player
- memories
- backstory triggers
- opportunity and danger
- vice pressure and boredom

### 8.4 Behavior Tree layer

The BT is not global-AI magic. It is an execution expander.

Branches:

- Root
  - HighThreat
    - retreat
    - melee_engage
    - break_contact
    - bandage_self
  - Social
    - approach_for_talk
    - answer_player
    - negotiate_command
    - suggest_action
  - Survival
    - search_food
    - drink
    - rest
  - Story
    - reveal_clue
    - go_to_anchor
  - Idle
    - observe
    - wander_short
    - smoke_or_drink

### 8.5 Why this hybrid matters

Utility alone makes agents twitchy.
Behavior trees alone make them predictable.
Goal + Utility + BT gives:

- stable long-term intent
- reactive short-term choice
- reproducible execution sequences

---

## 9. Action runtime

The runtime owns the mod’s logical action queue.

```lua
IntentQueue = {
  { kind = "move_to", ... },
  { kind = "talk", ... },
  { kind = "loot_container", ... },
  { kind = "eat_food", ... },
  { kind = "attack_melee", ... },
}
```

### Mapping rules

- movement intents -> `PathFindBehavior2`
- time-consuming intents -> `LuaTimedAction`
- interrupt -> `StopAllActionQueue`
- optional chained scheduling -> `QueueAction` if available, otherwise `StartAction`

### Runtime responsibilities

- ensure only one intent starts when actor is idle
- cancel obsolete actions
- prevent duplicate move spam
- detect stalled pathfinding
- enforce combat interrupts
- report completion/failure back into AI state

---

## 10. Combat design

Combat is intentionally conservative in v1.

### Supported

- threat detection
- melee approach/attack/retreat
- panic-based disengage
- simple target prioritisation
- relationship-aware protection of player

### Deferred

- advanced firearm tactics
- vehicle combat
- faction-scale combined-arms behaviors

### Threat inputs

- nearby zombies count
- hostile human count
- own weapon class
- current health
- pain / panic / endurance
- distance to target

### Tactical outputs

- engage
- kite short
- retreat
- break line and regroup
- bandage self

Combat also emits memory events:

- `player_saved_me`
- `player_abandoned_me`
- `we_fought_together`
- `player_hit_me`
- `i_hit_player`

These feed relationship and drama.

---

## 11. Social system

The player never issues a command as a guaranteed imperative. It is always evaluated.

### Command evaluation factors

- current need pressure
- current panic and pain
- trust/respect/fear/resentment
- personality
- promise debt
- perceived risk
- current long-term goal

### Responses

- accept
- refuse
- counteroffer
- delay
- topic_shift
- suggest_alternative

This allows the NPC to feel causally grounded rather than robotic.

---

## 12. Dialogue and localization

The system stores **semantic dialogue intents**, not raw sentences.

Example:

```lua
{
  intent = "refuse_command",
  reason = "hunger",
  tone = "weary",
  targetNpcId = "LWN-000014",
}
```

The realizer maps that to localization keys, such as:

- `LWN_Dialogue_Refuse_Hunger_Weary`
- `LWN_Dialogue_CounterOffer_SearchFood`
- `LWN_Dialogue_Suggestion_RestSoon`

This keeps the save file language-neutral and translation-friendly.

---

## 13. UI/UX design

### Core principle

High-frequency actions should be low-friction.
Low-frequency inspection should be persistent but optional.

### Entry points

1. **World context menu** on or near an embodied NPC.
2. **Quick radial menu** for frequent orders.
3. **Persistent command panel** for state inspection and long-form interaction.
4. **Dialogue window** for story/personal topics.

### Recommended flow

- Right-click NPC -> `LWN > [Name]`
  - Talk
  - Quick Command
  - Open Panel
  - Trade / Give Item
  - Leave / Dismiss

If multiple NPCs are under the cursor square, show a target picker first.

### Why this is the best SP UX here

- It uses the existing context-menu habit players already know.
- Radial menus reduce travel time for repetitive commands.
- A persistent panel makes relationship/state legible.
- It avoids a fragile free-text parser.

### Suggested quick radial slices

- Follow
- Wait
- Guard Here
- Search Nearby
- Retreat
- Attack My Target
- Tend Me
- Open Panel

### Suggestion UX

When the NPC proposes something:

- `Say()` for the voice line
- `HaloTextHelper` for quick approval/decline feedback
- `WorldMarkers` or `WorldMapMarkersV1` for map/location hints

---

## 14. Drama and world-story

### Drama engine

Local social drama events:

- promise broken
- loot dispute
- jealousy
- rescue debt
- trespass anger
- cowardice witnessed
- leadership challenge
- theft suspicion

Drama changes relationship values and may spawn new goals.

### World story generator

This is not a global movie director. It is a seed generator for encounter continuity.

Examples:

- a relative clue exists in a given district
- a former resident still defends a safehouse
- a deserter turned looter
- a companion’s vice gets worse over time

The world-story system decides **what should exist in the background**. The encounter system decides **when the player can meet it**.

---

## 15. Legacy continuation

### Trigger

When the player dies.

### Candidate rules

Candidates are recruited companions or very high-trust allied NPCs.

### Stored data

- profession
- traits
- perk levels
- key inventory/equipment
- relationship debts
- backstory summary
- active story arc

### Continuation model

Not live possession.
Instead:

1. collect eligible snapshots
2. show a continuation modal
3. store the chosen snapshot in `root.legacy.pending`
4. apply it during the next continuation flow / new survivor setup

This keeps the feature robust and save-safe.

---

## 16. Module-by-module design

### 00_LWN_Config

Defines budgets, activation radii, encounter limits, initial population ranges, and debug toggles.

**Invariant:** no mutable save data here.

### 01_LWN_Schema

Creates default records and helper constructors.

**Invariant:** schemas stay pure-data.

### 02_LWN_Localization

Small wrapper around `Translator.getText()` with safe fallback behavior.

**Invariant:** game logic never depends on a rendered sentence.

### 10_LWN_PopulationStore

Owns `ModData.getOrCreate("LWN_SP")`. CRUD for NPC records, encounter state, and legacy snapshots.

**Invariant:** canonical authority for all persistent state.

### 11_LWN_PopulationSeeder

Seeds hidden NPC records at world creation.

**Inputs:** player start square, world seed, config.
**Outputs:** initialized `root.npcs`.

### 12_LWN_Memory

Adds, decays, and summarizes memories.

**Invariant:** memories are tokens with salience, not prose.

### 13_LWN_Social

Relationship deltas, command evaluation, suggestion generation.

**Invariant:** command result is always one of the defined social outcomes.

### 14_LWN_DialogueRealizer

Converts semantic dialogue intents into localization keys and optional `Say()` lines.

### 15_LWN_WorldStory

Owns long-running arcs, clue generation, and recurring encounter seeds.

### 16_LWN_GoalSystem

Builds long-term and short-term goals from current state.

### 17_LWN_UtilityAI

Scores candidate intents and chooses the top one.

### 18_LWN_BehaviorTree

Expands current intent into concrete execution nodes.

### 19_LWN_ActionIntents

Simple constructors for strongly-shaped intent tables.

### 20_LWN_ActionRuntime

Bridges logical intents to pathfinding and timed actions.

### 21_LWN_Combat

Threat detection and melee-oriented combat branch.

### 22_LWN_EncounterDirector

Determines which hidden NPC becomes encounter-eligible and when.

### 23_LWN_ActorFactory

Creates `SurvivorDesc`, applies profession/trait/personality-adjacent descriptor values, selects a safe spawn square, and instantiates an NPC-flagged `IsoPlayer`.

### 24_LWN_ActorSync

Push/pull sync between actor and canonical record.

### 25_LWN_EmbodimentManager

Turns eligible records into actors and back into records.

### 26_LWN_UI_ContextMenu

Adds the top-level interaction entry and routes to target picker / radial / panel.

### 27_LWN_UI_RadialMenu

Fast-command wheel.

### 28_LWN_UI_CommandPanel

Persistent inspect panel for state, relationship, current goal, and story hints.

### 29_LWN_UI_DialogueWindow

Personal/story dialogue topics and lightweight keyword input if desired.

### 30_LWN_Legacy

Death handling and continuation snapshot flow.

### 90_LWN_EventAdapter

All engine hook bindings live here, including the hidden-record rearm pass for companions/debug NPCs and the defensive `OnCreateSurvivor` compatibility hook.

### 99_LWN_Bootstrap

Final startup ordering, post-load validation, and one-shot init.

---

## 17. Testing strategy

### Unit-like smoke tests

- seed new world
- create root mod data
- create 200 hidden records
- stage a single encounter
- embody one NPC
- open context menu
- issue follow command
- despawn and resync
- kill player and open legacy modal

### In-game behavior tests

- first encounter must not happen immediately
- same NPC must preserve memory across despawn/re-embody cycles
- recruited NPC must not blink in/out at screen edges
- command refusal must be explainable by current state
- betrayal must require accumulation, not pure randomness

### Save/load tests

- save while NPC embodied
- reload and verify canonical record consistency
- load with no embodied NPC nearby
- remove mod data in debug mode and re-seed safely

---

## 18. Phased implementation plan

### Phase 1 — foundation

- PopulationStore
- Schema
- Seeder
- EncounterDirector
- ActorFactory
- EmbodimentManager

### Phase 2 — visible interaction

- Context menu
- Radial menu
- Command panel
- ActorSync

### Phase 3 — simple companion AI

- GoalSystem
- UtilityAI
- ActionIntents
- ActionRuntime
- Memory
- Social

### Phase 4 — combat and recruited follower loop

- Combat
- Follow/Wait/Guard/Search behaviors

### Phase 5 — story and drama

- WorldStory
- DialogueRealizer
- Drama flags in Social/Memory

### Phase 6 — legacy

- Death modal
- Snapshot continuation

This is the order most likely to produce a stable mod quickly.
