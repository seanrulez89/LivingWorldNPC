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
local DEFAULT_WALK_SPEED = 1.04
local DEFAULT_RUN_SPEED = 0.72

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
    return actor and BanditBrain and BanditBrain.Get and BanditBrain.Get(actor) or nil
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

local function removeActor(actor, reason)
    if not actor then return end
    local brain = brainFor(actor)
    local id = brain and brain.id or (BanditUtils and BanditUtils.GetZombieID and BanditUtils.GetZombieID(actor)) or nil
    stopActor(actor)
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    if id and player and sendClientCommand then
        sendClientCommand(player, "Commands", "BanditRemove", { id = id })
    end
    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")
    clearBanditCaches(id)
    print(string.format("[LWN][Bandits] removed banditId=%s reason=%s", tostring(id), tostring(reason)))
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
    brain.lwnNonCombat = true
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setLastTargettedBy", nil)
    protectedCall(actor, "setAttackedBy", nil)
    protectedCall(actor, "setEatBodyTarget", nil, false)
    protectedCall(actor, "setNoTeeth", true)
    protectedCall(actor, "setGodMod", true)
    protectedCall(actor, "setInvulnerable", true)
    protectedCall(actor, "setVariable", "NoLungeTarget", true)
    if Bandit and Bandit.SurpressZombieSounds then
        Bandit.SurpressZombieSounds(actor)
    end
    stopBanditBreathing(actor)
end

local function friendlyRecordForActor(actor)
    local modData = protectedCall(actor, "getModData")
    local npcId = modData and (modData.LWN_NpcId or modData.LWN_LastNpcId) or nil
    local record = npcId and LWN.PopulationStore and LWN.PopulationStore.getNPC
        and LWN.PopulationStore.getNPC(npcId) or nil
    if not record then return nil end
    local policy = LWN.Social and LWN.Social.relationshipCombatPolicy
        and LWN.Social.relationshipCombatPolicy(record) or nil
    if not policy or policy.allowPlayerAttack == true then return nil end
    return record
end

function Carrier.onHitZombie(actor, attacker)
    local brain = brainFor(actor)
    if not isControlledBrain(brain) then return end
    local record = friendlyRecordForActor(actor)
    if not record then return end

    local canonicalHealth = tonumber(record.stats and record.stats.health)
    if canonicalHealth and canonicalHealth > 0 then
        protectedCall(actor, "setHealth", canonicalHealth)
    end
    protectedCall(actor, "setKnockedDown", false)
    protectedCall(actor, "setOnFloor", false)
    protectedCall(actor, "setFallOnFront", false)
    protectedCall(actor, "setAlwaysKnockedDown", false)
    enforceSafety(actor, brain)
    if Bandit and Bandit.ForceStationary then
        Bandit.ForceStationary(actor, brain.lwnMoveActive ~= true)
    end
    print(string.format(
        "[LWN][Bandits] friendly hit suppressed npcId=%s banditId=%s attacker=%s health=%.2f",
        tostring(record.id), tostring(brain.id), tostring(attacker),
        tonumber(protectedCall(actor, "getHealth") or canonicalHealth or 0) or 0
    ))
end

local function stampActor(record, handle, actor, brain)
    brain.lwnNpcId = record.id
    brain.lwnSessionId = handle.sessionId
    brain.lwnNonCombat = true
    brain.key = handle.correlationKey
    brain.fullname = displayName(record)
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
        modData.LWN_DisplayName = brain.fullname
        modData.LWN_AllowPlayerAttack = false
    end
    local descriptor = protectedCall(actor, "getDescriptor")
    protectedCall(descriptor, "setForename", record.identity and record.identity.firstName or nil)
    protectedCall(descriptor, "setSurname", record.identity and record.identity.lastName or nil)
    protectedCall(actor, "setForname", record.identity and record.identity.firstName or nil)
    protectedCall(actor, "setSurname", record.identity and record.identity.lastName or nil)
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
            lwnNonCombat = true,
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
            removeActor(matches[i].actor, "duplicate_correlation_key")
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
    if brain.lwnMoveActive ~= true and Bandit and Bandit.ForceStationary then
        Bandit.ForceStationary(actor, true)
    end
    return { ok = true, status = "active", detail = options and options.source or "synced" }
end

function Carrier.getActor(handle)
    return handle and handle.actor or nil
end

function Carrier.isUsable(handle)
    local actor = handle and handle.actor or nil
    if not actor then return false end
    if protectedCall(actor, "isAlive") == false then return false end
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

local function followTarget(player)
    local px = tonumber(protectedCall(player, "getX") or 0) or 0
    local py = tonumber(protectedCall(player, "getY") or 0) or 0
    local pz = tonumber(protectedCall(player, "getZ") or 0) or 0
    local direction = protectedCall(player, "getForwardDirection")
    local fx = tonumber(protectedCall(direction, "getX") or 0) or 0
    local fy = tonumber(protectedCall(direction, "getY") or 0) or 0
    local length = math.sqrt(fx * fx + fy * fy)
    if length > 0.001 then
        fx = fx / length
        fy = fy / length
    end
    return px - fx * FOLLOW_OFFSET, py - fy * FOLLOW_OFFSET, pz
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
    local tx, ty, tz = followTarget(player)
    local targetDx, targetDy = ax - tx, ay - ty
    local targetDistance = math.sqrt(targetDx * targetDx + targetDy * targetDy)
    local playerDx, playerDy = ax - px, ay - py
    local playerDistance = math.sqrt(playerDx * playerDx + playerDy * playerDy)
    local movementMode, profile, playerSneaking, playerRunning, playerSprinting = followLocomotion(player)
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
        removeActor(handle.actor, options and options.reason or "carrier_retire")
    end
    handle.actor = nil
    handle.pending = false
    handle.status = "retired"
    return { ok = true, status = "retired", detail = options and options.reason or "retired" }
end

function Carrier.tick()
    local now = nowMs()
    for key, expiresAt in pairs(Carrier.RetiredKeys) do
        local matches = matchingActors(key)
        for i = 1, #matches do
            removeActor(matches[i].actor, "late_orphan")
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
        task = task and task.action or nil,
        combatTask = combatTask,
        moveAttempt = task and task.lwnAttempt or move and move.attempts or lastMove and lastMove.attempts or nil,
        moveCycle = task and task.lwnCycle or move and move.taskCycles or lastMove and lastMove.taskCycles or nil,
        moveStatus = move and "pathing" or lastMove and lastMove.status or nil,
        moveReason = lastMove and lastMove.reason or nil,
        moveDistance = lastMove and lastMove.distance or nil,
        followActive = follow ~= nil,
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
