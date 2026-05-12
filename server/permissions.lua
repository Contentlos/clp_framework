--[[
    clp_framework — Permissions (Server)

    Liefert IsAdmin, GetGroup, HasGroup-Helper. Quellen:
      1. clp_users.group  — primäre Quelle, im Player-Object cached
      2. ACE-Permissions  — wenn Config.AdminAceCheck gesetzt

    Phase 0 hat noch keinen vollen Player-State; wir lesen direkt aus DB
    bei Bedarf (und cachen 60 Sekunden). Wird in Phase 1 mit Player verdrahtet.
]]

local Perms = {}

-- Cache: identifier → { group, ts }
local GroupCache = {}
local CACHE_TTL_MS = 60 * 1000

-- ============================================================
--  Holt die Gruppe aus DB (oder Cache)
-- ============================================================
local function fetchGroupByIdentifier(identifier)
    if not identifier or identifier == '' then return 'user' end
    local cached = GroupCache[identifier]
    if cached and (CLP.Util.nowMs() - cached.ts) < CACHE_TTL_MS then
        return cached.group
    end
    local row = CLP.DB.single('SELECT `group` FROM clp_users WHERE identifier = ?', { identifier })
    local group = (row and row.group) or 'user'
    GroupCache[identifier] = { group = group, ts = CLP.Util.nowMs() }
    return group
end

-- ============================================================
--  PUBLIC API
-- ============================================================

--- Liefert die Gruppe eines Spielers ('user' wenn kein Eintrag in DB).
--- @param src number
--- @return string
function Perms.GetGroup(src)
    local identifier = CLP.Identity.GetPrimary(src)
    if not identifier then return 'user' end
    return fetchGroupByIdentifier(identifier)
end

--- Prüft ob der Spieler in einer der Admin-Gruppen ist
--- (zusätzlich ACE-Check wenn Config.AdminAceCheck gesetzt).
--- @param src number
--- @return boolean
function Perms.IsAdmin(src)
    if not src or src == 0 then return true end -- Konsole gilt als Admin
    -- ACE-Check (zusätzlich, nicht ausschließlich)
    if Config.AdminAceCheck and IsPlayerAceAllowed(tostring(src), Config.AdminAceCheck) then
        return true
    end
    local group = Perms.GetGroup(src)
    if not group then return false end
    for _, g in ipairs(Config.AdminGroups or {}) do
        if group == g then return true end
    end
    return false
end

--- Setzt die Gruppe in DB + Cache.
--- @param identifier string
--- @param group string
function Perms.SetGroup(identifier, group)
    if not identifier or identifier == '' then return false end
    CLP.DB.query('UPDATE clp_users SET `group` = ? WHERE identifier = ?', { group, identifier })
    GroupCache[identifier] = { group = group, ts = CLP.Util.nowMs() }
    return true
end

--- Cache-Eintrag invalidieren (z.B. nach Gruppen-Wechsel via Command).
function Perms.Invalidate(identifier)
    GroupCache[identifier] = nil
end

CLP.RegisterModule('Perms', Perms)
