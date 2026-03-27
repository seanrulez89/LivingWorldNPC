# Minimal Dummy Step B-full — Appearance Path Replacement and Visual Truth Gate — 2026-03-28

## 목표

Step A와 Step C 이후 minimal dummy는 다음을 처음으로 달성했다.

- zombie vocal suppression
- aggression suppression
- real displacement via deterministic movement

하지만 외형은 여전히 유저 눈에 zombie처럼 보였고,
기존 debug summary는 다음처럼 너무 낙관적으로 보였다.

- `humanInit=yes`
- `probeOk=yes`

실제 최신 로그는 이 false positive를 직접 보여줬다.

- `role=reanimated_zombie`
- `humanInit=true`
- `skin=nil`
- `itemVisuals=5`
- yet probe previously passed

즉 Step B-full의 목적은 두 가지다.

1. **spawn 초기 경로를 더 강한 rebuild / reapply 쪽으로 교체**한다.
2. **시각적 진실과 더 가까운 probe 기준**으로 성공/실패를 다시 판정한다.

---

## 이번에 바뀐 것

### 1. ShellHumanizer.maintain can now really do full reapply after bootstrap

- `42/media/lua/client/37_LWN_ShellHumanizer.lua`

기존 문제:
- `maintain(... forceFull=true, forceInitial=true)`를 호출해도
  initial state가 아직 없으면 `applyInitial(...)`만 실행하고 곧바로 return 했다.
- 즉 이름은 rebuild처럼 보여도,
  실제론 "initial만 한 번 더" 하고 끝나는 경우가 있었다.

변경 후:
- bootstrap initial을 먼저 수행하되,
- `forceFull=true`이면 거기서 return하지 않고
  full reapply 단계까지 계속 진행한다.

이 변화는 중요하다.
왜냐하면 이제 dummy rebuild가 정말로
`maintenance_full_reapply`까지 도달할 수 있기 때문이다.

### 2. stricter visual-truth probe added for minimal dummy

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

이전 probe 문제:
- `humanInit=true`만으로도 통과될 수 있었고,
- `appearanceDetail.applied=true`만으로도 통과될 수 있었다.
- 그래서 실제론 zombie-looking shell인데도 summary상으로는 성공처럼 보였다.

변경 후 dummy probe 기준:
- descriptor 존재
- humanVisual 존재
- `skin != nil`
- `itemVisuals > 0` 또는 `wornItems > 0`
- `LWN_HybridAppearanceApplied == true`

즉 minimal dummy는 이제
**실제 visual 재료가 더 분명히 올라간 경우만 성공**으로 본다.

추가 기록:
- `LWN_HumanizationProbeWornItems`
- `LWN_HumanizationProbeHybridApplied`
- `LWN_HumanizationVisualTruthOk`

### 3. dummy appearance lifecycle state was expanded

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

이전에는:
- `appearanceLocked`
- `initialAppearanceOk`
정도만 있었다.

이제는:
- `appearanceLocked`
- `appearanceFailed`
- `appearanceRebuildPending`
- `appearanceFailureCount`
- last probe source/detail/at

까지 기록한다.

의미:
- 이제 dummy shell은 단순히 "성공/실패"가 아니라,
  **외형 재구축이 더 필요한 shell인지 아닌지**를 lifecycle로 추적할 수 있게 됐다.

### 4. initial spawn path for minimal dummy now prefers rebuild-based appearance work

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

기존:
- spawn 시 generic humanization pass 실행
- 실패하면 dummy rebuild fallback 시도

변경 후:
- minimal dummy spawn는 처음부터
  `buildInitialDummyAppearance(...)`
  기반 경로를 사용한다.
- 즉 dummy는 generic path를 먼저 믿지 않고,
  **초기부터 reapply/rebuild 중심 경로**를 타게 된다.

### 5. sync-time rebuild retry added for unresolved dummy appearance

- `42/media/lua/client/35_LWN_Carrier_IsoZombie.lua`

dummy가 아직:
- appearanceLocked != true
- 또는 appearanceRebuildPending == true

이면 sync 시점에도 rebuild path를 다시 탄다.

의미:
- spawn 한 번 실패했다고 그대로 포기하지 않고,
  **minimal dummy가 visually unresolved state면 sync에서도 다시 외형 재구축을 시도**한다.

### 6. debug summary now exposes appearance lock/failure state

- `42/media/lua/client/92_LWN_DebugTools.lua`

MOVE SUMMARY에 추가:
- `appLock`
- `appFail`

그리고 TEST 01/02 checklist 문구도 dummy lane 기준으로 조정했다.

이제 다음 테스트에서 바로 볼 수 있다.

- `probeOk=yes`
- `appLock=yes`
- `appFail=no`

이 조합이 나와야 "summary상 외형 성공"이라고 읽을 수 있다.

---

## 왜 이 패치가 필요한가

이번 minimal dummy branch는 movement/audio/aggression 쪽에서 처음 진전을 냈다.
하지만 외형은 여전히 유저가 zombie로 인식했다.

이 말은 이제 문제를 다음처럼 분리해서 볼 수 있다는 뜻이다.

### 이미 어느 정도 해결된 것

- dummy가 공격하지 않게 만들기
- zombie vocal을 조용하게 만들기
- 실제 위치 이동 만들기

### 아직 남은 가장 큰 문제

- visual shell이 인간처럼 읽히는가
- summary의 success flag가 실제 시각 결과를 반영하는가

즉 Step B-full은 "예쁘게 보이게 해보자" 수준이 아니라,
**이제 남은 주병목을 정면으로 다루기 위한 판정/경로 재설계**다.

---

## 기대 효과

다음 테스트에서 가장 먼저 보고 싶은 건 다음이다.

1. spawn 직후 `skin=nil` 상태를 더 이상 성공으로 치지 않는다.
2. `probeOk=yes`가 나오면 이전보다 실제 시각 결과와 더 가까워진다.
3. dummy가 unresolved appearance 상태면 sync rebuild가 추가로 시도된다.
4. 성공 시 `appLock=yes`, 실패 시 `appFail=yes`로 더 분명하게 읽힌다.

---

## 아직 안 한 것

- generation-based recovery rewrite
- failed shell에 대한 full rebuild lifecycle centralization
- deterministic mover의 arrived/stalled classification 추가 보강
- dead code removal of old appearance paths

즉 Step B-full은
**외형 경로와 판정의 신뢰도를 올리는 단계**이고,
복귀/recovery 구조는 아직 이후 작업이다.
