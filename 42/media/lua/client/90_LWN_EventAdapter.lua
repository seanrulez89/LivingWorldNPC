LWN = LWN or {}
LWN.EventAdapter = LWN.EventAdapter or {}

-- Central event bridge. It owns world tick orchestration but delegates actual
-- state changes to specialized modules so hook wiring stays isolated here.
local Adapter = LWN.EventAdapter

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

local function safeText(value)
    if value == nil then return "nil" end
    local text = tostring(value)
    text = text:gsub("[\r\n|]", " ")
    return text
end

local function safeNumber(value)
    if type(value) ~= "number" then
        return safeText(value)
    end
    return string.format("%.2f", value)
end

local function objectRef(value)
    if value == nil then return "nil" end
    return safeText(tostring(value))
end

local function coordSummary(x, y, z)
    return safeNumber(x) .. "," .. safeNumber(y) .. "," .. safeNumber(z)
end

local getAnchorSquare

local function traceStage(stage, record, actor, extra)
    if LWN.ActorFactory and LWN.ActorFactory.debugStage then
        LWN.ActorFactory.debugStage("EventAdapter", stage, record, actor, protectedCall(actor, "getDescriptor"), extra)
    end
end

local function getPlayerSafe()
    return getPlayer and getPlayer() or nil
end

local function hookStageName(hookName, suffix)
    local stage = tostring(hookName or "onCreateHook")
    if string.sub(stage, 1, 2) == "On" then
        stage = "on" .. string.sub(stage, 3)
    end
    if suffix and suffix ~= "" then
        stage = stage .. "." .. tostring(suffix)
    end
    return stage
end

local function isPlayerAsleep(player)
    if not player then return false end
    if player.isAsleep then
        return player:isAsleep() == true
    end
    return false
end

local function isManagedActor(obj)
    if not obj then return false end
    if LWN.ActorFactory and LWN.ActorFactory.isManagedActor then
        return LWN.ActorFactory.isManagedActor(obj)
    end
    return false
end

local function getKnownNpcId(actor)
    if not actor then return nil end
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        local npcId = LWN.ActorFactory.getNpcIdFromActor(actor)
        if npcId then
            return npcId
        end
    end
    local modData = actor.getModData and actor:getModData() or nil
    return modData and (modData.LWN_NpcId or modData.LWN_LastNpcId) or nil
end

local function getActiveNpcId(actor)
    if not actor then return nil end
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        local npcId = LWN.ActorFactory.getNpcIdFromActor(actor)
        if npcId then
            return npcId
        end
    end
    local modData = actor.getModData and actor:getModData() or nil
    return modData and modData.LWN_NpcId or nil
end

local function getNpcId(actor)
    return getKnownNpcId(actor)
end

local function isCleanupBlocked(npcId)
    if not npcId then return false end
    if LWN.EmbodimentManager and LWN.EmbodimentManager.isCleanupBlocked then
        return LWN.EmbodimentManager.isCleanupBlocked(npcId)
    end
    return false
end

local function getCleanupState(npcId)
    if not npcId then return nil end
    if LWN.EmbodimentManager and LWN.EmbodimentManager.getCleanupState then
        return LWN.EmbodimentManager.getCleanupState(npcId)
    end
    return nil
end

local function getActorCleanupState(actor)
    if not actor then return nil end
    if LWN.EmbodimentManager and LWN.EmbodimentManager.getActorCleanupState then
        return LWN.EmbodimentManager.getActorCleanupState(actor)
    end
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

local function cleanupStateDetail(npcId)
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

local function actorCleanupDetail(actor)
    local state = getActorCleanupState(actor)
    if not state then return "actorCleanup=nil" end
    return string.format(
        "actorCleanupStage=%s actorCleanupReason=%s actorCleanupNpcId=%s pending=%s",
        tostring(state.stage),
        tostring(state.reason),
        tostring(state.npcId),
        tostring(state.pending)
    )
end

local function copyTable(source)
    if not source then return nil end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function getPresentationState(actor)
    if not actor then return nil end
    if LWN.ActorFactory and LWN.ActorFactory.getPresentationState then
        return LWN.ActorFactory.getPresentationState(actor)
    end
    local health = protectedCall(actor, "getHealth")
    local dead = protectedCall(actor, "isDead")
    local reanimated = protectedCall(actor, "isReanimatedPlayer")
    local zombie = protectedCall(actor, "isZombie")
    local downed = protectedCall(actor, "isOnFloor") == true
        or protectedCall(actor, "isFallOnFront") == true
        or protectedCall(actor, "isKnockedDown") == true
    return {
        objectRef = objectRef(actor),
        object = protectedCall(actor, "getObjectName"),
        health = health,
        dead = dead,
        downed = downed,
        deathLike = dead == true or reanimated == true or (type(health) == "number" and health <= 0),
        zombie = zombie,
        reanimated = reanimated,
        world = protectedCall(actor, "isExistInTheWorld"),
    }
