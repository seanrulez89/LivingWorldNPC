# Build 42 Modding Knowledge Map 2026-03-12

Project: LivingWorldNPC  
Purpose: Build 42 modding 전반을 폭넓게 학습하고, 나중에 어떤 API 축이 필요해져도 다시 찾기 쉬운 지형도로 정리한다.  
Scope: 이번 턴은 문서 학습/정리만 수행하며, 런타임 코드 수정은 하지 않는다.

## 1. 출발점과 증거 등급

필수 출발점:

- PZwiki Modding: https://pzwiki.net/wiki/Modding
- Official modding Javadocs index: https://projectzomboid.com/modding/index.html

이번 문서에서의 증거 등급:

- Official primary
  - `projectzomboid.com/modding/` 아래의 공식 JavaDocs
  - `projectzomboid.com` 공식 블로그/정책 문서
  - The Indie Stone 공식 포럼 자료
- Official-adjacent / community curated
  - `pzwiki.net`의 모딩 허브, 이벤트, 포맷, 도구, 가이드 문서
  - 실무적으로 매우 유용하지만, API 존재성/시그니처의 최종 근거는 아니다
- Supplemental external
  - PZwiki가 연결하는 언어/도구/커뮤니티 외부 문서
  - 도구 사용법, Lua/Java 일반 지식, 역공학 워크플로에는 도움되지만 PZ API의 1차 근거는 아니다

핵심 관찰:

- Official JavaDocs는 Java 표면을 기준으로 Build 42 엔진 표면적을 가장 넓게 보여준다.
- PZwiki는 Lua 이벤트, 스크립트 포맷, 맵/타일, 모드 구조, 디버그 워크플로를 연결해 주는 인덱스 역할을 한다.
- Build 42에서 실제 모딩 작업은 "공식 JavaDocs + PZwiki 이벤트/포맷 문서 + 일부 공식 블로그/포럼 공지"의 조합으로 이해하는 것이 가장 안전하다.

## 2. 이번 턴에 넓게 따라간 문서 축

대표적으로 확인한 페이지 묶음:

- 허브 / 온보딩
  - https://pzwiki.net/wiki/Modding
  - https://pzwiki.net/wiki/Mod_structure
  - https://pzwiki.net/wiki/Game_files
  - https://pzwiki.net/wiki/File_formats
  - https://pzwiki.net/wiki/Debug_mode
  - https://pzwiki.net/wiki/Startup_parameters
  - https://pzwiki.net/wiki/Mod_optimization
- API 인덱스 / 클래스 / 패키지
  - https://projectzomboid.com/modding/index.html
  - https://projectzomboid.com/modding/zombie/characters/package-summary.html
  - https://projectzomboid.com/modding/zombie/ui/package-summary.html
  - https://projectzomboid.com/modding/zombie/iso/package-summary.html
  - https://projectzomboid.com/modding/zombie/iso/objects/package-summary.html
  - https://projectzomboid.com/modding/zombie/inventory/package-summary.html
  - https://projectzomboid.com/modding/zombie/inventory/types/package-summary.html
  - https://projectzomboid.com/modding/zombie/core/skinnedmodel/package-summary.html
  - https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/package-summary.html
  - https://projectzomboid.com/modding/zombie/audio/package-summary.html
  - https://projectzomboid.com/modding/zombie/radio/package-summary.html
  - https://projectzomboid.com/modding/zombie/scripting/package-summary.html
  - https://projectzomboid.com/modding/zombie/scripting/objects/package-summary.html
  - https://projectzomboid.com/modding/zombie/globalObjects/package-summary.html
  - https://projectzomboid.com/modding/zombie/worldMap/package-summary.html
  - https://projectzomboid.com/modding/zombie/world/moddata/package-summary.html
  - https://projectzomboid.com/modding/zombie/savefile/package-summary.html
  - https://projectzomboid.com/modding/zombie/network/package-summary.html
  - https://projectzomboid.com/modding/zombie/spnetwork/package-summary.html
- 이벤트 / Lua 브리지
  - https://pzwiki.net/wiki/Lua_event
  - https://pzwiki.net/wiki/Category:Current_Lua_events
  - https://pzwiki.net/wiki/Lua_object
  - https://pzwiki.net/wiki/Java_object
  - https://pzwiki.net/wiki/JavaDocs
- 스크립트 / 데이터 / 콘텐츠 작성
  - https://pzwiki.net/wiki/Scripts
  - https://pzwiki.net/wiki/Procedural_distributions
  - https://pzwiki.net/wiki/Item
  - https://pzwiki.net/wiki/Vehicle
  - https://pzwiki.net/wiki/Sound
  - https://pzwiki.net/wiki/Sandbox_options
  - https://pzwiki.net/wiki/TimedAction
