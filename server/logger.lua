--[[
    clp_framework — Logger (Phase 3)

    Features:
      * Strukturierte Log-Levels: debug | info | warn | error | audit
      * Konsole-Output (immer bei LogToConsole=true) mit FiveM-Color-Codes
      * File-Output: optional, schreibt nach Config.LogFilePath (relativ zur
        Resource). Wir oeffnen die Datei einmal beim Resource-Start und
        appenden line-buffered.
      * Discord-Webhook: pro Level gefiltert via Config.LogDiscordLevels.
        Postet im Embed-Format mit Color, Title, Description, Footer.
      * Audit-DB: Logger.audit(citizenid, type, payload, actor) schreibt in
        clp_character_log + optional Discord-Notify.
      * Backwards-compat: Logger.info, Logger.warn, Logger.error, Logger.debug
        funktionieren weiter wie Phase 0.

    Public:
        CLP.Log(msg, ...)               — Alias zu .info (existed bereits)
        CLP.Log.info / warn / error / debug
        CLP.Log.level(level, msg, ...)  — explizit
        CLP.Log.audit(cid, type, payload, actor)
        CLP.Log.toDiscord(level, title, message, fields?)
]]

local Logger = {}

-- ============================================================
--  LEVELS
-- ============================================================
local LEVEL = { debug = 10, info = 20, warn = 30, error = 40, audit = 50 }
local LEVEL_PREFIX = {
    debug = { tag = '^5DEBUG', color = 0x95a5a6 },
    info  = { tag = '^2INFO ', color = 0x2ecc71 },
    warn  = { tag = '^3WARN ', color = 0xf39c12 },
    error = { tag = '^1ERROR', color = 0xe74c3c },
    audit = { tag = '^6AUDIT', color = 0x3498db },
}

local function fmtMsg(msg, ...)
    if select('#', ...) > 0 then
        local ok, s = pcall(string.format, msg, ...)
        if ok then return s end
        return tostring(msg) .. ' ' .. table.concat({ ... }, ' ')
    end
    return tostring(msg)
end

local function levelEnabled(level)
    local cur = (LEVEL[Config.LogLevel] or LEVEL.info)
    local lv  = (LEVEL[level] or LEVEL.info)
    return lv >= cur
end

-- ============================================================
--  CONSOLE-OUTPUT
-- ============================================================
local function logConsole(level, line)
    if not Config.LogToConsole then return end
    local meta = LEVEL_PREFIX[level] or LEVEL_PREFIX.info
    print(('^7[clp] %s %s %s^7'):format(CLP.Util.iso8601(), meta.tag, line))
end

-- ============================================================
--  FILE-OUTPUT
-- ============================================================
local fileHandle = nil
local fileOpenAttempted = false

local function ensureFile()
    if not Config.LogToFile then return nil end
    if fileHandle then return fileHandle end
    if fileOpenAttempted then return nil end
    fileOpenAttempted = true
    local path = Config.LogFilePath
    if not path or path == '' then return nil end
    -- io.open ist server-side erlaubt; relative Pfade werden vom FiveM-CWD
    -- aufgeloest, was meistens das txData/<server>/resources-Verzeichnis ist.
    -- Wir versuchen den Dir zu erstellen via os.execute (best effort, optional).
    local dir = path:match('^(.*)/[^/]+$')
    if dir then
        pcall(function() os.execute('mkdir -p "' .. dir .. '" 2>/dev/null') end)
    end
    local ok, f = pcall(io.open, path, 'a+')
    if not ok or not f then
        print(('^3[clp] WARN  Logger konnte File "%s" nicht oeffnen.'):format(path))
        return nil
    end
    fileHandle = f
    -- line-buffered
    pcall(function() f:setvbuf('line') end)
    return fileHandle
end

local function logFile(level, line)
    local f = ensureFile(); if not f then return end
    local ok = pcall(function()
        f:write(('%s [%s] %s\n'):format(CLP.Util.iso8601(), level:upper(), line))
    end)
    if not ok then
        -- Bei Schreibfehler File schliessen damit wir nicht in jedes Log einen Fehler reinschreiben
        pcall(function() f:close() end)
        fileHandle = nil
    end
