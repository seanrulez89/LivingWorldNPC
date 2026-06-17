require "ISUI/ISInventoryPage"

LWN = LWN or {}
LWN.NPCInventoryUI = LWN.NPCInventoryUI or {}

local NPCInventory = LWN.NPCInventoryUI

NPCInventory.active = NPCInventory.active or nil
NPCInventory.lastTooFarSpeechAt = NPCInventory.lastTooFarSpeechAt or {}

local MAX_DISTANCE = 6.0
local TICK_INTERVAL_MS = 500
local TOO_FAR_SPEECH_COOLDOWN_MS = 2500

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function nowMs()
    if getTimestampMs then return getTimestampMs() end
    return math.floor((os and os.clock and os.clock() or 0) * 1000)
end

local function worldAgeHours()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function getPlayerByNum(playerNum)
    playerNum = tonumber(playerNum) or 0
    if getSpecificPlayer then return getSpecificPlayer(playerNum) end
    return getPlayer and getPlayer() or nil
end

local function getPlayerDataSafe(playerNum)
    playerNum = tonumber(playerNum) or 0
    if getPlayerData then return getPlayerData(playerNum) end
    return ISPlayerData and ISPlayerData[playerNum + 1] or nil
end

local function getLootPage(playerNum)
    local pdata = getPlayerDataSafe(playerNum)
    if pdata and pdata.lootInventory then return pdata.lootInventory end
    if getPlayerLoot then return getPlayerLoot(tonumber(playerNum) or 0) end
    return nil
end

local function getInventoryPage(playerNum)
    local pdata = getPlayerDataSafe(playerNum)
    if pdata and pdata.playerInventory then return pdata.playerInventory end
    if getPlayerInventory then return getPlayerInventory(tonumber(playerNum) or 0) end
    return nil
end

local function getNpcId(actor)
    if not actor then return nil end
    if LWN.ActorFactory and LWN.ActorFactory.getNpcIdFromActor then
        local npcId = LWN.ActorFactory.getNpcIdFromActor(actor)
        if npcId then return npcId end
    end
    local modData = protectedCall(actor, "getModData")
    return modData and (modData.LWN_NpcId or modData.LWN_LastNpcId) or nil
end

local function displayNameFor(record, actor)
    if record and record.identity then
        local first = tostring(record.identity.firstName or "")
        local last = tostring(record.identity.lastName or "")
        local name = (first .. " " .. last):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then return name end
    end
    return tostring(protectedCall(actor, "getFullName") or getNpcId(actor) or "NPC")
end

local function isAliveRecord(record)
    if LWN.PopulationStore and LWN.PopulationStore.isAlive then
        return LWN.PopulationStore.isAlive(record) == true
    end
    return record ~= nil
end

local function actorUsable(actor)
    if not actor then return false end
    if LWN.ActorFactory and LWN.ActorFactory.isManagedActor then
        return LWN.ActorFactory.isManagedActor(actor) == true
    end
    return getNpcId(actor) ~= nil
end

local function resolveActive()
    local active = NPCInventory.active
    if not (active and active.npcId) then return nil, nil end

    if LWN.EmbodimentManager and LWN.EmbodimentManager.getUsableActorByNpcId then
        local actor, record = LWN.EmbodimentManager.getUsableActorByNpcId(active.npcId)
        if actor and record and actorUsable(actor) and isAliveRecord(record) then
            return actor, record
        end
    end

    local record = LWN.PopulationStore and LWN.PopulationStore.getNPC and LWN.PopulationStore.getNPC(active.npcId) or nil
    local actor = record and LWN.EmbodimentManager and LWN.EmbodimentManager.getActor and LWN.EmbodimentManager.getActor(record) or nil
    if actorUsable(actor) and isAliveRecord(record) then
        return actor, record
    end
    return nil, record
end

local function distanceBetween(a, b)
    if not (a and b) then return nil end
    local ax = tonumber(protectedCall(a, "getX"))
    local ay = tonumber(protectedCall(a, "getY"))
    local bx = tonumber(protectedCall(b, "getX"))
    local by = tonumber(protectedCall(b, "getY"))
    if not (ax and ay and bx and by) then return nil end
    local dx = ax - bx
    local dy = ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function refreshLootPage(playerNum)
    local page = getLootPage(playerNum)
    if page and page.refreshBackpacks then
        protectedCall(page, "refreshBackpacks")
    end
end

local function pageVisible(page)
    local visible = protectedCall(page, "getIsVisible")
    if visible ~= nil then return visible == true end
    visible = protectedCall(page, "isVisible")
    if visible ~= nil then return visible == true end
    return page and page.visible == true or false
