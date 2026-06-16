# Reference Mods Local Code Review (2026-06-13)

## Scope

This review inspects the locally downloaded Build 42 versions of:

- Bandits (`3268487204`, active version `42.18`)
- Bandits: Week One - The Ark (`3707475814`, active version `42.18`)
- Bandits Creator (`3469292499`, latest installed version `42.17`)
- LivingWorldNPC (`LivingWorldNPCSP`) on the current working branch

The immediate project goal used for the comparison is narrower than the final living-world goal:

> First produce one completely controlled, convincingly human NPC whose identity and state survive embodiment changes. Then grow that verified runtime into the larger autonomous world simulation.

This is an architectural review, not permission to copy third-party code or assets. Bandits code and animation assets should be treated as reference material unless the author explicitly permits reuse. A dependency-based integration or an independently implemented equivalent is safer than source copying.

## Executive conclusion

The three mods answer different parts of the problem:

- **Bandits is the actor runtime.** It turns an `IsoZombie` into a managed human-presenting shell through a brain, task runtime, per-frame ownership loop, visual reconstruction, and a large patched zombie animation graph.
- **The Ark is the controlled companion example.** It extends Bandits with a named NPC, explicit command modes, schedules, needs, story state, and prioritized behavior selection.
- **Bandits Creator is an authoring tool.** It edits the clan/profile data consumed by Bandits. Its invisible `IsoPlayer` is only a preview model, not its world NPC runtime.
- **LWN already has the better long-term simulation boundary.** Its persistent NPC record is canonical and the live actor is an adapter-managed embodiment. Bandits and The Ark tend to let the live Bandit brain become the primary state container.

The central discovery is why the current LWN Bandits-style visual probe did not solve presentation:

> Bandits is not just a sequence of Lua calls that changes skin, hair, and clothing. It ships 452 zombie AnimSet XML files and 14 custom animation assets, then drives those graphs with variables such as `Bandit`, `BanditPrimaryType`, `BanditWalkType`, and `BanditImmediateAnim` from a continuous `OnZombieUpdate` lifecycle.

LWN currently ships no `AnimSets` or custom animation assets. It reproduced a subset of the visual stamping calls, but not the animation-state contract that makes the zombie shell consistently read as a human actor. The observed `presentationRole=reanimated_zombie` / `fail_presentation_role_zombie` result is therefore expected, not mysterious.

## 1. Bandits

### 1.1 Actor creation and identity

Bandits creates a normal `IsoZombie` with `addZombiesInOutfit`, then builds a separate Lua brain for it in `BanditServerSpawner.lua`:

- the actor's persistent outfit ID becomes `brain.id`;
- profile and clan data become appearance, stats, weapons, inventory, personality, hostility, and voice;
- caller arguments become `program`, `stage`, `master`, `permanent`, and `key`;
- the brain is stored in one of 32 clustered global ModData tables.

Relevant code:

- `BanditServerSpawner.lua:293-425` - `banditize`, brain construction, visuals, ModData write
- `BanditServerSpawner.lua:1112-1129` - public clan spawn entry point
- `BanditServerSpawner.lua:400-412` - program, owner, permanent flag, and arbitrary key
- `BanditGMD.lua:1-107` - clustered persistence and transmission

The arbitrary `brain.key` is especially useful for LWN. It can carry the stable LWN NPC ID so a newly created Bandit shell can be reconciled with the canonical LWN record.

### 1.2 Client takeover and control loop

On the client, Bandits recognizes the persistent outfit ID in clustered ModData and converts that zombie into a managed Bandit:

- writes the brain into actor ModData;
- sets `Bandit=true`, walk type, speed variables, `NoLungeTarget`, no teeth, and voice prefix;
- removes zombie inventory and suppresses zombie presentation;
- continuously reapplies visuals and runtime variables;
- generates a task from the current program and processes one task through `NEW`, `WORKING`, and `COMPLETED` states.

Relevant code:

- `BanditUpdate.lua:157-225` - client-side takeover
- `BanditUpdate.lua:1899-2110` - main per-zombie update loop
- `BanditUpdate.lua:1729-1808` - task state machine
- `BanditUpdate.lua:1810-1883` - priority checks and program dispatch
- `ZombieActions/ZAMove.lua:1-130` - movement action using `PathFindBehavior2`

This is materially different from LWN's current one-time and periodic shell shaping. Bandits owns the shell every update and treats actor variables, animation state, task state, and model state as one runtime contract.

### 1.3 Human presentation is an asset-plus-code system

`Bandit.ApplyVisuals` clears the zombie's visual state, assigns a human body texture, hair, beard, clothing item visuals, attached weapons, and bag, then forces a model reset.

Relevant code:

- `Bandit.lua:79-281` - complete visual reconstruction
- `Bandit.lua:1331+` - male/female human body skin selection

