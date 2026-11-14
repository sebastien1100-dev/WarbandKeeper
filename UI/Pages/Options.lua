local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local GAP = 12

-- Pastille de couleur d'accent (ronde, anneau quand sélectionnée).
local function AccentDot(parent, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    b.ring = UI:Icon(b, "circle", 26, nil, "BACKGROUND")
    b.ring:SetPoint("CENTER")
    b.gapRing = UI:Icon(b, "circle", 22, C.surface, "BORDER")
    b.gapRing:SetPoint("CENTER")
    local a = UI.accents[index]
    b.dot = UI:Icon(b, "circle", 18, { a[1], a[2], a[3], 1 }, "ARTWORK")
    b.dot:SetPoint("CENTER")
    function b:Refresh()
        local sel = WK.DB.global.settings.ui.accent == index
        self.ring:SetVertexColor(a[1], a[2], a[3], 1)
        self.ring:SetShown(sel)
        self.gapRing:SetShown(sel)
    end
    b:SetScript("OnClick", function() UI:SetAccent(index) end)
    UI:OnAccent(function() b:Refresh() end)
    return b
end

UI:RegisterPage({
    key = "options", order = 10, navIcon = "gear",
    title = "Options",
    subtitle = "Apparence, langue, bouton minimap et alertes.",

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

        -- Apparence --------------------------------------------------------------
        local look = card("Apparence", 200)
        local dots = CreateFrame("Frame", nil, look)
        dots:SetSize(#UI.accents * 32, 26)
        for i = 1, #UI.accents do
            local d = AccentDot(dots, i)
            d:SetPoint("LEFT", (i - 1) * 32, 0)
        end
        UI:SettingRow(look, -40, "Couleur d'accent", "Boutons, interrupteurs, barres et graphiques.", dots, 220)

        local slider = UI:Slider(look, 240, 0.7, 1.3, 0.05,
            function() return cfg.scale or 1 end,
            function(v) UI:ApplyScale(v) end, "%.2fx")
        UI:SettingRow(look, -92, "Échelle de la fenêtre", "Appliquée au relâchement du curseur.", slider, 260)

        local langBox = CreateFrame("Frame", nil, look)
        local lang = UI:Segmented(langBox, { { "auto", "Auto" }, { "frFR", "Français" }, { "enUS", "English" } },
            function(v)
                cfg.lang = v
                self.reload:Show()
            end, 30)
        lang:SetPoint("RIGHT")
        lang:Select(cfg.lang or "auto")
        self.reload = UI:Button(langBox, "Recharger", nil, 30, "primary")
        self.reload:SetPoint("RIGHT", lang, "LEFT", -8, 0)
        self.reload:SetScript("OnClick", function() ReloadUI() end)
        self.reload:Hide()
        langBox:SetSize(lang:GetWidth() + 120, 30)
        UI:SettingRow(look, -144, "Langue", "Auto : celle du jeu. Le changement demande de recharger l'interface.", langBox, 360)

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
        self.mmToggle:Refresh()
        self.alertToggle:Refresh()
    end,
})
