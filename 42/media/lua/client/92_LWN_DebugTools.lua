LWN = LWN or {}
LWN.DebugTools = LWN.DebugTools or {}

-- Development-only helpers. They should stay available in debug builds because
-- most embodiment failures are easiest to diagnose from live saves.
local DebugTools = LWN.DebugTools
local Store = LWN.PopulationStore

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function ensureDebugState()
    return Store.debugState()
end

local function clamp(value, minValue, maxValue)
    if type(value) ~= "number" then
        value = minValue
    end
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    return value
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
    if not record or (Store.isAlive and not Store.isAlive(record)) then
        return nil
    end

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
        if Store.isAlive(record) and record.embodiment and record.embodiment.state == "embodied" and record.debugSpawnOnly then
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

local function findNearestRecord(player)
    if not player then return nil, nil end

    local px, py = player:getX(), player:getY()
    local bestRecord = nil
    local bestD2 = math.huge

    Store.eachNPC(function(record)
        if Store.isAlive(record) ~= true then
            return
        end
        local ax = record.anchor and record.anchor.x or 0
        local ay = record.anchor and record.anchor.y or 0
        local dx = ax - px
        local dy = ay - py
        local d2 = dx * dx + dy * dy
        if d2 < bestD2 then
            bestRecord = record
            bestD2 = d2
        end
    end)

    return bestRecord, bestD2
end

local function relationshipValue(record, key)
    local rel = record.relationshipToPlayer or {}
    return tonumber(rel[key] or 0) or 0
end

local function actorDebugLine(actor)
    if not actor then
        return "actor=nil"
    end

    return string.format(
        "actor=%s world=%s ghost=%s invisible=%s culled=%s x=%.1f y=%.1f z=%.1f",
        tostring(actor:getObjectName()),
        tostring(actor.isExistInTheWorld and actor:isExistInTheWorld() or nil),
        tostring(actor.isGhostMode and actor:isGhostMode() or nil),
        tostring(actor.isInvisible and actor:isInvisible() or nil),
        tostring(actor.isSceneCulled and actor:isSceneCulled() or nil),
        tonumber(actor:getX() or 0) or 0,
        tonumber(actor:getY() or 0) or 0,
        tonumber(actor:getZ() or 0) or 0
    )
end

local function dumpRecordSummary(record, actor, player)
    if not record then
        sayInfo(player, "No NPC record to dump")
        return false
    end

    local currentIntent = record.goals and record.goals.currentIntent or nil
    local currentPlan = record.goals and record.goals.currentPlan or {}
    local summary = string.format(
        "NPC %s %s state=%s goal=%s intent=%s",
        tostring(record.id),
        tostring(record.identity and record.identity.firstName or "Unknown"),
        tostring(record.embodiment and record.embodiment.state or "unknown"),
        tostring(record.goals and record.goals.longTerm and record.goals.longTerm.kind or "idle"),
        tostring(currentIntent or "none")
    )

    sayInfo(player, summary)
    print("[LWN][Debug] npc summary :: " .. summary)
    print(string.format(
        "[LWN][Debug] npc relations :: trust=%.2f respect=%.2f fear=%.2f resentment=%.2f loyaltyShift=%.2f",
        relationshipValue(record, "trust"),
        relationshipValue(record, "respect"),
        relationshipValue(record, "fear"),
        relationshipValue(record, "resentment"),
        relationshipValue(record, "loyaltyShift")
    ))
    print(string.format(
        "[LWN][Debug] npc stats :: hunger=%.2f thirst=%.2f fatigue=%.2f panic=%.2f health=%.2f role=%s story=%s clueCount=%s memories=%d",
        tonumber(record.stats and record.stats.hunger or 0) or 0,
        tonumber(record.stats and record.stats.thirst or 0) or 0,
        tonumber(record.stats and record.stats.fatigue or 0) or 0,
        tonumber(record.stats and record.stats.panic or 0) or 0,
        tonumber(record.stats and record.stats.health or 0) or 0,
        tostring(record.companion and record.companion.squadRole or "none"),
        tostring(record.storyArc and record.storyArc.type or "none"),
        tostring(record.storyArc and record.storyArc.clueCount or 0),
        #(record.memories or {})
    ))
    print("[LWN][Debug] npc actionQueue :: " .. table.concat(currentPlan, ","))
    print("[LWN][Debug] npc actor :: " .. actorDebugLine(actor))
    return true
