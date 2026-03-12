LWN = LWN or {}
LWN.EmbodimentManager = LWN.EmbodimentManager or {}

local Embody = LWN.EmbodimentManager
local Store = LWN.PopulationStore

Embody._actors = Embody._actors or {}
Embody._cleanupBlocklist = Embody._cleanupBlocklist or {}
Embody._cleanupInFlight = Embody._cleanupInFlight or {}

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
    end

    if Embody._cleanupInFlight[npcId] or not Embody._cleanupBlocklist[npcId] then
        Embody._cleanupInFlight[npcId] = state
    end
    if Embody._cleanupBlocklist[npcId] then
        Embody._cleanupBlocklist[npcId] = state
    end
    return state
end

local function getLifecycleBlock(record, actor)
    if not record then
        return "record_missing", "record=nil"
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
    print(string.format(
        "[LWN][CleanupTrace] stage=%s | npcId=%s | recordExists=%s | recordState=%s | actorRef=%s | actorKind=%s | actorWorld=%s | blocked=%s | cleanupStage=%s | cleanupReason=%s | reason=%s | detail=%s",
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
        safeText(extra and extra.detail or nil)
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

local function clearUiTargets(npcId)
    if not npcId then return end

    if LWN.UICommandPanel and LWN.UICommandPanel.target and getKnownNpcId(LWN.UICommandPanel.target) == npcId and LWN.UICommandPanel.hide then
        LWN.UICommandPanel.hide()
    end
    if LWN.UIDialogueWindow and LWN.UIDialogueWindow.target and getKnownNpcId(LWN.UIDialogueWindow.target) == npcId and LWN.UIDialogueWindow.hide then
        LWN.UIDialogueWindow.hide()
    end
    if LWN.UIRadialMenu and LWN.UIRadialMenu.target and getKnownNpcId(LWN.UIRadialMenu.target) == npcId and LWN.UIRadialMenu.hide then
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

local function detachWorldObject(obj, npcId, reason)
    if not obj then return end

    local modData = protectedCall(obj, "getModData")
    traceCleanup("leftover.cleanup.start", npcId, nil, obj, {
        reason = reason,
        detail = string.format("kind=%s", tostring(worldObjectKind(obj))),
    })

    if LWN.ActorFactory and LWN.ActorFactory.hasRuntimeCore and LWN.ActorFactory.hasRuntimeCore(obj) and LWN.ActorFactory.cleanupActor then
        LWN.ActorFactory.cleanupActor(obj, reason)
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

    clearUiTargets(record.id)

    if actor then
        if LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
            LWN.ActorFactory.cleanupActor(actor, reason)
        else
            protectedCall(actor, "StopAllActionQueue")
            protectedCall(actor, "removeFromSquare")
            protectedCall(actor, "removeFromWorld")
        end
    end

    record.embodiment.state = nextState
    record.embodiment.actorId = nil
    record.embodiment.missingTicks = 0
    record.embodiment.cooldownUntilHour = cooldownHours
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
    if record.embodiment.state ~= "hidden" then return false end
    local companion = record.companion or {}
    if not companion.recruited and not record.debugSpawnOnly then return false end

    local now = getGameTime() and getGameTime():getWorldAgeHours() or 0
    if (record.embodiment.cooldownUntilHour or 0) > now then return false end

    local radius = Embody._activationRadiusFor(record)
    local d2 = dist2(player:getX(), player:getY(), record.anchor.x, record.anchor.y)
    if d2 > radius * radius then return false end

    record.embodiment.state = "eligible"
    traceStage("tryRearmHidden.eligible", record, nil, {
        source = "tryRearmHidden",
        detail = string.format("radius=%.2f distance=%.2f", radius, math.sqrt(d2)),
    })
    print(string.format("[LWN][Embodiment] rearmed hidden npc %s", tostring(record.id)))
    return true
end

function Embody.tryEmbody(record, player)
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
    local d2 = dist2(player:getX(), player:getY(), record.anchor.x, record.anchor.y)
    if d2 > radius * radius then
        setLastFailure(record, "out_of_range", string.format("%.2f", math.sqrt(d2)))
        traceStage("tryEmbody.out_of_range", record, nil, {
            source = "tryEmbody",
            detail = string.format("radius=%.2f distance=%.2f", radius, math.sqrt(d2)),
        })
        return nil
    end

    traceStage("tryEmbody.start", record, nil, {
        source = "tryEmbody",
        detail = string.format("radius=%.2f distance=%.2f", radius, math.sqrt(d2)),
    })

    local actor = LWN.ActorFactory.createActor(record, player)
    if actor then
        traceStage("tryEmbody.actor_created", record, actor, {
            source = "tryEmbody",
        })
        local ok, syncErr = pcall(LWN.ActorSync.pushRecordToActor, record, actor)
        if not ok then
            print(string.format("[LWN][Embodiment] initial sync failed for %s :: %s", tostring(record.id), tostring(syncErr)))
            if LWN.ActorFactory and LWN.ActorFactory.rejectActor then
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
            setLastFailure(record, "initial_sync_failed", syncErr)
            traceStage("tryEmbody.initial_sync_failed", record, actor, {
                source = "tryEmbody",
                detail = syncErr,
            })
            return nil
        end

        traceStage("tryEmbody.initial_sync_ok", record, actor, {
            source = "tryEmbody",
        })

        record.embodiment.state = "embodied"
        record.embodiment.actorId = record.id
        record.embodiment.lastSeenHour = getGameTime():getWorldAgeHours()
        record.embodiment.missingTicks = 0
        record.embodiment.lastFailureReason = nil
        record.embodiment.lastFailureDetail = nil
        Embody.touchGrace(record)
        if Embody.registerActor(record, actor) == false then
            if LWN.ActorFactory and LWN.ActorFactory.rejectActor then
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
    setLastFailure(record, "create_actor_failed", "ActorFactory returned nil")
    traceStage("tryEmbody.create_actor_failed", record, nil, {
        source = "tryEmbody",
        detail = "ActorFactory returned nil",
    })
    return nil
end

function Embody.tryDespawn(record, actor, player)
    if record.embodiment.state ~= "embodied" or not actor then return false end

    local radius = LWN.Config.Embodiment.DespawnRadiusTiles
    local companion = record.companion or {}
    if companion.recruited then
        radius = LWN.Config.Embodiment.CompanionDespawnRadiusTiles
    end

    local grace = record.embodiment.graceUntilHour or 0
    if getGameTime():getWorldAgeHours() < grace then return false end

    local d2 = dist2(player:getX(), player:getY(), actor:getX(), actor:getY())
    if d2 < radius * radius then return false end

    traceStage("tryDespawn.start", record, actor, {
        source = "tryDespawn",
        detail = string.format("radius=%.2f distance=%.2f", radius, math.sqrt(d2)),
    })
    LWN.ActorSync.pullActorToRecord(record, actor)
    Store.setEmbodiedMeta(record.id, {
        state = "embodied",
        x = math.floor(protectedCall(actor, "getX") or record.anchor.x or 0),
        y = math.floor(protectedCall(actor, "getY") or record.anchor.y or 0),
        z = math.floor(protectedCall(actor, "getZ") or record.anchor.z or 0),
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
    record.embodiment.graceUntilHour = getGameTime():getWorldAgeHours() + LWN.Config.Embodiment.GraceHours
end

function Embody.registerActor(record, actor)
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
    Store.setEmbodiedMeta(record.id, {
        state = record.embodiment.state,
        x = math.floor(protectedCall(actor, "getX") or record.anchor.x or 0),
        y = math.floor(protectedCall(actor, "getY") or record.anchor.y or 0),
        z = math.floor(protectedCall(actor, "getZ") or record.anchor.z or 0),
        lastSeenHour = getGameTime() and getGameTime():getWorldAgeHours() or 0,
    })
    traceRegistryState("registerActor.bound", record, actor, {
        source = "registerActor",
    }, false)
    return true
end

function Embody.getActor(record)
    if not record then return nil end
    return Embody._actors[record.id]
end

function Embody.getCleanupState(npcId)
    return getCleanupState(npcId)
end

function Embody.getActorCleanupState(actor)
    return getActorCleanupState(actor)
end

function Embody.unregisterActor(record, reason)
    if not record then return end
    local actor = Embody._actors[record.id]
    traceRegistryState("unregisterActor.start", record, actor, {
        source = "unregisterActor",
        reason = reason,
    }, true)
    Embody._actors[record.id] = nil
    Store.setEmbodiedMeta(record.id, nil)
    Embody._registryTraceCache = Embody._registryTraceCache or {}
    Embody._registryTraceCache[record.id] = nil
    Embody._deathLikeTraceCache = Embody._deathLikeTraceCache or {}
    Embody._deathLikeTraceCache[record.id] = nil
    traceStage("unregisterActor.complete", record, actor, {
        source = "unregisterActor",
        detail = string.format(
            "recordState=%s actorRef=%s actorWorld=%s reason=%s metaCleared=true",
            tostring(record.embodiment and record.embodiment.state or nil),
            tostring(actor),
            tostring(actor and protectedCall(actor, "isExistInTheWorld") or nil),
            tostring(reason)
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

    local reason = options and options.reason or "canonical_cleanup"
    local detail = options and options.detail or nil
    local removeRecord = not (options and options.removeRecord == false)
    local blockNpcId = options and options.blockNpcId
    if blockNpcId == nil then
        blockNpcId = removeRecord
    end
    local actor = options and options.actor or nil
    if not actor and record then
        actor = Embody.getActor(record)
    end
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
    updateCleanupState(npcId, "ui_targets.cleared", reason, record, actor, {
        removeRecord = removeRecord,
    })
    traceCleanup("ui_targets.cleared", npcId, record, actor, {
        reason = reason,
    })

    if record then
        record.embodiment = record.embodiment or {}
        record.embodiment.state = removeRecord and "removed" or "hidden"
        record.embodiment.actorId = nil
        record.embodiment.missingTicks = 0
        if removeRecord then
            record.embodiment.cooldownUntilHour = nil
        else
            record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + autoRearmCooldownHours(record)
        end
        updateCleanupState(npcId, "record.deactivated", reason, record, actor, {
            removeRecord = removeRecord,
        })
        traceCleanup("record.deactivated", npcId, record, actor, {
            reason = reason,
            detail = string.format("removeRecord=%s", tostring(removeRecord)),
        })
    end

    if actor then
        updateCleanupState(npcId, "actor.cleanup.start", reason, record, actor, {
            removeRecord = removeRecord,
        })
        traceCleanup("actor.cleanup.start", npcId, record, actor, {
            reason = reason,
        })
        if LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
            LWN.ActorFactory.cleanupActor(actor, reason)
        else
            protectedCall(actor, "StopAllActionQueue")
            protectedCall(actor, "removeFromSquare")
            protectedCall(actor, "removeFromWorld")
        end
        updateCleanupState(npcId, "actor.cleanup.complete", reason, record, actor, {
            removeRecord = removeRecord,
        })
        traceCleanup("actor.cleanup.complete", npcId, record, actor, {
            reason = reason,
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

    local leftovers = collectCleanupObjects(record, npcId, actor)
    if #leftovers == 0 then
        traceCleanup("leftover.none", npcId, record, actor, {
            reason = reason,
        })
    else
        traceCleanup("leftover.snapshot", npcId, record, actor, {
            reason = reason,
            detail = summarizeCleanupObjects(leftovers, actor),
        })
        for _, obj in ipairs(leftovers) do
            if obj ~= actor then
                detachWorldObject(obj, npcId, reason)
            end
        end
    end

    if record then
        updateCleanupState(npcId, "registry.clearing", reason, record, actor, {
            removeRecord = removeRecord,
        })
        Embody.unregisterActor(record, reason)
        updateCleanupState(npcId, "registry.cleared", reason, record, actor, {
            removeRecord = removeRecord,
        })
        traceCleanup("registry.cleared", npcId, record, actor, {
            reason = reason,
        })
    end

    if removeRecord and Store and Store.removeNPC then
        Store.removeNPC(npcId)
        updateCleanupState(npcId, "record.removed", reason, nil, actor, {
            removeRecord = removeRecord,
        })
        traceCleanup("record.removed", npcId, nil, actor, {
            reason = reason,
        })
    end

    Embody._cleanupInFlight[npcId] = nil

    return true
end
