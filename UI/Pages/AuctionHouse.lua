local ADDON_NAME, WK = ...
local UI = WK.UI
local T = function(s) return WK.T(s) end

-- Page « Hôtel des ventes » (groupe Trésorerie) : tous les réglages de l'HV au même endroit, en cartes
-- sur deux colonnes : source des prix (reprise d'Options), panneau et scan, prix relevés, vente, alertes
-- de prix (reprises de la section « ah » de QoL, cachée). Les prix dans l'infobulle sont dans
-- Options > Infobulles ; la fenêtre de l'HV elle-même est en jeu (UI/AuctionTabs.lua).
local GAP = 12

UI:RegisterPage({
    key = "auction", order = 5.5, nav = "Hôtel des ventes",
    title = "Hôtel des ventes",
    subtitle = "Prix, scan, vente et alertes de prix.",

    Build = function(self, p)
        local sc = UI:Scroll(p)
        sc:SetAllPoints()
        self.sc = sc
        self.cards = {}
        for _, c in ipairs(UI:SectionCards("options", "prices")) do table.insert(self.cards, c) end
        for _, c in ipairs(UI:SectionCards("qol", "ah")) do table.insert(self.cards, c) end
        for _, c in ipairs(self.cards) do c:SetParent(sc.child); c:Show() end
        -- sous-onglets de catégories (UI:CardTabs)
        self.ct = UI:CardTabs(p, "auction", {
            { "scan", T("Scan et prix"), titles = { "Prix des objets", "Hôtel des ventes", "Prix relevés" } },
            { "sell", T("Vente"), titles = { "Vente" } },
            { "alerts", T("Alertes de prix"), titles = { "Alertes de prix" } },
        }, function() self:Layout() end)
        UI:OnResize(sc, function() self:Layout() end)
    end,

    Layout = function(self)
        local list = self.ct:Filter(self.cards)
        local bh = self.ct:Height()
        if self.ct.bar then
            self.ct.bar:ClearAllPoints(); self.ct.bar:SetPoint("TOPLEFT", self.sc:GetParent(), "TOPLEFT", 0, 0)
        end
        self.sc:ClearAllPoints(); self.sc:SetPoint("TOPLEFT", 0, -bh); self.sc:SetPoint("BOTTOMRIGHT")
        local W = math.max(400, (self.sc:GetWidth() or 800) - 12)
        self.sc.child:SetWidth(W)
        local cols = W < 760 and 1 or 2
        local cw = cols == 1 and W or math.floor((W - GAP) / 2)
        local colY = { 0, 0 }
        for _, c in ipairs(list) do
            local col = (cols == 2 and colY[2] < colY[1]) and 2 or 1
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", (col - 1) * (cw + GAP), -colY[col])
            c:SetWidth(cw)
            colY[col] = colY[col] + (c:GetHeight() or 100) + GAP
        end
        self.sc:SetContentHeight(math.max(colY[1], colY[2]))
    end,

    -- recherche : un réglage d'une autre catégorie ouvre son onglet
    RevealSetting = function(self, row)
        local f = row
        while f do
            if f:GetParent() == self.sc.child then if self.ct:Reveal(f) then self:Layout() end return end
            f = f:GetParent()
        end
    end,

    Refresh = function(self)
        self:Layout()
        -- interrupteurs et textes des cartes reprises (tenus par QoL et Options)
        for _, key in ipairs({ "qol", "options" }) do
            local d = UI.pages[key]
            if d and d.frame then
                for _, t in ipairs(d.toggles or {}) do if t:IsVisible() then t:Refresh() end end
                for _, fn in ipairs(d.dyn or {}) do pcall(fn) end
                if key == "options" and d.Refresh then pcall(d.Refresh, d) end
            end
        end
    end,
})
