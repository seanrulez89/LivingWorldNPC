LWN = LWN or {}
LWN.ActionRuntime = LWN.ActionRuntime or {}

-- Translates high-level intents into small engine actions and keeps a debug view
-- of the queue on the record for inspection.
local Runtime = LWN.ActionRuntime

Runtime.Queues = Runtime.Queues or {}

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

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function isMinimalDummyRecord(record)
    return LWN.Social and LWN.Social.isMinimalDummyRecord and LWN.Social.isMinimalDummyRecord(record)
end

local function carrierHandleFor(record)
    return record
        and LWN.EmbodimentManager
        and LWN.EmbodimentManager.getCarrierHandle
        and LWN.EmbodimentManager.getCarrierHandle(record)
        or nil
end

local function carrierKindFor(record)
    local handle = carrierHandleFor(record)
    return handle and handle.kind or record and record.embodiment and record.embodiment.carrierKind or nil
end

local function isAllowedDummyIntent(intent)
    return intent and (intent.kind == "move_to" or intent.kind == "follow_player")
end

local function isDummyMoveAuthorityActive(record)
    return LWN.Social and LWN.Social.isMinimalDummyMoveActive and LWN.Social.isMinimalDummyMoveActive(record)
end

local function isMoveCommandActive(command)
    if type(command) ~= "table" or command.active ~= true then
        return false
    end
    return command.intentKind == "move_to"
        or command.intentKind == "follow_player"
        or command.kind == "move_to"
        or command.kind == "designated_location"
        or command.kind == "follow_player"
end

local function isDummyMotorMoveActive(record)
    local motor = record and record.dummy and record.dummy.motor or nil
    return motor and (motor.state == "started" or motor.state == "stepping") or false
end

local function isDummyMotorSettled(record)
    local motor = record and record.dummy and record.dummy.motor or nil
    local state = motor and motor.state or nil
    return state == nil or state == "arrived" or state == "stalled" or state == "failed" or state == "idle"
end

local function clearDummyCommandMirror(record)
    if not isMinimalDummyRecord(record) then return false end
    record.dummy = record.dummy or {}
    record.dummy.state = "idle"
    record.dummy.command = nil
    return true
end

local function settleDummyIdleIfStopped(record, actor, source)
    if not isMinimalDummyRecord(record) then
        return false
    end

    local command = record and record.companion and record.companion.command or nil
    if isMoveCommandActive(command) or isDummyMotorMoveActive(record) or not isDummyMotorSettled(record) then
        return false
    end

    if actor then
        if protectedCall(actor, "isMoving") == true then
            return false
        end
        if protectedCall(actor, "getPath2") ~= nil then
            return false
        end
    end

    clearDummyCommandMirror(record)
    if actor
        and carrierKindFor(record) == "isozombie"
        and LWN.Carriers
        and LWN.Carriers.isozombie
        and LWN.Carriers.isozombie.enforceHardDummyShell
    then
        LWN.Carriers.isozombie.enforceHardDummyShell(
            record,
            actor,
            "idle",
            source or "ActionRuntime.settleDummyIdleIfStopped"
        )
    end
    return true
end

local function syncDummyMirror(record, queue)
    if not isMinimalDummyRecord(record) then return end
    record.dummy = record.dummy or {}
    local current = queue and queue[1] or nil
    if current and (current.kind == "move_to" or current.kind == "follow_player") then
        record.dummy.state = current.kind
        record.dummy.command = {
            kind = current.kind,
            destination = current.kind == "move_to" and current.data and {
                x = current.data.x,
                y = current.data.y,
                z = current.data.z,
                label = current.data.destinationLabel or current.data.label,
            } or nil,
        }
    else
        local settled = settleDummyIdleIfStopped(record, nil, "ActionRuntime.syncDummyMirror")
        if not settled and isDummyMoveAuthorityActive(record) then
            record.dummy.state = "move_to"
            record.dummy.command = record.dummy.command or { kind = "move_to" }
        elseif not settled then
            record.dummy.state = "idle"
            record.dummy.command = nil
        end
    end
end

local function ensureCommandState(record)
    if not record then return nil end
    record.companion = record.companion or {}
    record.companion.command = record.companion.command or {}
    local command = record.companion.command
    command.destination = command.destination or {}
    if command.status == nil then command.status = "idle" end
    if command.active == nil then command.active = false end
    return command
end

local function setCommandDestination(command, data)
    if not command then return end
    command.destination = command.destination or {}
    if type(data) ~= "table" then
        command.destination.x = nil
        command.destination.y = nil
        command.destination.z = nil
        command.destination.label = nil
        return
    end
    command.destination.x = data.x
    command.destination.y = data.y
    command.destination.z = data.z
    command.destination.label = data.destinationLabel or data.label or command.destination.label
end

