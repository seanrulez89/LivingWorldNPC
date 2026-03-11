# LivingWorldNPC Work Notes

Date: 2026-03-11

## 작업 목표
- 최우선: embodied NPC가 월드에 실제로 보이도록 시각적 실체화 경로를 보강한다.
- 병행: 로그/주석/디버그 도구/문서를 강화하고, MD에 적혀 있던 일부 디버그·스토리 기능을 구현한다.

## 코드 근거 기반 관찰
- 로컬 `console.txt` 기준 최근 테스트에서는 `ActorFactory`가 embodied 직후 다음을 남겼다.
  - `world=true`
  - `ghost=false`
  - `invisible=false`
  - `sceneCulled=false`
  - `alpha=1.00`
- 따라서 "월드에 없어서 안 보임"만으로는 현재 증상을 설명하기 어렵다.
- 남은 직접 후보는:
  - descriptor가 실제 body mesh / human visual로 반영되지 않음
  - worn item 변경이 model refresh로 이어지지 않음
  - ModelManager 쪽 렌더 등록/리셋이 누락됨

## reference_mods 재검토 메모
- Bandits `shared/Bandit.lua`
  - `Bandit.ApplyVisuals()`에서 `getHumanVisual()`, `getItemVisuals()`, `getWornItems():clear()`, `setFemaleEtc()`, `resetModel*()`를 강하게 묶는다.
- BanditsCreator `OptionScreens/*`
  - `IsoPlayer.new(...)` 직후 `setFemale(...)`, `getHumanVisual():setSkinTextureIndex(...)`, `setWornItem(...)`를 직접 호출한다.
  - preview actor는 world actor의 직접 레퍼런스가 아니다.

## 이번 패치에서 넣은 것
- `23_LWN_ActorFactory.lua`
  - `visualSummary` 로그 추가.
  - `ModelManager.instance:Add/Reset/ResetNextFrame/ResetCharacterEquippedHands` 재호출.
  - `Dressup(desc)` / `InitSpriteParts(desc)` / `setFemale(...)` / `onWornItemsChanged()` 보강.
  - worn item 적용 시 `ItemBodyLocation.get(ResourceLocation.of(...))` 경로 fallback 추가.
- `24_LWN_ActorSync.lua`
  - embodied actor에 gender/NPC/visibility flag를 매 tick 재강제.
- `90_LWN_EventAdapter.lua`
  - `OnCreateSurvivor`에서도 visual refresh 경로 재사용.
  - `EveryTenMinutes`에서 clue 생성과 world event 적재 시작.
  - `OnKeyPressed` 기반 디버그 핫키 연결.
- `92_LWN_DebugTools.lua`
  - nearest NPC dump
  - wipe + reseed
  - relationship cheat
  - story beat inject
  - force legacy candidate
  - F3-F8 hotkey
- `20_LWN_ActionRuntime.lua`
  - `record.goals.currentPlan/currentIntent` 미러링으로 상태 관측성 향상.

## 공식 자료 근거
- Project Zomboid official modding docs
  - `ILuaGameCharacter.Dressup(SurvivorDesc)`
    - https://projectzomboid.com/modding/zombie/characters/ILuaGameCharacter.html
  - `ModelManager.Add`, `ContainsChar`, `Reset`, `ResetNextFrame`
    - https://projectzomboid.com/modding/zombie/core/skinnedmodel/ModelManager.html
  - `IsoPlayer` API surface
    - https://projectzomboid.com/modding/zombie/characters/IsoPlayer.html
- Project Zomboid official blog / update note
  - Build 42 unstable branch announcement
    - https://projectzomboid.com/blog/news/2024/02/unstable-branch-for-build-42/

## 다음 수동 검증 포인트
1. 새 또는 초기화된 세이브에서 F4로 debug NPC를 1명 생성한다.
2. `console.txt`에서 `actor state` 바로 아래 `actor visuals`를 확인한다.
3. `itemVisuals`, `wornItems`, `skin`, `hair`, `beard`, `persistentOutfitId` 값이 비정상적으로 비어 있는지 본다.
4. F5로 nearest NPC summary를 덤프해 `state`, `goal`, `intent`를 확인한다.
5. 여전히 투명하면 same-frame 이후 로그에 `ModelManager refresh`와 `actor visuals` 변화가 있는지 비교한다.

## Stage 3 최소 패치 메모
- 이번 턴은 세 후보 중 `worn items -> item visuals/body visual graph 갱신 문제`만 겨냥했다.
- 겨냥 stage:
  - `createActor.world_registered` 이후
  - `refreshEmbodiedPresentation.ready` 이전
  - 새 trace stage: `refreshEmbodiedPresentation.item_visual_bridge`
- 의도:
  - `wornItems > 0`인데 `itemVisuals == 0`인 경우에만, worn clothing에서 item visual을 한 번 보수적으로 다시 구성한다.
  - 이미 `itemVisuals`가 있으면 건드리지 않는다.
  - 즉, 기존 descriptor/model refresh 경로를 뒤엎지 않고 "body/item visual graph가 비어 있는가"만 분리 관측한다.
- 이번 패치의 핵심 판정 필드:
  - `mode=rebuilt_from_worn_items`
  - `wornItems=...`
  - `itemVisualsBefore=0`
  - `itemVisualsAfter>0`
  - `added=...`
- 성공으로 단정하지 않는다. 이 stage 이후에도 여전히 안 보이면 다음 유력 후보는 descriptor -> human visual 직접 반영 쪽이다.

## 추가 작업 메모: 레퍼런스 재학습
- 이번 턴은 런타임 코드 수정 대신 `reference_mods` 재검토를 우선했다.
- 새로 추가된 `reference_mods/3001908830/mods/PZNS_Framework`를 포함해 Bandits, BanditsWeekOne, BanditsCreator, PZNS를 다시 읽었다.
- 별도 분석 문서:
  - `docs/REFERENCE_STUDY_2026-03-11.md`
- 현재 중간 결론:
  - Bandits는 world entity + visual rebuild에 강한 근거를 준다.
  - BanditsCreator는 preview actor 예시라서 world embodiment 근거로 오용하면 위험하다.
  - PZNS는 manager/context menu/template 구조는 참고 가치가 높지만 Build 41 save/load, ghost-mode unload, OnRenderTick AI는 Build 42 LWN에 그대로 가져오면 위험하다.

## 작업 플로우 고정 메모
- WSL에서는 PowerShell 검증보다 `./scripts/validate-wsl.sh`를 기본 검증 경로로 사용한다.
- 메인 저장소에서는 `reference_mods/` 원본 스냅샷을 추적하지 않고, 분석 문서만 유지한다.
- 아직 남은 핵심 작업:
  - 인게임 재테스트 + `EmbodimentTrace` 로그 수집
  - Stage 3 최소 패치의 가설 판정
  - 그 결과에 따라 다음 최소 패치 방향 결정
  - `lua5.4`/`luac5.4` 설치 후 Lua 문법 검사 활성화
