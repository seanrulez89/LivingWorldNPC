# PZwiki Build 42 review for LivingWorldNPC's IsoZombie-shell path

_Date: 2026-03-20_
_Project: LivingWorldNPC_
_Scope: Critical review of the following PZwiki pages, filtered for what matters to a Build 42 IsoZombie-shell NPC strategy:_

- Modding
- Scripts
- Lua (API)
- Java
- User Interface
- Modeling
- Animation
- Mapping
- Rendering
- Translation

## Executive read

The listed PZwiki pages are useful as a **terrain map**, not as a final authority. For this project, they are most valuable in three ways:

1. **They confirm the shape of the supported modding lanes** in Build 42: scripts for data definitions, Lua as the normal runtime bridge, Java as the “break glass” path, UI as a first-class mod surface, animation/model assets as increasingly modernized B42 content, and translations as newly JSON/UTF-8 centered.
2. **They expose where the wiki is thin, unstable, or aspirational.** A lot of the Build 42 pages are flagged as unstable-beta updates, partially incomplete, or full of redlinks/stubs. That matters because the project is specifically pushing on one of the hardest edges: making a zombie-backed actor read as human.
3. **They indirectly reveal the right strategy for embodiment.** The cleanest path is not “make the engine believe this really is a human NPC everywhere.” The better path is “use the lanes the game already wants to support—appearance, animation, UI, text, audio, and state framing—to make a zombie-shell actor be *perceived* as a human system.”

My bottom line after reading these pages critically:

- **Directly promising lanes:** Lua-driven behavior orchestration, careful use of exposed Java objects/methods, script-defined models/items/sounds/entities where useful, B42 animation/model pipeline work, UI overlays/panels/context feedback, translation-backed labeling/text framing, and map/scene staging.
- **High-risk / fragile lanes:** full Java-class replacement for production, assuming the wiki’s script docs are complete, assuming mapping tools are B42-ready, assuming animation/model docs imply simple plug-and-play actor replacement, and assuming “rendering” helps in-game embodiment beyond presentation collateral or flier/media-style content.
- **False lead to avoid:** treating this as a pure “NPC AI” problem. For an IsoZombie-shell project, it is equally a **perception design** problem: silhouette, pacing, idles, reactions, gear readability, naming, UI affordances, social framing, and selective suppression of the undead cues players key on.

---

## Method and source quality notes

### How I accessed the pages

The live wiki was behind Cloudflare for direct extraction, so I used a text mirror route (`r.jina.ai`) to recover the page bodies. The content appears to be current mirror text of the named PZwiki pages.

### Important reliability warning

The pages themselves repeatedly warn that they are:

- updated to various **unstable Build 42 point versions**, not always the current one,
- partially incomplete,
- dependent on other pages that are redlinked or stubbed,
- and still mid-transition from Build 41 assumptions.

So the wiki is best used here as:

- **good for topology**,
- **good for vocabulary**,
- **good for finding supported surface areas**,
- **bad for exact boundaries unless cross-checked against JavaDocs/decompilation/in-project testing**.

That is especially true for this mod, because the project is trying to inhabit an edge case the wiki does not directly document: an actor that is systemically zombie-derived but socially read as human.

---

## The human-perception problem

This is the core design issue the wiki does not state outright but all the relevant pages circle around.

A player decides “that thing is a human” long before any AI sophistication is noticed. The judgment is mostly made from:

1. **silhouette**
2. **stance and gait**
3. **micro-idles and transitions**
4. **attack / flinch / recovery language**
5. **hair, outfit, and body variation**
6. **whether UI and text systems name/frame it as a person**
7. **whether the actor participates in expected social affordances**
8. **whether undead tells leak through at the wrong moments**

For an IsoZombie shell, this means the embodiment problem is not only “can the object move and think?” but:

- can it stop broadcasting “zombie” through animation state choices,
- can it acquire enough human-readable presentation to override system ancestry,
- and can the mod fill the missing social cues through UI/text/audio design where animation or rendering control is incomplete.

### What the reviewed pages imply

The pages together imply a practical split:

- **Scripts / Modeling / Animation** tell you how to define and import assets.
- **Lua (API) / Java** tell you how deeply you can poke runtime state.
- **User Interface / Translation** tell you how to label, explain, and stabilize player interpretation.
- **Mapping / Rendering** tell you how to stage encounters and collateral, not how to solve runtime embodiment by themselves.

That suggests a layered human-perception strategy:

