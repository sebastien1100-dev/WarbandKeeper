local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Encart « feu de camp » (Modules/Camp.lua) : près d'un camp, propose de s'asseoir (bouton) ; assis, une
-- barre compte la minute ; ensuite, les avantages obtenus et leur durée (puis il s'efface) ; relevé trop
-- tôt : le rappel revient. Se place en mode édition.
local M = WK.modules.Camp
local card

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperCampCard", UIParent)
    f:SetSize(380, 64)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.icon = UI:RoundIcon(f, 40)
    f.icon:SetPoint("LEFT", 12, 0)
    f.title = UI:Text(f, 14)
    f.title:SetPoint("TOPLEFT", 62, -12)
    f.title:SetJustifyH("LEFT")
    f.sub = UI:Text(f, 12, C.text)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.sub:SetJustifyH("LEFT")
    if f.sub.SetWordWrap then f.sub:SetWordWrap(true) end
    if f.sub.SetMaxLines then f.sub:SetMaxLines(3) end
    -- décompte en grand à droite pendant la minute assise
    f.count = UI:Text(f, 24, C.text)
    f.count:SetPoint("RIGHT", -18, 2); f.count:SetJustifyH("RIGHT")
    f.sit = UI:Button(f, "S'asseoir", 84, 28, "primary")
    f.sit:SetPoint("RIGHT", -10, 0)
    f.sit:SetScript("OnClick", function() M:Sit() end)
    f.close = UI:IconButton(f, "close", 16, nil, "accent")
    f.close:SetPoint("TOPRIGHT", -4, -4)
    f.close:SetScript("OnClick", function() f.dismissed = M.state; f:Hide() end)
    f.track = f:CreateTexture(nil, "ARTWORK")
    f.track:SetHeight(5)
    f.track:SetPoint("BOTTOMLEFT", 12, 6); f.track:SetPoint("BOTTOMRIGHT", -12, 6)
    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetHeight(5)
    f.fill:SetPoint("BOTTOMLEFT", f.track, "BOTTOMLEFT")
    f:Hide()

    -- Remplit selon l'état ; sample : aperçu du mode édition
    function f:Paint(sample)
        local state = sample and "sitting" or M.state
        local a = M.auras or {}
        local r1, g1, b1 = UI:Accent()
        self.border:SetColor(r1, g1, b1, 0.6)
        self.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
        self.fill:SetColorTexture(r1, g1, b1, 1)
        local src = a.sit or a.flame or a.perk
        self.icon:SetTexture((src and src.icon) or "Interface\\Icons\\Spell_Fire_Fire")
        self.sit:Hide(); self.track:Hide(); self.fill:Hide(); self.count:SetText("")
        if state == "sit" or state == "early" then
            self.title:SetText(state == "early" and T("Relevé trop tôt") or T("Feu de camp à proximité"))
            local left = M.Remaining(a.perk)
            self.sub:SetText(left and string.format(T("Avantages : %s restants · assieds-toi 1 min pour les renouveler"), UI:AgoShort(left, true))
                or T("Assieds-toi (ou fabrique à côté) 1 min pour obtenir les avantages du camp."))
            self.sit:Show()
        elseif state == "sitting" then
            self.title:SetText(T("Reste assis…"))
            local left = sample and 42 or M.Remaining(a.sit) or 0
            local total = (a.sit and type(a.sit.duration) == "number" and a.sit.duration > 0) and a.sit.duration or 60
            self.sub:SetText(T("Les avantages du camp arrivent à la fin de la minute."))
            self.count:SetText(string.format("%d s", math.max(0, math.ceil(left))))
            self.track:Show(); self.fill:Show()
            self.fill:SetWidth(math.max(0.01, (self.track:GetWidth() or 0) * (1 - left / total)))
        elseif state == "done" then
            self.title:SetText(T("Avantages du camp"))
            local left = M.Remaining(a.perk)
            local txt = M:PerkText()
            self.sub:SetText((txt and (txt:gsub("\n", " · ") .. "  ·  ") or "") .. (left and string.format(T("%s restantes"), UI:AgoShort(left, true)) or ""))
        end
        -- place du texte : jusqu'au bouton ou au décompte s'ils sont là, sinon jusqu'à la croix
        local right = self.sit:IsShown() and 104 or ((self.count:GetText() or "") ~= "" and 84 or 30)
        local w = (self:GetWidth() or 380) - 62 - right
        self.title:SetWidth(w); self.sub:SetWidth(w)
        local h = 12 + (self.title:GetStringHeight() or 16) + 4 + (self.sub:GetStringHeight() or 14) + (self.track:IsShown() and 22 or 14)
        self:SetHeight(math.max(64, math.ceil(h)))
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 0.25 then return end
        s.acc = 0
        if s.sample then return end
        if M.state == "sitting" then s:Paint() end
        -- avantages obtenus : affichés 8 s puis l'encart s'efface
        local keep = M:Config().doneSecs or 8
        if M.state == "done" and s.doneAt and keep > 0 and GetTime() - s.doneAt > keep then s:Hide() end
    end)
    UI:RegisterHUD("camp", f, {
        label = T("Feu de camp"), default = { 0, -180 },
        enabled = function() return M:Config().enabled and WK:FeatureOn("campfire") end,
        -- fin de l'aperçu : l'état réel revient (pas seulement caché)
        -- fin de l'aperçu : état rafraîchi sans le jouer comme un changement (son et encart « avantages »
        -- rejoués deux fois avant, une fois par élément)
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint(true); f:Show() else f:Hide(); UI.CampReplay() end
        end,
        -- « Tester » : l'encart tel qu'au camp, avec son son d'alerte
        test = function()
            f.sample = true; f:Paint(true); f:Show()
            local ps, sk = _G.PlaySound, _G.SOUNDKIT
            if M:Config().sound and ps then pcall(ps, (sk and sk.UI_GARRISON_TOAST_INVASION_ALERT) or 8959, "Master") end
        end,
        testStop = function() f.sample = nil; f:Hide(); UI.CampReplay() end,
    })
    return f
