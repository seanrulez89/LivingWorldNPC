# Domain Workstreams and Shared Contracts

Date: 2026-06-16

This document is the current coordination rulebook for LivingWorldNPC. It is
meant for Codex, future sub-agents, and human review before the mod grows into
combat, status, inventory, personal history, and autonomous-feeling behavior.

The short version:

- Do not move behavior authority into the Bandits actor or brain.
- Do not let story, social, or status code directly drive world actors.
- Keep canonical NPC state in the LWN record.
- Convert decisions into intents.
- Let `ActionRuntime` and the active carrier execute those intents.
- Let `LWN.Combat` decide whether combat is allowed; let Bandits execute combat.

## Current Architecture Verdict

The current runtime is already close to the right domain split. The risky part
is not the folder layout. The risky part is that several large files are acting
as integration hubs while the project is still moving fast.

Therefore the safe structural move for this pass is documentation and ownership,
not a physical file split. Splitting `36_LWN_Carrier_Bandits.lua`,
`90_LWN_EventAdapter.lua`, or `92_LWN_DebugTools.lua` before the next combat and
follow tests would create behavior risk without giving enough benefit.

The next code refactors should happen only when the extracted boundary has an
active feature behind it, such as autonomous intent scoring, squad inventory, or
NPC status UI.

## Non-Negotiable Invariants

- `LWN.Schema` and `LWN.PopulationStore` define the canonical NPC record.
- `record.identity`, `record.stats`, `record.personality`,
  `record.motivations`, `record.backstory`, `record.relationshipToPlayer`,
  `record.companion`, and `record.combat` are the source of truth.
- Bandit `brain` fields are runtime hints only. They may cache `lwnControlled`,
  `lwnCombatEngaged`, `lwnCombatReason`, `lwnTeamId`, movement flags, and spawn
  correlation data, but must not become save data.
- Actor `ModData` is an identification and runtime bridge, not a second NPC
  database.
- Carriers own embodiment, movement task execution, animation posture, actor
  cleanup, and third-party compatibility wrappers.
- Carriers do not own goals, memories, personal story, relationship policy, or
  long-term autonomous decisions.
- User-facing commands and autonomous decisions must flow through intents.
- Debug tools may create test flows, but debug state must not become required
  production state.
- General Bandits behavior must keep its original result unless the actor or
  brain is positively identified as LWN-managed.

## Domain Workstreams

### 1. Canonical State and Schema

Owned files:

- `42/media/lua/shared/01_LWN_Schema.lua`
- `42/media/lua/client/10_LWN_PopulationStore.lua`
- `42/media/lua/shared/00_LWN_Config.lua`

Responsibilities:

- Define durable NPC record shape.
- Add compatibility defaults through `ensureNPCRecordShape`; do not force
  one-time migrations for ordinary test saves unless unavoidable.
- Keep fields serializable and understandable without an actor.
- Preserve backward compatibility for old records.

Rules:

- Any new cross-domain field starts here, with a default.
- Do not store Java objects, actor refs, Bandit brain refs, or transient task
  refs in the canonical record.
- Prefer adding a small field to the record over hiding durable behavior state in
  actor `ModData`.

### 2. Identity, Backstory, Memory, and Social State

Owned files:

- `42/media/lua/client/11_LWN_PopulationSeeder.lua`
- `42/media/lua/client/12_LWN_Memory.lua`
- `42/media/lua/client/13_LWN_Social.lua`
- `42/media/lua/client/15_LWN_WorldStory.lua`

Responsibilities:

- Create identities and initial narrative hooks.
- Record memories and relationship changes.
- Expose story and social facts to decision code.
- Never directly manipulate embodied actors.

Rules:

- Backstory should alter preferences, thresholds, dialogue, and intent scoring.
- Backstory should not directly enqueue Bandits tasks.
- Social policy may answer questions such as "is the player allowed to harm this
  NPC?" or "should this NPC trust this order?"
- Memory writes should be event-based and explainable.

### 3. Autonomy and Decision Layer

Owned files:

- `42/media/lua/client/16_LWN_GoalSystem.lua`
- `42/media/lua/client/17_LWN_UtilityAI.lua`
- `42/media/lua/client/18_LWN_BehaviorTree.lua`
- `42/media/lua/client/19_LWN_ActionIntents.lua`

