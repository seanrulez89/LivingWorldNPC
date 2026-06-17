# LivingWorldNPC Test Failure Hardening Plan — 2026-03-27

## 왜 이 패치를 넣었나

2026-03-27 자동화 테스트에서 다음이 동시에 확인됐다.

- TEST 01부터 NPC가 완전한 zombie presentation으로 보임
- TEST 02/03에서 `moving=true`, `path2=true`인데 `totalDelta=0.00`
- commandable lane인데도 hold/neutralized 충돌 정황이 강함
- return 후 original shell은 roaming hostile zombie처럼 남고,
  origin에는 다른 stationary replacement shell이 남음
- audio suppression이 너무 강해서 actor-local을 넘어 전체 효과음 체감까지 해칠 가능성이 있음

이번 패치는 이 관찰을 기준으로 다음 6가지를 직접 완화하려는 목적이다.

1. command movement 시 hold-position 해제
2. commandable lane movement unlock 재강제
3. spawn humanization success/fail probe 추가
4. handle actor reclaim 경로 추가
5. ordinary-zombie cleanup 보호 강화
6. `audio_stopall` 축소 + watchdog 단순화

---

## 이번 코드 변경 요약

### 1. movement unlock

- `20_LWN_ActionRuntime.lua`
  - `releaseCommandMovementHold(...)` 추가
  - `_startMovement(...)` 진입 시 hold/quarantine를 강제로 해제
  - command movement 시작 사실을 record/modData에 기록

- `92_LWN_DebugTools.lua`
  - `issueDesignatedMoveCommand(...)`에서
    hold/quarantine를 먼저 풀고 command movement를 강제 허용

### 2. no-displacement watchdog 단순화

- `20_LWN_ActionRuntime.lua`
  - `moving && path2 && totalDelta<=0.05 && squareChanged=false`
  - 상태가 약 2.5초 지속되면
    `watchdog:path_only_statue` reason을 남기도록 변경

### 3. humanization probe / retry

- `35_LWN_Carrier_IsoZombie.lua`
  - `probeHumanizationState(...)` 추가
  - spawn/sync 후 probe 실행
  - spawn에서 probe 실패 시 1회 humanization retry 후 재검사
  - probe 결과를 handle runtime + modData에 남김

### 4. recovery handle reclaim

- `90_LWN_EventAdapter.lua`
  - `tryReclaimHandleActor(...)` 추가
  - `knownNpcId`, `shellMarker`, `managed shell contract`가 남아 있으면
    handle actor를 즉시 버리지 않고
    restamp + ensureInWorld + non-hostile recovery lane으로 재회수 시도

### 5. cleanup protection hardening

- `92_LWN_DebugTools.lua`
  - `clearNearbyWorldNoise(...)`에서
    npcId/marker/cache hit가 있는 actor는 ordinary zombie cleanup 대상에서 제외
  - 보호/삭제 이유를 콘솔 로그로 남김

### 6. audio suppression refinement

- `35_LWN_Carrier_IsoZombie.lua`
  - `stopZombieCodedAudio(...)`에서 `stopAll()` 제거
  - zombie-coded named sounds만 targeted stop
  - illusion/audio summary 문구도 `targeted_zombie_mute` 기준으로 갱신

---

## 다음 테스트에서 기대하는 변화

### TEST 01

- actor dump에서 `humanInit=true` 또는 probe 성공 정황이 더 자주 보여야 함
- full-zombie appearance가 계속되면 spawn humanization gate가 아직 부족하다는 뜻

### TEST 02 / TEST 03

- `hold=false`
- `totalDelta > 0.00`
- 또는 실패 시 최소한 `watchdog:path_only_statue`가 뜨면서
  statue-like path-only 실패가 명확히 찍혀야 함

### TEST 04

- `handle_reclaim_success` 또는 `handle_recovered`가 보이면 개선 신호
- `cached_miss + handle_rejected + candidate_missing`가 계속 뜨면 continuity는 여전히 미해결

### cleanup / audio

- `clean nearby ordinary zombie`가 managed shell을 지우지 말아야 함
- 게임 전체 효과음이 죽는 체감은 줄어야 함

---

## 아직 남는 리스크

- spawn humanization probe는 현재 “실전적 판정”에 가깝고,
  완전한 시각적 인간화 성공을 100% 보장하는 strict proof는 아님
- commandable lane unlock만으로 locomotion이 풀리지 않으면,
  다음 가설은 actor-state-machine / movement authority mismatch 쪽으로 더 좁혀짐
- handle reclaim이 늘어도 original shell 자체가 hostile logic을 되찾는다면
  recovery 후 추가 de-hostile repair가 더 필요할 수 있음

---

## 한 줄 결론

이번 패치는 ‘예쁘게 보이게’보다,
**실패 원인을 더 직접적으로 없애거나 드러내는 hardening pass**다.

다음 테스트의 핵심 질문은 딱 세 가지다.

1. hold를 풀면 실제로 한 칸이라도 움직이느냐?
2. spawn humanization 실패가 baseline에서 더 분명히 드러나느냐?
3. return 후 original shell을 버리지 않고 reclaim하느냐?
