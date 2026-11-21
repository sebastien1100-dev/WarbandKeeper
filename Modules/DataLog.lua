local ADDON_NAME, WK = ...
local M = WK:NewModule("DataLog")
local T = function(s) return WK.T(s) end

-- Journal des données : ce qui arrive dans la base de quêtes.
--   mises à jour de la base (WK.DataLog, généré par tools/gen_quests.py / tools/datalog.py : quêtes ajoutées,
--   corrigées, retirées à chaque mise à jour de QuestieDB et de ses corrections WoW Forever) ;
--   quêtes apprises en jeu (WK.DB.global.questLearn, Modules/Quests.lua).
-- Pastilles « NOUVELLE » / « APPRISE » / « CORRIGÉE » pendant `days` jours dans les listes de quêtes,
-- message à la connexion après une nouvelle base (UI/DataLog.lua).
-- Réglages WK.DB.global.dataLog : badges, days, toast, seen (date de la dernière base annoncée).

local DEFAULTS = { badges = true, days = 7, toast = true }
function M:Config()
    local g = WK.DB.global
    g.dataLog = g.dataLog or {}
    for k, v in pairs(DEFAULTS) do if g.dataLog[k] == nil then g.dataLog[k] = v end end
    return g.dataLog
end

-- fil complet, le plus récent en tête : { kind = "db", t, e } ou { kind = "learn", t, id, e }
function M:Entries()
    local out = {}
    for _, e in ipairs(WK.DataLog or {}) do table.insert(out, { kind = "db", t = e.t or 0, e = e }) end
    local Q = WK.modules.Quests
    local store = Q and Q.LearnStore and Q.LearnStore() or {}
    for id, e in pairs(store) do
        if e.n then table.insert(out, { kind = "learn", t = e.at or 0, id = id, e = e }) end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end
function M:Latest()
    local best
    for _, e in ipairs(WK.DataLog or {}) do if not best or (e.t or 0) > (best.t or 0) then best = e end end
    return best
end

-- état « récent » de chaque quête (gardé 60 s) : new / learned / changed
local cache, cacheAt
local function recent()
    local now = time()
    if cache and cacheAt and now - cacheAt < 60 then return cache end
    cache, cacheAt = {}, now
    local cut = now - (M:Config().days or 7) * 86400
    for _, e in ipairs(WK.DataLog or {}) do
        if (e.t or 0) >= cut then
            for _, c in ipairs(e.chg or {}) do if not cache[c[1]] then cache[c[1]] = "changed" end end
            for _, id in ipairs(e.add or {}) do cache[id] = "new" end
        end
    end
    local Q = WK.modules.Quests
    for id, e in pairs(Q and Q.LearnStore and Q.LearnStore() or {}) do
        if e.n and (e.at or 0) >= cut then cache[id] = "learned" end
    end
    return cache
end
function M:Invalidate() cache = nil end
function M:State(qid) return qid and recent()[qid] or nil end

local LABEL = { new = "NOUVELLE", learned = "APPRISE", changed = "CORRIGÉE" }
local COLOR = { new = "rule", learned = "plan", changed = "warning" }
M.LABEL, M.COLOR = LABEL, COLOR
-- pastille à mettre après un nom de quête (texte coloré), ou ""
-- compact : seulement le pictogramme coloré (titres de la tournée, fenêtre du donjon : pas de place pour le mot)
local GLYPH = { new = "spark", learned = "book", changed = "refresh" }
function M:Badge(qid, compact)
    if not self:Config().badges then return "" end
    local st = self:State(qid)
    if not st then return "" end
    local UI = WK.UI
    local col = UI.colors[COLOR[st]] or UI.colors.muted
    if compact then
        return string.format(" |T%s%s:13:13:0:0:64:64:0:64:0:64:%d:%d:%d|t", UI.MEDIA, GLYPH[st],
            math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255))
    end
    -- point plein de la couleur puis le mot (les listes sont du texte : pas de cadre possible)
    local dot = string.format("|T%scircle:9:9:0:0:128:128:0:128:0:128:%d:%d:%d|t", UI.MEDIA,
        math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255))
    return "  " .. dot .. " " .. UI:Hex(col) .. T(LABEL[st]) .. "|r"
end

-- codes d'une correction en clair (« niveau 30 » 31 · donneur déplacé »)
function M:Describe(codes)
    local parts = {}
    for c in tostring(codes or ""):gmatch("%S+") do
        local k, a, b = c:match("^(%a)(%d+)>(%d+)$")
        if k == "l" then table.insert(parts, string.format(T("niveau %s » %s"), a, b))
        elseif k == "r" then table.insert(parts, string.format(T("niveau requis %s » %s"), a, b))
        elseif c == "g" then table.insert(parts, T("donneur déplacé"))
        elseif c == "z" then table.insert(parts, T("autre zone"))
        elseif c == "p" then table.insert(parts, T("prérequis"))
        elseif c == "n" then table.insert(parts, T("nom"))
        elseif c == "f" then table.insert(parts, T("faction")) end
    end
    return table.concat(parts, " · ")
end

-- ce qu'une mise à jour change pour le perso connecté : quêtes nouvelles dans sa zone, à son niveau, à prendre
function M:ForMe(e)
    local Q = WK.modules.Quests
    local c = WK.DB:Me() or {}
    local zone = Q and Q:PlayerZone()
    local lvl = UnitLevel and UnitLevel("player") or c.level or 1
    local here, mine = {}, 0
    for _, id in ipairs(e and e.add or {}) do
        local q = Q and Q:Get(id)
        if q and Q:ForChar(q, c) and Q:State(q, c) == "avail" and math.abs((q.lvl or 0) - lvl) <= 5 then
            mine = mine + 1
            if zone and q.map == zone then table.insert(here, q) end
        end
    end
    return here, mine, zone
end
