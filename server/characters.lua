--[[
    clp_framework — Characters-Layer (Phase 1)

    Verwaltet die `clp_characters`-Tabelle: pro User N Charaktere.
    Jeder Charakter hat eine eigene citizenid (8 Zeichen) als Primary Key.

    Public API:
        Characters.ListByUser(userId)        -> array von rows (soft-deleted ausgeblendet)
        Characters.LoadByCitizenId(cid)      -> row | nil
        Characters.Create(userId, data)      -> ok, citizenid | err
        Characters.SoftDelete(cid)           -> ok
        Characters.UpdateLastSeen(cid)
        Characters.Save(cid, fields)         -> ok      (UPDATE clp_characters)
        Characters.GetLastPlayed(userId)     -> row | nil  (last_seen DESC)
        Characters.CountByUser(userId)       -> n

    Felder die Save persistiert:
        firstname, lastname, gender, birthdate, nationality, phone,
        job, job_grade, on_duty, gang, gang_grade,
        cash, bank, black_money,
        metadata (JSON), position (JSON),
        playtime_seconds, last_seen
]]

local Characters = {}

-- ============================================================
--  HELPER
-- ============================================================
local function safeJson(value)
    if value == nil then return nil end
    local ok, encoded = pcall(json.encode, value)
    if not ok then return nil end
    return encoded
end

local function decodeJson(raw, fallback)
    if not raw or raw == '' then return fallback end
    local ok, decoded = pcall(json.decode, raw)
    if ok then return decoded end
    return fallback
end

local function generateUniqueCitizenId(maxTries)
    maxTries = maxTries or 10
    for _ = 1, maxTries do
        local cid = CLP.Util.generateCitizenId(8)
        local exists = CLP.DB.scalar('SELECT 1 FROM clp_characters WHERE citizenid = ?', { cid })
        if not exists then return cid end
    end
    return nil
end

-- ============================================================
--  PUBLIC API
-- ============================================================

function Characters.ListByUser(userId)
    if not userId then return {} end
    local rows = CLP.DB.query(
        'SELECT citizenid, slot, firstname, lastname, gender, job, job_grade, '
        .. 'cash, bank, black_money, last_seen, created_at '
        .. 'FROM clp_characters '
        .. 'WHERE user_id = ? AND deleted_at IS NULL '
        .. 'ORDER BY slot ASC',
        { userId }
    )
    return rows or {}
end

function Characters.CountByUser(userId)
    if not userId then return 0 end
    local n = CLP.DB.scalar(
        'SELECT COUNT(*) FROM clp_characters WHERE user_id = ? AND deleted_at IS NULL',
        { userId }
    )
    return tonumber(n) or 0
end

function Characters.LoadByCitizenId(cid)
    if not cid then return nil end
    return CLP.DB.single(
        'SELECT * FROM clp_characters WHERE citizenid = ? AND deleted_at IS NULL',
        { cid }
    )
end

function Characters.GetLastPlayed(userId)
    if not userId then return nil end
    return CLP.DB.single(
        'SELECT * FROM clp_characters '
        .. 'WHERE user_id = ? AND deleted_at IS NULL '
        .. 'ORDER BY last_seen DESC, slot ASC LIMIT 1',
        { userId }
    )
end

