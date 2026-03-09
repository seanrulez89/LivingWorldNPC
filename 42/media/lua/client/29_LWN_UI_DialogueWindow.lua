require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextEntryBox"

LWN = LWN or {}
LWN.UIDialogueWindow = LWN.UIDialogueWindow or {}

local W = LWN.UIDialogueWindow
W.window = nil
W.logBox = nil
W.inputBox = nil
W.target = nil

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

local DialogueWindow = ISCollapsableWindow:derive("LWNDialogueWindow")

function DialogueWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()
    local rh = self:resizeWidgetHeight()
    local inputHeight = 24

    local logBox = ISTextEntryBox:new("", 8, th + 8, self.width - 16, self.height - th - rh - inputHeight - 20)
    logBox:initialise()
    logBox:setAnchorRight(true)
    logBox:setAnchorBottom(true)
    logBox:setEditable(false)
    logBox:setMultipleLine(true)
    logBox:addScrollBars()
    self:addChild(logBox)

    local inputBox = ISTextEntryBox:new("", 8, self.height - rh - inputHeight - 8, self.width - 16, inputHeight)
    inputBox:initialise()
    inputBox:setAnchorRight(true)
    inputBox:setAnchorTop(false)
    inputBox:setAnchorBottom(true)
    inputBox:setEditable(true)
    inputBox:setOnlyNumbers(false)
    self:addChild(inputBox)

    self.logBox = logBox
    self.inputBox = inputBox
    W.logBox = logBox
    W.inputBox = inputBox
end

function DialogueWindow:close()
    W.hide()
end

function DialogueWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = "LWN Dialogue"
    o.resizable = true
    o.pin = true
    return o
end

function W._ensure()
    if W.window then return end

    local win = DialogueWindow:new(
        LWN.Config.UI.DialogueWindowX,
        LWN.Config.UI.DialogueWindowY,
        LWN.Config.UI.DialogueWindowW,
        LWN.Config.UI.DialogueWindowH
    )
    win:initialise()
    win:instantiate()
    win:addToUIManager()
    win:setVisible(false)

    W.window = win
end

function W.show(actor)
    if not isUsableActor(actor) then return end

    W._ensure()
    W.target = actor
    W.window:setVisible(true)
    W.window:bringToTop()
    W:refresh()
end

function W.hide()
    if W.window then
        W.window:setVisible(false)
    end
    W.target = nil
end

function W:refresh()
    if not self.target then return end
    if not isUsableActor(self.target) then
        self.hide()
        return
    end

    local npcId = getNpcId(self.target)
    local record = npcId and LWN.PopulationStore.getNPC(npcId) or nil
    if not record then
        self.hide()
        return
    end

    local summary = {
        tostring(protectedCall(self.target, "getFullName") or npcId),
        "Ask about: food / rest / home / family / trade",
        "Core command flow remains menu-driven; this window is an info stub during development.",
        "Arc: " .. tostring(record.storyArc and record.storyArc.type or "none"),
        "Goal: " .. tostring(record.goals and record.goals.longTerm and record.goals.longTerm.kind or "idle"),
    }

    if self.logBox then
        self.logBox:setText(table.concat(summary, "\n"))
    end
end
