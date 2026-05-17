--[[
    clp_framework — Server-Side Notify-Stub (Phase 2)

    Stellt CLP.Notify(src, message, type, duration) bereit.
    Phase 2: minimaler Trigger des UINotify-Events (UI selbst kommt Phase 4 voll).
    Phase 3: wird um Broadcast / Sound / persistente Server-Logs ergaenzt.

    Type-Werte: 'info' | 'success' | 'error' | 'warning' (UI behandelt das)
]]

function CLP.Notify(src, message, ntype, duration)
    if not src or not message then return end
    local payload = {
        message  = tostring(message),
        type     = ntype or 'info',
        duration = tonumber(duration) or 4000,
    }
    if src == -1 then
        TriggerClientEvent(CLP.Events.UINotify, -1, payload)
    else
        TriggerClientEvent(CLP.Events.UINotify, tonumber(src), payload)
    end
end

--- Convenience: an alle online-Spieler senden.
function CLP.NotifyAll(message, ntype, duration)
    CLP.Notify(-1, message, ntype, duration)
end
