# Minimal Dummy Breakthrough Analysis — 2026-03-28

## 한 줄 요약

이번 진전은 우연이 아니다.

우리는 더 이상

- 관계를 조정하고,
- 친화/중립/적대 상태를 흔들고,
- 좀비 캐리어가 알아서 인간처럼 굴어주기를 기대하고,
- native zombie pathing이 결국은 실제 이동으로 이어지기를 바라는

방식으로 테스트하지 않았다.

대신 이번에는 다음 세 가지를 동시에 했다.

1. **실험 표면을 minimal dummy로 축소했다.**
2. **dummy shell에 강한 하드 계약(hard shell contract)을 반복 적용했다.**
3. **이동만큼은 zombie-native locomotion을 우회해서 deterministic motor로 직접 밀었다.**

그 결과 처음으로 다음이 동시에 성립했다.

- zombie vocal 없음
- 공격성 없음
- 실제 displacement 있음

외형은 아직 좀비처럼 보이지만,
이번 테스트는 프로젝트가 처음으로 **핵심 한 축을 정말로 뚫었다**는 점에서 중요하다.

---

## 먼저, 이전에는 왜 계속 안 됐나

이전 아키텍처는 크게 네 겹이 서로 충돌하고 있었다.

### 1. 사회적 관계 계층

- friendly / neutral / hostile
- trust / resentment / recruited
- betrayal / pending_betrayal
- relationship policy drift

이 계층은 원래 살아있는 NPC를 시뮬레이션하기 위한 것이었다.
하지만 테스트 단계에서는 오히려 질문을 흐렸다.

- 지금 이 NPC가 왜 공격하나?
- 관계가 바뀌어서 그런가?
- 시스템이 drift 해서 그런가?
- command queue보다 story logic가 우선했나?

즉 "dummy가 왜 dummy처럼 안 움직이냐"를 보려는데,
계속 "사회적 NPC"로 해석해버리는 문제가 있었다.

### 2. goal / utility / behavior 계층

- support_player
- follow / guard / search / retreat
- utility choice
- behavior tree tick

이 계층도 마찬가지다.
더미는 원래 아무 생각 없이 가만히 있어야 하는데,
시스템은 계속 "이 NPC가 지금 뭘 해야 하나"를 계산하려 했다.

그래서 실험자는 단순한 질문을 하고 싶었는데,
엔진은 계속 복잡한 질문으로 대답하고 있었다.

### 3. carrier 자체의 zombie 본능

같은 `IsoZombie` carrier 위에 인간형 외형/행동을 덧입히는 구조에서는,
아래가 계속 새어 나왔다.

- target reacquisition
- attack intent
- zombie vocal
- zombie-coded movement read
- reanimated zombie presentation role

즉 겉에 뭐를 씌워도,
안쪽에서는 계속 zombie가 자기 본능을 되찾으려고 했다.

### 4. native zombie locomotion

로그상 반복되던 실패 패턴은 분명했다.

- `moving=true`
- `path2=true`
- 그런데 `totalDelta=0.00`
- `squareChanged=no`

즉 path는 있는 것처럼 보였지만,
실제 world movement는 발생하지 않았다.

이건 단순한 pathfinding 실패가 아니라,
**행동 명령이 body/world transform까지 도달하지 못하는 구조적 실패**였다.

---

## 이번에는 무엇을 다르게 했나

이번 진전은 아래 네 단계가 겹쳐져서 나왔다.

---

## 1. 실험 대상을 "NPC"가 아니라 "minimal dummy"로 재정의했다

이게 가장 중요한 출발점이다.

이전에는 테스트 대상이 사실상
"완성형 NPC 후보"였다.
즉 테스트 시작 전부터 다음이 같이 얹혀 있었다.

- 관계
- 목표
- 스토리
- 전투 가능성
- 이동
- 외형
- recovery

문제는 이 모든 축이 동시에 열려 있으면,
어느 하나가 실패해도 다른 모든 축이 원인처럼 보인다는 거다.

그래서 새 브랜치에서는 아예 실험 대상을 다시 정의했다.

### minimal dummy의 정의

- 기본 상태는 idle
- 명령이 있을 때만 move_to
- 관계 없음
- 목표 없음
- 자율 행동 없음
- 공격 없음
- 좀비 소리 없음
- 인간 외형 시도

