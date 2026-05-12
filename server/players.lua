--[[
    clp_framework — Player-Manager (Phase 1)

    Online-Set aller geladenen Spieler. Lifecycle:
        playerJoining  -> CLP.LoadPlayer(src)   (ensure user, evtl. Auto-Char-Select)
        char selected  -> CLP.AttachCharacter(src, row) (ueber events.lua / charactersxxx)
        playerDropped  -> CLP.UnloadPlayer(src, reason)

    Public API:
        CLP.GetPlayer(src)              -> Player | nil
        CLP.GetPlayers()                -> array<src>
        CLP.GetOnlinePlayers()          -> table<src, Player>
        CLP.GetPlayerByCitizenId(cid)   -> Player | nil
        CLP.GetPlayerByIdentifier(id)   -> Player | nil
        CLP.LoadPlayer(src)             -> Player | nil   (NUR User-Setup, kein Char)
        CLP.AttachCharacter(src, row)   -> ok            (haengt clp_characters-Row an)
        CLP.UnloadPlayer(src, reason)
        CLP.SaveAll(reason)             -> Anzahl gespeicherter
]]

local PlayerClass = CLP.GetModule('PlayerClass')

local Online       = {}  -- src -> Player
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
    local out = {}
    for src in pairs(Online) do out[#out + 1] = src end
    return out
end

function CLP.GetOnlinePlayers()
    return Online
end

function CLP.GetPlayerByCitizenId(cid)
    return cid and ByCitizenId[cid] or nil
end

function CLP.GetPlayerByIdentifier(identifier)
    return identifier and ByIdentifier[identifier] or nil
end

-- ============================================================
--  LOAD  (Phase 1: User-Setup, OHNE Charakter)
--  Wird in playerJoining gerufen. Wenn AutoCharSelect on,
--  haengt sofort der zuletzt-gespielte (oder ein neuer) Charakter dran.
-- ============================================================
function CLP.LoadPlayer(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if Online[src] then return Online[src] end

    local Users = CLP.GetModule('Users')
    if not Users then
        CLP.Err('Users-Modul nicht verfuegbar (server/users.lua nicht geladen?)')
        return nil
    end

    -- 1) User-Row sicherstellen
    local ok, identifier, _row, _isNew = Users.Ensure(src)
    if not ok or not identifier then
        CLP.Warn(CLP.L.player_no_identifier, tostring(src))
        return nil
    end

    -- 2) Player-Skelett anlegen (noch ohne Charakter)
    local player = PlayerClass.New(src, identifier)
    Online[src] = player
    ByIdentifier[identifier] = player

    -- NOTE: NICHT PlayerLoaded feuern hier; das passiert NACH AttachCharacter.
    CLP.Dbg('player skeleton geladen: src=%s ident=%s', src, identifier)
    return player
end

-- ============================================================
--  ATTACH CHARACTER  (nach Char-Auswahl)
-- ============================================================
function CLP.AttachCharacter(src, row)
    src = tonumber(src)
    local player = Online[src]
    if not player then return false, 'no_player' end
    if type(row) ~= 'table' or not row.citizenid then return false, 'no_row' end

    if not player:AttachCharacter(row) then
        return false, 'attach_failed'
    end

    -- Indizes / Audit / last_seen aktualisieren
    ByCitizenId[player.citizenid] = player
    local Characters = CLP.GetModule('Characters')
    if Characters then Characters.UpdateLastSeen(player.citizenid) end
    if CLP.Log and CLP.Log.audit then
        CLP.Log.audit(player.citizenid, 'login', { ip = player.idents.ip, source = src }, 'system')
    end

    -- Client benachrichtigen
    local data = player:GetSerializableData()
    TriggerClientEvent(CLP.Events.PlayerLoaded, src, data)

    -- Server-side Hook (andere Module hoeren mit)
    TriggerEvent(CLP.Events.PlayerLoaded, src, player)

    -- ESX-Kompat
    if Config.EmitEsxEvents then
        TriggerEvent('esx:playerLoaded', src, data)
    end

    CLP.Log(CLP.L.player_loaded, player:GetFullName(), player.citizenid)
    return true
end

-- ============================================================
--  UNLOAD
-- ============================================================
function CLP.UnloadPlayer(src, reason)
    src = tonumber(src)
    if not src or not Online[src] then return end
    local player = Online[src]

    -- Finaler Save
    if player:IsAttached() then
        local ok = pcall(function() player:Save() end)
        if not ok then
            CLP.Warn('Final-Save fuer src=%s fehlgeschlagen.', src)
        end
        if CLP.Log and CLP.Log.audit then
            CLP.Log.audit(player.citizenid, 'logout', { reason = reason }, 'system')
        end
    end

    -- Indizes aufraeumen
    if player.citizenid  then ByCitizenId[player.citizenid] = nil end
    if player.identifier then ByIdentifier[player.identifier] = nil end
    Online[src] = nil

    CLP.Identity.Invalidate(src)
    CLP.Log(CLP.L.player_dropped, player:GetFullName(), tostring(reason or 'unknown'))
    TriggerEvent(CLP.Events.PlayerDropped, src, reason, player)
end

-- ============================================================
--  SAVE-ALL  (manuell + Auto-Save-Loop + Resource-Stop)
-- ============================================================
function CLP.SaveAll(reason)
    local n = 0
    for _, player in pairs(Online) do
        if player:IsAttached() and player.dirty then
            local ok = pcall(function() player:Save() end)
            if ok then n = n + 1 end
        end
    end
    if n > 0 then
        CLP.Dbg('SaveAll: %d dirty player(s) gespeichert (reason=%s)', n, tostring(reason or 'autosave'))
    end
    return n
end

-- ============================================================
--  AUTO-SAVE-LOOP
-- ============================================================
CreateThread(function()
    while true do
        local wait = tonumber(Config.AutoSaveInterval) or (5 * 60 * 1000)
        Wait(wait)
        if not Config.SkeletonMode then
            CLP.SaveAll('autosave')
        end
    end
end)
