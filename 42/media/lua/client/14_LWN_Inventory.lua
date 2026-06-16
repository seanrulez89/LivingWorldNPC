LWN = LWN or {}
LWN.Inventory = LWN.Inventory or {}

local Inventory = LWN.Inventory

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function nowHour()
    return getGameTime() and getGameTime():getWorldAgeHours() or 0
end

local function ensure(record)
    if LWN.PopulationStore and LWN.PopulationStore.ensureRecordShape then
        LWN.PopulationStore.ensureRecordShape(record)
    end
    record.inventory = record.inventory or {}
    record.inventory.items = record.inventory.items or {}
    record.inventory.equipment = record.inventory.equipment or {}
    record.inventory.lastChangeReason = record.inventory.lastChangeReason or nil
    record.inventory.lastChangedAt = record.inventory.lastChangedAt or nil
    return record.inventory
end

local function itemFullType(item)
    return item and (protectedCall(item, "getFullType") or protectedCall(item, "getType")) or nil
end

local function safeSize(list)
    if not list then return 0 end
    return tonumber(protectedCall(list, "size")) or 0
end

local function actorItemCounts(actor)
    local counts = {}
    local inventory = protectedCall(actor, "getInventory")
    local items = protectedCall(inventory, "getItems")
    local size = tonumber(protectedCall(items, "size")) or 0
    for i = 0, size - 1 do
        local fullType = itemFullType(protectedCall(items, "get", i))
        if fullType then
            counts[fullType] = (counts[fullType] or 0) + 1
        end
    end
    return counts, size
end

local function findActorItem(actor, fullType)
    if not actor or not fullType then return nil end
    local inventory = protectedCall(actor, "getInventory")
    local items = protectedCall(inventory, "getItems")
    local size = tonumber(protectedCall(items, "size")) or 0
    for i = 0, size - 1 do
        local item = protectedCall(items, "get", i)
        if itemFullType(item) == fullType then
            return item
        end
    end
    return nil
end

local function actorHasExactItem(actor, expected)
    if not actor or not expected then return false end
    local inventory = protectedCall(actor, "getInventory")
    local items = protectedCall(inventory, "getItems")
    local size = tonumber(protectedCall(items, "size")) or 0
    for i = 0, size - 1 do
        if protectedCall(items, "get", i) == expected then
            return true
        end
    end
    return false
end

local function findWornItem(actor, wearLocation)
    if not actor or not wearLocation then return nil end
    return protectedCall(actor, "getWornItem", wearLocation)
end

local function ensureActorItem(actor, fullType, allowCreate)
    if not actor or not fullType then return nil, false end
    local existing = findActorItem(actor, fullType)
    if existing then return existing, false end
    if allowCreate ~= true then return nil, false end
    local inventory = protectedCall(actor, "getInventory")
    local item = protectedCall(inventory, "AddItem", fullType)
    return item, item ~= nil
end

local function recordItemCounts(inv)
    local counts = {}
    for _, entry in ipairs(inv.items or {}) do
        local fullType = entry and entry.fullType or entry and entry.itemId or nil
        local count = tonumber(entry and entry.count or 1) or 1
        if fullType then
            counts[fullType] = (counts[fullType] or 0) + count
        end
    end
    return counts
end

local function setChanged(inv, reason)
    inv.lastChangeReason = reason or "inventory_changed"
    inv.lastChangedAt = nowHour()
end

local function refreshActorVisuals(actor, reason)
    protectedCall(actor, "onWornItemsChanged")
    protectedCall(actor, "resetModel")
    protectedCall(actor, "resetModelNextFrame")
    local modData = protectedCall(actor, "getModData")
    if modData then
        modData.LWN_LastInventoryVisualRefresh = reason or "inventory_sync"
        modData.LWN_LastInventoryVisualRefreshAt = nowHour()
    end
end

local function resolveWearLocation(item)
    if not item then return nil end
    local bodyLocation = protectedCall(item, "getBodyLocation")
    if bodyLocation and bodyLocation ~= "" then return bodyLocation end
    local canEquip = protectedCall(item, "canBeEquipped")
    if canEquip and canEquip ~= "" then return canEquip end
    return nil
end

