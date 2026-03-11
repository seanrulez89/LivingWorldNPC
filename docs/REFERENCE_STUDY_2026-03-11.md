# Reference Study 2026-03-11

Project: LivingWorldNPC
Focus: `reference_mods` 재학습, 새로 추가된 `PZNS_Framework` 포함
Scope: 구조, NPC 실체화/시각화, 상호작용, LWN 적용 가능점, 직접 차용 시 위험점, 다음 수정 전에 세워야 할 가설

## 1. 이번 검토 범위

이번 턴에서 직접 다시 확인한 레퍼런스는 아래 네 묶음이다.

- `reference_mods/3268487204/mods/Bandits/42.13`
- `reference_mods/3403180543/mods/BanditsWeekOne/42.13`
- `reference_mods/3469292499/mods/BanditsCreator/42.15`
- `reference_mods/3001908830/mods/PZNS_Framework`

핵심적으로 다시 읽은 파일은 아래와 같다.

- Bandits
  - `shared/Bandit.lua`
  - `client/BanditUpdate.lua`
  - `client/BanditMenu.lua`
  - `server/BanditServerSpawner.lua`
- BanditsWeekOne
  - `shared/BWOEvents.lua`
  - `shared/BWOBanditCreator.lua`
  - `client/BWOMenu.lua`
- BanditsCreator
  - `client/BCMenu.lua`
  - `client/OptionScreens/BanditCreationMain.lua`
  - `client/OptionScreens/BanditMainScreen.lua`
- PZNS_Framework
  - `mod.info`
  - `client/03_mod_core/PZNS_NPCSurvivor.lua`
  - `client/04_data_management/PZNS_NPCsManager.lua`
  - `client/02_mod_utils/PZNS_UtilsDataNPCs.lua`
  - `client/02_mod_utils/PZNS_UtilsNPCs.lua`
  - `client/02_mod_utils/PZNS_WorldUtils.lua`
  - `client/08_mod_contextmenu/PZNS_ContextMenu*.lua`
  - `client/11_events_spawning/PZNS_Events.lua`
  - `client/10_mod_templates/PZNS_TemplateNPC*.lua`

## 2. Bandits

### 2-1. 구조

Bandits는 사실상 "NPC처럼 보이는 인간형 적/동료"를 위한 런타임 본체다.

- `shared/`
  - 상태 정의, 외형 조립, task/action, 프로그램, 호환성 레이어
- `client/`
  - 월드 엔티티 업데이트, 컨텍스트 메뉴, 표시 보조
- `server/`
  - 스폰과 동기화

핵심 축은 아래처럼 나뉜다.

- 상태: `BanditBrain.lua`
- 외형: `Bandit.lua`
- 상위 의도: `ZombiePrograms/*`
- task 생성: `BanditPrograms.lua`
- task 실행: `ZombieActions/*`
- 스폰/런타임 연결: `BanditServerSpawner.lua`, `BanditUpdate.lua`

### 2-2. NPC 실체화/시각화 방식

Bandits의 가장 중요한 점은 "새 인간형 엔티티를 직접 세우지 않는다"는 것이다.

- `BanditUpdate.lua`의 `Banditize(zombie, brain)`는 기존 zombie를 bandit runtime으로 바꾼다.
- `BanditServerSpawner.lua`는 persistent outfit id와 brain 데이터를 만들어 zombie 쪽에 입힌다.
- `Bandit.lua`의 `Bandit.ApplyVisuals()`는 실제 외형을 강하게 다시 조립한다.

직접 확인한 시각화 포인트:

- `getHumanVisual()`
- `getItemVisuals():clear()`
- `getWornItems():clear()`
- `setFemaleEtc(...)`
- 피부/헤어/수염 직접 세팅
- 아이템 비주얼을 `ItemVisual`로 직접 추가
- 마지막에 dirt/blood cleanup과 model reset 계열 호출

즉, Bandits는 descriptor만 믿지 않고 "가시 모델을 다시 빌드한다"는 성격이 강하다.

### 2-3. 상호작용 처리 방식

