require "ISUI/ISRadialMenu"

LWN = LWN or {}
LWN.UIRadialMenu = LWN.UIRadialMenu or {}

local UIRadial = LWN.UIRadialMenu
UIRadial.instance = nil
UIRadial.targetNpcId = nil

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

local function isUsableActor(actor)
    if not actor then return false end
    if LWN.ActorFactory and LWN.ActorFactory.isManagedActor then
        return LWN.ActorFactory.isManagedActor(actor)
    end
    return false
end

local function getNpcId(actor)
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        return LWN.ActorFactory.getNpcIdFromActor(actor)
    end
    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_NpcId or nil
end

local function resolveRecord(actor)
    if not isUsableActor(actor) then return nil, nil, nil end

    local npcId = getNpcId(actor)
    if not npcId then return nil, nil, nil end

    return LWN.PopulationStore.getNPC(npcId), npcId, actor
end

local function resolveTarget()
    local npcId = UIRadial.targetNpcId
    if not npcId then return nil, nil end

    if LWN.EmbodimentManager and LWN.EmbodimentManager.getUsableActorByNpcId then
        local actor, record = LWN.EmbodimentManager.getUsableActorByNpcId(npcId)
        if actor and record then
            return record, actor
        end
    end

    local record = LWN.PopulationStore.getNPC(npcId)
    if not record then return nil, nil end
    local actor = LWN.EmbodimentManager and LWN.EmbodimentManager.getActor and LWN.EmbodimentManager.getActor(record) or nil
    if not isUsableActor(actor) then
        return record, nil
    end
    return record, actor
end

local function say(actor, text)
    local modData = protectedCall(actor, "getModData")
    if actor and actor.Say and not (modData and modData.LWN_CarrierKind == "bandits") then
        actor:Say(text)
    end
    print("[LWN][UIRadial] " .. tostring(text))
end

local function queueIntent(record, actor, intent, label)
    if not record or not actor or not intent then return false end

    if LWN.ActionRuntime and LWN.ActionRuntime.replaceWithIntent then
        LWN.ActionRuntime.replaceWithIntent(record, actor, intent)
    else
        LWN.ActionRuntime.clear(record, actor)
        LWN.ActionRuntime.enqueue(record, intent)
        if LWN.EmbodimentManager and LWN.EmbodimentManager.touchGrace then
            LWN.EmbodimentManager.touchGrace(record)
        end
    end

    if label then
        say(actor, label)
    end
    return true
end

local function chooseDesignatedDestination(actor)
    local player = getPlayer and getPlayer() or nil
    local cell = getCell and getCell() or nil
    if not player or not actor or not cell then
        return nil
    end

    local px = math.floor(protectedCall(player, "getX") or 0)
    local py = math.floor(protectedCall(player, "getY") or 0)
    local pz = math.floor(protectedCall(player, "getZ") or 0)
    local ax = tonumber(protectedCall(actor, "getX") or px) or px
    local ay = tonumber(protectedCall(actor, "getY") or py) or py
    local candidates = {
        { x = px + 6, y = py, z = pz, label = "TEST EAST 6" },
        { x = px - 6, y = py, z = pz, label = "TEST WEST 6" },
        { x = px, y = py + 6, z = pz, label = "TEST SOUTH 6" },
        { x = px, y = py - 6, z = pz, label = "TEST NORTH 6" },
    }

    local best = nil
    local bestD2 = -1
    for i = 1, #candidates do
        local candidate = candidates[i]
        if cell:getGridSquare(candidate.x, candidate.y, candidate.z) then
            local dx = candidate.x - ax
            local dy = candidate.y - ay
            local d2 = dx * dx + dy * dy
            if d2 > bestD2 then
                best = candidate
                bestD2 = d2
            end
        end
    end

    return best
end

local function isMinimalDummyRecord(record)
    return record and record.dummy and record.dummy.enabled == true
end

local function commandAccepted(record, actor, command)
    if isMinimalDummyRecord(record) then
        return { kind = "accept", reason = "minimal_dummy" }
    end

    if record.companion and record.companion.recruited then
        return { kind = "accept", reason = "trusted" }
    end

    local response = LWN.Social and LWN.Social.commandResponse and LWN.Social.commandResponse(record, command, {}) or nil
    if response then
        local line = LWN.DialogueRealizer and LWN.DialogueRealizer.realize and LWN.DialogueRealizer.realize(record, response) or nil
        if line and LWN.DialogueRealizer and LWN.DialogueRealizer.emit then
            LWN.DialogueRealizer.emit(actor, line)
        end
        return response
    end

    return { kind = "accept", reason = "fallback" }
