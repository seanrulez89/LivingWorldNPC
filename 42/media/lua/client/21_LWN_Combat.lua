LWN = LWN or {}
LWN.Combat = LWN.Combat or {}

local Combat = LWN.Combat

function Combat.buildContext(record, actor)
    local ctx = { threatPos = nil, hostile = nil, threatScore = 0 }
    if not actor or not actor.getSquare then return ctx end

    local square = actor:getSquare()
    if not square or not square.getMovingObjects then return ctx end

    local objects = square:getMovingObjects()
    if not objects then return ctx end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof and instanceof(obj, "IsoZombie") then
            ctx.hostile = obj
            ctx.threatScore = ctx.threatScore + 0.5
            ctx.threatPos = { x = obj:getX(), y = obj:getY() }
        end
    end

    ctx.threatScore = ctx.threatScore + record.stats.panic
    ctx.threatScore = ctx.threatScore - record.personality.bravery * 0.3
    return ctx
end

function Combat.chooseIntent(record, actor, ctx)
    if not ctx or not ctx.hostile then return nil end

    if record.stats.health < 35 or record.stats.panic > 0.65 then
        return LWN.ActionIntents.retreat(record, ctx.threatPos)
    end

    return LWN.ActionIntents.attackMelee(record, ctx.hostile)
end