상호작용은 월드에 실제로 존재하는 moving object를 기준으로 열린다.

- `BanditMenu.WorldContextMenuPre`
  - 클릭 square
  - 남쪽 square
  - 서쪽 square
  를 탐색하며 target zombie를 찾는다.
- bandit 여부는 `zombie:getVariableBoolean("Bandit")`로 판별한다.
- 동료화/프로그램 전환도 runtime entity 기준이다.

즉, UI는 저장 데이터가 아니라 "지금 월드에 잡히는 엔티티"에 매달려 있다.

### 2-4. LWN에 적용 가능한 점

- 상태와 표현 분리
  - brain/modData가 canonical state이고, 월드 엔티티는 presentation/runtime cache다.
- 시각화 재조립 단계의 존재
  - 외형은 descriptor 1회 전달로 끝내지 않고, HumanVisual/item visuals/worn items를 다시 만든다.
- 상호작용의 공간 탐색
  - 컨텍스트 메뉴는 클릭 square 한 칸만 보지 않는다.
- compatibility layer 분리
  - 버전 차이나 외부 모드 차이를 별도 계층으로 격리한다.

### 2-5. 그대로 가져오면 위험한 점

- Bandits의 전제는 zombie 기반 runtime이다.
  - LWN은 `IsoPlayer` embodied cache 구조이므로 그대로 복제할 수 없다.
- SP/MP 겸용 설계라 서버 스포너와 sync 구조가 두껍다.
  - LWN SP 우선 구조에는 과하다.
- zombie 전용 animation variable, hit reaction 우회 코드가 많다.
  - Build 42 `IsoPlayer` 경로에는 그대로 맞지 않는다.

## 3. BanditsWeekOne

### 3-1. 구조

BanditsWeekOne은 NPC 엔진 본체라기보다 "Bandits 위에 올라가는 세계 연출 계층"이다.

- `shared/BWOEvents.lua`
  - 대형 이벤트, 시간표, 연출
- `shared/BWOBanditCreator.lua`
  - room/zone 기반 NPC preset 조립
- `client/BWOMenu.lua`
  - 디버그 이벤트/스폰 메뉴
- `shared/Variants/*`
  - 시나리오 데이터
- `shared/BWORooms.lua`, `BWOBuildings.lua`, `BWORoutes.lua`
  - 공간 의미 계층

`mod.info`에서 `require=Bandits2`이므로, 자체적으로 새로운 NPC 구현을 만들기보다 Bandits의 runtime을 재활용한다.

### 3-2. NPC 실체화/시각화 방식

BanditsWeekOne의 NPC 표시 자체는 Bandits 본체에 의존한다.

- `BWOEvents.lua`, `BWOEventsPlace.lua`, `BWOMenu.lua`에서
  - `sendClientCommand(..., 'Spawner', 'Clan', args)`
  - 또는 직접 `BanditServer.Spawner.Clan(...)`
  로 Bandits runtime spawn을 호출한다.
- `BWOBanditCreator.lua`는 room/zone/variant별로
  - outfit
  - weapon chance
  - hair style
  - loot
  같은 데이터를 조합한다.

즉, WeekOne은 "NPC를 어떻게 보이게 하느냐"보다 "어떤 상황에 어떤 NPC 군집을 놓을 것이냐"에 집중한다.

### 3-3. 상호작용 처리 방식

- `BWOMenu.WorldContextMenuPre`
  - profession, clicked square, nearby zombie를 읽어서 의사/간호사의 heal 같은 액션을 붙인다.
- 디버그 메뉴는 방대한 이벤트/스폰/연출 테스트 진입점이다.
- 상호작용도 최종적으로는 Bandits runtime entity에 기대고 있다.

### 3-4. LWN에 적용 가능한 점

- scene/schedule/variant 계층의 독립 모듈화
- room/building/route 기반 의미론
- 세계 이벤트와 NPC 그룹 스폰을 분리된 레이어로 운영하는 방식
- 디버그 메뉴로 시스템 단위를 강제 호출하는 습관

### 3-5. 그대로 가져오면 위험한 점

