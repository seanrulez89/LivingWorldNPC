# Bandits → LivingWorldNPC 1:1 Minimal Component Map

Date: 2026-03-21
Branch: `spike/isozombie`
Purpose: turn the observed Bandits success pattern into a concrete design map for LivingWorldNPC, with a strict focus on the **minimum components LWN must own** if it wants an `IsoZombie` carrier to be perceived as a real human NPC.

---

## Executive verdict

Bandits is not succeeding because it found a hidden "turn zombie into human" switch.
Bandits is succeeding because it built a **full orchestration layer** on top of an `IsoZombie` shell.

That orchestration layer is thicker than our current LWN spike in four critical places:

1. **initial banditization pass** happens immediately and decisively
2. **animation/action control** is explicit, not mostly left to zombie-native behavior
3. **equipment / hands / attached models / bump types** are actively managed
4. **audio is not only suppressed; it is replaced and contextualized**

So the right question for LWN is no longer:

- "How do we make `IsoZombie` become a human actor?"

The right question is:

- "What is the minimum Bandits-style orchestration stack LWN must add on top of an `IsoZombie` shell to make it read as a human NPC?"

This document answers that question directly.

---

# 1. The short answer: what LWN is still missing

LWN already has:

- canonical NPC records
- social state / trust / memory / goals
- carrier adapter structure
- an active `IsoZombie` shell path
- hybrid descriptor / human-visual shaping
- persistent illusion beginnings
- good debug visibility

LWN does **not** yet have the minimum complete equivalent of Bandits in these areas:

- a **single authoritative banditize/humanize pass** at shell birth
- a **shell-side action program layer** that owns human-readable movement and attack execution
- a **weapon / hands / attached-model layer**
- a **state-profile illusion layer** (`friendly`, `neutral`, `hostile`) that changes more than combat toggles
- a **selective audio replacement layer**
- a **first-apply vs maintenance split**
- a **hostile profile that still looks/reads human rather than zombie**

That is the real gap.

---

# 2. The core mental model

## 2.1 What Bandits is actually doing

Bandits should be read as this architecture:

- **carrier**: `IsoZombie`
- **identity**: custom bandit markers + sidecar brain id
- **brain**: external tables/programs/tasks
- **animation**: explicit bump-type / walk-type / action selection
- **equipment**: explicit hand items, attachment state, model reset
- **audio**: suppression + explicit replacement playback
- **presentation**: repeated humanization / anti-zombie restamping

That is not a skinning trick.
That is a **puppeteering system**.

## 2.2 What LWN is currently doing

LWN currently has a strong top half but a thinner bottom half:

- **carrier**: `35_LWN_Carrier_IsoZombie.lua`
- **identity**: `record.id`, `modData`, carrier markers
- **brain**: `16/17/18/19/20/21`
- **presentation**: `23_LWN_ActorFactory.lua`
- **lifecycle**: `25_LWN_EmbodimentManager.lua`, `31_LWN_CarrierAdapter.lua`, `90_LWN_EventAdapter.lua`
- **illusion beginnings**: persistent illusion package in `35_LWN_Carrier_IsoZombie.lua`

But LWN still often lets the shell fall back to:

- zombie-native hostile read
- zombie-native attack feel
- zombie-native final presentation role
- weak equipment/animation orchestration

So LWN has **brain and lifecycle**, but Bandits has more **stagecraft**.

---

# 3. 1:1 structure map — Bandits → LWN

## 3.1 Carrier birth / shell acquisition

### Bandits

**Relevant files**
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/shared/BanditCompatibility.lua`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/client/BanditUpdate.lua`
- `reference_mods/3268487204/mods/Bandits/42.15/media/lua/server/BanditServerSpawner.lua`

**Observed responsibilities**
- spawn shell with `addZombiesInOutfit(...)`
- immediately decorate / banditize shell
- version-specific wrapper for B42 signature drift

### LWN

