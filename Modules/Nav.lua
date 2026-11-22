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
local OFF = 3.0        -- coût d'un mètre hors des chemins connus (2,0 avant : trop de lignes droites à travers champs)
local LEARNED = 0.8    -- un chemin appris est sûr (tu y es passé) : nettement préféré
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

-- Construction étalée : dans une coroutine (calcul de trajet, construction de fond), la main est rendue au jeu
-- dès qu'on a travaillé env. 6 ms ; hors coroutine, d'une traite. Avant, le graphe d'un continent (env. 8800
-- points de chemins + les chemins appris) était construit d'un bloc : saccade à la connexion et à chaque
-- changement de continent.
local yieldAt
local function maybeYield()
    if not coroutine.running() then return end
    local t = _G.debugprofilestop and _G.debugprofilestop()
    if not t then return end
    if not yieldAt then yieldAt = t return end
    if t - yieldAt > 6 then coroutine.yield(); yieldAt = _G.debugprofilestop() end
end
local graphGen = 0 -- monte à chaque oubli des graphes (un graphe construit pendant ce temps est jeté)
local function build(cont)
    local gen = graphGen
    local g = newGraph()
    local G = Gd()
    yieldAt = nil
    for map, lines in pairs(WK.RoadsDB or {}) do
        if mapCont(map) == cont then
            for _, line in ipairs(lines) do
                maybeYield()
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
        maybeYield()
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
        if i % 200 == 0 then maybeYield() end
        near(g, g.X[i], g.Y[i], JOIN, function(j, d) if j > i then link(g, i, j, d * 1.1) end end)
    end
    if gen == graphGen then graphs[cont] = g end
    return g
