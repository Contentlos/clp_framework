--[[
    clp_framework — Vehicles Server (Phase 0 Stub)
    Phase 6: Spawn-API, Plate-Generator, Garage, Keys, Persistence, Mod-Save.
]]

local Veh = {}

function Veh:GetByPlate(plate)         return nil end
function Veh:GetOwned(citizenid)       return {} end
function Veh:SpawnFor(src, plate)      return false end
function Veh:StoreAt(plate, garage)    return false end
function Veh:GeneratePlate()           return 'CLP00000' end

CLP.RegisterModule('Veh', Veh)