local function isWearLocation(value)
    value = tostring(value or "")
    return value ~= ""
        and value ~= "Primary"
        and value ~= "Secondary"
        and value ~= "BothHands"
        and value ~= "TwoHands"
end

local function clearHandsHoldingItem(actor, item)
    if not actor or not item then return end
    if protectedCall(actor, "getPrimaryHandItem") == item then
        protectedCall(actor, "setPrimaryHandItem", nil)
    end
    if protectedCall(actor, "getSecondaryHandItem") == item then
        protectedCall(actor, "setSecondaryHandItem", nil)
    end
end

local function recordCount(inv, itemId)
    local count = 0
    for _, entry in ipairs(inv.items or {}) do
        local fullType = entry and (entry.fullType or entry.itemId)
        if fullType == itemId then
            count = count + (tonumber(entry.count or 1) or 1)
        end
    end
    return count
end

function Inventory.snapshot(record, actor)
    if not record then return nil end
    local inv = ensure(record)
    local equipment = inv.equipment or {}
    local actorCounts, actorTotal = actorItemCounts(actor)
    local primary = itemFullType(protectedCall(actor, "getPrimaryHandItem"))
    local secondary = itemFullType(protectedCall(actor, "getSecondaryHandItem"))

    return {
        version = 1,
        record = {
            items = inv.items or {},
            counts = recordItemCounts(inv),
            primaryWeapon = equipment.primaryWeapon,
            secondaryWeapon = equipment.secondaryWeapon,
            bag = equipment.bag,
            clothing = equipment.clothing or {},
        },
        actor = {
            counts = actorCounts,
            totalItems = actorTotal,
            primaryHand = primary,
            secondaryHand = secondary,
            wornCount = safeSize(protectedCall(actor, "getWornItems")),
            itemVisualCount = safeSize(protectedCall(actor, "getItemVisuals")),
        },
        supplies = {
            foodDays = tonumber(inv.foodDays or 0) or 0,
            waterUnits = tonumber(inv.waterUnits or 0) or 0,
            meds = tonumber(inv.meds or 0) or 0,
            ammo = tonumber(inv.ammo or 0) or 0,
            valuables = tonumber(inv.valuables or 0) or 0,
        },
        lastChangeReason = inv.lastChangeReason,
        lastChangedAt = inv.lastChangedAt,
    }
end

function Inventory.recordCount(record, itemId)
    if not record or not itemId then return 0 end
    return recordCount(ensure(record), itemId)
end

function Inventory.actorCount(actor, itemId)
    local counts = actorItemCounts(actor)
    return tonumber(counts and counts[itemId] or 0) or 0
end

function Inventory.itemFullType(item)
    return itemFullType(item)
end

function Inventory.grant(record, itemId, count, reason)
    if not record or not itemId then return false, "record_or_item_missing" end
    local grantReason = tostring(reason or "")
    local debugGrant = grantReason == "debug_grant"
        or grantReason == "debug_squad_weapon"
        or grantReason == "test_only"
    if debugGrant ~= true then
        if LWN.Log and LWN.Log.warn then
            LWN.Log.warn("Inventory", "virtual_grant_blocked", {
                npcId = record.id,
                item = itemId,
                source = "virtual_or_test",
                reason = grantReason ~= "" and grantReason or "missing_reason",
                detail = "existing_item_required",
            })
        end
        return false, "virtual_grant_disabled_existing_item_required"
    end
    local inv = ensure(record)
    count = math.max(1, tonumber(count or 1) or 1)
    inv.items[#inv.items + 1] = {
        fullType = tostring(itemId),
        count = count,
        acquiredAt = nowHour(),
        reason = reason or "grant",
    }
    setChanged(inv, reason or "grant")
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Inventory", "grant_virtual_item", {
            npcId = record.id,
            item = itemId,
            count = count,
            source = "virtual_or_test",
            reason = reason or "grant",
        })
    end
    return true
end

function Inventory.addExistingItemRecord(record, item, reason)
    if not record or not item then return false, "record_or_item_missing" end
    local fullType = itemFullType(item)
    if not fullType then return false, "item_type_missing" end
    local inv = ensure(record)
    inv.items[#inv.items + 1] = {
        fullType = fullType,
        count = 1,
        acquiredAt = nowHour(),
        reason = reason or "existing_item_transfer",
        itemName = protectedCall(item, "getDisplayName") or protectedCall(item, "getName") or fullType,
        source = "existing_item",
    }
    setChanged(inv, reason or "existing_item_transfer")
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Inventory", "record_existing_item", {
            npcId = record.id,
            item = fullType,
            source = "existing_item",
            reason = reason or "existing_item_transfer",
        })
    end
    return true
