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
    if actor and actor.Say then
        actor:Say(text)
    end
    print("[LWN][UIRadial] " .. tostring(text))
end

local function queueIntent(record, actor, intent, label)
    if not record or not actor or not intent then return false end

    LWN.ActionRuntime.clear(record, actor)
    LWN.ActionRuntime.enqueue(record, intent)
    if LWN.EmbodimentManager and LWN.EmbodimentManager.touchGrace then
        LWN.EmbodimentManager.touchGrace(record)
    end

    if label then
        say(actor, label)
    end
    return true
end

local function commandAccepted(record, actor, command)
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

    if command == "follow" then
        record.companion.squadRole = "follow"
        queueIntent(record, actor, LWN.ActionIntents.followPlayer(record), "Following.")
    elseif command == "wait" then
        record.companion.squadRole = "wait"
        LWN.ActionRuntime.clear(record, actor)
        if LWN.EmbodimentManager and LWN.EmbodimentManager.touchGrace then
            LWN.EmbodimentManager.touchGrace(record)
        end
        say(actor, "Holding here.")
    elseif command == "guard" then
        record.companion.squadRole = "guard"
        queueIntent(record, actor, LWN.ActionIntents.guardPlayer(record), "Watching your back.")
    elseif command == "search" then
        record.companion.squadRole = "search"
        queueIntent(record, actor, LWN.ActionIntents.searchNearby(record, "food"), "I'll search nearby.")
    elseif command == "retreat" then
        record.companion.squadRole = "retreat"
        local player = getPlayer and getPlayer() or nil
        local threatPos = player and { x = player:getX(), y = player:getY() } or nil
        queueIntent(record, actor, LWN.ActionIntents.retreat(record, threatPos), "Falling back.")
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

    menu:addSlice("Follow", nil, UIRadial.onCommand, "follow")
    menu:addSlice("Wait", nil, UIRadial.onCommand, "wait")
    menu:addSlice("Guard", nil, UIRadial.onCommand, "guard")
    menu:addSlice("Search", nil, UIRadial.onCommand, "search")
    menu:addSlice("Retreat", nil, UIRadial.onCommand, "retreat")
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
