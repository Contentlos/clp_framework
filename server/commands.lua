--[[
    clp_framework — Server-Commands (Phase 0: minimal)

    Phase 0 hat nur Diagnose-Commands. Money/Job/TP/etc. kommen in Phase 3.

    Commands:
        /clpinfo                       — zeigt Framework-Version + Phase + Online-Anzahl (alle)
        /clpid                         — zeigt eigene Identifier (alle)
        /clpwho                        — Liste aller online Spieler mit Citizen-ID (Admin)
]]

-- ============================================================
--  /clpinfo
-- ============================================================
RegisterCommand('clpinfo', function(source, args, rawCommand)
    local online = #CLP.GetPlayers()
    local msg = ('CLP-Framework v%s — Phase %d — %d online'):format(CLP.Version, CLP.Phase, online)
    if source == 0 then
        print(msg)
    else
        TriggerClientEvent('chat:addMessage', source, {
            args = { '^2[CLP]', msg },
        })
    end
end, false)

-- ============================================================
--  /clpid
-- ============================================================
RegisterCommand('clpid', function(source, args, rawCommand)
    if source == 0 then
        print('Diesen Befehl im Spiel benutzen.')
        return
    end
    local p = CLP.GetPlayer(source)
    if not p then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[CLP]', 'Du bist nicht geladen.' } })
        return
    end
    TriggerClientEvent('chat:addMessage', source, {
        args = { '^2[CLP]', ('Identifier: %s | CitizenID: %s'):format(p:GetIdentifier(), p:GetCitizenId() or '-') },
    })
end, false)

-- ============================================================
--  /clpwho  (Admin)
-- ============================================================
RegisterCommand('clpwho', function(source, args, rawCommand)
    if source ~= 0 and not CLP.Perms.IsAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[CLP]', CLP.L.permission_denied } })
        return
    end
    local lines = { ('Online-Spieler (%d):'):format(#CLP.GetPlayers()) }
    for _, src in ipairs(CLP.GetPlayers()) do
        local p = CLP.GetPlayer(src)
        if p then
            lines[#lines + 1] = ('  src=%d  %s  citizenid=%s  ident=%s'):format(
                src, p:GetFullName(), p:GetCitizenId() or '-', p:GetIdentifier() or '-'
            )
        end
    end
    local out = table.concat(lines, '\n')
    if source == 0 then
        print(out)
    else
        for _, line in ipairs(lines) do
            TriggerClientEvent('chat:addMessage', source, { args = { '^2[CLP]', line } })
        end
    end
end, true) -- restricted = true (ACE-Check zusätzlich möglich)
