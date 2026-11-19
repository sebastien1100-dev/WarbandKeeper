local ADDON_NAME, WK = ...
local M = WK:NewModule("Nav")
local T = function(s) return WK.T(s) end

-- Navigation : trajet qui suit les chemins connus, de toi jusqu'au lieu guidé (Modules/Guide.lua).
--   Chemins de base : patrouilles des PNJ (Modules/RoadsDB.lua, QuestieDB) : un PNJ y marche, c'est praticable.
--   Chemins appris : ce que tes persos parcourent à pied ou à monture (hors vol, taxi, instances, fantôme),
--     noté par tronçons nouveaux seulement (un endroit déjà connu ne se note pas deux fois).
--     WK.DB.global.nav = { trails = { [continent] = { { x, y, x, y, ... } } } } (mètres du jeu, hors profils)
--   Trajet : A* sur le graphe des chemins (coordonnées « monde » du continent : x nord, y ouest).
--     Suivre un chemin coûte sa longueur ; quitter les chemins coûte OFF fois la distance (terrain inconnu :
--     murs, falaises, eau). Les vols connus du perso (maîtres de vol découverts) entrent dans le calcul ;
--     un autre continent mène au quai ou au zeppelin qui y va (Modules/MapLayers.lua).
--   Suivi : point suivant sur le trajet pour la flèche, recalcul si on s'écarte, étapes (marche, vol, bateau).
local OFF = 2.0        -- coût d'un mètre hors des chemins connus
local LEARNED = 0.95   -- un chemin appris est sûr : légèrement préféré
local JOIN = 30        -- deux chemins à moins de JOIN m se rejoignent
local JUMP = 160       -- saut hors chemin possible entre deux chemins (coût OFF)
local START_R = 500    -- chemins atteignables depuis le départ
local CELL = 100       -- grille de recherche spatiale
local STEP = 12        -- un point appris tous les STEP m
local NOVEL = 9        -- un point à moins de NOVEL m d'un chemin connu n'est pas nouveau
local MAX_LEARN = 60000
local WALK_SPEED, MOUNT_SPEED, FLY_SPEED = 7, 11.2, 30

local floor, sqrt, huge = math.floor, math.sqrt, math.huge

local function Gd() return WK.modules.Guide end
local function cfg() return Gd():Config() end
local function data()
    local g = WK.DB.global
    g.nav = g.nav or {}
    g.nav.trails = g.nav.trails or {}
    return g.nav
end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return sqrt(dx * dx + dy * dy) end

---------------------------------------------------------------------------
-- Graphe d'un continent (construit à la demande, refait quand les chemins appris changent)
---------------------------------------------------------------------------
local graphs = {}  -- [cont] = { X, Y, adj, grid, n, learnedLen, roadLen }
local contOfMap = {}
local function mapCont(map)
    local c = contOfMap[map]
    if c == nil then
        c = Gd().ToWorld(map, 0.5, 0.5) or false
        contOfMap[map] = c
    end
    return c or nil
end

local function newGraph()
    return { X = {}, Y = {}, adj = {}, grid = {}, key = {}, n = 0, learnedLen = 0, roadLen = 0 }
