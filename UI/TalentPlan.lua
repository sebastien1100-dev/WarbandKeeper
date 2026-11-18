local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Panneau « Plan de montée » (Modules/TalentPlan.lua), collé à droite de la fenêtre des talents du jeu
-- (nom selon le client : PlayerSpellsFrame, ClassTalentFrame, PlayerTalentFrame, TalentFrame) ; s'ouvre et se ferme
-- avec elle. /wk plan l'ouvre seul (déplaçable). Le talent à prendre est entouré dans la fenêtre du jeu quand elle
-- expose ses boutons (GetTalentButtonByNodeID). Réglage : settings.ui.talentPlanPanel.
local P = WK.modules.TalentPlan
local panel, glow, host
local FRAMES = { "PlayerSpellsFrame", "ClassTalentFrame", "PlayerTalentFrame", "TalentFrame" }

local function enabled()
    local s = WK.DB.global.settings.ui
    if s.talentPlanPanel == nil then s.talentPlanPanel = true end
    return s.talentPlanPanel
end
UI.TalentPlanEnabled = enabled

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperTalentPlan", UIParent)
    f:SetSize(300, 470)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) if not s.anchored then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.96 }, { UI:Accent() })
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetText(T("Plan de montée"))
    f.by = UI:Text(f, 10, C.dim); f.by:SetPoint("LEFT", f.title, "RIGHT", 8, 0); f.by:SetText("Warband Keeper")
    f.close = UI:IconButton(f, "close", 16, nil, "accent"); f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close:SetScript("OnClick", function() f.userHidden = true; f:Hide() end)
    -- plan actif (clic : plan suivant)
    f.planBtn = UI:Button(f, "", 272, 26, "secondary"); f.planBtn:SetPoint("TOPLEFT", 14, -36)
    f.planBtn:SetScript("OnClick", function()
        local key = WK:CharKey()
        local list = P:Plans(key)
        if #list == 0 then return end
        local _, a = P:Active(key)
        P:SetActive(key, ((a or 0) % #list) + 1)
        f:Paint()
    end)
    -- étape en cours
    f.now = CreateFrame("Frame", nil, f)
    f.now:SetPoint("TOPLEFT", 14, -70); f.now:SetPoint("TOPRIGHT", -14, -70); f.now:SetHeight(84)
    UI:Panel(f.now, 9, C.surface, { UI:Accent() })
    f.nowLvl = UI:Text(f.now, 10, C.muted); f.nowLvl:SetPoint("TOPLEFT", 10, -8)
    f.nowIcon = UI:RoundIcon(f.now, 26); f.nowIcon:SetPoint("TOPLEFT", 10, -24)
    f.nowName = UI:Text(f.now, 13); f.nowName:SetPoint("TOPLEFT", 44, -28); f.nowName:SetPoint("RIGHT", -8, 0)
    f.place = UI:Button(f.now, "Placer ce point", nil, 22, "primary"); f.place:SetPoint("BOTTOMLEFT", 10, 6)
    f.place:SetScript("OnClick", function()
        local ok, why = P:PlaceNext()
        if not ok then WK:Print(why or "") end
    end)
    f.stepsHead = UI:Text(f, 10, C.dim); f.stepsHead:SetText(UI:Upper(T("Étapes")))
    -- toutes les étapes du plan, dans une liste qui défile ; celles déjà apprises sont grisées
    f.list = UI:Scroll(f)
    f.list:SetPoint("BOTTOMRIGHT", -6, 28)
    f.rows = {}
    function f:Row(i)
        local r = self.rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, self.list.child)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 4, -(i - 1) * 23); r:SetPoint("TOPRIGHT", -4, -(i - 1) * 23)
        r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetTexture("Interface\\Buttons\\WHITE8X8"); r.bg:SetAllPoints()
        r.lv = UI:Text(r, 11); r.lv:SetPoint("LEFT", 2, 0); r.lv:SetWidth(26); r.lv:SetJustifyH("CENTER")
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 32, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 56, 0); r.name:SetPoint("RIGHT", -48, 0)
        r.ok = UI:Text(r, 11, C.positive); r.ok:SetPoint("RIGHT", -2, 0)
        self.rows[i] = r
        return r
    end
    f.foot = UI:Text(f, 10, C.dim); f.foot:SetPoint("BOTTOMLEFT", 14, 10)

    function f:Paint()
        local key = WK:CharKey()
        local c = WK.DB.global.characters[key]
        local plan = P:Active(key)
        local r1, g1, b1 = UI:Accent()
        -- aucun plan : un texte sur plusieurs lignes au lieu du bouton (le libellé débordait)
        if not self.empty then
            self.empty = UI:Text(self, 12, C.muted)
            self.empty:SetPoint("TOPLEFT", 14, -40); self.empty:SetPoint("RIGHT", -14, 0)
            self.empty:SetJustifyH("LEFT")
            if self.empty.SetWordWrap then self.empty:SetWordWrap(true) end
            self.empty:SetText(T("Aucun plan de montée pour ce perso. Crée-le dans la fiche du perso, onglet Talents, carte « Plans de montée »."))
        end
        self.empty:SetShown(plan == nil)
        self.planBtn:SetShown(plan ~= nil)
        self.stepsHead:SetShown(plan ~= nil)
        local label = plan and (plan.name .. "  ·  " .. T("changer")) or ""
        self.planBtn:SetLabel(label)
        -- nom de plan trop long : coupé dans le bouton
        self.planBtn.label:SetWidth(self.planBtn:GetWidth() - 20)
        if self.planBtn.label.SetWordWrap then self.planBtn.label:SetWordWrap(false) end
        local pr = P:Progress(key)
        local hasStep = pr and pr.step and pr.talent
        -- encart de l'étape en cours, seulement s'il reste un point à prendre
        self.now:SetShown(hasStep and true or false)
        if hasStep then
            self.nowLvl:SetText(string.format(T("Niveau %d · %d point(s) libre(s)"), P.FIRST_LEVEL + pr.next - 1, pr.free))
            self.nowIcon:SetTexture(pr.talent[2] or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.nowName:SetText(string.format("%s |cff9ca3ab(%d/%d)|r", pr.talent[1], P:StepRank(plan, pr.next), pr.talent[6] or 1))
            self.place:SetEnabled(pr.free > 0)
        end
        local listTop = hasStep and -162 or -70
        self.stepsHead:ClearAllPoints(); self.stepsHead:SetPoint("TOPLEFT", 14, listTop)
        self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", 6, listTop - 14); self.list:SetPoint("BOTTOMRIGHT", -6, 28)
        -- toutes les étapes : grisées quand le talent a déjà ce rang
        local cur = pr and pr.next or 1
        local n = plan and #plan.steps or 0
        for i = 1, math.max(n, #self.rows) do
            local r = self:Row(i)
            local st = plan and plan.steps[i]
            if st then
                local d = P:Talent(c, st)
                local want = P:StepRank(plan, i)
                local learned = d and (d[5] or 0) >= want
                r.lv:SetText(P.FIRST_LEVEL + i - 1)
                r.icon:SetTexture(d and d[2] or "Interface\\Icons\\INV_Misc_QuestionMark")
                if r.icon.SetDesaturated then r.icon:SetDesaturated(learned) end
                r.name:SetText(string.format("%s |cff9ca3ab%d/%d|r", d and d[1] or st[4] or "?", want, d and d[6] or 1))
                r:SetAlpha(learned and 0.4 or 1)
                r.ok:SetText(learned and T("appris") or "")
                r.bg:SetVertexColor(r1, g1, b1, (not learned and i == cur) and 0.18 or 0)
                r:Show()
            else
                r:Hide()
            end
        end
        self.list.child:SetWidth(math.max(200, (self.list:GetWidth() or 288) - 14))
        self.list:SetContentHeight(n * 23 + 4)
        -- l'étape en cours reste visible
        if self.list.SetVerticalScroll and cur > 4 then pcall(self.list.SetVerticalScroll, self.list, (cur - 3) * 23) end
        self.foot:SetText(plan and string.format(T("%d / %d points du plan"), pr and pr.spent or 0, #plan.steps) or "")
        UI:TalentPlanGlow()
    end
    f:Hide()
    return f
end

-- Talent à prendre entouré dans la fenêtre du jeu (si elle expose ses boutons)
function UI:TalentPlanGlow()
    if glow then glow:Hide() end
    if not (host and host:IsShown() and panel and panel:IsShown()) then return end
    local pr = P:Progress(WK:CharKey())
    local node = pr and pr.step and (pr.step[3] or (pr.talent and pr.talent[8]))
    if not node then return end
    local btn
    for _, sub in ipairs({ host.TalentsFrame or false, host.TalentsTab or false, host }) do
        if sub and sub.GetTalentButtonByNodeID then
            local ok, b = pcall(sub.GetTalentButtonByNodeID, sub, node)
            if ok and b then btn = b break end
        end
    end
    if not btn then return end
    if not glow then
        glow = CreateFrame("Frame", nil, UIParent)
        glow:SetFrameStrata("DIALOG")
        glow.tex = glow:CreateTexture(nil, "OVERLAY")
        glow.tex:SetTexture(UI.MEDIA .. "ring")
        glow.tex:SetAllPoints()
        glow:SetScript("OnUpdate", function(s, el)
            s.t = (s.t or 0) + el
            local r, g, b = UI:Accent()
            s.tex:SetVertexColor(r, g, b, 0.6 + 0.4 * math.sin(s.t * 5))
        end)
    end
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -6, 6); glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 6, -6)
    glow:Show()
end

function UI:ShowTalentPlan(anchorTo)
    if not panel then panel = build() end
    panel:ClearAllPoints()
    panel.anchored = anchorTo ~= nil
    -- au-dessus de la fenêtre de l'addon (même strate « HIGH ») : collé à sa droite, sinon au centre
    panel:SetFrameStrata("DIALOG")
    panel:Raise()
    local main = UI.frame
    if anchorTo then panel:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 4, 0)
    elseif main and main:IsShown() then panel:SetPoint("TOPLEFT", main, "TOPRIGHT", 6, 0)
    else panel:SetPoint("CENTER", 0, 0) end
    panel.userHidden = nil
    panel:Paint()
    panel:Show()
end
function UI:ToggleTalentPlan()
    if panel and panel:IsShown() then panel:Hide() else UI:ShowTalentPlan(host and host:IsShown() and host or nil) end
end
-- Un plan supprimé : on ferme le panneau et la fenêtre des talents du jeu à laquelle il est collé (hors combat)
function UI:CloseTalentPlan()
    if panel and panel:IsShown() then panel:Hide() end
    if glow then glow:Hide() end
    if host and host:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
        if HideUIPanel then pcall(HideUIPanel, host) else pcall(host.Hide, host) end
    end
end
function UI:RefreshTalentPlan() if panel and panel:IsShown() then panel:Paint() end end

-- Accroche à la fenêtre des talents du jeu (chargée à la demande)
local function tryHook()
    for _, name in ipairs(FRAMES) do
        local fr = _G[name]
        if fr and fr.HookScript and not fr.wkPlanHooked then
            fr.wkPlanHooked = true
            fr:HookScript("OnShow", function(s)
                host = s
                if enabled() and #P:Plans(WK:CharKey()) > 0 then UI:ShowTalentPlan(s) end
            end)
            fr:HookScript("OnHide", function(s)
                if panel and panel.anchored then panel:Hide() end
                if glow then glow:Hide() end
            end)
            if fr:IsShown() then host = fr end
        end
    end
end
UI.TalentPlanHook = tryHook
WK:On("ADDON_LOADED", function() tryHook() end)
WK:On("PLAYER_LOGIN", function() tryHook() end)
WK:On("TRAIT_CONFIG_UPDATED", function() C_Timer.After(0.5, function() UI:RefreshTalentPlan() end) end)
WK:On("PLAYER_LEVEL_UP", function() C_Timer.After(3, function() UI:RefreshTalentPlan() end) end)
