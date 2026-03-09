LWN = LWN or {}
LWN.Schema = LWN.Schema or {}

local Schema = LWN.Schema

local function copyTable(src)
    local dst = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = copyTable(v)
        else
            dst[k] = v
        end
    end
    return dst
end

Schema.copyTable = copyTable

function Schema.newRoot()
    return {
        version = LWN.Config.Version,
        seeded = false,
        nextNpcId = 1,
        npcs = {},
        embodied = {},
        encounters = {
            firstEncounterTriggered = false,
            travelledTiles = 0,
            hasSlept = false,
            currentEligibleId = nil,
            lastEncounterHour = -9999,
        },
        worldStory = {
            clues = {},
            pendingEvents = {},
            visitedStrategicBuildings = {},
        },
        legacy = {
            pending = nil,
            candidates = {},
        },
        debug = {
            devToolsEnabled = false,
        },
    }
end

function Schema.newMemory(kind, salience, data)
    return {
        kind = kind,
        salience = salience or 0.5,
        createdDay = getGameTime() and getGameTime():getWorldAgeHours() / 24 or 0,
        data = data or {},
    }
end

function Schema.newGoal(kind, priority, data)
    return {
        kind = kind,
        priority = priority or 0,
        progress = 0,
        data = data or {},
    }
end

function Schema.newIntent(kind, data)
    return {
        kind = kind,
        started = false,
        failed = false,
        done = false,
        data = data or {},
    }
end

function Schema.newNPCRecord(id, seed)
    return {
        id = id,
        seed = seed,
        identity = {
            firstName = "Unknown",
            lastName = "Unknown",
            female = false,
            ageBucket = "adult",
            profession = "unemployed",
            traitIds = {},
        },
        appearance = {
            outfit = nil,
            persistentOutfit = nil,
        },
        anchor = {
            x = 0, y = 0, z = 0,
            zoneId = nil,
            buildingId = nil,
            roomType = nil,
        },
        embodiment = {
            state = "hidden",
            actorId = nil,
            lastSeenHour = 0,
            graceUntilHour = 0,
            cooldownUntilHour = 0,
            missingTicks = 0,
        },
        stats = {
            hunger = 0.1,
            thirst = 0.1,
            fatigue = 0.1,
            boredom = 0.0,
            panic = 0.0,
            fear = 0.0,
            stress = 0.0,
            pain = 0.0,
            drunkenness = 0.0,
            endurance = 1.0,
            morale = 0.5,
            health = 100.0,
        },
        moodles = {},
        perks = {},
        inventory = {
            foodDays = 0.0,
            waterUnits = 0.0,
            meds = 0,
            ammo = 0,
            valuables = 0,
            equipment = {},
        },
        personality = {
            bravery = 0.5,
            empathy = 0.5,
            greed = 0.5,
            discipline = 0.5,
            curiosity = 0.5,
            impulsiveness = 0.5,
            loyalty = 0.5,
            paranoia = 0.5,
            sociability = 0.5,
        },
        motivations = {
            survival = 1.0,
            safety = 0.7,
            belonging = 0.4,
            power = 0.2,
            curiosity = 0.3,
            pleasure = 0.2,
            ideology = 0.1,
        },
        vice = {
            smoker = false,
            drinker = false,
            reader = false,
        },
        relationshipToPlayer = {
            trust = 0.0,
            respect = 0.0,
            fear = 0.0,
            resentment = 0.0,
            attachment = 0.0,
            debt = 0.0,
            loyaltyShift = 0.0,
        },
        memories = {},
        backstory = {
            formerProfession = nil,
            trauma = nil,
            hobby = nil,
            belief = nil,
            secret = nil,
            familyStatus = nil,
        },
        storyArc = {
            type = nil,
            phase = 0,
            clueCount = 0,
            revealFlags = {},
        },
        schedule = {
            activity = "idle_abstract",
            nextHour = 0,
        },
        goals = {
            longTerm = nil,
            shortTerm = nil,
            currentPlan = {},
            currentIntent = nil,
        },
        drama = {
            rivalry = false,
            jealousy = false,
            promiseBroken = false,
            suspectsTheft = false,
            pendingBetrayal = false,
        },
        companion = {
            recruited = false,
            squadRole = nil,
            canContinueAsLegacy = false,
        },
    }
end

function Schema.newLegacySnapshot(record)
    return {
        id = record.id,
        identity = copyTable(record.identity),
        perks = copyTable(record.perks),
        inventory = copyTable(record.inventory),
        backstory = copyTable(record.backstory),
        relationshipToPlayer = copyTable(record.relationshipToPlayer),
        storyArc = copyTable(record.storyArc),
        personality = copyTable(record.personality),
        motivations = copyTable(record.motivations),
    }
end
