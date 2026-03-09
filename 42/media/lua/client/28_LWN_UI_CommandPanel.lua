require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"

LWN = LWN or {}
LWN.UICommandPanel = LWN.UICommandPanel or {}

local Panel = LWN.UICommandPanel
Panel.window = nil
Panel.textbox = nil
Panel.target = nil

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

local CommandPanelWindow = ISCollapsableWindow:derive("LWNCommandPanelWindow")

function CommandPanelWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()

    local box = ISTextEntryBox:new("", 8, th + 8, self.width - 16, self.height - th - rh - 16)
    box:initialise()
    box:setAnchorRight(true)
    box:setAnchorBottom(true)
    box:setEditable(false)
    box:setMultipleLine(true)
    box:addScrollBars()
    self:addChild(box)

    self.textbox = box
    Panel.textbox = box
end

function CommandPanelWindow:close()
    Panel.hide()
end

function CommandPanelWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = "LWN Command Panel"
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

    local lines = {}
    lines[#lines + 1] = tostring(protectedCall(actor, "getFullName") or npcId)
    lines[#lines + 1] = "Actor: " .. tostring(protectedCall(actor, "getObjectName"))
    lines[#lines + 1] = "Profession: " .. tostring(record.identity and record.identity.profession or "unknown")
    lines[#lines + 1] = string.format(
        "Trust %.2f / Fear %.2f / Resentment %.2f",
        tonumber(record.relationshipToPlayer and record.relationshipToPlayer.trust or 0) or 0,
        tonumber(record.relationshipToPlayer and record.relationshipToPlayer.fear or 0) or 0,
        tonumber(record.relationshipToPlayer and record.relationshipToPlayer.resentment or 0) or 0
    )
    lines[#lines + 1] = string.format(
        "Hunger %.2f / Fatigue %.2f / Panic %.2f",
        tonumber(record.stats and record.stats.hunger or 0) or 0,
        tonumber(record.stats and record.stats.fatigue or 0) or 0,
        tonumber(record.stats and record.stats.panic or 0) or 0
    )
    lines[#lines + 1] = "Goal: " .. tostring(record.goals and record.goals.longTerm and record.goals.longTerm.kind or "idle")
    lines[#lines + 1] = "Squad Role: " .. tostring(record.companion and record.companion.squadRole or "none")
    lines[#lines + 1] = "Arc: " .. tostring(record.storyArc and record.storyArc.type or "none")
    lines[#lines + 1] = "Memories: " .. tostring(#(record.memories or {}))
    lines[#lines + 1] = "State: " .. tostring(record.embodiment and record.embodiment.state or "unknown") .. string.format(" / CD %.2fh", cooldownLeft)
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
    Panel.target = actor
    Panel.window:setVisible(true)
    Panel.window:bringToTop()
    Panel:refresh()
end

function Panel.hide()
    if Panel.window then
        Panel.window:setVisible(false)
    end
    Panel.target = nil
end

function Panel:refresh()
    if not self.target then return end
    if not isUsableActor(self.target) then
        self.hide()
        return
    end
    self.renderTarget(self.target)
end
