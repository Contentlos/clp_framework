--[[
    clp_framework — Input-Dialog (Client, Phase 4)

    Modal-Input mit beliebig vielen Feldern (text, number, password, select,
    textarea). Wartet asynchron auf Submit/Cancel und gibt das Values-Object
    zurueck (oder nil bei Cancel).

    Public:
        CLP.UI.Input(opts) -> table | nil    (yields current thread)

        opts = {
            title         = string,
            submitLabel?  = 'OK',
            cancelLabel?  = 'Abbrechen',
            fields        = {
                { name='vorname', label='Vorname', type='text', placeholder='Max', maxLength=32 },
                { name='alter',   label='Alter',   type='number' },
                { name='geschl', label='Geschlecht', type='select',
                  options = { { value='m', label='M' }, { value='f', label='F' } } },
                ...
            },
        }

    Returns: { vorname='...', alter='25', ... } oder nil
]]

CLP.UI = CLP.UI or {}

local PendingPromises = {}

local function genId()
    return 'in_' .. tostring(GetGameTimer()) .. '_' .. tostring(math.random(1, 1e6))
end

function CLP.UI.Input(opts)
    opts = opts or {}
    local id = opts.id or genId()
    local promise = promise.new and promise.new() or nil

    PendingPromises[id] = function(values, cancelled)
        if cancelled then
            if promise then promise:resolve(nil) else PendingPromises[id] = nil end
        else
            if promise then promise:resolve(values) else PendingPromises[id] = nil end
        end
        PendingPromises[id] = nil
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action      = 'input:open',
        id          = id,
        title       = opts.title or 'Eingabe',
        submitLabel = opts.submitLabel,
        cancelLabel = opts.cancelLabel,
        fields      = opts.fields or {},
    })

    if promise then
        local result = Citizen.Await(promise)
        SetNuiFocus(false, false)
        return result
    else
        -- Fallback: synchron warten
        local done, out
        PendingPromises[id] = function(values, cancelled)
            done = true
            out  = (not cancelled) and values or nil
            PendingPromises[id] = nil
        end
        while not done do Wait(50) end
        SetNuiFocus(false, false)
        return out
    end
end

RegisterNUICallback('input:submit', function(data, cb)
    cb({ ok = true })
    local id = data and data.id
    local p = PendingPromises[id]
    if p then pcall(p, data.values or {}, false) end
end)

RegisterNUICallback('input:cancel', function(data, cb)
    cb({ ok = true })
    local id = data and data.id
    local p = PendingPromises[id]
    if p then pcall(p, nil, true) end
end)
