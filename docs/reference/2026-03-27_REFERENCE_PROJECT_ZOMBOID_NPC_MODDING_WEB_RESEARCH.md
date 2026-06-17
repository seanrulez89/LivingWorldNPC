# Project Zomboid NPC Modding Web Research — 2026-03-27

## 목적

이 문서는 2026-03-27 기준으로 웹에서 다시 조사한 **Project Zomboid 모딩 / 특히 NPC 모드 개발** 관련 자료를 폭넓게 정리한 메모다.

목표는 다음 3가지다.

1. Build 42/43 기준 공식 방향과 한계를 다시 확인한다.
2. NPC 모드 개발에 실제로 도움이 되는 자료 축을 정리한다.
3. `LivingWorldNPC` 같은 프로젝트에서 바로 써먹을 수 있는 실전 시사점을 남긴다.

---

## 핵심 요약

### 1. 공식 인간 NPC는 아직 Build 42의 기본 제공 기능이 아니다

- Project Zomboid 공식 블로그 `2022 and Beyond`에서 개발팀은 **인간 NPC는 기술적으로 Build 43** 쪽이라고 명시했다.
- 같은 글에서 개발팀은 NPC 기술이 장기간 준비돼 왔고, 이를 바탕으로 동물/사냥 같은 비인간 NPC 기술도 얹힌다고 설명했다.
- 즉 Build 42의 모더들은 **완성된 공식 인간 NPC API를 받았다기보다**, 점진적으로 드러나는 엔진 능력·애니메이션·월드 시스템 위에 우회 구현을 얹는 상황에 가깝다.

### 2. Build 42는 NPC 모드에 오히려 좋은 기반을 준다

공식 `Upcoming Features: B42`와 관련 자료를 보면 Build 42는:

- 더 깊어진 월드/층 구조
- 개선된 렌더링/깊이 처리
- 신규 제작 시스템
- 동물/비인간 AI 기반
- 장기 월드 운영을 위한 구조
- 모더 친화적 시스템 확장

을 목표로 한다.

즉 **공식 인간 NPC가 아직 없어도**, NPC 모드는 다음 기반을 활용해 점점 더 강해질 수 있다.

- 행동 루프를 유지할 수 있는 업데이트 훅
- 렌더/애니메이션/비주얼 재적용
- 사운드/월드 인터랙션 제어
- Build 42 멀티플레이 대응 구조

### 3. 실제 NPC 모드 개발은 “AI 구현”보다 “엔진과의 계약 관리”에 더 가깝다

이번 웹 조사의 가장 중요한 결론은 이거다.

NPC 모드는 단순히:

- path를 주고
- 행동을 넣고
- 외형을 입히는 문제

가 아니라,

- 어떤 엔진 클래스(`IsoZombie`, `IsoPlayer`, `IsoGameCharacter`)를 빌릴지
- 어떤 이벤트에서 상태를 다시 찍어눌러야 할지
- 애니메이션/오디오/전투 intent를 얼마나 지속적으로 억제할지
- 싱글/멀티에서 authority를 어떻게 나눌지
- recovery / relink / duplicate 방지를 어떻게 할지

를 설계하는 **지속적인 상태 관리 문제**다.

이건 현재 `LivingWorldNPC`가 겪는 문제와도 정확히 맞닿아 있다.

---

## 조사한 자료 축

### 1. 공식 / 준공식 축

- Project Zomboid 공식 블로그
- Project Zomboid 공식 modding JavaDoc 페이지
- The Indie Stone 포럼의 Build 42 migration / MP 관련 공지
- PZwiki 모딩 문서

### 2. 커뮤니티 레퍼런스 축

- `FWolfe/Zomboid-Modding-Guide`
- `cocolabs/pz-modding-guide`
- `JBD-Mods/awesome-project-zomboid-build42-resources`

### 3. NPC 모드 생태계 관찰 축

