LWN = LWN or {}
LWN.Debug = LWN.Debug or {}

local Debug = LWN.Debug

function Debug.dumpSummary()
    local embodied = LWN.PopulationStore.countEmbodied()
    local total = 0
    local eligible = 0
    local soonestCooldown = nil

    LWN.PopulationStore.eachNPC(function(record)
        total = total + 1
        if record.embodiment.state == "eligible" then
            eligible = eligible + 1
        end

        local cd = record.embodiment.cooldownUntilHour or 0
        if cd > 0 and (soonestCooldown == nil or cd < soonestCooldown) then
            soonestCooldown = cd
        end
    end)

    local encounters = LWN.PopulationStore.root().encounters or {}
    print(string.format(
        "[LWN] total=%d embodied=%d eligible=%d currentEligible=%s firstEncounter=%s lastEncounterHour=%.2f nextNpcCooldown=%.2f",
        total,
        embodied,
        eligible,
        tostring(encounters.currentEligibleId),
        tostring(encounters.firstEncounterTriggered),
        tonumber(encounters.lastEncounterHour or -9999) or -9999,
        tonumber(soonestCooldown or -1) or -1
    ))
end