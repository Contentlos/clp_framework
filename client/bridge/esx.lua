--[[
    clp_framework — ESX-Bridge (CLIENT)

    Stellt ein ESX-kompatibles Shared-Object client-seitig bereit. Resources
    wie `clp_gmenu` rufen client-seitig:
        local ESX = exports['es_extended']:getSharedObject()
        ESX.GetPlayerData()

    Wir liefern ein gleich geformtes Objekt. Funktioniert nur wenn entweder
    (a) eine es_extended-Forwarder-Resource existiert (siehe Server-Bridge-Kommentar)
    (b) die Resource direkt clp_framework anspricht via:
        local ESX = exports.clp_framework:GetSharedObject()
]]

if not Config.EnableEsxBridge then
    return
end

local Shared = {}

function Shared.GetPlayerData()
    return CLP.PlayerData
end

Shared.PlayerData = CLP.PlayerData  -- Live-Reference (Tabelle wird vom Server-Push mutiert)

function Shared.ShowNotification(msg)
    TriggerEvent('esx:showNotification', msg)
end

-- Sehr einfache Callback-Bridge (Phase 3 baut volle Version)
function Shared.TriggerServerCallback(name, cb, ...)
    local args = {...}
    local cbId = ('cb_%s_%d_%d'):format(name, GetGameTimer(), math.random(100000, 999999))
    local handler
    handler = RegisterNetEvent('__esx_cb_resp:' .. name, function(requestId, ...)
        if requestId ~= cbId then return end
        if cb then cb(...) end
        RemoveEventHandler(handler)
    end)
    TriggerServerEvent('__esx_cb:' .. name, cbId, table.unpack(args))
end

-- Exports
exports('GetSharedObject', function() return Shared end)
exports('GetESX',          function() return Shared end)

CLP.RegisterModule('ESX', Shared)