**Current paths**
- `42/media/lua/client/31_LWN_CarrierAdapter.lua`
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

**What LWN already has**
- adapter-controlled spawn path
- `IsoZombie` carrier implementation
- handle registration
- shell markers / carrier metadata

**What LWN is missing**
- a cleanly named, authoritative **post-spawn humanization pass** that happens once and is considered complete

**Minimum required LWN component**
- `LWN.ShellHumanizer.applyInitial(record, actor, descriptor, options)`

**Why this matters**
- today, the first major humanization jump seems to occur on first strong sync/state change
- that is too late
- Bandits effectively “banditizes” at birth, not lazily by accident

---

## 3.2 Shell identity / ownership / brain lookup

### Bandits

**Relevant files**
- `BanditUpdate.lua`
- `BanditBrain.lua`
- `BanditZombie.lua`

**Observed responsibilities**
- `zombie:setVariable("Bandit", true)`
- `zombie:getModData().brainId = brain.id`
- caches map shell ids back to external brain/program state

### LWN

**Current paths**
- `10_LWN_PopulationStore.lua`
- `25_LWN_EmbodimentManager.lua`
- `31_LWN_CarrierAdapter.lua`
- `35_LWN_Carrier_IsoZombie.lua`

**What LWN already has**
- canonical `record.id`
- shell markers such as `LWN_NpcId`, `LWN_CarrierKind`, `LWN_ShellMarker`, `LWN_SessionId`
- external canonical record ownership

**What LWN is missing**
- one single, canonical, engine-visible boolean/string marker that all later systems can branch on as the “this is a humanized LWN shell” flag

**Minimum required LWN component**
- `setVariable("LWNManagedShell", true)` is a good start, but it should become a true cross-system contract
- document it as the equivalent of Bandits’ `Bandit=true`

**Why this matters**
- Bandits’ success is not just the brain id; it is the clarity of shell identity everywhere
- LWN should stop treating identity markers as mere debug metadata and promote them into a formal runtime contract

---

## 3.3 Brain / program / task ownership

### Bandits

**Relevant files**
- `BanditBrain.lua`
- `BanditPrograms.lua`
- `ZombiePrograms/*.lua`
- `ZombieActions/*.lua`

**Observed responsibilities**
- external brain owns intent/program/task state
- shell performs tasks but does not own cognition
- different task/action layers exist beneath the high-level brain

### LWN

**Current paths**
- `16_LWN_GoalSystem.lua`
- `17_LWN_UtilityAI.lua`
- `18_LWN_BehaviorTree.lua`
- `19_LWN_ActionIntents.lua`
- `20_LWN_ActionRuntime.lua`
- `21_LWN_Combat.lua`
- `90_LWN_EventAdapter.lua`

**What LWN already has**
- a proper external cognition stack
- goals → utility → behavior → action intent → action runtime

**What LWN is missing**
- an **animation-facing shell action layer** equivalent to Bandits’ `ZombieActions`
- currently, too much hostile read still leaks through basic zombie-style pursuit/attack handling

**Minimum required LWN component**
- `LWN.ShellActions` layer under `ActionRuntime`
- it should translate `attack_melee`, `follow`, `move`, `guard`, `aim`, `shoot`, etc. into shell-specific execution primitives

**Important distinction**
- LWN already has intents
- Bandits additionally has **task performers**
- that is the missing middle layer

---

## 3.4 Walk / locomotion / motion read

### Bandits

**Relevant files**
- `BanditUpdate.lua`
- `ZombieActions/ZAGoTo.lua`
- `ZombieActions/ZAMove.lua`

**Observed responsibilities**
- `setWalkType("Walk")`
- `setVariable("BanditWalkType", "Walk")`
- move tasks keep reinforcing readable movement state
- locomotion is part of the illusion, not an afterthought

### LWN

**Current paths**
- `35_LWN_Carrier_IsoZombie.lua`
- `20_LWN_ActionRuntime.lua`
- `90_LWN_EventAdapter.lua`

