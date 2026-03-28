LWN = LWN or {}
LWN.DebugTools = LWN.DebugTools or {}

-- Development-only helpers. They should stay available in debug builds because
-- most embodiment failures are easiest to diagnose from live saves.
local DebugTools = LWN.DebugTools
local Store = LWN.PopulationStore

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function ensureDebugState()
    return Store.debugState()
end

local function automationState()
    local debug = ensureDebugState()
    debug.automation = debug.automation or {
        active = false,
        scenario = nil,
        phase = nil,
        npcId = nil,
        destination = nil,
        startedAt = nil,
        updatedAt = nil,
        step = 0,
    }
    return debug.automation
end

local function clamp(value, minValue, maxValue)
    if type(value) ~= "number" then
        value = minValue
    end
    if value < minValue then value = minValue end
    if value > maxValue then value = maxValue end
    return value
end

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then
        return result
    end
    return nil
end

local function sayInfo(player, text)
    if player and player.Say then
        player:Say(text)
    end
    print("[LWN][Debug] " .. tostring(text))
end

local function sayChecklist(player, title, lines)
    sayInfo(player, tostring(title))
    for i = 1, #lines do
        sayInfo(player, tostring(lines[i]))
    end
end

local function boolText(value)
    if value == true then return "yes" end
    if value == false then return "no" end
    return tostring(value)
end

local function numberText(value, decimals)
    if type(value) ~= "number" then return tostring(value) end
    return string.format("%." .. tostring(decimals or 2) .. "f", value)
end

local function actorModData(record, actor)
    actor = actor or findActorForRecord(record)
    return actor and actor.getModData and actor:getModData() or nil, actor
end

local function movementSummaryLine(record, actor)
    local modData
    modData, actor = actorModData(record, actor)
    local command = record and record.companion and record.companion.command or {}
    local telemetry = command and command.movementTelemetry or {}
    return string.format(
        "MOVE SUMMARY npc=%s lane=%s cmd=%s/%s motor=%s commit=%s moving=%s attacking=%s target=%s path2=%s totalDelta=%s delta=%s,%s squareChanged=%s watchdog=%s canWalk=%s useless=%s humanInit=%s probeOk=%s appLock=%s appFail=%s",
        tostring(record and record.id or "nil"),
        tostring(modData and modData.LWN_ShellLaneContract or modData and modData.LWN_ShellMode or "none"),
        tostring(command.kind or "none"),
        tostring(command.status or "idle"),
        tostring(modData and modData.LWN_DummyMoveMotorState or "none"),
        tostring(modData and modData.LWN_DummyCommittedSquare or "none"),
        boolText(modData and modData.LWN_MoveTelemetryMoving),
        boolText(actor and protectedCall(actor, "isAttacking") == true),
        boolText(actor and protectedCall(actor, "getTarget") ~= nil),
        boolText(modData and modData.LWN_MoveTelemetryPath2),
        numberText(modData and modData.LWN_MoveTelemetryTotalDelta, 2),
        numberText(modData and modData.LWN_MoveTelemetryDeltaX, 2),
        numberText(modData and modData.LWN_MoveTelemetryDeltaY, 2),
        boolText((modData and modData.LWN_MoveTelemetrySquareChangedAt) ~= nil),
        boolText(
            command.lastReason == "watchdog:no_displacement_3s"
                or telemetry.lastReason == "watchdog:no_displacement_3s"
                or command.lastReason == "watchdog:path_only_statue"
                or telemetry.lastReason == "watchdog:path_only_statue"
        ),
        boolText(modData and modData.LWN_MoveTelemetryCanWalk),
        boolText(modData and modData.LWN_MoveTelemetryUseless),
        boolText(modData and (modData.LWN_HumanizationInitialApplied or modData.LWN_InitialHumanizationApplied)),
        boolText(modData and modData.LWN_HumanizationProbeOk),
        boolText(modData and modData.LWN_DummyAppearanceLocked),
        boolText(modData and modData.LWN_DummyAppearanceFailed)
    )
end

local function recoverySummaryLine(record, actor)
    local modData
    modData, actor = actorModData(record, actor)
    local state = record and record.embodiment and record.embodiment.state or "unknown"
    return string.format(
        "RECOVERY SUMMARY npc=%s state=%s lane=%s replacementPrecheck=%s attackLock=%s handleRef=%s",
        tostring(record and record.id or "nil"),
        tostring(state),
        tostring(modData and modData.LWN_ShellLaneContract or modData and modData.LWN_ShellMode or "none"),
        "check console for tryEmbody.replacement_precheck + recovery.cached_* + handle_*",
        tostring(record and record.embodiment and record.embodiment.attackQuarantineUntilHour or "none"),
        tostring(LWN.EmbodimentManager and LWN.EmbodimentManager.getCarrierHandle and LWN.EmbodimentManager.getCarrierHandle(record) and LWN.EmbodimentManager.getCarrierHandle(record).actor or nil)
    )
end

local function dumpAutomationOneLineSummary(record, actor, player, label)
    if not record then
        sayInfo(player, tostring(label or "TEST SUMMARY") .. " npc=nil")
        return false
    end
    local moveLine = movementSummaryLine(record, actor)
    local recoveryLine = recoverySummaryLine(record, actor)
    sayInfo(player, tostring(label or "TEST SUMMARY"))
    sayInfo(player, moveLine)
    sayInfo(player, recoveryLine)
    print("[LWN][Debug] automation summary :: " .. moveLine)
    print("[LWN][Debug] automation summary :: " .. recoveryLine)
    return true
end

local function isManagedActor(obj)
    if not obj then return false end
    if LWN.ActorFactory and LWN.ActorFactory.isManagedActor then
        return LWN.ActorFactory.isManagedActor(obj)
    end
    return false
end

local function getNpcId(actor)
    if not actor then return nil end
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        return LWN.ActorFactory.getNpcIdFromActor(actor)
    end
    local modData = actor.getModData and actor:getModData() or nil
    return modData and modData.LWN_NpcId or nil
end

local function randomizeIdentity(record)
    local female = ZombRand(0, 2) == 0
    record.identity.female = female

    if SurvivorFactory and SurvivorFactory.getRandomForename then
        record.identity.firstName = SurvivorFactory.getRandomForename(female) or record.identity.firstName
    end
    if SurvivorFactory and SurvivorFactory.getRandomSurname then
        record.identity.lastName = SurvivorFactory.getRandomSurname() or record.identity.lastName
    end
end

local function embodiedCoordsFor(record)
    local meta = record and Store.getEmbodiedMeta and Store.getEmbodiedMeta(record.id) or nil
    if meta and meta.x ~= nil and meta.y ~= nil then
        return tonumber(meta.x) or 0, tonumber(meta.y) or 0, tonumber(meta.z or 0) or 0, "meta"
    end
    local anchor = record and record.anchor or {}
    return tonumber(anchor.x) or 0, tonumber(anchor.y) or 0, tonumber(anchor.z) or 0, "anchor"
end

local function debugConfig(key, fallback)
    local cfg = LWN.Config and LWN.Config.Debug or nil
    if not cfg then return fallback end
    local value = cfg[key]
    if value == nil then return fallback end
    return value
end

local function clearNearbyWorldNoise(player, radius, protectedNpcId)
    if not player then return 0 end
    local square = protectedCall(player, "getSquare")
    local cell = getCell and getCell() or nil
    if not square or not cell then return 0 end

    local function isBoundToAnyLiveRecord(obj)
        local found = false
        Store.eachNPC(function(record)
            if found or Store.isAlive(record) ~= true then
                return
            end
            local actor = LWN.EmbodimentManager and LWN.EmbodimentManager.getActor and LWN.EmbodimentManager.getActor(record) or nil
            if actor and actor == obj then
                found = true
                return
            end
            local handle = LWN.EmbodimentManager and LWN.EmbodimentManager.getCarrierHandle and LWN.EmbodimentManager.getCarrierHandle(record) or nil
            if handle and handle.actor and handle.actor == obj then
                found = true
            end
        end)
        return found
    end

    local cx = protectedCall(square, "getX") or math.floor(player:getX())
    local cy = protectedCall(square, "getY") or math.floor(player:getY())
    local cz = protectedCall(square, "getZ") or math.floor(player:getZ())
    local removed = 0
    local seen = {}

    local function hasAnyLwnMarker(obj)
        local modData = obj and obj.getModData and obj:getModData() or nil
        if not modData then return false end
        return modData.LWN_NpcId ~= nil
            or modData.LWN_LastNpcId ~= nil
            or modData.LWN_TestHarnessLabel ~= nil
            or modData.LWN_ShellMarker ~= nil
    end

    local function maybeRemove(obj)
        if not obj or seen[obj] then return end
        seen[obj] = true
        local npcId = getNpcId(obj)
        if npcId and npcId == protectedNpcId then
            print(string.format("[LWN][Debug] debug_cleanup.protected_managed_shell :: reason=protectedNpcId npcId=%s actorRef=%s", tostring(npcId), tostring(obj)))
            return
        end
        if npcId ~= nil
            or hasAnyLwnMarker(obj)
            or isBoundToAnyLiveRecord(obj)
            or (LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.isKnownManagedShell and LWN.Carriers.isozombie.isKnownManagedShell(obj))
        then
            print(string.format("[LWN][Debug] debug_cleanup.protected_managed_shell :: reason=marker_or_cache npcId=%s actorRef=%s", tostring(npcId), tostring(obj)))
            return
        end
        local objectName = tostring(protectedCall(obj, "getObjectName") or "")
        local managed = isManagedActor(obj)
        local isZombie = protectedCall(obj, "isZombie") == true
        local isDeadBody = string.find(objectName, "DeadBody", 1, true) ~= nil
        if (isZombie and not managed) or isDeadBody then
            print(string.format("[LWN][Debug] debug_cleanup.removed_ordinary_zombie :: object=%s npcId=%s actorRef=%s", tostring(objectName), tostring(npcId), tostring(obj)))
            protectedCall(obj, "removeFromWorld")
            protectedCall(obj, "removeFromSquare")
            removed = removed + 1
        end
    end

    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            local scanSquare = cell:getGridSquare(x, y, cz)
            if scanSquare then
                local moving = protectedCall(scanSquare, "getMovingObjects")
                if moving and moving.size then
                    for i = moving:size() - 1, 0, -1 do
                        maybeRemove(moving:get(i))
                    end
                end
                local staticMoving = protectedCall(scanSquare, "getStaticMovingObjects")
                if staticMoving and staticMoving.size then
                    for i = staticMoving:size() - 1, 0, -1 do
                        maybeRemove(staticMoving:get(i))
                    end
                end
            end
        end
    end

    return removed
