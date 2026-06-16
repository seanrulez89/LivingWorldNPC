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

local function itemFullType(item)
    return item and (protectedCall(item, "getFullType") or protectedCall(item, "getType")) or nil
end

local function itemLabel(item)
    return tostring(protectedCall(item, "getDisplayName") or protectedCall(item, "getName") or itemFullType(item) or "item")
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

local function clickedWorldInventoryItem(worldObjects)
    if not worldObjects then return nil end
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        local item = protectedCall(obj, "getItem")
        if item and itemFullType(item) then
            return item
        end
        if itemFullType(obj) then
            return obj
        end
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
    if LWN.DebugTools and LWN.DebugTools.selectSquadNpc then
        LWN.DebugTools.selectSquadNpc(record.id)
    end
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
        combatPolicy = "self_defense",
    })
    local queued = queueCommand(record, actor, intent, "move")
    print(string.format(
        "[LWN][Command] move npcId=%s name=%s dest=%s queued=%s",
        tostring(record.id), displayNameFor(record, actor), label, tostring(queued)
    ))
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Command", "move_to", {
            npcId = record.id,
            name = displayNameFor(record, actor),
            command = "move_to",
            source = "world_context",
            ok = queued,
            reason = "player_right_click_move",
            x = x,
            y = y,
            z = z,
            detail = label,
            policy = "self_defense",
        })
    end
    return queued
end

local function commandFollowPlayer(record, actor)
    if not LWN.ActionIntents then return false end
    local intent = LWN.ActionIntents.followPlayer(record, {
        commandKind = "follow_player",
        commandSource = "world_context",
        commandReason = "player_follow_command",
        combatPolicy = "stance",
    })
    local queued = queueCommand(record, actor, intent, "follow")
    print(string.format(
        "[LWN][Command] follow npcId=%s name=%s queued=%s",
        tostring(record.id), displayNameFor(record, actor), tostring(queued)
    ))
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Command", "follow_player", {
            npcId = record.id,
            name = displayNameFor(record, actor),
            command = "follow_player",
            source = "world_context",
            ok = queued,
            reason = "player_follow_command",
            policy = "stance",
        })
    end
    return queued
end

local function commandWait(record, actor)
    if not record or not actor or not LWN.ActionRuntime then return false end
    if LWN.DebugTools and LWN.DebugTools.selectSquadNpc then
        LWN.DebugTools.selectSquadNpc(record.id)
    end
    record.companion = record.companion or {}
    record.companion.squadRole = "wait"
    LWN.ActionRuntime.clear(record, actor)
    record.companion.command = record.companion.command or {}
    local command = record.companion.command
    command.kind = "wait"
    command.source = "world_context"
    command.intentKind = nil
    command.combatPolicy = "self_defense"
    command.status = "waiting"
    command.active = true
    command.issuedAt = getGameTime() and getGameTime():getWorldAgeHours() or 0
    command.startedAt = command.issuedAt
    command.completedAt = nil
    command.lastOutcome = nil
    command.lastReason = "player_wait_command"
    print(string.format(
        "[LWN][Command] wait npcId=%s name=%s",
        tostring(record.id), displayNameFor(record, actor)
    ))
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Command", "wait", {
            npcId = record.id,
            name = displayNameFor(record, actor),
            command = "wait",
            source = "world_context",
            ok = true,
            reason = "player_wait_command",
            policy = "self_defense",
        })
    end
    return true
end

local function commandSetDisposition(record, actor, disposition)
    if not record or not LWN.Combat or not LWN.Combat.setDisposition then return false end
    if LWN.DebugTools and LWN.DebugTools.selectSquadNpc then
        LWN.DebugTools.selectSquadNpc(record.id)
    end
    local stance = disposition == "aggressive" and "aggressive" or "passive"
    LWN.Combat.setDisposition(record, stance, "world_context_stance_change")
    local brain = actor and BanditBrain and BanditBrain.Get and BanditBrain.Get(actor) or nil
    if brain then
        brain.lwnCombatReason = "stance_changed"
    end
    print(string.format(
        "[LWN][Command] stance npcId=%s name=%s stance=%s",
        tostring(record.id), displayNameFor(record, actor), stance
    ))
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Command", "combat_stance", {
            npcId = record.id,
            name = displayNameFor(record, actor),
            command = "set_disposition",
            stance = stance,
            source = "world_context",
            ok = true,
            reason = "world_context_stance_change",
        })
    end
    return true
