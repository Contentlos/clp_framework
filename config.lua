--[[
    clp_framework — Bootstrap-Konfiguration

    Diese Datei enthält nur Werte, die BEIM START vorhanden sein müssen.
    Alles andere (Jobs, Items, Doors, Vehicles-Defaults) lebt in der Datenbank
    bzw. im jeweiligen Modul-Config und ist später in-game editierbar
    (kommt in Phase 3+).

    Konvention: Werte hier dürfen vom Server-Owner überschrieben werden;
    der Code im Framework liest ausschließlich über die Config-Tabelle.
]]

Config = Config or {}

-- ============================================================
--  ALLGEMEIN
-- ============================================================
Config.Locale          = 'de'      -- Aktuell nur 'de' implementiert. (i18n bewusst weggelassen.)
Config.Debug           = false     -- true = ausführliche Logs auf der Server-Konsole
Config.AutoApplySchema = true      -- false = Schema nicht automatisch anwenden (manuell via SQL)

-- ============================================================
--  IDENTIFIKATION
--  Reihenfolge bestimmt welcher Identifier als "primary" gilt.
--  Erster verfügbarer wird genommen. license / license2 sind robust.
-- ============================================================
Config.PrimaryIdentifier = 'license'  -- 'license' | 'license2' | 'steam' | 'discord' | 'fivem' | 'xbl'

-- ============================================================
--  CHARAKTER / ACCOUNT
-- ============================================================
Config.MaxCharacters    = 3              -- Max Charaktere pro User
Config.AutoSaveInterval = 5 * 60 * 1000  -- 5 Min — alle Online-Charaktere auf DB persistieren
Config.StartCash        = 500            -- Startgeld bei neuem Charakter
Config.StartBank        = 5000           -- Start-Bank
Config.StartBlackMoney  = 0

-- ============================================================
--  ADMIN-GRUPPEN
--  Akzeptierte Gruppen-Strings aus der `users.group`-Spalte.
--  Wird bei Resource-Start in den Permissions-Cache geladen.
-- ============================================================
Config.AdminGroups = { 'admin', 'superadmin', 'owner' }

-- Zusätzlich kann ACE genutzt werden (z.B. via 'command.clpadmin')
Config.AdminAceCheck = nil  -- nil = aus

-- ============================================================
--  ESX-BRIDGE
-- ============================================================
Config.EnableEsxBridge   = true   -- ESX-kompatible Exports + xPlayer-Shape
Config.EmitEsxEvents     = true   -- Fire 'esx:playerLoaded' / 'esx:setJob' / 'esx:setAccountMoney' etc.
Config.EsxSharedObjName  = 'es_extended' -- Export-Resource-Name für getSharedObject() — Standard-ESX
                                          -- (Resource muss NICHT existieren; das Framework registriert
                                          --  den Export selber. Wir matchen den Standard-Namen damit
                                          --  Resources wie clp_gmenu ohne Änderung funktionieren.)

-- ============================================================
--  LOGGING  (Phase 3)
-- ============================================================
Config.LogToConsole     = true
Config.LogToFile        = true
Config.LogFilePath      = 'logs/clp_framework.log'  -- relativ zur Resource (logs/-Ordner wird erstellt)
Config.LogLevel         = 'info'  -- 'debug' | 'info' | 'warn' | 'error'  (debug muss separat aktiv sein)

-- Discord-Webhook (optional). Wenn gesetzt, werden Logs der konfigurierten Levels
-- als Embed gepostet. URL siehe Discord -> Channel-Einstellungen -> Integrations.
Config.LogDiscordHook   = nil   -- z.B. 'https://discord.com/api/webhooks/...'
Config.LogDiscordUsername = 'CLP-Framework'
Config.LogDiscordLevels  = { 'error', 'warn' }  -- welche Levels gesendet werden
Config.LogDiscordAudit   = false                -- alle audit() ebenfalls posten

-- ============================================================
--  PHASE-0-MODE
--  In Phase 0 lief das Framework im SkeletonMode: keine DB-Charakter-Daten,
--  Spieler wurden nur "gerippt" damit Bridges nicht crashen.
--  In Phase 1+ ist das aus — Spieler werden aus clp_characters geladen.
-- ============================================================
Config.SkeletonMode = false

-- ============================================================
--  PHASE-1-MODE  (Auto-Char-Select bis UI in Phase 4 existiert)
--
--  Wenn true:  Joinende Spieler ohne Charakter bekommen automatisch einen
--              "Default-Charakter" (siehe Config.DefaultChar*) und werden
--              direkt geladen. Spieler mit 1+ Charakteren bekommen den
--              zuletzt gespielten (last_seen DESC).
--  Wenn false: Server sendet CharList-Event an Client und wartet auf
--              CharSelect/CharCreate vom Client (Char-Select-UI — Phase 4).
-- ============================================================
Config.AutoCharSelect      = true
Config.DefaultCharFirstname = 'Max'
Config.DefaultCharLastname  = 'Mustermann'
Config.DefaultCharGender    = 'm'   -- 'm' | 'f' | 'd'

-- ============================================================
--  DEFAULTS — werden in Phase 1+ in DB-Seeds verschoben
-- ============================================================
Config.DefaultJob       = 'unemployed'
Config.DefaultJobGrade  = 0

-- ============================================================
--  JOBS / SALARY  (Phase 2)
--
--  Jobs werden beim ersten Resource-Start aus shared/jobs.default.lua
--  in clp_jobs / clp_job_grades geseedet (idempotent).
--  Server-Owner kann die Tabellen anschliessend frei editieren.
-- ============================================================
Config.SalaryEnabled     = true
Config.SalaryInterval    = 10 * 60 * 1000   -- alle 10 Min Gehalt zahlen
Config.SalaryRequireDuty = true             -- false = Gehalt auch off-duty zahlen

