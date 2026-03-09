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

local function isManagedActor(obj)
    if not obj then return false end
    if LWN.ActorFactory and LWN.ActorFactory.isManagedActor then
        return LWN.ActorFactory.isManagedActor(obj)
    end
    return false
end

local function getNpcId(actor)
    if not actor then return nil end
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        return LWN.ActorFactory.getNpcIdFromActor(actor)
    end
    local modData = actor.getModData and actor:getModData() or nil
    return modData and modData.LWN_NpcId or nil
end

local function randomizeIdentity(record)
    local female = ZombRand(0, 2) == 0
    record.identity.female = female

    if SurvivorFactory and SurvivorFactory.getRandomForename then
        record.identity.firstName = SurvivorFactory.getRandomForename(female) or record.identity.firstName
    end
    if SurvivorFactory and SurvivorFactory.getRandomSurname then
        record.identity.lastName = SurvivorFactory.getRandomSurname() or record.identity.lastName
    end
end

local function findActorForRecord(record)
    local actor = LWN.EmbodimentManager.getActor(record)
    if actor and getNpcId(actor) == record.id then
        return actor
    end

    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local meta = Store.getEmbodiedMeta(record.id)
    local cx = math.floor((meta and meta.x) or record.anchor.x or 0)
    local cy = math.floor((meta and meta.y) or record.anchor.y or 0)
    local cz = math.floor((meta and meta.z) or record.anchor.z or 0)

    for y = cy - 2, cy + 2 do
        for x = cx - 2, cx + 2 do
            local square = cell:getGridSquare(x, y, cz)
            if square and square:getMovingObjects() then
                for i = 0, square:getMovingObjects():size() - 1 do
                    local obj = square:getMovingObjects():get(i)
                    if isManagedActor(obj) and getNpcId(obj) == record.id then
                        LWN.EmbodimentManager.registerActor(record, obj)
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

local function chooseEmbodiedDebugVictim(player)
    if not player then return nil end

    local px, py = player:getX(), player:getY()
    local bestRecord = nil
    local bestD2 = -1

    Store.eachNPC(function(record)
        if record.embodiment and record.embodiment.state == "embodied" and record.debugSpawnOnly then
            local dx = (record.anchor.x or 0) - px
            local dy = (record.anchor.y or 0) - py
            local d2 = dx * dx + dy * dy
            if d2 > bestD2 then
                bestRecord = record
                bestD2 = d2
            end
        end
    end)

    return bestRecord
end

local function makeRoomForDebugSpawn(player)
    local countEmbodied = Store.countEmbodied and Store.countEmbodied() or 0
    local maxEmbodied = LWN.Config and LWN.Config.Population and LWN.Config.Population.MaxEmbodied or 0
    if countEmbodied < maxEmbodied then
        return true, nil
    end

    local victim = chooseEmbodiedDebugVictim(player)
    if not victim then
        return false, "max_embodied_no_debug_victim"
    end

    local actor = findActorForRecord(victim)
    if actor and LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
        LWN.ActorFactory.cleanupActor(actor)
    end
    LWN.EmbodimentManager.unregisterActor(victim)
    Store.removeNPC(victim.id)
    print("[LWN][Debug] Freed embodied slot by removing debug NPC " .. tostring(victim.id))
    return true, victim.id
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

    local roomOk, roomDetail = makeRoomForDebugSpawn(player)
    if not roomOk then
        sayInfo(player, string.format("Spawn blocked: %s", tostring(roomDetail)))
        return nil
    elseif roomDetail then
        sayInfo(player, string.format("Freed debug slot by removing %s", tostring(roomDetail)))
    end

    local id = Store.nextNpcId()
    local seed = ZombRand(1, 2147483646)
    local record = LWN.Schema.newNPCRecord(id, seed)

    randomizeIdentity(record)
    record.identity.profession = "unemployed"
    record.backstory.formerProfession = record.identity.profession
    record.relationshipToPlayer.trust = 0.25
    record.relationshipToPlayer.respect = 0.15
    record.companion.recruited = true
    record.companion.squadRole = "debug"
    record.goals.longTerm = LWN.Schema.newGoal("support_player", 1.0)
    record.anchor.x = math.floor(player:getX()) + ZombRand(-2, 3)
    record.anchor.y = math.floor(player:getY()) + ZombRand(-2, 3)
    record.anchor.z = math.floor(player:getZ())
    record.debugSpawnOnly = true
    record.embodiment.state = "eligible"
    record.embodiment.cooldownUntilHour = worldAgeHours()

    Store.addNPC(record)

    local actor = LWN.EmbodimentManager.tryEmbody(record, player)
    if actor then
        sayInfo(player, string.format("Spawned embodied NPC %s", record.id))
    else
        local failure = LWN.ActorFactory and LWN.ActorFactory.getLastFailure and LWN.ActorFactory.getLastFailure() or nil
        if failure and failure.npcId == record.id then
            sayInfo(player, string.format("Spawn failed for %s; see console for ActorFactory failure details", record.id))
        else
            local reason = record.embodiment and record.embodiment.lastFailureReason or "unknown"
            local detail = record.embodiment and record.embodiment.lastFailureDetail or ""
            sayInfo(player, string.format("Spawn blocked for %s: %s %s", record.id, tostring(reason), tostring(detail)))
        end
    end
    return record, actor
end

function DebugTools.dumpLastActorFailure(player)
    local failure = LWN.ActorFactory and LWN.ActorFactory.getLastFailure and LWN.ActorFactory.getLastFailure() or nil
    if not failure then
        sayInfo(player, "No recorded actor failure")
        return false
    end

    sayInfo(player, string.format("Last actor failure: %s", tostring(failure.npcId or failure.reason)))
    if LWN.ActorFactory and LWN.ActorFactory.dumpLastFailure then
        LWN.ActorFactory.dumpLastFailure()
    end
    return true
end

function DebugTools.deleteNpcById(npcId, player)
    if not npcId then return false end
    local record = Store.getNPC(npcId)
    if not record then return false end

    local actor = findActorForRecord(record)
    if actor then
        if LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
            LWN.ActorFactory.cleanupActor(actor)
        end
        LWN.EmbodimentManager.unregisterActor(record)
    end

    if LWN.UICommandPanel and LWN.UICommandPanel.target and getNpcId(LWN.UICommandPanel.target) == npcId then
        LWN.UICommandPanel.hide()
    end
    if LWN.UIDialogueWindow and LWN.UIDialogueWindow.target and getNpcId(LWN.UIDialogueWindow.target) == npcId then
        LWN.UIDialogueWindow.hide()
    end
    if LWN.UIRadialMenu and LWN.UIRadialMenu.target and getNpcId(LWN.UIRadialMenu.target) == npcId then
        LWN.UIRadialMenu.hide()
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
