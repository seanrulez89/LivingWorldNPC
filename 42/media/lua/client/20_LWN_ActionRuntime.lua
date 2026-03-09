LWN = LWN or {}
LWN.ActionRuntime = LWN.ActionRuntime or {}

local Runtime = LWN.ActionRuntime

Runtime.Queues = Runtime.Queues or {}

local function queueFor(id)
    Runtime.Queues[id] = Runtime.Queues[id] or {}
    return Runtime.Queues[id]
end

function Runtime.clear(record, actor)
    Runtime.Queues[record.id] = {}
    if actor and actor.StopAllActionQueue then
        actor:StopAllActionQueue()
    end
end

function Runtime.enqueue(record, intent)
    local q = queueFor(record.id)
    table.insert(q, intent)
end

function Runtime.peek(record)
    local q = queueFor(record.id)
    return q[1]
end

function Runtime.pop(record)
    local q = queueFor(record.id)
    table.remove(q, 1)
end

function Runtime._newTimedActionTable(record, actor, intent)
    local t = {}
    t.maxTime = 60
    t.stopOnWalk = true
    t.stopOnRun = true

    function t:isValid()
        return actor ~= nil
    end

    function t:start()
        -- Example animation selection only.
        if intent.kind == "rest" then
            self.javaAction:setActionAnim("Loot")
        end
    end

    function t:update()
        -- no-op placeholder
    end

    function t:perform()
        -- resolve logical effect here
        intent.done = true
        if actor and actor.StopTimedActionAnim then
            actor:StopTimedActionAnim()
        end
    end

    function t:stop()
        intent.failed = true
    end

    return t
end

function Runtime._startTimedAction(record, actor, intent)
    local t = Runtime._newTimedActionTable(record, actor, intent)
    -- Constructor shape follows the exposed Java class and the long-used timed-action helper pattern.
    t.javaAction = LuaTimedAction.new(t, actor)

    if actor.QueueAction then
        actor:QueueAction(t.javaAction)
    else
        actor:StartAction(t.javaAction)
    end
end

function Runtime._startMovement(record, actor, intent)
    local pf = actor:getPathFindBehavior2()
    if not pf then
        intent.failed = true
        return
    end

    if intent.kind == "move_to" then
        pf:pathToLocation(intent.data.x, intent.data.y, intent.data.z)
    elseif intent.kind == "follow_player" then
        local player = getPlayer()
        if player then pf:pathToCharacter(player) end
    elseif intent.kind == "retreat" then
        local px, py, pz = actor:getX(), actor:getY(), actor:getZ()
        local tx = math.floor(px + (px - (intent.data.threatPos and intent.data.threatPos.x or px)) * 4)
        local ty = math.floor(py + (py - (intent.data.threatPos and intent.data.threatPos.y or py)) * 4)
        pf:pathToLocation(tx, ty, pz)
    elseif intent.kind == "wander_short" then
        local px, py, pz = math.floor(actor:getX()), math.floor(actor:getY()), math.floor(actor:getZ())
        pf:pathToLocation(px + ZombRand(-5, 6), py + ZombRand(-5, 6), pz)
    end

    intent.started = true
end

function Runtime._tickMovementIntent(actor, intent)
    local pf = actor:getPathFindBehavior2()
    if not pf then return false end

    local result = pf:update()
    if tostring(result) == "Succeeded" then
        intent.done = true
        return true
    elseif tostring(result) == "Failed" then
        intent.failed = true
        return true
    end
    return false
end

function Runtime.tick(record, actor)
    local current = Runtime.peek(record)
    if not current then return end

    if current.kind == "move_to" or current.kind == "follow_player" or current.kind == "retreat" or current.kind == "wander_short" then
        if not current.started then
            Runtime._startMovement(record, actor, current)
        else
            Runtime._tickMovementIntent(actor, current)
        end
    elseif current.kind == "talk" then
        if not current.started then
            current.started = true
            if current.data.topic == "ask_food" then
                actor:Say("Do you have anything to eat?")
            elseif current.data.topic == "reveal_clue" then
                actor:Say("I think I know where to look next.")
            end
            current.done = true
        end
    elseif current.kind == "rest" or current.kind == "search_nearby" then
        if not current.started then
            current.started = true
            Runtime._startTimedAction(record, actor, current)
        else
            -- Timed action completion is observed through flags set by the action table.
        end
    elseif current.kind == "idle_observe" then
        current.done = true
    elseif current.kind == "attack_melee" then
        if current.data.target and actor.AttemptAttack then
            actor:faceThisObject(current.data.target)
            actor:AttemptAttack(1.0)
        end
        current.done = true
    end

    if current.done or current.failed then
        Runtime.pop(record)
    end
end
