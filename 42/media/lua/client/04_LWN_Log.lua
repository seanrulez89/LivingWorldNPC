LWN = LWN or {}
LWN.Log = LWN.Log or {}

local Log = LWN.Log

Log.Runtime = Log.Runtime or {
    sequence = 0,
    lastStates = {},
    lastRateAt = {},
}

local FIELD_ORDER = {
    "npcId",
    "name",
    "teamId",
    "slot",
    "stage",
    "state",
    "from",
    "to",
    "command",
    "status",
    "intent",
    "policy",
    "stance",
    "guideline",
    "reason",
    "detail",
    "item",
    "slotName",
    "source",
    "scenario",
    "carrier",
    "target",
    "ok",
    "health",
    "distance",
    "targetDistance",
    "stress",
    "morale",
    "cohesion",
    "count",
    "task",
    "actor",
    "x",
    "y",
    "z",
}

local function config()
    return (LWN.Config and LWN.Config.Logging) or {}
end

local function nowMs()
    if getTimestampMs then return getTimestampMs() end
    return math.floor((os and os.clock and os.clock() or 0) * 1000)
end

local function worldAgeHours()
    local gameTime = getGameTime and getGameTime() or nil
    return gameTime and gameTime:getWorldAgeHours() or 0
end

local function safeText(value)
    if value == nil then return "nil" end
    local text = tostring(value)
    text = text:gsub("[\r\n|]", " ")
    return text
end

local function levelEnabled(level)
    local cfg = config()
    if cfg.Enabled == false then return false end
    if level == "debug" and cfg.Debug ~= true then return false end
    return true
end

local function rootDebug()
    local root = nil
    if LWN.PopulationStore and LWN.PopulationStore.root then
        local ok, result = pcall(LWN.PopulationStore.root)
        if ok then root = result end
    elseif ModData and ModData.getOrCreate and LWN.Config and LWN.Config.ModDataTag then
        local ok, result = pcall(ModData.getOrCreate, LWN.Config.ModDataTag)
        if ok then root = result end
    end
    if not root then return nil end
    root.debug = root.debug or {}
    return root.debug
end

local function appendBuffer(entry)
    local cfg = config()
    if cfg.BufferEnabled == false then return end
    local debug = rootDebug()
    if not debug then return end
    debug.logBuffer = debug.logBuffer or {}
    debug.logSequence = Log.Runtime.sequence
    local buffer = debug.logBuffer
    buffer[#buffer + 1] = entry
    local maxEntries = tonumber(cfg.MaxBufferEntries) or 300
    while #buffer > maxEntries do
        table.remove(buffer, 1)
    end
end

local function orderedKeys(fields)
    local seen = {}
    local keys = {}
    for i = 1, #FIELD_ORDER do
        local key = FIELD_ORDER[i]
        if fields[key] ~= nil then
            keys[#keys + 1] = key
            seen[key] = true
        end
    end
    local rest = {}
    for key in pairs(fields) do
        if not seen[key] then
            rest[#rest + 1] = key
        end
    end
    table.sort(rest, function(a, b) return tostring(a) < tostring(b) end)
    for i = 1, #rest do
        keys[#keys + 1] = rest[i]
    end
    return keys
end

local function buildLine(entry)
    local parts = {
        "[LWN][Log]",
        "seq=" .. safeText(entry.seq),
        "level=" .. safeText(entry.level),
        "domain=" .. safeText(entry.domain),
        "event=" .. safeText(entry.event),
        string.format("hour=%.4f", tonumber(entry.hour or 0) or 0),
    }
    local fields = entry.fields or {}
    local keys = orderedKeys(fields)
    for i = 1, #keys do
        local key = keys[i]
        parts[#parts + 1] = safeText(key) .. "=" .. safeText(fields[key])
    end
    return table.concat(parts, " | ")
end

function Log.event(level, domain, event, fields, options)
    level = level or "info"
    if not levelEnabled(level) then return nil end
    options = options or {}
    fields = fields or {}

    if options.rateKey then
        local key = tostring(domain) .. ":" .. tostring(event) .. ":" .. tostring(options.rateKey)
        local now = nowMs()
        local minMs = tonumber(options.rateMs) or tonumber(config().DefaultRateMs) or 0
        local last = tonumber(Log.Runtime.lastRateAt[key]) or 0
        if minMs > 0 and now - last < minMs then
            return nil
        end
        Log.Runtime.lastRateAt[key] = now
    end

    Log.Runtime.sequence = (tonumber(Log.Runtime.sequence) or 0) + 1
    local entry = {
        seq = Log.Runtime.sequence,
        level = level,
        domain = domain or "General",
        event = event or "event",
        hour = worldAgeHours(),
        ms = nowMs(),
        fields = fields,
    }
    entry.line = buildLine(entry)
    appendBuffer(entry)
    print(entry.line)
    return entry
end

function Log.debug(domain, event, fields, options)
    return Log.event("debug", domain, event, fields, options)
end

function Log.info(domain, event, fields, options)
    return Log.event("info", domain, event, fields, options)
end

function Log.warn(domain, event, fields, options)
    return Log.event("warn", domain, event, fields, options)
end

function Log.error(domain, event, fields, options)
    return Log.event("error", domain, event, fields, options)
end

function Log.state(domain, key, state, fields, options)
    key = tostring(domain or "General") .. ":" .. tostring(key or "unknown")
    local previous = Log.Runtime.lastStates[key]
    if previous == state then return nil end
    Log.Runtime.lastStates[key] = state
    fields = fields or {}
    fields.from = previous
    fields.to = state
    return Log.event("info", domain, "state_change", fields, options)
end

function Log.recent(limit)
    local debug = rootDebug()
    local buffer = debug and debug.logBuffer or {}
    limit = tonumber(limit) or #buffer
    local start = math.max(1, #buffer - limit + 1)
    local out = {}
    for i = start, #buffer do
        out[#out + 1] = buffer[i]
    end
    return out
end

function Log.dumpRecent(limit)
    local entries = Log.recent(limit)
    for i = 1, #entries do
        print(entries[i].line or buildLine(entries[i]))
    end
    return #entries
end
