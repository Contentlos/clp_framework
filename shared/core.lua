--[[
    clp_framework — Core Globals & Loader

    Legt die zwei Namespaces an: CLP (Default) und Framework (Alias).
    Beide zeigen auf das gleiche Tabellen-Objekt — Änderungen an einem
    sind auch am anderen sichtbar.

    Versions-Info / Resource-Metadaten / Modul-Registry.
]]

-- ============================================================
--  GLOBAL NAMESPACE
-- ============================================================
CLP = CLP or {
    -- Versions-Info
    Version        = '0.4.0-phase3',
    Phase          = 3,
    ResourceName   = GetCurrentResourceName(),

    -- Welche Seite läuft? (server | client)
    Side           = IsDuplicityVersion() and 'server' or 'client',

    -- Modul-Registry: jeder Sub-Bereich registriert sich hier
    --   z.B. CLP.Player, CLP.Money, CLP.Jobs, CLP.Inventory ...
    --   So weiß jedes Modul, was schon geladen ist.
    _modules       = {},

    -- Cache für Once-Funktionen (lazy-init)
    _once          = {},
}

-- Alias — zeigt auf dieselbe Tabelle
Framework = CLP

-- ============================================================
--  MODUL-REGISTRIERUNG
--  Jedes geladene Modul ruft CLP.RegisterModule('Name', tbl) auf.
--  Der Name darf nicht doppelt vorkommen (Reload schlägt fehl).
-- ============================================================
function CLP.RegisterModule(name, tbl)
    if type(name) ~= 'string' or name == '' then
        error(('[clp_framework] RegisterModule: Name muss ein String sein (got %s)'):format(type(name)))
    end
    if CLP._modules[name] then
        -- Bei Reload überschreiben wir bewusst — sonst geht onResourceStart neu laden kaputt.
        -- Aber wir loggen es, damit Doppel-Registrierungen erkennbar sind.
        if CLP.Side == 'server' then
            print(('^3[clp_framework]^7 Modul "%s" wird neu registriert.'):format(name))
        end
    end
    CLP._modules[name] = tbl
    CLP[name] = tbl
    return tbl
end

function CLP.GetModule(name)
    return CLP._modules[name]
end

function CLP.HasModule(name)
    return CLP._modules[name] ~= nil
end

-- ============================================================
--  ONCE — Lazy-Initializer (für Bridges, DB-Schemata, etc.)
-- ============================================================
function CLP.Once(key, fn)
    if CLP._once[key] then return CLP._once[key] end
    CLP._once[key] = fn() or true
    return CLP._once[key]
end

-- ============================================================
--  DEBUG-PRINT  — nur wenn Config.Debug true ist
-- ============================================================
function CLP.Dbg(fmt, ...)
    if not Config or not Config.Debug then return end
    local msg = (select('#', ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    if CLP.Side == 'server' then
        print(('^5[clp_framework:debug]^7 %s'):format(msg))
    else
        print(('[clp_framework:debug] %s'):format(msg))
    end
end

-- ============================================================
--  LOG-PRINT (immer sichtbar, ohne Debug-Flag)
-- ============================================================
function CLP.Log(fmt, ...)
    local msg = (select('#', ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    if CLP.Side == 'server' then
        print(('^2[clp_framework]^7 %s'):format(msg))
    else
        print(('[clp_framework] %s'):format(msg))
    end
end

function CLP.Warn(fmt, ...)
    local msg = (select('#', ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    if CLP.Side == 'server' then
        print(('^3[clp_framework]^7 %s'):format(msg))
    else
        print(('[clp_framework:warn] %s'):format(msg))
    end
end

function CLP.Err(fmt, ...)
    local msg = (select('#', ...) > 0) and string.format(fmt, ...) or tostring(fmt)
    if CLP.Side == 'server' then
        print(('^1[clp_framework:ERROR]^7 %s'):format(msg))
    else
        print(('[clp_framework:ERROR] %s'):format(msg))
    end
end
