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
    local inventorySnapshot = LWN.Inventory and LWN.Inventory.snapshot and LWN.Inventory.snapshot(record, actor) or nil
    local stage = LWN.Social and LWN.Social.computeRelationshipStage and LWN.Social.computeRelationshipStage(record)
        or relationship.stage
        or "neutral"
    local team = companion.teamId
        and LWN.Social
        and LWN.Social.updateTeamMood
        and LWN.Social.updateTeamMood(companion.teamId)
        or nil

    return {
        version = 2,
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
            stage = stage,
            trust = number(relationship.trust),
            respect = number(relationship.respect),
            fear = number(relationship.fear),
            resentment = number(relationship.resentment),
            attachment = number(relationship.attachment),
            debt = number(relationship.debt),
        },
        team = {
            id = companion.teamId or "none",
            companionCount = number(team and team.companionCount),
            stress = number(team and team.stress),
            morale = number(team and team.morale, 0.5),
            cohesion = number(team and team.cohesion, 0.5),
            pressureReason = team and team.pressureReason or "none",
        },
        inventory = {
            foodDays = number(inventory.foodDays),
            waterUnits = number(inventory.waterUnits),
            meds = number(inventory.meds),
            ammo = number(inventory.ammo),
            valuables = number(inventory.valuables),
            equipment = inventory.equipment or {},
            items = inventory.items or {},
            actorItemCount = number(inventorySnapshot and inventorySnapshot.actor and inventorySnapshot.actor.totalItems),
            actorWornCount = number(inventorySnapshot and inventorySnapshot.actor and inventorySnapshot.actor.wornCount),
            actorItemVisualCount = number(inventorySnapshot and inventorySnapshot.actor and inventorySnapshot.actor.itemVisualCount),
            primaryWeapon = inventorySnapshot and inventorySnapshot.record and inventorySnapshot.record.primaryWeapon
                or inventory.equipment and inventory.equipment.primaryWeapon
                or nil,
            actorPrimaryHand = inventorySnapshot and inventorySnapshot.actor and inventorySnapshot.actor.primaryHand or nil,
            actorSecondaryHand = inventorySnapshot and inventorySnapshot.actor and inventorySnapshot.actor.secondaryHand or nil,
            clothing = inventorySnapshot and inventorySnapshot.record and inventorySnapshot.record.clothing
                or inventory.equipment and inventory.equipment.clothing
                or {},
            lastChangeReason = inventorySnapshot and inventorySnapshot.lastChangeReason or inventory.lastChangeReason,
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
            behaviorGuideline = companion.behaviorGuideline or "follow",
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
