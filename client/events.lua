--[[
    clp_framework — Client Event-Wiring (Phase 0: minimal)

    In Phase 1 wandern hier die Spawn-/Respawn-/Death-Hooks rein.
]]

-- ============================================================
--  PLAYER SPAWNED (Phase 0: nur lokales Event feuern)
-- ============================================================
AddEventHandler('playerSpawned', function()
    TriggerEvent(CLP.Events.PlayerSpawned)
    if Config.EmitEsxEvents then
        TriggerEvent('esx:onPlayerSpawn')
    end
end)
