local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local GAP = 12

-- Pastille de couleur d'accent (ronde, anneau quand sélectionnée).
-- key : "theme", "class" ou index de UI.accents ; color() renvoie r, g, b.
local function AccentDot(parent, key, color, tooltip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    b.ring = UI:Icon(b, "circle", 26, nil, "BACKGROUND")
    b.ring:SetPoint("CENTER")
    b.gapRing = UI:Icon(b, "circle", 22, C.surface, "BORDER")
    b.gapRing:SetPoint("CENTER")
    b.dot = UI:Icon(b, "circle", 18, nil, "ARTWORK")
    b.dot:SetPoint("CENTER")
    if key == "class" or key == "theme" then
        b.mark = UI:Text(b, 9, C.onAccent)
        b.mark:SetPoint("CENTER", 0, 0)
        b.mark:SetText(key == "class" and "C" or "T")
    end
    function b:Refresh()
        local r, g, bl = color()
        self.dot:SetVertexColor(r, g, bl, 1)
        self.ring:SetVertexColor(r, g, bl, 1)
        local sel = WK.DB.global.settings.ui.accent == key
        self.ring:SetShown(sel)
        self.gapRing:SetShown(sel)
    end
    b:SetScript("OnClick", function() UI:SetAccent(key) end)
    b:SetScript("OnEnter", function(self)
        WK.UI:TooltipOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(WK.T(tooltip), 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI:OnAccent(function() b:Refresh() end)
    return b
end

-- Vignette d'aperçu d'un thème : mini-fenêtre dessinée avec sa palette.
local function ThemeTile(parent, theme, width, onClick)
    local pal, accent = UI:ThemePalette(theme.key)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 96)
    local prev = CreateFrame("Frame", nil, b)
    prev:SetPoint("TOPLEFT")
    prev:SetPoint("TOPRIGHT")
    prev:SetHeight(66)
    b.sel = UI:Rounded(prev, 12, 0, "BACKGROUND", 0)
    UI:Rounded(prev, 10, 2, "BACKGROUND", 1):SetColor(unpack(pal.frame))
    UI:Rounded(prev, 9, 3, "BACKGROUND", 2):SetColor(pal.bg[1], pal.bg[2], pal.bg[3], 1)
    -- barre du haut, pilule d'accent, deux cartes
    local bar = prev:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(unpack(pal.border))
    bar:SetPoint("TOPLEFT", 10, -20); bar:SetPoint("TOPRIGHT", -10, -20); bar:SetHeight(1)
    local logo = UI:Icon(prev, "circle", 8, { accent[1], accent[2], accent[3], 1 })
    logo:SetPoint("TOPLEFT", 10, -8)
    local pill = CreateFrame("Frame", nil, prev)
    pill:SetSize(26, 8)
    pill:SetPoint("TOPRIGHT", -10, -8)
    UI:Rounded(pill, 4, 0, "ARTWORK", 1):SetColor(accent[1], accent[2], accent[3], 1)
    for i = 1, 2 do
        local cardF = CreateFrame("Frame", nil, prev)
        cardF:SetPoint("TOPLEFT", 10 + (i - 1) * ((width - 26) / 2 + 6), -28)
        cardF:SetSize((width - 26) / 2, 28)
        UI:Rounded(cardF, 6, 0, "ARTWORK", 1):SetColor(unpack(pal.border))
        UI:Rounded(cardF, 5, 1, "ARTWORK", 2):SetColor(unpack(pal.surface))
        local line = cardF:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(pal.text[1], pal.text[2], pal.text[3], 0.7)
        line:SetPoint("TOPLEFT", 6, -8); line:SetSize((width - 26) / 4, 3)
        local line2 = cardF:CreateTexture(nil, "OVERLAY")
        line2:SetColorTexture(pal.muted[1], pal.muted[2], pal.muted[3], 0.6)
        line2:SetPoint("TOPLEFT", 6, -16); line2:SetSize((width - 26) / 3, 3)
    end
    b.label = UI:Text(b, 12)
    b.label:SetPoint("TOP", prev, "BOTTOM", 0, -8)
    b.label:SetText(theme.label)
    function b:Refresh(selected)
        if selected then self.sel:SetColor(UI:Accent()) self.sel:Show() else self.sel:Hide() end
        self.label:SetTextColor(unpack(selected and C.text or C.muted))
    end
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        WK.UI:TooltipOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(WK.T(theme.label), 1, 1, 1)
        GameTooltip:AddLine(WK.T(theme.desc), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

UI:RegisterPage({
    key = "options", order = 10, navIcon = "gear",
    title = "Options",
    subtitle = "Réglages rangés par catégorie.",

    Build = function(self, p)
        local cfg = WK.DB.global.settings.ui
        local alerts = WK.DB.global.settings.alerts
        -- Sections verticales à gauche, contenu défilant à droite ----------------------
        local NAV_W = 210
        local W = UI.PAGE_W - NAV_W - GAP - 12
        local navCard = UI:Card(p)
        navCard:SetWidth(NAV_W)
        navCard:SetPoint("TOPLEFT")
        navCard:SetPoint("BOTTOMLEFT")
        local host = CreateFrame("Frame", nil, p)
        host:SetPoint("TOPLEFT", NAV_W + GAP, 0)
        host:SetPoint("BOTTOMRIGHT")
        self.sections, self.sectionButtons = {}, {}
        local root, y, current
        local function section(key)
            if current then current.scroll:SetContentHeight(y) end
            local sc = UI:Scroll(host)
            sc:SetAllPoints()
            sc:Hide()
            current = { scroll = sc }
            self.sections[key] = current
            root, y = sc.child, 0
        end
        local function card(title, h)
            local c = UI:Card(root, title)
            c:SetSize(W, h)
            c:SetPoint("TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", 0, -y)
            y = y + h + GAP
            return c
        end
        function self:ShowSection(key)
            if key == "theme" then key = "look" end -- ancienne section, fusionnée dans Apparence
            if not self.sections[key] then key = "general" end
            cfg.optSection = key
            for k, sec in pairs(self.sections) do sec.scroll:SetShown(k == key) end
            for k, b in pairs(self.sectionButtons) do b.selected = (k == key); b:Paint() end
        end
        local SECTIONS = {
            { "general", "Général", "home", "Langue, minimap, combat" },
            { "prices", "Prix", "coin", "Source des prix" },
            { "mail", "Courrier", "mail", "Envoi, réception, dépôt" },
            { "glow", "Récolte", "filter", "Coins de récolte" },
            { "alerts", "Alertes", "clock", "Banque et courrier" },
            { "look", "Apparence", "logo", "Thème, couleurs, police" },
            { "about", "À propos", "notes", "Version et commandes" },
        }
        for i, sec in ipairs(SECTIONS) do
            local b = CreateFrame("Button", nil, navCard)
            b:SetHeight(50)
            b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 54)
            b:SetPoint("TOPRIGHT", -8, -8 - (i - 1) * 54)
            b.bg = UI:Rounded(b, 10, 0, "BACKGROUND", 1)
            b.bar = CreateFrame("Frame", nil, b)
            b.bar:SetSize(3, 20)
            b.bar:SetPoint("LEFT")
            b.barTex = UI:Rounded(b.bar, 1.5, 0, "ARTWORK", 1)
            b.icon = UI:Icon(b, sec[3], 16)
            b.icon:SetPoint("LEFT", 14, 0)
            b.label = UI:Text(b, 13)
            b.label:SetPoint("TOPLEFT", 42, -9)
            b.label:SetText(sec[2])
            b.desc = UI:Text(b, 10, C.muted)
            b.desc:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -4)
            b.desc:SetPoint("RIGHT", b, "RIGHT", -6, 0)
            b.desc:SetText(sec[4])
            function b:Paint()
                local sel = self.selected
                self.bg:SetColor(unpack(sel and C.surface2 or C.hover))
                self.bg:SetShown(sel or self.hover)
                self.bar:SetShown(sel)
                self.barTex:SetColor(UI:Accent())
                if sel then self.icon:SetVertexColor(UI:Accent()) else self.icon:SetVertexColor(unpack(C.muted)) end
                self.label:SetTextColor(unpack((sel or self.hover) and C.text or C.muted))
            end
            b:SetScript("OnEnter", function(s) s.hover = true; s:Paint() end)
            b:SetScript("OnLeave", function(s) s.hover = false; s:Paint() end)
            b:SetScript("OnClick", function() self:ShowSection(sec[1]) end)
            UI:OnAccent(function() b:Paint() end)
            self.sectionButtons[sec[1]] = b
        end

        -- Thème, police, arrondi, opacité et langue s'appliquent en direct : l'interface est reconstruite.
        local function apply() UI:Rebuild() end

        -- Apparence : thème puis couleurs, police, taille ---------------------------
        section("look")
        local perRow = 4
        local rowsN = math.ceil(#UI.themes / perRow)
        local themeCard = card("Thème", 48 + rowsN * 106)
        local tw = (W - 32 - (perRow - 1) * 10) / perRow
        self.themeTiles = {}
        for i, th in ipairs(UI.themes) do
            local tile = ThemeTile(themeCard, th, tw, function()
                cfg.theme = th.key
                cfg.accent = "theme"
                UI:SetAccent("theme")
                apply()
            end)
            tile:SetPoint("TOPLEFT", 16 + ((i - 1) % perRow) * (tw + 10), -44 - math.floor((i - 1) / perRow) * 106)
            self.themeTiles[th.key] = tile
        end
        function self:RefreshThemes()
            for key, tile in pairs(self.themeTiles) do tile:Refresh(key == cfg.theme) end
        end

        -- Thème personnalisé ----------------------------------------------------------
        local cust = card("Thème personnalisé", 132)
        local copy = UI:Button(cust, "Partir du thème actuel", nil, 28, "secondary")
        copy:SetPoint("TOPRIGHT", -12, -8)
        copy.tooltip = "Copie les couleurs du thème actuel pour les modifier."
        local function saveCustom(key, r, g, b)
            cfg.custom = cfg.custom or {}
            cfg.custom[key] = { r, g, b }
            cfg.theme = "custom"
            if cfg.accent ~= "class" and type(cfg.accent) ~= "number" then cfg.accent = "theme" end
            -- Le sélecteur envoie beaucoup de valeurs pendant qu'on le fait glisser : on attend un peu.
            self.customToken = (self.customToken or 0) + 1
            local token = self.customToken
            C_Timer.After(0.4, function() if token == self.customToken then apply() end end)
        end
        copy:SetScript("OnClick", function()
            local base = UI:ThemeBase(cfg.theme == "custom" and "vault" or cfg.theme)
            cfg.custom = {}
            for _, k in ipairs(UI.CUSTOM_KEYS) do
                local c = base[k[1]]
                cfg.custom[k[1]] = { c[1], c[2], c[3] }
            end
            cfg.theme = "custom"
            cfg.accent = "theme"
            apply()
        end)
        local sw = (W - 32 - 6 * 10) / 7
        local customBase = UI:ThemeBase("custom")
        for i, k in ipairs(UI.CUSTOM_KEYS) do
            local b = CreateFrame("Button", nil, cust)
            b:SetSize(sw, 64)
            b:SetPoint("TOPLEFT", 16 + (i - 1) * (sw + 10), -44)
            local swatch = CreateFrame("Frame", nil, b)
            swatch:SetPoint("TOPLEFT"); swatch:SetPoint("TOPRIGHT"); swatch:SetHeight(34)
            UI:Rounded(swatch, 10, 0, "BACKGROUND", 1):SetColor(unpack(C.border))
            local fill = UI:Rounded(swatch, 9, 1, "BACKGROUND", 2)
            local c = customBase[k[1]]
            fill:SetColor(c[1], c[2], c[3], 1)
            local lbl = UI:Text(b, 11, C.muted)
            lbl:SetPoint("TOP", swatch, "BOTTOM", 0, -8)
            lbl:SetText(k[2])
            b:SetScript("OnClick", function()
                local cur = UI:ThemeBase("custom")[k[1]]
                UI:PickColor(cur[1], cur[2], cur[3], function(r, g, bl)
                    fill:SetColor(r, g, bl, 1)
                    saveCustom(k[1], r, g, bl)
                end)
            end)
            b:SetScript("OnEnter", function() WK.UI:TooltipOwner(b, "ANCHOR_TOP"); GameTooltip:SetText(WK.T("Clique pour choisir la couleur"), 1, 1, 1); GameTooltip:Show() end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        local look = card("Couleurs, police et taille", 356)
        local dots = CreateFrame("Frame", nil, look)
        local choices = {
            { "theme", function() local a = UI.themeAccent or UI.accents[1]; return a[1], a[2], a[3] end, "Accent du thème" },
            { "class", function()
                local _, class = UnitClass("player")
                local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
                if c then return c.r, c.g, c.b end
                return 0.8, 0.8, 0.8
            end, "Couleur de classe" },
        }
        for i, a in ipairs(UI.accents) do
            table.insert(choices, { i, function() return a[1], a[2], a[3] end, "Couleur fixe" })
        end
        dots:SetSize(#choices * 32, 26)
        for i, ch in ipairs(choices) do
            local d = AccentDot(dots, ch[1], ch[2], ch[3])
            d:SetPoint("LEFT", (i - 1) * 32, 0)
        end
        UI:SettingRow(look, -40, "Couleur d'accent", "T : accent du thème · C : couleur de classe.", dots, 300)

        local fontSeg = UI:Segmented(look, { { "friz", "Friz Quadrata" }, { "arialn", "Arial Narrow" } },
            function(v) cfg.font = v; apply(); UI:ApplyGameTooltipFonts() end, 30)
        fontSeg:Select(cfg.font or "friz")
        UI:SettingRow(look, -92, "Police", "Police du texte de l'interface.", fontSeg, 280)

        local roundSeg = UI:Segmented(look, { { 1, "Fort" }, { 0.6, "Moyen" }, { 0.25, "Carré" } },
            function(v) cfg.rounding = v; apply() end, 30)
        roundSeg:Select(cfg.rounding or 1)
        UI:SettingRow(look, -144, "Arrondi", "Arrondi des fenêtres, cartes et boutons.", roundSeg, 280)

        local opacity = UI:Slider(look, 240, 0.6, 1, 0.05,
            function() return cfg.opacity or 1 end,
            function(v) cfg.opacity = v; apply() end, "%.2f")
        UI:SettingRow(look, -196, "Opacité du fond", "Transparence du fond de la fenêtre (appliquée au relâchement).", opacity, 260)

        local slider = UI:Slider(look, 240, 0.7, 1.3, 0.05,
            function() return cfg.scale or 1 end,
            function(v) UI:ApplyScale(v) end, "%.2fx")
        UI:SettingRow(look, -248, "Échelle de la fenêtre", "Appliquée au relâchement du curseur.", slider, 260)

        self.portraitToggle = UI:Toggle(look,
            function() return cfg.portraits ~= false end,
            function(v) cfg.portraits = v; WK:NotifyChanged() end)
        UI:SettingRow(look, -300, "Portraits des persos",
            "À côté des noms. Vrai portrait pour le perso connecté, race et sexe pour les autres. Désactivé : icône de classe.",
            self.portraitToggle, 80)

        -- Général : langue, bouton minimap, fenêtre ------------------------------------
        section("general")
        local langCard = card("Langue", 96)
        local lang = UI:Segmented(langCard, { { "auto", "Auto" }, { "frFR", "Français" }, { "enUS", "English" } },
            function(v) cfg.lang = v; apply() end, 30)
        lang:Select(cfg.lang or "auto")
        UI:SettingRow(langCard, -40, "Langue", "Auto : celle du jeu.", lang, 280)

        local ttCard = card("Infobulles", 150)
        UI:SettingRow(ttCard, -94, "Police fine pour les infobulles du jeu", "Objets, PNJ, sorts : la police de l'interface choisie dans Apparence, sans contour, comme les infobulles de l'addon.",
            UI:Toggle(ttCard, function() return cfg.gameTooltipFont ~= false end, function(v) cfg.gameTooltipFont = v; UI:ApplyGameTooltipFonts() end), 80)
        UI:SettingRow(ttCard, -40, "Montée des métiers", "Dans l'infobulle d'un objet : les métiers qui s'en servent pour monter, et combien il en faut encore à chacun de tes persos.",
            UI:Toggle(ttCard, function() return cfg.tooltipProf ~= false end, function(v) cfg.tooltipProf = v end), 80)
        local generalY = y -- la section Général reprend plus bas (après Prix des objets) à cette hauteur

        -- Prix des objets ------------------------------------------------------------
        section("prices")
        local priceCard = card("Prix des objets", 108)
        local vcfg = WK.DB.global.settings.value
        local src = UI:Segmented(priceCard, { { "auctionator", "Hôtel des ventes" }, { "vendor", "Marchand" }, { "both", "Les deux" } },
            function(v) vcfg.source = v; WK.modules.Value:StockValue(true); WK:NotifyChanged(); self:Refresh() end, 30)
        src:Select(vcfg.source or "auctionator")
        self.priceRow = UI:SettingRow(priceCard, -36, "Source des prix", nil, src, 330)
        -- Description sur sa propre ligne : la commande à trois choix prend la largeur.
        self.priceDesc = UI:Text(priceCard, 11, C.muted)
        self.priceDesc:SetPoint("TOPLEFT", 16, -76)
        self.priceDesc:SetPoint("TOPRIGHT", -16, -76)
        self.priceDesc:SetJustifyH("LEFT")

        -- Bouton minimap (section Général) ---------------------------------------------
        current.scroll:SetContentHeight(y)
        root, y, current = self.sections.general.scroll.child, generalY, self.sections.general
        local mm = card("Bouton minimap", 136)
        self.mmToggle = UI:Toggle(mm,
            function() return not cfg.minimap.hide end,
            function(v) cfg.minimap.hide = not v; WK.modules.MinimapButton:Update() end)
        UI:SettingRow(mm, -40, "Afficher le bouton", "Clic gauche : ouvrir. Clic droit : options. Glisser pour le déplacer.", self.mmToggle, 80)
        local reset = UI:Button(mm, "Recentrer", nil, 28, "secondary")
        UI:SettingRow(mm, -88, "Position de la fenêtre", nil, reset)
        reset:SetScript("OnClick", function()
            cfg.point = nil
            UI.frame:ClearAllPoints()
            UI.frame:SetPoint("CENTER")
        end)
        local loginCard = card("Rappels à la connexion", 146)
        self.loginToggle = UI:Toggle(loginCard,
            function() return cfg.loginPopup ~= false end,
            function(v) cfg.loginPopup = v end)
        local loginRow = UI:SettingRow(loginCard, -40, "Fenêtre de rappels",
            "À la connexion d'un perso : courrier à prendre, recharges prêtes, métier au plafond…", self.loginToggle, 190)
        local preview = UI:Button(loginCard, "Aperçu", nil, 26, "ghost")
        preview:SetPoint("RIGHT", self.loginToggle, "LEFT", -12, 0)
        preview:SetScript("OnClick", function() UI:ShowLoginPopup(true) end)
        UI:SettingRow(loginCard, -92, "Durée d'affichage", "La fenêtre se ferme seule au bout de ce temps (pas tant que la souris est dessus). 0 : elle reste jusqu'à ce que tu la fermes.",
            UI:Slider(loginCard, 200, 0, 60, 1,
                function() local v = cfg.loginPopupTime; if v == nil then v = 5 end; return v end,
                function(v) cfg.loginPopupTime = v end, "%d s"), 220)
        local winCard = card("Combat", 96)
        self.combatToggle = UI:Toggle(winCard,
            function() return cfg.closeInCombat end,
            function(v) cfg.closeInCombat = v end)
        UI:SettingRow(winCard, -40, "Fermer la fenêtre en combat",
            "Au début d'un combat. La mini-fenêtre de la session de farm reste affichée.", self.combatToggle, 80)

        -- Courrier : envoi, réception, dépôt en banque ---------------------------
        section("mail")
        local mcfg, bcfg = WK.DB.global.mail, WK.DB.global.bank
        self.mailToggles = {}
        local function toggle(parent, get, set)
            local t = UI:Toggle(parent, get, set)
            table.insert(self.mailToggles, t)
            return t
        end
        local send = card("Envoi", 184)
        UI:SettingRow(send, -40, "Envoi automatique",
            "À l'ouverture de la boîte aux lettres, les objets assignés quittent les sacs vers leur destinataire (12 par courrier).",
            toggle(send, function() return mcfg.enabled end, function(v) WK.modules.Mail:SetEnabled(v) end), 80)
        UI:SettingRow(send, -88, "Fermer la boîte aux lettres après l'envoi",
            "Seulement quand quelque chose a été envoyé (après la prise automatique si elle est activée).",
            toggle(send, function() return mcfg.closeAfter ~= false end, function(v) mcfg.closeAfter = v end), 80)
        UI:SettingRow(send, -136, "Trier les sacs ensuite",
            "Après l'envoi automatique (et la prise automatique si elle est activée).",
            toggle(send, function() return mcfg.sortAfter ~= false end, function(v) mcfg.sortAfter = v end), 80)
        local recv = card("Réception", 88)
        UI:SettingRow(recv, -40, "Tout prendre automatiquement",
            "Après les envois : or et objets (sauf contre-remboursement), arrêt si les sacs sont pleins. Un bouton « Tout prendre » est aussi ajouté à la boîte de réception.",
            toggle(recv, function() return mcfg.autoTake end, function(v) mcfg.autoTake = v end), 80)
        local dep = card("Dépôt en banque", 136)
        UI:SettingRow(dep, -40, "Dépôt automatique",
            "À l'ouverture de la banque, les objets assignés sont rangés dans la banque du perso ou de bataillon.",
            toggle(dep, function() return bcfg.enabled end, function(v) bcfg.enabled = v; WK:NotifyChanged() end), 80)
        UI:SettingRow(dep, -88, "Trier les sacs ensuite", "Après le dépôt automatique.",
            toggle(dep, function() return bcfg.sortAfter ~= false end, function(v) bcfg.sortAfter = v end), 80)

        -- Récolte : coins de récolte (le halo est dans QoL) -------------------------------
        section("glow")
        self.glowToggles = {}
        local function gtoggle(parent, get, set)
            local t = UI:Toggle(parent, get, set)
            table.insert(self.glowToggles, t)
            return t
        end

        local nodesCard
        -- Coins de récolte sur la carte du monde
        local gm = WK.DB.global.gatherMap
        local spotsCard = card("Coins de récolte", 184)
        UI:SettingRow(spotsCard, -40, "Enregistrer mes récoltes",
            "À chaque plante, minerai ou cuir ramassé, l'endroit est noté (tous les persos).",
            gtoggle(spotsCard, function() return gm.record end, function(v) gm.record = v end), 80)
        UI:SettingRow(spotsCard, -88, "Afficher sur la carte du monde",
            "Une pastille par coin, de la couleur de la ressource, plus grosse là où tu récoltes souvent.",
            gtoggle(spotsCard, function() return gm.showMap end, function(v)
                gm.showMap = v; WK.modules.GatherMap:Redraw()
            end), 80)
        self.spotsInfo = UI:Text(spotsCard, 11, C.muted)
        self.spotsInfo:SetPoint("BOTTOMLEFT", 16, 18)
        local clearSpots = UI:Button(spotsCard, "Effacer", nil, 28, "ghost", "trash")
        clearSpots:SetPoint("BOTTOMRIGHT", -12, 12)
        clearSpots.tooltip = "Maj + clic : efface tous les coins enregistrés."
        clearSpots:SetScript("OnClick", function()
            if IsShiftKeyDown() then WK.modules.GatherMap:Clear(); self:Refresh() end
        end)

        -- Filons et plantes déjà récoltés (Modules/Nodes.lua) et HUD de récolte (UI/GatherHUD.lua)
        local nd = WK.modules.Nodes:Config()
        local function ntoggle(field)
            return gtoggle(nodesCard, function() return nd[field] end, function(v) nd[field] = v; UI:RefreshNodePins() end)
        end
        nodesCard = card("Filons et plantes récoltés", 40 + 5 * 46 + 30, "là où tes persos ont déjà récolté (tout le compte)")
        UI:SettingRow(nodesCard, -40, "Afficher sur la minicarte", "Une petite icône par nœud déjà récolté autour de toi, même hors de portée du pistage du jeu.", ntoggle("minimap"), 80)
        UI:SettingRow(nodesCard, -86, "Afficher sur la carte du monde", "Tous les nœuds déjà récoltés de la zone.", ntoggle("map"), 80)
        UI:SettingRow(nodesCard, -132, "Seulement mes métiers", "Plantes si le perso a l'Herboristerie, filons s'il a le Minage.", ntoggle("onlyMine"), 80)
        UI:SettingRow(nodesCard, -178, "Seulement ce que je peux récolter", "Cache ce qui demande plus que ta compétence.", ntoggle("onlyUsable"), 80)
        UI:SettingRow(nodesCard, -224, "Taille des icônes", nil,
            UI:Slider(nodesCard, 220, 8, 24, 1, function() return nd.size or 14 end, function(v) nd.size = v; UI:RefreshNodePins() end, "%d px"), 240)
        local nodesNote = UI:Text(nodesCard, 11, C.muted)
        nodesNote:SetPoint("BOTTOMLEFT", 16, 14)
        nodesNote:SetText(WK.T("Anneau : rouge trop dur · orange, jaune, vert selon la difficulté · gris sans intérêt ou métier absent."))

        local hc = UI.GatherHUDConfig()
        local hud = card("HUD de récolte", 40 + 3 * 46 + 52, "la minicarte en grand au milieu de l'écran")
        local hudBtn = UI:Button(hud, "Afficher / masquer", nil, 28, "primary")
        hudBtn:SetScript("OnClick", function() UI:ToggleGatherHUD() end)
        UI:SettingRow(hud, -40, "HUD de récolte", "La minicarte s'affiche en grand et transparente au centre de l'écran : les points jaunes du pistage (filons, plantes) se voient de bien plus loin. Aussi : /wk hud, ou une touche dans les raccourcis du jeu (Warband Keeper).", hudBtn, 170)
        UI:SettingRow(hud, -92, "Taille", "Part de la hauteur de l'écran.",
            UI:Slider(hud, 220, 30, 90, 5, function() return hc.size end, function(v) hc.size = v; UI:ApplyGatherHUD() end, "%d %%"), 240)
        UI:SettingRow(hud, -138, "Opacité", nil,
            UI:Slider(hud, 220, 0.2, 1, 0.05, function() return hc.alpha end, function(v) hc.alpha = v; UI:ApplyGatherHUD() end, "%.2f"), 240)
        UI:SettingRow(hud, -184, "Fermer en combat", "Le HUD disparaît au début d'un combat.",
            gtoggle(hud, function() return hc.combatHide end, function(v) hc.combatHide = v end), 80)

        -- Alertes -------------------------------------------------------------------
        section("alerts")
        local al = card("Alertes", 196)
        self.alertToggle = UI:Toggle(al,
            function() return alerts.enabled end,
            function(v) alerts.enabled = v; WK:NotifyChanged() end)
        UI:SettingRow(al, -40, "Activer les alertes", "Rappel dans le chat à la connexion, et colonnes en orange dans la page Persos.", self.alertToggle, 80)
        local bankSlider = UI:Slider(al, 240, 1, 30, 1,
            function() return alerts.bankDays end,
            function(v) alerts.bankDays = v; WK:NotifyChanged() end, "%d j")
        UI:SettingRow(al, -92, "Banque pas vue depuis", "Alerte quand la banque d'un perso (niveau 10+) n'a pas été ouverte depuis ce nombre de jours.", bankSlider, 260)
        local mailSlider = UI:Slider(al, 240, 1, 10, 1,
            function() return alerts.mailDays end,
            function(v) alerts.mailDays = v; WK:NotifyChanged() end, "%d j")
        UI:SettingRow(al, -144, "Courrier qui expire", "Alerte quand un courrier expire dans moins de ce nombre de jours.", mailSlider, 260)

        -- À propos ----------------------------------------------------------------
        section("about")
        local about = card("À propos", 236)
        local t = UI:Text(about, 12, C.muted)
        t:SetPoint("TOPLEFT", 16, -42)
        t:SetPoint("TOPRIGHT", -16, -42)
        t:SetJustifyV("TOP")
        if t.SetWordWrap then t:SetWordWrap(true) end
        t:SetSpacing(4)
        local T = WK.T
        t:SetText("Warband Keeper v" .. WK.version .. "\n"
            .. T("Commandes : |cffffffff/wk|r ouvre cette fenêtre, |cffffffff/wk aide|r liste les commandes du chat.") .. "\n"
            .. T("Connecte-toi une fois sur chaque personnage et ouvre sa banque pour qu'il soit enregistré.") .. "\n"
            .. T("Lieux du guidage (boîtes aux lettres, banques, marchands, maîtres de classe), monstres rares, quêtes et chemins de base de la navigation (patrouilles des PNJ) : données de QuestieDB, base de l'addon Questie (github.com/Questie/QuestieDB, licence GPLv3).") .. "\n"
            .. T("Distances de l'indicateur du chasseur : bibliothèque LibRangeCheck-3.0 (WoWUIDev Community, licence MIT)."))
        local notesBtn = UI:Button(about, "Voir les patch notes", nil, 28, "secondary", "notes")
        notesBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        notesBtn:SetScript("OnClick", function() UI:ShowPage("notes") end)
        current.scroll:SetContentHeight(y)
        self:ShowSection(cfg.optSection or "general")
    end,

    Refresh = function(self)
        self:RefreshThemes()
        if self.priceDesc and self.priceDesc.SetText then
            local V = WK.modules.Value
            if not V:HasAHPrices() then
                self.priceDesc:SetText(WK.T("Pas encore de prix HV : fais un scan à l'hôtel des ventes (panneau Warband Keeper). En attendant, les prix marchands sont utilisés."))
            elseif V:ShowBoth() then
                self.priceDesc:SetText(WK.T("Les deux prix sont affichés ; les calculs prennent le meilleur des deux."))
            elseif WK.DB.global.settings.value.source == "vendor" then
                self.priceDesc:SetText(WK.T("Prix de vente aux marchands uniquement."))
            else
                self.priceDesc:SetText(WK.T("Prix de l'hôtel des ventes (prix marchand si l'objet n'a pas de prix)."))
            end
        end
        self.mmToggle:Refresh()
        self.combatToggle:Refresh()
        self.loginToggle:Refresh()
        self.portraitToggle:Refresh()
        self.alertToggle:Refresh()
        for _, t in ipairs(self.mailToggles) do t:Refresh() end
        for _, t in ipairs(self.glowToggles) do t:Refresh() end
        self.spotsInfo:SetText(string.format(WK.T("%d récoltes enregistrées"), WK.modules.GatherMap:Count()))

    end,
})
