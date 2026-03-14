LWN = LWN or {}
LWN.Carriers = LWN.Carriers or {}

local Carrier = {}
LWN.Carriers.isosurvivor = Carrier

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
    if ok then
        return result
    end
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
        "[LWN][CarrierIsoSurvivor] stage=%s | npcId=%s | detail=%s",
        safeText(stage),
        safeText(record and record.id or nil),
        safeText(detail)
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
    return square, cell
end

local function buildDescriptor(record)
    if LWN.ActorFactory and LWN.ActorFactory.buildDescriptor then
        return LWN.ActorFactory.buildDescriptor(record)
    end

    local female = record and record.identity and record.identity.female == true or false
    if SurvivorFactory and SurvivorFactory.CreateSurvivor then
        return SurvivorFactory.CreateSurvivor(nil, female)
    end
    return nil
end

local function tryInstantiateCandidate(label, fn)
    local ok, result = pcall(fn)
    if ok and result then
        return result, label, nil
    end
    return nil, label, ok and "result=nil" or result
end

local function instantiateIsoSurvivor(record, desc, square, cell)
    if not desc or not square or not cell then
        return nil, "missing_desc_or_square_or_cell", nil
    end

    local x = protectedCall(square, "getX") or 0
    local y = protectedCall(square, "getY") or 0
    local z = protectedCall(square, "getZ") or 0

    local candidates = {
        {
            label = "SurvivorFactory.InstansiateInCell(desc,cell,x,y,z)",
            fn = function()
                if SurvivorFactory and SurvivorFactory.InstansiateInCell then
                    return SurvivorFactory.InstansiateInCell(desc, cell, x, y, z)
                end
                return nil
            end,
        },
        {
            label = "IsoSurvivor.new(desc,cell,x,y,z)",
            fn = function()
                if IsoSurvivor and IsoSurvivor.new then
                    return IsoSurvivor.new(desc, cell, x, y, z)
                end
                return nil
            end,
        },
        {
            label = "IsoSurvivor.new(cell,desc,x,y,z)",
            fn = function()
                if IsoSurvivor and IsoSurvivor.new then
                    return IsoSurvivor.new(cell, desc, x, y, z)
                end
                return nil
            end,
        },
        {
            label = "IsoSurvivor.new(desc,square)",
            fn = function()
                if IsoSurvivor and IsoSurvivor.new then
                    return IsoSurvivor.new(desc, square)
                end
                return nil
            end,
        },
        {
            label = "IsoSurvivor.new(square,desc)",
            fn = function()
                if IsoSurvivor and IsoSurvivor.new then
                    return IsoSurvivor.new(square, desc)
                end
                return nil
            end,
        },
    }

    local errors = {}
    for _, candidate in ipairs(candidates) do
        local actor, usedLabel, err = tryInstantiateCandidate(candidate.label, candidate.fn)
        if actor then
            return actor, usedLabel, nil
        end
        errors[#errors + 1] = string.format("%s => %s", tostring(usedLabel), tostring(err))
    end

    return nil, nil, table.concat(errors, " || ")
end

local function markManaged(record, actor)
    if not actor then return end
    local modData = protectedCall(actor, "getModData")
    if modData and record then
        modData.LWN_NpcId = record.id
        modData.LWN_LastNpcId = record.id
        modData.LWN_CarrierKind = "isosurvivor"
        modData.LWN_CarrierSpike = true
    end

    -- Avoid player-specific NPC setters here. Some IsoSurvivor instances appear to
    -- carry a null internal `player` and throw engine-side NPEs when those setters run.
    protectedCall(actor, "setVisibleToNPCs", true)
    protectedCall(actor, "setSceneCulled", false)
    protectedCall(actor, "setInvisible", false)
    protectedCall(actor, "setGhostMode", false)
    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
    protectedCall(actor, "reloadOutfit")
    protectedCall(actor, "checkUpdateModelTextures")
    protectedCall(actor, "onWornItemsChanged")
end

local function assessRuntimeReadiness(actor)
    if not actor then
        return false, "actor=nil"
    end

    local bodyDamage = protectedCall(actor, "getBodyDamage")
    local stats = protectedCall(actor, "getStats")
    local inventory = protectedCall(actor, "getInventory")
    local square = protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")
    local inWorld = protectedCall(actor, "isExistInTheWorld") == true
    local descriptor = protectedCall(actor, "getDescriptor")

    if not bodyDamage then
        return false, string.format(
            "runtime_core_missing bodyDamage=nil stats=%s inventory=%s inWorld=%s squarePresent=%s descriptor=%s",
            tostring(stats ~= nil),
            tostring(inventory ~= nil),
            tostring(inWorld),
            tostring(square ~= nil),
            tostring(descriptor ~= nil)
        )
    end

    return true, string.format(
        "runtime_ready bodyDamage=%s stats=%s inventory=%s inWorld=%s squarePresent=%s descriptor=%s",
        tostring(bodyDamage ~= nil),
        tostring(stats ~= nil),
        tostring(inventory ~= nil),
        tostring(inWorld),
        tostring(square ~= nil),
        tostring(descriptor ~= nil)
    )
end

local function shallowRetireRejectedSurvivor(record, actor, reason)
    if not actor then
        return {
            ok = true,
            status = "retired",
            detail = "isosurvivor_shallow_retire_actor=nil",
        }
    end

    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_NpcId = nil
    end

    protectedCall(actor, "setInvisible", true)
    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")

    if record and record.embodiment then
        record.embodiment.noAutoRearm = true
        record.embodiment.state = "hidden"
        record.embodiment.actorId = nil
        record.embodiment.cooldownUntilHour = worldAgeHours() + 24
    end

    trace("retire.shallow", record, string.format(
        "reason=%s world=%s squarePresent=%s",
        tostring(reason),
        tostring(protectedCall(actor, "isExistInTheWorld")),
        tostring((protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")) ~= nil)
    ))

    return {
        ok = true,
        status = "retired",
        detail = string.format("isosurvivor_shallow_retire reason=%s", tostring(reason)),
    }
end

function Carrier.kind()
    return "isosurvivor"
end

function Carrier.canSpawn(record, options)
    if not IsoSurvivor then
        return false, "IsoSurvivor_global_missing"
    end
    return true, "IsoSurvivor_available_for_spike"
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
                kind = "isosurvivor",
                actor = nil,
                status = "failed",
                spawnedAt = worldAgeHours(),
                detail = detail,
            },
        }
    end

    local player = options and options.player or nil
    local square, cell = ensureSquare(record, player)
    local desc = buildDescriptor(record)
    local actor, constructorLabel, constructorErr = instantiateIsoSurvivor(record, desc, square, cell)

    if not actor then
        local detailText = string.format("constructor_failed | %s", tostring(constructorErr))
        trace("spawn.failed", record, detailText)
        return {
            ok = false,
            actor = nil,
            detail = detailText,
            handle = {
                kind = "isosurvivor",
                actor = nil,
                status = "failed",
                spawnedAt = worldAgeHours(),
                detail = detailText,
                runtime = {
                    constructorError = constructorErr,
                },
            },
        }
    end

    markManaged(record, actor)
    local runtimeOk, runtimeDetail = assessRuntimeReadiness(actor)
    trace(runtimeOk and "spawn.runtime_ready" or "spawn.runtime_rejected", record, string.format("constructor=%s | %s", tostring(constructorLabel), tostring(runtimeDetail)))

    if runtimeOk ~= true then
        shallowRetireRejectedSurvivor(record, actor, "isosurvivor_runtime_core_missing")

        local detailText = string.format("runtime_rejected via=%s | %s", tostring(constructorLabel), tostring(runtimeDetail))
        return {
            ok = false,
            actor = nil,
            detail = detailText,
            handle = {
                kind = "isosurvivor",
                actor = nil,
                status = "failed",
                spawnedAt = worldAgeHours(),
                detail = detailText,
                runtime = {
                    constructor = constructorLabel,
                    runtimeDetail = runtimeDetail,
                },
            },
        }
    end

    trace("spawn.ok", record, string.format("constructor=%s | %s", tostring(constructorLabel), tostring(runtimeDetail)))
    return {
        ok = true,
        actor = actor,
        detail = string.format("isosurvivor_spawned_via=%s", tostring(constructorLabel)),
        handle = {
            kind = "isosurvivor",
            actor = actor,
            status = "active",
            spawnedAt = worldAgeHours(),
            detail = string.format("isosurvivor_spawned_via=%s", tostring(constructorLabel)),
            runtime = {
                constructor = constructorLabel,
                square = square,
                runtimeDetail = runtimeDetail,
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
            detail = "isosurvivor_handle_actor=nil",
        }
    end

    local runtimeOk, runtimeDetail = assessRuntimeReadiness(actor)
    if runtimeOk ~= true then
        trace("sync.runtime_rejected", record, runtimeDetail)
        return {
            ok = false,
            status = "failed",
            detail = string.format("isosurvivor_runtime_rejected=%s", tostring(runtimeDetail)),
        }
    end

    markManaged(record, actor)
    if LWN.ActorSync and LWN.ActorSync.pushRecordToActor then
        local ok, err = pcall(LWN.ActorSync.pushRecordToActor, record, actor)
        if not ok then
            trace("sync.failed", record, err)
            return {
                ok = false,
                status = "failed",
                detail = string.format("isosurvivor_sync_failed=%s", tostring(err)),
            }
        end
    end

    markManaged(record, actor)
    return {
        ok = true,
        status = "active",
        detail = options and options.mode == "presentation" and "isosurvivor_synced_presentation" or "isosurvivor_synced",
    }
end

function Carrier.retire(record, handle, options)
    record = ensureRecordShape(record)
    local actor = handle and handle.actor or nil
    local reason = options and options.reason or "carrier_retire"
    if not actor then
        return {
            ok = true,
            status = "retired",
            detail = "isosurvivor_handle_actor=nil",
        }
    end

    if reason == "isosurvivor_runtime_core_missing" or reason == "tryEmbody.initial_sync_failed" then
        return shallowRetireRejectedSurvivor(record, actor, reason)
    end

    if LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
        local result = LWN.ActorFactory.cleanupActor(actor, reason) or {}
        return {
            ok = result.completed ~= false,
            status = result.completed == false and (result.deferred and "retiring" or "retire_blocked") or "retired",
            detail = result.detail or reason,
        }
    end

    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")
    return {
        ok = true,
        status = "retired",
        detail = reason,
    }
end

function Carrier.isUsable(handle)
    local actor = handle and handle.actor or nil
    if not actor then return false end
    return protectedCall(actor, "isExistInTheWorld") == true or protectedCall(actor, "getCurrentSquare") ~= nil
end

function Carrier.getActor(handle)
    return handle and handle.actor or nil
end
