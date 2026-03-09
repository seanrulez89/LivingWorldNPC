LWN = LWN or {}
LWN.DialogueRealizer = LWN.DialogueRealizer or {}

local Realizer = LWN.DialogueRealizer

function Realizer.realize(record, response)
    if not response then return nil end

    if response.kind == "accept" and response.reason == "trusted" then
        return { key = "LWN_Dialogue_Accept_Follow" }
    end

    if response.kind == "refuse" and response.reason == "hunger" then
        return { key = "LWN_Dialogue_Refuse_Hunger_Weary" }
    end

    if response.kind == "counteroffer" and response.reason == "hunger" then
        return { text = "I'll help, but we need food first." }
    end

    if response.kind == "delay" and response.reason == "fatigue" then
        return { text = "Give me a minute. I'm exhausted." }
    end

    if response.kind == "topic_shift" then
        return { text = "Not now. We should talk about something else." }
    end

    return { text = "..." }
end

function Realizer.emit(actor, line)
    if not line then return end
    if line.key then
        return LWN.Loc.say(actor, line.key)
    elseif line.text and actor and actor.Say then
        actor:Say(line.text)
        return line.text
    end
end
