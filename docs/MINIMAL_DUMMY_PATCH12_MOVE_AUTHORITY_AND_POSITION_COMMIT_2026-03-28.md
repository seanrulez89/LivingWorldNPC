# Minimal Dummy Patch 1+2 — Move Authority Lock and Position Commit — 2026-03-28

## 왜 이 패치가 필요했나

직전 테스트에서 중요한 단서가 두 개 나왔다.

1. `TEST 02` 경로에서는 deterministic move motor가 실제로 더미를 이동시켰다.
2. 하지만 일부 수동 command 경로에서는 잠깐 이동한 뒤 원래 위치로 되돌아가는 것처럼 보였다.

또 로그에는 다음 같은 모순이 보였다.

- `queue=move_to`
- 그런데 shell summary는 `dummy_idle`

즉 문제는 더 이상 "이동 자체가 안 된다"가 아니라,

- move authority와 idle authority가 서로 싸우고 있고
- 이동한 위치를 시스템 전체가 현재 위치로 받아들이지 못하고 있다는 것

으로 좁혀졌다.

## 이번 패치 목표

1. move motor가 active면 shell authority가 절대 idle로 내려가지 않게 한다.
2. deterministic step 성공 시 그 위치를 actor뿐 아니라 record/meta/handle 쪽에도 commit 한다.

## 이번에 바뀐 것

### 1. Social layer now knows whether dummy move authority is really active

- `42/media/lua/client/13_LWN_Social.lua`
- 추가:
  - `Social.isMinimalDummyMoveActive(record)`

이 helper는 단순히 `record.dummy.state`만 보지 않는다.
다음을 함께 본다.

- `record.dummy.state == "move_to"`
- `record.dummy.command.kind == "move_to"`
- `record.dummy.motor.state in {started, stepping}`
- `record.companion.command.active` + move-like command kind

즉 move authority를 더 넓고 현실적으로 판정한다.

### 2. Minimal dummy policy now follows real move authority, not stale dummy state

- `Social.minimalDummyPolicy(record)`
- 이제 `dummy_move` vs `dummy_idle` 판정이
  `Social.isMinimalDummyMoveActive(record)` 기준으로 이뤄진다.

효과:
- queue/motor는 move인데 shell policy만 idle로 내려가는 모순을 줄인다.

### 3. Runtime dummy mirror no longer drops to idle while move authority is active

- `42/media/lua/client/20_LWN_ActionRuntime.lua`
- `syncDummyMirror(record, queue)` 수정

이전:
- queue가 비어 있으면 바로 `dummy.state = "idle"`

지금:
- queue가 비어 있어도 move authority가 active면
  `dummy.state = "move_to"`를 유지한다.

### 4. clearActiveCommand no longer eagerly kills dummy move state if move authority is still active

- `clearActiveCommand(record, reason)` 수정

이전:
- clear가 들어오면 곧바로 `dummy.state = "idle"`

지금:
- move authority가 still active면 state를 `move_to`로 유지
- 완전히 끝난 경우에만 idle로 내린다.

### 5. EmbodimentManager now has an explicit actor-position commit function

- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
- 추가:
  - `Embody.commitActorPosition(record, actor, overrides)`

이 함수는 step 성공 후 다음을 함께 갱신한다.

- `record.anchor`
- `record.embodiment.lastKnownX/Y/Z`
- `record.embodiment.lastKnownSquare`
- embodied meta store
- carrier handle runtime commit fields
- dummy last committed square metadata
- actor modData commit fields

즉 이제 "actor만 잠깐 움직이고 논리적 위치는 여전히 원래 자리"인 상태를 줄이기 시작한다.

### 6. Deterministic move motor now commits each successful step

- `42/media/lua/client/20_LWN_ActionRuntime.lua`
- `commitDummyPosition(record, actor, square, source)` 추가
- `_tickDummyMoveMotor(...)`에서 step 성공 시마다 commit 수행
- arrived 시에도 current square를 다시 commit

효과:
- 이동 성공 후 위치가 logical state에 더 빨리 반영된다.

### 7. Motor state now reinforces dummy state more explicitly

- `setDummyMotorState(record, actor, state, detail)` 수정
- `started` / `stepping`이면 `dummy.state = "move_to"`
- `arrived` / `stalled` / `failed` / `idle`이면 `dummy.state = "idle"`

즉 motor state가 dummy authority state를 더 직접적으로 이끈다.

### 8. EventAdapter now enforces hard dummy shell by move-authority state, not only dummy.state

- `42/media/lua/client/90_LWN_EventAdapter.lua`
- 추가:
  - local `isDummyMoveAuthorityActive(record)`
- pre/post runtime hard shell enforcement가 이제 이 helper를 사용한다.

효과:
- move가 실제로 active한 동안에는 `dummy_move` shell contract를 더 우선적으로 유지한다.

### 9. Debug summary now shows committed square

- `42/media/lua/client/92_LWN_DebugTools.lua`
- MOVE SUMMARY에 추가:
  - `commit=<square>`

다음 테스트부터는:
- motor state
- totalDelta
- squareChanged
- committed square

를 같이 보며, 이동 후 위치가 진짜 확정됐는지 더 빨리 읽을 수 있다.

## 기대 효과

다음 테스트에서 보고 싶은 변화는 다음과 같다.

1. move 중 shell lane이 `dummy_idle`로 쉽게 떨어지지 않는다.
2. 이동 후 더미가 이전 anchor 기준으로 바로 되감기는 현상이 줄어든다.
3. 수동 command 경로에서도 move authority 유지가 조금 더 일관된다.
4. summary에 committed square가 찍히며 위치 권한이 더 잘 보인다.

## 아직 남는 것

이 패치는 다음 문제를 완전히 해결하는 단계는 아니다.

- 공격처럼 보이는 zombie motion residue
- zombie body skin / reanimated zombie visual role
- full recovery / generation rewrite

즉 이번 패치는
**이동 authority와 위치 authority를 맞추는 작업**이고,
그 다음 단계에서 visual aggression scrub와 zombie-body visual fail gating을 더 밀어야 한다.
