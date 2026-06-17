# Reference Study 2026-03-12: Build 41 Lessons From Working NPC Mods

Project: LivingWorldNPC
Scope: `reference_mods` 재분석
Goal: "Build 41에서 멈췄더라도 당시 실제로 굴러가던 구현들"이 현재 LWN / Build 42에 주는 교훈 정리

## 1. 이번 턴의 비교 범위

이번 턴에서 중점적으로 다시 읽은 레퍼런스는 아래 6개다.

- `reference_mods/1905148104/mods/Superb-Survivors`
- `reference_mods/2980672778/mods/SuperbSurvivorsContinued`
- `reference_mods/3001908830/mods/PZNS_Framework`
- `reference_mods/3268487204/mods/Bandits/42.13`
- `reference_mods/3403180543/mods/BanditsWeekOne/42.13`, `42.15`
- `reference_mods/3469292499/mods/BanditsCreator/42.15`

이번 비교에서 중요한 변화는 다음이다.

- `Superb Survivors` 원본과 `Superb Survivors Continued`가 "B41 인간형 `IsoPlayer` NPC"가 실제로 어떻게 돌아갔는지 보여준다.
- 즉, `IsoPlayer` 경로 자체가 원천적으로 불가능했던 것은 아니다.
- 대신 그 대가로
  - save/load 의존,
  - 수동 외형 갱신,
  - aggressive lifecycle 제어,
  - `OnRenderTick` 기반 갱신
  이 붙었다.
- 따라서 LWN은 "인간형 `IsoPlayer` embodied cache" 방향을 완전히 버릴 필요는 없지만, B41식 우회 구현 전체를 그대로 되살리면 안 된다.

## 2. 한 줄 결론

새 레퍼런스 2개를 반영하고 나면 결론은 더 선명해진다.

- Build 41에서 실제로 잘 굴러간 인간 NPC 계열은 `IsoPlayer`를 만들고 끝내지 않았다.
- 반드시
  - 착장 재적용,
  - `HumanVisual` 직접 수정,
  - `initSpritePartsEmpty()`,
  - `OnClothingUpdated`,
  - `resetModel()`
  같은 후처리를 붙였다.
- 반대로 offscreen unload, save-file reload, `ghost` 우회, `OnRenderTick` 루프는 "돌아가게 만들기 위한 시대적 workaround" 성격이 강했다.
- LWN의 현재 투명 NPC 문제에는 lifecycle보다 먼저 "post-spawn visual rebuild가 충분한가"가 더 직접적인 질문이다.

## 3. 구조 비교

### 3-1. Superb Survivors 원본

원본 `Superb Survivors`는 거대한 단일체에 가깝다.

- `SuperSurvivor.lua`
  - 생성, load, 장비, 전투, 상태, 외형 후처리까지 다 가진다.
- `SuperSurvivorManager.lua`
  - active survivor 배열과 spawn/load/update를 직접 관리한다.
- `SuperSurvivorsMod.lua`
  - `OnRenderTick`, 저장, 랜덤 스폰, 이벤트를 한데 묶는다.
- `SuperSurvivorsContextMenu.lua`
  - 월드 상호작용과 지휘 UI를 담당한다.

장점:

- 동작 경로가 단순하다.
- 월드 actor 중심 사고가 분명하다.

약점:

- 책임 분리가 약하다.
- Build 42로 옮기기엔 결합도가 너무 높다.

### 3-2. Superb Survivors Continued

continued는 구조를 재정리하려는 흔적이 명확하다.

- `03_Core/`
  - `SuperSurvivor.lua`, `SuperSurvivorGroup.lua`
- `04_DataManagement/`
  - manager, update, base management, mod init
- `05_Tasks/`
  - 행동 task
- `06_AI/`
  - companion / non-companion 분리
- `07_Spawning/`
  - 스폰 전용 모듈
- `08_UI/`
  - context menu, panels

핵심은 "원본의 동작 방식은 유지하되, 어떤 부분이 debt인지 코드 주석으로 드러냈다"는 점이다.

### 3-3. PZNS_Framework

PZNS는 Build 41 계열 레퍼런스 중 구조가 제일 명시적이다.

- core
- data manager
- utils
- orders
- AI
- context menu
- UI
- templates

즉, "B41 인간 NPC"를 가장 프레임워크답게 해석한 경우다.