- 비주얼 / 맵 / 타일 / 렌더링
  - https://pzwiki.net/wiki/Modeling
  - https://pzwiki.net/wiki/Rendering
  - https://pzwiki.net/wiki/Animation
  - https://pzwiki.net/wiki/Mapping
  - https://pzwiki.net/wiki/map.info
  - https://pzwiki.net/wiki/Adding_new_tiles
  - https://pzwiki.net/wiki/Tile_properties
  - https://pzwiki.net/wiki/Room_definitions_and_item_spawns
  - https://pzwiki.net/wiki/Vehicle_zones
- 네트워킹 / 세이브 / 보조 실무
  - https://pzwiki.net/wiki/Networking
  - https://pzwiki.net/wiki/Testing_mods_in_multiplayer
  - https://pzwiki.net/wiki/PersistentOutfitID
  - https://pzwiki.net/wiki/Remote_debugging
  - https://pzwiki.net/wiki/Decompiling_game_code
- 공식 공지 / 정책
  - https://projectzomboid.com/blog/news/2024/11/build-42-unstable/
  - https://projectzomboid.com/blog/news/2025/09/terminally-illinois/
  - https://theindiestone.com/forums/index.php?/topic/82717-applying-41-mp-server-changes-to-42/

## 3. Build 42 모딩 지형도

### 3-1. 온보딩, 폴더 구조, 파일 포맷

Official primary:

- Build 42 런타임 표면은 공식 JavaDocs 인덱스가 가장 넓게 보여준다.

Official-adjacent:

- `Mod structure`는 `42/`와 `common/` 같은 배치 구조를 이해하는 진입점이다.
- `Game files`는 게임 설치/사용자 폴더/로그/세이브 위치를 다시 찾을 때 유용하다.
- `File formats`는 텍스트 스크립트, 맵 관련 파일, 설정 파일 등 데이터형 자산의 입구 역할을 한다.
- `Debug mode`, `Startup parameters`, `Mod optimization`은 모드 실험과 성능 확인의 반복 루프를 정리해 준다.

시사점:

- LWN처럼 런타임 Lua와 데이터 자산을 함께 다루는 모드는 API 클래스 문서만으로는 충분하지 않다.
- 구조 문서와 파일 포맷 문서를 같이 봐야 저장 위치, 패치 지점, 디버그 관찰 지점을 놓치지 않는다.

### 3-2. 이벤트와 Lua 브리지

Official primary:

- 공식 JavaDocs는 이벤트 카탈로그를 잘 설명하지 않는다.
- 대신 클래스 메서드와 패키지 구조를 통해 "이 이벤트가 결국 어떤 객체로 연결되는가"를 확인할 수 있다.

Official-adjacent:

- `Lua_event`와 `Category:Current Lua events`가 실제 Lua 훅의 중심 인덱스다.
- 카테고리 페이지 기준 현재 Lua 이벤트는 매우 넓은 범위를 덮고 있으며, Build 42 실무에서는 사실상 필수 레퍼런스다.
- `Lua_object`, `Java_object`, `JavaDocs` 페이지는 Lua에서 만나는 객체가 어느 Java 클래스와 연결되는지 추적하는 브리지 역할을 한다.

도메인별 이벤트 축:

- 인간형 / 캐릭터
  - `OnCreateLivingCharacter`, `OnCreateSurvivor`, `OnClothingUpdated`
- 좀비 / 시체
  - `OnZombieCreate`, `OnZombieDead`, `OnDeadBodySpawn`
- UI / 입력
  - 컨텍스트 메뉴, 키 입력, 플레이어 업데이트, UI 갱신 계열이 이벤트 분류의 큰 축을 이룬다
- 월드 / 오브젝트
  - 월드 로드, 오브젝트 생성/변화, 월드 컨텍스트 메뉴, 시간/날씨 변화 관련 훅이 존재한다
- 데이터 / 저장
  - `ModData`, `GlobalModData`, 분배 테이블 merge, 라디오/사운드 초기화 계열 훅이 중요하다
- MP / 네트워킹
  - 수신/송신, 클라이언트-서버 이벤트, MP 테스트용 훅이 별도 축으로 존재한다

시사점:

- Build 42 실무에서 Lua 이벤트 정의는 PZwiki 의존도가 높다.
- 다만 이벤트가 넘겨주는 객체의 실제 능력은 반드시 JavaDocs로 재검증해야 한다.

