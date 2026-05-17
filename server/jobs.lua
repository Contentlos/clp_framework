--[[
    clp_framework — Jobs-Modul (Phase 2: Voll)

    Registry-Layer fuer Jobs + Grades. Faehigkeiten:
      * Default-Jobs werden beim Resource-Start in clp_jobs/clp_job_grades geseedet
        (idempotent, ueberschreibt keine existierenden Rows).
      * In-Memory-Registry wird beim Start aus DB geladen.
      * SetJob/SetDuty validieren strikt gegen die Registry.
      * Salary-Tick: alle Config.SalaryInterval Minuten bekommen On-Duty-Spieler
        ihr Grade-Salary in die Bank.
      * ESX-Kompat: feuert esx:setJob fuer beide Seiten wenn Config.EmitEsxEvents.

    Public:
      CLP.Jobs:GetAll()                            -> { [name] = job }
      CLP.Jobs:Get(name)                           -> job | nil
      CLP.Jobs:GetGrade(name, grade)               -> grade | nil
      CLP.Jobs:Exists(name)                        -> bool
      CLP.Jobs:SetJob(src, name, grade, reason)    -> ok, err?
      CLP.Jobs:SetDuty(src, onDuty)                -> ok
      CLP.Jobs:Register(name, label, opts)         -> ok (admin/runtime add)
      CLP.Jobs:Reload()                            -> reload registry from DB
]]

local Jobs = {}

-- ============================================================
--  IN-MEMORY-REGISTRY
-- ============================================================
local registry = {}  -- [name] = { name, label, whitelisted, category, grades = { [g] = {...} } }

local function buildJobShape(jobRow, gradeRows)
    local job = {
        name        = jobRow.name,
        label       = jobRow.label,
        whitelisted = (tonumber(jobRow.whitelisted) or 0) == 1,
        category    = jobRow.category,
        grades      = {},
    }
    for _, gr in ipairs(gradeRows or {}) do
        job.grades[tonumber(gr.grade)] = {
            grade  = tonumber(gr.grade),
            label  = gr.label,
            salary = tonumber(gr.salary) or 0,
        }
    end
    return job
end

-- ============================================================
--  SEED (idempotent — INSERT IGNORE)
-- ============================================================
local function seedDefaults()
    if not CLP.DefaultJobs then
        CLP.Warn('[jobs] CLP.DefaultJobs not loaded — skipping seed')
        return
    end
    local insertedJobs, insertedGrades = 0, 0
    for name, def in pairs(CLP.DefaultJobs) do
        local existing = CLP.DB.single('SELECT name FROM clp_jobs WHERE name = ? LIMIT 1', { name })
        if not existing then
            CLP.DB.executeSync(
                'INSERT INTO clp_jobs (name, label, whitelisted, category) VALUES (?, ?, ?, ?)',
                { name, def.label, def.whitelisted or 0, def.category }
            )
            insertedJobs = insertedJobs + 1
        end
        for grade, gdata in pairs(def.grades or {}) do
            local g = CLP.DB.single(
                'SELECT job FROM clp_job_grades WHERE job = ? AND grade = ? LIMIT 1',
                { name, grade }
            )
            if not g then
                CLP.DB.executeSync(
                    'INSERT INTO clp_job_grades (job, grade, label, salary) VALUES (?, ?, ?, ?)',
                    { name, grade, gdata.label, gdata.salary or 0 }
                )
                insertedGrades = insertedGrades + 1
            end
        end
    end
    if insertedJobs > 0 or insertedGrades > 0 then
        CLP.Log('[jobs] Seeded %d job(s) + %d grade(s)', insertedJobs, insertedGrades)
    end
end

-- ============================================================
--  LOAD-FROM-DB
-- ============================================================
local function loadRegistry()
    registry = {}
    local jobRows = CLP.DB.query('SELECT name, label, whitelisted, category FROM clp_jobs')
    if type(jobRows) ~= 'table' then jobRows = {} end
    for _, row in ipairs(jobRows) do
        local grades = CLP.DB.query(
            'SELECT grade, label, salary FROM clp_job_grades WHERE job = ? ORDER BY grade ASC',
            { row.name }
        )
        registry[row.name] = buildJobShape(row, grades or {})
    end
    -- Fallback: wenn DB leer (z.B. weil seed schief ging), wenigstens 'unemployed' bereitstellen
    if not registry.unemployed then
        registry.unemployed = {
            name = 'unemployed', label = 'Arbeitslos', whitelisted = false, category = 'civilian',
            grades = { [0] = { grade = 0, label = 'Buerger', salary = 0 } },
        }
    end
    CLP.Log('[jobs] Registry geladen: %d Jobs', (function() local n=0 for _ in pairs(registry) do n=n+1 end return n end)())
end

-- ============================================================
--  PUBLIC GETTERS
-- ============================================================
function Jobs:GetAll()
    return registry
end

function Jobs:Get(name)
    return registry[name]
end

function Jobs:GetGrade(name, grade)
    local j = registry[name]
    if not j then return nil end
    return j.grades[tonumber(grade) or 0]
end

function Jobs:Exists(name)
    return registry[name] ~= nil
end

