LWN = LWN or {}
LWN.EventAdapter = LWN.EventAdapter or {}

local Adapter = LWN.EventAdapter

local function getPlayerSafe()
    return getPlayer and getPlayer() or nil
end

local function isPlayerAsleep(player)
    if not player then return false end
    if player.isAsleep then
        return player:isAsleep() == true
    end
    return false
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

local function updateTravelledDistance(player)
    if not player then return end

    local px = player:getX()
    local py = player:getY()

    if not Adapter._lastPlayerPos then
        Adapter._lastPlayerPos = { x = px, y = py }
        return
    end

    local dx = px - Adapter._lastPlayerPos.x
    local dy = py - Adapter._lastPlayerPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0.01 then
        LWN.PopulationStore.markTravelled(dist)
        Adapter._lastPlayerPos.x = px
        Adapter._lastPlayerPos.y = py
    end
end

local function findActorNearAnchor(record)
    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local meta = LWN.PopulationStore.getEmbodiedMeta(record.id)
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
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

local function resolveEmbodiedActor(record)
    local actor = LWN.EmbodimentManager.getActor(record)
    if actor
        and getNpcId(actor) == record.id
        and (not actor.isExistInTheWorld or actor:isExistInTheWorld() ~= false)
        and (not LWN.ActorFactory or not LWN.ActorFactory.hasRuntimeCore or LWN.ActorFactory.hasRuntimeCore(actor))
    then
        return actor
    end

    actor = findActorNearAnchor(record)
    if actor then
        LWN.EmbodimentManager.registerActor(record, actor)
    end
    return actor
end

local function hideEmbodiedRecord(record, actor, reason, detail)
    print(string.format("[LWN][Embodiment] hiding %s because %s :: %s", tostring(record.id), tostring(reason), tostring(detail)))

    if actor and LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
        LWN.ActorFactory.cleanupActor(actor)
    end

    local cooldownHours = ((LWN.Config.Population and LWN.Config.Population.EncounterCooldownHours) or 2.0)
    if (record.companion and record.companion.recruited) or record.debugSpawnOnly then
        cooldownHours = math.max((LWN.Config.Embodiment and LWN.Config.Embodiment.GraceHours) or 0.05, 0.05)
    end

    record.embodiment.state = "hidden"
    record.embodiment.actorId = nil
    record.embodiment.missingTicks = 0
    record.embodiment.cooldownUntilHour = getGameTime():getWorldAgeHours() + cooldownHours
    LWN.EmbodimentManager.unregisterActor(record)
end

local function tickEmbodiedRecord(record, actor, player)
    record.embodiment.missingTicks = 0
    LWN.ActorSync.pullActorToRecord(record, actor)
    LWN.EmbodimentManager.registerActor(record, actor)
    LWN.GoalSystem.update(record, {})

    local combatCtx = LWN.Combat.buildContext(record, actor)
    local combatIntent = LWN.Combat.chooseIntent(record, actor, combatCtx)
    if combatIntent then
        LWN.ActionRuntime.enqueue(record, combatIntent)
    else
        local chosen = LWN.UtilityAI.choose(record, {})
        local intent = LWN.BehaviorTree.tick(record, actor, {}, chosen)
        if intent and not LWN.ActionRuntime.peek(record) then
            LWN.ActionRuntime.enqueue(record, intent)
        end
    end

    LWN.ActionRuntime.tick(record, actor)
    LWN.EmbodimentManager.tryDespawn(record, actor, player)
end

function Adapter.onNewGame(player, square)
    LWN.PopulationSeeder.seedNewWorld(player, square)
    LWN.WorldStory.seed()
end

function Adapter.onCreateUI()
    -- Pre-create windows lazily if you prefer. We keep them lazy in the skeleton.
end

