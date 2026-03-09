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

function Sync.pushRecordToActor(record, actor)
    if not actor then return end
    -- Personality lives mostly in data, but current dialog and greeting state can be hinted by halo note.
    actor:getModData().LWN_NpcId = record.id
end

function Sync.pullActorToRecord(record, actor)
    if not actor then return end

    local stats = actor:getStats()
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

    record.moodles = record.moodles or {}
    for _, mt in ipairs(trackedMoodles) do
        record.moodles[tostring(mt)] = actor:getMoodleLevel(mt)
    end

    record.inventory.equipment = record.inventory.equipment or {}
    local primary = actor:getPrimaryHandItem()
    if primary and primary.getFullType then
        record.inventory.equipment.primaryWeapon = primary:getFullType()
    end

    record.perks = record.perks or {}
    record.perks.Aiming = actor:getPerkLevel(PerkFactory.Perks.Aiming)
    record.perks.FirstAid = actor:getPerkLevel(PerkFactory.Perks.FirstAid)
    record.perks.Woodwork = actor:getPerkLevel(PerkFactory.Perks.Woodwork)
    record.perks.Mechanics = actor:getPerkLevel(PerkFactory.Perks.Mechanics)

    record.anchor.x = math.floor(actor:getX())
    record.anchor.y = math.floor(actor:getY())
    record.anchor.z = math.floor(actor:getZ())
end
