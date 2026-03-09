LWN = LWN or {}
LWN.ActorFactory = LWN.ActorFactory or {}

local Factory = LWN.ActorFactory
local Store = LWN.PopulationStore

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

local function coordSummary(x, y, z)
    return safeNumber(x) .. "," .. safeNumber(y) .. "," .. safeNumber(z)
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
    appendPart(parts, "traits", #(identity.traitIds or {}))
    appendPart(parts, "hunger", safeNumber(stats.hunger))
    appendPart(parts, "thirst", safeNumber(stats.thirst))
    appendPart(parts, "fatigue", safeNumber(stats.fatigue))
    return table.concat(parts, " | ")
end

local function actorSummary(actor)
    if not actor then
        return "actor=nil"
    end

    local modData = protectedCall(actor, "getModData")
    local square = protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")
    local parts = {}
    appendPart(parts, "object", protectedCall(actor, "getObjectName"))
    appendPart(parts, "npcId", modData and modData.LWN_NpcId or nil)
    appendPart(parts, "body", protectedCall(actor, "getBodyDamage") ~= nil)
    appendPart(parts, "stats", protectedCall(actor, "getStats") ~= nil)
    appendPart(parts, "inventory", protectedCall(actor, "getInventory") ~= nil)
    appendPart(parts, "pos", coordSummary(protectedCall(actor, "getX"), protectedCall(actor, "getY"), protectedCall(actor, "getZ")))
    appendPart(parts, "destroyed", protectedCall(actor, "isDestroyed"))
    appendPart(parts, "world", protectedCall(actor, "isExistInTheWorld"))
    appendPart(parts, "square", squareSummary(square))
    return table.concat(parts, " | ")
end

local function extraSummary(extra)
    if not extra then return "extra=nil" end

    local parts = {}
    appendPart(parts, "source", extra.source)
    appendPart(parts, "detail", extra.detail)
    appendPart(parts, "thrown", extra.thrown)
    if extra.square then
        appendPart(parts, "targetSquare", squareSummary(extra.square))
    end
    return table.concat(parts, " | ")
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

    print("[LWN][ActorFactory] " .. safeText(reason) .. " for " .. safeText(snapshot.npcId))
    print("[LWN][ActorFactory] failure record :: " .. snapshot.record)
    print("[LWN][ActorFactory] failure actor :: " .. snapshot.actor)
    print("[LWN][ActorFactory] failure descriptor :: hour=" .. safeNumber(snapshot.worldAgeHours) .. " | " .. snapshot.descriptor .. " | " .. snapshot.extra)
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
            return desc, "neutral"
        end
    end

    if SurvivorFactory and SurvivorFactory.CreateSurvivor then
        local ok, desc = pcall(function()
            return SurvivorFactory.CreateSurvivor()
        end)
        if ok and desc then
            callIf(desc, "setFemale", record.identity.female == true)
            return desc, "default"
        end
    end

    return nil, "unavailable"
end

function Factory.buildDescriptor(record)
    local desc, descriptorMode = createDescriptor(record)
    if not desc then
        logFailure("buildDescriptor failed: CreateSurvivor returned nil", record, nil, nil, descriptorMode, { source = "buildDescriptor" })
        return nil, descriptorMode
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

    return desc, descriptorMode
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
    local desc, descriptorMode = Factory.buildDescriptor(record)
    if not desc then
        return nil
    end

    local cell = getCell()
    if not cell then
        logFailure("createActor failed: getCell() returned nil", record, nil, desc, descriptorMode, { source = "createActor" })
        return nil
    end

    local x = math.floor(record.anchor.x or 0)
    local y = math.floor(record.anchor.y or 0)
    local z = math.floor(record.anchor.z or 0)
    local square = cell:getGridSquare(x, y, z)
    if not square then
        logFailure("createActor skipped: target square missing", record, nil, desc, descriptorMode, {
            source = "createActor",
            detail = coordSummary(x, y, z),
        })
        return nil
    end

    Factory._pendingRecord = record
    local ok, actorOrErr = pcall(function()
        return SurvivorFactory.InstansiateInCell(desc, cell, x, y, z)
    end)
    Factory._pendingRecord = nil

    if not ok then
        logFailure("createActor failed: InstansiateInCell threw", record, nil, desc, descriptorMode, {
            source = "createActor",
            thrown = actorOrErr,
            square = square,
        })
        return nil
    end

    local actor = actorOrErr
    if not actor then
        logFailure("createActor failed: InstansiateInCell returned nil", record, nil, desc, descriptorMode, {
            source = "createActor",
            square = square,
        })
        return nil
    end

    if not hasRuntimeCore(actor) then
        Factory.rejectActor(actor, "createActor rejected invalid runtime actor", record.id, record, desc, descriptorMode, {
            source = "createActor",
            square = square,
        })
        return nil
    end

    actor:getModData().LWN_NpcId = record.id
    Factory.applyTraits(record, actor)
    Factory.applyLoadout(record, actor)

    return actor
end
