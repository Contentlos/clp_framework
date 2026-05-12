--[[
    clp_framework — Progress (Client, Phase 0 Stub)
]]

CLP.UI = CLP.UI or {}

--- Zeigt einen Fortschrittsbalken.
--- @param opts table  { label, duration, canCancel? }
--- @param onDone function?
function CLP.UI.Progress(opts, onDone)
    opts = opts or {}
    SendNUIMessage({
        action    = 'progress',
        label     = tostring(opts.label or ''),
        duration  = tonumber(opts.duration) or 3000,
        canCancel = opts.canCancel == true,
    })
    -- Phase 4: echte Cancel-Logik. Aktuell: Wait + onDone.
    CreateThread(function()
        Wait(tonumber(opts.duration) or 3000)
        if onDone then onDone(true) end
    end)
end
