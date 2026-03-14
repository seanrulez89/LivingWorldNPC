LWN = LWN or {}
LWN.CarrierAdapter = LWN.CarrierAdapter or {}
LWN.Carriers = LWN.Carriers or {}

local Adapter = LWN.CarrierAdapter
local Carriers = LWN.Carriers
local Store = LWN.PopulationStore
local Embody = LWN.EmbodimentManager

local function ensureRecordShape(record)
    if Store and Store.ensureRecordShape then
        return Store.ensureRecordShape(record)
    end
    return record
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

local function trace(stage, record, handle, detail)
    print(string.format(
        "[LWN][CarrierAdapter] stage=%s | npcId=%s | carrierKind=%s | handleStatus=%s | detail=%s",
        safeText(stage),
        safeText(record and record.id or nil),
        safeText(handle and handle.kind or record and record.embodiment and record.embodiment.carrierKind or nil),
        safeText(handle and handle.status or nil),
        safeText(detail)
    ))
end

local function defaultHandle(record, kind)
    return {
        npcId = record and record.id or nil,
        kind = kind or "none",
        actor = nil,
        status = "idle",
        spawnedAt = nil,
        lastSyncAt = nil,
        lastRetireAt = nil,
        detail = nil,
        runtime = {},
    }
end

function Adapter.getImplementation(kind)
    return Carriers[kind or "none"] or Carriers.none or nil
end

function Adapter.resolveKind(record, options)
    record = ensureRecordShape(record)
    local requested = options and options.kind or nil
    if requested and Carriers[requested] then
        return requested
    end

    local embodiment = record and record.embodiment or nil
    if embodiment and embodiment.preferredCarrierKind and Carriers[embodiment.preferredCarrierKind] then
        return embodiment.preferredCarrierKind
    end
    if embodiment and embodiment.carrierKind and Carriers[embodiment.carrierKind] then
        return embodiment.carrierKind
    end

    return "none"
end

function Adapter.ensureEmbodimentFields(record, kind)
    record = ensureRecordShape(record)
    if not record then return nil end

    record.embodiment = record.embodiment or {}
    record.embodiment.carrierKind = kind or record.embodiment.carrierKind or "none"
    record.embodiment.carrierState = record.embodiment.carrierState or {}
    record.embodiment.lastCarrierChangeAt = worldAgeHours()
    return record
end

function Adapter.buildHandle(record, kind, seed)
    local handle = defaultHandle(record, kind)
    if type(seed) == "table" then
        for k, v in pairs(seed) do
            handle[k] = v
        end
    end
    handle.kind = kind or handle.kind or "none"
    handle.npcId = record and record.id or handle.npcId
    handle.runtime = handle.runtime or {}
    return handle
end

function Adapter.registerHandle(record, handle)
    if not record or not handle then return nil end
    Adapter.ensureEmbodimentFields(record, handle.kind)

    if Embody and Embody.registerCarrierHandle then
        Embody.registerCarrierHandle(record, handle)
    end

    record.embodiment.carrierKind = handle.kind
    record.embodiment.carrierState = record.embodiment.carrierState or {}
    record.embodiment.carrierState.status = handle.status
    record.embodiment.carrierState.detail = handle.detail
    record.embodiment.carrierState.lastSyncAt = handle.lastSyncAt
    record.embodiment.carrierState.lastRetireAt = handle.lastRetireAt
    return handle
end

function Adapter.getHandle(record)
    if not record then return nil end
    if Embody and Embody.getCarrierHandle then
        return Embody.getCarrierHandle(record)
    end
    return nil
end

function Adapter.getActor(handle)
    if not handle then return nil end
    local impl = Adapter.getImplementation(handle.kind)
    if impl and impl.getActor then
        return impl.getActor(handle)
    end
    return handle.actor
end

function Adapter.isUsable(handle)
    if not handle then return false end
    local impl = Adapter.getImplementation(handle.kind)
    if impl and impl.isUsable then
        return impl.isUsable(handle)
    end
    return handle.actor ~= nil
