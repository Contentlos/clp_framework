--[[
    clp_framework — Player-Manager

    Verwaltet das Online-Set aller geladenen Spieler. In Phase 0 weitgehend
    leer (Skeleton-Mode), die Methoden sind aber schon da — andere Module
    sollen sie aufrufen können ohne in Phase 1 neu verdrahtet zu werden.

    Public API:
        CLP.GetPlayer(src)            → Player | nil
        CLP.GetPlayers()              → table<src, Player>
        CLP.GetPlayerByCitizenId(id)  → Player | nil
        CLP.GetPlayerByIdentifier(id) → Player | nil
        CLP.LoadPlayer(src)           → Player
        CLP.UnloadPlayer(src, reason) → void
]]

local PlayerClass = CLP.GetModule('PlayerClass')

-- src → Player
local Online = {}

-- Schnell-Lookups
local ByCitizenId  = {}
local ByIdentifier = {}

-- ============================================================
--  ACCESSORS
-- ============================================================
function CLP.GetPlayer(src)
    if not src then return nil end
    return Online[tonumber(src)]
end

function CLP.GetPlayers()
    -- Wir geben Liste der Source-IDs (kompatibel zu ESX.GetPlayers())
    local out = {}
    for src in pairs(Online) do out[#out + 1] = src end
    return out
end

function CLP.GetOnlinePlayers()
    return Online
end

function CLP.GetPlayerByCitizenId(citizenid)
    return citizenid and ByCitizenId[citizenid] or nil
end

function CLP.GetPlayerByIdentifier(identifier)
    return identifier and ByIdentifier[identifier] or nil
end

-- ============================================================
--  LOAD / UNLOAD
--  Phase 0: erstellt ein Player-Object, lädt aber KEINE Charakter-Daten.
--  Im SkeletonMode wird der Spieler trotzdem registriert, damit die
--  Bridge funktioniert (clp_gmenu erwartet xPlayer auf ESX.GetPlayerFromId).
-- ============================================================
function CLP.LoadPlayer(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if Online[src] then return Online[src] end

    local player = PlayerClass.New(src)
    if not player or not player.identifier then
        CLP.Warn(CLP.L.player_no_identifier, tostring(src))
        return nil
    end

    Online[src] = player
    ByIdentifier[player.identifier] = player

    -- Audit
    if not Config.SkeletonMode and CLP.Log and CLP.Log.audit and player.citizenid then
        CLP.Log.audit(player.citizenid, 'login', { ip = player.idents.ip, source = src }, 'system')
    end

    -- NetEvent
    TriggerEvent(CLP.Events.PlayerLoaded, src, player)
    if Config.EmitEsxEvents then
        -- ESX-Kompatibilität — exakt der Event-Name den clp_gmenu listenet
        TriggerEvent('esx:playerLoaded', src, nil)
    end

    CLP.Log(CLP.L.player_loaded, player:GetFullName(), player.citizenid or '-')
    return player
end

function CLP.UnloadPlayer(src, reason)
    src = tonumber(src)
    if not src or not Online[src] then return end
    local player = Online[src]

    -- Persistieren (no-op in Phase 0)
    pcall(function() player:Save() end)

    -- Indizes aufräumen
    if player.citizenid then ByCitizenId[player.citizenid] = nil end
    if player.identifier then ByIdentifier[player.identifier] = nil end
    Online[src] = nil

    CLP.Identity.Invalidate(src)
    CLP.Log(CLP.L.player_dropped, player:GetFullName(), tostring(reason or 'unknown'))

    TriggerEvent(CLP.Events.PlayerDropped, src, reason, player)
end

-- ============================================================
--  AUTO-SAVE-LOOP  (no-op in SkeletonMode)
-- ============================================================
CreateThread(function()
    while true do
        local wait = tonumber(Config.AutoSaveInterval) or (5 * 60 * 1000)
        Wait(wait)
        if not Config.SkeletonMode then
            for _, player in pairs(Online) do
                pcall(function() player:Save() end)
            end
        end
    end
end)
