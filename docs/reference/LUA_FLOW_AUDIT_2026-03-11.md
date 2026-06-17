# LivingWorldNPC Lua Flow Audit

Date: 2026-03-11

## 목적
- `42/media/lua` 아래 모든 Lua 파일을 전수 점검해 역할, 호출 흐름, 상호 의존성을 정리한다.
- 특히 "NPC 시각적 실체화"와 연결되는 경로를 분리해서 추적한다.

## Shared layer
- `42/media/lua/shared/00_LWN_Config.lua`
  - 전역 설정 테이블.
- `42/media/lua/shared/01_LWN_Schema.lua`
  - root/NPC/memory/goal/intent/legacy snapshot 생성기.
- `42/media/lua/shared/02_LWN_Localization.lua`
  - 번역 텍스트 접근 래퍼.

## Persistence and simulation layer
- `42/media/lua/client/10_LWN_PopulationStore.lua`
  - canonical root/record 접근, embodied meta 저장, debug state 저장.
- `42/media/lua/client/11_LWN_PopulationSeeder.lua`
  - 새 게임 시 NPC record 초기 시드.
- `42/media/lua/client/12_LWN_Memory.lua`
  - 기억 추가/감쇠/조회.
- `42/media/lua/client/13_LWN_Social.lua`
  - trust/resentment 조절, 명령 응답 판정.
- `42/media/lua/client/15_LWN_WorldStory.lua`
  - 오프스크린 story arc tick, clue 생성.
- `42/media/lua/client/16_LWN_GoalSystem.lua`
  - 장기/단기 goal 계산.
- `42/media/lua/client/17_LWN_UtilityAI.lua`
  - goal 기반 candidate 생성/점수화.
- `42/media/lua/client/18_LWN_BehaviorTree.lua`
  - utility winner를 intent로 변환.
- `42/media/lua/client/19_LWN_ActionIntents.lua`
  - intent schema 생성기.
- `42/media/lua/client/20_LWN_ActionRuntime.lua`
  - queued intent 실행기, currentPlan/currentIntent 미러링.
- `42/media/lua/client/21_LWN_Combat.lua`
  - square 위 zombie 위협 감지와 전투 intent 결정.
- `42/media/lua/client/22_LWN_EncounterDirector.lua`
  - hidden NPC 중 누가 eligible/first encounter 대상이 될지 결정.

## Embodiment layer
- `42/media/lua/client/23_LWN_ActorFactory.lua`
  - descriptor 생성, spawn square 선택, `IsoPlayer.new(...)`, world registration, dressup, model refresh, loadout, 실패 로그.
- `42/media/lua/client/24_LWN_ActorSync.lua`
  - canonical record <-> embodied actor stats/moodles/perks 동기화.
- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
  - hidden/eligible/embodied 상태 전환, despawn, rearm, actor cache.

## UI and interaction layer
- `42/media/lua/client/14_LWN_DialogueRealizer.lua`
  - social response를 실제 대사로 실현.
- `42/media/lua/client/26_LWN_UI_ContextMenu.lua`
  - 월드 우클릭에서 NPC 탐색과 디버그 메뉴 표시.
- `42/media/lua/client/27_LWN_UI_RadialMenu.lua`
  - follow/wait/guard/search/retreat/panel 명령.
- `42/media/lua/client/28_LWN_UI_CommandPanel.lua`
  - 현재 NPC 상태/goal/intent/clue 표시.
- `42/media/lua/client/29_LWN_UI_DialogueWindow.lua`
  - 대화 대상 상태를 텍스트로 표시.
- `42/media/lua/client/30_LWN_Legacy.lua`
  - 사망 후 legacy candidate 수집 및 적용.

## Event and debug layer
- `42/media/lua/client/90_LWN_EventAdapter.lua`
  - OnNewGame / OnCreateSurvivor / EveryOneMinute / EveryTenMinutes / OnTick / OnKeyPressed 연결점.
- `42/media/lua/client/91_LWN_Debug.lua`
  - 전체 summary dump.
- `42/media/lua/client/92_LWN_DebugTools.lua`
  - spawn/delete/dump/relationship/story beat/legacy/wipe hotkeys 및 메뉴 액션.
- `42/media/lua/client/99_LWN_Bootstrap.lua`
  - root init 및 이벤트 바인딩.

## 핵심 호출 흐름
1. `99_LWN_Bootstrap.lua`
   - `LWN.init()` -> `PopulationStore.root()` -> `EventAdapter.bind()`
2. 새 게임 시작
   - `EventAdapter.onNewGame()` -> `PopulationSeeder.seedNewWorld()` -> `WorldStory.seed()`
3. 첫 조우 후보 선정
   - `EventAdapter.onEveryOneMinute()` -> `EncounterDirector.update()`
4. eligible -> embodied
   - `EventAdapter.onTick()` -> `EmbodimentManager.tryEmbody()`
   - `EmbodimentManager.tryEmbody()` -> `ActorFactory.createActor()`
   - `ActorFactory.createActor()` -> `IsoPlayer.new(...)` -> world registration -> dressup/model refresh -> `ActorSync.pushRecordToActor()`
5. embodied tick
   - `EventAdapter.onTick()` -> `resolveEmbodiedActor()` -> `tickEmbodiedRecord()`
   - `tickEmbodiedRecord()` -> `ActorSync.ensureEmbodiedActorState()` -> `ActorSync.pullActorToRecord()`
   - 이후 `GoalSystem` -> `Combat` or `UtilityAI` -> `BehaviorTree` -> `ActionRuntime.tick()`
6. distance despawn
   - `tickEmbodiedRecord()` -> `EmbodimentManager.tryDespawn()` -> actor cleanup + record hidden

## 시각적 실체화 경로에서 중요한 지점
- `ActorFactory.createActor()`
  - `SurvivorFactory.CreateSurvivor(...)`
  - `IsoPlayer.new(...)`
  - `ensureActorRegisteredInWorld(...)`
  - `setBaselineHumanVisual(...)`
  - `Factory.refreshEmbodiedPresentation(...)`
  - `Factory.applyLoadout(...)`
- `EventAdapter.onCreateSurvivor()`
  - 엔진이 create-survivor 훅을 실제로 태우는 경우 동일한 visual refresh 경로를 재호출
- `EventAdapter.resolveEmbodiedActor()`
  - cache actor를 다시 world square에 재정렬

## 현재 감사 결론
- 아키텍처 원칙인 "canonical state는 ModData, embodied actor는 cache"는 유지 가능하다.
- 문제 중심 파일은 `23_LWN_ActorFactory.lua`, `24_LWN_ActorSync.lua`, `25_LWN_EmbodimentManager.lua`, `90_LWN_EventAdapter.lua`다.
- 나머지 AI/UI 레이어는 actor가 실제로 보이고 상호작용 가능하다는 전제 위에서 이미 작동 가능한 뼈대를 갖고 있다.
