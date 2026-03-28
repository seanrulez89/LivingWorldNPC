# Next Session Handoff — 2026-03-28

Current work branch: `spike/minimal-neutral-dummy`
Baseline branches preserved:
- `spike/isozombie` — pre-surgery freeze point
- `spike/companion-shell-split` — surgery planning / reset branch

Status: major progress achieved on the minimal dummy branch. The project is no longer primarily stuck on spawn instability, zombie vocal leakage, fake movement, or post-arrival attack-like presentation residue.

## Executive summary

The branch is now behaving much more like a constrained **minimal neutral dummy** and much less like a noisy failed full-NPC experiment.

Two late-session fixes were especially important:

- `91561dd` — `Fix dummy spawn scrub grace helpers`
- `70bebb0` — `Fix dummy move idle handoff`

Those fixes materially changed what the branch still fails at.

### What now works materially better

1. **Single stable spawn remains intact**
   - exactly one test NPC spawned in the latest retest
   - no immediate aggression / player recognition appeared
   - zombie vocal remained suppressed
   - spawn-safe scrub grace clearly stayed active in logs

2. **Real movement still exists and still commits**
   - deterministic movement again produced real displacement
   - latest arrived summary still showed:
     - `motor=arrived`
     - `commit=<new square>`
     - `squareChanged=yes`
     - `totalDelta=7.00`

3. **Move→idle handoff is now materially better**
   - the earlier post-arrival in-place stepping / attack-like posture did **not** reproduce in the latest retest
   - after arrival, repeated idle shell enforcement dominated the log
   - no `attacking=yes` or `target=yes` signals appeared in the analyzed run

4. **Delete works again in the tested scenario**
   - `delete` successfully removed the latest test dummy
   - the earlier attack-state false positive did not block deletion in this retest

### What still clearly fails

1. **Visual shell is still zombie-like**
   - the player still sees a zombie-looking shell
   - visual signature still reads like `reanimated_zombie|M_ZedBody...`
   - the latest summaries still report:
     - `probeOk=no`
     - `appLock=no`
     - `appFail=yes`

2. **PresentationGuard still blocks alive-style repair**
   - repeated guard lines still report `reason=zombie_or_reanimated`
   - this strongly suggests the alive-looking presentation path is still blocked by upstream role/class/presentation constraints

3. **`clean` is still not a shell delete path**
   - `clean` continues to protect the managed shell itself
   - it behaves like a nearby sterile cleanup pass, not like direct NPC removal

## Why the latest result matters

This is the key change in project shape.

Earlier in the day, the main open question was still whether the branch was primarily failing because:
- spawn scrub was too aggressive,
- move authority snapped back,
- post-arrival move shell stayed latched,
- or zombie combat residue kept reasserting itself.

The latest retest makes the picture much cleaner.

### Current best interpretation

The dummy is now much closer to this shape:

- **logic / control:** mostly constrained and non-hostile
- **audio:** mostly corrected
- **movement:** real and committed
- **move→idle handoff:** materially stabilized
- **visual body / appearance truth:** still zombie-coded

In simple terms:

- the branch is getting better at acting like a dummy,
- but the body still looks like a zombie.

That narrowing is a real architectural win.

## Commits on the minimal dummy branch that matter most now

In useful recent order on `spike/minimal-neutral-dummy`:

- `fc92e5b` — `Lock dummy move authority and commit moved positions`
- `1560591` — `Record end-of-day minimal dummy lessons and handoff`
- `6a7c488` — `Scrub dummy attack presentation and delete false positives`
- `0bc814f` — `Make dummy scrub spawn-safe`
- `91561dd` — `Fix dummy spawn scrub grace helpers`
- `70bebb0` — `Fix dummy move idle handoff`

### What the last two fixes changed in practice

#### `91561dd` — spawn-safe scrub completion
- completed the missing grace helpers
- prevented over-eager spawn-time scrub from destabilizing the shell immediately after creation

#### `70bebb0` — move-idle handoff fix
- stopped treating `dummy.command` mirror data as authoritative move-active proof by itself
- added explicit idle-settle behavior when command inactive + motor settled + actor not moving/pathing
- gave post-runtime enforcement a narrow chance to settle into idle before move shell can win again

## Evidence from the latest retest

Primary log analyzed:
- `/mnt/c/Users/seanr/Zomboid/Logs/2026-03-28_15-54_DebugLog.txt`

Most important observations:

1. **Spawn stayed stable**
   - initial summaries stayed in `dummy_idle`
   - no aggression / targeting appeared at TEST 01

2. **Move committed correctly**
   - arrived summary showed `commit=3753,10997,0`
   - `squareChanged=yes`
   - `totalDelta=7.00`

3. **Idle contract now wins after arrival**
   - `dummy_contract_move_applied` only appeared 4 times total and only around move startup
   - `dummy_contract_idle_applied` appeared 195 times
   - `attacking=yes` count was 0
   - `target=yes` count was 0

4. **Appearance still fails honestly**
   - `spawn.humanization_failed`
   - `probeOk=no`
   - `appFail=yes`
   - `PresentationGuard ... reason=zombie_or_reanimated`

5. **Delete succeeded**
   - `deleteNpcById:immediate_noncombat`
   - `Deleted NPC LWN-000027`

## Immediate next patch priority

### 1. Appearance truth / zombie-body hard fail investigation (highest priority)

Goal:
- understand why the branch still ends up presenting as `reanimated_zombie|M_ZedBody...`
- make appearance success / failure correspond more tightly to what the player actually sees
- determine whether the next meaningful step is:
  - stronger fail gating,
  - different post-create appearance rebuild timing,
  - or deeper actor-role/class change for alive-state presentation

Main files expected:
- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`
- `42/media/lua/client/37_LWN_ShellHumanizer.lua`
- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/92_LWN_DebugTools.lua`

### 2. Keep TEST 01~03 as the main validation lane

Goal:
- avoid broad scenario noise while appearance is still wrong
- keep checking that spawn stability, committed movement, and calm post-arrival behavior do not regress while appearance work continues

### 3. Keep recovery / TEST 04 de-prioritized

Goal:
- do not re-open recovery / long-path complexity until the shell stops reading as a zombie
- otherwise failure signals will become muddy again

## What not to do first next time

- do **not** jump back into heavy social / relationship logic work
- do **not** assume more aggression scrub is the next best patch without fresh evidence
- do **not** prioritize locomotion polish before the body/presentation truth problem is clearer
- do **not** spend the next session on `clean` semantics; `delete` is already the reliable removal path for the current test lane

## Suggested next-session workflow

1. Start on `spike/minimal-neutral-dummy`
2. Re-read:
   - `docs/MINIMAL_DUMMY_MOVE_IDLE_HANDOFF_RETEST_2026-03-28.md`
   - `docs/TEST_LOG_HISTORY.md` (latest entry)
3. Focus on appearance truth / zombie-body fail investigation
4. Re-run only `TEST 01~03`
5. If appearance materially improves, only then revisit broader recovery / TEST 04 planning

## Current testing takeaway

The branch is no longer in the old “everything fails at once” state.

It is now in a much better and much narrower state:

- spawn works well enough to trust
- movement works well enough to trust
- move→idle handoff works much better than before
- delete works in the tested scenario
- the remaining dominant issue is **visual shell correctness**

That narrowing is the main thing to protect next.
