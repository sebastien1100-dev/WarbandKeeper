local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Tableau des bateaux et zeppelins, sans horaires : « d'ici, où je peux aller ? ». À gauche la carte des
-- lignes (carte d'Azeroth du jeu, couleurs d'origine, sans repères ; chaque ligne en courbe douce, bateau
-- en trait plein, zeppelin en pointillés ; lignes du port choisi en surbrillance), à droite la liste par port
-- (quais des lignes du jeu à moins de 500 m l'un de l'autre, Modules/BoatLines.lua) avec ses pontons et leurs
-- destinations ; le port choisi (le plus proche d'office) en haut, encadré. Clic sur un quai de la carte :
-- ce port ; survol d'une destination : sa ligne brille ; clic : guidage vers son ponton. Ouvert par le
-- raccourci « Bateaux » du micro menu et /wk bateaux.
local W, H, PORT_GAP, DEST_H = 1016, 500, 8, 24
local LIST_W = 340            -- colonne de la liste
local MAP_W = W - LIST_W - 36 -- carte
local CONTMAP = { [0] = 1415, [1] = 1414 } -- cartes des continents du jeu (repli)
local AZEROTH = 947                         -- carte du monde du jeu (fond, couleurs d'origine)
local board

local function BL() return WK.modules.BoatLines end
-- orange des zeppelins (tiré de C.warning, plus franc) : sur la carte et dans la liste
local function zepCol() local w = C.warning; return { w[1], w[2] * 0.72, w[3] * 0.4 } end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- nom de la zone d'un point monde
local function zoneName(c, x, y)
    local map = BL():ToMap(c, x, y)
    local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name or nil
end

-- Ports : { name, zone, c, x, y, d (distance, nil si autre continent), dests = { { l, s, text, vessel, kind, neutral } } }
local function ports(all, selected)
    local B = BL()
    local out = {}
    for _, l in ipairs(B:All()) do
        if all or B:Mine(l) then
            for s, st in ipairs(l.stops) do
                local port
                for _, p in ipairs(out) do
                    if p.c == st.c and dist(p.x, p.y, st.x, st.y) < 500 then port = p break end
                end
                if not port then
                    port = { name = B:StopName(l, s), c = st.c, x = st.x, y = st.y, dests = {} }
                    table.insert(out, port)
                end
                table.insert(port.dests, { l = l, s = s, text = table.concat(B:Destinations(l, s), " » "),
                    vessel = T(l.vessel or ""), kind = l.kind, neutral = not l.side })
            end
        end
    end
    local p0 = WK.modules.Guide:PlayerPos()
    for _, p in ipairs(out) do
        if p0 and p0.cont == p.c then
            p.d = math.huge
            for _, dd in ipairs(p.dests) do
                local st = dd.l.stops[dd.s]
                p.d = math.min(p.d, dist(st.x, st.y, p0.wx, p0.wy))
            end
        end
        table.sort(p.dests, function(a, b) return a.text < b.text end)
    end
    table.sort(out, function(a, b)
        if selected and (a.name == selected) ~= (b.name == selected) then return a.name == selected end
        if (a.d ~= nil) ~= (b.d ~= nil) then return a.d ~= nil end
        if a.d and b.d then return a.d < b.d end
        return a.name < b.name
    end)
    return out
end

local function distText(d)
    if not d then return T("autre continent") end
    if d < 300 then return T("tu y es") end
    if d < 1000 then return string.format(T("%d m"), math.floor(d / 10 + 0.5) * 10) end
    return string.format(T("%.1f km"), d / 1000):gsub("%.", ",")
end

local function guideTo(dd)
    local st = dd.l.stops[dd.s]
    local mapID, x, y = BL():ToMap(st.c, st.x, st.y)
    if mapID then
        local name = BL():StopName(dd.l, dd.s)
        WK.modules.MapLayers:GuideTo(mapID, { x, y, 0, nil, nil, name, name, dd.vessel }, "Quai")
    end
end

---------------------------------------------------------------------------
-- Carte : position d'un quai, fond des continents, courbes
---------------------------------------------------------------------------
-- point d'un quai dans l'espace de son continent : pixels de la carte du jeu si on peut, sinon monde
-- (x nord, y ouest : u = -y, v = -x) ; art = la carte du jeu est utilisable
local function unitPos(c, x, y, art)
    if art and C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D and CONTMAP[c] then
        local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(x, y), CONTMAP[c])
        if ok and pos then
            local px, py = pos.x, pos.y
            if pos.GetXY then px, py = pos:GetXY() end
            return px * art.lw, py * art.lh
        end
    end
    return -y, -x
end
local function artOf(cont)
    if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return nil end
    local okL, layers = pcall(C_Map.GetMapArtLayers, cont)
    local L = okL and layers and layers[1]
    local okT, files = pcall(C_Map.GetMapArtLayerTextures, cont, 1)
    if not (L and okT and files and #files > 0) then return nil end
    return { lw = L.layerWidth or 1002, lh = L.layerHeight or 668, tw = L.tileWidth or 256, th = L.tileHeight or 256, files = files }
end
-- point d'une courbe de Bézier quadratique
local function qbez(t, x1, y1, cx, cy, x2, y2)
    local u = 1 - t
    return u * u * x1 + 2 * u * t * cx + t * t * x2, u * u * y1 + 2 * u * t * cy + t * t * y2
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperBoatBoard", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER", 0, 40)
    -- au-dessus de la fenêtre de l'addon (strate HIGH, qui se remet devant à chaque clic)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:Panel(f, 12, C.surface, C.border)
    f.logo = UI:Icon(f, "boat", 18, nil, "ARTWORK"); f.logo:SetPoint("TOPLEFT", 14, -13)
    f.logo:SetVertexColor(UI:Accent())
    f.title = UI:Text(f, 14); f.title:SetPoint("LEFT", f.logo, "RIGHT", 8, 0)
    f.title:SetText(T("Ports et destinations"))
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 16, -36)
    f.sub:SetText(T("Clic sur un quai de la carte ou une destination de la liste"))
    f.close = UI:IconButton(f, "close", 18); f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.all = UI:Button(f, "Toutes les lignes", nil, 22, "ghost")
    f.all:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.all:SetScript("OnClick", function() f.showAll = not f.showAll; f:Refresh() end)
    -- onglets Bateaux / Vols (onglet retenu dans settings.ui.boardTab)
    f.mode = WK.DB.global.settings.ui.boardTab == "flight" and "flight" or "boat"
    f.tabs = UI:Segmented(f, { { "boat", "Bateaux" }, { "flight", "Vols" } }, function(v)
        f.mode = v; WK.DB.global.settings.ui.boardTab = v; f.hoverRoute = nil; f:Refresh()
    end, 24)
    f.tabs:SetPoint("LEFT", f.title, "RIGHT", 18, 0)
    f.tabs:Select(f.mode)
    -- Vols : carte de quel perso
    local function charOpts()
        local opts = {}
        for key, c in pairs(WK.DB.global.characters) do table.insert(opts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
        table.sort(opts, function(a, b) return a[2] < b[2] end)
        return opts
    end
    f.charKey = WK:CharKey()
    f.charDd = UI:Dropdown(f, 170, 24, charOpts(), function(v) f.charKey = v; f.selNode = nil; f:Refresh() end)
    f.charDd:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.charOpts = charOpts

    -----------------------------------------------------------------------
    -- carte à gauche
    -----------------------------------------------------------------------
    local mapH = H - 56 - 12
    local mf = CreateFrame("Frame", nil, f)
    mf:SetPoint("TOPLEFT", 12, -56); mf:SetSize(MAP_W, mapH)
    if mf.SetClipsChildren then mf:SetClipsChildren(true) end
    local i = C.info
    mf.sea = UI:Rounded(mf, 10, 0, "BACKGROUND", 1)
    mf.sea:SetColor(i[1] * 0.16, i[2] * 0.22, i[3] * 0.30, 1)
    f.mapF = mf
    -- deux continents côte à côte (Kalimdor à gauche), un passage au milieu pour l'île de Zephras
    local GAPX = 56
    local boxW = (MAP_W - GAPX - 20) / 2
    f.boxes = {
        [1] = { x = 10, y = 26, w = boxW, h = mapH - 36, name = T("Kalimdor") },
        [0] = { x = 10 + boxW + GAPX, y = 26, w = boxW, h = mapH - 36, name = T("Royaumes de l'Est") },
    }
    for c, b in pairs(f.boxes) do
        b.frame = CreateFrame("Frame", nil, mf)
        b.frame:SetPoint("TOPLEFT", mf, "TOPLEFT", b.x, -b.y); b.frame:SetSize(b.w, b.h)
        if b.frame.SetClipsChildren then b.frame:SetClipsChildren(true) end
        b.land = UI:Rounded(b.frame, 14, 0, "BACKGROUND", 1)
        b.land:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 0.9)
        b.tiles = {}
        b.label = UI:Text(mf, 9, C.dim); b.label:SetText(string.upper(b.name))
        b.label:SetPoint("TOP", mf, "TOPLEFT", b.x + b.w / 2, -9)
        b.cont = c
    end
    -- fond principal : la carte d'Azeroth du jeu entière, sans désaturation (les continents ci-dessus ne
    -- servent que si elle manque)
    f.world = CreateFrame("Frame", nil, mf); f.world:SetAllPoints(mf); f.world:SetFrameLevel(mf:GetFrameLevel() + 2)
    f.worldTiles = {}
    -- courbes : traits recyclés (CreateLine) sur un cadre au-dessus des continents
    local lineF = CreateFrame("Frame", nil, mf); lineF:SetAllPoints(mf); lineF:SetFrameLevel(mf:GetFrameLevel() + 4)
    local dotF = CreateFrame("Frame", nil, mf); dotF:SetAllPoints(mf); dotF:SetFrameLevel(mf:GetFrameLevel() + 6)
    f.lines, f.nLines = {}, 0
    local function seg(x1, y1, x2, y2, thick, r, g, b, a)
        if not lineF.CreateLine then return end
        f.nLines = f.nLines + 1
        local l = f.lines[f.nLines]
        if not l then l = lineF:CreateLine(nil, "ARTWORK"); f.lines[f.nLines] = l end
        l:ClearAllPoints()
        l:SetStartPoint("TOPLEFT", lineF, x1, -y1); l:SetEndPoint("TOPLEFT", lineF, x2, -y2)
        l:SetThickness(thick)
        l:SetColorTexture(r, g, b, a)
        l:Show()
    end
    f.dots = {}
    local function dot(k)
        local d = f.dots[k]
        if d then return d end
        d = CreateFrame("Button", nil, dotF)
        d:SetSize(16, 16)
        d.halo = d:CreateTexture(nil, "BACKGROUND"); d.halo:SetTexture(UI.MEDIA .. "circle"); d.halo:SetPoint("CENTER"); d.halo:SetSize(24, 24)
        d.edge = d:CreateTexture(nil, "ARTWORK"); d.edge:SetTexture(UI.MEDIA .. "circle"); d.edge:SetPoint("CENTER"); d.edge:SetSize(11, 11)
        d.edge:SetVertexColor(0, 0, 0, 0.9)
        d.dot = d:CreateTexture(nil, "OVERLAY"); d.dot:SetTexture(UI.MEDIA .. "circle"); d.dot:SetPoint("CENTER"); d.dot:SetSize(8, 8)
        d.label = UI:Text(dotF, 10)
        -- contour : lisible sur les couleurs de la carte du jeu
        d.label:SetFont(UI.FONT, 10, "OUTLINE")
        d:SetScript("OnClick", function(s)
            if s.node then f.selNode = s.node.id; f:Refresh() return end
            f.selected = s.port.name; f:Refresh()
        end)
        d:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if s.node then
                local n = s.node
                GameTooltip:SetText(n.name, 1, 1, 1)
                GameTooltip:AddLine(n.zone or "", 0.7, 0.7, 0.7)
                if n.known then GameTooltip:AddLine(T("Clic : destinations depuis ce point"), 0.6, 0.6, 0.6)
                else GameTooltip:AddLine(T("Point de vol pas encore appris par ce perso"), 0.6, 0.6, 0.6) end
                GameTooltip:Show()
                return
            end
            GameTooltip:SetText(s.port.name, 1, 1, 1)
            for _, dd in ipairs(s.port.dests) do GameTooltip:AddDoubleLine(dd.text, dd.vessel, 0.85, 0.85, 0.85, 0.6, 0.6, 0.6) end
            GameTooltip:AddLine(T("Clic : voir ce port dans la liste"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        d:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.dots[k] = d
        return d
    end

    -- fond : carte du jeu du continent, cadrée sur ses quais, assombrie et teintée aux couleurs de l'addon
    function f:Layout(list)
        local pos = {}
        -- carte d'Azeroth : tout le fond, couleurs du jeu ; quais placés par le jeu
        local wa = artOf(AZEROTH)
        for _, t in ipairs(self.worldTiles) do t:Hide() end
        if wa then
            local sc = math.min(MAP_W / wa.lw, mapH / wa.lh)
            local ox, oy = (MAP_W - wa.lw * sc) / 2, (mapH - wa.lh * sc) / 2
            local cols = math.ceil(wa.lw / wa.tw)
            for idx, file in ipairs(wa.files) do
                local col, row = (idx - 1) % cols, math.floor((idx - 1) / cols)
                local t = self.worldTiles[idx]
                if not t then t = self.world:CreateTexture(nil, "BACKGROUND", nil, 2); self.worldTiles[idx] = t end
                t:SetTexture(file)
                if t.SetDesaturated then t:SetDesaturated(false) end
                t:SetVertexColor(1, 1, 1, 1)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.world, "TOPLEFT", ox + col * wa.tw * sc, -(oy + row * wa.th * sc))
                t:SetSize(wa.tw * sc, wa.th * sc)
                t:Show()
            end
            local placed = 0
            for _, p in ipairs(list) do
                local u, v
                if C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D then
                    local ok, _, mp = pcall(C_Map.GetMapPosFromWorldPos, p.c, CreateVector2D(p.x, p.y), AZEROTH)
                    if ok and mp then
                        u, v = mp.x, mp.y
                        if mp.GetXY then u, v = mp:GetXY() end
                    end
                end
                if u and u > 0 and u < 1 and v > 0 and v < 1 then
                    pos[p.name] = { ox + u * wa.lw * sc, oy + v * wa.lh * sc }
                    placed = placed + 1
                end
            end
            if placed >= 2 then
                self.proj = function(c, x, y)
                    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
                    local ok, _, mp = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(x, y), AZEROTH)
                    if not (ok and mp) then return nil end
                    local u, v = mp.x, mp.y
                    if mp.GetXY then u, v = mp:GetXY() end
                    if not (u and u > 0 and u < 1 and v > 0 and v < 1) then return nil end
                    return ox + u * wa.lw * sc, oy + v * wa.lh * sc
                end
                -- île hors des cartes du jeu (Zephras…) : au milieu de la mer, en haut
                local k = 0
                for _, p in ipairs(list) do
                    if not pos[p.name] then k = k + 1; pos[p.name] = { ox + wa.lw * sc * 0.5, oy + wa.lh * sc * (0.2 + 0.08 * k) } end
                end
                for _, b in pairs(self.boxes) do b.frame:Hide(); b.label:Hide() end
                self.pos = pos
                return
            end
            for _, t in ipairs(self.worldTiles) do t:Hide() end
            pos = {}
        end
        for _, b in pairs(self.boxes) do b.frame:Show(); b.label:Show() end
        for c, b in pairs(self.boxes) do
            b.art = artOf(CONTMAP[c])
            -- cadrage : rectangle des quais du continent, avec une marge
            local x0, y0, x1, y1
            for _, p in ipairs(list) do
                if p.c == c then
                    local u, v = unitPos(p.c, p.x, p.y, b.art)
                    x0, y0 = math.min(x0 or u, u), math.min(y0 or v, v)
                    x1, y1 = math.max(x1 or u, u), math.max(y1 or v, v)
                end
            end
            if not x0 then x0, y0, x1, y1 = 0, 0, 1, 1 end
            local mw, mh = math.max(1, x1 - x0), math.max(1, y1 - y0)
            local m = math.max(mw, mh) * 0.14
            x0, y0, x1, y1 = x0 - m, y0 - m, x1 + m, y1 + m
            local sc = math.min(b.w / (x1 - x0), b.h / (y1 - y0))
            local ox = (b.w - (x1 - x0) * sc) / 2 - x0 * sc
            local oy = (b.h - (y1 - y0) * sc) / 2 - y0 * sc
            b.sc, b.ox, b.oy = sc, ox, oy
            for _, t in ipairs(b.tiles) do t:Hide() end
            b.land:SetShown(not b.art)
            if b.art then
                local A = b.art
                local cols = math.ceil(A.lw / A.tw)
                for idx, file in ipairs(A.files) do
                    local col, row = (idx - 1) % cols, math.floor((idx - 1) / cols)
                    local t = b.tiles[idx]
                    if not t then t = b.frame:CreateTexture(nil, "BACKGROUND", nil, 2); b.tiles[idx] = t end
                    t:SetTexture(file)
                    if t.SetDesaturated then t:SetDesaturated(true) end
                    t:SetVertexColor(0.42 + i[1] * 0.1, 0.46 + i[2] * 0.1, 0.52 + i[3] * 0.12, 0.85)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", b.frame, "TOPLEFT", ox + col * A.tw * sc, -(oy + row * A.th * sc))
                    t:SetSize(A.tw * sc, A.th * sc)
                    t:Show()
                end
            end
        end
        for k, p in ipairs(list) do
            local b = self.boxes[p.c]
            local x, y
            if b then
                local u, v = unitPos(p.c, p.x, p.y, b.art)
                x, y = b.x + b.ox + u * b.sc, b.y + b.oy + v * b.sc
            else
                -- île hors continents (Zephras…) : dans le passage du milieu, en haut
                x, y = MAP_W / 2, 70 + (k % 3) * 30
            end
            pos[p.name] = { x, y }
        end
        self.pos = pos
        self.proj = function(c, x, y)
            local b = self.boxes[c]
            if not b then return nil end
            local u, v = unitPos(c, x, y, b.art)
            return b.x + b.ox + u * b.sc, b.y + b.oy + v * b.sc
        end
    end

    -- courbes des lignes et quais
    function f:DrawMap(list)
        for k = 1, self.nLines do self.lines[k]:Hide() end
        self.nLines = 0
        local pos, sel, hover = self.pos, self.selected, self.hoverLine
        -- port de chaque quai (ligne, n° de quai)
        local portOf = {}
        for _, p in ipairs(list) do
            for _, dd in ipairs(p.dests) do portOf[dd.l.key .. ":" .. dd.s] = p.name end
        end
        local selLines = {}
        for _, p in ipairs(list) do
            if p.name == sel then for _, dd in ipairs(p.dests) do selLines[dd.l.key] = true end end
        end
        local B = BL()
        local drawn = {}
        for li, l in ipairs(B:All()) do
            local mine = B:Mine(l)
            if (self.showAll or mine) and not drawn[l.key] then
                drawn[l.key] = true
                local zep = l.kind == "zeppelin"
                -- couleurs lisibles sur la carte du jeu : bateau bleu clair, zeppelin orange
                local base = zep and zepCol() or C.info
                local lift = zep and 0 or 0.3
                local col = { base[1] + (1 - base[1]) * lift, base[2] + (1 - base[2]) * lift, base[3] + (1 - base[3]) * lift }
                local hl = (hover and hover.key == l.key) or (not hover and selLines[l.key])
                local a = hl and 1 or ((hover or sel) and 0.5 or 0.95)
                if not mine then a = a * 0.6 end
                for s = 1, #l.legs do
                    local pa = portOf[l.key .. ":" .. s]
                    local pb = portOf[l.key .. ":" .. (s % #l.stops + 1)]
                    local A, Bp = pa and pos[pa], pb and pos[pb]
                    local pk = l.key .. ":" .. ((pa or "") < (pb or "") and ((pa or "") .. ">" .. (pb or "")) or ((pb or "") .. ">" .. (pa or "")))
                    if A and Bp and pa ~= pb and not drawn[pk] then
                        drawn[pk] = true
                        local x1, y1, x2, y2 = A[1], A[2], Bp[1], Bp[2]
                        local dx, dy = x2 - x1, y2 - y1
                        local side = (li % 2 == 0) and 1 or -1
                        local k = 0.22 * side
                        local cx, cy = (x1 + x2) / 2 - dy * k, (y1 + y2) / 2 + dx * k
                        local N = zep and 36 or 24
                        local px, py = x1, y1
                        for n = 1, N do
                            local qx, qy = qbez(n / N, x1, y1, cx, cy, x2, y2)
                            -- zeppelin : longs tirets (2 morceaux sur 3) ; contour sombre sous chaque trait
                            if not zep or n % 3 ~= 0 then
                                local th = hl and 4 or 3
                                if hl then seg(px, py, qx, qy, 10, col[1], col[2], col[3], 0.25) end
                                seg(px, py, qx, qy, th + 3, 0, 0, 0, 0.7 * a)
                                seg(px, py, qx, qy, th, col[1], col[2], col[3], a)
                            end
                            px, py = qx, qy
                        end
                    end
                end
            end
        end
        -- quais : ton port (bleu, halo), le port choisi (accent), les autres
        local ar, ag, ab = UI:Accent()
        local k = 0
        for _, p in ipairs(list) do
            local xy = pos[p.name]
            if xy then
                k = k + 1
                local d = dot(k)
                d.port, d.node = p, nil
                d:ClearAllPoints(); d:SetPoint("CENTER", dotF, "TOPLEFT", xy[1], -xy[2])
                local near = p.d and p.d < 300
                local isSel = p.name == sel
                local c = near and C.info or (isSel and { ar, ag, ab } or C.text)
                d.dot:SetVertexColor(c[1], c[2], c[3], 1)
                d.halo:SetVertexColor(c[1], c[2], c[3], 0.3); d.halo:SetShown(near or isSel)
                d.label:ClearAllPoints()
                -- étiquette du côté où elle tient : à droite près du bord gauche, à gauche près du bord droit
                local right = xy[1] < 110 or (xy[1] > MAP_W / 2 and xy[1] < MAP_W - 110)
                if right then d.label:SetPoint("LEFT", d, "RIGHT", 1, 6) else d.label:SetPoint("RIGHT", d, "LEFT", -1, 6) end
                d.label:SetJustifyH(right and "LEFT" or "RIGHT")
                d.label:SetText((p.name:gsub("^Port de ", "")))
                local tc = (near or isSel) and c or C.text
                d.label:SetTextColor(tc[1], tc[2], tc[3], 1)
                d:Show(); d.label:Show()
            end
        end
        for n = k + 1, #self.dots do self.dots[n]:Hide(); self.dots[n].label:Hide() end
    end

    -----------------------------------------------------------------------
    -- liste à droite (inchangée : un encart par port)
    -----------------------------------------------------------------------
    f.scroll = UI:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", f, "TOPRIGHT", -(LIST_W + 14), -56); f.scroll:SetPoint("BOTTOMRIGHT", -8, 12)
    local root = f.scroll.child
    root:SetWidth(LIST_W - 12)

    f.cards = {}
    local function destRow(card, k)
        local r = card.rows[k]
        if r then return r end
        r = CreateFrame("Button", nil, card)
        r:SetHeight(DEST_H)
        r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 2); r.bg:Hide()
        r.ring = UI:Icon(r, "circle", 18, nil, "ARTWORK"); r.ring:SetPoint("LEFT", 4, 0)
        r.icon = UI:Icon(r, "boat", 11, nil, "OVERLAY"); r.icon:SetPoint("CENTER", r.ring, "CENTER")
        r.text = UI:Text(r, 12); r.text:SetPoint("LEFT", 30, 0); r.text:SetPoint("RIGHT", -124, 0); r.text:SetJustifyH("LEFT")
        if r.text.SetWordWrap then r.text:SetWordWrap(false) end
        r.vessel = UI:Text(r, 10, C.muted); r.vessel:SetPoint("RIGHT", -6, 0); r.vessel:SetWidth(118); r.vessel:SetJustifyH("RIGHT")
        if r.vessel.SetWordWrap then r.vessel:SetWordWrap(false) end
        r:SetScript("OnEnter", function(s)
            s.bg:SetColor(unpack(C.hover)); s.bg:Show()
            if s.fl then
                if s.fl.chain then f.hoverRoute = s.fl.chain; f:DrawFlights() end
                UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(s.fl.title or "", 1, 1, 1)
                for _, l in ipairs(s.fl.tip or {}) do GameTooltip:AddLine(l, 0.75, 0.75, 0.75, true) end
                GameTooltip:Show()
                return
            end
            if not s.dd then return end
            f.hoverLine = s.dd.l; f:DrawMap(f.list)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.dd.vessel, 1, 1, 1)
            GameTooltip:AddLine(BL():LineName(s.dd.l), 0.85, 0.85, 0.85, true)
            GameTooltip:AddLine(T("Clic : guidage vers ce ponton"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(s)
            s.bg:Hide(); GameTooltip:Hide()
            if s.fl then
                if f.hoverRoute then f.hoverRoute = nil; f:DrawFlights() end
                return
            end
            if f.hoverLine then f.hoverLine = nil; f:DrawMap(f.list) end
        end)
        r:SetScript("OnClick", function(s)
            if s.fl then if s.fl.onClick then s.fl.onClick() end return end
            if s.dd then guideTo(s.dd) end
        end)
        card.rows[k] = r
        return r
    end
    local function card(idx)
        local c = f.cards[idx]
        if c then return c end
        c = CreateFrame("Button", nil, root)
        -- liseré : fond plein dessous, carte posée 1 px à l'intérieur
        c.edge = UI:Rounded(c, 10, 0, "BACKGROUND", 0)
        c.bg = UI:Rounded(c, 10, 1, "BACKGROUND", 1)
        c.name = UI:Text(c, 13); c.name:SetPoint("TOPLEFT", 12, -9)
        c.meta = UI:Text(c, 10, C.muted); c.meta:SetPoint("TOPRIGHT", -12, -11); c.meta:SetJustifyH("RIGHT")
        c.rows = {}
        -- clic sur l'encart : ce port devient le port choisi (ses lignes brillent sur la carte)
        c:SetScript("OnClick", function(s)
            if s.onClick then s.onClick() return end
            if s.port then f.selected = s.port.name; f:Refresh() end
        end)
        f.cards[idx] = c
        return c
    end

    function f:Refresh()
        if self.mode == "flight" then return self:RefreshFlights() end
        self.title:SetText(T("Ports et destinations"))
        self.logo:SetTexture(UI.MEDIA .. "boat")
        self.sub:SetText(T("Clic sur un quai de la carte ou une destination de la liste"))
        self.all:Show(); self.charDd:Hide()
        local list = ports(self.showAll, self.selected)
        if not self.selected and list[1] then self.selected = list[1].name; list = ports(self.showAll, self.selected) end
        self.list = list
        self.all:SetLabel(self.showAll and T("Ma faction") or T("Toutes les lignes"))
        local y = 0
        local ar, ag, ab = UI:Accent()
        for idx, p in ipairs(list) do
            local c = card(idx)
            c.port, c.onClick = p, nil
            if c.barBg then c.barBg:Hide(); c.barFill:Hide() end
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, -y)
            local isSel = p.name == self.selected
            c.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
            if isSel then c.edge:SetColor(ar, ag, ab, 1) else c.edge:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1) end
            c.name:SetText(p.name)
            local zone = zoneName(p.c, p.x, p.y)
            c.meta:SetText(distText(p.d) .. (zone and (" · " .. zone) or ""))
            local ry = 32
            for k, dd in ipairs(p.dests) do
                local r = destRow(c, k)
                r.dd, r.fl = dd, nil
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -ry); r:SetPoint("RIGHT", c, "RIGHT", -6, 0)
                local col = dd.kind == "zeppelin" and zepCol() or C.positive
                r.ring:SetVertexColor(col[1], col[2], col[3], 1)
                r.icon:SetTexture(UI.MEDIA .. (dd.kind == "zeppelin" and "zeppelin" or "boat"))
                r.icon:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
                r.text:SetText(dd.text)
                r.vessel:SetText(dd.vessel .. (dd.neutral and ("  " .. UI:Hex(C.dim) .. "(" .. T("neutre") .. ")|r") or ""))
                r:Show()
                ry = ry + DEST_H
            end
            for k = #p.dests + 1, #c.rows do c.rows[k]:Hide() end
            local h = ry + 8
            c:SetHeight(h)
            c:Show()
            y = y + h + PORT_GAP
        end
        for idx = #list + 1, #self.cards do self.cards[idx]:Hide() end
        root:SetHeight(math.max(1, y))
        if self.scroll.SetVerticalScroll then self.scroll:SetVerticalScroll(0) end
        if self.scroll.UpdateBar then self.scroll:UpdateBar() end
        self:Layout(list)
        self:DrawMap(list)
    end
    -----------------------------------------------------------------------
    -- Onglet Vols : relais du jeu (connus en clair, à apprendre grisés), trajets du jeu (connus en bleu,
    -- pas encore possibles en pointillés gris), destinations depuis le relais choisi (le plus proche d'office)
    -----------------------------------------------------------------------
    local function durText(d)
        local parts = {}
        if d.secs then table.insert(parts, string.format(T("env. %d min"), math.max(1, math.floor(d.secs / 60 + 0.5)))) end
        local relays = #d.chain - 2
        if relays == 1 then table.insert(parts, string.format(T("via %s"), d.chain[2].name))
        elseif relays > 1 then table.insert(parts, string.format(T("%d relais"), relays)) end
        return table.concat(parts, " · ")
    end
    local function guideNode(n)
        if n and n.fm then WK.modules.Guide:Start(n.fm, "Maître de vol", "flight") end
    end
    local function nodeDist(n, p0)
        if not (p0 and p0.cont == n.c) then return nil end
        return dist(n.x, n.y, p0.wx, p0.wy)
    end

    function f:DrawFlights()
        local data = self.fdata
        for k = 1, self.nLines do self.lines[k]:Hide() end
        self.nLines = 0
        if not (data and self.proj) then return end
        -- trajet survolé (ou départ choisi) : relais à relais en accent
        local hot = {}
        if self.hoverRoute then
            for hi = 1, #self.hoverRoute - 1 do
                local a, b = self.hoverRoute[hi], self.hoverRoute[hi + 1]
                hot[math.min(a.id, b.id) .. "-" .. math.max(a.id, b.id)] = true
            end
        end
        local info = C.info
        local blue = { info[1] + (1 - info[1]) * 0.3, info[2] + (1 - info[2]) * 0.3, info[3] + (1 - info[3]) * 0.3 }
        local ar, ag, ab = UI:Accent()
        for pass = 1, 3 do -- inconnus dessous, connus au-dessus, trajet survolé tout en haut
            for _, e in ipairs(data.edges) do
                local key = math.min(e.a.id, e.b.id) .. "-" .. math.max(e.a.id, e.b.id)
                local isHot = hot[key]
                if (pass == 1 and not e.known) or (pass == 2 and e.known and not isHot) or (pass == 3 and isHot) then
                    local pts = e.pts
                    local step = math.max(2, math.floor(#pts / 24) * 2) -- 12 morceaux au plus
                    local px, py = self.proj(e.a.c, pts[1], pts[2])
                    local n = 0
                    for pi = 1 + step, #pts + step - 1, step do
                        local j = math.min(pi, #pts - 1)
                        local qx, qy = self.proj(e.a.c, pts[j], pts[j + 1])
                        if px and qx then
                            n = n + 1
                            if isHot then
                                seg(px, py, qx, qy, 9, ar, ag, ab, 0.25)
                                seg(px, py, qx, qy, 5, 0, 0, 0, 0.6)
                                seg(px, py, qx, qy, 3, ar, ag, ab, 1)
                            elseif e.known then
                                seg(px, py, qx, qy, 4, 0, 0, 0, 0.55)
                                seg(px, py, qx, qy, 2, blue[1], blue[2], blue[3], (self.hoverRoute and 0.45) or 0.9)
                            elseif n % 2 == 1 then
                                seg(px, py, qx, qy, 2, 0.32, 0.33, 0.37, 0.8)
                            end
                        end
                        px, py = qx, qy
                    end
                end
            end
        end
        -- relais : départ en accent (halo), connus blancs avec nom, à apprendre gris sans nom
        local k = 0
        for _, nd in ipairs(data.list) do
            local x, y = self.proj(nd.c, nd.x, nd.y)
            if x then
                k = k + 1
                local d = dot(k)
                d.port, d.node = nil, nd
                d:ClearAllPoints(); d:SetPoint("CENTER", dotF, "TOPLEFT", x, -y)
                local isFrom = self.fromNode == nd
                local col = isFrom and { ar, ag, ab } or (nd.known and C.text or { 0.42, 0.43, 0.47 })
                d.dot:SetVertexColor(col[1], col[2], col[3], 1)
                d.dot:SetSize(nd.known and 8 or 6, nd.known and 8 or 6)
                d.halo:SetVertexColor(col[1], col[2], col[3], 0.3); d.halo:SetShown(isFrom)
                d.label:ClearAllPoints()
                local right = x < MAP_W - 110
                if right then d.label:SetPoint("LEFT", d, "RIGHT", 1, 5) else d.label:SetPoint("RIGHT", d, "LEFT", -1, 5) end
                d.label:SetJustifyH(right and "LEFT" or "RIGHT")
                d.label:SetText(nd.name)
                d.label:SetTextColor(col[1], col[2], col[3], 1)
                d:Show(); d.label:SetShown(nd.known or isFrom)
            end
        end
        for n = k + 1, #self.dots do self.dots[n]:Hide(); self.dots[n].label:Hide() end
    end

    function f:RefreshFlights()
        local F = WK.modules.Flight
        self.title:SetText(T("Points de vol"))
        self.logo:SetTexture(UI.MEDIA .. "griffon")
        self.sub:SetText(T("Clic sur un point : destinations depuis ce point · grisé : pas encore appris"))
        self.all:Hide()
        self.charDd:SetOptions(self.charOpts()); self.charDd:Select(self.charKey); self.charDd:Show()
        local data = F and F.BoardData and F:BoardData(self.charKey)
        self.fdata = data
        local p0 = self.charKey == WK:CharKey() and WK.modules.Guide:PlayerPos() or nil
        -- départ : relais choisi, sinon le relais connu le plus proche
        local from = data and self.selNode and data.nodes[self.selNode]
        if data and not from then
            local bd
            for _, n in ipairs(data.list) do
                if n.known then
                    local d = nodeDist(n, p0) or 1e9
                    if not bd or d < bd then from, bd = n, d end
                end
            end
        end
        self.fromNode = from
        local dests = data and F:Destinations(data, from) or {}
        -- carte
        local items = {}
        for _, n in ipairs(data and data.list or {}) do items[#items + 1] = { name = n.key, c = n.c, x = n.x, y = n.y } end
        self:Layout(items)
        self:DrawFlights()
        -- liste
        local ar, ag, ab = UI:Accent()
        local y, idx = 0, 0
        local function newCard(name, meta, sel)
            idx = idx + 1
            local c = card(idx)
            c.port, c.onClick = nil, nil
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, -y)
            c.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
            if sel then c.edge:SetColor(ar, ag, ab, 1) else c.edge:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1) end
            c.name:SetText(name); c.meta:SetText(meta or "")
            if c.barBg then c.barBg:Hide(); c.barFill:Hide() end
            for _, r in ipairs(c.rows) do r:Hide() end
            c:Show()
            return c
        end
        local function row(c, k, ry, fl, ringCol, text, right, dim)
            local r = destRow(c, k)
            r.dd, r.fl = nil, fl
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -ry); r:SetPoint("RIGHT", c, "RIGHT", -6, 0)
            r.ring:SetVertexColor(ringCol[1], ringCol[2], ringCol[3], dim and 0.45 or 1)
            r.icon:SetTexture(UI.MEDIA .. "griffon"); r.icon:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
            r.text:SetText(text); r.text:SetTextColor(unpack(dim and C.muted or C.text))
            r.vessel:SetText(right or "")
            r:Show()
        end
        local function finish(c, ry) local h = ry + 8; c:SetHeight(h); y = y + h + PORT_GAP end
        if not data or not next(data.nodes) then
            local c = newCard(T("Points de vol"), "")
            c.meta:SetText(""); finish(c, 30)
        else
            -- 1. départ et destinations (survol : trajet sur la carte)
            if from then
                local c = newCard(string.format(T("Depuis %s"), from.name), from.zone, true)
                local ry = 32
                if #dests == 0 then
                    row(c, 1, ry, { title = from.name }, C.muted, T("Aucune destination connue d'ici"), "", true); ry = ry + DEST_H
                end
                for k, d in ipairs(dests) do
                    if k > 14 then break end
                    row(c, k, ry, { chain = d.chain, title = d.node.name,
                        tip = { d.node.zone, durText(d), T("Clic : guidage vers le maître de vol de départ") },
                        onClick = function() guideNode(from) end }, C.info, d.node.name, durText(d))
                    ry = ry + DEST_H
                end
                finish(c, ry)
            else
                local c = newCard(T("Aucun point de vol connu"), "")
                row(c, 1, 32, { title = "" }, C.muted, T("Ouvre la carte d'un maître de vol pour noter tes points"), "", true)
                finish(c, 32 + DEST_H)
            end
            -- 2. par continent puis par zone (la plus proche en haut) : connus en vert, à apprendre grisés
            local conts = {}
            for _, n in ipairs(data.list) do
                local ct = conts[n.c]
                if not ct then ct = { c = n.c, zones = {}, total = 0, known = 0 }; conts[n.c] = ct end
                ct.total = ct.total + 1
                if n.known then ct.known = ct.known + 1 end
                local z = ct.zones[n.zone]
                if not z then z = { name = n.zone, nodes = {} }; ct.zones[n.zone] = z end
                table.insert(z.nodes, n)
                local d = nodeDist(n, p0)
                if d and (not z.d or d < z.d) then z.d = d end
            end
            local clist = {}
            for _, ct in pairs(conts) do table.insert(clist, ct) end
            table.sort(clist, function(a, b)
                local am, bm = p0 and a.c == p0.cont, p0 and b.c == p0.cont
                if am ~= bm then return am and true or false end
                return a.c > b.c
            end)
            for _, ct in ipairs(clist) do
                local cname = ct.c == 1 and T("Kalimdor") or ct.c == 0 and T("Royaumes de l'Est") or T("Autres terres")
                local c = newCard(cname, string.format(T("%d / %d points connus"), ct.known, ct.total))
                if not c.barBg then
                    c.barBg = c:CreateTexture(nil, "ARTWORK"); c.barFill = c:CreateTexture(nil, "OVERLAY")
                end
                c.barBg:ClearAllPoints(); c.barBg:SetPoint("TOPLEFT", 12, -32); c.barBg:SetPoint("TOPRIGHT", -12, -32); c.barBg:SetHeight(5)
                c.barBg:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], 1); c.barBg:Show()
                c.barFill:ClearAllPoints(); c.barFill:SetPoint("TOPLEFT", c.barBg, "TOPLEFT"); c.barFill:SetHeight(5)
                c.barFill:SetWidth(math.max(1, (LIST_W - 36) * ct.known / math.max(1, ct.total)))
                c.barFill:SetColorTexture(C.info[1], C.info[2], C.info[3], 1); c.barFill:Show()
                finish(c, 36)
                local zl = {}
                for _, z in pairs(ct.zones) do table.insert(zl, z) end
                table.sort(zl, function(a, b)
                    if (a.d ~= nil) ~= (b.d ~= nil) then return a.d ~= nil end
                    if a.d and b.d then return a.d < b.d end
                    return a.name < b.name
                end)
                for _, z in ipairs(zl) do
                    local here = z.d and z.d < 1500
                    local zc = newCard(z.name, z.d and distText(z.d) or "", false)
                    if here then zc.meta:SetText(T("tu es ici")) end
                    table.sort(z.nodes, function(a, b) if a.known ~= b.known then return a.known end return a.name < b.name end)
                    local ry = 32
                    for k, n in ipairs(z.nodes) do
                        if n.known then
                            row(zc, k, ry, { title = n.name, tip = { n.zone, T("Clic : destinations depuis ce point") },
                                onClick = function() self.selNode = n.id; self:Refresh() end },
                                (n == from) and { ar, ag, ab } or C.positive, n.name, (n == from) and T("départ") or T("connu"))
                        else
                            local d = nodeDist(n, p0)
                            row(zc, k, ry, { title = n.name, tip = { n.zone, T("Point de vol pas encore appris par ce perso"), T("Clic : guidage vers ce maître de vol") },
                                onClick = function() guideNode(n) end },
                                C.muted, n.name, T("à apprendre") .. (d and (" · " .. distText(d)) or ""), true)
                        end
                        ry = ry + DEST_H
                    end
                    finish(zc, ry)
                end
            end
        end
        for k = idx + 1, #self.cards do self.cards[k]:Hide() end
        root:SetHeight(math.max(1, y))
        if self.scroll.UpdateBar then self.scroll:UpdateBar() end
    end
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperBoatBoard") end
    return f
end

-- mode : « boat » ou « flight » (onglet ouvert), sinon le dernier
function UI:ToggleBoatBoard(show, mode)
    if not board then board = build() end
    if mode then board.mode = mode; board.tabs:Select(mode); WK.DB.global.settings.ui.boardTab = mode end
    if show == true or not board:IsShown() then
        board.selected, board.selNode = nil, nil
        board.charKey = WK:CharKey()
        board:Refresh(); board:Show(); board:Raise()
    else board:Hide() end
end
