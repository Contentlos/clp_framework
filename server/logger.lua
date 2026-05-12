--[[
    clp_framework — Logger (Phase 0: basic console + file)

    In Phase 3 erweitert um Discord-Webhook + strukturiertes Logging.
    Aktuell:
      Logger.info(msg, ...)
      Logger.warn(msg, ...)
      Logger.error(msg, ...)
      Logger.audit(type, payload, actor)  — schreibt in clp_character_log

    File-Logging ist optional (Config.LogToFile) — die Datei wird in einen
    `logs/`-Ordner relativ zur Resource geschrieben. Falls der Ordner nicht
    existiert, fällt es auf "nur Konsole" zurück (LoadResourceFile/SaveResourceFile
    erzwingen Deklaration in fxmanifest, weshalb wir hier zur Vereinfachung
    NICHT in eine Ressourcen-Datei schreiben, sondern stdout-only halten.
    Echte File-Logs folgen in Phase 3 über io.open).
-- ============================================================
]]

local Logger = {}

local function fmt(prefix, msg, ...)
    local s = (select('#', ...) > 0) and string.format(msg, ...) or tostring(msg)
    return ('%s %s %s'):format(CLP.Util.iso8601(), prefix, s)
end

function Logger.info(msg, ...)
    if not Config.LogToConsole then return end
    print(('^2[clp]^7 %s'):format(fmt('INFO ', msg, ...)))
end

function Logger.warn(msg, ...)
    if not Config.LogToConsole then return end
    print(('^3[clp]^7 %s'):format(fmt('WARN ', msg, ...)))
end

function Logger.error(msg, ...)
    if not Config.LogToConsole then return end
    print(('^1[clp]^7 %s'):format(fmt('ERROR', msg, ...)))
end

function Logger.debug(msg, ...)
    if not Config.Debug then return end
    print(('^5[clp]^7 %s'):format(fmt('DEBUG', msg, ...)))
end

--- Schreibt einen Audit-Eintrag in clp_character_log.
--- @param citizenid string
--- @param logType string   z.B. 'login', 'money_add', 'job_change'
--- @param payload table | string
--- @param actor string?    Default 'system'
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
end

CLP.RegisterModule('Log', Logger)