**What LWN already has**
- `Walk` walk-type reassertion in the persistent illusion package
- movement suppression for neutralized shells

**What LWN is missing**
- walk type as a **stateful policy dimension**, not just one blanket override
- hostile still lacks a distinct human-readable locomotion profile

**Minimum required LWN components**
- `illusionProfile.walkType`
- `illusionProfile.motionStyle`
- `illusionProfile.allowSprint` / `allowRun`
- state-specific locomotion profiles for:
  - `friendly`
  - `neutral`
  - `hostile`

**Why this matters**
- right now hostile still reads zombie because the shell is allowed to attack, but not yet taught to move like an armed human

---

## 3.5 Attack execution / animation control

### Bandits

**Relevant files**
- `ZombieActions/ZASmack.lua`
- `ZombieActions/ZAShoot.lua`
- `ZombieActions/ZAAim.lua`
- `ZombieActions/ZAEquip.lua`

**Observed responsibilities**
- explicit `setBumpType(task.anim)`
- explicit `faceLocation(...)` / `faceLocationF(...)`
- explicit weapon-specific attack animation selection
- explicit aim / shoot / melee orchestration
- shell is told what animation to perform rather than simply being told “go hostile” and left alone

### LWN

**Current paths**
- `19_LWN_ActionIntents.lua`
- `20_LWN_ActionRuntime.lua`
- `21_LWN_Combat.lua`

**What LWN already has**
- intent-level abstraction (`attackMelee`, `followPlayer`, `retreat`, etc.)
- queue/runtime structure

**What LWN is missing**
- attack execution that feels like human action choreography rather than zombie-native attack semantics

**Minimum required LWN component**
- shell-execution functions like:
  - `ShellActions.faceTarget(...)`
  - `ShellActions.playAttackAnim(...)`
  - `ShellActions.playAimAnim(...)`
  - `ShellActions.playShootAnim(...)`
  - `ShellActions.playEquipAnim(...)`

**Critical insight**
- this is likely the single biggest reason Bandits “feels like a complete NPC” while LWN still feels like a managed zombie

---

## 3.6 Weapon / hands / attached-item pipeline

### Bandits

**Relevant files**
- `Bandit.lua`
- `ZombieActions/ZAEquip.lua`
- `ZombieActions/ZASmack.lua`
- `ZombieActions/ZAShoot.lua`

**Observed responsibilities**
- `setPrimaryHandItem(...)`
- `setSecondaryHandItem(...)`
- `setAttachedItem(...)`
- `resetEquippedHandsModels()`
- `clearAttachedItems()`
- `BanditPrimaryType` determines pose/read

### LWN

**Current paths**
- currently fragmented / mostly absent at shell-performance level
- some appearance/worn-item work exists in `23_LWN_ActorFactory.lua`

**What LWN already has**
- visual clothing bridge
- worn-item/item-visual observation

**What LWN is missing**
- explicit **combat/equipment hand-state orchestration**

**Minimum required LWN components**
- `LWN.EquipRuntime` or `LWN.ShellEquipment`
- shell-facing helpers:
  - `setHands(record, actor, equipmentProfile)`
  - `syncAttachedItems(record, actor)`
  - `clearHandsForProfileSwitch(record, actor)`
- a small enum like Bandits’ effective hand types:
  - `barehand`
  - `onehanded`
  - `twohanded`
  - `handgun`
  - `rifle`
  - `spear`

**Why this matters**
- without hand/attach orchestration, even good AI and sound still won’t read like a person using tools or weapons

---

## 3.7 Audio suppression vs audio replacement

### Bandits

**Relevant files**
- `BanditUpdate.lua`
- `BanditCompatibility.lua`
- `ZombieActions/*.lua`
- `media/scripts/zs_sounds*.txt`

