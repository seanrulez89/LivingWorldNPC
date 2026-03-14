LWN = LWN or {}
LWN.Social = LWN.Social or {}

local Social = LWN.Social
local Memory = LWN.Memory

function Social.adjustTrust(record, delta, reason)
    local rel = record.relationshipToPlayer
    rel.trust = math.max(-1, math.min(1, rel.trust + delta))
    Memory.add(record, reason or "trust_shift", math.abs(delta), { delta = delta })
end

function Social.adjustResentment(record, delta, reason)
    local rel = record.relationshipToPlayer
    rel.resentment = math.max(0, math.min(1.5, rel.resentment + delta))
    Memory.add(record, reason or "resentment_shift", math.abs(delta), { delta = delta })
end

function Social.commandResponse(record, command, context)
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
    return record.relationshipToPlayer.trust >= LWN.Config.Social.RecruitTrustFloor
end

function Social.relationshipCombatPolicy(record)
    local rel = record.relationshipToPlayer or {}
    local drama = record.drama or {}
    local companion = record.companion or {}
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
            reason = drama.pendingBetrayal == true and "pending_betrayal" or "betrayal_score",
        }
    end

    if companion.recruited == true and trust >= recruitFloor then
        return {
            state = "friendly",
            allowPlayerAttack = false,
            allowCarrierAttackPlayer = false,
            shouldNeutralizeCarrier = true,
            reason = "trusted_companion",
        }
    end

    return {
        state = "neutral",
        allowPlayerAttack = true,
        allowCarrierAttackPlayer = false,
        shouldNeutralizeCarrier = true,
        reason = companion.recruited == true and "recruited_but_low_trust" or "not_recruited",
    }
end

function Social.maybeSuggest(record)
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
