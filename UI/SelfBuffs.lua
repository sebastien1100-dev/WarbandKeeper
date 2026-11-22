local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Buffs à ne pas oublier (Modules/SelfBuffs.lua), maquette B : liste déroulée sous ou au-dessus de la case
-- « buffs » de la barre « Sacs, marchand et maître » (réglage BagHelp dir) ; une ligne par buff demandé ici : bouton
-- protégé (type=spell, clic = lancer le sort), nom, état (absent, temps restant, ok). Boutons jamais changés en
-- combat (pending rendu à PLAYER_REGEN_ENABLED), liste fermée à l'entrée en combat ; placée sur _G.UIParent d'après
-- le rectangle de la case, jamais ancrée à la barre.
local SB = WK.modules.SelfBuffs
local MAXR, LS, LGAP, LW = 10, 26, 4, 230
local list
local pending = false

local function inCombat() return _G.InCombatLockdown and _G.InCombatLockdown() end
local function short(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec >= 3600 then return string.format("%dh", math.floor(sec / 3600)) end
    if sec >= 60 then return string.format(T("%d min"), math.floor(sec / 60)) end
    return string.format("%ds", sec)
end
local function stateText(r)
    if r.state == "missing" then return r.e.track and T("éteint") or T("absent"), C.negative end
    if r.state == "soon" then return short(r.left), C.gold end
    if r.left and r.left > 0 then return short(r.left), C.positive end
    return T("ok"), C.positive
end

local function build()
    local f = _G.CreateFrame("Frame", "WarbandKeeperSelfBuffs", _G.UIParent)
    f:SetSize(LW, LS + 12)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    UI:Panel(f, 8, { C.bg[1], C.bg[2], C.bg[3], 0.95 }, { UI:Accent() })
    f.rows = {}
    for i = 1, MAXR do
        local b = _G.CreateFrame("Button", "WarbandKeeperSelfBuff" .. i, f, "SecureActionButtonTemplate")
        b:SetSize(LS, LS)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6 - (i - 1) * (LS + LGAP))
        if b.RegisterForClicks then b:RegisterForClicks("AnyUp", "AnyDown") end
        b:SetAttribute("type", "spell")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label = UI:Text(f, 11); b.label:SetJustifyH("LEFT")
        b.label:SetPoint("LEFT", b, "RIGHT", 8, 0); b.label:SetPoint("RIGHT", f, "RIGHT", -62, 0)
        b.state = UI:Text(f, 10, C.muted); b.state:SetJustifyH("RIGHT")
        b.state:SetPoint("RIGHT", f, "RIGHT", -8, 0); b.state:SetPoint("TOP", b, "TOP", 0, -7)
        b:SetScript("OnEnter", function(s)
            if not s.r then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(s.r.name or "?", 1, 1, 1)
            local where = {}
            local pl = SB:Places(s.r.rk, s.r.e)
            if pl:find("w", 1, true) then where[#where + 1] = T("monde") end
            if pl:find("d", 1, true) then where[#where + 1] = T("donjon") end
            if pl:find("r", 1, true) then where[#where + 1] = T("raid") end
            _G.GameTooltip:AddLine(string.format(T("Demandé : %s"), table.concat(where, ", ")), 0.85, 0.85, 0.85)
            _G.GameTooltip:AddLine(inCombat() and T("En combat : utilisable après le combat") or T("Clic : lancer"),
                0.6, 0.6, 0.6)
            _G.GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
        b:Hide(); b.label:Hide(); b.state:Hide()
        f.rows[i] = b
    end
    -- états relus toutes les 0,5 s (textes seulement : rien de protégé ne change ici)
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 0.5 then return end
        s.acc = 0
        local rows = SB:Status()
        local by = {}
        for _, r in ipairs(rows) do by[r.rk] = r end
        for _, b in ipairs(s.rows) do
            if b:IsShown() and b.r then
                local r = by[b.r.rk] or b.r
                b.r = r
                local txt, col = stateText(r)
                b.state:SetText(txt); b.state:SetTextColor(col[1], col[2], col[3])
                b.icon:SetDesaturated(r.state == "ok")
            end
        end
    end)
    f:Hide()

    -- Remplit la liste (hors combat : attributs protégés)
    function f:Fill(rows)
        local n = math.min(#rows, MAXR)
        for i, b in ipairs(self.rows) do
            local r = rows[i]
            if r and i <= n then
                b.r = r
                if b:GetAttribute("spell") ~= r.name then b:SetAttribute("spell", r.name) end
                b.icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                b.icon:SetDesaturated(r.state == "ok")
                b.label:SetText(r.name or T(r.e.label))
                local txt, col = stateText(r)
                b.state:SetText(txt); b.state:SetTextColor(col[1], col[2], col[3])
                b:Show(); b.label:Show(); b.state:Show()
            else
                b.r = nil
                b:Hide(); b.label:Hide(); b.state:Hide()
            end
        end
        self:SetHeight(12 + math.max(1, n) * LS + math.max(0, n - 1) * LGAP)
    end
    return f
end

function UI.RefreshSelfBuffs()
    if inCombat() then pending = true return end
    pending = false
    if not list then list = build() end
    local cfg = SB:Config()
    local tile = UI.SelfBuffTile and UI.SelfBuffTile()
    if not (list.open and cfg.bar and tile and tile:IsVisible()) then list:Hide() return end
    local rows = SB:Status()
    if #rows == 0 then list:Hide(); list.open = false return end
    list:Fill(rows)
    local sc = tile:GetEffectiveScale() / _G.UIParent:GetEffectiveScale()
    local l, b, w, h = tile:GetRect()
    if l then
        local x = (l + w / 2) * sc - LW / 2
        list:ClearAllPoints()
        local down = WK.modules.BagHelp:Config().dir ~= "up"
        if down then list:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", x, b * sc - 4)
        else list:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", x, (b + h) * sc + 4) end
    end
    list:Show()
end
-- case « buffs » : déroule ou replie la liste (hors combat seulement : boutons protégés)
function UI.ToggleSelfBuffs()
    if inCombat() then WK:Print(T("Buffs : liste à ouvrir hors combat.")) return end
    if not list then list = build() end
    list.open = not list.open
    UI:RefreshSelfBuffs()
end
function UI.SelfBuffsOpen() return list and list.open and list:IsShown() or false end

-- entrée en combat : la liste se replie (encore permis à cet instant), puis plus rien ne bouge jusqu'à la sortie
WK:On("PLAYER_REGEN_DISABLED", function()
    if list and list:IsShown() and not inCombat() then list.open = false; list:Hide() end
end)
WK:On("PLAYER_REGEN_ENABLED", function() if pending then UI:RefreshSelfBuffs() end end)