end

local function tweakRelationshipField(record, field, delta)
    record.relationshipToPlayer = record.relationshipToPlayer or {}
    local rel = record.relationshipToPlayer

    if field == "trust" and LWN.Social and LWN.Social.adjustTrust then
        LWN.Social.adjustTrust(record, delta, "debug_trust")
        return rel.trust
    end
    if field == "resentment" and LWN.Social and LWN.Social.adjustResentment then
        LWN.Social.adjustResentment(record, delta, "debug_resentment")
        return rel.resentment
    end

    local minValue, maxValue = -1, 1
    if field == "fear" then
        minValue, maxValue = 0, 1.5
    elseif field == "respect" or field == "attachment" or field == "debt" then
        minValue, maxValue = -1, 1.5
    elseif field == "loyaltyShift" then
        minValue, maxValue = -1.5, 1.5
    end

    rel[field] = clamp((rel[field] or 0) + delta, minValue, maxValue)
    return rel[field]
end

local function sayActorLine(record, line)
    local actor = findActorForRecord(record)
    if actor and actor.Say then
        actor:Say(line)
    end
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

    if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
        LWN.EmbodimentManager.canonicalCleanup(victim, {
            reason = "debug_make_room",
            detail = "max_embodied_debug_spawn",
        })
    end
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

function DebugTools.dumpNearestNpcSummary(player)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    return dumpRecordSummary(record, findActorForRecord(record), player)
end

function DebugTools.dumpNpcById(npcId, player)
    if not npcId then return false end
    local record = Store.getNPC(npcId)
    if not record then
        sayInfo(player, string.format("Unknown NPC %s", tostring(npcId)))
        return false
    end

    return dumpRecordSummary(record, findActorForRecord(record), player)
end

function DebugTools.adjustNearestRelationship(player, field, delta)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    local value = tweakRelationshipField(record, field, delta)
    sayInfo(player, string.format("%s %s %.2f", tostring(record.id), tostring(field), tonumber(value or 0) or 0))
    return true, record
end

function DebugTools.applyStoryBeat(player, beat)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    record.drama = record.drama or {}
    if beat == "shared_food" then
        tweakRelationshipField(record, "trust", 0.20)
        tweakRelationshipField(record, "resentment", -0.10)
        record.stats.hunger = clamp((record.stats.hunger or 0) - 0.15, 0, 1)
        LWN.Memory.add(record, "shared_food", 0.45, { debug = true })
        sayActorLine(record, "That helped. Thanks.")
    elseif beat == "rescued_me" then
        tweakRelationshipField(record, "trust", 0.30)
        tweakRelationshipField(record, "fear", -0.10)
        LWN.Memory.add(record, "rescued_me", 0.60, { debug = true })
        sayActorLine(record, "You pulled me out of that.")
    elseif beat == "promise_broken" then
        tweakRelationshipField(record, "resentment", 0.25)
        record.drama.promiseBroken = true
        LWN.Memory.add(record, "promise_broken", 0.55, { debug = true })
        sayActorLine(record, "You said we'd do this together.")
    elseif beat == "theft_suspected" then
        tweakRelationshipField(record, "resentment", 0.20)
        record.drama.suspectsTheft = true
        LWN.Memory.add(record, "theft_suspected", 0.40, { debug = true })
        sayActorLine(record, "Something is missing.")
    elseif beat == "jealousy" then
        tweakRelationshipField(record, "resentment", 0.15)
        record.drama.jealousy = true
        LWN.Memory.add(record, "jealousy", 0.35, { debug = true })
        sayActorLine(record, "You trust them more than me.")
    else
        sayInfo(player, string.format("Unknown story beat %s", tostring(beat)))
        return false
    end

    sayInfo(player, string.format("Applied beat %s to %s", tostring(beat), tostring(record.id)))
    return true, record
end

function DebugTools.forceLegacyCandidate(player)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    record.companion = record.companion or {}
    record.companion.recruited = true
    record.companion.canContinueAsLegacy = true
    record.companion.squadRole = record.companion.squadRole or "companion"
    record.relationshipToPlayer = record.relationshipToPlayer or {}
    record.relationshipToPlayer.trust = math.max(record.relationshipToPlayer.trust or 0, LWN.Config.Legacy.MinTrust)
    Store.setLegacyCandidates(LWN.Legacy.collectCandidates())
    sayInfo(player, string.format("Forced legacy candidate %s", tostring(record.id)))
    return true, record
