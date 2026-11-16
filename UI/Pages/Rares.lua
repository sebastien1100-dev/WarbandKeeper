local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Rares (Modules/Rares.lua) : la collection des rares, perso par perso.
--   vue « Zones »      : à gauche ta zone et les zones par continent avec leur progression,
--                        à droite les rares de la zone choisie ;
--   vue « Collection » : une tuile par zone avec un anneau de progression, les rares de la zone
--                        choisie en dessous.
local R = WK.modules.Rares
local GAP, LEFT_W, ROW_H = 12, 300, 44
local TILE_W, TILE_H = 214, 74
local DOTS = 28 -- points de l'anneau de progression

-- Couleur du niveau d'un rare pour un perso (comme la difficulté des quêtes)
-- Durée courte : « 5 min », « 3 h », « 2 j »
local function short(sec)
    sec = math.max(0, sec or 0)
    if sec < 3600 then return string.format(T("%d min"), math.max(1, math.floor(sec / 60))) end
    if sec < 86400 then return string.format(T("%d h"), math.floor(sec / 3600)) end
    return string.format(T("%d j"), math.floor(sec / 86400))
end

local function levelColor(lvl, me)
    local d = (lvl or 0) - (me or 1)
    if d >= 5 then return C.negative end
    if d >= 3 then return C.warning end
    if d >= -2 then return C.gold end
    if d >= -8 then return C.positive end
    return C.dim
end

