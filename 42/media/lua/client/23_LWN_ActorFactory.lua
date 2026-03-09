LWN = LWN or {}
LWN.ActorFactory = LWN.ActorFactory or {}

local Factory = LWN.ActorFactory

local function callIf(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if fn then
        return fn(obj, ...)
    end
    return nil
end

local function safeCleanupActor(actor)
    if not actor then return end
    if actor.StopAllActionQueue then
        actor:StopAllActionQueue()
    end
    if actor.Despawn then
        actor:Despawn()
        return
    end
    if actor.removeFromSquare then
        actor:removeFromSquare()
    end
    if actor.removeFromWorld then
        actor:removeFromWorld()
    end
end

local function hasRuntimeCore(actor)
    if not actor then return false end

    local okBody = true
    if actor.getBodyDamage then
        okBody = actor:getBodyDamage() ~= nil
    end

    local okStats = true
    if actor.getStats then
        okStats = actor:getStats() ~= nil
    end

    local okInventory = true
    if actor.getInventory then
        okInventory = actor:getInventory() ~= nil
    end

    return okBody and okStats and okInventory
end

function Factory.buildDescriptor(record)
    local desc = SurvivorFactory.CreateSurvivor()

    callIf(desc, "setFemale", record.identity.female)
    callIf(desc, "setForename", record.identity.firstName)
    callIf(desc, "setSurname", record.identity.lastName)

    -- Build 42 surfaces differ by branch; guard optional descriptor methods.
    callIf(desc, "setProfession", record.identity.profession)

    if ProfessionFactory and ProfessionFactory.getProfession then
        local prof = ProfessionFactory.getProfession(record.identity.profession)
        if prof then
            callIf(desc, "setProfessionSkills", prof)
        end
    end

    -- Descriptor personality hints; all optional per runtime exposure.
    callIf(desc, "setBravery", record.personality.bravery)
    callIf(desc, "setCompassion", record.personality.empathy)
    callIf(desc, "setLoyalty", record.personality.loyalty)
    callIf(desc, "setAggressiveness", record.personality.greed)
    callIf(desc, "setFriendliness", record.personality.sociability)
    callIf(desc, "setTemper", record.personality.impulsiveness)
    callIf(desc, "setLoner", 1.0 - record.personality.sociability)

    return desc
end

function Factory.applyTraits(record, actor)
    for _, traitId in ipairs(record.identity.traitIds or {}) do
        -- Trait application is kept abstract here.
        -- For vanilla traits, the descriptor / profession setup usually handles the visible effects.
        -- Custom trait registration should be done in a registry bootstrap before world load.
    end
end

function Factory.applyLoadout(record, actor)
    local inv = actor:getInventory()
    if not inv then return end

    if record.inventory.equipment.primaryWeapon then
        local item = inv:AddItem(record.inventory.equipment.primaryWeapon)
        if item then actor:setPrimaryHandItem(item) end
    end
end

function Factory.createActor(record)
    local desc = Factory.buildDescriptor(record)
    local cell = getCell()
    local actor = SurvivorFactory.InstansiateInCell(desc, cell, record.anchor.x, record.anchor.y, record.anchor.z)

    if not actor then
        print("[LWN][ActorFactory] createActor failed: InstansiateInCell returned nil for " .. tostring(record.id))
        return nil
    end

    if not hasRuntimeCore(actor) then
        print("[LWN][ActorFactory] createActor rejected invalid runtime actor for " .. tostring(record.id))
        safeCleanupActor(actor)
        return nil
    end

    actor:getModData().LWN_NpcId = record.id
    Factory.applyTraits(record, actor)
    Factory.applyLoadout(record, actor)

    return actor
end