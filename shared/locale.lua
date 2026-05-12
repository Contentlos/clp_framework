--[[
    clp_framework — Locale-Strings (Deutsch, hardcoded)

    KEIN echtes i18n-System — bewusste Entscheidung (siehe Plan-Doc).
    Strings liegen unter CLP.L für direkten Zugriff:
        CLP.L.player_loaded
        CLP.L.errors.no_money

    Falls jemals Mehrsprachigkeit gewünscht: einfach Datei pro Locale anlegen
    und ein Lookup-Layer drüber bauen — aber nicht jetzt.
]]

local L = {
    -- ============================================================
    --  ALLGEMEIN
    -- ============================================================
    framework_started        = 'CLP-Framework gestartet (Phase %d, v%s).',
    framework_stopped        = 'CLP-Framework wird beendet.',
    skeleton_mode_warning    = 'SKELETON-MODE aktiv — Spieler werden NICHT geladen. (Phase 0)',

    -- ============================================================
    --  DB
    -- ============================================================
    db_connecting            = 'Verbinde zur Datenbank...',
    db_connected             = 'Datenbank-Verbindung steht.',
    db_schema_applied        = 'Datenbank-Schema angewendet (%d Statements).',
    db_schema_skipped        = 'Schema-Auto-Apply ist deaktiviert (Config.AutoApplySchema=false).',
    db_query_failed          = 'DB-Query fehlgeschlagen: %s',

    -- ============================================================
    --  PLAYER / IDENTITY
    -- ============================================================
    player_connecting        = 'Spieler verbindet: %s (src=%s)',
    player_loaded            = 'Spieler geladen: %s (citizenid=%s)',
    player_dropped           = 'Spieler getrennt: %s (Grund: %s)',
    player_no_identifier     = 'Spieler %s hat keinen verwertbaren Identifier — Verbindung abgelehnt.',
    player_save_ok           = 'Spieler %s gespeichert.',
    player_save_failed       = 'Speichern von Spieler %s fehlgeschlagen: %s',

    -- ============================================================
    --  MONEY
    -- ============================================================
    money_added              = 'Geld hinzugefügt: %s (%s)',
    money_removed            = 'Geld abgezogen: %s (%s)',
    money_insufficient       = 'Nicht genug Geld auf %s (benötigt %s, vorhanden %s).',

    -- ============================================================
    --  JOBS
    -- ============================================================
    job_changed              = 'Job geändert: %s → %s (Grade %d)',
    job_unknown              = 'Unbekannter Job: %s',
    job_grade_unknown        = 'Unbekannter Grade für Job %s: %s',

    -- ============================================================
    --  PERMISSIONS
    -- ============================================================
    permission_denied        = 'Keine Berechtigung.',

    -- ============================================================
    --  BRIDGE / ESX
    -- ============================================================
    bridge_esx_enabled       = 'ESX-Bridge aktiv — Resources mit ESX-API funktionieren.',
    bridge_esx_disabled      = 'ESX-Bridge deaktiviert (Config.EnableEsxBridge=false).',

    -- ============================================================
    --  FEHLERMELDUNGEN (Spieler-sichtbar via Notify)
    -- ============================================================
    err_no_money             = 'Du hast nicht genug Geld.',
    err_not_allowed          = 'Das darfst du nicht.',
    err_busy                 = 'Du bist gerade beschäftigt.',
    err_too_far              = 'Du bist zu weit weg.',
    err_internal             = 'Ein interner Fehler ist aufgetreten.',
}

CLP.L = L
CLP.RegisterModule('L', L)
