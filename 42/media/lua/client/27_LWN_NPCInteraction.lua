LWN = LWN or {}
LWN.NPCInteraction = LWN.NPCInteraction or {}

local Interaction = LWN.NPCInteraction

Interaction.actions = Interaction.actions or {}

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function getNpcId(actor)
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        return LWN.ActorFactory.getNpcIdFromActor(actor)
    end
    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_NpcId or nil
end

function Interaction.resolve(actor)
    if not actor then return nil end
    if LWN.ActorFactory
        and LWN.ActorFactory.isManagedActor
        and LWN.ActorFactory.isManagedActor(actor) ~= true
    then
        return nil
    end
    local npcId = getNpcId(actor)
    local record = npcId and LWN.PopulationStore and LWN.PopulationStore.getNPC
        and LWN.PopulationStore.getNPC(npcId)
        or nil
    if not npcId or not record then return nil end
    return {
        actor = actor,
        record = record,
        npcId = npcId,
    }
end

function Interaction.register(id, spec)
    if type(id) ~= "string" or id == "" or type(spec) ~= "table" then
        return false
    end
    spec.id = id
    Interaction.actions[id] = spec
    return true
end

function Interaction.list(actor, context)
    local target = Interaction.resolve(actor)
    if not target then return {} end
    target.context = context or {}

    local actions = {}
    for _, action in pairs(Interaction.actions) do
        local available = true
        if type(action.isAvailable) == "function" then
            local ok, result = pcall(action.isAvailable, target)
            available = ok and result == true
        end
        if available then
            actions[#actions + 1] = action
        end
    end
    table.sort(actions, function(a, b)
        local aOrder = tonumber(a.order) or 100
        local bOrder = tonumber(b.order) or 100
        if aOrder == bOrder then return tostring(a.id) < tostring(b.id) end
        return aOrder < bOrder
    end)
    return actions
end

function Interaction.label(action)
    if not action then return "Interaction" end
    if LWN.Loc and LWN.Loc.textOrDefault and action.labelKey then
        return LWN.Loc.textOrDefault(action.labelKey, action.defaultLabel or action.id)
    end
    return action.defaultLabel or action.id
end

function Interaction.invoke(id, actor, context)
    local action = Interaction.actions[id]
    local target = Interaction.resolve(actor)
    if not action or not target or type(action.run) ~= "function" then
        return false
    end
    target.context = context or {}
    local ok, result = pcall(action.run, target)
    if not ok then
        print(string.format(
            "[LWN][Interaction] failed npcId=%s action=%s error=%s",
            tostring(target.npcId), tostring(id), tostring(result)
        ))
        return false
    end
    local succeeded = result ~= false
    print(string.format(
        "[LWN][Interaction] %s npcId=%s action=%s source=%s",
        succeeded and "invoked" or "rejected",
        tostring(target.npcId), tostring(id), tostring(target.context.source or "unknown")
    ))
    return succeeded
end

Interaction.register("status", {
    order = 10,
    labelKey = "LWN_UI_Context_Panel",
    defaultLabel = "View Status",
    run = function(target)
        if not (LWN.UICommandPanel and LWN.UICommandPanel.show) then return false end
        return LWN.UICommandPanel.show(target.actor) == true
    end,
})

Interaction.register("inventory", {
    order = 15,
    defaultLabel = "Open Inventory",
    run = function(target)
        if not (LWN.NPCInventoryUI and LWN.NPCInventoryUI.open) then return false end
        local playerNum = target.context and tonumber(target.context.playerNum) or 0
        return LWN.NPCInventoryUI.open(target.actor, playerNum) == true
    end,
})

Interaction.register("talk", {
    order = 20,
    labelKey = "LWN_UI_Context_Talk",
    defaultLabel = "Talk",
    run = function(target)
        if not (LWN.UIDialogueWindow and LWN.UIDialogueWindow.show) then return false end
        return LWN.UIDialogueWindow.show(target.actor) == true
    end,
})

Interaction.register("quick_command", {
    order = 30,
    labelKey = "LWN_UI_Context_Quick",
    defaultLabel = "Quick Command",
    run = function(target)
        if not (LWN.UIRadialMenu and LWN.UIRadialMenu.showFor) then return false end
        return LWN.UIRadialMenu.showFor(target.actor) == true
    end,
})
