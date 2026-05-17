--[[
    clp_framework — Client Event-Wiring

    Wichtig: 'esx:onPlayerSpawn' darf NUR feuern wenn der Spieler auch
    geladen ist (CLP.IsLoaded == true). Sonst greifen ESX-Resources
    (z.B. skinchanger) auf eine leere PlayerData zu und crashen mit
    "attempt to index a nil value (field 'metadata')".
]]

-- ============================================================
--  PLAYER SPAWNED
-- ============================================================
AddEventHandler('playerSpawned', function()
    TriggerEvent(CLP.Events.PlayerSpawned)
    if Config.EmitEsxEvents and CLP.IsLoaded then
        TriggerEvent('esx:onPlayerSpawn')
    end
end)
