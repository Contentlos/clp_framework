--[[
    clp_framework — Player-Klasse (Phase 1)

    Reprasentiert einen ONLINE-Spieler MIT ausgewaehltem Charakter.

    Lebenszyklus:
        1. Player.New(src, userId)            -> leeres Skelett (kein Charakter)
        2. player:AttachCharacter(row)        -> fuellt aus clp_characters-Row
        3. spaeter: player:Save()             -> UPDATE clp_characters (async)
        4. player:MarkDirty()                 -> wird vom AutoSave-Loop persistiert
        5. player:Detach() bei Disconnect     -> finaler Save

    Methoden (Auswahl):
        GetSource / GetIdentifier / GetCitizenId / GetFullName
        GetMoney(account) / AddMoney / RemoveMoney / HasMoney
        GetJob() / SetJob(name, grade)
        GetMeta(key) / SetMeta(key, value)
        SetPosition({x,y,z,h})
        GetSerializableData()         -> Subset fuer den Client (kein DB-Kram)
        Save()                        -> async persistieren
        IsAttached()                  -> hat citizenid
]]

local Player = {}
Player.__index = Player

-- ============================================================
--  CONSTRUCTOR
-- ============================================================
function Player.New(src, userId)
    local self = setmetatable({}, Player)
    self.source     = tonumber(src) or 0
    self.identifier = userId or CLP.Identity.GetPrimary(self.source)
    self.idents     = CLP.Identity.GetAll(self.source) or {}
    self.name       = (self.source > 0 and GetPlayerName(self.source)) or 'unknown'
    self.loadedAt   = CLP.Util.nowMs()

    -- Charakter-Daten (gefuellt nach AttachCharacter)
    self.citizenid  = nil
    self.slot       = nil
    self.firstname  = nil
    self.lastname   = nil
    self.gender     = 'm'
    self.birthdate  = nil
    self.nationality= nil
    self.phone      = nil

    self.money = { cash = 0, bank = 0, black_money = 0 }
    self.job   = {
        name        = Config.DefaultJob or 'unemployed',
        grade       = Config.DefaultJobGrade or 0,
        label       = 'Arbeitslos',
        grade_label = 'Niemand',
        salary      = 0,
        on_duty     = false,
    }
    self.gang  = { name = nil, grade = 0 }
    self.metadata = { hunger = 100, thirst = 100, stress = 0, skin = nil }
    self.position = nil

    self.attached   = false  -- echter Charakter geladen?
    self.dirty      = false  -- gibt es ungespeicherte Aenderungen?
    self.lastSaveAt = 0
    return self
end

-- ============================================================
--  CHARACTER ATTACHMENT
-- ============================================================

--- Befuellt das Player-Objekt aus einer clp_characters-Row.
--- @param row table  full clp_characters row
function Player:AttachCharacter(row)
    if type(row) ~= 'table' or not row.citizenid then return false end
    local Characters = CLP.GetModule('Characters')
    local decode = Characters and Characters._decodeJson or function(_, fb) return fb end

    self.citizenid   = row.citizenid
    self.slot        = tonumber(row.slot) or 1
    self.firstname   = row.firstname
    self.lastname    = row.lastname
    self.gender      = row.gender or 'm'
    self.birthdate   = row.birthdate
    self.nationality = row.nationality
    self.phone       = row.phone

    self.money.cash        = tonumber(row.cash)        or 0
    self.money.bank        = tonumber(row.bank)        or 0
    self.money.black_money = tonumber(row.black_money) or 0

    self.job.name    = row.job or self.job.name
    self.job.grade   = tonumber(row.job_grade) or 0
    self.job.on_duty = (tonumber(row.on_duty) or 0) == 1
    self.gang.name   = row.gang
    self.gang.grade  = tonumber(row.gang_grade) or 0

    -- JSON-Felder
    local meta = decode(row.metadata, { hunger = 100, thirst = 100, stress = 0 })
    if type(meta) == 'table' then self.metadata = meta end
    local pos = decode(row.position, nil)
    if type(pos) == 'table' then self.position = pos end

    self.attached   = true
    self.dirty      = false
    self.lastSaveAt = CLP.Util.nowMs()
    return true
end

function Player:IsAttached()
    return self.attached == true and self.citizenid ~= nil
end