end

---------------------------------------------------------------------------
-- Icône près d'un feu de camp : clic = s'asseoir ; assis, un cercle décompte la minute
---------------------------------------------------------------------------
local icon
local function buildIcon()
    local b = CreateFrame("Button", "WarbandKeeperCampIcon", UIParent)
    b:SetSize(52, 52)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:RegisterForClicks("LeftButtonUp")
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.glow:SetTexture(UI.MEDIA .. "circle")
    b.glow:SetPoint("CENTER"); b.glow:SetSize(70, 70)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(UI.MEDIA .. "circle")
    b.bg:SetAllPoints()
    b.ring = b:CreateTexture(nil, "BORDER")
    b.ring:SetTexture(UI.MEDIA .. "ring")
    b.ring:SetAllPoints()
    b.fire = b:CreateTexture(nil, "ARTWORK")
    b.fire:SetTexture(UI.MEDIA .. "fire")
    b.fire:SetPoint("CENTER", 0, 1); b.fire:SetSize(30, 30)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetPoint("TOPLEFT", 4, -4); b.cd:SetPoint("BOTTOMRIGHT", -4, 4)
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
    if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
    if b.cd.SetSwipeColor then b.cd:SetSwipeColor(0, 0, 0, 0.45) end
    -- chiffre posé sur un cadre au-dessus du voile qui tourne (avant, le voile le recouvrait : peu lisible)
    b.over = _G.CreateFrame("Frame", nil, b)
    b.over:SetAllPoints(); b.over:SetFrameLevel(b.cd:GetFrameLevel() + 2)
    b.num = b.over:CreateFontString(nil, "OVERLAY")
    b.num:SetFont(UI.FONT, 20, "THICKOUTLINE")
    b.num:SetPoint("CENTER", 0, 0)
    b.num:SetTextColor(1, 1, 1, 1)
    b.label = UI:Text(b, 10, C.text)
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -3)
    b:SetScript("OnClick", function() M:Sit() end)
    b:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        local st = M.state
        GameTooltip:SetText(T("Feu de camp"), 1, 1, 1)
        if st == "sitting" then GameTooltip:AddLine(T("Reste assis : les avantages du camp arrivent à la fin de la minute."), 0.8, 0.8, 0.8, true)
        elseif st == "done" then GameTooltip:AddLine(M:PerkText() or T("Avantages du camp obtenus."), 0.8, 0.8, 0.8, true)
        else GameTooltip:AddLine(T("Clic : s'asseoir 1 min près du feu pour obtenir les avantages du camp."), 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnUpdate", function(s, el)
        s.t = (s.t or 0) + el
        local r1, g1, b1 = UI:Accent()
        local st = s.sample and "sit" or M.state
        -- pulsation pour attirer l'oeil quand il faut s'asseoir
        local pulse = (st == "sit" or st == "early") and (0.35 + 0.3 * math.sin(s.t * 4)) or 0
        s.glow:SetVertexColor(r1, g1, b1, pulse)
        if st == "sitting" and not s.sample then
            local left = M.Remaining(M.auras and M.auras.sit) or 0
            s.num:SetText(left > 0 and tostring(math.ceil(left)) or "")
        else
            s.num:SetText("")
        end
        if st == "done" and s.doneAt and not s.sample then
            local keep = M:Config().doneSecs or 8
            if keep > 0 and GetTime() - s.doneAt > keep then s:Hide() end
        end
    end)
    function b:Paint(sample)
        local st = sample and "sit" or M.state
        local r1, g1, b1 = UI:Accent()
        self.bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 0.92)
        local col = (st == "done") and C.positive or (st == "early") and C.warning or { r1, g1, b1, 1 }
        self.ring:SetVertexColor(col[1], col[2], col[3], 1)
        self.fire:SetVertexColor(col[1], col[2], col[3], 1)
        self.fire:SetAlpha(st == "sitting" and 0.15 or 1)
        self.label:SetText(st == "sitting" and T("assis") or st == "done" and T("avantages") or st == "early" and T("rassieds-toi") or T("s'asseoir"))
        local a = M.auras or {}
        if st == "sitting" and a.sit and type(a.sit.expires) == "number" and not sample then
            local dur = (type(a.sit.duration) == "number" and a.sit.duration > 0) and a.sit.duration or 60
            self.cd:SetCooldown(a.sit.expires - dur, dur)
            self.cd:Show()
        else
            self.cd:Hide()
        end
    end
    b:Hide()
    UI:RegisterHUD("campIcon", b, {
        label = T("Icône du feu de camp"), default = { -220, -120 },
        enabled = function() return M:Config().icon and WK:FeatureOn("campfire") end,
        sample = function(on) b.sample = on or nil; if on then b:Paint(true); b:Show() else b:Hide(); UI.CampReplay() end end,
    })
    return b
