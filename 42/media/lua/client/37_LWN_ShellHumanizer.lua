LWN = LWN or {}
LWN.ShellHumanizer = LWN.ShellHumanizer or {}

local Humanizer = LWN.ShellHumanizer
local Store = LWN.PopulationStore

local DEFAULT_EXPERIMENT = "isozombie_initial_humanization_v1"

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

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function safeText(value)
    if value == nil then return "nil" end
    local text = tostring(value)
    text = text:gsub("[\r\n|]", " ")
    return text
end

local function trace(stage, record, detail)
    print(string.format(
        "[LWN][ShellHumanizer] stage=%s | npcId=%s | detail=%s",
        safeText(stage),
        safeText(record and record.id or nil),
        safeText(detail)
    ))
end

local function ensureIllusionState(record)
    record = ensureRecordShape(record)
    if not record then return nil end

    record.embodiment = record.embodiment or {}
    record.embodiment.illusion = record.embodiment.illusion or {
        initialApplied = false,
        initialAppliedAt = nil,
        initialSource = nil,
        initialProfile = nil,
        initialAppearanceSignature = nil,
        lastMaintenanceAt = nil,
        lastMaintenanceSource = nil,
        lastMaintenanceProfile = nil,
        lastKnownAppearanceSignature = nil,
        lastMaintenanceMode = nil,
        lockedAppearanceSignature = nil,
        driftCount = 0,
        lastDriftAt = nil,
        lastDriftReason = nil,
    }
    return record.embodiment.illusion
end

local function normalizeAppearanceDetail(detail, overrides)
    local normalized = {
        applied = detail and detail.applied == true or false,
        experiment = detail and detail.experiment or DEFAULT_EXPERIMENT,
        reuse = detail and detail.reuse or "desc+baseline+clothes+bridge",
        bridgeMode = detail and detail.bridgeMode or "pending",
        descriptorMode = detail and detail.descriptorMode or "pending",
        descriptorSource = detail and detail.descriptorSource or "pending",
        stage = detail and detail.stage or nil,
        status = detail and detail.status or nil,
        profile = detail and detail.profile or nil,
        mode = detail and detail.mode or nil,
        skipped = detail and detail.skipped == true or false,
        reason = detail and detail.reason or nil,
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
        normalized.status = normalized.skipped == true and "skipped" or "pending"
    end
    if normalized.stage == nil then
        normalized.stage = normalized.status
    end
    return normalized
end

local function currentAppearanceSignature(actor)
    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_AppearanceSignature or nil
end

local function cachedAppearanceDetail(actor, overrides)
    local modData = protectedCall(actor, "getModData")
    if not modData or modData.LWN_HybridAppearanceExperiment == nil then
        return normalizeAppearanceDetail(nil, overrides)
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
    }, overrides)
end

local function stampHumanizationState(record, actor, detail, source, profile, mode)
    local illusion = ensureIllusionState(record)
    local modData = protectedCall(actor, "getModData")
    if not illusion then return end

    local signature = currentAppearanceSignature(actor)
    local now = worldAgeHours()
    local harness = record and record.debugHarness or nil

    if mode == "initial" then
        illusion.initialApplied = detail and detail.applied == true or false
        illusion.initialAppliedAt = now
        illusion.initialSource = source
        illusion.initialProfile = profile
        illusion.initialAppearanceSignature = signature
        illusion.lastKnownAppearanceSignature = signature
        if harness and harness.identityLock == true then
            illusion.lockedAppearanceSignature = signature
        end
    else
        local previousSignature = illusion.lastKnownAppearanceSignature
        if previousSignature and signature and previousSignature ~= signature then
            illusion.driftCount = (tonumber(illusion.driftCount) or 0) + 1
            illusion.lastDriftAt = now
            illusion.lastDriftReason = source
        end
        if not (detail and detail.mode == "maintenance_identity_lock_restore_pending") then
            illusion.lastKnownAppearanceSignature = signature or illusion.lastKnownAppearanceSignature
        end
        illusion.lastMaintenanceAt = now
        illusion.lastMaintenanceSource = source
        illusion.lastMaintenanceProfile = profile
        illusion.lastMaintenanceMode = detail and detail.mode or mode
    end

    if modData then
        modData.LWN_InitialHumanizationApplied = illusion.initialApplied == true
        modData.LWN_InitialHumanizationAt = illusion.initialAppliedAt
        modData.LWN_InitialHumanizationSource = illusion.initialSource
        modData.LWN_InitialHumanizationProfile = illusion.initialProfile
        modData.LWN_InitialAppearanceSignature = illusion.initialAppearanceSignature
        modData.LWN_LastKnownAppearanceSignature = illusion.lastKnownAppearanceSignature
        modData.LWN_LockedAppearanceSignature = illusion.lockedAppearanceSignature
        modData.LWN_HumanizationDriftCount = illusion.driftCount or 0
        modData.LWN_HumanizationLastDriftAt = illusion.lastDriftAt
        modData.LWN_HumanizationLastDriftReason = illusion.lastDriftReason
        modData.LWN_MaintenanceHumanizationAt = illusion.lastMaintenanceAt
        modData.LWN_MaintenanceHumanizationSource = illusion.lastMaintenanceSource
        modData.LWN_MaintenanceHumanizationProfile = illusion.lastMaintenanceProfile
        modData.LWN_MaintenanceHumanizationMode = illusion.lastMaintenanceMode
    end
