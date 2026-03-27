# Minimal Dummy Step A — Hard Dummy Shell Contract — 2026-03-28

## 목표

minimal dummy가 여전히 zombie carrier의 기본 공격성/오디오/외형 실패에 끌려가던 문제를
carrier 층에서 더 강하게 누르기 위한 첫 hardening 단계다.

이번 Step A는 아직 deterministic movement motor는 넣지 않았지만,
그 전에 필요한 **hard dummy shell contract + spawn-time appearance rebuild fallback**을 추가한다.

## 이번에 바뀐 것

### 1. Dummy policy now distinguishes idle vs move

- `13_LWN_Social.lua`
- `minimalDummyPolicy(record)`가 이제
  - `dummy_idle`
  - `dummy_move`
  를 분리한다.
- idle일 때는 `allowMovement=false`
- move일 때만 `allowMovement=true`

이건 이후 hard dummy shell contract가 lane 의미를 더 명확히 쓰게 만들기 위한 기초다.

### 2. Hard dummy shell contract added

- `35_LWN_Carrier_IsoZombie.lua`
- 추가:
  - `applyDummyVoicePrefix(actor)`
  - `clearAllZombieAggro(actor, options)`
  - `applyDummyAudioMute(actor, source)`
  - `applyHardDummyShellContract(record, actor, mode, source)`
  - `Carrier.enforceHardDummyShell(...)`

핵심 효과:

- target / attackedBy / lastTargettedBy clearing 강화
- zombie attack-ish variables clearing 강화
- dummy idle / move lane 분리
- dummy audio mute를 더 명시적으로 기록
- idle일 때는 moving/path를 더 강하게 정리
- move일 때도 aggro를 반복적으로 비움

### 3. Dummy lane support expanded inside carrier shell contract

- `dummy_idle`
- `dummy_move`

이 lane들이 `applyShellLaneContract(...)`에서 first-class lane으로 취급되도록 수정했다.

### 4. Spawn-time appearance rebuild fallback added for dummy

- `35_LWN_Carrier_IsoZombie.lua`
- 추가:
  - `noteDummyAppearanceState(...)`
  - `rebuildDummyAppearance(record, actor, source)`

spawn probe가 실패할 때 dummy는 기존처럼 같은 initial pass만 반복하지 않고,
`ShellHumanizer.maintain(... forceFull=true ...)` 기반의 reapply 경로를 한 번 더 시도한다.

즉 "나중 유지 단계에서 먹는 외형 변경"을 spawn fallback으로 당겨오려는 첫 시도다.

### 5. Basic carrier flag application now re-enforces hard dummy shell

- `applyBasicZombieCarrierFlags(...)` 끝에서
  dummy면 hard dummy shell contract를 다시 적용한다.

의도:
- persistent illusion / relationship combat state가 적용된 뒤에도
  마지막으로 dummy contract가 우선권을 다시 갖도록 하기 위함

### 6. Runtime and EventAdapter now re-apply hard dummy shell repeatedly

- `20_LWN_ActionRuntime.lua`
  - `Runtime.clear(...)`
  - `_startMovement(...)`
  - `_tickMovementIntent(...)`
- `90_LWN_EventAdapter.lua`
  - `tickEmbodiedRecord(...)` pre/post runtime

즉 dummy shell contract가:
- queue clear 후
- move 시작 시
- move tick 중
- main embodied tick 전후

반복적으로 다시 씌워진다.

## 기대 효과

다음 테스트에서 보고 싶은 첫 변화는 다음과 같다.

1. dummy idle 상태에서 target reacquisition이 줄어든다.
2. dummy move 상태에서도 attack target 유지가 약해진다.
3. zombie vocal leak가 줄어든다.
4. spawn 직후 appearance rebuild fallback이 초기 좀비 외형 실패 빈도를 조금이라도 낮춘다.

## 아직 안 한 것

- deterministic move motor
- generation-based single-shell recovery
- rebuild-driven recovery lifecycle
- debug summary 확장

즉 이번 Step A는 **carrier를 강하게 봉인하는 단계**이고,
진짜 이동 확보는 다음 Step(결정적 mover)에서 다룰 예정이다.
