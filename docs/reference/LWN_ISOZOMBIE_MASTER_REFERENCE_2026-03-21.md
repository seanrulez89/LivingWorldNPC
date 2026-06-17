# LivingWorldNPC IsoZombie Master Strategic Reference

Date: 2026-03-21
Branch context: `spike/isozombie`
Scope: docs-only synthesis of the following March 20 research docs, reconciled against the current branch code:

- `docs/reference/REFERENCE_CORPUS_ISOZOMBIE_AUDIT_2026-03-20.md`
- `docs/reference/BUILD42_ISOZOMBIE_NPC_WEB_MEMO_2026-03-20.md`
- `docs/reference/BUILD41_78_JAVADOC_SKEPTICAL_AUDIT_FOR_BUILD42_ISOZOMBIE_SHELL_2026-03-20.md`
- `docs/reference/PZWIKI_BUILD42_ISOZOMBIE_SHELL_REVIEW_2026-03-20.md`

Repo-aware runtime files reviewed while writing this:

- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/24_LWN_ActorSync.lua`
- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua`
- `42/media/lua/client/31_LWN_CarrierAdapter.lua`
- `42/media/lua/client/33_LWN_Carrier_IsoPlayer.lua`
- `42/media/lua/client/34_LWN_Carrier_IsoSurvivor.lua`
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

## Executive verdict

The strongest current direction for LivingWorldNPC is not "convert a zombie into a human once" and not "resurrect the old `IsoPlayer` embodiment fight." It is:

1. keep canonical NPC identity, trust, memory, goals, and lifecycle in ModData-backed records,
2. embody nearby NPCs as managed `IsoZombie` shells,
3. continuously restamp presentation, relationship posture, and UI framing so the shell is read as a person,
4. treat every live shell as a zombie-runtime cache with human-facing illusion layers, not as a true human runtime.

That conclusion is stronger after the March 20 doc set, not weaker.

What changed versus earlier branch assumptions:

- the reference corpus does not reveal a clean Build 42 "real human NPC" recipe waiting to be copied
- the best real reference proof is still Bandits' zombie-shell strategy, not a hidden `IsoPlayer` salvation path
- Build 41 docs help explain why appearance borrowing is plausible, but they do not justify trusting Build 42 to honor human combat/AI semantics on a zombie subclass
- the current branch already behaves like this reality:
  - `35_LWN_Carrier_IsoZombie.lua` owns spawn/sync/retire for the live shell
  - `23_LWN_ActorFactory.lua` provides appearance shaping and hybrid instrumentation
  - `26_LWN_UI_ContextMenu.lua` explicitly has special targeting allowances for managed zombie carriers
  - `25_LWN_EmbodimentManager.lua` already treats embodied actors as disposable caches over canonical records

The project therefore should optimize for a durable "human-perceived zombie-shell carrier" architecture, not for subclass conversion fantasies.

## What Is Genuinely Supported Vs Speculative

## Genuinely supported by the combined evidence

### 1) Spawning a real, visible, world-native zombie shell

Supported by:

