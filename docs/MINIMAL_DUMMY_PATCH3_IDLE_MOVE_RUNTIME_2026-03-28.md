# Minimal Dummy Patch 3 — Idle / Move Runtime Narrowing — 2026-03-28

## 목표

minimal dummy record의 런타임을 실제로 `idle / move_to` 중심으로 좁힌다.

Patch 2가 social / goal / story contamination을 줄였다면,
이번 Patch 3은 runtime layer에서 더미가 old NPC action set을 실질적으로 덜 타게 만드는 단계다.

## 이번에 바뀐 것

### 1. ActionRuntime now understands minimal dummy mode

- `20_LWN_ActionRuntime.lua`
- 추가:
  - `isMinimalDummyRecord(record)`
  - `isAllowedDummyIntent(intent)`
  - `syncDummyMirror(record, queue)`

### 2. Dummy queue now effectively supports only `move_to`

- dummy record에 대해 `Runtime.enqueue(...)`는
  `move_to`만 허용한다.
- 다른 intent는 enqueue되지 않는다.
- dummy queue는 항상 단일 current command로 취급되도록 insert 전에 queue를 비운다.

### 3. Dummy mirror state is now updated from the queue

- queue 비어 있으면:
  - `record.dummy.state = "idle"`
- queue first가 `move_to`면:
  - `record.dummy.state = "move_to"`
  - destination mirror 기록

### 4. Runtime.tick drops unsupported dummy actions immediately

- dummy record에 남아 있는 current intent가 `move_to`가 아니면
  즉시 실패/제거한다.
- 즉 old intents가 남아 있더라도 더미 런타임 본선으로 계속 흘러가지 못한다.

### 5. EventAdapter no longer drives dummy records through utility/combat selection

- `90_LWN_EventAdapter.lua`
- dummy record에서는:
  - invalid old queue가 있으면 clear
  - queue가 있으면 `dummy_command_queue`
  - queue가 없으면 `dummy_idle`
- 즉 utility/combat/behavior tree가 더미의 주행 경로를 다시 채우지 않는다.

### 6. Movement contract relabeling

- dummy move tick/start는 `forceLane = "dummy_move"`를 우선 사용한다.
- 로그/상태 해석이 old `non_hostile_commandable` naming에서 조금 더 분리된다.

## 아직 안 한 것

- deterministic mover
- generation identity / single active shell recovery rewrite
- failed shell rebuild lifecycle
- full dead-code deletion of old paths

즉 이번 Patch 3은 "완성"이 아니라,
minimal dummy가 **실제로 old runtime behavior churn에서 한 단계 더 벗어나도록** 만드는 중간 단계다.

## 다음 단계에서 확인하고 싶은 것

다음 테스트 전 또는 다음 패치에서 보고 싶은 건 딱 이거다.

1. 더미가 더 이상 follow/guard/story/hostile utility 쪽으로 새 queue를 만들지 않는가?
2. 더미 queue가 실제로 `move_to`만 유지되는가?
3. 그래도 `move_to`가 실이동을 못 하면 deterministic mover를 도입해야 하는가?
