--[[
    clp_framework — Datenbank-Layer (oxmysql-Wrapper)

    Wrappt oxmysql-Exports und bietet:
      - applySchema()   — liest server/sql/schema.sql und splittet auf ';' und
                          exec'd jedes Statement einzeln (oxmysql kann keine
                          Multi-Statements). Idempotent.
      - query(sql, params, cb)        — wie oxmysql:query (async)
      - querySync(sql, params)        — sync (nur in Init-Code verwenden!)
      - single(sql, params, cb)       — gibt nur die erste Zeile zurück
      - insert(sql, params, cb)       — gibt insertId zurück
      - update / delete als Aliase auf query
      - kv:get(key) / kv:set(key, value)  — bequemer Key-Value-Zugriff
]]

local DB = {}

-- ============================================================
--  INITIAL CONNECTION CHECK
-- ============================================================
local function hasOxmysql()
    return GetResourceState('oxmysql') == 'started' or GetResourceState('oxmysql') == 'starting'
end

if not hasOxmysql() then
    CLP.Err('oxmysql ist nicht gestartet — clp_framework kann nicht starten. Bitte oxmysql in der server.cfg ensure-en.')
    -- Wir werfen keinen Lua-Error damit andere Resources noch laden können;
    -- aber Calls in DB.* werden fehlschlagen.
end

-- ============================================================
--  RAW QUERIES
-- ============================================================
function DB.query(sql, params, cb)
    if cb then
        return exports.oxmysql:query(sql, params or {}, cb)
    end
    return exports.oxmysql:query_async(sql, params or {})
end

function DB.querySync(sql, params)
    -- Verwendet executeSync — blockierend, NUR für Init.
    -- Für Player-/Geld-Operationen IMMER async!
    if not exports.oxmysql.executeSync then
        return nil, 'oxmysql:executeSync nicht verfügbar'
    end
    return exports.oxmysql:executeSync(sql, params or {})
end

function DB.single(sql, params, cb)
    if cb then
        return exports.oxmysql:single(sql, params or {}, cb)
    end
    return exports.oxmysql:single_async(sql, params or {})
end

function DB.scalar(sql, params, cb)
    if cb then
        return exports.oxmysql:scalar(sql, params or {}, cb)
    end
    return exports.oxmysql:scalar_async(sql, params or {})
end

function DB.insert(sql, params, cb)
    if cb then
        return exports.oxmysql:insert(sql, params or {}, cb)
    end
    return exports.oxmysql:insert_async(sql, params or {})
end

function DB.update(sql, params, cb)
    return DB.query(sql, params, cb)
end

function DB.delete(sql, params, cb)
    return DB.query(sql, params, cb)
end

-- ============================================================
--  SCHEMA-APPLY
--  Liest server/sql/schema.sql aus der Resource und führt jedes Statement
--  einzeln aus. Splittet auf ';' am Zeilenende (vor '\n').
-- ============================================================
local function splitStatements(sqlText)
    local out = {}
    local buf = {}
    for line in (sqlText .. '\n'):gmatch('([^\n]*)\n') do
        -- Kommentar-Zeilen weglassen damit sie nicht versehentlich
        -- ein ';' enthalten und falsch splittet.
        local trimmed = line:gsub('%-%-[^\n]*$', '')
        if trimmed:match('%S') then
            buf[#buf + 1] = trimmed
            if trimmed:match(';%s*$') then
                local stmt = table.concat(buf, '\n')
                stmt = stmt:gsub(';%s*$', '')
                stmt = (stmt:gsub('^%s+', ''):gsub('%s+$', ''))
                if stmt ~= '' then out[#out + 1] = stmt end
                buf = {}
            end
        end
    end
    -- Rest (falls letztes Statement ohne ';' endet)
    if #buf > 0 then
        local stmt = table.concat(buf, '\n')
        stmt = (stmt:gsub('^%s+', ''):gsub('%s+$', ''))
        if stmt ~= '' then out[#out + 1] = stmt end
    end
    return out
end

function DB.applySchema()
    if not Config.AutoApplySchema then
        CLP.Log(CLP.L.db_schema_skipped)
        return false
    end
    local raw = LoadResourceFile(CLP.ResourceName, 'server/sql/schema.sql')
    if not raw or raw == '' then
        CLP.Err('Schema-Datei nicht lesbar: server/sql/schema.sql')
        return false
    end
    local stmts = splitStatements(raw)
    local applied = 0
    for _, stmt in ipairs(stmts) do
        local ok, err = pcall(function()
            DB.querySync(stmt, {})
        end)
        if ok then
            applied = applied + 1
        else
            CLP.Err('Schema-Statement fehlgeschlagen:\n%s\nFehler: %s', stmt, tostring(err))
        end
    end
    CLP.Log(CLP.L.db_schema_applied, applied)
    return applied > 0
end

-- ============================================================
--  KEY-VALUE-STORE
--  Persistent in clp_kv-Tabelle. Werte werden als JSON serialisiert.
-- ============================================================
DB.kv = {}

function DB.kv.get(key, default)
    local row = DB.single('SELECT v FROM clp_kv WHERE k = ?', { key })
    if not row or row.v == nil then return default end
    local ok, decoded = pcall(json.decode, row.v)
    if ok then return decoded end
    return default
end

function DB.kv.set(key, value)
    local encoded = json.encode(value)
    DB.query('REPLACE INTO clp_kv (k, v) VALUES (?, ?)', { key, encoded })
end

function DB.kv.delete(key)
    DB.query('DELETE FROM clp_kv WHERE k = ?', { key })
end

CLP.RegisterModule('DB', DB)