That code is only half of the mechanism. The common directory contains:

- 452 patched files below `media/AnimSets/zombie`;
- 14 custom animation assets;
- graph conditions keyed by `Bandit`, weapon type, walk type, and immediate-animation variables.

This explains the failed LWN experiment precisely. Visual calls can alter the model while the underlying zombie animation graph and actor classification continue to own the final presentation.

### 1.4 Authority model

Bandits mirrors visuals and actions on clients but chooses the nearest player as the controller for consequences. The intent is to avoid every client applying damage or other authoritative effects.

Relevant code:

- `BanditUtils.lua:664-692` - nearest-player controller selection
- `BanditZombie.lua:44+` - actor caches populated from `OnZombieUpdate`

This is workable but tightly coupled to Bandits' multiplayer assumptions. LWN should prove the first adapter in single-player before inheriting this authority model.

### 1.5 Persistence weaknesses

Bandits persistence is useful for transient actor brains but weaker than LWN's canonical-record model:

- `BanditPermanent.Check` returns immediately, so its restoration scan is disabled.
- Restore creates a fresh zombie and fresh brain from the profile instead of rehydrating the complete old brain.
- Restore copies only selected fields and can lose custom runtime state, inventory extensions, needs, or scenario data.
- `args.master = brain.pid` appears inconsistent with the original `brain.master` field and the spawn path's `args.pid`, so ownership restoration is suspect.
- old cluster cleanup in the restore path is commented out.
- `Spawner.Individual` assigns `spawnPoint` but then references `spawnPoints`, which makes the individual API appear broken in this installed version.

Relevant code:

- `client/BanditPermanent.lua:7+`
- `BanditServerSpawner.lua:495-540`
- `BanditServerSpawner.lua:1132-1146`

LWN should not adopt Bandits restore as its source of truth. It should respawn/rebind a shell from its own stable NPC record.

## 2. The Ark

### 2.1 Extension pattern

The Ark does not fork the Bandits runtime. It registers content and behavior into Bandits' global extension points:

- custom clan/profile mappings;
- `ZombiePrograms.Emma` stages;
- scenario events that invoke Bandits `Spawner.Clan`;
- brain fields used as command and story state.

Emma's spawn request supplies a clan, position, `program="Emma"`, voice, and full name. This is the strongest real example of the intended extension path.

Relevant code:

- `BWOASequence.lua:48-59` - Emma spawn payload
- `BWOAEvents.lua:476-483` - forwarding to Bandits spawn
- `ZombiePrograms/ZPEmma.lua:22-33` - program registration

### 2.2 Explicit commands

Dialogue/emote commands mutate a small brain mode:

- `followme` sets `mode="follow"`;
- `stop` clears the mode;
- other commands select scenario-specific modes.

`BWOANPC.ModBrain` retrieves the Bandit by ID, mutates the brain, and forces synchronization.

Relevant code:

- `BWOAChat.lua:166-240` - command-to-mode mapping
- `BWOANPC.lua:241-247` - synchronized brain mutation

This is an important design lesson for LWN: a command should change canonical policy or intent state, not directly improvise dozens of actor calls. The actor runtime should consume that state.

### 2.3 Companion policy

`ZombiePrograms.Emma.Main` is a hand-authored priority selector. It considers, in order, recovery, story stage, greeting, healing the player, explicit command mode, chase/story state, bladder, hunger, mission teleport, decontamination, household work, dancing, schedule, outfit, laundry, blood cleaning, and idle behavior.

Reusable helpers such as `GoAndDo`, `FollowMaster`, `HealPlayer`, and outfit transformation produce Bandits tasks.

Relevant code:

- `ZombiePrograms/ZPEmma.lua:165-350` - main priority policy
- `BWOAPrograms.lua:55+` - move-or-do helper
- `BWOAPrograms.lua:184-235` - follow behavior
- `BWOAPrograms.lua:349-401` - player healing

Architecturally this is very close to LWN's existing `UtilityAI -> BehaviorTree -> ActionIntent -> ActionRuntime` chain. The Ark demonstrates that the missing urgent piece is not another high-level AI planner. It is a reliable action executor and actor shell beneath the planner.

### 2.4 Persistence compensation and bugs

The Ark records Emma's latest position in scenario ModData and attempts to restore or teleport her by removing and recreating a Bandit. This compensates for Bandits' incomplete permanence, but it remains fragile:

- a recreated Bandit can receive a new persistent outfit ID;
- custom brain fields can be lost through Bandits restore;
- stale ID entries can remain;
- owner restoration inherits Bandits' mismatch;
- hunger is incremented twice in the per-minute needs update, likely where one increment was intended to be thirst.

Relevant code:

