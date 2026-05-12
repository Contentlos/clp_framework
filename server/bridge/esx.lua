--[[
    clp_framework — ESX-Bridge (SERVER)

    Stellt eine ESX-Legacy-kompatible API über `exports.es_extended:getSharedObject()`
    bereit. Resources wie `clp_gmenu` rufen das auf und erwarten ein ESX-Objekt
    mit den Methoden GetPlayerFromId, GetPlayers, RegisterUsableItem etc.
    Wir geben ein "Shape-kompatibles" Objekt zurück, dessen Methoden auf CLP zeigen.

    SICHERHEITSHINWEIS: Diese Bridge ist NUR aktiv wenn Config.EnableEsxBridge=true.
    Sie REGISTRIERT keinen eigenen Resource-Namen `es_extended` — sie nutzt das
    Export-System der lokalen Resource (clp_framework). Damit Code wie
    `exports['es_extended']:getSharedObject()` funktioniert, müsste theoretisch
    eine Resource mit Namen 'es_extended' existieren. Praktisch: viele ESX-
    Resources fallen auch auf ein triggered Event 'esx:getSharedObject' zurück
    ODER man legt eine 1-File-Resource 'es_extended' an die nur den Export
    weiterleitet. Phase 0 deckt:
      (a) Event-basierten Pfad ('esx:getSharedObject')
      (b) Direct-Export von clp_framework selber:
          `exports.clp_framework:GetSharedObject()` (interner Pfad, falls jemand
          das Framework direkt ansprechen will)

    Falls deine clp_gmenu / andere ESX-Resources `exports['es_extended']:...`
    nutzen UND es_extended NICHT installiert ist, brauchen wir entweder
    (1) eine 1-File-Stub-Resource `es_extended` die nur Export-Forwarding
         macht (kommt in Phase 1 als optionaler Helper)
    (2) oder du behältst es_extended weiter installiert und wir kapern die
         Player-Daten via Event-Hooks.
    In Phase 0 wählen wir Pfad (1)-Vorbereitung: das Shared-Object ist
    fertig, die Forwarder-Resource kommt im nächsten PR.
]]

if not Config.EnableEsxBridge then
    CLP.Log(CLP.L.bridge_esx_disabled)
    return
end

