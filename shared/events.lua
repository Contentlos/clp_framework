--[[
    clp_framework — Event-Konstanten

    Zentrale Definition aller Event-Namen die das Framework auf NetEvent /
    AddEventHandler-Level feuert. Andere Resources sollen NUR diese Konstanten
    nutzen, NIE Strings hartcoden, damit Umbenennungen ein-Stellen-Änderungen sind.

    Konvention für Event-Namen:
        clp:<bereich>:<aktion>
    Beispiele:
        clp:player:loaded
        clp:player:dropped
        clp:player:save
        clp:money:changed
        clp:job:changed
]]

local E = {
    -- Player-Lifecycle
    PlayerConnecting   = 'clp:player:connecting',  -- S: vor Loading (preCheck, identifiers)
    PlayerLoading      = 'clp:player:loading',     -- S→C: send Spinner / Char-Select
    PlayerLoaded       = 'clp:player:loaded',      -- S→C: alle Daten da
    PlayerDropped      = 'clp:player:dropped',     -- S: nach disconnect
    PlayerSpawned      = 'clp:player:spawned',     -- C→S: Ped fertig im Spiel
    PlayerSwitchedChar = 'clp:player:switchedChar',-- bei Charakterwechsel ohne Reconnect

    -- Money
    MoneyChanged       = 'clp:money:changed',      -- C/S: { account, oldValue, newValue, reason }
    MoneyAdded         = 'clp:money:added',        -- nur Add-Events (für Analytics)
    MoneyRemoved       = 'clp:money:removed',

    -- Jobs
    JobChanged         = 'clp:job:changed',        -- { old, new, grade }
    JobDuty            = 'clp:job:duty',           -- { onDuty: bool }

    -- Inventory (Phase 5+)
    InvUpdated         = 'clp:inv:updated',
    InvItemUsed        = 'clp:inv:itemUsed',

    -- Vehicles (Phase 6+)
    VehicleSpawned     = 'clp:veh:spawned',
    VehicleStored      = 'clp:veh:stored',

    -- Doors (Phase 7+)
    DoorToggled        = 'clp:door:toggled',

    -- Sicherheits-Events
    SecurityViolation  = 'clp:security:violation', -- S-only: { src, type, payload }
}

CLP.Events = E
CLP.RegisterModule('Events', E)
