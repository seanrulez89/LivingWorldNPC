# Build 42 Modding Source Register 2026-03-12

Purpose: 이번 턴에 따라간 문서들을 "무엇이 공식 근거인지 / 무엇이 보조 참고인지" 기준으로 빠르게 다시 찾기 위한 레지스터.

## 1. 분류 기준

- Official primary
  - The Indie Stone가 직접 운영하는 문서/블로그/포럼
  - API 존재성, 클래스/메서드 표면, 빌드 전환 공지의 최종 근거
- Official-adjacent / community curated
  - PZwiki 문서
  - 이벤트, 포맷, 모드 구조, 맵/타일 실무에 특히 강함
  - 단, 메서드 존재성은 공식 JavaDocs로 재확인 권장
- Supplemental external
  - PZwiki가 연결하는 외부 도구/언어/커뮤니티 문서
  - 도구 사용법이나 일반 개념 학습에는 좋지만, PZ Build 42 API의 공식 근거는 아님

## 2. Official Primary

### 2-1. 공식 API 인덱스

- Official primary
- 용도: Build 42 전체 Java 패키지 지도를 잡는 최상위 출발점
- URL: https://projectzomboid.com/modding/index.html

### 2-2. 대표 패키지 묶음

- Official primary
- 용도: 인간형 캐릭터, 좀비, 상태, 스킬, 착장
- URL: https://projectzomboid.com/modding/zombie/characters/package-summary.html

- Official primary
- 용도: UI/HUD/패널/입력 상호작용
- URL: https://projectzomboid.com/modding/zombie/ui/package-summary.html

- Official primary
- 용도: 셀, 스퀘어, moving object, 월드 핵심 구조
- URL: https://projectzomboid.com/modding/zombie/iso/package-summary.html

- Official primary
- 용도: 시체, 문, 창, 컨테이너 등 월드 오브젝트
- URL: https://projectzomboid.com/modding/zombie/iso/objects/package-summary.html

- Official primary
- 용도: 인벤토리와 아이템 인스턴스
- URL: https://projectzomboid.com/modding/zombie/inventory/package-summary.html

- Official primary
- 용도: 무기, 음식, 의류, 컨테이너 등 구체 아이템 타입
- URL: https://projectzomboid.com/modding/zombie/inventory/types/package-summary.html

- Official primary
- 용도: 모델/렌더/스킨드 모델 계층
- URL: https://projectzomboid.com/modding/zombie/core/skinnedmodel/package-summary.html

- Official primary
- 용도: `HumanVisual`, `ItemVisual`, 외형 표현
- URL: https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/package-summary.html

- Official primary
- 용도: 사운드 런타임 계층
- URL: https://projectzomboid.com/modding/zombie/audio/package-summary.html

- Official primary
- 용도: 라디오/미디어/방송 시스템
- URL: https://projectzomboid.com/modding/zombie/radio/package-summary.html

- Official primary
- 용도: 텍스트 스크립트 로더와 스크립트 객체
- URL: https://projectzomboid.com/modding/zombie/scripting/package-summary.html

- Official primary
- 용도: `Item`, `Recipe`, `VehicleScript`, `ModelScript`, `SoundTimelineScript`
- URL: https://projectzomboid.com/modding/zombie/scripting/objects/package-summary.html

- Official primary
- 용도: world-level persistent state helpers
- URL: https://projectzomboid.com/modding/zombie/globalObjects/package-summary.html

- Official primary
- 용도: 월드맵 표시와 메타 데이터
- URL: https://projectzomboid.com/modding/zombie/worldMap/package-summary.html

- Official primary
- 용도: world mod data persistence
- URL: https://projectzomboid.com/modding/zombie/world/moddata/package-summary.html

- Official primary
- 용도: 저장 파일 레이어
- URL: https://projectzomboid.com/modding/zombie/savefile/package-summary.html

- Official primary
- 용도: 멀티플레이 네트워크 계층
- URL: https://projectzomboid.com/modding/zombie/network/package-summary.html

- Official primary
- 용도: 싱글플레이 쪽 네트워크 관련 표면
- URL: https://projectzomboid.com/modding/zombie/spnetwork/package-summary.html

### 2-3. 대표 클래스 페이지

- Official primary
- 용도: 인간형 플레이어 캐릭터 생성/상태
- URL: https://projectzomboid.com/modding/zombie/characters/IsoPlayer.html

- Official primary
- 용도: 생존자 클래스와 survivor 전용 라이프사이클
- URL: https://projectzomboid.com/modding/zombie/characters/IsoSurvivor.html

- Official primary
- 용도: 좀비 개체와 Build 42 object lifecycle 해석의 기준점
- URL: https://projectzomboid.com/modding/zombie/characters/IsoZombie.html

