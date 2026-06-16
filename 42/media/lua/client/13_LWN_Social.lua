LWN = LWN or {}
LWN.Social = LWN.Social or {}

local Social = LWN.Social
local Memory = LWN.Memory

local function clamp(value, minValue, maxValue)
    if type(value) ~= "number" then
        value = minValue
    end
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    return value
end

local function remember(record, reason, salience, data)
    if Memory and Memory.add then
        Memory.add(record, reason, salience, data)
    end
end

local function ensureCombatPolicyTables(record)
    if type(record) ~= "table" then
        return {}, {}, {}
    end
    if LWN.PopulationStore and LWN.PopulationStore.ensureRecordShape then
        LWN.PopulationStore.ensureRecordShape(record)
    end
    record.relationshipToPlayer = record.relationshipToPlayer or {}
    record.drama = record.drama or {}
    record.companion = record.companion or {}
    return record.relationshipToPlayer, record.drama, record.companion
end

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function relationScore(record)
    local rel = record and record.relationshipToPlayer or {}
    return (tonumber(rel.trust or 0) or 0) * 1.25
        + (tonumber(rel.respect or 0) or 0) * 0.45
        + (tonumber(rel.attachment or 0) or 0) * 0.55
        + (tonumber(rel.debt or 0) or 0) * 0.25
        - (tonumber(rel.fear or 0) or 0) * 0.45
        - (tonumber(rel.resentment or 0) or 0) * 1.10
end

local function defaultTeam(teamId)
    return {
        id = teamId or "player-team-0",
        companionCount = 0,
        stress = 0.0,
        morale = 0.5,
        cohesion = 0.5,
        pressureReason = "baseline",
        lastUpdatedHour = worldAgeHours(),
    }
end

function Social.computeRelationshipStage(record)
    if type(record) ~= "table" then return "neutral" end
    if Social.isMinimalDummyRecord(record) then
        record.relationshipToPlayer = record.relationshipToPlayer or {}
        record.relationshipToPlayer.stage = record.companion and record.companion.recruited == true
            and "companion"
            or "friendly"
        if LWN.Log and LWN.Log.state then
            LWN.Log.state("Social", "relationship:" .. tostring(record.id), record.relationshipToPlayer.stage, {
                npcId = record.id,
                stage = record.relationshipToPlayer.stage,
                reason = "minimal_dummy_policy",
            })
        end
        return record.relationshipToPlayer.stage
    end

    local rel, drama, companion = ensureCombatPolicyTables(record)
    local previousStage = rel.stage
    if drama.pendingBetrayal == true or Social.betrayalScore(record) >= (LWN.Config.Social.BetrayThreshold or 1.25) then
        rel.stage = "hostile"
        if LWN.Log and LWN.Log.state then
            LWN.Log.state("Social", "relationship:" .. tostring(record.id), rel.stage, {
                npcId = record.id,
                stage = rel.stage,
                reason = "betrayal_threshold",
                previous = previousStage,
            })
        end
        return rel.stage
    end

    local score = relationScore(record)
    if companion.recruited == true and score >= -0.15 then
        rel.stage = "companion"
    elseif score >= 0.45 then
        rel.stage = "friendly"
    elseif score <= -0.55 then
        rel.stage = "hostile"
    elseif score <= -0.15 or (tonumber(rel.fear or 0) or 0) >= 0.65 or (tonumber(rel.resentment or 0) or 0) >= 0.60 then
        rel.stage = "wary"
    else
        rel.stage = "neutral"
    end
    if LWN.Log and LWN.Log.state then
        LWN.Log.state("Social", "relationship:" .. tostring(record.id), rel.stage, {
            npcId = record.id,
            stage = rel.stage,
            reason = "relationship_score",
            previous = previousStage,
            score = string.format("%.3f", tonumber(score) or 0),
            trust = rel.trust,
            fear = rel.fear,
            resentment = rel.resentment,
        })
    end
    return rel.stage
end

function Social.getTeam(teamId)
    teamId = teamId or "player-team-0"
    if not (LWN.PopulationStore and LWN.PopulationStore.root) then
        return defaultTeam(teamId)
    end
    local root = LWN.PopulationStore.root()
    root.teams = root.teams or {}
    root.teams[teamId] = root.teams[teamId] or defaultTeam(teamId)
    return root.teams[teamId]
end

