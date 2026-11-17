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
    f:SetSize(320, 64)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.icon = UI:RoundIcon(f, 36)
    f.icon:SetPoint("LEFT", 12, 0)
    f.title = UI:Text(f, 13)
    f.title:SetPoint("TOPLEFT", 58, -12)
    f.title:SetPoint("RIGHT", -96, 0)
    f.title:SetJustifyH("LEFT")
    f.sub = UI:Text(f, 11, C.muted)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("RIGHT", -96, 0)
    f.sub:SetJustifyH("LEFT")
    f.sit = UI:Button(f, "S'asseoir", 84, 28, "primary")
    f.sit:SetPoint("RIGHT", -10, 0)
    f.sit:SetScript("OnClick", function() M:Sit() end)
    f.close = UI:IconButton(f, "close", 16, nil, "accent")
    f.close:SetPoint("TOPRIGHT", -4, -4)
    f.close:SetScript("OnClick", function() f.dismissed = M.state; f:Hide() end)
    f.track = f:CreateTexture(nil, "ARTWORK")
    f.track:SetHeight(3)
    f.track:SetPoint("BOTTOMLEFT", 12, 2); f.track:SetPoint("BOTTOMRIGHT", -12, 2)
    f.fill = f:CreateTexture(nil, "OVERLAY")
    f.fill:SetHeight(3)
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
        self.sit:Hide(); self.track:Hide(); self.fill:Hide()
        if state == "sit" or state == "early" then
            self.title:SetText(state == "early" and T("Relevé trop tôt") or T("Feu de camp à proximité"))
            local left = M.Remaining(a.perk)
            self.sub:SetText(left and string.format(T("Avantages : %s restants · assieds-toi 1 min pour les renouveler"), UI:AgoShort(left, true))
                or T("Assieds-toi 1 min pour obtenir les avantages du camp (2 h)."))
            self.sit:Show()
        elseif state == "sitting" then
            self.title:SetText(T("Reste assis…"))
            local left = sample and 42 or M.Remaining(a.sit) or 0
            local total = (a.sit and type(a.sit.duration) == "number" and a.sit.duration > 0) and a.sit.duration or 60
            self.sub:SetText(string.format(T("Avantages du camp dans %d s"), math.max(0, math.ceil(left))))
            self.track:Show(); self.fill:Show()
            self.fill:SetWidth(math.max(0.01, (self.track:GetWidth() or 0) * (1 - left / total)))
        elseif state == "done" then
            self.title:SetText(T("Avantages du camp"))
            local left = M.Remaining(a.perk)
            local txt = M:PerkText()
            self.sub:SetText((txt and (txt:gsub("\n", " · ") .. "  ·  ") or "") .. (left and string.format(T("%s restantes"), UI:AgoShort(left, true)) or ""))
        end
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
        enabled = function() return M:Config().enabled end,
        sample = function(on) f.sample = on or nil; if on then f:Paint(true); f:Show() else f:Hide() end end,
    })
    return f
end

M.OnChange = function(_, changed)
    if not card then card = build() end
    if card.sample then return end
    local st = M.state
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

WK:On("PLAYER_LOGIN", function() if not card then card = build() end end)
