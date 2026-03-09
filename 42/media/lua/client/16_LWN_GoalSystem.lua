LWN = LWN or {}
LWN.GoalSystem = LWN.GoalSystem or {}

local GoalSystem = LWN.GoalSystem

function GoalSystem.update(record, context)
    local stats = record.stats
    local rel = record.relationshipToPlayer

    local goals = {}

    if stats.hunger > 0.65 then
        table.insert(goals, LWN.Schema.newGoal("secure_food", 0.95))
    end
    if stats.thirst > 0.65 then
        table.insert(goals, LWN.Schema.newGoal("secure_water", 0.92))
    end
    if stats.fatigue > 0.75 then
        table.insert(goals, LWN.Schema.newGoal("rest", 0.90))
    end
    if stats.panic > 0.55 then
        table.insert(goals, LWN.Schema.newGoal("escape_area", 0.98))
    end

    if record.companion.recruited and rel.trust > 0.2 then
        table.insert(goals, LWN.Schema.newGoal("support_player", 0.78))
    end

    if record.storyArc.type == "find_relative" then
        table.insert(goals, LWN.Schema.newGoal("pursue_story_arc", 0.55 + record.storyArc.phase * 0.1))
    end

    if record.vice.smoker and stats.stress > 0.45 then
        table.insert(goals, LWN.Schema.newGoal("seek_smoke", 0.50))
    end
    if record.vice.drinker and stats.boredom > 0.45 then
        table.insert(goals, LWN.Schema.newGoal("seek_drink", 0.40))
    end

    table.sort(goals, function(a, b) return a.priority > b.priority end)
    record.goals.longTerm = goals[1]
    record.goals.shortTerm = goals[2]
    return goals
end
