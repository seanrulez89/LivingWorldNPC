# Minimal Dummy Patch 2 — Relationship / Story / Goal Bypass — 2026-03-28

## 목표

`record.dummy.enabled == true`인 레코드가 기존 NPC 시스템의 관계/스토리/목표/유틸리티 흐름에 오염되지 않도록 차단한다.

이번 패치는 아직 런타임을 완전히 `idle / move_to`만으로 재작성하는 단계는 아니지만,
그 전 단계로서 **dummy record를 기존 social NPC 해석에서 분리**하는 역할을 한다.

## 이번에 바뀐 것

### 1. Social layer

- `13_LWN_Social.lua`
- 추가:
  - `Social.isMinimalDummyRecord(record)`
  - `Social.minimalDummyPolicy(record)`
- 효과:
  - dummy record는 항상 neutral dummy 정책만 사용
  - trust/resentment 조정 무력화
  - commandResponse는 즉시 accept
  - betrayalScore는 사실상 비활성
  - canRecruit는 false
  - forceRelationshipCombatPolicy도 dummy에서는 no-op 성격으로 neutral dummy policy 반환
  - maybeSuggest는 nil

### 2. Goal layer

- `16_LWN_GoalSystem.lua`
- dummy record는 `idle` goal 하나만 유지
- `support_player`, `storyArc`, `seek_*`, `escape_area` 등은 더 이상 dummy에 생성되지 않음

### 3. Utility layer

- `17_LWN_UtilityAI.lua`
- dummy record는 `dummy_idle` candidate만 가지도록 축소
- 기존 trust/story/panic 기반 scoring을 타지 않음

### 4. Behavior layer

- `18_LWN_BehaviorTree.lua`
- dummy record는 behavior tree에서 사실상 항상 `idleObserve`만 반환
- follow/guard/retreat/search/story 행동으로 확장되지 않음

### 5. Carrier policy layer

- `35_LWN_Carrier_IsoZombie.lua`
- local `relationshipCombatPolicy(record)`가 먼저 dummy 여부를 보고
  `Social.minimalDummyPolicy(record)`를 우선 사용하도록 변경
- 즉 harness/legacy social 흐름보다 dummy neutral policy가 상위가 됨
- humanization profile도 dummy는 `neutral_dummy`로 기록

### 6. EventAdapter decision layer

- `90_LWN_EventAdapter.lua`
- goal update는 이제 dummy context를 함께 전달
- embodied decision source도 dummy 기준으로 분리됨:
  - `dummy_suppressed_combat`
  - `dummy_command_queue`
  - `dummy_idle`
- 즉 로그상으로도 old non-hostile companion 흐름과 dummy 흐름이 구분되기 시작함

## 이번 패치가 아직 하지 않은 것

- deterministic movement motor
- generation-based single-active-shell recovery
- failed-shell rebuild 중심 spawn lifecycle
- full dead-code deletion
- action runtime의 complete dummy-only rewrite

즉 이번 패치는 **Patch 3으로 넘어가기 위한 backend 우회층**이다.

## 기대 효과

다음 단계부터 dummy record는 최소한:

- trust / betrayal / recruited / hostile drift
- story goal
- support_player goal
- follow/guard/retreat/search behavior

같은 기존 NPC 논리에 덜 끌려간다.

이제 다음 단계는 런타임을 정말로 `idle / move_to` 중심으로 줄이는 것이다.
