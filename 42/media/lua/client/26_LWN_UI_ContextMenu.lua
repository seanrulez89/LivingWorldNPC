LWN = LWN or {}
LWN.UIContextMenu = LWN.UIContextMenu or {}

-- World-object context entry point. We intentionally scan nearby squares because
-- a clicked tile often isn't the actor's exact moving-object square.
local UIContext = LWN.UIContextMenu
local Store = LWN.PopulationStore

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

local function objectRef(value)
    if value == nil then return "nil" end
    return safeText(tostring(value))
end

local function isDebugModeEnabled()
    if LWN and LWN.Config and LWN.Config.Debug and LWN.Config.Debug.Enabled == true then
        return true
    end
    if LWN.DebugTools and LWN.DebugTools.isEnabled then
        return LWN.DebugTools.isEnabled() == true
    end
    return false
end

local function getPlayerByNum(playerNum)
    if getSpecificPlayer then
        return getSpecificPlayer(playerNum)
    end
    return getPlayer and getPlayer() or nil
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
        local npcId = LWN.ActorFactory.getNpcIdFromActor(actor)
        if npcId then
            return npcId
        end
    end
    local modData = actor.getModData and actor:getModData() or nil
    return modData and (modData.LWN_NpcId or modData.LWN_LastNpcId) or nil
end

local function getModData(obj)
    if not obj then return nil end
    return obj.getModData and obj:getModData() or nil
end

local function getActiveNpcId(obj)
    local modData = getModData(obj)
    return modData and modData.LWN_NpcId or nil
end

local function hasStaleNpcMarker(obj)
    local modData = getModData(obj)
    return modData ~= nil
        and modData.LWN_NpcId == nil
        and (modData.LWN_LastNpcId ~= nil or modData.LWN_LastCleanupHour ~= nil)
end

local function isCleanupBlocked(npcId)
    if not npcId then return false end
    if LWN.EmbodimentManager and LWN.EmbodimentManager.isCleanupBlocked then
        return LWN.EmbodimentManager.isCleanupBlocked(npcId)
    end
    return false
end

local function worldObjectKind(obj)
    if not obj then return "nil" end
    if instanceof then
        if instanceof(obj, "IsoDeadBody") then return "corpse" end
        if instanceof(obj, "IsoZombie") then return "zombie" end
        if instanceof(obj, "IsoPlayer") then return "player" end
        if instanceof(obj, "IsoSurvivor") then return "survivor" end
    end
    return safeText(protectedCall(obj, "getObjectName"))
end

local function getRegisteredActor(record)
    if not record then return nil end
    if LWN.EmbodimentManager and LWN.EmbodimentManager.getActor then
        return LWN.EmbodimentManager.getActor(record)
    end
    return nil
end

local function npcMarkerState(obj)
    local modData = getModData(obj)
    if not modData then return "none" end
    if modData.LWN_NpcId ~= nil then return "active" end
    if modData.LWN_LastNpcId ~= nil or modData.LWN_LastCleanupHour ~= nil then
        return "stale"
    end
    return "none"
end

local function traceContextCandidate(stage, actor, reason, worldObject)
    if not isDebugModeEnabled() then return end

    local obj = actor or worldObject
    local npcId = getNpcId(obj)
    local record = npcId and Store and Store.getNPC and Store.getNPC(npcId) or nil
    local registeredActor = getRegisteredActor(record)
    local deathLike = actor and LWN.ActorFactory and LWN.ActorFactory.isDeathLikeActor and LWN.ActorFactory.isDeathLikeActor(actor) or false
    print(string.format(
        "[LWN][ContextTrace] stage=%s | npcId=%s | reason=%s | candidateRef=%s | kind=%s | marker=%s | cleanupBlocked=%s | recordExists=%s | recordState=%s | registeredRef=%s | registeredMatch=%s | deathLike=%s | world=%s | square=%s",
        safeText(stage),
        safeText(npcId),
        safeText(reason),
        safeText(objectRef(obj)),
        safeText(worldObjectKind(obj)),
        safeText(npcMarkerState(obj)),
        safeText(isCleanupBlocked(npcId)),
        safeText(record ~= nil),
        safeText(record and record.embodiment and record.embodiment.state or nil),
        safeText(registeredActor and objectRef(registeredActor) or nil),
        safeText(registeredActor ~= nil and registeredActor == actor or false),
        safeText(deathLike),
        safeText(obj and protectedCall(obj, "isExistInTheWorld") or nil),
        safeText(obj and protectedCall(obj, "getSquare") or protectedCall(obj, "getCurrentSquare") or nil)
    ))
