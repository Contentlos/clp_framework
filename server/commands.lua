--[[
    clp_framework — Server-Commands (Phase 2)

    Diagnose:
        /clpinfo               — Framework-Version + Phase + Online-Anzahl (alle)
        /clpid                 — eigene Identifier (alle)
        /clpwho                — Liste aller online Spieler (Admin)
        /joblist               — Liste aller Jobs aus Registry (Admin)

    Administration (Admin-only):
        /setjob <id> <name> [grade] [reason]   — Job eines Spielers setzen
        /duty                                  — eigenen Dienst-Status togglen
        /addmoney <id> <account> <amount>      — Geld hinzufuegen
        /removemoney <id> <account> <amount>   — Geld abziehen
        /clpreloadjobs                         — Jobs-Registry aus DB neu laden
]]

-- ============================================================
--  HELPERS
-- ============================================================
local function reply(src, msg, color)
    color = color or '^2'
    if src == 0 then
        print(('[CLP] %s'):format(msg))
    else
        TriggerClientEvent('chat:addMessage', src, { args = { color .. '[CLP]', msg } })
    end
end

local function requireAdmin(src)
    if src == 0 then return true end
    if not CLP.Perms.IsAdmin(src) then
        reply(src, CLP.L.permission_denied, '^1')
        return false
    end
    return true
end

local function getTargetPlayer(idArg)
    local id = tonumber(idArg)
    if not id then return nil, 'invalid_id' end
    local p = CLP.GetPlayer(id)
    if not p then return nil, 'not_online' end
    return p
end

-- ============================================================
--  /clpinfo
-- ============================================================
RegisterCommand('clpinfo', function(source, args, rawCommand)
    local online = #CLP.GetPlayers()
    reply(source, ('CLP-Framework v%s — Phase %d — %d online'):format(CLP.Version, CLP.Phase, online))
end, false)

-- ============================================================
--  /clpid
-- ============================================================
RegisterCommand('clpid', function(source, args, rawCommand)
    if source == 0 then
        reply(0, 'Diesen Befehl im Spiel benutzen.')
        return
    end
    local p = CLP.GetPlayer(source)
    if not p then
        reply(source, 'Du bist nicht geladen.', '^1')
        return
    end
    reply(source, ('Identifier: %s | CitizenID: %s'):format(p:GetIdentifier(), p:GetCitizenId() or '-'))
end, false)

