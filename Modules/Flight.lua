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

if hooksecurefunc and TakeTaxiNode then
    hooksecurefunc("TakeTaxiNode", function(index)
        worldCache = {} -- les relais sont relus sur la carte ouverte
        local cur = currentNode()
        local from, to = cur and nodeName(cur), nodeName(index)
        if not to then return end
        local stops, dist = routeStops(cur, index)
        pending = { from = from or "?", to = to, dist = dist, stops = stops, t = GetTime() }
    end)
end

---------------------------------------------------------------------------
-- Décollage et atterrissage (le jeu ne prévient pas : on regarde si le perso est en vol)
---------------------------------------------------------------------------
local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") end

function M:Start()
    if not pending then return end
    local key = pending.from .. "|" .. pending.to
    flight = { from = pending.from, to = pending.to, start = GetTime(), dist = pending.dist, stops = pending.stops,
               est = db().routes[key] or self:Estimate(pending.dist), learned = db().routes[key] ~= nil,
               traveled = 0 }
    pending = nil
    if self.OnStart then self:OnStart(flight) end
end

function M:Finish()
    if not flight then return end
    local f = flight
    flight = nil
    local secs = GetTime() - f.start
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
        if f.dist and f.dist > 0 then
            local sp = f.dist / secs
            d.worldSpeed = d.worldSpeed and (d.worldSpeed * 0.7 + sp * 0.3) or sp
        end
    end
    if self.OnFinish then self:OnFinish() end
end

function M:Current() return flight end
-- Chemin connu d'un vol (« Départ », « Arrivée ») : continent, { x, y, ... } (sens du vol)
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
end

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
