local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Tracé du trajet de navigation (Modules/Nav.lua) : pointillés de la couleur d'accent, de toi
-- jusqu'au lieu guidé, sur la carte du monde (appelé par UI/MapPins.lua) et sur la minicarte.
-- Les étapes de vol sont en tirets plus espacés et plus pâles.
local N = WK.modules.Nav
local MAX_MAP, MAX_MINI = 1200, 160

local function gcfg() return WK.modules.Guide:Config() end

-- Chemin d'un vol, gardé en cache par « Départ|Arrivée » : remaining() tourne toutes les 0,15 s et, pour un
-- vol pas encore fait, Flight:Path relance un Dijkstra à chaque appel. L'entrée reste valable tant que les
-- chemins appris de ce trajet (dans un sens ou l'autre) n'ont pas changé ; vidée à l'ouverture de la carte
-- des vols (nouveau relais connu).
local pathCache = {}
local function flightPath(from, to)
    local F = WK.modules.Flight
    if not (F and F.Path) then return nil end
    local fl = WK.DB.global.flights
    local paths = fl and fl.paths
    local fw = paths and paths[(from or "") .. "|" .. (to or "")]
    local bw = paths and paths[(to or "") .. "|" .. (from or "")]
    local key = (from or "") .. "|" .. (to or "")
    local e = pathCache[key]
    if e and e.paths == paths and e.fw == fw and e.bw == bw then return e.c, e.pts end
    local c, pts = F:Path(from, to)
    pathCache[key] = { paths = paths, fw = fw, bw = bw, c = c, pts = pts }
    return c, pts
end
WK:On("TAXIMAP_OPENED", function() pathCache = {} end)

-- Points d'un vol : chemin réel déjà parcouru une fois (Modules/Flight.lua), sinon ligne droite
local function flyPoints(out, from, to, ax, ay, bx, by, fromIdx)
    local pts = select(2, flightPath(from, to))
    if pts and #pts >= 4 then
        for k = (fromIdx or 1), #pts / 2 do out[#out + 1] = { pts[k * 2 - 1], pts[k * 2], true } end
        return true
    end
    if ax then out[#out + 1] = { ax, ay } end
    if bx then out[#out + 1] = { bx, by, true } end -- le segment qui arrive ici est un vol
    return false
end
-- Index du point du chemin le plus proche de (x, y)
local function nearestIdx(pts, x, y)
    local bi, bd = 1, math.huge
    for k = 1, #pts / 2 do
        local d = N.Dist(x, y, pts[k * 2 - 1], pts[k * 2])
        if d < bd then bi, bd = k, d end
    end
    return bi
end

-- Points restants du trajet (monde), depuis la position du perso : { { x, y, fly } }
-- En vol (taxi) : le chemin du griffon depuis la position actuelle (connu après un premier vol,
-- sinon le chemin parcouru jusqu'ici), puis la suite du trajet guidé.
local function remaining()
    local r = N.route
    local G = WK.modules.Guide
    local p = G:PlayerPos()
    local F = WK.modules.Flight
    local fl = F and F.Current and F:Current()
    local out = {}
    if fl and p and p.cont then
        out[1] = { p.wx, p.wy }
        local _, pts = flightPath(fl.from, fl.to)
        if pts and #pts >= 4 then
            for k = nearestIdx(pts, p.wx, p.wy), #pts / 2 do out[#out + 1] = { pts[k * 2 - 1], pts[k * 2], true } end
        elseif fl.pts and #fl.pts >= 4 then
            -- premier vol sur ce trajet : le chemin déjà parcouru (derrière toi)
            out = {}
            for k = 1, #fl.pts / 2 do out[#out + 1] = { fl.pts[k * 2 - 1], fl.pts[k * 2], k > 1 } end
            out[#out + 1] = { p.wx, p.wy, true }
        end
        -- suite du trajet guidé après l'étape de vol
        if r and r.cont == p.cont then
            local after = false
            for _, l in ipairs(r.legs) do
                if after and l.kind == "walk" then
                    for k = 1, #l.pts / 2 do out[#out + 1] = { l.pts[k * 2 - 1], l.pts[k * 2] } end
                end
                if l.kind == "fly" then after = true end
            end
        end
        return out, p.cont
    end
    if not r then return nil end
    if p and p.cont == r.cont then out[1] = { p.wx, p.wy } end
    for li = r.leg or 1, #r.legs do
        local l = r.legs[li]
        if l.kind == "walk" then
            local start = (li == r.leg) and (r.idx or 1) or 1
            for k = start, #l.pts / 2 do out[#out + 1] = { l.pts[k * 2 - 1], l.pts[k * 2] } end
        elseif l.kind == "fly" then
            flyPoints(out, l.from, l.to, l.ax, l.ay, l.bx, l.by)
        end
    end
    return out, r.cont
end

-- Lignes fines (vols, bateaux) : un trait de couleur sur un liseré sombre un peu plus large, lisible sur
-- tous les fonds de carte. Pool par usage ; repli en points si le client n'a pas CreateLine.
function UI:LinePool(layerSub)
    local pool = { lines = {}, n = 0 }
    function pool:Reset()
        for _, l in ipairs(self.lines) do l:Hide(); l.o:Hide() end
        self.n = 0
    end
    function pool:Add(cv, x1, y1, x2, y2, thick, r, g, b, a)
        if not cv.CreateLine then return end
        self.n = self.n + 1
        local l = self.lines[self.n]
        if not l then
            l = cv:CreateLine(nil, "OVERLAY", nil, (layerSub or 4) + 1)
            l.o = cv:CreateLine(nil, "OVERLAY", nil, layerSub or 4)
            self.lines[self.n] = l
        end
        if l:GetParent() ~= cv then l:SetParent(cv); l.o:SetParent(cv) end
        for _, x in ipairs({ l.o, l }) do
            x:ClearAllPoints()
            x:SetStartPoint("TOPLEFT", cv, x1, -y1)
            x:SetEndPoint("TOPLEFT", cv, x2, -y2)
        end
        l.o:SetThickness(thick + 2.5)
        l.o:SetColorTexture(0, 0, 0, 0.75 * (a or 1))
        l:SetThickness(thick)
        l:SetColorTexture(r, g, b, a or 1)
        l.o:Show(); l:Show()
    end
    return pool
end
local canLine = function(cv) return cv and cv.CreateLine ~= nil end

-- Trajets de bateau appris (Modules/Nav.lua) : leur chemin réel, en trait fin de la couleur des transports
local boatDots = {}
local boatLines = UI:LinePool(4)
function UI:DrawBoatPaths(cv, mapID, w, h)
    for _, d in ipairs(boatDots) do d:Hide() end
    boatLines:Reset()
    local L = WK.modules.MapLayers
    if not (L and WK:FeatureOn("maplayers") and L:Config().map.transport) then return end
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
    local col = { UI:Accent() }
    local tl = L.LAYER and L.LAYER.transport
    if tl and L.FAMILY[tl.family] then col = L.FAMILY[tl.family].color end
    local scale = (w / 1000) * UI.MapIconScale()
    local size, gap = math.max(3 * UI.MapIconScale(), 4.5 * scale), math.max(8 * UI.MapIconScale(), 13 * scale)
    local n = 0
    for _, b in ipairs(N:Boats()) do
        local pts = b.path and b.path.pts
        if pts and #pts >= 4 then
            local px, py
            for k = 1, #pts / 2 do
                local okc, _, pos = pcall(C_Map.GetMapPosFromWorldPos, b.path.c, CreateVector2D(pts[k * 2 - 1], pts[k * 2]), mapID)
                local mx, my
                if okc and pos then mx, my = pos.x, pos.y; if pos.GetXY then mx, my = pos:GetXY() end end
                if mx and mx > -0.1 and mx < 1.1 and my > -0.1 and my < 1.1 then
                    local x, y = mx * w, my * h
                    if px and canLine(cv) then
                        boatLines:Add(cv, px, py, x, y, math.max(1.6 * UI.MapIconScale(), 2.2 * scale), col[1], col[2], col[3], 0.95)
                    elseif px then
                        local dx, dy = x - px, y - py
                        local len = math.sqrt(dx * dx + dy * dy)
                        local t = 0
                        while t < len and n < 600 do
                            n = n + 1
                            local d = boatDots[n]
                            if not d then
                                d = cv:CreateTexture(nil, "OVERLAY", nil, 4)
                                d:SetTexture(UI.MEDIA .. "circle")
                                boatDots[n] = d
                            end
                            if d:GetParent() ~= cv then d:SetParent(cv) end
                            d:SetSize(size, size)
                            d:SetVertexColor(col[1], col[2], col[3], 0.85)
                            d:ClearAllPoints()
                            d:SetPoint("CENTER", cv, "TOPLEFT", px + dx * t / len, -(py + dy * t / len))
                            d:Show()
                            t = t + gap
                        end
                    end
                    px, py = x, y
                else
                    px, py = nil, nil
                end
            end
        end
    end
end
function UI:HideBoatPaths() for _, d in ipairs(boatDots) do d:Hide() end; boatLines:Reset() end

---------------------------------------------------------------------------
-- Carte du monde
---------------------------------------------------------------------------
-- Chaque point : un disque de la couleur d'accent posé sur un disque sombre un peu plus grand
-- (contour), pour rester lisible sur tous les fonds de carte.
local mapDots = {}
local function mapDot(i, cv)
    local d = mapDots[i]
    if not d then
        d = cv:CreateTexture(nil, "OVERLAY", nil, 6)
        d:SetTexture(UI.MEDIA .. "circle")
        d.o = cv:CreateTexture(nil, "OVERLAY", nil, 5)
        d.o:SetTexture(UI.MEDIA .. "circle")
        d.o:SetPoint("CENTER", d, "CENTER")
        mapDots[i] = d
    end
    if d:GetParent() ~= cv then d:SetParent(cv); d.o:SetParent(cv) end
    return d
end
local flyLines = UI:LinePool(5)
local walkLines = UI:LinePool(6)
function UI:HideNavRoute()
    for _, d in ipairs(mapDots) do d:Hide(); d.o:Hide() end
    flyLines:Reset()
    walkLines:Reset()
end
local function toMap(cont, x, y, mapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(x, y), mapID)
    if not ok or not pos then return nil end
    local mx, my = pos.x, pos.y
    if pos.GetXY then mx, my = pos:GetXY() end
    return mx, my
end
function UI:DrawNavRoute(cv, mapID, w, h)
    UI:HideNavRoute()
    if not gcfg().route then return end
    local pts, cont = remaining()
    if not pts or #pts < 2 then return end
    local r, g, b = UI:Accent()
    local scale = (w / 1000) * UI.MapIconScale()
    local size = math.max(5 * UI.MapIconScale(), 7.5 * scale)
    local gap = math.max(9 * UI.MapIconScale(), 14 * scale)
    local n = 0
    local px, py
    for i, pt in ipairs(pts) do
        local mx, my = toMap(cont, pt[1], pt[2], mapID)
        if mx then
            local x, y = mx * w, my * h
            if px then
                local fly = pt[3]
                local dx, dy = x - px, y - py
                local len = math.sqrt(dx * dx + dy * dy)
                local step = fly and gap * 2.2 or gap
                local inside = (mx > -0.05 and mx < 1.05 and my > -0.05 and my < 1.05) or (px > -0.05 * w and px < 1.05 * w and py > -0.05 * h and py < 1.05 * h)
                if len > 0 and inside and fly and canLine(cv) then
                    -- étape de vol : trait fin continu
                    flyLines:Add(cv, px, py, x, y, math.max(1.8 * UI.MapIconScale(), 2.4 * scale), r, g, b, 0.95)
                elseif len > 0 and inside and canLine(cv) then
                    -- à pied : trait fin et plein, cerné de sombre pour rester visible sur la carte
                    walkLines:Add(cv, px, py, x, y, math.max(2.2 * UI.MapIconScale(), 3 * scale), r, g, b, 1)
                elseif len > 0 and inside then
                    local k = 0
                    while k < len and n < MAX_MAP do
                        n = n + 1
                        local d = mapDot(n, cv)
                        local s = fly and size * 0.8 or size
                        d:SetSize(s, s)
                        d:SetVertexColor(r, g, b, fly and 0.6 or 1)
                        d.o:SetSize(s + 3.5 * math.max(1, scale), s + 3.5 * math.max(1, scale))
                        d.o:SetVertexColor(0, 0, 0, fly and 0.45 or 0.8)
                        d:ClearAllPoints()
                        d:SetPoint("CENTER", cv, "TOPLEFT", px + dx * k / len, -(py + dy * k / len))
                        d:Show(); d.o:Show()
                        k = k + step
                    end
                end
            end
            px, py = x, y
        else
            px, py = nil, nil
        end
        if n >= MAX_MAP then break end
    end
end

---------------------------------------------------------------------------
-- Minicarte
---------------------------------------------------------------------------
local holder, miniDots = nil, {}
local viewRadius = UI.MiniViewRadius -- aide commune de la minicarte (UI/MapPins.lua)
local function miniDot(i)
    local d = miniDots[i]
    if not d then
        d = holder:CreateTexture(nil, "OVERLAY", nil, 2)
        d:SetTexture(UI.MEDIA .. "circle")
        d.o = holder:CreateTexture(nil, "OVERLAY", nil, 1)
        d.o:SetTexture(UI.MEDIA .. "circle")
        d.o:SetPoint("CENTER", d, "CENTER")
        miniDots[i] = d
    end
    return d
end
local miniLines
local function updateMini()
    for _, d in ipairs(miniDots) do d:Hide(); d.o:Hide() end
    if miniLines then miniLines:Reset() end
    if not gcfg().routeMini or not Minimap:IsVisible() then return end
    local pts, cont = remaining()
    if not pts or #pts < 2 then return end
    local G = WK.modules.Guide
    local p = G:PlayerPos()
    if not (p and p.cont == cont) then return end
    local radius = viewRadius()
    local limit = radius * 0.94
    local half = Minimap:GetWidth() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or nil
    local cs, sn = facing and math.cos(facing) or 1, facing and math.sin(facing) or 0
    local r, g, b = UI:Accent()
    -- trait continu (comme sur la carte du monde), coupé au bord de la minicarte
    miniLines = miniLines or UI:LinePool(4)
    miniLines:Reset()
    local function toMini(x, y)
        -- monde : x vers le nord, y vers l'ouest ; écran : dx vers l'est, dy vers le nord
        local dx, dy = -(y - p.wy), x - p.wx
        if facing then dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs end
        return dx, dy
    end
    local L2 = limit * limit
    local n = 0
    for i = 2, #pts do
        local a, c = pts[i - 1], pts[i]
        local fly = c[3]
        local x0, y0 = toMini(a[1], a[2])
        local x1, y1 = toMini(c[1], c[2])
        -- partie du segment dans le cercle : |P0 + t (P1 - P0)| <= limite
        local ex, ey = x1 - x0, y1 - y0
        local A = ex * ex + ey * ey
        local B = 2 * (x0 * ex + y0 * ey)
        local Cc = x0 * x0 + y0 * y0 - L2
        local t0, t1
        if A < 1e-6 then
            if Cc <= 0 then t0, t1 = 0, 1 end
        else
            local disc = B * B - 4 * A * Cc
            if disc >= 0 then
                local sq = math.sqrt(disc)
                t0, t1 = math.max(0, (-B - sq) / (2 * A)), math.min(1, (-B + sq) / (2 * A))
                if t0 >= t1 then t0 = nil end
            end
        end
        if t0 and n < MAX_MINI then
            n = n + 1
            local ax, ay = x0 + ex * t0, y0 + ey * t0
            local bx, by = x0 + ex * t1, y0 + ey * t1
            miniLines:Add(holder, half + ax / radius * half, half - ay / radius * half,
                half + bx / radius * half, half - by / radius * half, fly and 2 or 3, r, g, b, fly and 0.6 or 1)
        end
    end
end

function UI:RefreshNavRoute()
    if WK.modules.Guide.Redraw then WK.modules.Guide:Redraw() end
    if holder then updateMini() end
end

WK:On("PLAYER_LOGIN", function()
    C_Timer.After(2, function()
        if Minimap and not holder then
            holder = CreateFrame("Frame", "WarbandKeeperNavRoute", Minimap)
            holder:SetAllPoints(Minimap)
            holder:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 3)
            holder.acc, holder.mapAcc = 0, 0
            holder:SetScript("OnUpdate", function(s, el)
                s.acc, s.mapAcc = s.acc + el, s.mapAcc + el
                -- carte du monde ouverte : le tracé suit le perso (une fois par seconde)
                if s.mapAcc > 1 and WorldMapFrame and WorldMapFrame:IsShown() and UI.RefreshGuidePinLabel then
                    UI:RefreshGuidePinLabel()
                end
                -- carte ouverte : pastilles de lieux masquées par autre chose qu'un redessin ? on les remet
                if s.mapAcc > 1 and WorldMapFrame and WorldMapFrame:IsShown() and UI.MapLayersHidden and UI:MapLayersHidden() then
                    if UI.MapNote then UI.MapNote("pastilles masquées : réaffichage") end
                    if UI.RedrawWorldMap then UI.RedrawWorldMap("réparation") end
                end
                if s.mapAcc > 1 and (N.route or (WK.modules.Flight and WK.modules.Flight:Current())) and WorldMapFrame and WorldMapFrame:IsShown() then
                    s.mapAcc = 0
                    local cv = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
                    local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
                    if cv and mapID and (cv:GetWidth() or 0) > 0 then UI:DrawNavRoute(cv, mapID, cv:GetWidth(), cv:GetHeight()) end
                end
                if s.mapAcc > 1 then s.mapAcc = 0 end
                if s.acc < 0.15 then return end
                s.acc = 0
                updateMini()
            end)
        end
    end)
end)
