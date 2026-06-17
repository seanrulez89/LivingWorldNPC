# Debug Delete Combat Guard - 2026-03-14

## Why this patch exists

The prior cleanup hardening reduced the immediacy of the crash, but did not solve the core combat-case failure.

Observed behavior:

- deleting a live embodied NPC while **not** under zombie attack was safe
- deleting a live embodied NPC **during** zombie attack still crashed later
- zombies continued attacking the deleted target until an engine-side anim/reaction callback hit a `getCurrentSquare()==nil` path

Because the combat-target chain was still alive, the safest short-term contract is now simpler:

- do not allow debug delete while the NPC is in combat or under attack

## New behavior

### 1. Combat-time debug delete is blocked

`DebugTools.deleteNpcById()` now resolves the embodied actor first and asks `ActorFactory.isActorInCombatOrUnderAttack(actor)`.

If the actor is in combat, deletion is refused and a debug-facing message is shown:

- `NPC <id> is in combat and cannot be deleted (<reason>)`

### 2. Non-combat debug delete is immediate

For `debug_delete`, `ActorFactory.cleanupActor()` no longer uses deferred quarantine cleanup.

That means when the actor is not in combat:

- logical cleanup still happens through canonical cleanup
- physical cleanup is attempted immediately instead of being deferred

This matches the new intended operator contract:

- **combat:** do not delete
- **non-combat:** delete immediately

## Combat detection used

The new combat guard checks for:

- actor has a combat target
- actor is currently attacking
- nearby zombies within a short radius that either:
  - explicitly target the actor, or
  - are currently attacking right beside the actor

This is intentionally conservative.
If the guard says the NPC is in combat, delete is blocked rather than risking another crash.

## Files changed

- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

## Validation performed

```bash
./scripts/validate-wsl.sh
```

Expected result:

- syntax passes
- non-combat delete is immediate
- combat delete is refused with a message instead of entering unsafe cleanup
