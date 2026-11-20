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
        local sel = UI:AccentChoice() == key
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


UI:RegisterPage({
    key = "options", order = 10, navIcon = "gear",
    title = "Options",
    subtitle = "Réglages rangés par catégorie.",
    -- point sur l'icône des Options : patch notes pas encore lues
    count = function()
        local Mt = WK.modules.Maintenance
        if Mt and Mt:Unseen() > 0 then return "!" end
        return UI.notesDef and UI.notesDef.count() or ""
    end,

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
        local function card(title, h, subtitle)
            local c = UI:Card(root, title, subtitle)
            current.cards = current.cards or {}
            table.insert(current.cards, c)
            c.cardKey = title
            c:SetSize(W, h)
            c:SetPoint("TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", 0, -y)
            y = y + h + GAP
            return c
        end
        function self:ShowSection(key)
            if key == "theme" then key = "look" end -- ancienne section, fusionnée dans Apparence
            if not self.sections[key] or not self.sectionButtons[key] then key = "general" end
            cfg.optSection = key
            for k, sec in pairs(self.sections) do sec.scroll:SetShown(k == key) end
            if key == "notes" and UI.notesDef then
                local ns = self.sections.notes
                if not ns.built then
                    UI:InAccentScope("window", UI.notesDef.Build, UI.notesDef, ns.scroll)
                    ns.built = true
                end
                -- lues seulement si on les voit vraiment (les Options peuvent être construites cachées :
                -- recherche, cartes reprises par d'autres pages)
                if ns.scroll:IsVisible() then
                    UI.notesDef:Refresh()
                    if UI.RefreshChips then UI:RefreshChips() end
                end
            end
            if key == "general" and self.sections.general.showTab then self.sections.general.showTab(cfg.optGenTab or "lang") end
            for k, b in pairs(self.sectionButtons) do b.selected = (k == key); b:Paint() end
        end
        local SECTIONS = {
            { "general", "Général", "home", "Langue, infobulles, minimap" },
            -- Prix, Courrier, Récolte, Alertes : leurs cartes sont reprises par la page Hôtel des ventes,
            -- la page Courrier, les réglages des métiers et QoL > Général > Alertes (sections cachées).
            { "look", "Apparence", "logo", "Couleurs, police, taille" },
            { "profiles", "Profils", "users", "Un jeu de réglages par perso" },
            { "notes", "Patch notes", "notes", "Nouveautés et à venir" },
            { "maint", "Fiabilité", "warn", "Erreurs et place des données" },
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
            b.desc:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, -26)
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
        -- (thèmes : Graphite seulement, plus de choix ni de thème personnalisé)
        function self:RefreshThemes() end

        -- Apparence : onglets Styles / Couleurs / Texte / Formes / Fenêtre à gauche (tient dans la fenêtre sans
        -- défiler), aperçu en direct à droite, partage du style et retour d'origine en bas. La fenêtre se
        -- reconstruit à chaque changement : l'aperçu montre tout de suite le résultat.
        local look = card("Couleurs, police et taille", 470)
        local lc = CreateFrame("Frame", nil, look)
        lc:SetPoint("TOPLEFT", 0, 0); lc:SetPoint("BOTTOMLEFT", 0, 0)
        local rc = CreateFrame("Frame", nil, look)
        rc:SetPoint("TOPLEFT", lc, "TOPRIGHT", 8, 0); rc:SetPoint("BOTTOMRIGHT", -16, 16)
        look:SetScript("OnSizeChanged", function(c, w) lc:SetWidth(math.max(470, math.floor((w or c:GetWidth()) * 0.62))) end)
        lc:SetWidth(520)
        local LOOK_TABS = { { "styles", "Styles" }, { "colors", "Couleurs" }, { "text", "Texte" }, { "shapes", "Formes" }, { "window", "Fenêtre" } }
        local panes = {}
        for _, t in ipairs(LOOK_TABS) do
            local pf = CreateFrame("Frame", nil, lc)
            pf:SetPoint("TOPLEFT", 0, -78); pf:SetPoint("TOPRIGHT", 0, -78); pf:SetHeight(300)
            pf:Hide()
            panes[t[1]] = pf
        end
        local tabSeg
        local function showTab(k)
            if not panes[k] then k = "colors" end
            cfg.lookTab = k
            for key, pf in pairs(panes) do pf:SetShown(key == k) end
            if tabSeg then tabSeg:Select(k) end
        end
        tabSeg = UI:Segmented(lc, LOOK_TABS, showTab, 28)
        tabSeg:SetPoint("TOPLEFT", 16, -40)
        -- un réglage trouvé par la recherche ouvre son onglet
        self.lookTabOf = function(row)
            for key, pf in pairs(panes) do
                local f = row
                while f do if f == pf then return key end; f = f:GetParent() end
            end
        end
        self.lookShowTab = showTab

        ---------------------------------------------------------------- Styles prêts
        local STYLES = {
            { "Graphite rose", { accent = 7, bgTint = nil, rounding = 1, cardStyle = nil, titleFont = nil } },
            { "Nuit bleue", { accent = 5, bgTint = "cold", rounding = 0.8, cardStyle = "halo", titleFont = nil } },
            { "Forêt", { accent = 3, bgTint = nil, rounding = 1.2, cardStyle = nil, titleFont = nil } },
            { "Or ancien", { accent = 1, bgTint = "warm", rounding = 0.6, cardStyle = "halo", titleFont = "morpheus" } },
            { "Améthyste", { accent = 6, bgTint = "cold", rounding = 1, cardStyle = "flat", titleFont = nil } },
            { "Braise", { accent = 8, bgTint = "warm", rounding = 0.4, cardStyle = nil, titleFont = nil } },
        }
        do
            local pf = panes.styles
            local note = UI:Text(pf, 11, C.muted); note:SetPoint("TOPLEFT", 16, -2); note:SetPoint("RIGHT", -16, 0)
            note:SetJustifyH("LEFT"); if note.SetWordWrap then note:SetWordWrap(true) end
            note:SetText(WK.T("Un clic applique couleur, teinte du fond, arrondi, style des cartes et police des titres ; règle ensuite le reste dans les autres onglets."))
            for n, st in ipairs(STYLES) do
                local a = UI.accents[st[2].accent]
                local b = CreateFrame("Button", nil, pf)
                b:SetSize(150, 76)
                local col, row = (n - 1) % 3, math.floor((n - 1) / 3)
                b:SetPoint("TOPLEFT", 16 + col * 158, -40 - row * 86)
                b.edge = UI:Rounded(b, 10, 0, "BACKGROUND", 0); b.edge:SetColor(unpack(C.border))
                b.bg = UI:Rounded(b, 9, 1, "BACKGROUND", 1); b.bg:SetColor(unpack(C.surface2))
                local bar = b:CreateTexture(nil, "ARTWORK"); bar:SetColorTexture(a[1], a[2], a[3], 1)
                bar:SetPoint("TOPLEFT", 12, -12); bar:SetSize(84, 5)
                local bar2 = b:CreateTexture(nil, "ARTWORK"); bar2:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
                bar2:SetPoint("TOPLEFT", 12, -24); bar2:SetSize(110, 3)
                local pill = b:CreateTexture(nil, "ARTWORK"); pill:SetColorTexture(a[1], a[2], a[3], 1)
                pill:SetPoint("TOPLEFT", 12, -34); pill:SetSize(34, 10)
                local name = UI:Text(b, 11); name:SetPoint("BOTTOMLEFT", 12, 10); name:SetText(WK.T(st[1]))
                b:SetScript("OnEnter", function(x) x.edge:SetColor(a[1], a[2], a[3], 1) end)
                b:SetScript("OnLeave", function(x) x.edge:SetColor(unpack(C.border)) end)
                b:SetScript("OnClick", function()
                    for k, v in pairs(st[2]) do if k ~= "accent" then cfg[k] = v end end
                    -- champs absents du style : remis à leur valeur d'origine
                    for _, k in ipairs({ "bgTint", "cardStyle", "titleFont" }) do if st[2][k] == nil then cfg[k] = nil end end
                    UI:SetAccent(st[2].accent)
                    apply()
                end)
            end
        end

        ---------------------------------------------------------------- Couleurs
        do
            local pf = panes.colors
            local dots = CreateFrame("Frame", nil, pf)
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
            table.insert(choices, { "custom", function()
                local c = cfg.accentRGB
                if type(c) == "table" and c[1] then return c[1], c[2], c[3] end
                return 0.9, 0.9, 0.9
            end, "Ta couleur (code ci-dessous)" })
            dots:SetSize(#choices * 26, 26)
            for i, ch in ipairs(choices) do
                local d = AccentDot(dots, ch[1], ch[2], ch[3])
                d:SetScale(0.9)
                d:SetPoint("LEFT", (i - 1) * 29, 0)
            end
            UI:SettingRow(pf, 0, "Couleur d'accent", "T : thème · C : classe · le dernier : ta couleur.", dots, 360)
            local hex = UI:Input(pf, 110, 28, "#F58CBA")
            local function hexOf()
                local c = cfg.accentRGB
                if type(c) ~= "table" or not c[1] then return "" end
                return string.format("#%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
            end
            hex:SetText(hexOf())
            hex.onEnter = function(v)
                local h = (v or ""):gsub("[^%x]", "")
                if #h == 3 then h = h:sub(1, 1):rep(2) .. h:sub(2, 2):rep(2) .. h:sub(3, 3):rep(2) end
                if #h ~= 6 then hex:SetText(hexOf()) return end
                cfg.accentRGB = { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
                UI:SetAccent("custom")
                hex:SetText(hexOf())
            end
            UI:SettingRow(pf, -46, "Ta couleur", "Code hexadécimal (#RRGGBB), puis Entrée.", hex, 120)
            -- dégradé : 2e couleur des jauges (aucune, ou une des couleurs fixes)
            local g2 = CreateFrame("Frame", nil, pf); g2:SetSize(10 * 24, 22)
            local g2dots = {}
            for n = 0, #UI.accents do
                local b = CreateFrame("Button", nil, g2); b:SetSize(20, 20); b:SetPoint("LEFT", n * 24, 0)
                b.ring = UI:Icon(b, "circle", 20, nil, "BACKGROUND"); b.ring:SetPoint("CENTER")
                b.dot = UI:Icon(b, n == 0 and "close" or "circle", n == 0 and 12 or 14, nil, "ARTWORK"); b.dot:SetPoint("CENTER")
                local a = UI.accents[n]
                if a then b.dot:SetVertexColor(a[1], a[2], a[3], 1) else b.dot:SetVertexColor(unpack(C.muted)) end
                b:SetScript("OnClick", function() cfg.accent2 = (n > 0) and n or nil; apply() end)
                g2dots[n] = b
            end
            UI:OnAccent(function()
                for n, b in pairs(g2dots) do
                    local on = (cfg.accent2 or 0) == n
                    local r, g, bl = UI:Accent()
                    b.ring:SetVertexColor(r, g, bl, on and 1 or 0)
                end
            end)
            UI:SettingRow(pf, -92, "Dégradé d'accent", "2e couleur des jauges (barre d'XP, progression…) ; la croix : aucune.", g2, 260)
            local tintSeg = UI:Segmented(pf, { { "cold", "Froid" }, { "neutral", "Neutre" }, { "warm", "Chaud" } },
                function(v) cfg.bgTint = (v ~= "neutral") and v or nil; apply() end, 28)
            tintSeg:Select(cfg.bgTint or "neutral")
            UI:SettingRow(pf, -138, "Teinte du fond", "Graphite plus bleuté ou plus chaud.", tintSeg, 230)
            local perChar = UI:Toggle(pf, function() return cfg.accentPerChar end, function(v)
                cfg.accentPerChar = v or nil
                if v then cfg.charAccent = cfg.charAccent or {}; cfg.charAccent[WK:CharKey()] = cfg.charAccent[WK:CharKey()] or cfg.accent end
                UI:SetAccent(UI:AccentChoice())
            end)
            UI:SettingRow(pf, -184, "Accent par perso", "Chaque perso garde sa couleur : choisis-la ci-dessus quand il est connecté.", perChar, 80)
            local glow = UI:Slider(pf, 180, 0, 2, 0.1, function() return cfg.glow or 1 end,
                function(v) cfg.glow = (math.abs(v - 1) < 0.01) and nil or v; apply() end, "%.1f")
            UI:SettingRow(pf, -230, "Halo du cadre", "Lueur en haut de la fenêtre (0 : aucune).", glow, 260)
        end

        ---------------------------------------------------------------- Texte
        do
            local pf = panes.text
            local SHORT = { friz = "Friz", arialn = "Arial N.", morpheus = "Morpheus", skurri = "Skurri" }
            local fontOpts = {}
            for _, f in ipairs(UI.fonts) do table.insert(fontOpts, { f.key, SHORT[f.key] or f.label }) end
            local fontSeg = UI:Segmented(pf, fontOpts, function(v) cfg.font = v; apply(); UI:ApplyGameTooltipFonts() end, 28)
            fontSeg:Select(cfg.font or "friz")
            UI:SettingRow(pf, 0, "Police", "Texte de l'interface.", fontSeg, 290)
            local tOpts = { { "same", "Texte" } }
            for _, f in ipairs(UI.fonts) do table.insert(tOpts, { f.key, SHORT[f.key] or f.label }) end
            local titleSeg = UI:Segmented(pf, tOpts, function(v) cfg.titleFont = (v ~= "same") and v or nil; apply() end, 28)
            titleSeg:Select(cfg.titleFont or "same")
            UI:SettingRow(pf, -46, "Police des titres", "Titres des cartes (Texte : la même que le texte).", titleSeg, 330)
            local tsize = UI:Slider(pf, 180, 85, 125, 5,
                function() return math.floor((cfg.textScale or 1) * 100 + 0.5) end,
                function(v) cfg.textScale = (v ~= 100) and v / 100 or nil; apply() end, "%d %%")
            UI:SettingRow(pf, -92, "Taille du texte", "Fenêtre tout de suite ; éléments à l'écran au prochain /reload.", tsize, 260)
            local conSeg = UI:Segmented(pf, { { "soft", "Doux" }, { "normal", "Normal" }, { "strong", "Fort" } },
                function(v) cfg.contrast = (v ~= "normal") and v or nil; apply() end, 28)
            conSeg:Select(cfg.contrast or "normal")
            UI:SettingRow(pf, -138, "Contraste", "Textes secondaires : plus discrets ou plus lisibles.", conSeg, 230)
        end

        ---------------------------------------------------------------- Formes et effets
        do
            local pf = panes.shapes
            local round = UI:Slider(pf, 180, 0, 1.4, 0.1, function() return cfg.rounding or 1 end,
                function(v) cfg.rounding = v; apply() end, "%.1f")
            UI:SettingRow(pf, 0, "Arrondi", "Fenêtres, cartes et boutons (0 : carré).", round, 260)
            local cardSeg = UI:Segmented(pf, { { "flat", "Plat" }, { "line", "Liseré" }, { "halo", "Halo" } },
                function(v) cfg.cardStyle = (v ~= "line") and v or nil; apply() end, 28)
            cardSeg:Select(cfg.cardStyle or "line")
            UI:SettingRow(pf, -46, "Style des cartes", "Plat : sans bordure · Liseré : fine bordure · Halo : lueur en haut.", cardSeg, 230)
            local bgSeg = UI:Segmented(pf, { { "none", "Uni" }, { "grain", "Grain" }, { "stone", "Pierre" }, { "parchment", "Parchemin" } },
                function(v) cfg.bgTexture = (v ~= "none") and v or nil; apply() end, 28)
            bgSeg:Select(cfg.bgTexture or "none")
            UI:SettingRow(pf, -92, "Fond de fenêtre", "Texture du jeu, très discrète.", bgSeg, 330)
            local animSeg = UI:Segmented(pf, { { "none", "Aucune" }, { "soft", "Fondu" } },
                function(v) cfg.anim = (v == "none") and "none" or nil end, 28)
            animSeg:Select(cfg.anim == "none" and "none" or "soft")
            UI:SettingRow(pf, -138, "Animation", "Fondu à l'ouverture de la fenêtre.", animSeg, 180)
        end

        ---------------------------------------------------------------- Fenêtre
        do
            local pf = panes.window
            local sideSeg = UI:Segmented(pf, { { "left", "À gauche" }, { "right", "À droite" }, { "icons", "Icônes seules" } },
                function(v)
                    cfg.sideRight = (v == "right") or nil
                    cfg.collapsed = (v == "icons") or nil
                    UI:Relayout()
                end, 28)
            sideSeg:Select(cfg.collapsed and "icons" or (cfg.sideRight and "right" or "left"))
            UI:SettingRow(pf, 0, "Barre latérale", "Côté du menu, ou menu réduit en icônes.", sideSeg, 330)
            local opacity = UI:Slider(pf, 180, 0.6, 1, 0.05, function() return cfg.opacity or 1 end,
                function(v) cfg.opacity = v; apply() end, "%.2f")
            UI:SettingRow(pf, -46, "Opacité du fond", "Appliquée au relâchement.", opacity, 260)
            local slider = UI:Slider(pf, 180, 0.7, 1.3, 0.05, function() return cfg.scale or 1 end,
                function(v) UI:ApplyScale(v) end, "%.2fx")
            UI:SettingRow(pf, -92, "Échelle de la fenêtre", "Appliquée au relâchement du curseur.", slider, 260)
            local tip = UI:Slider(pf, 180, 0.6, 1, 0.05, function() return cfg.tipOpacity or 1 end,
                function(v) cfg.tipOpacity = (v < 0.999) and v or nil end, "%.2f")
            UI:SettingRow(pf, -138, "Infobulles", "Opacité de leur fond (à la prochaine infobulle).", tip, 260)
            self.portraitToggle = UI:Toggle(pf, function() return cfg.portraits ~= false end,
                function(v) cfg.portraits = v; WK:NotifyChanged() end)
            UI:SettingRow(pf, -184, "Portraits des persos", "Vrai portrait pour le perso connecté, sinon icône de classe.", self.portraitToggle, 80)
        end
        showTab(cfg.lookTab or "styles")
        -- recherche de la barre latérale : un réglage trouvé ouvre son onglet
        current.tabOf = self.lookTabOf
        current.showTab = showTab

        ---------------------------------------------------------------- Partage et retour d'origine
        local STYLE_KEYS = { "accent", "accentRGB", "accent2", "bgTint", "font", "titleFont", "textScale", "rounding", "cardStyle",
            "opacity", "contrast", "bgTexture", "glow", "anim", "tipOpacity", "sideRight", "collapsed" }
        local P = WK.modules.Profiles
        local dlg = CreateFrame("Frame", "WarbandKeeperStyleCode", UIParent)
        dlg:SetSize(480, 160); dlg:SetPoint("CENTER", 0, 80)
        dlg:SetFrameStrata("FULLSCREEN_DIALOG"); dlg:EnableMouse(true)
        UI:Panel(dlg, 12, C.surface, C.border)
        dlg.title = UI:Text(dlg, 14); dlg.title:SetPoint("TOPLEFT", 18, -16)
        dlg.text = UI:Text(dlg, 11, C.muted); dlg.text:SetPoint("TOPLEFT", 18, -40); dlg.text:SetPoint("RIGHT", -18, 0)
        dlg.text:SetJustifyH("LEFT"); if dlg.text.SetWordWrap then dlg.text:SetWordWrap(true) end
        dlg.input = UI:Input(dlg, 444, 30, ""); dlg.input:SetPoint("TOPLEFT", 18, -76)
        if dlg.input.edit.SetMaxLetters then dlg.input.edit:SetMaxLetters(0) end
        dlg.ok = UI:Button(dlg, "Appliquer", nil, 28, "primary"); dlg.ok:SetPoint("BOTTOMRIGHT", -18, 14)
        dlg.close = UI:Button(dlg, "Fermer", nil, 28, "ghost"); dlg.close:SetPoint("RIGHT", dlg.ok, "LEFT", -8, 0)
        dlg.close:SetScript("OnClick", function() dlg:Hide() end)
        dlg:Hide()
        if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperStyleCode") end
        local function applyStyle(t)
            local uc = WK.DB.global.settings.ui -- la table en place (un profil peut l'avoir remplacée)
            for _, k in ipairs(STYLE_KEYS) do
                local v = t[k]
                local ok = v == nil or type(v) == "number" or type(v) == "string" or type(v) == "boolean"
                    or (k == "accentRGB" and type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number")
                if ok then uc[k] = v end
            end
            if uc.accentPerChar and uc.charAccent then uc.charAccent[WK:CharKey()] = nil end
            apply()
        end
        UI.ApplyStyleTable = applyStyle
        local shareBtn = UI:Button(lc, "Partager mon style", nil, 26, "secondary")
        shareBtn:SetPoint("BOTTOMLEFT", 16, 16)
        shareBtn:SetScript("OnClick", function()
            local t = {}
            for _, k in ipairs(STYLE_KEYS) do t[k] = cfg[k] end
            if cfg.accentPerChar then t.accent = UI:AccentChoice() end
            local code = P:EncodeTable(t, "WKS1:")
            dlg.title:SetText(WK.T("Mon style"))
            dlg.text:SetText(WK.T("Ctrl+C pour copier, puis « Coller un style » chez un autre perso, un autre compte ou un ami."))
            dlg.input:SetText(code); dlg.ok:Hide()
            dlg:Show(); dlg.input.edit:SetFocus(); dlg.input.edit:HighlightText()
        end)
        local pasteBtn = UI:Button(lc, "Coller un style", nil, 26, "secondary")
        pasteBtn:SetPoint("LEFT", shareBtn, "RIGHT", 8, 0)
        local function doPaste()
            local t, err = P:DecodeTable(dlg.input:GetText(), "WKS1:")
            if not t then dlg.text:SetText(err); dlg.text:SetTextColor(unpack(C.warning)) return end
            dlg:Hide()
            applyStyle(t)
        end
        pasteBtn:SetScript("OnClick", function()
            dlg.title:SetText(WK.T("Coller un style"))
            dlg.text:SetText(WK.T("Colle un code de style (WKS1:…) avec Ctrl+V : couleurs, police, formes et fenêtre changent d'un coup."))
            dlg.text:SetTextColor(unpack(C.muted))
            dlg.input:SetText(""); dlg.ok:Show()
            dlg:Show(); dlg.input.edit:SetFocus()
        end)
        dlg.ok:SetScript("OnClick", doPaste)
        dlg.input.onEnter = function() if dlg.ok:IsShown() then doPaste() end end
        local resetBtn = UI:Button(lc, "Apparence d'origine", nil, 26, "ghost", "refresh")
        resetBtn:SetPoint("BOTTOMRIGHT", -16, 16)
        resetBtn.tooltip = "Maj + clic : remet couleurs, police, formes et fenêtre comme au départ."
        resetBtn:SetScript("OnClick", function()
            if not IsShiftKeyDown() then return end
            local t = { accent = "theme" }
            applyStyle(t)
        end)

        -- aperçu en direct : titre, pastille, carte avec jauge, boutons et interrupteur, aux réglages en place
        local pv = UI:Text(rc, 10, C.muted); pv:SetPoint("TOPLEFT", 6, -44); pv:SetText(WK.T("APERÇU EN DIRECT"))
        local box = CreateFrame("Frame", nil, rc)
        box:SetPoint("TOPLEFT", 0, -62); box:SetPoint("RIGHT", 0, 0); box:SetHeight(212)
        UI:Panel(box, 12, C.bg, C.border)
        local ttl = UI:Text(box, 13); ttl:SetPoint("TOPLEFT", 14, -14); ttl:SetText("Warband Keeper")
        UI:OnAccent(function() ttl:SetTextColor(UI:Accent()) end)
        local chip = CreateFrame("Frame", nil, box); chip:SetSize(84, 24); chip:SetPoint("TOPRIGHT", -12, -10)
        chip.edge = UI:Rounded(chip, 12, 0, "BACKGROUND", 0); chip.bg = UI:Rounded(chip, 11, 1, "BACKGROUND", 1)
        chip.t = UI:Text(chip, 11); chip.t:SetPoint("CENTER")
        UI:OnAccent(function()
            local r, g, b = UI:Accent()
            chip.edge:SetColor(r, g, b, 0.55); chip.bg:SetColor(r * 0.18, g * 0.18, b * 0.18, 1)
            chip.t:SetText(UI:Hex(C.muted) .. WK.T("Or") .. "|r  " .. UI:Hex({ r, g, b }) .. "7 po|r")
        end)
        local sample = UI:Card(box, WK.T("Carte d'exemple"))
        sample:SetPoint("TOPLEFT", 12, -46); sample:SetPoint("TOPRIGHT", -12, -46); sample:SetHeight(96)
        local st = UI:Text(sample, 11, C.muted); st:SetPoint("TOPLEFT", 16, -40); st:SetText(WK.T("Texte secondaire de l'interface"))
        local bar = UI:Progress(sample, 6); bar:SetPoint("TOPLEFT", 16, -68); bar:SetPoint("RIGHT", -16, 0); bar:SetValue(0.62)
        local b1 = UI:Button(box, "Principal", nil, 28, "primary"); b1:SetPoint("BOTTOMLEFT", 12, 14)
        local b2 = UI:Button(box, "Secondaire", nil, 28, "secondary"); b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
        local tg = UI:Toggle(box, function() return true end, function() end); tg:SetPoint("BOTTOMRIGHT", -14, 18)
        local note = UI:Text(rc, 11, C.muted); note:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 4, -12); note:SetPoint("RIGHT", 0, 0)
        note:SetJustifyH("LEFT"); if note.SetWordWrap then note:SetWordWrap(true) end
        note:SetText(WK.T("Chaque réglage change l'aperçu et la fenêtre tout de suite ; les curseurs, au relâchement."))

        -- Général : langue, bouton minimap, fenêtre ------------------------------------
        section("general")
        local langCard = card("Langue", 96)
        local lang = UI:Segmented(langCard, { { "auto", "Auto" }, { "frFR", "Français" }, { "enUS", "English" } },
            function(v) cfg.lang = v; apply() end, 30)
        lang:Select(cfg.lang or "auto")
        UI:SettingRow(langCard, -40, "Langue", "Auto : celle du jeu.", lang, 280)

        -- Infobulles : toutes les lignes que l'addon ajoute aux infobulles, à un seul endroit (onglet Infobulles),
        -- rangées en cartes par thème : apparence, prix, métiers, butin, PNJ
        do
            local function ttCard(title, sub, rows)
                local c = card(title, 40 + #rows * 54 + 8, sub)
                for n, r in ipairs(rows) do
                    local t = UI:Toggle(c, r[3], r[4])
                    self.ttToggles = self.ttToggles or {}
                    table.insert(self.ttToggles, t)
                    UI:SettingRow(c, -40 - (n - 1) * 54, r[1], r[2], t, 80)
                end
                return c
            end
            local PHc = function() return WK.modules.ProfHelp:Config() end
            local AHc = function() return WK.modules.AHScan:Config() end
            ttCard("Apparence des infobulles", "fond, bordure et police", {
                { "Infobulles du jeu au style de l'addon", "Objets, PNJ, sorts, liens du chat, comparaisons : fond, bordure et police de l'addon. Coupé : le style du jeu.",
                    function() return cfg.gameTooltipFont ~= false end, function(v) cfg.gameTooltipFont = v; UI:ApplyGameTooltipFonts() end },
            })
            ttCard("Objets : prix", "ce que vaut un objet", {
                { "Prix de l'hôtel des ventes", "Prix le plus bas à l'unité, moyenne sur 14 jours, quantité en vente et date du relevé.",
                    function() return AHc().tooltip end, function(v) AHc().tooltip = v end },
                { "Prix de la pile", "Ajoute le prix d'une pile entière pour les objets qui s'empilent.",
                    function() return AHc().stack end, function(v) AHc().stack = v end },
                { "Valeur de désenchantement", "Enchanteur sur le compte : ce que le désenchantement d'un objet rapporte en moyenne.",
                    function() return PHc().deTip end, function(v) PHc().deTip = v end },
            })
            ttCard("Objets : métiers", "à quoi sert un composant", {
                { "Montée des métiers", "Dans l'infobulle d'un objet : les métiers qui s'en servent pour monter, et combien il en faut encore à chacun de tes persos.",
                    function() return cfg.tooltipProf ~= false end, function(v) cfg.tooltipProf = v end },
                { "Fabriquer ou vendre", "Composant qu'une recette d'un de tes persos valorise mieux que la vente brute : la recette et ce qu'elle en tire à l'unité.",
                    function() return PHc().craftTip end, function(v) PHc().craftTip = v end },
            })
            ttCard("Objets : butin", "d'où vient un objet", {
                { "Butin observé", "Dans l'infobulle d'un objet : les monstres qui le lâchent et à quelle fréquence, d'après les butins relevés par les joueurs (Everloot).",
                    function() return cfg.tooltipDrops ~= false end, function(v) cfg.tooltipDrops = v end },
            })
            ttCard("PNJ", "au survol d'un personnage", {
                { "Quêtes du donneur", "Au survol d'un PNJ : ses quêtes que ce perso n'a pas encore faites.",
                    function() return WK.modules.Quests:Config().tooltip end, function(v) WK.modules.Quests:Config().tooltip = v; WK:NotifyChanged() end },
                { "Rares", "Au survol d'un rare : son butin notable, et lesquels de tes persos l'ont déjà tué.",
                    function() return WK.modules.Rares:Config().tooltip end, function(v) WK.modules.Rares:Config().tooltip = v end },
            })
        end
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
        local winCard = card("Combat", 96)
        self.combatToggle = UI:Toggle(winCard,
            function() return cfg.closeInCombat end,
            function(v) cfg.closeInCombat = v end)
        UI:SettingRow(winCard, -40, "Fermer la fenêtre en combat",
            "Au début d'un combat. La mini-fenêtre de la session de farm reste affichée.", self.combatToggle, 80)
        -- (affichée dans QoL > Général > Alertes, qui la reprend : dernière de la section)
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
        local win = card("Fenêtre", 88)
        UI:SettingRow(win, -40, "Notre fenêtre de courrier",
            "À la place de celle du jeu : Reçus, Envoyer, Rangement, Règles d'envoi et Historique au même endroit. « Fenêtre du jeu » y revient pour une visite.",
            toggle(win, function() return mcfg.window ~= false end, function(v) mcfg.window = v end), 80)
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
        local spotsCard = card("Coins de récolte", 136)
        UI:SettingRow(spotsCard, -40, "Enregistrer mes récoltes",
            "À chaque plante, minerai ou cuir ramassé, l'endroit est noté (tous les persos).",
            gtoggle(spotsCard, function() return gm.record end, function(v) gm.record = v end), 80)
        -- (l'affichage sur la carte du monde est celui du calque « Filons et plantes », réglé plus bas)
        self.spotsInfo = UI:Text(spotsCard, 11, C.muted)
        self.spotsInfo:SetPoint("BOTTOMLEFT", 16, 18)
        local clearSpots = UI:Button(spotsCard, "Effacer", nil, 28, "danger", "trash")
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

        -- Profils (UI/Pages/Profiles.lua) -------------------------------------------
        section("profiles")
        UI:BuildProfileCards(self, card)

        -- Fiabilité (UI/Maintenance.lua) : erreurs notées et nettoyage des sauvegardes
        section("maint")
        UI:BuildMaintenanceCards(self, card)

        -- Patch notes (UI/Pages/Notes.lua) : page entière, construite à la première ouverture
        local notesHost = CreateFrame("Frame", nil, host)
        notesHost:SetAllPoints(); notesHost:Hide()
        self.sections.notes = { scroll = notesHost }

        -- À propos ----------------------------------------------------------------
        section("about")
        -- en-tête (logo, version, boutons), trois tuiles (ouvrir, commandes, à faire une fois), puis le tableau
        -- des sources : ce qui en vient, la source, la licence en pastille ; la mention complète au survol
        local T = WK.T
        local SRC = {
            { "map", "Lieux, rares, quêtes, boss, chemins", "QuestieDB · github.com/Questie/QuestieDB", "GPLv3", "warning",
                "Lieux du guidage (boîtes aux lettres, banques, marchands, maîtres de classe), monstres rares, quêtes, boss des donjons et chemins de base de la navigation (patrouilles des PNJ) : données de QuestieDB, base de l'addon Questie (github.com/Questie/QuestieDB, licence GPLv3)." },
            { "hammer", "Guides des métiers, butin des donjons", "wowtbc.gg", "cité", "muted",
                "Guides de montée des métiers et tables de butin des donjons et raids de WoW Forever : wowtbc.gg." },
            { "book", "Noms français, n° d'instance et de rencontre", "Tables du client WoW Forever · wago.tools", "jeu", "muted",
                "Noms français des donjons et des boss, numéros d'instance et de rencontre : tables du client WoW Forever (données du jeu, lues sur wago.tools)." },
            { "chart", "Trajets de vol, taux de drop observés", "Everloot · everloot.app", "CC BY-SA 4.0", "info",
                "Trajets de vol (fichiers du jeu) et taux de drop observés par les joueurs : Everloot (everloot.app ; taux de drop sous licence CC BY-SA 4.0)." },
            { "fire", "Objets de camp, objets de la liste BiS", "wowlayerup-forever/opendata", "CC BY 4.0", "info",
                "Objets de camp et objets portables de la liste BiS (n° d'objet, emplacement, caractéristiques, effet selon le niveau) : wowlayerup-forever/opendata (github.com/wowlayerup-forever/opendata, licence CC BY 4.0), données reprises et traduites." },
            { "boat", "Bateaux et zeppelins (trajets et quais)", "Fichiers du jeu · wago.tools", "jeu", "muted",
                "Bateaux et zeppelins : trajets et quais tirés de la table TaxiPathNode des fichiers du jeu (wago.tools)." },
            { "crosshair", "Distances (indicateur du chasseur)", "LibRangeCheck-3.0 · WoWUIDev Community", "MIT", "positive",
                "Distances de l'indicateur du chasseur : bibliothèque LibRangeCheck-3.0 (WoWUIDev Community, licence MIT)." },
        }
        local ROWH = 34
        -- en-tête 92, tuiles 70, titre et colonnes 28, en-têtes 18, lignes, marge
        local aboutH = 92 + 70 + 8 + 20 + 18 + #SRC * ROWH + 16
        local about = card(nil, aboutH)
        -- en-tête
        local logoBox = CreateFrame("Frame", nil, about); logoBox:SetSize(44, 44); logoBox:SetPoint("TOPLEFT", 16, -16)
        logoBox.ring = UI:Rounded(logoBox, 12, 0, "BACKGROUND", 1)
        logoBox.bg = UI:Rounded(logoBox, 11, 1, "BACKGROUND", 2)
        logoBox.ic = UI:Icon(logoBox, "logo", 26, nil, "ARTWORK"); logoBox.ic:SetPoint("CENTER")
        local name = UI:Text(about, 16, C.text); name:SetPoint("TOPLEFT", logoBox, "TOPRIGHT", 14, -4)
        local tag = UI:Text(about, 12, C.muted); tag:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -5)
        tag:SetText(T("Tous tes persos, leur or, leurs sacs et leurs métiers, au même endroit."))
        local function paintHead()
            local r, g, b = UI:Accent()
            logoBox.ring:SetColor(r, g, b, 1)
            logoBox.bg:SetColor(C.surface[1] * 0.8 + r * 0.2, C.surface[2] * 0.8 + g * 0.2, C.surface[3] * 0.8 + b * 0.2, 1)
            logoBox.ic:SetVertexColor(r, g, b, 1)
            name:SetText("Warband Keeper " .. UI:Hex({ r, g, b }) .. "v" .. WK.version .. "|r")
        end
        paintHead(); UI:OnAccent(paintHead)
        local notesBtn = UI:Button(about, "Voir les patch notes", nil, 30, "primary", "notes")
        notesBtn:SetPoint("TOPRIGHT", -16, -23)
        notesBtn:SetScript("OnClick", function() self:ShowSection("notes") end)
        local cmdBtn = UI:Button(about, "Commandes du chat", nil, 30, "secondary")
        cmdBtn:SetPoint("RIGHT", notesBtn, "LEFT", -8, 0)
        cmdBtn.tooltip = "Écrit la liste des commandes /wk dans le chat."
        cmdBtn:SetScript("OnClick", function() if SlashCmdList and SlashCmdList.WARBANDKEEPER then SlashCmdList.WARBANDKEEPER("aide") end end)
        local sep = about:CreateTexture(nil, "ARTWORK"); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", 16, -76); sep:SetPoint("TOPRIGHT", -16, -76); sep:SetColorTexture(unpack(C.border))
        -- tuiles
        local TILES = {
            { "OUVRIR", "|cffffffff/wk|r  ouvre cette fenêtre" },
            { "COMMANDES", "|cffffffff/wk aide|r  les liste dans le chat" },
            { "À FAIRE UNE FOIS", "Connecte chaque perso et ouvre sa banque pour qu'il soit enregistré." },
        }
        local tiles = {}
        for i, tl in ipairs(TILES) do
            local f = CreateFrame("Frame", nil, about)
            UI:Panel(f, 10, C.surface2, C.border)
            f.k = UI:Text(f, 10, C.dim); f.k:SetPoint("TOPLEFT", 12, -10); f.k:SetText(T(tl[1]))
            f.t = UI:Text(f, 12, C.muted); f.t:SetPoint("TOPLEFT", 12, -28); f.t:SetPoint("RIGHT", -12, 0)
            f.t:SetJustifyH("LEFT"); if f.t.SetWordWrap then f.t:SetWordWrap(true) end
            f.t:SetText(T(tl[2]))
            tiles[i] = f
        end
        -- tableau des sources
        local srcHead = UI:Text(about, 10, C.dim); srcHead:SetPoint("TOPLEFT", 16, -(92 + 70 + 8)); srcHead:SetText(T("SOURCES DES DONNÉES"))
        local colY = 92 + 70 + 8 + 20
        local h1 = UI:Text(about, 9, C.dim); h1:SetText(T("CE QUI EN VIENT"))
        local h2 = UI:Text(about, 9, C.dim); h2:SetText(T("SOURCE"))
        local h3 = UI:Text(about, 9, C.dim); h3:SetText(T("LICENCE"))
        local rowsA = {}
        for i, sd in ipairs(SRC) do
            local r = CreateFrame("Frame", nil, about)
            r:SetHeight(ROWH)
            r:EnableMouse(true)
            r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetHeight(1); r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT")
            r.line:SetColorTexture(unpack(C.border))
            r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 1, 1, 0.03); r.hl:Hide()
            r.icb = CreateFrame("Frame", nil, r); r.icb:SetSize(24, 24); r.icb:SetPoint("LEFT", 4, 0)
            r.icb.ring = UI:Rounded(r.icb, 12, 0, "BACKGROUND", 1)
            r.icb.bg = UI:Rounded(r.icb, 11, 1, "BACKGROUND", 2)
            r.ic = UI:Icon(r.icb, sd[1], 13, nil, "ARTWORK"); r.ic:SetPoint("CENTER")
            r.what = UI:Text(r, 12, C.text); r.what:SetText(T(sd[2])); r.what:SetJustifyH("LEFT")
            r.src = UI:Text(r, 12, C.muted); r.src:SetText(sd[3]); r.src:SetJustifyH("LEFT")
            for _, fs in ipairs({ r.what, r.src }) do if fs.SetWordWrap then fs:SetWordWrap(false) end end
            r.lic = UI:Badge(r, sd[4], C[sd[5]] or C.muted)
            r:SetScript("OnEnter", function(row)
                row.hl:Show()
                UI:TooltipOwner(row, "ANCHOR_TOP")
                GameTooltip:AddLine(sd[3], 1, 1, 1)
                GameTooltip:AddLine(T(sd[6]), 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function(row) row.hl:Hide(); GameTooltip:Hide() end)
            rowsA[i] = r
        end
        local function paintRows()
            local r1, g1, b1 = UI:Accent()
            for _, r in ipairs(rowsA) do
                r.icb.ring:SetColor(r1, g1, b1, 1)
                r.icb.bg:SetColor(C.surface[1] * 0.8 + r1 * 0.2, C.surface[2] * 0.8 + g1 * 0.2, C.surface[3] * 0.8 + b1 * 0.2, 1)
                r.ic:SetVertexColor(r1, g1, b1, 1)
            end
        end
        paintRows(); UI:OnAccent(paintRows)
        -- mise en page élastique
        UI:OnResize(about, function(w)
            w = w or about:GetWidth() or 800
            local inner = w - 32
            -- nom et phrase s'arrêtent avant les boutons (retour à la ligne si la fenêtre est étroite)
            local textW = math.max(120, w - 74 - (notesBtn:GetWidth() + cmdBtn:GetWidth() + 8) - 32)
            name:SetWidth(textW); name:SetJustifyH("LEFT")
            tag:SetWidth(textW); tag:SetJustifyH("LEFT")
            if tag.SetWordWrap then tag:SetWordWrap(true) end
            local tw = math.floor((inner - 20) / 3)
            for i, f in ipairs(tiles) do
                f:ClearAllPoints(); f:SetPoint("TOPLEFT", 16 + (i - 1) * (tw + 10), -92); f:SetSize(tw, 70)
            end
            local LIC_W = 110
            local whatX = 40
            local srcX = whatX + math.floor((inner - whatX - LIC_W) * 0.5)
            local licX = inner - LIC_W
            h1:ClearAllPoints(); h1:SetPoint("TOPLEFT", 16 + whatX, -colY)
            h2:ClearAllPoints(); h2:SetPoint("TOPLEFT", 16 + srcX, -colY)
            h3:ClearAllPoints(); h3:SetPoint("TOPLEFT", 16 + licX, -colY)
            for i, r in ipairs(rowsA) do
                local yy = colY + 18 + (i - 1) * ROWH
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 16, -yy); r:SetPoint("TOPRIGHT", -16, -yy)
                r.what:ClearAllPoints(); r.what:SetPoint("LEFT", whatX, 0); r.what:SetWidth(srcX - whatX - 12)
                r.src:ClearAllPoints(); r.src:SetPoint("LEFT", srcX, 0); r.src:SetWidth(licX - srcX - 12)
                r.lic:ClearAllPoints(); r.lic:SetPoint("LEFT", licX, 0)
            end
        end)
        current.scroll:SetContentHeight(y)
        -- Général en onglets par catégorie : Langue, Infobulles, Fenêtre (bouton minimap, combat)
        do
            local gsec = self.sections.general
            local child = gsec.scroll.child
            local TABS = { { "lang", "Langue", { ["Langue"] = true } }, { "tips", "Infobulles", { ["Apparence des infobulles"] = true, ["Objets : prix"] = true,
                ["Objets : métiers"] = true, ["Objets : butin"] = true, ["PNJ"] = true } },
                { "win", "Fenêtre", { ["Bouton minimap"] = true, ["Combat"] = true } } }
            local function tabOf(c)
                for _, t in ipairs(TABS) do if t[3][c.cardKey or ""] then return t[1] end end
            end
            local seg
            function gsec.showTab(key)
                cfg.optGenTab = key
                if seg then seg:Select(key) end
                local yy = 46
                for _, c in ipairs(gsec.cards or {}) do
                    local mine = c:GetParent() == child and tabOf(c)
                    if mine then
                        c:SetShown(mine == key)
                        if mine == key then
                            c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, -yy); c:SetPoint("TOPRIGHT", 0, -yy)
                            yy = yy + c:GetHeight() + GAP
                        end
                    end
                end
                gsec.scroll:SetContentHeight(yy)
                if gsec.scroll.SetVerticalScroll then gsec.scroll:SetVerticalScroll(0) end
            end
            local items = {}
            for _, t in ipairs(TABS) do table.insert(items, { t[1], t[2] }) end
            seg = UI:Segmented(child, items, function(k) gsec.showTab(k) end, 32)
            seg:SetPoint("TOPLEFT", 0, 0)
            gsec.tabOf = function(row)
                local f = row
                while f do
                    if f.cardKey then
                        local k = tabOf(f)
                        if k then for i, t in ipairs(TABS) do if t[1] == k then return i end end end
                    end
                    f = f:GetParent()
                end
            end
            local showByIndex = gsec.showTab
            gsec.showTab = function(k)
                if type(k) == "number" then k = TABS[k] and TABS[k][1] or "lang" end
                showByIndex(k)
            end
            gsec.showTab(cfg.optGenTab or "lang")
        end
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
        for _, t in ipairs(self.ttToggles or {}) do t:Refresh() end
        self.spotsInfo:SetText(string.format(WK.T("%d récoltes enregistrées"), WK.modules.GatherMap:Count()))
        if self.RefreshProfiles then self:RefreshProfiles() end

    end,
})
