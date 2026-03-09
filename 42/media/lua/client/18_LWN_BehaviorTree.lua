LWN = LWN or {}
LWN.BehaviorTree = LWN.BehaviorTree or {}

local BT = LWN.BehaviorTree
local Intents = nil

local function intents()
    Intents = Intents or LWN.ActionIntents
    return Intents
end

function BT.tick(record, actor, context, chosen)
    if not chosen then
        return intents().idleObserve(record)
    end

    if chosen.kind == "search_food_nearby" then
        return intents().searchNearby(record, "food")
    elseif chosen.kind == "ask_player_for_food" then
        return intents().talk(record, "ask_food")
    elseif chosen.kind == "seek_rest" then
        return intents().rest(record)
    elseif chosen.kind == "retreat_from_threat" then
        return intents().retreat(record, context and context.threatPos)
    elseif chosen.kind == "follow_player" then
        return intents().followPlayer(record)
    elseif chosen.kind == "guard_player" then
        return intents().guardPlayer(record)
    elseif chosen.kind == "reveal_story_clue" then
        return intents().talk(record, "reveal_clue")
    elseif chosen.kind == "move_to_story_anchor" then
        return intents().moveTo(record, record.anchor.x, record.anchor.y, record.anchor.z)
    elseif chosen.kind == "wander_short" then
        return intents().wander(record)
    end

    return intents().idleObserve(record)
end