1. **Body layer** – clothes, model hooks, hair/props, clean silhouette.
2. **Motion layer** – less zombie-like idles/transitions, or at least selective animation masking.
3. **Feedback layer** – names, relationship marks, context prompts, state icons, dialogue/noise surrogates.
4. **Scene layer** – introduce these actors in contexts that reinforce humanity.
5. **Rule layer** – suppress or reroute obviously undead behaviors that destroy the illusion.

This is the most important design takeaway from the wiki pass.

---

## Directly useful facts

## 1) Modding page: broad lane map, but not a decision-maker by itself

Even without reprinting the whole page, the category structure it links around is useful: PZ modding is explicitly divided into Scripts, Lua, Java, User Interface, Modeling, Animation, Mapping, Rendering, and Translation.

### Why that matters to LivingWorldNPC

This page is useful mainly because it confirms that the project should be thought of as **multi-surface modding**, not “just Lua AI work.”

For a zombie-shell NPC, the correct stack is probably:

- **Lua** for orchestration and in-game state handling,
- **exposed Java objects** for low-level character/zombie manipulation where Lua reaches through,
- **animation/model assets** for embodiment,
- **UI/translation** for social framing and player comprehension,
- **scripts** for asset definitions and supporting data,
- **mapping** only for curated encounter staging or test scenes,
- **rendering** only for out-of-band presentation/media.

### Practical implication

If the mod keeps treating embodiment as a pure carrier/behavior problem, it will likely underinvest in the surfaces that actually make players read the actor as human.

---

## 2) Scripts page: useful for asset definitions, weak for solving runtime personhood

The Scripts page is one of the more concretely useful ones.

### Hard facts from the page

- Scripts are **custom data definition files**, not a general programming language.
- They live under `media/scripts` and use `.txt` files.
- Commas at the end of key-value pairs are mandatory.
- Module scoping and import behavior exist, but the page itself warns that script resolution can be inconsistent and recommends explicit module prefixes.
- Build 42 script docs are incomplete and many block pages are redlinked or partial.
- The page points to **PZ Scripts Data / ScriptsDocs** as the more complete reference.
- Important script blocks listed include:
  - `item`
  - `model`
  - `sound`
  - `entity`
  - `animation` (not well documented on the page)
  - `mannequin`
  - `character_profession_definition`
  - `character_trait_definition`
  - `sandbox options`

### Direct use for this project

Scripts matter here mostly for **supporting embodiment assets**, not for runtime AI.

Most relevant uses:

- **model scripts** to bind models/textures/animations into usable game-facing definitions,
- **sound scripts** if the project wants “human” non-verbal audio or less-zombie-coded sound identities,
- **item scripts** for embodiment props, special visual signifiers, or debug/testing artifacts,
- **sandbox options** to expose shell-behavior toggles and perception-experiment toggles cleanly,
- possibly **entity/mannequin** references as clue surfaces for visual staging or testing.

### What this page says indirectly

The wiki frames scripts as a data layer parsed/cached by Java. That is a quiet but important warning:

- scripts are excellent for defining resources and structured content,
- but they are a poor place to expect emergent “human-like” runtime behavior.

So for LivingWorldNPC, scripts should be treated as **resource plumbing and config**, not the heart of the illusion.

### Fragility warnings

- The page openly says not all script blocks are fully documented.
- There are many redlinks and stubs.
- The page itself warns syntax and resolution behavior can be inconsistent.
- File override behavior sounds dangerous for compatibility.

### Best project use

Use scripts where they clearly fit:

- model declarations,
- sound definitions,
- asset registration,
- option exposure,
- content labels.

Do **not** plan the core NPC architecture around undocumented script tricks.

---

## 3) Lua (API) page: the main supported control surface

This is one of the most relevant pages.

### Hard facts from the page

- Project Zomboid’s Lua layer is Kahlua / Lua 5.1-ish, with exposed Java classes and methods.
- Lua events are a primary way to get runtime access to objects.
- The page explicitly uses `OnZombieUpdate` and `IsoZombie` as a canonical example.
- Exposed Java methods are reachable via normal Lua syntax:
  - `instance:methodName(...)` for instance methods
  - `ClassName.methodName(...)` for static methods
- `LuaManager.GlobalObject` functions are exposed as global Lua functions like `getPlayer()` and `getCell()`.
- Only public members are exposed normally.
- Reflection-style field access is possible but ugly/expensive; the page also mentions helper libraries like Starlit Library.
- The page warns that Java-object access via Lua has performance costs.
- Constructors do not necessarily create fully valid live entities in the way modders may assume.

