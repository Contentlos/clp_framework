--[[
    clp_framework — Server Event-Wiring (Phase 1)

    Verbindet die FiveM-Lifecycle-Events mit dem Player- + Character-Manager.
    Implementiert ausserdem die Phase-1-Char-Select-Events:
      C->S CharRequestList / CharCreate / CharSelect / CharDelete
      S->C CharList / CharCreated / CharSelected / CharDeleted
]]

-- ============================================================
--  PLAYER CONNECTING (Deferrals-Phase)
-- ============================================================
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('CLP-Framework — pruefe Identifier...')

    local primary = CLP.Identity.GetPrimary(src)
    if not primary then
        deferrals.done('Kein gueltiger Identifier gefunden. Verbindung abgelehnt.')
        if setKickReason then setKickReason('Kein gueltiger Identifier.') end
        return
    end

    -- Ban-Check
    local Users = CLP.GetModule('Users')
    if Users and Users.IsBanned then
        local banned, reason = Users.IsBanned(primary)
        if banned then
            local msg = ('Du bist gebannt: %s'):format(reason or 'kein Grund angegeben')
            deferrals.done(msg)
            if setKickReason then setKickReason(msg) end
            return
        end
    end

    deferrals.update(('CLP-Framework — willkommen %s!'):format(playerName or 'Spieler'))
    Wait(50)
    deferrals.done()
    CLP.Dbg('player connecting OK: src=%s primary=%s', src, primary)
end)

-- ============================================================
--  CHAR-SELECT FLOW (Phase 1)
--  Wenn Config.AutoCharSelect=true: Server waehlt last-played oder erstellt Default.
--  Wenn false: Server sendet CharList an Client, wartet auf CharSelect/CharCreate.
-- ============================================================

