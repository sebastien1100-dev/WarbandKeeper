local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Barre d'expérience (Modules/XP.lua) : XP du niveau (accent), repos (bleu), XP des quêtes terminées à rendre
-- (jaune, avec un trait où tu arriverais en les rendant). Libellés au-dessus (sauf en compact), tout le
-- détail en infobulle. Cachée au niveau maximum. Se place en mode édition (HUD « xpbar »).
local M = WK.modules.XP
local bar
local W, BH = 520, 8
local BLUE = { 0.38, 0.62, 0.95 }
local YELLOW = { 0.96, 0.80, 0.36 }

local function fmt(n)
    n = math.floor((n or 0) + 0.5)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return (n < 0 and "-" or "") .. out
end
UI.FormatXP = fmt

local function dur(sec)
    sec = math.floor(sec or 0)
    if sec < 3600 then return string.format(T("%d min"), math.max(1, math.floor(sec / 60))) end
    return string.format("%d h %02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end
UI.XPDuration = dur

-- Valeurs affichées (vraies, ou exemple du mode édition)
local function data(sample)
    if sample then
        return { level = 23, cur = 4520, max = 12300, rested = 6150, resting = true, maxed = false }, 2300, 3
    end
    local list = M:Pending()
    local p = 0
    for _, e in ipairs(list) do p = p + e.xp end
    return M:Me(), p, #list
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperXPBar", UIParent)
    f:SetSize(W, 30)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f.track = f:CreateTexture(nil, "BACKGROUND")
    f.track:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.track:SetPoint("BOTTOMLEFT", 0, 0); f.track:SetPoint("BOTTOMRIGHT", 0, 0)
    f.track:SetHeight(BH)
    local function seg(layer, sub)
        local t = f:CreateTexture(nil, layer, nil, sub)
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetHeight(BH - 2)
        t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
        return t
    end
    f.rest = seg("ARTWORK", 0)
    f.pend = seg("ARTWORK", 1)
    f.cur = seg("ARTWORK", 2)
    f.mark = f:CreateTexture(nil, "OVERLAY")
    f.mark:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.mark:SetSize(2, BH + 6)
    f.ticks = {}
    for i = 1, 9 do
        local t = f:CreateTexture(nil, "OVERLAY", nil, -1)
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetSize(1, BH - 2)
        f.ticks[i] = t
    end
    f.left = UI:Text(f, 11)
    f.left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, BH + 4)
    f.right = UI:Text(f, 10, C.muted)
    f.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, BH + 5)
    f.right:SetJustifyH("RIGHT")
    f:Hide()

    function f:Paint(sample)
        local x, pend, nq = data(sample)
        local cfg = M:Config()
        local w = self:GetWidth() - 2
        local r1, g1, b1 = UI:Accent()
        self.track:SetVertexColor(0.04, 0.03, 0.02, 0.85)
        self.cur:SetVertexColor(r1, g1, b1, 1)
        self.rest:SetVertexColor(BLUE[1], BLUE[2], BLUE[3], 0.55)
        self.pend:SetVertexColor(YELLOW[1], YELLOW[2], YELLOW[3], 0.9)
        self.mark:SetVertexColor(YELLOW[1], YELLOW[2], YELLOW[3], 1)
        local function wid(v) return math.max(0.01, math.min(w, w * v / x.max)) end
        self.cur:SetWidth(wid(x.cur))
        self.rest:SetWidth(wid(x.cur + x.rested))
        self.rest:SetShown(x.rested > 0)
        self.pend:SetWidth(wid(x.cur + pend))
        self.pend:SetShown(pend > 0)
        self.mark:ClearAllPoints()
        self.mark:SetPoint("CENTER", self.track, "LEFT", 1 + wid(x.cur + pend), 0)
        self.mark:SetShown(pend > 0)
        for i, t in ipairs(self.ticks) do
            t:ClearAllPoints()
            t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 1 + w * i / 10, 1)
            t:SetColorTexture(0, 0, 0, 0.35)
        end
        local compact = cfg.compact
        self.left:SetShown(not compact); self.right:SetShown(not compact)
        self:SetHeight(compact and BH or 30)
        self.left:SetText(string.format(T("Niv. %d  ·  %s / %s  (%d %%)"), x.level, fmt(x.cur), fmt(x.max), math.floor(x.cur / x.max * 100)))
        local parts = {}
        if x.rested > 0 then table.insert(parts, string.format("|cff61a0f2" .. T("repos %d %%") .. "|r", math.floor(x.rested / x.max * 100))) end
        if pend > 0 then table.insert(parts, string.format("|cfff5cc5c" .. T("à rendre +%s (%d)") .. "|r", fmt(pend), nq)) end
        if x.cur + pend >= x.max then table.insert(parts, "|cff9ed17a" .. T("niveau en rendant tout") .. "|r") end
        self.right:SetText(table.concat(parts, "  ·  "))
    end

    f:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        local x, pend, nq = data(s.sample)
        GameTooltip:SetText(string.format(T("Niveau %d"), x.level), 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Expérience"), string.format("%s / %s (%d %%)", fmt(x.cur), fmt(x.max), math.floor(x.cur / x.max * 100)), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Manque"), fmt(x.max - x.cur), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Repos"), string.format("%s (%d %%)%s", fmt(x.rested), math.floor(x.rested / x.max * 100),
            x.resting and (" · " .. T("en auberge")) or ""), 0.8, 0.8, 0.8, BLUE[1], BLUE[2], BLUE[3])
        if pend > 0 then
            GameTooltip:AddDoubleLine(string.format(T("Quêtes à rendre (%d)"), nq), "+" .. fmt(pend), 0.8, 0.8, 0.8, YELLOW[1], YELLOW[2], YELLOW[3])
            local after = (x.cur + pend) / x.max * 100
            GameTooltip:AddDoubleLine(T("En rendant tout"), after >= 100 and T("niveau suivant") or string.format("%d %%", math.floor(after)),
                0.8, 0.8, 0.8, 0.62, 0.82, 0.48)
        end
        local perHour, secs, mobs = M:Rate()
        if s.sample then perHour, secs, mobs = 18400, 1640, 52 end
        if perHour then
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(T("Rythme"), string.format(T("%s / h"), fmt(perHour)), 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("Niveau suivant dans"), dur(secs), 0.8, 0.8, 0.8, 1, 1, 1)
            if mobs then GameTooltip:AddDoubleLine(T("Monstres restants"), string.format(T("env. %d"), mobs), 0.8, 0.8, 0.8, 1, 1, 1) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("Clic : section Expérience"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnMouseUp", function()
        UI:ToggleWindow("qol")
        if UI.pages.qol and UI.pages.qol.ShowSection then UI.pages.qol:ShowSection("xp") end
    end)

    UI:RegisterHUD("xpbar", f, {
        label = T("Barre d'expérience"), default = { 0, -300 },
        enabled = function() return M:Config().bar and WK:FeatureOn("xp") end,
        sample = function(on) f.sample = on or nil; if on then f:Paint(true); f:Show() else UI:RefreshXPBar() end end,
    })
    return f
end

function UI:RefreshXPBar()
    if not bar then bar = build() end
    if bar.sample then return end
    local on = M:Config().bar and WK:FeatureOn("xp") and not M:Me().maxed
    if not on then bar:Hide() return end
    bar:Paint()
    bar:Show()
end

M.OnChange = function() UI:RefreshXPBar() end
WK:On("PLAYER_LOGIN", function() C_Timer.After(1, function() UI:RefreshXPBar() end) end)
