--[[
    clp_framework — User-Layer (Phase 1)

    Verwaltet die `clp_users`-Tabelle: das physische Konto eines Spielers
    (per primary identifier). Pro User koennen N Charaktere existieren
    (siehe characters.lua).

    Public API:
        Users.Ensure(src)            -> ok, identifier, row, isNew
        Users.GetRow(identifier)     -> row | nil
        Users.UpdateLastSeen(identifier)
        Users.SetGroup(identifier, group)
        Users.IsBanned(identifier)   -> bool, reason

    Schreibt synchron im Connect-Pfad (deferral-zeit ist OK) und async sonst.
]]

local Users = {}

-- ============================================================
--  GET / ENSURE
-- ============================================================

--- Stellt sicher dass eine User-Row existiert. Wird im playerJoining gerufen.
--- @param src number
--- @return boolean ok, string? identifier, table? row, boolean? isNew
function Users.Ensure(src)
    local primary = CLP.Identity.GetPrimary(src)
    if not primary then
        return false, nil, nil, false
    end

    local idents = CLP.Identity.GetAll(src) or {}
    local name   = GetPlayerName(src) or 'Unknown'

    local row = CLP.DB.single(
        'SELECT * FROM clp_users WHERE identifier = ?',
        { primary }
    )

    if row then
        -- bestehender User -> last_seen + last_name aktualisieren (async)
        CLP.DB.query(
            'UPDATE clp_users SET last_seen = CURRENT_TIMESTAMP, last_name = ?, '
            .. 'license = ?, license2 = ?, steam = ?, discord = ?, fivem = ?, ip = ? '
            .. 'WHERE identifier = ?',
            {
                name,
                idents.license, idents.license2, idents.steam,
                idents.discord, idents.fivem, idents.ip,
                primary,
            }
        )
        CLP.Log(CLP.L.user_returning, primary, row['group'] or 'user')
        return true, primary, row, false
    end

    -- neuer User -> INSERT
    CLP.DB.insert(
        'INSERT INTO clp_users '
        .. '(identifier, license, license2, steam, discord, fivem, ip, last_name, `group`) '
        .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            primary,
            idents.license, idents.license2, idents.steam,
            idents.discord, idents.fivem, idents.ip,
            name, 'user',
        }
    )

    local newRow = {
        identifier = primary,
        license    = idents.license,
        license2   = idents.license2,
        steam      = idents.steam,
        discord    = idents.discord,
        fivem      = idents.fivem,
        ip         = idents.ip,
        last_name  = name,
        ['group']  = 'user',
        banned     = 0,
    }
    CLP.Log(CLP.L.user_created, primary)
    return true, primary, newRow, true
end

function Users.GetRow(identifier)
    if not identifier then return nil end
    return CLP.DB.single('SELECT * FROM clp_users WHERE identifier = ?', { identifier })
end

function Users.UpdateLastSeen(identifier)
    if not identifier then return end
    CLP.DB.query('UPDATE clp_users SET last_seen = CURRENT_TIMESTAMP WHERE identifier = ?', { identifier })
end

function Users.SetGroup(identifier, group)
    if not identifier or not group then return false end
    CLP.DB.query('UPDATE clp_users SET `group` = ? WHERE identifier = ?', { tostring(group), identifier })
    if CLP.Perms and CLP.Perms.Invalidate then
        CLP.Perms.Invalidate(identifier)
    end
    return true
end

--- Prueft ob der User gebannt ist. Phase 1 minimal:
--- banned=1 reicht; ban_until-Logik kommt in einem spaeteren Phase.
function Users.IsBanned(identifier)
    if not identifier then return false end
    local row = CLP.DB.single(
        'SELECT banned, ban_reason, ban_until FROM clp_users WHERE identifier = ?',
        { identifier }
    )
    if not row then return false end
    if (row.banned or 0) ~= 1 then return false end
    -- ban_until in der Zukunft? -> dann gebannt.
    -- (Phase 1: keine genaue Zeit-Vergleichslogik, banned=1 reicht.)
    return true, row.ban_reason or 'gebannt'
end

CLP.RegisterModule('Users', Users)