- Build 42에서 언급되는 대표 NPC 계열 모드들
  - Bandits
  - Week One NPC
  - Superb Survivors 계열
- Steam / Reddit / 커뮤니티 글에서 확인되는 현실적 반응
  - Build 42에서 NPC 모드는 존재하지만 안정성 이슈가 큼
  - 싱글/멀티 지원 상태가 제각각
  - 업데이트 추종 비용이 큼

---

## 공식 방향에서 읽히는 것

### 1. 인간 NPC는 여전히 “공식 완성 기능”이 아니라 “진행 중 목표”다

공식 블로그 `2022 and Beyond`의 핵심 포인트:

- 개발팀은 NPC 전담 팀을 둔다고 설명했다.
- 하지만 **인간 NPC는 기술적으로 Build 43**로 분류했다.
- 동시에 동물/사냥 등도 넓게 보면 NPC 기술의 일부라고 설명했다.

이게 모더 관점에서 뜻하는 바:

- Build 42에서 인간 NPC 모드는 **정식 인간 NPC 시스템 위 확장**이 아니라,
- **현재 노출된 캐릭터/AI/애니메이션/월드 기능을 조합한 우회 구현**일 가능성이 높다.

즉, 현재 NPC 모드의 불안정성은 “모드가 못나서”라기보다,
**아직 공식 인간 NPC 레이어가 완성되지 않은 엔진 공간을 모더가 메우고 있기 때문**으로 보는 게 맞다.

### 2. Build 42는 모더에게 “완제품”보다 “재료”를 더 많이 준다

`Upcoming Features: B42`에서 드러나는 방향은:

- 더 큰 구조물 / 지하 / 고층 월드
- 고도화된 제작 시스템
- 장기 플레이 기반
- 동물 AI
- 모더 친화적 프레임워크 확장

중요한 해석:

- Build 42는 인간 NPC를 바로 주지는 않지만,
- **향후 NPC/커뮤니티 시스템이 얹힐 수 있는 세계와 상호작용 기반**을 넓힌다.
- 따라서 NPC 모더는 단순히 “사람 하나 걷게 만들기”보다,
  **월드 안에서 오래 유지되는 행위자**를 만드는 쪽으로 사고해야 한다.

---

## 모딩 자료에서 읽히는 개발 원칙

### 1. Lua가 주 무대고, Java는 읽는 대상에 가깝다

`FWolfe/Zomboid-Modding-Guide`와 PZwiki 자료 공통 요지:

- PZ는 Java + Lua 이중 구조다.
- 실제 모딩은 대부분 **Lua**에서 이루어진다.
- Java를 직접 수정하는 건 가능하지만 일반 배포형 모드 기준으로는 비주류다.
- 대신 Java를 **읽고 이해하는 것**은 매우 중요하다.

NPC 모드에선 이게 특히 중요하다.

왜냐하면 NPC 모드는:

- 행동 상태
- pathfinding
- 캐릭터 클래스 차이
- 이벤트 진입점
- 오디오/애니메이션/비주얼 반영

같은 엔진 내부 동작을 자주 건드리기 때문이다.

즉:

- 구현은 Lua에서 하되,
- 판단 근거는 JavaDocs / decompile / vanilla Lua에서 얻는 방식이 맞다.

### 2. 이벤트 기반 구조를 중심으로 설계해야 한다

여러 가이드가 공통으로 강조하는 부분:

- PZ Lua는 **event/callback 중심**이다.
- 대부분의 로직은 지속 polling보다,
  특정 이벤트와 update loop에 걸어두는 식으로 작동한다.

NPC 모드에 주는 의미:

- spawn 시 1회 세팅만으로는 부족하다.
- `OnTick`, `OnPlayerUpdate`, `OnZombieUpdate`, custom runtime update 같은
  **반복 재확인 지점**이 사실상 필수다.
