# Carrier IsoZombie Friendly Attack Suppression - 2026-03-14

## Why this pass exists

The first hostility-groundwork pass established relationship policy and shell posture, but it did not yet use a concrete engine-level control point to reduce direct player damage against friendly carriers.

A useful reference clue appeared in external mod code using:

- `setGodMod(true)`

That suggested a cautious next step.

## What changed

`Carrier_IsoZombie` now applies:

- `setGodMod(policy.allowPlayerAttack ~= true)`

inside the relationship-driven shell combat-state application.

## Intended behavior

### Friendly

If policy says:

- `allowPlayerAttack = false`

then the shell is put into god mode.

This is intended as a **minimum friendly-shell attack suppression measure**.

### Neutral / Hostile

If policy says:

- `allowPlayerAttack = true`

then god mode is turned back off.

This preserves the future design requirement that betrayal/hostility must still allow real attackability.

## Why this is still a cautious patch

This pass does **not** rewrite the engine attack flow.
It only uses a narrow, reversible control point already seen in reference code.

That keeps the project safer than trying to intercept every attack path immediately.

## Important limitation

This patch is still exploratory.

It aims to answer:

- does `setGodMod(true)` effectively suppress player damage against friendly `IsoZombie` shells in practice?

It does not yet prove that all forms of attack targeting/animation/selection are fully solved.

## Validation performed

```bash
./scripts/validate-wsl.sh
luac -p 42/media/lua/client/35_LWN_Carrier_IsoZombie.lua
```