end

local function snapshotPage(page)
    if not page then return nil end
    return {
        visible = pageVisible(page),
        collapsed = page.isCollapsed == true,
    }
end

local function applyUnpinnedControls(page)
    if not page then return end
    if page.pin ~= nil then
        page.pin = false
    end
    if page.pinButton then
        protectedCall(page.pinButton, "setVisible", true)
    end
    if page.collapseButton then
        protectedCall(page.collapseButton, "setVisible", false)
    end
end

local function showPageTransient(page)
    if not page then return end
    protectedCall(page, "setVisible", true)
    page.isCollapsed = false
    page.collapseCounter = 0
    applyUnpinnedControls(page)
    protectedCall(page, "clearMaxDrawHeight")
end

local function restorePage(page, snapshot)
    if not page or not snapshot then return end
    applyUnpinnedControls(page)
    page.collapseCounter = 0
    protectedCall(page, "setVisible", snapshot.visible == true)
    if snapshot.visible == true then
        if snapshot.collapsed == true then
            page.isCollapsed = false
            protectedCall(page, "collapseNow")
        else
            page.isCollapsed = false
            protectedCall(page, "clearMaxDrawHeight")
        end
    else
        page.isCollapsed = snapshot.collapsed == true
    end
end

local function restorePages(playerNum, pageState)
    if not pageState then return end
    restorePage(getInventoryPage(playerNum), pageState.inventory)
    restorePage(getLootPage(playerNum), pageState.loot)
end

local function selectContainer(page, inventory)
    if not (page and page.inventoryPane and inventory) then return end
    page.inventoryPane.inventory = inventory
    page.inventoryPane.lastinventory = inventory
    page.inventory = inventory
    page.forceSelectedContainer = inventory
    page.forceSelectedContainerTime = nowMs() + 2000
    if page.inventoryPane.refreshContainer then
        protectedCall(page.inventoryPane, "refreshContainer")
    end
end

local function syncRecord(record, actor, reason)
    if LWN.Inventory and LWN.Inventory.reconcileActorInventory then
        return LWN.Inventory.reconcileActorInventory(record, actor, reason or "npc_inventory_ui")
    end
    return nil
end

local function sayTooFar(actor, npcId, distance)
    if not actor then return end
    npcId = npcId or getNpcId(actor) or "unknown"
    local now = nowMs()
    local previous = tonumber(NPCInventory.lastTooFarSpeechAt[npcId]) or 0
    if previous + TOO_FAR_SPEECH_COOLDOWN_MS > now then
        return
    end
    NPCInventory.lastTooFarSpeechAt[npcId] = now
    protectedCall(actor, "Say", "Come closer to check my inventory.")
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Inventory", "npc_inventory_too_far_speech", {
            npcId = npcId,
            source = "npc_inventory_ui",
            distance = distance and string.format("%.2f", distance) or nil,
            maxDistance = MAX_DISTANCE,
            ok = false,
        }, { rateKey = tostring(npcId), rateMs = TOO_FAR_SPEECH_COOLDOWN_MS })
    end
end

local function isContainerItem(actor, item)
    if not item then return false end
    if protectedCall(item, "getCategory") == "Container" and protectedCall(actor, "isEquipped", item) == true then
        return true
    end
    if protectedCall(item, "isItemType", ItemType and ItemType.KEY_RING) == true then
        return true
    end
    if protectedCall(item, "hasTag", ItemTag and ItemTag.KEY_RING) == true then
        return true
    end
    return false
end

local function addNpcContainerButtons(page, actor, record)
    local inventory = protectedCall(actor, "getInventory")
    if not (page and inventory and page.addContainerButton) then return false end

    protectedCall(inventory, "setExplored", true)
    local name = displayNameFor(record, actor)
    local icon = page.invbasic or getTexture and getTexture("media/ui/Icon_InventoryBasic.png") or nil
    local button = page:addContainerButton(inventory, icon, name, "Living NPC Inventory")
    if button then
        button.LWN_NpcId = record and record.id or getNpcId(actor)
        button.LWN_ActorInventory = true
    end
    selectContainer(page, inventory)

    local items = protectedCall(inventory, "getItems")
    local size = tonumber(protectedCall(items, "size")) or 0
    for i = 0, size - 1 do
        local item = protectedCall(items, "get", i)
        if isContainerItem(actor, item) then
            local container = protectedCall(item, "getInventory")
            if container then
                local itemButton = page:addContainerButton(
                    container,
                    protectedCall(item, "getTex"),
                    protectedCall(item, "getName") or protectedCall(item, "getDisplayName") or "Container",
                    protectedCall(item, "getName") or protectedCall(item, "getDisplayName")
                )
                if itemButton then
                    itemButton.LWN_NpcId = record and record.id or getNpcId(actor)
                    itemButton.LWN_ActorInventory = true
                end
                local visual = protectedCall(item, "getVisual")
                local clothing = protectedCall(item, "getClothingItem")
                if itemButton and visual and clothing then
                    local tint = protectedCall(visual, "getTint", clothing)
                    if tint then
                        itemButton:setTextureRGBA(
                            protectedCall(tint, "getRedFloat") or 1,
                            protectedCall(tint, "getGreenFloat") or 1,
                            protectedCall(tint, "getBlueFloat") or 1,
                            1.0
                        )
                    end
                end
            end
        end
    end

    return true
