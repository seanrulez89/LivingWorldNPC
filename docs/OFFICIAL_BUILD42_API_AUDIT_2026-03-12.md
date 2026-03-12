# Official Build 42 API Audit 2026-03-12

Project: LivingWorldNPC  
Focus: 공식 Project Zomboid modding 문서/위키 학습 + LWN Build 42 API 적합성 점검  
Scope: 인간형 캐릭터, `IsoPlayer`, `IsoZombie`, `SurvivorDesc`, `HumanVisual`, clothing / worn items / model refresh, world object lifecycle, death / reanimation / corpse

## 1. 이번 턴에 학습한 공식 문서 범위

출발점:

- https://pzwiki.net/wiki/Modding
- https://projectzomboid.com/modding/index.html

직접 따라간 주요 하위 문서:

- 공식 Java/Lua API
  - `IsoPlayer`: https://projectzomboid.com/modding/zombie/characters/IsoPlayer.html
  - `IsoSurvivor`: https://projectzomboid.com/modding/zombie/characters/IsoSurvivor.html
  - `IsoZombie`: https://projectzomboid.com/modding/zombie/characters/IsoZombie.html
  - `IsoGameCharacter`: https://projectzomboid.com/modding/zombie/characters/IsoGameCharacter.html
  - `SurvivorDesc`: https://projectzomboid.com/modding/zombie/characters/SurvivorDesc.html
  - `HumanVisual`: https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/HumanVisual.html
  - `ItemVisual`: https://projectzomboid.com/modding/zombie/core/skinnedmodel/visual/ItemVisual.html
  - `WornItems`: https://projectzomboid.com/modding/zombie/characters/WornItems/WornItems.html
  - `ModelManager`: https://projectzomboid.com/modding/zombie/core/skinnedmodel/ModelManager.html
  - `IsoDeadBody`: https://projectzomboid.com/modding/zombie/iso/objects/IsoDeadBody.html
  - `IsoMovingObject`: https://projectzomboid.com/modding/zombie/iso/IsoMovingObject.html
  - `IsoObject`: https://projectzomboid.com/modding/zombie/iso/IsoObject.html
  - `SurvivorFactory`: https://projectzomboid.com/modding/zombie/characters/SurvivorFactory.html
- 공식/준공식 위키 이벤트 및 클래스 문서
  - `OnCreateLivingCharacter`: https://pzwiki.net/wiki/OnCreateLivingCharacter
  - `OnCreateSurvivor`: https://pzwiki.net/wiki/OnCreateSurvivor
  - `OnZombieCreate`: https://pzwiki.net/wiki/OnZombieCreate
  - `OnZombieDead`: https://pzwiki.net/wiki/OnZombieDead
  - `OnDeadBodySpawn`: https://pzwiki.net/wiki/OnDeadBodySpawn
  - `OnClothingUpdated`: https://pzwiki.net/wiki/OnClothingUpdated
  - `IsoZombie`: https://pzwiki.net/wiki/IsoZombie
- 공식 개발 블로그
  - Build 42 unstable compatibility note: https://projectzomboid.com/blog/news/2024/11/build-42-unstable/
  - Build 43 / human NPC direction: https://projectzomboid.com/blog/news/2025/09/terminally-illinois/

## 2. 공식 문서에서 확인된 핵심 사실

### 2-1. 인간형 캐릭터 생성과 이벤트

- `IsoPlayer` 생성자는 공식 Javadocs에 존재한다. 즉, 객체 자체를 Lua에서 만드는 행위는 "메서드 수준"으로는 가능하다.
- 하지만 Build 42 공식 블로그 기준으로 인간형 NPC 본격 지원은 여전히 Build 43 이후 축이다. Build 42는 공식 human NPC framework가 아니다.
- `SurvivorFactory`와 `IsoSurvivor`도 공식 문서에 존재하며, `SurvivorFactory.InstansiateInCell(...)`는 `IsoSurvivor`를 반환한다.
- 위키 기준 `OnCreateSurvivor`는 `IsoSurvivor` 생성 이벤트다.
- 위키 기준 `OnCreateLivingCharacter`는 `IsoPlayer` 또는 `IsoSurvivor` 생성 시점에 호출된다.

정리:

- `IsoPlayer.new(...)` 자체는 가능
- 하지만 "공식적으로 지원되는 인간형 NPC 시스템"이라고 보기 어렵다
- `IsoPlayer` 경로를 쓰면서 생성 후처리를 `OnCreateSurvivor`에 기대는 것은 문서와 맞지 않는다

### 2-2. 외형, 의복, worn items, item visuals

