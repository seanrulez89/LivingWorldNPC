# Structure Review Experiments 2026-03-12

Purpose: 공식 문서 감사 결과를 바탕으로, 이번 턴의 구조 재검토 작업을 실험 1/2/3으로 분리해 기록한다.  
Rule: 이번 문서는 "해결 보고"가 아니라 "판정 가능한 실험 묶음"이다. 결론은 잠정적이며, 다음 인게임 로그 수집으로 다시 확인해야 한다.

Related inputs:

- `docs/OFFICIAL_BUILD42_API_AUDIT_2026-03-12.md`
- `docs/LWN_BUILD42_DECISION_MATRIX_2026-03-12.md`
- `docs/WORK_NOTES_2026-03-11.md`
- `LWN_SP_TESTING.md`

## 연결 지도

- 실험 1은 "생성 직후 어느 훅에서 post-create presentation을 다시 만질 것인가"를 본다.
- 실험 2는 "death-like actor, corpse, zombie, canonical cleanup을 어떤 계약으로 읽을 것인가"를 본다.
- 실험 3은 "위 두 실험 결과를 바탕으로 `IsoPlayer` 경로를 계속 밀 가치가 있는가"를 본다.
- 따라서 실험 1과 2는 런타임 trace 강화, 실험 3은 구조 판단 자료 정리로 역할이 다르다.

## 실험 1. OnCreateLivingCharacter 기준 생성 후처리 비교

### 목적

- 현재 LWN의 embodied actor 생성은 `IsoPlayer.new(...)` 기준인데, 엔진 훅 재진입은 `OnCreateSurvivor`에만 묶여 있었다.
- 공식 문서 감사 기준에서는 `IsoPlayer`/`IsoSurvivor` 공통 생성 후처리 비교 지점으로 `OnCreateLivingCharacter`가 더 자연스럽다.
- 이번 턴 목표는 기존 `OnCreateSurvivor` 경로를 지우지 않고, 두 훅이 실제로 어떻게 보이는지 비교 가능한 trace를 만드는 것이다.

### 실제 변경

- `42/media/lua/client/23_LWN_ActorFactory.lua`
  - newly created actor의 `ModData`에 `LWN_CreateHookPending`, `LWN_CreateHookExpected`, `LWN_PostCreateApplied*`를 남긴다.
- `42/media/lua/client/90_LWN_EventAdapter.lua`
  - 공용 `handleCreatedCharacter(actor, hookName)`를 추가했다.
  - `Events.OnCreateLivingCharacter`를 지원하는 환경이면 바인딩한다.
  - 기존 `OnCreateSurvivor`도 그대로 유지하고, 두 훅 모두 같은 post-create 경로를 공유하되 첫 적용 이후 나중 훅은 `compare_only` trace만 남긴다.

### 새 판정 로그

- `stage=onCreateLivingCharacter.observed`
- `stage=onCreateLivingCharacter.world_ready`
- `stage=onCreateLivingCharacter.presentation_refreshed`
- `stage=onCreateLivingCharacter.synced`
- `stage=onCreateLivingCharacter.registered`
- `stage=onCreateLivingCharacter.compare_only`
- 같은 패턴의 `onCreateSurvivor.*`

핵심 detail 필드:

- `recordExists=`
- `hookPending=`
- `previousHook=`
- `appliedBy=`
- `expected=OnCreateLivingCharacter`
- `actorKind=Player|Survivor|...`

### 이번 턴 잠정 판정

- `IsoPlayer` 생성 경로를 유지한 상태에서도 `OnCreateLivingCharacter` 기준 비교는 충분히 할 수 있게 됐다.
- 아직 "어느 훅이 실제로 더 맞다"는 결론은 내리지 않는다.
- 다음 테스트에서 봐야 할 것은 "실제로 어떤 훅이 먼저/유일하게 들어오는가"와 "그 훅 직후 alpha/presentation이 달라지는가"다.

### 다음 인게임 테스트에서 볼 블록

같은 `npcId`로 아래 순서를 확인한다.

