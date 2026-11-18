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
local ROWS = 12

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
    f.stepsHead = UI:Text(f, 10, C.dim); f.stepsHead:SetPoint("TOPLEFT", 14, -164); f.stepsHead:SetText(UI:Upper(T("Étapes")))
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 10, -178 - (i - 1) * 23); r:SetPoint("TOPRIGHT", -10, -178 - (i - 1) * 23)
        r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetTexture("Interface\\Buttons\\WHITE8X8"); r.bg:SetAllPoints()
        r.lv = UI:Text(r, 11); r.lv:SetPoint("LEFT", 4, 0); r.lv:SetWidth(26); r.lv:SetJustifyH("CENTER")
        r.icon = UI:RoundIcon(r, 18); r.icon:SetPoint("LEFT", 34, 0)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 58, 0); r.name:SetPoint("RIGHT", -20, 0)
        r.ok = UI:Text(r, 11, C.positive); r.ok:SetPoint("RIGHT", -4, 0)
        f.rows[i] = r
    end
    f.foot = UI:Text(f, 10, C.dim); f.foot:SetPoint("BOTTOMLEFT", 14, 10)

    function f:Paint()
        local key = WK:CharKey()
        local c = WK.DB.global.characters[key]
        local plan = P:Active(key)
        local r1, g1, b1 = UI:Accent()
        self.planBtn:SetLabel(plan and (plan.name .. "  ·  " .. T("changer")) or T("Aucun plan : crée-le dans la fiche (onglet Talents)"))
        local pr = P:Progress(key)
        local hasStep = pr and pr.step and pr.talent
        self.now:SetShown(plan ~= nil)
        if plan then
            if hasStep then
                self.nowLvl:SetText(string.format(T("Niveau %d · %d point(s) libre(s)"), P.FIRST_LEVEL + pr.next - 1, pr.free))
                self.nowIcon:SetTexture(pr.talent[2] or "Interface\\Icons\\INV_Misc_QuestionMark")
                self.nowName:SetText(string.format("%s |cff9ca3ab(%d/%d)|r", pr.talent[1], P:StepRank(plan, pr.next), pr.talent[6] or 1))
                self.place:Show(); self.place:SetEnabled(pr.free > 0)
            else
                self.nowLvl:SetText(T("Plan terminé"))
                self.nowIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                self.nowName:SetText(string.format(T("%d point(s) prévus, tous placés"), #plan.steps))
                self.place:Hide()
            end
        end
        -- étapes autour de l'étape en cours
        local cur = pr and pr.next or 1
        local first = math.max(1, cur - 2)
        for i, r in ipairs(self.rows) do
            local n = first + i - 1
            local st = plan and plan.steps[n]
            if st then
                local d = P:Talent(c, st)
                r.lv:SetText(P.FIRST_LEVEL + n - 1)
                r.icon:SetTexture(d and d[2] or "Interface\\Icons\\INV_Misc_QuestionMark")
                r.name:SetText(string.format("%s |cff9ca3ab%d/%d|r", d and d[1] or st[4] or "?", P:StepRank(plan, n), d and d[6] or 1))
                local done = n < cur
                r:SetAlpha(done and 0.45 or 1)
                r.ok:SetText(done and "•" or "")
                r.bg:SetVertexColor(r1, g1, b1, n == cur and 0.18 or 0)
                r:Show()
            else
                r:Hide()
            end
        end
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
    if anchorTo then panel:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 4, 0) else panel:SetPoint("CENTER", 300, 0) end
    panel.userHidden = nil
    panel:Paint()
    panel:Show()
end
function UI:ToggleTalentPlan()
    if panel and panel:IsShown() then panel:Hide() else UI:ShowTalentPlan(host and host:IsShown() and host or nil) end
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
