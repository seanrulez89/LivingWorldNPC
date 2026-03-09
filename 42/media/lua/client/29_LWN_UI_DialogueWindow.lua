LWN = LWN or {}
LWN.UIDialogueWindow = LWN.UIDialogueWindow or {}

local W = LWN.UIDialogueWindow
W.window = nil
W.logBox = nil
W.inputBox = nil
W.target = nil

function W._ensure()
    if W.window then return end

    local win = NewWindow.new(
        LWN.Config.UI.DialogueWindowX,
        LWN.Config.UI.DialogueWindowY,
        LWN.Config.UI.DialogueWindowW,
        LWN.Config.UI.DialogueWindowH,
        true
    )
    win:setMovable(true)
    win:setVisible(false)
    UIManager.AddUI(win)

    local logBox = UITextBox2.new(UIFont.Small, 8, 24, LWN.Config.UI.DialogueWindowW - 16, LWN.Config.UI.DialogueWindowH - 80, "", true)
    logBox:setEditable(false)
    win:AddChild(logBox)

    local inputBox = UITextBox2.new(UIFont.Small, 8, LWN.Config.UI.DialogueWindowH - 48, LWN.Config.UI.DialogueWindowW - 16, 24, "", true)
    inputBox:setEditable(true)
    inputBox:setMaxTextLength(24)
    win:AddChild(inputBox)

    W.window = win
    W.logBox = logBox
    W.inputBox = inputBox
end

function W.show(actor)
    W._ensure()
    W.target = actor
    W.window:setVisible(true)

    local npcId = actor:getModData().LWN_NpcId
    local record = LWN.PopulationStore.getNPC(npcId)
    local summary = {
        actor:getFullName(),
        "Ask about: food / rest / home / family / trade",
        "This textbox is optional; the core command UX stays menu-driven.",
        "Arc: " .. tostring(record and record.storyArc.type or "none"),
    }
    W.logBox:SetText(table.concat(summary, "\n"))
end

function W.hide()
    if W.window then W.window:setVisible(false) end
    W.target = nil
end
