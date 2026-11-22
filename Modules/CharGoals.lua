local _, WK = ...
local M = WK:NewModule("CharGoals")
local T = function(s) return WK.T(s) end

-- Objectifs par perso (maquette D ; à ne pas confondre avec Modules/Goals.lua,
-- objectifs des courbes des Statistiques) : niveau, or, palier de métier, liste BiS complète.
--   WK.DB.global.charGoals[perso] = { { kind = "level"|"gold"|"prof"|"bis", target, prof?, start, at, done? } }
-- (données de compte, hors profils). Progression et estimation sur le rythme réel :
--   niveau : XP/h de la séance (perso connecté) ; or : gain net des 7 derniers jours (journal de l'or) ;
--   métier : points restants ; BiS : objets de la liste affichée déjà portés ou sur le compte du perso.
-- Lu par le tableau « Objectifs » de la page Persos et par la mini-fenêtre « À faire » (UI/TodoBar.lua).
M.KINDS = { "level", "gold", "prof", "bis" }
M.LABELS = { level = "Niveau", gold = "Or", prof = "Métier", bis = "Liste BiS" }
local DAY = 86400

local function store()
    local g = WK.DB.global
    g.charGoals = g.charGoals or {}
    return g.charGoals
end
function M.For(_, key)
    local s = store()
    s[key] = s[key] or {}
    return s[key]
end

local function levelNow(c)
    local x = c.xp
    if x and x.level then return x.level + (x.max and x.max > 0 and (x.cur or 0) / x.max or 0) end
    return c.level or 1
end
local function profRank(c, prof)
    local p = c.professions and c.professions[prof]
    return type(p) == "table" and (p.rank or 0) or 0, type(p) == "table" and p.max or nil
end
local function bisCount(key, c)
    local Bi = WK.modules.BiS
    if not Bi then return 0, 0 end
    local ok, list = pcall(Bi.List, Bi, key)
    if not ok or type(list) ~= "table" then return 0, 0 end
    local worn = {}
    for _, link in pairs(c.gear or {}) do
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if id then worn[id] = true end
    end
    local have, total = 0, 0
    local Inv = WK.modules.Inventory
    for _, id in pairs(list) do
        if type(id) == "number" then
            total = total + 1
            if worn[id] or (Inv and (Inv:CharCount(c, id)) > 0) then have = have + 1 end
        end
    end
    return have, total
end

-- Valeur actuelle d'un objectif (même unité que target)
local function current(key, c, g)
    if g.kind == "level" then return levelNow(c)
    elseif g.kind == "gold" then return math.floor((c.money or 0) / 10000)
    elseif g.kind == "prof" then return (profRank(c, g.prof))
    elseif g.kind == "bis" then return (bisCount(key, c)) end
    return 0
end

-- Gain net d'or par jour sur les 7 derniers jours (journal de l'or, ClientDash), en pièces de cuivre
function M.GoldPerDay(_, key)
    local log = WK.DB.global.moneyLog or {}
    local cut, sum, first = time() - 7 * DAY, 0, nil
    for _, e in ipairs(log) do
        if e.c == key and e.t >= cut then
            sum = sum + (e.d or 0)
            first = first and math.min(first, e.t) or e.t
        end
    end
    if not first then return nil end
    local days = math.max(1, (time() - first) / DAY)
    return sum / days
end

local function hours(h)
    if h < 1 then return string.format(T("env. %d min"), math.max(1, math.floor(h * 60 + 0.5))) end
    if h < 48 then return string.format(T("env. %d h"), math.floor(h + 0.5)) end
    return string.format(T("env. %d j"), math.floor(h / 24 + 0.5))
end

