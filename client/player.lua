--[[
    clp_framework — Client-Player-API

    Exponiert Convenience-Funktionen für lokale Resources:
        CLP.GetPlayerData()         → PlayerData-Tabelle
        CLP.GetMoney(account)
        CLP.GetJob()
        CLP.IsLoaded                → bool
]]

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