- `IsoGameCharacter`는 `getHumanVisual()`, `getWornItems()`, `getItemVisuals()`, `setWornItem(...)`, `onWornItemsChanged()`, `resetModel()`, `resetModelNextFrame()`를 제공한다.
- `SurvivorDesc`는 `dressInNamedOutfit(...)`와 `getWornItems()`를 제공한다.
- `HumanVisual`는 `addClothingItem(ItemVisuals, Item)`와 각종 피부/헤어/수염/바디 비주얼 조작 메서드를 제공한다.
- `ItemVisual`는 `setItemType(...)`, `setClothingItemName(...)` 등을 제공한다.
- `WornItems`는 `getItemVisuals(ItemVisuals)`와 `setFromItemVisuals(ItemVisuals)`를 제공한다.
- 위키에는 `OnClothingUpdated(character)` 이벤트가 따로 있다.

정리:

- Build 42 공식 API는 `HumanVisual` / `WornItems` / `ItemVisuals`를 함께 쓰는 경로를 전제한다
- `WornItems -> ItemVisuals` 변환은 이미 공식 메서드가 있다
- 의복 변경 후 모델 갱신은 `onWornItemsChanged()` + model refresh 계열이 정석에 가깝다

### 2-3. 월드 오브젝트 / moving object 생명주기

- `IsoObject`에는 `addToWorld()`, `removeFromWorld()`, `isExistInTheWorld()`가 문서화되어 있다.
- `IsoMovingObject`에는 `removeFromSquare()`, `setCurrent(IsoGridSquare)`, `setMovingSquareNow()`가 문서화되어 있다.
- `IsoSurvivor`에는 `Despawn()`이 문서화되어 있다.
- `ModelManager`는 `Add`, `Reset`, `ResetNextFrame`, `ContainsChar`, `ResetCharacterEquippedHands` 등을 갖고 있다.
- `IsoGameCharacter.onCullStateChanged(...)` 문서에는 이 메서드를 직접 호출하지 말고 `ModelManager`가 호출한다고 적혀 있다.

정리:

- 월드 등록/해제는 `addToWorld/removeFromWorld/removeFromSquare` 같은 생명주기 API가 중심이다
- 렌더/모델 캐시는 `ModelManager`가 관리하지만, 이것이 canonical lifecycle은 아니다
- square/current 포인터를 수동으로 많이 만지는 코드는 특히 조심해야 한다

### 2-4. 사망, 시체, 리애니메이션

- `IsoGameCharacter`에는 `setHealth(...)`와 별도로 `die()`, `Kill(...)`, `becomeCorpse()`, `shouldBecomeCorpse()`, `shouldBecomeZombieAfterDeath()`가 문서화되어 있다.
- `OnZombieDead`는 좀비가 죽을 때 호출되며, corpse는 즉시 생성되지 않을 수도 있다고 위키가 설명한다.
- `OnDeadBodySpawn(deadBody)`는 `IsoDeadBody`가 실제 생성될 때 호출된다.
- `IsoDeadBody`는 `getHumanVisual()`, `getWornItems()`, `getItemVisuals()`, `reanimateLater()` 등을 제공한다.

정리:

- Build 42 공식 경로에서 "죽음"은 단순히 `health <= 0`가 아니다
- 시체 생성과 리애니메이션은 별도 객체와 별도 이벤트가 있다
- corpse/reanimation을 다루려면 `IsoDeadBody`까지 포함한 흐름을 봐야 한다

### 2-5. Build 42 쪽에서 특히 주의할 문서상 변화

- 공식 Build 42 unstable 공지에서는 B41 세이브와 모드가 B42와 호환되지 않는다고 명시한다.
- 위키의 `IsoZombie` / `OnZombieCreate` 문서는 Build 42에서 오브젝트 풀링 때문에 같은 `IsoZombie` 인스턴스가 재사용될 수 있고, `OnZombieCreate`가 재사용 시에도 호출될 수 있음을 경고한다.
- 공식 블로그 기준 human NPC는 Build 43 이후 큰 축이므로, Build 42에서 인간형 NPC 구현은 여전히 우회적이며 취약할 수 있다.

## 3. LWN과 대조했을 때의 핵심 시사점

검토한 주요 구현 위치:

- `42/media/lua/client/23_LWN_ActorFactory.lua`
- `42/media/lua/client/24_LWN_ActorSync.lua`
- `42/media/lua/client/25_LWN_EmbodimentManager.lua`
- `42/media/lua/client/90_LWN_EventAdapter.lua`

### 3-1. 가능한 것