### Why this matters a lot

This page quietly confirms the project’s current architectural instinct: **Lua is the normal place to steer an IsoZombie-backed runtime actor**.

The critical phrase for this project is basically: _events hand you real runtime objects, including zombies._

That means the project can keep thinking in terms of:

- inspecting/managing live `IsoZombie` instances,
- shaping their state from Lua,
- using JavaDocs/decompilation to find exposed methods that control animation/state/descriptor/reaction surfaces,
- and only escalating to Java mods if a decisive capability wall is reached.

### Direct embodiment implications

The Lua page supports a “behavior wrapper” architecture:

- observe the zombie shell in update events,
- clamp or redirect states that leak undead identity,
- apply presentation or metadata choices when the shell enters/changes states,
- sync UI labels/markers/tooltips with shell identity,
- and maintain a companion data model for the “person” that the shell is representing.

### Important limit implied by the page

Lua is a bridge to Java, not magic.

If the methods needed to fully override deep animation state selection, pathfinding identity, social interaction semantics, or internal zombie assumptions are not exposed, Lua can only go so far.

So Lua is the best first lane, but not a promise of total control.

### Performance warning relevant to NPC swarms

The page’s note on performance is not theoretical. For NPC populations, frequent Java-object method calls or reflection-style field scans can become expensive quickly.

For this project, that implies:

- prefer sparse state syncs over constant deep polling,
- cache identifiers/references when possible,
- avoid reflection-heavy patterns in per-tick loops,
- and reserve expensive inspection for debug or coarse intervals.

### Best use for the project

Use Lua as the **control plane** and **illusion maintenance layer**, not as a brute-force everything-every-tick rewrite layer.

---

## 4) Java page: real power, real maintenance debt

### Hard facts from the page

- Java modding is more powerful than Lua.
- It has major distribution and maintenance drawbacks.
- Traditional Java mods are not normal Workshop-friendly content and often require manual installation.
- Overwriting classes is brittle against updates.
- Tools like Leaf and ZombieBuddy are named as ways to do more targeted modifications.
- As of the page text, Build 42 uses Java 25 and custom Java work must match that.
- The page explicitly recommends starting with Lua unless necessary.

### Direct implication for LivingWorldNPC

This page is basically a warning label.

Yes, Java can probably solve more of the “make a zombie shell act unlike a zombie” problem.
But if the mod’s goal is a broadly usable Build 42 mod with tolerable maintenance cost, Java should be treated as:

- **a scalpel**, not the default lane,
- **an escalation path**, not the first architecture,
- and probably **a last resort for specific missing hooks**, not a full class-rewrite plan.

### When Java becomes justified

Only if one of the following turns out to be impossible or too ugly in Lua:

- suppressing or replacing the exact undead animation logic that ruins the illusion,
- altering internal classification/AI branching that hardcodes zombie assumptions,
- exposing missing state needed for safe orchestration,
- or creating a compatibility-preserving injection point that Lua cannot reach.

### Critical note

The Java page is accurate in spirit, but dangerously easy to overread. “More power” does not mean “better path.” For this project, Java is likely the wrong first embodiment lane unless the illusion is blocked by a specific engine seam.

---

## 5) User Interface page: much more relevant than it first looks

This page is directly useful.

### Hard facts from the page

- UI is natively supported via Lua.
- `ISUIElement` is the central class family.
- UI files should live client-side under `media/lua/client/...`.
- Vanilla-style composition via child UI elements is recommended.
- There are direct drawing functions and standard widgets.
- The page explicitly encourages using LuaDocs for UI APIs.
- The page strongly implies mod compatibility is better when you use the normal ISUIElement family instead of ad hoc drawing-only approaches.

### Why this matters to human perception

If the shell sometimes cannot fully *be* human in engine terms, UI can help the player reliably *read* it as human.

UI can carry a huge amount of the social framing burden:

- names over actors,
- relationship state icons,
- trust/affinity indicators,
- contextual prompts that are human-coded rather than undead-coded,
- inspect panels with biography/status information,
- portraits or symbolic identity badges,
- dialogue-ish speech bubbles or interaction panes,
- debug overlays during embodiment experiments.

### Strong design implication

For this project, UI is not just admin tooling. It is part of the embodiment stack.

A shell that visually reads 70% human but is consistently:

- named,
- framed,
- contextualized,
- and explained through UI,

will often be perceived as a human NPC more successfully than a shell that is visually 85% correct but receives zero social framing.

### Concrete opportunities