end

local behaviorGuidelines = {
    { id = "follow", label = "Follow" },
    { id = "watch", label = "Watch surroundings" },
    { id = "attack", label = "Attack threats" },
    { id = "flee", label = "Flee danger" },
    { id = "search_supplies", label = "Search supplies" },
    { id = "autonomous", label = "Autonomous behavior" },
}

local function commandSetBehaviorGuideline(record, actor, guideline)
    if not record then return false end
    record.companion = record.companion or {}
    record.companion.behaviorGuideline = guideline or "follow"
    if LWN.DebugTools and LWN.DebugTools.selectSquadNpc then
        LWN.DebugTools.selectSquadNpc(record.id)
    end
    print(string.format(
        "[LWN][Command] behavior npcId=%s name=%s guideline=%s",
        tostring(record.id), displayNameFor(record, actor), tostring(record.companion.behaviorGuideline)
    ))
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Command", "behavior_guideline", {
            npcId = record.id,
            name = displayNameFor(record, actor),
            command = "set_behavior_guideline",
            guideline = record.companion.behaviorGuideline,
            source = "world_context",
            ok = true,
        })
    end
    return true
end

local function commandGiveExistingItem(record, actor, item, player, equip, slot, sourceLabel)
    if not record or not actor or not item or not (LWN.Inventory and LWN.Inventory.transferExistingItemToActor) then
        return false
    end
    if player then
        if protectedCall(player, "getPrimaryHandItem") == item then
            protectedCall(player, "setPrimaryHandItem", nil)
        end
        if protectedCall(player, "getSecondaryHandItem") == item then
            protectedCall(player, "setSecondaryHandItem", nil)
        end
    end
    local result = LWN.Inventory.transferExistingItemToActor(record, actor, item, {
        equip = equip == true,
        slot = slot or "auto",
        reason = "player_give_item",
    }) or {}
    print(string.format(
        "[LWN][Command] give_item npcId=%s name=%s item=%s source=%s equip=%s ok=%s detail=%s actorCount=%s",
        tostring(record.id), displayNameFor(record, actor), tostring(itemFullType(item)),
        tostring(sourceLabel or "unknown"), tostring(equip == true),
        tostring(result.ok == true), tostring(result.detail), tostring(result.actorCount)
    ))
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Command", "give_item", {
            npcId = record.id,
            name = displayNameFor(record, actor),
            command = "give_item",
            item = itemFullType(item),
            source = sourceLabel or "unknown",
            ok = result.ok == true,
            detail = result.detail,
            count = result.actorCount,
            slotName = slot or "auto",
            equip = equip == true,
        })
    end
    return result.ok == true
end

local function addGiveItemOptions(sub, record, actor, player, clickedItem)
    if not (LWN.Inventory and LWN.Inventory.transferExistingItemToActor) then return end

    local giveOption = sub:addOption("Give item", nil, nil)
    local giveSub = sub:getNew(sub)
    sub:addSubMenu(giveOption, giveSub)

    local added = 0
    local primary = protectedCall(player, "getPrimaryHandItem")
    if primary and itemFullType(primary) then
        added = added + 1
        giveSub:addOption("Give primary hand: " .. itemLabel(primary), {
            record = record, actor = actor, item = primary, player = player,
        }, function(args)
            commandGiveExistingItem(args.record, args.actor, args.item, args.player, false, nil, "player_primary")
        end)
        giveSub:addOption("Give/equip primary hand: " .. itemLabel(primary), {
            record = record, actor = actor, item = primary, player = player,
        }, function(args)
            commandGiveExistingItem(args.record, args.actor, args.item, args.player, true, "auto", "player_primary")
        end)
    end

    local secondary = protectedCall(player, "getSecondaryHandItem")
    if secondary and secondary ~= primary and itemFullType(secondary) then
        added = added + 1
        giveSub:addOption("Give secondary hand: " .. itemLabel(secondary), {
            record = record, actor = actor, item = secondary, player = player,
        }, function(args)
            commandGiveExistingItem(args.record, args.actor, args.item, args.player, false, nil, "player_secondary")
        end)
        giveSub:addOption("Give/equip secondary hand: " .. itemLabel(secondary), {
            record = record, actor = actor, item = secondary, player = player,
        }, function(args)
            commandGiveExistingItem(args.record, args.actor, args.item, args.player, true, "auto", "player_secondary")
        end)
    end

    if clickedItem and itemFullType(clickedItem) then
        added = added + 1
        giveSub:addOption("Give clicked world item: " .. itemLabel(clickedItem), {
            record = record, actor = actor, item = clickedItem, player = player,
        }, function(args)
            commandGiveExistingItem(args.record, args.actor, args.item, args.player, false, nil, "world_item")
        end)
        giveSub:addOption("Give/equip clicked world item: " .. itemLabel(clickedItem), {
            record = record, actor = actor, item = clickedItem, player = player,
        }, function(args)
            commandGiveExistingItem(args.record, args.actor, args.item, args.player, true, "auto", "world_item")
        end)
    end

    if added == 0 then
        giveSub:addOption("No held or clicked item", nil, nil)
    end
