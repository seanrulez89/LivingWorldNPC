# Build 41.78 Javadoc Skeptical Audit for Build 42 IsoZombie-Shell Work

Date: 2026-03-20
Project: LivingWorldNPC
Scope: documentation only
Primary question: what, if anything, from the public Build 41.78 javadocs still helps an experimental Build 42 design where the live in-world shell remains `IsoZombie` but should be perceived as human?

## Sources reviewed

Primary entry points requested:

- `https://zomboid-javadoc.com/41.78/index.html`
- `https://zomboid-javadoc.com/41.78/overview-tree.html`

Targeted class pages reviewed for evidence:

- `https://zomboid-javadoc.com/41.78/zombie/characters/package-tree.html`
- `https://zomboid-javadoc.com/41.78/zombie/characters/IsoGameCharacter.html`
- `https://zomboid-javadoc.com/41.78/zombie/characters/IsoLivingCharacter.html`
- `https://zomboid-javadoc.com/41.78/zombie/characters/IsoPlayer.html`
- `https://zomboid-javadoc.com/41.78/zombie/characters/IsoSurvivor.html`
- `https://zomboid-javadoc.com/41.78/zombie/characters/IsoZombie.html`
- `https://zomboid-javadoc.com/41.78/zombie/characters/SurvivorDesc.html`
- `https://zomboid-javadoc.com/41.78/zombie/core/skinnedmodel/visual/IHumanVisual.html`
- `https://zomboid-javadoc.com/41.78/zombie/core/skinnedmodel/visual/BaseVisual.html`
- `https://zomboid-javadoc.com/41.78/zombie/core/skinnedmodel/visual/HumanVisual.html`
- `https://zomboid-javadoc.com/41.78/zombie/core/skinnedmodel/advancedanimation/AnimatedModel.html`
- `https://zomboid-javadoc.com/41.78/zombie/iso/objects/IsoDeadBody.html`

Local repo context referenced while interpreting this:

- `docs/plans/HYBRID_ISOZOMBIE_SHELL_PLAN_2026-03-20.md`
- branch: `spike/isozombie`

---

## Executive verdict

The Build 41.78 javadocs are useful mainly as a **concept map**, not as safe implementation truth for Build 42.

The strongest carryover is this:

- in Build 41.78, `IsoZombie`, `IsoPlayer`, `SurvivorDesc`, `AnimatedModel`, and even `IsoDeadBody` all touch a shared **human-visual presentation surface** through `IHumanVisual` / `HumanVisual`
- `IsoGameCharacter` owns a `descriptor` (`SurvivorDesc`) and a large amount of general character/animation/inventory state
- `IsoZombie` is **not** on the same gameplay branch as `IsoPlayer` / `IsoSurvivor`, but it still participates in human visual presentation and rendering

That is exactly why the current LivingWorldNPC direction is not crazy: there is Build 41 evidence that a zombie-class carrier can still be part of a human-looking presentation pipeline.

But the risky part is just as important:

- Build 41.78 does **not** prove that Build 42 preserves the same class relationships, model hooks, animation wiring, or descriptor semantics
- Build 41.78 also does **not** prove that making an `IsoZombie` look human will make the engine, AI, combat, hit logic, factions, targeting, or UI treat it like a human
- in fact, the hierarchy strongly suggests the opposite: gameplay semantics and visual semantics were already partially decoupled in Build 41, which means appearance transfer is much safer than behavioral transfer

So the right Build 42 reading is:

- **appearance shaping ideas:** probably still worth probing
- **behavior/combat identity borrowing:** high risk, likely wrong unless proven in Build 42 with instrumentation

---

## Confirmed observations

### 1) `IsoZombie` and `IsoPlayer` share an `IsoGameCharacter` ancestor, but diverge immediately after that

Evidence:

- `zombie/characters/package-tree.html` shows:
  - `IsoObject -> IsoMovingObject -> IsoGameCharacter`
  - `IsoGameCharacter -> IsoLivingCharacter -> IsoPlayer -> IsoSurvivor`
  - `IsoGameCharacter -> IsoZombie`
- `IsoGameCharacter.html` lists direct known subclasses including `IsoLivingCharacter`, `IsoZombie`, and others
- `IsoLivingCharacter.html` lists direct known subclasses `IsoPlayer` and `IsoSurvivor`

What this confirms:

- `IsoZombie` is not a subtype of `IsoLivingCharacter`
- `IsoZombie` does not inherit the `IsoLivingCharacter -> IsoPlayer` path
- Build 41 already had two different gameplay branches:
  - the human/living branch
  - the zombie branch

Why it matters for LivingWorldNPC:

- trying to make a live `IsoZombie` behave exactly like a player/survivor by inheritance assumptions is already suspect in Build 41 terms
- the safer reading is that both branches share a large common base (`IsoGameCharacter`), but not a unified gameplay identity

### 2) `IsoGameCharacter` is the real shared substrate for a lot of useful state

Evidence from `IsoGameCharacter.html`:

- field `descriptor` is a `SurvivorDesc`
- field `advancedAnimator` exists
- `actionContext` exists
- `wornItems`, `attachedItems`, inventory fields, hand model fields, `stateMachine`, `stats`, `BodyDamage`, and network/model-related fields exist
- methods include clothing/body-visual helpers such as:
  - `addBodyVisualFromClothingItemName(...)`
  - `addBodyVisualFromItemType(...)`
  - `dressInClothingItem(...)`
  - `dressInNamedOutfit(...)`
  - `dressInPersistentOutfit(...)`
  - `dressInPersistentOutfitID(...)`
  - `dressInRandomOutfit()`

What this confirms:

- Build 41 centered a lot of cross-character state in `IsoGameCharacter`
- outfit and body-visual manipulation were not player-exclusive at the base API surface
- descriptor and visual dressing concepts were tightly associated with general game-character infrastructure

Why it matters:

- if Build 42 still has an analogous shared character substrate, that is the most plausible location for transferable ideas
- it supports the current local design instinct: borrow **descriptor/outfit/presentation inputs**, not full player identity

### 3) `IsoZombie` in Build 41.78 explicitly participates in `IHumanVisual`

Evidence:

- `IsoZombie.html` lists implemented interfaces including `IHumanVisual`
- `IHumanVisual.html` lists known implementing classes:
  - `AnimatedModel`
  - `IsoDeadBody`
  - `IsoMannequin`
  - `IsoPlayer`
  - `IsoZombie`
  - `SharedDescriptors.Descriptor`
  - `SurvivorDesc`
  - others
- `IsoZombie.html` includes a `getVisual()` entry in its method summary

What this confirms:

- Build 41 did not reserve human-visual plumbing only for `IsoPlayer`
- zombies, dead bodies, descriptors, and render helpers all shared a common human-visual contract

Why it matters:

- this is the single strongest piece of evidence in favor of the LivingWorldNPC shell experiment
- it means there was at least one engine design in which “zombie gameplay identity” and “human visual presentation hooks” coexisted in one object

### 4) `IHumanVisual` is a very small contract; that is revealing

Evidence from `IHumanVisual.html`:

Methods are only:

- `getHumanVisual()`
- `getItemVisuals(ItemVisuals)`
- `isFemale()`
- `isZombie()`
- `isSkeleton()`

What this confirms:

- the human-visual bridge is intentionally narrow
- it is about presentation descriptors, not general gameplay capability

Why it matters:

- this cuts against any fantasy that `IHumanVisual` equals “the engine will treat this as a human NPC”
- it is evidence for a **presentation adapter**, not a behavior adapter

### 5) `HumanVisual` is a rich appearance object, separate from the actor class hierarchy

Evidence from `HumanVisual.html`:

- it extends `BaseVisual`
- it exposes appearance-oriented methods such as:
  - `isFemale()`
  - `isZombie()`
  - `isSkeleton()`
  - `setSkinColor(...)`
  - `setSkinTextureIndex(...)`
  - `setSkinTextureName(...)`
  - `setHairModel(...)`
  - `setBeardModel(...)`
  - blood/dirt/hole methods
  - `synchWithOutfit(Outfit)`
  - `dressInNamedOutfit(...)`
  - `dressInClothingItem(...)`
  - body visual add/remove helpers
  - `setForceModel(...)`
  - `setForceModelScript(...)`

What this confirms:

- appearance data was abstracted into a dedicated visual object, not hardwired to only one runtime actor type
- clothing/outfit/skin/hair/model selection existed as its own layer

Why it matters:

- for Build 42 shell work, appearance should be treated as a separately testable layer
- the shell may only need enough hooks to feed a `HumanVisual`-like subsystem, rather than needing full human gameplay identity