- `BWOANPC.lua:3-72` - position and needs tracking
- `BWOANPC.lua:78-162` - teleport and missing-NPC recreation
- `BWOAGMD.lua:160-162` - permanent NPC table

The Ark is therefore a very valuable behavior reference, but not a persistence model to copy wholesale.

## 3. Bandits Creator

### 3.1 What it actually is

Bandits Creator is a profile and clan editor. It depends on `Bandits2`. Its invisible `IsoPlayer` objects are preview avatars used by the option screens. They do not establish that `IsoPlayer` is a viable world NPC actor in Build 42.

The generated data describes:

- stable UUID profile and clan identifiers;
- sex, skin, hair, beard, colors;
- health, sight, endurance, strength, and expertise;
- ordered clothing and tints;
- melee/ranged weapons, ammo, and bag.

Relevant code:

- `OptionScreens/BanditCreationMain.lua:1163-1255` - profile assembly and save
- `OptionScreens/BanditClanMain.lua:400-442` - clan save
- Bandits' `BanditCustom.lua:12-174` - actual file load/save and merge contract

### 3.2 Useful design lesson

Runtime behavior is separated from content authoring. A creator mod writes profiles; Bandits consumes those profiles without embedding editor concerns in the actor loop. LWN should eventually use the same separation for NPC archetypes, schedules, appearance presets, and scenario packs.

### 3.3 Weak points not to inherit

The installed data pipeline is convenient but brittle:

- line-oriented flat text is parsed with narrow patterns;
- local data overrides activated-mod data by load order;
- the clan `BanditCustom.Delete` function is later overwritten by the bandit delete function;
- client/server push-pull sends whole tables rather than validated operations;
- the server receive path appears to trust client-provided data without an admin or schema check;
- the server-to-client send call is commented in the installed version, so the pull UI may be incomplete.

For LWN, content data should be versioned, schema-validated, and separated from authoritative save state.

## 4. Comparison with LivingWorldNPC

| Dimension | Bandits | The Ark | Creator | LivingWorldNPC |
|---|---|---|---|---|
| Live actor | Managed `IsoZombie` | Bandits actor | Preview `IsoPlayer` only | Adapter-selected carrier, currently `IsoZombie` spike |
| Canonical identity | Persistent outfit ID / brain | Bandit ID plus scenario table | UUID profile IDs | Stable `LWN-xxxxxx` record ID |
| State authority | Brain attached to Bandit | Brain plus scenario ModData | Profile files | ModData NPC record; actor is non-authoritative |
| Behavior selection | Program stage returns tasks | Rich prioritized Emma program | None | Utility scoring and behavior tree |
| Action execution | Mature `ZombieActions` state machine | Reuses Bandits actions | None | LWN `ActionRuntime`, currently fighting raw zombie shell behavior |
| Human presentation | Visual rebuild plus 452 AnimSet patches | Inherits Bandits | Preview renderer | Lua visual shaping only; no animation graph assets |
| Commands | Program/master switches | Brain `mode` mutation | Editor UI | Canonical action intents and command state |
| Persistence | Clustered brain, incomplete restore | Extra tracking and recreate logic | Profile data only | Strongest design: persistent record independent of embodiment |
| Generality | Group combat/survival runtime | One authored companion/scenario | Authoring utility | Broad living-world simulation foundation |

### LWN strengths to preserve

1. `PopulationStore` explicitly states that canonical NPC state belongs in ModData, not in the embodied actor (`10_LWN_PopulationStore.lua:4-5`).
2. `Schema.newNPCRecord` gives identity, anchor, embodiment, presentation, death, cleanup, and target state a stable home (`01_LWN_Schema.lua:92+`).
3. `CarrierAdapter` already defines the correct replaceable boundary: resolve, spawn, sync, retire, and get actor (`31_LWN_CarrierAdapter.lua:53-220`).
4. `EmbodimentManager` activates a record by asking the adapter for a shell rather than constructing identity inside the shell (`25_LWN_EmbodimentManager.lua:680+`).
5. Action intents make commands serializable and testable (`19_LWN_ActionIntents.lua`).

These are stronger foundations for the final mod than Bandits' actor-centric brain persistence.

### LWN weaknesses exposed by this review

1. The current `IsoZombie` carrier calls `addZombiesInOutfit` with a nil outfit and then attempts to humanize the shell after quarantine. Bandits begins with a controlled naked outfit and immediately establishes its complete brain/animation contract.
2. `ActorFactory` and `Carrier_IsoZombie` have accumulated large visual probes, guardrails, checkpoints, and recovery paths. The two files alone exceed 6,600 lines. Much of that complexity is compensating for a missing lower-level presentation runtime.
3. LWN sets some Bandits-like variables, including `BanditWalkType`, but does not ship the animation graphs that read the complete variable contract.
4. LWN's movement executor directly drives `PathFindBehavior2` while repeatedly repairing zombie flags. Bandits treats movement as one action inside a shell runtime that also owns animation, collision, sounds, and combat state.
5. The project has already demonstrated that direct visual stamping is partially effective but cannot change final zombie-owned presentation truth. Repeating more variations of the same probe has diminishing value.

