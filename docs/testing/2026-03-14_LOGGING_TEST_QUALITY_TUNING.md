# Log Quality Tuning - 2026-03-14

## Scope

Small log-only cleanup pass.

No intended gameplay change.
No intended embodiment architecture change.

## What changed

### 1. `death.awaiting_corpse` is now throttled

Previously the death lifecycle could emit `death.awaiting_corpse` almost every tick until the timeout/corpse condition flipped.

That made logs noisy without adding much diagnostic value.

Now the trace is only emitted periodically while the actor is still waiting for the corpse/timeout condition.

### 2. `leftover.snapshot` is suppressed for the trivial detached-self case

After cleanup, logs sometimes reported a leftover snapshot containing only the same detached actor object with `world=false`.

That case is expected and was not useful enough to keep logging every time.

Now `leftover.snapshot` is still logged for meaningful leftovers, but not for the trivial:

- single leftover
- same actor object
- already out of world

case.

## Files changed

- `42/media/lua/client/25_LWN_EmbodimentManager.lua`

## Expected effect

Logs should stay easier to read during:

- death transition cleanup
- routine actor cleanup

while preserving more important cleanup diagnostics.