end

function UIRadial._ensure(playerNum)
    if UIRadial.instance then
        return UIRadial.instance
    end

    local menu = ISRadialMenu:new(0, 0, LWN.Config.UI.QuickMenuInnerRadius, LWN.Config.UI.QuickMenuOuterRadius, playerNum or 0)
    menu:initialise()
    local onMouseDownOutside = menu.onMouseDownOutside
    menu.onMouseDownOutside = function(self, x, y)
        UIRadial.targetNpcId = nil
        onMouseDownOutside(self, x, y)
    end

    UIRadial.instance = menu
    return menu
end

function UIRadial.hide()
    if UIRadial.instance and UIRadial.instance:getIsVisible() then
        UIRadial.instance:undisplay()
    end
    UIRadial.targetNpcId = nil
end

function UIRadial.onCommand(command)
    local record, actor = resolveTarget()
    UIRadial.targetNpcId = nil
    if not record or not actor then
        UIRadial.hide()
        return
    end
    record.companion = record.companion or {}

    local response = commandAccepted(record, actor, command)
    if response and response.kind ~= "accept" then
        return
    end

    if command == "move" then
        local destination = chooseDesignatedDestination(actor)
        if not destination then
            say(actor, "No test destination found.")
            return
        end
        record.companion.squadRole = "move"
        if record.dummy then
            record.dummy.state = "move_to"
        end
        queueIntent(record, actor, LWN.ActionIntents.moveTo(record, destination.x, destination.y, destination.z, {
            commandKind = "designated_location",
            commandSource = "ui_radial",
            commandReason = "player_designated_move",
            destinationLabel = destination.label,
        }), string.format("Moving to %s.", tostring(destination.label)))
    elseif command == "wait" then
        record.companion.squadRole = "wait"
        if record.dummy then
            record.dummy.state = "idle"
        end
        LWN.ActionRuntime.clear(record, actor)
        if LWN.EmbodimentManager and LWN.EmbodimentManager.touchGrace then
            LWN.EmbodimentManager.touchGrace(record)
        end
        say(actor, "Holding here.")
    elseif command == "follow" then
        record.companion.squadRole = "follow"
        if record.dummy then
            record.dummy.state = "follow_player"
        end
        queueIntent(record, actor, LWN.ActionIntents.followPlayer(record, {
            commandKind = "follow_player",
            commandSource = "ui_radial",
            commandReason = "player_follow_command",
        }), "Following you.")
    elseif command == "panel" then
        if LWN.UICommandPanel and LWN.UICommandPanel.show then
            LWN.UICommandPanel.show(actor)
        end
    end
end

function UIRadial.showFor(actor)
    if not isUsableActor(actor) then return end

    local menu = UIRadial._ensure(0)
    UIRadial.targetNpcId = getNpcId(actor)

    menu:clear()
    menu:setX((UIManager.getLastMouseX and UIManager.getLastMouseX() or 300) - LWN.Config.UI.QuickMenuOuterRadius)
    menu:setY((UIManager.getLastMouseY and UIManager.getLastMouseY() or 300) - LWN.Config.UI.QuickMenuOuterRadius)

    menu:addSlice("Move", nil, UIRadial.onCommand, "move")
    menu:addSlice("Follow", nil, UIRadial.onCommand, "follow")
    menu:addSlice("Wait", nil, UIRadial.onCommand, "wait")
    menu:addSlice("Panel", nil, UIRadial.onCommand, "panel")

    menu:setVisible(true)
    menu:addToUIManager()
end

function UIRadial.refresh()
    if not UIRadial.targetNpcId then return end
    local _, actor = resolveTarget()
    if not isUsableActor(actor) then
        UIRadial.hide()
    end
end

function UIRadial.onCustomUIKeyPressed(key)
    if not UIRadial.instance or not UIRadial.instance:getIsVisible() then return end
    if key then
        UIRadial.hide()
    end
end
