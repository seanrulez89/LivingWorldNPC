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

## 2026-03-25 02:29 KST — Consolidated lock against return-path hostile reversion

### In-game result
- user confirmed a stronger and clearer failure shape:
  - after distance-return, the originally spawned shell could emit zombie audio, pursue, and land real hit events before new manual policy toggles
  - nearby zombie cleanup could remove the visible attacker from view
  - relationship controls still worked until explicit delete, proving record/object detachment persisted

### Log/behavior interpretation
- this pattern points to return/recovery-time shell authority leakage more than pure appearance-only drift
- cleanup semantics also indicated that a visible attacker object could be removed while the logical record remained active

### Code or document changes that followed
- added recovery attack-quarantine state and metadata at schema/runtime levels
- enforced suppression while recovery attack-quarantine is active, not only while harness quarantine is active
- hardened actor_lost path to salvage likely live shell actor references before cleanup finalization
- strengthened debug nearby-zombie cleanup to preserve objects bound to live records, not just objects with obvious LWN markers
- expanded debug telemetry with attack-lock fields
- documented consolidation in `DISTANCE_RETURN_HOSTILE_REVERSION_LOCK_2026-03-25.md`

### Next thing to verify
- after distance-return, confirm whether attack starts before attack-lock expiry
- verify whether `attackLock` fields are present on the attacker-looking shell at the moment of threat
- verify that nearby zombie cleanup no longer removes currently bound shell objects while the record remains alive

## 2026-03-25 02:45 KST — Added manual-assisted automation for repeatable debug test flow

### In-game / workflow need
- the manual test loop had become too click-heavy and timing-sensitive
- important runtime windows could be missed before the right dump button was pressed
- user explicitly wanted automation for spawn / dump / policy-sequence / return-phase dump, while keeping sound/visual judgment manual

### Code or document changes that followed
- added an `Automation` submenu under `IsoZombie Test`
- implemented a tracked multi-phase automated scenario:
  - start -> spawn baseline dumps
  - continue -> hostile/friendly policy cycle with dumps
  - continue again after return -> return-phase dumps + zombie census + last actor failure
- added explicit in-game prompt messages telling the human what to observe and when to move away / return
- tracked the automation scenario by concrete `npcId` instead of relying purely on repeated nearest-target clicking
- documented the workflow in `MANUAL_ASSISTED_AUTOMATED_TEST_RUNNER_2026-03-25.md`

### Next thing to verify
- confirm the automated sequence targets the intended test NPC consistently across all three phases
- confirm the prompts are clear enough that the user can pause for sound/visual observation at the right times
- confirm the return-phase dump captures the relevant hostile-reversion or split-body moment more reliably than the old manual click sequence

## 2026-03-25 03:28 KST — Final test of the day: automation useful, hostile reversion remains, posture still fails

### In-game result
- spawn-time zombie audio was still suppressed well enough that the user did not notice immediate zombie sound
- after distance-return, before any new relationship toggle, the originally spawned NPC immediately showed hostile intent and attacked the player, including real hit confirmation
- in this final run, the earlier split-body/two-bodies-at-once symptom was not observed
- posture still looked hunched and zombie-like to the user; the anti-hunch experiment did not meaningfully change the read
- the automated test runner was useful in principle, but its speech-bubble prompts were unreadable because Korean text appeared garbled/encoding-broken
- `Continue Automated Test` may still have triggered at least one clothing/appearance change, but the user was not fully certain
- when nearby-zombie cleanup was used after the hostile return, the visible attacker disappeared from view

### Interpretation / lesson
- automation is worth keeping, but its prompt channel currently needs to avoid broken Korean speech-bubble text
- the strongest remaining gameplay/runtime failure is still return-path hostile reversion of the original spawned shell before any new manual policy input
- posture correction via the current accessible idle/anim reset approach appears insufficient; zombie hunch remains a major tell
- the split-body problem may be intermittent rather than guaranteed on every return-path run
- visible attacker removal by nearby-zombie cleanup again suggests world object / logical record separation remains a live concern, though this exact run did not fully re-check whether logical controls still persisted afterward

