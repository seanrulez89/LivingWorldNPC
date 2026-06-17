LWN = LWN or {}
LWN.Carriers = LWN.Carriers or {}

print("[LWN][Boot] file=35_LWN_Carrier_IsoZombie")

local Carrier = {}
LWN.Carriers.isozombie = Carrier

local Store = LWN.PopulationStore
Carrier.ManagedShellCache = Carrier.ManagedShellCache or {
    byNpcId = {},
    byActorRef = {},
}
Carrier.PendingHitRepairs = Carrier.PendingHitRepairs or {}

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
local ISOZOMBIE_ROLE_GUARD_RELAX_EXPERIMENT = true
local ISOZOMBIE_ALIVE_RESET_AFTER_RUNTIME_SETTLE = true
local ISOZOMBIE_SHELL_DIRECT_VISUAL_PROBE = false
local ISOZOMBIE_SHELL_FIRST_BUILD_LANE = false
local ISOZOMBIE_APPEARANCE_REPAIR_MAX_ATTEMPTS = 5
local ISOZOMBIE_APPEARANCE_REPAIR_INTERVAL_MS = 900
local MOVE_STALL_MS = 5000
local MOVE_ARRIVAL_DISTANCE = 0.75
local MOVE_MAX_ATTEMPTS = 3
local MOVE_PROGRESS_EPSILON = 0.05
local LWN_WALKTYPE_IDLE = "LWNWalk"
local LWN_WALKTYPE_FALLBACK = "1"
local FOLLOW_OFFSET = 0.85
local FOLLOW_ARRIVAL_DISTANCE = 0.55
local FOLLOW_RETARGET_DISTANCE = 0.70
local FOLLOW_RETARGET_MS = 300
local FOLLOW_HEADING_EPSILON = 0.08
local FOLLOW_CATCHUP_ENTER_DISTANCE = 3.0
local FOLLOW_CATCHUP_EXIT_DISTANCE = 1.8
local FOLLOW_HARD_CATCHUP_DISTANCE = 5.5
local FOLLOW_CATCHUP_OFFSET = 0.55
local ATTACK_RANGE = 1.25
local ATTACK_REPATH_DISTANCE = 0.8
local ATTACK_RETRY_MS = 650
local ATTACK_TIMEOUT_MS = 9000
local DEFAULT_WALK_SPEED = 1.04
local DEFAULT_RUN_SPEED = 0.72
local FOLLOW_FORMATION = {
    [1] = { back = 0.85, side = 0.00 },
    [2] = { back = 1.10, side = -0.55 },
    [3] = { back = 1.10, side = 0.55 },
}
local FOLLOW_LOCOMOTION = {
    walk = { key = "walk", walkType = "LWNWalk", fallbackWalkType = LWN_WALKTYPE_FALLBACK, endurance = 0, walkMultiplier = 1.0, runMultiplier = 1.0 },
    run = { key = "run", walkType = "LWNRun", fallbackWalkType = "sprint1", endurance = -0.03, walkMultiplier = 1.0, runMultiplier = 1.0 },
    sprint = { key = "sprint", walkType = "LWNSprint", fallbackWalkType = "sprint1", endurance = -0.06, walkMultiplier = 1.0, runMultiplier = 1.35 },
    crouch_walk = { key = "crouch_walk", walkType = "LWNCrouchWalk", fallbackWalkType = LWN_WALKTYPE_FALLBACK, endurance = -0.01, walkMultiplier = 1.0, runMultiplier = 1.0 },
    crouch_run = { key = "crouch_run", walkType = "LWNCrouchRun", fallbackWalkType = "sprint1", endurance = -0.03, walkMultiplier = 1.35, runMultiplier = 1.0 },
}

local function nowMs()
    if getTimestampMs then return getTimestampMs() end
    return math.floor((os and os.clock and os.clock() or 0) * 1000)