Responsibilities:

- Convert current world state, NPC state, personality, memory, relationship, and
  command policy into candidate intents.
- Score or select an intent.
- Keep the selected action explainable.

Rules:

- Autonomous behavior must emit `LWN.Schema.newIntent(...)` objects.
- Do not call carrier functions from autonomy files.
- Do not mutate actor movement, target, health, or Bandits tasks from this layer.
- Every autonomous choice should have a reason string suitable for telemetry.
- Future "autonomous feeling" should come from varied scoring and thresholds, not
  hidden carrier side effects.

Recommended future pipeline:

1. Observe player, squad, threats, resources, moodles, injuries, and current
   command.
2. Build a decision context.
3. Score candidate intents with personality, motivations, memory, relationship,
   backstory, and command policy.
4. Emit one intent with a reason.
5. Let `ActionRuntime` and the carrier execute it.
6. Log one compact explanation line when the decision changes.

### 4. Action Runtime and Movement

Owned files:

- `42/media/lua/client/20_LWN_ActionRuntime.lua`
- Movement sections inside `42/media/lua/client/36_LWN_Carrier_Bandits.lua`
- `42/media/lua/client/31_LWN_CarrierAdapter.lua`

Responsibilities:

- Maintain the intent queue.
- Start, tick, cancel, and finish current intents.
- Delegate carrier-specific execution through `CarrierAdapter.tickIntent` and
  `CarrierAdapter.cancelIntent`.
- Keep command status synchronized with the canonical record.

Rules:

- `ActionRuntime` decides whether an intent is active, done, or failed.
- Carriers may execute or reject an intent, but should return a structured
  result instead of silently overriding runtime state.
- Follow, wait, move, and future "fetch car" or "retreat to shelter" commands
  should remain command/intents, not debug-only actions.
- Movement code must not clear combat tasks while `lwnCombatEngaged` is true.

### 5. Combat, Damage, and Threat Policy

Owned files:

- `42/media/lua/client/21_LWN_Combat.lua`
- LWN wrappers in `42/media/lua/shared/03_LWN_BanditsIntegration.lua`
- Damage and combat bridge sections in `42/media/lua/client/36_LWN_Carrier_Bandits.lua`

Responsibilities:

- Decide whether an LWN NPC is allowed to engage.
- Maintain team defense signals and direct self-defense signals.
- Keep `record.combat` and runtime brain flags synchronized.
- Preserve player-friendly attack suppression without blocking ordinary zombie
  damage.

Rules:

- `LWN.Combat` controls engagement permission.
- Bandits executes combat once permission is granted.
- LWN vs player and LWN vs LWN are not enemies in the current version.
- LWN vs ordinary zombie is enemy only when `lwnCombatEngaged` is true.
- Friendly player attack suppression must be scoped to the player relation
  policy and must not make NPCs immune to ordinary zombies.
- Combat telemetry should report NPC id/name, stance, policy, team, health,
  threat, reason, task, and target only when state changes or on explicit test
  summaries.

### 6. Embodiment and Carrier Lifecycle

Owned files:

- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
- `42/media/lua/client/31_LWN_CarrierAdapter.lua`
- `42/media/lua/client/32_LWN_Carrier_None.lua`
- `42/media/lua/client/33_LWN_Carrier_IsoPlayer.lua`
- `42/media/lua/client/34_LWN_Carrier_IsoSurvivor.lua`
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/36_LWN_Carrier_Bandits.lua`

Responsibilities:

- Decide hidden, spawning, embodied, cleanup, and retired lifecycle states.
- Bind records to world actors.
- Retire actors cleanly.
- Keep carrier-specific quirks isolated.

Rules:

- `Bandits` is the current active carrier for test companions.
- Legacy carriers remain research code unless explicitly reactivated.
- Spawn may be asynchronous; `pending` is a valid carrier result.
- Duplicate or orphan actors must be cleaned through carrier lifecycle APIs.
- Any carrier-specific workaround must positively identify LWN actors before
  changing third-party behavior.

### 7. UI, Interaction, and Status

Owned files:

- `42/media/lua/client/26_LWN_UI_ContextMenu.lua`
- `42/media/lua/client/27_LWN_NPCInteraction.lua`
- `42/media/lua/client/27_LWN_UI_RadialMenu.lua`
- `42/media/lua/client/28_LWN_NPCStatus.lua`
- `42/media/lua/client/28_LWN_UI_CommandPanel.lua`
- `42/media/lua/client/29_LWN_UI_DialogueWindow.lua`

Responsibilities:

- Present commands, NPC status, stance changes, and future interaction panels.
- Convert UI choices into public state updates or intents.
- Never bypass command/intents for world actor behavior.

Rules:

- UI can call `ActionRuntime.replaceWithIntent`, `ActionRuntime.clear`,
  `Combat.setDisposition`, and future public APIs.
- UI should not write Bandit brain fields directly except for temporary debug
  bridge code that is clearly isolated.
- NPC status windows should read canonical state first and runtime debug state
  second.

### 8. Event Bridge, Debug, and Telemetry

Owned files:

- `42/media/lua/client/90_LWN_EventAdapter.lua`
- `42/media/lua/client/91_LWN_Debug.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

Responsibilities:

- Register game events.
- Drive periodic ticks.
- Provide test menus and summaries.
- Record compact logs that survive manual in-game testing.

Rules:

- Event handlers should route quickly into domain modules.
- Long-term behavior rules should not live only in the event adapter.
- Debug tools may orchestrate test setup, but production behavior must remain in
  domain modules.
- Test logs should favor state-transition lines and summary lines over per-tick
  spam.

## Shared Runtime Contracts

### NPC Record Contract

Canonical records are created by `LWN.Schema.newNPCRecord(id, seed)` and repaired
by `LWN.Schema.ensureNPCRecordShape(record)`.

Current important durable sections:

- `identity`: displayed name, sex, profession, traits.
- `stats`: health and survival state inputs.
- `personality`: long-term behavioral weights.
- `motivations`: broad priorities such as survival, safety, belonging, power,
  curiosity, pleasure, and ideology.
- `relationshipToPlayer`: trust, fear, resentment, attachment, debt, and loyalty.
- `backstory`: personal history hooks.
- `memories`: event-based memory entries.
- `goals`: current plans and future autonomy state.
- `companion`: team, squad slot, current command, command policy.
- `combat`: stance, engagement state, reason, health bridge, and last threat.
- `embodiment`: carrier lifecycle, actor bridge, presentation, death, cleanup.

### Intent Contract

Intents are created through `LWN.Schema.newIntent(kind, data)` and helper
functions in `LWN.ActionIntents`.

Current public helpers:

- `moveTo(record, x, y, z, options)`
- `followPlayer(record, options)`
- `guardPlayer(record)`
- `retreat(record, threatPos)`
- `wander(record)`
- `rest(record)`
- `searchNearby(record, topic)`
- `talk(record, topic)`
- `attackMelee(record, target)`
- `idleObserve(record)`

Required intent lifecycle fields:

- `kind`
- `started`
- `failed`
- `done`
- `data`

Reserved or active command combat policies:

- `stance`: follow the NPC's combat disposition.
- `self_defense`: ignore unrelated threats, respond to direct danger.
- `assist`: join team defense even if not otherwise aggressive.
- `avoid`: reserved for future escape behavior.

### ActionRuntime Contract

Public functions:

- `LWN.ActionRuntime.enqueue(record, intent)`
- `LWN.ActionRuntime.replaceWithIntent(record, actor, intent)`
- `LWN.ActionRuntime.clear(record, actor)`
- `LWN.ActionRuntime.peek(record)`
- `LWN.ActionRuntime.pop(record)`
- `LWN.ActionRuntime.tick(record, actor)`

Rules:

- `replaceWithIntent` is the preferred UI command entry point.
- `clear` must cancel active carrier intent state when possible.
- `tick` may delegate carrier-owned movement through `CarrierAdapter.tickIntent`.
- Runtime failures must update command state instead of leaving commands active
  forever.

### CarrierAdapter Contract

Public functions:

