local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Panneau « À apprendre ici » collé à la fenêtre du maître de classe (même strate et niveau qu'elle) :
-- une coche par sort (cochée = à apprendre, décochée = écarté, retenu pour ce perso), les sorts disponibles
-- puis, en grisé, ceux des niveaux suivants (cochables d'avance) ; « Apprendre la sélection » (les moins
-- chers d'abord, sans dépasser l'or) ; clic sur le nom d'un sort disponible = l'apprendre seul.
-- Données : Modules/ClassSpells.lua. Réglage ClassSpells:Config().panel (QoL > Classes > Général).
local W, ROW, MAXROWS = 320, 26, 18
local panel

local function CS() return WK.modules.ClassSpells end

local function build()
    local f = _G.CreateFrame("Frame", "WarbandKeeperClassTrainer", _G.UIParent)
    f:SetWidth(W)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.96 }, C.border)
    f.title = UI:Text(f, 13, C.text); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetText(T("À apprendre ici"))
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3); f.sub:SetPoint("RIGHT", -14, 0)
    f.sub:SetJustifyH("LEFT")
    f.later = UI:Text(f, 9, C.dim); f.later:SetText(UI:Upper(T("Niveaux suivants")))
    f.rows = {}
    for i = 1, MAXROWS do
        local b = _G.CreateFrame("Button", nil, f)
        b:SetHeight(ROW)
        b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.05); b.hl:Hide()
        -- coche : à apprendre (oui) ou écarté (non)
        b.check = UI:Toggle(b, function() return b.e and not b.e.skipped end, function(v)
            if b.e then CS():Skip(nil, b.e.name, not v, b.e.rank) end
            UI:RefreshClassTrainer()
        end)
        b.check:SetScale(0.7); b.check:SetPoint("LEFT", 2 / 0.7, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 34, 0)
        b.name = UI:Text(b, 11, C.text); b.name:SetPoint("LEFT", 60, 0); b.name:SetPoint("RIGHT", -70, 0)
        b.name:SetJustifyH("LEFT")
        if b.name.SetWordWrap then b.name:SetWordWrap(false) end
        b.cost = UI:Text(b, 11, C.gold); b.cost:SetPoint("RIGHT", -4, 0); b.cost:SetJustifyH("RIGHT")
        b:SetScript("OnEnter", function(s)
            s.hl:Show()
            local GT = _G.GameTooltip
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GT:SetText(s.e and (s.e.name .. (s.e.rank ~= "" and (" (" .. s.e.rank .. ")") or "")) or "", 1, 1, 1)
            local tip
            if s.e and s.e.later then
                tip = string.format(T("Niveau %s · coche : l'apprendre le moment venu"), s.e.level or "?")
            else
                tip = T("Clic : apprendre ce sort · coche : dans la sélection ou écarté")
            end
            GT:AddLine(tip, C.muted[1], C.muted[2], C.muted[3], true)
            GT:Show()
        end)
        b:SetScript("OnLeave", function(s) s.hl:Hide(); _G.GameTooltip:Hide() end)
        b:SetScript("OnClick", function(s)
            if not s.e or s.e.later then return end
            -- un seul achat par ligne jusqu'au rafraîchissement (TRAINER_UPDATE refait les lignes)
            if s.bought == s.e then return end
            if CS():LearnOne(s.e.index, s.e.name, s.e.rank) then s.bought = s.e end
        end)
        b:Hide()
        f.rows[i] = b
    end
    f.all = UI:Button(f, T("Apprendre la sélection"), nil, 26, "primary")
    f.all:SetScript("OnClick", function()
        local n, spent = CS():LearnAll()
        if n > 0 then WK:Print(string.format(T("%d sort(s) appris pour %s."), n, CS():Money(spent))) end
    end)
    f.note = UI:Text(f, 10, C.muted); f.note:SetJustifyH("LEFT"); if f.note.SetWordWrap then f.note:SetWordWrap(true) end
    f.note:SetText(T("Décoché : écarté pour ce perso (gardé). Prix relevés ici : retenus pour tes autres persos"
        .. " de la même classe."))
    return f
