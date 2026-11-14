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
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
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
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
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
    subtitle = "Thème, apparence, langue, bouton minimap et alertes.",

    Build = function(self, p)
        local cfg = WK.DB.global.settings.ui
        local alerts = WK.DB.global.settings.alerts
        local scroll = UI:Scroll(p)
        scroll:SetAllPoints()
        local root = scroll.child
        local W = UI.PAGE_W - 12
        local y = 0
        local function card(title, h)
            local c = UI:Card(root, title)
            c:SetSize(W, h)
            c:SetPoint("TOPLEFT", 0, -y)
            y = y + h + GAP
            return c
        end

        -- Les réglages marqués « rechargement » s'appliquent après /reload.
        local reloads = {}
        local function needReload() for _, r in ipairs(reloads) do r:Show() end end
        local function reloadButton(parent)
            local r = UI:Button(parent, "Recharger pour appliquer", nil, 28, "primary", "refresh")
            r:SetScript("OnClick", function() ReloadUI() end)
            r:Hide()
            table.insert(reloads, r)
            return r
        end

        -- Thème -------------------------------------------------------------------
        local themeCard = card("Thème", 154)
        reloadButton(themeCard):SetPoint("TOPRIGHT", -12, -8)
        local n = #UI.themes
        local tw = (W - 32 - (n - 1) * 10) / n
        self.themeTiles = {}
        for i, th in ipairs(UI.themes) do
            local tile = ThemeTile(themeCard, th, tw, function()
                cfg.theme = th.key
                cfg.accent = "theme"
                UI:SetAccent("theme")
                self:RefreshThemes()
                needReload()
            end)
            tile:SetPoint("TOPLEFT", 16 + (i - 1) * (tw + 10), -44)
            self.themeTiles[th.key] = tile
        end
        function self:RefreshThemes()
            for key, tile in pairs(self.themeTiles) do tile:Refresh(key == cfg.theme) end
        end

        -- Apparence --------------------------------------------------------------
        local look = card("Apparence", 356)
        reloadButton(look):SetPoint("TOPRIGHT", -12, -8)
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
        UI:SettingRow(look, -40, "Couleur d'accent", "T : celle du thème. C : couleur de classe du perso connecté. Changement immédiat.", dots, 300)

        local fontSeg = UI:Segmented(look, { { "friz", "Friz Quadrata" }, { "arialn", "Arial Narrow" } },
            function(v) cfg.font = v; needReload() end, 30)
        fontSeg:Select(cfg.font or "friz")
        UI:SettingRow(look, -92, "Police", "Police du texte de l'interface (rechargement).", fontSeg, 280)

        local roundSeg = UI:Segmented(look, { { 1, "Fort" }, { 0.6, "Moyen" }, { 0.25, "Carré" } },
            function(v) cfg.rounding = v; needReload() end, 30)
        roundSeg:Select(cfg.rounding or 1)
        UI:SettingRow(look, -144, "Arrondi", "Arrondi des fenêtres, cartes et boutons (rechargement).", roundSeg, 280)

        local opacity = UI:Slider(look, 240, 0.6, 1, 0.05,
            function() return cfg.opacity or 1 end,
            function(v) cfg.opacity = v; needReload() end, "%.2f")
        UI:SettingRow(look, -196, "Opacité du fond", "Transparence du fond de la fenêtre (rechargement).", opacity, 260)

        local slider = UI:Slider(look, 240, 0.7, 1.3, 0.05,
            function() return cfg.scale or 1 end,
            function(v) UI:ApplyScale(v) end, "%.2fx")
        UI:SettingRow(look, -248, "Échelle de la fenêtre", "Appliquée au relâchement du curseur.", slider, 260)

        local lang = UI:Segmented(look, { { "auto", "Auto" }, { "frFR", "Français" }, { "enUS", "English" } },
            function(v) cfg.lang = v; needReload() end, 30)
        lang:Select(cfg.lang or "auto")
        UI:SettingRow(look, -300, "Langue", "Auto : celle du jeu (rechargement).", lang, 280)

        -- Bouton minimap -----------------------------------------------------------
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

        -- Alertes -------------------------------------------------------------------
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
        local about = card("À propos", 120)
        local t = UI:Text(about, 12, C.muted)
        t:SetPoint("TOPLEFT", 16, -42)
        t:SetPoint("TOPRIGHT", -16, -42)
        t:SetJustifyV("TOP")
        if t.SetWordWrap then t:SetWordWrap(true) end
        t:SetSpacing(4)
        local T = WK.T
        t:SetText("Warband Keeper v" .. WK.version .. "\n"
            .. T("Commandes : |cffffffff/wk|r ouvre cette fenêtre, |cffffffff/wk aide|r liste les commandes du chat.") .. "\n"
            .. T("Connecte-toi une fois sur chaque personnage et ouvre sa banque pour qu'il soit enregistré."))
        scroll:SetContentHeight(y)
    end,

    Refresh = function(self)
        self:RefreshThemes()
        self.mmToggle:Refresh()
        self.alertToggle:Refresh()
    end,
})
