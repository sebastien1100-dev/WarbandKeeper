local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page « Pêche » (groupe Artisanat) : onglets Collection (UI/FishingCollection.lua : album des espèces
-- et atlas des eaux) et Carnet (carnet de pêche et dernières prises), roue dentée à droite pour les
-- réglages du mode pêche (cartes sur deux colonnes). Carnet et réglages sont les cartes construites par
-- la page QoL (section « fishing », `fishSection`), reprises ici une fois (`Adopt`) : leurs interrupteurs
-- et textes se rafraîchissent avec ceux de QoL.
local GAP = 12

UI:RegisterPage({
    key = "fishing", order = 6.5, nav = "Pêche",
    title = "Pêche",
    subtitle = "Collection des espèces pêchées sur le compte, carnet et réglages du mode pêche.",

    Build = function(self, p)
        self.view = "coll"
        local seg = UI:Segmented(p, { { "coll", "Collection" }, { "journal", "Carnet" } }, function(k)
            self.view = k; self:Refresh()
        end, 32)
        seg:SetPoint("TOPLEFT")
        seg:Select("coll")
        self.seg = seg
        -- roue dentée : réglages du mode pêche ; un second clic revient à l'onglet d'avant
        local gear = UI:IconButton(p, "gear", 32, "Réglages de pêche")
        gear:SetPoint("TOPRIGHT")
        gear:SetScript("OnClick", function()
            if self.view == "settings" then
                self.view = self.before or "coll"; self.before = nil
                seg:Select(self.view)
            else
                self.before = self.view; self.view = "settings"
                seg:Select(nil)
            end
            self:Refresh()
        end)
        self.gear = gear

        -- Collection
        local sc = UI:Scroll(p)
        sc:SetPoint("TOPLEFT", 0, -42)
        sc:SetPoint("BOTTOMRIGHT")
        self.sc = sc
        local card = UI:Card(sc.child, T("Collection"), " ")
        card:SetPoint("TOPLEFT")
        card:SetPoint("TOPRIGHT")
        card:SetHeight(400)
        UI:OnResize(sc, function(w) sc.child:SetWidth(w - 12) end)
        self.coll = UI:FishCollection(card, function(h) sc:SetContentHeight(h + 8) end)
        sc:SetContentHeight(card:GetHeight() + 8)

        -- Carnet et réglages : cartes reprises de QoL
        local function pane()
            local s = UI:Scroll(p)
            s:SetPoint("TOPLEFT", 0, -42)
            s:SetPoint("BOTTOMRIGHT")
            s:Hide()
            return s
        end
        self.jsc, self.ssc = pane(), pane()
        UI:OnResize(self.jsc, function() if self.jsc:IsShown() then self:Layout() end end)
        UI:OnResize(self.ssc, function() if self.ssc:IsShown() then self:Layout() end end)
        self:Adopt()
    end,

    -- Reprend les cartes de la section Pêche de QoL (une seule fois).
    Adopt = function(self)
        if self.jcards then return true end
        local qol = UI:EnsurePage("qol")
        local sec = qol and qol.fishSection
        if not sec or not sec.cards then return false end
        self.qol = qol
        self.jcards, self.scards = {}, {}
        for _, c in ipairs(sec.cards) do
            if c.journal then
                c:SetParent(self.jsc.child); table.insert(self.jcards, c)
            else
                c:SetParent(self.ssc.child); table.insert(self.scards, c)
            end
            c:Show()
        end
        return true
    end,

    -- Carnet : cartes l'une sous l'autre ; réglages : deux colonnes (chaque carte sous la plus courte).
    Layout = function(self)
        if not self.jcards then return end
        local jw = math.max(400, (self.jsc:GetWidth() or 800) - 12)
        self.jsc.child:SetWidth(jw)
        local y = 0
        for _, c in ipairs(self.jcards) do
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", 0, -y); c:SetWidth(jw)
            y = y + c:GetHeight() + GAP
        end
        self.jsc:SetContentHeight(y)
        local sw = math.max(400, (self.ssc:GetWidth() or 800) - 12)
        self.ssc.child:SetWidth(sw)
        local cw = math.floor((sw - GAP) / 2)
        local colY = { 0, 0 }
        for _, c in ipairs(self.scards) do
            local col = colY[1] <= colY[2] and 1 or 2
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", (col - 1) * (cw + GAP), -colY[col])
            c:SetWidth(cw)
            colY[col] = colY[col] + c:GetHeight() + GAP
        end
        self.ssc:SetContentHeight(math.max(colY[1], colY[2]))
    end,

    -- La recherche de la barre latérale : ouvrir la vue qui contient le réglage.
    RevealSetting = function(self, row)
        local f = row
        while f do
            if f == self.ssc.child then self.view = "settings"; self.seg:Select(nil); break end
            if f == self.jsc.child then self.view = "journal"; self.seg:Select("journal"); break end
            f = f:GetParent()
        end
        self:Refresh()
    end,

    Refresh = function(self)
        self:Adopt()
        local v = self.view
        self.sc:SetShown(v == "coll")
        self.jsc:SetShown(v == "journal")
        self.ssc:SetShown(v == "settings")
        self.gear:SetActive(v == "settings")
        if v == "coll" then
            if self.coll then self.coll:Refresh() end
        else
            self:Layout()
            -- interrupteurs et textes des cartes reprises (tenus par la page QoL)
            local q = self.qol
            if q then
                for _, t in ipairs(q.toggles or {}) do if t:IsVisible() then t:Refresh() end end
                for _, fn in ipairs(q.dyn or {}) do pcall(fn) end
            end
        end
    end,
})

-- Ouvre les réglages de pêche (roue dentée de la page Pêche).
function UI:OpenFishSettings()
    UI:ShowPage("fishing")
    local pg = UI.pages and UI.pages.fishing
    if pg and pg.gear and pg.view ~= "settings" then pg.gear:GetScript("OnClick")(pg.gear) end
end
