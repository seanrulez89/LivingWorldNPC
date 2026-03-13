# LivingWorldNPC Work Notes

Date: 2026-03-11

## 작업 목표
- 최우선: embodied NPC가 월드에 실제로 보이도록 시각적 실체화 경로를 보강한다.
- 병행: 로그/주석/디버그 도구/문서를 강화하고, MD에 적혀 있던 일부 디버그·스토리 기능을 구현한다.

## 코드 근거 기반 관찰
- 로컬 `console.txt` 기준 최근 테스트에서는 `ActorFactory`가 embodied 직후 다음을 남겼다.
  - `world=true`
  - `ghost=false`
  - `invisible=false`
  - `sceneCulled=false`
  - `alpha=1.00`
- 따라서 "월드에 없어서 안 보임"만으로는 현재 증상을 설명하기 어렵다.
- 남은 직접 후보는:
  - descriptor가 실제 body mesh / human visual로 반영되지 않음
  - worn item 변경이 model refresh로 이어지지 않음
  - ModelManager 쪽 렌더 등록/리셋이 누락됨

## reference_mods 재검토 메모
- Bandits `shared/Bandit.lua`
  - `Bandit.ApplyVisuals()`에서 `getHumanVisual()`, `getItemVisuals()`, `getWornItems():clear()`, `setFemaleEtc()`, `resetModel*()`를 강하게 묶는다.
- BanditsCreator `OptionScreens/*`
  - `IsoPlayer.new(...)` 직후 `setFemale(...)`, `getHumanVisual():setSkinTextureIndex(...)`, `setWornItem(...)`를 직접 호출한다.
  - preview actor는 world actor의 직접 레퍼런스가 아니다.

## 이번 패치에서 넣은 것
- `23_LWN_ActorFactory.lua`
  - `visualSummary` 로그 추가.
  - `ModelManager.instance:Add/Reset/ResetNextFrame/ResetCharacterEquippedHands` 재호출.
  - `Dressup(desc)` / `InitSpriteParts(desc)` / `setFemale(...)` / `onWornItemsChanged()` 보강.
  - worn item 적용 시 `ItemBodyLocation.get(ResourceLocation.of(...))` 경로 fallback 추가.
- `24_LWN_ActorSync.lua`
  - embodied actor에 gender/NPC/visibility flag를 매 tick 재강제.
- `90_LWN_EventAdapter.lua`
  - `OnCreateSurvivor`에서도 visual refresh 경로 재사용.
  - `EveryTenMinutes`에서 clue 생성과 world event 적재 시작.
  - `OnKeyPressed` 기반 디버그 핫키 연결.
- `92_LWN_DebugTools.lua`
  - nearest NPC dump
  - wipe + reseed
  - relationship cheat
  - story beat inject
  - force legacy candidate
  - F3-F8 hotkey
- `20_LWN_ActionRuntime.lua`
  - `record.goals.currentPlan/currentIntent` 미러링으로 상태 관측성 향상.

## 공식 자료 근거
- Project Zomboid official modding docs
  - `ILuaGameCharacter.Dressup(SurvivorDesc)`
    - https://projectzomboid.com/modding/zombie/characters/ILuaGameCharacter.html
  - `ModelManager.Add`, `ContainsChar`, `Reset`, `ResetNextFrame`
    - https://projectzomboid.com/modding/zombie/core/skinnedmodel/ModelManager.html
  - `IsoPlayer` API surface
    - https://projectzomboid.com/modding/zombie/characters/IsoPlayer.html
- Project Zomboid official blog / update note
  - Build 42 unstable branch announcement
    - https://projectzomboid.com/blog/news/2024/02/unstable-branch-for-build-42/

## 다음 수동 검증 포인트
1. 새 또는 초기화된 세이브에서 F4로 debug NPC를 1명 생성한다.
2. `console.txt`에서 `actor state` 바로 아래 `actor visuals`를 확인한다.
3. `itemVisuals`, `wornItems`, `skin`, `hair`, `beard`, `persistentOutfitId` 값이 비정상적으로 비어 있는지 본다.
4. F5로 nearest NPC summary를 덤프해 `state`, `goal`, `intent`를 확인한다.
5. 여전히 투명하면 same-frame 이후 로그에 `ModelManager refresh`와 `actor visuals` 변화가 있는지 비교한다.

