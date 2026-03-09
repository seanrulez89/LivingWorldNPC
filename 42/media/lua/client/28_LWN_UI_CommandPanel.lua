LWN = LWN or {}
LWN.UICommandPanel = LWN.UICommandPanel or {}

local Panel = LWN.UICommandPanel
Panel.window = nil
Panel.textbox = nil
Panel.target = nil

function Panel._ensure()
    if Panel.window then return end

    local win = NewWindow.new(
        LWN.Config.UI.CommandPanelX,
        LWN.Config.UI.CommandPanelY,
        LWN.Config.UI.CommandPanelW,
        LWN.Config.UI.CommandPanelH,
        true
    )
    win:setMovable(true)
    win:setVisible(false)
    UIManager.AddUI(win)

    local box = UITextBox2.new(UIFont.Small, 8, 24, LWN.Config.UI.CommandPanelW - 16, LWN.Config.UI.CommandPanelH - 32, "", true)
    box:setEditable(false)
    win:AddChild(box)

    Panel.window = win
    Panel.textbox = box
end

function Panel.renderTarget(actor)
    local npcId = actor:getModData().LWN_NpcId
    local record = LWN.PopulationStore.getNPC(npcId)
    if not record then return end

    local encounters = LWN.PopulationStore.root().encounters or {}
    local lastFailure = LWN.ActorFactory and LWN.ActorFactory.getLastFailure and LWN.ActorFactory.getLastFailure() or nil
    local nowHour = getGameTime() and getGameTime():getWorldAgeHours() or 0
    local cooldownLeft = math.max(0, (record.embodiment.cooldownUntilHour or 0) - nowHour)

    local lines = {}
    table.insert(lines, actor:getFullName())
    table.insert(lines, "Actor: " .. tostring(actor:getObjectName()))
    table.insert(lines, "Profession: " .. tostring(record.identity.profession))
    table.insert(lines, string.format("Trust %.2f / Fear %.2f / Resentment %.2f", record.relationshipToPlayer.trust, record.relationshipToPlayer.fear, record.relationshipToPlayer.resentment))
    table.insert(lines, string.format("Hunger %.2f / Fatigue %.2f / Panic %.2f", record.stats.hunger, record.stats.fatigue, record.stats.panic))
    table.insert(lines, "Goal: " .. tostring(record.goals.longTerm and record.goals.longTerm.kind or "idle"))
    table.insert(lines, "Arc: " .. tostring(record.storyArc.type or "none"))
    table.insert(lines, "Memories: " .. tostring(#(record.memories or {})))
    table.insert(lines, "State: " .. tostring(record.embodiment.state) .. string.format(" / CD %.2fh", cooldownLeft))
    table.insert(lines, "Encounter currentEligible: " .. tostring(encounters.currentEligibleId))
    table.insert(lines, "Encounter firstTriggered: " .. tostring(encounters.firstEncounterTriggered) .. string.format(" / last %.2fh", tonumber(encounters.lastEncounterHour or -9999) or -9999))
    if lastFailure then
        table.insert(lines, "Last Failure: " .. tostring(lastFailure.npcId) .. " / " .. tostring(lastFailure.reason))
    end

    Panel.textbox:SetText(table.concat(lines, "\n"))
end

function Panel.show(actor)
    Panel._ensure()
    Panel.target = actor
    Panel.window:setVisible(true)
    Panel:refresh()
end

function Panel.hide()
    if Panel.window then Panel.window:setVisible(false) end
    Panel.target = nil
end

function Panel:refresh()
    if self.target then
        self.renderTarget(self.target)
    end
end
