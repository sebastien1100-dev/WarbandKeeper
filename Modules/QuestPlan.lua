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
local SECS = { m = 22, i = 26, o = 12 } -- temps moyen par unité d'objectif

function M:Config()
    local g = WK.DB.global
    g.questPlan = g.questPlan or {}
    local c = g.questPlan
    c.picked = c.picked or {}
    c.tour = c.tour or {}
    if c.nearAlert == nil then c.nearAlert = true end
    c.maxAbove = c.maxAbove or 2
    return c
end
local function Q() return WK.modules.QuestTrack end
local function G() return WK.modules.Guide end
local function on() return WK:FeatureOn("quests") end

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
    local zone = WK.modules.Quests:PlayerZone()
    local out = {}
    if not zone then return out, nil end
    local Qs = WK.modules.Quests
    local me = WK.DB:Me() or {}
    local lvl = UnitLevel and UnitLevel("player") or me.level or 1
    local cfg = self:Config()
    local seen = {}
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
        if e.center or (e.complete and e.turnIn) then table.insert(out, e); seen[e.id] = true end
    end
    for _, l in ipairs(Q():LogQuests()) do
        local q = Qs:Get(l.id)
        add({ id = l.id, title = l.title, lvl = l.level or (q and q.lvl) or lvl, xp = q and q.xp or 0, inLog = true, complete = l.complete })
    end
    for _, q in ipairs(Qs:OnMap(zone)) do
        if not seen[q.id] and q.x and Qs:ForChar(q, me) and Qs:State(q, me) == "avail"
            and (q.lvl or 0) <= lvl + 4 and (q.lvl or 0) >= lvl - 8 then
            local gm = q.smap or zone
            add({ id = q.id, title = Qs:Name(q), lvl = q.lvl, xp = q.xp or 0, giver = point(gm, q.x / 100, q.y / 100),
                giverName = q.sid })
        end
    end
    -- choix : coché d'office si le niveau va (au plus maxAbove au-dessus du perso)
    local picked = cfg.picked[WK:CharKey()] or {}
    for _, e in ipairs(out) do
        local p = picked[e.id]
        if p == nil then p = e.inLog or (e.lvl or 0) <= lvl + cfg.maxAbove end
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
local function objTime(qid, inLog)
    local s = 0
    if inLog then
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

function M:Build()
    local coins = self:Coins()
    if memo.build and memo.coins == coins then return self:CopyTour(memo.build) end
    local t = self:BuildNow(coins)
    memo.build = t
    return self:CopyTour(t)
end
function M:CopyTour(t)
    local steps = {}
    for i, s in ipairs(t.steps) do steps[i] = s end
    return { steps = steps, idx = 1, start = time(), secs = t.secs, meters = t.meters,
        gained0 = WK.modules.XP and WK.modules.XP.session and WK.modules.XP.session.gained or 0, turned = 0 }
