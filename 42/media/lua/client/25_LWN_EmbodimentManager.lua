LWN = LWN or {}
LWN.EmbodimentManager = LWN.EmbodimentManager or {}

local Embody = LWN.EmbodimentManager
local Store = LWN.PopulationStore

Embody._actors = Embody._actors or {}
Embody._carrierHandles = Embody._carrierHandles or {}
Embody._cleanupBlocklist = Embody._cleanupBlocklist or {}
Embody._cleanupInFlight = Embody._cleanupInFlight or {}

local function ensureRecordShape(record)
    if Store and Store.ensureRecordShape then
        return Store.ensureRecordShape(record)
    end
    return record
end

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end

    local ok, result = pcall(fn, obj, ...)
    if ok then
        return result
    end
    return nil
end

local function dist2(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

local function safeText(value)
    if value == nil then return "nil" end
    local text = tostring(value)
    text = text:gsub("[\r\n|]", " ")
    return text
end

local function normalizeSampleValue(value)
    local text = safeText(value)
    text = text:gsub("%-?%d+%.%d+", "#")
    text = text:gsub("%-?%d+", "#")
    text = text:gsub("%s+", " ")
    return text
end

local function sampleDebugEvent(bucketName, key, signature, options)
    if LWN.ActorFactory and LWN.ActorFactory.sampleDebugEvent then
        return LWN.ActorFactory.sampleDebugEvent(bucketName, key, signature, options)
    end
    return {
        emit = true,
        reason = "local_fallback",
        seenCount = 1,
        suppressedCount = 0,
    }
end

local function sampleSuffix(sample)
    if not sample then return "" end

    local parts = {}
    if sample.reason and sample.reason ~= "new" then
        parts[#parts + 1] = "sample=" .. safeText(sample.reason)
    end
    if (sample.suppressedCount or 0) > 0 then
        parts[#parts + 1] = "suppressed=" .. safeText(sample.suppressedCount)
    end
    if #parts == 0 then
        return ""
    end
    return " | " .. table.concat(parts, " | ")
end

local function objectRef(value)
    if value == nil then return "nil" end
    return safeText(tostring(value))
end

local function worldObjectKind(obj)
    if not obj then return "nil" end
    if instanceof then
        if instanceof(obj, "IsoDeadBody") then return "corpse" end
        if instanceof(obj, "IsoZombie") then return "zombie" end
        if instanceof(obj, "IsoPlayer") then return "player" end
        if instanceof(obj, "IsoSurvivor") then return "survivor" end
    end
    return safeText(protectedCall(obj, "getObjectName"))
end

local function getKnownNpcId(obj)
    if not obj then return nil end
    local modData = protectedCall(obj, "getModData")
    if not modData then return nil end
    return modData.LWN_NpcId or modData.LWN_LastNpcId or nil
end

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or nil
end

local function updateLastKnownPosition(record, actor, overrides)
    record = ensureRecordShape(record)
    if not record then return nil end

    local x = overrides and overrides.x or protectedCall(actor, "getX") or record.anchor.x or 0
    local y = overrides and overrides.y or protectedCall(actor, "getY") or record.anchor.y or 0
    local z = overrides and overrides.z or protectedCall(actor, "getZ") or record.anchor.z or 0

    record.embodiment = record.embodiment or {}
    record.embodiment.lastKnownX = tonumber(x) or 0
    record.embodiment.lastKnownY = tonumber(y) or 0
    record.embodiment.lastKnownZ = tonumber(z) or 0
    record.embodiment.lastKnownHour = worldAgeHours()

    return {
        x = math.floor(record.embodiment.lastKnownX),
        y = math.floor(record.embodiment.lastKnownY),
        z = math.floor(record.embodiment.lastKnownZ),
    }
end

local function isAlive(record)
    if Store and Store.isAlive then
        return Store.isAlive(record)
    end
    return record ~= nil
end

local function touchRecordStage(record, stage, reason)
    record = ensureRecordShape(record)
    if not record then return end

    record.embodiment.stage = stage
    record.embodiment.lastStageAt = worldAgeHours()
    record.embodiment.lastStageReason = reason
    if LWN.Log and LWN.Log.state then
        LWN.Log.state("Embodiment", "stage:" .. tostring(record.id), tostring(stage) .. "|" .. tostring(reason), {
            npcId = record.id,
            state = record.embodiment.state,
            stage = stage,
            reason = reason,
            carrier = record.embodiment.carrierKind,
        })
    end
end

local function touchCleanupRecord(record, state, reason, removeRecord)
    record = ensureRecordShape(record)
    if not record then return end

    local cleanup = record.embodiment.cleanup or {}
    record.embodiment.cleanup = cleanup
    cleanup.state = state
    cleanup.reason = reason or cleanup.reason
    if removeRecord ~= nil then
        cleanup.removeRecord = removeRecord == true
    end
    if state == "pending" then
        cleanup.requestedAt = cleanup.requestedAt or worldAgeHours()
    elseif state == "complete" then
        cleanup.completedAt = worldAgeHours()
    end
    if LWN.Log and LWN.Log.state then
        LWN.Log.state("Cleanup", "cleanup:" .. tostring(record.id), tostring(state) .. "|" .. tostring(reason), {
            npcId = record.id,
            state = state,
            reason = reason,
            status = record.embodiment and record.embodiment.state,
            removeRecord = cleanup.removeRecord,
        })
    end
end

local function clearRecordTarget(record, reason)
    record = ensureRecordShape(record)
    if not record then return end

    record.embodiment.target = record.embodiment.target or {}
    record.embodiment.target.kind = nil
    record.embodiment.target.npcId = nil
    record.embodiment.target.lastKnownX = nil
    record.embodiment.target.lastKnownY = nil
    record.embodiment.target.lastKnownZ = nil
    record.embodiment.target.lastResolvedHour = worldAgeHours()
    record.embodiment.target.lastReason = reason
end

local function touchDeathRecord(record, state, source, reason)
    record = ensureRecordShape(record)
    if not record then return end

    local death = record.embodiment.death or {}
    record.embodiment.death = death
    death.state = state
    death.source = source or death.source
    death.reason = reason or death.reason
    if LWN.Log and LWN.Log.state then
        LWN.Log.state("Carrier", "death:" .. tostring(record.id), tostring(state) .. "|" .. tostring(source) .. "|" .. tostring(reason), {
            npcId = record.id,
            state = state,
            source = source,
            reason = reason,
            health = record.stats and record.stats.health,
        })
    end
    if state == "alive" then
        death.latched = false
        death.latchedAt = nil
        death.corpseSeen = false
        death.corpseSeenAt = nil
        death.corpseVisual = false
        death.cleanupRequested = false
        return
    end

    death.latched = true
    death.latchedAt = death.latchedAt or worldAgeHours()
end

local function getCleanupState(npcId)
    if not npcId then return nil end
    return Embody._cleanupInFlight[npcId] or Embody._cleanupBlocklist[npcId] or nil
end

local function getActorCleanupState(actor)
    if not actor then return nil end
    local modData = protectedCall(actor, "getModData")
    if not modData then return nil end
    if modData.LWN_CleanupPending ~= true and modData.LWN_CleanupStage == nil and modData.LWN_LastCleanupStage == nil then
        return nil
    end
    return {
        pending = modData.LWN_CleanupPending == true,
        stage = modData.LWN_CleanupStage or modData.LWN_LastCleanupStage,
        reason = modData.LWN_CleanupReason or modData.LWN_LastCleanupReason,
        npcId = modData.LWN_CleanupNpcId or modData.LWN_NpcId or modData.LWN_LastNpcId,
    }
end

local function cleanupStateSummary(npcId)
    local state = getCleanupState(npcId)
    if not state then return "cleanupState=nil" end
    return string.format(
        "cleanupStage=%s cleanupReason=%s removeRecord=%s actorRef=%s",
        tostring(state.stage),
        tostring(state.reason),
        tostring(state.removeRecord),
        tostring(state.actorRef)
    )
end

local function updateCleanupState(npcId, stage, reason, record, actor, extra)
    if not npcId then return nil end

    local state = getCleanupState(npcId) or {}
    state.stage = stage or state.stage
    state.reason = reason or state.reason
    state.at = worldAgeHours()
    state.recordState = record and record.embodiment and record.embodiment.state or state.recordState
    state.actorRef = actor and objectRef(actor) or state.actorRef
    if extra then
        if extra.removeRecord ~= nil then
            state.removeRecord = extra.removeRecord
        end
        if extra.detail ~= nil then
            state.detail = extra.detail
        end
        if extra.actorSource ~= nil then
            state.actorSource = extra.actorSource
        end
        if extra.registeredMatch ~= nil then
            state.registeredMatch = extra.registeredMatch
        end
        if extra.actor ~= nil then
            state.actor = extra.actor
        end
        if extra.deferred ~= nil then
            state.deferred = extra.deferred == true
        end
        if extra.attempts ~= nil then
            state.attempts = extra.attempts
        end
        if extra.skipDetail ~= nil then
            state.skipDetail = extra.skipDetail
        end
        if extra.cooldownUntilHour ~= nil then
            state.cooldownUntilHour = extra.cooldownUntilHour
        end
    end

    if Embody._cleanupInFlight[npcId] or not Embody._cleanupBlocklist[npcId] then
        Embody._cleanupInFlight[npcId] = state
    end
    if Embody._cleanupBlocklist[npcId] then
        Embody._cleanupBlocklist[npcId] = state
    end
    return state
end

local function actorDeathLike(actor)
    if not actor then return false end
    if protectedCall(actor, "isDead") == true then return true end
    if protectedCall(actor, "isAlive") == false then return true end
    local health = tonumber(protectedCall(actor, "getHealth"))
    if health ~= nil and health <= 0 then return true end
    if LWN.ActorFactory and LWN.ActorFactory.isDeathLikeActor then
        local ok, deathLike = pcall(LWN.ActorFactory.isDeathLikeActor, actor)
        if ok and deathLike == true then return true end
    end
    return false
end

local function retireWorldObjectIdentity(modData, npcId)
    if not modData then return end
    modData.LWN_LastNpcId = npcId or modData.LWN_NpcId or modData.LWN_LastNpcId
    modData.LWN_FormerCarrierKind = modData.LWN_CarrierKind or modData.LWN_FormerCarrierKind
    modData.LWN_FormerTestHarnessLabel = modData.LWN_TestHarnessLabel or modData.LWN_FormerTestHarnessLabel
    modData.LWN_NpcId = nil
    modData.LWN_CarrierKind = nil
    modData.LWN_ShellMarker = nil
    modData.LWN_TestHarnessLabel = nil
    modData.LWN_ManagedShellContract = nil
    modData.LWN_AllowPlayerAttack = nil
end

local function getLifecycleBlock(record, actor)
    if not record then
        return "record_missing", "record=nil"
    end
    if not isAlive(record) then
        return "record_dead", "recordLife=dead"
    end

    if Embody._cleanupInFlight[record.id] then
        return "cleanup_in_progress", cleanupStateSummary(record.id)
    end
    if Embody._cleanupBlocklist[record.id] then
        return "cleanup_blocked", cleanupStateSummary(record.id)
    end
    if record.embodiment and record.embodiment.state == "removed" then
        return "record_removed", "recordState=removed"
    end
    if actorDeathLike(actor) then
        return "actor_death_like", string.format(
            "actorDead=%s actorAlive=%s actorHealth=%s",
            tostring(protectedCall(actor, "isDead")),
            tostring(protectedCall(actor, "isAlive")),
            tostring(protectedCall(actor, "getHealth"))
        )
    end

    local actorCleanup = getActorCleanupState(actor)
    if actorCleanup and actorCleanup.pending == true then
        return "actor_cleanup_pending", string.format(
            "actorCleanupStage=%s actorCleanupReason=%s actorCleanupNpcId=%s",
            tostring(actorCleanup.stage),
            tostring(actorCleanup.reason),
            tostring(actorCleanup.npcId)
        )
    end

    return nil, nil
end

local function traceCleanup(stage, npcId, record, actor, extra)
    local cleanupState = getCleanupState(npcId)
    local sample = sampleDebugEvent(
        "cleanup_trace",
        table.concat({
            safeText(stage),
            safeText(npcId),
            safeText(objectRef(actor)),
        }, "|"),
        table.concat({
            safeText(stage),
            safeText(record and record.embodiment and record.embodiment.state or nil),
            safeText(worldObjectKind(actor)),
            safeText(actor and protectedCall(actor, "isExistInTheWorld") or nil),
            safeText(Embody._cleanupBlocklist and Embody._cleanupBlocklist[npcId] ~= nil or false),
            safeText(cleanupState and cleanupState.stage or nil),
            safeText(cleanupState and cleanupState.reason or nil),
            normalizeSampleValue(extra and extra.reason or nil),
            normalizeSampleValue(extra and extra.detail or nil),
        }, "|")
    )
    if sample.emit ~= true then
        return
    end

    print(string.format(
        "[LWN][CleanupTrace] stage=%s | npcId=%s | recordExists=%s | recordState=%s | actorRef=%s | actorKind=%s | actorWorld=%s | blocked=%s | cleanupStage=%s | cleanupReason=%s | reason=%s | detail=%s%s",
        safeText(stage),
        safeText(npcId),
        safeText(record ~= nil),
        safeText(record and record.embodiment and record.embodiment.state or nil),
        safeText(objectRef(actor)),
        safeText(worldObjectKind(actor)),
        safeText(actor and protectedCall(actor, "isExistInTheWorld") or nil),
        safeText(Embody._cleanupBlocklist and Embody._cleanupBlocklist[npcId] ~= nil or false),
        safeText(cleanupState and cleanupState.stage or nil),
        safeText(cleanupState and cleanupState.reason or nil),
        safeText(extra and extra.reason or nil),
        safeText(extra and extra.detail or nil),
        sampleSuffix(sample)
    ))
end

local function summarizeCleanupObjects(leftovers, actor)
    if not leftovers or #leftovers == 0 then
        return "count=0"
    end

    local actorKey = objectRef(actor)
    local parts = {}
    for _, obj in ipairs(leftovers) do
        parts[#parts + 1] = string.format(
            "%s[sameActor=%s ref=%s world=%s]",
            tostring(worldObjectKind(obj)),
            tostring(actor and objectRef(obj) == actorKey or false),
            tostring(objectRef(obj)),
            tostring(protectedCall(obj, "isExistInTheWorld"))
        )
    end

    return string.format("count=%d objects=%s", #leftovers, table.concat(parts, ";"))
end

local function shouldTraceLeftoverSnapshot(leftovers, actor)
    if not leftovers or #leftovers == 0 then
        return false
    end

    if #leftovers ~= 1 then
        return true
    end

    local obj = leftovers[1]
    if not obj then
        return false
    end

    if actor and obj == actor and protectedCall(obj, "isExistInTheWorld") ~= true then
        return false
    end

    return true
end

local function clearUiTargets(npcId)
    if not npcId then return end

    if LWN.UICommandPanel and LWN.UICommandPanel.targetNpcId == npcId and LWN.UICommandPanel.hide then
        LWN.UICommandPanel.hide()
    end
    if LWN.UIDialogueWindow and LWN.UIDialogueWindow.targetNpcId == npcId and LWN.UIDialogueWindow.hide then
        LWN.UIDialogueWindow.hide()
    end
    if LWN.UIRadialMenu and LWN.UIRadialMenu.targetNpcId == npcId and LWN.UIRadialMenu.hide then
        LWN.UIRadialMenu.hide()
    end
end

local function appendMatchingObjects(results, seen, list, npcId)
    if not list or not list.size or not list.get or not npcId then return end

    for i = 0, list:size() - 1 do
        local obj = list:get(i)
        if getKnownNpcId(obj) == npcId then
            local ref = objectRef(obj)
            if not seen[ref] then
                seen[ref] = true
                results[#results + 1] = obj
            end
        end
    end
end

local function collectCleanupObjects(record, npcId, actor)
    local results = {}
    local seen = {}
    local cell = getCell and getCell() or nil

    if actor then
        local ref = objectRef(actor)
        seen[ref] = true
        results[#results + 1] = actor
    end

    if not cell or not record or not npcId then
        return results
    end

    local meta = Store.getEmbodiedMeta and Store.getEmbodiedMeta(npcId) or nil
    local cx = math.floor((meta and meta.x) or record.anchor.x or 0)
    local cy = math.floor((meta and meta.y) or record.anchor.y or 0)
    local cz = math.floor((meta and meta.z) or record.anchor.z or 0)

    for y = cy - 2, cy + 2 do
        for x = cx - 2, cx + 2 do
            local square = cell:getGridSquare(x, y, cz)
            if square then
                appendMatchingObjects(results, seen, protectedCall(square, "getMovingObjects"), npcId)
                appendMatchingObjects(results, seen, protectedCall(square, "getStaticMovingObjects"), npcId)
            end
        end
    end

    return results
end

local function detachWorldObject(obj, npcId, reason, options)
    if not obj then return end

    local modData = protectedCall(obj, "getModData")
    local preserveWorldObject = options and options.preserveWorldObject == true or false
    traceCleanup("leftover.cleanup.start", npcId, nil, obj, {
        reason = reason,
        detail = string.format("kind=%s preserve=%s", tostring(worldObjectKind(obj)), tostring(preserveWorldObject)),
    })

    if preserveWorldObject then
        retireWorldObjectIdentity(modData, npcId)
        traceCleanup("leftover.cleanup.preserved", npcId, nil, obj, {
            reason = reason,
            detail = string.format("kind=%s", tostring(worldObjectKind(obj))),
        })
        return
    end

    if LWN.ActorFactory and LWN.ActorFactory.hasRuntimeCore and LWN.ActorFactory.hasRuntimeCore(obj) and LWN.ActorFactory.cleanupActor then
        local cleanupResult = LWN.ActorFactory.cleanupActor(obj, reason)
        if cleanupResult and cleanupResult.deferred == true then
            traceCleanup("leftover.cleanup.deferred", npcId, nil, obj, {
                reason = reason,
                detail = cleanupResult.detail,
            })
            return
        end
    else
        protectedCall(obj, "removeFromSquare")
        protectedCall(obj, "removeFromWorld")
        if modData then
            modData.LWN_LastNpcId = npcId or modData.LWN_LastNpcId
            modData.LWN_NpcId = nil
        end
    end

    traceCleanup("leftover.cleanup.complete", npcId, nil, obj, {
        reason = reason,
        detail = string.format(
            "kind=%s world=%s",
            tostring(worldObjectKind(obj)),
            tostring(protectedCall(obj, "isExistInTheWorld"))
        ),
    })
end

local function releaseActor(record, actor, nextState, cooldownHours, reason)
    if not record then return false end
    if nextState == "hidden" and Embody.canonicalCleanup then
        return Embody.canonicalCleanup(record, {
            actor = actor,
            removeRecord = false,
            blockNpcId = true,
            cooldownUntilHour = cooldownHours,
            reason = reason or "releaseActor",
            detail = "releaseActor",
        })
    end

    record = ensureRecordShape(record)
    clearUiTargets(record.id)
    clearRecordTarget(record, reason)
    record.embodiment.state = nextState
    record.embodiment.actorId = nil
    record.embodiment.missingTicks = 0
    record.embodiment.cooldownUntilHour = cooldownHours
    touchRecordStage(record, nextState == "hidden" and "inactive" or nextState, reason)
    Embody.unregisterActor(record, reason)
    return true
end

function Embody._activationRadiusFor(record)
    local companion = record.companion or {}
    if companion.recruited then
        return LWN.Config.Embodiment.CompanionDespawnRadiusTiles
    end
    return LWN.Config.Embodiment.RadiusTiles
end

local function activationOriginFor(record)
    if not record then
        return nil, nil, nil, "record=nil"
    end

    local meta = Store and Store.getEmbodiedMeta and Store.getEmbodiedMeta(record.id) or nil
    if meta and meta.x ~= nil and meta.y ~= nil then
        return tonumber(meta.x) or 0, tonumber(meta.y) or 0, tonumber(meta.z or record.anchor and record.anchor.z or 0) or 0, "embodied_meta"
    end

    if record.embodiment and record.embodiment.lastKnownX ~= nil and record.embodiment.lastKnownY ~= nil then
        return tonumber(record.embodiment.lastKnownX) or 0, tonumber(record.embodiment.lastKnownY) or 0, tonumber(record.embodiment.lastKnownZ or record.anchor and record.anchor.z or 0) or 0, "record_last_known"
    end

    local anchor = record.anchor or {}
    return tonumber(anchor.x) or 0, tonumber(anchor.y) or 0, tonumber(anchor.z) or 0, "anchor"
end

local function debugNpcShouldStayEmbodied(record)
    if not record then return false end
    if record.debugSpawnOnly ~= true then return false end
    if record.embodiment and record.embodiment.allowDebugDespawnForReturnTest == true then
        return false
    end
    if not (LWN.Config and LWN.Config.Debug and LWN.Config.Debug.KeepDebugSpawnsEmbodied == true) then
        return false
    end
    return true
end

local function shouldPreserveCarrierHandleOnHidden(record)
    if not record then return false end
    if not (record.embodiment and record.embodiment.state == "hidden") then
        return false
    end
    if isAlive(record) ~= true then
        return false
    end
    return record.embodiment.allowDebugDespawnForReturnTest == true
end

local function autoRearmCooldownHours(record)
    local companion = record.companion or {}
    if companion.recruited or record.debugSpawnOnly then
        return math.max((LWN.Config.Embodiment and LWN.Config.Embodiment.GraceHours) or 0.05, 0.05)
    end
    return ((LWN.Config.Population and LWN.Config.Population.EncounterCooldownHours) or 2.0)
end

local function setLastFailure(record, reason, detail)
    if not record then return end
    record.embodiment = record.embodiment or {}
    record.embodiment.lastFailureReason = reason
    record.embodiment.lastFailureDetail = detail
    record.embodiment.lastFailureHour = getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function traceStage(stage, record, actor, extra)
    if LWN.ActorFactory and LWN.ActorFactory.debugStage then
        LWN.ActorFactory.debugStage("EmbodimentManager", stage, record, actor, protectedCall(actor, "getDescriptor"), extra)
    end
end

local function registrySignature(record, actor)
    local meta = record and Store.getEmbodiedMeta and Store.getEmbodiedMeta(record.id) or nil
    local cleanup = getCleanupState(record and record.id or nil)
    local deathLike = actor and LWN.ActorFactory and LWN.ActorFactory.isDeathLikeActor and LWN.ActorFactory.isDeathLikeActor(actor) or false
    return table.concat({
        tostring(record and record.id or "nil"),
        tostring(record and record.embodiment and record.embodiment.state or "nil"),
        tostring(actor),
        tostring(actor and protectedCall(actor, "isExistInTheWorld") or nil),
        tostring(deathLike),
        tostring(meta and meta.state or "nil"),
        tostring(meta and meta.x or "nil"),
        tostring(meta and meta.y or "nil"),
        tostring(meta and meta.z or "nil"),
        tostring(cleanup and cleanup.stage or "nil"),
        tostring(cleanup and cleanup.reason or "nil"),
    }, "|")
end

local function traceRegistryState(stage, record, actor, extra, force)
    if not record then return end

    Embody._registryTraceCache = Embody._registryTraceCache or {}
    local signature = registrySignature(record, actor)
    if not force and Embody._registryTraceCache[record.id] == signature then
        return
    end
    Embody._registryTraceCache[record.id] = signature

    local meta = Store.getEmbodiedMeta and Store.getEmbodiedMeta(record.id) or nil
    local cleanup = getCleanupState(record.id)
    traceStage(stage, record, actor, {
        source = extra and extra.source or stage,
        detail = string.format(
            "recordState=%s actorRef=%s actorWorld=%s deathLike=%s metaState=%s metaPos=%s,%s,%s cleanupStage=%s cleanupReason=%s reason=%s",
            tostring(record.embodiment and record.embodiment.state or nil),
            tostring(actor),
            tostring(actor and protectedCall(actor, "isExistInTheWorld") or nil),
            tostring(actor and LWN.ActorFactory and LWN.ActorFactory.isDeathLikeActor and LWN.ActorFactory.isDeathLikeActor(actor) or false),
            tostring(meta and meta.state or nil),
            tostring(meta and meta.x or nil),
            tostring(meta and meta.y or nil),
            tostring(meta and meta.z or nil),
            tostring(cleanup and cleanup.stage or nil),
            tostring(cleanup and cleanup.reason or nil),
            tostring(extra and extra.reason or nil)
        ),
    })
end

function Embody.tryRearmHidden(record, player)
    if not record or not player then return false end
    record = ensureRecordShape(record)
    if not isAlive(record) then return false end
    if record.embodiment.state ~= "hidden" then return false end
    if getCleanupState(record.id) or Embody.isCleanupBlocked(record.id) then return false end
    local companion = record.companion or {}
    if not companion.recruited and not record.debugSpawnOnly then return false end

    local now = getGameTime() and getGameTime():getWorldAgeHours() or 0
    if record.embodiment.noAutoRearm == true then return false end
    if (record.embodiment.cooldownUntilHour or 0) > now then return false end

    local radius = Embody._activationRadiusFor(record)
    local originX, originY, originZ, originSource = activationOriginFor(record)
    local d2 = dist2(player:getX(), player:getY(), originX, originY)
    if d2 > radius * radius then return false end

    record.embodiment.state = "eligible"
    touchRecordStage(record, "eligible", "tryRearmHidden")
    traceStage("tryRearmHidden.eligible", record, nil, {
        source = "tryRearmHidden",
        detail = string.format("radius=%.2f distance=%.2f origin=%s originPos=%.0f,%.0f,%.0f", radius, math.sqrt(d2), tostring(originSource), originX, originY, originZ),
    })
    print(string.format("[LWN][Embodiment] rearmed hidden npc %s", tostring(record.id)))
    return true
end

function Embody.tryEmbody(record, player)
    record = ensureRecordShape(record)
    local lifecycleReason, lifecycleDetail = getLifecycleBlock(record, nil)
    if lifecycleReason then
        setLastFailure(record, lifecycleReason, lifecycleDetail)
        traceStage("tryEmbody.lifecycle_blocked", record, nil, {
            source = "tryEmbody",
            detail = string.format("reason=%s %s", tostring(lifecycleReason), tostring(lifecycleDetail)),
        })
        return nil
    end
    if record.embodiment.state ~= "eligible" then
        setLastFailure(record, "not_eligible", tostring(record.embodiment.state))
        traceStage("tryEmbody.not_eligible", record, nil, {
            source = "tryEmbody",
            detail = tostring(record.embodiment.state),
        })
        return nil
    end
    if Store.countEmbodied() >= LWN.Config.Population.MaxEmbodied then
        setLastFailure(record, "max_embodied", tostring(Store.countEmbodied()))
        traceStage("tryEmbody.max_embodied", record, nil, {
            source = "tryEmbody",
            detail = tostring(Store.countEmbodied()),
        })
        return nil
    end

    local radius = Embody._activationRadiusFor(record)
    local originX, originY, originZ, originSource = activationOriginFor(record)
    local d2 = dist2(player:getX(), player:getY(), originX, originY)
    if d2 > radius * radius then
        setLastFailure(record, "out_of_range", string.format("%.2f", math.sqrt(d2)))
        traceStage("tryEmbody.out_of_range", record, nil, {
            source = "tryEmbody",
            detail = string.format("radius=%.2f distance=%.2f origin=%s originPos=%.0f,%.0f,%.0f", radius, math.sqrt(d2), tostring(originSource), originX, originY, originZ),
        })
        return nil
    end

    local handle = Embody.getCarrierHandle and Embody.getCarrierHandle(record) or nil
    local cachedManagedShell = LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.getKnownShellByNpcId and LWN.Carriers.isozombie.getKnownShellByNpcId(record.id) or nil
    traceStage("tryEmbody.start", record, nil, {
        source = "tryEmbody",
        detail = string.format("radius=%.2f distance=%.2f origin=%s originPos=%.0f,%.0f,%.0f handleActor=%s cachedShell=%s", radius, math.sqrt(d2), tostring(originSource), originX, originY, originZ, tostring(handle and handle.actor or nil), tostring(cachedManagedShell)),
    })
    traceStage("tryEmbody.replacement_precheck", record, nil, {
        source = "tryEmbody",
        detail = string.format("spawning_new_shell because existing handle=%s cachedManaged=%s", tostring(handle and handle.actor or nil), tostring(cachedManagedShell)),
    })
    record.embodiment.recoveryDebug = record.embodiment.recoveryDebug or {}
    record.embodiment.recoveryDebug.stage = "tryEmbody.replacement_precheck"
    record.embodiment.recoveryDebug.detail = string.format(
        "handleActor=%s cachedManaged=%s origin=%s originPos=%.0f,%.0f,%.0f",
        tostring(handle and handle.actor or nil),
        tostring(cachedManagedShell),
        tostring(originSource),
        originX,
        originY,
        originZ
    )
    record.embodiment.recoveryDebug.at = worldAgeHours()
    touchRecordStage(record, "spawning", "tryEmbody.start")

    local spawnResult = nil
    if LWN.CarrierAdapter and LWN.CarrierAdapter.spawn then
        spawnResult = LWN.CarrierAdapter.spawn(record, {
            player = player,
        })
    else
        local legacyActor = LWN.ActorFactory and LWN.ActorFactory.createActor and LWN.ActorFactory.createActor(record, player) or nil
        spawnResult = {
            ok = legacyActor ~= nil,
            actor = legacyActor,
            detail = legacyActor and "legacy_spawn_without_adapter" or "legacy_spawn_failed_without_adapter",
            handle = legacyActor and {
                kind = record.embodiment and record.embodiment.carrierKind or "isozombie",
                actor = legacyActor,
                status = "active",
            } or nil,
        }
    end

    local actor = spawnResult and spawnResult.actor or nil
    local handle = spawnResult and spawnResult.handle or nil
    if spawnResult and spawnResult.ok ~= false and spawnResult.pending == true and handle then
        record.embodiment.state = "spawning"
        record.embodiment.actorId = nil
        record.embodiment.missingTicks = 0
        record.embodiment.lastFailureReason = nil
        record.embodiment.lastFailureDetail = nil
        touchRecordStage(record, "spawning", "tryEmbody.pending")
        traceStage("tryEmbody.pending", record, nil, {
            source = "tryEmbody",
            detail = string.format("carrierKind=%s handleStatus=%s", tostring(handle.kind), tostring(handle.status)),
        })
        return nil
    end
    if actor then
        traceStage("tryEmbody.actor_created", record, actor, {
            source = "tryEmbody",
            detail = string.format("carrierKind=%s spawnDetail=%s", tostring(handle and handle.kind or nil), tostring(spawnResult and spawnResult.detail or nil)),
        })
        local ok, syncResult = pcall(function()
            if LWN.CarrierAdapter and LWN.CarrierAdapter.sync then
                return LWN.CarrierAdapter.sync(record, handle, {
                    mode = "full",
                    snapToAnchor = true,
                    source = "tryEmbody.initial_sync",
                })
            end
            return LWN.ActorSync.pushRecordToActor(record, actor)
        end)
        local syncFailed = not ok or (type(syncResult) == "table" and syncResult.ok == false)
        local syncErr = not ok and syncResult or (type(syncResult) == "table" and syncResult.detail or nil)
        if syncFailed then
            print(string.format("[LWN][Embodiment] initial sync failed for %s :: %s", tostring(record.id), tostring(syncErr)))
            if LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
                LWN.CarrierAdapter.retire(record, handle, {
                    reason = "tryEmbody.initial_sync_failed",
                })
            elseif LWN.ActorFactory and LWN.ActorFactory.rejectActor then
                LWN.ActorFactory.rejectActor(actor, "tryEmbody failed during initial sync", record.id, record, nil, nil, {
                    source = "tryEmbody",
                    stage = "tryEmbody.initial_sync_failed",
                    thrown = syncErr,
                })
            elseif LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
                LWN.ActorFactory.cleanupActor(actor)
            end

            record.embodiment.state = "hidden"
            record.embodiment.actorId = nil
            record.embodiment.missingTicks = 0
            record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + autoRearmCooldownHours(record)
            touchRecordStage(record, "inactive", "tryEmbody.initial_sync_failed")
            setLastFailure(record, "initial_sync_failed", syncErr)
            traceStage("tryEmbody.initial_sync_failed", record, actor, {
                source = "tryEmbody",
                detail = syncErr,
            })
            return nil
        end

        traceStage("tryEmbody.initial_sync_ok", record, actor, {
            source = "tryEmbody",
            detail = string.format("carrierKind=%s", tostring(handle and handle.kind or nil)),
        })

        record.embodiment.state = "embodied"
        record.embodiment.actorId = record.id
        record.embodiment.lastSeenHour = getGameTime():getWorldAgeHours()
        record.embodiment.missingTicks = 0
        record.embodiment.lastFailureReason = nil
        record.embodiment.lastFailureDetail = nil
        record.embodiment.noAutoRearm = false
        touchRecordStage(record, "active", "tryEmbody.initial_sync_ok")
        Embody.touchGrace(record)
        if Embody.registerActor(record, actor) == false then
            if LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
                LWN.CarrierAdapter.retire(record, handle, {
                    reason = "tryEmbody.register_rejected",
                })
            elseif LWN.ActorFactory and LWN.ActorFactory.rejectActor then
                LWN.ActorFactory.rejectActor(actor, "tryEmbody rejected lifecycle-blocked actor after create", record.id, record, nil, nil, {
                    source = "tryEmbody",
                    stage = "tryEmbody.register_rejected",
                })
            elseif LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
                LWN.ActorFactory.cleanupActor(actor, "tryEmbody.register_rejected")
            end
            record.embodiment.state = "hidden"
            record.embodiment.actorId = nil
            record.embodiment.missingTicks = 0
            record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + autoRearmCooldownHours(record)
            touchRecordStage(record, "inactive", "tryEmbody.register_rejected")
            setLastFailure(record, "register_rejected", "registerActor returned false")
            traceStage("tryEmbody.register_rejected", record, actor, {
                source = "tryEmbody",
                detail = "registerActor returned false",
            })
            return nil
        end
        traceStage("tryEmbody.embodied", record, actor, {
            source = "tryEmbody",
            detail = string.format("graceUntil=%.2f", tonumber(record.embodiment.graceUntilHour or 0) or 0),
        })
        if LWN.EncounterDirector and LWN.EncounterDirector.notifyEmbodied then
            LWN.EncounterDirector.notifyEmbodied(record)
        end
        print(string.format(
            "[LWN][Embodiment] embodied %s at %.0f,%.0f,%.0f",
            tostring(record.id),
            tonumber(protectedCall(actor, "getX") or record.anchor.x or 0) or 0,
            tonumber(protectedCall(actor, "getY") or record.anchor.y or 0) or 0,
            tonumber(protectedCall(actor, "getZ") or record.anchor.z or 0) or 0
        ))
        return actor
    end

    -- Avoid spamming failed instantiation every tick.
    record.embodiment.state = "hidden"
    record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + autoRearmCooldownHours(record)
    touchRecordStage(record, "inactive", "tryEmbody.create_actor_failed")
    setLastFailure(record, "create_actor_failed", "ActorFactory returned nil")
    traceStage("tryEmbody.create_actor_failed", record, nil, {
        source = "tryEmbody",
        detail = "ActorFactory returned nil",
    })
    return nil
end

function Embody.pollPending(record, player)
    record = ensureRecordShape(record)
    if not record or record.embodiment.state ~= "spawning" then return nil end
    local handle = Embody.getCarrierHandle(record)
    if not handle or not (LWN.CarrierAdapter and LWN.CarrierAdapter.poll) then
        record.embodiment.state = "hidden"
        record.embodiment.cooldownUntilHour = worldAgeHours() + autoRearmCooldownHours(record)
        touchRecordStage(record, "inactive", "pollPending.handle_missing")
        setLastFailure(record, "pending_handle_missing", "carrier handle unavailable")
        if LWN.DebugTools and LWN.DebugTools.onCarrierEmbodimentFailed then
            LWN.DebugTools.onCarrierEmbodimentFailed(record, "pending_handle_missing", "carrier handle unavailable")
        end
        return nil
    end

    local ok, result = pcall(LWN.CarrierAdapter.poll, record, handle, { player = player })
    if not ok then
        result = { ok = false, pending = false, detail = result }
    end
    if result and result.pending == true then return nil end
    if not result or result.ok == false or not result.actor then
        if LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
            LWN.CarrierAdapter.retire(record, handle, { reason = result and result.detail or "pending_spawn_failed" })
        end
        record.embodiment.state = "hidden"
        record.embodiment.actorId = nil
        record.embodiment.cooldownUntilHour = worldAgeHours() + autoRearmCooldownHours(record)
        touchRecordStage(record, "inactive", "pollPending.failed")
        setLastFailure(record, "pending_spawn_failed", result and result.detail or "unknown")
        traceStage("pollPending.failed", record, nil, {
            source = "pollPending",
            detail = result and result.detail or "unknown",
        })
        if LWN.DebugTools and LWN.DebugTools.onCarrierEmbodimentFailed then
            LWN.DebugTools.onCarrierEmbodimentFailed(
                record,
                "pending_spawn_failed",
                result and result.detail or "unknown"
            )
        end
        return nil
    end

    local actor = result.actor
    handle = result.handle or handle
    local syncOk, syncResult = pcall(LWN.CarrierAdapter.sync, record, handle, {
        mode = "full",
        source = "pollPending.initial_sync",
    })
    if not syncOk or (type(syncResult) == "table" and syncResult.ok == false) then
        LWN.CarrierAdapter.retire(record, handle, { reason = "pollPending.initial_sync_failed" })
        record.embodiment.state = "hidden"
        record.embodiment.actorId = nil
        record.embodiment.cooldownUntilHour = worldAgeHours() + autoRearmCooldownHours(record)
        touchRecordStage(record, "inactive", "pollPending.initial_sync_failed")
        local syncDetail = syncResult
        if syncOk and type(syncResult) == "table" then
            syncDetail = syncResult.detail
        end
        setLastFailure(record, "initial_sync_failed", syncDetail)
        if LWN.DebugTools and LWN.DebugTools.onCarrierEmbodimentFailed then
            LWN.DebugTools.onCarrierEmbodimentFailed(record, "initial_sync_failed", syncDetail)
        end
        return nil
    end

    record.embodiment.state = "embodied"
    record.embodiment.actorId = record.id
    record.embodiment.lastSeenHour = worldAgeHours()
    record.embodiment.missingTicks = 0
    record.embodiment.lastFailureReason = nil
    record.embodiment.lastFailureDetail = nil
    record.embodiment.noAutoRearm = false
    touchRecordStage(record, "active", "pollPending.bound")
    Embody.touchGrace(record)
    if Embody.registerActor(record, actor) == false then
        LWN.CarrierAdapter.retire(record, handle, { reason = "pollPending.register_rejected" })
        record.embodiment.state = "hidden"
        record.embodiment.actorId = nil
        setLastFailure(record, "register_rejected", "pending actor registration rejected")
        if LWN.DebugTools and LWN.DebugTools.onCarrierEmbodimentFailed then
            LWN.DebugTools.onCarrierEmbodimentFailed(
                record,
                "register_rejected",
                "pending actor registration rejected"
            )
        end
        return nil
    end
    if LWN.EncounterDirector and LWN.EncounterDirector.notifyEmbodied then
        LWN.EncounterDirector.notifyEmbodied(record)
    end
    if LWN.DebugTools and LWN.DebugTools.onCarrierEmbodied then
        LWN.DebugTools.onCarrierEmbodied(record, actor)
    end
    print(string.format(
        "[LWN][Embodiment] pending actor bound npcId=%s carrier=%s",
        tostring(record.id), tostring(handle.kind)
    ))
    return actor
end

function Embody.tryDespawn(record, actor, player)
    record = ensureRecordShape(record)
    if record.embodiment.state ~= "embodied" or not actor then return false end
    if not isAlive(record) then return false end
    if debugNpcShouldStayEmbodied(record) then
        traceStage("tryDespawn.skipped_debug_pinned", record, actor, {
            source = "tryDespawn",
            detail = "debugSpawnOnly=true keepEmbodied=true",
        })
        return false
    end

    local radius = LWN.Config.Embodiment.DespawnRadiusTiles
    local companion = record.companion or {}
    if companion.recruited then
        radius = LWN.Config.Embodiment.CompanionDespawnRadiusTiles
    end
    if record.debugSpawnOnly == true and LWN.Config and LWN.Config.Debug and tonumber(LWN.Config.Debug.DebugSpawnDespawnRadiusTiles) then
        radius = tonumber(LWN.Config.Debug.DebugSpawnDespawnRadiusTiles) or radius
    end

    local grace = record.embodiment.graceUntilHour or 0
    if getGameTime():getWorldAgeHours() < grace then return false end

    local d2 = dist2(player:getX(), player:getY(), actor:getX(), actor:getY())
    if d2 < radius * radius then return false end

    traceStage("tryDespawn.start", record, actor, {
        source = "tryDespawn",
        detail = string.format("radius=%.2f distance=%.2f debugSpawn=%s", radius, math.sqrt(d2), tostring(record.debugSpawnOnly == true)),
    })
    LWN.ActorSync.pullActorToRecord(record, actor)
    local lastKnown = updateLastKnownPosition(record, actor)
    Store.setEmbodiedMeta(record.id, {
        state = "embodied",
        x = math.floor((lastKnown and lastKnown.x) or protectedCall(actor, "getX") or record.anchor.x or 0),
        y = math.floor((lastKnown and lastKnown.y) or protectedCall(actor, "getY") or record.anchor.y or 0),
        z = math.floor((lastKnown and lastKnown.z) or protectedCall(actor, "getZ") or record.anchor.z or 0),
        lastSeenHour = getGameTime() and getGameTime():getWorldAgeHours() or 0,
    })
    releaseActor(
        record,
        actor,
        "hidden",
        getGameTime():getWorldAgeHours() + autoRearmCooldownHours(record),
        "despawn_radius"
    )
    traceStage("tryDespawn.hidden", record, actor, {
        source = "tryDespawn",
        detail = string.format("cooldownUntil=%.2f", tonumber(record.embodiment.cooldownUntilHour or 0) or 0),
    })
    print(string.format("[LWN][Embodiment] despawned %s", tostring(record.id)))
    return true
end

function Embody.touchGrace(record)
    record = ensureRecordShape(record)
    record.embodiment.graceUntilHour = getGameTime():getWorldAgeHours() + LWN.Config.Embodiment.GraceHours
end

function Embody.registerCarrierHandle(record, handle)
    record = ensureRecordShape(record)
    if not record or not handle then return false end

    handle.npcId = record.id
    Embody._carrierHandles[record.id] = handle
    record.embodiment.carrierKind = handle.kind or record.embodiment.carrierKind or "none"
    record.embodiment.carrierState = record.embodiment.carrierState or {}
    record.embodiment.carrierState.status = handle.status
    record.embodiment.carrierState.detail = handle.detail
    record.embodiment.carrierState.spawnedAt = handle.spawnedAt
    record.embodiment.carrierState.lastSyncAt = handle.lastSyncAt
    record.embodiment.carrierState.lastRetireAt = handle.lastRetireAt
    return true
end

function Embody.getCarrierHandle(record)
    if not record then return nil end
    return Embody._carrierHandles[record.id]
end

function Embody.unregisterCarrierHandle(record, reason)
    if not record then return end
    record = ensureRecordShape(record)
    Embody._carrierHandles[record.id] = nil
    record.embodiment.carrierState = record.embodiment.carrierState or {}
    record.embodiment.carrierState.status = "retired"
    record.embodiment.carrierState.detail = reason or "unregisterCarrierHandle"
    record.embodiment.carrierState.lastRetireAt = worldAgeHours()
end

function Embody.registerActor(record, actor)
    record = ensureRecordShape(record)
    if not record or not actor then return false end
    local lifecycleReason, lifecycleDetail = getLifecycleBlock(record, actor)
    if lifecycleReason then
        traceStage("registerActor.rejected_lifecycle", record, actor, {
            source = "registerActor",
            detail = string.format("reason=%s %s", tostring(lifecycleReason), tostring(lifecycleDetail)),
        })
        return false
    end
    if record.embodiment.state ~= "embodied" then
        traceStage("registerActor.rejected_state", record, actor, {
            source = "registerActor",
            detail = string.format("recordState=%s", tostring(record.embodiment.state)),
        })
        return false
    end
    Embody._actors[record.id] = actor
    local handle = Embody.getCarrierHandle(record) or {
        kind = record.embodiment and record.embodiment.carrierKind or "isozombie",
        spawnedAt = worldAgeHours(),
        detail = "legacy_registerActor_bridge",
        runtime = {},
    }
    handle.actor = actor
    handle.status = "active"
    handle.pending = false
    handle.runtime = handle.runtime or {}
    handle.runtime.source = handle.runtime.source or "Embody.registerActor"
    Embody.registerCarrierHandle(record, handle)
    local lastKnown = updateLastKnownPosition(record, actor)
    Store.setEmbodiedMeta(record.id, {
        state = record.embodiment.state,
        x = math.floor((lastKnown and lastKnown.x) or protectedCall(actor, "getX") or record.anchor.x or 0),
        y = math.floor((lastKnown and lastKnown.y) or protectedCall(actor, "getY") or record.anchor.y or 0),
        z = math.floor((lastKnown and lastKnown.z) or protectedCall(actor, "getZ") or record.anchor.z or 0),
        lastSeenHour = getGameTime() and getGameTime():getWorldAgeHours() or 0,
    })
    touchRecordStage(record, record.embodiment.death and record.embodiment.death.latched and "death_latched" or "active", "registerActor")
    traceRegistryState("registerActor.bound", record, actor, {
        source = "registerActor",
    }, false)
    return true
end

function Embody.getActor(record)
    if not record then return nil end
    local handle = Embody.getCarrierHandle(record)
    if handle and LWN.CarrierAdapter and LWN.CarrierAdapter.getActor then
        return LWN.CarrierAdapter.getActor(handle)
    end
    return Embody._actors[record.id]
end

function Embody.commitActorPosition(record, actor, overrides)
    record = ensureRecordShape(record)
    if not record or not actor then return nil end

    local lastKnown = updateLastKnownPosition(record, actor, overrides)
    if not lastKnown then return nil end

    record.anchor = record.anchor or {}
    record.anchor.x = lastKnown.x
    record.anchor.y = lastKnown.y
    record.anchor.z = lastKnown.z
    record.anchor.lastCommittedAt = worldAgeHours()
    record.anchor.lastCommittedSource = overrides and overrides.source or "Embody.commitActorPosition"

    if Store and Store.setEmbodiedMeta then
        Store.setEmbodiedMeta(record.id, {
            state = record.embodiment and record.embodiment.state or "embodied",
            x = math.floor(lastKnown.x),
            y = math.floor(lastKnown.y),
            z = math.floor(lastKnown.z),
            lastSeenHour = worldAgeHours() or 0,
        })
    end

    record.embodiment = record.embodiment or {}
    record.embodiment.lastKnownSquare = string.format("%d,%d,%d", math.floor(lastKnown.x), math.floor(lastKnown.y), math.floor(lastKnown.z))
    record.embodiment.lastCommittedAt = worldAgeHours()
    record.embodiment.lastCommittedSource = overrides and overrides.source or "Embody.commitActorPosition"

    local handle = Embody.getCarrierHandle(record)
    if handle then
        handle.runtime = handle.runtime or {}
        handle.runtime.lastCommittedX = lastKnown.x
        handle.runtime.lastCommittedY = lastKnown.y
        handle.runtime.lastCommittedZ = lastKnown.z
        handle.runtime.lastCommittedSquare = record.embodiment.lastKnownSquare
        handle.runtime.lastCommittedAt = worldAgeHours()
        handle.runtime.lastCommittedSource = overrides and overrides.source or "Embody.commitActorPosition"
    end

    if record.dummy and record.dummy.enabled == true then
        record.dummy.lastCommittedSquare = record.embodiment.lastKnownSquare
        record.dummy.lastCommittedAt = worldAgeHours()
        record.dummy.lastCommittedSource = overrides and overrides.source or "Embody.commitActorPosition"
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyCommittedSquare = record.embodiment.lastKnownSquare
        modData.LWN_DummyCommittedAt = worldAgeHours()
        modData.LWN_DummyCommittedSource = overrides and overrides.source or "Embody.commitActorPosition"
    end

    return lastKnown
end

function Embody.getUsableActorByNpcId(npcId)
    if not npcId or not Store or not Store.getNPC then return nil, nil end

    local record = Store.getNPC(npcId)
    if not record or not isAlive(record) or record.embodiment.state ~= "embodied" or getCleanupState(npcId) then
        return nil, record
    end

    local actor = Embody.getActor(record)
    if not actor then
        return nil, record
    end
    if getActorCleanupState(actor) then
        return nil, record
    end
    local handle = Embody.getCarrierHandle(record)
    if handle and LWN.CarrierAdapter and LWN.CarrierAdapter.isUsable then
        handle.actor = handle.actor or actor
        if LWN.CarrierAdapter.isUsable(handle) then
            return actor, record
        end
    end
    if LWN.ActorFactory and LWN.ActorFactory.isManagedActor and not LWN.ActorFactory.isManagedActor(actor) then
        return nil, record
    end

    return actor, record
end

function Embody.getCleanupState(npcId)
    return getCleanupState(npcId)
end

function Embody.getActorCleanupState(actor)
    return getActorCleanupState(actor)
end

function Embody.unregisterActor(record, reason)
    if not record then return end
    record = ensureRecordShape(record)
    local actor = Embody._actors[record.id]
    local preserveCarrierHandle = shouldPreserveCarrierHandleOnHidden(record)
    local previousHandle = Embody.getCarrierHandle(record)
    traceRegistryState("unregisterActor.start", record, actor, {
        source = "unregisterActor",
        reason = reason,
    }, true)
    Embody._actors[record.id] = nil
    if preserveCarrierHandle then
        local handle = previousHandle or {
            kind = record.embodiment and record.embodiment.carrierKind or "isozombie",
            actor = actor,
            status = "hidden_recoverable",
            spawnedAt = worldAgeHours(),
        }
        handle.actor = handle.actor or actor
        handle.status = "hidden_recoverable"
        handle.detail = reason or "unregisterActor.hidden_recoverable"
        handle.lastRetireAt = worldAgeHours()
        Embody.registerCarrierHandle(record, handle)
    else
        Embody.unregisterCarrierHandle(record, reason or "unregisterActor")
    end
    local preservedPos = updateLastKnownPosition(record, actor)
    if record.embodiment and record.embodiment.state == "hidden" and isAlive(record) == true then
        Store.setEmbodiedMeta(record.id, {
            state = "hidden",
            x = math.floor((preservedPos and preservedPos.x) or record.embodiment.lastKnownX or record.anchor.x or 0),
            y = math.floor((preservedPos and preservedPos.y) or record.embodiment.lastKnownY or record.anchor.y or 0),
            z = math.floor((preservedPos and preservedPos.z) or record.embodiment.lastKnownZ or record.anchor.z or 0),
            lastSeenHour = worldAgeHours() or 0,
        })
    else
        Store.setEmbodiedMeta(record.id, nil)
    end
    Embody._registryTraceCache = Embody._registryTraceCache or {}
    Embody._registryTraceCache[record.id] = nil
    Embody._deathLikeTraceCache = Embody._deathLikeTraceCache or {}
    Embody._deathLikeTraceCache[record.id] = nil
    clearRecordTarget(record, reason or "unregisterActor")
    traceStage("unregisterActor.complete", record, actor, {
        source = "unregisterActor",
        detail = string.format(
            "recordState=%s actorRef=%s actorWorld=%s reason=%s metaCleared=true handlePreserved=%s handleActor=%s",
            tostring(record.embodiment and record.embodiment.state or nil),
            tostring(actor),
            tostring(actor and protectedCall(actor, "isExistInTheWorld") or nil),
            tostring(reason),
            tostring(preserveCarrierHandle),
            tostring(previousHandle and previousHandle.actor or actor)
        ),
    })
end

function Embody.isCleanupBlocked(npcId)
    if not npcId then return false end
    return Embody._cleanupBlocklist and Embody._cleanupBlocklist[npcId] ~= nil or false
end

function Embody.noteDeathLikeActor(record, actor, source)
    if not record or not actor then return end

    local deathLike = LWN.ActorFactory and LWN.ActorFactory.isDeathLikeActor and LWN.ActorFactory.isDeathLikeActor(actor) or false
    if deathLike ~= true then
        Embody._deathLikeTraceCache = Embody._deathLikeTraceCache or {}
        Embody._deathLikeTraceCache[record.id] = nil
        return
    end

    Embody._deathLikeTraceCache = Embody._deathLikeTraceCache or {}
    local signature = table.concat({
        tostring(record.id),
        tostring(record.embodiment and record.embodiment.state or nil),
        tostring(actor),
        tostring(protectedCall(actor, "isExistInTheWorld")),
        tostring(Embody.isCleanupBlocked(record.id)),
    }, "|")
    if Embody._deathLikeTraceCache[record.id] == signature then
        return
    end
    Embody._deathLikeTraceCache[record.id] = signature

    traceCleanup("death_like.embodied_observed", record.id, record, actor, {
        reason = source or "unknown",
        detail = string.format(
            "cleanupContract=observe_only state=%s actorKind=%s actorWorld=%s blocked=%s",
            tostring(record.embodiment and record.embodiment.state or nil),
            tostring(worldObjectKind(actor)),
            tostring(protectedCall(actor, "isExistInTheWorld")),
            tostring(Embody.isCleanupBlocked(record.id))
        ),
    })
end

function Embody.noteDeath(record, actor, source, detail)
    record = ensureRecordShape(record)
    if not record or not actor then return false end
    if not isAlive(record) and record.embodiment.death and record.embodiment.death.latched then
        return false
    end

    record.status.life = "dead"
    record.status.removed = false
    record.status.lastChangedHour = worldAgeHours() or 0
    record.status.reason = detail or source or "death"
    record.embodiment.cooldownUntilHour = nil
    record.embodiment.missingTicks = 0
    touchDeathRecord(record, "death_latched", source or "death", detail)
    touchCleanupRecord(record, "idle", detail or source, false)
    touchRecordStage(record, "death_latched", detail or source or "death")
    clearRecordTarget(record, source or "death")

    local meta = Store and Store.setEmbodiedMeta and {
        state = "death_latched",
        x = math.floor(protectedCall(actor, "getX") or record.anchor.x or 0),
        y = math.floor(protectedCall(actor, "getY") or record.anchor.y or 0),
        z = math.floor(protectedCall(actor, "getZ") or record.anchor.z or 0),
        lastSeenHour = worldAgeHours() or 0,
    } or nil
    if meta then
        Store.setEmbodiedMeta(record.id, meta)
    end

    local modData = protectedCall(actor, "getModData")
    retireWorldObjectIdentity(modData, record.id)
    local handle = Embody.getCarrierHandle(record)
    if handle then
        handle.actor = nil
        handle.pending = false
        handle.status = "dead"
        handle.detail = detail or source or "death_latched"
        handle.lastRetireAt = worldAgeHours()
        Embody.registerCarrierHandle(record, handle)
    end

    traceCleanup("death.latched", record.id, record, actor, {
        reason = source,
        detail = detail,
    })
    return true
end

function Embody.noteCorpseObserved(npcId, corpse, source)
    if not npcId or not Store or not Store.getNPC then return false end

    local record = Store.getNPC(npcId)
    if not record or isAlive(record) ~= false then
        return false
    end

    local death = record.embodiment.death or {}
    if death.corpseSeen == true then
        return false
    end

    death.corpseSeen = true
    death.corpseSeenAt = worldAgeHours()
    death.corpseVisual = protectedCall(corpse, "getVisual") ~= nil
    death.state = "corpse_observed"
    death.source = source or death.source
    record.embodiment.death = death
    touchRecordStage(record, "corpse_observed", source or "corpse")

    traceCleanup("death.corpse_observed", npcId, record, corpse, {
        reason = source,
        detail = string.format("corpseVisual=%s", tostring(death.corpseVisual)),
    })
    return true
end

function Embody.tickDeathLifecycle(record, actor, source)
    record = ensureRecordShape(record)
    if not record or isAlive(record) then return false end
    if getCleanupState(record.id) or Embody.isCleanupBlocked(record.id) then return true end

    local death = record.embodiment.death or {}
    local latchedAt = tonumber(death.latchedAt or worldAgeHours() or 0) or 0
    local now = worldAgeHours() or latchedAt
    local timeout = (LWN.Config and LWN.Config.Embodiment and LWN.Config.Embodiment.DeathCleanupDelayHours) or 0.0025
    local actorWorld = actor and protectedCall(actor, "isExistInTheWorld") or nil
    local shouldCleanup = death.corpseSeen == true
        or actor == nil
        or actorWorld == false
        or (now - latchedAt) >= timeout

    if not shouldCleanup then
        local traceNow = now
        local lastTrace = tonumber(death.lastAwaitingCorpseTraceAt or 0) or 0
        if lastTrace <= 0 or (traceNow - lastTrace) >= 0.0005 then
            death.lastAwaitingCorpseTraceAt = traceNow
            record.embodiment.death = death
            traceCleanup("death.awaiting_corpse", record.id, record, actor, {
                reason = source,
                detail = string.format("latchedAt=%.4f corpseSeen=%s actorWorld=%s", latchedAt, tostring(death.corpseSeen), tostring(actorWorld)),
            })
        end
        return true
    end

    death.cleanupRequested = true
    record.embodiment.death = death
    return Embody.canonicalCleanup(record, {
        actor = actor,
        removeRecord = false,
        blockNpcId = true,
        reason = death.corpseSeen == true and "death_corpse_cleanup" or "death_timeout_cleanup",
        detail = source,
    })
end

function Embody.canonicalCleanup(recordOrNpcId, options)
    local record = type(recordOrNpcId) == "table" and recordOrNpcId or nil
    local npcId = record and record.id or recordOrNpcId
    if not npcId and options then
        npcId = options.npcId
    end
    if not npcId then return false end

    if not record and Store and Store.getNPC then
        record = Store.getNPC(npcId)
    end
    record = ensureRecordShape(record)

    local reason = options and options.reason or "canonical_cleanup"
    local detail = options and options.detail or nil
    local removeRecord = not (options and options.removeRecord == false)
    local blockNpcId = options and options.blockNpcId
    local cooldownUntilHour = options and options.cooldownUntilHour or nil
    if blockNpcId == nil then
        blockNpcId = removeRecord
    end
    local actor = options and options.actor or nil
    if not actor and record then
        actor = Embody.getActor(record)
    end
    local preserveActorWorldObject = actor
        and record
        and isAlive(record) == false
        and (worldObjectKind(actor) == "corpse" or worldObjectKind(actor) == "zombie")
    local registeredActor = record and Embody.getActor(record) or nil
    local actorSource = options and options.actor and "options.actor" or (actor and "registry" or "none")
    local actorCleanup = getActorCleanupState(actor)

    if Embody._cleanupInFlight[npcId] then
        traceCleanup("request.duplicate", npcId, record, actor, {
            reason = reason,
            detail = cleanupStateSummary(npcId),
        })
        return false
    end

    local cleanupState = {
        at = worldAgeHours(),
        stage = "request",
        reason = reason,
        removeRecord = removeRecord,
        actorRef = objectRef(actor),
        actorSource = actorSource,
        registeredMatch = registeredActor ~= nil and actor ~= nil and registeredActor == actor or false,
    }
    Embody._cleanupInFlight[npcId] = cleanupState

    if blockNpcId then
        Embody._cleanupBlocklist[npcId] = cleanupState
    end
    traceCleanup("request", npcId, record, actor, {
        reason = reason,
        detail = string.format(
            "removeRecord=%s blockNpcId=%s actorSource=%s registeredRef=%s registeredMatch=%s actorCleanupStage=%s %s",
            tostring(removeRecord),
            tostring(blockNpcId),
            tostring(actorSource),
            tostring(objectRef(registeredActor)),
            tostring(registeredActor ~= nil and actor ~= nil and registeredActor == actor or false),
            tostring(actorCleanup and actorCleanup.stage or nil),
            tostring(detail)
        ),
    })

    clearUiTargets(npcId)
    if record and LWN.ActionRuntime and LWN.ActionRuntime.clear then
        LWN.ActionRuntime.clear(record, actor)
    end
    clearRecordTarget(record, reason)
    updateCleanupState(npcId, "ui_targets.cleared", reason, record, actor, {
        removeRecord = removeRecord,
    })
    traceCleanup("ui_targets.cleared", npcId, record, actor, {
        reason = reason,
    })

    if record then
        touchCleanupRecord(record, "pending", reason, removeRecord)
        touchRecordStage(record, "cleanup", reason)
        record.embodiment = record.embodiment or {}
        record.embodiment.state = removeRecord and "removed" or "hidden"
        record.embodiment.actorId = nil
        record.embodiment.missingTicks = 0
        if removeRecord then
            record.embodiment.cooldownUntilHour = nil
            record.status.removed = true
            record.status.lastChangedHour = worldAgeHours() or 0
            record.status.reason = reason
        else
            if isAlive(record) then
                record.embodiment.cooldownUntilHour = cooldownUntilHour or (getGameTime():getWorldAgeHours() + autoRearmCooldownHours(record))
            else
                record.embodiment.cooldownUntilHour = nil
            end
        end
        updateCleanupState(npcId, "record.deactivated", reason, record, actor, {
            removeRecord = removeRecord,
            cooldownUntilHour = record.embodiment.cooldownUntilHour,
        })
        traceCleanup("record.deactivated", npcId, record, actor, {
            reason = reason,
            detail = string.format(
                "removeRecord=%s cooldownUntil=%.4f",
                tostring(removeRecord),
                tonumber(record.embodiment.cooldownUntilHour or 0) or 0
            ),
        })
    end

    local actorCleanupDeferred = false
    if actor then
        updateCleanupState(npcId, "actor.cleanup.start", reason, record, actor, {
            removeRecord = removeRecord,
            actor = actor,
        })
        traceCleanup("actor.cleanup.start", npcId, record, actor, {
            reason = reason,
            detail = string.format("preserveActorWorldObject=%s", tostring(preserveActorWorldObject)),
        })
        if preserveActorWorldObject then
            local modData = protectedCall(actor, "getModData")
            retireWorldObjectIdentity(modData, npcId)
        elseif LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
            local handle = Embody.getCarrierHandle(record) or {
                kind = record and record.embodiment and record.embodiment.carrierKind or "isozombie",
                actor = actor,
                status = "active",
            }
            local cleanupResult = LWN.CarrierAdapter.retire(record, handle, {
                reason = reason,
            })
            actorCleanupDeferred = cleanupResult and (cleanupResult.status == "retiring" or cleanupResult.status == "retire_blocked") or false
            if actorCleanupDeferred then
                blockNpcId = true
                Embody._cleanupBlocklist[npcId] = getCleanupState(npcId) or cleanupState
                cleanupState.handle = handle
                updateCleanupState(npcId, "actor.cleanup.deferred", reason, record, actor, {
                    removeRecord = removeRecord,
                    actor = actor,
                    deferred = true,
                    detail = cleanupResult and cleanupResult.detail or nil,
                })
                traceCleanup("actor.cleanup.deferred", npcId, record, actor, {
                    reason = reason,
                    detail = cleanupResult and cleanupResult.detail or "cleanupActor returned deferred",
                })
            end
        else
            protectedCall(actor, "StopAllActionQueue")
            protectedCall(actor, "removeFromSquare")
            protectedCall(actor, "removeFromWorld")
        end
        if actorCleanupDeferred ~= true then
            updateCleanupState(npcId, "actor.cleanup.complete", reason, record, actor, {
                removeRecord = removeRecord,
            })
            traceCleanup("actor.cleanup.complete", npcId, record, actor, {
                reason = reason,
            })
        end
    else
        local pendingHandle = record and Embody.getCarrierHandle(record) or nil
        if pendingHandle and LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
            LWN.CarrierAdapter.retire(record, pendingHandle, { reason = reason })
            updateCleanupState(npcId, "actor.cleanup.pending_handle", reason, record, actor, {
                removeRecord = removeRecord,
            })
            traceCleanup("actor.cleanup.pending_handle", npcId, record, actor, {
                reason = reason,
                detail = "actor=nil pending handle retired",
            })
        else
            updateCleanupState(npcId, "actor.cleanup.skipped", reason, record, actor, {
                removeRecord = removeRecord,
            })
            traceCleanup("actor.cleanup.skipped", npcId, record, actor, {
                reason = reason,
                detail = "actor=nil",
            })
        end
    end

    local leftovers = collectCleanupObjects(record, npcId, actor)
    if #leftovers == 0 then
        traceCleanup("leftover.none", npcId, record, actor, {
            reason = reason,
        })
    else
        if shouldTraceLeftoverSnapshot(leftovers, actor) then
            traceCleanup("leftover.snapshot", npcId, record, actor, {
                reason = reason,
                detail = summarizeCleanupObjects(leftovers, actor),
            })
        end
        for _, obj in ipairs(leftovers) do
            if obj ~= actor then
                local kind = worldObjectKind(obj)
                local preserveWorldObject = record
                    and isAlive(record) == false
                    and (kind == "corpse" or kind == "zombie")
                detachWorldObject(obj, npcId, reason, {
                    preserveWorldObject = preserveWorldObject,
                })
            end
        end
    end

    if record then
        updateCleanupState(npcId, "registry.clearing", reason, record, actor, {
            removeRecord = removeRecord,
        })
        Embody.unregisterActor(record, reason)
        if actorCleanupDeferred == true then
            touchRecordStage(record, "cleanup_deferred", reason)
            updateCleanupState(npcId, "registry.deferred", reason, record, actor, {
                removeRecord = removeRecord,
                actor = actor,
                deferred = true,
                detail = string.format("removeRecord=%s", tostring(removeRecord)),
            })
            traceCleanup("registry.deferred", npcId, record, actor, {
                reason = reason,
                detail = string.format("removeRecord=%s", tostring(removeRecord)),
            })
        else
            touchCleanupRecord(record, "complete", reason, removeRecord)
            touchRecordStage(record, removeRecord and "removed" or (isAlive(record) and "inactive" or "dead_cleaned"), reason)
            updateCleanupState(npcId, "registry.cleared", reason, record, actor, {
                removeRecord = removeRecord,
            })
            traceCleanup("registry.cleared", npcId, record, actor, {
                reason = reason,
            })
        end
    end

    if actorCleanupDeferred ~= true and removeRecord and Store and Store.removeNPC then
        Store.removeNPC(npcId)
        updateCleanupState(npcId, "record.removed", reason, nil, actor, {
            removeRecord = removeRecord,
        })
        traceCleanup("record.removed", npcId, nil, actor, {
            reason = reason,
        })
    end

    if actorCleanupDeferred ~= true then
        Embody._cleanupInFlight[npcId] = nil
        if removeRecord ~= true and (record == nil or isAlive(record) == true) then
            Embody._cleanupBlocklist[npcId] = nil
        end
    end

    return true
end

function Embody.tickDeferredCleanup()
    if not Embody._cleanupInFlight then return end

    local pendingIds = {}
    for npcId, cleanupState in pairs(Embody._cleanupInFlight) do
        if cleanupState and cleanupState.deferred == true then
            pendingIds[#pendingIds + 1] = npcId
        end
    end

    for _, npcId in ipairs(pendingIds) do
        local cleanupState = Embody._cleanupInFlight[npcId]
        if cleanupState and cleanupState.deferred == true then
            local record = Store and Store.getNPC and Store.getNPC(npcId) or nil
            local actor = cleanupState.actor
            local attempts = (tonumber(cleanupState.attempts) or 0) + 1
            local canFinalize = true
            local finalizeDetail = "actor=nil"

            if LWN.ActorFactory and LWN.ActorFactory.canFinalizeDeferredCleanup then
                canFinalize, finalizeDetail = LWN.ActorFactory.canFinalizeDeferredCleanup(actor)
            elseif actor and protectedCall(actor, "isExistInTheWorld") == true then
                canFinalize = false
                finalizeDetail = string.format(
                    "actorWorld=%s squarePresent=%s",
                    tostring(protectedCall(actor, "isExistInTheWorld")),
                    tostring((protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")) ~= nil)
                )
            end

            if canFinalize ~= true then
                updateCleanupState(npcId, "deferred.finalize.skipped", cleanupState.reason, record, actor, {
                    removeRecord = cleanupState.removeRecord,
                    actor = actor,
                    deferred = true,
                    attempts = attempts,
                    skipDetail = finalizeDetail,
                    detail = finalizeDetail,
                })
                if cleanupState.lastSkipDetail ~= finalizeDetail or attempts == 1 then
                    cleanupState.lastSkipDetail = finalizeDetail
                    traceCleanup("deferred.finalize.skipped", npcId, record, actor, {
                        reason = cleanupState.reason,
                        detail = finalizeDetail,
                    })
                end
            else
                traceCleanup("deferred.finalize.start", npcId, record, actor, {
                    reason = cleanupState.reason,
                    detail = string.format("attempts=%s", tostring(attempts)),
                })

                local cleanupResult = nil
                if LWN.ActorFactory and LWN.ActorFactory.finalizeDeferredCleanup then
                    cleanupResult = LWN.ActorFactory.finalizeDeferredCleanup(actor, cleanupState.reason)
                elseif LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
                    cleanupResult = LWN.CarrierAdapter.retire(record, cleanupState.handle or Embody.getCarrierHandle(record), {
                        reason = cleanupState.reason,
                    })
                    cleanupResult.completed = cleanupResult.ok ~= false and cleanupResult.status ~= "retiring" and cleanupResult.status ~= "retire_blocked"
                elseif LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
                    cleanupResult = LWN.ActorFactory.cleanupActor(actor, cleanupState.reason)
                else
                    cleanupResult = {
                        completed = true,
                        detail = "no_actor_factory_finalizer",
                    }
                end

                if cleanupResult and cleanupResult.completed ~= false then
                    if record then
                        touchCleanupRecord(record, "complete", cleanupState.reason, cleanupState.removeRecord)
                        touchRecordStage(
                            record,
                            cleanupState.removeRecord and "removed" or (isAlive(record) and "inactive" or "dead_cleaned"),
                            cleanupState.reason
                        )
                    end

                    updateCleanupState(npcId, "deferred.finalize.complete", cleanupState.reason, record, actor, {
                        removeRecord = cleanupState.removeRecord,
                        actor = actor,
                        deferred = false,
                        attempts = attempts,
                        detail = cleanupResult.detail,
                    })
                    traceCleanup("deferred.finalize.complete", npcId, record, actor, {
                        reason = cleanupState.reason,
                        detail = cleanupResult.detail,
                    })

                    if cleanupState.removeRecord and Store and Store.removeNPC then
                        Store.removeNPC(npcId)
                        updateCleanupState(npcId, "record.removed", cleanupState.reason, nil, actor, {
                            removeRecord = cleanupState.removeRecord,
                            detail = "deferred_cleanup_complete",
                        })
                        traceCleanup("record.removed", npcId, nil, actor, {
                            reason = cleanupState.reason,
                            detail = "deferred_cleanup_complete",
                        })
                    end

                    if cleanupState.removeRecord ~= true and (record == nil or isAlive(record) == true) then
                        Embody._cleanupBlocklist[npcId] = nil
                    end
                    Embody._cleanupInFlight[npcId] = nil
                else
                    updateCleanupState(npcId, "deferred.finalize.incomplete", cleanupState.reason, record, actor, {
                        removeRecord = cleanupState.removeRecord,
                        actor = actor,
                        deferred = true,
                        attempts = attempts,
                        detail = cleanupResult and cleanupResult.detail or "completed=false",
                    })
                    traceCleanup("deferred.finalize.incomplete", npcId, record, actor, {
                        reason = cleanupState.reason,
                        detail = cleanupResult and cleanupResult.detail or "completed=false",
                    })
                end
            end
        end
    end
end