- Official primary
- 용도: 인간형 descriptor, 외형/착장 준비
- URL: https://projectzomboid.com/modding/zombie/characters/SurvivorDesc.html

- Official primary
- 용도: 공통 캐릭터 능력, 죽음/시체화/외형/착장 관련 상위 표면
- URL: https://projectzomboid.com/modding/zombie/characters/IsoGameCharacter.html

- Official primary
- 용도: 모델 갱신과 캐릭터 렌더 캐시 관리
- URL: https://projectzomboid.com/modding/zombie/core/skinnedmodel/ModelManager.html

- Official primary
- 용도: 인간형 외형 데이터 표면
- URL: https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/HumanVisual.html

- Official primary
- 용도: 아이템 비주얼 브리지
- URL: https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/ItemVisual.html

- Official primary
- 용도: 시체 객체, 외형, 리애니메이션
- URL: https://projectzomboid.com/modding/zombie/iso/objects/IsoDeadBody.html

- Official primary
- 용도: 월드 오브젝트 공통 라이프사이클
- URL: https://projectzomboid.com/modding/zombie/iso/IsoObject.html

- Official primary
- 용도: moving object 라이프사이클
- URL: https://projectzomboid.com/modding/zombie/iso/IsoMovingObject.html

### 2-4. 공식 블로그 / 포럼 / 정책

- Official primary
- 용도: Build 42 unstable 전환 주의사항, B41 호환 단절 확인
- URL: https://projectzomboid.com/blog/news/2024/11/build-42-unstable/

- Official primary
- 용도: 인간형 NPC 방향성의 공식 문맥 확인
- URL: https://projectzomboid.com/blog/news/2025/09/terminally-illinois/

- Official primary
- 용도: B41 MP 변경을 B42에 적용하는 공식 포럼 가이드
- URL: https://theindiestone.com/forums/index.php?/topic/82717-applying-41-mp-server-changes-to-42/

## 3. Official-Adjacent / Community Curated

### 3-1. 허브와 인덱스

- Official-adjacent
- 용도: 모딩 전체 허브
- URL: https://pzwiki.net/wiki/Modding

- Official-adjacent
- 용도: Lua 이벤트 인덱스
- URL: https://pzwiki.net/wiki/Lua_event

- Official-adjacent
- 용도: 현재 Lua 이벤트 카테고리
- URL: https://pzwiki.net/wiki/Category:Current_Lua_events

- Official-adjacent
- 용도: Lua 객체와 Java 객체를 잇는 브리지
- URL: https://pzwiki.net/wiki/Lua_object

- Official-adjacent
- 용도: Java 객체 목록과 공식 JavaDocs로 향하는 안내
- URL: https://pzwiki.net/wiki/Java_object

- Official-adjacent
- 용도: 공식 JavaDocs 사용 가이드
- URL: https://pzwiki.net/wiki/JavaDocs

### 3-2. 구조 / 파일 / 디버그 / 성능

- Official-adjacent
- 용도: 모드 폴더 구조
- URL: https://pzwiki.net/wiki/Mod_structure

- Official-adjacent
- 용도: 게임 파일 위치와 디렉터리 이해
- URL: https://pzwiki.net/wiki/Game_files

- Official-adjacent
- 용도: 데이터 파일 포맷 인덱스
- URL: https://pzwiki.net/wiki/File_formats

- Official-adjacent
- 용도: 디버그 모드 기능 개요
- URL: https://pzwiki.net/wiki/Debug_mode

- Official-adjacent
- 용도: 시작 파라미터
- URL: https://pzwiki.net/wiki/Startup_parameters

- Official-adjacent
- 용도: 모드 최적화 팁
- URL: https://pzwiki.net/wiki/Mod_optimization

- Official-adjacent
- 용도: 원격 디버깅 워크플로
- URL: https://pzwiki.net/wiki/Remote_debugging

- Official-adjacent
- 용도: 역공학 워크플로와 한계
- URL: https://pzwiki.net/wiki/Decompiling_game_code

### 3-3. 데이터 / 스크립트 / 콘텐츠 작성

- Official-adjacent
- 용도: 텍스트 스크립트 개요
- URL: https://pzwiki.net/wiki/Scripts

- Official-adjacent
- 용도: 분배 테이블/루트 계층
- URL: https://pzwiki.net/wiki/Procedural_distributions

- Official-adjacent
- 용도: 아이템 스크립트
- URL: https://pzwiki.net/wiki/Item

- Official-adjacent
- 용도: 차량 스크립트
- URL: https://pzwiki.net/wiki/Vehicle

- Official-adjacent
- 용도: 사운드 스크립트
- URL: https://pzwiki.net/wiki/Sound

- Official-adjacent
- 용도: 샌드박스 옵션 정의
- URL: https://pzwiki.net/wiki/Sandbox_options

