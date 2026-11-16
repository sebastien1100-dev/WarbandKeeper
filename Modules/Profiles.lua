local ADDON_NAME, WK = ...
local M = WK:NewModule("Profiles")
local T = function(s) return WK.T(s) end

-- Profils de réglages : jeux nommés de réglages (apparence, QoL, halo, rares, récolte…), à choisir
-- par perso. Les données du compte (persos, sacs, journal, courrier, règles d'envoi, notes de
-- joueurs, rares tués…) ne font jamais partie d'un profil.
-- Fonctionnement : les réglages « vivants » restent à leur place habituelle (WK.DB.global.settings…).
-- Au chargement, si ce perso utilise un autre profil que celui en place, les réglages en place sont
-- rangés dans leur profil et ceux du profil voulu sont posés à la place. Un changement de profil
-- recharge donc l'interface.
-- WK.DB.global.profiles = { list = { [nom] = copie }, byChar = { [perso] = nom }, loaded = nom }

local DEFAULT = "Défaut"
M.DEFAULT = DEFAULT

-- Ce qu'un profil contient : clé de WK.DB.global, et sous-clés à laisser de côté (données ou état)
local KEYS = {
    settings = { trackedItems = true, lastSeenVersion = true },
    qol = { petFoods = true },
    glow = { saved = true, otherOff = true },
    rares = { kills = true },
    quests = {},
    ah = { realms = true },
    modulesOff = {},
    mapLayers = {},
    gatherMap = {},
}
local SKIP_DEEP = { savedSound = true, savedSoft = true, fishAdded = true, lfgAdded = true } -- état interne, à tout niveau

local function copy(src, skip)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
        if not (skip and skip[k]) and not SKIP_DEEP[k] then out[k] = copy(v) end
    end
    return out
end

local function store()
    local g = WK.DB.global
    g.profiles = g.profiles or {}
    local p = g.profiles
    p.list = p.list or {}
    p.byChar = p.byChar or {}
    p.loaded = p.loaded or DEFAULT
    return p
end

-- Réglages en place -> copie
local function capture()
    local snap = {}
    for key, skip in pairs(KEYS) do snap[key] = copy(WK.DB.global[key], skip) end
    return snap
end

-- Copie -> réglages en place (les sous-clés de données restent celles du compte)
local function apply(snap)
    local g = WK.DB.global
    for key, skip in pairs(KEYS) do
        local live = g[key] or {}
        local kept = {}
        for k in pairs(skip) do kept[k] = live[k] end
        local fresh = copy((snap and snap[key]) or {})
        for k, v in pairs(kept) do fresh[k] = v end
        -- état interne gardé (sons coupés pendant la pêche, réglages du jeu sauvegardés…)
        if key == "qol" and live.fishing and fresh.fishing then
            fresh.fishing.savedSound, fresh.fishing.savedSoft = live.fishing.savedSound, live.fishing.savedSoft
        end
        g[key] = fresh
    end
end

function M:Current() return store().loaded end
function M:ForChar(key) return store().byChar[key or WK:CharKey()] or DEFAULT end
function M:Names()
    local p = store()
    local names, seen = { DEFAULT }, { [DEFAULT] = true }
    for name in pairs(p.list) do if not seen[name] then seen[name] = true; table.insert(names, name) end end
    if not seen[p.loaded] then table.insert(names, p.loaded) end
    table.sort(names, function(a, b) if a == DEFAULT then return true elseif b == DEFAULT then return false end return a < b end)
    return names
end
-- Persos qui utilisent un profil
function M:Users(name)
    local out = {}
    for key, c in pairs(WK.DB.global.characters) do
        if self:ForChar(key) == name then table.insert(out, WK:CharName(c, key)) end
    end
    table.sort(out)
    return out
end

-- Avant tout le reste (ADDON_LOADED, appelé par Core/Init.lua juste après la base) : pose le profil de ce perso.
function M:Apply()
    local p = store()
    local want = self:ForChar()
    if want ~= p.loaded then
        p.list[p.loaded] = capture()
        if p.list[want] then apply(p.list[want]) end
        p.loaded = want
    end
end

-- Le profil en place est gardé à jour à la déconnexion.
WK:On("PLAYER_LOGOUT", function()
    local p = store()
    p.list[p.loaded] = capture()
end)

-- Nouveau profil, copie des réglages actuels. Renvoie false et un message si le nom ne va pas.
function M:Create(name)
    name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return false, T("Donne un nom au profil.") end
    if #name > 24 then return false, T("Nom trop long (24 caractères au plus).") end
    local p = store()
    for _, n in ipairs(self:Names()) do if n:lower() == name:lower() then return false, T("Ce profil existe déjà.") end end
    p.list[name] = capture()
    return true
end

-- Ce perso passe sur un profil : les réglages actuels sont rangés, puis l'interface recharge.
function M:Use(name)
    local p = store()
    p.byChar[WK:CharKey()] = (name ~= DEFAULT) and name or nil
    if name == p.loaded then return end
    p.list[p.loaded] = capture()
    apply(p.list[name])
    p.loaded = name
    if ReloadUI then ReloadUI() end
end

-- Copie les réglages d'un autre profil dans le profil en place (puis recharge).
function M:CopyFrom(name)
    local p = store()
    if name == p.loaded then return end
    if name == DEFAULT and not p.list[DEFAULT] then apply({}) else apply(p.list[name]) end
    if ReloadUI then ReloadUI() end
end

-- Remet le profil en place aux réglages d'origine (puis recharge).
function M:Reset()
    apply({})
    if ReloadUI then ReloadUI() end
end

-- Supprime un profil (ni « Défaut », ni celui en place). Ses persos reviennent sur « Défaut ».
function M:Delete(name)
    local p = store()
    if name == DEFAULT or name == p.loaded then return false end
    p.list[name] = nil
    for key, n in pairs(p.byChar) do if n == name then p.byChar[key] = nil end end
    return true
end
