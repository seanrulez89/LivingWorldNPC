# Minimal Dummy Step C — Deterministic Move Motor — 2026-03-28

## 목표

minimal dummy가 native zombie locomotion에 의존하지 않고도
`move_to` 명령으로 실제 world displacement를 만들 수 있게 한다.

지금까지의 반복 실패 패턴은 다음과 같았다.

- `moving=true`
- `path2=true`
- `totalDelta=0.00`
- `squareChanged=no`

즉 pathing state는 존재하지만 body/world movement가 실제로 적용되지 않았다.

이번 Step C는 이 문제를 우회하기 위해 dummy 전용 deterministic move motor를 추가한다.

## 이번에 바뀐 것

### 1. Dummy move motor state helpers added

- `20_LWN_ActionRuntime.lua`
- 추가:
  - `actorTilePosition(actor)`
  - `gridSquareAt(x, y, z)`
  - `ensureActorAtSquare(actor, square)`
  - `ensureDummyMotorState(record, actor)`
  - `setDummyMotorState(record, actor, state, detail)`
  - `chooseDummyMotorStepSquare(actor, intent)`

이 helper들은 dummy motor가 다음 square를 고르고,
actor를 해당 square로 직접 옮기고,
motor 상태를 modData / telemetry에 기록하는 데 사용된다.

### 2. Dummy `move_to` no longer depends on native path start

- `Runtime._startMovement(record, actor, intent)`
- minimal dummy + `move_to`인 경우:
  - `pathToLocation(...)` / `PathFindBehavior2`를 사용하지 않는다.
  - 대신 `Runtime._startDummyMoveMotor(...)`가 시작된다.

### 3. Deterministic stepping added

- `Runtime._startDummyMoveMotor(...)`
- `Runtime._tickDummyMoveMotor(...)`

실제 동작:

- 목적지 좌표를 tile 기준으로 본다.
- 현재 tile에서 목표 tile로 한 칸씩 접근한다.
- 대각/축 우선 후보 square를 고른다.
- 해당 square가 있으면 actor를 직접 그 square 중심으로 재배치한다.
- 충분히 가까워지면 `arrived`로 종료한다.
- 여러 번 step 후보를 못 찾으면 `stalled` / `failed`로 종료한다.

즉 이 모터는 보기 좋은 걷기를 우선하지 않고,
**실제 displacement 발생**을 1순위로 둔다.

### 4. Runtime tick recognizes deterministic dummy moves

- `_tickMovementIntent(...)`는 이제
  `intent.pathMethod == "dummy:deterministic"`이면
  native `pf:update()` 대신
  `Runtime._tickDummyMoveMotor(...)`를 호출한다.

### 5. Debug summary now shows motor state

- `92_LWN_DebugTools.lua`
- MOVE SUMMARY에
  - `motor=<state>`
  - `commit=<square>`
  가 추가되었다.

예상 state:

- `started`
- `stepping`
- `arrived`
- `stalled`
- `failed`

또한 TEST 02/03 checklist에도 motor state를 보도록 문구를 추가했다.

## 기대 효과

다음 테스트에서 가장 먼저 기대하는 변화는 다음과 같다.

1. TEST 02에서 `motor=started -> stepping`
2. `totalDelta > 0.00`
3. `squareChanged=yes`
4. TEST 03에서 `motor=arrived` 또는 적어도 `stalled`로 더 명확한 실패 분류

## 아직 안 한 것

- generation-based single active shell recovery rewrite
- full Step B spawn path replacement
- failed shell lifecycle centralization
- dead code deletion

즉 이번 Step C는 **실제 이동 확보를 최우선으로 하는 강제 이동 우회층**이다.