### 6) `SurvivorDesc` is both descriptor/state and an `IHumanVisual` implementer

Evidence:

- `SurvivorDesc.html` shows `getHumanVisual()`, `getItemVisuals(...)`, `isFemale()`, `isZombie()`, `isSkeleton()`
- it also exposes name/profession/personality/state methods like:
  - `getForename()`, `setForename(...)`
  - `getSurname()`, `setSurname(...)`
  - `getProfession()`, `setProfession(...)`
  - `setFemale(...)`
  - `dressInNamedOutfit(...)`
  - various personality traits (`setBravery`, `setAggressiveness`, etc.)

What this confirms:

- Build 41 used a descriptor object that straddled identity and visual concerns
- descriptor-driven outfit/name/gender shaping is not just speculative; it existed as a concrete API surface

Why it matters:

- reusing a descriptor-like object as a **shaping artifact** remains one of the most defensible carryovers for Build 42
- but it still says nothing about Build 42 combat semantics

### 7) `AnimatedModel` can be fed either `HumanVisual` or `SurvivorDesc`

Evidence from `AnimatedModel.html`:

- implements `IHumanVisual`
- has `setVisual(HumanVisual)`
- has `setSurvivorDesc(SurvivorDesc)`
- has `setCharacter(...)`
- has `setAnimSetName(...)`
- has `setOutfitName(...)`
- has render/update lifecycle methods:
  - `update()`
  - `isReadyToRender()`
  - `renderMain()`
  - `DoRender(...)`
  - `DoRenderToWorld(...)`
  - `postRender(...)`
  - `releaseAnimationPlayer()`

What this confirms:

- in Build 41, rendering/animation could consume multiple upstream identity/appearance sources
- descriptor, visual, and live character were distinct but interoperable presentation inputs

Why it matters:

- conceptually, this supports a Build 42 architecture where:
  - canonical NPC record -> descriptor-like shaping -> visual object -> live shell presentation
- that layered architecture is far safer than “make zombie secretly be player”

### 8) `IsoPlayer` and `IsoZombie` both expose `render(...)`, `preupdate()`, `update()`, `load(...)`, `save(...)`, and visual accessors, but that does not mean parity

Evidence:

- `IsoZombie.html` and `IsoPlayer.html` both show render/update/load/save style methods
- both list `getVisual()` in their method summaries
- both ultimately inherit from `IsoGameCharacter`

What this confirms:

- there was some shared lifecycle vocabulary at the class surface level
- both actor types were model/render/update participants

What it does **not** confirm:

- identical animation sets
- identical state machines
- identical targeting/combat rules
- safe substitution of one for the other

Why it matters:

- Build 42 work should treat similarly named methods as **surface resemblance only** until runtime tests prove equivalence

### 9) The engine had non-live objects that still implement `IHumanVisual`

Evidence:

- `IHumanVisual.html` lists `IsoDeadBody` among implementers
- `IsoDeadBody.html` includes `getVisual()`, `isFemale()`, `isZombie()`, `render(...)`, and `reanimate()`

What this confirms:

- the human-visual pipeline was broader than live controllable actors
- a body/corpse/reanimation lifecycle also intersected presentation state

Why it matters:

- Build 42 shell experiments may benefit from thinking in terms of **presentation carriers** rather than only “is this a player or a zombie?”
- but again: visual compatibility does not imply behavioral compatibility

---

## Probable carryovers

These are not confirmed for Build 42. They are simply the most plausible concepts to test first because they do not depend on Build 41-specific inheritance tricks.

### A) Descriptor-first appearance shaping probably still transfers conceptually

Reasoning:

- Build 41 strongly separates actor runtime from descriptor/visual data sources
- `SurvivorDesc` and `HumanVisual` are explicit shaping layers
- `AnimatedModel` accepts descriptor/visual inputs separately from a live character

Likely Build 42 interpretation:

- keep the canonical NPC identity outside the shell
- derive name/gender/outfit/body/hair/skin intent in a descriptor-like or record-backed staging object
- push only the safe appearance subset into the live shell

For LivingWorldNPC:

- current local idea in `docs/plans/HYBRID_ISOZOMBIE_SHELL_PLAN_2026-03-20.md` lines up with this almost perfectly

### B) `IsoZombie` may still be able to drive a human-looking model/presentation path

