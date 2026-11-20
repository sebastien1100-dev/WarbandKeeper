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
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border) -- fond sombre du thème
    f.trackF = CreateFrame("Frame", nil, f)
    UI:Panel(f.trackF, 5, { (C.bg[1] + C.surface[1]) / 2, (C.bg[2] + C.surface[2]) / 2, (C.bg[3] + C.surface[3]) / 2, 1 }, C.border)
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
        -- texte au-dessus (défaut) ou en dessous de la barre (réglage textPos)
        local below = cfg.textPos == "below" and not compact
        if below then
            self.trackF:SetPoint("TOPLEFT", 10, -7); self.trackF:SetPoint("TOPRIGHT", -10, -7)
        else
            self.trackF:SetPoint("BOTTOMLEFT", 10, 7); self.trackF:SetPoint("BOTTOMRIGHT", -10, 7)
        end
        self.trackF:SetHeight(bh)
        self.left:ClearAllPoints(); self.right:ClearAllPoints()
        if below then
            self.left:SetPoint("BOTTOMLEFT", 10, 7); self.right:SetPoint("BOTTOMRIGHT", -10, 7)
        else
            self.left:SetPoint("TOPLEFT", 10, -7); self.right:SetPoint("TOPRIGHT", -10, -7)
        end
        -- texte au survol (réglage) : libellés cachés tant que la souris n'est pas sur la barre (place gardée)
        local showText = not compact and (not cfg.textHover or self.hovered or self.sample) and true or false
        self.left:SetShown(showText); self.right:SetShown(showText)
        -- sans fond (réglage) : cadre et liseré transparents, textes ombrés pour rester lisibles ; la piste reste
        local bare = cfg.noBg and true or false
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], bare and 0 or 0.92)
        self.border:SetColor(C.border[1], C.border[2], C.border[3], bare and 0 or (C.border[4] or 1))
        -- sans fond : police contourée un peu plus grande, ombre portée et gris éclaircis (lisible sur un décor clair)
        for _, t in ipairs({ self.left, self.right }) do
            t:SetFont(UI.FONT, bare and 12 or 11, bare and "OUTLINE" or "")
            t:SetShadowColor(0, 0, 0, bare and 0.9 or 0)
            t:SetShadowOffset(bare and 1 or 0, bare and -1 or 0)
        end
        self.bare = bare
        local w = self:GetWidth() - 22
        local r1, g1, b1 = UI:Accent()
        self.cur:SetVertexColor(r1, g1, b1, 1)
        self.shine:SetVertexColor(1, 1, 1, 0.25)
        self.rest:SetVertexColor(C.info[1], C.info[2], C.info[3], 1)
        self.pend:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.75)
        self.mark:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
        self.glow:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.35)
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
        local hex, mu = UI:Hex({ r1, g1, b1 }), UI:Hex(bare and C.text or C.muted)
        self.right:SetTextColor(unpack(bare and C.text or C.muted))
        self.left:SetText(string.format(hex .. T("Niv. %d") .. "|r  " .. mu .. "·|r  %s / %s  " .. mu .. "(%d %%)|r", x.level, fmt(x.cur), fmt(x.max), math.floor(x.cur / x.max * 100)))
        local parts = {}
        if x.rested > 0 then table.insert(parts, string.format(UI:Hex(C.info) .. T("repos %d %%") .. "|r", math.floor(x.rested / x.max * 100))) end
        if pend > 0 then table.insert(parts, string.format(UI:Hex(C.gold) .. T("à rendre +%s (%d)") .. "|r", fmt(pend), nq)) end
        if x.cur + pend >= x.max then table.insert(parts, UI:Hex(C.positive) .. T("niveau en rendant tout") .. "|r") end
        self.right:SetText(table.concat(parts, "  " .. mu .. "·|r  "))
    end

    f:SetScript("OnEnter", function(s)
        s.hovered = true
        if M:Config().textHover then s.left:SetShown(not M:Config().compact); s.right:SetShown(not M:Config().compact) end
        UI:TooltipOwner(s, "ANCHOR_TOP")
        local x, pend, nq = data(s.sample)
        GameTooltip:SetText(string.format(T("Niveau %d"), x.level), 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Expérience"), string.format("%s / %s (%d %%)", fmt(x.cur), fmt(x.max), math.floor(x.cur / x.max * 100)), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Manque"), fmt(x.max - x.cur), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("Repos"), string.format("%s (%d %%)%s", fmt(x.rested), math.floor(x.rested / x.max * 100),
            x.resting and (" · " .. T("en auberge")) or ""), 0.8, 0.8, 0.8, C.info[1], C.info[2], C.info[3])
        if pend > 0 then
            GameTooltip:AddDoubleLine(string.format(T("Quêtes à rendre (%d)"), nq), "+" .. fmt(pend), 0.8, 0.8, 0.8, C.gold[1], C.gold[2], C.gold[3])
            local after = (x.cur + pend) / x.max * 100
            GameTooltip:AddDoubleLine(T("En rendant tout"), after >= 100 and T("niveau suivant") or string.format("%d %%", math.floor(after)),
                0.8, 0.8, 0.8, C.positive[1], C.positive[2], C.positive[3])
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
    f:SetScript("OnLeave", function(s)
        GameTooltip:Hide()
        s.hovered = nil
        if M:Config().textHover and not s.sample then s.left:Hide(); s.right:Hide() end
    end)
    f:SetScript("OnMouseUp", function()
        -- ouvrir (jamais refermer : la fenêtre ouverte sur une autre section de QoL se fermait)
        UI:Create():Show(); UI:ShowPage("qol")
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
