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
    key = "options", order = 10, section = "bas", icon = "gear",
    title = "Options",
    subtitle = "Apparence de la fenêtre et du bouton minimap.",

    Build = function(self, p)
        local cfg = WK.DB.global.settings.ui

        -- Apparence --------------------------------------------------------------
        local look = UI:Card(p, "Apparence")
        look:SetSize(UI.PAGE_W, 150)
        look:SetPoint("TOPLEFT")

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

        -- Bouton minimap -----------------------------------------------------------
        local mm = UI:Card(p, "Bouton minimap")
        mm:SetSize(UI.PAGE_W, 112)
        mm:SetPoint("TOPLEFT", 0, -150 - GAP)
        self.mmToggle = UI:Toggle(mm,
            function() return not cfg.minimap.hide end,
            function(v) cfg.minimap.hide = not v; WK.modules.MinimapButton:Update() end)
        UI:SettingRow(mm, -40, "Afficher le bouton", "Clic gauche : ouvrir. Clic droit : options. Glisser pour le déplacer.", self.mmToggle, 80)
        local reset = UI:Button(mm, "Recentrer la fenêtre", nil, 28, "secondary")
        reset:SetPoint("BOTTOMRIGHT", -16, 14)
        reset:SetScript("OnClick", function()
            cfg.point = nil
            UI.frame:ClearAllPoints()
            UI.frame:SetPoint("CENTER")
        end)

        -- À propos ----------------------------------------------------------------
        local about = UI:Card(p, "À propos")
        about:SetSize(UI.PAGE_W, UI.PAGE_H - 150 - 112 - 2 * GAP)
        about:SetPoint("TOPLEFT", 0, -150 - 112 - 2 * GAP)
        local t = UI:Text(about, 12, C.muted)
        t:SetPoint("TOPLEFT", 16, -42)
        t:SetPoint("RIGHT", -16, 0)
        t:SetJustifyV("TOP")
        if t.SetWordWrap then t:SetWordWrap(true) end
        t:SetSpacing(4)
        t:SetText("Warband Keeper v" .. WK.version .. "\n"
            .. "Commandes : |cffffffff/wk|r ouvre cette fenêtre, |cffffffff/wk aide|r liste les commandes du chat.\n"
            .. "Connecte-toi une fois sur chaque personnage et ouvre sa banque pour qu'il soit enregistré.")
    end,

    Refresh = function(self)
        self.mmToggle:Refresh()
    end,
})