Reasoning:

- Build 41 `IsoZombie` already implemented `IHumanVisual`
- `HumanVisual` explicitly contains `isZombie()` and zombie rot/skeleton presentation helpers like `pickRandomZombieRotStage()`
- this suggests the visual system already knew that “human model family” and “zombie-ness” are not binary opposites

Likely Build 42 interpretation:

- a zombie carrier may still be able to host model/visual data that reads as human or near-human
- even if exact class names changed, the engine probably still has some version of presentation flags, outfit data, and model scripts

### C) Outfit/item visual synchronization is probably safer to borrow than AI/combat state

Reasoning:

- Build 41 `HumanVisual` exposes outfit sync and clothing item helpers directly
- `IsoGameCharacter` exposes body visual and outfit dressing helpers at base level

Likely Build 42 interpretation:

- if any Build 42 shell experiment succeeds, clothing, body visuals, hair, skin, and model script selection are more plausible success points than faction/combat semantics

### D) Animation/render lifecycle likely still exists as a staged process

Reasoning:

- Build 41 `AnimatedModel` has a clear prepare/update/render/postRender/release pattern
- `IsoGameCharacter` includes animator and action-context state

Likely Build 42 interpretation:

- there is probably still a distinction between:
  - canonical actor state
  - animation variables / animator state
  - model assembly
  - render
- Build 42 testing should instrument each stage separately instead of treating “appearance failed” as one single problem

### E) The narrowness of `IHumanVisual` likely reflects an enduring engine design principle

Reasoning:

- the interface is so small that it looks like an intentional adapter boundary
- that kind of boundary often survives refactors better than concrete classes do

Likely Build 42 interpretation:

- even if names changed, expect some small adapter or accessor boundary for visual identity data
- search Build 42 for equivalents of:
  - human visual getter
  - item visual collector
  - female/zombie/skeleton presentation flags

---

## Likely Build 42 breakages

These are the places where Build 41 knowledge is most likely to mislead.

### 1) Class hierarchy assumptions are dangerous

Why:

- Build 42 may have refactored inheritance, animation ownership, or networking significantly
- the presence of `IsoPlayer`, `IsoZombie`, `IsoSurvivor`, or even `SurvivorDesc` in Build 41 does not guarantee the same role or existence in Build 42

Specific risk:

- designing around exact Build 41 ancestry like `IsoGameCharacter -> IsoLivingCharacter -> IsoPlayer` may be wasted effort if Build 42 reorganized character classes

### 2) `IsoSurvivor` is especially suspect as a source of truth

Why:

- in the Build 41 hierarchy it is a subclass of `IsoPlayer`
- but Build 42 NPC work may no longer align with the old survivor branch at all
- its javadoc surface is thin here and mostly inherited, which smells like legacy rather than an actively trustworthy future path

Conclusion:

- `IsoSurvivor` is better treated as historical evidence that the game once had a human-NPC/player-adjacent branch, not as a recommended Build 42 implementation target

### 3) `SurvivorDesc` may no longer be a reliable live runtime contract

Why:

- descriptors often survive as data carriers while live systems move elsewhere
- Build 41 descriptor APIs include personality/relationship/profile fields that may have no Build 42 behavioral counterpart or may be unused by modern systems

Specific risk:

- copying Build 41 descriptor personality fields and expecting AI behavior to follow in Build 42 is likely wrong
- descriptor as appearance seed: plausible
- descriptor as full behavior source: dubious

### 4) `HumanVisual` flags do not guarantee perception semantics

Why:

- `IHumanVisual` only exposes visual-ish queries and item visuals
- `HumanVisual` contains zombie/skeleton state too
- therefore “human visual” in Build 41 clearly means “humanoid model presentation layer,” not “everyone in the game will regard this as a human ally”

Specific risk for LivingWorldNPC:

- making the shell render human may still leave it:
  - targetable as a zombie
  - processed by zombie AI/collision logic
  - killable under zombie-only rules
  - excluded from human-only UI/interaction logic

This risk matches the repo’s recent observed result that policy metadata changed without real engine-level behavior changes.

### 5) Animation/model method names may be the same while semantics differ

Why:

- update/render/preupdate/getVisual are generic names
- Build 42 may route them through different animator ownership, model scripts, or state variable sources

Specific risk:

- assuming that because Build 41 `IsoZombie` had `getVisual()` and `render(...)`, Build 42 `IsoZombie` can accept the same mutations or timing is unsafe

### 6) Network/load/save behavior is likely a minefield

Why:

- Build 41 javadocs show load/save/network fields across `IsoGameCharacter`, `IsoPlayer`, and `IsoZombie`
- Build 42 almost certainly changed some replication and ownership logic

Specific risk:

- any attempt to spoof player-like identity inside a zombie shell may break serialization, replication, or lifecycle cleanup even if visuals look correct locally

### 7) `IHumanVisual` implementer lists prove breadth, not safety

Why:

- Build 41 includes `IsoDeadBody`, `IsoMannequin`, `AnimatedModel`, and `SurvivorDesc`
- that means many object types can participate in the same visual contract
- it does **not** mean these types are swappable in gameplay

Specific risk:

- Build 42 shell design must resist over-reading shared interfaces as evidence of interchangeable runtime behavior

---

## Relevance to “make `IsoZombie` be perceived as human”

This is the key design question, and the Build 41 evidence gives a mixed answer.

### What the javadocs support

They support the narrow claim that:

- a zombie-class actor can participate in a humanoid visual pipeline
- a shared descriptor/visual layer can feed multiple consumer types
- appearance, outfit, and model assembly were at least partly independent from the exact gameplay branch

That means the following Build 42 strategy remains reasonable:

- keep `IsoZombie` as the carrier because it survives in the world correctly
- use record/descriptor-like data to shape body, outfit, hair, skin, and model presentation
- treat the shell as a presentation host, not as a secret `IsoPlayer`

### What the javadocs do **not** support

They do not support the stronger claim that:

- if an `IsoZombie` looks human, the engine will classify it as human
- NPCs, the player, or AI systems will automatically change threat, friendship, conversation, or combat behavior
- human-only systems can be borrowed cleanly just because the shell shares `IsoGameCharacter`

### The skeptical bottom line

If the actual target is:

- “make this shell render and present as human”

then Build 41 offers meaningful conceptual guidance.

If the actual target is:

- “make every subsystem treat this zombie shell as a human NPC”

then Build 41 is mostly warning tape. The hierarchy and interfaces suggest those identities were already distinct in Build 41, and Build 42 has even more opportunity to have split them further.

### Most defensible reframing for LivingWorldNPC

Instead of asking:

- “Can we make `IsoZombie` actually be a human?”

The Build 41-informed Build 42 question should be:

- “Which specific subsystems decide ‘human enough’ versus ‘zombie enough,’ and can we satisfy them one by one without leaving the zombie carrier path?”

That decomposes into separate test targets:

- render/model appearance
- clothing/body visuals
- idle/move animation feel
- object picker / highlight / cursor perception
- combat target selection
- ally/enemy relation logic
- UI labels / social affordances
- death/reanimation/cleanup lifecycle

That decomposition is much more consistent with what the Build 41 docs actually show.

---

## Concrete next experiments

These should be Build 42-first experiments, not Build 41 porting exercises.

### Experiment 1: Treat descriptor and visual shaping as a separate pipeline

Goal:

- prove whether the Build 42 shell can ingest human-like appearance data independently of behavior logic

Method:

1. Keep current `IsoZombie` spawn path unchanged.
2. Add explicit debug metadata for four stages:
   - canonical record source
   - descriptor-like shaping source
   - visual/outfit source
   - live shell-applied source
3. For each shell, log whether each stage completed and whether the resulting appearance changed.

Success signal:

- shell remains stable as `IsoZombie`
- human-facing appearance changes are visible and attributable

Failure signal:

- the data seems to apply in metadata only, with no visible model/outfit effect

### Experiment 2: Probe for the smallest Build 42 equivalent of `IHumanVisual`

Goal:

- locate the actual adapter boundary Build 42 uses for humanoid appearance

Method:

- search local Build 42 decomp/source/docs for equivalents of:
  - `getHumanVisual`
  - `getItemVisuals`
  - human/zombie/skeleton presentation flags
  - model script / outfit sync methods
- document exact Build 42 class names and ownership

Success signal:

- identify a thin presentation interface or accessor layer

Failure signal:

- appearance is now deeply entangled in actor-specific classes with no clear adapter boundary

### Experiment 3: Separate “looks human” from “is treated as human” in test scripts

