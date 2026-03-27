# Runtime Hotfix — Watchdog Telemetry Nil-Safety — 2026-03-27

## 문제

직전 hardening 패치 후 TEST 01 단계에서 NPC가 생성 직후 사라지는 것처럼 보였고,
콘솔에는 런타임 에러가 기록됐다.

실제 스택트레이스는 다음을 가리켰다.

- `20_LWN_ActionRuntime.lua`
- `Runtime._tickMovementIntent(...)`
- `attempted index of non-table`

## 직접 원인

watchdog 보강 코드가 `command.movementTelemetry`를 table이라고 가정하고
바로 `telemetry.pathOnlyStatueSince = ...` 같은 필드 대입을 수행했다.

하지만 특정 순간에는 `movementTelemetry`가 아직 초기화되지 않았거나,
Lua 측에서 table이 아닌 값으로 해석될 수 있어 nil/non-table 인덱싱이 발생했다.

그 결과 embodied tick이 예외로 끊기고,
EventAdapter가 해당 NPC를 `embodied_tick_error`로 숨김 처리했다.

## 핫픽스 내용

- `_tickMovementIntent(...)`에서
  - `command.movementTelemetry`가 table이 아니면 즉시 `{}`로 초기화
  - `telemetry == nil`이면 새 table을 만들어 다시 연결
- 즉 watchdog / path-only-statue 경로가
  telemetry 부재만으로는 절대 크래시하지 않도록 수정했다.

## 기대 효과

- TEST 01에서 spawn 직후 런타임 에러로 NPC가 hide되는 현상 제거
- 이후 테스트에서 다시
  - spawn humanization 실패
  - hold release 효과
  - real movement 여부
  - recovery reclaim 경로
  를 정상적으로 관찰 가능

## 참고

이번 핫픽스는 원인 제거용 최소 수정이다.

즉, 이 패치가 movement/humanization/recovery 자체를 해결하는 것은 아니고,
**그 문제들을 다시 정상적으로 관측할 수 있게 런타임을 복구하는 목적**이다.
