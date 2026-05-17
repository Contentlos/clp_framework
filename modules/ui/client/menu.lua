--[[
    clp_framework — Menu (Client, Phase 4)

    Stack-fähiges Menu-System mit Keyboard-Navigation (in script.js).
    Server / Client koennen Menus oeffnen, NUI sendet bei Auswahl einen
    'menu:select'-Callback zurueck, der den Original-Callback aufruft.

    Public:
        CLP.UI.OpenMenu(opts) -> id
        CLP.UI.CloseMenu(id)
        CLP.UI.CloseAllMenus()

    opts = {
        id?         = string (sonst auto-generiert)
        title       = string
        subtitle?   = string
        items       = { { label, description?, icon?, action?, payload?, disabled?, onSelect? = function(payload) } }
        onClose?    = function()
        onBack?     = function(id)      -- Backspace im Menu
    }
]]

CLP.UI = CLP.UI or {}

local OpenMenus  = {}   -- { [id] = { items, onClose, onBack } }
local StackOrder = {}   -- chronologisch (oben = aktiv)

local function idGen()
    return ('menu_%d_%d'):format(GetGameTimer(), math.random(1, 1e6))
end

local function focusOn()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end

local function focusOff()
    if #StackOrder == 0 then
        SetNuiFocus(false, false)
    end
end

function CLP.UI.OpenMenu(opts)
    opts = opts or {}
    if type(opts.items) ~= 'table' then
        opts.items = {}
    end
    local id = opts.id or idGen()
    OpenMenus[id] = {
        items   = opts.items,
        onClose = opts.onClose,
        onBack  = opts.onBack,
    }
    table.insert(StackOrder, id)
    focusOn()

    -- Sanitize items fuer JSON-Transport
    local sendItems = {}
    for i, it in ipairs(opts.items) do
        sendItems[i] = {
            label       = it.label or ('Item ' .. i),
            description = it.description,
            icon        = it.icon,
            action      = it.action,
            payload     = it.payload,
            disabled    = it.disabled == true,
        }
    end

    SendNUIMessage({
        action = 'menu:open',
        menu = {
            id       = id,
            title    = opts.title or 'Menu',
            subtitle = opts.subtitle,
            items    = sendItems,
        },
    })
    return id
end

function CLP.UI.CloseMenu(id)
    if id and OpenMenus[id] then
        local cfg = OpenMenus[id]
        OpenMenus[id] = nil
        for i = #StackOrder, 1, -1 do
            if StackOrder[i] == id then table.remove(StackOrder, i); break end
        end
        if cfg.onClose then pcall(cfg.onClose) end
    end
    SendNUIMessage({ action = 'menu:close', id = id })
    focusOff()
end

function CLP.UI.CloseAllMenus()
    for id, cfg in pairs(OpenMenus) do
        if cfg.onClose then pcall(cfg.onClose) end
    end
    OpenMenus  = {}
    StackOrder = {}
    SendNUIMessage({ action = 'menu:closeAll' })
    focusOff()
end

-- ============================================================
--  NUI-CALLBACKS
-- ============================================================
RegisterNUICallback('menu:select', function(data, cb)
    cb({ ok = true })
    local id  = data and data.id
    local idx = tonumber(data and data.idx)
    if not id or not idx then return end
    local cfg = OpenMenus[id]
    if not cfg then return end
    local item = cfg.items[idx + 1]  -- JS ist 0-indexed
    if not item then return end
    if type(item.onSelect) == 'function' then
        pcall(item.onSelect, item.payload, item)
    end
    if item.closeOnSelect ~= false then
        CLP.UI.CloseMenu(id)
    end
end)

RegisterNUICallback('menu:close', function(data, cb)
    cb({ ok = true })
    CLP.UI.CloseMenu(data and data.id)
end)

RegisterNUICallback('menu:back', function(data, cb)
    cb({ ok = true })
    local id = data and data.id
    local cfg = id and OpenMenus[id]
    if cfg and cfg.onBack then pcall(cfg.onBack, id) end
end)
