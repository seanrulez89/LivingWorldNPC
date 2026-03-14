LWN = LWN or {}
LWN.Carriers = LWN.Carriers or {}

local Carrier = {}
LWN.Carriers.isoplayer = Carrier

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

function Carrier.kind()
    return "isoplayer"
end

function Carrier.canSpawn(record, options)
    if not LWN.ActorFactory or not LWN.ActorFactory.createActor then
        return false, "actor_factory_missing"
    end
    return true, "legacy_isoplayer_available"
end

function Carrier.spawn(record, options)
    record = ensureRecordShape(record)
    local ok, detail = Carrier.canSpawn(record, options)
    if ok ~= true then
        return {
            ok = false,
            actor = nil,
            detail = detail,
            handle = {
                kind = "isoplayer",
                actor = nil,
                status = "failed",
                spawnedAt = worldAgeHours(),
                detail = detail,
            },
        }
    end

    local actor = LWN.ActorFactory.createActor(record, options and options.player or nil)
    local success = actor ~= nil
    return {
        ok = success,
        actor = actor,
        detail = success and "legacy_isoplayer_spawned" or "legacy_isoplayer_spawn_failed",
        handle = {
            kind = "isoplayer",
            actor = actor,
            status = success and "active" or "failed",
            spawnedAt = worldAgeHours(),
            detail = success and "legacy_isoplayer_spawned" or "legacy_isoplayer_spawn_failed",
            runtime = {
                source = "ActorFactory.createActor",
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
            detail = "isoplayer_handle_actor=nil",
        }
    end

    if LWN.ActorSync and LWN.ActorSync.pushRecordToActor then
        LWN.ActorSync.pushRecordToActor(record, actor)
    end

    return {
        ok = true,
        status = "active",
        detail = options and options.mode == "presentation" and "isoplayer_synced_presentation" or "isoplayer_synced",
    }
end

function Carrier.retire(record, handle, options)
    record = ensureRecordShape(record)
    local actor = handle and handle.actor or nil
    if not actor then
        return {
            ok = true,
            status = "retired",
            detail = "isoplayer_handle_actor=nil",
        }
    end

    if LWN.ActorFactory and LWN.ActorFactory.cleanupActor then
        local result = LWN.ActorFactory.cleanupActor(actor, options and options.reason or "carrier_retire") or {}
        return {
            ok = result.completed ~= false,
            status = result.completed == false and (result.deferred and "retiring" or "retire_blocked") or "retired",
            detail = result.detail or options and options.reason or "carrier_retire",
        }
    end

    return {
        ok = false,
        status = "failed",
        detail = "actor_factory_cleanup_missing",
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