-- ============================================================
--  /clpwho
-- ============================================================
RegisterCommand('clpwho', function(source, args, rawCommand)
    if not requireAdmin(source) then return end
    local players = CLP.GetPlayers()
    reply(source, ('Online-Spieler (%d):'):format(#players))
    for _, src in ipairs(players) do
        local p = CLP.GetPlayer(src)
        if p then
            reply(source, ('  src=%d  %s  citizenid=%s  ident=%s  job=%s/%d'):format(
                src, p:GetFullName(), p:GetCitizenId() or '-', p:GetIdentifier() or '-',
                (p:GetJob() or {}).name or '-', (p:GetJob() or {}).grade or 0
            ))
        end
    end
end, true)

-- ============================================================
--  /joblist  (Admin)
-- ============================================================
RegisterCommand('joblist', function(source, args, rawCommand)
    if not requireAdmin(source) then return end
    local jobs = CLP.Jobs:GetAll()
    local names = {}
    for name in pairs(jobs) do names[#names + 1] = name end
    table.sort(names)
    reply(source, ('Jobs in Registry (%d):'):format(#names))
    for _, name in ipairs(names) do
        local j = jobs[name]
        local gradeCount = 0
        for _ in pairs(j.grades or {}) do gradeCount = gradeCount + 1 end
        reply(source, ('  %s — "%s" [%s] grades=%d wl=%s'):format(
            name, j.label, j.category or '-', gradeCount, j.whitelisted and 'ja' or 'nein'
        ))
    end
end, true)

-- ============================================================
--  /setjob <id> <name> [grade] [reason]   (Admin)
-- ============================================================
RegisterCommand('setjob', function(source, args, rawCommand)
    if not requireAdmin(source) then return end
    if #args < 2 then
        reply(source, 'Verwendung: /setjob <id> <name> [grade] [reason]', '^3')
        return
    end
    local p, err = getTargetPlayer(args[1])
    if not p then
        reply(source, 'Ziel-Spieler nicht gefunden: ' .. tostring(err), '^1')
        return
    end
    local name   = tostring(args[2])
    local grade  = tonumber(args[3]) or 0
    local reason = args[4] and table.concat(args, ' ', 4) or 'admin_command'

    local ok, ferr = CLP.Jobs:SetJob(p:GetSource(), name, grade, reason)
    if not ok then
        reply(source, 'Job-Set fehlgeschlagen: ' .. tostring(ferr), '^1')
        return
    end
    local job = p:GetJob()
    reply(source, (CLP.L.job_set_target):format(p:GetFullName(), job.label or job.name, job.grade_label or ('Grade ' .. job.grade)))
    if p:GetSource() ~= source then
        CLP.Notify(p:GetSource(), (CLP.L.job_set_self):format(job.label or job.name, job.grade_label or ('Grade ' .. job.grade)), 'success', 5000)
    end
end, true)

-- ============================================================
--  /duty   (alle Spieler — togglt eigenen Dienst-Status)
-- ============================================================
RegisterCommand('duty', function(source, args, rawCommand)
    if source == 0 then
        reply(0, 'Diesen Befehl im Spiel benutzen.')
        return
    end
    local p = CLP.GetPlayer(source)
    if not p or not p:IsAttached() then
        reply(source, 'Du bist nicht geladen.', '^1')
        return
    end
    local newDuty = not p:OnDuty()
    CLP.Jobs:SetDuty(source, newDuty)
    reply(source, newDuty and CLP.L.duty_on or CLP.L.duty_off)
    CLP.Notify(source, newDuty and CLP.L.duty_on or CLP.L.duty_off, 'info', 3000)
end, false)

-- ============================================================
--  /addmoney <id> <account> <amount>    (Admin)
-- ============================================================
RegisterCommand('addmoney', function(source, args, rawCommand)
    if not requireAdmin(source) then return end
    if #args < 3 then
        reply(source, 'Verwendung: /addmoney <id> <cash|bank|black_money> <amount>', '^3')
        return
    end
    local p, err = getTargetPlayer(args[1])
    if not p then
        reply(source, 'Ziel-Spieler nicht gefunden: ' .. tostring(err), '^1')
        return
    end
    local account = tostring(args[2])
    if account ~= 'cash' and account ~= 'bank' and account ~= 'black_money' then
        reply(source, 'Ungueltiges Konto. Erlaubt: cash | bank | black_money', '^1')
        return
    end
    local amount = math.floor(tonumber(args[3]) or 0)
    if amount <= 0 then
        reply(source, 'Betrag muss > 0 sein.', '^1')
        return
    end
    local ok = CLP.Money:Add(p:GetSource(), account, amount, 'admin_addmoney')
    if not ok then
        reply(source, 'Geld-Add fehlgeschlagen.', '^1')
        return
    end
    reply(source, ('+%d$ auf %s fuer %s.'):format(amount, account, p:GetFullName()))
    CLP.Notify(p:GetSource(), ('Admin hat dir %d$ auf %s gutgeschrieben.'):format(amount, account), 'success', 5000)
end, true)

-- ============================================================
--  /removemoney <id> <account> <amount>    (Admin)
-- ============================================================
RegisterCommand('removemoney', function(source, args, rawCommand)
    if not requireAdmin(source) then return end
    if #args < 3 then
        reply(source, 'Verwendung: /removemoney <id> <cash|bank|black_money> <amount>', '^3')
        return
    end
    local p, err = getTargetPlayer(args[1])
    if not p then
        reply(source, 'Ziel-Spieler nicht gefunden: ' .. tostring(err), '^1')
        return
    end
    local account = tostring(args[2])
    if account ~= 'cash' and account ~= 'bank' and account ~= 'black_money' then
        reply(source, 'Ungueltiges Konto.', '^1')
        return
    end
    local amount = math.floor(tonumber(args[3]) or 0)
    if amount <= 0 then
        reply(source, 'Betrag muss > 0 sein.', '^1')
        return
    end
    local ok = CLP.Money:Remove(p:GetSource(), account, amount, 'admin_removemoney')
    if not ok then
        reply(source, 'Geld-Remove fehlgeschlagen (evtl. nicht genug).', '^1')
        return
    end
    reply(source, ('-%d$ von %s bei %s.'):format(amount, account, p:GetFullName()))
    CLP.Notify(p:GetSource(), ('Admin hat dir %d$ von %s abgezogen.'):format(amount, account), 'warning', 5000)
end, true)

-- ============================================================
--  /clpreloadjobs   (Admin)
-- ============================================================
RegisterCommand('clpreloadjobs', function(source, args, rawCommand)
    if not requireAdmin(source) then return end
    CLP.Jobs:Reload()
    reply(source, 'Jobs-Registry neu geladen.')
end, true)
