# LivingWorldNPC Long-Term Vision

Date: 2026-06-16

This document records the user's long-term design vision for LivingWorldNPC. It
is not an implementation commitment for the next patch. It is the north star
that future plans should be checked against.

## Core Vision

LivingWorldNPC is not just a follower mod.

The goal is to create NPCs who feel like real survivors inside Project Zomboid:
people with inventory, jobs, traits, moodles, movement, fear, loyalty, memory,
preferences, relationships, voices, gifts, grudges, and personal stories.

NPCs should be able to become companions, strangers, rivals, threats, burdens,
or sacrifices. The player's group should feel like a small human drama moving
through the zombie apocalypse.

## Design Pillars

### 1. Player-Like Survivors

NPCs should eventually have visible, player-legible equivalents for as many
player-character systems as possible. This does not require true engine-level
inheritance from the player class. The design requirement is that NPCs have these
elements and the player can inspect or understand them:

- inventory
- equipment
- clothing
- profession
- traits
- moodles
- health and injury
- endurance and fatigue
- hunger and thirst
- movement modes
- combat
- item use
- voice/sound
- vehicle passenger behavior
- eventually, vehicle driving if technically feasible

The practical rule is: if the player can experience it, an NPC should eventually
have a compatible representation of it.

The player should be able to check these elements through interaction, status
UI, dialogue, overhead speech, or other in-game feedback.

### 2. Mod Compatibility

The long-term design should avoid hardcoding only vanilla professions, traits,
items, and systems.

Preferred direction:

- Store professions, traits, and item references by stable string/script IDs.
- Read available professions/traits/items from game data when possible.
- Accept unknown modded IDs without destroying records.
- Add compatibility shims only when a target mod is important enough.

This can be delayed if needed. The first priority is making the vanilla-like NPC
loop reliable. But the architecture should not make mod compatibility impossible
later.

### 3. Rich Interaction

Current interaction is right-click context menu. This is acceptable for the
foundation, but not the final interaction model.

Long-term interaction should include:

- right-click NPC menu
- dedicated icon or hotkey-style interaction entry point
- NPC status window
- dialogue and command panel
- giving and receiving items
- stance/order changes
- relationship actions
- narrative conversation hooks

The player should not need to micromanage every small behavior. Interaction
should give direction, not puppeteer every step.

### 4. Personal Narrative and Preferences

Each NPC should have personal history and behavioral flavor.

Possible personal data:

- former profession
- family situation
- trauma
- belief
- secret
- hobby
- favorite foods
- disliked foods
- favorite weapons
- disliked weapons
- preferred places
- places they avoid
- moral limits
- remembered promises
- remembered betrayals

These facts should affect behavior, dialogue, loyalty, fear, stress, and future
autonomous decisions.

### 5. Contextual Speech and Voice

NPCs should communicate their state to the player.

Speech can appear as overhead text. Voice or sound can be used when appropriate,
such as calling for help while cornered.

Speech should be driven by:

- current danger
- injury
- hunger/thirst/fatigue
- relationship to player
- personality
- backstory
- recent memories
- command state
- location
- preferred/disliked items or situations

The player should be able to understand what an NPC is feeling or intending
without opening a debug panel.

### 6. Five Relationship Stages

The current conceptual relationship ladder:

1. Hostile
2. Wary
3. Neutral
4. Friendly
5. Companion

Possible behavioral meaning:

- Hostile: may attack, rob, threaten, or flee from the player.
- Wary: does not trust the player; may talk but keeps distance.
- Neutral: can trade or talk but is not loyal.
- Friendly: accepts more interaction and may cooperate.
- Companion: joins the player's group and accepts squad-level behavior.

Relationship should be dynamic. It can improve through help, gifts, shared
danger, dialogue, and kept promises. It can worsen through neglect, insults,
scarcity, betrayal, friendly fire, abandoned promises, and incompatible values.

### 7. Standing Behavior Guidelines

The player should be able to set broad behavior guidelines instead of issuing
every action manually.

Initial guideline candidates:

- Search supplies
- Watch surroundings
- Attack
- Flee
- Follow
- Autonomous behavior