**Observed responsibilities**
- `desc:setVoicePrefix("Bandit")`
- B42 compatibility path: `desc:setVoicePrefix("NotAZombie")`
- emitter suppression exists
- but Bandits also actively **plays contextual sounds** for actions
  - reloads
  - attacks
  - equipment
  - impacts
  - speech barks

### LWN

**Current paths**
- `23_LWN_ActorFactory.lua`
- `35_LWN_Carrier_IsoZombie.lua`
- debug observation in `92_LWN_DebugTools.lua`

**What LWN already has**
- zombie vocal suppression experiment
- `NotAZombie` voice prefix
- emitter stop-based suppression

**What LWN is missing**
- selective suppression instead of blunt mute
- explicit **replacement** audio layer

**Minimum required LWN components**
- `LWN.ShellAudio` with two responsibilities:
  1. `suppressZombieAudio(record, actor, profile)`
  2. `playHumanCue(record, actor, cue)`

**First minimum cue set**
- `move_soft`
- `move_run`
- `melee_voice`
- `reload_voice`
- `alert_voice`
- `pain_voice`
- `speak_short`

**Critical insight**
- LWN already proved suppression works
- what is missing now is **replacement**
- without replacement, the shell can become eerily silent rather than human

---

## 3.8 Initial humanization vs maintenance reassertion

### Bandits

**Observed pattern**
- banditize shell strongly up front
- then maintain state over time

### LWN

**Current paths**
- `23_LWN_ActorFactory.lua`
- `35_LWN_Carrier_IsoZombie.lua`
- `90_LWN_EventAdapter.lua`

**What LWN already has**
- strong maintenance reassertion starting to emerge
- appearance diff logging proved that first strong sync still changes the shell substantially

**What LWN is missing**
- a formal split between:
  - initial humanization pass
  - maintenance pass

**Minimum required LWN component**
- `record.embodiment.illusion` state with flags like:
  - `initialApplied`
  - `initialAppliedAt`
  - `lastMaintenanceAt`
  - `initialAppearanceSignature`

**Implementation idea**
- `applyInitialHumanization(...)` once
- `maintainIllusion(...)` every sync

**Why this matters**
- this is the cleanest explanation for why first forced state change visibly changes outfit/hair/etc.
- that work should happen earlier and more intentionally

---

## 3.9 Hostile profile separation

### Bandits

**Observed pattern**
- hostile behavior still uses a shell, but the shell is managed through custom tasks, weapons, sounds, and animations
- hostile is not just “turn off suppressions and let zombie logic loose”

### LWN

**Current paths**
- `13_LWN_Social.lua`
- `21_LWN_Combat.lua`
- `35_LWN_Carrier_IsoZombie.lua`

**What LWN already has**
- canonical friendly/neutral/hostile policy states
- hostile pursuit exists

**What LWN is missing**
- hostile-specific illusion profile

**Minimum required LWN component**
- separate profile table, e.g.:
  - `IllusionProfiles.friendly`
  - `IllusionProfiles.neutral`
  - `IllusionProfiles.hostile`

**Profile dimensions**
- walk type
- vocal suppression mode
- hand/equipment visibility
- aggression cues
- no-lunge / no-teeth / hit reaction mode
- idle posture / turn behavior
- whether shell actions are allowed to play attack animation families

**Why this matters**
- hostile is currently the strongest evidence that LWN still lacks Bandits’ action-stage depth

---

## 3.10 Death / corpse / narrative continuity

### Bandits

**Observed pattern**
- IDs, loot, drop behavior, corpse identity cues
- shell still reads socially as a person when dead

### LWN

**Current paths**
- `25_LWN_EmbodimentManager.lua`
- `24_LWN_ActorSync.lua`
- `30_LWN_Legacy.lua` (partially pruned / still prototype-heavy)

**What LWN already has**
- good cleanup/handle architecture
- better separation between canonical record and shell

**What LWN is missing**
- corpse-time personhood framing

