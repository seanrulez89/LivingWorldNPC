# LivingWorldNPC Actor-Class A/B Spike Plan — 2026-03-27

## 목적

현재 embodiment/materialization 병목이 `actor-class mismatch`인지 빠르게 확인하기 위한
**소형 스파이크 실험 계획**이다.

이 문서는 리라이트 계획이 아니라, 메인라인 작업과 병행 가능한
짧은 비교 실험의 기준을 고정하기 위한 것이다.

---

## 비교 대상

### A안 — 현재 메인라인

- carrier: `IsoZombie`
- 접근: managed shell contract + persistent illusion + movement telemetry + recovery cache 강화

### B안 — 대체 carrier 스파이크

- 후보 1: `IsoPlayer`
- 후보 2: 그 외 player-like human presentation carrier
- 목적:
  - alive-state human presentation이 더 자연스러운지
  - movement authority가 더 잘 맞는지
  - recovery / relink 비용이 오히려 커지는지

---

## 반드시 같은 조건에서 비교할 것

1. 같은 NPC record seed
2. 같은 spawn 위치
3. 같은 TEST 01 / 02 / 03 흐름
4. 같은 debug harness 설정
5. 같은 로깅 포맷

---

## 성공 판정 기준

### 1차 기준 — embodiment

- spawn 직후 actor가 월드에 안정적으로 존재한다
- alive-state에서 **보인다**
- zombie-like audio/combat leak가 적다

### 2차 기준 — locomotion

- `move_to` 명령 후 실제 square가 변한다
- `moving=true + path2=true + delta≈0` 상태가 지속되지 않는다
- orientation / turning이 최소한 body에 반영된다

### 3차 기준 — continuity

- stream out / return 후 같은 actor를 relink하기 쉽다
- rogue shell + replacement shell split가 덜하다

---

## 실패 판정 기준

- actor는 존재하지만 alive-state visual이 깨진다
- path는 돌지만 실이동이 없다
- 멀티/authority 비용이 너무 커진다
- recovery가 오히려 더 불안정해진다

---

## 최소 수집 로그

- actor class / carrier kind
- spawn success / runtime ready
- shell contract lane
- x/y/z delta
- currentSquare changes
- path2 exists
- isMoving
- walkType
- canWalk / useless
- recovery source
- cached shell hit/miss

---

## 실행 원칙

- 메인라인 안정화 작업을 멈추지 않는다.
- B안 스파이크는 **짧고 버릴 수 있게** 만든다.
- 비교 질문은 딱 3개만 유지한다.
  1. 더 잘 보이는가?
  2. 더 잘 움직이는가?
  3. recovery 비용이 낮은가?

이 셋 중 2개 이상이 명확히 좋아지지 않으면,
대체 carrier는 메인라인 전환 후보로 승격하지 않는다.
