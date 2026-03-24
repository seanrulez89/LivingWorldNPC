LWN = LWN or {}
LWN.Carriers = LWN.Carriers or {}

local Carrier = {}
LWN.Carriers.isozombie = Carrier

local Store = LWN.PopulationStore

local function ensureRecordShape(record)
    if Store and Store.ensureRecordShape then
        return Store.ensureRecordShape(record)
    end
    return record
end

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local ISOZOMBIE_SETTLE_MAX_SYNC_ATTEMPTS = 12
local ISOZOMBIE_SETTLE_MAX_HOURS = 0.0015
local ISOZOMBIE_APPEARANCE_EXPERIMENT = "isozombie_shared_desc_visual_v1"
local ISOZOMBIE_APPEARANCE_REUSE = "desc+baseline+clothes+bridge"

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function safeText(value)
    if value == nil then return "nil" end
    local text = tostring(value)
    text = text:gsub("[\r\n|]", " ")
    return text
end

local function normalizeSampleValue(value)
    local text = safeText(value)
    text = text:gsub("%-?%d+%.%d+", "#")
    text = text:gsub("%-?%d+", "#")
    text = text:gsub("%s+", " ")
    return text
end

local function sampleDebugEvent(bucketName, key, signature, options)
    if LWN.ActorFactory and LWN.ActorFactory.sampleDebugEvent then
        return LWN.ActorFactory.sampleDebugEvent(bucketName, key, signature, options)
    end
    return {
        emit = true,
        reason = "local_fallback",
        seenCount = 1,
        suppressedCount = 0,
    }
end