- Official-adjacent
- 용도: timed action 스크립트/런타임 이해
- URL: https://pzwiki.net/wiki/TimedAction

### 3-4. 비주얼 / 맵 / 타일 / 월드 데이터

- Official-adjacent
- 용도: 모델링 파이프라인
- URL: https://pzwiki.net/wiki/Modeling

- Official-adjacent
- 용도: 렌더링 파이프라인
- URL: https://pzwiki.net/wiki/Rendering

- Official-adjacent
- 용도: 애니메이션 파이프라인
- URL: https://pzwiki.net/wiki/Animation

- Official-adjacent
- 용도: 맵 제작 허브
- URL: https://pzwiki.net/wiki/Mapping

- Official-adjacent
- 용도: 맵 메타 데이터 파일
- URL: https://pzwiki.net/wiki/map.info

- Official-adjacent
- 용도: 새 타일 추가
- URL: https://pzwiki.net/wiki/Adding_new_tiles

- Official-adjacent
- 용도: 타일 속성
- URL: https://pzwiki.net/wiki/Tile_properties

- Official-adjacent
- 용도: 방 정의와 아이템 스폰
- URL: https://pzwiki.net/wiki/Room_definitions_and_item_spawns

- Official-adjacent
- 용도: 차량 존 데이터
- URL: https://pzwiki.net/wiki/Vehicle_zones

### 3-5. 이벤트 예시와 주제별 페이지

- Official-adjacent
- 용도: 인간형 생성 공통 훅
- URL: https://pzwiki.net/wiki/OnCreateLivingCharacter

- Official-adjacent
- 용도: survivor 생성 훅
- URL: https://pzwiki.net/wiki/OnCreateSurvivor

- Official-adjacent
- 용도: 좀비 생성 훅과 풀링 경고
- URL: https://pzwiki.net/wiki/OnZombieCreate

- Official-adjacent
- 용도: 좀비 사망 훅
- URL: https://pzwiki.net/wiki/OnZombieDead

- Official-adjacent
- 용도: 시체 생성 훅
- URL: https://pzwiki.net/wiki/OnDeadBodySpawn

- Official-adjacent
- 용도: 착장 갱신 훅
- URL: https://pzwiki.net/wiki/OnClothingUpdated

- Official-adjacent
- 용도: 좀비 클래스 보조 설명
- URL: https://pzwiki.net/wiki/IsoZombie

### 3-6. 저장 / 네트워킹 / MP 실무

- Official-adjacent
- 용도: 네트워킹 개요
- URL: https://pzwiki.net/wiki/Networking

- Official-adjacent
- 용도: 멀티플레이 테스트 절차
- URL: https://pzwiki.net/wiki/Testing_mods_in_multiplayer

- Official-adjacent
- 용도: persistent outfit 식별자 개념
- URL: https://pzwiki.net/wiki/PersistentOutfitID

## 4. Supplemental External

이번 턴에 확인한 PZwiki 연결 외부 페이지는 성격상 세 부류로 나뉜다.

### 4-1. 공식이지만 API 1차 문서는 아닌 외부

- Official external
- 성격: `projectzomboid.com` 블로그, The Indie Stone 포럼
- 용도: 빌드 전환 공지, 정책, MP 변경 가이드
- 판정: 공식성은 높지만, 클래스/메서드 시그니처의 1차 근거는 여전히 JavaDocs

### 4-2. 일반 기술 문서

- Supplemental external
- 성격: Lua 언어 문서, Java/Javadoc 참고, IDE 디버거 문서
- 용도: Lua 5.1 문법, 원격 디버깅 설정, 일반 Java 문서 이해
- 판정: 도구와 언어 이해에는 유용하나, PZ-specific 판단 근거로 직접 쓰면 안 됨

### 4-3. 커뮤니티 생성 참고 자료

- Supplemental external
- 성격: 비공식 Lua docs mirror, stubs, 디컴파일러/커뮤니티 튜토리얼, 일부 외부 도구 페이지
- 용도: 탐색 속도 향상, 예시 확보, 워크플로 보조
- 판정: 생산성에는 도움이 되지만 공식성은 낮다. Build 42 API 판단은 반드시 공식 JavaDocs/공식 공지로 역검증 필요

## 5. 실무용 사용 규칙

- API가 "존재하는가"를 판단할 때는 공식 JavaDocs를 먼저 본다.
- 이벤트 시그니처, 텍스트 스크립트 포맷, 맵/타일 저작법은 PZwiki를 먼저 보고 나서 공식 표면과 맞춘다.
- 블로그/포럼은 지원 범위와 빌드 간 변화의 맥락을 판단할 때 사용한다.
- 외부 링크는 도구/언어/실무 편의 자료로만 쓰고, 엔진 사실성의 최종 근거로 쓰지 않는다.

