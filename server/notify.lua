--[[
    clp_framework — Server-Side Notify (Phase 3)

    Public:
        CLP.Notify(src, message, ntype, duration)
        CLP.NotifyAll(message, ntype, duration)
        CLP.NotifyGroup(group, message, ntype, duration)
        CLP.NotifyAdmins(message, ntype, duration)
        CLP.NotifyJob(jobName, message, ntype, duration)

    Notifications werden ueber CLP.Events.UINotify an die Client(s) gesendet
    und dort von modules/ui/client/notify.lua an die NUI weitergereicht
    (Phase 4 baut die NUI voll aus — Phase 3 fokussiert auf Server-API).

    Hooks:
        'before:notify' { src, message, type, duration }      — cancelable
        'after:notify'  { src, message, type, duration }      — informativ

    Types: 'info' (default) | 'success' | 'warning' | 'error'
]]

local function basePayload(message, ntype, duration)
    return {
        message  = tostring(message or ''),
        type     = ntype or 'info',
        duration = tonumber(duration) or 4000,
    }
end

local function send(src, payload)
    if not src or not payload.message or payload.message == '' then return false end
    if CLP.Hooks then
        local ok = CLP.Hooks:Fire('before:notify', {
            src = src, message = payload.message, type = payload.type, duration = payload.duration,
        })
        if ok == false then return false end
    end
    TriggerClientEvent(CLP.Events.UINotify, src, payload)
    if CLP.Hooks then
        CLP.Hooks:Fire('after:notify', {
            src = src, message = payload.message, type = payload.type, duration = payload.duration,
        })
    end
    return true
end

--- Sendet eine Notification an einen einzelnen Spieler (oder -1 = alle).
function CLP.Notify(src, message, ntype, duration)
    return send(tonumber(src) or src, basePayload(message, ntype, duration))
end

--- Sendet eine Notification an ALLE Spieler.
function CLP.NotifyAll(message, ntype, duration)
    return send(-1, basePayload(message, ntype, duration))
end

--- Sendet eine Notification an alle Spieler einer Permissions-Gruppe.
--- @param group string  z.B. 'admin' | 'mod'
function CLP.NotifyGroup(group, message, ntype, duration)
    local payload = basePayload(message, ntype, duration)
    for _, src in ipairs(CLP.GetPlayers()) do
        if CLP.Perms and CLP.Perms.GetGroup and CLP.Perms.GetGroup(src) == group then
            send(src, payload)
        end
    end
end

--- Sendet eine Notification an alle Admins (Permissions.IsAdmin).
function CLP.NotifyAdmins(message, ntype, duration)
    local payload = basePayload(message, ntype, duration)
    for _, src in ipairs(CLP.GetPlayers()) do
        if CLP.Perms and CLP.Perms.IsAdmin and CLP.Perms.IsAdmin(src) then
            send(src, payload)
        end
    end
end

--- Sendet eine Notification an alle Spieler mit einem bestimmten Job.
function CLP.NotifyJob(jobName, message, ntype, duration)
    local payload = basePayload(message, ntype, duration)
    for _, src in ipairs(CLP.GetPlayers()) do
        local p = CLP.GetPlayer(src)
        if p and p:IsAttached() then
            local job = p:GetJob() or {}
            if job.name == jobName then send(src, payload) end
        end
    end
end
