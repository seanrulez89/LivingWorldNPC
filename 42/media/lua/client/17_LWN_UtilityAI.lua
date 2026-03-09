LWN = LWN or {}
LWN.UtilityAI = LWN.UtilityAI or {}

local Utility = LWN.UtilityAI

function Utility.buildCandidates(record, context)
    local out = {}
    local goal = record.goals.longTerm and record.goals.longTerm.kind or "idle"

    if goal == "secure_food" then
        table.insert(out, { kind = "search_food_nearby" })
        table.insert(out, { kind = "ask_player_for_food" })
    elseif goal == "rest" then
        table.insert(out, { kind = "seek_rest" })
    elseif goal == "escape_area" then
        table.insert(out, { kind = "retreat_from_threat" })
    elseif goal == "support_player" then
        table.insert(out, { kind = "follow_player" })
        table.insert(out, { kind = "guard_player" })
    elseif goal == "pursue_story_arc" then
        table.insert(out, { kind = "reveal_story_clue" })
        table.insert(out, { kind = "move_to_story_anchor" })
    else
        table.insert(out, { kind = "observe_player" })
        table.insert(out, { kind = "wander_short" })
    end

    return out
end

function Utility.score(record, candidate, context)
    local stats = record.stats
    local rel = record.relationshipToPlayer
    local p = record.personality
    local score = 0

    if candidate.kind == "search_food_nearby" then
        score = score + stats.hunger * 2.0 + p.curiosity * 0.2
    elseif candidate.kind == "ask_player_for_food" then
        score = score + stats.hunger * 1.4 + rel.trust * 0.6 - rel.resentment * 0.5
    elseif candidate.kind == "seek_rest" then
        score = score + stats.fatigue * 2.0
    elseif candidate.kind == "retreat_from_threat" then
        score = score + stats.panic * 1.8 + p.paranoia * 0.5 - p.bravery * 0.4
    elseif candidate.kind == "follow_player" then
        score = score + rel.trust * 0.8 + p.loyalty * 0.5
    elseif candidate.kind == "guard_player" then
        score = score + rel.trust * 0.7 + p.bravery * 0.5
    elseif candidate.kind == "reveal_story_clue" then
        score = score + rel.trust * 0.4 + record.storyArc.phase * 0.3
    elseif candidate.kind == "move_to_story_anchor" then
        score = score + 0.45 + record.storyArc.phase * 0.15
    elseif candidate.kind == "observe_player" then
        score = score + p.paranoia * 0.4 + p.curiosity * 0.2
    elseif candidate.kind == "wander_short" then
        score = score + stats.boredom * 0.8 + p.curiosity * 0.3
    end

    candidate.score = score
    return score
end

function Utility.choose(record, context)
    local best, bestScore = nil, -math.huge
    for _, candidate in ipairs(Utility.buildCandidates(record, context)) do
        local score = Utility.score(record, candidate, context)
        if score > bestScore then
            best = candidate
            bestScore = score
        end
    end
    return best
end