end

function Inventory.remove(record, itemId, count, reason)
    if not record or not itemId then return false, "record_or_item_missing" end
    local inv = ensure(record)
    count = math.max(1, tonumber(count or 1) or 1)
    local remaining = count
    for i = #inv.items, 1, -1 do
        local entry = inv.items[i]
        local fullType = entry and (entry.fullType or entry.itemId)
        if fullType == itemId then
            local entryCount = tonumber(entry.count or 1) or 1
            local take = math.min(entryCount, remaining)
            entryCount = entryCount - take
            remaining = remaining - take
            if entryCount <= 0 then
                table.remove(inv.items, i)
            else
                entry.count = entryCount
            end
            if remaining <= 0 then break end
        end
    end
    if remaining == count then
        return false, "item_not_found"
    end
    setChanged(inv, reason or "remove")
    return remaining <= 0, remaining > 0 and "partial_remove" or nil
end

function Inventory.setEquipment(record, slot, itemId, reason)
    if not record or not slot then return false, "record_or_slot_missing" end
    local inv = ensure(record)
    if inv.equipment[slot] == itemId then return true end
    inv.equipment[slot] = itemId
    setChanged(inv, reason or "equipment_changed")
    return true
end

function Inventory.setClothing(record, wearLocation, itemId, reason)
    if not record or not wearLocation then return false, "record_or_location_missing" end
    local inv = ensure(record)
    inv.equipment.clothing = inv.equipment.clothing or {}
    if inv.equipment.clothing[wearLocation] == itemId then return true end
    inv.equipment.clothing[wearLocation] = itemId
    setChanged(inv, reason or "clothing_changed")
    return true
end

function Inventory.removeVirtualTestItems(record, itemId, reason)
    if not record or not itemId then return 0 end
    local inv = ensure(record)
    local removed = 0
    for i = #inv.items, 1, -1 do
        local entry = inv.items[i]
        local fullType = entry and (entry.fullType or entry.itemId)
        local isVirtual = entry
            and (entry.source == "virtual_or_test"
                or entry.reason == "squad_weapon"
                or entry.reason == "debug_squad_weapon")
        if fullType == itemId and isVirtual then
            removed = removed + (tonumber(entry.count or 1) or 1)
            table.remove(inv.items, i)
        end
    end
    if removed > 0 then
        setChanged(inv, reason or "remove_virtual_test_item")
        if LWN.Log and LWN.Log.info then
            LWN.Log.info("Inventory", "remove_virtual_test_item", {
                npcId = record.id,
                item = itemId,
                count = removed,
                source = "virtual_or_test",
                reason = reason or "remove_virtual_test_item",
            })
        end
    end
    return removed
end

function Inventory.equipExistingActorItem(record, actor, item, slot, reason)
    if not actor or not item then return { ok = false, detail = "actor_or_item_missing" } end
    local itemId = itemFullType(item)
    if not itemId then return { ok = false, detail = "item_type_missing" } end
    local changed = false
    slot = slot or "auto"
    if slot == "auto" then
        local wearLocation = resolveWearLocation(item)
        slot = isWearLocation(wearLocation) and wearLocation or "primaryWeapon"
    end
    if slot == "primaryWeapon" or slot == "primary" then
        if protectedCall(actor, "getPrimaryHandItem") ~= item then
            protectedCall(actor, "setPrimaryHandItem", item)
            changed = true
        end
        if protectedCall(item, "isRequiresEquippedBothHands") == true
            or protectedCall(item, "isTwoHandWeapon") == true
        then
            if protectedCall(actor, "getSecondaryHandItem") ~= item then
                protectedCall(actor, "setSecondaryHandItem", item)
                changed = true
            end
        end
        Inventory.setEquipment(record, "primaryWeapon", itemId, reason or "equip_existing_item")
    elseif slot == "secondaryWeapon" or slot == "secondary" then
        if protectedCall(actor, "getSecondaryHandItem") ~= item then
            protectedCall(actor, "setSecondaryHandItem", item)
            changed = true
        end
        Inventory.setEquipment(record, "secondaryWeapon", itemId, reason or "equip_existing_item")
    else
        local wearLocation = slot
        if slot == "bag" then
            wearLocation = resolveWearLocation(item) or "Back"
            Inventory.setEquipment(record, "bag", itemId, reason or "equip_existing_item")
        else
            Inventory.setClothing(record, wearLocation, itemId, reason or "equip_existing_item")
        end
        if wearLocation and findWornItem(actor, wearLocation) ~= item then
            protectedCall(actor, "setWornItem", wearLocation, item)
            refreshActorVisuals(actor, reason or "equip_existing_worn_item")
            changed = true
        end
    end

    local result = {
        ok = true,
        detail = "existing_item_equipped",
        item = item,
        changed = changed,
        fullType = itemId,
    }
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Inventory", "equip_existing_item", {
            npcId = record and record.id,
            item = itemId,
            slotName = slot,
            ok = result.ok,
            detail = result.detail,
            changed = changed,
            reason = reason or "equip_existing_item",
        })
    end
    return result