end

local function isManagedZombieCarrier(actor)
    if not actor then return false end
    if worldObjectKind(actor) ~= "zombie" then return false end

    local npcId = getActiveNpcId(actor) or getNpcId(actor)
    if not npcId then return false end

    local modData = getModData(actor)
    return modData ~= nil and modData.LWN_CarrierKind == "isozombie"
end

local function isTargetableNpcActor(actor)
    if not actor then return false end

    local kind = worldObjectKind(actor)
    if kind == "corpse" then
        traceContextCandidate("candidate.rejected", actor, "leftover_death_object", nil)
        return false
    end
    if kind == "zombie" and not isManagedZombieCarrier(actor) then
        traceContextCandidate("candidate.rejected", actor, "leftover_death_object", nil)
        return false
    end

    if hasStaleNpcMarker(actor) then
        traceContextCandidate("candidate.rejected", actor, "stale_cleanup_marker", nil)
        return false
    end

    local npcId = getActiveNpcId(actor) or getNpcId(actor)
    if not npcId then return false end

    if isCleanupBlocked(npcId) then
        traceContextCandidate("candidate.rejected", actor, "cleanup_blocked", nil)
        return false
    end

    if protectedCall(actor, "isDestroyed") == true or protectedCall(actor, "isExistInTheWorld") == false then
        traceContextCandidate("candidate.rejected", actor, "stale_world_actor", nil)
        return false
    end

    if not isManagedActor(actor) then
        local reason
        if kind == "player" then
            reason = "stale_player_actor"
        elseif kind == "zombie" and isManagedZombieCarrier(actor) then
            reason = "managed_zombie_not_finalized"
        else
            reason = "not_managed_actor"
        end
        traceContextCandidate("candidate.rejected", actor, reason, nil)
        return false
    end

    local record = Store and Store.getNPC and Store.getNPC(npcId) or nil
    if not record then
        traceContextCandidate("candidate.rejected", actor, "record_missing", nil)
        return false
    end

    if record.embodiment and record.embodiment.state ~= "embodied" then
        traceContextCandidate("candidate.rejected", actor, "record_not_embodied", nil)
        return false
    end

    local registeredActor = getRegisteredActor(record)
    if not registeredActor then
        traceContextCandidate("candidate.rejected", actor, "record_not_registered", nil)
        return false
    end

    if registeredActor ~= actor then
        traceContextCandidate("candidate.rejected", actor, "stale_registered_actor", nil)
        return false
    end

    if LWN.ActorFactory and LWN.ActorFactory.isDeathLikeActor and LWN.ActorFactory.isDeathLikeActor(actor) then
        traceContextCandidate("candidate.rejected", actor, "death_like_actor", nil)
        return false
    end

    traceContextCandidate("candidate.accepted", actor, "targetable", nil)
    return true
end

function UIContext.findNpcActorInWorldObjects(worldObjects)
    if not worldObjects or #worldObjects == 0 then return nil end
    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local candidateSquares = {}
    local seenSquares = {}
    local originSquare = nil

    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if getNpcId(obj) then
            traceContextCandidate("worldObject.inspect", nil, "clicked_object", obj)
        end

        if isTargetableNpcActor(obj) then
            return obj
        end

        local square = obj and obj.getSquare and obj:getSquare() or nil
        if square then
            originSquare = originSquare or square
            local key = tostring(square:getX()) .. ":" .. tostring(square:getY()) .. ":" .. tostring(square:getZ())
            if not seenSquares[key] then
                seenSquares[key] = true
                candidateSquares[#candidateSquares + 1] = square
            end
        end
    end

    originSquare = originSquare or candidateSquares[1]
    if not originSquare then return nil end

    local ox = originSquare:getX()
    local oy = originSquare:getY()
    local oz = originSquare:getZ()
    local bestActor = nil
    local bestD2 = math.huge

    local function scanSquare(square)
        if not square or not square.getMovingObjects then return end
        local movingObjects = square:getMovingObjects()
        if not movingObjects then return end

        for i = 0, movingObjects:size() - 1 do
            local obj = movingObjects:get(i)
            if isTargetableNpcActor(obj) then
                local dx = (obj:getX() or square:getX()) - ox
                local dy = (obj:getY() or square:getY()) - oy
                local d2 = dx * dx + dy * dy
                if d2 < bestD2 then
                    bestActor = obj
                    bestD2 = d2
                end
            end
        end
    end

    for _, square in ipairs(candidateSquares) do
        for dy = -1, 1 do
            for dx = -1, 1 do
                scanSquare(cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ()))
            end
        end
    end

    return bestActor
