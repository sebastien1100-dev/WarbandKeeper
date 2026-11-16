local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Petit panneau collé à droite de la fenêtre de l'hôtel des ventes : état des prix, bouton de scan
-- (complet si le jeu l'autorise, sinon page par page) et progression. Logique : Modules/AHScan.lua.
local S = WK.modules.AHScan
local panel

local function ago(t)
    if not t then return T("jamais") end
    local s = time() - t
    if s < 3600 then return string.format(T("il y a %d min"), math.max(1, math.floor(s / 60))) end
    if s < 86400 then return string.format(T("il y a %d h"), math.floor(s / 3600)) end
    return string.format(T("il y a %d j"), math.floor(s / 86400))
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperAHPanel", UIParent)
    f:SetSize(250, 136)
    UI:Panel(f, 12, C.surface, C.border)
    f.logo = UI:Icon(f, "logo", 16, nil, "ARTWORK")
    f.logo:SetPoint("TOPLEFT", 14, -12)
    f.title = UI:Text(f, 12)
    f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0)
    f.title:SetText("Warband Keeper")
    f.close = UI:IconButton(f, "close", 16)
    f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f.hidden = true; f:Hide() end)
    f.count = UI:Text(f, 18)
    f.count:SetPoint("TOPLEFT", 14, -36)
    f.countL = UI:Text(f, 11, C.muted)
    f.countL:SetPoint("BOTTOMLEFT", f.count, "BOTTOMRIGHT", 6, 2)
    f.when = UI:Text(f, 11, C.muted)
    f.when:SetPoint("TOPLEFT", f.count, "BOTTOMLEFT", 0, -4)
    f.bar = UI:Progress(f, 4)
    f.bar:SetPoint("TOPLEFT", 14, -82)
    f.bar:SetPoint("TOPRIGHT", -14, -82)
    f.btn = UI:Button(f, "Scanner l'HV", 222, 28, "primary")
    f.btn:SetPoint("BOTTOM", 0, 12)
    f.btn:SetScript("OnClick", function()
        if S.scan then S:Stop() else S:Start() end
    end)
    f.btn:SetScript("OnEnter", function(b)
        WK.UI:TooltipOwner(b, "ANCHOR_RIGHT")
        local _, all = S:CanQuery()
        GameTooltip:SetText(T("Scan de l'hôtel des ventes"), 1, 1, 1)
        GameTooltip:AddLine(all and T("Scan complet possible maintenant : toute l'HV en une fois.")
            or T("Scan complet pas encore permis par le jeu (environ toutes les 15 min) : le scan se fait page par page, plus lentement."), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(T("Les prix servent aux infobulles, à la valeur des stocks et aux métiers."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    f.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc > 1 then s.acc = 0; s:Refresh() end
    end)

    function f:Refresh()
        local d = S:Data()
        local r, g, b = UI:Accent()
        self.logo:SetVertexColor(r, g, b)
        self.count:SetText(tostring(S:Count()))
        self.countL:SetText(T("objets avec un prix"))
        local sc = S.scan
        if sc then
            local frac = (sc.total and sc.total > 0) and (sc.done or 0) / sc.total or 0
            self.bar:Show(); self.bar:SetValue(frac)
            if sc.phase == "wait" then self.when:SetText(T("Scan : réponse du serveur..."))
            elseif sc.pages then self.when:SetText(string.format(T("Scan page par page : %d / %d"), sc.done or 0, sc.total or 0))
            else self.when:SetText(string.format(T("Scan complet : %d / %d"), sc.done or 0, sc.total or 0)) end
            self.btn:SetLabel(T("Arrêter"))
            self.btn:SetStyle("secondary")
        else
            self.bar:Hide()
            local _, all = S:CanQuery()
            local cd = S:FullCooldown()
            local hint = all and T("complet possible") or (cd > 0 and string.format(T("complet dans ~%d min"), math.ceil(cd / 60)) or T("page par page"))
            self.when:SetText(T("Dernier scan") .. " " .. ago(d.last) .. "  ·  " .. hint)
            self.btn:SetLabel(T("Scanner l'HV"))
            self.btn:SetStyle("primary")
        end
    end
    return f
end

local function host() return AuctionHouseFrame or AuctionFrame end

local function show()
    if not S:Config().panel or not WK:FeatureOn("ah") then return end
    local h = host()
    if not h then return end
    panel = panel or build()
    panel.hidden = nil
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", h, "TOPRIGHT", 6, -12)
    panel:SetFrameStrata(h:GetFrameStrata() or "MEDIUM")
    panel:Show()
    panel:Refresh()
end

S.OnProgress = function() if panel and panel:IsShown() then panel:Refresh() end end
WK:On("AUCTION_HOUSE_SHOW", function() C_Timer.After(0.1, show) end)
WK:On("AUCTION_HOUSE_CLOSED", function() if panel then panel:Hide() end end)
