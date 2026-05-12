--[[
    clp_framework — Client-Player-API

    Exponiert Convenience-Funktionen fuer lokale Resources:
        CLP.GetPlayerData()           -> PlayerData-Tabelle
        CLP.GetMoney(account)
        CLP.GetJob()
        CLP.GetCitizenId()
        CLP.GetFullName()
        CLP.IsLoaded                  -> bool

    Charakter-Lifecycle (Phase 1; UI dazu kommt in Phase 4):
        CLP.RequestCharList()         -> fragt Server nach Charakter-Liste
        CLP.SelectCharacter(citizenid)
        CLP.CreateCharacter({...})
        CLP.DeleteCharacter(citizenid)
        CLP.OnCharList(cb)            -> registriert Callback fuer CharList-Antwort
]]

-- ============================================================
--  ACCESSORS
-- ============================================================
function CLP.GetPlayerData()
    return CLP.PlayerData
end

function CLP.GetMoney(account)
    return (CLP.PlayerData.money and CLP.PlayerData.money[account or 'cash']) or 0
end

function CLP.GetJob()
    return CLP.Util.deepcopy(CLP.PlayerData.job or {})
end

function CLP.GetCitizenId()
    return CLP.PlayerData.citizenid
end

function CLP.GetFullName()
    if CLP.PlayerData.firstname and CLP.PlayerData.lastname then
        return CLP.PlayerData.firstname .. ' ' .. CLP.PlayerData.lastname
    end
    return ''
end

-- ============================================================
--  CHARAKTER-LIFECYCLE (Trigger-API)
-- ============================================================
function CLP.RequestCharList()
    TriggerServerEvent(CLP.Events.CharRequestList)
end

function CLP.SelectCharacter(citizenid)
    if not citizenid then return false end
    TriggerServerEvent(CLP.Events.CharSelect, { citizenid = citizenid })
    return true
end

function CLP.CreateCharacter(data)
    TriggerServerEvent(CLP.Events.CharCreate, data or {})
end

function CLP.DeleteCharacter(citizenid)
    if not citizenid then return false end
    TriggerServerEvent(CLP.Events.CharDelete, { citizenid = citizenid })
    return true
end

-- ============================================================
--  CALLBACKS (kleines Pub/Sub fuer NUI / Resources)
-- ============================================================
local charListCbs = {}
function CLP.OnCharList(cb)
    if type(cb) == 'function' then charListCbs[#charListCbs + 1] = cb end
end

RegisterNetEvent(CLP.Events.CharList, function(data)
    for _, cb in ipairs(charListCbs) do
        pcall(cb, data)
    end
    TriggerEvent('clp:client:charList', data)
end)

RegisterNetEvent(CLP.Events.CharCreated, function(data)
    TriggerEvent('clp:client:charCreated', data)
end)

RegisterNetEvent(CLP.Events.CharSelected, function(data)
    TriggerEvent('clp:client:charSelected', data)
end)

RegisterNetEvent(CLP.Events.CharDeleted, function(data)
    TriggerEvent('clp:client:charDeleted', data)
end)