- Bandits runtime이 깔려 있다는 전제가 강하다.
- 연출 규모가 크고 patch/override도 많다.
- 현재 LWN의 우선순위인 "NPC가 보이느냐"보다 그 위 레이어의 문제를 다루므로, 지금 그대로 흡수하면 우선순위가 흐려진다.

## 4. BanditsCreator

### 4-1. 구조

BanditsCreator는 editor/preview 도구다.

- `BCMenu.lua`
  - 컨텍스트 메뉴 진입
- `OptionScreens/BanditCreationMain.lua`
  - 개별 NPC 편집
- `OptionScreens/BanditMainScreen.lua`
  - 저장된 NPC 목록과 미리보기
- `OptionScreens/BanditClanMain.lua`
  - 클랜 단위 편집

### 4-2. NPC 실체화/시각화 방식

중요한 점은 여기의 `IsoPlayer.new(...)`가 "월드 actor"가 아니라 "UI preview source"라는 점이다.

- `BanditCreationMain.lua`
  - `IsoPlayer.new(getCell(), self.desc, px, py, pz)`
  - `setNPC(true)`
  - `setInvisible(true)`
  - `setGhostMode(true)`
  - `setFemale(...)`
  - `getHumanVisual():setSkinTextureIndex(...)`
  - 헤어/수염 세팅
  - `avatarPanel:setCharacter(self.model)`
- `BanditMainScreen.lua`
  - 동일한 방식으로 preview model 생성
  - `setWornItem(...)`, `setAttachedItem(...)`로 시각 미리보기 갱신

이 구조는 "투명해도 괜찮은" actor를 의도적으로 만든 것이다. UI 3D 패널이 따로 렌더링하기 때문이다.

### 4-3. 상호작용 처리 방식

- `BCMenu.WorldContextMenuPre`
  - 디버그/관리자 조건에서 "Bandit Creator" UI를 연다.
- 이후 상호작용은 거의 전부 UI 내부에서 일어난다.
- 월드에 놓인 embodied NPC를 대상으로 한 상호작용 구조는 아니다.

### 4-4. LWN에 적용 가능한 점

- preview actor와 world actor를 분리해야 한다는 교훈
- character editor/appearance debug 도구 설계
- 착장, 피부, 헤어를 빠르게 조합해 검증하는 테스트 harness

### 4-5. 그대로 가져오면 위험한 점

- `setInvisible(true)`와 `setGhostMode(true)`는 preview 문맥이라 안전한 것이다.
- 이 코드를 world embodiment에 오해해서 가져오면 오히려 투명 NPC를 만들 수 있다.
- "IsoPlayer가 생성됐다"는 사실만으로 월드에서 보여야 한다고 생각하면 잘못된 결론으로 이어진다.

## 5. PZNS_Framework

### 5-1. 구조

`mod.info`에 `versionMin=41.1`이 명시되어 있어, 기본 전제부터 Build 41 계열이다.

구조는 꽤 정리돼 있다.

- `03_mod_core/`
  - `PZNS_NPCSurvivor.lua`, `PZNS_NPCGroup.lua`, `PZNS_NPCZone.lua`
- `04_data_management/`
  - active NPC/group/zone manager
- `05_npc_actions/`
  - 행동 유틸
- `06_npc_orders/`
  - follow, hold, attack 같은 order
- `07_npc_ai/`
  - general AI, jobs, need handling
- `08_mod_contextmenu/`
  - invite, jobs, orders, info, inventory
- `09_mod_ui/`
  - 디버그/정보 UI
- `10_mod_templates/`
  - Jill/Chris 테스트 NPC
- `11_events_spawning/`
  - 이벤트 등록과 디버그 스폰

LWN 관점에서 흥미로운 점은 "canonical NPC data + embodied IsoPlayer cache" 구도가 이미 존재한다는 점이다.

### 5-2. NPC 실체화/시각화 방식

PZNS는 실제로 `IsoPlayer` 기반 NPC를 만든다.

`PZNS_NPCsManager.createNPCSurvivor()`와 내부 `createIsoPlayer()` 흐름을 보면:

- `SurvivorDesc` 생성
- 필요 시 `survivorDescObject:dressInNamedOutfit(outfit)`
- `IsoPlayer.new(...)`
- `getModData().survivorID` 기록
- `setForname`, `setSurname`
- `setNPC(true)`
- `setSceneCulled(false)`

그 뒤 외형은 utility로 후처리한다.

- `PZNS_UtilsNPCs.PZNS_AddEquipClothingNPCSurvivor`
  - 아이템 인스턴스를 인벤토리에 넣고
  - `setWornItem(bodyLocation, clothingItem)` 호출
- `PZNS_UtilsNPCs.PZNS_SetNPCHairModel`
- `PZNS_UtilsNPCs.PZNS_SetNPCHairColor`
- `PZNS_UtilsNPCs.PZNS_SetNPCSkinTextureIndex`
- `PZNS_UtilsNPCs.PZNS_SetNPCSkinColor`

테스트 템플릿들도 같은 흐름을 쓴다.

- `PZNS_TemplateNPCChrisTester.lua`
- `PZNS_TemplateNPCJillTester.lua`

즉, PZNS는 descriptor만으로 충분하다고 보지 않고 "spawn 후 visual/inventory/clothing를 다시 얹는" 방식이다.

### 5-3. 오프스크린/리스폰 방식

이 부분은 Build 42 LWN에서 특히 조심해야 한다.

- `PZNS_WorldUtils.PZNS_SpawnNPCIfSquareIsLoaded`
  - `EveryOneMinute`로 spawn/despawn 판단
- 사거리 안이면
  - `PZNS_UtilsDataNPCs.PZNS_SpawnNPCFromModData(...)`
  - `npcIsoPlayerObject:setGhostMode(false)`
- 사거리 밖이면
  - 저장
  - `npcIsoPlayer:setGhostMode(true)`
  - job을 `Debug Nil Job`로 바꾸고
  - `npcSurvivor.npcIsoPlayerObject = nil`

또한 `PZNS_UtilsDataNPCs.PZNS_SpawnNPCFromModData`는 save file에서 `npcIsoPlayerObject:load(npcFileName)`까지 호출한다.

이건 "IsoPlayer save file + ModData + aggressive spawn/despawn"를 묶은 구조다.

### 5-4. 상호작용 처리 방식

PZNS의 상호작용 구조는 LWN에 꽤 유용하다.

- `PZNS_ContextMenu.PZNS_OnFillWorldObjectContextMenu`
  - 통합 submenu를 만든다.
- 세부 메뉴는 역할별 파일로 분리되어 있다.
  - invite
  - jobs
  - orders
  - inventory
  - info
  - zones
- `InviteOptions`는 player mouse square의 moving objects를 훑어
  - `IsoPlayer`인지 확인
  - `survivorID`로 manager에서 NPC record를 찾고
  - group 이동과 저장을 수행한다.

즉, 상호작용이

- 월드 엔티티 탐색
- canonical record lookup
- record mutation
- 저장

의 순서로 이어진다.

### 5-5. LWN에 적용 가능한 점

- canonical record와 embodied actor reference를 분리하는 사고방식
- NPC manager / group manager / zone manager 분리
- context menu를 기능 단위 파일로 세분하는 방식
- 테스트용 template NPC와 debug UI를 유지하는 습관
- spawn 후 visual/inventory/clothing를 utility 함수로 덧입히는 패턴

### 5-6. 그대로 가져오면 위험한 점

PZNS는 Build 41 전제가 강해서 그대로 믿으면 안 된다.

- `versionMin=41.1`
- 코드 주석에도 B41의 MP/NPC 문제를 직접 언급
- `EveryOneMinute + ghost mode + nil reference` 조합은 Build 42 LWN에서 위험하다.
- save file 기반 `IsoPlayer:load(...)` 의존도도 높다.
- `OnRenderTick`에 AI 루프를 묶는 부분은 규모가 커질수록 비용이 크다.
- `isExistInTheWorld()`가 불안정하다고 전제하는 주석이 있어, 런타임 가정이 낡았을 가능성이 있다.