end

function Humanizer.ensureIllusionState(record)
    return ensureIllusionState(record)
end

function Humanizer.hasInitialApplied(record, actor)
    local illusion = ensureIllusionState(record)
    if illusion and illusion.initialApplied == true then
        return true
    end

    local modData = protectedCall(actor, "getModData")
    return modData and modData.LWN_InitialHumanizationApplied == true or false
end

function Humanizer.getIllusionState(record)
    return ensureIllusionState(record)
end

function Humanizer.applyInitial(record, actor, options)
    record = ensureRecordShape(record)
    local profile = options and options.profile or "neutral"
    local source = options and options.source or "ShellHumanizer.applyInitial"
    local experimentName = options and options.experimentName or DEFAULT_EXPERIMENT
    local descriptor = protectedCall(actor, "getDescriptor")

    if not actor then
        local detail = normalizeAppearanceDetail(nil, {
            skipped = true,
            reason = "actor=nil",
            stage = "initial_skipped",
            status = "skipped",
            profile = profile,
            mode = "initial",
        })
        trace("initial.skipped", record, "actor=nil")
        return descriptor, detail
    end

    if Humanizer.hasInitialApplied(record, actor) and not (options and options.force == true) then
        local detail = cachedAppearanceDetail(actor, {
            stage = "initial_cached",
            status = "applied",
            profile = profile,
            mode = "initial_cached",
            skipped = true,
            reason = "already_initialized",
        })
        stampHumanizationState(record, actor, detail, source .. ".cached", profile, "initial_cached")
        trace("initial.cached", record, string.format(
            "profile=%s sig=%s",
            tostring(profile),
            tostring(currentAppearanceSignature(actor))
        ))
        return descriptor, detail
    end

    if not (LWN.ActorFactory and LWN.ActorFactory.applySafeAppearanceShaping) then
        local detail = normalizeAppearanceDetail(nil, {
            skipped = true,
            reason = "helper_missing",
            stage = "initial_skipped",
            status = "skipped",
            profile = profile,
            mode = "initial",
        })
        trace("initial.skipped", record, "helper_missing")
        return descriptor, detail
    end

    local ok, shapedDescriptor, detail = pcall(LWN.ActorFactory.applySafeAppearanceShaping, record, actor, {
        source = source,
        experimentName = experimentName,
    })
    if not ok then
        local failedDetail = normalizeAppearanceDetail(nil, {
            skipped = true,
            reason = tostring(shapedDescriptor),
            stage = "initial_error",
            status = "skipped",
            profile = profile,
            mode = "initial",
            bridgeMode = "error",
            descriptorMode = "error",
        })
        trace("initial.error", record, tostring(shapedDescriptor))
        return descriptor, failedDetail
    end

    detail = normalizeAppearanceDetail(detail, {
        stage = detail and detail.applied == true and "initial_applied" or "initial_skipped",
        status = detail and detail.applied == true and "applied" or "skipped",
        profile = profile,
        mode = "initial",
    })
    stampHumanizationState(record, actor, detail, source, profile, "initial")
    trace("initial.ready", record, string.format(
        "profile=%s applied=%s sig=%s bridge=%s",
        tostring(profile),
        tostring(detail.applied == true),
        tostring(currentAppearanceSignature(actor)),
        tostring(detail.bridgeMode)
    ))
    return shapedDescriptor, detail
end