end

local function addCommandOptions(sub, record, actor, clickedSquare, player, clickedItem)
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
    local disposition = record.combat and record.combat.disposition or "passive"
    sub:addOption(
        disposition == "aggressive" and "Combat stance: Aggressive [current]" or "Set combat stance: Aggressive",
        { record = record, actor = actor },
        function(args) commandSetDisposition(args.record, args.actor, "aggressive") end
    )
    sub:addOption(
        disposition == "passive" and "Combat stance: Passive [current]" or "Set combat stance: Passive",
        { record = record, actor = actor },
        function(args) commandSetDisposition(args.record, args.actor, "passive") end
    )

    local behaviorOption = sub:addOption("Behavior guideline", nil, nil)
    local behaviorSub = sub:getNew(sub)
    sub:addSubMenu(behaviorOption, behaviorSub)
    local currentGuideline = record.companion and record.companion.behaviorGuideline or "follow"
    for i = 1, #behaviorGuidelines do
        local guideline = behaviorGuidelines[i]
        local label = guideline.id == currentGuideline
            and (guideline.label .. " [current]")
            or ("Set: " .. guideline.label)
        behaviorSub:addOption(label, {
            record = record,
            actor = actor,
            guideline = guideline.id,
        }, function(args)
            commandSetBehaviorGuideline(args.record, args.actor, args.guideline)
        end)
    end
    addGiveItemOptions(sub, record, actor, player, clickedItem)
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

local function addNpcInteractionSubmenu(context, player, actor, clickedSquare, clickedItem)
    local record = recordForActor(actor)
    local displayName = displayNameFor(record, actor)
    local rootText = LWN.Loc.textOrDefault("LWN_UI_Context_Root", "Living NPC") .. ": " .. tostring(displayName)
    local option = context:addOption(rootText, nil, nil)
    local sub = context:getNew(context)
    context:addSubMenu(option, sub)

    if LWN.NPCInteraction and LWN.NPCInteraction.list then
        local actions = LWN.NPCInteraction.list(actor, { source = "world_context" })
        for i = 1, #actions do
            local action = actions[i]
            sub:addOption(LWN.NPCInteraction.label(action), {
                actionId = action.id,
                actor = actor,
            }, function(args)
                LWN.NPCInteraction.invoke(args.actionId, args.actor, { source = "world_context" })
            end)
        end
    end

    addCommandOptions(sub, record, actor, clickedSquare, player, clickedItem)
end

local function addGroundCommandSubmenu(context, player, clickedSquare, clickedItem)
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
        addCommandOptions(npcSub, target.record, target.actor, clickedSquare, player, clickedItem)
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

    settingsSub:addOption("Spawn Aggressive Companion", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.spawnAggressiveCompanion then
            LWN.DebugTools.spawnAggressiveCompanion(p)
        end
    end)

    settingsSub:addOption("Spawn Passive Companion", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.spawnPassiveCompanion then
            LWN.DebugTools.spawnPassiveCompanion(p)
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
    local clickedItem = clickedWorldInventoryItem(worldObjects)

    if actor then
        addNpcInteractionSubmenu(context, player, actor, clickedSquare, clickedItem)
    else
        addGroundCommandSubmenu(context, player, clickedSquare, clickedItem)
    end

    addDebugSubmenu(context, player, actor)
end