### 3-3. 인간형 캐릭터, NPC, 캐릭터 상태

Official primary:

- `zombie.characters` 패키지는 `IsoGameCharacter`, `IsoPlayer`, `IsoZombie`, `IsoSurvivor`, `SurvivorDesc`, `Stats`, `BodyDamage`, `XP`, `Skills`, `WornItems` 같은 핵심 표면을 모아 둔다.
- `zombie.characters.action`, `skills`, `traits`, `Moodles`, `BodyDamage` 하위 패키지는 인간형 행위와 상태 시스템의 세부 층을 보여 준다.
- 대표 클래스:
  - https://projectzomboid.com/modding/zombie/characters/IsoPlayer.html
  - https://projectzomboid.com/modding/zombie/characters/IsoSurvivor.html
  - https://projectzomboid.com/modding/zombie/characters/IsoZombie.html
  - https://projectzomboid.com/modding/zombie/characters/SurvivorDesc.html
  - https://projectzomboid.com/modding/zombie/characters/IsoGameCharacter.html

Official-adjacent:

- `OnCreateLivingCharacter`는 `IsoPlayer`와 `IsoSurvivor` 생성 문맥을 연결해 준다.
- `OnCreateSurvivor`는 `IsoSurvivor` 전용 훅으로 구분되어 있다.

핵심 정리:

- Build 42에서 인간형 캐릭터 조작은 가능하지만, 공식 문서 표면만으로 "정식 human NPC framework"가 있다고 보기는 어렵다.
- 공식 블로그 기준 인간형 NPC 방향성은 Build 43 문맥에서 더 강하게 언급된다.
- 즉 Build 42의 인간형 NPC는 공식 클래스 표면 위에서 작동할 수는 있어도 안정 지원 영역으로 단정하면 위험하다.

### 3-4. UI, 입력, HUD, 메뉴

Official primary:

- `zombie.ui` 패키지는 UI 요소, 패널, HUD, 목록, 텍스트, 조이스틱/마우스 상호작용 계층을 모은다.
- `zombie.input` 패키지는 키/마우스/컨트롤러 입력 처리를 보여 준다.
- `zombie.chat`와 일부 `gameStates` 문서도 UI 흐름과 얽힌다.

Official-adjacent:

- PZwiki 이벤트 문서는 우클릭 메뉴, 인벤토리 메뉴, 툴팁, 플레이어 업데이트 등 Lua 진입점을 잡는 데 더 실용적이다.

시사점:

- Build 42 UI 모딩은 Java 클래스보다 Lua 이벤트와 기존 UI 객체 관례를 함께 읽어야 한다.
- LWN의 디버그 UI/우클릭 도구는 이 축의 확장선에 있다.

### 3-5. 월드 오브젝트, 셀, 스퀘어, 환경 시스템

Official primary:

- `zombie.iso`는 월드 셀, 그리드 스퀘어, moving object, LOS/FOV, world streaming의 핵심이다.
- `zombie.iso.objects`는 창문, 문, 시체, 라디오, 컨테이너, 불, 빗물통 등 월드 배치 객체를 다룬다.
- `zombie.iso.SpriteDetails`, `areas`, `weather`, `erosion`, `randomizedWorld`, `meta`는 월드 규칙과 환경 레이어를 보강한다.
- 대표 클래스:
  - https://projectzomboid.com/modding/zombie/iso/IsoObject.html
  - https://projectzomboid.com/modding/zombie/iso/IsoMovingObject.html
  - https://projectzomboid.com/modding/zombie/iso/objects/IsoDeadBody.html

Official-adjacent:

- `Mapping`, `Tile_properties`, `Adding_new_tiles`, `Room_definitions_and_item_spawns`, `Vehicle_zones`, `map.info`는 월드 레벨 데이터 작성의 실무 입구다.

핵심 정리:

- 게임 월드는 단순히 캐릭터와 아이템만이 아니라, 셀/스퀘어/오브젝트/타일 속성/방 정의/존 데이터가 얽힌 구조다.
- 월드 오브젝트를 다루는 모드는 스크립트 문서와 Javadocs를 함께 봐야 안전하다.

### 3-6. 아이템, 인벤토리, 루트, 스크립트 오브젝트

Official primary:

- `zombie.inventory`와 `zombie.inventory.types`는 아이템 인스턴스와 세부 아이템 타입을 보여 준다.
- `zombie.scripting`과 `zombie.scripting.objects`는 `Item`, `Recipe`, `VehicleScript`, `SoundTimelineScript`, `ModelScript` 같은 텍스트 스크립트 객체를 설명한다.
- `zombie.characters.WornItems`와 시각 계층은 아이템과 캐릭터 착장을 연결한다.

