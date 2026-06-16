LWN = LWN or {}
LWN.Combat = LWN.Combat or {}

local Combat = LWN.Combat

local DEFAULT_TEAM_ID = "player-team-0"
local AGGRESSIVE_RADIUS = 8
local PASSIVE_RADIUS = 6
local MAX_PLAYER_DISTANCE = 12
local THREAT_MEMORY_MS = 3000
local TEAM_SIGNAL_MS = 4000

Combat.TeamSignals = Combat.TeamSignals or {}
Combat.Runtime = Combat.Runtime or {}

local function nowMs()
    if getTimestampMs then return getTimestampMs() end
    return math.floor((os and os.clock and os.clock() or 0) * 1000)
end

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function brainFor(actor)
    if not (actor and BanditBrain and BanditBrain.Get) then return nil end
    local ok, brain = pcall(BanditBrain.Get, actor)
    return ok and brain or nil
end

local function ensureCombat(record)
    if LWN.PopulationStore and LWN.PopulationStore.ensureRecordShape then
        LWN.PopulationStore.ensureRecordShape(record)
    end
    record.companion = record.companion or {}
    record.companion.teamId = record.companion.teamId or DEFAULT_TEAM_ID
    record.combat = record.combat or {}
    record.combat.disposition = record.combat.disposition == "aggressive" and "aggressive" or "passive"
    record.combat.state = record.combat.state or "idle"
    record.combat.reason = record.combat.reason or "no_threat"
    return record.combat
end

local function isPlayer(obj)
    return obj ~= nil
        and instanceof ~= nil
        and instanceof(obj, "IsoPlayer")
        and protectedCall(obj, "isNPC") ~= true
end

local function isAlive(obj)
    if not obj then return false end
    if protectedCall(obj, "isDead") == true then return false end
    if protectedCall(obj, "isAlive") == false then return false end
    local health = tonumber(protectedCall(obj, "getHealth"))
    return health == nil or health > 0
end

local function isOrdinaryZombie(obj)
    if not obj or not instanceof or not instanceof(obj, "IsoZombie") or not isAlive(obj) then
        return false
    end
    return brainFor(obj) == nil
end

local function distanceBetween(a, b)
    if not a or not b then return math.huge end
    local ax = tonumber(protectedCall(a, "getX")) or 0
    local ay = tonumber(protectedCall(a, "getY")) or 0
    local bx = tonumber(protectedCall(b, "getX")) or 0
    local by = tonumber(protectedCall(b, "getY")) or 0
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function recordForActor(actor)
    local modData = protectedCall(actor, "getModData")
    local npcId = modData and modData.LWN_NpcId or nil
    return npcId and LWN.PopulationStore and LWN.PopulationStore.getNPC
        and LWN.PopulationStore.getNPC(npcId) or nil
end

local function isSquadTarget(target, teamId)
    if isPlayer(target) then return true end
    local record = recordForActor(target)
    return record ~= nil
        and record.companion ~= nil
        and record.companion.teamId == teamId
        and (not LWN.PopulationStore.isAlive or LWN.PopulationStore.isAlive(record) == true)
end

local function signalFor(teamId)
    local signal = Combat.TeamSignals[teamId]
    if signal and nowMs() > (tonumber(signal.expiresAtMs) or 0) then
        Combat.TeamSignals[teamId] = nil
        return nil
    end
    return signal
end

local function setTeamSignal(teamId, reason, threat)
    teamId = teamId or DEFAULT_TEAM_ID
    Combat.TeamSignals[teamId] = {
        reason = reason,
        threat = threat,
        x = tonumber(protectedCall(threat, "getX")),
        y = tonumber(protectedCall(threat, "getY")),
        z = tonumber(protectedCall(threat, "getZ")),
        createdAtMs = nowMs(),
        expiresAtMs = nowMs() + TEAM_SIGNAL_MS,
    }
end

local function runtimeFor(record)
    local runtime = Combat.Runtime[record.id]
    if not runtime then
        runtime = {}
        Combat.Runtime[record.id] = runtime
    end
    return runtime
end

local function rememberDirectThreat(record, threat, reason)
    local runtime = runtimeFor(record)
    runtime.directThreat = threat
    runtime.directReason = reason or "direct_self_defense"
    runtime.directExpiresAtMs = nowMs() + TEAM_SIGNAL_MS
end

function Combat.notePlayerAttack(target, attacker)
    if not isPlayer(attacker) or not isOrdinaryZombie(target) then return false end
    setTeamSignal(DEFAULT_TEAM_ID, "player_attacked_zombie", target)
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Combat", "team_signal", {
            teamId = DEFAULT_TEAM_ID,
            reason = "player_attacked_zombie",
            target = tostring(target),
            x = tonumber(protectedCall(target, "getX")),
            y = tonumber(protectedCall(target, "getY")),
            z = tonumber(protectedCall(target, "getZ")),
        })
    end
    return true
end

