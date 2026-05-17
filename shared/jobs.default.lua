--[[
    clp_framework — Default-Jobs (Phase 2)

    Wird beim Resource-Start in clp_jobs + clp_job_grades geseedet (idempotent).
    Server-Owner kann die Tabellen jederzeit direkt editieren; das Seeding
    ueberschreibt KEINE existierenden Rows.

    Schema:
        CLP.DefaultJobs = {
            <name> = {
                label, whitelisted, category,
                grades = { [grade] = { label, salary } }
            }
        }
]]

CLP.DefaultJobs = {
    -- ============================================================
    --  Zivil
    -- ============================================================
    unemployed = {
        label = 'Arbeitslos', whitelisted = 0, category = 'civilian',
        grades = {
            [0] = { label = 'Buerger', salary = 50 },
        },
    },

    -- ============================================================
    --  Staat
    -- ============================================================
    police = {
        label = 'Polizei', whitelisted = 1, category = 'staat',
        grades = {
            [0] = { label = 'Rekrut',         salary = 200 },
            [1] = { label = 'Polizist',       salary = 300 },
            [2] = { label = 'Oberkommissar',  salary = 400 },
            [3] = { label = 'Inspektor',      salary = 550 },
            [4] = { label = 'Polizeichef',    salary = 750 },
        },
    },
    ambulance = {
        label = 'Sanitaeter', whitelisted = 1, category = 'staat',
        grades = {
            [0] = { label = 'Praktikant',  salary = 200 },
            [1] = { label = 'Sanitaeter',  salary = 300 },
            [2] = { label = 'Notarzt',     salary = 450 },
            [3] = { label = 'Chefarzt',    salary = 650 },
        },
    },
    fire = {
        label = 'Feuerwehr', whitelisted = 1, category = 'staat',
        grades = {
            [0] = { label = 'Anwaerter',     salary = 200 },
            [1] = { label = 'Feuerwehrmann', salary = 300 },
            [2] = { label = 'Brandmeister',  salary = 450 },
            [3] = { label = 'Wachleiter',    salary = 600 },
        },
    },

    -- ============================================================
    --  Companies / Civilian-Jobs
    -- ============================================================
    mechanic = {
        label = 'Mechaniker', whitelisted = 0, category = 'company',
        grades = {
            [0] = { label = 'Lehrling',       salary = 150 },
            [1] = { label = 'Mechaniker',     salary = 250 },
            [2] = { label = 'Meister',        salary = 400 },
            [3] = { label = 'Werkstattchef',  salary = 550 },
        },
    },
    taxi = {
        label = 'Taxi', whitelisted = 0, category = 'company',
        grades = {
            [0] = { label = 'Fahrer',     salary = 100 },
            [1] = { label = 'Fahrlehrer', salary = 200 },
            [2] = { label = 'Chef',       salary = 350 },
        },
    },
    tow = {
        label = 'Abschleppdienst', whitelisted = 0, category = 'company',
        grades = {
            [0] = { label = 'Fahrer',      salary = 120 },
            [1] = { label = 'Schichtleiter', salary = 220 },
            [2] = { label = 'Chef',        salary = 350 },
        },
    },
}
