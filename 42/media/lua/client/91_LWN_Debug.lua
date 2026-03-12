LWN = LWN or {}
LWN.Debug = LWN.Debug or {}

-- Small console summary helpers for quick sanity checks between live tests.
local Debug = LWN.Debug

function Debug.dumpSummary()
    local embodied = LWN.PopulationStore.countEmbodied()
    local total = 0
    local eligible = 0
    local soonestCooldown = nil
    local clueCount = #(LWN.PopulationStore.root().worldStory and LWN.PopulationStore.root().worldStory.clues or {})

    LWN.PopulationStore.eachNPC(function(record)
        total = total + 1
        if LWN.PopulationStore.isAlive(record) and record.embodiment.state == "eligible" then
            eligible = eligible + 1
        end

        local cd = record.embodiment.cooldownUntilHour or 0
        if cd > 0 and (soonestCooldown == nil or cd < soonestCooldown) then
            soonestCooldown = cd
        end
    end)

    local encounters = LWN.PopulationStore.root().encounters or {}
    local lastFailure = LWN.ActorFactory and LWN.ActorFactory.getLastFailure and LWN.ActorFactory.getLastFailure() or nil
    print(string.format(
        "[LWN] total=%d embodied=%d eligible=%d clues=%d currentEligible=%s firstEncounter=%s lastEncounterHour=%.2f nextNpcCooldown=%.2f",
        total,
        embodied,
        eligible,
        clueCount,
        tostring(encounters.currentEligibleId),
        tostring(encounters.firstEncounterTriggered),
        tonumber(encounters.lastEncounterHour or -9999) or -9999,
        tonumber(soonestCooldown or -1) or -1
    ))

    if lastFailure then
        print(string.format(
            "[LWN] lastActorFailure npc=%s reason=%s",
            tostring(lastFailure.npcId),
            tostring(lastFailure.reason)
        ))
    end
end
