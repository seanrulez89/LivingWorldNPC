# Build 42 IsoZombie NPC Web Memo - 2026-03-20

Project: LivingWorldNPC  
Scope: official Build 42 docs + high-signal web context for an `IsoZombie`-shell NPC approach  
Intent: complement local repo/reference-mod audit; docs only, no gameplay-code changes

## Bottom line

The `IsoZombie` shell path is still the least-bad Build 42 carrier for a visible/interactive fake-NPC, but the official API surface strongly suggests a hard ceiling:

- you **can** shape an `IsoZombie` with human-facing data (`SurvivorDesc`, outfit choice, `HumanVisual`, worn items, descriptor-ish identity)
- you **can** manipulate some zombie hostility/targeting state (`getTarget`, `setTargetSeenTime`, fake-dead/reanimate/useful-useless flags, crawl/walk posture, thump state)
- you **cannot infer from official docs** that an `IsoZombie` can be turned into a true human/NPC runtime with player/survivor combat semantics, safety semantics, or survivor AI just by copying appearance/state
- Build 42 specifically adds/clarifies **object pooling / instance reuse** on zombies, which breaks a lot of older B41-style assumptions for survivor/bandit mods that attached persistent identity directly to object instances

My read: the current hybrid idea is valid **only** if treated as a zombie-carrier plus human-presentation/state grafts. Treating the shell as secretly becoming an `IsoPlayer`/`IsoSurvivor` is the false lead.

---

## Official API facts that matter for the shell approach

### 1) `IsoZombie` already exposes more human-facing surface than it first appears

Official Javadocs show `IsoZombie` implements `IHumanVisual` and inherits the huge `IsoGameCharacter` surface.

Relevant official `IsoZombie` methods visible in docs:

- appearance / identity-adjacent
  - `getVisual()`
  - `dressInPersistentOutfitID(int)`
  - `setFemaleEtc(boolean)`
  - inherited `getDescriptor()`, `getHumanVisual()`, `getWornItems()`, `getItemVisuals()`, `setWornItem(...)`, `dressInNamedOutfit(...)`, `Dressup(...)`, `resetModel()`, `resetModelNextFrame()`
- targeting / behavior / zombie state
  - `getTarget()`
  - `isTargetInCone(...)`
  - `setTargetSeenTime(float)`
  - `pathToLocationF(...)`
  - `Wander()`
  - `setUseless(boolean)`
  - `setFakeDead(boolean)`, `setForceFakeDead(boolean)`, `setWasFakeDead(boolean)`
  - `setReanimate(boolean)`, `setReanimatedPlayer(boolean)`
  - `setCanWalk(boolean)`, `setCrawler(boolean)`, `setBecomeCrawler(boolean)`
  - `setSitAgainstWall(boolean)`
  - `setThumpCondition(...)`, `setThumpFlag(int)`, `setThumpTimer(int)`
- survivability / presentation oddities
  - `setImmortalTutorialZombie(boolean)`
  - inherited `getSafety()` appears on the surface via `IsoGameCharacter`

Implication:

- `setFemaleEtc(...)` is **not** a fake/decompiled ghost method here; it is documented on `IsoZombie`.
- `getSafety()` existing on the inherited surface does **not** mean zombie carriers participate in human PVP/faction safety rules the same way players do. It only proves the method is present on the common base API.

Sources:

- Official `IsoZombie` Javadocs: <https://projectzomboid.com/modding/zombie/characters/IsoZombie.html>
- Official `IsoGameCharacter` Javadocs: <https://projectzomboid.com/modding/zombie/characters/IsoGameCharacter.html>

### 2) `SurvivorDesc` remains the cleanest shaping artifact

Official `SurvivorDesc` docs confirm useful non-runtime identity and appearance hooks:

- `getHumanVisual()`
- `getItemVisuals(...)`
- `getWornItems()` / `setWornItem(...)`
- `dressInNamedOutfit(String)`
- identity / profile data: `setForename`, `setSurname`, `setProfession`, `setFemale`, personality-ish fields like friendliness/aggressiveness/loyalty

Implication:

- `SurvivorDesc` is good input data for the hybrid plan.
- It looks like a **descriptor/presentation seed**, not evidence that the live `IsoZombie` can inherit survivor AI just because it borrowed the desc.

