LWN = LWN or {}
LWN.Memory = LWN.Memory or {}

local Memory = LWN.Memory

function Memory.add(record, kind, salience, data)
    record.memories = record.memories or {}
    table.insert(record.memories, 1, LWN.Schema.newMemory(kind, salience, data))
end

function Memory.tickDecay(record)
    local decay = LWN.Config.Social.MemoryDecayPerDay or 0.02
    local keep = {}
    for _, memory in ipairs(record.memories or {}) do
        memory.salience = memory.salience - decay
        if memory.salience > 0.01 then
            table.insert(keep, memory)
        end
    end
    record.memories = keep
end

function Memory.has(record, kind)
    for _, memory in ipairs(record.memories or {}) do
        if memory.kind == kind then return true end
    end
    return false
end

function Memory.score(record, kind)
    local score = 0
    for _, memory in ipairs(record.memories or {}) do
        if memory.kind == kind then
            score = score + (memory.salience or 0)
        end
    end
    return score
end