### 3-4. Bandits / WeekOne / Creator

- `Bandits`
  - 안정적인 월드 엔티티 확보를 위해 zombie 기반 runtime을 선택
- `WeekOne`
  - 엔티티 본체 위에 scenario / room / route / event 계층을 올림
- `Creator`
  - world actor가 아니라 preview actor / editor 도구

이 셋은 Build 42 쪽 비교 대조군 역할을 한다.

### 3-5. 구조 관점의 교훈

LWN에 지금 필요한 구조적 결론은 아래다.

- canonical state와 embodied actor를 분리하는 현재 방향은 맞다.
- 다만 embodied layer는 "엔진이 실제로 추적하는 월드 actor"여야 한다.
- B41 인간 NPC 계열에서 배울 것은
  - manager 분리,
  - actor 후처리,
  - actor -> record lookup 흐름
  이다.
- B41 구현의 거대한 단일체와 save-file lifecycle 전체는 배울 대상이 아니다.

## 4. NPC 생성 / 실체화 방식 비교

### 4-1. Superb Survivors 원본 / Continued

둘 다 핵심은 같다.

- `SurvivorFactory.CreateSurvivor(...)`
- `IsoPlayer.new(...)`
- `setSceneCulled(false)`
- `setBlockMovement(true)`
- `setNPC(true)`

load 경로도 유사하다.

- `Buddy:load(filename)`
- 좌표 다시 세팅
- `setNPC(true)`
- `setSceneCulled(false)`

즉, "새 인간형 월드 actor를 직접 만든다"가 이 계열의 본질이다.

이 점은 중요하다.

- Build 41에서 실제로 인간형 NPC가 돌아갔던 사례는 존재한다.
- 그러므로 LWN의 `IsoPlayer` embodied 방향은 개념적으로 틀리지 않다.
- 다만 이 레퍼런스들이 안정성을 확보한 방식은 매우 B41스럽고 거칠다.

### 4-2. PZNS

PZNS도 같은 길을 간다.

- `SurvivorDesc` 생성
- 필요 시 `dressInNamedOutfit`
- `IsoPlayer.new(...)`
- `setNPC(true)`
- `setSceneCulled(false)`

즉, Superb 계열과 PZNS는 서로 다른 코드베이스지만 같은 전제를 공유한다.

- B41 인간형 NPC는 결국 `IsoPlayer`를 월드에 세우는 싸움이었다.

### 4-3. Bandits

Bandits는 정반대다.

- 인간형 `IsoPlayer` 대신 zombie를 bandit runtime으로 바꾼다.
- 엔진이 가장 안정적으로 다루는 월드 actor를 먼저 확보하고, 그 위에 NPC 환상을 얹는다.

즉, 실체화 안정성만 놓고 보면 Bandits가 가장 보수적이고 강하다.

### 4-4. BanditsCreator

Creator의 `IsoPlayer.new(...)`는 world embodiment가 아니라 preview source다.

- `setInvisible(true)`
- `setGhostMode(true)`
- UI avatar panel 연결

이건 LWN world actor 구현의 근거가 아니라, 오히려 섞으면 안 되는 경로다.

### 4-5. 실체화 관점의 교훈

- Build 41 인간 NPC들이 말하는 것:
  - `IsoPlayer` 실체화는 가능했지만 관리 비용이 컸다.
- Build 42 Bandits가 말하는 것:
  - 엔진이 잘 아는 actor를 쓰면 훨씬 안정적이다.
- LWN에 대한 결론:
  - `IsoPlayer` embodied cache를 계속 쓸 수는 있다.
  - 하지만 `createActor()` 성공만으로 실체화가 끝났다고 보면 안 된다.

## 5. 시각화 / 외형 적용 방식 비교

### 5-1. Superb Survivors 원본 / Continued

이 둘이 이번 턴에서 특히 중요했던 이유가 여기 있다.

둘 다 외형 적용을 "1회성 desc seed"로 끝내지 않는다.

- `SuitUp(...)`
- `WearThis(...)`
- `setWornItem(...)`
- `initSpritePartsEmpty()`
- `triggerEvent("OnClothingUpdated", player)`
- 상황에 따라 `resetModel()`

원본은 preset spawn에서 더 직접적으로 간다.

