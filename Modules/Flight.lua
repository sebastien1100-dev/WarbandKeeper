local ADDON_NAME, WK = ...
local M = WK:NewModule("Flight")
local T = function(s) return WK.T(s) end

-- Barre de vol : au départ d'un vol (maître de vol), trajet, temps restant et progression.
-- La durée d'un trajet est apprise au premier vol complet (partagée entre les persos). Avant ça,
-- elle est estimée en mètres du jeu : longueur du trajet (relais compris) et vitesse de vol apprise,
-- puis corrigée en vol d'après la distance réellement parcourue.
-- « Atterrir » demande au jeu de se poser au prochain relais, si le client le permet.
-- WK.DB.global.flights = { routes = { ["Départ|Arrivée"] = secondes }, worldSpeed = mètres / s }
-- (l'ancienne « speed » en unités de la carte des vols variait d'un continent à l'autre : abandonnée)

local function db()
    local g = WK.DB.global
    g.flights = g.flights or {}
    g.flights.routes = g.flights.routes or {}
    return g.flights
end

local function cfg()
    local q = WK.modules.QoL:Config()
    q.flight = q.flight or {}
    if q.flight.enabled == nil then q.flight.enabled = true end
    if q.flight.fpRemind == nil then q.flight.fpRemind = true end
    if q.flight.stats == nil then q.flight.stats = true end -- statistiques à la place de la carte, en vol
    return q.flight
end
M.Config = cfg

---------------------------------------------------------------------------
-- Choix du trajet chez le maître de vol
---------------------------------------------------------------------------
local pending -- { from, to, dist, t } : trajet demandé, en attente du décollage
local flight  -- { from, to, start, est, early } : vol en cours

local function nodeName(i) return TaxiNodeName and TaxiNodeName(i) end
local function currentNode()
    if not NumTaxiNodes then return nil end
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType and TaxiNodeGetType(i) == "CURRENT" then return i end
    end
end
-- Position d'un relais en mètres du jeu (via la carte des vols ouverte), mise en cache par relais.
local worldCache = {}
local function nodeWorld(i)
    if worldCache[i] ~= nil then return worldCache[i] end
    local w = false
    local mapID = GetTaxiMapID and GetTaxiMapID()
    if mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
        local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
        for _, n in ipairs(ok and nodes or {}) do
            if n.slotIndex == i and n.position then
                local x, y = n.position.x, n.position.y
                if n.position.GetXY then x, y = n.position:GetXY() end
                local cont, wx, wy = WK.modules.Guide.ToWorld(mapID, x, y)
                if cont then w = { cont, wx, wy } end
            end
        end
    end
    worldCache[i] = w
    return w
end
local function nodeDist(a, b)
    local wa, wb = nodeWorld(a), nodeWorld(b)
    if wa and wb and wa[1] == wb[1] then
        return math.sqrt((wa[2] - wb[2]) ^ 2 + (wa[3] - wb[3]) ^ 2)
    end
    return nil -- pas de mesure en mètres : pas d'estimation (les unités de la carte trompent)
end
local function mapDist(a, b)
    if not TaxiNodePosition then return nil end
    local ax, ay = TaxiNodePosition(a)
    local bx, by = TaxiNodePosition(b)
    if not ax or not bx then return nil end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Le trajet direct est rarement en ligne droite (relais) : la distance sert seulement à estimer.
function M:Estimate(dist)
    local sp = db().worldSpeed
    if dist and sp and sp > 0 then return dist / sp end
    return nil
end

-- Étapes du trajet (relais intermédiaires) : { { name, frac } }, frac = part de la distance (0-1).
-- La distance totale suit les relais, plus juste que la ligne droite.
local function routeStops(cur, index)
    if not (GetNumRoutes and TaxiGetNodeSlot and cur) then return nil, cur and nodeDist(cur, index) end
    local hops = GetNumRoutes(index) or 0
    if hops < 1 then return nil, nodeDist(cur, index) end
    local slots = { cur }
    for r = 1, hops do
        local slot = TaxiGetNodeSlot(index, r, true)
        if not slot then return nil, nodeDist(cur, index) end
        table.insert(slots, slot)
    end
    -- proportions des étapes : en mètres si possible, sinon sur la carte des vols (même rapport)
    -- longueur totale : en mètres seulement (sert à l'estimation de durée)
    local legs, total, world = {}, 0, 0
    for i = 2, #slots do
        local w = nodeDist(slots[i - 1], slots[i])
        if world and w then world = world + w else world = nil end
        local d = w or mapDist(slots[i - 1], slots[i]) or 0
        legs[i] = d
        total = total + d
    end
    local stops, acc = {}, 0
    for i = 2, #slots - 1 do -- relais entre le départ et l'arrivée
        acc = acc + legs[i]
        table.insert(stops, { name = nodeName(slots[i]) or "?", frac = total > 0 and acc / total or (i - 1) / (#slots - 1) })
    end
    return stops, world and world > 0 and world or nil
end
M.RouteStops = routeStops -- (pour les tests)

-- Durée d'un vol vers le relais `index` depuis le maître de vol ouvert : secondes, apprise (true/false)
function M:RouteTime(index)
    local cur = currentNode()
    local from, to = cur and nodeName(cur), nodeName(index)
    if not (from and to) or cur == index then return nil end
    local learned = db().routes[from .. "|" .. to]
    if learned then return learned, true end
    local _, dist = routeStops(cur, index)
    -- longueur du vrai trajet (fichiers du jeu) : estimation bien plus juste que les lignes droites
    local _, pts = self:Path(from, to)
    if pts and #pts >= 4 then dist = M.PathLength(pts) end
    local est = self:Estimate(dist)
    return est and math.floor(est + 0.5) or nil, false
end
local function clock(sec)
    sec = math.floor(sec + 0.5)
    if sec < 60 then return sec .. " s" end
    return string.format("%d min %02d", math.floor(sec / 60), sec % 60)
end
-- Infobulle d'une destination sur la carte des vols : durée apprise, ou estimée (« ~ »)
local function addTime(index)
    if not cfg().enabled or not index then return end
    local sec, learned = M:RouteTime(index)
    if not sec then return end
    local r, g, b = WK.UI:Accent()
    GameTooltip:AddLine(learned and string.format(T("Durée du vol : %s"), clock(sec))
        or string.format(T("Durée du vol : environ %s (estimée)"), clock(sec)), r, g, b)
    GameTooltip:Show()
end
if hooksecurefunc then
    -- ancienne carte des vols (boutons de relais)
    if TaxiNodeOnButtonEnter then
        hooksecurefunc("TaxiNodeOnButtonEnter", function(button) pcall(addTime, button and button:GetID()) end)
    end
    -- carte des vols récente (épingles) : accrochée quand elle se charge
    local function hookPins()
        local mix = FlightMap_FlightPointPinMixin
        if mix and mix.OnMouseEnter and not M.pinsHooked then
            M.pinsHooked = true
            hooksecurefunc(mix, "OnMouseEnter", function(pin)
                local d = pin and pin.taxiNodeData
                if d and d.slotIndex then pcall(addTime, d.slotIndex) end
            end)
        end
    end
    hookPins()
    WK:On("ADDON_LOADED", function(name) if name == "Blizzard_FlightMap" then hookPins() end end)
end

if hooksecurefunc and TakeTaxiNode then
    hooksecurefunc("TakeTaxiNode", function(index)
        worldCache = {} -- les relais sont relus sur la carte ouverte
        local cur = currentNode()
        local from, to = cur and nodeName(cur), nodeName(index)
        if not to then return end
        local stops, dist = routeStops(cur, index)
        local dest = nodeWorld(index)
        pending = { from = from or "?", to = to, dist = dist, stops = stops, t = GetTime(), dest = dest or nil }
    end)
end
-- carte des vols ouverte (autre maître de vol, autre continent) : les positions des relais sont relues
WK:On("TAXIMAP_OPENED", function() worldCache = {} end)

---------------------------------------------------------------------------
-- Décollage et atterrissage (le jeu ne prévient pas : on regarde si le perso est en vol)
---------------------------------------------------------------------------
local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") end

function M:Start()
    if not pending then return end
    local key = pending.from .. "|" .. pending.to
    -- distance mesurée comme le chemin parcouru (vrai trajet s'il est connu, sinon lignes droites entre relais)
    local dist = pending.dist
    local _, pts = self:Path(pending.from, pending.to)
    if pts and #pts >= 4 and M.PathLength then dist = M.PathLength(pts) end
    flight = { from = pending.from, to = pending.to, start = GetTime(), dist = dist, stops = pending.stops, dest = pending.dest,
               est = db().routes[key] or self:Estimate(dist), learned = db().routes[key] ~= nil,
               traveled = 0 }
    pending = nil
    if self.OnStart then self:OnStart(flight) end
end

local LAND_NEAR = 250 -- posé à moins de 250 m du relais d'arrivée : vol complet
function M:Finish()
    if not flight then return end
    local f = flight
    flight = nil
    local secs = GetTime() - f.start
    -- carnet des vols (statistiques en vol : vols du mois, temps en l'air, trajet le plus pris), 400 au plus
    do
        local d = db()
        d.log = d.log or {}
        table.insert(d.log, { t = time(), from = f.from, to = f.to, dur = math.floor(secs + 0.5) })
        while #d.log > 400 do table.remove(d.log, 1) end
    end
    -- Atterrissage anticipé avec le bouton du jeu : posé loin du relais d'arrivée, le vol n'est pas complet
    if not f.early and f.dest then
        local p = WK.modules.Guide:PlayerPos()
        if p and p.cont and (p.cont ~= f.dest[1]
            or math.sqrt((p.wx - f.dest[2]) ^ 2 + (p.wy - f.dest[3]) ^ 2) > LAND_NEAR) then
            f.early = true
        end
    end
    -- Durée apprise seulement pour un vol complet et plausible
    if not f.early and secs > 5 then
        local d = db()
        -- chemin du vol, simplifié, gardé pour le tracé (WK.DB.global.flights.paths["Départ|Arrivée"])
        if f.pts and #f.pts >= 6 and f.cont then
            local Nv = WK.modules.Nav
            d.paths = d.paths or {}
            local pts = Nv and Nv.Simplify and Nv.Simplify(f.pts, 8) or f.pts
            for i = 1, #pts do pts[i] = math.floor(pts[i] + 0.5) end
            d.paths[f.from .. "|" .. f.to] = { c = f.cont, pts = pts }
        end
        d.routes[f.from .. "|" .. f.to] = math.floor(secs + 0.5)
        d.speed = nil -- ancienne mesure, en unités de carte
        -- vitesse sur le chemin réellement parcouru (même grandeur que PathLength dans RouteTime)
        local len = (f.pts and #f.pts >= 4 and M.PathLength) and M.PathLength(f.pts) or f.dist
        if len and len > 0 then
            local sp = len / secs
            d.worldSpeed = d.worldSpeed and (d.worldSpeed * 0.7 + sp * 0.3) or sp
        end
    end
    if self.OnFinish then self:OnFinish() end
end

function M:Current() return flight end

-- Trajets de vol des fichiers du jeu (Modules/EverlootDB.lua, WK.FlightGame) : relais du jeu retrouvé par la
-- position du relais connu du perso (characters[perso].taxi, noté à l'ouverture de la carte des vols), puis
-- plus court enchaînement de trajets directs entre les deux relais.
local gameAdj
local function gameNode(name)
    local FG = WK.FlightGame
    local t = name and (WK.DB:Me().taxi or {})[name]
    if not (FG and t) then return nil end
    local best, bd
    for id, n in pairs(FG.nodes) do
        if n[1] == t[1] then
            local d = (n[2] - t[2]) ^ 2 + (n[3] - t[3]) ^ 2
            if not bd or d < bd then best, bd = id, d end
        end
    end
    return bd and bd < 150 * 150 and best or nil
end
local function pathLen(pts)
    local len = 0
    for i = 3, #pts, 2 do len = len + math.sqrt((pts[i] - pts[i - 2]) ^ 2 + (pts[i + 1] - pts[i - 1]) ^ 2) end
    return len
end
local function gamePath(a, b)
    local FG = WK.FlightGame
    if not (FG and a and b) or a == b then return nil end
    if not gameAdj then
        gameAdj = {}
        for key, pts in pairs(FG.paths) do
            local x, y = key:match("^(%d+)%-(%d+)$")
            x, y = tonumber(x), tonumber(y)
            gameAdj[x] = gameAdj[x] or {}
            gameAdj[x][y] = { pts = pts, len = pathLen(pts) }
        end
    end
    -- Dijkstra (quelques dizaines de relais par continent)
    local dist, prev, done = { [a] = 0 }, {}, {}
    while true do
        local u, du
        for n, dn in pairs(dist) do if not done[n] and (not du or dn < du) then u, du = n, dn end end
        if not u or u == b then break end
        done[u] = true
        for v, e in pairs(gameAdj[u] or {}) do
            local nd = du + e.len
            if not dist[v] or nd < dist[v] then dist[v], prev[v] = nd, u end
        end
    end
    if not dist[b] then return nil end
    local chain, n = {}, b
    while n ~= a do table.insert(chain, 1, n); n = prev[n] end
    local out, from = {}, a
    for _, to in ipairs(chain) do
        local pts = gameAdj[from][to].pts
        for i = (#out > 0 and 3 or 1), #pts do out[#out + 1] = pts[i] end
        from = to
    end
    return FG.nodes[a][1], out
end

-- Chemin connu d'un vol (« Départ », « Arrivée ») : continent, { x, y, ... } (sens du vol), appris en volant,
-- sinon tiré des fichiers du jeu
function M:Path(from, to)
    local d = db().paths or {}
    local e = d[(from or "") .. "|" .. (to or "")]
    if e then return e.c, e.pts end
    e = d[(to or "") .. "|" .. (from or "")]
    if e then
        local rev = {}
        for i = #e.pts - 1, 1, -2 do rev[#rev + 1] = e.pts[i]; rev[#rev + 1] = e.pts[i + 1] end
        return e.c, rev
    end
    return gamePath(gameNode(from), gameNode(to))
end
M.PathLength = pathLen

-- En vol : distance réellement parcourue (positions du perso, une par seconde). Pour un trajet pas
-- encore appris, l'estimation est recalculée : reste à parcourir / vitesse mesurée.
function M:Track()
    local f = flight
    local now = GetTime()
    if f.lastSample and now - f.lastSample < 1 then return end
    local p = WK.modules.Guide:PlayerPos()
    if not (p and p.cont) then return end
    -- chemin réel du vol (pour le dessiner : UI/NavRoute.lua), un point tous les 25 m au moins
    f.pts = f.pts or {}
    local np = #f.pts
    if np == 0 or f.cont ~= p.cont then
        f.cont = p.cont
        f.pts = { p.wx, p.wy }
    elseif math.sqrt((p.wx - f.pts[np - 1]) ^ 2 + (p.wy - f.pts[np]) ^ 2) > 25 then
        f.pts[np + 1], f.pts[np + 2] = p.wx, p.wy
    end
    if f.pos and f.pos.cont == p.cont then
        local dx, dy = p.wx - f.pos.wx, p.wy - f.pos.wy
        local step = math.sqrt(dx * dx + dy * dy)
        if step < 200 then f.traveled = (f.traveled or 0) + step end
    else
        f.trackStart = now
        f.traveled = 0
    end
    f.pos, f.lastSample = p, now
    if f.learned or f.early or not f.dist or not f.trackStart then return end
    local t = now - f.trackStart
    if t >= 4 and f.traveled > 20 then
        local speed = f.traveled / t
        local left = math.max(0, f.dist - f.traveled)
        f.est = (now - f.start) + left / speed
        f.live = true
    end
end

function M:CanLandEarly()
    return (TaxiRequestEarlyLanding or (C_TaxiMap and C_TaxiMap.RequestEarlyLanding)) ~= nil
end

function M:LandEarly()
    if not flight then return end
    local fn = TaxiRequestEarlyLanding or (C_TaxiMap and C_TaxiMap.RequestEarlyLanding)
    if fn and pcall(fn) then
        flight.early = true
        WK:Print(T("Atterrissage demandé au prochain relais."))
    end
end

local watcher = CreateFrame("Frame")
local acc = 0
watcher:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 0.25 then return end
    acc = 0
    if flight then M:Track() end
    local on = onTaxi()
    if on and not flight and pending and GetTime() - pending.t < 15 then M:Start()
    elseif not on and flight then M:Finish() end
    if pending and not on and GetTime() - pending.t > 15 then pending = nil end
end)

---------------------------------------------------------------------------
-- Points de vol à apprendre : maîtres de vol de ta faction (Modules/PlacesDB.lua, genre 8192) dont le
-- relais n'est pas dans les vols connus du perso (notés à l'ouverture de la carte des vols, Modules/Nav.lua).
-- Rappel une fois par zone et par session ; liste et guidage dans QoL > Carte ; /wk vol guide au plus proche.
---------------------------------------------------------------------------
local FM_BIT = 8192
local NEAR = 120 -- un relais connu à moins de 120 m du maître de vol : il est appris
local function factionLetter()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Alliance" and "A" or f == "Horde" and "H" or nil
end
function M:KnowsAnyTaxi()
    local t = WK.DB:Me().taxi
    return t ~= nil and next(t) ~= nil
end
-- Maîtres de vol pas encore appris : { { map, e, cont, wx, wy, distance } } (carte donnée, ou tout le continent)
function M:MissingFlightPoints(mapID, cont)
    local G = WK.modules.Guide
    local known = WK.DB:Me().taxi or {}
    local fac = factionLetter()
    local p = G:PlayerPos()
    local out = {}
    local maps = {}
    if mapID then maps[mapID] = (WK.PlacesDB or {})[mapID] else maps = WK.PlacesDB or {} end
    for map, list in pairs(maps) do
        for _, e in ipairs(list or {}) do
            if G.band(e[3], FM_BIT) ~= 0 and (not e[5] or e[5] == fac) then
                local c, wx, wy = G.ToWorld(map, e[1] / 100, e[2] / 100)
                if c and (not cont or c == cont) then
                    local learned = false
                    for _, n in pairs(known) do
                        if n[1] == c and math.sqrt((n[2] - wx) ^ 2 + (n[3] - wy) ^ 2) < NEAR then learned = true break end
                    end
                    if not learned then
                        local t = { map = map, e = e, cont = c, wx = wx, wy = wy, x = e[1] / 100, y = e[2] / 100 }
                        t.distance = p and G:Vector(p, t) or nil
                        table.insert(out, t)
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return (a.distance or 1e9) < (b.distance or 1e9) end)
    return out
end
function M:GuideToFlightPoint(t)
    t = t or self:MissingFlightPoints(nil, (WK.modules.Guide:PlayerPos() or {}).cont)[1]
    if not t then WK:Print(T("Aucun point de vol à apprendre connu sur ce continent.")) return end
    WK.modules.Guide:Start(t, "Point de vol à apprendre", "flight")
end
local reminded = {}
local hinted = false
local function checkZone()
    local c = cfg()
    if not c.fpRemind or (InCombatLockdown and InCombatLockdown()) then return end
    if IsInInstance and select(2, IsInInstance()) ~= "none" and select(2, IsInInstance()) ~= nil then return end
    local p = WK.modules.Guide:PlayerPos()
    if not p then return end
    if not M:KnowsAnyTaxi() then
        if not hinted then
            hinted = true
            WK:Print(T("Ouvre une fois la carte d'un maître de vol : Warband Keeper notera tes points de vol connus (rappel des points à apprendre, trajets avec vols)."))
        end
        return
    end
    if reminded[p.map] then return end
    reminded[p.map] = true
    local miss = M:MissingFlightPoints(p.map)
    if #miss == 0 then return end
    local G = WK.modules.Guide
    local name = G:PlaceName(miss[1])
    local msg = string.format(T("Point de vol à apprendre ici : %s"), name) .. (#miss > 1 and string.format(T(" (+%d)"), #miss - 1) or "")
    WK:Print(msg .. "  ·  " .. T("/wk vol pour y être guidé"))
    WK.modules.QoL:Remind("flightpoint", msg, 0.45, 0.78, 1, nil,
        { action = { label = T("Guider"), ghost = true, onClick = function() M:GuideToFlightPoint(miss[1]) end } })
end
WK:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(3, function() pcall(checkZone) end) end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(6, function() pcall(checkZone) end) end)
-- appris à l'instant (carte des vols ouverte chez ce maître) : plus de rappel pour la zone
WK:On("TAXIMAP_CLOSED", function() if WK.UI.RefreshFlightPoints then WK.UI:RefreshFlightPoints() end end)