-- ============================================================
--  xPlayer-PROXY  — wrap't einen CLP-Player als ESX-xPlayer
-- ============================================================
local function buildXPlayer(player)
    if not player then return nil end
    local source = player.source
    local idents = player.idents or {}

    local xp = {
        -- Klassische Felder
        source       = source,
        identifier   = player.identifier,
        name         = player:GetName(),
        job          = player:GetJob(),
        accounts     = {
            { name = 'money',       label = 'Cash',   money = player.money.cash        },
            { name = 'bank',        label = 'Bank',   money = player.money.bank        },
            { name = 'black_money', label = 'Schwarzgeld', money = player.money.black_money },
        },
        inventory    = {},  -- Phase 5 (Inventory) füllt das auf
        weight       = 0,
        maxWeight    = 30000,
        loadout      = {},
        variables    = {
            firstName = player.firstname or '',
            lastName  = player.lastname  or '',
            sex       = player.gender    or 'm',
            skin      = player.metadata.skin,
            phone     = nil,
        },

        -- Verschiedene Identifier-Schreibweisen die ESX-Resources nutzen
        getIdentifier = function() return player.identifier end,
        getName       = function() return player:GetFullName() end,
        setName       = function(name) player.name = tostring(name) end,

        -- Money
        getMoney      = function() return player:GetMoney('cash') end,
        addMoney      = function(amount, reason) return CLP.Money:Add(source, 'cash', amount, reason) end,
        removeMoney   = function(amount, reason) return CLP.Money:Remove(source, 'cash', amount, reason) end,
        setMoney      = function(amount)
            local cur = player:GetMoney('cash')
            if amount > cur then return CLP.Money:Add(source, 'cash', amount - cur, 'esx:setMoney')
            else return CLP.Money:Remove(source, 'cash', cur - amount, 'esx:setMoney') end
        end,

        getAccount    = function(name)
            local map = { money = 'cash', bank = 'bank', black_money = 'black_money' }
            local key = map[name] or name
            return {
                name   = name,
                label  = name,
                money  = player:GetMoney(key),
                round  = 0,
            }
        end,
        addAccountMoney    = function(name, amount, reason)
            local map = { money = 'cash', bank = 'bank', black_money = 'black_money' }
            return CLP.Money:Add(source, map[name] or name, amount, reason)
        end,
        removeAccountMoney = function(name, amount, reason)
            local map = { money = 'cash', bank = 'bank', black_money = 'black_money' }
            return CLP.Money:Remove(source, map[name] or name, amount, reason)
        end,
        setAccountMoney    = function(name, amount)
            local map = { money = 'cash', bank = 'bank', black_money = 'black_money' }
            local key = map[name] or name
            local cur = player:GetMoney(key)
            if amount > cur then return CLP.Money:Add(source, key, amount - cur, 'esx:set')
            else return CLP.Money:Remove(source, key, cur - amount, 'esx:set') end
        end,

        -- Job
        getJob        = function() return player:GetJob() end,
        setJob        = function(name, grade) return CLP.Jobs:SetJob(source, name, grade, 'esx_bridge') end,

        -- Metadata / Variables (ESX-Style)
        set           = function(key, value)
            -- Mapping: firstName, lastName, sex, skin → in player.firstname etc.
            if key == 'firstName' then player.firstname = value
            elseif key == 'lastName' then player.lastname = value
            elseif key == 'sex'      then player.gender   = value
            elseif key == 'skin'     then player:SetMeta('skin', value)
            else player:SetMeta(key, value) end
            xp.variables[key] = value
        end,
        get           = function(key)
            if key == 'firstName' then return player.firstname end
            if key == 'lastName'  then return player.lastname  end
            if key == 'sex'       then return player.gender    end
            if key == 'skin'      then return player:GetMeta('skin') end
            return player:GetMeta(key) or xp.variables[key]
        end,

        -- Inventory (Stub — Phase 5)
        getInventory      = function() return {} end,
        getInventoryItem  = function(name) return { name = name, count = 0, label = name } end,
        addInventoryItem  = function() return false end,
        removeInventoryItem = function() return false end,
        canCarryItem      = function() return true end,

        -- Notifications / Events
        showNotification  = function(msg)
            TriggerClientEvent('esx:showNotification', source, msg)
        end,
        triggerEvent      = function(name, ...)
            TriggerClientEvent(name, source, ...)
        end,
        kick              = function(reason)
            DropPlayer(source, reason or 'Gekickt')
        end,

        -- Group / Permission
        getGroup          = function() return CLP.Perms.GetGroup(source) end,
        setGroup          = function(group)
            return CLP.Perms.SetGroup(player.identifier, group)
        end,

        -- Spielzeit, Spawn-Coords
        getCoords         = function()
            local ped = GetPlayerPed(source)
            local c = GetEntityCoords(ped)
            return { x = c.x, y = c.y, z = c.z, heading = GetEntityHeading(ped) }
        end,
    }

    return xp
end

-- ============================================================
--  USABLE-ITEMS  — clp_gmenu's & andere Resources nutzen das
-- ============================================================
local UsableItems = {}

-- ============================================================
--  SHARED-OBJECT
-- ============================================================
local Shared = {}

function Shared.GetPlayerFromId(src)
    return buildXPlayer(CLP.GetPlayer(tonumber(src)))
end

function Shared.GetPlayerFromIdentifier(identifier)
    return buildXPlayer(CLP.GetPlayerByIdentifier(identifier))
end

function Shared.GetPlayers()
    return CLP.GetPlayers()
end

function Shared.GetExtendedPlayers()
    local out = {}
    for _, src in ipairs(CLP.GetPlayers()) do
        local xp = Shared.GetPlayerFromId(src)
        if xp then out[#out + 1] = xp end
    end
    return out
end

function Shared.RegisterUsableItem(item, cb)
    UsableItems[item] = cb
end

function Shared.UseItem(src, item)
    if UsableItems[item] then
        return UsableItems[item](src)
    end
    return false
end

function Shared.RegisterServerCallback(name, cb)
    -- Sehr minimaler Callback-Wrapper. Phase 3 baut das aus.
    RegisterNetEvent('__esx_cb:' .. name, function(requestId, ...)
        local src = source
        cb(src, function(...) TriggerClientEvent('__esx_cb_resp:' .. name, src, requestId, ...) end, ...)
    end)
end

-- ============================================================
--  EXPORTS / EVENTS
-- ============================================================

-- Andere Resources rufen `TriggerEvent('esx:getSharedObject', cb)` als Fallback.
AddEventHandler('esx:getSharedObject', function(cb)
    if type(cb) == 'function' then cb(Shared) end
end)

-- Direct-Export aus clp_framework — falls Resources das Framework direkt ansprechen
exports('GetSharedObject', function() return Shared end)
exports('GetESX',          function() return Shared end)

-- Expose intern (für andere CLP-Module die ESX-Resources triggern)
CLP.RegisterModule('ESX', Shared)

CLP.Log(CLP.L.bridge_esx_enabled)