## 5. Recommended implementation path

### Phase 1: Bandits-backed controlled carrier

Use Bandits as an explicit dependency for a narrow single-player prototype. Do not merge its source into LWN.

Add a new carrier kind, conceptually `bandits`, behind the existing `CarrierAdapter`:

1. Register one LWN clan/profile through Bandits' supported custom profile data.
2. Register `ZombiePrograms.LWNControlled` through the same global extension mechanism used by The Ark.
3. Spawn through `Spawner.Clan`, with `program="LWNControlled"`, `size=1`, and `key=<stable LWN npc id>`.
4. Discover and bind the spawned Bandit by `brain.key`, not by proximity or appearance.
5. Keep all durable identity, needs, relationships, inventory truth, goals, and schedules in the LWN record.
6. Treat the Bandit brain as a disposable embodiment cache containing the LWN key and current execution state.
7. Translate one LWN action intent at a time into Bandits tasks or a dedicated LWN Bandits program stage.
8. On unload, death, or loss, reconcile into the LWN record and create a fresh shell later. Do not call Bandits Restore as the source of truth.

This path uses Bandits for exactly what LWN lacks: a proven human-presenting shell and action executor. It retains LWN for exactly what Bandits lacks: stable simulation identity and generalized world state.

### Phase 1 acceptance test

The first milestone should contain only one NPC and five commands:

- spawn and bind by stable LWN ID;
- idle without zombie aggression or zombie audio;
- move to a selected tile;
- follow the player;
- stop/hold position;
- unload and recreate while preserving the same LWN identity and command state.

Do not re-enable UtilityAI, social simulation, combat, schedules, or broad population embodiment until this loop is reliable.

### Phase 2: Controlled action bridge

After the shell milestone:

- map `move_to`, `follow_player`, `guard_player`, `retreat`, and `idle_observe` to dedicated Bandits tasks;
- make command state authoritative over autonomous policy;
- add completion/failure acknowledgements back into the LWN action queue;
- add death and disappearance reconciliation keyed by `brain.key`;
- test save/load and chunk unload/reload before adding multiple actors.

The Ark's `brain.mode -> prioritized program -> reusable task` flow is the closest reference, while LWN's action intents should remain the public command contract.

### Phase 3: Restore the larger LWN simulation

Once the controlled shell is verified, reconnect the existing upper layers in this order:

1. explicit player commands;
2. needs and simple schedules;
3. utility-selected noncombat actions;
4. relationship-aware behavior;
5. combat and group behavior;
6. multiple embodied NPCs and offscreen population simulation.

### Long-term alternative: independent runtime

If a hard Bandits dependency is unacceptable, the alternative is not another Lua appearance experiment. It is an independent, clean implementation of:

- zombie AnimSet graph patches for every relevant state;
- custom human animation assets where vanilla clips are insufficient;
- a complete actor variable contract;
- per-update shell ownership;
- task/action executors;
- collision, sound, attack, death, network, and model-refresh handling.

That is a substantial subsystem and should be treated as a separate engineering project. The Bandits-backed carrier is the fastest way to validate LWN's product design before committing to that cost.

## 6. Risks and constraints

- **License/permission:** inspect for learning, but do not copy Bandits source or animation assets without explicit permission.
- **Global compatibility:** Bandits patches the zombie animation graph globally and changes zombie update behavior, so compatibility testing with other animation and zombie mods is mandatory.
- **Version coupling:** the reviewed APIs are implementation surfaces in the installed versions, not a guaranteed stable public SDK. Isolate every Bandits call inside one carrier/integration module.
- **Multiplayer:** Bandits' nearest-player controller and client synchronization model add complexity. Keep the first milestone single-player, matching `LivingWorldNPCSP`.
- **Spawner bugs:** prefer `Spawner.Clan`; the installed `Spawner.Individual` implementation has an apparent variable-name defect.
- **State duplication:** never allow both an LWN record and a Bandit brain to be independently authoritative for the same field.

## Final judgment

The downloaded mods strongly validate the project's strategic direction, but they also show that the recent experiment was aimed at too small a slice of Bandits.

The correct near-term move is:

> Preserve LWN's canonical records, command intents, and embodiment abstraction; replace the current raw `IsoZombie` spike with a narrow Bandits-backed carrier; prove one stable, fully controlled NPC; then reconnect the living-world systems above it.

This is both the shortest path to the urgent controlled-NPC milestone and the path that discards the least valuable LWN work.
