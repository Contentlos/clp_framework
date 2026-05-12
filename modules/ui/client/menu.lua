--[[
    clp_framework — Menu (Client, Phase 0 Stub)

    Phase 4 implementiert ein vollständiges Menu-Stack-System (mehrere
    übereinander gestaffelte Menüs, Tastatur-Navigation, Hotkeys).
    Phase 0 hat nur API-Skelett.
]]

CLP.UI = CLP.UI or {}

local OpenStack = {}

function CLP.UI.OpenMenu(opts)
    -- opts: { id, title, items = { { label, description, icon, action } } }
    opts = opts or {}
    opts.id = opts.id or ('menu_%d'):format(GetGameTimer())
    table.insert(OpenStack, opts.id)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'menu:open', menu = opts })
    return opts.id
end

function CLP.UI.CloseMenu(id)
    SendNUIMessage({ action = 'menu:close', id = id })
    if id then
        for i, v in ipairs(OpenStack) do
            if v == id then table.remove(OpenStack, i) break end
        end
    else
        OpenStack = {}
    end
    if #OpenStack == 0 then SetNuiFocus(false, false) end
end

RegisterNUICallback('menu:select', function(data, cb)
    -- Phase 4 routet das an den passenden Callback. Aktuell nur Echo.
    cb({ ok = true, data = data })
end)

RegisterNUICallback('menu:close', function(data, cb)
    CLP.UI.CloseMenu(data and data.id)
    cb({ ok = true })
end)
