local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Tableau des bateaux et zeppelins, sans horaires : « d'ici, où je peux aller ? ». À gauche la carte des
-- lignes (Kalimdor et les Royaumes de l'Est, cartes du jeu assombries ; chaque ligne en courbe douce, bateau
-- en trait plein, zeppelin en pointillés ; lignes du port choisi en surbrillance), à droite la liste par port
-- (quais des lignes du jeu à moins de 500 m l'un de l'autre, Modules/BoatLines.lua) avec ses pontons et leurs
-- destinations ; le port choisi (le plus proche d'office) en haut, encadré. Clic sur un quai de la carte :
-- ce port ; survol d'une destination : sa ligne brille ; clic : guidage vers son ponton. Ouvert par le
-- raccourci « Bateaux » du micro menu et /wk bateaux.
local W, H, PORT_GAP, DEST_H = 920, 560, 8, 24
local LIST_W = 340            -- colonne de la liste
local MAP_W = W - LIST_W - 36 -- carte
local CONTMAP = { [0] = 1415, [1] = 1414 } -- cartes des continents du jeu
local board

local function BL() return WK.modules.BoatLines end
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
        d.label = UI:Text(dotF, 9)
        d:SetScript("OnClick", function(s) f.selected = s.port.name; f:Refresh() end)
        d:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
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
                local col = zep and C.warning or C.info
                local hl = (hover and hover.key == l.key) or (not hover and selLines[l.key])
                local a = hl and 1 or ((hover or sel) and 0.28 or 0.75)
                if not mine then a = a * 0.6 end
                for s = 1, #l.legs do
                    local pa = portOf[l.key .. ":" .. s]
                    local pb = portOf[l.key .. ":" .. (s % #l.stops + 1)]
                    local A, Bp = pa and pos[pa], pb and pos[pb]
                    if A and Bp and pa ~= pb then
                        local x1, y1, x2, y2 = A[1], A[2], Bp[1], Bp[2]
                        local dx, dy = x2 - x1, y2 - y1
                        local side = (li % 2 == 0) and 1 or -1
                        local k = 0.22 * side
                        local cx, cy = (x1 + x2) / 2 - dy * k, (y1 + y2) / 2 + dx * k
                        local N = 24
                        local px, py = x1, y1
                        for n = 1, N do
                            local qx, qy = qbez(n / N, x1, y1, cx, cy, x2, y2)
                            if not zep or n % 2 == 1 then
                                if hl then seg(px, py, qx, qy, 7, col[1], col[2], col[3], 0.22) end
                                seg(px, py, qx, qy, hl and 2.6 or 1.8, col[1], col[2], col[3], a)
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
                d.port = p
                d:ClearAllPoints(); d:SetPoint("CENTER", dotF, "TOPLEFT", xy[1], -xy[2])
                local near = p.d and p.d < 300
                local isSel = p.name == sel
                local c = near and C.info or (isSel and { ar, ag, ab } or C.text)
                d.dot:SetVertexColor(c[1], c[2], c[3], 1)
                d.halo:SetVertexColor(c[1], c[2], c[3], 0.3); d.halo:SetShown(near or isSel)
                d.label:ClearAllPoints()
                local right = xy[1] > MAP_W / 2
                if right then d.label:SetPoint("LEFT", d, "RIGHT", 1, 6) else d.label:SetPoint("RIGHT", d, "LEFT", -1, 6) end
                d.label:SetJustifyH(right and "LEFT" or "RIGHT")
                d.label:SetText((p.name:gsub("^Port de ", "")))
                local tc = (near or isSel) and c or C.muted
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
            if f.hoverLine then f.hoverLine = nil; f:DrawMap(f.list) end
        end)
        r:SetScript("OnClick", function(s) if s.dd then guideTo(s.dd) end end)
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
        c:SetScript("OnClick", function(s) if s.port then f.selected = s.port.name; f:Refresh() end end)
        f.cards[idx] = c
        return c
    end

    function f:Refresh()
        local list = ports(self.showAll, self.selected)
        if not self.selected and list[1] then self.selected = list[1].name; list = ports(self.showAll, self.selected) end
        self.list = list
        self.all:SetLabel(self.showAll and T("Ma faction") or T("Toutes les lignes"))
        local y = 0
        local ar, ag, ab = UI:Accent()
        for idx, p in ipairs(list) do
            local c = card(idx)
            c.port = p
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y); c:SetPoint("RIGHT", root, "RIGHT", 0, 0)
            local isSel = p.name == self.selected
            c.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
            if isSel then c.edge:SetColor(ar, ag, ab, 1) else c.edge:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1) end
            c.name:SetText(p.name)
            local zone = zoneName(p.c, p.x, p.y)
            c.meta:SetText(distText(p.d) .. (zone and (" · " .. zone) or ""))
            local ry = 32
            for k, dd in ipairs(p.dests) do
                local r = destRow(c, k)
                r.dd = dd
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -ry); r:SetPoint("RIGHT", c, "RIGHT", -6, 0)
                local col = dd.kind == "zeppelin" and C.warning or C.positive
                r.ring:SetVertexColor(col[1], col[2], col[3], 1)
                r.icon:SetTexture(UI.MEDIA .. (dd.kind == "zeppelin" and "zeppelin" or "boat"))
                r.icon:SetVertexColor(0.06, 0.06, 0.07, 1)
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
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperBoatBoard") end
    return f
end

function UI:ToggleBoatBoard(show)
    if not board then board = build() end
    if show == true or not board:IsShown() then board.selected = nil; board:Refresh(); board:Show(); board:Raise() else board:Hide() end
end