local function sendCharList(src, identifier)
    local Characters = CLP.GetModule('Characters')
    if not Characters then return end
    local rows = Characters.ListByUser(identifier) or {}
    CLP.Log(CLP.L.char_list_loaded, identifier, #rows)
    TriggerClientEvent(CLP.Events.CharList, src, {
        chars     = rows,
        maxChars  = Config.MaxCharacters or 3,
    })
end

local function autoSelectOrCreate(src, identifier)
    local Characters = CLP.GetModule('Characters')
    if not Characters then return false end

    local row = Characters.GetLastPlayed(identifier)
    if row then
        CLP.Log(CLP.L.char_auto_selected, row.firstname, row.lastname, row.slot)
        return CLP.AttachCharacter(src, row)
    end

    -- Kein Charakter -> Default erstellen
    local ok, cidOrErr = Characters.Create(identifier, {
        firstname = Config.DefaultCharFirstname or 'Max',
        lastname  = Config.DefaultCharLastname  or 'Mustermann',
        gender    = Config.DefaultCharGender    or 'm',
        slot      = 1,
    })
    if not ok then
        CLP.Err(CLP.L.char_create_failed, tostring(cidOrErr))
        return false
    end
    CLP.Log(CLP.L.char_auto_created, identifier)

    local newRow = Characters.LoadByCitizenId(cidOrErr)
    if not newRow then
        CLP.Err('Auto-Char erstellt aber LoadByCitizenId(%s) gab nil zurueck.', cidOrErr)
        return false
    end
    return CLP.AttachCharacter(src, newRow)
end

-- ============================================================
--  PLAYER JOINING  — Spieler ist verbunden
-- ============================================================
AddEventHandler('playerJoining', function()
    local src = source
    local player = CLP.LoadPlayer(src)
    if not player then return end
    local identifier = player.identifier

    if Config.SkeletonMode then
        -- Phase-0-Kompat: keinen Charakter laden
        return
    end

    if Config.AutoCharSelect then
        -- Asynchron, damit playerJoining nicht blockiert (single() ist sync-blocking)
        CreateThread(function()
            Wait(50)
            local ok = autoSelectOrCreate(src, identifier)
            if not ok then
                -- Wenn auto-select fehlschlug: schick wenigstens die Liste
                sendCharList(src, identifier)
            end
        end)
    else
        -- Manueller Pfad: Char-Liste an Client schicken (UI in Phase 4)
        CreateThread(function()
            Wait(50)
            sendCharList(src, identifier)
        end)
    end
end)

-- ============================================================
--  CLIENT->SERVER: CharRequestList
-- ============================================================
RegisterNetEvent(CLP.Events.CharRequestList, function()
    local src = source
    local player = CLP.GetPlayer(src)
    if not player then return end
    sendCharList(src, player.identifier)
end)

-- ============================================================
--  CLIENT->SERVER: CharCreate
-- ============================================================
RegisterNetEvent(CLP.Events.CharCreate, function(data)
    local src = source
    local player = CLP.GetPlayer(src)
    if not player then return end

    local Characters = CLP.GetModule('Characters')
    if not Characters then return end

    local ok, cidOrErr = Characters.Create(player.identifier, data or {})
    if not ok then
        TriggerClientEvent(CLP.Events.CharCreated, src, { ok = false, err = tostring(cidOrErr) })
        return
    end
    TriggerClientEvent(CLP.Events.CharCreated, src, { ok = true, citizenid = cidOrErr })
    -- Liste neu schicken, damit der Client den neuen Char sieht
    sendCharList(src, player.identifier)
end)

-- ============================================================
--  CLIENT->SERVER: CharSelect
-- ============================================================
RegisterNetEvent(CLP.Events.CharSelect, function(data)
    local src = source
    local player = CLP.GetPlayer(src)
    if not player then return end
    local cid = data and data.citizenid
    if not cid then
        TriggerClientEvent(CLP.Events.CharSelected, src, { ok = false, err = 'missing_citizenid' })
        return
    end

    local Characters = CLP.GetModule('Characters')
    if not Characters then return end

    local row = Characters.LoadByCitizenId(cid)
    if not row or row.user_id ~= player.identifier then
        TriggerClientEvent(CLP.Events.CharSelected, src, { ok = false, err = 'not_found_or_forbidden' })
        return
    end

    local ok = CLP.AttachCharacter(src, row)
    TriggerClientEvent(CLP.Events.CharSelected, src, { ok = ok, citizenid = cid })
end)

-- ============================================================
--  CLIENT->SERVER: CharDelete
-- ============================================================
RegisterNetEvent(CLP.Events.CharDelete, function(data)
    local src = source
    local player = CLP.GetPlayer(src)
    if not player then return end
    local cid = data and data.citizenid
    if not cid then
        TriggerClientEvent(CLP.Events.CharDeleted, src, { ok = false, err = 'missing_citizenid' })
        return
    end

    local Characters = CLP.GetModule('Characters')
    if not Characters then return end

    local row = Characters.LoadByCitizenId(cid)
    if not row or row.user_id ~= player.identifier then
        TriggerClientEvent(CLP.Events.CharDeleted, src, { ok = false, err = 'not_found_or_forbidden' })
        return
    end

    Characters.SoftDelete(cid)
    TriggerClientEvent(CLP.Events.CharDeleted, src, { ok = true, citizenid = cid })
    sendCharList(src, player.identifier)
end)

-- ============================================================
--  PLAYER DROPPED
-- ============================================================
AddEventHandler('playerDropped', function(reason)
    local src = source
    CLP.UnloadPlayer(src, reason)
end)

-- ============================================================
--  RESOURCE STOPPED  — alle Spieler entladen (Save)
-- ============================================================
AddEventHandler('onResourceStop', function(name)
    if name ~= CLP.ResourceName then return end
    CLP.Log(CLP.L.framework_stopped)
    -- SaveAll vor Unload, falls jemand nicht in der UnloadPlayer-Schleife landet
    CLP.SaveAll('resource_stop')
    for _, src in ipairs(CLP.GetPlayers()) do
        CLP.UnloadPlayer(src, 'resource_stop')
    end
end)