Source:

- Official `SurvivorDesc` Javadocs: <https://projectzomboid.com/modding/zombie/characters/SurvivorDesc.html>

### 3) `HumanVisual` is real leverage for appearance, but only appearance

Official `HumanVisual` docs expose strong visual control:

- skin/hair/beard/body hair setters
- `setSkinTextureName(...)`
- `dressInNamedOutfit(String, ItemVisuals)`
- `dressInClothingItem(...)`
- `addBodyVisualFromClothingItemName(...)`
- `addClothingItem(...)`
- `synchWithOutfit(...)`

Implication:

- Build 42 absolutely gives tools to make a character *look* more human.
- None of this is evidence for changing the underlying zombie brain/combat/control ownership.

Source:

- Official `HumanVisual` Javadocs: <https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/HumanVisual.html>

### 4) `IsoGameCharacter` exposes NPC-ish knobs, but they are generic base knobs, not a promise of a supported human-NPC runtime

Official `IsoGameCharacter` docs visibly include:

- `getIsNPC()` / `setIsNPC(boolean)`
- `getDescriptor()`
- `getSafety()`
- `isVisibleToNPCs()` / `setVisibleToNPCs(boolean)`
- `setFollowingTarget(...)`
- enemy/local-list accessors
- `getCurrentStateName()`, `getPreviousStateName()`, animation/model reset methods
- death/reanimation lifecycle methods on the base type

Implication:

- These are attractive knobs for experiments.
- But base-class presence is a trap: it does **not** guarantee every subclass has the full supporting runtime behind the knob.
- Your local evidence already points at one likely example: using NPC/player-ish flags on zombie carriers can produce Java-side instability instead of upgraded behavior.

Source:

- Official `IsoGameCharacter` Javadocs: <https://projectzomboid.com/modding/zombie/characters/IsoGameCharacter.html>

---

## Hard limits / likely ceilings for an `IsoZombie` disguised as an NPC

### A. Human appearance is supported; human runtime identity is not clearly supported

What the docs support:

- descriptor-backed naming / profile
- human visual shaping
- clothing/worn-item/model refresh
- some target/alert/fake-dead/crawl/reanimate state nudges

What the docs do **not** support:

- a documented path to swap an `IsoZombie` AI/state-machine core into `IsoPlayer` or `IsoSurvivor`
- a documented path to make zombie carriers obey human safety/faction/PVP semantics just because shared base methods exist
- a documented Build 42 human NPC framework

This is the main ceiling.

### B. Build 42 official direction still says human NPCs are later work, not a supported B42 modding lane

Official Build 42 launch post explicitly says B42 is unstable, disruptive, and not compatible with B41 saves/mods. Public official messaging around NPCs keeps placing the major human-NPC step later (Build 43 era), not as a stable Build 42 modder-facing runtime.

Implication:

- trying to force B42 into a full human-NPC host is fighting the product roadmap
- zombie-shell fakery fits the current engine reality better than full `IsoPlayer` impersonation

Source:

- Official Build 42 Unstable post: <https://projectzomboid.com/blog/news/2024/12/build-42-unstable/>

### C. Zombie instance reuse / pooling is a real Build 42 footgun

PZwiki’s Build 42 `IsoZombie` note says that since Build 42, when an `IsoZombie` instance gets reused to load in a zombie, `OnZombieCreate` is triggered and can be used to initialize it. The same note warns that object pooling means data attached to a specific `IsoZombie` instance can get shuffled around.

Implication:

- B41 patterns that treated a zombie object identity as stable are now actively dangerous.
- Managed NPC metadata must be keyed to your own durable NPC id / `modData` stamps / re-init hooks, not to Lua object identity alone.
- This especially matters for shell ownership, trust/hostility flags, appearance stamps, and cleanup logic.

Source:

- PZwiki `IsoZombie` / `OnZombieCreate` summary via Brave search snippet: <https://pzwiki.net/wiki/IsoZombie>

---

## B41 -> B42 breakage patterns most likely to hit old survivor/bandit mods

These are the specific break classes most relevant to older NPC/survivor/bandit mods.

### 1) Root compatibility break: B41 mods are not compatible with B42