function Social.updateTeamMood(teamId)
    teamId = teamId or "player-team-0"
    local team = Social.getTeam(teamId)
    local count = 0
    local stressSum = 0
    local moraleSum = 0
    local relationSum = 0

    if LWN.PopulationStore and LWN.PopulationStore.eachNPC then
        LWN.PopulationStore.eachNPC(function(record)
            if LWN.PopulationStore.isAlive(record) == true
                and record.companion
                and record.companion.recruited == true
                and record.companion.teamId == teamId
            then
                count = count + 1
                Social.computeRelationshipStage(record)
                stressSum = stressSum + (tonumber(record.stats and record.stats.stress or 0) or 0)
                moraleSum = moraleSum + (tonumber(record.stats and record.stats.morale or 0.5) or 0.5)
                relationSum = relationSum + relationScore(record)
            end
        end)
    end

    local comfortable = LWN.Config.Social.ComfortableCompanionCount or 3
    local extra = math.max(0, count - comfortable)
    local baseStress = count > 0 and (stressSum / count) or 0
    local sizeStress = extra * (LWN.Config.Social.OversizeStressPerCompanion or 0.12)
    local morale = count > 0 and (moraleSum / count) or 0.5
    local cohesion = count > 0 and clamp(0.5 + (relationSum / count) * 0.25, 0, 1) or 0.5
    cohesion = clamp(cohesion - extra * (LWN.Config.Social.OversizeCohesionPenaltyPerCompanion or 0.08), 0, 1)

    team.companionCount = count
    team.stress = clamp(baseStress + sizeStress, 0, 1.5)
    team.morale = clamp(morale - sizeStress * 0.35, 0, 1)
    team.cohesion = cohesion
    team.pressureReason = extra > 0 and "oversized_group" or "baseline"
    team.lastUpdatedHour = worldAgeHours()
    if LWN.Log and LWN.Log.state then
        local signature = table.concat({
            tostring(count),
            string.format("%.3f", tonumber(team.stress) or 0),
            string.format("%.3f", tonumber(team.morale) or 0),
            string.format("%.3f", tonumber(team.cohesion) or 0),
            tostring(team.pressureReason),
        }, "|")
        LWN.Log.state("Social", "team:" .. tostring(teamId), signature, {
            teamId = teamId,
            count = count,
            stress = string.format("%.3f", tonumber(team.stress) or 0),
            morale = string.format("%.3f", tonumber(team.morale) or 0),
            cohesion = string.format("%.3f", tonumber(team.cohesion) or 0),
            reason = team.pressureReason,
        })
    end
    return team
end

function Social.applyEvent(record, eventKind, data)
    if type(record) ~= "table" then return false end
    data = data or {}
    eventKind = tostring(eventKind or "")

    if eventKind == "rescued_from_zombie" then
        Social.adjustTrust(record, 0.08, eventKind)
        record.relationshipToPlayer.attachment = clamp((record.relationshipToPlayer.attachment or 0) + 0.05, -1, 1.5)
    elseif eventKind == "friendly_fire" then
        record.relationshipToPlayer.fear = clamp((record.relationshipToPlayer.fear or 0) + 0.08, 0, 1.5)
        Social.adjustResentment(record, 0.10, eventKind)
    elseif eventKind == "neglect" then
        Social.adjustTrust(record, -0.05, eventKind)
        Social.adjustResentment(record, 0.05, eventKind)
    elseif eventKind == "companion_death" then
        record.stats = record.stats or {}
        record.stats.stress = clamp((record.stats.stress or 0) + 0.12, 0, 1.5)
        remember(record, eventKind, 0.60, data)
    else
        remember(record, eventKind ~= "" and eventKind or "social_event", tonumber(data.salience or 0.10) or 0.10, data)
    end

    Social.computeRelationshipStage(record)
    if record.companion and record.companion.teamId then
        Social.updateTeamMood(record.companion.teamId)
    end
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Social", "event_applied", {
            npcId = record.id,
            teamId = record.companion and record.companion.teamId,
            stage = record.relationshipToPlayer and record.relationshipToPlayer.stage,
            reason = eventKind,
            trust = record.relationshipToPlayer and record.relationshipToPlayer.trust,
            fear = record.relationshipToPlayer and record.relationshipToPlayer.fear,
            resentment = record.relationshipToPlayer and record.relationshipToPlayer.resentment,
            health = record.stats and record.stats.health,
            stress = record.stats and record.stats.stress,
        })
    end
    return true
end

function Social.isMinimalDummyRecord(record)
    return type(record) == "table"
        and type(record.dummy) == "table"
        and record.dummy.enabled == true
end