UI:RegisterPage({
    key = "rares", order = 9, nav = "Rares",

    Build = function(self, p)
        local cfg = R:Config()
        self.viewKey = WK:CharKey()
        self.zone = R:PlayerZone()

        -- Barre de commandes ---------------------------------------------------------
        self.viewSeg = UI:Segmented(p, { { "zones", "Zones" }, { "tiles", "Collection" } },
            function(v) cfg.view = v; self:Layout(); self:Refresh() end, 30)
        self.viewSeg:SetPoint("TOPLEFT")
        self.viewSeg:Select(cfg.view or "zones")
        self.hideBtn = UI:Button(p, "Masquer les tués", 150, 30, "ghost")
        self.hideBtn:SetPoint("TOPRIGHT")
        self.hideBtn:SetScript("OnClick", function() cfg.pageHideKilled = not cfg.pageHideKilled; self:Refresh() end)
        local charOpts = {}
        for key, c in pairs(WK.DB.global.characters) do table.insert(charOpts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
        table.sort(charOpts, function(a, b) return a[2] < b[2] end)
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self:Refresh() end)
        self.charDd:SetPoint("RIGHT", self.hideBtn, "LEFT", -8, 0)
        self.charDd:Select(self.viewKey)
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("RIGHT", self.charDd, "LEFT", -8, 0)
        of:SetText(T("Collection de"))

        -- Vue Zones : colonne de gauche ------------------------------------------------
        local left = UI:Card(p)
        left:SetWidth(LEFT_W)
        self.left = left
        self.cur = CreateFrame("Button", nil, left)
        self.cur:SetPoint("TOPLEFT", 10, -10)
        self.cur:SetPoint("TOPRIGHT", -10, -10)
        self.cur:SetHeight(78)
        self.cur.edge = UI:Rounded(self.cur, 10, 0, "BACKGROUND", 0)
        self.cur.bg = UI:Rounded(self.cur, 9, 1, "BACKGROUND", 1)
        self.cur.name = UI:Text(self.cur, 13)
        self.cur.name:SetPoint("TOPLEFT", 12, -10)
        self.cur.tag = UI:Text(self.cur, 10, C.muted)
        self.cur.tag:SetPoint("TOPRIGHT", -12, -12)
        self.cur.tag:SetText(T("ta zone"))
        self.cur.count = UI:Text(self.cur, 22)
        self.cur.count:SetPoint("TOPLEFT", self.cur.name, "BOTTOMLEFT", 0, -4)
        self.cur.lv = UI:Text(self.cur, 11, C.muted)
        self.cur.lv:SetPoint("BOTTOMLEFT", self.cur.count, "BOTTOMRIGHT", 8, 3)
        self.cur.bar = UI:Progress(self.cur, 4)
        self.cur.bar:SetPoint("BOTTOMLEFT", 12, 10)
        self.cur.bar:SetPoint("BOTTOMRIGHT", -12, 10)
        self.cur:SetScript("OnClick", function() self.zone = R:PlayerZone(); self:Refresh() end)
        self.zscroll = UI:Scroll(left)
        self.zscroll:SetPoint("TOPLEFT", 6, -98)
        self.zscroll:SetPoint("BOTTOMRIGHT", -6, 8)
        self.zrows = UI:Pool(function()
            local b = CreateFrame("Button", nil, self.zscroll.child)
            b:SetHeight(30)
            b.bg = UI:Rounded(b, 8, 0, "BACKGROUND", 1)
            b.name = UI:Text(b, 12)
            b.name:SetPoint("LEFT", 10, 0)
            b.name:SetPoint("RIGHT", -60, 0)
            b.name:SetJustifyH("LEFT")
            b.n = UI:Text(b, 11, C.muted)
            b.n:SetPoint("RIGHT", -10, 0)
            b:SetScript("OnEnter", function(s) if not s.sel then s.bg:SetColor(unpack(C.hover)); s.bg:Show() end end)
            b:SetScript("OnLeave", function(s) if not s.sel then s.bg:Hide() end end)
            b:SetScript("OnClick", function(s) self.zone = s.map; self:Refresh() end)
            return b
        end)
        self.zheads = UI:Pool(function()
            local t = UI:Text(self.zscroll.child, 10, C.dim)
            return t
        end)

        -- Vue Collection : tuiles ------------------------------------------------------
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
            t.n = UI:Text(t, 11)
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

        -- Rares de la zone (les deux vues) -----------------------------------------------
        local list = UI:Card(p)
        self.list = list
        self.lTitle = UI:Text(list, 14)
        self.lTitle:SetPoint("TOPLEFT", 14, -12)
        self.lSub = UI:Text(list, 11, C.muted)
        self.lSub:SetPoint("TOPRIGHT", -14, -14)
        self.lscroll = UI:Scroll(list)
        self.lscroll:SetPoint("TOPLEFT", 4, -38)
        self.lscroll:SetPoint("BOTTOMRIGHT", -4, 6)
        self.rrows = UI:Pool(function()
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
            r.star = UI:Icon(r, "star", 11, nil, "OVERLAY")
            r.star:SetPoint("CENTER", r.med, "CENTER")
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
                if not s.r then return end
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(R:Name(s.r), C.rare[1], C.rare[2], C.rare[3])
                local loot = R:Loot(s.r.id)
                for i, l in ipairs(loot) do
                    if i > 5 then break end
                    GameTooltip:AddDoubleLine(WK.GetItemInfo(l.id) or ("#" .. l.id), l.prof and T(l.prof) or "", 1, 1, 1, 0.6, 0.6, 0.6)
                end
                local k = R:Killed(s.r.id) or {}
                local who = {}
                for key, at in pairs(k) do
                    local c = WK.DB.global.characters[key]
                    if c then table.insert(who, WK:CharName(c, key) .. " (" .. string.format(T("il y a %s"), short(time() - at)) .. ")") end
                end
                if #who > 0 then GameTooltip:AddLine(T("Tué par") .. " " .. table.concat(who, ", "), 0.56, 0.82, 0.54, true) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return r
        end)
        self.empty = UI:Text(self.lscroll.child, 12, C.muted)

        UI:OnResize(p, function() self:Layout(); self:Refresh() end)
        self:Layout()
    end,

    -- Place les blocs selon la vue
    Layout = function(self)
        local p = self.left:GetParent()
        local h = p:GetHeight() or 500
        if h < 100 then h = 500 end
        local top = 30 + GAP
        self.left:ClearAllPoints(); self.list:ClearAllPoints(); self.tscroll:ClearAllPoints()
        if (R:Config().view or "zones") == "tiles" then
            self.left:Hide(); self.tscroll:Show()
            local th = math.floor((h - top) * 0.46)
            self.tscroll:SetPoint("TOPLEFT", 0, -top)
            self.tscroll:SetPoint("TOPRIGHT", 0, -top)
            self.tscroll:SetHeight(th)
            self.list:SetPoint("TOPLEFT", 0, -(top + th + GAP))
            self.list:SetPoint("BOTTOMRIGHT")
        else
            self.left:Show(); self.tscroll:Hide()
            self.left:SetPoint("TOPLEFT", 0, -top)
            self.left:SetPoint("BOTTOMLEFT")
            self.list:SetPoint("TOPLEFT", LEFT_W + GAP, -top)
            self.list:SetPoint("BOTTOMRIGHT")
        end
    end,

    Refresh = function(self)
        local cfg = R:Config()
        if self.lastView ~= (cfg.view or "zones") then
            self.lastView = cfg.view or "zones"
            self.viewSeg:Select(self.lastView)
            self:Layout()
        end
        local key = self.viewKey or WK:CharKey()
        local c = WK.DB.global.characters[key] or {}
        local myLevel = c.level or UnitLevel("player") or 1
        local zones = R:Zones(key)
        local playerZone = R:PlayerZone()
        self.zone = self.zone or playerZone or (zones[1] and zones[1].map)
        local r1, g1, b1 = UI:Accent()
        self.hideBtn.label:SetText(cfg.pageHideKilled and T("Montrer les tués") or T("Masquer les tués"))

        -- zone du joueur en grand
        local pz
        for _, z in ipairs(zones) do if z.map == playerZone then pz = z end end
        self.cur:SetShown(pz ~= nil)
        if pz then
            self.cur.edge:SetColor(r1, g1, b1, 1); self.cur.bg:SetColor(unpack(self.zone == pz.map and C.surface2 or C.surface))
            self.cur.name:SetText(pz.name)
            self.cur.count:SetText(pz.killed .. " / " .. pz.total)
            self.cur.lv:SetText(string.format(T("niveaux %d-%d"), pz.min, pz.max))
            self.cur.bar:SetValue(pz.total > 0 and pz.killed / pz.total or 0)
        end
        -- liste des zones par continent
        self.zrows:Reset(); self.zheads:Reset()
        local y, lastCont = 0, nil
        local contTotals = {}
        for _, z in ipairs(zones) do
            local t = contTotals[z.contName] or { 0, 0 }
            t[1], t[2] = t[1] + z.killed, t[2] + z.total
            contTotals[z.contName] = t
        end
        local zw = LEFT_W - 24
        for _, z in ipairs(zones) do
            if z.contName ~= lastCont then
                lastCont = z.contName
                local hd = self.zheads:Get()
                hd:ClearAllPoints(); hd:SetPoint("TOPLEFT", 8, -(y + 10))
                local t = contTotals[z.contName]
                hd:SetText(string.upper(z.contName) .. "  ·  " .. t[1] .. " / " .. t[2])
                hd:Show()
                y = y + 30
            end
            local b = self.zrows:Get()
            b.map = z.map
            b.sel = self.zone == z.map
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetWidth(zw)
            b.name:SetText(z.name)
            local done = z.killed >= z.total
            b.n:SetText(z.killed .. " / " .. z.total .. (done and "  •" or ""))
            b.n:SetTextColor(unpack(done and C.positive or C.muted))
            b.bg:SetColor(unpack(C.surface2)); b.bg:SetShown(b.sel)
            y = y + 32
        end
        self.zscroll.child:SetSize(zw, y + 6)
        if self.zscroll.UpdateBar then self.zscroll:UpdateBar() end

        -- tuiles
        self.tiles:Reset()
        local W = (self.tscroll:GetWidth() or 800)
        if W < 100 then W = 800 end
        local cols = math.max(1, math.floor((W - 14 + 10) / (TILE_W + 10)))
        -- ta zone en premier
        local ordered = {}
        for _, z in ipairs(zones) do if z.map == playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if z.map ~= playerZone then table.insert(ordered, z) end end
        for i, z in ipairs(ordered) do
            local t = self.tiles:Get()
            t.map = z.map
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", col * (TILE_W + 10), -row * (TILE_H + 10))
            local cur = z.map == playerZone
            local sel = z.map == self.zone
            t.edge:SetColor(unpack((cur or sel) and { r1, g1, b1, 1 } or C.border))
            t.bg:SetColor(unpack(sel and C.surface2 or C.surface))
            local frac = z.total > 0 and z.killed / z.total or 0
            local col2 = frac >= 1 and C.positive or { r1, g1, b1, 1 }
            for k, d in ipairs(t.dots) do
                local on = (k - 0.5) / DOTS <= frac
                d:SetVertexColor(unpack(on and col2 or C.border))
            end
            t.n:SetText(z.killed .. "/" .. z.total)
            t.name:SetText(z.name)
            t.sub:SetText(string.format(T("niveaux %d-%d"), z.min, z.max))
            t.tag:SetText(cur and T("ta zone") or "")
            t.tag:SetTextColor(r1, g1, b1)
        end
        self.tscroll.child:SetSize(W, math.ceil(#zones / cols) * (TILE_H + 10))
        if self.tscroll.UpdateBar then self.tscroll:UpdateBar() end

        -- rares de la zone choisie
        self.rrows:Reset()
        local rares = self.zone and R:OnMap(self.zone) or {}
        self.lTitle:SetText((self.zone and R:ZoneName(self.zone) or "") .. "  |cff999999· " .. string.format(T("%d rares"), #rares) .. "|r")
        self.lSub:SetText(T("trié par niveau"))
        local LW = (self.lscroll:GetWidth() or 600)
        if LW < 100 then LW = 600 end
        local ly = 0
        for _, r in ipairs(rares) do
            local killedAt = R:Killed(r.id, key)
            if not (cfg.pageHideKilled and killedAt) then
                local row = self.rrows:Get()
                row.r = r
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -ly); row:SetWidth(LW - 14)
                row.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
                row.lv:SetText(tostring(r.min))
                row.lv:SetTextColor(unpack(levelColor(r.min, myLevel)))
                local mc = r.elite and C.gold or C.rare
                row.med:SetVertexColor(unpack(killedAt and C.dim or mc)); row.star:SetVertexColor(unpack(killedAt and C.dim or mc))
                row.name:SetText(R:Name(r) .. (r.elite and ("  |cffe0bd72" .. T("élite") .. "|r") or ""))
                row.name:SetTextColor(unpack(killedAt and C.dim or C.text))
                -- détail : butin utile, sinon qui d'autre l'a tué
                local loot = R:Loot(r.id)
                local sub
                for _, l in ipairs(loot) do
                    if l.prof and #l.who > 0 then sub = (WK.GetItemInfo(l.id) or "") .. "  |cff9ed17a· " .. T(l.prof) .. " (" .. table.concat(l.who, ", ") .. ")|r" break end
                end
                if not sub and loot[1] then sub = WK.GetItemInfo(loot[1].id) or "" end
                if not sub then
                    local others = {}
                    for k2 in pairs(R:Killed(r.id) or {}) do
                        if k2 ~= key and WK.DB.global.characters[k2] then table.insert(others, WK:CharName(WK.DB.global.characters[k2], k2)) end
                    end
                    sub = #others > 0 and (T("tué par") .. " " .. table.concat(others, ", ")) or T("aucun butin notable")
                end
                row.sub:SetText(sub)
                if killedAt then row.state:Set(string.format(T("tué il y a %s"), short(time() - killedAt)), C.positive)
                else row.state:Set(T("pas tué"), C.muted) end
                row.guide:SetScript("OnClick", function() R:GuideTo(r) end)
                ly = ly + ROW_H
            end
        end
        self.empty:SetShown(ly == 0)
        self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 14, -10)
        self.empty:SetText(#rares == 0 and T("Choisis une zone.") or T("Tous les rares de cette zone sont tués."))
        self.lscroll.child:SetSize(LW - 14, math.max(ly, 30))
        if self.lscroll.UpdateBar then self.lscroll:UpdateBar() end
    end,
})
