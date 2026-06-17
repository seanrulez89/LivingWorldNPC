# Cleanup NPE Hardening - 2026-03-14

## Problem addressed

A live embodied `IsoPlayer` could be deleted through the debug cleanup path, after which the game later crashed with:

- `java.lang.NullPointerException`
- `BodyDamage.UpdateBoredom(...)`
- because `IsoGameCharacter.getCurrentSquare()` had become `null`

This is a cleanup-lifecycle bug, not the same bug as the alive-NPC transparency failure.

## What the crash implies

The engine could still deliver delayed reaction / animation / update work against the actor after LivingWorldNPC had already pushed the actor through world removal.

That means "defer one tick, then remove" was still too aggressive for some runtime cases.

## What changed

### 1. Live `IsoPlayer` cleanup now waits longer before physical finalization

The cleanup contract for live embodied `IsoPlayer` actors now requires a quarantine window before `finalizeDeferredCleanup()` can proceed.

Current thresholds:

- minimum deferred cleanup attempts: `90`
- minimum deferred cleanup age: `0.0005` world hours

These are intentionally conservative. The goal is to let pending attack / reaction / animation events age out before physical removal.

### 2. Quarantine now caches the actor's last known square/position

When cleanup is first deferred, the actor stores:

- `LWN_CleanupAnchorX`
- `LWN_CleanupAnchorY`
- `LWN_CleanupAnchorZ`
- whether a square existed at quarantine time

This gives final cleanup a last known good square context to fall back to.

### 3. Final physical cleanup now restores square references if removal clears them

If final cleanup succeeds in removing the actor from world, but the actor no longer has a square reference, the code now tries to restore the cached square/position references on the detached actor.

This does **not** re-add the actor to world.
It only tries to prevent lingering engine callbacks from encountering a `null currentSquare` immediately after world removal.

## Tradeoff

This hardening intentionally prefers:

- delayed physical cleanup
- over immediate delete semantics

So a debug-deleted live actor may remain in quarantine for a short period before the physical removal step finishes.

That is acceptable here because the priority is:

1. stop the crash
2. keep logical/registry/UI cleanup correct
3. tolerate slightly slower physical retirement if needed

## What this patch does NOT claim

This patch does not prove the cleanup path is universally perfect.
It is a safety hardening pass based on the observed NPE signature.

If another crash remains after this pass, the next likely direction is:

- even longer quarantine
- or a stronger soft-delete contract that avoids physical world removal for live `IsoPlayer` actors until the engine is unquestionably done referencing them

## Validation performed

Run locally after the patch:

```bash
./scripts/validate-wsl.sh
```

This validated:

- diff format
- changed-file syntax via `luac -p`
- repo cleanliness expectations for the modified files

## Expected outcome for the next in-game test

A debug delete of a live embodied NPC should now:

- remove the NPC logically from UI/registry/state first
- keep the actor quarantined longer
- only finalize physical cleanup after the wait window
- reduce or eliminate the `getCurrentSquare() == null` crash path observed in the prior run