function Combat.noteSquadHit(record, attacker)
    if not record or not isOrdinaryZombie(attacker) then return false end
    ensureCombat(record)
    rememberDirectThreat(record, attacker, "self_hit_by_zombie")
    setTeamSignal(record.companion.teamId, "squad_member_hit", attacker)
    if LWN.Log and LWN.Log.warn then
        LWN.Log.warn("Combat", "squad_hit_by_zombie", {
            npcId = record.id,
            teamId = record.companion.teamId,
            reason = "squad_member_hit",
            target = tostring(attacker),
            health = record.stats and record.stats.health,
            x = tonumber(protectedCall(attacker, "getX")),
            y = tonumber(protectedCall(attacker, "getY")),
            z = tonumber(protectedCall(attacker, "getZ")),
        })
    end
    return true
end

function Combat.resetTeam(teamId)
    Combat.TeamSignals[teamId or DEFAULT_TEAM_ID] = nil
    for npcId in pairs(Combat.Runtime) do
        Combat.Runtime[npcId] = nil
    end
end

function Combat.setDisposition(record, disposition, reason)
    if not record then return false end
    local combat = ensureCombat(record)
    combat.disposition = disposition == "aggressive" and "aggressive" or "passive"
    combat.reason = reason or "disposition_changed"
    return true
end

function Combat.commandPolicy(record)
    local command = record and record.companion and record.companion.command or nil
    local policy = command and command.combatPolicy or nil
    if policy == "avoid" or policy == "self_defense" or policy == "assist" or policy == "stance" then
        return policy
    end
    if command and (command.kind == "move_to" or command.kind == "designated_location" or command.kind == "wait") then
        return "self_defense"
    end
    return "stance"
end

local function scanThreats(record, actor)
    local result = {
        nearest = nil,
        nearestDistance = math.huge,
        direct = nil,
        directDistance = math.huge,
        team = nil,
        teamDistance = math.huge,
    }
    local cell = getCell and getCell() or nil
    if not cell then return result end

    local ax = math.floor(tonumber(protectedCall(actor, "getX")) or 0)
    local ay = math.floor(tonumber(protectedCall(actor, "getY")) or 0)
    local az = math.floor(tonumber(protectedCall(actor, "getZ")) or 0)
    local teamId = record.companion.teamId or DEFAULT_TEAM_ID
    local seen = {}

    for y = ay - AGGRESSIVE_RADIUS, ay + AGGRESSIVE_RADIUS do
        for x = ax - AGGRESSIVE_RADIUS, ax + AGGRESSIVE_RADIUS do
            local square = cell:getGridSquare(x, y, az)
            local objects = square and protectedCall(square, "getMovingObjects") or nil
            if objects and objects.size and objects.get then
                for i = 0, objects:size() - 1 do
                    local zombie = objects:get(i)
                    if not seen[zombie] and isOrdinaryZombie(zombie) then
                        seen[zombie] = true
                        local distance = distanceBetween(actor, zombie)
                        local visible = protectedCall(actor, "CanSee", zombie)
                        if distance <= AGGRESSIVE_RADIUS and visible ~= false then
                            if distance < result.nearestDistance then
                                result.nearest = zombie
                                result.nearestDistance = distance
                            end
                            local target = protectedCall(zombie, "getTarget")
                            if target == actor and distance < result.directDistance then
                                result.direct = zombie
                                result.directDistance = distance
                            end
                            if isSquadTarget(target, teamId) and distance < result.teamDistance then
                                result.team = zombie
                                result.teamDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    return result
end

local function taskName(actor)
    local task = Bandit and Bandit.GetTask and Bandit.GetTask(actor) or nil
    return task and task.action or "none"
end