function Social.isMinimalDummyMoveActive(record)
    if not Social.isMinimalDummyRecord(record) then
        return false
    end

    local dummy = record and record.dummy or nil
    local motor = dummy and dummy.motor or nil
    local command = record and record.companion and record.companion.command or nil

    if dummy and (dummy.state == "move_to" or dummy.state == "follow_player") then
        return true
    end
    if motor and (motor.state == "started" or motor.state == "stepping") then
        return true
    end
    if command and command.active == true then
        if command.intentKind == "move_to"
            or command.intentKind == "follow_player"
            or command.kind == "move_to"
            or command.kind == "designated_location"
            or command.kind == "follow_player"
        then
            return true
        end
    end
    return false
end

function Social.minimalDummyPolicy(record)
    local harness = record and record.debugHarness or nil
    if harness and harness.quarantine == true then
        return {
            state = "friendly",
            allowPlayerAttack = false,
            allowCarrierAttackPlayer = false,
            shouldNeutralizeCarrier = true,
            allowMovement = false,
            allowAutonomousMovement = false,
            shellMode = "debug_quarantine",
            reason = "minimal_dummy_quarantine",
        }
    end
    local moving = Social.isMinimalDummyMoveActive(record)
    return {
        state = "friendly",
        allowPlayerAttack = false,
        allowCarrierAttackPlayer = false,
        shouldNeutralizeCarrier = true,
        allowMovement = moving == true,
        allowAutonomousMovement = false,
        shellMode = moving and "dummy_move" or "dummy_idle",
        reason = moving and "minimal_dummy_move_lock" or "minimal_dummy_idle_lock",
    }
end

function Social.adjustTrust(record, delta, reason)
    local rel = ensureCombatPolicyTables(record)
    if Social.isMinimalDummyRecord(record) then
        rel.trust = 0
        rel.stage = "friendly"
        return
    end
    rel.trust = clamp((tonumber(rel.trust or 0) or 0) + delta, -1, 1)
    remember(record, reason or "trust_shift", math.abs(delta), { delta = delta })
    Social.computeRelationshipStage(record)
end

function Social.adjustResentment(record, delta, reason)
    local rel = ensureCombatPolicyTables(record)
    if Social.isMinimalDummyRecord(record) then
        rel.resentment = 0
        rel.stage = "friendly"
        return
    end
    rel.resentment = clamp((tonumber(rel.resentment or 0) or 0) + delta, 0, 1.5)
    remember(record, reason or "resentment_shift", math.abs(delta), { delta = delta })
    Social.computeRelationshipStage(record)
end

function Social.commandResponse(record, command, context)
    if Social.isMinimalDummyRecord(record) then
        return { kind = "accept", reason = "minimal_dummy" }
    end
    context = context or {}
    local rel = record.relationshipToPlayer
    local stats = record.stats
    local p = record.personality

    local score = 0
    score = score + rel.trust * 1.4
    score = score + rel.respect * 0.6
    score = score - rel.fear * 0.2
    score = score - rel.resentment * 1.2
    score = score - stats.hunger * 0.7
    score = score - stats.fatigue * 0.8
    score = score - stats.panic * 1.0
    score = score + p.loyalty * 0.8
    score = score - p.paranoia * 0.4
    score = score - (context.risk or 0) * (1.0 - p.bravery)

    if score >= 0.75 then
        return { kind = "accept", reason = "trusted" }
    elseif score >= 0.2 then
        return { kind = "counteroffer", reason = stats.hunger > 0.4 and "hunger" or "caution" }
    elseif score >= -0.2 then
        return { kind = "delay", reason = stats.fatigue > 0.5 and "fatigue" or "uncertain" }
    elseif score >= -0.6 then
        return { kind = "refuse", reason = stats.panic > 0.4 and "panic" or "distrust" }
    end

    return { kind = "topic_shift", reason = "hostile" }
end

function Social.betrayalScore(record)
    if Social.isMinimalDummyRecord(record) then
        return -999
    end
    local rel = record.relationshipToPlayer
    local p = record.personality
    local score = 0
    score = score + p.greed
    score = score + rel.resentment
    score = score + rel.fear * 0.6
    score = score - p.loyalty
    score = score - rel.trust
    return score
end

function Social.canRecruit(record)
    if Social.isMinimalDummyRecord(record) then
        return false
    end
    Social.computeRelationshipStage(record)
    return record.relationshipToPlayer.trust >= LWN.Config.Social.RecruitTrustFloor
        or record.relationshipToPlayer.stage == "friendly"
end