- `getHumanVisual():setSkinTextureIndex(...)`
- `setHairModel(...)`
- `setBeardModel(...)`
- `setHairColor(...)`

즉, 실제로 굴러간 B41 인간 NPC는 "spawn 후 visual graph를 다시 건드리는 것"을 당연하게 여겼다.

### 5-2. PZNS

PZNS도 똑같은 메시지를 준다.

- `dressInNamedOutfit`로 seed
- 이후 utility로
  - hair
  - skin
  - clothing
  - worn item
  를 다시 적용

즉, PZNS 역시 "desc만 믿지 않는다".

### 5-3. Bandits

Bandits는 여기서 한 단계 더 과격하다.

- `getHumanVisual()`
- `getItemVisuals():clear()`
- `getWornItems():clear()`
- body / hair / beard / clothing rebuild
- `resetModelNextFrame()`
- `resetModel()`

이건 Build 42에서 외형 리빌드가 얼마나 중요한지 보여주는 가장 강한 반례다.

### 5-4. BanditsCreator

Creator도 preview에서조차 직접 외형을 만진다.

- `setFemale(...)`
- `getHumanVisual():setSkinTextureIndex(...)`
- `setWornItem(...)`
- `setAttachedItem(...)`

즉, preview actor조차 desc seed만으로는 끝내지 않는다.

### 5-5. 시각화 관점의 교훈

LWN에 대한 직접 결론은 명확하다.

- "descriptor를 넣었으니 보여야 한다"는 가정은 약하다.
- 실제로 굴러간 구현들은 모두 spawn 뒤에 visual rebuild 단계를 둔다.
- 투명 NPC 문제의 우선 가설은
  - world registration 실패
  보다는
  - visual/material/model refresh 누락
  쪽이 더 설득력 있다.

## 6. 상호작용 처리 방식 비교

### 6-1. Superb Survivors 원본 / Continued

둘 다 `OnFillWorldObjectContextMenu`에서 클릭 square만 보지 않는다.

- 현재 square
- N / S / E / W
- 일부 대각 인접 square
- 각 square의 `movingObjects`
- 그 안의 `IsoPlayer`

즉, "월드 actor를 먼저 찾고, 그 actor의 modData ID를 기준으로 상호작용"한다.

### 6-2. PZNS

PZNS도 흐름이 같다.

- mouse square의 moving objects 탐색
- `IsoPlayer` 확인
- `survivorID`로 manager lookup
- record mutation

즉, 상호작용은 항상

- world entity 탐색
- canonical record lookup
- mutation

순서로 이어진다.

### 6-3. Bandits

Bandits도 클릭 square 주변을 확장 탐색해 bandit zombie를 찾는다.

즉, Build 42 쪽도 같은 결론이다.

### 6-4. 상호작용 관점의 교훈

- LWN의 context menu는 square 1칸 고정 탐색이면 부족할 가능성이 높다.
- 유저 체감상 "안 보인다" 문제 일부는 사실 "찾는 범위가 좁다" 문제일 수 있다.
- 따라서 시각화와 상호작용은 분리해서 디버깅해야 한다.

## 7. unload / despawn / lifecycle 방식 비교

### 7-1. Superb Survivors 원본 / Continued

이 계열은 강한 B41식 lifecycle workaround를 쓴다.

- save file 기반 개체 저장
- `LoadGridsquare`에서 재실체화
- `removeFromWorld()`
- `removeFromSquare()`
- `player = nil`
- `OnRenderTick`에서 survivor routine update

즉, 살아있는 actor cache를 오래 믿지 않고 자주 걷어냈다.

### 7-2. PZNS

PZNS는 이걸 더 체계적으로 만들었지만 더 안전하진 않다.

- `EveryOneMinute`
- spawn range 체크
- save file reload
- offscreen 시 `setGhostMode(true)`
- `Debug Nil Job`
- `npcIsoPlayerObject = nil`

이건 개념적으로는 "offscreen actor를 data-only로 되돌린다"는 점에서 LWN의 방향과 닮았지만, 구현 수단은 Build 41 우회 냄새가 매우 강하다.

### 7-3. Bandits / WeekOne

Bandits 계열은 인간 `IsoPlayer` lifecycle 문제 자체를 우회한다.

- zombie runtime이 계속 월드에서 안정적으로 돈다.
- WeekOne은 그 위에 연출만 얹는다.

