# LivingWorldNPC SP — Local Testing & Debug Guide

## 1. 목적
이 문서는 Steam 창작마당에 올리기 전에 **로컬 환경에서 Build 42 싱글플레이 모드**를 반복 테스트하기 위한 절차와, 인게임에서 주요 기능을 검증하기 위한 디버그 루틴을 정리한다.

## 2. 로컬 설치 형태
Project Zomboid Build 42는 버전 디렉터리(`42/`)를 기준으로 모드를 읽는다. 이 폴더를 `Zomboid/mods` 아래에 로컬 모드로 배치해서 테스트한다.

권장 구조:

```text
%USERPROFILE%\Zomboid\mods\LivingWorldNPCSP\
  common\
  42\
    mod.info
    media\lua\shared\...
    media\lua\client\...
```

## 3. 빠른 테스트 절차 (Windows)
1. Steam을 종료한다.
2. `C:\Users\<사용자명>\Zomboid\mods\` 아래에 `LivingWorldNPCSP` 폴더를 복사한다.
3. Steam 실행 → Project Zomboid 실행.
4. 메인 메뉴의 **Mods** 또는 Build 42의 공식 모드 매니저에서 `LivingWorldNPCSP`를 활성화한다.
5. 새 샌드박스 저장을 만든다. (기존 저장과 분리)

## 4. 권장 시작 옵션
로컬 개발 때는 Steam Launch Options에 아래 둘 중 하나를 사용한다.

- `-debug`
- `-debug -cachedir=C:\ZomboidDev\LWN_SP`

두 번째 옵션은 개발용 캐시/세이브/로그를 일반 플레이 데이터와 분리할 때 유용하다.

## 5. 로그 확인 위치
- 일반 런타임 오류: `C:\Users\<사용자명>\Zomboid\console.txt`
- 압축 로그 묶음: `C:\Users\<사용자명>\Zomboid\logs.zip`
- JVM 크래시: `Steam\steamapps\common\ProjectZomboid\hs_err_pid*.log`

### 5.1 투명 NPC 추적 로그
- 개발/디버그 모드에서는 `console.txt`에서 `[LWN][EmbodimentTrace]`를 검색한다.
- 같은 NPC 흐름은 `npcId=... | stage=...` 조합으로 본다.
- 생성 경로는 `module=ActorFactory`, 상태 전이는 `module=EmbodimentManager`, 엔진 이벤트 재연결/유실은 `module=EventAdapter`를 우선 본다.
- 외형 문제는 `humanVisual=`, `skin=`, `hair=`, `beard=`, `itemVisuals=`, `wornItems=`, `persistentOutfitId=` 값을 stage 사이에서 비교한다.
- Stage 3 최소 패치에서는 `stage=refreshEmbodiedPresentation.item_visual_bridge`를 추가로 본다.
- 이 stage의 핵심 detail 필드:
  - `mode=rebuilt_from_worn_items`면 worn clothing에서 item visual 재구성을 시도한 것
  - `itemVisualsBefore=0` / `itemVisualsAfter>0`면 이번 가설이 맞을 가능성이 올라감
  - `mode=item_visuals_present`면 이번 패치는 실질적으로 개입하지 않은 것

## 6. 반드시 넣어야 할 디버그 훅
### 6.1 강제 인카운터
- 플레이어 근처에 eligible NPC를 즉시 staged/embodied로 승격
- 랜덤 조우를 기다리지 않고 첫 조우 흐름 검증 가능

### 6.1.1 현재 구현된 우클릭 디버그 메뉴
- `LWN Settings`에서 디버그를 켠 뒤 월드 우클릭
- `Debug: Spawn NPC Near Player`
- `Debug: Delete Nearest NPC`
- `Debug: Dump Last Actor Failure`
- `Debug: Dump Nearest NPC Summary`
- `Debug: Wipe Data + Reseed`
- `Debug: Boost Nearest NPC Trust`
- `Debug: Shared Food Beat (Nearest)`
- `Debug: Force Legacy Candidate (Nearest)`

이 메뉴는 실체화된 NPC의 생성/삭제/최근 실패 원인 확인을 인게임에서 바로 수행하기 위한 개발용 도구다.
`Debug: Spawn NPC Near Player`는 `MaxEmbodied` 한도에 걸리면 가장 멀리 있는 기존 디버그 NPC를 정리해 새 스폰 슬롯을 확보한다.

### 6.2 최근접 NPC 덤프
- F5 또는 `Debug: Dump Nearest NPC Summary`
- nearest NPC id
- 장기 목표
- 현재 action intent / action queue
- 관계값(trust/respect/fear/resentment/loyaltyShift)
- actor world/ghost/invisible/culled 좌표

### 6.3 전체 데이터 초기화
- F6 또는 `Debug: Wipe Data + Reseed`
- 내부적으로 embodied actor cleanup 후 root를 reset하고 현재 세이브에 다시 시드
- 새 게임을 만들지 않고도 reseed를 확인 가능

### 6.4 관계값 증감 치트
- F7은 현재 nearest NPC의 trust를 +0.20 올린다
- 우클릭 메뉴에는 `Boost Nearest NPC Trust`가 있다
- 향후 fear / resentment / loyaltyShift 개별 치트는 같은 디버그 계열에 추가 가능

### 6.5 story/drama 강제 트리거
- 현재 구현:
  - `shared_food`
  - `rescued_me`
  - `promise_broken`
  - `theft_suspected`
  - `jealousy`
- 우클릭 메뉴에서 `Shared Food Beat (Nearest)`를 즉시 호출 가능

### 6.6 레거시 강제 테스트
- F8 또는 `Debug: Force Legacy Candidate (Nearest)`
- 현재 nearest NPC를 recruited + trust floor 충족 상태로 만들어 candidate에 넣음

## 7. 추천 핫키
- F3: 디버그 패널 토글
- F4: 강제 인카운터
- F5: 최근접 NPC 덤프
- F6: LWN_SP 데이터 초기화
- F7: 최근접 NPC trust +0.20
- F8: 최근접 NPC를 legacy candidate로 강제 지정

## 8. 테스트 시나리오 체크리스트
### A. 모드 로딩
- [ ] Mods 목록에 보이는가
- [ ] 활성화 후 게임이 정상 진입하는가
- [ ] `console.txt` 상단에 `[LWN] Bootstrap started`가 찍히는가

### B. 인구 시드
- [ ] 새 게임 시작 직후 `root.seeded == true`
- [ ] 숨겨진 NPC 레코드가 생성됐는가
- [ ] 시작 직후는 embodied NPC 수가 0인가

### C. 첫 조우
- [ ] 랜덤 또는 강제 인카운터로 NPC가 등장하는가
- [ ] 실체화 위치가 플레이어 시야에 자연스러운가
- [ ] 실제 월드에 보이는 인간형 actor(`IsoPlayer` 기반)가 생성되는가
- [ ] `actor visuals` 로그에 `skin`, `itemVisuals`, `wornItems`가 합리적으로 채워지는가
- [ ] `refreshEmbodiedPresentation.item_visual_bridge`에서 `wornItems`와 `itemVisualsBefore/After` 변화가 가설과 맞는가
- [ ] 대사 1줄과 관계 초기화가 정상인가

### D. 화면 밖 비실체화
- [ ] 일정 거리 이상 멀어지면 actor가 사라지는가
- [ ] canonical record는 유지되는가
- [ ] 다시 접근하면 같은 NPC가 다시 실체화되는가
- [ ] 동료/디버그 spawn NPC는 짧은 cooldown 뒤 자동으로 재실체화 가능한가

### E. 명령/협상
- [ ] Follow / Wait / Guard / Attack / Retreat / Talk가 동작하는가
- [ ] 수락 / 거절 / 역제안이 상태와 관계에 따라 달라지는가
- [ ] 패널의 상태 요약이 갱신되는가

### F. 기억/드라마
- [ ] food sharing 후 trust 증가
- [ ] 방치 후 resentment 증가
- [ ] 반복 상호작용 후 personal story가 열리는가

### G. 레거시
- [ ] 플레이어 사망 시 candidate 목록이 뜨는가
- [ ] 선택한 동료의 snapshot이 저장되는가
- [ ] 다음 플레이 시작에 profession/traits/perks 일부가 반영되는가

## 9. 우선순위별 테스트 순서
1. 로딩 / ModData 생성
2. Population seeding
3. Encounter director
4. Embodiment / despawn loop
5. Command UI / radial menu
6. Goal + utility + BT
7. social + memory + drama
8. legacy continuation

## 10. 주의
- 개발 중에는 기존 저장을 계속 재사용하지 말고 `-cachedir`로 별도 개발 프로필을 두는 편이 좋다.
- 한 번에 여러 기능을 붙이지 말고, 위 우선순위 순서로 기능을 잠그면서 테스트한다.
- 실체화 실패가 보이면 `console.txt`에서 `[LWN][ActorFactory] failure record`, `failure actor`, `failure descriptor` 세 줄을 먼저 확인한다.
- NPC가 보이지 않으면 같은 구간의 `created embodied npc` 직후 아래 두 줄을 함께 확인한다.
  - `actor state`: `ghost`, `invisible`, `sceneCulled`, `alpha`, `targetAlpha`
  - `actor visuals`: `skin`, `hair`, `beard`, `itemVisuals`, `wornItems`, `persistentOutfitId`
