local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Plan de quêtes : quêtes à prendre autour de toi regroupées par coin (camps qui se recoupent), puis tournée
-- la plus courte (donneurs, camps, rendus) suivie étape par étape. Données : WK.QuestsDB (donneurs, niveau,
-- prérequis via Quests:State), Modules/QuestObjDB.lua (camps, rendu), journal du jeu (QuestTrack).
-- Ordre : au plus proche (en respectant prendre > faire > rendre), puis amélioré par échanges de segments
-- (2-opt) tant que l'ordre reste valable. Distances en mètres du jeu (Guide.ToWorld) à vol d'oiseau.
-- Réglages et état : WK.DB.global.questPlan (picked[perso][quête] = true / false, tour[perso], nearAlert,
-- maxAbove) ; tour et choix sont des données (hors profils).
local M = {}
WK.modules.QuestPlan = M

local JOIN = 0.10          -- quêtes dont les camps sont à moins de 10 % de la carte : même coin
local SPEED = 7            -- m/s à pied
local SECS = { m = 22, i = 26, o = 12, e = 15, x = 20 } -- temps moyen par unité d'objectif

function M:Config()
    local g = WK.DB.global
    g.questPlan = g.questPlan or {}
    local c = g.questPlan
    c.picked = c.picked or {}
    c.tour = c.tour or {}
    if c.nearAlert == nil then c.nearAlert = true end
    c.maxAbove = c.maxAbove or 2
    if c.noGroup == nil then c.noGroup = false end -- quêtes de groupe décochées d'office
    if c.nearSteps == nil then c.nearSteps = "ask" end -- étape plus loin toute proche : ask / auto / off
    return c
end
local function Q() return WK.modules.QuestTrack end
local function G() return WK.modules.Guide end
local function on() return WK:FeatureOn("quests") end
local function inLog(qid) return Q():InLog(qid) end

local function world(map, x, y)
    local c, wx, wy = G().ToWorld(map, x, y)
    return c, wx, wy
end
local function dist(a, b)
    if a.cont and b.cont and a.cont == b.cont and a.wx and b.wx then
        return math.sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2)
    end
    if a.map == b.map then return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) * 2500 end
    return 100000
end
local function point(map, x, y)
    local p = { map = map, x = x, y = y }
    p.cont, p.wx, p.wy = world(map, x, y)
    return p
end

---------------------------------------------------------------------------
-- Candidats : quêtes du journal et quêtes à prendre de la zone
---------------------------------------------------------------------------
-- camp principal de chaque objectif sur la carte de la zone (le plus fourni)
local function zoneCamps(qid, zone)
    local d = Q():Data(qid)
    local out = {}
    if not d then return out end
    for i, o in ipairs(d.objs) do
        local best
        for _, c in ipairs(o.camps) do
            if c.map == zone and (not best or (c.n or 0) > (best.n or 0)) then best = c end
        end
        if best then table.insert(out, { i = i, kind = o.kind, camp = best }) end
    end
    return out
end