- 특히 엔진이 native state를 다시 덮어쓰는 영역은
  “한 번 세팅”보다 “지속 재강제”가 중요하다.

이건 현재 `LivingWorldNPC`에서 확인된 문제와 정확히 맞는다.

- walkType이 한번만 맞고 다시 흐트러짐
- target/combat state가 재오염됨
- recovery 후 shell identity가 갈라짐

이런 건 전부 event/update 설계 문제에 가깝다.

### 3. shared / client / server 구분은 NPC 모드에서 특히 중요하다

구조 문서와 가이드 공통 포인트:

- `media/lua/shared` — 공통 데이터 / 계약 / 상수 / 공용 로직
- `media/lua/client` — UI, context menu, local presentation, local actions
- `media/lua/server` — 서버 권한 로직, 스폰, 월드 상태, MP authoritative 처리

NPC 모드에선 자주 생기는 실수가:

- presentation state와 authoritative state를 뒤섞는 것
- 싱글에서는 되는데 MP에서 desync 나는 것
- actor identity를 client-local만 믿는 것

즉 NPC 모드는 일반 QoL 모드보다 더 강하게:

- **record/state는 shared or server authoritative**
- **표현 계층은 client**
- **recovery와 ownership 판단은 더 엄격하게**

가 필요하다.

---

## Build 42 멀티플레이 / 마이그레이션에서 읽히는 것

### 1. Build 42.13 이후에는 모드 호환성이 중요한 별도 과제다

검색 결과와 포럼 migration 자료 요지:

- Build 42.13은 멀티플레이와 함께 **identifier / registry / network compatibility** 쪽 변화가 있었다.
- 모더는 단순히 기능 구현만이 아니라,
  **새 구조에 맞춘 마이그레이션**을 별도로 챙겨야 한다.
- The Indie Stone 포럼에 42.13, 42.15 기준 migration guide가 따로 올라와 있다.

NPC 모드에 주는 시사점:

- NPC 데이터 식별자, registry, spawnable content, translation/resource 등록 같은
  **부수 인프라**가 이전보다 더 중요하다.
- MP 대응을 하려면 state authority, registry consistency, asset registration을
  처음부터 염두에 두고 설계해야 한다.

### 2. “싱글에서 된다”는 NPC 모드 기준으론 절반 성공일 뿐이다

커뮤니티 검색에서 반복적으로 보이는 패턴:

- 어떤 NPC 모드는 SP에서는 어느 정도 동작
- MP에서는 부분 작동 또는 불안정
- Build minor update 하나에도 깨짐

이유는 대체로 다음 축으로 보인다.

- actor ownership
- state replication
- event order 차이
- client presentation vs server truth 불일치
- network-safe하지 않은 local hacks

따라서 NPC 모드를 키울수록 테스트 매트릭스는 최소 이 정도가 필요하다.

1. SP fresh world
2. SP save/load resume
3. MP host
4. MP dedicated or remote client
5. streaming out/in 이후 relink

---

## NPC 모드 개발에 직접 연결되는 실전 포인트

### 1. 캐릭터 클래스 선택은 아키텍처 문제다

이번 조사에서 다시 강하게 확인된 것:

- `IsoZombie`를 사람처럼 쓰는 방식
- `IsoPlayer`를 NPC처럼 쓰는 방식
- 기타 엔진 캐릭터 계층 활용

은 단순 구현 취향이 아니라 **핵심 아키텍처 선택**이다.

#### `IsoZombie`를 빌릴 때 장점

- 기본 이동/월드 존재/갱신 루프가 안정적일 수 있음
- 엔진이 이미 다루는 moving object 흐름 위에 올라갈 수 있음
- zombie update/event 훅을 활용 가능

#### `IsoZombie`를 빌릴 때 비용

- combat intent, 추적 성향, lunge, zombie audio 같은 native behavior 누수
- 인간 presentation을 계속 재주입해야 함
- 살아있는 인간처럼 보이게 만들수록 억제 코드가 늘어남