function Adapter.onCreateSurvivor(survivor)
    if not survivor then return end

    local pendingRecord = nil
    if LWN.ActorFactory and LWN.ActorFactory.attachPendingRecord then
        pendingRecord = LWN.ActorFactory.attachPendingRecord(survivor)
    end

    local modData = survivor:getModData()
    local npcId = (modData and modData.LWN_NpcId) or (pendingRecord and pendingRecord.id) or nil
    if not npcId then return end

    if LWN.ActorFactory and LWN.ActorFactory.hasRuntimeCore and not LWN.ActorFactory.hasRuntimeCore(survivor) then
        if LWN.ActorFactory.rejectActor then
            LWN.ActorFactory.rejectActor(survivor, "onCreateSurvivor rejected invalid runtime actor", npcId, pendingRecord, nil, nil, {
                source = "onCreateSurvivor",
            })
        end
        return
    end

    local record = pendingRecord or LWN.PopulationStore.getNPC(npcId)
    if record then
        LWN.ActorSync.pushRecordToActor(record, survivor)
        if record.embodiment.state == "embodied" then
            LWN.EmbodimentManager.registerActor(record, survivor)
        end
    end
end

function Adapter.onPlayerDeath(player)
    LWN.Legacy.showDeathModal(player)
end

function Adapter.onEveryOneMinute()
    local player = getPlayerSafe()
    if not player then return end

    if isPlayerAsleep(player) then
        LWN.PopulationStore.markSlept()
    end

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state ~= "embodied" then
            record.stats.hunger = math.min(1.0, record.stats.hunger + 0.01)
            record.stats.thirst = math.min(1.0, record.stats.thirst + 0.012)
            record.stats.fatigue = math.min(1.0, record.stats.fatigue + 0.006)
            LWN.Memory.tickDecay(record)
            LWN.WorldStory.tickNPC(record)
        end
    end)

    LWN.EncounterDirector.update(player)
end

function Adapter.onEveryTenMinutes()
    -- Reserved for heavier off-screen simulation and world-story pulses.
end

function Adapter.onTick()
    local player = getPlayerSafe()
    if not player then return end

    updateTravelledDistance(player)

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state == "hidden" and LWN.EmbodimentManager.tryRearmHidden then
            LWN.EmbodimentManager.tryRearmHidden(record, player)
        end
    end)

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state == "eligible" then
            LWN.EmbodimentManager.tryEmbody(record, player)
        end
    end)

    LWN.PopulationStore.eachNPC(function(record)
        if record.embodiment.state == "embodied" then
            local actor = resolveEmbodiedActor(record)

            if actor then
                local ok, err = pcall(tickEmbodiedRecord, record, actor, player)
                if not ok then
                    hideEmbodiedRecord(record, actor, "embodied_tick_error", err)
                end
            else
                record.embodiment.missingTicks = (record.embodiment.missingTicks or 0) + 1
                if record.embodiment.missingTicks >= 10 then
                    hideEmbodiedRecord(record, nil, "actor_lost", "resolveEmbodiedActor returned nil")
                end
            end
        end
    end)

    if LWN.UIRadialMenu and LWN.UIRadialMenu.refresh then
        LWN.UIRadialMenu:refresh()
    end
    if LWN.UICommandPanel and LWN.UICommandPanel.refresh then
        LWN.UICommandPanel:refresh()
    end
    if LWN.UIDialogueWindow and LWN.UIDialogueWindow.refresh then
        LWN.UIDialogueWindow:refresh()
    end
end

function Adapter.bind()
    -- These hooks come from the shipped/community Lua event layer, not the Java Javadocs.
    Events.OnNewGame.Add(Adapter.onNewGame)
    Events.OnCreateUI.Add(Adapter.onCreateUI)
    Events.OnCreateSurvivor.Add(Adapter.onCreateSurvivor)
    Events.OnPlayerDeath.Add(Adapter.onPlayerDeath)
    Events.OnFillWorldObjectContextMenu.Add(LWN.UIContextMenu.onFillWorldObjectContextMenu)
    Events.OnCustomUIKeyPressed.Add(LWN.UIRadialMenu.onCustomUIKeyPressed)
    Events.EveryOneMinute.Add(Adapter.onEveryOneMinute)
    Events.EveryTenMinutes.Add(Adapter.onEveryTenMinutes)
    Events.OnTick.Add(Adapter.onTick)
end