end
-- construction de fond (apprentissage des chemins : jamais d'un bloc hors coroutine)
local building = {}
local buildFailed = {} -- continent -> heure de l'échec : pas de nouvel essai avant 60 s
local bgFrame
local function buildInBackground(cont)
    if graphs[cont] or building[cont] then return end
    local now = _G.GetTime and _G.GetTime() or 0
    if buildFailed[cont] and now - buildFailed[cont] < 60 then return end
    building[cont] = coroutine.create(function() build(cont) end)
    if not bgFrame then
        bgFrame = _G.CreateFrame("Frame")
        bgFrame:SetScript("OnUpdate", function(s)
            local c, co = next(building) -- un continent à la fois
            if not c then s:Hide() return end
            local ok, err = false, nil
            if coroutine.status(co) ~= "dead" then ok, err = coroutine.resume(co) end
            if not ok and err then
                -- erreur dans la construction (donnée de chemin abîmée) : notée au journal, et pas relancée en
                -- boucle (avant : avalée sans trace et relancée toutes les 0,5 s)
                if WK.RecordError then pcall(WK.RecordError, err, "", "Nav:build") end
                buildFailed[c] = _G.GetTime and _G.GetTime() or 0
            end
            if not ok or coroutine.status(co) == "dead" then building[c] = nil end
        end)
    end
    bgFrame:Show()
end
local function graph(cont)
    if graphs[cont] then return graphs[cont] end
    -- dans une coroutine (calcul de trajet) : une seule construction, celle de fond, qu'on attend (avant, le calcul
    -- et l'apprentissage des chemins pouvaient construire le même continent en même temps)
    if coroutine.running() then
        buildInBackground(cont)
        while building[cont] and not graphs[cont] do coroutine.yield() end
        if graphs[cont] then return graphs[cont] end
        -- la construction de fond vient d'échouer : pas de seconde construction tout de suite (avant, le
        -- calcul en relançait une aussitôt, vouée au même échec)
        if buildFailed[cont] then return nil end
    end
    return build(cont)
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
    -- réseau de ce continent en échec depuis moins de 60 s : ligne droite (avant, chaque calcul refaisait une
    -- construction complète vouée à échouer)
    local failedAt = buildFailed[cont]
    if failedAt and (_G.GetTime and _G.GetTime() or 0) - failedAt < 60 then return { sx, sy, tx, ty } end
    local g = graph(cont)
    if not g then return { sx, sy, tx, ty } end
    local START = 0
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
    -- mètres hors des chemins connus sur ce trajet (/wk nav) : dernier bout vers le but, sauts, départ
    local offLen = goalFrom == START and D or dist(g.X[goalFrom], g.Y[goalFrom], tx, ty)
    while i and i ~= START do
        rev[#rev + 1] = g.X[i]; rev[#rev + 1] = g.Y[i]
        local j = from[i]
        local px, py
        if j == START then px, py = sx, sy else px, py = g.X[j], g.Y[j] end
        local d = dist(g.X[i], g.Y[i], px, py)
        local c = best[i] - (j == START and 0 or best[j])
        if d > 1 and c >= d * OFF * 0.99 then offLen = offLen + d end
        i = j
    end
    M.lastOff = offLen
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
-- carte des vols « classique » : relais lus un par un (nom, genre, position via Flight:NodeWorld)
local function classicTaxi()
    local F = WK.modules.Flight
    if not (NumTaxiNodes and TaxiNodeName and F and F.NodeWorld) then return end
    local known = myTaxi()
    for i = 1, NumTaxiNodes() do
        local ty = TaxiNodeGetType and TaxiNodeGetType(i)
        local name = TaxiNodeName(i)
        if name and ty ~= "NONE" and ty ~= "DISTANT" then
            local w = F:NodeWorld(i)
            if w then known[name] = { w[1], floor(w[2]), floor(w[3]) } end
        end
    end
end
WK:On("TAXIMAP_OPENED", function()
    local mapID = GetTaxiMapID and GetTaxiMapID()
    local ok, nodes = false, nil
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and mapID then ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID) end
    if not ok or type(nodes) ~= "table" or #nodes == 0 then return C_Timer.After(0.1, classicTaxi) end
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
-- les n relais connus les plus proches d'un point : { { n = relais, d = distance, name } }
local function nearestTaxis(cont, x, y, count)
    local list = {}
    for name, n in pairs(myTaxi()) do
        if n[1] == cont then list[#list + 1] = { n = n, d = dist(x, y, n[2], n[3]), name = name } end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    for i = #list, (count or 3) + 1, -1 do list[i] = nil end
    return list
end
M.NearestTaxis = nearestTaxis
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
WK:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(unit, _, spellID)
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

-- Tram des profondeurs (Hurlevent <-> Forgefer, même continent) : ses deux stations sont apprises en le prenant
-- (dernière position dehors avant l'instance du tram, première position dehors après) : nav.tramSt = { {c,x,y}, ... }
-- (« nav.tram » était l'ancien horaire, effacé à la connexion par BoatLines). Proposé quand il bat la marche.
local TRAM_RIDE = 75 -- trajet dans le tunnel, montée et descente comprises
local function tramStations()
    local n = WK.DB.global.nav
    n.tramSt = n.tramSt or {}
    return n.tramSt
end
M.TramStations = tramStations
local function noteStation(c, x, y)
    if not c then return end
    local st = tramStations()
    for _, p in ipairs(st) do
        if p[1] == c and dist(p[2], p[3], x, y) < 250 then p[2], p[3] = floor(x), floor(y) return end
    end
    if #st >= 2 then table.remove(st, 1) end
    st[#st + 1] = { c, floor(x), floor(y) }
end
M.NoteTramStation = noteStation
do
    local inside, lastOut, exitAt, lastCity
    local TRAM_CITY, TRAM_JUMP = { [1453] = "sw", [1455] = "if" }, 210
    local function tick()
        local BL = WK.modules.BoatLines
        local now = BL and BL.InTram and BL:InTram()
        if now then
            if not inside and lastOut then noteStation(lastOut[1], lastOut[2], lastOut[3]) end
            inside, exitAt = true, nil
            return
        end
        local c, x, y = playerWorld()
        local t = _G.GetTime()
        if inside then
            inside = false; exitAt = t
        end
        if c then
            if exitAt and t - exitAt < 20 then noteStation(c, x, y); exitAt = nil end
            lastOut = { c, x, y }
            -- WoW Forever peut faire du tram un simple tunnel (ni instance ni zone à son nom) : passer de
            -- Hurlevent à Forgefer (ou l'inverse) en moins de TRAM_JUMP s, sans vol ni téléport, c'est le tram.
            -- Les stations = dernier point lisible dans la 1re ville, premier dans l'autre.
            local map = _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")
            local city = TRAM_CITY[map or 0]
            local taxi = _G.UnitOnTaxi and _G.UnitOnTaxi("player")
            if taxi or pendingPort then lastCity = nil
            elseif city then
                if lastCity and lastCity.city ~= city and t - lastCity.t < TRAM_JUMP then
                    noteStation(lastCity.c, lastCity.x, lastCity.y)
                    noteStation(c, x, y)
                end
                lastCity = { city = city, c = c, x = x, y = y, t = t }
            end
        end
    end
    M._tramTick = tick -- (pour les tests)
    if _G.C_Timer and _G.C_Timer.NewTicker then
        WK:On("PLAYER_LOGIN", function() _G.C_Timer.NewTicker(1, tick) end)
    end
end

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
    local opts = portOptions()
    local why = { n = #opts, base = base }
    for _, o in ipairs(opts) do
        if o.pc == tc then
            local cost = PORT_COST + dist(o.px, o.py, tx, ty) * 1.25 / speed()
            why.cost = math.min(why.cost or cost, cost)
            if cost < base * 0.75 and base - cost > 60 and (not bestCost or cost < bestCost) then best, bestCost = o, cost end
        end
    end
    why.used = best and best.label or nil
    M.lastPort = why
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
                    side = best.line and (best.here == best.line.a and "a" or "b"),
                    here = best.here, there = best.there } -- quais (carte, x, y) : traversée dessinée sur la carte d'Azeroth
        return { legs = legs, cont = cont, partial = true }
    end
    local D = dist(sx, sy, tx, ty)
    local pts = walk(cont, sx, sy, tx, ty, 4)
    local walkLen = lineLen(pts)
    local v = speed()
    local walkTime = walkLen / v
    -- un vol connu fait-il gagner du temps ?
    -- (avant : vol proposé seulement si les deux relais étaient à moins de 60 % de la distance en tout ; depuis le
    -- milieu des Paluns, Menethil était trop loin et le guidage faisait marcher jusqu'à Forgefer). Maintenant :
    -- les 3 relais connus les plus proches du départ et de l'arrivée, la paire la plus rapide, si elle bat la marche
    local flyPick
    if D > 1500 then
        local fs = (WK.DB.global.flights and WK.DB.global.flights.worldSpeed) or FLY_SPEED
        local A, B, an, bn, flyLen, estimate
        local starts, ends = nearestTaxis(cont, sx, sy, 3), nearestTaxis(cont, tx, ty, 3)
        local learned = WK.DB.global.flights and WK.DB.global.flights.routes or {}
        for _, a in ipairs(starts) do
            for _, b in ipairs(ends) do
                if a.name ~= b.name then
                    local fl = dist(a.n[2], a.n[3], b.n[2], b.n[3])
                    -- durée du vol déjà faite si on la connaît (le vrai trajet passe par des relais), sinon estimée
                    local ft = tonumber(learned[a.name .. "|" .. b.name]) or (fl * 1.15 / fs)
                    local e = (a.d + b.d) * 1.3 / v + ft + 25
                    if not estimate or e < estimate then
                        A, B, an, bn, flyLen, estimate = a.n, b.n, a.name, b.name, fl, e
                    end
                end
            end
        end
        M.lastFly = { known = 0, starts = #starts, ends = #ends, est = estimate, walk = walkTime, from = an, to = bn }
        for _, n in pairs(myTaxi()) do if n[1] == cont then M.lastFly.known = M.lastFly.known + 1 end end
        if A and B and estimate < walkTime * 0.8 then
            flyPick = { A = A, B = B, an = an, bn = bn, len = flyLen, est = estimate, fs = fs }
        end
    end
    if D <= 1500 then M.lastFly = { short = true, walk = walkTime } end
    -- tram des profondeurs : stations apprises, même continent ; gardé s'il bat la marche de 20 % et d'une minute
    local st = tramStations()
    if #st == 2 and st[1][1] == cont and st[2][1] == cont then
        local A, B = st[1], st[2]
        local ab = dist(sx, sy, A[2], A[3]) + dist(tx, ty, B[2], B[3])
        if ab > dist(sx, sy, B[2], B[3]) + dist(tx, ty, A[2], A[3]) then
            A, B = B, A
        end
        local guess = (dist(sx, sy, A[2], A[3]) + dist(B[2], B[3], tx, ty)) * 1.3 / v + TRAM_RIDE
        M.lastTram = { guess = guess, walk = walkTime, fly = flyPick and flyPick.est }
        -- le tram gagne aussi contre un vol plus lent (Hurlevent <-> Forgefer : le tram est bien plus court)
        if guess < walkTime * 0.8 and walkTime - guess > 60 and not (flyPick and flyPick.est <= guess) then
            local p1 = walk(cont, sx, sy, A[2], A[3], 4)
            local p2 = walk(cont, B[2], B[3], tx, ty, 4)
            -- Forgefer est au nord de Hurlevent (x monde = nord)
            local nameA = A[2] > B[2] and T("Forgefer") or T("Hurlevent")
            local nameB = A[2] > B[2] and T("Hurlevent") or T("Forgefer")
            legs[1] = { kind = "walk", pts = p1, len = lineLen(p1) }
            legs[2] = { kind = "tram", from = nameA, to = nameB, ax = A[2], ay = A[3], bx = B[2], by = B[3] }
            legs[3] = { kind = "walk", pts = p2, len = lineLen(p2) }
            return { legs = legs, cont = cont, seconds = (legs[1].len + legs[3].len) / v + TRAM_RIDE }
        end
    else
        M.lastTram = { stations = #st }
    end
    if flyPick then
        local f = flyPick
        local p1 = walk(cont, sx, sy, f.A[2], f.A[3], 4)
        local p2 = walk(cont, f.B[2], f.B[3], tx, ty, 4)
        legs[1] = { kind = "walk", pts = p1, len = lineLen(p1) }
        legs[2] = { kind = "fly", from = f.an, to = f.bn, ax = f.A[2], ay = f.A[3], bx = f.B[2], by = f.B[3],
                    len = f.len }
        legs[3] = { kind = "walk", pts = p2, len = lineLen(p2) }
        return { legs = legs, cont = cont, seconds = (legs[1].len + legs[3].len) / v + f.len * 1.15 / f.fs + 25 }
    end
    legs[1] = { kind = "walk", pts = pts, len = walkLen }
    return { legs = legs, cont = cont, seconds = walkTime }
end

-- Calcul en arrière-plan (quelques ms par image) ; le trajet précédent reste affiché en attendant
local runner
-- Trajet raté (erreur, position illisible au départ : chargement, ville, instance) ou calculé pour un continent
-- qu'on a quitté pendant le calcul : nouvel essai quelques secondes plus tard, 5 fois au plus par cible (avant, le
-- guidage restait à vol d'oiseau jusqu'au prochain changement de cible)
local function retryLater(target, secs)
    target.navTries = (target.navTries or 0) + 1
    if target.navTries > 5 or not _G.C_Timer then return end
    _G.C_Timer.After(secs, function()
        if Gd().target == target and not job and not (M.route and M.route.target == target) then M:Plan(target) end
    end)
end
local function pump()
    if not job then runner:Hide() return end
    local ok, res = coroutine.resume(job.co)
    if not ok then
        local target = job.target
        job = nil; runner:Hide()
        if WK.RecordError then pcall(WK.RecordError, res, "", "Nav:Plan") end
        if target and Gd().target == target then retryLater(target, 5) end
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
            local cont = playerWorld()
            if cont and res.cont and cont ~= res.cont then M.route = nil; M:Plan(target) return end
        else
            retryLater(target, 5)
            -- recalcul raté vers la même cible (écart, position illisible un instant) : le bon trajet est gardé
            if M.route and M.route.target == target then return end
        end
        M.route = res
        -- un seul redessin (RefreshNavRoute redessine la carte via Guide:Redraw)
        if WK.UI.RefreshNavRoute then WK.UI:RefreshNavRoute() elseif Gd().Redraw then Gd():Redraw() end
    end
end
function M:Plan(target)
    if not target then return end
    if not runner then
        runner = CreateFrame("Frame")
        runner:SetScript("OnUpdate", pump)
    end
    -- nouvelle cible : l'ancien trajet est oublié tout de suite (sinon, pendant le calcul, sa distance restante,
    -- presque nulle juste après une arrivée, servait pour la nouvelle cible : faux « Arrivé » et guidage arrêté) ;
    -- un recalcul vers la même cible (écart) garde l'ancien trajet en attendant
    if M.route and M.route.target ~= target then M.route = nil end
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
-- Point visé maintenant (monde) et texte de l'étape : x, y, texte, distance restante (m).
-- Gardé 0,1 s : l'épingle (env. 33 fois par seconde) et la flèche (20 fois) le demandaient chacune, avec à chaque
-- fois la somme de toute la longueur restante du trajet.
local wpCache = { at = -10 }
function M:Waypoint()
    local now = _G.GetTime and _G.GetTime() or 0
    local c = wpCache
    if c.route == self.route and now - c.at < 0.1 and now >= c.at then return c[1], c[2], c[3], c[4] end
    local a, b, t, d = self:WaypointNow()
    c.route, c.at, c[1], c[2], c[3], c[4] = self.route, now, a, b, t, d
    return a, b, t, d
end
function M:WaypointNow()
    local r = self.route
    if not r or not r.legs[r.leg] then return nil end
    -- dans le tram (pas de position lisible) : le trajet passe à l'étape « tram » et le dit
    local BL = WK.modules.BoatLines
    if BL and BL.InTram and BL:InTram() then
        for k = r.leg, math.min(#r.legs, r.leg + 1) do
            local l = r.legs[k]
            if l.kind == "tram" then
                if r.leg ~= k then r.leg, r.idx = k, 1 end
                return nil, nil, string.format(T("Tram des profondeurs » %s"), l.to or "?"), nil
            end
        end
    end
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
            return self:WaypointNow()
        end
        local nextLeg = r.legs[r.leg + 1]
        local text
        if nextLeg and nextLeg.kind == "fly" then text = string.format(T("Vers le maître de vol (%s)"), nextLeg.from)
        elseif nextLeg and nextLeg.kind == "tram" then text = T("Vers le tram des profondeurs")
        elseif nextLeg then
            text = string.format(T("Vers le quai : %s"), nextLeg.from or "?")
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
            return self:WaypointNow()
        end
        -- avant, cette étape n'était jamais recalculée : sans pierre prise, le guidage restait sur « prête ».
        -- Éloigné de plus de 300 m du début de l'étape sans être en vol : nouveau calcul, une fois par écart
        if not leg.sx then leg.sx, leg.sy = px, py end
        if not leg.replanned and not (_G.UnitOnTaxi and _G.UnitOnTaxi("player")) and r.target
            and dist(px, py, leg.sx, leg.sy) > 300 then
            leg.replanned = true; lastReplan = _G.GetTime()
            M:Plan(r.target)
        end
        return nil, nil, leg.label .. "  ·  " .. T("prête"), nil
    elseif leg.kind == "tram" then
        -- sorti du tram près de la station d'arrivée : étape suivante ; parti ailleurs : nouveau calcul
        if dist(px, py, leg.bx, leg.by) < 150 then
            r.leg, r.idx = r.leg + 1, 1
            return self:WaypointNow()
        end
        if not leg.sx then leg.sx, leg.sy = px, py end
        if not leg.replanned and r.target and dist(px, py, leg.sx, leg.sy) > 300
            and dist(px, py, leg.ax, leg.ay) > 300 then
            leg.replanned = true; lastReplan = _G.GetTime()
            M:Plan(r.target)
        end
        return leg.ax, leg.ay, string.format(T("Tram des profondeurs » %s"), leg.to or "?"), nil
    elseif leg.kind == "fly" then
        local onTaxi = _G.UnitOnTaxi and _G.UnitOnTaxi("player")
        if onTaxi then leg.flew = true end
        -- arrivé près du point d'atterrissage : étape suivante
        if dist(px, py, leg.bx, leg.by) < 80 and not onTaxi then
            r.leg, r.idx = r.leg + 1, 1
            return self:WaypointNow()
        end
        -- avant, cette étape n'était jamais recalculée : posé ailleurs qu'au relais prévu (ou vol pas pris, parti
        -- à plus de 300 m du maître de vol), le guidage restait sur le vol. Maintenant : posé à moins de 300 m du
        -- relais = étape suivante ; plus loin, ou vol pas pris, nouveau calcul (une fois par écart)
        if not onTaxi and not leg.replanned and r.target then
            if not leg.sx then leg.sx, leg.sy = px, py end
            local fromB = dist(px, py, leg.bx, leg.by)
            if leg.flew and fromB <= 300 then
                r.leg, r.idx = r.leg + 1, 1
                return self:WaypointNow()
            end
            if (leg.flew and fromB > 300) or (not leg.flew and dist(px, py, leg.sx, leg.sy) > 300) then
                leg.replanned = true; lastReplan = _G.GetTime()
                M:Plan(r.target)
            end
        end
        return leg.ax, leg.ay, string.format(T("Vol : %s » %s"), leg.from, leg.to), nil
    else
        local txt = string.format(T("Prends le %s pour %s"), leg.kind == "zeppelin" and T("zeppelin") or T("bateau"), leg.to or "?")
        return nil, nil, txt, nil
    end
end

-- Étape intermédiaire en cours (station du tram, maître de vol, quai) : point de carte { map, x, y } (0-1) où poser
-- le repère du jeu à la place de la cible finale, pour que l'épingle à l'écran y mène ; nil à la dernière étape
function M:StepTarget()
    local r = self.route
    local leg = r and r.legs and r.legs[r.leg]
    if not leg then return nil end
    local wx, wy
    if leg.kind == "walk" then
        local nxt = r.legs[r.leg + 1]
        if not nxt or nxt.kind == "port" then return nil end
        local n = #leg.pts / 2
        if n < 1 then return nil end
        wx, wy = leg.pts[n * 2 - 1], leg.pts[n * 2]
    elseif leg.kind == "tram" then
        wx, wy = leg.bx, leg.by -- étape tram en cours = on est monté : la station d'arrivée
    elseif leg.kind == "fly" then
        -- au maître de vol : lui ; en vol : le relais d'arrivée
        if _G.UnitOnTaxi and _G.UnitOnTaxi("player") then wx, wy = leg.bx, leg.by else wx, wy = leg.ax, leg.ay end
    else
        return nil
    end
    r.stepT = r.stepT or {}
    local key = r.leg .. ":" .. floor(wx) .. ":" .. floor(wy)
    local st = r.stepT[key]
    if st == nil then
        local BL = WK.modules.BoatLines
        local map, x, y
        if BL and BL.ToMap and wx then map, x, y = BL:ToMap(r.cont, wx, wy) end
        st = map and { map = map, x = x / 100, y = y / 100, cont = r.cont, wx = wx, wy = wy, step = true } or false
        r.stepT[key] = st
    end
    return st or nil
end

-- Vol prévu par le trajet en cours (étape de vol en cours ou juste après la marche vers le maître de vol) :
-- { from, to } (noms des relais de la carte des vols), sinon nil
function M:PlannedFlight()
    local r = M.route
    if not (r and r.legs and r.leg) then return nil end
    for j = r.leg, math.min(#r.legs, r.leg + 1) do
        local l = r.legs[j]
        if l and l.kind == "fly" then return l end
    end
end

-- Changement de continent (bateau, zeppelin, portail) : on recalcule depuis le nouveau continent
WK:On("ZONE_CHANGED_NEW_AREA", function()
    local r = M.route
    if r and r.target then
        local cont = playerWorld()
        if cont and cont ~= r.cont then M:Plan(r.target) end
    elseif Gd().target and not job then
        -- pas de trajet (calcul raté au départ) : nouvel essai à l'arrivée dans la zone
        M:Plan(Gd().target)
    end
end)

---------------------------------------------------------------------------
-- Apprentissage des chemins
---------------------------------------------------------------------------
local cur -- tronçon en cours : { cont, pts, lastX, lastY }
local function novel(cont, x, y)
    local g = graphs[cont]
    if not g then
        -- graphe pas encore prêt : construit en fond, ce point n'est pas appris (le suivant le sera)
        buildInBackground(cont)
        return false
    end
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
        M.sessionLearned = (M.sessionLearned or 0) + lineLen(t.pts)
        M.sessionTrails = (M.sessionTrails or 0) + 1
        M.lastTrailAt = GetTime and GetTime() or 0
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
-- Depuis 1.128.96 : un bateau appris doit changer de continent. Les vraies lignes du même continent sont dans
-- les fichiers du jeu (Modules/BoatLines.lua) ; ce qui restait (Hurlevent » Forêt d'Elwynn…) était un autre
-- déplacement sans bouger (monture d'escorte, véhicule de quête, téléport lent) pris pour un bateau.
local function validBoat(a, b)
    if not (a and b) then return false end
    return a.c ~= nil and b.c ~= nil and a.c ~= b.c
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
    -- sont oubliés : la ligne du jeu les remplace (tracé, quais)
    if not d.boatsChecked5 and WK.BoatLines and #WK.BoatLines > 0 then
        d.boatsChecked5 = true
        for i = #d.boats, 1, -1 do if knownRoute(d.boats[i].a, d.boats[i].b) then table.remove(d.boats, i) end end
    end
    -- une fois (1.128.96) : bateaux appris sur un même continent oubliés (faux trajets, voir validBoat)
    if not d.boatsChecked6 then
        d.boatsChecked6 = true
        for i = #d.boats, 1, -1 do if not validBoat(d.boats[i].a, d.boats[i].b) then table.remove(d.boats, i) end end
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
    local BLm = WK.modules.BoatLines
    if BLm and BLm.RideEnd then pcall(BLm.RideEnd, BLm) end
    if not (r and endP and endP.cont) then return end
    -- ligne du jeu prise (Modules/BoatLines.lua) : notée pour la carte
    local function learn()
        local BT = WK.modules.BoatTimes
        if BT then pcall(BT.Learn, BT, dock(r.start), dock(endP)) end
    end
    learnRide(r, endP, learn)
end
learnRide = function(r, endP, learn)
    local len = lineLen(r.pts)
    if not r.crossed and len < 150 then blog(string.format("fin : trop court (%d m)", len)) return end
    local a, b = dock(r.start), dock(endP)
    if not validBoat(a, b) then blog(string.format("fin : refusé (%s » %s, %s)", tostring(a.name), tostring(b.name), "même continent")) return end
    if knownRoute(a, b) then blog(string.format("fin : trajet connu %s » %s", tostring(a.name), tostring(b.name))); learn() return end
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
    graphs = {}; graphGen = graphGen + 1; building = {}
    learn()
    WK:Print(string.format(T("Nouveau trajet en bateau appris : %s » %s."), a.name, b.name))
    if WK.UI.RefreshMapLayers then WK.UI:RefreshMapLayers() end
end
local function rideTick()
    -- les traversées (lignes prises, bandeau à bord) ne dépendent pas de « Apprendre les chemins »,
    -- qui ne parle que des chemins à pied ou à monture
    M.rideOff = nil
    local p = Gd():PlayerPos()
    local now = GetTime()
    if not (p and p.cont) then
        -- position illisible (certaines villes, chargement) : au-delà de 15 s, la traversée est abandonnée
        -- (avant : elle ne finissait jamais et le bandeau « À bord » restait affiché à terre)
        if ride and now - (ride.lastOk or now) > 15 then
            blog("arrêt : position illisible depuis 15 s")
            ride = nil
            local BLm = WK.modules.BoatLines
            if BLm and BLm.RideEnd then pcall(BLm.RideEnd, BLm) end
        end
        return
    end
    if ride then
        ride.lastOk = now
        -- garde-fou : aucune traversée ne dure 20 min
        if now - (ride.started or now) > 1200 then
            blog("arrêt : traversée de plus de 20 min")
            endRide(ride.last, ride.moved)
        end
    end
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
            -- faux départs sur le ponton : le perso s'arrête juste avant la mesure, et la vitesse moyenne de
            -- son dernier pas (4 à 6 m/s) passait pour « porté ». Il faut maintenant deux mesures de suite,
            -- sans que le perso marchait à la précédente
            -- (la vitesse du perso est lue à la mesure d'avant aussi : à l'arrêt elle vaut 0, et la fin d'une
            -- course à monture passait pour un navire rapide)
            own = math.max(own or 0, lastS.own or 0)
            carried = (not moving and v > 3) or (v > math.max(12, own * 1.6))
            if carried and not ride and v < 30 then
                local cand = not lastS.moving
                if not (cand and lastS.cand) then
                    lastS = { cont = p.cont, wx = p.wx, wy = p.wy, map = p.map, x = p.x, y = p.y, t = now, moving = moving, cand = cand,
                        own = GetUnitSpeed and GetUnitSpeed("player") or 0 }
                    return
                end
            end
            if not taxi and carried and v < 80 then
                if not ride then
                    ride = { start = lastS, pts = { lastS.wx, lastS.wy }, still = 0, t0 = epoch() - (now - lastS.t), started = now, lastOk = now }
                    blog(string.format("début : %s (%.0f m/s)", zoneName(lastS.map), v))
                    local BLm = WK.modules.BoatLines
                    if BLm and BLm.RideBegin then BLm:RideBegin(); pcall(BLm.RideSample, BLm, lastS.cont, lastS.wx, lastS.wy) end
                end
                local BLs = WK.modules.BoatLines
                if BLs and BLs.RideSample then pcall(BLs.RideSample, BLs, p.cont, p.wx, p.wy) end
                -- le tracé reste sur le continent du départ (coordonnées d'un seul continent)
                if p.cont == ride.start.cont then ride.pts[#ride.pts + 1] = p.wx; ride.pts[#ride.pts + 1] = p.wy end
                ride.still, ride.last, ride.free = 0, p, 0
                ride.moved = epoch() -- dernier instant où le navire avançait (heure d'arrivée au quai)
            elseif ride and v >= 80 then
                -- téléport, pierre de foyer, mort : plus sur le navire
                blog("arrêt : téléporté")
                ride = nil
                local BLm = WK.modules.BoatLines
                if BLm and BLm.RideEnd then pcall(BLm.RideEnd, BLm) end
            elseif ride then
                -- plus porté depuis 15 s (descendu loin du quai, parti à pied ou à monture) : traversée finie
                ride.free = (ride.free or 0) + dt
                if ride.free > 15 then
                    blog("arrêt : plus porté depuis 15 s")
                    endRide(ride.last, ride.moved)
                    lastS = { cont = p.cont, wx = p.wx, wy = p.wy, map = p.map, x = p.x, y = p.y, t = now }
                    return
                end
                -- près d'un quai d'une ligne du jeu (ou d'un trajet appris) ?
                local BLm = WK.modules.BoatLines
                local dq
                if BLm then dq = select(3, BLm:StopNear(p.cont, p.wx, p.wy, 400)) end
                local atDock = dq ~= nil
                if taxi then
                    blog("arrêt : vol")
                    endRide(ride.last, ride.moved)
                elseif moving then
                    -- il marche : descendu au quai (près d'un quai et plus porté) ; en mer, il marche sur le
                    -- pont et la traversée continue (avant : elle s'arrêtait en pleine mer)
                    ride.still = 0
                    if atDock and v < (own or 7) + 2 then
                        blog("arrêt : descendu au quai")
                        endRide(ride.last, ride.moved)
                    end
                elseif v < 1.5 then
                    ride.still = ride.still + dt
                    -- le navire est à quai depuis un moment (ou immobile loin de tout quai : on abandonne)
                    if ride.still > 8 then
                        blog(atDock and "arrêt : à quai 8 s" or "arrêt : immobile 8 s")
                        endRide(ride.last, ride.moved or (epoch() - ride.still))
                    end
                end
            end
        end
    end
    lastS = { cont = p.cont, wx = p.wx, wy = p.wy, map = p.map, x = p.x, y = p.y, t = now,
        moving = (IsPlayerMoving and IsPlayerMoving()) or false, own = GetUnitSpeed and GetUnitSpeed("player") or 0 }
end
M.IsRiding = function() return ride ~= nil end
-- traversée sûre (bandeau « À bord ») : depuis 4 s au moins et à plus de 25 m du point de départ, ou après un
-- changement de continent ; une fausse traversée sur le ponton ne fait plus clignoter le bandeau
M.RideConfirmed = function()
    if not ride then return false end
    if ride.crossed then return true end
    local l = ride.last
    if not (l and ride.start and l.wx and ride.start.wx) then return false end
    return GetTime() - (ride.started or GetTime()) >= 4 and dist(l.wx, l.wy, ride.start.wx, ride.start.wy) >= 25
end
-- point de départ de la traversée en cours (continent, x, y) : le bandeau du quai y retrouve la ligne prise
M.RideStart = function() return ride and ride.start and ride.start.cont, ride and ride.start and ride.start.wx, ride and ride.start and ride.start.wy end
-- /wk bateau : état de la détection et journal des traversées
function M:BoatDiag()
    local out = {}
    local p = Gd():PlayerPos()
    table.insert(out, string.format("position : %s · en traversée : %s · bateaux appris : %d",
        p and p.cont and (zoneName(p.map) .. " / continent " .. tostring(p.cont)) or "inconnue", ride and "oui" or "non", #M:Boats()))
    -- quais des lignes du jeu les plus proches (le bandeau apparaît sous WK.UI.DockRange m)
    if p and p.cont and WK.modules.BoatLines then
        local BL = WK.modules.BoatLines
        local docks = {}
        for _, l in ipairs(BL:All()) do
            for si, st in ipairs(l.stops) do
                if st.c == p.cont then
                    table.insert(docks, { d = dist(st.x, st.y, p.wx, p.wy), txt = BL:StopName(l, si) .. " » " .. BL:StopName(l, si % #l.stops + 1)
                        .. (BL:Mine(l) and "" or " (autre faction)") })
                end
            end
        end
        table.sort(docks, function(a, b) return a.d < b.d end)
        local parts = {}
        for i = 1, math.min(4, #docks) do parts[i] = string.format("%s %d m", docks[i].txt, math.floor(docks[i].d + 0.5)) end
        table.insert(out, "quais proches : " .. (#parts > 0 and table.concat(parts, " · ") or "aucun sur ce continent")
            .. string.format(" · bandeau sous %d m", (WK.UI and WK.UI.DockRange) or 0))
    end
    if WK.modules.BoatLines and WK.modules.BoatLines.Diag then
        for _, l in ipairs(WK.modules.BoatLines:Diag()) do table.insert(out, "ligne · " .. l) end
    end
    for _, l in ipairs(M.boatLog) do table.insert(out, l) end
    if #M.boatLog == 0 then table.insert(out, "rien de noté depuis la connexion") end
    -- trajets appris en jeu : distance à leurs deux quais
    for _, b in ipairs(M:Boats()) do
        local parts = {}
        for _, e in ipairs({ b.a, b.b }) do
            if e then
                local d = (p and p.cont and e.c == p.cont and e.wx) and string.format(" %d m", math.floor(dist(e.wx, e.wy, p.wx, p.wy) + 0.5)) or ""
                parts[#parts + 1] = (e.name or "?") .. d
            end
        end
        table.insert(out, "appris : " .. table.concat(parts, " » "))
    end
    -- bandeau : dernières apparitions et leur raison (UI/DockBanner.lua)
    local dl = WK.UI and WK.UI.dockLog or {}
    if #dl == 0 then table.insert(out, "bandeau : pas affiché depuis la connexion") end
    for _, l in ipairs(dl) do table.insert(out, "bandeau · " .. l) end
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
    graphs = {}; graphGen = graphGen + 1; building = {}
    nLearned = 0
    if Gd().target then self:Plan(Gd().target) end
end
-- Longueurs (m) : chemins appris, chemins de base (continent du perso)
function M:Stats()
    local learned = 0
    for _, list in pairs(data().trails) do for _, t in ipairs(list) do learned = learned + lineLen(t) end end
    local cont = playerWorld()
    local roads = 0
    -- graphe pas encore prêt : pas construit d'un bloc ici (gel de l'écran), lancé en fond
    if cont then
        local g = graphs[cont]
        if g then roads = g.roadLen else buildInBackground(cont) end
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
    -- apprentissage : réglage, ce qui a été appris depuis la connexion, tronçon en cours, raison d'une pause
    local why = not cfg().learn and T("coupé (réglage)") or (not canLearn() and T("en pause (vol, bateau, instance ou mort)")) or T("actif")
    WK:Print("  " .. T("Apprentissage") .. " : " .. why .. " · " .. string.format(T("depuis la connexion : %d m en %d tronçon(s)"),
        floor(M.sessionLearned or 0), M.sessionTrails or 0)
        .. (M.lastTrailAt and (" · " .. string.format(T("dernier il y a %d s"), floor(GetTime() - M.lastTrailAt))) or "")
        .. (cur and (" · " .. string.format(T("tronçon en cours : %d points"), #cur.pts / 2)) or "")
        .. string.format(" · %d / %d", floor(learnedPoints()), MAX_LEARN))
    -- moyens de transport : pourquoi le vol, le tram ou la pierre de foyer ont été écartés au dernier calcul
    local function mmss(s) return s and string.format("%d:%02d", floor(s / 60), floor(s % 60)) or "-" end
    local fl = M.lastFly
    if fl and fl.short then
        WK:Print("  " .. T("Vol") .. " : " .. T("cible trop proche pour un vol"))
    elseif fl then
        WK:Print("  " .. T("Vol") .. " : " .. string.format(T("%d relais connus sur ce continent"), fl.known)
            .. (fl.from and (" · " .. string.format(T("meilleur %s » %s en %s contre %s à pied"), fl.from, fl.to or "?",
                mmss(fl.est), mmss(fl.walk)))
                or (" · " .. T("aucune paire de relais (ouvre la carte des vols chez un maître)"))))
    end
    local BL = WK.modules.BoatLines
    if BL and BL.TramInfo then
        local id, iname, zone, sub = BL:TramInfo()
        local map = _G.C_Map and _G.C_Map.GetBestMapForUnit and _G.C_Map.GetBestMapForUnit("player")
        WK:Print("  " .. T("Tram") .. " : " .. string.format(T("dans le tram : %s (instance %s « %s », zone « %s »)"),
            BL:InTram() and T("oui") or T("non"), tostring(id), iname, zone .. (sub ~= "" and (" / " .. sub) or ""))
            .. " · " .. T("carte") .. " " .. tostring(map))
    end
    local tr = M.lastTram
    if tr and tr.stations then
        WK:Print("  " .. T("Tram") .. " : "
            .. string.format(T("%d / 2 stations connues (prends le tram une fois)"), tr.stations))
    elseif tr then
        WK:Print("  " .. T("Tram") .. " : "
            .. string.format(T("%s par le tram contre %s à pied"), mmss(tr.guess), mmss(tr.walk)))
    end
    local c = hearthData()
    local pt = M.lastPort
    local unknown = T("lieu inconnu (utilise-la ou lie-la chez un aubergiste)")
    WK:Print("  " .. T("Pierre de foyer") .. " : " .. (c.hearth and (c.hearth.name or "?") or unknown)
        .. " · " .. (hearthReady() and T("prête") or T("en recharge ou absente"))
        .. (pt and (" · " .. string.format(T("%d moyen(s) prêt(s)"), pt.n)
            .. (pt.cost and (" · " .. string.format(T("%s par là contre %s"), mmss(pt.cost), mmss(pt.base))) or ""))
            or ""))
    local total = 0
    for _, l in ipairs(r and r.legs or {}) do if l.kind == "walk" then total = total + (l.len or 0) end end
    if r and M.lastOff then
        WK:Print("  " .. string.format(T("hors des chemins connus : env. %d m sur %d m de marche (en ligne droite, faute de chemin appris)"),
            floor(M.lastOff), floor(total)))
    end
end

-- accès pour les tests
M._compute, M._learnTick = compute, function() learnTick() end
M._computeFrom = function(...) return computeFrom(...) end -- tests
M._rideTick = function() rideTick() end