function Social.relationshipCombatPolicy(record)
    if Social.isMinimalDummyRecord(record) then
        return Social.minimalDummyPolicy(record)
    end
    local rel, drama, companion = ensureCombatPolicyTables(record)
    local stage = Social.computeRelationshipStage(record)
    local trust = tonumber(rel.trust or 0) or 0
    local betrayalScore = Social.betrayalScore(record)
    local recruitFloor = LWN.Config.Social.RecruitTrustFloor or 0.45
    local betrayThreshold = LWN.Config.Social.BetrayThreshold or 1.25

    if drama.pendingBetrayal == true or betrayalScore >= betrayThreshold then
        return {
            state = "hostile",
            relationshipStage = stage,
            allowPlayerAttack = true,
            allowCarrierAttackPlayer = true,
            shouldNeutralizeCarrier = false,
            allowMovement = true,
            allowAutonomousMovement = true,
            shellMode = "hostile",
            reason = drama.pendingBetrayal == true and "pending_betrayal" or "betrayal_score",
        }
    end

    if companion.recruited == true and (trust >= recruitFloor or stage == "companion") then
        return {
            state = "friendly",
            relationshipStage = stage,
            allowPlayerAttack = false,
            allowCarrierAttackPlayer = false,
            shouldNeutralizeCarrier = true,
            allowMovement = true,
            allowAutonomousMovement = true,
            shellMode = "non_hostile_mobile",
            reason = "trusted_companion",
        }
    end

    return {
        state = "neutral",
        relationshipStage = stage,
        allowPlayerAttack = true,
        allowCarrierAttackPlayer = false,
        shouldNeutralizeCarrier = true,
        allowMovement = true,
        allowAutonomousMovement = true,
        shellMode = "non_hostile_mobile",
        reason = companion.recruited == true and "recruited_but_low_trust" or "not_recruited",
    }
end

function Social.combatPolicySummary(record, policy)
    local rel = ensureCombatPolicyTables(record)
    local stage = Social.computeRelationshipStage(record)
    policy = policy or Social.relationshipCombatPolicy(record)
    if Social.isMinimalDummyRecord(record) then
        return string.format(
            "%s/%s dummy=%s state=%s",
            tostring(policy and policy.state or "unknown"),
            tostring(policy and policy.reason or "unknown"),
            tostring(record and record.id or nil),
            tostring(record and record.dummy and record.dummy.state or "nil")
        )
    end
    return string.format(
        "%s/%s stage=%s t=%.2f",
        tostring(policy and policy.state or "unknown"),
        tostring(policy and policy.reason or "unknown"),
        tostring(stage),
        tonumber(rel.trust or 0) or 0
    )
end

function Social.forceRelationshipCombatPolicy(record, targetState, reason)
    if type(record) ~= "table" then
        return nil, "record=nil"
    end
    if Social.isMinimalDummyRecord(record) then
        return Social.minimalDummyPolicy(record), nil
    end

    local rel, drama, companion = ensureCombatPolicyTables(record)
    local recruitFloor = LWN.Config.Social.RecruitTrustFloor or 0.45
    targetState = tostring(targetState or ""):lower()

    if targetState == "friendly" then
        companion.recruited = true
        drama.pendingBetrayal = false
        rel.trust = clamp(math.max(tonumber(rel.trust or 0) or 0, recruitFloor + 0.15), -1, 1)
        rel.resentment = 0
        rel.fear = 0
    elseif targetState == "neutral" then
        companion.recruited = false
        drama.pendingBetrayal = false
        rel.trust = clamp(math.min(recruitFloor - 0.10, 0.25), -1, 1)
        rel.resentment = 0
        rel.fear = 0
    elseif targetState == "hostile" then
        companion.recruited = false
        drama.pendingBetrayal = true
        rel.trust = clamp(-0.35, -1, 1)
        rel.resentment = clamp(math.max(tonumber(rel.resentment or 0) or 0, 0.85), 0, 1.5)
        rel.fear = clamp(math.max(tonumber(rel.fear or 0) or 0, 0.40), 0, 1.5)
    else
        return nil, "unknown_target_state"
    end

    remember(record, reason or "force_relationship_combat_policy", 0.15, {
        state = targetState,
    })

    return Social.relationshipCombatPolicy(record), nil
end

function Social.maybeSuggest(record)
    if Social.isMinimalDummyRecord(record) then
        return nil
    end
    local stats = record.stats
    if stats.hunger > 0.7 then
        return { kind = "suggest", topic = "find_food" }
    end
    if stats.fatigue > 0.75 then
        return { kind = "suggest", topic = "rest" }
    end
    if stats.panic > 0.55 then
        return { kind = "suggest", topic = "leave_area" }
    end
    return nil
end
