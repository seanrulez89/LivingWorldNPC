LWN = LWN or {}
LWN.EmbodimentManager = LWN.EmbodimentManager or {}

local Embody = LWN.EmbodimentManager
local Store = LWN.PopulationStore

Embody._actors = Embody._actors or {}

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
    print(string.format("[LWN][Embodiment] rearmed hidden npc %s", tostring(record.id)))
    return true
end

function Embody.tryEmbody(record, player)
    if record.embodiment.state ~= "eligible" then
        setLastFailure(record, "not_eligible", tostring(record.embodiment.state))
        return nil
    end
    if Store.countEmbodied() >= LWN.Config.Population.MaxEmbodied then
        setLastFailure(record, "max_embodied", tostring(Store.countEmbodied()))
        return nil
    end

    local radius = Embody._activationRadiusFor(record)
    local d2 = dist2(player:getX(), player:getY(), record.anchor.x, record.anchor.y)
    if d2 > radius * radius then
        setLastFailure(record, "out_of_range", string.format("%.2f", math.sqrt(d2)))
        return nil
    end

    local actor = LWN.ActorFactory.createActor(record, player)
    if actor then
        local ok, syncErr = pcall(LWN.ActorSync.pushRecordToActor, record, actor)
        if not ok then
            print(string.format("[LWN][Embodiment] initial sync failed for %s :: %s", tostring(record.id), tostring(syncErr)))
            if LWN.ActorFactory and LWN.ActorFactory.rejectActor then
                LWN.ActorFactory.rejectActor(actor, "tryEmbody failed during initial sync", record.id, record, nil, nil, {
                    source = "tryEmbody",
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
            return nil
        end

        record.embodiment.state = "embodied"
        record.embodiment.actorId = record.id
        record.embodiment.lastSeenHour = getGameTime():getWorldAgeHours()
        record.embodiment.missingTicks = 0
        record.embodiment.lastFailureReason = nil
        record.embodiment.lastFailureDetail = nil
        Embody.touchGrace(record)
        Embody.registerActor(record, actor)
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

    LWN.ActorSync.pullActorToRecord(record, actor)
    Store.setEmbodiedMeta(record.id, {
        state = "embodied",
        x = math.floor(protectedCall(actor, "getX") or record.anchor.x or 0),
        y = math.floor(protectedCall(actor, "getY") or record.anchor.y or 0),
        z = math.floor(protectedCall(actor, "getZ") or record.anchor.z or 0),
        lastSeenHour = getGameTime() and getGameTime():getWorldAgeHours() or 0,
    })
    if LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
        LWN.ActorFactory.cleanupActor(actor)
    else
        protectedCall(actor, "StopAllActionQueue")
        protectedCall(actor, "removeFromSquare")
        protectedCall(actor, "removeFromWorld")
    end

    record.embodiment.state = "hidden"
    record.embodiment.actorId = nil
    record.embodiment.missingTicks = 0
    record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + autoRearmCooldownHours(record)
    Embody.unregisterActor(record)
    print(string.format("[LWN][Embodiment] despawned %s", tostring(record.id)))
    return true
end

function Embody.touchGrace(record)
    record.embodiment.graceUntilHour = getGameTime():getWorldAgeHours() + LWN.Config.Embodiment.GraceHours
end

function Embody.registerActor(record, actor)
    if not record or not actor then return end
    Embody._actors[record.id] = actor
    Store.setEmbodiedMeta(record.id, {
        state = record.embodiment.state,
        x = math.floor(protectedCall(actor, "getX") or record.anchor.x or 0),
        y = math.floor(protectedCall(actor, "getY") or record.anchor.y or 0),
        z = math.floor(protectedCall(actor, "getZ") or record.anchor.z or 0),
        lastSeenHour = getGameTime() and getGameTime():getWorldAgeHours() or 0,
    })
end

function Embody.getActor(record)
    if not record then return nil end
    return Embody._actors[record.id]
end

function Embody.unregisterActor(record)
    if not record then return end
    Embody._actors[record.id] = nil
    Store.setEmbodiedMeta(record.id, nil)
end
