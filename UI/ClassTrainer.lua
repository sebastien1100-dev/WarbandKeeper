local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Panneau « À apprendre ici » collé à la fenêtre du maître de classe (même strate et niveau qu'elle) :
-- sorts disponibles avec leur prix, « Tout apprendre » (les moins chers d'abord, sans dépasser l'or),
-- clic = apprendre ce sort, clic droit = l'écarter / le remettre. Données : Modules/ClassSpells.lua.
-- Réglage ClassSpells:Config().panel (onglet « Sorts » de la fiche du perso).
local W, ROW, MAXROWS = 300, 26, 16
local panel

local function CS() return WK.modules.ClassSpells end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperClassTrainer", UIParent)
    f:SetWidth(W)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.96 }, C.border)
    f.title = UI:Text(f, 13, C.text); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetText(T("À apprendre ici"))
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3); f.sub:SetPoint("RIGHT", -14, 0)
    f.sub:SetJustifyH("LEFT")
    f.rows = {}
    for i = 1, MAXROWS do
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(ROW)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.05); b.hl:Hide()
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 2, 0)
        b.name = UI:Text(b, 11, C.text); b.name:SetPoint("LEFT", 28, 0); b.name:SetPoint("RIGHT", -70, 0); b.name:SetJustifyH("LEFT")
        if b.name.SetWordWrap then b.name:SetWordWrap(false) end
        b.cost = UI:Text(b, 11, C.gold); b.cost:SetPoint("RIGHT", -4, 0); b.cost:SetJustifyH("RIGHT")
        b:SetScript("OnEnter", function(s)
            s.hl:Show()
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.e and (s.e.name .. (s.e.rank ~= "" and (" (" .. s.e.rank .. ")") or "")) or "", 1, 1, 1)
            GameTooltip:AddLine(s.e and s.e.skipped and T("Écarté · clic droit : le remettre") or T("Clic : apprendre · clic droit : écarter"), C.muted[1], C.muted[2], C.muted[3])
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide() end)
        b:SetScript("OnClick", function(s, btn)
            if not s.e then return end
            if btn == "RightButton" then CS():Skip(nil, s.e.name, not s.e.skipped)
            elseif not s.e.skipped then
                -- un seul achat par ligne jusqu'au rafraîchissement (TRAINER_UPDATE refait les lignes)
                if s.bought == s.e then return end
                if CS():LearnOne(s.e.index, s.e.name, s.e.rank) then s.bought = s.e end
            end
        end)
        b:Hide()
        f.rows[i] = b
    end
    f.all = UI:Button(f, T("Tout apprendre"), nil, 26, "primary")
    f.all:SetScript("OnClick", function()
        local n, spent = CS():LearnAll()
        if n > 0 then WK:Print(string.format(T("%d sort(s) appris pour %s."), n, CS():Money(spent))) end
    end)
    f.note = UI:Text(f, 10, C.muted); f.note:SetJustifyH("LEFT"); if f.note.SetWordWrap then f.note:SetWordWrap(true) end
    f.note:SetText(T("Prix relevés ici : retenus pour tes autres persos de la même classe."))
    return f
end

function UI:RefreshClassTrainer()
    local cs = CS()
    local tf = ClassTrainerFrame
    -- maître de classe seulement (pas un maître de métier, d'armes, de familiers ou de monte)
    local isClass = cs.IsClassTrainer and cs.IsClassTrainer()
    if not (tf and tf:IsShown()) or not isClass or not WK:FeatureOn("classes") or not cs:Config().panel then
        if panel then panel:Hide() end
        return
    end
    if not panel then panel = build() end
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", tf, "TOPRIGHT", 6, 0)
    UI:MatchHost(panel, tf)
    local list = cs:TrainerAvailable()
    table.sort(list, function(a, b) if a.skipped ~= b.skipped then return not a.skipped end return a.cost < b.cost end)
    local total, n = 0, 0
    for _, e in ipairs(list) do if not e.skipped then total = total + e.cost; n = n + 1 end end
    panel.sub:SetText(string.format(T("%d sort(s) · %s · tu as %s"), n, cs:Money(total), cs:Money(GetMoney and GetMoney() or 0)))
    local y = -44
    for i, b in ipairs(panel.rows) do
        local e = list[i]
        if e then
            b.e = e
            local icon
            if GetTrainerServiceIcon then icon = GetTrainerServiceIcon(e.index) end
            b.icon:SetTexture(icon or 134400)
            b.icon:SetDesaturated(e.skipped and true or false)
            b.name:SetText(e.name .. (e.rank ~= "" and (" " .. UI:Hex(C.muted) .. e.rank .. "|r") or ""))
            b.name:SetTextColor(unpack(e.skipped and C.dim or C.text))
            b.cost:SetText(e.skipped and T("écarté") or cs:Money(e.cost))
            b.cost:SetTextColor(unpack(e.skipped and C.dim or C.gold))
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 10, y); b:SetPoint("RIGHT", -10, 0)
            b:Show()
            y = y - ROW
        else
            b:Hide()
        end
    end
    if #list == 0 then
        panel.sub:SetText(T("Rien à apprendre ici pour l'instant."))
    end
    panel.all:SetLabel(n > 0 and string.format(T("Tout apprendre (%s)"), cs:Money(total)) or T("Tout apprendre"))
    panel.all:SetWidth(panel.all.label:GetStringWidth() + 32)
    panel.all:SetEnabled(n > 0)
    panel.all:ClearAllPoints(); panel.all:SetPoint("TOPLEFT", 14, y - 8)
    panel.note:ClearAllPoints(); panel.note:SetPoint("TOPLEFT", 14, y - 42); panel.note:SetPoint("RIGHT", -14, 0)
    panel:SetHeight(-y + 42 + (panel.note:GetStringHeight() or 12) + 14)
    panel:Show()
end

WK:On("TRAINER_SHOW", function() C_Timer.After(0.15, function() UI:RefreshClassTrainer() end) end)
WK:On("TRAINER_UPDATE", function() if panel and panel:IsShown() then UI:RefreshClassTrainer() end end)
WK:On("TRAINER_CLOSED", function() if panel then panel:Hide() end end)