**Minimum required LWN component**
- not urgent for the next spike, but eventually:
  - corpse inventory/personhood markers
  - visible persistent identifiers
  - body drop logic that preserves narrative identity

**Reason to postpone**
- the live-shell illusion is still the main blocker
- Bandits proves this layer matters, but it is not first priority

---

# 4. The minimum LWN architecture that should exist

This is the practical answer to “what are the minimum components we truly need?”

## 4.1 Minimum Component A — ShellHumanizer

**Status:** missing as a formal unit

**Proposed responsibility**
- own initial humanization and maintenance reassertion

**Should absorb logic currently scattered across**
- `23_LWN_ActorFactory.lua`
- `35_LWN_Carrier_IsoZombie.lua`

**Minimum public API**
- `applyInitial(record, actor, descriptor, options)`
- `maintain(record, actor, descriptor, profile)`
- `snapshot(actor)`
- `diff(before, after)`

**Why it is minimum**
- without this, the humanization logic stays spread between presentation experiments and policy sync

---

## 4.2 Minimum Component B — ShellProfiles / IllusionProfiles

**Status:** missing as a first-class unit

**Proposed responsibility**
- define what `friendly`, `neutral`, and `hostile` mean **in embodiment terms**, not just combat terms

**Minimum data per profile**
- walk type
- audio policy
- weapon visibility policy
- anti-zombie suppression package
- motion style
- aggression permissions
- maintenance intensity

**Why it is minimum**
- right now state changes mostly alter aggression/suppression, not full character read

---

## 4.3 Minimum Component C — ShellActions

**Status:** missing

**Proposed responsibility**
- translate high-level intents into shell-specific animation/equipment/sound execution

**Should sit between**
- `20_LWN_ActionRuntime.lua`
- actual `IsoZombie` actor calls

**Minimum actions**
- `move`
- `follow`
- `guard`
- `face`
- `attack_melee`
- `aim`
- `shoot`
- `equip`
- `idle_human`

**Why it is minimum**
- this is the layer Bandits clearly has and LWN clearly lacks

---

## 4.4 Minimum Component D — ShellEquipment

**Status:** missing

**Proposed responsibility**
- synchronize hand items / attachment models / weapon posture

**Minimum API**
- `applyLoadout(record, actor, loadoutProfile)`
- `setHands(record, actor, handType, itemPrimary, itemSecondary)`
- `resetForProfile(record, actor)`

**Why it is minimum**
- human-read combat depends heavily on what the shell is holding and how

---

## 4.5 Minimum Component E — ShellAudio

**Status:** only partially present

**Current partial equivalents**
- voice prefix setting
- emitter stop-based suppression

**Proposed responsibility**
- selective zombie-vocal suppression
- human-coded cue playback

**Minimum API**
- `suppress(record, actor, profile)`
- `playCue(record, actor, cue)`
- `updateMovementPresence(record, actor, profile)`

**Why it is minimum**
- today’s tests already proved audio changes massively affect whether the shell feels human or uncanny

---

## 4.6 Minimum Component F — ShellTelemetry

**Status:** partially present and already useful

**Current equivalents**
- `92_LWN_DebugTools.lua`
- `appearance.diff`
- decision dump
- movement/audio dump

**Proposed responsibility**
- preserve the high-yield debugging already built, but align it around the new architecture

**Minimum tracked values**
- shell marker
- session id
- appearance signature
- illusion profile
- audio policy
- last shell action
- initial-humanization-applied flag
- maintenance-applied flag

**Why it is minimum**
- the spike is now too subtle to debug by eyesight alone

---

# 5. Exact LWN file mapping — where each minimum component should live

## 5.1 Files to keep as the high-level spine

- `10_LWN_PopulationStore.lua`
  - canonical NPC record persistence
- `13_LWN_Social.lua`
  - social policy source of truth
