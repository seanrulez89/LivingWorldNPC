# LWN Build 42 Decision Matrix 2026-03-12

Project: LivingWorldNPC  
Purpose: 장문의 Build 42 학습 문서를 다시 읽지 않고도, LWN에서 무엇을 믿고 무엇을 의심하고 무엇을 실험해야 하는지 빠르게 결정하기 위한 압축판.  
Scope: 이번 문서는 런타임 구현 지침이 아니라 의사결정용 요약이다. 코드 수정 지시가 아니라, 다음 패치 전에 판단 우선순위를 맞추는 데 목적이 있다.

## 1. 빠른 사용 규칙

판단 우선순위:

1. 공식 JavaDocs와 공식 블로그/포럼에 직접 보이는 것부터 믿는다.
2. PZwiki 이벤트/포맷 문서는 Lua 훅과 실무 진입점으로 강하게 참고하되, 메서드 존재성의 최종 근거로 쓰지 않는다.
3. Build 41 레퍼런스 모드는 "돌아가던 패턴"을 보여주는 참고 사례일 뿐, Build 42 정답으로 승격하지 않는다.

행동 라벨:

- `유지`: 현재 방향을 유지해도 됨
- `재검토`: 방향 자체는 버리지 않되, 설계 가정을 다시 확인해야 함
- `실험`: 짧은 검증 루프로 사실 여부를 먼저 확인해야 함
- `중단`: Build 42에서 기본 경로로 채택하면 위험함

충돌 라벨:

- `없음`: 현재 LWN 가정과 대체로 정렬
- `부분`: 방향은 맞지만 구현/훅/세부 수단이 어긋남
- `있음`: 현재 핵심 가정 또는 구현이 공식 문서와 명확히 어긋남

Build 41 판정:

- `참고 가능`: 개념이나 패턴만 차용 가능
- `조건부 참고`: 제한된 범위에서만 참고 가능
- `직접 사용 위험`: Build 42 기본 경로로 쓰기 위험

## 2. 주제별 의사결정 표