#### `IsoPlayer`를 빌릴 때 장점

- 인간 presentation / animation / equipment 동작이 더 자연스러울 가능성
- player-like visual pipeline 활용 가능성

#### `IsoPlayer`를 빌릴 때 비용

- NPC로 쓰기엔 ownership / authority / 엔진 기대치가 어긋날 수 있음
- multiplayer, control, embodiment 구성이 더 복잡해질 수 있음

현재 `LivingWorldNPC` 맥락에서 이건 특히 중요하다.

- alive-state human presentation 문제
- actor-class mismatch 의심
- zombie shell은 보이는데 “인간처럼 살아있는 층”이 깨지는 현상

이건 웹 조사 결과와도 잘 맞는다.

즉 앞으로도 **클래스 선택 실험(A/B)** 은 계속 높은 가치가 있다.

### 2. NPC 모드는 “행동 AI”보다 “상태 격리”가 먼저다

실전적으로는 다음이 먼저다.

- 공격 타겟을 안 잡게 하기
- zombie combat state를 누수시키지 않기
- path와 movement authority가 충돌하지 않게 하기
- visual/audio/animation을 엔진 기본값에서 떼어내기

다시 말해,

> ‘생각하는 NPC’를 만들기 전에 ‘엔진 기본 본능이 새지 않는 shell’을 먼저 만들어야 한다.

Bandits 같은 레퍼런스가 강한 이유도 여기에 있다.

- shell 초기화
- zombie 속성 억제
- walkType 유지
- sound suppression
- visual reapply
- identity/cache 관리

즉 좋은 NPC 모드는 생각보다 **AI가 아니라 shell discipline** 비중이 크다.

### 3. pathfinding 성공 != 실제 이동 성공

공식 JavaDoc의 `Path` 문서는 path 자체가 “좌표 step 집합”이라는 걸 보여준다.

이 말은:

- path가 존재함
- step이 계산됨

만으로는 부족하다는 뜻이다.

실제 NPC 모드에선 그 다음 층이 남는다.

- actor state machine이 그 path를 소비하는가?
- locomotion이 현재 posture / movement flags와 충돌하지 않는가?
- path는 있는데 anchor sync가 다시 제자리로 되감지 않는가?
- non-hostile suppression이 movement까지 같이 막지 않는가?

현재 `LivingWorldNPC`의
`pathing=true`, `moving=true`, `path2=true`인데 실제 square가 안 바뀌는 증상은
정확히 이 구간의 문제다.

### 4. animation / voice / visual은 부가 요소가 아니라 embodiment 계층이다

웹 검색에서 애니메이션/보이스/모델링 관련 문서가 계속 강조되는 이유:

- PZ의 캐릭터는 단순 sprite가 아니라
  애니메이션 노드, 모델, 보이스, 착용품, 반응, 오디오 분위기의 합으로 읽힌다.

즉 NPC가 사람처럼 보이려면:

- 걷는 방식
- 공격 반응
- 음성/소리
- 손 장비 모델
- 옷/헤어/비주얼
- 상태 전이 애니메이션

이 서로 맞아야 한다.

그래서 “보인다/안 보인다” 문제는 단순 렌더 문제가 아닐 수 있다.
다음이 다 포함된다.

- animator/state reset 누락
- wrong walk profile
- zombie hit reaction 유지
- zombie emitter 소리 유지
- hands/attached items mismatch
- shell 자체는 존재하지만 인간 presentation layer가 미적용

---

## 자료별 실무 가치

### 1. PZwiki / JavaDocs

가장 실무 가치가 큰 이유:

- 현재 노출된 클래스와 메서드를 빠르게 확인 가능
- 이벤트 목록과 관련 문서를 따라가기 좋음
- 클래스 관계를 추적하기 좋음

NPC 모드에서 특히 자주 보게 될 축:

- `IsoZombie`
- `IsoPlayer`
- `IsoGameCharacter`
- Lua events
- JavaDocs / unofficial JavaDocs
- decompiling guides

### 2. FWolfe 가이드

가치:

- 모드 구조와 Lua/Java 관계를 빠르게 잡아줌
- 파일 위치, shared/client/server 구분, 이벤트 중심 구조를 익히기 좋음
- “읽을 곳이 어디냐”를 알려주는 레퍼런스성 문서

특히 신규 실험 브랜치 만들 때:

- 어떤 로직을 client로 둘지
- 어떤 테이블을 shared에 둘지
- 어디서 vanilla Lua를 읽어야 할지

빠르게 판단하는 데 도움됨.

### 3. cocolabs 가이드

가치:

- 기술 튜토리얼보단 **개발 방법론** 쪽이 강함
- 버전관리, 문서화, 라이선스, 지식 공유, 워크플로우 정리를 강조

NPC 모드처럼 오래 끄는 프로젝트에 특히 중요:

- 실험 로그 남기기
- 가설/실패 케이스 기록하기
- 핫픽스와 구조 개선 분리하기
- 레퍼런스 출처 명확히 남기기

`LivingWorldNPC`가 지금처럼 handoff 문서와 test history를 누적하는 방식은
이 가이드의 철학과도 잘 맞는다.

### 4. awesome build42 resources

가치:

- 최신 Build 42 기준 진입점 묶음
- 커뮤니티, 문서, 툴, JavaDocs, 로그 분석 툴 등 링크 허브

NPC 모드 개발에 특히 유용한 이유:

- 한 번 막히면 코드만 보는 게 아니라
  디스코드/포럼/로그 분석/JavaDocs를 오가야 하는데,
  이런 허브형 문서가 탐색 비용을 줄여준다.

---

## LivingWorldNPC에 대한 직접 시사점

### 1. 현재 방향은 크게 틀리지 않았다

이번 웹 조사 기준으로 보면 `LivingWorldNPC`가 이미 하고 있는 다음 접근은 타당하다.

- `IsoZombie` shell을 관리 대상으로 취급
- posture / visual / audio를 별도 계층에서 교정
- 공격성 억제 / no-lunge / sound suppression 같은 bundle을 강화
- actor recovery / relink / replacement를 독립 관심사로 다룸
- Bandits 같은 실전 모드를 레퍼런스로 삼음

즉 지금 프로젝트의 핵심 문제는 “엉뚱한 길”이라기보다,
**어려운 길의 깊은 디테일 구간에 들어온 상태**로 보인다.

### 2. 오늘 이후 더 중요해지는 것

#### 2.1 managed shell contract를 더 중앙집중화

웹 조사 결과상 강하게 추천되는 방향:

- non-hostile / friendly / mobile / quarantine 등 각 상태에서
  중복된 억제 코드를 흩뿌리기보다,
- 하나의 **shell contract**로 관리해야 한다.

현재 막 넣은 방향과도 맞다.

#### 2.2 cache / registry / identity 계층 강화

Build 42 MP / migration 흐름까지 감안하면,
향후 더 중요해질 것:

- shell identity를 npc id와 강하게 연결
- cached shell 재획득 우선
- rogue shell / replacement shell 판정 명확화
- relink 시 marker restamp 일관화

#### 2.3 presentation과 authority를 분리해서 로그화

앞으로는 로그도 이렇게 나누는 게 좋다.

- **authority layer**
  - npcId
  - actorRef
  - shell contract state
  - quarantine / target / path / moving / square
- **presentation layer**
  - walkType
  - hit reaction
  - voice/emitter state
  - humanized visuals applied
  - hand models / attachments state

그래야 “actor는 존재하는데 인간처럼 안 보임” 문제가
어느 층에서 깨졌는지 빨리 보인다.

