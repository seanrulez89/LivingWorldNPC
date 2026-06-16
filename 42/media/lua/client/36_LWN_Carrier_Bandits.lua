LWN = LWN or {}
LWN.Carriers = LWN.Carriers or {}

local Carrier = {}
LWN.Carriers.bandits = Carrier

local CLAN_ID = "ae5e5d56-d82f-43a3-b1bb-28614544b343"
local PROFILE_ID = "381888f8-af27-45b6-aa90-f56d22299753"
local PROGRAM_NAME = "LWNControlled"
local SPAWN_TIMEOUT_MS = 10000
local ORPHAN_SWEEP_MS = 30000
local MOVE_STALL_MS = 5000
local MOVE_ARRIVAL_DISTANCE = 0.75
local MOVE_MAX_ATTEMPTS = 3
local MOVE_PROGRESS_EPSILON = 0.05
local SPAWN_CALM_MS = 1000
local FOLLOW_OFFSET = 2.25
local FOLLOW_ARRIVAL_DISTANCE = 1.0
local FOLLOW_RETARGET_DISTANCE = 1.25
local FOLLOW_RETARGET_MS = 350
local FOLLOW_HEADING_EPSILON = 0.08
local FOLLOW_CATCHUP_ENTER_DISTANCE = 8.0
local FOLLOW_CATCHUP_EXIT_DISTANCE = 5.5
local FOLLOW_HARD_CATCHUP_DISTANCE = 14.0
local FOLLOW_CATCHUP_OFFSET = 1.25
local SQUAD_TELEMETRY_MS = 3000
local SQUAD_TELEMETRY_TRANSITION_MS = 750
local DEFAULT_WALK_SPEED = 1.04
local DEFAULT_RUN_SPEED = 0.72
local FOLLOW_FORMATION = {
    [1] = { back = 2.25, side = 0.00 },
    [2] = { back = 3.10, side = -1.25 },
    [3] = { back = 3.10, side = 1.25 },
}
local SQUAD_WEAPONS = {
    [1] = "Base.BaseballBat",
    [2] = "Base.Hammer",
    [3] = "Base.Crowbar",
}

-- Bandits paths reliably with these three walk types; speed multipliers provide
-- distinct sprint and crouch-run states without reintroducing unsupported SneakRun.
local FOLLOW_LOCOMOTION = {
    walk = { walkType = "Walk", endurance = 0, walkMultiplier = 1.0, runMultiplier = 1.0 },
    run = { walkType = "Run", endurance = -0.03, walkMultiplier = 1.0, runMultiplier = 1.0 },
    sprint = { walkType = "Run", endurance = -0.06, walkMultiplier = 1.0, runMultiplier = 1.35 },
    crouch_walk = { walkType = "SneakWalk", endurance = -0.01, walkMultiplier = 1.0, runMultiplier = 1.0 },
    crouch_run = { walkType = "SneakWalk", endurance = -0.03, walkMultiplier = 1.35, runMultiplier = 1.0 },
}

Carrier.RetiredKeys = Carrier.RetiredKeys or {}
Carrier.PendingHitRepairs = Carrier.PendingHitRepairs or {}

local function nowMs()
    if getTimestampMs then return getTimestampMs() end
    return math.floor((os and os.clock and os.clock() or 0) * 1000)
end

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function movementBaseSpeeds(actor)
    local modData = protectedCall(actor, "getModData")
    if not modData then return DEFAULT_WALK_SPEED, DEFAULT_RUN_SPEED end
    if tonumber(modData.LWN_BaseWalkSpeed) == nil then
        modData.LWN_BaseWalkSpeed = tonumber(protectedCall(actor, "getVariableFloat", "WalkSpeed", DEFAULT_WALK_SPEED))
            or DEFAULT_WALK_SPEED
    end
    if tonumber(modData.LWN_BaseRunSpeed) == nil then
        modData.LWN_BaseRunSpeed = tonumber(protectedCall(actor, "getVariableFloat", "RunSpeed", DEFAULT_RUN_SPEED))
            or DEFAULT_RUN_SPEED
    end
    return tonumber(modData.LWN_BaseWalkSpeed) or DEFAULT_WALK_SPEED,
        tonumber(modData.LWN_BaseRunSpeed) or DEFAULT_RUN_SPEED
end

local function applyMovementProfile(actor, profile)
    if not actor or not profile then return end
    local baseWalkSpeed, baseRunSpeed = movementBaseSpeeds(actor)
    protectedCall(actor, "setVariable", "WalkSpeed", baseWalkSpeed * (profile.walkMultiplier or 1))
    protectedCall(actor, "setVariable", "RunSpeed", baseRunSpeed * (profile.runMultiplier or 1))
    protectedCall(actor, "setVariable", "BanditWalkType", profile.walkType)
    protectedCall(actor, "setWalkType", profile.walkType)
end

local function resetMovementProfile(actor)
    local baseWalkSpeed, baseRunSpeed = movementBaseSpeeds(actor)
    protectedCall(actor, "setVariable", "WalkSpeed", baseWalkSpeed)
    protectedCall(actor, "setVariable", "RunSpeed", baseRunSpeed)
    protectedCall(actor, "setVariable", "BanditWalkType", "Walk")
    protectedCall(actor, "setWalkType", "Walk")
end

local function displayName(record)
    local identity = record and record.identity or {}
    return string.format("%s %s", tostring(identity.firstName or "Unknown"), tostring(identity.lastName or "Unknown"))
end

local function captureSpawnCalm(player)
    if not player then return nil end
    local stats = protectedCall(player, "getStats")
    local panic = CharacterStat and CharacterStat.PANIC and protectedCall(stats, "get", CharacterStat.PANIC) or nil
    local timeSinceLastStab = protectedCall(player, "getTimeSinceLastStab")
    protectedCall(player, "setTimeSinceLastStab", 0)
    local emitter = protectedCall(player, "getEmitter")
    protectedCall(emitter, "stopSoundByName", "ZombieSurprisedPlayer")
    return {
        panic = panic,
        timeSinceLastStab = timeSinceLastStab,
        startedAtMs = nowMs(),
        untilMs = nil,
        active = true,
    }
end

local function applySpawnCalm(handle)
    local calm = handle and handle.runtime and handle.runtime.spawnCalm or nil
    if not calm or calm.active ~= true then return end
    local now = nowMs()
    calm.untilMs = calm.untilMs or (now + SPAWN_CALM_MS)
    if now >= calm.untilMs then
        calm.active = false
        local player = getSpecificPlayer and getSpecificPlayer(0) or nil
        if player and calm.timeSinceLastStab ~= nil then
            protectedCall(player, "setTimeSinceLastStab", calm.timeSinceLastStab)
        end
        print(string.format(
            "[LWN][Bandits] spawn calm complete npcId=%s baselinePanic=%s visible=%s",
            tostring(handle.lwnNpcId), tostring(calm.panic), tostring(calm.lastVisible)
        ))
        return
    end
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    if not player then return end

    local emitter = protectedCall(player, "getEmitter")
    protectedCall(emitter, "stopSoundByName", "ZombieSurprisedPlayer")
    protectedCall(player, "setTimeSinceLastStab", 0)

    local stats = protectedCall(player, "getStats")
    if calm.panic ~= nil and CharacterStat and CharacterStat.PANIC then
        local currentPanic = protectedCall(stats, "get", CharacterStat.PANIC)
        if currentPanic ~= nil and currentPanic > calm.panic then
            protectedCall(stats, "set", CharacterStat.PANIC, calm.panic)
        end
    end
    local visible = protectedCall(stats, "getNumVisibleZombies") or protectedCall(stats, "getVisibleZombies")
    local bodyDamage = protectedCall(player, "getBodyDamage")
    if visible ~= nil then
        protectedCall(bodyDamage, "setOldNumZombiesVisible", visible)
    end

    calm.lastVisible = visible
