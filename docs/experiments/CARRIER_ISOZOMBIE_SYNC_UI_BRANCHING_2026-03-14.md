# Carrier IsoZombie Sync/UI Branching - 2026-03-14

## Why this pass exists

After resolve hardening, the `IsoZombie` carrier could remain visible and embodied long enough for meaningful observation.

The next blockers were:

1. repeated per-tick errors from human-oriented `ActorSync` flag enforcement
2. missing right-click interaction because the context menu system rejected zombies before checking whether they were LWN-managed carriers

## What the logs showed

The dominant repeating error was:

- `IsoGameCharacter.setNPC(...)`
- `NullPointerException: this.player is null`

That means the zombie carrier was being pushed through a player/NPC setter path that does not apply safely to it.

At the same time, the context menu logic treated all zombies as leftover/death objects and rejected them before targetable-NPC checks could succeed.

## What changed

### 1. `ActorSync` is now carrier-aware for `IsoZombie`

`enforceEmbodiedFlags(record, actor)` now looks up the carrier kind.

For `carrierKind == "isozombie"`, it skips human/player-specific setters such as:

- `setFemale(...)`
- `setFemaleEtc(...)`
- `setNPC(...)`
- `setIsNPC(...)`
- `setForname(...)`
- `setSurname(...)`

It still applies only the safer generic parts needed for the shell to remain visible/usable.

This should remove the repeated `setNPC()` exception spam seen in the previous run.

### 2. Context menu targeting now recognizes managed zombie carriers

`26_LWN_UI_ContextMenu.lua` now distinguishes between:

- ordinary zombies
- `LWN`-managed zombie carriers

A managed zombie carrier is currently recognized by:

- world object kind = `zombie`
- active/stored npcId exists
- `modData.LWN_CarrierKind == "isozombie"`

Those actors are no longer rejected by the early `kind == "zombie"` filter.

This is the first step toward letting the normal NPC interaction menu appear on `IsoZombie` carriers.

## Scope note

This pass does **not** claim the `IsoZombie` carrier is finished.
It only removes two major blockers:

- sync error spam from wrong setter usage
- context menu rejection before carrier-aware targeting

## Validation performed

```bash
./scripts/validate-wsl.sh
luac -p 42/media/lua/client/24_LWN_ActorSync.lua
luac -p 42/media/lua/client/26_LWN_UI_ContextMenu.lua
```

## What to watch in the next test

Look for:

- major reduction or elimination of repeated `setNPC()` errors
- whether right-click menu now appears on the visible zombie carrier
- whether the carrier remains visible and stable while embodied
