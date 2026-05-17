--[[
    clp_framework — Doors Server (Phase 0 Stub)
    Phase 7: Door-Registry (DB), Lock/Unlock-Auth, Bulk-Sync, Admin-Editor.
]]

local Doors = {}

function Doors:Get(id)              return nil end
function Doors:Lock(id, locked)     return false end
function Doors:Add(def)             return false end
function Doors:Remove(id)           return false end

CLP.RegisterModule('Doors', Doors)
