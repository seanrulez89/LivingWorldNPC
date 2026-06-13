require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"

LWN = LWN or {}
LWN.UICommandPanel = LWN.UICommandPanel or {}

-- Read-only status window for the currently targeted embodied NPC.
local Panel = LWN.UICommandPanel
Panel.window = nil
Panel.textbox = nil
Panel.targetNpcId = nil

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

local function getNpcId(actor)
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        return LWN.ActorFactory.getNpcIdFromActor(actor)
    end
    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_NpcId or nil
end

local function isUsableActor(actor)
    if not actor then return false end
    if LWN.ActorFactory and LWN.ActorFactory.isManagedActor then
        return LWN.ActorFactory.isManagedActor(actor)
    end
    return false
end

local function resolveTarget()
    local npcId = Panel.targetNpcId
    if not npcId then return nil, nil end

    if LWN.EmbodimentManager and LWN.EmbodimentManager.getUsableActorByNpcId then
        local actor, record = LWN.EmbodimentManager.getUsableActorByNpcId(npcId)
        if actor and record then
            return actor, record
        end
    end

    local record = LWN.PopulationStore.getNPC(npcId)
    if not record then return nil, nil end
    local actor = LWN.EmbodimentManager and LWN.EmbodimentManager.getActor and LWN.EmbodimentManager.getActor(record) or nil
    if not isUsableActor(actor) then
        return nil, record
    end
    return actor, record
end

local CommandPanelWindow = ISCollapsableWindow:derive("LWNCommandPanelWindow")

function CommandPanelWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()

    local box = ISTextEntryBox:new("", 8, th + 8, self.width - 16, self.height - th - rh - 16)
    box:initialise()
    box:setAnchorRight(true)
    box:setAnchorBottom(true)
    self:addChild(box)
    box:setEditable(false)
    box:setMultipleLine(true)
    box:addScrollBars()

    self.textbox = box
    Panel.textbox = box
end

function CommandPanelWindow:close()
    Panel.hide()
end

function CommandPanelWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = LWN.Loc and LWN.Loc.textOrDefault
        and LWN.Loc.textOrDefault("LWN_UI_CommandPanel_Title", "NPC Status")
        or "NPC Status"
    o.resizable = true
    o.pin = true
    return o
end

function Panel._ensure()
    if Panel.window then return end

    local win = CommandPanelWindow:new(
        LWN.Config.UI.CommandPanelX,
        LWN.Config.UI.CommandPanelY,
        LWN.Config.UI.CommandPanelW,
        LWN.Config.UI.CommandPanelH
    )
    win:initialise()
    win:instantiate()
    win:addToUIManager()
    win:setVisible(false)

    Panel.window = win
end

