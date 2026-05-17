--[[
    clp_framework — Hooks-System (Phase 3)

    Generisches Pub/Sub mit Cancel-Faehigkeit. Andere Resources koennen
    bei Framework-Aktionen zwischen-haengen (z.B. "before:moneyAdd" um
    Add zu blockieren, oder "after:jobChange" um etwas auszuloesen).

    Konvention fuer Hook-Namen:
        'before:<area>:<action>'    cancelable (return false -> abort)
        'after:<area>:<action>'     informativ (return-value egal)
        'on:<area>:<action>'        Alias zu after

    Beispiele:
        'before:money:add'
        'after:money:add'
        'before:job:change'
        'before:char:select'

    Public:
        CLP.Hooks:Register(name, fn, priority?)
        CLP.Hooks:Unregister(name, fn)
        CLP.Hooks:Fire(name, ...)               -> (ok, ...result)
        CLP.Hooks:FireSimple(name, ...)         -> (cancelled: bool)
        CLP.Hooks:List(name?)
        CLP.Hooks:Clear(name?)

    Cancel-Semantik:
        - 'before:*' hooks: erster Handler der explizit `false` zurueckgibt,
          beendet die Kette mit ok=false. Numerischer false-Wert oder nil
          gilt nicht als Cancel.
        - 'after:*' hooks: Cancel ist sinnlos, Return-Werte werden ignoriert.

    Priorities:
        Hoehere Zahl = frueher (default 0). Z.B. priority=100 laeuft vor 0.
        Bei gleicher Priority gilt Registrierungs-Reihenfolge.
]]

local Hooks = {}

local handlers = {}   -- [name] = { { fn = fn, prio = number }, ... } (sortiert prio DESC)

local function isBefore(name)
    return type(name) == 'string' and name:sub(1, 7) == 'before:'
end

-- ============================================================
--  REGISTER / UNREGISTER
-- ============================================================
function Hooks:Register(name, fn, priority)
    if type(name) ~= 'string' or type(fn) ~= 'function' then return false end
    handlers[name] = handlers[name] or {}
    local list = handlers[name]
    list[#list + 1] = { fn = fn, prio = tonumber(priority) or 0 }
    table.sort(list, function(a, b) return a.prio > b.prio end)
    return true
end

function Hooks:Unregister(name, fn)
    local list = handlers[name]; if not list then return false end
    for i = #list, 1, -1 do
        if list[i].fn == fn then table.remove(list, i); return true end
    end
    return false
end

-- ============================================================
--  FIRE
-- ============================================================
--- Feuert die Hook-Kette. Bei 'before:*' kann jeder Handler durch
--- Return false die Kette canceln.
--- @return ok boolean   Bei before:* false wenn ein Handler false zurueckgab; sonst true.
--- @return any?         Letzter Return-Wert eines Handlers (informativ).
function Hooks:Fire(name, ...)
    local list = handlers[name]; if not list or #list == 0 then return true end
    local cancellable = isBefore(name)
    local lastResult
    for _, entry in ipairs(list) do
        local ok, result = pcall(entry.fn, ...)
        if not ok then
            if CLP and CLP.Warn then
                CLP.Warn('[hooks] Handler-Error in "%s": %s', name, tostring(result))
            end
        else
            lastResult = result
            if cancellable and result == false then
                return false, lastResult
            end
        end
    end
    return true, lastResult
end

--- Convenience: returns true wenn die Kette gecancelt wurde.
function Hooks:FireSimple(name, ...)
    local ok = self:Fire(name, ...)
    return ok == false
end

-- ============================================================
--  INTROSPECTION
-- ============================================================
function Hooks:List(name)
    if name then
        local list = handlers[name] or {}
        local out = {}
        for i, e in ipairs(list) do out[i] = { prio = e.prio } end
        return out
    end
    local out = {}
    for k, list in pairs(handlers) do out[k] = #list end
    return out
end

function Hooks:Clear(name)
    if name then handlers[name] = nil else handlers = {} end
end

CLP.Hooks = Hooks
CLP.RegisterModule('Hooks', Hooks)