end

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
    local sampleOptions = nil
    if stage == "dummy_contract_idle_applied" then
        sampleOptions = {
            repeatCheckpoints = { 4 },
            repeatThreshold = 16,
            repeatInterval = 256,
        }
    elseif stage == "dummy_contract_move_applied" then
        sampleOptions = {
            repeatCheckpoints = { 4, 16 },
            repeatThreshold = 32,
            repeatInterval = 128,
        }
    end

    local sample = sampleDebugEvent(
        "carrier_isozombie_trace",
        table.concat({
            safeText(record and record.id or nil),
            safeText(stage),
        }, "|"),
        table.concat({
            safeText(stage),
            normalizeSampleValue(detail),
        }, "|"),
        sampleOptions
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

local function roleGuardSnapshot(actor)
    if not actor then
        return {
            bodyDamage = false,
            stats = false,
            inWorld = false,
            currentSquarePresent = false,
            squarePresent = false,
            anySquarePresent = false,
            isZombie = false,
            presentationRole = "actor_nil",
            alpha = nil,
            targetAlpha = nil,
            modelRegistered = nil,
            createHookPending = nil,
            lastCreateHook = nil,
        }
    end

    local currentSquare = protectedCall(actor, "getCurrentSquare")
    local square = protectedCall(actor, "getSquare")
    local presentation = LWN.ActorFactory and LWN.ActorFactory.getPresentationState and LWN.ActorFactory.getPresentationState(actor) or nil
    local modData = protectedCall(actor, "getModData")

    return {
        bodyDamage = protectedCall(actor, "getBodyDamage") ~= nil,
        stats = protectedCall(actor, "getStats") ~= nil,
        inWorld = protectedCall(actor, "isExistInTheWorld") == true,
        currentSquarePresent = currentSquare ~= nil,
        squarePresent = square ~= nil,
        anySquarePresent = currentSquare ~= nil or square ~= nil,
        isZombie = protectedCall(actor, "isZombie") == true,
        presentationRole = presentation and presentation.presentationRole or "unknown",
        alpha = presentation and presentation.alpha or protectedCall(actor, "getAlpha", 0),
        targetAlpha = presentation and presentation.targetAlpha or protectedCall(actor, "getTargetAlpha", 0),
        modelRegistered = presentation and presentation.modelRegistered or (modData and modData.LWN_ModelRegistered) or nil,
        createHookPending = modData and modData.LWN_CreateHookPending or nil,
        lastCreateHook = modData and modData.LWN_LastCreateHook or nil,
    }
end

local function roleGuardSummary(snapshot)
    snapshot = snapshot or {}
    return string.format(
        "bodyDamage=%s stats=%s inWorld=%s currentSquare=%s square=%s anySquare=%s isZombie=%s role=%s alpha=%s targetAlpha=%s modelRegistered=%s createHookPending=%s lastCreateHook=%s",
        tostring(snapshot.bodyDamage),
        tostring(snapshot.stats),
        tostring(snapshot.inWorld),
        tostring(snapshot.currentSquarePresent),
        tostring(snapshot.squarePresent),
        tostring(snapshot.anySquarePresent),
        tostring(snapshot.isZombie),
        tostring(snapshot.presentationRole),
        tostring(snapshot.alpha),
        tostring(snapshot.targetAlpha),
        tostring(snapshot.modelRegistered),
        tostring(snapshot.createHookPending),
        tostring(snapshot.lastCreateHook)
    )
end

local function stampRoleGuardSnapshot(actor, source)
    local modData = protectedCall(actor, "getModData")
    local snapshot = roleGuardSnapshot(actor)
    if modData then
        modData.LWN_RoleGuardSource = source
        modData.LWN_RoleGuardAt = worldAgeHours()
        modData.LWN_RoleGuardBodyDamage = snapshot.bodyDamage == true
        modData.LWN_RoleGuardStats = snapshot.stats == true
        modData.LWN_RoleGuardInWorld = snapshot.inWorld == true
        modData.LWN_RoleGuardCurrentSquare = snapshot.currentSquarePresent == true
        modData.LWN_RoleGuardSquare = snapshot.squarePresent == true
        modData.LWN_RoleGuardAnySquare = snapshot.anySquarePresent == true
        modData.LWN_RoleGuardIsZombie = snapshot.isZombie == true
        modData.LWN_RoleGuardPresentationRole = snapshot.presentationRole
        modData.LWN_RoleGuardAlpha = snapshot.alpha
        modData.LWN_RoleGuardTargetAlpha = snapshot.targetAlpha
        modData.LWN_RoleGuardModelRegistered = snapshot.modelRegistered
        modData.LWN_RoleGuardCreateHookPending = snapshot.createHookPending
        modData.LWN_RoleGuardLastCreateHook = snapshot.lastCreateHook
        modData.LWN_RoleGuardSummary = roleGuardSummary(snapshot)
    end
    return snapshot
end

local function assessAppearanceEligibility(actor)
    if not actor then
        return false, "appearance_ineligible actor=nil"
    end

    local snapshot = stampRoleGuardSnapshot(actor, "CarrierIsoZombie.assessAppearanceEligibility")

    if not snapshot.inWorld or not snapshot.anySquarePresent or not snapshot.isZombie then
        return false, string.format(
            "appearance_ineligible %s",
            roleGuardSummary(snapshot)
        )
    end

    return true, string.format(
        "appearance_eligible %s",
        roleGuardSummary(snapshot)
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
    protectedCall(actor, "clearAggroList")
    protectedCall(actor, "setVariable", "NoLungeTarget", true)
    protectedCall(actor, "setVariable", "NoLungeAttack", true)
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
    protectedCall(actor, "setWalkType", LWN_WALKTYPE_IDLE)
    protectedCall(actor, "setVariable", "LWNWalkType", LWN_WALKTYPE_IDLE)
    protectedCall(actor, "setNoTeeth", policy and policy.allowCarrierAttackPlayer ~= true)
    if options.clearEquipment == true then
        protectedCall(actor, "setPrimaryHandItem", nil)
        protectedCall(actor, "setSecondaryHandItem", nil)
        protectedCall(actor, "resetEquippedHandsModels")
        protectedCall(actor, "clearAttachedItems")
    end
    protectedCall(actor, "setUseless", neutralized == true)
    protectedCall(actor, "setCanWalk", allowMovement == true)
    protectedCall(actor, "setGodMod", false)
    protectedCall(actor, "setInvulnerable", false)
    if not (record and Carrier.PendingHitRepairs and Carrier.PendingHitRepairs[record.id]) then
        protectedCall(actor, "setAvoidDamage", false)
    end

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
        laneOptions.clearCombat = options.clearCombat ~= false
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

local function dummyScrubGraceHours()
    local hours = LWN.Config and LWN.Config.Embodiment and LWN.Config.Embodiment.GraceHours or 0.05
    hours = tonumber(hours) or 0.05
    if hours < 0 then
        return 0
    end
    return hours
end

local function markDummySpawnGrace(record, actor, source, reset)
    if not isMinimalDummyRecord(record) then return 0 end

    record.dummy = record.dummy or {}
    local dummy = record.dummy
    local now = worldAgeHours()
    local spawnedAt = tonumber(dummy.spawnedAt)
    if reset == true or spawnedAt == nil or spawnedAt <= 0 then
        spawnedAt = now
        dummy.spawnedAt = spawnedAt
    end

    local graceUntil = now + dummyScrubGraceHours()
    dummy.scrubGraceUntil = graceUntil
    dummy.scrubGraceMarkedAt = now
    dummy.scrubGraceSource = source or "CarrierIsoZombie.markDummySpawnGrace"

    local modData = actor and protectedCall(actor, "getModData") or nil
    if modData then
        modData.LWN_DummySpawnedAt = dummy.spawnedAt
        modData.LWN_DummyScrubGraceUntil = graceUntil
        modData.LWN_DummyScrubGraceSource = dummy.scrubGraceSource
    end

    return graceUntil
end

local function isDummyScrubGraceActive(record)
    if not isMinimalDummyRecord(record) then return false end
    local untilHour = tonumber(record and record.dummy and record.dummy.scrubGraceUntil or 0) or 0
    return untilHour > worldAgeHours()
end

local function hasDummyScrubResidue(actor)
    if not actor then return false end
    return protectedCall(actor, "isAttacking") == true
        or protectedCall(actor, "getTarget") ~= nil
        or protectedCall(actor, "getLastTargettedBy") ~= nil
end

local function scrubDummyAttackPresentation(record, actor, mode, source, options)
    if not actor then return false end

    options = options or {}
    mode = mode == "move" and "move" or "idle"
    source = source or "CarrierIsoZombie.scrubDummyAttackPresentation"

    local force = options.force == true
    local residuePresent = hasDummyScrubResidue(actor)
    if mode ~= "move" and force ~= true and isDummyScrubGraceActive(record) and residuePresent ~= true then
        trace("dummy_scrub_skipped_spawn_grace", record, string.format(
            "source=%s force=%s residue=%s until=%.5f",
            tostring(source),
            tostring(force),
            tostring(residuePresent),
            tonumber(record and record.dummy and record.dummy.scrubGraceUntil or 0) or 0
        ))
        return false
    end

    clearAllZombieAggro(actor, {
        stopActions = mode ~= "move",
        clearPath = mode ~= "move",
    })
    protectedCall(actor, "setWalkType", LWN_WALKTYPE_IDLE)
    protectedCall(actor, "setVariable", "LWNWalkType", LWN_WALKTYPE_IDLE)
    protectedCall(actor, "setVariable", "LWNManagedShell", true)

    if mode ~= "move" then
        protectedCall(actor, "setMoving", false)
        protectedCall(actor, "setPath2", nil)
        protectedCall(actor, "clearVariable", "bPathfind")
        protectedCall(actor, "setTarget", nil)
        protectedCall(actor, "setLastTargettedBy", nil)
        protectedCall(actor, "setDir", IsoDirections and IsoDirections.S or nil)
        protectedCall(actor, "setIdleAnimatorState")
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyPresentationScrubAt = worldAgeHours()
        modData.LWN_DummyPresentationScrubMode = mode
        modData.LWN_DummyPresentationScrubForce = force
        modData.LWN_DummyPresentationScrubSource = source
    end

    return true
end

local function forceDummyIdlePresentation(record, actor, source, options)
    if not actor then return false end

    options = options or {}
    source = source or "CarrierIsoZombie.forceDummyIdlePresentation"

    local scrubApplied = options.scrubApplied
    if scrubApplied == nil then
        scrubApplied = scrubDummyAttackPresentation(record, actor, "idle", source .. ".scrub", options)
    end
    if scrubApplied ~= true then
        return false
    end

    protectedCall(actor, "StopAllActionQueue")
    protectedCall(actor, "setMoving", false)
    protectedCall(actor, "setPath2", nil)
    protectedCall(actor, "clearVariable", "bPathfind")
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setLastTargettedBy", nil)
    protectedCall(actor, "setDir", IsoDirections and IsoDirections.S or nil)
    protectedCall(actor, "setWalkType", LWN_WALKTYPE_IDLE)
    protectedCall(actor, "setVariable", "LWNWalkType", LWN_WALKTYPE_IDLE)
    protectedCall(actor, "setIdleAnimatorState")

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyIdlePresentationForcedAt = worldAgeHours()
        modData.LWN_DummyIdlePresentationForcedSource = source
    end

    return true
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
            and "idle_anim_reset+walktype=LWNWalk+anti_hunch_neutralized"
            or "idle_anim_reset+walktype=LWNWalk+anti_hunch_active"
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
    local scrubApplied = scrubDummyAttackPresentation(record, actor, mode, (source or "CarrierIsoZombie.applyHardDummyShellContract") .. ".scrub")
    applyDummyVoicePrefix(actor)
    applyDummyAudioMute(actor, source or "CarrierIsoZombie.applyHardDummyShellContract")
    applyPostureHumanization(record, actor, (source or "CarrierIsoZombie.applyHardDummyShellContract") .. ".posture", {
        neutralized = mode ~= "move",
    })

    if mode ~= "move" then
        forceDummyIdlePresentation(record, actor, (source or "CarrierIsoZombie.applyHardDummyShellContract") .. ".idle", {
            scrubApplied = scrubApplied,
        })
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

function Carrier.scrubDummyPresentation(record, actor, mode, source, options)
    if mode == "move" then
        return scrubDummyAttackPresentation(record, actor, "move", source or "CarrierIsoZombie.scrubDummyPresentation", options)
    else
        return forceDummyIdlePresentation(record, actor, source or "CarrierIsoZombie.scrubDummyPresentation", options)
    end
end

function Carrier.isDummyScrubGraceActive(record)
    return isDummyScrubGraceActive(record)
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
    local engaged = record and record.combat and record.combat.state == "engaged"

    applyShellLaneContract(record, actor, policy, {
        source = "CarrierIsoZombie.applyPersistentIllusionPackage",
        allowMovement = policy.allowMovement == true,
        neutralized = policy.shouldNeutralizeCarrier == true and policy.allowMovement ~= true,
        clearCombat = policy.shouldNeutralizeCarrier == true and engaged ~= true,
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
        modData.LWN_AnimationHumanization = "walktype=LWNWalk+idle_anim_reset+clear_attack_vars"
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

    protectedCall(actor, "setGodMod", false)
    protectedCall(actor, "setInvulnerable", false)
    if not (record and Carrier.PendingHitRepairs and Carrier.PendingHitRepairs[record.id]) then
        protectedCall(actor, "setAvoidDamage", false)
    end
    applyShellLaneContract(record, actor, policy, {
        source = "CarrierIsoZombie.applyRelationshipCombatState",
        allowMovement = allowMovement,
        neutralized = policy.shouldNeutralizeCarrier == true and allowMovement ~= true,
        clearCombat = not (record and record.combat and record.combat.state == "engaged"),
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

local function applyShellFirstDummyCarrierState(record, actor, policy, source)
    if not actor then return nil end
    policy = policy or relationshipCombatPolicy(record)
    local mode = record and record.dummy and record.dummy.state == "move_to" and "move" or "idle"
    local lane = mode == "move" and "dummy_move" or "dummy_idle"

    applyShellLaneContract(record, actor, policy, {
        source = source or "CarrierIsoZombie.applyShellFirstDummyCarrierState",
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
    applyDummyVoicePrefix(actor)
    applyDummyAudioMute(actor, source or "CarrierIsoZombie.applyShellFirstDummyCarrierState")
    protectedCall(actor, "setGodMod", false)
    protectedCall(actor, "setInvulnerable", false)
    protectedCall(actor, "setAvoidDamage", false)
    protectedCall(actor, "setNoTeeth", true)
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setLastTargettedBy", nil)
    protectedCall(actor, "setAttackedBy", nil)
    protectedCall(actor, "setEatBodyTarget", nil, false)
    protectedCall(actor, "setSitAgainstWall", false)
    protectedCall(actor, "setOnFloor", false)
    protectedCall(actor, "setFallOnFront", false)
    protectedCall(actor, "setMoving", mode == "move")
    if mode ~= "move" then
        protectedCall(actor, "StopAllActionQueue")
        protectedCall(actor, "setPath2", nil)
        protectedCall(actor, "clearVariable", "bPathfind")
        protectedCall(actor, "setDir", IsoDirections and IsoDirections.S or nil)
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_ShellFirstBuildLane = true
        modData.LWN_ShellFirstBuildLaneSource = source or "CarrierIsoZombie.applyShellFirstDummyCarrierState"
        modData.LWN_ShellFirstBuildLaneMode = mode
        modData.LWN_ShellFirstBuildLaneFlags = "minimal_shell_lane+audio_mute+no_posture_refresh"
    end

    return lane
end

local function applyBasicZombieCarrierFlags(record, actor, options, descriptor, appearanceDetail)
    if not actor then return end
    options = options or {}
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
        modData.LWN_TestRoleGuardRelaxed = ISOZOMBIE_ROLE_GUARD_RELAX_EXPERIMENT == true
        modData.LWN_TestRoleGuardRelaxReason = ISOZOMBIE_ROLE_GUARD_RELAX_EXPERIMENT == true and "managed_isozombie_shell" or nil
    end

    registerManagedShell(record, actor, "CarrierIsoZombie.applyBasicZombieCarrierFlags")

    stampHybridSummary(record, actor, summary, descriptor, appearanceDetail)
    if options.shellFirstDummyMinFlags == true and isMinimalDummyRecord(record) then
        applyShellFirstDummyCarrierState(record, actor, policy, options.source or "CarrierIsoZombie.applyBasicZombieCarrierFlags.shell_first")
    else
        applyPersistentIllusionPackage(record, actor, descriptor, policy)
        applyRelationshipCombatState(record, actor, options, policy)
        if isMinimalDummyRecord(record) then
            applyHardDummyShellContract(record, actor, record and record.dummy and record.dummy.state == "move_to" and "move" or "idle", "CarrierIsoZombie.applyBasicZombieCarrierFlags")
        end
    end

    protectedCall(actor, "setFakeDead", false)
    protectedCall(actor, "setCrawler", false)
    protectedCall(actor, "setSitAgainstWall", false)
    protectedCall(actor, "setReanimate", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setHealth", record and record.stats and tonumber(record.stats.health) or protectedCall(actor, "getHealth") or 1)
end

local function assessRuntimeReadiness(actor)
    if not actor then
        return false, "actor=nil"
    end

    local snapshot = stampRoleGuardSnapshot(actor, "CarrierIsoZombie.assessRuntimeReadiness")

    if not snapshot.bodyDamage or not snapshot.inWorld or not snapshot.anySquarePresent or not snapshot.isZombie then
        return false, string.format(
            "runtime_core_missing %s",
            roleGuardSummary(snapshot)
        )
    end

    return true, string.format(
        "runtime_ready %s",
        roleGuardSummary(snapshot)
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

local function appearanceTruthScore(truth)
    if not truth then return 0 end
    local score = 0
    if truth.descriptorOk == true then score = score + 1 end
    if truth.humanVisualOk == true then score = score + 1 end
    if truth.skinOk == true then score = score + 1 end
    if truth.wornItemsOk == true or truth.itemVisualsOk == true then score = score + 1 end
    if truth.hybridAppliedOk == true then score = score + 1 end
    if truth.presentationRoleOk == true then score = score + 1 end
    if truth.guardBlocked == nil then score = score + 1 end
    if truth.ok == true then score = score + 1 end
    return score
end

local function stampAppearanceCadence(record, actor, source)
    if not actor then return nil end
    local modData = protectedCall(actor, "getModData")
    if not modData then return nil end
    local truth = LWN.ActorFactory and LWN.ActorFactory.getAppearanceTruthSnapshot and LWN.ActorFactory.getAppearanceTruthSnapshot(actor) or nil
    local presentation = LWN.ActorFactory and LWN.ActorFactory.getPresentationState and LWN.ActorFactory.getPresentationState(actor) or nil
    if not truth then return nil end

    local score = appearanceTruthScore(truth)
    local stage = tostring(source or "unknown")
    local signature = truth.signature or "nil"
    local role = presentation and presentation.presentationRole or truth.role or "unknown"
    local now = worldAgeHours()

    modData.LWN_AppearanceCadenceLastStage = stage
    modData.LWN_AppearanceCadenceLastAt = now
    modData.LWN_AppearanceCadenceLastScore = score
    modData.LWN_AppearanceCadenceLastSignature = signature
    modData.LWN_AppearanceCadenceLastRole = role
    modData.LWN_AppearanceCadenceLastFailCode = truth.failureCode or "none"
    modData.LWN_AppearanceCadenceLastGuardBlocked = truth.guardBlocked or "none"

    if modData.LWN_AppearanceCadenceFirstStage == nil then
        modData.LWN_AppearanceCadenceFirstStage = stage
        modData.LWN_AppearanceCadenceFirstAt = now
        modData.LWN_AppearanceCadenceFirstScore = score
        modData.LWN_AppearanceCadenceFirstSignature = signature
    end

    local bestScore = tonumber(modData.LWN_AppearanceCadenceBestScore)
    if bestScore == nil or score > bestScore then
        modData.LWN_AppearanceCadenceBestScore = score
        modData.LWN_AppearanceCadenceBestStage = stage
        modData.LWN_AppearanceCadenceBestAt = now
        modData.LWN_AppearanceCadenceBestSignature = signature
        modData.LWN_AppearanceCadenceBestRole = role
        modData.LWN_AppearanceCadenceBestFailCode = truth.failureCode or "none"
    end

    local bestSignature = modData.LWN_AppearanceCadenceBestSignature
    local currentBest = tonumber(modData.LWN_AppearanceCadenceBestScore) or score
    local overwriteDetected = false
    local overwriteReason = nil
    if bestSignature and bestSignature ~= "nil" then
        if signature ~= bestSignature and score < currentBest then
            overwriteDetected = true
            overwriteReason = "signature_drift_after_better_state"
        elseif score < currentBest then
            overwriteDetected = true
            overwriteReason = "score_drop_after_better_state"
        end
    end

    if overwriteDetected == true then
        modData.LWN_AppearanceCadenceOverwriteDetected = true
        modData.LWN_AppearanceCadenceOverwriteAt = now
        modData.LWN_AppearanceCadenceOverwriteStage = stage
        modData.LWN_AppearanceCadenceOverwriteReason = overwriteReason
        modData.LWN_AppearanceCadenceOverwriteFromSignature = bestSignature
        modData.LWN_AppearanceCadenceOverwriteToSignature = signature
        modData.LWN_AppearanceCadenceOverwriteToScore = score
    end

    print(string.format(
        "[LWN][OverwriteTracker] stage=%s npc=%s score=%s best=%s sig=%s bestSig=%s role=%s fail=%s guard=%s overwrite=%s overwriteReason=%s",
        tostring(stage),
        tostring(record and record.id or modData.LWN_NpcId or "nil"),
        tostring(score),
        tostring(modData.LWN_AppearanceCadenceBestScore or score),
        tostring(signature),
        tostring(bestSignature or signature),
        tostring(role),
        tostring(truth.failureCode or "none"),
        tostring(truth.guardBlocked or "none"),
        tostring(overwriteDetected),
        tostring(overwriteReason)
    ))

    return {
        score = score,
        stage = stage,
        signature = signature,
        role = role,
        overwriteDetected = overwriteDetected,
        overwriteReason = overwriteReason,
    }
end

local function probeHumanizationState(record, actor, appearanceDetail, source)
    if not actor then
        return false, "actor=nil"
    end

    local modData = protectedCall(actor, "getModData")
    local humanInit = modData and modData.LWN_HumanizationInitialApplied == true or false
    local profile = modData and modData.LWN_HumanizationProfile or humanizationProfile(record)
    local truth = LWN.ActorFactory and LWN.ActorFactory.getAppearanceTruthSnapshot and LWN.ActorFactory.getAppearanceTruthSnapshot(actor) or nil
    local roleGuard = stampRoleGuardSnapshot(actor, source or "CarrierIsoZombie.probeHumanizationState")

    local ok = false
    local role = truth and truth.role or (protectedCall(actor, "isZombie") == true and "reanimated_zombie" or "alive_npc")
    local skin = truth and truth.skin or (modData and modData.LWN_HybridCurrentSkin or nil)
    local itemVisualCount = truth and truth.itemVisualCount or 0
    local wornItemCount = truth and truth.wornItemCount or 0
    local hybridApplied = truth and truth.hybridAppliedOk == true or (modData and modData.LWN_HybridAppearanceApplied == true or false)
    local strictVisualOk = truth and truth.strictVisualOk == true or false
    local descriptorOk = truth and truth.descriptorOk == true or false
    local humanVisualOk = truth and truth.humanVisualOk == true or false
    local skinOk = truth and truth.skinOk == true or false
    local wornItemsOk = truth and truth.wornItemsOk == true or false
    local itemVisualsOk = truth and truth.itemVisualsOk == true or false
    local roleOk = truth and truth.presentationRoleOk == true or false
    local guardBlocked = truth and truth.guardBlocked or nil
    local overwrittenAfterRefresh = truth and truth.overwrittenAfterRefresh == true or false
    local failureCode = truth and truth.failureCode or nil

    if isMinimalDummyRecord(record) then
        ok = truth and truth.ok == true or false
    else
        ok = (truth and truth.ok == true) or strictVisualOk == true
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
        modData.LWN_HumanizationProbeDescriptorOk = descriptorOk == true
        modData.LWN_HumanizationProbeHumanVisualOk = humanVisualOk == true
        modData.LWN_HumanizationProbeSkinOk = skinOk == true
        modData.LWN_HumanizationProbeWornItemsOk = wornItemsOk == true
        modData.LWN_HumanizationProbeItemVisualsOk = itemVisualsOk == true
        modData.LWN_HumanizationProbeRoleOk = roleOk == true
        modData.LWN_HumanizationProbeGuardBlocked = guardBlocked
        modData.LWN_HumanizationProbeOverwrittenAfterRefresh = overwrittenAfterRefresh == true
        modData.LWN_HumanizationProbeFailureCode = failureCode
        modData.LWN_HumanizationProbeRoleGuardSummary = roleGuardSummary(roleGuard)
    end

    local detail = string.format(
        "role=%s humanInit=%s descOk=%s visualOk=%s skinOk=%s wornOk=%s itemVisualOk=%s hybridApplied=%s roleOk=%s guardBlocked=%s overwritten=%s strictVisualOk=%s fail=%s skin=%s itemVisuals=%s wornItems=%s profile=%s roleGuard={%s}",
        tostring(role),
        tostring(humanInit),
        tostring(descriptorOk),
        tostring(humanVisualOk),
        tostring(skinOk),
        tostring(wornItemsOk),
        tostring(itemVisualsOk),
        tostring(hybridApplied == true),
        tostring(roleOk),
        tostring(guardBlocked),
        tostring(overwrittenAfterRefresh),
        tostring(strictVisualOk == true),
        tostring(failureCode),
        tostring(skin),
        tostring(itemVisualCount),
        tostring(wornItemCount),
        tostring(profile),
        tostring(roleGuardSummary(roleGuard))
    )

    noteDummyAppearanceState(record, actor, ok, source, detail)
    stampAppearanceCadence(record, actor, source or "CarrierIsoZombie.probeHumanizationState")
    trace(ok and "spawn.humanization_probe" or "spawn.humanization_failed", record, detail)
    return ok, detail
end

local function clearShellObservationState(record, actor, reason)
    if not actor then
        return false
    end

    local modData = protectedCall(actor, "getModData")
    if not modData then
        return false
    end

    modData.LWN_ShellVisualProbeCheckpointStage = nil
    modData.LWN_ShellVisualProbeCheckpointSource = nil
    modData.LWN_ShellVisualProbeCheckpointDetail = nil
    modData.LWN_ShellVisualProbeCheckpointAt = nil
    modData.LWN_ShellVisualProbeCheckpointRole = nil
    modData.LWN_ShellVisualProbeCheckpointFail = nil
    modData.LWN_ShellVisualProbeCheckpointGuard = nil
    modData.LWN_ShellVisualProbeCheckpointSignature = nil
    modData.LWN_ShellVisualProbeCheckpointWorld = nil
    modData.LWN_ShellVisualProbeCheckpointSquare = nil
    modData.LWN_ShellVisualProbeCheckpointAlpha = nil
    modData.LWN_ShellVisualProbeCheckpointTargetAlpha = nil
    modData.LWN_ShellVisualProbeCheckpointModelRegistered = nil
    modData.LWN_ShellVisualProbePostFlagsStage = nil
    modData.LWN_ShellVisualProbePostFlagsRole = nil
    modData.LWN_ShellVisualProbePostFlagsFail = nil
    modData.LWN_ShellVisualProbePostFlagsGuard = nil
    modData.LWN_ShellVisualProbePostFlagsSignature = nil
    modData.LWN_ShellVisualProbePostFlagsWorld = nil
    modData.LWN_ShellVisualProbePostFlagsSquare = nil
    modData.LWN_ShellVisualProbePostFlagsAlpha = nil
    modData.LWN_ShellVisualProbePostFlagsTargetAlpha = nil
    modData.LWN_ShellVisualProbePostFlagsModelRegistered = nil
    modData.LWN_ShellVisualProbeApplied = nil
    modData.LWN_ShellVisualProbeDetail = nil
    modData.LWN_ShellVisualProbeStage = nil
    modData.LWN_ShellVisualProbeNetEffect = nil
    modData.LWN_ShellFirstBuildLane = nil
    modData.LWN_ShellFirstBuildLaneSource = nil
    modData.LWN_ShellFirstBuildLaneMode = nil
    modData.LWN_ShellFirstBuildLaneFlags = nil
    modData.LWN_ShellFirstBuildLaneStage = nil
    modData.LWN_ShellFirstBuildLaneProbeApplied = nil
    modData.LWN_ShellFirstBuildLaneProbeDetail = nil
    modData.LWN_ShellProbePathEnterCount = nil
    modData.LWN_ShellProbePathLastEnter = nil
    modData.LWN_ShellProbePathLastSource = nil
    modData.LWN_ShellProbePathLastDetail = nil
    modData.LWN_ShellProbePathLastAt = nil
    modData.LWN_ShellProbePathLastNpcId = nil
    modData.LWN_ShellProbePathLastActorRef = nil
    modData.LWN_ShellVisualFactoryStage = nil
    modData.LWN_ShellVisualFactorySource = nil
    modData.LWN_ShellVisualFactoryDetail = nil
    modData.LWN_ShellVisualFactoryAt = nil
    modData.LWN_ShellVisualFactoryCount = nil
    modData.LWN_ShellProbePathResetReason = tostring(reason or "unknown")
    modData.LWN_ShellProbePathResetAt = worldAgeHours()

    print(string.format(
        "[LWN][ShellProbePath] reset reason=%s | npcId=%s | objectRef=%s",
        tostring(reason or "unknown"),
        tostring(modData.LWN_NpcId or record and record.id or "nil"),
        tostring(actor)
    ))
    return true
end

local function logShellProbePathEntry(record, actor, entry, source, detail)
    if not actor then
        return false
    end

    local modData = protectedCall(actor, "getModData")
    local count = nil
    if modData then
        count = (tonumber(modData.LWN_ShellProbePathEnterCount) or 0) + 1
        modData.LWN_ShellProbePathEnterCount = count
        modData.LWN_ShellProbePathLastEnter = tostring(entry or "unknown")
        modData.LWN_ShellProbePathLastSource = tostring(source or "unknown")
        modData.LWN_ShellProbePathLastDetail = tostring(detail or "none")
        modData.LWN_ShellProbePathLastAt = worldAgeHours()
        modData.LWN_ShellProbePathLastNpcId = modData.LWN_NpcId or record and record.id or nil
        modData.LWN_ShellProbePathLastActorRef = tostring(actor)
    end

    print(string.format(
        "[LWN][ShellProbePath] enter=%s | source=%s | npcId=%s | objectRef=%s | count=%s | detail=%s",
        tostring(entry or "unknown"),
        tostring(source or "unknown"),
        tostring(modData and modData.LWN_NpcId or record and record.id or "nil"),
        tostring(actor),
        tostring(count or "nil"),
        tostring(detail or "none")
    ))
    return true
end

local function stampShellProbeCheckpoint(record, actor, stage, source)
    if not (actor and LWN.ActorFactory) then
        return nil
    end

    local truth = LWN.ActorFactory.getAppearanceTruthSnapshot and LWN.ActorFactory.getAppearanceTruthSnapshot(actor) or nil
    local presentation = LWN.ActorFactory.getPresentationState and LWN.ActorFactory.getPresentationState(actor) or nil
    local modData = protectedCall(actor, "getModData")
    local stageText = tostring(stage or "nil")
    local role = presentation and presentation.presentationRole or truth and truth.role or nil
    local fail = truth and truth.failureCode or nil
    local guard = truth and truth.guardBlocked or nil
    local signature = truth and truth.signature or nil
    local checkpointWorld = presentation and presentation.world or nil
    local checkpointSquare = presentation and presentation.squarePresent or nil
    local checkpointAlpha = presentation and presentation.alpha or nil
    local checkpointTargetAlpha = presentation and presentation.targetAlpha or nil
    local checkpointModelRegistered = presentation and presentation.modelRegistered or nil
    local checkpointNpcId = modData and modData.LWN_NpcId or record and record.id or nil
    local checkpointRef = tostring(actor)
    local isPostBuildCheckpoint = stageText == "after_basic_flags"
        or string.find(stageText, "after_min_flags", 1, true) ~= nil
        or string.find(stageText, "after_basic_flags", 1, true) ~= nil
    local detail = string.format(
        "stage=%s role=%s fail=%s guard=%s world=%s square=%s alpha=%s targetAlpha=%s modelRegistered=%s descOk=%s visualOk=%s skinOk=%s wornOk=%s itemVisualOk=%s overwritten=%s sig=%s",
        stageText,
        tostring(role or "nil"),
        tostring(fail or "none"),
        tostring(guard or "none"),
        tostring(checkpointWorld),
        tostring(checkpointSquare),
        tostring(checkpointAlpha),
        tostring(checkpointTargetAlpha),
        tostring(checkpointModelRegistered),
        tostring(truth and truth.descriptorOk == true),
        tostring(truth and truth.humanVisualOk == true),
        tostring(truth and truth.skinOk == true),
        tostring(truth and truth.wornItemsOk == true),
        tostring(truth and truth.itemVisualsOk == true),
        tostring(truth and truth.overwrittenAfterRefresh == true),
        tostring(signature or "nil")
    )

    if modData then
        modData.LWN_ShellVisualProbeCheckpointStage = stageText
        modData.LWN_ShellVisualProbeCheckpointSource = tostring(source or "CarrierIsoZombie.shell_probe_checkpoint")
        modData.LWN_ShellVisualProbeCheckpointDetail = detail
        modData.LWN_ShellVisualProbeCheckpointAt = worldAgeHours()
        modData.LWN_ShellVisualProbeCheckpointRole = role
        modData.LWN_ShellVisualProbeCheckpointFail = fail
        modData.LWN_ShellVisualProbeCheckpointGuard = guard
        modData.LWN_ShellVisualProbeCheckpointSignature = signature
        modData.LWN_ShellVisualProbeCheckpointWorld = checkpointWorld == true
        modData.LWN_ShellVisualProbeCheckpointSquare = checkpointSquare == true
        modData.LWN_ShellVisualProbeCheckpointAlpha = checkpointAlpha
        modData.LWN_ShellVisualProbeCheckpointTargetAlpha = checkpointTargetAlpha
        modData.LWN_ShellVisualProbeCheckpointModelRegistered = checkpointModelRegistered
        if isPostBuildCheckpoint then
            modData.LWN_ShellVisualProbePostFlagsStage = stageText
            modData.LWN_ShellVisualProbePostFlagsRole = role
            modData.LWN_ShellVisualProbePostFlagsFail = fail
            modData.LWN_ShellVisualProbePostFlagsGuard = guard
            modData.LWN_ShellVisualProbePostFlagsSignature = signature
            modData.LWN_ShellVisualProbePostFlagsWorld = checkpointWorld == true
            modData.LWN_ShellVisualProbePostFlagsSquare = checkpointSquare == true
            modData.LWN_ShellVisualProbePostFlagsAlpha = checkpointAlpha
            modData.LWN_ShellVisualProbePostFlagsTargetAlpha = checkpointTargetAlpha
            modData.LWN_ShellVisualProbePostFlagsModelRegistered = checkpointModelRegistered
        end
    end

    local checkpointLine = string.format(
        "[LWN][ShellProbeCheckpoint] stage=%s | source=%s | npcId=%s | objectRef=%s | role=%s | fail=%s | guard=%s | world=%s | square=%s | alpha=%s | targetAlpha=%s | modelRegistered=%s | descOk=%s | visualOk=%s | skinOk=%s | wornOk=%s | itemVisualOk=%s | overwritten=%s | sig=%s",
        tostring(stageText),
        tostring(source or "CarrierIsoZombie.shell_probe_checkpoint"),
        tostring(checkpointNpcId or "nil"),
        tostring(checkpointRef or "nil"),
        tostring(role or "nil"),
        tostring(fail or "none"),
        tostring(guard or "none"),
        tostring(checkpointWorld),
        tostring(checkpointSquare),
        tostring(checkpointAlpha),
        tostring(checkpointTargetAlpha),
        tostring(checkpointModelRegistered),
        tostring(truth and truth.descriptorOk == true),
        tostring(truth and truth.humanVisualOk == true),
        tostring(truth and truth.skinOk == true),
        tostring(truth and truth.wornItemsOk == true),
        tostring(truth and truth.itemVisualsOk == true),
        tostring(truth and truth.overwrittenAfterRefresh == true),
        tostring(signature or "nil")
    )

    print(checkpointLine)
    trace("shell_probe_" .. tostring(stageText), record, string.format(
        "source=%s %s",
        tostring(source or "CarrierIsoZombie.shell_probe_checkpoint"),
        tostring(detail)
    ))
    return truth, presentation, detail
end

local function runShellFirstBuild(record, actor, descriptor, profile, stageLabel, rebuildSource)
    local modData = protectedCall(actor, "getModData")
    local probeApplied = false
    local probeDetail = "shell_first_probe_unavailable"

    logShellProbePathEntry(record, actor, "runShellFirstBuild", rebuildSource, string.format("stage=%s descriptor=%s profile=%s", tostring(stageLabel), tostring(descriptor ~= nil), tostring(profile or "nil")))
    stampShellProbeCheckpoint(record, actor, stageLabel .. "_pre_direct_probe", rebuildSource .. ".shell_pre_direct_probe")

    if ISOZOMBIE_SHELL_DIRECT_VISUAL_PROBE == true
        and isMinimalDummyRecord(record)
        and LWN.ActorFactory
        and LWN.ActorFactory.applyManagedShellVisualProbe
    then
        probeApplied, probeDetail = LWN.ActorFactory.applyManagedShellVisualProbe(
            record,
            actor,
            descriptor,
            {
                source = rebuildSource .. ".shell_visual_probe",
            }
        )
        if modData then
            modData.LWN_ShellVisualProbeDetail = probeDetail
            modData.LWN_ShellVisualProbeStage = rebuildSource .. ".shell_visual_probe"
            modData.LWN_ShellFirstBuildLane = true
            modData.LWN_ShellFirstBuildLaneStage = stageLabel
            modData.LWN_ShellFirstBuildLaneProbeApplied = probeApplied == true
            modData.LWN_ShellFirstBuildLaneProbeDetail = probeDetail
        end
        stampShellProbeCheckpoint(record, actor, stageLabel .. "_post_direct_probe", rebuildSource .. ".shell_visual_probe")
        stampShellProbeCheckpoint(record, actor, stageLabel .. "_after_probe_refresh", rebuildSource .. ".shell_visual_probe")
    end

    local appearanceDetail = normalizeAppearanceDetail(nil, {
        applied = probeApplied == true,
        experiment = "isozombie_shell_stage1_visual_pass",
        reuse = "shell_stage1_direct_visual_pass",
        bridgeMode = modData and modData.LWN_ShellVisualProbeBridge or "none",
        descriptorMode = probeApplied == true and "shell_stage1_functional_pass" or "shell_stage1_skipped",
        descriptorSource = descriptor and "shell_stage1_seeded_descriptor" or "shell_stage1_descriptor_missing",
        stage = stageLabel,
        status = probeApplied == true and "applied" or "skipped",
        profile = profile,
        mode = "shell_first_build_lane",
    })

    return appearanceDetail, probeApplied == true, probeDetail
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
    local shellFirst = ISOZOMBIE_SHELL_FIRST_BUILD_LANE == true and isMinimalDummyRecord(record)

    clearShellObservationState(record, actor, rebuildSource .. ".begin")
    logShellProbePathEntry(record, actor, "buildInitialDummyAppearance", rebuildSource, string.format("shellFirst=%s descriptor=%s", tostring(shellFirst == true), tostring(descriptor ~= nil)))

    if LWN.ShellHumanizer and LWN.ShellHumanizer.applyInitial then
        descriptor, initialDetail = LWN.ShellHumanizer.applyInitial(record, actor, {
            source = rebuildSource .. ".initial",
            profile = profile,
            force = true,
        })
        if shellFirst == true then
            stampShellProbeCheckpoint(record, actor, "shell_first_after_apply_initial", rebuildSource .. ".initial")
        end
    end

    if shellFirst ~= true then
        logShellProbePathEntry(record, actor, "buildInitialDummyAppearance.standard", rebuildSource, "using_standard_dummy_rebuild")
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

        if ISOZOMBIE_SHELL_DIRECT_VISUAL_PROBE == true
            and isMinimalDummyRecord(record)
            and LWN.ActorFactory
            and LWN.ActorFactory.applyManagedShellVisualProbe
        then
            local _probeApplied, probeDetail = LWN.ActorFactory.applyManagedShellVisualProbe(
                record,
                actor,
                descriptor,
                {
                    source = rebuildSource .. ".shell_visual_probe",
                }
            )
            local modData = protectedCall(actor, "getModData")
            if modData then
                modData.LWN_ShellVisualProbeDetail = probeDetail
                modData.LWN_ShellVisualProbeStage = rebuildSource .. ".shell_visual_probe"
            end
            stampShellProbeCheckpoint(record, actor, "after_probe_refresh", rebuildSource .. ".shell_visual_probe")
        end
    else
        logShellProbePathEntry(record, actor, "buildInitialDummyAppearance.shell_first", rebuildSource, "enter_shell_first_branch")
        if descriptor == nil and LWN.ActorFactory and LWN.ActorFactory.buildDescriptor then
            descriptor, _ = LWN.ActorFactory.buildDescriptor(record)
        end
        appearanceDetail = select(1, runShellFirstBuild(record, actor, descriptor, profile, "shell_first_initial_build", rebuildSource))
    end

    if shellFirst == true then
        stampShellProbeCheckpoint(record, actor, "shell_first_before_min_flags", rebuildSource .. ".pre_min_flags")
    end
    applyBasicZombieCarrierFlags(record, actor, {
        shellFirstDummyMinFlags = shellFirst == true,
        source = rebuildSource .. ".post_build_flags",
    }, descriptor, appearanceDetail)
    stampShellProbeCheckpoint(record, actor, shellFirst == true and "shell_first_after_min_flags" or "after_basic_flags", rebuildSource .. ".post_basic_flags")
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

local function runPostRuntimeSettleRebuild(record, actor, source)
    if not actor then
        return nil, nil, false, "actor=nil"
    end

    local profile = humanizationProfile(record)
    local rebuildSource = source or "CarrierIsoZombie.runtimeSettleRebuild"
    local descriptor = protectedCall(actor, "getDescriptor")
    local appearanceDetail = nil
    local shellFirst = ISOZOMBIE_SHELL_FIRST_BUILD_LANE == true and isMinimalDummyRecord(record)

    clearShellObservationState(record, actor, rebuildSource .. ".begin")
    logShellProbePathEntry(record, actor, "runPostRuntimeSettleRebuild", rebuildSource, string.format("shellFirst=%s descriptor=%s", tostring(shellFirst == true), tostring(descriptor ~= nil)))

    if shellFirst ~= true then
        logShellProbePathEntry(record, actor, "runPostRuntimeSettleRebuild.standard", rebuildSource, "using_standard_post_settle_rebuild")
        if LWN.ShellHumanizer and LWN.ShellHumanizer.maintain then
            descriptor, appearanceDetail = LWN.ShellHumanizer.maintain(record, actor, {
                source = rebuildSource,
                profile = profile,
                forceFull = true,
                forceInitial = true,
            })
        else
            descriptor, appearanceDetail = applyAppearanceExperiment(record, actor, "runtime_settle_rebuild")
            appearanceDetail = normalizeAppearanceDetail(appearanceDetail, {
                stage = "runtime_settle_rebuild",
                status = appearanceDetail and appearanceDetail.applied == true and "applied" or "skipped",
                profile = profile,
                mode = "post_settle_full_reapply",
            })
        end

        if ISOZOMBIE_SHELL_DIRECT_VISUAL_PROBE == true
            and isMinimalDummyRecord(record)
            and LWN.ActorFactory
            and LWN.ActorFactory.applyManagedShellVisualProbe
        then
            local _probeApplied, probeDetail = LWN.ActorFactory.applyManagedShellVisualProbe(
                record,
                actor,
                descriptor,
                {
                    source = rebuildSource .. ".shell_visual_probe",
                }
            )
            local modData = protectedCall(actor, "getModData")
            if modData then
                modData.LWN_ShellVisualProbeDetail = probeDetail
                modData.LWN_ShellVisualProbeStage = rebuildSource .. ".shell_visual_probe"
            end
            stampShellProbeCheckpoint(record, actor, "post_runtime_settle_after_probe", rebuildSource .. ".shell_visual_probe")
        end
    else
        logShellProbePathEntry(record, actor, "runPostRuntimeSettleRebuild.shell_first", rebuildSource, "enter_shell_first_post_settle_branch")
        if descriptor == nil and LWN.ShellHumanizer and LWN.ShellHumanizer.applyInitial then
            descriptor, _ = LWN.ShellHumanizer.applyInitial(record, actor, {
                source = rebuildSource .. ".initial_seed",
                profile = profile,
                force = true,
            })
            stampShellProbeCheckpoint(record, actor, "shell_first_post_runtime_settle_after_apply_initial", rebuildSource .. ".initial_seed")
        end
        if descriptor == nil and LWN.ActorFactory and LWN.ActorFactory.buildDescriptor then
            descriptor, _ = LWN.ActorFactory.buildDescriptor(record)
        end
        appearanceDetail = select(1, runShellFirstBuild(record, actor, descriptor, profile, "shell_first_post_runtime_settle_build", rebuildSource))
    end

    if shellFirst == true then
        stampShellProbeCheckpoint(record, actor, "shell_first_post_runtime_settle_before_min_flags", rebuildSource .. ".pre_min_flags")
    end
    applyBasicZombieCarrierFlags(record, actor, {
        shellFirstDummyMinFlags = shellFirst == true,
        source = rebuildSource .. ".post_build_flags",
    }, descriptor, appearanceDetail)
    stampShellProbeCheckpoint(record, actor, shellFirst == true and "shell_first_post_runtime_settle_after_min_flags" or "post_runtime_settle_after_basic_flags", rebuildSource .. ".post_basic_flags")
    local ok, detail = probeHumanizationState(record, actor, appearanceDetail, rebuildSource .. ".probe")

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_RuntimeSettleRebuildAttempted = true
        modData.LWN_RuntimeSettleRebuildAt = worldAgeHours()
        modData.LWN_RuntimeSettleRebuildSource = rebuildSource
        modData.LWN_RuntimeSettleRebuildOk = ok == true
        modData.LWN_RuntimeSettleRebuildDetail = detail
        modData.LWN_RuntimeSettleRebuildMode = appearanceDetail and appearanceDetail.mode or "post_settle_full_reapply"
        modData.LWN_RuntimeSettleRebuildStage = appearanceDetail and appearanceDetail.stage or "runtime_settle_rebuild"
    end

    trace(ok and "runtime_settle_rebuild.ok" or "runtime_settle_rebuild.failed", record, string.format(
        "source=%s mode=%s stage=%s detail=%s",
        tostring(rebuildSource),
        tostring(appearanceDetail and appearanceDetail.mode or "nil"),
        tostring(appearanceDetail and appearanceDetail.stage or "nil"),
        tostring(detail)
    ))

    return descriptor, appearanceDetail, ok, detail
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
        modData.LWN_LastNpcId = record and record.id or modData.LWN_LastNpcId
        modData.LWN_NpcId = nil
        modData.LWN_ShellMarker = modData.LWN_ShellMarker or string.format("isozombie:%s", tostring(record and record.id or modData.LWN_LastNpcId or "unknown"))
        modData.LWN_ManagedShellContract = true
        modData.LWN_TestHarnessLabel = record and record.debugHarness and record.debugHarness.label or modData.LWN_TestHarnessLabel
        modData.LWN_TestHarnessEnabled = record and record.debugHarness and record.debugHarness.enabled == true or modData.LWN_TestHarnessEnabled
        modData.LWN_TestHarnessQuarantine = record and record.debugHarness and record.debugHarness.quarantine == true or modData.LWN_TestHarnessQuarantine
        modData.LWN_ReturnRecoveryCandidate = true
        modData.LWN_ReturnRecoveryReason = tostring(reason or "unknown")
        modData.LWN_ReturnRecoveryAt = worldAgeHours()
    end

    protectedCall(actor, "StopAllActionQueue")
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setLastTargettedBy", nil)
    protectedCall(actor, "setAttackedBy", nil)
    protectedCall(actor, "setEatBodyTarget", nil, false)
    protectedCall(actor, "setPath2", nil)
    protectedCall(actor, "setMoving", false)
    protectedCall(actor, "setUseless", true)
    protectedCall(actor, "setCanWalk", false)
    protectedCall(actor, "setNoTeeth", true)
    protectedCall(actor, "setInvisible", true)
    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")
    markNoAutoRearm(record)

    trace("retire.shallow", record, string.format(
        "reason=%s world=%s squarePresent=%s lastNpcId=%s shellMarker=%s returnRecovery=%s",
        tostring(reason),
        tostring(protectedCall(actor, "isExistInTheWorld")),
        tostring((protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")) ~= nil),
        tostring(modData and modData.LWN_LastNpcId or nil),
        tostring(modData and modData.LWN_ShellMarker or nil),
        tostring(modData and modData.LWN_ReturnRecoveryCandidate or nil)
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
        logShellProbePathEntry(record, actor, "Carrier.spawn.initial_dummy_callsite", "CarrierIsoZombie.spawn", "before_buildInitialDummyAppearance")
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
    if isMinimalDummyRecord(record) then
        markDummySpawnGrace(record, actor, "CarrierIsoZombie.spawn", true)
    end
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
    local wasSettlePending = handle.runtime.settlePending == true
    if isMinimalDummyRecord(record) and (not record.dummy or not record.dummy.scrubGraceUntil) then
        markDummySpawnGrace(record, actor, "CarrierIsoZombie.sync.bootstrap", false)
    end
    applyEmergencyQuarantine(record, actor, "CarrierIsoZombie.sync")
    local runtimeOk, runtimeDetail = assessRuntimeReadiness(actor)
    local appearanceDetail = nil
    local appearanceEligible = false
    local appearanceGateDetail = nil
    local humanizationOk = false
    local humanizationDetail = nil
    if isMinimalDummyRecord(record) and record.dummy and (record.dummy.appearanceLocked ~= true or record.dummy.appearanceRebuildPending == true) then
        logShellProbePathEntry(record, actor, "Carrier.sync.rebuild_callsite", "CarrierIsoZombie.sync", string.format("appearanceLocked=%s rebuildPending=%s", tostring(record.dummy and record.dummy.appearanceLocked == true), tostring(record.dummy and record.dummy.appearanceRebuildPending == true)))
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

    if wasSettlePending == true and handle.runtime.runtimeSettleRebuildDone ~= true then
        local _settleDescriptor
        logShellProbePathEntry(record, actor, "Carrier.sync.post_runtime_settle_callsite", "CarrierIsoZombie.sync", string.format("wasSettlePending=%s runtimeSettleRebuildDone=%s", tostring(wasSettlePending == true), tostring(handle.runtime.runtimeSettleRebuildDone == true)))
        _settleDescriptor, appearanceDetail, humanizationOk, humanizationDetail = runPostRuntimeSettleRebuild(
            record,
            actor,
            "CarrierIsoZombie.sync.post_runtime_settle"
        )
        appearanceEligible = humanizationOk == true
        appearanceGateDetail = humanizationDetail
        handle.runtime.appearanceEligible = appearanceEligible == true
        handle.runtime.appearanceEligibilityDetail = appearanceGateDetail
        handle.runtime.appearanceExperiment = appearanceDetail and appearanceDetail.experiment or handle.runtime.appearanceExperiment
        handle.runtime.appearanceApplied = appearanceDetail and appearanceDetail.applied == true or false
        handle.runtime.appearanceStatus = appearanceDetail and appearanceDetail.status or nil
        handle.runtime.appearanceStage = appearanceDetail and appearanceDetail.stage or nil
        handle.runtime.humanizationMode = appearanceDetail and appearanceDetail.mode or nil
        handle.runtime.humanizationProfile = appearanceDetail and appearanceDetail.profile or humanizationProfile(record)
        handle.runtime.humanizationProbeOk = humanizationOk == true
        handle.runtime.humanizationProbeDetail = humanizationDetail
        handle.runtime.runtimeSettleRebuildDone = true
        handle.runtime.runtimeSettleRebuildAt = worldAgeHours()

        if ISOZOMBIE_ALIVE_RESET_AFTER_RUNTIME_SETTLE == true
            and isMinimalDummyRecord(record)
            and LWN.ActorFactory
            and LWN.ActorFactory.rebuildAliveAnimationState
        then
            local resetTouched = LWN.ActorFactory.rebuildAliveAnimationState(
                actor,
                "CarrierIsoZombie.sync.runtime_settle_alive_reset"
            )
            handle.runtime.runtimeSettleAliveResetDone = true
            handle.runtime.runtimeSettleAliveResetTouched = resetTouched == true
            handle.runtime.runtimeSettleAliveResetAt = worldAgeHours()
            local modData = protectedCall(actor, "getModData")
            if modData then
                modData.LWN_RuntimeSettleAliveResetDone = true
                modData.LWN_RuntimeSettleAliveResetTouched = resetTouched == true
                modData.LWN_RuntimeSettleAliveResetAt = worldAgeHours()
                modData.LWN_RuntimeSettleAliveResetReason = "CarrierIsoZombie.sync.runtime_settle_alive_reset"
            end
            trace("runtime_settle_alive_reset", record, string.format(
                "touched=%s humanization=%s detail=%s",
                tostring(resetTouched == true),
                tostring(humanizationOk == true),
                tostring(humanizationDetail)
            ))
            stampAppearanceCadence(record, actor, "CarrierIsoZombie.sync.runtime_settle_alive_reset")
        end
    end

    if humanizationOk ~= true then
        local repairAttempts = tonumber(handle.runtime.appearanceRepairAttempts) or 0
        local repairLastAtMs = tonumber(handle.runtime.appearanceRepairLastAtMs) or 0
        local now = nowMs()
        if repairAttempts < ISOZOMBIE_APPEARANCE_REPAIR_MAX_ATTEMPTS
            and repairLastAtMs + ISOZOMBIE_APPEARANCE_REPAIR_INTERVAL_MS <= now
        then
            repairAttempts = repairAttempts + 1
            handle.runtime.appearanceRepairAttempts = repairAttempts
            handle.runtime.appearanceRepairLastAtMs = now
            trace("sync.appearance_repair_retry", record, string.format(
                "attempt=%s/%s previous=%s",
                tostring(repairAttempts),
                tostring(ISOZOMBIE_APPEARANCE_REPAIR_MAX_ATTEMPTS),
                tostring(humanizationDetail)
            ))

            local _repairDescriptor
            _repairDescriptor, appearanceDetail, humanizationOk, humanizationDetail = runPostRuntimeSettleRebuild(
                record,
                actor,
                "CarrierIsoZombie.sync.appearance_repair"
            )
            appearanceEligible = humanizationOk == true
            appearanceGateDetail = humanizationDetail
            handle.runtime.appearanceEligible = appearanceEligible == true
            handle.runtime.appearanceEligibilityDetail = appearanceGateDetail
            handle.runtime.appearanceExperiment = appearanceDetail and appearanceDetail.experiment or handle.runtime.appearanceExperiment
            handle.runtime.appearanceApplied = appearanceDetail and appearanceDetail.applied == true or false
            handle.runtime.appearanceStatus = appearanceDetail and appearanceDetail.status or nil
            handle.runtime.appearanceStage = appearanceDetail and appearanceDetail.stage or nil
            handle.runtime.humanizationMode = appearanceDetail and appearanceDetail.mode or nil
            handle.runtime.humanizationProfile = appearanceDetail and appearanceDetail.profile or humanizationProfile(record)
            handle.runtime.humanizationProbeOk = humanizationOk == true
            handle.runtime.humanizationProbeDetail = humanizationDetail
            handle.runtime.appearanceRepairOk = humanizationOk == true
        end
    else
        handle.runtime.appearanceRepairOk = true
        handle.runtime.appearanceRepairAttempts = 0
        handle.runtime.appearanceRepairLastAtMs = 0
    end

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

local function movementBaseSpeeds(actor)
    local modData = protectedCall(actor, "getModData")
    if not modData then return DEFAULT_WALK_SPEED, DEFAULT_RUN_SPEED end
    if tonumber(modData.LWN_BaseWalkSpeed) == nil then
        modData.LWN_BaseWalkSpeed = tonumber(protectedCall(actor, "getVariableFloat", "WalkSpeed", DEFAULT_WALK_SPEED))
            or DEFAULT_WALK_SPEED
    end
    if tonumber(modData.LWN_BaseRunSpeed) == nil then
        modData.LWN_BaseRunSpeed = tonumber(protectedCall(actor, "getVariableFloat", "RunSpeed", DEFAULT_RUN_SPEED))
            or DEFAULT_RUN_SPEED
    end
    return tonumber(modData.LWN_BaseWalkSpeed) or DEFAULT_WALK_SPEED,
        tonumber(modData.LWN_BaseRunSpeed) or DEFAULT_RUN_SPEED
end

local function applyMovementProfile(actor, profile)
    if not actor or not profile then return end
    local baseWalkSpeed, baseRunSpeed = movementBaseSpeeds(actor)
    local modData = protectedCall(actor, "getModData")
    local walkType = profile.walkType or LWN_WALKTYPE_IDLE
    if modData and modData.LWN_UseVanillaWalkType == true and profile.fallbackWalkType then
        walkType = profile.fallbackWalkType
    end
    protectedCall(actor, "setVariable", "WalkSpeed", baseWalkSpeed * (profile.walkMultiplier or 1))
    protectedCall(actor, "setVariable", "RunSpeed", baseRunSpeed * (profile.runMultiplier or 1))
    protectedCall(actor, "setVariable", "LWNLocomotion", profile.key or walkType)
    protectedCall(actor, "setVariable", "LWNWalkType", walkType)
    protectedCall(actor, "setWalkType", walkType)
    protectedCall(actor, "setCanWalk", true)
    protectedCall(actor, "setUseless", false)
end

local function markMovementAnimFallback(record, actor, reason)
    local modData = protectedCall(actor, "getModData")
    if modData and modData.LWN_UseVanillaWalkType ~= true then
        modData.LWN_UseVanillaWalkType = true
        modData.LWN_UseVanillaWalkTypeReason = reason or "movement_no_progress"
        modData.LWN_UseVanillaWalkTypeAt = worldAgeHours()
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Movement", "animset_fallback", {
                npcId = record and record.id,
                source = "isozombie",
                status = "fallback",
                reason = modData.LWN_UseVanillaWalkTypeReason,
                detail = "custom_lwn_walktype_no_progress",
            })
        end
    end
end

local function movementBumpForProfile(profile)
    local walkType = profile and profile.walkType or LWN_WALKTYPE_IDLE
    if walkType == "LWNRun" or walkType == "LWNSprint" or walkType == "LWNCrouchRun" then
        return "IdleToRun"
    end
    if walkType == "LWNWalk" or walkType == "LWNCrouchWalk" or walkType == LWN_WALKTYPE_FALLBACK then
        return "IdleToWalk"
    end
    return nil
end

local function stopActorMotion(actor, options)
    options = options or {}
    if not actor then return end
    local pf = protectedCall(actor, "getPathFindBehavior2")
    protectedCall(pf, "cancel")
    protectedCall(pf, "reset")
    protectedCall(actor, "setPath2", nil)
    protectedCall(actor, "setMoving", false)
    if options.clearTarget == true then
        protectedCall(actor, "setTarget", nil)
        protectedCall(actor, "setLastTargettedBy", nil)
    end
    if options.stopActions == true then
        protectedCall(actor, "StopAllActionQueue")
    end
end

local function startPathTo(actor, x, y, z, profile)
    if not actor or x == nil or y == nil or z == nil then return false, "invalid_path_target" end
    protectedCall(actor, "setCanWalk", true)
    protectedCall(actor, "setUseless", false)
    protectedCall(actor, "setTarget", nil)
    protectedCall(actor, "setTargetSeenTime", 0)
    protectedCall(actor, "setLastTargettedBy", nil)
    protectedCall(actor, "setAttackedBy", nil)
    protectedCall(actor, "clearAggroList")
    protectedCall(actor, "faceLocation", x, y)
    local bump = movementBumpForProfile(profile)
    if bump then
        protectedCall(actor, "setBumpType", bump)
    end
    local pf = protectedCall(actor, "getPathFindBehavior2")
    if pf and (pf.pathToLocationF or pf.pathToLocation) then
        protectedCall(pf, "cancel")
        protectedCall(pf, "reset")
        protectedCall(actor, "setPath2", nil)
        local ok = false
        local method = "pf:pathToLocation"
        if pf.pathToLocationF then
            method = "pf:pathToLocationF"
            ok = pcall(pf.pathToLocationF, pf, x, y, z)
        else
            ok = pcall(pf.pathToLocation, pf, x, y, z)
        end
        if ok then
            protectedCall(actor, "setMoving", true)
            if pf.update then
                pcall(pf.update, pf)
            end
            return true, method
        end
    end
    if actor.pathToLocationF then
        local ok = pcall(actor.pathToLocationF, actor, x, y, z)
        if ok then
            protectedCall(actor, "setMoving", true)
            return true, "actor:pathToLocationF"
        end
    end
    if actor.pathToLocation then
        local ok = pcall(actor.pathToLocation, actor, x, y, z)
        if ok then
            protectedCall(actor, "setMoving", true)
            return true, "actor:pathToLocation"
        end
    end
    return false, "path_start_unavailable"
end

local function behaviorResultName(result)
    if result == nil then return "Working" end
    if BehaviorResult then
        if result == BehaviorResult.Failed then return "Failed" end
        if result == BehaviorResult.Succeeded then return "Succeeded" end
    end
    return tostring(result)
end

local function tickPathfinder(actor)
    local pf = protectedCall(actor, "getPathFindBehavior2")
    if not pf then return "Missing" end
    if not pf.update then return "MissingUpdate" end
    local ok, result = pcall(pf.update, pf)
    if ok then return behaviorResultName(result) end
    return "Error"
end

local function distanceTo(actor, x, y)
    local ax = tonumber(protectedCall(actor, "getX") or x) or x
    local ay = tonumber(protectedCall(actor, "getY") or y) or y
    local dx, dy = ax - x, ay - y
    return math.sqrt(dx * dx + dy * dy), ax, ay
end

local function isOrdinaryZombieActor(actor)
    if not actor or not instanceof or not instanceof(actor, "IsoZombie") then return false end
    if protectedCall(actor, "isDead") == true then return false end
    if protectedCall(actor, "isAlive") == false then return false end
    if (tonumber(protectedCall(actor, "getHealth")) or 1) <= 0 then return false end
    local modData = protectedCall(actor, "getModData")
    return not (modData and (modData.LWN_NpcId ~= nil or modData.LWN_LastNpcId ~= nil or modData.LWN_ManagedShellContract == true))
end

local function resolveAttackTarget(actor, intent)
    local data = intent and intent.data or {}
    if isOrdinaryZombieActor(data.target) then return data.target end
    local cell = getCell and getCell() or nil
    if not cell then return nil end
    local tx = math.floor(tonumber(data.targetX or protectedCall(actor, "getX") or 0) or 0)
    local ty = math.floor(tonumber(data.targetY or protectedCall(actor, "getY") or 0) or 0)
    local tz = math.floor(tonumber(data.targetZ or protectedCall(actor, "getZ") or 0) or 0)
    local best, bestD = nil, math.huge
    for y = ty - 1, ty + 1 do
        for x = tx - 1, tx + 1 do
            local square = cell:getGridSquare(x, y, tz)
            local objects = square and protectedCall(square, "getMovingObjects") or nil
            if objects and objects.size and objects.get then
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if isOrdinaryZombieActor(obj) then
                        local d = distanceTo(actor, tonumber(protectedCall(obj, "getX") or x) or x, tonumber(protectedCall(obj, "getY") or y) or y)
                        if d < bestD then
                            best, bestD = obj, d
                        end
                    end
                end
            end
        end
    end
    data.target = best
    intent.data = data
    return best
end

local function updateFollowHeading(player, follow, px, py)
    local dx = follow.lastPlayerX and (px - follow.lastPlayerX) or 0
    local dy = follow.lastPlayerY and (py - follow.lastPlayerY) or 0
    local distance = math.sqrt(dx * dx + dy * dy)
    if follow.lastPlayerX == nil or follow.lastPlayerY == nil then
        follow.lastPlayerX = px
        follow.lastPlayerY = py
    end
    if distance >= FOLLOW_HEADING_EPSILON then
        follow.headingX = dx / distance
        follow.headingY = dy / distance
        follow.headingSource = "player_motion"
        follow.lastPlayerX = px
        follow.lastPlayerY = py
    elseif follow.headingX == nil or follow.headingY == nil then
        local direction = protectedCall(player, "getForwardDirection")
        local fx = tonumber(protectedCall(direction, "getX") or 0) or 0
        local fy = tonumber(protectedCall(direction, "getY") or 0) or 0
        local length = math.sqrt(fx * fx + fy * fy)
        if length > 0.001 then
            follow.headingX = fx / length
            follow.headingY = fy / length
            follow.headingSource = "initial_facing"
        else
            follow.headingX = 0
            follow.headingY = 1
            follow.headingSource = "fallback_north"
        end
    end
    return follow.headingX, follow.headingY
end

local function updateFollowMode(follow, playerDistance)
    local catchup = follow.catchup == true
    if catchup then
        catchup = playerDistance > FOLLOW_CATCHUP_EXIT_DISTANCE
    else
        catchup = playerDistance >= FOLLOW_CATCHUP_ENTER_DISTANCE
    end
    follow.catchup = catchup
    if not catchup then return "formation" end
    if playerDistance >= FOLLOW_HARD_CATCHUP_DISTANCE then return "hard_catchup" end
    return "catchup"
end

local function followTarget(player, record, follow, px, py, pz, playerDistance)
    local fx, fy = updateFollowHeading(player, follow, px, py)
    local slot = tonumber(record and record.companion and record.companion.squadSlot) or 1
    local mode = updateFollowMode(follow, playerDistance)
    if mode ~= "formation" then
        return px - fx * FOLLOW_CATCHUP_OFFSET, py - fy * FOLLOW_CATCHUP_OFFSET, pz, slot, mode
    end
    local formation = FOLLOW_FORMATION[slot] or { back = FOLLOW_OFFSET, side = 0 }
    local lateralX, lateralY = -fy, fx
    return px - fx * formation.back + lateralX * formation.side,
        py - fy * formation.back + lateralY * formation.side,
        pz, slot, mode
end

local function followLocomotion(player)
    local sneaking = protectedCall(player, "isSneaking") == true
    local sprinting = protectedCall(player, "isSprinting") == true
    local running = protectedCall(player, "isRunning") == true
    if sneaking and (running or sprinting) then
        return "crouch_run", FOLLOW_LOCOMOTION.crouch_run, sneaking, running, sprinting
    end
    if sneaking then return "crouch_walk", FOLLOW_LOCOMOTION.crouch_walk, sneaking, running, sprinting end
    if sprinting then return "sprint", FOLLOW_LOCOMOTION.sprint, sneaking, running, sprinting end
    if running then return "run", FOLLOW_LOCOMOTION.run, sneaking, running, sprinting end
    return "walk", FOLLOW_LOCOMOTION.walk, sneaking, running, sprinting
end

local function rememberMoveResult(handle, move, status, reason, distance)
    if not handle then return end
    handle.runtime = handle.runtime or {}
    handle.runtime.lastMove = {
        status = status,
        reason = reason,
        distance = distance,
        atMs = nowMs(),
        attempts = move and move.attempts or nil,
        cycles = move and move.pathCycles or nil,
    }
end

local function tickMoveTo(record, handle, intent)
    local actor = handle and handle.actor or nil
    if not actor then
        return { handled = true, failed = true, status = "failed", reason = "actor_missing" }
    end
    if record and record.combat and record.combat.state == "engaged" then
        return { handled = true, status = "combat", reason = record.combat.reason or "combat_interrupt" }
    end
    local data = intent.data or {}
    local tx, ty, tz = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not tx or not ty or not tz then
        return { handled = true, failed = true, status = "failed", reason = "invalid_destination" }
    end
    handle.runtime = handle.runtime or {}
    local move = handle.runtime.move
    if not move or move.intent ~= intent then
        stopActorMotion(actor, { clearTarget = true })
        move = { intent = intent, attempts = 1, pathCycles = 0, lastProgressAtMs = nowMs(), bestDistance = math.huge }
        handle.runtime.move = move
        handle.runtime.follow = nil
    end
    applyMovementProfile(actor, FOLLOW_LOCOMOTION.walk)
    local distance = distanceTo(actor, tx, ty)
    if distance <= MOVE_ARRIVAL_DISTANCE then
        stopActorMotion(actor, { clearTarget = true })
        rememberMoveResult(handle, move, "arrived", "lwn_distance_threshold", distance)
        handle.runtime.move = nil
        return { handled = true, done = true, status = "arrived", reason = "lwn_distance_threshold", distance = distance }
    end
    local now = nowMs()
    if distance < move.bestDistance - MOVE_PROGRESS_EPSILON then
        move.bestDistance = distance
        move.lastProgressAtMs = now
    elseif now - move.lastProgressAtMs >= MOVE_STALL_MS then
        markMovementAnimFallback(record, actor, "move_no_progress")
        if move.attempts >= MOVE_MAX_ATTEMPTS then
            stopActorMotion(actor, { clearTarget = true })
            rememberMoveResult(handle, move, "failed", "lwn_no_progress_after_3_attempts", distance)
            handle.runtime.move = nil
            return { handled = true, failed = true, status = "failed", reason = "lwn_no_progress_after_3_attempts", distance = distance }
        end
        stopActorMotion(actor, { clearTarget = true })
        move.started = false
        move.attempts = move.attempts + 1
        move.lastProgressAtMs = now
        move.bestDistance = distance
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Movement", "move_retry", {
                npcId = record and record.id,
                source = "isozombie",
                status = "retry",
                reason = "no_progress_5s",
                distance = string.format("%.2f", distance),
                count = move.attempts,
            })
        end
    end
    if move.started ~= true then
        clearCombatIntent(actor, { stopActions = false, clearPath = false })
        local ok, method = startPathTo(actor, tx, ty, tz, FOLLOW_LOCOMOTION.walk)
        if not ok then
            handle.runtime.move = nil
            return { handled = true, failed = true, status = "failed", reason = method or "path_start_failed" }
        end
        move.started = true
        move.pathMethod = method
        move.pathCycles = move.pathCycles + 1
    end
    local pathResult = tickPathfinder(actor)
    if pathResult == "Failed" or pathResult == "Error" or pathResult == "Missing" then
        move.started = false
    end
    return {
        handled = true,
        status = "pathing",
        reason = "lwn_move_active",
        distance = distance,
        attempts = move.attempts,
        taskCycles = move.pathCycles,
    }
end

local function tickFollowPlayer(record, handle, intent)
    local actor = handle and handle.actor or nil
    if not actor then
        return { handled = true, failed = true, status = "failed", reason = "actor_missing" }
    end
    if record and record.combat and record.combat.state == "engaged" then
        return { handled = true, status = "combat", reason = record.combat.reason or "combat_interrupt" }
    end
    local player = getSpecificPlayer and getSpecificPlayer(0) or (getPlayer and getPlayer()) or nil
    if not player then
        return { handled = true, failed = true, status = "failed", reason = "follow_player_missing" }
    end
    handle.runtime = handle.runtime or {}
    local follow = handle.runtime.follow
    if not follow or follow.intent ~= intent then
        stopActorMotion(actor, { clearTarget = true })
        follow = {
            intent = intent,
            pathCycles = 0,
            repaths = 0,
            lastProgressAtMs = nowMs(),
            lastX = tonumber(protectedCall(actor, "getX") or 0) or 0,
            lastY = tonumber(protectedCall(actor, "getY") or 0) or 0,
        }
        handle.runtime.follow = follow
        handle.runtime.move = nil
    end
    local ax = tonumber(protectedCall(actor, "getX") or 0) or 0
    local ay = tonumber(protectedCall(actor, "getY") or 0) or 0
    local px = tonumber(protectedCall(player, "getX") or ax) or ax
    local py = tonumber(protectedCall(player, "getY") or ay) or ay
    local pz = tonumber(protectedCall(player, "getZ") or 0) or 0
    local playerDistance = math.sqrt((ax - px) ^ 2 + (ay - py) ^ 2)
    local tx, ty, tz, formationSlot, followMode = followTarget(player, record, follow, px, py, pz, playerDistance)
    local targetDistance = math.sqrt((ax - tx) ^ 2 + (ay - ty) ^ 2)
    local movementMode, profile, playerSneaking, playerRunning, playerSprinting = followLocomotion(player)
    if followMode == "hard_catchup" then
        movementMode, profile = "sprint", FOLLOW_LOCOMOTION.sprint
    elseif followMode == "catchup" and movementMode ~= "sprint" then
        movementMode, profile = "run", FOLLOW_LOCOMOTION.run
    end
    applyMovementProfile(actor, profile)
    clearCombatIntent(actor, { stopActions = false, clearPath = false })
    local now = nowMs()
    local moved = math.sqrt((ax - follow.lastX) ^ 2 + (ay - follow.lastY) ^ 2)
    if targetDistance > FOLLOW_ARRIVAL_DISTANCE and moved < MOVE_PROGRESS_EPSILON and now - follow.lastProgressAtMs >= MOVE_STALL_MS then
        markMovementAnimFallback(record, actor, "follow_no_progress")
        stopActorMotion(actor, { clearTarget = true })
        follow.started = false
        follow.repaths = follow.repaths + 1
        follow.lastProgressAtMs = now
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Movement", "follow_repath", {
                npcId = record and record.id,
                source = "isozombie",
                status = "repath",
                reason = "follow_no_progress_5s",
                distance = string.format("%.2f", playerDistance),
                count = follow.repaths,
            })
        end
    elseif moved >= MOVE_PROGRESS_EPSILON or targetDistance <= FOLLOW_ARRIVAL_DISTANCE then
        follow.lastX, follow.lastY = ax, ay
        follow.lastProgressAtMs = now
    end
    local targetShift = follow.targetX and math.sqrt((tx - follow.targetX) ^ 2 + (ty - follow.targetY) ^ 2) or math.huge
    local styleChanged = follow.movementMode ~= nil and follow.movementMode ~= movementMode
    local canRetarget = follow.lastPathAtMs == nil or now - follow.lastPathAtMs >= FOLLOW_RETARGET_MS
    if targetDistance <= FOLLOW_ARRIVAL_DISTANCE then
        stopActorMotion(actor, { clearTarget = true })
        follow.started = false
    elseif follow.started ~= true or (canRetarget and (styleChanged or targetShift >= FOLLOW_RETARGET_DISTANCE)) then
        stopActorMotion(actor, { clearTarget = true })
        local ok = startPathTo(actor, tx, ty, tz, profile)
        if ok then
            follow.started = true
            follow.pathCycles = follow.pathCycles + 1
            follow.targetX, follow.targetY, follow.targetZ = tx, ty, tz
            follow.lastPathAtMs = now
        end
    end
    if follow.started == true then
        local pathResult = tickPathfinder(actor)
        if pathResult == "Failed" or pathResult == "Error" or pathResult == "Missing" then
            follow.started = false
        end
    end
    follow.movementMode = movementMode
    follow.walkType = profile.walkType
    follow.playerSneaking = playerSneaking
    follow.playerRunning = playerRunning
    follow.playerSprinting = playerSprinting
    follow.playerDistance = playerDistance
    follow.targetDistance = targetDistance
    follow.followMode = followMode
    follow.formationSlot = formationSlot
    return {
        handled = true,
        status = "following",
        reason = targetDistance <= FOLLOW_ARRIVAL_DISTANCE and "follow_holding_trailing_position" or "follow_trailing_player",
        distance = playerDistance,
        walkType = profile.walkType,
        taskCycles = follow.pathCycles,
    }
end

local function tickAttackMelee(record, handle, intent)
    local actor = handle and handle.actor or nil
    if not actor then
        return { handled = true, failed = true, status = "failed", reason = "actor_missing" }
    end
    local target = resolveAttackTarget(actor, intent)
    if not target then
        return { handled = true, done = true, status = "done", reason = "target_lost" }
    end
    handle.runtime = handle.runtime or {}
    local attack = handle.runtime.attack
    if not attack or attack.intent ~= intent then
        attack = { intent = intent, startedAtMs = nowMs(), attempts = 0, pathCycles = 0, lastAttackAtMs = 0 }
        handle.runtime.attack = attack
    end
    protectedCall(actor, "setCanWalk", true)
    protectedCall(actor, "setUseless", false)
    protectedCall(actor, "setVariable", "NoLungeAttack", false)
    protectedCall(actor, "setTarget", target)
    local tx = tonumber(protectedCall(target, "getX") or 0) or 0
    local ty = tonumber(protectedCall(target, "getY") or 0) or 0
    local tz = tonumber(protectedCall(target, "getZ") or 0) or 0
    local distance = distanceTo(actor, tx, ty)
    if distance > ATTACK_RANGE then
        applyMovementProfile(actor, FOLLOW_LOCOMOTION.run)
        local targetShift = attack.targetX and math.sqrt((tx - attack.targetX) ^ 2 + (ty - attack.targetY) ^ 2) or math.huge
        if attack.pathStarted ~= true or targetShift >= ATTACK_REPATH_DISTANCE then
            stopActorMotion(actor, { clearTarget = false })
            local ok = startPathTo(actor, tx, ty, tz, FOLLOW_LOCOMOTION.run)
            if ok then
                attack.pathStarted = true
                attack.pathCycles = attack.pathCycles + 1
                attack.targetX, attack.targetY, attack.targetZ = tx, ty, tz
            end
        end
        if attack.pathStarted == true then
            local pathResult = tickPathfinder(actor)
            if pathResult == "Failed" or pathResult == "Error" or pathResult == "Missing" then
                attack.pathStarted = false
            end
        end
        if nowMs() - attack.startedAtMs > ATTACK_TIMEOUT_MS then
            stopActorMotion(actor, { clearTarget = true })
            handle.runtime.attack = nil
            return { handled = true, failed = true, status = "failed", reason = "attack_timeout", distance = distance }
        end
        return { handled = true, status = "closing", reason = "attack_move_to_target", distance = distance }
    end
    stopActorMotion(actor, { clearTarget = false })
    protectedCall(actor, "faceThisObject", target)
    local now = nowMs()
    if now - (tonumber(attack.lastAttackAtMs) or 0) >= ATTACK_RETRY_MS then
        attack.lastAttackAtMs = now
        attack.attempts = attack.attempts + 1
        if actor.AttemptAttack then
            pcall(actor.AttemptAttack, actor, 1.0)
        elseif actor.DoAttack then
            pcall(actor.DoAttack, actor, 1.0)
        else
            handle.runtime.attack = nil
            return { handled = true, failed = true, status = "failed", reason = "attack_api_missing" }
        end
        if LWN.Log and LWN.Log.info then
            LWN.Log.info("Combat", "attack_attempt", {
                npcId = record and record.id,
                source = "isozombie",
                status = "attacking",
                reason = record and record.combat and record.combat.reason or "attack_melee",
                count = attack.attempts,
                distance = string.format("%.2f", distance),
                target = tostring(target),
            }, { rateKey = tostring(record and record.id or "unknown") .. ":attack_attempt", rateMs = 1000 })
        end
    end
    if not isOrdinaryZombieActor(target) then
        handle.runtime.attack = nil
        protectedCall(actor, "setTarget", nil)
        return { handled = true, done = true, status = "done", reason = "target_dead" }
    end
    if now - attack.startedAtMs > ATTACK_TIMEOUT_MS then
        handle.runtime.attack = nil
        return { handled = true, failed = true, status = "failed", reason = "attack_timeout", distance = distance }
    end
    return { handled = true, status = "attacking", reason = "attack_melee", distance = distance, attempts = attack.attempts }
end

function Carrier.cancelIntent(record, handle, intent, reason)
    local actor = handle and handle.actor or nil
    if actor then
        stopActorMotion(actor, { clearTarget = true, stopActions = false })
    end
    if handle and handle.runtime then
        rememberMoveResult(handle, handle.runtime.move or handle.runtime.follow, "cancelled", reason or "intent_cancelled", nil)
        handle.runtime.move = nil
        handle.runtime.follow = nil
        handle.runtime.attack = nil
    end
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("CommandRuntime", "carrier_intent_cancelled", {
            npcId = record and record.id,
            source = "isozombie",
            intent = intent and intent.kind,
            reason = reason or "intent_cancelled",
            status = "cancelled",
        })
    end
    return { ok = true, detail = reason or "intent_cancelled" }
end

function Carrier.tickIntent(record, handle, intent)
    if not intent then return { handled = false } end
    if intent.kind == "move_to" then
        return tickMoveTo(record, handle, intent)
    end
    if intent.kind == "follow_player" then
        return tickFollowPlayer(record, handle, intent)
    end
    if intent.kind == "attack_melee" then
        return tickAttackMelee(record, handle, intent)
    end
    return { handled = false }
end

local function isPlayerAttacker(attacker)
    return attacker
        and instanceof
        and instanceof(attacker, "IsoPlayer")
        and protectedCall(attacker, "isNPC") ~= true
end

local function recordForActor(actor)
    local modData = protectedCall(actor, "getModData")
    local npcId = modData and (modData.LWN_NpcId or modData.LWN_LastNpcId) or nil
    return npcId and LWN.PopulationStore and LWN.PopulationStore.getNPC
        and LWN.PopulationStore.getNPC(npcId) or nil
end

local function friendlyRecordForActor(actor)
    local record = recordForActor(actor)
    if not record then return nil end
    if LWN.PopulationStore and LWN.PopulationStore.isAlive and LWN.PopulationStore.isAlive(record) ~= true then
        return nil
    end
    local policy = LWN.Social and LWN.Social.relationshipCombatPolicy
        and LWN.Social.relationshipCombatPolicy(record) or nil
    if not policy or policy.allowPlayerAttack == true then return nil end
    return record
end

local function actorDeathLike(actor)
    if not actor then return true end
    if protectedCall(actor, "isDead") == true then return true end
    if protectedCall(actor, "isAlive") == false then return true end
    if (tonumber(protectedCall(actor, "getHealth")) or 1) <= 0 then return true end
    return false
end

local function syncHealth(record, actor, source)
    if not record or not actor then return nil end
    local health = tonumber(protectedCall(actor, "getHealth") or record.stats and record.stats.health or 0) or 0
    record.stats = record.stats or {}
    record.stats.health = health
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_LastHealthSync = source or "CarrierIsoZombie.syncHealth"
        modData.LWN_LastHealthSyncAt = worldAgeHours()
        modData.LWN_LastHealth = health
    end
    if health <= 0 and LWN.EmbodimentManager and LWN.EmbodimentManager.noteDeath then
        LWN.EmbodimentManager.noteDeath(record, actor, source or "CarrierIsoZombie.health_zero", "health_zero")
    end
    return health
end

local function beginFriendlyFireProtection(record, actor, source)
    local recordHealth = tonumber(record and record.stats and record.stats.health)
    local actorHealth = tonumber(protectedCall(actor, "getHealth"))
    local health = recordHealth and recordHealth > 0 and recordHealth or actorHealth or 1
    protectedCall(actor, "setAvoidDamage", true)
    protectedCall(actor, "setGodMod", false)
    protectedCall(actor, "setInvulnerable", false)
    protectedCall(actor, "setHealth", health)
    Carrier.PendingHitRepairs[record.id] = {
        actor = actor,
        health = health,
        source = source or "friendly_fire",
        remainingTicks = 3,
    }
    return health
end

function Carrier.onHitZombie(actor, attacker)
    if LWN.Combat and LWN.Combat.notePlayerAttack then
        LWN.Combat.notePlayerAttack(actor, attacker)
    end
    local record = friendlyRecordForActor(actor)
    if not record then return end
    if isPlayerAttacker(attacker) then
        local restoreHealth = beginFriendlyFireProtection(record, actor, "on_hit_zombie")
        protectedCall(actor, "setHealth", restoreHealth)
        protectedCall(actor, "setKnockedDown", false)
        protectedCall(actor, "setOnFloor", false)
        protectedCall(actor, "setFallOnFront", false)
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Combat", "friendly_hit_suppressed", {
                npcId = record.id,
                actor = tostring(actor),
                target = tostring(attacker),
                health = string.format("%.2f", restoreHealth),
                reason = "player_hit_blocked",
                source = "isozombie",
            })
        end
        return
    end
    if isOrdinaryZombieActor(attacker) then
        if LWN.Combat and LWN.Combat.noteSquadHit then
            LWN.Combat.noteSquadHit(record, attacker)
        end
        local health = syncHealth(record, actor, "zombie_hit") or 0
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Combat", "zombie_damage_accepted", {
                npcId = record.id,
                actor = tostring(actor),
                target = tostring(attacker),
                health = string.format("%.2f", health),
                reason = "zombie_hit",
                source = "isozombie",
            })
        end
    end
end

function Carrier.onWeaponHitCharacter(attacker, actor)
    if LWN.Combat and LWN.Combat.notePlayerAttack then
        LWN.Combat.notePlayerAttack(actor, attacker)
    end
    local record = friendlyRecordForActor(actor)
    if not record or not isPlayerAttacker(attacker) then return end
    local restoreHealth = beginFriendlyFireProtection(record, actor, "on_weapon_hit_character")
    protectedCall(actor, "setHealth", restoreHealth)
    if LWN.Log and LWN.Log.warn then
        LWN.Log.warn("Combat", "friendly_weapon_hit_suppressed", {
            npcId = record.id,
            actor = tostring(actor),
            target = tostring(attacker),
            health = string.format("%.2f", restoreHealth),
            reason = "player_weapon_hit_blocked",
            source = "isozombie",
        })
    end
    return false
end

local function tickPendingHitRepairs()
    for npcId, repair in pairs(Carrier.PendingHitRepairs) do
        local actor = repair and repair.actor or nil
        local record = LWN.PopulationStore and LWN.PopulationStore.getNPC
            and LWN.PopulationStore.getNPC(npcId) or nil
        if not record
            or (LWN.PopulationStore.isAlive and LWN.PopulationStore.isAlive(record) ~= true)
            or actorDeathLike(actor)
        then
            Carrier.PendingHitRepairs[npcId] = nil
        else
            local restoreHealth = tonumber(repair.health) or tonumber(record.stats and record.stats.health) or 1
            if restoreHealth > 0 then
                protectedCall(actor, "setHealth", restoreHealth)
            end
            protectedCall(actor, "setKnockedDown", false)
            protectedCall(actor, "setOnFloor", false)
            protectedCall(actor, "setFallOnFront", false)
            protectedCall(actor, "setAlwaysKnockedDown", false)
            repair.remainingTicks = (tonumber(repair.remainingTicks) or 1) - 1
            if repair.remainingTicks <= 0 then
                protectedCall(actor, "setAvoidDamage", false)
                syncHealth(record, actor, "friendly_fire_repair_complete")
                Carrier.PendingHitRepairs[npcId] = nil
                if LWN.Log and LWN.Log.info then
                    LWN.Log.info("Combat", "friendly_hit_repair_complete", {
                        npcId = npcId,
                        actor = tostring(actor),
                        health = string.format("%.2f", tonumber(protectedCall(actor, "getHealth") or restoreHealth) or 0),
                        reason = repair.source,
                        source = "isozombie",
                    })
                end
            end
        end
    end
end

function Carrier.tick()
    tickPendingHitRepairs()
end

function Carrier.getDebugState(record, handle)
    local actor = handle and handle.actor or nil
    local modData = protectedCall(actor, "getModData")
    local runtime = handle and handle.runtime or {}
    local move = runtime and (runtime.move or runtime.follow or runtime.attack) or nil
    return {
        source = "isozombie",
        target = protectedCall(actor, "getTarget") ~= nil,
        task = modData and modData.LWN_ActiveTask or nil,
        combatTask = record and record.combat and record.combat.state == "engaged" and "attack_melee" or nil,
        moveAttempt = move and move.attempts or nil,
        moveCycle = move and (move.pathCycles or move.cycles) or nil,
        moveStatus = runtime and runtime.lastMove and runtime.lastMove.status or nil,
        moveReason = runtime and runtime.lastMove and runtime.lastMove.reason or nil,
        moveDistance = runtime and runtime.lastMove and runtime.lastMove.distance or nil,
        followMode = runtime and runtime.follow and runtime.follow.followMode or nil,
        followDistance = runtime and runtime.follow and runtime.follow.playerDistance or nil,
        walkType = protectedCall(actor, "getVariableString", "LWNWalkType") or protectedCall(actor, "getWalkType"),
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

if Events and Events.OnHitZombie then
    if Carrier._onHitZombieHandler then
        Events.OnHitZombie.Remove(Carrier._onHitZombieHandler)
    end
    Carrier._onHitZombieHandler = function(actor, attacker)
        Carrier.onHitZombie(actor, attacker)
    end
    Events.OnHitZombie.Add(Carrier._onHitZombieHandler)
end

if Events and Events.OnWeaponHitCharacter then
    if Carrier._onWeaponHitCharacterHandler then
        Events.OnWeaponHitCharacter.Remove(Carrier._onWeaponHitCharacterHandler)
    end
    Carrier._onWeaponHitCharacterHandler = function(attacker, actor)
        return Carrier.onWeaponHitCharacter(attacker, actor)
    end
    Events.OnWeaponHitCharacter.Add(Carrier._onWeaponHitCharacterHandler)
end
