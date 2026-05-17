--[[
    clp_framework — Money-Modul (Phase 0: minimal Wrapper)

    Wird in Phase 1+ ausgebaut. Aktuell bietet es nur statische Helper, die
    Player:GetMoney / :AddMoney / :RemoveMoney aufrufen + Events feuern.

    API:
        CLP.Money:Get(src, account)
        CLP.Money:Add(src, account, amount, reason)
        CLP.Money:Remove(src, account, amount, reason)
        CLP.Money:Has(src, account, amount)
        CLP.Money:Transfer(srcFrom, srcTo, account, amount, reason)
]]

local Money = {}

local function getPlayer(src)
    return CLP.GetPlayer(src)
end

function Money:Get(src, account)
    local p = getPlayer(src)
    return p and p:GetMoney(account or 'cash') or 0
end

function Money:Add(src, account, amount, reason)
    local p = getPlayer(src)
    if not p then return false end
    account = account or 'cash'
    amount  = tonumber(amount) or 0
    if amount <= 0 then return false end
    if CLP.Hooks then
        local ok = CLP.Hooks:Fire('before:money:add', { src = src, account = account, amount = amount, reason = reason })
        if ok == false then return false, 'cancelled' end
    end
    local old = p:GetMoney(account)
    if not p:AddMoney(account, amount, reason) then return false end
    local new = p:GetMoney(account)
    TriggerEvent(CLP.Events.MoneyAdded, src, account, amount, reason)
    TriggerEvent(CLP.Events.MoneyChanged, src, account, old, new, reason)
    TriggerClientEvent(CLP.Events.MoneyChanged, src, account, old, new, reason)
    if Config.EmitEsxEvents and (account == 'bank' or account == 'black_money') then
        TriggerClientEvent('esx:setAccountMoney', src, { name = account, money = new })
    end
    if CLP.Hooks then
        CLP.Hooks:Fire('after:money:add', { src = src, account = account, amount = amount, old = old, new = new, reason = reason })
    end
    return true
end

function Money:Remove(src, account, amount, reason)
    local p = getPlayer(src)
    if not p then return false end
    account = account or 'cash'
    amount  = tonumber(amount) or 0
    if amount <= 0 then return false end
    if CLP.Hooks then
        local ok = CLP.Hooks:Fire('before:money:remove', { src = src, account = account, amount = amount, reason = reason })
        if ok == false then return false, 'cancelled' end
    end
    local old = p:GetMoney(account)
    if not p:RemoveMoney(account, amount, reason) then return false end
    local new = p:GetMoney(account)
    TriggerEvent(CLP.Events.MoneyRemoved, src, account, amount, reason)
    TriggerEvent(CLP.Events.MoneyChanged, src, account, old, new, reason)
    TriggerClientEvent(CLP.Events.MoneyChanged, src, account, old, new, reason)
    if Config.EmitEsxEvents and (account == 'bank' or account == 'black_money') then
        TriggerClientEvent('esx:setAccountMoney', src, { name = account, money = new })
    end
    if CLP.Hooks then
        CLP.Hooks:Fire('after:money:remove', { src = src, account = account, amount = amount, old = old, new = new, reason = reason })
    end
    return true
end

function Money:Has(src, account, amount)
    local p = getPlayer(src)
    return p and p:HasMoney(account or 'cash', tonumber(amount) or 0) or false
end

function Money:Transfer(srcFrom, srcTo, account, amount, reason)
    if not self:Has(srcFrom, account, amount) then return false, 'no_money' end
    if not self:Remove(srcFrom, account, amount, reason or 'transfer_out') then return false, 'remove_failed' end
    if not self:Add(srcTo, account, amount, reason or 'transfer_in') then
        -- Rollback
        self:Add(srcFrom, account, amount, 'transfer_rollback')
        return false, 'add_failed'
    end
    return true
end

CLP.RegisterModule('Money', Money)