end

local function applyDebugHarnessDefaults(record, carrierKind)
    if not record then return end
    record.debugHarness = record.debugHarness or {}
    record.debugHarness.enabled = true
    record.debugHarness.label = string.format("TEST-%s", tostring(record.id or "NPC"))
    record.debugHarness.sterileRadius = tonumber(debugConfig("DebugSterileRadiusTiles", 8)) or 8
    record.debugHarness.identityLock = debugConfig("DebugTestIdentityLock", true) == true
    record.debugHarness.holdPosition = debugConfig("DebugTestHoldPosition", true) == true
    record.debugHarness.forceFriendly = false
    record.debugHarness.quarantine = false
    record.debugHarness.allowCommandMovement = true
    record.debugHarness.allowForcedHostile = false
    record.debugHarness.carrierKind = carrierKind or "isoplayer"
    record.debugHarness.mode = "minimal_dummy"
    record.identity.firstName = tostring(record.debugHarness.label)
    record.identity.lastName = carrierKind == "isozombie" and "Dummy" or "Debug"
    record.relationshipToPlayer.trust = 0.0
    record.relationshipToPlayer.respect = 0.0
    record.relationshipToPlayer.resentment = 0.0
    record.relationshipToPlayer.fear = 0.0
    record.relationshipToPlayer.affection = 0.0
end

local function applyDebugHarnessOverrides(record, overrides)
    if not record or type(overrides) ~= "table" then return end
    record.debugHarness = record.debugHarness or {}
    for key, value in pairs(overrides) do
        record.debugHarness[key] = value
    end
    if record.debugHarness.label then
        record.identity.firstName = tostring(record.debugHarness.label)
    end
end

local function ensureMinimalDummyState(record)
    if not record then return nil end
    record.dummy = record.dummy or {}
    local dummy = record.dummy
    dummy.enabled = true
    dummy.mode = "minimal_neutral_dummy"
    dummy.generationId = tonumber(dummy.generationId) or 1
    dummy.state = dummy.state or "spawn_pending"
    dummy.command = dummy.command or nil
    dummy.activeActorRef = dummy.activeActorRef or nil
    dummy.appearanceSeed = dummy.appearanceSeed or record.seed or ZombRand(1, 2147483646)
    dummy.appearanceLocked = dummy.appearanceLocked == true
    dummy.initialAppearanceOk = dummy.initialAppearanceOk == true
    dummy.lastMoveResult = dummy.lastMoveResult or nil

    record.companion = record.companion or {}
    record.companion.recruited = false
    record.companion.squadRole = "dummy"
    record.goals = record.goals or {}
    record.goals.longTerm = nil
    record.goals.shortTerm = nil
    record.drama = nil

    local rel = record.relationshipToPlayer or {}
    rel.trust = 0.0
    rel.respect = 0.0
    rel.resentment = 0.0
    rel.fear = 0.0
    rel.affection = 0.0
    record.relationshipToPlayer = rel
    return dummy
end

local function findActorForRecord(record)
    if not record or (Store.isAlive and not Store.isAlive(record)) then
        return nil
    end

    local actor = LWN.EmbodimentManager.getActor(record)
    if actor and getNpcId(actor) == record.id then
        return actor
    end

    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local meta = Store.getEmbodiedMeta(record.id)
    local cx = math.floor((meta and meta.x) or record.anchor.x or 0)
    local cy = math.floor((meta and meta.y) or record.anchor.y or 0)
    local cz = math.floor((meta and meta.z) or record.anchor.z or 0)

    for y = cy - 2, cy + 2 do
        for x = cx - 2, cx + 2 do
            local square = cell:getGridSquare(x, y, cz)
            if square and square:getMovingObjects() then
                for i = 0, square:getMovingObjects():size() - 1 do
                    local obj = square:getMovingObjects():get(i)
                    if isManagedActor(obj) and getNpcId(obj) == record.id then
                        LWN.EmbodimentManager.registerActor(record, obj)
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

local function chooseEmbodiedDebugVictim(player)
    if not player then return nil end

    local px, py = player:getX(), player:getY()
    local bestRecord = nil
    local bestD2 = -1

    Store.eachNPC(function(record)
        if Store.isAlive(record) and record.embodiment and record.embodiment.state == "embodied" and record.debugSpawnOnly then
            local dx = (record.anchor.x or 0) - px
            local dy = (record.anchor.y or 0) - py
            local d2 = dx * dx + dy * dy
            if d2 > bestD2 then
                bestRecord = record
                bestD2 = d2
            end
        end
    end)

    return bestRecord
end

local function findNearestRecord(player)
    if not player then return nil, nil end

    local px, py = player:getX(), player:getY()
    local bestRecord = nil
    local bestD2 = math.huge
    local bestPriority = -1

    Store.eachNPC(function(record)
        if Store.isAlive(record) ~= true then
            return
        end
        local ax, ay = embodiedCoordsFor(record)
        local dx = ax - px
        local dy = ay - py
        local d2 = dx * dx + dy * dy
        local priority = 0
        local actor = findActorForRecord(record)
        if record.debugSpawnOnly == true then
            priority = priority + 10
        end
        if record.debugHarness and record.debugHarness.enabled == true then
            priority = priority + 20
        end
        if record.embodiment and record.embodiment.carrierKind == "isozombie" then
            priority = priority + 5
        end
        if record.embodiment and record.embodiment.state == "embodied" then
            priority = priority + 40
        elseif record.embodiment and record.embodiment.state == "hidden" then
            priority = priority - 30
        end
        if actor then
            priority = priority + 30
            if protectedCall(actor, "isExistInTheWorld") == true then
                priority = priority + 15
            end
        end
        if priority > bestPriority or (priority == bestPriority and d2 < bestD2) then
            bestRecord = record
            bestD2 = d2
            bestPriority = priority
        end
    end)

    return bestRecord, bestD2
end

local function relationshipValue(record, key)
    local rel = record.relationshipToPlayer or {}
    return tonumber(rel[key] or 0) or 0
end

local function relationshipPolicy(record)
    if LWN.Social and LWN.Social.relationshipCombatPolicy then
        return LWN.Social.relationshipCombatPolicy(record)
    end
    return {
        state = "unknown",
        reason = "social_missing",
    }
end

local function relationshipPolicySummary(record, policy)
    if LWN.Social and LWN.Social.combatPolicySummary then
        return LWN.Social.combatPolicySummary(record, policy)
    end
    policy = policy or relationshipPolicy(record)
    return string.format("%s/%s", tostring(policy.state), tostring(policy.reason))
end

local function syncRecordCarrier(record, player, source)
    if not record or not record.embodiment or record.embodiment.state ~= "embodied" then
        return false, "record_not_embodied"
    end
    if not (LWN.EmbodimentManager and LWN.EmbodimentManager.getCarrierHandle) then
        return false, "carrier_handle_missing"
    end

    local handle = LWN.EmbodimentManager.getCarrierHandle(record)
    if not handle then
        return false, "carrier_handle=nil"
    end
    if not (LWN.CarrierAdapter and LWN.CarrierAdapter.sync) then
        return false, "carrier_sync_missing"
    end

    local result = LWN.CarrierAdapter.sync(record, handle, {
        mode = "full",
        player = player,
        source = source or "DebugTools",
    }) or {}

    if result.ok == false then
        return false, result.detail or "carrier_sync_failed"
    end
    return true, result.detail or "carrier_synced"
end

local function safeSize(list)
    if not list then return 0 end
    if list.size then
        local ok, v = pcall(list.size, list)
        if ok and type(v) == "number" then return v end
    end
    return 0
end