이 변화는 단순한 "설정 변경"이 아니다.
질문의 구조를 바꾼 것이다.

예전 질문:
- 이 NPC가 제대로 동작하나?

새 질문:
- 이 더미가 가만히 설 수 있나?
- 이 더미가 명령대로 이동하나?
- 이 더미가 zombie처럼 공격/울부짖지 않나?

질문이 좁아지자 원인도 좁아졌다.

---

## 2. 관계 / 스토리 / 목표 / 유틸리티 오염을 active path에서 제거했다

이번 진전의 첫 번째 토대는 "더 이상 다른 시스템이 끼어들지 못하게 한 것"이다.

### 실제로 제거/우회한 것

- trust / resentment drift
- canRecruit
- betrayal score
- command response social gating
- support_player goal
- story-driven goal assignment
- utility candidate 다양화
- behavior tree의 follow/guard/retreat/search 확장

### 왜 이게 중요했나

이전에는 더미를 spawn해도,
내부적으로는 계속 "일반 NPC"처럼 해석하려는 힘이 남아 있었다.

그러면 무슨 일이 생기냐면,
실험자는 move_to만 주고 싶은데,
시스템은 뒤에서 다음을 계속 만지게 된다.

- 관계 기반 policy
- utility choice
- autonomous behavior
- non-hostile but still socially interpreted state

이번에는 이걸 먼저 끊었다.

그래서 이번 테스트가 의미 있는 건,
이제 성공의 이유를 더 이상
"어쩌다 social drift가 덜 일어나서"라고 설명할 필요가 없다는 점이다.

즉 이번 전진은 **운이 아니라 구조 변경의 결과**다.

---

## 3. hard dummy shell contract를 반복 적용했다

이게 두 번째 핵심이다.

### 이전 방식

예전에는 대체로 이런 식이었다.

- spawn 시 한번 초기화
- state 전환 시 한번 humanization/neutralization
- 필요할 때 suppressions 추가

문제는 `IsoZombie`는 이렇게 한두 번 눌러서는 얌전해지지 않는다는 점이다.
조금 지나면 다시:

- target을 잡고
- attack-ish state를 띠고
- zombie vocal을 내고
- zombie-like read를 드러냈다.

### 이번 방식

이번에는 shell contract를 **반복 재적용**했다.

적용 지점:
- idle tick
- move tick
- runtime clear 직후
- move start 직후
- embodied tick 전/후

### contract가 실제로 하는 일

- target clear
- attackedBy / lastTargettedBy clear
- zombie attack 변수 clear
- NoLungeTarget 유지
- no teeth 유지
- targeted zombie mute
- move / idle lane 분리

### 왜 이게 중요했나

결국 이번 성공은
"좀비를 설득한 것"이 아니라
**좀비가 zombie처럼 굴려고 할 때마다 계속 덮어씌운 것**이다.

이건 Bandits 류 레퍼런스에서 배운 가장 중요한 교훈과도 맞다.
인간처럼 보이는 것은 화장이고,
인간처럼 행동하게 묶는 것은 계약이다.

이번에는 그 계약이 실제로 효력을 냈다.

### 그 증거

테스트 로그는 반복적으로 이렇게 보여줬다.

- `dummy_contract_idle_applied`
- `target=false`
- `moving=false`
- `path2=false`

그리고 move 상태에서도:

- `dummy_contract_move_applied`
- `target=false`
- `moving=true`
- `path2=false`

즉 shell은 더 이상 공격과 이동을 동시에 zombie 방식으로 해석하지 않았다.

---

## 4. 제일 중요한 변화: 이동을 더 이상 zombie-native locomotion에 맡기지 않았다

이게 이번 돌파의 진짜 핵심이다.

### 이전 구조의 한계

우리는 오랫동안 다음을 계속 봤다.

- path는 잡힘
- moving=true
- path2=true
- 그런데 좌표는 안 바뀜

이건 단순 버그가 아니라,
**이동 의도와 world movement 사이에 있는 엔진 계층이 막혀 있었다**는 뜻이다.

즉 "걷게 하자"고 했는데,
실제로는 "걷고 있다고 말만 하는 zombie"가 된 셈이다.

### 이번 구조

그래서 이번엔 아예 우회했다.

