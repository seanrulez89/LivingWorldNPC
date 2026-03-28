# Minimal Dummy Spawn-Safe Scrub Hotfix — 2026-03-28

## 왜 이 핫픽스가 필요했나

직전 visual aggression scrub 패치 후 TEST 01에서 다음 회귀가 관찰됐다.

- dummy가 무한 생성처럼 보임
- 런타임 에러 발생
- 생성된 dummy들은 zombie-looking shell이지만
  - zombie vocal은 없고
  - 공격성도 없고
  - 플레이어 인식도 약함

이 패턴은 visual aggression scrub의 방향 자체가 틀렸다기보다,
**spawn 직후 idle shell에 너무 이르고 너무 강한 scrub가 들어간 결과**로 해석됐다.

즉 문제는:
- scrub 필요성이 아니라
- scrub 적용 시점 / 강도 / 반복 위치
였다.

## 이번 핫픽스 목표

1. spawn 직후에는 aggressive idle scrub를 잠시 유예한다.
2. move 종료 / stalled 같이 정말 필요한 지점의 scrub는 유지한다.
3. post-runtime extra scrub는 조건부로만 돌린다.
4. audio suppression / deterministic movement / position commit 같은 이미 확보한 진전은 유지한다.

## 이번에 바뀐 것

### 1. Dummy spawn scrub grace window 추가

- `35_LWN_Carrier_IsoZombie.lua`
- 추가:
  - `dummyScrubGraceHours()`
  - `markDummySpawnGrace(record, actor, source, reset)`
  - `isDummyScrubGraceActive(record)`

dummy spawn / 초기 sync 시:
- `record.dummy.spawnedAt`
- `record.dummy.scrubGraceUntil`
를 기록한다.

이 grace window 동안에는,
spawn 직후 idle shell에 대한 강한 visual scrub가 무조건 실행되지 않도록 한다.

### 2. idle scrub를 조건부화

- `scrubDummyAttackPresentation(record, actor, mode, source, options)`
- idle mode + spawn grace active + 실제 attacking/target residue 없음
이면
  - scrub를 건너뛴다
  - `dummy_scrub_skipped_spawn_grace`를 남긴다

즉 이제는 "항상 scrub"가 아니라,
**spawn 직후에는 정말 필요할 때만 scrub**한다.

### 3. `forceDummyIdlePresentation(...)`도 grace를 존중

- 이전에는 idle 강제 presentation이 너무 공격적이었다.
- 이제는 내부 scrub가 실제로 수행된 경우에만
  - `StopAllActionQueue()`
  - path clear
  - direction reset
  같은 강한 idle presentation 조작을 계속 수행한다.

즉 spawn 직후 shell settling 전에 과도한 idle reset을 덜 하게 된다.

### 4. spawn / sync에서 grace 기록

- spawn 경로에서 minimal dummy면 grace를 새로 기록
- sync 경로에서도 아직 grace metadata가 없으면 bootstrap 기록

즉 새 shell은 spawn-safe window를 갖게 된다.

### 5. EventAdapter post-runtime extra scrub를 조건부로 약화

- `90_LWN_EventAdapter.lua`
- 이전에는 hard shell enforcement 뒤에 post-runtime scrub가 거의 항상 추가로 돌았다.
- 지금은 아래 조건에서만 추가 scrub를 실행한다.
  - spawn grace가 끝났고
  - move active 이거나
  - 실제 attacking residue가 있거나
  - target residue가 있거나

그 외에는 post-runtime extra scrub를 건너뛴다.

이건 TEST 01 spawn idle 상태에서의 회귀를 줄이기 위한 핵심 완화다.

### 6. move 종료 / stalled 시점의 scrub는 force 유지

- `20_LWN_ActionRuntime.lua`
- deterministic move motor가
  - arrived
  - stalled
일 때 수행하는 idle scrub는 여전히 force=true로 유지했다.

이유:
- 이 경로는 spawn 회귀의 원인이라기보다,
  post-move attack-presentation residue를 줄이는 데 필요하기 때문이다.

## 기대 효과

다음 TEST 01에서 기대하는 변화는 다음과 같다.

1. spawn 직후 런타임 에러 재현이 줄어든다.
2. dummy가 무한 생성처럼 보이는 현상이 줄어든다.
3. zombie vocal suppression / no-aggression baseline은 유지된다.
4. move 이후 residue scrub 효과는 가능한 한 유지된다.

## 아직 안 한 것

- explicit re-embody error backoff lifecycle
- zombie body skin hard fail 강화
- deeper visual aggression cleanup beyond current residue scrub

즉 이번 핫픽스는
**spawn idle safety를 회복하는 회귀 완화 패치**다.