- Bandits corpus findings in `docs/reference/REFERENCE_CORPUS_ISOZOMBIE_AUDIT_2026-03-20.md`
- current LWN spawn path in `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

What this actually means:

- using `addZombiesInOutfit(...)` to get a valid live shell is real
- this is the one carrier path in the current branch that already aligns with known stable world-runtime behavior
- this matches Bandits' strongest pattern: spawn a zombie first, then manage it as something else socially

### 2) Stamping managed identity onto the shell via ModData and custom markers

Supported by:

- Bandits' `Bandit` variable plus `brainId` pattern
- current LWN markers in `35_LWN_Carrier_IsoZombie.lua`
- current managed-target checks in `23_LWN_ActorFactory.lua` and `26_LWN_UI_ContextMenu.lua`

What this actually means:

- shell identity must be attached with LWN-owned markers such as `LWN_NpcId`, `LWN_CarrierKind`, relation summaries, and hybrid debug metadata
- engine object identity is not enough
- Build 42 pooling/reuse risk means the mod's own NPC id must stay primary

### 3) Applying human-facing appearance data to a zombie shell

Supported by:

- official Build 42 docs summarized in `docs/reference/BUILD42_ISOZOMBIE_NPC_WEB_MEMO_2026-03-20.md`
- Build 41 conceptual evidence in `docs/reference/BUILD41_78_JAVADOC_SKEPTICAL_AUDIT_FOR_BUILD42_ISOZOMBIE_SHELL_2026-03-20.md`
- current implementation in `23_LWN_ActorFactory.lua:applySafeAppearanceShaping(...)`

What this actually means:

- descriptor seeding, `HumanVisual`, clothing application, worn-item bridging, and model refresh are legitimate experiment lanes
- they are appearance lanes, not proof of human runtime ownership

### 4) Steering some hostility/neutralization behavior from relationship policy

Supported by:

- current `35_LWN_Carrier_IsoZombie.lua:applyRelationshipCombatState(...)`
- current `13_LWN_Social.lua:relationshipCombatPolicy(...)`

What this actually means:

- the project can already manipulate whether the shell pursues the player, drops intent, stops walking, loses teeth, and toggles attackability heuristics
- this is partial behavior steering, not full behavior replacement

### 5) Framing managed zombie carriers as interactable NPCs in UI

Supported by:

- `26_LWN_UI_ContextMenu.lua:isManagedZombieCarrier(...)`
- `26_LWN_UI_ContextMenu.lua:isTargetableNpcActor(...)`

What this actually means:

- UI can help close the social gap even when the engine still sees zombie ancestry
- the player does not need engine-pure human classification to receive "Living NPC" affordances

## Still speculative or unsupported

### 1) One-shot type conversion from `IsoZombie` to "real human NPC"

Not supported by the docs, the references, or the current branch results.

Why not:

- no reviewed source shows a stable Build 42 path that makes the engine truly treat `IsoZombie` as `IsoPlayer` or `IsoSurvivor`
- current branch evidence already shows descriptor/human-visual success can coexist with `presentationRole=reanimated_zombie`
- the March 20 docs repeatedly point to shared presentation surfaces, not shared gameplay semantics

### 2) Human safety/combat/faction semantics arriving automatically from shared base methods

Not supported.

Why not:

- Build 42 docs expose broad `IsoGameCharacter` methods, but the web memo correctly treats this as a subclass trap
- earlier local NPE behavior around zombie-carrier `setNPC(true)` proved that inherited surface does not guarantee safe runtime semantics
- current code has already started guarding this in `23_LWN_ActorFactory.lua:refreshActorPresentation(...)` and `24_LWN_ActorSync.lua:enforceEmbodiedFlags(...)`

### 3) Stable logical identity attached to a zombie object instance

Not supported and actively unsafe to assume.

Why not:

- the web memo and wiki review both highlight Build 42 reuse/pooling risk
- current LWN architecture is already healthier when identity stays in records plus `LWN_NpcId`, not in raw Lua object identity

### 4) Solving the shell with descriptor work alone

Not supported by the current branch and contradicted by evidence.

Why not:

- current hybrid summary can report descriptor bound and appearance applied while the shell still renders as zombie
- Bandits also does not stop at descriptors; it keeps rewriting visuals, sound, behavior variables, and identity markers

## What Build 41 Teaches Vs What Must Be Distrusted In Build 42

## Build 41 lessons still worth keeping

### Shared presentation substrate matters

The Build 41 skeptical audit is useful because it shows why this experiment is not nonsense:

- `IsoZombie`, `IsoPlayer`, `SurvivorDesc`, `AnimatedModel`, and other classes shared human-visual concepts
- `SurvivorDesc` was a legitimate identity-and-appearance seed
- `HumanVisual` was its own layer, not welded to only one actor class

Carry forward:

- keep using descriptor-like data as appearance input
- keep treating presentation as a separate layer from canonical state
- keep testing visual and identity shaping on the zombie shell

### Shared base class is useful as a map, not a contract

Build 41 helps explain why certain methods appear on multiple actor classes.

Carry forward:

- use Build 41 to form hypotheses about appearance, model reset, descriptor seeding, and broad lifecycle vocabulary
- use it to generate tests, not to grant trust

## What must be distrusted in Build 42

### Distrust inheritance-based optimism

If a method exists on `IsoGameCharacter`, do not assume the zombie subclass can safely use it in the same way as a live human branch.

Concrete branch example:

- previous `setNPC(true)` behavior on zombie shells was unstable enough that current code now gates those paths away from `isozombie`

### Distrust object-instance permanence

Do not treat a specific `IsoZombie` instance as the NPC.

Practical meaning for LWN:

- `record.id` stays canonical
- shell markers must be restamped
- pooling-safe reinit logic matters more than "store actor forever"

### Distrust B41-era human-NPC mod portability as proof

Older `IsoPlayer`/`IsoSurvivor` success stories prove historical possibility, not Build 42 support.

Practical meaning for LWN:

- `33_LWN_Carrier_IsoPlayer.lua` and `34_LWN_Carrier_IsoSurvivor.lua` are historical comparison spikes, not the strategy to scale
- every time the branch relies on them, it reopens a fight that the current research set does not endorse

## What The Best Reference Mods Actually Prove

## Bandits proves the shell pattern, not true conversion

This is the single most important reference conclusion from `docs/reference/REFERENCE_CORPUS_ISOZOMBIE_AUDIT_2026-03-20.md`.

What Bandits actually proves:

- an `IsoZombie` can be used as the stable world actor
- that shell can be marked as special with variables and sidecar brain identity
- visuals can be continuously rewritten to look human-ish
- zombie sound identity can be suppressed or redirected
- behavior can be clamped and steered enough to sell a bandit illusion

What Bandits does not prove:

- true human AI/runtime conversion
- automatic safety semantics
- that descriptor-only work is sufficient

The reusable LWN lesson is therefore:

- win through repeated illusion maintenance plus separate brain/state ownership
- do not waste effort looking for a magical class conversion step that the best reference does not use

## Human NPC reference lines prove a different lesson

`Superb Survivors`, `PZNS_Framework`, and `Braven's NPC Framework` still matter, but mainly as caution:

- they show that historical human-carrier approaches existed
- they do not give a clean Build 42 endorsement
- they reinforce that human embodiment has always required a lot of manual lifecycle and presentation care

Practical LWN reading:

- mine them for UX, AI, dialogue, and state ideas
- do not read them as evidence that the current branch should return to `IsoPlayer`

## KnoxEventExpanded and similar Build 42 ecosystem references prove staging value, not shell identity

These references help with:

- authored encounter framing
- narrative delivery
- ecosystem expectations for Build 42 content lanes

They do not prove:

- runtime zombie-shell human conversion

## Why This Is A Human Perception / Illusion Maintenance Problem

The core blocker is not "how do we convert object type X into object type Y."

The real blocker is:

- how does the player decide that this thing in front of them is a person and not just a special zombie
- how do we keep that judgment stable across movement, idles, pursuit, interaction, sound, cleanup, and respawn

This is why the problem is distributed across many layers.

### The player reads humanity from cues, not ancestry

The shell is judged from:

- silhouette and outfit
- movement profile and idle posture
- reaction language
- sound identity
- whether the context menu treats it like a person
- whether trust/hostility behavior matches social expectations
- whether zombie tells leak at the wrong moment

That means the branch fails if any one of these loudly says "zombie," even if descriptor plumbing is technically correct.

### A one-shot conversion mindset causes the wrong experiments

If the team keeps asking "what final setter makes the zombie become human," experiments will overfocus on:

- descriptors
- one-time visual application
- inherited base-class methods

But the March 20 corpus says the winning lane is:

- shell spawn
- shell identification
- repeated perception maintenance
- strong separation between canonical person and embodied shell

### LivingWorldNPC already behaves like an illusion-maintenance system

The branch architecture already points this way:

