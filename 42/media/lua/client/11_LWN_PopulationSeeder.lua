LWN = LWN or {}
LWN.PopulationSeeder = LWN.PopulationSeeder or {}

local Seeder = LWN.PopulationSeeder
local Store = LWN.PopulationStore

local professions = {
    "unemployed", "burgerflipper", "constructionworker", "nurse", "policeofficer", "carpenter", "mechanic"
}

local traumas = { nil, "lost_family", "failed_rescue", "burned_home", "panic_history" }
local hobbies = { nil, "reading", "radio", "fishing", "music" }
local beliefs = { nil, "never_steal_homes", "protect_family", "self_preservation_first" }

local function rand(a, b)
    return ZombRand(a, b + 1)
end

local function pick(list)
    return list[rand(1, #list)]
end

local function randomName(desc)
    SurvivorFactory.randomName(desc)
    return desc:getForename(), desc:getSurname()
end

function Seeder.seedNewWorld(player, square)
    local root = Store.root()
    if root.seeded then return end

    local count = rand(LWN.Config.Population.InitialMin, LWN.Config.Population.InitialMax)
    local cell = getCell()

    for i = 1, count do
        local id = Store.nextNpcId()
        local seed = ZombRand(1, 2147483646)
        local record = LWN.Schema.newNPCRecord(id, seed)

        local desc = SurvivorFactory.CreateSurvivor()
        desc:setFemale(ZombRand(0, 2) == 0)
        local firstName, lastName = randomName(desc)
        record.identity.firstName = firstName or record.identity.firstName
        record.identity.lastName = lastName or record.identity.lastName
        record.identity.female = desc:isFemale()
        record.identity.profession = pick(professions)

        local px, py = math.floor(player:getX()), math.floor(player:getY())
        record.anchor.x = px + rand(-180, 180)
        record.anchor.y = py + rand(-180, 180)
        record.anchor.z = 0
        record.embodiment.state = "hidden"

        record.backstory.formerProfession = record.identity.profession
        record.backstory.trauma = pick(traumas)
        record.backstory.hobby = pick(hobbies)
        record.backstory.belief = pick(beliefs)
        record.storyArc.type = pick({ nil, "find_relative", "protect_home", "vice_decline", "loot_conflict" })

        record.personality.bravery = ZombRandFloat(0.1, 0.9)
        record.personality.empathy = ZombRandFloat(0.1, 0.9)
        record.personality.greed = ZombRandFloat(0.1, 0.9)
        record.personality.curiosity = ZombRandFloat(0.1, 0.9)
        record.personality.impulsiveness = ZombRandFloat(0.1, 0.9)
        record.personality.loyalty = ZombRandFloat(0.1, 0.9)
        record.personality.paranoia = ZombRandFloat(0.1, 0.9)

        record.motivations.survival = ZombRandFloat(0.7, 1.0)
        record.motivations.safety = ZombRandFloat(0.2, 0.9)
        record.motivations.belonging = ZombRandFloat(0.1, 0.8)
        record.motivations.curiosity = ZombRandFloat(0.0, 0.7)
        record.motivations.pleasure = ZombRandFloat(0.0, 0.6)
        record.motivations.power = ZombRandFloat(0.0, 0.5)

        record.vice.smoker = ZombRand(0, 100) < 12
        record.vice.drinker = ZombRand(0, 100) < 10
        record.vice.reader = ZombRand(0, 100) < 18

        Store.addNPC(record)
    end

    root.seeded = true
end
