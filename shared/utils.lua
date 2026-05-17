--[[
    clp_framework — Allgemeine Util-Funktionen

    Wird unter CLP.Util / Framework.Util registriert.
    Alles Pure (keine FiveM-Natives), damit auf beiden Seiten gleich.
]]

local U = {}

-- ============================================================
--  MATHEMATIK
-- ============================================================
function U.round(n, decimals)
    if not n then return 0 end
    local f = 10 ^ (decimals or 0)
    return math.floor(n * f + 0.5) / f
end

function U.clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

function U.lerp(a, b, t)
    return a + (b - a) * t
end

-- ============================================================
--  TABELLEN
-- ============================================================
function U.deepcopy(t, seen)
    if type(t) ~= 'table' then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local out = {}
    seen[t] = out
    for k, v in pairs(t) do
        out[U.deepcopy(k, seen)] = U.deepcopy(v, seen)
    end
    return setmetatable(out, getmetatable(t))
end

function U.merge(target, source, overwrite)
    if type(source) ~= 'table' then return target end
    for k, v in pairs(source) do
        if overwrite or target[k] == nil then
            target[k] = v
        end
    end
    return target
end

function U.deepMerge(target, source)
    if type(source) ~= 'table' then return target end
    for k, v in pairs(source) do
        if type(v) == 'table' and type(target[k]) == 'table' then
            U.deepMerge(target[k], v)
        else
            target[k] = v
        end
    end
    return target
end

function U.keys(t)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    return out
end

function U.size(t)
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function U.contains(t, value)
    for _, v in pairs(t or {}) do
        if v == value then return true end
    end
    return false
end

function U.indexOf(t, value)
    for i, v in ipairs(t or {}) do
        if v == value then return i end
    end
    return nil
end

-- ============================================================
--  STRINGS
-- ============================================================
function U.trim(s)
    if not s then return '' end
    return (tostring(s):gsub('^%s*(.-)%s*$', '%1'))
end

function U.startsWith(s, prefix)
    return type(s) == 'string' and type(prefix) == 'string' and s:sub(1, #prefix) == prefix
end

function U.endsWith(s, suffix)
    return type(s) == 'string' and type(suffix) == 'string' and s:sub(-#suffix) == suffix
end

function U.split(s, sep)
    sep = sep or ','
    local out = {}
    for part in tostring(s):gmatch('([^' .. sep .. ']+)') do
        out[#out + 1] = part
    end
    return out
end

-- ============================================================
--  UUID / Citizen-ID-Generator
--    Citizen-ID Format: 8 Zeichen, Großbuchstaben + Zahlen (z.B. "K3F7A21B")
--    Wahrscheinlichkeit Kollision bei 1 Mio. Charakteren: ~1.4%
--    -> wir prüfen DB auf Eindeutigkeit beim Erstellen.
-- ============================================================
local CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789' -- ohne 0/O/1/I/L für Lesbarkeit

-- Lua 5.4: math.randomseed verlangt Integer. Einmaliger Seed beim Laden
-- reicht voellig fuer Citizen-IDs (DB-Eindeutigkeitscheck folgt sowieso).
-- Wichtig: os-Lib gibt es im Client-Lua nicht; deshalb guarden.
do
    local seed = 0
    if os and os.time then seed = seed + math.floor(os.time()) end
    if GetGameTimer then seed = seed + math.floor(GetGameTimer()) end
    if seed == 0 then seed = math.floor(math.random() * 2 ^ 31) end
    math.randomseed(seed)
end

function U.generateCitizenId(length)
    length = length or 8
    local out = {}
    for i = 1, length do
        local idx = math.random(1, #CHARS)
        out[i] = CHARS:sub(idx, idx)
    end
    return table.concat(out)
end

function U.uuid4()
    -- RFC 4122 v4 — pseudozufällig, ausreichend für interne IDs
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xF) or math.random(8, 0xB)
        return string.format('%x', v)
    end)
end

-- ============================================================
--  ZEIT-HILFEN
-- ============================================================
function U.now()
    return os.time()
end

function U.nowMs()
    if GetGameTimer then return GetGameTimer() end
    return math.floor(os.clock() * 1000)
end

function U.iso8601(timestamp)
    return os.date('!%Y-%m-%dT%H:%M:%SZ', timestamp or os.time())
end

-- ============================================================
--  REGISTRIEREN
-- ============================================================
CLP.RegisterModule('Util', U)
