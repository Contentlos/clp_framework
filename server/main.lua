--[[
    clp_framework — Server-Entry (zuletzt geladen in shared/server_scripts)

    Initialisiert DB-Schema beim Start, druckt Banner.
]]

local function banner()
    local mode
    if Config.SkeletonMode then mode = 'SKELETON'
    elseif Config.AutoCharSelect then mode = 'AUTO-CHAR'
    else mode = 'CHAR-SELECT' end
    print('')
    print('^2========================================================^7')
    print(('^2  clp_framework v%s  —  Phase %d  —  %s^7'):format(CLP.Version, CLP.Phase, mode))
    print('^2  © Contentlos / CLP^7')
    print('^2========================================================^7')
    if Config.SkeletonMode then
        CLP.Warn(CLP.L.skeleton_mode_warning)
    elseif CLP.Phase == 1 then
        CLP.Log(CLP.L.phase1_mode_info)
    end
end

-- ============================================================
--  STARTUP
-- ============================================================
AddEventHandler('onResourceStart', function(name)
    if name ~= CLP.ResourceName then return end

    banner()
    CLP.Log(CLP.L.framework_started, CLP.Phase, CLP.Version)

    -- Schema in nicht-blockierendem Thread anwenden
    CreateThread(function()
        Wait(100)
        local ok = pcall(function() CLP.DB.applySchema() end)
        if not ok then
            CLP.Err('Schema-Anwendung übersprungen (oxmysql nicht bereit?). Manuelles Anwenden empfohlen.')
        end
    end)
end)
