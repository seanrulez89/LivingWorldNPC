# 3인 동료 분대 전투 기반 구현 기록 (폐기된 Bandits-backed 버전)

작성일: 2026-06-14  
대상: Project Zomboid Build 42.18 싱글플레이, 당시 Bandits2 carrier
상태: 2026-06-16 이후 런타임 설계로는 폐기됨. 이 문서는 외부 모드 의존
전환기에 작성된 역사적 구현 기록이며, 현재 실행 경로는 LWN 자체 managed
`IsoZombie` carrier다.

## 현재 대체 기준

현재 구현과 테스트 기준은
`docs/current/MANAGED_ISOZOMBIE_INDEPENDENCE_2026-06-16.md`가 우선한다.

- 활성 companion carrier는 `isozombie`다.
- Bandits brain, task, cache, `AreEnemies`, `ApplyVisuals` wrapper는 현재
  런타임 계약이 아니다.
- `LWN.Combat`는 교전 허용 여부를 판단하고, LWN carrier가 이동과
  `attack_melee` 실행을 직접 담당한다.
- `TEST RESET`은 LWN record, actor, cache, pending state, combat runtime을
  정리한다.
- 일반 Bandits NPC 회귀 검증은 현재 기본 검증 범위가 아니다. Bandits
  관련 문서는 외부 참고 및 과거 의사결정 기록으로만 유지한다.

아래 내용은 당시 설계 의도와 데이터 계약을 추적하기 위한 역사 기록이다.
현재 런타임을 수정할 때 직접 따라야 하는 실행 계획으로 사용하지 않는다.

## 당시 목표

플레이어와 최대 3명의 LWN 동료를 `player-team-0` 분대로 묶는다. 동료는 한 명씩 생성하며 고유 이름, 분대 슬롯, 근접 무기, 전투 성향을 가진다. 플레이어의 우호 동료 공격은 무효화하지만 일반 좀비의 공격은 실제 체력 감소와 사망으로 이어져야 한다.

당시 계획은 Bandits의 전투 task 실행기를 재사용하는 것이었다. 교전 여부와 명령 우선순위는 LWN canonical record가 결정하며 Bandit brain은 현재 교전 상태를 전달하는 폐기 가능한 런타임 표현으로 취급했다. 이 실행 방식은 현재 기본 경로에서 제거되었다.

## 데이터 계약

- `record.companion.teamId`: 현재는 `player-team-0`.
- `record.companion.squadSlot`: 1~3. 빈 슬롯은 동료 사망 후 재사용한다.
- `record.companion.command.combatPolicy`: `avoid`, `self_defense`, `assist`, `stance`.
- `record.combat.disposition`: `aggressive` 또는 `passive`.
- `record.combat.state`: `idle` 또는 `engaged`.
- `record.combat.reason`: 현재 상태를 만든 위협 또는 명령 사유.
- `record.combat.maxHealth`: 최초 결합 actor의 실제 최대 체력 기준값.
- 마지막 위협 좌표와 교전/해제 시각은 `record.combat`에 남긴다.

기존 저장은 `Schema.ensureNPCRecordShape`의 기본값 보충으로 읽는다. 별도 일괄 마이그레이션은 하지 않는다.

## 명령 우선순위

| 명령 | combatPolicy | 동작 |
| --- | --- | --- |
| 플레이어 추종 | `stance` | NPC 성향에 따라 선제 또는 팀 방어 교전 |
| 지정 위치 이동 | `self_defense` | 선제 교전 금지, 직접 공격받을 때만 대응 |
| 제자리 대기 | `self_defense` | 선제 교전 금지, 직접 공격받을 때만 대응 |

전투는 이동 명령을 삭제하지 않는 interrupt다. 당시 구현에서는 교전 시작 시 Bandits 이동 task만 비우고 LWN intent와 command는 유지하는 방식을 썼다. 현재 구현은 외부 task 대신 LWN carrier 내부 path, movement mode, attack state를 직접 정리하고 재개한다.

## 전투 성향

### 호전적

- `stance` 정책에서 보이는 일반 좀비가 8타일 이내면 교전한다.
- 플레이어와 12타일 넘게 떨어졌거나 3초간 유효한 위협이 없으면 교전을 종료한다.
- 당시에는 Bandits의 기존 수적 열세 후퇴 판단을 유지하는 것으로 계획했다.

### 수동적

- 평상시에는 좀비를 적으로 분류하지 않고 플레이어 추종을 계속한다.
- 6타일 안에서 플레이어가 좀비를 공격하거나, 좀비가 플레이어/분대원을 표적으로 삼거나, 분대원이 실제 피격되면 합류한다.
- 팀 방어 신호는 마지막 사건 뒤 4초간 유지한다.
- 자신이 직접 공격받으면 현재 명령과 성향에 관계없이 자기방어한다.