end

function UI:RefreshClassTrainer()
    local cs = CS()
    local tf = _G.ClassTrainerFrame
    -- maître de classe seulement (pas un maître de métier, d'armes, de familiers ou de monte)
    local isClass = cs.IsClassTrainer and cs.IsClassTrainer()
    if not (tf and tf:IsShown()) or not isClass or not WK:FeatureOn("classes") or not cs:Config().panel then
        if panel then panel:Hide() end
        return
    end
    if not panel then panel = build() end
    panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", tf, "TOPRIGHT", 6, 0)
    UI:MatchHost(panel, tf)
    local list = cs:TrainerAvailable(true)
    table.sort(list, function(a, b)
        if a.later ~= b.later then return not a.later end
        if a.later then return (a.level or 0) < (b.level or 0) end
        return a.cost < b.cost
    end)
    local total, n, nNow = 0, 0, 0
    for _, e in ipairs(list) do
        if not e.later then
            nNow = nNow + 1
            if not e.skipped then total = total + e.cost; n = n + 1 end
        end
    end
    local gold = cs:Money(_G.GetMoney and _G.GetMoney() or 0)
    panel.sub:SetText(string.format(T("%d sort(s) · %s · tu as %s"), n, cs:Money(total), gold))
    local y = -44
    local laterShown = false
    panel.later:Hide()
    for i, b in ipairs(panel.rows) do
        local e = list[i]
        if e then
            if e.later and not laterShown then
                laterShown = true
                y = y - 6
                panel.later:ClearAllPoints(); panel.later:SetPoint("TOPLEFT", 14, y); panel.later:Show()
                y = y - 16
            end
            b.e = e
            local icon
            if _G.GetTrainerServiceIcon then icon = _G.GetTrainerServiceIcon(e.index) end
            b.icon:SetTexture(icon or 134400)
            local dim = e.skipped or e.later
            b.icon:SetDesaturated(dim and true or false)
            b.name:SetText(e.name .. (e.rank ~= "" and (" " .. UI:Hex(C.muted) .. e.rank .. "|r") or ""))
            b.name:SetTextColor(unpack(dim and C.dim or C.text))
            if e.later then b.cost:SetText(e.level and string.format(T("niv. %d"), e.level) or "")
            else b.cost:SetText(e.skipped and T("écarté") or cs:Money(e.cost)) end
            b.cost:SetTextColor(unpack(dim and C.dim or C.gold))
            b.check:Refresh()
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 10, y); b:SetPoint("TOPRIGHT", -10, y)
            b:Show()
            y = y - ROW
        else
            b:Hide()
        end
    end
    if nNow == 0 then
        panel.sub:SetText(T("Rien à apprendre ici pour l'instant."))
    end
    panel.all:SetLabel(n > 0 and string.format(T("Apprendre la sélection (%s)"), cs:Money(total))
        or T("Apprendre la sélection"))
    panel.all:SetWidth(panel.all.label:GetStringWidth() + 32)
    panel.all:SetEnabled(n > 0)
    panel.all:ClearAllPoints(); panel.all:SetPoint("TOPLEFT", 14, y - 8)
    panel.note:ClearAllPoints(); panel.note:SetPoint("TOPLEFT", 14, y - 42)
    panel.note:SetPoint("TOPRIGHT", -14, y - 42)
    panel:SetHeight(-y + 42 + (panel.note:GetStringHeight() or 12) + 14)
    panel:Show()
end

WK:On("TRAINER_SHOW", function() C_Timer.After(0.15, function() UI:RefreshClassTrainer() end) end)
WK:On("TRAINER_UPDATE", function() if panel and panel:IsShown() then UI:RefreshClassTrainer() end end)
WK:On("TRAINER_CLOSED", function() if panel then panel:Hide() end end)
