LWN = LWN or {}
LWN.ActorFactory = LWN.ActorFactory or {}

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

local function dist2(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return dx * dx + dy * dy
end

local function coordSummary(x, y, z)
    return safeNumber(x) .. "," .. safeNumber(y) .. "," .. safeNumber(z)
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
    local parts = {}
    appendPart(parts, "object", protectedCall(actor, "getObjectName"))
    appendPart(parts, "npcId", getNpcIdFromActor(actor))
    appendPart(parts, "body", protectedCall(actor, "getBodyDamage") ~= nil)
    appendPart(parts, "stats", protectedCall(actor, "getStats") ~= nil)
    appendPart(parts, "inventory", protectedCall(actor, "getInventory") ~= nil)
    appendPart(parts, "npc", protectedCall(actor, "getIsNPC"))
    appendPart(parts, "ghost", protectedCall(actor, "isGhostMode"))
    appendPart(parts, "invisible", protectedCall(actor, "isInvisible"))
    appendPart(parts, "sceneCulled", protectedCall(actor, "isSceneCulled"))
    appendPart(parts, "alpha", safeNumber(protectedCall(actor, "getAlpha", 0)))
    appendPart(parts, "targetAlpha", safeNumber(protectedCall(actor, "getTargetAlpha", 0)))
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
    appendPart(parts, "spawnSource", extra.spawnSource)
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

local function logInfo(message, record, actor, extra)
    if not LWN.Config.Debug.Enabled then return end

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
    end
end

local function safeCleanupActor(actor)
    if not actor then return end
    protectedCall(actor, "StopAllActionQueue")
    protectedCall(actor, "setSceneCulled", true)
    protectedCall(actor, "setNPC", false)
    protectedCall(actor, "setDestroyed", true)
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
    if not appearance.outfit then
        return
    end

    local ok, err = pcall(function()
        desc:dressInNamedOutfit(appearance.outfit)
    end)
    if not ok then
        logInfo("dressInNamedOutfit failed", record, nil, {
            source = "buildDescriptor",
            detail = appearance.outfit,
            thrown = err,
            descriptorMode = descriptorMode,
        })
    end
end

local function addAndWearItem(actor, fullType)
    local inv = protectedCall(actor, "getInventory")
    if not inv then return nil end

    local item = inv:AddItem(fullType)
    if not item then return nil end

    local bodyLocation = protectedCall(item, "getBodyLocation")
    if bodyLocation and bodyLocation ~= "" then
        protectedCall(actor, "setWornItem", bodyLocation, item)
    end
    return item
end

local function ensureVisibleClothing(actor)
    if protectedCall(actor, "getClothingItem_Torso") and protectedCall(actor, "getClothingItem_Legs") then
        return
    end

    protectedCall(actor, "dressInRandomOutfit")

    if protectedCall(actor, "getClothingItem_Torso") and protectedCall(actor, "getClothingItem_Legs") then
        return
    end

    for _, fullType in ipairs(fallbackClothing) do
        addAndWearItem(actor, fullType)
    end
    protectedCall(actor, "resetModelNextFrame")
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

function Factory.buildDescriptor(record)
    local desc, descriptorMode = createDescriptor(record)
    if not desc then
        logFailure("buildDescriptor failed: CreateSurvivor returned nil", record, nil, nil, descriptorMode, { source = "buildDescriptor" })
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
    safeCleanupActor(actor)
end

local function refreshActorPresentation(actor)
    if not actor then return end

    protectedCall(actor, "setGhostMode", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setNPC", true)
    protectedCall(actor, "setIsNPC", true)

    local inv = protectedCall(actor, "getInventory")
    if inv then
        protectedCall(inv, "setDrawDirty", true)
    end

    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
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

function Factory.applyLoadout(record, actor)
    ensureVisibleClothing(actor)

    local primaryWeapon = record.inventory
        and record.inventory.equipment
        and record.inventory.equipment.primaryWeapon
        or nil

    ensurePrimaryWeapon(actor, primaryWeapon)
    refreshActorPresentation(actor)
end

function Factory.createActor(record, player)
    local desc, descriptorMode = Factory.buildDescriptor(record)
    if not desc then
        return nil
    end

    local cell = getCell()
    if not cell then
        logFailure("createActor failed: getCell() returned nil", record, nil, desc, descriptorMode, { source = "createActor" })
        return nil
    end

    local square, spawnSource = Factory.findSpawnSquare(record, player)
    if not square then
        logFailure("createActor skipped: no spawn square", record, nil, desc, descriptorMode, {
            source = "createActor",
            spawnSource = spawnSource,
            detail = coordSummary(record.anchor.x, record.anchor.y, record.anchor.z),
        })
        return nil
    end

    local x = math.floor(protectedCall(square, "getX") or record.anchor.x or 0)
    local y = math.floor(protectedCall(square, "getY") or record.anchor.y or 0)
    local z = math.floor(protectedCall(square, "getZ") or record.anchor.z or 0)

    local ok, actorOrErr = pcall(function()
        -- Build 42 does not expose a complete first-party human NPC framework yet,
        -- so embodied LWN NPCs are created as NPC-flagged IsoPlayer instances with
        -- canonical state still living in ModData-backed records.
        return IsoPlayer.new(cell, desc, x, y, z)
    end)

    if not ok then
        logFailure("createActor failed: IsoPlayer.new threw", record, nil, desc, descriptorMode, {
            source = "createActor",
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
            square = square,
            spawnSource = spawnSource,
        })
        return nil
    end

    protectedCall(actor, "setDescriptor", desc)
    protectedCall(actor, "setNPC", true)
    protectedCall(actor, "setIsNPC", true)
    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setGhostMode", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setVisibleToNPCs", true)
    protectedCall(actor, "setForname", record.identity.firstName)
    protectedCall(actor, "setSurname", record.identity.lastName)

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_NpcId = record.id
        modData.LWN_ActorKind = "IsoPlayer"
        modData.LWN_SpawnSource = spawnSource
    end

    if not hasRuntimeCore(actor) then
        Factory.rejectActor(actor, "createActor rejected invalid runtime actor", record.id, record, desc, descriptorMode, {
            source = "createActor",
            square = square,
            spawnSource = spawnSource,
        })
        return nil
    end

    Factory.applyTraits(record, actor)
    Factory.applyLoadout(record, actor)
    protectedCall(actor, "setHealth", record.stats and record.stats.health or 100)
    refreshActorPresentation(actor)

    logInfo("created embodied npc", record, actor, {
        source = "createActor",
        square = square,
        spawnSource = spawnSource,
        detail = descriptorMode,
    })

    return actor
end