### 7-4. lifecycle 관점의 교훈

- LWN이 지금 당장 가져와야 할 것은 "오프스크린은 data가 canonical"이라는 개념뿐이다.
- 가져오면 안 되는 것은
  - save-file actor reload 중심 설계
  - aggressive remove / ghost / nil job
  - `OnRenderTick` 광범위 업데이트
  다.
- 현재 LWN 단계에서는 unload 최적화보다 "일단 보이는 embodied actor를 안정적으로 유지"하는 편이 맞다.

## 8. Build 42로 가져올 수 있는 것

### 8-1. 바로 가져올 수 있는 것

- spawn 뒤에 외형 후처리 단계를 별도 함수로 두는 패턴
- `HumanVisual`, worn item, attached item, clothing update를 명시적으로 다루는 사고방식
- world actor를 찾은 뒤 canonical record로 연결하는 context menu 구조
- manager / task / AI / UI 분리
- debug logging과 template / forced spawn 진입점 유지

### 8-2. 개념만 가져올 수 있는 것

- offscreen actor를 data-only로 되돌리는 발상
- group / zone / schedule 계층 분리
- loaded square 근처에서만 actor를 실체화하는 발상

### 8-3. Build 42용으로 재설계해야 하는 것

- `IsoPlayer:load(filename)` 중심 respawn
- `removeFromWorld()` / `removeFromSquare()`를 정상 흐름의 일부로 쓰는 것
- `ghost`를 unload 주수단으로 쓰는 것
- `OnRenderTick`에서 대규모 NPC AI를 도는 것
- nil reference 회피용 dummy job 패턴

## 9. 그대로 가져오면 위험한 것

새 레퍼런스 2개를 반영하고 나면, 위험 구역은 더 분명해진다.

- Superb 원본의 단일체 구조
- Superb / PZNS의 save-file actor 복원 의존
- continued가 스스로 "rework needed"라고 표시한 spawn logic와 `LoadGridsquare` 흐름
- PZNS의 `ghost + nil job + nil actor reference` 우회
- preview actor 설정을 world actor에 섞는 것
- B41 한계 때문에 생긴 렌더 / lifecycle workaround를 Build 42 정답으로 착각하는 것

즉, "과거에 돌아갔다"와 "지금 그대로 옮겨도 된다"는 전혀 다르다.

## 10. 현재 LWN 투명 NPC 문제에 주는 직접적 시사점

이번 턴에서 가장 직접적인 시사점은 아래 5개다.

### 10-1. `IsoPlayer` 경로 자체를 포기할 근거는 없다

- Superb 원본
- Superb Continued
- PZNS

모두 인간형 `IsoPlayer` NPC를 실제 월드 actor로 썼다.

즉, LWN의 embodied `IsoPlayer` 방향은 개념적으로 여전히 가능하다.

### 10-2. 투명 문제의 1순위 의심점은 visual rebuild 부족이다

실제로 굴러간 레퍼런스 공통점:

- 착장 재적용
- sprite parts 갱신
- clothing update event
- `HumanVisual` 직접 수정
- model reset

따라서 현재 LWN도 "actor exists" 이후의 시각화 파이프라인을 더 강하게 봐야 한다.

### 10-3. preview용 패턴이 섞이면 안 된다

`BanditsCreator`의

- `setInvisible(true)`
- `setGhostMode(true)`

는 preview에만 안전하다.

현재 투명 증상을 볼 때, world embodiment 경로에 preview 잔재가 없는지 계속 의심해야 한다.

### 10-4. 상호작용 실패가 비가시성처럼 느껴질 수 있다

Superb / PZNS / Bandits 모두 square 확장 탐색을 쓴다.

따라서 LWN도

- actor visibility 검증
- actor discoverability 검증

을 분리해야 한다.

### 10-5. unload 최적화는 지금 우선순위가 아니다

B41 레퍼런스들이 unload에 집착한 이유는 엔진 제약과 성능 때문이었다.

현재 LWN은 먼저

- 보이는가
- 클릭되는가
- 외형이 유지되는가

를 고정해야 한다.

## 11. 핵심 비교 요약

### 11-1. 새 레퍼런스가 추가되며 바뀐 요약

기존에는