## Stage 3 최소 패치 메모
- 이번 턴은 세 후보 중 `worn items -> item visuals/body visual graph 갱신 문제`만 겨냥했다.
- 겨냥 stage:
  - `createActor.world_registered` 이후
  - `refreshEmbodiedPresentation.ready` 이전
  - 새 trace stage: `refreshEmbodiedPresentation.item_visual_bridge`
- 의도:
  - `wornItems > 0`인데 `itemVisuals == 0`인 경우에만, worn clothing에서 item visual을 한 번 보수적으로 다시 구성한다.
  - 이미 `itemVisuals`가 있으면 건드리지 않는다.
  - 즉, 기존 descriptor/model refresh 경로를 뒤엎지 않고 "body/item visual graph가 비어 있는가"만 분리 관측한다.
- 이번 패치의 핵심 판정 필드:
  - `mode=rebuilt_from_worn_items`
  - `wornItems=...`
  - `itemVisualsBefore=0`
  - `itemVisualsAfter>0`
  - `added=...`
- 성공으로 단정하지 않는다. 이 stage 이후에도 여전히 안 보이면 다음 유력 후보는 descriptor -> human visual 직접 반영 쪽이다.

## 2026-03-12 최소 패치 메모
- 이번 턴은 가설을 다시 좁혀 `descriptor / SurvivorDesc -> renderable body graph / sprite parts / human visual final state 반영 실패`만 겨냥했다.
- 관찰 근거:
  - 최근 로그에서 `world=true`, `ghost=false`, `invisible=false`, `sceneCulled=false`, `alpha=1.00`이 이미 확인됐다.
  - 같은 구간에서 `humanVisual=true`, `actorDescriptor=true`, `itemVisuals>0`, `wornItems>0`도 확인돼, 이번 턴은 world registration / visibility flag / itemVisuals 부족 가설을 우선순위에서 내렸다.
- 코드 변경 의도:
  - `ActorFactory.refreshEmbodiedPresentation()`에서 descriptor 바인딩과 post-clothing materialization을 분리해 추적한다.
  - `Dressup(desc)`는 pre-clothing 1회만 유지하고, clothing/loadout 이후에는 `InitSpriteParts(desc)` + `onWornItemsChanged()` + `resetModel*()` 중심으로 final state를 다시 굳힌다.
  - `ActorSync`는 생성 직후 visual state를 매 tick 덮어쓰지 않도록, `LWN_PresentationPending` 플래그가 있을 때만 1회 settle을 수행한다.
- 새/중요 stage:
  - `refreshEmbodiedPresentation.descriptor_bound`
  - `refreshEmbodiedPresentation.materialized`
  - `applyLoadout.materialized`
  - `settleEmbodiedPresentation.ready`
  - `pushRecordToActor.presentation_settled`
  - `ensureEmbodiedActorState.presentation_settled`
- 이번 턴 판정에 특히 볼 필드:
  - `detail=phase=... descriptorApplied=... dressup=... initSpriteParts=... female=...`
  - 기존 `humanVisual`, `actorDescriptor`, `skin`, `hair`, `beard`, `itemVisuals`, `wornItems`
- 여전히 해결로 단정하지 않는다.
  - 위 stage들에서 descriptor/materialization은 정상인데 인게임에서 계속 투명하면, 다음 턴에는 body graph 이후의 render registration 또는 same-frame invalidation 쪽으로 더 좁혀야 한다.

## 추가 작업 메모: 레퍼런스 재학습
- 이번 턴은 런타임 코드 수정 대신 `reference_mods` 재검토를 우선했다.
- 새로 추가된 `reference_mods/3001908830/mods/PZNS_Framework`를 포함해 Bandits, BanditsWeekOne, BanditsCreator, PZNS를 다시 읽었다.
- 별도 분석 문서:
  - `docs/REFERENCE_STUDY_2026-03-11.md`
