--[[
    clp_framework — Inventory Server (Phase 0 Stub)

    Vollständige Implementation in Phase 5: Items-Registry, Slot-Logic,
    Weight/Stack, Anti-Cheat, Stashes, Bodendrops, Trade, Crafting-Hook.

    Hier nur Placeholder-Exports damit andere Module schon dagegen referenzieren
    können, ohne Crashes.
]]

local Inv = {}

function Inv:GetItems(src)             return {} end
function Inv:GetItem(src, item)        return nil end
function Inv:AddItem(src, item, count, meta)    return false end
function Inv:RemoveItem(src, item, count, meta) return false end
function Inv:CanCarry(src, item, count)         return true end
function Inv:UseItem(src, item)        return false end

CLP.RegisterModule('Inv', Inv)