end

function Inventory.equipActorItem(record, actor, itemId, slot, reason, options)
    if not actor or not itemId then return { ok = false, detail = "actor_or_item_missing" } end
    options = options or {}
    local item, added = ensureActorItem(actor, itemId, options.allowCreate == true)
    if not item then return { ok = false, detail = "actor_item_missing" } end

    local changed = added == true
    slot = slot or "primaryWeapon"
    if slot == "primaryWeapon" or slot == "primary" then
        if itemFullType(protectedCall(actor, "getPrimaryHandItem")) ~= itemId then
            protectedCall(actor, "setPrimaryHandItem", item)
            changed = true
        end
        if protectedCall(item, "isRequiresEquippedBothHands") == true
            or protectedCall(item, "isTwoHandWeapon") == true
        then
            if itemFullType(protectedCall(actor, "getSecondaryHandItem")) ~= itemId then
                protectedCall(actor, "setSecondaryHandItem", item)
                changed = true
            end
        end
    elseif slot == "secondaryWeapon" or slot == "secondary" then
        if itemFullType(protectedCall(actor, "getSecondaryHandItem")) ~= itemId then
            protectedCall(actor, "setSecondaryHandItem", item)
            changed = true
        end
    else
        local wearLocation = slot
        if slot == "bag" then
            wearLocation = resolveWearLocation(item) or "Back"
        end
        if wearLocation and itemFullType(findWornItem(actor, wearLocation)) ~= itemId then
            protectedCall(actor, "setWornItem", wearLocation, item)
            refreshActorVisuals(actor, reason or "equip_worn_item")
            changed = true
        end
    end

    local result = {
        ok = true,
        detail = added and "item_added_and_equipped" or "item_equipped",
        item = item,
        added = added,
        changed = changed,
    }
    if (changed == true or added == true) and LWN.Log and LWN.Log.info then
        LWN.Log.info("Inventory", added and "equip_created_item" or "equip_actor_item", {
            npcId = record and record.id,
            item = itemId,
            slotName = slot,
            ok = result.ok,
            detail = result.detail,
            source = added and "created_by_debug_sync" or "actor_inventory",
            changed = changed,
            reason = reason or "equip_actor_item",
        })
    end
    return result
end