end

local function updateIcon(changed)
    if not icon then icon = buildIcon() end
    if icon.sample then return end
    local st = M.state
    if not M:Config().icon or st == "none" then icon:Hide() return end
    if st == "done" and changed then icon.doneAt = GetTime() end
    if st == "done" and not changed and not icon:IsShown() then return end
    icon:Paint()
    icon:Show()
end

-- Changement d'état reçu pendant l'aperçu du mode édition : retenu et rejoué une fois à la sortie (son, encart
-- « avantages ») ; avant, il était perdu, ou rejoué deux fois (une fois par élément)
local campPending = false
function UI.CampReplay()
    local ch = campPending
    campPending = false
    M:OnChange(ch)
end
M.OnChange = function(_, changed)
    if not card then card = build() end
    if card.sample or (icon and icon.sample) then
        if changed then campPending = true end
        return
    end
    updateIcon(changed)
    local st = M.state
    if not M:Config().enabled then card:Hide() return end
    if st == "none" then card.dismissed = nil; card:Hide() return end
    if card.dismissed == st then return end
    if changed then card.dismissed = nil end
    if st == "done" and changed then card.doneAt = GetTime() end
    if changed and (st == "sit" or st == "early") and M:Config().sound and PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_GARRISON_TOAST_INVASION_ALERT) or 8959, "Master")
    end
    if st == "done" and not changed and not card:IsShown() then return end
    card:Paint()
    card:Show()
end

WK:On("PLAYER_LOGIN", function()
    if not card then card = build() end
    if not icon then icon = buildIcon() end
end)