local function actorDebugLine(actor)
    if not actor then
        return "actor=nil"
    end

    local modData = actor.getModData and actor:getModData() or nil
    local presentation = LWN.ActorFactory and LWN.ActorFactory.getPresentationState and LWN.ActorFactory.getPresentationState(actor) or nil
    local visual = protectedCall(actor, "getHumanVisual")
    local itemVisuals = protectedCall(actor, "getItemVisuals")
    local wornItems = protectedCall(actor, "getWornItems")
    local path2 = protectedCall(actor, "getPath2")

    return string.format(
        "actor=%s kind=%s shell=%s session=%s world=%s ghost=%s invisible=%s culled=%s x=%.1f y=%.1f z=%.1f role=%s skin=%s itemVisuals=%d wornItems=%d policy=%s stance=%s shellMode=%s safety=%s moveSupp=%s moving=%s path2=%s allowMove=%s autoMove=%s audioHint=%s audioHuman=%s posture=%s illusion=%s testLabel=%s hold=%s quarantine=%s cmdMove=%s attackLock=%s lock=%s humanInit=%s humanProfile=%s maintMode=%s drift=%s appearanceDiff=%s",
        tostring(actor:getObjectName()),
        tostring(modData and modData.LWN_ActorKind or "unknown"),
        tostring(modData and modData.LWN_ShellMarker or (modData and modData.LWN_NpcId and ("isozombie:" .. tostring(modData.LWN_NpcId)) or "none")),
        tostring(modData and modData.LWN_SessionId or "none"),
        tostring(actor.isExistInTheWorld and actor:isExistInTheWorld() or nil),
        tostring(actor.isGhostMode and actor:isGhostMode() or nil),
        tostring(actor.isInvisible and actor:isInvisible() or nil),
        tostring(actor.isSceneCulled and actor:isSceneCulled() or nil),
        tonumber(actor:getX() or 0) or 0,
        tonumber(actor:getY() or 0) or 0,
        tonumber(actor:getZ() or 0) or 0,
        tostring(presentation and presentation.presentationRole or "unknown"),
        tostring(visual and protectedCall(visual, "getSkinTexture") or "none"),
        safeSize(itemVisuals),
        safeSize(wornItems),
        tostring(modData and (modData.LWN_RelationshipPolicySummary or modData.LWN_RelationState) or "unknown"),
        tostring(modData and modData.LWN_CarrierCombatMode or "unknown"),
        tostring(modData and modData.LWN_ShellMode or "unknown"),
        tostring(modData and modData.LWN_FriendlySuppression or "unknown"),
        tostring(modData and modData.LWN_MovementSuppression or "unknown"),
        tostring(protectedCall(actor, "isMoving")),
        tostring(path2 ~= nil),
        tostring(modData and modData.LWN_AllowMovement or false),
        tostring(modData and modData.LWN_AllowAutonomousMovement or false),
        tostring(modData and modData.LWN_AudioLeakHint or "none"),
        tostring(modData and modData.LWN_AudioHumanization or "none"),
        tostring(modData and modData.LWN_PostureHumanization or "none"),
        tostring(modData and modData.LWN_PersistentIllusionPackage or "none"),
        tostring(modData and modData.LWN_TestHarnessLabel or "none"),
        tostring(modData and modData.LWN_TestHarnessHoldPosition or false),
        tostring(modData and modData.LWN_TestHarnessQuarantine or false),
        tostring(modData and modData.LWN_TestHarnessAllowCommandMovement or false),
        tostring(modData and modData.LWN_AttackQuarantineUntil or "none"),
        tostring(modData and modData.LWN_TestHarnessIdentityLock or false),
        tostring(modData and modData.LWN_HumanizationInitialApplied or modData and modData.LWN_InitialHumanizationApplied or false),
        tostring(modData and (modData.LWN_HumanizationProfile or modData.LWN_InitialHumanizationProfile or modData.LWN_MaintenanceHumanizationProfile) or "none"),
        tostring(modData and (modData.LWN_HumanizationMaintenanceMode or modData.LWN_MaintenanceHumanizationMode) or "none"),
        tostring(modData and modData.LWN_HumanizationDriftCount or 0),
        tostring(modData and modData.LWN_AppearanceDiffSummary or "none")
    )
end