- `IsoPlayer.new(cell, desc, x, y, z)`로 인간형 actor를 생성하는 시도 자체는 API 표면상 가능하다.
- `SurvivorDesc`를 만들고 `dressInNamedOutfit(...)`를 거친 뒤 `Dressup`, `InitSpriteParts`, `getHumanVisual`, `setWornItem`, `onWornItemsChanged`, `resetModel` 계열로 presentation을 정리하는 방향 자체는 공식 메서드 조합 안에 있다.
- `addToWorld/removeFromWorld`와 `isExistInTheWorld()`를 기준으로 embodied cache를 월드에 올리고 내리는 개념 자체는 가능하다.

### 3-2. 불가능하거나 매우 의심스러운 것

#### A. Build 42를 "공식 human NPC runtime"처럼 다루는 방향

관련 코드:

- `23_LWN_ActorFactory.lua:1294`

의미:

- LWN은 world actor를 `IsoPlayer.new(...)`로 직접 만든다.
- 공식 문서만 보면 생성자는 존재하지만, 공식 블로그는 Build 42 human NPC framework를 약속하지 않는다.
- 따라서 이 경로는 "가능한 메서드 호출"과 "공식적으로 안정 지원되는 시스템" 사이에 큰 간극이 있다.

판정:

- 매우 의심스러움

#### B. `IsoPlayer` 생성 후처리를 `OnCreateSurvivor`에 기대는 패턴

관련 코드:

- `90_LWN_EventAdapter.lua:226`
- `90_LWN_EventAdapter.lua:390`

근거:

- `OnCreateSurvivor`는 `IsoSurvivor` 생성 이벤트
- `OnCreateLivingCharacter`는 `IsoPlayer` 또는 `IsoSurvivor` 생성 이벤트

의미:

- LWN actor는 `IsoPlayer`인데, 이벤트 연결은 `OnCreateSurvivor`만 한다.
- 문서 기준으로는 맞는 후크가 아니다.

판정:

- 우선순위 높은 불일치

#### C. 죽음을 `setHealth(...)`와 내부 hidden/death-like 상태로만 취급하는 패턴

관련 코드:

- `23_LWN_ActorFactory.lua:1376`
- `24_LWN_ActorSync.lua:235`
- `23_LWN_ActorFactory.lua:1041`

근거:

- 공식 API는 `die`, `Kill`, `becomeCorpse`, `shouldBecomeCorpse`, `shouldBecomeZombieAfterDeath`
- corpse 생성은 `OnZombieDead`와 `OnDeadBodySpawn` 사이에 지연이 있을 수 있음
- `IsoDeadBody`는 별도 객체로 외형/착장/리애니메이션 API를 가짐

의미:

- `health <= 0`는 death signal일 수는 있어도, corpse/reanimate lifecycle을 대체하지 못한다.
- LWN이 이후 corpse, reanimation, loot, visual persistence까지 다루려 하면 현재 방식은 구조적으로 어긋날 가능성이 높다.

판정:

- 우선순위 가장 높음

#### D. `WornItems -> ItemVisuals`를 수동으로 재구성하는 패턴

관련 코드:

- `23_LWN_ActorFactory.lua:817`
- `23_LWN_ActorFactory.lua:851`
- `23_LWN_ActorFactory.lua:857`

근거:

- 공식 `WornItems`에는 `getItemVisuals(...)`와 `setFromItemVisuals(...)`가 이미 있음
- 공식 `HumanVisual.addClothingItem(...)`는 `Item`을 받음
- `ItemVisual.setClothingItemName(...)`의 이름은 "clothing item name"이지 full type 보장이 아님

의미:

- LWN의 `bridgeWornItemsToItemVisuals()`는 엔진이 이미 제공하는 변환 경로를 우회한다.
- 특히 fallback에서 `setClothingItemName(fullType)`를 넣는 부분은 의미상 맞지 않을 가능성이 높다.

판정:

- 우선순위 높음

#### E. 월드 등록 시 square/current 포인터를 과하게 수동 조작하는 패턴

관련 코드:

- `23_LWN_ActorFactory.lua:905-916`

근거:

- 공식 문서에 보이는 생명주기 메서드는 `addToWorld`, `removeFromWorld`, `removeFromSquare`, `setCurrent`, `setMovingSquareNow`
- LWN은 `setMovingSquare`, `setCurrentSquare`, `setSquare`, `square:AddMovingObject(...)`까지 직접 만진다

의미:

- 일부는 엔진 내부용이거나 문서 바깥 API일 수 있다.
- 현재는 `protectedCall`로 실패를 삼키므로 겉으로는 버틸 수 있지만, Build 변경에 취약하다.