1. `stage=createActor.actor_allocated`
2. `stage=createActor.world_registered`
3. `stage=onCreateLivingCharacter.observed` 또는 `stage=onCreateSurvivor.observed`
4. `stage=...world_ready`
5. `stage=...presentation_refreshed`
6. `stage=...synced`
7. `stage=...registered` 또는 `stage=...compare_only`
8. 같은 구간의 `[LWN][PresentationWatch]`

판정 기준:

- `OnCreateLivingCharacter`만 찍히면 `IsoPlayer` 경로 post-create anchor 후보가 강해진다.
- `OnCreateSurvivor`만 찍히면 현재 가정과 실제 훅 동작이 다를 수 있으니 계속 비교가 필요하다.
- 둘 다 찍히면, 먼저 적용한 훅과 뒤늦게 `compare_only`로 온 훅을 구분해서 본다.
- 훅은 정상인데 `alpha=0.00`, `targetAlpha=0.00`이 그대로면 생성 훅보다 presentation/actor-class 쪽 이슈가 남아 있다.

## 실험 2. death/corpse/reanimation lifecycle과 canonical cleanup 정렬

### 목적

- death-like actor가 계속 embodied로 남는지 먼저 확인한다.
- `delete/remove`와 `despawn/hide`가 이미 나뉜 canonical cleanup contract와 death-like 관측을 연결한다.
- corpse / zombie / original player actor representation이 동시에 남는 경우를 한 덩어리로 구분 가능하게 만든다.

### 실제 변경

- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
  - `noteDeathLikeActor(record, actor, source)`를 추가해 death-like actor가 아직 canonical cleanup 전에 embodied 상태에 남아 있는 순간을 `CleanupTrace`로 남긴다.
  - `canonicalCleanup()`에서 leftover object 집합 전체를 `leftover.snapshot`으로 먼저 덤프한다.
  - unregister 시 death-like trace cache를 비운다.
- `42/media/lua/client/90_LWN_EventAdapter.lua`
  - 기존 `embodiedActor.death_like` trace가 찍힐 때 `EmbodimentManager.noteDeathLikeActor()`도 함께 호출한다.

### 새 판정 로그

- `[LWN][CleanupTrace] stage=death_like.embodied_observed`
- `[LWN][CleanupTrace] stage=leftover.snapshot`
- 기존 `[LWN][DeathTrace] stage=probe.related_object`
- 기존 `stage=deathProbe.objects_changed`

핵심 detail 필드:

- `cleanupContract=observe_only`
- `state=embodied|hidden|removed`
- `actorKind=player|corpse|zombie|survivor`
- `objects=player[sameActor=...];corpse[sameActor=...];zombie[sameActor=...]`

### 이번 턴 잠정 판정

- 이번 턴은 death-like actor를 즉시 정리하도록 바꾸지 않았다.
- 대신 "death-like 상태가 되었는데도 canonical cleanup이 아직 안 돌았다"는 사실과 "cleanup 시점에 어떤 representation이 같이 남아 있었는지"를 더 직접적으로 볼 수 있게 했다.
- 따라서 다음 테스트에서는 "문제가 아직 있는가"보다 먼저 "어느 경로로 남는가"를 분리 판단할 수 있다.

### 다음 인게임 테스트에서 볼 블록

같은 `npcId`로 아래 순서를 확인한다.

1. `stage=deathState.changed`
2. `stage=embodiedActor.death_like`
3. `[LWN][CleanupTrace] stage=death_like.embodied_observed`
4. `[LWN][DeathTrace] ... relatedKind=corpse|zombie|player`
5. delete/remove면 `[LWN][CleanupTrace] stage=request`
6. `[LWN][CleanupTrace] stage=leftover.snapshot`
7. `[LWN][CleanupTrace] stage=actor.cleanup.complete`
8. `[LWN][CleanupTrace] stage=registry.cleared`

판정 기준:

- `death_like.embodied_observed`가 찍히면 death-like actor가 cleanup 전까지 embodied cache에 남아 있다는 뜻이다.
- `leftover.snapshot`에 `player`, `corpse`, `zombie`가 함께 보이면 representation이 중첩돼 있음을 뜻한다.
- `sameActor=false`가 대부분이면 corpse/zombie는 원래 actor와 다른 object일 가능성이 높다.
- delete 직후 `record.removed`까지 갔는데도 인게임에 무언가 남으면 leftover cleanup 범위나 엔진 lifecycle 지연을 다시 봐야 한다.

