--[[
    clp_framework — Char-Select Client (Phase 4)

    Lauscht auf CLP.Events.CharList (Server sendet die Liste der Charaktere
    beim Connect wenn Config.AutoCharSelect=false). Oeffnet die Vollbild-NUI
    und routet Auswahl/Erstellung/Loeschung an den Server.

    Lifecycle:
      Server   -> Client   CharList  { chars, maxChars }   -> UI zeigt Charselect
      Client   -> Server   CharSelect { citizenid }
      Client   -> Server   CharCreate { firstname, lastname, gender, slot, birthdate }
      Client   -> Server   CharDelete { citizenid }
      Server   -> Client   CharCreated { ok, citizenid?, err? }
      Server   -> Client   CharSelected { ok, citizenid?, err? }
      Server   -> Client   CharDeleted { ok, citizenid?, err? }
      Server   -> Client   PlayerLoaded { ... }            -> UI schliesst

    Fokus-Verwaltung: Sobald die NUI offen ist, wird SetNuiFocus(true, true)
    gesetzt und die Kamera wird auf eine fixe Pos gesetzt (einfach Heaven-Cam).
]]

CLP.UI = CLP.UI or {}

local CharSelectActive = false
local HeavenCam

local function setupCam()
    -- Spieler unsichtbar machen + Heaven-Cam
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    DoScreenFadeOut(0)
    Wait(50)
    DoScreenFadeIn(500)

    -- Cam hoch ueber Karte
    HeavenCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(HeavenCam, 405.91, -996.04, -90.0)
    SetCamRot(HeavenCam, -25.0, 0.0, 180.0, 2)
    SetCamFov(HeavenCam, 50.0)
    RenderScriptCams(true, false, 0, true, false)
end

local function teardownCam()
    if HeavenCam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(HeavenCam, false)
        HeavenCam = nil
    end
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
end

local function show(chars, maxChars)
    if CharSelectActive then return end
    CharSelectActive = true
    SetNuiFocus(true, true)
    setupCam()
    SendNUIMessage({
        action   = 'charselect:show',
        chars    = chars or {},
        maxChars = tonumber(maxChars) or (Config and Config.MaxCharacters) or 3,
    })
end

local function hide()
    if not CharSelectActive then return end
    CharSelectActive = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'charselect:hide' })
    teardownCam()
end

function CLP.UI.ShowCharSelect(chars, maxChars) show(chars, maxChars) end
function CLP.UI.HideCharSelect()                hide() end
function CLP.UI.IsCharSelectOpen()              return CharSelectActive end

-- ============================================================
--  SERVER -> CLIENT  Events
-- ============================================================
RegisterNetEvent(CLP.Events.CharList, function(data)
    if type(data) ~= 'table' then return end
    show(data.chars, data.maxChars)
end)

RegisterNetEvent(CLP.Events.CharCreated, function(data)
    data = data or {}
    if data.ok then
        CLP.UI.Notify(('Charakter erstellt (citizenid %s)'):format(tostring(data.citizenid)), 'success', 4000)
        -- Nach Create kommt eh ein neues CharList vom Server
    else
        CLP.UI.Notify(('Fehler: %s'):format(tostring(data.err or 'unbekannt')), 'error', 6000)
    end
end)

RegisterNetEvent(CLP.Events.CharSelected, function(data)
    data = data or {}
    if data.ok then
        hide()
        -- PlayerLoaded folgt direkt vom Server
    else
        CLP.UI.Notify(('Charakter-Auswahl fehlgeschlagen: %s'):format(tostring(data.err or 'unbekannt')), 'error', 6000)
    end
end)

RegisterNetEvent(CLP.Events.CharDeleted, function(data)
    data = data or {}
    if data.ok then
        CLP.UI.Notify('Charakter geloescht.', 'success', 4000)
    else
        CLP.UI.Notify(('Loeschen fehlgeschlagen: %s'):format(tostring(data.err or 'unbekannt')), 'error', 6000)
    end
end)

RegisterNetEvent(CLP.Events.PlayerLoaded, function(_data)
    -- Sicherheitshalber: falls die UI noch offen ist, jetzt schliessen
    if CharSelectActive then hide() end
end)

-- ============================================================
--  NUI -> CLIENT  Callbacks (vom HTML)
-- ============================================================
RegisterNUICallback('char:select', function(data, cb)
    cb({ ok = true })
    local cid = data and data.citizenid
    if not cid then return end
    TriggerServerEvent(CLP.Events.CharSelect, { citizenid = cid })
end)

RegisterNUICallback('char:create', function(data, cb)
    cb({ ok = true })
    data = data or {}
    TriggerServerEvent(CLP.Events.CharCreate, {
        firstname = data.firstname,
        lastname  = data.lastname,
        gender    = data.gender or 'm',
        slot      = tonumber(data.slot) or 1,
        birthdate = data.birthdate,
    })
end)

RegisterNUICallback('char:delete', function(data, cb)
    cb({ ok = true })
    local cid = data and data.citizenid
    if not cid then return end
    TriggerServerEvent(CLP.Events.CharDelete, { citizenid = cid })
end)
