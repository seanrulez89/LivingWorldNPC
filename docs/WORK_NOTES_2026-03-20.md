# Work Notes - 2026-03-20

## IsoZombie relationship debug follow-up

- Added nearest-NPC debug controls for:
  - lowering trust
  - forcing canonical `friendly`, `neutral`, or `hostile` policy outcomes through `Social.forceRelationshipCombatPolicy(...)`
- Kept the forcing path inside real record fields (`relationshipToPlayer`, `companion`, `drama`) instead of adding a debug-only policy state.
- `DebugTools` now tries an immediate carrier sync after trust/policy changes so embodied `IsoZombie` shells update in-place during testing.

## IsoZombie shell observability / suppression

- `Carrier_IsoZombie` now writes concise policy metadata into shell `modData`:
  - `LWN_RelationshipPolicySummary`
  - `LWN_CarrierCombatMode`
  - `LWN_FriendlySuppression`
- Friendly / neutral shells now also call `StopAllActionQueue()` when clearing target state.
- `setGodMod(...)` remains the fallback safety layer for `allowPlayerAttack == false`; this pass does not claim complete player-side attack suppression is solved.

## Quick test path

1. Enable debug tools and spawn a nearby `IsoZombie` shell.
2. Use `Debug: Force Nearest Friendly Policy`, `Neutral`, and `Hostile` to confirm shell posture changes immediately.
3. Use `Debug: Boost Nearest NPC Trust` and `Debug: Lower Nearest NPC Trust` to verify trust-driven transitions still flow through the same policy model.
4. Use `Debug: Dump Nearest NPC Summary` and confirm the summary / actor line shows the current policy and suppression metadata.
5. For friendly shells, verify they stay inert and note whether player attackability still leaks through despite `godmod+clearqueue`.

## Validation in this pass

- `./scripts/validate-wsl.sh`
- `luac -p` on edited Lua files