- 현재 중간 결론:
  - Bandits는 world entity + visual rebuild에 강한 근거를 준다.
  - BanditsCreator는 preview actor 예시라서 world embodiment 근거로 오용하면 위험하다.
  - PZNS는 manager/context menu/template 구조는 참고 가치가 높지만 Build 41 save/load, ghost-mode unload, OnRenderTick AI는 Build 42 LWN에 그대로 가져오면 위험하다.

## 작업 플로우 고정 메모
- WSL에서는 PowerShell 검증보다 `./scripts/validate-wsl.sh`를 기본 검증 경로로 사용한다.
- 메인 저장소에서는 `reference_mods/` 원본 스냅샷을 추적하지 않고, 분석 문서만 유지한다.
- 의미 있는 코딩 턴이 끝날 때마다 `validate-wsl` 실행 → `git status` 확인 → 작은 스냅샷 커밋 생성을 기본 운영 규칙으로 사용한다.
- 여러 가설 실험은 한 커밋에 섞지 않고, 롤백 가능한 작은 단위로 남긴다.
- 인게임 테스트 이후에는 결과/로그/교훈/후속 수정/다음 검증 포인트를 `docs/TEST_LOG_HISTORY.md`에 시계열로 누적 기록한다.
- 아직 남은 핵심 작업:
  - 인게임 재테스트 + `EmbodimentTrace` 로그 수집
  - Stage 3 최소 패치의 가설 판정
  - 그 결과에 따라 다음 최소 패치 방향 결정
- 환경 업데이트:
  - WSL에 `lua`/`luac`가 설치되어, 이제 `./scripts/validate-wsl.sh`에서 변경된 Lua 파일 문법 검사가 가능하다.

## 2026-03-12 alive vs death/downed presentation 추적 메모
- 이번 턴은 가설을 더 좁혀, "살아 있는 embodied actor의 visible presentation path는 어긋나 있고, death/downed/cleanup/repair 전환에서만 다른 representation이 드러난다"는 가능성만 겨냥했다.
- 관찰 근거:
  - 이미 `world=true`, `ghost=false`, `invisible=false`, `sceneCulled=false`, `alpha=1.00`, `humanVisual=true`, `actorDescriptor=true`, `itemVisuals>0`, `wornItems>0`가 확인됐다.
  - 사용자 관찰상 살아 있을 때는 안 보이지만, 공격받아 피를 흘린 뒤 죽거나 누운 시점에는 "누워 있는 좀비 같은 것"이 보였다.
- 이번 최소 패치 의도:
  - 같은 `npcId` 기준으로 alive -> downed/death-like -> cleanup/despawn -> repair 전후를 한 줄 흐름으로 비교하기 쉽게 만든다.
  - `health<=0` 또는 death-like actor를 `resolveEmbodiedActor()`가 다시 월드에 붙잡아 repair하는 경우만 최소 차단해, 죽은 표현체가 살아 있는 actor presentation 분석을 더 흐리지 않게 한다.
  - despawn/cleanup 직전과 직후도 같은 필드셋으로 남겨, "alive actor가 너무 빨리 꺼진 뒤 다른 object만 남는지"를 판별하기 쉽게 한다.
- 이번 턴에 추가한 핵심 trace/stage:
  - 공통 필드 확장:
    - `object`
    - `npc`
    - `health`
    - `zombie`
    - `reanimated`
    - `dead`
    - `downed`
    - `deathLike`
  - 새 stage:
    - `pushRecordToActor.presentation_changed`
    - `ensureEmbodiedActorState.presentation_changed`
    - `pullActorToRecord.presentation_changed`
    - `tickEmbodiedRecord.start`
    - `tickEmbodiedRecord.pre_despawn`
    - `cleanupActor.complete`
    - `resolveEmbodiedActor.repair_blocked_death_like`
- 이번 턴에서 특히 판정할 로그 패턴:
  - 같은 `npcId`로 `pullActorToRecord.presentation_changed`가 `downed=true` 또는 `deathLike=true`로 바뀌는지
  - 그 직후 `cleanupActor.start/complete`가 같은 actor 상태를 닫는지
  - `resolveEmbodiedActor.repair_blocked_death_like`가 찍히면, 이전에는 죽은/죽음 유사 actor를 repair 대상으로 다시 붙잡고 있었을 가능성이 있다
  - 반대로 위 전환 로그가 없는데 화면에는 누운 개체가 보이면, 그 개체는 기존 embodied actor가 아니라 다른 visible object일 가능성이 올라간다
