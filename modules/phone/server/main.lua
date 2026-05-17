--[[
    clp_framework — Phone Server (Phase 0 Stub)

    Das Framework liefert in Phase 8 NUR ein API-Stub für späteres
    Phone-Resource: SendSMS-Hook, Identifier-Resolver, Player-Phone-Number.
    Kein vollständiges Phone-UI in clp_framework — das wäre Sprengung des Scopes.
]]

local Phone = {}

function Phone:GetNumber(citizenid) return nil end
function Phone:SendSMS(fromNumber, toNumber, text) return false end
function Phone:OnSMS(cb) end -- Hook-Registry für Resources

CLP.RegisterModule('Phone', Phone)
