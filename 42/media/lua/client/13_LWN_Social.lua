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
    record.relationshipToPlayer = record.relationshipToPlayer or {}
    record.drama = record.drama or {}
    record.companion = record.companion or {}
    return record.relationshipToPlayer, record.drama, record.companion
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
        return
    end
    rel.trust = clamp((tonumber(rel.trust or 0) or 0) + delta, -1, 1)
    remember(record, reason or "trust_shift", math.abs(delta), { delta = delta })
end

function Social.adjustResentment(record, delta, reason)
    local rel = ensureCombatPolicyTables(record)
    if Social.isMinimalDummyRecord(record) then
        rel.resentment = 0
        return
    end
    rel.resentment = clamp((tonumber(rel.resentment or 0) or 0) + delta, 0, 1.5)
    remember(record, reason or "resentment_shift", math.abs(delta), { delta = delta })
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
    return record.relationshipToPlayer.trust >= LWN.Config.Social.RecruitTrustFloor
end

function Social.relationshipCombatPolicy(record)
    if Social.isMinimalDummyRecord(record) then
        return Social.minimalDummyPolicy(record)
    end
    local rel, drama, companion = ensureCombatPolicyTables(record)
    local trust = tonumber(rel.trust or 0) or 0
    local betrayalScore = Social.betrayalScore(record)
    local recruitFloor = LWN.Config.Social.RecruitTrustFloor or 0.45
    local betrayThreshold = LWN.Config.Social.BetrayThreshold or 1.25

    if drama.pendingBetrayal == true or betrayalScore >= betrayThreshold then
        return {
            state = "hostile",
            allowPlayerAttack = true,
            allowCarrierAttackPlayer = true,
            shouldNeutralizeCarrier = false,
            allowMovement = true,
            allowAutonomousMovement = true,
            shellMode = "hostile",
            reason = drama.pendingBetrayal == true and "pending_betrayal" or "betrayal_score",
        }
    end

    if companion.recruited == true and trust >= recruitFloor then
        return {
            state = "friendly",
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
        "%s/%s t=%.2f",
        tostring(policy and policy.state or "unknown"),
        tostring(policy and policy.reason or "unknown"),
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
