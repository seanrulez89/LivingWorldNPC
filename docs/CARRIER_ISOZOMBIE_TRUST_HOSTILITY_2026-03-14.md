# Carrier IsoZombie Trust-Gated Hostility - 2026-03-14

## Why this pass exists

Once the `IsoZombie` carrier became visible, persistent, interactive, and stable, the next design question changed.

The problem is no longer just embodiment.
It is now relationship policy:

- when should the player and carrier treat each other as allies?
- when should they be hostile?
- how can future betrayal be supported without hardcoding permanent safety?

## Required design rule

The project should **not** make all managed carriers permanently unattackable.

Instead, relationship state must decide the combat stance.

Target rule:

- sufficiently trusted companion -> friendly / mutually non-hostile
- betrayal or hostile relationship -> mutually attackable / hostile
- everything else -> transitional neutral state, not yet the final betrayal behavior

## New policy helper

A new helper now exists in `13_LWN_Social.lua`:

- `Social.relationshipCombatPolicy(record)`

It currently returns a policy object with:

- `state` (`friendly`, `neutral`, `hostile`)
- `allowPlayerAttack`
- `allowCarrierAttackPlayer`
- `shouldNeutralizeCarrier`
- `reason`

## Current policy rules

### Hostile

Returned when:

- `record.drama.pendingBetrayal == true`
- or `Social.betrayalScore(record) >= LWN.Config.Social.BetrayThreshold`

Current result:

- `allowPlayerAttack = true`
- `allowCarrierAttackPlayer = true`
- `shouldNeutralizeCarrier = false`

### Friendly

Returned when:

- `record.companion.recruited == true`
- and `trust >= RecruitTrustFloor`

Current result:

- `allowPlayerAttack = false`
- `allowCarrierAttackPlayer = false`
- `shouldNeutralizeCarrier = true`

### Neutral

Fallback state for everything else.

Current result:

- `allowPlayerAttack = true`
- `allowCarrierAttackPlayer = false`
- `shouldNeutralizeCarrier = true`

This preserves the current test-friendly inert shell while leaving space for later betrayal/hostility work.

## IsoZombie integration in this pass

`35_LWN_Carrier_IsoZombie.lua` now reads the relationship combat policy and stores it into actor modData:

- `LWN_RelationState`
- `LWN_AllowPlayerAttack`
- `LWN_AllowCarrierAttackPlayer`
- `LWN_HostilityReason`

It also changes shell neutralization behavior based on the policy:

- friendly/neutral -> keep the carrier neutralized/inert
- hostile -> stop forcing the shell into the current inert mode

## Important limitation in this pass

This pass is **policy groundwork**, not final combat enforcement.

Meaning:

- the carrier now knows whether it is meant to be friendly, neutral, or hostile
- but the project does **not yet** fully control every engine-level player attack decision or full hostile targeting behavior

So this pass should be understood as:

- relationship-aware shell policy setup

not yet as:

- complete betrayal combat implementation

## Why this is still valuable now

This keeps the project aligned with the future design goal:

- companions can later betray the player
- trust level matters
- carriers are not hardcoded into permanent pacifism

Without this policy layer, later betrayal work would require ripping out temporary assumptions.

## Recommended next step

After this policy groundwork, the next logical work items are:

1. identify the best hook/control point for suppressing player attack against friendly carriers
2. identify the best control point for allowing hostile carriers to actively target/attack the player
3. keep those decisions driven by `relationshipCombatPolicy(record)` rather than by carrier-specific one-off hacks
