LWN = LWN or {}
LWN.ActorFactory = LWN.ActorFactory or {}

-- Embodied actors are a render/runtime cache over canonical ModData records.
-- This module is responsible for making that cache visible and debuggable.
local Factory = LWN.ActorFactory
local Store = LWN.PopulationStore

local fallbackClothing = {
    "Base.Tshirt_WhiteTINT",
    "Base.Trousers_Denim",
    "Base.Shoes_Random",
}

local function callIf(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if fn then
        return fn(obj, ...)
    end
    return nil
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

local function appendPart(parts, key, value)
    parts[#parts + 1] = tostring(key) .. "=" .. safeText(value)
end

local function safeSize(value)
    if not value then return 0 end
    local size = protectedCall(value, "size")
    if type(size) == "number" then
        return size
    end
    return 0
end

local function dist2(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return dx * dx + dy * dy
end

local function coordSummary(x, y, z)
    return safeNumber(x) .. "," .. safeNumber(y) .. "," .. safeNumber(z)
end

local function objectRef(value)
    if value == nil then return "nil" end
    return safeText(tostring(value))
end

local function getNpcIdFromActor(actor)
    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_NpcId or nil
end

local function isManagedActor(obj)
    if not obj then return false end
    if getNpcIdFromActor(obj) == nil then return false end
    if protectedCall(obj, "isDestroyed") == true then return false end
    if protectedCall(obj, "isExistInTheWorld") == false then return false end
    return protectedCall(obj, "getBodyDamage") ~= nil
        and protectedCall(obj, "getStats") ~= nil
        and protectedCall(obj, "getInventory") ~= nil
end

local function squareSummary(square)
    if not square then return "square=nil" end

    local parts = {}
    appendPart(parts, "square", coordSummary(protectedCall(square, "getX"), protectedCall(square, "getY"), protectedCall(square, "getZ")))

    local zone = protectedCall(square, "getZone")
    if zone and zone.getType then
        appendPart(parts, "zone", protectedCall(zone, "getType"))
    end

    local room = protectedCall(square, "getRoom")
    if room and room.getName then
        appendPart(parts, "room", protectedCall(room, "getName"))
    end

    local building = room and protectedCall(room, "getBuilding") or nil
    appendPart(parts, "building", building ~= nil)
    appendPart(parts, "free", protectedCall(square, "isFree", false))
    appendPart(parts, "solidFloor", protectedCall(square, "isSolidFloor"))
    return table.concat(parts, " | ")
end

local function descriptorSummary(desc, descriptorMode)
    if not desc then
        return "descriptor=nil"
    end

    local parts = {}
    appendPart(parts, "descriptorMode", descriptorMode)
    appendPart(parts, "female", protectedCall(desc, "isFemale"))
    appendPart(parts, "forename", protectedCall(desc, "getForename"))
    appendPart(parts, "surname", protectedCall(desc, "getSurname"))
    appendPart(parts, "profession", protectedCall(desc, "getProfession"))
    return table.concat(parts, " | ")
end

local function isDebugModeEnabled()
    if LWN and LWN.Config and LWN.Config.Debug and LWN.Config.Debug.Enabled == true then
        return true
    end
    if LWN.DebugTools and LWN.DebugTools.isEnabled then
        return LWN.DebugTools.isEnabled() == true
    end
    return false
end

local function isVisualProbeEnabled(record)
    if not isDebugModeEnabled() then
        return false
    end
    if LWN.Config.Debug.Verbose == true then
        return true
    end
    if record and record.debugSpawnOnly == true then
        return true
    end
    if LWN.DebugTools and LWN.DebugTools.isEnabled then
        return LWN.DebugTools.isEnabled() == true
    end
    return false
end

local function recordSummary(record)
    if not record then
        return "record=nil"
    end

    local identity = record.identity or {}
    local backstory = record.backstory or {}
    local anchor = record.anchor or {}
    local embodiment = record.embodiment or {}
    local companion = record.companion or {}
    local storyArc = record.storyArc or {}
    local stats = record.stats or {}
    local goals = record.goals or {}
    local longTerm = goals.longTerm or {}

    local parts = {}
    appendPart(parts, "id", record.id)
    appendPart(parts, "name", safeText(identity.firstName) .. " " .. safeText(identity.lastName))
    appendPart(parts, "female", identity.female == true)
    appendPart(parts, "profession", identity.profession)
    appendPart(parts, "formerProfession", backstory.formerProfession)
    appendPart(parts, "anchor", coordSummary(anchor.x, anchor.y, anchor.z))
    appendPart(parts, "state", embodiment.state)
    appendPart(parts, "cooldownUntil", safeNumber(embodiment.cooldownUntilHour))
    appendPart(parts, "debugSpawnOnly", record.debugSpawnOnly == true)
    appendPart(parts, "recruited", companion.recruited == true)
    appendPart(parts, "story", storyArc.type)
    appendPart(parts, "goal", longTerm.kind)
    appendPart(parts, "traits", #(identity.traitIds or {}))
    appendPart(parts, "hunger", safeNumber(stats.hunger))
    appendPart(parts, "thirst", safeNumber(stats.thirst))
    appendPart(parts, "fatigue", safeNumber(stats.fatigue))
    appendPart(parts, "health", safeNumber(stats.health))
    return table.concat(parts, " | ")
end

local function actorSummary(actor)
    if not actor then
        return "actor=nil"
    end

    local square = protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")
    local bodyDamage = protectedCall(actor, "getBodyDamage")
    local health = protectedCall(actor, "getHealth")
    if health == nil then
        health = protectedCall(bodyDamage, "getHealth")
    end
    local isZombie = protectedCall(actor, "isZombie")
    local isReanimated = protectedCall(actor, "isReanimatedPlayer")
    local isDead = protectedCall(actor, "isDead")
    local isOnFloor = protectedCall(actor, "isOnFloor")
    local isFallOnFront = protectedCall(actor, "isFallOnFront")
    local isKnockedDown = protectedCall(actor, "isKnockedDown")
    local isDeathFinished = protectedCall(actor, "isDeathFinished")
    local isDowned = isOnFloor == true or isFallOnFront == true or isKnockedDown == true
    local isDeathLike = isDead == true
        or isReanimated == true
        or isDeathFinished == true
        or (type(health) == "number" and health <= 0)
    local parts = {}
    appendPart(parts, "object", protectedCall(actor, "getObjectName"))
    appendPart(parts, "npcId", getNpcIdFromActor(actor))
    appendPart(parts, "objectRef", objectRef(actor))
    appendPart(parts, "body", protectedCall(actor, "getBodyDamage") ~= nil)
    appendPart(parts, "stats", protectedCall(actor, "getStats") ~= nil)
    appendPart(parts, "inventory", protectedCall(actor, "getInventory") ~= nil)
    appendPart(parts, "npc", protectedCall(actor, "getIsNPC"))
    appendPart(parts, "health", safeNumber(health))
    appendPart(parts, "zombie", isZombie)
    appendPart(parts, "reanimated", isReanimated)
    appendPart(parts, "dead", isDead)
    appendPart(parts, "downed", isDowned)
    appendPart(parts, "onFloor", isOnFloor)
    appendPart(parts, "fallOnFront", isFallOnFront)
    appendPart(parts, "knockedDown", isKnockedDown)
    appendPart(parts, "deathFinished", isDeathFinished)
    appendPart(parts, "deathLike", isDeathLike)
    appendPart(parts, "ghost", protectedCall(actor, "isGhostMode"))
    appendPart(parts, "invisible", protectedCall(actor, "isInvisible"))
    appendPart(parts, "sceneCulled", protectedCall(actor, "isSceneCulled"))
    appendPart(parts, "alpha", safeNumber(protectedCall(actor, "getAlpha", 0)))
    appendPart(parts, "targetAlpha", safeNumber(protectedCall(actor, "getTargetAlpha", 0)))
    appendPart(parts, "alphaZero", protectedCall(actor, "isAlphaZero"))
    appendPart(parts, "targetAlphaZero", protectedCall(actor, "isTargetAlphaZero", 0))
    appendPart(parts, "humanVisual", protectedCall(actor, "getHumanVisual") ~= nil)
    appendPart(parts, "actorDescriptor", protectedCall(actor, "getDescriptor") ~= nil)
    appendPart(parts, "pos", coordSummary(protectedCall(actor, "getX"), protectedCall(actor, "getY"), protectedCall(actor, "getZ")))
    appendPart(parts, "destroyed", protectedCall(actor, "isDestroyed"))
    appendPart(parts, "world", protectedCall(actor, "isExistInTheWorld"))
    appendPart(parts, "square", squareSummary(square))
    return table.concat(parts, " | ")
end

local function squareCoords(square)
    if not square then return "nil" end
    return coordSummary(
        protectedCall(square, "getX"),
        protectedCall(square, "getY"),
        protectedCall(square, "getZ")
    )
end

local function visualSummary(actor, descriptor)
    if not actor then
        return "visual=nil"
    end

    local visual = protectedCall(actor, "getHumanVisual")
    local itemVisuals = protectedCall(actor, "getItemVisuals")
    local wornItems = protectedCall(actor, "getWornItems")
    local actorDescriptor = protectedCall(actor, "getDescriptor")
    local desc = actorDescriptor or descriptor
    local parts = {}

    appendPart(parts, "descriptor", descriptor ~= nil)
    appendPart(parts, "actorDescriptor", actorDescriptor ~= nil)
    appendPart(parts, "humanVisual", visual ~= nil)
    appendPart(parts, "female", protectedCall(actor, "isFemale") or (desc and protectedCall(desc, "isFemale")) or nil)
    appendPart(parts, "skin", visual and (protectedCall(visual, "getSkinTexture") or protectedCall(visual, "getSkinTextureName")) or nil)
    appendPart(parts, "hair", visual and protectedCall(visual, "getHairModel") or nil)
    appendPart(parts, "beard", visual and protectedCall(visual, "getBeardModel") or nil)
    appendPart(parts, "itemVisuals", safeSize(itemVisuals))
    appendPart(parts, "wornItems", safeSize(wornItems))
    appendPart(parts, "persistentOutfitId", protectedCall(actor, "getPersistentOutfitID"))
    return table.concat(parts, " | ")
end

local function actorPresentationState(actor)
    if not actor then
        return nil
    end

    local bodyDamage = protectedCall(actor, "getBodyDamage")
    local health = protectedCall(actor, "getHealth")
    if health == nil then
        health = protectedCall(bodyDamage, "getHealth")
    end

    local isZombie = protectedCall(actor, "isZombie")
    local isReanimated = protectedCall(actor, "isReanimatedPlayer")
    local isDead = protectedCall(actor, "isDead")
    local isOnFloor = protectedCall(actor, "isOnFloor")
    local isFallOnFront = protectedCall(actor, "isFallOnFront")
    local isKnockedDown = protectedCall(actor, "isKnockedDown")
    local isDeathFinished = protectedCall(actor, "isDeathFinished")
    local isDowned = isOnFloor == true or isFallOnFront == true or isKnockedDown == true
    local isDeathLike = isDead == true
        or isReanimated == true
        or isDeathFinished == true
        or (type(health) == "number" and health <= 0)

    return {
        objectRef = objectRef(actor),
        object = protectedCall(actor, "getObjectName"),
        npc = protectedCall(actor, "getIsNPC"),
        health = health,
        zombie = isZombie,
        reanimated = isReanimated,
        dead = isDead,
        downed = isDowned,
        onFloor = isOnFloor,
        fallOnFront = isFallOnFront,
        knockedDown = isKnockedDown,
        deathFinished = isDeathFinished,
        deathLike = isDeathLike,
        world = protectedCall(actor, "isExistInTheWorld"),
        destroyed = protectedCall(actor, "isDestroyed"),
        ghost = protectedCall(actor, "isGhostMode"),
        invisible = protectedCall(actor, "isInvisible"),
        sceneCulled = protectedCall(actor, "isSceneCulled"),
        alpha = protectedCall(actor, "getAlpha", 0),
        targetAlpha = protectedCall(actor, "getTargetAlpha", 0),
        alphaZero = protectedCall(actor, "isAlphaZero"),
        targetAlphaZero = protectedCall(actor, "isTargetAlphaZero", 0),
        humanVisual = protectedCall(actor, "getHumanVisual") ~= nil,
        actorDescriptor = protectedCall(actor, "getDescriptor") ~= nil,
    }
end

local function presentationStateSummary(actor)
    local state = actorPresentationState(actor)
    if not state then
        return "presentation=nil"
    end

    local parts = {}
    appendPart(parts, "objectRef", state.objectRef)
    appendPart(parts, "object", state.object)
    appendPart(parts, "npc", state.npc)
    appendPart(parts, "health", safeNumber(state.health))
    appendPart(parts, "zombie", state.zombie)
    appendPart(parts, "reanimated", state.reanimated)
    appendPart(parts, "dead", state.dead)
    appendPart(parts, "downed", state.downed)
    appendPart(parts, "onFloor", state.onFloor)
    appendPart(parts, "fallOnFront", state.fallOnFront)
    appendPart(parts, "knockedDown", state.knockedDown)
    appendPart(parts, "deathFinished", state.deathFinished)
    appendPart(parts, "deathLike", state.deathLike)
    appendPart(parts, "world", state.world)
    appendPart(parts, "destroyed", state.destroyed)
    appendPart(parts, "ghost", state.ghost)
    appendPart(parts, "invisible", state.invisible)
    appendPart(parts, "sceneCulled", state.sceneCulled)
    appendPart(parts, "alpha", safeNumber(state.alpha))
    appendPart(parts, "targetAlpha", safeNumber(state.targetAlpha))
    appendPart(parts, "alphaZero", state.alphaZero)
    appendPart(parts, "targetAlphaZero", state.targetAlphaZero)
    appendPart(parts, "humanVisual", state.humanVisual)
    appendPart(parts, "actorDescriptor", state.actorDescriptor)
    return table.concat(parts, ",")
end

local trackedPresentationFields = {
    "objectRef",
    "object",
    "npc",
    "world",
    "health",
    "dead",
    "downed",
    "deathLike",
    "zombie",
    "reanimated",
    "ghost",
    "invisible",
    "sceneCulled",
    "alpha",
    "targetAlpha",
    "alphaZero",
    "targetAlphaZero",
    "humanVisual",
    "actorDescriptor",
}

local function copyTable(source)
    if not source then return nil end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function presentationTraceKey(record, actor)
    return (record and record.id) or getNpcIdFromActor(actor) or objectRef(actor)
end

local function presentationDiffSummary(previous, current)
    if not previous or not current then
        return nil
    end

    local changes = {}
    for _, field in ipairs(trackedPresentationFields) do
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

    if #changes == 0 then
        return nil
    end
    return table.concat(changes, ",")
end

local function shouldWatchAlphaState(state)
    if not state then return false end

    local alphaZero = state.alphaZero == true
        or (type(state.alpha) == "number" and state.alpha <= 0.01)
    local targetZero = state.targetAlphaZero == true
        or (type(state.targetAlpha) == "number" and state.targetAlpha <= 0.01)

    if not alphaZero and not targetZero then
        return false
    end

    return state.deathLike ~= true
        and state.destroyed ~= true
        and state.world ~= false
        and state.ghost ~= true
        and state.invisible ~= true
        and state.sceneCulled ~= true
end

local function tracePresentationWatch(moduleName, stage, record, actor, extra)
    if not isDebugModeEnabled() or not actor then return end

    local key = presentationTraceKey(record, actor)
    Factory._presentationTraceCache = Factory._presentationTraceCache or {}
    Factory._presentationAlphaWatch = Factory._presentationAlphaWatch or {}

    local current = actorPresentationState(actor)
    local previous = Factory._presentationTraceCache[key]
    local changed = presentationDiffSummary(previous, current)

    if changed then
        print(string.format(
            "[LWN][PresentationWatch] module=%s | stage=%s | npcId=%s | source=%s | detail=%s",
            safeText(moduleName),
            safeText(stage),
            safeText(key),
            safeText(extra and extra.source or nil),
            safeText(changed)
        ))
    end

    if shouldWatchAlphaState(current) then
        local signature = string.format(
            "objectRef=%s|alpha=%s|targetAlpha=%s|dead=%s|downed=%s|deathLike=%s|humanVisual=%s|actorDescriptor=%s",
            safeText(current.objectRef),
            safeNumber(current.alpha),
            safeNumber(current.targetAlpha),
            safeText(current.dead),
            safeText(current.downed),
            safeText(current.deathLike),
            safeText(current.humanVisual),
            safeText(current.actorDescriptor)
        )
        local lastSignature = Factory._presentationAlphaWatch[key]
        if lastSignature ~= signature then
            Factory._presentationAlphaWatch[key] = signature
            print(string.format(
                "[LWN][PresentationWatch] module=%s | stage=%s | npcId=%s | alphaWatch=true | objectRef=%s | object=%s | world=%s | ghost=%s | invisible=%s | sceneCulled=%s | alpha=%s | targetAlpha=%s | alphaZero=%s | targetAlphaZero=%s | health=%s | dead=%s | downed=%s | deathLike=%s | humanVisual=%s | actorDescriptor=%s",
                safeText(moduleName),
                safeText(stage),
                safeText(key),
                safeText(current.objectRef),
                safeText(current.object),
                safeText(current.world),
                safeText(current.ghost),
                safeText(current.invisible),
                safeText(current.sceneCulled),
                safeNumber(current.alpha),
                safeNumber(current.targetAlpha),
                safeText(current.alphaZero),
                safeText(current.targetAlphaZero),
                safeNumber(current.health),
                safeText(current.dead),
                safeText(current.downed),
                safeText(current.deathLike),
                safeText(current.humanVisual),
                safeText(current.actorDescriptor)
            ))
        end
    else
        Factory._presentationAlphaWatch[key] = nil
    end

    Factory._presentationTraceCache[key] = copyTable(current)
end

local function extraSummary(extra)
    if not extra then return "extra=nil" end

    local parts = {}
    appendPart(parts, "source", extra.source)
    appendPart(parts, "detail", extra.detail)
    appendPart(parts, "thrown", extra.thrown)
    appendPart(parts, "spawnSource", extra.spawnSource)
    if extra.square then
        appendPart(parts, "targetSquare", squareSummary(extra.square))
    end
    return table.concat(parts, " | ")
end

local function stageTrace(moduleName, stage, record, actor, descriptor, extra)
    if not isDebugModeEnabled() then return end

    local currentSquare = actor and (protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")) or nil
    local targetSquare = extra and extra.square or nil
    local actorDescriptor = actor and protectedCall(actor, "getDescriptor") or nil
    local presentation = actor and actorPresentationState(actor) or nil
    local visual = actor and protectedCall(actor, "getHumanVisual") or nil
    local itemVisuals = actor and protectedCall(actor, "getItemVisuals") or nil
    local wornItems = actor and protectedCall(actor, "getWornItems") or nil

    local parts = {
        "[LWN][EmbodimentTrace]",
    }

    appendPart(parts, "module", moduleName)
    appendPart(parts, "stage", stage)
    appendPart(parts, "npcId", record and record.id or getNpcIdFromActor(actor) or (extra and extra.npcId) or nil)
    appendPart(parts, "objectRef", actor and objectRef(actor) or nil)
    appendPart(parts, "object", presentation and presentation.object or nil)
    appendPart(parts, "npc", presentation and presentation.npc or nil)
    appendPart(parts, "health", presentation and safeNumber(presentation.health) or nil)
    appendPart(parts, "zombie", presentation and presentation.zombie or nil)
    appendPart(parts, "reanimated", presentation and presentation.reanimated or nil)
    appendPart(parts, "dead", presentation and presentation.dead or nil)
    appendPart(parts, "downed", presentation and presentation.downed or nil)
    appendPart(parts, "deathLike", presentation and presentation.deathLike or nil)
    appendPart(parts, "world", actor and protectedCall(actor, "isExistInTheWorld") or nil)
    appendPart(parts, "currentSquare", squareCoords(currentSquare))
    appendPart(parts, "targetSquare", squareCoords(targetSquare))
    appendPart(parts, "ghost", actor and protectedCall(actor, "isGhostMode") or nil)
    appendPart(parts, "invisible", actor and protectedCall(actor, "isInvisible") or nil)
    appendPart(parts, "sceneCulled", actor and protectedCall(actor, "isSceneCulled") or nil)
    appendPart(parts, "alpha", presentation and safeNumber(presentation.alpha) or nil)
    appendPart(parts, "targetAlpha", presentation and safeNumber(presentation.targetAlpha) or nil)
    appendPart(parts, "alphaZero", presentation and presentation.alphaZero or nil)
    appendPart(parts, "targetAlphaZero", presentation and presentation.targetAlphaZero or nil)
    appendPart(parts, "descriptor", descriptor ~= nil)
    appendPart(parts, "actorDescriptor", actorDescriptor ~= nil)
    appendPart(parts, "humanVisual", visual ~= nil)
    appendPart(parts, "skin", visual and (protectedCall(visual, "getSkinTexture") or protectedCall(visual, "getSkinTextureName")) or nil)
    appendPart(parts, "hair", visual and protectedCall(visual, "getHairModel") or nil)
    appendPart(parts, "beard", visual and protectedCall(visual, "getBeardModel") or nil)
    appendPart(parts, "itemVisuals", safeSize(itemVisuals))
    appendPart(parts, "wornItems", safeSize(wornItems))
    appendPart(parts, "persistentOutfitId", actor and protectedCall(actor, "getPersistentOutfitID") or nil)

    if record and record.anchor then
        appendPart(parts, "anchor", coordSummary(record.anchor.x, record.anchor.y, record.anchor.z))
    end
    if extra and extra.source then
        appendPart(parts, "source", extra.source)
    end
    if extra and extra.spawnSource then
        appendPart(parts, "spawnSource", extra.spawnSource)
    end
    if extra and extra.detail then
        appendPart(parts, "detail", extra.detail)
    end

    print(table.concat(parts, " | "))
    tracePresentationWatch(moduleName, stage, record, actor, extra)

    if isVisualProbeEnabled(record) then
        if record then
            print("[LWN][EmbodimentTrace] module=" .. safeText(moduleName) .. " | stage=" .. safeText(stage) .. " | record :: " .. recordSummary(record))
        end
        if actor then
            print("[LWN][EmbodimentTrace] module=" .. safeText(moduleName) .. " | stage=" .. safeText(stage) .. " | actor :: " .. actorSummary(actor))
            print("[LWN][EmbodimentTrace] module=" .. safeText(moduleName) .. " | stage=" .. safeText(stage) .. " | visuals :: " .. visualSummary(actor, descriptor))
        end
        if descriptor then
            print("[LWN][EmbodimentTrace] module=" .. safeText(moduleName) .. " | stage=" .. safeText(stage) .. " | descriptor :: " .. descriptorSummary(descriptor, extra and extra.descriptorMode or nil))
        end
    end
end

local function rememberFailure(snapshot)
    Factory._lastFailure = snapshot
    if Store and Store.debugState then
        Store.debugState().lastActorFailure = snapshot
    end
end

local function logFailure(reason, record, actor, descriptor, descriptorMode, extra)
    local snapshot = {
        reason = reason,
        npcId = record and record.id or (extra and extra.npcId) or nil,
        worldAgeHours = getGameTime() and getGameTime():getWorldAgeHours() or nil,
        record = recordSummary(record),
        actor = actorSummary(actor),
        descriptor = descriptorSummary(descriptor, descriptorMode),
        extra = extraSummary(extra),
    }

    rememberFailure(snapshot)
    stageTrace("ActorFactory", extra and extra.stage or "failure", record, actor, descriptor, {
        source = extra and extra.source or "logFailure",
        square = extra and extra.square or nil,
        spawnSource = extra and extra.spawnSource or nil,
        detail = reason,
        descriptorMode = descriptorMode,
        npcId = snapshot.npcId,
    })

    print("[LWN][ActorFactory] " .. safeText(reason) .. " for " .. safeText(snapshot.npcId))
    print("[LWN][ActorFactory] failure record :: " .. snapshot.record)
    print("[LWN][ActorFactory] failure actor :: " .. snapshot.actor)
    if actor then
        print("[LWN][ActorFactory] failure visuals :: " .. visualSummary(actor, descriptor))
    end
    print("[LWN][ActorFactory] failure descriptor :: hour=" .. safeNumber(snapshot.worldAgeHours) .. " | " .. snapshot.descriptor .. " | " .. snapshot.extra)
end

local function logInfo(message, record, actor, extra)
    if not isDebugModeEnabled() then return end

    local parts = {
        "[LWN][ActorFactory] " .. safeText(message),
    }

    if record then
        parts[#parts + 1] = "record=" .. record.id
    end
    if actor then
        parts[#parts + 1] = "npcId=" .. safeText(getNpcIdFromActor(actor))
        parts[#parts + 1] = "actor=" .. safeText(protectedCall(actor, "getObjectName"))
    end
    if extra then
        parts[#parts + 1] = extraSummary(extra)
    end
    print(table.concat(parts, " | "))
    if actor then
        print("[LWN][ActorFactory] actor state :: " .. actorSummary(actor))
        print("[LWN][ActorFactory] actor visuals :: " .. visualSummary(actor))
    end
end

local function modelManager()
    if ModelManager and ModelManager.instance then
        return ModelManager.instance
    end
    return nil
end

local function refreshModelManager(actor, reason)
    local manager = modelManager()
    if not manager or not actor then return nil end

    local before = protectedCall(manager, "ContainsChar", actor)
    if before ~= true then
        protectedCall(manager, "Add", actor)
    end

    protectedCall(manager, "Reset", actor)
    protectedCall(manager, "ResetNextFrame", actor)
    protectedCall(manager, "ResetCharacterEquippedHands", actor)

    local after = protectedCall(manager, "ContainsChar", actor)
    if LWN.Config.Debug.Verbose then
        print(string.format(
            "[LWN][ActorFactory] ModelManager refresh reason=%s before=%s after=%s npcId=%s",
            safeText(reason),
            safeText(before),
            safeText(after),
            safeText(getNpcIdFromActor(actor))
        ))
    end
    return after
end

local function repairVisibleAlpha(actor, reason)
    if not actor then return false end

    local before = actorPresentationState(actor)
    if not shouldWatchAlphaState(before) then
        return false
    end

    protectedCall(actor, "setAlphaAndTarget", 1.0)
    protectedCall(actor, "setAlphaToTarget", 0)

    local after = actorPresentationState(actor)
    print(string.format(
        "[LWN][PresentationWatch] action=alpha_repair | reason=%s | npcId=%s | objectRef=%s | beforeAlpha=%s | beforeTargetAlpha=%s | afterAlpha=%s | afterTargetAlpha=%s | dead=%s | downed=%s | deathLike=%s",
        safeText(reason),
        safeText(getNpcIdFromActor(actor)),
        safeText(objectRef(actor)),
        safeNumber(before and before.alpha or nil),
        safeNumber(before and before.targetAlpha or nil),
        safeNumber(after and after.alpha or nil),
        safeNumber(after and after.targetAlpha or nil),
        safeText(after and after.dead or nil),
        safeText(after and after.downed or nil),
        safeText(after and after.deathLike or nil)
    ))
    return true
end

local function markPresentationPending(actor, reason)
    local modData = protectedCall(actor, "getModData")
    if not modData then return end

    modData.LWN_PresentationPending = true
    modData.LWN_PresentationReason = reason
    modData.LWN_PresentationPendingAt = getGameTime() and getGameTime():getWorldAgeHours() or nil
end

local function safeCleanupActor(actor)
    if not actor then return end
    local modData = protectedCall(actor, "getModData")
    if modData and modData.LWN_NpcId ~= nil then
        modData.LWN_LastNpcId = modData.LWN_NpcId
    end

    protectedCall(actor, "StopAllActionQueue")
    protectedCall(actor, "setGhostMode", true)
    protectedCall(actor, "setInvisible", true)
    protectedCall(actor, "setSceneCulled", true)
    protectedCall(actor, "setNPC", false)
    protectedCall(actor, "setIsNPC", false)

    -- Prefer the engine-managed despawn path. Clearing square/current references
    -- here can leave a scheduled update with a nil currentSquare in the same frame.
    local despawned = protectedCall(actor, "Despawn")
    local stillWorld = protectedCall(actor, "isExistInTheWorld")
    if despawned == nil or stillWorld == true then
        -- If the engine despawn leaves the actor registered in-world, force a
        -- direct world removal so stale actor refs stop shadowing delete/remove.
        protectedCall(actor, "removeFromSquare")
        protectedCall(actor, "removeFromWorld")
    end

    if modData then
        modData.LWN_CreateHookPending = false
        modData.LWN_LastCleanupHour = getGameTime() and getGameTime():getWorldAgeHours() or nil
        modData.LWN_LastCleanupWorld = stillWorld
        modData.LWN_NpcId = nil
    end
end

local function hasRuntimeCore(actor)
    if not actor then return false end

    local okBody = protectedCall(actor, "getBodyDamage") ~= nil
    local okStats = protectedCall(actor, "getStats") ~= nil
    local okInventory = protectedCall(actor, "getInventory") ~= nil

    return okBody and okStats and okInventory
end

local function isSquareSpawnable(square)
    if not square then return false end

    local solidFloor = protectedCall(square, "isSolidFloor")
    if solidFloor == false then return false end

    local isFree = protectedCall(square, "isFree", false)
    if isFree == false then return false end

    local movingObjects = protectedCall(square, "getMovingObjects")
    if movingObjects and movingObjects.size then
        for i = 0, movingObjects:size() - 1 do
            local obj = movingObjects:get(i)
            if obj and instanceof then
                if instanceof(obj, "IsoZombie") or instanceof(obj, "IsoPlayer") or instanceof(obj, "IsoSurvivor") then
                    return false
                end
            end
        end
    end

    return true
end

local function addCandidate(candidates, square, source, player, anchorX, anchorY)
    if not isSquareSpawnable(square) then return end

    local sx = protectedCall(square, "getX") or 0
    local sy = protectedCall(square, "getY") or 0
    local score = dist2(anchorX, anchorY, sx, sy)

    if player then
        local pd2 = dist2(player:getX(), player:getY(), sx, sy)
        if pd2 < 4 then
            return
        end
        score = score + math.abs(pd2 - 16)
    end

    candidates[#candidates + 1] = {
        square = square,
        source = source,
        score = score,
    }
end

local function chooseBestCandidate(candidates)
    local best = nil
    for _, candidate in ipairs(candidates) do
        if not best or candidate.score < best.score then
            best = candidate
        end
    end
    return best
end

local function createDescriptor(record)
    local female = record.identity and record.identity.female == true

    if SurvivorFactory and SurvivorFactory.CreateSurvivor and SurvivorType and SurvivorType.Neutral ~= nil then
        local ok, desc = pcall(function()
            return SurvivorFactory.CreateSurvivor(SurvivorType.Neutral, female)
        end)
        if ok and desc then
            return desc, "neutral"
        end
    end

    if SurvivorFactory and SurvivorFactory.CreateSurvivor then
        local ok, desc = pcall(function()
            return SurvivorFactory.CreateSurvivor(nil, female)
        end)
        if ok and desc then
            return desc, "typed_nil"
        end
    end

    if SurvivorFactory and SurvivorFactory.CreateSurvivor then
        local ok, desc = pcall(function()
            return SurvivorFactory.CreateSurvivor()
        end)
        if ok and desc then
            callIf(desc, "setFemale", female)
            return desc, "default"
        end
    end

    return nil, "unavailable"
end

local function applyDescriptorAppearance(record, desc, descriptorMode)
    local appearance = record.appearance or {}
    local outfit = appearance.outfit
    if not outfit or outfit == "" then
        return
    end

    local ok, err = pcall(function()
        desc:dressInNamedOutfit(outfit)
    end)
    if not ok then
        logInfo("dressInNamedOutfit failed", record, nil, {
            source = "buildDescriptor",
            detail = outfit,
            thrown = err,
            descriptorMode = descriptorMode,
        })
    end
end

local function setBaselineHumanVisual(record, actor, desc)
    if not actor then return end

    local female = record.identity and record.identity.female == true
    protectedCall(actor, "setFemale", female)
    protectedCall(actor, "setFemaleEtc", female)

    local visual = protectedCall(actor, "getHumanVisual")
    if visual then
        local skin = protectedCall(visual, "getSkinTexture") or protectedCall(visual, "getSkinTextureName")
        if not skin or tostring(skin) == "" then
            protectedCall(visual, "setSkinTextureIndex", 0)
        end

        -- BanditsCreator explicitly flips gender and seeds a baseline body visual
        -- on every preview IsoPlayer. World actors need the same nudge when the
        -- descriptor path alone doesn't materialize a mesh.
        if female then
            protectedCall(visual, "removeBodyVisualFromItemType", "Base.M_Hair_Stubble")
            protectedCall(visual, "removeBodyVisualFromItemType", "Base.M_Beard_Stubble")
        else
            protectedCall(visual, "removeBodyVisualFromItemType", "Base.F_Hair_Stubble")
        end
    end

    protectedCall(actor, "onWornItemsChanged")
    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
    refreshModelManager(actor, "baseline_visual")
end

local function materializeDescriptorVisual(record, actor, descriptor, phase, options)
    if not actor then
        return nil, {
            phase = phase,
            descriptorApplied = false,
            dressup = false,
            initSpriteParts = false,
            female = false,
        }
    end

    local desc = descriptor or protectedCall(actor, "getDescriptor")
    local female = record
        and record.identity
        and record.identity.female == true
        or (desc and protectedCall(desc, "isFemale") == true)
        or false
    local detail = {
        phase = phase,
        descriptorApplied = desc ~= nil,
        dressup = false,
        initSpriteParts = false,
        female = female,
    }

    protectedCall(actor, "setFemale", female)
    protectedCall(actor, "setFemaleEtc", female)

    if desc then
        callIf(desc, "setFemale", female)
        if record and record.identity then
            callIf(desc, "setForename", record.identity.firstName)
            callIf(desc, "setSurname", record.identity.lastName)
            callIf(desc, "setProfession", record.identity.profession)
        end

        protectedCall(actor, "setDescriptor", desc)

        if not options or options.dressup ~= false then
            protectedCall(actor, "Dressup", desc)
            detail.dressup = true
        end

        if not options or options.initSpriteParts ~= false then
            protectedCall(actor, "InitSpriteParts", desc)
            detail.initSpriteParts = true
        end
    end

    protectedCall(actor, "onWornItemsChanged")
    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
    refreshModelManager(actor, "descriptor_" .. safeText(phase))
    markPresentationPending(actor, phase)
    return desc, detail
end

local function resolveWearLocation(item)
    if not item then return nil end

    local bodyLocation = protectedCall(item, "getBodyLocation")
    if bodyLocation and bodyLocation ~= "" then
        if ItemBodyLocation and ItemBodyLocation.get and ResourceLocation and ResourceLocation.of and type(bodyLocation) == "string" then
            local ok, resolved = pcall(function()
                return ItemBodyLocation.get(ResourceLocation.of(bodyLocation))
            end)
            if ok and resolved then
                return resolved
            end
        end
        return bodyLocation
    end

    return protectedCall(item, "canBeEquipped")
end

local function addAndWearItem(actor, fullType)
    local inv = protectedCall(actor, "getInventory")
    if not inv then return nil end

    local item = inv:AddItem(fullType)
    if not item then return nil end

    local wearLocation = resolveWearLocation(item)
    if wearLocation and wearLocation ~= "" then
        protectedCall(actor, "setWornItem", wearLocation, item)
    end
    return item
end

local function ensureVisibleClothing(actor)
    if protectedCall(actor, "getClothingItem_Torso") and protectedCall(actor, "getClothingItem_Legs") then
        return
    end

    protectedCall(actor, "dressInRandomOutfit")

    if protectedCall(actor, "getClothingItem_Torso") and protectedCall(actor, "getClothingItem_Legs") then
        protectedCall(actor, "onWornItemsChanged")
        refreshModelManager(actor, "random_outfit")
        return
    end

    for _, fullType in ipairs(fallbackClothing) do
        addAndWearItem(actor, fullType)
    end
    protectedCall(actor, "onWornItemsChanged")
    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
    refreshModelManager(actor, "fallback_clothing")
end

local function bridgeWornItemsToItemVisuals(actor)
    local visual = protectedCall(actor, "getHumanVisual")
    local itemVisuals = protectedCall(actor, "getItemVisuals")
    local wornItems = protectedCall(actor, "getWornItems")
    local result = {
        wornItems = safeSize(wornItems),
        itemVisualsBefore = safeSize(itemVisuals),
        itemVisualsAfter = safeSize(itemVisuals),
        added = 0,
        mode = "skipped",
    }

    if not actor or not visual or not itemVisuals or not wornItems then
        result.mode = "missing_visual_containers"
        return result
    end

    if result.wornItems <= 0 then
        result.mode = "no_worn_items"
        return result
    end

    if result.itemVisualsBefore > 0 then
        result.mode = "item_visuals_present"
        return result
    end

    for i = 0, wornItems:size() - 1 do
        local wornEntry = protectedCall(wornItems, "get", i)
        local item = protectedCall(wornEntry, "getItem") or wornEntry
        local clothingItem = protectedCall(item, "getClothingItem")
        local itemVisual = nil

        if clothingItem then
            itemVisual = protectedCall(visual, "addClothingItem", itemVisuals, clothingItem)
        end

        if not itemVisual and ItemVisual and ItemVisual.new then
            local fullType = protectedCall(item, "getFullType")
            if fullType then
                itemVisual = ItemVisual.new()
                protectedCall(itemVisual, "setItemType", fullType)
                protectedCall(itemVisual, "setClothingItemName", fullType)
                protectedCall(itemVisuals, "add", itemVisual)
            end
        end

        if itemVisual then
            result.added = result.added + 1
        end
    end

    result.itemVisualsAfter = safeSize(itemVisuals)
    if result.itemVisualsAfter > result.itemVisualsBefore then
        result.mode = "rebuilt_from_worn_items"
        protectedCall(actor, "onWornItemsChanged")
        protectedCall(actor, "resetModel")
        protectedCall(actor, "resetModelNextFrame")
        refreshModelManager(actor, "item_visual_bridge")
        return result
    end

    result.mode = "no_visuals_added"
    return result
end

local function ensurePrimaryWeapon(actor, fullType)
    if not fullType then return nil end

    local inv = protectedCall(actor, "getInventory")
    if not inv then return nil end

    local item = inv:AddItem(fullType)
    if not item then return nil end

    protectedCall(actor, "setPrimaryHandItem", item)
    if protectedCall(item, "isRequiresEquippedBothHands") or protectedCall(item, "isTwoHandWeapon") then
        protectedCall(actor, "setSecondaryHandItem", item)
    end
    return item
end

local function ensureActorRegisteredInWorld(actor, square)
    if not actor or not square then return false end

    local sx = tonumber(protectedCall(square, "getX") or protectedCall(actor, "getX") or 0) or 0
    local sy = tonumber(protectedCall(square, "getY") or protectedCall(actor, "getY") or 0) or 0
    local sz = tonumber(protectedCall(square, "getZ") or protectedCall(actor, "getZ") or 0) or 0

    protectedCall(actor, "setX", sx + 0.5)
    protectedCall(actor, "setY", sy + 0.5)
    protectedCall(actor, "setZ", sz)
    protectedCall(actor, "setCurrent", square)
    protectedCall(actor, "setMovingSquare", square)
    protectedCall(actor, "setCurrentSquare", square)
    protectedCall(actor, "setSquare", square)

    if protectedCall(actor, "isExistInTheWorld") ~= true then
        protectedCall(square, "AddMovingObject", actor)
        protectedCall(actor, "addToWorld")
    end

    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setGhostMode", false)
    protectedCall(actor, "setInvisible", false)
    repairVisibleAlpha(actor, "ensureActorRegisteredInWorld")
    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
    refreshModelManager(actor, "world_registration")

    local currentSquare = protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")
    local inWorld = protectedCall(actor, "isExistInTheWorld")
    return currentSquare ~= nil and inWorld ~= false
end

function Factory.buildDescriptor(record)
    local desc, descriptorMode = createDescriptor(record)
    if not desc then
        logFailure("buildDescriptor failed: CreateSurvivor returned nil", record, nil, nil, descriptorMode, {
            source = "buildDescriptor",
            stage = "buildDescriptor.failed",
        })
        return nil, descriptorMode
    end

    callIf(desc, "setFemale", record.identity.female == true)
    callIf(desc, "setForename", record.identity.firstName)
    callIf(desc, "setSurname", record.identity.lastName)
    callIf(desc, "setProfession", record.identity.profession)

    if ProfessionFactory and ProfessionFactory.getProfession then
        local prof = ProfessionFactory.getProfession(record.identity.profession)
        if prof then
            callIf(desc, "setProfessionSkills", prof)
        end
    end

    callIf(desc, "setBravery", record.personality.bravery)
    callIf(desc, "setCompassion", record.personality.empathy)
    callIf(desc, "setLoyalty", record.personality.loyalty)
    callIf(desc, "setAggressiveness", record.personality.greed)
    callIf(desc, "setFriendliness", record.personality.sociability)
    callIf(desc, "setTemper", record.personality.impulsiveness)
    callIf(desc, "setLoner", 1.0 - record.personality.sociability)

    applyDescriptorAppearance(record, desc, descriptorMode)
    stageTrace("ActorFactory", "buildDescriptor.ready", record, nil, desc, {
        source = "buildDescriptor",
        descriptorMode = descriptorMode,
        detail = descriptorMode,
    })
    return desc, descriptorMode
end

function Factory.findSpawnSquare(record, player)
    local cell = getCell()
    if not cell then return nil, "no_cell" end

    local ax = math.floor(record.anchor.x or 0)
    local ay = math.floor(record.anchor.y or 0)
    local az = math.floor(record.anchor.z or 0)
    local anchorSquare = cell:getGridSquare(ax, ay, az)
    local candidates = {}

    -- Prefer tiles near the canonical anchor, but avoid popping directly on top of
    -- the player or onto occupied/air squares. This keeps embodiment visible while
    -- reducing collision-driven runtime faults.
    addCandidate(candidates, anchorSquare, "anchor", player, ax, ay)

    if anchorSquare and AdjacentFreeTileFinder and AdjacentFreeTileFinder.Find and player then
        addCandidate(candidates, AdjacentFreeTileFinder.Find(anchorSquare, player), "anchor_adjacent", player, ax, ay)
    end

    for radius = 1, 3 do
        for dy = -radius, radius do
            for dx = -radius, radius do
                if math.max(math.abs(dx), math.abs(dy)) == radius then
                    local square = cell:getGridSquare(ax + dx, ay + dy, az)
                    addCandidate(candidates, square, string.format("anchor_ring_%d", radius), player, ax, ay)
                end
            end
        end
    end

    if player then
        local px = math.floor(player:getX())
        local py = math.floor(player:getY())
        local pz = math.floor(player:getZ())

        for radius = 2, 5 do
            for dy = -radius, radius do
                for dx = -radius, radius do
                    if math.max(math.abs(dx), math.abs(dy)) == radius then
                        local square = cell:getGridSquare(px + dx, py + dy, pz)
                        addCandidate(candidates, square, string.format("player_ring_%d", radius), player, ax, ay)
                    end
                end
            end
        end
    end

    local best = chooseBestCandidate(candidates)
    if not best then
        return nil, "no_spawn_square"
    end

    return best.square, best.source
end

function Factory.hasRuntimeCore(actor)
    return hasRuntimeCore(actor)
end

function Factory.isManagedActor(obj)
    return isManagedActor(obj)
end

function Factory.getNpcIdFromActor(actor)
    return getNpcIdFromActor(actor)
end

function Factory.getLastFailure()
    return Factory._lastFailure
end

function Factory.isDeathLikeActor(actor)
    local state = actorPresentationState(actor)
    return state and state.deathLike == true or false
end

function Factory.getPresentationState(actor)
    return actorPresentationState(actor)
end

function Factory.presentationStateSummary(actor)
    return presentationStateSummary(actor)
end

function Factory.debugStage(moduleName, stage, record, actor, descriptor, extra)
    stageTrace(moduleName, stage, record, actor, descriptor, extra)
end

function Factory.dumpLastFailure()
    local failure = Factory._lastFailure
    if not failure then
        print("[LWN][ActorFactory] last failure :: none")
        return
    end

    print("[LWN][ActorFactory] last failure reason :: " .. safeText(failure.reason))
    print("[LWN][ActorFactory] last failure record :: " .. safeText(failure.record))
    print("[LWN][ActorFactory] last failure actor :: " .. safeText(failure.actor))
    print("[LWN][ActorFactory] last failure descriptor :: " .. safeText(failure.descriptor) .. " | " .. safeText(failure.extra))
end

function Factory.attachPendingRecord(actor)
    if not actor then return nil end

    local record = Factory._pendingRecord
    if not record then return nil end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_NpcId = record.id
    end
    return record
end

function Factory.rejectActor(actor, reason, npcId, record, descriptor, descriptorMode, extra)
    local failureRecord = record
    if not failureRecord and Store and Store.getNPC and npcId then
        failureRecord = Store.getNPC(npcId)
    end

    local failureExtra = extra or {}
    failureExtra.npcId = npcId
    logFailure(reason, failureRecord, actor, descriptor, descriptorMode, failureExtra)
    safeCleanupActor(actor)
end

function Factory.cleanupActor(actor)
    local npcId = getNpcIdFromActor(actor)
    stageTrace("ActorFactory", "cleanupActor.start", nil, actor, nil, {
        source = "cleanupActor",
        npcId = npcId,
        detail = presentationStateSummary(actor),
    })
    safeCleanupActor(actor)
    stageTrace("ActorFactory", "cleanupActor.complete", nil, actor, nil, {
        source = "cleanupActor",
        npcId = npcId,
        detail = presentationStateSummary(actor),
    })
end

local refreshActorPresentation

function Factory.settleEmbodiedPresentation(record, actor, descriptor, source)
    local desc, detail = materializeDescriptorVisual(record, actor, descriptor, source or "settle", {
        dressup = false,
        initSpriteParts = true,
    })
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_PresentationPending = false
        modData.LWN_PresentationSettledBy = source
        modData.LWN_PresentationSettledAt = getGameTime() and getGameTime():getWorldAgeHours() or nil
    end

    stageTrace("ActorFactory", "settleEmbodiedPresentation.ready", record, actor, desc, {
        source = source or "settleEmbodiedPresentation",
        detail = string.format(
            "phase=%s descriptorApplied=%s dressup=%s initSpriteParts=%s female=%s",
            safeText(detail.phase),
            safeText(detail.descriptorApplied),
            safeText(detail.dressup),
            safeText(detail.initSpriteParts),
            safeText(detail.female)
        ),
    })
end

function Factory.ensureActorInWorld(actor, square)
    return ensureActorRegisteredInWorld(actor, square)
end

function Factory.repairVisibleAlpha(actor, reason)
    return repairVisibleAlpha(actor, reason)
end

function Factory.refreshEmbodiedPresentation(record, actor, descriptor)
    local activeDescriptor, baseline = materializeDescriptorVisual(record or {}, actor, descriptor, "refresh_pre_clothing", {
        dressup = true,
        initSpriteParts = true,
    })
    stageTrace("ActorFactory", "refreshEmbodiedPresentation.descriptor_bound", record, actor, activeDescriptor, {
        source = "refreshEmbodiedPresentation",
        detail = string.format(
            "phase=%s descriptorApplied=%s dressup=%s initSpriteParts=%s female=%s",
            safeText(baseline.phase),
            safeText(baseline.descriptorApplied),
            safeText(baseline.dressup),
            safeText(baseline.initSpriteParts),
            safeText(baseline.female)
        ),
    })
    setBaselineHumanVisual(record or {}, actor, activeDescriptor)
    ensureVisibleClothing(actor)
    local finalizedDescriptor, finalized = materializeDescriptorVisual(record or {}, actor, activeDescriptor, "refresh_post_clothing", {
        dressup = false,
        initSpriteParts = true,
    })
    stageTrace("ActorFactory", "refreshEmbodiedPresentation.materialized", record, actor, finalizedDescriptor, {
        source = "refreshEmbodiedPresentation",
        detail = string.format(
            "phase=%s descriptorApplied=%s dressup=%s initSpriteParts=%s female=%s",
            safeText(finalized.phase),
            safeText(finalized.descriptorApplied),
            safeText(finalized.dressup),
            safeText(finalized.initSpriteParts),
            safeText(finalized.female)
        ),
    })
    local bridge = bridgeWornItemsToItemVisuals(actor)
    stageTrace("ActorFactory", "refreshEmbodiedPresentation.item_visual_bridge", record, actor, finalizedDescriptor, {
        source = "refreshEmbodiedPresentation",
        detail = string.format(
            "mode=%s wornItems=%d itemVisualsBefore=%d itemVisualsAfter=%d added=%d",
            safeText(bridge.mode),
            tonumber(bridge.wornItems or 0) or 0,
            tonumber(bridge.itemVisualsBefore or 0) or 0,
            tonumber(bridge.itemVisualsAfter or 0) or 0,
            tonumber(bridge.added or 0) or 0
        ),
    })
    refreshActorPresentation(actor)
    stageTrace("ActorFactory", "refreshEmbodiedPresentation.ready", record, actor, finalizedDescriptor, {
        source = "refreshEmbodiedPresentation",
    })
end

refreshActorPresentation = function(actor)
    if not actor then return end

    protectedCall(actor, "setGhostMode", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setNPC", true)
    protectedCall(actor, "setIsNPC", true)
    protectedCall(actor, "setVisibleToNPCs", true)
    repairVisibleAlpha(actor, "refreshActorPresentation")

    local inv = protectedCall(actor, "getInventory")
    if inv then
        protectedCall(inv, "setDrawDirty", true)
    end

    protectedCall(actor, "onWornItemsChanged")
    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
    refreshModelManager(actor, "presentation")
end

function Factory.applyTraits(record, actor)
    for _, traitId in ipairs(record.identity.traitIds or {}) do
        local traits = protectedCall(actor, "getTraits")
        if traits and traits.add then
            pcall(function()
                traits:add(traitId)
            end)
        end
    end
end

function Factory.applyLoadout(record, actor, descriptor)
    ensureVisibleClothing(actor)

    local primaryWeapon = record.inventory
        and record.inventory.equipment
        and record.inventory.equipment.primaryWeapon
        or nil

    ensurePrimaryWeapon(actor, primaryWeapon)
    local desc, detail = materializeDescriptorVisual(record or {}, actor, descriptor, "apply_loadout", {
        dressup = false,
        initSpriteParts = true,
    })
    stageTrace("ActorFactory", "applyLoadout.materialized", record, actor, desc, {
        source = "applyLoadout",
        detail = string.format(
            "phase=%s descriptorApplied=%s dressup=%s initSpriteParts=%s female=%s",
            safeText(detail.phase),
            safeText(detail.descriptorApplied),
            safeText(detail.dressup),
            safeText(detail.initSpriteParts),
            safeText(detail.female)
        ),
    })
    refreshActorPresentation(actor)
end

function Factory.createActor(record, player)
    local desc, descriptorMode = Factory.buildDescriptor(record)
    if not desc then
        return nil
    end

    stageTrace("ActorFactory", "createActor.start", record, nil, desc, {
        source = "createActor",
        descriptorMode = descriptorMode,
    })

    local cell = getCell()
    if not cell then
        logFailure("createActor failed: getCell() returned nil", record, nil, desc, descriptorMode, {
            source = "createActor",
            stage = "createActor.no_cell",
        })
        return nil
    end

    local square, spawnSource = Factory.findSpawnSquare(record, player)
    if not square then
        logFailure("createActor skipped: no spawn square", record, nil, desc, descriptorMode, {
            source = "createActor",
            stage = "createActor.no_spawn_square",
            spawnSource = spawnSource,
            detail = coordSummary(record.anchor.x, record.anchor.y, record.anchor.z),
        })
        return nil
    end

    stageTrace("ActorFactory", "createActor.spawn_selected", record, nil, desc, {
        source = "createActor",
        square = square,
        spawnSource = spawnSource,
        descriptorMode = descriptorMode,
    })

    local x = math.floor(protectedCall(square, "getX") or record.anchor.x or 0)
    local y = math.floor(protectedCall(square, "getY") or record.anchor.y or 0)
    local z = math.floor(protectedCall(square, "getZ") or record.anchor.z or 0)

    Factory._pendingRecord = record
    local ok, actorOrErr = pcall(function()
        -- Build 42 does not expose a complete first-party human NPC framework yet,
        -- so embodied LWN NPCs are created as NPC-flagged IsoPlayer instances with
        -- canonical state still living in ModData-backed records.
        return IsoPlayer.new(cell, desc, x, y, z)
    end)
    Factory._pendingRecord = nil

    if not ok then
        logFailure("createActor failed: IsoPlayer.new threw", record, nil, desc, descriptorMode, {
            source = "createActor",
            stage = "createActor.alloc_throw",
            thrown = actorOrErr,
            square = square,
            spawnSource = spawnSource,
        })
        return nil
    end

    local actor = actorOrErr
    if not actor then
        logFailure("createActor failed: IsoPlayer.new returned nil", record, nil, desc, descriptorMode, {
            source = "createActor",
            stage = "createActor.alloc_nil",
            square = square,
            spawnSource = spawnSource,
        })
        return nil
    end

    stageTrace("ActorFactory", "createActor.actor_allocated", record, actor, desc, {
        source = "createActor",
        square = square,
        spawnSource = spawnSource,
        descriptorMode = descriptorMode,
    })

    protectedCall(actor, "setDescriptor", desc)
    protectedCall(actor, "setNPC", true)
    protectedCall(actor, "setIsNPC", true)
    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setGhostMode", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setVisibleToNPCs", true)
    protectedCall(actor, "setFemale", record.identity and record.identity.female == true)
    protectedCall(actor, "setFemaleEtc", record.identity and record.identity.female == true)
    protectedCall(actor, "setForname", record.identity.firstName)
    protectedCall(actor, "setSurname", record.identity.lastName)

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_NpcId = record.id
        modData.LWN_ActorKind = "IsoPlayer"
        modData.LWN_SpawnSource = spawnSource
        modData.LWN_CreateHookPending = true
        modData.LWN_CreateHookExpected = "OnCreateLivingCharacter"
        modData.LWN_LastCreateHook = nil
        modData.LWN_LastCreateHookAt = nil
        modData.LWN_PostCreateApplied = false
        modData.LWN_PostCreateAppliedBy = nil
        modData.LWN_PostCreateAppliedAt = nil
    end

    if not ensureActorRegisteredInWorld(actor, square) then
        Factory.rejectActor(actor, "createActor rejected actor not registered in world", record.id, record, desc, descriptorMode, {
            source = "createActor",
            stage = "createActor.world_rejected",
            square = square,
            spawnSource = spawnSource,
        })
        return nil
    end

    stageTrace("ActorFactory", "createActor.world_registered", record, actor, desc, {
        source = "createActor",
        square = square,
        spawnSource = spawnSource,
        descriptorMode = descriptorMode,
    })

    if not hasRuntimeCore(actor) then
        Factory.rejectActor(actor, "createActor rejected invalid runtime actor", record.id, record, desc, descriptorMode, {
            source = "createActor",
            stage = "createActor.runtime_rejected",
            square = square,
            spawnSource = spawnSource,
        })
        return nil
    end

    Factory.applyTraits(record, actor)
    Factory.refreshEmbodiedPresentation(record, actor, desc)
    Factory.applyLoadout(record, actor, desc)
    protectedCall(actor, "setHealth", record.stats and record.stats.health or 100)
    refreshActorPresentation(actor)
    stageTrace("ActorFactory", "createActor.presentation_ready", record, actor, desc, {
        source = "createActor",
        square = square,
        spawnSource = spawnSource,
        descriptorMode = descriptorMode,
    })

    logInfo("created embodied npc", record, actor, {
        source = "createActor",
        square = square,
        spawnSource = spawnSource,
        detail = descriptorMode,
    })

    return actor
end