-- ============================================================
--  SET-JOB  (strikte Validierung — Phase 2)
-- ============================================================
function Jobs:SetJob(src, name, grade, reason)
    local p = CLP.GetPlayer(src)
    if not p then return false, 'no_player' end
    if not p:IsAttached() then return false, 'not_attached' end

    local job = registry[name]
    if not job then
        CLP.Warn(CLP.L.job_unknown, tostring(name))
        return false, 'unknown_job'
    end
    local g = job.grades[tonumber(grade) or 0]
    if not g then
        CLP.Warn(CLP.L.job_grade_unknown, tostring(name), tostring(grade))
        return false, 'unknown_grade'
    end

    local old = p:GetJob()

    if CLP.Hooks then
        local ok = CLP.Hooks:Fire('before:job:change', { src = src, from = old, to = { name = job.name, grade = g.grade }, reason = reason })
        if ok == false then return false, 'cancelled' end
    end

    p.job.name        = job.name
    p.job.label       = job.label
    p.job.grade       = g.grade
    p.job.grade_label = g.label
    p.job.salary      = g.salary
    p.job.on_duty     = false  -- bei Job-Wechsel off-duty
    p:MarkDirty()

    TriggerEvent(CLP.Events.JobChanged, src, p:GetJob(), old, reason)
    TriggerClientEvent(CLP.Events.JobChanged, src, p:GetJob(), old, reason)
    if Config.EmitEsxEvents then
        TriggerClientEvent('esx:setJob', src, p:GetJob(), old)
        TriggerEvent('esx:setJob', src, p:GetJob(), old)
    end
    CLP.Log(CLP.L.job_changed, old.name or '-', p:GetJob().name, p:GetJob().grade)
    if p.citizenid and CLP.Log.audit then
        CLP.Log.audit(p.citizenid, 'job_change', { from = old, to = p:GetJob(), reason = reason }, 'system')
    end
    if CLP.Hooks then
        CLP.Hooks:Fire('after:job:change', { src = src, from = old, to = p:GetJob(), reason = reason })
    end
    return true
end

-- ============================================================
--  SET-DUTY
-- ============================================================
function Jobs:SetDuty(src, onDuty)
    local p = CLP.GetPlayer(src)
    if not p then return false end
    local prev = p.job.on_duty
    p.job.on_duty = (onDuty == true)
    p:MarkDirty()
    TriggerEvent(CLP.Events.JobDuty, src, p.job.on_duty)
    TriggerClientEvent(CLP.Events.JobDuty, src, p.job.on_duty)
    if CLP.Hooks then
        CLP.Hooks:Fire('after:job:duty', { src = src, on_duty = p.job.on_duty, was = prev })
    end
    return true
end

-- ============================================================
--  REGISTER  (Runtime-Add eines Jobs — INSERT in DB + Registry)
-- ============================================================
function Jobs:Register(name, label, opts)
    opts = opts or {}
    if registry[name] then return false, 'already_exists' end
    CLP.DB.executeSync(
        'INSERT INTO clp_jobs (name, label, whitelisted, category) VALUES (?, ?, ?, ?)',
        { name, label, opts.whitelisted and 1 or 0, opts.category }
    )
    local grades = opts.grades or { [0] = { label = label, salary = 0 } }
    for grade, gdata in pairs(grades) do
        CLP.DB.executeSync(
            'INSERT INTO clp_job_grades (job, grade, label, salary) VALUES (?, ?, ?, ?)',
            { name, grade, gdata.label, gdata.salary or 0 }
        )
    end
    registry[name] = {
        name = name, label = label,
        whitelisted = opts.whitelisted == true,
        category = opts.category,
        grades = {},
    }
    for grade, gdata in pairs(grades) do
        registry[name].grades[tonumber(grade)] = {
            grade = tonumber(grade), label = gdata.label, salary = gdata.salary or 0,
        }
    end
    return true
end

-- ============================================================
--  RELOAD
-- ============================================================
function Jobs:Reload()
    loadRegistry()
    return true
end

-- ============================================================
--  SALARY-TICK
-- ============================================================
local function paySalary()
    if not Config.SalaryEnabled then return end
    local paid, total = 0, 0
    for _, src in ipairs(CLP.GetPlayers()) do
        local p = CLP.GetPlayer(src)
        if p and p:IsAttached() then
            local job = p:GetJob()
            if job and job.salary and job.salary > 0 then
                -- nur on-duty zahlt, oder wenn Config.SalaryRequireDuty = false
                if (not Config.SalaryRequireDuty) or job.on_duty then
                    local amount = math.floor(job.salary)
                    if amount > 0 and CLP.Money then
                        CLP.Money:Add(src, 'bank', amount, 'salary')
                        paid  = paid + 1
                        total = total + amount
                        if CLP.Notify then
                            CLP.Notify(src, (CLP.L.salary_paid or 'Gehalt erhalten: %d$'):format(amount), 'success', 4000)
                        end
                    end
                end
            end
        end
    end
    if paid > 0 then
        CLP.Log('[jobs] Salary-Tick: %d Spieler ausbezahlt (%d$ insgesamt)', paid, total)
    end
end

CreateThread(function()
    -- Warte bis Resource voll geladen ist
    Wait(2000)
    -- Erst seed, dann load — beides idempotent
    local ok = pcall(seedDefaults)
    if not ok then CLP.Warn('[jobs] seedDefaults pcall failed') end
    pcall(loadRegistry)

    -- Salary-Tick
    if Config.SalaryEnabled and (Config.SalaryInterval or 0) > 0 then
        while true do
            Wait(Config.SalaryInterval)
            pcall(paySalary)
        end
    end
end)

CLP.RegisterModule('Jobs', Jobs)