### Code or document changes that followed
- none yet in this entry; this log is intended as the end-of-day stable handoff point before the next session continues from the remaining failures

### Next thing to verify
- switch automation speech-bubble prompts to an encoding-safe prompt strategy (likely ASCII/English or a different in-game notification path) before relying on them heavily again
- use the automated flow to check whether `attackLock` is present at the exact moment of return-path hostility
- verify again whether nearby-zombie cleanup removes only the visible shell while relationship/debug controls still target the logical record
- decide whether posture work should pause behind behavior-authority/recovery fixes, since posture improvements currently do not survive user perception testing

## 2026-03-27 23:39 KST — Repeated failure shape confirms pre-surgery reset is needed

### In-game result
- overall game audio returned to normal after the targeted-mute hotfix, so the earlier total-silence issue is no longer contaminating tests
- zombie vocal/read returned too, confirming earlier "quiet NPC" impressions were likely mixed with the broader audio failure
- the test NPC still rendered as a full zombie and did not produce any real displacement
- after leaving and returning, the familiar split pattern repeated:
  - the original NPC read as a normal roaming zombie
  - a different-looking replacement appeared near the anchor
  - this time the replacement also showed in-place attack-like stepping instead of staying completely still
- using nearby ordinary-zombie cleanup removed the roaming original shell from view
- a new and important clue appeared: forcing the replacement friendly changed its appearance and that new appearance then stayed stable; later relationship forcing no longer caused obvious further rerolls

### Log signals
- the test harness now really does release hold during movement tests:
  - `hold=false` appeared during TEST 02/03
- but movement still failed at the deeper level:
  - `moving=true`
  - `path2=true`
  - `totalDelta=0.00`
  - `squareChanged=no`
- non-hostile command flow still carried `neutralized=true` while trying to path, so the command lane is still partially mixed with suppression/quarantine semantics
- spawn-time humanization still failed baseline checks:
  - `presentationRole=reanimated_zombie`
  - `humanInit=false`
  - probe remained negative on the default spawn path
- forcing the shell into a stronger friendly/trusted-companion style later in the run triggered real presentation work:
  - appearance changed
  - the changed appearance remained stable
  - the actor state shifted toward non-hostile mobile maintenance instead of the earlier command-only shell read
- return/recovery still broke continuity hard:
  - repeated `recovery.cached_miss`
  - repeated `handle_reclaim_failed`
  - repeated `handle_rejected`
  - repeated `candidate_missing`
- the protected managed shell logic in nearby cleanup now works better for the known managed object, but the broader gameplay problem remains because the logical/original shell split is still happening before cleanup time

### Interpretation / lesson
- the last few hardening passes did improve observability and fixed the worst global-audio regression, but the core runtime failure shape barely moved
- the strongest remaining blockers are now clearer than before:
  1. spawn-time humanization still does not truly succeed on the default path
  2. same-shell friendly command locomotion still does not translate pathing into real world movement even after hold release
  3. return-path continuity still collapses into original-shell-versus-replacement split behavior
- the friendly/neutral/hostile relationship matrix is now making experiments noisier instead of more informative
- the most important positive clue in this run is that later friendly/trusted-companion reapply can visibly change and then stabilize appearance; that suggests the appearance system is not universally impossible, but the initial spawn pipeline and same-actor authority model are likely wrong

### Code or document changes that followed
- no new runtime patch is recorded in this test-log entry itself; instead, the project state is being frozen and documented before a larger surgery phase
- the pre-surgery docs and branch plan are the meaningful follow-up output from this point

### Next thing to verify
- freeze the current baseline cleanly in docs and git before further structural work
- simplify experiments by removing neutral/hostile policy churn from the main test lane and using a locked-friendly companion baseline first
- split big-surgery work into a dedicated branch so the current `spike/isozombie` line remains a readable pre-surgery baseline
- in the surgery branch, prioritize role separation, generation-based identity, failed-shell rebuild, and a deterministic movement path for the friendly companion shell