## 실험 3. IsoPlayer 유지 vs 대안 actor 경로 비교 자료

### 목적

- 이번 턴에 actor class를 갈아엎지 않고, 현재 `IsoPlayer` 구조가 계속 밀 가치가 있는지 판단 자료를 만든다.
- LWN이 현재 `IsoPlayer`에 무엇을 기대하는지, 무엇이 공식 문서와 맞고 무엇이 회색지대인지 코드 레벨에서 분리한다.
- `IsoSurvivor`, zombie-based spike는 이번 턴에 설계 메모와 비교 포인트까지만 정리한다.

### 이번 턴 정리한 현재 LWN의 `IsoPlayer` 기대치

LWN이 실제로 기대하는 것:

- `getBodyDamage`, `getStats`, `getInventory`를 가진 runtime core
- `getHumanVisual`, `getWornItems`, `getItemVisuals`, `onWornItemsChanged`, `resetModel*`를 통한 presentation rebuild
- `addToWorld` / `removeFromWorld` / `removeFromSquare` / `isExistInTheWorld` 축의 world actor 동작
- `ModData.LWN_NpcId`를 실은 canonical lookup carrier
- collision / context menu / zombie targeting이 되는 player-like living actor

공식 문서와 정렬되는 부분:

- `IsoPlayer.new(...)` 표면 자체
- `HumanVisual` / `WornItems` / `ItemVisuals` / `ModelManager` 축
- world lifecycle API를 중심으로 보는 방향

공식 문서와 충돌하거나 회색지대인 부분:

- Build 42를 사실상 "공식 human NPC runtime"처럼 전제하는 해석
- `IsoPlayer` 경로인데 post-create hook를 `OnCreateSurvivor`에만 기대했던 점
- `setFemaleEtc`, 일부 visual accessor처럼 문서 근거가 약한 추정성 호출
- square/current 포인터를 과하게 직접 만지는 등록 보조
- death를 `health <= 0` 중심으로만 읽으려는 유혹

### 이번 턴 잠정 판정

- `IsoPlayer` 경로 자체를 이번 턴에 폐기할 근거는 아직 없다.
- 다만 "계속 밀 가치"는 actor class 자체보다, 생성 훅과 death lifecycle을 얼마나 문서 축에 맞게 재정렬할 수 있는지에 더 달려 있다.
- 즉 이번 단계의 질문은 "`IsoPlayer`를 버릴까?"보다 "`IsoPlayer` 경로를 더 문서 친화적으로 좁힐 수 있는가?"에 가깝다.

### 대안 actor 경로 메모

- `IsoSurvivor`
  - 장점: 생성 이벤트와 일부 lifecycle 서사가 더 자연스럽다.
  - 리스크: 현재 LWN의 player-like 상호작용, targetability, cache semantics와 얼마나 맞는지 미확인이다.
- zombie-based spike
  - 장점: 엔진의 기존 combat/targeting/visibility lifecycle에 기대기 쉽다.
  - 리스크: 인간형 social/UI/identity 요구와 멀어져 이번 턴 범위를 크게 벗어난다.

이번 턴 판단:

- 두 대안 모두 "대규모 구현"이 아니라 비교 스파이크 후보로만 유지한다.
- 우선순위는 `IsoPlayer` 경로를 즉시 버리는 것이 아니라, 실험 1/2 로그로 계속 밀 가치가 있는지 판단하는 것이다.

## 현재 가장 유력한 다음 단계

- 다음 인게임 테스트에서 `OnCreateLivingCharacter`와 `OnCreateSurvivor` 중 실제로 어느 훅이 post-create anchor로 더 안정적으로 보이는지 먼저 확인한다.
- 그 결과와 함께 `death_like.embodied_observed` + `leftover.snapshot`를 붙여 보면, 다음 턴 우선순위가 "alpha/presentation 정밀화"인지 "death cleanup 진입 시점 조정"인지 더 명확해진다.
