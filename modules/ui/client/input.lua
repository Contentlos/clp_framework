--[[
    clp_framework — Input-Dialog (Client, Phase 0 Stub)
]]

CLP.UI = CLP.UI or {}

--- Öffnet einen Input-Dialog. Phase 4 implementiert die UI; Phase 0 fällt auf
--- KeyboardInput-Native zurück (synchron, für CMD-Zeile reicht das).
--- @param opts table  { title, placeholder, maxLength }
--- @return string | nil
function CLP.UI.Input(opts)
    opts = opts or {}
    AddTextEntry('CLP_UI_INPUT_HELP', opts.title or 'Eingabe:')
    DisplayOnscreenKeyboard(1, 'CLP_UI_INPUT_HELP', '', opts.placeholder or '', '', '', '', tonumber(opts.maxLength) or 64)
    while UpdateOnscreenKeyboard() == 0 do Wait(0) end
    if UpdateOnscreenKeyboard() ~= 2 then
        return GetOnscreenKeyboardResult()
    end
    return nil
end