## 2026-03-28 02:30 KST — First real minimal-dummy progress: no zombie vocal, no aggression, real displacement

### In-game result
- TEST 01:
  - the dummy still rendered with a zombie-looking exterior
  - zombie vocal sound was gone
  - other game sounds remained normal
  - no active aggression was observed
- TEST 02:
  - the dummy still looked zombie-like
  - zombie vocal remained suppressed
  - aggression still did not appear
  - most importantly, the dummy **actually moved** for the first time in this reduced architecture
- TEST 03:
  - no major new visual change was observed beyond the movement success already seen in TEST 02
- return / TEST 04 was intentionally skipped because the current milestone focus is movement-first, not recovery-first

### Log signals
- repeated hard dummy idle enforcement showed:
  - `lane=dummy_idle`
  - `target=false`
  - `moving=false`
  - `path2=false`
- after move command, repeated hard dummy move enforcement showed:
  - `lane=dummy_move`
  - `target=false`
  - `moving=true`
  - mostly `path2=false`
- the crucial movement summary changed shape for the first time:
  - `motor=stepping`
  - `totalDelta=1.41`
  - `squareChanged=yes`
  - `canWalk=yes`
  - `useless=no`
- old zombie-native path dependence weakened:
  - the successful movement summary no longer depended on `path2=true`
  - the deterministic motor path was active instead
- the shell was still visually wrong according to the human observer, even though the summary still reported positive humanization flags

### Interpretation / lesson
- this run is the first proof that the minimal-dummy reset is actually working at the right layer
- the major progress did **not** come from more relationship tuning or more combat suppression flags alone
- it came from changing the architecture in three important ways:
  1. removing social/story/goal churn from the active test lane,
  2. turning the shell into a repeatedly enforced hard dummy contract,
  3. bypassing zombie-native locomotion with a deterministic move motor
- this means the main blocker has narrowed sharply:
  - movement and aggression are no longer the dominant mystery
  - **visual humanization is now the clearest remaining blocker**
- the current humanization probe is now suspected to be too optimistic or partially false-positive, because the player still saw a zombie-looking shell while the debug summary claimed `humanInit=yes` and `probeOk=yes`

### Code or document changes that followed
- no additional code patch is recorded in this test-log entry itself; the test is important because it validates the direction of the new minimal-dummy branch
- the correct follow-up after this run is:
  - document why progress finally happened,
  - then prioritize full spawn-time appearance path replacement / stronger appearance truth checks,
  - only after that return to recovery generation work

### Next thing to verify
- replace or harden the appearance success probe so it better matches what the human actually sees on screen
- promote the rebuild-based appearance path further into the default initial spawn path for minimal dummy shells
- keep deterministic movement intact while improving final arrived/stalled classification
- do not re-introduce relationship complexity before the visual shell stops reading as a zombie

## 2026-03-28 03:55 KST — Move authority and position commit worked; visual aggression residue remains

### In-game result
- TEST 01:
  - dummy still rendered with a zombie-looking exterior
  - zombie vocal remained suppressed
  - no active aggression at spawn
  - dummy stayed stationary as expected
- TEST 02:
  - dummy still rendered with the same zombie-like exterior
  - zombie vocal remained suppressed
  - movement succeeded again and looked more like a very fast walk than a pure teleport
  - the dummy did **not** snap back to the original position after the automated move
  - after arrival, the dummy began in-place stepping / attack-like body language again
  - however, it still did not land an actual attack on the player
  - when the player stood very close or physically contacted the dummy, the in-place stepping paused
- TEST 03:
  - no major new visual change
  - zombie-like exterior persisted
  - zombie vocal still suppressed
  - attack-like in-place stepping could reappear after shove/contact changes
- manual `Command Nearest Dummy To Test Destination`:
  - movement succeeded
  - the dummy again did **not** snap back to the original location
  - the move also read as a very fast walk