- dummy + move_to면
- native `pathToLocation()` / `PathFindBehavior2`를 주 경로로 쓰지 않음
- 대신 deterministic move motor를 시작

### deterministic move motor가 하는 일

- 현재 tile 좌표를 읽음
- 목표 tile 좌표를 읽음
- 다음으로 갈 square 후보를 계산
- 그 square가 있으면 actor를 그 위치로 직접 옮김
- 충분히 가까워지면 arrived 처리
- 못 움직이면 stalled 처리

즉 이번엔 더 이상
"엔진이 알아서 움직여주겠지"
를 믿지 않았다.

### 왜 이게 드디어 먹혔나

왜냐하면 이번엔
**행동 의도를 직접 좌표 변화로 번역했기 때문**이다.

이전엔:
- move intent -> zombie locomotion state -> (중간 어디선가 증발)

이번엔:
- move intent -> next square 계산 -> actor 직접 재배치

이 차이가 컸다.

### 그 증거

로그에서 처음으로 다음이 동시에 떴다.

- `motor=stepping`
- `totalDelta=1.41`
- `squareChanged=yes`
- `path2=no`

이 조합은 매우 중요하다.

왜냐하면 이건
"이제는 zombie native path state가 없어도 실제 이동이 가능하다"
는 뜻이기 때문이다.

즉 지금의 성공은
**좀비 이동 엔진을 고친 성공이 아니라, 그 엔진을 우회한 성공**이다.

---

## 왜 좀비 소리가 사라졌나

이번에 소리가 사라진 이유도 비슷하다.

예전에는 전역 오디오를 잘못 건드려서,
"NPC가 조용해진 건지 게임이 조용해진 건지"가 섞인 적이 있었다.

이번에는 그 실수를 줄였다.

### 무엇이 달랐나

- `stopAll()` 같은 넓은 차단 제거
- targeted zombie mute 사용
- hard shell contract 안에서 반복 재적용
- voice prefix도 dummy 기준으로 다시 지정

즉 이번엔
"전체 게임을 조용하게 만들어서 좀비가 조용해진 것처럼 보이는 방식"
이 아니라,
**그 actor의 zombie vocal만 겨냥해서 막는 방식**에 가까워졌다.

그래서 유저 체감도 이렇게 바뀌었다.

- 다른 소리는 정상
- 좀비 소리만 안 남

이건 이번 오디오 suppression이 드디어 실전적으로 맞아들어갔다는 뜻이다.

---

## 왜 공격성이 사라졌나

이것도 같은 맥락이다.

### 이전에는
- target reacquisition이 계속 남았고
- actor_has_target 때문에 삭제도 안 되고
- move 상태에서도 공격 의도가 새어 나왔다.

### 이번에는
hard dummy shell contract가 반복적으로:
- target clear
- attackedBy clear
- attack-ish variables clear
를 강제했다.

그리고 move/idle lane이 분리되면서,
이제는 이동 상태라도 공격 로직이 다시 끼어들 틈이 줄어들었다.

즉 이번에 공격성이 줄어든 이유는
"관계가 좋아져서"도 아니고,
"우호 설정을 잘해서"도 아니다.

**공격 자체를 dummy shell의 허용 범위 밖으로 밀어낸 것**이 핵심이다.

---

## 그런데 왜 외형은 아직도 좀비인가

여기가 지금 가장 중요한 남은 문제다.

이번 테스트는 movement / audio / aggression 쪽에서 처음으로 진전이 있었다.
그런데 외형은 여전히 유저 눈에 "좀비"였다.

이 말은 무엇이냐면,
지금까지의 문제 묶음 중에서
다음이 분리됐다는 뜻이다.

### 이제 분리된 것

- 오디오 문제: 일부 진전 있음
- 공격성 문제: 일부 진전 있음
- 이동 문제: 첫 성공 있음
- **외형 문제: 여전히 미해결**

즉 이제는 "모든 것이 한꺼번에 망가져 있다"가 아니라,
**시각적 humanization 경로만 유난히 남아 있다**고 볼 수 있다.

### 더 중요한 점

현재 debug summary는
- `humanInit=yes`
- `probeOk=yes`
처럼 보일 수 있다.

그런데 사람 눈에는 여전히 좀비다.

즉 지금 probe는 진실을 과대평가하고 있다.

