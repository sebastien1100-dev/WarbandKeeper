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
            if key == "profiles" and self.RefreshProfiles then self:RefreshProfiles() end
            if key == "diag" and not self.sections.diag.built then
                self.sections.diag.built = true
                UI:InAccentScope("window", UI.BuildDiagPanel, UI, self.sections.diag.scroll)
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
            { "diag", "Diagnostics", "search", "Commandes de vérification" },
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
            -- point rouge sur la section qui a du nouveau : Patch notes pas lues, erreur pas vue (Fiabilité)
            b.dot = UI:Icon(b, "circle", 8, nil, "OVERLAY")
            b.dot:SetPoint("TOPRIGHT", -10, -10)
            b.dot:SetVertexColor(unpack(C.negative))
            b.dot:Hide()
            local secKey = sec[1]
            function b:Paint()
                local news = false
                if secKey == "notes" then news = UI.notesDef and UI.notesDef.count and (UI.notesDef.count() or "") ~= "" or false
                elseif secKey == "maint" then local Mt = WK.modules.Maintenance; news = Mt and Mt:Unseen() > 0 or false end
                self.dot:SetShown(news)
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

        -- Apparence : onglets Styles / Couleurs / Texte / Formes / Fenêtre à gauche, aperçu en direct à droite
        -- (dessous si la carte est étroite), partage du style et retour d'origine en bas. La fenêtre se
        -- reconstruit à chaque changement : l'aperçu montre tout de suite le résultat.
        local LOOK_H, PV_H = 470, 330
        local look = card("Couleurs, police et taille", LOOK_H)
        local lookSec = current
        local lc = CreateFrame("Frame", nil, look)
        local rc = CreateFrame("Frame", nil, look)
        -- réglages à gauche et aperçu à droite si la carte est assez large, sinon l'aperçu passe dessous
        -- (la grille des styles demande 500 px, l'aperçu 250)
        local lookStacked
        UI:OnResize(look, function(w)
            if not w or w < 50 then return end
            local st = w < 800
            lc:ClearAllPoints(); rc:ClearAllPoints()
            lc:SetPoint("TOPLEFT", 0, 0)
            if st then
                lc:SetPoint("TOPRIGHT", 0, 0); lc:SetHeight(LOOK_H)
                rc:SetPoint("TOPLEFT", lc, "BOTTOMLEFT", 16, 30); rc:SetPoint("TOPRIGHT", lc, "BOTTOMRIGHT", -16, 30); rc:SetHeight(PV_H)
            else
                lc:SetPoint("BOTTOMLEFT", 0, 0); lc:SetWidth(math.max(520, math.floor(w * 0.62)))
                rc:SetPoint("TOPLEFT", lc, "TOPRIGHT", 8, 0); rc:SetPoint("BOTTOMRIGHT", -16, 16)
            end
            if st ~= lookStacked then
                lookStacked = st
                local h = st and (LOOK_H - 30 + PV_H + 6) or LOOK_H
                look:SetHeight(h)
                lookSec.scroll:SetContentHeight(h + GAP)
            end
        end)
        local LOOK_TABS = { { "styles", "Styles" }, { "colors", "Couleurs" }, { "text", "Texte" }, { "window", "Fenêtre" } }
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
        -- chaque style est un habillage (UI.SKINS) : forme des cartes, de la barre latérale, des pastilles, des
        -- jauges et des boutons, plus sa couleur, sa police des titres et son fond
        local STYLE_FIELDS = { "skin", "accent2", "bgTint", "bgTexture", "font", "titleFont", "rounding", "cardStyle", "glow", "glowTint", "contrast" }
        local STYLES = {
            { "graphite", "Graphite", { accent = 7, rounding = 1 } },
            { "heraldic", "Héraldique", { skin = "heraldic", accent = 8, accent2 = 1, rounding = 0.8 } },
            { "ink", "Encre", { skin = "ink", accent = 6, rounding = 1.2 } },
            { "leather", "Cuir et or", { skin = "leather", accent = 1, titleFont = "morpheus", bgTexture = "grain", rounding = 0.6 } },
        }
        do
            local pf = panes.styles
            local note = UI:Text(pf, 11, C.muted); note:SetPoint("TOPLEFT", 16, -2); note:SetPoint("TOPRIGHT", -16, -2)
            note:SetJustifyH("LEFT"); if note.SetWordWrap then note:SetWordWrap(true) end
            note:SetText(WK.T("Chaque style habille toute la fenêtre : barre latérale, cartes, pastilles, jauges et boutons. Règle ensuite le détail dans les autres onglets."))
            local fontPath = {}
            for _, f in ipairs(UI.fonts) do fontPath[f.key] = f.path end
            for n, st in ipairs(STYLES) do
                local d = st[3]
                local a = UI.accents[d.accent]
                local bg, line, surf = UI:TintedBase(d.bgTint, d.skin)
                local b = CreateFrame("Button", nil, pf)
                b:SetSize(230, 96)
                local col, row = (n - 1) % 2, math.floor((n - 1) / 2)
                b:SetPoint("TOPLEFT", 16 + col * 238, -38 - row * 104)
                local r0 = 4 + 8 * (d.rounding or 1)
                -- mini-fenêtre : cadre, fond, barre latérale, carte habillée, titre dans la police du style
                b.edge = UI:Rounded(b, r0 + 1, 0, "BACKGROUND", 0); b.edge:SetColor(line[1], line[2], line[3], 1)
                b.bg = UI:Rounded(b, r0, 1, "BACKGROUND", 1); b.bg:SetColor(bg[1], bg[2], bg[3], 1)
                if d.bgTexture then
                    local tx = b:CreateTexture(nil, "BACKGROUND", nil, 3)
                    tx:SetTexture(({ grain = "Interface\\DialogFrame\\UI-DialogBox-Background", stone = "Interface\\FrameGeneral\\UI-Background-Rock",
                        parchment = "Interface\\QuestFrame\\QuestBG" })[d.bgTexture])
                    tx:SetPoint("TOPLEFT", 3, -3); tx:SetPoint("BOTTOMRIGHT", -3, 3)
                    if tx.SetDesaturated then tx:SetDesaturated(true) end
                    tx:SetVertexColor(1, 1, 1, 0.12)
                end
                -- barre latérale
                local sb = b:CreateTexture(nil, "BACKGROUND", nil, 4)
                sb:SetPoint("TOPLEFT", 2, -2); sb:SetPoint("BOTTOMLEFT", 2, 2); sb:SetWidth(44)
                if d.skin == "heraldic" then sb:SetColorTexture(a[1] * 0.45, a[2] * 0.45, a[3] * 0.45, 1)
                elseif d.skin == "ink" then sb:SetColorTexture(0, 0, 0, 0)
                else sb:SetColorTexture(0, 0, 0, 0.18) end
                for k = 1, 4 do
                    local it = b:CreateTexture(nil, "ARTWORK")
                    it:SetSize(k == 1 and 30 or 24, 4); it:SetPoint("TOPLEFT", 9, -12 - k * 11)
                    if d.skin == "heraldic" then it:SetColorTexture(1, 1, 1, k == 1 and 0.95 or 0.45)
                    elseif k == 1 then it:SetColorTexture(a[1], a[2], a[3], 1)
                    else it:SetColorTexture(surf[1] * 1.8, surf[2] * 1.8, surf[3] * 1.8, 1) end
                end
                -- carte
                local mc = CreateFrame("Frame", nil, b)
                mc:SetPoint("TOPLEFT", 54, -10); mc:SetPoint("TOPRIGHT", -10, -10); mc:SetHeight(52)
                local cr = math.max(2, r0 - 4)
                if d.skin ~= "ink" then
                    mc.edge = UI:Rounded(mc, cr, 0, "BORDER", 0); mc.edge:SetColor(line[1], line[2], line[3], 1)
                    mc.bg = UI:Rounded(mc, cr - 1, 1, "BORDER", 1); mc.bg:SetColor(surf[1], surf[2], surf[3], 1)
                else
                    local lb = mc:CreateTexture(nil, "ARTWORK"); lb:SetColorTexture(a[1], a[2], a[3], 1)
                    lb:SetPoint("TOPLEFT", 0, -2); lb:SetPoint("BOTTOMLEFT", 0, 2); lb:SetWidth(2)
                end
                local tt = UI:Text(mc, d.skin == "ink" and 13 or 10)
                if d.titleFont and fontPath[d.titleFont] then tt:SetFont(fontPath[d.titleFont], 10, "") end
                tt:SetText(WK.T("Titre")); tt:SetTextColor(0.92, 0.92, 0.94)
                if d.skin == "heraldic" then
                    local band = mc:CreateTexture(nil, "ARTWORK", nil, 1)
                    band:SetPoint("TOPLEFT", 1, -1); band:SetPoint("TOPRIGHT", -1, -1); band:SetHeight(16)
                    band:SetColorTexture(a[1] * 0.55, a[2] * 0.55, a[3] * 0.55, 1)
                    tt:SetPoint("TOPLEFT", 7, -3); tt:SetTextColor(1, 1, 1)
                elseif d.skin == "leather" then
                    tt:SetPoint("TOP", 0, -4); tt:SetTextColor(a[1], a[2], a[3])
                    local fil = mc:CreateTexture(nil, "ARTWORK"); fil:SetColorTexture(a[1], a[2], a[3], 0.7)
                    fil:SetPoint("TOP", 0, -17); fil:SetSize(70, 1)
                    local in2 = UI:Rounded(mc, math.max(2, cr - 3), 3, "BORDER", 2); in2:SetColor(line[1], line[2], line[3], 0.6)
                    local in3 = UI:Rounded(mc, math.max(2, cr - 4), 4, "BORDER", 3); in3:SetColor(surf[1], surf[2], surf[3], 1)
                else
                    tt:SetPoint("TOPLEFT", d.skin == "ink" and 8 or 7, -4)
                end
                local tr = mc:CreateTexture(nil, "ARTWORK", nil, 2); tr:SetColorTexture(0, 0, 0, 0.35)
                tr:SetPoint("BOTTOMLEFT", 8, 9); tr:SetPoint("BOTTOMRIGHT", -8, 9); tr:SetHeight(d.skin == "ink" and 2 or 4)
                local bar = mc:CreateTexture(nil, "ARTWORK", nil, 3); bar:SetColorTexture(a[1], a[2], a[3], 1)
                bar:SetPoint("BOTTOMLEFT", 8, 9); bar:SetSize(90, d.skin == "ink" and 2 or 4)
                local name = UI:Text(b, 11); name:SetPoint("BOTTOMLEFT", 56, 10)
                if d.font and fontPath[d.font] then name:SetFont(fontPath[d.font], 11, "") end
                name:SetText(WK.T(st[2])); name:SetTextColor(a[1], a[2], a[3])
                b.sel = UI:Icon(b, "circle", 10, nil, "OVERLAY"); b.sel:SetPoint("BOTTOMRIGHT", -10, 10)
                b.sel:SetVertexColor(a[1], a[2], a[3], 1)
                -- style en place : mêmes réglages que ceux du style (un réglage changé ensuite le désélectionne)
                local function same(k, want, have)
                    if k == "glow" or k == "rounding" then return math.abs((want or 1) - (have or 1)) < 0.01 end
                    if k == "font" then return (want or "friz") == (have or "friz") end
                    return want == have
                end
                local function paint()
                    local on = UI:AccentChoice() == d.accent
                    for _, k in ipairs(STYLE_FIELDS) do if on and not same(k, d[k], cfg[k]) then on = false end end
                    b.sel:SetShown(on)
                    if on then b.edge:SetColor(a[1], a[2], a[3], 1) else b.edge:SetColor(line[1], line[2], line[3], 1) end
                end
                paint()
                b:SetScript("OnEnter", function(x) x.edge:SetColor(a[1], a[2], a[3], 1) end)
                b:SetScript("OnLeave", function() paint() end)
                b:SetScript("OnClick", function()
                    for _, k in ipairs(STYLE_FIELDS) do cfg[k] = d[k] end
                    if cfg.glow == 1 then cfg.glow = nil end
                    cfg.style = nil -- (ancien repère du style choisi : la sélection se lit sur les réglages)
                    UI:SetAccent(d.accent)
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
            -- (dégradé, teinte du fond, accent par perso et halo : retirés ; les styles les règlent)
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
            local tsize = UI:Slider(pf, 180, 85, 125, 5,
                function() return math.floor((cfg.textScale or 1) * 100 + 0.5) end,
                function(v) cfg.textScale = (v ~= 100) and v / 100 or nil; apply() end, "%d %%")
            UI:SettingRow(pf, -46, "Taille du texte", "Fenêtre tout de suite ; éléments à l'écran au prochain /reload.", tsize, 260)
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
            self.sideSeg = sideSeg -- aussi repliée par le bouton du bas de la barre : relu au rafraîchissement
            UI:SettingRow(pf, 0, "Barre latérale", "Côté du menu, ou menu réduit en icônes.", sideSeg, 330)
            local opacity = UI:Slider(pf, 180, 0.6, 1, 0.05, function() return cfg.opacity or 1 end,
                function(v) cfg.opacity = v; apply() end, "%.2f")
            UI:SettingRow(pf, -46, "Opacité du fond",
                "Fenêtre principale, appliquée au relâchement ; pleine au survol.", opacity, 260)
            local slider = UI:Slider(pf, 180, 0.7, 1.3, 0.05, function() return cfg.scale or 1 end,
                function(v) UI:ApplyScale(v) end, "%.2fx")
            UI:SettingRow(pf, -92, "Échelle de la fenêtre", "Appliquée au relâchement du curseur.", slider, 260)
            local tip = UI:Slider(pf, 180, 0.6, 1, 0.05, function() return cfg.tipOpacity or 1 end,
                function(v) cfg.tipOpacity = (v < 0.999) and v or nil end, "%.2f")
            UI:SettingRow(pf, -138, "Infobulles", "Opacité de leur fond (à la prochaine infobulle).", tip, 260)
            self.portraitToggle = UI:Toggle(pf, function() return cfg.portraits ~= false end,
                function(v) cfg.portraits = v; WK:NotifyChanged() end)
            UI:SettingRow(pf, -184, "Portraits des persos", "Vrai portrait pour le perso connecté, sinon icône de classe.", self.portraitToggle, 80)
            local hud = UI:Slider(pf, 180, 0.3, 1, 0.05, function() return cfg.hudOpacity or UI.HUD_ALPHA end,
                function(v) cfg.hudOpacity = v; UI.HudRefreshAll() end, "%.2f")
            UI:SettingRow(pf, -230, "Opacité des cadres à l'écran",
                "Toutes les fenêtres et cadres posés sur le jeu ; opacité pleine au survol de la souris.", hud, 260)
        end
        showTab(cfg.lookTab or "styles")
        UI.lookShow = function(k) self:ShowSection("look"); showTab(k) end
        -- recherche de la barre latérale : un réglage trouvé ouvre son onglet
        current.tabOf = self.lookTabOf
        current.showTab = showTab

        ---------------------------------------------------------------- Partage et retour d'origine
        local STYLE_KEYS = { "accent", "accentRGB", "accent2", "bgTint", "font", "titleFont", "textScale", "rounding", "cardStyle",
            "opacity", "contrast", "bgTexture", "glow", "glowTint", "anim", "tipOpacity", "sideRight", "collapsed", "skin",
            "hudOpacity" }
        -- bornes des curseurs : un code collé ne peut pas sortir de ce que l'Apparence propose
        local STYLE_RANGE = { rounding = { 0, 1.4 }, textScale = { 0.85, 1.25 }, opacity = { 0.6, 1 }, glow = { 0, 2 }, tipOpacity = { 0.6, 1 }, hudOpacity = { 0.3, 1 } }
        local P = WK.modules.Profiles
        -- fenêtre du code de style : créée une seule fois (la page est refaite à chaque UI:Rebuild)
        local dlg = UI.styleCodeDlg
        if not dlg then
            dlg = UI:InAccentScope("styleCode", function()
                local f = CreateFrame("Frame", "WarbandKeeperStyleCode", UIParent)
                f:SetSize(480, 160); f:SetPoint("CENTER", 0, 80)
                f:SetFrameStrata("FULLSCREEN_DIALOG"); f:EnableMouse(true)
                UI:Panel(f, 12, C.surface, C.border)
                f.title = UI:Text(f, 14); f.title:SetPoint("TOPLEFT", 18, -16)
                f.text = UI:Text(f, 11, C.muted); f.text:SetPoint("TOPLEFT", 18, -40)
                f.text:SetPoint("TOPRIGHT", -18, -40)
                f.text:SetJustifyH("LEFT"); if f.text.SetWordWrap then f.text:SetWordWrap(true) end
                f.input = UI:Input(f, 444, 30, ""); f.input:SetPoint("TOPLEFT", 18, -76)
                if f.input.edit.SetMaxLetters then f.input.edit:SetMaxLetters(0) end
                f.ok = UI:Button(f, "Appliquer", nil, 28, "primary"); f.ok:SetPoint("BOTTOMRIGHT", -18, 14)
                f.close = UI:Button(f, "Fermer", nil, 28, "ghost"); f.close:SetPoint("RIGHT", f.ok, "LEFT", -8, 0)
                f.close:SetScript("OnClick", function() f:Hide() end)
                f:Hide()
                if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperStyleCode") end
                return f
            end)
            UI.styleCodeDlg = dlg
        end
        dlg:Hide()
        dlg.bg:SetColor(unpack(C.surface)); dlg.border:SetColor(unpack(C.border)) -- couleurs du thème en place
        local function applyStyle(t)
            local uc = WK.DB.global.settings.ui -- la table en place (un profil peut l'avoir remplacée)
            for _, k in ipairs(STYLE_KEYS) do
                local v = t[k]
                local ok = v == nil or type(v) == "number" or type(v) == "string" or type(v) == "boolean"
                    or (k == "accentRGB" and type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number")
                if ok and type(v) == "number" and STYLE_RANGE[k] then v = math.max(STYLE_RANGE[k][1], math.min(STYLE_RANGE[k][2], v)) end
                if ok and k == "accentRGB" and v then
                    v = { math.max(0, math.min(1, v[1])), math.max(0, math.min(1, v[2])), math.max(0, math.min(1, v[3])) }
                end
                if ok then uc[k] = v end
            end
            uc.style = nil
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
        box:SetPoint("TOPLEFT", 0, -62); box:SetPoint("TOPRIGHT", 0, -62); box:SetHeight(212)
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
        local bar = UI:Progress(sample, 6); bar:SetPoint("TOPLEFT", 16, -68)
        bar:SetPoint("TOPRIGHT", -16, -68); bar:SetValue(0.62)
        local b1 = UI:Button(box, "Principal", nil, 28, "primary"); b1:SetPoint("BOTTOMLEFT", 12, 14)
        local b2 = UI:Button(box, "Secondaire", nil, 28, "secondary"); b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
        local tg = UI:Toggle(box, function() return true end, function() end); tg:SetPoint("BOTTOMRIGHT", -14, 18)
        local note = UI:Text(rc, 11, C.muted); note:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 4, -12)
        note:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -12)
        note:SetJustifyH("LEFT"); if note.SetWordWrap then note:SetWordWrap(true) end
        note:SetText(WK.T("Chaque réglage change l'aperçu et la fenêtre tout de suite ; les curseurs, au relâchement."))

        -- Général : langue, bouton minimap, fenêtre ------------------------------------
        section("general")
        local langCard = card("Langue", 96)
        local lang = UI:Segmented(langCard, { { "auto", "Auto" }, { "frFR", "Français" }, { "enUS", "English" } },
            function(v)
                cfg.lang = v
                WK.RefreshBindingNames()
                apply()
                -- la fenêtre suit tout de suite ; les HUD et les textes posés une seule fois, au /reload
                UI:AskReload(WK.T("Langue changée : recharge l'interface pour l'appliquer partout."))
            end, 30)
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
            ttCard("Objets", "prix, métiers et butin", {
                { "Prix de l'hôtel des ventes", "Prix le plus bas à l'unité, moyenne sur 14 jours, quantité en vente et date du relevé.",
                    function() return AHc().tooltip end, function(v) AHc().tooltip = v end },
                { "Prix de la pile", "Ajoute le prix d'une pile entière pour les objets qui s'empilent.",
                    function() return AHc().stack end, function(v) AHc().stack = v end },
                { "Valeur de désenchantement", "Enchanteur sur le compte : ce que le désenchantement d'un objet rapporte en moyenne.",
                    function() return PHc().deTip end, function(v) PHc().deTip = v end },
                { "Montée des métiers", "Dans l'infobulle d'un objet : les métiers qui s'en servent pour monter, et combien il en faut encore à chacun de tes persos.",
                    function() return cfg.tooltipProf ~= false end, function(v) cfg.tooltipProf = v end },
                { "Fabriquer ou vendre", "Composant qu'une recette d'un de tes persos valorise mieux que la vente brute : la recette et ce qu'elle en tire à l'unité.",
                    function() return PHc().craftTip end, function(v) PHc().craftTip = v end },
                { "Butin observé", "Dans l'infobulle d'un objet : les monstres qui le lâchent et à quelle fréquence, d'après les butins relevés par les joueurs (Everloot).",
                    function() return cfg.tooltipDrops ~= false end, function(v) cfg.tooltipDrops = v end },
            })
            ttCard("PNJ et apparence", "au survol d'un personnage, style des infobulles", {
                { "Quêtes du donneur", "Au survol d'un PNJ : ses quêtes que ce perso n'a pas encore faites.",
                    function() return WK.modules.Quests:Config().tooltip end, function(v) WK.modules.Quests:Config().tooltip = v; WK:NotifyChanged() end },
                { "Rares", "Au survol d'un rare : son butin notable, et lesquels de tes persos l'ont déjà tué.",
                    function() return WK.modules.Rares:Config().tooltip end, function(v) WK.modules.Rares:Config().tooltip = v end },
                { "Infobulles du jeu au style de l'addon", "Objets, PNJ, sorts, liens du chat, comparaisons : fond, bordure et police de l'addon. Coupé : le style du jeu.",
                    function() return cfg.gameTooltipFont ~= false end, function(v) cfg.gameTooltipFont = v; UI:ApplyGameTooltipFonts() end },
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
        local mm = card("Bouton minimap", 184)
        self.mmToggle = UI:Toggle(mm,
            function() return not cfg.minimap.hide end,
            function(v) cfg.minimap.hide = not v; WK.modules.MinimapButton:Update() end)
        UI:SettingRow(mm, -40, "Afficher le bouton", "Clic gauche : ouvrir. Clic droit : options. Glisser pour le déplacer.", self.mmToggle, 80)
        self.gmToggle = UI:Toggle(mm,
            function() return cfg.gameMenu ~= false end,
            function(v) cfg.gameMenu = v end)
        UI:SettingRow(mm, -88, "Raccourci dans le menu du jeu", "Un bouton « Warband Keeper » dans le menu Échap, au-dessus d'EllesmereUI (ou d'Add-ons).", self.gmToggle, 80)
        local reset = UI:Button(mm, "Recentrer", nil, 28, "secondary")
        UI:SettingRow(mm, -136, "Position de la fenêtre", nil, reset)
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

        -- (section cachée « alerts » : affichée seulement dans QoL > Général > Alertes, qui la reprend)
        local loginCard = card("Rappels à la connexion", 146)
        self.loginToggle = UI:Toggle(loginCard,
            function() return cfg.loginPopup ~= false end,
            function(v) cfg.loginPopup = v end)
        UI:SettingRow(loginCard, -40, "Fenêtre de rappels",
            "À la connexion d'un perso : courrier à prendre, recharges prêtes, métier au plafond…", self.loginToggle, 190)
        local preview = UI:Button(loginCard, "Aperçu", nil, 26, "ghost")
        preview:SetPoint("RIGHT", self.loginToggle, "LEFT", -12, 0)
        preview:SetScript("OnClick", function() UI:ShowLoginPopup(true) end)
        UI:SettingRow(loginCard, -92, "Durée d'affichage", "La fenêtre se ferme seule au bout de ce temps (pas tant que la souris est dessus). 0 : elle reste jusqu'à ce que tu la fermes.",
            UI:Slider(loginCard, 200, 0, 60, 1,
                function() local v = cfg.loginPopupTime; if v == nil then v = 5 end; return v end,
                function(v) cfg.loginPopupTime = v end, "%d s"), 220)
        -- Mini-fenêtre « À faire » (UI/TodoBar.lua) : tous ses réglages ici
        do
            local tc = UI.TodoConfig()
            local function redraw() if UI.RefreshTodoBar then UI:RefreshTodoBar() end end
            local kinds = UI.TODO_KINDS
            local half = math.ceil(#kinds / 2)
            local tcard = card("Mini-fenêtre « À faire »", 40 + 15 * 46 + 34 + half * 30 + 12,
                "barre de pastilles à l'écran, placée en mode édition")
            local ty = -40
            local function trow(label, desc, ctl, w) UI:SettingRow(tcard, ty, label, desc, ctl, w); ty = ty - 46 end
            local function tog(get, set) return UI:Toggle(tcard, get, function(v) set(v); redraw() end) end
            trow("Afficher la mini-fenêtre",
                "Une pastille par genre de tâche, avec son nombre ; survol = le détail, clic = la page.",
                tog(function() return cfg.todoBar ~= false end, function(v) cfg.todoBar = v end), 80)
            local scope = UI:Segmented(tcard, { { "all", "Tout le compte" }, { "me", "Ce perso" } },
                function(v) tc.scope = v; redraw() end, 26)
            scope:Select(tc.scope)
            trow("Tâches de", "Tout le compte, ou seulement celles du perso connecté.", scope, 230)
            trow("Titre « À faire »", "Le mot « À faire » au début de la barre.",
                tog(function() return tc.title end, function(v) tc.title = v end), 80)
            trow("Libellés", "Un mot à côté du nombre (« 2 plafond », « 1 repos »…) quand la tâche en a un.",
                tog(function() return tc.labels end, function(v) tc.labels = v end), 80)
            trow("Cacher quand il n'y a rien", "Sinon la barre affiche « rien à faire ».",
                tog(function() return tc.hideEmpty end, function(v) tc.hideEmpty = v end), 80)
            local size = UI:Segmented(tcard, { { "s", "Petite" }, { "m", "Moyenne" }, { "l", "Grande" } },
                function(v) tc.size = v; redraw() end, 26)
            size:Select(tc.size)
            trow("Taille des pastilles", "La taille d'ensemble se règle aussi en mode édition.", size, 260)
            local lay = UI:Segmented(tcard, { { "row", "En ligne" }, { "col", "En colonne" } },
                function(v) tc.vertical = v == "col"; redraw() end, 26)
            lay:Select(tc.vertical and "col" or "row")
            trow("Disposition", "Pastilles côte à côte, ou les unes sous les autres.", lay, 220)
            trow("Fond", "Fond graphite derrière les pastilles ; sans fond, seules les pastilles restent.",
                tog(function() return tc.bg end, function(v) tc.bg = v end), 80)
            trow("Pastilles au plus", "Les plus urgentes d'abord ; 0 : toutes.",
                UI:Slider(tcard, 220, 0, 15, 1, function() return tc.max or 0 end,
                    function(v) tc.max = v; redraw() end, "%d"), 240)
            -- taille et opacité : les mêmes que les curseurs du mode édition (la place, elle, se règle là-bas)
            local thud = function() return UI:HUDEntry("todoBar") end
            local function happly() if UI.HUDApply then UI:HUDApply("todoBar") end; redraw() end
            trow("Taille de la barre",
                "Toute la barre (la même que le curseur du mode édition ; la place se règle en mode édition).",
                UI:Slider(tcard, 220, 0.5, 2, 0.05, function() return thud().scale or 1 end,
                    function(v) thud().scale = v; happly() end, "%.2fx"), 240)
            trow("Opacité", "Transparence de toute la barre.",
                UI:Slider(tcard, 220, 0.1, 1, 0.05, function() return thud().alpha or 1 end,
                    function(v) thud().alpha = v; happly() end, "%.2f"), 240)
            trow("Pleine au survol", "La barre redevient opaque quand la souris passe dessus.",
                tog(function() return tc.hoverFull end, function(v) tc.hoverFull = v end), 80)
            trow("Infobulle au survol", "Le détail des tâches d'une pastille quand la souris passe dessus.",
                tog(function() return tc.tips end, function(v) tc.tips = v end), 80)
            trow("Clic sur une pastille", "Ouvre la page de la tâche (Courrier, Métiers…).",
                tog(function() return tc.click end, function(v) tc.click = v end), 80)
            trow("Cacher en combat", "La barre disparaît pendant les combats.",
                tog(function() return tc.hideCombat end, function(v) tc.hideCombat = v end), 80)
            -- pastilles affichées, genre par genre (deux colonnes)
            local head = UI:Text(tcard, 12, C.text)
            head:SetPoint("TOPLEFT", 16, ty - 6)
            head:SetText(WK.T("Pastilles affichées"))
            local gy = ty - 34
            for i, k in ipairs(kinds) do
                local col = i <= half and 0 or 1
                local row = (i - 1) % half
                local holder = _G.CreateFrame("Frame", nil, tcard)
                holder:SetSize(300, 26)
                holder:SetPoint("TOPLEFT", tcard, "TOPLEFT", 16 + col * 320, gy - row * 30)
                local key = k[1]
                local t = UI:Toggle(holder, function() return not tc.off[key] end,
                    function(v) tc.off[key] = (not v) or nil; redraw() end)
                t:SetPoint("LEFT", 0, 0)
                local l = UI:Text(holder, 12, C.text)
                l:SetPoint("LEFT", t, "RIGHT", 10, 0)
                l:SetText(WK.T(k[2]))
            end
        end
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

        -- Diagnostics (UI/Maintenance.lua) : liste et résultat, page entière construite à la première ouverture
        local diagHost = _G.CreateFrame("Frame", nil, host)
        diagHost:SetAllPoints(); diagHost:Hide()
        self.sections.diag = { scroll = diagHost }

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
            { "skull", "Cartes des donjons, boss, taux de drop", "Naowh Forever · Dungeon Journal", "accord", "positive",
                "Cartes des donjons (images du jeu), place et portrait des boss, taux de drop des objets : Dungeon Journal de Naowh Forever, repris avec l'accord de son auteur." },
            { "boat", "Bateaux et zeppelins (trajets et quais)", "Fichiers du jeu · wago.tools", "jeu", "muted",
                "Bateaux et zeppelins : trajets et quais tirés de la table TaxiPathNode des fichiers du jeu (wago.tools)." },
            { "book", "Prix des sorts de classe chez le maître", "What's Training · github.com/fusionpit/WhatsTraining", "MIT", "positive",
                "Prix de base des sorts de classe chez le maître (avant remise de réputation) : addon What's Training (github.com/fusionpit/WhatsTraining, licence MIT). Le prix relevé chez le maître passe devant." },
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
            f.t = UI:Text(f, 12, C.muted); f.t:SetPoint("TOPLEFT", 12, -28); f.t:SetPoint("TOPRIGHT", -12, -28)
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
            local TABS = { { "lang", "Langue", { ["Langue"] = true } }, { "tips", "Infobulles", { ["Objets"] = true, ["PNJ et apparence"] = true } },
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
        -- points rouges des sections (patch notes lues, erreurs vues : ils s'éteignent)
        for _, b in pairs(self.sectionButtons or {}) do b:Paint() end
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
        if self.gmToggle then self.gmToggle:Refresh() end
        self.combatToggle:Refresh()
        self.loginToggle:Refresh()
        self.portraitToggle:Refresh()
        if self.sideSeg then
            local ui = WK.DB.global.settings.ui
            self.sideSeg:Select(ui.collapsed and "icons" or (ui.sideRight and "right" or "left"))
        end
        self.alertToggle:Refresh()
        for _, t in ipairs(self.mailToggles) do t:Refresh() end
        for _, t in ipairs(self.glowToggles) do t:Refresh() end
        for _, t in ipairs(self.ttToggles or {}) do t:Refresh() end
        self.spotsInfo:SetText(string.format(WK.T("%d récoltes enregistrées"), WK.modules.GatherMap:Count()))
        -- profils : seulement quand la section est affichée (le code d'export recopie tous les réglages)
        local ps = self.sections and self.sections.profiles
        if self.RefreshProfiles and ps and ps.scroll:IsVisible() then self:RefreshProfiles() end
    end,
})