function Inventory.transferExistingItemToActor(record, actor, item, options)
    options = options or {}
    if not record or not actor or not item then
        return { ok = false, detail = "record_actor_or_item_missing" }
    end
    if instanceof and not instanceof(item, "InventoryItem") then
        return { ok = false, detail = "not_inventory_item" }
    end

    local targetInventory = protectedCall(actor, "getInventory")
    if not targetInventory then return { ok = false, detail = "target_inventory_missing" } end

    local fullType = itemFullType(item)
    if not fullType then return { ok = false, detail = "item_type_missing" } end

    local sourceContainer = protectedCall(item, "getContainer")
    local worldItem = protectedCall(item, "getWorldItem")
    local alreadyOwned = sourceContainer == targetInventory or actorHasExactItem(actor, item)

    if not alreadyOwned then
        if sourceContainer then
            clearHandsHoldingItem(protectedCall(sourceContainer, "getParent"), item)
            protectedCall(sourceContainer, "DoRemoveItem", item)
            protectedCall(sourceContainer, "Remove", item)
            protectedCall(sourceContainer, "RemoveItem", item)
            protectedCall(sourceContainer, "setDrawDirty", true)
        elseif worldItem then
            protectedCall(worldItem, "removeFromWorld")
            protectedCall(worldItem, "removeFromSquare")
            protectedCall(item, "setWorldItem", nil)
        else
            return { ok = false, detail = "item_has_no_source" }
        end
        protectedCall(targetInventory, "AddItem", item)
        if actorHasExactItem(actor, item) ~= true then
            if sourceContainer then
                protectedCall(sourceContainer, "AddItem", item)
            end
            return { ok = false, detail = "target_inventory_add_failed" }
        end
    end

    local recordOk = Inventory.addExistingItemRecord(record, item, options.reason or "existing_item_transfer")
    local equipResult = nil
    if options.equip == true then
        equipResult = Inventory.equipExistingActorItem(record, actor, item, options.slot or "auto", options.reason or "existing_item_transfer")
    end
    local actorCount = Inventory.actorCount(actor, fullType)
    local result = {
        ok = actorHasExactItem(actor, item) == true,
        detail = alreadyOwned and "already_owned" or "transferred_existing_item",
        recordOk = recordOk == true,
        fullType = fullType,
        actorCount = actorCount,
        equipped = equipResult and equipResult.ok == true or false,
        equipDetail = equipResult and equipResult.detail or nil,
    }
    if LWN.Log and LWN.Log.info then
        LWN.Log.info("Inventory", "transfer_existing_item", {
            npcId = record.id,
            item = fullType,
            source = alreadyOwned and "already_owned" or (sourceContainer and "container" or worldItem and "world_item" or "unknown"),
            ok = result.ok,
            detail = result.detail,
            count = actorCount,
            equipped = result.equipped,
            slotName = options.slot or "auto",
            reason = options.reason or "existing_item_transfer",
        })
    end
    return result
end

function Inventory.syncActorEquipment(record, actor, options)
    options = options or {}
    local snapshot = Inventory.snapshot(record, actor)
    if not snapshot then return { ok = false, detail = "snapshot_missing" } end
    local changed = false
    local applied = {}
    local equipment = snapshot.record or {}
    local apply = options.apply == true
    local syncReason = tostring(options.reason or "sync_actor_equipment")
    local allowCreate = options.allowCreate == true
        and (syncReason == "debug_grant"
            or syncReason == "debug_squad_weapon"
            or syncReason == "test_only")
    if options.allowCreate == true and allowCreate ~= true and LWN.Log and LWN.Log.warn then
        LWN.Log.warn("Inventory", "sync_allow_create_blocked", {
            npcId = record and record.id,
            source = "Inventory.syncActorEquipment",
            reason = syncReason,
            detail = "existing_item_required",
        })
    end

    local function applySlot(slot, itemId)
        if not apply or not itemId then return end
        local result = Inventory.equipActorItem(record, actor, itemId, slot, syncReason, {
            allowCreate = allowCreate == true,
        })
        applied[#applied + 1] = {
            slot = slot,
            itemId = itemId,
            ok = result and result.ok == true,
            detail = result and result.detail or "nil",
        }
        changed = changed or (result and result.changed == true)
    end

    applySlot("primaryWeapon", equipment.primaryWeapon)
    applySlot("secondaryWeapon", equipment.secondaryWeapon)
    applySlot("bag", equipment.bag)
    for wearLocation, itemId in pairs(equipment.clothing or {}) do
        applySlot(wearLocation, itemId)
    end

    local after = changed and Inventory.snapshot(record, actor) or snapshot
    return {
        ok = true,
        detail = apply and "equipment_synced" or "read_only_snapshot",
        changed = changed,
        applied = applied,
        primaryMatches = after.record.primaryWeapon == nil
            or after.record.primaryWeapon == after.actor.primaryHand,
        secondaryMatches = after.record.secondaryWeapon == nil
            or after.record.secondaryWeapon == after.actor.secondaryHand,
        snapshot = after,
    }
end