Official Build 42 launch wording is blunt: **Build 41 saves and mods are NOT compatible with Build 42.**

That alone means older NPC mods only "working" after a version bump should be assumed fragile until proven otherwise.

Source:

- <https://projectzomboid.com/blog/news/2024/12/build-42-unstable/>

### 2) Versioned mod layout / new B42+ mod structure expectations

The August 2024 official modding blog post describes the B42+ versioned mod directory approach (`42/`, `common/`, etc.) and explicitly says B41 continues loading from root while B42+ uses the new system.

Implication:

- older survivor/bandit mods written for root-only B41 layout often need structural migration, not just code edits.
- LivingWorldNPC is already using the correct B42-style layout, which is good.

Source:

- Official modding post: <https://projectzomboid.com/blog/news/2024/08/tidy-up-time/>

### 3) Zombie pooling / reuse invalidates many "attach data to object instance" tricks

Old NPC mods that:

- cached zombie references as permanent identities
- assumed `OnZombieCreate` means brand new logical character
- tied trust/faction state to object references instead of stable ids

are now at risk in B42.

Source:

- PZwiki Build 42 `IsoZombie` note on reuse/object pooling

### 4) Event assumptions from the old survivor path are shaky

Official docs still show:

- `OnCreateLivingCharacter` for `IsoPlayer` or `IsoSurvivor`
- `OnCreateSurvivor` for `IsoSurvivor`
- `OnZombieCreate` for zombies

Implication:

- old mods that mixed player/survivor/zombie creation paths loosely and expected one post-create hook to catch all cases are more likely to break.
- for an `IsoZombie` shell, zombie-specific reinit logic matters more in B42 than generic one-time construction assumptions.

### 5) Presentation and lifecycle are stricter than B41-era hack mods often assumed

Official Build 42 surfaces emphasize:

- model reset methods
- `onWornItemsChanged()` / clothing listeners
- corpse/reanimate lifecycle APIs
- explicit scene culling / model manager interactions

Implication:

- older bandit/survivor mods that brute-forced visuals or death states by poking only health/alpha/square fields are even more likely to desync or silently fail in B42.

---

## False leads to avoid

### False lead 1: "If `IsoZombie` has `getSafety()` / `setIsNPC()` / `getDescriptor()`, it can be made into a true survivor"

No. Shared base-class methods are not a guarantee of correct subclass semantics.

This is probably the single most seductive trap in the docs.

### False lead 2: "If the shell can wear human clothes and use `HumanVisual`, the engine will treat it like a human"

No. Appearance tooling is not equivalent to AI/control/runtime role.

### False lead 3: "Use `IsoPlayer` because the constructor exists, then patch away the rest"

This was already questionable in the older audit and still looks questionable. The official docs prove the constructor exists; they do **not** prove B42 provides a stable modder-facing human-NPC runtime around it.

### False lead 4: "Zombie attack suppression can probably be solved by one flag"

Probably not. Official zombie APIs expose several posture/target/fake-dead/usefulness/reanimate/thump knobs, which is a hint that behavior is distributed across multiple state channels.

In practice that means friendliness/neutrality likely needs a bundle of state management, not a single boolean.

---

## Plausible breakthrough directions

These look like the realistic high-upside directions, ordered from safest to riskiest.

### 1) Double down on "zombie carrier + human presentation" as the mainline

Use:

- `SurvivorDesc` for identity/outfit seeding
- `HumanVisual` + worn items + model resets for appearance
- durable `modData` / NPC-id stamping for ownership
- `OnZombieCreate`-aware reinit logic for pooled instances

Avoid trying to pretend the carrier is actually a player/survivor.

### 2) Treat friendliness/neutrality as behavior suppression, not true alliance

Instead of trying to grant real human social semantics, treat the shell as:

- zombie that is prevented from selecting/keeping hostile targets
- zombie whose pursuit/thump/crawl/fake-dead/useful state is constantly curated
- managed shell with a separate higher-level trust model in your own records

That aligns better with the API surface actually documented.

### 3) Explore descriptor/visual refresh timing around pooling and clothing updates

There may be extra mileage in careful ordering of:

- descriptor seed
- outfit seed
- visual sync
- worn-item propagation
- `onWornItemsChanged()`
- `resetModel()` / `resetModelNextFrame()`
- zombie-create/reuse reapplication

This is the best area for a real breakthrough because it is strongly supported by docs and less likely to fight engine intent.

### 4) If safety/attackability matters, probe zombie-specific invulnerability/suppression instead of human safety semantics

The surface suggests `setImmortalTutorialZombie(...)`, fake-dead controls, target-seen timing, and useful/useless posture flags may be more relevant than shared human-ish safety APIs.

That is ugly, but probably closer to the real engine levers for a zombie shell.

---

## Repo-specific implications for LivingWorldNPC

Current repo evidence matches the web picture surprisingly well:

- the repo already leans on `SurvivorDesc`, `HumanVisual`, `dressInNamedOutfit`, `getTarget`, and `OnCreateLivingCharacter` expectations in places
- the docs already note a likely bad interaction around `setNPC(true)` on zombie carriers
- the hybrid-shell plan is directionally right **as long as it remains explicit that the shell is still an `IsoZombie`**

Especially relevant local references:

- `docs/HYBRID_ISOZOMBIE_SHELL_PLAN_2026-03-20.md`
- `docs/CARRIER_ISOZOMBIE_HOSTILITY_EXPLORATION_2026-03-14.md`
- `docs/CARRIER_ISOZOMBIE_FRIENDLY_ATTACK_SUPPRESSION_2026-03-14.md`
- `docs/OFFICIAL_BUILD42_API_AUDIT_2026-03-12.md`
- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/24_LWN_ActorSync.lua`

Concrete code/doc observations from this pass:

- repo still calls `setFemaleEtc(...)` in the actor factory/sync path; official docs say this is a real `IsoZombie` method, so that specific call is not the problem by itself
- repo still probes `getTarget`/`getTargetChar`; official docs confirm `getTarget()` exists on zombies, so target-state experiments are on solid surface area
- repo notes a likely `setNPC(true)` crash path; official docs do not make that call look safe for zombie carriers, so the current suspicion is credible

---

## Practical verdict

If the question is "Can Build 42 support a convincing NPC-like entity by using an `IsoZombie` shell?" then the answer is **yes, partially**.

If the question is "Can Build 42 support turning an `IsoZombie` into a true human NPC by layering descriptor/visual/safety flags onto it?" then the answer is **probably no, or not in a stable/documented way**.

So the best working stance is:

- **carrier:** `IsoZombie`
- **identity/appearance source:** `SurvivorDesc` + `HumanVisual` + worn items
- **social semantics:** owned by LWN record data, not by assuming engine-native human-NPC semantics
- **behavior management:** zombie-specific suppression/retargeting/fake-dead/usefulness/state curation
- **state durability:** stable NPC id + `modData` + reuse-aware reinit, never raw object identity alone

That is ugly, but it is honest.

---

## Source list

Official:

- `IsoZombie` Javadocs: <https://projectzomboid.com/modding/zombie/characters/IsoZombie.html>
- `IsoGameCharacter` Javadocs: <https://projectzomboid.com/modding/zombie/characters/IsoGameCharacter.html>
- `IsoPlayer` Javadocs: <https://projectzomboid.com/modding/zombie/characters/IsoPlayer.html>
- `IsoSurvivor` Javadocs: <https://projectzomboid.com/modding/zombie/characters/IsoSurvivor.html>
- `SurvivorDesc` Javadocs: <https://projectzomboid.com/modding/zombie/characters/SurvivorDesc.html>
- `SurvivorFactory` Javadocs: <https://projectzomboid.com/modding/zombie/characters/SurvivorFactory.html>
- `HumanVisual` Javadocs: <https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/HumanVisual.html>
- Build 42 Unstable announcement: <https://projectzomboid.com/blog/news/2024/12/build-42-unstable/>

Supporting / semi-official:

- PZwiki `IsoZombie` (object pooling / `OnZombieCreate` reuse note): <https://pzwiki.net/wiki/IsoZombie>

Local companion docs:

- `docs/OFFICIAL_BUILD42_API_AUDIT_2026-03-12.md`
- `docs/HYBRID_ISOZOMBIE_SHELL_PLAN_2026-03-20.md`