local function summarizePlan(plan, limit)
    if type(plan) ~= "table" or #plan == 0 then
        return "none"
    end
    local maxItems = limit or 8
    local out = {}
    local repeatKind = nil
    local repeatCount = 0

    local function flushRepeat()
        if not repeatKind then return end
        if repeatCount > 1 then
            out[#out + 1] = string.format("%s×%d", tostring(repeatKind), repeatCount)
        else
            out[#out + 1] = tostring(repeatKind)
        end
        repeatKind = nil
        repeatCount = 0
    end

    for i = 1, #plan do
        local kind = tostring(plan[i])
        if repeatKind == nil then
            repeatKind = kind
            repeatCount = 1
        elseif repeatKind == kind then
            repeatCount = repeatCount + 1
        else
            flushRepeat()
            repeatKind = kind
            repeatCount = 1
        end
        if #out >= maxItems then break end
    end
    flushRepeat()
    if #plan > maxItems then
        out[#out + 1] = string.format("...+%d", #plan - maxItems)
    end
    return table.concat(out, ",")
end

local function cachedHybridDebugLine(actor)
    local modData = protectedCall(actor, "getModData")
    if not modData then
        return nil
    end

    return modData.LWN_HybridDebugLine
        or modData.LWN_HybridSummary
        or modData.LWN_HybridAppearanceDebugLine
        or nil
end

local function hybridDebugLine(record, actor)
    local cached = cachedHybridDebugLine(actor)
    if LWN.ActorFactory and LWN.ActorFactory.hybridSummaryLine then
        local descriptor = protectedCall(actor, "getDescriptor")
        local ok, line = pcall(LWN.ActorFactory.hybridSummaryLine, record, actor, descriptor)
        if ok and line then
            return line
        end
    end
    return cached
end

local function dumpRecordSummary(record, actor, player)
    if not record then
        sayInfo(player, "No NPC record to dump")
        return false
    end

    local currentIntent = record.goals and record.goals.currentIntent or nil
    local currentPlan = record.goals and record.goals.currentPlan or {}
    local policy = relationshipPolicy(record)
    local command = record.companion and record.companion.command or {}
    local destination = command.destination or {}
    local speechLine = string.format(
        "NPC %s %s %s",
        tostring(record.id),
        tostring(record.embodiment and record.embodiment.state or "unknown"),
        relationshipPolicySummary(record, policy)
    )
    local summary = string.format(
        "NPC %s %s state=%s policy=%s goal=%s intent=%s",
        tostring(record.id),
        tostring(record.identity and record.identity.firstName or "Unknown"),
        tostring(record.embodiment and record.embodiment.state or "unknown"),
        relationshipPolicySummary(record, policy),
        tostring(record.goals and record.goals.longTerm and record.goals.longTerm.kind or "idle"),
        tostring(currentIntent or "none")
    )
    local hybridLine = hybridDebugLine(record, actor)

    sayInfo(player, speechLine)
    if hybridLine then
        sayInfo(player, hybridLine)
    end
    print("[LWN][Debug] npc summary :: " .. summary)
    print("[LWN][Debug] npc hybrid :: " .. tostring(hybridLine or "HYBRID unavailable"))
    print(string.format(
        "[LWN][Debug] npc relations :: trust=%.2f respect=%.2f fear=%.2f resentment=%.2f loyaltyShift=%.2f",
        relationshipValue(record, "trust"),
        relationshipValue(record, "respect"),
        relationshipValue(record, "fear"),
        relationshipValue(record, "resentment"),
        relationshipValue(record, "loyaltyShift")
    ))
    print(string.format(
        "[LWN][Debug] npc stats :: hunger=%.2f thirst=%.2f fatigue=%.2f panic=%.2f health=%.2f role=%s story=%s clueCount=%s memories=%d",
        tonumber(record.stats and record.stats.hunger or 0) or 0,
        tonumber(record.stats and record.stats.thirst or 0) or 0,
        tonumber(record.stats and record.stats.fatigue or 0) or 0,
        tonumber(record.stats and record.stats.panic or 0) or 0,
        tonumber(record.stats and record.stats.health or 0) or 0,
        tostring(record.companion and record.companion.squadRole or "none"),
        tostring(record.storyArc and record.storyArc.type or "none"),
        tostring(record.storyArc and record.storyArc.clueCount or 0),
        #(record.memories or {})
    ))
    local meta = Store.getEmbodiedMeta and Store.getEmbodiedMeta(record.id) or nil
    local debugState = record.embodiment and record.embodiment.debug or nil
    local illusion = record.embodiment and record.embodiment.illusion or nil
    print("[LWN][Debug] npc actionQueue :: " .. summarizePlan(currentPlan, 10))
    print("[LWN][Debug] npc actor :: " .. actorDebugLine(actor))
    print(string.format(
        "[LWN][Debug] npc identity :: npcId=%s embodiedState=%s carrier=%s actorKind=%s shell=%s session=%s metaState=%s metaXYZ=%s/%s/%s",
        tostring(record.id),
        tostring(record.embodiment and record.embodiment.state or "unknown"),
        tostring(record.embodiment and record.embodiment.carrierKind or "unknown"),
        tostring(actor and actor.getModData and actor:getModData() and actor:getModData().LWN_ActorKind or "unknown"),
        tostring(actor and actor.getModData and actor:getModData() and actor:getModData().LWN_ShellMarker or "none"),
        tostring(actor and actor.getModData and actor:getModData() and actor:getModData().LWN_SessionId or "none"),
        tostring(meta and meta.state or "nil"),
        tostring(meta and meta.x or "nil"),
        tostring(meta and meta.y or "nil"),
        tostring(meta and meta.z or "nil")
    ))
    print(string.format(
        "[LWN][Debug] npc decision :: source=%s utility=%s behavior=%s chosen=%s neutralized=%s queueBefore=%s tickHour=%s",
        tostring(debugState and debugState.source or "nil"),
        tostring(debugState and debugState.utility or "nil"),
        tostring(debugState and debugState.behavior or "nil"),
        tostring(debugState and debugState.chosen or "nil"),
        tostring(debugState and debugState.neutralized or "nil"),
        tostring(debugState and debugState.queueBefore or "nil"),
        tostring(debugState and debugState.worldAgeHours or "nil")
    ))
    print(string.format(
        "[LWN][Debug] npc appearance :: diff=%s source=%s at=%s sig=%s",
        tostring(actor and actor.getModData and actor:getModData() and actor:getModData().LWN_AppearanceDiffSummary or "none"),
        tostring(actor and actor.getModData and actor:getModData() and actor:getModData().LWN_AppearanceDiffSource or "none"),
        tostring(actor and actor.getModData and actor:getModData() and actor:getModData().LWN_AppearanceDiffAt or "none"),
        tostring(actor and actor.getModData and actor:getModData() and actor:getModData().LWN_AppearanceSignature or "none")
    ))
    print(string.format(
        "[LWN][Debug] npc humanization :: initialApplied=%s initialAt=%s initialProfile=%s initialSig=%s maintenanceAt=%s maintenanceSource=%s maintenanceProfile=%s maintenanceMode=%s driftCount=%s lastDriftAt=%s lastDriftReason=%s lastKnownSig=%s lockedSig=%s",
        tostring(illusion and illusion.initialApplied or "nil"),
        tostring(illusion and illusion.initialAppliedAt or "nil"),
        tostring(illusion and illusion.initialProfile or "nil"),
        tostring(illusion and illusion.initialAppearanceSignature or "nil"),
        tostring(illusion and illusion.lastMaintenanceAt or "nil"),
        tostring(illusion and illusion.lastMaintenanceSource or "nil"),
        tostring(illusion and illusion.lastMaintenanceProfile or "nil"),
        tostring(illusion and illusion.lastMaintenanceMode or "nil"),
        tostring(illusion and illusion.driftCount or 0),
        tostring(illusion and illusion.lastDriftAt or "nil"),
        tostring(illusion and illusion.lastDriftReason or "nil"),
        tostring(illusion and illusion.lastKnownAppearanceSignature or "nil"),
        tostring(illusion and illusion.lockedAppearanceSignature or "nil")
    ))
    print(string.format(
        "[LWN][Debug] npc testHarness :: enabled=%s label=%s hold=%s quarantine=%s forceFriendly=%s identityLock=%s sterileRadius=%s attackLockUntil=%s attackLockReason=%s",
        tostring(record.debugHarness and record.debugHarness.enabled or false),
        tostring(record.debugHarness and record.debugHarness.label or "nil"),
        tostring(record.debugHarness and record.debugHarness.holdPosition or false),
        tostring(record.debugHarness and record.debugHarness.quarantine or false),
        tostring(record.debugHarness and record.debugHarness.forceFriendly or false),
        tostring(record.debugHarness and record.debugHarness.identityLock or false),
        tostring(record.debugHarness and record.debugHarness.sterileRadius or "nil"),
        tostring(record.embodiment and record.embodiment.attackQuarantineUntilHour or "nil"),
        tostring(record.embodiment and record.embodiment.lastAttackQuarantineReason or "nil")
    ))
    print(string.format(
        "[LWN][Debug] npc command :: kind=%s status=%s source=%s dest=%s,%s,%s label=%s issuedAt=%s startedAt=%s completedAt=%s outcome=%s reason=%s distance=%s",
        tostring(command.kind or "nil"),
        tostring(command.status or "nil"),
        tostring(command.source or "nil"),
        tostring(destination.x or "nil"),
        tostring(destination.y or "nil"),
        tostring(destination.z or "nil"),
        tostring(destination.label or "nil"),
        tostring(command.issuedAt or "nil"),
        tostring(command.startedAt or "nil"),
        tostring(command.completedAt or "nil"),
        tostring(command.lastOutcome or "nil"),
        tostring(command.lastReason or "nil"),
        tostring(command.lastDistance or "nil")
    ))
    print("[LWN][Debug] npc move_summary :: " .. movementSummaryLine(record, actor))
    print("[LWN][Debug] npc recovery_summary :: " .. recoverySummaryLine(record, actor))
    return true
end

local function tweakRelationshipField(record, field, delta)
    record.relationshipToPlayer = record.relationshipToPlayer or {}
    local rel = record.relationshipToPlayer

    if field == "trust" and LWN.Social and LWN.Social.adjustTrust then
        LWN.Social.adjustTrust(record, delta, "debug_trust")
        return rel.trust
    end
    if field == "resentment" and LWN.Social and LWN.Social.adjustResentment then
        LWN.Social.adjustResentment(record, delta, "debug_resentment")
        return rel.resentment
    end

    local minValue, maxValue = -1, 1
    if field == "fear" then
        minValue, maxValue = 0, 1.5
    elseif field == "respect" or field == "attachment" or field == "debt" then
        minValue, maxValue = -1, 1.5
    elseif field == "loyaltyShift" then
        minValue, maxValue = -1.5, 1.5
    end

    rel[field] = clamp((rel[field] or 0) + delta, minValue, maxValue)
    return rel[field]
end

local function sayActorLine(record, line)
    local actor = findActorForRecord(record)
    if actor and actor.Say then
        actor:Say(line)
    end
end

local function makeRoomForDebugSpawn(player)
    local countEmbodied = Store.countEmbodied and Store.countEmbodied() or 0
    local maxEmbodied = LWN.Config and LWN.Config.Population and LWN.Config.Population.MaxEmbodied or 0
    if countEmbodied < maxEmbodied then
        return true, nil
    end

    local victim = chooseEmbodiedDebugVictim(player)
    if not victim then
        return false, "max_embodied_no_debug_victim"
    end

    if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
        LWN.EmbodimentManager.canonicalCleanup(victim, {
            reason = "debug_make_room",
            detail = "max_embodied_debug_spawn",
        })
    end
    print("[LWN][Debug] Freed embodied slot by removing debug NPC " .. tostring(victim.id))
    return true, victim.id
end

function DebugTools.isEnabled()
    return ensureDebugState().devToolsEnabled == true
end

function DebugTools.setEnabled(enabled)
    ensureDebugState().devToolsEnabled = enabled == true
    return ensureDebugState().devToolsEnabled
end

function DebugTools.toggleEnabled()
    local state = ensureDebugState()
    state.devToolsEnabled = not (state.devToolsEnabled == true)
    return state.devToolsEnabled
end

local function spawnOneNearPlayerWithCarrier(player, carrierKind, options)
    if not player then return nil end

    local roomOk, roomDetail = makeRoomForDebugSpawn(player)
    if not roomOk then
        sayInfo(player, string.format("Spawn blocked: %s", tostring(roomDetail)))
        return nil
    elseif roomDetail then
        sayInfo(player, string.format("Freed debug slot by removing %s", tostring(roomDetail)))
    end

    local id = Store.nextNpcId()
    local seed = ZombRand(1, 2147483646)
    local record = LWN.Schema.newNPCRecord(id, seed)

    randomizeIdentity(record)
    applyDebugHarnessDefaults(record, carrierKind)
    applyDebugHarnessOverrides(record, options and options.harness or nil)
    ensureMinimalDummyState(record)
    record.identity.profession = "unemployed"
    record.backstory.formerProfession = record.identity.profession
    record.anchor.x = math.floor(player:getX()) + ZombRand(-2, 3)
    record.anchor.y = math.floor(player:getY()) + ZombRand(-2, 3)
    record.anchor.z = math.floor(player:getZ())
    record.debugSpawnOnly = true
    record.embodiment.state = "eligible"
    record.embodiment.cooldownUntilHour = worldAgeHours()
    record.embodiment.preferredCarrierKind = carrierKind or "isoplayer"
    record.embodiment.carrierKind = carrierKind or "isoplayer"

    local sterileRadius = tonumber(record.debugHarness and record.debugHarness.sterileRadius or 0) or 0
    if sterileRadius > 0 then
        local removedBefore = clearNearbyWorldNoise(player, sterileRadius, nil)
        if removedBefore > 0 then
            sayInfo(player, string.format("Sterile lane cleared: removed %d nearby world objects", removedBefore))
        end
    end

    Store.addNPC(record)

    local actor = LWN.EmbodimentManager.tryEmbody(record, player)
    if actor then
        if sterileRadius > 0 then
            local removedAfter = clearNearbyWorldNoise(player, sterileRadius, record.id)
            if removedAfter > 0 then
                sayInfo(player, string.format("Post-spawn sterile cleanup: removed %d nearby objects", removedAfter))
            end
        end
        local actorModData = actor.getModData and actor:getModData() or nil
        if actorModData then
            actorModData.LWN_TestHarnessLabel = record.debugHarness and record.debugHarness.label or nil
            actorModData.LWN_TestHarnessSterileRadius = sterileRadius
            actorModData.LWN_TestHarnessIdentityLock = record.debugHarness and record.debugHarness.identityLock == true or false
            actorModData.LWN_TestHarnessHoldPosition = record.debugHarness and record.debugHarness.holdPosition == true or false
            actorModData.LWN_TestHarnessAllowCommandMovement = record.debugHarness and record.debugHarness.allowCommandMovement ~= false or false
            actorModData.LWN_DummyEnabled = true
            actorModData.LWN_DummyMode = record.dummy and record.dummy.mode or "minimal_neutral_dummy"
            actorModData.LWN_DummyState = record.dummy and record.dummy.state or "spawn_pending"
            actorModData.LWN_DummyGenerationId = record.dummy and record.dummy.generationId or 1
        end
        sayInfo(player, string.format("Spawned minimal dummy %s via %s", record.id, tostring(record.embodiment and record.embodiment.carrierKind or carrierKind)))
    else
        local handle = LWN.EmbodimentManager and LWN.EmbodimentManager.getCarrierHandle and LWN.EmbodimentManager.getCarrierHandle(record) or nil
        local handleDetail = handle and handle.detail or nil
        local failure = LWN.ActorFactory and LWN.ActorFactory.getLastFailure and LWN.ActorFactory.getLastFailure() or nil
        if handleDetail then
            sayInfo(player, string.format("Spawn failed for %s via %s: %s", record.id, tostring(carrierKind), tostring(handleDetail)))
        elseif failure and failure.npcId == record.id then
            sayInfo(player, string.format("Spawn failed for %s; see console for ActorFactory failure details", record.id))
        else
            local reason = record.embodiment and record.embodiment.lastFailureReason or "unknown"
            local detail = record.embodiment and record.embodiment.lastFailureDetail or ""
            sayInfo(player, string.format("Spawn blocked for %s via %s: %s %s", record.id, tostring(carrierKind), tostring(reason), tostring(detail)))
        end
    end
    return record, actor
end

function DebugTools.spawnOneNearPlayer(player)
    return spawnOneNearPlayerWithCarrier(player, "isoplayer")
end

function DebugTools.spawnOneNearPlayerIsoSurvivor(player)
    return spawnOneNearPlayerWithCarrier(player, "isosurvivor")
end

function DebugTools.spawnOneNearPlayerIsoZombie(player)
    return spawnOneNearPlayerWithCarrier(player, "isozombie")
end

local function resetAutomation(player, reason)
    local state = automationState()
    state.active = false
    state.scenario = nil
    state.phase = nil
    state.npcId = nil
    state.destination = nil
    state.startedAt = nil
    state.updatedAt = worldAgeHours()
    state.step = 0
    if player and reason then
        sayInfo(player, string.format("TEST RESET (%s)", tostring(reason)))
    end
    return state
end

local function collectDebugHarnessRecords()
    local records = {}
    Store.eachNPC(function(record)
        if Store.isAlive(record) == true
            and record.debugSpawnOnly == true
            and record.debugHarness
            and record.debugHarness.enabled == true
        then
            records[#records + 1] = record
        end
    end)
    return records
end

local function purgeRogueDebugHarnessShells(player, radius)
    if not player then return 0 end
    local cell = getCell and getCell() or nil
    local square = protectedCall(player, "getSquare")
    if not cell or not square then return 0 end

    local cx = protectedCall(square, "getX") or math.floor(player:getX())
    local cy = protectedCall(square, "getY") or math.floor(player:getY())
    local cz = protectedCall(square, "getZ") or math.floor(player:getZ())
    local searchRadius = tonumber(radius) or 18
    local removed = 0
    local seen = {}

    local function hasHarnessMarker(obj)
        local modData = obj and obj.getModData and obj:getModData() or nil
        if not modData then return false end
        return modData.LWN_TestHarnessLabel ~= nil
            or (type(modData.LWN_ShellMarker) == "string"
                and string.find(modData.LWN_ShellMarker, "isozombie:", 1, true) == 1
                and modData.LWN_CarrierSpike == true)
    end

    local function maybeRemove(obj)
        if not obj or seen[obj] then return end
        seen[obj] = true
        if not hasHarnessMarker(obj) then return end
        if LWN.ActorFactory and LWN.ActorFactory.cleanupActor and LWN.ActorFactory.hasRuntimeCore and LWN.ActorFactory.hasRuntimeCore(obj) then
            LWN.ActorFactory.cleanupActor(obj, "debug_test_clean_slate")
        else
            protectedCall(obj, "removeFromSquare")
            protectedCall(obj, "removeFromWorld")
        end
        removed = removed + 1
    end

    for y = cy - searchRadius, cy + searchRadius do
        for x = cx - searchRadius, cx + searchRadius do
            local scanSquare = cell:getGridSquare(x, y, cz)
            if scanSquare then
                local moving = protectedCall(scanSquare, "getMovingObjects")
                if moving and moving.size then
                    for i = moving:size() - 1, 0, -1 do
                        maybeRemove(moving:get(i))
                    end
                end
                local staticMoving = protectedCall(scanSquare, "getStaticMovingObjects")
                if staticMoving and staticMoving.size then
                    for i = staticMoving:size() - 1, 0, -1 do
                        maybeRemove(staticMoving:get(i))
                    end
                end
            end
        end
    end

    return removed
end

local function prepareAutomationCleanSlate(player, reason)
    local cleanedRecords = 0
    local records = collectDebugHarnessRecords()
    for i = 1, #records do
        local record = records[i]
        local actor = findActorForRecord(record)
        if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
            LWN.EmbodimentManager.canonicalCleanup(record, {
                actor = actor,
                removeRecord = true,
                blockNpcId = false,
                reason = reason or "debug_test_clean_slate",
                detail = "remove_existing_debug_harness_records",
            })
            cleanedRecords = cleanedRecords + 1
        end
    end

    local removedShells = purgeRogueDebugHarnessShells(player, math.max(18, tonumber(debugConfig("DebugSterileRadiusTiles", 8)) or 8))
    resetAutomation(nil, reason or "clean_slate")
    if player then
        sayInfo(player, string.format("TEST CLEAN SLATE records=%d shells=%d", cleanedRecords, removedShells))
    end
    return cleanedRecords, removedShells
end

local function getAutomationRecord()
    local state = automationState()
    if not state.npcId then return nil, state end
    local record = Store.getNPC and Store.getNPC(state.npcId) or nil
    return record, state
end

local function setAutomationDestination(state, destination)
    if not state then return end
    if not destination then
        state.destination = nil
        return
    end
    state.destination = {
        x = destination.x,
        y = destination.y,
        z = destination.z,
        label = destination.label,
    }
end

local function dumpMovementAudioForRecord(record, player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    local actor = findActorForRecord(record)
    local modData = actor and actor.getModData and actor:getModData() or nil
    local debugState = record.embodiment and record.embodiment.debug or nil
    local currentPlan = record.goals and record.goals.currentPlan or {}
    local command = record.companion and record.companion.command or {}
    local destination = command.destination or {}
    local line = string.format(
        "MOVE/AUDIO %s queue=%s source=%s util=%s behavior=%s chosen=%s neutralized=%s moving=%s path2=%s shell=%s cmd=%s cmdStatus=%s dest=%s,%s,%s cmdLabel=%s supp=%s audio=%s humanize=%s posture=%s illusion=%s testLabel=%s hold=%s quarantine=%s attackLock=%s lock=%s init=%s profile=%s maint=%s drift=%s",
        tostring(record.id),
        summarizePlan(currentPlan, 8),
        tostring(debugState and debugState.source or "nil"),
        tostring(debugState and debugState.utility or "nil"),
        tostring(debugState and debugState.behavior or "nil"),
        tostring(debugState and debugState.chosen or "nil"),
        tostring(debugState and debugState.neutralized or "nil"),
        tostring(actor and protectedCall(actor, "isMoving") or nil),
        tostring(actor and protectedCall(actor, "getPath2") ~= nil or nil),
        tostring(modData and modData.LWN_ShellMode or modData and modData.LWN_CarrierCombatMode or "none"),
        tostring(command.kind or "none"),
        tostring(command.status or "idle"),
        tostring(destination.x or "nil"),
        tostring(destination.y or "nil"),
        tostring(destination.z or "nil"),
        tostring(destination.label or "nil"),
        tostring(modData and modData.LWN_MovementSuppression or "none"),
        tostring(modData and modData.LWN_AudioLeakHint or "none"),
        tostring(modData and modData.LWN_AudioHumanization or "none"),
        tostring(modData and modData.LWN_PostureHumanization or "none"),
        tostring(modData and modData.LWN_PersistentIllusionPackage or "none"),
        tostring(modData and modData.LWN_TestHarnessLabel or "none"),
        tostring(modData and modData.LWN_TestHarnessHoldPosition or false),
        tostring(modData and modData.LWN_TestHarnessQuarantine or false),
        tostring(modData and modData.LWN_AttackQuarantineUntil or "none"),
        tostring(modData and modData.LWN_TestHarnessIdentityLock or false),
        tostring(modData and (modData.LWN_HumanizationInitialApplied or modData.LWN_InitialHumanizationApplied) or false),
        tostring(modData and (modData.LWN_HumanizationProfile or modData.LWN_InitialHumanizationProfile or modData.LWN_MaintenanceHumanizationProfile) or "none"),
        tostring(modData and (modData.LWN_HumanizationMaintenanceMode or modData.LWN_MaintenanceHumanizationMode) or "none"),
        tostring(modData and modData.LWN_HumanizationDriftCount or 0)
    )
    sayInfo(player, line)
    print("[LWN][Debug] npc movement_audio :: " .. line)
    return true
end

local function forceRelationshipCombatPolicyForRecord(record, targetState, player, options)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end
    if not (LWN.Social and LWN.Social.forceRelationshipCombatPolicy) then
        sayInfo(player, "Policy forcing unavailable")
        return false
    end

    local harness = record.debugHarness or nil
    local originalAllowForcedHostile = harness and harness.allowForcedHostile or nil
    if targetState == "hostile"
        and harness
        and harness.enabled == true
        and harness.quarantine == true
        and harness.allowForcedHostile ~= true
        and not (options and options.allowHostileOverride == true)
    then
        sayInfo(player, string.format("%s hostile force blocked by quarantine", tostring(record.id)))
        return false
    end

    if targetState == "hostile" and harness and options and options.allowHostileOverride == true then
        harness.allowForcedHostile = true
    end

    local policy, err = LWN.Social.forceRelationshipCombatPolicy(
        record,
        targetState,
        options and options.reason or ("debug_force_policy_" .. tostring(targetState))
    )

    if harness then
        harness.allowForcedHostile = originalAllowForcedHostile
    end

    if not policy then
        sayInfo(player, string.format("Force %s failed (%s)", tostring(targetState), tostring(err)))
        return false
    end

    local syncOk, syncDetail = syncRecordCarrier(record, player, options and options.source or "DebugTools.forceRelationshipCombatPolicy")
    if syncOk ~= true and syncDetail ~= "record_not_embodied" and syncDetail ~= "carrier_handle=nil" then
        print("[LWN][Debug] forced policy sync skipped :: " .. tostring(syncDetail))
    end

    sayInfo(player, string.format("%s -> %s", tostring(record.id), relationshipPolicySummary(record, policy)))
    return true, record, policy
end

local function chooseDesignatedTestDestination(player, actor)
    local cell = getCell and getCell() or nil
    if not player or not actor or not cell then
        return nil
    end

    local px = math.floor(protectedCall(player, "getX") or 0)
    local py = math.floor(protectedCall(player, "getY") or 0)
    local pz = math.floor(protectedCall(player, "getZ") or 0)
    local ax = tonumber(protectedCall(actor, "getX") or px) or px
    local ay = tonumber(protectedCall(actor, "getY") or py) or py
    local candidates = {
        { x = px + 6, y = py, z = pz, label = "TEST EAST 6" },
        { x = px - 6, y = py, z = pz, label = "TEST WEST 6" },
        { x = px, y = py + 6, z = pz, label = "TEST SOUTH 6" },
        { x = px, y = py - 6, z = pz, label = "TEST NORTH 6" },
    }

    local best = nil
    local bestD2 = -1
    for i = 1, #candidates do
        local candidate = candidates[i]
        if cell:getGridSquare(candidate.x, candidate.y, candidate.z) then
            local dx = candidate.x - ax
            local dy = candidate.y - ay
            local d2 = dx * dx + dy * dy
            if d2 > bestD2 then
                best = candidate
                bestD2 = d2
            end
        end
    end

    return best
end

local function issueDesignatedMoveCommand(record, player, options)
    if not record then
        sayInfo(player, "No dummy found")
        return false
    end

    ensureMinimalDummyState(record)
    local actor = findActorForRecord(record)
    if not actor then
        sayInfo(player, string.format("Dummy %s has no live actor", tostring(record.id)))
        return false
    end

    local destination = options and options.destination or chooseDesignatedTestDestination(player, actor)
    if not destination then
        sayInfo(player, string.format("Dummy %s has no test destination", tostring(record.id)))
        return false
    end

    if record.debugHarness then
        record.debugHarness.allowCommandMovement = true
        record.debugHarness.quarantine = false
        record.debugHarness.holdPosition = false
        record.embodiment = record.embodiment or {}
        record.embodiment.debug = record.embodiment.debug or {}
        record.embodiment.debug.commandHoldReleasedAt = worldAgeHours()
        record.embodiment.debug.commandHoldReleaseSource = options and options.commandSource or "DebugTools.issueDesignatedMoveCommand"
        local modData = actor and actor.getModData and actor:getModData() or nil
        if modData then
            modData.LWN_TestHarnessHoldPosition = false
            modData.LWN_TestHarnessQuarantine = false
            modData.LWN_TestHarnessAllowCommandMovement = true
            modData.LWN_CommandHoldReleasedAt = worldAgeHours()
            modData.LWN_CommandHoldReleaseSource = options and options.commandSource or "DebugTools.issueDesignatedMoveCommand"
        end
        actor = findActorForRecord(record) or actor
    end

    local intent = LWN.ActionIntents.moveTo(record, destination.x, destination.y, destination.z, {
        commandKind = "designated_location",
        commandSource = options and options.commandSource or "debug_tools",
        commandReason = options and options.commandReason or "debug_designated_move",
        destinationLabel = destination.label,
    })

    local issued = false
    if LWN.ActionRuntime and LWN.ActionRuntime.replaceWithIntent then
        issued = LWN.ActionRuntime.replaceWithIntent(record, actor, intent) == true
    else
        LWN.ActionRuntime.clear(record, actor)
        issued = LWN.ActionRuntime.enqueue(record, intent) == true
    end

    if issued ~= true then
        sayInfo(player, string.format("Move command not queued for %s", tostring(record.id)))
        return false
    end

    if record.dummy then
        record.dummy.state = "move_to"
        record.dummy.command = {
            kind = "move_to",
            destination = destination,
            issuedAt = worldAgeHours(),
        }
    end

    sayInfo(player, string.format(
        "MOVE CMD %s -> %s (%s,%s,%s)",
        tostring(record.id),
        tostring(destination.label),
        tostring(destination.x),
        tostring(destination.y),
        tostring(destination.z)
    ))
    return true, record, destination
end

local function runMovementAutomationTest01(player)
    prepareAutomationCleanSlate(player, "automation_test_start")
    local record, actor = spawnOneNearPlayerWithCarrier(player, "isozombie", {
        harness = {
            forceFriendly = false,
            holdPosition = true,
            quarantine = false,
            allowCommandMovement = true,
            mode = "minimal_dummy",
        },
    })
    if not record then
        sayInfo(player, "TEST 01 failed: spawn failed")
        return false
    end

    local state = automationState()
    state.active = true
    state.scenario = "minimal_dummy_move_return_v1"
    state.phase = "test_02_ready"
    state.npcId = record.id
    state.destination = nil
    state.startedAt = worldAgeHours()
    state.updatedAt = state.startedAt
    state.step = 1

    dumpRecordSummary(record, actor or findActorForRecord(record), player)
    dumpMovementAudioForRecord(record, player)
    dumpAutomationOneLineSummary(record, actor or findActorForRecord(record), player, "TEST 01 SUMMARY")

    sayChecklist(player, "TEST 01 CHECK", {
        "Look: only ONE test NPC should exist.",
        "Check: shell lane should read dummy_idle.",
        "Check: canWalk=yes and useless=no in the summary.",
        "Check: probeOk=yes and appLock=yes; appFail=yes means visual rebuild still failed.",
        "Look: same face, hair, and clothes stay stable.",
        "Look: idle posture reads human, not feral zombie.",
        "Listen: zombie audio should stay quiet.",
        "Then click TEST 02.",
    })
    return true
end

local function runMovementAutomationTest02(player)
    local record, state = getAutomationRecord()
    if not state.active or state.scenario ~= "minimal_dummy_move_return_v1" then
        sayInfo(player, "No active test. Run TEST 01 first.")
        return false
    end
    if not record then
        sayInfo(player, string.format("Tracked NPC %s missing. Use TEST RESET.", tostring(state.npcId)))
        return false
    end
    if state.phase ~= "test_02_ready" then
        sayInfo(player, string.format("TEST 02 unavailable at phase %s", tostring(state.phase)))
        return false
    end

    local ok, _, destination = issueDesignatedMoveCommand(record, player, {
        commandSource = "automation_test_02",
        commandReason = "automation_designated_walk",
    })
    if ok ~= true then
        return false
    end

    setAutomationDestination(state, destination)
    dumpRecordSummary(record, findActorForRecord(record), player)
    dumpMovementAudioForRecord(record, player)
    dumpAutomationOneLineSummary(record, findActorForRecord(record), player, "TEST 02 SUMMARY")
    state.phase = "test_03_ready"
    state.updatedAt = worldAgeHours()
    state.step = 2
    sayChecklist(player, "TEST 02 CHECK", {
        string.format("Watch: NPC walks to %s.", tostring(destination and destination.label or "TEST MARK")),
        "Check: shell lane should stay dummy_move during movement.",
        "Check: motor should move from started to stepping during actual movement.",
        "Check: totalDelta should rise above 0.00 once the body actually moves.",
        "Check: squareChanged should flip to yes if real displacement happens.",
        "Look: movement/posture should read human, not zombie.",
        "Look: appearance stays stable while walking.",
        "Listen: audio should stay quiet during the walk.",
        "After the walk settles, click TEST 03.",
    })
    return true
end

local function runMovementAutomationTest03(player)
    local record, state = getAutomationRecord()
    if not state.active or state.scenario ~= "minimal_dummy_move_return_v1" then
        sayInfo(player, "No active test. Run TEST 01 first.")
        return false
    end
    if not record then
        sayInfo(player, string.format("Tracked NPC %s missing. Use TEST RESET.", tostring(state.npcId)))
        return false
    end
    if state.phase ~= "test_03_ready" then
        sayInfo(player, string.format("TEST 03 unavailable at phase %s", tostring(state.phase)))
        return false
    end

    dumpRecordSummary(record, findActorForRecord(record), player)
    dumpMovementAudioForRecord(record, player)
    dumpAutomationOneLineSummary(record, findActorForRecord(record), player, "TEST 03 SUMMARY")
    DebugTools.dumpLastActorFailure(player)
    state.phase = "test_04_ready"
    state.updatedAt = worldAgeHours()
    state.step = 3
    sayChecklist(player, "TEST 03 CHECK", {
        "Confirm: destination walk succeeded or failed.",
        "Check: final command status matches what you saw.",
        "Check: motor should end as arrived or stalled.",
        "Check: watchdog should stay NO; if YES, pathing happened without real displacement.",
        "Check: totalDelta and squareChanged tell you whether movement was real or statue-like.",
        "If failed, note whether it was hostile leak, path-only, or watchdog no-displacement.",
        "Now walk far away, then return to this NPC.",
        "After you return, click TEST 04.",
    })
    return true
end

local function runMovementAutomationTest04(player)
    local record, state = getAutomationRecord()
    if not state.active or state.scenario ~= "minimal_dummy_move_return_v1" then
        sayInfo(player, "No active test. Run TEST 01 first.")
        return false
    end
    if not record then
        sayInfo(player, string.format("Tracked NPC %s missing. Use TEST RESET.", tostring(state.npcId)))
        return false
    end
    if state.phase ~= "test_04_ready" then
        sayInfo(player, string.format("TEST 04 unavailable at phase %s", tostring(state.phase)))
        return false
    end

    dumpRecordSummary(record, findActorForRecord(record), player)
    dumpMovementAudioForRecord(record, player)
    dumpAutomationOneLineSummary(record, findActorForRecord(record), player, "TEST 04 SUMMARY")
    DebugTools.dumpNearbyZombieLikeObjects(player)
    DebugTools.dumpLastActorFailure(player)
    state.phase = "complete"
    state.updatedAt = worldAgeHours()
    state.step = 4
    sayChecklist(player, "TEST 04 CHECK", {
        "Look: appearance still matches after return.",
        "Look: posture and movement still read human-ish.",
        "Listen: no fresh zombie audio leak.",
        "Watch: no hostile reversion, lunge, bite, or chase.",
        "Watch: no duplicate replacement shells appear.",
        "Check console: recovery.cached_hit is best-case before nearby scan.",
        "Check console: handle_recovered is okay; replacement_precheck means a new shell path was considered.",
        "Check console: cached_miss + handle_rejected + candidate_missing together means continuity is still broken.",
    })
    return true
end

local function runStandardAutomationContinue(player)
    local _, state = getAutomationRecord()
    if not state.active then
        return runMovementAutomationTest01(player)
    end
    if state.phase == "test_02_ready" then
        return runMovementAutomationTest02(player)
    elseif state.phase == "test_03_ready" then
        return runMovementAutomationTest03(player)
    elseif state.phase == "test_04_ready" then
        return runMovementAutomationTest04(player)
    elseif state.phase == "complete" then
        sayInfo(player, string.format("Test already complete for npc=%s. Use TEST RESET.", tostring(state.npcId)))
        return true
    end

    sayInfo(player, string.format("Unknown test phase %s. Use TEST RESET.", tostring(state.phase)))
    return false
end

function DebugTools.cleanNearbyWorldNoise(player)
    local nearest = findNearestRecord(player)
    local protectedNpcId = nearest and nearest.id or nil
    local removed = clearNearbyWorldNoise(player, tonumber(debugConfig("DebugSterileRadiusTiles", 8)) or 8, protectedNpcId)
    sayInfo(player, string.format("Sterile cleanup removed %d nearby world objects", removed))
    return true, removed
end

function DebugTools.dumpNearbyZombieLikeObjects(player)
    if not player then return false end
    local cell = getCell and getCell() or nil
    local square = protectedCall(player, "getSquare")
    if not cell or not square then
        sayInfo(player, "No world square available")
        return false
    end

    local radius = tonumber(debugConfig("DebugSterileRadiusTiles", 8)) or 8
    local cx = protectedCall(square, "getX") or math.floor(player:getX())
    local cy = protectedCall(square, "getY") or math.floor(player:getY())
    local cz = protectedCall(square, "getZ") or math.floor(player:getZ())
    local lines = {}
    local seen = {}

    local function inspect(obj)
        if not obj or seen[obj] then return end
        seen[obj] = true
        local objectName = tostring(protectedCall(obj, "getObjectName") or "")
        local isZombie = protectedCall(obj, "isZombie") == true
        local isDeadBody = string.find(objectName, "DeadBody", 1, true) ~= nil
        if not isZombie and not isDeadBody then
            return
        end
        local modData = obj.getModData and obj:getModData() or nil
        lines[#lines + 1] = string.format(
            "obj=%s ref=%s managed=%s npcId=%s lastNpcId=%s label=%s x=%.1f y=%.1f z=%.1f cleanupCandidate=%s",
            tostring(objectName ~= "" and objectName or "unknown"),
            tostring(obj),
            tostring(isManagedActor(obj)),
            tostring(modData and modData.LWN_NpcId or nil),
            tostring(modData and modData.LWN_LastNpcId or nil),
            tostring(modData and modData.LWN_TestHarnessLabel or nil),
            tonumber(protectedCall(obj, "getX") or 0) or 0,
            tonumber(protectedCall(obj, "getY") or 0) or 0,
            tonumber(protectedCall(obj, "getZ") or 0) or 0,
            tostring((isZombie and not isManagedActor(obj) and not (modData and (modData.LWN_NpcId or modData.LWN_LastNpcId or modData.LWN_TestHarnessLabel))) or isDeadBody)
        )
    end

    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            local scanSquare = cell:getGridSquare(x, y, cz)
            if scanSquare then
                local moving = protectedCall(scanSquare, "getMovingObjects")
                if moving and moving.size then
                    for i = 0, moving:size() - 1 do
                        inspect(moving:get(i))
                    end
                end
                local staticMoving = protectedCall(scanSquare, "getStaticMovingObjects")
                if staticMoving and staticMoving.size then
                    for i = 0, staticMoving:size() - 1 do
                        inspect(staticMoving:get(i))
                    end
                end
            end
        end
    end

    print(string.format("[LWN][Debug] nearby zombie-like census :: radius=%s count=%s", tostring(radius), tostring(#lines)))
    for i = 1, #lines do
        print("[LWN][Debug] zombie-like :: " .. tostring(lines[i]))
    end
    sayInfo(player, string.format("Nearby zombie-like census dumped (%d objects)", #lines))
    return true, #lines
end

function DebugTools.dumpLastActorFailure(player)
    local failure = LWN.ActorFactory and LWN.ActorFactory.getLastFailure and LWN.ActorFactory.getLastFailure() or nil
    if not failure then
        sayInfo(player, "No recorded actor failure")
        return false
    end

    sayInfo(player, string.format("Last actor failure: %s", tostring(failure.npcId or failure.reason)))
    if LWN.ActorFactory and LWN.ActorFactory.dumpLastFailure then
        LWN.ActorFactory.dumpLastFailure()
    end
    return true
end

function DebugTools.dumpNearestNpcSummary(player)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    return dumpRecordSummary(record, findActorForRecord(record), player)
end

function DebugTools.dumpNearestNpcHybridSummary(player)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    local line = hybridDebugLine(record, findActorForRecord(record))
    sayInfo(player, tostring(line or "HYBRID unavailable"))
    print("[LWN][Debug] npc hybrid :: " .. tostring(line or "HYBRID unavailable"))
    return line ~= nil
end

function DebugTools.dumpNearestNpcMovementAudioState(player)
    local record = findNearestRecord(player)
    return dumpMovementAudioForRecord(record, player)
end

function DebugTools.dumpNpcById(npcId, player)
    if not npcId then return false end
    local record = Store.getNPC(npcId)
    if not record then
        sayInfo(player, string.format("Unknown NPC %s", tostring(npcId)))
        return false
    end

    return dumpRecordSummary(record, findActorForRecord(record), player)
end

function DebugTools.adjustNearestRelationship(player, field, delta)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    local value = tweakRelationshipField(record, field, delta)
    local syncOk, syncDetail = syncRecordCarrier(record, player, "DebugTools.adjustNearestRelationship")
    if syncOk ~= true and syncDetail ~= "record_not_embodied" and syncDetail ~= "carrier_handle=nil" then
        print("[LWN][Debug] relationship sync skipped :: " .. tostring(syncDetail))
    end
    sayInfo(player, string.format(
        "%s %s=%.2f %s",
        tostring(record.id),
        tostring(field),
        tonumber(value or 0) or 0,
        relationshipPolicySummary(record)
    ))
    return true, record
end

function DebugTools.forceNearestRelationshipCombatPolicy(player, targetState)
    local record = findNearestRecord(player)
    return forceRelationshipCombatPolicyForRecord(record, targetState, player, {
        source = "DebugTools.forceRelationshipCombatPolicy",
        reason = "debug_force_policy_" .. tostring(targetState),
    })
end

function DebugTools.commandNearestNpcToDesignatedLocation(player)
    local record = findNearestRecord(player)
    return issueDesignatedMoveCommand(record, player, {
        commandSource = "debug_menu",
        commandReason = "debug_menu_designated_move",
    })
end

function DebugTools.startAutomatedIsoZombieTest(player)
    return runMovementAutomationTest01(player)
end

function DebugTools.continueAutomatedIsoZombieTest(player)
    return runStandardAutomationContinue(player)
end

function DebugTools.runAutomatedIsoZombieTest01(player)
    return runMovementAutomationTest01(player)
end

function DebugTools.runAutomatedIsoZombieTest02(player)
    return runMovementAutomationTest02(player)
end

function DebugTools.runAutomatedIsoZombieTest03(player)
    return runMovementAutomationTest03(player)
end

function DebugTools.runAutomatedIsoZombieTest04(player)
    return runMovementAutomationTest04(player)
end

function DebugTools.resetAutomatedIsoZombieTest(player)
    prepareAutomationCleanSlate(player, "manual_reset")
    return true
end

function DebugTools.dumpAutomatedIsoZombieTestStatus(player)
    local record, state = getAutomationRecord()
    local destination = state.destination or {}
    sayInfo(player, string.format(
        "TEST STATUS scenario=%s phase=%s npcId=%s active=%s dest=%s,%s,%s %s",
        tostring(state.scenario),
        tostring(state.phase),
        tostring(state.npcId),
        tostring(state.active),
        tostring(destination.x or "nil"),
        tostring(destination.y or "nil"),
        tostring(destination.z or "nil"),
        tostring(destination.label or "")
    ))
    if record then
        dumpRecordSummary(record, findActorForRecord(record), player)
        dumpMovementAudioForRecord(record, player)
        return true
    end
    return false
end

function DebugTools.applyStoryBeat(player, beat)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    record.drama = record.drama or {}
    if beat == "shared_food" then
        tweakRelationshipField(record, "trust", 0.20)
        tweakRelationshipField(record, "resentment", -0.10)
        record.stats.hunger = clamp((record.stats.hunger or 0) - 0.15, 0, 1)
        LWN.Memory.add(record, "shared_food", 0.45, { debug = true })
        sayActorLine(record, "That helped. Thanks.")
    elseif beat == "rescued_me" then
        tweakRelationshipField(record, "trust", 0.30)
        tweakRelationshipField(record, "fear", -0.10)
        LWN.Memory.add(record, "rescued_me", 0.60, { debug = true })
        sayActorLine(record, "You pulled me out of that.")
    elseif beat == "promise_broken" then
        tweakRelationshipField(record, "resentment", 0.25)
        record.drama.promiseBroken = true
        LWN.Memory.add(record, "promise_broken", 0.55, { debug = true })
        sayActorLine(record, "You said we'd do this together.")
    elseif beat == "theft_suspected" then
        tweakRelationshipField(record, "resentment", 0.20)
        record.drama.suspectsTheft = true
        LWN.Memory.add(record, "theft_suspected", 0.40, { debug = true })
        sayActorLine(record, "Something is missing.")
    elseif beat == "jealousy" then
        tweakRelationshipField(record, "resentment", 0.15)
        record.drama.jealousy = true
        LWN.Memory.add(record, "jealousy", 0.35, { debug = true })
        sayActorLine(record, "You trust them more than me.")
    else
        sayInfo(player, string.format("Unknown story beat %s", tostring(beat)))
        return false
    end

    sayInfo(player, string.format("Applied beat %s to %s", tostring(beat), tostring(record.id)))
    return true, record
end

function DebugTools.forceLegacyCandidate(player)
    local record = findNearestRecord(player)
    if not record then
        sayInfo(player, "No NPCs found")
        return false
    end

    record.companion = record.companion or {}
    record.companion.recruited = true
    record.companion.squadRole = record.companion.squadRole or "companion"
    record.relationshipToPlayer = record.relationshipToPlayer or {}
    record.relationshipToPlayer.trust = math.max(record.relationshipToPlayer.trust or 0, LWN.Config.Legacy.MinTrust)
    sayInfo(player, string.format("Forced legacy candidate %s", tostring(record.id)))
    return true, record
end

function DebugTools.wipeAndReseed(player)
    local records = {}
    Store.eachNPC(function(record)
        if Store.isAlive(record) then
            records[#records + 1] = record
        end
    end)

    for _, record in ipairs(records) do
        local actor = findActorForRecord(record)
        if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
            LWN.EmbodimentManager.canonicalCleanup(record, {
                actor = actor,
                reason = "debug_wipe",
                detail = "wipeAndReseed",
            })
        elseif actor and LWN.CarrierAdapter and LWN.CarrierAdapter.retire then
            LWN.CarrierAdapter.retire(record, LWN.EmbodimentManager and LWN.EmbodimentManager.getCarrierHandle and LWN.EmbodimentManager.getCarrierHandle(record) or {
                kind = record and record.embodiment and record.embodiment.carrierKind or "isoplayer",
                actor = actor,
                status = "active",
            }, {
                reason = "debug_wipe",
            })
        elseif actor and LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
            LWN.ActorFactory.cleanupActor(actor)
        end
    end

    if LWN.ActionRuntime then
        LWN.ActionRuntime.Queues = {}
    end
    if LWN.EmbodimentManager then
        LWN.EmbodimentManager._actors = {}
        LWN.EmbodimentManager._carrierHandles = {}
        LWN.EmbodimentManager._cleanupBlocklist = {}
        LWN.EmbodimentManager._cleanupInFlight = {}
        LWN.EmbodimentManager._registryTraceCache = {}
        LWN.EmbodimentManager._deathLikeTraceCache = {}
    end

    if ModData and ModData.remove then
        pcall(ModData.remove, LWN.Config.ModDataTag)
    end
    Store.resetRoot()

    if LWN.EventAdapter then
        LWN.EventAdapter._lastPlayerPos = nil
    end

    if player and LWN.PopulationSeeder and LWN.PopulationSeeder.seedNewWorld then
        LWN.PopulationSeeder.seedNewWorld(player, player:getSquare())
    end
    if LWN.WorldStory and LWN.WorldStory.seed then
        LWN.WorldStory.seed()
    end

    sayInfo(player, "Wiped LWN data and reseeded current save")
    return true
end

function DebugTools.deleteNpcById(npcId, player)
    if not npcId then return false end
    local record = Store.getNPC(npcId)
    if not record then return false end

    local actor = findActorForRecord(record)
    if actor and LWN.ActorFactory and LWN.ActorFactory.isActorInCombatOrUnderAttack then
        local inCombat, combatReason = LWN.ActorFactory.isActorInCombatOrUnderAttack(actor)
        if inCombat == true then
            sayInfo(player, string.format("NPC %s is in combat and cannot be deleted (%s)", npcId, tostring(combatReason)))
            return false
        end
    end

    if LWN.EmbodimentManager and LWN.EmbodimentManager.canonicalCleanup then
        LWN.EmbodimentManager.canonicalCleanup(record, {
            actor = actor,
            reason = "debug_delete",
            detail = "deleteNpcById:immediate_noncombat",
        })
    else
        if actor and LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
            LWN.ActorFactory.cleanupActor(actor, "debug_delete")
        end
        Store.removeNPC(npcId)
    end
    sayInfo(player, string.format("Deleted NPC %s", npcId))
    return true
end

function DebugTools.deleteNearestNpc(player)
    if not player then return false end

    local px, py = player:getX(), player:getY()
    local bestId = nil
    local bestD2 = math.huge

    Store.eachNPC(function(record)
        if Store.isAlive(record) ~= true then
            return
        end
        local dx = (record.anchor.x or 0) - px
        local dy = (record.anchor.y or 0) - py
        local d2 = dx * dx + dy * dy
        if d2 < bestD2 then
            bestD2 = d2
            bestId = record.id
        end
    end)

    if not bestId then return false end
    return DebugTools.deleteNpcById(bestId, player)
end

function DebugTools.onKeyPressed(key)
    if not key or not Keyboard then return end

    local player = getPlayer and getPlayer() or nil
    if key == Keyboard.KEY_F3 then
        local after = DebugTools.toggleEnabled()
        sayInfo(player, after and "LWN debug on" or "LWN debug off")
        return
    end

    if not DebugTools.isEnabled() then return end

    if key == Keyboard.KEY_F4 then
        DebugTools.spawnOneNearPlayer(player)
    elseif key == Keyboard.KEY_F5 then
        DebugTools.dumpNearestNpcSummary(player)
    elseif key == Keyboard.KEY_F6 then
        DebugTools.wipeAndReseed(player)
    elseif key == Keyboard.KEY_F7 then
        DebugTools.adjustNearestRelationship(player, "trust", 0.20)
    elseif key == Keyboard.KEY_F8 then
        DebugTools.forceLegacyCandidate(player)
    end
end