local function moveIntentDistance(actor, intent)
    if not actor or not intent or intent.kind ~= "move_to" or not intent.data then
        return nil
    end
    local dx = (protectedCall(actor, "getX") or intent.data.x or 0) - (intent.data.x or 0)
    local dy = (protectedCall(actor, "getY") or intent.data.y or 0) - (intent.data.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function squareKey(square)
    if not square then return nil end
    local x = protectedCall(square, "getX")
    local y = protectedCall(square, "getY")
    local z = protectedCall(square, "getZ")
    if x == nil or y == nil or z == nil then return nil end
    return string.format("%d,%d,%d", x, y, z)
end

local function releaseCommandMovementHold(record, actor, source)
    if not record then return false end
    record.debugHarness = record.debugHarness or {}
    local harness = record.debugHarness
    local changed = false

    if harness.holdPosition == true then
        harness.holdPosition = false
        changed = true
    end
    if harness.quarantine == true then
        harness.quarantine = false
        changed = true
    end
    if harness.allowCommandMovement ~= true then
        harness.allowCommandMovement = true
        changed = true
    end

    record.embodiment = record.embodiment or {}
    record.embodiment.debug = record.embodiment.debug or {}
    record.embodiment.debug.commandHoldReleasedAt = worldAgeHours()
    record.embodiment.debug.commandHoldReleaseSource = source or "ActionRuntime.releaseCommandMovementHold"

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_TestHarnessHoldPosition = false
        modData.LWN_TestHarnessQuarantine = false
        modData.LWN_TestHarnessAllowCommandMovement = true
        modData.LWN_CommandHoldReleasedAt = worldAgeHours()
        modData.LWN_CommandHoldReleaseSource = source or "ActionRuntime.releaseCommandMovementHold"
    end

    return changed
end

local function updateMovementTelemetry(record, intent, command, actor, status, reason)
    if not (record and intent and command and actor) then
        return
    end

    command.movementTelemetry = command.movementTelemetry or {}
    local telemetry = command.movementTelemetry
    local now = worldAgeHours()
    local x = tonumber(protectedCall(actor, "getX") or 0) or 0
    local y = tonumber(protectedCall(actor, "getY") or 0) or 0
    local z = tonumber(protectedCall(actor, "getZ") or 0) or 0
    local square = protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")
    local squareId = squareKey(square)
    local moving = protectedCall(actor, "isMoving") == true
    local path2 = protectedCall(actor, "getPath2")
    local deltaX = telemetry.lastX and (x - telemetry.lastX) or 0
    local deltaY = telemetry.lastY and (y - telemetry.lastY) or 0
    local displacement = math.sqrt(deltaX * deltaX + deltaY * deltaY)

    telemetry.lastStatus = status or telemetry.lastStatus
    telemetry.lastReason = reason or telemetry.lastReason
    telemetry.lastObservedAt = now
    telemetry.lastX = x
    telemetry.lastY = y
    telemetry.lastZ = z
    telemetry.lastSquare = squareId
    telemetry.lastDeltaX = deltaX
    telemetry.lastDeltaY = deltaY
    telemetry.lastDisplacement = displacement
    telemetry.isMoving = moving
    telemetry.path2 = path2 ~= nil
    telemetry.walkType = protectedCall(actor, "getVariableString", "BanditWalkType") or protectedCall(actor, "getWalkType") or "unknown"
    telemetry.canWalk = protectedCall(actor, "isCanWalk")
    telemetry.useless = protectedCall(actor, "isUseless")

    if telemetry.startX == nil then
        telemetry.startX = x
        telemetry.startY = y
        telemetry.startZ = z
        telemetry.startSquare = squareId
        telemetry.startedAt = now
    end

    if displacement > 0.05 or (telemetry.lastSquare ~= nil and telemetry.prevSquare ~= nil and telemetry.lastSquare ~= telemetry.prevSquare) then
        telemetry.lastMovedAt = now
        telemetry.squareChangedAt = telemetry.lastSquare ~= telemetry.prevSquare and now or telemetry.squareChangedAt
        telemetry.noDisplacementSince = nil
    else
        telemetry.noDisplacementSince = telemetry.noDisplacementSince or now
    end

    telemetry.prevSquare = squareId
    telemetry.totalDelta = math.sqrt((x - (telemetry.startX or x)) ^ 2 + (y - (telemetry.startY or y)) ^ 2)

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_MoveTelemetryStatus = telemetry.lastStatus
        modData.LWN_MoveTelemetryReason = telemetry.lastReason
        modData.LWN_MoveTelemetrySquare = telemetry.lastSquare
        modData.LWN_MoveTelemetryDeltaX = telemetry.lastDeltaX
        modData.LWN_MoveTelemetryDeltaY = telemetry.lastDeltaY
        modData.LWN_MoveTelemetryDisplacement = telemetry.lastDisplacement
        modData.LWN_MoveTelemetryTotalDelta = telemetry.totalDelta
        modData.LWN_MoveTelemetryPath2 = telemetry.path2
        modData.LWN_MoveTelemetryMoving = telemetry.isMoving
        modData.LWN_MoveTelemetryWalkType = telemetry.walkType
        modData.LWN_MoveTelemetryCanWalk = telemetry.canWalk
        modData.LWN_MoveTelemetryUseless = telemetry.useless
        modData.LWN_MoveTelemetryNoDisplacementSince = telemetry.noDisplacementSince
        modData.LWN_MoveTelemetryPathOnlyStatueSince = telemetry.pathOnlyStatueSince
        modData.LWN_MoveTelemetryLastMovedAt = telemetry.lastMovedAt
        modData.LWN_MoveTelemetrySquareChangedAt = telemetry.squareChangedAt
    end
end

local function logCommandState(record, intent, command, status, reason)
    if not (LWN.Log and LWN.Log.state and record and command) then return end
    local state = table.concat({
        tostring(intent and intent.kind or command.intentKind or command.kind or "none"),
        tostring(status or command.status or "idle"),
        tostring(reason or command.lastReason or "none"),
    }, "|")
    local destination = command.destination or {}
    LWN.Log.state("CommandRuntime", "command:" .. tostring(record.id), state, {
        npcId = record.id,
        command = command.kind,
        status = status or command.status,
        intent = intent and intent.kind or command.intentKind,
        policy = command.combatPolicy,
        reason = reason or command.lastReason,
        detail = command.lastOutcome,
        x = destination.x,
        y = destination.y,
        z = destination.z,
        distance = command.lastDistance and string.format("%.2f", tonumber(command.lastDistance) or 0) or nil,
    })
end

local function updateMoveCommand(record, intent, status, reason, actor)
    if not record or not intent or (intent.kind ~= "move_to" and intent.kind ~= "follow_player") then
        return
    end

    local command = ensureCommandState(record)
    if not command then return end

    command.kind = intent.data and (intent.data.commandKind or intent.kind) or intent.kind
    command.source = intent.data and (intent.data.commandSource or intent.data.source) or command.source
    command.intentKind = intent.kind
    setCommandDestination(command, intent.data)
    command.status = status or command.status or "queued"
    command.lastReason = reason or command.lastReason
    command.lastDistance = moveIntentDistance(actor, intent)

    local now = worldAgeHours()
    if command.issuedAt == nil then
        command.issuedAt = now
    end
    if (status == "pathing" or status == "following") and command.startedAt == nil then
        command.startedAt = now
    end
    if actor then
        updateMovementTelemetry(record, intent, command, actor, status, reason)
    end

    if status == "arrived" or status == "failed" or status == "cleared" then
        command.active = false
        command.completedAt = now
        command.lastOutcome = status
    else
        command.active = true
    end

    if status == "arrived" or status == "failed" or status == "cleared" then
        settleDummyIdleIfStopped(record, actor, "ActionRuntime.updateMoveCommand." .. tostring(status))
    end
    logCommandState(record, intent, command, status, reason)
end

local function clearActiveCommand(record, reason)
    local command = ensureCommandState(record)
    if not command or command.active ~= true then
        return
    end
    command.status = "cleared"
    command.active = false
    command.completedAt = worldAgeHours()
    command.lastOutcome = "cleared"
    command.lastReason = reason or "runtime_clear"
    command.lastDistance = nil
    logCommandState(record, nil, command, "cleared", command.lastReason)
    if isMinimalDummyRecord(record) then
        record.dummy = record.dummy or {}
        record.dummy.lastMoveResult = reason or "runtime_clear"
        clearDummyCommandMirror(record)
        if record.dummy.motor then
            record.dummy.motor.state = "idle"
            record.dummy.motor.detail = reason or "runtime_clear"
        end
    end
end

local function noteIssuedIntent(record, intent)
    if not record or not intent then return end

    local command = ensureCommandState(record)
    if not command then return end

    if isMinimalDummyRecord(record) and not isAllowedDummyIntent(intent) then
        command.intentKind = intent.kind
        command.status = "idle"
        return
    end

    if intent.kind == "move_to" or intent.kind == "follow_player" then
        command.kind = intent.data and (intent.data.commandKind or intent.kind) or intent.kind
        command.source = intent.data and (intent.data.commandSource or intent.data.source) or command.source
        command.intentKind = intent.kind
        command.combatPolicy = intent.data and intent.data.combatPolicy
            or (intent.kind == "follow_player" and "stance" or "self_defense")
        command.status = "queued"
        command.active = true
        command.issuedAt = worldAgeHours()
        command.startedAt = nil
        command.completedAt = nil
        command.lastOutcome = nil
        command.lastReason = intent.data and intent.data.commandReason or nil
        command.lastDistance = nil
        command.movementTelemetry = {}
        setCommandDestination(command, intent.kind == "move_to" and intent.data or nil)
        if LWN.Log and LWN.Log.info then
            LWN.Log.info("CommandRuntime", "intent_issued", {
                npcId = record.id,
                command = command.kind,
                status = command.status,
                intent = intent.kind,
                policy = command.combatPolicy,
                reason = command.lastReason,
                x = command.destination and command.destination.x,
                y = command.destination and command.destination.y,
                z = command.destination and command.destination.z,
            })
        end
        return
    end

    if command.active ~= true then
        command.intentKind = intent.kind
        command.status = "idle"
    end
end

local function queueFor(id)
    Runtime.Queues[id] = Runtime.Queues[id] or {}
    return Runtime.Queues[id]
end

local function syncPlanMirror(record)
    if not record then return end
    record.goals = record.goals or {}
    record.goals.currentPlan = {}

    local q = queueFor(record.id)
    syncDummyMirror(record, q)
    for i = 1, #q do
        record.goals.currentPlan[i] = q[i].kind
    end

    record.goals.currentIntent = q[1] and q[1].kind or nil
    record.embodiment = record.embodiment or {}
    record.embodiment.target = record.embodiment.target or {}
    local current = q[1]
    if current and current.kind == "attack_melee" then
        record.embodiment.target.kind = current.data and (current.data.targetKind or "world_object") or "world_object"
        record.embodiment.target.npcId = nil
        record.embodiment.target.lastKnownX = current.data and current.data.targetX or nil
        record.embodiment.target.lastKnownY = current.data and current.data.targetY or nil
        record.embodiment.target.lastKnownZ = current.data and current.data.targetZ or nil
        record.embodiment.target.lastResolvedHour = getGameTime() and getGameTime():getWorldAgeHours() or nil
        record.embodiment.target.lastReason = "attack_melee"
    else
        record.embodiment.target.kind = nil
        record.embodiment.target.npcId = nil
        record.embodiment.target.lastKnownX = nil
        record.embodiment.target.lastKnownY = nil
        record.embodiment.target.lastKnownZ = nil
        record.embodiment.target.lastResolvedHour = getGameTime() and getGameTime():getWorldAgeHours() or nil
        record.embodiment.target.lastReason = "queue_sync"
    end
end

local function isAttackTargetUsable(target)
    if not target then return false end
    if instanceof and not instanceof(target, "IsoZombie") then
        return false
    end
    if protectedCall(target, "isDead") == true then
        return false
    end
    if protectedCall(target, "isExistInTheWorld") == false then
        return false
    end
    return true
end

local function resolveAttackTarget(actor, intent)
    if not actor or not intent or not intent.data then return nil end

    local target = intent.data.target
    if isAttackTargetUsable(target) then
        intent.data.targetX = protectedCall(target, "getX") or intent.data.targetX
        intent.data.targetY = protectedCall(target, "getY") or intent.data.targetY
        intent.data.targetZ = protectedCall(target, "getZ") or intent.data.targetZ
        return target
    end

    local cell = getCell and getCell() or nil
    if not cell then
        return nil
    end

    local tx = math.floor(intent.data.targetX or protectedCall(actor, "getX") or 0)
    local ty = math.floor(intent.data.targetY or protectedCall(actor, "getY") or 0)
    local tz = math.floor(intent.data.targetZ or protectedCall(actor, "getZ") or 0)
    local best = nil
    local bestD2 = math.huge

    for y = ty - 1, ty + 1 do
        for x = tx - 1, tx + 1 do
            local square = cell:getGridSquare(x, y, tz)
            local objects = square and protectedCall(square, "getMovingObjects") or nil
            if objects and objects.size and objects.get then
                for i = 0, objects:size() - 1 do
                    local obj = objects:get(i)
                    if isAttackTargetUsable(obj) then
                        local dx = (protectedCall(obj, "getX") or x) - (protectedCall(actor, "getX") or tx)
                        local dy = (protectedCall(obj, "getY") or y) - (protectedCall(actor, "getY") or ty)
                        local d2 = dx * dx + dy * dy
                        if d2 < bestD2 then
                            best = obj
                            bestD2 = d2
                        end
                    end
                end
            end
        end
    end

    intent.data.target = best
    if best then
        intent.data.targetX = protectedCall(best, "getX") or intent.data.targetX
        intent.data.targetY = protectedCall(best, "getY") or intent.data.targetY
        intent.data.targetZ = protectedCall(best, "getZ") or intent.data.targetZ
    end
    return best
end

function Runtime.clear(record, actor)
    local current = record and Runtime.peek(record) or nil
    if record and LWN.CarrierAdapter and LWN.CarrierAdapter.cancelIntent then
        LWN.CarrierAdapter.cancelIntent(record, carrierHandleFor(record), current, "runtime_clear")
    end
    clearActiveCommand(record, "runtime_clear")
    Runtime.Queues[record.id] = {}
    syncPlanMirror(record)
    if actor and actor.StopAllActionQueue then
        actor:StopAllActionQueue()
    end
    if actor and carrierKindFor(record) == "isozombie" and isMinimalDummyRecord(record) and LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.enforceHardDummyShell then
        LWN.Carriers.isozombie.enforceHardDummyShell(record, actor, "idle", "ActionRuntime.clear")
    end
end

local function intentsEquivalent(a, b)
    if not a or not b then return false end
    if a.kind ~= b.kind then return false end

    local ad = a.data or {}
    local bd = b.data or {}
    if a.kind == "retreat" then
        local ax = ad.threatPos and ad.threatPos.x or nil
        local ay = ad.threatPos and ad.threatPos.y or nil
        local bx = bd.threatPos and bd.threatPos.x or nil
        local by = bd.threatPos and bd.threatPos.y or nil
        return ax == bx and ay == by
    end

    if a.kind == "attack_melee" then
        return ad.target == bd.target
            and ad.targetX == bd.targetX
            and ad.targetY == bd.targetY
            and ad.targetZ == bd.targetZ
    end

    return true
end

function Runtime.enqueue(record, intent)
    if isMinimalDummyRecord(record) and not isAllowedDummyIntent(intent) then
        return false
    end
    local q = queueFor(record.id)
    local last = q[#q]
    if intentsEquivalent(last, intent) then
        return false
    end
    if isMinimalDummyRecord(record) then
        Runtime.Queues[record.id] = {}
        q = queueFor(record.id)
    end
    table.insert(q, intent)
    syncPlanMirror(record)
    return true
end

function Runtime.replaceWithIntent(record, actor, intent)
    if not record or not intent then
        return false
    end

    Runtime.clear(record, actor)
    noteIssuedIntent(record, intent)
    local inserted = Runtime.enqueue(record, intent)
    if inserted and LWN.EmbodimentManager and LWN.EmbodimentManager.touchGrace then
        LWN.EmbodimentManager.touchGrace(record)
    end
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("CommandRuntime", "queue_replace", {
            npcId = record.id,
            command = intent.data and (intent.data.commandKind or intent.kind) or intent.kind,
            intent = intent.kind,
            ok = inserted == true,
            reason = intent.data and intent.data.commandReason or nil,
        })
    end
    return inserted
end

function Runtime.peek(record)
    local q = queueFor(record.id)
    return q[1]
end

function Runtime.pop(record)
    local q = queueFor(record.id)
    table.remove(q, 1)
    syncPlanMirror(record)
end

function Runtime._newTimedActionTable(record, actor, intent)
    local t = {}
    t.maxTime = 60
    t.stopOnWalk = true
    t.stopOnRun = true

    function t:isValid()
        return actor ~= nil
    end

    function t:start()
        -- Example animation selection only.
        if intent.kind == "rest" then
            self.javaAction:setActionAnim("Loot")
        end
    end

    function t:update()
        -- no-op placeholder
    end

    function t:perform()
        -- resolve logical effect here
        intent.done = true
        if actor and actor.StopTimedActionAnim then
            actor:StopTimedActionAnim()
        end
    end

    function t:stop()
        intent.failed = true
    end

    return t
end

function Runtime._startTimedAction(record, actor, intent)
    local t = Runtime._newTimedActionTable(record, actor, intent)
    -- Constructor shape follows the exposed Java class and the long-used timed-action helper pattern.
    t.javaAction = LuaTimedAction.new(t, actor)

    if actor.QueueAction then
        actor:QueueAction(t.javaAction)
    else
        actor:StartAction(t.javaAction)
    end
end

local function invokeActorPath(actor, methodName, ...)
    if not actor then return false end
    local fn = actor[methodName]
    if not fn then return false end
    local ok = pcall(fn, actor, ...)
    return ok == true
end

local function actorTilePosition(actor)
    return math.floor(tonumber(protectedCall(actor, "getX") or 0) or 0), math.floor(tonumber(protectedCall(actor, "getY") or 0) or 0), math.floor(tonumber(protectedCall(actor, "getZ") or 0) or 0)
end

local function gridSquareAt(x, y, z)
    local cell = getCell and getCell() or nil
    return cell and protectedCall(cell, "getGridSquare", x, y, z) or nil
end

local function commitDummyPosition(record, actor, square, source)
    if not (record and actor and square) then return nil end
    local sx = tonumber(protectedCall(square, "getX") or 0) or 0
    local sy = tonumber(protectedCall(square, "getY") or 0) or 0
    local sz = tonumber(protectedCall(square, "getZ") or 0) or 0
    if LWN.EmbodimentManager and LWN.EmbodimentManager.commitActorPosition then
        return LWN.EmbodimentManager.commitActorPosition(record, actor, {
            x = sx + 0.5,
            y = sy + 0.5,
            z = sz,
            source = source or "ActionRuntime.commitDummyPosition",
        })
    end
    record.anchor = record.anchor or {}
    record.anchor.x = sx
    record.anchor.y = sy
    record.anchor.z = sz
    record.embodiment = record.embodiment or {}
    record.embodiment.lastKnownX = sx + 0.5
    record.embodiment.lastKnownY = sy + 0.5
    record.embodiment.lastKnownZ = sz
    record.embodiment.lastKnownSquare = string.format("%d,%d,%d", sx, sy, sz)
    if record.dummy then
        record.dummy.lastCommittedSquare = record.embodiment.lastKnownSquare
        record.dummy.lastCommittedAt = worldAgeHours()
        record.dummy.lastCommittedSource = source or "ActionRuntime.commitDummyPosition"
    end
    return { x = sx + 0.5, y = sy + 0.5, z = sz }
end

local function ensureActorAtSquare(actor, square)
    if not (actor and square) then return false end
    if LWN.ActorFactory and LWN.ActorFactory.ensureActorInWorld then
        return LWN.ActorFactory.ensureActorInWorld(actor, square) == true
    end
    local sx = tonumber(protectedCall(square, "getX") or 0) or 0
    local sy = tonumber(protectedCall(square, "getY") or 0) or 0
    local sz = tonumber(protectedCall(square, "getZ") or 0) or 0
    protectedCall(actor, "setX", sx + 0.5)
    protectedCall(actor, "setY", sy + 0.5)
    protectedCall(actor, "setZ", sz)
    protectedCall(actor, "setCurrent", square)
    protectedCall(actor, "setCurrentSquare", square)
    protectedCall(actor, "setSquare", square)
    protectedCall(actor, "setMovingSquareNow")
    if protectedCall(actor, "isExistInTheWorld") ~= true then
        protectedCall(square, "AddMovingObject", actor)
        protectedCall(actor, "addToWorld")
    end
    return (protectedCall(actor, "getSquare") or protectedCall(actor, "getCurrentSquare")) ~= nil
end

local function ensureDummyMotorState(record, actor)
    if not isMinimalDummyRecord(record) then return nil end
    record.dummy = record.dummy or {}
    record.dummy.motor = record.dummy.motor or {
        mode = "deterministic",
        state = "idle",
        startedAt = nil,
        updatedAt = nil,
        lastSquare = nil,
        steps = 0,
        stallTicks = 0,
    }
    local motor = record.dummy.motor
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyMoveMotor = motor.mode
        modData.LWN_DummyMoveMotorState = motor.state
        modData.LWN_DummyMoveMotorSteps = motor.steps or 0
        modData.LWN_DummyMoveMotorLastSquare = motor.lastSquare
    end
    return motor
end

local function setDummyMotorState(record, actor, state, detail)
    local motor = ensureDummyMotorState(record, actor)
    if not motor then return nil end
    motor.state = state
    motor.detail = detail or motor.detail
    motor.updatedAt = worldAgeHours()

    if isMinimalDummyRecord(record) then
        record.dummy = record.dummy or {}
        if state == "started" or state == "stepping" then
            record.dummy.state = "move_to"
            record.dummy.command = record.dummy.command or { kind = "move_to" }
        elseif state == "arrived" or state == "stalled" or state == "failed" or state == "idle" then
            clearDummyCommandMirror(record)
        end
    end

    local command = ensureCommandState(record)
    if command then
        command.movementTelemetry = command.movementTelemetry or {}
        command.movementTelemetry.motorState = state
        command.movementTelemetry.motorDetail = detail
        command.movementTelemetry.motorUpdatedAt = motor.updatedAt
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_DummyMoveMotor = motor.mode
        modData.LWN_DummyMoveMotorState = state
        modData.LWN_DummyMoveMotorDetail = detail
        modData.LWN_DummyMoveMotorUpdatedAt = motor.updatedAt
        modData.LWN_DummyMoveMotorSteps = motor.steps or 0
        modData.LWN_DummyMoveMotorLastSquare = motor.lastSquare
    end
    return motor
end

local function chooseDummyMotorStepSquare(actor, intent)
    if not (actor and intent and intent.data) then
        return nil, "dummy_move_missing_intent"
    end

    local cx, cy, cz = actorTilePosition(actor)
    local tx = math.floor(tonumber(intent.data.x or cx) or cx)
    local ty = math.floor(tonumber(intent.data.y or cy) or cy)
    local tz = math.floor(tonumber(intent.data.z or cz) or cz)
    if cx == tx and cy == ty and cz == tz then
        return nil, "dummy_move_arrived"
    end

    local dx = tx > cx and 1 or (tx < cx and -1 or 0)
    local dy = ty > cy and 1 or (ty < cy and -1 or 0)
    local candidates = {
        { x = cx + dx, y = cy + dy, z = tz },
        { x = cx + dx, y = cy, z = tz },
        { x = cx, y = cy + dy, z = tz },
    }

    for i = 1, #candidates do
        local c = candidates[i]
        if not (c.x == cx and c.y == cy and c.z == cz) then
            local square = gridSquareAt(c.x, c.y, c.z)
            if square then
                return square, "dummy_move_step"
            end
        end
    end

    return nil, "dummy_move_no_square"
end

function Runtime._startDummyMoveMotor(record, actor, intent)
    local motor = ensureDummyMotorState(record, actor)
    if not motor then
        intent.failed = true
        updateMoveCommand(record, intent, "failed", "dummy_move_motor_unavailable", actor)
        return
    end

    record.dummy = record.dummy or {}
    record.dummy.state = "move_to"
    record.dummy.command = {
        kind = "move_to",
        destination = intent.data and {
            x = intent.data.x,
            y = intent.data.y,
            z = intent.data.z,
            label = intent.data.destinationLabel or intent.data.label,
        } or nil,
    }

    motor.mode = "deterministic"
    motor.startedAt = worldAgeHours()
    motor.updatedAt = motor.startedAt
    motor.steps = 0
    motor.stallTicks = 0
    motor.lastSquare = squareKey(protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare"))
    intent.started = true
    intent.pathMethod = "dummy:deterministic"
    intent.lastProgressAt = worldAgeHours()
    intent.lastObservedDistance = moveIntentDistance(actor, intent)
    protectedCall(actor, "setPath2", nil)
    protectedCall(actor, "setMoving", true)
    setDummyMotorState(record, actor, "started", "dummy_move_motor_started")
    updateMoveCommand(record, intent, "pathing", "dummy_move_motor_started", actor)
end

function Runtime._tickDummyMoveMotor(record, actor, intent)
    local motor = ensureDummyMotorState(record, actor)
    if not motor then
        intent.failed = true
        updateMoveCommand(record, intent, "failed", "dummy_move_motor_missing", actor)
        return true
    end

    local distance = moveIntentDistance(actor, intent)
    if distance ~= nil and distance <= 0.55 then
        protectedCall(actor, "setMoving", false)
        record.dummy = record.dummy or {}
        record.dummy.state = "idle"
        commitDummyPosition(record, actor, protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare"), "ActionRuntime._tickDummyMoveMotor.arrived_pre")
        setDummyMotorState(record, actor, "arrived", "dummy_move_arrived")
        if LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.scrubDummyPresentation then
            LWN.Carriers.isozombie.scrubDummyPresentation(record, actor, "idle", "ActionRuntime._tickDummyMoveMotor.arrived_pre", { force = true })
        end
        intent.done = true
        updateMoveCommand(record, intent, "arrived", "dummy_move_arrived", actor)
        return true
    end

    local nextSquare, reason = chooseDummyMotorStepSquare(actor, intent)
    if not nextSquare then
        if reason == "dummy_move_arrived" then
            protectedCall(actor, "setMoving", false)
            setDummyMotorState(record, actor, "arrived", reason)
            intent.done = true
            updateMoveCommand(record, intent, "arrived", reason, actor)
            return true
        end

        motor.stallTicks = (motor.stallTicks or 0) + 1
        setDummyMotorState(record, actor, "stalled", reason)
        if motor.stallTicks >= 10 then
            protectedCall(actor, "setMoving", false)
            if LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.scrubDummyPresentation then
                LWN.Carriers.isozombie.scrubDummyPresentation(record, actor, "idle", "ActionRuntime._tickDummyMoveMotor.stalled", { force = true })
            end
            intent.failed = true
            updateMoveCommand(record, intent, "failed", "dummy_move_stalled", actor)
            return true
        end
        updateMoveCommand(record, intent, "pathing", reason or "dummy_move_waiting", actor)
        return false
    end

    local ok = ensureActorAtSquare(actor, nextSquare)
    if ok ~= true then
        motor.stallTicks = (motor.stallTicks or 0) + 1
        setDummyMotorState(record, actor, "stalled", "dummy_move_reposition_failed")
        if motor.stallTicks >= 10 then
            protectedCall(actor, "setMoving", false)
            intent.failed = true
            updateMoveCommand(record, intent, "failed", "dummy_move_reposition_failed", actor)
            return true
        end
        updateMoveCommand(record, intent, "pathing", "dummy_move_reposition_retry", actor)
        return false
    end

    motor.steps = (motor.steps or 0) + 1
    motor.stallTicks = 0
    motor.updatedAt = worldAgeHours()
    motor.lastSquare = squareKey(nextSquare)
    protectedCall(actor, "setMoving", true)
    commitDummyPosition(record, actor, nextSquare, "ActionRuntime._tickDummyMoveMotor")
    setDummyMotorState(record, actor, "stepping", motor.lastSquare)

    distance = moveIntentDistance(actor, intent)
    if distance ~= nil and distance <= 0.55 then
        protectedCall(actor, "setMoving", false)
        record.dummy = record.dummy or {}
        record.dummy.state = "idle"
        commitDummyPosition(record, actor, protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare"), "ActionRuntime._tickDummyMoveMotor.arrived_post")
        setDummyMotorState(record, actor, "arrived", "dummy_move_arrived")
        if LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.scrubDummyPresentation then
            LWN.Carriers.isozombie.scrubDummyPresentation(record, actor, "idle", "ActionRuntime._tickDummyMoveMotor.arrived_post", { force = true })
        end
        intent.done = true
        updateMoveCommand(record, intent, "arrived", "dummy_move_arrived", actor)
        return true
    end

    updateMoveCommand(record, intent, "pathing", "dummy_move_step", actor)
    return false
end

Runtime.settleDummyIdleIfStopped = settleDummyIdleIfStopped

function Runtime._startMovement(record, actor, intent)
    local pf = actor:getPathFindBehavior2()
    local started = false
    local pathMethod = nil

    releaseCommandMovementHold(record, actor, "ActionRuntime._startMovement")
    protectedCall(actor, "setUseless", false)
    protectedCall(actor, "setCanWalk", true)
    protectedCall(actor, "setNoTeeth", true)
    protectedCall(actor, "setVariable", "NoLungeTarget", true)
    protectedCall(actor, "setWalkType", "Walk")
    protectedCall(actor, "setVariable", "BanditWalkType", "Walk")
    protectedCall(actor, "clearVariable", "bPathfind")
    if LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.reassertManagedShellContract then
        LWN.Carriers.isozombie.reassertManagedShellContract(record, actor, {
            source = "ActionRuntime._startMovement",
            allowMovement = true,
            neutralized = false,
            clearCombat = false,
            stopAudio = false,
            forceLane = isMinimalDummyRecord(record) and "dummy_move" or nil,
        })
    end
    if isMinimalDummyRecord(record) and LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.enforceHardDummyShell then
        LWN.Carriers.isozombie.enforceHardDummyShell(record, actor, "move", "ActionRuntime._startMovement")
    end

    if isMinimalDummyRecord(record) and intent.kind == "move_to" then
        Runtime._startDummyMoveMotor(record, actor, intent)
        return
    elseif intent.kind == "move_to" then
        started = invokeActorPath(actor, "pathToLocation", intent.data.x, intent.data.y, intent.data.z)
        pathMethod = started and "actor:pathToLocation" or nil
        if not started and pf then
            pf:pathToLocation(intent.data.x, intent.data.y, intent.data.z)
            started = true
            pathMethod = "pf:pathToLocation"
        end
    elseif intent.kind == "follow_player" then
        local player = getPlayer()
        if player then
            started = invokeActorPath(actor, "pathToCharacter", player)
            pathMethod = started and "actor:pathToCharacter" or nil
            if not started and pf then
                pf:pathToCharacter(player)
                started = true
                pathMethod = "pf:pathToCharacter"
            end
        end
    elseif intent.kind == "guard_player" then
        local player = getPlayer()
        if player then
            started = invokeActorPath(actor, "pathToCharacter", player)
            pathMethod = started and "actor:pathToCharacter" or nil
            if not started and pf then
                pf:pathToCharacter(player)
                started = true
                pathMethod = "pf:pathToCharacter"
            end
        end
    elseif intent.kind == "retreat" then
        local px, py, pz = actor:getX(), actor:getY(), actor:getZ()
        local tx = math.floor(px + (px - (intent.data.threatPos and intent.data.threatPos.x or px)) * 4)
        local ty = math.floor(py + (py - (intent.data.threatPos and intent.data.threatPos.y or py)) * 4)
        started = invokeActorPath(actor, "pathToLocation", tx, ty, pz)
        pathMethod = started and "actor:pathToLocation" or nil
        if not started and pf then
            pf:pathToLocation(tx, ty, pz)
            started = true
            pathMethod = "pf:pathToLocation"
        end
    elseif intent.kind == "wander_short" then
        local px, py, pz = math.floor(actor:getX()), math.floor(actor:getY()), math.floor(actor:getZ())
        local tx = px + ZombRand(-5, 6)
        local ty = py + ZombRand(-5, 6)
        started = invokeActorPath(actor, "pathToLocation", tx, ty, pz)
        pathMethod = started and "actor:pathToLocation" or nil
        if not started and pf then
            pf:pathToLocation(tx, ty, pz)
            started = true
            pathMethod = "pf:pathToLocation"
        end
    end

    if not started then
        intent.failed = true
        updateMoveCommand(record, intent, "failed", "path_start_unavailable", actor)
        return
    end

    intent.started = true
    intent.pathMethod = pathMethod
    intent.lastProgressAt = worldAgeHours()
    intent.lastObservedDistance = moveIntentDistance(actor, intent)
    protectedCall(actor, "setMoving", true)
    updateMoveCommand(record, intent, "pathing", pathMethod and ("path_started:" .. pathMethod) or "path_started", actor)
end

function Runtime._tickMovementIntent(record, actor, intent)
    releaseCommandMovementHold(record, actor, "ActionRuntime._tickMovementIntent")
    if LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.reassertManagedShellContract then
        LWN.Carriers.isozombie.reassertManagedShellContract(record, actor, {
            source = "ActionRuntime._tickMovementIntent",
            allowMovement = true,
            neutralized = false,
            clearCombat = false,
            stopAudio = false,
            forceLane = isMinimalDummyRecord(record) and "dummy_move" or "non_hostile_commandable",
        })
    end
    if isMinimalDummyRecord(record) and LWN.Carriers and LWN.Carriers.isozombie and LWN.Carriers.isozombie.enforceHardDummyShell then
        LWN.Carriers.isozombie.enforceHardDummyShell(record, actor, "move", "ActionRuntime._tickMovementIntent")
    end

    if isMinimalDummyRecord(record) and intent.pathMethod == "dummy:deterministic" then
        return Runtime._tickDummyMoveMotor(record, actor, intent)
    end

    if intent.kind == "move_to" then
        local distance = moveIntentDistance(actor, intent)
        if distance ~= nil and distance <= 1.1 then
            intent.done = true
            updateMoveCommand(record, intent, "arrived", "distance_threshold", actor)
            return true
        end
        if distance ~= nil then
            local lastDistance = tonumber(intent.lastObservedDistance)
            if lastDistance == nil or distance < (lastDistance - 0.05) then
                intent.lastProgressAt = worldAgeHours()
            end
            intent.lastObservedDistance = distance
        end
    end

    local command = ensureCommandState(record)
    if command and type(command.movementTelemetry) ~= "table" then
        command.movementTelemetry = {}
    end
    local telemetry = command and command.movementTelemetry or nil
    if telemetry == nil then
        telemetry = {}
        if command then
            command.movementTelemetry = telemetry
        end
    end
    local moving = telemetry and telemetry.isMoving == true or false
    local hasPath = telemetry and telemetry.path2 == true or false
    local totalDelta = telemetry and tonumber(telemetry.totalDelta) or nil
    local squareChanged = telemetry and telemetry.squareChangedAt ~= nil or false
    local statueSince = telemetry and tonumber(telemetry.pathOnlyStatueSince) or nil
    if moving and hasPath and (totalDelta == nil or totalDelta <= 0.05) and squareChanged ~= true then
        telemetry.pathOnlyStatueSince = statueSince or worldAgeHours()
    else
        telemetry.pathOnlyStatueSince = nil
    end
    statueSince = telemetry and tonumber(telemetry.pathOnlyStatueSince) or nil
    if moving and hasPath and statueSince and (worldAgeHours() - statueSince) >= (2.5 / 3600) then
        if telemetry.lastNoDisplacementWarnAt == nil or (worldAgeHours() - telemetry.lastNoDisplacementWarnAt) >= (2 / 3600) then
            telemetry.lastNoDisplacementWarnAt = worldAgeHours()
            intent.watchdogTriggered = true
            updateMoveCommand(record, intent, "pathing", "watchdog:path_only_statue", actor)
        end
    end

    local pf = actor:getPathFindBehavior2()
    if not pf then
        intent.failed = true
        updateMoveCommand(record, intent, "failed", "path_behavior_lost", actor)
        return true
    end

    local result = pf:update()
    if tostring(result) == "Succeeded" then
        intent.done = true
        updateMoveCommand(record, intent, "arrived", "path_succeeded", actor)
        return true
    elseif tostring(result) == "Failed" then
        intent.failed = true
        updateMoveCommand(record, intent, "failed", "path_failed", actor)
        return true
    end
    updateMoveCommand(record, intent, "pathing", "path_running", actor)
    return false
end

function Runtime.tick(record, actor)
    local current = Runtime.peek(record)
    if not current then
        if isMinimalDummyRecord(record) then
            syncDummyMirror(record, nil)
        end
        return
    end

    if isMinimalDummyRecord(record) and current.kind ~= "move_to" and current.kind ~= "follow_player" then
        current.failed = true
        Runtime.pop(record)
        return
    end

    local delegated = nil
    if LWN.CarrierAdapter and LWN.CarrierAdapter.tickIntent then
        delegated = LWN.CarrierAdapter.tickIntent(record, carrierHandleFor(record), current)
    end
    local delegatedHandled = delegated and delegated.handled == true
    if delegatedHandled then
        current.started = true
        current.pathMethod = "carrier:" .. tostring(carrierKindFor(record) or "unknown")
        if delegated.done == true then
            current.done = true
            updateMoveCommand(record, current, delegated.status or "arrived", delegated.reason or "carrier_arrived", actor)
        elseif delegated.failed == true then
            current.failed = true
            updateMoveCommand(record, current, delegated.status or "failed", delegated.reason or "carrier_failed", actor)
        elseif current.kind == "move_to" or current.kind == "follow_player" then
            updateMoveCommand(
                record,
                current,
                delegated.status or (current.kind == "follow_player" and "following" or "pathing"),
                delegated.reason or "carrier_pathing",
                actor
            )
        end
    elseif current.kind == "move_to" or current.kind == "follow_player" or current.kind == "guard_player" or current.kind == "retreat" or current.kind == "wander_short" then
        if not current.started then
            if current.kind == "guard_player" then
                local player = getPlayer()
                if player then
                    local dx = actor:getX() - player:getX()
                    local dy = actor:getY() - player:getY()
                    if (dx * dx + dy * dy) <= 9 then
                        actor:faceThisObject(player)
                        current.done = true
                    else
                        Runtime._startMovement(record, actor, current)
                    end
                else
                    current.failed = true
                end
            else
                Runtime._startMovement(record, actor, current)
            end
        else
            if current.kind == "guard_player" then
                local player = getPlayer()
                if player then
                    local dx = actor:getX() - player:getX()
                    local dy = actor:getY() - player:getY()
                    if (dx * dx + dy * dy) <= 9 then
                        actor:faceThisObject(player)
                        current.done = true
                    else
                        Runtime._tickMovementIntent(record, actor, current)
                    end
                else
                    current.failed = true
                end
            else
                Runtime._tickMovementIntent(record, actor, current)
            end
        end
    elseif current.kind == "talk" then
        if not current.started then
            current.started = true
            if current.data.topic == "ask_food" then
                actor:Say("Do you have anything to eat?")
            elseif current.data.topic == "reveal_clue" then
                actor:Say("I think I know where to look next.")
            end
            current.done = true
        end
    elseif current.kind == "rest" or current.kind == "search_nearby" then
        if not current.started then
            current.started = true
            Runtime._startTimedAction(record, actor, current)
        else
            -- Timed action completion is observed through flags set by the action table.
        end
    elseif current.kind == "idle_observe" then
        current.done = true
    elseif current.kind == "attack_melee" then
        local target = resolveAttackTarget(actor, current)
        if target and actor.AttemptAttack then
            actor:faceThisObject(target)
            actor:AttemptAttack(1.0)
        else
            current.failed = true
        end
        current.done = true
    end

    if current.done or current.failed then
        if isMinimalDummyRecord(record) then
            record.dummy = record.dummy or {}
            record.dummy.lastMoveResult = current.done and "done" or "failed"
            if record.dummy.motor then
                record.dummy.motor.state = current.done and "arrived" or "failed"
                record.dummy.motor.detail = current.done and (current.pathMethod == "dummy:deterministic" and "dummy_move_arrived" or "done") or (current.pathMethod == "dummy:deterministic" and "dummy_move_failed" or "failed")
            end
        end
        Runtime.pop(record)
    end
end