local function setEngaged(record, actor, brain, engaged, reason, threat, refreshThreatMemory)
    local combat = ensureCombat(record)
    local nextState = engaged and "engaged" or "idle"
    local stateChanged = combat.state ~= nextState
    local changed = stateChanged or combat.reason ~= reason
    if stateChanged and Bandit and Bandit.ClearTasks then
        Bandit.ClearTasks(actor)
        local pathfinder = protectedCall(actor, "getPathFindBehavior2")
        protectedCall(pathfinder, "cancel")
        protectedCall(pathfinder, "reset")
        brain.lwnMoveActive = false
    end

    combat.state = nextState
    combat.reason = reason
    brain.lwnCombatEngaged = engaged == true
    brain.lwnCombatReason = reason
    brain.lwnTeamId = record.companion.teamId

    if threat then
        combat.lastThreatX = tonumber(protectedCall(threat, "getX"))
        combat.lastThreatY = tonumber(protectedCall(threat, "getY"))
        combat.lastThreatZ = tonumber(protectedCall(threat, "getZ"))
        combat.lastThreatAt = worldAgeHours()
    end
    if engaged then
        combat.lastEngagedAt = worldAgeHours()
        local runtime = runtimeFor(record)
        if refreshThreatMemory ~= false then
            runtime.lastValidThreatAtMs = nowMs()
            runtime.lastThreat = threat or runtime.lastThreat
        end
        if Bandit and Bandit.ForceStationary then Bandit.ForceStationary(actor, false) end
    elseif stateChanged then
        combat.lastDisengagedAt = worldAgeHours()
        local runtime = runtimeFor(record)
        runtime.lastThreat = nil
        runtime.lastValidThreatAtMs = nil
        protectedCall(actor, "setTarget", nil)
    end

    if changed then
        local identity = record.identity or {}
        if LWN.Log and LWN.Log.info then
            LWN.Log.info("Combat", "engagement", {
                npcId = record.id,
                name = tostring(identity.firstName or "Unknown") .. " " .. tostring(identity.lastName or ""),
                teamId = record.companion.teamId,
                state = nextState,
                stance = combat.disposition,
                policy = Combat.commandPolicy(record),
                reason = reason,
                target = tostring(threat or protectedCall(actor, "getTarget")),
                task = taskName(actor),
                health = tonumber(record.stats and record.stats.health or protectedCall(actor, "getHealth") or 0) or 0,
                x = tonumber(protectedCall(actor, "getX")),
                y = tonumber(protectedCall(actor, "getY")),
                z = tonumber(protectedCall(actor, "getZ")),
            })
        end
        print(string.format(
            "[LWN][Combat] npcId=%s name=%s %s stance=%s policy=%s team=%s health=%.2f threat=%s reason=%s task=%s target=%s",
            tostring(record.id),
            tostring(identity.firstName or "Unknown") .. " " .. tostring(identity.lastName or ""),
            nextState,
            tostring(combat.disposition),
            tostring(Combat.commandPolicy(record)),
            tostring(record.companion.teamId),
            tonumber(record.stats and record.stats.health or protectedCall(actor, "getHealth") or 0) or 0,
            tostring(threat),
            tostring(reason),
            taskName(actor),
            tostring(protectedCall(actor, "getTarget"))
        ))
    end
end

function Combat.update(record, actor)
    if not record or not actor then return false end
    local brain = brainFor(actor)
    if not brain or brain.lwnControlled ~= true then return false end

    local combat = ensureCombat(record)
    local runtime = runtimeFor(record)
    local now = nowMs()
    local scan = scanThreats(record, actor)
    if scan.team and scan.teamDistance <= PASSIVE_RADIUS then
        setTeamSignal(record.companion.teamId, "zombie_targeting_squad", scan.team)
    end

    if runtime.directThreat and now > (tonumber(runtime.directExpiresAtMs) or 0) then
        runtime.directThreat = nil
        runtime.directReason = nil
    end

    local threat, reason = nil, nil
    if scan.direct and scan.directDistance <= PASSIVE_RADIUS then
        threat, reason = scan.direct, "direct_self_defense"
        rememberDirectThreat(record, threat, reason)
    elseif runtime.directThreat and isOrdinaryZombie(runtime.directThreat) then
        threat, reason = runtime.directThreat, runtime.directReason or "direct_self_defense"
    else
        local policy = Combat.commandPolicy(record)
        local signal = signalFor(record.companion.teamId)
        if policy == "assist" or policy == "stance" then
            if signal and scan.nearest and scan.nearestDistance <= PASSIVE_RADIUS then
                threat = signal.threat and isOrdinaryZombie(signal.threat) and signal.threat or scan.nearest
                reason = signal.reason or "team_defense"
            elseif policy == "stance"
                and combat.disposition == "aggressive"
                and scan.nearest
                and scan.nearestDistance <= AGGRESSIVE_RADIUS
            then
                local player = getSpecificPlayer and getSpecificPlayer(0) or (getPlayer and getPlayer()) or nil
                if not player or distanceBetween(actor, player) <= MAX_PLAYER_DISTANCE then
                    threat, reason = scan.nearest, "aggressive_proximity"
                end
            end
        end
    end

    if threat then
        runtime.lastThreat = threat
        runtime.lastValidThreatAtMs = now
        setEngaged(record, actor, brain, true, reason, threat)
        return true
    end

    if combat.state == "engaged"
        and now - (tonumber(runtime.lastValidThreatAtMs) or 0) < THREAT_MEMORY_MS
        and runtime.lastThreat
        and isOrdinaryZombie(runtime.lastThreat)
    then
        setEngaged(record, actor, brain, true, combat.reason or "threat_memory", runtime.lastThreat, false)
        return true
    end

    setEngaged(record, actor, brain, false, "no_valid_threat", nil)
    return false
end

-- Legacy callers still expect these functions. Bandits-backed companions use
-- update() as a combat gate and leave execution to Bandits ManageCombat.
function Combat.buildContext(record, actor)
    return { record = record, actor = actor, threatPos = nil, hostile = nil, threatScore = 0 }
end

function Combat.chooseIntent(record, actor, ctx)
    return nil
end