end

-- ============================================================
--  DISCORD-WEBHOOK
-- ============================================================
local function discordLevelAllowed(level)
    local allowed = Config.LogDiscordLevels
    if not allowed then return false end
    if type(allowed) ~= 'table' then return false end
    for _, l in ipairs(allowed) do
        if l == level then return true end
    end
    return false
end

local function postDiscord(level, title, description, fields)
    if not Config.LogDiscordHook or Config.LogDiscordHook == '' then return end
    if not discordLevelAllowed(level) then return end
    local meta = LEVEL_PREFIX[level] or LEVEL_PREFIX.info
    local payload = {
        username = Config.LogDiscordUsername or 'CLP-Framework',
        embeds = {{
            title       = title or ('[' .. level:upper() .. ']'),
            description = description or '',
            color       = meta.color,
            fields      = fields,
            footer      = { text = ('clp_framework v%s | %s'):format(CLP.Version, CLP.Util.iso8601()) },
        }},
    }
    PerformHttpRequest(Config.LogDiscordHook, function(statusCode, _, _)
        if statusCode and statusCode >= 400 then
            print(('^3[clp] WARN  Discord-Webhook returned %d'):format(statusCode))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

--- Ermoeglicht direktes Webhook-Posting ohne Console-Logging.
function Logger.toDiscord(level, title, message, fields)
    postDiscord(level, title, message, fields)
end

-- ============================================================
--  CORE LOG-METHODS
-- ============================================================
function Logger.level(level, msg, ...)
    if not levelEnabled(level) then return end
    local line = fmtMsg(msg, ...)
    logConsole(level, line)
    logFile(level, line)
    if level == 'error' or level == 'warn' then
        postDiscord(level, ('[%s]'):format(level:upper()), line)
    end
end

function Logger.info(msg, ...)  Logger.level('info',  msg, ...) end
function Logger.warn(msg, ...)  Logger.level('warn',  msg, ...) end
function Logger.error(msg, ...) Logger.level('error', msg, ...) end
function Logger.debug(msg, ...) Logger.level('debug', msg, ...) end

-- ============================================================
--  AUDIT  (DB + optional Discord)
-- ============================================================
function Logger.audit(citizenid, logType, payload, actor)
    if not citizenid then return end
    if not CLP.DB then return end
    local enc
    if type(payload) == 'table' then
        enc = json.encode(payload)
    else
        enc = tostring(payload or '')
    end
    CLP.DB.query(
        'INSERT INTO clp_character_log (citizenid, type, payload, actor) VALUES (?, ?, ?, ?)',
        { citizenid, tostring(logType), enc, actor or 'system' }
    )
    -- Optional Discord-Audit (nur bei explizit konfiguriert)
    if Config.LogDiscordAudit and Config.LogDiscordHook then
        local fields = {
            { name = 'Citizen', value = tostring(citizenid), inline = true },
            { name = 'Type',    value = tostring(logType),   inline = true },
            { name = 'Actor',   value = tostring(actor or 'system'), inline = true },
        }
        postDiscord('audit', '[AUDIT] ' .. tostring(logType), '```json\n' .. (enc or '{}') .. '\n```', fields)
    end
end

-- ============================================================
--  CLEANUP
-- ============================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= CLP.ResourceName then return end
    if fileHandle then pcall(function() fileHandle:close() end); fileHandle = nil end
end)

-- ============================================================
--  REGISTER + CALL-METATABLE
--
--  shared/core.lua definiert CLP.Log als Funktion. CLP.RegisterModule
--  ueberschreibt das durch unsere Logger-Tabelle. Damit alter Code wie
--      CLP.Log('Schema applied (%d Statements).', n)
--  weiter funktioniert, geben wir der Tabelle ein __call das wie .info wirkt.
-- ============================================================
setmetatable(Logger, { __call = function(_, msg, ...) Logger.info(msg, ...) end })

CLP.RegisterModule('Log', Logger)