end

function NPCInventory.clear(reason)
    local active = NPCInventory.active
    if active then
        local actor, record = resolveActive()
        if actor and record then
            syncRecord(record, actor, reason or "npc_inventory_closed")
        end
        if LWN.Log and LWN.Log.info then
            LWN.Log.info("Inventory", "npc_inventory_close", {
                npcId = active.npcId,
                source = "npc_inventory_ui",
                reason = reason or "closed",
                ok = true,
            })
        end
    end
    NPCInventory.active = nil
    restorePages(active and active.playerNum or 0, active and active.pageState or nil)
    refreshLootPage(active and active.playerNum or 0)
    return true
end

function NPCInventory.open(actor, playerNum)
    playerNum = tonumber(playerNum) or 0
    local npcId = getNpcId(actor)
    local record = npcId and LWN.PopulationStore and LWN.PopulationStore.getNPC and LWN.PopulationStore.getNPC(npcId) or nil
    local inventory = protectedCall(actor, "getInventory")
    if not (npcId and record and inventory and actorUsable(actor) and isAliveRecord(record)) then
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Inventory", "npc_inventory_open_failed", {
                npcId = npcId,
                source = "npc_inventory_ui",
                reason = "target_unavailable",
                ok = false,
            })
        end
        return false
    end

    local player = getPlayerByNum(playerNum)
    local distance = distanceBetween(player, actor)
    if distance and distance > MAX_DISTANCE then
        sayTooFar(actor, npcId, distance)
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Inventory", "npc_inventory_open_failed", {
                npcId = npcId,
                source = "npc_inventory_ui",
                reason = "too_far",
                distance = string.format("%.2f", distance),
                maxDistance = MAX_DISTANCE,
                ok = false,
            })
        end
        return false
    end

    local inventoryPage = getInventoryPage(playerNum)
    local lootPage = getLootPage(playerNum)

    NPCInventory.active = {
        npcId = npcId,
        playerNum = playerNum,
        openedAt = worldAgeHours(),
        lastTickAtMs = 0,
        pageState = {
            inventory = snapshotPage(inventoryPage),
            loot = snapshotPage(lootPage),
        },
    }
    syncRecord(record, actor, "npc_inventory_open")

    showPageTransient(inventoryPage)
    showPageTransient(lootPage)
    selectContainer(lootPage, inventory)
    refreshLootPage(playerNum)
    selectContainer(lootPage, inventory)

    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Inventory", "npc_inventory_open", {
            npcId = npcId,
            name = displayNameFor(record, actor),
            source = "npc_inventory_ui",
            count = tonumber(protectedCall(protectedCall(inventory, "getItems"), "size")) or 0,
            ok = true,
        })
    end
    return true
end

function NPCInventory.onRefreshInventoryWindowContainers(page, step)
    if step ~= "beforeFloor" then return end
    local active = NPCInventory.active
    if not (active and page) then return end
    local lootPage = getLootPage(active.playerNum or 0)
    if page ~= lootPage then return end

    local actor, record = resolveActive()
    if not actor then
        NPCInventory.clear("actor_unavailable")
        return
    end

    addNpcContainerButtons(page, actor, record)
end

function NPCInventory.tick()
    local active = NPCInventory.active
    if not active then return end
    local now = nowMs()
    if (tonumber(active.lastTickAtMs) or 0) + TICK_INTERVAL_MS > now then
        return
    end
    active.lastTickAtMs = now

    local actor, record = resolveActive()
    if not actor then
        NPCInventory.clear("actor_unavailable")
        return
    end

    local player = getPlayerByNum(active.playerNum or 0)
    local distance = distanceBetween(player, actor)
    if distance and distance > MAX_DISTANCE then
        sayTooFar(actor, active.npcId, distance)
        NPCInventory.clear("too_far")
        return
    end

    syncRecord(record, actor, "npc_inventory_tick")
end
