LWN = LWN or {}
LWN.UIContextMenu = LWN.UIContextMenu or {}

local UIContext = LWN.UIContextMenu

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

function UIContext.findNpcActorInWorldObjects(worldObjects)
    if not worldObjects or #worldObjects == 0 then return nil end
    local square = worldObjects[1] and worldObjects[1]:getSquare() or nil
    if not square then return nil end

    for i = 0, square:getMovingObjects():size() - 1 do
        local obj = square:getMovingObjects():get(i)
        if isManagedActor(obj) and obj:getModData().LWN_NpcId then
            return obj
        end
    end
    return nil
end

local function addNpcInteractionSubmenu(context, actor)
    local rootText = LWN.Loc.textOrDefault("LWN_UI_Context_Root", "Living NPC") .. ": " .. actor:getFullName()
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
    local settingsLabel = "LWN Settings"
    local settingsOpt = context:addOption(settingsLabel, nil, nil)
    local settingsSub = context:getNew(context)
    context:addSubMenu(settingsOpt, settingsSub)

    local enabled = LWN.DebugTools and LWN.DebugTools.isEnabled and LWN.DebugTools.isEnabled() or false
    local toggleLabel = enabled and "Debug Tools: ON (Click to Disable)" or "Debug Tools: OFF (Click to Enable)"

    settingsSub:addOption(toggleLabel, nil, function()
        if not LWN.DebugTools or not LWN.DebugTools.toggleEnabled then return end
        local after = LWN.DebugTools.toggleEnabled()
        print("[LWN][Debug] devToolsEnabled=" .. tostring(after))
    end)

    if not enabled then return end

    settingsSub:addOption("Debug: Spawn NPC Near Player", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.spawnOneNearPlayer then
            LWN.DebugTools.spawnOneNearPlayer(p)
        end
    end)

    settingsSub:addOption("Debug: Delete Nearest NPC", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.deleteNearestNpc then
            LWN.DebugTools.deleteNearestNpc(p)
        end
    end)

    settingsSub:addOption("Debug: Dump Last Actor Failure", player, function(p)
        if LWN.DebugTools and LWN.DebugTools.dumpLastActorFailure then
            LWN.DebugTools.dumpLastActorFailure(p)
        end
    end)

    if actor and actor:getModData() and actor:getModData().LWN_NpcId then
        local npcId = actor:getModData().LWN_NpcId
        settingsSub:addOption("Debug: Delete This NPC (" .. tostring(npcId) .. ")", player, function(p)
            if LWN.DebugTools and LWN.DebugTools.deleteNpcById then
                LWN.DebugTools.deleteNpcById(npcId, p)
            end
        end)
    end
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