function Panel.renderTarget(actor)
    if not Panel.textbox then return end

    local npcId = getNpcId(actor)
    local record = npcId and LWN.PopulationStore.getNPC(npcId) or nil
    if not record then
        Panel.hide()
        return
    end

    local encounters = LWN.PopulationStore.root().encounters or {}
    local lastFailure = LWN.ActorFactory and LWN.ActorFactory.getLastFailure and LWN.ActorFactory.getLastFailure() or nil
    local nowHour = getGameTime() and getGameTime():getWorldAgeHours() or 0
    local cooldownLeft = math.max(0, (record.embodiment.cooldownUntilHour or 0) - nowHour)
    local command = record.companion and record.companion.command or {}
    local destination = command.destination or {}
    local snapshot = LWN.NPCStatus and LWN.NPCStatus.snapshot and LWN.NPCStatus.snapshot(record, actor) or nil
    local identity = snapshot and snapshot.identity or {}
    local condition = snapshot and snapshot.condition or {}
    local relationship = snapshot and snapshot.relationship or {}
    local activity = snapshot and snapshot.activity or {}
    local inventory = snapshot and snapshot.inventory or {}
    local embodiment = snapshot and snapshot.embodiment or {}
    destination = activity.commandDestination or destination

    local lines = {}
    lines[#lines + 1] = tostring(identity.name or protectedCall(actor, "getFullName") or npcId)
    lines[#lines + 1] = "Actor: " .. tostring(protectedCall(actor, "getObjectName"))
    lines[#lines + 1] = "Profession: " .. tostring(identity.profession or "unknown")
    lines[#lines + 1] = string.format(
        "Trust %.2f / Fear %.2f / Resentment %.2f",
        tonumber(relationship.trust or 0) or 0,
        tonumber(relationship.fear or 0) or 0,
        tonumber(relationship.resentment or 0) or 0
    )
    lines[#lines + 1] = string.format(
        "Health %.1f / Endurance %.2f / Pain %.2f",
        tonumber(condition.health or 0) or 0,
        tonumber(condition.endurance or 0) or 0,
        tonumber(condition.pain or 0) or 0
    )
    lines[#lines + 1] = string.format(
        "Hunger %.2f / Thirst %.2f / Fatigue %.2f / Panic %.2f",
        tonumber(condition.hunger or 0) or 0,
        tonumber(condition.thirst or 0) or 0,
        tonumber(condition.fatigue or 0) or 0,
        tonumber(condition.panic or 0) or 0
    )
    lines[#lines + 1] = "Goal: " .. tostring(activity.goal or "idle")
    lines[#lines + 1] = "Intent: " .. tostring(activity.intent or "none")
    lines[#lines + 1] = "Carrier: " .. tostring(embodiment.carrierKind or "unknown")
    lines[#lines + 1] = "Shell: " .. tostring(embodiment.shellMode or "unknown")
    lines[#lines + 1] = "Command: " .. tostring(activity.commandKind or "none") .. " / " .. tostring(activity.commandStatus or "idle")
    lines[#lines + 1] = string.format(
        "Destination: %s,%s,%s %s",
        tostring(destination.x or "-"),
        tostring(destination.y or "-"),
        tostring(destination.z or "-"),
        tostring(destination.label or "")
    )
    lines[#lines + 1] = "Squad Role: " .. tostring(activity.squadRole or "none")
    lines[#lines + 1] = string.format(
        "Supplies: food %.1fd / water %.1f / meds %d / ammo %d",
        tonumber(inventory.foodDays or 0) or 0,
        tonumber(inventory.waterUnits or 0) or 0,
        tonumber(inventory.meds or 0) or 0,
        tonumber(inventory.ammo or 0) or 0
    )
    lines[#lines + 1] = "Arc: " .. tostring(record.storyArc and record.storyArc.type or "none")
    lines[#lines + 1] = "Clues: " .. tostring(record.storyArc and record.storyArc.clueCount or 0)
    lines[#lines + 1] = "Memories: " .. tostring(#(record.memories or {}))
    lines[#lines + 1] = "State: " .. tostring(record.embodiment and record.embodiment.state or "unknown") .. string.format(" / CD %.2fh", cooldownLeft)
    if record.embodiment and record.embodiment.lastFailureReason then
        lines[#lines + 1] = "Last Embody Block: " .. tostring(record.embodiment.lastFailureReason) .. " / " .. tostring(record.embodiment.lastFailureDetail or "")
    end
    lines[#lines + 1] = "Encounter currentEligible: " .. tostring(encounters.currentEligibleId)
    lines[#lines + 1] = "Encounter firstTriggered: " .. tostring(encounters.firstEncounterTriggered) .. string.format(" / last %.2fh", tonumber(encounters.lastEncounterHour or -9999) or -9999)
    if lastFailure then
        lines[#lines + 1] = "Last Failure: " .. tostring(lastFailure.npcId) .. " / " .. tostring(lastFailure.reason)
    end

    Panel.textbox:setText(table.concat(lines, "\n"))
end

function Panel.show(actor)
    if not isUsableActor(actor) then return end

    Panel._ensure()
    Panel.targetNpcId = getNpcId(actor)
    local record = Panel.targetNpcId and LWN.PopulationStore.getNPC(Panel.targetNpcId) or nil
    local snapshot = LWN.NPCStatus and LWN.NPCStatus.snapshot and LWN.NPCStatus.snapshot(record, actor) or nil
    if Panel.window and snapshot and snapshot.identity then
        local title = LWN.Loc and LWN.Loc.textOrDefault
            and LWN.Loc.textOrDefault("LWN_UI_CommandPanel_Title", "NPC Status")
            or "NPC Status"
        Panel.window.title = string.format("%s - %s", title, tostring(snapshot.identity.name))
    end
    Panel.window:setVisible(true)
    Panel.window:bringToTop()
    Panel:refresh()
    return true
end

function Panel.hide()
    if Panel.window then
        Panel.window:setVisible(false)
    end
    Panel.targetNpcId = nil
end

function Panel:refresh()
    if not self.targetNpcId then return end
    local actor = resolveTarget()
    if not isUsableActor(actor) then
        self.hide()
        return
    end
    self.renderTarget(actor)
end