- Hover/nearby panel showing a proper person name and role.
- Interaction radial or context options that are clearly human-social verbs.
- Subtle “recognized survivor” badge language rather than debug-like labels.
- Tooltip/state strings that explain shell oddities diegetically instead of exposing them as bugs.
- Optional dev overlay that highlights which cues currently break the illusion.

### Caveat

UI cannot save obviously feral motion or attack language. But it can drastically improve interpretation once the worst animation tells are handled.

---

## 6) Modeling page: confirms modern asset lanes, but mostly as support work

### Hard facts from the page

- Modeling is for creating 3D models used in-game or for rendering.
- Blender is the common community tool.
- B42-relevant formats include:
  - `.fbx`
  - `.glb`
  - `.x` is explicitly not recommended
- FBX can be hot-reloaded.
- GLB can bundle animation and is useful for niche applications like clothing or tiles.

### What matters for LivingWorldNPC

This page confirms that a custom embodiment layer is viable in principle:

- clothing pieces,
- props,
- visual body-affordance elements,
- alternate model hookups,
- or subtle silhouette-correcting assets

are not outside the expected modding model.

### Best interpretation for this project

Modeling is likely most useful for **perception polish**, not core control.

Examples:

- accessories or body-layer assets that reduce “zombie read,”
- special silhouettes that make the shell look more civilian/survivor-like,
- test props to see what players key on most strongly,
- attachment-based tricks if supported through model scripts/animations.

### Important limitation

The page does **not** mean “swap in a human model and the problem is solved.”

If motion, posture, reaction timing, sound, and social framing remain zombie-coded, better geometry alone will not create a human NPC in player perception.

---

## 7) Animation page: the single most important non-code clue page

This page is extremely relevant.

### Hard facts from the page

- Custom animation in PZ involves rigs, export formats, and defining `AnimNode` usage.
- Build 42 uses an animation content structure including:
  - `anims_X`
  - `AnimSets`
  - `ActionGroups`
  - `AnimStates`
  - `AnimNode`
  - transition definitions
- `.glb` is recommended; `.fbx` still works; `.x` is not recommended.
- Files can replace same-relative-path files.
- The page presents entity-specific animation structures and state trees.

### Why this matters more than it first appears

This page reframes the embodiment problem from “how do I make an NPC?” to “how do I control the state machine that determines what kind of body-language the shell emits?”

That is exactly the right question.

For a zombie-shell human illusion, the most damaging moments are often not pathfinding or combat logic. They are:

- idle stance,
- turn-in-place behavior,
- locomotion blend,
- stumble cadence,
- hit reaction,
- pursuit posture,
- fall/recovery logic,
- attack windup,
- and transitions between these.

The Animation page tells us those are not a single blob. They live in a structured animation pipeline.

### Direct project implication

If the project can selectively redirect or replace the most telling zombie states with more neutral/human-readable ones, the perceptual win could be huge even without true human AI.

That suggests experiment lanes like:

- identify the small set of states that most strongly scream “zombie,”
- test replacement or masking of those states first,
- treat idle/walk/turn/hit-reaction as top priority,
- treat attack/pursuit/falldown as second-wave depending on intended interaction model.

### Important caution

The page documents the asset/state structure, but not the exact difficulty of injecting a zombie-shell into a human-like AnimSet pipeline. That remains a major unknown.

So the page is useful as a conceptual map, but not proof of easy implementation.

### Highest-value inference

For LivingWorldNPC, **animation work may buy more “human perception” than deeper AI work at this stage**.

That is probably the most important inference from the whole wiki set.

---

## 8) Mapping page: relevant mostly for staging, not for core embodiment

### Hard facts from the page

- B42 mapping tools are not fully officially ready; the page says official B42 tools are pending stable release.
- Existing official tools are outdated for B42.
- Unofficial tools exist and are being used.
- Maps live under `media/maps/...`.
- Replacing existing map cells is coarse and heavy; you cannot trivially drop a single building into an existing cell without broader replacement.
- The page has obvious stubs and incomplete sections.

### Direct implication for this project

Mapping is **not** the main lane for solving shell embodiment.

However, it is relevant for:

- controlled test spaces,
- encounter choreography,
- social-context staging,
- safe observation rooms / debug maps,
- authored setpieces where shell behavior is read more favorably.

### Why staging matters

Humans are more likely to read an actor as human if introduced in a human-coded context:

- inside a camp,
- around furniture,
- near survivor-signaling props,
- in spaces that suggest domesticity, trade, conversation, or work.

So mapping is not solving the actor, but it can drastically help **scene-level perception**.

