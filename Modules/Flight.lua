local ADDON_NAME, WK = ...
local M = WK:NewModule("Flight")
local T = function(s) return WK.T(s) end

-- Barre de vol : au départ d'un vol (maître de vol), trajet, temps restant et progression.
-- La durée d'un trajet est apprise au premier vol complet (partagée entre les persos) ; avant ça,
-- elle est estimée d'après la distance et la vitesse moyenne des vols déjà faits.
-- « Atterrir » demande au jeu de se poser au prochain relais, si le client le permet.
-- WK.DB.global.flights = { routes = { ["Départ|Arrivée"] = secondes }, speed = unités de carte / s }

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
local function nodeDist(a, b)
    if not TaxiNodePosition then return nil end
    local ax, ay = TaxiNodePosition(a)
    local bx, by = TaxiNodePosition(b)
    if not ax or not bx then return nil end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Le trajet direct est rarement en ligne droite (relais) : la distance sert seulement à estimer.
function M:Estimate(dist)
    local sp = db().speed
    if dist and sp and sp > 0 then return dist / sp end
    return nil
end

if hooksecurefunc and TakeTaxiNode then
    hooksecurefunc("TakeTaxiNode", function(index)
        local cur = currentNode()
        local from, to = cur and nodeName(cur), nodeName(index)
        if not to then return end
        pending = { from = from or "?", to = to, dist = cur and nodeDist(cur, index), t = GetTime() }
    end)
end

---------------------------------------------------------------------------
-- Décollage et atterrissage (le jeu ne prévient pas : on regarde si le perso est en vol)
---------------------------------------------------------------------------
local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") end

function M:Start()
    if not pending then return end
    local key = pending.from .. "|" .. pending.to
    flight = { from = pending.from, to = pending.to, start = GetTime(), dist = pending.dist,
               est = db().routes[key] or self:Estimate(pending.dist), learned = db().routes[key] ~= nil }
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
        d.routes[f.from .. "|" .. f.to] = math.floor(secs + 0.5)
        if f.dist and f.dist > 0 then
            local sp = f.dist / secs
            d.speed = d.speed and (d.speed * 0.7 + sp * 0.3) or sp
        end
    end
    if self.OnFinish then self:OnFinish() end
end

function M:Current() return flight end

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
    local on = onTaxi()
    if on and not flight and pending and GetTime() - pending.t < 15 then M:Start()
    elseif not on and flight then M:Finish() end
    if pending and not on and GetTime() - pending.t > 15 then pending = nil end
end)