- canonical state in `PopulationStore` and NPC records
- embodiment as a nearby cache in `EmbodimentManager`
- carrier-specific sync in `CarrierAdapter`
- appearance repair in `ActorFactory`
- relation-driven shell posture in `Carrier_IsoZombie`
- special-case UI targeting in `UI_ContextMenu`

The missing piece is not architecture reinvention. It is discipline: stop treating any zombie-shell experiment as if it were secretly a full human runtime.

## Current Strongest Architectural Direction For LivingWorldNPC

## Canonical model

Keep the current canonical rule:

- NPC truth lives in ModData-backed records, never in the live actor object

That remains correct for Build 42 and is even more important under zombie reuse/pooling risk.

## Embodied model

Treat nearby embodiment as:

- `record` = person
- `handle` = current carrier session
- `actor` = disposable shell instance

For `spike/isozombie`, the shell should be assumed to be:

- world-valid
- visually steerable
- socially frameable
- behaviorally steerable only in limited ways
- never the authority on identity

## Responsibility split

Recommended split for the current branch:

### 1) `PopulationStore` / schema

Own:

- identity
- trust/respect
- memories
- goals
- inventory/loadout intent
- death/removal lifecycle

### 2) `CarrierAdapter` and carrier modules

Own:

- spawn/sync/retire routing
- carrier-specific runtime assumptions
- carrier-specific metadata on the shell

### 3) `ActorFactory`

Own:

- appearance shaping helpers
- hybrid debug instrumentation
- generic presentation probes and repair

But stop treating it as the place that can turn zombies into humans.

### 4) `Carrier_IsoZombie`

Own:

- shell spawning
- relationship-driven aggression/neutralization
- appearance pass scheduling
- shell-level marker stamping

This should be the practical center of the current spike.

### 5) `UI_ContextMenu`, dialogue UI, radial UI, command UI

Own:

- social framing
- discoverability
- reassurance to the player that this is a managed NPC, not random undead noise

## Short architectural slogan

For this branch, the right mental model is:

"Human identity in records, zombie shell in world, illusion maintained continuously."

## Detailed Actionable Lessons

## Appearance

### What to keep doing

- keep using descriptor and human-visual shaping as a seed layer
- keep stamping hybrid metadata so the branch can compare intended presentation against observed presentation
- keep carrier-aware branching so zombie shells do not receive unsafe human-only setters

### What to stop assuming

- descriptor success does not equal visual success
- clothing success does not equal presentation-role success
- one refresh pass is unlikely to be enough if the zombie pipeline restamps later

### Practical lesson for next work

The next appearance experiments should test zombie-presentation override boundaries directly, not just more descriptor polish.

Current code surfaces to focus on later:

- `23_LWN_ActorFactory.lua:applySafeAppearanceShaping(...)`
- `23_LWN_ActorFactory.lua:refreshActorPresentation(...)`
- `35_LWN_Carrier_IsoZombie.lua:runAppearancePass(...)`
- current debug dump surfaces in `92_LWN_DebugTools.lua`

## Animation

### What the research implies

- Build 41 and wiki material both suggest animation/model layers are separate, but not fully under easy Lua control
- the branch should therefore aim first for "less zombie-coded" motion, not "perfect human locomotion"

### Practical lesson

Test for the specific undead tells that break the illusion most:

- idle sway
- attack windup
- pursuit posture
- transition snaps after sync

If perfect animation replacement is not available, design around exposure:

- use calmer states for friendly/neutral shells
- avoid forcing unnecessary movement churn
- prefer social/UI framing when motion remains imperfect

## Audio

### What the references prove

Bandits' strongest audio lesson is not fancy voice acting. It is suppression of unmistakable zombie audio.

### Practical lesson

Audio is one of the cheapest illusion wins still available:

- suppress tiny repeated zombie footstep/voice tells before chasing deeper animation work
- give hostile/friendly/neutral tests an audio checklist, not just a visual checklist

Current branch files that should stay part of this conversation later:

- `35_LWN_Carrier_IsoZombie.lua` for relation posture
- future sound-script work under `media/scripts` if needed

## AI / State

### What is real today

The current branch can already push the shell into coarse modes:

