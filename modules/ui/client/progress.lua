--[[
    clp_framework — Progress (Client, Phase 4)

    Bottom-Center-Progressbar mit optionalem Cancel (Taste X).
    NUI sendet beim Ablauf oder Cancel den 'progress:done'-Callback.

    Public:
        CLP.UI.Progress(opts, onDone) -> key
            opts = { key?, label, duration, canCancel?, disableMovement? }
            onDone(success: bool) -- success=true wenn nicht gecancelt
        CLP.UI.CancelProgress(key?)

    Auch wenn der Server S2C-Event UIProgressStart feuert, wird das vom
    Server-Notify-Modul nicht direkt genutzt — Phase 4 bleibt client-driven.
    Andere Resources koennen den Event direkt triggern.
]]

CLP.UI = CLP.UI or {}

local Active = {}   -- [key] = { onDone, canCancel, disableMovement }

local function nextKey()
    return 'p_' .. tostring(GetGameTimer()) .. '_' .. tostring(math.random(1, 1e6))
end

local function disableMovement()
    -- Verhindert Bewegung waehrend Progress laeuft (vergleichbar mit ox_lib)
    DisableControlAction(0, 30,  true) -- MOVE_LR
    DisableControlAction(0, 31,  true) -- MOVE_UD
    DisableControlAction(0, 21,  true) -- SPRINT
    DisableControlAction(0, 22,  true) -- JUMP
    DisableControlAction(0, 23,  true) -- ENTER_VEHICLE
    DisableControlAction(0, 24,  true) -- ATTACK
    DisableControlAction(0, 25,  true) -- AIM
    DisableControlAction(0, 47,  true) -- DETONATE
    DisableControlAction(0, 58,  true) -- THROW_GRENADE
    DisableControlAction(0, 263, true) -- MELEE_ATTACK1
    DisableControlAction(0, 264, true)
    DisableControlAction(0, 257, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 143, true)
    DisableControlAction(0, 75,  true) -- EXIT_VEHICLE
end

--- Startet eine Progressbar. Gibt key zurueck, mit dem sie gecancelt werden kann.
function CLP.UI.Progress(opts, onDone)
    opts = opts or {}
    local key = opts.key or nextKey()
    Active[key] = {
        onDone          = onDone,
        canCancel       = opts.canCancel == true,
        disableMovement = opts.disableMovement ~= false,
    }
    SendNUIMessage({
        action    = 'progress:start',
        key       = key,
        label     = tostring(opts.label or 'Bitte warten'),
        duration  = tonumber(opts.duration) or 3000,
        canCancel = opts.canCancel == true,
    })

    if opts.disableMovement ~= false then
        CreateThread(function()
            while Active[key] do
                disableMovement()
                Wait(0)
            end
        end)
    end
    return key
end

function CLP.UI.CancelProgress(key)
    SendNUIMessage({ action = 'progress:cancel', key = key or 'all' })
end

RegisterNUICallback('progress:done', function(data, cb)
    cb({ ok = true })
    local key = data and data.key
    if not key then return end
    local entry = Active[key]
    if not entry then return end
    Active[key] = nil
    if entry.onDone then
        pcall(entry.onDone, not (data.cancelled == true))
    end
end)