- `16_LWN_GoalSystem.lua`
- `17_LWN_UtilityAI.lua`
- `18_LWN_BehaviorTree.lua`
- `19_LWN_ActionIntents.lua`
- `20_LWN_ActionRuntime.lua`
- `25_LWN_EmbodimentManager.lua`
- `31_LWN_CarrierAdapter.lua`
- `35_LWN_Carrier_IsoZombie.lua`
- `90_LWN_EventAdapter.lua`
- `92_LWN_DebugTools.lua`

These are the right places to keep the architecture spine.

## 5.2 Files/components to conceptually add

### Add under client
- `36_LWN_ShellProfiles.lua`
- `37_LWN_ShellHumanizer.lua`
- `38_LWN_ShellEquipment.lua`
- `39_LWN_ShellActions.lua`
- `40_LWN_ShellAudio.lua`

These names are only a proposal, but the separation matters more than the numbering.

## 5.3 Where existing code should move conceptually

### From `23_LWN_ActorFactory.lua`
Move or wrap into `ShellHumanizer`:
- descriptor shaping
- human visual baseline
- clothing bridge
- appearance diff snapshotting
- maintenance-safe presentation stamping

### From `35_LWN_Carrier_IsoZombie.lua`
Keep in carrier:
- spawn/sync/retire
- shell metadata stamping
- relation-policy integration

But move/wrap into dedicated components:
- persistent illusion package → `ShellProfiles` + `ShellAudio` + `ShellHumanizer`

### From `20_LWN_ActionRuntime.lua`
Keep:
- queue ownership / timed-action shell

But route actual execution through:
- `ShellActions`

### From `90_LWN_EventAdapter.lua`
Keep:
- orchestration loop / tick scheduling / lifecycle wiring

But make it call:
- social policy
- action selection
- shell action executor
- humanization maintenance
explicitly, rather than mixing these concerns too much in one place

---

# 6. The minimum implementation order

If LWN wants the smallest possible build that meaningfully closes the gap with Bandits, the order should be:

## 6.1 First
**Split initial humanization from maintenance**

Reason:
- the logs already proved the first strong sync is still doing major appearance work
- this is the easiest structural upgrade that aligns with observed evidence

## 6.2 Second
**Create illusion profiles**

Reason:
- `friendly`, `neutral`, and `hostile` need to differ in more than combat intent
- this is the minimum bridge from policy to embodiment

## 6.3 Third
**Introduce ShellAudio with selective suppression**

Reason:
- current blunt suppression proved audio matters
- now it needs to become precise rather than mute-everything

## 6.4 Fourth
**Introduce ShellActions for hostile execution**

Reason:
- this is the biggest remaining difference between LWN and Bandits-feel
- hostile still reads like zombie aggression because LWN does not yet own the action performance layer strongly enough

## 6.5 Fifth
**Introduce ShellEquipment**

Reason:
- once actions are explicit, weapons/hands/attachments become the next force multiplier for human-read combat

---

# 7. The bold but evidence-backed conclusion

If Bandits can look like:

- real walking humans
- real running humans
- real melee attackers
- real shooters

then the lesson is not:

- “the zombie isn’t really a zombie under the hood”

The lesson is:

- **they built enough shell-side orchestration that the player stops caring what the underlying class is.**

That is the exact target LWN should now adopt.

LWN does **not** need to solve every engine-level human classification problem first.
LWN needs to implement the minimum complete illusion stack.

That stack, in minimum form, is:

1. **ShellHumanizer**
2. **ShellProfiles**
3. **ShellActions**
4. **ShellEquipment**
5. **ShellAudio**
6. **ShellTelemetry**

Everything else can stay built around the existing LWN record/goal/social/embodiment spine.

---

# 8. Final answer in one sentence

What LWN is missing is **not one hidden API**; it is the minimum complete **Bandits-style shell orchestration layer** that turns a managed zombie shell into a continuously humanized performance surface.

If the next phase builds that layer deliberately, the current `spike/isozombie` architecture can stay intact and still move much closer to the kind of NPC presence the user observed in Bandits.
