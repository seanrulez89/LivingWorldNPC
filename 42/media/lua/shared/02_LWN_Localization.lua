LWN = LWN or {}
LWN.Loc = LWN.Loc or {}

local Loc = LWN.Loc

function Loc.text(key, ...)
    if Translator and Translator.getText then
        return Translator.getText(key, ...)
    end
    return key
end

function Loc.textOrDefault(key, defaultText, ...)
    if Translator and Translator.getTextOrNull then
        local txt = Translator.getTextOrNull(key, ...)
        if txt then return txt end
    end
    return defaultText or key
end

function Loc.say(actor, key, ...)
    local line = Loc.text(key, ...)
    if actor and actor.Say then
        actor:Say(line)
    end
    return line
end
