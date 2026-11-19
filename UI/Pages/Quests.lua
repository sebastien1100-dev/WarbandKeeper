local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Quêtes (Modules/Quests.lua), sur le modèle de la page Rares : une tuile par zone avec un
-- anneau de progression (ta zone en premier), les quêtes de la zone choisie en dessous, et à droite
-- les réglages et la légende. Collection par perso (« Quêtes de »).
local Q = WK.modules.Quests
local GAP, SIDE_W, ROW_H = 12, 300, 44

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
    if st == "high" then return C.negative, T("trop haute") end
    return C.tank, T("plus tard")
end
local KIND = { d = "Donjon", c = "Classe" }

-- Choix du menu des persos (rebâti à chaque rafraîchissement : persos renommés ou supprimés).
local function charOptions()
    local opts = {}
    for key, c in pairs(WK.DB.global.characters) do table.insert(opts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
    table.sort(opts, function(a, b) return a[2] < b[2] end)
    return opts
end

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
        local charOpts = charOptions()
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self.zone = nil; self:Refresh() end)
        self.charDd:SetPoint("TOPLEFT", of, "TOPRIGHT", 8, 9)
        self.charDd:Select(self.viewKey)
        self.filterSeg = UI:Segmented(p, { { "all", "Toutes" }, { "todo", "À faire" }, { "done", "Faites" } },
            function(v) cfg.filter = v; self:Refresh() end, 30)
        self.filterSeg:SetPoint("TOPLEFT", self.charDd, "TOPRIGHT", 8, 0)
        self.filterSeg:Select(cfg.filter)

        self:BuildSettings(p)
        -- roue dentée : réglages (quêtes montrées, légende) à la place des tuiles et de la liste
        local gear = UI:IconButton(p, "gear", 30, "Réglages des quêtes")
        gear:SetPoint("TOPRIGHT")
        gear:SetScript("OnClick", function() self.settingsOpen = not self.settingsOpen; self:Layout(); self:Refresh() end)
        self.gear = gear

        -- Bandeau de chiffres, carte du continent et liste des zones --------------------
        self.kpi = UI:KpiRow(p, 4, 74)
        self.map = UI:ZoneMap(p)
        self.zcard = UI:Card(p)
        self.zTitle = UI:Text(self.zcard, 12); self.zTitle:SetPoint("TOPLEFT", 14, -10)
        self.zscroll = UI:Scroll(self.zcard)
        self.zscroll:SetPoint("TOPLEFT", 4, -32); self.zscroll:SetPoint("BOTTOMRIGHT", -4, 6)
        self.zrows = UI:Pool(function() return UI:ZoneRow(self.zscroll.child, function(map) self.zone = map; self:Refresh() end) end)

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
            r.name:SetPoint("RIGHT", -190, 0)
            r.name:SetJustifyH("LEFT")
            r.sub = UI:Text(r, 11, C.muted)
            r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("RIGHT", -190, 0)
            r.sub:SetJustifyH("LEFT")
            r.guide = UI:GuideButton(r, 28, "Guider jusqu'au donneur de la quête")
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

    -- recherche de la barre latérale : un réglage des quêtes ouvre la roue
    RevealSetting = function(self, row)
        local f = row
        while f do
            if f == self.side then self.settingsOpen = true; self:Layout(); self:Refresh() return end
            f = f:GetParent()
        end
    end,

    Layout = function(self)
        local p = self.list:GetParent()
        local h = p:GetHeight() or 500
        if h < 100 then h = 500 end
        local top = 30 + GAP
        self.side:ClearAllPoints()
        local open = self.settingsOpen == true
        self.gear:SetActive(open)
        self.side:SetShown(open)
        -- réglages : sur toute la largeur, sous la barre
        self.side:SetPoint("TOPLEFT", 0, -top)
        self.side:SetPoint("BOTTOMRIGHT")
        local w = p:GetWidth() or 800
        self.side.child:SetSize(math.min((w > 100 and w or 800) - 10, 560), self.sideH or 400)
        if self.side.UpdateBar then self.side:UpdateBar() end
        UI:ZoneLayout(self, p, top, w, h, open)
    end,

    Refresh = function(self)
        local cfg = Q:Config()
        -- menu des persos à jour (perso renommé ou supprimé : retour au premier)
        self.charDd:SetOptions(charOptions())
        if self.charDd.selected ~= self.viewKey then
            if WK.DB.global.characters[self.viewKey] then self.charDd:Select(self.viewKey) else self.viewKey = self.charDd.selected end
        end
        for _, t in ipairs(self.toggles) do t:Refresh() end
        local key = self.viewKey or WK:CharKey()
        local c = WK.DB.global.characters[key] or {}
        local myLevel = c.level or 1
        local zones = Q:Zones(key)
        local playerZone = key == WK:CharKey() and Q:PlayerZone() or nil
        local best = Q:BestZone(key)
        self.zone = self.zone or playerZone or (best and best.map) or (zones[1] and zones[1].map)
        local r1, g1, b1 = UI:Accent()

        -- bandeau
        local qDone, qTotal = Q:Totals(key)
        local accent = { r1, g1, b1 }
        self.kpi:Set(1, { label = string.format(T("QUÊTES FAITES · %s"), WK:CharName(c, key)), value = qDone .. UI:Hex(C.muted) .. " / " .. qTotal .. "|r",
            sub = qTotal > 0 and string.format(T("%d %% du total pour ce perso"), math.floor(qDone / qTotal * 100 + 0.5)) or "",
            frac = qTotal > 0 and qDone / qTotal or 0, color = accent })
        local X = WK.modules.XP
        local pend = key == WK:CharKey() and X and X.Pending and X:Pending() or {}
        local pxp = 0
        for _, e in ipairs(pend) do pxp = pxp + (e.xp or 0) end
        self.kpi:Set(2, { label = T("À RENDRE"), value = tostring(#pend), color = #pend > 0 and C.positive or C.muted,
            sub = #pend > 0 and string.format(T("%s XP · clic : guider"), BreakUpLargeNumbers and BreakUpLargeNumbers(pxp) or pxp) or T("rien à rendre"),
            onClick = #pend > 0 and function() X:GuideNearest() end or nil })
        local near, nearZones = 0, 0
        for _, z in ipairs(zones) do
            local zn = 0
            for _, q in ipairs(Q:OnMap(z.map)) do
                if (q.lvl or 0) >= myLevel - 3 and (q.lvl or 0) <= myLevel + 3 and Q:ForChar(q, c) and Q:State(q, c) == "avail" then zn = zn + 1 end
            end
            near = near + zn
            if zn > 0 then nearZones = nearZones + 1 end
        end
        self.kpi:Set(3, { label = string.format(T("POUR TON NIVEAU (%d)"), myLevel), value = tostring(near), color = C.gold,
            sub = string.format(T("quêtes disponibles dans %d zones"), nearZones) })
        self.kpi:Set(4, { label = T("ZONE CONSEILLÉE"), value = best and best.name or "-", color = C.positive,
            sub = best and string.format(T("%d à faire · niveaux %d-%d"), best.avail, best.min, best.max) or T("aucune pour l'instant"),
            onClick = best and function() self.zone = best.map; self:Refresh() end or nil })

        -- carte du continent : une bulle par zone, couleur et taille = avancement
        for _, z in ipairs(zones) do z.frac = z.total > 0 and z.done / z.total or 0 end
        self.map:SetData(zones, {
            selected = self.zone, player = playerZone, best = best and best.map,
            color = function(z)
                if z.frac >= 1 then return C.positive end
                if z.frac >= 0.5 then return C.positive end
                if z.frac >= 0.15 then return C.gold end
                if z.frac > 0 then return accent end
                return C.dim
            end,
            onClick = function(map) self.zone = map; self:Refresh() end,
            tip = function(z, tt)
                tt:AddDoubleLine(T("Quêtes faites"), z.done .. " / " .. z.total, 0.7, 0.7, 0.7, 1, 1, 1)
                tt:AddDoubleLine(T("Niveaux"), z.min .. "-" .. z.max, 0.7, 0.7, 0.7, 1, 1, 1)
                if z.avail > 0 then tt:AddDoubleLine(T("Disponibles"), tostring(z.avail), 0.7, 0.7, 0.7, 1, 1, 1) end
            end,
        })
        self.map.legend:SetText(T("taille et couleur = avancement · clic : voir la zone"))

        -- liste des zones (ta zone, la conseillée, puis par niveau)
        local ordered = {}
        for _, z in ipairs(zones) do if z.map == playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if best and z.map == best.map and z.map ~= playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if z.map ~= playerZone and not (best and z.map == best.map) then table.insert(ordered, z) end end
        self.zrows:Reset()
        local ZW = (self.zscroll:GetWidth() or 400)
        if ZW < 100 then ZW = 400 end
        for i, z in ipairs(ordered) do
            local r = self.zrows:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(i - 1) * UI.ZONE_ROW_H); r:SetWidth(ZW - 14)
            local tag
            if z.map == playerZone then tag = { T("ta zone"), accent }
            elseif best and z.map == best.map then tag = { T("conseillée"), C.positive } end
            r:Fill(z, { selected = z.map == self.zone, frac = z.frac, color = accent, tag = tag, level = myLevel,
                right = z.avail > 0 and string.format(T("%d à faire"), z.avail) or (z.done >= z.total and T("finie") or "") })
        end
        self.zTitle:SetText(string.format(T("Zones · %d"), #ordered))
        self.zscroll.child:SetSize(ZW - 14, #ordered * UI.ZONE_ROW_H)
        if self.zscroll.UpdateBar then self.zscroll:UpdateBar() end

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
                    if q.skill then table.insert(parts, UI:Hex(C.positive) .. T(q.skill) .. "|r")
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
        self.lTitle:SetText(zname .. "  " .. UI:Hex(C.muted) .. "· " .. string.format(T("%d quêtes"), total) .. "|r")
        self.lSub:SetText(Q:Known(key) and T("triées par niveau") or T("connecte ce perso pour lire ses quêtes faites"))
        self.empty:SetShown(shown == 0)
        self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 14, -10)
        self.empty:SetText(total == 0 and T("Choisis une zone.") or T("Aucune quête pour ce filtre."))
        self.lscroll.child:SetSize(LW - 14, math.max(ly, 30))
        if self.lscroll.UpdateBar then self.lscroll:UpdateBar() end
    end,
})
