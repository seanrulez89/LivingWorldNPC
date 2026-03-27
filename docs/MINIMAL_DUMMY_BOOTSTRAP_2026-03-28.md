# Minimal Dummy Bootstrap — 2026-03-28

## 왜 이게 첫 작업인가

대수술 전체 계획을 고려하면, 가장 먼저 해야 할 일은
기존 시스템을 한 번에 다 뜯는 것이 아니라
**실험 표면을 minimal neutral dummy 기준으로 좁히는 것**이다.

이번 첫 패치는 그 목적에 맞춰 다음을 먼저 정리한다.

- 새 구현 브랜치 시작
- debug/test UI에서 관계/신뢰/legacy 실험 메뉴 제거
- debug spawn을 minimal dummy baseline으로 표기
- 자동 테스트 시 기본 harness를 `forceFriendly` 없이 시작
- radial interaction도 move/wait/panel만 남겨 실험 노이즈 축소

## 이번 패치의 범위

### 포함

- `spike/minimal-neutral-dummy` 브랜치 생성
- `26_LWN_UI_ContextMenu.lua`
  - "Minimal Dummy Test" 기준으로 메뉴 이름 정리
  - trust/friendly/neutral/hostile 관련 메뉴 제거
  - legacy carrier submenu 제거
- `27_LWN_UI_RadialMenu.lua`
  - `Move`, `Wait`, `Panel`만 남김
  - minimal dummy record는 social acceptance 없이 바로 명령 수락
- `92_LWN_DebugTools.lua`
  - debug harness 기본값을 관계 실험 대신 minimal dummy baseline으로 조정
  - debug spawn 시 `record.dummy` 상태 생성
  - spawn 시 forced-friendly policy sync 제거
  - command move 시 dummy state 기록
  - automation scenario 이름을 minimal dummy 기준으로 갱신

### 아직 포함하지 않음

- relationship / story / goal runtime의 실제 삭제
- carrier/runtime/event layer의 full dummy-only rewrite
- deterministic mover
- generation identity
- recovery rebuild policy

즉 이번 패치는 **구조 대수술 전의 실험 lane 정리** 단계다.

## 기대 효과

1. 메뉴/UI에서 관계 실험 노이즈가 줄어든다.
2. 새 실험 브랜치가 기존 branch history와 분리된다.
3. debug spawn 자체가 minimal dummy baseline으로 더 명시된다.
4. 다음 패치부터 관계/목표 active path 제거를 더 안전하게 시작할 수 있다.

## 다음 패치 목표

다음 실제 코드 패치는 아래 둘 중 하나가 아니라 둘 다 가야 한다.

1. `relationship/story/goal` active path를 dummy record에서 완전히 우회하기
2. runtime를 `idle` / `move_to` 중심으로 줄이기

그 전까지는 이번 패치가 "테스트 출발점 정리" 역할을 한다.
