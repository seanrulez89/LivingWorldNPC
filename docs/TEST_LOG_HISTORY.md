# Test Log History

This file is the running narrative for in-game test results.

## Purpose

Track each meaningful test cycle in a way that preserves causality:

1. what was tested
2. what happened in-game
3. what the logs showed
4. what hypothesis or lesson was derived
5. what code/doc changes followed
6. what the next expected check should be

## Entry format

For every new test cycle, append a new section using this structure:

```md
## YYYY-MM-DD HH:MM KST — Short title

### In-game result
- ...

### Log signals
- ...

### Interpretation / lesson
- ...

### Code or document changes that followed
- ...

### Next thing to verify
- ...
```

## Notes

- Keep entries append-only.
- Prefer concrete observations over vague summaries.
- If an observation later turns out to be wrong, do not erase it; append a correction in a later entry.
- This file is intended to help large refactors keep contact with actual test evidence.
- Use this file for cross-day test/result continuity; do not keep appending new-day technical work into an older `WORK_NOTES_YYYY-MM-DD.md` file.

## 2026-03-13 09:14 KST — Best-so-far test, alive actor still invisible

### In-game result
- 사용자 관찰 기준 이번 테스트는 지금까지 중 가장 좋았다.
- NPC 자체는 여전히 화면에 보이지 않았다.
- 대신 이전에 거슬리던 corpse flicker, stale target, delete crash, death overlap은 체감상 많이 줄어든 편이었다.

### Log signals
- 최신 `console.txt`에는 이번 구간 기준 `ERROR`, `Exception`, Lua stack trace가 보이지 않았다.
- 로그 보존 구간은 생성 직후가 아니라 이미 embodied 상태인 `LWN-000037`의 runtime부터 시작했다.
- 살아 있는 동안 `LWN-000037`는 약 5.7초 동안 계속 아래 상태를 유지했다.
- `world=true`, `ghost=false`, `invisible=false`, `sceneCulled=false`, `alpha=1.00`, `targetAlpha=1.00`
- `humanVisual=true`, `actorDescriptor=true`, `itemVisuals=5`, `wornItems=3`, `persistentOutfitId=0`
- `PresentationGuard`도 계속 `status=already_set`만 남겼고, alpha zero나 false-flag repair는 필요하지 않았다.
- death 전환은 `t=1773360836224` 근처에서 같은 `IsoPlayer{ ID:93 }`에 대해 `health=0.00`, `dead=true`, `deathLike=true`로 바뀌며 감지됐다.
- 같은 순간 `DeathTrace`는 별도 `IsoZombie{ ID:38 }`를 같은 square에서 잡았고, `sameActorRef=false`, `sameNpcId=false`였다.
- death 이후 cleanup 전까지 `corpseSeen=false`가 계속 유지됐고, 약 0.58초 뒤 `death_timeout_cleanup`가 실행됐다.
- cleanup 흐름은 `ui_targets.cleared -> record.deactivated -> actor.cleanup.complete -> unregisterActor.complete -> registry.cleared` 순으로 끝까지 이어졌다.
- cleanup 뒤에는 `ContextTrace stage=candidate.rejected | reason=leftover_death_object`가 남아, 남은 zombie가 NPC 컨텍스트 타깃으로 재채택되지는 않았다.

### Interpretation / lesson
- 이번 로그는 "안 보이는 이유가 alpha/ghost/invisible/scene-cull/simple visual-missing 쪽은 아니다"를 더 강하게 지지한다.
- 살아 있는 embodied actor는 논리적으로는 이미 꽤 정상이다. 따라서 1순위는 여전히 alive presentation/render path 자체다.
- 특히 Build 42에서 현재 `IsoPlayer` 기반 embodied NPC가 world 등록과 visual data를 갖고도 실제 draw path에 오르지 않거나, model/render registration 층에서 누락될 가능성이 가장 크다.
- stale target 관점에서는 개선 신호가 있다. cleanup에서 UI target이 먼저 정리되고, 이후 leftover zombie도 candidate에서 거절됐다.
- delete crash는 이번 테스트에서 직접 `debug.delete.request`가 실행된 흔적은 없어서 "완전 해소"라고 단정할 수는 없다. 다만 같은 cleanup contract를 쓰는 death cleanup은 예외 없이 끝났다.
- corpse flicker는 이번 로그만 보면 줄어든 편이다. corpse/player/zombie가 교대로 튀는 패턴은 없었고, 대신 "dead IsoPlayer + separate IsoZombie 동시 존재"가 짧게 나타났다.
- death overlap은 완전히 사라지지 않았다. corpse를 보지 못한 채 원래 actor가 잠깐 남아 있고, 별도 zombie가 같은 칸에 생긴다.

