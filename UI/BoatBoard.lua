local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Tableau des bateaux et zeppelins par port, sans horaires : « d'ici, où je peux aller ? ». Chaque port
-- (quais des lignes du jeu à moins de 500 m l'un de l'autre, Modules/BoatLines.lua) avec ses pontons et
-- leurs destinations ; le port le plus proche de toi en haut, encadré. Clic sur une destination : guidage
-- vers son ponton. Ouvert par le raccourci « Bateaux » du micro menu et /wk bateaux.
local W, MAXH, PORT_GAP, DEST_H = 470, 560, 8, 24
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
local function ports(all)
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

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperBoatBoard", UIParent)
    f:SetSize(W, 200)
    f:SetPoint("CENTER", 0, 80)
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
    f.sub:SetText(T("Clic sur une destination : guidage vers son ponton"))
    f.close = UI:IconButton(f, "close", 18); f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.all = UI:Button(f, "Toutes les lignes", nil, 22, "ghost")
    f.all:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.all:SetScript("OnClick", function() f.showAll = not f.showAll; f:Refresh() end)
    f.scroll = UI:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", 12, -56); f.scroll:SetPoint("BOTTOMRIGHT", -8, 12)
    local root = f.scroll.child
    root:SetWidth(W - 34)

    f.cards = {}
    local function destRow(card, k)
        local r = card.rows[k]
        if r then return r end
        r = CreateFrame("Button", nil, card)
        r:SetHeight(DEST_H)
        r.bg = UI:Rounded(r, 6, 0, "BACKGROUND", 2); r.bg:Hide()
        r.ring = UI:Icon(r, "circle", 18, nil, "ARTWORK"); r.ring:SetPoint("LEFT", 4, 0)
        r.icon = UI:Icon(r, "boat", 11, nil, "OVERLAY"); r.icon:SetPoint("CENTER", r.ring, "CENTER")
        r.text = UI:Text(r, 12); r.text:SetPoint("LEFT", 30, 0); r.text:SetPoint("RIGHT", -170, 0); r.text:SetJustifyH("LEFT")
        if r.text.SetWordWrap then r.text:SetWordWrap(false) end
        r.vessel = UI:Text(r, 10, C.muted); r.vessel:SetPoint("RIGHT", -6, 0); r.vessel:SetWidth(160); r.vessel:SetJustifyH("RIGHT")
        if r.vessel.SetWordWrap then r.vessel:SetWordWrap(false) end
        r:SetScript("OnEnter", function(s)
            s.bg:SetColor(unpack(C.hover)); s.bg:Show()
            if not s.dd then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.dd.vessel, 1, 1, 1)
            GameTooltip:AddLine(BL():LineName(s.dd.l), 0.85, 0.85, 0.85, true)
            GameTooltip:AddLine(T("Clic : guidage vers ce ponton"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(s) s.bg:Hide(); GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s) if s.dd then guideTo(s.dd) end end)
        card.rows[k] = r
        return r
    end
    local function card(i)
        local c = f.cards[i]
        if c then return c end
        c = CreateFrame("Frame", nil, root)
        -- liseré : fond plein dessous, carte posée 1 px à l'intérieur
        c.edge = UI:Rounded(c, 10, 0, "BACKGROUND", 0)
        c.bg = UI:Rounded(c, 10, 1, "BACKGROUND", 1)
        c.name = UI:Text(c, 13); c.name:SetPoint("TOPLEFT", 12, -9)
        c.meta = UI:Text(c, 10, C.muted); c.meta:SetPoint("TOPRIGHT", -12, -11); c.meta:SetJustifyH("RIGHT")
        c.rows = {}
        f.cards[i] = c
        return c
    end

    function f:Refresh()
        local list = ports(self.showAll)
        self.all:SetLabel(self.showAll and T("Ma faction") or T("Toutes les lignes"))
        local y = 0
        local ar, ag, ab = UI:Accent()
        for i, p in ipairs(list) do
            local c = card(i)
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y); c:SetPoint("RIGHT", root, "RIGHT", 0, 0)
            local near = p.d and p.d < 300
            c.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
            if near then c.edge:SetColor(ar, ag, ab, 1) else c.edge:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1) end
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
        for i = #list + 1, #self.cards do self.cards[i]:Hide() end
        root:SetHeight(math.max(1, y))
        self:SetHeight(math.min(MAXH, 56 + y + 14))
        if self.scroll.UpdateBar then self.scroll:UpdateBar() end
    end
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperBoatBoard") end
    return f
end

function UI:ToggleBoatBoard(show)
    if not board then board = build() end
    if show == true or not board:IsShown() then board:Refresh(); board:Show(); board:Raise() else board:Hide() end
end
