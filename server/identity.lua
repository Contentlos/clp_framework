--[[
    clp_framework — Identity-Resolver

    Aufgabe: aus einem `source` (1..n) die echten Identifier extrahieren
    (license, license2, steam, discord, fivem, ip) und einen "primary"
    Identifier wählen.

    Default Primary: 'license' (siehe Config.PrimaryIdentifier).
    Fallback-Reihenfolge wenn primary fehlt:
        license → license2 → steam → discord → fivem → xbl

    Diese Klasse hat KEINE Datenbank-Logik — die liegt in player.lua/players.lua.
    Identity gibt nur Strings.
]]

local Identity = {}

-- Cache: src → table { primary, all }
local Cache = {}

-- Reihenfolge der Identifier-Typen
local KIND_ORDER = { 'license', 'license2', 'steam', 'discord', 'fivem', 'xbl' }

-- ============================================================
--  ROHE EXTRAKTION
-- ============================================================
local function extractAll(src)
    local out = {}
    local n = GetNumPlayerIdentifiers(src) or 0
    for i = 0, n - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            local kind, value = id:match('^(%w+):(.+)$')
            if kind and value then
                -- 'license:abc' → license
                -- 'license2:abc' → license2
                -- 'steam:11000010abcdef' → steam
                out[kind] = value
            end
        end
    end
    -- Spezialfall: IP separat lesen (nicht in identifiers in allen Versionen)
    local ip = GetPlayerEndpoint(src)
    if ip then
        -- 'a.b.c.d:port' → reine IP
        out.ip = ip:match('^([^:]+)') or ip
    end
    return out
end

local function pickPrimary(idents)
    if not idents then return nil, 'no identifiers' end
    local preferred = Config.PrimaryIdentifier or 'license'
    if idents[preferred] then
        return preferred .. ':' .. idents[preferred]
    end
    for _, k in ipairs(KIND_ORDER) do
        if idents[k] then
            return k .. ':' .. idents[k]
        end
    end
    return nil, 'no usable identifier'
end

-- ============================================================
--  PUBLIC API
-- ============================================================

--- Liefert alle Identifier eines Spielers als Tabelle.
--- @param src number
--- @return table | nil
function Identity.GetAll(src)
    if not src or src == 0 then return nil end
    if Cache[src] and Cache[src].all then return Cache[src].all end
    local all = extractAll(src)
    Cache[src] = Cache[src] or {}
    Cache[src].all = all
    return all
end

--- Liefert den "primary identifier" (z.B. 'license:abcdef').
--- @param src number
--- @return string | nil, string | nil  -- identifier, error
function Identity.GetPrimary(src)
    if Cache[src] and Cache[src].primary then return Cache[src].primary end
    local all = Identity.GetAll(src)
    if not all then return nil, 'no identifiers' end
    local primary, err = pickPrimary(all)
    if primary then
        Cache[src] = Cache[src] or {}
        Cache[src].primary = primary
    end
    return primary, err
end

--- Liefert einen bestimmten Identifier-Typ (z.B. 'steam') OHNE Prefix.
--- @param src number
--- @param kind string
--- @return string | nil
function Identity.Get(src, kind)
    local all = Identity.GetAll(src)
    return all and all[kind] or nil
end

--- Liefert den IPv4/IPv6 des Spielers.
--- @param src number
function Identity.GetIp(src)
    return Identity.Get(src, 'ip')
end

--- Cache für einen Spieler leeren (bei Disconnect).
function Identity.Invalidate(src)
    Cache[src] = nil
end

CLP.RegisterModule('Identity', Identity)