--- Erstellt einen neuen Charakter.
--- @param userId string  primary identifier des Users (z.B. 'license:abc')
--- @param data   table   { firstname, lastname, gender?, slot?, birthdate?, nationality? }
--- @return boolean ok, string? citizenidOrErr
function Characters.Create(userId, data)
    if not userId then return false, 'no_user' end
    if type(data) ~= 'table' then return false, 'no_data' end

    -- Limit-Check
    local count = Characters.CountByUser(userId)
    if count >= (Config.MaxCharacters or 3) then
        return false, 'max_reached'
    end

    -- Felder validieren / defaulten
    local firstname = tostring(data.firstname or ''):sub(1, 32)
    local lastname  = tostring(data.lastname  or ''):sub(1, 32)
    if firstname == '' or lastname == '' then
        return false, 'name_missing'
    end

    local gender = data.gender
    if gender ~= 'm' and gender ~= 'f' and gender ~= 'd' then gender = 'm' end

    local slot   = tonumber(data.slot) or (count + 1)
    if slot < 1 then slot = 1 end
    if slot > (Config.MaxCharacters or 3) then slot = Config.MaxCharacters or 3 end

    local cid = generateUniqueCitizenId(10)
    if not cid then return false, 'citizenid_collision' end

    local cash  = tonumber(Config.StartCash)        or 500
    local bank  = tonumber(Config.StartBank)        or 5000
    local black = tonumber(Config.StartBlackMoney)  or 0
    local job   = Config.DefaultJob       or 'unemployed'
    local grade = tonumber(Config.DefaultJobGrade) or 0

    local ok, errOrInsertId = pcall(function()
        return CLP.DB.insert(
            'INSERT INTO clp_characters '
            .. '(citizenid, user_id, slot, firstname, lastname, gender, birthdate, nationality, phone, '
            .. ' job, job_grade, cash, bank, black_money, metadata, position) '
            .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            {
                cid, userId, slot, firstname, lastname, gender,
                data.birthdate, data.nationality, data.phone,
                job, grade,
                cash, bank, black,
                safeJson({ hunger = 100, thirst = 100, stress = 0 }),
                nil,
            }
        )
    end)
    if not ok then
        return false, tostring(errOrInsertId or 'db_insert_failed')
    end

    CLP.Log(CLP.L.char_created, firstname, lastname, cid, slot)
    if CLP.Log and CLP.Log.audit then
        CLP.Log.audit(cid, 'char_create', { user = userId, slot = slot }, 'system')
    end
    return true, cid
end

function Characters.SoftDelete(cid)
    if not cid then return false end
    CLP.DB.query(
        'UPDATE clp_characters SET deleted_at = CURRENT_TIMESTAMP WHERE citizenid = ?',
        { cid }
    )
    CLP.Log(CLP.L.char_deleted, cid, cid)
    if CLP.Log and CLP.Log.audit then
        CLP.Log.audit(cid, 'char_delete', {}, 'system')
    end
    return true
end

function Characters.UpdateLastSeen(cid)
    if not cid then return end
    CLP.DB.query('UPDATE clp_characters SET last_seen = CURRENT_TIMESTAMP WHERE citizenid = ?', { cid })
end

--- Persistiert ein Charakter-Dict (async). Nur whitelisted Felder.
--- @param cid string
--- @param fields table  { firstname, lastname, gender, job, job_grade, cash, bank, black_money, metadata, position, ... }
function Characters.Save(cid, fields)
    if not cid or type(fields) ~= 'table' then return false end

    local sets   = {}
    local params = {}

    local function add(col, val)
        sets[#sets + 1] = ('`%s` = ?'):format(col)
        params[#params + 1] = val
    end

    -- Persistierbare Spalten
    local allow = {
        firstname = true, lastname = true, gender = true,
        birthdate = true, nationality = true, phone = true,
        job = true, job_grade = true, on_duty = true,
        gang = true, gang_grade = true,
        cash = true, bank = true, black_money = true,
        playtime_seconds = true,
    }
    for col, val in pairs(fields) do
        if allow[col] then add(col, val) end
    end

    -- JSON-Spalten
    if fields.metadata ~= nil then add('metadata', safeJson(fields.metadata)) end
    if fields.position ~= nil then add('position', safeJson(fields.position)) end

    -- last_seen IMMER mit aktualisieren
    sets[#sets + 1] = '`last_seen` = CURRENT_TIMESTAMP'

    if #sets == 0 then return false end

    params[#params + 1] = cid
    CLP.DB.query(
        ('UPDATE clp_characters SET %s WHERE citizenid = ?'):format(table.concat(sets, ', ')),
        params
    )
    return true
end

-- ============================================================
--  EXPOSE
-- ============================================================
Characters._decodeJson = decodeJson  -- intern fuer player.lua
CLP.RegisterModule('Characters', Characters)
