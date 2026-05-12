# clp_framework

> **Modernes, modulares FiveM-Framework — Standalone mit ESX-Bridge.**
> © Contentlos / CLP — Alle Rechte vorbehalten (siehe [LICENSE.md](./LICENSE.md))

---

## Status

| Phase | Inhalt | Status |
|-------|--------|--------|
| **0** | Skeleton, Core-Loader, DB-Schema, Identity, ESX-Bridge | ✅ aktuell |
| 1 | Player-Klasse vollständig (Money/Persistence/Login/Char-Select) | ⏳ geplant |
| 2 | Jobs/Grades-Registry, Salary-Tick, ESX-Job-Kompat | ⏳ geplant |
| 3 | Logger ausbauen (Discord-Webhook), Commands (/setjob /addmoney) | ⏳ geplant |
| 4 | `modules/ui` voll (Notify / Menu / Progress / Input — eigene NUI) | ⏳ geplant |
| 5 | `modules/inventory` voll (Items, Slots, D&D, Hotbar, Drops, Trade) | ⏳ geplant |
| 6 | `modules/vehicles` voll (Spawn, Garage, Keys, Persistence) | ⏳ geplant |
| 7 | `modules/doors` voll (Registry, Auth, Admin-Editor) | ⏳ geplant |
| 8 | `modules/phone` Stub für späteres Phone-Resource | ⏳ geplant |
| 9 | Doku, Migration-Guide ESX→CLP, Beispiel-Resource | ⏳ geplant |

> **Aktuell läuft das Framework im SKELETON-MODE** (`Config.SkeletonMode = true`).
> Spieler werden zwar geladen und der ESX-Bridge funktioniert (für `clp_gmenu` etc.),
> aber **keine Charakter-Daten aus der DB** werden geholt. Wird in Phase 1 ausgeschaltet.

---

## Features (Übersicht — finaler Zielzustand)

- **Mega-Core**: Player, Money, Jobs, Inventory, Vehicles/Garage, Doors, Phone-Stub — alles in einer Resource.
- **Standalone + ESX-Bridge**: Eigene saubere API (`CLP.GetPlayer(src)`, `CLP.Money:Add(...)`, ...), plus ESX-kompatibler Layer (`ESX.GetPlayerFromId`, `xPlayer.*`, `esx:playerLoaded`, ...) damit bestehende ESX-Resources einfach laufen.
- **OneSync Infinity-ready**: gebaut für 128 Spieler, Batch-Writes, Caching, server-authoritative.
- **Alles eigen** — kein `ox_lib`, kein `ox_inventory`, kein `ox_target`. Eigene NUI (Vanilla HTML/CSS/JS), eigenes Inventory, eigene UI-Library.
- **Externes Target-System**: `clp_gmenu` wird als Eye-Target-Provider genutzt — wir duplizieren das nicht.
- **DB**: oxmysql mit automatischem Schema-Bootstrap (idempotent).
- **Deutsche Player-Strings** (hardcoded), englischer Identifier-Style im Code.

---

## Tech-Stack

| Layer | Technologie |
|-------|-------------|
| DB-Driver | **oxmysql** |
| Util / UI | **eigene NUI** (Vanilla HTML/CSS/JS) — kein ox_lib |
| Target / Eye-Menu | **`clp_gmenu`** (separates Repo, optional) |
| Bridge | **ESX-Legacy-Shape** (xPlayer, ESX.GetPlayerFromId, esx:playerLoaded) |
| Player-Identifier | `license` als Primary (per Config umschaltbar auf license2 / steam / discord) |
| Namespace | `CLP` (Default) + `Framework` (Alias) |

---

## Installation

1. Resource nach `resources/[CLP]/clp_framework` kopieren.
2. In `server.cfg` (Reihenfolge wichtig):
   ```cfg
   ensure oxmysql
   ensure clp_framework
   # ggf. später:
   # ensure clp_gmenu
   # ensure clp_inventory
   # ...
   ```
3. Server starten. Beim ersten Start wird das DB-Schema automatisch angelegt
   (`clp_users`, `clp_characters`, `clp_character_log`, `clp_jobs`, `clp_job_grades`,
   `clp_character_inventory`, `clp_character_vehicles`, `clp_doors`, `clp_kv`).

> **Phase 0:** Spieler werden im SkeletonMode geladen — d.h. die ESX-Bridge funktioniert
> sofort (für `clp_gmenu`), aber keine echten Charakter-Daten. Charakter-Auswahl + DB-Load
> kommen in Phase 1.

### Debug

Setze `Config.Debug = true` in `config.lua` für ausführliche Server-Konsolen-Logs.

---

## Architektur