### 3. 클래스 A/B 실험은 여전히 high-value다

웹 조사 기준으로도 이건 유지 가치가 높다.

특히 다음 질문은 아직 살아 있다.

- `IsoZombie` 기반에서 인간 alive-state를 끝까지 안정화할 수 있는가?
- `IsoPlayer` 기반 혹은 다른 carrier 설계가 presentation 쪽에서 더 자연스러운가?
- 이동/전투/표현/멀티 authority를 모두 합치면 어느 클래스가 총비용이 낮은가?

즉 “밴딧식 shell discipline 강화”와 별개로,
**carrier class 재검토**는 계속 병행 가치가 있다.

---

## 추천 학습 루트

### 1단계 — 공식 구조 감각 잡기

1. `Modding` / `Lua (API)` / `Lua Events`
2. 공식 modding JavaDoc
3. Build 42 feature / migration 공지

목표:

- 지금 노출된 것과 아닌 것을 구분
- 이벤트 중심 사고 적응
- shared/client/server 감각 확보

### 2단계 — 캐릭터 계층 읽기

1. `IsoZombie`
2. `IsoPlayer`
3. `IsoGameCharacter`
4. path / movement 관련 JavaDocs
5. decompile + vanilla Lua cross-read

목표:

- 어떤 클래스가 무엇을 기본으로 기대하는지 파악
- NPC 모드에서 어떤 우회가 필요한지 판단

### 3단계 — 실전 모드 해부

1. Bandits
2. Week One NPC
3. Superb Survivors 계열

볼 것:

- spawn contract
- update loop
- combat suppression
- audio/visual reapply
- identity / cleanup / despawn / recovery
- SP/MP 분기

### 4단계 — 자기 프로젝트 문서화 강화

- 테스트 시나리오 고정
- 로그 포맷 고정
- 실패 유형 taxonomy 만들기
- commit 단위를 가설 중심으로 유지

---

## 추천 실무 체크리스트

### NPC 모드 새 실험 시작 전

- 어떤 carrier class를 쓸지 명시했는가?
- authoritative state가 어디에 있는가?
- client presentation과 분리돼 있는가?
- spawn 후 1회 설정이 아니라 update reassert가 있는가?
- target/combat/audio/visual suppression bundle이 하나로 묶였는가?
- shell identity/cache가 있는가?
- stream out/in 이후 relink 경로가 있는가?
- save/load, SP/MP를 따로 본 적 있는가?

### pathfinding 버그 볼 때

- path object가 있나?
- moving flag가 true인가?
- world square가 실제 변하나?
- walkType / animator state가 맞나?
- suppression이 locomotion까지 잠그지 않나?
- anchor/recovery가 곧바로 되감지 않나?

### “보이지 않는 인간 NPC” 문제 볼 때

- actor 존재 여부
- alive/dead/downed state
- visual humanization applied 여부
- animator/state reset 여부
- zombie reaction/audio 잔존 여부
- attached items / hands model mismatch
- shell class 자체 한계 여부

---

## 주의할 점

### 1. 검색 결과에는 노이즈가 많다

- 커뮤니티 글은 체감/후기와 사실이 섞여 있다.
- Steam/Reddit 정보는 참고만 하고,
  아키텍처 판단은 공식 자료 + 코드 + 실험 로그로 닫아야 한다.

### 2. PZwiki 일부 페이지는 fetch 차단이 있었다

- 일부 PZwiki 페이지는 웹 fetch에서 차단(Cloudflare류)되어,
  검색 스니펫과 다른 공식/커뮤니티 자료로 보완했다.
- 따라서 세부 API 사실은 최종적으로 local docs / JavaDocs / decompile로 재확인하는 게 안전하다.

### 3. Build minor version 차이를 계속 의식해야 한다

- 42.13, 42.15 같은 마이너 버전에서 migration 이슈가 이미 있었다.
- 따라서 NPC 모드 구현에서 “지금 된다”는 사실만으론 부족하고,
  버전 변동에 얼마나 견디는지도 중요하다.