function Humanizer.maintain(record, actor, options)
    record = ensureRecordShape(record)
    local profile = options and options.profile or "neutral"
    local source = options and options.source or "ShellHumanizer.maintain"
    local descriptor = protectedCall(actor, "getDescriptor")
    local harness = record and record.debugHarness or nil

    if not actor then
        local detail = normalizeAppearanceDetail(nil, {
            skipped = true,
            reason = "actor=nil",
            stage = "maintenance_skipped",
            status = "skipped",
            profile = profile,
            mode = "maintenance",
        })
        trace("maintenance.skipped", record, "actor=nil")
        return descriptor, detail
    end

    if Humanizer.hasInitialApplied(record, actor) ~= true then
        return Humanizer.applyInitial(record, actor, {
            source = source .. ".bootstrap",
            profile = profile,
            experimentName = options and options.experimentName or DEFAULT_EXPERIMENT,
            force = options and options.forceInitial == true,
        })
    end

    local modData = protectedCall(actor, "getModData")
    local illusion = ensureIllusionState(record)
    local beforeSig = currentAppearanceSignature(actor)
    local lockedSig = illusion and (illusion.lockedAppearanceSignature or illusion.initialAppearanceSignature) or nil
    local lockedMismatch = harness and harness.identityLock == true and lockedSig and beforeSig and beforeSig ~= lockedSig or false
    local needFullReapply = options and options.forceFull == true
    if not beforeSig or beforeSig == "" then
        needFullReapply = true
    end
    if modData and modData.LWN_HybridAppearanceApplied ~= true then
        needFullReapply = true
    end
    if lockedMismatch then
        needFullReapply = false
    end

    local detail
    if needFullReapply then
        local ok, shapedDescriptor, shapedDetail = pcall(LWN.ActorFactory.applySafeAppearanceShaping, record, actor, {
            source = source .. ".full",
            experimentName = options and options.experimentName or DEFAULT_EXPERIMENT,
        })
        if ok then
            descriptor = shapedDescriptor or descriptor
            detail = normalizeAppearanceDetail(shapedDetail, {
                stage = "maintenance_full_reapply",
                status = shapedDetail and shapedDetail.applied == true and "applied" or "skipped",
                profile = profile,
                mode = "maintenance_full_reapply",
            })
        else
            detail = normalizeAppearanceDetail(nil, {
                skipped = true,
                reason = tostring(shapedDescriptor),
                stage = "maintenance_full_error",
                status = "skipped",
                profile = profile,
                mode = "maintenance_full_reapply",
                bridgeMode = "error",
                descriptorMode = "error",
            })
            trace("maintenance.error", record, tostring(shapedDescriptor))
        end
    else
        if LWN.ActorFactory and LWN.ActorFactory.restoreEmbodiedPresentationFlags then
            LWN.ActorFactory.restoreEmbodiedPresentationFlags(actor, source)
        end
        if LWN.ActorFactory and LWN.ActorFactory.repairVisibleAlpha then
            LWN.ActorFactory.repairVisibleAlpha(actor, source)
        end
        if not lockedMismatch then
            if LWN.ActorFactory and LWN.ActorFactory.refreshEmbodiedPresentation then
                -- too heavy for maintenance; prefer the lower-level visual refresh path
            end
            if LWN.ActorFactory and LWN.ActorFactory.refreshActorPresentation then
                LWN.ActorFactory.refreshActorPresentation(actor)
            elseif LWN.ActorFactory and LWN.ActorFactory.applySafeAppearanceShaping then
                needFullReapply = true
            end
        end

        detail = cachedAppearanceDetail(actor, {
            applied = true,
            stage = lockedMismatch
                and "maintenance_identity_lock_restore_pending"
                or "maintenance_light",
            status = "applied",
            profile = profile,
            mode = lockedMismatch
                and "maintenance_identity_lock_restore_pending"
                or "maintenance_light",
            reason = lockedMismatch
                and "signature_locked_restore_pending"
                or nil,
        })
    end

    stampHumanizationState(record, actor, detail, source, profile, detail and detail.mode or "maintenance")
    trace("maintenance.ready", record, string.format(
        "profile=%s mode=%s beforeSig=%s afterSig=%s driftCount=%s",
        tostring(profile),
        tostring(detail and detail.mode or "nil"),
        tostring(beforeSig),
        tostring(currentAppearanceSignature(actor)),
        tostring(record and record.embodiment and record.embodiment.illusion and record.embodiment.illusion.driftCount or 0)
    ))
    return descriptor, detail
end