-- { title, value, pct (0-1), eta (texte), done }
function M:Progress(key, g)
    local c = WK.DB.global.characters[key]
    if not c then return nil end
    local now = current(key, c, g)
    local start = g.start or 0
    local target = g.target or 1
    local out = { now = now }
    if g.kind == "bis" then
        local have, total = bisCount(key, c)
        out.pct = total > 0 and have / total or 0
        out.title = T("Liste BiS complète")
        out.value = string.format("%d / %d", have, total)
        out.eta = total == 0 and T("liste vide : choisis tes objets dans la fiche, onglet BiS")
            or (have >= total and T("objectif atteint") or string.format(T("%d objet(s) à trouver"), total - have))
        out.done = total > 0 and have >= total
        return out
    end
    local span = target - start
    out.pct = span > 0 and math.max(0, math.min(1, (now - start) / span)) or (now >= target and 1 or 0)
    out.done = now >= target
    if g.kind == "level" then
        out.title = string.format(T("Niveau %d"), target)
        out.value = string.format("%d", math.floor(now))
        if out.done then out.eta = T("objectif atteint")
        elseif key == WK:CharKey() and WK.modules.XP then
            local X = WK.modules.XP
            local perHour = X:Rate()
            local x = X:Me()
            if perHour and perHour > 0 then
                local need = (x.max - x.cur) + math.max(0, target - x.level - 1) * x.max * 1.1
                out.eta = string.format(T("%s au rythme actuel"), hours(need / perHour))
            else
                out.eta = T("gagne un peu d'XP pour estimer le temps")
            end
        else
            out.eta = T("connecte ce perso pour estimer le temps")
        end
    elseif g.kind == "gold" then
        out.title = string.format(T("%d po"), target)
        out.value = string.format(T("%d po"), now)
        if out.done then out.eta = T("objectif atteint")
        else
            local perDay = self:GoldPerDay(key)
            if perDay and perDay > 0 then
                local left = (target * 10000 - (c.money or 0)) / perDay * 24
                out.eta = string.format(T("%s (+%d po par jour sur 7 jours)"), hours(left),
                    math.floor(perDay / 10000 + 0.5))
            else
                out.eta = T("pas encore de gain d'or noté sur 7 jours")
            end
        end
    elseif g.kind == "prof" then
        local _, max = profRank(c, g.prof)
        out.title = string.format("%s %d", T(g.prof or "?"), target)
        out.value = tostring(now)
        if out.done then out.eta = T("objectif atteint")
        elseif max and max < target and now >= max then
            out.eta = string.format(T("au plafond %d : va voir le maître"), max)
        else
            out.eta = string.format(T("%d point(s) à monter"), target - now)
        end
    end
    return out
end

-- Tous les objectifs du compte : { key, i, g, p }, du plus proche au plus lointain (atteints à la fin)
function M:All()
    local out = {}
    for key, list in pairs(store()) do
        if WK.DB.global.characters[key] then
            for i, g in ipairs(list) do
                local p = self:Progress(key, g)
                if p then out[#out + 1] = { key = key, i = i, g = g, p = p } end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.p.done ~= b.p.done then return not a.p.done end
        if a.p.pct ~= b.p.pct then return a.p.pct > b.p.pct end
        return a.key < b.key
    end)
    return out
end

-- Objectif pas encore atteint le plus avancé d'un perso : { title, pct, eta }
function M:Nearest(key)
    local best
    for _, g in ipairs(self:For(key)) do
        local p = self:Progress(key, g)
        if p and not p.done and (not best or p.pct > best.pct) then best = p end
    end
    return best
end

-- Ajoute un objectif ; rend nil et un message si la cible n'a pas de sens
function M:Add(key, kind, target, prof)
    local c = WK.DB.global.characters[key]
    if not c then return nil, T("perso inconnu") end
    target = tonumber(target)
    if kind ~= "bis" and (not target or target <= 0) then return nil, T("indique une cible (un nombre)") end
    if kind == "prof" and not prof then return nil, T("choisis un métier") end
    if kind == "level" and WK.modules.XP and target > WK.modules.XP:MaxLevel() then
        return nil, string.format(T("niveau maximum : %d"), WK.modules.XP:MaxLevel())
    end
    local g = { kind = kind, target = target and math.floor(target) or nil, prof = prof, at = time() }
    g.start = kind == "level" and math.floor(levelNow(c)) or kind ~= "bis" and current(key, c, g) or 0
    table.insert(self:For(key), g)
    WK:NotifyChanged()
    return g
end
function M:Remove(key, i)
    table.remove(self:For(key), i)
    WK:NotifyChanged()
end