### Fragility / caution

Because B42 tooling is still in transition, mapping-heavy plans are risky if the project’s actual blocker is embodiment. It would be easy to disappear into environment work while the shell itself still moves like the dead.

### Best use

Use mapping lightly and surgically:

- dedicated embodiment test scenes,
- curated reveal scenes,
- maybe one or two social vignettes.

Do not make mapping a prerequisite for proving the shell concept.

---

## 9) Rendering page: mostly a false lead for runtime embodiment, but useful for collateral and design study

### Hard facts from the page

- Rendering is about generating 2D images from 3D scenes in external tools.
- The page explicitly frames it as indirectly linked to modding.
- Main uses include mod presentation and in-game media like fliers.
- It points to tutorials for setting up PZ characters in Blender.

### Direct implication

For runtime NPC embodiment, this page is largely a **non-solution**.

Rendering does not make the shell act more human in game.

### Where it *is* useful

- generating concept art or comparative sheets of shell variants,
- mockups of visual readability tests,
- in-world print media/fliers if the project wants to seed lore or faction identity,
- workshop presentation assets,
- previsualizing clothes/hair/accessories before asset implementation.

### Best project use

Treat rendering as a design support and communication tool, not a gameplay/embodiment lane.

---

## 10) Translation page: surprisingly important for identity and social framing

This page is more useful than it looks.

### Hard facts from the page

- Build 42.15.0 moved translations to `.json` and UTF-8 broadly.
- There are many translation domains/types, including:
  - `UI`
  - `Tooltip`
  - `ContextMenu`
  - `ItemName`
  - `Entity`
  - `SurvivorNames`
  - `Mod`
  - map-related location strings
- The page shows structured translation keys and JSON schema support.
- It confirms translation is a first-class, organized system rather than a hacky afterthought.

### Why this matters to the project

Translation is part of **identity presentation**.

For human perception, text strings matter a lot:

- what the actor is called,
- what verbs appear when interacting with it,
- what labels and tooltips imply about its status,
- whether the mod speaks in a human-social vocabulary or an undead/debug one.

### Concrete opportunities

- Use `SurvivorNames`-style naming ideas or equivalent structured naming support for broad personhood variation.
- Keep UI/context labels consistently human-coded.
- Avoid exposing internal shell terms to players unless intentionally diegetic.
- Add translation-backed descriptors for occupation, relationship, mood, or trust state.
- Support localization early if this project expects broad playtesting; social read is partly linguistic.

### Hidden value

Translation files also make it easier to iterate tone. If a given naming scheme makes players think “pet zombie” instead of “survivor,” translation-backed wording can be changed quickly without deeper code changes.

---

## Embodiment and presentation implications

This is the synthesis section the wiki pages point toward.

## A. The shell should be treated as an actor with a costume, motion language, and social wrapper

The project should not ask only:

- “Can the shell follow commands?”
- “Can the shell avoid attacking friendlies?”
- “Can the shell carry state?”

It should also ask:

- “What does the player think this thing is within 250 ms of seeing it?”
- “What single animation frame or transition gives away the undead core?”
- “What text/context affordance repairs trust after a suspicious movement?”
- “What presentation cues buy the most human read per hour of implementation work?”

## B. Human read probably comes from suppressing a few high-signal zombie tells, not solving everything

The Animation/Modeling/UI pages together suggest a realistic strategy:

Find the top 20% of cues causing 80% of the “that’s a zombie” read.

Likely candidates:

- idle hunch / tension posture,
- locomotion cadence,
- attack anticipation,
- twitch/stumble loops,
- hit reaction/falldown style,
- vocalization/sound set,
- corpse/decay visual cues,
- lack of human-coded naming and interaction verbs.

If those are reduced, the shell may become legible enough as “strange survivor” even if deeper systems remain zombie-born.

## C. UI and naming are not cosmetic extras; they are embodiment multipliers

The User Interface and Translation pages strongly support this.

An actor that:

- has a stable proper name,
- presents relationship/context affordances,
- exposes inspectable state in human language,
- and participates in familiar UI verbs,

will be perceived as more human than a visually superior actor that the game still frames as an anonymous hostile creature.

## D. Sound likely matters even though the reviewed pages only touch it indirectly

The Scripts page lists sound blocks. The rest of the review implies that audio should be part of the embodiment stack.

If the shell keeps zombie groans, the illusion collapses fast.

Even simple alternatives could help:

- silence under conditions where a zombie would vocalize,
- human-ish exertion/breath sounds,
- contextual non-verbal cues,
- radio/voice stand-ins if full dialogue is impossible.

## E. Scene context can compensate for partial embodiment limits

Mapping and Rendering are secondary, but the Mapping page in particular implies authored contexts are available.

A shell introduced as:

- standing guard,
- seated near domestic props,
- moving between task-relevant locations,
- associated with shelters, supplies, names, and notes,

will read more human than the same shell shambling across open road space with no context.

---

## Rendering / animation / model pipeline clues

This section focuses on the most actionable pipeline hints.

## 1. Modern formats are favored: GLB and FBX, not X

Both Modeling and Animation explicitly say:

- `.glb` is increasingly preferred/recommended,
- `.fbx` remains acceptable and hot-reload friendly,
- `.x` is legacy and not recommended.

### Implication

If the project invests in embodiment assets now, it should bias toward the B42-modern lane rather than legacy asset assumptions.

## 2. Animation is state-structured, not just clip-based

The Animation page’s description of `AnimSets`, `ActionGroups`, `AnimStates`, `AnimNodes`, and transitions is the key clue.

### Implication

Do not think only in terms of “replace animation X with animation Y.”
Think in terms of:

- which state family is active,
- which transitions expose zombie-ness,
- and whether a shell can be routed to a more human-neutral state subset.

## 3. Hot reload support lowers experimentation cost

Modeling/Animation note hot reload for FBX and GLB-related asset workflows.

### Implication

This is ideal for rapid embodiment experiments:

- tweak a posture,
- tweak a prop placement,
- tweak a motion clip,
- compare human-read immediately.

That makes animation-first testing more attractive than large architecture rewrites.

## 4. Model scripts probably act as the bridge layer

The Scripts page listing `model` blocks matters because it implies the art pipeline is not isolated. It can connect to actual in-game definitions.

### Implication

A useful embodiment experiment stack is likely:

1. author/adjust model or animation asset,
2. register/bind it through scripts,
3. activate or route it through Lua-controlled runtime state,
4. evaluate human-read in a controlled scene.

## 5. Character rigs and existing entity structures matter more than “new NPC from scratch” fantasies

The Animation page points to character rigs and to entity-specific animation structures.

### Implication

The likely winning strategy is not inventing an entirely new being. It is parasitizing existing supported rig/state structures and bending them toward the project’s perception goals.

That is very consistent with an IsoZombie-shell approach.

---

## UI / translation / design opportunities

These are the most promising non-animation opportunities surfaced by the wiki pass.

## 1. A proper “personhood wrapper” UI layer

Build a thin but polished UI system that makes the shell read as a social actor.

Candidate features:

- hover nameplate with proper first/last name or role-based display name,
- trust/familiarity iconography,
- inspect panel with status that uses human framing,
- context menu verbs like Talk / Check / Trade / Ask Follow / Stand Guard,
- optional debug overlay showing shell state, active presentation mask, and known illusion breaks.

## 2. Translation-driven identity packs

Because Translation is JSON/UTF-8 in modern B42, it is easy to centralize:

- naming pools,
- faction naming language,
- role descriptors,
- interaction verbs,
- diegetic status strings,
- flavor text for notes/media that contextualize NPC presence.

This is low-risk, high-leverage work.

## 3. In-world textual scaffolding

The Translation and Rendering pages together hint at a neat lane:

- notes,
- flyers,
- print media,
- labels,
- map descriptions,
- shelter signage,

can all build the sense of human presence even before the shell is perfect.

## 4. Tone control as perception control

If players see strings like “subject,” “carrier,” “shell,” or “managed zombie,” the illusion dies.
If they see “survivor,” “guard,” “neighbor,” “runner,” “medic,” “scavenger,” etc., the same system is interpreted very differently.

That is not cheap trickery. It is core UX.

---

## Outdated, fragile, or incomplete parts of the reviewed material

This section matters because the pages often sound more definitive than they are.

## Global issues across the set

- Many pages are updated to **different unstable B42 point versions**, not the latest current one.
- Several pages explicitly ask for help updating to newer point versions.
- Many subordinate pages are redlinks or stubs.
- Build 41 terminology/examples still bleed through in places.
- The category is useful, but not consistently mature.

## Specific fragilities

### Scripts

- The page says documentation is incomplete.
- Some script block docs do not exist yet.
- It warns of inconsistency in syntax/behavior across block types.
- Therefore: great starting map, weak final reference.

### Lua (API)

- Good conceptual overview, but too broad to define exact exposed capabilities.
- Must be cross-checked with JavaDocs/decompilation/actual runtime tests.