핵심적으로, PZNS는 "좋은 아이디어가 있는 실험적 프레임워크"이지, Build 42에서 검증된 정답 구현으로 보면 안 된다.

## 6. 새 레퍼런스에서 얻은 핵심 교훈

이번에 새로 추가된 PZNS까지 포함해서 다시 정리하면, 중요한 교훈은 아래와 같다.

### 6-1. 시각화는 descriptor만으로 끝나지 않는다

Bandits와 PZNS 모두 공통으로, spawn 이후에 아래를 다시 만진다.

- gender
- hair
- skin
- beard
- clothing
- hand item / attached item

즉, LWN의 투명 문제를 다시 볼 때도 "descriptor를 넣었으니 보여야 한다"는 가정은 약하다.

### 6-2. world actor와 preview actor는 분리해야 한다

BanditsCreator는 `IsoPlayer`를 많이 만들지만, 그 목적은 UI preview다.
따라서 BanditsCreator의 `invisible/ghost` 세팅은 world embodiment 근거가 아니라 오히려 반례다.

### 6-3. 상호작용은 엔티티 탐색과 record lookup의 결합이다

Bandits도, PZNS도 둘 다 월드 moving object를 먼저 찾고 그 다음 저장 record와 연결한다.
이 점은 LWN의 context menu 안정화에 직접 도움이 된다.

### 6-4. 오프스크린 관리와 실체화는 분리해서 생각해야 한다

PZNS는 aggressive spawn/despawn를 쓰지만, 그 부분은 Build 42에서 그대로 가져오기보다 개념만 참고해야 한다.
LWN의 우선순위는 먼저 "한 번 실체화된 NPC가 확실히 보이는가"다.

## 7. PZNS Build 41에서 Build 42 LWN으로 가져올 수 있는 것 / 없는 것

### 7-1. 가져올 수 있는 것

- manager 분리
  - NPC, group, zone을 각기 다른 관리 모듈로 유지하는 구조
- canonical state와 embodied actor reference 분리
- spawn 후 후처리 방식
  - hair/skin/clothing/equipment를 유틸 함수로 다시 적용
- world entity -> record lookup -> action mutation 흐름의 context menu 구조
- template NPC, debug hotkey, debug panel 같은 개발용 보조 체계

### 7-2. 검증적으로만 참고해야 하는 것

- `IsoPlayer.new(...)` 후 `setNPC(true)`, `setSceneCulled(false)` 같은 기본 세팅
  - 아이디어는 유효하지만 Build 42에서 충분조건이라고 단정하면 안 된다.
- `dressInNamedOutfit(outfit)` 후 추가 착장
  - 초기 외형 seed 용도로는 참고 가능하지만, Build 42에서는 model refresh 경로가 더 중요할 수 있다.
- 거리 기반 spawn/despawn 관리자
  - 개념은 참고 가능하나 구현은 다시 설계해야 한다.

### 7-3. 그대로 가져오면 안 되는 것

- Build 41 전제의 save/load 경로
  - `npcIsoPlayerObject:load(npcFileName)` 중심 흐름
- `ghost mode`를 offscreen unload의 핵심 메커니즘으로 쓰는 방식
- `Debug Nil Job`처럼 nil reference 회피를 위해 job을 강제로 바꾸는 방식
- `OnRenderTick`에 광범위한 AI 업데이트를 올리는 구조
- B41 MP/NPC 한계를 우회하기 위한 workaround들

## 8. 이번 투명 NPC 문제를 수정 전에 어떻게 다시 접근할 것인가

이번 재학습 후에는, "NPC가 월드에 없다"와 "월드에는 있는데 메시가 안 생긴다"를 분리해서 봐야 한다.

이미 최근 LWN 로그에서는 `world=true`, `ghost=false`, `invisible=false`, `sceneCulled=false`, `alpha=1.00`가 관측된 적이 있다.
따라서 다음 수정은 아래 순서로 접근하는 편이 더 타당하다.