- 이번 패치는 해결 선언이 아니라 판정력 강화다.

## 2026-03-12 alpha zero / corpse-reanimation object identity 메모
- 이번 턴은 두 축만 유지했다.
  - 1순위: 살아 있는 embodied actor가 `world=true`, `ghost=false`, `invisible=false`, `sceneCulled=false`, `humanVisual=true`, `actorDescriptor=true`인데도 `alpha=0.00`, `targetAlpha=0.00`로 남는 경로 추적
  - 2순위: 죽은 뒤 화면에 보이는 누운 인물 / 기상한 좀비 / 뒤늦은 corpse가 기존 embodied actor와 같은 객체인지 별도 객체인지 판별
- 이번 코드 변경의 의도:
  - 기존 `EmbodimentTrace` 한 줄 요약에 `objectRef`, `alpha`, `targetAlpha`, `alphaZero`, `targetAlphaZero`를 추가해 같은 `npcId` 안에서 객체 identity와 alpha 상태를 바로 비교한다.
  - 새 `PresentationWatch` 로그로 `object`, `objectRef`, `npc`, `world`, `health`, `dead`, `downed`, `deathLike`, `ghost`, `invisible`, `sceneCulled`, `alpha`, `targetAlpha`, `humanVisual`, `actorDescriptor`의 변화만 따로 뽑아낸다.
  - visible actor인데 alpha만 0으로 남는 경우에만 `setAlphaAndTarget(1.0)` + `setAlphaToTarget(0)`를 보수적으로 재시도한다.
  - 저장소 로컬 검색 기준으로는 아직 `setAlpha(0)`, `setTargetAlpha(0)`, `setAlphaAndTarget(0)` 같은 명시적 강제 0 호출은 보이지 않았고, 대신 LWN이 실제로 호출한 alpha 관련 메서드/이유를 `[LWN][AlphaTrace]`로 남겨 내부 엔진 경로와 구분한다.
  - death 쪽은 확실한 이벤트 이름을 추측하지 않고, `OnTick`에서 death-like/downed actor 주변 square를 probe해 corpse/zombie/player 계열 object를 `objectRef` 기준으로 비교한다.
- 이번 턴에 추가된 핵심 로그:
  - `[LWN][PresentationWatch] ... detail=alpha:...->...`
  - `[LWN][PresentationWatch] ... alphaWatch=true ...`
  - `[LWN][AlphaTrace] stage=request ... method=setAlphaAndTarget|setAlphaToTarget ... reason=...`
  - `[LWN][AlphaTrace] stage=alive_zero_observed ... verdict=no_lwn_alpha_request_recorded|last_lwn_alpha_value_request_was_nonzero|...`
  - `[LWN][PresentationWatch] action=alpha_repair ...`
  - `stage=deathState.changed`
  - `stage=deathProbe.objects_changed`
  - `[LWN][DeathTrace] ... relatedKind=corpse|zombie|player ... sameActorRef=... sameNpcId=... relatedRef=...`
- 다음 테스트에서 특히 볼 블록:
  - 같은 `npcId`에서 `module=ActorFactory/EventAdapter/ActorSync`의 `objectRef=...`, `alpha=...`, `targetAlpha=...`
  - 직후 이어지는 `[LWN][PresentationWatch]`의 `detail=...` 또는 `alphaWatch=true`
  - `[LWN][AlphaTrace] stage=alive_zero_observed`의 `lastMethod=`, `lastReason=`, `lastZeroMethod=`, `verdict=`
  - `action=alpha_repair`가 찍히면 before/after alpha 값이 실제로 회복되는지
  - 죽는 순간 `stage=deathState.changed` 다음 `[LWN][DeathTrace] relatedKind=...`가 어떤 `relatedRef`를 남기는지
- 객체 판정 기준:
  - `sameActorRef=true`면 화면의 개체가 기존 embodied actor와 같은 Lua/Java object다.
  - `sameActorRef=false`인데 `relatedKind=corpse` 또는 `relatedKind=zombie`가 뜨면 별도 corpse/reanimated object다.
  - `sameNpcId=true`면 새 object에도 `ModData.LWN_NpcId`가 남았다는 뜻이고, `sameNpcId=false`면 단순 근접 object일 가능성이 높다.

