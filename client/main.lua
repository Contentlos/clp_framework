--[[
    clp_framework — Client-Entry

    Bootstrap des Client-Sides: CLP-Globals werden über shared/core.lua
    bereits angelegt. Hier nur Banner + NetEvent-Setup für Player-Loaded etc.
]]

-- Lokale Spielerdaten (gespiegelt vom Server)
CLP.PlayerData = CLP.PlayerData or {
    identifier = nil,
    citizenid  = nil,
    firstname  = nil,
    lastname   = nil,
    gender     = 'm',
    job        = { name = 'unemployed', grade = 0, label = 'Arbeitslos', grade_label = 'Niemand', salary = 0, on_duty = false },
    money      = { cash = 0, bank = 0, black_money = 0 },
    metadata   = {},
}

CLP.IsLoaded = false

-- ============================================================
--  RESOURCE-START Banner
-- ============================================================
AddEventHandler('onClientResourceStart', function(resName)
    if resName ~= CLP.ResourceName then return end
    print(('[clp_framework] Client geladen — v%s Phase %d'):format(CLP.Version, CLP.Phase))
end)

-- ============================================================
--  RECEIVE PlayerLoaded vom Server
-- ============================================================
RegisterNetEvent(CLP.Events.PlayerLoaded, function(playerData)
    if type(playerData) == 'table' then
        for k, v in pairs(playerData) do CLP.PlayerData[k] = v end
    end
    CLP.IsLoaded = true
    -- Lokales Event für andere Resources die nicht NetEvents lauschen
    TriggerEvent('clp:client:playerLoaded', CLP.PlayerData)
    -- ESX-Kompatibilität: Resources hören häufig 'esx:playerLoaded'
    if Config.EmitEsxEvents then
        TriggerEvent('esx:playerLoaded', CLP.PlayerData)
    end
end)

-- ============================================================
--  MONEY-UPDATE
-- ============================================================
RegisterNetEvent(CLP.Events.MoneyChanged, function(account, oldValue, newValue, reason)
    if CLP.PlayerData and CLP.PlayerData.money then
        CLP.PlayerData.money[account] = newValue
    end
    TriggerEvent('clp:client:moneyChanged', account, oldValue, newValue, reason)
end)

-- ============================================================
--  JOB-UPDATE
-- ============================================================
RegisterNetEvent(CLP.Events.JobChanged, function(newJob, oldJob, reason)
    CLP.PlayerData.job = newJob
    TriggerEvent('clp:client:jobChanged', newJob, oldJob, reason)
end)