These are not final names. They are conceptual behavior policies.

Important rule: a guideline should influence decision scoring, not replace all
moment-to-moment judgment. A hungry cowardly NPC and a disciplined fighter should
not behave identically under the same guideline.

### 7.1 Productive Inefficiency

NPCs should not always behave optimally. Some inefficient behavior should be
intentional when it expresses personality, trauma, memory, relationship tension,
or personal narrative.

Examples:

- a frightened NPC falls back instead of holding a perfect formation
- an attached NPC risks danger to help a wounded companion
- a traumatized NPC hesitates near a place that resembles a past loss
- a former doctor prioritizes an injured survivor over looting efficiency
- a resentful NPC follows an order slowly or complains before obeying
- a grieving NPC stops near a meaningful location or object

The rule is not "make NPCs stupid." The rule is "make inefficiency legible." If
an NPC makes a suboptimal choice, the player should often be able to infer why
from dialogue, overhead speech, status, memories, traits, or recent events.

This is one of the main ways to make NPCs feel alive rather than merely useful.

### 7.2 Team Size Pressure

The intended baseline party size is the player plus three companions. Larger
groups should be possible but socially and logistically difficult.

Possible pressure sources:

- food and water demand
- medical supply demand
- noise and visibility
- slower movement
- conflicting personalities
- role dissatisfaction
- fear after casualties
- resentment after unfair item distribution
- stress from overcrowded vehicles or shelters

Good leadership, enough supplies, safe shelter, successful missions, compatible
personalities, and relationship maintenance should make larger groups possible,
but not effortless.

### 7.3 Role Preference and Role Conflict

NPCs should eventually care about what the player asks them to do.

Possible role preferences:

- fighter
- scout
- guard
- medic
- hauler
- driver
- cook
- mechanic
- looter
- caretaker

An NPC can perform disliked work, but repeated mismatch should affect stress,
morale, trust, resentment, and performance. A compatible role should improve
morale and make the NPC feel more useful and distinct.

### 7.4 Team Mood

Individual relationship is not enough. The group should also have a broad team
mood or morale layer.

Team mood may fall after:

- companion death
- repeated injuries
- hunger or thirst
- unsafe sleeping conditions
- failed missions
- friendly fire
- abandonment
- visible unfairness

Team mood may rise after:

- safe rest
- shared meals
- successful rescue
- successful supply run
- surviving a major fight
- receiving gifts
- reaching a safehouse
- keeping promises

Team mood should influence dialogue, obedience, panic, conflict, and the risk of
someone leaving.

### 7.5 Leadership, Trust, Respect, Fear, and Resentment

Relationship should not be a single affection score.

Current long-term relationship dimensions should include or preserve room for:

- trust
- respect
- fear
- resentment
- attachment
- debt
- loyalty

This allows more nuanced relationships:

- an NPC can like the player but not respect them as a leader
- an NPC can obey because they fear the player
- an NPC can respect the player but resent unfair decisions
- an NPC can stay because of debt, not affection
- an NPC can be loyal to the group but angry at the player

This nuance should feed both dialogue and autonomous behavior.

### 7.6 Narrative Through Action

Dialogue is important, but not every story beat should be spoken.

NPCs should reveal themselves through behavior:

- where they choose to stand
- what they pick up first
- what they refuse to use
- who they protect
- when they hesitate
- when they complain
- when they volunteer
- when they give something away
- when they leave

The best outcome is for the player to understand a character partly from what
they do, not only from what they say.

### 8. Recruitment and World Discovery

Current development spawns NPCs directly for testing. The final mod should make
the player discover NPCs naturally while exploring.

Potential encounter patterns:

- lone survivor hiding in a building
- hostile survivor guarding supplies
- wounded survivor asking for help
- small group with internal conflict
- survivor trapped by zombies
- survivor who recognizes a location or object
- ex-companion found later after leaving the group

Companions should be earned through interaction, trust, gifts, shared danger,
and narrative circumstances.

### 9. Gifts, Trade, Loyalty, and Betrayal

NPCs should both receive and give.

Possible interactions:

- player gives favorite item to improve relationship
- NPC gives player a useful item
- NPC asks for food, medicine, cigarettes, books, weapons, or help
- NPC resents unfair distribution
- NPC leaves if relationship falls too low
- NPC betrays the group in extreme cases

Betrayal should leave story traces, such as a note saying where the NPC went.
If the player reaches that place later, the former companion may be encountered
again and the conflict can resolve through dialogue or violence.

### 10. Places and Vehicles

NPCs should remember places and eventually act on place knowledge.

Near-term vehicle goal:

- NPCs can ride in the same vehicle while the player drives.

Long-term vehicle goal:

- NPCs can be ordered to bring a parked vehicle, flee to a shelter, or drive to
  a remembered location if the engine allows this reliably.

Vehicle driving should be treated as a later high-risk feature, not a foundation
requirement.

## Architectural Implications

### Canonical State Must Stay Rich

The NPC record needs to remain the durable source for identity, status,
relationship, memory, preferences, narrative, inventory abstraction, and command
policy.

Actor state is temporary. Bandits brain state is temporary. UI state is
temporary.

### Autonomy Should Be Explainable

The future autonomous-feeling system should not be a black box. Every important
decision should be explainable as:

```text
current state + personality + memory + relationship + backstory + command policy
=> chosen intent + reason
```

This keeps debugging possible and makes NPC behavior feel authored rather than
random.

### Player-Like Systems Need Adapters

NPCs may not be true `IsoPlayer` instances. Therefore player-like systems should
be represented through adapters:

- canonical inventory model
- actor equipment bridge
- moodle/status model
- profession/trait IDs
- movement command bridge
- combat permission bridge
- dialogue/voice bridge
- vehicle passenger bridge

Each adapter should degrade gracefully when an exact player feature cannot be
implemented yet.

### Relationship and Narrative Should Not Directly Drive Actors

Story, memory, relationship, and personality should affect decisions by changing
scores, permissions, dialogue, and intent generation.

They should not directly push Bandits tasks or mutate actor movement/combat
state.

## Suggested Development Phases

### Phase 1: Stable Companion Squad

Goal: make the current 3-person companion squad reliable.

Focus:

- follow quality with multiple NPCs
- combat stance correctness
- damage/death correctness
- replacement after death
- friendly fire policy
- clear status display
- compact logs

### Phase 2: NPC Status and Inventory Foundation

Goal: make each NPC inspectable and materially real.

Focus:

- status window
- inventory display
- equipment display
- giving/taking basic items
- weapon ownership correctness
- moodle/status abstraction

### Phase 3: Relationship and Dialogue Foundation

Goal: make NPCs socially legible.

Focus:

- five relationship stages
- relationship score changes
- basic dialogue menu
- overhead status speech
- gifts and preferences
- trust/fear/resentment feedback

### Phase 4: Autonomous Behavior Guidelines

Goal: reduce micromanagement.

Focus:

- follow/search/watch/attack/flee/autonomous policies
- decision context builder
- utility scoring
- personality/backstory modifiers
- explainable intent logs

### Phase 5: World Recruitment and Encounters

Goal: stop spawning test companions directly for ordinary play.

Focus:

- encounter director
- natural NPC discovery
- recruitment flow
- hostile/wary/neutral NPC behavior
- persistent discovered survivors

### Phase 6: Advanced Narrative Consequences

Goal: make long-term relationships matter.

Focus:

- promises
- grudges
- leaving the group
- betrayal
- notes/clues
- later re-encounter
- special location memories

### Phase 7: Vehicles and Complex Orders

Goal: expand group survival logistics.

Focus:

- passenger support
- enter/exit vehicle commands
- remembered safehouse/vehicle locations
- fetch vehicle experiments
- flee-to-location experiments
- driving only if reliable enough

## Immediate Design Bias

When choosing between two implementations, prefer the one that:

- preserves canonical record authority
- keeps behavior explainable
- routes decisions through intents
- isolates carrier-specific tricks
- can represent modded IDs later
- supports per-NPC variation
- keeps manual testing observable through concise logs

This vision is ambitious. The correct way to build it is not one huge jump, but
small playable layers that keep the player's group feeling more alive each time.