1. 월드 등록 실패 가설과 시각화 실패 가설을 분리한다.
2. preview용 패턴과 world actor 패턴을 섞지 않는다.
3. descriptor 기반 초기화 이후 실제 visual rebuild가 필요한지 검증한다.
4. 컨텍스트 메뉴 실패를 "안 보인다"와 혼동하지 않도록 상호작용 탐색 경로도 별도 검증한다.

## 9. 다음 수정 단계에서 검증할 가설 목록

### 가설 A. 실제 실패점은 world registration이 아니라 visual rebuild 누락이다

근거:

- Bandits는 HumanVisual/item visuals/worn items/model reset을 강하게 묶는다.
- PZNS도 spawn 후 hair/skin/clothing를 다시 얹는다.
- BanditsCreator는 preview에서도 visual을 직접 건드린다.

검증 포인트:

- embodied 직후 `getHumanVisual()`의 skin/hair/beard 값
- `getItemVisuals()`와 `getWornItems()`의 개수
- same-frame 또는 next-frame model refresh 이후 값 변화

### 가설 B. `SurvivorDesc`의 정보가 `IsoPlayer` 메시로 충분히 전파되지 않는다

근거:

- 여러 레퍼런스가 descriptor 이후에 다시 `setFemale`, `setSkinTextureIndex`, `setHairModel`, `setWornItem`을 호출한다.

검증 포인트:

- desc 기반 spawn만 한 actor
- desc 이후 direct visual mutation을 한 actor
- 둘의 가시성 차이 비교

### 가설 C. worn item은 들어가지만 body/item visual graph가 갱신되지 않는다

근거:

- Bandits는 `ItemVisual`을 직접 조작한다.
- PZNS는 clothing item을 인벤토리와 worn item에 모두 넣는다.

검증 포인트:

- 옷 inventory 존재 여부
- worn item slot 존재 여부
- item visuals 반영 여부

### 가설 D. Build 42에서는 model manager 또는 equivalent refresh가 더 직접 필요하다

근거:

- Bandits는 reset 계열 호출을 반복한다.
- LWN 로그상 world flag는 정상인데도 여전히 안 보인다면, 메시 생성 타이밍/리셋 문제가 남는다.

검증 포인트:

- refresh 전후 `containsChar`류 상태
- next-frame 이후 가시성 변화

### 가설 E. 상호작용 탐색 실패가 "비가시화" 체감과 섞여 있다

근거:

- Bandits와 PZNS 모두 clicked square 한 칸보다 넓게 엔티티를 찾는다.
- LWN이 좁은 범위만 보면, 실제로는 nearby actor가 있어도 유저는 "없는 것 같다"고 느낄 수 있다.

검증 포인트:

- clicked square
- 인접 square
- moving objects 전체 탐색 결과 비교

### 가설 F. PZNS식 ghost/offscreen 관리 아이디어는 현재 증상의 직접 원인이 아닐 가능성이 높다

근거:

- 최근 LWN 로그에서는 `ghost=false`가 찍힌 적이 있다.
- 따라서 지금 당장의 1순위는 ghost flag보다 visual/material/model 생성 경로다.

검증 포인트:

- 같은 NPC에 대해 spawn 직후와 몇 틱 후의 `ghost`, `invisible`, `alpha`, `isSceneCulled`를 나눠 기록

## 10. 결론

이번 레퍼런스 재학습으로 가장 분명해진 것은 아래 두 가지다.

- Bandits 계열은 "월드에 안정적으로 존재하는 엔티티를 어떻게 NPC처럼 꾸밀 것인가"에 강하다.
- PZNS는 "IsoPlayer 기반 NPC 관리와 상호작용 구조"에 아이디어를 주지만, Build 41 가정과 workaround가 많아 Build 42 LWN에 그대로 가져오면 위험하다.

따라서 다음 수정 단계는 PZNS를 복제하는 방향이 아니라,

- LWN의 existing embodied `IsoPlayer` 경로를 유지하되
- post-spawn visual rebuild와 debug instrumentation을 더 엄밀히 검증하고
- world actor와 preview actor 개념을 섞지 않는 방향

으로 가는 것이 맞다.
