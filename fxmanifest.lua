--[[
    clp_framework — Modernes FiveM-Framework
    © Contentlos / CLP

    Standalone Player- / Money- / Job- / Inventory- / Vehicle- / Door- / Phone-Framework
    mit optionaler ESX-Bridge für Kompatibilität zu bestehenden ESX-Resources.

    Frameworks-Globals:
      CLP        — primärer Namespace (CLP.GetPlayer, CLP.Money:Add, ...)
      Framework  — Alias, zeigt auf dasselbe Tabellen-Objekt

    Lade-Reihenfolge in dieser Datei ist BEWUSST gewählt:
      shared/core.lua zuerst (legt CLP / Framework Globals an)
      → utils → locale → events
      → server/db → identity → permissions → logger → player → players → money → jobs → events → commands
      → server/bridge/esx.lua (NACH allen Core-Modulen, weil Bridge sie wrappt)
      → modules/<name>/server/*.lua

    Phase 0 enthält Stubs für Player/Money/Jobs — gefüllt werden sie in Phase 1+.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'clp_framework'
author 'Contentlos / CLP'
version '0.2.0-phase1'
description 'CLP-Framework Core (Player, Money, Jobs, Inventory, Vehicles, Doors, Phone-Stub) mit ESX-Bridge'
repository 'https://github.com/Contentlos/clp_framework'

-- ============================================================
--  NUI (Mega-Core: UI-Modul, Inventory, Vehicles, Doors haben eigene NUIs)
-- ============================================================
ui_page 'modules/ui/html/index.html'

files {
    -- UI-Modul (Notify, Menu, Progress, Input)
    'modules/ui/html/index.html',
    'modules/ui/html/style.css',
    'modules/ui/html/script.js',

    -- Inventory NUI (in Phase 5 gefüllt)
    'modules/inventory/html/index.html',

    -- Vehicles / Garage NUI (in Phase 6 gefüllt)
    'modules/vehicles/html/index.html',

    -- Default-Daten
    'modules/doors/data/doors.default.json',
}

-- ============================================================
--  SHARED — alle Seiten sehen diese Globals (CLP, Framework, Util)
-- ============================================================
shared_scripts {
    'config.lua',
    'shared/core.lua',
    'shared/utils.lua',
    'shared/locale.lua',
    'shared/events.lua',
}

-- ============================================================
--  SERVER
--  Reihenfolge ist wichtig (Abhängigkeiten von oben nach unten)
-- ============================================================
server_scripts {
    -- Core
    'server/db.lua',
    'server/identity.lua',
    'server/permissions.lua',
    'server/logger.lua',
    'server/users.lua',
    'server/characters.lua',
    'server/player.lua',
    'server/players.lua',
    'server/money.lua',
    'server/jobs.lua',
    'server/events.lua',
    'server/commands.lua',
    'server/main.lua',

    -- Module (Phase 0: Stub-Files; Inhalte folgen in Phase 5+)
    'modules/inventory/server/main.lua',
    'modules/vehicles/server/main.lua',
    'modules/doors/server/main.lua',
    'modules/phone/server/main.lua',

    -- Bridges (zuletzt, weil sie Core-Module wrappen)
    'server/bridge/esx.lua',
}

-- ============================================================
--  CLIENT
-- ============================================================
client_scripts {
    -- Core
    'client/main.lua',
    'client/player.lua',
    'client/events.lua',
    'client/commands.lua',

    -- UI-Modul (NUI-Bridge: Notify, Menu, Progress, Input)
    'modules/ui/client/notify.lua',
    'modules/ui/client/menu.lua',
    'modules/ui/client/progress.lua',
    'modules/ui/client/input.lua',

    -- Sub-Module (Stub-Files in Phase 0)
    'modules/inventory/client/main.lua',
    'modules/vehicles/client/main.lua',
    'modules/doors/client/main.lua',
    'modules/phone/client/main.lua',

    -- Bridges (zuletzt)
    'client/bridge/esx.lua',
}

-- ============================================================
--  ABHÄNGIGKEITEN
-- ============================================================
dependencies {
    'oxmysql',
}

-- Bewusst KEINE Abhängigkeit zu es_extended oder ox_lib:
--   - Das Framework ist standalone.
--   - Die ESX-Bridge stellt das ESX-Objekt SELBST bereit (export getSharedObject),
--     sodass Resources die ESX erwarten direkt funktionieren — auch ohne dass
--     es_extended installiert ist.