function Player:MarkDirty()
    self.dirty = true
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
--  MONEY
-- ============================================================
function Player:GetMoney(account)
    account = account or 'cash'
    return self.money[account] or 0
end

function Player:AddMoney(account, amount, _reason)
    amount  = tonumber(amount) or 0
    if amount <= 0 then return false end
    account = account or 'cash'
    if self.money[account] == nil then return false end
    self.money[account] = self.money[account] + amount
    self:MarkDirty()
    return true
end

function Player:RemoveMoney(account, amount, _reason)
    amount  = tonumber(amount) or 0
    if amount <= 0 then return false end
    account = account or 'cash'
    if (self.money[account] or 0) < amount then return false end
    self.money[account] = self.money[account] - amount
    self:MarkDirty()
    return true
end

function Player:HasMoney(account, amount)
    return (self.money[account or 'cash'] or 0) >= (tonumber(amount) or 0)
end

-- ============================================================
--  JOB
-- ============================================================
function Player:GetJob()
    return CLP.Util.deepcopy(self.job)
end

function Player:SetJob(name, grade)
    self.job.name  = tostring(name or self.job.name)
    self.job.grade = tonumber(grade or self.job.grade) or 0
    self:MarkDirty()
    return true
end

function Player:SetDuty(onDuty)
    self.job.on_duty = onDuty and true or false
    self:MarkDirty()
end

function Player:OnDuty()  return self.job.on_duty == true end

-- ============================================================
--  METADATA / POSITION
-- ============================================================
function Player:GetMeta(key)
    if key == nil then return CLP.Util.deepcopy(self.metadata) end
    return self.metadata[key]
end

function Player:SetMeta(key, value)
    self.metadata[key] = value
    self:MarkDirty()
end

function Player:SetPosition(pos)
    if type(pos) ~= 'table' then return false end
    self.position = { x = pos.x, y = pos.y, z = pos.z, h = pos.h or pos.heading }
    self:MarkDirty()
    return true
end

function Player:GetPosition()
    return CLP.Util.deepcopy(self.position)
end

-- ============================================================
--  SERIALISIERUNG (an Client schicken)
-- ============================================================
function Player:GetSerializableData()
    return {
        identifier = self.identifier,
        citizenid  = self.citizenid,
        slot       = self.slot,
        firstname  = self.firstname,
        lastname   = self.lastname,
        gender     = self.gender,
        phone      = self.phone,
        money      = CLP.Util.deepcopy(self.money),
        job        = CLP.Util.deepcopy(self.job),
        gang       = CLP.Util.deepcopy(self.gang),
        metadata   = CLP.Util.deepcopy(self.metadata),
        position   = CLP.Util.deepcopy(self.position),
    }
end

-- ============================================================
--  PERSISTENCE
-- ============================================================
function Player:Save()
    if not self:IsAttached() then return false end
    local Characters = CLP.GetModule('Characters')
    if not Characters then return false end

    local ok = Characters.Save(self.citizenid, {
        firstname   = self.firstname,
        lastname    = self.lastname,
        gender      = self.gender,
        birthdate   = self.birthdate,
        nationality = self.nationality,
        phone       = self.phone,
        job         = self.job.name,
        job_grade   = self.job.grade,
        on_duty     = self.job.on_duty and 1 or 0,
        gang        = self.gang.name,
        gang_grade  = self.gang.grade,
        cash        = math.floor(self.money.cash or 0),
        bank        = math.floor(self.money.bank or 0),
        black_money = math.floor(self.money.black_money or 0),
        metadata    = self.metadata,
        position    = self.position,
    })

    if ok then
        self.dirty      = false
        self.lastSaveAt = CLP.Util.nowMs()
        CLP.Dbg('player saved: cid=%s', tostring(self.citizenid))
    else
        CLP.Warn(CLP.L.player_save_failed, self.citizenid or '?', 'characters.save returned false')
    end
    return ok
end

-- ============================================================
--  EVENTS
-- ============================================================
function Player:TriggerEvent(name, ...)
    if self.source > 0 then
        TriggerClientEvent(name, self.source, ...)
    end
end

function Player:ShowNotification(message, ntype, duration)
    self:TriggerEvent('clp:ui:notify', message, ntype, duration)
end

-- ============================================================
--  REGISTRIEREN
-- ============================================================
CLP.RegisterModule('PlayerClass', Player)