---

## 참고 링크

### 공식 / 준공식

- Project Zomboid — 2022 and Beyond  
  <https://projectzomboid.com/blog/news/2022/01/2022-and-beyond/>
- Project Zomboid — Upcoming Features: B42  
  <https://projectzomboid.com/blog/upcoming-features-b42/>
- Project Zomboid official modding JavaDocs root example (`LuaManager.GlobalObject`)  
  <https://projectzomboid.com/modding/zombie/Lua/LuaManager.GlobalObject.html>
- Project Zomboid official modding JavaDocs pathfinding example (`Path`)  
  <https://projectzomboid.com/modding/zombie/ai/astar/Path.html>
- The Indie Stone Forums — Modding Migration Guide (42.13)  
  <https://theindiestone.com/forums/index.php?/topic/88499-modding-migration-guide-4213/>
- The Indie Stone Forums — Modding Migration Guide (42.15)  
  <https://theindiestone.com/forums/index.php?/topic/92433-modding-migration-guide-4215/>

### 위키 / 문서 허브

- PZwiki — Modding  
  <https://pzwiki.net/wiki/Modding>
- PZwiki — Lua (API)  
  <https://pzwiki.net/wiki/Lua_(API)>
- PZwiki — Lua Events  
  <https://pzwiki.net/wiki/Lua_Events>
- PZwiki — IsoZombie  
  <https://pzwiki.net/wiki/IsoZombie>
- PZwiki — Decompiling game code  
  <https://pzwiki.net/wiki/Decompiling_game_code>
- PZwiki — Unofficial JavaDocs (Build 42)  
  <https://pzwiki.net/wiki/Unofficial_JavaDocs_(Build_42)>
- PZwiki — Creating custom animations  
  <https://pzwiki.net/wiki/Creating_custom_animations>
- PZwiki — Creating custom voices  
  <https://pzwiki.net/wiki/Creating_custom_voices>

### 커뮤니티 가이드 / 리소스

- FWolfe — Zomboid Modding Guide  
  <https://github.com/FWolfe/Zomboid-Modding-Guide>
- cocolabs — pz-modding-guide  
  <https://github.com/cocolabs/pz-modding-guide>
- JBD-Mods — awesome-project-zomboid-build42-resources  
  <https://github.com/JBD-Mods/awesome-project-zomboid-build42-resources>

### NPC 모드 생태계 관찰용

- Bandits NPC (Workshop)  
  <https://steamcommunity.com/workshop/filedetails/?id=3268487204>
- Week One NPC (Workshop)  
  <https://steamcommunity.com/workshop/filedetails/?id=3403180543>
- Superb Survivors (legacy lineage reference)  
  <https://steamcommunity.com/workshop/filedetails/?id=1905148104>

---

## 최종 결론

Project Zomboid의 NPC 모드 개발은 아직도 **완성된 공식 인간 NPC 시스템 위에서 하는 작업이 아니다**.
대신 Build 42가 제공하는 캐릭터/월드/이벤트/애니메이션/모딩 기반 위에서,
모더가 직접 **행위자(shell)를 길들이고 유지하는 시스템**을 만드는 일에 가깝다.

그래서 성공적인 NPC 모드 개발은 보통 다음 순서를 따른다.

1. carrier class 선택
2. shell suppression / identity contract 확립
3. movement + path + authority 정렬
4. visual/audio/animation 인간화
5. recovery / relink / MP 안정화
6. 그 다음에야 higher-level AI

현재 `LivingWorldNPC`의 문제도 정확히 이 축 위에 있다.
따라서 앞으로의 최우선 과제는 여전히:

- managed shell contract 강화
- combat leak 차단
- movement 실이동 확보
- identity/cache/recovery 안정화

로 두는 게 맞다.