### Java

- Correctly warns about maintenance burden, but can tempt people into over-escalation.
- The tool mentions (Leaf, ZombieBuddy) are clues, not guarantees of a project-safe path.

### User Interface

- Strong practical intro, but not remotely exhaustive enough for a large in-game social UI.
- Good for confirming lane viability, not final implementation detail.

### Modeling / Animation

- Good directional guidance, but actual production difficulty still depends heavily on rig compatibility, asset specifics, and engine expectations not fully documented here.
- The existence of a pipeline does not mean the shell can trivially inherit human-style animation behavior.

### Mapping

- Explicitly incomplete, and B42 tooling is still transitional.
- Dangerous to overcommit here.

### Rendering

- Least relevant to the runtime problem.
- Useful, but easy to waste time on if mistaken for a gameplay lane.

### Translation

- One of the better pages, but still partly in transition due to the recent JSON/UTF-8 B42 changes.
- Good lane, but must match actual in-project file expectations.

---

## False leads and traps

These are the ideas the reviewed pages might accidentally encourage, but which look like poor bets for this project.

## 1. “Just use Java and solve it properly”

Tempting, but likely wrong as a first move.

Why it is a trap:

- distribution pain,
- maintenance pain,
- update brittleness,
- likely overkill before proving exactly what Lua/asset/UI work cannot do.

## 2. “Scripts can probably define most of the NPC”

No. Scripts are data definitions, not a substitute for runtime orchestration and perception management.

## 3. “Rendering is part of the embodiment solution”

Not really. It is presentation collateral and concept support.

## 4. “Mapping will make them feel human”

Only indirectly. Good staging helps, but a shambling corpse in a nicely dressed campsite is still a shambling corpse.

## 5. “If the model is good enough, players will read it as human”

Model quality helps, but gait and reaction language usually dominate in motion-heavy reads.

## 6. “The wiki documents everything needed for B42 animation/entity work”

It does not. It points in the right direction, but there are too many stubs/redlinks/unstable-version mismatches.

---

## Concrete next experiments

These are the most useful experiments implied by the reviewed pages.

## Experiment 1: Human-read triage matrix

Goal: discover which cues most strongly break the illusion.

Method:

- Put one shell actor in a controlled test scene.
- Vary only one cue at a time:
  - nameplate on/off,
  - survivor outfit on/off,
  - idle variant A/B,
  - walk variant A/B,
  - zombie vocalization on/off,
  - context verbs human-coded vs generic.
- Record first-impression judgments.

Why it matters:

This will identify the highest-yield embodiment work instead of guessing.

## Experiment 2: Idle / walk / turn replacement priority pass

Goal: prove whether animation-state work buys enough human read to justify pipeline investment.

Method:

- Focus on the smallest high-frequency state set:
  - idle
  - walk
  - turn / rotate-in-place
- Try to neutralize the most zombie-coded motion patterns.
- Ignore advanced states at first.

Expected value:

Very high. These are the states players see constantly.

## Experiment 3: UI personhood wrapper prototype

Goal: measure how much social framing alone improves perception.

Build:

- hover nameplate,
- trust/status icon,
- basic inspect panel,
- human-social context verbs.

Expected result:

Even with imperfect motion, this should materially improve “that is a person” read.

## Experiment 4: Translation-driven naming and role system

Goal: decouple identity presentation from implementation details.

Build:

- JSON-backed names,
- role descriptors,
- contextual tooltip strings,
- faction/social labels.

Expected value:

High, low-risk, and it will improve both polish and iteration speed.

## Experiment 5: Audio suppression / substitution pass

Goal: remove one of the fastest illusion-killers.

Method:

- identify shell situations where standard zombie sounds occur,
- suppress them where possible,
- test neutral silence first,
- then test light human-coded non-verbal cues if asset support exists.

Expected value:

Potentially huge. Groans and feral cues can ruin everything instantly.

## Experiment 6: Curated encounter scene

Goal: test whether environmental framing can salvage partial embodiment.

Build one small authored setup:

- shelter-like scene,
- shell actor with proper outfit/nameplate,
- survivor-coded props,
- interaction affordance.

Measure whether first-impression human read improves.

## Experiment 7: Strict escalation criterion for Java

Goal: prevent architecture drift.

Before any Java escalation, require a written failure case:

- what exact exposed Lua/asset/UI path was tried,
- what precise hard limit was hit,
- what specific Java hook would solve it,
- why that hook is worth long-term maintenance cost.

