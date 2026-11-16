local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Quêtes (Modules/Quests.lua), sur le modèle de la page Rares : une tuile par zone avec un
-- anneau de progression (ta zone en premier), les quêtes de la zone choisie en dessous, et à droite
-- les réglages et la légende. Collection par perso (« Quêtes de »).
local Q = WK.modules.Quests
local GAP, SIDE_W, ROW_H = 12, 300, 44
local TILE_W, TILE_H = 214, 74
local DOTS = 28

local function levelColor(lvl, me)
    local d = (lvl or 0) - (me or 1)
    if d >= 5 then return C.negative end
    if d >= 3 then return C.warning end
    if d >= -2 then return C.gold end
    if d >= -8 then return C.positive end
    return C.dim
end

-- Couleur et texte de chaque état
local function stateInfo(st)
    if st == "done" then return C.dim, T("faite") end
    if st == "log" then return C.positive, T("dans le journal") end
    if st == "avail" then return C.gold, T("disponible") end
    if st == "high" then return C.warning, T("trop haute") end
    return C.muted, T("plus tard")
end
local KIND = { d = "Donjon", c = "Classe" }

UI:RegisterPage({
    key = "quests", order = 8.9, nav = "Quêtes",

    Build = function(self, p)
        local cfg = Q:Config()
        self.viewKey = WK:CharKey()
        self.zone = Q:PlayerZone()
        cfg.filter = cfg.filter or "all"

        -- Barre de commandes ---------------------------------------------------------
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("TOPLEFT", 0, -9)
        of:SetText(T("Quêtes de"))
        local charOpts = {}
        for key, c in pairs(WK.DB.global.characters) do table.insert(charOpts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
        table.sort(charOpts, function(a, b) return a[2] < b[2] end)
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self.zone = nil; self:Refresh() end)
        self.charDd:SetPoint("TOPLEFT", of, "TOPRIGHT", 8, 9)
        self.charDd:Select(self.viewKey)
        self.filterSeg = UI:Segmented(p, { { "all", "Toutes" }, { "todo", "À faire" }, { "done", "Faites" } },
            function(v) cfg.filter = v; self:Refresh() end, 30)
        self.filterSeg:SetPoint("TOPLEFT", self.charDd, "TOPRIGHT", 8, 0)
        self.filterSeg:Select(cfg.filter)

        self:BuildSettings(p)

        -- Tuiles des zones -------------------------------------------------------------
        self.tscroll = UI:Scroll(p)
        self.tiles = UI:Pool(function()
            local t = CreateFrame("Button", nil, self.tscroll.child)
            t:SetSize(TILE_W, TILE_H)
            t.edge = UI:Rounded(t, 14, 0, "BACKGROUND", 0)
            t.bg = UI:Rounded(t, 13, 1, "BACKGROUND", 1)
            t.dots = {}
            for i = 1, DOTS do
                local d = t:CreateTexture(nil, "ARTWORK")
                d:SetTexture(UI.MEDIA .. "circle")
                d:SetSize(5, 5)
                local a = -math.pi / 2 + (i - 1) / DOTS * 2 * math.pi
                d:SetPoint("CENTER", t, "LEFT", 38 + math.cos(a) * 22, -math.sin(a) * 22)
                t.dots[i] = d
            end
            t.n = UI:Text(t, 10)
            t.n:SetPoint("CENTER", t, "LEFT", 38, 0)
            t.n:SetJustifyH("CENTER")
            t.name = UI:Text(t, 12)
            t.name:SetPoint("TOPLEFT", 72, -16)
            t.name:SetPoint("RIGHT", -10, 0)
            t.name:SetJustifyH("LEFT")
            t.sub = UI:Text(t, 10, C.muted)
            t.sub:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -3)
            t.tag = UI:Text(t, 10)
            t.tag:SetPoint("TOPLEFT", t.sub, "BOTTOMLEFT", 0, -3)
            t:SetScript("OnClick", function(s) self.zone = s.map; self:Refresh() end)
            return t
        end)

        -- Quêtes de la zone choisie ------------------------------------------------------
        local list = UI:Card(p)
        self.list = list
        self.lTitle = UI:Text(list, 14)
        self.lTitle:SetPoint("TOPLEFT", 14, -12)
        self.lSub = UI:Text(list, 11, C.muted)
        self.lSub:SetPoint("TOPRIGHT", -14, -14)
        self.lscroll = UI:Scroll(list)
        self.lscroll:SetPoint("TOPLEFT", 4, -38)
        self.lscroll:SetPoint("BOTTOMRIGHT", -4, 6)
        self.qrows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, self.lscroll.child)
            r:SetHeight(ROW_H)
            r.line = r:CreateTexture(nil, "BACKGROUND")
            r.line:SetPoint("BOTTOMLEFT", 8, 0); r.line:SetPoint("BOTTOMRIGHT", -8, 0); r.line:SetHeight(1)
            r.lv = UI:Text(r, 12)
            r.lv:SetPoint("LEFT", 8, 0)
            r.lv:SetWidth(26)
            r.lv:SetJustifyH("RIGHT")
            r.med = UI:Icon(r, "ring", 22, nil, "ARTWORK")
            r.med:SetPoint("LEFT", 42, 0)
            r.mark = UI:Icon(r, "bang", 12, nil, "OVERLAY")
            r.mark:SetPoint("CENTER", r.med, "CENTER")
            r.name = UI:Text(r, 13)
            r.name:SetPoint("TOPLEFT", 74, -6)
            r.name:SetPoint("RIGHT", -230, 0)
            r.name:SetJustifyH("LEFT")
            r.sub = UI:Text(r, 11, C.muted)
            r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("RIGHT", -230, 0)
            r.sub:SetJustifyH("LEFT")
            r.guide = UI:Button(r, "Guider", 70, 24, "secondary")
            r.guide:SetPoint("RIGHT", -10, 0)
            r.state = UI:Badge(r, "")
            r.state:SetPoint("RIGHT", r.guide, "LEFT", -8, 0)
            r:EnableMouse(true)
            r:SetScript("OnEnter", function(s)
                if not s.q then return end
                local q = s.q
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(Q:Name(q), 1, 0.82, 0)
                GameTooltip:AddDoubleLine(T("Niveau"), q.lvl .. (q.req and q.req > 0 and ("  (" .. T("requis") .. " " .. q.req .. ")") or ""), 0.6, 0.6, 0.6, 1, 1, 1)
                if (q.xp or 0) > 0 then GameTooltip:AddDoubleLine(T("Expérience"), tostring(q.xp), 0.6, 0.6, 0.6, 1, 1, 1) end
                -- persos qui l'ont faite
                local who = {}
                for key, c in pairs(WK.DB.global.characters) do
                    if c.quests and c.quests.done and c.quests.done[q.id] then table.insert(who, WK:CharName(c, key)) end
                end
                if #who > 0 then GameTooltip:AddLine(T("Faite par") .. " " .. table.concat(who, ", "), 0.56, 0.82, 0.54, true) end
                if q.nxt and Q:Get(q.nxt) then GameTooltip:AddLine(T("Suite :") .. " " .. Q:Name(Q:Get(q.nxt)), 0.6, 0.6, 0.6, true) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return r
        end)
        self.empty = UI:Text(self.lscroll.child, 12, C.muted)

        UI:OnResize(p, function() self:Layout(); self:Refresh() end)
        Q.OnChange = function() if p:IsVisible() then self:Refresh() end end
        self:Layout()
    end,

    -- Colonne de droite : réglages et légende
    BuildSettings = function(self, p)
        local qc = Q:Config()
        self.toggles = {}
        local side = UI:Scroll(p)
        self.side = side
        local root = side.child
        local y = 0
        local function card(title, h, subtitle)
            local c = UI:Card(root, title, subtitle)
            c:SetHeight(h)
            c:SetPoint("TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", 0, -y)
            y = y + h + GAP
            return c
        end
        local function toggle(parent, field)
            local t = UI:Toggle(parent, function() return qc[field] end,
                function(v) qc[field] = v; WK:NotifyChanged(); self:Refresh() end)
            table.insert(self.toggles, t)
            return t
        end

        local lcard = card("Quêtes montrées", 40 + 4 * 36 + 6, "d'après QuestieDB")
        UI:SettingRow(lcard, -40, "Quêtes de donjon", nil, toggle(lcard, "dungeons"), 50)
        UI:SettingRow(lcard, -76, "Quêtes trop hautes", nil, toggle(lcard, "high"), 50)
        UI:SettingRow(lcard, -112, "Métier : si le perso l'a", nil, toggle(lcard, "profOnly"), 50)
        UI:SettingRow(lcard, -148, "Classe : celles du perso", nil, toggle(lcard, "classOnly"), 50)

        local tcard = card("Infobulle", 40 + 36 + 34, "au survol d'un PNJ")
        UI:SettingRow(tcard, -40, "Quêtes du donneur", nil, toggle(tcard, "tooltip"), 50)
        local th = UI:Text(tcard, 10, C.dim)
        th:SetPoint("TOPLEFT", 16, -82)
        th:SetPoint("RIGHT", -16, 0)
        th:SetJustifyH("LEFT")
        th:SetText(T("Celles que ce perso n'a pas encore faites."))

        local states = { "avail", "log", "done", "high", "locked" }
        local gcard = card("Légende", 40 + #states * 24 + 8)
        for i, st in ipairs(states) do
            local col, label = stateInfo(st)
            local d = UI:Icon(gcard, "circle", 8, nil, "ARTWORK")
            d:SetPoint("TOPLEFT", 18, -44 - (i - 1) * 24)
            d:SetVertexColor(unpack(col))
            local l = UI:Text(gcard, 12)
            l:SetPoint("LEFT", d, "RIGHT", 10, 0)
            local txt = { avail = "Disponible", log = "Dans le journal", done = "Faite",
                          high = "Trop haute pour le perso", locked = "Après une autre quête" }
            l:SetText(T(txt[st]))
        end
        self.sideH = y
    end,

    Layout = function(self)
        local p = self.list:GetParent()
        local h = p:GetHeight() or 500
        if h < 100 then h = 500 end
        local top = 30 + GAP
        self.list:ClearAllPoints(); self.tscroll:ClearAllPoints(); self.side:ClearAllPoints()
        self.side:SetPoint("TOPRIGHT", 0, 0)
        self.side:SetPoint("BOTTOMRIGHT")
        self.side:SetWidth(SIDE_W)
        self.side.child:SetSize(SIDE_W - 8, self.sideH or 400)
        if self.side.UpdateBar then self.side:UpdateBar() end
        local th = math.floor((h - top) * 0.40)
        self.tscroll:SetPoint("TOPLEFT", 0, -top)
        self.tscroll:SetPoint("TOPRIGHT", -(SIDE_W + GAP), -top)
        self.tscroll:SetHeight(th)
        self.list:SetPoint("TOPLEFT", 0, -(top + th + GAP))
        self.list:SetPoint("BOTTOMRIGHT", -(SIDE_W + GAP), 0)
    end,

    Refresh = function(self)
        local cfg = Q:Config()
        for _, t in ipairs(self.toggles) do t:Refresh() end
        local key = self.viewKey or WK:CharKey()
        local c = WK.DB.global.characters[key] or {}
        local myLevel = c.level or 1
        local zones = Q:Zones(key)
        local playerZone = key == WK:CharKey() and Q:PlayerZone() or nil
        local best = Q:BestZone(key)
        self.zone = self.zone or playerZone or (best and best.map) or (zones[1] and zones[1].map)
        local r1, g1, b1 = UI:Accent()

        -- tuiles (ta zone, puis la zone conseillée, puis par niveau)
        self.tiles:Reset()
        local W = (self.tscroll:GetWidth() or 800)
        if W < 100 then W = 800 end
        local cols = math.max(1, math.floor((W - 14 + 10) / (TILE_W + 10)))
        local ordered = {}
        for _, z in ipairs(zones) do if z.map == playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if best and z.map == best.map and z.map ~= playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if z.map ~= playerZone and not (best and z.map == best.map) then table.insert(ordered, z) end end
        for i, z in ipairs(ordered) do
            local t = self.tiles:Get()
            t.map = z.map
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", col * (TILE_W + 10), -row * (TILE_H + 10))
            local sel = z.map == self.zone
            t.edge:SetColor(unpack(sel and { r1, g1, b1, 1 } or C.border))
            t.bg:SetColor(unpack(sel and C.surface2 or C.surface))
            local frac = z.total > 0 and z.done / z.total or 0
            local col2 = frac >= 1 and C.positive or { r1, g1, b1, 1 }
            for k, d in ipairs(t.dots) do
                d:SetVertexColor(unpack(((k - 0.5) / DOTS <= frac) and col2 or C.border))
            end
            t.n:SetText(z.done .. "/" .. z.total)
            t.name:SetText(z.name)
            t.sub:SetText(string.format(T("niveaux %d-%d"), z.min, z.max))
            if z.map == playerZone then
                t.tag:SetText(T("ta zone")); t.tag:SetTextColor(r1, g1, b1)
            elseif best and z.map == best.map then
                t.tag:SetText(T("conseillée pour monter")); t.tag:SetTextColor(unpack(C.positive))
            elseif z.avail > 0 then
                t.tag:SetText(string.format(T("%d à faire"), z.avail)); t.tag:SetTextColor(unpack(C.muted))
            else
                t.tag:SetText("")
            end
        end
        self.tscroll.child:SetSize(W, math.ceil(#ordered / cols) * (TILE_H + 10))
        if self.tscroll.UpdateBar then self.tscroll:UpdateBar() end

        -- quêtes de la zone choisie
        self.qrows:Reset()
        local all = self.zone and Q:OnMap(self.zone) or {}
        local LW = (self.lscroll:GetWidth() or 600)
        if LW < 100 then LW = 600 end
        local ly, shown, total = 0, 0, 0
        for _, q in ipairs(all) do
            if Q:ForChar(q, c) then
                total = total + 1
                local st, need = Q:State(q, c)
                local keep = (cfg.filter == "all" or (cfg.filter == "done" and st == "done") or (cfg.filter == "todo" and st ~= "done"))
                if st == "high" and not cfg.high then keep = false end
                if keep then
                    shown = shown + 1
                    local row = self.qrows:Get()
                    row.q = q
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -ly); row:SetWidth(LW - 14)
                    row.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
                    row.lv:SetText(q.lvl > 0 and tostring(q.lvl) or "-")
                    row.lv:SetTextColor(unpack(st == "done" and C.dim or levelColor(q.lvl, myLevel)))
                    local col, label = stateInfo(st)
                    row.med:SetVertexColor(unpack(col)); row.mark:SetVertexColor(unpack(col))
                    row.name:SetText(Q:Name(q))
                    row.name:SetTextColor(unpack(st == "done" and C.dim or C.text))
                    local parts = {}
                    if q.skill then table.insert(parts, "|cff9ed17a" .. T(q.skill) .. "|r")
                    elseif KIND[q.kind] then table.insert(parts, T(KIND[q.kind])) end
                    if st == "locked" and need and Q:Get(need) then table.insert(parts, string.format(T("après « %s »"), Q:Name(Q:Get(need))))
                    elseif st == "high" then table.insert(parts, string.format(T("niveau %d requis"), q.req)) end
                    if (q.xp or 0) > 0 then table.insert(parts, q.xp .. " XP") end
                    row.sub:SetText(table.concat(parts, "  ·  "))
                    row.state:Set(label, col)
                    row.guide:SetShown(q.x ~= nil and st ~= "done")
                    row.guide:SetScript("OnClick", function() Q:GuideTo(q) end)
                    ly = ly + ROW_H
                end
            end
        end
        local zname = self.zone and WK.modules.Rares:ZoneName(self.zone) or ""
        self.lTitle:SetText(zname .. "  |cff999999· " .. string.format(T("%d quêtes"), total) .. "|r")
        self.lSub:SetText(Q:Known(key) and T("triées par niveau") or T("connecte ce perso pour lire ses quêtes faites"))
        self.empty:SetShown(shown == 0)
        self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 14, -10)
        self.empty:SetText(total == 0 and T("Choisis une zone.") or T("Aucune quête pour ce filtre."))
        self.lscroll.child:SetSize(LW - 14, math.max(ly, 30))
        if self.lscroll.UpdateBar then self.lscroll:UpdateBar() end
    end,
})