### Code or document changes that followed
- 이번 턴은 런타임 코드 수정 없이, 최신 로그 분석 결과를 문서에만 반영했다.
- `docs/WORK_NOTES_2026-03-11.md`에 최신 테스트 기준 남은 1순위와 후속 개선 포인트를 추가했다.

### Next thing to verify
- alive 상태의 `IsoPlayer` embodied actor가 실제 render/model registration에 올라가는지 별도 trace를 추가해 확인한다.
- death 시점에 separate zombie가 확인되면 원래 death-like actor를 더 빨리 정리할 수 있는지 본다.
- 다음 테스트에서는 생성 직후 `ActorFactory`와 `OnCreate*` 구간이 콘솔에 남도록 로그 보존 범위를 확보한다.

## 2026-03-20 02:47 KST — Hybrid appearance runs, hostile wakes up, zombie shell still wins

### In-game result
- dump helpers no longer crashed.
- visible shell still looked like an ordinary zombie.
- `hostile` caused the shell to actively come after the player.
- `friendly` / `neutral` did not obviously attack, but the player heard repeated tiny footstep sounds as if movement and pinning were fighting each other.
- forcing relationship state and repeatedly adjusting trust produced intermittent errors.

### Log signals
- hybrid summary now shows the appearance experiment truly ran:
  - `exp=isozombie_shared_desc_visual_v1:applied@sync_pending_applied`
  - descriptor source moved to `npc_record_survivor_desc_*`
  - bridge reported `item_visuals_present`
- despite this, live actor visuals still reported zombie rendering state:
  - `presentationRole=reanimated_zombie`
  - zombie body skin such as `M_ZedBody04_level1`
- every policy/trust-driven sync could throw the same Java exception:
  - `NullPointerException: Cannot assign field "isNpc" because "this.player" is null`
  - stack traced through `IsoGameCharacter.setNPC(...)`
  - Lua entry point was `23_LWN_ActorFactory.lua -> refreshActorPresentation()`
- hostile state clearly changed runtime posture:
  - debug actor line showed `stance=hostile_player safety=attackable`
  - logs also showed repeated path/movement warnings such as `WalkTowardState but path2 != null`
  - debug action queue could fill with repeated `retreat`

### Interpretation / lesson
- the hybrid appearance experiment is now genuinely executing; the failure is no longer “experiment never ran”.
- descriptor/human-visual reuse alone is not enough to beat the zombie presentation pipeline.
- `setNPC(true)` is unsafe on the live `IsoZombie` carrier and is likely a direct source of the new error spam.
- non-hostile suppression is incomplete because some movement/deferred-path state survives or gets re-enqueued after policy sync.
- hostile behavior is now partially real, which is an important milestone: policy is affecting live behavior, not just metadata.

### Code or document changes that followed
- analysis and handoff docs were updated after the run so the next session can resume from the new blocker set instead of re-proving earlier findings.

### Next thing to verify
- remove or hard-gate `setNPC(true)` from zombie appearance refresh and confirm the relationship/trust sync errors disappear.
- strengthen non-hostile movement suppression until repeated footstep/path churn stops.
- probe whether zombie body/presentation-role overrides are the real limiting layer for human appearance on `IsoZombie`.

## 2026-03-21 01:55 KST — Persistent illusion pass stabilizes non-hostile shells, but hostile still reads zombie

### In-game result
- forcing `friendly` / `neutral` now leaves the shell visibly calm; the earlier repeated tiny footstep churn largely disappeared
- after switching from `hostile` back to `neutral` / `friendly`, the shell stopped immediately instead of treadmill-walking in place
- the shell still rendered as a zombie in every state
- after the persistent-illusion pass, the shell no longer emitted obvious zombie vocal sounds
- however, this audio suppression was probably too blunt: during treadmill-like motion, normal footstep presence also felt absent
- user clearly observed that the first forced state change after spawn caused an outfit / appearance change; later transitions back to `friendly` did not repeat that dramatic change every time
- hostile still looked and felt like a zombie attacking the player, not a human-like hostile NPC

