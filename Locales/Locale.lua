local ADDON_NAME, WK = ...

-- Langues : frFR (référence) et enUS.
--  * WK.L.CLE   : messages du chat, par clé (Locales/<langue>.lua, table keys)
--  * WK.T(txt)  : textes de l'interface ; la clé est le texte français,
--                 traduit via Locales/enUS.lua (table text). Sans traduction, le français reste.
WK.Locales = { frFR = { keys = {}, text = {} }, enUS = { keys = {}, text = {} } }

-- Langue active : réglage du joueur, ou langue du client en mode « auto ».
function WK.Lang()
    local s = WK.DB and WK.DB.global and WK.DB.global.settings and WK.DB.global.settings.ui
    local l = s and s.lang or "auto"
    if l == "auto" then
        l = (GetLocale and GetLocale() == "frFR") and "frFR" or "enUS"
    end
    return WK.Locales[l] and l or "frFR"
end

function WK.T(s)
    if type(s) ~= "string" or s == "" then return s end
    local lang = WK.Lang()
    if lang == "frFR" then return s end
    return WK.Locales[lang].text[s] or s
end

WK.L = setmetatable({}, {
    __index = function(_, k)
        local lang = WK.Lang()
        return WK.Locales[lang].keys[k] or WK.Locales.frFR.keys[k] or k
    end,
})