```
clp_framework/
├── fxmanifest.lua
├── config.lua                       — Bootstrap-Konfig
├── LICENSE.md
├── README.md
│
├── shared/
│   ├── core.lua                     — CLP + Framework Globals, Loader, RegisterModule
│   ├── utils.lua                    — round/clamp/deepcopy/uuid/citizenid/…
│   ├── locale.lua                   — alle Deutschen Strings (hardcoded)
│   └── events.lua                   — Event-Konstanten (CLP.Events.*)
│
├── server/
│   ├── main.lua                     — Banner + Schema-Apply
│   ├── db.lua                       — oxmysql-Wrapper + Schema-Splitter + KV-Store
│   ├── identity.lua                 — Identifier-Resolver
│   ├── permissions.lua              — Groups, IsAdmin
│   ├── logger.lua                   — Console/Audit
│   ├── player.lua                   — Player-Klasse
│   ├── players.lua                  — Manager (CLP.GetPlayer, LoadPlayer, UnloadPlayer)
│   ├── money.lua                    — CLP.Money:Add/Remove/Has/Transfer
│   ├── jobs.lua                     — CLP.Jobs:SetJob/SetDuty
│   ├── events.lua                   — playerConnecting / Joining / Dropped
│   ├── commands.lua                 — /clpinfo /clpid /clpwho
│   ├── sql/schema.sql               — Initial-Schema (auto-applied)
│   └── bridge/esx.lua               — ESX-Legacy-Shape (xPlayer, GetPlayerFromId, …)
│
├── client/
│   ├── main.lua                     — PlayerData-Mirror + Event-Receiver
│   ├── player.lua                   — CLP.GetPlayerData / GetMoney / GetJob / IsLoaded
│   ├── events.lua                   — Spawn-Events
│   ├── commands.lua                 — Phase 3 Platzhalter
│   └── bridge/esx.lua               — Client-ESX-Shape
│
└── modules/
    ├── ui/                          — Notify / Menu / Progress / Input + HTML-NUI
    ├── inventory/                   — Phase 5
    ├── vehicles/                    — Phase 6
    ├── doors/                       — Phase 7
    └── phone/                       — Phase 8 (nur Stub)
```

---

## API (Phase 0)

### Server

```lua
-- Player-Manager
local p = CLP.GetPlayer(src)                    -- → Player | nil
local list = CLP.GetPlayers()                    -- → number[]
local p = CLP.GetPlayerByIdentifier('license:abc')
local p = CLP.GetPlayerByCitizenId('K3F7A21B')

-- Player-Methoden
p:GetSource()       p:GetIdentifier()   p:GetCitizenId()
p:GetFullName()     p:GetIdent('steam')
p:GetMoney('cash' | 'bank' | 'black_money')
p:HasMoney('bank', 100)
p:GetJob()          p:SetJob('police', 2)
p:GetMeta('hunger')  p:SetMeta('hunger', 50)

-- Money-Service
CLP.Money:Get(src, 'bank')
CLP.Money:Add(src, 'cash', 500, 'reward')
CLP.Money:Remove(src, 'bank', 100, 'purchase')
CLP.Money:Has(src, 'cash', 50)
CLP.Money:Transfer(srcFrom, srcTo, 'cash', 100, 'tip')

-- Jobs
CLP.Jobs:SetJob(src, 'police', 3, 'admin_promo')
CLP.Jobs:SetDuty(src, true)

-- DB
CLP.DB.query('SELECT * FROM ...', { params })           -- async
CLP.DB.single('SELECT * FROM ... LIMIT 1', { params })
CLP.DB.querySync('CREATE TABLE ...')                    -- nur Init
CLP.DB.kv.set('foo', { any = 'value' })
CLP.DB.kv.get('foo', defaultValue)

-- Permissions
CLP.Perms.IsAdmin(src)
CLP.Perms.GetGroup(src)

-- Logger / Audit
CLP.Log.info('Test %d', 42)
CLP.Log.audit(citizenid, 'money_add', { amount = 100 }, 'system')

-- Events (Konstanten)
CLP.Events.PlayerLoaded   -- 'clp:player:loaded'
CLP.Events.MoneyChanged   -- 'clp:money:changed'
CLP.Events.JobChanged     -- 'clp:job:changed'
```

### Client

```lua
CLP.GetPlayerData()   -- { identifier, citizenid, firstname, lastname, job, money, … }
CLP.GetMoney('bank')
CLP.GetJob()
CLP.GetCitizenId()
CLP.GetFullName()
CLP.IsLoaded          -- bool

-- UI
CLP.UI.Notify('Hallo Welt', 'success', 4000)
CLP.UI.OpenMenu({ title = 'Auswahl', items = { … } })
CLP.UI.Progress({ label = 'Lockpicking', duration = 5000 }, function(done) … end)
local input = CLP.UI.Input({ title = 'Plate' })
```

### ESX-Bridge (für Drittanbieter-Resources, z.B. clp_gmenu)

```lua
-- Server
local ESX = exports.clp_framework:GetSharedObject()
local xPlayer = ESX.GetPlayerFromId(src)
xPlayer.getMoney()          xPlayer.addMoney(100)
xPlayer.getJob()            xPlayer.setJob('police', 2)
xPlayer.getIdentifier()     xPlayer.showNotification('Hi')
ESX.RegisterUsableItem('bandage', function(src) … end)

-- Client
local ESX = exports.clp_framework:GetSharedObject()
local data = ESX.GetPlayerData()

-- Events (vom Framework gefeuert wenn Config.EmitEsxEvents=true):
RegisterNetEvent('esx:playerLoaded', function(data) … end)
RegisterNetEvent('esx:setJob',      function(newJob, oldJob) … end)
RegisterNetEvent('esx:setAccountMoney', function(account) … end)
```

---

## Lizenz

Custom Commercial — kostenlos für private Server, **keine Modifikation außerhalb dieses Repos**, kein Re-Sale, Credits müssen bleiben, kommerziell nur mit Lizenz.

Volltext: [LICENSE.md](./LICENSE.md)

---

*Build-Plan: [clp_framework_plan.md](https://github.com/Contentlos/clp_framework/) — wird in den nächsten PRs umgesetzt.*
