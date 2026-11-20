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

-- Ce qu'un profil contient : clé de WK.DB.global, et sous-clés à laisser de côté (données ou état) ;
-- __only = seulement ces sous-clés (le reste de la table est fait de données du compte)
local KEYS = {
    settings = { trackedItems = true, lastSeenVersion = true, notesSeenVersion = true, statsHidden = true },
    dungeons = { __only = { cfg = true } },
    itemLock = { __only = { cfg = true } },
    mail = { __only = { enabled = true, closeAfter = true, sortAfter = true, autoTake = true, window = true } },
    bank = { __only = { enabled = true, sortAfter = true } },
    qol = { petFoods = true },
    glow = { saved = true, otherOff = true },
    rares = { kills = true, dead = true },
    quests = {},
    ah = { realms = true, lists = true, curList = true, alerts = true },
    modulesOff = {},
    mapLayers = {},
    gatherMap = {},
    stash = {},
    gatherHelp = { rankSeen = true, lastRank = true },
    profHelp = { deLog = true },
    bagHelp = { dismissed = true },
    questTrack = { tracked = true }, -- réglages du suivi (la quête suivie de chaque perso reste à lui)
    blessings = { chars = true }, -- barre et Salut (la répartition de chaque paladin reste à son perso)
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
    for key, skip in pairs(KEYS) do
        if skip.__only then
            local live, part = WK.DB.global[key] or {}, {}
            for k in pairs(skip.__only) do part[k] = copy(live[k]) end
            snap[key] = part
        else
            snap[key] = copy(WK.DB.global[key], skip)
        end
    end
    return snap
end

-- Copie -> réglages en place (les sous-clés de données restent celles du compte)
local function apply(snap, reset)
    local g = WK.DB.global
    for key, skip in pairs(KEYS) do
        local live = g[key] or {}
        if skip.__only then
            -- seulement les sous-clés de réglages : le reste (données) ne bouge pas ; une valeur absente du
            -- profil (capturé avant l'ajout de la clé) garde la valeur en place
            local part = snap and snap[key]
            if part then for k in pairs(skip.__only) do if part[k] ~= nil then live[k] = copy(part[k]) end end end
            if reset then for k in pairs(skip.__only) do live[k] = nil end end
            g[key] = live
        else
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
    -- un profil capturé avant l'ajout d'un réglage n'en a pas la valeur par défaut
    if WK.DB.FillDefaults then WK.DB:FillDefaults() end
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
    WK.UI:AskReload(WK.T("Profil changé : recharge l'interface pour l'appliquer."))
end

-- Copie les réglages d'un autre profil dans le profil en place (puis recharge).
function M:CopyFrom(name)
    local p = store()
    if name == p.loaded then return end
    if name == DEFAULT and not p.list[DEFAULT] then apply({}) else apply(p.list[name]) end
    WK.UI:AskReload(WK.T("Réglages copiés : recharge l'interface pour les appliquer."))
end

-- Remet le profil en place aux réglages d'origine (puis recharge).
function M:Reset()
    apply({}, true)
    WK.UI:AskReload(WK.T("Profil remis à zéro : recharge l'interface pour l'appliquer."))
end

---------------------------------------------------------------------------
-- Partage : un profil devient un code texte (« WKP1: » + base64), à coller chez un autre joueur ou sur un
-- autre compte. Format interne simple et typé, relu par un analyseur (jamais de loadstring : rien ne s'exécute).
--   table « T … E », texte « S<longueur>: », nombre « N<valeur>; », booléen « B1 » / « B0 »
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(data)
    local out, n = {}, #data
    for i = 1, n, 3 do
        local a, b, c = data:byte(i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2 = math.floor(v / 262144) % 64, math.floor(v / 4096) % 64
        local c3, c4 = math.floor(v / 64) % 64, v % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end
local B64R = {}
for i = 1, 64 do B64R[B64:byte(i)] = i - 1 end
local function b64dec(s)
    s = s:gsub("[^%w%+/=]", "")
    local out = {}
    for i = 1, #s, 4 do
        local a, b, c, d = s:byte(i, i + 3)
        local va, vb = B64R[a], B64R[b]
        if not (va and vb) then return nil end
        local vc, vd = c and B64R[c], d and B64R[d]
        local v = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
        out[#out + 1] = string.char(math.floor(v / 65536) % 256)
        if vc then out[#out + 1] = string.char(math.floor(v / 256) % 256) end
        if vd then out[#out + 1] = string.char(v % 256) end
    end
    return table.concat(out)
end
local function ser(v, out, depth)
    local t = type(v)
    if t == "table" then
        if depth > 20 then return end
        out[#out + 1] = "T"
        for k, x in pairs(v) do
            local tk, tx = type(k), type(x)
            local okNum = tx ~= "number" or (x == x and x ~= math.huge and x ~= -math.huge)
            if (tk == "string" or tk == "number") and okNum and (tx == "table" or tx == "string" or tx == "number" or tx == "boolean") then
                ser(k, out, depth + 1); ser(x, out, depth + 1)
            end
        end
        out[#out + 1] = "E"
    elseif t == "string" then out[#out + 1] = "S" .. #v .. ":" .. v
    elseif t == "number" then out[#out + 1] = "N" .. string.format("%.17g", v) .. ";"
    elseif t == "boolean" then out[#out + 1] = v and "B1" or "B0" end
end
-- analyseur : rend la valeur et la position suivante, ou nil si le texte est abîmé
local function des(s, i, depth)
    if depth > 22 or i > #s then return nil end
    local c = s:sub(i, i)
    if c == "T" then
        local t = {}
        i = i + 1
        while true do
            if i > #s then return nil end
            if s:sub(i, i) == "E" then return t, i + 1 end
            local k, v
            k, i = des(s, i, depth + 1); if k == nil or type(k) == "table" then return nil end
            v, i = des(s, i, depth + 1); if v == nil then return nil end
            t[k] = v
        end
    elseif c == "S" then
        local len, rest = s:match("^(%d+):()", i + 1)
        len = tonumber(len)
        if not len then return nil end
        return s:sub(rest, rest + len - 1), rest + len
    elseif c == "N" then
        local num, rest = s:match("^([%-%d%.eE+naif]+);()", i + 1)
        local v = tonumber(num)
        if not v or v ~= v then return nil end
        return v, rest
    elseif c == "B" then
        return s:sub(i + 1, i + 1) == "1", i + 2
    end
    return nil
end
local PREFIX = "WKP1:"

-- Encodage commun (style de l'Apparence…) : table -> « préfixe » + base64 ; et retour (nil + raison si abîmé)
function M:EncodeTable(t, prefix)
    local out = {}
    ser(t, out, 0)
    return prefix .. b64enc(table.concat(out))
end
function M:DecodeTable(code, prefix)
    code = type(code) == "string" and code:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if code:sub(1, #prefix) ~= prefix then return nil, string.format(T("Ce n'est pas un code %s…"), prefix) end
    if #code > 200000 then return nil, T("Code trop long.") end
    local raw = b64dec(code:sub(#prefix + 1))
    local t = raw and des(raw, 1, 0)
    if type(t) ~= "table" then return nil, T("Code abîmé : copie-le en entier.") end
    return t
end

-- Code d'un profil (celui en place : ses réglages du moment)
function M:Export(name)
    local p = store()
    name = name or p.loaded
    local data = (name == p.loaded) and capture() or p.list[name]
    if not data then return nil, T("Ce profil n'a pas encore de réglages enregistrés.") end
    local out = {}
    ser({ v = 1, name = name, data = data }, out, 0)
    return PREFIX .. b64enc(table.concat(out))
end

-- Nouveau profil depuis un code (seules les clés de réglages connues sont reprises). Rend true et le nom
-- donné au profil, ou false et la raison.
-- Code lu : nom d'origine et réglages reconnus (clés de KEYS), ou nil et la raison
local function decode(code)
    code = type(code) == "string" and code:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if code:sub(1, #PREFIX) ~= PREFIX then return nil, T("Ce n'est pas un code de profil Warband Keeper (WKP1:…).") end
    if #code > 2000000 then return nil, T("Code trop long.") end
    local raw = b64dec(code:sub(#PREFIX + 1))
    local t = raw and des(raw, 1, 0)
    if type(t) ~= "table" or type(t.data) ~= "table" then return nil, T("Code abîmé : copie-le en entier.") end
    local data, n = {}, 0
    for key in pairs(KEYS) do
        if type(t.data[key]) == "table" then data[key] = t.data[key]; n = n + 1 end
    end
    if n == 0 then return nil, T("Ce code ne contient aucun réglage.") end
    return { name = type(t.name) == "string" and t.name or nil, data = data, n = n }
end
-- Aperçu d'un code collé, sans rien créer : true, nom, nombre de groupes de réglages ; ou false, raison
function M:Peek(code)
    local d, err = decode(code)
    if not d then return false, err end
    return true, d.name, d.n
end

function M:Import(code, wanted)
    local d, err = decode(code)
    if not d then return false, err end
    local t, data = { name = d.name }, d.data
    -- nom libre (24 caractères au plus), sinon celui du code ; « (2) », « (3) »… s'il existe déjà
    local base = (type(wanted) == "string" and wanted:match("%S") and wanted) or (type(t.name) == "string" and t.name) or T("Importé")
    base = base:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 20)
    if base == DEFAULT then base = T("Importé") end
    local taken = {}
    for _, n in ipairs(self:Names()) do taken[n:lower()] = true end
    local name, n = base, 1
    while taken[name:lower()] do n = n + 1; name = base .. " (" .. n .. ")" end
    store().list[name] = data
    return true, name
end

-- Supprime un profil (ni « Défaut », ni celui en place). Ses persos reviennent sur « Défaut ».
-- Celui en place aussi : ce perso repasse sur « Défaut » (ses réglages appliqués, rechargement proposé).
function M:Delete(name)
    local p = store()
    if name == DEFAULT or not (p.list[name] or name == p.loaded) then return false end
    if name == p.loaded then
        if p.list[DEFAULT] then apply(p.list[DEFAULT]) else apply({}, true) end
        p.loaded = DEFAULT
        WK.UI:AskReload(T("Profil supprimé : ce perso repasse sur « Défaut ». Recharge l'interface pour l'appliquer."))
    end
    p.list[name] = nil
    for key, n in pairs(p.byChar) do if n == name then p.byChar[key] = nil end end
    return true
end