| 주제 | 지금 믿을 것 | 지금 의심할 것 | 공식 근거 강도 | 현재 LWN과의 충돌 여부 | 권장 행동 | B41 취급 | 참고 출처 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Actor class 선택 | `IsoPlayer`, `IsoSurvivor`, `SurvivorFactory` 같은 인간형 클래스 표면은 Build 42 공식 JavaDocs에 존재한다 | Build 42가 인간형 NPC를 정식 안정 runtime으로 지원한다고 보는 해석 | 높음 | 부분 | 재검토 | 조건부 참고 | Official: `IsoPlayer`, `IsoSurvivor`, `SurvivorFactory`, Build 42 unstable 공지, Build 43 NPC 방향 블로그; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12` |
| 생성 후 라이프사이클 hook | 인간형 생성 후처리 기준 훅으로는 `OnCreateLivingCharacter`가 더 자연스럽다 | `IsoPlayer` 경로를 쓰면서 `OnCreateSurvivor`만 기대하는 패턴 | 중간 | 있음 | 재검토 | 참고 가능 | Official-adjacent: `OnCreateLivingCharacter`, `OnCreateSurvivor`; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12` |
| Death / reanimation / corpse | 죽음은 `setHealth <= 0`만이 아니라 `die`, `Kill`, `becomeCorpse`, `IsoDeadBody`, `OnDeadBodySpawn`까지 포함한 별도 흐름이다 | health 플래그만으로 corpse, loot, reanimation, visual persistence까지 대체할 수 있다는 가정 | 높음 | 있음 | 재검토 | 직접 사용 위험 | Official: `IsoGameCharacter`, `IsoDeadBody`; Official-adjacent: `OnZombieDead`, `OnDeadBodySpawn`; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12`, `BUILD42_MODDING_KNOWLEDGE_MAP_2026-03-12` |
| Visual / clothing / worn items | `SurvivorDesc`는 seed에 가깝고, 실제 표현은 `HumanVisual`, `WornItems`, `ItemVisuals`, `onWornItemsChanged`, `resetModel*` 축으로 이해하는 편이 안전하다 | descriptor만 주면 최종 모델이 자동으로 안전하게 완성된다는 가정, `WornItems -> ItemVisuals` 수동 브리지 | 높음 | 있음 | 실험 | 조건부 참고 | Official: `HumanVisual`, `ItemVisual`, `WornItems`, `ModelManager`, `IsoGameCharacter`; Official-adjacent: `OnClothingUpdated`; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12`, `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS` |
| Context menu targeting | 상호작용은 world actor를 먼저 찾고 canonical record로 연결하는 구조가 안전하다 | 클릭한 한 칸만 보고 actor 존재 여부를 판단하는 좁은 탐색 | 낮음 | 부분 | 실험 | 참고 가능 | Build 41 refs: Superb Survivors, PZNS, Bandits; Local: `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS` |
| Cleanup / remove / world registration | `addToWorld`, `removeFromWorld`, `removeFromSquare`, `isExistInTheWorld` 같은 문서화된 lifecycle API를 중심으로 보는 것이 안전하다 | `setCurrentSquare`, `setSquare`, `setMovingSquare`, `square:AddMovingObject(...)` 등 포인터를 과하게 수동 조작하는 방식 | 높음 | 있음 | 재검토 | 직접 사용 위험 | Official: `IsoObject`, `IsoMovingObject`; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12` |
| ModelManager의 역할 | `ModelManager`는 presentation/cache 계층으로 이해하는 편이 안전하다 | `ModelManager`를 canonical lifecycle 제어 수단처럼 기대하는 해석 | 중간 | 부분 | 재검토 | 조건부 참고 | Official: `ModelManager`, `IsoGameCharacter.onCullStateChanged`; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12` |
| ModData / persistence | canonical NPC state를 `ModData`에 두고 embodied actor를 cache로 두는 방향은 Build 42 저장 계층과 대체로 맞는다 | ModData만으로 corpse, world 흔적, 외형 영속성까지 모두 해결된다고 보는 해석 | 중간 | 없음 | 유지 | 참고 가능 | Official: `zombie.world.moddata`, `zombie.savefile`, `zombie.globalObjects`; Local: `BUILD42_MODDING_KNOWLEDGE_MAP_2026-03-12` |
| 미문서/추정성 메서드 | 공식 JavaDocs에 직접 보이는 메서드와 클래스 시그니처 | `setFemaleEtc`, `getSkinTextureName`처럼 문서 근거가 약한 추정성 호출 | 높음 | 있음 | 중단 | 직접 사용 위험 | Official: `HumanVisual` JavaDocs; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12` |
| Zombie object identity 해석 | Build 42 위키는 zombie object pooling과 인스턴스 재사용 가능성을 경고한다 | "Lua 참조 하나 = 영속 개체 하나"라는 정체성 가정 | 중간 | 부분 | 재검토 | 직접 사용 위험 | Official-adjacent: `IsoZombie`, `OnZombieCreate`; Local: `OFFICIAL_BUILD42_API_AUDIT_2026-03-12`, `BUILD42_MODDING_KNOWLEDGE_MAP_2026-03-12` |

## 3. Build 41 방식 판정표

| Build 41 패턴 | Build 42에서의 판정 | 이유 | 권장 행동 | 참고 출처 |
| --- | --- | --- | --- | --- |
| spawn 뒤 visual rebuild를 별도 단계로 두기 | 참고 가능 | 여러 B41 인간형 NPC 모드가 공통으로 채택했고, Build 42 공식 비주얼 API 축과도 충돌하지 않는다 | 실험 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS`, `OFFICIAL_BUILD42_API_AUDIT_2026-03-12` |
| world actor를 찾은 뒤 canonical record를 조회하는 context menu 구조 | 참고 가능 | 현재 LWN의 canonical-state 설계와 잘 맞는다 | 유지 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS` |
| `SurvivorDesc`를 seed로 쓰고 이후 외형/착장을 재적용 | 조건부 참고 | 개념은 유효하지만, Build 42에서는 공식 `WornItems`/`HumanVisual` 경로로 다시 매핑해야 한다 | 실험 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS`, `OFFICIAL_BUILD42_API_AUDIT_2026-03-12` |
| save/load 기반 actor 재실체화 | 직접 사용 위험 | B41 workaround 성격이 강하고, Build 42 기본 경로로 신뢰할 근거가 약하다 | 중단 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS`, Build 42 unstable 공지 |
| `OnRenderTick` 기반 광범위 NPC 갱신 | 직접 사용 위험 | B41 debt 성격이 강하고 현재 LWN 우선 과제와 맞지 않는다 | 중단 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS` |
| `ghost` / `invisible` / preview actor 플래그를 world actor 흐름에 섞기 | 직접 사용 위험 | preview와 world embodiment를 섞으면 투명/비상호작용 증상을 악화시킬 수 있다 | 중단 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS` |
| aggressive remove / nil actor / dummy-job 우회 | 직접 사용 위험 | offscreen 최적화보다 actor 안정성 확보가 우선이며, Build 42 정답으로 보기 어렵다 | 중단 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS` |
| square 주변 확장 탐색으로 actor 찾기 | 참고 가능 | 상호작용 실패를 비가시성과 분리해 진단할 수 있다 | 실험 | `REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS` |

## 4. 지금 LWN에서 가장 먼저 믿어야 하는 것

- canonical NPC state를 `ModData`에 두고 embodied actor를 cache로 두는 큰 방향
- Build 42 공식 JavaDocs에 직접 보이는 lifecycle, visual, corpse API 축
- PZwiki의 이벤트 문서를 "Lua 훅 인덱스"로 쓰는 방식
- Build 41 레퍼런스에서 `post-spawn visual rebuild`와 `actor -> record lookup`만 선별 차용하는 전략

## 5. 지금 LWN에서 가장 먼저 의심해야 하는 것

