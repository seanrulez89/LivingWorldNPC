LWN = LWN or {}
LWN.Carriers = LWN.Carriers or {}

local Carrier = {}
LWN.Carriers.none = Carrier

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

function Carrier.kind()
    return "none"
end

function Carrier.canSpawn(record, options)
    return true, "logic_only_no_world_actor"
end

function Carrier.spawn(record, options)
    return {
        ok = true,
        actor = nil,
        detail = "logic_only_no_world_actor",
        handle = {
            kind = "none",
            actor = nil,
            status = "active",
            spawnedAt = worldAgeHours(),
            detail = "logic_only_no_world_actor",
            runtime = {
                mode = "logic_only",
            },
        },
    }
end

function Carrier.sync(record, handle, options)
    handle.runtime = handle.runtime or {}
    handle.runtime.lastMode = options and options.mode or "light"
    return {
        ok = true,
        status = "active",
        detail = "no_world_actor_sync_noop",
    }
end

function Carrier.retire(record, handle, options)
    return {
        ok = true,
        status = "retired",
        detail = options and options.reason or "no_world_actor_retired",
    }
end

function Carrier.isUsable(handle)
    return handle ~= nil and handle.kind == "none"
end

function Carrier.getActor(handle)
    return nil
end