### Log signals
- non-hostile suppression now consistently showed:
  - `npc decision :: source=policy_suppressed_combat`
  - `npc actionQueue :: none`
  - `npc movement_audio :: ... queue=none ... neutralized=true`
- the combat retreat churn source was successfully isolated and then suppressed for neutralized shells
- hostile still produced combat-driven behavior and zombie-coded pursuit/attack read
- appearance diff logging confirmed the first strong appearance refresh was real, not imagined:
  - `stage=appearance.diff`
  - diff fields included changes such as:
    - `skin:M_ZedBody02_level1->M_ZedBody04_level1`
    - `hair:Mullet->Fabian`
    - `beard:Chin->PointyChin`
    - `itemVisuals:7->6`
    - `wornItems:0->3`
    - `persistentOutfitId:4325872->4325390`
- despite the real appearance refresh, actor summaries still reported zombie presentation state:
  - `presentationRole=reanimated_zombie`
  - zombie body skin remained active
- persistent illusion metadata now appeared in debug output, including:
  - `audioHuman=descriptor_voiceprefix+emitter_stopall`
  - `illusion=walk_human+no_lunge+voice_notazombie+audio_stopall+hitreaction_guard`

### Interpretation / lesson
- the project crossed an important threshold: the current `IsoZombie` route is no longer just about making the shell stable; it is now clearly about managing an illusion stack
- non-hostile behavior is now much closer to the intended design: calm, quiet, and policy-controlled
- the first state-change appearance jump strongly suggests humanization is currently landing on the first major sync rather than being fully completed at spawn time
- appearance changes are real and meaningful at the clothing / grooming / outfit-id layer, but they still terminate inside zombie presentation role / zombie body skin
- the audio pass proved that zombie-coded sound leaks can be suppressed, but the current method likely over-suppresses and removes too much sonic presence
- hostile remains the main embodiment gap: it is still "managed zombie aggression" rather than a convincing human hostile profile

### Code or document changes that followed
- `9dad167` removed dead legacy remnants that were no longer supporting the spike
- `5d9686b` strengthened non-hostile suppression and improved shell observability
- `66b63d9` added high-yield decision / movement / audio diagnostics
- `d90b005` blocked neutralized combat churn and added real appearance diff logging
- `9305213` applied a Bandits-inspired persistent illusion package (voice prefix, walk type, no-lunge, hit-reaction guard, emitter suppression)
- research synthesis was also expanded today across:
  - `LWN_ISOZOMBIE_MASTER_REFERENCE_2026-03-21.md`
  - `LWN_ISOZOMBIE_CLEANUP_TRIAGE_2026-03-21.md`
  - `REFERENCE_CORPUS_ISOZOMBIE_AUDIT_2026-03-20.md`
  - `BUILD42_ISOZOMBIE_NPC_WEB_MEMO_2026-03-20.md`
  - `BUILD41_78_JAVADOC_SKEPTICAL_AUDIT_FOR_BUILD42_ISOZOMBIE_SHELL_2026-03-20.md`
  - `PZWIKI_BUILD42_ISOZOMBIE_SHELL_REVIEW_2026-03-20.md`

### Next thing to verify
- split humanization into an explicit first-apply phase versus later maintenance reassertion, so the first forced state change is no longer the moment where the shell visibly "changes clothes"
- replace blunt `emitter:stopAll()`-style suppression with narrower zombie-vocal suppression so human/presence cues are not also erased
- introduce a hostile-specific illusion profile so hostile shells stop reading like plain zombies with some suppressions turned off
- continue treating final zombie presentation role / zombie skin as the likely hard limit until evidence proves otherwise

## 2026-03-24 23:27 KST — Distance-return test exposed continuity friction and debug-menu clutter

### In-game result
- after spawning a test NPC and moving far away, returning did not restore a clearly visible NPC to the player’s eye
- the user could not confidently tell whether the NPC was truly deleted or merely not visible/presented
- the current debug menu was noisy enough that it actively slowed down test iteration

