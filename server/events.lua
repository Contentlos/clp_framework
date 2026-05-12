--[[
    clp_framework — Server Event-Wiring

    Verbindet die FiveM-Lifecycle-Events (playerConnecting, playerDropped,
    playerJoining) mit dem Player-Manager.
]]

-- ============================================================
--  PLAYER CONNECTING (Deferrals-Phase)
-- ============================================================
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(('CLP-Framework — prüfe Identifier...'))

    local idents = CLP.Identity.GetAll(src)
    local primary = CLP.Identity.GetPrimary(src)
    if not primary then
        deferrals.done(('Kein gültiger Identifier gefunden. Verbindung abgelehnt.'))
        if setKickReason then
            setKickReason('Kein gültiger Identifier.')
        end
        return
    end

    -- Phase 1+ kommt hier: Ban-Check, Whitelist-Check, etc.
    deferrals.update(('CLP-Framework — willkommen %s!'):format(playerName))
    Wait(50)
    deferrals.done()
    CLP.Dbg('player connecting OK: src=%s primary=%s', src, primary)
end)

-- ============================================================
--  PLAYER JOINING  — Spieler ist verbunden, Ressourcen werden gestreamt
--  Wir laden hier den Player IM SkeletonMode bereits, damit Bridges + Tests
--  funktionieren. In Phase 1 wandert das in eine eigene Char-Select-Phase.
-- ============================================================
AddEventHandler('playerJoining', function()
    local src = source
    if not Config.SkeletonMode then return end
    -- SkeletonMode: minimaler Player-Object so dass clp_gmenu xPlayer.* nutzen kann.
    CLP.LoadPlayer(src)
end)

-- ============================================================
--  PLAYER DROPPED
-- ============================================================
AddEventHandler('playerDropped', function(reason)
    local src = source
    CLP.UnloadPlayer(src, reason)
end)

-- ============================================================
--  RESOURCE STOPPED  — alle Spieler entladen (Save)
-- ============================================================
AddEventHandler('onResourceStop', function(name)
    if name ~= CLP.ResourceName then return end
    CLP.Log(CLP.L.framework_stopped)
    for _, src in ipairs(CLP.GetPlayers()) do
        CLP.UnloadPlayer(src, 'resource_stop')
    end
end)
