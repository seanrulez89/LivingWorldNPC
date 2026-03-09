LWN = LWN or {}
LWN.DebugTools = LWN.DebugTools or {}

local DebugTools = LWN.DebugTools
local Store = LWN.PopulationStore

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function ensureDebugState()
    return Store.debugState()
end

local function sayInfo(player, text)
    if player and player.Say then
        player:Say(text)
    end
    print("[LWN][Debug] " .. tostring(text))
end

local function randomizeIdentity(record)
    local desc = SurvivorFactory.CreateSurvivor()
    desc:setFemale(ZombRand(0, 2) == 0)
    SurvivorFactory.randomName(desc)

    record.identity.firstName = desc:getForename() or record.identity.firstName
    record.identity.lastName = desc:getSurname() or record.identity.lastName
    record.identity.female = desc:isFemale()
end

local function findActorForRecord(record)
    local actor = LWN.EmbodimentManager.getActor(record)
    if actor and actor:getModData() and actor:getModData().LWN_NpcId == record.id then
        return actor
    end

    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local cx = math.floor(record.anchor.x or 0)
    local cy = math.floor(record.anchor.y or 0)
    local cz = math.floor(record.anchor.z or 0)

    for y = cy - 2, cy + 2 do
        for x = cx - 2, cx + 2 do
            local square = cell:getGridSquare(x, y, cz)
            if square and square:getMovingObjects() then
                for i = 0, square:getMovingObjects():size() - 1 do
                    local obj = square:getMovingObjects():get(i)
                    if instanceof and instanceof(obj, "IsoSurvivor") and obj:getModData().LWN_NpcId == record.id then
                        LWN.EmbodimentManager.registerActor(record, obj)
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

function DebugTools.isEnabled()
    return ensureDebugState().devToolsEnabled == true
end

function DebugTools.setEnabled(enabled)
    ensureDebugState().devToolsEnabled = enabled == true
    return ensureDebugState().devToolsEnabled
end

function DebugTools.toggleEnabled()
    local state = ensureDebugState()
    state.devToolsEnabled = not (state.devToolsEnabled == true)
    return state.devToolsEnabled
end

function DebugTools.spawnOneNearPlayer(player)
    if not player then return nil end

    local id = Store.nextNpcId()
    local seed = ZombRand(1, 2147483646)
    local record = LWN.Schema.newNPCRecord(id, seed)

    randomizeIdentity(record)
    record.anchor.x = math.floor(player:getX()) + ZombRand(-2, 3)
    record.anchor.y = math.floor(player:getY()) + ZombRand(-2, 3)
    record.anchor.z = math.floor(player:getZ())
    record.embodiment.state = "eligible"
    record.embodiment.cooldownUntilHour = 0

    Store.addNPC(record)
    local actor = LWN.EmbodimentManager.tryEmbody(record, player)

    if actor then
        sayInfo(player, string.format("Spawned NPC %s", record.id))
    else
        sayInfo(player, string.format("Spawn request queued for %s (actor not ready)", record.id))
    end
    return record, actor
end

function DebugTools.deleteNpcById(npcId, player)
    if not npcId then return false end
    local record = Store.getNPC(npcId)
    if not record then return false end

    local actor = findActorForRecord(record)
    if actor then
        if actor.StopAllActionQueue then actor:StopAllActionQueue() end
        if actor.Despawn then actor:Despawn() end
        LWN.EmbodimentManager.unregisterActor(record)
    end

    Store.removeNPC(npcId)
    sayInfo(player, string.format("Deleted NPC %s", npcId))
    return true
end

function DebugTools.deleteNearestNpc(player)
    if not player then return false end

    local px, py = player:getX(), player:getY()
    local bestId = nil
    local bestD2 = math.huge

    Store.eachNPC(function(record)
        local dx = (record.anchor.x or 0) - px
        local dy = (record.anchor.y or 0) - py
        local d2 = dx * dx + dy * dy
        if d2 < bestD2 then
            bestD2 = d2
            bestId = record.id
        end
    end)

    if not bestId then return false end
    return DebugTools.deleteNpcById(bestId, player)
end