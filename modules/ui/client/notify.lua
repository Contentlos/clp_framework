--[[
    clp_framework — Notify (Client)

    Phase 0: nimmt einen Notify-Aufruf entgegen und schickt ihn als NUI-Message
    an html/script.js. In Phase 4 kommen Typen / Sounds / Animationen dazu.
]]

CLP.UI = CLP.UI or {}

--- Zeigt eine Notification.
--- @param message string
--- @param type string?       'info' (default) | 'success' | 'warning' | 'error'
--- @param duration number?   in ms (default 4000)
function CLP.UI.Notify(message, type, duration)
    SendNUIMessage({
        action   = 'notify',
        message  = tostring(message or ''),
        type     = type or 'info',
        duration = tonumber(duration) or 4000,
    })
end

-- ESX-Kompat: Resource lauschen häufig auf 'esx:showNotification'
RegisterNetEvent('esx:showNotification', function(message, type, duration)
    CLP.UI.Notify(message, type, duration)
end)
