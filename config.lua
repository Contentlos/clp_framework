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
--
--  SIDECAR-MODE (Default ab v0.5.1):
--    Wenn du clp_framework PARALLEL zu es_extended laeufst (ESX bleibt das
--    Framework, clp_framework liefert nur UI/Hooks/Logger), MUSS beides hier
--    auf false stehen, sonst kommen sich beide gegenseitig in die Quere.
--
--  DROP-IN-MODE (zukuenftig, wenn clp_framework es_extended ersetzt):
--    Beides auf true und es_extended deinstallieren. clp_framework liefert
--    dann den xPlayer + alle ESX-Events fuer kompatible Resources.
-- ============================================================
Config.EnableEsxBridge   = false  -- ESX-kompatible Exports + xPlayer-Shape (Drop-In-Mode)
Config.EmitEsxEvents     = false  -- Fire 'esx:playerLoaded' / 'esx:onPlayerSpawn' etc. (Drop-In-Mode)
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
--  PLAYER-LIFECYCLE
--
--  SkeletonMode = true:
--    clp_framework lädt KEINEN Spieler aus clp_characters, macht KEIN
--    AttachCharacter, schreibt KEIN clp_users/clp_characters. Das brauchst
--    du im Sidecar-Mode (es_extended verwaltet die Spieler).
--    UI/Hooks/Logger laufen aber trotzdem.
--
--  SkeletonMode = false:
--    Voller Player-Lifecycle aus clp_users/clp_characters mit AttachCharacter,
--    Money/Job-Push an Client, AutoSave-Loop etc. (Drop-In-Mode oder eigener
--    Server ohne ESX).
-- ============================================================
Config.SkeletonMode = true   -- SIDECAR-MODE (Default ab v0.5.1)

-- ============================================================
--  CHARAKTER-AUSWAHL  (Phase 4 NUI ist scharfgeschaltet)
--  Nur relevant wenn Config.SkeletonMode = false (sonst egal).
--
--  Wenn true:  Joinende Spieler ohne Charakter bekommen automatisch einen
--              "Default-Charakter" (siehe Config.DefaultChar*) und werden
--              direkt geladen. Spieler mit 1+ Charakteren bekommen den
--              zuletzt gespielten (last_seen DESC). Schnell-Test-Modus.
--  Wenn false: Server sendet CharList-Event an Client, NUI oeffnet die
--              Vollbild-Char-Auswahl, Spieler waehlt/erstellt/loescht
--              seine Charaktere. (Phase-4-NUI ab Version 0.5.0)
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