end
local function cellKey(x, y) return floor(x / CELL) * 100000 + floor(y / CELL) end
local function addNode(g, x, y)
    local k = floor(x / 4) .. ":" .. floor(y / 4) -- fusion des points à 4 m près
    local i = g.key[k]
    if i then return i end
    g.n = g.n + 1
    i = g.n
    g.X[i], g.Y[i], g.adj[i] = x, y, {}
    g.key[k] = i
    local ck = cellKey(x, y)
    local cell = g.grid[ck]
    if not cell then cell = {}; g.grid[ck] = cell end
    cell[#cell + 1] = i
    return i
end
local function link(g, a, b, cost)
    if a == b then return end
    local la, lb = g.adj[a], g.adj[b]
    for k = 1, #la, 2 do if la[k] == b then if cost < la[k + 1] then la[k + 1] = cost end return end end
    la[#la + 1] = b; la[#la + 1] = cost
    lb[#lb + 1] = a; lb[#lb + 1] = cost
end
-- Nœuds à moins de r de (x, y) : appelle fn(i, d)
local function near(g, x, y, r, fn)
    local cx0, cx1 = floor((x - r) / CELL), floor((x + r) / CELL)
    local cy0, cy1 = floor((y - r) / CELL), floor((y + r) / CELL)
    for cx = cx0, cx1 do
        for cy = cy0, cy1 do
            local cell = g.grid[cx * 100000 + cy]
            if cell then
                for _, i in ipairs(cell) do
                    local d = dist(x, y, g.X[i], g.Y[i])
                    if d <= r then fn(i, d) end
                end
            end
        end
    end
end
local function addLine(g, pts, factor)
    local prev, len = nil, 0
    for k = 1, #pts - 1, 2 do
        local i = addNode(g, pts[k], pts[k + 1])
        if prev then
            local d = dist(g.X[prev], g.Y[prev], g.X[i], g.Y[i])
            link(g, prev, i, d * factor)
            len = len + d
        end
        prev = i
    end
    return len
end

local function lineLen(pts)
    local len = 0
    for k = 1, #pts - 3, 2 do len = len + dist(pts[k], pts[k + 1], pts[k + 2], pts[k + 3]) end
    return len
end

local function build(cont)
    local g = newGraph()
    local G = Gd()
    for map, lines in pairs(WK.RoadsDB or {}) do
        if mapCont(map) == cont then
            for _, line in ipairs(lines) do
                local pts = {}
                for k = 1, #line - 1, 2 do
                    local c, wx, wy = G.ToWorld(map, line[k] / 100, line[k + 1] / 100)
                    if c == cont then pts[#pts + 1] = wx; pts[#pts + 1] = wy end
                end
                g.roadLen = g.roadLen + addLine(g, pts, 1)
            end
        end
    end
    for _, pts in ipairs(data().trails[cont] or {}) do
        g.learnedLen = g.learnedLen + addLine(g, pts, LEARNED)
    end
    -- bateaux appris sur ce continent : un saut d'un quai à l'autre (temps d'attente compté)
    for _, b in ipairs(data().boats or {}) do
        if b.a.c == cont and b.b.c == cont then
            local na, nb = addNode(g, b.a.wx, b.a.wy), addNode(g, b.b.wx, b.b.wy)
            local len = (b.path and b.path.pts and lineLen(b.path.pts)) or dist(b.a.wx, b.a.wy, b.b.wx, b.b.wy)
            link(g, na, nb, len * 0.35 + 300)
        end
    end
    -- jonctions : les chemins qui se touchent se rejoignent
    for i = 1, g.n do
        near(g, g.X[i], g.Y[i], JOIN, function(j, d) if j > i then link(g, i, j, d * 1.1) end end)
    end
    graphs[cont] = g
    return g
end
local function graph(cont)
    return graphs[cont] or build(cont)
end

---------------------------------------------------------------------------
-- Recherche A* (étalée sur plusieurs images)
---------------------------------------------------------------------------
-- Tas binaire de nœuds triés par f
local function heapPush(h, f, i, fv)
    local n = #h + 1
    h[n] = i; f[n] = fv
    while n > 1 do
        local p = floor(n / 2)
        if f[p] <= f[n] then break end
        h[p], h[n] = h[n], h[p]; f[p], f[n] = f[n], f[p]
        n = p
    end
end
local function heapPop(h, f)
    local n = #h
    if n == 0 then return nil end
    local top, topF = h[1], f[1]
    h[1], f[1] = h[n], f[n]
    h[n], f[n] = nil, nil
    n = n - 1
    local i = 1
    while true do
        local l, r, m = i * 2, i * 2 + 1, i
        if l <= n and f[l] < f[m] then m = l end
        if r <= n and f[r] < f[m] then m = r end
        if m == i then break end
        h[i], h[m] = h[m], h[i]; f[i], f[m] = f[m], f[i]
        i = m
    end
    return top, topF
end

local clock = debugprofilestop or function() return GetTime() * 1000 end
-- Chemin à pied de (sx, sy) à (tx, ty) sur le continent : { x, y, x, y, ... } ; yield() entre les tranches
local function walk(cont, sx, sy, tx, ty, budget)
    local g = graph(cont)
    local GOAL, START = -1, 0
    local best = { [START] = 0 }
    local from = {}
    local closed = {}
    local h, f = {}, {}
    local D = dist(sx, sy, tx, ty)
    -- la ligne droite (hors chemins) est toujours possible
    local goalCost, goalFrom = D * OFF, START
    near(g, sx, sy, START_R, function(i, d)
        local c = d * OFF
        if not best[i] or c < best[i] then
            best[i] = c; from[i] = START
            heapPush(h, f, i, c + dist(g.X[i], g.Y[i], tx, ty) * LEARNED)
        end
    end)
    local t0, ops = clock(), 0
    while true do
        local i, fi = heapPop(h, f)
        if not i or fi >= goalCost then break end
        if not closed[i] then
            closed[i] = true
            local gi = best[i]
            local xi, yi = g.X[i], g.Y[i]
            -- finir tout droit vers le but
            local cg = gi + dist(xi, yi, tx, ty) * OFF
            if cg < goalCost then goalCost, goalFrom = cg, i end
            local function relax(j, c)
                local nc = gi + c
                if not best[j] or nc < best[j] then
                    best[j] = nc; from[j] = i
                    heapPush(h, f, j, nc + dist(g.X[j], g.Y[j], tx, ty) * LEARNED)
                end
            end
            local adj = g.adj[i]
            for k = 1, #adj, 2 do
                local j = adj[k]
                if not closed[j] then relax(j, adj[k + 1]) end
            end
            -- saut hors chemin vers un chemin voisin
            near(g, xi, yi, JUMP, function(j, d) if not closed[j] and d > JOIN then relax(j, d * OFF) end end)
            ops = ops + 1
            if ops % 64 == 0 and budget and clock() - t0 > budget then
                coroutine.yield()
                t0 = clock()
            end
            if ops > 40000 then break end
        end
    end
    -- remonter le trajet
    local rev = { tx, ty }
    local i = goalFrom
    while i and i ~= START do
        rev[#rev + 1] = g.X[i]; rev[#rev + 1] = g.Y[i]
        i = from[i]
    end
    rev[#rev + 1] = sx; rev[#rev + 1] = sy
    local pts = {}
    for k = #rev - 1, 1, -2 do pts[#pts + 1] = rev[k]; pts[#pts + 1] = rev[k + 1] end
    return pts, goalCost
end

---------------------------------------------------------------------------
-- Vols connus du perso (notés à l'ouverture de la carte des vols)
---------------------------------------------------------------------------
local function myTaxi()
    local me = WK.DB:Me()
    me.taxi = me.taxi or {}
    return me.taxi
end
WK:On("TAXIMAP_OPENED", function()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and GetTaxiMapID) then return end
    local mapID = GetTaxiMapID()
    local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
    if not ok or type(nodes) ~= "table" then return end
    local known = myTaxi()
    local unreach = Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2
    for _, n in ipairs(nodes) do
        if n.name and n.position and n.state ~= unreach then
            local x, y = n.position.x, n.position.y
            if n.position.GetXY then x, y = n.position:GetXY() end
            local c, wx, wy = Gd().ToWorld(mapID, x, y)
            if c then known[n.name] = { c, floor(wx), floor(wy) } end
        end
    end
end)
local function nearestTaxi(cont, x, y)
    local best, bd, bn
    for name, n in pairs(myTaxi()) do
        if n[1] == cont then
            local d = dist(x, y, n[2], n[3])
            if not bd or d < bd then best, bd, bn = n, d, name end
        end
    end
    return best, bd, bn
end
local function speed()
    local lvl = UnitLevel and UnitLevel("player") or 1
    return (lvl >= 40) and MOUNT_SPEED or WALK_SPEED
end

---------------------------------------------------------------------------
-- Plan : étapes { kind = "walk", pts } | { kind = "fly", from, to, ax, ay, bx, by } | { kind = "boat", ... }
---------------------------------------------------------------------------
M.route = nil
local job

local function playerWorld()
    local p = Gd():PlayerPos()
    if not (p and p.cont) then return nil end
    return p.cont, p.wx, p.wy
end

local computeFrom
-- Pierre de foyer et téléports (Retour astral du chaman, téléports du mage, Reflet-de-Lune du druide) :
-- point d'arrivée appris en jeu (lieu de la pierre noté chez l'aubergiste, arrivée notée après chaque sort).
local HEARTH_ITEM, HEARTH_SPELL, RECALL = 6948, 8690, 556
local PORTS = { [3561] = true, [3562] = true, [3563] = true, [3565] = true, [3566] = true, [3567] = true, [18960] = true }
local function hearthData()
    local c = WK.DB:Me()
    c.ports = c.ports or {}
    return c
end
local function spellReady(id)
    if not (IsPlayerSpell and IsPlayerSpell(id)) and not (IsSpellKnown and IsSpellKnown(id)) then return false end
    local start, dur
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(info) == "table" then start, dur = info.startTime, info.duration end
    elseif GetSpellCooldown then start, dur = GetSpellCooldown(id) end
    return not dur or dur <= 1.5 or (start or 0) + dur <= GetTime()
end
local function hearthReady()
    local n = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(HEARTH_ITEM)) or (GetItemCount and GetItemCount(HEARTH_ITEM)) or 0
    if n <= 0 then return false end
    local start, dur
    if C_Container and C_Container.GetItemCooldown then start, dur = C_Container.GetItemCooldown(HEARTH_ITEM)
    elseif GetItemCooldown then start, dur = GetItemCooldown(HEARTH_ITEM) end
    return not dur or dur == 0 or (start or 0) + dur <= GetTime()
end
-- moyens de voyage prêts : { { label, pc, px, py } }
local function portOptions()
    local c = hearthData()
    local out = {}
    local h = c.hearth
    if h and h.cont then
        if hearthReady() then
            table.insert(out, { label = string.format(T("Pierre de foyer » %s"), h.name or "?"), pc = h.cont, px = h.wx, py = h.wy })
        elseif spellReady(RECALL) then
            table.insert(out, { label = string.format(T("Retour astral » %s"), h.name or "?"), pc = h.cont, px = h.wx, py = h.wy })
        end
    end
    for id, pt in pairs(c.ports) do
        if PORTS[id] and pt.cont and spellReady(id) then
            local name = WK.SpellInfo(id)
            table.insert(out, { label = name or T("Téléportation"), pc = pt.cont, px = pt.wx, py = pt.wy })
        end
    end
    return out
end
-- apprentissage : lieu de la pierre (chez l'aubergiste) et arrivée des sorts
WK:On("HEARTHSTONE_BOUND", function()
    local cont, x, y = playerWorld()
    if not cont then return end
    local c = hearthData()
    c.hearth = { cont = cont, wx = x, wy = y, name = GetBindLocation and GetBindLocation() or nil }
end)
local pendingPort
WK:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
    if unit ~= "player" then return end
    if spellID == HEARTH_SPELL or spellID == RECALL or PORTS[spellID] then
        local cont, x, y = playerWorld()
        pendingPort = { id = spellID, t = GetTime(), cont = cont, x = x, y = y }
        C_Timer.After(6, function() M:NotePort() end)
    end
end)
function M:NotePort()
    local p = pendingPort
    if not p or GetTime() - p.t > 90 then pendingPort = nil return end
    local cont, x, y = playerWorld()
    if not cont then return end
    if cont == p.cont and p.x and dist(x, y, p.x, p.y) < 300 then return end -- pas encore arrivé
    pendingPort = nil
    local c = hearthData()
    if p.id == HEARTH_SPELL or p.id == RECALL then
        c.hearth = { cont = cont, wx = x, wy = y, name = (GetBindLocation and GetBindLocation()) or (c.hearth and c.hearth.name) }
    else
        c.ports[p.id] = { cont = cont, wx = x, wy = y }
    end
end
WK:On("PLAYER_ENTERING_WORLD", function() if pendingPort then C_Timer.After(2, function() M:NotePort() end) end end)

local PORT_COST = 30 -- incantation (10 s) et écran de chargement
local function compute(target)
    local cont, sx, sy = playerWorld()
    if not cont then return nil end
    local direct = computeFrom(cont, sx, sy, target)
    local tc, tx, ty = target.cont, target.wx, target.wy
    if not tc then tc, tx, ty = Gd().ToWorld(target.map, target.x, target.y) end
    if not tc or not direct then return direct end
    -- un moyen de voyage prêt fait-il gagner beaucoup de temps ?
    local base = direct.seconds or (direct.partial and 3600) or 3600
    local best, bestCost
    for _, o in ipairs(portOptions()) do
        if o.pc == tc then
            local cost = PORT_COST + dist(o.px, o.py, tx, ty) * 1.25 / speed()
            if cost < base * 0.75 and base - cost > 60 and (not bestCost or cost < bestCost) then best, bestCost = o, cost end
        end
    end
    if not best then return direct end
    local sub = computeFrom(best.pc, best.px, best.py, target)
    if not sub then return direct end
    local legs = { { kind = "port", label = best.label, pc = best.pc, px = best.px, py = best.py } }
    for _, l in ipairs(sub.legs) do table.insert(legs, l) end
    return { legs = legs, cont = cont, seconds = PORT_COST + (sub.seconds or 0), port = true }
end
M.PortOptions = portOptions

computeFrom = function(cont, sx, sy, target)
    local tc, tx, ty = target.cont, target.wx, target.wy
    if not tc then tc, tx, ty = Gd().ToWorld(target.map, target.x, target.y) end
    if not tc then return nil end
    local legs = {}
    if tc ~= cont then
        -- autre continent : vers le quai qui y mène
        local L = WK.modules.MapLayers
        local fac = UnitFactionGroup and UnitFactionGroup("player")
        fac = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
        local best, bd
        for _, r in ipairs(L and L:AllTransports() or {}) do
            if not (r.side and r.side ~= fac) then
                -- ligne du jeu à plus de 2 quais (boucle) : chaque étape ne va que de a vers b
                local loop = r.game and r.game.stops and #r.game.stops > 2
                for _, pair in ipairs(loop and { { r.a, r.b } } or { { r.a, r.b }, { r.b, r.a } }) do
                    local here, there = pair[1], pair[2]
                    local hc, hx, hy = Gd().ToWorld(here[1], here[2] / 100, here[3] / 100)
                    local thc = Gd().ToWorld(there[1], there[2] / 100, there[3] / 100)
                    if hc == cont and thc == tc then
                        local d = dist(sx, sy, hx, hy)
                        if not bd or d < bd then best, bd = { here = here, there = there, x = hx, y = hy, kind = r.kind, line = r }, d end
                    end
                end
            end
        end
        if not best then return { legs = {}, cont = cont, noRoute = true } end
        local pts = walk(cont, sx, sy, best.x, best.y, 4)
        legs[1] = { kind = "walk", pts = pts, len = lineLen(pts) }
        legs[2] = { kind = best.kind, to = best.there[4], from = best.here[4], line = best.line,
                    side = best.line and (best.here == best.line.a and "a" or "b") }
        return { legs = legs, cont = cont, partial = true }
    end
    local D = dist(sx, sy, tx, ty)
    local pts = walk(cont, sx, sy, tx, ty, 4)
    local walkLen = lineLen(pts)
    local v = speed()
    local walkTime = walkLen / v
    -- un vol connu fait-il gagner du temps ?
    if D > 1500 then
        local A, da, an = nearestTaxi(cont, sx, sy)
        local B, db, bn = nearestTaxi(cont, tx, ty)
        if A and B and an ~= bn and da + db < D * 0.6 then
            local fs = (WK.DB.global.flights and WK.DB.global.flights.worldSpeed) or FLY_SPEED
            local flyLen = dist(A[2], A[3], B[2], B[3])
            local estimate = (da + db) * 1.3 / v + flyLen * 1.15 / fs + 25
            if estimate < walkTime * 0.8 then
                local p1 = walk(cont, sx, sy, A[2], A[3], 4)
                local p2 = walk(cont, B[2], B[3], tx, ty, 4)
                legs[1] = { kind = "walk", pts = p1, len = lineLen(p1) }
                legs[2] = { kind = "fly", from = an, to = bn, ax = A[2], ay = A[3], bx = B[2], by = B[3], len = flyLen }
                legs[3] = { kind = "walk", pts = p2, len = lineLen(p2) }
                return { legs = legs, cont = cont, seconds = (legs[1].len + legs[3].len) / v + flyLen * 1.15 / fs + 25 }
            end
        end
    end
    legs[1] = { kind = "walk", pts = pts, len = walkLen }
    return { legs = legs, cont = cont, seconds = walkTime }
end

-- Calcul en arrière-plan (quelques ms par image) ; le trajet précédent reste affiché en attendant
local runner
local function pump()
    if not job then runner:Hide() return end
    local ok, res = coroutine.resume(job.co)
    if not ok then
        job = nil; runner:Hide()
        return
    end
    if coroutine.status(job.co) == "dead" then
        local target = job.target
        job = nil; runner:Hide()
        if Gd().target ~= target then return end
        if res then
            res.target = target
            res.leg, res.idx = 1, 1
            res.at = GetTime()
        end
        M.route = res
        if Gd().Redraw then Gd():Redraw() end
        if WK.UI.RefreshNavRoute then WK.UI:RefreshNavRoute() end
    end
end
function M:Plan(target)
    if not target then return end
    if not runner then
        runner = CreateFrame("Frame")
        runner:SetScript("OnUpdate", pump)
    end
    job = { target = target, co = coroutine.create(function() return compute(target) end) }
    runner:Show()
end
function M:Clear()
    job = nil
    M.route = nil
    if WK.UI.RefreshNavRoute then WK.UI:RefreshNavRoute() end
end

---------------------------------------------------------------------------
-- Suivi du trajet : point suivant, étape en cours, recalcul quand on s'écarte
---------------------------------------------------------------------------
local AHEAD = 25
local offSince, lastReplan = nil, 0
-- Point visé maintenant (monde) et texte de l'étape : x, y, texte, distance restante (m)
function M:Waypoint()
    local r = self.route
    if not r or not r.legs[r.leg] then return nil end
    local cont, px, py = playerWorld()
    if not cont or cont ~= r.cont then return nil end
    local leg = r.legs[r.leg]
    if leg.kind == "walk" then
        local pts = leg.pts
        local n = #pts / 2
        -- segment le plus proche à partir de l'index courant (on n'avance que vers l'avant)
        local bi, bd = r.idx, huge
        for k = r.idx, math.max(r.idx, math.min(n - 1, r.idx + 40)) do
            local ax, ay = pts[k * 2 - 1], pts[k * 2]
            local bx, by = pts[k * 2 + 1] or ax, pts[k * 2 + 2] or ay
            local dx, dy = bx - ax, by - ay
            local l2 = dx * dx + dy * dy
            local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
            local d = dist(px, py, ax + t * dx, ay + t * dy)
            if d < bd then bi, bd = k, d end
        end
        r.idx = bi
        -- écart : recalcul après 4 s à plus de 60 m du trajet
        local now = GetTime()
        if bd > 60 then
            offSince = offSince or now
            if now - offSince > 4 and now - lastReplan > 8 and r.target then
                lastReplan = now; offSince = nil
                M:Plan(r.target)
            end
        else
            offSince = nil
        end
        local k = math.min(n, bi + 1)
        while k < n and dist(px, py, pts[k * 2 - 1], pts[k * 2]) < AHEAD do k = k + 1 end
        local wx, wy = pts[k * 2 - 1], pts[k * 2]
        local rest = dist(px, py, wx, wy)
        for j = k, n - 1 do rest = rest + dist(pts[j * 2 - 1], pts[j * 2], pts[j * 2 + 1], pts[j * 2 + 2]) end
        -- fin de l'étape à pied
        if k >= n and rest < 20 and r.legs[r.leg + 1] then
            r.leg, r.idx = r.leg + 1, 1
            return self:Waypoint()
        end
        local nextLeg = r.legs[r.leg + 1]
        local text
        if nextLeg and nextLeg.kind == "fly" then text = string.format(T("Vers le maître de vol (%s)"), nextLeg.from)
        elseif nextLeg then
            text = string.format(T("Vers le quai : %s"), nextLeg.from or "?")
            -- horaires appris : départ, et si on arrive à temps (marche jusqu'au quai)
            local BT = WK.modules.BoatTimes
            local st = BT and nextLeg.line and BT:State(nextLeg.line, nextLeg.side)
            if st then
                local walkT = rest / speed()
                local pre = st.est and T("env. ") or ""
                text = text .. "  ·  " .. string.format(T("départ dans %s"), pre .. BT.Clock(st.inn))
                if walkT <= st.inn - 3 then text = text .. "  ·  " .. T("tu arrives à temps")
                else text = text .. "  ·  " .. string.format(T("le suivant dans %s"), pre .. BT.Clock(st.following)) end
            end
        end
        for j = r.leg + 1, #r.legs do
            local l = r.legs[j]
            if l.kind == "walk" then rest = rest + (l.len or 0) end
        end
        return wx, wy, text, rest
    elseif leg.kind == "port" then
        -- pierre de foyer ou téléport : étape suivante une fois arrivé (même continent ; sinon le
        -- changement de continent relance le calcul)
        if cont == leg.pc and dist(px, py, leg.px, leg.py) < 250 then
            r.leg, r.idx = r.leg + 1, 1
            return self:Waypoint()
        end
        return nil, nil, leg.label .. "  ·  " .. T("prête"), nil
    elseif leg.kind == "fly" then
        -- arrivé près du point d'atterrissage : étape suivante
        if dist(px, py, leg.bx, leg.by) < 80 and not (UnitOnTaxi and UnitOnTaxi("player")) then
            r.leg, r.idx = r.leg + 1, 1
            return self:Waypoint()
        end
        return leg.ax, leg.ay, string.format(T("Vol : %s » %s"), leg.from, leg.to), nil
    else
        local txt = string.format(T("Prends le %s pour %s"), leg.kind == "zeppelin" and T("zeppelin") or T("bateau"), leg.to or "?")
        local BT = WK.modules.BoatTimes
        local st = BT and leg.line and BT:State(leg.line, leg.side)
        if st then
            local pre = st.est and T("env. ") or ""
            txt = txt .. "  ·  " .. (st.atDock and string.format(T("à quai, départ dans %s"), pre .. BT.Clock(st.inn))
                or string.format(T("départ dans %s"), pre .. BT.Clock(st.inn)))
        end
        return nil, nil, txt, nil
    end
end

-- Changement de continent (bateau, zeppelin, portail) : on recalcule depuis le nouveau continent
WK:On("ZONE_CHANGED_NEW_AREA", function()
    local r = M.route
    if r and r.target then
        local cont = playerWorld()
        if cont and cont ~= r.cont then M:Plan(r.target) end
    end
end)

---------------------------------------------------------------------------
-- Apprentissage des chemins
---------------------------------------------------------------------------
local cur -- tronçon en cours : { cont, pts, lastX, lastY }
local function novel(cont, x, y)
    local g = graphs[cont]
    if not g then g = graph(cont) end
    local found = false
    near(g, x, y, NOVEL, function() found = true end)
    return not found
end
local nLearned
local function learnedPoints()
    if not nLearned then
        nLearned = 0
        for _, list in pairs(data().trails) do for _, t in ipairs(list) do nLearned = nLearned + #t / 2 end end
    end
    return nLearned
end
-- Simplification d'un tronçon (Ramer-Douglas-Peucker, 3 m) : la ligne garde sa forme, moins de points
local function simplify(pts, tol)
    tol = tol or 3
    local n = #pts / 2
    if n < 3 then return pts end
    local keep = { [1] = true, [n] = true }
    local stack = { { 1, n } }
    while #stack > 0 do
        local seg = table.remove(stack)
        local i, j = seg[1], seg[2]
        local ax, ay, bx, by = pts[i * 2 - 1], pts[i * 2], pts[j * 2 - 1], pts[j * 2]
        local dx, dy = bx - ax, by - ay
        local l2 = dx * dx + dy * dy
        local best, bk = 0, nil
        for k = i + 1, j - 1 do
            local px, py = pts[k * 2 - 1], pts[k * 2]
            local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
            local d = dist(px, py, ax + t * dx, ay + t * dy)
            if d > best then best, bk = d, k end
        end
        if bk and best > tol then
            keep[bk] = true
            stack[#stack + 1] = { i, bk }; stack[#stack + 1] = { bk, j }
        end
    end
    local out = {}
    for k = 1, n do if keep[k] then out[#out + 1] = pts[k * 2 - 1]; out[#out + 1] = pts[k * 2] end end
    return out
end

function M:EndTrail()
    if not cur then return end
    local t = cur
    cur = nil
    t.pts = simplify(t.pts)
    if #t.pts >= 4 and lineLen(t.pts) >= 30 then
        local d = data()
        d.trails[t.cont] = d.trails[t.cont] or {}
        table.insert(d.trails[t.cont], t.pts)
        nLearned = learnedPoints() + #t.pts / 2
        -- le graphe tient compte du tronçon tout de suite
        local g = graphs[t.cont]
        if g then
            local first = g.n + 1
            g.learnedLen = g.learnedLen + addLine(g, t.pts, LEARNED)
            for i = first, g.n do
                near(g, g.X[i], g.Y[i], JOIN, function(j, dd) if j < first then link(g, i, j, dd * 1.1) end end)
            end
        end
    end
end
local function canLearn()
    if not cfg().learn then return false end
    if M.IsRiding and M.IsRiding() then return false end
    if UnitOnTaxi and UnitOnTaxi("player") then return false end
    if IsFlying and IsFlying() then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if UnitInVehicle and UnitInVehicle("player") then return false end
    if IsInInstance then
        local _, it = IsInInstance()
        if it and it ~= "none" then return false end
    end
    return true
end
local function learnTick()
    if not canLearn() then M:EndTrail() return end
    local cont, x, y = playerWorld()
    if not cont then M:EndTrail() return end
    x, y = floor(x + 0.5), floor(y + 0.5)
    if cur and (cur.cont ~= cont or dist(x, y, cur.lastX, cur.lastY) > 90) then M:EndTrail() end -- téléport, bateau…
    if cur and dist(x, y, cur.lastX, cur.lastY) < STEP then return end
    if learnedPoints() > MAX_LEARN then return end
    if novel(cont, x, y) then
        if not cur then
            cur = { cont = cont, pts = {} }
            -- on raccroche le tronçon au point précédent (déjà connu) pour garder le chemin continu
            if M.lastPos and M.lastPos[1] == cont and dist(x, y, M.lastPos[2], M.lastPos[3]) < 90 then
                cur.pts[1], cur.pts[2] = M.lastPos[2], M.lastPos[3]
            end
        end
        cur.pts[#cur.pts + 1] = x; cur.pts[#cur.pts + 1] = y
        cur.lastX, cur.lastY = x, y
    elseif cur then
        -- retour sur un chemin connu : le tronçon s'y raccroche et se ferme
        cur.pts[#cur.pts + 1] = x; cur.pts[#cur.pts + 1] = y
        M:EndTrail()
    end
    M.lastPos = { cont, x, y }
end
---------------------------------------------------------------------------
-- Bateaux (et zeppelins) appris : la position avance alors que le perso ne bouge pas, hors vol et
-- hors taxi : il est porté par un transport. Le départ et l'arrivée deviennent deux quais, le
-- trajet suivi est gardé pour le dessin. WK.DB.global.nav.boats = { { kind, a, b, path } },
-- a et b = { map, x, y (0-100), name, c (continent), wx, wy }.
---------------------------------------------------------------------------
-- Un vrai trajet en bateau : autre continent, ou sur le même continent au moins 500 m entre les quais
-- et une autre région à l'arrivée (un autre déplacement sans bouger, pris pour un bateau, restait dans la même zone)
local MIN_BOAT = 500
local function validBoat(a, b)
    if not (a and b) then return false end
    if a.c ~= b.c then return true end
    if a.name and b.name and a.name == b.name then return false end
    return a.wx and b.wx and dist(a.wx, a.wy, b.wx, b.wy) >= MIN_BOAT or false
end
-- Trajet déjà dans les données (MapLayers.TRANSPORTS : bateaux et zeppelins connus), dans un sens ou dans l'autre
local function knownRoute(a, b)
    -- ligne des fichiers du jeu (Modules/BoatLines.lua) : déjà connue, jamais apprise en double
    local BL = WK.modules.BoatLines
    if BL and a and b and a.wx and b.wx and BL:StopNear(a.c, a.wx, a.wy, 300) and BL:StopNear(b.c, b.wx, b.wy, 400) then return true end
    local L, P = WK.modules.MapLayers, WK.modules.Guide
    if not (P and P.ToWorld and a and b and a.wx and b.wx) then return false end
    for _, t in ipairs(L and L.TRANSPORTS or {}) do
        local ca, ax, ay = P.ToWorld(t.a[1], t.a[2] / 100, t.a[3] / 100)
        local cb, bx, by = P.ToWorld(t.b[1], t.b[2] / 100, t.b[3] / 100)
        if ax and bx then
            local same = ca == a.c and cb == b.c and dist(ax, ay, a.wx, a.wy) < 300 and dist(bx, by, b.wx, b.wy) < 300
            local rev = cb == a.c and ca == b.c and dist(bx, by, a.wx, a.wy) < 300 and dist(ax, ay, b.wx, b.wy) < 300
            if same or rev then return true end
        end
    end
    return false
end
function M:Boats()
    local d = data()
    d.boats = d.boats or {}
    -- une fois : on retire les trajets appris qui n'en étaient pas, puis ceux qui doublent un trajet connu
    if not d.boatsChecked then
        d.boatsChecked = true
        for i = #d.boats, 1, -1 do if not validBoat(d.boats[i].a, d.boats[i].b) then table.remove(d.boats, i) end end
    end
    if not d.boatsChecked2 and WK.modules.Guide and WK.modules.Guide.ToWorld and C_Map and C_Map.GetWorldPosFromMapPos then
        d.boatsChecked2 = true
        for i = #d.boats, 1, -1 do if knownRoute(d.boats[i].a, d.boats[i].b) then table.remove(d.boats, i) end end
    end
    -- une fois : les traversées vers un autre continent finissaient au chargement, en pleine mer (quai au nom
    -- du continent, horaires faux) ; ces trajets et les horaires appris avant la correction sont oubliés
    if not d.boatsChecked3 and C_Map and C_Map.GetMapInfo then
        d.boatsChecked3 = true
        local function sea(q)
            local ok, info = pcall(C_Map.GetMapInfo, q and q.map)
            return not (ok and info) or (info.mapType and info.mapType <= 2)
        end
        for i = #d.boats, 1, -1 do if sea(d.boats[i].a) or sea(d.boats[i].b) then table.remove(d.boats, i) end end
        d.sched = nil
    end
    -- une fois (1.33.0) : les bateaux appris qui sont des lignes des fichiers du jeu (Modules/BoatLines.lua)
    -- sont oubliés : la ligne du jeu les remplace (tracé, quais, horaires)
    if not d.boatsChecked5 and WK.BoatLines and #WK.BoatLines > 0 then
        d.boatsChecked5 = true
        for i = #d.boats, 1, -1 do if knownRoute(d.boats[i].a, d.boats[i].b) then table.remove(d.boats, i) end end
    end
    -- une fois encore (1.31.8) : quai noté sur la carte du continent quand on est à bord
    if not d.boatsChecked4 and C_Map and C_Map.GetMapInfo then
        d.boatsChecked4 = true
        for i = #d.boats, 1, -1 do
            for _, q in ipairs({ d.boats[i].a, d.boats[i].b }) do
                local ok, info = pcall(C_Map.GetMapInfo, q and q.map)
                if ok and info and info.mapType and info.mapType <= 2 then table.remove(d.boats, i) break end
            end
        end
    end
    return d.boats
end
local ride, lastS
local function epoch() return (GetServerTime and GetServerTime()) or time() end
-- journal des traversées (/wk bateau) : début, fin et raison d'un refus ; 12 dernières lignes
M.boatLog = {}
local function blog(msg)
    table.insert(M.boatLog, date("%H:%M:%S") .. "  " .. msg)
    while #M.boatLog > 12 do table.remove(M.boatLog, 1) end
end
M.BoatLog = blog
local function zoneName(map)
    local R = WK.modules.Rares
    local ok, n = pcall(function() return R and R:ZoneName(map) end)
    return (ok and n) or (GetZoneText and GetZoneText()) or "?"
end
local function dock(p)
    local map, x, y = p.map, p.x, p.y
    -- à bord, le jeu peut donner la carte du continent : on prend la zone sous le perso
    local ok, info = pcall(C_Map.GetMapInfo, map)
    if ok and info and info.mapType and info.mapType <= 2 and C_Map.GetMapInfoAtPosition then
        local ok2, sub = pcall(C_Map.GetMapInfoAtPosition, map, x, y)
        if ok2 and sub and sub.mapID and sub.mapID ~= map and CreateVector2D then
            local ok3, _, pos = pcall(C_Map.GetMapPosFromWorldPos, p.cont, CreateVector2D(p.wx, p.wy), sub.mapID)
            if ok3 and pos then
                local mx, my = pos.x, pos.y
                if pos.GetXY then mx, my = pos:GetXY() end
                if mx and my then map, x, y = sub.mapID, mx, my end
            end
        end
    end
    return { map = map, x = floor(x * 10000) / 100, y = floor(y * 10000) / 100, name = zoneName(map), c = p.cont, wx = floor(p.wx), wy = floor(p.wy) }
end
local learnRide
local function endRide(endP, arr)
    local r = ride
    ride = nil
    if not (r and endP and endP.cont) then return end
    -- horaires (Modules/BoatTimes.lua) : départ et arrivée de cette traversée, une fois la ligne connue
    local function learn()
        local BT = WK.modules.BoatTimes
        if BT and r.t0 then pcall(BT.Learn, BT, dock(r.start), dock(endP), r.t0, arr) end
    end
    learnRide(r, endP, learn)
end
learnRide = function(r, endP, learn)
    local len = lineLen(r.pts)
    if not r.crossed and len < 150 then blog(string.format("fin : trop court (%d m)", len)) return end
    local a, b = dock(r.start), dock(endP)
    if not validBoat(a, b) then blog(string.format("fin : refusé (%s » %s, %s)", tostring(a.name), tostring(b.name), a.c ~= b.c and "autre continent" or "même zone ou moins de 500 m")) return end
    if knownRoute(a, b) then blog(string.format("fin : trajet connu %s » %s, horaires notés", tostring(a.name), tostring(b.name))); learn() return end
    blog(string.format("fin : %s » %s (%d m)", tostring(a.name), tostring(b.name), len))
    local boats = M:Boats()
    local path = { c = r.start.cont, pts = simplify(r.pts, 6) }
    for i = 1, #path.pts do path.pts[i] = floor(path.pts[i] + 0.5) end
    -- même trajet (dans un sens ou dans l'autre) : on met à jour
    for _, e in ipairs(boats) do
        local same = (e.a.c == a.c and dist(e.a.wx, e.a.wy, a.wx, a.wy) < 150 and e.b.c == b.c and dist(e.b.wx, e.b.wy, b.wx, b.wy) < 250)
        local rev = (e.b.c == a.c and dist(e.b.wx, e.b.wy, a.wx, a.wy) < 150 and e.a.c == b.c and dist(e.a.wx, e.a.wy, b.wx, b.wy) < 250)
        if same or rev then
            if same and (#path.pts > #(e.path and e.path.pts or {})) then e.path = path end
            learn()
            return
        end
    end
    table.insert(boats, { kind = "boat", a = a, b = b, path = path })
    graphs = {}
    learn()
    WK:Print(string.format(T("Nouveau trajet en bateau appris : %s » %s."), a.name, b.name))
    if WK.UI.RefreshMapLayers then WK.UI:RefreshMapLayers() end
end
local function rideTick()
    -- les traversées (horaires, tracés des lignes prises) ne dépendent pas de « Apprendre les chemins »,
    -- qui ne parle que des chemins à pied ou à monture
    M.rideOff = nil
    local p = Gd():PlayerPos()
    if not (p and p.cont) then return end
    local now = GetTime()
    local taxi = (UnitOnTaxi and UnitOnTaxi("player")) or (IsFlying and IsFlying())
    if lastS then
        local dt = now - lastS.t
        if lastS.cont ~= p.cont then
            -- écran de chargement pendant le trajet : le bateau continue jusqu'au quai de l'autre continent ;
            -- la traversée se termine quand il s'y arrête (vraie heure d'arrivée, vrai quai)
            if ride then
                ride.crossed, ride.last, ride.still = true, p, 0
                blog("chargement : autre continent, suite de la traversée")
            else blog("changement de continent sans traversée repérée") end
        elseif dt > 0 then
            local v = dist(p.wx, p.wy, lastS.wx, lastS.wy) / dt
            local moving = (IsPlayerMoving and IsPlayerMoving()) or (GetUnitSpeed and (GetUnitSpeed("player") or 0) > 0 and not IsPlayerMoving)
            -- porté par un transport : immobile et la position avance ; ou, même en marchant sur le pont,
            -- la position avance bien plus vite que le perso ne peut courir
            local own = GetUnitSpeed and GetUnitSpeed("player") or 7
            local carried = (not moving and v > 3) or (v > math.max(12, (own or 7) * 1.6))
            if not taxi and carried and v < 80 then
                if not ride then
                    ride = { start = lastS, pts = { lastS.wx, lastS.wy }, still = 0, t0 = epoch() - (now - lastS.t) }
                    blog(string.format("début : %s (%.0f m/s)", zoneName(lastS.map), v))
                end
                -- le tracé reste sur le continent du départ (coordonnées d'un seul continent)
                if p.cont == ride.start.cont then ride.pts[#ride.pts + 1] = p.wx; ride.pts[#ride.pts + 1] = p.wy end
                ride.still, ride.last = 0, p
            elseif ride then
                ride.still = ride.still + dt
                -- il descend du bateau, ou le bateau est à quai depuis un moment
                if moving or taxi or ride.still > 8 then
                    blog(moving and "arrêt : le perso bouge" or taxi and "arrêt : vol" or "arrêt : immobile 8 s")
                    endRide(ride.last, epoch() - ride.still)
                end
            end
        end
    end
    lastS = { cont = p.cont, wx = p.wx, wy = p.wy, map = p.map, x = p.x, y = p.y, t = now }
end
M.IsRiding = function() return ride ~= nil end
-- /wk bateau : état de la détection et journal des traversées
function M:BoatDiag()
    local out = {}
    local p = Gd():PlayerPos()
    local BT = WK.modules.BoatTimes
    table.insert(out, string.format("apprentissage : %s · position : %s · en traversée : %s · bateaux appris : %d · horaires reçus : %d (partage %s)",
        "actif", p and p.cont and (zoneName(p.map) .. " / continent " .. tostring(p.cont)) or "inconnue",
        ride and "oui" or "non", #M:Boats(), BT and BT.received or 0, cfg().boatShare == false and "coupé" or "actif"))
    for _, l in ipairs(M.boatLog) do table.insert(out, l) end
    if #M.boatLog == 0 then table.insert(out, "rien de noté depuis la connexion") end
    return out
end

WK:On("PLAYER_LOGOUT", function() M:EndTrail() end)
WK:On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.5, function() pcall(rideTick); pcall(learnTick) end)
    end
end)

function M:Forget()
    cur = nil
    data().trails = {}
    data().boats = {}
    graphs = {}
    nLearned = 0
    if Gd().target then self:Plan(Gd().target) end
end
-- Longueurs (m) : chemins appris, chemins de base (continent du perso)
function M:Stats()
    local learned = 0
    for _, list in pairs(data().trails) do for _, t in ipairs(list) do learned = learned + lineLen(t) end end
    local cont = playerWorld()
    local roads = 0
    if cont then
        local ok, g = pcall(graph, cont)
        if ok and g then roads = g.roadLen end
    end
    return learned, roads
end
M.Dist, M.LineLen = dist, lineLen
M.Simplify = function(pts, tol) return simplify(pts, tol) end

function M:Report()
    local learned, roads = self:Stats()
    local r = self.route
    local legs = {}
    for _, l in ipairs(r and r.legs or {}) do
        table.insert(legs, l.kind == "walk" and string.format("%s %d m", T("marche"), floor(l.len or 0)) or l.kind)
    end
    WK:Print("  " .. T("Navigation") .. " : " .. string.format(T("%.1f km appris, %.1f km de base"), learned / 1000, roads / 1000)
        .. " · " .. T("trajet") .. " : " .. (r and table.concat(legs, " > ") or T("aucun")))
end

-- accès pour les tests
M._compute, M._learnTick = compute, function() learnTick() end
M._rideTick = function() rideTick() end