- hostile pursuit
- neutralized
- idle-ish / clear-queue posture

### What is not real today

- true human social AI inside the shell
- trustworthy one-flag suppression of all zombie aggression channels

### Practical lesson

Model the shell as a constrained puppet:

- canonical AI decides intent
- shell receives clamped zombie-compatible state
- non-hostile shells should be judged by "does the illusion stay socially plausible" rather than "did we perfectly disable every zombie subsystem"

This is why movement churn matters so much. Even if the shell is non-hostile, constant retreat/repath noise makes it read as unstable undead behavior.

## Identity

### Strongest lesson

Identity must survive shell loss, shell replacement, cleanup, and pooling.

### Practical rule

Never let any gameplay-important truth depend on:

- a specific actor reference
- zombie object lifetime
- a single create hook firing

Instead:

- keep `record.id` canonical
- restamp `LWN_NpcId` and `LWN_CarrierKind`
- preserve shell session metadata only as debug/runtime hints

## Lifecycle

### What the branch already learned the hard way

- embodied actors vanish, desync, die, or linger in cleanup edge cases
- death objects and leftover zombie/corpse world objects can confuse identity
- debug deletion during combat is particularly dangerous

### Practical lesson

The shell architecture is only viable if lifecycle rules stay conservative:

- clear ownership markers carefully
- allow handle-based recovery where still useful
- preserve canonical death/removal in records first
- treat actor cleanup as shell cleanup, not truth cleanup

## UX / UI framing

### Why this is not optional

UI is not cosmetic here. It is part of the embodiment system.

Without UI framing, players will default to "special zombie."

### Practical lesson

Keep building cues that say "person":

- context menu label
- dialogue window routing
- quick command affordances
- concise relationship state/debug readouts during experiments

In other words, when animation cannot fully carry humanity, UI should close the gap.

## Experiment-Priority Roadmap

This roadmap is intentionally practical for the next session on `spike/isozombie`.

## Phase 0: Immediate next-session priorities

These are the highest-value experiments because they directly answer the current branch's biggest uncertainty: where the illusion is actually breaking.

### Priority 1: Confirm the real appearance ceiling on a live shell

Question:

- after `applySafeAppearanceShaping(...)` reports success, which visible cues still remain unmistakably zombie?

Test first:

1. Spawn one debug NPC with `IsoZombie` carrier only.
2. Use the existing nearest-NPC debug dump surfaces.
3. Capture:
   - relation policy summary
   - hybrid summary line
   - presentation role
   - body/skin identifiers
   - visible clothing state
4. Repeat after a fresh sync and after brief movement.

Why first:

- it determines whether the next work should stay in appearance, move to audio, or move to motion suppression

Current files implicated:

- `35_LWN_Carrier_IsoZombie.lua`
- `23_LWN_ActorFactory.lua`
- `92_LWN_DebugTools.lua`

### Priority 2: Stabilize friendly/neutral non-hostile posture

Question:

- does a supposedly non-hostile shell still leak zombie intent through movement churn, repathing, or repeated micro-activation?

Test first:

1. Force `friendly`.
2. Force `neutral`.
3. Stand near the shell and then move away slightly.
4. Record:
   - whether it repaths
   - whether it retreats repeatedly
   - whether it turns toward the player too often
   - whether it can still attack or "wants" to attack

Why second:

- an unstable non-hostile shell destroys the illusion even faster than imperfect clothes

Current files implicated:

- `35_LWN_Carrier_IsoZombie.lua:applyRelationshipCombatState(...)`
- `13_LWN_Social.lua`

### Priority 3: Run an audio-suppression pass before deeper animation work

Question:

- are the remaining "this is a zombie" cues primarily audible right now?

Test first:

1. Spawn one shell in quiet surroundings.
2. Observe idle audio and micro-steps.
3. Repeat in hostile, neutral, and friendly policy states.
4. Log whether sound leaks happen during spawn, idle, retarget, or movement.

Why third:

- audio suppression is often cheaper and higher-yield than solving animation parity

