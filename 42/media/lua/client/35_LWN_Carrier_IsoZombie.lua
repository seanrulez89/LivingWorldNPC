LWN = LWN or {}
LWN.Carriers = LWN.Carriers or {}

local Carrier = {}
LWN.Carriers.isozombie = Carrier

local Store = LWN.PopulationStore
Carrier.ManagedShellCache = Carrier.ManagedShellCache or {
    byNpcId = {},
    byActorRef = {},
}

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

local function isMinimalDummyRecord(record)
    return LWN.Social and LWN.Social.isMinimalDummyRecord and LWN.Social.isMinimalDummyRecord(record)
end

local function relationshipCombatPolicy(record)
    if isMinimalDummyRecord(record) and LWN.Social and LWN.Social.minimalDummyPolicy then
        return LWN.Social.minimalDummyPolicy(record)
    end
    local harness = record and record.debugHarness or nil
    if harness and harness.enabled == true and harness.quarantine == true then
        return {
            state = harness.forceFriendly == true and "friendly" or "neutral",
            allowPlayerAttack = true,
            allowCarrierAttackPlayer = false,
            shouldNeutralizeCarrier = true,
            allowMovement = false,
            allowAutonomousMovement = false,
            shellMode = "debug_quarantine",
            reason = "debug_test_harness_quarantine",
        }
    end
    if harness and harness.enabled == true and harness.holdPosition == true then
        return {
            state = harness.forceFriendly == true and "friendly" or "neutral",
            allowPlayerAttack = true,
            allowCarrierAttackPlayer = false,
            shouldNeutralizeCarrier = true,
            allowMovement = harness.allowCommandMovement ~= false,
            allowAutonomousMovement = false,
            shellMode = harness.allowCommandMovement == false and "non_hostile_hold" or "non_hostile_commandable",
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
        allowMovement = true,
        allowAutonomousMovement = true,
        shellMode = "non_hostile_mobile",
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
    if policy.shouldNeutralizeCarrier == true and policy.allowMovement == true then
        return policy.shellMode or "non_hostile_mobile"
    end
    if policy.shouldNeutralizeCarrier == true then
        return "neutralized"
    end
    return "idle"
end

local function friendlySuppressionSummary(policy)
    if policy.allowPlayerAttack ~= true then
        return "godmod+managed_shell_contract"
    end
    if policy.shouldNeutralizeCarrier == true and policy.allowMovement == true then
        return "managed_shell_contract+clear_target+keep_path+walktype_guard"
    end
    if policy.shouldNeutralizeCarrier == true then
        return "managed_shell_contract+clearqueue+clearpath"
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
    if isMinimalDummyRecord(record) then
        return "neutral_dummy"
    end
    local harness = record and record.debugHarness or nil
    if harness and harness.enabled == true and harness.forceFriendly == true then
        return "friendly"
    end
    local policy = relationshipCombatPolicy(record)
    return policy and policy.state or "neutral"
end

-- Friendly/neutral shells should drop any stale queued aggression as well as target refs.
local function clearCombatIntent(actor, options)
    if not (options and options.stopActions == false) then
        protectedCall(actor, "StopAllActionQueue")
    end
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setAttackedBy", nil)
    protectedCall(actor, "setLastTargettedBy", nil)
    protectedCall(actor, "setEatBodyTarget", nil, false)
    protectedCall(actor, "setTargetSeenTime", 0)
    if not (options and options.clearPath == false) then
        protectedCall(actor, "setPath2", nil)
        protectedCall(actor, "setMoving", false)
    end
end

local stopZombieCodedAudio

local function shellObjectRef(actor)
    if not actor then return nil end
    return tostring(actor)
end

local function registerManagedShell(record, actor, source)
    if not (record and record.id and actor) then return nil end
    local ref = shellObjectRef(actor)
    local cache = Carrier.ManagedShellCache
    if not cache then return nil end

    cache.byNpcId[record.id] = actor
    if ref then
        cache.byActorRef[ref] = {
            actor = actor,
            npcId = record.id,
            source = source or "CarrierIsoZombie.registerManagedShell",
            seenAt = worldAgeHours(),
        }
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_ManagedShellContract = true
        modData.LWN_ManagedShellCacheSource = source or "CarrierIsoZombie.registerManagedShell"
        modData.LWN_ManagedShellCacheSeenAt = worldAgeHours()
        modData.LWN_ManagedShellRef = ref
        modData.LWN_ManagedShellLastX = protectedCall(actor, "getX")
        modData.LWN_ManagedShellLastY = protectedCall(actor, "getY")
        modData.LWN_ManagedShellLastZ = protectedCall(actor, "getZ")
    end

    return actor
end

function Carrier.getKnownShellByNpcId(npcId)
    if not npcId then return nil end
    local cache = Carrier.ManagedShellCache
    local actor = cache and cache.byNpcId and cache.byNpcId[npcId] or nil
    if not actor then return nil end
    if protectedCall(actor, "isDestroyed") == true then return nil end
    if protectedCall(actor, "isZombie") ~= true then return nil end
    if protectedCall(actor, "isExistInTheWorld") == false then return nil end
    return actor
end

function Carrier.isKnownManagedShell(actor)
    if not actor then return false end
    local ref = shellObjectRef(actor)
    local cache = Carrier.ManagedShellCache
    if ref and cache and cache.byActorRef and cache.byActorRef[ref] then
        return true
    end
    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_ManagedShellContract == true or false
end

local function applyManagedShellContract(record, actor, policy, options)
    if not actor then return nil end
    policy = policy or relationshipCombatPolicy(record)
    options = options or {}
    local allowMovement = options.allowMovement
    if allowMovement == nil then
        allowMovement = policy and policy.allowMovement == true
    end
    local neutralized = options.neutralized
    if neutralized == nil then
        neutralized = policy and policy.shouldNeutralizeCarrier == true and allowMovement ~= true
    end

    protectedCall(actor, "setVariable", "LWNManagedShell", true)
    protectedCall(actor, "setVariable", "NoLungeTarget", true)
    protectedCall(actor, "setVariable", "ZombieHitReaction", "Chainsaw")
    protectedCall(actor, "setWalkType", "Walk")
    protectedCall(actor, "setVariable", "BanditWalkType", "Walk")
    protectedCall(actor, "setNoTeeth", policy and policy.allowCarrierAttackPlayer ~= true)
    protectedCall(actor, "setPrimaryHandItem", nil)
    protectedCall(actor, "setSecondaryHandItem", nil)
    protectedCall(actor, "resetEquippedHandsModels")
    protectedCall(actor, "clearAttachedItems")
    protectedCall(actor, "setUseless", neutralized == true)
    protectedCall(actor, "setCanWalk", allowMovement == true)

    if options.clearCombat ~= false then
        clearCombatIntent(actor, {
            stopActions = allowMovement == true,
            clearPath = allowMovement ~= true,
        })
    end

    if options.stopAudio == true then
        stopZombieCodedAudio(actor)
    end

    return registerManagedShell(record, actor, options.source or "CarrierIsoZombie.applyManagedShellContract")
end

local function applyShellLaneContract(record, actor, policy, options)
    if not actor then return nil end
    policy = policy or relationshipCombatPolicy(record)
    options = options or {}
    local lane = options.forceLane or policy.shellMode or "non_hostile_mobile"
    local laneOptions = {
        source = options.source or "CarrierIsoZombie.applyShellLaneContract",
        stopAudio = options.stopAudio,
    }

    if lane == "debug_quarantine" then
        laneOptions.allowMovement = false
        laneOptions.neutralized = true
        laneOptions.clearCombat = true
    elseif lane == "non_hostile_hold" or lane == "dummy_idle" then
        laneOptions.allowMovement = false
        laneOptions.neutralized = true
        laneOptions.clearCombat = true
    elseif lane == "non_hostile_commandable" or lane == "non_hostile_mobile" or lane == "recovery_non_hostile_mobile" or lane == "dummy_move" then
        laneOptions.allowMovement = true
        laneOptions.neutralized = false
        laneOptions.clearCombat = true
    else
        laneOptions.allowMovement = options.allowMovement
        laneOptions.neutralized = options.neutralized
        laneOptions.clearCombat = options.clearCombat
    end

    local applied = applyManagedShellContract(record, actor, policy, laneOptions)
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_ShellLaneContract = lane
        modData.LWN_ShellLaneContractSource = laneOptions.source
        modData.LWN_ShellLaneAllowMovement = laneOptions.allowMovement == true
        modData.LWN_ShellLaneNeutralized = laneOptions.neutralized == true
        modData.LWN_ShellLaneClearCombat = laneOptions.clearCombat ~= false
    end
    return applied
end

function Carrier.reassertManagedShellContract(record, actor, options)
    options = options or {}
    local policy = options.policy or relationshipCombatPolicy(record)
    local allowMovement = options.allowMovement
    if allowMovement == nil then
        allowMovement = policy and policy.allowMovement == true
    end
    local neutralized = options.neutralized
    if neutralized == nil then
        neutralized = policy and policy.shouldNeutralizeCarrier == true and allowMovement ~= true
    end
    return applyShellLaneContract(record, actor, policy, {
        source = options.source or "CarrierIsoZombie.reassertManagedShellContract",
        allowMovement = allowMovement,
        neutralized = neutralized,
        clearCombat = options.clearCombat,
        stopAudio = options.stopAudio,
        forceLane = options.forceLane,
    })
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

stopZombieCodedAudio = function(actor)
    local emitter = protectedCall(actor, "getEmitter")
    if emitter then
        protectedCall(emitter, "stopSoundByName", "MaleZombieCombined")
        protectedCall(emitter, "stopSoundByName", "FemaleZombieCombined")
        protectedCall(emitter, "stopSoundByName", "ZombieIdle")
        protectedCall(emitter, "stopSoundByName", "ZombieAttack")
        protectedCall(emitter, "stopSoundByName", "MaleZombieAttack")
        protectedCall(emitter, "stopSoundByName", "FemaleZombieAttack")
        protectedCall(emitter, "stopSoundByName", "MaleZombieIdle")
        protectedCall(emitter, "stopSoundByName", "FemaleZombieIdle")
    end
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_AudioHumanization = "descriptor_voiceprefix+targeted_zombie_mute"
        modData.LWN_AudioStopAllDisabled = true
    end
end

local function applyDummyVoicePrefix(actor)
    local descriptor = protectedCall(actor, "getDescriptor")
    if descriptor then
        protectedCall(descriptor, "setVoicePrefix", "NotAZombie")
    end
end

local function clearAllZombieAggro(actor, options)
    options = options or {}
    clearCombatIntent(actor, {
        stopActions = options.stopActions,
        clearPath = options.clearPath,
    })
    protectedCall(actor, "clearVariable", "AttackAnim")
    protectedCall(actor, "clearVariable", "AttackCollisionCheck")
    protectedCall(actor, "clearVariable", "AttackDidDamage")
    protectedCall(actor, "clearVariable", "AttackOutcome")
    protectedCall(actor, "clearVariable", "isattacking")
    protectedCall(actor, "clearVariable", "attacking")
    protectedCall(actor, "clearVariable", "bAttack")
    protectedCall(actor, "clearVariable", "bAttacking")
    protectedCall(actor, "clearVariable", "battackfrombehind")
    protectedCall(actor, "clearVariable", "bdoshove")
    protectedCall(actor, "clearVariable", "bDoShove")
    protectedCall(actor, "clearVariable", "bShoveAiming")
    protectedCall(actor, "clearVariable", "Bite")
    protectedCall(actor, "clearVariable", "BiteDefended")
    protectedCall(actor, "clearVariable", "bAiming")
    protectedCall(actor, "clearVariable", "Aiming")
    protectedCall(actor, "clearVariable", "ZombieFaceTarget")
    protectedCall(actor, "clearVariable", "TurnTowardsTarget")
    protectedCall(actor, "clearVariable", "turning")
    protectedCall(actor, "clearVariable", "bTurning")
    protectedCall(actor, "clearVariable", "ZombieTurnAlerted")
    protectedCall(actor, "clearVariable", "ZombieTurnRight")
    protectedCall(actor, "clearVariable", "ZombieTurnLeft")
end

local function applyDummyAudioMute(actor, source)
    applyDummyVoicePrefix(actor)
    stopZombieCodedAudio(actor)
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyAudioMuteAppliedAt = worldAgeHours()
        modData.LWN_DummyAudioMuteSource = source or "CarrierIsoZombie.applyDummyAudioMute"
        modData.LWN_AudioLeakHint = "dummy_targeted_zombie_mute"
    end
end

local function applyPostureHumanization(record, actor, source, options)
    if not actor then return end
    local neutralized = options and options.neutralized == true or false

    applyManagedShellContract(record, actor, relationshipCombatPolicy(record), {
        source = source or "CarrierIsoZombie.applyPostureHumanization",
        allowMovement = neutralized ~= true,
        neutralized = neutralized,
        clearCombat = neutralized == true,
        stopAudio = false,
    })
    if neutralized == true or protectedCall(actor, "isMoving") ~= true then
        protectedCall(actor, "setIdleAnimatorState")
    end
    protectedCall(actor, "clearVariable", "TimedActionType")
    protectedCall(actor, "clearVariable", "BumpFallType")
    protectedCall(actor, "clearVariable", "WeaponReloadType")
    protectedCall(actor, "clearVariable", "bdoshove")
    protectedCall(actor, "clearVariable", "bDoShove")
    protectedCall(actor, "clearVariable", "isattacking")
    protectedCall(actor, "clearVariable", "AttackAnim")
    protectedCall(actor, "clearVariable", "bShoveAiming")
    protectedCall(actor, "clearVariable", "BumpFall")
    if neutralized == true then
        protectedCall(actor, "clearVariable", "bPathfind")
    end
    protectedCall(actor, "clearVariable", "bKnockedDown")
    protectedCall(actor, "clearVariable", "FallOnFront")
    protectedCall(actor, "clearVariable", "ZombieTurnAlerted")
    protectedCall(actor, "clearVariable", "ZombieTurnRight")
    protectedCall(actor, "clearVariable", "ZombieTurnLeft")
    protectedCall(actor, "clearVariable", "onknees")
    protectedCall(actor, "clearVariable", "frombehind")
    protectedCall(actor, "clearVariable", "ragdollbump")
    protectedCall(actor, "setOnFloor", false)
    protectedCall(actor, "setFallOnFront", false)
    if neutralized then
        protectedCall(actor, "setMoving", false)
        protectedCall(actor, "setPath2", nil)
        protectedCall(actor, "setTarget", nil)
        protectedCall(actor, "setLastTargettedBy", nil)
        protectedCall(actor, "setDir", IsoDirections and IsoDirections.S or nil)
    end
    if LWN.ActorFactory and LWN.ActorFactory.refreshActorPresentation then
        LWN.ActorFactory.refreshActorPresentation(actor)
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_PostureHumanization = neutralized == true
            and "idle_anim_reset+walktype=Walk+anti_hunch_neutralized"
            or "idle_anim_reset+walktype=Walk+anti_hunch_active"
        modData.LWN_PostureHumanizationSource = source or "CarrierIsoZombie.applyPostureHumanization"
    end
end

local function applyHardDummyShellContract(record, actor, mode, source)
    if not (actor and isMinimalDummyRecord(record)) then return nil end
    mode = mode == "move" and "move" or "idle"
    local lane = mode == "move" and "dummy_move" or "dummy_idle"
    local applied = applyShellLaneContract(record, actor, relationshipCombatPolicy(record), {
        source = source or "CarrierIsoZombie.applyHardDummyShellContract",
        allowMovement = mode == "move",
        neutralized = mode ~= "move",
        clearCombat = true,
        stopAudio = true,
        forceLane = lane,
    })

    clearAllZombieAggro(actor, {
        stopActions = mode ~= "move",
        clearPath = mode ~= "move",
    })
    scrubDummyAttackPresentation(record, actor, mode, (source or "CarrierIsoZombie.applyHardDummyShellContract") .. ".scrub")
    applyDummyVoicePrefix(actor)
    applyDummyAudioMute(actor, source or "CarrierIsoZombie.applyHardDummyShellContract")
    applyPostureHumanization(record, actor, (source or "CarrierIsoZombie.applyHardDummyShellContract") .. ".posture", {
        neutralized = mode ~= "move",
    })

    if mode ~= "move" then
        forceDummyIdlePresentation(record, actor, (source or "CarrierIsoZombie.applyHardDummyShellContract") .. ".idle")
        protectedCall(actor, "setUseless", true)
        protectedCall(actor, "setCanWalk", false)
    else
        protectedCall(actor, "setUseless", false)
        protectedCall(actor, "setCanWalk", true)
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyHardShellMode = mode
        modData.LWN_DummyHardShellSource = source or "CarrierIsoZombie.applyHardDummyShellContract"
        modData.LWN_DummyAggroClearedAt = worldAgeHours()
        modData.LWN_DummyAggroClearPath = mode ~= "move"
        modData.LWN_DummyAggroTarget = protectedCall(actor, "getTarget") ~= nil
    end

    trace(mode == "move" and "dummy_contract_move_applied" or "dummy_contract_idle_applied", record, string.format(
        "lane=%s target=%s moving=%s path2=%s",
        tostring(lane),
        tostring(protectedCall(actor, "getTarget") ~= nil),
        tostring(protectedCall(actor, "isMoving") == true),
        tostring(protectedCall(actor, "getPath2") ~= nil)
    ))

    return applied
end

function Carrier.enforceHardDummyShell(record, actor, mode, source)
    return applyHardDummyShellContract(record, actor, mode, source or "CarrierIsoZombie.enforceHardDummyShell")
end

function Carrier.scrubDummyPresentation(record, actor, mode, source)
    if mode == "move" then
        scrubDummyAttackPresentation(record, actor, "move", source or "CarrierIsoZombie.scrubDummyPresentation")
    else
        forceDummyIdlePresentation(record, actor, source or "CarrierIsoZombie.scrubDummyPresentation")
    end
end

local function applyEmergencyQuarantine(record, actor, source)
    if not actor then return end
    local harness = record and record.debugHarness or nil
    if not (harness and harness.enabled == true and harness.quarantine == true) then
        return
    end

    applyShellLaneContract(record, actor, relationshipCombatPolicy(record), {
        source = source or "CarrierIsoZombie.applyEmergencyQuarantine",
        allowMovement = false,
        neutralized = true,
        clearCombat = true,
        stopAudio = false,
        forceLane = "debug_quarantine",
    })
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setLastTargettedBy", nil)
    protectedCall(actor, "setPath2", nil)
    protectedCall(actor, "setMoving", false)
    applyPostureHumanization(record, actor, source or "CarrierIsoZombie.applyEmergencyQuarantine", {
        neutralized = true,
    })
    stopZombieCodedAudio(actor)

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_NpcId = record and record.id or modData.LWN_NpcId
        modData.LWN_LastNpcId = record and record.id or modData.LWN_LastNpcId
        modData.LWN_TestHarnessQuarantine = true
        modData.LWN_TestHarnessQuarantineSource = source or "CarrierIsoZombie.applyEmergencyQuarantine"
        modData.LWN_AudioHumanization = modData.LWN_AudioHumanization or "emergency_quarantine_stopall"
        modData.LWN_AudioLeakHint = "spawn_quarantine_should_be_quiet"
    end
end

local function applyPersistentIllusionPackage(record, actor, descriptor, policy)
    if not actor then return end
    policy = policy or relationshipCombatPolicy(record)

    applyShellLaneContract(record, actor, policy, {
        source = "CarrierIsoZombie.applyPersistentIllusionPackage",
        allowMovement = policy.allowMovement == true,
        neutralized = policy.shouldNeutralizeCarrier == true and policy.allowMovement ~= true,
        clearCombat = policy.shouldNeutralizeCarrier == true,
        stopAudio = false,
        forceLane = policy.shellMode,
    })
    applyPostureHumanization(record, actor, "CarrierIsoZombie.applyPersistentIllusionPackage", {
        neutralized = policy.shouldNeutralizeCarrier == true and policy.allowMovement ~= true,
    })

    if descriptor then
        protectedCall(descriptor, "setVoicePrefix", "NotAZombie")
    end

    stopZombieCodedAudio(actor)

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_PersistentIllusionPackage = policy.shouldNeutralizeCarrier == true
            and "walk_human+no_lunge+voice_notazombie+targeted_audio_mute+hitreaction_guard+posture_idle_reset"
            or "walk_human+no_lunge+voice_notazombie+targeted_audio_mute+hitreaction_guard+posture_idle_reset"
        modData.LWN_AudioHumanization = "descriptor_voiceprefix+targeted_zombie_mute"
        modData.LWN_AnimationHumanization = "walktype=Walk+idle_anim_reset+clear_attack_vars"
    end
end

local function applyRelationshipCombatState(record, actor, options, policy)
    if not actor then return nil end
    policy = policy or relationshipCombatPolicy(record)
    local player = getPrimaryPlayer(options)
    local harness = record and record.debugHarness or nil
    local allowMovement = policy.allowMovement == true

    if harness and harness.enabled == true and harness.quarantine == true then
        applyEmergencyQuarantine(record, actor, "CarrierIsoZombie.applyRelationshipCombatState")
    end

    protectedCall(actor, "setGodMod", policy.allowPlayerAttack ~= true)
    applyShellLaneContract(record, actor, policy, {
        source = "CarrierIsoZombie.applyRelationshipCombatState",
        allowMovement = allowMovement,
        neutralized = policy.shouldNeutralizeCarrier == true and allowMovement ~= true,
        clearCombat = policy.shouldNeutralizeCarrier == true,
        stopAudio = policy.shouldNeutralizeCarrier == true,
        forceLane = policy.shellMode,
    })

    if policy.shouldNeutralizeCarrier == true then
        if allowMovement ~= true then
            clearRuntimeIntent(record, actor)
        end
        applyPostureHumanization(record, actor, "CarrierIsoZombie.applyRelationshipCombatState.neutralized", {
            neutralized = allowMovement ~= true,
        })
        if allowMovement ~= true then
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
        applyPostureHumanization(record, actor, "CarrierIsoZombie.applyRelationshipCombatState.active", {
            neutralized = false,
        })
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
        modData.LWN_MovementSuppression = policy.shouldNeutralizeCarrier == true
            and (policy.allowMovement == true
                and (policy.allowAutonomousMovement == true and "non_hostile_mobile+autonomous" or "non_hostile_mobile+command_only")
                or "clearqueue+cleartarget+clearpath+combat_block")
            or "hostile_pathing"
        modData.LWN_AudioLeakHint = policy.shouldNeutralizeCarrier == true and "should_be_quiet_non_hostile" or "hostile_vocal_leak_possible"
        modData.LWN_HostilityReason = policy.reason
        modData.LWN_ShellMode = policy.shellMode or carrierCombatMode(policy)
        modData.LWN_AllowMovement = policy.allowMovement == true
        modData.LWN_AllowAutonomousMovement = policy.allowAutonomousMovement == true
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
        modData.LWN_TestHarnessQuarantine = harness and harness.quarantine == true or false
        modData.LWN_TestHarnessAllowCommandMovement = harness and harness.allowCommandMovement ~= false or false
        modData.LWN_AttackQuarantineUntil = record.embodiment and record.embodiment.attackQuarantineUntilHour or nil
        modData.LWN_AttackQuarantineReason = record.embodiment and record.embodiment.lastAttackQuarantineReason or nil
        modData.LWN_TestHarnessIdentityLock = harness and harness.identityLock == true or false
        modData.LWN_TestHarnessSterileRadius = harness and harness.sterileRadius or nil
        modData.LWN_DummyEnabled = isMinimalDummyRecord(record)
        modData.LWN_DummyState = record and record.dummy and record.dummy.state or nil
        modData.LWN_DummyAppearanceLocked = record and record.dummy and record.dummy.appearanceLocked == true or false
        modData.LWN_DummyInitialAppearanceOk = record and record.dummy and record.dummy.initialAppearanceOk == true or false
        modData.LWN_DummyAppearanceFailed = record and record.dummy and record.dummy.appearanceFailed == true or false
        modData.LWN_DummyAppearanceRebuildPending = record and record.dummy and record.dummy.appearanceRebuildPending == true or false
        modData.LWN_DummyAppearanceFailureCount = record and record.dummy and record.dummy.appearanceFailureCount or 0
    end

    registerManagedShell(record, actor, "CarrierIsoZombie.applyBasicZombieCarrierFlags")

    stampHybridSummary(record, actor, summary, descriptor, appearanceDetail)
    applyPersistentIllusionPackage(record, actor, descriptor, policy)
    applyRelationshipCombatState(record, actor, options, policy)
    if isMinimalDummyRecord(record) then
        applyHardDummyShellContract(record, actor, record and record.dummy and record.dummy.state == "move_to" and "move" or "idle", "CarrierIsoZombie.applyBasicZombieCarrierFlags")
    end

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

local function noteDummyAppearanceState(record, actor, ok, source, detail)
    if not isMinimalDummyRecord(record) then return end
    record.dummy = record.dummy or {}
    record.dummy.initialAppearanceOk = ok == true
    if ok == true then
        record.dummy.appearanceLocked = true
        record.dummy.appearanceFailed = false
        record.dummy.appearanceRebuildPending = false
    else
        record.dummy.appearanceLocked = false
        record.dummy.appearanceFailed = true
        record.dummy.appearanceRebuildPending = true
        record.dummy.appearanceFailureCount = (tonumber(record.dummy.appearanceFailureCount) or 0) + 1
    end
    record.dummy.lastAppearanceProbeSource = source or "CarrierIsoZombie.noteDummyAppearanceState"
    record.dummy.lastAppearanceProbeDetail = detail
    record.dummy.lastAppearanceProbeAt = worldAgeHours()

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyAppearanceLocked = record.dummy.appearanceLocked == true
        modData.LWN_DummyInitialAppearanceOk = record.dummy.initialAppearanceOk == true
        modData.LWN_DummyAppearanceFailed = record.dummy.appearanceFailed == true
        modData.LWN_DummyAppearanceRebuildPending = record.dummy.appearanceRebuildPending == true
        modData.LWN_DummyAppearanceFailureCount = record.dummy.appearanceFailureCount or 0
        modData.LWN_DummyAppearanceProbeSource = source or "CarrierIsoZombie.noteDummyAppearanceState"
        modData.LWN_DummyAppearanceProbeDetail = detail
        modData.LWN_DummyAppearanceProbeAt = record.dummy.lastAppearanceProbeAt
    end
end

local function probeHumanizationState(record, actor, appearanceDetail, source)
    if not actor then
        return false, "actor=nil"
    end

    local modData = protectedCall(actor, "getModData")
    local humanInit = modData and modData.LWN_HumanizationInitialApplied == true or false
    local profile = modData and modData.LWN_HumanizationProfile or humanizationProfile(record)
    local itemVisuals = protectedCall(actor, "getItemVisuals")
    local itemVisualCount = itemVisuals and itemVisuals.size and itemVisuals:size() or 0
    local wornItems = protectedCall(actor, "getWornItems")
    local wornItemCount = wornItems and wornItems.size and wornItems:size() or 0
    local descriptor = protectedCall(actor, "getDescriptor")
    local humanVisual = protectedCall(actor, "getHumanVisual")
    local skin = humanVisual and protectedCall(humanVisual, "getSkinTexture") or modData and modData.LWN_HybridCurrentSkin or nil
    if skin ~= nil and tostring(skin) == "" then
        skin = nil
    end
    local presentation = LWN.ActorFactory and LWN.ActorFactory.getPresentationState and LWN.ActorFactory.getPresentationState(actor) or nil
    local role = presentation and presentation.presentationRole or (protectedCall(actor, "isZombie") == true and "reanimated_zombie" or "alive_npc")
    local hybridApplied = modData and modData.LWN_HybridAppearanceApplied == true or false
    local strictVisualOk = descriptor ~= nil
        and humanVisual ~= nil
        and skin ~= nil
        and (itemVisualCount > 0 or wornItemCount > 0)
        and hybridApplied == true

    local ok
    if isMinimalDummyRecord(record) then
        ok = strictVisualOk == true
    else
        ok = humanInit == true
            or (appearanceDetail and appearanceDetail.applied == true)
            or strictVisualOk == true
    end

    if modData then
        modData.LWN_HumanizationProbeOk = ok == true
        modData.LWN_HumanizationProbeSource = source or "CarrierIsoZombie.probeHumanizationState"
        modData.LWN_HumanizationProbeRole = role
        modData.LWN_HumanizationProbeSkin = skin
        modData.LWN_HumanizationProbeItemVisuals = itemVisualCount
        modData.LWN_HumanizationProbeWornItems = wornItemCount
        modData.LWN_HumanizationProbeHybridApplied = hybridApplied == true
        modData.LWN_HumanizationVisualTruthOk = strictVisualOk == true
    end

    local detail = string.format(
        "role=%s humanInit=%s skin=%s itemVisuals=%s wornItems=%s descriptor=%s humanVisual=%s hybridApplied=%s strictVisualOk=%s profile=%s",
        tostring(role),
        tostring(humanInit),
        tostring(skin),
        tostring(itemVisualCount),
        tostring(wornItemCount),
        tostring(descriptor ~= nil),
        tostring(humanVisual ~= nil),
        tostring(hybridApplied == true),
        tostring(strictVisualOk == true),
        tostring(profile)
    )

    noteDummyAppearanceState(record, actor, ok, source, detail)
    trace(ok and "spawn.humanization_probe" or "spawn.humanization_failed", record, detail)
    return ok, detail
end

local function buildInitialDummyAppearance(record, actor, source)
    if not (actor and isMinimalDummyRecord(record)) then
        return nil, nil, false, "not_minimal_dummy"
    end

    local profile = humanizationProfile(record)
    local descriptor = protectedCall(actor, "getDescriptor")
    local appearanceDetail = nil
    local initialDetail = nil
    local rebuildSource = source or "CarrierIsoZombie.buildInitialDummyAppearance"

    if LWN.ShellHumanizer and LWN.ShellHumanizer.applyInitial then
        descriptor, initialDetail = LWN.ShellHumanizer.applyInitial(record, actor, {
            source = rebuildSource .. ".initial",
            profile = profile,
            force = true,
        })
    end

    if LWN.ShellHumanizer and LWN.ShellHumanizer.maintain then
        descriptor, appearanceDetail = LWN.ShellHumanizer.maintain(record, actor, {
            source = rebuildSource .. ".reapply",
            profile = profile,
            forceFull = true,
            forceInitial = true,
        })
    else
        descriptor, appearanceDetail = applyAppearanceExperiment(record, actor, "dummy_initial_rebuild")
        appearanceDetail = normalizeAppearanceDetail(appearanceDetail, {
            stage = "dummy_initial_rebuild",
            status = appearanceDetail and appearanceDetail.applied == true and "applied" or "skipped",
            profile = profile,
            mode = "maintenance_full_reapply",
        })
    end

    if initialDetail and appearanceDetail and appearanceDetail.applied ~= true then
        appearanceDetail = initialDetail
    end

    applyBasicZombieCarrierFlags(record, actor, nil, descriptor, appearanceDetail)
    local ok, detail = probeHumanizationState(record, actor, appearanceDetail, rebuildSource .. ".probe")
    trace(ok and "dummy_appearance_locked" or "dummy_appearance_failed", record, string.format(
        "source=%s detail=%s",
        tostring(rebuildSource),
        tostring(detail)
    ))
    return descriptor, appearanceDetail, ok, detail
end

local function rebuildDummyAppearance(record, actor, source)
    return buildInitialDummyAppearance(record, actor, source or "CarrierIsoZombie.rebuildDummyAppearance")
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

function Carrier.enforceQuarantine(record, actor, source)
    applyEmergencyQuarantine(record, actor, source or "CarrierIsoZombie.enforceQuarantine")
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

    applyEmergencyQuarantine(record, actor, "CarrierIsoZombie.spawn")

    local runtimeOk, runtimeDetail = assessRuntimeReadiness(actor)
    local appearanceDetail = nil
    local appearanceEligible = false
    local appearanceGateDetail = nil
    local humanizationOk = false
    local humanizationDetail = nil

    if isMinimalDummyRecord(record) then
        _, appearanceDetail, humanizationOk, humanizationDetail = buildInitialDummyAppearance(record, actor, "CarrierIsoZombie.spawn.initial_dummy")
        appearanceEligible = humanizationOk == true
        appearanceGateDetail = humanizationDetail
    else
        local _descriptor
        _descriptor, appearanceDetail, appearanceEligible, appearanceGateDetail = runHumanizationPass(
            record,
            actor,
            options,
            "spawn",
            runtimeOk
        )
        humanizationOk, humanizationDetail = probeHumanizationState(record, actor, appearanceDetail, "CarrierIsoZombie.spawn")
        if humanizationOk ~= true then
            trace("spawn.humanization_retry", record, humanizationDetail)
            _descriptor, appearanceDetail, appearanceEligible, appearanceGateDetail = runHumanizationPass(
                record,
                actor,
                options,
                "spawn_retry",
                runtimeOk
            )
            humanizationOk, humanizationDetail = probeHumanizationState(record, actor, appearanceDetail, "CarrierIsoZombie.spawn.retry")
        end
    end
    local spawnedAt = worldAgeHours()
    trace(runtimeOk and "spawn.runtime_ready" or "spawn.pending_settle", record, string.format(
        "spawn=%s | humanization=%s mode=%s probe=%s | %s",
        tostring(spawnDetail),
        appearanceEligible == true and tostring(appearanceDetail and appearanceDetail.stage or "eligible") or tostring(appearanceGateDetail),
        tostring(appearanceDetail and appearanceDetail.mode or "nil"),
        tostring(humanizationDetail),
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
                humanizationProbeOk = humanizationOk == true,
                humanizationProbeDetail = humanizationDetail,
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
    applyEmergencyQuarantine(record, actor, "CarrierIsoZombie.sync")
    local runtimeOk, runtimeDetail = assessRuntimeReadiness(actor)
    local appearanceDetail = nil
    local appearanceEligible = false
    local appearanceGateDetail = nil
    local humanizationOk = false
    local humanizationDetail = nil
    if isMinimalDummyRecord(record) and record.dummy and (record.dummy.appearanceLocked ~= true or record.dummy.appearanceRebuildPending == true) then
        _, appearanceDetail, humanizationOk, humanizationDetail = rebuildDummyAppearance(record, actor, "CarrierIsoZombie.sync.rebuild")
        appearanceEligible = humanizationOk == true
        appearanceGateDetail = humanizationDetail
    else
        local _descriptor
        _descriptor, appearanceDetail, appearanceEligible, appearanceGateDetail = runHumanizationPass(
            record,
            actor,
            options,
            "sync",
            runtimeOk
        )
        humanizationOk, humanizationDetail = probeHumanizationState(record, actor, appearanceDetail, "CarrierIsoZombie.sync")
    end
    handle.runtime.appearanceEligible = appearanceEligible == true
    handle.runtime.appearanceEligibilityDetail = appearanceGateDetail
    handle.runtime.appearanceExperiment = appearanceDetail and appearanceDetail.experiment or nil
    handle.runtime.appearanceApplied = appearanceDetail and appearanceDetail.applied == true or false
    handle.runtime.appearanceStatus = appearanceDetail and appearanceDetail.status or nil
    handle.runtime.appearanceStage = appearanceDetail and appearanceDetail.stage or nil
    handle.runtime.humanizationMode = appearanceDetail and appearanceDetail.mode or nil
    handle.runtime.humanizationProfile = appearanceDetail and appearanceDetail.profile or humanizationProfile(record)
    handle.runtime.initialHumanizationApplied = record.embodiment and record.embodiment.illusion and record.embodiment.illusion.initialApplied == true or false
    handle.runtime.humanizationProbeOk = humanizationOk == true
    handle.runtime.humanizationProbeDetail = humanizationDetail
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
    local snapToAnchor = options and options.snapToAnchor == true
    if anchor and snapToAnchor then
        protectedCall(actor, "setX", tonumber(anchor.x) + 0.5)
        protectedCall(actor, "setY", tonumber(anchor.y) + 0.5)
        protectedCall(actor, "setZ", tonumber(anchor.z))
    end
    if record and record.stats and record.stats.health then
        protectedCall(actor, "setHealth", tonumber(record.stats.health) or 1)
    end
    if isMinimalDummyRecord(record) then
        applyHardDummyShellContract(record, actor, record and record.dummy and record.dummy.state == "move_to" and "move" or "idle", "CarrierIsoZombie.sync")
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