This keeps Java from becoming a vague fantasy answer.

## Experiment 8: Build an “illusion breaker” checklist

Create a living checklist of observed cues that reveal the shell as undead, for example:

- wrong idle posture,
- wrong gait cadence,
- vocalization mismatch,
- attack anticipation,
- no proper name,
- hostile cursor treatment,
- context menu mismatch,
- wrong hit reaction,
- corpse/decay textures,
- weird rotation speed,
- pathing choices that feel feral.

This will turn embodiment from a fuzzy goal into an observable test discipline.

---

## Practical project recommendations

## Recommendation 1: treat embodiment as a multidisciplinary stack

Going forward, the project should track work under at least these lanes:

- runtime control,
- motion/animation,
- visual embodiment,
- social/UI framing,
- text/identity,
- audio suppression/substitution,
- scene/context staging.

## Recommendation 2: prioritize perception wins over deep system purity

A shell that is 70–80% human-readable and stable is more valuable than an architecturally pure solution that still feels undead to players.

## Recommendation 3: use the wiki as a compass, not a contract

For any nontrivial claim from these pages, especially around Scripts, Lua exposure, and animation pipeline details, verify against:

- JavaDocs,
- decompilation,
- runtime experiments,
- and the existing project docs already produced in this repo.

## Recommendation 4: move UI/translation higher in the roadmap

They are not side polish. They are likely part of the minimum viable human-perception package.

## Recommendation 5: do not let mapping/rendering distract from the main loop

Useful supporting lanes, yes.
Core blocker solvers, no.

---

## Per-page verdict summary

### Modding
- **Usefulness:** medium
- **Value:** category map / lane framing
- **Risk:** low, but generic
- **Verdict:** good orientation, not enough by itself

### Scripts
- **Usefulness:** high for asset/config definition
- **Value:** model/sound/item/sandbox/entity support
- **Risk:** medium-high due to incompleteness and inconsistency
- **Verdict:** use for plumbing, not core behavior

### Lua (API)
- **Usefulness:** very high
- **Value:** main control/orchestration lane for shell management
- **Risk:** medium; exposed-surface uncertainty and performance costs
- **Verdict:** primary runtime lane

### Java
- **Usefulness:** high as an escalation path
- **Value:** precise hard-limit escape hatch
- **Risk:** very high for maintenance/distribution
- **Verdict:** only for narrowly justified blockers

### User Interface
- **Usefulness:** very high
- **Value:** social framing and personhood wrapper
- **Risk:** low-medium
- **Verdict:** should be treated as core embodiment work

### Modeling
- **Usefulness:** medium-high
- **Value:** silhouette/visual polish/support assets
- **Risk:** medium
- **Verdict:** important support lane, not sufficient alone

### Animation
- **Usefulness:** extremely high
- **Value:** strongest non-AI lever for human-read embodiment
- **Risk:** high technical uncertainty, but high upside
- **Verdict:** probably the highest-leverage next deep lane

### Mapping
- **Usefulness:** medium
- **Value:** staging, test scenes, curated encounters
- **Risk:** medium-high due to B42 tooling transition
- **Verdict:** use surgically, not as backbone

### Rendering
- **Usefulness:** low for runtime, medium for support
- **Value:** presentation/previsualization/media
- **Risk:** low, but distractible
- **Verdict:** support only

### Translation
- **Usefulness:** high
- **Value:** naming, UI language, interaction framing, localization
- **Risk:** low-medium due to format transition details
- **Verdict:** strong, low-risk identity layer

---

## Final conclusion

The PZwiki pages do **not** reveal a secret clean “NPC creation” path for a Build 42 IsoZombie-shell project. What they do reveal is more useful:

They show that the likely winning approach is a **layered illusion architecture**.

- Use **Lua** as the runtime control plane.
- Use **Animation** as the main bodily-humanization lever.
- Use **Modeling** for silhouette and support assets.
- Use **UI** and **Translation** to make the shell legible as a person.
- Use **Scripts** for asset/config registration.
- Use **Mapping** only for staged tests and curated contexts.
- Use **Java** only when a specific, proven hard limit demands it.
- Use **Rendering** for concept/presentation, not runtime problem-solving.

If the project wants NPCs to be perceived as human, the right question is no longer just:

> How do we control an IsoZombie?

It is:

> How do we make an IsoZombie-backed actor emit enough human body language, naming, context, and interaction framing that players stop reading the underlying class ancestry as the truth of what it is?

That is the lane these wiki pages most strongly point toward.