## 2026-03-12 delete/remove/despawn lifecycle 메모
- 이번 턴은 delete/remove를 canonical cleanup으로 다시 묶고, despawn은 "record 유지 + runtime만 해제"로 분리했다.
- canonical cleanup contract:
  - `delete/remove`는 같은 `npcId`에 대해 `record`를 먼저 비활성화하고, embodied actor와 registration/cache(`EmbodimentManager._actors`, `root.embodied`)를 끊고, UI target을 닫고, 주변 corpse/zombie/player leftover를 best-effort로 제거한 뒤 `Store.removeNPC()`까지 끝내야 한다.
  - `despawn/hide`는 canonical record를 지우지 않되, embodied actor/UI target/registration-cache는 같은 순서로 정리하고 `record.embodiment.state=hidden`만 남긴다.
  - context menu 후보 판정은 "world object에 `npcId`가 남았는가"가 아니라 "canonical record가 아직 `embodied`이고 cleanup blocklist에도 없는가"를 기준으로 한다.
- 이번 패치에서 추가/강화한 판정 로그:
  - `[LWN][CleanupTrace] stage=request|record.deactivated|actor.cleanup.*|leftover.*|registry.cleared|record.removed`
  - `[LWN][ContextTrace] stage=debug.delete.request`
  - `[LWN][ContextTrace] stage=worldObject.inspect`
  - `[LWN][ContextTrace] stage=candidate.accepted|candidate.rejected`
  - `[LWN][ContextTrace] ... marker=active|stale ... registeredRef=... registeredMatch=...`
  - `stage=registerActor.bound`
  - `stage=unregisterActor.start`
  - `stage=unregisterActor.complete`
  - `stage=onCreateSurvivor.cleanup_rejected`
- 다음 테스트에서는 같은 `npcId`로 아래 순서를 본다:
  - `ContextTrace stage=debug.delete.request`
  - `CleanupTrace stage=request`
  - `CleanupTrace stage=record.deactivated`
  - `cleanupActor.start`
  - `cleanupActor.complete`
  - `unregisterActor.start`
  - `unregisterActor.complete`
  - `CleanupTrace stage=record.removed`
  - 삭제 후 다시 우클릭했을 때 `ContextTrace stage=candidate.rejected | reason=cleanup_blocked` 또는 `reason=record_not_embodied`
  - stale leftover가 다시 걸리면 `reason=stale_cleanup_marker`, `reason=record_not_registered`, `reason=stale_registered_actor`, `reason=leftover_death_object`, `reason=death_like_actor` 중 어디서 끊기는지 본다
- 삭제 후에도 corpse / zombie가 남아 있으면:
  - `CleanupTrace stage=leftover.cleanup.start|complete`가 같은 `npcId`로 찍히는지 본다.
  - `ContextTrace`는 메뉴 타깃에서 제외되는지 확인한다.
  - 같은 시점의 `[LWN][DeathTrace]`로 `relatedKind`, `relatedRef`, `sameActorRef`, `sameNpcId`를 본다.

## 2026-03-12 구조 재검토 실험 분리 메모
- 이번 턴은 세 실험을 하나의 "구조 재검토"로 묶되, 판정 기준은 서로 섞지 않도록 나눴다.
- 실험별 상세 정리 문서:
  - `docs/STRUCTURE_REVIEW_EXPERIMENTS_2026-03-12.md`
- 실험 1:
  - `OnCreateLivingCharacter`를 기존 `OnCreateSurvivor`와 병행 바인딩해, `IsoPlayer` 생성 후 어느 훅이 실제 post-create anchor인지 비교 가능한 trace를 추가했다.
  - 핵심 stage:
    - `onCreateLivingCharacter.observed`
    - `onCreateLivingCharacter.world_ready`
    - `onCreateLivingCharacter.presentation_refreshed`
    - `onCreateLivingCharacter.synced`
    - `onCreateLivingCharacter.registered`
    - `onCreateLivingCharacter.applied`
    - `onCreateLivingCharacter.compare_only`
    - 동일 패턴의 `onCreateSurvivor.*`
  - 같은 stage의 `detail=`에는 이제 `observedOrder=`, `expected=`, `previousHook=`, `appliedBy=`, `registeredRef=`, `registeredMatch=`, `presentationPending=`, `settledBy=`, `alpha=`, `targetAlpha=`가 함께 남는다.
