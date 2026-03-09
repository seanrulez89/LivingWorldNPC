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

local function safeCleanupActor(actor)
    if not actor then return end
    protectedCall(actor, "setDestroyed", true)
    protectedCall(actor, "StopAllActionQueue")
    protectedCall(actor, "Despawn")
    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")
    protectedCall(actor, "setCurrent", nil)
    protectedCall(actor, "setMovingSquare", nil)
end

local function hasRuntimeCore(actor)
    if not actor then return false end

    local okBody = protectedCall(actor, "getBodyDamage") ~= nil
    local okStats = protectedCall(actor, "getStats") ~= nil
    local okInventory = protectedCall(actor, "getInventory") ~= nil

    return okBody and okStats and okInventory
end

local function createDescriptor(record)
    if SurvivorFactory and SurvivorFactory.CreateSurvivor and SurvivorType and SurvivorType.Neutral ~= nil then
        local ok, desc = pcall(function()
            return SurvivorFactory.CreateSurvivor(SurvivorType.Neutral, record.identity.female == true)
        end)
        if ok and desc then
            return desc
        end
    end

    if SurvivorFactory and SurvivorFactory.CreateSurvivor then
        local ok, desc = pcall(function()
            return SurvivorFactory.CreateSurvivor()
        end)
        if ok and desc then
            callIf(desc, "setFemale", record.identity.female == true)
            return desc
        end
    end

    return nil
end

function Factory.buildDescriptor(record)
    local desc = createDescriptor(record)
    if not desc then
        print("[LWN][ActorFactory] buildDescriptor failed: CreateSurvivor returned nil for " .. tostring(record.id))
        return nil
    end

    callIf(desc, "setFemale", record.identity.female == true)
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

function Factory.hasRuntimeCore(actor)
    return hasRuntimeCore(actor)
end

function Factory.attachPendingRecord(survivor)
    if not survivor then return nil end

    local record = Factory._pendingRecord
    if not record then return nil end

    local modData = protectedCall(survivor, "getModData")
    if modData then
        modData.LWN_NpcId = record.id
    end
    return record
end

function Factory.rejectActor(actor, reason, npcId)
    print("[LWN][ActorFactory] " .. tostring(reason) .. " for " .. tostring(npcId))
    safeCleanupActor(actor)
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
    if not desc then
        return nil
    end

    local cell = getCell()
    if not cell then
        print("[LWN][ActorFactory] createActor failed: getCell() returned nil for " .. tostring(record.id))
        return nil
    end

    local x = math.floor(record.anchor.x or 0)
    local y = math.floor(record.anchor.y or 0)
    local z = math.floor(record.anchor.z or 0)
    local square = cell:getGridSquare(x, y, z)
    if not square then
        print("[LWN][ActorFactory] createActor skipped: target square missing for " .. tostring(record.id))
        return nil
    end

    Factory._pendingRecord = record
    local ok, actorOrErr = pcall(function()
        return SurvivorFactory.InstansiateInCell(desc, cell, x, y, z)
    end)
    Factory._pendingRecord = nil

    if not ok then
        print("[LWN][ActorFactory] createActor failed: InstansiateInCell threw for " .. tostring(record.id) .. " :: " .. tostring(actorOrErr))
        return nil
    end

    local actor = actorOrErr
    if not actor then
        print("[LWN][ActorFactory] createActor failed: InstansiateInCell returned nil for " .. tostring(record.id))
        return nil
    end

    if not hasRuntimeCore(actor) then
        Factory.rejectActor(actor, "createActor rejected invalid runtime actor", record.id)
        return nil
    end

    actor:getModData().LWN_NpcId = record.id
    Factory.applyTraits(record, actor)
    Factory.applyLoadout(record, actor)

    return actor
end