Goal:

- stop conflating presentation wins with behavior wins

Method:

For one controlled shell variant, test and record independently:

- visual silhouette
- clothing/hair/skin correctness
- cursor/highlight behavior
- whether player auto-targeting treats it as hostile
- whether allied NPCs attack it
- whether it can attack / be attacked / be killed under zombie semantics

Success signal:

- a matrix showing exactly which systems still read the shell as zombie

Failure signal:

- tests remain anecdotal and mixed, making iteration noisy

### Experiment 4: Search for Build 42 model lifecycle timing hazards

Goal:

- determine whether appearance writes are happening too early, too late, or to the wrong owner

Method:

Instrument lifecycle edges analogous to Build 41’s:

- pre-update / update
- animator ready state
- model instance creation
- outfit/body visual sync moment
- render-ready moment
- cleanup/release moment

Success signal:

- one stable point where visual application reliably sticks

Failure signal:

- appearance reverts, races, or gets rebuilt after custom application

### Experiment 5: Avoid `IsoPlayer` semantic borrowing; test only isolated data borrowing

Goal:

- keep the experiment honest and reduce false positives

Method:

Allowed borrowed inputs:

- name / gender / profession labels
- descriptor-like outfit choice
- visual/body/hair/skin decisions
- high-level inventory intent if it only affects displayed gear

Disallowed until proven safe:

- player input state
- player combat permissions
- player UI ownership
- player-only state machine variables
- save/load logic expecting a real player

Success signal:

- the shell improves visually without destabilizing carrier behavior

Failure signal:

- hidden player-only assumptions creep in and break runtime behavior

### Experiment 6: Identify which systems decide hostility independently of relation metadata

Goal:

- explain the repo’s observed result that friendly/neutral/hostile metadata changes did not change live behavior

Method:

Build a checklist for each subsystem that may independently classify the shell:

- combat hit resolution
- pathing avoidance / aggro selection
- attack eligibility
- object picker / targeting mask
- AI threat tables or relationship tables
- animation state guards

Success signal:

- one or more concrete subsystems are identified as still reading zombie identity regardless of relation metadata

Failure signal:

- all changes remain at mod-data/debug level only

### Experiment 7: Build a “human perception ladder” instead of a single pass/fail target

Goal:

- replace vague success criteria with graded milestones

Suggested ladder:

1. human-looking model only
2. human-looking model + stable outfit/body visuals
3. human-looking shell not obviously using zombie idle presentation
4. shell no longer highlighted/selected as a normal zombie target
5. shell no longer treated as a zombie threat by friendly NPC logic
6. shell participates in selected human-facing interactions

Why this matters:

- Build 41 evidence suggests different subsystems own different pieces of “human-ness”
- expecting one switch to flip all of them is probably the wrong model

---

## Practical implications for the current branch

For `spike/isozombie`, the Build 41 material supports these immediate decisions:

### Keep doing

- keep `IsoZombie` as the world carrier
- keep hybrid-source stamping and provenance logs
- keep descriptor/outfit/presentation work clearly separated from behavior work
- keep documenting which subsystem changed versus which did not

### Avoid doing

- do not cite Build 41 `IsoPlayer` methods as evidence that Build 42 zombie shells can safely reuse player semantics
- do not use `IsoSurvivor` as if it were a trustworthy Build 42 implementation guide
- do not treat any shared `getVisual()`/`render()` naming as proof of semantic parity

### Strongest Build 41-informed hypothesis worth testing next

- Build 42 may still allow an `IsoZombie` shell to host human-like appearance data through a narrow presentation boundary
- but hostility, combat, and world classification are likely decided elsewhere and must be isolated separately

---

## Final conclusion

The Build 41.78 javadocs are valuable here for one reason: they show a past engine architecture where a zombie runtime object could still plug into a humanoid visual pipeline.

They are **not** a license to assume that a Build 42 `IsoZombie` can inherit or fake its way into full human NPC semantics.

So the durable takeaway is:

- **yes, borrow the idea of descriptor-driven appearance shaping**
- **no, do not trust Build 41 player/survivor behavior assumptions to carry over**
- **treat “perceived as human” as a stack of subsystems to satisfy, not a single type conversion problem**

That interpretation fits both the javadoc evidence and the current repo’s live test results, where metadata-level relation changes did not produce real behavioral changes.
