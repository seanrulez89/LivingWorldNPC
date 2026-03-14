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

    protectedCall(actor, "setNPC", true)
    protectedCall(actor, "setIsNPC", true)
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
    trace("spawn.ok", record, constructorLabel)
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
    if not actor then
        return {
            ok = true,
            status = "retired",
            detail = "isosurvivor_handle_actor=nil",
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

    protectedCall(actor, "removeFromSquare")
    protectedCall(actor, "removeFromWorld")
    return {
        ok = true,
        status = "retired",
        detail = options and options.reason or "isosurvivor_removed_directly",
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
