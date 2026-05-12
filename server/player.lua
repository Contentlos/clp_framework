--[[
    clp_framework — Player-Klasse (Phase 0: Stub)

    In Phase 0 minimaler Skelett-Constructor mit Identifier-Resolver,
    Stub-Methoden für Money/Job, und Persistierung (Save). Die echten
    Werte (Cash/Bank/BlackMoney/Job/Metadata) werden in Phase 1 aus der
    DB geladen + persistiert.

    Verwendung (intern):
        local p = CLP.Player.New(src)
        p:GetIdentifier()  → 'license:abc...'
        p:GetMoney('cash') → 0  (Stub)

    Über CLP.GetPlayer(src) wird ein gecachter Player aus players.lua geholt
    — siehe players.lua.
]]

local Player = {}
Player.__index = Player

-- ============================================================
--  CONSTRUCTOR
-- ============================================================
function Player.New(src)
    local self = setmetatable({}, Player)
    self.source     = tonumber(src) or 0
    self.identifier = CLP.Identity.GetPrimary(self.source)
    self.idents     = CLP.Identity.GetAll(self.source) or {}
    self.name       = (self.source > 0 and GetPlayerName(self.source)) or 'unknown'
    self.loadedAt   = CLP.Util.nowMs()

    -- Phase 0: Charakter-Daten als Stub. Phase 1 lädt sie aus DB.
    self.citizenid  = nil
    self.firstname  = nil
    self.lastname   = nil
    self.gender     = 'm'

    self.money = {
        cash        = 0,
        bank        = 0,
        black_money = 0,
    }

    self.job = {
        name        = Config.DefaultJob or 'unemployed',
        grade       = Config.DefaultJobGrade or 0,
        label       = 'Arbeitslos',
        grade_label = 'Niemand',
        salary      = 0,
        on_duty     = false,
    }

    self.metadata = {
        hunger = 100,
        thirst = 100,
        stress = 0,
        skin   = nil,
    }

    self.position = nil  -- {x,y,z,h}

    return self
end

-- ============================================================
--  IDENTITY ACCESSORS
-- ============================================================
function Player:GetSource()      return self.source end
function Player:GetIdentifier()  return self.identifier end
function Player:GetCitizenId()   return self.citizenid end
function Player:GetName()        return self.name end
function Player:GetFullName()
    if self.firstname and self.lastname then
        return self.firstname .. ' ' .. self.lastname
    end
    return self.name or 'Unbekannt'
end
function Player:GetIdent(kind)   return self.idents[kind] end

-- ============================================================
--  MONEY (Stub in Phase 0 — full logic in money.lua + Phase 1)
-- ============================================================
function Player:GetMoney(account)
    account = account or 'cash'
    return self.money[account] or 0
end

function Player:AddMoney(account, amount, reason)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    account = account or 'cash'
    if self.money[account] == nil then return false end
    self.money[account] = self.money[account] + amount
    -- Phase 1: NetEvent feuern + DB persistieren
    return true
end

function Player:RemoveMoney(account, amount, reason)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    account = account or 'cash'
    if (self.money[account] or 0) < amount then return false end
    self.money[account] = self.money[account] - amount
    return true
end

function Player:HasMoney(account, amount)
    return (self.money[account or 'cash'] or 0) >= (tonumber(amount) or 0)
end

-- ============================================================
--  JOB (Stub)
-- ============================================================
function Player:GetJob()
    return CLP.Util.deepcopy(self.job)
end

function Player:SetJob(name, grade)
    -- Phase 2 implementiert volle Validierung gegen clp_jobs / clp_job_grades.
    self.job.name  = tostring(name or self.job.name)
    self.job.grade = tonumber(grade or self.job.grade) or 0
    return true
end

function Player:OnDuty()  return self.job.on_duty == true end

-- ============================================================
--  METADATA
-- ============================================================
function Player:GetMeta(key)
    if key == nil then return CLP.Util.deepcopy(self.metadata) end
    return self.metadata[key]
end

function Player:SetMeta(key, value)
    self.metadata[key] = value
end

-- ============================================================
--  PERSISTENCE  (Phase 0: NO-OP — Phase 1 implementiert Save)
-- ============================================================
function Player:Save()
    if Config.SkeletonMode then return false end
    -- Phase 1: UPDATE clp_characters SET ... WHERE citizenid = ?
    return false
end

function Player:TriggerEvent(name, ...)
    if self.source > 0 then
        TriggerClientEvent(name, self.source, ...)
    end
end

function Player:ShowNotification(message, ntype, duration)
    self:TriggerEvent(CLP.Events.MoneyChanged, message) -- placeholder bis modules/ui da ist
    -- In Phase 4 (UI-Modul) ersetzen wir das durch ein dediziertes Notify-Event.
end

CLP.RegisterModule('PlayerClass', Player)
return Player
