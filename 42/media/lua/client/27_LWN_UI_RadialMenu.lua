LWN = LWN or {}
LWN.UIRadialMenu = LWN.UIRadialMenu or {}

local UIRadial = LWN.UIRadialMenu
UIRadial.instance = nil
UIRadial.target = nil

function UIRadial._ensure()
    if UIRadial.instance then return UIRadial.instance end

    local x = UIManager.getLastMouseX and UIManager.getLastMouseX() or 300
    local y = UIManager.getLastMouseY and UIManager.getLastMouseY() or 300
    local menu = RadialMenu.new(x, y, LWN.Config.UI.QuickMenuInnerRadius, LWN.Config.UI.QuickMenuOuterRadius)
    UIManager.AddUI(menu)
    UIRadial.instance = menu
    return menu
end

function UIRadial.showFor(actor)
    local menu = UIRadial._ensure()
    menu:clear()
    UIRadial.target = actor

    menu:addSlice("Follow", nil)
    menu:addSlice("Wait", nil)
    menu:addSlice("Guard", nil)
    menu:addSlice("Search", nil)
    menu:addSlice("Retreat", nil)
    menu:addSlice("Panel", nil)
    menu:setVisible(true)
end

function UIRadial.hide()
    if UIRadial.instance then
        UIRadial.instance:setVisible(false)
    end
end

function UIRadial.onCustomUIKeyPressed(key)
    if not UIRadial.instance or not UIRadial.instance:isVisible() then return end
    -- TODO: map confirm/cancel keys through the actual keybinding you choose.
end