### Log signals
- code review after the test showed that hidden rearm and embody range checks still used `record.anchor.x/y` rather than the last embodied meta position
- despawn already stores `Store.setEmbodiedMeta(record.id, { x, y, z, ... })`, but rearm path was not preferring that location
- debug-spawned NPCs were still eligible for normal distance-based despawn behavior, which can interfere with rapid test loops
- UI context debug options still exposed legacy carrier experiments and dangerous actions alongside the main IsoZombie test lane

### Interpretation / lesson
- this test was not clean evidence about humanization timing by itself because embodiment continuity policy was still able to contaminate the result
- the likely issue is not simply “NPC deleted forever”, but a continuity mismatch between despawn bookkeeping, rearm distance checks, and test-oriented debug behavior
- debug tooling itself had become part of the problem: too many unrelated menu entries reduced testing speed and clarity

### Code or document changes that followed
- updated embodiment continuity so hidden rearm / embody checks can prefer last embodied meta position over anchor-only distance checks
- pinned debug-spawned NPCs in-world by default during tests, via config-driven `KeepDebugSpawnsEmbodied`
- widened debug spawn despawn radius config as a fallback if pinned mode is disabled later
- reorganized context debug menu into:
  - `IsoZombie Test`
  - optional `Legacy / Carrier Experiments`
  - optional `Danger Zone`
- kept legacy carrier items hidden by default and moved destructive actions out of the main test lane

### Next thing to verify
- spawn one IsoZombie debug NPC, walk far away, return, and confirm the NPC either remains embodied or rearms predictably near the last embodied position
- confirm the debug menu now supports a fast loop of: spawn → dump summary → force policy → dump movement/audio
- if the NPC still appears missing after continuity fixes, capture whether debug dumps show a live embodied actor with no visible presentation, which would re-point suspicion back to rendering/presentation rather than lifecycle

## 2026-03-25 00:12 KST — Identity collapse observed, test lane pivoted to sterile harness

### In-game result
- user spawned exactly one debug NPC, moved far away, and returned
- on return, the originally spawned NPC appeared to have collapsed back into a normal zombie-like read
- at the same location, the user felt there was now also a "new NPC" present, creating a strong duplication impression

### Log signals
- console review showed only one explicit debug embodiment spawn for the test run: `LWN-000038`
- subsequent log lines continued to track the same managed actor reference (`IsoZombie ID:72`) rather than a clearly separate second managed actor
- debug pinning was active, so normal debug despawn was not the main explanation
- the managed shell's appearance signature drifted across time, and the shell remained under zombie-coded presentation role
- nearby ordinary zombies were still part of the local world state, increasing ambiguity

### Interpretation / lesson
- the strongest problem was not confirmed true duplication but **identity collapse under test conditions**
- a single managed shell could still be misread as:
  - a normal zombie
  - a replaced shell
  - a duplicated shell
- this meant the test lane itself was no longer trustworthy enough for evaluating deeper humanization work

### Code or document changes that followed
- created a sterile test harness around debug IsoZombie spawns
- added nearby world-noise cleanup before and after spawn
- forced hold-position/friendly harness posture for the test shell
- added identity-lock-aware maintenance behavior so test maintenance does not eagerly behave like re-randomization
- expanded debug output with test harness metadata and locked signature reporting
- documented the new test lane in `TEST_IDENTITY_HARNESS_2026-03-25.md`

### Next thing to verify
- spawn a sterile test NPC and confirm the area is visibly cleaner of ordinary zombies
- walk away and return, then verify the same harness label / npcId remains the focus of debug dumps
- confirm movement/pathing churn stays low enough that the shell remains locally findable
- confirm maintenance now prefers holding the locked identity instead of escalating into an obviously different look during the test loop

## 2026-03-25 00:48 KST — Audio suppression works after policy sync, but shell still risks actor_lost zombie reversion

### In-game result
- spawn-time shell still emitted zombie-like sound at first
- after forcing relationship policy, the shell stopped making zombie-like sound
- after travelling away and returning, the shell appeared to behave like a normal attacking zombie
- deleting nearby ordinary zombies also removed what the user perceived as the reverted shell

### Log signals
- initial spawn path still showed a settle gap before full runtime/presentation readiness
- later debug state showed non-hostile suppression metadata working as intended
- eventual cleanup path clearly showed `reason=actor_lost`, after which the record fell to `hidden`
- cleanup/deletion then targeted the LWN record while the player-facing shell identity had already collapsed

