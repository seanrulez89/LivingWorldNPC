LWN = LWN or {}
LWN.ActionIntents = LWN.ActionIntents or {}

local Intents = LWN.ActionIntents

function Intents.moveTo(record, x, y, z)
    return LWN.Schema.newIntent("move_to", { x = x, y = y, z = z })
end

function Intents.followPlayer(record)
    return LWN.Schema.newIntent("follow_player", {})
end

function Intents.guardPlayer(record)
    return LWN.Schema.newIntent("guard_player", {})
end

function Intents.retreat(record, threatPos)
    return LWN.Schema.newIntent("retreat", { threatPos = threatPos })
end

function Intents.wander(record)
    return LWN.Schema.newIntent("wander_short", {})
end

function Intents.rest(record)
    return LWN.Schema.newIntent("rest", {})
end

function Intents.searchNearby(record, topic)
    return LWN.Schema.newIntent("search_nearby", { topic = topic })
end

function Intents.talk(record, topic)
    return LWN.Schema.newIntent("talk", { topic = topic })
end

function Intents.attackMelee(record, target)
    return LWN.Schema.newIntent("attack_melee", { target = target })
end

function Intents.idleObserve(record)
    return LWN.Schema.newIntent("idle_observe", {})
end