end

function DebugTools.wipeAndReseed(player)
    local records = {}
    Store.eachNPC(function(record)
        if Store.isAlive(record) then
            records[#records + 1] = record
        end
    end)

    for _, record in ipairs(records) do
        local actor = findActorForRecord(record)
        if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
            LWN.EmbodimentManager.canonicalCleanup(record, {
                actor = actor,
                reason = "debug_wipe",
                detail = "wipeAndReseed",
            })
        elseif actor and LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
            LWN.CarrierAdapter.retire(record, LWN.EmbodimentManager and LWN.EmbodimentManager.getCarrierHandle and LWN.EmbodimentManager.getCarrierHandle(record) or {
                kind = record and record.embodiment and record.embodiment.carrierKind or "isoplayer",
                actor = actor,
                status = "active",
            }, {
                reason = "debug_wipe",
            })
        elseif actor and LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
            LWN.ActorFactory.cleanupActor(actor)
        end
    end

    if LWN.ActionRuntime then
        LWN.ActionRuntime.Queues = {}
    end
    if LWN.EmbodimentManager then
        LWN.EmbodimentManager._actors = {}
        LWN.EmbodimentManager._carrierHandles = {}
        LWN.EmbodimentManager._cleanupBlocklist = {}
        LWN.EmbodimentManager._cleanupInFlight = {}
        LWN.EmbodimentManager._registryTraceCache = {}
        LWN.EmbodimentManager._deathLikeTraceCache = {}
    end

    if ModData and ModData.remove then
        pcall(ModData.remove, LWN.Config.ModDataTag)
    end
    Store.resetRoot()

    if LWN.EventAdapter then
        LWN.EventAdapter._lastPlayerPos = nil
    end

    if player and LWN.PopulationSeeder and LWN.PopulationSeeder.seedNewWorld then
        LWN.PopulationSeeder.seedNewWorld(player, player:getSquare())
    end
    if LWN.WorldStory and LWN.WorldStory.seed then
        LWN.WorldStory.seed()
    end

    sayInfo(player, "Wiped LWN data and reseeded current save")
    return true
end

function DebugTools.deleteNpcById(npcId, player)
    if not npcId then return false end
    local record = Store.getNPC(npcId)
    if not record then return false end

    local actor = findActorForRecord(record)
    if actor and LWN.ActorFactory and LWN.ActorFactory.isActorInCombatOrUnderAttack then
        local inCombat, combatReason = LWN.ActorFactory.isActorInCombatOrUnderAttack(actor)
        if inCombat == true then
            sayInfo(player, string.format("NPC %s is in combat and cannot be deleted (%s)", npcId, tostring(combatReason)))
            return false
        end
    end

    if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
        LWN.EmbodimentManager.canonicalCleanup(record, {
            actor = actor,
            reason = "debug_delete",
            detail = "deleteNpcById:immediate_noncombat",
        })
    else
        if actor and LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
            LWN.ActorFactory.cleanupActor(actor, "debug_delete")
        end
        Store.removeNPC(npcId)
    end
    sayInfo(player, string.format("Deleted NPC %s", npcId))
    return true
end

function DebugTools.deleteNearestNpc(player)
    if not player then return false end

    local px, py = player:getX(), player:getY()
    local bestId = nil
    local bestD2 = math.huge

    Store.eachNPC(function(record)
        if Store.isAlive(record) ~= true then
            return
        end
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

function DebugTools.onKeyPressed(key)
    if not key or not Keyboard then return end

    local player = getPlayer and getPlayer() or nil
    if key == Keyboard.KEY_F3 then
        local after = DebugTools.toggleEnabled()
        sayInfo(player, after and "LWN debug on" or "LWN debug off")
        return
    end

    if not DebugTools.isEnabled() then return end

    if key == Keyboard.KEY_F4 then
        DebugTools.spawnOneNearPlayer(player)
    elseif key == Keyboard.KEY_F5 then
        DebugTools.dumpNearestNpcSummary(player)
    elseif key == Keyboard.KEY_F6 then
        DebugTools.wipeAndReseed(player)
    elseif key == Keyboard.KEY_F7 then
        DebugTools.adjustNearestRelationship(player, "trust", 0.20)
    elseif key == Keyboard.KEY_F8 then
        DebugTools.forceLegacyCandidate(player)
    end
end