-- { { id, title, lvl, xp, inLog, complete, giver = point?, camps = {…}, center = point?, turnIn = point?, coin } }
function M:Candidates()
    -- zone de la tournée : celle choisie dans « Carte des zones » (PlanZone), sinon celle où tu es
    local zone = M:Config().planZone or WK.modules.Quests:PlayerZone()
    local out = {}
    if not zone then return out, nil end
    local Qs = WK.modules.Quests
    local me = WK.DB:Me() or {}
    local lvl = UnitLevel and UnitLevel("player") or me.level or 1
    local cfg = self:Config()
    local seen = {}
    -- quêtes de la zone pas proposées, et pourquoi (affiché sous « Quêtes de ma zone »)
    local stats = { low = 0, high = 0, locked = 0, noArea = 0 }
    self.lastStats = stats
    local function add(e)
        local camps = zoneCamps(e.id, zone)
        if #camps > 0 then
            local sx, sy = 0, 0
            for _, c in ipairs(camps) do sx, sy = sx + c.camp.x, sy + c.camp.y end
            e.center = point(zone, sx / #camps, sy / #camps)
        end
        e.camps = camps
        local d = Q():Data(e.id)
        local ti = (e.inLog and Q():TurnIn(e.id)) or (d and d.turnIn)
        if ti then e.turnIn = point(ti.map, ti.x, ti.y) end
        -- quête du journal absente de la base (quêtes propres à WoW Forever) : le point donné par le jeu
        -- (C_QuestLog.GetNextWaypoint) sert de zone d'objectifs tant qu'elle n'est pas finie
        if e.inLog and not e.complete and #camps == 0 and not (d and #(d.objs or {}) > 0) and ti and ti.map == zone then
            e.camps = { { i = 1, kind = "m", camp = { map = ti.map, x = ti.x, y = ti.y } } }
            e.center = point(ti.map, ti.x, ti.y)
            e.gameOnly = true
        end
        -- quête finie : seulement si on la rend dans cette zone (sinon, depuis une capitale, la tournée
        -- se réduisait à un rendu à l'autre bout du continent)
        -- quête à porter ou à livrer (pas de zone d'objectifs connue) : prise puis rendue dans la zone
        local carry = not e.inLog and e.giver and e.turnIn and e.turnIn.map == zone
        if e.center or carry or (e.complete and e.turnIn and e.turnIn.map == zone) then table.insert(out, e); seen[e.id] = true
        else stats.noArea = stats.noArea + 1 end
    end
    for _, l in ipairs(Q():LogQuests()) do
        local q = Qs:Get(l.id)
        add({ id = l.id, title = l.title, lvl = l.level or (q and q.lvl) or lvl, xp = q and q.xp or 0, inLog = true, complete = l.complete })
    end
    for _, q in ipairs(Qs:OnMap(zone)) do
        if not seen[q.id] and q.x and Qs:ForChar(q, me) then
            local st = Qs:State(q, me)
            if st == "locked" then stats.locked = stats.locked + 1
            elseif st == "avail" or st == "high" then
                local every = cfg.allZone == zone .. ":" .. WK:CharKey()
                if ((q.lvl or 0) > lvl + 4 and not every) or st == "high" then stats.high = stats.high + 1
                -- trop basse : écartée, sauf « Compléter la zone » lancé dans cette zone (toutes les quêtes)
                elseif (q.lvl or 0) < lvl - 8 and cfg.allZone ~= zone .. ":" .. WK:CharKey() then stats.low = stats.low + 1
                else
                    local gm = q.smap or zone
                    add({ id = q.id, title = Qs:Name(q), lvl = q.lvl, xp = q.xp or 0, giver = point(gm, q.x / 100, q.y / 100),
                        giverName = q.sid })
                end
            end
        end
    end
    -- choix : coché d'office si le niveau va (au plus maxAbove au-dessus du perso)
    local picked = cfg.picked[WK:CharKey()] or {}
    for _, e in ipairs(out) do
        local p = picked[e.id]
        e.group = WK.QuestIsGroup(e.id) or nil
        -- quête de groupe : décochée d'office quand le réglage « Éviter les quêtes de groupe » est mis
        if p == nil then p = e.inLog or ((e.lvl or 0) <= lvl + cfg.maxAbove and not (e.group and cfg.noGroup)) end
        e.picked = p and true or false
        e.hard = (e.lvl or 0) > lvl + cfg.maxAbove
    end
    return out, zone
end

-- Coins : quêtes regroupées par camps proches. { { quests = {…}, center = point, xp, label } }, triés par XP
-- (gardés 2 s : la page les relit à chaque rafraîchissement ; une coche les recalcule)
local memo = {}
function M:Invalidate() memo = {} end
function M:Coins()
    local now = GetTime and GetTime() or time()
    if memo.coins and now - memo.at < 2 then return memo.coins, memo.zone, memo.list end
    local coins, zone, list = self:CoinsNow()
    memo.coins, memo.zone, memo.list, memo.at, memo.build = coins, zone, list, now, nil
    return coins, zone, list
end
function M:CoinsNow()
    local list, zone = self:Candidates()
    local coins = {}
    for _, e in ipairs(list) do
        local c = e.center or e.turnIn
        local best
        if c then
            for _, k in ipairs(coins) do
                if k.map == c.map and math.sqrt((k.x - c.x) ^ 2 + (k.y - c.y) ^ 2) <= JOIN then best = k break end
            end
        end
        if not best then
            best = { quests = {}, map = c and c.map or zone, x = c and c.x or 0.5, y = c and c.y or 0.5, xp = 0, sx = 0, sy = 0 }
            table.insert(coins, best)
        end
        table.insert(best.quests, e)
        e.coin = best
        best.xp = best.xp + (e.xp or 0)
        best.sx, best.sy = best.sx + (c and c.x or 0.5), best.sy + (c and c.y or 0.5)
        best.x, best.y = best.sx / #best.quests, best.sy / #best.quests
    end
    local me = G():PlayerPos()
    for _, k in ipairs(coins) do
        k.center = point(k.map, k.x, k.y)
        k.d = me and dist(me, k.center) or nil
        k.label = M:Direction(me, k.center)
    end
    table.sort(coins, function(a, b) return a.xp > b.xp end)
    return coins, zone, list
end

local DIRS = { "nord", "nord-est", "est", "sud-est", "sud", "sud-ouest", "ouest", "nord-ouest" }
function M:Direction(me, p)
    if not (me and p and me.map == p.map) then return T("dans la zone") end
    local dx, dy = p.x - me.x, -(p.y - me.y)
    if math.abs(dx) < 0.02 and math.abs(dy) < 0.02 then return T("ici") end
    local a = math.deg(math.atan2(dx, dy)) % 360
    return T(DIRS[math.floor((a + 22.5) / 45) % 8 + 1])
end

function M:SetPicked(qid, v)
    local c = self:Config()
    local k = WK:CharKey()
    c.picked[k] = c.picked[k] or {}
    c.picked[k][qid] = v and true or false
    self:Invalidate()
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Tournée
---------------------------------------------------------------------------
-- étapes : { kind = "pick"|"do"|"turn", qids = {…}, map, x, y, title, secs }
local function objTime(qid, logged)
    -- temps réel déjà noté pour cette quête (Modules/LevelGuide.lua) : le plus juste
    local LG = WK.modules.LevelGuide
    local rec = LG and LG:QuestTime(qid)
    if rec and not logged then return rec end
    local s = 0
    if logged then
        for _, o in ipairs(Q():Objectives(qid)) do
            if not o.done then
                local k = (o.type == "item" and "i") or (o.type == "object" and "o") or "m"
                s = s + math.max(1, (o.need or 0) - (o.have or 0)) * SECS[k]
            end
        end
    else
        local d = Q():Data(qid)
        for _, o in ipairs(d and d.objs or {}) do s = s + 8 * (SECS[o.kind] or 20) end
    end
    return s
end

local excluded -- plus bas
function M:Build()
    local coins = self:Coins()
    if memo.build and memo.coins == coins then return self:CopyTour(memo.build) end
    local t = self:BuildNow(coins)
    -- quêtes trop chères en temps pour leur XP (ou sur un autre continent) : retirées, la tournée est refaite
    local me = G():PlayerPos()
    local ex = excluded(t, me)
    if #ex > 0 then
        local skip = {}
        for _, e in ipairs(ex) do skip[e.id] = true end
        t = self:BuildNow(coins, skip)
        t.excluded = ex
    end
    memo.build = t
    return self:CopyTour(t)
end
function M:CopyTour(t)
    local steps = {}
    for i, s in ipairs(t.steps) do steps[i] = s end
    local ex
    if t.excluded then ex = {}; for i, e in ipairs(t.excluded) do ex[i] = { id = e.id, title = e.title, reason = e.reason } end end
    return { steps = steps, idx = 1, start = time(), secs = t.secs, meters = t.meters, excluded = ex,
        gained0 = WK.modules.XP and WK.modules.XP.session and WK.modules.XP.session.gained or 0, turned = 0 }
end
-- Suites prévues (B) : la quête qui suit une quête cochée (q.nxt), si elle se fait dans la zone et que son
-- niveau va ; elle est prise au rendu de la précédente, ses objectifs entrent dans la même boucle. Deux
-- niveaux de suite au plus. { id, title, xp, giver, camps, center, turnIn, predicted = profondeur, parent }
local function predicted(list, zone)
    local Qs = WK.modules.Quests
    local me = WK.DB:Me() or {}
    local lvl = UnitLevel and UnitLevel("player") or me.level or 1
    local maxAbove = M:Config().maxAbove or 2
    local done = me.quests and me.quests.done or {}
    local have = {}
    for _, e in ipairs(list) do have[e.id] = true end
    local out = {}
    local function follow(e, depth)
        if depth > 2 then return end
        local q = Qs:Get(e.id)
        local nid = q and q.nxt
        local nq = nid and not have[nid] and not done[nid] and not inLog(nid) and Qs:Get(nid)
        if not (nq and Qs:ForChar(nq, me)) or (nq.lvl or 0) > lvl + maxAbove then return end
        if M:Config().noGroup and nq.grp == 1 then return end
        local n = { id = nid, title = Qs:Name(nq), lvl = nq.lvl, xp = nq.xp or 0, predicted = depth, parent = e, picked = true }
        n.camps = zoneCamps(nid, zone)
        if #n.camps > 0 then
            local sx, sy = 0, 0
            for _, c in ipairs(n.camps) do sx, sy = sx + c.camp.x, sy + c.camp.y end
            n.center = point(zone, sx / #n.camps, sy / #n.camps)
        end
        -- prise : chez son donneur (souvent celui qui reprend la précédente)
        if nq.x then n.giver = point(nq.smap or zone, nq.x / 100, nq.y / 100)
        elseif e.turnIn then n.giver = e.turnIn end
        local d = Q():Data(nid)
        if d and d.turnIn then n.turnIn = point(d.turnIn.map, d.turnIn.x, d.turnIn.y) end
        local here = (n.center ~= nil) or (n.turnIn and n.turnIn.map == zone)
        if not (here and n.giver) then return end
        have[nid] = true
        table.insert(out, n)
        follow(n, depth + 1)
    end
    for _, e in ipairs(list) do if e.picked and e.turnIn then follow(e, 1) end end
    return out
end
M.Predicted = predicted

-- Achats (A) : le marchand de ta faction le plus proche de toi qui vend cet objet, sur ton continent
local function nearestVendor(item, from, alt)
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    local letter = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
    local best, bd
    for _, v in ipairs(Q():Vendors(item)) do
        if not letter or v.fac:find(letter, 1, true) then
            local p = point(v.map, v.x, v.y)
            local d = from and dist(from, p) or 0
            -- position du perso illisible ou sur une autre carte sans coordonnées du monde : depuis le rendu
            if d >= 100000 and alt then d = dist(alt, p) end
            if d < 100000 and (not bd or d < bd) then best, bd = { p = p, v = v }, d end
        end
    end
    return best
end
M.NearestVendor = nearestVendor

local DO_JOIN = 220 -- camps à moins de 220 m : une seule étape « faire » (objectifs de plusieurs quêtes ensemble)
function M:BuildNow(coins, skip)
    skip = skip or {}
    local nodes = {}
    -- les nœuds ne se regroupent qu'entre quêtes de même profondeur (quête cochée, suite, suite de suite) :
    -- sinon une suite prise au rendu formerait une boucle d'ordre (rendre avant de prendre avant de rendre)
    local function node(kind, p, qid, depth, title)
        for _, n in ipairs(nodes) do
            if n.kind == kind and n.depth == depth and dist(n, p) < (kind == "do" and DO_JOIN or 25) then
                local dup = false
                for _, q in ipairs(n.qids) do if q == qid then dup = true end end
                if not dup then table.insert(n.qids, qid) end
                return n
            end
        end
        local n = { kind = kind, map = p.map, x = p.x, y = p.y, cont = p.cont, wx = p.wx, wy = p.wy, qids = { qid }, title = title,
            depth = depth, after = {}, preds = {} }
        table.insert(nodes, n)
        return n
    end
    local here = G():PlayerPos()
    local list, zone = {}, nil
    for _, k in ipairs(coins) do
        for _, e in ipairs(k.quests) do if e.picked and not skip[e.id] then table.insert(list, e); zone = zone or k.map end end
    end
    zone = WK.modules.Quests:PlayerZone() or zone
    for _, n in ipairs(zone and predicted(list, zone) or {}) do table.insert(list, n) end
    local turnOf = {}
    for _, e in ipairs(list) do
        local depth = e.predicted or 0
        local pick = (not e.inLog) and e.giver and node("pick", e.giver, e.id, depth, e.title) or nil
        if pick and e.parent and turnOf[e.parent] then pick.after[turnOf[e.parent]] = true end
        if pick and e.predicted then pick.preds[e.id] = true end
        -- A : une étape « faire » par camp (plus au milieu de camps éloignés), regroupée avec les camps voisins
        local dos = {}
        if not e.complete and e.camps and #e.camps > 0 then
            local per = objTime(e.id, e.inLog) / #e.camps
            for _, c in ipairs(e.camps) do
                local p = point(c.camp.map or zone, c.camp.x, c.camp.y)
                local dn = node("do", p, e.id, depth)
                dn.secs = (dn.secs or 0) + per
                -- camps de cette quête dans l'étape : seuls leurs objectifs y sont montrés et comptés
                dn.camps = dn.camps or {}
                dn.camps[e.id] = dn.camps[e.id] or {}
                table.insert(dn.camps[e.id], { map = p.map, x = c.camp.x, y = c.camp.y })
                if pick then dn.after[pick] = true end
                if e.predicted then dn.preds[e.id] = true end
                table.insert(dos, dn)
            end
        end
        -- objets à acheter : une étape chez le marchand le plus proche (A), sinon une note sur le rendu (B)
        local buys, noVendor = {}, {}
        for _, it in ipairs(Q():BuyMissing(e.id)) do
            local bv = nearestVendor(it.id, here, e.turnIn)
            if bv then
                local bn = node("buy", bv.p, e.id, depth)
                bn.vendor = bv.v
                bn.items = bn.items or {}
                local need = Q():BuyNeed(e.id, it.id)
                local found = false
                for _, x in ipairs(bn.items) do if x.id == it.id then x.need = x.need + need; found = true end end
                if not found then table.insert(bn.items, { id = it.id, need = need }) end
                bn.secs = 20
                if e.predicted then bn.preds[e.id] = true end
                table.insert(buys, bn)
            else
                table.insert(noVendor, it)
            end
        end
        if e.turnIn then
            local tn = node("turn", e.turnIn, e.id, depth, e.title)
            for _, dn in ipairs(dos) do tn.after[dn] = true end
            for _, bn in ipairs(buys) do tn.after[bn] = true end
            for _, it in ipairs(noVendor) do tn.buyMissing = tn.buyMissing or {}; table.insert(tn.buyMissing, it) end
            if pick then tn.after[pick] = true end
            if e.predicted then tn.preds[e.id] = true end
            turnOf[e] = tn
        end
    end
    -- visite du maître de classe (réglage levelGuide.trainerTour, oui par défaut) : quand des sorts sont à
    -- apprendre maintenant, le maître le plus proche devient une étape, placée là où elle coûte le moins
    local LGc = WK.modules.LevelGuide and WK.modules.LevelGuide:Config()
    local CS = WK.modules.ClassSpells
    if LGc and LGc.trainerTour ~= false and CS and #nodes > 0 then
        local cr = CS:ForChar()
        if cr and #cr.now > 0 then
            local g = G()
            local tg = g:Nearest(g:KindsFor("trainer"), select(2, UnitClass("player")))
            if tg then
                local p = point(tg.map, tg.x, tg.y)
                if not nodes[1] or dist(nodes[1], p) < 100000 then
                    table.insert(nodes, { kind = "trainer", map = p.map, x = p.x, y = p.y, cont = p.cont, wx = p.wx, wy = p.wy,
                        qids = {}, secs = 60, title = g:PlaceName(tg), spells = #cr.now, after = {}, preds = {} })
                end
            end
        end
    end
    -- au plus proche, en respectant l'ordre prendre > faire > rendre
    local me = G():PlayerPos() or (nodes[1] and point(nodes[1].map, nodes[1].x, nodes[1].y))
    local order, used = {}, {}
    local function ready(n)
        for a in pairs(n.after or {}) do if not used[a] then return false end end
        return true
    end
    local cur = me
    for _ = 1, #nodes do
        local best, bd
        for _, n in ipairs(nodes) do
            if not used[n] and ready(n) then
                local d = cur and dist(cur, n) or 0
                if not bd or d < bd then best, bd = n, d end
            end
        end
        if not best then break end
        used[best] = true
        table.insert(order, best)
        cur = best
    end
    -- amélioration : 2-opt (inverser un segment) et déplacement d'une étape ailleurs (or-opt), tant que la
    -- tournée raccourcit et que l'ordre reste valable ; les allers-retours au camp disparaissent ainsi : les
    -- rendus d'un même PNJ ne forment qu'une étape, placée après tout ce qu'elle attend
    local function valid(seq)
        local pos = {}
        for i, n in ipairs(seq) do pos[n] = i end
        for i, n in ipairs(seq) do
            for a in pairs(n.after or {}) do if pos[a] and pos[a] > i then return false end end
        end
        return true
    end
    local function len(seq)
        local s, prev = 0, me
        for _, n in ipairs(seq) do if prev then s = s + dist(prev, n) end; prev = n end
        return s
    end
    local improved, guard = true, 0
    local N = #order
    local budget = N <= 30 and 30 or 8
    while improved and guard < budget do
        improved, guard = false, guard + 1
        local base = len(order)
        for i = 1, N - 1 do
            for j = i + 1, N do
                local seq = {}
                for k = 1, i - 1 do seq[#seq + 1] = order[k] end
                for k = j, i, -1 do seq[#seq + 1] = order[k] end
                for k = j + 1, N do seq[#seq + 1] = order[k] end
                if valid(seq) then
                    local l = len(seq)
                    if l < base - 1 then order, base, improved = seq, l, true end
                end
            end
        end
        for i = 1, N do
            for j = 1, N do
                if j ~= i then
                    local seq = {}
                    for k = 1, N do if k ~= i then seq[#seq + 1] = order[k] end end
                    table.insert(seq, j, order[i])
                    if valid(seq) then
                        local l = len(seq)
                        if l < base - 1 then order, base, improved = seq, l, true end
                    end
                end
            end
        end
    end
    -- étapes enregistrables (sans références entre nœuds) ; retours : passages à moins de 60 m d'un endroit
    -- déjà visité plus tôt (hors étape juste avant)
    local steps, total, travel, prev = {}, 0, 0, me
    local returns = 0
    for i, n in ipairs(order) do
        local d = prev and dist(prev, n) or 0
        if d >= 100000 then d = 0 end
        travel = travel + d
        for k = 1, i - 2 do if dist(order[k], n) < 60 and dist(order[i - 1], n) >= 60 then returns = returns + 1 break end end
        local secs = d / SPEED + (n.secs or (n.kind == "do" and 0 or 15))
        total = total + secs
        local pr = {}
        for q in pairs(n.preds or {}) do pr[#pr + 1] = q end
        table.sort(pr)
        table.insert(steps, { kind = n.kind, qids = n.qids, map = n.map, x = n.x, y = n.y, secs = math.floor(secs), label = n.kind == "do" and M:Direction(me, n) or nil,
            title = n.kind == "trainer" and n.title or nil, spells = n.spells, level = n.kind == "trainer" and (UnitLevel and UnitLevel("player")) or nil,
            preds = #pr > 0 and pr or nil, items = n.items, vendor = n.vendor and Q():VendorName(n.vendor) or nil,
            vendorRole = n.vendor and select(2, Q():VendorName(n.vendor)) or nil,
            buyMissing = n.buyMissing, camps = n.kind == "do" and n.camps or nil })
        prev = n
    end
    steps = M.AddTravel(steps, me)
    total = 0
    for _, s in ipairs(steps) do total = total + (s.secs or 0) end
    return { steps = steps, idx = 1, start = time(), secs = math.floor(total), meters = math.floor(travel), returns = returns,
        gained0 = WK.modules.XP and WK.modules.XP.session and WK.modules.XP.session.gained or 0, turned = 0, list = list }
end

---------------------------------------------------------------------------
-- Foyer et vols : sur un long trajet entre deux étapes (plus de 1,5 km), une étape « Foyer » quand la pierre
-- est liée près de l'arrivée, ou « Vol » entre deux maîtres de vol connus, si elle fait gagner au moins 1 min
-- et un quart du temps à pied. Une seule pierre de foyer par tournée (recharge d'une heure).
---------------------------------------------------------------------------
local FLY_SPEED = 30   -- m/s en vol (estimation, sans durée apprise)
local function toPoint(c, wx, wy)
    local B = WK.modules.BoatLines
    if not (B and B.ToMap) then return nil end
    local ok, map, x, y = pcall(B.ToMap, B, c, wx, wy)
    if not (ok and map and type(x) == "number" and type(y) == "number") then return nil end
    local p = { map = map, x = x / 100, y = y / 100, cont = c, wx = wx, wy = wy }
    return p
end
local function hearthReady()
    local cd = C_Container and C_Container.GetItemCooldown or GetItemCooldown
    if not cd then return true end
    local ok, start, dur = pcall(cd, 6948)
    if not ok or not start or start == 0 then return true end
    return (start + (dur or 0)) - (GetTime and GetTime() or 0) < 60
end
function M.AddTravel(steps, me)
    if #steps == 0 then return steps end
    local c = WK.DB:Me() or {}
    local F = WK.modules.Flight
    local data = F and F.BoardData and F:BoardData()
    local hearthUsed = false
    local out, prev = {}, me
    for _, s in ipairs(steps) do
        local p = point(s.map, s.x, s.y)
        local d = prev and dist(prev, p) or 0
        if prev and d > 1500 and d < 100000 then
            local walk = d / SPEED
            local best
            -- foyer
            local h = c.hearth
            if not hearthUsed and h and h.cont == p.cont and h.wx and hearthReady() then
                local hp = { cont = h.cont, wx = h.wx, wy = h.wy }
                local after = math.sqrt((h.wx - p.wx) ^ 2 + (h.wy - p.wy) ^ 2)
                local secs = 12 + after / SPEED
                if after < 600 and walk - secs > 60 and secs < walk * 0.75 then
                    local hpt = toPoint(hp.cont, hp.wx, hp.wy)
                    if hpt then best = { kind = "hearth", p = hpt, secs = secs, gain = walk - secs, title = h.name } end
                end
            end
            -- vol entre deux relais connus
            if data and prev.cont == p.cont then
                local function nearestKnown(q, maxd)
                    local bn, bd
                    for _, n in ipairs(data.list) do
                        if n.known and n.fm and n.c == q.cont then
                            local dd = math.sqrt((n.x - q.wx) ^ 2 + (n.y - q.wy) ^ 2)
                            if dd < maxd and (not bd or dd < bd) then bn, bd = n, dd end
                        end
                    end
                    return bn, bd
                end
                local a, da = nearestKnown(prev, 700)
                local b, db = nearestKnown(p, 900)
                if a and b and a ~= b then
                    for _, dd in ipairs(F:Destinations(data, a)) do
                        if dd.node == b then
                            local fly = dd.secs or (dd.len / FLY_SPEED)
                            local secs = da / SPEED + 10 + fly + db / SPEED
                            if walk - secs > 60 and secs < walk * 0.75 and (not best or walk - secs > best.gain) then
                                local fa = b.fm
                                best = { kind = "flight", p = point(a.fm.map, a.fm.x, a.fm.y), secs = secs, gain = walk - secs,
                                    title = b.name, dest = point(fa.map, fa.x, fa.y), from = a.name }
                            end
                            break
                        end
                    end
                end
            end
            if best then
                if best.kind == "hearth" then hearthUsed = true end
                table.insert(out, { kind = best.kind, qids = {}, map = best.p.map, x = best.p.x, y = best.p.y,
                    secs = math.floor(best.secs), gain = math.floor(best.gain), title = best.title,
                    dest = best.dest and { map = best.dest.map, x = best.dest.x, y = best.dest.y } or nil, next = { map = s.map, x = s.x, y = s.y } })
                -- l'étape suivante part de l'arrivée : son temps de marche devient celui depuis l'arrivée
                s.secs = math.max(10, (s.secs or 0) - math.floor(walk))
            end
        end
        table.insert(out, s)
        prev = p
    end
    return out
end

---------------------------------------------------------------------------
-- Quêtes écartées : une quête cochée qui coûte beaucoup de temps (détour + objectifs) pour peu d'XP, comparée
-- à la moyenne de la tournée, ou dont une étape est sur un autre continent, est retirée de la tournée et dite
-- (bandeau « quêtes écartées », « Les remettre » = keep[perso][quête]). Jamais une quête du journal.
---------------------------------------------------------------------------
excluded = function(t, me)
    local keep = (M:Config().keep or {})[WK:CharKey()] or {}
    local steps = t.steps
    local function len(skipQ)
        local s, prev = 0, me
        for _, st in ipairs(steps) do
            local only = #st.qids == 1 and st.qids[1] == skipQ
            if not only then
                local p = point(st.map, st.x, st.y)
                if prev then local d = dist(prev, p); s = s + (d < 100000 and d or 0) end
                prev = p
            end
        end
        return s
    end
    local base = len(nil)
    local xpAll = 0
    for _, e in ipairs(t.list or {}) do xpAll = xpAll + (e.xp or 0) end
    local rate = (t.secs or 0) > 0 and xpAll / t.secs or 0
    -- continent de la tournée : celui de la plupart de ses étapes (pas celui du perso, qui peut préparer
    -- la tournée d'une autre zone)
    local count, main, best = {}, nil, 0
    for _, st in ipairs(steps) do
        local p = point(st.map, st.x, st.y)
        if p.cont then count[p.cont] = (count[p.cont] or 0) + 1; if count[p.cont] > best then main, best = p.cont, count[p.cont] end end
    end
    local out = {}
    for _, e in ipairs(t.list or {}) do
        if not e.inLog and not e.predicted and not keep[e.id] then
            local far = false
            for _, st in ipairs(steps) do
                for _, q in ipairs(st.qids) do
                    if q == e.id and main then
                        local p = point(st.map, st.x, st.y)
                        if p.cont and p.cont ~= main then far = true end
                    end
                end
            end
            local cost = (base - len(e.id)) / SPEED + objTime(e.id, false)
            if far then
                table.insert(out, { id = e.id, title = e.title, reason = T("autre continent") })
            elseif rate > 0 and cost > 360 and (e.xp or 0) / cost < rate * 0.35 then
                table.insert(out, { id = e.id, title = e.title, reason = string.format(T("+%d min pour %d XP"), math.floor(cost / 60 + 0.5), e.xp or 0) })
            end
        end
    end
    return out
end
function M:Keep(ids)
    local c = self:Config()
    local k = WK:CharKey()
    c.keep = c.keep or {}
    c.keep[k] = c.keep[k] or {}
    for _, id in ipairs(ids or {}) do c.keep[k][id] = true end
    self:Invalidate()
    if self:Tour() then self:Reorder() end
    WK:NotifyChanged()
end

-- D · Sur ton chemin : quête de la zone pas dans la tournée (nouvelle depuis le calcul, ou un peu haute) dont le
-- donneur ou la zone d'objectifs est à moins de 90 m du trajet vers l'étape en cours. Une coche enlevée à la main
-- n'est jamais reproposée ; « Ignorer » l'écarte jusqu'à la fin de la session.
local ignored = {}
function M:IgnoreOnTheWay(qid) if qid then ignored[qid] = true end; self.way = nil; self:Changed() end
function M:OnTheWay()
    local t = self:Tour()
    local s = t and not t.paused and t.steps[t.idx]
    if not s or not s.map then return nil end
    local me = G():PlayerPos()
    if not me then return nil end
    local now = GetTime and GetTime() or time()
    if self.way and self.way.at and now - self.way.at < 3 and self.way.idx == t.idx then return self.way.e and self.way end
    local inTour = {}
    for _, st in ipairs(t.steps) do for _, q in ipairs(st.qids or {}) do inTour[q] = true end end
    local picked = self:Config().picked[WK:CharKey()] or {}
    local goal = point(s.map, s.x, s.y)
    local base = dist(me, goal)
    local _, _, list = self:Coins()
    local best
    if base < 100000 then
        for _, e in ipairs(list or {}) do
            if not inTour[e.id] and not ignored[e.id] and picked[e.id] ~= false and not e.complete then
                for _, p in ipairs({ e.giver or false, e.center or false }) do
                    if p and p.wx then
                        local det = dist(me, p) + dist(p, goal) - base
                        -- à moins de 90 m du trajet : détour aller-retour d'env. 180 m au plus
                        if det <= 180 and (not best or det < best.det) then best = { e = e, det = det } end
                    end
                end
            end
        end
    end
    self.way = { at = now, idx = t.idx, e = best and best.e, det = best and best.det }
    if not best then return nil end
    self.way.mins = math.max(1, math.floor((best.det / SPEED + objTime(best.e.id, best.e.inLog)) / 60 + 0.5))
    return self.way
end
-- Étape prévue plus loin dans la tournée et toute proche (donneur ou rendu à moins de 45 m, camp à moins de
-- 70 m), faisable maintenant (prendre : quête disponible ; faire : dans le journal ; rendre : prête) :
-- { j = n° de l'étape, step, d = distance } ou nil. Réglage nearSteps : ask (proposée sur la carte de tournée),
-- auto (remontée toute seule), off. Gardée 1 s ; une étape écartée (clic droit) n'est plus proposée.
local nearIgnored = setmetatable({}, { __mode = "k" })
function M:NearStep()
    local mode = self:Config().nearSteps or "ask"
    if mode == "off" then return nil end
    local t = self:Tour()
    if not t or t.paused or not t.steps[t.idx] then return nil end
    local now = _G.GetTime and _G.GetTime() or _G.time()
    if self.near and self.near.at and now - self.near.at < 1 and self.near.idx == t.idx then return self.near.hit end
    local me = G():PlayerPos()
    local hit
    if me then
        local Qs = WK.modules.Quests
        local c = WK.DB:Me() or {}
        for j = t.idx + 2, #t.steps do
            local s = t.steps[j]
            if s.map and not nearIgnored[s] and (s.kind == "pick" or s.kind == "do" or s.kind == "turn") then
                local d = dist(me, point(s.map, s.x, s.y))
                if d < (s.kind == "do" and 70 or 45) then
                    local ok = true
                    for _, q in ipairs(s.qids or {}) do
                        if s.kind == "pick" then
                            local qq = Qs and Qs:Get(q)
                            if inLog(q) or (qq and Qs:State(qq, c) ~= "avail") then ok = false end
                        elseif s.kind == "do" then
                            if not inLog(q) or Q():IsComplete(q) then ok = false end
                        elseif not (inLog(q) and Q():IsComplete(q)) then
                            ok = false
                        end
                    end
                    if ok and (not hit or d < hit.d) then hit = { j = j, step = s, d = d } end
                end
            end
        end
    end
    self.near = { at = now, idx = t.idx, hit = hit }
    return hit
end
-- l'étape devient l'étape en cours (celle d'avant reprend juste après)
function M:DoNearNow(step)
    local t = self:Tour()
    if not (t and step) then return end
    for j = t.idx + 1, #t.steps do
        if t.steps[j] == step then
            table.remove(t.steps, j)
            table.insert(t.steps, t.idx, step)
            self.near, self.lastKey = nil, nil
            self:Retarget()
            if self.Changed then self:Changed() end
            return true
        end
    end
end
function M:SkipNear(step)
    if step then nearIgnored[step] = true end
    self.near = nil
    if self.Changed then self:Changed() end
end
-- mode auto : appelé avec la vérification de la tournée
function M:CheckNear()
    if (self:Config().nearSteps or "ask") ~= "auto" then return end
    local hit = self:NearStep()
    if hit then
        local title = self:StepTitle(hit.step)
        if self:DoNearNow(hit.step) then WK:Print(string.format(T("Tout près, faite maintenant : %s"), title)) end
    end
end

function M:AddOnTheWay(qid)
    if not qid then return end
    self.way = nil
    self:SetPicked(qid, true)
    self:Reorder()
    local Qs = WK.modules.Quests
    local q = Qs and Qs:Get(qid)
    WK:Print(string.format(T("Ajoutée à la tournée : %s"), (q and Qs:Name(q)) or ("#" .. qid)))
end

function M:Tour() return self:Config().tour[WK:CharKey()] end
function M:Active() local t = self:Tour(); return t and not t.paused and t.steps[t.idx] ~= nil end

function M:Start()
    self:Invalidate()
    local t = self:Build()
    if #t.steps == 0 then WK:Print(T("Rien à faire : coche des quêtes dans « Quêtes de ma zone ».")) return nil end
    t.zone = self:Config().planZone or WK.modules.Quests:PlayerZone()
    self:Config().tour[WK:CharKey()] = t
    self.lastKey = nil
    self:Advance()
    self:Changed()
    return t
end

-- Compléter la zone : coche toutes les quêtes proposées dans la zone (même celles au-dessus de ton niveau)
-- et lance la tournée depuis l'endroit où tu es (une tournée en cours est remplacée)
function M:CompleteZone()
    -- toutes les quêtes de la zone, même celles bien en dessous de ton niveau (gardé jusqu'à la fin de la tournée)
    local zone = WK.modules.Quests:PlayerZone()
    self:Config().planZone = nil
    self:Config().allZone = zone and (zone .. ":" .. WK:CharKey()) or nil
    self:Invalidate()
    local list = self:Candidates()
    if #list == 0 then WK:Print(T("Aucune quête à faire dans cette zone.")) return nil end
    local c = self:Config()
    local k = WK:CharKey()
    c.picked[k] = c.picked[k] or {}
    for _, e in ipairs(list) do c.picked[k][e.id] = true end
    c.tour[k] = nil
    local t = self:Start()
    if t then WK:Print(string.format(T("Zone à compléter : %d quêtes, %d étapes."), #list, #t.steps)) end
    return t
end

-- Tournée d'une zone choisie dans « Carte des zones » : ces quêtes cochées, les autres de la zone décochées ;
-- la tournée vise cette zone même si tu es ailleurs (gardée jusqu'à la fin de la tournée)
function M:PlanZone(zone, ids)
    local c = self:Config()
    local k = WK:CharKey()
    if self:Tour() then self:Stop() end
    c.planZone = (zone ~= WK.modules.Quests:PlayerZone()) and zone or nil
    c.allZone = zone .. ":" .. k
    self:Invalidate()
    c.picked[k] = c.picked[k] or {}
    local want = {}
    for _, id in ipairs(ids) do want[id] = true end
    for _, e in ipairs(self:Candidates()) do c.picked[k][e.id] = want[e.id] or false end
    for id in pairs(want) do c.picked[k][id] = true end
    self:Invalidate()
    local t = self:Start()
    if t then WK:Print(string.format(T("Tournée prête : %d quêtes, %d étapes (Ma progression)."), #ids, #t.steps)) end
    return t
end

-- Vider la liste : toutes les quêtes de la zone décochées (la tournée en cours s'arrête)
function M:ClearPicks()
    local c = self:Config()
    local k = WK:CharKey()
    c.picked[k] = c.picked[k] or {}
    for _, e in ipairs(self:Candidates()) do c.picked[k][e.id] = false end
    c.allZone = nil
    c.planZone = nil
    if self:Tour() then self:Stop() end
    self:Invalidate()
    WK:NotifyChanged()
    WK:Print(T("Liste vidée : coche des quêtes (Choisir les quêtes) pour une nouvelle tournée."))
end

function M:Stop()
    self:Config().tour[WK:CharKey()] = nil
    self:Config().allZone = nil
    self:Config().planZone = nil
    local g = G()
    if g.target and g.target.kind == "qtour" then g:Stop() end
    self.lastKey = nil
    self:Changed()
    if Q().Retarget then Q():Retarget(true) end
end

function M:Pause(v)
    local t = self:Tour()
    if not t then return end
    t.paused = v and true or nil
    if v then
        local g = G()
        if g.target and g.target.kind == "qtour" then g:Stop() end
    else
        self.lastKey = nil
        self:Retarget()
    end
    self:Changed()
end

function M:Skip()
    local t = self:Tour()
    if not t then return end
    t.idx = t.idx + 1
    self.lastKey = nil
    self:Advance()
    self:Changed()
end

-- Tournée de ramassage (quêtes d'un donjon et leurs prérequis, donneurs dans plusieurs zones) : une étape
-- « prendre » par donneur, dans l'ordre du plus proche au suivant (même continent d'abord) ; gardée telle
-- quelle quand on change de zone (t.custom), « Réordonner » refait seulement l'ordre.
local function orderSteps(steps)
    local p = G() and G():PlayerPos()
    local left, out = {}, {}
    for _, s in ipairs(steps) do
        local c, wx, wy = world(s.map, s.x, s.y)
        s.cont, s.wx, s.wy = c, wx, wy
        table.insert(left, s)
    end
    local cur = p and { cont = p.cont, wx = p.wx, wy = p.wy } or nil
    while #left > 0 do
        local bi, bd = 1, nil
        for i, s in ipairs(left) do
            local d
            if cur and s.cont and s.cont == cur.cont and s.wx and cur.wx then
                d = math.sqrt((s.wx - cur.wx) ^ 2 + (s.wy - cur.wy) ^ 2)
            else
                d = 1e9 + i -- autre continent (ou position inconnue) : à la fin, dans l'ordre
            end
            if not bd or d < bd then bi, bd = i, d end
        end
        local s = table.remove(left, bi)
        table.insert(out, s)
        if s.cont then cur = { cont = s.cont, wx = s.wx, wy = s.wy } end
    end
    return out
end
function M:StartPickTour(quests, label)
    local groups, steps = {}, {}
    for _, q in ipairs(quests or {}) do
        local map = q.smap or q.map
        if q.x and map then
            local key = (q.sid and ("n" .. q.sid)) or string.format("%d:%d:%d", map, math.floor(q.x), math.floor(q.y))
            local s = groups[key]
            if not s then
                s = { kind = "pick", qids = {}, map = map, x = q.x / 100, y = q.y / 100, secs = 45 }
                groups[key] = s
                table.insert(steps, s)
            end
            table.insert(s.qids, q.id)
            self:SetPicked(q.id, true)
        end
    end
    if #steps == 0 then WK:Print(T("Aucun donneur connu pour ces quêtes.")) return nil end
    local XP = WK.modules.XP
    local t = { steps = orderSteps(steps), idx = 1, start = time(), gained0 = XP and XP.session and XP.session.gained or 0,
        turned = 0, zone = WK.modules.Quests:PlayerZone(), custom = true, label = label }
    self:Config().tour[WK:CharKey()] = t
    self.lastKey = nil
    self:Advance()
    self:Changed()
    WK:Print(string.format(T("Tournée de ramassage%s : %d quête(s), %d donneur(s)."), label and (" · " .. label) or "", #quests, #steps))
    return t
end

-- Recalcule l'ordre des étapes qui restent (depuis l'endroit où tu es)
function M:Reorder()
    local t = self:Tour()
    if not t then return self:Start() end
    if t.custom then
        local rest = {}
        for i = t.idx, #t.steps do table.insert(rest, t.steps[i]) end
        local done = {}
        for i = 1, t.idx - 1 do table.insert(done, t.steps[i]) end
        for _, s in ipairs(orderSteps(rest)) do table.insert(done, s) end
        t.steps = done
        self.lastKey = nil
        self:Advance()
        self:Changed()
        return
    end
    local keep = { start = t.start, gained0 = t.gained0, turned = t.turned }
    local old = {}
    for i = t.idx, #t.steps do old[#old + 1] = t.steps[i] end
    self:Invalidate()
    local n = self:Build()
    n.start, n.gained0, n.turned = keep.start, keep.gained0, keep.turned
    n.list = nil
    n.zone = self:Config().planZone or WK.modules.Quests:PlayerZone()
    -- étapes qui restaient et que la nouvelle tournée n'a pas (autre zone : donneur, coin ou rendu ailleurs) :
    -- gardées à la fin, dans leur ordre, au lieu d'être perdues sans le dire
    self.keptSteps = self:KeepMissing(n, old)
    self:Config().tour[WK:CharKey()] = n
    self.lastKey = nil
    self:Advance()
    self:Changed()
end

-- Ajoute à la tournée n les étapes « prendre / faire / rendre » de old qu'elle n'a pas, encore utiles ;
-- rend leur nombre
function M.KeepMissing(_, n, old)
    local have = {}
    for _, s in ipairs(n.steps or {}) do
        for _, q in ipairs(s.qids or {}) do have[s.kind .. q] = true end
    end
    local Qt = Q()
    local kept = 0
    for _, s in ipairs(old or {}) do
        if (s.kind == "pick" or s.kind == "do" or s.kind == "turn") and s.qids and #s.qids > 0 then
            local missing = false
            for _, q in ipairs(s.qids) do if not have[s.kind .. q] then missing = true end end
            local useful = false
            for _, q in ipairs(s.qids) do
                if s.kind == "pick" then
                    if not inLog(q) and not M.Turned(q) then useful = true end
                elseif s.kind == "do" then
                    if inLog(q) and not (Qt.IsComplete and Qt:IsComplete(q)) then useful = true end
                elseif inLog(q) then
                    useful = true
                end
            end
            if missing and useful then
                table.insert(n.steps, s)
                for _, q in ipairs(s.qids) do have[s.kind .. q] = true end
                kept = kept + 1
            end
        end
    end
    return kept
end

-- quête déjà rendue (journal du jeu, ou quêtes faites relevées pour le perso)
local function turned(q)
    local d = (WK.DB:Me() or {}).quests
    if d and d.done and d.done[q] then return true end
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q) and true or false
end
M.Turned = turned
-- étape dont toutes les quêtes sont déjà rendues (faite hors de l'ordre de la tournée)
function M:StepSpent(s)
    if not s.qids or #s.qids == 0 then return false end
    for _, q in ipairs(s.qids) do if inLog(q) or not turned(q) then return false end end
    return true
end

function M:StepDone(s)
    if s.kind == "trainer" then
        -- fini quand il ne reste rien à apprendre, ou après une visite chez le maître depuis le début de l'étape
        local CS = WK.modules.ClassSpells
        local cr = CS and CS:ForChar()
        if not cr or #cr.now == 0 then return true end
        local LG = WK.modules.LevelGuide
        local seen = LG and (LG:Config().trainer or {})[WK:CharKey()] or 0
        return seen >= (s.level or 999)
    elseif s.kind == "buy" then
        -- fini quand tout est dans les sacs (ou que les quêtes sont déjà rendues)
        local open = false
        for _, q in ipairs(s.qids) do
            if inLog(q) or not turned(q) then open = true end
        end
        if not open then return true end
        for _, it in ipairs(s.items or {}) do if Q():ItemCount(it.id) < (it.need or 1) then return false end end
        return true
    elseif s.kind == "hearth" or s.kind == "flight" then
        -- arrivé (près du foyer ou du relais d'arrivée), ou déjà près de l'étape suivante (fait autrement)
        local me = G():PlayerPos()
        if not me then return false end
        local goal = s.kind == "flight" and s.dest or s
        if goal and dist(me, point(goal.map, goal.x, goal.y)) < 400 then return true end
        if s.next and dist(me, point(s.next.map, s.next.x, s.next.y)) < 400 then return true end
        return false
    elseif s.kind == "pick" then
        -- prise, ou déjà rendue (sinon la tournée restait bloquée sur une quête finie ailleurs)
        for _, q in ipairs(s.qids) do if not inLog(q) and not turned(q) then return false end end
        return true
    elseif s.kind == "do" then
        for _, q in ipairs(s.qids) do
            if inLog(q) and not Q():IsComplete(q) then
                -- objectifs pas encore donnés par le jeu (juste après la prise) : pas fini (avant, la liste
                -- vide passait pour « tout est fait » et la tournée sautait au rendu) ; quête répartie sur
                -- plusieurs étapes : seuls les objectifs des camps de cette étape comptent
                local objs = M:StepQuestObjectives(s, q)
                if #objs == 0 then return false end
                for _, o in ipairs(objs) do if not o.done then return false end end
            end
        end
        return true
    else
        for _, q in ipairs(s.qids) do if inLog(q) then return false end end
        return true
    end
end

-- Titre lisible d'une étape
-- Avancement d'une quête : « new » (pas dans le journal), « started » (rien de fait), « partial »
-- (objectifs entamés), « ready » (prête à rendre), avec la part faite (0 à 1)
function M:QuestProgress(qid)
    if not inLog(qid) then return "new", 0 end
    if Q():IsComplete(qid) then return "ready", 1 end
    local have, need = 0, 0
    for _, o in ipairs(Q():Objectives(qid)) do
        local n = math.max(1, o.need or 0)
        need = need + n
        have = have + (o.done and n or math.min(n, o.have or 0))
    end
    local frac = need > 0 and have / need or 0
    return frac > 0 and "partial" or "started", frac
end
-- couleur de chaque avancement (à prendre : or, comme le « ! » du jeu ; entamée : orange ; prête : vert)
M.PROGRESS_COLOR = { new = "gold", started = "text", partial = "warning", ready = "positive" }
function M:ProgressColor(qid)
    local st = self:QuestProgress(qid)
    return WK.UI.colors[self.PROGRESS_COLOR[st] or "text"] or WK.UI.colors.text, st
end

-- Titre d'une étape ; colored = nom de chaque quête à la couleur de son avancement
function M:StepTitle(s, colored)
    if s.kind == "hearth" then return string.format(T("Foyer » %s"), s.title or T("ton auberge")) end
    if s.kind == "flight" then return string.format(T("Vol » %s"), s.title or "?") end
    if s.kind == "trainer" then
        return string.format(T("Maître de classe : %d sort(s) à apprendre"), s.spells or 0)
    end
    if s.kind == "buy" then
        local parts = {}
        for _, it in ipairs(s.items or {}) do
            local n = WK.GetItemInfo and WK.GetItemInfo(it.id)
            -- nom pas encore connu du jeu : demandé, le titre se met à jour au rafraîchissement suivant
            if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, it.id) end
            table.insert(parts, (n or string.format(T("objet %d"), it.id)) .. ((it.need or 1) > 1 and (" ×" .. it.need) or ""))
        end
        return string.format(T("Acheter : %s"), table.concat(parts, ", "))
    end
    local names = {}
    local pred = {}
    for _, q in ipairs(s.preds or {}) do pred[q] = true end
    for _, q in ipairs(s.qids) do
        local qq = WK.modules.Quests:Get(q)
        local n = (inLog(q) and Q():Title(q)) or (qq and WK.modules.Quests:Name(qq)) or ("#" .. q)
        -- suite prévue pas encore prise
        if pred[q] and not inLog(q) then n = n .. " " .. T("(suite)") end
        if colored then
            n = WK.UI:Hex(self:ProgressColor(q)) .. n .. "|r"
            if WK.modules.DataLog then n = n .. WK.modules.DataLog:Badge(q, true) end
        end
        -- quête de groupe (monstre élite) : étiquette « GROUPE » devant le nom
        n = WK.UI.GroupTag(q) .. n
        table.insert(names, n)
    end
    local list = table.concat(names, ", ")
    if s.kind == "pick" then return string.format(T("Prendre : %s"), list)
    elseif s.kind == "turn" then return string.format(T("Rendre : %s"), list)
    end
    -- étape « faire » : le nom des quêtes seul (plus de « Coin nord : … ») ; une quête répartie sur plusieurs
    -- étapes (objectifs à plusieurs endroits) : les objectifs de celle-ci, pour ne pas lire deux fois le même titre
    if #s.qids == 1 and self:SplitQuest(s, s.qids[1]) then
        local objs, own = self:StepQuestObjectives(s, s.qids[1])
        if own then
            local left = {}
            for _, o in ipairs(objs) do
                if not o.done then
                    left[#left + 1] = tostring(o.name ~= "" and o.name or o.text):gsub("%s*:%s*%d+%s*/%s*%d+.*$", "")
                end
            end
            if #left > 2 then left = { left[1], left[2], "+" .. (#left - 2) } end
            if #left > 0 then list = list .. " · " .. table.concat(left, ", ") end
        end
    end
    return list
end

-- La quête a-t-elle d'autres étapes « faire » dans la tournée ?
function M:SplitQuest(s, q)
    local t = self:Tour()
    if not t then return false end
    for _, o in ipairs(t.steps) do
        if o ~= s and o.kind == "do" then
            for _, x in ipairs(o.qids or {}) do if x == q then return true end end
        end
    end
    return false
end
-- Objectifs d'une quête pour une étape « faire » : ceux dont un camp est dans l'étape (2e valeur vraie), sinon tous
function M.StepQuestObjectives(_, s, q)
    local objs = Q():Objectives(q)
    local mine = s.camps and s.camps[q]
    if not mine then return objs, false end
    local out = {}
    for _, o in ipairs(objs) do
        local hit = false
        for _, oc in ipairs(o.camps or {}) do
            for _, sc in ipairs(mine) do
                local near = math.abs((oc.x or 0) - (sc.x or 0)) < 0.002 and math.abs((oc.y or 0) - (sc.y or 0)) < 0.002
                if oc.map == sc.map and near then
                    hit = true break
                end
            end
            if hit then break end
        end
        if hit then out[#out + 1] = o end
    end
    if #out == 0 then return objs, false end
    return out, true
end

-- Objectifs pas finis d'une étape « faire » : { name, have, need, done }
function M:StepObjectives(s)
    local out = {}
    if s.kind ~= "do" then return out end
    local multi = #s.qids > 1
    for qi, q in ipairs(s.qids) do
        if inLog(q) then
            local qn = multi and Q():Title(q) or nil
            for _, o in ipairs((M:StepQuestObjectives(s, q))) do
                table.insert(out, { name = o.name ~= "" and o.name or o.text, have = o.have, need = o.need, done = o.done, quest = qn,
                    refs = o.refs, type = o.type, qid = q,
                    qi = multi and qi or nil })
            end
        end
    end
    return out
end

-- Temps restant estimé (s) : étapes à partir de l'étape en cours
function M:Remaining()
    local t = self:Tour()
    if not t then return 0 end
    local s = 0
    for i = t.idx, #t.steps do s = s + (t.steps[i].secs or 0) end
    return s
end

-- Passe les étapes faites, guide vers l'étape en cours, termine la tournée
function M:Advance()
    local t = self:Tour()
    if not t then return end
    self:CheckNear()
    while t.steps[t.idx] and self:StepDone(t.steps[t.idx]) do t.idx = t.idx + 1; self.lastKey = nil end
    if not t.steps[t.idx] then self:Finish() return end
    self:Retarget()
end

function M:Retarget()
    local t = self:Tour()
    if not t or t.paused or not on() then return end
    local s = t.steps[t.idx]
    if not s then return end
    local g = G()
    if g.target and g.target.kind ~= "qtour" and g.target.kind ~= "qtrack" then return end
    local key = t.idx .. ":" .. s.map .. ":" .. s.x
    if key == self.lastKey then return end
    self.lastKey = key
    local title = self:StepTitle(s)
    local tg = { map = s.map, x = s.x, y = s.y, e = { s.x * 100, s.y * 100, 0, nil, nil, title, title,
        string.format(T("Étape %d / %d"), t.idx, #t.steps) } }
    tg.cont, tg.wx, tg.wy = world(s.map, s.x, s.y)
    g:Start(tg, "Tournée de quêtes", "qtour")
end

function M:Finish()
    local t = self:Tour()
    if not t then return end
    self:Config().allZone = nil
    self:Config().planZone = nil
    local XP = WK.modules.XP
    local gained = XP and XP.session and (XP.session.gained - (t.gained0 or 0)) or 0
    local mins = math.max(1, math.floor((time() - (t.start or time())) / 60 + 0.5))
    WK:Print(string.format(T("Tournée finie : %d étapes en %d min, %d XP, %d quête(s) rendue(s)."), #t.steps, mins, math.max(0, gained), t.turned or 0))
    self:Config().tour[WK:CharKey()] = nil
    local g = G()
    if g.target and g.target.kind == "qtour" then g:Stop() end
    self.lastKey = nil
    self:Changed()
end

function M:Changed()
    if WK.UI.RefreshQuestTracker then WK.UI:RefreshQuestTracker() end
    if WK.UI.RefreshQuestCamps then WK.UI:RefreshQuestCamps() end
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Donneur d'une quête utile tout près (une fois par quête et par session)
---------------------------------------------------------------------------
local told = {}
local function nearCheck()
    if not on() or not M:Config().nearAlert then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local me = G():PlayerPos()
    if not me then return end
    local Qs = WK.modules.Quests
    local zone = Qs:PlayerZone()
    if not zone then return end
    local c = WK.DB:Me() or {}
    local lvl = UnitLevel and UnitLevel("player") or c.level or 1
    local picked = M:Config().picked[WK:CharKey()] or {}
    local n, names = 0, {}
    for _, q in ipairs(Qs:OnMap(zone)) do
        if q.x and not told[q.id] and picked[q.id] ~= false and (q.lvl or 0) <= lvl + M:Config().maxAbove
            and (q.lvl or 0) >= lvl - 5 and Qs:ForChar(q, c) and Qs:State(q, c) == "avail" then
            local p = point(q.smap or zone, q.x / 100, q.y / 100)
            if dist(me, p) < 40 then n = n + 1; told[q.id] = true; table.insert(names, Qs:Name(q)) end
        end
    end
    if n > 0 then
        -- les rappels à l'écran ont été retirés : la ligne passe par le chat (avant, rien ne s'affichait mais
        -- les quêtes étaient marquées « déjà dites »)
        WK:Print(string.format(T("%d quête(s) à prendre tout près : %s"), n, table.concat(names, ", ")))
    end
end

---------------------------------------------------------------------------
-- Évènements
---------------------------------------------------------------------------
local pending
local function soon()
    M:Invalidate()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function() pending = nil; if on() and M:Tour() then M:Advance(); M:Changed() end end)
end
WK:On("QUEST_LOG_UPDATE", soon)
WK:On("QUEST_ACCEPTED", soon)
WK:On("QUEST_TURNED_IN", function(qid)
    local t = M:Tour()
    if t then t.turned = (t.turned or 0) + 1 end
    soon()
    -- quête rendue qui a une suite : la tournée est refaite (la suite prévue devient une vraie quête à
    -- prendre, ou disparaît si le jeu ne la propose pas)
    local q = qid and WK.modules.Quests and WK.modules.Quests:Get(qid)
    if t and q and q.nxt then
        local planned = false
        for _, st in ipairs(t.steps) do for _, x in ipairs(st.qids or {}) do if x == q.nxt then planned = true end end end
        C_Timer.After(1.5, function()
            local t2 = M:Tour()
            if not (on() and t2 and not t2.paused) then return end
            M:Invalidate()
            local list = M:Candidates()
            for _, e in ipairs(list) do
                if e.id == q.nxt and e.picked then
                    M:Reorder()
                    if not planned then WK:Print(string.format(T("Suite ajoutée à la tournée : %s"), e.title or ("#" .. e.id))) end
                    return
                end
            end
            if planned then M:Reorder() end
        end)
    end
end)
-- « Sur ton chemin » : la carte de tournée est repeinte quand la quête proposée change
local lastWay
local function wayCheck()
    if not (on() and M:Active()) then lastWay = nil return end
    local w = M:OnTheWay()
    local id = w and w.e and w.e.id or false
    if id ~= lastWay then
        lastWay = id
        if WK.UI.RefreshQuestTracker then WK.UI:RefreshQuestTracker() end
    end
end
WK:On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(5, nearCheck)
        C_Timer.NewTicker(4, wayCheck)
    end
end)
-- arrivée dans une autre zone de quêtes : une tournée faite ailleurs est refaite avec les quêtes d'ici
-- (quêtes cochées de la zone et journal) ; les étapes d'ailleurs qui restaient sont gardées à la fin
WK:On("ZONE_CHANGED_NEW_AREA", function()
    C_Timer.After(2, function()
        local t = M:Tour()
        if not (on() and t and not t.paused) then return end
        local zone = WK.modules.Quests:PlayerZone()
        if not zone or zone == t.zone or M:Config().planZone or t.custom then return end
        M:Reorder()
        local n = M:Tour()
        if n then
            local msg = string.format(T("Tournée refaite pour cette zone : %d étapes."), #n.steps)
            if (M.keptSteps or 0) > 0 then
                msg = msg .. " " .. string.format(T("%d étape(s) d'une autre zone gardée(s) à la fin."), M.keptSteps)
            end
            WK:Print(msg)
        end
    end)
end)
