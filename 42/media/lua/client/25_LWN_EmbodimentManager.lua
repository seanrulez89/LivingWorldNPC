LWN = LWN or {}
LWN.EmbodimentManager = LWN.EmbodimentManager or {}

local Embody = LWN.EmbodimentManager
local Store = LWN.PopulationStore

Embody._actors = Embody._actors or {}

local function dist2(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function Embody._activationRadiusFor(record)
    if record.companion.recruited then
        return LWN.Config.Embodiment.CompanionDespawnRadiusTiles
    end
    return LWN.Config.Embodiment.RadiusTiles
end

function Embody.tryEmbody(record, player)
    if record.embodiment.state ~= "eligible" then return nil end
    if Store.countEmbodied() >= LWN.Config.Population.MaxEmbodied then return nil end

    local radius = LWN.Config.Embodiment.RadiusTiles
    local d2 = dist2(player:getX(), player:getY(), record.anchor.x, record.anchor.y)
    if d2 > radius * radius then return nil end

        local actor = LWN.ActorFactory.createActor(record)
    if actor then
        LWN.ActorSync.pushRecordToActor(record, actor)
        record.embodiment.state = "embodied"
        record.embodiment.actorId = record.id
        record.embodiment.lastSeenHour = getGameTime():getWorldAgeHours()
        record.embodiment.missingTicks = 0
        Embody.registerActor(record, actor)
        if LWN.EncounterDirector and LWN.EncounterDirector.notifyEmbodied then
            LWN.EncounterDirector.notifyEmbodied(record)
        end
        return actor
    end

    -- Avoid spamming failed instantiation every tick.
    record.embodiment.state = "hidden"
    record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + 0.05
    return nil
end

function Embody.tryDespawn(record, actor, player)
    if record.embodiment.state ~= "embodied" or not actor then return false end

    local radius = LWN.Config.Embodiment.DespawnRadiusTiles
    if record.companion.recruited then
        radius = LWN.Config.Embodiment.CompanionDespawnRadiusTiles
    end

    local grace = record.embodiment.graceUntilHour or 0
    if getGameTime():getWorldAgeHours() < grace then return false end

    local d2 = dist2(player:getX(), player:getY(), actor:getX(), actor:getY())
    if d2 < radius * radius then return false end

    LWN.ActorSync.pullActorToRecord(record, actor)
    Store.setEmbodiedMeta(record.id, {
        state = "embodied",
        x = math.floor(actor:getX()),
        y = math.floor(actor:getY()),
        z = math.floor(actor:getZ()),
        lastSeenHour = getGameTime() and getGameTime():getWorldAgeHours() or 0,
    })
    if actor.StopAllActionQueue then
        actor:StopAllActionQueue()
    end
    if actor.Despawn then
        actor:Despawn()
    end

    record.embodiment.state = "hidden"
    record.embodiment.actorId = nil
    record.embodiment.missingTicks = 0
    record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + ((LWN.Config.Population and LWN.Config.Population.EncounterCooldownHours) or 2.0)
    Embody.unregisterActor(record)
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
        x = math.floor(actor:getX()),
        y = math.floor(actor:getY()),
        z = math.floor(actor:getZ()),
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