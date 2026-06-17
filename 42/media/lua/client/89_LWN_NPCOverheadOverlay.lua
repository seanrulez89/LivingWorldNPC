LWN = LWN or {}
LWN.NPCOverheadOverlay = LWN.NPCOverheadOverlay or {}

local Overlay = LWN.NPCOverheadOverlay

local MAX_DRAW_DISTANCE = 45
local BAR_SEGMENTS = 12
local BAR_OFFSET_Y = 13
local NAME_OFFSET_Y = 155

local function protectedCall(obj, methodName, ...)
    if not obj then return nil end
    local fn = obj[methodName]
    if not fn then return nil end
    local ok, result = pcall(fn, obj, ...)
    if ok then return result end
    return nil
end

local function clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function displayNameFor(record, actor)
    if record and record.identity then
        local first = tostring(record.identity.firstName or "")
        local last = tostring(record.identity.lastName or "")
        local name = (first .. " " .. last):gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then return name end
    end
    return tostring(protectedCall(actor, "getFullName") or (record and record.id) or "NPC")
end

local function healthRatioFor(record, actor)
    local value = nil
    if record and record.stats and record.stats.health ~= nil then
        value = tonumber(record.stats.health)
    end
    if value == nil then
        value = tonumber(protectedCall(actor, "getHealth"))
    end
    if value == nil then
        return 1, 100
    end
    local ratio = value
    if ratio > 1 then
        ratio = ratio / 100
    end
    ratio = clamp01(ratio)
    return ratio, math.floor(ratio * 100 + 0.5)
end

local function healthBarText(ratio, percent)
    ratio = clamp01(ratio)
    local filled = math.floor(ratio * BAR_SEGMENTS + 0.5)
    if filled < 0 then filled = 0 end
    if filled > BAR_SEGMENTS then filled = BAR_SEGMENTS end
    local empty = BAR_SEGMENTS - filled
    return "[" .. string.rep("|", filled) .. string.rep(".", empty) .. "] " .. tostring(percent) .. "%"
end

local function healthColor(ratio)
    ratio = clamp01(ratio)
    if ratio >= 0.60 then
        return 0.25, 1.0, 0.25
    end
    if ratio >= 0.30 then
        return 1.0, 0.85, 0.2
    end
    return 1.0, 0.25, 0.2
end

local function overlayFont()
    if not UIFont then return nil end
    return UIFont.Small or UIFont.NewSmall or UIFont.Medium
end

local function resolveActor(record)
    if not record or not record.id then return nil end
    if LWN.EmbodimentManager and LWN.EmbodimentManager.getUsableActorByNpcId then
        local actor = LWN.EmbodimentManager.getUsableActorByNpcId(record.id)
        if actor then return actor end
    end
    if LWN.EmbodimentManager and LWN.EmbodimentManager.getActor then
        return LWN.EmbodimentManager.getActor(record)
    end
    return nil
end

local function isAliveRecord(record)
    if LWN.PopulationStore and LWN.PopulationStore.isAlive then
        return LWN.PopulationStore.isAlive(record) == true
    end
    return record ~= nil
end

local function actorDrawable(actor)
    if not actor then return false end
    if protectedCall(actor, "isDead") == true then return false end
    if protectedCall(actor, "isDestroyed") == true then return false end
    if protectedCall(actor, "isExistInTheWorld") == false then return false end
    return (protectedCall(actor, "getCurrentSquare") or protectedCall(actor, "getSquare")) ~= nil
end

local function distanceToPlayer(actor)
    local player = getPlayer and getPlayer() or nil
    if not (player and actor) then return nil end
    local ax = tonumber(protectedCall(actor, "getX"))
    local ay = tonumber(protectedCall(actor, "getY"))
    local px = tonumber(protectedCall(player, "getX"))
    local py = tonumber(protectedCall(player, "getY"))
    if not (ax and ay and px and py) then return nil end
    local dx = ax - px
    local dy = ay - py
    return math.sqrt(dx * dx + dy * dy)
end

local function actorScreenPosition(actor)
    if not (IsoUtils and IsoUtils.XToScreen and IsoUtils.YToScreen) then return nil, nil end
    local x = tonumber(protectedCall(actor, "getX"))
    local y = tonumber(protectedCall(actor, "getY"))
    local z = tonumber(protectedCall(actor, "getZ")) or 0
    if not (x and y) then return nil, nil end
    local sx = IsoUtils.XToScreen(x, y, z, 0)
    local sy = IsoUtils.YToScreen(x, y, z, 0)
    if getCameraOffX then sx = sx - getCameraOffX() end
    if getCameraOffY then sy = sy - getCameraOffY() end
    return sx, sy - NAME_OFFSET_Y
end

local function screenVisible(x, y)
    local core = getCore and getCore() or nil
    if not core then return true end
    local w = tonumber(protectedCall(core, "getScreenWidth")) or 0
    local h = tonumber(protectedCall(core, "getScreenHeight")) or 0
    if w <= 0 or h <= 0 then return true end
    return x > -120 and x < w + 120 and y > -80 and y < h + 80
end

local function drawTextCenter(tm, font, x, y, text, r, g, b, a)
    tm:DrawStringCentre(font, x - 1, y - 1, text, 0, 0, 0, a)
    tm:DrawStringCentre(font, x + 1, y + 1, text, 0, 0, 0, a)
    tm:DrawStringCentre(font, x, y, text, r, g, b, a)
end

function Overlay.onPostUIDraw()
    if not (LWN.PopulationStore and LWN.PopulationStore.eachNPC) then return end
    local tm = getTextManager and getTextManager() or nil
    local font = overlayFont()
    if not (tm and font) then return end

    LWN.PopulationStore.eachNPC(function(record)
        if not (record and record.embodiment and record.embodiment.state == "embodied") then return end
        if isAliveRecord(record) ~= true then return end

        local actor = resolveActor(record)
        if actorDrawable(actor) ~= true then return end

        local distance = distanceToPlayer(actor)
        if distance and distance > MAX_DRAW_DISTANCE then return end

        local sx, sy = actorScreenPosition(actor)
        if not (sx and sy and screenVisible(sx, sy)) then return end

        local ratio, percent = healthRatioFor(record, actor)
        local name = displayNameFor(record, actor)
        local bar = healthBarText(ratio, percent)
        local r, g, b = healthColor(ratio)

        drawTextCenter(tm, font, sx, sy, name, 1, 1, 1, 0.95)
        drawTextCenter(tm, font, sx, sy + BAR_OFFSET_Y, bar, r, g, b, 0.95)
    end)
end