local function sampleSuffix(sample)
    if not sample then return "" end

    local parts = {}
    if sample.reason and sample.reason ~= "new" then
        parts[#parts + 1] = "sample=" .. safeText(sample.reason)
    end
    if (sample.suppressedCount or 0) > 0 then
        parts[#parts + 1] = "suppressed=" .. safeText(sample.suppressedCount)
    end
    if #parts == 0 then
        return ""
    end
    return " | " .. table.concat(parts, " | ")
end

local function trace(stage, record, detail)
    local sample = sampleDebugEvent(
        "carrier_isozombie_trace",
        table.concat({
            safeText(record and record.id or nil),
            safeText(stage),
        }, "|"),
        table.concat({
            safeText(stage),
            normalizeSampleValue(detail),
        }, "|")
    )
    if sample.emit ~= true then
        return
    end

    print(string.format(
        "[LWN][CarrierIsoZombie] stage=%s | npcId=%s | detail=%s%s",
        safeText(stage),
        safeText(record and record.id or nil),
        safeText(detail),
        sampleSuffix(sample)
    ))
end

local function ensureSquare(record, player)
    local x = math.floor(record and record.anchor and record.anchor.x or protectedCall(player, "getX") or 0)
    local y = math.floor(record and record.anchor and record.anchor.y or protectedCall(player, "getY") or 0)
    local z = math.floor(record and record.anchor and record.anchor.z or protectedCall(player, "getZ") or 0)
    local cell = getCell and getCell() or (getWorld and getWorld() and getWorld():getCell()) or nil
    local square = cell and protectedCall(cell, "getGridSquare", x, y, z) or nil
    if not square and player then
        square = protectedCall(player, "getSquare")
    end
    return square
end

local function femaleChanceForRecord(record)
    if record and record.identity and record.identity.female == true then
        return 100
    end
    return 0
end

local function zombieListFirst(list)
    if not list then return nil end
    if list.get and list.size and list:size() > 0 then
        return list:get(0)
    end
    if type(list) == "table" then
        return list[1]
    end
    return nil
end

local function spawnZombieAtSquare(square, record)
    if not square or not addZombiesInOutfit then
        return nil, "missing_square_or_addZombiesInOutfit"
    end

    local x = protectedCall(square, "getX") or 0
    local y = protectedCall(square, "getY") or 0
    local z = protectedCall(square, "getZ") or 0
    local femaleChance = femaleChanceForRecord(record)

    local ok, zombieList = pcall(function()
        return addZombiesInOutfit(x, y, z, 1, nil, femaleChance, false, false, false, false, false, false, 1)
    end)
    if not ok then
        return nil, zombieList
    end

    local actor = zombieListFirst(zombieList)
    if not actor then
        return nil, "zombieList_empty"
    end

    return actor, "addZombiesInOutfit"
end

local function relationshipCombatPolicy(record)
    local harness = record and record.debugHarness or nil
    if harness and harness.enabled == true and harness.holdPosition == true then
        return {
            state = harness.forceFriendly == true and "friendly" or "neutral",
            allowPlayerAttack = true,
            allowCarrierAttackPlayer = false,
            shouldNeutralizeCarrier = true,
            reason = "debug_test_harness_hold_position",
        }
    end
    if LWN.Social and LWN.Social.relationshipCombatPolicy then
        return LWN.Social.relationshipCombatPolicy(record)
    end
    return {
        state = "neutral",
        allowPlayerAttack = true,
        allowCarrierAttackPlayer = false,
        shouldNeutralizeCarrier = true,
        reason = "social_policy_missing",
    }
end

local function relationshipPolicySummary(record, policy)
    if LWN.Social and LWN.Social.combatPolicySummary then
        return LWN.Social.combatPolicySummary(record, policy)
    end
    policy = policy or relationshipCombatPolicy(record)
    return string.format("%s/%s", tostring(policy.state), tostring(policy.reason))
end

local function carrierCombatMode(policy)
    if policy.allowCarrierAttackPlayer == true then
        return "hostile_player"
    end
    if policy.shouldNeutralizeCarrier == true then
        return "neutralized"
    end
    return "idle"
end

local function friendlySuppressionSummary(policy)
    if policy.allowPlayerAttack ~= true then
        return "godmod+clearqueue"
    end
    if policy.shouldNeutralizeCarrier == true then
        return "clearqueue"
    end
    return "attackable"
end

local function stampHybridSummary(record, actor, relationSummary, descriptor, appearanceDetail)
    if not (actor and LWN.ActorFactory and LWN.ActorFactory.stampHybridDebugMetadata) then
        return nil
    end

    local metadataOptions = {
        relationPolicy = relationSummary,
    }
    if appearanceDetail then
        metadataOptions.descriptorSource = appearanceDetail.descriptorSource
        metadataOptions.appearanceExperiment = appearanceDetail.experiment
        metadataOptions.appearanceApplied = appearanceDetail.applied == true
        metadataOptions.appearanceReuse = appearanceDetail.reuse
        metadataOptions.appearanceBridge = appearanceDetail.bridgeMode
        metadataOptions.appearanceStage = appearanceDetail.stage
        metadataOptions.appearanceStatus = appearanceDetail.status
    end

    local modData = protectedCall(actor, "getModData")
    local ok, hybridSources = pcall(LWN.ActorFactory.stampHybridDebugMetadata, record, actor, descriptor, metadataOptions)
    if not ok then
        trace("hybrid.summary.error", record, tostring(hybridSources))
        return nil
    end
    if modData and hybridSources then
        local previousSummary = modData.LWN_LastHybridSummaryLogged
        if previousSummary ~= hybridSources.summary
            and LWN.ActorFactory
            and LWN.ActorFactory.debugStage
        then
            modData.LWN_LastHybridSummaryLogged = hybridSources.summary
            local summaryStage = "hybrid.summary"
            if appearanceDetail and appearanceDetail.status == "pending" then
                summaryStage = "hybrid.summary.pre_appearance"
            elseif appearanceDetail and appearanceDetail.status == "applied" then
                summaryStage = "hybrid.summary.post_appearance"
            elseif appearanceDetail and appearanceDetail.status == "skipped" then
                summaryStage = "hybrid.summary.skipped"
            end
            LWN.ActorFactory.debugStage("CarrierIsoZombie", summaryStage, record, actor, descriptor, {
                source = "Carrier_IsoZombie",
                detail = hybridSources.summary,
            })
        end
    end

    return hybridSources
end

local function normalizeAppearanceDetail(detail, overrides)
    local normalized = {
        applied = detail and detail.applied == true or false,
        experiment = detail and detail.experiment or ISOZOMBIE_APPEARANCE_EXPERIMENT,
        reuse = detail and detail.reuse or ISOZOMBIE_APPEARANCE_REUSE,
        bridgeMode = detail and detail.bridgeMode or "pending",
        descriptorMode = detail and detail.descriptorMode or "pending",
        descriptorSource = detail and detail.descriptorSource or "pending",
        stage = detail and detail.stage or nil,
        status = detail and detail.status or nil,
    }

    if overrides then
        for key, value in pairs(overrides) do
            if value ~= nil then
                normalized[key] = value
            end
        end
    end

    if normalized.applied == true and normalized.status == nil then
        normalized.status = "applied"
    end
    if normalized.status == nil then
        normalized.status = "pending"
    end
    if normalized.stage == nil then
        normalized.stage = normalized.status
    end

    return normalized
end

local function cachedAppearanceDetail(actor)
    local modData = protectedCall(actor, "getModData")
    if not modData or modData.LWN_HybridAppearanceExperiment == nil then
        return nil
    end

    return normalizeAppearanceDetail({
        applied = modData.LWN_HybridAppearanceApplied == true,
        experiment = modData.LWN_HybridAppearanceExperiment,
        reuse = modData.LWN_HybridAppearanceReuse,
        bridgeMode = modData.LWN_HybridAppearanceBridge or "none",
        descriptorMode = modData.LWN_HybridAppearanceDescriptorMode,
        descriptorSource = modData.LWN_HybridDescriptorSource
            or (modData.LWN_HybridAppearanceDescriptorMode and string.format(
                "npc_record_survivor_desc_%s",
                tostring(modData.LWN_HybridAppearanceDescriptorMode)
            ))
            or "npc_record_identity_seed",
        stage = modData.LWN_HybridAppearanceStage,
        status = modData.LWN_HybridAppearanceStatus,
    })
end

local function applyAppearanceExperiment(record, actor, stageBase)
    local cached = cachedAppearanceDetail(actor)
    if cached and cached.applied == true then
        cached = normalizeAppearanceDetail(cached, {
            stage = string.format("%s_cached", tostring(stageBase or "appearance")),
            status = "applied",
        })
        trace("appearance.cached", record, string.format(
            "stage=%s desc=%s mode=%s reuse=%s bridge=%s",
            tostring(cached.stage),
            tostring(cached.descriptorSource or "nil"),
            tostring(cached.descriptorMode or "nil"),
            tostring(cached.reuse or "nil"),
            tostring(cached.bridgeMode or "nil")
        ))
        return protectedCall(actor, "getDescriptor"), cached
    end
    if not (LWN.ActorFactory and LWN.ActorFactory.applySafeAppearanceShaping) then
        trace("appearance.skipped", record, string.format("stage=%s reason=helper_missing", tostring(stageBase or "appearance")))
        return nil, normalizeAppearanceDetail(nil, {
            bridgeMode = "helper_missing",
            descriptorMode = "unavailable",
            descriptorSource = "npc_record_identity_seed",
            stage = string.format("%s_skipped", tostring(stageBase or "appearance")),
            status = "skipped",
        })
    end

    local ok, descriptor, detail = pcall(LWN.ActorFactory.applySafeAppearanceShaping, record, actor, {
        source = "CarrierIsoZombie.applyAppearanceExperiment",
        experimentName = ISOZOMBIE_APPEARANCE_EXPERIMENT,
    })
    if not ok then
        trace("appearance.error", record, string.format("stage=%s error=%s", tostring(stageBase), tostring(descriptor)))
        return nil, normalizeAppearanceDetail(nil, {
            bridgeMode = "error",
            descriptorMode = "error",
            descriptorSource = "npc_record_identity_seed",
            stage = string.format("%s_error", tostring(stageBase or "appearance")),
            status = "skipped",
        })
    end

    detail = normalizeAppearanceDetail(detail, {
        stage = string.format(
            "%s_%s",
            tostring(stageBase or "appearance"),
            detail and detail.applied == true and "applied" or "skipped"
        ),
        status = detail and detail.applied == true and "applied" or "skipped",
    })

    trace("appearance.experiment", record, string.format(
        "stage=%s applied=%s desc=%s mode=%s reuse=%s bridge=%s",
        tostring(detail and detail.stage or "nil"),
        tostring(detail and detail.applied == true),
        tostring(detail and detail.descriptorSource or "nil"),
        tostring(detail and detail.descriptorMode or "nil"),
        tostring(detail and detail.reuse or "nil"),
        tostring(detail and detail.bridgeMode or "nil")
    ))

    return descriptor, detail
end

local function assessAppearanceEligibility(actor)
    if not actor then
        return false, "appearance_ineligible actor=nil"
    end

    local square = protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")
    local inWorld = protectedCall(actor, "isExistInTheWorld") == true
    local isZombie = protectedCall(actor, "isZombie") == true

    if not inWorld or not square or not isZombie then
        return false, string.format(
            "appearance_ineligible inWorld=%s squarePresent=%s isZombie=%s",
            tostring(inWorld),
            tostring(square ~= nil),
            tostring(isZombie)
        )
    end

    return true, string.format(
        "appearance_eligible inWorld=%s squarePresent=%s isZombie=%s",
        tostring(inWorld),
        tostring(square ~= nil),
        tostring(isZombie)
    )
end

local function stageBaseForAction(actionName, runtimeOk)
    return string.format("%s_%s", tostring(actionName or "appearance"), runtimeOk == true and "ready" or "pending")
end

local function humanizationProfile(record)
    local harness = record and record.debugHarness or nil
    if harness and harness.enabled == true and harness.forceFriendly == true then
        return "friendly"
    end
    local policy = relationshipCombatPolicy(record)
    return policy and policy.state or "neutral"
end

-- Friendly/neutral shells should drop any stale queued aggression as well as target refs.
local function clearCombatIntent(actor)
    protectedCall(actor, "StopAllActionQueue")
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setAttackedBy", nil)
    protectedCall(actor, "setTargetSeenTime", 0)
    protectedCall(actor, "setPath2", nil)
    protectedCall(actor, "setMoving", false)
end

local function getPrimaryPlayer(options)
    local player = options and options.player or nil
    if player then return player end
    if getSpecificPlayer then
        return getSpecificPlayer(0)
    end
    return nil
end

local function clearRuntimeIntent(record, actor)
    if record and LWN.ActionRuntime and LWN.ActionRuntime.clear then
        LWN.ActionRuntime.clear(record, actor)
    end
end

local function stopZombieCodedAudio(actor)
    local emitter = protectedCall(actor, "getEmitter")
    if emitter then
        protectedCall(emitter, "stopAll")
        protectedCall(emitter, "stopSoundByName", "MaleZombieCombined")
        protectedCall(emitter, "stopSoundByName", "FemaleZombieCombined")
    end
end

local function applyPersistentIllusionPackage(record, actor, descriptor, policy)
    if not actor then return end
    policy = policy or relationshipCombatPolicy(record)

    protectedCall(actor, "setVariable", "LWNManagedShell", true)
    protectedCall(actor, "setVariable", "NoLungeTarget", true)
    protectedCall(actor, "setVariable", "ZombieHitReaction", "Chainsaw")
    protectedCall(actor, "setWalkType", "Walk")
    protectedCall(actor, "setVariable", "BanditWalkType", "Walk")

    if descriptor then
        protectedCall(descriptor, "setVoicePrefix", "NotAZombie")
    end

    stopZombieCodedAudio(actor)

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_PersistentIllusionPackage = policy.shouldNeutralizeCarrier == true
            and "walk_human+no_lunge+voice_notazombie+audio_stopall+hitreaction_guard"
            or "walk_human+no_lunge+voice_notazombie+audio_stopall+hitreaction_guard"
        modData.LWN_AudioHumanization = "descriptor_voiceprefix+emitter_stopall"
        modData.LWN_AnimationHumanization = "walktype=Walk"
    end
end

local function applyRelationshipCombatState(record, actor, options, policy)
    if not actor then return nil end
    policy = policy or relationshipCombatPolicy(record)
    local player = getPrimaryPlayer(options)
    local harness = record and record.debugHarness or nil

    protectedCall(actor, "setGodMod", policy.allowPlayerAttack ~= true)

    if policy.shouldNeutralizeCarrier == true then
        protectedCall(actor, "setUseless", true)
        protectedCall(actor, "setCanWalk", false)
        protectedCall(actor, "setNoTeeth", true)
        clearCombatIntent(actor)
        clearRuntimeIntent(record, actor)
        if harness and harness.holdPosition == true then
            protectedCall(actor, "setTarget", nil)
            protectedCall(actor, "setLastTargettedBy", nil)
            protectedCall(actor, "setPath2", nil)
            protectedCall(actor, "setMoving", false)
            protectedCall(actor, "setDir", IsoDirections and IsoDirections.S or nil)
        end
    else
        protectedCall(actor, "setUseless", false)
        protectedCall(actor, "setCanWalk", true)
        protectedCall(actor, "setNoTeeth", policy.allowCarrierAttackPlayer ~= true)
        if policy.allowCarrierAttackPlayer == true and player then
            protectedCall(actor, "setTarget", player)
            protectedCall(actor, "faceThisObject", player)
            protectedCall(actor, "pathToCharacter", player)
        else
            clearCombatIntent(actor)
            clearRuntimeIntent(record, actor)
        end
    end

    return policy
end

local function applyBasicZombieCarrierFlags(record, actor, options, descriptor, appearanceDetail)
    if not actor then return end
    local modData = protectedCall(actor, "getModData")
    local policy = relationshipCombatPolicy(record)
    local summary = relationshipPolicySummary(record, policy)
    if modData and record then
        local illusion = record.embodiment and record.embodiment.illusion or nil
        local harness = record.debugHarness or nil
        modData.LWN_NpcId = record.id
        modData.LWN_LastNpcId = record.id
        modData.LWN_CarrierKind = "isozombie"
        modData.LWN_ActorKind = tostring(protectedCall(actor, "getObjectName") or "IsoZombie")
        modData.LWN_SessionId = record.embodiment and record.embodiment.sessionId or modData.LWN_SessionId
        modData.LWN_ShellMarker = string.format("isozombie:%s", tostring(record.id))
        modData.LWN_CarrierSpike = true
        modData.LWN_RelationState = policy.state
        modData.LWN_RelationshipPolicySummary = summary
        modData.LWN_AllowPlayerAttack = policy.allowPlayerAttack == true
        modData.LWN_AllowCarrierAttackPlayer = policy.allowCarrierAttackPlayer == true
        modData.LWN_CarrierCombatMode = carrierCombatMode(policy)
        modData.LWN_FriendlySuppression = friendlySuppressionSummary(policy)
        modData.LWN_MovementSuppression = policy.shouldNeutralizeCarrier == true and "clearqueue+cleartarget+clearpath+combat_block" or "hostile_pathing"
        modData.LWN_AudioLeakHint = policy.shouldNeutralizeCarrier == true and "should_be_quiet_non_hostile" or "hostile_vocal_leak_possible"
        modData.LWN_HostilityReason = policy.reason
        modData.LWN_RelationshipPolicyAppliedAt = worldAgeHours()
        modData.LWN_HumanizationProfile = humanizationProfile(record)
        modData.LWN_HumanizationInitialApplied = illusion and illusion.initialApplied == true or false
        modData.LWN_HumanizationInitialAt = illusion and illusion.initialAppliedAt or nil
        modData.LWN_HumanizationInitialSignature = illusion and illusion.initialAppearanceSignature or nil
        modData.LWN_HumanizationMaintenanceAt = illusion and illusion.lastMaintenanceAt or nil
        modData.LWN_HumanizationMaintenanceMode = illusion and illusion.lastMaintenanceMode or nil
        modData.LWN_HumanizationDriftCount = illusion and illusion.driftCount or 0
        modData.LWN_TestHarnessLabel = harness and harness.label or nil
        modData.LWN_TestHarnessEnabled = harness and harness.enabled == true or false
        modData.LWN_TestHarnessHoldPosition = harness and harness.holdPosition == true or false
        modData.LWN_TestHarnessIdentityLock = harness and harness.identityLock == true or false
        modData.LWN_TestHarnessSterileRadius = harness and harness.sterileRadius or nil
    end

    stampHybridSummary(record, actor, summary, descriptor, appearanceDetail)
    applyPersistentIllusionPackage(record, actor, descriptor, policy)
    applyRelationshipCombatState(record, actor, options, policy)

    protectedCall(actor, "setFakeDead", false)
    protectedCall(actor, "setCrawler", false)
    protectedCall(actor, "setSitAgainstWall", false)
    protectedCall(actor, "setReanimate", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setHealth", 1)
end

local function assessRuntimeReadiness(actor)
    if not actor then
        return false, "actor=nil"
    end

    local bodyDamage = protectedCall(actor, "getBodyDamage")
    local stats = protectedCall(actor, "getStats")
    local square = protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")
    local inWorld = protectedCall(actor, "isExistInTheWorld") == true
    local isZombie = protectedCall(actor, "isZombie") == true

    if not bodyDamage or not inWorld or not square or not isZombie then
        return false, string.format(
            "runtime_core_missing bodyDamage=%s stats=%s inWorld=%s squarePresent=%s isZombie=%s",
            tostring(bodyDamage ~= nil),
            tostring(stats ~= nil),
            tostring(inWorld),
            tostring(square ~= nil),
            tostring(isZombie)
        )
    end

    return true, string.format(
        "runtime_ready bodyDamage=%s stats=%s inWorld=%s squarePresent=%s isZombie=%s",
        tostring(bodyDamage ~= nil),
        tostring(stats ~= nil),
        tostring(inWorld),
        tostring(square ~= nil),
        tostring(isZombie)
    )
end

local function runHumanizationPass(record, actor, options, actionName, runtimeOk)
    local stageBase = stageBaseForAction(actionName, runtimeOk)
    local appearanceOk, appearanceGateDetail = assessAppearanceEligibility(actor)
    local profile = humanizationProfile(record)

    if appearanceOk ~= true then
        local skippedDetail = normalizeAppearanceDetail(nil, {
            bridgeMode = "ineligible",
            descriptorMode = "ineligible",
            descriptorSource = "ineligible",
            stage = string.format("%s_ineligible", tostring(stageBase)),
            status = "skipped",
            profile = profile,
            mode = actionName == "spawn" and "initial" or "maintenance",
        })
        trace("humanization.skipped", record, string.format("stage=%s | %s", tostring(stageBase), tostring(appearanceGateDetail)))
        applyBasicZombieCarrierFlags(record, actor, options, nil, skippedDetail)
        return nil, skippedDetail, false, appearanceGateDetail
    end

    local preAppearanceDetail = normalizeAppearanceDetail(nil, {
        stage = string.format("%s_pre", tostring(stageBase)),
        status = "pending",
        profile = profile,
        mode = actionName == "spawn" and "initial_pending" or "maintenance_pending",
    })
    applyBasicZombieCarrierFlags(record, actor, options, nil, preAppearanceDetail)

    local descriptor = nil
    local appearanceDetail = nil
    if LWN.ShellHumanizer then
        local shouldApplyInitial = actionName == "spawn"
            or (LWN.ShellHumanizer.hasInitialApplied and LWN.ShellHumanizer.hasInitialApplied(record, actor) ~= true)
        if shouldApplyInitial and LWN.ShellHumanizer.applyInitial then
            descriptor, appearanceDetail = LWN.ShellHumanizer.applyInitial(record, actor, {
                source = string.format("CarrierIsoZombie.%s.initial", tostring(actionName)),
                profile = profile,
            })
        elseif LWN.ShellHumanizer.maintain then
            descriptor, appearanceDetail = LWN.ShellHumanizer.maintain(record, actor, {
                source = string.format("CarrierIsoZombie.%s.maintain", tostring(actionName)),
                profile = profile,
            })
        end
    end

    if descriptor == nil and appearanceDetail == nil then
        descriptor, appearanceDetail = applyAppearanceExperiment(record, actor, stageBase)
        appearanceDetail = normalizeAppearanceDetail(appearanceDetail, {
            profile = profile,
            mode = actionName == "spawn" and "legacy_initial_fallback" or "legacy_maintenance_fallback",
        })
    end

    applyBasicZombieCarrierFlags(record, actor, options, descriptor, appearanceDetail)
    return descriptor, appearanceDetail, true, appearanceGateDetail
end

local function markNoAutoRearm(record)
    if record and record.embodiment then
        record.embodiment.noAutoRearm = true
        record.embodiment.state = "hidden"
        record.embodiment.actorId = nil
        record.embodiment.cooldownUntilHour = worldAgeHours() + 24
    end
end

local function shallowRetire(record, actor, reason)
    if not actor then
        return {
            ok = true,
            status = "retired",
            detail = "isozombie_shallow_retire_actor=nil",
        }
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_NpcId = nil
    end

    protectedCall(actor, "setInvisible", true)
    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")
    markNoAutoRearm(record)

    trace("retire.shallow", record, string.format(
        "reason=%s world=%s squarePresent=%s",
        tostring(reason),
        tostring(protectedCall(actor, "isExistInTheWorld")),
        tostring((protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")) ~= nil)
    ))

    return {
        ok = true,
        status = "retired",
        detail = string.format("isozombie_shallow_retire reason=%s", tostring(reason)),
    }
end

function Carrier.kind()
    return "isozombie"
end

function Carrier.canSpawn(record, options)
    if not addZombiesInOutfit then
        return false, "addZombiesInOutfit_missing"
    end
    return true, "addZombiesInOutfit_available"
end

function Carrier.spawn(record, options)
    record = ensureRecordShape(record)
    local ok, detail = Carrier.canSpawn(record, options)
    if ok ~= true then
        trace("spawn.unavailable", record, detail)
        return {
            ok = false,
            actor = nil,
            detail = detail,
            handle = {
                kind = "isozombie",
                actor = nil,
                status = "failed",
                spawnedAt = worldAgeHours(),
                detail = detail,
            },
        }
    end

    local square = ensureSquare(record, options and options.player or nil)
    local actor, spawnDetail = spawnZombieAtSquare(square, record)
    if not actor then
        local detailText = string.format("spawn_failed | %s", tostring(spawnDetail))
        trace("spawn.failed", record, detailText)
        return {
            ok = false,
            actor = nil,
            detail = detailText,
            handle = {
                kind = "isozombie",
                actor = nil,
                status = "failed",
                spawnedAt = worldAgeHours(),
                detail = detailText,
            },
        }
    end

    local runtimeOk, runtimeDetail = assessRuntimeReadiness(actor)
    local _, appearanceDetail, appearanceEligible, appearanceGateDetail = runHumanizationPass(
        record,
        actor,
        options,
        "spawn",
        runtimeOk
    )
    local spawnedAt = worldAgeHours()
    trace(runtimeOk and "spawn.runtime_ready" or "spawn.pending_settle", record, string.format(
        "spawn=%s | humanization=%s mode=%s | %s",
        tostring(spawnDetail),
        appearanceEligible == true and tostring(appearanceDetail and appearanceDetail.stage or "eligible") or tostring(appearanceGateDetail),
        tostring(appearanceDetail and appearanceDetail.mode or "nil"),
        tostring(runtimeDetail)
    ))

    return {
        ok = true,
        actor = actor,
        detail = runtimeOk == true
            and string.format("isozombie_spawned_via=%s", tostring(spawnDetail))
            or string.format("isozombie_pending_settle via=%s | %s", tostring(spawnDetail), tostring(runtimeDetail)),
        handle = {
            kind = "isozombie",
            actor = actor,
            status = runtimeOk == true and "active" or "pending_settle",
            spawnedAt = spawnedAt,
            detail = runtimeOk == true
                and string.format("isozombie_spawned_via=%s", tostring(spawnDetail))
                or string.format("isozombie_pending_settle via=%s | %s", tostring(spawnDetail), tostring(runtimeDetail)),
            runtime = {
                spawnDetail = spawnDetail,
                runtimeDetail = runtimeDetail,
                appearanceEligible = appearanceEligible == true,
                appearanceEligibilityDetail = appearanceGateDetail,
                appearanceExperiment = appearanceDetail and appearanceDetail.experiment or nil,
                appearanceApplied = appearanceDetail and appearanceDetail.applied == true or false,
                appearanceStatus = appearanceDetail and appearanceDetail.status or nil,
                appearanceStage = appearanceDetail and appearanceDetail.stage or nil,
                humanizationMode = appearanceDetail and appearanceDetail.mode or nil,
                humanizationProfile = appearanceDetail and appearanceDetail.profile or humanizationProfile(record),
                initialHumanizationApplied = record.embodiment and record.embodiment.illusion and record.embodiment.illusion.initialApplied == true or false,
                neutralized = true,
                settlePending = runtimeOk ~= true,
                settleAttempts = 0,
                settleStartedAt = spawnedAt,
            },
        },
    }
end

function Carrier.sync(record, handle, options)
    record = ensureRecordShape(record)
    local actor = handle and handle.actor or nil
    if not actor then
        return {
            ok = false,
            status = "failed",
            detail = "isozombie_handle_actor=nil",
        }
    end

    handle.runtime = handle.runtime or {}
    local runtimeOk, runtimeDetail = assessRuntimeReadiness(actor)
    local _, appearanceDetail, appearanceEligible, appearanceGateDetail = runHumanizationPass(
        record,
        actor,
        options,
        "sync",
        runtimeOk
    )
    handle.runtime.appearanceEligible = appearanceEligible == true
    handle.runtime.appearanceEligibilityDetail = appearanceGateDetail
    handle.runtime.appearanceExperiment = appearanceDetail and appearanceDetail.experiment or nil
    handle.runtime.appearanceApplied = appearanceDetail and appearanceDetail.applied == true or false
    handle.runtime.appearanceStatus = appearanceDetail and appearanceDetail.status or nil
    handle.runtime.appearanceStage = appearanceDetail and appearanceDetail.stage or nil
    handle.runtime.humanizationMode = appearanceDetail and appearanceDetail.mode or nil
    handle.runtime.humanizationProfile = appearanceDetail and appearanceDetail.profile or humanizationProfile(record)
    handle.runtime.initialHumanizationApplied = record.embodiment and record.embodiment.illusion and record.embodiment.illusion.initialApplied == true or false
    handle.runtime.runtimeDetail = runtimeDetail
    if runtimeOk ~= true then
        local settleAttempts = (tonumber(handle.runtime.settleAttempts) or 0) + 1
        local settleStartedAt = tonumber(handle.runtime.settleStartedAt or handle.spawnedAt or worldAgeHours()) or worldAgeHours()
        local elapsed = math.max(0, worldAgeHours() - settleStartedAt)
        handle.runtime.settlePending = true
        handle.runtime.settleAttempts = settleAttempts
        handle.runtime.settleStartedAt = settleStartedAt

        if settleAttempts < ISOZOMBIE_SETTLE_MAX_SYNC_ATTEMPTS and elapsed < ISOZOMBIE_SETTLE_MAX_HOURS then
            trace("sync.pending_settle", record, string.format(
                "attempt=%s/%s elapsed=%.6f/%.6f | humanization=%s mode=%s | %s",
                settleAttempts,
                ISOZOMBIE_SETTLE_MAX_SYNC_ATTEMPTS,
                elapsed,
                ISOZOMBIE_SETTLE_MAX_HOURS,
                appearanceEligible == true and tostring(appearanceDetail and appearanceDetail.stage or "eligible") or tostring(appearanceGateDetail),
                tostring(appearanceDetail and appearanceDetail.mode or "nil"),
                tostring(runtimeDetail)
            ))
            return {
                ok = true,
                status = "pending_settle",
                detail = string.format("isozombie_pending_settle attempt=%s | %s", tostring(settleAttempts), tostring(runtimeDetail)),
            }
        end

        trace("sync.runtime_rejected", record, string.format("attempt=%s elapsed=%.6f | %s", settleAttempts, elapsed, tostring(runtimeDetail)))
        shallowRetire(record, actor, "isozombie_runtime_core_missing")
        return {
            ok = false,
            status = "failed",
            detail = string.format("isozombie_runtime_rejected=%s", tostring(runtimeDetail)),
        }
    end

    handle.runtime.settlePending = false
    handle.runtime.runtimeDetail = runtimeDetail

    local anchor = record and record.anchor or nil
    if anchor then
        protectedCall(actor, "setX", tonumber(anchor.x) + 0.5)
        protectedCall(actor, "setY", tonumber(anchor.y) + 0.5)
        protectedCall(actor, "setZ", tonumber(anchor.z))
    end
    if record and record.stats and record.stats.health then
        protectedCall(actor, "setHealth", tonumber(record.stats.health) or 1)
    end

    return {
        ok = true,
        status = "active",
        detail = options and options.mode == "presentation" and "isozombie_synced_presentation" or "isozombie_synced_light",
    }
end

function Carrier.retire(record, handle, options)
    record = ensureRecordShape(record)
    local actor = handle and handle.actor or nil
    local reason = options and options.reason or "carrier_retire"
    return shallowRetire(record, actor, reason)
end

function Carrier.isUsable(handle)
    local actor = handle and handle.actor or nil
    if not actor then return false end
    return protectedCall(actor, "isExistInTheWorld") == true and protectedCall(actor, "isZombie") == true
end

function Carrier.getActor(handle)
    return handle and handle.actor or nil
end