- 실험 2:
  - death-like actor가 cleanup 전에 embodied로 남아 있는지 `CleanupTrace stage=death_like.embodied_observed`로 확인 가능하게 했다.
  - canonical cleanup 직전 leftover representation 전체를 `CleanupTrace stage=leftover.snapshot`으로 묶어, `player/corpse/zombie` 동시 잔류를 한 블록에서 비교 가능하게 했다.
- 실험 3:
  - 이번 턴에는 actor class 교체 없이 `IsoPlayer`에 대한 현재 기대치, 공식 문서와의 충돌/회색지대, 대안 actor path(`IsoSurvivor`, zombie-based spike)를 비교 메모로 정리했다.
- 아직 해결 선언은 하지 않는다.
  - 다음 인게임 테스트에서 우선 볼 것은 생성 훅 차이와 death-like leftover snapshot이다.

## 2026-03-12 Build 42 presentation API 재검토 메모
- 공식 Build 42 문서 대조 기준:
  - `IsoObject` 문서에는 `getAlpha(int)`, `getTargetAlpha(int)`, `setAlphaAndTarget(float)`, `setAlphaToTarget(int)` 같은 alpha 계열 API가 object 공통 표현층으로 노출된다.
  - `IsoGameCharacter` 문서에는 `setSceneCulled(boolean)`, `isSceneCulled()`, `onCullStateChanged(boolean)`가 보이며, `onCullStateChanged` 설명은 `ModelManager.Add/Remove` 쪽 cull callback 의미에 가깝다.
  - `IsoDeadBody` 문서에는 corpse 쪽 visual 접근점이 `getHumanVisual()`보다 `getVisual()`에 가깝게 드러난다.
- 현재 LWN 사용 패턴과의 충돌/주의점:
  - 살아 있는 embodied actor 복구용으로 `setSceneCulled(false)`를 여러 lifecycle 지점에서 반복 호출하는 패턴은, 문서 의미상 "현재 씬 cull 상태"를 강제로 되돌리는 용도와 완전히 일치한다고 보기 어렵다.
  - corpse/dead-body는 alpha 계열은 비교 가능하지만, character 전용 `ghost/invisible/sceneCulled` 복구와 동일한 층으로 취급하면 해석이 흔들린다.

## 2026-03-13 최신 테스트 로그 분석 메모
- 분석 대상:
  - 최신 `console.txt` 수정 시각 `2026-03-13 09:14:11 +0900`
  - 이번 보존 구간은 생성 직후가 아니라 이미 embodied 된 `LWN-000037`의 runtime 중간부터 시작한다.
- 예외/에러:
  - 이번 최신 로그에서는 `ERROR`, `Exception`, Lua stack trace가 보이지 않았다.
  - 즉, 이번 테스트의 남은 문제는 crash보다 presentation/logic 쪽이다.
- 이번 테스트에서 개선된 점:
  - stale target 관련해서는 cleanup 후 `ui_targets.cleared`, `registry.cleared`, `candidate.rejected | reason=leftover_death_object`가 남아, leftover zombie가 다시 NPC 후보로 붙지 않았다.
  - delete crash는 직접 delete 요청 로그가 없어서 완전 판정은 불가하지만, 같은 cleanup contract를 쓰는 death cleanup은 예외 없이 끝났다.
  - corpse flicker는 이번 로그 기준으로는 크게 줄었다. corpse/player/zombie가 여러 objectRef 사이에서 출렁이는 패턴이 아니라, death-like player와 separate zombie의 짧은 동시 존재만 남았다.
