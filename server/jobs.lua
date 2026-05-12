--[[
    clp_framework — Jobs-Modul (Phase 0: Skeleton)

    In Phase 2 wird das hier voll ausgebaut (Registry aus DB, Grades,
    Permissions, Salary-Tick). Aktuell:
      CLP.Jobs:Get(name)                       → table | nil  (immer nil außer 'unemployed')
      CLP.Jobs:GetGrade(name, grade)           → table | nil
      CLP.Jobs:SetJob(src, name, grade, reason)→ ok
      CLP.Jobs:SetDuty(src, onDuty)
]]

local Jobs = {}

local FallbackJobs = {
    unemployed = {
        name   = 'unemployed',
        label  = 'Arbeitslos',
        grades = {
            [0] = { grade = 0, label = 'Bürger', salary = 0 },
        },
    },
}

function Jobs:Get(name)
    return FallbackJobs[name]
end

function Jobs:GetGrade(name, grade)
    local j = FallbackJobs[name]
    if not j then return nil end
    return j.grades[tonumber(grade) or 0]
end

function Jobs:SetJob(src, name, grade, reason)
    local p = CLP.GetPlayer(src)
    if not p then return false end
    local job = FallbackJobs[name]
    local g   = job and job.grades[tonumber(grade) or 0]
    -- Bewusst tolerant in Phase 0: unbekannte Jobs werden trotzdem gesetzt,
    -- nur ein Hinweis im Log. Phase 2 macht das strikt.
    if not job then CLP.Warn(CLP.L.job_unknown, tostring(name)) end
    if job and not g then CLP.Warn(CLP.L.job_grade_unknown, tostring(name), tostring(grade)) end

    local old = p:GetJob()
    p:SetJob(name, grade or 0)
    if job and g then
        p.job.label       = job.label
        p.job.grade_label = g.label
        p.job.salary      = g.salary or 0
    end

    TriggerEvent(CLP.Events.JobChanged, src, p:GetJob(), old, reason)
    TriggerClientEvent(CLP.Events.JobChanged, src, p:GetJob(), old, reason)
    if Config.EmitEsxEvents then
        TriggerClientEvent('esx:setJob', src, p:GetJob(), old)
        TriggerEvent('esx:setJob', src, p:GetJob(), old)
    end
    CLP.Log(CLP.L.job_changed, old.name, p:GetJob().name, p:GetJob().grade)
    if p.citizenid and CLP.Log.audit then
        CLP.Log.audit(p.citizenid, 'job_change', { from = old, to = p:GetJob(), reason = reason }, 'system')
    end
    return true
end

function Jobs:SetDuty(src, onDuty)
    local p = CLP.GetPlayer(src)
    if not p then return false end
    p.job.on_duty = (onDuty == true)
    TriggerEvent(CLP.Events.JobDuty, src, p.job.on_duty)
    TriggerClientEvent(CLP.Events.JobDuty, src, p.job.on_duty)
    return true
end

CLP.RegisterModule('Jobs', Jobs)
