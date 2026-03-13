# Test Log History

This file is the running narrative for in-game test results.

## Purpose

Track each meaningful test cycle in a way that preserves causality:

1. what was tested
2. what happened in-game
3. what the logs showed
4. what hypothesis or lesson was derived
5. what code/doc changes followed
6. what the next expected check should be

## Entry format

For every new test cycle, append a new section using this structure:

```md
## YYYY-MM-DD HH:MM KST — Short title

### In-game result
- ...

### Log signals
- ...

### Interpretation / lesson
- ...

### Code or document changes that followed
- ...

### Next thing to verify
- ...
```

## Notes

- Keep entries append-only.
- Prefer concrete observations over vague summaries.
- If an observation later turns out to be wrong, do not erase it; append a correction in a later entry.
- This file is intended to help large refactors keep contact with actual test evidence.
- Use this file for cross-day test/result continuity; do not keep appending new-day technical work into an older `WORK_NOTES_YYYY-MM-DD.md` file.

## 2026-03-13 09:14 KST — Best-so-far test, alive actor still invisible

### In-game result
- 사용자 관찰 기준 이번 테스트는 지금까지 중 가장 좋았다.
- NPC 자체는 여전히 화면에 보이지 않았다.
- 대신 이전에 거슬리던 corpse flicker, stale target, delete crash, death overlap은 체감상 많이 줄어든 편이었다.

### Log signals
- 최신 `console.txt`에는 이번 구간 기준 `ERROR`, `Exception`, Lua stack trace가 보이지 않았다.
- 로그 보존 구간은 생성 직후가 아니라 이미 embodied 상태인 `LWN-000037`의 runtime부터 시작했다.
- 살아 있는 동안 `LWN-000037`는 약 5.7초 동안 계속 아래 상태를 유지했다.
- `world=true`, `ghost=false`, `invisible=false`, `sceneCulled=false`, `alpha=1.00`, `targetAlpha=1.00`
- `humanVisual=true`, `actorDescriptor=true`, `itemVisuals=5`, `wornItems=3`, `persistentOutfitId=0`
- `PresentationGuard`도 계속 `status=already_set`만 남겼고, alpha zero나 false-flag repair는 필요하지 않았다.
- death 전환은 `t=1773360836224` 근처에서 같은 `IsoPlayer{ ID:93 }`에 대해 `health=0.00`, `dead=true`, `deathLike=true`로 바뀌며 감지됐다.
- 같은 순간 `DeathTrace`는 별도 `IsoZombie{ ID:38 }`를 같은 square에서 잡았고, `sameActorRef=false`, `sameNpcId=false`였다.
- death 이후 cleanup 전까지 `corpseSeen=false`가 계속 유지됐고, 약 0.58초 뒤 `death_timeout_cleanup`가 실행됐다.
- cleanup 흐름은 `ui_targets.cleared -> record.deactivated -> actor.cleanup.complete -> unregisterActor.complete -> registry.cleared` 순으로 끝까지 이어졌다.
- cleanup 뒤에는 `ContextTrace stage=candidate.rejected | reason=leftover_death_object`가 남아, 남은 zombie가 NPC 컨텍스트 타깃으로 재채택되지는 않았다.

### Interpretation / lesson
- 이번 로그는 "안 보이는 이유가 alpha/ghost/invisible/scene-cull/simple visual-missing 쪽은 아니다"를 더 강하게 지지한다.
- 살아 있는 embodied actor는 논리적으로는 이미 꽤 정상이다. 따라서 1순위는 여전히 alive presentation/render path 자체다.
- 특히 Build 42에서 현재 `IsoPlayer` 기반 embodied NPC가 world 등록과 visual data를 갖고도 실제 draw path에 오르지 않거나, model/render registration 층에서 누락될 가능성이 가장 크다.
- stale target 관점에서는 개선 신호가 있다. cleanup에서 UI target이 먼저 정리되고, 이후 leftover zombie도 candidate에서 거절됐다.
- delete crash는 이번 테스트에서 직접 `debug.delete.request`가 실행된 흔적은 없어서 "완전 해소"라고 단정할 수는 없다. 다만 같은 cleanup contract를 쓰는 death cleanup은 예외 없이 끝났다.
- corpse flicker는 이번 로그만 보면 줄어든 편이다. corpse/player/zombie가 교대로 튀는 패턴은 없었고, 대신 "dead IsoPlayer + separate IsoZombie 동시 존재"가 짧게 나타났다.
- death overlap은 완전히 사라지지 않았다. corpse를 보지 못한 채 원래 actor가 잠깐 남아 있고, 별도 zombie가 같은 칸에 생긴다.

### Code or document changes that followed
- 이번 턴은 런타임 코드 수정 없이, 최신 로그 분석 결과를 문서에만 반영했다.
- `docs/WORK_NOTES_2026-03-11.md`에 최신 테스트 기준 남은 1순위와 후속 개선 포인트를 추가했다.

### Next thing to verify
- alive 상태의 `IsoPlayer` embodied actor가 실제 render/model registration에 올라가는지 별도 trace를 추가해 확인한다.
- death 시점에 separate zombie가 확인되면 원래 death-like actor를 더 빨리 정리할 수 있는지 본다.
- 다음 테스트에서는 생성 직후 `ActorFactory`와 `OnCreate*` 구간이 콘솔에 남도록 로그 보존 범위를 확보한다.