### Interpretation / lesson
- suppression logic itself is not dead; it lands after policy/humanization sync
- the bigger issue is still managed-shell control across lifecycle drift, especially around actor-loss/rebind boundaries
- test harness stability needed another step beyond sterile lane + identity lock: stronger quarantine and stronger actor tethering

### Code or document changes that followed
- added spawn/sync-side emergency quarantine for debug harness shells
- enforced quarantine again during embodied ticks so action/combat drift is less able to re-wild the shell
- broadened actor recovery signals to include last known id / harness label / carrier-handle identity
- preserved hidden alive records' last known position for continuity and future recovery
- documented the pass in `QUARANTINE_TETHER_HARDENING_2026-03-25.md`

### Next thing to verify
- confirm spawn-time zombie audio leak is reduced by the new emergency quarantine path
- confirm distance-return tests no longer collapse as easily into `actor_lost`
- confirm quarantined debug shells remain neutralized unless deliberately released from quarantine later

## 2026-03-25 01:21 KST — Spawn audio improved, appearance stabilized, but distance-return still restores hostile zombie-like behavior

### In-game result
- spawn-time zombie audio leak was no longer observed immediately after spawn
- after travelling away and returning, the shell still behaved like a normal hostile zombie and clearly walked toward the player to attack
- appearance changed once at the first forced relationship-policy refresh, then stayed visually stable afterward

### Log signals
- recent code behavior strongly suggests quarantine improved the initial spawn layer enough to reduce early audio leakage
- identity lock / initial-humanization split also appears to have reduced repeated appearance churn
- however, behavior authority still remains vulnerable after recovery / distance-return transitions

### Interpretation / lesson
- appearance is no longer the sharpest blocker in this test lane
- the stronger remaining failure is that the managed shell can still regain zombie-native pursuit/attack authority after return/recovery
- the next pass therefore needs to lock behavior authority harder, not just maintain identity and appearance

### Code or document changes that followed
- added stronger recovery-time re-neutralization in the event layer
- made quarantined shells skip normal goal/action progression more aggressively
- blocked hostile forcing via debug policy tools while quarantine is active by default
- documented the pass in `BEHAVIOR_AUTHORITY_LOCK_2026-03-25.md`

### Next thing to verify
- confirm distance-return no longer restores obvious hostile pursuit/attack under quarantine
- confirm the stronger behavior lock does not regress the newly improved spawn-time audio quieting
- confirm appearance remains stable while stronger behavior authority suppression is active

## 2026-03-25 01:50 KST — Split-body suspicion moved focus toward appearance-lock restore and object census

### In-game result
- spawn-time shell remained quiet
- after distance-return, the user perceived two bodies on screen at once:
  - the original shell-like body, which emitted zombie sound and later disappeared via nearby zombie cleanup
  - a second body, which did not disappear via that cleanup
- appearance seemed to change first on hostile forcing and again on a later friendly forcing, then stopped changing further

### Log signals
- earlier console review still did not prove a second managed `LWN-...` spawn id
- this kept suspicion centered on managed-shell continuity split or leftover/orphaned zombie-like bodies rather than a clean second managed spawn
- repeated appearance drift remained consistent with policy-transition-triggered sync/humanization churn

### Interpretation / lesson
- the runtime problem is no longer well described as only behavior authority drift
- there is now strong reason to suspect a split between:
  - a zombie-like/orphan-like body that can still be treated as ordinary cleanup noise
  - a more protected/managed body that remains after cleanup
- policy transitions remain one of the clearest suspected triggers for appearance instability

### Code or document changes that followed
- nearby ordinary-zombie cleanup now preserves any zombie-like object with LWN identity markers, not just currently managed actors
- added `Dump Nearby Zombie-like Objects` so tests can inspect every nearby zombie-like body and its LWN markers/cleanup-candidate status
- changed identity-lock maintenance to avoid blindly refreshing presentation when a locked shell is already in mismatch, recording `maintenance_identity_lock_restore_pending` instead
- documented the pass in `APPEARANCE_LOCK_RESTORE_AND_CENSUS_2026-03-25.md`

### Next thing to verify
- force the same hostile→friendly-style policy sequence and see whether appearance now stabilizes earlier
- when two bodies are visible, dump nearby zombie-like objects immediately and compare their LWN markers and cleanup-candidate status
- verify whether the original shell-like body still vanishes under cleanup or is now preserved for better diagnosis