- deletion result:
  - this time delete was blocked again, but the reason shifted from a persistent target-style interpretation toward an `actor_is_attacking` style state even though the player still did not observe real attack hits landing

### Log signals
- movement summary now clearly recorded committed arrival state:
  - `cmd=designated_location/arrived`
  - `motor=arrived`
  - `commit=<new square>`
  - `squareChanged=yes`
  - `totalDelta≈8`
- the new committed square matched the updated anchor / current square after movement, meaning the logical position and visible position were now much better aligned
- the old manual-command regression (move briefly, then return to original anchor) no longer reproduced in this run
- appearance remained unresolved but now more honestly so:
  - `probeOk=no`
  - `appLock=no`
  - `appFail=yes`
  - visual signature still read as `reanimated_zombie|F_ZedBody...`
- delete block reason in the latest run pointed to `actor_is_attacking`, which is meaningfully different from earlier `actor_has_target` style failures

### Interpretation / lesson
- this run strongly suggests the recent move-authority and position-commit work succeeded at the right layer
- the project no longer appears stuck on the old "move, then snap back" problem in the main dummy flow
- the remaining post-move problem is now better described as **visual aggression / attack-presentation residue**, not as a full return to real hostile zombie behavior
- the user’s observation that the dummy stopped its in-place stepping when standing in direct contact with the player is an important clue that body/turn/attack presentation is still reacting to nearby collision/proximity conditions even when real attack behavior is mostly suppressed
- the biggest remaining blockers are now:
  1. zombie body visual lock (`F_ZedBody...`, `reanimated_zombie` signature)
  2. attack-like presentation residue after movement
  3. player-facing / turn-to-player residue after movement
- this is a major narrowing compared with earlier sessions: movement authority and position authority are no longer the top mystery

### Code or document changes that followed
- none yet in this test-log entry itself; this entry marks the end-of-day freeze after proving that move authority and committed position got materially better on the minimal dummy branch

### Next thing to verify
- add a visual-aggression scrub pass that clears attack/alert/turn presentation residue after movement and while idle
- hard-fail zombie body skins / corpse-style presentation more explicitly in the dummy appearance truth gate
- keep recovery / TEST 04 de-prioritized until visual aggression and body appearance improve further

## 2026-03-28 16:03 KST — Move-idle handoff fix resolved post-arrival aggression residue; visual shell remains the top blocker

### In-game result
- TEST 01:
  - exactly one dummy spawned
  - zombie-looking exterior persisted
  - zombie vocal remained suppressed
  - no aggression or player recognition appeared
  - the dummy stayed still
- TEST 02:
  - movement again succeeded and visibly progressed across multiple intermediate positions
  - the dummy reached the destination successfully
  - after arrival, the dummy stayed quiet and still
  - the earlier in-place stepping / attack-like posture did **not** reproduce in this run
  - approaching or shoving the dummy also did **not** trigger renewed aggression-looking posture in the observed run
- TEST 03:
  - no major new visible change
  - the shell remained zombie-looking but non-aggressive and quiet
- cleanup result:
  - `clean` still did not remove the dummy itself
  - `delete` successfully removed the dummy

### Log signals
- spawn remained stable under the spawn-safe scrub grace:
  - early lines showed `dummy_contract_idle_applied` and repeated `dummy_scrub_skipped_spawn_grace`
  - summary stayed at `lane=dummy_idle`, `attacking=no`, `target=no`
- movement still committed correctly:
  - `cmd=designated_location/arrived`
  - `motor=arrived`
  - `commit=3753,10997,0`
  - `totalDelta=7.00`
  - `squareChanged=yes`
- the strongest new signal was post-arrival shell stability:
  - `dummy_contract_move_applied` appeared only 4 times total and only around move startup
  - `dummy_contract_idle_applied` appeared 195 times
  - `attacking=yes` appeared 0 times
  - `target=yes` appeared 0 times
  - after arrival, repeated idle-contract maintenance dominated the log instead of renewed move-shell pressure