end

function Adapter.spawn(record, options)
    record = ensureRecordShape(record)
    if not record then
        return {
            ok = false,
            kind = "none",
            actor = nil,
            handle = nil,
            detail = "record=nil",
        }
    end

    local kind = Adapter.resolveKind(record, options)
    local impl = Adapter.getImplementation(kind)
    if not impl or not impl.spawn then
        return {
            ok = false,
            kind = kind,
            actor = nil,
            handle = nil,
            detail = "carrier_impl_missing",
        }
    end

    Adapter.ensureEmbodimentFields(record, kind)
    local result = impl.spawn(record, options or {}) or {}
    local handle = Adapter.buildHandle(record, kind, result.handle or {
        actor = result.actor,
        status = result.ok == false and "failed" or "active",
        detail = result.detail,
        spawnedAt = worldAgeHours(),
    })

    if result.ok ~= false then
        handle.spawnedAt = handle.spawnedAt or worldAgeHours()
        Adapter.registerHandle(record, handle)
    end

    trace("spawn", record, handle, result.detail)
    result.kind = kind
    result.handle = handle
    result.actor = result.actor or handle.actor
    if result.ok == nil then
        result.ok = result.actor ~= nil or kind == "none"
    end
    return result
end

function Adapter.sync(record, handle, options)
    record = ensureRecordShape(record)
    handle = handle or Adapter.getHandle(record)
    if not record or not handle then
        return {
            ok = false,
            detail = "record_or_handle_missing",
        }
    end

    local impl = Adapter.getImplementation(handle.kind)
    if not impl or not impl.sync then
        return {
            ok = false,
            detail = "carrier_sync_missing",
            handle = handle,
        }
    end

    local result = impl.sync(record, handle, options or {}) or {}
    handle.lastSyncAt = worldAgeHours()
    handle.status = result.ok == false and (handle.status or "active") or (result.status or handle.status or "active")
    handle.detail = result.detail or handle.detail
    Adapter.registerHandle(record, handle)
    trace("sync", record, handle, result.detail)
    result.handle = handle
    if result.ok == nil then result.ok = true end
    return result
end

function Adapter.retire(record, handle, options)
    record = ensureRecordShape(record)
    handle = handle or Adapter.getHandle(record)
    if not record then
        return {
            ok = false,
            detail = "record=nil",
        }
    end

    if not handle then
        return {
            ok = true,
            detail = "handle=nil",
        }
    end

    local impl = Adapter.getImplementation(handle.kind)
    if not impl or not impl.retire then
        return {
            ok = false,
            detail = "carrier_retire_missing",
            handle = handle,
        }
    end

    local result = impl.retire(record, handle, options or {}) or {}
    handle.lastRetireAt = worldAgeHours()
    handle.status = result.ok == false and (result.status or "retire_blocked") or (result.status or "retired")
    handle.detail = result.detail or handle.detail

    if result.ok ~= false then
        if Embody and Embody.unregisterCarrierHandle then
            Embody.unregisterCarrierHandle(record, options and options.reason or "carrier_retire")
        end
    else
        Adapter.registerHandle(record, handle)
    end

    trace("retire", record, handle, result.detail)
    result.handle = handle
    if result.ok == nil then result.ok = true end
    return result
end

function Adapter.getDebugState(record, handle)
    record = ensureRecordShape(record)
    handle = handle or Adapter.getHandle(record)
    return {
        npcId = record and record.id or nil,
        carrierKind = handle and handle.kind or record and record.embodiment and record.embodiment.carrierKind or nil,
        handleStatus = handle and handle.status or nil,
        actorRef = handle and handle.actor and tostring(handle.actor) or nil,
        spawnedAt = handle and handle.spawnedAt or nil,
        lastSyncAt = handle and handle.lastSyncAt or nil,
        lastRetireAt = handle and handle.lastRetireAt or nil,
        detail = handle and handle.detail or nil,
    }
end
