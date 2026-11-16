local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page « Pêche » (groupe FARM) : la collection de pêche (UI/FishingCollection.lua : album des
-- espèces et atlas des eaux). Les réglages du mode pêche et le carnet restent dans QoL > Pêche.
UI:RegisterPage({
    key = "fishing", order = 6.5, nav = "Pêche",
    title = "Pêche",
    subtitle = "Collection des espèces pêchées sur le compte, et où les pêcher.",

    Build = function(self, p)
        local sc = UI:Scroll(p)
        sc:SetPoint("TOPLEFT")
        sc:SetPoint("BOTTOMRIGHT")
        self.sc = sc
        local card = UI:Card(sc.child, T("Collection"), " ")
        card:SetPoint("TOPLEFT")
        card:SetPoint("TOPRIGHT")
        card:SetHeight(400)
        UI:OnResize(sc, function(w) sc.child:SetWidth(w - 12) end)
        self.coll = UI:FishCollection(card, function(h) sc:SetContentHeight(h + 8) end)
        sc:SetContentHeight(card:GetHeight() + 8)
    end,

    Refresh = function(self)
        if self.coll then self.coll:Refresh() end
    end,
})