end

local function brainFor(actor)
    if not (actor and BanditBrain and BanditBrain.Get) then return nil end
    local ok, brain = pcall(BanditBrain.Get, actor)
    if ok then return brain end
    return nil
end

local function isControlledBrain(brain)
    if LWN.BanditsIntegration and LWN.BanditsIntegration.isControlledBrain then
        return LWN.BanditsIntegration.isControlledBrain(brain)
    end
    return brain and brain.program and brain.program.name == PROGRAM_NAME or false
end

local function getBanditEntries()
    if BanditZombie and BanditZombie.GetAllB then
        return BanditZombie.GetAllB() or {}
    end
    return BanditZombie and BanditZombie.CacheLightB or {}
end

local function actorByBanditId(id)
    return BanditZombie and BanditZombie.GetInstanceById and BanditZombie.GetInstanceById(id) or nil
end

local function distanceToAnchor(record, actor)
    local ax = tonumber(record and record.anchor and record.anchor.x or 0) or 0
    local ay = tonumber(record and record.anchor and record.anchor.y or 0) or 0
    local dx = (tonumber(protectedCall(actor, "getX") or ax) or ax) - ax
    local dy = (tonumber(protectedCall(actor, "getY") or ay) or ay) - ay
    return dx * dx + dy * dy
end