- Bandits는 안정적이지만 zombie 기반
- PZNS는 아이디어는 좋지만 B41 debt가 큼

정도가 중심이었다.

이번에는 여기에 다음 결론이 추가된다.

- `Superb Survivors` 계열은 "B41 인간형 NPC가 실제로 굴러가던 방식"의 가장 강한 사례다.
- 그리고 그 구현의 공통 핵심은
  - 인간 `IsoPlayer` 실체화,
  - 수동 외형 갱신,
  - 넓은 범위의 월드 상호작용 탐색
  이었다.
- 반면 그 구현의 부작용은
  - save/load 의존,
  - aggressive despawn,
  - `OnRenderTick` 루프
  였다.

### 11-2. 레퍼런스별 한 줄 요약

- `Superb Survivors`
  - 인간 `IsoPlayer` NPC는 가능하지만, 수동 refresh와 lifecycle workaround 없이는 불안정했다.
- `Superb Survivors Continued`
  - 원본의 핵심 패턴은 유지하되, 무엇이 debt인지 더 잘 드러낸 운영판이다.
- `PZNS`
  - 구조적으로 제일 깔끔한 B41 인간 NPC 프레임워크지만 unload workaround가 무겁다.
- `Bandits`
  - 엔티티 안정성을 최우선으로 확보한 뒤 외형을 강하게 리빌드한다.
- `BanditsWeekOne`
  - 안정적인 runtime 위에 이벤트 / 스케줄 / 의미 계층을 얹는 방법을 보여준다.
- `BanditsCreator`
  - preview actor와 world actor를 반드시 분리해야 한다는 반례다.

## 12. 다음 패치 전에 다시 세워야 할 가설

### 가설 A. LWN의 현재 핵심 실패는 world 등록보다 visual rebuild 부족이다

근거:

- Superb / Continued / PZNS / Bandits 모두 post-spawn visual 후처리를 쓴다.
- Bandits는 reset까지 강하게 건다.

### 가설 B. `SurvivorDesc`는 seed일 뿐, 최종 가시 모델을 보장하지 않는다

근거:

- Superb 원본 preset spawn은 `HumanVisual`을 직접 수정한다.
- PZNS는 spawn 후 hair / skin / clothing을 utility로 다시 입힌다.

### 가설 C. worn item 반영과 model refresh는 별개일 수 있다

근거:

- Superb 계열은 `setWornItem` 뒤 `initSpritePartsEmpty()`와 `OnClothingUpdated`를 붙인다.
- Bandits는 더 나아가 `resetModel*()`까지 쓴다.

### 가설 D. context menu 탐색 폭이 좁으면 "NPC가 없는 것 같다"는 체감이 섞인다

근거:

- Superb / Continued / Bandits 모두 인접 square까지 본다.
- PZNS도 moving object -> record lookup 구조다.

### 가설 E. offscreen unload를 먼저 만지면 문제를 더 흐릴 수 있다

근거:

- B41 레퍼런스들의 unload 패턴은 대부분 workaround 성격이다.
- 지금은 visibility 문제를 먼저 고정하는 편이 더 안전하다.

### 가설 F. preview 전용 플래그나 경로가 world embodiment에 새어 나오면 투명 증상을 악화시킨다

근거:

- `BanditsCreator`는 의도적으로 invisible / ghost actor를 만든다.
- 이 경로는 world actor 설계에 섞이면 안 된다.

## 13. 최종 결론

새 레퍼런스 2개를 반영한 뒤의 결론은 아래처럼 정리된다.

- B41에서 실제로 돌아간 인간형 NPC 구현은 분명히 있었다.
- 그 구현들이 공통으로 말하는 것은 "인간 `IsoPlayer`를 만들 수는 있지만, 시각화와 lifecycle을 수동으로 많이 보정해야 한다"는 점이다.
- 그래서 LWN은 `IsoPlayer` embodied 방향을 유지할 수 있다.
- 하지만 그대로 가져와야 할 것은 B41 workaround 묶음이 아니라
  - post-spawn visual rebuild,
  - world actor 중심 상호작용 탐색,
  - canonical data와 embodied cache 분리
  이다.
- 현재 LWN 투명 NPC 문제의 직접적 우선순위는 unload가 아니라 "spawn 직후 actor visual graph가 실제로 완성되는가"를 검증하는 것이다.