- 여전히 남은 핵심 문제:
  - 1순위는 여전히 "alive embodied NPC가 논리적으로는 정상인데 실제로는 안 보인다"이다.
  - 근거:
    - alive 구간 내내 `world=true`
    - `ghost=false`, `invisible=false`, `sceneCulled=false`
    - `alpha=1.00`, `targetAlpha=1.00`
    - `humanVisual=true`, `actorDescriptor=true`, `itemVisuals=5`, `wornItems=3`
    - `PresentationGuard`는 계속 `status=already_set`
  - 따라서 alpha/culling/simple-flag 문제는 우선순위가 더 내려갔고, render registration 또는 Build 42에서의 `IsoPlayer` alive presentation path 자체가 더 유력하다.
- death/corpse/cleanup 해석:
  - death 전환은 같은 `IsoPlayer{ ID:93 }`에 대해 `health=0.00`, `deathLike=true`로 감지됐다.
  - 같은 순간 `DeathTrace`는 별도 `IsoZombie{ ID:38 }`를 같은 square에서 잡았고 `sameActorRef=false`, `sameNpcId=false`였다.
  - cleanup 전까지 `corpseSeen=false`가 유지돼 corpse 기반 정리로 넘어가지 못했고, 약 0.58초 뒤 `death_timeout_cleanup`로 원래 actor를 정리했다.
  - 즉, death overlap은 "이전보다 훨씬 덜 어지럽지만 완전히 사라진 것은 아니고, separate zombie spawn + original actor delayed cleanup" 형태로 아직 남아 있다.
- 이번 로그가 시사하는 추가 개선사항 3개:
  - alive actor의 실제 render/model registration 상태를 직접 추적한다.
    - 예: `ModelManager` 등록 여부, same-frame remove/add, visible actor와의 차이 비교
  - death 시 separate zombie가 확인되고 `corpseSeen=false`가 계속되면, 원래 death-like actor cleanup을 더 앞당기는 조건을 검토한다.
  - 다음 테스트에서는 생성 직후 `ActorFactory`/`OnCreate*` 블록이 잘리지 않도록 콘솔 보존 범위나 테스트 시작 직후 로그 확보 절차를 보강한다.

## 2026-03-13 전면 구조 재정렬 메모
- 이번 턴의 결론은 "방향 폐기"가 아니라 "계약 재정의 후 계속 진행 가능" 쪽이다.
- 다만 유지 조건은 더 엄격해졌다.
  - `ModData`가 유일한 canonical state
  - `IsoPlayer`는 embodied carrier에 불과함
  - presentation/death/cleanup/target은 모두 canonical state에 stage를 남겨야 함
- 실제 코드 변경의 핵심:
  - `Schema`와 `PopulationStore`에 `status`, `embodiment.stage`, `presentation`, `death`, `cleanup`, `target` 메타 추가
  - `ActorFactory`에서 spawn/presentation stage 기록, 공식 `WornItems -> ItemVisuals` 브리지 우선 사용, world registration 최소 경로 우선 시도
  - `EmbodimentManager`에서 death latch, corpse 관찰, cleanup ownership, preserved corpse/zombie leftover 처리 추가
  - `EventAdapter`에서 death-like actor를 일반 embodied tick와 분리하고 `OnDeadBodySpawn` 관찰 연결
  - UI target을 actor ref가 아니라 `npcId` 기반 재해석으로 전환
  - `ActionRuntime`에서 melee target을 raw ref 고정 대신 좌표 기반 재해석 가능 형태로 보강
- 이번 턴의 제한도 명확히 남긴다.
  - Build 42에서 human death/corpse/reanimation을 LWN이 완전한 first-class simulation으로 소유한다고 주장하지 않는다.
  - 현재 더 안전한 정의는 "canonical death state + corpse observation + ownership release"다.
- 다음 판단은 문서가 아니라 인게임 결과로 내린다.
  - 필수 체크리스트: `docs/INGAME_TEST_CHECKLIST_2026-03-13.md`
  - 구조 판단 문서: `docs/ARCHITECTURE_VERDICT_2026-03-13.md`
  - 그래서 이번 턴 수정은 `setSceneCulled(false)`를 제거하는 것이 아니라, `world=true` + `squarePresent=true` + `deathLike=false`인 live actor에만 제한하고 corpse/reanimated는 별도 presentation block으로 추적하는 쪽으로 좁힌다.
