LWN = LWN or {}
LWN.NPCStatus = LWN.NPCStatus or {}

local Status = LWN.NPCStatus

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function number(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback or 0 end
    return value
end

local function fullName(record)
    local identity = record and record.identity or {}
    local name = string.format(
        "%s %s",
        tostring(identity.firstName or "Unknown"),
        tostring(identity.lastName or "Unknown")
    )
    return name:gsub("^%s+", ""):gsub("%s+$", "")
end

function Status.snapshot(record, actor)
    if not record then return nil end
    local stats = record.stats or {}
    local inventory = record.inventory or {}
    local relationship = record.relationshipToPlayer or {}
    local companion = record.companion or {}
    local command = companion.command or {}
    local embodiment = record.embodiment or {}
    local modData = protectedCall(actor, "getModData")
    local actorHealth = protectedCall(actor, "getHealth")

    return {
        version = 1,
        npcId = record.id,
        identity = {
            name = fullName(record),
            profession = record.identity and record.identity.profession or "unknown",
            female = record.identity and record.identity.female == true,
            traits = record.identity and record.identity.traitIds or {},
        },
        condition = {
            health = number(stats.health, number(actorHealth, 100)),
            hunger = number(stats.hunger),
            thirst = number(stats.thirst),
            fatigue = number(stats.fatigue),
            endurance = number(stats.endurance, 1),
            panic = number(stats.panic),
            stress = number(stats.stress),
            pain = number(stats.pain),
        },
        relationship = {
            trust = number(relationship.trust),
            respect = number(relationship.respect),
            fear = number(relationship.fear),
            resentment = number(relationship.resentment),
            attachment = number(relationship.attachment),
        },
        inventory = {
            foodDays = number(inventory.foodDays),
            waterUnits = number(inventory.waterUnits),
            meds = number(inventory.meds),
            ammo = number(inventory.ammo),
            valuables = number(inventory.valuables),
            equipment = inventory.equipment or {},
        },
        skills = {
            perks = record.perks or {},
        },
        activity = {
            goal = record.goals and record.goals.longTerm and record.goals.longTerm.kind or "idle",
            intent = record.goals and record.goals.currentIntent or "none",
            commandKind = command.kind or "none",
            commandStatus = command.status or "idle",
            commandDestination = command.destination or {},
            squadRole = companion.squadRole or "none",
        },
        embodiment = {
            state = embodiment.state or "unknown",
            carrierKind = embodiment.carrierKind or modData and modData.LWN_CarrierKind or "unknown",
            shellMode = modData and (modData.LWN_ShellMode or modData.LWN_CarrierCombatMode) or "unknown",
            lastFailureReason = embodiment.lastFailureReason,
            lastFailureDetail = embodiment.lastFailureDetail,
        },
        sections = {
            overview = true,
            health = true,
            skills = true,
            inventory = true,
            relationship = true,
        },
    }
end
