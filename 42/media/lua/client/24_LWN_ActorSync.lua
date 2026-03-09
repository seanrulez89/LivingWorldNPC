LWN = LWN or {}
LWN.ActorSync = LWN.ActorSync or {}

local Sync = LWN.ActorSync

local trackedMoodles = {
    MoodleType.Hungry,
    MoodleType.Thirst,
    MoodleType.Tired,
    MoodleType.Panic,
    MoodleType.Stress,
    MoodleType.Bored,
    MoodleType.Injured,
    MoodleType.Pain,
    MoodleType.Drunk,
}

local trackedStats = {
    { field = "hunger", enum = CharacterStat and CharacterStat.HUNGER or nil },
    { field = "thirst", enum = CharacterStat and CharacterStat.THIRST or nil },
    { field = "fatigue", enum = CharacterStat and CharacterStat.FATIGUE or nil },
    { field = "boredom", enum = CharacterStat and CharacterStat.BOREDOM or nil },
    { field = "panic", enum = CharacterStat and CharacterStat.PANIC or nil },
    { field = "stress", enum = CharacterStat and CharacterStat.STRESS or nil },
    { field = "pain", enum = CharacterStat and CharacterStat.PAIN or nil },
    { field = "drunkenness", enum = CharacterStat and CharacterStat.INTOXICATION or nil },
    { field = "endurance", enum = CharacterStat and CharacterStat.ENDURANCE or nil },
    { field = "morale", enum = CharacterStat and CharacterStat.MORALE or nil },
}

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end

    local ok, result = pcall(fn, obj, ...)
    if ok then
        return result
    end
    return nil
end

local function clamp(value, minValue, maxValue)
    if type(value) ~= "number" then return nil end
    if type(minValue) == "number" and value < minValue then
        value = minValue
    end
    if type(maxValue) == "number" and value > maxValue then
        value = maxValue
    end
    return value
end

local function enumBounds(statEnum)
    if not statEnum then return 0, 1 end
    local minValue = protectedCall(statEnum, "getMinimumValue")
    local maxValue = protectedCall(statEnum, "getMaximumValue")
    if type(minValue) ~= "number" then minValue = 0 end
    if type(maxValue) ~= "number" then maxValue = 1 end
    return minValue, maxValue
end

local function toEngineValue(statEnum, recordValue)
    if type(recordValue) ~= "number" then return nil end

    local minValue, maxValue = enumBounds(statEnum)
    if maxValue > 1.01 and recordValue >= 0 and recordValue <= 1 then
        return clamp(minValue + ((maxValue - minValue) * recordValue), minValue, maxValue)
    end
    return clamp(recordValue, minValue, maxValue)
end

local function toRecordValue(statEnum, engineValue)
    if type(engineValue) ~= "number" then return nil end

    local minValue, maxValue = enumBounds(statEnum)
    if maxValue > 1.01 and engineValue >= minValue and engineValue <= maxValue then
        local span = maxValue - minValue
        if span <= 0 then
            return clamp(engineValue, minValue, maxValue)
        end
        return clamp((engineValue - minValue) / span, 0, 1)
    end
    return clamp(engineValue, minValue, maxValue)
end

local function safeMoodleLevel(actor, moodleType)
    local ok, level = pcall(function()
        return actor:getMoodleLevel(moodleType)
    end)
    if ok and type(level) == "number" then
        return level
    end
    return 0
end

local function ensureRecordShape(record)
    record.identity = record.identity or {}
    record.stats = record.stats or {}
    record.anchor = record.anchor or {}
    record.inventory = record.inventory or {}
    record.inventory.equipment = record.inventory.equipment or {}
    record.perks = record.perks or {}
    record.moodles = record.moodles or {}
end

local function getNpcId(actor)
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        return LWN.ActorFactory.getNpcIdFromActor(actor)
    end
    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_NpcId or nil
end

local function enforceEmbodiedFlags(record, actor)
    if not actor then return end

    local modData = protectedCall(actor, "getModData")
    if modData and record then
        modData.LWN_NpcId = record.id
    end

    protectedCall(actor, "setNPC", true)
    protectedCall(actor, "setIsNPC", true)
    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setGhostMode", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setForname", record and record.identity and record.identity.firstName or nil)
    protectedCall(actor, "setSurname", record and record.identity and record.identity.lastName or nil)
end

local function applyTrackedStats(record, stats)
    if not stats or not stats.set then return end

    for _, entry in ipairs(trackedStats) do
        if entry.enum then
            local value = toEngineValue(entry.enum, record.stats[entry.field])
            if value ~= nil then
                protectedCall(stats, "set", entry.enum, value)
            end
        end
    end
end

local function readTrackedStats(record, stats)
    if not stats or not stats.get then return end

    for _, entry in ipairs(trackedStats) do
        if entry.enum then
            local engineValue = protectedCall(stats, "get", entry.enum)
            local recordValue = toRecordValue(entry.enum, engineValue)
            if recordValue ~= nil then
                record.stats[entry.field] = recordValue
            end
        end
    end

    record.stats.fear = record.stats.panic or record.stats.fear or 0
end

function Sync.pushRecordToActor(record, actor)
    if not actor then return end
    ensureRecordShape(record)
    enforceEmbodiedFlags(record, actor)

    applyTrackedStats(record, protectedCall(actor, "getStats"))
    protectedCall(actor, "setHealth", record.stats.health or protectedCall(actor, "getHealth"))
end

function Sync.ensureEmbodiedActorState(record, actor)
    ensureRecordShape(record)
    enforceEmbodiedFlags(record, actor)
end

function Sync.pullActorToRecord(record, actor)
    if not actor then return end
    ensureRecordShape(record)

    readTrackedStats(record, protectedCall(actor, "getStats"))
    record.stats.health = protectedCall(actor, "getHealth") or record.stats.health

    for _, mt in ipairs(trackedMoodles) do
        record.moodles[tostring(mt)] = safeMoodleLevel(actor, mt)
    end

    local primary = protectedCall(actor, "getPrimaryHandItem")
    if primary and primary.getFullType then
        record.inventory.equipment.primaryWeapon = primary:getFullType()
    end

    if PerkFactory and PerkFactory.Perks then
        record.perks.Aiming = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.Aiming) or record.perks.Aiming
        record.perks.FirstAid = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.FirstAid) or record.perks.FirstAid
        record.perks.Woodwork = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.Woodwork) or record.perks.Woodwork
        record.perks.Mechanics = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.Mechanics) or record.perks.Mechanics
    end

    record.anchor.x = math.floor(protectedCall(actor, "getX") or record.anchor.x or 0)
    record.anchor.y = math.floor(protectedCall(actor, "getY") or record.anchor.y or 0)
    record.anchor.z = math.floor(protectedCall(actor, "getZ") or record.anchor.z or 0)

    local npcId = getNpcId(actor)
    if npcId and npcId ~= record.id then
        local modData = protectedCall(actor, "getModData")
        if modData then
            modData.LWN_NpcId = record.id
        end
    end
end