end

local function noteCreateHookSequence(modData, hookName)
    if not modData or not hookName then return end

    local current = modData.LWN_CreateHookSequence
    if not current or current == "" then
        modData.LWN_CreateHookSequence = hookName
        return
    end
    modData.LWN_CreateHookSequence = current .. ">" .. hookName
end

local function createHookComparisonDetail(record, actor, hookName, modData, extraDetail)
    local state = getPresentationState(actor)
    local npcId = record and record.id or (modData and (modData.LWN_NpcId or modData.LWN_LastNpcId) or nil)
    local cleanupState = getCleanupState(npcId)
    local actorCleanup = getActorCleanupState(actor)
    local registeredActor = record
        and LWN.EmbodimentManager
        and LWN.EmbodimentManager.getActor
        and LWN.EmbodimentManager.getActor(record)
        or nil
    local parts = {
        string.format("hook=%s", tostring(hookName)),
        string.format("observedOrder=%s", tostring(modData and modData.LWN_CreateHookSequence or nil)),
        string.format("expected=%s", tostring(modData and modData.LWN_CreateHookExpected or nil)),
        string.format("previousHook=%s", tostring(modData and modData.LWN_LastCreateHook or nil)),
        string.format("appliedBy=%s", tostring(modData and modData.LWN_PostCreateAppliedBy or nil)),
        string.format("hookPending=%s", tostring(modData and modData.LWN_CreateHookPending == true)),
        string.format("postCreateApplied=%s", tostring(modData and modData.LWN_PostCreateApplied == true)),
        string.format("recordState=%s", tostring(record and record.embodiment and record.embodiment.state or nil)),
        string.format("registeredRef=%s", tostring(registeredActor and objectRef(registeredActor) or nil)),
        string.format("registeredMatch=%s", tostring(registeredActor ~= nil and registeredActor == actor or false)),
        string.format("cleanupBlocked=%s", tostring(npcId ~= nil and isCleanupBlocked(npcId) or false)),
        string.format("cleanupStage=%s", tostring(cleanupState and cleanupState.stage or nil)),
        string.format("cleanupReason=%s", tostring(cleanupState and cleanupState.reason or nil)),
        string.format("actorCleanupStage=%s", tostring(actorCleanup and actorCleanup.stage or nil)),
        string.format("actorCleanupReason=%s", tostring(actorCleanup and actorCleanup.reason or nil)),
        string.format("presentationPending=%s", tostring(modData and modData.LWN_PresentationPending == true)),
        string.format("presentationReason=%s", tostring(modData and modData.LWN_PresentationReason or nil)),
        string.format("settledBy=%s", tostring(modData and modData.LWN_PresentationSettledBy or nil)),
        string.format("alpha=%s", tostring(state and safeNumber(state.alpha) or "nil")),
        string.format("targetAlpha=%s", tostring(state and safeNumber(state.targetAlpha) or "nil")),
    }
    if extraDetail and extraDetail ~= "" then
        parts[#parts + 1] = extraDetail
    end
    return table.concat(parts, ",")
end

local function traceEmbodiedDeathLike(record, actor, source)
    if not record or not actor then return end

    local state = getPresentationState(actor)
    if not state or state.deathLike ~= true then
        Adapter._embodiedDeathLikeCache = Adapter._embodiedDeathLikeCache or {}
        Adapter._embodiedDeathLikeCache[record.id] = nil
        return
    end

    Adapter._embodiedDeathLikeCache = Adapter._embodiedDeathLikeCache or {}
    local signature = table.concat({
        safeText(state.objectRef),
        safeText(state.object),
        safeText(state.dead),
        safeText(state.reanimated),
        safeText(state.zombie),
        safeText(state.world),
        safeText(record.embodiment and record.embodiment.state or nil),
    }, "|")
    if Adapter._embodiedDeathLikeCache[record.id] == signature then
        return
    end
    Adapter._embodiedDeathLikeCache[record.id] = signature

    if LWN.EmbodimentManager and LWN.EmbodimentManager.noteDeathLikeActor then
        LWN.EmbodimentManager.noteDeathLikeActor(record, actor, source)
    end

    traceStage("embodiedActor.death_like", record, actor, {
        source = source,
        detail = string.format(
            "recordState=%s object=%s world=%s dead=%s zombie=%s reanimated=%s",
            tostring(record.embodiment and record.embodiment.state or nil),
            tostring(state.object),
            tostring(state.world),
            tostring(state.dead),
            tostring(state.zombie),
            tostring(state.reanimated)
        ),
    })
end

local trackedDeathFields = {
    "objectRef",
    "object",
    "health",
    "dead",
    "downed",
    "deathLike",
    "zombie",
    "reanimated",
    "world",
}

local function deathStateDiff(previous, current)
    if not previous or not current then return nil end

    local changes = {}
    for _, field in ipairs(trackedDeathFields) do
        local before = previous[field]
        local after = current[field]
        if type(before) == "number" and type(after) == "number" then
            if math.abs(before - after) > 0.001 then
                changes[#changes + 1] = string.format("%s:%s->%s", field, safeNumber(before), safeNumber(after))
            end
        elseif before ~= after then
            changes[#changes + 1] = string.format("%s:%s->%s", field, safeText(before), safeText(after))
        end
    end

    if #changes == 0 then return nil end
    return table.concat(changes, ",")
end

local function squareCoords(square)
    if not square then return "nil" end
    return coordSummary(
        protectedCall(square, "getX"),
        protectedCall(square, "getY"),
        protectedCall(square, "getZ")
    )
end

local function worldObjectKind(obj)
    if not obj then return "nil" end
    if instanceof then
        if instanceof(obj, "IsoDeadBody") then return "corpse" end
        if instanceof(obj, "IsoZombie") then return "zombie" end
        if instanceof(obj, "IsoPlayer") then return "player" end
        if instanceof(obj, "IsoSurvivor") then return "survivor" end
    end

    local objectName = protectedCall(obj, "getObjectName")
    if objectName == "DeadBody" then return "corpse" end
    if objectName == "Zombie" then return "zombie" end
    if objectName == "Player" then return "player" end
    return safeText(objectName)
end

local function appendObjectList(entries, seen, list)
    if not list or not list.size or not list.get then return end

    for i = 0, list:size() - 1 do
        local obj = list:get(i)
        local ref = objectRef(obj)
        if not seen[ref] then
            seen[ref] = true
            entries[#entries + 1] = obj
        end
    end
end

local function summarizeWorldObject(obj, record, actor)
    local modData = protectedCall(obj, "getModData")
    local square = protectedCall(obj, "getSquare") or protectedCall(obj, "getCurrentSquare")
    local ref = objectRef(obj)
    local actorRef = objectRef(actor)
    return {
        kind = worldObjectKind(obj),
        object = protectedCall(obj, "getObjectName"),
        objectRef = ref,
        sameActorRef = actor and ref == actorRef or false,
        sameNpcId = record and modData and modData.LWN_NpcId == record.id or false,
        modNpcId = modData and modData.LWN_NpcId or nil,
        zombie = protectedCall(obj, "isZombie"),
        reanimated = protectedCall(obj, "isReanimatedPlayer"),
        dead = protectedCall(obj, "isDead"),
        fakeDead = protectedCall(obj, "isFakeDead"),
        crawling = protectedCall(obj, "isCrawling"),
        world = protectedCall(obj, "isExistInTheWorld"),
        humanVisual = protectedCall(obj, "getHumanVisual") ~= nil,
        actorDescriptor = protectedCall(obj, "getDescriptor") ~= nil,
        square = squareCoords(square),
    }
end

local function isInterestingDeathObject(summary)
    if not summary then return false end
    if summary.kind == "corpse" or summary.kind == "zombie" then
        return true
    end
    if summary.sameActorRef or summary.sameNpcId then
        return true
    end
    return false
end

local function deathObjectSignature(summary)
    return table.concat({
        safeText(summary.kind),
        safeText(summary.object),
        safeText(summary.objectRef),
        safeText(summary.sameActorRef),
        safeText(summary.sameNpcId),
        safeText(summary.modNpcId),
        safeText(summary.zombie),
        safeText(summary.reanimated),
        safeText(summary.dead),
        safeText(summary.fakeDead),
        safeText(summary.crawling),
        safeText(summary.square),
    }, "|")
end

local function logDeathObject(record, actor, source, stage, summary)
    print(string.format(
        "[LWN][DeathTrace] source=%s | stage=%s | npcId=%s | actorRef=%s | actorObject=%s | relatedKind=%s | relatedObject=%s | relatedRef=%s | sameActorRef=%s | sameNpcId=%s | modNpcId=%s | zombie=%s | reanimated=%s | dead=%s | fakeDead=%s | crawling=%s | humanVisual=%s | actorDescriptor=%s | world=%s | square=%s",
        safeText(source),
        safeText(stage),
        safeText(record and record.id or getNpcId(actor)),
        safeText(objectRef(actor)),
        safeText(actor and protectedCall(actor, "getObjectName") or nil),
        safeText(summary.kind),
        safeText(summary.object),
        safeText(summary.objectRef),
        safeText(summary.sameActorRef),
        safeText(summary.sameNpcId),
        safeText(summary.modNpcId),
        safeText(summary.zombie),
        safeText(summary.reanimated),
        safeText(summary.dead),
        safeText(summary.fakeDead),
        safeText(summary.crawling),
        safeText(summary.humanVisual),
        safeText(summary.actorDescriptor),
        safeText(summary.world),
        safeText(summary.square)
    ))
end

local function probeDeathObjects(record, actor, source)
    if not record then return end

    local state = getPresentationState(actor)
    local shouldProbe = state and (state.downed == true or state.deathLike == true or state.zombie == true or state.reanimated == true)

    Adapter._deathObjectCache = Adapter._deathObjectCache or {}
    local previousSignature = Adapter._deathObjectCache[record.id]

    if not shouldProbe and previousSignature == nil then
        return
    end

    local centerSquare = actor and (protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")) or getAnchorSquare(record)
    if not centerSquare then return end

    local cx = protectedCall(centerSquare, "getX") or record.anchor.x or 0
    local cy = protectedCall(centerSquare, "getY") or record.anchor.y or 0
    local cz = protectedCall(centerSquare, "getZ") or record.anchor.z or 0
    local cell = getCell and getCell() or nil
    if not cell then return end

    local signatures = {}
    local seen = {}
    local radius = shouldProbe and 2 or 1

    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            local square = cell:getGridSquare(x, y, cz)
            if square then
                local objects = {}
                appendObjectList(objects, seen, protectedCall(square, "getMovingObjects"))
                appendObjectList(objects, seen, protectedCall(square, "getStaticMovingObjects"))
                for _, obj in ipairs(objects) do
                    local summary = summarizeWorldObject(obj, record, actor)
                    if isInterestingDeathObject(summary) then
                        signatures[#signatures + 1] = deathObjectSignature(summary)
                        if previousSignature == nil or not string.find(previousSignature, summary.objectRef, 1, true) then
                            logDeathObject(record, actor, source, "probe.related_object", summary)
                        end
                    end
                end
            end
        end
    end

    table.sort(signatures)
    local joined = #signatures > 0 and table.concat(signatures, ";") or "none"
    if previousSignature ~= joined then
        traceStage("deathProbe.objects_changed", record, actor, {
            source = source,
            detail = string.format("objectSet=%s", joined),
        })
        Adapter._deathObjectCache[record.id] = joined == "none" and nil or joined
        if joined == "none" and shouldProbe then
            print(string.format(
                "[LWN][DeathTrace] source=%s | stage=probe.related_object | npcId=%s | actorRef=%s | result=none | center=%s",
                safeText(source),
                safeText(record.id),
                safeText(objectRef(actor)),
                coordSummary(cx, cy, cz)
            ))
        end
    end
end

local function traceDeathState(record, actor, source)
    if not actor or not record then return end

    local current = getPresentationState(actor)
    if not current then return end

    Adapter._deathStateCache = Adapter._deathStateCache or {}
    local previous = Adapter._deathStateCache[record.id]
    local detail = deathStateDiff(previous, current)
    if detail then
        traceStage("deathState.changed", record, actor, {
            source = source,
            detail = detail,
        })
    end

    Adapter._deathStateCache[record.id] = copyTable(current)
    probeDeathObjects(record, actor, source)
end

local function updateTravelledDistance(player)
    if not player then return end

    local px = player:getX()
    local py = player:getY()

    if not Adapter._lastPlayerPos then
        Adapter._lastPlayerPos = { x = px, y = py }
        return
    end

    local dx = px - Adapter._lastPlayerPos.x
    local dy = py - Adapter._lastPlayerPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0.01 then
        LWN.PopulationStore.markTravelled(dist)
        Adapter._lastPlayerPos.x = px
        Adapter._lastPlayerPos.y = py
    end
end

local function findActorNearAnchor(record)
    if not record or isCleanupBlocked(record.id) then
        return nil
    end

    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local meta = LWN.PopulationStore.getEmbodiedMeta(record.id)
    local cx = math.floor((meta and meta.x) or record.anchor.x or 0)
    local cy = math.floor((meta and meta.y) or record.anchor.y or 0)
    local cz = math.floor((meta and meta.z) or record.anchor.z or 0)

    for y = cy - 2, cy + 2 do
        for x = cx - 2, cx + 2 do
            local square = cell:getGridSquare(x, y, cz)
            if square and square:getMovingObjects() then
                for i = 0, square:getMovingObjects():size() - 1 do
                    local obj = square:getMovingObjects():get(i)
                    local actorCleanup = getActorCleanupState(obj)
                    if isManagedActor(obj) and getActiveNpcId(obj) == record.id and not (actorCleanup and actorCleanup.pending == true) then
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

getAnchorSquare = function(record)
    local cell = getCell and getCell() or nil
    if not cell or not record then return nil end

    local meta = LWN.PopulationStore.getEmbodiedMeta(record.id)
    local cx = math.floor((meta and meta.x) or record.anchor.x or 0)
    local cy = math.floor((meta and meta.y) or record.anchor.y or 0)
    local cz = math.floor((meta and meta.z) or record.anchor.z or 0)
    return cell:getGridSquare(cx, cy, cz)
end

local function resolveEmbodiedActor(record)
    if not record then
        traceStage("resolveEmbodiedActor.lifecycle_blocked", record, nil, {
            source = "resolveEmbodiedActor",
            detail = "reason=record_missing",
        })
        return nil
    end
    if record.embodiment.state ~= "embodied" then
        traceStage("resolveEmbodiedActor.lifecycle_blocked", record, nil, {
            source = "resolveEmbodiedActor",
            detail = string.format("reason=record_not_embodied recordState=%s", tostring(record.embodiment.state)),
        })
        return nil
    end
    if isCleanupBlocked(record.id) then
        traceStage("resolveEmbodiedActor.lifecycle_blocked", record, nil, {
            source = "resolveEmbodiedActor",
            detail = string.format("reason=cleanup_blocked %s", cleanupStateDetail(record.id)),
        })
        return nil
    end
    if getCleanupState(record.id) then
        traceStage("resolveEmbodiedActor.lifecycle_blocked", record, nil, {
            source = "resolveEmbodiedActor",
            detail = string.format("reason=cleanup_in_progress %s", cleanupStateDetail(record.id)),
        })
        return nil
    end

    local actor = LWN.EmbodimentManager.getActor(record)
    local actorCleanup = getActorCleanupState(actor)
    if actorCleanup and actorCleanup.pending == true then
        traceStage("resolveEmbodiedActor.cached_rejected", record, actor, {
            source = "resolveEmbodiedActor",
            detail = string.format("reason=actor_cleanup_pending %s", actorCleanupDetail(actor)),
        })
        actor = nil
    end
    if actor and LWN.ActorFactory and LWN.ActorFactory.ensureActorInWorld then
        local anchorSquare = getAnchorSquare(record)
        local hadWorld = protectedCall(actor, "isExistInTheWorld")
        local hadSquare = protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")
        local deathLike = LWN.ActorFactory.isDeathLikeActor and LWN.ActorFactory.isDeathLikeActor(actor) or false
        if deathLike then
            traceEmbodiedDeathLike(record, actor, "resolveEmbodiedActor.cached")
        end
        if deathLike and (hadWorld ~= true or not hadSquare) then
            traceStage("resolveEmbodiedActor.repair_blocked_death_like", record, actor, {
                source = "resolveEmbodiedActor",
                square = anchorSquare,
                detail = string.format("hadWorld=%s hadSquare=%s", tostring(hadWorld), tostring(hadSquare ~= nil)),
            })
        else
            LWN.ActorFactory.ensureActorInWorld(actor, anchorSquare)
            local hasWorld = protectedCall(actor, "isExistInTheWorld")
            local hasSquare = protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")
            if hadWorld ~= true or not hadSquare then
                traceStage("resolveEmbodiedActor.repaired_cached", record, actor, {
                    source = "resolveEmbodiedActor",
                    square = anchorSquare,
                    detail = string.format("hadWorld=%s hasWorld=%s", tostring(hadWorld), tostring(hasWorld)),
                })
            end
        end
    end
    if actor
        and getActiveNpcId(actor) == record.id
        and (not actor.isExistInTheWorld or actor:isExistInTheWorld() ~= false)
        and (not LWN.ActorFactory or not LWN.ActorFactory.hasRuntimeCore or LWN.ActorFactory.hasRuntimeCore(actor))
    then
        return actor
    end

    actor = findActorNearAnchor(record)
    if actor then
        local registered = LWN.EmbodimentManager.registerActor(record, actor)
        if registered ~= false then
            traceEmbodiedDeathLike(record, actor, "resolveEmbodiedActor.relinked")
            traceStage("resolveEmbodiedActor.relinked_near_anchor", record, actor, {
                source = "resolveEmbodiedActor",
                square = getAnchorSquare(record),
            })
        else
            traceStage("resolveEmbodiedActor.relink_rejected", record, actor, {
                source = "resolveEmbodiedActor",
                square = getAnchorSquare(record),
                detail = createHookComparisonDetail(record, actor, "resolveEmbodiedActor", protectedCall(actor, "getModData"), "phase=relink_rejected"),
            })
            actor = nil
        end
    end
    return actor
end

local function hideEmbodiedRecord(record, actor, reason, detail)
    traceStage("hideEmbodiedRecord.start", record, actor, {
        source = "hideEmbodiedRecord",
        detail = tostring(reason) .. ":" .. tostring(detail),
    })
    print(string.format("[LWN][Embodiment] hiding %s because %s :: %s", tostring(record.id), tostring(reason), tostring(detail)))
    if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
        LWN.EmbodimentManager.canonicalCleanup(record, {
            actor = actor,
            removeRecord = false,
            reason = reason,
            detail = detail,
        })
    end
    traceStage("hideEmbodiedRecord.hidden", record, actor, {
        source = "hideEmbodiedRecord",
        detail = string.format("reason=%s cooldownUntil=%.2f", tostring(reason), tonumber(record.embodiment.cooldownUntilHour or 0) or 0),
    })
end

local function tickEmbodiedRecord(record, actor, player)
    local actorCleanup = getActorCleanupState(actor)
    if record.embodiment.state ~= "embodied" or isCleanupBlocked(record.id) or getCleanupState(record.id) or (actorCleanup and actorCleanup.pending == true) then
        traceStage("tickEmbodiedRecord.lifecycle_skipped", record, actor, {
            source = "tickEmbodiedRecord",
            detail = string.format(
                "recordState=%s blocked=%s %s %s",
                tostring(record.embodiment.state),
                tostring(isCleanupBlocked(record.id)),
                cleanupStateDetail(record.id),
                actorCleanupDetail(actor)
            ),
        })
        return
    end
    record.embodiment.missingTicks = 0
    traceStage("tickEmbodiedRecord.start", record, actor, {
        source = "tickEmbodiedRecord",
    })
    traceDeathState(record, actor, "tickEmbodiedRecord.start")
    traceEmbodiedDeathLike(record, actor, "tickEmbodiedRecord.start")
    if LWN.ActorSync and LWN.ActorSync.ensureEmbodiedActorState then
        LWN.ActorSync.ensureEmbodiedActorState(record, actor)
    end
    LWN.ActorSync.pullActorToRecord(record, actor)
    LWN.EmbodimentManager.registerActor(record, actor)
    LWN.GoalSystem.update(record, {})

    local combatCtx = LWN.Combat.buildContext(record, actor)
    local combatIntent = LWN.Combat.chooseIntent(record, actor, combatCtx)
    if combatIntent then
        LWN.ActionRuntime.enqueue(record, combatIntent)
    else
        local chosen = LWN.UtilityAI.choose(record, {})
        local intent = LWN.BehaviorTree.tick(record, actor, {}, chosen)
        if intent and not LWN.ActionRuntime.peek(record) then
            LWN.ActionRuntime.enqueue(record, intent)
        end
    end

    LWN.ActionRuntime.tick(record, actor)
    traceDeathState(record, actor, "tickEmbodiedRecord.pre_despawn")
    traceStage("tickEmbodiedRecord.pre_despawn", record, actor, {
        source = "tickEmbodiedRecord",
    })
    LWN.EmbodimentManager.tryDespawn(record, actor, player)
end

function Adapter.onNewGame(player, square)
    LWN.PopulationSeeder.seedNewWorld(player, square)
    LWN.WorldStory.seed()
end

function Adapter.onCreateUI()
    -- Pre-create windows lazily if you prefer. We keep them lazy in the skeleton.
end

local function handleCreatedCharacter(actor, hookName)
    if not actor then return end

    local stageBase = hookStageName(hookName)
    local pendingRecord = nil
    if LWN.ActorFactory and LWN.ActorFactory.attachPendingRecord then
        pendingRecord = LWN.ActorFactory.attachPendingRecord(actor)
    end

    local modData = protectedCall(actor, "getModData")
    local npcId = (modData and modData.LWN_NpcId) or (pendingRecord and pendingRecord.id) or nil
    local hasLwnMarkers = modData and (
        modData.LWN_NpcId ~= nil
        or modData.LWN_LastNpcId ~= nil
        or modData.LWN_CreateHookPending == true
        or modData.LWN_SpawnSource ~= nil
    ) or false
    if not npcId and not pendingRecord and not hasLwnMarkers then
        return
    end

    local record = pendingRecord or (npcId and LWN.PopulationStore and LWN.PopulationStore.getNPC and LWN.PopulationStore.getNPC(npcId) or nil)
    local previousHook = modData and modData.LWN_PostCreateAppliedBy or nil
    local hookPending = modData and modData.LWN_CreateHookPending == true or false
    noteCreateHookSequence(modData, hookName)
    traceStage(stageBase .. ".observed", record or pendingRecord, actor, {
        source = hookName,
        npcId = npcId,
        detail = createHookComparisonDetail(record or pendingRecord, actor, hookName, modData, string.format(
            "recordExists=%s,hookPendingObserved=%s,previousAppliedHook=%s,actorKind=%s",
            tostring(record ~= nil),
            tostring(hookPending),
            tostring(previousHook),
            tostring(protectedCall(actor, "getObjectName"))
        )),
    })

    if not npcId then
        traceStage(stageBase .. ".ignored", pendingRecord, actor, {
            source = hookName,
            detail = "npcId=nil",
        })
        return
    end

    if LWN.ActorFactory and LWN.ActorFactory.hasRuntimeCore and not LWN.ActorFactory.hasRuntimeCore(actor) then
        traceStage(stageBase .. ".invalid_runtime", record, actor, {
            source = hookName,
            npcId = npcId,
        })
        if LWN.ActorFactory.rejectActor then
            LWN.ActorFactory.rejectActor(actor, hookName .. " rejected invalid runtime actor", npcId, record, nil, nil, {
                source = hookName,
                stage = stageBase .. ".invalid_runtime",
            })
        end
        return
    end

    local actorCleanup = getActorCleanupState(actor)
    local recordState = record and record.embodiment and record.embodiment.state or nil
    local rejectReason = nil
    if not record then
        rejectReason = "record_missing"
    elseif isCleanupBlocked(npcId) then
        rejectReason = "cleanup_blocked"
    elseif recordState == "removed" then
        rejectReason = "record_removed"
    elseif actorCleanup and actorCleanup.pending == true then
        rejectReason = "actor_cleanup_pending"
    elseif not pendingRecord and recordState ~= "embodied" then
        rejectReason = "record_not_embodied"
    end

    if rejectReason then
        local rejectStage = rejectReason == "cleanup_blocked" and ".cleanup_rejected" or ".lifecycle_rejected"
        traceStage(stageBase .. rejectStage, pendingRecord or record, actor, {
            source = hookName,
            npcId = npcId,
            detail = string.format(
                "reason=%s recordExists=%s recordState=%s %s %s",
                tostring(rejectReason),
                tostring(record ~= nil),
                tostring(recordState),
                cleanupStateDetail(npcId),
                actorCleanupDetail(actor)
            ),
        })
        if LWN.ActorFactory and LWN.ActorFactory.rejectActor then
            LWN.ActorFactory.rejectActor(actor, hookName .. " rejected lifecycle-blocked actor", npcId, pendingRecord or record, nil, nil, {
                source = hookName,
                stage = stageBase .. rejectStage,
                blocked = isCleanupBlocked(npcId),
                rejectReason = rejectReason,
            })
        end
        return
    end

    if modData then
        modData.LWN_LastCreateHook = hookName
        modData.LWN_LastCreateHookAt = getGameTime() and getGameTime():getWorldAgeHours() or nil
    end

    if modData and modData.LWN_PostCreateApplied == true then
        traceStage(stageBase .. ".compare_only", record, actor, {
            source = hookName,
            detail = createHookComparisonDetail(record, actor, hookName, modData, "compareOnly=true"),
        })
        return
    end

    local anchorSquare = getAnchorSquare(record)
    if LWN.ActorFactory and LWN.ActorFactory.ensureActorInWorld then
        LWN.ActorFactory.ensureActorInWorld(actor, anchorSquare)
    end
    traceStage(stageBase .. ".world_ready", record, actor, {
        source = hookName,
        square = anchorSquare,
        detail = createHookComparisonDetail(record, actor, hookName, modData, "phase=world_ready"),
    })
    if LWN.ActorFactory and LWN.ActorFactory.refreshEmbodiedPresentation then
        LWN.ActorFactory.refreshEmbodiedPresentation(record, actor, protectedCall(actor, "getDescriptor"))
    end
    traceStage(stageBase .. ".presentation_refreshed", record, actor, {
        source = hookName,
        square = anchorSquare,
        detail = createHookComparisonDetail(record, actor, hookName, modData, "phase=presentation_refreshed"),
    })
    if LWN.ActorSync and LWN.ActorSync.pushRecordToActor then
        LWN.ActorSync.pushRecordToActor(record, actor)
    end
    traceStage(stageBase .. ".synced", record, actor, {
        source = hookName,
        detail = createHookComparisonDetail(record, actor, hookName, modData, "phase=synced"),
    })
    if record.embodiment.state == "embodied" and LWN.EmbodimentManager and LWN.EmbodimentManager.registerActor then
        LWN.EmbodimentManager.registerActor(record, actor)
        traceStage(stageBase .. ".registered", record, actor, {
            source = hookName,
            detail = createHookComparisonDetail(record, actor, hookName, modData, "phase=registered"),
        })
    end

    if modData then
        modData.LWN_CreateHookPending = false
        modData.LWN_PostCreateApplied = true
        modData.LWN_PostCreateAppliedBy = hookName
        modData.LWN_PostCreateAppliedAt = getGameTime() and getGameTime():getWorldAgeHours() or nil
        traceStage(stageBase .. ".applied", record, actor, {
            source = hookName,
            detail = createHookComparisonDetail(record, actor, hookName, modData, "phase=applied"),
        })
    end
end

function Adapter.onCreateSurvivor(survivor)
    handleCreatedCharacter(survivor, "OnCreateSurvivor")
end

function Adapter.onCreateLivingCharacter(character)
    handleCreatedCharacter(character, "OnCreateLivingCharacter")
end

function Adapter.onPlayerDeath(player)
    LWN.Legacy.showDeathModal(player)
end

function Adapter.onEveryOneMinute()
    local player = getPlayerSafe()
    if not player then return end

    if isPlayerAsleep(player) then
        LWN.PopulationStore.markSlept()
    end

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state ~= "embodied" then
            record.stats.hunger = math.min(1.0, record.stats.hunger + 0.01)
            record.stats.thirst = math.min(1.0, record.stats.thirst + 0.012)
            record.stats.fatigue = math.min(1.0, record.stats.fatigue + 0.006)
            LWN.Memory.tickDecay(record)
            LWN.WorldStory.tickNPC(record)
        end
    end)

    LWN.EncounterDirector.update(player)
end

function Adapter.onEveryTenMinutes()
    LWN.PopulationStore.eachNPC(function(record)
        local clue = LWN.WorldStory.maybeCreateClue(record)
        if clue then
            LWN.PopulationStore.addWorldClue(clue)
            LWN.PopulationStore.addWorldEvent({
                kind = "story_clue_created",
                npcId = clue.npcId,
                x = clue.x,
                y = clue.y,
                z = clue.z,
                text = clue.text,
            })
            print(string.format("[LWN][WorldStory] created clue for %s", tostring(clue.npcId)))
        end
    end)
end

function Adapter.onTick()
    local player = getPlayerSafe()
    if not player then return end

    updateTravelledDistance(player)

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state == "hidden" and LWN.EmbodimentManager.tryRearmHidden then
            LWN.EmbodimentManager.tryRearmHidden(record, player)
        end
    end)

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state == "eligible" then
            LWN.EmbodimentManager.tryEmbody(record, player)
        end
    end)

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state == "embodied" then
            local actor = resolveEmbodiedActor(record)

            if actor then
                local ok, err = pcall(tickEmbodiedRecord, record, actor, player)
                if not ok then
                    hideEmbodiedRecord(record, actor, "embodied_tick_error", err)
                end
            else
                record.embodiment.missingTicks = (record.embodiment.missingTicks or 0) + 1
                if record.embodiment.missingTicks == 1 then
                    traceStage("onTick.actor_missing", record, nil, {
                        source = "onTick",
                        detail = "missingTicks=1",
                    })
                    probeDeathObjects(record, nil, "onTick.actor_missing")
                end
                if record.embodiment.missingTicks >= 10 then
                    traceStage("onTick.actor_missing_threshold", record, nil, {
                        source = "onTick",
                        detail = "missingTicks=" .. tostring(record.embodiment.missingTicks),
                    })
                    hideEmbodiedRecord(record, nil, "actor_lost", "resolveEmbodiedActor returned nil")
                end
            end
        end
    end)

    if LWN.UIRadialMenu and LWN.UIRadialMenu.refresh then
        LWN.UIRadialMenu:refresh()
    end
    if LWN.UICommandPanel and LWN.UICommandPanel.refresh then
        LWN.UICommandPanel:refresh()
    end
    if LWN.UIDialogueWindow and LWN.UIDialogueWindow.refresh then
        LWN.UIDialogueWindow:refresh()
    end
end

function Adapter.bind()
    -- These hooks come from the shipped/community Lua event layer, not the Java Javadocs.
    Events.OnNewGame.Add(Adapter.onNewGame)
    Events.OnCreateUI.Add(Adapter.onCreateUI)
    if Events.OnCreateLivingCharacter then
        Events.OnCreateLivingCharacter.Add(Adapter.onCreateLivingCharacter)
    end
    Events.OnCreateSurvivor.Add(Adapter.onCreateSurvivor)
    Events.OnPlayerDeath.Add(Adapter.onPlayerDeath)
    Events.OnFillWorldObjectContextMenu.Add(LWN.UIContextMenu.onFillWorldObjectContextMenu)
    Events.OnCustomUIKeyPressed.Add(LWN.UIRadialMenu.onCustomUIKeyPressed)
    if LWN.DebugTools and LWN.DebugTools.onKeyPressed then
        Events.OnKeyPressed.Add(LWN.DebugTools.onKeyPressed)
    end
    Events.EveryOneMinute.Add(Adapter.onEveryOneMinute)
    Events.EveryTenMinutes.Add(Adapter.onEveryTenMinutes)
    Events.OnTick.Add(Adapter.onTick)
end