- Build 42를 사실상 공식 human NPC runtime처럼 전제하는 해석
- `IsoPlayer` actor 후처리를 `OnCreateSurvivor`만으로 충분하다고 보는 가정
- `setHealth`와 내부 상태만으로 death/corpse/reanimation을 커버할 수 있다는 가정
- `WornItems -> ItemVisuals`를 수동 브리지하는 복구 로직
- world registration을 위해 square/current 포인터를 수동으로 밀어 넣는 방식
- JavaDocs에서 직접 확인되지 않는 메서드 호출

## 6. 현재 가장 우선순위 높은 구조 질문

1. embodied human actor의 공식적 기준점은 당분간 `IsoPlayer`를 유지하되 후처리를 보강하는 것인가, 아니면 `IsoSurvivor`/`SurvivorFactory` 경로를 다시 평가해야 하는가?
2. 생성 후처리와 외형 복구의 anchor hook는 `OnCreateLivingCharacter`로 옮겨야 하는가?
3. LWN의 "death"는 record 상태 전환만 다루는가, 아니면 `IsoDeadBody`까지 포함한 world 흔적 모델로 확장할 것인가?
4. visual rebuild는 `SurvivorDesc` seed 이후 공식 `WornItems`/`HumanVisual`/`resetModel*` 경로로 재정의해야 하는가?
5. world registration/cleanup은 문서화된 lifecycle API만으로 축소 가능한가?

## 7. 바로 다음 실험 후보

| 우선순위 | 실험 후보 | 검증하려는 가설 | 성공 기준 | 실패 시 의미 |
| --- | --- | --- | --- | --- |
| 1 | `IsoPlayer` spawn 직후 `OnCreateLivingCharacter` 기준 visual rebuild 실험 | 현재 핵심 실패는 world registration보다 visual rebuild 부족이다 | actor 존재 + 외형/착장/모델이 안정적으로 보임 | spawn 이후 표현 계층 외에 registration 또는 actor class 문제가 더 큼 |
| 2 | `WornItems.getItemVisuals()` / `setFromItemVisuals()` 기반 공식 브리지 실험 | 수동 `ItemVisual` 조립보다 공식 변환 경로가 더 안정적이다 | 수동 fallback 없이 의복/외형 반영이 유지됨 | LWN의 외형 데이터 구조가 공식 경로와 어긋나 있을 수 있음 |
| 3 | death 처리에서 `setHealth` 경로와 corpse-aware 설계의 최소 차이 실험 | LWN death는 corpse lifecycle을 무시하면 이후 확장에 막힌다 | 죽음 이후 world 흔적/시체 흐름의 차이가 명확히 관찰됨 | 현재 스코프에서는 corpse를 보류하고 data-only death로 한정 가능 |
| 4 | context menu square 확장 탐색 실험 | 일부 "NPC 없음" 체감은 탐색 폭 부족 때문이다 | 비가시성과 무관하게 탐지율/상호작용률이 올라감 | 문제의 핵심은 탐색이 아니라 embodiment 또는 visual일 가능성 |
| 5 | `IsoSurvivor`/`SurvivorFactory`의 embodied 적합성 소규모 스파이크 | `IsoPlayer`보다 더 자연스러운 lifecycle 경로가 있을 수 있다 | hook/lifecycle/cleanup 면에서 명확한 이점 확인 | 당분간 `IsoPlayer` 유지 + 후처리 보강이 더 현실적 |
| 6 | cleanup을 `addToWorld/removeFromWorld/removeFromSquare` 중심으로 축소하는 실험 | 수동 square/current 포인터 조작은 불필요하거나 과하다 | 수동 포인터 조작 없이도 안정적 등록/해제가 가능 | registration의 실제 누락 지점이 다른 곳에 있음 |

## 8. 최종 압축 결론

- LWN의 큰 방향 전체가 틀린 것은 아니다. 특히 `ModData` canonical state 전략은 Build 42 지형과 잘 맞는다.
- 가장 위험한 부분은 actor class 자체보다도, 그 위에 얹힌 잘못된 hook 선택, death/corpse 생명주기 우회, 수동 visual 브리지, 과한 world registration 조작이다.
- Build 41은 "가능했던 구현"의 참고 자료로는 유효하지만, save/load, ghost, aggressive unload, `OnRenderTick` 루프는 Build 42 기본 해법으로 채택하면 안 된다.
- 다음 판단은 설계 논쟁보다 짧은 실험으로 가르는 편이 좋다. 특히 visual rebuild, 공식 worn-item 브리지, corpse-aware death 흐름이 우선 검증 대상이다.

## 9. 관련 원문 문서

- `docs/OFFICIAL_BUILD42_API_AUDIT_2026-03-12.md`
- `docs/BUILD42_MODDING_KNOWLEDGE_MAP_2026-03-12.md`
- `docs/BUILD42_MODDING_SOURCE_REGISTER_2026-03-12.md`
- `docs/REFERENCE_STUDY_2026-03-12_BUILD41_LESSONS.md`