Official-adjacent:

- `Item`, `Scripts`, `Procedural_distributions`, `TimedAction`, `Sandbox_options`는 실제 데이터 저작과 분배 로직 확인에 유용하다.

핵심 정리:

- Build 42 아이템 모딩은 "스크립트 정의 + 런타임 인벤토리 타입 + 분배/루트 + timed action"의 조합으로 봐야 한다.
- 나중에 NPC가 아이템을 입고 들고 떨구고 루팅하게 만들려면 이 네 층을 모두 재방문해야 한다.

### 3-7. 비주얼, 모델, 애니메이션, 의복

Official primary:

- `zombie.core.skinnedmodel`과 `zombie.core.skinnedmodel.visual`은 인간형 비주얼의 핵심 패키지다.
- `ModelManager`, `HumanVisual`, `ItemVisual`, `ItemVisuals`, `ClothingItemReference` 같은 클래스가 보인다.
- `zombie.characters.WornItems`와 결합되어 착장과 모델 갱신 흐름을 이룬다.

Official-adjacent:

- `Modeling`, `Rendering`, `Animation`은 아트 파이프라인과 게임 내 표현 계층을 이어 준다.
- `OnClothingUpdated` 같은 이벤트는 비주얼 갱신 타이밍을 이해할 때 유용하다.

핵심 정리:

- Build 42에서 인간형 비주얼은 모델 매니저, human visual, item visual, worn items가 함께 움직이는 구조다.
- 외형/착장/코스메틱은 캐릭터 로직과 완전히 분리된 계층이 아니며, 캐릭터 라이프사이클과 맞물린다.

### 3-8. 오디오, 라디오, 사운드 타임라인

Official primary:

- `zombie.audio` 패키지는 사운드 emitters, banks, parameters, runtime sound hooks를 노출한다.
- `zombie.radio` 패키지는 라디오/방송/미디어/대사와 엮이는 계층을 보여 준다.
- `zombie.scripting.objects` 안의 사운드 스크립트 객체도 이 축에 걸친다.

Official-adjacent:

- `Sound` 문서는 텍스트 스크립트 단위의 사운드 정의를 이해하는 진입점이다.
- 이벤트 카탈로그에는 사운드 뱅크 초기화나 라디오 스크립트 초기화와 관련된 훅들이 보인다.

시사점:

- 지금 LWN이 오디오를 깊게 쓰지 않더라도, 나중에 NPC 보이스/큐/라디오 스토리 연동을 넣으려면 이 패키지 묶음을 다시 봐야 한다.

### 3-9. 맵, 타일, 지역 데이터, 월드 제작 도구

Official primary:

- `zombie.worldMap` 패키지는 월드맵 렌더링과 메타 데이터 접근의 공식 표면이다.
- `zombie.iso`, `meta`, `areas`, `randomizedWorld`도 맵/지역 로직과 맞닿아 있다.

Official-adjacent:

- `Mapping` 허브는 TileZed, WorldEd, 번들 맵 문서, 타일 속성, 방 정의, 차량 존 문서를 묶어 준다.
- `map.info`는 맵 메타데이터와 로딩 경계를 이해하는 데 중요하다.

핵심 정리:

- Build 42 모딩에서 맵/타일은 별도 분야처럼 보이지만, 실제로는 아이템 스폰, 이벤트 조건, 차량 존, 스토리 포인트와 연결된다.
- LWN처럼 오프스크린 NPC를 월드 데이터 위에 얹는 모드는 맵 메타와 방/존 데이터 이해가 장기적으로 중요하다.

### 3-10. 스토리, 데이터, 글로벌 상태, 퍼시스턴스

Official primary:

- `zombie.world.moddata`는 월드 레벨 ModData 저장 계층이다.
- `zombie.savefile`은 저장 시스템과 저장 관련 클래스 표면을 노출한다.
- `zombie.globalObjects`, `zombie.randomizedWorld`, `zombie.radio`, `zombie.text.templating`는 세계 상태, 스토리 데이터, 텍스트 생성과 맞물린다.

Official-adjacent:

- `ModData`/`GlobalModData` 관련 이벤트 문맥은 PZwiki 이벤트 문서에서 추적하기 쉽다.
- `PersistentOutfitID`는 영속적 외형 식별과 관련된 보조 문서로 볼 가치가 있다.

핵심 정리:

- Build 42에서 persistence는 단순 세이브 파일 한 덩어리가 아니라 world mod data, save classes, global object state, randomized data가 함께 구성하는 층이다.
- LWN의 "canonical NPC state lives in ModData" 가정은 이 축과 잘 맞지만, 나중에 외형/죽음/월드 흔적을 더 남기려면 save/corpse/global-object 층도 함께 고려해야 한다.

### 3-11. 좀비, 사망, 시체, 리애니메이션

Official primary:

- `IsoZombie`, `IsoGameCharacter`, `IsoDeadBody` 조합이 핵심 축이다.
- `IsoGameCharacter`에는 죽음/시체화 관련 메서드가 존재하며, `IsoDeadBody`는 시체 객체의 별도 라이프사이클을 가진다.

Official-adjacent:

- `OnZombieCreate`, `OnZombieDead`, `OnDeadBodySpawn` 문서는 생성-죽음-시체 생성이 한 단계로 끝나지 않음을 보여 준다.
- Build 42 위키 문서는 좀비 오브젝트 풀링과 인스턴스 재사용을 경고한다.

핵심 정리:

- Build 42에서 좀비와 시체는 분리된 객체 층으로 이해해야 한다.
- 오브젝트 풀링 경고 때문에 "Lua 참조 하나 = 영속 개체 하나"라고 가정하면 쉽게 틀린다.

### 3-12. 네트워킹과 멀티플레이어

Official primary:

- `zombie.network`와 `zombie.spnetwork`는 네트워크 계층을 드러낸다.
- The Indie Stone 공식 포럼의 MP 변경 가이드는 Build 41 방식에서 42로 넘어올 때의 네트워크 적응 지점을 알려 준다.

Official-adjacent:

- `Networking`, `Testing mods in multiplayer`는 MP 관련 개념과 테스트 절차를 정리해 준다.

핵심 정리:

- 이번 프로젝트는 SP 모드이지만, 공식 문서 지형도 차원에서는 MP 계층을 알고 있어야 한다.
- 특히 Build 42는 B41과 모드/세이브 호환 단절이 명시되어 있으므로, MP 정보도 B41 습관을 그대로 가져오면 안 된다.

## 4. Build 42 문서에서 드러나는 메타 패턴

- JavaDocs는 폭넓지만, Lua 이벤트/콜백 설명은 빈약하다.
- PZwiki는 이벤트와 콘텐츠 포맷을 잘 연결하지만, API 존재성의 최종 근거는 아니다.
- 공식 블로그/포럼은 Build 전환기 주의사항과 지원 범위의 뉘앙스를 알려 준다.
- 따라서 Build 42 모딩 판단 순서는 아래가 안전하다.
  - 1차: 공식 JavaDocs와 공식 공지에서 지원 범위를 확인
  - 2차: PZwiki에서 이벤트 시그니처와 데이터 포맷을 연결
  - 3차: 외부 레퍼런스는 도구/언어/보조 예시로만 사용

## 5. LWN에 직접 시사점이 있는 항목

이번 턴의 목적은 전체 학습이지만, LWN과 바로 이어지는 함의는 따로 적는다.

- `ModData` 중심 canonical state 전략은 Build 42 persistence 축과 대체로 잘 맞는다.
- 인간형 NPC는 Build 42에서 공식 클래스 표면은 보이지만, 공식 블로그 문맥상 정식 안정 NPC 프레임워크로 단정하면 위험하다.
- 착장/외형은 `SurvivorDesc`, `WornItems`, `HumanVisual`, `ModelManager`를 함께 보는 편이 안전하다.
- 월드 흔적을 더 남기려면 `IsoObject`/`IsoMovingObject`뿐 아니라 `IsoDeadBody`, `randomizedWorld`, `globalObjects`, `savefile` 축까지 함께 봐야 한다.
- 오프스크린 NPC와 월드 상호작용을 늘릴수록 `map.info`, room definitions, vehicle zones, world map/meta 계층의 중요도가 커진다.
- 지금은 SP 전용이더라도, MP 문서 축을 미리 알아 두면 나중에 "이건 SP 전용 설계로 안전한가?"를 판별하기 쉬워진다.

## 6. 후속 탐색 우선순위 제안

전체 지형도를 확보한 뒤, 다음에 깊게 파면 좋은 축:

1. `zombie.world.moddata`, `zombie.savefile`, `zombie.globalObjects`의 저장 계층 비교
2. `zombie.ui`, 이벤트 카탈로그, 기존 UI 객체 관례를 묶은 Build 42 UI 모딩 정리
3. 맵/타일/방 정의/존 데이터를 LWN 오프스크린 시뮬레이션과 연결하는 연구
4. 사운드/라디오/텍스트 템플릿을 NPC 상호작용 데이터와 연결하는 연구