end

local function addNpcInteractionSubmenu(context, actor)
    local modData = getModData(actor)
    local displayName = protectedCall(actor, "getFullName")
        or modData and modData.LWN_DisplayName
        or tostring(getNpcId(actor) or "Unknown")
    local rootText = LWN.Loc.textOrDefault("LWN_UI_Context_Root", "Living NPC") .. ": " .. tostring(displayName)
    local option = context:addOption(rootText, nil, nil)
    local sub = context:getNew(context)
    context:addSubMenu(option, sub)

    sub:addOption(LWN.Loc.textOrDefault("LWN_UI_Context_Talk", "Talk"), actor, function(target)
        LWN.UIDialogueWindow.show(target)
    end)

    sub:addOption(LWN.Loc.textOrDefault("LWN_UI_Context_Quick", "Quick Command"), actor, function(target)
        LWN.UIRadialMenu.showFor(target)
    end)

    sub:addOption(LWN.Loc.textOrDefault("LWN_UI_Context_Panel", "Open Panel"), actor, function(target)
        LWN.UICommandPanel.show(target)
    end)
end

local function addDebugSubmenu(context, player, actor)
    local settingsLabel = "LWN Tests"
    local settingsOpt = context:addOption(settingsLabel, nil, nil)
    local settingsSub = context:getNew(context)
    context:addSubMenu(settingsOpt, settingsSub)

    local automationOpt = settingsSub:addOption("Automation", nil, nil)
    local automationSub = settingsSub:getNew(settingsSub)
    settingsSub:addSubMenu(automationOpt, automationSub)

    automationSub:addOption("TEST RESET - Clear State", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.resetAutomatedIsoZombieTest then
            LWN.DebugTools.resetAutomatedIsoZombieTest(p)
        end
    end)

    automationSub:addOption("TEST 01 - Spawn Baseline (IsoZombie)", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoZombieTest01 then
            LWN.DebugTools.runAutomatedIsoZombieTest01(p)
        end
    end)

    automationSub:addOption("TEST 01P - IsoPlayer Viability Probe", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoPlayerProbe then
            LWN.DebugTools.runAutomatedIsoPlayerProbe(p)
        end
    end)

    automationSub:addOption("[DISABLED] TEST 01B - Spawn Baseline (IsoSurvivor)", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoSurvivorTest01 then
            LWN.DebugTools.runAutomatedIsoSurvivorTest01(p)
        end
    end)

    automationSub:addOption("TEST 02 - Command Walk", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoZombieTest02 then
            LWN.DebugTools.runAutomatedIsoZombieTest02(p)
        end
    end)

    automationSub:addOption("TEST 03 - Capture Move", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoZombieTest03 then
            LWN.DebugTools.runAutomatedIsoZombieTest03(p)
        end
    end)

    automationSub:addOption("TEST 04 - Return Check", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoZombieTest04 then
            LWN.DebugTools.runAutomatedIsoZombieTest04(p)
        end
    end)

    automationSub:addOption("TEST STATUS - Dump Current", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.dumpAutomatedIsoZombieTestStatus then
            LWN.DebugTools.dumpAutomatedIsoZombieTestStatus(p)
        end
    end)
end

function UIContext.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end

    local player = getPlayerByNum(playerNum)
    local actor = UIContext.findNpcActorInWorldObjects(worldObjects)

    if actor then
        addNpcInteractionSubmenu(context, actor)
    end

    addDebugSubmenu(context, player, actor)
end