end
function M:BuildNow(coins)
    local nodes = {}
    local function node(kind, p, qid, title)
        -- même endroit (moins de 25 m) et même genre : une seule étape
        for _, n in ipairs(nodes) do
            if n.kind == kind and dist(n, p) < 25 then table.insert(n.qids, qid) return n end
        end
        local n = { kind = kind, map = p.map, x = p.x, y = p.y, cont = p.cont, wx = p.wx, wy = p.wy, qids = { qid }, title = title }
        table.insert(nodes, n)
        return n
    end
    for _, k in ipairs(coins) do
        local doNode
        for _, e in ipairs(k.quests) do
            if e.picked then
                local pick = (not e.inLog) and e.giver and node("pick", e.giver, e.id, e.title) or nil
                if e.center and not e.complete then
                    if not doNode then
                        doNode = { kind = "do", map = k.center.map, x = k.center.x, y = k.center.y, cont = k.center.cont,
                            wx = k.center.wx, wy = k.center.wy, qids = {}, after = {}, label = k.label }
                        table.insert(nodes, doNode)
                    end
                    table.insert(doNode.qids, e.id)
                    if pick then doNode.after[pick] = true end
                    doNode.secs = (doNode.secs or 0) + objTime(e.id, e.inLog)
                end
                if e.turnIn then
                    local tn = node("turn", e.turnIn, e.id, e.title)
                    tn.after = tn.after or {}
                    if doNode then tn.after[doNode] = true end
                    if pick then tn.after[pick] = true end
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
    -- 2-opt : inverser un segment s'il raccourcit la tournée et garde l'ordre valable
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
    while improved and guard < 40 do
        improved, guard = false, guard + 1
        local base = len(order)
        for i = 1, #order - 1 do
            for j = i + 1, #order do
                local seq = {}
                for k = 1, i - 1 do seq[#seq + 1] = order[k] end
                for k = j, i, -1 do seq[#seq + 1] = order[k] end
                for k = j + 1, #order do seq[#seq + 1] = order[k] end
                if valid(seq) then
                    local l = len(seq)
                    if l < base - 1 then order, base, improved = seq, l, true end
                end
            end
        end
    end
    -- étapes enregistrables (sans références entre nœuds)
    local steps, total, travel, prev = {}, 0, 0, me
    for _, n in ipairs(order) do
        local d = prev and dist(prev, n) or 0
        if d >= 100000 then d = 0 end
        travel = travel + d
        local secs = d / SPEED + (n.secs or (n.kind == "do" and 0 or 15))
        total = total + secs
        table.insert(steps, { kind = n.kind, qids = n.qids, map = n.map, x = n.x, y = n.y, secs = math.floor(secs), label = n.label })
        prev = n
    end
    return { steps = steps, idx = 1, start = time(), secs = math.floor(total), meters = math.floor(travel),
        gained0 = WK.modules.XP and WK.modules.XP.session and WK.modules.XP.session.gained or 0, turned = 0 }
end

function M:Tour() return self:Config().tour[WK:CharKey()] end
function M:Active() local t = self:Tour(); return t and not t.paused and t.steps[t.idx] ~= nil end

function M:Start()
    self:Invalidate()
    local t = self:Build()
    if #t.steps == 0 then WK:Print(T("Rien à faire : coche des quêtes dans « À prendre ».")) return nil end
    self:Config().tour[WK:CharKey()] = t
    self.lastKey = nil
    self:Advance()
    self:Changed()
    return t
end

function M:Stop()
    self:Config().tour[WK:CharKey()] = nil
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

-- Recalcule l'ordre des étapes qui restent (depuis l'endroit où tu es)
function M:Reorder()
    local t = self:Tour()
    if not t then return self:Start() end
    local keep = { start = t.start, gained0 = t.gained0, turned = t.turned }
    self:Invalidate()
    local n = self:Build()
    n.start, n.gained0, n.turned = keep.start, keep.gained0, keep.turned
    self:Config().tour[WK:CharKey()] = n
    self.lastKey = nil
    self:Advance()
    self:Changed()
end

local function inLog(qid) return Q():InLog(qid) end
function M:StepDone(s)
    if s.kind == "pick" then
        for _, q in ipairs(s.qids) do if not inLog(q) then return false end end
        return true
    elseif s.kind == "do" then
        for _, q in ipairs(s.qids) do
            if inLog(q) and not Q():IsComplete(q) then
                for _, o in ipairs(Q():Objectives(q)) do if not o.done then return false end end
            end
        end
        return true
    else
        for _, q in ipairs(s.qids) do if inLog(q) then return false end end
        return true
    end
end

-- Titre lisible d'une étape
function M:StepTitle(s)
    local names = {}
    for _, q in ipairs(s.qids) do
        local qq = WK.modules.Quests:Get(q)
        table.insert(names, (inLog(q) and Q():Title(q)) or (qq and WK.modules.Quests:Name(qq)) or ("#" .. q))
    end
    local list = table.concat(names, ", ")
    if s.kind == "pick" then return string.format(T("Prendre : %s"), list)
    elseif s.kind == "turn" then return string.format(T("Rendre : %s"), list)
    end
    return string.format(T("Coin %s : %s"), s.label or "", list)
end

-- Objectifs pas finis d'une étape « faire » : { name, have, need, done }
function M:StepObjectives(s)
    local out = {}
    if s.kind ~= "do" then return out end
    for _, q in ipairs(s.qids) do
        if inLog(q) then
            for _, o in ipairs(Q():Objectives(q)) do
                table.insert(out, { name = o.name ~= "" and o.name or o.text, have = o.have, need = o.need, done = o.done })
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
        WK.modules.QoL:Remind("qplan.near", string.format(T("%d quête(s) à prendre tout près : %s"), n, table.concat(names, ", ")),
            1, 0.82, 0.2, nil, { ttl = 30 })
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
WK:On("QUEST_TURNED_IN", function()
    local t = M:Tour()
    if t then t.turned = (t.turned or 0) + 1 end
    soon()
end)
WK:On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(5, nearCheck) end
end)
