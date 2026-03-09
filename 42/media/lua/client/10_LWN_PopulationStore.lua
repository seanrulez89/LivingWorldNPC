LWN = LWN or {}
LWN.PopulationStore = LWN.PopulationStore or {}

local Store = LWN.PopulationStore

function Store.root()
    local root = ModData.getOrCreate(LWN.Config.ModDataTag)
    if not root.version then
        local fresh = LWN.Schema.newRoot()
        for k, v in pairs(fresh) do root[k] = v end
    end
    return root
end

function Store.ensureNPCTable()
    local root = Store.root()
    root.npcs = root.npcs or {}
    return root.npcs
end

function Store.nextNpcId()
    local root = Store.root()
    local id = string.format("LWN-%06d", root.nextNpcId)
    root.nextNpcId = root.nextNpcId + 1
    return id
end

function Store.addNPC(record)
    local npcs = Store.ensureNPCTable()
    npcs[record.id] = record
    return record
end

function Store.getNPC(id)
    local npcs = Store.ensureNPCTable()
    return npcs[id]
end

function Store.eachNPC(fn)
    local npcs = Store.ensureNPCTable()
    for id, record in pairs(npcs) do
        fn(record, id)
    end
end

function Store.findEmbodiedIds()
    local ids = {}
    Store.eachNPC(function(record)
        if record.embodiment.state == "embodied" then
            table.insert(ids, record.id)
        end
    end)
    return ids
end

function Store.countEmbodied()
    local n = 0
    Store.eachNPC(function(record)
        if record.embodiment.state == "embodied" then
            n = n + 1
        end
    end)
    return n
end

function Store.markTravelled(tiles)
    local root = Store.root()
    root.encounters.travelledTiles = (root.encounters.travelledTiles or 0) + (tiles or 0)
end

function Store.markSlept()
    local root = Store.root()
    root.encounters.hasSlept = true
end

function Store.setVisitedStrategicBuilding(key)
    local root = Store.root()
    root.worldStory.visitedStrategicBuildings[key] = true
end

function Store.addWorldEvent(event)
    local root = Store.root()
    root.worldStory.pendingEvents = root.worldStory.pendingEvents or {}
    table.insert(root.worldStory.pendingEvents, event)
end

function Store.setLegacyCandidates(candidates)
    Store.root().legacy.candidates = candidates or {}
end

function Store.setPendingLegacy(snapshot)
    Store.root().legacy.pending = snapshot
end
function Store.setEmbodiedMeta(npcId, meta)
    local root = Store.root()
    root.embodied = root.embodied or {}
    if meta then
        root.embodied[npcId] = meta
    else
        root.embodied[npcId] = nil
    end
end

function Store.getEmbodiedMeta(npcId)
    local root = Store.root()
    root.embodied = root.embodied or {}
    return root.embodied[npcId]
end
function Store.removeNPC(id)
    local root = Store.root()
    local npcs = Store.ensureNPCTable()
    npcs[id] = nil

    root.embodied = root.embodied or {}
    root.embodied[id] = nil

    root.encounters = root.encounters or {}
    if root.encounters.currentEligibleId == id then
        root.encounters.currentEligibleId = nil
    end
end

function Store.debugState()
    local root = Store.root()
    root.debug = root.debug or {}
    if root.debug.devToolsEnabled == nil then
        root.debug.devToolsEnabled = false
    end
    return root.debug
end