- appearance still failed honestly:
  - `probeOk=no`
  - `appLock=no`
  - `appFail=yes`
  - `PresentationGuard` continued blocking `restore_false_flags` / `repair_alpha` with `reason=zombie_or_reanimated`
- cleanup / delete behavior became clearer:
  - `clean` logged `debug_cleanup.protected_managed_shell`
  - `delete` succeeded through `deleteNpcById:immediate_noncombat`

### Interpretation / lesson
- the recent move-idle handoff patch (`70bebb0`) appears to have fixed the previously dominant stale move-authority / post-arrival handoff problem
- the branch no longer appears to be primarily blocked by post-move aggression-presentation residue
- the top remaining blocker is now even more clearly **visual shell correctness / alive-state appearance truth**
- this is major progress because the project’s dominant mystery has narrowed again:
  1. spawn stability is much better
  2. movement is real and committed
  3. post-arrival aggression-looking residue is much lower / absent in this run
  4. the main unresolved layer is still zombie-looking body presentation

### Code or document changes that followed
- documented the retest and current interpretation in:
  - `docs/MINIMAL_DUMMY_MOVE_IDLE_HANDOFF_RETEST_2026-03-28.md`
  - `docs/NEXT_SESSION_HANDOFF_2026-03-28.md`

### Next thing to verify
- keep `TEST 01~03` as the main validation lane
- prioritize appearance truth / zombie-body fail analysis over new aggression scrub work
- keep recovery / TEST 04 de-prioritized until the shell stops reading as `reanimated_zombie|...`

## 2026-03-28 17:08 KST — Strategic decision: exhaust the current LWN appearance pipeline before gradual Bandits visual borrowing

### Why this decision was made
- the latest minimal dummy retests materially improved:
  - spawn stability
  - movement truth / committed displacement
  - post-arrival calmness
  - move→idle handoff
- this means the branch is finally stable enough to isolate **appearance** as its own problem instead of one symptom among many runtime failures
- because of that, the project can now extract much better lessons from the current LWN descriptor/hybrid pipeline before introducing Bandits-style direct visual stamping

### Strategic conclusion
- do **not** switch wholesale to the Bandits approach yet
- do **not** abandon the current LWN hybrid / descriptor architecture yet
- instead, first exhaust the meaningful remaining experiment space inside the current approach
- only after the current approach reaches a clearer ceiling should the project gradually borrow Bandits-style direct visual stamping, and only at the missing layer

### Comparison that drove the decision
- Bandits is strongest at:
  - direct `HumanVisual` mutation
  - direct `ItemVisual` population
  - aggressive cleanup of visual residue
  - repeated shell / walktype reassertion
- LWN is currently strongest at:
  - canonical record-driven identity
  - stronger diagnostics / strict visual probing
  - cleaner shell lifecycle and validation lane
  - preserving future commandable non-hostile behavior

### Agreed next patch waves
- Patch Plan 1 — appearance forensics / failure taxonomy
  - split the current broad visual failure into exact failing layers and codes
- Patch Plan 2 — phase-aware rebuild / timing experiments
  - test whether the current method works better when applied later (runtime settle / post-arrival) rather than only at spawn
- Patch Plan 3 — guard / role / overwrite hardening
  - test whether `PresentationGuard`, zombie-coded role truth, or post-refresh overwrite is the final blocker

### Main planning doc added
- `docs/OUR_APPROACH_FIRST_EXPERIMENT_PLAN_BEFORE_BANDITS_ADOPTION_2026-03-28.md`

### Main practical takeaway
- the immediate goal is **not** “become more like Bandits”
- the immediate goal is:
  - preserve the diagnostic clarity gained from the minimal dummy stabilizations,
  - push the current LWN appearance path to its maximum informative limit,
  - then adopt only the specific Bandits-style visual techniques that the current pipeline truly proves it still lacks