## 당시 Bandits 경계 (현재 폐기)

- `brain.lwnControlled`: LWN이 통제하는 actor 표식.
- `brain.lwnCombatEngaged`: `BanditUtils.AreEnemies`가 일반 좀비를 적으로 취급할지 결정하는 게이트.
- LWN과 일반 좀비는 교전 중에만 적이다.
- LWN끼리, LWN과 플레이어, LWN과 다른 Bandit은 당시 버전에서 적이 아니다.
- `hostile`, `hostileP`, `loyal`은 계속 false로 유지한다.
- Bandits 음성, 자동 무기 탐색, 자동 보급은 계속 차단한다.
- 슬롯 1~3은 각각 `Base.BaseballBat`, `Base.Hammer`, `Base.Crowbar`를 사용한다.

현재 구현에서는 위 brain/task 경계를 사용하지 않는다. 대응되는 현재 표식은
actor `ModData`의 LWN 전용 필드와 canonical `record.combat` 상태다.

## 피해와 체력

- 평상시 `GodMod`, `Invulnerable`, `AvoidDamage`는 false이며 `Shootable`은 true다.
- 실제 플레이어 공격 이벤트에만 세 보호 플래그를 임시 활성화하고 canonical health로 3 tick 복구한다.
- 일반 좀비 공격은 복구 큐를 만들지 않는다. 당시에는 actor health를 `record.stats.health`와 `brain.health`에 동기화했다.
- 당시 `Bandit.ApplyVisuals` wrapper는 LWN actor의 호출 전 체력을 복원해 프로필 체력으로 되감기는 현상을 막았다.
- 체력 0 이하는 기존 EmbodimentManager death latch와 corpse cleanup 경로가 처리한다.
- 감염, 부위별 상처, 치료 UI는 후속 범위다.

## 테스트 하네스

- `Spawn Aggressive Companion`, `Spawn Passive Companion` 메뉴로 한 명씩 생성한다.
- 동시 pending spawn은 하나만 허용한다.
- 살아 있는 테스트 동료가 3명이면 생성을 차단한다.
- 상태는 `npcIds`, `pendingNpcId`, `selectedNpcId`로 관리한다.
- 생성 결합 직후 기본 `follow_player` intent를 발행한다.
- NPC 우클릭 메뉴에서 성향을 확인하고 전환할 수 있다.
- 상태창은 팀, 슬롯, 성향, 교전 상태, 명령 전투 정책을 표시한다.
- 당시 `TEST RESET`은 모든 테스트 record, actor, Bandit cache/brain, pending spawn, 팀 위협 런타임을 정리했다. 현재 RESET은 LWN 자체 carrier 상태만 정리한다.

## 인게임 합격 시나리오

1. 호전적/수동적을 섞어 세 명을 순차 생성하고 이름, ID, 슬롯 무기를 확인한다.
2. 플레이어가 각 NPC를 근접 공격, 밀치기, 바닥 공격해도 체력이 감소하지 않는지 확인한다.
3. 일반 좀비가 NPC를 공격하면 체력이 감소하고 외형 갱신 뒤에도 회복되지 않는지 확인한다.
4. 반복 공격 또는 다수 좀비로 NPC가 실제 사망하는지 확인한다.
5. 호전적 NPC가 8타일 내 좀비와 먼저 싸우고 전투 후 추종을 재개하는지 확인한다.
6. 수동적 NPC가 무관한 좀비를 지나치지만 플레이어/분대 교전에는 합류하는지 확인한다.
7. 지정 이동과 대기 중 선제 교전하지 않고 직접 자기방어만 하는지 확인한다.
8. 한 NPC 사망 뒤 나머지 두 명이 정상 동작하고 빈 슬롯에 새 NPC를 생성할 수 있는지 확인한다.
9. RESET 뒤 actor, brain/cache, record가 남지 않고 다시 세 명을 생성할 수 있는지 확인한다.
10. 당시 외부 Bandits NPC의 적 판정, 피해, 전투, 보급이 기존과 같은지 확인한다.

## 정적 검증

- `scripts/validate-mac.sh`
- 전체 Lua `luac -p`
- `git diff --check`

정적 검증은 엔진 이벤트 순서와 실제 인게임 전투 애니메이션을 증명하지 못한다. 현재 인게임 시나리오는 `[LWN][Combat]`, `[LWN][CarrierIsoZombie]`, `[LWN][ShellProbe]`, `[LWN][Log] domain=Combat`, `[LWN][Log] domain=Movement` 전환 기록을 함께 확인해야 한다. `[LWN][Bandits]` 런타임 로그가 나오면 현재 독립 carrier 기준에서는 실패로 본다.
