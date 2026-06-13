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
    return modData ~= nil and (modData.LWN_CarrierKind == "isozombie" or modData.LWN_CarrierKind == "bandits")
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

local function clickedSquareFromWorldObjects(worldObjects)
    if BanditCompatibility and BanditCompatibility.GetClickedSquare then
        local ok, square = pcall(BanditCompatibility.GetClickedSquare)
        if ok and square then return square end
    end
    if not worldObjects then return nil end
    for i = 1, #worldObjects do
        local square = protectedCall(worldObjects[i], "getSquare") or protectedCall(worldObjects[i], "getCurrentSquare")
        if square then return square end
    end
    return nil
end

local function recordForActor(actor)
    local npcId = getNpcId(actor)
    return npcId and Store and Store.getNPC and Store.getNPC(npcId) or nil
end

local function displayNameFor(record, actor)
    local modData = getModData(actor)
    if modData and modData.LWN_DisplayName then
        return tostring(modData.LWN_DisplayName)
    end
    local identity = record and record.identity or {}
    local fullName = string.format("%s %s", tostring(identity.firstName or ""), tostring(identity.lastName or ""))
    if fullName:gsub("%s", "") ~= "" then return fullName end
    return tostring(record and record.id or getNpcId(actor) or "Unknown")
end

local function queueCommand(record, actor, intent, squadRole)
    if not record or not actor or not intent then return false end
    record.companion = record.companion or {}
    record.companion.squadRole = squadRole
    if LWN.ActionRuntime and LWN.ActionRuntime.replaceWithIntent then
        return LWN.ActionRuntime.replaceWithIntent(record, actor, intent) == true
    end
    return false
end

local function commandMoveToSquare(record, actor, square)
    if not square or not LWN.ActionIntents then return false end
    local x = protectedCall(square, "getX")
    local y = protectedCall(square, "getY")
    local z = protectedCall(square, "getZ")
    if x == nil or y == nil or z == nil then return false end
    local label = string.format("PLAYER MARK %d,%d,%d", x, y, z)
    local intent = LWN.ActionIntents.moveTo(record, x, y, z, {
        commandKind = "designated_location",
        commandSource = "world_context",
        commandReason = "player_right_click_move",
        destinationLabel = label,
    })
    local queued = queueCommand(record, actor, intent, "move")
    print(string.format(
        "[LWN][Command] move npcId=%s name=%s dest=%s queued=%s",
        tostring(record.id), displayNameFor(record, actor), label, tostring(queued)
    ))
    return queued
end

local function commandFollowPlayer(record, actor)
    if not LWN.ActionIntents then return false end
    local intent = LWN.ActionIntents.followPlayer(record, {
        commandKind = "follow_player",
        commandSource = "world_context",
        commandReason = "player_follow_command",
    })
    local queued = queueCommand(record, actor, intent, "follow")
    print(string.format(
        "[LWN][Command] follow npcId=%s name=%s queued=%s",
        tostring(record.id), displayNameFor(record, actor), tostring(queued)
    ))
    return queued
end

local function commandWait(record, actor)
    if not record or not actor or not LWN.ActionRuntime then return false end
    record.companion = record.companion or {}
    record.companion.squadRole = "wait"
    LWN.ActionRuntime.clear(record, actor)
    print(string.format(
        "[LWN][Command] wait npcId=%s name=%s",
        tostring(record.id), displayNameFor(record, actor)
    ))
    return true
end

local function addCommandOptions(sub, record, actor, clickedSquare)
    if clickedSquare then
        sub:addOption("Move to this location", { record = record, actor = actor, square = clickedSquare }, function(args)
            commandMoveToSquare(args.record, args.actor, args.square)
        end)
    end
    sub:addOption("Follow me", { record = record, actor = actor }, function(args)
        commandFollowPlayer(args.record, args.actor)
    end)
    sub:addOption("Wait here", { record = record, actor = actor }, function(args)
        commandWait(args.record, args.actor)
    end)
end

local function embodiedCommandTargets()
    local targets = {}
    if not (Store and Store.eachNPC) then return targets end
    Store.eachNPC(function(record)
        if record.embodiment and record.embodiment.state == "embodied" then
            local actor = getRegisteredActor(record)
            if isTargetableNpcActor(actor) then
                targets[#targets + 1] = { record = record, actor = actor }
            end
        end
    end)
    table.sort(targets, function(a, b)
        return displayNameFor(a.record, a.actor) < displayNameFor(b.record, b.actor)
    end)
    return targets
end

local function addNpcInteractionSubmenu(context, player, actor, clickedSquare)
    local record = recordForActor(actor)
    local displayName = displayNameFor(record, actor)
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

    addCommandOptions(sub, record, actor, clickedSquare)
end

local function addGroundCommandSubmenu(context, player, clickedSquare)
    if not clickedSquare then return end
    local targets = embodiedCommandTargets()
    if #targets == 0 then return end

    local rootOption = context:addOption("Living NPC Commands", nil, nil)
    local rootSub = context:getNew(context)
    context:addSubMenu(rootOption, rootSub)
    for i = 1, #targets do
        local target = targets[i]
        local npcOption = rootSub:addOption(displayNameFor(target.record, target.actor), nil, nil)
        local npcSub = rootSub:getNew(rootSub)
        rootSub:addSubMenu(npcOption, npcSub)
        addCommandOptions(npcSub, target.record, target.actor, clickedSquare)
    end
end

local function addDebugSubmenu(context, player, actor)
    local settingsLabel = "LWN Tests"
    local settingsOpt = context:addOption(settingsLabel, nil, nil)
    local settingsSub = context:getNew(context)
    context:addSubMenu(settingsOpt, settingsSub)

    settingsSub:addOption("TEST RESET - Clear State", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.resetAutomatedIsoZombieTest then
            LWN.DebugTools.resetAutomatedIsoZombieTest(p)
        end
    end)

    settingsSub:addOption("TEST 01 - Spawn Baseline (Bandits)", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoZombieTest01 then
            LWN.DebugTools.runAutomatedIsoZombieTest01(p)
        end
    end)

    settingsSub:addOption("TEST 02 - Command Walk", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoZombieTest02 then
            LWN.DebugTools.runAutomatedIsoZombieTest02(p)
        end
    end)

    settingsSub:addOption("TEST 03 - Capture Move", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.runAutomatedIsoZombieTest03 then
            LWN.DebugTools.runAutomatedIsoZombieTest03(p)
        end
    end)

    settingsSub:addOption("TEST STATUS - Dump Current", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.dumpAutomatedIsoZombieTestStatus then
            LWN.DebugTools.dumpAutomatedIsoZombieTestStatus(p)
        end
    end)
end

function UIContext.onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test then return end

    local player = getPlayerByNum(playerNum)
    local actor = UIContext.findNpcActorInWorldObjects(worldObjects)
    local clickedSquare = clickedSquareFromWorldObjects(worldObjects)

    if actor then
        addNpcInteractionSubmenu(context, player, actor, clickedSquare)
    else
        addGroundCommandSubmenu(context, player, clickedSquare)
    end

    addDebugSubmenu(context, player, actor)
end
