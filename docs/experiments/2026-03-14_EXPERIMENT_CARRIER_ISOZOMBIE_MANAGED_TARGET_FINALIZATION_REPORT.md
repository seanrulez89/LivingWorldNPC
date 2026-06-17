# Carrier IsoZombie Managed-Target Finalization - 2026-03-14

## Why this pass exists

After the sync/UI branching pass, the `IsoZombie` carrier could remain visible, stable, and error-light.

However, right-click interaction still failed.

Context logs showed the managed zombie carrier reaching the later targetability checks successfully, but still being rejected as:

- `reason=not_managed_actor`

That pointed to a single remaining bottleneck:

- `ActorFactory.isManagedActor()` still enforced a human-oriented runtime-core definition

## What changed

### 1. `ActorFactory.isManagedActor()` is now carrier-aware for `IsoZombie`

For ordinary human-style carriers, the old rule stays in place:

- npcId exists
- not destroyed
- in world
- `getBodyDamage()` exists
- `getStats()` exists
- `getInventory()` exists

For `carrierKind == "isozombie"`, the rule now becomes:

- npcId exists
- not destroyed
- in world
- `isZombie() == true`
- square/currentSquare present
- `getStats()` exists

This removes the inappropriate requirement that a managed zombie carrier must satisfy the same body/inventory assumptions as a human carrier.

### 2. Context-menu rejection reason is now more specific for managed zombie carriers

If a zombie carrier still fails the managed-actor check, the context trace will now report:

- `managed_zombie_not_finalized`

instead of the generic:

- `not_managed_actor`

This makes future targetability failures easier to diagnose.

## Why this matters

By the time this pass was needed, the managed `IsoZombie` carrier already had all of these properties:

- visible in world
- persisted instead of disappearing immediately
- no repeated sync error spam
- registered actor matched the candidate actor
- record existed and was still in `embodied` state

So keeping the old human-centric `isManagedActor()` rule was no longer reasonable.

This pass is the first time the repo explicitly treats a non-human carrier as a first-class managed actor candidate.

## Validation performed

```bash
./scripts/validate-wsl.sh
luac -p 42/media/lua/client/23_LWN_ActorFactory.lua
luac -p 42/media/lua/client/26_LWN_UI_ContextMenu.lua
```

## What to watch in the next test

Look for:

- whether right-click menus now appear on the visible `IsoZombie` carrier
- whether context trace reaches `candidate.accepted`
- whether any remaining rejection reason is now more specific than the old generic managed-actor failure