### Priority 4: Harden identity observations against shell replacement/recovery

Question:

- when the shell goes missing and is recovered or respawned, do the right `LWN_NpcId`, carrier kind, and relation markers come back consistently?

Test first:

1. Spawn a shell.
2. Walk far enough to trigger despawn/rearm/re-embody behavior.
3. Return and confirm:
   - same canonical NPC id
   - correct carrier kind
   - relation summary still matches the record
   - context menu still targets the shell as the same NPC

Why fourth:

- this is where Build 42 pooling risk becomes a real gameplay bug instead of a documentation warning

Current files implicated:

- `25_LWN_EmbodimentManager.lua`
- `31_LWN_CarrierAdapter.lua`
- `26_LWN_UI_ContextMenu.lua`

### Priority 5: Measure how much UI framing compensates for imperfect embodiment

Question:

- if the shell still moves slightly zombie-like, does current UI framing salvage player interpretation enough for the spike to remain viable?

Test first:

1. Spawn one friendly shell.
2. Use context menu, dialogue window, and radial menu.
3. Note whether the actor feels like "a managed NPC with imperfect animation" or "a zombie with debug UI glued on."

Why fifth:

- this decides how much the branch should invest in presentation polish versus social affordances

## Phase 1: Medium-term experiments after Phase 0 answers

Only move here after the top five priorities above produce stable notes.

### 1) Target zombie-presentation boundaries directly

If Phase 0 confirms that descriptor and clothing are working but the shell still renders as zombie, the next experiments should probe:

- zombie body skin selection
- presentation-role sources
- reapplication timing after movement/state changes
- whether any engine-side post-spawn pass is overwriting the shell after LWN sync

### 2) Separate "hostile shell" and "friendly shell" presentation goals

Do not require one animation/pose profile to solve both cases.

Recommended split:

- hostile shell: allow more active motion if behavior reads clearly dangerous
- friendly shell: prioritize calmness, stability, and reduced surprise

### 3) Add explicit experiment logs/checklists

The next session should record for each run:

- branch commit
- carrier kind
- relation state
- whether appearance applied
- whether audio leaked
- whether context targeting worked
- whether shell recovered cleanly after distance/despawn

### 4) Decide whether any B42 asset work is justified

Only after the runtime boundary is clearer should the branch invest in:

- custom sound definitions
- model/script assets
- curated encounter staging for first-impression control

## Phase 2: Only later if needed

These are valid, but not first-line tasks.

### 1) Deeper animation/model asset pipeline work

Only worth it if Phase 0 proves the shell is otherwise stable and socially useful.

### 2) Java-side escalation

Only worth it if:

- a very specific runtime wall is identified
- Lua-accessible tools are exhausted
- the project is willing to accept heavier maintenance debt

### 3) Revisiting human carriers

Only later if a new Build 42 surface appears or a tightly scoped comparison spike is needed.

Current research does not justify returning to `IsoPlayer` as the main plan.

## Practical Next-Session Execution Checklist

Use this order:

1. Spawn exactly one `IsoZombie` debug shell.
2. Dump nearest-NPC summary plus hybrid line immediately after spawn.
3. Force `friendly`, record posture and audio.
4. Force `neutral`, record posture and audio.
5. Force `hostile`, confirm pursuit/attack posture.
6. Walk away and return to test shell continuity.
7. Use the context menu and quick-command surfaces.
8. Write down the first cue that still breaks the "human" read.

If the first breaking cue is:

- zombie body/skin or presentation role: stay on appearance/presentation boundaries
- repetitive sounds: move audio suppression up
- movement churn while non-hostile: move state suppression up
- shell identity loss after despawn: move lifecycle/identity hardening up

## Final strategic summary

The branch should proceed as if Bandits taught the right lesson:

- not "convert the class,"
- but "own the identity, own the illusion, and keep restamping the shell."

For LivingWorldNPC, the `IsoZombie` path remains the strongest current carrier direction because it matches Build 42 world reality better than `IsoPlayer`, while still leaving room for human-perceived presentation through appearance, state, audio, and UI framing.