- `getImplementation(kind)`
- `resolveKind(record, options)`
- `ensureEmbodimentFields(record, kind)`
- `buildHandle(record, kind, seed)`
- `registerHandle(record, handle)`
- `getHandle(record)`
- `getActor(handle)`
- `isUsable(handle)`
- `spawn(record, options)`
- `poll(record, handle, options)`
- `sync(record, handle, options)`
- `retire(record, handle, options)`
- `tickIntent(record, handle, intent)`
- `cancelIntent(record, handle, intent, reason)`
- `tick()`
- `getDebugState(record, handle)`

Carrier result shape:

- `ok`: false only for failure.
- `pending`: true for asynchronous spawn/bind.
- `actor`: optional actor ref.
- `handle`: runtime carrier handle.
- `status`: optional lifecycle status.
- `detail`: concise reason string.

### Combat Contract

Public functions:

- `LWN.Combat.update(record, actor)`
- `LWN.Combat.notePlayerAttack(target, attacker)`
- `LWN.Combat.noteSquadHit(record, attacker)`
- `LWN.Combat.resetTeam(teamId)`
- `LWN.Combat.setDisposition(record, disposition, reason)`
- `LWN.Combat.commandPolicy(record)`
- Legacy compatibility: `buildContext(record, actor)` and
  `chooseIntent(record, actor, ctx)`.

Rules:

- `update` is the combat gate for Bandits-backed companions.
- It may set `record.combat.state`, `record.combat.reason`,
  `brain.lwnCombatEngaged`, `brain.lwnCombatReason`, and `brain.lwnTeamId`.
- It must not turn unrelated ordinary Bandits into LWN-controlled actors.
- It must not grant full invulnerability.

## Sub-Agent / Parallel Work Rules

Sub-agents can help once the project splits into multiple workstreams, but only
if the main agent keeps integration authority.

Good sub-agent tasks:

- Audit one domain and return findings without edits.
- Add focused tests or validation helpers.
- Draft UI copy or status-panel fields.
- Implement a narrow feature in one owned module after the shared contract is
  already agreed.
- Compare reference mods for one behavior topic.

Bad sub-agent tasks:

- "Refactor the carrier" without a precise boundary.
- "Improve autonomy" by editing carrier, combat, UI, and schema at once.
- Any schema change without compatibility defaults.
- Any Bandits wrapper change without checking generic Bandits behavior.
- Any debug-tool shortcut that becomes required for normal runtime behavior.

For any multi-agent or parallel edit:

1. Declare the domain owner.
2. Declare allowed files.
3. Declare public APIs being changed.
4. Keep schema changes in a separate mini-plan.
5. Run validation after integration.
6. Summarize behavioral risk and manual test requirements.

## Future Extraction Candidates

These are not refactors to do immediately. They are the likely safe split points
once related features are active.

- From `36_LWN_Carrier_Bandits.lua`:
  - spawn correlation and binding
  - follow locomotion tasking
  - combat damage bridge
  - equipment grant/equip bridge
  - debug state reporting
- From `90_LWN_EventAdapter.lua`:
  - tick scheduler
  - death and corpse event bridge
  - command/development harness routing
  - future autonomy tick bridge
- From `92_LWN_DebugTools.lua`:
  - companion squad test menu
  - log summary/report generation
  - legacy carrier experiment commands
- From `23_LWN_ActorFactory.lua`:
  - legacy IsoZombie experiment helpers
  - reusable actor diagnostics
  - obsolete appearance probes after Bandits carrier stabilizes

Do not split duplicate numeric-prefix UI files yet. Their load order currently
works, and a rename would be a behavior risk unless performed as a dedicated
load-order pass.

## Patch Checklist

Before editing:

- Identify the domain owner.
- Check whether the change touches a shared contract.
- Prefer adding a narrow API over cross-module mutation.
- Decide whether the behavior should be canonical state, runtime state, or debug
  state.

Before finishing:

- Run `bash scripts/validate-mac.sh` after Lua changes.
- Run `git diff --check` after any change.
- For Bandits changes, confirm the wrapper is idempotent and LWN-scoped.
- For autonomous behavior changes, include a compact explanation log.
- For UI changes, confirm actions route through intent or public domain APIs.

