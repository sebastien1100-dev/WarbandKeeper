local _, WK = ...
local M = WK:NewModule("ClassPlan")
local T = function(s) return WK.T(s) end

-- Plans de montée par classe (page Leveling, maquette A) : un plan = l'ordre des points de talent (comme les
-- plans par perso de Modules/TalentPlan.lua) + les sorts du maître à ne pas acheter. Tous les persos de la classe
-- le suivent (sauf ceux qui s'en détachent) : panneau de la fenêtre des talents, lueur du talent suivant, et
-- coches du panneau du maître de classe (Modules/ClassSpells.lua : Skip / Skipped passent par ici).
--   WK.DB.global.classPlans[CLASSE] = { list = { { name, steps = { { arbre, n°, nœud, nom } },
--     skip = { [sort] = true } } }, active = n°, nofollow = { [perso] = true } }
-- Arbres de talents : ceux relevés sur un perso de la classe (le connecté d'abord, sinon le plus récent).

local function store(class)
    local g = WK.DB.global
    g.classPlans = g.classPlans or {}
    local s = g.classPlans[class]
    if not s then s = { list = {} }; g.classPlans[class] = s end
    s.list = s.list or {}
    s.nofollow = s.nofollow or {}
    for _, p in ipairs(s.list) do p.steps = p.steps or {}; p.skip = p.skip or {} end
    return s
end
M.Store = store

function M.Plans(_, class) return store(class).list end
function M.Active(_, class)
    if not class then return nil end
    local s = store(class)
    return s.active and s.list[s.active], s.active
end
function M:SetActive(class, i)
    store(class).active = i
    self:Changed()
end
function M:New(class, name, steps)
    local s = store(class)
    local cp = {}
    for k, st in ipairs(steps or {}) do cp[k] = { st[1], st[2], st[3], st[4] } end
    table.insert(s.list, { name = name, steps = cp, skip = {} })
    if not s.active then s.active = #s.list end
    self:Changed()
    return #s.list
end
function M:Delete(class, i)
    local s = store(class)
    table.remove(s.list, i)
    if s.active == i then s.active = (#s.list > 0) and 1 or nil
    elseif s.active and s.active > i then s.active = s.active - 1 end
    self:Changed()
end
function M:Rename(class, i, name)
    local p = store(class).list[i]
    if p and name and name ~= "" then p.name = name; self:Changed() end
end

-- Perso de référence de la classe (arbres relevés) : le connecté s'il est de cette classe, sinon le plus récent
function M.RefChar(_, class)
    local me = WK:CharKey()
    local chars = WK.DB.global.characters
    local c = chars[me]
    if c and c.class == class and c.talents and c.talents[1] and c.talents[1].list then return me, c end
    local best, bk
    for key, ch in pairs(chars) do
        if ch.class == class and ch.talents and ch.talents[1] and ch.talents[1].list then
            if not best or (ch.sheetAt or 0) > (best.sheetAt or 0) then best, bk = ch, key end
        end
    end
    return bk, best
end
-- Arbres tirés des tables du jeu (WK.ClassTalentTrees de Modules/ClassSpellsDB.lua) : un plan se fait sans perso
-- de la classe. Même forme que c.talents ({ nom, icône, rangée, colonne, rang, max, sort, nœud = nil }), rangés
-- par rangée puis colonne ; noms et icônes relus en jeu (refaits tant qu'un nom manque). trees.static = vrai.
local staticTrees = {}
function M.StaticTrees(_, class)
    local raw = class and WK.ClassTalentTrees and WK.ClassTalentTrees[class]
    if not raw then return nil end
    local t = staticTrees[class]
    if t and t.complete then return t end
    local fr = WK.Lang() == "frFR"
    t = { static = true, complete = true }
    for _, tr in ipairs(raw) do
        local tree = { name = fr and tr[1] or tr[2], points = 0, list = {} }
        for row, col, max, sp, pre in tr[3]:gmatch("(%d+),(%d+),(%d+),(%d+),?([%d%.]*)") do
            sp = tonumber(sp)
            local name, icon = WK.SpellInfo(sp)
            if not name then t.complete = false end
            local d = { name or ("#" .. sp), icon, tonumber(row), tonumber(col), 0, tonumber(max), sp }
            local pr, pc = pre:match("^(%d+)%.(%d+)$")
            if pr then d.req = { tonumber(pr), tonumber(pc) } end
            tree.list[#tree.list + 1] = d
        end
        tree.cols = 4
        t[#t + 1] = tree
    end
    staticTrees[class] = t
    return t
end

-- Prérequis d'un talent (arbre ti, n° j) : n° du talent demandé (même arbre) et son rang max, ou nil.
-- Arbres relevés : 9e champ (nœud source du trait de la fenêtre des talents) ; arbres des tables : d.req
-- (rangée, colonne) ; sinon le talent de même nom des tables donne le nom du prérequis.
local function findIn(list, test) for j, d in ipairs(list or {}) do if test(d) then return j, d end end end
function M:Prereq(class, trees, ti, j)
    local tree = trees and trees[ti]
    local d = tree and tree.list and tree.list[j]
    if not d then return nil end
    if d[9] then
        local pj, pd = findIn(tree.list, function(x) return x[8] == d[9] end)
        if pj then return pj, pd[6] or 1, pd end
    end
    if d.req then
        local pj, pd = findIn(tree.list, function(x) return x[3] == d.req[1] and x[4] == d.req[2] end)
        if pj then return pj, pd[6] or 1, pd end
    end
    if not trees.static then
        local st = self:StaticTrees(class)
        for _, stree in ipairs(st or {}) do
            local _, sd = findIn(stree.list, function(x) return x[1] == d[1] end)
            if sd then
                if not sd.req then return nil end
                local _, sp = findIn(stree.list, function(x) return x[3] == sd.req[1] and x[4] == sd.req[2] end)
                local pj, pd
                if sp then pj, pd = findIn(tree.list, function(x) return x[1] == sp[1] end) end
                if pj then return pj, pd[6] or 1, pd end
                return nil
            end
        end
    end
    return nil
end

-- Copie d'un plan (nom « … (copie) »), et code de partage « WKC1:CLASSE:nom du talent*rangs,… » (par noms :
-- marche sur les arbres des tables comme sur les arbres relevés)
function M:Duplicate(class, i)
    local p = store(class).list[i]
    if not p then return nil end
    local n = self:New(class, p.name .. " " .. T("(copie)"), p.steps)
    local q = store(class).list[n]
    for k in pairs(p.skip or {}) do q.skip[k] = true end
    q.static = p.static
    return n
end
function M.Export(_, class, i)
    local p = store(class).list[i]
    if not p then return nil end
    local parts = {}
    for k, st in ipairs(p.steps) do parts[k] = st[1] .. "." .. st[2] end
    return "WKC1:" .. class .. ":" .. table.concat(parts, ",")
end
function M:Import(class, code)
    code = tostring(code or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%s%[%]\"']", "")
    local cls, body = code:match("^WKC1:(%u+):([%d%.,]*)$")
    if not cls then cls, body = code:match("^WKP1:([%u%?]+):([%d%.,]*)$") end
    if not cls then return nil, T("code non reconnu (attendu : WKC1:… ou WKP1:…)") end
    if cls ~= "?" and cls ~= class then return nil, T("ce code est pour une autre classe") end
    local i = self:New(class, T("Plan importé"))
    for ti, j in body:gmatch("(%d+)%.(%d+)") do
        if not self:AddStep(class, i, tonumber(ti), tonumber(j)) then
            self:Delete(class, i)
            return nil, T("le code ne correspond pas aux arbres de cette classe")
        end
    end
    self:SetActive(class, i)
    return i
end

-- Plan fait sur les arbres des tables, recalé sur les arbres relevés en jeu dès qu'un perso de la classe les a :
-- chaque point retrouvé par le nom du talent (arbre, n°, nœud) ; le plan garde « static » tant qu'il en manque.
function M.Remap(_, class, trees)
    local changed = false
    for _, p in ipairs(store(class).list) do
        if p.static then
            local where = {}
            for ti, tr in ipairs(trees) do
                for j, d in ipairs(tr.list or {}) do if d[1] then where[d[1]] = { ti, j, d[8] } end end
            end
            local all = true
            for _, st in ipairs(p.steps) do
                local w = st[4] and where[st[4]]
                if w then st[1], st[2], st[3] = w[1], w[2], w[3] else all = false end
            end
            if all then p.static = nil end
            changed = true
        end
    end
    return changed
end

function M:Trees(class)
    local _, c = self:RefChar(class)
    if c and c.talents then
        if self:Remap(class, c.talents) then WK:NotifyChanged() end
        return c.talents
    end
    return self:StaticTrees(class)
end

-- Persos de la classe (clé, perso) et ceux qui suivent le plan
function M.Chars(_, class)
    local out = {}
    for key, c in pairs(WK.DB.global.characters) do
        if c.class == class then out[#out + 1] = { key = key, c = c } end
    end
    table.sort(out, function(a, b) return (a.c.level or 0) > (b.c.level or 0) end)
    return out
end
function M.Follows(_, key)
    local c = WK.DB.global.characters[key]
    if not (c and c.class) then return false end
    return not store(c.class).nofollow[key]
end
function M:SetFollow(key, v)
    local c = WK.DB.global.characters[key]
    if not (c and c.class) then return end
    store(c.class).nofollow[key] = (not v) or nil
    self:Changed()
end
-- Plan que suit un perso (celui de sa classe), ou nil
function M:PlanFor(key)
    local c = WK.DB.global.characters[key or WK:CharKey()]
    if not (c and c.class) or not self:Follows(key or WK:CharKey()) then return nil end
    local p = self:Active(c.class)
    -- plan fait sans perso : recalé sur les arbres relevés avant de servir (n° de nœud pour placer les points)
    if p and p.static and c.talents then self:Remap(c.class, c.talents) end
    return p
end

-- Ajoute un point (mêmes règles que les plans par perso : rang maximum, 5 points par rangée au-dessus)
function M:AddStep(class, i, ti, j)
    local p = store(class).list[i]
    local trees = self:Trees(class)
    local d = trees and trees[ti] and trees[ti].list and trees[ti].list[j]
    if not (p and d) then return false end
    local TP = WK.modules.TalentPlan
    local ranks = TP:Ranks(p)
    local r = ranks[ti .. ":" .. j] or 0
    if r >= (d[6] or 1) then return false, T("Ce talent est déjà au maximum dans le plan.") end
    local inTree = 0
    for k, v in pairs(ranks) do if k:match("^(%d+):") == tostring(ti) then inTree = inTree + v end end
    local need = ((d[3] or 1) - 1) * 5
    if inTree < need then
        local fmt = T("Rangée pas encore accessible : il faut %d points dans cet arbre (%d pour l'instant).")
        return false, string.format(fmt, need, inTree)
    end
    if #p.steps >= 51 then return false, T("Le plan a déjà tous ses points (niveau 60).") end
    local pj, pmax, pd = self:Prereq(class, trees, ti, j)
    if pj and (ranks[ti .. ":" .. pj] or 0) < pmax then
        return false, string.format(T("Il faut d'abord %s au rang %d."), pd[1] or "?", pmax)
    end
    table.insert(p.steps, { ti, j, d[8], d[1] })
    if trees.static then p.static = true end
    self:Changed()
    return true
end
function M:RemoveLast(class, i)
    local p = store(class).list[i]
    if p and #p.steps > 0 then table.remove(p.steps); self:Changed() end
end

-- Sorts écartés (pas achetés chez le maître)
function M.Skipped(_, plan, name) return plan and plan.skip and plan.skip[name] or false end
function M:SetSkip(class, i, name, v)
    local p = store(class).list[i]
    if p then p.skip[name] = v and true or nil; self:Changed() end
end
-- Noms des talents pris dans le plan : leurs sorts (rangs appris chez le maître) font partie des achats
function M.TalentNames(_, plan)
    local out = {}
    for _, st in ipairs(plan and plan.steps or {}) do if st[4] then out[st[4]] = true end end
    return out
end

function M.Changed(_)
    WK:NotifyChanged()
    local UI = WK.UI
    if UI and UI.RefreshTalentPlan then pcall(UI.RefreshTalentPlan, UI) end
    if UI and UI.RefreshClassTrainer then pcall(UI.RefreshClassTrainer, UI) end
end
