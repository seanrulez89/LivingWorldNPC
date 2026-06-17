# Minimal Dummy Visual Aggression Scrub — 2026-03-28

## 왜 이 패치가 필요했나

이전 테스트까지의 상태는 다음과 같았다.

- zombie vocal suppression worked
- deterministic movement worked
- moved position commit worked much better
- but after moving, the dummy could still *look* aggressive:
  - in-place stepping
  - attack-like arm posture
  - player-facing zombie-like turn behavior
- delete gating could still fail with `actor_is_attacking` even when the player did not observe real attack hits landing

즉 남은 가장 큰 문제는 더 이상 pure locomotion authority가 아니라,
**zombie attack presentation residue**였다.

## 이번 패치 목표

1. attack / alert / turn presentation residue를 더 강하게 scrub
2. idle state에서 dummy가 player-facing zombie처럼 보이는 현상을 줄이기
3. 실제 target이 없는 dummy residue 때문에 delete가 막히는 false positive를 줄이기

## 이번에 바뀐 것

### 1. `clearAllZombieAggro(...)` 강화

- `35_LWN_Carrier_IsoZombie.lua`
- attack / bite / aiming / turn 관련 variable clearing 범위를 넓혔다.

### 2. `scrubDummyAttackPresentation(...)` 추가

- `35_LWN_Carrier_IsoZombie.lua`
- hard shell contract와 별개로,
  attack-like presentation residue를 지우는 전용 scrub 함수를 추가했다.
- idle일 때는 더 강하게:
  - moving false
  - path nil
  - walk type reset
  - direction south lock attempt

### 3. `forceDummyIdlePresentation(...)` 추가

- `35_LWN_Carrier_IsoZombie.lua`
- idle contract 재적용 시 attack / turn residue를 더 강하게 누른다.
- `StopAllActionQueue()`까지 함께 적용한다.

### 4. Hard dummy shell contract now includes explicit presentation scrub

- `35_LWN_Carrier_IsoZombie.lua`
- `applyHardDummyShellContract(...)` 내부에
  scrub pass를 직접 넣었다.
- idle mode에서는 `forceDummyIdlePresentation(...)`까지 호출한다.

### 5. Runtime arrival / stall paths now scrub immediately

- `20_LWN_ActionRuntime.lua`
- deterministic move motor가 `arrived` 또는 severe `stalled`로 끝날 때
  idle scrub를 즉시 실행하도록 추가했다.
- 즉 move 종료 직후 zombie attack presentation residue를 더 빨리 꺼내려는 목적이다.

### 6. EventAdapter post-runtime now double-scrubs dummy shell

- `90_LWN_EventAdapter.lua`
- 기존 hard shell enforcement 뒤에
  `scrubDummyPresentation(...)`를 한 번 더 실행한다.
- 이건 tick 말미에 남는 attack-like presentation residue를 줄이기 위한 추가 보호층이다.

### 7. Delete guard now tolerates dummy attack-presentation-only residue

- `23_LWN_ActorFactory.lua`
- `isActorInCombatOrUnderAttack(...)`에서
  dummy actor가 `isAttacking()==true`여도
  실제 target이 없으면 `dummy_attack_presentation_only`로 보고 combat block을 걸지 않도록 완화했다.
- 목적:
  - "실제로는 안 때리는데 delete가 attack state 때문에 막히는" false positive 감소

### 8. Debug summary now exposes `attacking` and `target`

- `92_LWN_DebugTools.lua`
- MOVE SUMMARY에 다음을 추가:
  - `attacking=yes/no`
  - `target=yes/no`
- 다음 테스트에서는
  - 실제 target reacquisition인지
  - attack-like presentation residue인지
  더 빨리 구분할 수 있다.

## 기대 효과

다음 테스트에서 기대하는 변화는 다음과 같다.

1. 이동 후 dummy가 제자리 걸음/공격 자세로 덜 남는다.
2. idle 상태에서 player-facing zombie turn residue가 줄어든다.
3. target이 없는 dummy residue 때문에 delete가 막히는 일이 줄어든다.
4. summary에서 `attacking`과 `target`을 같이 보며 residue 성격을 더 잘 해석할 수 있다.

## 아직 안 한 것

- zombie body skin hard fail 강화
- visual shell을 truly human-looking body로 고정하는 작업
- deeper recovery / generation rewrite

즉 이 패치는 **몸짓/연기 residue를 줄이는 단계**이고,
body appearance 자체를 인간으로 바꾸는 단계는 아직 다음 우선순위다.
