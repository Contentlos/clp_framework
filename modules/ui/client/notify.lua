--[[
    clp_framework — Notify (Client, Phase 4)

    Server-/Client-Notify Bridge zur NUI. Server sendet CLP.Events.UINotify
    (Tabelle: { message, type, duration }), Client rendert in #clp-notify-stack.
]]

CLP.UI = CLP.UI or {}

--- Zeigt eine Notification lokal an.
--- @param message string
--- @param ntype string?      'info' (default) | 'success' | 'warning' | 'error'
--- @param duration number?   in ms (default 4000)
function CLP.UI.Notify(message, ntype, duration)
    SendNUIMessage({
        action   = 'notify',
        message  = tostring(message or ''),
        type     = ntype or 'info',
        duration = tonumber(duration) or 4000,
    })
end

-- Server-Side Notify (Phase 2+) — CLP.Notify(src, msg, type, duration) -> hier
RegisterNetEvent(CLP.Events.UINotify, function(data)
    if type(data) == 'table' then
        CLP.UI.Notify(data.message, data.type, data.duration)
    elseif type(data) == 'string' then
        CLP.UI.Notify(data)
    end
end)

-- ESX-Kompat: Resource lauschen haeufig auf 'esx:showNotification'
RegisterNetEvent('esx:showNotification', function(message, ntype, duration)
    CLP.UI.Notify(message, ntype, duration)
end)
