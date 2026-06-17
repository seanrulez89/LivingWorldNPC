# Bandits Friendly Damage and Respawn Failure Investigation - 2026-06-13

## Scope

This note records the results of the live test that ended at 2026-06-13 23:35 KST.
No runtime code was changed during this investigation.

Primary evidence:

- `/Users/sean/Zomboid/console.txt`
- `/Users/sean/Zomboid/Logs/2026-06-13_23-31_DebugLog.txt`
- tested commit: `28fa94d Fix Bandits follow locomotion and friendly hit safety`

Test actor:

- LWN NPC: `LWN-000026`, `아이오니 웨스턴`
- IsoZombie object ID: `48`
- Bandit brain / persistent outfit ID: `7405639`

## Executive Findings

1. The player can still land real attacks on the friendly controlled NPC.
2. The current `OnHitZombie` recovery runs before the engine finishes applying damage and knockdown state.
3. `setGodMod(true)` and `setInvulnerable(true)` did not reliably prevent this attack path.
4. The fatal hit produced a Bandits corpse synchronization error, then LWN briefly rebound the dead actor before death cleanup completed.
5. TEST RESET and the next TEST 01 both failed while trying to remove the stale dead actor through `BanditUtils.GetZombieID`.
6. The clean-slate routine excludes dead debug records, which leaves the dead record and marked shell for the unsafe orphan purge path.

## Attack Timeline

The LWN handler logged many successful hit events between frames `8162` and `10803`:

```text
[LWN][Bandits] friendly hit suppressed npcId=LWN-000026 ... health=1.80
```

This proves that the player attack collision continued to reach the Bandits actor. The log does not prove that every attempted swing connected, so the reported intermittent feeling may include ordinary misses or non-damaging hits. It does prove that friendly attack suppression was not reliable.

The decisive ordering appears at frame `10607`:

```text
23:35:07.046 friendly hit suppressed ... health=1.80
23:35:07.054 actor health changed 1.80 -> 1.54
23:35:07.055 actor knockedDown=true
```

The handler restored the state visible at event time, but the engine applied final damage and knockdown immediately afterward. The same ordering occurs on the fatal hit:

```text
23:35:10.312 friendly hit suppressed ... health=0.69
23:35:10.321 actor health changed 0.69 -> 0.00, dead=true
```

Therefore the current handler is a pre-resolution observer for this combat path, not a reliable post-damage recovery point. This also explains why `setKnockedDown(false)` and `setOnFloor(false)` did not keep the NPC standing.

Canonical health was pulled down over successive hits:

```text
1.80 -> 1.54 -> 1.11 -> 0.69 -> 0.00 actor death
```

The LWN record retained `health=0.69` after death because the lethal engine result happened after the final recovery callback and before the normal actor-to-record pull could commit zero health.

## Death-Time Failure

At frame `10803`, EventAdapter correctly observed a death-like actor. Before cleanup completed, actor recovery accepted and rebound the same dead object:

```text
recovery.cached_hit
registerActor.bound health=0.00 dead=true
resolveEmbodiedActor.relinked_near_anchor health=0.00 dead=true
```

This is an invalid recovery transition. Cached, handle-based, and nearby recovery paths must reject dead or death-like actors before registration.

Death cleanup then preserved the dead zombie/corpse world objects and hid the canonical record. Immediately afterward Bandits found its corpse and attempted `body:sync()`, producing:

```text
SERVER FOUND DEAD BANDIT BODY
ERROR: IsoDeadBody not found on square 8223,11668,0
```

This is not a Lua stack-trace exception. It is most likely a corpse-registration race between the engine/Bandits death pipeline and LWN cleanup. The logs show that the corpse could still be enumerated while already reporting `world=false`. The exact owner of the invalid corpse registration still needs a focused test.

## Respawn Failure

TEST RESET at frame `12199` and the next TEST 01 at frame `12662` failed identically:

```text
BanditUtils.GetZombieID(BanditUtils.lua:611)
removeActor(36_LWN_Carrier_Bandits.lua:247)
purgeRogueDebugHarnessShells(92_LWN_DebugTools.lua:1188)
prepareAutomationCleanSlate(92_LWN_DebugTools.lua:1216)
java.lang.RuntimeException: Object tried to call nil in GetZombieID
```

`removeActor` first asks for a live Bandit brain. The dead actor no longer has one, so it falls back to:

```lua
BanditUtils.GetZombieID(actor)
```

Bandits then calls `character:getPersistentOutfitID()` on the stale dead actor. That method lookup fails in its current lifecycle state and aborts the entire clean-slate operation.

The failure is made deterministic by the debug cleanup order:

1. `collectDebugHarnessRecords()` only includes records where `Store.isAlive(record) == true`.
2. The dead `LWN-000026` record is skipped and remains stored.
3. The orphan scan still finds the dead object because `LWN_TestHarnessLabel`, `LWN_CarrierKind=bandits`, and last-NPC markers remain.
4. The orphan scan sends that stale object to `Carrier.removeActor`.
5. The unprotected Bandits ID lookup throws before `resetAutomation()` and before a new spawn request.

After both failures, status remained:

```text
scenario=minimal_dummy_move_return_bandits_v1
phase=test_02_ready
npcId=LWN-000026
record state=hidden
actor=nil
bandit count=0
```

This confirms that no new NPC was requested; TEST 01 stopped in pre-spawn cleanup.

## Patch Direction For Next Session

### Friendly attack prevention

- Find a player combat target-selection or hit-list control point that can exclude friendly LWN actors before collision resolution.
- Do not treat `OnHitZombie`, `setGodMod`, or `setInvulnerable` as sufficient by themselves.
- If a deferred post-hit repair is retained as a fallback, run it on a later tick and keep a pre-hit health/posture snapshot. It cannot be the primary defense because a lethal hit can finalize first.
- Log weapon type, floor state, health before event, and health on the next tick to distinguish standing hits, floor attacks, and stomps.

### Death and cleanup lifecycle

- Reject `dead`, `health <= 0`, and death-like actors in cached, carrier-handle, and nearby recovery paths.
- Retire or null the Bandits carrier handle as soon as death is latched; never leave a dead actor as a recoverable handle actor.
- Make Bandits ID resolution safe for stale actors. Prefer stored `handle.banditId`, brain ID, or stamped ModData, and never call `BanditUtils.GetZombieID` without a protected capability check.
- Include dead debug-harness records in TEST RESET clean-slate removal.
- Clear or reinterpret Bandits/test-harness markers on preserved dead actors and corpses so orphan cleanup does not treat them as live carriers.
- Let the native Bandits death/cache pipeline finish before attempting any explicit Bandit removal. Re-test whether this removes the corpse sync race.
- Ensure clean-slate cleanup is exception-isolated so one stale object cannot prevent automation reset and the next spawn.

## Required Regression Test

1. Spawn one controlled NPC and confirm all five follow movement modes still work.
2. Attempt standing melee hits, shove/knockdown, floor attacks, stomps, and ranged attacks separately.
3. Confirm friendly attacks do not reduce health or create a corpse.
4. Temporarily force a death through a debug-only path and verify dead actors are never rebound.
5. Run TEST RESET after forced death and confirm no `GetZombieID` exception.
6. Run TEST 01 immediately afterward and confirm exactly one new actor binds.
7. Confirm Bandits cache count, LWN carrier handle, cleanup blocklist, record state, and corpse markers are all consistent.

