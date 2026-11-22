local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Rares (Modules/Rares.lua) : la collection des rares, perso par perso.
--   onglet « Collection » : une tuile par zone avec un anneau de progression (ta zone en premier),
--                           les rares de la zone choisie en dessous ;
--   roue dentée : les réglages (carte, alerte avec aperçu en direct ; infobulle : Options > Infobulles).
local R = WK.modules.Rares
local GAP, ROW_H = 12, 44

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

-- Choix du menu des persos (rebâti à chaque rafraîchissement : persos renommés ou supprimés).
local function charOptions()
    local opts = {}
    for key, c in pairs(WK.DB.global.characters) do table.insert(opts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
    table.sort(opts, function(a, b) return a[2] < b[2] end)
    return opts
end

UI:RegisterPage({
    key = "rares", order = 9, nav = "Rares",

    Build = function(self, p)
        local cfg = R:Config()
        self.viewKey = WK:CharKey()
        self.zone = R:PlayerZone()

        -- Onglets et barre de commandes ----------------------------------------------
        self.tab = "collection"
        self.tabSeg = UI:Segmented(p, { { "collection", "Collection" } },
            function(v) self.tab = v; self:Layout(); self:Refresh() end, 30)
        self.tabSeg:SetPoint("TOPLEFT")
        self.tabSeg:Select("collection")
        -- roue dentée : réglages (carte, alerte) ; un second clic revient à la collection
        local gear = UI:IconButton(p, "gear", 30, "Réglages des rares")
        gear:SetPoint("TOPRIGHT")
        gear:SetScript("OnClick", function() self:ShowSection(self.tab == "settings" and "collection" or "settings") end)
        self.gear = gear
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("TOPRIGHT", -(190 + 8 + 150 + 8 + 38), -9)
        of:SetText(T("Collection de"))
        self.ofLabel = of
        local charOpts = charOptions()
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self:Refresh() end)
        self.charDd:SetPoint("TOPRIGHT", -(150 + 8 + 38), 0)
        self.charDd:Select(self.viewKey)
        self.hideBtn = UI:Button(p, "Masquer les tués", 150, 30, "ghost")
        self.hideBtn:SetPoint("TOPRIGHT", -38, 0)
        self.hideBtn:SetScript("OnClick", function() cfg.pageHideKilled = not cfg.pageHideKilled; self:Refresh() end)

        self:BuildSettings(p)

        -- Vue Collection : bandeau de chiffres, carte du continent et liste des zones -------
        self.kpi = UI:KpiRow(p, 4, 74)
        self.map = UI:ZoneMap(p)
        self.zcard = UI:Card(p)
        self.zTitle = UI:Text(self.zcard, 12); self.zTitle:SetPoint("TOPLEFT", 14, -10)
        self.zscroll = UI:Scroll(self.zcard)
        self.zscroll:SetPoint("TOPLEFT", 4, -32); self.zscroll:SetPoint("BOTTOMRIGHT", -4, 6)
        self.zrows = UI:Pool(function() return UI:ZoneRow(self.zscroll.child, function(map) self.zone = map; self:Refresh() end) end)

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
            r.name:SetPoint("TOPRIGHT", -190, -6)
            r.name:SetJustifyH("LEFT")
            r.sub = UI:Text(r, 11, C.muted)
            r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -3)
            r.sub:SetJustifyH("LEFT")
            r.guide = UI:GuideButton(r, 28, "Guider jusqu'au point d'apparition le plus proche")
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

    -- Réglages (roue dentée) : carte et alerte
    BuildSettings = function(self, p)
        local rc = R:Config()
        self.toggles = {}
        local sc = UI:Scroll(p)
        self.side = sc
        local root = sc.child
        root:SetSize(math.max(400, (UI.PAGE_W or 840) - 10), 400) -- largeur connue avant de poser les réglages
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

        local mcard = card("Sur la carte", 40 + 4 * 46 + 8, "monstres rares de WoW Forever, d'après QuestieDB")
        UI:SettingRow(mcard, -40, "Sur la carte du monde", "Un médaillon par rare (mauve, doré pour un élite, grisé si ce perso l'a tué). Au survol : apparitions et patrouille.", toggle(mcard, "map", redraw), 80)
        UI:SettingRow(mcard, -86, "Masquer les rares tués sur la carte", "Ceux que ce perso a déjà tués disparaissent de la carte.", toggle(mcard, "hideKilled", redraw), 80)
        UI:SettingRow(mcard, -132, "Liste des rares de la zone", "Sur le côté de la carte du monde, avec le guidage en un clic.", toggle(mcard, "list", redraw), 80)
        UI:SettingRow(mcard, -178, "Patrouilles des rares sur la carte", "Le trajet de chaque rare qui se déplace, en pointillés de sa couleur, toujours affiché (sinon : seulement au survol de son médaillon).", toggle(mcard, "paths", redraw), 80)

        local acard = card("Alerte « Rare en vue »", 40 + 4 * 46 + 182, "quand un rare entre dans ton champ de vision")
        UI:SettingRow(acard, -40, "Alerte", "Se place en mode édition.", toggle(acard, "alert"), 80)
        UI:SettingRow(acard, -86, "Son de l'alerte", nil, toggle(acard, "sound"), 80)
        UI:SettingRow(acard, -132, "Tête de mort sur le rare guidé", "En cliquant sur Guider dans l'alerte : le marqueur tête de mort du jeu est posé sur le rare (en raid, il faut être chef ou assistant).", toggle(acard, "skull"), 80)
        local preview, prevState = nil, "new"
        local styleSeg = UI:Segmented(acard, { { "banner", "Bandeau" }, { "compact", "Compact" } },
            function(v) rc.alertStyle = v; if preview then preview:Fill(prevState, v) end end, 26)
        styleSeg:Select(rc.alertStyle or "banner")
        UI:SettingRow(acard, -178, "Style", "Bandeau : portrait, butin et flèche de guidage. Compact : une ligne, clic pour guider.", styleSeg, 200)
        -- aperçu en direct, avec trois états à essayer
        local box = CreateFrame("Frame", nil, acard)
        box:SetPoint("TOPLEFT", 16, -224)
        box:SetPoint("TOPRIGHT", -16, -224)
        box:SetHeight(124)
        box.bg = UI:Rounded(box, 10, 0, "BACKGROUND", 1)
        box.bg:SetColor(unpack(C.inset))
        local stateSeg = UI:Segmented(box, { { "new", "Pas tué" }, { "killed", "Déjà tué" }, { "elite", "Élite" } },
            function(v) prevState = v; preview:Fill(v, rc.alertStyle) end, 22)
        stateSeg:SetPoint("TOPRIGHT", -8, -8)
        stateSeg:Select("new")
        local ph = UI:Text(box, 10, C.dim)
        ph:SetPoint("TOPLEFT", 10, -12)
        ph:SetText(T("APERÇU"))
        preview = UI:RareAlertPreview(box)
        preview:SetPoint("BOTTOM", 0, 10)
        preview:Fill("new", rc.alertStyle or "banner")
        local tb = UI:Button(acard, "Montrer à l'écran", 150, 26, "ghost")
        tb:SetPoint("BOTTOMRIGHT", -14, 10)
        tb:SetScript("OnClick", function() UI:TestRareAlert(prevState) end)
        -- sous-onglets de catégories (UI:CardTabs) : barre en haut, cartes de l'onglet dessous
        self.rcards = { mcard, acard }
        self.ct = UI:CardTabs(root, "rares", {
            { "map", T("Carte"), titles = { "Sur la carte" } },
            { "alert", T("Alerte"), titles = { "Alerte « Rare en vue »" } },
        }, function() self:PlaceCards() end)
        self:PlaceCards()
        -- pour la recherche de la barre latérale (UI/Search.lua) : un réglage trouvé ouvre cet onglet
        self.sections = { settings = { scroll = sc } }
        UI:OnResize(sc, function(w) root:SetSize(math.max(w - 10, 100), self.sideH) end)
        local prevReveal = self.RevealSetting
        self.RevealSetting = function(d, row)
            local f = row
            while f do
                if f:GetParent() == root and d.ct:Reveal(f) then d:PlaceCards() break end
                f = f:GetParent()
            end
            if prevReveal then prevReveal(d, row) end
        end
    end,

    PlaceCards = function(self)
        local list = self.ct:Filter(self.rcards)
        local y = 0
        if self.ct.bar then
            self.ct.bar:ClearAllPoints(); self.ct.bar:SetPoint("TOPLEFT", 0, 0); y = self.ct:Height()
        end
        for _, c in ipairs(list) do
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, -y); c:SetPoint("TOPRIGHT", 0, -y)
            y = y + c:GetHeight() + GAP
        end
        self.sideH = y
        local root = self.side.child
        root:SetSize(root:GetWidth(), y)
        if self.side.SetContentHeight then self.side:SetContentHeight(y) end
    end,

    ShowSection = function(self, key)
        self.tab = key == "settings" and "settings" or "collection"
        self.tabSeg:Select(self.tab == "settings" and nil or "collection")
        self.gear:SetActive(self.tab == "settings")
        self:Layout(); self:Refresh()
    end,

    Layout = function(self)
        local p = self.list:GetParent()
        local h = p:GetHeight() or 500
        if h < 100 then h = 500 end
        local top = 30 + GAP
        local coll = self.tab ~= "settings"
        self.side:SetShown(not coll)
        self.charDd:SetShown(coll); self.hideBtn:SetShown(coll); self.ofLabel:SetShown(coll)
        self.side:ClearAllPoints()
        self.side:SetPoint("TOPLEFT", 0, -top)
        self.side:SetPoint("BOTTOMRIGHT")
        local w = p:GetWidth() or 800
        self.side.child:SetSize((w > 100 and w or 800) - 10, self.sideH or 400)
        if self.side.UpdateBar then self.side:UpdateBar() end
        UI:ZoneLayout(self, p, top, w, h, not coll)
    end,

    Refresh = function(self)
        local cfg = R:Config()
        -- menu des persos à jour (perso renommé ou supprimé : retour au premier)
        self.charDd:SetOptions(charOptions())
        if self.charDd.selected ~= self.viewKey then
            if WK.DB.global.characters[self.viewKey] then self.charDd:Select(self.viewKey) else self.viewKey = self.charDd.selected end
        end
        local key = self.viewKey or WK:CharKey()
        local c = WK.DB.global.characters[key] or {}
        local myLevel = c.level or UnitLevel("player") or 1
        local zones = R:Zones(key)
        local playerZone = R:PlayerZone()
        self.zone = self.zone or playerZone or (zones[1] and zones[1].map)
        local r1, g1, b1 = UI:Accent()
        for _, t in ipairs(self.toggles) do t:Refresh() end
        self.hideBtn.label:SetText(cfg.pageHideKilled and T("Montrer les tués") or T("Masquer les tués"))

        -- bandeau
        local killed, total = R:Totals(key)
        local rc = C.rare
        local last, lastAt
        for id, k in pairs(cfg.kills or {}) do
            local at = k[key]
            if at and (not lastAt or at > lastAt) then last, lastAt = id, at end
        end
        self.kpi:Set(1, { label = string.format(T("RARES TUÉS · %s"), WK:CharName(c, key)), value = killed .. UI:Hex(C.muted) .. " / " .. total .. "|r",
            sub = last and R:Get(last) and string.format(T("dernier : %s, il y a %s"), R:Name(R:Get(last)), short(time() - lastAt)) or T("aucun pour l'instant"),
            frac = total > 0 and killed / total or 0, color = rc })
        local here, hereNew = 0, 0
        for _, r in ipairs(playerZone and R:OnMap(playerZone) or {}) do
            here = here + 1
            if not R:Killed(r.id, key) then hereNew = hereNew + 1 end
        end
        self.kpi:Set(2, { label = T("DANS TA ZONE"), value = tostring(here), color = here > 0 and rc or C.muted,
            sub = playerZone and string.format(T("dont %d pas encore tués"), hereNew) or T("pas de rare ici"),
            onClick = playerZone and function() self.zone = playerZone; self:Refresh() end or nil })
        local recent = 0
        for id in pairs(cfg.dead or {}) do if R:RecentDeath(id) then recent = recent + 1 end end
        self.kpi:Set(3, { label = T("MORTS RÉCENTES"), value = tostring(recent), color = recent > 0 and C.negative or C.muted,
            sub = T("moins de 3 h : repop possible") })
        -- butin utile : rares pas tués qui donnent une recette d'un métier de tes persos
        local useful = 0
        for _, z in ipairs(zones) do
            for _, r in ipairs(R:OnMap(z.map)) do
                if not R:Killed(r.id, key) then
                    for _, l in ipairs(R:Loot(r.id)) do if l.prof and #l.who > 0 then useful = useful + 1; break end end
                end
            end
        end
        self.kpi:Set(4, { label = T("BUTIN UTILE"), value = tostring(useful), color = C.gold,
            sub = T("rares pas tués avec une recette pour tes métiers") })

        -- carte du continent
        for _, z in ipairs(zones) do z.frac = z.total > 0 and z.killed / z.total or 0 end
        self.map:SetData(zones, {
            selected = self.zone, player = playerZone,
            color = function(z)
                if z.frac >= 1 then return C.positive end
                if z.frac > 0 then return rc end
                return C.dim
            end,
            onClick = function(map) self.zone = map; self:Refresh() end,
            tip = function(z, tt)
                tt:AddDoubleLine(T("Rares tués"), z.killed .. " / " .. z.total, 0.7, 0.7, 0.7, 1, 1, 1)
                tt:AddDoubleLine(T("Niveaux"), z.min .. "-" .. z.max, 0.7, 0.7, 0.7, 1, 1, 1)
            end,
        })
        self.map.legend:SetText(T("taille et couleur = rares tués · clic : voir la zone"))

        -- liste des zones (ta zone en premier)
        local ordered = {}
        for _, z in ipairs(zones) do if z.map == playerZone then table.insert(ordered, z) end end
        for _, z in ipairs(zones) do if z.map ~= playerZone then table.insert(ordered, z) end end
        self.zrows:Reset()
        local ZW = (self.zscroll:GetWidth() or 400)
        if ZW < 100 then ZW = 400 end
        for i, z in ipairs(ordered) do
            local row = self.zrows:Get()
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(i - 1) * UI.ZONE_ROW_H); row:SetWidth(ZW - 14)
            local left = z.total - z.killed
            row:Fill(z, { selected = z.map == self.zone, frac = z.frac, color = rc, level = myLevel,
                tag = z.map == playerZone and { T("ta zone"), { r1, g1, b1 } } or nil,
                right = left > 0 and string.format(T("%d à tuer"), left) or T("tous tués") })
        end
        self.zTitle:SetText(string.format(T("Zones · %d"), #ordered))
        self.zscroll.child:SetSize(ZW - 14, #ordered * UI.ZONE_ROW_H)
        if self.zscroll.UpdateBar then self.zscroll:UpdateBar() end

        -- rares de la zone choisie
        self.rrows:Reset()
        local rares = self.zone and R:OnMap(self.zone) or {}
        self.lTitle:SetText((self.zone and R:ZoneName(self.zone) or "") .. "  " .. UI:Hex(C.muted) .. "· " .. string.format(T("%d rares"), #rares) .. "|r")
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
                row.name:SetText(R:Name(r) .. (r.elite and ("  " .. UI:Hex(C.gold) .. T("élite") .. "|r") or ""))
                row.name:SetTextColor(unpack(killedAt and C.dim or C.text))
                -- détail : butin utile, sinon qui d'autre l'a tué
                local loot = R:Loot(r.id)
                local sub
                for _, l in ipairs(loot) do
                    if l.prof and #l.who > 0 then sub = (WK.GetItemInfo(l.id) or "") .. "  " .. UI:Hex(C.positive) .. "· " .. T(l.prof) .. " (" .. table.concat(l.who, ", ") .. ")|r" break end
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
