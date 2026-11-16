local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Rares (Modules/Rares.lua) : la collection des rares, perso par perso.
--   une tuile par zone avec un anneau de progression (ta zone en premier), les rares de la zone
--   choisie en dessous, et à droite les réglages (carte, infobulle, alerte avec aperçu en direct).
local R = WK.modules.Rares
local GAP, SIDE_W, ROW_H = 12, 300, 44
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
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("TOPLEFT", 0, -9)
        of:SetText(T("Collection de"))
        local charOpts = {}
        for key, c in pairs(WK.DB.global.characters) do table.insert(charOpts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
        table.sort(charOpts, function(a, b) return a[2] < b[2] end)
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self:Refresh() end)
        self.charDd:SetPoint("TOPLEFT", of, "TOPRIGHT", 8, 9)
        self.charDd:Select(self.viewKey)
        self.hideBtn = UI:Button(p, "Masquer les tués", 150, 30, "ghost")
        self.hideBtn:SetPoint("TOPLEFT", self.charDd, "TOPRIGHT", 8, 0)
        self.hideBtn:SetScript("OnClick", function() cfg.pageHideKilled = not cfg.pageHideKilled; self:Refresh() end)

        self:BuildSettings(p)

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

        -- Rares de la zone choisie -------------------------------------------------------
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

    -- Colonne de réglages à droite (mêmes réglages que l'ancienne section QoL > Rares)
    BuildSettings = function(self, p)
        local rc = R:Config()
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
        local function toggle(parent, field, after)
            local t = UI:Toggle(parent, function() return rc[field] end,
                function(v) rc[field] = v; if after then after() end; WK:NotifyChanged() end)
            table.insert(self.toggles, t)
            return t
        end
        local function redraw() if UI.RedrawRarePins then UI:RedrawRarePins() end end

        local mcard = card("Carte et infobulle", 40 + 4 * 36 + 6, "d'après QuestieDB")
        UI:SettingRow(mcard, -40, "Médaillons sur la carte", nil, toggle(mcard, "map", redraw), 50)
        UI:SettingRow(mcard, -76, "Masquer les tués sur la carte", nil, toggle(mcard, "hideKilled", redraw), 50)
        UI:SettingRow(mcard, -112, "Liste à côté de la carte", nil, toggle(mcard, "list", redraw), 50)
        UI:SettingRow(mcard, -148, "Infobulle d'un rare", nil, toggle(mcard, "tooltip"), 50)

        local acard = card("Alerte « Rare en vue »", 40 + 3 * 36 + 112 + 44, "à l'écran")
        UI:SettingRow(acard, -40, "Alerte", nil, toggle(acard, "alert"), 50)
        UI:SettingRow(acard, -76, "Son de l'alerte", nil, toggle(acard, "sound"), 50)
        local preview, box, prevState = nil, nil, "new"
        local function fill()
            local st = rc.alertStyle or "banner"
            local sc = st == "compact" and 0.76 or 0.54
            preview:SetScale(sc)
            preview:ClearAllPoints()
            preview:SetPoint("CENTER", box, "BOTTOM", 0, 37 / sc) -- décalage en unités de l'aperçu réduit
            preview:Fill(prevState, st)
        end
        local styleSeg = UI:Segmented(acard, { { "banner", "Bandeau" }, { "compact", "Compact" } },
            function(v) rc.alertStyle = v; if preview then fill() end end, 24)
        styleSeg:Select(rc.alertStyle or "banner")
        UI:SettingRow(acard, -112, "Style", nil, styleSeg, 150)
        -- aperçu en direct, avec trois états à essayer
        box = CreateFrame("Frame", nil, acard)
        box:SetPoint("TOPLEFT", 12, -152)
        box:SetPoint("TOPRIGHT", -12, -152)
        box:SetHeight(104)
        box.bg = UI:Rounded(box, 10, 0, "BACKGROUND", 1)
        box.bg:SetColor(unpack(C.inset))
        local stateSeg = UI:Segmented(box, { { "new", "Pas tué" }, { "killed", "Déjà tué" }, { "elite", "Élite" } },
            function(v) prevState = v; fill() end, 22)
        stateSeg:SetPoint("TOP", 0, -8)
        stateSeg:Select("new")
        preview = UI:RareAlertPreview(box)
        fill()
        self.preview = fill
        local tb = UI:Button(acard, "Montrer à l'écran", 150, 26, "ghost")
        tb:SetPoint("BOTTOMRIGHT", -12, 10)
        tb:SetScript("OnClick", function() UI:TestRareAlert(prevState) end)
        local hint = UI:Text(acard, 10, C.dim)
        hint:SetPoint("BOTTOMLEFT", 14, 18)
        hint:SetText(T("Se place en mode édition."))
        self.sideH = y
    end,

    -- Tuiles en haut, liste en dessous, réglages à droite
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
        local th = math.floor((h - top) * 0.46)
        self.tscroll:SetPoint("TOPLEFT", 0, -top)
        self.tscroll:SetPoint("TOPRIGHT", -(SIDE_W + GAP), -top)
        self.tscroll:SetHeight(th)
        self.list:SetPoint("TOPLEFT", 0, -(top + th + GAP))
        self.list:SetPoint("BOTTOMRIGHT", -(SIDE_W + GAP), 0)
    end,

    Refresh = function(self)
        local cfg = R:Config()
        local key = self.viewKey or WK:CharKey()
        local c = WK.DB.global.characters[key] or {}
        local myLevel = c.level or UnitLevel("player") or 1
        local zones = R:Zones(key)
        local playerZone = R:PlayerZone()
        self.zone = self.zone or playerZone or (zones[1] and zones[1].map)
        local r1, g1, b1 = UI:Accent()
        for _, t in ipairs(self.toggles) do t:Refresh() end
        self.hideBtn.label:SetText(cfg.pageHideKilled and T("Montrer les tués") or T("Masquer les tués"))

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
        self.tscroll.child:SetSize(W, math.ceil(#ordered / cols) * (TILE_H + 10))
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
