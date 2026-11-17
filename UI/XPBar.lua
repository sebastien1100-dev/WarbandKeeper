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
    -- style du micro menu : cadre sombre arrondi au liseré fin, textes dans le cadre, piste arrondie
    local f = CreateFrame("Frame", "WarbandKeeperXPBar", UIParent)
    f:SetSize(W, 40)
    f:SetFrameStrata("LOW")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:Panel(f, 10, { 0.06, 0.063, 0.075, 0.92 }, C.border)
    f.trackF = CreateFrame("Frame", nil, f)
    UI:Panel(f.trackF, 5, { 0.09, 0.094, 0.106, 1 }, C.border)
    local function seg(layer, sub)
        local t = f.trackF:CreateTexture(nil, layer, nil, sub)
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetPoint("TOPLEFT", f.trackF, "TOPLEFT", 1, -1)
        t:SetPoint("BOTTOMLEFT", f.trackF, "BOTTOMLEFT", 1, 1)
        return t
    end
    f.pend = seg("ARTWORK", 0)
    f.rest = seg("ARTWORK", 1)
    f.cur = seg("ARTWORK", 2)
    -- reflet clair en haut de l'XP (relief)
    f.shine = f.trackF:CreateTexture(nil, "ARTWORK", nil, 3)
    f.shine:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.shine:SetPoint("TOPLEFT", f.cur, "TOPLEFT"); f.shine:SetPoint("TOPRIGHT", f.cur, "TOPRIGHT")
    f.shine:SetHeight(1)
    f.mark = f.trackF:CreateTexture(nil, "OVERLAY")
    f.mark:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.glow = f.trackF:CreateTexture(nil, "OVERLAY", nil, -1)
    f.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.ticks = {}
    for i = 1, 9 do
        local t = f.trackF:CreateTexture(nil, "OVERLAY", nil, -2)
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        f.ticks[i] = t
    end
    f.left = UI:Text(f, 11)
    f.right = UI:Text(f, 11, C.muted)
    f.right:SetJustifyH("RIGHT")
    f:Hide()

    function f:Paint(sample)
        local x, pend, nq = data(sample)
        local cfg = M:Config()
        -- largeur et épaisseur réglables (QoL > Expérience)
        local bh = math.max(4, math.min(24, cfg.thick or BH))
        local compact = cfg.compact
        self:SetWidth(math.max(200, cfg.width or W))
        self:SetHeight(compact and (bh + 14) or (bh + 32))
        self.trackF:ClearAllPoints()
        self.trackF:SetPoint("BOTTOMLEFT", 10, 7); self.trackF:SetPoint("BOTTOMRIGHT", -10, 7)
        self.trackF:SetHeight(bh)
        self.left:ClearAllPoints(); self.left:SetPoint("TOPLEFT", 10, -7)
        self.right:ClearAllPoints(); self.right:SetPoint("TOPRIGHT", -10, -7)
        self.left:SetShown(not compact); self.right:SetShown(not compact)
        local w = self:GetWidth() - 22
        local r1, g1, b1 = UI:Accent()
        self.cur:SetVertexColor(r1, g1, b1, 1)
        self.shine:SetVertexColor(1, 1, 1, 0.25)
        self.rest:SetVertexColor(BLUE[1], BLUE[2], BLUE[3], 0.55)
        self.pend:SetVertexColor(YELLOW[1], YELLOW[2], YELLOW[3], 0.75)
        self.mark:SetVertexColor(YELLOW[1], YELLOW[2], YELLOW[3], 1)
        self.glow:SetVertexColor(YELLOW[1], YELLOW[2], YELLOW[3], 0.35)
        local function wid(v) return math.max(0.01, math.min(w, w * v / x.max)) end
        self.cur:SetWidth(wid(x.cur))
        self.rest:SetWidth(wid(x.cur + x.rested))
        self.rest:SetShown(x.rested > 0)
        self.pend:SetWidth(wid(x.cur + pend))
        self.pend:SetShown(pend > 0)
        local mx = 1 + wid(x.cur + pend)
        self.mark:ClearAllPoints(); self.mark:SetSize(2, bh + 6)
        self.mark:SetPoint("CENTER", self.trackF, "LEFT", mx, 0)
        self.glow:ClearAllPoints(); self.glow:SetSize(6, bh + 6)
        self.glow:SetPoint("CENTER", self.trackF, "LEFT", mx, 0)
        self.mark:SetShown(pend > 0); self.glow:SetShown(pend > 0)
        for i, t in ipairs(self.ticks) do
            t:ClearAllPoints()
            t:SetSize(1, math.max(1, bh - 2))
            t:SetPoint("LEFT", self.trackF, "LEFT", 1 + w * i / 10, 0)
            t:SetColorTexture(0, 0, 0, 0.35)
        end
        local hex = string.format("|cff%02x%02x%02x", r1 * 255, g1 * 255, b1 * 255)
        self.left:SetText(string.format(hex .. T("Niv. %d") .. "|r  |cff9ca3ab·|r  %s / %s  |cff9ca3ab(%d %%)|r", x.level, fmt(x.cur), fmt(x.max), math.floor(x.cur / x.max * 100)))
        local parts = {}
        if x.rested > 0 then table.insert(parts, string.format("|cff7fb6f2" .. T("repos %d %%") .. "|r", math.floor(x.rested / x.max * 100))) end
        if pend > 0 then table.insert(parts, string.format("|cfff5d76e" .. T("à rendre +%s (%d)") .. "|r", fmt(pend), nq)) end
        if x.cur + pend >= x.max then table.insert(parts, "|cff9ed17a" .. T("niveau en rendant tout") .. "|r") end
        self.right:SetText(table.concat(parts, "  |cff9ca3ab·|r  "))
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
