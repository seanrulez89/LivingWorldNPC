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

local function safeMoodleLevel(actor, moodleType)
    local ok, level = pcall(function()
        return actor:getMoodleLevel(moodleType)
    end)
    if ok and type(level) == "number" then
        return level
    end
    return 0
end

function Sync.pushRecordToActor(record, actor)
    if not actor then return end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_NpcId = record.id
    end

    protectedCall(actor, "setNPC", true)
    protectedCall(actor, "setIsNPC", true)
    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setForname", record.identity.firstName)
    protectedCall(actor, "setSurname", record.identity.lastName)

    local stats = protectedCall(actor, "getStats")
    if stats then
        stats.hunger = record.stats.hunger or stats.hunger
        stats.thirst = record.stats.thirst or stats.thirst
        stats.fatigue = record.stats.fatigue or stats.fatigue
        stats.boredom = record.stats.boredom or stats.boredom or stats.Boredom
        stats.Panic = record.stats.panic or stats.Panic
        stats.Fear = record.stats.fear or stats.Fear
        stats.stress = record.stats.stress or stats.stress
        stats.Pain = record.stats.pain or stats.Pain
        stats.Drunkenness = record.stats.drunkenness or stats.Drunkenness
        stats.endurance = record.stats.endurance or stats.endurance
        stats.morale = record.stats.morale or stats.morale
    end

    protectedCall(actor, "setHealth", record.stats.health or protectedCall(actor, "getHealth"))
end

function Sync.pullActorToRecord(record, actor)
    if not actor then return end

    local stats = protectedCall(actor, "getStats")
    if stats then
        record.stats.hunger = stats.hunger or record.stats.hunger
        record.stats.thirst = stats.thirst or record.stats.thirst
        record.stats.fatigue = stats.fatigue or record.stats.fatigue
        record.stats.boredom = stats.boredom or stats.Boredom or record.stats.boredom
        record.stats.panic = stats.Panic or record.stats.panic
        record.stats.fear = stats.Fear or record.stats.fear
        record.stats.stress = stats.stress or record.stats.stress
        record.stats.pain = stats.Pain or record.stats.pain
        record.stats.drunkenness = stats.Drunkenness or record.stats.drunkenness
        record.stats.endurance = stats.endurance or record.stats.endurance
        record.stats.morale = stats.morale or record.stats.morale
    end

    record.stats.health = protectedCall(actor, "getHealth") or record.stats.health

    record.moodles = record.moodles or {}
    for _, mt in ipairs(trackedMoodles) do
        record.moodles[tostring(mt)] = safeMoodleLevel(actor, mt)
    end

    record.inventory.equipment = record.inventory.equipment or {}
    local primary = protectedCall(actor, "getPrimaryHandItem")
    if primary and primary.getFullType then
        record.inventory.equipment.primaryWeapon = primary:getFullType()
    end

    record.perks = record.perks or {}
    if PerkFactory and PerkFactory.Perks then
        record.perks.Aiming = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.Aiming) or record.perks.Aiming
        record.perks.FirstAid = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.FirstAid) or record.perks.FirstAid
        record.perks.Woodwork = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.Woodwork) or record.perks.Woodwork
        record.perks.Mechanics = protectedCall(actor, "getPerkLevel", PerkFactory.Perks.Mechanics) or record.perks.Mechanics
    end

    record.anchor.x = math.floor(protectedCall(actor, "getX") or record.anchor.x or 0)
    record.anchor.y = math.floor(protectedCall(actor, "getY") or record.anchor.y or 0)
    record.anchor.z = math.floor(protectedCall(actor, "getZ") or record.anchor.z or 0)
end
