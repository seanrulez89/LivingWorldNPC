LWN = LWN or {}
LWN.EncounterDirector = LWN.EncounterDirector or {}

local Director = LWN.EncounterDirector
local Store = LWN.PopulationStore

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function dist2(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

function Director.cooldownHours()
    return (LWN.Config.Population and LWN.Config.Population.EncounterCooldownHours) or 2.0
end

function Director.firstEncounterMaxDistanceTiles()
    local embodyRadius = (LWN.Config.Embodiment and LWN.Config.Embodiment.RadiusTiles) or 32
    return math.floor(embodyRadius * 1.25)
end

function Director.ensureEncounterState()
    local root = Store.root()
    root.encounters = root.encounters or {}
    if root.encounters.currentEligibleId == nil then
        root.encounters.currentEligibleId = nil
    end
    if root.encounters.lastEncounterHour == nil then
        root.encounters.lastEncounterHour = -9999
    end
    if root.encounters.firstEncounterTriggered == nil then
        root.encounters.firstEncounterTriggered = false
    end
    return root.encounters
end

function Director.gatesOpen()
    local root = Store.root()
    if worldAgeHours() >= LWN.Config.Population.IntroLockHours then return true end
    if (root.encounters.travelledTiles or 0) >= LWN.Config.Population.IntroTravelThreshold then return true end
    if root.encounters.hasSlept then return true end
    return false
end

function Director._scoreBlockedByCooldown(record, now)
    local untilHour = record.embodiment and record.embodiment.cooldownUntilHour or 0
    return untilHour > now
end

function Director.score(record, player)
    if record.embodiment.state ~= "hidden" and record.embodiment.state ~= "eligible" then
        return -math.huge
    end

    local encounters = Director.ensureEncounterState()
    local now = worldAgeHours()
    if Director._scoreBlockedByCooldown(record, now) then
        return -math.huge
    end

    local score = 0
    local px, py = player:getX(), player:getY()
    local d2 = dist2(px, py, record.anchor.x, record.anchor.y)

    score = score - (d2 / 4000)

    if not encounters.firstEncounterTriggered then
        local maxDist = Director.firstEncounterMaxDistanceTiles()
        local maxD2 = maxDist * maxDist
        if d2 > maxD2 then
            return -math.huge
        end
        local closeness = math.max(0, (maxD2 - d2) / maxD2)
        score = score + (0.75 * closeness)
    end

    if record.storyArc.type then score = score + 0.35 end
    if record.backstory.formerProfession == "nurse" and player:getMoodleLevel(MoodleType.Injured) > 0 then
        score = score + 0.5
    end
    if record.personality.paranoia > 0.7 and getGameTime():getHour() >= 20 then
        score = score - 0.2
    end

    return score
end

function Director._clearNonSelectedEligibility(selectedId)
    Store.eachNPC(function(record)
        if record.embodiment.state == "eligible" and record.id ~= selectedId then
            record.embodiment.state = "hidden"
        end
    end)
end

function Director.notifyEmbodied(record)
    if not record then return end
    local encounters = Director.ensureEncounterState()
    encounters.firstEncounterTriggered = true
    encounters.lastEncounterHour = worldAgeHours()
    if encounters.currentEligibleId == record.id then
        encounters.currentEligibleId = nil
    end
end

function Director.update(player)
    if not Director.gatesOpen() then return end

    local encounters = Director.ensureEncounterState()
    local now = worldAgeHours()

    if (now - (encounters.lastEncounterHour or -9999)) < Director.cooldownHours() then
        return
    end

    if Store.countEmbodied() >= LWN.Config.Population.MaxEmbodied then
        return
    end

    local selectedId = encounters.currentEligibleId
    if selectedId then
        local selected = Store.getNPC(selectedId)
        if selected and (selected.embodiment.state == "hidden" or selected.embodiment.state == "eligible") then
            local selectedScore = Director.score(selected, player)
            if selectedScore > -math.huge then
                selected.embodiment.state = "eligible"
                Director._clearNonSelectedEligibility(selectedId)
                return
            end
        end
        encounters.currentEligibleId = nil
    end

    local best, bestScore = nil, -math.huge
    Store.eachNPC(function(record)
        if record.embodiment.state == "hidden" then
            local score = Director.score(record, player)
            if score > bestScore then
                best = record
                bestScore = score
            end
        end
    end)

    if best and bestScore > -1.0 then
        encounters.currentEligibleId = best.id
        best.embodiment.state = "eligible"
        Director._clearNonSelectedEligibility(best.id)
    end
end