판정:

- 우선순위 높음

#### F. 문서에 잘 드러나지 않는 추정성 메서드에 의존하는 패턴

관련 코드 예:

- `23_LWN_ActorFactory.lua:679`, `731`, `1335`의 `setFemaleEtc`
- `23_LWN_ActorFactory.lua:683`의 `getSkinTextureName`

근거:

- Build 42 공식 `HumanVisual` 문서에는 `getSkinTexture()`와 `setSkinTextureName(...)`는 보이지만 `getSkinTextureName()`은 확인되지 않음
- `setFemaleEtc`도 관련 클래스 문서에서 분명하게 확인되지 않음

의미:

- 이전 빌드, 레퍼런스 모드, decompiled knowledge에서 온 추정성 호출일 수 있다.
- `protectedCall` 덕분에 죽지는 않지만, 실제 효과가 없을 수 있다.

판정:

- 중간 우선순위

### 3-3. Build 41과 42에서 달라진 것으로 봐야 할 부분

문서 근거가 분명한 것만 적는다.

- `OnZombieCreate` / `IsoZombie`
  - Build 42 위키 문서는 object pooling 때문에 같은 `IsoZombie` 인스턴스가 재사용될 수 있다고 경고한다.
  - 따라서 B41 감각으로 "좀비 객체 인스턴스 하나 = 고정 개체 하나"라고 가정하면 위험하다.
- Build 42 unstable 전체
  - 공식 블로그가 B41과 B42의 모드 호환성 단절을 명시한다.
  - B41에서 우연히 먹히던 undocumented path를 B42에서 그대로 신뢰하면 안 된다.
- human NPC 기대치
  - Build 42 공식 방향은 여전히 human NPC 본체가 아니다.
  - 즉 B41 대비 B42에서 인간형 NPC가 공식 지원으로 올라온 것이 아니라, 여전히 틈새/우회 영역에 가깝다.

## 4. LWN에서 잘못 적용했을 가능성이 높은 API/패턴 우선순위

### 1순위

- `IsoPlayer` 기반 embodied NPC를 공식 human NPC처럼 취급하는 전제
- `setHealth(...)`만으로 죽음 상태를 흉내 내며 corpse/reanimation lifecycle을 우회하는 전제

### 2순위

- `IsoPlayer` 경로를 쓰면서 `OnCreateSurvivor`만 바인딩하는 이벤트 선택
- `WornItems -> ItemVisuals`를 수동 브리지하는 presentation 복구 방식

### 3순위

- `setCurrentSquare`, `setSquare`, `setMovingSquare`, `square:AddMovingObject(...)` 중심의 수동 월드 등록
- `ModelManager.Add/Reset/...`를 presentation 복구의 핵심 수단처럼 쓰는 패턴

### 4순위

- `setFemaleEtc`, `getSkinTextureName` 같은 문서상 불투명한 메서드 호출
- `setClothingItemName(fullType)`처럼 의미적으로 어긋날 수 있는 fallback 값

## 5. 다음 패치 전에 재검토해야 할 사항

- LWN의 embodied human actor를 계속 `IsoPlayer`로 유지할지, 아니면 공식 문서상 더 자연스러운 `IsoSurvivor`/`SurvivorFactory` 경로를 재검토할지 결정 필요
- 생성 후처리 이벤트를 `OnCreateSurvivor`에 둘지, `OnCreateLivingCharacter`로 옮길지 검토 필요
- "죽음"을 record 상태와 actor health만으로 표현할지, 아니면 corpse / `IsoDeadBody` / reanimation lifecycle을 모델에 반영할지 설계 결정 필요
- `bridgeWornItemsToItemVisuals()`는 공식 `WornItems.getItemVisuals()` / `setFromItemVisuals()`로 대체 가능한지 검토 필요
- 월드 등록/해제는 문서화된 생명주기 API 중심으로 줄일 수 있는지 점검 필요
- 문서에 안 보이는 추정성 호출은 Build 42 기준 실제 존재/효과를 별도 체크리스트로 분리할 필요가 있음

## 6. 한 줄 결론

LWN은 Build 42에서 "불가능한 것만 하고 있다"기보다는, 공식 API 조각들을 조합해 인간형 NPC처럼 보이게 만드는 우회 경로를 많이 쓰고 있다. 가장 큰 리스크는 `IsoPlayer` human-NPC 경로 자체보다도, 그 위에 얹은 이벤트 선택, death/corpse lifecycle 우회, 그리고 clothing/item visual 복구를 수동 브리지로 메우는 부분이다.