이건 굉장히 중요한 발견이다.
왜냐하면 이제부터 해야 할 일은 막연한 humanization 추가가 아니라,
**“무엇을 성공으로 볼 것인가”를 다시 정의하는 것**이기 때문이다.

---

## 결국 이번 진전의 본질은 무엇인가

쉽게 말하면 이거다.

### 예전 방식
"복잡한 NPC를 만든 다음, 그 NPC가 우연히 조용하고 얌전하고 잘 걷기를 바랐다."

### 이번 방식
"복잡한 NPC를 잠시 포기하고, 조용하고 얌전하고 이동만 하는 dummy를 먼저 직접 만들었다."

이 차이가 진전을 만들었다.

다시 더 쉽게 말하면:

- 예전엔 **좀비를 사람처럼 설득하려고 했다**
- 이번엔 **좀비를 계속 묶어두고, 이동은 우리가 직접 시켰다**

그래서 처음으로 결과가 나왔다.

---

## 이번 테스트가 왜 분기점인가

이번 전진은 겉으로 보면 사소해 보일 수 있다.

- 외형은 아직 좀비
- 이동도 아주 자연스럽진 않음

하지만 개발 관점에선 전혀 사소하지 않다.

왜냐하면 이번으로 다음이 처음 증명됐기 때문이다.

1. minimal dummy 방향이 맞다
2. hard shell contract는 실제 효과가 있다
3. deterministic movement는 실제 displacement를 만들 수 있다
4. social/goal 제거는 방향이 맞았다
5. 남은 핵심 병목은 이제 visual shell 쪽으로 좁혀졌다

즉,
이번부터는 더 이상 "아무것도 안 된다"가 아니다.
이제는 **"무엇은 됐고, 무엇만 남았는지 안다"** 상태다.

이 차이는 매우 크다.

---

## 다음 우선순위는 무엇인가

이번 분석 기준으로 다음 우선순위는 이렇게 잡는 게 맞다.

### 1순위 — Step B-full

이제 movement / audio / aggression이 첫 성공을 냈으니,
다음은 외형을 정면으로 다뤄야 한다.

해야 할 것:
- initial spawn path를 maintenance_full_reapply 중심으로 교체
- appearance probe를 더 엄격하게 재정의
- 성공 외형 lock 강화
- failed shell lifecycle 추가

### 2순위 — Step C 보강

지금 motor는 첫 displacement는 만들었지만,
아직 `arrived / stalled` 해석은 덜 정교하다.

보강할 것:
- 도착 판정 조정
- stalled 판정 조정
- 더 짧은 테스트 거리로 초기 검증 최적화

### 3순위 — recovery

return-path split는 여전히 문제지만,
지금은 외형이 더 큰 병목이다.

즉 recovery는 지금 당장보다,
spawn shell이 visually right해진 다음 더 보는 게 효율적이다.

---

## 가장 쉬운 최종 설명

사용자에게 가장 쉽게 설명하면 이렇다.

> 예전에는 좀비 하나를 인간 NPC처럼 만들려고 너무 많은 걸 동시에 시켰다.
> 그래서 관계, 행동, 전투, 이동, 외형이 서로 꼬였다.
> 이번에는 그걸 포기하고,
> "가만히 서 있다가 명령하면 이동만 하는 중립 dummy"로 줄였다.
> 그리고 좀비 본능은 계속 강제로 지우고,
> 이동은 엔진에게 맡기지 않고 직접 한 칸씩 움직이게 만들었다.
> 그래서 처음으로 공격성/좀비소리/이동에서 실제 진전이 생겼다.
> 이제 남은 가장 큰 문제는 외형이다.

---

## 결론

이번 진전은 패치 하나의 우연한 성공이 아니라,
문제를 다루는 방식 자체를 바꾼 결과다.

- 복잡한 NPC를 잠시 포기했고,
- 실험 대상을 minimal dummy로 줄였고,
- shell contract를 강화했고,
- locomotion을 직접 제어했다.

그래서 처음으로:

- 공격성 억제,
- 좀비 소리 억제,
- 실제 이동

이 동시에 성립했다.

이제 프로젝트는 다시 "아무것도 안 되는 상태"가 아니다.
이제는 **움직이는 조용한 중립 dummy는 만들 수 있고, 남은 핵심은 외형 재구축**이라고 말할 수 있다.