local function matchingActors(key)
    local matches = {}
    for id, light in pairs(getBanditEntries()) do
        local brain = light and light.brain or nil
        if brain and tonumber(brain.key) == tonumber(key) and isControlledBrain(brain) then
            local actor = actorByBanditId(id)
            if actor then
                matches[#matches + 1] = { id = id, actor = actor, brain = brain }
            end
        end
    end
    return matches
end

local function clearBanditCaches(id)
    if not (BanditZombie and id) then return end
    if BanditZombie.Cache then BanditZombie.Cache[id] = nil end
    if BanditZombie.CacheLight then BanditZombie.CacheLight[id] = nil end
    if BanditZombie.CacheLightB and BanditZombie.CacheLightB[id] ~= nil then
        BanditZombie.CacheLightB[id] = nil
        BanditZombie.CacheLightBCnt = math.max(0, (tonumber(BanditZombie.CacheLightBCnt) or 1) - 1)
    end
    if BanditZombie.CacheLightZ and BanditZombie.CacheLightZ[id] ~= nil then
        BanditZombie.CacheLightZ[id] = nil
        BanditZombie.CacheLightZCnt = math.max(0, (tonumber(BanditZombie.CacheLightZCnt) or 1) - 1)
    end
end

local function actorDeathLike(actor)
    if not actor then return true end
    local objectName = tostring(protectedCall(actor, "getObjectName") or "")
    if objectName == "Corpse" or objectName == "IsoDeadBody" then return true end
    if protectedCall(actor, "isDead") == true then return true end
    if protectedCall(actor, "isAlive") == false then return true end
    local health = tonumber(protectedCall(actor, "getHealth"))
    return health ~= nil and health <= 0
end

local function safeBanditId(actor, hint)
    if hint ~= nil then return hint end
    local brain = brainFor(actor)
    if brain and brain.id ~= nil then return brain.id end
    local modData = protectedCall(actor, "getModData")
    if modData and modData.LWN_BanditId ~= nil then
        return modData.LWN_BanditId
    end
    if actorDeathLike(actor) then return nil end
    if BanditUtils and BanditUtils.GetZombieID then
        local ok, id = pcall(BanditUtils.GetZombieID, actor)
        if ok then return id end
    end
    return nil
end

local function stopActor(actor)
    if not actor then return end
    if Bandit and Bandit.ClearTasks then Bandit.ClearTasks(actor) end
    if Bandit and Bandit.ForceStationary then Bandit.ForceStationary(actor, true) end
    local brain = brainFor(actor)
    if brain then
        brain.lwnMoveActive = false
        brain.lwnFollowActive = false
    end
    local pathfinder = protectedCall(actor, "getPathFindBehavior2")
    protectedCall(pathfinder, "cancel")
    protectedCall(pathfinder, "reset")
    protectedCall(actor, "setMoving", false)
    protectedCall(actor, "setTarget", nil)
    resetMovementProfile(actor)
    local emitter = protectedCall(actor, "getEmitter")
    protectedCall(emitter, "stopAll")
end

local function stopBanditBreathing(actor)
    local emitter = protectedCall(actor, "getEmitter")
    protectedCall(emitter, "stopSoundByName", "ZSBreath_Male")
    protectedCall(emitter, "stopSoundByName", "ZSBreath_Female")
end

local function rememberMoveResult(handle, move, status, reason, distance)
    if not handle then return end
    handle.runtime = handle.runtime or {}
    handle.runtime.lastMove = {
        status = status,
        reason = reason,
        distance = distance,
        attempts = move and move.attempts or 0,
        taskCycles = move and move.taskCycles or 0,
        atMs = nowMs(),
    }
end

local function removeActor(actor, reason, idHint)
    if not actor then return end
    local id = safeBanditId(actor, idHint)
    local dead = actorDeathLike(actor)
    if not dead then
        stopActor(actor)
    else
        local emitter = protectedCall(actor, "getEmitter")
        protectedCall(emitter, "stopAll")
    end
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_LastNpcId = modData.LWN_NpcId or modData.LWN_LastNpcId
        modData.LWN_NpcId = nil
        modData.LWN_CarrierKind = nil
        modData.LWN_ShellMarker = nil
        modData.LWN_TestHarnessLabel = nil
        modData.LWN_ManagedShellContract = nil
        modData.LWN_BanditsCorrelationKey = nil
        modData.LWN_BanditsSessionId = nil
        modData.LWN_AllowPlayerAttack = nil
    end
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    local commandSent = false
    if id and not dead and player and sendClientCommand then
        sendClientCommand(player, "Commands", "BanditRemove", { id = id })
        commandSent = true
    end
    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")
    clearBanditCaches(id)
    print(string.format(
        "[LWN][Bandits] removed banditId=%s reason=%s dead=%s commandSent=%s",
        tostring(id), tostring(reason), tostring(dead), tostring(commandSent)
    ))
end

Carrier.removeActor = removeActor

local function enforceSafety(actor, brain)
    if not actor or not brain then return end
    brain.program = brain.program or {}
    if brain.program.name ~= PROGRAM_NAME then
        brain.program.name = PROGRAM_NAME
        brain.program.stage = "Main"
    elseif brain.program.stage ~= "Prepare" and brain.program.stage ~= "Main" then
        brain.program.stage = "Main"
    end
    brain.programFallback = PROGRAM_NAME
    brain.hostile = false
    brain.hostileP = false
    brain.loyal = false
    brain.demolish = false
    brain.eatBody = false
    brain.lwnControlled = true
    brain.lwnNonCombat = brain.lwnCombatEngaged ~= true
    if brain.lwnCombatEngaged ~= true then
        protectedCall(actor, "setTarget", nil)
    end
    protectedCall(actor, "setEatBodyTarget", nil, false)
    protectedCall(actor, "setNoTeeth", true)
    if brain.lwnFriendlyFireProtected ~= true then
        protectedCall(actor, "setGodMod", false)
        protectedCall(actor, "setInvulnerable", false)
        protectedCall(actor, "setAvoidDamage", false)
    end
    protectedCall(actor, "setShootable", true)
    protectedCall(actor, "setVariable", "NoLungeTarget", true)
    if Bandit and Bandit.SurpressZombieSounds then
        Bandit.SurpressZombieSounds(actor)
    end
    stopBanditBreathing(actor)
end

local function isPlayerAttacker(attacker)
    return attacker ~= nil
        and instanceof ~= nil
        and instanceof(attacker, "IsoPlayer")
        and protectedCall(attacker, "isNPC") ~= true
end

local function syncHealth(record, actor, brain, source)
    if not record or not actor or not brain then return nil end
    record.combat = record.combat or {}
    record.stats = record.stats or {}
    local previous = tonumber(record.stats.health)
    local health = tonumber(protectedCall(actor, "getHealth"))
    if health == nil then return nil end
    if record.combat.healthInitialized ~= true then
        record.combat.healthInitialized = true
        record.combat.maxHealth = health
    else
        record.combat.maxHealth = math.max(tonumber(record.combat.maxHealth) or 0, health)
    end
    record.stats.health = health
    brain.health = health
    brain.lwnLastHealthSyncSource = source
    brain.lwnLastHealthSyncAt = worldAgeHours()
    if previous == nil or math.abs(previous - health) > 0.001 then
        print(string.format(
            "[LWN][SquadHealth] npcId=%s previous=%s current=%.2f delta=%s source=%s",
            tostring(record.id),
            previous and string.format("%.2f", previous) or "nil",
            health,
            previous and string.format("%.2f", health - previous) or "nil",
            tostring(source)
        ))
    end
    return health
end

local function itemFullType(item)
    return item and (protectedCall(item, "getFullType") or protectedCall(item, "getType")) or nil
end

local function inventoryItemCount(actor, fullType)
    if not actor or not fullType then return 0 end
    local inventory = protectedCall(actor, "getInventory")
    local items = protectedCall(inventory, "getItems")
    local size = tonumber(protectedCall(items, "size")) or 0
    local count = 0
    for i = 0, size - 1 do
        if itemFullType(protectedCall(items, "get", i)) == fullType then
            count = count + 1
        end
    end
    return count
end

local function objectId(obj)
    if not obj then return "nil" end
    return tostring(protectedCall(obj, "getOnlineID") or protectedCall(obj, "getID") or obj)
end

local function logSquadTelemetry(record, handle, actor, brain)
    if not record or not handle or not actor or not brain then return end
    handle.runtime = handle.runtime or {}
    local telemetry = handle.runtime.squadTelemetry or {}
    handle.runtime.squadTelemetry = telemetry

    local now = nowMs()
    local task = Bandit and Bandit.GetTask and Bandit.GetTask(actor) or nil
    local taskAction = task and task.action or "none"
    local taskItem = task and (task.itemPrimary or task.weapon) or "none"
    local significantTask = (taskAction == "Smack"
        or taskAction == "Push"
        or taskAction == "Equip"
        or taskAction == "Unequip") and taskAction or "none"
    local desiredWeapon = brain.weapons and brain.weapons.melee or "none"
    local primaryWeapon = itemFullType(protectedCall(actor, "getPrimaryHandItem")) or "none"
    local equipped = desiredWeapon ~= "none" and protectedCall(actor, "isPrimaryEquipped", desiredWeapon) == true
    local command = record.companion and record.companion.command or {}
    local combat = record.combat or {}
    local follow = handle.runtime.follow or {}
    local signature = table.concat({
        tostring(command.kind), tostring(command.status), tostring(combat.state), tostring(combat.reason),
        tostring(significantTask), tostring(desiredWeapon), tostring(primaryWeapon),
        tostring(equipped), tostring(follow.movementMode), tostring(follow.followMode),
        objectId(protectedCall(actor, "getTarget")),
    }, "|")
    local intervalElapsed = now - (tonumber(telemetry.lastAtMs) or 0) >= SQUAD_TELEMETRY_MS
    local transitionElapsed = signature ~= telemetry.signature
        and now - (tonumber(telemetry.lastAtMs) or 0) >= SQUAD_TELEMETRY_TRANSITION_MS
    if not intervalElapsed and not transitionElapsed then return end

    local ax = tonumber(protectedCall(actor, "getX") or 0) or 0
    local ay = tonumber(protectedCall(actor, "getY") or 0) or 0
    local az = tonumber(protectedCall(actor, "getZ") or 0) or 0
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    local playerDistance = nil
    if player then
        local dx = ax - (tonumber(protectedCall(player, "getX")) or ax)
        local dy = ay - (tonumber(protectedCall(player, "getY")) or ay)
        playerDistance = math.sqrt(dx * dx + dy * dy)
    end
    local inventoryCount = desiredWeapon ~= "none" and inventoryItemCount(actor, desiredWeapon) or 0
    print(string.format(
        "[LWN][SquadTelemetry] npcId=%s name=%s slot=%s stance=%s policy=%s pos=%.1f,%.1f,%.1f playerDist=%s formation=%s followMode=%s locomotion=%s heading=%s targetPos=%s followTargetDist=%s command=%s/%s combat=%s reason=%s task=%s taskItem=%s desiredWeapon=%s primaryHand=%s equipped=%s inventoryCount=%s health=%.2f target=%s",
        tostring(record.id), displayName(record),
        tostring(record.companion and record.companion.squadSlot),
        tostring(combat.disposition),
        tostring(command.combatPolicy or "none"), ax, ay, az,
        playerDistance and string.format("%.2f", playerDistance) or "nil",
        tostring(follow.formationSlot or "none"), tostring(follow.followMode or "none"),
        tostring(follow.movementMode or "none"), tostring(follow.headingSource or "none"),
        follow.desiredTargetX and string.format("%.1f,%.1f", follow.desiredTargetX, follow.desiredTargetY) or "nil",
        follow.targetDistance and string.format("%.2f", follow.targetDistance) or "nil",
        tostring(command.kind or "none"), tostring(command.status or "idle"),
        tostring(combat.state or "idle"), tostring(combat.reason or "none"),
        tostring(taskAction), tostring(taskItem), tostring(desiredWeapon), tostring(primaryWeapon),
        tostring(equipped), tostring(inventoryCount),
        tonumber(protectedCall(actor, "getHealth") or 0) or 0,
        objectId(protectedCall(actor, "getTarget"))
    ))
    telemetry.lastAtMs = now
    telemetry.signature = signature
end

local function beginFriendlyFireProtection(record, actor, brain, source)
    local actorHealth = tonumber(protectedCall(actor, "getHealth")) or 0
    local canonicalHealth = tonumber(record.stats and record.stats.health) or actorHealth
    local restoreHealth = math.max(actorHealth, canonicalHealth)
    brain.lwnFriendlyFireProtected = true
    brain.lwnProtectedHealth = restoreHealth
    brain.lwnFriendlyFireProtectedAtMs = nowMs()
    protectedCall(actor, "setGodMod", true)
    protectedCall(actor, "setInvulnerable", true)
    protectedCall(actor, "setAvoidDamage", true)
    Carrier.PendingHitRepairs[record.id] = {
        actor = actor,
        health = restoreHealth,
        remainingTicks = 3,
        queuedAtMs = nowMs(),
        source = source,
    }
    return restoreHealth
end

local function assignSquadWeapon(record, actor, brain)
    local slot = tonumber(record and record.companion and record.companion.squadSlot)
    local weapon = SQUAD_WEAPONS[slot]
    if not weapon then return end
    local alreadyAssigned = brain.lwnSquadWeaponAssigned == weapon
    brain.weapons = brain.weapons or {}
    brain.weapons.primary = brain.weapons.primary or { bulletsLeft = 0, ammoCount = 0, magCount = 0 }
    brain.weapons.secondary = brain.weapons.secondary or { bulletsLeft = 0, ammoCount = 0, magCount = 0 }
    brain.weapons.melee = weapon
    brain.lwnSquadWeaponAssigned = weapon
    if LWN.Inventory then
        if LWN.Inventory.recordCount and LWN.Inventory.recordCount(record, weapon) <= 0 then
            LWN.Inventory.grant(record, weapon, 1, "squad_weapon")
        end
        if LWN.Inventory.setEquipment then
            LWN.Inventory.setEquipment(record, "primaryWeapon", weapon, "squad_weapon")
        end
    else
        record.inventory = record.inventory or {}
        record.inventory.equipment = record.inventory.equipment or {}
        record.inventory.equipment.primaryWeapon = weapon
    end
    if Bandit and Bandit.SetWeapons then Bandit.SetWeapons(actor, brain.weapons) end
    local syncResult = LWN.Inventory and LWN.Inventory.syncActorEquipment
        and LWN.Inventory.syncActorEquipment(record, actor, {
            apply = true,
            allowCreate = true,
            reason = "squad_weapon",
        })
        or nil
    if Bandit and Bandit.SetHands then Bandit.SetHands(actor, weapon) end
    if LWN.Inventory and LWN.Inventory.syncActorEquipment then
        syncResult = LWN.Inventory.syncActorEquipment(record, actor, {
            apply = true,
            allowCreate = true,
            reason = "squad_weapon_post_bandit_hands",
        }) or syncResult
    end
    if alreadyAssigned and syncResult and syncResult.changed ~= true then return end
    print(string.format(
        "[LWN][Bandits] squad weapon npcId=%s slot=%s weapon=%s actual=%s primaryMatch=%s changed=%s",
        tostring(record.id), tostring(slot), tostring(weapon),
        tostring(syncResult and syncResult.snapshot and syncResult.snapshot.actor and syncResult.snapshot.actor.primaryHand or "unknown"),
        tostring(syncResult and syncResult.primaryMatches),
        tostring(syncResult and syncResult.changed)
    ))
end

local function friendlyRecordForActor(actor)
    local modData = protectedCall(actor, "getModData")
    local npcId = modData and (modData.LWN_NpcId or modData.LWN_LastNpcId) or nil
    local record = npcId and LWN.PopulationStore and LWN.PopulationStore.getNPC
        and LWN.PopulationStore.getNPC(npcId) or nil
    if not record then return nil end
    if LWN.PopulationStore.isAlive and LWN.PopulationStore.isAlive(record) ~= true then return nil end
    local policy = LWN.Social and LWN.Social.relationshipCombatPolicy
        and LWN.Social.relationshipCombatPolicy(record) or nil
    if not policy or policy.allowPlayerAttack == true then return nil end
    return record
end

function Carrier.onHitZombie(actor, attacker)
    if LWN.Combat and LWN.Combat.notePlayerAttack then
        LWN.Combat.notePlayerAttack(actor, attacker)
    end
    local brain = brainFor(actor)
    if not isControlledBrain(brain) then return end
    local record = friendlyRecordForActor(actor)
    if not record then return end

    if not isPlayerAttacker(attacker) then
        if LWN.Combat and LWN.Combat.noteSquadHit then
            LWN.Combat.noteSquadHit(record, attacker)
        end
        local health = syncHealth(record, actor, brain, "zombie_hit") or 0
        print(string.format(
            "[LWN][Bandits] zombie damage accepted npcId=%s banditId=%s attacker=%s health=%.2f",
            tostring(record.id), tostring(brain.id), tostring(attacker), health
        ))
        return
    end

    local restoreHealth = beginFriendlyFireProtection(record, actor, brain, "on_hit_zombie")
    if restoreHealth > 0 then protectedCall(actor, "setHealth", restoreHealth) end
    protectedCall(actor, "setKnockedDown", false)
    protectedCall(actor, "setOnFloor", false)
    protectedCall(actor, "setFallOnFront", false)
    protectedCall(actor, "setAlwaysKnockedDown", false)
    enforceSafety(actor, brain)
    print(string.format(
        "[LWN][Bandits] friendly hit suppressed npcId=%s banditId=%s attacker=%s health=%.2f deferred=true",
        tostring(record.id), tostring(brain.id), tostring(attacker),
        tonumber(protectedCall(actor, "getHealth") or restoreHealth or 0) or 0
    ))
end

function Carrier.onWeaponHitCharacter(attacker, actor)
    if LWN.Combat and LWN.Combat.notePlayerAttack then
        LWN.Combat.notePlayerAttack(actor, attacker)
    end
    local brain = brainFor(actor)
    local record = friendlyRecordForActor(actor)
    if not isControlledBrain(brain) or not record or not isPlayerAttacker(attacker) then return end
    beginFriendlyFireProtection(record, actor, brain, "on_weapon_hit_character")
    enforceSafety(actor, brain)
    return false
end

local function tickPendingHitRepairs()
    for npcId, repair in pairs(Carrier.PendingHitRepairs) do
        local actor = repair and repair.actor or nil
        local record = LWN.PopulationStore and LWN.PopulationStore.getNPC
            and LWN.PopulationStore.getNPC(npcId) or nil
        local brain = brainFor(actor)
        if not record
            or (LWN.PopulationStore.isAlive and LWN.PopulationStore.isAlive(record) ~= true)
            or actorDeathLike(actor)
            or not isControlledBrain(brain)
        then
            Carrier.PendingHitRepairs[npcId] = nil
            print(string.format(
                "[LWN][Bandits] friendly hit repair abandoned npcId=%s actorDead=%s recordAlive=%s",
                tostring(npcId), tostring(actorDeathLike(actor)),
                tostring(record and LWN.PopulationStore.isAlive and LWN.PopulationStore.isAlive(record) or false)
            ))
        else
            local restoreHealth = tonumber(repair.health) or tonumber(record.stats and record.stats.health) or 1
            if restoreHealth > 0 then
                protectedCall(actor, "setHealth", restoreHealth)
            end
            protectedCall(actor, "setKnockedDown", false)
            protectedCall(actor, "setOnFloor", false)
            protectedCall(actor, "setFallOnFront", false)
            protectedCall(actor, "setAlwaysKnockedDown", false)
            enforceSafety(actor, brain)
            repair.remainingTicks = (tonumber(repair.remainingTicks) or 1) - 1
            if repair.remainingTicks <= 0 then
                brain.lwnFriendlyFireProtected = false
                brain.lwnProtectedHealth = nil
                brain.lwnFriendlyFireProtectedAtMs = nil
                protectedCall(actor, "setGodMod", false)
                protectedCall(actor, "setInvulnerable", false)
                protectedCall(actor, "setAvoidDamage", false)
                syncHealth(record, actor, brain, "friendly_fire_repair_complete")
                Carrier.PendingHitRepairs[npcId] = nil
                print(string.format(
                    "[LWN][Bandits] friendly hit repair complete npcId=%s banditId=%s health=%.2f",
                    tostring(npcId), tostring(brain.id),
                    tonumber(protectedCall(actor, "getHealth") or restoreHealth) or 0
                ))
            end
        end
    end
end

local function stampActor(record, handle, actor, brain)
    brain.lwnNpcId = record.id
    brain.lwnSessionId = handle.sessionId
    brain.lwnControlled = true
    brain.lwnNonCombat = brain.lwnCombatEngaged ~= true
    brain.lwnTeamId = record.companion and record.companion.teamId or "player-team-0"
    brain.key = handle.correlationKey
    brain.fullname = displayName(record)
    if brain.lwnFriendlyFireProtected == true
        and Carrier.PendingHitRepairs[record.id] == nil
        and nowMs() - (tonumber(brain.lwnFriendlyFireProtectedAtMs) or 0) >= 750
    then
        brain.lwnFriendlyFireProtected = false
        brain.lwnProtectedHealth = nil
        brain.lwnFriendlyFireProtectedAtMs = nil
    end
    handle.lwnNpcId = record.id
    local modData = protectedCall(actor, "getModData")
    if modData then
        movementBaseSpeeds(actor)
        modData.LWN_NpcId = record.id
        modData.LWN_LastNpcId = record.id
        modData.LWN_CarrierKind = "bandits"
        modData.LWN_ShellMarker = "bandits:" .. tostring(record.id)
        modData.LWN_ManagedShellContract = true
        modData.LWN_TestHarnessLabel = record.debugHarness and record.debugHarness.label or nil
        modData.LWN_BanditsCorrelationKey = handle.correlationKey
        modData.LWN_BanditsSessionId = handle.sessionId
        modData.LWN_BanditId = brain.id or handle.banditId
        modData.LWN_DisplayName = brain.fullname
        modData.LWN_AllowPlayerAttack = false
    end
    local descriptor = protectedCall(actor, "getDescriptor")
    protectedCall(descriptor, "setForename", record.identity and record.identity.firstName or nil)
    protectedCall(descriptor, "setSurname", record.identity and record.identity.lastName or nil)
    protectedCall(actor, "setForname", record.identity and record.identity.firstName or nil)
    protectedCall(actor, "setSurname", record.identity and record.identity.lastName or nil)
    syncHealth(record, actor, brain, "stamp_actor")
    assignSquadWeapon(record, actor, brain)
    if LWN.Combat and LWN.Combat.update then
        LWN.Combat.update(record, actor)
    end
    enforceSafety(actor, brain)
    applySpawnCalm(handle)
    handle.runtime = handle.runtime or {}
    if handle.runtime.safetySynced ~= true and Bandit and Bandit.ForceSyncPart then
        Bandit.ForceSyncPart(actor, {
            id = brain.id,
            hostile = false,
            hostileP = false,
            loyal = false,
            demolish = false,
            eatBody = false,
            lwnNpcId = record.id,
            lwnSessionId = handle.sessionId,
            lwnControlled = true,
            lwnNonCombat = brain.lwnCombatEngaged ~= true,
            lwnTeamId = brain.lwnTeamId,
        })
        handle.runtime.safetySynced = true
    end
end

local function numericNpcId(record)
    local digits = tostring(record and record.id or ""):match("(%d+)$")
    return tonumber(digits) or 0
end

local function buildCorrelationKey(record, sessionId)
    return numericNpcId(record) * 1000 + (sessionId % 1000)
end

local function dependencyReady()
    if LWN.BanditsIntegration and LWN.BanditsIntegration.install then
        LWN.BanditsIntegration.install()
    end
    return sendClientCommand ~= nil
        and BanditZombie ~= nil
        and BanditBrain ~= nil
        and Bandit ~= nil
        and BanditUtils ~= nil
        and ZombiePrograms ~= nil
        and ZombiePrograms[PROGRAM_NAME] ~= nil
end

local function validateProfileData()
    local clan = BanditCustom and BanditCustom.ClanGet and BanditCustom.ClanGet(CLAN_ID) or nil
    local profile = BanditCustom and BanditCustom.GetById and BanditCustom.GetById(PROFILE_ID) or nil
    if (not clan or not profile) and BanditCustom and BanditCustom.Load then
        BanditCustom.Load()
        clan = BanditCustom.ClanGet and BanditCustom.ClanGet(CLAN_ID) or nil
        profile = BanditCustom.GetById and BanditCustom.GetById(PROFILE_ID) or nil
    end
    local profileCount = 0
    local clanProfiles = BanditCustom and BanditCustom.GetFromClan and BanditCustom.GetFromClan(CLAN_ID) or {}
    for _ in pairs(clanProfiles or {}) do
        profileCount = profileCount + 1
    end
    print(string.format(
        "[LWN][Bandits] profile check clanCount=%s profileCount=%s expectedProfile=%s clanId=%s profileId=%s",
        tostring(clan and 1 or 0), tostring(profileCount), tostring(profile ~= nil), CLAN_ID, PROFILE_ID
    ))
    return clan ~= nil and profile ~= nil and profileCount == 1
end

function Carrier.canSpawn(record, options)
    if not dependencyReady() then
        return false, "Bandits2 runtime unavailable"
    end
    if not validateProfileData() then
        return false, "LWN Bandits clan/profile unavailable"
    end
    return true, "Bandits2 ready"
end

function Carrier.spawn(record, options)
    local ok, detail = Carrier.canSpawn(record, options)
    if not ok then
        return { ok = false, detail = detail }
    end

    record.embodiment = record.embodiment or {}
    record.embodiment.sessionId = (tonumber(record.embodiment.sessionId) or 0) + 1
    local sessionId = record.embodiment.sessionId
    local key = buildCorrelationKey(record, sessionId)
    local handle = {
        kind = "bandits",
        actor = nil,
        status = "pending",
        pending = true,
        spawnedAt = worldAgeHours(),
        requestedAtMs = nowMs(),
        sessionId = sessionId,
        correlationKey = key,
        runtime = {},
        detail = "spawn_requested",
    }

    local player = options and options.player or (getSpecificPlayer and getSpecificPlayer(0)) or nil
    if not player then
        return { ok = false, detail = "player unavailable", handle = handle }
    end
    handle.runtime.spawnCalm = captureSpawnCalm(player)

    local anchor = record.anchor or {}
    sendClientCommand(player, "Spawner", "Clan", {
        cid = CLAN_ID,
        x = math.floor(tonumber(anchor.x) or player:getX()),
        y = math.floor(tonumber(anchor.y) or player:getY()),
        z = math.floor(tonumber(anchor.z) or player:getZ()),
        program = PROGRAM_NAME,
        size = 1,
        key = key,
        hostile = false,
        hostileP = false,
        loyal = false,
        permanent = false,
        fullname = displayName(record),
    })

    print(string.format(
        "[LWN][Bandits] spawn requested npcId=%s session=%s key=%s",
        tostring(record.id), tostring(sessionId), tostring(key)
    ))
    return { ok = true, pending = true, actor = nil, handle = handle, detail = "spawn_requested" }
end

function Carrier.poll(record, handle, options)
    if not handle then return { ok = false, detail = "handle missing" } end
    local matches = matchingActors(handle.correlationKey)
    if #matches > 0 then
        table.sort(matches, function(a, b)
            return distanceToAnchor(record, a.actor) < distanceToAnchor(record, b.actor)
        end)
        local selected = matches[1]
        for i = 2, #matches do
            removeActor(matches[i].actor, "duplicate_correlation_key", matches[i].id)
        end
        handle.actor = selected.actor
        handle.banditId = selected.id
        handle.status = "active"
        handle.pending = false
        handle.boundAtMs = nowMs()
        stampActor(record, handle, selected.actor, selected.brain)
        print(string.format(
            "[LWN][Bandits] bound npcId=%s session=%s key=%s banditId=%s duplicates=%s",
            tostring(record.id), tostring(handle.sessionId), tostring(handle.correlationKey),
            tostring(selected.id), tostring(math.max(0, #matches - 1))
        ))
        return { ok = true, pending = false, actor = selected.actor, handle = handle, detail = "bound" }
    end

    if nowMs() - (tonumber(handle.requestedAtMs) or nowMs()) >= SPAWN_TIMEOUT_MS then
        Carrier.RetiredKeys[handle.correlationKey] = nowMs() + ORPHAN_SWEEP_MS
        handle.status = "failed"
        handle.pending = false
        handle.detail = "spawn_timeout"
        return { ok = false, pending = false, handle = handle, detail = "spawn_timeout" }
    end
    return { ok = true, pending = true, handle = handle, detail = "awaiting_bandit" }
end

function Carrier.sync(record, handle, options)
    local actor = handle and handle.actor or nil
    local brain = brainFor(actor)
    if not actor or not brain then
        return { ok = handle and handle.pending == true, status = handle and handle.status or "missing", detail = "actor_or_brain_missing" }
    end
    stampActor(record, handle, actor, brain)
    if brain.lwnMoveActive ~= true and brain.lwnCombatEngaged ~= true and Bandit and Bandit.ForceStationary then
        Bandit.ForceStationary(actor, true)
    end
    logSquadTelemetry(record, handle, actor, brain)
    return { ok = true, status = "active", detail = options and options.source or "synced" }
end

function Carrier.getActor(handle)
    return handle and handle.actor or nil
end

function Carrier.isUsable(handle)
    local actor = handle and handle.actor or nil
    if not actor then return false end
    if actorDeathLike(actor) then
        handle.runtime = handle.runtime or {}
        if handle.runtime.deathLogged ~= true then
            local brain = brainFor(actor)
            print(string.format(
                "[LWN][SquadLifecycle] npcId=%s banditId=%s event=death_detected health=%.2f world=%s",
                tostring(handle.lwnNpcId), tostring(brain and brain.id or handle.banditId),
                tonumber(protectedCall(actor, "getHealth") or 0) or 0,
                tostring(protectedCall(actor, "isExistInTheWorld"))
            ))
            handle.runtime.deathLogged = true
        end
        return false
    end
    if protectedCall(actor, "isExistInTheWorld") == false then return false end
    return isControlledBrain(brainFor(actor))
end

function Carrier.cancelIntent(record, handle, intent, reason)
    local actor = handle and handle.actor or nil
    if actor then stopActor(actor) end
    if handle and handle.runtime then
        rememberMoveResult(handle, handle.runtime.move, "cancelled", reason or "intent_cancelled", nil)
        handle.runtime.move = nil
        handle.runtime.follow = nil
    end
    return { ok = true, detail = reason or "intent_cancelled" }
end

local function tickMoveTo(record, handle, intent)
    local actor = handle and handle.actor or nil
    local brain = brainFor(actor)
    if not actor or not brain then
        rememberMoveResult(handle, nil, "failed", "bandit_actor_missing", nil)
        return { handled = true, failed = true, status = "failed", reason = "bandit_actor_missing" }
    end

    enforceSafety(actor, brain)
    if brain.lwnCombatEngaged == true then
        return {
            handled = true,
            status = "combat",
            reason = brain.lwnCombatReason or "combat_interrupt",
        }
    end
    applyMovementProfile(actor, FOLLOW_LOCOMOTION.walk)
    local data = intent.data or {}
    local tx, ty, tz = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not tx or not ty or not tz then
        rememberMoveResult(handle, nil, "failed", "invalid_destination", nil)
        return { handled = true, failed = true, status = "failed", reason = "invalid_destination" }
    end

    handle.runtime = handle.runtime or {}
    local move = handle.runtime.move
    if not move or move.intent ~= intent then
        stopActor(actor)
        move = {
            intent = intent,
            attempts = 1,
            taskCycles = 0,
            lastProgressAtMs = nowMs(),
            bestDistance = math.huge,
        }
        handle.runtime.move = move
        handle.runtime.follow = nil
        handle.runtime.lastMove = nil
    end

    local dx = (tonumber(protectedCall(actor, "getX") or tx) or tx) - tx
    local dy = (tonumber(protectedCall(actor, "getY") or ty) or ty) - ty
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance <= MOVE_ARRIVAL_DISTANCE then
        stopActor(actor)
        rememberMoveResult(handle, move, "arrived", "bandits_distance_threshold", distance)
        handle.runtime.move = nil
        return { handled = true, done = true, status = "arrived", reason = "bandits_distance_threshold", distance = distance }
    end

    local now = nowMs()
    if distance < move.bestDistance - MOVE_PROGRESS_EPSILON then
        move.bestDistance = distance
        move.lastProgressAtMs = now
    elseif now - move.lastProgressAtMs >= MOVE_STALL_MS then
        if move.attempts >= MOVE_MAX_ATTEMPTS then
            stopActor(actor)
            rememberMoveResult(handle, move, "failed", "bandits_no_progress_after_3_attempts", distance)
            handle.runtime.move = nil
            return {
                handled = true,
                failed = true,
                status = "failed",
                reason = "bandits_no_progress_after_3_attempts",
                distance = distance,
            }
        end
        stopActor(actor)
        move.attempts = move.attempts + 1
        move.lastProgressAtMs = now
        move.bestDistance = distance
        print(string.format(
            "[LWN][Bandits] move retry npcId=%s key=%s attempt=%s reason=no_progress_5s distance=%.2f",
            tostring(record.id), tostring(handle.correlationKey), tostring(move.attempts), distance
        ))
    end

    local hasTask = Bandit and Bandit.HasTask and Bandit.HasTask(actor) == true
    if not hasTask then
        move.taskCycles = move.taskCycles + 1
        brain.lwnMoveActive = true
        if Bandit and Bandit.ForceStationary then Bandit.ForceStationary(actor, false) end
        local task = BanditUtils.GetMoveTask(0, tx, ty, tz, "Walk", distance, true)
        task.lwnMove = true
        task.lwnAttempt = move.attempts
        task.lwnCycle = move.taskCycles
        Bandit.AddTask(actor, task)
        print(string.format(
            "[LWN][Bandits] move npcId=%s key=%s attempt=%s cycle=%s distance=%.2f dest=%.1f,%.1f,%.1f",
            tostring(record.id), tostring(handle.correlationKey), tostring(move.attempts),
            tostring(move.taskCycles), distance, tx, ty, tz
        ))
    end

    return {
        handled = true,
        status = "pathing",
        reason = "bandits_move_active",
        distance = distance,
        attempts = move.attempts,
        taskCycles = move.taskCycles,
    }
end

local function updateFollowHeading(player, follow, px, py)
    local dx = follow.lastPlayerX and (px - follow.lastPlayerX) or 0
    local dy = follow.lastPlayerY and (py - follow.lastPlayerY) or 0
    local distance = math.sqrt(dx * dx + dy * dy)
    if follow.lastPlayerX == nil or follow.lastPlayerY == nil then
        follow.lastPlayerX = px
        follow.lastPlayerY = py
    end

    if distance >= FOLLOW_HEADING_EPSILON then
        follow.headingX = dx / distance
        follow.headingY = dy / distance
        follow.headingSource = "player_motion"
        follow.lastPlayerX = px
        follow.lastPlayerY = py
    elseif follow.headingX == nil or follow.headingY == nil then
        local direction = protectedCall(player, "getForwardDirection")
        local fx = tonumber(protectedCall(direction, "getX") or 0) or 0
        local fy = tonumber(protectedCall(direction, "getY") or 0) or 0
        local length = math.sqrt(fx * fx + fy * fy)
        if length > 0.001 then
            follow.headingX = fx / length
            follow.headingY = fy / length
            follow.headingSource = "initial_facing"
        else
            follow.headingX = 0
            follow.headingY = 1
            follow.headingSource = "fallback_north"
        end
    end
    return follow.headingX, follow.headingY
end

local function updateFollowMode(follow, playerDistance)
    local catchup = follow.catchup == true
    if catchup then
        catchup = playerDistance > FOLLOW_CATCHUP_EXIT_DISTANCE
    else
        catchup = playerDistance >= FOLLOW_CATCHUP_ENTER_DISTANCE
    end
    follow.catchup = catchup
    if not catchup then return "formation" end
    if playerDistance >= FOLLOW_HARD_CATCHUP_DISTANCE then return "hard_catchup" end
    return "catchup"
end

local function followTarget(player, record, follow, px, py, pz, playerDistance)
    local fx, fy = updateFollowHeading(player, follow, px, py)
    local slot = tonumber(record and record.companion and record.companion.squadSlot) or 1
    local followMode = updateFollowMode(follow, playerDistance)
    if followMode ~= "formation" then
        return px - fx * FOLLOW_CATCHUP_OFFSET,
            py - fy * FOLLOW_CATCHUP_OFFSET,
            pz, slot, followMode
    end
    local formation = FOLLOW_FORMATION[slot] or { back = FOLLOW_OFFSET, side = 0 }
    local lateralX, lateralY = -fy, fx
    return px - fx * formation.back + lateralX * formation.side,
        py - fy * formation.back + lateralY * formation.side,
        pz, slot, followMode
end

local function followLocomotion(player)
    local sneaking = protectedCall(player, "isSneaking") == true
    local sprinting = protectedCall(player, "isSprinting") == true
    local running = protectedCall(player, "isRunning") == true

    if sneaking and (running or sprinting) then
        return "crouch_run", FOLLOW_LOCOMOTION.crouch_run, sneaking, running, sprinting
    end
    if sneaking then
        return "crouch_walk", FOLLOW_LOCOMOTION.crouch_walk, sneaking, running, sprinting
    end
    if sprinting then
        return "sprint", FOLLOW_LOCOMOTION.sprint, sneaking, running, sprinting
    end
    if running then
        return "run", FOLLOW_LOCOMOTION.run, sneaking, running, sprinting
    end
    return "walk", FOLLOW_LOCOMOTION.walk, sneaking, running, sprinting
end

local function tickFollowPlayer(record, handle, intent)
    local actor = handle and handle.actor or nil
    local brain = brainFor(actor)
    if not actor or not brain then
        return { handled = true, failed = true, status = "failed", reason = "bandit_actor_missing" }
    end
    local player = getSpecificPlayer and getSpecificPlayer(0) or (getPlayer and getPlayer()) or nil
    if not player then
        return { handled = true, failed = true, status = "failed", reason = "follow_player_missing" }
    end

    enforceSafety(actor, brain)
    if brain.lwnCombatEngaged == true then
        return {
            handled = true,
            status = "combat",
            reason = brain.lwnCombatReason or "combat_interrupt",
        }
    end
    handle.runtime = handle.runtime or {}
    local follow = handle.runtime.follow
    if not follow or follow.intent ~= intent then
        stopActor(actor)
        follow = {
            intent = intent,
            taskCycles = 0,
            repaths = 0,
            lastProgressAtMs = nowMs(),
            lastX = tonumber(protectedCall(actor, "getX") or 0) or 0,
            lastY = tonumber(protectedCall(actor, "getY") or 0) or 0,
        }
        handle.runtime.follow = follow
        handle.runtime.move = nil
        handle.runtime.lastMove = nil
    end

    local ax = tonumber(protectedCall(actor, "getX") or 0) or 0
    local ay = tonumber(protectedCall(actor, "getY") or 0) or 0
    local px = tonumber(protectedCall(player, "getX") or ax) or ax
    local py = tonumber(protectedCall(player, "getY") or ay) or ay
    local pz = tonumber(protectedCall(player, "getZ") or 0) or 0
    local playerDx, playerDy = ax - px, ay - py
    local playerDistance = math.sqrt(playerDx * playerDx + playerDy * playerDy)
    local tx, ty, tz, formationSlot, followMode = followTarget(
        player, record, follow, px, py, pz, playerDistance
    )
    local targetDx, targetDy = ax - tx, ay - ty
    local targetDistance = math.sqrt(targetDx * targetDx + targetDy * targetDy)
    local movementMode, profile, playerSneaking, playerRunning, playerSprinting = followLocomotion(player)
    if followMode == "hard_catchup" then
        movementMode = "sprint"
        profile = FOLLOW_LOCOMOTION.sprint
    elseif followMode == "catchup" and movementMode ~= "sprint" then
        movementMode = "run"
        profile = FOLLOW_LOCOMOTION.run
    end
    local walkType = profile.walkType
    local now = nowMs()

    if targetDistance > FOLLOW_ARRIVAL_DISTANCE then
        local progressDx, progressDy = ax - follow.lastX, ay - follow.lastY
        if math.sqrt(progressDx * progressDx + progressDy * progressDy) >= MOVE_PROGRESS_EPSILON then
            follow.lastX = ax
            follow.lastY = ay
            follow.lastProgressAtMs = now
        elseif now - follow.lastProgressAtMs >= MOVE_STALL_MS then
            stopActor(actor)
            follow.repaths = follow.repaths + 1
            follow.lastProgressAtMs = now
            follow.lastX = ax
            follow.lastY = ay
            print(string.format(
                "[LWN][Bandits] follow repath npcId=%s key=%s repath=%s distance=%.2f",
                tostring(record.id), tostring(handle.correlationKey), tostring(follow.repaths), playerDistance
            ))
        end
    else
        follow.lastProgressAtMs = now
        follow.lastX = ax
        follow.lastY = ay
    end

    local currentTask = Bandit and Bandit.GetTask and Bandit.GetTask(actor) or nil
    local targetShift = follow.targetX and math.sqrt((tx - follow.targetX) ^ 2 + (ty - follow.targetY) ^ 2) or math.huge
    local styleChanged = follow.movementMode ~= nil and follow.movementMode ~= movementMode
    local canRetarget = follow.lastTaskAtMs == nil or now - follow.lastTaskAtMs >= FOLLOW_RETARGET_MS
    if currentTask and canRetarget and (styleChanged or targetShift >= FOLLOW_RETARGET_DISTANCE) then
        stopActor(actor)
        currentTask = nil
    end

    applyMovementProfile(actor, profile)
    if follow.loggedMovementMode ~= movementMode then
        local baseWalkSpeed, baseRunSpeed = movementBaseSpeeds(actor)
        print(string.format(
            "[LWN][Bandits] follow style npcId=%s key=%s mode=%s walkType=%s walkSpeed=%.2f runSpeed=%.2f playerDistance=%.2f",
            tostring(record.id), tostring(handle.correlationKey), tostring(movementMode), tostring(walkType),
            baseWalkSpeed * (profile.walkMultiplier or 1), baseRunSpeed * (profile.runMultiplier or 1), playerDistance
        ))
        follow.loggedMovementMode = movementMode
    end
    follow.movementMode = movementMode
    follow.walkType = walkType
    follow.playerSneaking = playerSneaking
    follow.playerRunning = playerRunning
    follow.playerSprinting = playerSprinting
    follow.playerDistance = playerDistance
    follow.targetDistance = targetDistance
    follow.desiredTargetX = tx
    follow.desiredTargetY = ty
    follow.desiredTargetZ = tz
    follow.formationSlot = formationSlot
    if follow.loggedFollowMode ~= followMode then
        print(string.format(
            "[LWN][FollowWatch] npcId=%s slot=%s state=%s playerDistance=%.2f targetDistance=%.2f heading=%s target=%.1f,%.1f",
            tostring(record.id), tostring(formationSlot), tostring(followMode), playerDistance,
            targetDistance, tostring(follow.headingSource), tx, ty
        ))
        follow.loggedFollowMode = followMode
    end
    follow.followMode = followMode

    if targetDistance <= FOLLOW_ARRIVAL_DISTANCE then
        if currentTask or brain.lwnMoveActive == true then
            stopActor(actor)
        end
        brain.lwnFollowActive = true
        return {
            handled = true,
            status = "following",
            reason = "follow_holding_trailing_position",
            distance = playerDistance,
            walkType = walkType,
            taskCycles = follow.taskCycles,
        }
    end

    currentTask = Bandit and Bandit.GetTask and Bandit.GetTask(actor) or nil
    if not currentTask then
        follow.taskCycles = follow.taskCycles + 1
        follow.targetX = tx
        follow.targetY = ty
        follow.targetZ = tz
        follow.lastTaskAtMs = now
        brain.lwnMoveActive = true
        brain.lwnFollowActive = true
        if Bandit and Bandit.ForceStationary then Bandit.ForceStationary(actor, false) end
        local task = BanditUtils.GetMoveTask(profile.endurance, tx, ty, tz, walkType, targetDistance, true)
        task.lwnFollow = true
        task.lwnCycle = follow.taskCycles
        task.lwnMovementMode = movementMode
        task.lwnWalkType = walkType
        Bandit.AddTask(actor, task)
    end

    return {
        handled = true,
        status = "following",
        reason = "follow_trailing_player",
        distance = playerDistance,
        walkType = walkType,
        taskCycles = follow.taskCycles,
    }
end

function Carrier.tickIntent(record, handle, intent)
    if not intent then return { handled = false } end
    if intent.kind == "move_to" then
        return tickMoveTo(record, handle, intent)
    end
    if intent.kind == "follow_player" then
        return tickFollowPlayer(record, handle, intent)
    end
    return { handled = false }
end

function Carrier.retire(record, handle, options)
    if not handle then return { ok = true, status = "retired", detail = "handle missing" } end
    Carrier.RetiredKeys[handle.correlationKey] = nowMs() + ORPHAN_SWEEP_MS
    if handle.actor then
        removeActor(handle.actor, options and options.reason or "carrier_retire", handle.banditId)
    end
    handle.actor = nil
    handle.pending = false
    handle.status = "retired"
    return { ok = true, status = "retired", detail = options and options.reason or "retired" }
end

function Carrier.tick()
    local now = nowMs()
    tickPendingHitRepairs()
    for key, expiresAt in pairs(Carrier.RetiredKeys) do
        local matches = matchingActors(key)
        for i = 1, #matches do
            removeActor(matches[i].actor, "late_orphan", matches[i].id)
        end
        if now >= expiresAt then
            Carrier.RetiredKeys[key] = nil
        end
    end
end

function Carrier.getDebugState(record, handle)
    local actor = handle and handle.actor or nil
    local brain = brainFor(actor)
    local task = actor and Bandit and Bandit.GetTask and Bandit.GetTask(actor) or nil
    local combatActions = {
        Aim = true,
        Equip = true,
        Hit = true,
        Load = true,
        Push = true,
        Rack = true,
        Shoot = true,
        Smack = true,
        Stomp = true,
        Unequip = true,
        Unload = true,
    }
    local combatTask = nil
    for _, queued in pairs(brain and brain.tasks or {}) do
        if queued and combatActions[queued.action] then
            combatTask = queued.action
            break
        end
    end
    local playingSounds = {}
    local emitter = protectedCall(actor, "getEmitter")
    for _, soundName in pairs(Bandit and Bandit.SoundStopList or {}) do
        if protectedCall(emitter, "isPlaying", soundName) == true then
            playingSounds[#playingSounds + 1] = soundName
        end
    end
    local move = handle and handle.runtime and handle.runtime.move or nil
    local follow = handle and handle.runtime and handle.runtime.follow or nil
    local lastMove = handle and handle.runtime and handle.runtime.lastMove or nil
    local hostile, hostileP, nonCombat = nil, nil, nil
    if brain then
        hostile = brain.hostile
        hostileP = brain.hostileP
        nonCombat = brain.lwnNonCombat
    end
    return {
        correlationKey = handle and handle.correlationKey or nil,
        sessionId = handle and handle.sessionId or nil,
        banditId = handle and handle.banditId or nil,
        pending = handle and handle.pending or false,
        hostile = hostile,
        hostileP = hostileP,
        nonCombat = nonCombat,
        controlled = brain and brain.lwnControlled == true or false,
        combatEngaged = brain and brain.lwnCombatEngaged == true or false,
        combatReason = brain and brain.lwnCombatReason or nil,
        task = task and task.action or nil,
        combatTask = combatTask,
        moveAttempt = task and task.lwnAttempt or move and move.attempts or lastMove and lastMove.attempts or nil,
        moveCycle = task and task.lwnCycle or move and move.taskCycles or lastMove and lastMove.taskCycles or nil,
        moveStatus = move and "pathing" or lastMove and lastMove.status or nil,
        moveReason = lastMove and lastMove.reason or nil,
        moveDistance = lastMove and lastMove.distance or nil,
        followActive = follow ~= nil,
        followMode = follow and follow.followMode or nil,
        followHeadingSource = follow and follow.headingSource or nil,
        followTargetX = follow and follow.desiredTargetX or nil,
        followTargetY = follow and follow.desiredTargetY or nil,
        followMovementMode = follow and follow.movementMode or nil,
        followWalkType = follow and follow.walkType or nil,
        followPlayerSneaking = follow and follow.playerSneaking or false,
        followPlayerRunning = follow and follow.playerRunning or false,
        followPlayerSprinting = follow and follow.playerSprinting or false,
        followTaskCycles = follow and follow.taskCycles or nil,
        followRepaths = follow and follow.repaths or nil,
        followPlayerDistance = follow and follow.playerDistance or nil,
        followTargetDistance = follow and follow.targetDistance or nil,
        spawnCalmActive = handle and handle.runtime and handle.runtime.spawnCalm and handle.runtime.spawnCalm.active == true or false,
        target = protectedCall(actor, "getTarget") ~= nil,
        audioActive = #playingSounds > 0,
        audio = #playingSounds > 0 and table.concat(playingSounds, ",") or "none",
    }
end


if Events and Events.OnHitZombie then
    if Carrier._onHitZombieHandler then
        Events.OnHitZombie.Remove(Carrier._onHitZombieHandler)
    end
    Carrier._onHitZombieHandler = function(actor, attacker)
        Carrier.onHitZombie(actor, attacker)
    end
    Events.OnHitZombie.Add(Carrier._onHitZombieHandler)
end


if Events and Events.OnWeaponHitCharacter then
    if Carrier._onWeaponHitCharacterHandler then
        Events.OnWeaponHitCharacter.Remove(Carrier._onWeaponHitCharacterHandler)
    end
    Carrier._onWeaponHitCharacterHandler = function(attacker, actor)
        return Carrier.onWeaponHitCharacter(attacker, actor)
    end
    Events.OnWeaponHitCharacter.Add(Carrier._onWeaponHitCharacterHandler)
end
